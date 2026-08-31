import 'package:flutter_test/flutter_test.dart';
import 'package:notenest/data/models/enums.dart';
import 'package:notenest/features/lock/pin_hasher.dart';
import 'package:notenest/features/lock/pin_lock_controller.dart';
import 'package:notenest/features/lock/pin_lock_policy.dart';

void main() {
  group('PinHasher', () {
    test('accepts only four digits', () {
      expect(PinHasher.isFourDigits('1234'), isTrue);
      expect(PinHasher.isFourDigits('0000'), isTrue);
      expect(PinHasher.isFourDigits('123'), isFalse);
      expect(PinHasher.isFourDigits('12345'), isFalse);
      expect(PinHasher.isFourDigits('12a4'), isFalse);
    });

    test('round-trips a PIN and rejects a wrong one', () async {
      final stored = await PinHasher.hash('4281');
      expect(stored, startsWith('v1\$'));
      expect(await PinHasher.verify('4281', stored), isTrue);
      expect(await PinHasher.verify('4280', stored), isFalse);
      expect(await PinHasher.verify('4281', 'not-a-hash'), isFalse);
    });

    test('the same PIN with a different salt does not match', () async {
      final a = await PinHasher.hash('1111', salt: 'aa');
      final b = await PinHasher.hash('1111', salt: 'bb');
      expect(a, isNot(equals(b)));
      expect(await PinHasher.verify('1111', a), isTrue);
    });
  });

  group('PinLockPolicy', () {
    test('with no PIN nothing is hidden', () {
      const policy = PinLockPolicy(
        hasPin: false,
        target: PinLockTarget.both,
        notesUnlocked: false,
        listsUnlocked: false,
      );
      expect(policy.shouldHideNotes, isFalse);
      expect(policy.shouldHideLists, isFalse);
      expect(policy.needsHomeGate, isFalse);
    });

    test('notes-only hides notes from All until unlocked', () {
      const locked = PinLockPolicy(
        hasPin: true,
        target: PinLockTarget.notes,
        notesUnlocked: false,
        listsUnlocked: false,
      );
      expect(locked.shouldHideNotes, isTrue);
      expect(locked.shouldHideLists, isFalse);
      expect(locked.needsHomeGate, isFalse);
      expect(locked.hidesEntry(EntryType.note), isTrue);
      expect(locked.hidesEntry(EntryType.checklist), isFalse);
      expect(locked.needsNotesGate(EntryFilter.notes), isTrue);
      expect(locked.needsNotesGate(EntryFilter.all), isFalse);

      const open = PinLockPolicy(
        hasPin: true,
        target: PinLockTarget.notes,
        notesUnlocked: true,
        listsUnlocked: false,
      );
      expect(open.shouldHideNotes, isFalse);
      expect(open.hidesEntry(EntryType.note), isFalse);
    });

    test('lists-only hides lists from All until unlocked', () {
      const locked = PinLockPolicy(
        hasPin: true,
        target: PinLockTarget.lists,
        notesUnlocked: false,
        listsUnlocked: false,
      );
      expect(locked.shouldHideNotes, isFalse);
      expect(locked.shouldHideLists, isTrue);
      expect(locked.needsHomeGate, isFalse);
      expect(locked.needsListsGate(EntryFilter.lists), isTrue);
    });

    test('both locked asks for PIN on All', () {
      const locked = PinLockPolicy(
        hasPin: true,
        target: PinLockTarget.both,
        notesUnlocked: false,
        listsUnlocked: false,
      );
      expect(locked.needsHomeGate, isTrue);
      expect(locked.shouldHideNotes, isTrue);
      expect(locked.shouldHideLists, isTrue);

      const open = PinLockPolicy(
        hasPin: true,
        target: PinLockTarget.both,
        notesUnlocked: true,
        listsUnlocked: true,
      );
      expect(open.needsHomeGate, isFalse);
      expect(open.shouldHideNotes, isFalse);
      expect(open.shouldHideLists, isFalse);
    });
  });

  group('PinLockController', () {
    test('set / unlock / lock / remove', () async {
      final lock = PinLockController();
      expect(lock.hasPin, isFalse);

      await lock.setPin('2468');
      expect(lock.hasPin, isTrue);
      // Setting a PIN authenticates this session.
      expect(lock.shouldHideNotes, isFalse);

      lock.lockNow();
      expect(lock.needsHomeGate, isTrue);
      expect(await lock.unlockWithPin('0000'), isFalse);
      expect(lock.needsHomeGate, isTrue);
      expect(await lock.unlockWithPin('2468'), isTrue);
      expect(lock.needsHomeGate, isFalse);

      await lock.removePin();
      expect(lock.hasPin, isFalse);
      expect(lock.shouldHideNotes, isFalse);
      lock.dispose();
    });

    test('notes target does not hide lists', () async {
      final lock = PinLockController();
      await lock.setTarget(PinLockTarget.notes);
      await lock.setPin('1357');
      lock.lockNow();
      expect(lock.shouldHideNotes, isTrue);
      expect(lock.shouldHideLists, isFalse);
      expect(lock.needsHomeGate, isFalse);
      lock.dispose();
    });

    test('background resume past the timer locks again', () async {
      var now = DateTime.utc(2026, 8, 24, 12, 0);
      final lock = PinLockController(clock: () => now);
      await lock.setAutoLock(AutoLockMinutes.one);
      await lock.setPin('9999');
      lock.lockNow();
      expect(await lock.unlockWithPin('9999'), isTrue);
      expect(lock.shouldHideNotes, isFalse);

      now = now.add(const Duration(minutes: 2));
      lock.onResumed();
      expect(lock.shouldHideNotes, isTrue);
      expect(lock.needsHomeGate, isTrue);
      lock.dispose();
    });

    test('user activity pushes the auto-lock deadline forward', () async {
      var now = DateTime.utc(2026, 8, 24, 12, 0);
      final lock = PinLockController(clock: () => now);
      await lock.setAutoLock(AutoLockMinutes.one);
      await lock.setPin('9999');
      lock.lockNow();
      expect(await lock.unlockWithPin('9999'), isTrue);

      // Halfway through the minute the user is still working.
      now = now.add(const Duration(seconds: 30));
      lock.noteActivity();

      // Past the ORIGINAL deadline, but only 45 s after the activity.
      now = now.add(const Duration(seconds: 45));
      lock.onResumed();
      expect(lock.shouldHideNotes, isFalse);

      // 16 s later (61 s after the activity) the pushed deadline has passed.
      now = now.add(const Duration(seconds: 16));
      lock.onResumed();
      expect(lock.shouldHideNotes, isTrue);
      lock.dispose();
    });

    test('activity while locked never arms a timer nor unlocks', () async {
      var now = DateTime.utc(2026, 8, 24, 12, 0);
      final lock = PinLockController(clock: () => now);
      await lock.setAutoLock(AutoLockMinutes.one);
      await lock.setPin('9999');
      lock.lockNow();

      // An attacker tapping around on the lock screen must gain nothing…
      lock.noteActivity();

      // …not even after staying away far past every deadline.
      now = now.add(const Duration(minutes: 30));
      lock.onResumed();
      expect(lock.shouldHideNotes, isTrue);
      expect(lock.needsHomeGate, isTrue);
      lock.dispose();
    });

    test('closing the session locks immediately', () async {
      final lock = PinLockController();
      await lock.setPin('1111');
      expect(lock.shouldHideNotes, isFalse);
      lock.onSessionEnded();
      expect(lock.shouldHideNotes, isTrue);
      lock.dispose();
    });

    test('three wrong tries briefly block further attempts', () async {
      var now = DateTime.utc(2026, 8, 24, 12, 0);
      final lock = PinLockController(clock: () => now);
      await lock.setPin('2222');
      lock.lockNow();

      expect(await lock.unlockWithPin('0000'), isFalse);
      expect(await lock.unlockWithPin('0000'), isFalse);
      expect(await lock.unlockWithPin('0000'), isFalse);
      expect(lock.isBlocked, isTrue);
      expect(await lock.unlockWithPin('2222'), isFalse);

      now = now.add(const Duration(seconds: 6));
      expect(lock.isBlocked, isFalse);
      expect(await lock.unlockWithPin('2222'), isTrue);
      lock.dispose();
    });
  });
}
