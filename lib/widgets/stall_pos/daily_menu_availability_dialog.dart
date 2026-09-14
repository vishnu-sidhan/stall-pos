import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/order_controller.dart';
import '../../data/models/stall_models.dart';
import 'dietary_symbol.dart';

/// Clean full-height view allowing the stall manager/cashier to toggle which
/// menu items are available for the day. Items marked unavailable are hidden from POS take-order menu.
class DailyMenuAvailabilityView extends StatefulWidget {
  final OrderController controller;
  final Color Function(String category) getCategoryColor;

  const DailyMenuAvailabilityView({
    super.key,
    required this.controller,
    required this.getCategoryColor,
  });

  @override
  State<DailyMenuAvailabilityView> createState() => _DailyMenuAvailabilityViewState();
}

class _DailyMenuAvailabilityViewState extends State<DailyMenuAvailabilityView> {
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
          final groupKey = item.categoryName;
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final matchesName = item.name.toLowerCase().contains(q);
            final matchesCategory = item.categoryName.toLowerCase().contains(q);
            final matchesVariants = item.effectiveVariants.any((v) => v.name.toLowerCase().contains(q));
            if (!matchesName && !matchesCategory && !matchesVariants) continue;
          }
          grouped.putIfAbsent(groupKey, () => []).add(item);
        }

        final sortedCategories = grouped.keys.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                            _searchQuery.isNotEmpty
                                ? 'No items matching "$_searchQuery"'
                                : 'No menu items found',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      itemCount: sortedCategories.length,
                      itemBuilder: (context, catIndex) {
                        final category = sortedCategories[catIndex];
                        final items = grouped[category]!;
                        final catColor = widget.getCategoryColor(category);

                        final catAvailableCount =
                            items.where((i) => i.isAvailable).length;
                        final allCatAvailable =
                            catAvailableCount == items.length;
                        final noneCatAvailable = catAvailableCount == 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          color: isDark
                              ? theme.colorScheme.surfaceContainerHighest
                              : theme.colorScheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: catColor.withAlpha(80),
                              width: 1.2,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            shape: const Border(),
                            collapsedShape: const Border(),
                            leading: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: catColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(
                              category,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              '$catAvailableCount / ${items.length} Available',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Batch toggle switch for category
                                Tooltip(
                                  message: allCatAvailable
                                      ? 'Disable all in $category'
                                      : 'Enable all in $category',
                                  child: Switch.adaptive(
                                    key: ValueKey(
                                        'cat_batch_switch_${category.replaceAll(' ', '_')}'),
                                    value: !noneCatAvailable,
                                    activeThumbColor: Colors.white,
                                    activeTrackColor: const Color(0xFF10B981),
                                    onChanged: (bool val) {
                                      HapticFeedback.lightImpact();
                                      widget.controller
                                          .setCategoryAvailability(category, val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              const Divider(height: 1),
                              ...items.map((item) {
                                final isAvailable = item.isAvailable;
                                final variants = item.effectiveVariants;
                                final hasVariants = variants.isNotEmpty;
                                final availableVariantsCount =
                                    variants.where((v) => v.isAvailable).length;
                                final isPartiallyAvailable = hasVariants &&
                                    isAvailable &&
                                    availableVariantsCount > 0 &&
                                    availableVariantsCount < variants.length;

                                String badgeText;
                                Color badgeColor;
                                Color badgeTextColor;

                                if (!isAvailable || (hasVariants && availableVariantsCount == 0)) {
                                  badgeText = 'Sold Out';
                                  badgeColor = Colors.red;
                                  badgeTextColor = Colors.red.shade800;
                                } else if (hasVariants && isPartiallyAvailable) {
                                  badgeText = '$availableVariantsCount/${variants.length} In Stock';
                                  badgeColor = Colors.orange;
                                  badgeTextColor = Colors.orange.shade800;
                                } else {
                                  badgeText = hasVariants
                                      ? '${variants.length}/${variants.length} In Stock'
                                      : 'In Stock';
                                  badgeColor = Colors.green;
                                  badgeTextColor = Colors.green.shade800;
                                }

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      InkWell(
                                        key: ValueKey('item_row_${item.id}'),
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          widget.controller.toggleItemAvailability(item.id);
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                 children: [
                                                   Row(
                                                     children: [
                                                       DietarySymbol(
                                                         type: item.effectiveDietaryType,
                                                         size: 13,
                                                       ),
                                                       const SizedBox(width: 6),
                                                       Expanded(
                                                         child: Text(
                                                           item.displayName,
                                                           style: TextStyle(
                                                             fontWeight: FontWeight.w600,
                                                             fontSize: 14,
                                                             decoration: isAvailable
                                                                 ? null
                                                                 : TextDecoration.lineThrough,
                                                             color: isAvailable
                                                                 ? null
                                                                 : theme.colorScheme.outline,
                                                           ),
                                                         ),
                                                       ),
                                                     ],
                                                   ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '₹${item.price.toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isAvailable
                                                          ? theme.colorScheme.primary
                                                          : theme.colorScheme.outline,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Status text badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              margin: const EdgeInsets.only(right: 8),
                                              decoration: BoxDecoration(
                                                color: badgeColor.withAlpha(20),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: badgeColor.withAlpha(80),
                                                ),
                                              ),
                                              child: Text(
                                                badgeText,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: badgeTextColor,
                                                ),
                                              ),
                                            ),
                                            // Item switch
                                            Switch.adaptive(
                                              key: ValueKey('item_switch_${item.id}'),
                                              value: isAvailable,
                                              activeThumbColor: Colors.white,
                                              activeTrackColor: const Color(0xFF10B981),
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
                                      if (hasVariants) ...[
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: variants.map((v) {
                                            final vPrice = item.priceForVariant(v);
                                            final isVarAvailable = isAvailable && v.isAvailable;
                                            return InkWell(
                                              key: ValueKey('var_toggle_${item.id}_${v.name}'),
                                              onTap: isAvailable
                                                  ? () {
                                                      HapticFeedback.selectionClick();
                                                      widget.controller.toggleMenuItemVariantAvailability(
                                                        item.id,
                                                        v.name,
                                                      );
                                                    }
                                                  : null,
                                              borderRadius: BorderRadius.circular(8),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 150),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isVarAvailable
                                                      ? Colors.green.withAlpha(25)
                                                      : (isDark
                                                          ? Colors.red.withAlpha(20)
                                                          : Colors.red.withAlpha(15)),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: isVarAvailable
                                                        ? Colors.green.withAlpha(120)
                                                        : Colors.red.withAlpha(80),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isVarAvailable
                                                          ? Icons.check_circle_rounded
                                                          : Icons.cancel_rounded,
                                                      size: 13,
                                                      color: isVarAvailable
                                                          ? Colors.green.shade700
                                                          : Colors.red.shade700,
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Text(
                                                      v.name,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        decoration: isVarAvailable
                                                            ? null
                                                            : TextDecoration.lineThrough,
                                                        color: isVarAvailable
                                                            ? (isDark
                                                                ? Colors.white
                                                                : Colors.black87)
                                                            : theme.colorScheme.outline,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '₹${vPrice.toStringAsFixed(0)}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: isVarAvailable
                                                            ? theme.colorScheme.primary
                                                            : theme.colorScheme.outline,
                                                      ),
                                                    ),
                                                    if (!isVarAvailable && isAvailable) ...[
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '(Sold Out)',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.red.shade700,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                      const Divider(height: 12),
                                    ],
                                  ),
                                );
                              }),
                            ],
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
}

/// Modal dialog allowing the stall manager/cashier to toggle which menu items
/// are available for the day. Items marked unavailable are hidden from POS take-order menu.
class DailyMenuAvailabilityDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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

            // Embedded DailyMenuAvailabilityView
            Expanded(
              child: DailyMenuAvailabilityView(
                controller: controller,
                getCategoryColor: getCategoryColor,
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
  }
}
