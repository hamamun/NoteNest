import 'package:flutter/material.dart';

import '../features/sync/sync_controller.dart';
import 'icons.dart';

/// Top-bar sync control. Spins the cloud icon the whole time a sync is running.
class SyncStatusButton extends StatefulWidget {
  const SyncStatusButton({
    super.key,
    required this.sync,
    this.onPressed,
  });

  final SyncController sync;
  final VoidCallback? onPressed;

  @override
  State<SyncStatusButton> createState() => _SyncStatusButtonState();
}

class _SyncStatusButtonState extends State<SyncStatusButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncSpin(widget.sync.isSyncing);
  }

  @override
  void didUpdateWidget(covariant SyncStatusButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpin(widget.sync.isSyncing);
  }

  void _syncSpin(bool syncing) {
    if (syncing) {
      if (!_spin.isAnimating) _spin.repeat();
    } else if (_spin.isAnimating) {
      _spin
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync = widget.sync;
    final scheme = Theme.of(context).colorScheme;
    final syncing = sync.isSyncing;

    final IconData icon;
    Color? color;
    if (syncing) {
      icon = AppIcons.sync;
      color = scheme.primary;
    } else {
      switch (sync.state) {
        case SyncUiState.connected:
          icon = AppIcons.syncOk;
        case SyncUiState.failed:
          icon = AppIcons.syncError;
          color = scheme.error;
        case SyncUiState.syncing:
          icon = AppIcons.sync;
          color = scheme.primary;
        case SyncUiState.notConnected:
        case SyncUiState.reconnectRequired:
          icon = AppIcons.syncOff;
      }
    }

    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      label: sync.statusLabel,
      child: IconButton(
        tooltip: sync.statusLabel,
        onPressed: widget.onPressed,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: syncing
            ? RotationTransition(
                turns: _spin,
                child: Icon(icon, color: color),
              )
            : Icon(icon, color: color),
      ),
    );
  }
}
