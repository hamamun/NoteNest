import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// SEC-07/SEC-08/B-16: the only place secrets are allowed to live.
///
/// Backed by Windows Credential Manager and the Android Keystore. Nothing in
/// this class ever writes to SQLite, to a file, or to a log line.
class SecureStore {
  SecureStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            // AndroidOptions must not set `encryptedSharedPreferences`: the
            // Jetpack Security library is deprecated by Google and the plugin
            // auto-migrates existing data to its custom ciphers.
            const FlutterSecureStorage(
              wOptions: WindowsOptions(),
            );

  final FlutterSecureStorage _storage;

  static const _kGithubPat = 'github_pat';
  static const _kBackupPassphrase = 'backup_passphrase';
  static const _kSyncPassphrase = 'sync_passphrase';

  // --- GitHub token (SEC-07) ---

  Future<String?> readToken() => _storage.read(key: _kGithubPat);

  Future<void> writeToken(String token) =>
      _storage.write(key: _kGithubPat, value: token.trim());

  Future<void> deleteToken() => _storage.delete(key: _kGithubPat);

  Future<bool> hasToken() async {
    final token = await readToken();
    return token != null && token.isNotEmpty;
  }

  // --- Backup passphrase (B-16) ---

  Future<String?> readBackupPassphrase() =>
      _storage.read(key: _kBackupPassphrase);

  Future<void> writeBackupPassphrase(String value) =>
      _storage.write(key: _kBackupPassphrase, value: value);

  Future<void> deleteBackupPassphrase() =>
      _storage.delete(key: _kBackupPassphrase);

  Future<bool> hasBackupPassphrase() async {
    final value = await readBackupPassphrase();
    return value != null && value.isNotEmpty;
  }

  // --- V3: encrypted note sync passphrase ---

  Future<String?> readSyncPassphrase() => _storage.read(key: _kSyncPassphrase);

  Future<void> writeSyncPassphrase(String value) =>
      _storage.write(key: _kSyncPassphrase, value: value);

  Future<void> deleteSyncPassphrase() => _storage.delete(key: _kSyncPassphrase);

  Future<bool> hasSyncPassphrase() async {
    final value = await readSyncPassphrase();
    return value != null && value.isNotEmpty;
  }

  /// SEC-12: Disconnect wipes every secret this app owns.
  Future<void> wipeAll() async {
    await deleteToken();
    await deleteBackupPassphrase();
    await deleteSyncPassphrase();
  }
}
