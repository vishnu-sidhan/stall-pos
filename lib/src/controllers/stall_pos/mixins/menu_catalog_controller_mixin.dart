import 'package:flutter/foundation.dart';
import '../../../models/stall_models.dart';
import '../../../services/csv_export_service.dart';
import '../../../services/csv_import_service.dart';
import 'cart_key_parser.dart';

/// Mixin managing menu items catalog, indexes, availability toggles, CSV import/export,
/// filtering, and item lookup resolution for Stall POS.
mixin MenuCatalogControllerMixin on ChangeNotifier {
  List<MenuItem> _menu = [];
  final Map<String, MenuItem> _itemById = {};
  final Map<String, List<MenuItem>> _itemsByCategoryId = {};

  /// Abstract requirements provided by [CategoryConfigControllerMixin] and host controller.
  List<ItemCategory> get categoryConfigs;
  ItemCategory? getCategoryConfig(String category);
  double getCategoryCost(String category);
  String? getCategoryCostReason(String category);
  ItemCategory resolveItemCategory(String categoryName);
  MenuItem hydrateMenuItemCategory(MenuItem item);
  String get selectedCategory;
  void selectCategory(String category);
  Future<void> saveCategoryConfig(ItemCategory config);
  Future<void> syncCategoriesWithMenu({bool replace = false});
  void invalidateCategoryColors();
  Future<void> saveState();

  /// Abstract hook invoked when a menu item is deleted, allowing Cart to clear matching entries.
  void onMenuItemDeleted(String itemId);

  /// Raw mutable list of menu items.
  List<MenuItem> get rawMenu => _menu;

  /// Unmodifiable view of menu items hydrated with category configs.
  List<MenuItem> get menu =>
      List.unmodifiable(_menu.map(hydrateMenuItemCategory));

  /// Unmodifiable view of currently available menu items.
  List<MenuItem> get availableMenu => List.unmodifiable(
    _menu.where((m) => m.isEffectivelyAvailable).map(hydrateMenuItemCategory),
  );

  /// Sets loaded menu from storage during initialization.
  @protected
  void setLoadedMenu(List<MenuItem> loaded) {
    _menu = List.from(loaded);
    rebuildIndexes();
  }

  /// Rebuilds lookup indexes for fast O(1) item and category lookups.
  void rebuildIndexes() {
    _itemById.clear();
    _itemsByCategoryId.clear();
    for (final item in _menu) {
      final hydrated = hydrateMenuItemCategory(item);
      _itemById[hydrated.id] = hydrated;
      (_itemsByCategoryId[hydrated.category.id] ??= []).add(hydrated);
    }
  }

  /// Hook called by [CategoryConfigControllerMixin] to rebuild indexes.
  void rebuildMenuIndexes() => rebuildIndexes();

  /// O(1) indexed lookup by item ID.
  MenuItem? getItemById(String id) {
    final item = _itemById[id];
    return item != null ? hydrateMenuItemCategory(item) : null;
  }

  /// O(1) indexed lookup of items belonging to a category ID.
  List<MenuItem> getItemsByCategory(String categoryId) =>
      _itemsByCategoryId[categoryId] ?? const [];

  MenuItem? findBaseMenuItem(String key) {
    final firstPart = key.split('+').first;
    final direct = getItemById(firstPart);
    if (direct != null) return direct;

    final parsedBaseId = CartKeyParser.parseBaseIdFromKey(firstPart);
    final parsed = getItemById(parsedBaseId);
    if (parsed != null) return parsed;

    for (final m in _menu) {
      if (firstPart == m.id ||
          firstPart.startsWith('${m.id}_var_') ||
          firstPart.startsWith('${m.id}_cat_')) {
        return m;
      }
    }
    return null;
  }

  bool isBaseItemMatch(String cartId, String targetId) {
    final base = findBaseMenuItem(cartId);
    if (base != null) return base.id == targetId;
    return CartKeyParser.parseBaseIdFromKey(cartId) == targetId;
  }

  /// Resolves the base [MenuItem] for a given item key,
  /// taking into account any variant or category customizations.
  MenuItem resolveBaseItem(String baseId) {
    final direct = getItemById(baseId);
    if (direct != null) return direct;

    final matchedBase = findBaseMenuItem(baseId);
    if (matchedBase != null &&
        (baseId.contains('_var_') || baseId.contains('_cat_'))) {
      final firstPart = baseId.split('+').first;
      final suffix = firstPart.substring(matchedBase.id.length);

      String? parsedVar;
      String? parsedCat;
      if (suffix.contains('_var_')) {
        final afterVar = suffix.split('_var_')[1];
        parsedVar = afterVar.contains('_cat_')
            ? afterVar.split('_cat_').first
            : afterVar;
      }
      if (suffix.contains('_cat_')) {
        parsedCat = suffix.split('_cat_')[1];
      }

      final rawBase = matchedBase;
      final rawCat = parsedCat != null
          ? resolveItemCategory(parsedCat)
          : rawBase.category;
      final resolvedName = parsedVar;

      CategoryOption? matchedVariant;
      if (resolvedName != null) {
        final normalizedTarget = resolvedName.trim().toLowerCase();
        for (final v in rawBase.effectiveVariants) {
          final vNorm = v.name.trim().toLowerCase();
          if (vNorm == normalizedTarget ||
              normalizedTarget.startsWith(vNorm) ||
              normalizedTarget.contains(vNorm)) {
            matchedVariant = v;
            break;
          }
        }
        if (matchedVariant == null) {
          final catConfig = getCategoryConfig(rawCat.name);
          if (catConfig != null) {
            for (final opt in catConfig.options) {
              final optNorm = opt.name.trim().toLowerCase();
              if (optNorm == normalizedTarget ||
                  normalizedTarget.startsWith(optNorm) ||
                  normalizedTarget.contains(optNorm)) {
                matchedVariant = opt;
                break;
              }
            }
          }
        }
      }

      final effectivePrice = rawBase.priceForVariant(matchedVariant);
      final catKey = rawCat.name.trim().toLowerCase();
      final baseLower = rawBase.name.trim().toLowerCase();
      final varLower = resolvedName?.trim().toLowerCase();

      String effectiveName;
      if (resolvedName != null &&
          resolvedName.trim().isNotEmpty &&
          resolvedName.trim() != rawBase.name.trim()) {
        final cleanVar = resolvedName.trim();
        if (rawBase.name.contains('/')) {
          effectiveName = cleanVar;
        } else if (catKey.isNotEmpty &&
            baseLower.contains(catKey) &&
            varLower != null &&
            !varLower.contains(catKey)) {
          effectiveName = '$cleanVar (${rawBase.name})';
        } else if (!rawBase.name.contains('($cleanVar)')) {
          effectiveName = '${rawBase.name} ($cleanVar)';
        } else {
          effectiveName = rawBase.name;
        }
      } else {
        effectiveName = rawBase.name;
      }

      return rawBase.copyWith(
        name: effectiveName,
        price: effectivePrice,
        category: rawCat,
      );
    }

    if (matchedBase != null) return matchedBase;

    return MenuItem(
      id: baseId,
      name: baseId.isNotEmpty ? baseId : 'Item',
      price: 0.0,
      category: resolveItemCategory('General'),
    );
  }

  /// Breakdown of pricing components for a cart item or line item.
  CartItemBreakdown? getCartItemBreakdown(String itemId) {
    final compositeIndex = itemId.indexOf('+');
    final baseId = compositeIndex != -1
        ? itemId.substring(0, compositeIndex)
        : itemId;
    final baseItem = resolveBaseItem(baseId);
    final categoryAdditionalCost = getCategoryCost(baseItem.categoryName);
    final categoryCostReason = getCategoryCostReason(baseItem.categoryName);

    final addonDetails = <CartItemAddonDetail>[];
    double addonsPrice = 0.0;

    if (compositeIndex != -1) {
      final addonSection = itemId.substring(compositeIndex + 1);
      final addonIdList = addonSection.split('+');

      final Map<String, int> addonCounts = {};
      for (final aid in addonIdList) {
        if (aid.isNotEmpty) {
          addonCounts[aid] = (addonCounts[aid] ?? 0) + 1;
        }
      }

      for (final entry in addonCounts.entries) {
        final key = entry.key;
        CategoryOption? itemAddon;
        final candidateAddons = [
          ...baseItem.addons,
          ...(getCategoryConfig(baseItem.categoryName)?.addons ??
              const <CategoryOption>[]),
        ];
        for (final a in candidateAddons) {
          if (a.id == key || a.name == key) {
            itemAddon = a;
            break;
          }
        }

        final addonName = itemAddon != null
            ? itemAddon.name
            : resolveBaseItem(key).name;
        final singlePrice = itemAddon != null
            ? (itemAddon.priceDelta > 0
                  ? itemAddon.priceDelta
                  : (itemAddon.price ?? 0.0))
            : resolveBaseItem(key).price;
        final totalAddonPrice = singlePrice * entry.value;
        addonsPrice += totalAddonPrice;
        addonDetails.add((
          name: addonName,
          count: entry.value,
          singlePrice: singlePrice,
          totalPrice: totalAddonPrice,
        ));
      }
    }

    if (addonDetails.isEmpty && categoryAdditionalCost == 0) {
      return null;
    }

    return (
      baseItem: baseItem,
      basePrice: baseItem.price,
      categoryAdditionalCost: categoryAdditionalCost,
      categoryCostReason: categoryCostReason,
      addonsPrice: addonsPrice,
      totalUnitPrice: baseItem.price + categoryAdditionalCost + addonsPrice,
      addonDetails: addonDetails,
    );
  }

  /// Finds a MenuItem by ID.
  /// Supports:
  /// - Direct catalog menu items
  /// - Slash variant / category dynamic selections (e.g. "itemId_var_option_cat_Rice")
  /// - Composite add-on items (e.g. "itemId+addonId1+addonId2")
  MenuItem findItem(String itemId) {
    final compositeIndex = itemId.indexOf('+');

    if (compositeIndex != -1) {
      final breakdown = getCartItemBreakdown(itemId);
      if (breakdown != null) {
        final prefix = breakdown.addonDetails
            .map((entry) {
              final name = entry.name;
              final count = entry.count;
              return count > 1
                  ? '[$count'
                        'x $name]'
                  : '[$name]';
            })
            .join(' ');

        return MenuItem(
          id: itemId,
          name: '$prefix ${breakdown.baseItem.displayName}'.trim(),
          price: breakdown.totalUnitPrice,
          category: breakdown.baseItem.category,
          colorHex: breakdown.baseItem.colorHex,
          dietaryType: breakdown.baseItem.dietaryType,
        );
      }
    }

    if (itemId.contains('_var_') || itemId.contains('_cat_')) {
      final baseItem = resolveBaseItem(itemId);
      final catCost = getCategoryCost(baseItem.categoryName);
      return MenuItem(
        id: itemId,
        name: baseItem.name,
        price: baseItem.price + catCost,
        category: baseItem.category,
        colorHex: baseItem.colorHex,
        dietaryType: baseItem.dietaryType,
      );
    }

    final direct = getItemById(itemId);
    if (direct != null) {
      final hydrated = hydrateMenuItemCategory(direct);
      final catCost = getCategoryCost(hydrated.categoryName);
      return catCost > 0
          ? hydrated.copyWith(price: hydrated.price + catCost)
          : hydrated;
    }

    return MenuItem(
      id: itemId,
      name: itemId.isNotEmpty ? itemId : 'Item',
      price: 0.0,
      category: resolveItemCategory('General'),
    );
  }

  /// Group menu items by category name.
  Map<String, List<MenuItem>> get menuByCategory {
    final map = <String, List<MenuItem>>{};
    for (final item in _menu) {
      final cat = item.categoryName.isNotEmpty ? item.categoryName : 'General';
      map.putIfAbsent(cat, () => []).add(hydrateMenuItemCategory(item));
    }
    return map;
  }

  ItemDietaryType? _selectedDietary;

  /// Currently active dietary type filter (null means "All").
  ItemDietaryType? get selectedDietaryType => _selectedDietary;

  /// Updates active dietary filter without resetting selected category.
  void selectDietary(ItemDietaryType? dietary) {
    if (_selectedDietary == dietary) return;
    _selectedDietary = dietary;
    notifyListeners();
  }

  /// Bulk sets availability for all items of a specific dietary type.
  Future<void> setDietaryAvailability(ItemDietaryType dietary, bool isAvailable) async {
    bool modified = false;
    for (int i = 0; i < _menu.length; i++) {
      if (_menu[i].effectiveDietaryType == dietary) {
        if (_menu[i].isAvailable != isAvailable) {
          _menu[i] = _menu[i].copyWith(isAvailable: isAvailable);
          modified = true;
        }
      }
    }
    if (modified) {
      rebuildIndexes();
      await saveState();
      notifyListeners();
    }
  }

  /// Centralized menu item search and filtering helper.
  List<MenuItem> filterMenuItems({
    String query = '',
    String? categoryId,
    bool onlyAvailable = false,
    ItemDietaryType? dietary,
  }) {
    final effectiveDietary = dietary ?? _selectedDietary;
    return _menu.where((item) {
      if (onlyAvailable && !item.isEffectivelyAvailable) return false;
      if (categoryId != null &&
          item.category.id != categoryId &&
          item.categoryName.toLowerCase() != categoryId.toLowerCase()) {
        return false;
      }
      if (effectiveDietary != null && effectiveDietary != ItemDietaryType.none) {
        if (effectiveDietary == ItemDietaryType.veg) {
          if (item.effectiveDietaryType != ItemDietaryType.veg) return false;
        } else if (effectiveDietary == ItemDietaryType.nonVeg) {
          if (item.effectiveDietaryType != ItemDietaryType.nonVeg) return false;
        } else {
          if (item.effectiveDietaryType != effectiveDietary) return false;
        }
      }
      if (query.isNotEmpty) {
        final q = query.toLowerCase().trim();
        final matchesName = item.name.toLowerCase().contains(q);
        final matchesCat = item.category.name.toLowerCase().contains(q);
        final matchesVariants = item.effectiveVariants.any(
          (v) => v.name.toLowerCase().contains(q),
        );
        if (!matchesName && !matchesCat && !matchesVariants) return false;
      }
      return true;
    }).toList();
  }

  /// Filtered menu of items available for today based on selected category chip.
  List<MenuItem> get filteredMenu {
    final cat = selectedCategory == 'All' ? null : selectedCategory;
    final list = filterMenuItems(categoryId: cat, onlyAvailable: true);
    return list.map(hydrateMenuItemCategory).toList();
  }

  /// All menu items including unavailable ones, filtered by category.
  List<MenuItem> get allFilteredMenu {
    final cat = selectedCategory == 'All' ? null : selectedCategory;
    final list = filterMenuItems(categoryId: cat, onlyAvailable: false);
    return list.map(hydrateMenuItemCategory).toList();
  }

  /// Menu items available for today grouped by category for POS accordion rendering.
  Map<String, List<MenuItem>> get groupedMenu {
    final map = <String, List<MenuItem>>{};
    final items = filteredMenu;
    for (final item in items) {
      final cat = item.categoryName.trim().isEmpty
          ? 'General'
          : item.categoryName.trim();
      map.putIfAbsent(cat, () => []).add(item);
    }
    return map;
  }

  /// All menu items grouped by category (for daily menu availability management).
  Map<String, List<MenuItem>> get allGroupedMenu {
    final map = <String, List<MenuItem>>{};
    for (final item in _menu) {
      final cat = item.categoryName.trim().isEmpty
          ? 'General'
          : item.categoryName.trim();
      map.putIfAbsent(cat, () => []).add(hydrateMenuItemCategory(item));
    }
    return map;
  }

  /// Adds a menu item to the catalog and persists it.
  Future<void> addMenuItem(MenuItem item) async {
    _menu.add(item);
    rebuildIndexes();
    invalidateCategoryColors();
    await syncCategoriesWithMenu();
    await saveState();
    notifyListeners();
  }

  /// Updates an existing menu item in the catalog.
  Future<void> updateMenuItem(MenuItem updated) async {
    final idx = _menu.indexWhere((m) => m.id == updated.id);
    if (idx != -1) {
      _menu[idx] = updated;
      rebuildIndexes();
      invalidateCategoryColors();
      await syncCategoriesWithMenu();
      await saveState();
      notifyListeners();
    }
  }

  /// Deletes a menu item from the catalog and updates the cart.
  Future<void> deleteMenuItem(String id) async {
    _menu.removeWhere((m) => m.id == id);
    rebuildIndexes();
    onMenuItemDeleted(id);
    if (selectedCategory != 'All' &&
        !_menu.any((m) => m.categoryName == selectedCategory)) {
      selectCategory('All');
    }
    invalidateCategoryColors();
    await saveState();
    notifyListeners();
  }

  /// Replaces or adds bulk menu items.
  Future<void> setMenu(List<MenuItem> newMenu, {bool replace = true}) async {
    if (replace) {
      _menu = List.from(newMenu);
      selectCategory('All');
    } else {
      _menu.addAll(newMenu);
    }
    rebuildIndexes();
    invalidateCategoryColors();
    await syncCategoriesWithMenu(replace: replace);
    await saveState();
    notifyListeners();
  }

  /// Toggles availability of a menu item for today and persists it.
  Future<void> toggleItemAvailability(String id) async {
    final index = _menu.indexWhere((m) => m.id == id);
    if (index == -1) return;
    final current = _menu[index];
    _menu[index] = current.copyWith(isAvailable: !current.isAvailable);
    rebuildIndexes();
    await saveState();
    notifyListeners();
  }

  /// Sets availability of a menu item or add-on for today and persists it.
  Future<void> setItemAvailability(String id, bool isAvailable) async {
    final index = _menu.indexWhere((m) => m.id == id);
    if (index != -1) {
      if (_menu[index].isAvailable == isAvailable) return;
      _menu[index] = _menu[index].copyWith(isAvailable: isAvailable);
      rebuildIndexes();
      await saveState();
      notifyListeners();
      return;
    }

    // Check if id matches an add-on on any category
    for (int i = 0; i < categoryConfigs.length; i++) {
      final cat = categoryConfigs[i];
      final addonIdx = cat.addons.indexWhere(
        (a) =>
            a.id == id ||
            a.name.trim().toLowerCase() == id.trim().toLowerCase(),
      );
      if (addonIdx != -1) {
        final updatedAddons = List<CategoryOption>.from(cat.addons);
        if (updatedAddons[addonIdx].isEnabled != isAvailable) {
          updatedAddons[addonIdx] = updatedAddons[addonIdx].copyWith(
            isEnabled: isAvailable,
          );
          await saveCategoryConfig(cat.copyWith(addons: updatedAddons));
          return;
        }
      }
    }
  }

  /// Toggles or sets availability of an individual add-on on a category and persists it.
  Future<void> toggleCategoryAddonAvailability(
    String categoryName,
    String addonIdOrName, {
    bool? isAvailable,
  }) async {
    final catConfig = getCategoryConfig(categoryName);
    if (catConfig == null) return;
    final catAddons = List<CategoryOption>.from(catConfig.addons);
    final targetIdx = catAddons.indexWhere(
      (a) =>
          a.id == addonIdOrName ||
          a.name.trim().toLowerCase() == addonIdOrName.trim().toLowerCase(),
    );
    if (targetIdx == -1) return;

    final target = catAddons[targetIdx];
    final newStatus = isAvailable ?? !target.isEnabled;
    if (target.isEnabled == newStatus) return;

    catAddons[targetIdx] = target.copyWith(isEnabled: newStatus);
    await saveCategoryConfig(catConfig.copyWith(addons: catAddons));
  }

  /// Toggles or sets availability of an individual add-on on a specific menu item.
  Future<void> toggleMenuItemAddonAvailability(
    String itemId,
    String addonIdOrName, {
    bool? isAvailable,
  }) async {
    final index = _menu.indexWhere((m) => m.id == itemId);
    if (index == -1) return;
    final item = _menu[index];

    final unavail = List<String>.from(item.unavailableAddons);
    final target = addonIdOrName.trim().toLowerCase();
    final isCurrentlyUnavail = unavail.any(
      (a) => a.trim().toLowerCase() == target,
    );

    final shouldBeAvailable = isAvailable ?? isCurrentlyUnavail;
    if (shouldBeAvailable) {
      unavail.removeWhere((a) => a.trim().toLowerCase() == target);
    } else {
      if (!isCurrentlyUnavail) {
        unavail.add(addonIdOrName.trim());
      }
    }

    _menu[index] = item.copyWith(unavailableAddons: unavail);
    rebuildIndexes();
    await saveState();
    notifyListeners();
  }

  /// Toggles or sets availability of an individual variant on a specific menu item.
  Future<void> toggleMenuItemVariantAvailability(
    String itemId,
    String variantIdOrName, {
    bool? isAvailable,
  }) async {
    final index = _menu.indexWhere((m) => m.id == itemId);
    if (index == -1) return;
    final item = _menu[index];

    final unavail = List<String>.from(item.unavailableVariants);
    final target = variantIdOrName.trim().toLowerCase();
    final isCurrentlyUnavail = unavail.any(
      (v) => v.trim().toLowerCase() == target,
    );

    final shouldBeAvailable = isAvailable ?? isCurrentlyUnavail;
    if (shouldBeAvailable) {
      unavail.removeWhere((v) => v.trim().toLowerCase() == target);
    } else {
      if (!isCurrentlyUnavail) {
        unavail.add(variantIdOrName.trim());
      }
    }

    _menu[index] = item.copyWith(unavailableVariants: unavail);
    rebuildIndexes();
    await saveState();
    notifyListeners();
  }

  /// Toggles or sets availability of an individual variant across the entire category and persists it.
  Future<void> toggleCategoryVariantAvailability(
    String categoryName,
    String variantIdOrName, {
    bool? isAvailable,
  }) async {
    final catConfig = getCategoryConfig(categoryName);
    if (catConfig == null) return;
    final currentVariants = List<CategoryOption>.from(catConfig.options);
    if (currentVariants.isEmpty) return;

    final targetIdx = currentVariants.indexWhere(
      (v) =>
          v.id == variantIdOrName ||
          v.name.trim().toLowerCase() == variantIdOrName.trim().toLowerCase(),
    );
    if (targetIdx == -1) return;

    final target = currentVariants[targetIdx];
    final newStatus = isAvailable ?? !target.isEnabled;
    if (target.isEnabled == newStatus) return;

    currentVariants[targetIdx] = target.copyWith(isEnabled: newStatus);
    await saveCategoryConfig(catConfig.copyWith(options: currentVariants));
  }

  /// Sets availability for all items in a category for today and persists it.
  Future<void> setCategoryAvailability(
    String category,
    bool isAvailable,
  ) async {
    bool modified = false;
    final norm = category.trim().toLowerCase();
    for (int i = 0; i < _menu.length; i++) {
      final catName = _menu[i].categoryName.trim().toLowerCase();
      if (catName == norm) {
        if (_menu[i].isAvailable != isAvailable) {
          _menu[i] = _menu[i].copyWith(isAvailable: isAvailable);
          modified = true;
        }
      }
    }
    if (modified) {
      rebuildIndexes();
      await saveState();
      notifyListeners();
    }
  }

  /// Bulk sets availability for all items across the entire menu.
  Future<void> setAllItemsAvailability(bool isAvailable) async {
    bool modified = false;
    for (int i = 0; i < _menu.length; i++) {
      if (_menu[i].isAvailable != isAvailable) {
        _menu[i] = _menu[i].copyWith(isAvailable: isAvailable);
        modified = true;
      }
    }
    if (modified) {
      rebuildIndexes();
      await saveState();
      notifyListeners();
    }
  }

  /// Bulk sets availability for a specific list of item IDs (e.g. currently filtered items).
  Future<void> setItemsAvailability(Iterable<String> itemIds, bool isAvailable) async {
    final targetIds = itemIds.toSet();
    if (targetIds.isEmpty) return;

    bool modified = false;
    for (int i = 0; i < _menu.length; i++) {
      if (targetIds.contains(_menu[i].id)) {
        if (_menu[i].isAvailable != isAvailable) {
          _menu[i] = _menu[i].copyWith(isAvailable: isAvailable);
          modified = true;
        }
      }
    }
    if (modified) {
      rebuildIndexes();
      await saveState();
      notifyListeners();
    }
  }

  /// Exports current categories and menu catalog to CSV file.
  Future<void> exportMenuToCsv({
    List<ItemCategory>? categories,
    String filename = 'menu_catalog.csv',
  }) async {
    await CsvExportService.exportMenuCatalog(
      categories: categories ?? categoryConfigs,
      items: _menu,
      filename: filename,
    );
  }

  /// Imports a complete menu catalog with both items and category configurations.
  Future<void> importMenuCatalog({
    required List<MenuItem> items,
    List<ItemCategory>? categories,
    bool replace = true,
  }) async {
    if (replace) {
      _menu = List.from(items);
      selectCategory('All');
      rebuildIndexes();
      if (categories != null && categories.isNotEmpty) {
        for (final cat in categories) {
          await saveCategoryConfig(cat);
        }
      }
    } else {
      _menu.addAll(items);
      rebuildIndexes();
      if (categories != null) {
        for (final cat in categories) {
          await saveCategoryConfig(cat);
        }
      }
    }

    invalidateCategoryColors();
    await syncCategoriesWithMenu(replace: replace);
    await saveState();
    notifyListeners();
  }

  /// Convenience method to import a full Menu & Catalog from CSV text.
  Future<MenuCatalogParseResult> importCatalogFromCsv(
    String csvContent, {
    bool replace = true,
  }) async {
    final result = CsvImportService.parseCsv(csvContent);
    if (result.hasItems || result.hasCategories) {
      await importMenuCatalog(
        items: result.items,
        categories: result.categories,
        replace: replace,
      );
    }
    return result;
  }

  /// Hook called when category config is updated to re-hydrate menu items.
  void handleCategoryUpdatedInMenu(ItemCategory config) {
    final normalized = config.name.trim().toLowerCase();
    for (int i = 0; i < _menu.length; i++) {
      if (_menu[i].categoryName.trim().toLowerCase() == normalized ||
          CartKeyParser.normalizeCategoryKey(_menu[i].categoryName) ==
              CartKeyParser.normalizeCategoryKey(config.name)) {
        _menu[i] = _menu[i].copyWith(
          category: config,
          colorHex: config.colorHex ?? _menu[i].colorHex,
        );
      }
    }
    rebuildIndexes();
  }

  /// Hook called when a category is renamed to update menu items.
  void handleCategoryRenamedInMenu(String oldName, String newName) {
    final oldNorm = oldName.trim().toLowerCase();
    for (int i = 0; i < _menu.length; i++) {
      final item = _menu[i];
      if (item.categoryName.trim().toLowerCase() == oldNorm) {
        _menu[i] = item.copyWith(
          category: item.category.copyWith(name: newName.trim()),
        );
      }
    }
    rebuildIndexes();
  }

  /// Hook called when a category is deleted to reassign or remove menu items.
  void handleCategoryDeletedInMenu(
    String categoryName, {
    required bool deleteItems,
  }) {
    final norm = categoryName.trim().toLowerCase();
    if (deleteItems) {
      _menu.removeWhere(
        (item) => item.categoryName.trim().toLowerCase() == norm,
      );
    } else {
      const generalCategory = ItemCategory(id: 'cat_general', name: 'General');
      for (int i = 0; i < _menu.length; i++) {
        if (_menu[i].categoryName.trim().toLowerCase() == norm) {
          _menu[i] = _menu[i].copyWith(category: generalCategory);
        }
      }
    }
    rebuildIndexes();
  }
}
