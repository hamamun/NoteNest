import 'package:flutter/material.dart';

/// Version-proof colour helpers.
///
/// `Color.withOpacity()` was deprecated in Flutter 3.27 and removed later;
/// `Color.withValues()` does not exist before 3.27. Using either one directly
/// ties the whole app to a narrow band of Flutter releases.
///
/// [withAlpha] has been stable for the entire life of Flutter, so this
/// extension works everywhere.
extension ColorFade on Color {
  /// Returns this colour at [opacity] (0.0 transparent, 1.0 opaque).
  Color fade(double opacity) =>
      withAlpha((255 * opacity).round().clamp(0, 255));
}
