import 'package:flutter/material.dart';
import 'item_category.dart';

/// Immutable domain model representing a menu item in the catalog.
class MenuItem {
  final String id;
  final String name;
  final double price;
  final ItemCategory category;
  final int? colorHex;
  final List<String> unavailableVariants;
  final List<String> unavailableAddons;
  final ItemDietaryType? dietaryType;

  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.category = ItemCategory.general,
    this.colorHex,
    this.unavailableVariants = const [],
    this.unavailableAddons = const [],
    this.dietaryType,
  });

  /// Effective list of variants/options inherited from category options.
  List<CategoryOption> get variants => effectiveVariants;

  /// Alias for variants.
  List<CategoryOption> get options => effectiveVariants;

  /// Name of the category as a String helper.
  String get categoryName => category.name;

  /// Effective category name.
  String get categoryDisplayName => category.name;

  /// Clean display name for POS cards, order tickets, and receipts.
  String get displayName => name;


  /// Effective dietary classification, falling back to keyword inference.
  ItemDietaryType get effectiveDietaryType {
    if (dietaryType != null && dietaryType != ItemDietaryType.none) {
      return dietaryType!;
    }
    return ItemDietaryType.infer(name: displayName, category: categoryName);
  }

  /// Effective color hex value, resolving to the dynamic category palette if unset.
  int get resolvedColorHex =>
      colorHex ?? ItemCategory.getColorForCategory(displayName);

  /// Material [Color] representation of [resolvedColorHex].
  Color get color => Color(resolvedColorHex);

  /// Display name formatted with the main category name in brackets (e.g. "Veg Momos (Momos)").
  String get displayNameWithCategory {
    final cat = categoryName.trim();
    if (cat.isNotEmpty &&
        cat.toLowerCase() != 'general' &&
        !cat.contains('/') &&
        !name.toLowerCase().endsWith('(${cat.toLowerCase()})')) {
      return '$name ($cat)';
    }
    return name;
  }

  /// Effective list of variants/options. Inherits from category options,
  /// with item-level disabled variants marked as unavailable.
  List<CategoryOption> get effectiveVariants {
    List<CategoryOption> base;
    if (category.effectiveOptions.isNotEmpty) {
      base = category.effectiveOptions;
    } else if (name.contains('/')) {
      final segments = name
          .split('/')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (segments.length > 1) {
        base = segments.map((s) => CategoryOption(id: s, name: s)).toList();
      } else {
        base = const [];
      }
    } else {
      base = const [];
    }

    if (base.isEmpty) return const [];
    if (unavailableVariants.isEmpty) return base;

    final lowerUnavail =
        unavailableVariants.map((u) => u.trim().toLowerCase()).toSet();
    return base.map((opt) {
      if (lowerUnavail.contains(opt.id.trim().toLowerCase()) ||
          lowerUnavail.contains(opt.name.trim().toLowerCase())) {
        return opt.copyWith(isEnabled: false);
      }
      return opt;
    }).toList();
  }

  /// Effective category add-ons, with item-level disabled add-ons marked as unavailable.
  List<CategoryOption> get addons => effectiveAddons;

  /// Effective category add-ons, with item-level disabled add-ons marked as unavailable.
  List<CategoryOption> get effectiveAddons {
    final base = category.addons;
    if (base.isEmpty) return const [];
    if (unavailableAddons.isEmpty) return base;

    final lowerUnavail =
        unavailableAddons.map((u) => u.trim().toLowerCase()).toSet();
    return base.map((addon) {
      if (lowerUnavail.contains(addon.id.trim().toLowerCase()) ||
          lowerUnavail.contains(addon.name.trim().toLowerCase())) {
        return addon.copyWith(isEnabled: false);
      }
      return addon;
    }).toList();
  }

  /// Whether this item has multiple selectable options or variants.
  bool get hasVariants => effectiveVariants.isNotEmpty;

  /// Whether this item has add-ons available.
  bool get hasAddons => effectiveAddons.any((a) => a.isAvailable);

  /// Available add-ons for this item.
  List<CategoryOption> get availableAddons =>
      effectiveAddons.where((a) => a.isAvailable).toList();

  /// Whether this item has any customizations (variants or add-ons).
  bool get hasCustomizations => hasVariants || hasAddons;

  /// Whether the item has at least one selectable variant that is enabled/available.
  bool get hasAvailableVariants =>
      !hasVariants || effectiveVariants.any((v) => v.isAvailable);

  /// Whether this item is available for ordering today.
  /// Evaluates dynamically: not disabled specifically via [unavailableVariants]
  /// and has at least one available variant.
  bool get isAvailable {
    final lowerUnavail =
        unavailableVariants.map((u) => u.trim().toLowerCase()).toSet();
    if (lowerUnavail.contains(id.trim().toLowerCase()) ||
        lowerUnavail.contains(name.trim().toLowerCase())) {
      return false;
    }
    return hasAvailableVariants;
  }

  /// Backwards-compatible alias for [isAvailable].
  bool get isEffectivelyAvailable => isAvailable;

  /// Returns the resolved price for a given variant/option, falling back to [price].
  double priceForVariant(CategoryOption? variant) {
    if (variant == null) return price;
    if (variant.price != null && variant.price! > 0) {
      return variant.price!;
    }
    return price + variant.priceDelta;
  }

  MenuItem copyWith({
    String? id,
    String? name,
    double? price,
    ItemCategory? category,
    int? colorHex,
    bool clearColor = false,
    List<String>? unavailableVariants,
    List<String>? unavailableAddons,
    bool? isAvailable,
    ItemDietaryType? dietaryType,
    bool clearDietaryType = false,
  }) {
    List<String> resolvedUnavailVars =
        unavailableVariants ?? this.unavailableVariants;
    if (isAvailable != null) {
      final list = List<String>.from(resolvedUnavailVars);
      final targetId = id ?? this.id;
      final targetName = name ?? this.name;
      if (isAvailable) {
        list.removeWhere((u) {
          final l = u.trim().toLowerCase();
          return l == targetId.trim().toLowerCase() ||
              l == targetName.trim().toLowerCase();
        });
      } else {
        final alreadyContains = list.any((u) =>
            u.trim().toLowerCase() == targetId.trim().toLowerCase() ||
            u.trim().toLowerCase() == targetName.trim().toLowerCase());
        if (!alreadyContains) {
          list.add(targetId);
        }
      }
      resolvedUnavailVars = list;
    }

    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      colorHex: clearColor ? null : (colorHex ?? this.colorHex),
      unavailableVariants: resolvedUnavailVars,
      unavailableAddons: unavailableAddons ?? this.unavailableAddons,
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
        if (unavailableVariants.isNotEmpty)
          'unavailableVariants': unavailableVariants,
        if (unavailableAddons.isNotEmpty)
          'unavailableAddons': unavailableAddons,
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
        : ItemCategory.parseColor(map['color']);

    final rawVariants = map['variants'] ?? map['options'];
    final parsedVariants = (rawVariants is List)
        ? rawVariants
            .whereType<Map>()
            .map((v) => CategoryOption.fromJson(Map<String, dynamic>.from(v)))
            .toList()
        : const <CategoryOption>[];

    final rawAddons = map['addons'];
    final parsedAddons = (rawAddons is List)
        ? rawAddons
            .whereType<Map>()
            .map((a) => CategoryOption.fromJson(Map<String, dynamic>.from(a)))
            .where((a) {
              final lower = a.name.trim().toLowerCase();
              return lower.isNotEmpty &&
                  lower != 'false' &&
                  lower != 'true' &&
                  lower != 'null' &&
                  lower != 'none' &&
                  lower != '0' &&
                  lower != '1';
            })
            .toList()
        : const <CategoryOption>[];

    if (parsedCategory.addons.isEmpty && parsedAddons.isNotEmpty) {
      parsedCategory = parsedCategory.copyWith(addons: parsedAddons);
    }
    if (parsedCategory.options.isEmpty && parsedVariants.isNotEmpty) {
      parsedCategory = parsedCategory.copyWith(options: parsedVariants);
    }

    final parsedDietary = ItemDietaryType.fromString(
      map['dietaryType']?.toString() ??
          map['dietary_type']?.toString() ??
          map['diet']?.toString(),
    );
    final rawUnavailVariants = map['unavailableVariants'];
    final parsedUnavailableVariants = (rawUnavailVariants is List)
        ? rawUnavailVariants.map((e) => e.toString()).toList()
        : <String>[];

    // Migration: If legacy JSON had isAvailable: false, record id as unavailable variant
    if (map['isAvailable'] == false || map['is_available'] == false) {
      final itemId = map['id']?.toString() ?? '';
      if (itemId.isNotEmpty && !parsedUnavailableVariants.contains(itemId)) {
        parsedUnavailableVariants.add(itemId);
      }
    }

    final rawUnavailAddons = map['unavailableAddons'];
    final parsedUnavailableAddons = (rawUnavailAddons is List)
        ? rawUnavailAddons.map((e) => e.toString()).toList()
        : <String>[];

    return MenuItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      category: parsedCategory,
      colorHex:
          parsedColor ?? ItemCategory.getColorForCategory(parsedCategory.name),
      unavailableVariants: parsedUnavailableVariants,
      unavailableAddons: parsedUnavailableAddons,
      dietaryType: parsedDietary != ItemDietaryType.none ? parsedDietary : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MenuItem && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
