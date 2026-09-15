import 'package:flutter/foundation.dart';
import '../theme/category_colors.dart';
import 'item_category.dart';
export 'item_category.dart';

// Data models for the Stall POS screen and orders.

class MenuItem with DietaryAware, ColorThemed implements CatalogItem {
  @override
  final String id;
  final String name;
  @override
  final double price;
  final ItemCategory category;
  @override
  final int? colorHex;
  final bool isAddon;
  final String? linkedCategory;
  @override
  final bool isAvailable;
  final List<CategoryOption> variants;
  @override
  final ItemDietaryType? dietaryType;

  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.category = ItemCategory.general,
    this.colorHex,
    this.isAddon = false,
    this.linkedCategory,
    this.isAvailable = true,
    this.variants = const [],
    this.dietaryType,
  });

  /// Alias for variants
  List<CategoryOption> get options => variants;

  /// Name of the category as a String helper.
  @override
  String get categoryName => category.name;

  /// Effective category name.
  String get categoryDisplayName => category.name;

  /// Check if this item qualifies as an add-on either via explicit flag,
  /// category-level add-on configuration, or legacy category name keywords.
  bool get effectiveIsAddon {
    if (isAddon || category.isAddonCategory) return true;
    final cat = category.name.toLowerCase();
    return cat.contains('addon') || cat.contains('add-on') || cat == 'extras' || cat == 'extra';
  }

  /// List of target categories this add-on can be linked to.
  /// If [linkedCategory] is explicitly provided, it is parsed (supporting '/' separation).
  /// Defaults to ['All'] for unlinked add-ons.
  List<String> get effectiveLinkedCategories {
    if (linkedCategory != null && linkedCategory!.trim().isNotEmpty) {
      return linkedCategory!
          .split('/')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (category.isAddonCategory) {
      return const ['All'];
    }
    final cat = category.name.toLowerCase().trim();
    if (!cat.contains('addon') &&
        !cat.contains('add-on') &&
        cat != 'extras' &&
        cat != 'extra') {
      return slashCategoryVariants;
    }
    return const ['All'];
  }

  /// Whether this add-on can be attached to items of [targetItemCategory].
  bool isApplicableToCategory(String targetItemCategory) {
    if (!effectiveIsAddon) return false;
    final targetVariants = targetItemCategory
        .split('/')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();
    for (final linked in effectiveLinkedCategories) {
      final l = linked.trim().toLowerCase();
      if (l == 'all' || l == '*') return true;
      if (targetVariants.contains(l)) return true;
    }
    return false;
  }

  /// Clean display name for POS cards, order tickets, and receipts.
  @override
  String get displayName => name;

  /// Backwards-compatible alias for [displayName].
  String get effectiveDisplayName => name;

  /// Display name formatted with the main category name in brackets (e.g. "Veg Momos (Momos)").
  String get displayNameWithCategory {
    final cat = categoryName.trim();
    if (cat.isNotEmpty && !name.toLowerCase().endsWith('(${cat.toLowerCase()})')) {
      return '$name ($cat)';
    }
    return name;
  }

  /// Whether the item name contains '/' indicating multiple or-variants.
  bool get hasSlashNameVariants => name.contains('/');

  /// List of separated variant names when split by '/'.
  List<String> get slashNameVariants {
    if (!hasSlashNameVariants) return [name];
    return name
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Whether the category contains '/' indicating multiple or-categories.
  bool get hasSlashCategoryVariants => category.name.contains('/');

  /// List of separated category names when split by '/'.
  List<String> get slashCategoryVariants {
    if (!hasSlashCategoryVariants) return [category.name];
    return category.name
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Effective list of variants/options. Returns explicit [variants] if defined,
  /// falls back to category options if defined on [category],
  /// or derives options from slash-separated names or categories for seamless backward compatibility.
  List<CategoryOption> get effectiveVariants {
    if (variants.isNotEmpty) {
      return variants;
    }
    if (category.effectiveOptions.isNotEmpty) {
      return category.effectiveOptions;
    }
    if (hasSlashNameVariants) {
      return slashNameVariants
          .map(
            (v) => CategoryOption(
              id: 'var_${v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
              name: v,
              additionalCost: 0.0,
              isEnabled: isAvailable,
            ),
          )
          .toList();
    }
    if (hasSlashCategoryVariants) {
      return slashCategoryVariants
          .map(
            (v) => CategoryOption(
              id: 'cat_${v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
              name: v,
              additionalCost: 0.0,
              isEnabled: isAvailable,
            ),
          )
          .toList();
    }
    return const [];
  }

  /// Whether this item has multiple selectable options or variants.
  bool get hasVariants => effectiveVariants.isNotEmpty;

  /// Whether the item has at least one selectable variant that is enabled/available.
  bool get hasAvailableVariants => !hasVariants || effectiveVariants.any((v) => v.isAvailable);

  /// Whether this item is available for ordering today (both item-level and variant-level).
  bool get isEffectivelyAvailable => isAvailable && hasAvailableVariants;

  /// Returns the resolved price for a given variant/option, falling back to [price].
  double priceForVariant(CategoryOption? variant) {
    if (variant?.price != null && variant!.price! > 0) {
      return variant.price!;
    }
    if (variant != null && variant.additionalCost != 0.0) {
      return price + variant.additionalCost;
    }
    return price;
  }

  /// Whether the item has any '/' variants in name or category.
  bool get hasAnySlashVariants => hasSlashNameVariants || hasSlashCategoryVariants || variants.isNotEmpty;

  /// Backwards-compatible aliases
  bool get hasSlashVariants => hasAnySlashVariants;
  List<String> get slashVariants => effectiveVariants.map((v) => v.name).toList();

  MenuItem copyWith({
    String? id,
    String? name,
    double? price,
    ItemCategory? category,
    int? colorHex,
    bool clearColor = false,
    bool? isAddon,
    String? linkedCategory,
    bool clearLinkedCategory = false,
    bool? isAvailable,
    List<CategoryOption>? variants,
    ItemDietaryType? dietaryType,
    bool clearDietaryType = false,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      colorHex: clearColor ? null : (colorHex ?? this.colorHex),
      isAddon: isAddon ?? this.isAddon,
      linkedCategory: clearLinkedCategory
          ? null
          : (linkedCategory ?? this.linkedCategory),
      isAvailable: isAvailable ?? this.isAvailable,
      variants: variants ?? this.variants,
      dietaryType: clearDietaryType ? null : (dietaryType ?? this.dietaryType),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'category': category.name,
        'categoryObject': category.toJson(),
        if (colorHex != null) 'colorHex': colorHex,
        if (isAddon) 'isAddon': isAddon,
        if (linkedCategory != null && linkedCategory!.trim().isNotEmpty)
          'linkedCategory': linkedCategory,
        'isAvailable': isAvailable,
        if (variants.isNotEmpty)
          'variants': variants.map((v) => v.toJson()).toList(),
        if (dietaryType != null && dietaryType != ItemDietaryType.none)
          'dietaryType': dietaryType!.code,
      };

  factory MenuItem.fromJson(Map<String, dynamic> map) {
    ItemCategory parsedCategory;
    if (map['categoryObject'] is Map) {
      parsedCategory = ItemCategory.fromJson(
        Map<String, dynamic>.from(map['categoryObject'] as Map),
      );
    } else if (map['category'] is Map) {
      parsedCategory = ItemCategory.fromJson(
        Map<String, dynamic>.from(map['category'] as Map),
      );
    } else if (map['category'] is String &&
        (map['category'] as String).trim().isNotEmpty) {
      final raw = (map['category'] as String).trim();
      parsedCategory = ItemCategory(
        id: 'cat_${raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
        name: raw,
      );
    } else {
      parsedCategory = ItemCategory.general;
    }

    final parsedColor = map['colorHex'] != null
        ? (map['colorHex'] as num?)?.toInt()
        : CategoryColorHelper.parseColor(map['color']);
    final isAddonExplicit = map['isAddon'] == true || map['is_addon'] == true;
    final linkedCategoryRaw = map['linkedCategory']?.toString().trim() ??
        map['targetCategory']?.toString().trim() ??
        map['linked_category']?.toString().trim();
    final linkedCategory = (linkedCategoryRaw != null && linkedCategoryRaw.isNotEmpty)
        ? linkedCategoryRaw
        : null;

    final rawVariants = map['variants'] ?? map['options'];
    final parsedVariants = (rawVariants is List)
        ? rawVariants
        .whereType<Map>()
        .map((v) => CategoryOption.fromJson(Map<String, dynamic>.from(v)))
        .toList()
        : const <CategoryOption>[];

    final parsedDietary = ItemDietaryType.fromString(
      map['dietaryType']?.toString() ??
          map['dietary_type']?.toString() ??
          map['diet']?.toString(),
    );

    return MenuItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      category: parsedCategory,
      colorHex: parsedColor ?? CategoryColorHelper.getColorForCategory(parsedCategory.name),
      isAddon: isAddonExplicit,
      linkedCategory: linkedCategory,
      isAvailable: map['isAvailable'] != false && map['is_available'] != false,
      variants: parsedVariants,
      dietaryType: parsedDietary != ItemDietaryType.none ? parsedDietary : null,
    );
  }

}

class StallOrder {
  final int token;
  final String itemsSummary;
  final double total;
  final DateTime timestamp;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? customerName;
  final bool isPaid;
  final String? paymentMethod;
  final Map<String, int> items;
  final double paidAmount;
  final Map<String, int> paidItems;
  final Map<String, int> completedItems;
  final Map<String, Map<String, dynamic>> itemSnapshots;
  final bool isParcel;
  final String? orderNotes;

  StallOrder({
    required this.token,
    required this.itemsSummary,
    required this.total,
    required this.timestamp,
    this.isCompleted = false,
    this.completedAt,
    this.customerName,
    this.isPaid = false,
    this.paymentMethod,
    this.items = const {},
    this.paidAmount = 0.0,
    this.paidItems = const {},
    this.completedItems = const {},
    this.itemSnapshots = const {},
    this.isParcel = false,
    this.orderNotes,
  });

  String get displayCustomerName {
    if (customerName != null && customerName!.trim().isNotEmpty) {
      return customerName!.trim();
    }
    return 'Walk-in Customer';
  }

  /// Whether this order has custom instructions or notes
  bool get hasNotes => (orderNotes != null && orderNotes!.trim().isNotEmpty);

  /// Human-readable order type label
  String get orderTypeLabel => isParcel ? 'Parcel' : 'Dine In';

  /// Formatted note including parcel indication and any custom instructions
  String get effectiveOrderNote => [
        if (isParcel) 'Parcel',
        if (hasNotes) orderNotes!.trim(),
      ].join(' • ');

  /// Balance amount remaining to be paid
  double get remainingDue => (total - paidAmount) > 0 ? (total - paidAmount) : 0.0;

  /// Whether this order has had a previous payment but still has an unpaid balance
  bool get hasPartialPayment => paidAmount > 0 && remainingDue > 0;

  /// Whether this order is completely paid
  bool get isFullyPaid => isPaid && remainingDue == 0;

  /// Returns the completed quantity for a specific item.
  int getCompletedQuantity(String itemId) {
    if (isCompleted) {
      return items[itemId] ?? 0;
    }
    return completedItems[itemId] ?? 0;
  }

  /// Returns remaining uncompleted quantity for a specific item.
  int getPendingQuantity(String itemId) {
    final total = items[itemId] ?? 0;
    final completed = getCompletedQuantity(itemId);
    return (total - completed) > 0 ? (total - completed) : 0;
  }

  /// Returns true if an item is fully completed.
  bool isItemCompleted(String itemId) {
    return getPendingQuantity(itemId) <= 0;
  }

  /// Returns true if all items in this order are completed.
  bool get areAllItemsCompleted {
    if (isCompleted) return true;
    if (items.isEmpty) return false;
    for (final entry in items.entries) {
      if ((completedItems[entry.key] ?? 0) < entry.value) {
        return false;
      }
    }
    return true;
  }

  /// Total count of all items in this order.
  int get totalItemsCount => items.values.fold<int>(0, (sum, q) => sum + q);

  /// Total count of completed items in this order.
  int get completedItemsCount {
    if (isCompleted) return totalItemsCount;
    int count = 0;
    for (final entry in items.entries) {
      final done = completedItems[entry.key] ?? 0;
      count += (done > entry.value) ? entry.value : done;
    }
    return count;
  }

  /// Completion progress ratio from 0.0 to 1.0.
  double get completionProgress {
    if (isCompleted) return 1.0;
    final total = totalItemsCount;
    if (total <= 0) return 0.0;
    return (completedItemsCount / total).clamp(0.0, 1.0);
  }

  StallOrder copyWith({
    int? token,
    String? itemsSummary,
    double? total,
    DateTime? timestamp,
    bool? isCompleted,
    DateTime? completedAt,
    String? customerName,
    bool clearCustomerName = false,
    bool? isPaid,
    String? paymentMethod,
    Map<String, int>? items,
    double? paidAmount,
    Map<String, int>? paidItems,
    Map<String, int>? completedItems,
    Map<String, Map<String, dynamic>>? itemSnapshots,
    bool? isParcel,
    String? orderNotes,
    bool clearOrderNotes = false,
  }) {
    return StallOrder(
      token: token ?? this.token,
      itemsSummary: itemsSummary ?? this.itemsSummary,
      total: total ?? this.total,
      timestamp: timestamp ?? this.timestamp,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      customerName: clearCustomerName ? null : (customerName ?? this.customerName),
      isPaid: isPaid ?? this.isPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      items: items ?? this.items,
      paidAmount: paidAmount ?? this.paidAmount,
      paidItems: paidItems ?? this.paidItems,
      completedItems: completedItems ?? this.completedItems,
      itemSnapshots: itemSnapshots ?? this.itemSnapshots,
      isParcel: isParcel ?? this.isParcel,
      orderNotes: clearOrderNotes ? null : (orderNotes ?? this.orderNotes),
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'itemsSummary': itemsSummary,
        'total': total,
        'timestamp': timestamp.toIso8601String(),
        'isCompleted': isCompleted,
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (customerName != null) 'customerName': customerName,
        'isPaid': isPaid,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        'items': items,
        'paidAmount': paidAmount,
        'paidItems': paidItems,
        if (completedItems.isNotEmpty) 'completedItems': completedItems,
        if (itemSnapshots.isNotEmpty) 'itemSnapshots': itemSnapshots,
        if (isParcel) 'isParcel': isParcel,
        if (orderNotes != null) 'orderNotes': orderNotes,
      };

  factory StallOrder.fromJson(Map<String, dynamic> map) {
    Map<String, int> parsedItems = {};
    if (map['items'] is Map) {
      (map['items'] as Map).forEach((k, v) {
        if (v is num) {
          parsedItems[k.toString()] = v.toInt();
        }
      });
    }

    final isPaidVal = map['isPaid'] == true;
    final totalVal = (map['total'] as num?)?.toDouble() ?? 0.0;
    final paidAmountVal = (map['paidAmount'] as num?)?.toDouble() ?? (isPaidVal ? totalVal : 0.0);

    Map<String, int> parsedPaidItems = {};
    if (map['paidItems'] is Map) {
      (map['paidItems'] as Map).forEach((k, v) {
        if (v is num) {
          parsedPaidItems[k.toString()] = v.toInt();
        }
      });
    } else if (isPaidVal) {
      parsedPaidItems = Map.from(parsedItems);
    }

    Map<String, int> parsedCompletedItems = {};
    if (map['completedItems'] is Map) {
      (map['completedItems'] as Map).forEach((k, v) {
        if (v is num) {
          parsedCompletedItems[k.toString()] = v.toInt();
        }
      });
    } else if (map['isCompleted'] == true) {
      parsedCompletedItems = Map.from(parsedItems);
    }

    Map<String, Map<String, dynamic>> parsedSnapshots = {};
    if (map['itemSnapshots'] is Map) {
      (map['itemSnapshots'] as Map).forEach((k, v) {
        if (v is Map) {
          parsedSnapshots[k.toString()] = Map<String, dynamic>.from(v);
        }
      });
    }

    return StallOrder(
      token: (map['token'] as num?)?.toInt() ?? 0,
      itemsSummary: map['itemsSummary']?.toString() ?? '',
      total: totalVal,
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
      isCompleted: map['isCompleted'] == true,
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'].toString())
          : null,
      customerName: map['customerName']?.toString(),
      isPaid: isPaidVal,
      paymentMethod: map['paymentMethod']?.toString(),
      items: parsedItems,
      paidAmount: paidAmountVal,
      paidItems: parsedPaidItems,
      completedItems: parsedCompletedItems,
      itemSnapshots: parsedSnapshots,
      isParcel: map['isParcel'] == true,
      orderNotes: map['orderNotes']?.toString() ?? map['notes']?.toString(),
    );
  }
}

/// Ticket contribution to an aggregated item in the consolidated kitchen prep queue.
typedef OrderTicketQuantity = ({
  int token,
  int quantity,
  bool isParcel,
  String? orderNotes,
});

/// Aggregated item across active orders for kitchen consolidated prep.
typedef AggregatedOrderItem = ({
  String itemId,
  String itemName,
  String displayName,
  String category,
  int totalQuantity,
  List<OrderTicketQuantity> tickets,
  int? colorHex,
  ItemDietaryType effectiveDietaryType,
});

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

/// Represents a structured order line item with preparation and payment state.
@immutable
class OrderLineItem with DietaryAware, ColorThemed implements PreparationItem {
  @override
  String get id => itemId;

  final String itemId;
  final String name;
  final int quantity;
  final int completedQuantity;
  final bool isCompletedItem;
  @override
  final String category;
  @override
  final int? colorHex;
  @override
  final String displayName;
  final bool isPaidItem;
  @override
  final ItemDietaryType? dietaryType;

  const OrderLineItem({
    required this.itemId,
    required this.name,
    required this.quantity,
    this.completedQuantity = 0,
    this.isCompletedItem = false,
    required this.category,
    this.colorHex,
    required this.displayName,
    this.isPaidItem = false,
    this.dietaryType,
  });

  @override
  String get categoryName => category;

  /// Pending quantity awaiting preparation.
  int get pendingQuantity =>
      (quantity - completedQuantity).clamp(0, quantity);

  /// Whether there are pending items to prepare.
  bool get hasPending => pendingQuantity > 0;

  /// Whether this line item has been completely prepared.
  bool get isFullyCompleted => completedQuantity >= quantity;

  OrderLineItem copyWith({
    String? itemId,
    String? name,
    int? quantity,
    int? completedQuantity,
    bool? isCompletedItem,
    String? category,
    int? colorHex,
    String? displayName,
    bool? isPaidItem,
    ItemDietaryType? dietaryType,
  }) {
    return OrderLineItem(
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      completedQuantity: completedQuantity ?? this.completedQuantity,
      isCompletedItem: isCompletedItem ?? this.isCompletedItem,
      category: category ?? this.category,
      colorHex: colorHex ?? this.colorHex,
      displayName: displayName ?? this.displayName,
      isPaidItem: isPaidItem ?? this.isPaidItem,
      dietaryType: dietaryType ?? this.dietaryType,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderLineItem &&
          runtimeType == other.runtimeType &&
          itemId == other.itemId &&
          name == other.name &&
          quantity == other.quantity &&
          completedQuantity == other.completedQuantity &&
          isCompletedItem == other.isCompletedItem &&
          category == other.category &&
          colorHex == other.colorHex &&
          displayName == other.displayName &&
          isPaidItem == other.isPaidItem &&
          dietaryType == other.dietaryType;

  @override
  int get hashCode => Object.hash(
        itemId,
        name,
        quantity,
        completedQuantity,
        isCompletedItem,
        category,
        colorHex,
        displayName,
        isPaidItem,
        dietaryType,
      );
}

/// Alias for [StallOrder] matching clean domain naming.
typedef Order = StallOrder;

/// Alias for [OrderLineItem] matching clean domain naming.
typedef OrderItem = OrderLineItem;

