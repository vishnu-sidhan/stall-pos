import 'package:flutter/material.dart';
import '../data/helpers/composite_item_helper.dart';
import '../data/models/stall_models.dart';
import '../data/storage/stall_storage.dart';
import '../data/storage/app_storage.dart';
import '../theme/category_colors.dart';

/// State controller for Stall POS operations:
/// managing menu catalog, active cart, orders queue, in-place order editing,
/// deletion, and reactive aggregated kitchen preparations.
class OrderController extends ChangeNotifier {
  final StallStorage _storageService;
  Map<String, int>? _cachedCategoryColors;

  static const List<String> defaultPredefinedNotes = [
    'Parcel',
    'Less Spicy',
    'Extra Spicy',
    'No Onion/Garlic',
    'Pack Separately',
  ];

  List<MenuItem> _menu = [];
  List<StallOrder> _orders = [];
  List<ItemCategory> _categoryConfigs = [];
  List<String> _predefinedNotes = List.from(defaultPredefinedNotes);
  final Map<String, int> _cart = {}; // menuItem.id -> quantity
  int _nextToken = 1;
  int? _editingOrderId;
  String _selectedCategory = 'All';
  bool _isLoading = true;

  OrderController({StallStorage? storageService})
      : _storageService = storageService ?? AppStorage.instance.stallStorage;

  // ---------------------------------------------------------------------------
  // GETTERS
  // ---------------------------------------------------------------------------

  bool get isLoading => _isLoading;
  List<MenuItem> get menu => List.unmodifiable(_menu);
  List<MenuItem> get availableMenu =>
      List.unmodifiable(_menu.where((m) => m.isEffectivelyAvailable));
  List<StallOrder> get orders => List.unmodifiable(_orders);
  List<ItemCategory> get categoryConfigs => List.unmodifiable(_categoryConfigs);
  List<String> get predefinedNotes => List.unmodifiable(_predefinedNotes);
  Map<String, int> get cart => Map.unmodifiable(_cart);
  int get nextToken => _nextToken;
  int? get editingOrderId => _editingOrderId;
  bool get isEditing => _editingOrderId != null;
  StallOrder? get editingOrder =>
      _editingOrderId != null ? _orders.where((o) => o.token == _editingOrderId).firstOrNull : null;
  String get selectedCategory => _selectedCategory;
  StallStorage get storageService => _storageService;

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
      for (final m in _menu) {
        if (m.categoryName.trim().toLowerCase() == normalized && m.colorHex != null) {
          if (!usedColors.contains(m.colorHex!)) {
            result[cat] = m.colorHex!;
            usedColors.add(m.colorHex!);
            break;
          }
        }
      }
    }

    for (final cat in allCategories) {
      if (!result.containsKey(cat)) {
        final uniqueColor = CategoryColorHelper.getUniqueColor(
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
        CategoryColorHelper.getColorForCategory(category);
    return Color(hex);
  }

  void _invalidateCategoryColors() {
    _cachedCategoryColors = null;
  }

  /// Adds a custom predefined note to the quick list and persists it.
  Future<void> addPredefinedNote(String note) async {
    final trimmed = note.trim();
    if (trimmed.isEmpty) return;
    if (!_predefinedNotes.any((n) => n.toLowerCase() == trimmed.toLowerCase())) {
      _predefinedNotes.add(trimmed);
      await _storageService.savePredefinedNotes(_predefinedNotes);
      notifyListeners();
    }
  }

  /// Removes a predefined note from the quick list and persists the update.
  Future<void> removePredefinedNote(String note) async {
    final trimmed = note.trim();
    _predefinedNotes.removeWhere((n) => n.toLowerCase() == trimmed.toLowerCase());
    await _storageService.savePredefinedNotes(_predefinedNotes);
    notifyListeners();
  }

  /// Resets predefined quick notes to system defaults.
  Future<void> resetPredefinedNotes() async {
    _predefinedNotes = List.from(defaultPredefinedNotes);
    await _storageService.savePredefinedNotes(_predefinedNotes);
    notifyListeners();
  }

  /// Normalizes category key by trimming segments around '/' slashes to prevent whitespace discrepancies
  /// (e.g. 'Momos /  Fried Momos' -> 'momos / fried momos').
  static String normalizeCategoryKey(String cat) {
    final trimmed = cat.trim().toLowerCase();
    if (trimmed.isEmpty) return '';
    if (!trimmed.contains('/')) return trimmed;
    return trimmed
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(' / ');
  }

  /// Fast lookup map for category configs keyed by lowercase trimmed category name
  /// as well as slash-normalized category key.
  Map<String, ItemCategory> get categoryConfigMap {
    final map = <String, ItemCategory>{};
    for (final c in _categoryConfigs) {
      final rawKey = c.name.trim().toLowerCase();
      final normKey = normalizeCategoryKey(c.name);
      map[rawKey] = c;
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
    // Also check if [category] is an option/variant under any category config
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
  MenuItem _hydrateMenuItemCategory(MenuItem item) {
    final latestConfig = getCategoryConfig(item.categoryName);
    if (latestConfig != null && latestConfig != item.category) {
      return item.copyWith(category: latestConfig);
    }
    return item;
  }


  /// Returns only the items/quantities that have been paid for in the given order.
  /// If an item contains add-ons (composite key with '+'), it is only considered confirmed
  /// if the exact linked item was paid for. If an add-on was added to an item, the linked
  /// item moves to pending and is excluded from confirmed items.
  Map<String, int> getConfirmedOrderItems(StallOrder order) {
    if (order.isPaid) {
      return Map.unmodifiable(order.items);
    }
    if (order.paidItems.isEmpty || order.paidAmount <= 0) {
      return const {};
    }

    final confirmed = <String, int>{};
    for (final entry in order.items.entries) {
      final itemId = entry.key;
      final totalQty = entry.value;
      if (totalQty <= 0) continue;

      final paidQty = order.paidItems[itemId] ?? 0;
      if (paidQty > 0) {
        final qty = paidQty > totalQty ? totalQty : paidQty;
        confirmed[itemId] = qty;
      }
    }
    return Map.unmodifiable(confirmed);
  }

  /// Returns only the items/quantities that have NOT yet been paid for in the given order.
  /// If an item contains add-ons that were added without being fully paid,
  /// the entire linked item moves to pending.
  Map<String, int> getPendingOrderItems(StallOrder order) {
    if (order.isPaid) {
      return const {};
    }
    if (order.paidItems.isEmpty || order.paidAmount <= 0) {
      return Map.unmodifiable(order.items);
    }

    final pending = <String, int>{};
    for (final entry in order.items.entries) {
      final itemId = entry.key;
      final totalQty = entry.value;
      if (totalQty <= 0) continue;

      final paidQty = order.paidItems[itemId] ?? 0;
      final unpaidQty = totalQty - paidQty;
      if (unpaidQty > 0) {
        pending[itemId] = unpaidQty;
      }
    }
    return Map.unmodifiable(pending);
  }

  /// Returns all active (non-completed) orders in FIFO order.
  List<StallOrder> get activeOrders =>
      _orders.where((o) => !o.isCompleted).toList();

  /// Returns active orders that have confirmed (paid) items.
  List<StallOrder> get confirmedActiveOrders =>
      activeOrders.where((o) => o.isPaid || getConfirmedOrderItems(o).isNotEmpty).toList();

  /// Returns active orders that have pending (unpaid) items to confirm payment.
  List<StallOrder> get toConfirmPaymentOrders =>
      activeOrders.where((o) => !o.isPaid && getPendingOrderItems(o).isNotEmpty).toList();

  /// Maximum number of items of a specific add-on (or add-on variant) allowed per base item.
  static const int maxPerAddonItem = 2;
  static const int maxAddonsPerItem = maxPerAddonItem;

  /// Returns the total number of add-ons currently attached to a cart item key.
  int getAddonCount(String cartItemId) {
    if (!cartItemId.contains('+')) return 0;
    final parts = cartItemId.split('+');
    return parts.length - 1;
  }

  /// Returns the count of a specific add-on (or specific variant of an add-on)
  /// currently attached to a cart item key.
  int getAddonItemCount(
    String cartItemId,
    String addonId, {
    String? resolvedAddonName,
  }) {
    if (!cartItemId.contains('+')) return 0;

    final targetVar = (resolvedAddonName != null && resolvedAddonName.trim().isNotEmpty)
        ? resolvedAddonName.trim()
        : null;

    final breakdown = getCartItemBreakdown(cartItemId);
    if (breakdown != null && targetVar != null) {
      for (final d in breakdown.addonDetails) {
        if (d.name.toLowerCase().trim() == targetVar.toLowerCase().trim()) {
          return d.count;
        }
      }
    }

    final tokens = cartItemId.split('+').sublist(1);
    int count = 0;
    for (final token in tokens) {
      if (targetVar != null) {
        final expectedPrefix = '${addonId}_var_$targetVar';
        if (token == expectedPrefix ||
            token.startsWith('${expectedPrefix}_cat_') ||
            token == targetVar) {
          count++;
        }
      } else {
        if (token == addonId ||
            token.startsWith('${addonId}_cat_') ||
            token.startsWith('${addonId}_var_')) {
          count++;
        }
      }
    }
    return count;
  }

  /// Returns all menu add-ons applicable to the given [category].
  List<MenuItem> getAddonsForCategory(String category, {bool onlyAvailable = true}) {
    return _menu
        .where((m) => (!onlyAvailable || m.isAvailable) && m.effectiveIsAddon && m.isApplicableToCategory(category))
        .toList();
  }

  /// Whether there are any add-ons available for the given [category].
  bool hasAddonsForCategory(String category, {bool onlyAvailable = true}) {
    return _menu
        .any((m) => (!onlyAvailable || m.isAvailable) && m.effectiveIsAddon && m.isApplicableToCategory(category));
  }

  /// Checks if the specified add-on can be added to the cart item without exceeding maxPerAddonItem
  /// and verifying that it is applicable to the target item's category.
  bool canAddAddonItem(
    String cartItemId,
    MenuItem addon, {
    String? resolvedAddonName,
    int countToAdd = 1,
  }) {
    final targetItem = findItem(cartItemId);
    if (!addon.isApplicableToCategory(targetItem.categoryName)) {
      return false;
    }
    final current = getAddonItemCount(
      cartItemId,
      addon.id,
      resolvedAddonName: resolvedAddonName,
    );
    return current + countToAdd <= maxPerAddonItem;
  }

  /// Checks if any available add-on for the cart item's category can still be added to the cart item.
  bool canAddAnyAddon(String cartItemId) {
    final targetItem = findItem(cartItemId);
    final availableAddons = getAddonsForCategory(targetItem.categoryName);
    if (availableAddons.isEmpty) return false;

    for (final addon in availableAddons) {
      if (addon.hasSlashNameVariants) {
        for (final v in addon.slashNameVariants) {
          if (getAddonItemCount(cartItemId, addon.id, resolvedAddonName: v) < maxPerAddonItem) {
            return true;
          }
        }
      } else {
        if (getAddonItemCount(cartItemId, addon.id) < maxPerAddonItem) {
          return true;
        }
      }
    }
    return false;
  }

  /// Checks if more add-ons can be linked to the specified cart item.
  bool canAddAddon(String cartItemId, [int countToAdd = 1]) {
    return canAddAnyAddon(cartItemId);
  }

  /// Total count of items in the current active cart.
  int get cartItemCount => _cart.values.fold(0, (a, b) => a + b);

  /// Resolves the underlying base item (pure catalog MenuItem with its base price),
  /// Resolves the base [MenuItem] for a given item key,
  /// taking into account any variant or category customizations.
  MenuItem _resolveBaseItem(String baseId) {
    // 1. Direct match in menu
    for (final m in _menu) {
      if (m.id == baseId) return m;
    }

    // 2. Customized variant / category item (e.g. itemId_var_option or itemId_cat_Rice)
    if (baseId.contains('_var_') || baseId.contains('_cat_')) {
      final parsed = CompositeItemHelper.parseKeyParts(baseId);
      final rawBase = _resolveBaseItem(parsed.baseId);
      final rawCat = parsed.category != null
          ? resolveItemCategory(parsed.category!)
          : rawBase.category;
      final resolvedName = parsed.variant;

      CategoryOption? matchedVariant;
      if (resolvedName != null && rawBase.variants.isNotEmpty) {
        final normalizedTarget = resolvedName.trim().toLowerCase();
        for (final v in rawBase.variants) {
          if (v.name.trim().toLowerCase() == normalizedTarget) {
            matchedVariant = v;
            break;
          }
        }
      }

      final effectivePrice = rawBase.priceForVariant(matchedVariant);
      final effectiveName = (resolvedName != null && rawBase.hasSlashNameVariants)
          ? resolvedName
          : rawBase.name;
      final effectiveDietary = matchedVariant?.dietaryType ?? rawBase.dietaryType;

      return MenuItem(
        id: baseId,
        name: effectiveName,
        price: effectivePrice,
        category: rawCat,
        colorHex: rawBase.colorHex,
        isAddon: rawBase.isAddon,
        variants: rawBase.variants,
        dietaryType: effectiveDietary,
      );
    }

    return MenuItem(
      id: baseId,
      name: baseId.isNotEmpty ? baseId : 'Item',
      price: 0.0,
      category: resolveItemCategory('General'),
    );
  }

  /// Returns a breakdown of base item, category additional cost, and add-ons for a cart item key.
  /// Returns null if the item has no linked add-ons and no category surcharge.
  CartItemBreakdown? getCartItemBreakdown(String itemId) {
    final compositeIndex = itemId.indexOf('+');
    final baseId = compositeIndex != -1 ? itemId.substring(0, compositeIndex) : itemId;
    final baseItem = _resolveBaseItem(baseId);
    final categoryAdditionalCost =
        !baseItem.effectiveIsAddon ? getCategoryCost(baseItem.categoryName) : 0.0;
    final categoryCostReason =
        !baseItem.effectiveIsAddon ? getCategoryCostReason(baseItem.categoryName) : null;

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
        final addon = _resolveBaseItem(entry.key);
        final singlePrice = addon.price;
        final totalAddonPrice = singlePrice * entry.value;
        addonsPrice += totalAddonPrice;
        addonDetails.add((
          name: addon.name,
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
  ///
  /// Any active category additional cost configured for the item's category is included.
  MenuItem findItem(String itemId) {
    final compositeIndex = itemId.indexOf('+');

    // 1. Composite items with add-ons (e.g. "baseItemId+addonId1")
    if (compositeIndex != -1) {
      final breakdown = getCartItemBreakdown(itemId);
      if (breakdown != null) {
        final prefix = breakdown.addonDetails.map((entry) {
          final name = entry.name;
          final count = entry.count;
          return count > 1 ? '[$count' 'x $name]' : '[$name]';
        }).join(' ');

        return MenuItem(
          id: itemId,
          name: '$prefix ${breakdown.baseItem.name}'.trim(),
          price: breakdown.totalUnitPrice,
          category: breakdown.baseItem.category,
          colorHex: breakdown.baseItem.colorHex,
          isAddon: false,
        );
      }
    }

    // 2. Customized variant / category items (e.g. "item_chai_var_Tea", "item_rice_cat_Rice", or "item_123_var_Fried Rice_cat_Rice")
    if (itemId.contains('_var_') || itemId.contains('_cat_')) {
      final baseItem = _resolveBaseItem(itemId);
      final catCost = !baseItem.effectiveIsAddon ? getCategoryCost(baseItem.categoryName) : 0.0;
      return MenuItem(
        id: itemId,
        name: baseItem.name,
        price: baseItem.price + catCost,
        category: baseItem.category,
        colorHex: baseItem.colorHex,
        isAddon: baseItem.isAddon,
      );
    }

    // 3. Direct match in menu
    for (final m in _menu) {
      if (m.id == itemId) {
        final hydrated = _hydrateMenuItemCategory(m);
        final catCost = !hydrated.effectiveIsAddon ? getCategoryCost(hydrated.categoryName) : 0.0;
        return catCost > 0 ? hydrated.copyWith(price: hydrated.price + catCost) : hydrated;
      }
    }

    return MenuItem(
      id: itemId,
      name: itemId.isNotEmpty ? itemId : 'Item',
      price: 0.0,
      category: resolveItemCategory('General'),
    );
  }

  /// Computes the total monetary price of items in the cart.
  double get cartTotal {
    double total = 0.0;
    _cart.forEach((itemId, qty) {
      final item = findItem(itemId);
      total += item.price * qty;
    });
    return total;
  }

  /// Total cost of base items in the cart (excluding category surcharges and add-on surcharges).
  double get cartBaseItemsTotal {
    double total = 0.0;
    _cart.forEach((itemId, qty) {
      final breakdown = getCartItemBreakdown(itemId);
      if (breakdown != null) {
        total += breakdown.basePrice * qty;
      } else {
        final item = findItem(itemId);
        total += item.price * qty;
      }
    });
    return total;
  }

  /// Total cost of category additional fees / packaging surcharges in the cart.
  double get cartCategoryCostsTotal {
    double total = 0.0;
    _cart.forEach((itemId, qty) {
      final breakdown = getCartItemBreakdown(itemId);
      if (breakdown != null) {
        total += breakdown.categoryAdditionalCost * qty;
      }
    });
    return total;
  }

  /// Total cost of add-ons in the cart.
  double get cartAddonsTotal {
    double total = 0.0;
    _cart.forEach((itemId, qty) {
      final breakdown = getCartItemBreakdown(itemId);
      if (breakdown != null) {
        total += breakdown.addonsPrice * qty;
      }
    });
    return total;
  }

  /// List of distinct categories present in the current menu and configuration.
  List<String> get categories {
    final set = <String>{'All'};
    for (final item in _menu) {
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

  /// Filtered menu of items available for today based on selected category chip.
  List<MenuItem> get filteredMenu {
    final list = _selectedCategory == 'All'
        ? _menu.where((m) => m.isEffectivelyAvailable).toList()
        : _menu
            .where((m) =>
                m.isEffectivelyAvailable &&
                m.categoryName.trim().toLowerCase() == _selectedCategory.toLowerCase())
            .toList();
    return list.map(_hydrateMenuItemCategory).toList();
  }

  /// All menu items including unavailable ones, filtered by category.
  List<MenuItem> get allFilteredMenu {
    final list = _selectedCategory == 'All'
        ? _menu
        : _menu
            .where((m) =>
                m.categoryName.trim().toLowerCase() == _selectedCategory.toLowerCase())
            .toList();
    return list.map(_hydrateMenuItemCategory).toList();
  }

  /// Menu items available for today grouped by category for POS accordion rendering.
  Map<String, List<MenuItem>> get groupedMenu {
    final map = <String, List<MenuItem>>{};
    final items = filteredMenu;
    for (final item in items) {
      final cat =
          item.categoryName.trim().isEmpty ? 'General' : item.categoryName.trim();
      map.putIfAbsent(cat, () => []).add(item);
    }
    return map;
  }

  /// All menu items grouped by category (for daily menu availability management).
  Map<String, List<MenuItem>> get allGroupedMenu {
    final map = <String, List<MenuItem>>{};
    for (final item in _menu) {
      final cat =
          item.categoryName.trim().isEmpty ? 'General' : item.categoryName.trim();
      map.putIfAbsent(cat, () => []).add(_hydrateMenuItemCategory(item));
    }
    return map;
  }

  /// Formats an item's display name for Active Orders and Item Summary,
  /// dynamically displaying the item name and selected variant / option in brackets
  /// (e.g. "Chicken (Kurkure Momos)", "Gobi (Noodles)"),
  /// or the category name in brackets if no variant exists (e.g. "Chicken Manchuria (Starters)").
  static String formatOrderLineItemDisplayName({
    required String rawName,
    required String itemId,
    String? category,
    String? baseItemName,
  }) {
    var result = rawName.trim();

    // 1. Extract any add-on prefixes like "[Schezwan]" or "[2x Schezwan]"
    String addonPrefix = '';
    final addonMatch = RegExp(r'^(\[[^\]]+\]\s*)+').firstMatch(result);
    if (addonMatch != null) {
      addonPrefix = addonMatch.group(0)!;
      result = result.substring(addonPrefix.length).trim();
    }

    // 2. Parse variant and category segments from itemId
    final catVariant = CompositeItemHelper.parseCategory(itemId);
    final varVariant = CompositeItemHelper.parseVariant(itemId);

    // 3. Strip any category suffix already in brackets from rawName
    // (e.g. "Chicken (Rolls)" -> "Chicken", "Veg (Steam Momos / Fried Momos / ...)" -> "Veg")
    final bracketMatch = RegExp(r'\s*\(([^)]+)\)$').firstMatch(result);
    if (bracketMatch != null) {
      final inside = bracketMatch.group(1)!.trim();
      final catNorm = category?.trim().toLowerCase();
      final insideNorm = inside.toLowerCase();
      if (inside.contains('/') ||
          (catNorm != null && insideNorm == catNorm) ||
          (catVariant != null && insideNorm == catVariant.trim().toLowerCase()) ||
          insideNorm == 'all') {
        result = result.substring(0, bracketMatch.start).trim();
      }
    }

    // 4. Resolve the base item name
    String itemName = result;
    if (baseItemName != null && baseItemName.trim().isNotEmpty) {
      var cleanBase = baseItemName.trim();
      final baseAddonMatch = RegExp(r'^(\[[^\]]+\]\s*)+').firstMatch(cleanBase);
      if (baseAddonMatch != null) {
        cleanBase = cleanBase.substring(baseAddonMatch.group(0)!.length).trim();
      }
      final baseBracketMatch = RegExp(r'\s*\(([^)]+)\)$').firstMatch(cleanBase);
      if (baseBracketMatch != null) {
        final inside = baseBracketMatch.group(1)!.trim();
        final catNorm = category?.trim().toLowerCase();
        if (inside.contains('/') || (catNorm != null && inside.toLowerCase() == catNorm)) {
          cleanBase = cleanBase.substring(0, baseBracketMatch.start).trim();
        }
      }
      if (cleanBase.isNotEmpty) {
        itemName = cleanBase;
      }
    }

    // If itemName contains slashes (slash-name item e.g. "Chilli / Paneer 65")
    // and a variant was selected, the selected variant is the true item name:
    if (itemName.contains('/') && varVariant != null && varVariant.trim().isNotEmpty) {
      itemName = varVariant.trim();
    }

    // 5. Determine the active variant/option
    String? selectedOption;
    if (varVariant != null && varVariant.trim().isNotEmpty) {
      final trimmedVar = varVariant.trim();
      // Only treat varVariant as a sub-option if it's not identical to itemName
      if (trimmedVar.toLowerCase() != itemName.toLowerCase()) {
        selectedOption = trimmedVar;
      }
    } else if (catVariant != null &&
        catVariant.trim().isNotEmpty &&
        !catVariant.contains('/')) {
      final trimmedCat = catVariant.trim();
      // Only treat catVariant as a sub-option if it differs from the main category
      if (category == null || trimmedCat.toLowerCase() != category.trim().toLowerCase()) {
        selectedOption = trimmedCat;
      }
    }

    // 6. Format the display string dynamically
    String? bracketContent;

    if (selectedOption != null && selectedOption.isNotEmpty) {
      // If the base item already embeds the category name (e.g. itemName: "Kurkure Momos")
      // and selectedOption is the filling/flavor (e.g. "Chicken"), display "$selectedOption ($itemName)"
      final catKey = category?.trim().toLowerCase();
      final itemLower = itemName.toLowerCase();
      final optLower = selectedOption.toLowerCase();

      if (catKey != null &&
          catKey.isNotEmpty &&
          itemLower.contains(catKey) &&
          !optLower.contains(catKey)) {
        return '$addonPrefix$selectedOption ($itemName)'.trim();
      }

      bracketContent = selectedOption;
    } else if (category != null && category.trim().isNotEmpty && !category.contains('/')) {
      bracketContent = category.trim();
    }

    if (bracketContent != null && bracketContent.isNotEmpty) {
      return '$addonPrefix$itemName ($bracketContent)'.trim();
    }

    return '$addonPrefix$itemName'.trim();
  }

  /// Consolidated items view across all active orders with confirmed payment.
  /// Aggregates total quantities per item and tracks ticket tags.
  /// Custom composite items with add-ons remain separate entries.
  List<AggregatedOrderItem> get combinedActiveOrders {
    // Filter to active orders that have confirmed items
    final eligibleOrders = _orders
        .where((o) => !o.isCompleted && (o.isPaid || getConfirmedOrderItems(o).isNotEmpty))
        .toList();
    if (eligibleOrders.isEmpty) return const [];

    // Map: ItemKey -> Aggregated details
    final Map<String, _ItemAccumulator> accumulators = {};

    for (final order in eligibleOrders) {
      // Use getConfirmedOrderItems so only items with confirmed payment are aggregated
      final itemsToAggregate = getConfirmedOrderItems(order);
      if (itemsToAggregate.isNotEmpty) {
        // Structured items map available
        itemsToAggregate.forEach((itemId, qty) {
          if (qty <= 0) return;
          final completedQty = order.completedItems[itemId] ?? 0;
          final remainingQty = qty - completedQty;
          if (remainingQty <= 0) return;
          final item = findItem(itemId);
          final snapshot = order.itemSnapshots[itemId];
          final rawName = snapshot?['name']?.toString() ?? item.name;
          final category = snapshot?['category']?.toString() ?? item.categoryName;
          final formattedName = formatOrderLineItemDisplayName(
            rawName: rawName,
            itemId: itemId,
            category: category,
            baseItemName: item.name,
          );

          final acc = accumulators.putIfAbsent(
            item.id.isNotEmpty ? item.id : formattedName,
            () => _ItemAccumulator(
              itemId: item.id,
              rawName: rawName,
              name: formattedName,
              category: category,
              colorHex: item.colorHex,
              dietaryType: item.effectiveDietaryType,
            ),
          );
          acc.totalQty += remainingQty;
          acc.tickets.add(
            (
              token: order.token,
              quantity: remainingQty,
              isParcel: order.isParcel,
              orderNotes: order.orderNotes,
            ),
          );
        });
      } else if (order.isPaid && order.itemsSummary.isNotEmpty) {
        // Fallback parser for legacy or raw summaries: e.g. "3x Masala Chai, 2x Veg Samosa"
        final parts = order.itemsSummary.split(',');
        final regex = RegExp(r'^\s*(\d+)x\s+(.+)$');
        for (final rawPart in parts) {
          final match = regex.firstMatch(rawPart.trim());
          if (match != null) {
            final qty = int.tryParse(match.group(1) ?? '1') ?? 1;
            final name = match.group(2)?.trim() ?? rawPart.trim();
            final matchedItem = _menu.firstWhere(
              (m) => m.name.toLowerCase() == name.toLowerCase(),
              orElse: () => MenuItem(
                id: name,
                name: name,
                price: 0,
                category: resolveItemCategory('General'),
              ),
            );

            final formattedName = formatOrderLineItemDisplayName(
              rawName: name,
              itemId: matchedItem.id,
              category: matchedItem.categoryName,
            );

            final acc = accumulators.putIfAbsent(
              matchedItem.id.isNotEmpty ? matchedItem.id : formattedName,
              () => _ItemAccumulator(
                itemId: matchedItem.id,
                rawName: matchedItem.name,
                name: formattedName,
                category: matchedItem.categoryName,
                colorHex: matchedItem.colorHex,
                dietaryType: matchedItem.effectiveDietaryType,
              ),
            );
            acc.totalQty += qty;
            acc.tickets.add(
              (
                token: order.token,
                quantity: qty,
                isParcel: order.isParcel,
                orderNotes: order.orderNotes,
              ),
            );
          }
        }
      }
    }

    final result = accumulators.values.map((acc) {
      return (
        itemId: acc.itemId,
        itemName: acc.rawName,
        displayName: acc.name,
        category: acc.category,
        totalQuantity: acc.totalQty,
        tickets: List<OrderTicketQuantity>.unmodifiable(acc.tickets),
        colorHex: acc.colorHex,
        effectiveDietaryType: acc.dietaryType ??
            ItemDietaryType.infer(name: acc.name, category: acc.category),
      );
    }).toList();

    // Sort by total quantity descending so highest prep items are on top
    result.sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));
    return result;
  }

  /// Returns a structured list of line items for an order, computing preparation status.
  List<OrderLineItem> getOrderLineItems(StallOrder order) {
    final result = <OrderLineItem>[];
    final targetItems = order.items.isNotEmpty ? order.items : order.paidItems;

    if (targetItems.isNotEmpty) {
      targetItems.forEach((itemId, qty) {
        if (qty <= 0) return;
        final item = findItem(itemId);
        final snapshot = order.itemSnapshots[itemId];
        final name = snapshot?['name']?.toString() ?? item.name;
        final category = snapshot?['category']?.toString() ?? item.categoryName;
        final displayName = formatOrderLineItemDisplayName(
          rawName: name,
          itemId: itemId,
          category: category,
          baseItemName: item.name,
        );
        final colorHex = (snapshot?['colorHex'] as num?)?.toInt() ?? item.colorHex;
        final snapshotDietary = ItemDietaryType.fromString(snapshot?['dietaryType']?.toString());
        final dietary = snapshotDietary != ItemDietaryType.none
            ? snapshotDietary
            : item.effectiveDietaryType;
        final isPaidItem = order.isPaid || ((order.paidItems[itemId] ?? 0) >= qty);
        final completedQty = order.getCompletedQuantity(itemId);
        result.add(OrderLineItem(
          itemId: itemId,
          name: name,
          quantity: qty,
          completedQuantity: completedQty,
          isCompletedItem: completedQty >= qty,
          category: category,
          colorHex: colorHex,
          displayName: displayName,
          isPaidItem: isPaidItem,
          dietaryType: dietary,
        ));
      });
    } else if (order.itemsSummary.isNotEmpty) {
      final parts = order.itemsSummary.split(',');
      final regex = RegExp(r'^\s*(\d+)x\s+(.+)$');
      for (final rawPart in parts) {
        final match = regex.firstMatch(rawPart.trim());
        if (match != null) {
          final qty = int.tryParse(match.group(1) ?? '1') ?? 1;
          final name = match.group(2)?.trim() ?? rawPart.trim();
          final item = _menu.firstWhere(
            (m) => m.name.toLowerCase() == name.toLowerCase(),
            orElse: () => MenuItem(
              id: '',
              name: name,
              price: 0,
              category: resolveItemCategory('General'),
            ),
          );
          final itemId = item.id.isNotEmpty ? item.id : name;
          final completedQty = order.getCompletedQuantity(itemId);
          final formattedDisplayName = formatOrderLineItemDisplayName(
            rawName: name,
            itemId: itemId,
            category: item.categoryName,
          );
          result.add(OrderLineItem(
            itemId: itemId,
            name: name,
            quantity: qty,
            completedQuantity: completedQty,
            isCompletedItem: completedQty >= qty,
            category: item.categoryName,
            colorHex: item.colorHex,
            displayName: formattedDisplayName,
            isPaidItem: order.isPaid,
            dietaryType: item.effectiveDietaryType,
          ));
        }
      }
    }
    return result;
  }


  /// Extracts individual items with their corresponding category and color for an order.
  /// If [customItems] is provided, extracts details for that subset of items instead of [order.items].
  List<OrderLineItem> getOrderItemsWithCategory(StallOrder order, {Map<String, int>? customItems}) {
    if (customItems != null) {
      final customOrder = StallOrder(
        token: order.token,
        itemsSummary: order.itemsSummary,
        total: order.total,
        timestamp: order.timestamp,
        items: customItems,
        itemSnapshots: order.itemSnapshots,
        isPaid: order.isPaid,
        paidItems: order.paidItems,
        completedItems: order.completedItems,
      );
      return getOrderLineItems(customOrder);
    }
    return getOrderLineItems(order);
  }

  // ---------------------------------------------------------------------------
  // INITIALIZATION & PERSISTENCE
  // ---------------------------------------------------------------------------

  Future<void> loadPersistedData() async {
    _isLoading = true;
    notifyListeners();

    _menu = List<MenuItem>.from(await _storageService.loadMenu());
    _orders = List<StallOrder>.from(await _storageService.loadOrders());
    _nextToken = await _storageService.loadNextToken();
    _categoryConfigs = List<ItemCategory>.from(await _storageService.loadCategories());
    final loadedNotes = await _storageService.loadPredefinedNotes();
    if (loadedNotes.isNotEmpty) {
      _predefinedNotes = List<String>.from(loadedNotes);
    } else {
      _predefinedNotes = List<String>.from(defaultPredefinedNotes);
    }
    await _syncCategoriesWithMenu();

    // Ensure all active orders have formatted display names in itemSnapshots and itemsSummary
    bool ordersModified = false;
    for (int i = 0; i < _orders.length; i++) {
      final order = _orders[i];
      if (order.isCompleted) continue;
      final lineItems = getOrderLineItems(order);
      if (lineItems.isNotEmpty) {
        final newSummary = lineItems.map((li) => '${li.quantity}x ${li.displayName}').join(', ');
        final newSnapshots = Map<String, Map<String, dynamic>>.from(order.itemSnapshots);
        for (final li in lineItems) {
          final existingSnap = newSnapshots[li.itemId];
          if (existingSnap != null) {
            newSnapshots[li.itemId] = {
              ...existingSnap,
              'displayName': li.displayName,
            };
          }
        }
        if (newSummary != order.itemsSummary) {
          _orders[i] = order.copyWith(
            itemsSummary: newSummary,
            itemSnapshots: newSnapshots,
          );
          ordersModified = true;
        }
      }
    }
    if (ordersModified) {
      await _storageService.saveOrders(_orders);
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Automatically synchronizes category configurations with all categories present in the menu.
  Future<void> _syncCategoriesWithMenu() async {
    final existingMap = {
      for (final c in _categoryConfigs) c.name.trim().toLowerCase(): c,
    };
    bool modified = false;

    for (final item in _menu) {
      final rawCat = item.categoryName.trim();
      if (rawCat.isEmpty || rawCat.toLowerCase() == 'all') continue;

      final key = rawCat.toLowerCase();
      final normKey = normalizeCategoryKey(rawCat);

      if (!existingMap.containsKey(key) && !existingMap.containsKey(normKey)) {
        final newCat = ItemCategory(
          id: item.category.id.isNotEmpty
              ? item.category.id
              : 'cat_${key.replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
          name: rawCat,
          additionalCost: item.category.additionalCost,
          colorHex: item.colorHex,
          options: item.category.options.isNotEmpty ? item.category.options : item.variants,
        );
        _categoryConfigs.add(newCat);
        existingMap[key] = newCat;
        existingMap[normKey] = newCat;
        modified = true;
      }
    }

    if (modified) {
      _invalidateCategoryColors();
      await _storageService.saveCategories(_categoryConfigs);
    }
  }

  /// Renames an existing category from [oldName] to [newName] across the entire system.
  /// Updates [categoryConfigs], all items in [_menu] belonging to [oldName],
  /// any add-on linked categories, and invalidates category colors.
  Future<void> renameCategory(String oldName, String newName) async {
    final oldTrimmed = oldName.trim();
    final newTrimmed = newName.trim();
    if (oldTrimmed.isEmpty ||
        newTrimmed.isEmpty ||
        oldTrimmed.toLowerCase() == newTrimmed.toLowerCase()) {
      return;
    }

    bool menuModified = false;
    final oldNorm = oldTrimmed.toLowerCase();

    // 1. Update category configs
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

    // 2. Update menu items with oldCategory
    for (int i = 0; i < _menu.length; i++) {
      final item = _menu[i];
      bool itemChanged = false;
      ItemCategory updatedCategory = item.category;
      String? updatedLinkedCategory = item.linkedCategory;

      if (item.categoryName.trim().toLowerCase() == oldNorm) {
        updatedCategory = item.category.copyWith(name: newTrimmed);
        itemChanged = true;
      }

      // Update linked category if addon links to old category
      if (item.linkedCategory != null) {
        final links = item.linkedCategory!.split('/').map((s) => s.trim()).toList();
        if (links.any((l) => l.toLowerCase() == oldNorm)) {
          final updatedLinks = links
              .map((l) => l.toLowerCase() == oldNorm ? newTrimmed : l)
              .toList();
          updatedLinkedCategory = updatedLinks.join(' / ');
          itemChanged = true;
        }
      }

      if (itemChanged) {
        _menu[i] = item.copyWith(
          category: updatedCategory,
          linkedCategory: updatedLinkedCategory,
        );
        menuModified = true;
      }
    }

    // 3. Update selectedCategory if needed
    if (_selectedCategory.trim().toLowerCase() == oldNorm) {
      _selectedCategory = newTrimmed;
    }

    _invalidateCategoryColors();
    await _storageService.saveCategories(_categoryConfigs);
    if (menuModified) {
      await _storageService.saveMenu(_menu);
    }
    notifyListeners();
  }

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

    _invalidateCategoryColors();
    await _storageService.saveCategories(_categoryConfigs);
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
    await _storageService.saveCategories(_categoryConfigs);
    notifyListeners();
  }

  Future<void> _saveState() async {
    await _storageService.saveMenu(_menu);
    await _storageService.saveOrders(_orders);
    await _storageService.saveNextToken(_nextToken);
    await _storageService.saveCategories(_categoryConfigs);
  }

  // ---------------------------------------------------------------------------
  // CATEGORY SELECTION
  // ---------------------------------------------------------------------------

  void selectCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // CART ACTIONS
  // ---------------------------------------------------------------------------

  /// Returns items currently in the cart that can receive add-ons.
  List<MenuItem> get cartBaseItems {
    final list = <MenuItem>[];
    for (final entry in _cart.entries) {
      if (entry.value > 0) {
        final item = findItem(entry.key);
        if (!item.effectiveIsAddon) {
          list.add(item);
        }
      }
    }
    return list;
  }

  /// Adds a standard item to the cart.
  /// If the item is an Add-on, throws a StateError because add-ons cannot be added alone.
  void addToCart(MenuItem item) {
    if (item.effectiveIsAddon) {
      throw StateError(
        'Add-ons cannot be added standalone. They must be linked to a main item.',
      );
    }
    _cart[item.id] = (_cart[item.id] ?? 0) + 1;
    notifyListeners();
  }

  /// Adds a specific variant of an or-item (slash item) to the cart.
  void addVariantToCart(MenuItem baseItem, String variantName) {
    final variantId = '${baseItem.id}_var_$variantName';
    _cart[variantId] = (_cart[variantId] ?? 0) + 1;
    notifyListeners();
  }

  /// Adds an item with custom variant name and/or resolved category to the cart.
  void addCustomizedItemToCart({
    required MenuItem baseItem,
    String? resolvedName,
    String? resolvedCategory,
  }) {
    if (baseItem.effectiveIsAddon) {
      throw StateError(
        'Add-ons cannot be added standalone. They must be linked to a main item.',
      );
    }
    String customId = baseItem.id;
    if (resolvedName != null &&
        resolvedName.trim().isNotEmpty &&
        resolvedName.trim() != baseItem.name.trim()) {
      customId += '_var_${resolvedName.trim()}';
    }
    if (resolvedCategory != null &&
        resolvedCategory.trim().isNotEmpty &&
        resolvedCategory.trim() != baseItem.categoryName.trim()) {
      customId += '_cat_${resolvedCategory.trim()}';
    }
    _cart[customId] = (_cart[customId] ?? 0) + 1;
    notifyListeners();
  }

  /// Links an add-on to an existing item in the cart.
  /// Converts 1 unit of targetCartItemId into targetCartItemId+addonId (repeated quantity times).
  /// Supports resolvedAddonName and quantity.
  void addAddonToCart({
    required String targetCartItemId,
    required MenuItem addon,
    String? resolvedAddonName,
    String? resolvedAddonCategory,
    int quantity = 1,
  }) {
    if (quantity <= 0) return;
    if (!_cart.containsKey(targetCartItemId) || _cart[targetCartItemId]! <= 0) {
      throw StateError(
        'Cannot link add-on to an item not present in the active cart.',
      );
    }

    final targetItem = findItem(targetCartItemId);
    if (!addon.isApplicableToCategory(targetItem.categoryName)) {
      throw ArgumentError(
        'Add-on [${addon.name}] is linked to [${addon.effectiveLinkedCategories.join(', ')}] and cannot be added to [${targetItem.name}] (${targetItem.categoryName}).',
      );
    }

    final currentAddonCount = getAddonItemCount(
      targetCartItemId,
      addon.id,
      resolvedAddonName: resolvedAddonName,
    );
    if (currentAddonCount + quantity > maxPerAddonItem) {
      final name = resolvedAddonName ?? addon.name;
      throw StateError(
        'Maximum $maxPerAddonItem [$name] allowed per item. Current: $currentAddonCount, trying to add: $quantity.',
      );
    }

    // Decrement the target base item in cart
    if (_cart[targetCartItemId]! > 1) {
      _cart[targetCartItemId] = _cart[targetCartItemId]! - 1;
    } else {
      _cart.remove(targetCartItemId);
    }

    String addonId = addon.id;
    if (resolvedAddonName != null &&
        resolvedAddonName.trim().isNotEmpty &&
        resolvedAddonName.trim() != addon.name.trim()) {
      addonId += '_var_${resolvedAddonName.trim()}';
    }
    if (resolvedAddonCategory != null &&
        resolvedAddonCategory.trim().isNotEmpty &&
        resolvedAddonCategory.trim() != addon.categoryName.trim()) {
      addonId += '_cat_${resolvedAddonCategory.trim()}';
    }

    // Append addonId repeated quantity times
    final tokens = List.filled(quantity, addonId).join('+');
    final compositeId = '$targetCartItemId+$tokens';
    _cart[compositeId] = (_cart[compositeId] ?? 0) + 1;
    notifyListeners();
  }

  /// Links multiple add-ons with their respective quantities to a cart item in a single action.
  void addMultipleAddonsToCart({
    required String targetCartItemId,
    required List<({MenuItem addon, String? resolvedName, int quantity})> addons,
  }) {
    final validAddons = addons.where((a) => a.quantity > 0).toList();
    if (validAddons.isEmpty) return;

    if (!_cart.containsKey(targetCartItemId) || _cart[targetCartItemId]! <= 0) {
      throw StateError(
        'Cannot link add-on to an item not present in the active cart.',
      );
    }

    final targetItem = findItem(targetCartItemId);
    for (final item in validAddons) {
      if (!item.addon.isApplicableToCategory(targetItem.categoryName)) {
        throw ArgumentError(
          'Add-on [${item.addon.name}] is linked to [${item.addon.effectiveLinkedCategories.join(', ')}] and cannot be added to [${targetItem.name}] (${targetItem.categoryName}).',
        );
      }
      final currentAddonCount = getAddonItemCount(
        targetCartItemId,
        item.addon.id,
        resolvedAddonName: item.resolvedName,
      );
      if (currentAddonCount + item.quantity > maxPerAddonItem) {
        final name = item.resolvedName ?? item.addon.name;
        throw StateError(
          'Maximum $maxPerAddonItem [$name] allowed per item. Current: $currentAddonCount, trying to add: ${item.quantity}.',
        );
      }
    }

    // Decrement the target base item in cart
    if (_cart[targetCartItemId]! > 1) {
      _cart[targetCartItemId] = _cart[targetCartItemId]! - 1;
    } else {
      _cart.remove(targetCartItemId);
    }

    final addonTokens = <String>[];
    for (final item in validAddons) {
      String aId = item.addon.id;
      if (item.resolvedName != null &&
          item.resolvedName!.trim().isNotEmpty &&
          item.resolvedName!.trim() != item.addon.name.trim()) {
        aId += '_var_${item.resolvedName!.trim()}';
      }
      for (int i = 0; i < item.quantity; i++) {
        addonTokens.add(aId);
      }
    }

    final compositeId = '$targetCartItemId+${addonTokens.join('+')}';
    _cart[compositeId] = (_cart[compositeId] ?? 0) + 1;
    notifyListeners();
  }

  void incrementCartItem(String itemId) {
    if (_cart.containsKey(itemId)) {
      _cart[itemId] = _cart[itemId]! + 1;
      notifyListeners();
    }
  }

  void removeFromCart(String itemId) {
    if (_cart.containsKey(itemId)) {
      if (_cart[itemId]! > 1) {
        _cart[itemId] = _cart[itemId]! - 1;
      } else {
        _cart.remove(itemId);
      }
      notifyListeners();
    }
  }

  void clearCart() {
    if (_cart.isNotEmpty) {
      _cart.clear();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // ORDER ACTIONS: EDIT, DELETE, PUNCH / UPDATE, COMPLETE
  // ---------------------------------------------------------------------------

  /// Initiates editing for an active order:
  /// 1. Populates cart with order's items.
  /// 2. Sets editingOrderId to order.token.
  /// Returns the customerName of the order (or empty string) to populate UI.
  String startEditingOrder(StallOrder order) {
    _cart.clear();

    if (order.items.isNotEmpty) {
      _cart.addAll(order.items);
    } else if (order.itemsSummary.isNotEmpty) {
      // Parse items summary if structured items map is missing
      final parts = order.itemsSummary.split(',');
      final regex = RegExp(r'^\s*(\d+)x\s+(.+)$');
      for (final p in parts) {
        final match = regex.firstMatch(p.trim());
        if (match != null) {
          final qty = int.tryParse(match.group(1) ?? '1') ?? 1;
          final name = match.group(2)?.trim() ?? '';
          final found = _menu.firstWhere(
            (m) => m.name.toLowerCase() == name.toLowerCase(),
            orElse: () => const MenuItem(id: '', name: '', price: 0),
          );
          if (found.id.isNotEmpty) {
            _cart[found.id] = qty;
          }
        }
      }
    }

    _editingOrderId = order.token;
    notifyListeners();
    return order.customerName ?? '';
  }

  /// Cancels editing mode and clears cart.
  void cancelEditingOrder() {
    _editingOrderId = null;
    _cart.clear();
    notifyListeners();
  }

  /// Alias for cancelEditingOrder
  void cancelEditing() => cancelEditingOrder();

  /// Places a new order or updates an existing order in-place if editingOrderId is set.
  /// Returns a tuple of (token, isEdit).
  Future<({int token, bool isEdit})> punchOrUpdateOrder({
    required String? customerName,
    String? paymentMethod,
    bool? isPaid,
    double? paidAmount,
    Map<String, int>? paidItems,
    bool isParcel = false,
    String? orderNotes,
  }) async {
    if (_cart.isEmpty) {
      throw StateError('Cannot punch an empty order');
    }

    final summaryParts = <String>[];
    final currentSnapshots = <String, Map<String, dynamic>>{};
    _cart.forEach((itemId, qty) {
      final item = findItem(itemId);
      final breakdown = getCartItemBreakdown(itemId);
      final formattedDisplayName = formatOrderLineItemDisplayName(
        rawName: item.name,
        itemId: itemId,
        category: item.categoryName,
        baseItemName: item.name,
      );
      summaryParts.add('${qty}x $formattedDisplayName');
      currentSnapshots[itemId] = {
        'name': item.name,
        'displayName': formattedDisplayName,
        'price': item.price,
        'category': item.categoryName,
        if (breakdown != null && breakdown.categoryAdditionalCost > 0) ...{
          'categoryAdditionalCost': breakdown.categoryAdditionalCost,
          if (breakdown.categoryCostReason != null)
            'categoryCostReason': breakdown.categoryCostReason,
        },
        if (item.colorHex != null) 'colorHex': item.colorHex,
        if (item.effectiveDietaryType != ItemDietaryType.none)
          'dietaryType': item.effectiveDietaryType.code,
      };
    });
    final summary = summaryParts.join(', ');
    final total = cartTotal;
    final cleanCustomerName =
        (customerName != null && customerName.trim().isNotEmpty)
            ? customerName.trim()
            : null;
    final cleanOrderNotes =
        (orderNotes != null && orderNotes.trim().isNotEmpty)
            ? orderNotes.trim()
            : null;

    if (_editingOrderId != null) {
      // In-place update of existing order
      final editToken = _editingOrderId!;
      final idx = _orders.indexWhere((o) => o.token == editToken);

      if (idx != -1) {
        final existing = _orders[idx];
        final wasPaid = existing.isPaid || existing.paidAmount > 0;
        final prevPaid = existing.paidAmount > 0
            ? existing.paidAmount
            : (existing.isPaid ? existing.total : 0.0);
        final additionalDue = (total - prevPaid) > 0 ? (total - prevPaid) : 0.0;

        double finalPaidAmount;
        bool finalIsPaid;
        Map<String, int> finalPaidItems;

        if (paidAmount != null) {
          finalPaidAmount = paidAmount;
          finalIsPaid = isPaid ?? (finalPaidAmount >= total);
          finalPaidItems = paidItems ??
              (finalIsPaid
                  ? Map.from(_cart)
                  : Map.from(existing.paidItems.isNotEmpty ? existing.paidItems : existing.items));
        } else if (isPaid != null) {
          finalIsPaid = isPaid;
          finalPaidAmount = isPaid ? total : prevPaid;
          finalPaidItems = isPaid
              ? Map.from(_cart)
              : Map.from(existing.paidItems.isNotEmpty ? existing.paidItems : existing.items);
        } else {
          if (wasPaid) {
            if (additionalDue > 0) {
              // Additional payment is required: preserve previous paid amount and items,
              // but mark order as NOT fully paid so newly added items are NOT shown in confirmed payment!
              finalPaidAmount = prevPaid;
              finalPaidItems = existing.paidItems.isNotEmpty
                  ? Map.from(existing.paidItems)
                  : (existing.items.isNotEmpty ? Map.from(existing.items) : {});
              finalIsPaid = false;
            } else {
              // Total decreased or stayed identical
              finalPaidAmount = total;
              finalPaidItems = Map.from(_cart);
              finalIsPaid = true;
            }
          } else {
            finalPaidAmount = 0.0;
            finalPaidItems = const {};
            finalIsPaid = false;
          }
        }

        final updatedPaymentMethod = paymentMethod ?? existing.paymentMethod;
        final updatedCompleted = <String, int>{};
        for (final entry in existing.completedItems.entries) {
          if (_cart.containsKey(entry.key)) {
            final newQty = _cart[entry.key]!;
            updatedCompleted[entry.key] = entry.value.clamp(0, newQty);
          }
        }

        _orders[idx] = existing.copyWith(
          itemsSummary: summary,
          total: total,
          items: Map.from(_cart),
          customerName: cleanCustomerName,
          clearCustomerName: cleanCustomerName == null,
          isPaid: finalIsPaid,
          paidAmount: finalPaidAmount,
          paidItems: finalPaidItems,
          completedItems: updatedCompleted,
          paymentMethod: updatedPaymentMethod,
          itemSnapshots: {...existing.itemSnapshots, ...currentSnapshots},
          isParcel: isParcel,
          orderNotes: cleanOrderNotes,
          clearOrderNotes: cleanOrderNotes == null,
        );
      }

      _editingOrderId = null;
      _cart.clear();
      await _saveState();
      notifyListeners();
      return (token: editToken, isEdit: true);
    } else {
      // New Order (defaults to unpaid unless specified)
      final effectiveIsPaid = isPaid ?? false;
      final newOrder = StallOrder(
        token: _nextToken,
        itemsSummary: summary,
        total: total,
        timestamp: DateTime.now(),
        customerName: cleanCustomerName,
        isPaid: effectiveIsPaid,
        paidAmount: effectiveIsPaid ? (paidAmount ?? total) : (paidAmount ?? 0.0),
        paidItems: effectiveIsPaid ? (paidItems ?? Map.from(_cart)) : (paidItems ?? const {}),
        paymentMethod: paymentMethod,
        items: Map.from(_cart),
        itemSnapshots: currentSnapshots,
        isParcel: isParcel,
        orderNotes: cleanOrderNotes,
      );

      _orders.add(newOrder);
      final assignedToken = _nextToken;
      _nextToken++;
      _cart.clear();
      await _saveState();
      notifyListeners();
      return (token: assignedToken, isEdit: false);
    }
  }

  /// Confirms payment for an order and persists the change.
  Future<void> confirmPayment({
    required int token,
    required String paymentMethod,
  }) async {
    final idx = _orders.indexWhere((o) => o.token == token);
    if (idx != -1) {
      final existing = _orders[idx];
      _orders[idx] = existing.copyWith(
        isPaid: true,
        paidAmount: existing.total,
        paidItems: Map.from(existing.items),
        paymentMethod: paymentMethod,
      );
      await _saveState();
      notifyListeners();
    }
  }

  /// Deletes an order from state and persists.
  /// If the deleted order is currently being edited, cancels editing mode.
  Future<void> deleteOrder(int token) async {
    if (_editingOrderId == token) {
      cancelEditingOrder();
    }
    _orders.removeWhere((o) => o.token == token);
    await _saveState();
    notifyListeners();
  }

  /// Marks an order as completed. Also synchronizes all items to be marked completed.
  Future<void> completeOrder(int token) async {
    final idx = _orders.indexWhere((o) => o.token == token);
    if (idx != -1) {
      final existing = _orders[idx];
      _orders[idx] = existing.copyWith(
        isCompleted: true,
        completedAt: DateTime.now(),
        completedItems: Map.from(existing.items),
      );
      await _saveState();
      notifyListeners();
    }
  }

  /// Alias for completeOrder
  Future<void> markOrderCompleted(int token) => completeOrder(token);

  /// Completes a specific quantity (or all remaining quantity if [quantity] is null)
  /// of an item for an active order ticket.
  /// If all items for this order become completed, the order is automatically completed.
  /// Returns true if this completion triggered the entire order to complete.
  Future<bool> completeOrderItem({
    required int token,
    required String itemId,
    int? quantity,
  }) async {
    final idx = _orders.indexWhere((o) => o.token == token);
    if (idx == -1) return false;

    final order = _orders[idx];
    final totalQty = order.items[itemId] ?? 0;
    if (totalQty <= 0) return false;

    final currentCompleted = order.completedItems[itemId] ?? 0;
    final qtyToAdd = quantity ?? (totalQty - currentCompleted);
    if (qtyToAdd <= 0) return false;

    final newCompleted = Map<String, int>.from(order.completedItems);
    newCompleted[itemId] = (currentCompleted + qtyToAdd).clamp(0, totalQty);

    // Check if all items in order are now completed
    bool allDone = true;
    for (final entry in order.items.entries) {
      final done = newCompleted[entry.key] ?? 0;
      if (done < entry.value) {
        allDone = false;
        break;
      }
    }

    final updatedOrder = order.copyWith(
      completedItems: newCompleted,
      isCompleted: allDone ? true : order.isCompleted,
      completedAt: allDone ? (order.completedAt ?? DateTime.now()) : order.completedAt,
    );
    _orders[idx] = updatedOrder;
    await _saveState();
    notifyListeners();
    return allDone;
  }

  /// Uncompletes/reverts completion of an item for an order ticket.
  /// If the order was previously completed, it will be restored to active.
  Future<void> uncompleteOrderItem({
    required int token,
    required String itemId,
    int? quantity,
  }) async {
    final idx = _orders.indexWhere((o) => o.token == token);
    if (idx == -1) return;

    final order = _orders[idx];
    final currentCompleted = order.completedItems[itemId] ?? 0;
    if (currentCompleted <= 0) return;

    final qtyToSubtract = quantity ?? currentCompleted;
    final newCompleted = Map<String, int>.from(order.completedItems);
    final remainingCompleted = (currentCompleted - qtyToSubtract).clamp(0, order.items[itemId] ?? 0);
    if (remainingCompleted > 0) {
      newCompleted[itemId] = remainingCompleted;
    } else {
      newCompleted.remove(itemId);
    }

    final updatedOrder = order.copyWith(
      completedItems: newCompleted,
      isCompleted: false,
      completedAt: null,
    );
    _orders[idx] = updatedOrder;
    await _saveState();
    notifyListeners();
  }

  /// Completes an item across all active tickets in the prep queue.
  /// Returns a list of order tokens that became fully completed as a result.
  Future<List<int>> completeAggregatedItem(String itemId) async {
    final completedOrderTokens = <int>[];

    // Find all active orders that have remaining uncompleted quantity for this item
    final eligibleOrders = _orders
        .where((o) => !o.isCompleted && (o.isPaid || getConfirmedOrderItems(o).isNotEmpty))
        .toList();

    bool stateChanged = false;
    for (final order in eligibleOrders) {
      final totalQty = getConfirmedOrderItems(order)[itemId] ?? 0;
      final completedQty = order.completedItems[itemId] ?? 0;
      if (totalQty > completedQty) {
        final fullyDone = await completeOrderItem(
          token: order.token,
          itemId: itemId,
          quantity: totalQty - completedQty,
        );
        stateChanged = true;
        if (fullyDone) {
          completedOrderTokens.add(order.token);
        }
      }
    }

    if (stateChanged) {
      await _saveState();
      notifyListeners();
    }
    return completedOrderTokens;
  }

  /// Completes an item for the oldest pending ticket (FIFO) in the prep queue.
  /// Returns token of the completed ticket and whether the order became fully completed.
  Future<({int token, bool isOrderFullyCompleted})?> completeNextTicketForItem(String itemId) async {
    final eligibleOrders = _orders
        .where((o) => !o.isCompleted && (o.isPaid || getConfirmedOrderItems(o).isNotEmpty))
        .toList();

    for (final order in eligibleOrders) {
      final totalQty = getConfirmedOrderItems(order)[itemId] ?? 0;
      final completedQty = order.completedItems[itemId] ?? 0;
      if (totalQty > completedQty) {
        final orderCompleted = await completeOrderItem(
          token: order.token,
          itemId: itemId,
          quantity: totalQty - completedQty,
        );
        return (token: order.token, isOrderFullyCompleted: orderCompleted);
      }
    }
    return null;
  }

  /// Clears all completed orders from memory and persistent storage.
  Future<void> clearCompletedOrders() async {
    _orders.removeWhere((o) => o.isCompleted);
    await _storageService.saveOrders(_orders);
    notifyListeners();
  }

  /// Archives completed orders to a separate persistent archive key and removes them from active orders.
  Future<void> archiveCompletedOrders() async {
    final completed = _orders.where((o) => o.isCompleted).toList();
    if (completed.isEmpty) return;
    await _storageService.archiveCompletedOrders(explicitOrders: completed);
    _orders.removeWhere((o) => o.isCompleted);
    await _storageService.saveOrders(_orders);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // MENU ITEM MANAGEMENT
  // ---------------------------------------------------------------------------

  Future<void> addMenuItem(MenuItem item) async {
    _menu.add(item);
    _invalidateCategoryColors();
    await _syncCategoriesWithMenu();
    await _saveState();
    notifyListeners();
  }

  Future<void> updateMenuItem(MenuItem updated) async {
    final idx = _menu.indexWhere((m) => m.id == updated.id);
    if (idx != -1) {
      _menu[idx] = updated;
      _invalidateCategoryColors();
      await _syncCategoriesWithMenu();
      await _saveState();
      notifyListeners();
    }
  }

  Future<void> deleteMenuItem(String id) async {
    _menu.removeWhere((m) => m.id == id);
    _cart.removeWhere((cartId, _) => CompositeItemHelper.isBaseItemMatch(cartId, id));
    if (_selectedCategory != 'All' &&
        !_menu.any((m) => m.categoryName == _selectedCategory)) {
      _selectedCategory = 'All';
    }
    _invalidateCategoryColors();
    await _saveState();
    notifyListeners();
  }

  Future<void> setMenu(List<MenuItem> newMenu, {bool replace = true}) async {
    if (replace) {
      _menu = List.from(newMenu);
      _cart.clear();
      _selectedCategory = 'All';
    } else {
      _menu.addAll(newMenu);
    }
    _invalidateCategoryColors();
    await _syncCategoriesWithMenu();
    await _saveState();
    notifyListeners();
  }

  /// Toggles availability of a menu item for today and persists it.
  Future<void> toggleItemAvailability(String id) async {
    final index = _menu.indexWhere((m) => m.id == id);
    if (index == -1) return;
    final current = _menu[index];
    _menu[index] = current.copyWith(isAvailable: !current.isAvailable);
    await _storageService.saveMenu(_menu);
    notifyListeners();
  }

  /// Sets availability of a menu item for today and persists it.
  Future<void> setItemAvailability(String id, bool isAvailable) async {
    final index = _menu.indexWhere((m) => m.id == id);
    if (index == -1) return;
    if (_menu[index].isAvailable == isAvailable) return;
    _menu[index] = _menu[index].copyWith(isAvailable: isAvailable);
    await _storageService.saveMenu(_menu);
    notifyListeners();
  }

  /// Toggles or sets availability of an individual variant on a menu item and persists it.
  Future<void> toggleMenuItemVariantAvailability(
    String itemId,
    String variantIdOrName, {
    bool? isAvailable,
  }) async {
    final index = _menu.indexWhere((m) => m.id == itemId);
    if (index == -1) return;
    final item = _menu[index];
    final currentVariants = List<CategoryOption>.from(item.effectiveVariants);
    if (currentVariants.isEmpty) return;

    final targetIdx = currentVariants.indexWhere(
      (v) =>
          v.id == variantIdOrName ||
          v.name.trim().toLowerCase() == variantIdOrName.trim().toLowerCase(),
    );
    if (targetIdx == -1) return;

    final target = currentVariants[targetIdx];
    final newStatus = isAvailable ?? !target.isEnabled;
    if (target.isEnabled == newStatus && item.variants.isNotEmpty) return;

    currentVariants[targetIdx] = target.copyWith(isEnabled: newStatus);

    _menu[index] = item.copyWith(variants: currentVariants);
    await _storageService.saveMenu(_menu);
    notifyListeners();
  }

  /// Sets availability for all items in a category for today and persists it.
  Future<void> setCategoryAvailability(String category, bool isAvailable) async {
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
      await _storageService.saveMenu(_menu);
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
      await _storageService.saveMenu(_menu);
      notifyListeners();
    }
  }
}

class _ItemAccumulator {
  final String itemId;
  final String rawName;
  final String name;
  final String category;
  final int? colorHex;
  final ItemDietaryType? dietaryType;
  int totalQty = 0;
  final List<OrderTicketQuantity> tickets = [];

  _ItemAccumulator({
    required this.itemId,
    required this.rawName,
    required this.name,
    required this.category,
    this.colorHex,
    this.dietaryType,
  });
}

