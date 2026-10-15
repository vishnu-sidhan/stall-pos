import 'package:counter_app/src/storage/app_storage.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/stall_pos.dart';

Future<OrderController> _initSoloTestController({bool soloMode = false}) async {
  SharedPreferences.setMockInitialValues({
    'stall_menu': jsonEncode([
      {
        'id': 'momo_1',
        'name': 'Veg Momos',
        'price': 150.0,
        'category': 'Momos',
      },
      {
        'id': 'soup_1',
        'name': 'Veg Soup',
        'price': 50.0,
        'category': 'Soups',
      },
    ]),
    'stall_orders': jsonEncode([]),
    'stall_next_token': 101,
  });
  AppStorage.reset();
  final storage = AppStorage.instance.stallStorage;
  final controller = OrderController(storage: storage);
  await controller.loadPersistedData();
  if (soloMode) {
    controller.toggleSoloMode(true);
  }
  return controller;
}

void main() {
  group('Solo Operator Mode (One-Thumb Mobile Cockpit)', () {
    testWidgets('Test 1: Toggle & Layout (Compact Wok Radar & 3-Button Express Bar)', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = await _initSoloTestController(soloMode: false);

      await tester.pumpWidget(
        MaterialApp(
          home: StallPosScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Initially solo mode is false
      expect(controller.isSoloMode, isFalse);
      expect(find.byKey(const ValueKey('compact_wok_radar_strip')), findsNothing);

      // Toggle solo mode via AppBar button
      await tester.tap(find.byKey(const Key('solo_mode_toggle_btn')));
      await tester.pumpAndSettle();

      expect(controller.isSoloMode, isTrue);
      // Compact Wok Radar strip is now pinned at top
      expect(find.byKey(const ValueKey('compact_wok_radar_strip')), findsOneWidget);
      expect(find.text('✅ Wok Clear — No Pending Prep'), findsOneWidget);

      // Add Veg Momos to cart
      await tester.tap(find.text('Veg Momos'));
      await tester.pumpAndSettle();

      expect(controller.cart.isNotEmpty, isTrue);

      // Verify 3-button Sticky Express Checkout Bar is rendered
      expect(find.byKey(const ValueKey('solo_express_bar_header')), findsOneWidget);
      expect(find.byKey(const ValueKey('solo_cash_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('solo_upi_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('solo_cook_btn')), findsOneWidget);
    });

    testWidgets('Test 2: 1-Tap Cash & UPI Express Punch (Zero Blocking Modals)', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = await _initSoloTestController(soloMode: true);

      await tester.pumpWidget(
        MaterialApp(
          home: StallPosScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Add item to cart
      await tester.tap(find.text('Veg Momos'));
      await tester.pumpAndSettle();
      expect(controller.cart['momo_1'], 1);

      // Tap CASH 1-tap checkout
      await tester.tap(find.byKey(const ValueKey('solo_cash_btn')));
      await tester.pumpAndSettle();

      // No modal dialog opened
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(PaymentConfirmationDialog), findsNothing);

      // Cart is immediately cleared
      expect(controller.cart.isEmpty, isTrue);

      // Order created and marked paid
      expect(controller.orders.length, 1);
      final order = controller.orders.first;
      expect(order.isPaid, isTrue);
      expect(order.paymentMethod, 'CASH');

      // Wok Radar strip reflects pending item to cook
      expect(find.byKey(const ValueKey('compact_wok_radar_strip')), findsOneWidget);
      expect(find.textContaining('Veg Momos'), findsWidgets);
    });

    testWidgets('Test 3: Cook While Customer Pays (Deferred UPI / PENDING payment)', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = await _initSoloTestController(soloMode: true);

      await tester.pumpWidget(
        MaterialApp(
          home: StallPosScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Add Veg Soup to cart
      await tester.tap(find.text('Veg Soup'));
      await tester.pumpAndSettle();
      expect(controller.cart['soup_1'], 1);

      // Tap COOK (Pay Later)
      await tester.tap(find.byKey(const ValueKey('solo_cook_btn')));
      await tester.pumpAndSettle();

      // Zero dialogs
      expect(find.byType(AlertDialog), findsNothing);

      // Cart cleared for next customer
      expect(controller.cart.isEmpty, isTrue);

      // Order created in PENDING unpaid state
      expect(controller.orders.length, 1);
      final pendingOrder = controller.orders.first;
      expect(pendingOrder.paymentMethod, 'PENDING');
      expect(pendingOrder.isPaid, isFalse);
      expect(pendingOrder.isCompleted, isFalse);

      // Pinned Wok Radar has item cooking
      expect(controller.combinedActiveOrders.any((item) => item.cartKey == 'soup_1'), isTrue);
      expect(find.textContaining('Veg Soup'), findsWidgets);
    });

    testWidgets('Test 4: 1-Tap Wok Radar Batch Clear (FIFO Order Preparation)', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = await _initSoloTestController(soloMode: true);

      // Punch two orders in FIFO sequence (Order #101 first, Order #102 second)
      controller.addToCart(controller.menu.firstWhere((i) => i.id == 'momo_1'));
      await controller.quickPunchSoloOrder(paymentMethod: 'CASH');

      controller.addToCart(controller.menu.firstWhere((i) => i.id == 'momo_1'));
      await controller.quickPunchSoloOrder(paymentMethod: 'PENDING');

      expect(controller.orders.length, 2);
      final firstOrder = controller.orders.first; // token 101, paid
      final secondOrder = controller.orders.last; // token 102, pending

      await tester.pumpWidget(
        MaterialApp(
          home: StallPosScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Both orders are cooking momos -> combined prep count = 2
      expect(find.text('Veg Momos'), findsWidgets);
      expect(find.text('× 2'), findsOneWidget);

      // Tap the Wok Radar pill for Veg Momos
      await tester.tap(find.byKey(const ValueKey('prep_pill_momo_1')));
      await tester.pumpAndSettle();

      // FIFO: First order (#101) was paid and its only item was prepared -> auto-completed!
      final updatedFirstOrder = controller.orders.firstWhere((o) => o.token == firstOrder.token);
      expect(updatedFirstOrder.isCompleted, isTrue);

      // Second order (#102) is still pending payment and active
      final updatedSecondOrder = controller.orders.firstWhere((o) => o.token == secondOrder.token);
      expect(updatedSecondOrder.isCompleted, isFalse);

      // Prep count decreased to 1
      expect(find.text('× 1'), findsOneWidget);
    });

    testWidgets('Test 5: 1-Tap Settlement on OrderCard (UPI & Serve)', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = await _initSoloTestController(soloMode: true);

      // Create a PENDING unpaid order
      controller.addToCart(controller.menu.firstWhere((i) => i.id == 'momo_1'));
      final order = await controller.quickPunchSoloOrder(paymentMethod: 'PENDING');
      expect(order, isNotNull);
      expect(order!.paymentMethod, 'PENDING');
      expect(order.isPaid, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: StallPosScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Queue badge in AppBar to open Active Orders tab
      await tester.tap(find.byKey(const Key('queue_badge_btn')));
      await tester.pumpAndSettle();

      // Unpaid warning badge is displayed
      expect(find.text('⚠️ UNPAID - COOKING'), findsOneWidget);

      // 1-Tap settlement buttons are rendered
      expect(find.byKey(ValueKey('upi_serve_btn_${order.token}')), findsOneWidget);
      expect(find.byKey(ValueKey('cash_serve_btn_${order.token}')), findsOneWidget);

      // Tap [ 📱 UPI & Serve ]
      await tester.tap(find.byKey(ValueKey('upi_serve_btn_${order.token}')));
      await tester.pumpAndSettle();

      // Order is settled and completed!
      final completedOrder = controller.orders.firstWhere((o) => o.token == order.token);
      expect(completedOrder.paymentMethod, 'UPI');
      expect(completedOrder.isPaid, isTrue);
      expect(completedOrder.isCompleted, isTrue);
    });
  });
}
