import 'package:flutter/material.dart';

import 'theme.dart';

/// COL-05: desktop shows a popover, mobile shows a bottom sheet of circles.
class ColorPickerSheet {
  ColorPickerSheet._();

  /// Mobile / small screens.
  static Future<String?> showSheet(
    BuildContext context, {
    required String currentKey,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Colour',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: NoteColor.palette
                    .map(
                      (color) => _Swatch(
                        color: color,
                        selected: color.key == currentKey,
                        onTap: () => Navigator.of(sheetContext).pop(color.key),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Desktop popover anchored to the button that opened it.
  static Future<String?> showPopover(
    BuildContext context, {
    required String currentKey,
  }) async {
    final button = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) {
      return showSheet(context, currentKey: currentKey);
    }

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    return showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem<String>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: 210,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: NoteColor.palette
                    .map(
                      (color) => _Swatch(
                        color: color,
                        selected: color.key == currentKey,
                        onTap: () => Navigator.of(context).pop(color.key),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final NoteColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: color.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: '${color.label} colour',
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.surface(brightness),
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 2.5 : 1,
              ),
            ),
            child: color.isDefault
                ? Icon(
                    Icons.format_color_reset_outlined,
                    size: 17,
                    color: scheme.onSurfaceVariant,
                  )
                : selected
                    ? Icon(
                        Icons.check,
                        size: 18,
                        color: color.foreground(brightness),
                      )
                    : null,
          ),
        ),
      ),
    );
  }
}
