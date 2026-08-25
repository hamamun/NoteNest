import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'database.g.dart';

/// D-01: the single content table. Notes and checklists share it because they
/// differ only in how the body is rendered.
class Entries extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // note | checklist
  TextColumn get title => text().withDefault(const Constant(''))();

  /// Markdown for notes, raw multiline text for checklists.
  TextColumn get body => text().withDefault(const Constant(''))();

  TextColumn get colorKey => text().withDefault(const Constant('default'))();

  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  IntColumn get pinnedAt => integer().nullable()();
  IntColumn get pinOrder => integer().nullable()(); // LATER, reserved

  TextColumn get location => text().withDefault(const Constant('active'))();
  TextColumn get previousLocationBeforeTrash => text().nullable()();

  /// K-06: per-checklist checkbox visibility, default on.
  BoolColumn get checkboxesVisibleInView =>
      boolean().withDefault(const Constant(true))();

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get contentUpdatedAt => integer()();
  IntColumn get metadataUpdatedAt => integer()();

  /// S-09: local only. Never written to GitHub.
  IntColumn get lastViewedAtLocal => integer().nullable()();

  IntColumn get archivedAt => integer().nullable()();
  IntColumn get trashedAt => integer().nullable()();
  IntColumn get permanentlyDeletedAt => integer().nullable()();
  BoolColumn get contentDeleted => boolean().withDefault(const Constant(false))();

  BoolColumn get localChanged => boolean().withDefault(const Constant(true))();
  IntColumn get lastSyncedAt => integer().nullable()();
  TextColumn get lastRemoteSha => text().nullable()();
  TextColumn get lastLocalHash => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  /// X-09: set on recovered conflict copies so the UI can badge them.
  TextColumn get conflictOfId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// D-02: internal checklist rows. The user never sees these as separate
/// controls (N-08) but they carry the checked state (M-07).
class ChecklistItems extends Table {
  TextColumn get id => text()();
  TextColumn get entryId => text()();

  /// Dart-side name is [itemText] because a getter named `text` would collide
  /// with the inherited `Table.text()` column builder. The SQLite column
  /// itself stays `text`, so existing databases need no migration.
  TextColumn get itemText => text().named('text')();
  BoolColumn get checked => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// D-03: image attachments. Images only (IMG-01).
class EntryImages extends Table {
  TextColumn get id => text()();
  TextColumn get entryId => text()();
  TextColumn get fileName => text()();
  TextColumn get localPath => text()();
  TextColumn get remotePath => text().nullable()();
  TextColumn get mimeType => text()();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  BoolColumn get localChanged => boolean().withDefault(const Constant(true))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  TextColumn get lastRemoteSha => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// D-04/X-01: delete records. Kept forever in v1 (X-13).
class Tombstones extends Table {
  TextColumn get entryId => text()();
  TextColumn get type => text()();
  IntColumn get deletedAt => integer()();
  TextColumn get deletedByDeviceId => text()();
  TextColumn get deleteRevisionId => text()();
  TextColumn get lastKnownNotePath => text().nullable()();

  /// Comma separated image ids (X-14).
  TextColumn get lastKnownImageIds => text().withDefault(const Constant(''))();
  TextColumn get reason => text().withDefault(const Constant('delete_forever'))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  TextColumn get remoteSha => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {entryId};
}

/// D-05: non-secret sync configuration. The token is NEVER stored here.
class SyncConfigs extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  BoolColumn get syncEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get githubOwner => text().withDefault(const Constant(''))();
  TextColumn get githubRepo => text().withDefault(const Constant(''))();
  TextColumn get githubBranch => text().withDefault(const Constant('main'))();
  IntColumn get lastSyncAt => integer().nullable()();
  TextColumn get lastSyncStatus => text().withDefault(const Constant(''))();
  TextColumn get lastRemoteCommit => text().nullable()();

  /// V2: auto sync on open / on network return (G-16).
  BoolColumn get autoSyncEnabled => boolean().withDefault(const Constant(false))();

  /// V3: encrypt note bodies before upload.
  BoolColumn get encryptSyncEnabled => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// D-06: device-local preferences as a simple key/value store.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// V3: local note history. Written before each destructive content change.
class EntryRevisions extends Table {
  TextColumn get id => text()();
  TextColumn get entryId => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  IntColumn get createdAt => integer()();
  TextColumn get source => text().withDefault(const Constant('local'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// D-07 (v2+): known devices, used for smarter tombstone retention later.
class Devices extends Table {
  TextColumn get deviceId => text()();
  TextColumn get deviceName => text()();
  TextColumn get platform => text()();
  IntColumn get firstSeenAt => integer()();
  IntColumn get lastSyncAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {deviceId};
}

@DriftDatabase(
  tables: [
    Entries,
    ChecklistItems,
    EntryImages,
    Tombstones,
    SyncConfigs,
    AppSettings,
    EntryRevisions,
    Devices,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Used by tests to run against an in-memory database.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
          // Seed the single sync config row.
          await into(syncConfigs).insert(
            const SyncConfigsCompanion(id: Value(1)),
            mode: InsertMode.insertOrIgnore,
          );
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await customStatement('DROP TABLE IF EXISTS entry_tags');
            await customStatement('DROP TABLE IF EXISTS tags');
          }
          await _createIndexes();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await into(syncConfigs).insert(
            const SyncConfigsCompanion(id: Value(1)),
            mode: InsertMode.insertOrIgnore,
          );
        },
      );

  /// D-09: the indexes that keep the home list fast.
  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_entries_location_pin_updated '
      'ON entries (location, is_pinned, updated_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_entries_type ON entries (type)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_checklist_entry_order '
      'ON checklist_items (entry_id, sort_order)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_images_entry ON entry_images (entry_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_revisions_entry ON entry_revisions (entry_id, created_at)',
    );
  }
}

/// D-10: the database lives in the platform application-support directory,
/// never next to the executable (BLD-04).
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'notenest.sqlite'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    sqlite3.tempDirectory = (await getTemporaryDirectory()).path;

    return NativeDatabase.createInBackground(file);
  });
}
