/// Shared enumerations for NoteNest.
///
/// Every enum stores itself as a stable string so the value can be written to
/// SQLite and to GitHub front matter without breaking when the enum order
/// changes in a later version.

/// N-01: the app has exactly two content types.
enum EntryType {
  note('note'),
  checklist('checklist');

  const EntryType(this.value);
  final String value;

  static EntryType parse(String? raw) => EntryType.values.firstWhere(
        (t) => t.value == raw,
        orElse: () => EntryType.note,
      );

  bool get isChecklist => this == EntryType.checklist;
}

/// T-01: `location` is the single source of truth for where an item lives.
enum EntryLocation {
  active('active'),
  archive('archive'),
  trash('trash'),
  deleted('deleted');

  const EntryLocation(this.value);
  final String value;

  static EntryLocation parse(String? raw) => EntryLocation.values.firstWhere(
        (l) => l.value == raw,
        orElse: () => EntryLocation.active,
      );

  /// `deleted` is an internal tombstone state and never renders (T-03).
  bool get isVisible => this != EntryLocation.deleted;
}

/// Per-entry sync bookkeeping (D-01).
enum SyncStatus {
  synced('synced'),
  pending('pending'),
  pendingDelete('pending_delete'),
  conflictReview('conflict_review'),
  error('error');

  const SyncStatus(this.value);
  final String value;

  static SyncStatus parse(String? raw) => SyncStatus.values.firstWhere(
        (s) => s.value == raw,
        orElse: () => SyncStatus.pending,
      );
}

/// U-11: home/archive/trash card layout. Device-local preference (U-12).
enum CardViewMode {
  grid('grid', 'Grid'),
  list('list', 'List'),
  compact('compact', 'Compact');

  const CardViewMode(this.value, this.label);
  final String value;
  final String label;

  static CardViewMode parse(String? raw) => CardViewMode.values.firstWhere(
        (m) => m.value == raw,
        orElse: () => CardViewMode.grid,
      );
}

/// S-08: sort options. `recentlyViewed` is local-only (S-09).
enum SortMode {
  recentlyEdited('recently_edited', 'Recently edited'),
  createdNewest('created_newest', 'Created newest'),
  createdOldest('created_oldest', 'Created oldest'),
  titleAz('title_az', 'Title A-Z'),
  recentlyViewed('recently_viewed', 'Recently viewed');

  const SortMode(this.value, this.label);
  final String value;
  final String label;

  static SortMode parse(String? raw) => SortMode.values.firstWhere(
        (m) => m.value == raw,
        orElse: () => SortMode.recentlyEdited,
      );
}

/// B-02: backup cadence.
enum BackupFrequency {
  disabled('disabled', 'Disabled'),
  weekly('weekly', 'Weekly'),
  monthly('monthly', 'Monthly');

  const BackupFrequency(this.value, this.label);
  final String value;
  final String label;

  static BackupFrequency parse(String? raw) =>
      BackupFrequency.values.firstWhere(
        (f) => f.value == raw,
        orElse: () => BackupFrequency.disabled,
      );
}

/// SET-01: content font size steps. Only note/list content scales (SET-02).
enum FontSizeStep {
  small('small', 'Small', 0.90),
  normal('default', 'Default', 1.00),
  large('large', 'Large', 1.15),
  extraLarge('extra_large', 'Extra Large', 1.30);

  const FontSizeStep(this.value, this.label, this.scale);
  final String value;
  final String label;
  final double scale;

  static FontSizeStep parse(String? raw) => FontSizeStep.values.firstWhere(
        (f) => f.value == raw,
        orElse: () => FontSizeStep.normal,
      );

  static FontSizeStep fromScale(double scale) {
    var best = FontSizeStep.normal;
    var bestDelta = double.infinity;
    for (final step in FontSizeStep.values) {
      final delta = (step.scale - scale).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = step;
      }
    }
    return best;
  }
}

/// Home/Archive/Trash content filter (U-08, T-04).
enum EntryFilter {
  all('all', 'All'),
  notes('notes', 'Notes'),
  lists('lists', 'Lists');

  const EntryFilter(this.value, this.label);
  final String value;
  final String label;

  EntryType? get type => switch (this) {
        EntryFilter.all => null,
        EntryFilter.notes => EntryType.note,
        EntryFilter.lists => EntryType.checklist,
      };
}

/// Which screen the user is browsing (T-03).
enum Workspace {
  home('home', 'Home', EntryLocation.active),
  archive('archive', 'Archive', EntryLocation.archive),
  trash('trash', 'Trash', EntryLocation.trash);

  const Workspace(this.value, this.label, this.location);
  final String value;
  final String label;
  final EntryLocation location;
}
