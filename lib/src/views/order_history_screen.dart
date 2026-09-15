import 'package:flutter/material.dart';
import '../controllers/order_controller.dart';
import '../storage/stall_storage.dart';
import 'order_history_view.dart';

export 'order_history_view.dart' show OrderHistoryFilter, OrderDateRangeFilter;

/// Scaffold wrapper screen for [OrderHistoryView].
class OrderHistoryScreen extends StatelessWidget {
  final StallStorage? storageService;
  final StallStorage? storage;
  final OrderController? controller;
  final VoidCallback? onOrdersChanged;

  const OrderHistoryScreen({
    super.key,
    this.storageService,
    this.storage,
    this.controller,
    this.onOrdersChanged,
  }) : assert(storageService != null || storage != null || controller != null);

  @override
  Widget build(BuildContext context) {
    return OrderHistoryView(
      storage: storage ?? storageService,
      storageService: storageService ?? storage,
      controller: controller,
      onOrdersChanged: onOrdersChanged,
      wrapInScaffold: true,
    );
  }
}
