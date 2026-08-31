import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notenest/app/theme.dart';

/// THM-01/THM-02: the built-in palette, wallpaper-derived schemes, and the
/// true-black dark variant.
void main() {
  group('AppTheme true black (THM-02)', () {
    test('true black swaps the dark surfaces for pure black', () {
      final dark = AppTheme.dark();
      final black = AppTheme.dark(trueBlack: true);

      expect(dark.scaffoldBackgroundColor, isNot(Colors.black));
      expect(black.scaffoldBackgroundColor, Colors.black);
      expect(black.appBarTheme.backgroundColor, Colors.black);
    });

    test('true black never leaks into the light theme', () {
      final light = AppTheme.light();
      expect(light.scaffoldBackgroundColor, isNot(Colors.black));
      expect(light.colorScheme.brightness, Brightness.light);
    });
  });

  group('AppTheme.fromScheme (THM-01)', () {
    test('keeps the dynamic scheme and honours true black', () {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
      );
      final theme = AppTheme.fromScheme(scheme, trueBlack: true);

      expect(theme.colorScheme.primary, scheme.primary);
      expect(theme.scaffoldBackgroundColor, Colors.black);
    });

    test('a light dynamic scheme stays a normal light theme', () {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: Brightness.light,
      );
      final theme = AppTheme.fromScheme(scheme, trueBlack: true);

      // trueBlack is dark-only by definition.
      expect(theme.scaffoldBackgroundColor, isNot(Colors.black));
    });
  });
}
