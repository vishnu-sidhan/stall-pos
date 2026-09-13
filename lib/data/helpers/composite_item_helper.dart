/// Centralized helper for constructing and parsing composite item keys
/// containing slash variants, category selections, and attached add-ons.
///
/// Format: `baseId[_var_Variant][_cat_Category][+addonId1[_var_AddonVariant]][+addonId2...]`
class CompositeItemHelper {
  CompositeItemHelper._();

  static const String varDelimiter = '_var_';
  static const String catDelimiter = '_cat_';
  static const String addonDelimiter = '+';

  /// Constructs a composite key for a base item with optional variant and category.
  static String buildBaseKey(
    String baseId, {
    String? variantName,
    String? categoryName,
  }) {
    String key = baseId.trim();
    if (variantName != null && variantName.trim().isNotEmpty) {
      key += '$varDelimiter${variantName.trim()}';
    }
    if (categoryName != null && categoryName.trim().isNotEmpty) {
      key += '$catDelimiter${categoryName.trim()}';
    }
    return key;
  }

  /// Constructs a key for an add-on item with optional variant.
  static String buildAddonKey(String addonId, {String? variantName}) {
    String key = addonId.trim();
    if (variantName != null && variantName.trim().isNotEmpty) {
      key += '$varDelimiter${variantName.trim()}';
    }
    return key;
  }

  /// Constructs a simple variant key: `baseId_var_variant`.
  static String buildVariantKey(String baseId, String variant) =>
      '${baseId.trim()}$varDelimiter${variant.trim()}';

  /// Parses a key formatted as `baseId_var_variant`, returning baseId and variant, or null if not formatted as such.
  static ({String baseId, String variant})? parseVariantKey(String key) {
    if (!key.contains(varDelimiter)) return null;
    final parts = key.split(varDelimiter);
    if (parts.length < 2) return null;
    return (baseId: parts[0].trim(), variant: parts.sublist(1).join(varDelimiter).trim());
  }

  /// Combines a base key with multiple add-on keys into a single composite key.
  static String buildCompositeKey(String baseKey, List<String> addonKeys) {
    if (addonKeys.isEmpty) return baseKey;
    return '$baseKey$addonDelimiter${addonKeys.join(addonDelimiter)}';
  }

  /// Returns true if [key] contains add-on segments.
  static bool hasAddons(String key) => key.contains(addonDelimiter);

  /// Splits a composite key into the base item segment and a list of add-on segments.
  static ({String baseSegment, List<String> addonSegments}) splitCompositeKey(String key) {
    if (!key.contains(addonDelimiter)) {
      return (baseSegment: key, addonSegments: const <String>[]);
    }
    final parts = key.split(addonDelimiter);
    return (
      baseSegment: parts.first,
      addonSegments: parts.sublist(1).where((s) => s.isNotEmpty).toList(),
    );
  }

  /// Extracts the raw base catalog ID from any composite key.
  /// E.g. `item_chai_var_Tea_cat_Beverages+addon_milk` -> `item_chai`.
  static String parseBaseId(String key) {
    final baseSegment = key.contains(addonDelimiter) ? key.split(addonDelimiter).first : key;
    var remaining = baseSegment;
    if (remaining.contains(varDelimiter)) {
      remaining = remaining.substring(0, remaining.indexOf(varDelimiter));
    }
    if (remaining.contains(catDelimiter)) {
      remaining = remaining.substring(0, remaining.indexOf(catDelimiter));
    }
    return remaining.trim();
  }

  /// Extracts the variant name if present in [key], or null.
  /// E.g. `item_chai_var_Tea_cat_Beverages` -> `Tea`.
  static String? parseVariant(String key) {
    final baseSegment = key.contains(addonDelimiter) ? key.split(addonDelimiter).first : key;
    if (!baseSegment.contains(varDelimiter)) return null;

    final afterVar = baseSegment.substring(baseSegment.indexOf(varDelimiter) + varDelimiter.length);
    if (afterVar.contains(catDelimiter)) {
      return afterVar.substring(0, afterVar.indexOf(catDelimiter)).trim();
    }
    return afterVar.trim();
  }

  /// Extracts the category name if present in [key], or null.
  /// E.g. `item_chai_var_Tea_cat_Beverages` -> `Beverages`.
  static String? parseCategory(String key) {
    final baseSegment = key.contains(addonDelimiter) ? key.split(addonDelimiter).first : key;
    if (!baseSegment.contains(catDelimiter)) return null;

    return baseSegment.substring(baseSegment.indexOf(catDelimiter) + catDelimiter.length).trim();
  }

  /// Extracts the list of add-on segments from a composite key.
  static List<String> parseAddons(String key) {
    if (!key.contains(addonDelimiter)) return const [];
    return key.split(addonDelimiter).sublist(1).where((s) => s.isNotEmpty).toList();
  }

  /// Checks whether [cartKey] represents or includes [baseId].
  static bool isBaseItemMatch(String cartKey, String baseId) {
    final parsed = parseBaseId(cartKey);
    return parsed == baseId.trim();
  }
}
