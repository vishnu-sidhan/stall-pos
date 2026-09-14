import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:counter_app/data/models/counter_model.dart';
import 'package:counter_app/data/models/stall_models.dart';

void main() {
  group('Domain Model Contracts & Inheritance Tests', () {
    test('MenuItem conforms to CatalogItem, DietaryAware, ColorThemed, IdentifiableEntity', () {
      const item = MenuItem(
        id: 'item_veg_momo',
        name: 'Veg Steam Momo',
        price: 90.0,
        category: ItemCategory(id: 'cat_momos', name: 'Momos'),
        variants: [
          CategoryOption(id: 'opt_steam', name: 'Steam'),
          CategoryOption(id: 'opt_fried', name: 'Fried', additionalCost: 10.0),
        ],
      );

      // Verify polymorphism
      expect(item, isA<CatalogItem>());
      expect(item, isA<IdentifiableEntity>());
      expect(item, isA<DietaryAware>());
      expect(item, isA<ColorThemed>());

      // IdentifiableEntity
      expect(item.id, equals('item_veg_momo'));
      expect(item.displayName, equals('Veg Steam Momo'));

      // CatalogItem
      expect(item.price, equals(90.0));
      expect(item.isAvailable, isTrue);

      // DietaryAware - automatic inference without repeating logic
      expect(item.effectiveDietaryType, equals(ItemDietaryType.veg));

      // ColorThemed - dynamic palette resolution
      expect(item.resolvedColorHex, isNotNull);
      expect(item.color, isA<Color>());
    });

    test('CategoryOption conforms to DietaryAware and IdentifiableEntity', () {
      const option = CategoryOption(
        id: 'opt_chicken_gravy',
        name: 'Chicken Gravy',
        additionalCost: 30.0,
      );

      expect(option, isA<IdentifiableEntity>());
      expect(option, isA<DietaryAware>());

      expect(option.id, equals('opt_chicken_gravy'));
      expect(option.displayName, equals('Chicken Gravy'));
      // Inferred dietary classification from name
      expect(option.effectiveDietaryType, equals(ItemDietaryType.nonVeg));
    });

    test('ItemCategory conforms to ColorThemed and IdentifiableEntity', () {
      const category = ItemCategory(
        id: 'cat_drinks',
        name: 'Cold Drinks',
        colorHex: 0xFF0284C7,
      );

      expect(category, isA<IdentifiableEntity>());
      expect(category, isA<ColorThemed>());

      expect(category.id, equals('cat_drinks'));
      expect(category.displayName, equals('Cold Drinks'));
      expect(category.colorHex, equals(0xFF0284C7));
      expect(category.resolvedColorHex, equals(0xFF0284C7));
      expect(category.color, equals(const Color(0xFF0284C7)));
    });

    test('OrderLineItem conforms to PreparationItem, DietaryAware, and ColorThemed', () {
      const lineItem = OrderLineItem(
        itemId: 'item_egg_roll',
        name: 'Double Egg Roll',
        displayName: 'Double Egg Roll',
        category: 'Rolls',
        quantity: 2,
        completedQuantity: 1,
        colorHex: 0xFFF57C00,
      );

      expect(lineItem, isA<PreparationItem>());
      expect(lineItem, isA<IdentifiableEntity>());
      expect(lineItem, isA<DietaryAware>());
      expect(lineItem, isA<ColorThemed>());

      expect(lineItem.id, equals('item_egg_roll'));
      expect(lineItem.displayName, equals('Double Egg Roll'));
      expect(lineItem.effectiveDietaryType, equals(ItemDietaryType.egg));
      expect(lineItem.pendingQuantity, equals(1));
      expect(lineItem.isFullyCompleted, isFalse);
    });

    test('AggregatedOrderItem typed record has structured kitchen prep fields', () {
      const AggregatedOrderItem aggItem = (
        itemId: 'item_paneer_tikka',
        itemName: 'Paneer Tikka',
        displayName: 'Paneer Tikka',
        category: 'Tandoor',
        totalQuantity: 5,
        tickets: [
          (token: 101, quantity: 2, isParcel: false, orderNotes: null),
          (token: 103, quantity: 3, isParcel: true, orderNotes: 'Less Spicy'),
        ],
        colorHex: null,
        effectiveDietaryType: ItemDietaryType.veg,
      );

      expect(aggItem.itemId, equals('item_paneer_tikka'));
      expect(aggItem.displayName, equals('Paneer Tikka'));
      expect(aggItem.effectiveDietaryType, equals(ItemDietaryType.veg));
      expect(aggItem.totalQuantity, equals(5));
      expect(aggItem.tickets.length, equals(2));
      expect(aggItem.tickets.first.token, equals(101));
      expect(aggItem.tickets.last.isParcel, isTrue);
    });

    test('CounterModel conforms to IdentifiableEntity and ColorThemed', () {
      final counter = CounterModel(
        id: 'counter_gym',
        title: 'Push-ups',
        count: 25,
        target: 50,
        colorHex: 0xFF1D4ED8,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(counter, isA<IdentifiableEntity>());
      expect(counter, isA<ColorThemed>());

      expect(counter.id, equals('counter_gym'));
      expect(counter.displayName, equals('Push-ups'));
      expect(counter.resolvedColorHex, equals(0xFF1D4ED8));
      expect(counter.color, equals(const Color(0xFF1D4ED8)));
      expect(counter.progress, equals(0.5));
    });

    test('Polymorphic handling of heterogeneous items using DietaryAware and ColorThemed', () {
      const items = <DietaryAware>[
        MenuItem(
          id: '1',
          name: 'Chicken Momos',
          price: 120,
        ),
        CategoryOption(
          id: '2',
          name: 'Fried Paneer',
        ),
        OrderLineItem(
          itemId: '3',
          name: 'Egg Curry',
          displayName: 'Egg Curry',
          category: 'Curries',
          quantity: 1,
        ),
      ];

      final classifications = items.map((i) => i.effectiveDietaryType).toList();
      expect(classifications, [
        ItemDietaryType.nonVeg,
        ItemDietaryType.veg,
        ItemDietaryType.egg,
      ]);
    });
  });
}
