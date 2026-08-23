import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/icons.dart';
import '../../app/services.dart';
import '../../core/logging.dart';

/// Settings > About. Also exposes the redacted log (SEC-08) so a failing sync
/// can be diagnosed without a debugger.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final services = context.read<Services>();

    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          icon: AppIcons.back,
          label: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('About NoteNest'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      AppIcons.home,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NoteNest', style: theme.textTheme.titleLarge),
                      Text(
                        'Version ${services.appVersion}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'A local-first notes and lists app. Everything is stored on '
                'this device first and works without internet. A private '
                'GitHub repository is used only for sync and backup.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
              const Divider(height: 40),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.devices_other),
                title: const Text('This device'),
                subtitle: Text('${services.deviceName}\n${services.deviceId}'),
                isThreeLine: true,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.storage_outlined),
                title: const Text('Storage'),
                subtitle: const Text(
                  'SQLite database and images in the app data folder',
                ),
              ),

              const Divider(height: 40),
              Text('Diagnostics', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Recent activity. Tokens and passphrases are never written '
                'to this log.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 240,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Builder(
                  builder: (_) {
                    final lines = AppLog.recent();
                    if (lines.isEmpty) {
                      return const Center(child: Text('Nothing logged yet.'));
                    }
                    return ListView.builder(
                      reverse: true,
                      itemCount: lines.length,
                      itemBuilder: (context, index) => Text(
                        lines[lines.length - 1 - index],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: AppLog.recent().join('\n')),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Log copied')),
                        );
                      }
                    },
                    icon: const Icon(AppIcons.copy, size: 18),
                    label: const Text('Copy log'),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () {
                      AppLog.clear();
                      (context as Element).markNeedsBuild();
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
