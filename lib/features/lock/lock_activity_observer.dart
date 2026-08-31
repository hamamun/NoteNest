import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'pin_lock_controller.dart';

/// PIN-05: feeds every in-app user interaction into
/// [PinLockController.noteActivity] so the auto-lock fires after inactivity,
/// not while somebody is actively working.
///
/// This widget belongs in [MaterialApp.builder], *above* the Navigator: pushed
/// routes (the note editor, settings, dialogs) are then covered too, which a
/// listener placed in `home` would miss.
///
/// Two event sources are watched:
///
/// * Pointer events, through a [Listener]. Taps, drags (a move with a button
///   down), wheel scrolls and trackpad pans all count; bare mouse hover does
///   not, because drifting the pointer across the desk is not using the app.
/// * Physical key presses, through [HardwareKeyboard.instance]. The handler
///   sees every key event even while a text field owns focus, which is what
///   makes desktop typing count.
///
/// One source cannot be caught here: a phone's soft keyboard renders in the
/// OS input window, so its keystrokes reach the app as neither pointer nor
/// key events. Editors therefore report typing themselves — see the
/// `TextEditingController` listeners in the item page.
class LockActivityObserver extends StatefulWidget {
  const LockActivityObserver({super.key, required this.child});

  final Widget child;

  @override
  State<LockActivityObserver> createState() => _LockActivityObserverState();
}

class _LockActivityObserverState extends State<LockActivityObserver> {
  bool _onKey(KeyEvent event) {
    _lock().noteActivity();
    return false; // Never consumes: the event continues into the app.
  }

  PinLockController _lock() => context.read<PinLockController>();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Translucent so a tap on a blank corner of a page still counts as
      // activity while the widget under it keeps receiving the event.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _lock().noteActivity(),
      onPointerMove: (event) {
        if (event.down) _lock().noteActivity();
      },
      // PIN-05: wheel scrolls count as activity. `Listener.onPointerScroll`
      // only exists on newer SDKs, so use the classic onPointerSignal +
      // PointerScrollEvent form that every supported Flutter has.
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) _lock().noteActivity();
      },
      onPointerPanZoomUpdate: (_) => _lock().noteActivity(),
      child: widget.child,
    );
  }
}
