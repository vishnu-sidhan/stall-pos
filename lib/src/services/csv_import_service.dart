import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/counter_model.dart';
import '../models/stall_models.dart';
import '../theme/category_colors.dart';

/// Result of parsing a full Menu & Catalog CSV with both items and categories.
class MenuCatalogParseResult {
  final List<MenuItem> items;
  final List<ItemCategory> categories;
  final int totalRowsParsed;
  final int skippedRowsCount;
  final List<String> warnings;

  const MenuCatalogParseResult({
    required this.items,
    required this.categories,
    required this.totalRowsParsed,
    required this.skippedRowsCount,
    this.warnings = const [],
  });

  bool get hasItems => items.isNotEmpty;
  bool get hasCategories => categories.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
}

/// Holds the parsed items, skipped counts, and diagnostic warnings from a CSV import.
class CsvParseResult<T> {
  final List<T> items;
  final int totalRowsParsed;
  final int skippedRowsCount;
  final List<String> warnings;

  const CsvParseResult({
    required this.items,
    required this.totalRowsParsed,
    required this.skippedRowsCount,
    this.warnings = const [],
  });

  bool get hasItems => items.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
}

/// Result of picking a file, including filename and raw decoded string content.
class CsvFileSelection {
  final String fileName;
  final String content;

  const CsvFileSelection({
    required this.fileName,
    required this.content,
  });
}

/// Service handling RFC 4180 CSV parsing and file picking for POS items and counters.
class CsvImportService {
  CsvImportService._();

  static const _uuid = Uuid();

  /// Built-in copy-pasteable sample CSV for POS menu items.
  static const String sampleMenuCsv = '''name,price,category
Masala Chai,20,Beverages
Filter Coffee,25,Beverages
Veg Samosa,20,Snacks
Paneer Roll,70,Fast Food
Chicken Biryani,180,Main Course
Mango Lassi,50,Beverages
Mineral Water,20,Beverages''';

  /// Built-in copy-pasteable sample CSV for counters.
  static const String sampleCountersCsv = '''title,count,step,target,allowNegative,colorHex
Daily Water Glasses,0,1,8,false,0xFF0284C7
Workout Reps,0,5,100,false,0xFF059669
Pages Read,0,1,50,false,0xFFD97706
Inventory Tally,10,1,,false,0xFF7C3AED
Budget Delta,0,10,,true,0xFFDC2626''';

  /// Parses a raw option string into a typed [CategoryOption].
  /// Supports:
  /// - `Fried:+10`, `Fried: +10`, `Fried:+10.0`
  /// - `Fried:-5`
  /// - `Regular:80`, `Regular: 80`
  /// - `Fried (+10)`, `Fried (+₹10)`, `Fried (+10.00)`
  /// - `Large (120)`, `Large (₹120)`
  /// - `Steam`
  static CategoryOption parseCategoryOption(String raw, String categorySlug, int index) {
    final str = raw.trim();
    if (str.isEmpty) {
      return CategoryOption(
        id: 'opt_${categorySlug}_$index',
        name: '',
        additionalCost: 0.0,
      );
    }

    double additionalCost = 0.0;
    double? explicitPrice;
    String name = str;

    // Pattern 1: "Name: +10", "Name:+10", "Name:-5" (explicit additional cost with colon)
    final colonDeltaRegex = RegExp(r'^(.+?)\s*:\s*([+-])\s*(?:₹|\$|€|£|Rs\.?)?\s*([\d.]+)$');
    final matchColonDelta = colonDeltaRegex.firstMatch(str);

    // Pattern 2: "Name (+10)", "Name (+₹10)" (parenthesized signed delta)
    final parenDeltaRegex = RegExp(r'^(.+?)\s*\(\s*([+-])\s*(?:₹|\$|€|£|Rs\.?)?\s*([\d.]+)\s*\)$');
    final matchParenDelta = parenDeltaRegex.firstMatch(str);

    // Pattern 3: "Name: 80", "Name:80", "Name:₹80" (colon explicit price)
    final colonPriceRegex = RegExp(r'^(.+?)\s*:\s*(?:₹|\$|€|£|Rs\.?)?\s*([\d.]+)$');
    final matchColonPrice = colonPriceRegex.firstMatch(str);

    // Pattern 4: "Name (₹80)", "Name (80)" (parenthesized unsigned price)
    final parenPriceRegex = RegExp(r'^(.+?)\s*\(\s*(?:₹|\$|€|£|Rs\.?)?\s*([\d.]+)\s*\)$');
    final matchParenPrice = parenPriceRegex.firstMatch(str);

    if (matchColonDelta != null) {
      name = matchColonDelta.group(1)!.trim();
      final sign = matchColonDelta.group(2) == '-' ? -1.0 : 1.0;
      final val = double.tryParse(matchColonDelta.group(3)!) ?? 0.0;
      additionalCost = sign * val;
    } else if (matchParenDelta != null) {
      name = matchParenDelta.group(1)!.trim();
      final sign = matchParenDelta.group(2) == '-' ? -1.0 : 1.0;
      final val = double.tryParse(matchParenDelta.group(3)!) ?? 0.0;
      additionalCost = sign * val;
    } else if (matchColonPrice != null) {
      name = matchColonPrice.group(1)!.trim();
      final val = double.tryParse(matchColonPrice.group(2)!) ?? 0.0;
      explicitPrice = val;
    } else if (matchParenPrice != null) {
      name = matchParenPrice.group(1)!.trim();
      final val = double.tryParse(matchParenPrice.group(2)!) ?? 0.0;
      explicitPrice = val;
    }

    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return CategoryOption(
      id: 'opt_${categorySlug}_${slug.isNotEmpty ? slug : index}',
      name: name,
      additionalCost: additionalCost,
      price: explicitPrice,
      isEnabled: true,
    );
  }

  /// Parses CSV text content into a list of [MenuItem]s.
  ///
  /// Expected columns:
  /// - `name` (required)
  /// - `price` (required, > 0)
  /// - `category` (optional, defaults to 'General')
  /// - `color` (optional, hex or name; if not defined, a random category color is assigned)
  static CsvParseResult<MenuItem> parseMenuItemsFromCsv(String csvContent) {
    final trimmed = csvContent.trim();
    if (trimmed.isEmpty) {
      return const CsvParseResult(
        items: [],
        totalRowsParsed: 0,
        skippedRowsCount: 0,
        warnings: ['The CSV content is empty.'],
      );
    }

    List<List<dynamic>> rows;
    try {
      rows = const CsvDecoder().convert(trimmed);
    } catch (e) {
      return CsvParseResult(
        items: [],
        totalRowsParsed: 0,
        skippedRowsCount: 0,
        warnings: ['Failed to parse CSV format: $e'],
      );
    }

    if (rows.isEmpty) {
      return const CsvParseResult(
        items: [],
        totalRowsParsed: 0,
        skippedRowsCount: 0,
        warnings: ['No data rows found in CSV.'],
      );
    }

    // Determine column indices from header
    int nameIdx = 0;
    int priceIdx = 1;
    int categoryIdx = 2;
    int colorIdx = -1;
    int addonIdx = -1;
    int linkedCategoryIdx = -1;
    int dietaryIdx = -1;
    int additionalCostIdx = -1;
    int variantsIdx = -1;
    int startIndex = 0;

    final firstRow = rows.first.map((c) => c.toString().trim().toLowerCase()).toList();
    final hasHeader = _isMenuHeaderRow(firstRow);

    if (hasHeader) {
      startIndex = 1;
      for (int i = 0; i < firstRow.length; i++) {
        final col = firstRow[i];
        if (col == 'name' || col == 'item' || col == 'title' || col == 'item_name' || col == 'product') {
          nameIdx = i;
        } else if (col == 'price' || col == 'rate' || col == 'cost' || col == 'amount' || col == 'mrp') {
          priceIdx = i;
        } else if (col == 'category' || col == 'cat' || col == 'group' || col == 'type' || col == 'section') {
          categoryIdx = i;
        } else if (col == 'color' || col == 'colorhex' || col == 'color_hex' || col == 'colour') {
          colorIdx = i;
        } else if (col == 'is_addon' || col == 'addon' || col == 'isaddon' || col == 'add_on') {
          addonIdx = i;
        } else if (col == 'linked_category' ||
            col == 'linkedcategory' ||
            col == 'target_category' ||
            col == 'targetcategory' ||
            col == 'applies_to') {
          linkedCategoryIdx = i;
        } else if (col == 'dietary' ||
            col == 'diet' ||
            col == 'dietary_type' ||
            col == 'dietarytype' ||
            col == 'veg_nonveg' ||
            col == 'veg_egg_nonveg') {
          dietaryIdx = i;
        } else if (col == 'category_additional_cost' ||
            col == 'additional_cost' ||
            col == 'additionalcost' ||
            col == 'surcharge' ||
            col == 'packaging_fee') {
          additionalCostIdx = i;
        } else if (col == 'category_variants' ||
            col == 'variants' ||
            col == 'options' ||
            col == 'subcategories' ||
            col == 'sub_categories') {
          variantsIdx = i;
        }
      }
    } else {
      startIndex = 0;
    }

    final items = <MenuItem>[];
    final warnings = <String>[];
    final categoryColors = <String, int>{};
    final usedColors = <int>{};
    int skippedCount = 0;

    for (int i = startIndex; i < rows.length; i++) {
      final row = rows[i];
      // Skip blank rows
      if (row.isEmpty || row.every((c) => c.toString().trim().isEmpty)) {
        continue;
      }

      final rowNum = i + 1;
      final name = nameIdx < row.length ? row[nameIdx].toString().trim() : '';
      final rawPrice = priceIdx < row.length ? row[priceIdx].toString().trim() : '';
      var category = categoryIdx < row.length ? row[categoryIdx].toString().trim() : '';
      final rawColor = colorIdx != -1 && colorIdx < row.length ? row[colorIdx].toString().trim() : '';
      final rawAddon = addonIdx != -1 && addonIdx < row.length ? row[addonIdx].toString().trim().toLowerCase() : '';
      final rawLinked = linkedCategoryIdx != -1 && linkedCategoryIdx < row.length
          ? row[linkedCategoryIdx].toString().trim()
          : '';
      final rawDietary = dietaryIdx != -1 && dietaryIdx < row.length
          ? row[dietaryIdx].toString().trim()
          : '';
      final rawAddCost = additionalCostIdx != -1 && additionalCostIdx < row.length
          ? row[additionalCostIdx].toString().trim()
          : '';
      final rawVariants = variantsIdx != -1 && variantsIdx < row.length
          ? row[variantsIdx].toString().trim()
          : '';

      if (name.isEmpty) {
        skippedCount++;
        warnings.add('Row $rowNum skipped: Missing item name.');
        continue;
      }

      // Clean price string (remove currency symbols like ₹, $, €, £, Rs. but preserve minus sign and decimal)
      final cleanedPrice = rawPrice.replaceAll(RegExp(r'[^\d.-]'), '');
      final price = double.tryParse(cleanedPrice);

      if (price == null || price <= 0) {
        skippedCount++;
        warnings.add('Row $rowNum ("$name") skipped: Invalid or zero price "$rawPrice".');
        continue;
      }

      if (category.isEmpty) {
        category = 'General';
      }

      final isAddonExplicit = rawAddon == 'true' || rawAddon == '1' || rawAddon == 'yes';
      final isAddon = isAddonExplicit ||
          category.toLowerCase().contains('addon') ||
          category.toLowerCase().contains('add-on') ||
          category.toLowerCase() == 'extras';
      final linkedCategory = rawLinked.isNotEmpty ? rawLinked : null;

      final parsedDietary = rawDietary.isNotEmpty
          ? ItemDietaryType.fromString(rawDietary)
          : ItemDietaryType.infer(name: name, category: category);
      final effectiveDietary = parsedDietary != ItemDietaryType.none ? parsedDietary : null;

      // Determine category color: if color is defined, use it; if not defined, assign a guaranteed unique, visually distinct color!
      final parsedColor = CategoryColorHelper.parseColor(rawColor);
      final normalizedCat = category.toLowerCase();
      int assignedColor;

      if (parsedColor != null) {
        assignedColor = parsedColor;
        categoryColors[normalizedCat] = assignedColor;
        usedColors.add(assignedColor);
      } else if (categoryColors.containsKey(normalizedCat)) {
        assignedColor = categoryColors[normalizedCat]!;
      } else {
        assignedColor = CategoryColorHelper.getUniqueColor(
          categoryName: category,
          usedColors: usedColors,
        );
        categoryColors[normalizedCat] = assignedColor;
        usedColors.add(assignedColor);
      }

      final addCost = double.tryParse(rawAddCost.replaceAll(RegExp(r'[^\d.-]'), '')) ?? 0.0;
      final variantOptions = <CategoryOption>[];
      if (rawVariants.isNotEmpty) {
        final splitVariants = rawVariants.contains('|')
            ? rawVariants.split('|')
            : rawVariants.split(',');
        for (int vIdx = 0; vIdx < splitVariants.length; vIdx++) {
          final vStr = splitVariants[vIdx].trim();
          if (vStr.isNotEmpty) {
            variantOptions.add(parseCategoryOption(vStr, normalizedCat, vIdx));
          }
        }
      }

      final itemCategory = ItemCategory(
        id: 'cat_${normalizedCat.replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
        name: category,
        colorHex: assignedColor,
        additionalCost: addCost,
        isAddonCategory: isAddon && linkedCategory == null,
        options: variantOptions,
      );

      items.add(MenuItem(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}',
        name: name,
        price: price,
        category: itemCategory,
        colorHex: assignedColor,
        isAddon: isAddon,
        linkedCategory: linkedCategory,
        dietaryType: effectiveDietary,
        variants: variantOptions,
      ));
    }

    return CsvParseResult(
      items: items,
      totalRowsParsed: rows.length - (hasHeader ? 1 : 0),
      skippedRowsCount: skippedCount,
      warnings: warnings,
    );
  }

  /// Parses a complete Menu & Catalog CSV containing both menu items and category configurations.
  ///
  /// Columns:
  /// `name,price,category,dietary_type,is_available,category_color,category_additional_cost,category_variants,is_addon,linked_category`
  static MenuCatalogParseResult parseCsv(String csvContent) {
    final trimmed = csvContent.trim();
    if (trimmed.isEmpty) {
      return const MenuCatalogParseResult(
        items: [],
        categories: [],
        totalRowsParsed: 0,
        skippedRowsCount: 0,
        warnings: ['The CSV content is empty.'],
      );
    }

    List<List<dynamic>> rows;
    try {
      rows = const CsvDecoder().convert(trimmed);
    } catch (e) {
      return MenuCatalogParseResult(
        items: [],
        categories: [],
        totalRowsParsed: 0,
        skippedRowsCount: 0,
        warnings: ['Failed to parse CSV format: $e'],
      );
    }

    if (rows.isEmpty) {
      return const MenuCatalogParseResult(
        items: [],
        categories: [],
        totalRowsParsed: 0,
        skippedRowsCount: 0,
        warnings: ['No data rows found in CSV.'],
      );
    }

    int nameIdx = -1;
    int priceIdx = -1;
    int categoryIdx = -1;
    int dietaryIdx = -1;
    int isAvailableIdx = -1;
    int colorIdx = -1;
    int additionalCostIdx = -1;
    int variantsIdx = -1;
    int addonIdx = -1;
    int linkedCategoryIdx = -1;
    int startIndex = 0;

    final firstRow = rows.first.map((c) => c.toString().trim().toLowerCase()).toList();
    final hasHeader = _isMenuHeaderRow(firstRow);

    if (hasHeader) {
      startIndex = 1;
      for (int i = 0; i < firstRow.length; i++) {
        final col = firstRow[i];
        if (col == 'name' || col == 'item' || col == 'title' || col == 'item_name') {
          nameIdx = i;
        } else if (col == 'price' || col == 'rate' || col == 'cost' || col == 'amount') {
          priceIdx = i;
        } else if (col == 'category' || col == 'cat' || col == 'group' || col == 'section') {
          categoryIdx = i;
        } else if (col == 'dietary_type' || col == 'dietary' || col == 'diet' || col == 'dietarytype' || col == 'veg_nonveg') {
          dietaryIdx = i;
        } else if (col == 'is_available' || col == 'available' || col == 'isavailable') {
          isAvailableIdx = i;
        } else if (col == 'category_color' || col == 'color' || col == 'colorhex' || col == 'color_hex') {
          colorIdx = i;
        } else if (col == 'category_additional_cost' || col == 'additional_cost' || col == 'additionalcost' || col == 'surcharge' || col == 'packaging_fee') {
          additionalCostIdx = i;
        } else if (col == 'category_variants' || col == 'variants' || col == 'options' || col == 'subcategories' || col == 'sub_categories') {
          variantsIdx = i;
        } else if (col == 'is_addon' || col == 'addon' || col == 'isaddon' || col == 'add_on') {
          addonIdx = i;
        } else if (col == 'linked_category' ||
            col == 'linkedcategory' ||
            col == 'target_category' ||
            col == 'targetcategory' ||
            col == 'applies_to') {
          linkedCategoryIdx = i;
        }
      }
    } else {
      nameIdx = 0;
      priceIdx = 1;
      categoryIdx = 2;
    }

    final items = <MenuItem>[];
    final categoriesMap = <String, ItemCategory>{};
    final warnings = <String>[];
    int skippedCount = 0;

    for (int i = startIndex; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((c) => c.toString().trim().isEmpty)) {
        continue;
      }

      final rowNum = i + 1;
      final name = nameIdx >= 0 && nameIdx < row.length ? row[nameIdx].toString().trim() : '';
      final rawPrice = priceIdx >= 0 && priceIdx < row.length ? row[priceIdx].toString().trim() : '';
      var catName = categoryIdx >= 0 && categoryIdx < row.length ? row[categoryIdx].toString().trim() : '';
      final rawDietary = dietaryIdx >= 0 && dietaryIdx < row.length ? row[dietaryIdx].toString().trim() : '';
      final rawAvailable = isAvailableIdx >= 0 && isAvailableIdx < row.length ? row[isAvailableIdx].toString().trim().toLowerCase() : '';
      final rawColor = colorIdx >= 0 && colorIdx < row.length ? row[colorIdx].toString().trim() : '';
      final rawAddCost = additionalCostIdx >= 0 && additionalCostIdx < row.length ? row[additionalCostIdx].toString().trim() : '';
      final rawVariants = variantsIdx >= 0 && variantsIdx < row.length ? row[variantsIdx].toString().trim() : '';
      final rawAddon = addonIdx >= 0 && addonIdx < row.length ? row[addonIdx].toString().trim().toLowerCase() : '';
      final rawLinked = linkedCategoryIdx >= 0 && linkedCategoryIdx < row.length ? row[linkedCategoryIdx].toString().trim() : '';

      if (catName.isEmpty) {
        catName = 'General';
      }

      final normalizedCat = catName.toLowerCase();
      final parsedColor = CategoryColorHelper.parseColor(rawColor);
      final addCost = double.tryParse(rawAddCost.replaceAll(RegExp(r'[^\d.-]'), '')) ?? 0.0;

      final isAddonExplicit = rawAddon == 'true' || rawAddon == '1' || rawAddon == 'yes';
      final isAddon = isAddonExplicit ||
          catName.toLowerCase().contains('addon') ||
          catName.toLowerCase().contains('add-on') ||
          catName.toLowerCase() == 'extras';
      final linkedCategory = rawLinked.isNotEmpty ? rawLinked : null;

      final variantOptions = <CategoryOption>[];
      if (rawVariants.isNotEmpty) {
        final splitVariants = rawVariants.contains('|')
            ? rawVariants.split('|')
            : rawVariants.split(',');
        for (int vIdx = 0; vIdx < splitVariants.length; vIdx++) {
          final vStr = splitVariants[vIdx].trim();
          if (vStr.isNotEmpty) {
            variantOptions.add(parseCategoryOption(vStr, normalizedCat, vIdx));
          }
        }
      }

      // Upsert Category
      ItemCategory category;
      if (!categoriesMap.containsKey(normalizedCat)) {
        category = ItemCategory(
          id: 'cat_${normalizedCat.replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
          name: catName,
          colorHex: parsedColor ?? CategoryColorHelper.getColorForCategory(catName),
          additionalCost: addCost,
          options: variantOptions,
          isAddonCategory: isAddon && linkedCategory == null,
        );
        categoriesMap[normalizedCat] = category;
      } else {
        final existing = categoriesMap[normalizedCat]!;
        category = existing.copyWith(
          colorHex: parsedColor ?? existing.colorHex,
          additionalCost: addCost > 0 ? addCost : existing.additionalCost,
          options: variantOptions.isNotEmpty ? variantOptions : existing.options,
        );
        categoriesMap[normalizedCat] = category;
      }

      // If name is empty, this row was a category-only row
      if (name.isEmpty) {
        continue;
      }

      final cleanedPrice = rawPrice.replaceAll(RegExp(r'[^\d.-]'), '');
      final price = double.tryParse(cleanedPrice);

      if (price == null || price <= 0) {
        skippedCount++;
        warnings.add('Row $rowNum ("$name") skipped: Invalid or zero price "$rawPrice".');
        continue;
      }

      final isAvailable = rawAvailable.isEmpty ||
          rawAvailable == 'true' ||
          rawAvailable == '1' ||
          rawAvailable == 'yes';

      final parsedDietary = rawDietary.isNotEmpty
          ? ItemDietaryType.fromString(rawDietary)
          : ItemDietaryType.infer(name: name, category: catName);
      final effectiveDietary = parsedDietary != ItemDietaryType.none ? parsedDietary : null;

      items.add(MenuItem(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}',
        name: name,
        price: price,
        category: category,
        colorHex: category.colorHex,
        isAvailable: isAvailable,
        dietaryType: effectiveDietary,
        isAddon: isAddon,
        linkedCategory: linkedCategory,
        variants: variantOptions.isNotEmpty ? variantOptions : category.options,
      ));
    }

    return MenuCatalogParseResult(
      items: items,
      categories: categoriesMap.values.toList(),
      totalRowsParsed: rows.length - (hasHeader ? 1 : 0),
      skippedRowsCount: skippedCount,
      warnings: warnings,
    );
  }

  static bool _isMenuHeaderRow(List<String> row) {
    return row.any((c) =>
        c == 'name' ||
        c == 'item' ||
        c == 'item_name' ||
        c == 'product' ||
        c == 'price' ||
        c == 'rate' ||
        c == 'category' ||
        c == 'color' ||
        c == 'colorhex' ||
        c == 'color_hex' ||
        c == 'category_color' ||
        c == 'is_addon' ||
        c == 'addon' ||
        c == 'add_on' ||
        c == 'linked_category' ||
        c == 'target_category' ||
        c == 'dietary' ||
        c == 'diet' ||
        c == 'dietary_type' ||
        c == 'is_available' ||
        c == 'category_additional_cost' ||
        c == 'category_variants' ||
        c == 'veg_nonveg');
  }


  /// Parses CSV text content into a list of [CounterModel]s.
  ///
  /// Expected columns:
  /// - `title` (required)
  /// - `count` (optional, default 0)
  /// - `step` (optional, default 1)
  /// - `target` (optional, integer)
  /// - `allowNegative` (optional, boolean default false)
  /// - `colorHex` (optional, default royal blue 0xFF2563EB)
  static CsvParseResult<CounterModel> parseCountersFromCsv(String csvContent) {
    final trimmed = csvContent.trim();
    if (trimmed.isEmpty) {
      return const CsvParseResult(
        items: [],
        totalRowsParsed: 0,
        skippedRowsCount: 0,
        warnings: ['The CSV content is empty.'],
      );
    }

    List<List<dynamic>> rows;
    try {
      rows = const CsvDecoder().convert(trimmed);
    } catch (e) {
      return CsvParseResult(
        items: [],
        totalRowsParsed: 0,
        skippedRowsCount: 0,
        warnings: ['Failed to parse CSV format: $e'],
      );
    }

    if (rows.isEmpty) {
      return const CsvParseResult(
        items: [],
        totalRowsParsed: 0,
        skippedRowsCount: 0,
        warnings: ['No data rows found in CSV.'],
      );
    }

    int titleIdx = 0;
    int countIdx = 1;
    int stepIdx = 2;
    int targetIdx = 3;
    int allowNegativeIdx = 4;
    int colorHexIdx = 5;
    int startIndex = 0;

    final firstRow = rows.first.map((c) => c.toString().trim().toLowerCase()).toList();
    final hasHeader = _isCounterHeaderRow(firstRow);

    if (hasHeader) {
      startIndex = 1;
      for (int i = 0; i < firstRow.length; i++) {
        final col = firstRow[i];
        if (col == 'title' || col == 'name' || col == 'counter' || col == 'counter_title') {
          titleIdx = i;
        } else if (col == 'count' || col == 'value' || col == 'initial' || col == 'initial_count') {
          countIdx = i;
        } else if (col == 'step' || col == 'step_value' || col == 'increment') {
          stepIdx = i;
        } else if (col == 'target' || col == 'goal' || col == 'target_count') {
          targetIdx = i;
        } else if (col == 'allownegative' || col == 'allow_negative' || col == 'negative') {
          allowNegativeIdx = i;
        } else if (col == 'colorhex' || col == 'color_hex' || col == 'color') {
          colorHexIdx = i;
        }
      }
    }

    final items = <CounterModel>[];
    final warnings = <String>[];
    int skippedCount = 0;
    final now = DateTime.now();

    for (int i = startIndex; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((c) => c.toString().trim().isEmpty)) {
        continue;
      }

      final rowNum = i + 1;
      final title = titleIdx < row.length ? row[titleIdx].toString().trim() : '';

      if (title.isEmpty) {
        skippedCount++;
        warnings.add('Row $rowNum skipped: Missing counter title.');
        continue;
      }

      final countStr = countIdx < row.length ? row[countIdx].toString().trim() : '';
      final count = int.tryParse(countStr) ?? 0;

      final stepStr = stepIdx < row.length ? row[stepIdx].toString().trim() : '';
      final step = (int.tryParse(stepStr) ?? 1).clamp(1, 100000);

      final targetStr = targetIdx < row.length ? row[targetIdx].toString().trim() : '';
      final target = int.tryParse(targetStr);

      final allowNegativeStr = allowNegativeIdx < row.length
          ? row[allowNegativeIdx].toString().trim().toLowerCase()
          : '';
      final allowNegative = allowNegativeStr == 'true' ||
          allowNegativeStr == '1' ||
          allowNegativeStr == 'yes';

      final colorStr = colorHexIdx < row.length ? row[colorHexIdx].toString().trim() : '';
      final colorHex = _parseColorHex(colorStr);

      items.add(CounterModel(
        id: _uuid.v4(),
        title: title,
        count: count,
        step: step,
        colorHex: colorHex,
        target: target,
        allowNegative: allowNegative,
        createdAt: now,
        updatedAt: now,
      ));
    }

    return CsvParseResult(
      items: items,
      totalRowsParsed: rows.length - (hasHeader ? 1 : 0),
      skippedRowsCount: skippedCount,
      warnings: warnings,
    );
  }

  static bool _isCounterHeaderRow(List<String> row) {
    return row.any((c) =>
        c == 'title' ||
        c == 'counter' ||
        c == 'count' ||
        c == 'step' ||
        c == 'target' ||
        c == 'goal');
  }

  static int _parseColorHex(String colorStr) {
    if (colorStr.isEmpty) return 0xFF2563EB;
    try {
      if (colorStr.startsWith('#')) {
        return int.parse('0xFF${colorStr.substring(1)}');
      } else if (colorStr.startsWith('0x') || colorStr.startsWith('0X')) {
        return int.parse(colorStr);
      }
      final parsed = int.tryParse(colorStr);
      if (parsed != null) return parsed;
    } catch (_) {}
    return 0xFF2563EB;
  }

  /// Opens the platform file picker to choose a CSV file and decodes its contents.
  ///
  /// Works across Web, iOS, Android, macOS, Linux, and Windows.
  static Future<CsvFileSelection?> pickCsvFile({FilePickerPlatform? customPicker}) async {
    final picker = customPicker ?? FilePickerPlatform.instance;
    final result = await picker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );

    if (result.isEmpty) {
      return null;
    }

    final file = result.first;
    final bytes = await file.readAsBytes();
    final content = utf8.decode(bytes);

    return CsvFileSelection(
      fileName: file.name,
      content: content,
    );
  }
}
