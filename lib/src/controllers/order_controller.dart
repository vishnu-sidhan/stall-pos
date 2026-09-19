import 'package:flutter/material.dart';
import '../models/stall_models.dart';
import '../storage/stall_storage.dart';
import '../storage/in_memory_storage.dart';
import 'common/async_loading_mixin.dart';
import 'stall_pos/mixins/pos_mixins.dart';

/// State controller for Stall POS operations:
/// orchestrates menu catalog, active cart, orders queue, in-place order editing,
/// deletion, and reactive aggregated kitchen preparations via modular mixins.
class OrderController extends ChangeNotifier
    with
        AsyncLoadingMixin,
        PredefinedNotesControllerMixin,
        CategoryConfigControllerMixin,
        MenuCatalogControllerMixin,
        CartControllerMixin,
        OrderLifecycleControllerMixin,
        KitchenPrepControllerMixin {
  final StallStorage _storageService;

  static const List<String> defaultPredefinedNotes =
      PredefinedNotesControllerMixin.defaultPredefinedNotes;

  static const int maxPerAddonItem = CartControllerMixin.maxPerAddonItem;
  static const int maxAddonsPerItem = maxPerAddonItem;

  OrderController({StallStorage? storage})
      : _storageService = storage ?? InMemoryStorage();

  StallStorage get storage => _storageService;
  StallStorage get storageService => _storageService;

  @override
  Future<void> saveState() async {
    await _storageService.saveMenu(rawMenu);
    await _storageService.saveOrders(rawOrders);
    await _storageService.saveNextToken(nextToken);
    await _storageService.saveCategories(categoryConfigs);
  }

  @override
  Future<void> onPredefinedNotesChanged() async {
    await _storageService.savePredefinedNotes(predefinedNotes);
  }

  @override
  Future<void> archiveCompletedOrdersToStorage(List<StallOrder> completed) async {
    await _storageService.archiveCompletedOrders(explicitOrders: completed);
  }

  /// Initial persistence load coordinating state hydration across all domain mixins.
  Future<void> loadPersistedData() async {
    setLoading(true);

    final loadedMenu = await _storageService.loadMenu();
    setLoadedMenu(loadedMenu);

    final loadedOrders = await _storageService.loadOrders();
    final loadedNextToken = await _storageService.loadNextToken();
    setLoadedOrders(loadedOrders, loadedNextToken);

    final loadedCategories = await _storageService.loadCategories();
    setLoadedCategoryConfigs(loadedCategories);

    final loadedNotes = await _storageService.loadPredefinedNotes();
    setLoadedPredefinedNotes(loadedNotes);

    await syncCategoriesWithMenu();

    // Hydrate orders with current menu item attributes (name, color, dietary type, price)
    for (int i = 0; i < rawOrders.length; i++) {
      final order = rawOrders[i];
      final hydratedItems = order.items.map((item) {
        final menuItem = findItem(item.itemId);
        final name = (item.itemName.isEmpty || item.itemName == item.itemId || item.itemName == 'Item')
            ? (menuItem.name.isNotEmpty ? menuItem.name : item.itemName)
            : item.itemName;
        final cat = (item.categoryName != null && item.categoryName!.isNotEmpty)
            ? item.categoryName
            : menuItem.categoryName;
        final colorHex = item.colorHex ?? menuItem.colorHex;
        final dietary = item.dietaryType != ItemDietaryType.none
            ? item.dietaryType
            : (menuItem.dietaryType ?? ItemDietaryType.none);
        final price = menuItem.price > 0 ? menuItem.price : item.price;
        return item.copyWith(
          itemName: name,
          categoryName: cat,
          colorHex: colorHex,
          dietaryType: dietary,
          price: price,
        );
      }).toList();

      rawOrders[i] = order.copyWith(items: hydratedItems);
    }

    setLoading(false);
  }

  /// Alias for loading initial persisted data and building cached indexes.
  Future<void> loadInitialData() => loadPersistedData();

  /// Formats an item's display name for Active Orders and Item Summary.
  static String formatOrderLineItemDisplayName({
    required String rawName,
    required String itemId,
    String? category,
    String? baseItemName,
  }) =>
      CartKeyParser.formatOrderLineItemDisplayName(
        rawName: rawName,
        itemId: itemId,
        category: category,
        baseItemName: baseItemName,
      );

  /// Normalizes category key by trimming segments around '/' slashes to prevent whitespace discrepancies.
  static String normalizeCategoryKey(String cat) =>
      CartKeyParser.normalizeCategoryKey(cat);
}
