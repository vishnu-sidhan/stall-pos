import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/src/storage/app_storage.dart';
import 'package:counter_app/src/views/stall_pos_screen.dart';
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

    test('MenuItem with explicit variants serializes variants to JSON', () {
      const item = MenuItem(
        id: 'item_pizza',
        name: 'Margherita Pizza',
        price: 150.0,
        category: ItemCategory.general,
        variants: [
          CategoryOption(id: 'v1', name: 'Regular', price: 150.0),
          CategoryOption(id: 'v2', name: 'Medium', price: 250.0),
          CategoryOption(id: 'v3', name: 'Large', price: 350.0),
        ],
      );

      final json = item.toJson();
      expect(json['variants'], isNotNull);
      final variantsList = json['variants'] as List;
      expect(variantsList.length, 3);
      expect(variantsList[1]['name'], 'Medium');
      expect(variantsList[1]['price'], 250.0);

      final reconstructed = MenuItem.fromJson(json);
      expect(reconstructed.variants.length, 3);
      expect(reconstructed.variants[2].name, 'Large');
      expect(reconstructed.variants[2].price, 350.0);
      expect(reconstructed.priceForVariant(reconstructed.variants[2]), 350.0);
    });

    test('effectiveVariants auto-derives from slash name when explicit variants empty', () {
      const item = MenuItem(
        id: 'item_combo',
        name: 'Tea / Coffee',
        price: 20.0,
      );

      expect(item.variants, isEmpty);
      expect(item.hasSlashNameVariants, isTrue);
      expect(item.effectiveVariants.length, 2);
      expect(item.effectiveVariants[0].name, 'Tea');
      expect(item.effectiveVariants[1].name, 'Coffee');
      expect(item.priceForVariant(item.effectiveVariants[0]), 20.0);
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

  group('ItemCustomizerSheet Widget Tests', () {
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
          },
          {
            'id': 'addon_cheese',
            'name': 'Extra Cheese',
            'price': 30.0,
            'category': 'Addons',
            'is_addon': true,
            'linked_category': 'Fast Food',
          },
        ]),
        'stall_orders': jsonEncode([]),
      });
      storage = AppStorage.instance.stallStorage;
      controller = OrderController(storage: storage);
      await controller.loadPersistedData();
    });

    testWidgets('ItemCustomizerSheet selects variant and adds to cart with live price', (WidgetTester tester) async {
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
                onPressed: () => ItemCustomizerSheet.show(
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
      expect(find.text('Single Patty'), findsOneWidget);
      expect(find.text('Double Patty'), findsOneWidget);
      expect(find.textContaining('Extra Cheese'), findsOneWidget);

      // Select Double Patty (+₹60)
      await tester.tap(find.text('Double Patty'));
      await tester.pumpAndSettle();

      // Add 1x Extra Cheese (+₹30) -> Total = 160 + 30 = 190
      final cheeseAddBtn = find.descendant(
        of: find.byType(AddonQuantityRow),
        matching: find.byIcon(Icons.add),
      );
      await tester.tap(cheeseAddBtn);
      await tester.pumpAndSettle();

      expect(find.text('Add to Order • ₹190'), findsOneWidget);

      // Tap Add to Order
      await tester.tap(find.text('Add to Order • ₹190'));
      await tester.pumpAndSettle();

      // Customizer closed and cart populated
      expect(find.text('Burger'), findsNothing);
      expect(controller.cart.isNotEmpty, isTrue);
      expect(controller.cartTotal, 190.0);
    });

    testWidgets('ItemCustomizerSheet disables sold-out variant and prevents adding if all variants sold out', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Item with one disabled variant and one enabled variant
      final item = MenuItem(
        id: 'drink_1',
        name: 'Milkshake',
        price: 80.0,
        category: const ItemCategory(id: 'cat_drinks', name: 'Drinks'),
        variants: const [
          CategoryOption(id: 'v_reg', name: 'Regular', price: 80.0, isEnabled: true),
          CategoryOption(id: 'v_lrg', name: 'Large', price: 120.0, isEnabled: false),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => ItemCustomizerSheet.show(
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

      // Regular should be selected, Large should show Sold Out
      expect(find.text('Regular'), findsOneWidget);
      expect(find.text('Sold Out'), findsOneWidget);

      // Tapping Large should NOT select it
      await tester.tap(find.text('Sold Out'));
      await tester.pumpAndSettle();

      // Price should still be Regular (₹80)
      expect(find.text('Add to Order • ₹80'), findsOneWidget);
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

  group('UnifiedItemCustomizerSheet Deduplication Tests', () {
    late StallStorage storage;
    late OrderController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = AppStorage.instance.stallStorage;
      controller = OrderController(storage: storage);
      await controller.loadPersistedData();
    });

    testWidgets('Double Egg in Rice/Noodles renders CATEGORY OPTION only, not PREPARATION / VARIANT', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const item = MenuItem(
        id: 'egg_rn',
        name: 'Double Egg',
        price: 190.0,
        category: ItemCategory(id: 'cat_rn', name: 'Rice/Noodles'),
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

      // CATEGORY OPTION must be present
      expect(find.text('CATEGORY OPTION'), findsOneWidget);
      // SELECT PREPARATION / VARIANT must NOT be present
      expect(find.text('SELECT PREPARATION / VARIANT'), findsNothing);
      expect(find.text('SELECT CHOICE'), findsNothing);

      // Rice and Noodles chips should appear exactly once
      expect(find.widgetWithText(ChoiceChip, 'Rice'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Noodles'), findsOneWidget);
    });

    testWidgets('Chilli / Chicken 65 in Starters renders SELECT CHOICE only, not PREPARATION / VARIANT', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const item = MenuItem(
        id: 'starter_combo',
        name: 'Chilli / Chicken 65',
        price: 220.0,
        category: ItemCategory(id: 'cat_starters', name: 'Starters'),
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

      // SELECT CHOICE must be present
      expect(find.text('SELECT CHOICE'), findsOneWidget);
      // SELECT PREPARATION / VARIANT must NOT be present
      expect(find.text('SELECT PREPARATION / VARIANT'), findsNothing);
      expect(find.text('CATEGORY OPTION'), findsNothing);

      // Chilli and Chicken 65 chips should appear exactly once
      expect(find.widgetWithText(ChoiceChip, 'Chilli'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Chicken 65'), findsOneWidget);

      // Selecting Chicken 65 does NOT prematurely close the sheet
      await tester.tap(find.widgetWithText(ChoiceChip, 'Chicken 65'));
      await tester.pumpAndSettle();
      expect(find.text('SELECT CHOICE'), findsOneWidget);
      expect(find.text('Add to Cart • ₹220'), findsOneWidget);

      // Tapping Add to Cart adds item and closes sheet
      await tester.tap(find.text('Add to Cart • ₹220'));
      await tester.pumpAndSettle();
      expect(find.text('SELECT CHOICE'), findsNothing);
      expect(controller.cart.isNotEmpty, isTrue);
    });

    testWidgets('Item with explicit variants renders SELECT PREPARATION / VARIANT without duplication', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const item = MenuItem(
        id: 'burger_item',
        name: 'Burger',
        price: 100.0,
        category: ItemCategory(id: 'cat_burgers', name: 'Burgers'),
        variants: [
          CategoryOption(id: 'v_single', name: 'Single Patty', price: 100.0),
          CategoryOption(id: 'v_double', name: 'Double Patty', price: 160.0),
        ],
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

      expect(find.text('SELECT PREPARATION / VARIANT'), findsOneWidget);
      expect(find.text('SELECT CHOICE'), findsNothing);
      expect(find.text('CATEGORY OPTION'), findsNothing);

      expect(find.text('Single Patty (₹100)'), findsOneWidget);
      expect(find.text('Double Patty (₹160)'), findsOneWidget);
    });
  });
}
