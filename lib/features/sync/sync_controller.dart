import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../core/logging.dart';
import '../../core/time.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/image_store.dart';
import '../../data/repositories/secure_store.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/sync_config_repository.dart';
import 'github_client.dart';
import 'sync_engine.dart';

/// G-13: the sync states surfaced in the UI.
enum SyncUiState {
  notConnected,
  connected,
  syncing,
  failed,
  reconnectRequired,
}

/// Background poll while the app is in the foreground.
///
/// 3 minutes is a compromise: frequent enough that two devices in use at the
/// same time stay close without hammering GitHub (the engine still no-ops
/// when nothing changed). Launch, network-return, and the Sync button are
/// independent of this timer.
const Duration periodicSyncInterval = Duration(minutes: 3);

/// Owns sync state for the whole app: the manual Sync button (G-11), the
/// status line (G-13), and V2 auto-sync on launch and on network return.
class SyncController extends ChangeNotifier {
  SyncController({
    required EntryRepository repository,
    required SyncConfigRepository config,
    required SecureStore secureStore,
    required SettingsRepository settings,
    required ImageStore imageStore,
    required String deviceId,
    required String deviceName,
  })  : _repo = repository,
        _config = config,
        _secure = secureStore,
        _settings = settings,
        _engine = SyncEngine(
          repository: repository,
          config: config,
          imageStore: imageStore,
          deviceId: deviceId,
          deviceName: deviceName,
        );

  final EntryRepository _repo;
  final SyncConfigRepository _config;
  final SecureStore _secure;
  final SettingsRepository _settings;
  final SyncEngine _engine;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicTimer;

  SyncUiState _state = SyncUiState.notConnected;
  String _message = '';
  bool _hasToken = false;
  bool _wasOffline = false;

  SyncUiState get state => _state;
  String get message => _message;
  bool get isSyncing => _state == SyncUiState.syncing;
  bool get hasToken => _hasToken;

  /// G-12: the Sync button is only usable when everything is in place.
  bool get canSync =>
      _config.syncEnabled && _hasToken && _state != SyncUiState.syncing;

  int? get lastSyncAt => _config.lastSyncAt;

  String get statusLabel {
    switch (_state) {
      case SyncUiState.syncing:
        return 'Syncing...';
      case SyncUiState.notConnected:
        return 'Sync not set up';
      case SyncUiState.reconnectRequired:
        return 'Reconnect GitHub';
      case SyncUiState.failed:
        return _message.isEmpty ? 'Sync failed' : _message;
      case SyncUiState.connected:
        final at = _config.lastSyncAt;
        if (at == null) return 'Connected';
        return 'Last synced ${AppTime.relative(at)}';
    }
  }

  Future<void> init() async {
    await refreshState();

    // V2: auto sync when the network comes back.
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online && _wasOffline && _config.autoSyncEnabled && canSync) {
        AppLog.info('sync', 'network returned, auto-syncing');
        unawaited(syncNow(silent: true));
      }
      _wasOffline = !online;
    });

    // V2: auto sync when the app opens.
    if (_config.autoSyncEnabled && canSync) {
      unawaited(syncNow(silent: true));
    }

    // V3-lite: background sync while the app is running.
    _periodicTimer = Timer.periodic(periodicSyncInterval, (_) {
      if (_config.autoSyncEnabled && canSync) {
        unawaited(syncNow(silent: true));
      }
    });
  }

  Future<void> refreshState() async {
    _hasToken = await _secure.hasToken();

    if (!_config.isConfigured || !_config.syncEnabled) {
      _state = SyncUiState.notConnected;
    } else if (!_hasToken) {
      // SEC-13: configuration says enabled but the secret is gone.
      _state = SyncUiState.reconnectRequired;
      _message = 'The saved token is missing. Reconnect GitHub in Settings.';
    } else {
      _state = SyncUiState.connected;
    }
    notifyListeners();
  }

  /// G-11/G-12: the manual Sync button.
  Future<SyncResult?> syncNow({bool silent = false}) async {
    if (!_config.syncEnabled) {
      _state = SyncUiState.notConnected;
      notifyListeners();
      return null;
    }

    final token = await _secure.readToken();
    if (token == null || token.isEmpty) {
      _state = SyncUiState.reconnectRequired;
      _message = 'No saved token. Reconnect GitHub in Settings.';
      notifyListeners();
      return null;
    }

    if (_engine.isRunning) return null;

    _state = SyncUiState.syncing;
    _message = 'Syncing...';
    notifyListeners();

    final client = GitHubClient(
      owner: _config.owner,
      repo: _config.repo,
      branch: _config.branch,
      token: token,
    );

    try {
      final passphrase = _config.encryptSyncEnabled
          ? await _secure.readSyncPassphrase()
          : null;

      final result = await _engine.run(
        client: client,
        encryptionPassphrase: passphrase,
      );

      _state = result.ok ? SyncUiState.connected : SyncUiState.failed;
      _message = result.summary;
      notifyListeners();
      return result;
    } finally {
      client.close();
    }
  }

  /// SEC-11
  Future<void> setEnabled(bool enabled) async {
    await _config.setSyncEnabled(enabled);
    await refreshState();
  }

  /// SEC-12: Disconnect wipes the token and the configuration but never the
  /// notes themselves.
  Future<void> disconnect({required bool clearConfig}) async {
    await _secure.deleteToken();
    await _secure.deleteSyncPassphrase();
    if (clearConfig) {
      await _config.clearConnection();
    } else {
      await _config.setSyncEnabled(false);
    }
    await refreshState();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _periodicTimer?.cancel();
    super.dispose();
  }

  EntryRepository get repository => _repo;
  SettingsRepository get settings => _settings;
}
