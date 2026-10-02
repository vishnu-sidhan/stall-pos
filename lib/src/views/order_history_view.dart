import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/order_controller.dart';
import '../models/stall_models.dart';
import '../storage/stall_storage.dart';
import '../storage/in_memory_storage.dart';
import '../services/csv_export_service.dart';
import '../widgets/stall_pos/delete_order_dialog.dart';

enum OrderHistoryFilter { all, completed, pending, fullyPaid, partial, unpaid }
enum OrderDateRangeFilter { allTime, today, yesterday, last7Days, thisMonth, custom }
enum OrderHistoryViewMode { orders, itemSummary }
enum ItemSalesSortOption { revenueDesc, quantityDesc, nameAsc }

/// Headless embeddable Order History & Analytics View.
///
/// Houses order history metrics, status and date-range filters,
/// token/customer/item search, expandable order details, itemized
/// sales & cost breakdown, and CSV export/archive tools.
/// When [wrapInScaffold] is true, includes a top [AppBar] with quick action buttons.
class OrderHistoryView extends StatefulWidget {
  final StallStorage? storage;
  final StallStorage? storageService;
  final OrderController? controller;
  final VoidCallback? onOrdersChanged;
  final bool wrapInScaffold;
  final bool showHeaderActions;
  final OrderHistoryFilter defaultFilter;
  final OrderDateRangeFilter defaultDateFilter;
  final OrderHistoryViewMode defaultViewMode;

  const OrderHistoryView({
    super.key,
    this.storage,
    this.storageService,
    this.controller,
    this.onOrdersChanged,
    this.wrapInScaffold = false,
    this.showHeaderActions = false,
    this.defaultFilter = OrderHistoryFilter.all,
    this.defaultDateFilter = OrderDateRangeFilter.allTime,
    this.defaultViewMode = OrderHistoryViewMode.orders,
  });

  @override
  State<OrderHistoryView> createState() => _OrderHistoryViewState();
}

class _OrderHistoryViewState extends State<OrderHistoryView> {
  List<StallOrder> _orders = [];
  bool _isLoading = true;
  late OrderHistoryFilter _filter;
  late OrderDateRangeFilter _dateFilter;
  late OrderHistoryViewMode _viewMode;
  ItemSalesSortOption _itemSortOption = ItemSalesSortOption.revenueDesc;
  DateTimeRange? _customDateRange;

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
    _filter = widget.defaultFilter;
    _dateFilter = widget.defaultDateFilter;
    _viewMode = widget.defaultViewMode;

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

  bool _matchesDateFilter(StallOrder o, DateTime now) {
    switch (_dateFilter) {
      case OrderDateRangeFilter.allTime:
        return true;
      case OrderDateRangeFilter.today:
        return _isSameDay(o.timestamp, now);
      case OrderDateRangeFilter.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        return _isSameDay(o.timestamp, yesterday);
      case OrderDateRangeFilter.last7Days:
        return now.difference(o.timestamp).inDays <= 7 &&
            o.timestamp.isBefore(now.add(const Duration(days: 1)));
      case OrderDateRangeFilter.thisMonth:
        return o.timestamp.year == now.year && o.timestamp.month == now.month;
      case OrderDateRangeFilter.custom:
        if (_customDateRange == null) return true;
        final start = DateTime(
          _customDateRange!.start.year,
          _customDateRange!.start.month,
          _customDateRange!.start.day,
        );
        final end = DateTime(
          _customDateRange!.end.year,
          _customDateRange!.end.month,
          _customDateRange!.end.day,
          23,
          59,
          59,
        );
        return o.timestamp.isAfter(start.subtract(const Duration(seconds: 1))) &&
            o.timestamp.isBefore(end.add(const Duration(seconds: 1)));
    }
  }

  List<StallOrder> get _ordersForDateFilter {
    final now = DateTime.now();
    return _orders.where((o) => _matchesDateFilter(o, now)).toList();
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
      case OrderDateRangeFilter.thisMonth:
        return 'This Month';
      case OrderDateRangeFilter.custom:
        if (_customDateRange != null) {
          final f = DateFormat('dd MMM');
          return '${f.format(_customDateRange!.start)} - ${f.format(_customDateRange!.end)}';
        }
        return 'Custom';
    }
  }

  List<StallOrder> get _filteredOrders {
    return _ordersForDateFilter.where((o) {
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

      // Search query filter (when searching in order tickets)
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

  int get _ordersCount => _ordersForDateFilter.length;
  double get _totalRevenue =>
      _ordersForDateFilter.fold<double>(0.0, (sum, o) => sum + o.total);

  double get _avgOrderValue =>
      _ordersCount == 0 ? 0 : _totalRevenue / _ordersCount;

  int get _completedCount =>
      _ordersForDateFilter.where((o) => o.isCompleted).length;
  int get _pendingCount =>
      _ordersForDateFilter.where((o) => !o.isCompleted).length;

  int get _totalItemsCount => _ordersForDateFilter.fold<int>(
        0,
        (sum, o) => sum + o.items.fold<int>(0, (iSum, item) => iSum + item.quantity),
      );

  int get _completedItemsCount => _ordersForDateFilter
      .where((o) => o.isCompleted)
      .fold<int>(
        0,
        (sum, o) => sum + o.items.fold<int>(0, (iSum, item) => iSum + item.quantity),
      );

  int get _allCompletedCount => _orders.where((o) => o.isCompleted).length;

  List<ItemSalesSummary> get _itemSummaries {
    // When aggregating item sales breakdown, aggregate orders matching the current date & filter
    // (If 'all' filter is selected, aggregate completed orders to present actual realized item sales)
    final targetOrders = (_filter == OrderHistoryFilter.all)
        ? _ordersForDateFilter.where((o) => o.isCompleted).toList()
        : _filteredOrders;

    final summaries = targetOrders.aggregateItemSales();

    // Search query filter
    final filtered = _searchQuery.isEmpty
        ? summaries
        : summaries.where((item) {
            final q = _searchQuery;
            return item.displayName.toLowerCase().contains(q) ||
                item.categoryName.toLowerCase().contains(q);
          }).toList();

    // Sort options
    switch (_itemSortOption) {
      case ItemSalesSortOption.revenueDesc:
        filtered.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
        break;
      case ItemSalesSortOption.quantityDesc:
        filtered.sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));
        break;
      case ItemSalesSortOption.nameAsc:
        filtered.sort((a, b) => a.displayName.compareTo(b.displayName));
        break;
    }
    return filtered;
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final initial = _customDateRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        );
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initial,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _dateFilter = OrderDateRangeFilter.custom;
      });
    }
  }

  Future<void> _exportCsv() async {
    if (_viewMode == OrderHistoryViewMode.itemSummary) {
      final itemsToExport = _itemSummaries;
      if (itemsToExport.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No item sales to export for this period.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      await CsvExportService.exportItemSalesSummaryCsv(
        items: itemsToExport,
        dateRangeLabel: _getDateFilterLabel(_dateFilter),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item sales summary exported.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      final targetOrders =
          _filteredOrders.isNotEmpty ? _filteredOrders : _ordersForDateFilter;
      await CsvExportService.exportOrdersCsv(orders: targetOrders);
    }
  }

  Future<void> _confirmArchiveCompleted() async {
    if (_allCompletedCount == 0) {
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
          'This will permanently archive $_allCompletedCount completed orders. They will be saved to your archive history file and cleared from the active list.',
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
    if (_allCompletedCount == 0) {
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
          'This will permanently remove $_allCompletedCount completed orders from history. Active/pending orders will be kept.',
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
        tooltip: _viewMode == OrderHistoryViewMode.itemSummary
            ? 'Download Items Sales CSV'
            : 'Download CSV',
        onPressed: _orders.isEmpty ? null : _exportCsv,
      ),
      IconButton(
        icon: const Icon(Icons.archive_outlined),
        tooltip: 'Archive Completed',
        onPressed: _allCompletedCount == 0 ? null : _confirmArchiveCompleted,
      ),
      IconButton(
        icon: const Icon(Icons.delete_sweep_rounded),
        tooltip: 'Clear Completed',
        onPressed: _allCompletedCount == 0 ? null : _confirmClearCompleted,
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
                        'Order History & Analytics',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Row(children: _buildActionButtons()),
                    ],
                  ),
                ),

              // Summary Metrics Banner
              _buildSummaryBanner(theme),

              // View Mode Switcher: Orders List vs Items Breakdown
              _buildViewSwitcher(theme),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _viewMode == OrderHistoryViewMode.itemSummary
                        ? 'Search items by name or category...'
                        : 'Search by #Token, Customer, or Items...',
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

              // Date Range Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _buildDateFilterChip('All Time', OrderDateRangeFilter.allTime),
                    const SizedBox(width: 6),
                    _buildDateFilterChip('Today', OrderDateRangeFilter.today),
                    const SizedBox(width: 6),
                    _buildDateFilterChip('Yesterday', OrderDateRangeFilter.yesterday),
                    const SizedBox(width: 6),
                    _buildDateFilterChip('Last 7 Days', OrderDateRangeFilter.last7Days),
                    const SizedBox(width: 6),
                    _buildDateFilterChip('This Month', OrderDateRangeFilter.thisMonth),
                    const SizedBox(width: 6),
                    _buildCustomDateFilterChip(),
                  ],
                ),
              ),

              // Status / Payment filter chips (for orders mode or filtering scope)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'All (${_ordersForDateFilter.length})',
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
                  ],
                ),
              ),

              // Orders mode settlement summary
              if (_viewMode == OrderHistoryViewMode.orders)
                _buildSettlementSummaryCard(theme),

              const Divider(height: 1),

              // Main Content: Orders List vs Items Breakdown
              Expanded(
                child: _viewMode == OrderHistoryViewMode.orders
                    ? (_filteredOrders.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredOrders.length,
                            itemBuilder: (context, index) {
                              final order = _filteredOrders[index];
                              return _buildOrderCard(order, theme);
                            },
                          ))
                    : _buildItemSummaryView(theme),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
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
          _buildStatItem('Orders', '$_ordersCount', theme.colorScheme.onSurface),
          _buildDivider(),
          _buildStatItem('Items Sold', '$_totalItemsCount', Colors.teal),
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
            fontSize: 17,
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

  Widget _buildViewSwitcher(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<OrderHistoryViewMode>(
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          segments: [
            ButtonSegment(
              value: OrderHistoryViewMode.orders,
              icon: const Icon(Icons.receipt_long_rounded, size: 16),
              label: Text('Orders List ($_ordersCount)'),
            ),
            ButtonSegment(
              value: OrderHistoryViewMode.itemSummary,
              icon: const Icon(Icons.bar_chart_rounded, size: 16),
              label: Text('Items Breakdown ($_completedItemsCount sold)'),
            ),
          ],
          selected: {_viewMode},
          onSelectionChanged: (newSelection) {
            setState(() => _viewMode = newSelection.first);
          },
        ),
      ),
    );
  }

  Widget _buildItemSummaryView(ThemeData theme) {
    final summaries = _itemSummaries;
    final totalUnits = summaries.fold<int>(0, (sum, i) => sum + i.totalQuantity);
    final totalSales = summaries.fold<double>(0.0, (sum, i) => sum + i.totalRevenue);

    if (summaries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'No completed items sold for this period',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Items from completed orders within the selected filter will appear here.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Sort Chips & Totals Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${summaries.length} items · $totalUnits units · ₹${totalSales.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              PopupMenuButton<ItemSalesSortOption>(
                initialValue: _itemSortOption,
                tooltip: 'Sort items',
                onSelected: (option) => setState(() => _itemSortOption = option),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: ItemSalesSortOption.revenueDesc,
                    child: Text('Sort by Highest Sales (₹)'),
                  ),
                  const PopupMenuItem(
                    value: ItemSalesSortOption.quantityDesc,
                    child: Text('Sort by Most Units Sold'),
                  ),
                  const PopupMenuItem(
                    value: ItemSalesSortOption.nameAsc,
                    child: Text('Sort by Name (A-Z)'),
                  ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _itemSortOption == ItemSalesSortOption.revenueDesc
                          ? Icons.trending_up
                          : (_itemSortOption == ItemSalesSortOption.quantityDesc
                              ? Icons.inventory_2_outlined
                              : Icons.sort_by_alpha),
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _itemSortOption == ItemSalesSortOption.revenueDesc
                          ? 'Sales ₹'
                          : (_itemSortOption == ItemSalesSortOption.quantityDesc
                              ? 'Units'
                              : 'A-Z'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Items List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: summaries.length,
            itemBuilder: (context, index) {
              final summary = summaries[index];
              return _buildItemSalesCard(
                summary: summary,
                rank: index + 1,
                totalSalesSum: totalSales,
                theme: theme,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildItemSalesCard({
    required ItemSalesSummary summary,
    required int rank,
    required double totalSalesSum,
    required ThemeData theme,
  }) {
    final pct = totalSalesSum > 0 ? (summary.totalRevenue / totalSalesSum) : 0.0;

    Color rankColor;
    Color rankTextColor = Colors.white;
    if (rank == 1) {
      rankColor = const Color(0xFFD4AF37); // Gold
    } else if (rank == 2) {
      rankColor = const Color(0xFF90A4AE); // Silver
    } else if (rank == 3) {
      rankColor = const Color(0xFFB07253); // Bronze
    } else {
      rankColor = theme.colorScheme.surfaceContainerHighest;
      rankTextColor = theme.colorScheme.onSurfaceVariant;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withAlpha(90),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rank Avatar
                CircleAvatar(
                  radius: 14,
                  backgroundColor: rankColor,
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: rankTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Name and Category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (summary.isVeg != null) _buildDietaryBadge(summary.isVeg!),
                          Expanded(
                            child: Text(
                              summary.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              summary.categoryName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${summary.totalQuantity} sold · Base ₹${summary.baseUnitPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Revenue Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${summary.totalRevenue.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      '${(pct * 100).toStringAsFixed(1)}% of sales',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Sales Share Progress Indicator
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: theme.colorScheme.primary,
              ),
            ),

            // Add-ons Breakdown
            if (summary.hasAddons) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withAlpha(60),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add-ons Breakdown:',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...summary.addonsBreakdown.map(
                      (addon) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '• ${addon.name} (x${addon.quantity})',
                              style: const TextStyle(fontSize: 11),
                            ),
                            Text(
                              '+₹${addon.totalRevenue.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDietaryBadge(bool isVeg) {
    final color = isVeg ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(2),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(10),
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
                size: 15,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Settlement Summary',
                style: TextStyle(
                  fontSize: 12,
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
          const SizedBox(height: 8),
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
              const SizedBox(width: 6),
              Expanded(
                child: _buildSettlementTile(
                  theme,
                  label: 'Cash in Drawer',
                  value: '₹${cashInDrawer.toStringAsFixed(0)}',
                  icon: Icons.payments_outlined,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildSettlementTile(
                  theme,
                  label: 'UPI / Online',
                  value: '₹${upiOnline.toStringAsFixed(0)}',
                  icon: Icons.qr_code_2_rounded,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 6),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
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

  Widget _buildCustomDateFilterChip() {
    final isSelected = _dateFilter == OrderDateRangeFilter.custom;
    final label = _customDateRange != null
        ? '${DateFormat('dd MMM').format(_customDateRange!.start)} - ${DateFormat('dd MMM').format(_customDateRange!.end)}'
        : 'Custom...';
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_rounded, size: 13, color: isSelected ? Colors.white : null),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => _pickCustomDateRange(),
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
  final OrderHistoryFilter defaultFilter;
  final OrderDateRangeFilter defaultDateFilter;
  final OrderHistoryViewMode defaultViewMode;

  const OrderHistoryScreen({
    super.key,
    this.storageService,
    this.storage,
    this.controller,
    this.onOrdersChanged,
    this.defaultFilter = OrderHistoryFilter.all,
    this.defaultDateFilter = OrderDateRangeFilter.allTime,
    this.defaultViewMode = OrderHistoryViewMode.orders,
  }) : assert(storageService != null || storage != null || controller != null);

  @override
  Widget build(BuildContext context) {
    return OrderHistoryView(
      storage: storage ?? storageService,
      storageService: storageService ?? storage,
      controller: controller,
      onOrdersChanged: onOrdersChanged,
      wrapInScaffold: true,
      defaultFilter: defaultFilter,
      defaultDateFilter: defaultDateFilter,
      defaultViewMode: defaultViewMode,
    );
  }
}
