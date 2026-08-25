import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../core/crypto.dart';
import '../../core/logging.dart';
import '../../core/time.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/checklist_matcher.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/secure_store.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/sync_config_repository.dart';
import '../sync/entry_file_codec.dart';
import '../sync/github_client.dart';

enum BackupKind {
  weekly('weekly'),
  monthly('monthly'),
  manual('manual');

  const BackupKind(this.folder);
  final String folder;
}

class BackupResult {
  const BackupResult({required this.ok, required this.message, this.path});
  final bool ok;
  final String message;
  final String? path;
}

/// B-01..B-18: dated snapshots uploaded to the same private repository.
///
/// A backup is deliberately different from a sync: sync keeps devices in step,
/// a backup is a frozen recovery point that includes archive, trash AND the
/// tombstones (B-11), so restoring one can never resurrect a deleted note.
class BackupService {
  BackupService({
    required EntryRepository repository,
    required SettingsRepository settings,
    required SyncConfigRepository config,
    required SecureStore secureStore,
    required String deviceId,
    required String deviceName,
    required String appVersion,
  })  : _repo = repository,
        _settings = settings,
        _config = config,
        _secure = secureStore,
        _deviceId = deviceId,
        _deviceName = deviceName,
        _appVersion = appVersion;

  final EntryRepository _repo;
  final SettingsRepository _settings;
  final SyncConfigRepository _config;
  final SecureStore _secure;
  final String _deviceId;
  final String _deviceName;
  final String _appVersion;

  /// B-04/B-05: is a scheduled backup due?
  bool isDue() {
    if (!_settings.backupEnabled) return false;
    switch (_settings.backupFrequency) {
      case BackupFrequency.disabled:
        return false;
      case BackupFrequency.weekly:
        return AppTime.olderThanDays(_settings.lastBackupAt, 7);
      case BackupFrequency.monthly:
        return AppTime.inPreviousMonth(_settings.lastBackupAt) ||
            AppTime.olderThanDays(_settings.lastBackupAt, 30);
    }
  }

  /// B-06: called after a successful sync, never before it.
  Future<BackupResult?> runIfDue() async {
    if (!isDue()) return null;
    final kind = _settings.backupFrequency == BackupFrequency.monthly
        ? BackupKind.monthly
        : BackupKind.weekly;
    return run(kind);
  }

  /// B-07: Backup Now works even when the schedule is disabled.
  Future<BackupResult> run(BackupKind kind) async {
    // B-03: backups live in the sync repository, so sync must be connected.
    if (!_config.isConfigured) {
      return const BackupResult(
        ok: false,
        message: 'Connect GitHub Sync first.',
      );
    }
    final token = await _secure.readToken();
    if (token == null || token.isEmpty) {
      return const BackupResult(
        ok: false,
        message: 'No saved GitHub token. Reconnect GitHub in Settings.',
      );
    }

    final client = GitHubClient(
      owner: _config.owner,
      repo: _config.repo,
      branch: _config.branch,
      token: token,
    );

    try {
      final now = AppTime.nowMs();
      var bytes = await buildArchive(now);
      var fileName = _fileNameFor(kind, now);

      // B-15/B-17: optional encryption, off by default.
      if (_settings.backupEncryption) {
        final passphrase = await _secure.readBackupPassphrase();
        if (passphrase == null || passphrase.isEmpty) {
          return const BackupResult(
            ok: false,
            message: 'Backup encryption is on but no passphrase is set.',
          );
        }
        bytes = await AppCrypto.encrypt(plain: bytes, passphrase: passphrase);
        fileName = '$fileName.enc';
      }

      final path = 'backups/${kind.folder}/$fileName';
      final existing = await client.getFile(path);
      await client.putFile(
        path: path,
        bytes: bytes,
        message: 'NoteNest: ${kind.folder} backup $fileName',
        expectedSha: existing?.sha,
      );

      // B-12
      await _settings.setLastBackupAt(now);
      await _settings.setLastBackupStatus('Backed up to $path');

      AppLog.info('backup', 'uploaded $path (${bytes.length} bytes)');
      return BackupResult(ok: true, message: 'Backup saved to $path', path: path);
    } on GitHubException catch (e) {
      await _settings.setLastBackupStatus('Failed: ${e.message}');
      return BackupResult(ok: false, message: e.message);
    } catch (e) {
      AppLog.error('backup', 'failed', e);
      await _settings.setLastBackupStatus('Failed');
      return BackupResult(ok: false, message: AppLog.redact(e));
    } finally {
      client.close();
    }
  }

  /// B-08: `notes-backup-weekly-2026-08-23-device-my-pc.zip`
  String _fileNameFor(BackupKind kind, int now) {
    final device = _deviceName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final stamp = switch (kind) {
      BackupKind.monthly => AppTime.monthStamp(now),
      BackupKind.weekly => AppTime.dateStamp(now),
      BackupKind.manual => AppTime.fileStamp(now),
    };
    return 'notes-backup-${kind.folder}-$stamp-device-$device.zip';
  }

  /// B-09/B-10/B-11: the zip.
  Future<Uint8List> buildArchive(int now) async {
    final archive = Archive();

    // Everything, including archive and trash (B-11).
    final bundles = await _repo.allEntriesIncludingDeleted();
    final live = bundles
        .where((b) => b.location != EntryLocation.deleted)
        .toList(growable: false);

    var imageCount = 0;

    for (final bundle in live) {
      final file = EntryFile(
        id: bundle.entry.id,
        type: bundle.type,
        title: bundle.entry.title,
        body: bundle.entry.body,
        colorKey: bundle.entry.colorKey,
        isPinned: bundle.entry.isPinned,
        pinnedAt: bundle.entry.pinnedAt,
        location: bundle.location,
        previousLocationBeforeTrash: bundle.entry.previousLocationBeforeTrash,
        checkboxesVisibleInView: bundle.entry.checkboxesVisibleInView,
        createdAt: bundle.entry.createdAt,
        updatedAt: bundle.entry.updatedAt,
        contentUpdatedAt: bundle.entry.contentUpdatedAt,
        metadataUpdatedAt: bundle.entry.metadataUpdatedAt,
        archivedAt: bundle.entry.archivedAt,
        trashedAt: bundle.entry.trashedAt,
        imageIds: bundle.images.map((i) => i.id).toList(),
      );

      // B-09: notes/ and lists/ are separate folders inside the archive.
      final folder = bundle.isChecklist ? 'lists' : 'notes';
      final content = utf8.encode(file.encode(lines: bundle.lines));
      archive.addFile(
        ArchiveFile('$folder/${bundle.entry.id}.md', content.length, content),
      );

      for (final image in bundle.images) {
        final imageFile = File(image.localPath);
        if (!imageFile.existsSync()) continue;
        final data = await imageFile.readAsBytes();
        archive.addFile(
          ArchiveFile('images/${image.fileName}', data.length, data),
        );
        imageCount++;
      }
    }

    // B-11: tombstones travel with the backup.
    for (final tombstone in await _repo.allTombstones()) {
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
      final content = utf8.encode(jsonEncode(payload));
      archive.addFile(
        ArchiveFile(
          'tombstones/${tombstone.entryId}.json',
          content.length,
          content,
        ),
      );
    }

    // B-10: manifest.
    final manifest = <String, dynamic>{
      'backup_version': 1,
      'created_at': AppTime.toIso(now),
      'created_by_device_id': _deviceId,
      'created_by_device_name': _deviceName,
      'app_version': _appVersion,
      'item_count': live.length,
      'image_count': imageCount,
      'note_count': live.where((b) => !b.isChecklist).length,
      'list_count': live.where((b) => b.isChecklist).length,
      'archived_count':
          live.where((b) => b.location == EntryLocation.archive).length,
      'trashed_count':
          live.where((b) => b.location == EntryLocation.trash).length,
      'tombstone_count': (await _repo.allTombstones()).length,
    };
    final manifestBytes =
        utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest));
    archive.addFile(
      ArchiveFile('backup.json', manifestBytes.length, manifestBytes),
    );

    // A plain-text index so a human opening the zip can find things.
    final index = StringBuffer()
      ..writeln('NoteNest backup')
      ..writeln('Created: ${AppTime.full(now)}')
      ..writeln('Device: $_deviceName')
      ..writeln('Items: ${live.length}')
      ..writeln()
      ..writeln('Note: deleting a backup later does not remove it from the')
      ..writeln('GitHub commit history.');
    for (final bundle in live) {
      final folder = bundle.isChecklist ? 'lists' : 'notes';
      index.writeln(
        '$folder/${bundle.entry.id}.md  '
        '[${bundle.location.value}]  '
        '${bundle.entry.title.isEmpty ? "(untitled)" : bundle.entry.title}',
      );
    }
    final indexBytes = utf8.encode(index.toString());
    archive.addFile(ArchiveFile('INDEX.txt', indexBytes.length, indexBytes));

    return Uint8List.fromList(ZipEncoder().encode(archive) ?? <int>[]);
  }

  /// B-18 support: builds a backup locally without uploading, so the user can
  /// keep an offline copy from Settings.
  Future<Uint8List> buildLocalArchive() async {
    var bytes = await buildArchive(AppTime.nowMs());
    if (_settings.backupEncryption) {
      final passphrase = await _secure.readBackupPassphrase();
      if (passphrase != null && passphrase.isNotEmpty) {
        bytes = await AppCrypto.encrypt(plain: bytes, passphrase: passphrase);
      }
    }
    return bytes;
  }

  /// Preview text used by the Settings screen.
  Future<String> describeContents() async {
    final bundles = await _repo.allEntriesIncludingDeleted();
    final live =
        bundles.where((b) => b.location != EntryLocation.deleted).toList();
    final tombstones = await _repo.allTombstones();
    return '${live.length} items, '
        '${live.where((b) => b.location == EntryLocation.archive).length} archived, '
        '${live.where((b) => b.location == EntryLocation.trash).length} in trash, '
        '${tombstones.length} delete records';
  }
}

/// V2: import/export a plain Markdown folder, Obsidian-compatible (V3).
class MarkdownFolderService {
  MarkdownFolderService(this._repo);

  final EntryRepository _repo;

  /// Writes every entry as a readable `.md` file into [folderPath].
  Future<int> exportFolder(String folderPath) async {
    final dir = Directory(folderPath);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final bundles = await _repo.allEntriesForSync();
    var written = 0;

    for (final bundle in bundles) {
      final title = bundle.entry.title.trim();
      final safe = (title.isEmpty ? bundle.entry.id : title)
          .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ')
          .trim();

      final buffer = StringBuffer()
        ..writeln('# ${title.isEmpty ? "Untitled" : title}')
        ..writeln();
      if (bundle.isChecklist) {
        buffer.writeln(ChecklistMatcher.toMarkdownTasks(bundle.lines));
      } else {
        buffer.writeln(bundle.entry.body);
      }

      final file = File('$folderPath/$safe.md');
      await file.writeAsString(buffer.toString());
      written++;
    }
    return written;
  }

  /// Imports every `.md` file in [folderPath] as a new note.
  Future<int> importFolder(String folderPath) async {
    final dir = Directory(folderPath);
    if (!dir.existsSync()) return 0;

    var imported = 0;
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.md')) continue;

      final raw = await entity.readAsString();
      final parsed = EntryFile.decode(raw);

      final looksLikeChecklist = RegExp(r'^\s*[-*]\s+\[[ xX]\]', multiLine: true)
          .hasMatch(raw);
      final type = parsed?.type ??
          (looksLikeChecklist ? EntryType.checklist : EntryType.note);

      var title = parsed?.title ?? '';
      var body = parsed?.body ?? raw;

      if (title.isEmpty) {
        final heading = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(body);
        if (heading != null) {
          title = heading.group(1)!.trim();
          body = body.replaceFirst(heading.group(0)!, '').trimLeft();
        } else {
          title = entity.uri.pathSegments.last.replaceAll('.md', '');
        }
      }

      final id = await _repo.createEntry(type);
      final editorBody = type.isChecklist
          ? ChecklistMatcher.toBody(ChecklistMatcher.parseMarkdownTasks(body))
          : body;
      await _repo.saveContent(
        id: id,
        title: title,
        body: editorBody,
        recordRevision: false,
      );
      imported++;
    }
    return imported;
  }
}
