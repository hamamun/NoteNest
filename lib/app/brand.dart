import 'package:flutter/material.dart';

/// The NoteNest "N" monogram. Used in the shell and About — the OS launcher
/// icon is a separate pipeline (`dart run flutter_launcher_icons`).
class AppBrandIcon extends StatelessWidget {
  const AppBrandIcon({super.key, this.size = 32});

  static const assetPath = 'assets/icon/app_icon_ui.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'NoteNest',
    );
  }
}
