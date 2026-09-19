import 'package:flutter/foundation.dart';

/// Mixin managing quick-add predefined notes for orders and ticket customization.
mixin PredefinedNotesControllerMixin on ChangeNotifier {
  static const List<String> defaultPredefinedNotes = [
    'Parcel',
    'Less Spicy',
    'Extra Spicy',
    'No Onion/Garlic',
    'Pack Separately',
  ];

  List<String> _predefinedNotes = List.from(defaultPredefinedNotes);

  /// Unmodifiable view of active predefined notes.
  List<String> get predefinedNotes => List.unmodifiable(_predefinedNotes);

  /// Callback to persist updated predefined notes to storage.
  @protected
  Future<void> onPredefinedNotesChanged();

  /// Sets loaded predefined notes from persistence.
  @protected
  void setLoadedPredefinedNotes(List<String> loaded) {
    if (loaded.isNotEmpty) {
      _predefinedNotes = List.from(loaded);
    } else {
      _predefinedNotes = List.from(defaultPredefinedNotes);
    }
  }

  /// Adds a custom predefined note if not already present.
  Future<void> addPredefinedNote(String note) async {
    final clean = note.trim();
    if (clean.isEmpty) return;
    if (!_predefinedNotes.any((n) => n.toLowerCase() == clean.toLowerCase())) {
      _predefinedNotes.add(clean);
      await onPredefinedNotesChanged();
      notifyListeners();
    }
  }

  /// Removes a predefined note by name.
  Future<void> removePredefinedNote(String note) async {
    _predefinedNotes.removeWhere((n) => n.toLowerCase() == note.trim().toLowerCase());
    await onPredefinedNotesChanged();
    notifyListeners();
  }

  /// Resets predefined notes to default list.
  Future<void> resetPredefinedNotes() async {
    _predefinedNotes = List.from(defaultPredefinedNotes);
    await onPredefinedNotesChanged();
    notifyListeners();
  }
}
