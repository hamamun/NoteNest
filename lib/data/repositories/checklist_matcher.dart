import 'dart:collection';

/// M-01..M-08: checklist checked-state preservation, matched by LINE TEXT.
///
/// The user's rule, verbatim: "checklist check-state preservation will be
/// considered the text, not position. If text change, no check-state."
///
/// Consequences that fall out of that rule:
///   * moving a line keeps its checkmark   (reordering is safe)
///   * editing a line clears its checkmark (it is a different item now)
///   * duplicates are consumed in order of appearance
///
/// This algorithm is deliberately dependency-free and pure so it can be unit
/// tested exhaustively (see test/checklist_matcher_test.dart).
class ChecklistLine {
  const ChecklistLine(this.text, this.checked);

  final String text;
  final bool checked;

  @override
  bool operator ==(Object other) =>
      other is ChecklistLine && other.text == text && other.checked == checked;

  @override
  int get hashCode => Object.hash(text, checked);

  @override
  String toString() => '${checked ? "[x]" : "[ ]"} $text';
}

class ChecklistMatcher {
  ChecklistMatcher._();

  static final RegExp _whitespaceRun = RegExp(r'\s+');

  /// M-02: trim the ends, collapse internal whitespace runs to one space,
  /// and compare case-sensitively.
  ///
  /// Case sensitivity is intentional: changing "milk" to "Milk" is a
  /// deliberate edit by the user, so the checkmark should clear.
  static String normalize(String text) =>
      text.trim().replaceAll(_whitespaceRun, ' ');

  /// M-03: rebuild checklist lines from raw editor [body], carrying checked
  /// state over from [previous] wherever the normalized text still matches.
  static List<ChecklistLine> reconcile({
    required List<ChecklistLine> previous,
    required String body,
  }) {
    // Bucket the old checked flags by normalized text, preserving old order
    // so duplicates are consumed first-in-first-out (M-06).
    final pool = <String, Queue<bool>>{};
    for (final line in previous) {
      pool.putIfAbsent(normalize(line.text), Queue<bool>.new).add(line.checked);
    }

    final result = <ChecklistLine>[];
    for (final raw in splitLines(body)) {
      final key = normalize(raw);
      final queue = pool[key];
      final checked = (queue != null && queue.isNotEmpty) ? queue.removeFirst() : false;
      result.add(ChecklistLine(raw.trim(), checked));
    }
    return result;
  }

  /// N-09: only non-empty lines become checklist items.
  static List<String> splitLines(String body) => body
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .toList(growable: false);

  /// Renders lines back into the plain multiline editor text (N-08).
  static String toBody(List<ChecklistLine> lines) =>
      lines.map((line) => line.text).join('\n');

  /// CP-05: default Copy All format for checklists is plain lines with no
  /// checkbox marks.
  static String toPlainText(List<ChecklistLine> lines) =>
      lines.map((line) => line.text).join('\n');

  /// E-11: TXT export format uses ASCII marks.
  static String toTxtExport(List<ChecklistLine> lines) =>
      lines.map((l) => '${l.checked ? "[x]" : "[ ]"} ${l.text}').join('\n');

  /// G-03: GitHub sync body keeps Markdown task-list syntax so the file stays
  /// readable on github.com.
  static String toMarkdownTasks(List<ChecklistLine> lines) =>
      lines.map((l) => '- [${l.checked ? "x" : " "}] ${l.text}').join('\n');

  static final RegExp _taskLine = RegExp(r'^\s*[-*]\s+\[([ xX])\]\s?(.*)$');

  /// Parses a synced checklist body back into lines. Falls back to treating
  /// each non-empty line as an unchecked item when the file was hand-edited
  /// on github.com without task syntax.
  static List<ChecklistLine> parseMarkdownTasks(String body) {
    final lines = <ChecklistLine>[];
    for (final raw in body.split('\n')) {
      if (raw.trim().isEmpty) continue;
      final match = _taskLine.firstMatch(raw);
      if (match != null) {
        final checked = match.group(1)!.toLowerCase() == 'x';
        lines.add(ChecklistLine(match.group(2)!.trim(), checked));
      } else {
        lines.add(ChecklistLine(raw.trim(), false));
      }
    }
    return lines;
  }

  /// U-14: the first few lines shown on a card, plus a "+N more" counter.
  static List<ChecklistLine> preview(List<ChecklistLine> lines, int max) =>
      lines.length <= max ? lines : lines.sublist(0, max);
}
