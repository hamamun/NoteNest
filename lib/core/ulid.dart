import 'dart:math';

/// ULID generator (P-08).
///
/// A ULID is a 26-character, lexicographically sortable, collision-resistant
/// identifier. Sortability matters here because entry ids double as stable
/// sync filenames, and monotonic ids make debugging sync order far easier
/// than random UUIDs.
class Ulid {
  Ulid._();

  static const String _crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static final Random _random = Random.secure();

  static int _lastTime = -1;
  static final List<int> _lastRandom = List<int>.filled(16, 0);

  /// Generates a new ULID string.
  ///
  /// Within the same millisecond the random component is incremented rather
  /// than regenerated, which guarantees strict monotonicity for ids created
  /// in a tight loop (for example when splitting a checklist into items).
  static String generate() {
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now == _lastTime) {
      _incrementRandom();
    } else {
      _lastTime = now;
      for (var i = 0; i < 16; i++) {
        _lastRandom[i] = _random.nextInt(32);
      }
    }

    final buffer = StringBuffer();

    // 10 characters of timestamp (48 bits).
    var time = now;
    final timeChars = List<String>.filled(10, '0');
    for (var i = 9; i >= 0; i--) {
      timeChars[i] = _crockford[time % 32];
      time = time ~/ 32;
    }
    buffer.writeAll(timeChars);

    // 16 characters of randomness (80 bits).
    for (var i = 0; i < 16; i++) {
      buffer.write(_crockford[_lastRandom[i]]);
    }

    return buffer.toString();
  }

  static void _incrementRandom() {
    for (var i = 15; i >= 0; i--) {
      if (_lastRandom[i] < 31) {
        _lastRandom[i]++;
        return;
      }
      _lastRandom[i] = 0;
    }
  }

  /// Returns true when [value] looks like a ULID produced by [generate].
  static bool isValid(String value) {
    if (value.length != 26) return false;
    for (final unit in value.codeUnits) {
      if (!_crockford.contains(String.fromCharCode(unit))) return false;
    }
    return true;
  }
}
