import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/enums.dart';
import '../data/repositories/settings_repository.dart';
import '../features/home/create_flow.dart';
import '../features/home/home_page.dart';
import '../features/lock/lock_lifecycle.dart';
import '../features/settings/settings_page.dart';
import '../state/app_state.dart';
import 'brand.dart';
import 'icons.dart';
import 'theme.dart';

/// Compatibility for files left over from `flutter create` (for example a
/// template `test/widget_test.dart`) that call `const MyApp()` directly.
/// This has to be a real class: a typedef alias such as
/// `typedef MyApp = NoteNestApp;` cannot be used as a constructor, which is
/// exactly what the analyzer error "The name 'MyApp' isn't a class" means.
/// NoteNest uses [NoteNestApp] as its canonical application widget.
class MyApp extends NoteNestApp {
  const MyApp({super.key});
}

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
      home: const LockLifecycle(child: AppShell()),
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
                  : const AppBrandIcon(size: 28),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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

/// U-10: Home / Archive / Trash on a bottom bar so the current workspace is
/// always visible. Settings stays in the drawer (it is a pushed page).
/// U-08/U-09: create lives as a trailing + on this bar, not as a FAB.
class _MobileShell extends StatelessWidget {
  const _MobileShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: NavigationDrawer(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 16, 12),
            child: _BrandMark(),
          ),
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
        ],
      ),
      body: Builder(
        builder: (context) => HomePage(
          isDesktop: false,
          onOpenDrawer: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      bottomNavigationBar: const _MobileBottomBar(),
    );
  }
}

/// Home / Archive / Trash share the bar equally; + is a trailing action,
/// never a fourth destination, so it cannot become the selected tab.
class _MobileBottomBar extends StatelessWidget {
  const _MobileBottomBar();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    const destinations = Workspace.values;
    final selected = destinations.indexOf(state.workspace);

    return Material(
      elevation: 3,
      color: scheme.surfaceContainer,
      surfaceTintColor: scheme.surfaceTint,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _MobileNavTab(
                    workspace: destinations[i],
                    selected: i == selected,
                    onTap: () => context
                        .read<AppState>()
                        .setWorkspace(destinations[i]),
                  ),
                ),
              if (!state.selectionMode) const _MobileNewButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavTab extends StatelessWidget {
  const _MobileNavTab({
    required this.workspace,
    required this.selected,
    required this.onTap,
  });

  final Workspace workspace;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor =
        selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    final labelColor = selected ? scheme.onSurface : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: workspace.label,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: 64,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.secondaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  selected ? _selectedIconFor(workspace) : _iconFor(workspace),
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                workspace.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: labelColor,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNewButton extends StatelessWidget {
  const _MobileNewButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 12, 0),
      child: Center(
        child: Semantics(
          button: true,
          label: 'New note or list',
          child: Tooltip(
            message: 'New note or list',
            child: FilledButton(
              onPressed: () => showCreateOptions(context),
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                minimumSize: const Size(48, 48),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: const Icon(AppIcons.newItem, size: 22),
            ),
          ),
        ),
      ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppBrandIcon(size: 30),
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
