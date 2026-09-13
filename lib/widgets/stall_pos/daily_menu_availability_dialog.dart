import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/order_controller.dart';
import '../../data/models/stall_models.dart';

/// Modal dialog allowing the stall manager/cashier to toggle which menu items
/// are available for the day. Items marked unavailable are hidden from POS take-order menu.
class DailyMenuAvailabilityDialog extends StatefulWidget {
  final OrderController controller;
  final Color Function(String category) getCategoryColor;

  const DailyMenuAvailabilityDialog({
    super.key,
    required this.controller,
    required this.getCategoryColor,
  });

  static Future<void> show(
    BuildContext context, {
    required OrderController controller,
    required Color Function(String category) getCategoryColor,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => DailyMenuAvailabilityDialog(
        controller: controller,
        getCategoryColor: getCategoryColor,
      ),
    );
  }

  @override
  State<DailyMenuAvailabilityDialog> createState() =>
      _DailyMenuAvailabilityDialogState();
}

class _DailyMenuAvailabilityDialogState
    extends State<DailyMenuAvailabilityDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final allItems = widget.controller.menu;
        final availableCount = allItems.where((item) => item.isAvailable).length;
        final totalCount = allItems.length;

        // Group items by category (respecting search filter)
        final Map<String, List<MenuItem>> grouped = {};
        for (final item in allItems) {
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final matchesName = item.name.toLowerCase().contains(q);
            final matchesCategory = item.categoryName.toLowerCase().contains(q);
            if (!matchesName && !matchesCategory) continue;
          }
          grouped.putIfAbsent(item.categoryName, () => []).add(item);
        }

        final sortedCategories = grouped.keys.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 620,
              maxHeight: 750,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withAlpha(120),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.checklist_rounded,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Menu Availability',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 19,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Select items available to order today',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Controls bar: Search & Quick Batch Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      // Search TextField
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search items or categories...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
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
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) {
                          setState(() => _searchQuery = val.trim());
                        },
                      ),
                      const SizedBox(height: 10),

                      // Availability badge & Batch toggles
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: availableCount == totalCount
                                  ? Colors.green.withAlpha(25)
                                  : (availableCount == 0
                                      ? Colors.red.withAlpha(25)
                                      : theme.colorScheme.primaryContainer.withAlpha(60)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: availableCount == totalCount
                                    ? Colors.green.withAlpha(120)
                                    : (availableCount == 0
                                        ? Colors.red.withAlpha(120)
                                        : theme.colorScheme.primary.withAlpha(100)),
                              ),
                            ),
                            child: Text(
                              '$availableCount / $totalCount Active',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: availableCount == totalCount
                                    ? Colors.green.shade800
                                    : (availableCount == 0
                                        ? Colors.red.shade800
                                        : theme.colorScheme.primary),
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            key: const ValueKey('enable_all_items_btn'),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              widget.controller.setAllItemsAvailability(true);
                            },
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text('Enable All'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            key: const ValueKey('disable_all_items_btn'),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              widget.controller.setAllItemsAvailability(false);
                            },
                            icon: const Icon(Icons.remove_circle_outline, size: 16),
                            label: const Text('Disable All'),
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Content list
                Expanded(
                  child: sortedCategories.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No matching items found',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: sortedCategories.length,
                          itemBuilder: (context, catIdx) {
                            final category = sortedCategories[catIdx];
                            final items = grouped[category]!;
                            final catAvailableCount =
                                items.where((i) => i.isAvailable).length;
                            final catColor = widget.getCategoryColor(category);

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? theme.colorScheme.surfaceContainerLow
                                    : theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant.withAlpha(120),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Category Section Header
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: catColor.withAlpha(20),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(13),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: catColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            category,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.surface,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: theme.colorScheme.outlineVariant,
                                            ),
                                          ),
                                          child: Text(
                                            '$catAvailableCount / ${items.length}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          key: ValueKey('toggle_category_$category'),
                                          borderRadius: BorderRadius.circular(6),
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            final enable = catAvailableCount < items.length;
                                            widget.controller.setCategoryAvailability(
                                              category,
                                              enable,
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            child: Text(
                                              catAvailableCount < items.length
                                                  ? 'Enable All'
                                                  : 'Disable All',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: catAvailableCount < items.length
                                                    ? theme.colorScheme.primary
                                                    : theme.colorScheme.error,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Item Rows
                                  ...items.map((item) {
                                    return InkWell(
                                      key: ValueKey('item_availability_tile_${item.id}'),
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        widget.controller.toggleItemAvailability(item.id);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          item.displayName,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight: item.isAvailable
                                                                ? FontWeight.w600
                                                                : FontWeight.normal,
                                                            color: item.isAvailable
                                                                ? theme.colorScheme.onSurface
                                                                : theme.colorScheme.onSurface.withAlpha(120),
                                                            decoration: item.isAvailable
                                                                ? null
                                                                : TextDecoration.lineThrough,
                                                          ),
                                                        ),
                                                      ),
                                                      if (item.effectiveIsAddon) ...[
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 5,
                                                            vertical: 1,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.amber.withAlpha(40),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: const Text(
                                                            'Add-on',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.amber,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '₹${item.price.toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: theme.colorScheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Switch.adaptive(
                                              key: ValueKey('item_switch_${item.id}'),
                                              value: item.isAvailable,
                                              activeTrackColor: catColor,
                                              onChanged: (bool val) {
                                                HapticFeedback.lightImpact();
                                                widget.controller.setItemAvailability(
                                                  item.id,
                                                  val,
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // Footer
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilledButton(
                        key: const ValueKey('daily_availability_done_btn'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
