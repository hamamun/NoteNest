import 'package:wakelock_plus/wakelock_plus.dart';

/// Thin wrapper so a missing or unsupported platform cannot crash View Mode.
class ScreenAwake {
  ScreenAwake._();

  static Future<void> setEnabled(bool enabled) async {
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {
      // Windows, tests, or a plugin that is not yet generated — ignore.
    }
  }
}
