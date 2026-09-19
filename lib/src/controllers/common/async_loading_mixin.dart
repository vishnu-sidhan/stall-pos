import 'package:flutter/foundation.dart';

/// Generic mixin providing loading state tracking for [ChangeNotifier] controllers.
mixin AsyncLoadingMixin on ChangeNotifier {
  bool _isLoading = true;

  /// Whether the controller is actively performing an asynchronous load/mutation.
  bool get isLoading => _isLoading;

  /// Updates the loading state and conditionally notifies listeners.
  @protected
  void setLoading(bool loading, {bool notify = true}) {
    if (_isLoading != loading) {
      _isLoading = loading;
      if (notify) {
        notifyListeners();
      }
    }
  }
}
