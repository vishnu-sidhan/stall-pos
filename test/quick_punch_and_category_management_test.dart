import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:counter_app/src/models/stall_models.dart';
import 'package:counter_app/src/storage/in_memory_storage.dart';
import 'package:counter_app/src/controllers/order_controller.dart';
import 'package:counter_app/src/widgets/stall_pos/cart_bottom_sheet.dart';
import 'package:counter_app/src/widgets/stall_pos/unified_item_customizer_sheet.dart';
import 'package:counter_app/src/widgets/stall_pos/manage_categories_view.dart';
import 'package:counter_app/src/widgets/stall_pos/daily_menu_availability_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleMenu = [
    const MenuItem(
      id: 'item_chai',
      name: 'Masala Chai',
      price: 20.0,
      category: ItemCategory(id: 'cat_bev', name: 'Beverages'),
    ),
    const MenuItem(
      id: 'item_burger',
      name: 'Veg Burger',
      price: 70.0,
      category: ItemCategory(id: 'cat_burger', name: 'Burger'),
    ),
    const MenuItem(
      id: 'item_momos',
      name: 'Veg Momos',
      price: 60.0,
      category: ItemCategory(
        id: 'cat_momos',
        name: 'Momos',
        options: [
          CategoryOption(id: 'opt_steam', name: 'Steam', additionalCost: 0.0, isEnabled: true),
          CategoryOption(id: 'opt_fried', name: 'Fried', additionalCost: 10.0, isEnabled: true),
        ],
      ),
    ),
  ];

  late InMemoryStallStorage storage;
  late OrderController controller;

  setUp(() async {
    storage = InMemoryStallStorage(initialMenu: sampleMenu);
    controller = OrderController(storage: storage);
    await controller.loadPersistedData();
  });

  group('CartBottomSheet Quick Punch Actions', () {
    testWidgets('renders Cash, UPI, and Punch Order buttons in CartBottomSheet', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final momo = controller.menu.firstWhere((i) => i.name.contains('Momo'));
      controller.addToCart(momo);

      String? fastCheckoutMethod;
      bool checkoutCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  CartBottomSheet.show(
                    ctx,
                    controller: controller,
                    getCategoryColor: (_) => Colors.red,
                    onCheckout: () => checkoutCalled = true,
                    onClearCart: () {},
                    onFastCheckout: (method) => fastCheckoutMethod = method,
                  );
                },
                child: const Text('Open Cart'),
              ),
            ),
          ),
        ),
      );

      // Open cart
      await tester.tap(find.text('Open Cart'));
      await tester.pumpAndSettle();

      // Verify Cash button, UPI button, and Punch Order button are rendered
      expect(find.byKey(const ValueKey('cart_fast_cash_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('cart_fast_upi_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('cart_punch_order_btn')), findsOneWidget);

      // Tap Cash button
      await tester.tap(find.byKey(const ValueKey('cart_fast_cash_btn')));
      await tester.pumpAndSettle();

      expect(fastCheckoutMethod, equals('Cash'));
      expect(checkoutCalled, isFalse);
    });

    testWidgets('UPI button triggers onFastCheckout with UPI', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final burger = controller.menu.firstWhere((i) => i.name.contains('Burger'));
      controller.addToCart(burger);

      String? fastCheckoutMethod;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  CartBottomSheet.show(
                    ctx,
                    controller: controller,
                    getCategoryColor: (_) => Colors.orange,
                    onCheckout: () {},
                    onClearCart: () {},
                    onFastCheckout: (method) => fastCheckoutMethod = method,
                  );
                },
                child: const Text('Open Cart'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Cart'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('cart_fast_upi_btn')));
      await tester.pumpAndSettle();

      expect(fastCheckoutMethod, equals('UPI'));
    });
  });

  group('UnifiedItemCustomizerSheet Full-Card Add-on Tap', () {
    testWidgets('tapping anywhere on add-on card increments add-on count', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Ensure Momos has an addon
      final momosCat = controller.getCategoryConfig('Momos');
      expect(momosCat, isNotNull);
      final updatedMomos = momosCat!.copyWith(
        addons: [
          const CategoryOption(id: 'add_mayo', name: 'Extra Mayo', priceDelta: 15.0, isEnabled: true),
        ],
      );
      await controller.saveCategoryConfig(updatedMomos);

      final momoItem = controller.menu.firstWhere((i) => i.categoryName == 'Momos');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => UnifiedItemCustomizerSheet(
                      item: momoItem,
                      controller: controller,
                      getCategoryColor: (_) => Colors.red,
                      buttonLabel: 'Add Item',
                    ),
                  );
                },
                child: const Text('Open Customizer'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Customizer'));
      await tester.pumpAndSettle();

      // Find Extra Mayo text
      expect(find.text('Extra Mayo'), findsOneWidget);

      // Tap the Extra Mayo text (full card)
      await tester.tap(find.text('Extra Mayo'));
      await tester.pumpAndSettle();

      // Quantity stepper minus icon should appear once Extra Mayo is added
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);

      // Tap again on the Extra Mayo text
      await tester.tap(find.text('Extra Mayo'));
      await tester.pumpAndSettle();

      // Addon count "2" should appear (item quantity is 1)
      expect(find.text('2'), findsOneWidget);

      // Decrement using minus button
      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pumpAndSettle();

      // Count 2 is gone, but remove button is still present (count is 1)
      expect(find.text('2'), findsNothing);
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
    });
  });

  group('Category Deletion in Controller and ManageCategoriesView', () {
    test('OrderController.deleteCategory reassigns items to General when deleteItems: false', () async {
      final momoCount = controller.menu.where((i) => i.categoryName == 'Momos').length;
      expect(momoCount, greaterThan(0));

      await controller.deleteCategory('Momos', deleteItems: false);

      // Category should be gone from configs
      expect(controller.categoryConfigs.any((c) => c.name.toLowerCase() == 'momos'), isFalse);

      // Items that were Momos should now have category General
      final generalItems = controller.menu.where((i) => i.categoryName == 'General').length;
      expect(generalItems, greaterThanOrEqualTo(momoCount));
    });

    test('OrderController.deleteCategory deletes items when deleteItems: true', () async {
      final initialTotal = controller.menu.length;
      final beverageCount = controller.menu.where((i) => i.categoryName == 'Beverages').length;
      expect(beverageCount, greaterThan(0));

      await controller.deleteCategory('Beverages', deleteItems: true);

      expect(controller.categoryConfigs.any((c) => c.name.toLowerCase() == 'beverages'), isFalse);
      expect(controller.menu.where((i) => i.categoryName == 'Beverages').isEmpty, isTrue);
      expect(controller.menu.length, equals(initialTotal - beverageCount));
    });

    testWidgets('ManageCategoriesView shows delete icon button and deletes category', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManageCategoriesView(
              controller: controller,
              getCategoryColor: (_) => Colors.blue,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find delete button for Momos
      final deleteBtn = find.byKey(const ValueKey('delete_category_Momos'));
      expect(deleteBtn, findsOneWidget);

      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog should appear with options
      expect(find.text('Delete Category "Momos"?'), findsOneWidget);
      expect(find.text('Reassign to "General"'), findsOneWidget);

      // Choose Reassign to General
      await tester.tap(find.text('Reassign to "General"'));
      await tester.pumpAndSettle();

      // Momos should no longer appear in the category list
      expect(find.byKey(const ValueKey('delete_category_Momos')), findsNothing);
    });
  });

  group('Sub-Category Availability in CategoryEditDialog and DailyMenuAvailabilityView', () {
    testWidgets('CategoryEditDialog does not have availability checkboxes', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  ManageCategoriesView.showAddEditCategoryDialog(
                    ctx,
                    categoryName: 'Momos',
                    controller: controller,
                    getCategoryColor: (_) => Colors.red,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Check that options (Steam, Fried, etc.) are present
      expect(find.text('Option / Variant Charges'), findsOneWidget);

      // Checkboxes inside dialog should NOT be present (0 checkboxes)
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.byType(Checkbox)), findsNothing);

      // Delete Category button should be present in actions
      expect(find.byKey(const ValueKey('dialog_delete_category_btn')), findsOneWidget);
    });

    testWidgets('DailyMenuAvailabilityView displays Sub-Category & Add-on availability', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyMenuAvailabilityView(
              controller: controller,
              getCategoryColor: (_) => Colors.red,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Momos section should display Sub-Category & Add-on Daily Availability
      expect(find.text('Sub-Category & Add-on Daily Availability'), findsWidgets);
      expect(find.text('Sub-Categories (Variants):'), findsWidgets);

      // Toggle a variant category-wide
      final steamChip = find.byKey(const ValueKey('cat_var_toggle_Momos_Steam'));
      expect(steamChip, findsOneWidget);

      await tester.tap(steamChip);
      await tester.pumpAndSettle();

      // Momos config should now have Steam disabled
      final momosConfig = controller.getCategoryConfig('Momos');
      final steamOpt = momosConfig?.effectiveOptions.firstWhere((o) => o.name == 'Steam');
      expect(steamOpt?.isEnabled, isFalse);
    });
  });
}
