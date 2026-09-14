import 'package:flutter/material.dart';
import '../../controllers/order_controller.dart';
import '../../data/models/stall_models.dart';
import '../../screens/store_management_screen.dart';

export '../../screens/store_management_screen.dart';

/// Compatibility adapter for StoreManagementDialog forwarding to StoreManagementScreen.
class StoreManagementDialog {
  static Future<void> show(
    BuildContext context, {
    required OrderController controller,
    required Color Function(String category) getCategoryColor,
    required VoidCallback onOpenOrderHistory,
    required VoidCallback onOpenCsvImport,
    required void Function(MenuItem? item) onAddOrEditItem,
    int initialTabIndex = 0,
  }) {
    return StoreManagementScreen.open(
      context,
      controller: controller,
      getCategoryColor: getCategoryColor,
      onOpenOrderHistory: onOpenOrderHistory,
      onOpenCsvImport: onOpenCsvImport,
      onAddOrEditItem: onAddOrEditItem,
      initialTabIndex: initialTabIndex,
    );
  }
}
