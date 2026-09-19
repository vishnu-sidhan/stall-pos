/// Pure utility class for parsing cart item keys, addon segments, variant segments,
/// and generating display names for POS order line items.
class CartKeyParser {
  const CartKeyParser._();

  /// Parses category name embedded in composite item key (e.g. `item_123_cat_Momos+addon_1`).
  static String? parseCategoryFromKey(String key) {
    final firstPart = key.split('+').first;
    final catIndex = firstPart.indexOf('_cat_');
    if (catIndex == -1) return null;
    final afterCat = firstPart.substring(catIndex + 5);
    if (afterCat.startsWith('var_')) {
      final secondCat = afterCat.indexOf('_cat_');
      if (secondCat == -1) return null;
      return afterCat.substring(secondCat + 5);
    }
    return afterCat;
  }

  /// Parses variant name embedded in composite item key (e.g. `item_123_var_Kurkure Momos_cat_Momos`).
  static String? parseVariantFromKey(String key) {
    final firstPart = key.split('+').first;
    final varIndex = firstPart.indexOf('_var_');
    if (varIndex == -1) return null;
    final afterVar = firstPart.substring(varIndex + 5);
    final catIndex = afterVar.indexOf('_cat_');
    return catIndex != -1 ? afterVar.substring(0, catIndex) : afterVar;
  }

  /// Parses raw catalog item ID by stripping variant, category, and addon suffixes.
  static String parseBaseIdFromKey(String key) {
    final firstPart = key.split('+').first;
    final varIndex = firstPart.indexOf('_var_');
    if (varIndex != -1) {
      return firstPart.substring(0, varIndex);
    }
    final catIndex = firstPart.indexOf('_cat_');
    if (catIndex != -1) {
      return firstPart.substring(0, catIndex);
    }
    return firstPart;
  }

  /// Normalizes category key by trimming segments around '/' slashes to prevent whitespace discrepancies
  /// (e.g. 'Momos /  Fried Momos' -> 'momos / fried momos').
  static String normalizeCategoryKey(String cat) {
    final trimmed = cat.trim().toLowerCase();
    if (trimmed.isEmpty) return '';
    if (!trimmed.contains('/')) return trimmed;
    return trimmed
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(' / ');
  }

  /// Formats an item's display name for Active Orders and Item Summary,
  /// dynamically displaying the item name and selected variant / option in brackets
  /// (e.g. "Chicken (Kurkure Momos)", "Gobi (Noodles)"),
  /// or the category name in brackets if no variant exists (e.g. "Chicken Manchuria (Starters)").
  static String formatOrderLineItemDisplayName({
    required String rawName,
    required String itemId,
    String? category,
    String? baseItemName,
  }) {
    var result = rawName.trim();

    // 1. Extract any add-on prefixes like "[Schezwan]" or "[2x Schezwan]"
    String addonPrefix = '';
    final addonMatch = RegExp(r'^(\[[^\]]+\]\s*)+').firstMatch(result);
    if (addonMatch != null) {
      addonPrefix = addonMatch.group(0)!;
      result = result.substring(addonPrefix.length).trim();
    }

    // 2. Parse variant and category segments from itemId
    final catVariant = parseCategoryFromKey(itemId);
    final varVariant = parseVariantFromKey(itemId);

    // 3. Strip any category suffix already in brackets from rawName
    final bracketMatch = RegExp(r'\s*\(([^)]+)\)$').firstMatch(result);
    if (bracketMatch != null) {
      final inside = bracketMatch.group(1)!.trim();
      final catNorm = category?.trim().toLowerCase();
      final insideNorm = inside.toLowerCase();
      if (inside.contains('/') ||
          (catNorm != null && insideNorm == catNorm) ||
          (catVariant != null && insideNorm == catVariant.trim().toLowerCase()) ||
          insideNorm == 'all') {
        result = result.substring(0, bracketMatch.start).trim();
      }
    }

    // 4. Resolve the base item name
    String itemName = result;
    if (baseItemName != null && baseItemName.trim().isNotEmpty) {
      var cleanBase = baseItemName.trim();
      final baseAddonMatch = RegExp(r'^(\[[^\]]+\]\s*)+').firstMatch(cleanBase);
      if (baseAddonMatch != null) {
        cleanBase = cleanBase.substring(baseAddonMatch.group(0)!.length).trim();
      }
      final baseBracketMatch = RegExp(r'\s*\(([^)]+)\)$').firstMatch(cleanBase);
      if (baseBracketMatch != null) {
        final inside = baseBracketMatch.group(1)!.trim();
        final catNorm = category?.trim().toLowerCase();
        if (inside.contains('/') || (catNorm != null && inside.toLowerCase() == catNorm)) {
          cleanBase = cleanBase.substring(0, baseBracketMatch.start).trim();
        }
      }
      if (cleanBase.isNotEmpty) {
        itemName = cleanBase;
      }
    }

    // If itemName contains slashes (slash-name item e.g. "Chilli / Paneer 65")
    // and a variant was selected, the selected variant is the true item name:
    if (itemName.contains('/') && varVariant != null && varVariant.trim().isNotEmpty) {
      itemName = varVariant.trim();
    }

    // 5. Determine the active variant/option
    String? selectedOption;
    if (varVariant != null && varVariant.trim().isNotEmpty) {
      final trimmedVar = varVariant.trim();
      // Only treat varVariant as a sub-option if it's not identical to itemName
      if (trimmedVar.toLowerCase() != itemName.toLowerCase()) {
        selectedOption = trimmedVar;
      }
    } else if (catVariant != null &&
        catVariant.trim().isNotEmpty &&
        !catVariant.contains('/')) {
      final trimmedCat = catVariant.trim();
      // Only treat catVariant as a sub-option if it differs from the main category
      if (category == null || trimmedCat.toLowerCase() != category.trim().toLowerCase()) {
        selectedOption = trimmedCat;
      }
    }

    // 6. Format the display string dynamically
    String? bracketContent;

    if (selectedOption != null && selectedOption.isNotEmpty) {
      final optLower = selectedOption.toLowerCase();
      if (itemName.toLowerCase().startsWith('$optLower (') ||
          itemName.toLowerCase().endsWith('($optLower)')) {
        return '$addonPrefix$itemName'.trim();
      }

      // If the base item already embeds the category name (e.g. itemName: "Kurkure Momos")
      // and selectedOption is the filling/flavor (e.g. "Chicken"), display "$selectedOption ($itemName)"
      final catKey = category?.trim().toLowerCase();
      final itemLower = itemName.toLowerCase();

      if (catKey != null &&
          catKey.isNotEmpty &&
          itemLower.contains(catKey) &&
          !optLower.contains(catKey) &&
          !itemName.contains('(')) {
        return '$addonPrefix$selectedOption ($itemName)'.trim();
      }

      bracketContent = selectedOption;
    } else if (category != null && category.trim().isNotEmpty && !category.contains('/')) {
      bracketContent = category.trim();
    }

    if (bracketContent != null && bracketContent.isNotEmpty) {
      if (itemName.toLowerCase().endsWith('(${bracketContent.toLowerCase()})')) {
        return '$addonPrefix$itemName'.trim();
      }
      return '$addonPrefix$itemName ($bracketContent)'.trim();
    }

    return '$addonPrefix$itemName'.trim();
  }
}
