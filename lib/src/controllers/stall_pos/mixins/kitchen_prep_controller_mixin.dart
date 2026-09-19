import 'package:flutter/foundation.dart';
import '../../../models/stall_models.dart';

/// Mixin managing kitchen preparation aggregation, ticket chips breakdown,
/// and batch / item completion for Stall POS.
mixin KitchenPrepControllerMixin on ChangeNotifier {
  /// Abstract requirements provided by [OrderLifecycleControllerMixin] and host controller.
  List<StallOrder> get rawOrders;
  List<StallOrder> get activeOrders;
  Future<void> saveState();

  /// Returns only the items/quantities that have been paid for in the given order.
  Map<String, int> getConfirmedOrderItems(StallOrder order) {
    if (order.isPaid) {
      return Map.unmodifiable(order.legacyItems);
    }
    return Map.unmodifiable(order.paidItems);
  }

  /// Returns only the items/quantities that have NOT yet been paid for in the given order.
  Map<String, int> getPendingOrderItems(StallOrder order) {
    if (order.isPaid) {
      return const {};
    }
    final pending = <String, int>{};
    for (final item in order.items) {
      final unp = item.quantity - item.paidQuantity;
      if (unp > 0) {
        pending[item.cartKey] = unp;
      }
    }
    return Map.unmodifiable(pending);
  }

  /// Returns active orders that have confirmed (paid) items.
  List<StallOrder> get confirmedActiveOrders =>
      activeOrders.where((o) => o.isPaid || getConfirmedOrderItems(o).isNotEmpty).toList();

  /// Returns active orders that have pending (unpaid) items to confirm payment.
  List<StallOrder> get toConfirmPaymentOrders =>
      activeOrders.where((o) => !o.isPaid && getPendingOrderItems(o).isNotEmpty).toList();

  /// Consolidated items view across all active orders with confirmed payment.
  /// Aggregates total quantities per item.
  List<OrderItem> get combinedActiveOrders {
    final eligibleOrders = rawOrders
        .where((o) => !o.isCompleted && (o.isPaid || o.items.any((i) => i.paidQuantity > 0)))
        .toList();

    final Map<String, List<OrderItem>> groups = {};
    for (final order in eligibleOrders) {
      for (final item in order.items) {
        if (item.isServed) continue;
        if (!order.isPaid && item.paidQuantity <= 0) continue;
        final qty = order.isPaid ? item.quantity : item.paidQuantity;
        if (qty <= 0) continue;

        groups.putIfAbsent(item.cartKey, () => []).add(item.copyWith(quantity: qty));
      }
    }

    final result = groups.values.map((group) {
      final base = group.first;
      final totalQty = group.fold<int>(0, (sum, item) => sum + item.quantity);
      return base.copyWith(quantity: totalQty);
    }).toList();

    result.sort((a, b) => b.quantity.compareTo(a.quantity));
    return result;
  }

  /// Alias for [combinedActiveOrders].
  List<OrderItem> get aggregatedPrepItems => combinedActiveOrders;

  /// Returns the active ticket breakdown contributing to an aggregated item.
  List<({int token, int quantity, bool isParcel, String? orderNotes})> getTicketsForItem(
    String itemIdOrCartKey,
  ) {
    final eligibleOrders = rawOrders
        .where((o) => !o.isCompleted && (o.isPaid || o.items.any((i) => i.paidQuantity > 0)))
        .toList();

    final tickets = <({int token, int quantity, bool isParcel, String? orderNotes})>[];
    for (final order in eligibleOrders) {
      for (final item in order.items) {
        if (item.isServed) continue;
        if (!order.isPaid && item.paidQuantity <= 0) continue;
        if (item.cartKey == itemIdOrCartKey || item.itemId == itemIdOrCartKey) {
          final qty = order.isPaid ? item.quantity : item.paidQuantity;
          if (qty > 0) {
            tickets.add((
              token: order.token,
              quantity: qty,
              isParcel: order.isParcel,
              orderNotes: order.orderNotes,
            ));
          }
        }
      }
    }
    return tickets;
  }

  /// Returns the structured list of line items for an order.
  List<OrderItem> getOrderLineItems(StallOrder order) =>
      getOrderItemsWithCategory(order);

  /// Extracts individual items for an order, supporting [customItems] filter if provided.
  List<OrderItem> getOrderItemsWithCategory(StallOrder order, {Map<String, int>? customItems}) {
    var items = order.items;
    if (customItems != null) {
      items = items
          .where((i) =>
              customItems.containsKey(i.cartKey) ||
              customItems.containsKey(i.itemId))
          .toList();
    }
    return items;
  }

  /// Completes a specific quantity of an item for an active order ticket.
  /// If all items for this order become completed, the order is automatically completed.
  Future<bool> completeOrderItem({
    required int token,
    required String itemId,
    int? quantity,
  }) async {
    final idx = rawOrders.indexWhere((o) => o.token == token);
    if (idx == -1) return false;

    final order = rawOrders[idx];
    final itemIdx = order.items.indexWhere(
      (i) =>
          !i.isServed &&
          !i.isReady &&
          (i.itemId == itemId || i.cartKey == itemId || i.itemName.toLowerCase() == itemId.toLowerCase()),
    );
    if (itemIdx == -1) return false;

    final targetItem = order.items[itemIdx];
    final qtyToComplete = quantity ?? targetItem.quantity;
    if (qtyToComplete <= 0) return false;

    final updatedItems = List<OrderItem>.from(order.items);
    if (qtyToComplete < targetItem.quantity) {
      final servedPart = targetItem.copyWith(
        quantity: qtyToComplete,
        paidQuantity: targetItem.paidQuantity >= qtyToComplete ? qtyToComplete : targetItem.paidQuantity,
        preparationStatus: ItemPreparationStatus.served,
      );
      final remainingPart = targetItem.copyWith(
        quantity: targetItem.quantity - qtyToComplete,
        paidQuantity: targetItem.paidQuantity > qtyToComplete ? (targetItem.paidQuantity - qtyToComplete) : 0,
        preparationStatus: targetItem.preparationStatus,
      );
      updatedItems[itemIdx] = servedPart;
      updatedItems.insert(itemIdx + 1, remainingPart);
    } else {
      updatedItems[itemIdx] = targetItem.copyWith(
        preparationStatus: ItemPreparationStatus.served,
      );
    }

    final allDone = updatedItems.isNotEmpty && updatedItems.every((i) => i.isServed || i.isReady);
    rawOrders[idx] = order.copyWith(
      items: updatedItems,
      isCompleted: allDone ? true : order.isCompleted,
      completedAt: allDone ? (order.completedAt ?? DateTime.now()) : order.completedAt,
    );
    await saveState();
    notifyListeners();
    return allDone;
  }

  /// Uncompletes/reverts completion of an item for an order ticket.
  Future<void> uncompleteOrderItem({
    required int token,
    required String itemId,
    int? quantity,
  }) async {
    final idx = rawOrders.indexWhere((o) => o.token == token);
    if (idx == -1) return;

    final order = rawOrders[idx];
    final itemIdx = order.items.indexWhere(
      (i) =>
          (i.isServed || i.isReady) &&
          (i.itemId == itemId || i.cartKey == itemId || i.itemName.toLowerCase() == itemId.toLowerCase()),
    );
    if (itemIdx == -1) return;

    final targetItem = order.items[itemIdx];
    final qtyToRevert = quantity ?? targetItem.quantity;
    if (qtyToRevert <= 0) return;

    final updatedItems = List<OrderItem>.from(order.items);
    if (qtyToRevert < targetItem.quantity) {
      final pendingPart = targetItem.copyWith(
        quantity: qtyToRevert,
        paidQuantity: targetItem.paidQuantity >= qtyToRevert ? qtyToRevert : targetItem.paidQuantity,
        preparationStatus: ItemPreparationStatus.pending,
      );
      final remainingServed = targetItem.copyWith(
        quantity: targetItem.quantity - qtyToRevert,
        paidQuantity: targetItem.paidQuantity > qtyToRevert ? (targetItem.paidQuantity - qtyToRevert) : 0,
        preparationStatus: targetItem.preparationStatus,
      );
      updatedItems[itemIdx] = pendingPart;
      updatedItems.insert(itemIdx + 1, remainingServed);
    } else {
      updatedItems[itemIdx] = targetItem.copyWith(
        preparationStatus: ItemPreparationStatus.pending,
      );
    }

    rawOrders[idx] = order.copyWith(
      items: updatedItems,
      isCompleted: false,
      completedAt: null,
    );
    await saveState();
    notifyListeners();
  }

  /// Completes an item across all active tickets in the prep queue.
  Future<List<int>> completeAggregatedItem(String itemId) async {
    final completedOrderTokens = <int>[];
    final eligibleOrders = rawOrders.where((o) => !o.isCompleted).toList();
    bool stateChanged = false;

    for (final order in eligibleOrders) {
      final pendingQty = order.getPendingQuantity(itemId);
      if (pendingQty > 0) {
        final done = await completeOrderItem(
          token: order.token,
          itemId: itemId,
          quantity: pendingQty,
        );
        stateChanged = true;
        if (done) completedOrderTokens.add(order.token);
      }
    }

    if (stateChanged) {
      await saveState();
      notifyListeners();
    }
    return completedOrderTokens;
  }

  /// Completes an item for the oldest pending ticket (FIFO) in the prep queue.
  Future<({int token, bool isOrderFullyCompleted})?> completeNextTicketForItem(String itemId) async {
    final eligibleOrders = rawOrders.where((o) => !o.isCompleted).toList();
    for (final order in eligibleOrders) {
      final pendingQty = order.getPendingQuantity(itemId);
      if (pendingQty > 0) {
        final orderCompleted = await completeOrderItem(
          token: order.token,
          itemId: itemId,
          quantity: pendingQty,
        );
        return (token: order.token, isOrderFullyCompleted: orderCompleted);
      }
    }
    return null;
  }
}
