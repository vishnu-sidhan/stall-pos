import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/src/controllers/order_controller.dart';
import 'package:counter_app/src/models/stall_models.dart';
import 'package:counter_app/src/storage/stall_storage_service.dart';
import 'package:counter_app/src/storage/in_memory_storage.dart';
import 'package:counter_app/src/services/csv_export_service.dart';

void main() {
  late StallStorageService storageService;
  late OrderController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'stall_menu': jsonEncode([
        {'id': 'item_1', 'name': 'Masala Chai', 'price': 20.0, 'category': 'Beverages'},
        {'id': 'item_2', 'name': 'Veg Samosa', 'price': 25.0, 'category': 'Snacks'},
        {'id': 'item_3', 'name': 'Cold Coffee', 'price': 50.0, 'category': 'Beverages'},
      ]),
      'stall_next_token': 101,
    });
    storageService = StallStorageService();
    controller = OrderController(storage: storageService);
    await controller.loadPersistedData();
  });

  group('OrderController - Basic Operations', () {
    test('initializes with loaded menu and default state', () {
      expect(controller.menu.length, 3);
      expect(controller.nextToken, 101);
      expect(controller.cart, isEmpty);
      expect(controller.orders, isEmpty);
      expect(controller.activeOrders, isEmpty);
      expect(controller.isEditing, isFalse);
      expect(controller.editingOrderId, isNull);
    });

    test('adds and removes items to/from cart', () {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1');
      controller.addToCart(chai);
      expect(controller.cart['item_1'], 1);
      expect(controller.cartItemCount, 1);
      expect(controller.cartTotal, 20.0);

      controller.addToCart(chai);
      expect(controller.cart['item_1'], 2);
      expect(controller.cartItemCount, 2);
      expect(controller.cartTotal, 40.0);

      controller.removeFromCart('item_1');
      expect(controller.cart['item_1'], 1);
      expect(controller.cartTotal, 20.0);

      controller.removeFromCart('item_1');
      expect(controller.cart.containsKey('item_1'), isFalse);
      expect(controller.cartTotal, 0.0);
    });
  });

  group('OrderController - Requirement 2: Optional Customer Name', () {
    test('places order without customer name successfully and falls back to Walk-in Customer', () async {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1');
      controller.addToCart(chai);

      final outcome = await controller.punchOrUpdateOrder(
        customerName: null,
        paymentMethod: 'Cash',
      );

      expect(outcome.isEdit, isFalse);
      expect(outcome.token, 101);
      expect(controller.orders.length, 1);

      final order = controller.orders.first;
      expect(order.token, 101);
      expect(order.customerName, isNull);
      expect(order.displayCustomerName, 'Walk-in Customer');
      expect(order.isPaid, isFalse); // Default is payment pending

      // Confirm payment
      await controller.confirmPayment(token: 101, paymentMethod: 'Cash');
      expect(controller.orders.first.isPaid, isTrue);
      expect(controller.orders.first.paymentMethod, 'Cash');
      expect(controller.nextToken, 102);
      expect(controller.cart, isEmpty);
    });

    test('places order with custom customer name', () async {
      final samosa = controller.menu.firstWhere((m) => m.id == 'item_2');
      controller.addToCart(samosa);

      await controller.punchOrUpdateOrder(
        customerName: 'Aarav Patel',
        paymentMethod: 'UPI',
      );

      final order = controller.orders.first;
      expect(order.customerName, 'Aarav Patel');
      expect(order.displayCustomerName, 'Aarav Patel');
      expect(order.paymentMethod, 'UPI');
    });
  });

  group('OrderController - Requirement 1: Order Editing & Deletion', () {
    test('edits an active order in-place without generating a new ID', () async {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1');
      final samosa = controller.menu.firstWhere((m) => m.id == 'item_2');

      // Place initial order
      controller.addToCart(chai);
      controller.addToCart(chai);
      await controller.punchOrUpdateOrder(
        customerName: 'Rahul',
        paymentMethod: 'Cash',
      );

      final originalOrder = controller.orders.first;
      expect(originalOrder.token, 101);
      expect(originalOrder.itemsSummary, contains('2x Masala Chai'));
      expect(originalOrder.total, 40.0);
      expect(controller.nextToken, 102);

      // Start editing
      final custName = controller.startEditingOrder(originalOrder);
      expect(custName, 'Rahul');
      expect(controller.isEditing, isTrue);
      expect(controller.editingOrderId, 101);
      expect(controller.cart['item_1'], 2);

      // Modify items in cart: add a Samosa
      controller.addToCart(samosa);
      expect(controller.cartTotal, 65.0); // 40 + 25

      // Save / Update order
      final updateOutcome = await controller.punchOrUpdateOrder(
        customerName: 'Rahul M',
        paymentMethod: 'UPI',
      );

      expect(updateOutcome.isEdit, isTrue);
      expect(updateOutcome.token, 101);
      expect(controller.nextToken, 102); // Token should NOT have incremented
      expect(controller.isEditing, isFalse);
      expect(controller.editingOrderId, isNull);
      expect(controller.cart, isEmpty);

      // Verify order record updated in-place
      expect(controller.orders.length, 1);
      final updated = controller.orders.first;
      expect(updated.token, 101);
      expect(updated.total, 65.0);
      expect(updated.customerName, 'Rahul M');
      expect(updated.paymentMethod, 'UPI');
      expect(updated.items['item_1'], 2);
      expect(updated.items['item_2'], 1);
    });

    test('edge case: editing an order with removed items', () async {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1');
      final samosa = controller.menu.firstWhere((m) => m.id == 'item_2');

      // Order with 2 chai and 2 samosas
      controller.addToCart(chai);
      controller.addToCart(chai);
      controller.addToCart(samosa);
      controller.addToCart(samosa);
      await controller.punchOrUpdateOrder(
        customerName: 'Priya',
        paymentMethod: 'Cash',
      );

      final order = controller.orders.first;
      controller.startEditingOrder(order);

      // Remove both samosas from cart
      controller.removeFromCart('item_2');
      controller.removeFromCart('item_2');
      expect(controller.cart.containsKey('item_2'), isFalse);
      expect(controller.cart['item_1'], 2);

      await controller.punchOrUpdateOrder(
        customerName: 'Priya',
        paymentMethod: 'Cash',
      );

      final updated = controller.orders.first;
      expect(updated.items.containsKey('item_2'), isFalse);
      expect(updated.items['item_1'], 2);
      expect(updated.total, 40.0);
    });

    test('edge case: deleting the currently edited order cancels edit mode', () async {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1');
      controller.addToCart(chai);
      await controller.punchOrUpdateOrder(
        customerName: 'Sam',
        paymentMethod: 'Cash',
      );

      final order = controller.orders.first;
      controller.startEditingOrder(order);
      expect(controller.isEditing, isTrue);

      // Delete the order while editing it
      await controller.deleteOrder(order.token);

      expect(controller.orders, isEmpty);
      expect(controller.isEditing, isFalse);
      expect(controller.editingOrderId, isNull);
      expect(controller.cart, isEmpty);
    });

    test('cancelEditingOrder restores cart to clean state without modifying order', () async {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1');
      controller.addToCart(chai);
      await controller.punchOrUpdateOrder(
        customerName: 'Neha',
        paymentMethod: 'Cash',
      );

      final order = controller.orders.first;
      controller.startEditingOrder(order);
      controller.addToCart(chai); // cart is now 2x

      controller.cancelEditingOrder();

      expect(controller.isEditing, isFalse);
      expect(controller.editingOrderId, isNull);
      expect(controller.cart, isEmpty);
      // Original order intact with 1x
      expect(controller.orders.first.total, 20.0);
    });
  });

  group('OrderController - Requirement 5: Combined Orders View (Consolidated Items)', () {
    test('combinedActiveOrders aggregates quantities and orders tags across multiple tickets for confirmed payment orders only', () async {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1');
      final samosa = controller.menu.firstWhere((m) => m.id == 'item_2');
      final coffee = controller.menu.firstWhere((m) => m.id == 'item_3');

      // Order #101: 3x Chai, 2x Samosa (Paid)
      controller.addToCart(chai);
      controller.addToCart(chai);
      controller.addToCart(chai);
      controller.addToCart(samosa);
      controller.addToCart(samosa);
      await controller.punchOrUpdateOrder(customerName: 'Table 1', paymentMethod: 'Cash', isPaid: true);

      // Order #102: 2x Chai, 1x Samosa, 4x Coffee (Unpaid initially)
      controller.addToCart(chai);
      controller.addToCart(chai);
      controller.addToCart(samosa);
      controller.addToCart(coffee);
      controller.addToCart(coffee);
      controller.addToCart(coffee);
      controller.addToCart(coffee);
      await controller.punchOrUpdateOrder(customerName: 'Table 2', paymentMethod: 'UPI', isPaid: false);

      // Before confirming #102, combinedActiveOrders only has items from #101
      expect(controller.combinedActiveOrders.length, 2);
      expect(controller.combinedActiveOrders.firstWhere((a) => a.itemName == 'Masala Chai').totalQuantity, 3);

      // Confirm payment for #102
      await controller.confirmPayment(token: 102, paymentMethod: 'UPI');

      // Order #103: 3x Chai (Paid)
      controller.addToCart(chai);
      controller.addToCart(chai);
      controller.addToCart(chai);
      await controller.punchOrUpdateOrder(customerName: 'Table 3', paymentMethod: 'Cash', isPaid: true);

      final aggregated = controller.combinedActiveOrders;
      expect(aggregated.length, 3);

      // Check Masala Chai: 3 + 2 + 3 = 8
      final chaiSummary = aggregated.firstWhere((a) => a.itemName == 'Masala Chai');
      expect(chaiSummary.totalQuantity, 8);
      expect(chaiSummary.category, 'Beverages');
      expect(chaiSummary.tickets.length, 3);
      expect(chaiSummary.tickets[0].token, 101);
      expect(chaiSummary.tickets[0].quantity, 3);
      expect(chaiSummary.tickets[1].token, 102);
      expect(chaiSummary.tickets[1].quantity, 2);
      expect(chaiSummary.tickets[2].token, 103);
      expect(chaiSummary.tickets[2].quantity, 3);

      // Check Cold Coffee: 4
      final coffeeSummary = aggregated.firstWhere((a) => a.itemName == 'Cold Coffee');
      expect(coffeeSummary.totalQuantity, 4);
      expect(coffeeSummary.tickets.length, 1);
      expect(coffeeSummary.tickets[0].token, 102);
      expect(coffeeSummary.tickets[0].quantity, 4);

      // Check Veg Samosa: 2 + 1 = 3
      final samosaSummary = aggregated.firstWhere((a) => a.itemName == 'Veg Samosa');
      expect(samosaSummary.totalQuantity, 3);
      expect(samosaSummary.tickets.length, 2);
    });

    test('combinedActiveOrders updates reactively when orders are completed or deleted', () async {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1');

      // Order 101: 2x Chai (Paid)
      controller.addToCart(chai);
      controller.addToCart(chai);
      await controller.punchOrUpdateOrder(customerName: 'A', paymentMethod: 'Cash', isPaid: true);

      // Order 102: 3x Chai (Paid)
      controller.addToCart(chai);
      controller.addToCart(chai);
      controller.addToCart(chai);
      await controller.punchOrUpdateOrder(customerName: 'B', paymentMethod: 'UPI', isPaid: true);

      expect(controller.combinedActiveOrders.first.totalQuantity, 5);

      // Complete Order 101
      await controller.completeOrder(101);
      expect(controller.combinedActiveOrders.first.totalQuantity, 3);
      expect(controller.combinedActiveOrders.first.tickets.length, 1);
      expect(controller.combinedActiveOrders.first.tickets.first.token, 102);

      // Delete Order 102
      await controller.deleteOrder(102);
      expect(controller.combinedActiveOrders, isEmpty);
    });
  });

  group('OrderController - Granular Item Completion & Direct Order Completion', () {
    test('completeOrderItem decrements remaining quantity in combinedActiveOrders and preserves uncompleted items', () async {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1');
      final samosa = controller.menu.firstWhere((m) => m.id == 'item_2');

      // Order 101: 2x Chai, 1x Samosa (Paid)
      controller.addToCart(chai);
      controller.addToCart(chai);
      controller.addToCart(samosa);
      await controller.punchOrUpdateOrder(customerName: 'Alice', paymentMethod: 'UPI', isPaid: true);

      expect(controller.combinedActiveOrders.length, 2);
      final initialChai = controller.combinedActiveOrders.firstWhere((i) => i.itemName == 'Masala Chai');
      expect(initialChai.totalQuantity, 2);

      // Complete 1x Chai for Order 101
      final orderCompleted1 = await controller.completeOrderItem(
        token: 101,
        itemId: 'item_1',
        quantity: 1,
      );
      expect(orderCompleted1, isFalse);
      expect(controller.activeOrders.length, 1);

      // In combinedActiveOrders, Chai should now have 1 remaining
      final updatedChai = controller.combinedActiveOrders.firstWhere((i) => i.itemName == 'Masala Chai');
      expect(updatedChai.totalQuantity, 1);
      expect(updatedChai.tickets.first.quantity, 1);

      // Complete remaining 1x Chai for Order 101
      final orderCompleted2 = await controller.completeOrderItem(
        token: 101,
        itemId: 'item_1',
        quantity: 1,
      );
      expect(orderCompleted2, isFalse);

      // Chai should now be completely gone from combinedActiveOrders since 0 remaining
      expect(controller.combinedActiveOrders.any((i) => i.itemName == 'Masala Chai'), isFalse);
      // Samosa is still pending in combinedActiveOrders
      expect(controller.combinedActiveOrders.firstWhere((i) => i.itemName == 'Veg Samosa').totalQuantity, 1);

      // Complete the Samosa: this should trigger order auto-completion!
      final orderCompleted3 = await controller.completeOrderItem(
        token: 101,
        itemId: 'item_2',
      );
      expect(orderCompleted3, isTrue);

      // Order 101 is now completed and removed from active orders
      expect(controller.activeOrders, isEmpty);
      expect(controller.combinedActiveOrders, isEmpty);
      expect(controller.orders.first.isCompleted, isTrue);
      expect(controller.orders.first.completedAt, isNotNull);
    });

    test('uncompleteOrderItem restores item and active order state', () async {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1');

      // Order 101: 1x Chai (Paid)
      controller.addToCart(chai);
      await controller.punchOrUpdateOrder(customerName: 'Bob', paymentMethod: 'Cash', isPaid: true);

      // Complete item -> order auto-completes
      await controller.completeOrderItem(token: 101, itemId: 'item_1');
      expect(controller.activeOrders, isEmpty);

      // Uncomplete item -> order re-opens as active
      await controller.uncompleteOrderItem(token: 101, itemId: 'item_1');
      expect(controller.activeOrders.length, 1);
      expect(controller.orders.first.isCompleted, isFalse);
      expect(controller.combinedActiveOrders.firstWhere((i) => i.itemName == 'Masala Chai').totalQuantity, 1);
    });

    test('completeAggregatedItem fulfills item across all tickets in batch', () async {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1');

      // Order 101: 2x Chai
      controller.addToCart(chai);
      controller.addToCart(chai);
      await controller.punchOrUpdateOrder(customerName: 'A', paymentMethod: 'UPI', isPaid: true);

      // Order 102: 3x Chai
      controller.addToCart(chai);
      controller.addToCart(chai);
      controller.addToCart(chai);
      await controller.punchOrUpdateOrder(customerName: 'B', paymentMethod: 'UPI', isPaid: true);

      expect(controller.combinedActiveOrders.firstWhere((i) => i.itemName == 'Masala Chai').totalQuantity, 5);

      // Batch complete all Chai
      final completedTokens = await controller.completeAggregatedItem('item_1');
      expect(completedTokens, containsAll([101, 102]));
      expect(controller.activeOrders, isEmpty);
      expect(controller.combinedActiveOrders, isEmpty);
    });

    test('completeNextTicketForItem fulfills oldest pending ticket in FIFO order', () async {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1');

      // Order 101: 2x Chai
      controller.addToCart(chai);
      controller.addToCart(chai);
      await controller.punchOrUpdateOrder(customerName: 'A', paymentMethod: 'UPI', isPaid: true);

      // Order 102: 3x Chai
      controller.addToCart(chai);
      controller.addToCart(chai);
      controller.addToCart(chai);
      await controller.punchOrUpdateOrder(customerName: 'B', paymentMethod: 'UPI', isPaid: true);

      // Complete next ticket for Chai -> completes #101
      final result = await controller.completeNextTicketForItem('item_1');
      expect(result?.token, 101);
      expect(result?.isOrderFullyCompleted, isTrue);

      // Only #102 remains in queue with 3x Chai
      expect(controller.combinedActiveOrders.firstWhere((i) => i.itemName == 'Masala Chai').totalQuantity, 3);
      expect(controller.combinedActiveOrders.firstWhere((i) => i.itemName == 'Masala Chai').tickets.first.token, 102);
    });

    test('completeOrder marks all items 100% completed and removes order from active queue', () async {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1');
      final samosa = controller.menu.firstWhere((m) => m.id == 'item_2');

      controller.addToCart(chai);
      controller.addToCart(samosa);
      await controller.punchOrUpdateOrder(customerName: 'C', paymentMethod: 'Cash', isPaid: true);

      await controller.completeOrder(101);
      final completed = controller.orders.firstWhere((o) => o.token == 101);
      expect(completed.isCompleted, isTrue);
      expect(completed.completedItems['item_1'], 1);
      expect(completed.completedItems['item_2'], 1);
      expect(completed.completionProgress, 1.0);
      expect(controller.activeOrders, isEmpty);
      expect(controller.combinedActiveOrders, isEmpty);
    });
  });

  group('OrderController - Slash Items & Add-on Linking', () {
    test('detects variants and adds selected variant to cart', () async {
      final orItem = MenuItem(
        id: 'item_or',
        name: 'Hot Beverage',
        price: 30.0,
        category: ItemCategory.named(
          'Hot Drinks',
          options: const [
            CategoryOption(id: 'v1', name: 'Tea'),
            CategoryOption(id: 'v2', name: 'Coffee'),
            CategoryOption(id: 'v3', name: 'Green Tea'),
          ],
        ),
      );
      await controller.addMenuItem(orItem);

      expect(orItem.hasVariants, isTrue);
      expect(orItem.effectiveVariants.map((v) => v.name).toList(), ['Tea', 'Coffee', 'Green Tea']);

      controller.addVariantToCart(orItem, 'Coffee');
      expect(controller.cart['item_or_var_Coffee'], 1);
      expect(controller.cartTotal, 30.0);

      final found = controller.findItem('item_or_var_Coffee');
      expect(found.name, 'Hot Beverage (Coffee)');
      expect(found.price, 30.0);
      expect(found.categoryName, 'Hot Drinks');
    });

    test('preserves categories containing slash as single intact filter chips', () {
      final itemComboCat = MenuItem(
        id: 'item_combo_cat',
        name: 'French Fries',
        price: 60.0,
        category: ItemCategory.named('Snacks / Fast Food'),
      );
      controller.addMenuItem(itemComboCat);

      expect(controller.categories, contains('Snacks / Fast Food'));
      expect(controller.categories.contains('Fast Food'), isFalse);

      // Filter by 'Snacks / Fast Food'
      controller.selectCategory('Snacks / Fast Food');
      expect(controller.filteredMenu.any((m) => m.name == 'French Fries'), isTrue);
    });

    test('links add-on to base item, formats name with bracket prefix, and sums price', () async {
      final burger = MenuItem(
        id: 'item_burger',
        name: 'Veg Burger',
        price: 80.0,
        category: ItemCategory.named(
          'Fast Food',
          addons: const [
            CategoryOption(id: 'addon_cheese', name: 'Extra Cheese', price: 20.0),
          ],
        ),
      );
      final addon = MenuItem(
        id: 'addon_cheese',
        name: 'Extra Cheese',
        price: 20.0,
        category: ItemCategory.named('Addons'),
      );

      await controller.addMenuItem(burger);
      await controller.addMenuItem(addon);

      // Add 2 burgers to cart
      controller.addToCart(burger);
      controller.addToCart(burger);
      expect(controller.cart[burger.id], 2);
      expect(controller.cartTotal, 160.0);

      // Link Extra Cheese to one of the burgers
      controller.addAddonToCart(targetCartItemId: burger.id, addon: addon);

      // Cart should now have 1x Veg Burger and 1x [Extra Cheese] Veg Burger
      expect(controller.cart[burger.id], 1);
      expect(controller.cart['${burger.id}+${addon.id}'], 1);

      // Total price: 80 + (80 + 20) = 180
      expect(controller.cartTotal, 180.0);

      final compositeItem = controller.findItem('${burger.id}+${addon.id}');
      expect(compositeItem.name, '[Extra Cheese] Veg Burger');
      expect(compositeItem.price, 100.0);

      // Punch order and check summary string
      final orderResult = await controller.punchOrUpdateOrder(
        customerName: 'Kunal',
        paymentMethod: 'Cash',
        isPaid: true,
      );

      final punchedOrder = controller.orders.firstWhere((o) => o.token == orderResult.token);
      expect(punchedOrder.itemsSummary, contains('1x Veg Burger (Fast Food)'));
      expect(punchedOrder.itemsSummary, contains('1x [Extra Cheese] Veg Burger (Fast Food)'));
      expect(punchedOrder.total, 180.0);
    });

    test('kitchen item summary tracks customized add-on item as a separate row from base item', () async {
      final burger = MenuItem(
        id: 'item_burger_kitchen',
        name: 'Veg Burger',
        price: 80.0,
        category: ItemCategory.named('Fast Food'),
      );
      final addon = MenuItem(
        id: 'addon_cheese_kitchen',
        name: 'Extra Cheese',
        price: 20.0,
        category: ItemCategory.named('Addons'),
      );

      await controller.addMenuItem(burger);
      await controller.addMenuItem(addon);

      // Order 1: 1x regular Veg Burger, 1x [Extra Cheese] Veg Burger
      controller.addToCart(burger);
      controller.addToCart(burger);
      controller.addAddonToCart(targetCartItemId: burger.id, addon: addon);
      await controller.punchOrUpdateOrder(customerName: 'Order 1', paymentMethod: 'Cash', isPaid: true);

      // Order 2: 2x regular Veg Burger
      controller.addToCart(burger);
      controller.addToCart(burger);
      await controller.punchOrUpdateOrder(customerName: 'Order 2', paymentMethod: 'UPI', isPaid: true);

      final aggregated = controller.combinedActiveOrders;

      // Veg Burger and [Extra Cheese] Veg Burger must be distinct rows!
      final regularBurgers = aggregated.firstWhere((a) => a.itemName.contains('Veg Burger') && !a.itemName.contains('Extra Cheese'));
      final cheeseBurgers = aggregated.firstWhere((a) => a.itemName.contains('Extra Cheese'));

      expect(regularBurgers.totalQuantity, 3); // 1 from Order 1 + 2 from Order 2
      expect(cheeseBurgers.totalQuantity, 1); // 1 from Order 1
    });

    test('findItem resolves _var_, _cat_, and composite items with addon variants', () async {
      final riceNoodles = MenuItem(
        id: 'item_rice_noodles',
        name: 'Fried Rice / Hakka Noodles',
        price: 120.0,
        category: ItemCategory.named('Rice / Noodles'),
      );
      final addonCheeseMayo = MenuItem(
        id: 'addon_cheese_mayo',
        name: 'Cheese / Mayo',
        price: 30.0,
        category: ItemCategory.named('Extras'),
      );

      await controller.addMenuItem(riceNoodles);
      await controller.addMenuItem(addonCheeseMayo);

      // 1. Resolve variant name only
      final varItem = controller.findItem('item_rice_noodles_var_Fried Rice');
      expect(varItem.name, 'Fried Rice');
      expect(varItem.categoryName, 'Rice / Noodles');
      expect(varItem.price, 120.0);
      expect(varItem.displayName, 'Fried Rice');

      // 2. Resolve category only
      final catItem = controller.findItem('item_rice_noodles_cat_Rice');
      expect(catItem.name, 'Fried Rice / Hakka Noodles');
      expect(catItem.categoryName, 'Rice');
      expect(catItem.price, 120.0);
      expect(catItem.displayName, 'Fried Rice / Hakka Noodles');

      // 3. Resolve both variant name and category
      final bothItem = controller.findItem('item_rice_noodles_var_Fried Rice_cat_Rice');
      expect(bothItem.name, 'Fried Rice');
      expect(bothItem.categoryName, 'Rice');
      expect(bothItem.price, 120.0);
      expect(bothItem.displayName, 'Fried Rice');

      // 4. Resolve composite item with addon variant
      final composite = controller.findItem('item_rice_noodles_var_Fried Rice_cat_Rice+addon_cheese_mayo_var_Cheese');
      expect(composite.name, '[Cheese] Fried Rice');
      expect(composite.categoryName, 'Rice');
      expect(composite.price, 150.0);
      expect(composite.displayName, '[Cheese] Fried Rice');
    });

    test('addCustomizedItemToCart and addAddonToCart with variant name correctly punch order', () async {
      final noodles = MenuItem(
        id: 'item_noodles',
        name: 'Noodles',
        price: 100.0,
        category: ItemCategory.named('Rice / Noodles'),
      );
      final dip = MenuItem(
        id: 'addon_dip',
        name: 'Red / Green Chutney',
        price: 15.0,
        category: ItemCategory.named('Extras'),
      );

      await controller.addMenuItem(noodles);
      await controller.addMenuItem(dip);

      // Add noodles with category resolved to Noodles
      controller.addCustomizedItemToCart(
        baseItem: noodles,
        resolvedCategory: 'Noodles',
      );

      expect(controller.cart['item_noodles_cat_Noodles'], 1);
      expect(controller.cartBaseItems.length, 1);
      expect(controller.cartBaseItems.first.displayName, 'Noodles');

      // Link addon with variant 'Green Chutney'
      controller.addAddonToCart(
        targetCartItemId: 'item_noodles_cat_Noodles',
        addon: dip,
        resolvedAddonName: 'Green Chutney',
      );

      expect(controller.cart['item_noodles_cat_Noodles+addon_dip_var_Green Chutney'], 1);
      expect(controller.cartTotal, 115.0);

      final orderResult = await controller.punchOrUpdateOrder(
        customerName: 'Aarav',
        paymentMethod: 'UPI',
        isPaid: true,
      );

      final punchedOrder = controller.orders.firstWhere((o) => o.token == orderResult.token);
      final itemsWithCategory = controller.getOrderItemsWithCategory(punchedOrder);
      expect(itemsWithCategory.first.name, '[Green Chutney] Noodles');
      expect(itemsWithCategory.first.category, 'Noodles');
      expect(itemsWithCategory.first.displayName, '[Green Chutney] Noodles (Noodles)');
    });

    test('same add-on added twice formats as [2x Addon] and calculates accurate price', () async {
      final burger = MenuItem(
        id: 'item_burger_xtimes',
        name: 'Veg Burger',
        price: 80.0,
        category: ItemCategory.named('Fast Food'),
      );
      final cheese = MenuItem(
        id: 'addon_cheese_xtimes',
        name: 'Extra Cheese',
        price: 20.0,
        category: ItemCategory.named('Addons'),
      );

      await controller.addMenuItem(burger);
      await controller.addMenuItem(cheese);

      controller.addToCart(burger);
      // Link cheese once
      controller.addAddonToCart(targetCartItemId: burger.id, addon: cheese);

      expect(controller.cart['${burger.id}+${cheese.id}'], 1);
      final singleAddonItem = controller.findItem('${burger.id}+${cheese.id}');
      expect(singleAddonItem.name, '[Extra Cheese] Veg Burger');
      expect(singleAddonItem.price, 100.0);
      expect(singleAddonItem.displayName, '[Extra Cheese] Veg Burger');

      // Link cheese a second time to the same item
      controller.addAddonToCart(targetCartItemId: '${burger.id}+${cheese.id}', addon: cheese);

      final doubleAddonId = '${burger.id}+${cheese.id}+${cheese.id}';
      expect(controller.cart[doubleAddonId], 1);
      expect(controller.cartTotal, 120.0); // 80 + 20*2

      final doubleAddonItem = controller.findItem(doubleAddonId);
      expect(doubleAddonItem.name, '[2x Extra Cheese] Veg Burger');
      expect(doubleAddonItem.price, 120.0);
      expect(doubleAddonItem.displayName, '[2x Extra Cheese] Veg Burger');

      // Linking cheese a third time throws StateError because max 2 add-ons per item is enforced
      expect(
        () => controller.addAddonToCart(targetCartItemId: doubleAddonId, addon: cheese),
        throwsA(isA<StateError>()),
      );
      final tripleAddonId = '${burger.id}+${cheese.id}+${cheese.id}+${cheese.id}';
      final tripleAddonItem = controller.findItem(tripleAddonId);
      expect(tripleAddonItem.name, '[3x Extra Cheese] Veg Burger');
      expect(tripleAddonItem.price, 140.0);
    });

    test('multiple different add-ons format properly with max 2 limit', () async {
      final burger = MenuItem(
        id: 'item_burger_multi',
        name: 'Veg Burger',
        price: 80.0,
        category: ItemCategory.named('Fast Food'),
      );
      final cheese = MenuItem(
        id: 'addon_cheese_multi',
        name: 'Cheese',
        price: 25.0,
        category: ItemCategory.named('Addons'),
      );
      final mayo = MenuItem(
        id: 'addon_mayo_multi',
        name: 'Mayo',
        price: 15.0,
        category: ItemCategory.named('Addons'),
      );

      await controller.addMenuItem(burger);
      await controller.addMenuItem(cheese);
      await controller.addMenuItem(mayo);

      controller.addToCart(burger);

      // Attempting to add 3x Cheese throws StateError (max per addon item is 2)
      expect(
        () => controller.addMultipleAddonsToCart(
          targetCartItemId: burger.id,
          addons: [
            (addon: cheese, resolvedName: null, quantity: 3),
          ],
        ),
        throwsA(isA<StateError>()),
      );

      // Adding 2x Cheese and 2x Mayo (4 add-ons total, max 2 of each) succeeds!
      controller.addMultipleAddonsToCart(
        targetCartItemId: burger.id,
        addons: [
          (addon: cheese, resolvedName: null, quantity: 2),
          (addon: mayo, resolvedName: null, quantity: 2),
        ],
      );

      final compositeId = '${burger.id}+${cheese.id}+${cheese.id}+${mayo.id}+${mayo.id}';
      expect(controller.cart[compositeId], 1);
      expect(controller.cartTotal, 160.0); // 80 + 25*2 + 15*2 = 160

      final compositeItem = controller.findItem(compositeId);
      expect(compositeItem.name, '[2x Cheese] [2x Mayo] Veg Burger');
      expect(compositeItem.price, 160.0);
      expect(compositeItem.displayName, '[2x Cheese] [2x Mayo] Veg Burger');

      // Attempting to add a 3rd Cheese to this composite item throws StateError
      expect(
        () => controller.addAddonToCart(
          targetCartItemId: compositeId,
          addon: cheese,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Rice / Noodles category is preserved intact as single category chip and grouped menu section', () async {
      final rice = MenuItem(
        id: 'item_rice',
        name: 'Fried Rice',
        price: 120.0,
        category: ItemCategory.named('Rice / Noodles'),
      );
      final noodles = MenuItem(
        id: 'item_noodles_alone',
        name: 'Hakka Noodles',
        price: 110.0,
        category: ItemCategory.named('Rice / Noodles'),
      );

      await controller.addMenuItem(rice);
      await controller.addMenuItem(noodles);

      // categories getter preserves 'Rice / Noodles' intact
      expect(controller.categories.contains('Rice / Noodles'), isTrue);
      expect(controller.categories.contains('Rice'), isFalse);
      expect(controller.categories.contains('Noodles'), isFalse);

      // groupedMenu groups both items under 'Rice / Noodles'
      final grouped = controller.groupedMenu;
      expect(grouped.containsKey('Rice / Noodles'), isTrue);
      expect(grouped['Rice / Noodles']!.length, 2);
      expect(grouped.containsKey('Rice'), isFalse);
      expect(grouped.containsKey('Noodles'), isFalse);
    });
  });

  group('OrderController - Additional Payment on Order Update', () {
    test('editing a paid order with new items marks it pending if additional payment not confirmed', () async {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1'); // ₹20
      final samosa = controller.menu.firstWhere((m) => m.id == 'item_2'); // ₹25

      // 1. Create and pay for order #101 (2x Chai = ₹40)
      controller.addToCart(chai);
      controller.addToCart(chai);
      await controller.punchOrUpdateOrder(
        customerName: 'Aman',
        paymentMethod: 'UPI',
        isPaid: true,
      );

      var order = controller.orders.first;
      expect(order.token, 101);
      expect(order.total, 40.0);
      expect(order.paidAmount, 40.0);
      expect(order.isPaid, isTrue);
      expect(order.remainingDue, 0.0);
      expect(order.hasPartialPayment, isFalse);

      // Verify in combinedActiveOrders
      expect(controller.combinedActiveOrders.first.itemName, 'Masala Chai');
      expect(controller.combinedActiveOrders.first.totalQuantity, 2);

      // 2. Edit order #101: add a Samosa (+₹25 -> ₹65)
      controller.startEditingOrder(order);
      controller.addToCart(samosa);
      expect(controller.cartTotal, 65.0);

      // Update without immediate payment (Pay Later flow)
      await controller.punchOrUpdateOrder(
        customerName: 'Aman',
        isPaid: false,
        paidAmount: 40.0,
      );

      order = controller.orders.first;
      expect(order.total, 65.0);
      expect(order.paidAmount, 40.0);
      expect(order.remainingDue, 25.0);
      expect(order.hasPartialPayment, isTrue);
      expect(order.isPaid, isFalse);

      // Order #101 has paid items (Chai), so it appears in confirmedActiveOrders (showing Chai)
      expect(controller.confirmedActiveOrders.length, 1);
      expect(controller.getConfirmedOrderItems(order), {'item_1': 2});

      // Order #101 also has pending items (Samosa), so it appears in toConfirmPaymentOrders (showing Samosa)
      expect(controller.toConfirmPaymentOrders.length, 1);
      expect(controller.getPendingOrderItems(order), {'item_2': 1});

      // In combinedActiveOrders, Samosa must NOT be present (only confirmed items)!
      final activeCombined = controller.combinedActiveOrders;
      expect(activeCombined.any((a) => a.itemName == 'Veg Samosa'), isFalse);
      expect(activeCombined.firstWhere((a) => a.itemName == 'Masala Chai').totalQuantity, 2);

      // 3. Confirm the remaining payment
      await controller.confirmPayment(token: 101, paymentMethod: 'UPI');

      order = controller.orders.first;
      expect(order.paidAmount, 65.0);
      expect(order.remainingDue, 0.0);
      expect(order.hasPartialPayment, isFalse);
      expect(order.isPaid, isTrue);

      // Now both Chai and Samosa are confirmed!
      expect(controller.confirmedActiveOrders.length, 1);
      expect(controller.toConfirmPaymentOrders, isEmpty);
      expect(controller.getConfirmedOrderItems(order), {'item_1': 2, 'item_2': 1});
      expect(controller.getPendingOrderItems(order), isEmpty);

      final finalCombined = controller.combinedActiveOrders;
      expect(finalCombined.firstWhere((a) => a.itemName == 'Masala Chai').totalQuantity, 2);
      expect(finalCombined.firstWhere((a) => a.itemName == 'Veg Samosa').totalQuantity, 1);
    });

    test('adding an addon item moves the linked item to confirm payment and excludes it from item summary until paid', () async {
      final burger = const MenuItem(id: 'item_burger', name: 'Veg Burger', price: 50);
      final cheese = const MenuItem(id: 'item_cheese', name: 'Extra Cheese', price: 20);
      final chai = const MenuItem(id: 'item_chai', name: 'Masala Chai', price: 20);
      await controller.setMenu([burger, cheese, chai]);

      // 1. Place order with 1x Burger and 1x Chai, fully paid (₹70)
      controller.addToCart(burger);
      controller.addToCart(chai);
      await controller.punchOrUpdateOrder(customerName: 'Rohit', isPaid: true, paidAmount: 70.0);

      var order = controller.orders.first;
      expect(order.isPaid, isTrue);
      expect(controller.confirmedActiveOrders.length, 1);
      expect(controller.toConfirmPaymentOrders, isEmpty);
      expect(controller.combinedActiveOrders.length, 2);

      // 2. Edit order: link cheese add-on to the burger (Burger becomes [Extra Cheese] Veg Burger, new total ₹90)
      controller.startEditingOrder(order);
      controller.addAddonToCart(targetCartItemId: 'item_burger', addon: cheese);
      expect(controller.cartTotal, 90.0);

      // Update order as Pay Later (₹70 previously paid, ₹20 additional due)
      await controller.punchOrUpdateOrder(
        customerName: 'Rohit',
        isPaid: false,
        paidAmount: 70.0,
      );

      order = controller.orders.first;
      expect(order.isPaid, isFalse);
      expect(order.remainingDue, 20.0);

      // Confirmed items: only Masala Chai (Burger has unpaid add-on, so it moved to pending!)
      final confirmedItems = controller.getConfirmedOrderItems(order);
      expect(confirmedItems.containsKey('item_chai'), isTrue);
      expect(confirmedItems['item_chai'], 1);
      expect(confirmedItems.containsKey('item_burger+item_cheese'), isFalse);

      // Pending items: the ENTIRE linked item [Extra Cheese] Veg Burger
      final pendingItems = controller.getPendingOrderItems(order);
      expect(pendingItems.containsKey('item_burger+item_cheese'), isTrue);
      expect(pendingItems['item_burger+item_cheese'], 1);
      expect(pendingItems.containsKey('item_chai'), isFalse);

      // Both queues show this order with their respective sliced items
      expect(controller.confirmedActiveOrders.length, 1);
      expect(controller.toConfirmPaymentOrders.length, 1);

      // Item summary must ONLY show confirmed items (Masala Chai, NOT the linked burger with unpaid cheese)
      final activeSummary = controller.combinedActiveOrders;
      expect(activeSummary.length, 1);
      expect(activeSummary.first.itemName, 'Masala Chai');
      expect(activeSummary.any((a) => a.itemName.contains('Burger')), isFalse);

      // 3. Confirm payment for the extra ₹20
      await controller.confirmPayment(token: order.token, paymentMethod: 'Cash');
      order = controller.orders.first;
      expect(order.isPaid, isTrue);

      // Now both items are confirmed and appear in Item Summary
      expect(controller.toConfirmPaymentOrders, isEmpty);
      expect(controller.confirmedActiveOrders.length, 1);
      final finalSummary = controller.combinedActiveOrders;
      expect(finalSummary.length, 2);
      expect(finalSummary.any((a) => a.itemName.contains('Cheese') && a.itemName.contains('Burger')), isTrue);
      expect(finalSummary.any((a) => a.itemName == 'Masala Chai'), isTrue);
    });

    test('getCartItemBreakdown and cart totals calculate split between item and addons', () {
      final controller = OrderController();
      final burger = MenuItem(id: 'item_burger', name: 'Veg Burger', price: 80.0, category: ItemCategory.named('Fast Food'));
      final cheese = MenuItem(id: 'item_cheese', name: 'Extra Cheese', price: 20.0, category: ItemCategory.named('Addons'));
      final mayo = MenuItem(id: 'item_mayo', name: 'Mayo', price: 15.0, category: ItemCategory.named('Addons'));
      final tea = MenuItem(id: 'item_tea', name: 'Tea', price: 10.0, category: ItemCategory.named('Beverages'));
      controller.setMenu([burger, cheese, mayo, tea]);

      // Standalone item breakdown is null
      expect(controller.getCartItemBreakdown('item_burger'), isNull);

      // Add burger with cheese + mayo
      controller.addToCart(burger);
      controller.addAddonToCart(targetCartItemId: 'item_burger', addon: cheese);
      controller.addAddonToCart(targetCartItemId: 'item_burger+item_cheese', addon: mayo);
      controller.addToCart(tea);

      final compositeKey = 'item_burger+item_cheese+item_mayo';
      final breakdown = controller.getCartItemBreakdown(compositeKey);
      expect(breakdown, isNotNull);
      expect(breakdown!.baseItem.name, 'Veg Burger');
      expect(breakdown.basePrice, 80.0);
      expect(breakdown.addonsPrice, 35.0);
      expect(breakdown.totalUnitPrice, 115.0);
      expect(breakdown.addonDetails.length, 2);
      expect(breakdown.addonDetails[0].name, 'Extra Cheese');
      expect(breakdown.addonDetails[0].totalPrice, 20.0);
      expect(breakdown.addonDetails[1].name, 'Mayo');
      expect(breakdown.addonDetails[1].totalPrice, 15.0);

      // Cart totals split:
      // Burger base: 80, Tea base: 10 => 90
      // Addons: 35
      // Total: 125
      expect(controller.cartBaseItemsTotal, 90.0);
      expect(controller.cartAddonsTotal, 35.0);
      expect(controller.cartTotal, 125.0);
    });

    group('Item Add-on Architecture', () {
      test('OrderController queries and validates item add-ons', () async {
        final burger = MenuItem(
          id: 'item_burger',
          name: 'Veg Burger',
          price: 80.0,
          category: ItemCategory.named(
            'Fast Food',
            addons: const [
              CategoryOption(id: 'addon_cheese', name: 'Extra Cheese', price: 25.0),
            ],
          ),
        );
        final tea = MenuItem(
          id: 'item_tea',
          name: 'Masala Chai',
          price: 20.0,
          category: ItemCategory.named(
            'Beverages',
            addons: const [
              CategoryOption(id: 'addon_ginger', name: 'Ginger', price: 5.0),
            ],
          ),
        );
        final cheese = MenuItem(
          id: 'addon_cheese',
          name: 'Extra Cheese',
          price: 25.0,
          category: ItemCategory.named('Extras'),
        );
        final ginger = MenuItem(
          id: 'addon_ginger',
          name: 'Ginger',
          price: 5.0,
          category: ItemCategory.named('Extras'),
        );

        await controller.addMenuItem(burger);
        await controller.addMenuItem(tea);

        // getAddonsForCategory & hasAddonsForCategory
        final fastFoodAddons = controller.getAddonsForCategory('Fast Food');
        expect(fastFoodAddons.length, 1);
        expect(fastFoodAddons.first.name, 'Extra Cheese');
        expect(controller.hasAddonsForCategory('Fast Food'), isTrue);

        final beverageAddons = controller.getAddonsForCategory('Beverages');
        expect(beverageAddons.length, 1);
        expect(beverageAddons.first.name, 'Ginger');
        expect(controller.hasAddonsForCategory('Beverages'), isTrue);

        expect(controller.getAddonsForCategory('Desserts'), isEmpty);
        expect(controller.hasAddonsForCategory('Desserts'), isFalse);

        // Add burger and tea to cart
        controller.addToCart(burger);
        controller.addToCart(tea);

        // Successfully add matching add-ons
        controller.addAddonToCart(targetCartItemId: burger.id, addon: cheese);
        controller.addAddonToCart(targetCartItemId: tea.id, addon: ginger);

        expect(controller.cart['item_burger+addon_cheese'], 1);
        expect(controller.cart['item_tea+addon_ginger'], 1);
      });
    });

    group('Menu Catalog CSV Round-Trip Restoration', () {
      test('exports and restores sub-categories with additional prices and category surcharges with 100% fidelity', () async {
        // 1. Setup rich categories with surcharges and differential option costs
        final momosCategory = ItemCategory(
          id: 'cat_momos',
          name: 'Momos',
          additionalCost: 15.0, // packaging surcharge
          colorHex: 0xFFEA580C,
          options: const [
            CategoryOption(id: 'opt_steam', name: 'Steam', additionalCost: 0.0),
            CategoryOption(id: 'opt_fried', name: 'Fried', additionalCost: 10.0),
            CategoryOption(id: 'opt_pan_fried', name: 'Pan Fried', additionalCost: 20.0),
            CategoryOption(id: 'opt_special', name: 'Special Jhol', price: 120.0),
          ],
          addons: const [
            CategoryOption(id: 'opt_dip', name: 'Schezwan Dip', price: 20.0, dietaryType: ItemDietaryType.veg),
          ],
        );

        final rollsCategory = ItemCategory(
          id: 'cat_rolls',
          name: 'Rolls',
          additionalCost: 5.0,
          colorHex: 0xFF10B981,
          options: const [
            CategoryOption(id: 'opt_single', name: 'Single Egg', additionalCost: 0.0),
            CategoryOption(id: 'opt_double', name: 'Double Egg', additionalCost: 25.0),
          ],
        );

        final items = [
          MenuItem(
            id: 'item_veg_momos',
            name: 'Veg Momos',
            price: 80.0,
            category: momosCategory,
            dietaryType: ItemDietaryType.veg,
          ),
          MenuItem(
            id: 'item_chicken_momos',
            name: 'Chicken Momos',
            price: 110.0,
            category: momosCategory,
            dietaryType: ItemDietaryType.nonVeg,
          ),
          MenuItem(
            id: 'item_egg_roll',
            name: 'Kolkata Egg Roll',
            price: 70.0,
            category: rollsCategory,
            dietaryType: ItemDietaryType.egg,
          ),
        ];

        // 2. Initialize Controller A and import catalog
        final storageA = InMemoryStorage();
        final controllerA = OrderController(storage: storageA);
        await controllerA.importMenuCatalog(
          items: items,
          categories: [momosCategory, rollsCategory],
          replace: true,
        );

        expect(controllerA.menu.length, 3);
        expect(controllerA.categoryConfigs.length, 2); // Momos, Rolls

        // Verify Controller A has options and surcharges
        final catMomosA = controllerA.categoryConfigs.firstWhere((c) => c.name == 'Momos');
        expect(catMomosA.additionalCost, 15.0);
        expect(catMomosA.options.length, 4);
        expect(catMomosA.options[1].name, 'Fried');
        expect(catMomosA.options[1].additionalCost, 10.0);
        expect(catMomosA.options[2].name, 'Pan Fried');
        expect(catMomosA.options[2].additionalCost, 20.0);
        expect(catMomosA.options[3].name, 'Special Jhol');
        expect(catMomosA.options[3].price, 120.0);

        // 3. Export to CSV string
        final exportedCsv = CsvExportService.generateMenuCsv(
          categories: controllerA.categoryConfigs,
          items: controllerA.menu,
        );

        // 4. Initialize Controller B with a completely separate empty storage
        final storageB = InMemoryStorage();
        final controllerB = OrderController(storage: storageB);
        await controllerB.loadPersistedData();

        // 5. Import exported CSV into Controller B
        final parseResult = await controllerB.importCatalogFromCsv(exportedCsv, replace: true);
        expect(parseResult.hasItems, isTrue);
        expect(parseResult.items.length, 3);

        // 6. Validate Controller B restored all data with 100% fidelity
        expect(controllerB.menu.length, 3);
        expect(controllerB.categoryConfigs.length, 2);

        final catMomosB = controllerB.categoryConfigs.firstWhere((c) => c.name == 'Momos');
        expect(catMomosB.additionalCost, 15.0);
        expect(catMomosB.colorHex, 0xFFEA580C);
        expect(catMomosB.options.length, 4);
        expect(catMomosB.options[0].name, 'Steam');
        expect(catMomosB.options[0].additionalCost, 0.0);
        expect(catMomosB.options[1].name, 'Fried');
        expect(catMomosB.options[1].additionalCost, 10.0);
        expect(catMomosB.options[2].name, 'Pan Fried');
        expect(catMomosB.options[2].additionalCost, 20.0);
        expect(catMomosB.options[3].name, 'Special Jhol');
        expect(catMomosB.options[3].price, 120.0);

        final catRollsB = controllerB.categoryConfigs.firstWhere((c) => c.name == 'Rolls');
        expect(catRollsB.additionalCost, 5.0);
        expect(catRollsB.options.length, 2);
        expect(catRollsB.options[0].name, 'Single Egg');
        expect(catRollsB.options[1].name, 'Double Egg');
        expect(catRollsB.options[1].additionalCost, 25.0);

        // Verify item-level effectiveVariants and addons in Controller B
        final vegMomosB = controllerB.menu.firstWhere((m) => m.name == 'Veg Momos');
        expect(vegMomosB.effectiveVariants.length, 4);
        expect(vegMomosB.effectiveVariants[1].additionalCost, 10.0);
        expect(vegMomosB.addons.length, 1);
        expect(vegMomosB.addons.first.name, 'Schezwan Dip');
        expect(vegMomosB.addons.first.price, 20.0);

        // 7. Verify persistence in storage: reload into Controller C from storage B
        final controllerC = OrderController(storage: storageB);
        await controllerC.loadPersistedData();

        expect(controllerC.menu.length, 3);
        expect(controllerC.categoryConfigs.length, 2);
        final catMomosC = controllerC.categoryConfigs.firstWhere((c) => c.name == 'Momos');
        expect(catMomosC.additionalCost, 15.0);
        expect(catMomosC.options.length, 4);
        expect(catMomosC.options[1].additionalCost, 10.0);
        expect(catMomosC.options[2].additionalCost, 20.0);
        expect(catMomosC.options[3].price, 120.0);

        // 8. Re-export from Controller C and verify round-trip stability
        final reExportedCsv = CsvExportService.generateMenuCsv(
          categories: controllerC.categoryConfigs,
          items: controllerC.menu,
        );
        expect(reExportedCsv, equals(exportedCsv));
      });

      test('setMenu with replace: true does not wipe out configured sub-categories', () async {
        final storage = InMemoryStorage();
        final controller = OrderController(storage: storage);
        await controller.loadPersistedData();

        // 1. Configure category "Momos" with sub-categories
        await controller.saveCategoryConfig(
          ItemCategory(
            id: 'cat_momos',
            name: 'Momos',
            additionalCost: 5.0,
            options: [
              CategoryOption(id: 'opt_steam', name: 'Steam', additionalCost: 0.0),
              CategoryOption(id: 'opt_fried', name: 'Fried', additionalCost: 10.0),
              CategoryOption(id: 'opt_pan', name: 'Pan Fried', additionalCost: 15.0),
            ],
          ),
        );

        // 2. Verify category configs has Momos with 3 options
        expect(controller.getCategoryConfig('Momos')?.options.length, 3);

        // 3. Call setMenu(..., replace: true) with items that do NOT carry category options
        final newItems = [
          const MenuItem(
            id: 'item_veg_momo',
            name: 'Veg Momos',
            category: ItemCategory(id: 'cat_momos', name: 'Momos'),
            price: 80.0,
          ),
          const MenuItem(
            id: 'item_paneer_momo',
            name: 'Paneer Momos',
            category: ItemCategory(id: 'cat_momos', name: 'Momos'),
            price: 100.0,
          ),
        ];

        await controller.setMenu(newItems, replace: true);

        // 4. Category options must still be intact!
        final momosConfig = controller.getCategoryConfig('Momos');
        expect(momosConfig, isNotNull);
        expect(momosConfig!.options.length, 3);
        expect(momosConfig.options.map((o) => o.name), containsAll(['Steam', 'Fried', 'Pan Fried']));
        expect(momosConfig.additionalCost, 5.0);

        // 5. Menu items should be hydrated with the live category options
        final vegMomo = controller.menu.firstWhere((m) => m.id == 'item_veg_momo');
        expect(vegMomo.category.options.length, 3);
        expect(vegMomo.effectiveVariants.length, 3);

        // 6. Adding customized item with category option calculates correct price (80 + 10 fried + 5 packaging = 95)
        controller.addCustomizedItemToCart(
          baseItem: vegMomo,
          resolvedName: 'Fried',
        );
        expect(controller.cartTotal, 95.0);
      });

      test('Items inherit category options and addons without conflation', () async {
        final storage = InMemoryStorage();
        final controller = OrderController(storage: storage);
        await controller.loadPersistedData();

        // Add item with category that has NO options
        final burger = MenuItem(
          id: 'item_burger',
          name: 'Veg Burger',
          category: const ItemCategory(id: 'cat_burgers', name: 'Burgers'),
          price: 50.0,
        );

        await controller.addMenuItem(burger);

        final burgerCategory = controller.getCategoryConfig('Burgers');
        expect(burgerCategory, isNotNull);
        expect(burgerCategory!.options, isEmpty);
        expect(burger.hasVariants, isFalse);
      });

      test('getCartItemDisplayName centralizes formatting and appends category in brackets for items without variants', () async {
        final storage = InMemoryStorage();
        final controller = OrderController(storage: storage);
        await controller.loadPersistedData();

        final paneerRoll = MenuItem(
          id: 'roll_paneer',
          name: 'Paneer Roll',
          price: 120.0,
          category: const ItemCategory(id: 'cat_rolls', name: 'Rolls'),
        );
        final startersItem = MenuItem(
          id: 'starter_chicken',
          name: 'Chicken Manchuria',
          price: 160.0,
          category: const ItemCategory(id: 'cat_starters', name: 'Starters'),
        );

        await controller.addMenuItem(paneerRoll);
        await controller.addMenuItem(startersItem);

        // Verify centralized display name for cart/summary/orders
        expect(controller.getCartItemDisplayName('roll_paneer'), equals('Paneer Roll (Rolls)'));
        expect(controller.getCartItemDisplayName('starter_chicken'), equals('Chicken Manchuria (Starters)'));

        // Add to cart and check Cart entries
        controller.addToCart(paneerRoll);
        controller.addToCart(startersItem);

        expect(controller.cart.containsKey('roll_paneer'), isTrue);
        expect(controller.cart.containsKey('starter_chicken'), isTrue);
        expect(controller.getCartItemDisplayName(controller.cart.keys.first), equals('Paneer Roll (Rolls)'));
      });
    });
  });
}
