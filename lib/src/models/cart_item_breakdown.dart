import 'menu_item.dart';

/// Represents an individual add-on entry in an item's price breakdown.
typedef CartItemAddonDetail = ({
  String name,
  int count,
  double singlePrice,
  double totalPrice,
});

/// Represents the monetary breakdown between a base item, its category surcharge, and its linked add-ons.
typedef CartItemBreakdown = ({
  MenuItem baseItem,
  double basePrice,
  double categoryAdditionalCost,
  String? categoryCostReason,
  double addonsPrice,
  double totalUnitPrice,
  List<CartItemAddonDetail> addonDetails,
});

/// Extension providing convenience getters on [CartItemBreakdown].
extension CartItemBreakdownExtension on CartItemBreakdown {
  /// Whether the item includes a category-level surcharge / additional cost.
  bool get hasCategoryCost => categoryAdditionalCost > 0;

  /// Whether the item includes active add-ons.
  bool get hasAddons => addonsPrice > 0 || addonDetails.isNotEmpty;
}
