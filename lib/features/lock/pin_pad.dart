import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/icons.dart';
import 'pin_hasher.dart';
import 'pin_lock_controller.dart';

/// A 4-digit PIN pad used for unlock, setup and confirm.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    required this.onSubmit,
    this.subtitle,
    this.footer,
    this.confirmTitle = 'Enter the same PIN again',
    this.confirmSubtitle = 'This confirms the PIN before it is saved.',
    this.requireConfirm = false,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final String confirmTitle;
  final String confirmSubtitle;
  final Widget? footer;
  final Future<bool> Function(String pin) onSubmit;
  final bool requireConfirm;
  final bool enabled;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  final FocusNode _focus = FocusNode();
  String _digits = '';
  String? _firstPin;
  String? _error;
  bool _busy = false;

  bool get _confirming => _firstPin != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    final digit = _digitFor(key);
    if (digit == null) return KeyEventResult.ignored;
    _tap(digit);
    return KeyEventResult.handled;
  }

  String? _digitFor(LogicalKeyboardKey key) {
    const digits = <LogicalKeyboardKey, String>{
      LogicalKeyboardKey.digit0: '0',
      LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.digit8: '8',
      LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.numpad0: '0',
      LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.numpad9: '9',
    };
    return digits[key];
  }

  void _tap(String digit) {
    if (!widget.enabled || _busy || _digits.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _digits += digit;
      _error = null;
    });
    if (_digits.length == 4) {
      unawaited(_finish());
    }
  }

  void _backspace() {
    if (!widget.enabled || _busy || _digits.isEmpty) return;
    setState(() {
      _digits = _digits.substring(0, _digits.length - 1);
      _error = null;
    });
  }

  Future<void> _finish() async {
    final pin = _digits;
    if (!PinHasher.isFourDigits(pin)) return;

    if (widget.requireConfirm && _firstPin == null) {
      setState(() {
        _firstPin = pin;
        _digits = '';
        _error = null;
      });
      return;
    }

    if (widget.requireConfirm && _firstPin != pin) {
      HapticFeedback.heavyImpact();
      setState(() {
        _firstPin = null;
        _digits = '';
        _error = 'The two PINs did not match. Try again.';
      });
      return;
    }

    setState(() => _busy = true);
    final ok = await widget.onSubmit(pin);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _busy = false;
        _digits = '';
        _error = null;
      });
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() {
      _busy = false;
      _digits = '';
      _error = 'Wrong PIN. Try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _confirming ? widget.confirmTitle : widget.title;
    final subtitle =
        _confirming ? widget.confirmSubtitle : widget.subtitle;

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.lock,
                size: 36,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              _Dots(filled: _digits.length, error: _error != null),
              const SizedBox(height: 12),
              SizedBox(
                height: 22,
                child: _busy
                    ? const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _error == null
                        ? const SizedBox.shrink()
                        : Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
              ),
              const SizedBox(height: 16),
              _Keypad(
                enabled: widget.enabled && !_busy,
                onDigit: _tap,
                onBackspace: _backspace,
              ),
              if (widget.footer != null) ...[
                const SizedBox(height: 20),
                widget.footer!,
              ],
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.filled, required this.error});

  final int filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = error ? scheme.error : scheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? active : Colors.transparent,
              border: Border.all(
                color: i < filled ? active : scheme.outline,
                width: 2,
              ),
            ),
          ),
      ],
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final bool enabled;
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, IconData? icon}) {
      return SizedBox(
        width: 84,
        height: 64,
        child: InkWell(
          onTap: enabled ? (onTap ?? () => onDigit(label)) : null,
          customBorder: const CircleBorder(),
          child: Center(
            child: icon != null
                ? Icon(icon, size: 22)
                : Text(
                    label,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [for (final d in row) key(d)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 84, height: 64),
            key('0'),
            key(
              'back',
              icon: Icons.backspace_outlined,
              onTap: onBackspace,
            ),
          ],
        ),
      ],
    );
  }
}

/// In-place unlock used on Home and on a locked open item.
class PinUnlockView extends StatelessWidget {
  const PinUnlockView({
    super.key,
    required this.lock,
    required this.title,
    this.subtitle,
  });

  final PinLockController lock;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final blocked = lock.isBlocked;
    return PinPad(
      title: title,
      subtitle: blocked
          ? 'Too many tries. Wait ${lock.blockedFor.inSeconds + 1}s.'
          : subtitle,
      enabled: !blocked,
      onSubmit: lock.unlockWithPin,
    );
  }
}
