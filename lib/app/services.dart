import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/logging.dart';
import '../core/ulid.dart';
import '../data/db/database.dart';
import '../data/repositories/entry_repository.dart';
import '../data/repositories/image_store.dart';
import '../data/repositories/secure_store.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/sync_config_repository.dart';
import '../features/backup/backup_service.dart';
import '../features/export/export_service.dart';
import '../features/sync/sync_controller.dart';

/// Everything the app needs, constructed once at startup.
///
/// P-07: the device identity is created on first launch and then never
/// changes. Tombstones, conflict-copy titles and backup filenames all depend
/// on it being stable.
class Services {
  Services._({
    required this.db,
    required this.settings,
    required this.syncConfig,
    required this.secureStore,
    required this.entries,
    required this.images,
    required this.exporter,
    required this.backup,
    required this.sync,
    required this.markdownFolder,
    required this.deviceId,
    required this.deviceName,
    required this.appVersion,
  });

  final AppDatabase db;
  final SettingsRepository settings;
  final SyncConfigRepository syncConfig;
  final SecureStore secureStore;
  final EntryRepository entries;
  final ImageStore images;
  final ExportService exporter;
  final BackupService backup;
  final SyncController sync;
  final MarkdownFolderService markdownFolder;
  final String deviceId;
  final String deviceName;
  final String appVersion;

  static Future<Services> bootstrap() async {
    final db = AppDatabase();

    final settings = SettingsRepository(db);
    await settings.load();

    final syncConfig = SyncConfigRepository(db);
    await syncConfig.load();

    // P-07: stable device identity.
    var deviceId = settings.deviceId;
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = Ulid.generate();
      await settings.setDeviceId(deviceId);
    }

    var deviceName = settings.deviceName;
    if (deviceName == 'This device') {
      deviceName = await _resolveDeviceName();
      await settings.setDeviceName(deviceName);
    }

    final appVersion = await _resolveAppVersion();

    final secureStore = SecureStore();
    final images = ImageStore();
    final entries = EntryRepository(db, deviceId: deviceId);

    final sync = SyncController(
      repository: entries,
      config: syncConfig,
      secureStore: secureStore,
      settings: settings,
      imageStore: images,
      deviceId: deviceId,
      deviceName: deviceName,
    );

    final backup = BackupService(
      repository: entries,
      settings: settings,
      config: syncConfig,
      secureStore: secureStore,
      deviceId: deviceId,
      deviceName: deviceName,
      appVersion: appVersion,
    );

    AppLog.info('boot', 'NoteNest $appVersion on $deviceName ($deviceId)');

    return Services._(
      db: db,
      settings: settings,
      syncConfig: syncConfig,
      secureStore: secureStore,
      entries: entries,
      images: images,
      exporter: ExportService(entries),
      backup: backup,
      sync: sync,
      markdownFolder: MarkdownFolderService(entries),
      deviceId: deviceId,
      deviceName: deviceName,
      appVersion: appVersion,
    );
  }

  static Future<String> _resolveDeviceName() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return '${android.manufacturer} ${android.model}'.trim();
      }
      if (Platform.isWindows) {
        final windows = await info.windowsInfo;
        return windows.computerName;
      }
      if (Platform.isLinux) {
        final linux = await info.linuxInfo;
        return linux.prettyName;
      }
      if (Platform.isMacOS) {
        final mac = await info.macOsInfo;
        return mac.computerName;
      }
    } catch (e) {
      AppLog.warn('boot', 'device name lookup failed: $e');
    }
    return Platform.operatingSystem;
  }

  static Future<String> _resolveAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return '1.0.0+1';
    }
  }

  /// Runs the post-sync backup check (B-06).
  Future<void> maybeBackupAfterSync() async {
    try {
      final result = await backup.runIfDue();
      if (result != null) {
        AppLog.info('backup', result.message);
      }
    } catch (e) {
      AppLog.warn('backup', 'scheduled backup failed: $e');
    }
  }

  @visibleForTesting
  Future<void> close() => db.close();
}
