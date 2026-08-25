import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;

import '../../core/crypto.dart';
import '../../core/logging.dart';
import '../../core/time.dart';
import '../../core/ulid.dart';
import '../../data/db/database.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/checklist_matcher.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/image_store.dart';
import '../../data/repositories/sync_config_repository.dart';
import 'entry_file_codec.dart';
import 'github_client.dart';
import 'sync_decision.dart';

class SyncResult {
  SyncResult();

  int pulled = 0;
  int pushed = 0;
  int deletedLocally = 0;
  int tombstonesUploaded = 0;
  int conflicts = 0;
  int imagesUp = 0;
  int imagesDown = 0;
  final List<String> errors = <String>[];

  bool get ok => errors.isEmpty;

  /// G-13: the one-line status shown next to the cloud icon.
  String get summary {
    if (errors.isNotEmpty) return 'Sync failed: ${errors.first}';
    final parts = <String>[];
    if (pulled > 0) parts.add('$pulled in');
    if (pushed > 0) parts.add('$pushed out');
    if (deletedLocally > 0) parts.add('$deletedLocally deleted');
    if (conflicts > 0) parts.add('$conflicts conflict${conflicts == 1 ? "" : "s"}');
    if (imagesUp + imagesDown > 0) parts.add('${imagesUp + imagesDown} images');
    return parts.isEmpty ? 'Already up to date' : 'Synced: ${parts.join(", ")}';
  }
}

/// G-01: repository paths.
class RepoPaths {
  RepoPaths._();
  static const String notes = 'notes';
  static const String images = 'images';
  static const String thumbnails = 'thumbnails';
  static const String tombstones = '.tombstones/entries';
  static const String meta = 'meta';
}

/// The sync engine.
///
/// The order of operations in [run] is fixed by X-03 and must not be
/// rearranged for convenience — pulling tombstones before pushing anything is
/// what stops deleted notes from coming back.
class SyncEngine {
  SyncEngine({
    required EntryRepository repository,
    required SyncConfigRepository config,
    required ImageStore imageStore,
    required String deviceId,
    required String deviceName,
  })  : _repo = repository,
        _config = config,
        _images = imageStore,
        _deviceId = deviceId,
        _deviceName = deviceName;

  final EntryRepository _repo;
  final SyncConfigRepository _config;
  final ImageStore _images;
  final String _deviceId;
  final String _deviceName;

  /// G-17: single-flight. Two concurrent syncs against the same repository
  /// would race on shas and could corrupt state.
  bool _running = false;
  bool get isRunning => _running;

  Future<SyncResult> run({
    required GitHubClient client,
    String? encryptionPassphrase,
  }) async {
    if (_running) {
      final busy = SyncResult()..errors.add('A sync is already running.');
      return busy;
    }
    _running = true;
    final result = SyncResult();

    try {
      AppLog.info('sync', 'start (device $_deviceId)');

      // ---- X-03 step 2 + 3: tombstones FIRST, applied before any upload ----
      final remoteTombstones = await _fetchRemoteTombstones(client);
      await _applyRemoteTombstones(client, remoteTombstones, result);

      // ---- X-03 step 4: remote entry listing ----
      final remoteNotes = <String, RemoteFile>{};
      for (final file in await client.listDirectory(RepoPaths.notes)) {
        if (!file.path.endsWith('.md')) continue;
        final id = file.path.split('/').last.replaceAll('.md', '');
        remoteNotes[id] = file;
      }

      // Local state after tombstones have been applied.
      final localBundles = await _repo.allEntriesForSync();
      final localById = {for (final b in localBundles) b.entry.id: b};
      final tombstoneIds = {
        for (final t in await _repo.allTombstones()) t.entryId,
      };

      final allIds = <String>{...localById.keys, ...remoteNotes.keys};

      // ---- X-03 steps 5 + 7: reconcile every id ----
      for (final id in allIds) {
        try {
          await _reconcileOne(
            client: client,
            id: id,
            local: localById[id],
            remote: remoteNotes[id],
            hasTombstone: tombstoneIds.contains(id),
            result: result,
            passphrase: encryptionPassphrase,
          );
        } catch (e) {
          AppLog.error('sync', 'entry $id failed', e);
          result.errors.add('Entry $id: ${AppLog.redact(e)}');
          await _repo.markSyncError(id);
        }
      }

      // ---- X-03 step 6: upload our own tombstones and finish the deletes ----
      await _pushLocalDeletes(client, result);

      // ---- images ----
      await _syncImages(client, result);

      final commit = await client.headCommitSha();
      await _config.recordSync(
        at: AppTime.nowMs(),
        status: result.ok ? result.summary : 'error',
        commit: commit,
      );

      AppLog.info('sync', 'done — ${result.summary}');
      return result;
    } on GitHubException catch (e) {
      AppLog.error('sync', 'github error', e);
      result.errors.add(e.message);
      await _config.recordSync(at: AppTime.nowMs(), status: 'error');
      return result;
    } on SocketException {
      result.errors.add('No internet connection.');
      await _config.recordSync(at: AppTime.nowMs(), status: 'offline');
      return result;
    } catch (e) {
      AppLog.error('sync', 'unexpected', e);
      result.errors.add(AppLog.redact(e));
      await _config.recordSync(at: AppTime.nowMs(), status: 'error');
      return result;
    } finally {
      _running = false;
    }
  }

  // ---------------------------------------------------------------------
  // Tombstones
  // ---------------------------------------------------------------------

  Future<Map<String, Map<String, dynamic>>> _fetchRemoteTombstones(
    GitHubClient client,
  ) async {
    final result = <String, Map<String, dynamic>>{};
    final files = await client.listDirectory(RepoPaths.tombstones);

    for (final file in files) {
      if (!file.path.endsWith('.json')) continue;
      final id = file.path.split('/').last.replaceAll('.json', '');

      // Skip the download when we already know about this delete.
      final known = await _repo.tombstoneFor(id);
      if (known != null && known.synced) {
        result[id] = const {};
        continue;
      }

      final full = await client.getFile(file.path);
      if (full?.bytes == null) continue;
      try {
        final json = jsonDecode(full!.text) as Map<String, dynamic>;
        result[id] = json;
      } catch (e) {
        AppLog.warn('sync', 'unreadable tombstone $id: $e');
      }
    }
    return result;
  }

  /// X-08/X-09: apply each remote tombstone locally before anything is pushed.
  Future<void> _applyRemoteTombstones(
    GitHubClient client,
    Map<String, Map<String, dynamic>> remote,
    SyncResult result,
  ) async {
    for (final entry in remote.entries) {
      final id = entry.key;
      final json = entry.value;
      if (json.isEmpty) continue; // already known and synced

      final local = await _repo.findEntry(id);

      // X-09: unsynced local work is preserved under a NEW id.
      if (local != null && local.entry.localChanged && !local.entry.contentDeleted) {
        await _repo.createRecoveredCopy(
          source: local,
          deviceName: _deviceName,
        );
        result.conflicts++;
      }

      await _repo.applyRemoteTombstone(
        entryId: id,
        type: json['type'] as String? ?? EntryType.note.value,
        deletedAt: AppTime.parseIso(json['deleted_at'] as String?) ?? AppTime.nowMs(),
        deletedByDeviceId: json['deleted_by_device_id'] as String? ?? 'unknown',
        deleteRevisionId: json['delete_revision_id'] as String? ?? Ulid.generate(),
        notePath: json['last_known_note_path'] as String?,
        imageIds: ((json['last_known_image_ids'] as List?) ?? const [])
            .map((e) => e.toString())
            .join(','),
      );
      if (local != null) result.deletedLocally++;
    }
  }

  /// X-07: upload the tombstone, THEN delete the note file, THEN the images.
  Future<void> _pushLocalDeletes(GitHubClient client, SyncResult result) async {
    final pending = await _repo.unsyncedTombstones();

    for (final tombstone in pending) {
      try {
        final payload = <String, dynamic>{
          'id': tombstone.entryId,
          'type': tombstone.type,
          'deleted_at': AppTime.toIso(tombstone.deletedAt),
          'deleted_by_device_id': tombstone.deletedByDeviceId,
          'delete_revision_id': tombstone.deleteRevisionId,
          'last_known_note_path': tombstone.lastKnownNotePath,
          'last_known_image_ids': tombstone.lastKnownImageIds
              .split(',')
              .where((s) => s.isNotEmpty)
              .toList(),
          'reason': tombstone.reason,
        };

        final path = '${RepoPaths.tombstones}/${tombstone.entryId}.json';
        final existing = await client.getFile(path);

        // 1. tombstone first — if we crash after this, other devices are safe.
        final sha = await client.putFile(
          path: path,
          bytes: Uint8List.fromList(
            utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)),
          ),
          message: 'NoteNest: tombstone ${tombstone.entryId}',
          expectedSha: existing?.sha,
        );
        await _repo.markTombstoneSynced(tombstone.entryId, sha);
        result.tombstonesUploaded++;

        // 2. the note file.
        await client.deleteByPath(
          tombstone.lastKnownNotePath ?? EntryFile.pathFor(tombstone.entryId),
          'NoteNest: delete ${tombstone.entryId}',
        );

        // 3. X-14: the images that belonged to it.
        for (final imageId in tombstone.lastKnownImageIds.split(',')) {
          if (imageId.isEmpty) continue;
          for (final ext in const ['.jpg', '.png', '.webp', '.jpeg']) {
            await client.deleteByPath(
              '${RepoPaths.images}/$imageId$ext',
              'NoteNest: delete image $imageId',
            );
          }
          await client.deleteByPath(
            '${RepoPaths.thumbnails}/$imageId.jpg',
            'NoteNest: delete thumbnail $imageId',
          );
        }

        // The local shell row can go now that the remote is clean.
        await _repo.purgeDeletedEntry(tombstone.entryId);
      } catch (e) {
        AppLog.error('sync', 'tombstone push failed for ${tombstone.entryId}', e);
        result.errors.add('Delete of ${tombstone.entryId}: ${AppLog.redact(e)}');
      }
    }
  }

  // ---------------------------------------------------------------------
  // Entry reconciliation
  // ---------------------------------------------------------------------

  Future<void> _reconcileOne({
    required GitHubClient client,
    required String id,
    required EntryBundle? local,
    required RemoteFile? remote,
    required bool hasTombstone,
    required SyncResult result,
    String? passphrase,
  }) async {
    final action = SyncDecision.decide(SyncInput(
      hasTombstone: hasTombstone,
      hasLocal: local != null,
      hasRemote: remote != null,
      localDirty: local?.entry.localChanged ?? false,
      syncedBefore: local?.entry.lastSyncedAt != null,
      remoteChanged: remote != null &&
          local != null &&
          remote.sha != (local.entry.lastRemoteSha ?? ''),
    ));

    switch (action) {
      case SyncAction.skipTombstoned:
      case SyncAction.noop:
        return;

      case SyncAction.deleteLocal:
        await _repo.applyRemoteTombstone(
          entryId: id,
          type: local!.entry.type,
          deletedAt: AppTime.nowMs(),
          deletedByDeviceId: 'remote',
          deleteRevisionId: Ulid.generate(),
        );
        result.deletedLocally++;
        return;

      case SyncAction.recoverConflictCopy:
        await _repo.createRecoveredCopy(source: local!, deviceName: _deviceName);
        await _repo.applyRemoteTombstone(
          entryId: id,
          type: local.entry.type,
          deletedAt: AppTime.nowMs(),
          deletedByDeviceId: 'remote',
          deleteRevisionId: Ulid.generate(),
        );
        result.conflicts++;
        result.deletedLocally++;
        return;

      case SyncAction.uploadNew:
      case SyncAction.pushLocal:
        await _push(client, local!, remote, result, passphrase);
        return;

      case SyncAction.pullRemote:
        await _pull(client, id, remote!, result, passphrase);
        return;

      case SyncAction.conflictCopy:
        // G-09: never merge, never overwrite. Keep the remote as the shared
        // truth and fork the local edits into a clearly labelled copy.
        await _repo.createRecoveredCopy(
          source: local!,
          deviceName: _deviceName,
          reasonLabel: 'Conflict',
        );
        await _pull(client, id, remote!, result, passphrase);
        result.conflicts++;
        return;

      case SyncAction.remoteDeleteConflict:
        // X-10: refuse to recreate. Flag it and let the user decide.
        AppLog.warn('sync', 'remote file for $id vanished without a tombstone');
        await _repo.markSyncError(id);
        result.errors.add(
          'The remote file for "${local!.entry.title.isEmpty ? id : local.entry.title}" '
          'disappeared without a delete record. It was left untouched.',
        );
        return;
    }
  }

  Future<void> _push(
    GitHubClient client,
    EntryBundle bundle,
    RemoteFile? remote,
    SyncResult result,
    String? passphrase,
  ) async {
    final entry = bundle.entry;
    final encrypt = _config.encryptSyncEnabled && passphrase != null;

    var body = bundle.isChecklist
        ? ChecklistMatcher.toMarkdownTasks(bundle.lines)
        : entry.body;
    if (encrypt) {
      body = await AppCrypto.encryptText(body, passphrase);
    }

    final file = EntryFile(
      id: entry.id,
      type: EntryType.parse(entry.type),
      title: encrypt ? await AppCrypto.encryptText(entry.title, passphrase) : entry.title,
      body: body,
      colorKey: entry.colorKey,
      isPinned: entry.isPinned,
      pinnedAt: entry.pinnedAt,
      location: EntryLocation.parse(entry.location),
      previousLocationBeforeTrash: entry.previousLocationBeforeTrash,
      checkboxesVisibleInView: entry.checkboxesVisibleInView,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      contentUpdatedAt: entry.contentUpdatedAt,
      metadataUpdatedAt: entry.metadataUpdatedAt,
      archivedAt: entry.archivedAt,
      trashedAt: entry.trashedAt,
      imageIds: bundle.images.map((i) => i.id).toList(),
      encrypted: encrypt,
      conflictOfId: entry.conflictOfId,
    );

    final content = encrypt
        ? file.encode()
        : file.encode(lines: bundle.lines);

    try {
      // X-11: compare-and-swap on the sha we last saw.
      final sha = await client.putFile(
        path: EntryFile.pathFor(entry.id),
        bytes: Uint8List.fromList(utf8.encode(content)),
        message: 'NoteNest: update ${entry.id}',
        expectedSha: remote?.sha ?? entry.lastRemoteSha,
      );
      await _repo.markSynced(
        id: entry.id,
        remoteSha: sha,
        syncedAt: AppTime.nowMs(),
      );
      result.pushed++;
    } on GitHubException catch (e) {
      if (e.isConflict) {
        // Someone moved the file between our listing and our write.
        AppLog.warn('sync', 'sha conflict on ${entry.id}, forking a copy');
        await _repo.createRecoveredCopy(
          source: bundle,
          deviceName: _deviceName,
          reasonLabel: 'Conflict',
        );
        final fresh = await client.getFile(EntryFile.pathFor(entry.id));
        if (fresh != null) {
          await _pull(client, entry.id, fresh, result, passphrase);
        }
        result.conflicts++;
      } else {
        rethrow;
      }
    }
  }

  Future<void> _pull(
    GitHubClient client,
    String id,
    RemoteFile remote,
    SyncResult result,
    String? passphrase,
  ) async {
    final full = remote.bytes != null ? remote : await client.getFile(remote.path);
    if (full == null) return;

    var parsed = EntryFile.decode(full.text, fallbackId: id);
    if (parsed == null) {
      AppLog.warn('sync', 'could not parse remote file for $id');
      return;
    }

    var title = parsed.title;
    var body = parsed.body;
    var lines = parsed.lines;

    if (parsed.encrypted) {
      if (passphrase == null) {
        result.errors.add(
          'Entry $id is encrypted but no sync passphrase is set.',
        );
        return;
      }
      try {
        title = await AppCrypto.decryptText(title, passphrase);
        body = await AppCrypto.decryptText(body, passphrase);
        lines = parsed.type.isChecklist
            ? ChecklistMatcher.parseMarkdownTasks(body)
            : const [];
      } catch (e) {
        result.errors.add('Could not decrypt $id: ${AppLog.redact(e)}');
        return;
      }
    }

    final editorBody = parsed.type.isChecklist
        ? ChecklistMatcher.toBody(lines)
        : body;

    await _repo.upsertFromRemote(
      id: id,
      companion: EntriesCompanion(
        id: Value(id),
        type: Value(parsed.type.value),
        title: Value(title),
        body: Value(editorBody),
        colorKey: Value(parsed.colorKey),
        isPinned: Value(parsed.isPinned),
        pinnedAt: Value(parsed.pinnedAt),
        location: Value(parsed.location.value),
        previousLocationBeforeTrash: Value(parsed.previousLocationBeforeTrash),
        checkboxesVisibleInView: Value(parsed.checkboxesVisibleInView),
        createdAt: Value(parsed.createdAt),
        updatedAt: Value(parsed.updatedAt),
        contentUpdatedAt: Value(parsed.contentUpdatedAt),
        metadataUpdatedAt: Value(parsed.metadataUpdatedAt),
        archivedAt: Value(parsed.archivedAt),
        trashedAt: Value(parsed.trashedAt),
        localChanged: const Value(false),
        lastSyncedAt: Value(AppTime.nowMs()),
        lastRemoteSha: Value(full.sha),
        syncStatus: Value(SyncStatus.synced.value),
        conflictOfId: Value(parsed.conflictOfId),
      ),
      lines: parsed.type.isChecklist ? lines : null,
    );

    // Pull down any images this entry references that we do not have yet.
    for (final imageId in parsed.imageIds) {
      await _pullImage(client, id, imageId, result);
    }

    result.pulled++;
  }

  // ---------------------------------------------------------------------
  // Images (IMG-08)
  // ---------------------------------------------------------------------

  Future<void> _syncImages(GitHubClient client, SyncResult result) async {
    // Push new local images.
    final bundles = await _repo.allEntriesForSync();
    for (final bundle in bundles) {
      for (final image in bundle.images) {
        if (image.syncStatus == SyncStatus.synced.value && !image.localChanged) {
          continue;
        }
        try {
          final file = File(image.localPath);
          if (!file.existsSync()) continue;
          final bytes = await file.readAsBytes();
          final path = '${RepoPaths.images}/${image.fileName}';
          final existing = await client.getFile(path);
          final sha = await client.putFile(
            path: path,
            bytes: bytes,
            message: 'NoteNest: image ${image.id}',
            expectedSha: existing?.sha,
          );
          await _repo.markImageSynced(image.id, path, sha);
          result.imagesUp++;
        } catch (e) {
          AppLog.warn('sync', 'image ${image.id} upload failed: $e');
        }
      }
    }

    // Remove images the user deleted.
    for (final image in await _repo.pendingImageDeletes()) {
      try {
        await client.deleteByPath(
          '${RepoPaths.images}/${image.fileName}',
          'NoteNest: delete image ${image.id}',
        );
        await client.deleteByPath(
          '${RepoPaths.thumbnails}/${image.id}.jpg',
          'NoteNest: delete thumbnail ${image.id}',
        );
        await _images.deleteThumbnail(image.id);
        await _repo.purgeImageRecord(image.id);
      } catch (e) {
        AppLog.warn('sync', 'image delete failed: $e');
      }
    }
  }

  Future<void> _pullImage(
    GitHubClient client,
    String entryId,
    String imageId,
    SyncResult result,
  ) async {
    final existing = await _repo.imagesFor(entryId);
    if (existing.any((i) => i.id == imageId)) return;

    for (final ext in const ['.jpg', '.png', '.jpeg', '.webp']) {
      final path = '${RepoPaths.images}/$imageId$ext';
      try {
        final file = await client.getFile(path);
        if (file?.bytes == null) continue;

        final localPath = await _images.writeRemoteImage('$imageId$ext', file!.bytes!);
        await _repo.addImageRecord(
          entryId: entryId,
          id: imageId,
          fileName: '$imageId$ext',
          localPath: localPath,
          mimeType: ext == '.png' ? 'image/png' : 'image/jpeg',
          sizeBytes: file.bytes!.length,
        );
        await _repo.markImageSynced(imageId, path, file.sha);
        result.imagesDown++;
        return;
      } catch (_) {
        continue;
      }
    }
  }
}
