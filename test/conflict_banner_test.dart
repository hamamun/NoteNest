import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notenest/features/item/widgets/conflict_banner.dart';

/// X-09: the conflict panel is the only place NoteNest asks the user to finish
/// a conflict, so the three decisions it offers are pinned here.
void main() {
  Future<void> pumpBanner(
    WidgetTester tester, {
    String? originalTitle = 'Shopping list',
    VoidCallback? onKeepBoth,
    VoidCallback? onOpenOriginal,
    VoidCallback? onReplaceOriginal,
    VoidCallback? onDiscard,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConflictBanner(
            originalTitle: originalTitle,
            onKeepBoth: onKeepBoth ?? () {},
            onOpenOriginal: onOpenOriginal,
            onReplaceOriginal: onReplaceOriginal,
            onDiscard: onDiscard,
          ),
        ),
      ),
    );
  }

  testWidgets('names the original it was forked from', (tester) async {
    await pumpBanner(tester);

    expect(find.text('Conflict copy'), findsOneWidget);
    expect(find.textContaining('"Shopping list"'), findsOneWidget);
    expect(find.textContaining('nothing was overwritten'), findsOneWidget);
  });

  testWidgets('offers all three decisions when the original still exists',
      (tester) async {
    await pumpBanner(
      tester,
      onOpenOriginal: () {},
      onReplaceOriginal: () {},
      onDiscard: () {},
    );

    expect(find.text('Keep both'), findsOneWidget);
    expect(find.text('Replace original'), findsOneWidget);
    expect(find.text('Discard copy'), findsOneWidget);
    expect(find.text('Open original'), findsOneWidget);
  });

  testWidgets('drops the actions that need a missing original', (tester) async {
    await pumpBanner(tester, originalTitle: null, onDiscard: () {});

    expect(find.textContaining('only version left'), findsOneWidget);
    expect(find.text('Open original'), findsNothing);
    expect(find.text('Replace original'), findsNothing);
    expect(find.text('Keep both'), findsOneWidget);
    expect(find.text('Discard copy'), findsOneWidget);
  });

  testWidgets('the buttons run the callbacks they are given', (tester) async {
    var kept = 0;
    var replaced = 0;
    var discarded = 0;

    await pumpBanner(
      tester,
      onKeepBoth: () => kept++,
      onReplaceOriginal: () => replaced++,
      onDiscard: () => discarded++,
    );

    await tester.tap(find.text('Keep both'));
    await tester.tap(find.text('Replace original'));
    await tester.tap(find.text('Discard copy'));
    await tester.pump();

    expect(kept, 1);
    expect(replaced, 1);
    expect(discarded, 1);
  });
}
