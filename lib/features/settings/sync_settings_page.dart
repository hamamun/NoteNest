import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/icons.dart';
import '../../app/services.dart';
import '../../core/time.dart';
import '../../data/repositories/sync_config_repository.dart';
import '../sync/github_client.dart';
import '../sync/sync_controller.dart';

/// SEC-02..SEC-15: GitHub sync setup.
class SyncSettingsPage extends StatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage> {
  final _ownerController = TextEditingController();
  final _repoController = TextEditingController();
  final _branchController = TextEditingController(text: 'main');
  final _tokenController = TextEditingController();

  bool _testing = false;
  bool _hasStoredToken = false;
  bool _replacingToken = false;
  ConnectionResult? _lastResult;

  @override
  void initState() {
    super.initState();
    final config = context.read<SyncConfigRepository>();
    _ownerController.text = config.owner;
    _repoController.text = config.repo;
    _branchController.text = config.branch;
    _refreshTokenState();
  }

  Future<void> _refreshTokenState() async {
    final has = await context.read<Services>().secureStore.hasToken();
    if (mounted) setState(() => _hasStoredToken = has);
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _repoController.dispose();
    _branchController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = context.watch<SyncConfigRepository>();
    final sync = context.watch<SyncController>();

    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          icon: AppIcons.back,
          label: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('GitHub sync'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _statusCard(theme, sync, config),
              const SizedBox(height: 20),

              Text('Repository', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Use a private repository that only you can see.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _ownerController,
                decoration: const InputDecoration(
                  labelText: 'GitHub username or organisation',
                  hintText: 'your-username',
                ),
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _repoController,
                decoration: const InputDecoration(
                  labelText: 'Repository name',
                  hintText: 'NoteNest',
                ),
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _branchController,
                decoration: const InputDecoration(
                  labelText: 'Branch',
                  hintText: 'main',
                ),
                autocorrect: false,
              ),

              const SizedBox(height: 22),
              Text('Personal access token', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Fine-grained token, this repository only, with '
                'Contents: Read and write plus Metadata: Read.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),

              // SEC-09: never show a saved token again.
              if (_hasStoredToken && !_replacingToken)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: const Text('Token: Saved'),
                    subtitle: const Text('Stored in your operating system keychain'),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          onPressed: () =>
                              setState(() => _replacingToken = true),
                          child: const Text('Replace'),
                        ),
                        TextButton(
                          onPressed: _removeToken,
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                TextField(
                  controller: _tokenController,
                  obscureText: true, // SEC-09: masked while typing.
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Paste token',
                    hintText: 'github_pat_...',
                    suffixIcon: _replacingToken
                        ? AppIconButton(
                            icon: AppIcons.clear,
                            label: 'Cancel replace',
                            onPressed: () => setState(() {
                              _replacingToken = false;
                              _tokenController.clear();
                            }),
                          )
                        : null,
                  ),
                ),

              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _testing ? null : _testConnection,
                      icon: _testing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_tethering),
                      label: const Text('Test connection'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      // SEC-06: cannot enable until a test has passed.
                      onPressed: (_lastResult?.ok ?? false) ? _saveAndEnable : null,
                      icon: const Icon(AppIcons.done),
                      label: const Text('Save and enable'),
                    ),
                  ),
                ],
              ),

              if (_lastResult != null) ...[
                const SizedBox(height: 14),
                _resultBanner(theme, _lastResult!),
              ],

              if (config.isConfigured) ...[
                const Divider(height: 44),
                SwitchListTile(
                  secondary: const Icon(AppIcons.sync),
                  title: const Text('Sync enabled'),
                  subtitle: const Text(
                    'Turning this off keeps your saved token and settings',
                  ),
                  value: config.syncEnabled,
                  onChanged: (value) =>
                      context.read<SyncController>().setEnabled(value),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.autorenew),
                  title: const Text('Auto sync'),
                  subtitle: const Text(
                    'Sync when the app opens and when the internet returns',
                  ),
                  value: config.autoSyncEnabled,
                  onChanged: config.syncEnabled
                      ? (value) => context
                          .read<SyncConfigRepository>()
                          .setAutoSync(value)
                      : null,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.lock_outline),
                  title: const Text('Encrypt notes before upload'),
                  subtitle: const Text(
                    'Advanced. Files stop being readable on github.com, and '
                    'losing the passphrase means losing the notes.',
                  ),
                  value: config.encryptSyncEnabled,
                  onChanged: config.syncEnabled ? _toggleEncryptedSync : null,
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: context.read<SyncController>().canSync
                      ? () async {
                          final services = context.read<Services>();
                          final result =
                              await context.read<SyncController>().syncNow();
                          if (result != null && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result.summary)),
                            );
                            if (result.ok) {
                              await services.maybeBackupAfterSync();
                            }
                          }
                        }
                      : null,
                  icon: const Icon(AppIcons.sync),
                  label: const Text('Sync now'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _disconnect,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  icon: const Icon(AppIcons.syncOff),
                  label: const Text('Disconnect GitHub sync'),
                ),
              ],

              const SizedBox(height: 26),
              _privacyNote(theme),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusCard(
    ThemeData theme,
    SyncController sync,
    SyncConfigRepository config,
  ) {
    final color = switch (sync.state) {
      SyncUiState.connected => theme.colorScheme.primaryContainer,
      SyncUiState.failed ||
      SyncUiState.reconnectRequired =>
        theme.colorScheme.errorContainer,
      _ => theme.colorScheme.surfaceContainerHighest,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            sync.state == SyncUiState.connected
                ? AppIcons.syncOk
                : AppIcons.syncOff,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sync.statusLabel, style: theme.textTheme.titleSmall),
                if (config.lastSyncAt != null)
                  Text(
                    'Last sync ${AppTime.full(config.lastSyncAt!)}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultBanner(ThemeData theme, ConnectionResult result) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: result.ok
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            result.ok ? Icons.check_circle_outline : AppIcons.warning,
            size: 20,
            color: result.ok
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              result.message,
              style: TextStyle(
                color: result.ok
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// SEC-15: the honest privacy note stays visible.
  Widget _privacyNote(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.warning, size: 18, color: theme.colorScheme.outline),
              const SizedBox(width: 8),
              Text('Before you sync', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Notes are stored as plain Markdown files in your repository, so '
            'you can always read them on github.com.\n\n'
            'Deleting a note removes it from the app and from the latest '
            'files, but old content can remain in the Git commit history.\n\n'
            'Do not store passwords or highly sensitive information in '
            'NoteNest.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  /// SEC-04/SEC-05
  Future<void> _testConnection() async {
    final owner = _ownerController.text.trim();
    final repo = _repoController.text.trim();
    final branch = _branchController.text.trim().isEmpty
        ? 'main'
        : _branchController.text.trim();

    if (owner.isEmpty || repo.isEmpty) {
      setState(() => _lastResult = const ConnectionResult(
            ok: false,
            message: 'Enter both the owner and the repository name.',
          ));
      return;
    }

    final services = context.read<Services>();
    var token = _tokenController.text.trim();
    if (token.isEmpty) {
      token = await services.secureStore.readToken() ?? '';
    }
    if (token.isEmpty) {
      setState(() => _lastResult = const ConnectionResult(
            ok: false,
            message: 'Paste your personal access token first.',
          ));
      return;
    }

    setState(() => _testing = true);

    final client = GitHubClient(
      owner: owner,
      repo: repo,
      branch: branch,
      token: token,
    );
    final result = await client.testConnection();
    client.close();

    if (!mounted) return;
    setState(() {
      _testing = false;
      _lastResult = result;
    });
  }

  /// SEC-03
  Future<void> _saveAndEnable() async {
    final services = context.read<Services>();
    final token = _tokenController.text.trim();

    if (token.isNotEmpty) {
      await services.secureStore.writeToken(token);
      _tokenController.clear();
    }

    await context.read<SyncConfigRepository>().saveConnection(
          owner: _ownerController.text.trim(),
          repo: _repoController.text.trim(),
          branch: _branchController.text.trim(),
        );
    await context.read<SyncController>().refreshState();

    if (!mounted) return;
    setState(() {
      _replacingToken = false;
      _hasStoredToken = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sync enabled.')),
    );
  }

  /// SEC-10
  Future<void> _removeToken() async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Remove saved token?',
      message: 'Sync will stop working until you paste a token again. '
          'Your notes stay on this device.',
      confirmLabel: 'Remove token',
    );
    if (!confirmed || !mounted) return;

    await context.read<Services>().secureStore.deleteToken();
    await context.read<SyncController>().refreshState();
    if (mounted) {
      setState(() {
        _hasStoredToken = false;
        _replacingToken = false;
      });
    }
  }

  /// SEC-12
  Future<void> _disconnect() async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Disconnect GitHub sync?',
      message: 'The saved token is deleted and the repository settings are '
          'cleared. Your notes stay on this device and nothing is removed '
          'from GitHub.',
      confirmLabel: 'Disconnect',
    );
    if (!confirmed || !mounted) return;

    await context.read<SyncController>().disconnect(clearConfig: true);
    if (!mounted) return;
    setState(() {
      _hasStoredToken = false;
      _lastResult = null;
      _ownerController.clear();
      _repoController.clear();
      _branchController.text = 'main';
    });
  }

  /// V3: encrypted note sync needs a passphrase before it can be turned on.
  Future<void> _toggleEncryptedSync(bool value) async {
    final services = context.read<Services>();
    final config = context.read<SyncConfigRepository>();

    if (!value) {
      await config.setEncryptSync(false);
      return;
    }

    final passphrase = await _promptPassphrase(
      title: 'Set sync passphrase',
      message: 'Every device must use the same passphrase. If you lose it, '
          'the notes in the repository cannot be recovered.',
    );
    if (passphrase == null || passphrase.isEmpty) return;

    await services.secureStore.writeSyncPassphrase(passphrase);
    await config.setEncryptSync(true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Encrypted sync on. Existing files re-upload encrypted.'),
        ),
      );
    }
  }

  Future<String?> _promptPassphrase({
    required String title,
    required String message,
  }) async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    String? error;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, style: Theme.of(builderContext).textTheme.bodySmall),
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
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
