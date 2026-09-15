import 'package:flutter/material.dart';

/// Represents dietary classification for food and beverage items
/// adhering to standard culinary labelling (e.g. FSSAI / vegetarian standards).
enum ItemDietaryType {
  veg,
  nonVeg,
  egg,
  none;

  /// Human-readable label.
  String get displayName {
    switch (this) {
      case ItemDietaryType.veg:
        return 'Veg';
      case ItemDietaryType.nonVeg:
        return 'Non-Veg';
      case ItemDietaryType.egg:
        return 'Egg';
      case ItemDietaryType.none:
        return 'Not Specified';
    }
  }

  /// Alias for displayName.
  String get label => displayName;

  /// Serialization string code.
  String get code {
    switch (this) {
      case ItemDietaryType.veg:
        return 'veg';
      case ItemDietaryType.nonVeg:
        return 'non_veg';
      case ItemDietaryType.egg:
        return 'egg';
      case ItemDietaryType.none:
        return 'none';
    }
  }

  /// Primary color for badges and indicator dots.
  Color get color {
    switch (this) {
      case ItemDietaryType.veg:
        return const Color(0xFF2E7D32); // Emerald Green
      case ItemDietaryType.nonVeg:
        return const Color(0xFFC62828); // Deep Crimson / Brown Red
      case ItemDietaryType.egg:
        return const Color(0xFFF57C00); // Amber Orange
      case ItemDietaryType.none:
        return const Color(0xFF78909C); // Slate Grey
    }
  }

  /// Outer border color for the standard square box.
  Color get borderColor => color;

  /// Parses an [ItemDietaryType] from an arbitrary input string (case-insensitive, lenient).
  static ItemDietaryType fromString(String? val) {
    if (val == null) return ItemDietaryType.none;
    final normalized = val.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (normalized.isEmpty || normalized == 'none' || normalized == 'notspecified') {
      return ItemDietaryType.none;
    }
    if (normalized == 'veg' ||
        normalized == 'v' ||
        normalized == 'vegetarian' ||
        normalized == 'pureveg' ||
        normalized == 'vegan') {
      return ItemDietaryType.veg;
    }
    if (normalized == 'nonveg' ||
        normalized == 'nv' ||
        normalized == 'nonvegetarian' ||
        normalized == 'meat') {
      return ItemDietaryType.nonVeg;
    }
    if (normalized == 'egg' ||
        normalized == 'e' ||
        normalized == 'eggetarian' ||
        normalized == 'eggitarian' ||
        normalized == 'containsegg' ||
        normalized == 'containsgg' ||
        normalized == 'ovovegetarian') {
      return ItemDietaryType.egg;
    }
    return ItemDietaryType.none;
  }

  /// Dynamically infers dietary classification based on keywords in name, category, or variant.
  ///
  /// This serves as an intelligent automatic fallback when the user has not explicitly set a dietary type.
  static ItemDietaryType infer({
    required String name,
    String? category,
    String? variantName,
  }) {
    final combined = '${name.toLowerCase()} ${category?.toLowerCase() ?? ""} ${variantName?.toLowerCase() ?? ""}';

    // 1. Check for non-vegetarian keywords (poultry, meat, seafood)
    final nonVegPattern = RegExp(
      r'(non[\s\-_]?veg|non[\s\-_]?vegetarian|\b(chicken|mutton|fish|prawn|prawns|lamb|pork|beef|bacon|seafood|ham|shrimp|meat|keema|pepperoni|salami|sausage|crab|squid|duck|turkey|tuna|salmon|steak)\b)',
      caseSensitive: false,
    );
    if (nonVegPattern.hasMatch(combined)) {
      return ItemDietaryType.nonVeg;
    }

    // 2. Check for egg / ovovegetarian keywords
    final eggPattern = RegExp(
      r'\b(egg|eggs|omelet|omelette|anda|bhurji|double egg|egg roll|egg chicken)\b',
      caseSensitive: false,
    );
    // If it contains "egg chicken", nonVeg was already caught above. If only egg:
    if (eggPattern.hasMatch(combined)) {
      return ItemDietaryType.egg;
    }

    // 3. Check for explicit vegetarian keywords
    final vegPattern = RegExp(
      r'\b(veg|vegetarian|paneer|gobi|mushroom|aloo|potato|cheese|corn|soya|chaap|palak|tofu|dal|daal|paneer roll|veg roll|chilli paneer|matar|chole|bhindi|dosa|idli|sambar|coffee|tea|chai|shake|juice|soda|falooda|paratha)\b',
      caseSensitive: false,
    );
    if (vegPattern.hasMatch(combined)) {
      return ItemDietaryType.veg;
    }

    return ItemDietaryType.none;
  }
}

/// Alias for [ItemDietaryType] matching clean domain naming.
typedef DietaryType = ItemDietaryType;
