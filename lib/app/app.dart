import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/enums.dart';
import '../data/repositories/settings_repository.dart';
import '../features/home/home_page.dart';
import '../features/settings/settings_page.dart';
import '../features/sync/sync_controller.dart';
import '../state/app_state.dart';
import 'icons.dart';
import 'theme.dart';

class NoteNestApp extends StatelessWidget {
  const NoteNestApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsRepository>();

    return MaterialApp(
      title: 'NoteNest',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode, // SET-14
      home: const AppShell(),
    );
  }
}

/// U-01/U-03/U-08: one shell that becomes a sidebar layout on desktop and a
/// drawer layout on mobile.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded = Breakpoints.isExpanded(constraints.maxWidth);
        final medium = Breakpoints.isMedium(constraints.maxWidth);

        if (expanded || medium) {
          return _DesktopShell(showLabels: expanded);
        }
        return const _MobileShell();
      },
    );
  }
}

/// U-03: NavigationRail + content.
class _DesktopShell extends StatelessWidget {
  const _DesktopShell({required this.showLabels});

  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    const destinations = Workspace.values;
    final index = destinations.indexOf(state.workspace);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: showLabels,
            minExtendedWidth: 190,
            backgroundColor: scheme.surface,
            selectedIndex: index < 0 ? 0 : index,
            onDestinationSelected: (i) =>
                context.read<AppState>().setWorkspace(destinations[i]),
            leading: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: showLabels
                  ? const _BrandMark()
                  : const Icon(AppIcons.home, size: 26),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _SyncRailStatus(),
                      AppIconButton(
                        icon: AppIcons.settings,
                        label: 'Settings',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsPage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            destinations: [
              for (final workspace in destinations)
                NavigationRailDestination(
                  icon: Icon(_iconFor(workspace)),
                  selectedIcon: Icon(_selectedIconFor(workspace)),
                  label: Text(workspace.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          const Expanded(child: HomePage(isDesktop: true)),
        ],
      ),
    );
  }
}

/// U-10: Home is primary; Archive, Trash and Settings live in the drawer.
class _MobileShell extends StatelessWidget {
  const _MobileShell();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      drawer: NavigationDrawer(
        selectedIndex: Workspace.values.indexOf(state.workspace),
        onDestinationSelected: (i) {
          context.read<AppState>().setWorkspace(Workspace.values[i]);
          Navigator.of(context).pop();
        },
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 16, 12),
            child: _BrandMark(),
          ),
          for (final workspace in Workspace.values)
            NavigationDrawerDestination(
              icon: Icon(_iconFor(workspace)),
              selectedIcon: Icon(_selectedIconFor(workspace)),
              label: Text(workspace.label),
            ),
          const Divider(indent: 24, endIndent: 24),
          ListTile(
            leading: const Icon(AppIcons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: _SyncDrawerStatus(),
          ),
        ],
      ),
      body: const HomePage(isDesktop: false),
    );
  }
}

IconData _iconFor(Workspace workspace) => switch (workspace) {
      Workspace.home => AppIcons.home,
      Workspace.archive => AppIcons.archive,
      Workspace.trash => AppIcons.trash,
    };

IconData _selectedIconFor(Workspace workspace) => switch (workspace) {
      Workspace.home => Icons.lightbulb,
      Workspace.archive => Icons.archive,
      Workspace.trash => Icons.delete,
    };

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(AppIcons.home, size: 18, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: 10),
        Text(
          'NoteNest',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// G-13: compact sync indicator for the rail.
class _SyncRailStatus extends StatelessWidget {
  const _SyncRailStatus();

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController>();
    final scheme = Theme.of(context).colorScheme;

    if (sync.isSyncing) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final (icon, color) = switch (sync.state) {
      SyncUiState.connected => (AppIcons.syncOk, null),
      SyncUiState.failed => (AppIcons.syncError, scheme.error),
      SyncUiState.reconnectRequired => (AppIcons.syncOff, scheme.error),
      _ => (AppIcons.syncOff, null),
    };

    return AppIconButton(
      icon: icon,
      label: sync.statusLabel,
      color: color,
      onPressed: sync.canSync
          ? () async {
              final result = await context.read<SyncController>().syncNow();
              if (result != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.summary)),
                );
              }
            }
          : null,
    );
  }
}

class _SyncDrawerStatus extends StatelessWidget {
  const _SyncDrawerStatus();

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController>();
    return Row(
      children: [
        Icon(
          sync.state == SyncUiState.connected ? AppIcons.syncOk : AppIcons.syncOff,
          size: 16,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            sync.statusLabel,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
