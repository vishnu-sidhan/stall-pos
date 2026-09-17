import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'model_contracts.dart';
export 'model_contracts.dart';

/// Alias for [CategoryOption] matching clean domain naming.
typedef CategoryVariant = CategoryOption;

/// Represents an individual category option, variant, or add-on
/// (e.g., 'Steam', 'Fried', 'Pan Fried' for Momos, or 'Extra Cheese' for a Burger).
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
    double additionalCost = 0.0,
    double? priceDelta,
    this.price,
    this.isEnabled = true,
    this.dietaryType,
  }) : additionalCost = priceDelta ?? additionalCost;

  @override
  String get displayName => name;

  /// Price adjustment or differential for this variant/add-on.
  double get priceDelta => price != null && price! > 0 ? price! : additionalCost;

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
    double? priceDelta,
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
      additionalCost: priceDelta ?? additionalCost ?? this.additionalCost,
      price: clearPrice ? null : (price ?? this.price),
      isEnabled: isEnabled ?? isAvailable ?? this.isEnabled,
      dietaryType: clearDietaryType ? null : (dietaryType ?? this.dietaryType),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'additionalCost': additionalCost,
        'additional_cost': additionalCost,
        'priceDelta': additionalCost,
        'price_delta': additionalCost,
        if (price != null) 'price': price,
        'isEnabled': isEnabled,
        'isAvailable': isEnabled,
        'is_available': isEnabled,
        if (dietaryType != null && dietaryType != ItemDietaryType.none)
          'dietaryType': dietaryType!.code,
      };

  factory CategoryOption.fromJson(Map<String, dynamic> map) {
    final explicitPrice = (map['price'] as num?)?.toDouble();
    final addCost = (map['additionalCost'] as num?)?.toDouble() ??
        (map['additional_cost'] as num?)?.toDouble() ??
        (map['priceDelta'] as num?)?.toDouble() ??
        (map['price_delta'] as num?)?.toDouble() ??
        0.0;
    final enabled = map['isEnabled'] != false &&
        map['isAvailable'] != false &&
        map['is_available'] != false;
    final dietary = ItemDietaryType.fromString(
      map['dietaryType']?.toString() ??
          map['dietary_type']?.toString() ??
          map['diet']?.toString(),
    );
    return CategoryOption(
      id: map['id']?.toString() ??
          'opt_${(map['name'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
      name: map['name']?.toString() ?? '',
      additionalCost: addCost,
      price: explicitPrice,
      isEnabled: enabled,
      dietaryType: dietary != ItemDietaryType.none ? dietary : null,
    );
  }

  static const Set<String> _ignoredVariantNames = {
    'false',
    'true',
    'null',
    'none',
    '0',
    '1',
    'no',
    'yes',
  };

  /// Parses pipe-separated variant or add-on strings.
  /// Format: `"Steam Momos|Fried Momos:+10|Pan Fried Momos:+20|Kurkure Momos:+30"`
  static List<CategoryOption> parseVariants(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final trimmed = raw.trim();
    if (_ignoredVariantNames.contains(trimmed.toLowerCase())) return const [];
    final result = <CategoryOption>[];
    final parts = trimmed.split('|');
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i].trim();
      if (part.isEmpty) continue;
      final colonIdx = part.indexOf(':');
      if (colonIdx == -1) {
        if (_ignoredVariantNames.contains(part.toLowerCase())) continue;
        result.add(CategoryOption(
          id: 'opt_${part.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
          name: part,
          additionalCost: 0.0,
        ));
      } else {
        final optName = part.substring(0, colonIdx).trim();
        if (_ignoredVariantNames.contains(optName.toLowerCase())) continue;
        final costStr = part.substring(colonIdx + 1).trim();
        double cost = 0.0;
        double? explicitPrice;
        if (costStr.startsWith('+')) {
          cost = double.tryParse(costStr.substring(1).trim()) ?? 0.0;
        } else if (costStr.startsWith('-')) {
          cost = -(double.tryParse(costStr.substring(1).trim()) ?? 0.0);
        } else {
          final parsed = double.tryParse(costStr);
          if (parsed != null) {
            explicitPrice = parsed;
          }
        }
        result.add(CategoryOption(
          id: 'opt_${optName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
          name: optName,
          additionalCost: cost,
          price: explicitPrice,
        ));
      }
    }
    return result;
  }

  /// Formats a list of [CategoryOption]s back into pipe-delimited string format.
  static String formatVariants(List<CategoryOption> options) {
    return options.map((opt) {
      if (opt.price != null && opt.price! > 0) {
        final formatted = opt.price!.toStringAsFixed(
          opt.price!.truncateToDouble() == opt.price! ? 0 : 2,
        );
        return '${opt.name}:$formatted';
      }
      if (opt.additionalCost > 0) {
        final formatted = opt.additionalCost.toStringAsFixed(
          opt.additionalCost.truncateToDouble() == opt.additionalCost ? 0 : 2,
        );
        return '${opt.name}:+$formatted';
      }
      return opt.name;
    }).join('|');
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

/// Represents a menu item category and its packaging/prep charge rules.
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

  /// Specific sub-category options / variants with individual charges
  /// (e.g., 'Steam': ₹0, 'Fried': ₹10, 'Pan Fried': ₹20).
  final List<CategoryOption> options;

  /// Specific cumulative add-ons available for this category
  /// (e.g., 'Extra Cheese': ₹20, 'Mayo': ₹15, 'Peri Peri Dip': ₹20).
  final List<CategoryOption> addons;

  const ItemCategory({
    required this.id,
    required this.name,
    this.additionalCost = 0.0,
    this.costReason,
    this.colorHex,
    this.isEnabled = true,
    this.isAddonCategory = false,
    List<CategoryOption> options = const [],
    List<CategoryOption>? categoryVariants,
    this.addons = const [],
  }) : options = categoryVariants ?? options;

  @override
  String get displayName => name;

  /// Alias for category-wide variants / options.
  List<CategoryOption> get categoryVariants => options;

  /// Factory helper for instantiating an [ItemCategory] from a simple name string.
  factory ItemCategory.named(
    String name, {
    int? colorHex,
    List<CategoryOption>? options,
    List<CategoryOption>? addons,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'general') {
      if (colorHex != null || options != null || addons != null) {
        return ItemCategory.general.copyWith(
          colorHex: colorHex,
          options: options,
          addons: addons,
        );
      }
      return ItemCategory.general;
    }
    return ItemCategory(
      id: 'cat_${trimmed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
      name: trimmed,
      colorHex: colorHex,
      options: options ?? const [],
      addons: addons ?? const [],
    );
  }

  /// Effective hex color value for this category, falling back to dynamic palette color.
  @override
  int get resolvedColorHex =>
      colorHex ?? getColorForCategory(displayName);

  /// Resolved Material Color for chips, cards, and badges.
  @override
  Color get color => Color(resolvedColorHex);

  /// Checks whether this category matches [otherName], ignoring case and surrounding whitespace.
  bool matches(String otherName) =>
      name.trim().toLowerCase() == otherName.trim().toLowerCase();

  /// Normalizes a category name string into a consistent lowercase slug key.
  static String normalize(String categoryName) =>
      categoryName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

  /// Whether this category has configured options/variants or slashed sub-categories.
  bool get hasOptions => effectiveOptions.isNotEmpty;

  /// Effective options/variants list for this category.
  /// If explicit [options] are defined, returns [options].
  /// Otherwise, if category name contains '/', parses each segment as a sub-category option.
  List<CategoryOption> get effectiveOptions {
    if (options.isNotEmpty) return options;
    if (name.contains('/')) {
      final segments = name
          .split('/')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (segments.length > 1) {
        return segments
            .map((s) => CategoryOption(
                  id: 'opt_${normalize(s)}',
                  name: s,
                  additionalCost: 0.0,
                ))
            .toList();
      }
    }
    return const [];
  }

  /// Resolves the specific additional charge for an option name (e.g. 'Fried' -> 10.0),
  /// falling back to [additionalCost] if no option matches.
  double getOptionCost(String optionName) {
    final trimmed = optionName.trim().toLowerCase();
    for (final opt in options) {
      if (opt.name.trim().toLowerCase() == trimmed) {
        return opt.isEnabled ? opt.additionalCost : 0.0;
      }
    }
    return isEnabled ? additionalCost : 0.0;
  }

  /// Formatted helper describing extra costs.
  String get costDescription {
    if (!isEnabled) return '';
    final activeOpts =
        options.where((o) => o.isEnabled && o.additionalCost > 0).toList();
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

  /// Whether this category currently has an active additional cost.
  bool get hasAdditionalCost {
    if (!isEnabled) return false;
    if (options.any((o) => o.isEnabled && o.additionalCost > 0)) {
      return true;
    }
    return additionalCost > 0;
  }

  /// Whether this category has add-ons available.
  bool get hasAddons => addons.any((a) => a.isAvailable);

  /// Available add-ons for this category.
  List<CategoryOption> get availableAddons =>
      addons.where((a) => a.isAvailable).toList();

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
    List<CategoryOption>? categoryVariants,
    List<CategoryOption>? addons,
  }) {
    return ItemCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      additionalCost: additionalCost ?? this.additionalCost,
      costReason: clearCostReason ? null : (costReason ?? this.costReason),
      colorHex: clearColor ? null : (colorHex ?? this.colorHex),
      isEnabled: isEnabled ?? this.isEnabled,
      isAddonCategory: isAddonCategory ?? this.isAddonCategory,
      options: categoryVariants ?? options ?? this.options,
      addons: addons ?? this.addons,
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
        if (isAddonCategory) 'isAddonCategory': true,
        if (options.isNotEmpty)
          'options': options.map((o) => o.toJson()).toList(),
        if (addons.isNotEmpty)
          'addons': addons.map((a) => a.toJson()).toList(),
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
      isAddonCategory: map['isAddonCategory'] == true,
      options: (map['options'] as List<dynamic>? ?? map['categoryVariants'] as List<dynamic>?)
              ?.map((e) =>
                  CategoryOption.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      addons: (map['addons'] as List<dynamic>?)
              ?.map((e) =>
                  CategoryOption.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }

  // --- Category Color Palette & Methods (Consolidated) ---

  /// Curated 16-color palette with high perceptual contrast.
  static const List<int> palette = [
    0xFF1D4ED8, // 1. Royal Blue
    0xFF059669, // 2. Emerald Green
    0xFFEA580C, // 3. Vivid Orange
    0xFFDC2626, // 4. Crimson Red
    0xFF7C3AED, // 5. Violet Purple
    0xFFD97706, // 6. Amber Gold
    0xFFE11D48, // 7. Rose Pink
    0xFF0F766E, // 8. Deep Teal
    0xFF0284C7, // 9. Cyan Sky
    0xFF65A30D, // 10. Bright Lime
    0xFFC026D3, // 11. Magenta Fuchsia
    0xFF78350F, // 12. Warm Chocolate
    0xFF831843, // 13. Deep Berry Plum
    0xFF3730A3, // 14. Dark Indigo
    0xFF3F6212, // 15. Olive Green
    0xFF334155, // 16. Slate Navy
  ];

  static const Map<String, int> namedColorMap = {
    'blue': 0xFF1D4ED8,
    'royal blue': 0xFF1D4ED8,
    'sapphire': 0xFF1D4ED8,
    'emerald': 0xFF059669,
    'green': 0xFF059669,
    'sunset': 0xFFEA580C,
    'orange': 0xFFEA580C,
    'crimson': 0xFFDC2626,
    'red': 0xFFDC2626,
    'violet': 0xFF7C3AED,
    'purple': 0xFF7C3AED,
    'teal': 0xFF0F766E,
    'amber': 0xFFD97706,
    'yellow': 0xFFD97706,
    'gold': 0xFFD97706,
    'rose': 0xFFE11D48,
    'pink': 0xFFE11D48,
    'indigo': 0xFF3730A3,
    'cyan': 0xFF0284C7,
    'sky': 0xFF0284C7,
    'fuchsia': 0xFFC026D3,
    'magenta': 0xFFC026D3,
    'lime': 0xFF65A30D,
    'brown': 0xFF78350F,
    'chocolate': 0xFF78350F,
    'plum': 0xFF831843,
    'berry': 0xFF831843,
    'olive': 0xFF3F6212,
    'slate': 0xFF334155,
    'gray': 0xFF334155,
    'grey': 0xFF334155,
  };

  /// Calculates the weighted Euclidean (redmean) perceptual color distance.
  static double colorDistance(int hex1, int hex2) {
    final r1 = (hex1 >> 16) & 0xFF;
    final g1 = (hex1 >> 8) & 0xFF;
    final b1 = hex1 & 0xFF;

    final r2 = (hex2 >> 16) & 0xFF;
    final g2 = (hex2 >> 8) & 0xFF;
    final b2 = hex2 & 0xFF;

    final rmean = (r1 + r2) / 2.0;
    final dr = r1 - r2;
    final dg = g1 - g2;
    final db = b1 - b2;

    return sqrt(
      (2.0 + rmean / 256.0) * dr * dr +
      4.0 * dg * dg +
      (2.0 + (255.0 - rmean) / 256.0) * db * db,
    );
  }

  static bool _isVisuallyDistinct(int candidate, Set<int> existingColors, {double minDistance = 75.0}) {
    for (final existing in existingColors) {
      if (colorDistance(candidate, existing) < minDistance) {
        return false;
      }
    }
    return true;
  }

  /// Returns a guaranteed unique, visually distinct color that has not been used yet.
  static int getUniqueColor({
    String? categoryName,
    required Set<int> usedColors,
  }) {
    final available = palette.where((c) => !usedColors.contains(c)).toList();

    if (available.isNotEmpty) {
      if (categoryName != null && categoryName.trim().isNotEmpty) {
        final trimmed = categoryName.trim().toLowerCase();
        final startIdx = trimmed.codeUnits
            .fold<int>(5381, (prev, c) => ((prev << 5) + prev) ^ c)
            .abs() % available.length;

        for (int i = 0; i < available.length; i++) {
          final candidate = available[(startIdx + i) % available.length];
          if (_isVisuallyDistinct(candidate, usedColors, minDistance: 80.0)) {
            return candidate;
          }
        }
      }

      int bestCandidate = available.first;
      double maxMinDist = -1.0;

      for (final candidate in available) {
        if (usedColors.isEmpty) return candidate;
        double minDist = double.infinity;
        for (final used in usedColors) {
          final dist = colorDistance(candidate, used);
          if (dist < minDist) minDist = dist;
        }
        if (minDist > maxMinDist) {
          maxMinDist = minDist;
          bestCandidate = candidate;
        }
      }

      return bestCandidate;
    }

    const phiAngle = 137.507764;
    double baseHue = 217.0;
    if (categoryName != null && categoryName.trim().isNotEmpty) {
      baseHue = (categoryName.trim().toLowerCase().hashCode.abs() % 360).toDouble();
    }

    for (int step = 1; step <= 100; step++) {
      final hue = (baseHue + step * phiAngle) % 360.0;
      final saturation = 0.75 + (step % 3) * 0.10;
      final value = 0.80 - ((step ~/ 3) % 3) * 0.10;
      final generatedColor = HSVColor.fromAHSV(1.0, hue, saturation.clamp(0.0, 1.0), value.clamp(0.0, 1.0)).toColor();
      final colorHex = 0xFF000000 | (generatedColor.toARGB32() & 0x00FFFFFF);

      if (_isVisuallyDistinct(colorHex, usedColors, minDistance: 70.0)) {
        return colorHex;
      }
    }

    final fallbackHue = (baseHue + Random().nextDouble() * 360.0) % 360.0;
    final fallbackColor = HSVColor.fromAHSV(1.0, fallbackHue, 0.80, 0.75).toColor();
    return 0xFF000000 | (fallbackColor.toARGB32() & 0x00FFFFFF);
  }

  /// Resolves an integer color hex for a category name.
  static int getColorForCategory(String? categoryName, {int? explicitColor}) {
    if (explicitColor != null && explicitColor != 0) {
      return explicitColor;
    }
    if (categoryName == null || categoryName.trim().isEmpty) {
      return palette.first;
    }
    final normalized = categoryName.trim().toLowerCase();
    if (namedColorMap.containsKey(normalized)) {
      return namedColorMap[normalized]!;
    }
    int hash = 5381;
    for (final unit in normalized.codeUnits) {
      hash = ((hash << 5) + hash) ^ unit;
    }
    final index = hash.abs() % palette.length;
    return palette[index];
  }

  /// Parses a color from dynamic input (hex string, integer, or named color).
  static int? parseColor(dynamic rawColor) {
    if (rawColor == null) return null;
    if (rawColor is int) return rawColor;
    final str = rawColor.toString().trim().toLowerCase();
    if (str.isEmpty) return null;

    if (namedColorMap.containsKey(str)) {
      return namedColorMap[str];
    }
    String cleanHex = str;
    if (cleanHex.startsWith('#')) {
      cleanHex = cleanHex.substring(1);
    } else if (cleanHex.startsWith('0x')) {
      cleanHex = cleanHex.substring(2);
    }
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    }
    if (cleanHex.length == 8) {
      return int.tryParse(cleanHex, radix: 16);
    }
    return null;
  }

  /// Returns a random color from the palette.
  static int getRandomColor() {
    return palette[Random().nextInt(palette.length)];
  }

  /// Computes appropriate text color (white or dark slate) with high readability.
  static Color getContrastingTextColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.4 ? const Color(0xFF0F172A) : Colors.white;
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
          listEquals(options, other.options) &&
          listEquals(addons, other.addons);

  @override
  int get hashCode => Object.hash(
        id,
        name.toLowerCase().trim(),
        additionalCost,
        costReason,
        colorHex,
        isEnabled,
        Object.hashAll(options),
        Object.hashAll(addons),
      );

  @override
  String toString() =>
      'ItemCategory(id: $id, name: $name, options: ${options.length}, addons: ${addons.length}, additionalCost: $additionalCost)';
}

/// Compatibility class delegating to [ItemCategory] static color helpers.
abstract final class CategoryColorHelper {
  static const List<int> palette = ItemCategory.palette;
  static const Map<String, int> namedColorMap = ItemCategory.namedColorMap;
  static double colorDistance(int hex1, int hex2) => ItemCategory.colorDistance(hex1, hex2);
  static int getUniqueColor({String? categoryName, required Set<int> usedColors}) =>
      ItemCategory.getUniqueColor(categoryName: categoryName, usedColors: usedColors);
  static int getColorForCategory(String? categoryName, {int? explicitColor}) =>
      ItemCategory.getColorForCategory(categoryName, explicitColor: explicitColor);
  static int? parseColor(dynamic rawColor) => ItemCategory.parseColor(rawColor);
  static int getRandomColor() => ItemCategory.getRandomColor();
  static Color getContrastingTextColor(Color background) =>
      ItemCategory.getContrastingTextColor(background);
}
