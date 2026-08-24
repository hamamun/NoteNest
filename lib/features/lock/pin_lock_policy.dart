import '../../data/models/enums.dart';

/// Pure lock rules. No I/O, no timers — easy to test and hard to get wrong.
class PinLockPolicy {
  const PinLockPolicy({
    required this.hasPin,
    required this.target,
    required this.notesUnlocked,
    required this.listsUnlocked,
  });

  final bool hasPin;
  final PinLockTarget target;
  final bool notesUnlocked;
  final bool listsUnlocked;

  bool get locksNotes => hasPin && target.locksNotes;
  bool get locksLists => hasPin && target.locksLists;

  /// Home should hide note cards (Archive / Trash never consult this).
  bool get shouldHideNotes => locksNotes && !notesUnlocked;

  /// Home should hide list cards.
  bool get shouldHideLists => locksLists && !listsUnlocked;

  /// Both sections are locked and still closed — ask for the PIN on All.
  bool get needsHomeGate =>
      hasPin && target == PinLockTarget.both && !notesUnlocked && !listsUnlocked;

  bool needsNotesGate(EntryFilter filter) =>
      filter == EntryFilter.notes && shouldHideNotes;

  bool needsListsGate(EntryFilter filter) =>
      filter == EntryFilter.lists && shouldHideLists;

  /// True when this Home entry must stay hidden.
  bool hidesEntry(EntryType type) {
    if (type == EntryType.checklist) return shouldHideLists;
    return shouldHideNotes;
  }
}
