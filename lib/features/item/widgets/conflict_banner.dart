import 'package:flutter/material.dart';

import '../../../app/icons.dart';
import '../../../core/color_x.dart';

/// X-09/G-09: the "you have a conflict, here is what to do about it" panel.
///
/// NoteNest never merges and never overwrites when two devices change the same
/// item — it keeps the remote version in the original and forks the local
/// edits into a conflict copy. That is safe, but until this panel existed the
/// only sign of it was a small "Conflict copy" label on the card, with no way
/// to finish the job. The panel offers the three decisions a person actually
/// makes:
///
///   * keep both  — the copy becomes an ordinary note
///   * replace    — the copy's text wins, the copy goes to Trash (undoable)
///   * discard    — the copy goes to Trash (undoable)
///
/// Every action is optional: [onOpenOriginal], [onReplaceOriginal] and
/// [onDiscard] are nullable so the panel still renders when the original entry
/// no longer exists.
class ConflictBanner extends StatelessWidget {
  const ConflictBanner({
    super.key,
    required this.originalTitle,
    required this.onKeepBoth,
    this.onOpenOriginal,
    this.onReplaceOriginal,
    this.onDiscard,
  });

  /// Title of the entry the other device wrote, or null if it is gone.
  final String? originalTitle;

  final VoidCallback onKeepBoth;
  final VoidCallback? onOpenOriginal;
  final VoidCallback? onReplaceOriginal;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final original = originalTitle?.trim();
    final hasOriginal = original != null && original.isNotEmpty;

    return Semantics(
      container: true,
      label: 'Conflict copy',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.secondary.fade(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  AppIcons.conflict,
                  size: 18,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conflict copy',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasOriginal
                            ? 'Both devices changed this item. The other '
                                'device\'s version is in "$original" — '
                                'nothing was overwritten.'
                            : 'Both devices changed this item. The original '
                                'is gone, so this copy is the only version '
                                'left.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSecondaryContainer.fade(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                if (hasOriginal && onOpenOriginal != null)
                  TextButton(
                    onPressed: onOpenOriginal,
                    child: const Text('Open original'),
                  ),
                if (hasOriginal && onReplaceOriginal != null)
                  TextButton(
                    onPressed: onReplaceOriginal,
                    child: const Text('Replace original'),
                  ),
                TextButton(
                  onPressed: onKeepBoth,
                  child: const Text('Keep both'),
                ),
                if (onDiscard != null)
                  TextButton(
                    onPressed: onDiscard,
                    style: TextButton.styleFrom(foregroundColor: scheme.error),
                    child: const Text('Discard copy'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
