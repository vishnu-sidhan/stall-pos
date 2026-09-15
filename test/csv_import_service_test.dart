import 'package:flutter_test/flutter_test.dart';
import 'package:counter_app/src/services/csv_import_service.dart';
import 'package:counter_app/src/theme/category_colors.dart';

void main() {
  group('CsvImportService - Menu Items', () {
    test('parses standard 3-column CSV with headers', () {
      const csv = '''name,price,category
Masala Chai,20,Beverages
Veg Samosa,25,Snacks
Paneer Roll,80.50,Fast Food''';

      final result = CsvImportService.parseMenuItemsFromCsv(csv);

      expect(result.items.length, 3);
      expect(result.skippedRowsCount, 0);
      expect(result.items[0].name, 'Masala Chai');
      expect(result.items[0].price, 20.0);
      expect(result.items[0].categoryName, 'Beverages');

      expect(result.items[1].name, 'Veg Samosa');
      expect(result.items[1].price, 25.0);
      expect(result.items[1].categoryName, 'Snacks');

      expect(result.items[2].name, 'Paneer Roll');
      expect(result.items[2].price, 80.50);
      expect(result.items[2].categoryName, 'Fast Food');
    });

    test('handles RFC 4180 quotes and commas inside fields', () {
      const csv = '''"name","price","category"
"Chai, Special Masala",30,"Hot Drinks, Tea"
"Double ""Deluxe"" Burger",150,Fast Food''';

      final result = CsvImportService.parseMenuItemsFromCsv(csv);

      expect(result.items.length, 2);
      expect(result.items[0].name, 'Chai, Special Masala');
      expect(result.items[0].price, 30.0);
      expect(result.items[0].categoryName, 'Hot Drinks, Tea');

      expect(result.items[1].name, 'Double "Deluxe" Burger');
      expect(result.items[1].price, 150.0);
    });

    test('cleans currency symbols and defaults category to General', () {
      const csv = '''item,rate
Coffee,₹ 40
Tea,\$2.50
Water Bottle,20''';

      final result = CsvImportService.parseMenuItemsFromCsv(csv);

      expect(result.items.length, 3);
      expect(result.items[0].name, 'Coffee');
      expect(result.items[0].price, 40.0);
      expect(result.items[0].categoryName, 'General');

      expect(result.items[1].price, 2.50);
      expect(result.items[2].price, 20.0);
    });

    test('skips rows with missing names or non-positive prices', () {
      const csv = '''name,price,category
Valid Item,50,Snacks
,40,Snacks
Invalid Price,abc,Snacks
Free Item,0,Promos
Negative Item,-10,Snacks''';

      final result = CsvImportService.parseMenuItemsFromCsv(csv);

      expect(result.items.length, 1);
      expect(result.items[0].name, 'Valid Item');
      expect(result.skippedRowsCount, 4);
      expect(result.warnings.length, 4);
    });

    test('handles empty CSV input gracefully', () {
      final result = CsvImportService.parseMenuItemsFromCsv('   \n  \n');
      expect(result.items, isEmpty);
      expect(result.hasItems, isFalse);
      expect(result.warnings, isNotEmpty);
    });

    test('parses menu CSV with explicit color column', () {
      const csv = '''name,price,category,color
Masala Chai,20,Beverages,#EA580C
Veg Samosa,25,Snacks,0xFF059669
Chocolate Donut,60,Dessert,crimson''';

      final result = CsvImportService.parseMenuItemsFromCsv(csv);
      expect(result.items.length, 3);
      expect(result.items[0].colorHex, 0xFFEA580C);
      expect(result.items[1].colorHex, 0xFF059669);
      expect(result.items[2].colorHex, 0xFFDC2626);
    });

    test('assigns random category color when color is not defined and shares color across category', () {
      const csv = '''name,price,category
Filter Coffee,30,Beverages
Masala Chai,20,Beverages
Veg Puff,35,Snacks''';

      final result = CsvImportService.parseMenuItemsFromCsv(csv);
      expect(result.items.length, 3);
      // Colors are assigned
      expect(result.items[0].colorHex, isNotNull);
      expect(result.items[1].colorHex, isNotNull);
      expect(result.items[2].colorHex, isNotNull);

      // Same category shares the assigned category color
      expect(result.items[0].colorHex, equals(result.items[1].colorHex));

      // Different category can have a different color
      expect(result.items[0].categoryName, 'Beverages');
      expect(result.items[2].categoryName, 'Snacks');
    });

    test('guarantees unique and distinct colors for all imported categories', () {
      const csv = '''name,price,category
Tea,10,Hot Drinks
Coffee,20,Cold Drinks
Samosa,15,Snacks
Burger,50,Fast Food
Cake,40,Desserts
Biryani,100,Meals
Combo,120,Combos''';

      final result = CsvImportService.parseMenuItemsFromCsv(csv);
      expect(result.items.length, 7);

      final categoryColors = <String, int>{};
      for (final item in result.items) {
        categoryColors[item.categoryName] = item.colorHex!;
      }

      // 7 categories must produce 7 strictly unique colors
      expect(categoryColors.values.toSet().length, equals(7));

      // Check that all assigned colors have significant perceptual distance (no two look the same)
      final colorsList = categoryColors.values.toList();
      for (int i = 0; i < colorsList.length; i++) {
        for (int j = i + 1; j < colorsList.length; j++) {
          final dist = CategoryColorHelper.colorDistance(colorsList[i], colorsList[j]);
          expect(dist, greaterThanOrEqualTo(70.0),
              reason: 'Colors ${colorsList[i]} and ${colorsList[j]} must be visually distinct');
        }
      }
    });

    test('parses is_addon and linked_category columns for category-linked add-ons', () {
      const csv = '''name,price,category,is_addon,linked_category
Veg Burger,80,Fast Food,false,
Extra Cheese,25,Addons,true,Fast Food
Ginger,5,Extras,true,Beverages''';

      final result = CsvImportService.parseMenuItemsFromCsv(csv);
      expect(result.items.length, 3);

      final burger = result.items[0];
      expect(burger.name, 'Veg Burger');
      expect(burger.isAddon, isFalse);
      expect(burger.linkedCategory, isNull);

      final cheese = result.items[1];
      expect(cheese.name, 'Extra Cheese');
      expect(cheese.isAddon, isTrue);
      expect(cheese.linkedCategory, 'Fast Food');
      expect(cheese.isApplicableToCategory('Fast Food'), isTrue);
      expect(cheese.isApplicableToCategory('Beverages'), isFalse);

      final ginger = result.items[2];
      expect(ginger.name, 'Ginger');
      expect(ginger.isAddon, isTrue);
      expect(ginger.linkedCategory, 'Beverages');
      expect(ginger.isApplicableToCategory('Beverages'), isTrue);
      expect(ginger.isApplicableToCategory('Fast Food'), isFalse);
    });

    test('parseCategoryOption correctly parses various formats of subcategories and pricing', () {
      final opt1 = CsvImportService.parseCategoryOption('Fried:+10', 'momos', 0);
      expect(opt1.name, 'Fried');
      expect(opt1.additionalCost, 10.0);
      expect(opt1.price, isNull);

      final opt2 = CsvImportService.parseCategoryOption('Pan Fried: +20.50', 'momos', 1);
      expect(opt2.name, 'Pan Fried');
      expect(opt2.additionalCost, 20.50);

      final opt3 = CsvImportService.parseCategoryOption('Discount:-5', 'combos', 2);
      expect(opt3.name, 'Discount');
      expect(opt3.additionalCost, -5.0);

      final opt4 = CsvImportService.parseCategoryOption('Special Jhol:120', 'momos', 3);
      expect(opt4.name, 'Special Jhol');
      expect(opt4.additionalCost, 0.0);
      expect(opt4.price, 120.0);

      final opt5 = CsvImportService.parseCategoryOption('Fried (+15)', 'momos', 4);
      expect(opt5.name, 'Fried');
      expect(opt5.additionalCost, 15.0);

      final opt6 = CsvImportService.parseCategoryOption('Large (₹90)', 'drinks', 5);
      expect(opt6.name, 'Large');
      expect(opt6.price, 90.0);

      final opt7 = CsvImportService.parseCategoryOption('Steam', 'momos', 6);
      expect(opt7.name, 'Steam');
      expect(opt7.additionalCost, 0.0);
      expect(opt7.price, isNull);
    });

    test('parseCsv parses full catalog including category surcharges and subcategory options with prices', () {
      const csv = '''name,price,category,dietary_type,is_available,category_color,category_additional_cost,category_variants,is_addon,linked_category
Veg Momos,80,Momos,veg,true,0xFFEA580C,15,Steam|Fried:+10|Pan Fried:+20|Special Jhol:120,false,
Chicken Momos,100,Momos,non_veg,true,0xFFEA580C,15,Steam|Fried:+10|Pan Fried:+20|Special Jhol:120,false,
Garlic Dip,25,Addons,veg,true,,0.0,,true,Momos
,0.0,Desserts,none,true,0xFF10B981,5,Single Scoop:40|Double Scoop:70,false,''';

      final result = CsvImportService.parseCsv(csv);

      expect(result.items.length, 3);
      expect(result.categories.length, 3); // Momos, Addons, Desserts

      final momosCat = result.categories.firstWhere((c) => c.name == 'Momos');
      expect(momosCat.additionalCost, 15.0);
      expect(momosCat.colorHex, 0xFFEA580C);
      expect(momosCat.options.length, 4);
      expect(momosCat.options[0].name, 'Steam');
      expect(momosCat.options[0].additionalCost, 0.0);
      expect(momosCat.options[1].name, 'Fried');
      expect(momosCat.options[1].additionalCost, 10.0);
      expect(momosCat.options[2].name, 'Pan Fried');
      expect(momosCat.options[2].additionalCost, 20.0);
      expect(momosCat.options[3].name, 'Special Jhol');
      expect(momosCat.options[3].price, 120.0);

      // Verify Veg Momos item inherits the subcategories and category surcharge
      final vegMomos = result.items[0];
      expect(vegMomos.name, 'Veg Momos');
      expect(vegMomos.price, 80.0);
      expect(vegMomos.category.name, 'Momos');
      expect(vegMomos.category.additionalCost, 15.0);
      expect(vegMomos.effectiveVariants.length, 4);
      expect(vegMomos.effectiveVariants[1].additionalCost, 10.0);

      // Verify Addon
      final dip = result.items[2];
      expect(dip.name, 'Garlic Dip');
      expect(dip.isAddon, isTrue);
      expect(dip.linkedCategory, 'Momos');

      // Verify Desserts category from category-only row
      final dessertCat = result.categories.firstWhere((c) => c.name == 'Desserts');
      expect(dessertCat.additionalCost, 5.0);
      expect(dessertCat.options.length, 2);
      expect(dessertCat.options[0].name, 'Single Scoop');
      expect(dessertCat.options[0].price, 40.0);
      expect(dessertCat.options[1].name, 'Double Scoop');
      expect(dessertCat.options[1].price, 70.0);
    });

    test('parseMenuItemsFromCsv parses category surcharges and subcategories for backwards compatibility', () {
      const csv = '''name,price,category,category_additional_cost,category_variants
Veg Momos,80,Momos,10,Steam|Fried:+15|Kurkure:+25''';

      final result = CsvImportService.parseMenuItemsFromCsv(csv);
      expect(result.items.length, 1);
      final item = result.items.first;

      expect(item.name, 'Veg Momos');
      expect(item.category.additionalCost, 10.0);
      expect(item.category.options.length, 3);
      expect(item.category.options[0].name, 'Steam');
      expect(item.category.options[0].additionalCost, 0.0);
      expect(item.category.options[1].name, 'Fried');
      expect(item.category.options[1].additionalCost, 15.0);
      expect(item.category.options[2].name, 'Kurkure');
      expect(item.category.options[2].additionalCost, 25.0);
      expect(item.variants.length, 3);
    });
  });

  group('CsvImportService - Counters', () {
    test('parses counter CSV with standard headers', () {
      const csv = '''title,count,step,target,allowNegative,colorHex
Glasses of Water,2,1,8,false,0xFF0284C7
Workout Reps,10,5,100,false,#059669
Negative Tracker,0,1,,true,0xFFDC2626''';

      final result = CsvImportService.parseCountersFromCsv(csv);

      expect(result.items.length, 3);
      expect(result.items[0].title, 'Glasses of Water');
      expect(result.items[0].count, 2);
      expect(result.items[0].step, 1);
      expect(result.items[0].target, 8);
      expect(result.items[0].allowNegative, isFalse);
      expect(result.items[0].colorHex, 0xFF0284C7);

      expect(result.items[1].title, 'Workout Reps');
      expect(result.items[1].count, 10);
      expect(result.items[1].step, 5);
      expect(result.items[1].target, 100);
      expect(result.items[1].colorHex, 0xFF059669);

      expect(result.items[2].title, 'Negative Tracker');
      expect(result.items[2].target, isNull);
      expect(result.items[2].allowNegative, isTrue);
    });

    test('skips counters without title', () {
      const csv = '''title,count,step
Daily Pushups,0,10
,5,1''';

      final result = CsvImportService.parseCountersFromCsv(csv);

      expect(result.items.length, 1);
      expect(result.items[0].title, 'Daily Pushups');
      expect(result.skippedRowsCount, 1);
    });
  });
}
