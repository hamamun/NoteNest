import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/icons.dart';
import '../../app/services.dart';
import '../../data/models/enums.dart';
import '../../state/app_state.dart';
import '../item/item_page.dart';
import '../lock/pin_lock_controller.dart';
import '../lock/pin_pad.dart';

/// U-09: one create control that opens a sheet, never two separate buttons.
Future<void> showCreateOptions(BuildContext context) async {
  final lock = context.read<PinLockController>();
  if (lock.shouldHideNotes && lock.shouldHideLists) {
    final unlocked = await _unlockIfNeeded(context, lock);
    if (!unlocked || !context.mounted) return;
  }

  if (!context.mounted) return;
  showActionSheet(
    context,
    title: 'Create',
    actions: [
      SheetAction(
        icon: AppIcons.newNote,
        label: 'New note',
        onTap: () => createAndOpen(context, EntryType.note),
      ),
      SheetAction(
        icon: AppIcons.newList,
        label: 'New list',
        onTap: () => createAndOpen(context, EntryType.checklist),
      ),
    ],
  );
}

/// Creates a note or list and opens it in Edit Mode.
///
/// New items always land in Home. If the user started from Archive or Trash,
/// the shell switches so backing out of the editor shows the new card.
Future<void> createAndOpen(BuildContext context, EntryType type) async {
  final lock = context.read<PinLockController>();
  final blocked =
      type.isChecklist ? lock.shouldHideLists : lock.shouldHideNotes;
  if (blocked) {
    final unlocked = await _unlockIfNeeded(context, lock);
    if (!unlocked || !context.mounted) return;
  }

  final services = context.read<Services>();
  final id = await services.entries.createEntry(type);
  if (!context.mounted) return;
  context.read<AppState>().setWorkspace(Workspace.home);
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ItemPage(entryId: id, startInEditMode: true),
    ),
  );
}

Future<bool> _unlockIfNeeded(
  BuildContext context,
  PinLockController lock,
) async {
  if (!lock.shouldHideNotes && !lock.shouldHideLists) return true;
  var ok = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
        content: SizedBox(
          width: 360,
          child: PinPad(
            title: 'Enter PIN',
            subtitle: 'Unlock to continue',
            onSubmit: (pin) async {
              final unlocked = await lock.unlockWithPin(pin);
              if (unlocked && dialogContext.mounted) {
                ok = true;
                Navigator.of(dialogContext).pop();
              }
              return unlocked;
            },
            footer: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ),
        ),
      );
    },
  );
  return ok;
}
