import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/icons.dart';
import '../../data/models/enums.dart';
import '../lock/pin_lock_controller.dart';
import '../lock/pin_pad.dart';

/// Settings > Privacy. The PIN never leaves this device and is never synced.
class LockSettingsPage extends StatefulWidget {
  const LockSettingsPage({super.key});

  @override
  State<LockSettingsPage> createState() => _LockSettingsPageState();
}

class _LockSettingsPageState extends State<LockSettingsPage> {
  bool _verified = false;
  bool _settingPin = false;
  String? _status;

  Future<void> _beginSetPin() async {
    setState(() {
      _settingPin = true;
      _status = null;
    });
  }

  Future<bool> _savePin(String pin) async {
    final lock = context.read<PinLockController>();
    await lock.setPin(pin);
    if (!mounted) return true;
    setState(() {
      _settingPin = false;
      _verified = true;
      _status = 'PIN saved on this device.';
    });
    return true;
  }

  Future<void> _changePin() async {
    final lock = context.read<PinLockController>();
    final ok = await _askPin(
      context,
      title: 'Enter current PIN',
      subtitle: 'Required to change the PIN.',
      verify: lock.unlockWithPin,
    );
    if (!ok || !mounted) return;
    setState(() {
      _settingPin = true;
      _verified = true;
      _status = null;
    });
  }

  Future<void> _removePin() async {
    final lock = context.read<PinLockController>();
    final ok = await _askPin(
      context,
      title: 'Enter current PIN',
      subtitle: 'Required to turn the lock off.',
      verify: lock.unlockWithPin,
    );
    if (!ok || !mounted) return;
    await lock.removePin();
    if (!mounted) return;
    setState(() {
      _verified = false;
      _settingPin = false;
      _status = 'PIN removed. Nothing is locked.';
    });
  }

  Future<bool> _ensureVerified() async {
    final lock = context.read<PinLockController>();
    if (!lock.hasPin || _verified) return true;
    final ok = await _askPin(
      context,
      title: 'Enter PIN',
      subtitle: 'Required to change lock settings.',
      verify: lock.unlockWithPin,
    );
    if (ok && mounted) setState(() => _verified = true);
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<PinLockController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          icon: AppIcons.back,
          label: 'Back',
          onPressed: () {
            if (_settingPin) {
              setState(() => _settingPin = false);
              return;
            }
            Navigator.of(context).pop();
          },
        ),
        title: Text(_settingPin ? 'Set PIN' : 'Privacy lock'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _settingPin
              ? PinPad(
                  title: lock.hasPin ? 'Choose a new PIN' : 'Choose a 4-digit PIN',
                  subtitle: 'You will need this PIN to open locked notes or lists.',
                  requireConfirm: true,
                  onSubmit: _savePin,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Text(
                      'A PIN on this device can hide notes, lists, or both. '
                      'It is never synced to GitHub. There is no recovery — '
                      'if you forget it, you will have to clear app data '
                      '(synced notes can come back after you reconnect).',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    if (_status != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _status!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (!lock.hasPin)
                      FilledButton.icon(
                        onPressed: _beginSetPin,
                        icon: const Icon(AppIcons.lock),
                        label: const Text('Set a 4-digit PIN'),
                      )
                    else ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(AppIcons.lock),
                        title: const Text('PIN is set'),
                        subtitle: Text('Locking ${lock.target.label.toLowerCase()}'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: _changePin,
                            child: const Text('Change PIN'),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: _removePin,
                            child: const Text('Remove PIN'),
                          ),
                        ],
                      ),
                      const Divider(height: 40),
                      Text('What to lock', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        'Archive and Trash stay open. Only Home is protected.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final target in PinLockTarget.values)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () async {
                            if (!await _ensureVerified()) return;
                            await lock.setTarget(target);
                          },
                          leading: Icon(
                            lock.target == target
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: lock.target == target
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                          title: Text(target.label),
                        ),
                      const Divider(height: 40),
                      Text('Auto-lock', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        'After you unlock, the timer starts. When it ends, '
                        'Home locks again. Closing the app locks at once. '
                        'On a phone, leaving NoteNest in the background '
                        'keeps it unlocked until this timer ends.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final option in AutoLockMinutes.values)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () async {
                            if (!await _ensureVerified()) return;
                            await lock.setAutoLock(option);
                          },
                          leading: Icon(
                            lock.autoLock == option
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: lock.autoLock == option
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                          title: Text(option.label),
                        ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

Future<bool> _askPin(
  BuildContext context, {
  required String title,
  required String subtitle,
  required Future<bool> Function(String pin) verify,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
        content: SizedBox(
          width: 360,
          child: PinPad(
            title: title,
            subtitle: subtitle,
            onSubmit: (pin) async {
              final ok = await verify(pin);
              if (ok && dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
              return ok;
            },
            footer: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
}
