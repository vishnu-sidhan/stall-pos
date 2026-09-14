import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/order_controller.dart';
import '../controllers/theme_controller.dart';
import '../data/models/stall_models.dart';
import '../widgets/csv_import_dialog.dart';
import '../widgets/stall_pos/add_edit_menu_item_dialog.dart';
import '../widgets/stall_pos/daily_menu_availability_dialog.dart';
import '../widgets/stall_pos/manage_categories_dialog.dart';
import 'order_history_screen.dart';

/// Centralized Store Management Studio Screen (Admin Page).
///
/// Houses all administrative tools:
/// 1. Daily Menu Availability (toggle available/sold-out items)
/// 2. Menu Catalog & Variants (manage items, variants, custom pricing)
/// 3. Categories & Surcharges (category fees and options)
/// 4. History & CSV Tools (order history, bulk import/export)
class StoreManagementScreen extends StatefulWidget {
  final OrderController controller;
  final Color Function(String category)? getCategoryColor;
  final VoidCallback? onOpenOrderHistory;
  final VoidCallback? onOpenCsvImport;
  final void Function(MenuItem? item)? onAddOrEditItem;
  final int initialTabIndex;
  final bool? showBackButton;

  const StoreManagementScreen({
    super.key,
    required this.controller,
    this.getCategoryColor,
    this.onOpenOrderHistory,
    this.onOpenCsvImport,
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
          onAddOrEditItem: onAddOrEditItem,
          initialTabIndex: initialTabIndex,
          showBackButton: showBackButton,
        ),
      ),
    );
  }

  @override
  State<StoreManagementScreen> createState() => _StoreManagementScreenState();
}

class _StoreManagementScreenState extends State<StoreManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _menuSearchQuery = '';
  final TextEditingController _menuSearchController = TextEditingController();

  Color _resolveCatColor(String cat) {
    if (widget.getCategoryColor != null) {
      return widget.getCategoryColor!(cat);
    }
    return widget.controller.getCategoryColor(cat);
  }

  void _handleOpenOrderHistory() async {
    if (widget.onOpenOrderHistory != null) {
      widget.onOpenOrderHistory!();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => OrderHistoryScreen(
          storageService: widget.controller.storageService,
          controller: widget.controller,
          onOrdersChanged: () => widget.controller.loadPersistedData(),
        ),
      ),
    );
    widget.controller.loadPersistedData();
  }

  void _handleOpenCsvImport() {
    if (widget.onOpenCsvImport != null) {
      widget.onOpenCsvImport!();
      return;
    }
    CsvImportDialog.showMenuItemsDialog(
      context,
      existingCount: widget.controller.menu.length,
      onImport: (importedItems, replaceExisting) {
        widget.controller.setMenu(importedItems, replace: replaceExisting);
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

  void _handleAddOrEditItem(MenuItem? existingItem) {
    if (widget.onAddOrEditItem != null) {
      widget.onAddOrEditItem!(existingItem);
      return;
    }
    final categories =
        widget.controller.categories.where((c) => c != 'All').toList();
    AddEditMenuItemDialog.show(
      context,
      controller: widget.controller,
      existingItem: existingItem,
      categories: categories,
      getCategoryColor: _resolveCatColor,
      resolvedCategoryColors: widget.controller.resolvedCategoryColors,
    );
  }

  void _handleDeleteItem(MenuItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Menu Item?'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.controller.deleteMenuItem(item.id);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _menuSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final canPop = Navigator.of(context).canPop();
    final shouldShowBack = widget.showBackButton ?? canPop;

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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'Catalog, Daily Availability, Categories & Tools',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ListenableBuilder(
            listenable: ThemeController.instance,
            builder: (context, _) {
              final isThemeDark =
                  Theme.of(context).brightness == Brightness.dark;
              return IconButton(
                icon: Icon(
                  isThemeDark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_outlined,
                ),
                tooltip: isThemeDark
                    ? 'Switch to Light Theme'
                    : 'Switch to Dark Theme',
                onPressed: () => ThemeController.instance.toggleTheme(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: size.width <= 640,
          tabAlignment: size.width <= 640 ? TabAlignment.start : null,
          tabs: const [
            Tab(
              icon: Icon(Icons.checklist_rounded, size: 20),
              text: 'Daily Availability',
            ),
            Tab(
              icon: Icon(Icons.restaurant_menu_rounded, size: 20),
              text: 'Menu & Variants',
            ),
            Tab(
              icon: Icon(Icons.tune_rounded, size: 20),
              text: 'Categories & Fees',
            ),
            Tab(
              icon: Icon(Icons.history_edu_rounded, size: 20),
              text: 'History & Tools',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Daily Availability (clean full-screen view)
          DailyMenuAvailabilityView(
            controller: widget.controller,
            getCategoryColor: _resolveCatColor,
          ),

          // Tab 2: Menu Catalog & Variants (clean full-screen view)
          _buildMenuCatalogTab(theme, isDark),

          // Tab 3: Categories & Surcharges (clean full-screen view)
          ManageCategoriesView(
            controller: widget.controller,
            getCategoryColor: _resolveCatColor,
          ),

          // Tab 4: History & Tools (clean full-screen view)
          _buildHistoryAndToolsTab(theme, isDark),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: MENU CATALOG & VARIANTS
  // ---------------------------------------------------------------------------
  Widget _buildMenuCatalogTab(ThemeData theme, bool isDark) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final allItems = widget.controller.menu;
        final filtered = _menuSearchQuery.trim().isEmpty
            ? allItems
            : allItems.where((m) {
                final q = _menuSearchQuery.toLowerCase();
                return m.name.toLowerCase().contains(q) ||
                    m.categoryName.toLowerCase().contains(q) ||
                    m.effectiveVariants.any((v) => v.name.toLowerCase().contains(q));
              }).toList();

        return Column(
          children: [
            // Action Bar (Search + Add Item Button)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _menuSearchController,
                      decoration: InputDecoration(
                        hintText: 'Search items, variants, or categories...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _menuSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _menuSearchController.clear();
                                  setState(() => _menuSearchQuery = '');
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? theme.colorScheme.surfaceContainerHighest
                            : theme.colorScheme.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      onChanged: (val) => setState(() => _menuSearchQuery = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    key: const ValueKey('admin_add_menu_item_btn'),
                    onPressed: () => _handleAddOrEditItem(null),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Items List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(120),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _menuSearchQuery.isNotEmpty
                                ? 'No items matching "$_menuSearchQuery"'
                                : 'No menu items yet',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) {
                        final item = filtered[idx];
                        final catColor = _resolveCatColor(item.categoryName);
                        final variants = item.effectiveVariants;

                        return Card(
                          elevation: 0,
                          color: isDark
                              ? theme.colorScheme.surfaceContainerHighest
                              : theme.colorScheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: theme.colorScheme.outlineVariant.withAlpha(80),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: catColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '₹${item.price.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      tooltip: 'Edit Item & Variants',
                                      onPressed: () => _handleAddOrEditItem(item),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: theme.colorScheme.error,
                                      ),
                                      tooltip: 'Delete Item',
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        _handleDeleteItem(item);
                                      },
                                    ),
                                  ],
                                ),

                                // Variants row if any
                                if (variants.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: variants.map((v) {
                                      final vPrice = item.priceForVariant(v);
                                      final isEnabled = v.isEnabled;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isEnabled
                                              ? catColor.withAlpha(25)
                                              : Colors.red.withAlpha(20),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isEnabled
                                                ? catColor.withAlpha(60)
                                                : Colors.red.withAlpha(60),
                                          ),
                                        ),
                                        child: Text(
                                          '${v.name}: ₹${vPrice.toStringAsFixed(0)}${isEnabled ? '' : ' (Disabled)'}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            decoration: isEnabled
                                                ? null
                                                : TextDecoration.lineThrough,
                                            color: isEnabled
                                                ? (isDark
                                                    ? Colors.white
                                                    : Colors.black87)
                                                : theme.colorScheme.outline,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 4: HISTORY & TOOLS
  // ---------------------------------------------------------------------------
  Widget _buildHistoryAndToolsTab(ThemeData theme, bool isDark) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final totalRevenue = widget.controller.orders.fold<double>(
          0,
          (sum, o) => sum + o.total,
        );

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Quick Stats Overview
            Card(
              elevation: 0,
              color: isDark
                  ? theme.colorScheme.surfaceContainerHighest
                  : theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withAlpha(80),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Terminal Metrics Overview',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _buildStatPill(
                          theme: theme,
                          label: 'Catalog Items',
                          value: '${widget.controller.menu.length}',
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        _buildStatPill(
                          theme: theme,
                          label: 'Categories',
                          value: '${widget.controller.categories.length - 1}',
                          color: Colors.purple,
                        ),
                        const SizedBox(width: 12),
                        _buildStatPill(
                          theme: theme,
                          label: 'Lifetime Orders',
                          value: '${widget.controller.orders.length}',
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 12),
                        _buildStatPill(
                          theme: theme,
                          label: 'Total Revenue',
                          value: '₹${totalRevenue.toStringAsFixed(0)}',
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Order History Tile
            _buildToolTile(
              theme: theme,
              isDark: isDark,
              icon: Icons.receipt_long_rounded,
              iconColor: Colors.teal,
              title: 'Full Order & Sales History',
              subtitle:
                  'View past orders, filter by payment status or date, print summaries, and inspect tickets.',
              buttonLabel: 'Open Order History',
              onTap: _handleOpenOrderHistory,
            ),
            const SizedBox(height: 16),

            // CSV Import Tile
            _buildToolTile(
              theme: theme,
              isDark: isDark,
              icon: Icons.upload_file_rounded,
              iconColor: Colors.blue,
              title: 'Upload Menu CSV',
              subtitle:
                  'Bulk import new menu items, update prices, or replace your entire catalog from a CSV file.',
              buttonLabel: 'Import Menu CSV',
              onTap: _handleOpenCsvImport,
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolTile({
    required ThemeData theme,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: isDark
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonal(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(buttonLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill({
    required ThemeData theme,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
