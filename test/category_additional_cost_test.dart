import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:counter_app/src/models/stall_models.dart';
import 'package:counter_app/src/storage/in_memory_storage.dart';
import 'package:counter_app/src/controllers/order_controller.dart';
import 'package:counter_app/src/widgets/stall_pos/category_accordion_card.dart';
import 'package:counter_app/src/widgets/stall_pos/category_config_dialog.dart';
import 'package:counter_app/src/widgets/stall_pos/manage_categories_view.dart';
import 'package:counter_app/src/widgets/stall_pos/cart_bottom_sheet.dart';
import 'package:counter_app/src/widgets/stall_pos/menu_item_card.dart';

void main() {
  group('CategoryOption Model Tests', () {
    test('serializes and deserializes CategoryOption correctly', () {
      const option = CategoryOption(
        id: 'opt_fried',
        name: 'Fried',
        additionalCost: 10.0,
        isEnabled: true,
      );

      expect(option.costBadge, '+₹10');
      final json = option.toJson();
      expect(json['id'], 'opt_fried');
      expect(json['name'], 'Fried');
      expect(json['additionalCost'], 10.0);
      expect(json['isEnabled'], isTrue);

      final fromJson = CategoryOption.fromJson(json);
      expect(fromJson, equals(option));
      expect(fromJson.hashCode, equals(option.hashCode));
    });

    test('costBadge handles decimal prices and disabled states', () {
      const decimalOpt = CategoryOption(
        id: 'opt_pan',
        name: 'Pan Fried',
        additionalCost: 15.5,
        isEnabled: true,
      );
      expect(decimalOpt.costBadge, '+₹15.50');

      const zeroOpt = CategoryOption(
        id: 'opt_steam',
        name: 'Steam',
        additionalCost: 0.0,
      );
      expect(zeroOpt.costBadge, '');

      const disabledOpt = CategoryOption(
        id: 'opt_tandoori',
        name: 'Tandoori',
        additionalCost: 20.0,
        isEnabled: false,
      );
      expect(disabledOpt.costBadge, '');
    });
  });

  group('ItemCategory Model Tests', () {
    test('serializes and deserializes ItemCategory correctly', () {
      const category = ItemCategory(
        id: 'cat_beverages',
        name: 'Beverages',
        additionalCost: 5.0,
        costReason: 'Packaging Fee',
        colorHex: 0xFF1D4ED8,
        isEnabled: true,
      );

      expect(category.costDescription, '+₹5 Packaging Fee');
      expect(category.hasAdditionalCost, isTrue);
      expect(category.resolvedColorHex, 0xFF1D4ED8);
      expect(category.color, const Color(0xFF1D4ED8));
      expect(category.matches('beverages'), isTrue);
      expect(category.matches('Other'), isFalse);

      final json = category.toJson();
      expect(json['id'], 'cat_beverages');
      expect(json['name'], 'Beverages');
      expect(json['additionalCost'], 5.0);
      expect(json['costReason'], 'Packaging Fee');
      expect(json['colorHex'], 0xFF1D4ED8);

      final fromJson = ItemCategory.fromJson(json);
      expect(fromJson, equals(category));
      expect(fromJson.hashCode, equals(category.hashCode));
    });

    test('auto-derives effectiveOptions from slash in category name', () {
      const momosCategory = ItemCategory(
        id: 'cat_momos',
        name: 'Steam / Fried / Pan Fried',
      );

      expect(momosCategory.hasOptions, isTrue);
      expect(momosCategory.options, isEmpty);
      final derived = momosCategory.effectiveOptions;
      expect(derived.length, 3);
      expect(derived[0].name, 'Steam');
      expect(derived[1].name, 'Fried');
      expect(derived[2].name, 'Pan Fried');
    });

    test('costDescription summarizes multiple CategoryOptions correctly', () {
      const momosCategory = ItemCategory(
        id: 'cat_momos',
        name: 'Steam / Fried / Pan Fried',
        options: [
          CategoryOption(id: 'opt_steam', name: 'Steam', additionalCost: 0.0),
          CategoryOption(id: 'opt_fried', name: 'Fried', additionalCost: 10.0),
          CategoryOption(id: 'opt_pan', name: 'Pan Fried', additionalCost: 20.0),
        ],
      );

      expect(momosCategory.hasAdditionalCost, isTrue);
      expect(momosCategory.costDescription, 'Fried (+₹10), Pan Fried (+₹20)');
      expect(momosCategory.getOptionCost('Steam'), 0.0);
      expect(momosCategory.getOptionCost('Fried'), 10.0);
      expect(momosCategory.getOptionCost('Pan Fried'), 20.0);
      expect(momosCategory.getOptionCost('NonExistent'), 0.0);
    });

    test('costDescription returns empty when additionalCost is 0 or disabled', () {
      const zeroCost = ItemCategory(
        id: 'cat_snacks',
        name: 'Snacks',
        additionalCost: 0.0,
      );
      expect(zeroCost.costDescription, '');
      expect(zeroCost.hasAdditionalCost, isFalse);

      const disabledCost = ItemCategory(
        id: 'cat_meals',
        name: 'Meals',
        additionalCost: 15.0,
        costReason: 'Container Charge',
        isEnabled: false,
      );
      expect(disabledCost.costDescription, '');
      expect(disabledCost.hasAdditionalCost, isFalse);
    });

    test('copyWith updates fields as expected', () {
      const original = ItemCategory(
        id: 'cat_1',
        name: 'Desserts',
        additionalCost: 10.0,
        costReason: 'Cold Box',
      );

      final updated = original.copyWith(
        additionalCost: 15.0,
        clearCostReason: true,
      );

      expect(updated.additionalCost, 15.0);
      expect(updated.costReason, isNull);
      expect(updated.costDescription, '+₹15');
    });

    test('MenuItem supports serialization and copyWith', () {
      const itemWithCategory = MenuItem(
        id: 'item_1',
        name: 'Veg Momos',
        category: ItemCategory(
          id: 'cat_momos',
          name: 'Momos',
        ),
        price: 80,
      );
      expect(itemWithCategory.displayName, 'Veg Momos');
      expect(itemWithCategory.categoryDisplayName, 'Momos');
      expect(itemWithCategory.categoryName, 'Momos');

      const itemWithoutCustom = MenuItem(
        id: 'item_2',
        name: 'Veg Steamed Momos',
        price: 80,
      );
      expect(itemWithoutCustom.displayName, 'Veg Steamed Momos');
      expect(itemWithoutCustom.categoryDisplayName, 'General');

      final copied = itemWithCategory.copyWith(price: 90);
      expect(copied.displayName, 'Veg Momos');
      expect(copied.price, 90);

      final json = itemWithCategory.toJson();
      expect(json['category'], 'Momos');
      final fromJson = MenuItem.fromJson(json);
      expect(fromJson.displayName, 'Veg Momos');
      expect(fromJson.categoryDisplayName, 'Momos');
    });
  });

  group('OrderController Category Additional Cost Logic', () {
    late InMemoryStallStorage storage;
    late OrderController controller;

    final sampleMenu = [
      const MenuItem(
        id: 'item_chai',
        name: 'Masala Chai',
        price: 20.0,
        category: ItemCategory(id: 'cat_bev', name: 'Beverages'),
      ),
      const MenuItem(
        id: 'item_samosa',
        name: 'Veg Samosa',
        price: 25.0,
        category: ItemCategory(id: 'cat_snacks', name: 'Snacks'),
      ),
      const MenuItem(
        id: 'item_momos',
        name: 'Veg Momos',
        price: 60.0,
        category: ItemCategory(id: 'cat_momos', name: 'Steam / Fried / Pan Fried'),
      ),
      const MenuItem(
        id: 'addon_ginger',
        name: 'Extra Ginger',
        price: 5.0,
        category: ItemCategory(id: 'cat_addon', name: 'Addon'),
      ),
    ];

    setUp(() async {
      storage = InMemoryStallStorage(initialMenu: sampleMenu);
      controller = OrderController(storage: storage);
      await controller.loadPersistedData();
    });

    test('auto-discovers categories from menu with default 0 cost', () {
      expect(controller.categoryConfigs.isNotEmpty, isTrue);
      expect(controller.getCategoryCost('Beverages'), 0.0);
      expect(controller.getCategoryCost('Snacks'), 0.0);
      expect(controller.getCategoryCostReason('Beverages'), isNull);
    });

    test('updates category additional cost and persists it', () async {
      await controller.updateCategoryCost(
        categoryName: 'Beverages',
        additionalCost: 5.0,
        reason: 'Packaging Fee',
      );

      expect(controller.getCategoryCost('Beverages'), 5.0);
      expect(controller.getCategoryCostReason('Beverages'), 'Packaging Fee');

      final persisted = await storage.loadCategories();
      final bevPersisted = persisted.firstWhere((c) => c.name == 'Beverages');
      expect(bevPersisted.additionalCost, 5.0);
      expect(bevPersisted.costReason, 'Packaging Fee');
    });

    test('handles multi-category option pricing for Momos (Steam/Fried/Pan Fried)', () async {
      const momosConfig = ItemCategory(
        id: 'cat_momos',
        name: 'Steam / Fried / Pan Fried',
        options: [
          CategoryOption(id: 'opt_steam', name: 'Steam', additionalCost: 0.0),
          CategoryOption(id: 'opt_fried', name: 'Fried', additionalCost: 10.0),
          CategoryOption(id: 'opt_pan', name: 'Pan Fried', additionalCost: 20.0),
        ],
      );

      await controller.saveCategoryConfig(momosConfig);

      // Verify individual option charges resolved directly
      expect(controller.getCategoryCost('Steam'), 0.0);
      expect(controller.getCategoryCost('Fried'), 10.0);
      expect(controller.getCategoryCost('Pan Fried'), 20.0);

      // Verify resolving option from parent category
      expect(controller.getCategoryOptionCost('Steam / Fried / Pan Fried', 'Fried'), 10.0);
      expect(controller.getCategoryOptionCost('Steam / Fried / Pan Fried', 'Pan Fried'), 20.0);

      // Add Momos with 'Fried' variant to cart
      final momosItem = controller.findItem('item_momos');
      controller.addCustomizedItemToCart(
        baseItem: momosItem,
        resolvedCategory: 'Fried',
      );

      final friedCartItemId = controller.cart.keys.first;
      final friedItem = controller.findItem(friedCartItemId);
      expect(friedItem.categoryName, 'Fried');
      final friedBreakdown = controller.getCartItemBreakdown(friedCartItemId);
      expect(friedBreakdown?.categoryAdditionalCost, 10.0);
      expect(controller.cartTotal, 70.0); // 60 base + 10 fried

      // Add Momos with 'Pan Fried' variant to cart
      controller.addCustomizedItemToCart(
        baseItem: momosItem,
        resolvedCategory: 'Pan Fried',
      );

      final panFriedCartItemId =
          controller.cart.keys.firstWhere((k) => k.contains('Pan Fried'));
      final panFriedBreakdown = controller.getCartItemBreakdown(panFriedCartItemId);
      expect(panFriedBreakdown?.categoryAdditionalCost, 20.0);
      expect(controller.cartTotal, 150.0); // (60+10) + (60+20) = 150
    });

    test('updateCategoryOptionCost helper updates specific variant charge', () async {
      await controller.updateCategoryOptionCost(
        parentCategory: 'Steam / Fried / Pan Fried',
        optionName: 'Fried',
        additionalCost: 12.0,
      );

      expect(controller.getCategoryCost('Fried'), 12.0);
    });

    test('calculates cart item category cost correctly for regular item vs addon', () async {
      await controller.updateCategoryCost(
        categoryName: 'Beverages',
        additionalCost: 3.0,
        reason: 'Cup Charge',
      );

      final chai = controller.findItem('item_chai');
      controller.addToCart(chai);

      final chaiBreakdown = controller.getCartItemBreakdown('item_chai');
      expect(chaiBreakdown?.categoryAdditionalCost, 3.0);
      expect(chaiBreakdown?.categoryCostReason, 'Cup Charge');
      expect(controller.cartTotal, 23.0); // 20 + 3

      // Addon linked to Beverages should not get category charge
      final ginger = controller.findItem('addon_ginger');
      controller.addAddonToCart(targetCartItemId: 'item_chai', addon: ginger);

      expect(controller.cartTotal, 28.0); // 20 item + 3 cat + 5 addon
    });

    test('order snapshot preserves category additional cost in order itemsSnapshot', () async {
      await controller.updateCategoryCost(
        categoryName: 'Beverages',
        additionalCost: 4.0,
        reason: 'Eco Packaging',
      );

      final chai = controller.findItem('item_chai');
      controller.addToCart(chai);
      final orderResult = await controller.punchOrUpdateOrder(
        customerName: 'Test',
        paymentMethod: 'Cash',
        isPaid: true,
      );

      final order = controller.orders.firstWhere((o) => o.token == orderResult.token);
      expect(order.items.first.categoryAdditionalCost, 4.0);
      expect(controller.getCategoryCostReason('Beverages'), 'Eco Packaging');
    });
  });

  group('Category Additional Cost Widgets Tests', () {
    testWidgets('CategoryAccordionCard renders costDescription badge and configure button',
        (tester) async {
      bool configureTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryAccordionCard(
              catName: 'Beverages',
              items: const [
                MenuItem(
                  id: '1',
                  name: 'Coffee',
                  price: 30,
                  category: ItemCategory(id: 'cat_bev', name: 'Beverages'),
                ),
              ],
              isExpanded: true,
              costDescription: '+₹5 Packaging',
              onConfigure: () => configureTapped = true,
              onToggle: () {},
              getCategoryColor: (_) => Colors.blue,
              itemCardBuilder: (item) => Text(item.name),
            ),
          ),
        ),
      );

      expect(find.text('Beverages'), findsOneWidget);
      expect(find.text('+₹5 Packaging'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump();
      expect(configureTapped, isTrue);
    });

    testWidgets('CategoryAccordionCard renders catName as title and costDescription',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryAccordionCard(
              catName: 'Steam / Fried / Pan Fried',
              items: const [
                MenuItem(
                  id: '1',
                  name: 'Veg Momos',
                  price: 60,
                  category: ItemCategory(id: 'cat_momos', name: 'Steam / Fried / Pan Fried'),
                ),
              ],
              isExpanded: true,
              costDescription: 'Fried (+₹10), Pan Fried (+₹20)',
              onToggle: () {},
              getCategoryColor: (_) => Colors.deepOrange,
              itemCardBuilder: (item) => Text(item.name),
            ),
          ),
        ),
      );

      // Title is Steam / Fried / Pan Fried
      expect(find.text('Steam / Fried / Pan Fried'), findsOneWidget);
      expect(find.text('Fried (+₹10), Pan Fried (+₹20)'), findsOneWidget);
    });

    testWidgets('CategoryConfigDialog updates category additional cost',
        (tester) async {
      final storage = InMemoryStallStorage(initialMenu: [
        const MenuItem(
          id: '1',
          name: 'Chai',
          price: 20,
          category: ItemCategory(id: 'cat_bev', name: 'Beverages'),
        ),
      ]);
      final controller = OrderController(storage: storage);
      await controller.loadPersistedData();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => CategoryConfigDialog.show(
                    context,
                    categoryName: 'Beverages',
                    controller: controller,
                    getCategoryColor: (_) => Colors.blue,
                  ),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Category: Beverages'), findsOneWidget);
      expect(find.text('Additional Cost (₹)'), findsOneWidget);

      // Enter additional cost 5
      await tester.enterText(find.widgetWithText(TextField, 'Additional Cost (₹)'), '5');
      // Tap quick suggestion chip 'Packaging Fee'
      await tester.tap(find.text('Packaging Fee'));
      await tester.pumpAndSettle();

      // Save changes
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(controller.getCategoryCost('Beverages'), 5.0);
      expect(controller.getCategoryCostReason('Beverages'), 'Packaging Fee');
    });

    testWidgets('CategoryConfigDialog edits multi-category option charges for Momos',
        (tester) async {
      final storage = InMemoryStallStorage(initialMenu: [
        const MenuItem(
          id: '1',
          name: 'Veg Momos',
          price: 60,
          category: ItemCategory(id: 'cat_momos', name: 'Steam / Fried / Pan Fried'),
        ),
      ]);
      final controller = OrderController(storage: storage);
      await controller.loadPersistedData();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => CategoryConfigDialog.show(
                    context,
                    categoryName: 'Steam / Fried / Pan Fried',
                    controller: controller,
                    getCategoryColor: (_) => Colors.deepOrange,
                  ),
                  child: const Text('Open Config'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Config'));
      await tester.pumpAndSettle();

      // Verify options derived and displayed
      expect(find.text('Steam'), findsOneWidget);
      expect(find.text('Fried'), findsOneWidget);
      expect(find.text('Pan Fried'), findsOneWidget);

      // Enter cost 10 for Fried (index 2), and 20 for Pan Fried (index 3), noting index 0 is Category Name
      final costFields = find.byType(TextField);
      await tester.enterText(costFields.at(2), '10');
      await tester.enterText(costFields.at(3), '20');

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(controller.getCategoryCost('Fried'), 10.0);
      expect(controller.getCategoryCost('Pan Fried'), 20.0);
    });

    testWidgets('ManageCategoriesDialog lists categories and allows searching and editing',
        (tester) async {
      final storage = InMemoryStallStorage(initialMenu: [
        const MenuItem(
          id: '1',
          name: 'Chai',
          price: 20,
          category: ItemCategory(id: 'cat_bev', name: 'Beverages'),
        ),
        const MenuItem(
          id: '2',
          name: 'Samosa',
          price: 25,
          category: ItemCategory(id: 'cat_snacks', name: 'Snacks'),
        ),
      ]);
      final controller = OrderController(storage: storage);
      await controller.loadPersistedData();
      await controller.updateCategoryCost(
        categoryName: 'Beverages',
        additionalCost: 5.0,
        reason: 'Cup Fee',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => ManageCategoriesDialog.show(
                    context,
                    controller: controller,
                    getCategoryColor: (_) => Colors.blue,
                  ),
                  child: const Text('Manage Categories'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Manage Categories'));
      await tester.pumpAndSettle();

      expect(find.text('Category Surcharges & Options'), findsOneWidget);
      expect(find.text('Beverages'), findsOneWidget);
      expect(find.text('+₹5 Cup Fee'), findsOneWidget);
      expect(find.text('Snacks'), findsOneWidget);
      expect(find.text('No extra surcharge'), findsOneWidget);

      // Search filter
      await tester.enterText(find.widgetWithText(TextField, 'Filter categories...'), 'Snack');
      await tester.pumpAndSettle();
      expect(find.text('Snacks'), findsOneWidget);
      expect(find.text('Beverages'), findsNothing);

      // Tap Done
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Category Surcharges & Options'), findsNothing);
    });

    testWidgets('CartBottomSheet displays category fee in split and summary footer',
        (tester) async {
      final storage = InMemoryStallStorage(initialMenu: [
        const MenuItem(
          id: '1',
          name: 'Chai',
          price: 20,
          category: ItemCategory(id: 'cat_bev', name: 'Beverages'),
        ),
      ]);
      final controller = OrderController(storage: storage);
      await controller.loadPersistedData();
      await controller.updateCategoryCost(
        categoryName: 'Beverages',
        additionalCost: 5.0,
        reason: 'Cup Fee',
      );

      controller.addToCart(controller.findItem('1'));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => CartBottomSheet.show(
                    context,
                    controller: controller,
                    getCategoryColor: (_) => Colors.blue,
                    onCheckout: () {},
                    onClearCart: () {},
                  ),
                  child: const Text('Open Cart'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Cart'));
      await tester.pumpAndSettle();

      // Verify item split display
      expect(find.text('Split: Item ₹20 + Cup Fee ₹5'), findsOneWidget);

      // Verify cart summary footer breakdown
      expect(find.text('Items Subtotal'), findsOneWidget);
      expect(find.text('₹20'), findsWidgets);
      expect(find.text('Category Additional Costs'), findsOneWidget);
      expect(find.text('+₹5'), findsOneWidget);
      expect(find.text('Total Payable'), findsOneWidget);
      expect(find.text('₹25'), findsWidgets);
    });

    test('ItemCategory and MenuItem display names work cleanly', () {
      const categoryMomos = ItemCategory(
        id: 'cat_momos',
        name: 'Momos',
      );

      const momos = MenuItem(
        id: '1',
        name: 'Veg Steamed Momos',
        price: 80,
        category: categoryMomos,
      );
      expect(momos.displayName, 'Veg Steamed Momos');
      expect(momos.categoryName, 'Momos');
      expect(momos.categoryDisplayName, 'Momos');

      const categoryNoDisplay = ItemCategory(
        id: 'cat_bev',
        name: 'Beverages',
      );

      const noCustom = MenuItem(
        id: '2',
        name: 'Chai',
        price: 20,
        category: categoryNoDisplay,
      );
      expect(noCustom.displayName, 'Chai');

      final copied = momos.copyWith(price: 90);
      expect(copied.displayName, 'Veg Steamed Momos');
      expect(copied.price, 90);

      final json = momos.toJson();
      expect(json['category'], 'Momos');
      final fromJson = MenuItem.fromJson(json);
      expect(fromJson.displayName, 'Veg Steamed Momos');
      expect(fromJson.categoryName, 'Momos');
      expect(fromJson.categoryDisplayName, 'Momos');
    });

    test('Aggregated prep item record displayName returns itemName', () {
      const aggItem = (
        itemId: '1',
        itemName: 'Veg Steamed Momos',
        displayName: 'Veg Steamed Momos',
        category: 'Momos',
        totalQuantity: 2,
        tickets: [(token: 101, quantity: 2, isParcel: false, orderNotes: null)],
        colorHex: null,
        effectiveDietaryType: ItemDietaryType.veg,
      );
      expect(aggItem.displayName, 'Veg Steamed Momos');

      const aggNoAlias = (
        itemId: '2',
        itemName: 'Veg Steamed Momos',
        displayName: 'Veg Steamed Momos',
        category: 'Momos',
        totalQuantity: 2,
        tickets: [(token: 101, quantity: 2, isParcel: false, orderNotes: null)],
        colorHex: null,
        effectiveDietaryType: ItemDietaryType.veg,
      );
      expect(aggNoAlias.displayName, 'Veg Steamed Momos');
    });

    test('OrderController respects ItemCategory in menu, filteredMenu, and findItem', () async {
      final storage = InMemoryStallStorage(initialMenu: [
        const MenuItem(
          id: 'item_momos',
          name: 'Veg Steamed Momos',
          price: 80,
          category: ItemCategory(
            id: 'cat_momos',
            name: 'Momos',
          ),
        ),
      ]);
      final controller = OrderController(storage: storage);
      await controller.loadPersistedData();

      expect(controller.menu.first.displayName, 'Veg Steamed Momos');
      expect(controller.filteredMenu.first.displayName, 'Veg Steamed Momos');
      expect(controller.findItem('item_momos').displayName, 'Veg Steamed Momos');

      // Add to cart and verify cart findItem
      controller.addToCart(controller.findItem('item_momos'));
      final orderItem = controller.findItem('item_momos');
      expect(orderItem.displayName, 'Veg Steamed Momos');
    });

    testWidgets('MenuItemCard and CartBottomSheet render clean item name',
        (tester) async {
      final storage = InMemoryStallStorage(initialMenu: [
        const MenuItem(
          id: 'item_momos',
          name: 'Veg Steamed Momos',
          price: 80,
          category: ItemCategory(
            id: 'cat_momos',
            name: 'Momos',
          ),
        ),
      ]);
      final controller = OrderController(storage: storage);
      await controller.loadPersistedData();

      // 1. Render MenuItemCard
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MenuItemCard(
                item: controller.menu.first,
                cart: const {},
                getCategoryColor: (_) => Colors.deepOrange,
                onTap: () {},
                onLongPress: () {},
              ),
            ),
          ),
        ),
      );

      // Verify card displays 'Veg Steamed Momos' and '(Momos)'
      expect(find.text('Veg Steamed Momos'), findsOneWidget);
      expect(find.text('(Momos)'), findsOneWidget);

      // 2. Add to cart and verify in CartBottomSheet
      controller.addToCart(controller.findItem('item_momos'));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => CartBottomSheet.show(
                    context,
                    controller: controller,
                    getCategoryColor: (_) => Colors.deepOrange,
                    onCheckout: () {},
                    onClearCart: () {},
                  ),
                  child: const Text('Open Cart'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Cart'));
      await tester.pumpAndSettle();

      // Verify item title in cart displays 'Veg Steamed Momos (Momos)'
      expect(find.text('Veg Steamed Momos (Momos)'), findsOneWidget);
    });

    test('OrderController normalizeCategoryKey handles uneven whitespace around slashes', () {
      expect(
        OrderController.normalizeCategoryKey('Momos /  Fried Momos /   Pan Fried Momos'),
        'momos / fried momos / pan fried momos',
      );
      expect(
        OrderController.normalizeCategoryKey('  Beverages  '),
        'beverages',
      );
    });

    testWidgets('CategoryAccordionCard renders multi-option cost badge inside column without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryAccordionCard(
              catName: 'Fried Momos / Pan Fried Momos / Kurkure Momos / Peri-Peri Momos',
              items: const [
                MenuItem(
                  id: '1',
                  name: 'Veg Momos',
                  price: 150,
                  category: ItemCategory(id: 'cat_momos', name: 'Momos'),
                ),
              ],
              isExpanded: true,
              costDescription: 'Fried Momos (+₹10), Pan Fried Momos (+₹20), Kurkure Momos (+₹30), Peri-Peri Momos (+₹40)',
              getCategoryColor: (_) => Colors.deepOrange,
              onToggle: () {},
              itemCardBuilder: (item) => Text(item.name),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no flutter overflow exceptions were thrown
      expect(tester.takeException(), isNull);

      // Verify title is rendered
      expect(find.text('Fried Momos / Pan Fried Momos / Kurkure Momos / Peri-Peri Momos'), findsOneWidget);

      // Verify the long multi-option badge is present
      expect(find.text('Fried Momos (+₹10), Pan Fried Momos (+₹20), Kurkure Momos (+₹30), Peri-Peri Momos (+₹40)'), findsOneWidget);
    });

    test('Selected category custom item works cleanly', () async {
      final storage = InMemoryStallStorage(initialMenu: [
        const MenuItem(
          id: 'item_chicken',
          name: 'Chicken Momos',
          price: 180,
          category: ItemCategory(
            id: 'cat_momos',
            name: 'Momos',
          ),
        ),
        const MenuItem(
          id: 'item_gobi',
          name: 'Gobi Manchuria',
          price: 170,
          category: ItemCategory(
            id: 'cat_starters',
            name: 'Starters',
          ),
        ),
      ]);
      final controller = OrderController(storage: storage);
      await controller.loadPersistedData();

      // 1. Regular item
      final gobiItem = controller.findItem('item_gobi');
      expect(gobiItem.displayName, 'Gobi Manchuria');

      // 2. Add customized item with selected category variant (Kurkure Momos)
      final chickenBase = controller.findItem('item_chicken');
      controller.addCustomizedItemToCart(
        baseItem: chickenBase,
        resolvedCategory: 'Kurkure Momos',
      );

      // Cart item key: item_chicken_cat_Kurkure Momos
      final cartItemKey = controller.cart.keys.first;
      final resolvedCartItem = controller.findItem(cartItemKey);
      expect(resolvedCartItem.displayName, 'Chicken Momos');
      expect(resolvedCartItem.categoryName, 'Kurkure Momos');

      // 3. Punch order and verify Active Orders item list
      final orderResult = await controller.punchOrUpdateOrder(customerName: null);
      final order = controller.orders.firstWhere((o) => o.token == orderResult.token);
      final activeItems = controller.getOrderItemsWithCategory(order);
      expect(activeItems.length, 1);
      expect(activeItems.first.displayName, 'Chicken Momos (Kurkure Momos)');

      // 4. Confirm payment so order is in Item Summary
      await controller.confirmPayment(token: order.token, paymentMethod: 'Cash');
      final aggregated = controller.combinedActiveOrders;
      expect(aggregated.length, 1);
      expect(aggregated.first.displayName, 'Chicken Momos (Kurkure Momos)');
    });

    testWidgets(
        'POS MenuItemCard displays category in brackets and Active Orders displays selected variant',
        (tester) async {
      final chai = const MenuItem(
        id: 'item_chai',
        name: 'Masala Chai',
        price: 20,
        category: ItemCategory(id: 'cat_bev', name: 'Beverages'),
      );
      final momos = const MenuItem(
        id: 'item_momos',
        name: 'Veg Momos',
        price: 80,
        category: ItemCategory(
          id: 'cat_momos',
          name: 'Momos',
          options: [
            CategoryOption(id: 'opt_steam', name: 'Steam'),
            CategoryOption(id: 'opt_fried', name: 'Fried'),
          ],
        ),
      );

      // Verify displayNameWithCategory getter
      expect(chai.displayNameWithCategory, 'Masala Chai (Beverages)');
      expect(momos.displayNameWithCategory, 'Veg Momos (Momos)');

      // Verify MenuItemCard renders (Beverages) in brackets
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MenuItemCard(
              item: chai,
              cart: const {},
              getCategoryColor: (_) => Colors.blue,
              onTap: () {},
              onLongPress: () {},
            ),
          ),
        ),
      );

      expect(find.text('Masala Chai'), findsOneWidget);
      expect(find.text('(Beverages)'), findsOneWidget);

      // Setup OrderController with both items
      final storage = InMemoryStallStorage(initialMenu: [chai, momos]);
      final controller = OrderController(storage: storage);
      await controller.loadPersistedData();

      // Add regular chai and customized momos (Steam)
      controller.addToCart(chai);
      controller.addCustomizedItemToCart(
        baseItem: momos,
        resolvedCategory: 'Steam',
      );

      final orderResult = await controller.punchOrUpdateOrder(customerName: null);
      final order = controller.orders.firstWhere((o) => o.token == orderResult.token);
      final lineItems = controller.getOrderItemsWithCategory(order);

      expect(lineItems.length, 2);
      final chaiLine = lineItems.firstWhere((i) => i.itemId == 'item_chai');
      final momosLine = lineItems.firstWhere((i) => i.itemId.contains('item_momos'));

      // Regular item has category in brackets, variant item shows variant in brackets
      expect(chaiLine.displayName, 'Masala Chai (Beverages)');
      expect(momosLine.displayName, 'Veg Momos (Steam)');

      // Confirm payment and check Item Summary aggregation
      await controller.confirmPayment(token: order.token, paymentMethod: 'Cash');
      final summaryList = controller.combinedActiveOrders;
      expect(summaryList.length, 2);

      final chaiSummary = summaryList.firstWhere((s) => s.itemId == 'item_chai');
      final momosSummary = summaryList.firstWhere((s) => s.itemId.contains('item_momos'));

      expect(chaiSummary.displayName, 'Masala Chai (Beverages)');
      expect(momosSummary.displayName, 'Veg Momos (Steam)');
    });

    test('Shows item name and selected variant in brackets if any, or category name if not', () async {
      final manchuria = MenuItem(
        id: 'item_manchuria',
        name: 'Chicken Manchuria',
        price: 180.0,
        category: ItemCategory.named('Starters'),
      );
      final kurkure = MenuItem(
        id: 'item_kurkure',
        name: 'Kurkure Momos',
        price: 150.0,
        category: ItemCategory.named(
          'Momos',
          options: const [
            CategoryOption(id: 'v_veg', name: 'Veg'),
            CategoryOption(id: 'v_paneer', name: 'Paneer'),
            CategoryOption(id: 'v_chicken', name: 'Chicken'),
          ],
        ),
      );
      final eggChicken = MenuItem(
        id: 'item_egg_chicken',
        name: 'Egg Chicken',
        price: 220.0,
        category: ItemCategory.named('Rice / Noodles'),
      );
      final schezwan = MenuItem(
        id: 'addon_schezwan',
        name: 'Schezwan',
        price: 30.0,
        category: ItemCategory.named('Addons'),
      );

      final storage = InMemoryStallStorage(initialMenu: [manchuria, kurkure, eggChicken, schezwan]);
      final controller = OrderController(storage: storage);
      await controller.loadPersistedData();

      // 1. Add regular Manchuria (no variant)
      controller.addToCart(manchuria);

      // 2. Add Kurkure Momos with variant Chicken
      controller.addCustomizedItemToCart(
        baseItem: kurkure,
        resolvedName: 'Chicken',
      );

      // 3. Add Egg Chicken with category variant Rice and addon Schezwan
      controller.addCustomizedItemToCart(
        baseItem: eggChicken,
        resolvedCategory: 'Rice',
      );
      final riceCartKey = controller.cartBaseItems.last.id;
      controller.addAddonToCart(
        targetCartItemId: riceCartKey,
        addon: schezwan,
      );

      final orderResult = await controller.punchOrUpdateOrder(
        customerName: 'Walk-in Customer',
        isPaid: true,
        paymentMethod: 'UPI',
      );
      final order = controller.orders.firstWhere((o) => o.token == orderResult.token);
      final lineItems = controller.getOrderItemsWithCategory(order);

      final manchuriaLine = lineItems.firstWhere((i) => i.itemId == 'item_manchuria');
      final kurkureLine = lineItems.firstWhere((i) => i.itemId.startsWith('item_kurkure'));
      final eggChickenLine = lineItems.firstWhere((i) => i.itemId.startsWith('item_egg_chicken'));

      // Regular item shows category in brackets
      expect(manchuriaLine.displayName, 'Chicken Manchuria (Starters)');
      // Variant item shows item name and selected category/style in brackets: Chicken (Kurkure Momos)
      expect(kurkureLine.displayName, 'Chicken (Kurkure Momos)');
      // Category variant item shows selected category variant in brackets
      expect(eggChickenLine.displayName, '[Schezwan] Egg Chicken (Rice)');

      // Combined active orders / Item summary aggregation
      final summaryList = controller.combinedActiveOrders;
      final manchuriaSummary = summaryList.firstWhere((s) => s.itemId == 'item_manchuria');
      final kurkureSummary = summaryList.firstWhere((s) => s.itemId.startsWith('item_kurkure'));
      final eggChickenSummary = summaryList.firstWhere((s) => s.itemId.startsWith('item_egg_chicken'));

      expect(manchuriaSummary.displayName, 'Chicken Manchuria (Starters)');
      expect(kurkureSummary.displayName, 'Chicken (Kurkure Momos)');
      expect(eggChickenSummary.displayName, '[Schezwan] Egg Chicken (Rice)');

      // Legacy order where Kurkure Momos was saved with "(Momos)" heals to "Chicken (Kurkure Momos)" from itemId
      final legacyOrder = StallOrder.fromJson({
        'token': 99,
        'timestamp': DateTime.now().toIso8601String(),
        'itemsSummary': '1x Kurkure Momos (Momos)',
        'total': 180,
        'isPaid': true,
        'items': {'item_kurkure_var_Chicken': 1},
        'itemSnapshots': {
          'item_kurkure_var_Chicken': {
            'name': 'Kurkure Momos',
            'displayName': 'Kurkure Momos (Momos)',
            'category': 'Momos',
          },
        },
      });
      final legacyLines = controller.getOrderLineItems(legacyOrder);
      expect(legacyLines.first.displayName, 'Chicken (Kurkure Momos)');
    });

    test('Real stall menu: Chicken item in Momos category with Kurkure Momos option displays Chicken (Kurkure Momos)', () async {
      final chickenMomoItem = MenuItem(
        id: 'item_1789369983777_9bc6b93d',
        name: 'Chicken',
        price: 180.0,
        category: const ItemCategory(
          id: 'cat_momos',
          name: 'Momos',
          options: [
            CategoryOption(id: 'opt_steam', name: 'Steam Momos'),
            CategoryOption(id: 'opt_fried', name: 'Fried Momos', additionalCost: 10),
            CategoryOption(id: 'opt_kurkure', name: 'Kurkure Momos', additionalCost: 30),
          ],
        ),
      );

      final storage = InMemoryStallStorage(initialMenu: [chickenMomoItem]);
      final controller = OrderController(storage: storage);
      await controller.loadPersistedData();

      // 1. Add Chicken with Kurkure Momos variant
      controller.addCustomizedItemToCart(
        baseItem: chickenMomoItem,
        resolvedName: 'Kurkure Momos',
      );

      final orderResult = await controller.punchOrUpdateOrder(
        customerName: 'Walk-in Customer',
        isPaid: true,
        paymentMethod: 'UPI',
      );
      final order = controller.orders.firstWhere((o) => o.token == orderResult.token);

      // Verify Active Orders line items
      final lineItems = controller.getOrderLineItems(order);
      expect(lineItems.length, 1);
      expect(lineItems.first.displayName, 'Chicken (Kurkure Momos)');

      // Verify Item Summary aggregation
      final summaryList = controller.combinedActiveOrders;
      expect(summaryList.length, 1);
      expect(summaryList.first.displayName, 'Chicken (Kurkure Momos)');

      // 2. Test active order self-healing from storage:
      // An order originally stored with old summary "1x Kurkure Momos (Momos)"
      final oldOrder = StallOrder.fromJson({
        'token': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'itemsSummary': '1x Kurkure Momos (Momos)',
        'total': 180,
        'isPaid': true,
        'items': {'item_1789369983777_9bc6b93d_var_Kurkure Momos': 1},
        'itemSnapshots': {
          'item_1789369983777_9bc6b93d_var_Kurkure Momos': {
            'name': 'Chicken',
            'displayName': 'Kurkure Momos (Momos)',
            'category': 'Momos',
          },
        },
      });
      final storageWithOldOrder = InMemoryStallStorage(
        initialMenu: [chickenMomoItem],
        initialOrders: [oldOrder],
      );
      final healingController = OrderController(storage: storageWithOldOrder);
      await healingController.loadPersistedData();

      // Check healed summary and snapshots
      final healedOrder = healingController.orders.first;
      expect(healedOrder.itemsSummary, '1x Chicken (Kurkure Momos)');
      expect(healedOrder.itemSnapshots['item_1789369983777_9bc6b93d_var_Kurkure Momos']?['displayName'], 'Chicken (Kurkure Momos)');

      // Check Active Orders and Item Summary on healed order
      final healedLineItems = healingController.getOrderLineItems(healedOrder);
      expect(healedLineItems.first.displayName, 'Chicken (Kurkure Momos)');
      final healedSummary = healingController.combinedActiveOrders;
      expect(healedSummary.first.displayName, 'Chicken (Kurkure Momos)');
    });

    test('formatOrderLineItemDisplayName is completely dynamic across food and non-food categories', () {
      // 1. Momos with variant (Kurkure Momos, Steam Momos, Fried Momos)
      expect(
        OrderController.formatOrderLineItemDisplayName(
          rawName: 'Chicken',
          itemId: 'item_momo_var_Kurkure Momos_cat_Momos',
          category: 'Momos',
          baseItemName: 'Chicken',
        ),
        'Chicken (Kurkure Momos)',
      );
      expect(
        OrderController.formatOrderLineItemDisplayName(
          rawName: 'Veg',
          itemId: 'item_momo_var_Steam Momos_cat_Momos',
          category: 'Momos',
          baseItemName: 'Veg',
        ),
        'Veg (Steam Momos)',
      );
      expect(
        OrderController.formatOrderLineItemDisplayName(
          rawName: 'Paneer',
          itemId: 'item_momo_var_Fried Momos_cat_Momos',
          category: 'Momos',
          baseItemName: 'Paneer',
        ),
        'Paneer (Fried Momos)',
      );

      // 2. Items without variants show category name in brackets
      expect(
        OrderController.formatOrderLineItemDisplayName(
          rawName: 'Chicken Manchuria',
          itemId: 'item_starters_1',
          category: 'Starters',
          baseItemName: 'Chicken Manchuria',
        ),
        'Chicken Manchuria (Starters)',
      );
      expect(
        OrderController.formatOrderLineItemDisplayName(
          rawName: 'Paneer 65',
          itemId: 'item_starters_2',
          category: 'Starters',
          baseItemName: 'Paneer 65',
        ),
        'Paneer 65 (Starters)',
      );
      expect(
        OrderController.formatOrderLineItemDisplayName(
          rawName: 'Chicken 65',
          itemId: 'item_rolls_1',
          category: 'Rolls',
          baseItemName: 'Chicken 65',
        ),
        'Chicken 65 (Rolls)',
      );

      // 3. Category variants (e.g. Rice / Noodles)
      expect(
        OrderController.formatOrderLineItemDisplayName(
          rawName: 'Egg Chicken',
          itemId: 'item_rice_cat_Rice',
          category: 'Rice / Noodles',
          baseItemName: 'Egg Chicken',
        ),
        'Egg Chicken (Rice)',
      );
      expect(
        OrderController.formatOrderLineItemDisplayName(
          rawName: 'Gobi',
          itemId: 'item_rice_cat_Noodles',
          category: 'Rice / Noodles',
          baseItemName: 'Gobi',
        ),
        'Gobi (Noodles)',
      );

      // 4. Add-on prefixes combined with variants
      expect(
        OrderController.formatOrderLineItemDisplayName(
          rawName: '[Schezwan] Egg Chicken',
          itemId: 'item_rice_cat_Rice+addon_1',
          category: 'Rice / Noodles',
          baseItemName: 'Egg Chicken',
        ),
        '[Schezwan] Egg Chicken (Rice)',
      );
      expect(
        OrderController.formatOrderLineItemDisplayName(
          rawName: '[Schezwan] [2x Egg] Gobi',
          itemId: 'item_rice_cat_Noodles+addon_1+addon_2',
          category: 'Rice / Noodles',
          baseItemName: 'Gobi',
        ),
        '[Schezwan] [2x Egg] Gobi (Noodles)',
      );
      // Ensures no duplicate addon prefix if baseItemName already contains prefix
      expect(
        OrderController.formatOrderLineItemDisplayName(
          rawName: '[Schezwan] Egg Chicken',
          itemId: 'item_rice_cat_Rice+addon_1',
          category: 'Rice / Noodles',
          baseItemName: '[Schezwan] Egg Chicken',
        ),
        '[Schezwan] Egg Chicken (Rice)',
      );

      // 5. Slash name items with variant
      expect(
        OrderController.formatOrderLineItemDisplayName(
          rawName: 'Chilli / Manchuria',
          itemId: 'item_slash_var_Chilli',
          category: 'Starters',
          baseItemName: 'Chilli / Manchuria',
        ),
        'Chilli (Starters)',
      );

      // 6. Non-food / completely arbitrary categories & variants (zero food-specific heuristics)
      expect(
        OrderController.formatOrderLineItemDisplayName(
          rawName: 'T-Shirt',
          itemId: 'item_apparel_var_XL_cat_Apparel',
          category: 'Apparel',
          baseItemName: 'T-Shirt',
        ),
        'T-Shirt (XL)',
      );
      expect(
        OrderController.formatOrderLineItemDisplayName(
          rawName: 'Oil Change',
          itemId: 'item_service_1',
          category: 'Services',
          baseItemName: 'Oil Change',
        ),
        'Oil Change (Services)',
      );
      expect(
        OrderController.formatOrderLineItemDisplayName(
          rawName: 'Wood Screw',
          itemId: 'item_hw_var_3-inch_cat_Hardware',
          category: 'Hardware',
          baseItemName: 'Wood Screw',
        ),
        'Wood Screw (3-inch)',
      );

      // 7. Base item embeds category name and variant is the flavor/attribute
      expect(
        OrderController.formatOrderLineItemDisplayName(
          rawName: 'Kurkure Momos',
          itemId: 'item_momo_var_Chicken_cat_Momos',
          category: 'Momos',
          baseItemName: 'Kurkure Momos',
        ),
        'Chicken (Kurkure Momos)',
      );
    });
  });
}

