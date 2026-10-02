import 'package:flutter/foundation.dart';
import 'dietary_type.dart';
import 'order_item.dart';
import 'stall_order.dart';

/// Sales summary of an addon attached to a menu item.
@immutable
class ItemAddonSales {
  final String name;
  final int quantity;
  final double totalRevenue;

  const ItemAddonSales({
    required this.name,
    required this.quantity,
    required this.totalRevenue,
  });
}

/// Aggregated sales metrics for an individual menu item / variant line
/// across completed stall orders.
@immutable
class ItemSalesSummary {
  final String itemKey;
  final String displayName;
  final String baseName;
  final String? variantName;
  final String categoryName;
  final int totalQuantity;
  final double totalRevenue;
  final double baseUnitPrice;
  final double averageUnitPrice;
  final int? colorHex;
  final ItemDietaryType dietaryType;
  final Map<String, int> addonCounts;
  final List<ItemAddonSales> addonsBreakdown;
  final int orderCount;

  const ItemSalesSummary({
    required this.itemKey,
    required this.displayName,
    required this.baseName,
    this.variantName,
    required this.categoryName,
    required this.totalQuantity,
    required this.totalRevenue,
    required this.baseUnitPrice,
    required this.averageUnitPrice,
    this.colorHex,
    this.dietaryType = ItemDietaryType.none,
    this.addonCounts = const {},
    this.addonsBreakdown = const [],
    this.orderCount = 1,
  });

  bool get hasAddons => addonsBreakdown.isNotEmpty || addonCounts.isNotEmpty;

  bool? get isVeg => dietaryType == ItemDietaryType.veg
      ? true
      : (dietaryType == ItemDietaryType.nonVeg ? false : null);

  /// Formatted breakdown string of attached addons (e.g. "2x Extra Cheese, 1x Mayo").
  String get addonSummaryString {
    if (addonsBreakdown.isNotEmpty) {
      return addonsBreakdown
          .map((a) => a.quantity > 1 ? '${a.quantity}x ${a.name}' : a.name)
          .join(', ');
    }
    if (addonCounts.isEmpty) return '';
    return addonCounts.entries
        .map((e) => e.value > 1 ? '${e.value}x ${e.key}' : e.key)
        .join(', ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemSalesSummary &&
          itemKey == other.itemKey &&
          totalQuantity == other.totalQuantity &&
          totalRevenue == other.totalRevenue);

  @override
  int get hashCode => Object.hash(itemKey, totalQuantity, totalRevenue);
}

/// Extension on collections of [StallOrder] to compute itemized sales breakdowns.
extension StallOrdersSalesAggregationExtension on Iterable<StallOrder> {
  /// Aggregates all line items into consolidated [ItemSalesSummary] metrics.
  /// If [completedOnly] is true, only orders marked completed are included.
  List<ItemSalesSummary> aggregateItemSales({bool completedOnly = true}) {
    final Map<String, List<OrderItem>> groups = {};
    final Map<String, int> orderAppearances = {};

    for (final order in this) {
      if (completedOnly && !order.isCompleted) continue;
      final seenInThisOrder = <String>{};

      for (final item in order.items) {
        final key = item.cartKey.isNotEmpty ? item.cartKey : item.itemId;
        groups.putIfAbsent(key, () => []).add(item);
        if (seenInThisOrder.add(key)) {
          orderAppearances[key] = (orderAppearances[key] ?? 0) + 1;
        }
      }
    }

    final result = groups.entries.map((entry) {
      final key = entry.key;
      final items = entry.value;
      final first = items.first;

      final totalQty = items.fold<int>(0, (sum, i) => sum + i.quantity);
      final totalRev = items.fold<double>(0.0, (sum, i) => sum + i.totalPrice);
      final avgPrice = totalQty > 0 ? (totalRev / totalQty) : first.unitPrice;

      final addonCounts = <String, int>{};
      final addonRevenues = <String, double>{};
      for (final it in items) {
        for (final a in it.selectedAddons) {
          final count = 1 * it.quantity;
          addonCounts[a.name] = (addonCounts[a.name] ?? 0) + count;
          addonRevenues[a.name] = (addonRevenues[a.name] ?? 0.0) + ((a.price ?? 0.0) * count);
        }
      }

      final addonsBreakdown = addonCounts.entries.map((e) {
        return ItemAddonSales(
          name: e.key,
          quantity: e.value,
          totalRevenue: addonRevenues[e.key] ?? 0.0,
        );
      }).toList();

      final variantDisplay = first.variantDisplay;
      final cleanDisplayName = (variantDisplay.isNotEmpty &&
              !first.itemName.toLowerCase().contains(variantDisplay.toLowerCase()))
          ? '${first.itemName} ($variantDisplay)'
          : first.itemName;

      return ItemSalesSummary(
        itemKey: key,
        displayName: cleanDisplayName,
        baseName: first.itemName,
        variantName: variantDisplay.isNotEmpty ? variantDisplay : null,
        categoryName: first.category,
        totalQuantity: totalQty,
        totalRevenue: totalRev,
        baseUnitPrice: first.price,
        averageUnitPrice: avgPrice,
        colorHex: first.colorHex,
        dietaryType: first.effectiveDietaryType,
        addonCounts: addonCounts,
        addonsBreakdown: addonsBreakdown,
        orderCount: orderAppearances[key] ?? 1,
      );
    }).toList();

    // Default sort: highest revenue first
    result.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    return result;
  }
}
