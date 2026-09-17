import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/src/storage/app_storage.dart';
import 'package:counter_app/src/storage/stall_storage.dart';
import 'package:counter_app/src/controllers/order_controller.dart';
import 'package:counter_app/src/models/stall_models.dart';
import 'package:counter_app/src/views/stall_pos_view.dart';
import 'package:counter_app/src/widgets/stall_pos/stall_pos_widgets.dart';

void main() {
  group('CategoryOption & Model Tests', () {
    test('CategoryOption serializes and deserializes to JSON accurately', () {
      const variant = CategoryOption(
        id: 'var_large',
        name: 'Large',
        price: 80.0,
        isEnabled: true,
      );

      final json = variant.toJson();
      expect(json['id'], 'var_large');
      expect(json['name'], 'Large');
      expect(json['price'], 80.0);
      expect(json['is_available'], true);

      final fromJson = CategoryOption.fromJson(json);
      expect(fromJson.id, 'var_large');
      expect(fromJson.name, 'Large');
      expect(fromJson.price, 80.0);
      expect(fromJson.isAvailable, true);
    });

    test('ItemCategory with variants serializes and deserializes via MenuItem', () {
      const category = ItemCategory(
        id: 'cat_pizza',
        name: 'Pizza',
        options: [
          CategoryOption(id: 'v1', name: 'Regular', price: 150.0),
          CategoryOption(id: 'v2', name: 'Medium', price: 250.0),
          CategoryOption(id: 'v3', name: 'Large', price: 350.0),
        ],
      );
      const item = MenuItem(
        id: 'item_pizza',
        name: 'Margherita Pizza',
        price: 150.0,
        category: category,
      );

      final json = item.toJson();
      expect(json['categoryObject'], isNotNull);
      final catJson = json['categoryObject'] as Map;
      expect(catJson['options'], isNotNull);
      final variantsList = catJson['options'] as List;
      expect(variantsList.length, 3);
      expect(variantsList[1]['name'], 'Medium');
      expect(variantsList[1]['price'], 250.0);

      final reconstructed = MenuItem.fromJson(json);
      expect(reconstructed.effectiveVariants.length, 3);
      expect(reconstructed.effectiveVariants[2].name, 'Large');
      expect(reconstructed.effectiveVariants[2].price, 350.0);
      expect(reconstructed.priceForVariant(reconstructed.effectiveVariants[2]), 350.0);
    });

    test('effectiveVariants inherits from category.effectiveOptions', () {
      const category = ItemCategory(
        id: 'cat_beverages',
        name: 'Beverages',
        options: [
          CategoryOption(id: 'opt_hot', name: 'Hot', priceDelta: 0.0),
          CategoryOption(id: 'opt_cold', name: 'Cold', priceDelta: 10.0),
        ],
      );
      const item = MenuItem(
        id: 'item_coffee',
        name: 'Coffee',
        price: 20.0,
        category: category,
      );

      expect(item.effectiveVariants.length, 2);
      expect(item.effectiveVariants[0].name, 'Hot');
      expect(item.effectiveVariants[1].name, 'Cold');
      expect(item.priceForVariant(item.effectiveVariants[1]), 30.0);
    });

    test('MenuItem with category addons serializes and deserializes accurately', () {
      const category = ItemCategory(
        id: 'cat_burgers',
        name: 'Burgers',
        addons: [
          CategoryOption(id: 'add_cheese', name: 'Cheese', priceDelta: 20.0),
          CategoryOption(id: 'add_sauce', name: 'Sauce', priceDelta: 10.0),
        ],
      );
      const item = MenuItem(
        id: 'item_burger',
        name: 'Burger',
        price: 80.0,
        category: category,
      );
      final json = item.toJson();
      final reconstructed = MenuItem.fromJson(json);
      expect(reconstructed.addons.length, 2);
      expect(reconstructed.addons[0].name, 'Cheese');
      expect(reconstructed.addons[0].priceDelta, 20.0);
    });
  });

  group('StoreManagementDialog Widget Tests', () {
    late StallStorage storage;
    late OrderController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'stall_menu': jsonEncode([
          {'id': '101', 'name': 'Tea', 'price': 15.0, 'category': 'Beverages'},
          {'id': '102', 'name': 'Samosa', 'price': 20.0, 'category': 'Snacks'},
        ]),
        'stall_orders': jsonEncode([]),
      });
      storage = AppStorage.instance.stallStorage;
      controller = OrderController(storage: storage);
      await controller.loadPersistedData();
    });

    testWidgets('StoreManagementDialog switches tabs and filters menu catalog', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => StoreManagementDialog.show(
                  ctx,
                  controller: controller,
                  getCategoryColor: (_) => Colors.orange,
                  onOpenOrderHistory: () {},
                  onOpenCsvImport: () {},
                  onAddOrEditItem: (_) {},
                ),
                child: const Text('Open Studio'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Store Management Studio
      await tester.tap(find.text('Open Studio'));
      await tester.pumpAndSettle();

      // Verify title and 4 tabs
      expect(find.text('Store Management Studio'), findsOneWidget);
      expect(find.text('Daily Availability'), findsOneWidget);
      expect(find.text('Menu & Variants'), findsOneWidget);
      expect(find.text('Categories & Fees'), findsOneWidget);
      expect(find.text('History & Tools'), findsOneWidget);

      // Switch to Menu & Variants tab
      await tester.tap(find.text('Menu & Variants'));
      await tester.pumpAndSettle();

      expect(find.text('Tea'), findsOneWidget);
      expect(find.text('Samosa'), findsOneWidget);
      expect(find.text('Add Item'), findsOneWidget);

      // Search inside menu catalog
      await tester.enterText(find.byType(TextField), 'Tea');
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('Tea'),
        ),
        findsOneWidget,
      );
      expect(find.text('Samosa'), findsNothing);

      // Switch to History & Tools tab
      await tester.tap(find.text('History & Tools'));
      await tester.pumpAndSettle();

      expect(find.text('Full Order & Sales History'), findsOneWidget);
      expect(find.text('Upload Menu CSV'), findsOneWidget);
    });
  });

  group('UnifiedItemCustomizerSheet Basic Customization Tests', () {
    late StallStorage storage;
    late OrderController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'stall_menu': jsonEncode([
          {
            'id': 'item_burger',
            'name': 'Burger',
            'price': 100.0,
            'category': 'Fast Food',
            'variants': [
              {'id': 'v_reg', 'name': 'Single Patty', 'price': 100.0, 'is_available': true},
              {'id': 'v_dbl', 'name': 'Double Patty', 'price': 160.0, 'is_available': true},
            ],
            'addons': [
              {'id': 'addon_cheese', 'name': 'Extra Cheese', 'price_delta': 30.0, 'is_available': true},
            ],
          },
        ]),
        'stall_orders': jsonEncode([]),
      });
      storage = AppStorage.instance.stallStorage;
      controller = OrderController(storage: storage);
      await controller.loadPersistedData();
    });

    testWidgets('UnifiedItemCustomizerSheet selects variant and adds to cart with live price', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final burger = controller.menu.firstWhere((i) => i.name == 'Burger');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => UnifiedItemCustomizerSheet.show(
                  ctx,
                  item: burger,
                  controller: controller,
                  getCategoryColor: (_) => Colors.blue,
                ),
                child: const Text('Open Customizer'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Customizer'));
      await tester.pumpAndSettle();

      // Verify customizer UI elements
      expect(find.text('Burger'), findsOneWidget);
      expect(find.text('Single Patty (₹100)'), findsOneWidget);
      expect(find.text('Double Patty (₹160)'), findsOneWidget);
      expect(find.text('Extra Cheese'), findsOneWidget);

      // Select Double Patty (160)
      await tester.tap(find.text('Double Patty (₹160)'));
      await tester.pumpAndSettle();

      // Add 1x Extra Cheese (+₹30) -> Total = 160 + 30 = 190
      final cheeseRow = find.ancestor(of: find.text('Extra Cheese'), matching: find.byType(Row)).first;
      final cheeseAddBtn = find.descendant(of: cheeseRow, matching: find.byIcon(Icons.add));
      await tester.tap(cheeseAddBtn);
      await tester.pumpAndSettle();

      expect(find.text('Add to Cart • ₹190'), findsOneWidget);

      // Tap Add to Cart
      await tester.tap(find.text('Add to Cart • ₹190'));
      await tester.pumpAndSettle();

      // Customizer closed and cart populated
      expect(find.text('Open Customizer'), findsOneWidget);
      expect(controller.cart.isNotEmpty, isTrue);
      expect(controller.cartTotal, 190.0);
    });

    testWidgets('UnifiedItemCustomizerSheet disables sold-out variant and prevents selection', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Item with one disabled variant and one enabled variant
      const item = MenuItem(
        id: 'drink_1',
        name: 'Milkshake',
        price: 80.0,
        category: ItemCategory(
          id: 'cat_drinks',
          name: 'Drinks',
          options: [
            CategoryOption(id: 'v_reg', name: 'Regular', price: 80.0, isEnabled: true),
            CategoryOption(id: 'v_lrg', name: 'Large', price: 120.0, isEnabled: false),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => UnifiedItemCustomizerSheet.show(
                  ctx,
                  item: item,
                  controller: controller,
                  getCategoryColor: (_) => Colors.purple,
                ),
                child: const Text('Open Drink Customizer'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Drink Customizer'));
      await tester.pumpAndSettle();

      // Regular should be present, Large should show Sold Out
      expect(find.text('Regular (₹80)'), findsOneWidget);
      expect(find.text('Large (Sold Out)'), findsOneWidget);

      // Tapping Sold Out variant should not change selection
      await tester.tap(find.text('Large (Sold Out)'));
      await tester.pumpAndSettle();

      // Price should still be Regular (₹80)
      expect(find.text('Add to Cart • ₹80'), findsOneWidget);
    });
  });

  group('1-Tap Fast Checkout Tests', () {
    testWidgets('Tapping 1-Tap Cash directly places paid Cash order without dialogs', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'stall_menu': jsonEncode([
          {'id': '101', 'name': 'Chai', 'price': 15.0, 'category': 'Beverages'},
        ]),
        'stall_orders': jsonEncode([]),
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: StallPosScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Add Chai to cart
      await tester.tap(find.text('Chai'));
      await tester.pumpAndSettle();

      // Fast checkout buttons should now be visible in cart panel
      expect(find.byKey(const ValueKey('fast_cash_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('fast_upi_btn')), findsOneWidget);

      // Tap 1-Tap Cash
      await tester.tap(find.byKey(const ValueKey('fast_cash_btn')));
      await tester.pumpAndSettle();

      // Cart should be empty, order placed directly as Paid Cash
      expect(find.text('TAP ITEMS TO START (#2)'), findsOneWidget);
      expect(find.text('Order #1 paid via Cash and placed!'), findsOneWidget);
    });
  });

  group('UnifiedItemCustomizerSheet Tests', () {
    late StallStorage storage;
    late OrderController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = AppStorage.instance.stallStorage;
      controller = OrderController(storage: storage);
      await controller.loadPersistedData();
    });

    testWidgets('Item in category with options renders Select Variant / Portion', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const category = ItemCategory(
        id: 'cat_rn',
        name: 'Rice/Noodles',
        options: [
          CategoryOption(id: 'opt_rice', name: 'Rice'),
          CategoryOption(id: 'opt_noodles', name: 'Noodles'),
        ],
      );

      const item = MenuItem(
        id: 'egg_rn',
        name: 'Double Egg',
        price: 190.0,
        category: category,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => UnifiedItemCustomizerSheet.show(
                  ctx,
                  item: item,
                  controller: controller,
                  getCategoryColor: (_) => Colors.green,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Select Variant / Portion must be present
      expect(find.text('Select Variant / Portion'), findsOneWidget);
      expect(find.text('Add-ons & Extras'), findsNothing);

      // Rice and Noodles chips should appear
      expect(find.widgetWithText(ChoiceChip, 'Rice'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Noodles'), findsOneWidget);

      // Selecting Noodles updates variant
      await tester.tap(find.widgetWithText(ChoiceChip, 'Noodles'));
      await tester.pumpAndSettle();

      // Add to Cart
      await tester.tap(find.text('Add to Cart • ₹190'));
      await tester.pumpAndSettle();

      expect(controller.cart.isNotEmpty, isTrue);
      expect(controller.cart.keys.first, contains('Noodles'));
    });

    testWidgets('Item with addons renders Add-ons & Extras section with increment/decrement', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const item = MenuItem(
        id: 'burger_combo',
        name: 'Veg Burger',
        price: 120.0,
        category: ItemCategory(
          id: 'cat_burgers',
          name: 'Burgers',
          addons: [
            CategoryOption(id: 'addon_cheese', name: 'Cheese Slice', priceDelta: 25.0),
            CategoryOption(id: 'addon_fries', name: 'Extra Fries', priceDelta: 50.0),
          ],
        ),
      );
      await controller.setMenu([item]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => UnifiedItemCustomizerSheet.show(
                  ctx,
                  item: item,
                  controller: controller,
                  getCategoryColor: (_) => Colors.red,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Add-ons & Extras must be present
      expect(find.text('Add-ons & Extras'), findsOneWidget);
      expect(find.text('Select Variant / Portion'), findsNothing);

      expect(find.text('Cheese Slice'), findsOneWidget);
      expect(find.text('+₹25'), findsOneWidget);

      // Tap '+' to add cheese slice
      final cheeseRow = find.ancestor(of: find.text('Cheese Slice'), matching: find.byType(Row)).first;
      final addBtn = find.descendant(of: cheeseRow, matching: find.byIcon(Icons.add));
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Price should update from 120 to 145 (120 + 25)
      expect(find.text('Add to Cart • ₹145'), findsOneWidget);

      // Tap Add to Cart
      await tester.tap(find.text('Add to Cart • ₹145'));
      await tester.pumpAndSettle();

      expect(controller.cart.isNotEmpty, isTrue);
      final breakdown2 = controller.getCartItemBreakdown(controller.cart.keys.first);
      expect(breakdown2?.addonDetails.length, 1);
      expect(breakdown2?.addonDetails.first.name, 'Cheese Slice');
    });

    testWidgets('Item with both variants and addons renders both sections cleanly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const item = MenuItem(
        id: 'pizza_deluxe',
        name: 'Deluxe Pizza',
        price: 200.0,
        category: ItemCategory(
          id: 'cat_pizza',
          name: 'Pizza',
          options: [
            CategoryOption(id: 'v_regular', name: 'Regular', price: 200.0),
            CategoryOption(id: 'v_large', name: 'Large', price: 320.0),
          ],
          addons: [
            CategoryOption(id: 'add_jalapeno', name: 'Jalapeno', priceDelta: 30.0),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => UnifiedItemCustomizerSheet.show(
                  ctx,
                  item: item,
                  controller: controller,
                  getCategoryColor: (_) => Colors.blue,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Select Variant / Portion'), findsOneWidget);
      expect(find.text('Add-ons & Extras'), findsOneWidget);

      expect(find.widgetWithText(ChoiceChip, 'Regular (₹200)'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Large (₹320)'), findsOneWidget);
      expect(find.text('Jalapeno'), findsOneWidget);
    });
  });
}
