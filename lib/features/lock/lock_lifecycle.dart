import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pin_lock_controller.dart';

/// Watches the process so a closed session locks at once, while a phone left
/// in the background only locks when the user's timer has run out.
class LockLifecycle extends StatefulWidget {
  const LockLifecycle({super.key, required this.child});

  final Widget child;

  @override
  State<LockLifecycle> createState() => _LockLifecycleState();
}

class _LockLifecycleState extends State<LockLifecycle> {
  AppLifecycleListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listener ??= AppLifecycleListener(
      onResume: () => context.read<PinLockController>().onResumed(),
      onDetach: () => context.read<PinLockController>().onSessionEnded(),
      onExitRequested: () async {
        context.read<PinLockController>().onSessionEnded();
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
