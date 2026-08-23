import 'package:flutter_test/flutter_test.dart';
import 'package:notenest/data/repositories/checklist_matcher.dart';

/// M-08: exhaustive tests for the text-based checked-state rule.
/// These mirror QA-02, QA-03 and QA-04 from BUILD_CHECKLIST.md.
void main() {
  List<ChecklistLine> lines(List<(String, bool)> raw) =>
      raw.map((e) => ChecklistLine(e.$1, e.$2)).toList();

  group('normalize (M-02)', () {
    test('trims the ends', () {
      expect(ChecklistMatcher.normalize('   Milk   '), 'Milk');
    });

    test('collapses internal whitespace runs', () {
      expect(ChecklistMatcher.normalize('Whole    Milk'), 'Whole Milk');
      expect(ChecklistMatcher.normalize('Whole\tMilk'), 'Whole Milk');
    });

    test('is case sensitive', () {
      expect(
        ChecklistMatcher.normalize('milk') == ChecklistMatcher.normalize('Milk'),
        isFalse,
      );
    });
  });

  group('reorder keeps checked state (M-04, QA-02)', () {
    test('moving a line carries its checkmark', () {
      final result = ChecklistMatcher.reconcile(
        previous: lines([('Milk', true), ('Rice', false), ('Tea', false)]),
        body: 'Rice\nMilk\nTea',
      );
      expect(result, lines([('Rice', false), ('Milk', true), ('Tea', false)]));
    });

    test('full reversal keeps every state', () {
      final result = ChecklistMatcher.reconcile(
        previous: lines([('A', true), ('B', false), ('C', true)]),
        body: 'C\nB\nA',
      );
      expect(result, lines([('C', true), ('B', false), ('A', true)]));
    });
  });

  group('text change clears checked state (M-05, QA-03)', () {
    test('edited line becomes unchecked', () {
      final result = ChecklistMatcher.reconcile(
        previous: lines([('Milk', true)]),
        body: 'Milk 2L',
      );
      expect(result, lines([('Milk 2L', false)]));
    });

    test('editing one line does not disturb the others', () {
      final result = ChecklistMatcher.reconcile(
        previous: lines([('Milk', true), ('Tea', true)]),
        body: 'Milk 2L\nTea',
      );
      expect(result, lines([('Milk 2L', false), ('Tea', true)]));
    });

    test('case change clears the checkmark', () {
      final result = ChecklistMatcher.reconcile(
        previous: lines([('Milk', true)]),
        body: 'milk',
      );
      expect(result, lines([('milk', false)]));
    });

    test('pure whitespace change keeps the checkmark', () {
      final result = ChecklistMatcher.reconcile(
        previous: lines([('Whole  Milk', true)]),
        body: '  Whole Milk  ',
      );
      expect(result, lines([('Whole Milk', true)]));
    });
  });

  group('duplicates (M-06, QA-04)', () {
    test('same count matches in order of appearance', () {
      final result = ChecklistMatcher.reconcile(
        previous: lines([('Milk', true), ('Milk', false)]),
        body: 'Milk\nMilk',
      );
      expect(result, lines([('Milk', true), ('Milk', false)]));
    });

    test('shrinking duplicates keeps the first available match', () {
      final result = ChecklistMatcher.reconcile(
        previous: lines([('Milk', true), ('Milk', false)]),
        body: 'Milk',
      );
      expect(result, lines([('Milk', true)]));
    });

    test('growing duplicates leaves the extra copy unchecked', () {
      final result = ChecklistMatcher.reconcile(
        previous: lines([('Milk', true)]),
        body: 'Milk\nMilk',
      );
      expect(result, lines([('Milk', true), ('Milk', false)]));
    });

    test('old order decides which duplicate wins', () {
      final result = ChecklistMatcher.reconcile(
        previous: lines([('Milk', false), ('Milk', true)]),
        body: 'Milk',
      );
      expect(result, lines([('Milk', false)]));
    });
  });

  group('line splitting (N-09)', () {
    test('empty lines are dropped', () {
      final result = ChecklistMatcher.reconcile(
        previous: lines([('A', true), ('B', true)]),
        body: 'A\n\n\n   \nB',
      );
      expect(result, lines([('A', true), ('B', true)]));
    });

    test('an empty body produces no items', () {
      final result = ChecklistMatcher.reconcile(
        previous: lines([('A', true)]),
        body: '   \n  \n',
      );
      expect(result, isEmpty);
    });

    test('all-new content is entirely unchecked', () {
      final result = ChecklistMatcher.reconcile(
        previous: lines([('A', true), ('B', true)]),
        body: 'X\nY',
      );
      expect(result, lines([('X', false), ('Y', false)]));
    });
  });

  group('unicode', () {
    test('non-latin text matches', () {
      final result = ChecklistMatcher.reconcile(
        previous: lines([('চা', true)]),
        body: 'চা',
      );
      expect(result, lines([('চা', true)]));
    });

    test('emoji are preserved', () {
      final result = ChecklistMatcher.reconcile(
        previous: lines([('Milk 🥛', true)]),
        body: 'Milk 🥛',
      );
      expect(result, lines([('Milk 🥛', true)]));
    });
  });

  group('markdown round trip (G-03)', () {
    test('task syntax survives a round trip', () {
      final original = lines([('Rice', false), ('Milk', true), ('Tea', false)]);
      final markdown = ChecklistMatcher.toMarkdownTasks(original);
      expect(markdown, '- [ ] Rice\n- [x] Milk\n- [ ] Tea');
      expect(ChecklistMatcher.parseMarkdownTasks(markdown), original);
    });

    test('hand-edited plain lines degrade to unchecked items', () {
      final parsed = ChecklistMatcher.parseMarkdownTasks('Rice\nMilk');
      expect(parsed, lines([('Rice', false), ('Milk', false)]));
    });

    test('uppercase X is accepted', () {
      expect(
        ChecklistMatcher.parseMarkdownTasks('- [X] Milk'),
        lines([('Milk', true)]),
      );
    });
  });

  group('export formats', () {
    final sample = lines([('Rice', false), ('Milk', true)]);

    test('plain copy has no marks (CP-05)', () {
      expect(ChecklistMatcher.toPlainText(sample), 'Rice\nMilk');
    });

    test('txt export uses ascii marks (E-11)', () {
      expect(ChecklistMatcher.toTxtExport(sample), '[ ] Rice\n[x] Milk');
    });
  });
}
