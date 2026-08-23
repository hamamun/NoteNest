import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'linkified_text.dart';

/// A small, self-contained Markdown renderer.
///
/// Why not the `flutter_markdown` package? It was discontinued upstream, and
/// depending on an unmaintained package for a v2 nicety would tie NoteNest to
/// a narrow range of Flutter releases. Everything here is plain Flutter, so it
/// keeps working across SDK versions.
///
/// Supported, which is everything a notes app realistically needs:
///   # ## ###   headings
///   - * +      bullet lists
///   1.         numbered lists
///   > quote    block quotes
///   ```code``` fenced code blocks
///   ---        horizontal rule
///   **bold**  *italic*  `code`  [text](url)
///
/// Text stays selectable (CP-01/CP-02) and honours the clickable-URL setting
/// (SET-06..SET-08) and the content font scale (SET-01).
class SimpleMarkdown extends StatelessWidget {
  const SimpleMarkdown({
    super.key,
    required this.data,
    required this.baseStyle,
    required this.clickableUrls,
  });

  final String data;
  final TextStyle baseStyle;
  final bool clickableUrls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = <Widget>[];
    final lines = data.replaceAll('\r\n', '\n').split('\n');

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      // Fenced code block.
      if (trimmed.startsWith('```')) {
        final buffer = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          buffer.add(lines[i]);
          i++;
        }
        i++; // closing fence
        blocks.add(_codeBlock(theme, buffer.join('\n')));
        continue;
      }

      // Horizontal rule.
      if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed)) {
        blocks.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1),
        ));
        i++;
        continue;
      }

      // Heading.
      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      if (heading != null) {
        final level = heading.group(1)!.length;
        final scale = switch (level) { 1 => 1.6, 2 => 1.35, 3 => 1.18, _ => 1.05 };
        blocks.add(Padding(
          padding: EdgeInsets.only(top: blocks.isEmpty ? 0 : 12, bottom: 4),
          child: _inline(
            context,
            heading.group(2)!,
            baseStyle.copyWith(
              fontSize: baseStyle.fontSize! * scale,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ));
        i++;
        continue;
      }

      // Block quote.
      if (trimmed.startsWith('>')) {
        final buffer = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          buffer.add(lines[i].trim().replaceFirst(RegExp(r'^>\s?'), ''));
          i++;
        }
        blocks.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: theme.colorScheme.outlineVariant, width: 3),
            ),
          ),
          child: _inline(
            context,
            buffer.join('\n'),
            baseStyle.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ));
        continue;
      }

      // Bullet or numbered list item.
      final bullet = RegExp(r'^\s*[-*+]\s+(.*)$').firstMatch(line);
      final numbered = RegExp(r'^\s*(\d+)[.)]\s+(.*)$').firstMatch(line);
      if (bullet != null || numbered != null) {
        final marker = bullet != null ? '\u2022' : '${numbered!.group(1)}.';
        final content = bullet != null ? bullet.group(1)! : numbered!.group(2)!;
        final indent = (line.length - line.trimLeft().length) ~/ 2;

        blocks.add(Padding(
          padding: EdgeInsets.only(left: 4.0 + indent * 16, bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text(marker, style: baseStyle),
              ),
              Expanded(child: _inline(context, content, baseStyle)),
            ],
          ),
        ));
        i++;
        continue;
      }

      // Blank line.
      if (trimmed.isEmpty) {
        blocks.add(SizedBox(height: baseStyle.fontSize! * 0.6));
        i++;
        continue;
      }

      // Paragraph: gather consecutive plain lines.
      final buffer = <String>[];
      while (i < lines.length) {
        final l = lines[i];
        final t = l.trim();
        if (t.isEmpty ||
            t.startsWith('```') ||
            t.startsWith('>') ||
            RegExp(r'^#{1,6}\s').hasMatch(t) ||
            RegExp(r'^\s*[-*+]\s').hasMatch(l) ||
            RegExp(r'^\s*\d+[.)]\s').hasMatch(l)) {
          break;
        }
        buffer.add(l);
        i++;
      }
      blocks.add(Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: _inline(context, buffer.join('\n'), baseStyle),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  Widget _codeBlock(ThemeData theme, String code) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        code,
        style: baseStyle.copyWith(
          fontFamily: 'monospace',
          fontSize: baseStyle.fontSize! * 0.92,
        ),
      ),
    );
  }

  /// Renders inline spans: bold, italic, inline code and links.
  Widget _inline(BuildContext context, String text, TextStyle style) {
    final theme = Theme.of(context);
    final spans = <InlineSpan>[];

    // One pass over all inline markers, earliest match wins.
    final pattern = RegExp(
      r'(\*\*|__)(.+?)\1'          // bold
      r'|(\*|_)(.+?)\3'            // italic
      r'|`([^`]+)`'                // inline code
      r'|\[([^\]]+)\]\(([^)]+)\)', // link
      dotAll: true,
    );

    var index = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > index) {
        spans.addAll(_plainSpans(context, text.substring(index, match.start), style));
      }

      if (match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(2),
          style: style.copyWith(fontWeight: FontWeight.w700),
        ));
      } else if (match.group(4) != null) {
        spans.add(TextSpan(
          text: match.group(4),
          style: style.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (match.group(5) != null) {
        spans.add(TextSpan(
          text: match.group(5),
          style: style.copyWith(
            fontFamily: 'monospace',
            fontSize: style.fontSize! * 0.92,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ));
      } else if (match.group(6) != null) {
        final label = match.group(6)!;
        final href = match.group(7)!;
        spans.add(TextSpan(
          text: label,
          style: style.copyWith(
            color: theme.colorScheme.primary,
            decoration: clickableUrls ? TextDecoration.underline : null,
          ),
          recognizer: clickableUrls
              ? (TapGestureRecognizer()
                ..onTap = () => LinkifiedText.openUrl(context, href))
              : null,
        ));
      }
      index = match.end;
    }

    if (index < text.length) {
      spans.addAll(_plainSpans(context, text.substring(index), style));
    }

    return SelectableText.rich(
      TextSpan(style: style, children: spans),
    );
  }

  /// Plain text, with bare URLs linkified when the setting allows it.
  List<InlineSpan> _plainSpans(
    BuildContext context,
    String text,
    TextStyle style,
  ) {
    if (!clickableUrls || !LinkifiedText.urlPattern.hasMatch(text)) {
      return [TextSpan(text: text)];
    }

    final theme = Theme.of(context);
    final spans = <InlineSpan>[];
    var index = 0;

    for (final match in LinkifiedText.urlPattern.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      final raw = match.group(0)!;
      spans.add(TextSpan(
        text: raw,
        style: style.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => LinkifiedText.openUrl(context, raw),
      ));
      index = match.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index)));
    }
    return spans;
  }
}
