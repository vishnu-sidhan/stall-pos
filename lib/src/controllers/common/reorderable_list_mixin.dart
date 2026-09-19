/// Generic mixin providing standard index shifting and bounds clamping for drag-and-drop lists.
mixin ReorderableListMixin {
  /// Shifts an item in a list from [oldIndex] to [newIndex] following Flutter's
  /// [ReorderableListView] semantics (compensating for index offset when dragging downwards).
  void reorderList<T>(List<T> list, int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex < 0 || newIndex > list.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = list.removeAt(oldIndex);
    final insertPos = newIndex.clamp(0, list.length);
    list.insert(insertPos, item);
  }
}
