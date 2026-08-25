import 'package:flutter_test/flutter_test.dart';
import 'package:notenest/core/time.dart';
import 'package:notenest/data/models/enums.dart';
import 'package:notenest/data/repositories/checklist_matcher.dart';
import 'package:notenest/features/sync/entry_file_codec.dart';

/// G-03/G-04: the sync file format must round-trip every synced field.
/// A field that silently stops round-tripping is a field that silently stops
/// syncing, which is very hard to notice in normal use.
void main() {
  EntryFile sample({
    EntryType type = EntryType.note,
    String title = 'Meeting note',
    String body = 'Body text here.',
    bool pinned = true,
    EntryLocation location = EntryLocation.active,
  }) {
    final now = DateTime.utc(2026, 8, 23, 10, 20).millisecondsSinceEpoch;
    return EntryFile(
      id: '01J9ZTESTID0000000000000AB',
      type: type,
      title: title,
      body: body,
      colorKey: 'yellow',
      isPinned: pinned,
      pinnedAt: pinned ? now : null,
      location: location,
      previousLocationBeforeTrash:
          location == EntryLocation.trash ? 'archive' : null,
      checkboxesVisibleInView: false,
      createdAt: now,
      updatedAt: now + 1000,
      contentUpdatedAt: now + 1000,
      metadataUpdatedAt: now + 500,
      archivedAt: location == EntryLocation.archive ? now : null,
      trashedAt: location == EntryLocation.trash ? now : null,
      imageIds: const ['img-1', 'img-2'],
    );
  }

  group('round trip (G-04)', () {
    test('every note field survives encode then decode', () {
      final original = sample();
      final decoded = EntryFile.decode(original.encode());

      expect(decoded, isNotNull);
      expect(decoded!.id, original.id);
      expect(decoded.type, original.type);
      expect(decoded.title, original.title);
      expect(decoded.body, original.body);
      expect(decoded.colorKey, 'yellow');
      expect(decoded.isPinned, isTrue);
      expect(decoded.pinnedAt, original.pinnedAt);
      expect(decoded.location, EntryLocation.active);
      expect(decoded.checkboxesVisibleInView, isFalse);
      expect(decoded.createdAt, original.createdAt);
      expect(decoded.updatedAt, original.updatedAt);
      expect(decoded.contentUpdatedAt, original.contentUpdatedAt);
      expect(decoded.metadataUpdatedAt, original.metadataUpdatedAt);
      expect(decoded.imageIds, ['img-1', 'img-2']);
    });

    test('archive state survives', () {
      final decoded =
          EntryFile.decode(sample(location: EntryLocation.archive).encode());
      expect(decoded!.location, EntryLocation.archive);
      expect(decoded.archivedAt, isNotNull);
    });

    test('trash state keeps where it came from (T-09)', () {
      final decoded =
          EntryFile.decode(sample(location: EntryLocation.trash).encode());
      expect(decoded!.location, EntryLocation.trash);
      expect(decoded.previousLocationBeforeTrash, 'archive');
    });

    test('checklists round trip through task syntax', () {
      final lines = [
        const ChecklistLine('Rice', false),
        const ChecklistLine('Milk', true),
      ];
      final encoded = sample(type: EntryType.checklist).encode(lines: lines);

      expect(encoded, contains('- [ ] Rice'));
      expect(encoded, contains('- [x] Milk'));

      final decoded = EntryFile.decode(encoded);
      expect(decoded!.lines, lines);
    });
  });

  group('never syncs device preferences (G-05)', () {
    test('front matter has no local-only fields', () {
      final encoded = sample().encode();
      expect(encoded, isNot(contains('last_viewed')));
      expect(encoded, isNot(contains('card_view')));
      expect(encoded, isNot(contains('font')));
      expect(encoded, isNot(contains('sort_mode')));
    });
  });

  group('awkward content', () {
    test('titles with colons and quotes survive', () {
      final now = AppTime.nowMs();
      final file = EntryFile(
        id: 'x',
        type: EntryType.note,
        title: 'Plan: buy "milk" — 3:30pm',
        body: 'body',
        colorKey: 'default',
        isPinned: false,
        pinnedAt: null,
        location: EntryLocation.active,
        previousLocationBeforeTrash: null,
        checkboxesVisibleInView: true,
        createdAt: now,
        updatedAt: now,
        contentUpdatedAt: now,
        metadataUpdatedAt: now,
        archivedAt: null,
        trashedAt: null,
        imageIds: const [],
      );
      final decoded = EntryFile.decode(file.encode());
      expect(decoded!.title, 'Plan: buy "milk" — 3:30pm');
    });

    test('a body containing --- does not break parsing', () {
      final now = AppTime.nowMs();
      final file = EntryFile(
        id: 'x',
        type: EntryType.note,
        title: 'T',
        body: 'before\n---\nafter',
        colorKey: 'default',
        isPinned: false,
        pinnedAt: null,
        location: EntryLocation.active,
        previousLocationBeforeTrash: null,
        checkboxesVisibleInView: true,
        createdAt: now,
        updatedAt: now,
        contentUpdatedAt: now,
        metadataUpdatedAt: now,
        archivedAt: null,
        trashedAt: null,
        imageIds: const [],
      );
      final decoded = EntryFile.decode(file.encode());
      expect(decoded!.body, 'before\n---\nafter');
    });

    test('unicode content survives', () {
      final now = AppTime.nowMs();
      final file = EntryFile(
        id: 'x',
        type: EntryType.note,
        title: 'কেনাকাটা',
        body: 'চা\nদুধ 🥛',
        colorKey: 'default',
        isPinned: false,
        pinnedAt: null,
        location: EntryLocation.active,
        previousLocationBeforeTrash: null,
        checkboxesVisibleInView: true,
        createdAt: now,
        updatedAt: now,
        contentUpdatedAt: now,
        metadataUpdatedAt: now,
        archivedAt: null,
        trashedAt: null,
        imageIds: const [],
      );
      final decoded = EntryFile.decode(file.encode());
      expect(decoded!.title, 'কেনাকাটা');
      expect(decoded.body, 'চা\nদুধ 🥛');
    });
  });

  group('hand-edited files degrade gracefully', () {
    test('a plain markdown file with no front matter still parses', () {
      final decoded = EntryFile.decode('Just some text', fallbackId: 'abc');
      expect(decoded!.id, 'abc');
      expect(decoded.body, 'Just some text');
      expect(decoded.type, EntryType.note);
    });

    test('a file with no id and no fallback is rejected', () {
      expect(EntryFile.decode('no front matter here'), isNull);
    });

    test('windows line endings are handled', () {
      final decoded = EntryFile.decode(
        '---\r\nid: abc\r\ntype: note\r\ntitle: Hi\r\n---\r\n\r\nBody',
      );
      expect(decoded!.title, 'Hi');
      expect(decoded.body, 'Body');
    });
  });

  test('path helper (G-01)', () {
    expect(EntryFile.pathFor('abc'), 'notes/abc.md');
  });
}
