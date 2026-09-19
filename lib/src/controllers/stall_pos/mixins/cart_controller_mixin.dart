import 'package:flutter/foundation.dart';
import '../../../models/stall_models.dart';
import 'cart_key_parser.dart';

/// Mixin managing active cart items, quantity modifications, add-on attachments,
/// and cart monetary computations for Stall POS.
mixin CartControllerMixin on ChangeNotifier {
  final Map<String, int> _cart = {};

  static const int maxPerAddonItem = 2;
  static const int maxAddonsPerItem = maxPerAddonItem;

  /// Abstract requirements provided by [MenuCatalogControllerMixin] and [CategoryConfigControllerMixin].
  MenuItem findItem(String id);
  CartItemBreakdown? getCartItemBreakdown(String itemId);
  ItemCategory? getCategoryConfig(String category);
  List<MenuItem> get rawMenu;

  /// Unmodifiable view of items in the cart (key -> quantity).
  Map<String, int> get cart => Map.unmodifiable(_cart);

  /// Total count of items in the current active cart.
  int get cartItemCount => _cart.values.fold(0, (a, b) => a + b);
  int get cartTotalQuantity => cartItemCount;
  int get cartCount => cartItemCount;

  /// Total monetary price of items in the cart.
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

  int getCartItemCount(String cartItemId) => _cart[cartItemId] ?? 0;
  int getItemQuantity(String cartItemId) => _cart[cartItemId] ?? 0;
  bool isItemInCart(String cartItemId) => _cart.containsKey(cartItemId);

  /// Returns items currently in the cart that can receive add-ons.
  List<MenuItem> get cartBaseItems {
    final list = <MenuItem>[];
    for (final entry in _cart.entries) {
      if (entry.value > 0) {
        list.add(findItem(entry.key));
      }
    }
    return list;
  }

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
    final result = <MenuItem>[];
    final seen = <String>{};

    final catConfig = getCategoryConfig(category);
    final catAddons = catConfig?.addons ?? const [];
    for (final addon in catAddons) {
      if (onlyAvailable && !addon.isEnabled) continue;
      if (seen.add(addon.name)) {
        result.add(MenuItem(
          id: addon.id,
          name: addon.name,
          price: addon.priceDelta > 0 ? addon.priceDelta : (addon.price ?? 0.0),
          category: catConfig ?? ItemCategory(id: 'cat_gen', name: category),
          unavailableVariants: addon.isEnabled ? const [] : [addon.id],
        ));
      }
    }

    for (final item in rawMenu.where((m) => m.categoryName.trim().toLowerCase() == category.trim().toLowerCase())) {
      for (final addon in item.addons) {
        if (onlyAvailable && !addon.isEnabled) continue;
        if (seen.add(addon.name)) {
          result.add(MenuItem(
            id: addon.id,
            name: addon.name,
            price: addon.priceDelta > 0 ? addon.priceDelta : (addon.price ?? 0.0),
            category: item.category,
            unavailableVariants: addon.isEnabled ? const [] : [addon.id],
          ));
        }
      }
    }
    return result;
  }

  /// Whether there are any add-ons available for the given [category].
  bool hasAddonsForCategory(String category, {bool onlyAvailable = true}) {
    return getAddonsForCategory(category, onlyAvailable: onlyAvailable).isNotEmpty;
  }

  /// Returns add-on options available for a specific item.
  List<CategoryOption> getAddonsForItem(MenuItem item, {bool onlyAvailable = true}) {
    if (onlyAvailable) {
      return item.effectiveAddons.where((a) => a.isAvailable).toList();
    }
    return item.effectiveAddons;
  }

  /// Checks if the specified add-on can be added to the cart item without exceeding maxPerAddonItem.
  bool canAddAddonItem(
    String cartItemId,
    MenuItem addon, {
    String? resolvedAddonName,
    int countToAdd = 1,
  }) {
    final current = getAddonItemCount(
      cartItemId,
      addon.id,
      resolvedAddonName: resolvedAddonName,
    );
    return current + countToAdd <= maxPerAddonItem;
  }

  /// Checks if any available add-on for the cart item can still be added to the cart item.
  bool canAddAnyAddon(String cartItemId) {
    final targetItem = findItem(cartItemId);
    final itemAddons = getAddonsForItem(targetItem, onlyAvailable: true);
    for (final addon in itemAddons) {
      if (getAddonItemCount(cartItemId, addon.id, resolvedAddonName: addon.name) < maxPerAddonItem) {
        return true;
      }
    }
    final availableAddons = getAddonsForCategory(targetItem.categoryName, onlyAvailable: true);
    for (final addon in availableAddons) {
      if (getAddonItemCount(cartItemId, addon.id) < maxPerAddonItem) {
        return true;
      }
    }
    return false;
  }

  /// Single source of truth for resolving the formatted display name of any cart item.
  String getCartItemDisplayName(String cartItemId) {
    final item = findItem(cartItemId);
    return CartKeyParser.formatOrderLineItemDisplayName(
      rawName: item.name,
      itemId: cartItemId,
      category: item.categoryName,
      baseItemName: item.name,
    );
  }

  /// Adds a standard item or [OrderItem] to the cart.
  void addToCart(dynamic item, [int quantity = 1]) {
    if (item is OrderItem) {
      final key = item.cartKey;
      _cart[key] = (_cart[key] ?? 0) + item.quantity;
    } else if (item is MenuItem) {
      _cart[item.id] = (_cart[item.id] ?? 0) + quantity;
    }
    notifyListeners();
  }

  /// Updates or replaces a line item in the cart using [OrderItem] or direct ID.
  void updateCartItem(
    dynamic item, {
    String? oldCartKey,
    int? quantity,
  }) {
    if (item is OrderItem) {
      if (oldCartKey != null && oldCartKey != item.cartKey) {
        _cart.remove(oldCartKey);
      }
      final qty = quantity ?? item.quantity;
      if (qty <= 0) {
        _cart.remove(item.cartKey);
      } else {
        _cart[item.cartKey] = qty;
      }
    } else if (item is String) {
      final qty = quantity ?? 1;
      if (qty <= 0) {
        _cart.remove(item);
      } else {
        _cart[item] = qty;
      }
    }
    notifyListeners();
  }

  /// Adds a specific variant of an item to the cart.
  void addVariantToCart(MenuItem baseItem, String variantName) {
    final variantId = '${baseItem.id}_var_$variantName';
    _cart[variantId] = (_cart[variantId] ?? 0) + 1;
    notifyListeners();
  }

  /// Adds an item with custom variant and/or add-ons to the cart.
  void addCustomizedItemToCart({
    required MenuItem baseItem,
    CategoryOption? selectedVariant,
    List<CategoryOption>? selectedAddons,
    int quantity = 1,
    String? resolvedName,
    String? resolvedCategory,
  }) {
    String customId = baseItem.id;
    final variantName = selectedVariant?.name ?? resolvedName;
    if (variantName != null &&
        variantName.trim().isNotEmpty &&
        variantName.trim() != baseItem.name.trim()) {
      customId += '_var_${variantName.trim()}';
    }
    if (resolvedCategory != null &&
        resolvedCategory.trim().isNotEmpty &&
        resolvedCategory.trim() != baseItem.categoryName.trim()) {
      customId += '_cat_${resolvedCategory.trim()}';
    }
    if (selectedAddons != null && selectedAddons.isNotEmpty) {
      for (final addon in selectedAddons) {
        customId += '+${addon.id}';
      }
    }
    _cart[customId] = (_cart[customId] ?? 0) + quantity;
    notifyListeners();
  }

  /// Links an add-on to an existing item in the cart.
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

    for (final item in validAddons) {
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

  void setCartItemQuantity(String itemId, int quantity) {
    if (quantity <= 0) {
      _cart.remove(itemId);
    } else {
      _cart[itemId] = quantity;
    }
    notifyListeners();
  }

  /// Hook called when a menu item is deleted from the catalog.
  void onMenuItemDeleted(String itemId) {
    _cart.removeWhere((cartId, _) => CartKeyParser.parseBaseIdFromKey(cartId) == itemId);
  }

  /// Internal helper to populate cart when editing an existing order.
  @protected
  void setCartFromOrder(Map<String, int> orderCart) {
    _cart.clear();
    _cart.addAll(orderCart);
    notifyListeners();
  }
}
