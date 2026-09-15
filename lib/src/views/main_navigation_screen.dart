import 'package:flutter/material.dart';
import '../controllers/counter_controller.dart';
import '../storage/app_storage.dart';
import 'home_screen.dart';
import 'stall_pos_screen.dart';
import 'store_management_screen.dart';

/// Main root screen providing bottom navigation between Multi-Counter, Stall POS, and Store Admin.
class MainNavigationScreen extends StatefulWidget {
  final CounterController controller;
  final OrderController? orderController;
  final int initialIndex;
  final List<Widget>? extraActions;

  const MainNavigationScreen({
    super.key,
    required this.controller,
    this.orderController,
    this.initialIndex = 1,
    this.extraActions,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  late final OrderController _orderController;
  late final bool _internalOrderController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    if (widget.orderController != null) {
      _orderController = widget.orderController!;
      _internalOrderController = false;
    } else {
      _orderController = OrderController(
        storage: AppStorage.instance.stallStorage,
      );
      _internalOrderController = true;
      _orderController.loadPersistedData();
    }
  }

  @override
  void dispose() {
    if (_internalOrderController) {
      _orderController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            controller: widget.controller,
            extraActions: widget.extraActions,
          ),
          StallPosScreen(
            controller: _orderController,
            extraActions: widget.extraActions,
          ),
          StoreManagementScreen(
            controller: _orderController,
            showBackButton: false,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (_currentIndex != index) {
            ScaffoldMessenger.of(context).clearSnackBars();
            setState(() {
              _currentIndex = index;
            });
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate_rounded),
            label: 'Counters',
            tooltip: 'Counters',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale_rounded),
            label: 'Stall POS',
            tooltip: 'Stall POS',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings_rounded),
            label: 'Admin',
            tooltip: 'Store Admin',
          ),
        ],
      ),
    );
  }
}
