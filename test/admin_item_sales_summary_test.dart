import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/src/models/stall_models.dart';
import 'package:counter_app/src/storage/stall_storage_service.dart';
import 'package:counter_app/src/views/order_history_view.dart';
import 'package:counter_app/src/services/csv_export_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ItemSalesSummary and Aggregation Tests', () {
    test('aggregateItemSales aggregates quantities, revenue, and addon breakdowns accurately', () {
      final now = DateTime.now();
      final orders = [
        StallOrder(
          token: 1,
          items: const [
            OrderItem(
              itemId: 'momo_steam',
              itemName: 'Momos',
              selectedVariant: CategoryOption(id: 'steam', name: 'Steam'),
              price: 150.0,
              quantity: 2,
              categoryName: 'Momos',
              dietaryType: ItemDietaryType.veg,
              selectedAddons: [
                CategoryOption(id: 'extra_piece', name: 'Extra Piece Momo', price: 25.0),
              ],
            ),
          ],
          timestamp: now,
          isCompleted: true,
          completedAt: now,
        ),
        StallOrder(
          token: 2,
          items: const [
            OrderItem(
              itemId: 'momo_steam',
              itemName: 'Momos',
              selectedVariant: CategoryOption(id: 'steam', name: 'Steam'),
              price: 150.0,
              quantity: 1,
              categoryName: 'Momos',
              dietaryType: ItemDietaryType.veg,
              selectedAddons: [
                CategoryOption(id: 'extra_piece', name: 'Extra Piece Momo', price: 25.0),
              ],
            ),
            OrderItem(
              itemId: 'chai',
              itemName: 'Masala Chai',
              price: 20.0,
              quantity: 3,
              categoryName: 'Beverages',
              dietaryType: ItemDietaryType.veg,
            ),
          ],
          timestamp: now,
          isCompleted: true,
          completedAt: now,
        ),
        // Pending order should be excluded by default from completed sales aggregation
        StallOrder(
          token: 3,
          items: const [
            OrderItem(
              itemId: 'momo_fried',
              itemName: 'Momos',
              selectedVariant: CategoryOption(id: 'fried', name: 'Fried'),
              price: 170.0,
              quantity: 5,
              categoryName: 'Momos',
            ),
          ],
          timestamp: now,
          isCompleted: false,
        ),
      ];

      final summaries = orders.aggregateItemSales(completedOnly: true);

      // We expect 2 completed distinct items: Momos (Steam) and Masala Chai
      expect(summaries.length, 2);

      // Sorted by revenue desc:
      // Momos (Steam): 3 units @ (150 + 25) = 175 * 3 = 525.0
      // Masala Chai: 3 units @ 20 = 60.0
      final momoSummary = summaries.firstWhere((s) => s.baseName == 'Momos');
      expect(momoSummary.totalQuantity, 3);
      expect(momoSummary.totalRevenue, 525.0);
      expect(momoSummary.averageUnitPrice, 175.0);
      expect(momoSummary.baseUnitPrice, 150.0);
      expect(momoSummary.hasAddons, isTrue);
      expect(momoSummary.isVeg, isTrue);
      expect(momoSummary.addonsBreakdown.length, 1);
      expect(momoSummary.addonsBreakdown.first.name, 'Extra Piece Momo');
      expect(momoSummary.addonsBreakdown.first.quantity, 3);
      expect(momoSummary.addonsBreakdown.first.totalRevenue, 75.0);

      final chaiSummary = summaries.firstWhere((s) => s.baseName == 'Masala Chai');
      expect(chaiSummary.totalQuantity, 3);
      expect(chaiSummary.totalRevenue, 60.0);
      expect(chaiSummary.hasAddons, isFalse);
    });

    test('generateItemSalesSummaryCsv formats RFC 4180 CSV correctly with period header', () {
      final summary = [
        const ItemSalesSummary(
          itemKey: 'momo_steam',
          displayName: 'Veg Momos (Steam)',
          baseName: 'Veg Momos',
          variantName: 'Steam',
          categoryName: 'Momos',
          totalQuantity: 4,
          totalRevenue: 700.0,
          baseUnitPrice: 150.0,
          averageUnitPrice: 175.0,
          addonsBreakdown: [
            ItemAddonSales(name: 'Extra Piece Momo', quantity: 4, totalRevenue: 100.0),
          ],
        ),
      ];

      final csv = CsvExportService.generateItemSalesSummaryCsv(
        items: summary,
        dateRangeLabel: 'Today',
      );

      expect(csv, contains('# Sales Summary Period: Today'));
      expect(csv, contains('Item Name,Base Name,Variant,Category,Quantity Sold,Average Unit Price,Total Sales,Add-ons Breakdown'));
      expect(csv, contains('Veg Momos (Steam)'));
      expect(csv, contains('4'));
      expect(csv, contains('175.00'));
      expect(csv, contains('700.00'));
      expect(csv, contains('4x Extra Piece Momo'));
    });
  });

  group('OrderHistoryView UI Breakdown & Date Filtering Tests', () {
    testWidgets('OrderHistoryView toggles to itemized breakdown and displays item sales cards', (WidgetTester tester) async {
      final storageService = StallStorageService();
      final now = DateTime.now();

      final orders = [
        StallOrder(
          token: 201,
          items: const [
            OrderItem(
              itemId: 'momo_steam',
              itemName: 'Momos',
              selectedVariant: CategoryOption(id: 'steam', name: 'Steam'),
              price: 150.0,
              quantity: 2,
              categoryName: 'Momos',
              dietaryType: ItemDietaryType.veg,
              selectedAddons: [
                CategoryOption(id: 'extra_piece', name: 'Extra Piece Momo', price: 25.0),
              ],
            ),
          ],
          timestamp: now,
          isCompleted: true,
          completedAt: now,
        ),
        StallOrder(
          token: 202,
          items: const [
            OrderItem(
              itemId: 'samosa',
              itemName: 'Samosa',
              price: 25.0,
              quantity: 4,
              categoryName: 'Snacks',
              dietaryType: ItemDietaryType.veg,
            ),
          ],
          timestamp: now,
          isCompleted: true,
          completedAt: now,
        ),
      ];

      await storageService.saveOrders(orders);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderHistoryView(
              storageService: storageService,
              showHeaderActions: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check SegmentedButton exists
      expect(find.text('Orders List (2)'), findsOneWidget);
      expect(find.text('Items Breakdown (6 sold)'), findsOneWidget);

      // Verify order cards are shown initially
      expect(find.text('#201'), findsOneWidget);
      expect(find.text('#202'), findsOneWidget);

      // Tap on Items Breakdown segment
      await tester.tap(find.text('Items Breakdown (6 sold)'));
      await tester.pumpAndSettle();

      // Order tickets should no longer be rendered
      expect(find.text('#201'), findsNothing);
      expect(find.text('#202'), findsNothing);

      // Item sales summaries should appear with quantities and revenue
      expect(find.text('Momos (Steam)'), findsOneWidget);
      expect(find.text('Samosa'), findsOneWidget);
      expect(find.text('2 sold · Base ₹150'), findsOneWidget);
      expect(find.text('4 sold · Base ₹25'), findsOneWidget);
      expect(find.text('₹350'), findsOneWidget); // 2 * (150 + 25)
      expect(find.text('₹100'), findsOneWidget); // 4 * 25
      expect(find.text('• Extra Piece Momo (x2)'), findsOneWidget);
      expect(find.text('+₹50'), findsOneWidget);

      // Switch back to Orders List
      await tester.tap(find.text('Orders List (2)'));
      await tester.pumpAndSettle();
      expect(find.text('#201'), findsOneWidget);
    });

    testWidgets('Date filter chips update metrics banner and filter completed orders', (WidgetTester tester) async {
      final storageService = StallStorageService();
      final now = DateTime.now();

      final orders = [
        StallOrder(
          token: 301,
          items: const [
            OrderItem(itemId: '1', itemName: 'Burger', price: 100.0, quantity: 1),
          ],
          timestamp: now,
          isCompleted: true,
        ),
        StallOrder(
          token: 302,
          items: const [
            OrderItem(itemId: '2', itemName: 'Pizza', price: 200.0, quantity: 1),
          ],
          timestamp: now.subtract(const Duration(days: 3)),
          isCompleted: true,
        ),
      ];

      await storageService.saveOrders(orders);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderHistoryView(
              storageService: storageService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All Time shows 2 orders, ₹300 total revenue
      expect(find.text('₹300'), findsOneWidget);
      expect(find.text('2'), findsWidgets); // Orders count & items

      // Switch to Today
      await tester.ensureVisible(find.text('Today'));
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      // Today shows only 1 order (#301), ₹100 revenue
      expect(find.text('₹100'), findsWidgets);
      expect(find.text('#301'), findsOneWidget);
      expect(find.text('#302'), findsNothing);
    });
  });
}
