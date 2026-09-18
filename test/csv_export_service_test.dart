import 'package:flutter_test/flutter_test.dart';
import 'package:counter_app/src/models/counter_log_entry.dart';
import 'package:counter_app/src/models/stall_models.dart';
import 'package:counter_app/src/services/csv_export_service.dart';

void main() {
  group('CsvExportService', () {
    final testDate = DateTime(2026, 6, 10, 15, 45, 30);

    test('generates valid RFC 4180 CSV content with escaping', () {
      final logs = [
        CounterLogEntry(
          id: 'log-1',
          counterId: 'counter-1',
          counterTitle: 'Pushups & Pullups, Day 1',
          counterColorHex: 0xFF2563EB,
          actionType: CounterActionType.increment,
          changeAmount: 5,
          resultingCount: 25,
          timestamp: testDate,
        ),
        CounterLogEntry(
          id: 'log-2',
          counterId: 'counter-2',
          counterTitle: 'Read "Atomic Habits"',
          counterColorHex: 0xFF059669,
          actionType: CounterActionType.reset,
          changeAmount: -20,
          resultingCount: 0,
          timestamp: testDate.add(const Duration(minutes: 10)),
        ),
      ];

      final csv = CsvExportService.generateCsv(logs);

      // Verify Header
      expect(
        csv.contains('ID,Timestamp,Date,Time,Counter Title,Action,Change,Resulting Count'),
        isTrue,
      );

      // Verify escaped quotes and commas in titles
      expect(csv.contains('"Pushups & Pullups, Day 1"'), isTrue);
      expect(csv.contains('"Read ""Atomic Habits"""'), isTrue);

      // Verify actions and changes
      expect(csv.contains('Increment,+5,25'), isTrue);
      expect(csv.contains('Reset,-20,0'), isTrue);
    });

    test('handles empty logs list gracefully', () {
      final csv = CsvExportService.generateCsv([]);
      expect(
        csv.trim(),
        'ID,Timestamp,Date,Time,Counter Title,Action,Change,Resulting Count',
      );
    });

    test('generates orders CSV with payment audit fields', () {
      final orders = [
        StallOrder(
          token: 1,
          itemsSummary: '2x Masala Chai',
          total: 40.0,
          timestamp: testDate,
          isCompleted: false,
          isPaid: false,
          paidAmount: 0.0,
          customerName: 'Aarav',
        ),
        StallOrder(
          token: 2,
          itemsSummary: '1x Veg Samosa, 1x Chai',
          total: 50.0,
          timestamp: testDate.add(const Duration(minutes: 5)),
          isCompleted: true,
          completedAt: testDate.add(const Duration(minutes: 10)),
          isPaid: true,
          paidAmount: 50.0,
          paymentMethod: 'Cash',
          customerName: 'Priya',
        ),
        StallOrder(
          token: 3,
          itemsSummary: '2x Paneer Roll',
          total: 140.0,
          timestamp: testDate.add(const Duration(minutes: 8)),
          isCompleted: false,
          isPaid: false,
          paidAmount: 70.0,
          paymentMethod: 'UPI',
          customerName: 'Rahul',
        ),
      ];

      final csv = CsvExportService.generateOrdersCsv(orders);

      expect(
        csv.contains('Token,Timestamp,Date,Time,Status,Payment Status,Order Type,Items Summary,Order Notes,Total Amount,Paid Amount,Balance Due,Completed At,Customer Name,Payment Method'),
        isTrue,
      );
      // Check Order 1: Unpaid
      expect(csv.contains('#1,'), isTrue);
      expect(csv.contains(',Pending,Unpaid,Dine In,"2x Masala Chai","",40.00,0.00,40.00,'), isTrue);
      // Check Order 2: Paid
      expect(csv.contains('#2,'), isTrue);
      expect(csv.contains(',Completed,Paid,Dine In,"1x Veg Samosa, 1x Chai","",50.00,50.00,0.00,'), isTrue);
      // Check Order 3: Partial
      expect(csv.contains('#3,'), isTrue);
      expect(csv.contains(',Pending,Partial,Dine In,"2x Paneer Roll","",140.00,70.00,70.00,'), isTrue);
    });

    test('generates menu catalog CSV preserving sub-categories with additional prices and category surcharge', () {
      final momosCategory = ItemCategory(
        id: 'cat_momos',
        name: 'Momos',
        additionalCost: 15.0,
        colorHex: 0xFFEA580C,
        options: const [
          CategoryOption(id: 'opt_steam', name: 'Steam', additionalCost: 0.0),
          CategoryOption(id: 'opt_fried', name: 'Fried', additionalCost: 10.0),
          CategoryOption(id: 'opt_pan_fried', name: 'Pan Fried', additionalCost: 20.0),
          CategoryOption(id: 'opt_special', name: 'Special Jhol', price: 120.0),
        ],
        addons: const [
          CategoryOption(id: 'item_extra_dip', name: 'Spicy Dip', additionalCost: 20.0),
        ],
      );

      final vegMomos = MenuItem(
        id: 'item_veg_momos',
        name: 'Veg Momos',
        price: 80.0,
        category: momosCategory,
        dietaryType: ItemDietaryType.veg,
      );

      final standaloneCategory = ItemCategory(
        id: 'cat_drinks',
        name: 'Beverages',
        additionalCost: 5.0,
        colorHex: 0xFF2563EB,
        options: const [
          CategoryOption(id: 'opt_small', name: 'Small', additionalCost: 0.0),
          CategoryOption(id: 'opt_large', name: 'Large', additionalCost: 25.0),
        ],
      );

      final csv = CsvExportService.generateMenuCsv(
        categories: [momosCategory, standaloneCategory],
        items: [vegMomos],
      );

      // Verify header contains all 9 standard columns
      expect(
        csv.contains('name,price,category,dietary_type,is_available,category_color,category_additional_cost,category_variants,addons'),
        isTrue,
      );

      // Verify Veg Momos line with category surcharge 15, category variants, and addons
      expect(
        csv.contains('Veg Momos,80,Momos,veg,true,0xFFEA580C,15,Steam|Fried:+10|Pan Fried:+20|Special Jhol:120,Spicy Dip:+20'),
        isTrue,
      );

      // Verify Standalone Beverages category row
      expect(
        csv.contains(',0.0,Beverages,none,true,0xFF2563EB,5,Small|Large:+25,'),
        isTrue,
      );
    });
  });
}
