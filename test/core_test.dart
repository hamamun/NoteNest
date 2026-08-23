import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notenest/core/crypto.dart';
import 'package:notenest/core/hash.dart';
import 'package:notenest/core/logging.dart';
import 'package:notenest/core/time.dart';
import 'package:notenest/core/ulid.dart';
import 'package:notenest/features/export/export_service.dart';

void main() {
  group('ULID (P-08)', () {
    test('is 26 characters and valid', () {
      final id = Ulid.generate();
      expect(id.length, 26);
      expect(Ulid.isValid(id), isTrue);
    });

    test('is monotonic even inside one millisecond', () {
      final ids = List.generate(500, (_) => Ulid.generate());
      final sorted = [...ids]..sort();
      expect(ids, sorted, reason: 'ULIDs must be lexicographically sortable');
      expect(ids.toSet().length, ids.length, reason: 'no collisions');
    });
  });

  group('token redaction (SEC-08)', () {
    test('classic PAT is redacted', () {
      final out = AppLog.redact('failed with ghp_abcdefghij1234567890ABCDEF');
      expect(out, isNot(contains('ghp_abcdefghij')));
      expect(out, contains('REDACTED'));
    });

    test('fine-grained PAT is redacted', () {
      final out = AppLog.redact(
        'token github_pat_11ABCDEFG0abcdefghij_1234567890abcdefXYZ used',
      );
      expect(out, isNot(contains('github_pat_11ABCDEFG')));
    });

    test('authorization headers are redacted', () {
      final out = AppLog.redact('Authorization: Bearer secretvalue123');
      expect(out, isNot(contains('secretvalue123')));
    });

    test('ordinary text is untouched', () {
      expect(AppLog.redact('sync finished, 3 notes'), 'sync finished, 3 notes');
    });
  });

  group('backup encryption (B-15)', () {
    test('round trips', () async {
      final plain = Uint8List.fromList(utf8.encode('secret backup contents'));
      final encrypted =
          await AppCrypto.encrypt(plain: plain, passphrase: 'correct horse');

      expect(AppCrypto.looksEncrypted(encrypted), isTrue);
      expect(encrypted, isNot(equals(plain)));

      final decrypted = await AppCrypto.decrypt(
        payload: encrypted,
        passphrase: 'correct horse',
      );
      expect(utf8.decode(decrypted), 'secret backup contents');
    });

    test('a wrong passphrase fails loudly', () async {
      final encrypted = await AppCrypto.encrypt(
        plain: Uint8List.fromList(utf8.encode('data')),
        passphrase: 'right',
      );
      expect(
        () => AppCrypto.decrypt(payload: encrypted, passphrase: 'wrong'),
        throwsA(isA<WrongPassphraseException>()),
      );
    });

    test('tampering is detected', () async {
      final encrypted = await AppCrypto.encrypt(
        plain: Uint8List.fromList(utf8.encode('data')),
        passphrase: 'pass',
      );
      encrypted[encrypted.length - 3] ^= 0xFF;
      expect(
        () => AppCrypto.decrypt(payload: encrypted, passphrase: 'pass'),
        throwsA(isA<WrongPassphraseException>()),
      );
    });

    test('a plain zip is not mistaken for an encrypted file', () {
      final zipMagic = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0, 0]);
      expect(AppCrypto.looksEncrypted(zipMagic), isFalse);
    });

    test('salt and nonce differ between runs', () async {
      final a = await AppCrypto.encrypt(
        plain: Uint8List.fromList(utf8.encode('same')),
        passphrase: 'same',
      );
      final b = await AppCrypto.encrypt(
        plain: Uint8List.fromList(utf8.encode('same')),
        passphrase: 'same',
      );
      expect(a, isNot(equals(b)));
    });

    test('text helpers round trip', () async {
      final encoded = await AppCrypto.encryptText('চা এবং দুধ', 'pass');
      expect(await AppCrypto.decryptText(encoded, 'pass'), 'চা এবং দুধ');
    });
  });

  group('export filenames (E-05)', () {
    final ms = DateTime.utc(2026, 8, 23).millisecondsSinceEpoch;

    test('normal title', () {
      expect(
        ExportService.safeFileName('Shopping List', ms, '.pdf'),
        'Shopping List - 2026-08-23.pdf',
      );
    });

    test('illegal characters are stripped', () {
      final name = ExportService.safeFileName('a/b\\c:d*e?f"g<h>i|j', ms, '.txt');
      expect(name, isNot(contains(RegExp(r'[<>:"/\\|?*]'))));
      expect(name, endsWith('.txt'));
    });

    test('empty title falls back to Untitled', () {
      expect(
        ExportService.safeFileName('   ', ms, '.pdf'),
        'Untitled - 2026-08-23.pdf',
      );
    });

    test('reserved windows device names are escaped', () {
      expect(ExportService.safeFileName('CON', ms, '.txt'), startsWith('_CON'));
      expect(ExportService.safeFileName('com1', ms, '.txt'), startsWith('_com1'));
    });

    test('trailing dots and spaces are removed', () {
      final name = ExportService.safeFileName('Report...  ', ms, '.pdf');
      expect(name, 'Report - 2026-08-23.pdf');
    });

    test('very long titles are truncated', () {
      final name = ExportService.safeFileName('x' * 300, ms, '.pdf');
      expect(name.length, lessThan(120));
    });

    test('newlines collapse', () {
      expect(
        ExportService.safeFileName('two\nlines', ms, '.txt'),
        'two lines - 2026-08-23.txt',
      );
    });
  });

  group('backup schedule (B-05)', () {
    test('weekly is due after 7 days', () {
      final eightDaysAgo =
          AppTime.nowMs() - const Duration(days: 8).inMilliseconds;
      expect(AppTime.olderThanDays(eightDaysAgo, 7), isTrue);

      final yesterday = AppTime.nowMs() - const Duration(days: 1).inMilliseconds;
      expect(AppTime.olderThanDays(yesterday, 7), isFalse);
    });

    test('never backed up is always due', () {
      expect(AppTime.olderThanDays(null, 7), isTrue);
      expect(AppTime.inPreviousMonth(null), isTrue);
    });

    test('monthly looks at the calendar month', () {
      final lastMonth = DateTime.now().subtract(const Duration(days: 40));
      expect(
        AppTime.inPreviousMonth(lastMonth.toUtc().millisecondsSinceEpoch),
        isTrue,
      );
      expect(AppTime.inPreviousMonth(AppTime.nowMs()), isFalse);
    });
  });

  group('time formatting (P-09)', () {
    test('iso output is UTC with a Z suffix', () {
      final ms = DateTime.utc(2026, 8, 23, 10, 20).millisecondsSinceEpoch;
      expect(AppTime.toIso(ms), '2026-08-23T10:20:00Z');
    });

    test('iso parses back to the same instant', () {
      final ms = DateTime.utc(2026, 8, 23, 10, 20).millisecondsSinceEpoch;
      expect(AppTime.parseIso(AppTime.toIso(ms)), ms);
    });

    test('file stamps contain no colons', () {
      expect(AppTime.fileStamp(AppTime.nowMs()), isNot(contains(':')));
    });

    test('null and junk parse to null', () {
      expect(AppTime.parseIso(null), isNull);
      expect(AppTime.parseIso('not a date'), isNull);
    });
  });

  group('content hash', () {
    test('is stable and differs on change', () {
      expect(ContentHash.of('abc'), ContentHash.of('abc'));
      expect(ContentHash.of('abc'), isNot(ContentHash.of('abd')));
    });

    test('field separation avoids collisions', () {
      expect(
        ContentHash.ofParts(['ab', 'c']),
        isNot(ContentHash.ofParts(['a', 'bc'])),
      );
    });
  });
}
