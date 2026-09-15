import 'package:flutter/material.dart';
import '../controllers/order_controller.dart';
import '../controllers/theme_controller.dart';
import '../storage/stall_storage.dart';
import '../storage/app_storage.dart';
import 'stall_pos_view.dart';

export 'stall_pos_view.dart';
export '../controllers/order_controller.dart';
export '../models/stall_models.dart';
export '../storage/stall_storage.dart';

/// Full-screen Scaffold wrapper for [StallPosView].
class StallPosScreen extends StatefulWidget {
  final StallStorage? storageService;
  final StallStorage? storage;
  final OrderController? controller;
  final List<Widget>? extraActions;

  const StallPosScreen({
    super.key,
    this.storageService,
    this.storage,
    this.controller,
    this.extraActions,
  });

  @override
  State<StallPosScreen> createState() => _StallPosScreenState();
}

class _StallPosScreenState extends State<StallPosScreen> {
  late final OrderController _controller;
  late final bool _internalController;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _internalController = false;
    } else {
      _controller = OrderController(
        storage: widget.storage ?? widget.storageService ?? AppStorage.instance.stallStorage,
      );
      _internalController = true;
      _controller.loadPersistedData();
    }
    _controller.addListener(_onControllerChanged);
  }


  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_internalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final totalRevenue = _controller.orders.fold<double>(
      0,
      (sum, o) => sum + o.total,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '⚡ StallPOS',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (MediaQuery.of(context).size.width >= 420)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(
                child: Text(
                  'Orders: ${_controller.orders.length} | ₹${totalRevenue.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          if (widget.extraActions != null) ...widget.extraActions!,
          ListenableBuilder(
            listenable: ThemeController.instance,
            builder: (context, _) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                ),
                tooltip: isDark
                    ? 'Switch to Light Theme'
                    : 'Switch to Dark Theme',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => ThemeController.instance.toggleTheme(),
              );
            },
          ),
        ],
      ),
      body: StallPosView(
        controller: _controller,
        storage: widget.storage ?? widget.storageService,
        extraActions: widget.extraActions,
      ),
    );
  }
}
