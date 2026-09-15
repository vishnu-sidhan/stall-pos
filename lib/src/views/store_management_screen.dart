import 'package:flutter/material.dart';
import '../controllers/order_controller.dart';
import '../models/stall_models.dart';
import 'store_management_view.dart';

/// Centralized Store Management Studio Screen (Admin Page).
///
/// Wraps [StoreManagementView] in a [Scaffold] with a header [AppBar].
class StoreManagementScreen extends StatelessWidget {
  final OrderController controller;
  final Color Function(String category)? getCategoryColor;
  final VoidCallback? onOpenOrderHistory;
  final VoidCallback? onOpenCsvImport;
  final VoidCallback? onExportCsv;
  final void Function(MenuItem? item)? onAddOrEditItem;
  final int initialTabIndex;
  final bool? showBackButton;

  const StoreManagementScreen({
    super.key,
    required this.controller,
    this.getCategoryColor,
    this.onOpenOrderHistory,
    this.onOpenCsvImport,
    this.onExportCsv,
    this.onAddOrEditItem,
    this.initialTabIndex = 0,
    this.showBackButton,
  });

  static Future<void> open(
    BuildContext context, {
    required OrderController controller,
    Color Function(String category)? getCategoryColor,
    VoidCallback? onOpenOrderHistory,
    VoidCallback? onOpenCsvImport,
    VoidCallback? onExportCsv,
    void Function(MenuItem? item)? onAddOrEditItem,
    int initialTabIndex = 0,
    bool? showBackButton,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => StoreManagementScreen(
          controller: controller,
          getCategoryColor: getCategoryColor,
          onOpenOrderHistory: onOpenOrderHistory,
          onOpenCsvImport: onOpenCsvImport,
          onExportCsv: onExportCsv,
          onAddOrEditItem: onAddOrEditItem,
          initialTabIndex: initialTabIndex,
          showBackButton: showBackButton,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = Navigator.of(context).canPop();
    final shouldShowBack = showBackButton ?? canPop;

    return Scaffold(
      appBar: AppBar(
        leading: shouldShowBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back to POS',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.admin_panel_settings_rounded,
                color: theme.colorScheme.onPrimaryContainer,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Store Management Studio',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Catalog, Surcharges & History',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
      body: StoreManagementView(
        controller: controller,
        getCategoryColor: getCategoryColor,
        onOpenOrderHistory: onOpenOrderHistory,
        onOpenCsvImport: onOpenCsvImport,
        onExportCsv: onExportCsv,
        onAddOrEditItem: onAddOrEditItem,
        initialTabIndex: initialTabIndex,
      ),
    );
  }
}
