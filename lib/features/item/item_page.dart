import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app/color_picker.dart';
import '../../app/icons.dart';
import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/time.dart';
import '../../data/db/database.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/checklist_matcher.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/image_store.dart';
import '../../data/repositories/settings_repository.dart';
import '../export/export_dialog.dart';
import 'widgets/image_strip.dart';
import 'widgets/linkified_text.dart';

/// U-17..U-20: the open item screen.
///
/// N-04: a saved item always opens in View Mode. Edit Mode is one tap away.
class ItemPage extends StatefulWidget {
  const ItemPage({
    super.key,
    required this.entryId,
    this.startInEditMode = false,
  });

  final String entryId;
  final bool startInEditMode;

  @override
  State<ItemPage> createState() => _ItemPageState();
}

class _ItemPageState extends State<ItemPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final FocusNode _bodyFocus = FocusNode();

  late bool _editing = widget.startInEditMode;
  Timer? _autosave;
  bool _controllersPrimed = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    // S-09: local-only, never bumps updated_at.
    unawaited(context.read<Services>().entries.markViewed(widget.entryId));

    _titleController.addListener(_scheduleAutosave);
    _bodyController.addListener(_scheduleAutosave);
  }

  @override
  void dispose() {
    _autosave?.cancel();
    // N-07: never lose the last keystrokes on the way out.
    unawaited(_saveNow());
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  /// N-07: debounce 800 ms, plus save on mode switch and on leaving.
  void _scheduleAutosave() {
    if (!_editing) return;
    _dirty = true;
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 800), _saveNow);
  }

  Future<void> _saveNow() async {
    if (!_dirty) return;
    _dirty = false;
    await context.read<Services>().entries.saveContent(
          id: widget.entryId,
          title: _titleController.text,
          body: _bodyController.text,
        );
  }

  Future<void> _setEditing(bool editing) async {
    if (!editing) await _saveNow();
    setState(() => _editing = editing);
    if (editing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bodyFocus.requestFocus());
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final settings = context.watch<SettingsRepository>();
    final isDesktop = Breakpoints.isExpanded(MediaQuery.sizeOf(context).width);

    return StreamBuilder<EntryBundle?>(
      stream: services.entries.watchEntry(widget.entryId),
      builder: (context, snapshot) {
        final bundle = snapshot.data;
        if (bundle == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Prime the controllers once, then let the user own them.
        if (!_controllersPrimed) {
          _titleController.text = bundle.entry.title;
          _bodyController.text = bundle.entry.body;
          _controllersPrimed = true;
        }

        final color = NoteColor.byKey(bundle.entry.colorKey);
        final brightness = Theme.of(context).brightness;
        final background = color.isDefault
            ? Theme.of(context).scaffoldBackgroundColor
            : color.surface(brightness);

        return Scaffold(
          backgroundColor: background,
          appBar: _appBar(context, bundle, isDesktop, background),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
                  children: [
                    _title(bundle),
                    const SizedBox(height: 10),
                    ImageStrip(
                      images: bundle.images,
                      editing: _editing,
                      onDelete: (image) => services.entries.deleteImage(image.id),
                    ),
                    if (bundle.tags.isNotEmpty && !_editing) _tagRow(bundle),
                    _content(context, bundle, settings),
                    const SizedBox(height: 24),
                    _metaFooter(bundle),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // App bar
  // ---------------------------------------------------------------------

  PreferredSizeWidget _appBar(
    BuildContext context,
    EntryBundle bundle,
    bool isDesktop,
    Color background,
  ) {
    final services = context.read<Services>();

    return AppBar(
      backgroundColor: background,
      leading: AppIconButton(
        icon: AppIcons.back,
        label: 'Back',
        onPressed: () async {
          await _saveNow();
          if (mounted) Navigator.of(context).pop();
        },
      ),
      actions: [
        AppIconButton(
          icon: bundle.entry.isPinned ? AppIcons.pin : AppIcons.pinOutline,
          label: bundle.entry.isPinned ? 'Unpin' : 'Pin',
          selected: bundle.entry.isPinned,
          onPressed: () => services.entries.togglePinned(bundle.entry.id),
        ),

        // K-01/K-09: checkbox visibility toggle — checklists, View Mode only.
        if (bundle.isChecklist && !_editing)
          AppIconButton(
            icon: bundle.entry.checkboxesVisibleInView
                ? AppIcons.checkboxesOn
                : AppIcons.checkboxesOff,
            label: bundle.entry.checkboxesVisibleInView
                ? 'Hide checkboxes'
                : 'Show checkboxes',
            selected: bundle.entry.checkboxesVisibleInView,
            onPressed: () => services.entries.setCheckboxesVisible(
              bundle.entry.id,
              !bundle.entry.checkboxesVisibleInView,
            ),
          ),

        // CP-03: Copy All, View Mode only.
        if (!_editing)
          AppIconButton(
            icon: AppIcons.copyAll,
            label: 'Copy all',
            onPressed: () => _copyAll(context, bundle),
          ),

        if (isDesktop) ...[
          AppIconButton(
            icon: AppIcons.color,
            label: 'Change colour',
            onPressed: () => _pickColor(context, bundle, isDesktop),
          ),
          if (_editing)
            AppIconButton(
              icon: AppIcons.image,
              label: 'Insert image',
              onPressed: () => _insertImage(context, bundle),
            ),
        ],

        // U-19: the View/Edit toggle.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _editing
              ? FilledButton.tonalIcon(
                  onPressed: () => _setEditing(false),
                  icon: const Icon(AppIcons.done, size: 18),
                  label: const Text('Done'),
                )
              : FilledButton.tonalIcon(
                  onPressed: () => _setEditing(true),
                  icon: const Icon(AppIcons.edit, size: 18),
                  label: const Text('Edit'),
                ),
        ),

        // U-20: everything else lives here.
        PopupMenuButton<String>(
          icon: const Icon(AppIcons.more),
          tooltip: 'More actions',
          onSelected: (value) => _onMenu(context, value, bundle, isDesktop),
          itemBuilder: (menuContext) {
            final location = bundle.location;
            return [
              if (!isDesktop)
                const PopupMenuItem(value: 'color', child: Text('Change colour')),
              if (!isDesktop && _editing)
                const PopupMenuItem(value: 'image', child: Text('Insert image')),
              const PopupMenuItem(value: 'tags', child: Text('Tags')),
              const PopupMenuItem(value: 'export', child: Text('Export')),
              const PopupMenuItem(value: 'history', child: Text('History')),
              const PopupMenuDivider(),
              if (location == EntryLocation.active)
                const PopupMenuItem(value: 'archive', child: Text('Archive')),
              if (location == EntryLocation.archive)
                const PopupMenuItem(value: 'unarchive', child: Text('Unarchive')),
              if (location != EntryLocation.trash)
                const PopupMenuItem(value: 'trash', child: Text('Move to trash')),
              if (location == EntryLocation.trash) ...[
                const PopupMenuItem(value: 'restore', child: Text('Restore')),
                const PopupMenuItem(value: 'home', child: Text('Move to home')),
                const PopupMenuItem(value: 'archive', child: Text('Move to archive')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete forever'),
                ),
              ],
            ];
          },
        ),
      ],
    );
  }

  Future<void> _onMenu(
    BuildContext context,
    String value,
    EntryBundle bundle,
    bool isDesktop,
  ) async {
    final services = context.read<Services>();
    final id = bundle.entry.id;

    switch (value) {
      case 'color':
        await _pickColor(context, bundle, isDesktop);
      case 'image':
        await _insertImage(context, bundle);
      case 'tags':
        await _editTags(context, bundle);
      case 'export':
        await ExportDialog.show(context, [bundle]);
      case 'history':
        await _showHistory(context, bundle);
      case 'archive':
        await services.entries.archive(id);
        if (mounted) Navigator.of(context).pop();
      case 'unarchive':
        await services.entries.restoreFromArchive(id);
        if (mounted) Navigator.of(context).pop();
      case 'trash':
        await services.entries.moveToTrash(id);
        if (mounted) Navigator.of(context).pop();
      case 'restore':
        await services.entries.restoreFromTrash(id);
        if (mounted) Navigator.of(context).pop();
      case 'home':
        await services.entries.moveToHome(id);
        if (mounted) Navigator.of(context).pop();
      case 'delete':
        final confirmed = await confirmDestructive(
          context,
          title: 'Delete forever?',
          message: 'This item will be permanently deleted from this device '
              'and from every synced device. This cannot be undone.',
          confirmLabel: 'Delete forever',
        );
        if (confirmed) {
          await services.entries.deleteForever(id);
          if (mounted) Navigator.of(context).pop();
        }
    }
  }

  // ---------------------------------------------------------------------
  // Content
  // ---------------------------------------------------------------------

  Widget _title(EntryBundle bundle) {
    if (_editing) {
      return TextField(
        controller: _titleController,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        decoration: const InputDecoration(
          hintText: 'Title',
          filled: false,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
      );
    }

    final title = bundle.entry.title.trim();
    return SelectableText(
      title.isEmpty ? 'Untitled' : title,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: title.isEmpty
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : null,
      ),
    );
  }

  Widget _content(
    BuildContext context,
    EntryBundle bundle,
    SettingsRepository settings,
  ) {
    // SET-01/SET-02: only the content scales, never the chrome.
    final scale = settings.contentFontScale;
    final baseSize = 16.0 * scale;
    final contentStyle = TextStyle(fontSize: baseSize, height: 1.45);

    if (_editing) {
      return TextField(
        controller: _bodyController,
        focusNode: _bodyFocus,
        style: contentStyle,
        maxLines: null,
        minLines: 12,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          // N-08: a checklist in Edit Mode is just a multiline note.
          hintText: bundle.isChecklist
              ? 'One item per line'
              : 'Start writing...',
          filled: false,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      );
    }

    if (bundle.isChecklist) {
      return _checklistView(context, bundle, contentStyle, settings);
    }
    return _noteView(context, bundle, contentStyle, settings);
  }

  /// N-05: rendered Markdown, selectable, with the URL rule applied.
  Widget _noteView(
    BuildContext context,
    EntryBundle bundle,
    TextStyle style,
    SettingsRepository settings,
  ) {
    final body = bundle.entry.body;
    if (body.trim().isEmpty) {
      return Text(
        'This note is empty. Tap Edit to add something.',
        style: style.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    if (!settings.markdownPreview) {
      return LinkifiedText(
        text: body,
        clickable: settings.clickableUrls,
        style: style,
      );
    }

    return MarkdownBody(
      data: body,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: style,
        listBullet: style,
        h1: style.copyWith(fontSize: style.fontSize! * 1.6, fontWeight: FontWeight.bold),
        h2: style.copyWith(fontSize: style.fontSize! * 1.4, fontWeight: FontWeight.bold),
        h3: style.copyWith(fontSize: style.fontSize! * 1.2, fontWeight: FontWeight.bold),
        code: style.copyWith(
          fontFamily: 'monospace',
          fontSize: style.fontSize! * 0.9,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        a: style.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
      // SET-07/SET-08: taps only navigate when the setting is on.
      onTapLink: settings.clickableUrls
          ? (text, href, title) {
              if (href != null) LinkifiedText.openUrl(context, href);
            }
          : null,
    );
  }

  /// N-09/N-10/K-02: checkbox rows, or plain lines when the toggle is off.
  Widget _checklistView(
    BuildContext context,
    EntryBundle bundle,
    TextStyle style,
    SettingsRepository settings,
  ) {
    final lines = bundle.lines;
    if (lines.isEmpty) {
      return Text(
        'This list is empty. Tap Edit and put one item on each line.',
        style: style.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final services = context.read<Services>();
    final showBoxes = bundle.entry.checkboxesVisibleInView;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showBoxes)
                  // SET-11: the checkbox owns its own tap area, separate from
                  // the text, so tapping a link never toggles the item.
                  Semantics(
                    checked: lines[i].checked,
                    label: lines[i].text,
                    child: Checkbox(
                      value: lines[i].checked,
                      onChanged: (value) => services.entries.setLineChecked(
                        bundle.entry.id,
                        i,
                        value ?? false,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                    ),
                  )
                else
                  const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: showBoxes ? 12 : 4, bottom: 4),
                    child: LinkifiedText(
                      text: lines[i].text,
                      clickable: settings.clickableUrls,
                      style: style.copyWith(
                        decoration: showBoxes && lines[i].checked
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: showBoxes && lines[i].checked
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _tagRow(EntryBundle bundle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: bundle.tags
            .map((tag) => Chip(
                  label: Text(tag.name),
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(AppIcons.tag, size: 14),
                ))
            .toList(),
      ),
    );
  }

  Widget _metaFooter(EntryBundle bundle) {
    final theme = Theme.of(context);
    final checked = bundle.isChecklist
        ? '${bundle.checkedCount} of ${bundle.lines.length} done  ·  '
        : '';
    return Text(
      '$checked'
      'Edited ${AppTime.relative(bundle.entry.updatedAt)}',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  /// CP-03/CP-04/CP-05
  Future<void> _copyAll(BuildContext context, EntryBundle bundle) async {
    final body = bundle.isChecklist
        ? ChecklistMatcher.toPlainText(bundle.lines)
        : bundle.entry.body;

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.copyAll),
              title: const Text('Copy title and text'),
              onTap: () => Navigator.of(sheetContext).pop('both'),
            ),
            ListTile(
              leading: const Icon(AppIcons.copy),
              title: const Text('Copy text only'),
              onTap: () => Navigator.of(sheetContext).pop('body'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    final title = bundle.entry.title.trim();
    final text = choice == 'both' && title.isNotEmpty ? '$title\n\n$body' : body;
    await Clipboard.setData(ClipboardData(text: text));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard')),
      );
    }
  }

  Future<void> _pickColor(
    BuildContext context,
    EntryBundle bundle,
    bool isDesktop,
  ) async {
    final key = isDesktop
        ? await ColorPickerSheet.showPopover(
            context,
            currentKey: bundle.entry.colorKey,
          )
        : await ColorPickerSheet.showSheet(
            context,
            currentKey: bundle.entry.colorKey,
          );
    if (key == null || !context.mounted) return;
    await context.read<Services>().entries.setColor(bundle.entry.id, key);
  }

  /// IMG-10: image-only pickers on both platforms.
  Future<void> _insertImage(BuildContext context, EntryBundle bundle) async {
    final services = context.read<Services>();

    Uint8List? bytes;
    String? name;

    try {
      if (Theme.of(context).platform == TargetPlatform.android ||
          Theme.of(context).platform == TargetPlatform.iOS) {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 92,
        );
        if (picked == null) return;
        bytes = await picked.readAsBytes();
        name = picked.name;
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;
        bytes = result.files.first.bytes;
        name = result.files.first.name;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the picker: $e')),
        );
      }
      return;
    }

    if (bytes == null || name == null) return;

    // IMG-02: validate again after picking — the filter is not enough.
    final validation = services.images.validate(name, bytes);
    if (!validation.ok) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validation.error ?? 'Only images are allowed.')),
        );
      }
      return;
    }

    final stored = await services.images.store(originalName: name, bytes: bytes);
    if (stored == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That image could not be added.')),
        );
      }
      return;
    }

    await services.entries.addImageRecord(
      entryId: bundle.entry.id,
      id: stored.id,
      fileName: stored.fileName,
      localPath: stored.localPath,
      mimeType: stored.mimeType,
      sizeBytes: stored.sizeBytes,
      width: stored.width,
      height: stored.height,
    );
  }

  /// V2: tags.
  Future<void> _editTags(BuildContext context, EntryBundle bundle) async {
    final services = context.read<Services>();
    final controller = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (builderContext, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tags', style: Theme.of(builderContext).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  StreamBuilder<List<Tag>>(
                    stream: services.entries.watchTags(),
                    builder: (context, snapshot) {
                      final all = snapshot.data ?? const <Tag>[];
                      return FutureBuilder<List<Tag>>(
                        future: services.entries.tagsFor(bundle.entry.id),
                        builder: (context, mineSnapshot) {
                          final mine = (mineSnapshot.data ?? const <Tag>[])
                              .map((t) => t.id)
                              .toSet();
                          if (all.isEmpty) {
                            return const Text('No tags yet. Create one below.');
                          }
                          return Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: all.map((tag) {
                              final selected = mine.contains(tag.id);
                              return FilterChip(
                                label: Text(tag.name),
                                selected: selected,
                                onSelected: (value) async {
                                  if (value) {
                                    await services.entries
                                        .attachTag(bundle.entry.id, tag.id);
                                  } else {
                                    await services.entries
                                        .detachTag(bundle.entry.id, tag.id);
                                  }
                                  setSheetState(() {});
                                },
                              );
                            }).toList(),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: const InputDecoration(hintText: 'New tag'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          final name = controller.text.trim();
                          if (name.isEmpty) return;
                          final tag = await services.entries.createTag(name);
                          await services.entries
                              .attachTag(bundle.entry.id, tag.id);
                          controller.clear();
                          setSheetState(() {});
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// V3: local note history.
  Future<void> _showHistory(BuildContext context, EntryBundle bundle) async {
    final services = context.read<Services>();
    final revisions = await services.entries.revisionsFor(bundle.entry.id);

    if (!context.mounted) return;

    if (revisions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No earlier versions saved yet.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, controller) => ListView.builder(
          controller: controller,
          itemCount: revisions.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'History (${revisions.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              );
            }
            final revision = revisions[index - 1];
            return ListTile(
              leading: const Icon(AppIcons.history),
              title: Text(AppTime.full(revision.createdAt)),
              subtitle: Text(
                revision.body.replaceAll('\n', ' '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: TextButton(
                onPressed: () async {
                  await services.entries
                      .restoreRevision(bundle.entry.id, revision.id);
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  if (mounted) {
                    setState(() {
                      _controllersPrimed = false;
                    });
                  }
                },
                child: const Text('Restore'),
              ),
            );
          },
        ),
      ),
    );
  }
}
