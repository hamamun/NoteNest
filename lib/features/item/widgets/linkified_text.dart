import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/logging.dart';

/// SET-06..SET-12: text with optional clickable URLs.
///
/// When the toggle is off the URL is still shown, still selectable and still
/// copyable — it simply does not navigate (SET-08). Text is always wrapped in
/// SelectableText so CP-01/CP-02 work in View Mode.
class LinkifiedText extends StatelessWidget {
  const LinkifiedText({
    super.key,
    required this.text,
    required this.clickable,
    this.style,
    this.textAlign,
  });

  final String text;
  final bool clickable;
  final TextStyle? style;
  final TextAlign? textAlign;

  /// Matches http/https URLs and bare www. hosts.
  ///
  /// Deliberately permissive, then tightened by [_trimTrailingPunctuation]:
  /// getting "see https://example.com." right matters more than a clever
  /// single-pass pattern.
  static final RegExp urlPattern = RegExp(
    r'(?:https?://|www\.)[^\s<>]+',
    caseSensitive: false,
  );

  /// Trailing punctuation almost always belongs to the sentence, not the URL.
  /// Closing brackets are only dropped when unbalanced, so
  /// `https://en.wikipedia.org/wiki/Foo_(bar)` survives intact.
  static String _trimTrailingPunctuation(String url) {
    var end = url.length;
    while (end > 0) {
      final char = url[end - 1];
      if ('.,;:!?"\''.contains(char)) {
        end--;
      } else if (char == ')' || char == ']' || char == '}') {
        final open = char == ')' ? '(' : (char == ']' ? '[' : '{');
        final candidate = url.substring(0, end);
        if (candidate.split(open).length > candidate.split(char).length) break;
        end--;
      } else {
        break;
      }
    }
    return url.substring(0, end);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = style ?? theme.textTheme.bodyMedium;

    if (!clickable || !urlPattern.hasMatch(text)) {
      // CP-01/CP-02: selectable even when links are disabled.
      return SelectableText(text, style: baseStyle, textAlign: textAlign);
    }

    final spans = <TextSpan>[];
    var index = 0;

    for (final match in urlPattern.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }

      final raw = match.group(0)!;
      final url = _trimTrailingPunctuation(raw);
      final tail = raw.substring(url.length);

      spans.add(
        TextSpan(
          text: url,
          style: baseStyle?.copyWith(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: theme.colorScheme.primary,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => openUrl(context, url),
        ),
      );
      if (tail.isNotEmpty) spans.add(TextSpan(text: tail));

      index = match.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index)));
    }

    return SelectableText.rich(
      TextSpan(style: baseStyle, children: spans),
      textAlign: textAlign,
    );
  }

  /// SET-12: http/https open directly; anything unusual asks first.
  static Future<void> openUrl(BuildContext context, String raw) async {
    var normalised = raw.trim();
    if (normalised.toLowerCase().startsWith('www.')) {
      normalised = 'https://$normalised';
    }

    final uri = Uri.tryParse(normalised);
    if (uri == null) return;

    const safeSchemes = {'http', 'https'};
    if (!safeSchemes.contains(uri.scheme.toLowerCase())) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Open this link?'),
          content: Text(
            'This link does not use http or https:\n\n$normalised\n\n'
            'Only continue if you trust it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Open'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $normalised')),
        );
      }
    } catch (e) {
      AppLog.warn('links', 'launch failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open that link.')),
        );
      }
    }
  }
}
