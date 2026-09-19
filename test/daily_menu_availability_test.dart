import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/src/controllers/counter_controller.dart';
import 'package:counter_app/src/storage/stall_storage_service.dart';
import 'package:counter_app/src/storage/app_storage.dart';
import 'package:counter_app/main.dart';
import 'package:counter_app/src/models/stall_models.dart';
import 'package:counter_app/src/controllers/order_controller.dart';
import 'package:counter_app/src/widgets/stall_pos/category_config_dialog.dart';
import 'package:counter_app/src/widgets/stall_pos/daily_menu_availability_view.dart';

void main() {
  group('Daily Menu Availability - Model Tests', () {
    test('MenuItem defaults isAvailable to true and serializes correctly', () {
      final item = MenuItem(
        id: 'chai_1',
        name: 'Masala Chai',
        price: 20.0,
        category: const ItemCategory(id: 'cat_bev', name: 'Beverages'),
      );

      expect(item.isAvailable, isTrue);

      final copy = item.copyWith(isAvailable: false);
      expect(copy.isAvailable, isFalse);
      expect(copy.name, equals('Masala Chai'));

      final json = copy.toJson();
      expect(json['unavailableVariants'], contains('chai_1'));

      final fromJson = MenuItem.fromJson(json);
      expect(fromJson.isAvailable, isFalse);

      // Null fallback
      final legacyJson = {
        'id': 'chai_legacy',
        'name': 'Legacy Chai',
        'price': 15.0,
        'category': 'Beverages',
      };
      final legacyItem = MenuItem.fromJson(legacyJson);
      expect(legacyItem.isAvailable, isTrue);
    });

    test('ItemCategory helper methods', () {
      final cat = ItemCategory(
        id: 'cat_bev',
        name: 'Beverages',
        additionalCost: 5.0,
        colorHex: 0xFF1D4ED8,
      );

      expect(cat.matches('Beverages'), isTrue);
      expect(cat.matches('beverages'), isTrue);
      expect(cat.matches('Snacks'), isFalse);
      expect(cat.color, equals(const Color(0xFF1D4ED8)));
      expect(ItemCategory.normalize('  Beverages '), equals('beverages'));
      expect(ItemCategory.normalize('Fast Food'), equals('fast_food'));
    });
  });

  group('Daily Menu Availability - OrderController Tests', () {
    late OrderController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'stall_menu': jsonEncode([
          {
            'id': 'bev_1',
            'name': 'Masala Chai',
            'price': 20.0,
            'category': 'Beverages',
            'isAvailable': true,
            'addons': [
              {
                'id': 'addon_1',
                'name': 'Extra Milk',
                'price': 5.0,
                'isEnabled': true,
              }
            ],
          },
          {
            'id': 'bev_2',
            'name': 'Filter Coffee',
            'price': 25.0,
            'category': 'Beverages',
            'isAvailable': true,
          },
          {
            'id': 'snack_1',
            'name': 'Samosa',
            'price': 15.0,
            'category': 'Snacks',
            'isAvailable': true,
          },
        ]),
        'stall_orders': jsonEncode([]),
        'stall_next_token': 1,
      });

      controller = OrderController(storage: StallStorageService());
      await controller.loadPersistedData();
    });

    test('Initializes with all items available', () {
      expect(controller.menu.length, equals(3));
      expect(controller.availableMenu.length, equals(3));
      expect(controller.filteredMenu.length, equals(3));
      expect(controller.groupedMenu.containsKey('Beverages'), isTrue);
      expect(controller.groupedMenu.containsKey('Snacks'), isTrue);
    });

    test('toggleItemAvailability updates availability and filtered lists', () {
      // Toggle off Samosa
      controller.toggleItemAvailability('snack_1');

      final samosa = controller.findItem('snack_1');
      expect(samosa.isAvailable, isFalse);

      // availableMenu reflects change
      expect(controller.availableMenu.any((i) => i.id == 'snack_1'), isFalse);

      // filteredMenu excludes it
      expect(controller.filteredMenu.any((i) => i.id == 'snack_1'), isFalse);

      // groupedMenu completely removes Snacks since all items in Snacks are unavailable
      expect(controller.groupedMenu.containsKey('Snacks'), isFalse);

      // But allFilteredMenu and allGroupedMenu still retain it
      expect(controller.allFilteredMenu.any((i) => i.id == 'snack_1'), isTrue);
      expect(controller.allGroupedMenu.containsKey('Snacks'), isTrue);

      // Toggle back on
      controller.toggleItemAvailability('snack_1');
      expect(controller.findItem('snack_1').isAvailable, isTrue);
      expect(controller.groupedMenu.containsKey('Snacks'), isTrue);
    });

    test('Disabling add-on excludes it from getAddonsForCategory', () async {
      expect(controller.getAddonsForCategory('Beverages').length, equals(1));
      expect(controller.hasAddonsForCategory('Beverages'), isTrue);

      // Disable the add-on
      await controller.setItemAvailability('addon_1', false);

      expect(controller.getAddonsForCategory('Beverages').length, equals(0));
      expect(controller.hasAddonsForCategory('Beverages'), isFalse);
    });

    test('setCategoryAvailability disables and enables all items in a category', () {
      controller.setCategoryAvailability('Beverages', false);

      expect(controller.findItem('bev_1').isAvailable, isFalse);
      expect(controller.findItem('bev_2').isAvailable, isFalse);
      // Snack item was untouched
      expect(controller.findItem('snack_1').isAvailable, isTrue);

      // Re-enable Beverages
      controller.setCategoryAvailability('Beverages', true);
      expect(controller.findItem('bev_1').isAvailable, isTrue);
      expect(controller.findItem('bev_2').isAvailable, isTrue);
    });

    test('setAllItemsAvailability toggles all items globally', () {
      controller.setAllItemsAvailability(false);
      expect(controller.availableMenu.isEmpty, isTrue);
      expect(controller.groupedMenu.isEmpty, isTrue);
      expect(controller.allGroupedMenu.isNotEmpty, isTrue);

      controller.setAllItemsAvailability(true);
      expect(controller.availableMenu.length, equals(3));
    });
  });

  group('Daily Menu Availability - Widget Tests', () {
    late OrderController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'stall_menu': jsonEncode([
          {
            'id': 'bev_1',
            'name': 'Masala Chai',
            'price': 20.0,
            'category': 'Beverages',
            'isAvailable': true,
          },
          {
            'id': 'snack_1',
            'name': 'Veg Samosa',
            'price': 15.0,
            'category': 'Snacks',
            'isAvailable': true,
          },
        ]),
        'stall_orders': jsonEncode([]),
        'stall_next_token': 1,
      });

      controller = OrderController(storage: StallStorageService());
      await controller.loadPersistedData();
    });

    testWidgets('DailyMenuAvailabilityDialog toggles items, search filters, and batch updates',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DailyMenuAvailabilityDialog.show(
                  context,
                  controller: controller,
                  getCategoryColor: (_) => Colors.blue,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Daily Menu Availability'), findsOneWidget);
      expect(find.text('Masala Chai'), findsOneWidget);
      expect(find.text('Veg Samosa'), findsOneWidget);

      // Toggle Masala Chai switch off
      final chaiSwitch = find.byKey(const ValueKey('item_switch_bev_1'));
      expect(chaiSwitch, findsOneWidget);
      await tester.tap(chaiSwitch);
      await tester.pumpAndSettle();

      expect(controller.findItem('bev_1').isAvailable, isFalse);

      // Test Search Filter
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'Samosa');
      await tester.pumpAndSettle();

      expect(find.text('Veg Samosa'), findsOneWidget);
      expect(find.text('Masala Chai'), findsNothing);

      // Clear search
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      // Test Batch "Disable All" button
      final disableAllBtn = find.byKey(const ValueKey('disable_all_items_btn'));
      await tester.tap(disableAllBtn);
      await tester.pumpAndSettle();

      expect(controller.findItem('bev_1').isAvailable, isFalse);
      expect(controller.findItem('snack_1').isAvailable, isFalse);

      // Test Batch "Enable All" button
      final enableAllBtn = find.byKey(const ValueKey('enable_all_items_btn'));
      await tester.tap(enableAllBtn);
      await tester.pumpAndSettle();

      expect(controller.findItem('bev_1').isAvailable, isTrue);
      expect(controller.findItem('snack_1').isAvailable, isTrue);

      // Tap Done
      await tester.tap(find.byKey(const ValueKey('daily_availability_done_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Daily Menu Availability'), findsNothing);
    });

    testWidgets('Store Admin bottom navbar daily availability hides item from POS register',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'stall_menu': jsonEncode([
          {
            'id': 'bev_1',
            'name': 'Masala Chai',
            'price': 20.0,
            'category': 'Beverages',
            'isAvailable': true,
          },
          {
            'id': 'snack_1',
            'name': 'Veg Samosa',
            'price': 15.0,
            'category': 'Snacks',
            'isAvailable': true,
          },
        ]),
      });
      final counterCtrl = CounterController(storageService: AppStorage.instance.counterStorage);
      await counterCtrl.init();

      await tester.pumpWidget(StallPosApp(controller: counterCtrl, initialIndex: 1));
      await tester.pumpAndSettle();

      // Masala Chai and Veg Samosa initially visible on register
      expect(find.text('Masala Chai'), findsWidgets);
      expect(find.text('Veg Samosa'), findsWidgets);

      // Switch to Store Admin via bottom navigation bar
      await tester.tap(find.byTooltip('Store Admin'));
      await tester.pumpAndSettle();

      expect(find.text('Daily Availability'), findsOneWidget);

      // Toggle off Veg Samosa
      final samosaSwitch = find.byKey(const ValueKey('item_switch_snack_1'));
      expect(samosaSwitch, findsOneWidget);
      await tester.tap(samosaSwitch);
      await tester.pumpAndSettle();

      // Switch back to Stall POS tab
      await tester.tap(find.byTooltip('Stall POS'));
      await tester.pumpAndSettle();

      // Masala Chai still visible, Veg Samosa hidden from take-order register
      expect(find.text('Masala Chai'), findsWidgets);
      expect(find.text('Veg Samosa'), findsNothing);
    });

    test('MenuItem hasAvailableVariants and isEffectivelyAvailable calculation', () {
      final momos = MenuItem(
        id: 'momo_1',
        name: 'Veg Momos',
        price: 80.0,
        category: const ItemCategory(
          id: 'cat_momos',
          name: 'Momos',
          options: [
            CategoryOption(id: 'v1', name: 'Steam', isEnabled: true),
            CategoryOption(id: 'v2', name: 'Fried', isEnabled: true),
          ],
        ),
      );

      expect(momos.hasVariants, isTrue);
      expect(momos.hasAvailableVariants, isTrue);
      expect(momos.isEffectivelyAvailable, isTrue);

      // Disable 1 variant
      final oneDisabled = momos.copyWith(
        category: momos.category.copyWith(
          options: const [
            CategoryOption(id: 'v1', name: 'Steam', isEnabled: true),
            CategoryOption(id: 'v2', name: 'Fried', isEnabled: false),
          ],
        ),
      );
      expect(oneDisabled.hasAvailableVariants, isTrue);
      expect(oneDisabled.isEffectivelyAvailable, isTrue);

      // Disable all variants
      final allDisabled = momos.copyWith(
        category: momos.category.copyWith(
          options: const [
            CategoryOption(id: 'v1', name: 'Steam', isEnabled: false),
            CategoryOption(id: 'v2', name: 'Fried', isEnabled: false),
          ],
        ),
      );
      expect(allDisabled.hasAvailableVariants, isFalse);
      expect(allDisabled.isEffectivelyAvailable, isFalse);

      // Item marked unavailable
      final itemUnavailable = momos.copyWith(isAvailable: false);
      expect(itemUnavailable.isEffectivelyAvailable, isFalse);
    });

    test('OrderController renameCategory updates categories, menu items, and linked addons', () async {
      SharedPreferences.setMockInitialValues({
        'stall_menu': jsonEncode([
          {
            'id': 'momo_1',
            'name': 'Veg Momos',
            'price': 80.0,
            'category': 'Momos',
            'isAvailable': true,
          },
        ]),
        'stall_categories': jsonEncode([
          {
            'id': 'cat_momos',
            'name': 'Momos',
            'additionalCost': 0.0,
          },
        ]),
      });

      final controller = OrderController(storage: StallStorageService());
      await controller.loadPersistedData();

      expect(controller.categories.contains('Momos'), isTrue);

      // Rename Momos -> Dimsums
      await controller.renameCategory('Momos', 'Dimsums');

      expect(controller.categories.contains('Momos'), isFalse);
      expect(controller.categories.contains('Dimsums'), isTrue);

      // Check item category
      final item = controller.findItem('momo_1');
      expect(item.categoryName, equals('Dimsums'));
    });

    test('OrderController toggleMenuItemVariantAvailability toggles individual variant and updates availability', () async {
      SharedPreferences.setMockInitialValues({
        'stall_menu': jsonEncode([
          {
            'id': 'momo_1',
            'name': 'Veg Momos',
            'price': 80.0,
            'category': 'Momos',
            'isAvailable': true,
            'variants': [
              {'id': 'v_steam', 'name': 'Steam', 'isEnabled': true},
              {'id': 'v_fried', 'name': 'Fried', 'isEnabled': true},
            ],
          },
        ]),
      });

      final controller = OrderController(storage: StallStorageService());
      await controller.loadPersistedData();

      var item = controller.findItem('momo_1');
      expect(item.isEffectivelyAvailable, isTrue);
      expect(item.effectiveVariants.first.isAvailable, isTrue);

      // Toggle Steam off
      await controller.toggleMenuItemVariantAvailability('momo_1', 'Steam');
      item = controller.findItem('momo_1');
      expect(item.effectiveVariants.firstWhere((v) => v.name == 'Steam').isAvailable, isFalse);
      expect(item.isEffectivelyAvailable, isTrue); // Fried is still available

      // Toggle Fried off
      await controller.toggleMenuItemVariantAvailability('momo_1', 'Fried');
      item = controller.findItem('momo_1');
      expect(item.effectiveVariants.firstWhere((v) => v.name == 'Fried').isAvailable, isFalse);
      expect(item.hasAvailableVariants, isFalse);
      expect(item.isEffectivelyAvailable, isFalse); // All variants now disabled

      // availableMenu excludes momos
      expect(controller.availableMenu.any((i) => i.id == 'momo_1'), isFalse);
    });

    testWidgets('DailyMenuAvailabilityView displays variant chips and toggles variant availability', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'stall_menu': jsonEncode([
          {
            'id': 'momo_1',
            'name': 'Veg Momos',
            'price': 80.0,
            'category': 'Momos',
            'isAvailable': true,
            'variants': [
              {'id': 'v_steam', 'name': 'Steam', 'price': 80.0, 'isEnabled': true},
              {'id': 'v_fried', 'name': 'Fried', 'price': 90.0, 'isEnabled': true},
            ],
          },
        ]),
      });

      final controller = OrderController(storage: StallStorageService());
      await controller.loadPersistedData();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyMenuAvailabilityView(
              controller: controller,
              getCategoryColor: (_) => Colors.blue,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expect variant chips to be visible
      expect(find.byKey(const ValueKey('var_toggle_momo_1_Steam')), findsOneWidget);
      expect(find.byKey(const ValueKey('var_toggle_momo_1_Fried')), findsOneWidget);
      expect(find.text('2/2 In Stock'), findsOneWidget);

      // Tap on Fried variant chip to toggle off
      final friedChip = find.byKey(const ValueKey('var_toggle_momo_1_Fried'));
      expect(friedChip, findsOneWidget);
      await tester.tap(friedChip);
      await tester.pumpAndSettle();

      // Status badge should now show 1/2 In Stock
      expect(find.text('1/2 In Stock'), findsOneWidget);
      expect(find.text('(Sold Out)'), findsOneWidget);
      expect(controller.findItem('momo_1').effectiveVariants.firstWhere((v) => v.name == 'Fried').isAvailable, isFalse);
    });

    testWidgets('CategoryConfigDialog displays editable category name with slash support and renames category', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'stall_menu': jsonEncode([
          {
            'id': 'rice_1',
            'name': 'Fried Rice',
            'price': 100.0,
            'category': 'Rice / Noodles',
            'isAvailable': true,
          },
        ]),
        'stall_categories': jsonEncode([
          {
            'id': 'cat_rn',
            'name': 'Rice / Noodles',
            'additionalCost': 0.0,
          },
        ]),
      });

      final controller = OrderController(storage: StallStorageService());
      await controller.loadPersistedData();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => CategoryConfigDialog.show(
                    context,
                    categoryName: 'Rice / Noodles',
                    controller: controller,
                    getCategoryColor: (_) => Colors.orange,
                  ),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Category Name'), findsOneWidget);
      expect(find.text('Use "/" to define slash sub-categories (e.g. Rice / Noodles)'), findsOneWidget);

      // Edit category name to Rice / Hakka Noodles
      final nameField = find.widgetWithText(TextField, 'Rice / Noodles');
      await tester.enterText(nameField, 'Rice / Hakka Noodles');
      await tester.pumpAndSettle();

      // Tap Save Changes
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Verify category renamed
      expect(controller.categories.contains('Rice / Hakka Noodles'), isTrue);
      expect(controller.findItem('rice_1').categoryName, equals('Rice / Hakka Noodles'));
    });

    test('OrderController isolates item-level variant and addon availability from other items', () async {
      final momosCat = ItemCategory(
        id: 'cat_momos',
        name: 'Momos',
        options: const [
          CategoryOption(id: 'v_steam', name: 'Steam', isEnabled: true),
          CategoryOption(id: 'v_fried', name: 'Fried', isEnabled: true),
        ],
        addons: const [
          CategoryOption(id: 'a_mayo', name: 'Extra Mayo', priceDelta: 10.0, isEnabled: true),
          CategoryOption(id: 'a_cheese', name: 'Cheese Dip', priceDelta: 20.0, isEnabled: true),
        ],
      );

      final vegMomo = MenuItem(
        id: 'veg_momo',
        name: 'Veg Momos',
        price: 80.0,
        category: momosCat,
      );

      final chickenMomo = MenuItem(
        id: 'chicken_momo',
        name: 'Chicken Momos',
        price: 100.0,
        category: momosCat,
      );

      SharedPreferences.setMockInitialValues({
        'stall_menu': jsonEncode([vegMomo.toJson(), chickenMomo.toJson()]),
        'stall_categories': jsonEncode([momosCat.toJson()]),
      });

      final controller = OrderController(storage: StallStorageService());
      await controller.loadPersistedData();

      // Initial state: both items have all variants & addons available
      expect(controller.findItem('veg_momo').effectiveVariants.every((v) => v.isAvailable), isTrue);
      expect(controller.findItem('chicken_momo').effectiveVariants.every((v) => v.isAvailable), isTrue);
      expect(controller.findItem('veg_momo').effectiveAddons.every((a) => a.isAvailable), isTrue);
      expect(controller.findItem('chicken_momo').effectiveAddons.every((a) => a.isAvailable), isTrue);

      // 1. Toggle Fried variant on veg_momo ONLY
      await controller.toggleMenuItemVariantAvailability('veg_momo', 'Fried');

      final vegAfterVar = controller.findItem('veg_momo');
      final chickenAfterVar = controller.findItem('chicken_momo');

      // veg_momo has Fried unavailable
      expect(vegAfterVar.effectiveVariants.firstWhere((v) => v.name == 'Fried').isAvailable, isFalse);
      expect(vegAfterVar.effectiveVariants.firstWhere((v) => v.name == 'Steam').isAvailable, isTrue);
      expect(vegAfterVar.isAvailable, isTrue);

      // chicken_momo is completely unaffected! Fried is still available
      expect(chickenAfterVar.effectiveVariants.firstWhere((v) => v.name == 'Fried').isAvailable, isTrue);
      expect(chickenAfterVar.effectiveVariants.firstWhere((v) => v.name == 'Steam').isAvailable, isTrue);

      // 2. Toggle Extra Mayo addon on veg_momo ONLY
      await controller.toggleMenuItemAddonAvailability('veg_momo', 'Extra Mayo');

      final vegAfterAddon = controller.findItem('veg_momo');
      final chickenAfterAddon = controller.findItem('chicken_momo');

      expect(vegAfterAddon.effectiveAddons.firstWhere((a) => a.name == 'Extra Mayo').isAvailable, isFalse);
      expect(vegAfterAddon.effectiveAddons.firstWhere((a) => a.name == 'Cheese Dip').isAvailable, isTrue);

      // chicken_momo is unaffected! Extra Mayo is still available
      expect(chickenAfterAddon.effectiveAddons.firstWhere((a) => a.name == 'Extra Mayo').isAvailable, isTrue);

      // 3. Category-level variant toggle: disable Steam for the ENTIRE category
      await controller.toggleCategoryVariantAvailability('Momos', 'Steam', isAvailable: false);

      final vegAfterCat = controller.findItem('veg_momo');
      final chickenAfterCat = controller.findItem('chicken_momo');

      // Steam is now disabled for both items
      expect(vegAfterCat.effectiveVariants.firstWhere((v) => v.name == 'Steam').isAvailable, isFalse);
      expect(chickenAfterCat.effectiveVariants.firstWhere((v) => v.name == 'Steam').isAvailable, isFalse);

      // And since veg_momo also had Fried disabled at item-level, all its variants are disabled!
      expect(vegAfterCat.hasAvailableVariants, isFalse);
      expect(vegAfterCat.isAvailable, isFalse); // Dynamically out of stock!

      // chicken_momo still has Fried available!
      expect(chickenAfterCat.effectiveVariants.firstWhere((v) => v.name == 'Fried').isAvailable, isTrue);
      expect(chickenAfterCat.isAvailable, isTrue);
    });
  });
}
