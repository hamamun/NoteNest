import 'package:flutter/foundation.dart';

import '../data/models/enums.dart';

/// UI-only state: which screen, which filter, what is selected.
///
/// Kept separate from the repositories so that navigating and selecting never
/// touches the database.
class AppState extends ChangeNotifier {
  Workspace _workspace = Workspace.home;
  EntryFilter _filter = EntryFilter.all;
  String _query = '';
  String? _activeTagId;
  final Set<String> _selected = <String>{};

  Workspace get workspace => _workspace;
  EntryFilter get filter => _filter;
  String get query => _query;
  String? get activeTagId => _activeTagId;

  Set<String> get selected => Set.unmodifiable(_selected);
  int get selectedCount => _selected.length;

  /// U-06/E-03: the export and bulk toolbars only exist in selection mode.
  bool get selectionMode => _selected.isNotEmpty;

  bool isSelected(String id) => _selected.contains(id);

  void setWorkspace(Workspace workspace) {
    if (_workspace == workspace) return;
    _workspace = workspace;
    _selected.clear();
    _query = '';
    notifyListeners();
  }

  void setFilter(EntryFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    notifyListeners();
  }

  void setQuery(String query) {
    if (_query == query) return;
    _query = query;
    notifyListeners();
  }

  void setActiveTag(String? tagId) {
    _activeTagId = tagId;
    notifyListeners();
  }

  void toggleSelected(String id) {
    if (!_selected.remove(id)) _selected.add(id);
    notifyListeners();
  }

  void select(String id) {
    if (_selected.add(id)) notifyListeners();
  }

  void selectAll(Iterable<String> ids) {
    _selected
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }
}
