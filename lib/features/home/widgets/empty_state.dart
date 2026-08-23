import 'package:flutter/material.dart';

import '../../../app/icons.dart';
import '../../../data/models/enums.dart';

/// U-24: the five empty states the app needs.
///
/// An empty screen with no explanation is the fastest way to make a new app
/// feel broken, so each state says what happened and what to do next.
class EmptyState extends StatelessWidget {
  const EmptyState._({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  factory EmptyState.forWorkspace(
    Workspace workspace, {
    required bool searching,
    required bool filtered,
    VoidCallback? onCreate,
  }) {
    if (searching) {
      return const EmptyState._(
        icon: AppIcons.search,
        title: 'No matches',
        message: 'Nothing here matches your search. '
            'Try a shorter word, or clear the search box.',
      );
    }

    switch (workspace) {
      case Workspace.home:
        if (filtered) {
          return const EmptyState._(
            icon: AppIcons.newItem,
            title: 'Nothing in this filter',
            message: 'Switch back to All to see everything you have.',
          );
        }
        return EmptyState._(
          icon: AppIcons.home,
          title: 'Your nest is empty',
          message: 'Notes and lists you create are stored on this device '
              'first. Everything works without internet.',
          action: onCreate == null
              ? null
              : FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(AppIcons.newItem),
                  label: const Text('Create your first note'),
                ),
        );
      case Workspace.archive:
        return const EmptyState._(
          icon: AppIcons.archive,
          title: 'Archive is empty',
          message: 'Archived notes are kept safely out of the way. '
              'They are never deleted.',
        );
      case Workspace.trash:
        return const EmptyState._(
          icon: AppIcons.trash,
          title: 'Trash is empty',
          message: 'Items you move to trash wait here until you restore '
              'them or delete them forever.',
        );
    }
  }

  /// Shown on the sync settings page before a repository is connected.
  factory EmptyState.syncNotConfigured({VoidCallback? onSetup}) => EmptyState._(
        icon: AppIcons.syncOff,
        title: 'Sync is not set up',
        message: 'NoteNest works completely offline. Connect a private '
            'GitHub repository if you also want your notes on another device.',
        action: onSetup == null
            ? null
            : FilledButton.icon(
                onPressed: onSetup,
                icon: const Icon(AppIcons.sync),
                label: const Text('Set up sync'),
              ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: 22),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
