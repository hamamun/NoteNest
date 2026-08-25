import 'dart:async';
import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app/color_picker.dart';
import '../../app/icons.dart';
import '../../app/screen_awake.dart';
import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/time.dart';
import '../../data/db/database.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/checklist_matcher.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../state/app_state.dart';
import '../export/export_dialog.dart';
import '../lock/pin_lock_controller.dart';
import '../lock/pin_pad.dart';
import 'widgets/image_strip.dart';
import 'widgets/linkified_text.dart';
import 'widgets/simple_markdown.dart';

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
  bool _keepAwake = false;

  bool get _isMobile => !kIsWeb && Platform.isAndroid;

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
    unawaited(ScreenAwake.setEnabled(false));
    // N-07: never lose the last keystrokes on the way out.
    unawaited(_saveNow());
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  Future<void> _applyKeepAwake() async {
    await ScreenAwake.setEnabled(_keepAwake && !_editing && _isMobile);
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
    await _applyKeepAwake();
    if (editing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bodyFocus.requestFocus());
    }
  }

  Future<void> _toggleKeepAwake() async {
    setState(() => _keepAwake = !_keepAwake);
    await _applyKeepAwake();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _keepAwake
              ? 'Screen will stay on while you read'
              : 'Screen can sleep again',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
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

        final lock = context.watch<PinLockController>();
        final onHome = context.watch<AppState>().workspace == Workspace.home;
        if (onHome && lock.policy.hidesEntry(bundle.type)) {
          return Scaffold(
            backgroundColor: background,
            appBar: AppBar(
              backgroundColor: background,
              leading: AppIconButton(
                icon: AppIcons.back,
                label: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: PinUnlockView(
              lock: lock,
              title: 'Enter PIN',
              subtitle:
                  bundle.isChecklist ? 'Lists are locked' : 'Notes are locked',
            ),
          );
        }

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

        // Notes have room in the bar. Lists already have the checkbox
        // toggle, so keep-awake lives in ⋮ there to avoid overflow.
        if (_isMobile && !_editing && !bundle.isChecklist)
          AppIconButton(
            icon: _keepAwake ? AppIcons.keepAwake : AppIcons.keepAwakeOff,
            label: _keepAwake ? 'Allow screen to sleep' : 'Keep screen on',
            selected: _keepAwake,
            onPressed: _toggleKeepAwake,
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
      case 'awake':
        await _toggleKeepAwake();
      case 'color':
        await _pickColor(context, bundle, isDesktop);
      case 'image':
        await _insertImage(context, bundle);
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

    return SimpleMarkdown(
      data: body,
      baseStyle: style,
      clickableUrls: settings.clickableUrls,
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

    // `name` is provably non-null here (both picker branches return early when
    // it couldn't be set); only `bytes` can legitimately be null.
    if (bytes == null) return;

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
