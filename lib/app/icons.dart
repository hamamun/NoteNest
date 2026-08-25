import 'package:flutter/material.dart';

/// A-02: the single source of truth for every icon in the app.
///
/// Centralising them keeps the icon language consistent and makes A-03
/// (tooltip + semantics on every icon button) mechanically enforceable.
class AppIcons {
  AppIcons._();

  static const IconData newItem = Icons.add;
  static const IconData newNote = Icons.description_outlined;
  static const IconData newList = Icons.checklist_rtl_outlined;
  static const IconData search = Icons.search;
  static const IconData clear = Icons.close;

  static const IconData viewGrid = Icons.grid_view_outlined;
  static const IconData viewList = Icons.view_agenda_outlined;
  static const IconData viewCompact = Icons.density_small_outlined;
  static const IconData viewRows = Icons.table_rows_outlined;
  static const IconData sort = Icons.sort;

  static const IconData checkboxesOn = Icons.check_box_outlined;
  static const IconData checkboxesOff = Icons.notes_outlined;

  static const IconData sync = Icons.cloud_sync_outlined;
  static const IconData syncOk = Icons.cloud_done_outlined;
  static const IconData syncOff = Icons.cloud_off_outlined;
  static const IconData syncError = Icons.cloud_off;
  static const IconData backup = Icons.backup_outlined;

  static const IconData edit = Icons.edit_outlined;
  static const IconData view = Icons.visibility_outlined;
  static const IconData done = Icons.check;
  static const IconData preview = Icons.preview_outlined;

  static const IconData copy = Icons.copy_outlined;
  static const IconData copyAll = Icons.copy_all_outlined;
  static const IconData color = Icons.palette_outlined;
  static const IconData image = Icons.image_outlined;
  static const IconData pin = Icons.push_pin;
  static const IconData pinOutline = Icons.push_pin_outlined;

  static const IconData archive = Icons.archive_outlined;
  static const IconData unarchive = Icons.unarchive_outlined;
  static const IconData restore = Icons.restore_from_trash_outlined;
  static const IconData trash = Icons.delete_outline;
  static const IconData deleteForever = Icons.delete_forever_outlined;
  static const IconData warning = Icons.warning_amber_rounded;

  static const IconData export = Icons.download_outlined;
  static const IconData settings = Icons.settings_outlined;
  static const IconData more = Icons.more_vert;
  static const IconData menu = Icons.menu;
  static const IconData back = Icons.arrow_back;
  static const IconData history = Icons.history;
  static const IconData home = Icons.lightbulb_outline;
  static const IconData conflict = Icons.merge_type;

  static const IconData lock = Icons.lock_outline;
  static const IconData lockOpen = Icons.lock_open_outlined;
  static const IconData keepAwake = Icons.wb_sunny_outlined;
  static const IconData keepAwakeOff = Icons.brightness_2_outlined;
}

/// A-03/A-04/A-07: an icon button that cannot be created without an
/// accessible label. Every icon-only control in NoteNest uses this widget.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.color,
    this.iconSize,
  });

  final IconData icon;

  /// Doubles as the tooltip (desktop hover / mobile long-press) and the
  /// screen-reader semantics label.
  final String label;

  final VoidCallback? onPressed;
  final bool selected;
  final Color? color;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: IconButton(
        icon: Icon(icon, size: iconSize),
        tooltip: label,
        onPressed: onPressed,
        color: color ?? (selected ? scheme.primary : null),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        isSelected: selected,
      ),
    );
  }
}

/// A labelled entry used by the mobile bottom sheets (U-09, U-13, U-20).
class SheetAction {
  const SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool selected;
}

/// Shows a consistent icon+label bottom sheet on mobile (U-02).
Future<void> showActionSheet(
  BuildContext context, {
  required String title,
  required List<SheetAction> actions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(title, style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            for (final action in actions)
              ListTile(
                leading: Icon(
                  action.icon,
                  color: action.destructive
                      ? scheme.error
                      : action.selected
                          ? scheme.primary
                          : null,
                ),
                title: Text(
                  action.label,
                  style: TextStyle(
                    color: action.destructive ? scheme.error : null,
                    fontWeight: action.selected ? FontWeight.w600 : null,
                  ),
                ),
                trailing: action.selected ? const Icon(AppIcons.done, size: 18) : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  action.onTap();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// T-17/A-06: destructive actions always confirm, with an explanation.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(AppIcons.warning, color: scheme.error, size: 32),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: scheme.error),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
