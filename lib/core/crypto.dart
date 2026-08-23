import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// B-15 / DEC-5: AES-256-GCM with PBKDF2-HMAC-SHA256 key derivation.
///
/// File layout, byte for byte:
///
/// ```text
/// "NNBK1"  5 bytes   magic, lets us detect and version the format
/// salt    16 bytes   random per file
/// nonce   12 bytes   random per file, never reused with the same key
/// ct       n bytes   ciphertext
/// tag     16 bytes   GCM authentication tag
/// ```
///
/// The tag is stored last so the whole payload can be streamed; decryption
/// verifies it before returning a single byte of plaintext, which means a
/// corrupted or tampered backup fails loudly instead of silently.
class AppCrypto {
  AppCrypto._();

  static const List<int> magic = <int>[0x4E, 0x4E, 0x42, 0x4B, 0x31]; // NNBK1
  static const int saltLength = 16;
  static const int nonceLength = 12;
  static const int tagLength = 16;
  static const int iterations = 200000;

  static final Random _random = Random.secure();

  static Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  static Future<SecretKey> _deriveKey(String passphrase, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
  }

  /// Encrypts [plain] with a key derived from [passphrase].
  static Future<Uint8List> encrypt({
    required Uint8List plain,
    required String passphrase,
  }) async {
    final salt = _randomBytes(saltLength);
    final nonce = _randomBytes(nonceLength);
    final key = await _deriveKey(passphrase, salt);

    final box = await AesGcm.with256bits().encrypt(
      plain,
      secretKey: key,
      nonce: nonce,
    );

    final out = BytesBuilder()
      ..add(magic)
      ..add(salt)
      ..add(nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return out.toBytes();
  }

  /// Decrypts a payload produced by [encrypt].
  ///
  /// Throws [CryptoFormatException] when the file is not ours and
  /// [WrongPassphraseException] when the tag does not verify.
  static Future<Uint8List> decrypt({
    required Uint8List payload,
    required String passphrase,
  }) async {
    if (!looksEncrypted(payload)) {
      throw const CryptoFormatException('Not a NoteNest encrypted file.');
    }
    final minimum = magic.length + saltLength + nonceLength + tagLength;
    if (payload.length < minimum) {
      throw const CryptoFormatException('Encrypted file is truncated.');
    }

    var offset = magic.length;
    final salt = payload.sublist(offset, offset += saltLength);
    final nonce = payload.sublist(offset, offset += nonceLength);
    final cipherText = payload.sublist(offset, payload.length - tagLength);
    final mac = payload.sublist(payload.length - tagLength);

    final key = await _deriveKey(passphrase, salt);
    try {
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const WrongPassphraseException(
        'Wrong passphrase, or the file has been modified.',
      );
    }
  }

  static bool looksEncrypted(List<int> payload) {
    if (payload.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (payload[i] != magic[i]) return false;
    }
    return true;
  }

  /// Convenience wrapper for encrypting text (V3 note-body encryption).
  static Future<String> encryptText(String text, String passphrase) async {
    final bytes = await encrypt(
      plain: Uint8List.fromList(utf8.encode(text)),
      passphrase: passphrase,
    );
    return base64.encode(bytes);
  }

  static Future<String> decryptText(String encoded, String passphrase) async {
    final bytes = await decrypt(
      payload: Uint8List.fromList(base64.decode(encoded.trim())),
      passphrase: passphrase,
    );
    return utf8.decode(bytes);
  }
}

class CryptoFormatException implements Exception {
  const CryptoFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WrongPassphraseException implements Exception {
  const WrongPassphraseException(this.message);
  final String message;
  @override
  String toString() => message;
}
