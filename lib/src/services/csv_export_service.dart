import 'package:intl/intl.dart';
import '../models/counter_log_entry.dart';
import '../models/stall_models.dart';
import 'csv_download_stub.dart'
    if (dart.library.io) 'csv_download_io.dart'
    if (dart.library.js_interop) 'csv_download_web.dart';

/// Service for formatting and exporting counter activity history, orders,
/// and complete menu catalogs to CSV.
class CsvExportService {
  CsvExportService._();

  /// Converts a list of [CounterLogEntry] into a standard RFC 4180 CSV string.
  static String generateCsv(List<CounterLogEntry> logs) {
    final buffer = StringBuffer();
    buffer.writeln('ID,Timestamp,Date,Time,Counter Title,Action,Change,Resulting Count');

    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('h:mm:ss a');

    for (final log in logs) {
      final safeTitle = '"${log.counterTitle.replaceAll('"', '""')}"';
      final changeStr = log.changeAmount >= 0 ? '+${log.changeAmount}' : '${log.changeAmount}';
      buffer.writeln(
        '${log.id},'
        '${log.timestamp.toIso8601String()},'
        '${dateFormat.format(log.timestamp)},'
        '${timeFormat.format(log.timestamp)},'
        '$safeTitle,'
        '${log.actionType.label},'
        '$changeStr,'
        '${log.resultingCount}',
      );
    }
    return buffer.toString();
  }

  /// Generates the CSV and triggers a platform-appropriate download or share action.
  static Future<void> exportHistoryCsv({
    required List<CounterLogEntry> logs,
    String? counterTitle,
  }) async {
    if (logs.isEmpty) return;

    final csvContent = generateCsv(logs);
    final nowStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final prefix = counterTitle != null && counterTitle.trim().isNotEmpty
        ? counterTitle.trim().replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_').toLowerCase()
        : 'counter_activity';
    final filename = '${prefix}_$nowStr.csv';

    await saveOrShareCsv(
      csvContent: csvContent,
      filename: filename,
    );
  }

  /// Converts a list of [StallOrder] into a standard RFC 4180 CSV string.
  static String generateOrdersCsv(List<StallOrder> orders) {
    final buffer = StringBuffer();
    buffer.writeln('Token,Timestamp,Date,Time,Status,Payment Status,Order Type,Items Summary,Order Notes,Total Amount,Paid Amount,Balance Due,Completed At,Customer Name,Payment Method');

    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('h:mm:ss a');

    for (final order in orders) {
      final safeSummary = '"${order.itemsSummary.replaceAll('"', '""')}"';
      final safeNotes = '"${(order.orderNotes ?? '').replaceAll('"', '""')}"';
      final status = order.isCompleted ? 'Completed' : 'Pending';
      final paymentStatus = order.isFullyPaid
          ? 'Paid'
          : (order.hasPartialPayment || order.paidAmount > 0 ? 'Partial' : 'Unpaid');
      final completedStr = order.completedAt != null
          ? order.completedAt!.toIso8601String()
          : '';
      final safeCustomer = '"${order.displayCustomerName.replaceAll('"', '""')}"';
      final safePayment = '"${(order.paymentMethod ?? 'UPI').replaceAll('"', '""')}"';

      buffer.writeln(
        '#${order.token},'
        '${order.timestamp.toIso8601String()},'
        '${dateFormat.format(order.timestamp)},'
        '${timeFormat.format(order.timestamp)},'
        '$status,'
        '$paymentStatus,'
        '${order.orderTypeLabel},'
        '$safeSummary,'
        '$safeNotes,'
        '${order.total.toStringAsFixed(2)},'
        '${order.paidAmount.toStringAsFixed(2)},'
        '${order.remainingDue.toStringAsFixed(2)},'
        '$completedStr,'
        '$safeCustomer,'
        '$safePayment',
      );
    }
    return buffer.toString();
  }

  /// Generates the orders CSV and triggers platform-appropriate download or share action.
  static Future<void> exportOrdersCsv({
    required List<StallOrder> orders,
  }) async {
    if (orders.isEmpty) return;

    final csvContent = generateOrdersCsv(orders);
    final nowStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = 'stall_orders_$nowStr.csv';

    await saveOrShareCsv(
      csvContent: csvContent,
      filename: filename,
    );
  }

  /// Generates a standardized Menu & Catalog CSV matching CsvImportService format.
  ///
  /// Output columns:
  /// `name,price,category,dietary_type,is_available,category_color,category_additional_cost,category_variants,addons`
  static String generateMenuCsv({
    required List<ItemCategory> categories,
    required List<MenuItem> items,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      'name,price,category,dietary_type,is_available,category_color,category_additional_cost,category_variants,addons',
    );

    // Index categories by name for fast lookup
    final catMap = <String, ItemCategory>{
      for (final c in categories) c.name.toLowerCase().trim(): c,
    };

    final exportedCategories = <String>{};

    for (final item in items) {
      final catName = item.categoryName;
      final effectiveCategory = catMap[catName.toLowerCase().trim()] ?? item.category;
      exportedCategories.add(effectiveCategory.name.toLowerCase().trim());

      final safeName = _escapeCsv(item.name);
      final priceStr = item.price.toStringAsFixed(
        item.price.truncateToDouble() == item.price ? 0 : 2,
      );
      final safeCategory = _escapeCsv(effectiveCategory.name);
      final dietaryStr = item.dietaryType?.code ??
          (item.effectiveDietaryType != ItemDietaryType.none
              ? item.effectiveDietaryType.code
              : 'none');
      final isAvailableStr = item.isAvailable.toString();
      final effectiveColorHex = effectiveCategory.colorHex ?? item.colorHex;
      final colorStr = effectiveColorHex != null
          ? '0x${effectiveColorHex.toRadixString(16).padLeft(8, '0').toUpperCase()}'
          : '';
      final effectiveAddCost = effectiveCategory.additionalCost > 0
          ? effectiveCategory.additionalCost
          : item.category.additionalCost;
      final addCostStr = effectiveAddCost > 0
          ? effectiveAddCost.toStringAsFixed(
              effectiveAddCost.truncateToDouble() == effectiveAddCost ? 0 : 2,
            )
          : '0.0';

      // Export sub-categories / options with their additional prices or prices
      final List<CategoryOption> optionsToExport;
      if (effectiveCategory.options.isNotEmpty) {
        optionsToExport = effectiveCategory.options;
      } else if (item.category.options.isNotEmpty) {
        optionsToExport = item.category.options;
      } else {
        optionsToExport = item.variants;
      }
      final variantsStr = _escapeCsv(CategoryOption.formatVariants(optionsToExport));
      final List<CategoryOption> addonsToExport = effectiveCategory.addons.isNotEmpty
          ? effectiveCategory.addons
          : item.category.addons;
      final addonsStr = _escapeCsv(CategoryOption.formatVariants(addonsToExport));

      buffer.writeln(
        '$safeName,$priceStr,$safeCategory,$dietaryStr,$isAvailableStr,$colorStr,$addCostStr,$variantsStr,$addonsStr',
      );
    }

    // Export any categories that don't have associated menu items
    for (final category in categories) {
      if (!exportedCategories.contains(category.name.toLowerCase().trim())) {
        final safeCategory = _escapeCsv(category.name);
        final colorStr = category.colorHex != null
            ? '0x${category.colorHex!.toRadixString(16).padLeft(8, '0').toUpperCase()}'
            : '';
        final addCostStr = category.additionalCost > 0
            ? category.additionalCost.toStringAsFixed(
                category.additionalCost.truncateToDouble() == category.additionalCost
                    ? 0
                    : 2,
              )
            : '0.0';
        final variantsStr = _escapeCsv(CategoryOption.formatVariants(category.options));
        final addonsStr = _escapeCsv(CategoryOption.formatVariants(category.addons));
        buffer.writeln(',0.0,$safeCategory,none,true,$colorStr,$addCostStr,$variantsStr,$addonsStr');
      }
    }

    return buffer.toString();
  }


  /// Exports stored categories and menu items to CSV format and prompts download/share.
  static Future<void> exportMenuCatalog({
    required List<ItemCategory> categories,
    required List<MenuItem> items,
    String filename = 'menu_catalog.csv',
  }) async {
    final csvContent = generateMenuCsv(categories: categories, items: items);
    await downloadCsv(csvContent, filename);
  }

  static String _escapeCsv(String val) {
    if (val.contains(',') || val.contains('"') || val.contains('\n') || val.contains('\r')) {
      return '"${val.replaceAll('"', '""')}"';
    }
    return val;
  }
}
