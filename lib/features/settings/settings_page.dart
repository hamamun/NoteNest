import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/icons.dart';
import '../../app/services.dart';
import '../../core/time.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/sync_config_repository.dart';
import '../sync/sync_controller.dart';
import 'about_page.dart';
import 'appearance_page.dart';
import 'backup_settings_page.dart';
import 'sync_settings_page.dart';
import 'tags_page.dart';

/// SET-13: the settings hub.
///
/// A-05: settings keep readable text labels. Icon-first is right for the main
/// UI, but a settings screen has to be unambiguous.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsRepository>();
    final config = context.watch<SyncConfigRepository>();
    final sync = context.watch<SyncController>();

    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          icon: AppIcons.back,
          label: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Settings'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _section(context, 'Appearance'),
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('Note and list text size'),
                subtitle: Text(settings.fontStep.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const AppearancePage()),
              ),
              ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: const Text('Theme'),
                subtitle: Text(switch (settings.themeMode) {
                  ThemeMode.light => 'Light',
                  ThemeMode.dark => 'Dark',
                  ThemeMode.system => 'Follow system',
                }),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const AppearancePage()),
              ),

              _section(context, 'Reading and editing'),
              SwitchListTile(
                secondary: const Icon(Icons.link),
                title: const Text('Clickable links'),
                subtitle: Text(
                  settings.clickableUrls
                      ? 'Links open in your browser from View Mode'
                      : 'Links show as plain text you can still select and copy',
                ),
                value: settings.clickableUrls,
                onChanged: settings.setClickableUrls,
              ),
              SwitchListTile(
                secondary: const Icon(AppIcons.preview),
                title: const Text('Markdown preview'),
                subtitle: const Text(
                  'Render headings, lists and bold text in View Mode',
                ),
                value: settings.markdownPreview,
                onChanged: settings.setMarkdownPreview,
              ),
              ListTile(
                leading: const Icon(AppIcons.tag),
                title: const Text('Tags'),
                subtitle: const Text('Create, rename and delete tags'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const TagsPage()),
              ),

              _section(context, 'Sync'),
              ListTile(
                leading: Icon(
                  sync.state == SyncUiState.connected
                      ? AppIcons.syncOk
                      : AppIcons.syncOff,
                ),
                title: const Text('GitHub sync'),
                subtitle: Text(
                  config.isConfigured
                      ? '${config.owner}/${config.repo} (${config.branch}) — '
                          '${sync.statusLabel}'
                      : 'Not set up. NoteNest works fully offline without it.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const SyncSettingsPage()),
              ),
              ListTile(
                leading: const Icon(AppIcons.backup),
                title: const Text('Backup'),
                subtitle: Text(
                  settings.backupEnabled
                      ? '${settings.backupFrequency.label}'
                          '${settings.lastBackupAt != null ? " — last ${AppTime.relative(settings.lastBackupAt!)}" : ""}'
                      : 'Off',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const BackupSettingsPage()),
              ),

              _section(context, 'About'),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About NoteNest'),
                subtitle: Text('Version ${context.read<Services>().appVersion}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const AboutPage()),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      );

  static void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}
