import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/icons.dart';
import '../../app/services.dart';
import '../../core/time.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/sync_config_repository.dart';
import '../backup/backup_service.dart';
import '../export/export_saver.dart';
import '../export/export_service.dart';

/// B-01..B-18: backup settings.
class BackupSettingsPage extends StatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  State<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends State<BackupSettingsPage> {
  bool _busy = false;
  String _contents = '';

  @override
  void initState() {
    super.initState();
    _loadContents();
  }

  Future<void> _loadContents() async {
    final text = await context.read<Services>().backup.describeContents();
    if (mounted) setState(() => _contents = text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsRepository>();
    final config = context.watch<SyncConfigRepository>();

    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          icon: AppIcons.back,
          label: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Backup'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sync keeps devices up to date. A backup is a dated '
                        'snapshot you can go back to.',
                        style: theme.textTheme.bodySmall),
                    if (_contents.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Will include: $_contents',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // B-03
              if (!config.isConfigured)
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: const ListTile(
                    leading: Icon(AppIcons.warning),
                    title: Text('Connect GitHub Sync first'),
                    subtitle: Text(
                      'Backups are uploaded to the same private repository.',
                    ),
                  ),
                ),

              SwitchListTile(
                secondary: const Icon(AppIcons.backup),
                title: const Text('Scheduled backup to GitHub'),
                value: settings.backupEnabled,
                onChanged: config.isConfigured
                    ? (value) => settings.setBackupEnabled(value)
                    : null,
              ),

              // B-02/B-05
              if (settings.backupEnabled) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<BackupFrequency>(
                    segments: const [
                      ButtonSegment(
                        value: BackupFrequency.disabled,
                        label: Text('Off'),
                      ),
                      ButtonSegment(
                        value: BackupFrequency.weekly,
                        label: Text('Weekly'),
                      ),
                      ButtonSegment(
                        value: BackupFrequency.monthly,
                        label: Text('Monthly'),
                      ),
                    ],
                    selected: {settings.backupFrequency},
                    onSelectionChanged: (selection) =>
                        settings.setBackupFrequency(selection.first),
                    showSelectedIcon: false,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'The app has no server, so a scheduled backup runs the '
                    'next time you open NoteNest or finish a sync.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],

              const Divider(height: 36),

              // B-15/B-17
              SwitchListTile(
                secondary: const Icon(Icons.lock_outline),
                title: const Text('Encrypt backup files'),
                subtitle: const Text(
                  'AES-256-GCM with a passphrase you choose. Off by default.',
                ),
                value: settings.backupEncryption,
                onChanged: _toggleEncryption,
              ),
              if (settings.backupEncryption)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(AppIcons.warning,
                            size: 18,
                            color: theme.colorScheme.onErrorContainer),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'If you lose this passphrase, the backup cannot '
                            'be recovered. Encryption applies to backups '
                            'only — synced notes stay readable.',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const Divider(height: 36),

              // B-07
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('Back up now'),
                subtitle: Text(
                  settings.lastBackupAt == null
                      ? 'Never backed up'
                      : 'Last backup ${AppTime.relative(settings.lastBackupAt!)}'
                          '${settings.lastBackupStatus.isEmpty ? "" : "\n${settings.lastBackupStatus}"}',
                ),
                isThreeLine: settings.lastBackupStatus.isNotEmpty,
                trailing: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                enabled: config.isConfigured && !_busy,
                onTap: config.isConfigured && !_busy ? _backupNow : null,
              ),

              // B-18: an offline copy, since restore-from-backup is not in v1.
              ListTile(
                leading: const Icon(AppIcons.export),
                title: const Text('Save a backup file to this device'),
                subtitle: const Text(
                  'Same zip, saved locally instead of uploaded',
                ),
                trailing: const Icon(Icons.chevron_right),
                enabled: !_busy,
                onTap: _busy ? null : _saveLocalBackup,
              ),

              const Divider(height: 36),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Backups include active, archived and trashed items, '
                  'checklist states, colours, images and delete records, so '
                  'restoring one can never bring back a note you deleted.\n\n'
                  'Deleting a backup file later does not remove it from the '
                  'GitHub commit history.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleEncryption(bool value) async {
    final services = context.read<Services>();
    final settings = context.read<SettingsRepository>();

    if (!value) {
      await settings.setBackupEncryption(false);
      await services.secureStore.deleteBackupPassphrase();
      return;
    }

    final controller = TextEditingController();
    final confirmController = TextEditingController();
    String? error;

    final passphrase = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) => AlertDialog(
          title: const Text('Backup passphrase'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'If you lose this passphrase, the encrypted backup cannot be '
                'recovered by anyone, including you.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Passphrase'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Repeat passphrase',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.length < 8) {
                  setDialogState(() => error = 'Use at least 8 characters.');
                  return;
                }
                if (controller.text != confirmController.text) {
                  setDialogState(() => error = 'The two entries do not match.');
                  return;
                }
                Navigator.of(dialogContext).pop(controller.text);
              },
              child: const Text('Turn on'),
            ),
          ],
        ),
      ),
    );

    if (passphrase == null || passphrase.isEmpty) return;
    await services.secureStore.writeBackupPassphrase(passphrase);
    await settings.setBackupEncryption(true);
  }

  Future<void> _backupNow() async {
    setState(() => _busy = true);
    final services = context.read<Services>();
    final result = await services.backup.run(BackupKind.manual);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  Future<void> _saveLocalBackup() async {
    setState(() => _busy = true);
    try {
      final services = context.read<Services>();
      final bytes = await services.backup.buildLocalArchive();
      final encrypted = context.read<SettingsRepository>().backupEncryption;
      final name = 'notenest-backup-'
          '${AppTime.fileStamp(AppTime.nowMs())}.zip${encrypted ? ".enc" : ""}';

      final path = await ExportSaver.save(ExportPayload(name, bytes));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(path == null ? 'Cancelled' : 'Saved $name')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
