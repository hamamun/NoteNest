import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import '../db/database.dart';
import '../models/enums.dart';

/// D-06: device-local preferences.
///
/// These are deliberately NOT synced (U-12, S-10): card layout, sort order,
/// font size and theme are per-device tastes, and syncing them would make one
/// device silently rearrange another.
class SettingsRepository extends ChangeNotifier {
  SettingsRepository(this._db);

  final AppDatabase _db;
  final Map<String, String> _cache = <String, String>{};
  bool _loaded = false;

  // Keys
  static const _kCardViewMode = 'card_view_mode';
  static const _kSortMode = 'sort_mode';
  static const _kFontStep = 'content_font_step';
  static const _kClickableUrls = 'clickable_urls_enabled';
  static const _kThemeMode = 'theme_mode';
  static const _kBackupEnabled = 'backup_enabled';
  static const _kBackupFrequency = 'backup_frequency';
  static const _kLastBackupAt = 'last_backup_at';
  static const _kLastBackupStatus = 'last_backup_status';
  static const _kBackupEncryption = 'backup_encryption_enabled';
  static const _kDeviceId = 'device_id';
  static const _kDeviceName = 'device_name';
  static const _kMarkdownPreview = 'markdown_preview_enabled';
  static const _kObsidianFolder = 'obsidian_folder_path';
  static const _kFirstRunDone = 'first_run_done';

  Future<void> load() async {
    final rows = await _db.select(_db.appSettings).get();
    _cache
      ..clear()
      ..addEntries(rows.map((r) => MapEntry(r.key, r.value)));
    _loaded = true;
    notifyListeners();
  }

  bool get isLoaded => _loaded;

  String? _get(String key) => _cache[key];

  Future<void> _set(String key, String value) async {
    _cache[key] = value;
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value),
        );
    notifyListeners();
  }

  // --- U-11/U-12 ---
  CardViewMode get cardViewMode => CardViewMode.parse(_get(_kCardViewMode));
  Future<void> setCardViewMode(CardViewMode mode) =>
      _set(_kCardViewMode, mode.value);

  // --- S-08/S-10 ---
  SortMode get sortMode => SortMode.parse(_get(_kSortMode));
  Future<void> setSortMode(SortMode mode) => _set(_kSortMode, mode.value);

  // --- SET-01..SET-05 ---
  FontSizeStep get fontStep => FontSizeStep.parse(_get(_kFontStep));
  double get contentFontScale => fontStep.scale;
  Future<void> setFontStep(FontSizeStep step) => _set(_kFontStep, step.value);

  Future<void> nudgeFontSize(int direction) async {
    final steps = FontSizeStep.values;
    final index = steps.indexOf(fontStep);
    final next = (index + direction).clamp(0, steps.length - 1);
    await setFontStep(steps[next]);
  }

  // --- SET-06..SET-12 ---
  bool get clickableUrls => (_get(_kClickableUrls) ?? 'true') == 'true';
  Future<void> setClickableUrls(bool value) =>
      _set(_kClickableUrls, value.toString());

  // --- SET-14 ---
  ThemeMode get themeMode => switch (_get(_kThemeMode)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
  Future<void> setThemeMode(ThemeMode mode) => _set(_kThemeMode, mode.name);

  // --- V2: markdown preview toggle ---
  bool get markdownPreview => (_get(_kMarkdownPreview) ?? 'true') == 'true';
  Future<void> setMarkdownPreview(bool value) =>
      _set(_kMarkdownPreview, value.toString());

  // --- B-02 ---
  bool get backupEnabled => (_get(_kBackupEnabled) ?? 'false') == 'true';
  Future<void> setBackupEnabled(bool value) =>
      _set(_kBackupEnabled, value.toString());

  BackupFrequency get backupFrequency =>
      BackupFrequency.parse(_get(_kBackupFrequency));
  Future<void> setBackupFrequency(BackupFrequency value) =>
      _set(_kBackupFrequency, value.value);

  int? get lastBackupAt => int.tryParse(_get(_kLastBackupAt) ?? '');
  Future<void> setLastBackupAt(int ms) => _set(_kLastBackupAt, ms.toString());

  String get lastBackupStatus => _get(_kLastBackupStatus) ?? '';
  Future<void> setLastBackupStatus(String status) =>
      _set(_kLastBackupStatus, status);

  // --- B-15 ---
  bool get backupEncryption => (_get(_kBackupEncryption) ?? 'false') == 'true';
  Future<void> setBackupEncryption(bool value) =>
      _set(_kBackupEncryption, value.toString());

  // --- V3: Obsidian-compatible local folder ---
  String? get obsidianFolder {
    final value = _get(_kObsidianFolder);
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<void> setObsidianFolder(String? path) =>
      _set(_kObsidianFolder, path ?? '');

  // --- P-07 ---
  String? get deviceId => _get(_kDeviceId);
  Future<void> setDeviceId(String id) => _set(_kDeviceId, id);

  String get deviceName => _get(_kDeviceName) ?? 'This device';
  Future<void> setDeviceName(String name) => _set(_kDeviceName, name);

  bool get firstRunDone => (_get(_kFirstRunDone) ?? 'false') == 'true';
  Future<void> setFirstRunDone() => _set(_kFirstRunDone, 'true');
}
