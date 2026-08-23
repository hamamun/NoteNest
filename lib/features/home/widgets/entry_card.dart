import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/icons.dart';
import '../../../app/theme.dart';
import '../../../core/time.dart';
import '../../../data/models/enums.dart';
import '../../../data/repositories/entry_repository.dart';

/// U-14: one note or list on the home/archive/trash grid.
///
/// The same widget serves all three card view modes (U-11); only padding,
/// preview length and image treatment change.
class EntryCard extends StatefulWidget {
  const EntryCard({
    super.key,
    required this.bundle,
    required this.viewMode,
    required this.onTap,
    required this.onLongPress,
    required this.selected,
    required this.selectionMode,
    required this.workspace,
    this.onPin,
    this.onColor,
    this.onArchive,
    this.onTrash,
    this.onRestore,
    this.onDeleteForever,
    this.onExport,
  });

  final EntryBundle bundle;
  final CardViewMode viewMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selected;
  final bool selectionMode;
  final Workspace workspace;

  final VoidCallback? onPin;
  final VoidCallback? onColor;
  final VoidCallback? onArchive;
  final VoidCallback? onTrash;
  final VoidCallback? onRestore;
  final VoidCallback? onDeleteForever;
  final VoidCallback? onExport;

  @override
  State<EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<EntryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final color = NoteColor.byKey(widget.bundle.entry.colorKey);
    final surface = color.isDefault
        ? theme.colorScheme.surface
        : color.surface(brightness);
    final foreground = color.isDefault
        ? theme.colorScheme.onSurface
        : color.foreground(brightness);

    final compact = widget.viewMode == CardViewMode.compact;
    final isList = widget.viewMode == CardViewMode.list;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        selected: widget.selected,
        label: widget.bundle.entry.title.isEmpty
            ? 'Untitled ${widget.bundle.isChecklist ? "list" : "note"}'
            : widget.bundle.entry.title,
        child: Material(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant.withOpacity(0.5),
                  width: widget.selected ? 2 : 1,
                ),
              ),
              padding: EdgeInsets.all(compact ? 10 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.bundle.images.isNotEmpty && !compact)
                    _thumbnail(isList),
                  _header(foreground, compact),
                  _body(foreground, compact),
                  if (widget.bundle.tags.isNotEmpty && !compact)
                    _tags(theme, foreground),
                  if (!compact) _footer(theme, foreground),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbnail(bool isList) {
    final file = File(widget.bundle.images.first.localPath);
    if (!file.existsSync()) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.file(
          file,
          height: isList ? 130 : 110,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _header(Color foreground, bool compact) {
    final title = widget.bundle.entry.title.trim();
    if (title.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: compact ? 13 : 15,
                color: foreground,
              ),
            ),
          ),
          if (widget.bundle.entry.isPinned)
            Icon(AppIcons.pin, size: 15, color: foreground.withOpacity(0.7)),
        ],
      ),
    );
  }

  Widget _body(Color foreground, bool compact) {
    final maxLines = compact ? 2 : (widget.viewMode == CardViewMode.list ? 5 : 8);

    // U-14: checklists preview as checkbox rows with a "+N more" counter.
    if (widget.bundle.isChecklist) {
      final lines = widget.bundle.lines;
      if (lines.isEmpty) {
        return Text(
          'Empty list',
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            color: foreground.withOpacity(0.55),
            fontStyle: FontStyle.italic,
          ),
        );
      }

      final shown = lines.take(maxLines).toList();
      final remaining = lines.length - shown.length;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    line.checked
                        ? Icons.check_box_outlined
                        : Icons.check_box_outline_blank,
                    size: compact ? 13 : 15,
                    color: foreground.withOpacity(0.7),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      line.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        color: foreground.withOpacity(line.checked ? 0.5 : 0.85),
                        decoration: line.checked
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (remaining > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '+ $remaining more',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: foreground.withOpacity(0.6),
                ),
              ),
            ),
        ],
      );
    }

    final body = widget.bundle.entry.body.trim();
    if (body.isEmpty) {
      if (widget.bundle.entry.title.trim().isEmpty) {
        return Text(
          'Empty note',
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            color: foreground.withOpacity(0.55),
            fontStyle: FontStyle.italic,
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return Text(
      body,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: compact ? 12 : 13,
        height: 1.35,
        color: foreground.withOpacity(0.85),
      ),
    );
  }

  Widget _tags(ThemeData theme, Color foreground) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: widget.bundle.tags
            .take(3)
            .map(
              (tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: foreground.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tag.name,
                  style: TextStyle(fontSize: 10.5, color: foreground),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  /// U-05: hover actions on desktop, quiet metadata otherwise.
  Widget _footer(ThemeData theme, Color foreground) {
    final showActions = _hovered && !widget.selectionMode;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 30,
        child: showActions ? _hoverActions(foreground) : _metaLine(foreground),
      ),
    );
  }

  Widget _metaLine(Color foreground) {
    final conflict = widget.bundle.entry.syncStatus == 'conflict_review';
    return Row(
      children: [
        if (conflict) ...[
          Icon(AppIcons.conflict, size: 13, color: foreground.withOpacity(0.8)),
          const SizedBox(width: 4),
          Text(
            'Conflict copy',
            style: TextStyle(fontSize: 11, color: foreground.withOpacity(0.8)),
          ),
          const Spacer(),
        ],
        if (!conflict) const Spacer(),
        Text(
          AppTime.relative(widget.bundle.entry.updatedAt),
          style: TextStyle(fontSize: 11, color: foreground.withOpacity(0.55)),
        ),
      ],
    );
  }

  Widget _hoverActions(Color foreground) {
    final inTrash = widget.workspace == Workspace.trash;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (!inTrash) ...[
            _miniAction(
              AppIcons.pinOutline,
              widget.bundle.entry.isPinned ? 'Unpin' : 'Pin',
              widget.onPin,
              foreground,
            ),
            _miniAction(AppIcons.color, 'Change colour', widget.onColor, foreground),
            _miniAction(
              widget.workspace == Workspace.archive
                  ? AppIcons.unarchive
                  : AppIcons.archive,
              widget.workspace == Workspace.archive ? 'Unarchive' : 'Archive',
              widget.workspace == Workspace.archive
                  ? widget.onRestore
                  : widget.onArchive,
              foreground,
            ),
            _miniAction(AppIcons.export, 'Export', widget.onExport, foreground),
            _miniAction(AppIcons.trash, 'Move to trash', widget.onTrash, foreground),
          ] else ...[
            _miniAction(AppIcons.restore, 'Restore', widget.onRestore, foreground),
            _miniAction(
              AppIcons.deleteForever,
              'Delete forever',
              widget.onDeleteForever,
              foreground,
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniAction(
    IconData icon,
    String label,
    VoidCallback? onPressed,
    Color foreground,
  ) {
    // A-03: even these small hover controls keep tooltip + semantics.
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 17, color: foreground.withOpacity(0.75)),
          ),
        ),
      ),
    );
  }
}
