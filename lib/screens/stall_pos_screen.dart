import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/order_controller.dart';
import '../controllers/theme_controller.dart';
import '../data/models/stall_models.dart';
import '../widgets/csv_import_dialog.dart';
import '../widgets/payment_confirmation_dialog.dart';
import '../widgets/stall_pos/stall_pos_widgets.dart';
import 'order_history_screen.dart';

// Re-export models and controller for backwards compatibility
import '../data/storage/stall_storage.dart';
export '../controllers/order_controller.dart';
export '../data/models/stall_models.dart';
export '../data/storage/stall_storage.dart';

class StallPosScreen extends StatefulWidget {
  final StallStorage? storageService;
  final OrderController? controller;
  final List<Widget>? extraActions;

  const StallPosScreen({
    super.key,
    this.storageService,
    this.controller,
    this.extraActions,
  });

  @override
  State<StallPosScreen> createState() => _StallPosScreenState();
}

class _StallPosScreenState extends State<StallPosScreen>
    with TickerProviderStateMixin {
  late final OrderController _controller;
  late final bool _internalController;
  late TabController _mobileTabController;
  late TabController _desktopTabController;
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _orderNotesController = TextEditingController();
  bool _isParcel = false;
  final Set<String> _collapsedCategories = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _internalController = false;
    } else {
      _controller = OrderController(
        storageService: widget.storageService,
      );
      _internalController = true;
      _controller.loadPersistedData();
    }
    _controller.addListener(_onControllerChanged);

    _mobileTabController = TabController(length: 3, vsync: this);
    _desktopTabController = TabController(length: 2, vsync: this);
    _mobileTabController.addListener(_onTabChanged);
    _desktopTabController.addListener(_onTabChanged);
  }

  int _lastMobileTabIndex = 0;
  int _lastDesktopTabIndex = 0;

  void _onTabChanged() {
    if (_mobileTabController.index != _lastMobileTabIndex) {
      _lastMobileTabIndex = _mobileTabController.index;
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    }
    if (_desktopTabController.index != _lastDesktopTabIndex) {
      _lastDesktopTabIndex = _desktopTabController.index;
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_internalController) {
      _controller.dispose();
    }
    _mobileTabController.removeListener(_onTabChanged);
    _desktopTabController.removeListener(_onTabChanged);
    _mobileTabController.dispose();
    _desktopTabController.dispose();
    _customerNameController.dispose();
    _orderNotesController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // CATEGORIES & COLORS
  // ---------------------------------------------------------------------------

  List<String> get _categories => _controller.categories;
  List<MenuItem> get _menu => _controller.menu;

  Map<String, int> get _resolvedCategoryColors => _controller.resolvedCategoryColors;

  Color _getCategoryColor(String category) {
    return _controller.getCategoryColor(
      category,
      defaultColor: Theme.of(context).colorScheme.primary,
    );
  }

  // ---------------------------------------------------------------------------
  // CART & MENU ITEM ACTIONS
  // ---------------------------------------------------------------------------

  void _addToCart(MenuItem item) {
    HapticFeedback.selectionClick();
    _controller.addToCart(item);
  }

  void _handleMenuItemTap(MenuItem item) {
    HapticFeedback.selectionClick();

    // 1. Check if item is an Add-on
    if (item.effectiveIsAddon) {
      final baseItems = _controller.cartBaseItems;
      if (baseItems.isEmpty) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Add-ons must be linked to an item. Please add a main item first.',
            ),
            backgroundColor: Colors.deepOrange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final matchingCategoryItems = baseItems
          .where((b) => item.isApplicableToCategory(b.categoryName))
          .toList();

      if (matchingCategoryItems.isEmpty) {
        final targetCatName = item.linkedCategory?.isNotEmpty == true
            ? item.linkedCategory!
            : item.categoryName;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Add-on [${item.name}] can only be added to "$targetCatName" items. Please add one first.',
            ),
            backgroundColor: Colors.deepOrange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      final eligibleBaseItems = matchingCategoryItems.where((b) {
        if (item.hasSlashNameVariants) {
          return item.slashNameVariants.any((v) =>
              _controller.getAddonItemCount(b.id, item.id, resolvedAddonName: v) <
              OrderController.maxPerAddonItem);
        }
        return _controller.getAddonItemCount(b.id, item.id) <
            OrderController.maxPerAddonItem;
      }).toList();

      if (eligibleBaseItems.isEmpty) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Maximum 2 [${item.name}] already added to items in cart.',
            ),
            backgroundColor: Colors.deepOrange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      // If addon has slash variants (e.g. Cheese / Mayo) OR multiple eligible base items in cart
      if (item.hasAnySlashVariants || eligibleBaseItems.length > 1) {
        _showCentralizedSlashSelectionModal(item);
        return;
      }

      // Single eligible base item & no slash in addon
      final target = eligibleBaseItems.first;
      _controller.addAddonToCart(
        targetCartItemId: target.id,
        addon: item,
      );
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added [${item.name}] to ${target.displayName}'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Check if item or all variants are available today
    if (!item.isEffectivelyAvailable) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item.hasVariants
                ? 'All variants of [${item.name}] are currently sold out.'
                : '[${item.name}] is currently sold out today.',
          ),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 2. Check if item has explicit variants or configured category options
    if (item.variants.isNotEmpty || item.category.options.isNotEmpty) {
      ItemCustomizerSheet.show(
        context,
        item: item,
        controller: _controller,
        getCategoryColor: _getCategoryColor,
      );
      return;
    }

    // 3. Check if item has '/' variants in name or category (e.g. Rice / Noodles or Fried Rice / Hakka Noodles)
    if (item.hasAnySlashVariants) {
      _showCentralizedSlashSelectionModal(item);
      return;
    }

    // 4. Regular item
    _addToCart(item);
  }

  void _showCentralizedSlashSelectionModal(MenuItem item) {
    SlashSelectionModal.show(
      context,
      item: item,
      controller: _controller,
      getCategoryColor: _getCategoryColor,
    );
  }

  void _showCartBottomSheet() {
    CartBottomSheet.show(
      context,
      controller: _controller,
      getCategoryColor: _getCategoryColor,
      onCheckout: () => _fireOrder(),
      onClearCart: _clearCart,
      onPayAndPunch: () => _fireOrder(immediatePayment: true),
      customerNameController: _customerNameController,
      orderNotesController: _orderNotesController,
      isParcel: _isParcel,
      onParcelChanged: (val) => setState(() => _isParcel = val),
      onAddPredefinedNote: _showAddPredefinedNoteDialog,
    );
  }

  void _clearCart() {
    _controller.clearCart();
    _customerNameController.clear();
    _orderNotesController.clear();
    setState(() {
      _isParcel = false;
    });
  }

  void _cancelEdit() {
    _controller.cancelEditing();
    _customerNameController.clear();
    _orderNotesController.clear();
    setState(() {
      _isParcel = false;
    });
  }

  void _showCustomNoteDialog() {
    final noteController = TextEditingController(text: _orderNotesController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notes_rounded),
            SizedBox(width: 8),
            Text('Order Notes'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add instructions or special requests for this order:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'e.g. Less spicy, pack separately...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (val) {
                _orderNotesController.text = val.trim();
                setState(() {});
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
        actions: [
          if (_orderNotesController.text.isNotEmpty)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () {
                _orderNotesController.clear();
                setState(() {});
                Navigator.pop(ctx);
              },
              child: const Text('Clear Note'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _orderNotesController.text = noteController.text.trim();
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showAddPredefinedNoteDialog() {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.playlist_add_rounded),
            SizedBox(width: 8),
            Text('New Predefined Note'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add a quick note that will appear in suggestion chips for fast checkout:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'e.g. Extra Chutney, No Sugar',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (val) {
                final text = val.trim();
                if (text.isNotEmpty) {
                  _controller.addPredefinedNote(text);
                  _appendQuickNote(text);
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = noteController.text.trim();
              if (text.isNotEmpty) {
                _controller.addPredefinedNote(text);
                _appendQuickNote(text);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save & Apply'),
          ),
        ],
      ),
    );
  }

  void _showDeletePredefinedNoteDialog(String note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Quick Note?'),
        content: Text('Do you want to remove "$note" from predefined quick notes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              _controller.removePredefinedNote(note);
              Navigator.pop(ctx);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _appendQuickNote(String note) {
    final current = _orderNotesController.text.trim();
    if (current.isEmpty) {
      _orderNotesController.text = note;
    } else {
      final parts = current.split(',').map((s) => s.trim()).toList();
      if (!parts.any((s) => s.toLowerCase() == note.toLowerCase())) {
        _orderNotesController.text = '$current, $note';
      }
    }
    setState(() {});
  }

  void _toggleQuickNote(String note) {
    final current = _orderNotesController.text.trim();
    final parts = current.isEmpty
        ? <String>[]
        : current.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final exists = parts.any((s) => s.toLowerCase() == note.toLowerCase());
    if (exists) {
      parts.removeWhere((s) => s.toLowerCase() == note.toLowerCase());
      _orderNotesController.text = parts.join(', ');
    } else {
      parts.add(note);
      _orderNotesController.text = parts.join(', ');
    }
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // ORDER ACTIONS: FIRE / UPDATE, EDIT, DELETE, COMPLETE
  // ---------------------------------------------------------------------------

  Future<void> _fireOrder({
    bool immediatePayment = false,
    String? directPaymentMethod,
  }) async {
    if (_controller.cart.isEmpty) return;

    final isEdit = _controller.isEditing;
    final custName = _customerNameController.text.trim();
    final orderNotes = _orderNotesController.text.trim().isNotEmpty
        ? _orderNotesController.text.trim()
        : null;
    final isParcel = _isParcel;

    HapticFeedback.heavyImpact();

    // Fast 1-Tap Checkout without dialog!
    if (!isEdit && directPaymentMethod != null) {
      final total = _controller.cartTotal;
      final outcome = await _controller.punchOrUpdateOrder(
        customerName: custName.isNotEmpty ? custName : null,
        isPaid: true,
        paidAmount: total,
        paidItems: Map.from(_controller.cart),
        paymentMethod: directPaymentMethod,
        isParcel: isParcel,
        orderNotes: orderNotes,
      );
      _customerNameController.clear();
      _orderNotesController.clear();
      setState(() => _isParcel = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order #${outcome.token} paid via $directPaymentMethod and placed!',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // 1-Step Immediate Checkout flow on POS register
    if (!isEdit && immediatePayment) {
      final token = _controller.nextToken;
      final total = _controller.cartTotal;
      final result = await PaymentConfirmationDialog.show(
        context,
        orderNumber: token,
        isEditing: false,
        totalDue: total,
        customerName: custName.isNotEmpty ? custName : 'Walk-in Customer',
        newTotal: total,
      );

      if (result == null) {
        // Cashier dismissed payment dialog: return without punching
        return;
      }

      if (result.isMarkAsPending) {
        // Cashier chose to keep pending / pay later
        final outcome = await _controller.punchOrUpdateOrder(
          customerName: custName.isNotEmpty ? custName : null,
          isPaid: false,
          isParcel: isParcel,
          orderNotes: orderNotes,
        );
        _customerNameController.clear();
        _orderNotesController.clear();
        setState(() => _isParcel = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order #${outcome.token} placed! Payment pending.'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Payment completed in 1-step!
      final outcome = await _controller.punchOrUpdateOrder(
        customerName: custName.isNotEmpty ? custName : null,
        isPaid: true,
        paidAmount: total,
        paidItems: Map.from(_controller.cart),
        paymentMethod: result.paymentMethod,
        isParcel: isParcel,
        orderNotes: orderNotes,
      );
      _customerNameController.clear();
      _orderNotesController.clear();
      setState(() => _isParcel = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order #${outcome.token} paid via ${result.paymentMethod} and dispatched!',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (isEdit) {
      final editToken = _controller.editingOrderId!;
      final existingOrder = _controller.orders.firstWhere(
        (o) => o.token == editToken,
      );
      final wasPaid = existingOrder.isPaid || existingOrder.paidAmount > 0;
      final prevPaid = existingOrder.paidAmount > 0
          ? existingOrder.paidAmount
          : (existingOrder.isPaid ? existingOrder.total : 0.0);
      final currentCartTotal = _controller.cartTotal;
      final additionalDue = currentCartTotal - prevPaid;

      if (wasPaid && additionalDue > 0) {
        // Prompt cashier to collect additional payment for the added items!
        final result = await PaymentConfirmationDialog.show(
          context,
          orderNumber: editToken,
          isEditing: true,
          totalDue: additionalDue,
          customerName: custName.isNotEmpty
              ? custName
              : existingOrder.displayCustomerName,
          previousPaid: prevPaid,
          newTotal: currentCartTotal,
        );

        if (result == null) {
          // Cashier tapped "Back to Cart" - abort update and keep cart open
          return;
        }

        if (result.isMarkAsPending) {
          // Pay later / keep pending: order is updated, but additional due is unpaid!
          await _controller.punchOrUpdateOrder(
            customerName: custName.isNotEmpty ? custName : null,
            isPaid: false,
            paidAmount: prevPaid,
            paidItems: existingOrder.paidItems.isNotEmpty
                ? existingOrder.paidItems
                : existingOrder.items,
            isParcel: isParcel,
            orderNotes: orderNotes,
          );
          _customerNameController.clear();
          _orderNotesController.clear();
          setState(() => _isParcel = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Order #$editToken updated! Additional ₹${additionalDue.toStringAsFixed(0)} pending.',
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        } else {
          // Additional payment confirmed via selected payment method
          await _controller.punchOrUpdateOrder(
            customerName: custName.isNotEmpty ? custName : null,
            isPaid: true,
            paidAmount: currentCartTotal,
            paidItems: Map.from(_controller.cart),
            paymentMethod: result.paymentMethod,
            isParcel: isParcel,
            orderNotes: orderNotes,
          );
          _customerNameController.clear();
          _orderNotesController.clear();
          setState(() => _isParcel = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Order #$editToken updated! Additional ₹${additionalDue.toStringAsFixed(0)} paid via ${result.paymentMethod}!',
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      } else if (wasPaid && additionalDue < 0) {
        // Items were removed: refund difference to customer
        await _controller.punchOrUpdateOrder(
          customerName: custName.isNotEmpty ? custName : null,
          isPaid: true,
          paidAmount: currentCartTotal,
          paidItems: Map.from(_controller.cart),
          isParcel: isParcel,
          orderNotes: orderNotes,
        );
        _customerNameController.clear();
        _orderNotesController.clear();
        setState(() => _isParcel = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Order #$editToken updated! Refund ₹${(-additionalDue).toStringAsFixed(0)} to customer.',
              ),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    final outcome = await _controller.punchOrUpdateOrder(
      customerName: custName.isNotEmpty ? custName : null,
      isPaid: isEdit ? null : false,
      isParcel: isParcel,
      orderNotes: orderNotes,
    );

    _customerNameController.clear();
    _orderNotesController.clear();
    setState(() => _isParcel = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            outcome.isEdit
                ? 'Order #${outcome.token} updated!'
                : 'Order #${outcome.token} placed! Payment pending.',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showConfirmPaymentDialog(StallOrder order) async {
    final due = order.hasPartialPayment ? order.remainingDue : order.total;
    final result = await PaymentConfirmationDialog.show(
      context,
      orderNumber: order.token,
      isEditing: false,
      totalDue: due,
      customerName: order.displayCustomerName,
      previousPaid: order.hasPartialPayment ? order.paidAmount : null,
      newTotal: order.total,
    );

    if (result == null || result.isMarkAsPending) return;

    await _controller.confirmPayment(
      token: order.token,
      paymentMethod: result.paymentMethod,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment confirmed for Order #${order.token} via ${result.paymentMethod}!',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _editOrder(StallOrder order) {
    if (_controller.isEditing) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Already editing Order #${_controller.editingOrderId}. Finish or cancel before editing another.',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          persist: false,
          action: SnackBarAction(
            label: 'Cancel Current',
            onPressed: _cancelEdit,
          ),
        ),
      );
      return;
    }

    if (_controller.cart.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard Current Cart?'),
          content: const Text(
            'You have unpunched items in your cart. Starting to edit this order will replace your current cart.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep Current Cart'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _performEditOrder(order);
              },
              child: const Text('Edit Order'),
            ),
          ],
        ),
      );
      return;
    }
    _performEditOrder(order);
  }

  void _performEditOrder(StallOrder order) {
    final custName = _controller.startEditingOrder(order);
    _customerNameController.text = custName;
    _orderNotesController.text = order.orderNotes ?? '';
    setState(() {
      _isParcel = order.isParcel;
    });
    _mobileTabController.index = 0;
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Editing Order #${order.token}'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirmDeleteOrder(int token) {
    DeleteOrderDialog.show(
      context,
      orderToken: token,
      onConfirm: () => _controller.deleteOrder(token),
    );
  }

  void _completeOrder(int token) {
    HapticFeedback.lightImpact();
    _controller.markOrderCompleted(token);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order #$token marked completed!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleCompleteTicketItem(int token, String itemId, String itemName, int quantity) async {
    HapticFeedback.mediumImpact();
    final wasOrderCompleted = await _controller.completeOrderItem(
      token: token,
      itemId: itemId,
      quantity: quantity,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasOrderCompleted
              ? 'Order #$token completed! ($itemName x$quantity)'
              : '$itemName x$quantity done for Order #$token',
        ),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            _controller.uncompleteOrderItem(
              token: token,
              itemId: itemId,
              quantity: quantity,
            );
          },
        ),
        persist: false,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleCompleteAllItem(String itemId, String itemName) async {
    HapticFeedback.mediumImpact();
    final completedTokens = await _controller.completeAggregatedItem(itemId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          completedTokens.isNotEmpty
              ? 'All $itemName completed! Orders ${completedTokens.map((t) => '#$t').join(', ')} finished!'
              : 'All $itemName completed!',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleToggleItemCompletion(int token, String itemId, bool complete) async {
    HapticFeedback.lightImpact();
    if (complete) {
      final wasOrderCompleted = await _controller.completeOrderItem(
        token: token,
        itemId: itemId,
      );
      if (!mounted) return;
      if (wasOrderCompleted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #$token marked completed!'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                _controller.uncompleteOrderItem(token: token, itemId: itemId);
              },
            ),
            persist: false,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      await _controller.uncompleteOrderItem(token: token, itemId: itemId);
    }
  }

  void _showAddOrEditItemDialog({MenuItem? existingItem}) {
    AddEditMenuItemDialog.show(
      context,
      controller: _controller,
      existingItem: existingItem,
      categories: _categories.where((c) => c != 'All').toList(),
      getCategoryColor: _getCategoryColor,
      resolvedCategoryColors: _resolvedCategoryColors,
    );
  }

  void openStoreManagementStudio({int initialTabIndex = 0}) {
    StoreManagementDialog.show(
      context,
      controller: _controller,
      getCategoryColor: _getCategoryColor,
      onOpenOrderHistory: _openOrderHistory,
      onOpenCsvImport: _openCsvImport,
      onAddOrEditItem: (item) => _showAddOrEditItemDialog(existingItem: item),
      initialTabIndex: initialTabIndex,
    );
  }

  void _openOrderHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => OrderHistoryScreen(
          storageService: _controller.storageService,
          controller: _controller,
          onOrdersChanged: () {
            _controller.loadPersistedData();
          },
        ),
      ),
    );
    _controller.loadPersistedData();
  }

  void _openCsvImport() {
    CsvImportDialog.showMenuItemsDialog(
      context,
      existingCount: _menu.length,
      onImport: (importedItems, replaceExisting) {
        _controller.setMenu(importedItems, replace: replaceExisting);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              replaceExisting
                  ? 'Replaced menu with ${importedItems.length} items from CSV!'
                  : 'Imported ${importedItems.length} menu items from CSV!',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pendingOrders = _controller.activeOrders;
    final totalRevenue = _controller.orders.fold<double>(
      0,
      (sum, o) => sum + o.total,
    );
    final totalPrepItems = _controller.combinedActiveOrders.fold<int>(
      0,
      (sum, item) => sum + item.totalQuantity,
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
        bottom: MediaQuery.of(context).size.width <= 900
            ? TabBar(
                controller: _mobileTabController,
                tabs: [
                  const Tab(
                    icon: Icon(Icons.touch_app_rounded),
                    text: 'POS / Register',
                  ),
                  Tab(
                    icon: Badge(
                      label: Text('${pendingOrders.length}'),
                      isLabelVisible: pendingOrders.isNotEmpty,
                      child: const Icon(Icons.restaurant_rounded),
                    ),
                    text: 'Active Orders',
                  ),
                  Tab(
                    icon: Badge(
                      label: Text('$totalPrepItems'),
                      isLabelVisible: totalPrepItems > 0,
                      child: const Icon(Icons.inventory_2_rounded),
                    ),
                    text: 'Item Summary',
                  ),
                ],
              )
            : null,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Large screen (Tablet / Desktop): Side-by-side view with right-side tabs
          if (constraints.maxWidth > 900) {
            return Row(
              children: [
                Expanded(flex: 5, child: _buildTakeOrderPanel()),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      TabBar(
                        controller: _desktopTabController,
                        tabs: [
                          Tab(
                            icon: Badge(
                              label: Text('${pendingOrders.length}'),
                              isLabelVisible: pendingOrders.isNotEmpty,
                              child: const Icon(Icons.receipt_long_rounded),
                            ),
                            text: 'Active Orders',
                          ),
                          Tab(
                            icon: Badge(
                              label: Text('$totalPrepItems'),
                              isLabelVisible: totalPrepItems > 0,
                              child: const Icon(Icons.inventory_2_rounded),
                            ),
                            text: 'Item Summary',
                          ),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _desktopTabController,
                          children: [
                            _buildActiveOrdersPanel(pendingOrders),
                            _buildItemSummaryPanel(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          // Small screen (Mobile): 3-Tab view
          return TabBarView(
            controller: _mobileTabController,
            children: [
              _buildTakeOrderPanel(),
              _buildActiveOrdersPanel(pendingOrders),
              _buildItemSummaryPanel(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTakeOrderPanel() {
    return TakeOrderPanel(
      controller: _controller,
      getCategoryColor: _getCategoryColor,
      collapsedCategories: _collapsedCategories,
      onToggleCategoryCollapse: (category) {
        setState(() {
          if (_collapsedCategories.contains(category)) {
            _collapsedCategories.remove(category);
          } else {
            _collapsedCategories.add(category);
          }
        });
      },
      customerNameController: _customerNameController,
      orderNotesController: _orderNotesController,
      isParcel: _isParcel,
      onParcelChanged: (val) {
        setState(() {
          _isParcel = val;
        });
      },
      onOpenManageCategories: null,
      onOpenCsvImport: null,
      onCancelEdit: _cancelEdit,
      onShowCustomNoteDialog: _showCustomNoteDialog,
      onToggleQuickNote: _toggleQuickNote,
      onDeletePredefinedNote: _showDeletePredefinedNoteDialog,
      onAddPredefinedNote: _showAddPredefinedNoteDialog,
      onShowCartBottomSheet: _showCartBottomSheet,
      onClearCart: _clearCart,
      onFireOrder: ({bool immediatePayment = false, String? directPaymentMethod}) =>
          _fireOrder(immediatePayment: immediatePayment, directPaymentMethod: directPaymentMethod),
      onMenuItemTap: _handleMenuItemTap,
      onMenuItemLongPress: null,
    );
  }

  // ---------------------------------------------------------------------------
  // 2. ACTIVE ORDERS QUEUE
  // ---------------------------------------------------------------------------

  Widget _buildActiveOrdersPanel(List<StallOrder> pendingOrders) {
    return ActiveOrdersPanel(
      controller: _controller,
      onConfirmPayment: _showConfirmPaymentDialog,
      onEditOrder: _editOrder,
      onDeleteOrder: _confirmDeleteOrder,
      onCompleteOrder: _completeOrder,
      onToggleItemCompletion: _handleToggleItemCompletion,
    );
  }

  // ---------------------------------------------------------------------------
  // 3. ITEM SUMMARY PREPARATION QUEUE
  // ---------------------------------------------------------------------------

  Widget _buildItemSummaryPanel() {
    return ItemSummaryPanel(
      controller: _controller,
      getCategoryColor: _getCategoryColor,
      onCompleteTicketItem: _handleCompleteTicketItem,
      onCompleteAllItem: _handleCompleteAllItem,
    );
  }
}
