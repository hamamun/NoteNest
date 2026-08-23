import 'package:flutter/material.dart';

/// COL-02 palette with COL-06 dark-mode variants.
///
/// Every colour ships a light and a dark surface plus a matching foreground so
/// text stays readable in both themes. Picking dark variants by hand (rather
/// than mechanically darkening the pastels) keeps the cards from turning muddy.
class NoteColor {
  const NoteColor({
    required this.key,
    required this.label,
    required this.light,
    required this.dark,
  });

  final String key;
  final String label;
  final Color light;
  final Color dark;

  Color surface(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Foreground guaranteed to contrast with [surface].
  Color foreground(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFFECEFF1) : const Color(0xFF202124);

  bool get isDefault => key == 'default';

  static const NoteColor defaultColor = NoteColor(
    key: 'default',
    label: 'Default',
    light: Color(0xFFFFFFFF),
    dark: Color(0xFF2A2D31),
  );

  static const List<NoteColor> palette = <NoteColor>[
    defaultColor,
    NoteColor(key: 'red', label: 'Red', light: Color(0xFFFAAFA8), dark: Color(0xFF5C2B29)),
    NoteColor(key: 'orange', label: 'Orange', light: Color(0xFFFFCC80), dark: Color(0xFF614A19)),
    NoteColor(key: 'yellow', label: 'Yellow', light: Color(0xFFFFF8B8), dark: Color(0xFF635D19)),
    NoteColor(key: 'green', label: 'Green', light: Color(0xFFCCFF90), dark: Color(0xFF345920)),
    NoteColor(key: 'teal', label: 'Teal', light: Color(0xFFA7FFEB), dark: Color(0xFF16504B)),
    NoteColor(key: 'blue', label: 'Blue', light: Color(0xFFCBF0F8), dark: Color(0xFF2D555E)),
    NoteColor(key: 'purple', label: 'Purple', light: Color(0xFFD7AEFB), dark: Color(0xFF42275E)),
    NoteColor(key: 'pink', label: 'Pink', light: Color(0xFFFDCFE8), dark: Color(0xFF5B2245)),
    NoteColor(key: 'gray', label: 'Gray', light: Color(0xFFE8EAED), dark: Color(0xFF3C3F43)),
  ];

  static NoteColor byKey(String? key) => palette.firstWhere(
        (c) => c.key == key,
        orElse: () => defaultColor,
      );
}

/// U-23: Material 3 theming, light + dark.
class AppTheme {
  AppTheme._();

  static const Color _seed = Color(0xFF3B6EA5);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF17191C) : const Color(0xFFF7F8FA),
      visualDensity: VisualDensity.standard,
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark ? const Color(0x1FFFFFFF) : const Color(0x14000000),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: isDark ? const Color(0xFF17191C) : const Color(0xFFF7F8FA),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF24272B) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      // A-07: comfortable hit targets everywhere.
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

/// U-01: responsive breakpoints.
class Breakpoints {
  Breakpoints._();

  static const double compact = 600;
  static const double medium = 1024;

  static bool isCompact(double width) => width < compact;
  static bool isMedium(double width) => width >= compact && width <= medium;
  static bool isExpanded(double width) => width > medium;
}
