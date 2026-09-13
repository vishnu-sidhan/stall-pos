import 'package:flutter/foundation.dart';

/// Represents an individual category option / variant within a category
/// (e.g., 'Steam', 'Fried', 'Pan Fried' for Momos, or 'Veg', 'Chicken' for Rice/Noodles).
@immutable
class CategoryOption {
  final String id;
  final String name;
  final double additionalCost;
  final bool isEnabled;

  const CategoryOption({
    required this.id,
    required this.name,
    this.additionalCost = 0.0,
    this.isEnabled = true,
  });

  /// Formatted helper describing the extra charge if active and > 0, e.g. "+₹10".
  String get costBadge {
    if (!isEnabled || additionalCost <= 0) return '';
    final formatted = additionalCost.toStringAsFixed(
      additionalCost.truncateToDouble() == additionalCost ? 0 : 2,
    );
    return '+₹$formatted';
  }

  CategoryOption copyWith({
    String? id,
    String? name,
    double? additionalCost,
    bool? isEnabled,
  }) {
    return CategoryOption(
      id: id ?? this.id,
      name: name ?? this.name,
      additionalCost: additionalCost ?? this.additionalCost,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'additionalCost': additionalCost,
        'isEnabled': isEnabled,
      };

  factory CategoryOption.fromJson(Map<String, dynamic> map) {
    return CategoryOption(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      additionalCost: (map['additionalCost'] as num?)?.toDouble() ?? 0.0,
      isEnabled: map['isEnabled'] != false,
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
          isEnabled == other.isEnabled;

  @override
  int get hashCode => Object.hash(
        id,
        name.trim().toLowerCase(),
        additionalCost,
        isEnabled,
      );

  @override
  String toString() =>
      'CategoryOption(name: $name, cost: $additionalCost, enabled: $isEnabled)';
}

/// Represents a menu item category and its surcharge / additional cost rules
/// (e.g., container charge, takeaway packaging fee, or multi-category options).
@immutable
class ItemCategory {
  static const general = ItemCategory(id: 'cat_general', name: 'General');

  final String id;
  final String name;
  final String? displayName;
  final double additionalCost;
  final String? costReason;
  final int? colorHex;
  final bool isPerItem;
  final bool isEnabled;

  /// Specific sub-category options with individual charges
  /// (e.g., 'Steam': ₹0, 'Fried': ₹10, 'Pan Fried': ₹20).
  final List<CategoryOption> options;

  const ItemCategory({
    required this.id,
    required this.name,
    this.displayName,
    this.additionalCost = 0.0,
    this.costReason,
    this.colorHex,
    this.isPerItem = true,
    this.isEnabled = true,
    this.options = const [],
  });

  /// Factory helper for instantiating an [ItemCategory] from a simple name string.
  factory ItemCategory.named(String name, {String? displayName, int? colorHex}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'general') {
      if ((displayName != null && displayName.trim().isNotEmpty) || colorHex != null) {
        return ItemCategory.general.copyWith(displayName: displayName, colorHex: colorHex);
      }
      return ItemCategory.general;
    }
    return ItemCategory(
      id: 'cat_${trimmed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
      name: trimmed,
      displayName: displayName,
      colorHex: colorHex,
    );
  }

  /// Short display name for POS screen cards, headings, and brackets.
  /// Falls back to [name] if [displayName] is not explicitly set.
  String get effectiveDisplayName =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!.trim()
          : name.trim();

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
    String? displayName,
    bool clearDisplayName = false,
    double? additionalCost,
    String? costReason,
    bool clearCostReason = false,
    int? colorHex,
    bool clearColor = false,
    bool? isPerItem,
    bool? isEnabled,
    List<CategoryOption>? options,
  }) {
    return ItemCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: clearDisplayName ? null : (displayName ?? this.displayName),
      additionalCost: additionalCost ?? this.additionalCost,
      costReason: clearCostReason ? null : (costReason ?? this.costReason),
      colorHex: clearColor ? null : (colorHex ?? this.colorHex),
      isPerItem: isPerItem ?? this.isPerItem,
      isEnabled: isEnabled ?? this.isEnabled,
      options: options ?? this.options,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (displayName != null && displayName!.trim().isNotEmpty)
          'displayName': displayName!.trim(),
        'additionalCost': additionalCost,
        if (costReason != null && costReason!.trim().isNotEmpty)
          'costReason': costReason!.trim(),
        if (colorHex != null) 'colorHex': colorHex,
        'isPerItem': isPerItem,
        'isEnabled': isEnabled,
        if (options.isNotEmpty)
          'options': options.map((o) => o.toJson()).toList(),
      };

  factory ItemCategory.fromJson(Map<String, dynamic> map) {
    return ItemCategory(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      displayName: map['displayName']?.toString().trim().isNotEmpty == true
          ? map['displayName'].toString().trim()
          : null,
      additionalCost: (map['additionalCost'] as num?)?.toDouble() ?? 0.0,
      costReason: map['costReason']?.toString().trim().isNotEmpty == true
          ? map['costReason'].toString().trim()
          : null,
      colorHex: (map['colorHex'] as num?)?.toInt(),
      isPerItem: map['isPerItem'] != false,
      isEnabled: map['isEnabled'] != false,
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
          displayName == other.displayName &&
          additionalCost == other.additionalCost &&
          costReason == other.costReason &&
          colorHex == other.colorHex &&
          isPerItem == other.isPerItem &&
          isEnabled == other.isEnabled &&
          listEquals(options, other.options);

  @override
  int get hashCode => Object.hash(
        id,
        name.toLowerCase().trim(),
        displayName,
        additionalCost,
        costReason,
        colorHex,
        isPerItem,
        isEnabled,
        Object.hashAll(options),
      );

  @override
  String toString() =>
      'ItemCategory(id: $id, name: $name, displayName: $displayName, options: ${options.length}, additionalCost: $additionalCost, reason: $costReason)';
}
