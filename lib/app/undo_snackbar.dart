import 'package:flutter/material.dart';

/// UND-02: the five-second safety net behind every metadata action.
///
/// Pin, colour, archive, trash and restore all have an exact inverse on
/// `EntryRepository`, so "Undo" simply replays the previous value. The normal
/// sync-dirty marking then applies to the revert exactly as it would to any
/// other edit — no special cases in the sync engine.
///
/// The messenger outlives route pushes and pops, so this is also safe to call
/// right before `Navigator.pop` (the item screen does exactly that).
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required Future<void> Function() onUndo,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: 'Undo', onPressed: () => onUndo()),
      ),
    );
}
