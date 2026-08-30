import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

import '../../app/color_picker.dart';
import '../../app/icons.dart';
import '../../app/services.dart';
import '../../app/sync_button.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../state/app_state.dart';
import '../export/export_dialog.dart';
import '../item/item_page.dart';
import '../lock/pin_lock_controller.dart';
import '../lock/pin_pad.dart';
import '../sync/sync_controller.dart';
import 'create_flow.dart';
import 'widgets/empty_state.dart';
import 'widgets/entry_card.dart';

/// U-03/U-08: the main browsing screen for Home, Archive and Trash.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.isDesktop, this.onOpenDrawer});

  final bool isDesktop;

  /// Opens the outer scaffold's navigation drawer. Only the mobile shell
  /// provides this; the desktop shell shows a permanent rail instead.
  final VoidCallback? onOpenDrawer;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  /// F-02: caches the per-workspace count streams so the "All" chip does not
  /// re-query (and flicker) on every rebuild.
  final Map<Workspace, Stream<({int notes, int lists})>> _typeCountStreams =
      <Workspace, Stream<({int notes, int lists})>>{};

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// S-14: debounced search.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) context.read<AppState>().setQuery(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = context.watch<SettingsRepository>();
    final services = context.read<Services>();
    final lock = context.watch<PinLockController>();

    return Scaffold(
      appBar: state.selectionMode
          ? _selectionAppBar(context, state)
          : _normalAppBar(context, state, settings),
      body: Column(
        children: [
          _filterRow(context, state),
          if (state.workspace == Workspace.trash) _trashBanner(context),
          Expanded(
            child: StreamBuilder<List<EntryBundle>>(
              stream: services.entries.watchEntries(
                workspace: state.workspace,
                filter: state.filter,
                sort: settings.sortMode,
                query: state.query,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var bundles = snapshot.data ?? const <EntryBundle>[];
                final onHome = state.workspace == Workspace.home;
                if (onHome) {
                  if (lock.shouldHideNotes) {
                    bundles = bundles
                        .where((b) => b.isChecklist)
                        .toList(growable: false);
                  }
                  if (lock.shouldHideLists) {
                    bundles = bundles
                        .where((b) => !b.isChecklist)
                        .toList(growable: false);
                  }
                }

                if (onHome &&
                    state.filter == EntryFilter.all &&
                    lock.needsHomeGate) {
                  return PinUnlockView(
                    lock: lock,
                    title: 'Enter PIN',
                    subtitle: 'Notes and lists are locked',
                  );
                }
                if (onHome && lock.policy.needsNotesGate(state.filter)) {
                  return PinUnlockView(
                    lock: lock,
                    title: 'Enter PIN',
                    subtitle: 'Notes are locked',
                  );
                }
                if (onHome && lock.policy.needsListsGate(state.filter)) {
                  return PinUnlockView(
                    lock: lock,
                    title: 'Enter PIN',
                    subtitle: 'Lists are locked',
                  );
                }

                if (bundles.isEmpty) {
                  if (onHome &&
                      (lock.shouldHideNotes || lock.shouldHideLists) &&
                      state.query.trim().isEmpty) {
                    return EmptyState.locked(
                      notesHidden: lock.shouldHideNotes,
                      listsHidden: lock.shouldHideLists,
                    );
                  }
                  return EmptyState.forWorkspace(
                    state.workspace,
                    searching: state.query.trim().isNotEmpty,
                    filtered: state.filter != EntryFilter.all,
                    onCreate: state.workspace == Workspace.home
                        ? () => createAndOpen(context, EntryType.note)
                        : null,
                  );
                }

                return _cards(context, bundles, settings.cardViewMode, state);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // App bars
  // ---------------------------------------------------------------------

  PreferredSizeWidget _normalAppBar(
    BuildContext context,
    AppState state,
    SettingsRepository settings,
  ) {
    final sync = context.watch<SyncController>();

    return AppBar(
      leading: widget.onOpenDrawer == null
          ? null
          : AppIconButton(
              icon: AppIcons.menu,
              label: 'Open navigation menu',
              onPressed: widget.onOpenDrawer,
            ),
      automaticallyImplyLeading:
          widget.onOpenDrawer == null && !widget.isDesktop,
      titleSpacing: widget.isDesktop ? 20 : 16,
      title: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SizedBox(
          height: 44,
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search ${state.workspace.label.toLowerCase()}',
              prefixIcon: const Icon(AppIcons.search, size: 20),
              suffixIcon: state.query.isEmpty
                  ? null
                  : AppIconButton(
                      icon: AppIcons.clear,
                      label: 'Clear search',
                      iconSize: 18,
                      onPressed: () {
                        _searchController.clear();
                        context.read<AppState>().setQuery('');
                      },
                    ),
            ),
          ),
        ),
      ),
      actions: [
        // U-13: exactly one view icon on mobile.
        AppIconButton(
          icon: switch (settings.cardViewMode) {
            CardViewMode.grid => AppIcons.viewGrid,
            CardViewMode.list => AppIcons.viewList,
            CardViewMode.compact => AppIcons.viewCompact,
            CardViewMode.rows => AppIcons.viewRows,
          },
          label: 'View: ${settings.cardViewMode.label}',
          onPressed: () => _showViewOptions(context, settings),
        ),
        if (widget.isDesktop)
          AppIconButton(
            icon: AppIcons.sort,
            label: 'Sort: ${settings.sortMode.label}',
            onPressed: () => _showSortOptions(context, settings),
          ),
        if (!widget.isDesktop)
          SyncStatusButton(
            sync: sync,
            onPressed: sync.canSync ? () => _sync(context) : null,
          ),
        if (widget.isDesktop) ...[
          SyncStatusButton(
            sync: sync,
            onPressed: sync.canSync ? () => _sync(context) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton.icon(
              onPressed: () => showCreateOptions(context),
              icon: const Icon(AppIcons.newItem, size: 18),
              label: const Text('New'),
            ),
          ),
        ],
        if (!widget.isDesktop)
          PopupMenuButton<String>(
            icon: const Icon(AppIcons.more),
            tooltip: 'More actions',
            onSelected: (value) {
              switch (value) {
                case 'sort':
                  _showSortOptions(context, settings);
                case 'select':
                  _enterSelectionMode(context);
                case 'empty':
                  _emptyTrash(context);
              }
            },
            itemBuilder: (menuContext) => [
              const PopupMenuItem(value: 'sort', child: Text('Sort by')),
              const PopupMenuItem(value: 'select', child: Text('Select items')),
              if (state.workspace == Workspace.trash)
                const PopupMenuItem(value: 'empty', child: Text('Empty trash')),
            ],
          ),
      ],
    );
  }

  /// U-06/E-02/E-03: the selection toolbar.
  PreferredSizeWidget _selectionAppBar(BuildContext context, AppState state) {
    final inTrash = state.workspace == Workspace.trash;
    final inArchive = state.workspace == Workspace.archive;

    return AppBar(
      leading: AppIconButton(
        icon: AppIcons.clear,
        label: 'Cancel selection',
        onPressed: () => context.read<AppState>().clearSelection(),
      ),
      title: Text('${state.selectedCount} selected'),
      actions: [
        AppIconButton(
          icon: AppIcons.export,
          label: 'Export selected',
          onPressed: () => _exportSelected(context, state),
        ),
        if (inTrash) ...[
          AppIconButton(
            icon: AppIcons.restore,
            label: 'Restore selected',
            onPressed: () async {
              final services = context.read<Services>();
              await services.entries.restoreAll(state.selected);
              if (context.mounted) context.read<AppState>().clearSelection();
            },
          ),
          AppIconButton(
            icon: AppIcons.deleteForever,
            label: 'Delete selected forever',
            onPressed: () => _deleteSelectedForever(context, state),
          ),
        ] else if (inArchive) ...[
          AppIconButton(
            icon: AppIcons.color,
            label: 'Change colour',
            onPressed: () => _colorSelected(context, state),
          ),
          AppIconButton(
            icon: AppIcons.unarchive,
            label: 'Unarchive selected',
            onPressed: () async {
              final services = context.read<Services>();
              await services.entries.unarchiveAll(state.selected);
              if (context.mounted) context.read<AppState>().clearSelection();
            },
          ),
          AppIconButton(
            icon: AppIcons.trash,
            label: 'Move selected to trash',
            onPressed: () async {
              final services = context.read<Services>();
              await services.entries.trashAll(state.selected);
              if (context.mounted) context.read<AppState>().clearSelection();
            },
          ),
        ] else ...[
          AppIconButton(
            icon: AppIcons.color,
            label: 'Change colour',
            onPressed: () => _colorSelected(context, state),
          ),
          AppIconButton(
            icon: AppIcons.archive,
            label: 'Archive selected',
            onPressed: () async {
              final services = context.read<Services>();
              await services.entries.archiveAll(state.selected);
              if (context.mounted) context.read<AppState>().clearSelection();
            },
          ),
          AppIconButton(
            icon: AppIcons.trash,
            label: 'Move selected to trash',
            onPressed: () async {
              final services = context.read<Services>();
              await services.entries.trashAll(state.selected);
              if (context.mounted) context.read<AppState>().clearSelection();
            },
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Filters
  // ---------------------------------------------------------------------

  Widget? _lockAvatar(BuildContext context, EntryFilter filter) {
    if (context.read<AppState>().workspace != Workspace.home) return null;
    final lock = context.read<PinLockController>();
    final locked = switch (filter) {
      EntryFilter.all => lock.needsHomeGate,
      EntryFilter.notes => lock.shouldHideNotes,
      EntryFilter.lists => lock.shouldHideLists,
    };
    if (!locked) return null;
    return Icon(
      AppIcons.lock,
      size: 16,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  Widget _filterRow(BuildContext context, AppState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Row(
        children: [
          for (final filter in EntryFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: _lockAvatar(context, filter),
                label: filter == EntryFilter.all
                    ? _allChipLabel(context, state)
                    : Text(filter.label),
                selected: state.filter == filter,
                onSelected: (_) => context.read<AppState>().setFilter(filter),
                showCheckmark: false,
              ),
            ),
          const Spacer(),
          if (widget.isDesktop && state.workspace == Workspace.trash)
            TextButton.icon(
              onPressed: () => _emptyTrash(context),
              icon: const Icon(AppIcons.deleteForever, size: 18),
              label: const Text('Empty trash'),
            ),
        ],
      ),
    );
  }

  /// The "All" chip shows a plain count of visible items, with no badge or
  /// background — just a muted number after the label. On Home, PIN-locked
  /// note/list sections are excluded so the number always matches what is on
  /// screen; Archive and Trash are never locked, so they show their totals.
  Widget _allChipLabel(BuildContext context, AppState state) {
    final services = context.read<Services>();
    final lock = context.read<PinLockController>();
    final onHome = state.workspace == Workspace.home;
    final stream = _typeCountStreams.putIfAbsent(
      state.workspace,
      () => services.entries.watchTypeCounts(state.workspace),
    );

    return StreamBuilder<({int notes, int lists})>(
      stream: stream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const Text('All');

        final showNotes = onHome ? !lock.shouldHideNotes : true;
        final showLists = onHome ? !lock.shouldHideLists : true;
        // Fully gated (both locked, nothing visible yet): no number, so a
        // misleading "0" never shows before the PIN gate is passed.
        if (!showNotes && !showLists) return const Text('All');

        final total =
            (showNotes ? data.notes : 0) + (showLists ? data.lists : 0);
        return Text.rich(
          TextSpan(
            text: 'All',
            children: [
              TextSpan(
                text: '  $total',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _trashBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(AppIcons.trash, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Items here are not deleted yet. Delete forever cannot be undone.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Cards
  // ---------------------------------------------------------------------

  Widget _cards(
    BuildContext context,
    List<EntryBundle> bundles,
    CardViewMode mode,
    AppState state,
  ) {
    final width = MediaQuery.sizeOf(context).width;

    Widget cardFor(EntryBundle bundle) => EntryCard(
          bundle: bundle,
          viewMode: mode,
          workspace: state.workspace,
          selected: state.isSelected(bundle.entry.id),
          selectionMode: state.selectionMode,
          onTap: () {
            if (state.selectionMode) {
              context.read<AppState>().toggleSelected(bundle.entry.id);
            } else {
              _open(context, bundle.entry.id);
            }
          },
          onLongPress: () =>
              context.read<AppState>().toggleSelected(bundle.entry.id),
          onPin: () => context.read<Services>().entries.togglePinned(bundle.entry.id),
          onColor: () => _pickColor(context, bundle),
          onArchive: () =>
              context.read<Services>().entries.archive(bundle.entry.id),
          onTrash: () =>
              context.read<Services>().entries.moveToTrash(bundle.entry.id),
          onRestore: () => state.workspace == Workspace.archive
              ? context.read<Services>().entries.restoreFromArchive(bundle.entry.id)
              : context.read<Services>().entries.restoreFromTrash(bundle.entry.id),
          onDeleteForever: () => _deleteForever(context, bundle),
          onExport: () => ExportDialog.show(context, [bundle]),
          onMore: widget.isDesktop && mode != CardViewMode.rows
              ? null
              : () => _showCardActions(context, bundle, state),
        );

    if (mode == CardViewMode.rows) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
        itemCount: bundles.length,
        separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1),
        itemBuilder: (context, index) => cardFor(bundles[index]),
      );
    }

    if (mode == CardViewMode.list) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        itemCount: bundles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => cardFor(bundles[index]),
      );
    }

    // U-11: masonry for grid and compact, with a column count that adapts.
    final columns = switch (mode) {
      CardViewMode.compact => (width / 210).floor().clamp(2, 8),
      CardViewMode.rows => 1,
      _ => (width / 280).floor().clamp(1, 6),
    };

    return MasonryGridView.count(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      crossAxisCount: columns,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      itemCount: bundles.length,
      itemBuilder: (context, index) => cardFor(bundles[index]),
    );
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  void _open(BuildContext context, String id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ItemPage(entryId: id)),
    );
  }

  void _enterSelectionMode(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Long-press any card to start selecting.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showCardActions(
    BuildContext context,
    EntryBundle bundle,
    AppState state,
  ) {
    final inTrash = state.workspace == Workspace.trash;
    final inArchive = state.workspace == Workspace.archive;
    showActionSheet(
      context,
      title: bundle.entry.title.trim().isEmpty
          ? 'Untitled'
          : bundle.entry.title.trim(),
      actions: [
        if (!inTrash) ...[
          SheetAction(
            icon: AppIcons.pinOutline,
            label: bundle.entry.isPinned ? 'Unpin' : 'Pin',
            onTap: () =>
                context.read<Services>().entries.togglePinned(bundle.entry.id),
          ),
          SheetAction(
            icon: AppIcons.color,
            label: 'Change colour',
            onTap: () => _pickColor(context, bundle),
          ),
          SheetAction(
            icon: inArchive ? AppIcons.unarchive : AppIcons.archive,
            label: inArchive ? 'Unarchive' : 'Archive',
            onTap: () => inArchive
                ? context
                    .read<Services>()
                    .entries
                    .restoreFromArchive(bundle.entry.id)
                : context.read<Services>().entries.archive(bundle.entry.id),
          ),
          SheetAction(
            icon: AppIcons.export,
            label: 'Export',
            onTap: () => ExportDialog.show(context, [bundle]),
          ),
          SheetAction(
            icon: AppIcons.trash,
            label: 'Move to trash',
            onTap: () =>
                context.read<Services>().entries.moveToTrash(bundle.entry.id),
          ),
        ] else ...[
          SheetAction(
            icon: AppIcons.restore,
            label: 'Restore',
            onTap: () => context
                .read<Services>()
                .entries
                .restoreFromTrash(bundle.entry.id),
          ),
          SheetAction(
            icon: AppIcons.export,
            label: 'Export',
            onTap: () => ExportDialog.show(context, [bundle]),
          ),
          SheetAction(
            icon: AppIcons.deleteForever,
            label: 'Delete forever',
            destructive: true,
            onTap: () => _deleteForever(context, bundle),
          ),
        ],
      ],
    );
  }

  void _showViewOptions(BuildContext context, SettingsRepository settings) {
    showActionSheet(
      context,
      title: 'Card view',
      actions: [
        for (final mode in CardViewMode.values)
          SheetAction(
            icon: switch (mode) {
              CardViewMode.grid => AppIcons.viewGrid,
              CardViewMode.list => AppIcons.viewList,
              CardViewMode.compact => AppIcons.viewCompact,
              CardViewMode.rows => AppIcons.viewRows,
            },
            label: mode.label,
            selected: settings.cardViewMode == mode,
            onTap: () => settings.setCardViewMode(mode),
          ),
      ],
    );
  }

  void _showSortOptions(BuildContext context, SettingsRepository settings) {
    showActionSheet(
      context,
      title: 'Sort by',
      actions: [
        for (final mode in SortMode.values)
          SheetAction(
            icon: AppIcons.sort,
            label: mode == SortMode.recentlyViewed
                ? '${mode.label} (this device)'
                : mode.label,
            selected: settings.sortMode == mode,
            onTap: () => settings.setSortMode(mode),
          ),
      ],
    );
  }

  Future<void> _pickColor(BuildContext context, EntryBundle bundle) async {
    final key = widget.isDesktop
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

  Future<void> _colorSelected(BuildContext context, AppState state) async {
    final key = await ColorPickerSheet.showSheet(context, currentKey: 'default');
    if (key == null || !context.mounted) return;
    final services = context.read<Services>();
    await services.entries.setColorAll(state.selected, key);
    if (context.mounted) context.read<AppState>().clearSelection();
  }

  Future<void> _exportSelected(BuildContext context, AppState state) async {
    final services = context.read<Services>();
    final bundles = await services.entries.entriesByIds(state.selected.toList());
    if (!context.mounted) return;
    await ExportDialog.show(context, bundles);
    if (context.mounted) context.read<AppState>().clearSelection();
  }

  /// T-12/T-17
  Future<void> _deleteForever(BuildContext context, EntryBundle bundle) async {
    final title = bundle.entry.title.trim();
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete forever?',
      message: '"${title.isEmpty ? "Untitled" : title}" will be permanently '
          'deleted from this device and from every synced device. '
          'This cannot be undone.',
      confirmLabel: 'Delete forever',
    );
    if (!confirmed || !context.mounted) return;
    await context.read<Services>().entries.deleteForever(bundle.entry.id);
  }

  Future<void> _deleteSelectedForever(
    BuildContext context,
    AppState state,
  ) async {
    final count = state.selectedCount;
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete $count item${count == 1 ? "" : "s"} forever?',
      message: 'They will be permanently deleted from this device and from '
          'every synced device. This cannot be undone.',
      confirmLabel: 'Delete forever',
    );
    if (!confirmed || !context.mounted) return;
    final services = context.read<Services>();
    await services.entries.deleteForeverAll(state.selected);
    if (context.mounted) context.read<AppState>().clearSelection();
  }

  /// T-13
  Future<void> _emptyTrash(BuildContext context) async {
    final services = context.read<Services>();
    final count = await services.entries.countIn(Workspace.trash);
    if (count == 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trash is already empty.')),
        );
      }
      return;
    }
    if (!context.mounted) return;

    final confirmed = await confirmDestructive(
      context,
      title: 'Empty trash?',
      message: '$count item${count == 1 ? "" : "s"} will be permanently '
          'deleted from this device and from every synced device. '
          'This cannot be undone.',
      confirmLabel: 'Empty trash',
    );
    if (!confirmed || !context.mounted) return;

    final removed = await services.entries.emptyTrash();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted $removed item${removed == 1 ? "" : "s"}.')),
    );
  }

  Future<void> _sync(BuildContext context) async {
    final services = context.read<Services>();
    final result = await context.read<SyncController>().syncNow();
    if (result == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.summary)),
    );
    // B-06: the scheduled backup runs after a successful sync.
    if (result.ok) {
      unawaited(services.maybeBackupAfterSync());
    }
  }
}
