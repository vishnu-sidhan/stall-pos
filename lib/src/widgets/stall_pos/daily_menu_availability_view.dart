import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/order_controller.dart';
import '../../models/stall_models.dart';
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
  String _selectedCategory = 'All';
  ItemDietaryType? _selectedDietary;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildDietaryFilterChip(
    BuildContext context, {
    Key? key,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
    ItemDietaryType? dietaryType,
  }) {
    return ChoiceChip(
      key: key,
      avatar: dietaryType != null
          ? DietarySymbol(type: dietaryType, size: 12)
          : null,
      label: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          fontSize: 12,
          color: isSelected ? color : null,
        ),
      ),
      selected: isSelected,
      selectedColor: color.withAlpha(40),
      side: BorderSide(
        color: isSelected ? color : Colors.grey.withAlpha(80),
        width: isSelected ? 1.5 : 1,
      ),
      showCheckmark: false,
      onSelected: (_) => onTap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final allCategoryNames = [
          'All',
          ...widget.controller.categories.where((c) => c.trim().toLowerCase() != 'all'),
        ];

        // Group items by category (respecting search filter, category filter, and dietary filter via centralized helper)
        final filteredItems = widget.controller.filterMenuItems(
          query: _searchQuery,
          categoryId: _selectedCategory == 'All' ? null : _selectedCategory,
          dietary: _selectedDietary ?? ItemDietaryType.none,
        );
        final filteredAvailableCount =
            filteredItems.where((item) => item.isAvailable).length;
        final filteredTotalCount = filteredItems.length;

        final isFiltered = _selectedCategory != 'All' ||
            _selectedDietary != null ||
            _searchQuery.isNotEmpty;

        final Map<String, List<MenuItem>> grouped = {};
        for (final item in filteredItems) {
          final groupKey = item.categoryName;
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

                  // Category Filter Chips
                  if (allCategoryNames.length > 1) ...[
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: allCategoryNames.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 6),
                        itemBuilder: (context, idx) {
                          final cat = allCategoryNames[idx];
                          final isSelected = _selectedCategory == cat;
                          final catColor = cat == 'All'
                              ? theme.colorScheme.primary
                              : widget.getCategoryColor(cat);
                          return ChoiceChip(
                            key: ValueKey('daily_category_filter_${cat.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}'),
                            avatar: cat == 'All'
                                ? null
                                : Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: catColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                            label: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? catColor : null,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: catColor.withAlpha(40),
                            side: BorderSide(
                              color: isSelected ? catColor : Colors.grey.withAlpha(80),
                              width: isSelected ? 1.5 : 1,
                            ),
                            showCheckmark: false,
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedCategory = cat);
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Dietary Type Quick Filters (All, Veg, Non-Veg)
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildDietaryFilterChip(
                          context,
                          key: const ValueKey('daily_dietary_filter_all'),
                          label: 'All',
                          isSelected: _selectedDietary == null,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedDietary = null);
                          },
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        _buildDietaryFilterChip(
                          context,
                          key: const ValueKey('daily_dietary_filter_veg'),
                          label: 'Veg',
                          isSelected: _selectedDietary == ItemDietaryType.veg,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedDietary =
                                _selectedDietary == ItemDietaryType.veg ? null : ItemDietaryType.veg);
                          },
                          dietaryType: ItemDietaryType.veg,
                          color: const Color(0xFF2E7D32),
                        ),
                        const SizedBox(width: 6),
                        _buildDietaryFilterChip(
                          context,
                          key: const ValueKey('daily_dietary_filter_non_veg'),
                          label: 'Non-Veg',
                          isSelected: _selectedDietary == ItemDietaryType.nonVeg,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedDietary =
                                _selectedDietary == ItemDietaryType.nonVeg ? null : ItemDietaryType.nonVeg);
                          },
                          dietaryType: ItemDietaryType.nonVeg,
                          color: const Color(0xFFC62828),
                        ),
                        if (widget.controller.menu.any((i) => i.effectiveDietaryType == ItemDietaryType.egg)) ...[
                          const SizedBox(width: 6),
                          _buildDietaryFilterChip(
                            context,
                            key: const ValueKey('daily_dietary_filter_egg'),
                            label: 'Egg',
                            isSelected: _selectedDietary == ItemDietaryType.egg,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedDietary =
                                  _selectedDietary == ItemDietaryType.egg ? null : ItemDietaryType.egg);
                            },
                            dietaryType: ItemDietaryType.egg,
                            color: const Color(0xFFE65100),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Availability badge & Batch toggles
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: filteredAvailableCount == filteredTotalCount && filteredTotalCount > 0
                              ? Colors.green.withAlpha(25)
                              : (filteredAvailableCount == 0
                                  ? Colors.red.withAlpha(25)
                                  : theme.colorScheme.primaryContainer.withAlpha(60)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: filteredAvailableCount == filteredTotalCount && filteredTotalCount > 0
                              ? Colors.green.withAlpha(120)
                              : (filteredAvailableCount == 0
                                  ? Colors.red.withAlpha(120)
                                  : theme.colorScheme.primary.withAlpha(100)),
                          ),
                        ),
                        child: Text(
                          '$filteredAvailableCount / $filteredTotalCount Active',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: filteredAvailableCount == filteredTotalCount && filteredTotalCount > 0
                                ? Colors.green.shade800
                                : (filteredAvailableCount == 0
                                    ? Colors.red.shade800
                                    : theme.colorScheme.primary),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Tooltip(
                        message: isFiltered
                            ? 'Enable all filtered items (${filteredItems.length})'
                            : 'Enable all menu items',
                        child: TextButton.icon(
                          key: const ValueKey('enable_all_items_btn'),
                          onPressed: filteredItems.isEmpty
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  widget.controller.setItemsAvailability(
                                    filteredItems.map((e) => e.id),
                                    true,
                                  );
                                },
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Enable All'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: isFiltered
                            ? 'Disable all filtered items (${filteredItems.length})'
                            : 'Disable all menu items',
                        child: TextButton.icon(
                          key: const ValueKey('disable_all_items_btn'),
                          onPressed: filteredItems.isEmpty
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  widget.controller.setItemsAvailability(
                                    filteredItems.map((e) => e.id),
                                    false,
                                  );
                                },
                          icon: const Icon(Icons.remove_circle_outline, size: 16),
                          label: const Text('Disable All'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
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
                        final catConfig = widget.controller.getCategoryConfig(category);

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
                                          .setItemsAvailability(items.map((e) => e.id), val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              const Divider(height: 1),
                              if (catConfig != null &&
                                  (catConfig.effectiveOptions.isNotEmpty || catConfig.addons.isNotEmpty)) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                  color: catColor.withAlpha(15),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.tune_rounded, size: 14, color: catColor),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Sub-Category & Add-on Daily Availability',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white70 : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (catConfig.effectiveOptions.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Sub-Categories (Variants):',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: catConfig.effectiveOptions.map((opt) {
                                            final isEnabled = opt.isEnabled;
                                            return InkWell(
                                              key: ValueKey('cat_var_toggle_${category}_${opt.name}'),
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                widget.controller.toggleCategoryVariantAvailability(
                                                  category,
                                                  opt.name,
                                                );
                                              },
                                              borderRadius: BorderRadius.circular(6),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isEnabled
                                                      ? Colors.green.withAlpha(25)
                                                      : Colors.red.withAlpha(25),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: isEnabled
                                                        ? Colors.green.withAlpha(120)
                                                        : Colors.red.withAlpha(120),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isEnabled ? Icons.check : Icons.close,
                                                      size: 12,
                                                      color: isEnabled ? Colors.green.shade700 : Colors.red.shade700,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${opt.name}${isEnabled ? '' : ' (Disabled)'}',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: isEnabled ? null : Colors.red.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                      if (catConfig.addons.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Category Add-ons:',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: catConfig.addons.map((addon) {
                                            final isEnabled = addon.isEnabled;
                                            return InkWell(
                                              key: ValueKey('cat_addon_toggle_${category}_${addon.name}'),
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                widget.controller.toggleCategoryAddonAvailability(
                                                  category,
                                                  addon.name,
                                                );
                                              },
                                              borderRadius: BorderRadius.circular(6),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isEnabled
                                                      ? Colors.blue.withAlpha(25)
                                                      : Colors.red.withAlpha(25),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: isEnabled
                                                        ? Colors.blue.withAlpha(120)
                                                        : Colors.red.withAlpha(120),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isEnabled ? Icons.check : Icons.close,
                                                      size: 12,
                                                      color: isEnabled ? Colors.blue.shade700 : Colors.red.shade700,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '+${addon.name}${isEnabled ? '' : ' (Disabled)'}',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: isEnabled ? null : Colors.red.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                              ],
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
                                                           item.name,
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
                                      if (item.effectiveAddons.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: item.effectiveAddons.map((addon) {
                                            final isAddonAvail = isAvailable && addon.isAvailable;
                                            return InkWell(
                                              key: ValueKey('addon_toggle_${item.id}_${addon.name}'),
                                              onTap: isAvailable
                                                  ? () {
                                                      HapticFeedback.selectionClick();
                                                      widget.controller.toggleMenuItemAddonAvailability(
                                                        item.id,
                                                        addon.name,
                                                      );
                                                    }
                                                  : null,
                                              borderRadius: BorderRadius.circular(8),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 150),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isAddonAvail
                                                      ? Colors.blue.withAlpha(20)
                                                      : (isDark ? Colors.red.withAlpha(20) : Colors.red.withAlpha(15)),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: isAddonAvail
                                                        ? Colors.blue.withAlpha(100)
                                                        : Colors.red.withAlpha(80),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isAddonAvail ? Icons.add_circle_outline : Icons.cancel_rounded,
                                                      size: 12,
                                                      color: isAddonAvail ? Colors.blue.shade700 : Colors.red.shade700,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '+${addon.name}',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        decoration: isAddonAvail ? null : TextDecoration.lineThrough,
                                                        color: isAddonAvail
                                                            ? (isDark ? Colors.white70 : Colors.black87)
                                                            : theme.colorScheme.outline,
                                                      ),
                                                    ),
                                                    if (!isAddonAvail && isAvailable) ...[
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        '(Sold Out)',
                                                        style: TextStyle(
                                                          fontSize: 9,
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
