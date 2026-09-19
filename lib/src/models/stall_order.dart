import 'package:flutter/foundation.dart';
import 'item_category.dart';
import 'order_item.dart';

/// Immutable domain model representing a customer order ticket in the stall POS.
///
/// Contains pure data variables, copyWith, and JSON serialization. All business calculations,
/// status evaluations, and UI helpers are encapsulated in [StallOrderLifecycleExtension].
@immutable
class StallOrder {
  final int token;
  final DateTime timestamp;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? customerName;
  final bool isPaid;
  final double? explicitPaidAmount;
  final String? paymentMethod;
  final List<OrderItem> items;
  final bool isParcel;
  final String? orderNotes;

  const StallOrder({
    required this.token,
    required this.timestamp,
    this.isCompleted = false,
    this.completedAt,
    this.customerName,
    this.isPaid = false,
    double? paidAmount,
    this.paymentMethod,
    this.items = const [],
    this.isParcel = false,
    this.orderNotes,
  }) : explicitPaidAmount = paidAmount;

  StallOrder copyWith({
    int? token,
    DateTime? timestamp,
    bool? isCompleted,
    DateTime? completedAt,
    String? customerName,
    bool clearCustomerName = false,
    bool? isPaid,
    double? paidAmount,
    String? paymentMethod,
    List<OrderItem>? items,
    bool? isParcel,
    String? orderNotes,
    bool clearOrderNotes = false,
  }) {
    return StallOrder(
      token: token ?? this.token,
      timestamp: timestamp ?? this.timestamp,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      customerName:
          clearCustomerName ? null : (customerName ?? this.customerName),
      isPaid: isPaid ?? this.isPaid,
      paidAmount: paidAmount ?? explicitPaidAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      items: items ?? this.items,
      isParcel: isParcel ?? this.isParcel,
      orderNotes: clearOrderNotes ? null : (orderNotes ?? this.orderNotes),
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'itemsSummary': itemsSummary,
        'total': totalAmount,
        'timestamp': timestamp.toIso8601String(),
        'isCompleted': isCompleted,
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (customerName != null) 'customerName': customerName,
        'isPaid': isPaid,
        'paidAmount': paidAmount,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        'items': items.map((i) => i.toJson()).toList(),
        'paidItems': paidItems,
        if (completedItems.isNotEmpty) 'completedItems': completedItems,
        if (itemSnapshots.isNotEmpty) 'itemSnapshots': itemSnapshots,
        if (isParcel) 'isParcel': isParcel,
        if (orderNotes != null) 'orderNotes': orderNotes,
      };

  factory StallOrder.fromJson(Map<String, dynamic> map) {
    final isPaidVal = map['isPaid'] == true;
    final totalVal = (map['total'] as num?)?.toDouble() ?? 0.0;

    List<OrderItem> parsedItems = [];
    if (map['items'] is List) {
      parsedItems = (map['items'] as List)
          .map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else if (map['items'] is Map) {
      // Backward compatibility parser for legacy maps
      final Map legacyItemsMap = map['items'] as Map;
      final Map legacyPaidMap =
          (map['paidItems'] is Map) ? (map['paidItems'] as Map) : const {};
      final Map legacyCompletedMap =
          (map['completedItems'] is Map) ? (map['completedItems'] as Map) : const {};
      final Map legacySnapshots =
          (map['itemSnapshots'] is Map) ? (map['itemSnapshots'] as Map) : const {};

      final count = legacyItemsMap.length;
      final pricePerItem = count > 0 ? (totalVal / count) : totalVal;

      legacyItemsMap.forEach((k, v) {
        final keyStr = k.toString();
        final qty = (v as num?)?.toInt() ?? 1;
        final snap = legacySnapshots[keyStr] as Map?;
        final name = snap?['name']?.toString() ??
            snap?['displayName']?.toString() ??
            keyStr;
        final cat = snap?['category']?.toString();
        final colorHex = (snap?['colorHex'] as num?)?.toInt();
        final paidQty =
            (legacyPaidMap[keyStr] as num?)?.toInt() ?? (isPaidVal ? qty : 0);
        final completedQty =
            (legacyCompletedMap[keyStr] as num?)?.toInt() ?? 0;
        final isDone = map['isCompleted'] == true || completedQty >= qty;

        CategoryOption? selVar;
        if (keyStr.contains('_var_')) {
          final varName = keyStr.split('_var_')[1].split('_cat_').first.split('+').first;
          if (varName.isNotEmpty) {
            selVar = CategoryOption(id: varName, name: varName);
          }
        }
        final List<CategoryOption> addons = [];
        if (keyStr.contains('+')) {
          for (final aid in keyStr.split('+').skip(1)) {
            if (aid.isNotEmpty) {
              addons.add(CategoryOption(id: aid, name: aid));
            }
          }
        }

        parsedItems.add(OrderItem(
          itemId: keyStr,
          itemName: name,
          price: qty > 0 ? (pricePerItem / qty) : pricePerItem,
          quantity: qty,
          selectedVariant: selVar,
          selectedAddons: addons,
          paidQuantity: paidQty,
          preparationStatus: isDone
              ? ItemPreparationStatus.served
              : ItemPreparationStatus.pending,
          categoryName: cat,
          colorHex: colorHex,
        ));
      });
    }

    if (parsedItems.isEmpty && totalVal > 0) {
      parsedItems = [
        OrderItem(
          itemId: 'item_legacy',
          itemName: map['itemsSummary']?.toString() ?? 'Item',
          price: totalVal,
          quantity: 1,
          paidQuantity: isPaidVal ? 1 : 0,
          preparationStatus: map['isCompleted'] == true
              ? ItemPreparationStatus.served
              : ItemPreparationStatus.pending,
        ),
      ];
    }

    return StallOrder(
      token: (map['token'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      isCompleted: map['isCompleted'] == true,
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'].toString())
          : null,
      customerName: map['customerName']?.toString(),
      isPaid: isPaidVal,
      paidAmount: (map['paidAmount'] as num?)?.toDouble(),
      paymentMethod: map['paymentMethod']?.toString(),
      items: parsedItems,
      isParcel: map['isParcel'] == true,
      orderNotes: map['orderNotes']?.toString() ?? map['notes']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StallOrder &&
          runtimeType == other.runtimeType &&
          token == other.token &&
          timestamp == other.timestamp &&
          isCompleted == other.isCompleted &&
          isPaid == other.isPaid &&
          listEquals(items, other.items));

  @override
  int get hashCode => Object.hash(token, timestamp, isCompleted, isPaid);

  @override
  String toString() =>
      'StallOrder(token: $token, items: ${items.length}, total: ₹$totalAmount, isPaid: $isPaid, isCompleted: $isCompleted)';
}

/// Calculations, presentation helpers, and lifecycle getters for [StallOrder].
extension StallOrderLifecycleExtension on StallOrder {
  /// Dynamic total order amount calculated from all line items.
  double get totalAmount => items.fold(0.0, (sum, i) => sum + i.totalPrice);

  /// Dynamic total paid amount calculated from all paid item quantities or explicit partial payment.
  double get paidAmount {
    if (isPaid) return totalAmount;
    if (explicitPaidAmount != null && explicitPaidAmount! > 0) {
      return explicitPaidAmount!;
    }
    return items.fold(0.0, (sum, i) => sum + i.paidAmount);
  }

  /// Balance remaining to be paid.
  double get remainingAmount => totalAmount - paidAmount;

  /// Total count of all items across lines.
  int get totalItemCount => items.fold(0, (sum, i) => sum + i.quantity);

  /// Whether all items in this order are completely paid for.
  bool get isFullyPaid => items.isNotEmpty && items.every((i) => i.isFullyPaid);

  /// Whether all items in this order are ready or served.
  bool get isAllReady =>
      items.isNotEmpty && items.every((i) => i.isReady || i.isServed);

  /// Whether all items in this order have been served.
  bool get isAllServed =>
      items.isNotEmpty && items.every((i) => i.isServed);

  // --- Aliases and Compatibility Getters ---

  /// Legacy alias for total order amount.
  double get total => totalAmount;

  /// Remaining unpaid balance (clamped to 0).
  double get remainingDue => remainingAmount > 0 ? remainingAmount : 0.0;

  /// Legacy alias for total item count.
  int get totalItemsCount => totalItemCount;

  /// Legacy alias for order token number.
  int get tokenNumber => token;

  /// Count of completed/served items in this order.
  int get completedItemsCount => items
      .where((i) => i.isReady || i.isServed)
      .fold(0, (sum, i) => sum + i.quantity);

  /// Completion progress ratio from 0.0 to 1.0.
  double get completionProgress =>
      totalItemsCount <= 0 ? 0.0 : (completedItemsCount / totalItemsCount).clamp(0.0, 1.0);

  /// Whether all items in this order are completed.
  bool get areAllItemsCompleted => isCompleted || isAllServed;

  /// Whether this order has had a partial payment with remaining balance due.
  bool get hasPartialPayment => paidAmount > 0 && remainingDue > 0;

  /// Formatted items summary string (e.g., "2x Masala Chai, 1x Veg Samosa").
  String get itemsSummary => items.isNotEmpty
      ? items.map((i) => '${i.quantity}x ${i.displayName}').join(', ')
      : '';

  /// Display customer name, defaulting to "Walk-in Customer".
  String get displayCustomerName {
    if (customerName != null && customerName!.trim().isNotEmpty) {
      return customerName!.trim();
    }
    return 'Walk-in Customer';
  }

  /// Whether this order has custom instructions or notes.
  bool get hasNotes => (orderNotes != null && orderNotes!.trim().isNotEmpty);

  /// Human-readable order type label.
  String get orderTypeLabel => isParcel ? 'Parcel' : 'Dine In';

  /// Formatted note combining parcel indicator and custom notes.
  String get effectiveOrderNote => [
        if (isParcel) 'Parcel',
        if (hasNotes) orderNotes!.trim(),
      ].join(' • ');

  /// Returns completed quantity for a specific item id or cartKey.
  int getCompletedQuantity(String itemId) => items
      .where((i) => i.itemId == itemId || i.cartKey == itemId)
      .where((i) => i.isReady || i.isServed)
      .fold(0, (sum, i) => sum + i.quantity);

  /// Returns pending uncompleted quantity for a specific item id or cartKey.
  int getPendingQuantity(String itemId) => items
      .where((i) => i.itemId == itemId || i.cartKey == itemId)
      .where((i) => !i.isReady && !i.isServed)
      .fold(0, (sum, i) => sum + i.quantity);

  /// Returns true if an item is fully completed.
  bool isItemCompleted(String itemId) => getPendingQuantity(itemId) <= 0;

  /// Projections for legacy dictionary maps
  Map<String, int> get legacyItems {
    final map = <String, int>{};
    for (final i in items) {
      map[i.cartKey] = (map[i.cartKey] ?? 0) + i.quantity;
    }
    return map;
  }

  Map<String, int> get paidItems {
    final map = <String, int>{};
    for (final i in items) {
      if (i.paidQuantity > 0) {
        map[i.cartKey] = (map[i.cartKey] ?? 0) + i.paidQuantity;
      }
    }
    return map;
  }

  Map<String, int> get completedItems {
    final map = <String, int>{};
    for (final i in items) {
      if (i.isReady || i.isServed) {
        map[i.cartKey] = (map[i.cartKey] ?? 0) + i.quantity;
      }
    }
    return map;
  }

  Map<String, Map<String, dynamic>> get itemSnapshots => {
        for (final i in items)
          i.cartKey: {
            'name': i.itemName,
            'category': i.category,
            'colorHex': i.colorHex,
            'dietaryType': i.dietaryType.name,
            'displayName': i.displayName,
            if (i.categoryAdditionalCost > 0)
              'categoryAdditionalCost': i.categoryAdditionalCost,
          }
      };
}
