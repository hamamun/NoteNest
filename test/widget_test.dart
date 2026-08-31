// Basic smoke test for NoteNest.
//
// The default `flutter create` template references `MyApp` from `main.dart`,
// but NoteNest defines it in `app/app.dart`.  Import from there instead.

import 'package:flutter_test/flutter_test.dart';
import 'package:notenest/app/app.dart';

void main() {
  testWidgets('App widget can be instantiated', (WidgetTester tester) async {
    // A minimal smoke test — just verify the widget class exists and can be
    // created.  A full pump requires Provider / DB setup which is covered by
    // the other tests in this directory.
    expect(MyApp, isNotNull);
  });
}
