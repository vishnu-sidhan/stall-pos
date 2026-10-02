import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/src/controllers/order_controller.dart';
import 'package:counter_app/src/models/stall_models.dart';
import 'package:counter_app/src/storage/stall_storage_service.dart';

void main() {
  group('Variant and Add-on Pricing Integrity Tests', () {
    late StallStorageService storageService;
    late OrderController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storageService = StallStorageService();
      controller = OrderController(storage: storageService);
    });

    test('Momos with single available variant and add-ons maintains ₹200 across reloads', () async {
      // 1. Setup Momos category with variants: Steam, Fried, Kurkure
      // and addon: Extra Piece Momo (+25)
      const momoCat = ItemCategory(
        id: 'cat_momos',
        name: 'Momos',
        options: [
          CategoryOption(id: 'opt_steam', name: 'Steam', additionalCost: 0.0),
          CategoryOption(id: 'opt_fried', name: 'Fried', additionalCost: 10.0),
          CategoryOption(id: 'opt_kurkure', name: 'Kurkure', additionalCost: 30.0),
        ],
        addons: [
          CategoryOption(id: 'addon_extra_piece', name: 'Extra Piece Momo', additionalCost: 25.0),
        ],
      );
      await controller.saveCategoryConfig(momoCat);

      const momoItem = MenuItem(
        id: 'item_veg_momos',
        name: 'Veg Momos',
        price: 150.0,
        category: ItemCategory(id: 'cat_momos', name: 'Momos'),
      );
      await controller.addMenuItem(momoItem);

      // 2. Mark Fried and Kurkure unavailable, leaving only Steam
      await controller.toggleCategoryVariantAvailability('Momos', 'Fried', isAvailable: false);
      await controller.toggleCategoryVariantAvailability('Momos', 'Kurkure', isAvailable: false);

      final hydrated = controller.hydrateMenuItemCategory(momoItem);
      final steamVariant = hydrated.effectiveVariants.firstWhere((v) => v.name == 'Steam');
      final extraAddon = hydrated.effectiveAddons.firstWhere((a) => a.id == 'addon_extra_piece');

      // 3. Add to cart: 1x Veg Steam (150) + 2x Extra Piece Momo (2 * 25 = 50) -> total 200
      controller.addCustomizedItemToCart(
        baseItem: hydrated,
        selectedVariant: steamVariant,
        selectedAddons: [extraAddon, extraAddon],
        quantity: 1,
      );

      expect(controller.cartTotal, equals(200.0));

      // 4. Punch order
      final outcome = await controller.punchOrUpdateOrder(
        isPaid: true,
        paidAmount: controller.cartTotal,
        paymentMethod: 'Cash',
      );

      final placedOrder = controller.orders.firstWhere((o) => o.token == outcome.token);
      expect(placedOrder.total, equals(200.0));
      expect(placedOrder.items.first.price, equals(150.0));
      expect(placedOrder.items.first.unitPrice, equals(200.0));

      // 5. Reload persisted data (simulates opening Store Management / History tab)
      await controller.loadPersistedData();

      final reloadedOrder = controller.orders.firstWhere((o) => o.token == outcome.token);
      expect(reloadedOrder.total, equals(200.0), reason: 'Order total must not jump to 250 after reload');
      expect(reloadedOrder.items.first.price, equals(150.0));
      expect(reloadedOrder.items.first.unitPrice, equals(200.0));
    });
  });
}
