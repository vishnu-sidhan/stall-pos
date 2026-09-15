import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/category_colors.dart';
import 'model_contracts.dart';
export 'model_contracts.dart';

/// Alias for [CategoryOption] matching clean domain naming.
typedef CategoryVariant = CategoryOption;

/// Represents an individual category option / variant within a category or menu item
/// (e.g., 'Steam', 'Fried', 'Pan Fried' for Momos, or 'Regular', 'Large' for Drinks).
@immutable
class CategoryOption with DietaryAware implements IdentifiableEntity {
  @override
  final String id;
  final String name;
  final double additionalCost;
  final double? price;
  final bool isEnabled;
  @override
  final ItemDietaryType? dietaryType;

  const CategoryOption({
    required this.id,
    required this.name,
    this.additionalCost = 0.0,
    this.price,
    this.isEnabled = true,
    this.dietaryType,
  });

  @override
  String get displayName => name;

  /// Alias for item-level availability.
  bool get isAvailable => isEnabled;

  /// Formatted helper describing the price differential or explicit price.
  /// e.g. "₹150" if explicit price is set, or "+₹10" if additionalCost > 0.
  String get costBadge {
    if (!isEnabled) return '';
    if (price != null && price! > 0) {
      final formatted = price!.toStringAsFixed(
        price!.truncateToDouble() == price! ? 0 : 2,
      );
      return '₹$formatted';
    }
    if (additionalCost <= 0) return '';
    final formatted = additionalCost.toStringAsFixed(
      additionalCost.truncateToDouble() == additionalCost ? 0 : 2,
    );
    return '+₹$formatted';
  }

  CategoryOption copyWith({
    String? id,
    String? name,
    double? additionalCost,
    double? price,
    bool clearPrice = false,
    bool? isEnabled,
    bool? isAvailable,
    ItemDietaryType? dietaryType,
    bool clearDietaryType = false,
  }) {
    return CategoryOption(
      id: id ?? this.id,
      name: name ?? this.name,
      additionalCost: additionalCost ?? this.additionalCost,
      price: clearPrice ? null : (price ?? this.price),
      isEnabled: isEnabled ?? isAvailable ?? this.isEnabled,
      dietaryType: clearDietaryType ? null : (dietaryType ?? this.dietaryType),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'additionalCost': additionalCost,
        if (price != null) 'price': price,
        'isEnabled': isEnabled,
        'isAvailable': isEnabled,
        'is_available': isEnabled,
        if (dietaryType != null && dietaryType != ItemDietaryType.none)
          'dietaryType': dietaryType!.code,
      };

  factory CategoryOption.fromJson(Map<String, dynamic> map) {
    final explicitPrice = (map['price'] as num?)?.toDouble();
    final addCost = (map['additionalCost'] as num?)?.toDouble() ?? 0.0;
    final enabled = map['isEnabled'] != false &&
        map['isAvailable'] != false &&
        map['is_available'] != false;
    final dietary = ItemDietaryType.fromString(
      map['dietaryType']?.toString() ??
          map['dietary_type']?.toString() ??
          map['diet']?.toString(),
    );
    return CategoryOption(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      additionalCost: addCost,
      price: explicitPrice,
      isEnabled: enabled,
      dietaryType: dietary != ItemDietaryType.none ? dietary : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryOption &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name.trim().toLowerCase() == other.name.trim().toLowerCase() &&
          additionalCost == other.additionalCost &&
          price == other.price &&
          isEnabled == other.isEnabled &&
          dietaryType == other.dietaryType;

  @override
  int get hashCode => Object.hash(
        id,
        name.trim().toLowerCase(),
        additionalCost,
        price,
        isEnabled,
        dietaryType,
      );

  @override
  String toString() {
    if (price != null) {
      return 'CategoryOption(name: $name, price: $price, enabled: $isEnabled, dietary: $dietaryType)';
    }
    return 'CategoryOption(name: $name, cost: $additionalCost, enabled: $isEnabled, dietary: $dietaryType)';
  }
}

/// Represents a menu item category and its surcharge / additional cost rules
/// (e.g., container charge, takeaway packaging fee, or multi-category options).
@immutable
class ItemCategory with ColorThemed implements IdentifiableEntity {
  static const general = ItemCategory(id: 'cat_general', name: 'General');

  @override
  final String id;
  final String name;
  final double additionalCost;
  final String? costReason;
  @override
  final int? colorHex;
  final bool isEnabled;
  final bool isAddonCategory;

  /// Specific sub-category options with individual charges
  /// (e.g., 'Steam': ₹0, 'Fried': ₹10, 'Pan Fried': ₹20).
  final List<CategoryOption> options;

  const ItemCategory({
    required this.id,
    required this.name,
    this.additionalCost = 0.0,
    this.costReason,
    this.colorHex,
    this.isEnabled = true,
    this.isAddonCategory = false,
    this.options = const [],
  });

  @override
  String get displayName => name;

  /// Factory helper for instantiating an [ItemCategory] from a simple name string.
  factory ItemCategory.named(String name, {int? colorHex, bool isAddonCategory = false}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'general') {
      if (colorHex != null || isAddonCategory) {
        return ItemCategory.general.copyWith(
          colorHex: colorHex,
          isAddonCategory: isAddonCategory,
        );
      }
      return ItemCategory.general;
    }
    return ItemCategory(
      id: 'cat_${trimmed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
      name: trimmed,
      colorHex: colorHex,
      isAddonCategory: isAddonCategory,
    );
  }

  /// Effective hex color value for this category, falling back to dynamic palette color.
  @override
  int get resolvedColorHex =>
      colorHex ?? CategoryColorHelper.getColorForCategory(displayName);

  /// Resolved Material Color for chips, cards, and badges.
  @override
  Color get color => Color(resolvedColorHex);

  /// Checks whether this category matches [otherName], ignoring case and surrounding whitespace.
  bool matches(String otherName) =>
      name.trim().toLowerCase() == otherName.trim().toLowerCase();

  /// Normalizes a category name string into a consistent lowercase slug key.
  static String normalize(String categoryName) =>
      categoryName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

  /// Whether this category has multiple sub-categories or options
  /// (e.g., configured [options] or slash variants like 'Steam / Fried / Pan Fried').
  bool get hasOptions => options.isNotEmpty || name.contains('/');

  /// Returns configured [options] or automatically derives [CategoryOption] instances
  /// by splitting [name] on '/' if [options] is empty.
  List<CategoryOption> get effectiveOptions {
    if (options.isNotEmpty) {
      return options;
    }
    if (name.contains('/')) {
      return name
          .split('/')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map(
            (variant) => CategoryOption(
              id: 'opt_${variant.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
              name: variant,
              additionalCost: 0.0,
              isEnabled: true,
            ),
          )
          .toList();
    }
    return const [];
  }

  /// Resolves the specific additional charge for an option name (e.g. 'Fried' -> 10.0),
  /// falling back to [additionalCost] if no option matches.
  double getOptionCost(String optionName) {
    final trimmed = optionName.trim().toLowerCase();
    for (final opt in effectiveOptions) {
      if (opt.name.trim().toLowerCase() == trimmed) {
        return opt.isEnabled ? opt.additionalCost : 0.0;
      }
    }
    return isEnabled ? additionalCost : 0.0;
  }

  /// Formatted helper describing the extra cost if active and > 0,
  /// e.g. "Fried (+₹10), Pan Fried (+₹20)" or "+₹5 Packaging Fee".
  String get costDescription {
    if (!isEnabled) return '';
    final activeOpts =
        effectiveOptions.where((o) => o.isEnabled && o.additionalCost > 0).toList();
    if (activeOpts.isNotEmpty) {
      return activeOpts
          .map((o) =>
              '${o.name} (+₹${o.additionalCost.toStringAsFixed(o.additionalCost.truncateToDouble() == o.additionalCost ? 0 : 2)})')
          .join(', ');
    }
    if (additionalCost <= 0) return '';
    final formattedCost = additionalCost.toStringAsFixed(
      additionalCost.truncateToDouble() == additionalCost ? 0 : 2,
    );
    if (costReason != null && costReason!.trim().isNotEmpty) {
      return '+₹$formattedCost ${costReason!.trim()}';
    }
    return '+₹$formattedCost';
  }

  /// Whether this category currently has an active additional cost
  /// either globally or across any of its category options.
  bool get hasAdditionalCost {
    if (!isEnabled) return false;
    if (effectiveOptions.any((o) => o.isEnabled && o.additionalCost > 0)) {
      return true;
    }
    return additionalCost > 0;
  }

  ItemCategory copyWith({
    String? id,
    String? name,
    double? additionalCost,
    String? costReason,
    bool clearCostReason = false,
    int? colorHex,
    bool clearColor = false,
    bool? isEnabled,
    bool? isAddonCategory,
    List<CategoryOption>? options,
  }) {
    return ItemCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      additionalCost: additionalCost ?? this.additionalCost,
      costReason: clearCostReason ? null : (costReason ?? this.costReason),
      colorHex: clearColor ? null : (colorHex ?? this.colorHex),
      isEnabled: isEnabled ?? this.isEnabled,
      isAddonCategory: isAddonCategory ?? this.isAddonCategory,
      options: options ?? this.options,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'additionalCost': additionalCost,
        if (costReason != null && costReason!.trim().isNotEmpty)
          'costReason': costReason!.trim(),
        if (colorHex != null) 'colorHex': colorHex,
        'isEnabled': isEnabled,
        if (isAddonCategory) 'isAddonCategory': isAddonCategory,
        if (options.isNotEmpty)
          'options': options.map((o) => o.toJson()).toList(),
      };

  factory ItemCategory.fromJson(Map<String, dynamic> map) {
    return ItemCategory(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      additionalCost: (map['additionalCost'] as num?)?.toDouble() ?? 0.0,
      costReason: map['costReason']?.toString().trim().isNotEmpty == true
          ? map['costReason'].toString().trim()
          : null,
      colorHex: (map['colorHex'] as num?)?.toInt(),
      isEnabled: map['isEnabled'] != false,
      isAddonCategory: map['isAddonCategory'] == true || map['is_addon_category'] == true,
      options: (map['options'] as List<dynamic>?)
              ?.map((e) =>
                  CategoryOption.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemCategory &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name.toLowerCase().trim() == other.name.toLowerCase().trim() &&
          additionalCost == other.additionalCost &&
          costReason == other.costReason &&
          colorHex == other.colorHex &&
          isEnabled == other.isEnabled &&
          isAddonCategory == other.isAddonCategory &&
          listEquals(options, other.options);

  @override
  int get hashCode => Object.hash(
        id,
        name.toLowerCase().trim(),
        additionalCost,
        costReason,
        colorHex,
        isEnabled,
        isAddonCategory,
        Object.hashAll(options),
      );

  @override
  String toString() =>
      'ItemCategory(id: $id, name: $name, options: ${options.length}, additionalCost: $additionalCost, isAddonCategory: $isAddonCategory)';
}

