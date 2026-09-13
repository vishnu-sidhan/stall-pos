import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/data/services/stall_storage_service.dart';
import 'package:counter_app/screens/stall_pos_screen.dart';
import 'package:counter_app/widgets/stall_pos/daily_menu_availability_dialog.dart';

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
      expect(json['isAvailable'], isFalse);

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
          {
            'id': 'addon_1',
            'name': 'Extra Milk',
            'price': 5.0,
            'category': 'Beverages',
            'isAddon': true,
            'linkedCategory': 'Beverages',
            'isAvailable': true,
          },
        ]),
        'stall_orders': jsonEncode([]),
        'stall_next_token': 1,
      });

      controller = OrderController(storageService: StallStorageService());
      await controller.loadPersistedData();
    });

    test('Initializes with all items available', () {
      expect(controller.menu.length, equals(4));
      expect(controller.availableMenu.length, equals(4));
      expect(controller.filteredMenu.length, equals(4));
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

    test('Disabling add-on excludes it from getAddonsForCategory', () {
      expect(controller.getAddonsForCategory('Beverages').length, equals(1));
      expect(controller.hasAddonsForCategory('Beverages'), isTrue);

      // Disable the add-on
      controller.setItemAvailability('addon_1', false);

      expect(controller.getAddonsForCategory('Beverages').length, equals(0));
      expect(controller.hasAddonsForCategory('Beverages'), isFalse);
    });

    test('setCategoryAvailability disables and enables all items in a category', () {
      controller.setCategoryAvailability('Beverages', false);

      expect(controller.findItem('bev_1').isAvailable, isFalse);
      expect(controller.findItem('bev_2').isAvailable, isFalse);
      expect(controller.findItem('addon_1').isAvailable, isFalse);
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
      expect(controller.availableMenu.length, equals(4));
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

      controller = OrderController(storageService: StallStorageService());
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
      expect(find.text('Masala Chai (Beverages)'), findsOneWidget);
      expect(find.text('Veg Samosa (Snacks)'), findsOneWidget);

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

      expect(find.text('Veg Samosa (Snacks)'), findsOneWidget);
      expect(find.text('Masala Chai (Beverages)'), findsNothing);

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

    testWidgets('StallPosScreen AppBar daily availability button opens dialog and hides item from register',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: StallPosScreen()));
      await tester.pumpAndSettle();

      // Masala Chai and Veg Samosa initially visible on register
      expect(find.text('Masala Chai (Beverages)'), findsWidgets);
      expect(find.text('Veg Samosa (Snacks)'), findsWidgets);

      // Tap Daily Menu Availability button in AppBar
      final availabilityBtn = find.byKey(const ValueKey('daily_availability_appbar_btn'));
      expect(availabilityBtn, findsOneWidget);
      await tester.tap(availabilityBtn);
      await tester.pumpAndSettle();

      expect(find.text('Daily Menu Availability'), findsOneWidget);

      // Toggle off Veg Samosa
      final samosaSwitch = find.byKey(const ValueKey('item_switch_snack_1'));
      await tester.tap(samosaSwitch);
      await tester.pumpAndSettle();

      // Close dialog
      await tester.tap(find.byKey(const ValueKey('daily_availability_done_btn')));
      await tester.pumpAndSettle();

      // Masala Chai still visible, Veg Samosa hidden from take-order register
      expect(find.text('Masala Chai (Beverages)'), findsWidgets);
      expect(find.text('Veg Samosa (Snacks)'), findsNothing);
    });
  });
}
