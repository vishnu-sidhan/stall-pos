import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/data/models/stall_models.dart';
import 'package:counter_app/controllers/order_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ItemDietaryType Inference Tests', () {
    test('Correctly infers non-veg items from names and categories', () {
      expect(ItemDietaryType.infer(name: 'Chicken Biryani'), ItemDietaryType.nonVeg);
      expect(ItemDietaryType.infer(name: 'Mutton Curry'), ItemDietaryType.nonVeg);
      expect(ItemDietaryType.infer(name: 'Fish Fry'), ItemDietaryType.nonVeg);
      expect(ItemDietaryType.infer(name: 'Prawns Masala'), ItemDietaryType.nonVeg);
      expect(ItemDietaryType.infer(name: 'Beef Roast'), ItemDietaryType.nonVeg);
      expect(ItemDietaryType.infer(name: 'Pork Sausage'), ItemDietaryType.nonVeg);
      expect(ItemDietaryType.infer(name: 'Duck Roast'), ItemDietaryType.nonVeg);
      expect(ItemDietaryType.infer(name: 'Crab Cakes'), ItemDietaryType.nonVeg);
      expect(ItemDietaryType.infer(name: 'Pepperoni Pizza'), ItemDietaryType.nonVeg);
      expect(ItemDietaryType.infer(name: 'Bacon Wrap'), ItemDietaryType.nonVeg);
      expect(ItemDietaryType.infer(name: 'Ham Sandwich'), ItemDietaryType.nonVeg);
      expect(ItemDietaryType.infer(name: 'Tuna Salad'), ItemDietaryType.nonVeg);
      expect(ItemDietaryType.infer(name: 'Salmon Grill'), ItemDietaryType.nonVeg);
      expect(ItemDietaryType.infer(name: 'Meat Platter'), ItemDietaryType.nonVeg);
    });

    test('Correctly infers non-veg when category contains non-veg hints', () {
      expect(
        ItemDietaryType.infer(name: 'Chef Special', category: 'Non-Veg'),
        ItemDietaryType.nonVeg,
      );
      expect(
        ItemDietaryType.infer(name: 'House Platter', category: 'Chicken Starters'),
        ItemDietaryType.nonVeg,
      );
      expect(
        ItemDietaryType.infer(name: 'Daily Catch', category: 'Seafood Specials'),
        ItemDietaryType.nonVeg,
      );
    });

    test('Correctly infers egg items', () {
      expect(ItemDietaryType.infer(name: 'Egg Fried Rice'), ItemDietaryType.egg);
      expect(ItemDietaryType.infer(name: 'Boiled Egg'), ItemDietaryType.egg);
      expect(ItemDietaryType.infer(name: 'Cheese Omelette'), ItemDietaryType.egg);
      expect(ItemDietaryType.infer(name: 'Egg Roll'), ItemDietaryType.egg);
      expect(ItemDietaryType.infer(name: 'Plain Anda'), ItemDietaryType.egg);
    });

    test('Correctly infers veg items', () {
      expect(ItemDietaryType.infer(name: 'Paneer Butter Masala'), ItemDietaryType.veg);
      expect(ItemDietaryType.infer(name: 'Veg Hakka Noodles'), ItemDietaryType.veg);
      expect(ItemDietaryType.infer(name: 'Mushroom Soup'), ItemDietaryType.veg);
      expect(ItemDietaryType.infer(name: 'Gobi Manchurian'), ItemDietaryType.veg);
      expect(ItemDietaryType.infer(name: 'Aloo Paratha'), ItemDietaryType.veg);
      expect(ItemDietaryType.infer(name: 'Masala Dosa'), ItemDietaryType.veg);
      expect(ItemDietaryType.infer(name: 'Idli Sambar'), ItemDietaryType.veg);
      expect(ItemDietaryType.infer(name: 'Coffee'), ItemDietaryType.veg);
      expect(ItemDietaryType.infer(name: 'Fresh Lime Soda'), ItemDietaryType.veg);
      expect(ItemDietaryType.infer(name: 'Falooda'), ItemDietaryType.veg);
    });

    test('Handles variant name inference overrides', () {
      expect(
        ItemDietaryType.infer(
          name: 'Kurkure Momos',
          variantName: 'Chicken',
        ),
        ItemDietaryType.nonVeg,
      );
      expect(
        ItemDietaryType.infer(
          name: 'Kurkure Momos',
          variantName: 'Paneer',
        ),
        ItemDietaryType.veg,
      );
      expect(
        ItemDietaryType.infer(
          name: 'Noodles',
          variantName: 'Egg',
        ),
        ItemDietaryType.egg,
      );
    });
  });

  group('ItemDietaryType Parsing & Serialization Tests', () {
    test('fromString lenient parsing', () {
      expect(ItemDietaryType.fromString('veg'), ItemDietaryType.veg);
      expect(ItemDietaryType.fromString('VEGETARIAN'), ItemDietaryType.veg);
      expect(ItemDietaryType.fromString('pure veg'), ItemDietaryType.veg);
      expect(ItemDietaryType.fromString('non_veg'), ItemDietaryType.nonVeg);
      expect(ItemDietaryType.fromString('non veg'), ItemDietaryType.nonVeg);
      expect(ItemDietaryType.fromString('nonveg'), ItemDietaryType.nonVeg);
      expect(ItemDietaryType.fromString('meat'), ItemDietaryType.nonVeg);
      expect(ItemDietaryType.fromString('egg'), ItemDietaryType.egg);
      expect(ItemDietaryType.fromString('eggitarian'), ItemDietaryType.egg);
      expect(ItemDietaryType.fromString('none'), ItemDietaryType.none);
      expect(ItemDietaryType.fromString(null), ItemDietaryType.none);
      expect(ItemDietaryType.fromString('unknown'), ItemDietaryType.none);
    });

    test('JSON serialization round-trip on MenuItem', () {
      final item = MenuItem(
        id: 'item_101',
        name: 'Paneer Tikka',
        price: 220,
        category: const ItemCategory(id: 'cat_1', name: 'Starters'),
        dietaryType: ItemDietaryType.veg,
      );

      final json = item.toJson();
      expect(json['dietaryType'], 'veg');

      final deserialized = MenuItem.fromJson(json);
      expect(deserialized.dietaryType, ItemDietaryType.veg);
      expect(deserialized.effectiveDietaryType, ItemDietaryType.veg);
    });

    test('JSON serialization round-trip on CategoryOption', () {
      final option = CategoryOption(
        id: 'opt_1',
        name: 'Egg Option',
        additionalCost: 30,
        dietaryType: ItemDietaryType.egg,
      );

      final json = option.toJson();
      expect(json['dietaryType'], 'egg');

      final deserialized = CategoryOption.fromJson(json);
      expect(deserialized.dietaryType, ItemDietaryType.egg);
    });

    test('Fallback to auto-inference when dietaryType is not specified', () {
      final item = MenuItem(
        id: 'item_102',
        name: 'Chicken 65',
        price: 180,
        category: const ItemCategory(id: 'cat_1', name: 'Starters'),
      );
      expect(item.dietaryType, isNull);
      expect(item.effectiveDietaryType, ItemDietaryType.nonVeg);
    });
  });

  group('ItemCategory isAddonCategory Tests', () {
    test('ItemCategory preserves isAddonCategory in JSON', () {
      final cat = const ItemCategory(
        id: 'cat_addons',
        name: 'Sauces & Dips',
        isAddonCategory: true,
      );

      final json = cat.toJson();
      expect(json['isAddonCategory'], isTrue);

      final restored = ItemCategory.fromJson(json);
      expect(restored.isAddonCategory, isTrue);
    });

    test('MenuItem effectiveIsAddon resolves from isAddonCategory', () {
      final addonCat = const ItemCategory(
        id: 'cat_bev_addons',
        name: 'Beverage Addons',
        isAddonCategory: true,
      );
      final item = MenuItem(
        id: 'addon_1',
        name: 'Boba Pearls',
        price: 40,
        category: addonCat,
      );

      expect(item.isAddon, isFalse);
      expect(item.effectiveIsAddon, isTrue);
    });
  });

  group('OrderController _resolveBaseItem and Dietary Propagation Tests', () {
    test('Resolves base item and preserves dietary classification in active orders', () async {
      final controller = OrderController();
      final chickenMomos = MenuItem(
        id: 'momo_1',
        name: 'Chicken / Veg Momos',
        price: 120,
        category: const ItemCategory(id: 'cat_momos', name: 'Momos'),
      );
      controller.addMenuItem(chickenMomos);

      // Add Chicken variant
      controller.addCustomizedItemToCart(
        baseItem: chickenMomos,
        resolvedName: 'Chicken',
      );

      expect(controller.cart.length, 1);
      final cartItemId = controller.cart.keys.first;
      final cartItem = controller.findItem(cartItemId);
      expect(cartItem.displayName, 'Chicken');
      expect(cartItem.displayNameWithCategory, 'Chicken (Momos)');
      expect(cartItem.effectiveDietaryType, ItemDietaryType.nonVeg);

      // Place order
      final outcome = await controller.punchOrUpdateOrder(
        customerName: 'Test Customer',
        paymentMethod: 'Cash',
      );
      expect(outcome.token, isNotNull);
      expect(controller.activeOrders.length, 1);

      // Confirm payment so that the order is eligible for combinedActiveOrders
      await controller.confirmPayment(token: outcome.token, paymentMethod: 'Cash');

      final lineItems = controller.getOrderLineItems(controller.activeOrders.first);
      expect(lineItems.length, 1);
      expect(lineItems.first.displayName, 'Chicken (Momos)');
      expect(lineItems.first.effectiveDietaryType, ItemDietaryType.nonVeg);

      // Verify kitchen aggregated summary
      final aggregated = controller.combinedActiveOrders;
      expect(aggregated.length, 1);
      expect(aggregated.first.displayName, 'Chicken (Momos)');
      expect(aggregated.first.effectiveDietaryType, ItemDietaryType.nonVeg);
    });
  });
}
