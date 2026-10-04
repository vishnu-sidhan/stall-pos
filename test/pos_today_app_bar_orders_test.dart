import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/src/controllers/order_controller.dart';
import 'package:counter_app/src/models/stall_models.dart';
import 'package:counter_app/src/views/stall_pos_view.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OrderController todayOrders & todayTotalRevenue', () {
    test('filters orders strictly for current calendar day', () async {
      final controller = OrderController();
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final lastWeek = now.subtract(const Duration(days: 7));

      final orders = [
        // Today orders
        StallOrder(
          token: 1,
          items: const [
            OrderItem(itemId: '1', itemName: 'Tea', price: 20.0, quantity: 2),
          ],
          timestamp: now,
          isCompleted: true,
        ),
        StallOrder(
          token: 2,
          items: const [
            OrderItem(itemId: '2', itemName: 'Coffee', price: 50.0, quantity: 1),
          ],
          timestamp: now.subtract(const Duration(hours: 2)),
          isCompleted: false,
        ),
        // Yesterday order
        StallOrder(
          token: 3,
          items: const [
            OrderItem(itemId: '3', itemName: 'Burger', price: 150.0, quantity: 2),
          ],
          timestamp: yesterday,
          isCompleted: true,
        ),
        // Last week order
        StallOrder(
          token: 4,
          items: const [
            OrderItem(itemId: '4', itemName: 'Pizza', price: 250.0, quantity: 1),
          ],
          timestamp: lastWeek,
          isCompleted: true,
        ),
      ];

      await controller.storage.saveOrders(orders);
      await controller.loadPersistedData();

      // Total all time
      expect(controller.orders.length, 4);

      // Today only: 2 orders (Tea 40 + Coffee 50 = 90)
      expect(controller.todayOrders.length, 2);
      expect(controller.todayOrders.map((o) => o.token).toList(), [1, 2]);
      expect(controller.todayTotalRevenue, 90.0);
    });
  });

  group('StallPosScreen App Bar Metrics', () {
    testWidgets('shows orders count and total revenue for the current day only', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = OrderController();
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      // 2 orders today totaling 120, 1 order yesterday totaling 500
      final orders = [
        StallOrder(
          token: 10,
          items: const [
            OrderItem(itemId: '1', itemName: 'Samosa', price: 25.0, quantity: 2),
          ],
          timestamp: now,
          isCompleted: true,
        ),
        StallOrder(
          token: 11,
          items: const [
            OrderItem(itemId: '2', itemName: 'Dosa', price: 70.0, quantity: 1),
          ],
          timestamp: now,
          isCompleted: false,
        ),
        StallOrder(
          token: 9,
          items: const [
            OrderItem(itemId: '3', itemName: 'Biryani Platter', price: 500.0, quantity: 1),
          ],
          timestamp: yesterday,
          isCompleted: true,
        ),
      ];

      await controller.storage.saveOrders(orders);
      await controller.loadPersistedData();

      await tester.pumpWidget(
        MaterialApp(
          home: StallPosScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // App bar should display today's metrics: 2 orders and ₹120 total
      expect(find.text('Orders: 2 | ₹120'), findsOneWidget);

      // Should NOT display all-time metrics (3 orders | ₹620)
      expect(find.text('Orders: 3 | ₹620'), findsNothing);
    });
  });
}
