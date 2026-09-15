import 'package:flutter/material.dart';
import '../controllers/order_controller.dart';
import '../models/stall_models.dart';
import '../widgets/csv_import_dialog.dart';
import '../widgets/stall_pos/add_edit_menu_item_dialog.dart';
import '../widgets/stall_pos/daily_menu_availability_view.dart';
import '../widgets/stall_pos/manage_categories_view.dart';
import 'order_history_screen.dart';

/// Headless embeddable Store Management view.
///
/// Houses administrative tools:
/// 1. Daily Menu Availability (toggle available/sold-out items)
/// 2. Menu Catalog & Variants (manage items, variants, custom pricing)
/// 3. Categories & Surcharges (category fees and options)
/// 4. History & CSV Tools (order history, bulk import/export)
///
/// Designed to be embedded into custom host application navigation shells
/// without forcing a root [Scaffold] or hardcoded [AppBar].
class StoreManagementView extends StatefulWidget {
  final OrderController controller;
  final Color Function(String category)? getCategoryColor;
  final VoidCallback? onOpenOrderHistory;
  final VoidCallback? onOpenCsvImport;
  final VoidCallback? onExportCsv;
  final void Function(MenuItem? item)? onAddOrEditItem;
  final int initialTabIndex;

  const StoreManagementView({
    super.key,
    required this.controller,
    this.getCategoryColor,
    this.onOpenOrderHistory,
    this.onOpenCsvImport,
    this.onExportCsv,
    this.onAddOrEditItem,
    this.initialTabIndex = 0,
  });

  @override
  State<StoreManagementView> createState() => _StoreManagementViewState();
}

class _StoreManagementViewState extends State<StoreManagementView>
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
          storage: widget.controller.storage,
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
          ),
        );
      },
      onImportCatalog: (catalog, replaceExisting) {
        widget.controller.importMenuCatalog(
          items: catalog.items,
          categories: catalog.categories,
          replace: replaceExisting,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              replaceExisting
                  ? 'Replaced menu with ${catalog.items.length} items and ${catalog.categories.length} categories from CSV!'
                  : 'Imported ${catalog.items.length} menu items and ${catalog.categories.length} categories from CSV!',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  Future<void> _handleExportMenuCsv() async {
    if (widget.onExportCsv != null) {
      widget.onExportCsv!();
      return;
    }
    try {
      await widget.controller.exportMenuToCsv();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menu catalog exported successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export menu catalog: $e'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleAddOrEditItem(MenuItem? item) {
    if (widget.onAddOrEditItem != null) {
      widget.onAddOrEditItem!(item);
      return;
    }
    AddEditMenuItemDialog.show(
      context,
      controller: widget.controller,
      existingItem: item,
      categories: widget.controller.categories.where((c) => c != 'All').toList(),
      getCategoryColor: _resolveCatColor,
      resolvedCategoryColors: widget.controller.resolvedCategoryColors,
    );
  }

  Future<void> _handleDeleteItem(MenuItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Menu Item?'),
        content: Text('Are you sure you want to delete "${item.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.controller.deleteMenuItem(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${item.name}"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    _menuSearchController.addListener(() {
      setState(() {
        _menuSearchQuery = _menuSearchController.text.trim().toLowerCase();
      });
    });
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

    final isSmall = MediaQuery.of(context).size.width <= 640;

    return Column(
      children: [
        Container(
          color: theme.colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            isScrollable: isSmall,
            tabAlignment: isSmall ? TabAlignment.start : null,
            tabs: const [
              Tab(
                icon: Icon(Icons.check_circle_outline_rounded, size: 20),
                text: 'Daily Availability',
              ),
              Tab(
                icon: Icon(Icons.restaurant_menu_rounded, size: 20),
                text: 'Menu & Variants',
              ),
              Tab(
                icon: Icon(Icons.category_rounded, size: 20),
                text: 'Categories & Fees',
              ),
              Tab(
                icon: Icon(Icons.history_edu_rounded, size: 20),
                text: 'History & Tools',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDailyAvailabilityTab(theme, isDark),
              _buildMenuCatalogTab(theme, isDark),
              _buildCategoriesTab(theme, isDark),
              _buildHistoryAndCsvTab(theme, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDailyAvailabilityTab(ThemeData theme, bool isDark) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final menu = widget.controller.menu;
        if (menu.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  size: 54,
                  color: theme.colorScheme.outlineVariant,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Menu Items to Configure',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add items in the Menu & Variants tab first.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return DailyMenuAvailabilityView(
          controller: widget.controller,
          getCategoryColor: _resolveCatColor,
        );
      },
    );
  }

  Widget _buildMenuCatalogTab(ThemeData theme, bool isDark) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final allItems = widget.controller.menu;
        final filteredItems = _menuSearchQuery.isEmpty
            ? allItems
            : allItems.where((i) {
                return i.name.toLowerCase().contains(_menuSearchQuery) ||
                    i.categoryName.toLowerCase().contains(_menuSearchQuery);
              }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _menuSearchController,
                      decoration: InputDecoration(
                        hintText: 'Search items or categories...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: _menuSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => _menuSearchController.clear(),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    key: const ValueKey('admin_add_menu_item_btn'),
                    onPressed: () => _handleAddOrEditItem(null),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Text(
                        _menuSearchQuery.isEmpty
                            ? 'No items in catalog yet.'
                            : 'No items match "$_menuSearchQuery"',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: filteredItems.length,
                      itemBuilder: (ctx, idx) {
                        final item = filteredItems[idx];
                        final catColor = _resolveCatColor(item.categoryName);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: theme.colorScheme.outlineVariant.withAlpha(80),
                            ),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: catColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(
                              item.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${item.categoryName} • ₹${item.price.toStringAsFixed(0)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  tooltip: 'Edit Item',
                                  onPressed: () => _handleAddOrEditItem(item),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 20,
                                    color: theme.colorScheme.error,
                                  ),
                                  tooltip: 'Delete Item',
                                  onPressed: () => _handleDeleteItem(item),
                                ),
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

  Widget _buildCategoriesTab(ThemeData theme, bool isDark) {
    return ManageCategoriesView(
      controller: widget.controller,
      getCategoryColor: _resolveCatColor,
    );
  }

  Widget _buildHistoryAndCsvTab(ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Order History Tile
        _buildToolTile(
          theme: theme,
          isDark: isDark,
          icon: Icons.history_rounded,
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
        const SizedBox(height: 16),

        // CSV Export Tile (Objective 4)
        _buildToolTile(
          theme: theme,
          isDark: isDark,
          icon: Icons.download_rounded,
          iconColor: Colors.green,
          title: 'Export Menu (CSV)',
          subtitle:
              'Backup catalog items, categories, surcharge rules, and variants to CSV for safekeeping or sharing.',
          buttonLabel: 'Export Menu (CSV)',
          onTap: _handleExportMenuCsv,
        ),
      ],
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
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 28),
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
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(buttonLabel, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
