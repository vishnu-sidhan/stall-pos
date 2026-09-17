import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/src/controllers/counter_controller.dart';
import 'package:counter_app/src/storage/app_storage.dart';
import 'package:counter_app/main.dart';
import 'package:counter_app/src/views/stall_pos_view.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('StallPosScreen starts empty and handles adding items to cart via Store Admin', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final counterCtrl = CounterController(storageService: AppStorage.instance.counterStorage);
    await counterCtrl.init();

    await tester.pumpWidget(StallPosApp(controller: counterCtrl, initialIndex: 1));
    await tester.pumpAndSettle();

    // Verify title and empty menu state
    expect(find.text('⚡ StallPOS'), findsOneWidget);
    expect(find.text('No menu items yet'), findsOneWidget);
    expect(find.text('Configure menu items and categories in Store Admin'), findsOneWidget);

    // Initial button state when cart is empty
    expect(find.text('TAP ITEMS TO START (#1)'), findsOneWidget);

    // Add a menu item with category via Store Admin bottom navigation tab
    await tester.tap(find.byTooltip('Store Admin'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Menu & Variants'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('admin_add_menu_item_btn')));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Item Name *'), 'Veg Roll');
    await tester.enterText(find.widgetWithText(TextField, 'Price (₹) *'), '80');
    await tester.enterText(find.widgetWithText(TextField, 'Or enter custom category'), 'Snacks');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add Item').last);
    await tester.pumpAndSettle();

    // Return to Stall POS tab
    await tester.tap(find.byTooltip('Stall POS'));
    await tester.pumpAndSettle();

    expect(find.text('Veg Roll'), findsOneWidget);
    expect(find.text('₹80'), findsOneWidget);
    expect(find.text('Snacks'), findsWidgets);

    // Tap on 'Veg Roll' to add to cart
    await tester.tap(find.text('Veg Roll'));
    await tester.pumpAndSettle();

    // Verify cart count badge (1) and button updated
    expect(find.text('1'), findsWidgets);
    expect(find.text('PUNCH ORDER (#1) • ₹80'), findsOneWidget);

    // Tap 'Veg Roll' again
    await tester.tap(find.text('Veg Roll'));
    await tester.pumpAndSettle();

    // Verify cart total updated to 160 and cart chip shows item
    expect(find.text('PUNCH ORDER (#1) • ₹160'), findsOneWidget);
    expect(find.text('2x Veg Roll'), findsOneWidget);

    // Tap 'Clear' button
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('TAP ITEMS TO START (#1)'), findsOneWidget);
  });

  testWidgets('StallPosScreen filters by category chips', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'stall_menu': jsonEncode([
        {'id': '101', 'name': 'Masala Chai', 'price': 20, 'category': 'Beverages'},
        {'id': '102', 'name': 'Veg Samosa', 'price': 25, 'category': 'Snacks'},
      ]),
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: StallPosScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Both items visible initially under 'All'
    expect(find.text('Masala Chai'), findsOneWidget);
    expect(find.text('Veg Samosa'), findsOneWidget);

    // Category chips visible
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Beverages'), findsWidgets);
    expect(find.text('Snacks'), findsWidgets);

    // Tap 'Beverages' chip
    await tester.tap(find.widgetWithText(ChoiceChip, 'Beverages'));
    await tester.pumpAndSettle();

    // Only Masala Chai should be visible
    expect(find.text('Masala Chai'), findsOneWidget);
    expect(find.text('Veg Samosa'), findsNothing);

    // Tap 'Snacks' chip
    await tester.tap(find.widgetWithText(ChoiceChip, 'Snacks'));
    await tester.pumpAndSettle();

    // Only Veg Samosa should be visible
    expect(find.text('Veg Samosa'), findsOneWidget);
    expect(find.text('Masala Chai'), findsNothing);

    // Switch back to 'All'
    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pumpAndSettle();

    expect(find.text('Masala Chai'), findsOneWidget);
    expect(find.text('Veg Samosa'), findsOneWidget);
  });

  testWidgets('StallPosScreen displays category split with headings and items in UI', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'stall_menu': jsonEncode([
        {'id': '101', 'name': 'Masala Chai', 'price': 20, 'category': 'Hot Drinks'},
        {'id': '102', 'name': 'Green Tea', 'price': 25, 'category': 'Hot Drinks'},
        {'id': '103', 'name': 'Paneer Roll', 'price': 70, 'category': 'Snacks'},
      ]),
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: StallPosScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify category headings
    expect(find.text('Hot Drinks'), findsWidgets); // chip + heading
    expect(find.text('Snacks'), findsWidgets); // chip + heading

    // Verify item count badge under Hot Drinks (2) and Snacks (1)
    expect(find.text('2'), findsWidgets);
    expect(find.text('1'), findsWidgets);

    // Verify all items are rendered under their respective sections
    expect(find.text('Masala Chai'), findsOneWidget);
    expect(find.text('Green Tea'), findsOneWidget);
    expect(find.text('Paneer Roll'), findsOneWidget);
  });

  testWidgets('Store Admin allows deleting a menu item from menu catalog', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'stall_menu': jsonEncode([
        {'id': '101', 'name': 'Masala Chai', 'price': 20, 'category': 'Beverages'},
      ]),
    });

    final counterCtrl = CounterController(storageService: AppStorage.instance.counterStorage);
    await counterCtrl.init();

    await tester.pumpWidget(StallPosApp(controller: counterCtrl, initialIndex: 1));
    await tester.pumpAndSettle();

    expect(find.text('Masala Chai'), findsOneWidget);

    // Switch to Store Admin
    await tester.tap(find.byTooltip('Store Admin'));
    await tester.pumpAndSettle();

    // Switch to Menu & Variants tab
    await tester.tap(find.text('Menu & Variants'));
    await tester.pumpAndSettle();

    expect(find.text('Masala Chai'), findsWidgets);

    // Tap delete button on Masala Chai
    await tester.tap(find.byTooltip('Delete Item'));
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('Delete Menu Item?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Switch back to POS tab
    await tester.tap(find.byTooltip('Stall POS'));
    await tester.pumpAndSettle();

    // Menu should now be empty
    expect(find.text('Masala Chai'), findsNothing);
    expect(find.text('No menu items yet'), findsOneWidget);
  });

  testWidgets('StallPosScreen fires order and displays side-by-side on wide screens', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'stall_menu': jsonEncode([
        {'id': '101', 'name': 'Paneer Wrap', 'price': 100, 'category': 'Snacks'},
        {'id': '102', 'name': 'Cold Coffee', 'price': 60, 'category': 'Beverages'},
      ]),
    });

    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: StallPosScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Add Paneer Wrap and Cold Coffee
    await tester.tap(find.text('Paneer Wrap'));
    await tester.tap(find.text('Cold Coffee'));
    await tester.pumpAndSettle();

    expect(find.text('PUNCH ORDER (#1) • ₹160'), findsOneWidget);

    // Fire the order directly (no popup dialog)
    await tester.tap(find.text('PUNCH ORDER (#1) • ₹160'));
    await tester.pumpAndSettle();

    // Cart cleared and next token is #2
    expect(find.text('TAP ITEMS TO START (#2)'), findsOneWidget);

    // On wide screen, Kitchen Queue is displayed side-by-side
    expect(find.text('#1'), findsOneWidget);
    expect(find.textContaining('Paneer Wrap'), findsWidgets);
    expect(find.textContaining('Cold Coffee'), findsWidgets);
    expect(find.text('To Confirm Payment'), findsOneWidget);
    expect(find.text('Confirm Payment'), findsOneWidget);

    // Tap Confirm Payment to pay
    await tester.tap(find.text('Confirm Payment'));
    await tester.pumpAndSettle();
    expect(find.text('Order #1'), findsOneWidget);
    await tester.tap(find.text('Confirm Payment & Complete'));
    await tester.pumpAndSettle();

    // Now order moves to Confirmed Payment Orders and has ✓ Done button
    expect(find.text('Confirmed Payment Orders'), findsOneWidget);
    expect(find.text('✓ Done'), findsOneWidget);

    // Mark order as completed
    await tester.tap(find.text('✓ Done'));
    await tester.pumpAndSettle();

    // Verify queue is now all caught up
    expect(find.text('All caught up! No pending orders.'), findsOneWidget);
  });

  testWidgets('Store Admin navigates to Order History and back', (WidgetTester tester) async {
    final counterCtrl = CounterController(storageService: AppStorage.instance.counterStorage);
    await counterCtrl.init();

    await tester.pumpWidget(StallPosApp(controller: counterCtrl, initialIndex: 1));
    await tester.pumpAndSettle();

    // Switch to Store Admin
    await tester.tap(find.byTooltip('Store Admin'));
    await tester.pumpAndSettle();

    // Switch to History & Tools tab
    await tester.tap(find.text('History & Tools'));
    await tester.pumpAndSettle();

    // Tap Open Order History button
    await tester.tap(find.text('Open Order History'));
    await tester.pumpAndSettle();

    // Order History screen is displayed
    expect(find.text('Order History'), findsOneWidget);
    expect(find.byTooltip('Download CSV'), findsOneWidget);

    // Pop back
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Store Management Studio'), findsOneWidget);
  });

  testWidgets('Store Admin imports menu items from CSV via History & Tools', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final counterCtrl = CounterController(storageService: AppStorage.instance.counterStorage);
    await counterCtrl.init();

    await tester.pumpWidget(StallPosApp(controller: counterCtrl, initialIndex: 1));
    await tester.pumpAndSettle();

    // Switch to Store Admin
    await tester.tap(find.byTooltip('Store Admin'));
    await tester.pumpAndSettle();

    // Switch to History & Tools tab
    await tester.tap(find.text('History & Tools'));
    await tester.pumpAndSettle();

    // Tap 'Import Menu CSV'
    await tester.tap(find.text('Import Menu CSV'));
    await tester.pumpAndSettle();

    expect(find.text('Import POS Menu Items'), findsOneWidget);

    // Switch to Paste Text tab
    await tester.tap(find.text('Paste Text'));
    await tester.pumpAndSettle();

    // Tap 'Load Sample'
    await tester.tap(find.text('Load Sample'));
    await tester.pumpAndSettle();

    // Tap 'Import 7 Items'
    await tester.tap(find.text('Import 7 Items'));
    await tester.pumpAndSettle();

    // Switch back to Stall POS tab
    await tester.tap(find.byTooltip('Stall POS'));
    await tester.pumpAndSettle();

    // Verify items and categories are loaded into menu
    expect(find.text('Masala Chai'), findsOneWidget);
    expect(find.text('Filter Coffee'), findsOneWidget);
    expect(find.text('Veg Samosa'), findsOneWidget);
    expect(find.text('Beverages'), findsWidgets);
    expect(find.text('Snacks'), findsWidgets);

    // Tap on item to start order
    await tester.tap(find.text('Masala Chai'));
    await tester.pumpAndSettle();

    expect(find.text('PUNCH ORDER (#1) • ₹20'), findsOneWidget);
  });

  testWidgets('StallPosScreen renders category colors in filter bar and headings', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'stall_menu': jsonEncode([
        {'id': '101', 'name': 'Masala Tea', 'price': 20, 'category': 'Beverages'},
        {'id': '102', 'name': 'Aloo Samosa', 'price': 30, 'category': 'Snacks'},
      ]),
    });

    final counterCtrl = CounterController(storageService: AppStorage.instance.counterStorage);
    await counterCtrl.init();

    await tester.pumpWidget(StallPosApp(controller: counterCtrl, initialIndex: 1));
    await tester.pumpAndSettle();

    // Category filter chips should be present: 'All', 'Beverages', 'Snacks'
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Beverages'), findsWidgets);
    expect(find.text('Snacks'), findsWidgets);

    // Verify ChoiceChips have avatar dots for specific categories
    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
    expect(chips.length, greaterThanOrEqualTo(3));

    // Find the chip for 'Beverages' and verify it has an avatar dot
    final bevChip = chips.firstWhere((c) => (c.label as Text).data == 'Beverages');
    expect(bevChip.avatar, isNotNull);

    // Verify category headings render with items count badge
    expect(find.text('Masala Tea'), findsOneWidget);
    expect(find.text('Aloo Samosa'), findsOneWidget);
  });
}
