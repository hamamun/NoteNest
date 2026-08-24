import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Hashes a 4-digit PIN so the digits themselves are never stored.
///
/// Format: `v1$<salt-hex>$<sha256-hex>`. The OS keystore already protects the
/// blob; the salt stops a dumped hash from matching another device.
class PinHasher {
  PinHasher._();

  static final Random _random = Random.secure();

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static String randomSalt({int length = 16}) {
    final bytes = List<int>.generate(length, (_) => _random.nextInt(256));
    return _hex(bytes);
  }

  static Future<String> hash(String pin, {String? salt}) async {
    final usedSalt = salt ?? randomSalt();
    final digest = await Sha256().hash(utf8.encode('$usedSalt:$pin'));
    return 'v1\$$usedSalt\$${_hex(digest.bytes)}';
  }

  static Future<bool> verify(String pin, String stored) async {
    final parts = stored.split('\$');
    if (parts.length != 3 || parts[0] != 'v1') return false;
    final candidate = await hash(pin, salt: parts[1]);
    if (candidate.length != stored.length) return false;
    var diff = 0;
    for (var i = 0; i < candidate.length; i++) {
      diff |= candidate.codeUnitAt(i) ^ stored.codeUnitAt(i);
    }
    return diff == 0;
  }

  static bool isFourDigits(String pin) =>
      pin.length == 4 && RegExp(r'^\d{4}$').hasMatch(pin);
}
