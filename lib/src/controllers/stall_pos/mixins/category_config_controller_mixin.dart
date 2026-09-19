import 'package:flutter/material.dart';
import '../../../models/stall_models.dart';
import 'cart_key_parser.dart';

/// Mixin managing category configurations, options, surcharges, color palettes,
/// and category selection for Stall POS.
mixin CategoryConfigControllerMixin on ChangeNotifier {
  List<ItemCategory> _categoryConfigs = [];
  Map<String, int>? _cachedCategoryColors;
  String _selectedCategory = 'All';

  /// Abstract requirement: list of menu items from [MenuCatalogControllerMixin].
  List<MenuItem> get rawMenu;

  /// Abstract requirement: persistence callback implemented by the host controller.
  Future<void> saveState();

  /// Abstract hooks to notify MenuCatalog when categories change.
  void handleCategoryUpdatedInMenu(ItemCategory config);
  void handleCategoryRenamedInMenu(String oldName, String newName);
  void handleCategoryDeletedInMenu(String categoryName, {required bool deleteItems});
  void rebuildMenuIndexes();

  /// Unmodifiable view of category configurations.
  List<ItemCategory> get categoryConfigs => List.unmodifiable(_categoryConfigs);

  /// Currently selected category filter chip in POS catalog.
  String get selectedCategory => _selectedCategory;

  /// Sets loaded category configurations from storage during initialization.
  @protected
  void setLoadedCategoryConfigs(List<ItemCategory> configs) {
    _categoryConfigs = List.from(configs);
    _invalidateCategoryColors();
  }

  /// Sets the selected category.
  void selectCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
    }
  }

  /// Normalizes category key using [CartKeyParser].
  static String normalizeCategoryKey(String cat) =>
      CartKeyParser.normalizeCategoryKey(cat);

  /// Returns cached or dynamically resolved category colors.
  Map<String, int> get resolvedCategoryColors {
    if (_cachedCategoryColors != null) return _cachedCategoryColors!;

    final result = <String, int>{};
    final usedColors = <int>{};
    final allCategories = categories.where((c) => c != 'All').toList();

    for (final cat in allCategories) {
      final normalized = cat.trim().toLowerCase();
      final config = _categoryConfigs.where((c) => c.matches(cat)).firstOrNull;
      if (config != null && config.colorHex != null) {
        result[cat] = config.colorHex!;
        usedColors.add(config.colorHex!);
        continue;
      }
      for (final m in rawMenu) {
        if (m.categoryName.trim().toLowerCase() == normalized && m.colorHex != null) {
          if (!usedColors.contains(m.colorHex!)) {
            result[cat] = m.colorHex!;
            usedColors.add(m.colorHex!);
            break;
          }
        }
      }
      if (!result.containsKey(cat)) {
        final uniqueColor = ItemCategory.getUniqueColor(
          categoryName: cat,
          usedColors: usedColors,
        );
        result[cat] = uniqueColor;
        usedColors.add(uniqueColor);
      }
    }

    _cachedCategoryColors = result;
    return result;
  }

  /// Returns the resolved [Color] for [category].
  Color getCategoryColor(String category, {Color? defaultColor}) {
    if (category == 'All') {
      return defaultColor ?? const Color(0xFF1D4ED8);
    }
    final hex = resolvedCategoryColors[category] ??
        ItemCategory.getColorForCategory(category);
    return Color(hex);
  }

  void _invalidateCategoryColors() {
    _cachedCategoryColors = null;
  }

  /// Invalidates cached category colors so next read re-resolves them.
  void invalidateCategoryColors() => _invalidateCategoryColors();

  /// Fast lookup map for category configs keyed by lowercase trimmed category name
  /// as well as slash-normalized category key.
  Map<String, ItemCategory> get categoryConfigMap {
    final map = <String, ItemCategory>{};
    for (final c in _categoryConfigs) {
      final rawKey = c.name.trim().toLowerCase();
      map[rawKey] = c;
      final normKey = normalizeCategoryKey(c.name);
      if (normKey.isNotEmpty && normKey != rawKey) {
        map[normKey] = c;
      }
    }
    return map;
  }

  /// Helper to lookup an ItemCategory config by either its exact or normalized name.
  ItemCategory? getCategoryConfig(String category) {
    final trimmed = category.trim().toLowerCase();
    if (trimmed.isEmpty || trimmed == 'all') return null;
    final norm = normalizeCategoryKey(category);
    return categoryConfigMap[norm] ?? categoryConfigMap[trimmed];
  }

  /// List of distinct categories present in the current menu and configuration.
  List<String> get categories {
    final set = <String>{'All'};
    for (final item in rawMenu) {
      if (item.categoryName.trim().isNotEmpty) {
        set.add(item.categoryName.trim());
      }
    }
    for (final config in _categoryConfigs) {
      if (config.name.trim().isNotEmpty) {
        set.add(config.name.trim());
      }
    }
    return set.toList();
  }

  /// Returns the additional cost configured for the given [category].
  /// Returns 0.0 if not configured, disabled, or <= 0.
  double getCategoryCost(String category) {
    final trimmed = category.trim().toLowerCase();
    if (trimmed.isEmpty || trimmed == 'all') return 0.0;
    final config = getCategoryConfig(category);
    if (config != null && config.isEnabled) {
      if (config.additionalCost > 0) {
        return config.additionalCost;
      }
    }
    for (final parent in _categoryConfigs) {
      if (!parent.isEnabled) continue;
      for (final opt in parent.effectiveOptions) {
        if (opt.isEnabled && opt.name.trim().toLowerCase() == trimmed) {
          if (opt.additionalCost > 0) return opt.additionalCost;
        }
      }
    }
    return 0.0;
  }

  /// Returns the label / reason for the category surcharge (e.g. "Packaging Fee" or "Fried").
  String? getCategoryCostReason(String category) {
    final trimmed = category.trim().toLowerCase();
    if (trimmed.isEmpty || trimmed == 'all') return null;
    final config = getCategoryConfig(category);
    if (config != null && config.isEnabled && config.additionalCost > 0) {
      return config.costReason;
    }
    for (final parent in _categoryConfigs) {
      if (!parent.isEnabled) continue;
      for (final opt in parent.effectiveOptions) {
        if (opt.isEnabled && opt.name.trim().toLowerCase() == trimmed && opt.additionalCost > 0) {
          return opt.name;
        }
      }
    }
    return null;
  }

  /// Resolves the additional cost for an option under a parent category
  /// (e.g., parent: "Steam / Fried / Pan Fried", option: "Fried").
  double getCategoryOptionCost(String parentCategory, String optionName) {
    final parent = _categoryConfigs.firstWhere(
      (c) =>
          c.name.trim().toLowerCase() == parentCategory.trim().toLowerCase() ||
          normalizeCategoryKey(c.name) == normalizeCategoryKey(parentCategory),
      orElse: () => ItemCategory(id: '', name: parentCategory),
    );
    return parent.getOptionCost(optionName);
  }

  /// Returns the category name (cleaned).
  String getCategoryDisplayName(String category) {
    return category.trim();
  }

  /// Resolves an [ItemCategory] by name, utilizing existing config if present or creating a default one.
  ItemCategory resolveItemCategory(String categoryName) {
    final trimmed = categoryName.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'general') {
      final config = getCategoryConfig('General');
      return config ?? ItemCategory.general;
    }
    final config = getCategoryConfig(trimmed);
    if (config != null) return config;
    return ItemCategory(
      id: 'cat_${trimmed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
      name: trimmed,
    );
  }

  /// Hydrates a [MenuItem] with the latest [ItemCategory] configuration from [_categoryConfigs].
  MenuItem hydrateMenuItemCategory(MenuItem item) {
    final latestConfig = getCategoryConfig(item.categoryName);
    if (latestConfig != null) {
      return item.copyWith(category: latestConfig);
    }
    return item;
  }

  /// Updates the additional cost, optional reason, and active toggle for a category.
  Future<void> updateCategoryCost({
    required String categoryName,
    required double additionalCost,
    String? reason,
    bool? isEnabled,
  }) async {
    final normalized = categoryName.trim().toLowerCase();
    final idx = _categoryConfigs.indexWhere(
      (c) => c.name.trim().toLowerCase() == normalized,
    );
    if (idx != -1) {
      _categoryConfigs[idx] = _categoryConfigs[idx].copyWith(
        additionalCost: additionalCost,
        costReason: reason,
        clearCostReason: reason == null || reason.trim().isEmpty,
        isEnabled: isEnabled ?? _categoryConfigs[idx].isEnabled,
      );
    } else {
      _categoryConfigs.add(ItemCategory(
        id: 'cat_${normalized.replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
        name: categoryName.trim(),
        additionalCost: additionalCost,
        costReason: reason,
        isEnabled: isEnabled ?? true,
      ));
    }
    await saveState();
    notifyListeners();
  }

  /// Updates the additional cost for a specific category option/variant
  /// (e.g. parent: "Momos" or "Steam / Fried / Pan Fried", option: "Fried", cost: 10.0).
  Future<void> updateCategoryOptionCost({
    required String parentCategory,
    required String optionName,
    required double additionalCost,
  }) async {
    final normalized = parentCategory.trim().toLowerCase();
    final idx = _categoryConfigs.indexWhere(
      (c) => c.name.trim().toLowerCase() == normalized,
    );
    if (idx != -1) {
      final parent = _categoryConfigs[idx];
      final currentOptions = List<CategoryOption>.from(parent.effectiveOptions);
      final optIdx = currentOptions.indexWhere(
        (o) => o.name.trim().toLowerCase() == optionName.trim().toLowerCase(),
      );
      if (optIdx != -1) {
        currentOptions[optIdx] = currentOptions[optIdx].copyWith(additionalCost: additionalCost);
      } else {
        currentOptions.add(CategoryOption(
          id: 'opt_${optionName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
          name: optionName.trim(),
          additionalCost: additionalCost,
        ));
      }
      final updated = parent.copyWith(options: currentOptions);
      _categoryConfigs[idx] = updated;
      await saveCategoryConfig(updated);
    } else {
      await saveCategoryConfig(ItemCategory(
        id: 'cat_${normalized.replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
        name: parentCategory.trim(),
        options: [
          CategoryOption(
            id: 'opt_${optionName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
            name: optionName.trim(),
            additionalCost: additionalCost,
          ),
        ],
      ));
    }
  }

  /// Alias for [saveCategoryConfig].
  Future<void> updateCategoryConfig(ItemCategory config) => saveCategoryConfig(config);

  /// Saves or updates a category's configuration and persists it.
  Future<void> saveCategoryConfig(ItemCategory config) async {
    final normalized = config.name.trim().toLowerCase();
    final idx = _categoryConfigs.indexWhere(
      (c) => c.name.trim().toLowerCase() == normalized,
    );
    if (idx != -1) {
      _categoryConfigs[idx] = config;
    } else {
      _categoryConfigs.add(config);
    }

    handleCategoryUpdatedInMenu(config);

    _invalidateCategoryColors();
    await saveState();
    notifyListeners();
  }

  /// Deletes a category by name.
  /// If [deleteItems] is true, removes all items in this category from the menu.
  /// If [deleteItems] is false, safely reassigns all items in this category to 'General'.
  Future<void> deleteCategory(String categoryName, {bool deleteItems = false}) async {
    final norm = categoryName.trim().toLowerCase();
    if (norm.isEmpty || norm == 'all') return;

    _categoryConfigs.removeWhere((c) => c.name.trim().toLowerCase() == norm);
    handleCategoryDeletedInMenu(categoryName, deleteItems: deleteItems);

    if (_selectedCategory.trim().toLowerCase() == norm) {
      _selectedCategory = 'All';
    }

    _invalidateCategoryColors();
    await saveState();
    notifyListeners();
  }

  /// Renames an existing category from [oldName] to [newName] across the entire system.
  Future<void> renameCategory(String oldName, String newName) async {
    final oldTrimmed = oldName.trim();
    final newTrimmed = newName.trim();
    if (oldTrimmed.isEmpty ||
        newTrimmed.isEmpty ||
        oldTrimmed.toLowerCase() == newTrimmed.toLowerCase()) {
      return;
    }

    final oldNorm = oldTrimmed.toLowerCase();
    final configIdx = _categoryConfigs.indexWhere(
      (c) => c.name.trim().toLowerCase() == oldNorm,
    );
    if (configIdx != -1) {
      _categoryConfigs[configIdx] =
          _categoryConfigs[configIdx].copyWith(name: newTrimmed);
    } else {
      _categoryConfigs.add(ItemCategory(
        id: 'cat_${newTrimmed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
        name: newTrimmed,
      ));
    }

    handleCategoryRenamedInMenu(oldName, newName);

    if (_selectedCategory.trim().toLowerCase() == oldNorm) {
      _selectedCategory = newTrimmed;
    }

    _invalidateCategoryColors();
    await saveState();
    notifyListeners();
  }

  /// Automatically synchronizes category configurations with all categories present in the menu.
  Future<void> syncCategoriesWithMenu({bool replace = false}) async {
    final existingMap = {
      for (int i = 0; i < _categoryConfigs.length; i++)
        _categoryConfigs[i].name.trim().toLowerCase(): i,
    };
    bool modified = false;

    for (final item in rawMenu) {
      final rawCat = item.categoryName.trim();
      if (rawCat.isEmpty || rawCat.toLowerCase() == 'all') continue;

      final key = rawCat.toLowerCase();
      final normKey = normalizeCategoryKey(rawCat);
      final itemOptions = item.category.options;
      final itemAddCost = item.category.additionalCost;
      final itemAddons = item.category.addons;

      final existingIdx = existingMap[key] ?? existingMap[normKey];

      if (existingIdx == null) {
        final newCat = ItemCategory(
          id: item.category.id.isNotEmpty
              ? item.category.id
              : 'cat_${key.replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
          name: rawCat,
          additionalCost: itemAddCost,
          colorHex: item.colorHex,
          options: itemOptions,
          addons: itemAddons,
        );
        _categoryConfigs.add(newCat);
        existingMap[key] = _categoryConfigs.length - 1;
        existingMap[normKey] = _categoryConfigs.length - 1;
        modified = true;
      } else {
        final current = _categoryConfigs[existingIdx];
        var updated = current;
        bool catChanged = false;

        if (itemOptions.isNotEmpty && current.options.isEmpty) {
          updated = updated.copyWith(options: itemOptions);
          catChanged = true;
        } else if (itemOptions.isNotEmpty && current.options.isNotEmpty) {
          final currentOptMap = {
            for (final o in current.options) o.name.trim().toLowerCase(): o,
          };
          bool optionsEnriched = false;
          final mergedOptions = List<CategoryOption>.from(current.options);
          for (final incOpt in itemOptions) {
            final oKey = incOpt.name.trim().toLowerCase();
            if (!currentOptMap.containsKey(oKey)) {
              mergedOptions.add(incOpt);
              optionsEnriched = true;
            } else {
              final existingOpt = currentOptMap[oKey]!;
              if (existingOpt.additionalCost == 0 && incOpt.additionalCost != 0) {
                final idx = mergedOptions.indexWhere(
                  (o) => o.name.trim().toLowerCase() == oKey,
                );
                if (idx != -1) {
                  mergedOptions[idx] = existingOpt.copyWith(
                    additionalCost: incOpt.additionalCost,
                    price: incOpt.price ?? existingOpt.price,
                  );
                  optionsEnriched = true;
                }
              }
            }
          }
          if (optionsEnriched) {
            updated = updated.copyWith(options: mergedOptions);
            catChanged = true;
          }
        }

        if (itemAddons.isNotEmpty && current.addons.isEmpty) {
          updated = updated.copyWith(addons: itemAddons);
          catChanged = true;
        } else if (itemAddons.isNotEmpty && current.addons.isNotEmpty) {
          final currentAddonMap = {
            for (final a in current.addons) a.name.trim().toLowerCase(): a,
          };
          bool addonsEnriched = false;
          final mergedAddons = List<CategoryOption>.from(current.addons);
          for (final incAddon in itemAddons) {
            final aKey = incAddon.name.trim().toLowerCase();
            if (!currentAddonMap.containsKey(aKey)) {
              mergedAddons.add(incAddon);
              addonsEnriched = true;
            }
          }
          if (addonsEnriched) {
            updated = updated.copyWith(addons: mergedAddons);
            catChanged = true;
          }
        }

        if (current.additionalCost == 0 && itemAddCost > 0) {
          updated = updated.copyWith(additionalCost: itemAddCost);
          catChanged = true;
        }

        if (current.colorHex == null && item.colorHex != null) {
          updated = updated.copyWith(colorHex: item.colorHex);
          catChanged = true;
        }

        if (catChanged) {
          _categoryConfigs[existingIdx] = updated;
          modified = true;
        }
      }
    }

    if (modified) {
      _invalidateCategoryColors();
      await saveState();
    }
  }
}
