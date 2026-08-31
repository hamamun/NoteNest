import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notenest/data/models/enums.dart';
import 'package:notenest/features/lock/lock_activity_observer.dart';
import 'package:notenest/features/lock/pin_lock_controller.dart';
import 'package:provider/provider.dart';

/// PIN-05: the auto-lock must fire after inactivity, never while the user is
/// working. These tests drive the real controller timers with the fake clock
/// that `testWidgets` provides.
void main() {
  Future<void> pumpApp(WidgetTester tester, PinLockController lock) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<PinLockController>.value(
        value: lock,
        child: const LockActivityObserver(
          child: MaterialApp(
            home: Scaffold(body: Center(child: Text('body'))),
          ),
        ),
      ),
    );
  }

  testWidgets('a tap pushes the auto-lock deadline forward', (tester) async {
    final lock = PinLockController();
    await lock.setAutoLock(AutoLockMinutes.one);
    await lock.setPin('1234');
    await pumpApp(tester, lock);

    // 40 s of the 60 elapse, then the user taps.
    await tester.pump(const Duration(seconds: 40));
    await tester.tap(find.text('body'));
    await tester.pump(const Duration(milliseconds: 100));

    // 40 s more: past the original deadline, still unlocked.
    await tester.pump(const Duration(seconds: 40));
    expect(lock.shouldHideNotes, isFalse);

    // Another 21 s of silence: locked, one minute after the tap.
    await tester.pump(const Duration(seconds: 21));
    expect(lock.shouldHideNotes, isTrue);
    lock.dispose();
  });

  testWidgets('a physical key press pushes the deadline forward', (tester) async {
    final lock = PinLockController();
    await lock.setAutoLock(AutoLockMinutes.one);
    await lock.setPin('1234');
    await pumpApp(tester, lock);

    await tester.pump(const Duration(seconds: 40));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pump(const Duration(seconds: 40));
    expect(lock.shouldHideNotes, isFalse);

    await tester.pump(const Duration(seconds: 21));
    expect(lock.shouldHideNotes, isTrue);
    lock.dispose();
  });

  testWidgets('bare mouse hover does not keep the session open', (tester) async {
    final lock = PinLockController();
    await lock.setAutoLock(AutoLockMinutes.one);
    await lock.setPin('1234');
    await pumpApp(tester, lock);

    // Drift a mouse across the page without pressing anything.
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.text('body')));
    await gesture.moveTo(tester.getTopLeft(find.text('body')));
    await tester.pump(const Duration(seconds: 61));

    // No button was ever down: that is inactivity, and it locks.
    expect(lock.shouldHideNotes, isTrue);
    lock.dispose();
  });
}
