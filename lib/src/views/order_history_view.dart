import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/order_controller.dart';
import '../models/stall_models.dart';
import '../storage/stall_storage.dart';
import '../storage/in_memory_storage.dart';
import '../services/csv_export_service.dart';
import '../widgets/stall_pos/delete_order_dialog.dart';

enum OrderHistoryFilter { all, completed, pending, fullyPaid, partial, unpaid }
enum OrderDateRangeFilter { allTime, today, yesterday, last7Days }

/// Headless embeddable Order History View.
///
/// Houses order history metrics, status and date-range filters,
/// token/customer search, expandable order details, and CSV export/archive tools.
/// When [wrapInScaffold] is true, includes a top [AppBar] with quick action buttons.
class OrderHistoryView extends StatefulWidget {
  final StallStorage? storage;
  final StallStorage? storageService;
  final OrderController? controller;
  final VoidCallback? onOrdersChanged;
  final bool wrapInScaffold;
  final bool showHeaderActions;

  const OrderHistoryView({
    super.key,
    this.storage,
    this.storageService,
    this.controller,
    this.onOrdersChanged,
    this.wrapInScaffold = false,
    this.showHeaderActions = false,
  });

  @override
  State<OrderHistoryView> createState() => _OrderHistoryViewState();
}

class _OrderHistoryViewState extends State<OrderHistoryView> {
  List<StallOrder> _orders = [];
  bool _isLoading = true;
  OrderHistoryFilter _filter = OrderHistoryFilter.all;
  OrderDateRangeFilter _dateFilter = OrderDateRangeFilter.allTime;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  StallStorage get _effectiveStorage =>
      widget.controller?.storage ??
      widget.storage ??
      widget.storageService ??
      InMemoryStorage();

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      widget.controller!.addListener(_onControllerChanged);
    }
    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _searchQuery) {
        setState(() => _searchQuery = q);
      }
    });
    _loadOrders();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted && widget.controller != null) {
      final list = List<StallOrder>.from(widget.controller!.orders);
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      setState(() {
        _orders = list;
      });
    }
  }

  Future<void> _loadOrders() async {
    if (widget.controller != null) {
      final list = List<StallOrder>.from(widget.controller!.orders);
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (mounted) {
        setState(() {
          _orders = list;
          _isLoading = false;
        });
      }
    } else {
      final loaded = await _effectiveStorage.loadOrders();
      loaded.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (mounted) {
        setState(() {
          _orders = loaded;
          _isLoading = false;
        });
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<StallOrder> get _ordersForDateFilter {
    final now = DateTime.now();
    return _orders.where((o) {
      switch (_dateFilter) {
        case OrderDateRangeFilter.allTime:
          return true;
        case OrderDateRangeFilter.today:
          return _isSameDay(o.timestamp, now);
        case OrderDateRangeFilter.yesterday:
          final yesterday = now.subtract(const Duration(days: 1));
          return _isSameDay(o.timestamp, yesterday);
        case OrderDateRangeFilter.last7Days:
          return now.difference(o.timestamp).inDays <= 7;
      }
    }).toList();
  }

  String _getDateFilterLabel(OrderDateRangeFilter filter) {
    switch (filter) {
      case OrderDateRangeFilter.allTime:
        return 'All Time';
      case OrderDateRangeFilter.today:
        return 'Today';
      case OrderDateRangeFilter.yesterday:
        return 'Yesterday';
      case OrderDateRangeFilter.last7Days:
        return 'Last 7 Days';
    }
  }

  List<StallOrder> get _filteredOrders {
    final now = DateTime.now();
    return _orders.where((o) {
      // Date filter
      switch (_dateFilter) {
        case OrderDateRangeFilter.allTime:
          break;
        case OrderDateRangeFilter.today:
          if (!_isSameDay(o.timestamp, now)) return false;
          break;
        case OrderDateRangeFilter.yesterday:
          final yesterday = now.subtract(const Duration(days: 1));
          if (!_isSameDay(o.timestamp, yesterday)) return false;
          break;
        case OrderDateRangeFilter.last7Days:
          final diff = now.difference(o.timestamp).inDays;
          if (diff > 7) return false;
          break;
      }

      // Status / Payment filter
      switch (_filter) {
        case OrderHistoryFilter.all:
          break;
        case OrderHistoryFilter.completed:
          if (!o.isCompleted) return false;
          break;
        case OrderHistoryFilter.pending:
          if (o.isCompleted) return false;
          break;
        case OrderHistoryFilter.fullyPaid:
          if (!o.isFullyPaid) return false;
          break;
        case OrderHistoryFilter.partial:
          if (!o.hasPartialPayment) return false;
          break;
        case OrderHistoryFilter.unpaid:
          if (o.isPaid || o.hasPartialPayment) return false;
          break;
      }

      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final tokenStr = '#${o.token}';
        final customer = (o.customerName ?? '').toLowerCase();
        final notes = (o.orderNotes ?? '').toLowerCase();
        final summary = o.itemsSummary.toLowerCase();

        final matchesToken = tokenStr.contains(_searchQuery) ||
            o.token.toString().contains(_searchQuery);
        final matchesCustomer = customer.contains(_searchQuery);
        final matchesNotes = notes.contains(_searchQuery);
        final matchesItems = summary.contains(_searchQuery);

        if (!matchesToken && !matchesCustomer && !matchesNotes && !matchesItems) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  double get _totalRevenue =>
      _orders.fold<double>(0.0, (sum, o) => sum + o.total);

  double get _avgOrderValue =>
      _orders.isEmpty ? 0 : _totalRevenue / _orders.length;

  int get _completedCount => _orders.where((o) => o.isCompleted).length;
  int get _pendingCount => _orders.where((o) => !o.isCompleted).length;

  Future<void> _exportCsv() async {
    final targetOrders = _filteredOrders.isNotEmpty ? _filteredOrders : _orders;
    await CsvExportService.exportOrdersCsv(orders: targetOrders);
  }

  Future<void> _confirmArchiveCompleted() async {
    if (_completedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No completed orders to archive.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Completed Orders?'),
        content: Text(
          'This will permanently archive $_completedCount completed orders. They will be saved to your archive history file and cleared from the active list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (widget.controller != null) {
                await widget.controller!.archiveCompletedOrders();
              } else {
                final completed = _orders.where((o) => o.isCompleted).toList();
                await _effectiveStorage.archiveCompletedOrders(explicitOrders: completed);
                await _effectiveStorage.clearCompletedOrders();
                await _loadOrders();
              }
              widget.onOrdersChanged?.call();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Completed orders archived successfully.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearCompleted() async {
    if (_completedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No completed orders to clear.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Completed Orders?'),
        content: Text(
          'This will permanently remove $_completedCount completed orders from history. Active/pending orders will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              if (widget.controller != null) {
                await widget.controller!.clearCompletedOrders();
              } else {
                await _effectiveStorage.clearCompletedOrders();
                await _loadOrders();
              }
              widget.onOrdersChanged?.call();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Completed orders cleared.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Clear Completed'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons() {
    return [
      IconButton(
        icon: const Icon(Icons.download_rounded),
        tooltip: 'Download CSV',
        onPressed: _orders.isEmpty ? null : _exportCsv,
      ),
      IconButton(
        icon: const Icon(Icons.archive_outlined),
        tooltip: 'Archive Completed',
        onPressed: _completedCount == 0 ? null : _confirmArchiveCompleted,
      ),
      IconButton(
        icon: const Icon(Icons.delete_sweep_rounded),
        tooltip: 'Clear Completed',
        onPressed: _completedCount == 0 ? null : _confirmClearCompleted,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              if (widget.showHeaderActions && !widget.wrapInScaffold)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                    border: Border(bottom: BorderSide(color: theme.dividerColor)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Order History',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Row(children: _buildActionButtons()),
                    ],
                  ),
                ),

              // Summary Metrics Banner
              _buildSummaryBanner(theme),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by #Token, Customer, or Items...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              // Filter Chips (Status)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'All (${_orders.length})',
                      filter: OrderHistoryFilter.all,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Completed ($_completedCount)',
                      filter: OrderHistoryFilter.completed,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Pending ($_pendingCount)',
                      filter: OrderHistoryFilter.pending,
                    ),
                    const SizedBox(width: 12),
                    Container(width: 1, height: 24, color: Colors.grey.withAlpha(80)),
                    const SizedBox(width: 12),
                    // Date Range Chips
                    _buildDateFilterChip('All Time', OrderDateRangeFilter.allTime),
                    const SizedBox(width: 6),
                    _buildDateFilterChip('Today', OrderDateRangeFilter.today),
                    const SizedBox(width: 6),
                    _buildDateFilterChip('Yesterday', OrderDateRangeFilter.yesterday),
                    const SizedBox(width: 6),
                    _buildDateFilterChip('Last 7 Days', OrderDateRangeFilter.last7Days),
                  ],
                ),
              ),
              // End-of-Day Quick Settlement Summary
              _buildSettlementSummaryCard(theme),
              const Divider(height: 1),

              // Orders List
              Expanded(
                child: _filteredOrders.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredOrders.length,
                        itemBuilder: (context, index) {
                          final order = _filteredOrders[index];
                          return _buildOrderCard(order, theme);
                        },
                      ),
              ),
            ],
          );

    if (widget.wrapInScaffold) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Order History',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: _buildActionButtons(),
        ),
        body: content,
      );
    }

    return content;
  }

  Widget _buildSummaryBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(100),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total Revenue', '₹${_totalRevenue.toStringAsFixed(0)}', theme.colorScheme.primary),
          _buildDivider(),
          _buildStatItem('Orders', '${_orders.length}', theme.colorScheme.onSurface),
          _buildDivider(),
          _buildStatItem('Avg Value', '₹${_avgOrderValue.toStringAsFixed(0)}', theme.colorScheme.secondary),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.grey.withAlpha(60),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSettlementSummaryCard(ThemeData theme) {
    final baseList = (_filter == OrderHistoryFilter.pending)
        ? _ordersForDateFilter
        : _filteredOrders;
    final completedOrders = baseList.where((o) => o.isCompleted).toList();
    final completedCount = completedOrders.length;

    double cashInDrawer = 0.0;
    double upiOnline = 0.0;
    for (final o in completedOrders) {
      final method = (o.paymentMethod ?? '').trim().toLowerCase();
      if (method == 'cash') {
        cashInDrawer += o.paidAmount;
      } else {
        upiOnline += o.paidAmount;
      }
    }
    final totalSales = cashInDrawer + upiOnline;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(120),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.point_of_sale_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Settlement Summary',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                _getDateFilterLabel(_dateFilter),
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildSettlementTile(
                  theme,
                  label: 'Completed',
                  value: '$completedCount',
                  icon: Icons.check_circle_outline,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSettlementTile(
                  theme,
                  label: 'Cash in Drawer',
                  value: '₹${cashInDrawer.toStringAsFixed(0)}',
                  icon: Icons.payments_outlined,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSettlementTile(
                  theme,
                  label: 'UPI / Online',
                  value: '₹${upiOnline.toStringAsFixed(0)}',
                  icon: Icons.qr_code_2_rounded,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSettlementTile(
                  theme,
                  label: 'Total Sales',
                  value: '₹${totalSales.toStringAsFixed(0)}',
                  icon: Icons.account_balance_wallet_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementTile(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required OrderHistoryFilter filter,
  }) {
    final isSelected = _filter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = filter),
    );
  }

  Widget _buildDateFilterChip(String label, OrderDateRangeFilter dateFilter) {
    final isSelected = _dateFilter == dateFilter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _dateFilter = dateFilter),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _filter != OrderHistoryFilter.all || _dateFilter != OrderDateRangeFilter.allTime
                ? 'No orders match the current filter'
                : 'No order history yet',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try changing your search query or reset filters'
                : 'Orders placed from the POS register will appear here',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(StallOrder order, ThemeData theme) {
    final formattedTime = DateFormat('dd MMM yyyy, hh:mm a').format(order.timestamp);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: order.isCompleted
              ? Colors.green.withAlpha(60)
              : Colors.orange.withAlpha(80),
        ),
      ),
      child: ExpansionTile(
        key: PageStorageKey('order_${order.token}'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: order.isCompleted
              ? Colors.green.withAlpha(40)
              : Colors.orange.withAlpha(40),
          child: Text(
            '#${order.token}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: order.isCompleted ? Colors.green.shade800 : Colors.orange.shade800,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                order.displayCustomerName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            Text(
              '₹${order.total.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(
                formattedTime,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const Spacer(),
              _buildStatusBadge(order),
            ],
          ),
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order.isParcel)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'Parcel Order',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (order.orderNotes?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(40),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notes_rounded, size: 16, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order.orderNotes!,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Items Summary
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    order.itemsSummary,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const Divider(height: 16),
                // Payment summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payment: ${order.paymentMethod ?? (order.isPaid ? "Paid" : "Pay Later")}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (order.hasPartialPayment)
                      Text(
                        'Paid: ₹${order.paidAmount.toStringAsFixed(0)} | Due: ₹${order.remainingDue.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      tooltip: 'Delete Order',
                      onPressed: () => _handleDeleteOrder(order),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleDeleteOrder(StallOrder order) {
    DeleteOrderDialog.show(
      context,
      orderToken: order.token,
      onConfirm: () async {
        if (widget.controller != null) {
          await widget.controller!.deleteOrder(order.token);
        } else {
          final allOrders = await _effectiveStorage.loadOrders();
          allOrders.removeWhere((o) => o.token == order.token);
          await _effectiveStorage.saveOrders(allOrders);
          await _loadOrders();
        }
        widget.onOrdersChanged?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order #${order.token} deleted'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  Widget _buildStatusBadge(StallOrder order) {
    if (order.isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withAlpha(40),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Completed',
          style: TextStyle(
            fontSize: 11,
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(40),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Pending',
        style: TextStyle(
          fontSize: 11,
          color: Colors.orange,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

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

