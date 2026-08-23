import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/database.dart';

/// D-05: the non-secret half of the sync configuration.
/// The token lives in [SecureStore] and never touches this table (SEC-08).
class SyncConfigRepository extends ChangeNotifier {
  SyncConfigRepository(this._db);

  final AppDatabase _db;
  SyncConfig? _cached;

  SyncConfig? get value => _cached;

  bool get isConfigured =>
      _cached != null &&
      _cached!.githubOwner.isNotEmpty &&
      _cached!.githubRepo.isNotEmpty;

  bool get syncEnabled => _cached?.syncEnabled ?? false;
  bool get autoSyncEnabled => _cached?.autoSyncEnabled ?? false;
  bool get encryptSyncEnabled => _cached?.encryptSyncEnabled ?? false;
  String get owner => _cached?.githubOwner ?? '';
  String get repo => _cached?.githubRepo ?? '';
  String get branch => _cached?.githubBranch ?? 'main';
  int? get lastSyncAt => _cached?.lastSyncAt;
  String get lastSyncStatus => _cached?.lastSyncStatus ?? '';

  Future<void> load() async {
    _cached = await (_db.select(_db.syncConfigs)..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    if (_cached == null) {
      await _db.into(_db.syncConfigs).insert(
            const SyncConfigsCompanion(id: Value(1)),
            mode: InsertMode.insertOrIgnore,
          );
      _cached = await (_db.select(_db.syncConfigs)..where((t) => t.id.equals(1)))
          .getSingleOrNull();
    }
    notifyListeners();
  }

  Future<void> _write(SyncConfigsCompanion companion) async {
    await (_db.update(_db.syncConfigs)..where((t) => t.id.equals(1)))
        .write(companion);
    await load();
  }

  /// SEC-03: called only after Test Connection succeeds (SEC-06).
  Future<void> saveConnection({
    required String owner,
    required String repo,
    required String branch,
  }) =>
      _write(SyncConfigsCompanion(
        githubOwner: Value(owner.trim()),
        githubRepo: Value(repo.trim()),
        githubBranch: Value(branch.trim().isEmpty ? 'main' : branch.trim()),
        syncEnabled: const Value(true),
      ));

  /// SEC-11: Disable keeps the token and the configuration.
  Future<void> setSyncEnabled(bool enabled) =>
      _write(SyncConfigsCompanion(syncEnabled: Value(enabled)));

  Future<void> setAutoSync(bool enabled) =>
      _write(SyncConfigsCompanion(autoSyncEnabled: Value(enabled)));

  Future<void> setEncryptSync(bool enabled) =>
      _write(SyncConfigsCompanion(encryptSyncEnabled: Value(enabled)));

  /// SEC-12: Disconnect clears the repo configuration too.
  Future<void> clearConnection() => _write(const SyncConfigsCompanion(
        syncEnabled: Value(false),
        githubOwner: Value(''),
        githubRepo: Value(''),
        githubBranch: Value('main'),
        lastSyncAt: Value(null),
        lastSyncStatus: Value(''),
        lastRemoteCommit: Value(null),
        autoSyncEnabled: Value(false),
        encryptSyncEnabled: Value(false),
      ));

  /// G-15
  Future<void> recordSync({
    required int at,
    required String status,
    String? commit,
  }) =>
      _write(SyncConfigsCompanion(
        lastSyncAt: Value(at),
        lastSyncStatus: Value(status),
        lastRemoteCommit: Value(commit),
      ));
}
