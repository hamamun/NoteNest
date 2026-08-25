import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';

import '../../core/hash.dart';
import '../../core/logging.dart';
import '../../core/time.dart';
import '../../core/ulid.dart';
import '../db/database.dart';
import '../models/enums.dart';
import 'checklist_matcher.dart';

/// Everything the UI needs to render one entry.
class EntryBundle {
  const EntryBundle({
    required this.entry,
    required this.lines,
    required this.images,
  });

  final Entry entry;
  final List<ChecklistLine> lines;
  final List<EntryImage> images;

  EntryType get type => EntryType.parse(entry.type);
  EntryLocation get location => EntryLocation.parse(entry.location);
  bool get isChecklist => type.isChecklist;

  /// U-14: the text preview shown on a card.
  String get preview {
    if (isChecklist) return ChecklistMatcher.toPlainText(lines);
    return entry.body;
  }

  int get checkedCount => lines.where((l) => l.checked).length;
}

/// The central data access object for notes and lists.
///
/// Every state transition in section T of BUILD_CHECKLIST.md is implemented
/// here exactly once, so the UI can never invent an illegal combination such
/// as "archived and trashed at the same time" (T-02).
class EntryRepository {
  EntryRepository(this._db, {required this.deviceId});

  final AppDatabase _db;
  final String deviceId;

  // ---------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------

  /// S-06/S-08/S-12: the main list query.
  Stream<List<EntryBundle>> watchEntries({
    required Workspace workspace,
    EntryFilter filter = EntryFilter.all,
    SortMode sort = SortMode.recentlyEdited,
    String query = '',
  }) {
    final select = _db.select(_db.entries)
      ..where((t) => t.location.equals(workspace.location.value));

    final type = filter.type;
    if (type != null) {
      select.where((t) => t.type.equals(type.value));
    }

    if (query.trim().isNotEmpty) {
      // S-12/S-13: case-insensitive over title and body. Because a checklist
      // stores its lines in `body`, line text is searchable for free.
      final like = '%${query.trim().toLowerCase()}%';
      select.where(
        (t) => t.title.lower().like(like) | t.body.lower().like(like),
      );
    }

    // S-03: pinned first everywhere except Trash (S-05).
    final orderBy = <OrderClauseGenerator<$EntriesTable>>[
      if (workspace != Workspace.trash)
        (t) => OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc),
      ..._orderFor(sort),
    ];
    select.orderBy(orderBy);

    return select.watch().asyncMap((rows) => _bundleAll(rows));
  }

  List<OrderClauseGenerator<$EntriesTable>> _orderFor(SortMode sort) {
    switch (sort) {
      case SortMode.recentlyEdited:
        return [(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)];
      case SortMode.createdNewest:
        return [(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)];
      case SortMode.createdOldest:
        return [(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)];
      case SortMode.titleAz:
        return [
          (t) => OrderingTerm(expression: t.title.lower(), mode: OrderingMode.asc),
          (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
        ];
      case SortMode.recentlyViewed:
        // S-09: local-only ordering, never synced.
        return [
          (t) => OrderingTerm(expression: t.lastViewedAtLocal, mode: OrderingMode.desc),
          (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
        ];
    }
  }

  Stream<EntryBundle?> watchEntry(String id) {
    final select = _db.select(_db.entries)..where((t) => t.id.equals(id));
    return select.watchSingleOrNull().asyncMap(
          (row) async => row == null ? null : _bundle(row),
        );
  }

  Future<EntryBundle?> findEntry(String id) async {
    final row = await (_db.select(_db.entries)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _bundle(row);
  }

  Future<List<EntryBundle>> allEntriesForSync() async {
    final rows = await (_db.select(_db.entries)
          ..where((t) => t.location.isNotValue(EntryLocation.deleted.value)))
        .get();
    return _bundleAll(rows);
  }

  Future<List<EntryBundle>> allEntriesIncludingDeleted() async {
    final rows = await _db.select(_db.entries).get();
    return _bundleAll(rows);
  }

  Future<List<EntryBundle>> entriesByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows =
        await (_db.select(_db.entries)..where((t) => t.id.isIn(ids))).get();
    return _bundleAll(rows);
  }

  Future<int> countIn(Workspace workspace) async {
    final count = _db.entries.id.count();
    final query = _db.selectOnly(_db.entries)
      ..addColumns([count])
      ..where(_db.entries.location.equals(workspace.location.value));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Stream<int> watchCount(Workspace workspace) {
    final count = _db.entries.id.count();
    final query = _db.selectOnly(_db.entries)
      ..addColumns([count])
      ..where(_db.entries.location.equals(workspace.location.value));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  Future<List<EntryBundle>> _bundleAll(List<Entry> rows) async {
    final result = <EntryBundle>[];
    for (final row in rows) {
      result.add(await _bundle(row));
    }
    return result;
  }

  Future<EntryBundle> _bundle(Entry entry) async {
    final lines = EntryType.parse(entry.type).isChecklist
        ? await _linesFor(entry.id)
        : const <ChecklistLine>[];
    final images = await imagesFor(entry.id);
    return EntryBundle(entry: entry, lines: lines, images: images);
  }

  Future<List<ChecklistLine>> _linesFor(String entryId) async {
    final rows = await (_db.select(_db.checklistItems)
          ..where((t) => t.entryId.equals(entryId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
    return rows.map((r) => ChecklistLine(r.itemText, r.checked)).toList();
  }

  Future<List<EntryImage>> imagesFor(String entryId) =>
      (_db.select(_db.entryImages)
            ..where((t) => t.entryId.equals(entryId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

  // ---------------------------------------------------------------------
  // Create / update
  // ---------------------------------------------------------------------

  /// N-01: creates an empty note or checklist and returns its id.
  Future<String> createEntry(EntryType type) async {
    final now = AppTime.nowMs();
    final id = Ulid.generate();
    await _db.into(_db.entries).insert(
          EntriesCompanion.insert(
            id: id,
            type: type.value,
            createdAt: now,
            updatedAt: now,
            contentUpdatedAt: now,
            metadataUpdatedAt: now,
            localChanged: const Value(true),
            syncStatus: Value(SyncStatus.pending.value),
          ),
        );
    AppLog.info('repo', 'created ${type.value} $id');
    return id;
  }

  /// N-06/N-07: saves edited content. Bumps `content_updated_at` (S-11) and
  /// reconciles checklist lines through the text matcher (M-03).
  Future<void> saveContent({
    required String id,
    required String title,
    required String body,
    bool recordRevision = true,
  }) async {
    final existing = await findEntry(id);
    if (existing == null) return;

    final unchanged = existing.entry.title == title && existing.entry.body == body;
    if (unchanged) return;

    if (recordRevision) {
      await _writeRevision(existing.entry);
    }

    final now = AppTime.nowMs();
    await _db.transaction(() async {
      await (_db.update(_db.entries)..where((t) => t.id.equals(id))).write(
        EntriesCompanion(
          title: Value(title),
          body: Value(body),
          updatedAt: Value(now),
          contentUpdatedAt: Value(now),
          localChanged: const Value(true),
          syncStatus: Value(SyncStatus.pending.value),
          lastLocalHash: Value(ContentHash.ofParts([title, body])),
        ),
      );

      if (existing.isChecklist) {
        final reconciled = ChecklistMatcher.reconcile(
          previous: existing.lines,
          body: body,
        );
        await _replaceChecklistItems(id, reconciled, now);
      }
    });
  }

  /// K-01..K-07: per-checklist checkbox visibility. This is item metadata, so
  /// it syncs.
  Future<void> setCheckboxesVisible(String id, bool visible) =>
      _updateMetadata(id, EntriesCompanion(checkboxesVisibleInView: Value(visible)));

  /// N-10: check/uncheck a single line from View Mode.
  Future<void> setLineChecked(String entryId, int index, bool checked) async {
    final rows = await (_db.select(_db.checklistItems)
          ..where((t) => t.entryId.equals(entryId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
    if (index < 0 || index >= rows.length) return;

    final now = AppTime.nowMs();
    await _db.transaction(() async {
      await (_db.update(_db.checklistItems)
            ..where((t) => t.id.equals(rows[index].id)))
          .write(ChecklistItemsCompanion(
        checked: Value(checked),
        updatedAt: Value(now),
      ));
      // Checking an item is a content change: it must sync and it should move
      // the item up the "recently edited" list (S-07).
      await (_db.update(_db.entries)..where((t) => t.id.equals(entryId))).write(
        EntriesCompanion(
          updatedAt: Value(now),
          contentUpdatedAt: Value(now),
          localChanged: const Value(true),
          syncStatus: Value(SyncStatus.pending.value),
        ),
      );
    });
  }

  Future<void> _replaceChecklistItems(
    String entryId,
    List<ChecklistLine> lines,
    int now,
  ) async {
    await (_db.delete(_db.checklistItems)
          ..where((t) => t.entryId.equals(entryId)))
        .go();
    for (var i = 0; i < lines.length; i++) {
      await _db.into(_db.checklistItems).insert(
            ChecklistItemsCompanion.insert(
              id: Ulid.generate(),
              entryId: entryId,
              itemText: lines[i].text,
              checked: Value(lines[i].checked),
              sortOrder: i,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  /// Replaces checklist state wholesale (used by the sync engine when pulling
  /// a remote checklist file).
  Future<void> replaceChecklistFromRemote(
    String entryId,
    List<ChecklistLine> lines,
  ) =>
      _replaceChecklistItems(entryId, lines, AppTime.nowMs());

  /// COL-01: colour is metadata, so it bumps `metadata_updated_at` only.
  Future<void> setColor(String id, String colorKey) =>
      _updateMetadata(id, EntriesCompanion(colorKey: Value(colorKey)));

  /// S-01/S-02: pin state syncs.
  Future<void> setPinned(String id, bool pinned) => _updateMetadata(
        id,
        EntriesCompanion(
          isPinned: Value(pinned),
          pinnedAt: Value(pinned ? AppTime.nowMs() : null),
        ),
      );

  Future<void> togglePinned(String id) async {
    final bundle = await findEntry(id);
    if (bundle == null) return;
    await setPinned(id, !bundle.entry.isPinned);
  }

  /// S-09: viewing is local-only. It must not touch `updated_at` and must not
  /// mark the row dirty, otherwise opening a note on the phone would reorder
  /// the desktop after the next sync.
  Future<void> markViewed(String id) async {
    await (_db.update(_db.entries)..where((t) => t.id.equals(id))).write(
      EntriesCompanion(lastViewedAtLocal: Value(AppTime.nowMs())),
    );
  }

  Future<void> _updateMetadata(String id, EntriesCompanion companion) async {
    final now = AppTime.nowMs();
    await (_db.update(_db.entries)..where((t) => t.id.equals(id))).write(
      companion.copyWith(
        updatedAt: Value(now),
        metadataUpdatedAt: Value(now),
        localChanged: const Value(true),
        syncStatus: Value(SyncStatus.pending.value),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // T-05..T-14: location transitions
  // ---------------------------------------------------------------------

  /// T-05: Home/Archive -> Archive.
  Future<void> archive(String id) => _updateMetadata(
        id,
        EntriesCompanion(
          location: Value(EntryLocation.archive.value),
          archivedAt: Value(AppTime.nowMs()),
          trashedAt: const Value(null),
          previousLocationBeforeTrash: const Value(null),
        ),
      );

  /// T-06: Archive -> Home.
  Future<void> restoreFromArchive(String id) => _updateMetadata(
        id,
        const EntriesCompanion(
          location: Value('active'),
          archivedAt: Value(null),
          trashedAt: Value(null),
          previousLocationBeforeTrash: Value(null),
        ),
      );

  /// T-07/T-08: anything -> Trash, remembering where it came from.
  Future<void> moveToTrash(String id) async {
    final bundle = await findEntry(id);
    if (bundle == null) return;
    final from = bundle.location;
    if (from == EntryLocation.trash || from == EntryLocation.deleted) return;

    await _updateMetadata(
      id,
      EntriesCompanion(
        previousLocationBeforeTrash: Value(from.value),
        location: Value(EntryLocation.trash.value),
        trashedAt: Value(AppTime.nowMs()),
      ),
    );
  }

  /// T-09: Trash -> wherever it came from (Home by default).
  Future<void> restoreFromTrash(String id) async {
    final bundle = await findEntry(id);
    if (bundle == null) return;

    final target = EntryLocation.parse(
      bundle.entry.previousLocationBeforeTrash ?? EntryLocation.active.value,
    );
    // T-02: an item can never land in `trash` or `deleted` via a restore.
    final safeTarget = (target == EntryLocation.archive)
        ? EntryLocation.archive
        : EntryLocation.active;

    await _updateMetadata(
      id,
      EntriesCompanion(
        location: Value(safeTarget.value),
        trashedAt: const Value(null),
        previousLocationBeforeTrash: const Value(null),
        archivedAt: Value(
          safeTarget == EntryLocation.archive ? AppTime.nowMs() : null,
        ),
      ),
    );
  }

  /// T-10: explicit "Move to Home" from Trash.
  Future<void> moveToHome(String id) => _updateMetadata(
        id,
        const EntriesCompanion(
          location: Value('active'),
          trashedAt: Value(null),
          archivedAt: Value(null),
          previousLocationBeforeTrash: Value(null),
        ),
      );

  /// T-11: explicit "Move to Archive" from Trash.
  Future<void> moveToArchive(String id) => archive(id);

  /// T-12/T-14/X-01: permanent delete. Always writes a tombstone first.
  Future<void> deleteForever(String id) async {
    final bundle = await findEntry(id);
    if (bundle == null) return;

    final now = AppTime.nowMs();
    final images = await imagesFor(id);

    await _db.transaction(() async {
      // X-01: tombstone before anything is destroyed.
      await _db.into(_db.tombstones).insertOnConflictUpdate(
            TombstonesCompanion.insert(
              entryId: id,
              type: bundle.entry.type,
              deletedAt: now,
              deletedByDeviceId: deviceId,
              deleteRevisionId: Ulid.generate(),
              lastKnownNotePath: Value('notes/$id.md'),
              lastKnownImageIds: Value(images.map((i) => i.id).join(',')),
              reason: const Value('delete_forever'),
              synced: const Value(false),
            ),
          );

      // T-14: the row survives as a `deleted` shell until the sync engine has
      // confirmed the remote delete.
      await (_db.update(_db.entries)..where((t) => t.id.equals(id))).write(
        EntriesCompanion(
          location: Value(EntryLocation.deleted.value),
          permanentlyDeletedAt: Value(now),
          contentDeleted: const Value(true),
          title: const Value(''),
          body: const Value(''),
          localChanged: const Value(true),
          syncStatus: Value(SyncStatus.pendingDelete.value),
          updatedAt: Value(now),
          metadataUpdatedAt: Value(now),
        ),
      );

      await (_db.delete(_db.checklistItems)..where((t) => t.entryId.equals(id))).go();
      await (_db.delete(_db.entryRevisions)..where((t) => t.entryId.equals(id))).go();
      await (_db.update(_db.entryImages)..where((t) => t.entryId.equals(id)))
          .write(EntryImagesCompanion(deletedAt: Value(now)));
    });

    // Local image bytes go immediately; the remote copies are removed by the
    // sync engine using the ids recorded on the tombstone (X-14).
    for (final image in images) {
      await _deleteLocalFile(image.localPath);
    }

    AppLog.info('repo', 'delete forever $id (tombstone written)');
  }

  /// T-13/X-15: Empty Trash writes one tombstone per item.
  Future<int> emptyTrash() async {
    final rows = await (_db.select(_db.entries)
          ..where((t) => t.location.equals(EntryLocation.trash.value)))
        .get();
    for (final row in rows) {
      await deleteForever(row.id);
    }
    return rows.length;
  }

  /// Bulk helpers used by the multi-select toolbar (U-06).
  Future<void> archiveAll(Iterable<String> ids) async {
    for (final id in ids) {
      await archive(id);
    }
  }

  Future<void> trashAll(Iterable<String> ids) async {
    for (final id in ids) {
      await moveToTrash(id);
    }
  }

  Future<void> setColorAll(Iterable<String> ids, String colorKey) async {
    for (final id in ids) {
      await setColor(id, colorKey);
    }
  }

  Future<void> restoreAll(Iterable<String> ids) async {
    for (final id in ids) {
      await restoreFromTrash(id);
    }
  }

  /// Bulk unarchive used by the Archive selection toolbar.
  Future<void> unarchiveAll(Iterable<String> ids) async {
    for (final id in ids) {
      await restoreFromArchive(id);
    }
  }

  Future<void> deleteForeverAll(Iterable<String> ids) async {
    for (final id in ids) {
      await deleteForever(id);
    }
  }

  // ---------------------------------------------------------------------
  // X-09: recovered conflict copies
  // ---------------------------------------------------------------------

  /// Creates a brand-new entry that carries the offline work forward without
  /// ever reusing the tombstoned id.
  Future<String> createRecoveredCopy({
    required EntryBundle source,
    required String deviceName,
    String reasonLabel = 'Recovered conflict',
  }) async {
    final now = AppTime.nowMs();
    final id = Ulid.generate();
    final title = '$reasonLabel - '
        '${source.entry.title.isEmpty ? "Untitled" : source.entry.title} - '
        'from $deviceName - ${AppTime.dateStamp(now)}';

    await _db.into(_db.entries).insert(
          EntriesCompanion.insert(
            id: id,
            type: source.entry.type,
            title: Value(title),
            body: Value(source.entry.body),
            colorKey: Value(source.entry.colorKey),
            checkboxesVisibleInView: Value(source.entry.checkboxesVisibleInView),
            location: Value(EntryLocation.active.value),
            createdAt: now,
            updatedAt: now,
            contentUpdatedAt: now,
            metadataUpdatedAt: now,
            localChanged: const Value(true),
            syncStatus: Value(SyncStatus.conflictReview.value),
            conflictOfId: Value(source.entry.id),
          ),
        );

    if (source.isChecklist) {
      await _replaceChecklistItems(id, source.lines, now);
    }

    AppLog.warn('repo', 'recovered conflict copy $id from ${source.entry.id}');
    return id;
  }

  Future<void> clearConflictFlag(String id) async {
    await (_db.update(_db.entries)..where((t) => t.id.equals(id)))
        .write(EntriesCompanion(syncStatus: Value(SyncStatus.pending.value)));
  }

  Stream<int> watchConflictCount() {
    final count = _db.entries.id.count();
    final query = _db.selectOnly(_db.entries)
      ..addColumns([count])
      ..where(_db.entries.syncStatus.equals(SyncStatus.conflictReview.value));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  // ---------------------------------------------------------------------
  // V3: local note history
  // ---------------------------------------------------------------------

  Future<void> _writeRevision(Entry entry) async {
    if (entry.title.isEmpty && entry.body.isEmpty) return;
    await _db.into(_db.entryRevisions).insert(
          EntryRevisionsCompanion.insert(
            id: Ulid.generate(),
            entryId: entry.id,
            title: entry.title,
            body: entry.body,
            createdAt: AppTime.nowMs(),
          ),
        );
    await _pruneRevisions(entry.id);
  }

  /// Keeps history bounded so the database cannot grow without limit.
  Future<void> _pruneRevisions(String entryId, {int keep = 50}) async {
    final rows = await (_db.select(_db.entryRevisions)
          ..where((t) => t.entryId.equals(entryId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
    if (rows.length <= keep) return;
    final doomed = rows.sublist(keep).map((r) => r.id).toList();
    await (_db.delete(_db.entryRevisions)..where((t) => t.id.isIn(doomed))).go();
  }

  Future<List<EntryRevision>> revisionsFor(String entryId) =>
      (_db.select(_db.entryRevisions)
            ..where((t) => t.entryId.equals(entryId))
            ..orderBy([
              (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
            ]))
          .get();

  Future<void> restoreRevision(String entryId, String revisionId) async {
    final revision = await (_db.select(_db.entryRevisions)
          ..where((t) => t.id.equals(revisionId)))
        .getSingleOrNull();
    if (revision == null) return;
    await saveContent(
      id: entryId,
      title: revision.title,
      body: revision.body,
    );
  }

  // ---------------------------------------------------------------------
  // Images (IMG-05, IMG-13)
  // ---------------------------------------------------------------------

  Future<void> addImageRecord({
    required String entryId,
    required String id,
    required String fileName,
    required String localPath,
    required String mimeType,
    required int sizeBytes,
    int? width,
    int? height,
  }) async {
    final existing = await imagesFor(entryId);
    final now = AppTime.nowMs();
    await _db.into(_db.entryImages).insert(
          EntryImagesCompanion.insert(
            id: id,
            entryId: entryId,
            fileName: fileName,
            localPath: localPath,
            mimeType: mimeType,
            sizeBytes: Value(sizeBytes),
            width: Value(width),
            height: Value(height),
            sortOrder: Value(existing.length),
            createdAt: now,
          ),
        );
    await (_db.update(_db.entries)..where((t) => t.id.equals(entryId))).write(
      EntriesCompanion(
        updatedAt: Value(now),
        contentUpdatedAt: Value(now),
        localChanged: const Value(true),
        syncStatus: Value(SyncStatus.pending.value),
      ),
    );
  }

  /// IMG-13: soft delete now, purge the local file, let sync remove the remote.
  Future<void> deleteImage(String imageId) async {
    final image = await (_db.select(_db.entryImages)
          ..where((t) => t.id.equals(imageId)))
        .getSingleOrNull();
    if (image == null) return;

    final now = AppTime.nowMs();
    await (_db.update(_db.entryImages)..where((t) => t.id.equals(imageId)))
        .write(EntryImagesCompanion(
      deletedAt: Value(now),
      localChanged: const Value(true),
      syncStatus: Value(SyncStatus.pendingDelete.value),
    ));
    await (_db.update(_db.entries)..where((t) => t.id.equals(image.entryId)))
        .write(EntriesCompanion(
      updatedAt: Value(now),
      contentUpdatedAt: Value(now),
      localChanged: const Value(true),
      syncStatus: Value(SyncStatus.pending.value),
    ));
    await _deleteLocalFile(image.localPath);
  }

  Future<List<EntryImage>> pendingImageDeletes() =>
      (_db.select(_db.entryImages)
            ..where((t) => t.syncStatus.equals(SyncStatus.pendingDelete.value)))
          .get();

  Future<void> purgeImageRecord(String imageId) =>
      (_db.delete(_db.entryImages)..where((t) => t.id.equals(imageId))).go();

  Future<void> markImageSynced(String imageId, String remotePath, String? sha) =>
      (_db.update(_db.entryImages)..where((t) => t.id.equals(imageId))).write(
        EntryImagesCompanion(
          remotePath: Value(remotePath),
          lastRemoteSha: Value(sha),
          localChanged: const Value(false),
          syncStatus: Value(SyncStatus.synced.value),
        ),
      );

  Future<void> _deleteLocalFile(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (e) {
      AppLog.warn('repo', 'could not delete local file: $e');
    }
  }

  // ---------------------------------------------------------------------
  // Sync support
  // ---------------------------------------------------------------------

  Future<void> markSynced({
    required String id,
    required String? remoteSha,
    required int syncedAt,
  }) async {
    await (_db.update(_db.entries)..where((t) => t.id.equals(id))).write(
      EntriesCompanion(
        localChanged: const Value(false),
        lastSyncedAt: Value(syncedAt),
        lastRemoteSha: Value(remoteSha),
        syncStatus: Value(SyncStatus.synced.value),
      ),
    );
  }

  Future<void> markSyncError(String id) async {
    await (_db.update(_db.entries)..where((t) => t.id.equals(id)))
        .write(EntriesCompanion(syncStatus: Value(SyncStatus.error.value)));
  }

  /// Applies a remote version on top of the local row (sync pull).
  Future<void> upsertFromRemote({
    required String id,
    required EntriesCompanion companion,
    List<ChecklistLine>? lines,
  }) async {
    await _db.transaction(() async {
      final exists = await (_db.select(_db.entries)..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (exists == null) {
        await _db.into(_db.entries).insert(companion);
      } else {
        await (_db.update(_db.entries)..where((t) => t.id.equals(id)))
            .write(companion);
      }
      if (lines != null) {
        await _replaceChecklistItems(id, lines, AppTime.nowMs());
      }
    });
  }

  /// X-08: a tombstone arrived for an entry with no unsynced local work.
  Future<void> applyRemoteTombstone({
    required String entryId,
    required String type,
    required int deletedAt,
    required String deletedByDeviceId,
    required String deleteRevisionId,
    String? notePath,
    String imageIds = '',
  }) async {
    final images = await imagesFor(entryId);

    await _db.transaction(() async {
      await _db.into(_db.tombstones).insertOnConflictUpdate(
            TombstonesCompanion.insert(
              entryId: entryId,
              type: type,
              deletedAt: deletedAt,
              deletedByDeviceId: deletedByDeviceId,
              deleteRevisionId: deleteRevisionId,
              lastKnownNotePath: Value(notePath),
              lastKnownImageIds: Value(imageIds),
              reason: const Value('remote_delete'),
              synced: const Value(true),
            ),
          );

      await (_db.delete(_db.checklistItems)..where((t) => t.entryId.equals(entryId)))
          .go();
      await (_db.delete(_db.entryRevisions)..where((t) => t.entryId.equals(entryId)))
          .go();
      await (_db.delete(_db.entryImages)..where((t) => t.entryId.equals(entryId)))
          .go();
      await (_db.delete(_db.entries)..where((t) => t.id.equals(entryId))).go();
    });

    for (final image in images) {
      await _deleteLocalFile(image.localPath);
    }
    AppLog.info('repo', 'applied remote tombstone for $entryId');
  }

  Future<Tombstone?> tombstoneFor(String entryId) =>
      (_db.select(_db.tombstones)..where((t) => t.entryId.equals(entryId)))
          .getSingleOrNull();

  Future<List<Tombstone>> allTombstones() => _db.select(_db.tombstones).get();

  Future<List<Tombstone>> unsyncedTombstones() =>
      (_db.select(_db.tombstones)..where((t) => t.synced.equals(false))).get();

  Future<void> markTombstoneSynced(String entryId, String? sha) =>
      (_db.update(_db.tombstones)..where((t) => t.entryId.equals(entryId)))
          .write(TombstonesCompanion(synced: const Value(true), remoteSha: Value(sha)));

  /// Removes the local shell row once the remote files are gone.
  Future<void> purgeDeletedEntry(String id) =>
      (_db.delete(_db.entries)..where((t) => t.id.equals(id))).go();

  Future<List<Entry>> pendingDeleteEntries() => (_db.select(_db.entries)
        ..where((t) => t.syncStatus.equals(SyncStatus.pendingDelete.value)))
      .get();

  Future<List<Entry>> dirtyEntries() => (_db.select(_db.entries)
        ..where((t) =>
            t.localChanged.equals(true) &
            t.location.isNotValue(EntryLocation.deleted.value)))
      .get();
}
