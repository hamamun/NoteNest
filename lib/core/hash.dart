/// Small dependency-free content hash used for change detection (D-01
/// `last_local_hash`). FNV-1a 64-bit is more than strong enough to answer
/// "did this entry change since the last sync?" and avoids pulling in a
/// crypto dependency on a hot path.
library;

class ContentHash {
  ContentHash._();

  static const int _offsetBasis = 0xcbf29ce484222325;
  static const int _prime = 0x100000001b3;

  static String of(String input) {
    var hash = _offsetBasis;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * _prime) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  /// Hashes the fields that make up an entry's syncable content.
  static String ofParts(List<Object?> parts) =>
      of(parts.map((p) => p?.toString() ?? '').join('\u0001'));
}
