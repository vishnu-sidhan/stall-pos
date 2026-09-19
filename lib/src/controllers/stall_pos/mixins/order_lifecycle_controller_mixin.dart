import 'package:flutter/foundation.dart';
import '../../../models/stall_models.dart';
import 'cart_key_parser.dart';

/// Mixin managing orders queue, ticketing, payment confirmations, in-place order editing,
/// deletion, and status lifecycle for Stall POS.
mixin OrderLifecycleControllerMixin on ChangeNotifier {
  List<StallOrder> _orders = [];
  int _nextToken = 1;
  int? _editingOrderId;

  /// Abstract requirements provided by other POS mixins and host controller.
  Map<String, int> get cart;
  double get cartTotal;
  void clearCart();
  void addToCart(dynamic item, [int quantity = 1]);
  void removeFromCart(String itemId);
  MenuItem findItem(String id);
  MenuItem? findBaseMenuItem(String key);
  MenuItem? getItemById(String id);
  ItemCategory? getCategoryConfig(String category);
  double getCategoryCost(String category);
  List<MenuItem> get rawMenu;
  Future<void> saveState();
  Future<void> archiveCompletedOrdersToStorage(List<StallOrder> completed);

  /// Raw mutable orders list.
  List<StallOrder> get rawOrders => _orders;

  /// Unmodifiable view of all orders.
  List<StallOrder> get orders => List.unmodifiable(_orders);

  /// Active (non-completed) orders in FIFO order.
  List<StallOrder> get activeOrders =>
      _orders.where((o) => !o.isCompleted).toList();

  /// Completed orders history.
  List<StallOrder> get completedOrders =>
      _orders.where((o) => o.isCompleted).toList();

  int get nextToken => _nextToken;
  int? get editingOrderId => _editingOrderId;
  bool get isEditing => _editingOrderId != null;
  StallOrder? get editingOrder => _editingOrderId != null
      ? _orders.where((o) => o.token == _editingOrderId).firstOrNull
      : null;

  /// Sets loaded orders from storage during initialization.
  @protected
  void setLoadedOrders(List<StallOrder> loadedOrders, int loadedNextToken) {
    _orders = List.from(loadedOrders);
    _nextToken = loadedNextToken;
  }

  /// Returns all items currently in the cart as concrete [OrderItem] models.
  List<OrderItem> get cartOrderItems {
    final list = <OrderItem>[];
    for (final entry in cart.entries) {
      final cartKey = entry.key;
      final qty = entry.value;
      if (qty <= 0) continue;

      final baseItem = findBaseMenuItem(cartKey) ?? findItem(cartKey);
      final resolvedItem = findItem(cartKey);
      final varVariant = CartKeyParser.parseVariantFromKey(cartKey);
      final catVariant = CartKeyParser.parseCategoryFromKey(cartKey);
      final resolvedCategoryName = catVariant ?? baseItem.categoryName;
      final catCost = getCategoryCost(resolvedCategoryName);

      CategoryOption? selectedVariant;
      if (varVariant != null && varVariant.isNotEmpty) {
        for (final v in baseItem.variants) {
          if (v.name.toLowerCase() == varVariant.toLowerCase() ||
              v.id == varVariant) {
            selectedVariant = v;
            break;
          }
        }
        selectedVariant ??= CategoryOption(id: varVariant, name: varVariant);
      }

      final List<CategoryOption> selectedAddons = [];
      if (cartKey.contains('+')) {
        final addonParts = cartKey.split('+').skip(1);
        final candidateAddons = [
          ...baseItem.addons,
          ...(getCategoryConfig(resolvedCategoryName)?.addons ??
              const <CategoryOption>[]),
        ];
        for (final part in addonParts) {
          if (part.isEmpty) continue;
          CategoryOption? found;
          for (final a in candidateAddons) {
            if (a.id == part || a.name == part) {
              found = a;
              break;
            }
          }
          if (found == null) {
            final addonItem = getItemById(part) ?? findBaseMenuItem(part);
            if (addonItem != null) {
              found = CategoryOption(
                id: addonItem.id,
                name: addonItem.name,
                price: addonItem.price,
              );
            }
          }
          found ??= CategoryOption(id: part, name: part);
          selectedAddons.add(found);
        }
      }

      final cleanItemName = cartKey.contains('+')
          ? resolvedItem.name
          : (baseItem.name.contains('/') ? resolvedItem.name : baseItem.name);

      list.add(
        OrderItem(
          itemId: cartKey,
          itemName: cleanItemName,
          price: baseItem.price,
          quantity: qty,
          selectedVariant: selectedVariant,
          selectedAddons: selectedAddons,
          categoryAdditionalCost: catCost,
          categoryName: resolvedCategoryName,
          colorHex: baseItem.colorHex,
          dietaryType: resolvedItem.effectiveDietaryType,
        ),
      );
    }
    return list;
  }

  /// Adds a specific [OrderItem] to the cart.
  void addOrderItemToCart(OrderItem orderItem) {
    addToCart(orderItem, orderItem.quantity);
  }

  /// Removes an [OrderItem] line from the cart.
  void removeOrderItemFromCart(OrderItem orderItem) {
    removeFromCart(orderItem.cartKey);
  }

  /// Looks up an order by its token / order ID.
  StallOrder? getOrderById(dynamic orderIdOrToken) {
    final token = (orderIdOrToken is int)
        ? orderIdOrToken
        : int.tryParse(orderIdOrToken.toString());
    if (token == null) return null;
    return _orders.where((o) => o.token == token).firstOrNull;
  }

  /// Initiates editing for an active order:
  /// 1. Populates cart with order's items.
  /// 2. Sets editingOrderId to order.token.
  /// Returns the customerName of the order (or empty string) to populate UI.
  String startEditingOrder(StallOrder order) {
    clearCart();

    if (order.items.isNotEmpty) {
      for (final item in order.items) {
        addToCart(item, item.quantity);
      }
    } else if (order.itemsSummary.isNotEmpty) {
      final parts = order.itemsSummary.split(',');
      final regex = RegExp(r'^\s*(\d+)x\s+(.+)$');
      for (final p in parts) {
        final match = regex.firstMatch(p.trim());
        if (match != null) {
          final qty = int.tryParse(match.group(1) ?? '1') ?? 1;
          final name = match.group(2)?.trim() ?? '';
          final found = rawMenu.firstWhere(
            (m) => m.name.toLowerCase() == name.toLowerCase(),
            orElse: () => const MenuItem(id: '', name: '', price: 0),
          );
          if (found.id.isNotEmpty) {
            addToCart(found, qty);
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
    clearCart();
    notifyListeners();
  }

  /// Alias for cancelEditingOrder.
  void cancelEditing() => cancelEditingOrder();

  /// Updates preparation status for a specific item in an order.
  Future<void> updateOrderItemPreparationStatus(
    dynamic orderIdOrToken,
    int itemIndex,
    ItemPreparationStatus status,
  ) async {
    final token = (orderIdOrToken is int)
        ? orderIdOrToken
        : int.tryParse(orderIdOrToken.toString());
    if (token == null) return;
    final idx = _orders.indexWhere((o) => o.token == token);
    if (idx == -1) return;

    final order = _orders[idx];
    if (itemIndex < 0 || itemIndex >= order.items.length) return;

    final updatedItems = List<OrderItem>.from(order.items);
    updatedItems[itemIndex] = updatedItems[itemIndex].copyWith(
      preparationStatus: status,
    );

    final allServed =
        updatedItems.isNotEmpty && updatedItems.every((i) => i.isServed);
    _orders[idx] = order.copyWith(
      items: updatedItems,
      isCompleted: allServed ? true : order.isCompleted,
      completedAt: allServed
          ? (order.completedAt ?? DateTime.now())
          : order.completedAt,
    );

    await saveState();
    notifyListeners();
  }

  /// Updates the paid quantity for a specific item in an order.
  Future<void> updateOrderItemPaidQuantity(
    dynamic orderIdOrToken,
    int itemIndex,
    int paidQuantity,
  ) async {
    final token = (orderIdOrToken is int)
        ? orderIdOrToken
        : int.tryParse(orderIdOrToken.toString());
    if (token == null) return;
    final idx = _orders.indexWhere((o) => o.token == token);
    if (idx == -1) return;

    final order = _orders[idx];
    if (itemIndex < 0 || itemIndex >= order.items.length) return;

    final updatedItems = List<OrderItem>.from(order.items);
    final clampedQty = paidQuantity.clamp(0, updatedItems[itemIndex].quantity);
    updatedItems[itemIndex] = updatedItems[itemIndex].copyWith(
      paidQuantity: clampedQty,
    );

    final allPaid =
        updatedItems.isNotEmpty && updatedItems.every((i) => i.isFullyPaid);
    _orders[idx] = order.copyWith(items: updatedItems, isPaid: allPaid);

    await saveState();
    notifyListeners();
  }

  /// Punches a new order or updates an existing order in-place if editing.
  Future<({int token, bool isEdit})> punchOrUpdateOrder({
    String? customerName,
    bool? isPaid,
    String? paymentMethod,
    double? paidAmount,
    Map<String, int>? paidItems,
    bool isParcel = false,
    String? orderNotes,
  }) async {
    if (cart.isEmpty) {
      throw StateError('Cannot punch an empty order');
    }

    final total = cartTotal;
    final cleanCustomerName =
        (customerName != null && customerName.trim().isNotEmpty)
        ? customerName.trim()
        : null;
    final cleanOrderNotes = (orderNotes != null && orderNotes.trim().isNotEmpty)
        ? orderNotes.trim()
        : null;

    if (_editingOrderId != null) {
      final editToken = _editingOrderId!;
      final idx = _orders.indexWhere((o) => o.token == editToken);

      if (idx != -1) {
        final existing = _orders[idx];
        final wasPaid = existing.isPaid || existing.paidAmount > 0;
        final prevPaid = existing.paidAmount > 0
            ? existing.paidAmount
            : (existing.isPaid ? existing.total : 0.0);
        final additionalDue = (total - prevPaid) > 0 ? (total - prevPaid) : 0.0;

        bool finalIsPaid;
        if (paidAmount != null) {
          finalIsPaid = isPaid ?? (paidAmount >= total);
        } else if (isPaid != null) {
          finalIsPaid = isPaid;
        } else {
          finalIsPaid = wasPaid && additionalDue <= 0;
        }

        final updatedPaymentMethod = paymentMethod ?? existing.paymentMethod;
        final orderItems = cartOrderItems.map((item) {
          int paidQty = 0;
          ItemPreparationStatus status = ItemPreparationStatus.pending;
          if (finalIsPaid) {
            paidQty = item.quantity;
          } else if (paidItems != null) {
            paidQty = (paidItems[item.cartKey] ?? 0).clamp(0, item.quantity);
            final prevItem = existing.items
                .where((i) => i.cartKey == item.cartKey)
                .firstOrNull;
            if (prevItem != null) {
              status = prevItem.preparationStatus;
            }
          } else {
            final prevItem = existing.items
                .where((i) => i.cartKey == item.cartKey)
                .firstOrNull;
            if (prevItem != null) {
              paidQty = prevItem.paidQuantity.clamp(0, item.quantity);
              status = prevItem.preparationStatus;
            }
          }
          return item.copyWith(
            paidQuantity: paidQty,
            preparationStatus: status,
          );
        }).toList();

        _orders[idx] = existing.copyWith(
          items: orderItems,
          customerName: cleanCustomerName,
          clearCustomerName: cleanCustomerName == null,
          isPaid: finalIsPaid,
          paidAmount: finalIsPaid ? null : (paidAmount ?? prevPaid),
          paymentMethod: updatedPaymentMethod,
          isParcel: isParcel,
          orderNotes: cleanOrderNotes,
          clearOrderNotes: cleanOrderNotes == null,
        );
      }

      _editingOrderId = null;
      clearCart();
      await saveState();
      notifyListeners();
      return (token: editToken, isEdit: true);
    } else {
      final effectiveIsPaid = isPaid ?? false;
      final orderItems = cartOrderItems.map((item) {
        return item.copyWith(paidQuantity: effectiveIsPaid ? item.quantity : 0);
      }).toList();

      final newOrder = StallOrder(
        token: _nextToken,
        timestamp: DateTime.now(),
        customerName: cleanCustomerName,
        isPaid: effectiveIsPaid,
        paymentMethod: paymentMethod,
        items: orderItems,
        isParcel: isParcel,
        orderNotes: cleanOrderNotes,
      );

      _orders.add(newOrder);
      final assignedToken = _nextToken;
      _nextToken++;
      clearCart();
      await saveState();
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
      final updatedItems = existing.items
          .map((i) => i.copyWith(paidQuantity: i.quantity))
          .toList();
      _orders[idx] = existing.copyWith(
        isPaid: true,
        items: updatedItems,
        paymentMethod: paymentMethod,
      );
      await saveState();
      notifyListeners();
    }
  }

  /// Deletes an order from state and persists.
  Future<void> deleteOrder(int token) async {
    if (_editingOrderId == token) {
      cancelEditingOrder();
    }
    _orders.removeWhere((o) => o.token == token);
    await saveState();
    notifyListeners();
  }

  /// Marks an order as completed and synchronizes all items to be marked served.
  Future<void> completeOrder(int token) async {
    final idx = _orders.indexWhere((o) => o.token == token);
    if (idx != -1) {
      final existing = _orders[idx];
      final updatedItems = existing.items
          .map(
            (i) => i.copyWith(preparationStatus: ItemPreparationStatus.served),
          )
          .toList();
      _orders[idx] = existing.copyWith(
        isCompleted: true,
        completedAt: DateTime.now(),
        items: updatedItems,
      );
      await saveState();
      notifyListeners();
    }
  }

  /// Alias for completeOrder.
  Future<void> markOrderCompleted(int token) => completeOrder(token);

  /// Clears all completed orders from memory and persistent storage.
  Future<void> clearCompletedOrders() async {
    _orders.removeWhere((o) => o.isCompleted);
    await saveState();
    notifyListeners();
  }

  /// Clears all orders from memory and persistent storage.
  Future<void> clearAllOrders() async {
    _orders.clear();
    await saveState();
    notifyListeners();
  }

  /// Archives completed orders to a separate persistent archive key and removes them from active orders.
  Future<void> archiveCompletedOrders() async {
    final completed = _orders.where((o) => o.isCompleted).toList();
    if (completed.isEmpty) return;
    await archiveCompletedOrdersToStorage(completed);
    _orders.removeWhere((o) => o.isCompleted);
    await saveState();
    notifyListeners();
  }
}
