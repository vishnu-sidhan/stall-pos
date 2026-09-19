import 'package:flutter/foundation.dart';
import 'item_category.dart';
import 'stall_order.dart';

/// Represents the preparation and fulfillment lifecycle status of an ordered item.
enum ItemPreparationStatus {
  pending('Pending'),
  preparing('Preparing'),
  ready('Ready'),
  served('Served');

  final String label;
  const ItemPreparationStatus(this.label);
}

/// Immutable domain model representing a line item in an active POS cart or placed order.
///
/// Contains pure data variables, copyWith, and JSON serialization. All business calculations,
/// pricing math, and display formatting are encapsulated in [OrderItemLifecycleExtension].
@immutable
class OrderItem {
  final String itemId;
  final String itemName;
  final double price;
  final int quantity;
  final CategoryOption? selectedVariant;
  final List<CategoryOption> selectedAddons;
  final double categoryAdditionalCost;
  final String? notes;
  final ItemPreparationStatus preparationStatus;
  final int paidQuantity;
  final String? categoryName;
  final int? colorHex;
  final ItemDietaryType dietaryType;

  const OrderItem({
    required this.itemId,
    required this.itemName,
    required this.price,
    this.quantity = 1,
    this.selectedVariant,
    this.selectedAddons = const [],
    this.categoryAdditionalCost = 0.0,
    this.notes,
    this.preparationStatus = ItemPreparationStatus.pending,
    this.paidQuantity = 0,
    this.categoryName,
    this.colorHex,
    this.dietaryType = ItemDietaryType.none,
  });

  /// Deterministic cart line key for grouping identical item customizations in the cart.
  String get cartKey {
    if (itemId.contains('_var_') || itemId.contains('_cat_') || itemId.contains('+')) {
      if (notes != null && notes!.trim().isNotEmpty && !itemId.contains('__note_')) {
        return '${itemId}__note_${notes!.trim().toLowerCase()}';
      }
      return itemId;
    }
    final buffer = StringBuffer(itemId);
    if (selectedVariant != null) {
      buffer.write('_${selectedVariant!.id}');
    }
    if (selectedAddons.isNotEmpty) {
      final addonParts = selectedAddons.map((a) => a.id).toList()..sort();
      buffer.write('_${addonParts.join('+')}');
    }
    if (notes != null && notes!.trim().isNotEmpty) {
      buffer.write('_${notes!.trim().toLowerCase()}');
    }
    return buffer.toString();
  }

  OrderItem copyWith({
    String? itemId,
    String? itemName,
    double? price,
    int? quantity,
    CategoryOption? selectedVariant,
    bool clearSelectedVariant = false,
    List<CategoryOption>? selectedAddons,
    double? categoryAdditionalCost,
    String? notes,
    bool clearNotes = false,
    ItemPreparationStatus? preparationStatus,
    int? paidQuantity,
    String? categoryName,
    bool clearCategoryName = false,
    int? colorHex,
    bool clearColorHex = false,
    ItemDietaryType? dietaryType,
  }) {
    return OrderItem(
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      selectedVariant: clearSelectedVariant
          ? null
          : (selectedVariant ?? this.selectedVariant),
      selectedAddons: selectedAddons ?? this.selectedAddons,
      categoryAdditionalCost:
          categoryAdditionalCost ?? this.categoryAdditionalCost,
      notes: clearNotes ? null : (notes ?? this.notes),
      preparationStatus: preparationStatus ?? this.preparationStatus,
      paidQuantity: paidQuantity ?? this.paidQuantity,
      categoryName:
          clearCategoryName ? null : (categoryName ?? this.categoryName),
      colorHex: clearColorHex ? null : (colorHex ?? this.colorHex),
      dietaryType: dietaryType ?? this.dietaryType,
    );
  }

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'itemName': itemName,
        'price': price,
        'quantity': quantity,
        if (selectedVariant != null)
          'selectedVariant': selectedVariant!.toJson(),
        if (selectedAddons.isNotEmpty)
          'selectedAddons': selectedAddons.map((a) => a.toJson()).toList(),
        'categoryAdditionalCost': categoryAdditionalCost,
        if (notes != null) 'notes': notes,
        'preparationStatus': preparationStatus.name,
        'paidQuantity': paidQuantity,
        if (categoryName != null) 'categoryName': categoryName,
        if (colorHex != null) 'colorHex': colorHex,
        if (dietaryType != ItemDietaryType.none)
          'dietaryType': dietaryType.name,
      };

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final statusStr = json['preparationStatus']?.toString();
    final status = ItemPreparationStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => ItemPreparationStatus.pending,
    );

    return OrderItem(
      itemId: json['itemId']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      selectedVariant: json['selectedVariant'] != null
          ? CategoryOption.fromJson(
              Map<String, dynamic>.from(json['selectedVariant'] as Map),
            )
          : null,
      selectedAddons: (json['selectedAddons'] as List<dynamic>?)
              ?.map((a) =>
                  CategoryOption.fromJson(Map<String, dynamic>.from(a as Map)))
              .toList() ??
          const [],
      categoryAdditionalCost:
          (json['categoryAdditionalCost'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString(),
      preparationStatus: status,
      paidQuantity: (json['paidQuantity'] as num?)?.toInt() ?? 0,
      categoryName: json['categoryName']?.toString(),
      colorHex: (json['colorHex'] as num?)?.toInt(),
      dietaryType: ItemDietaryType.fromString(json['dietaryType']?.toString()),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrderItem &&
          runtimeType == other.runtimeType &&
          cartKey == other.cartKey &&
          quantity == other.quantity &&
          price == other.price &&
          categoryAdditionalCost == other.categoryAdditionalCost &&
          preparationStatus == other.preparationStatus &&
          paidQuantity == other.paidQuantity);

  @override
  int get hashCode => Object.hash(
        cartKey,
        quantity,
        price,
        categoryAdditionalCost,
        preparationStatus,
        paidQuantity,
      );

  @override
  String toString() =>
      'OrderItem(itemId: $itemId, name: $itemName, qty: $quantity, prep: ${preparationStatus.label}, paidQty: $paidQuantity, cartKey: $cartKey)';
}

/// Calculations, presentation helpers, and lifecycle getters for [OrderItem].
extension OrderItemLifecycleExtension on OrderItem {
  /// Computed unit price including variant differential, category additional cost, and add-ons.
  double get unitPrice =>
      price +
      (selectedVariant?.priceDelta ?? (selectedVariant?.price ?? 0.0)) +
      categoryAdditionalCost +
      selectedAddons.fold(
          0.0,
          (sum, addon) =>
              sum +
              (addon.priceDelta > 0
                  ? addon.priceDelta
                  : (addon.price ?? 0.0)));

  /// Computed total line price for the given [quantity].
  double get totalPrice => unitPrice * quantity;

  /// Total amount already paid for this line item.
  double get paidAmount => unitPrice * paidQuantity;

  /// Remaining unpaid monetary balance for this line item.
  double get remainingAmount => totalPrice - paidAmount;

  /// Whether this item has been completely paid for.
  bool get isFullyPaid => paidQuantity >= quantity;

  /// Alias for backward compatibility with older UI and projections.
  bool get isPaidItem => isFullyPaid;

  /// Whether this item has had a partial payment.
  bool get isPartiallyPaid => paidQuantity > 0 && paidQuantity < quantity;

  /// Whether this item has been marked as ready for pickup / serving.
  bool get isReady => preparationStatus == ItemPreparationStatus.ready;

  /// Whether this item has been served to the customer.
  bool get isServed => preparationStatus == ItemPreparationStatus.served;

  /// Whether this item has reached ready or served fulfillment.
  bool get isCompletedItem => isReady || isServed;

  /// Completed count for fulfillment calculation.
  int get completedQuantity => isCompletedItem ? quantity : 0;

  /// Human-readable variant description.
  String get variantDisplay => selectedVariant?.name ?? '';

  /// Name alias for compatibility with older OrderLineItem callers.
  String get name => itemName;

  /// List of addon names selected for this item.
  List<String> get addonDisplays =>
      selectedAddons.map((a) => a.name).toList();

  /// Normalized category name.
  String get category => categoryName ?? '';

  /// Effective dietary classification.
  ItemDietaryType get effectiveDietaryType {
    if (dietaryType != ItemDietaryType.none) {
      return dietaryType;
    }
    return ItemDietaryType.infer(name: displayName, category: category);
  }

  /// Formatted display name combining item name, addons, variant, and category details.
  String get displayName {
    // If add-ons are present and not in itemName prefix, format addon prefix
    String prefix = '';
    if (selectedAddons.isNotEmpty) {
      final addonCounts = <String, int>{};
      for (final a in selectedAddons) {
        addonCounts[a.name] = (addonCounts[a.name] ?? 0) + 1;
      }
      final parts = addonCounts.entries
          .map((e) => e.value > 1 ? '[${e.value}x ${e.key}]' : '[${e.key}]')
          .join(' ');
      if (!itemName.startsWith('[')) {
        prefix = '$parts ';
      }
    }

    final variantPart = variantDisplay;
    if (variantPart.isNotEmpty &&
        variantPart.toLowerCase() != itemName.toLowerCase()) {
      if (itemName.toLowerCase().contains('(${variantPart.toLowerCase()})') ||
          itemName.toLowerCase().startsWith('${variantPart.toLowerCase()} (')) {
        return '$prefix$itemName'.trim();
      }
      if (category.isNotEmpty &&
          itemName.toLowerCase().contains(category.toLowerCase()) &&
          !variantPart.toLowerCase().contains(category.toLowerCase())) {
        return '$prefix$variantPart ($itemName)'.trim();
      }
      return '$prefix$itemName ($variantPart)'.trim();
    }

    if (category.isNotEmpty && !category.contains('/')) {
      if (!itemName.toLowerCase().endsWith('(${category.toLowerCase()})')) {
        return '$prefix$itemName ($category)'.trim();
      }
    }

    return '$prefix$itemName'.trim();
  }

  /// Total quantity alias.
  int get totalQuantity => quantity;
}

/// Multi-order batch prep aggregation extension on collections of orders.
extension StallOrdersAggregationExtension on Iterable<StallOrder> {
  /// Consolidates and aggregates matching items across multiple orders into grouped prep items.
  List<OrderItem> aggregateOrderItems() {
    final Map<String, List<OrderItem>> groups = {};

    for (final order in this) {
      for (final item in order.items) {
        groups.putIfAbsent(item.cartKey, () => []).add(item);
      }
    }

    final result = groups.values.map((group) {
      final base = group.first;
      final totalQty =
          group.fold<int>(0, (sum, item) => sum + item.quantity);

      return base.copyWith(
        quantity: totalQty,
      );
    }).toList();

    // Sort by quantity descending so highest prep volume is on top
    result.sort((a, b) => b.quantity.compareTo(a.quantity));
    return result;
  }
}
