import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notenest/app/undo_snackbar.dart';

/// UND-02: every metadata action confirms with a snackbar whose Undo button
/// runs the revert.
void main() {
  testWidgets('the Undo action runs the revert callback', (tester) async {
    var undone = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showUndoSnackBar(
                  context,
                  message: 'Pinned',
                  onUndo: () async => undone += 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pump(); // SnackBar enters.
    expect(find.text('Pinned'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(undone, 1);
  });

  testWidgets('a new snackbar replaces the previous one', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: Column(
                children: [
                  FilledButton(
                    onPressed: () => showUndoSnackBar(
                      context,
                      message: 'Pinned',
                      onUndo: () async {},
                    ),
                  ),
                  FilledButton(
                    onPressed: () => showUndoSnackBar(
                      context,
                      message: 'Archived',
                      onUndo: () async {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(FilledButton).first);
    await tester.pump();
    await tester.tap(find.byType(FilledButton).last);
    await tester.pump();

    expect(find.text('Pinned'), findsNothing);
    expect(find.text('Archived'), findsOneWidget);
  });
}
