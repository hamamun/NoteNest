import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/logging.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/secure_store.dart';
import '../../data/repositories/settings_repository.dart';
import 'pin_hasher.dart';
import 'pin_lock_policy.dart';

/// Owns the device PIN, what it protects, and whether Home is currently open.
///
/// Unlock state lives only in memory. Killing the process therefore locks at
/// once, which is the "close the app → lock" rule. A phone left in the
/// background keeps this object alive and stays unlocked until [autoLock]
/// elapses.
class PinLockController extends ChangeNotifier {
  PinLockController({
    SettingsRepository? settings,
    SecureStore? secureStore,
    DateTime Function()? clock,
  })  : _settings = settings,
        _secure = secureStore,
        _now = clock ?? DateTime.now;

  final SettingsRepository? _settings;
  final SecureStore? _secure;
  final DateTime Function() _now;

  bool _hasPin = false;
  PinLockTarget _target = PinLockTarget.both;
  AutoLockMinutes _autoLock = AutoLockMinutes.five;
  bool _notesUnlocked = false;
  bool _listsUnlocked = false;
  DateTime? _unlockDeadline;
  Timer? _timer;
  int _failures = 0;
  DateTime? _blockedUntil;
  String? _memoryHash;

  bool get hasPin => _hasPin;
  PinLockTarget get target => _target;
  AutoLockMinutes get autoLock => _autoLock;
  int get failureCount => _failures;

  PinLockPolicy get policy => PinLockPolicy(
        hasPin: _hasPin,
        target: _target,
        notesUnlocked: _notesUnlocked,
        listsUnlocked: _listsUnlocked,
      );

  bool get shouldHideNotes => policy.shouldHideNotes;
  bool get shouldHideLists => policy.shouldHideLists;
  bool get needsHomeGate => policy.needsHomeGate;

  bool get isBlocked {
    final until = _blockedUntil;
    return until != null && _now().isBefore(until);
  }

  Duration get blockedFor {
    final until = _blockedUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> load() async {
    if (_settings != null) {
      _target = _settings.pinLockTarget;
      _autoLock = _settings.autoLockMinutes;
    }
    if (_secure != null) {
      _hasPin = await _secure.hasPin();
    } else {
      _hasPin = _memoryHash != null;
    }
    notifyListeners();
  }

  Future<void> setPin(String pin) async {
    if (!PinHasher.isFourDigits(pin)) {
      throw ArgumentError('PIN must be exactly 4 digits.');
    }
    final hash = await PinHasher.hash(pin);
    if (_secure != null) {
      await _secure.writePinHash(hash);
    } else {
      _memoryHash = hash;
    }
    _hasPin = true;
    _failures = 0;
    _blockedUntil = null;
    _unlockForTarget();
    AppLog.info('lock', 'PIN set (target ${_target.value})');
    notifyListeners();
  }

  Future<void> removePin() async {
    if (_secure != null) {
      await _secure.deletePinHash();
    }
    _memoryHash = null;
    _hasPin = false;
    _notesUnlocked = false;
    _listsUnlocked = false;
    _unlockDeadline = null;
    _timer?.cancel();
    _failures = 0;
    _blockedUntil = null;
    AppLog.info('lock', 'PIN removed');
    notifyListeners();
  }

  Future<void> setTarget(PinLockTarget target) async {
    _target = target;
    if (_settings != null) await _settings.setPinLockTarget(target);
    if (target == PinLockTarget.both &&
        (_notesUnlocked || _listsUnlocked)) {
      _unlockForTarget();
    }
    notifyListeners();
  }

  Future<void> setAutoLock(AutoLockMinutes value) async {
    _autoLock = value;
    if (_settings != null) await _settings.setAutoLockMinutes(value);
    if (_notesUnlocked || _listsUnlocked) {
      _armTimer();
    }
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    if (!_hasPin) return false;
    if (!PinHasher.isFourDigits(pin)) return false;
    final stored = _secure != null ? await _secure.readPinHash() : _memoryHash;
    if (stored == null || stored.isEmpty) return false;
    return PinHasher.verify(pin, stored);
  }

  /// Checks the PIN and, on success, opens every section the target covers.
  Future<bool> unlockWithPin(String pin) async {
    if (isBlocked) return false;
    final ok = await verifyPin(pin);
    if (!ok) {
      _failures += 1;
      if (_failures >= 3) {
        final seconds = 5 * (_failures - 2);
        _blockedUntil = _now().add(Duration(seconds: seconds));
      }
      notifyListeners();
      return false;
    }
    _failures = 0;
    _blockedUntil = null;
    _unlockForTarget();
    notifyListeners();
    return true;
  }

  void lockNow() {
    final changed = _notesUnlocked || _listsUnlocked;
    _notesUnlocked = false;
    _listsUnlocked = false;
    _unlockDeadline = null;
    _timer?.cancel();
    _timer = null;
    if (changed) {
      AppLog.info('lock', 'locked');
      notifyListeners();
    }
  }

  /// Called when the app becomes visible again. A suspended isolate may have
  /// missed the timer, so we compare against the deadline.
  void onResumed() {
    final deadline = _unlockDeadline;
    if (deadline != null && !_now().isBefore(deadline)) {
      lockNow();
    }
  }

  /// Closing the window / killing the session locks immediately.
  void onSessionEnded() => lockNow();

  void _unlockForTarget() {
    _notesUnlocked = _target.locksNotes;
    _listsUnlocked = _target.locksLists;
    _armTimer();
  }

  void _armTimer() {
    _timer?.cancel();
    _unlockDeadline = _now().add(_autoLock.duration);
    _timer = Timer(_autoLock.duration, lockNow);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
