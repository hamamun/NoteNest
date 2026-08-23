import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/icons.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/settings_repository.dart';

/// SET-01..SET-05: content font size, plus theme and card view.
///
/// The live preview at the top is the point of this screen: the user can see
/// exactly what changes, and confirm that the app chrome does NOT change.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsRepository>();
    final theme = Theme.of(context);
    final scale = settings.contentFontScale;

    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          icon: AppIcons.back,
          label: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Appearance'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Note and list text size', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'This changes note and list content only. Menus, buttons and '
                'settings text stay the same size.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // SET-01: A- / A+ controls.
              Row(
                children: [
                  AppIconButton(
                    icon: Icons.text_decrease,
                    label: 'Smaller text',
                    onPressed: settings.fontStep == FontSizeStep.small
                        ? null
                        : () => settings.nudgeFontSize(-1),
                  ),
                  Expanded(
                    child: Text(
                      settings.fontStep.label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.text_increase,
                    label: 'Larger text',
                    onPressed: settings.fontStep == FontSizeStep.extraLarge
                        ? null
                        : () => settings.nudgeFontSize(1),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SegmentedButton<FontSizeStep>(
                segments: FontSizeStep.values
                    .map((step) => ButtonSegment<FontSizeStep>(
                          value: step,
                          label: Text(step.label),
                        ))
                    .toList(),
                selected: {settings.fontStep},
                onSelectionChanged: (selection) =>
                    settings.setFontStep(selection.first),
                showSelectedIcon: false,
              ),

              const SizedBox(height: 20),
              // SET-04: applies immediately, no restart.
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Preview', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 10),
                    Text(
                      'Shopping list for the weekend',
                      style: TextStyle(
                        fontSize: 16 * scale,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This is how your note and list text will look. '
                      'Adjust until it is comfortable to read.',
                      style: TextStyle(fontSize: 16 * scale, height: 1.45),
                    ),
                  ],
                ),
              ),

              const Divider(height: 44),

              Text('Theme', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (selection) =>
                    settings.setThemeMode(selection.first),
                showSelectedIcon: false,
              ),

              const Divider(height: 44),

              Text('Card view', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Saved on this device only.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<CardViewMode>(
                segments: const [
                  ButtonSegment(
                    value: CardViewMode.grid,
                    label: Text('Grid'),
                    icon: Icon(AppIcons.viewGrid),
                  ),
                  ButtonSegment(
                    value: CardViewMode.list,
                    label: Text('List'),
                    icon: Icon(AppIcons.viewList),
                  ),
                  ButtonSegment(
                    value: CardViewMode.compact,
                    label: Text('Compact'),
                    icon: Icon(AppIcons.viewCompact),
                  ),
                ],
                selected: {settings.cardViewMode},
                onSelectionChanged: (selection) =>
                    settings.setCardViewMode(selection.first),
                showSelectedIcon: false,
              ),

              const SizedBox(height: 20),
              Text('Sort order', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              for (final mode in SortMode.values)
                ListTile(
                  onTap: () => settings.setSortMode(mode),
                  leading: Icon(
                    settings.sortMode == mode
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: settings.sortMode == mode
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  title: Text(mode.label),
                  subtitle: mode == SortMode.recentlyViewed
                      ? const Text('This device only — never synced')
                      : null,
                  contentPadding: EdgeInsets.zero,
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
