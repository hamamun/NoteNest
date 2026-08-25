import '../../core/time.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/checklist_matcher.dart';

/// G-03/G-04: the on-disk representation of one entry in the GitHub repo.
///
/// A NoteNest entry file is YAML front matter followed by the body. The
/// front matter must round-trip EVERY synced field — if a field is missing
/// here, that field silently stops syncing, which is the sneakiest class of
/// bug in the whole app.
///
/// Deliberately excluded (G-05): last_viewed_at_local, sort mode, card view
/// mode and font scale. Those are device preferences, not note data.
class EntryFile {
  const EntryFile({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.colorKey,
    required this.isPinned,
    required this.pinnedAt,
    required this.location,
    required this.previousLocationBeforeTrash,
    required this.checkboxesVisibleInView,
    required this.createdAt,
    required this.updatedAt,
    required this.contentUpdatedAt,
    required this.metadataUpdatedAt,
    required this.archivedAt,
    required this.trashedAt,
    required this.imageIds,
    this.encrypted = false,
    this.conflictOfId,
  });

  final String id;
  final EntryType type;
  final String title;
  final String body;
  final String colorKey;
  final bool isPinned;
  final int? pinnedAt;
  final EntryLocation location;
  final String? previousLocationBeforeTrash;
  final bool checkboxesVisibleInView;
  final int createdAt;
  final int updatedAt;
  final int contentUpdatedAt;
  final int metadataUpdatedAt;
  final int? archivedAt;
  final int? trashedAt;
  final List<String> imageIds;
  final bool encrypted;
  final String? conflictOfId;

  /// Serialises to the `.md` file body.
  ///
  /// For checklists the body is written as Markdown task syntax so the file
  /// remains readable and editable on github.com (G-03).
  String encode({List<ChecklistLine> lines = const []}) {
    final buffer = StringBuffer()..writeln('---');

    void field(String key, Object? value) {
      if (value == null) return;
      buffer.writeln('$key: ${_escape(value.toString())}');
    }

    field('id', id);
    field('type', type.value);
    field('title', title);
    field('color', colorKey);
    field('pinned', isPinned);
    if (pinnedAt != null) field('pinned_at', AppTime.toIso(pinnedAt!));
    field('location', location.value);
    if (previousLocationBeforeTrash != null) {
      field('previous_location', previousLocationBeforeTrash);
    }
    field('checkboxes_visible', checkboxesVisibleInView);
    field('created', AppTime.toIso(createdAt));
    field('updated', AppTime.toIso(updatedAt));
    field('content_updated', AppTime.toIso(contentUpdatedAt));
    field('metadata_updated', AppTime.toIso(metadataUpdatedAt));
    if (archivedAt != null) field('archived', AppTime.toIso(archivedAt!));
    if (trashedAt != null) field('trashed', AppTime.toIso(trashedAt!));
    field('deleted', false);
    if (encrypted) field('encrypted', true);
    if (conflictOfId != null) field('conflict_of', conflictOfId);

    if (imageIds.isNotEmpty) {
      buffer.writeln('images:');
      for (final image in imageIds) {
        buffer.writeln('  - $image');
      }
    }

    buffer.writeln('---');
    buffer.writeln();

    if (type.isChecklist && !encrypted) {
      buffer.write(ChecklistMatcher.toMarkdownTasks(lines));
    } else {
      buffer.write(body);
    }
    return buffer.toString();
  }

  static String _escape(String value) {
    if (value.isEmpty) return '""';
    final needsQuotes = value.contains(RegExp(r'''[:#\-\[\]{}"'\n]''')) ||
        value.trim() != value;
    if (!needsQuotes) return value;
    return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n')}"';
  }

  static String _unescape(String value) {
    var v = value.trim();
    if (v.length >= 2 &&
        ((v.startsWith('"') && v.endsWith('"')) ||
            (v.startsWith("'") && v.endsWith("'")))) {
      v = v.substring(1, v.length - 1);
      v = v.replaceAll(r'\n', '\n').replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
    }
    return v;
  }

  /// Parses a `.md` file coming back from GitHub.
  ///
  /// Written defensively: the user may hand-edit these files on github.com,
  /// so anything missing falls back to a sane default rather than throwing.
  static EntryFile? decode(String raw, {String? fallbackId}) {
    final text = raw.replaceAll('\r\n', '\n');
    final meta = <String, String>{};
    final images = <String>[];
    var body = text;

    if (text.startsWith('---')) {
      final end = text.indexOf('\n---', 3);
      if (end != -1) {
        final header = text.substring(3, end);
        body = text.substring(end + 4);
        if (body.startsWith('\n')) body = body.substring(1);
        if (body.startsWith('\n')) body = body.substring(1);

        String? listKey;
        for (final line in header.split('\n')) {
          if (line.trim().isEmpty) continue;

          final itemMatch = RegExp(r'^\s+-\s+(.*)$').firstMatch(line);
          if (itemMatch != null && listKey != null) {
            final value = _unescape(itemMatch.group(1)!);
            if (listKey == 'images') {
              images.add(value);
            }
            continue;
          }

          final colon = line.indexOf(':');
          if (colon == -1) continue;
          final key = line.substring(0, colon).trim();
          final value = line.substring(colon + 1).trim();
          if (value.isEmpty) {
            listKey = key;
          } else {
            listKey = null;
            meta[key] = _unescape(value);
          }
        }
      }
    }

    final id = meta['id'] ?? fallbackId;
    if (id == null || id.isEmpty) return null;

    final created = AppTime.parseIso(meta['created']) ?? AppTime.nowMs();
    final updated = AppTime.parseIso(meta['updated']) ?? created;

    return EntryFile(
      id: id,
      type: EntryType.parse(meta['type']),
      title: meta['title'] ?? '',
      body: body.trimRight(),
      colorKey: meta['color'] ?? 'default',
      isPinned: meta['pinned'] == 'true',
      pinnedAt: AppTime.parseIso(meta['pinned_at']),
      location: EntryLocation.parse(meta['location'] ?? 'active'),
      previousLocationBeforeTrash: meta['previous_location'],
      checkboxesVisibleInView: (meta['checkboxes_visible'] ?? 'true') == 'true',
      createdAt: created,
      updatedAt: updated,
      contentUpdatedAt: AppTime.parseIso(meta['content_updated']) ?? updated,
      metadataUpdatedAt: AppTime.parseIso(meta['metadata_updated']) ?? updated,
      archivedAt: AppTime.parseIso(meta['archived']),
      trashedAt: AppTime.parseIso(meta['trashed']),
      imageIds: images,
      encrypted: meta['encrypted'] == 'true',
      conflictOfId: meta['conflict_of'],
    );
  }

  /// Parsed checklist lines for a checklist entry.
  List<ChecklistLine> get lines =>
      type.isChecklist ? ChecklistMatcher.parseMarkdownTasks(body) : const [];

  /// The raw multiline editor text for a checklist (N-08).
  String get editorBody => type.isChecklist
      ? ChecklistMatcher.toBody(lines)
      : body;

  static String pathFor(String id) => 'notes/$id.md';
}
