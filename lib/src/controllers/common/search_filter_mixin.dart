import 'package:flutter/foundation.dart';

/// Generic mixin providing search query state for [ChangeNotifier] controllers.
mixin SearchFilterMixin on ChangeNotifier {
  String _searchQuery = '';

  /// Active search query string.
  String get searchQuery => _searchQuery;

  /// Updates the active search query.
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  /// Clears the active search query.
  void clearSearchQuery() {
    if (_searchQuery.isEmpty) return;
    _searchQuery = '';
    notifyListeners();
  }
}
