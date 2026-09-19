import 'package:flutter_test/flutter_test.dart';
import 'package:counter_app/src/models/stall_models.dart';
import 'package:counter_app/src/controllers/order_controller.dart';
import 'package:counter_app/src/storage/in_memory_storage.dart';

void main() {
  group('Concrete Models Equality & HashCode Tests', () {
    test('MenuItem equality and hashCode are based on id', () {
      const item1 = MenuItem(
        id: 'item_1',
        name: 'Veg Burger',
        price: 50.0,
      );
      const item2 = MenuItem(
        id: 'item_1',
        name: 'Veggie Deluxe Burger',
        price: 70.0,
      );
      const item3 = MenuItem(
        id: 'item_2',
        name: 'Veg Burger',
        price: 50.0,
      );

      expect(item1 == item2, isTrue);
      expect(item1.hashCode, equals(item2.hashCode));
      expect(item1 == item3, isFalse);
    });

    test('ItemCategory equality and hashCode are based on id', () {
      const cat1 =
          ItemCategory(id: 'cat_momos', name: 'Momos', additionalCost: 5.0);
      const cat2 = ItemCategory(
          id: 'cat_momos', name: 'Delicious Momos', additionalCost: 10.0);
      const cat3 = ItemCategory(id: 'cat_burgers', name: 'Momos');

      expect(cat1 == cat2, isTrue);
      expect(cat1.hashCode, equals(cat2.hashCode));
      expect(cat1 == cat3, isFalse);
    });

    test('CategoryOption equality and hashCode are based on id', () {
      const opt1 = CategoryOption(
          id: 'opt_cheese', name: 'Extra Cheese', additionalCost: 20.0);
      const opt2 = CategoryOption(
          id: 'opt_cheese', name: 'Cheese Slice', additionalCost: 25.0);
      const opt3 = CategoryOption(id: 'opt_mayo', name: 'Extra Cheese');

      expect(opt1 == opt2, isTrue);
      expect(opt1.hashCode, equals(opt2.hashCode));
      expect(opt1 == opt3, isFalse);
    });

    test('MenuItem copyWith updates properties and handles isAvailable immutably',
        () {
      const item = MenuItem(
        id: 'item_coke',
        name: 'Coca Cola',
        price: 40.0,
      );
      expect(item.isAvailable, isTrue);

      final unavailableItem = item.copyWith(isAvailable: false);
      expect(unavailableItem.isAvailable, isFalse);
      expect(item.isAvailable, isTrue);

      final restoredItem = unavailableItem.copyWith(isAvailable: true);
      expect(restoredItem.isAvailable, isTrue);
    });
  });

  group('OrderItem Centralized Pricing and CartKey Tests', () {
    test(
        'Calculates unitPrice and totalPrice correctly with variant, category cost, and addons',
        () {
      const variant =
          CategoryOption(id: 'opt_fried', name: 'Fried', additionalCost: 15.0);
      const addon1 =
          CategoryOption(id: 'opt_cheese', name: 'Cheese', additionalCost: 20.0);
      const addon2 =
          CategoryOption(id: 'opt_mayo', name: 'Mayo', additionalCost: 10.0);

      const orderItem = OrderItem(
        itemId: 'momo_1',
        itemName: 'Momos',
        price: 100.0,
        quantity: 3,
        selectedVariant: variant,
        categoryAdditionalCost: 5.0,
        selectedAddons: [addon1, addon2],
        notes: 'Extra Spicy',
      );

      // unitPrice = 100 + 15 + 5 + (20 + 10) = 150
      expect(orderItem.unitPrice, equals(150.0));
      // totalPrice = 150 * 3 = 450
      expect(orderItem.totalPrice, equals(450.0));
    });

    test('Generates deterministic cartKey regardless of add-on list ordering', () {
      const variant = CategoryOption(id: 'opt_fried', name: 'Fried');
      const addon1 = CategoryOption(id: 'addon_b', name: 'Dip');
      const addon2 = CategoryOption(id: 'addon_a', name: 'Cheese');

      const itemA = OrderItem(
        itemId: 'item_1',
        itemName: 'Fries',
        price: 80.0,
        selectedVariant: variant,
        selectedAddons: [addon1, addon2],
        notes: 'No Salt ',
      );

      const itemB = OrderItem(
        itemId: 'item_1',
        itemName: 'Fries',
        price: 80.0,
        selectedVariant: variant,
        selectedAddons: [addon2, addon1],
        notes: '  no salt',
      );

      expect(itemA.cartKey, equals('item_1_opt_fried_addon_a+addon_b_no salt'));
      expect(itemB.cartKey, equals(itemA.cartKey));
    });
  });

  group('OrderController Indexing and Centralized Filtering Tests', () {
    late OrderController controller;

    setUp(() async {
      controller = OrderController(storage: InMemoryStorage());
      await controller.loadInitialData();
      await controller.setMenu([
        const MenuItem(
          id: 'item_tea',
          name: 'Masala Chai',
          price: 20.0,
          category: ItemCategory(id: 'cat_bev', name: 'Beverages'),
        ),
        const MenuItem(
          id: 'item_coffee',
          name: 'Cold Coffee',
          price: 60.0,
          category: ItemCategory(id: 'cat_bev', name: 'Beverages'),
        ),
        const MenuItem(
          id: 'item_samosa',
          name: 'Veg Samosa',
          price: 25.0,
          category: ItemCategory(id: 'cat_snacks', name: 'Snacks'),
        ),
      ]);
    });

    test('getItemById and getItemsByCategory perform O(1) cached lookups', () {
      final tea = controller.getItemById('item_tea');
      expect(tea, isNotNull);
      expect(tea!.name, equals('Masala Chai'));

      final nonExistent = controller.getItemById('missing_id');
      expect(nonExistent, isNull);

      final bevItems = controller.getItemsByCategory('cat_bev');
      expect(bevItems.length, equals(2));
      expect(bevItems.map((i) => i.name),
          containsAll(['Masala Chai', 'Cold Coffee']));
    });

    test('Indexes are updated dynamically when items are added, updated, or deleted',
        () async {
      await controller.addMenuItem(
        const MenuItem(
          id: 'item_brownie',
          name: 'Choco Brownie',
          price: 80.0,
          category: ItemCategory(id: 'cat_dessert', name: 'Desserts'),
        ),
      );

      expect(controller.getItemById('item_brownie'), isNotNull);
      expect(controller.getItemsByCategory('cat_dessert').length, equals(1));

      await controller.deleteMenuItem('item_brownie');
      expect(controller.getItemById('item_brownie'), isNull);
      expect(controller.getItemsByCategory('cat_dessert'), isEmpty);
    });

    test('filterMenuItems filters by query, categoryId, and onlyAvailable correctly',
        () async {
      // Query search
      final chaiSearch = controller.filterMenuItems(query: 'chai');
      expect(chaiSearch.length, equals(1));
      expect(chaiSearch.first.id, equals('item_tea'));

      // Category filter
      final bevFilter = controller.filterMenuItems(categoryId: 'cat_bev');
      expect(bevFilter.length, equals(2));

      // Availability filter
      await controller.setItemAvailability('item_tea', false);
      final availableBevs = controller.filterMenuItems(
        categoryId: 'cat_bev',
        onlyAvailable: true,
      );
      expect(availableBevs.length, equals(1));
      expect(availableBevs.first.id, equals('item_coffee'));
    });

    test('addToCart and updateCartItem support OrderItem and update line items cleanly',
        () {
      const orderItem = OrderItem(
        itemId: 'item_coffee',
        itemName: 'Cold Coffee',
        price: 60.0,
        quantity: 2,
        notes: 'Extra ice',
      );

      controller.addToCart(orderItem);
      expect(controller.cart[orderItem.cartKey], equals(2));

      final updatedOrderItem = orderItem.copyWith(quantity: 3);
      controller.updateCartItem(updatedOrderItem);
      expect(controller.cart[orderItem.cartKey], equals(3));
    });
  });
}
