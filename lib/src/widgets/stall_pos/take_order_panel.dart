import 'package:flutter/material.dart';
import '../../controllers/order_controller.dart';
import '../../models/stall_models.dart';
import 'category_accordion_card.dart';
import 'dietary_symbol.dart';
import 'menu_item_card.dart';

/// The primary Take Order Panel for the POS screen, containing the category selector,
/// categorized accordion menu items, customer name input, order mode, notes, and order punch buttons.
class TakeOrderPanel extends StatelessWidget {
  final OrderController controller;
  final Color Function(String category) getCategoryColor;
  final Set<String> collapsedCategories;
  final ValueChanged<String> onToggleCategoryCollapse;
  final TextEditingController customerNameController;
  final TextEditingController orderNotesController;
  final bool isParcel;
  final ValueChanged<bool> onParcelChanged;
  final VoidCallback? onOpenManageCategories;
  final VoidCallback? onOpenCsvImport;
  final VoidCallback onCancelEdit;
  final VoidCallback onShowCustomNoteDialog;
  final ValueChanged<String> onToggleQuickNote;
  final ValueChanged<String> onDeletePredefinedNote;
  final VoidCallback onAddPredefinedNote;
  final VoidCallback onShowCartBottomSheet;
  final VoidCallback onClearCart;
  final void Function({bool immediatePayment, String? directPaymentMethod}) onFireOrder;
  final ValueChanged<MenuItem> onMenuItemTap;
  final ValueChanged<MenuItem>? onMenuItemLongPress;

  const TakeOrderPanel({
    super.key,
    required this.controller,
    required this.getCategoryColor,
    required this.collapsedCategories,
    required this.onToggleCategoryCollapse,
    required this.customerNameController,
    required this.orderNotesController,
    required this.isParcel,
    required this.onParcelChanged,
    this.onOpenManageCategories,
    this.onOpenCsvImport,
    required this.onCancelEdit,
    required this.onShowCustomNoteDialog,
    required this.onToggleQuickNote,
    required this.onDeletePredefinedNote,
    required this.onAddPredefinedNote,
    required this.onShowCartBottomSheet,
    required this.onClearCart,
    required this.onFireOrder,
    required this.onMenuItemTap,
    this.onMenuItemLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final categories = controller.categories;
    final grouped = controller.groupedMenu;
    final menu = controller.menu;
    final cart = controller.cart;

    return Column(
      children: [
        // Category Filter Bar
        if (menu.isNotEmpty && categories.length > 1)
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length + (onOpenManageCategories != null ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                if (i == categories.length && onOpenManageCategories != null) {
                  return ActionChip(
                    avatar: Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    label: const Text(
                      'Manage Categories',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    tooltip: 'Manage Category Options & Surcharges',
                    onPressed: onOpenManageCategories,
                  );
                }

                final cat = categories[i];
                final isSelected = controller.selectedCategory == cat;
                final catColor = getCategoryColor(cat);
                final catConfig = controller.getCategoryConfig(cat);
                final hasCost = catConfig?.hasAdditionalCost == true;
                final displayCat = cat == 'All' ? 'All' : controller.getCategoryDisplayName(cat);

                return Tooltip(
                  message: cat == 'All' ? 'Show all items' : displayCat,
                  child: ChoiceChip(
                    avatar: cat == 'All'
                        ? null
                        : Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: catColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                    label: Text(
                      hasCost
                          ? '$displayCat (+₹${catConfig!.additionalCost.toStringAsFixed(catConfig.additionalCost.truncateToDouble() == catConfig.additionalCost ? 0 : 2)})'
                          : displayCat,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                        fontSize: 14,
                        color: isSelected ? catColor : null,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: catColor.withAlpha(45),
                    side: BorderSide(
                      color: isSelected ? catColor : catColor.withAlpha(90),
                      width: isSelected ? 1.8 : 1,
                    ),
                    showCheckmark: false,
                    onSelected: (selected) {
                      if (selected) {
                        controller.selectCategory(cat);
                      }
                    },
                  ),
                );
              },
            ),
          ),

          // Dietary Type Quick Filters (All, Veg, Non-Veg)
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              children: [
                _buildDietaryFilterChip(
                  context,
                  label: 'All',
                  isSelected: controller.selectedDietaryType == null,
                  onTap: () => controller.selectDietary(null),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                _buildDietaryFilterChip(
                  context,
                  label: 'Veg',
                  isSelected: controller.selectedDietaryType == ItemDietaryType.veg,
                  onTap: () => controller.selectDietary(
                    controller.selectedDietaryType == ItemDietaryType.veg ? null : ItemDietaryType.veg,
                  ),
                  dietaryType: ItemDietaryType.veg,
                  color: const Color(0xFF2E7D32),
                ),
                const SizedBox(width: 8),
                _buildDietaryFilterChip(
                  context,
                  label: 'Non-Veg',
                  isSelected: controller.selectedDietaryType == ItemDietaryType.nonVeg,
                  onTap: () => controller.selectDietary(
                    controller.selectedDietaryType == ItemDietaryType.nonVeg ? null : ItemDietaryType.nonVeg,
                  ),
                  dietaryType: ItemDietaryType.nonVeg,
                  color: const Color(0xFFC62828),
                ),
              ],
            ),
          ),

        // Menu item list with Expandable Accordion Categories
        Expanded(
          flex: 6,
          child: menu.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu_rounded,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No menu items yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configure menu items and categories in Store Admin',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : grouped.isEmpty
                  ? Center(
                      child: Text(
                        'No items in category "${controller.selectedCategory}"',
                        style: const TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: grouped.entries.map((entry) {
                          final category = entry.key;
                          final items = entry.value;
                          final catConfig = controller.getCategoryConfig(category);

                          return CategoryAccordionCard(
                            catName: category,
                            items: items,
                            isExpanded: !collapsedCategories.contains(category),
                            costDescription: catConfig?.costDescription,
                            onConfigure: null,
                            onToggle: () => onToggleCategoryCollapse(category),
                            getCategoryColor: getCategoryColor,
                            itemCardBuilder: (item) => MenuItemCard(
                              item: item,
                              cart: cart,
                              getCategoryColor: getCategoryColor,
                              onTap: () => onMenuItemTap(item),
                              onLongPress: onMenuItemLongPress != null
                                  ? () => onMenuItemLongPress!(item)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
        ),

        // Cart Drawer / Summary
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Active Editing Banner
              if (controller.isEditing)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade700),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        size: 20,
                        color: Colors.amber.shade900,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Editing Order #${controller.editingOrderId}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: onCancelEdit,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Cancel Edit'),
                      ),
                    ],
                  ),
                ),

              // Customer Name & Order Mode (Dine In / Parcel)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: customerNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Customer Name (Optional)',
                          hintText: 'Customer Name (Optional)',
                          prefixIcon: const Icon(Icons.person_outline, size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SegmentedButton<bool>(
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      segments: const [
                        ButtonSegment<bool>(
                          value: false,
                          icon: Icon(Icons.restaurant, size: 14),
                          label: Text('Dine In', style: TextStyle(fontSize: 11)),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          icon: Icon(Icons.takeout_dining, size: 14),
                          label: Text('Parcel', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                      selected: {isParcel},
                      onSelectionChanged: (Set<bool> newSelection) {
                        onParcelChanged(newSelection.first);
                      },
                    ),
                  ],
                ),
              ),

              // Quick Notes Bar (Custom Note + Predefined Quick Toggle Chips)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      if (orderNotesController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InputChip(
                            avatar: const Icon(Icons.sticky_note_2_outlined, size: 14),
                            label: Text(
                              orderNotesController.text,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            selected: true,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onPressed: onShowCustomNoteDialog,
                            onDeleted: () {
                              orderNotesController.clear();
                            },
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            avatar: const Icon(Icons.note_alt_outlined, size: 14),
                            label: const Text('Add Note', style: TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onPressed: onShowCustomNoteDialog,
                          ),
                        ),
                      ...controller.predefinedNotes.map((note) {
                        final isApplied = orderNotesController.text
                            .toLowerCase()
                            .contains(note.toLowerCase());
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Tooltip(
                            message: 'Tap to toggle • Long press to remove',
                            child: GestureDetector(
                              onLongPress: () => onDeletePredefinedNote(note),
                              child: FilterChip(
                                label: Text(
                                  note,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isApplied ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                selected: isApplied,
                                onSelected: (_) => onToggleQuickNote(note),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                              ),
                            ),
                          ),
                        );
                      }),
                      ActionChip(
                        avatar: const Icon(Icons.note_add_outlined, size: 14),
                        label: const Text(
                          '+ Note',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: onAddPredefinedNote,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ],
                  ),
                ),
              ),

              // Cart Items Bar (taps to open bottomsheet)
              if (cart.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: onShowCartBottomSheet,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Items in Cart (${controller.cartItemCount})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  cart.entries
                                      .map((e) {
                                        final displayName =
                                            controller.getCartItemDisplayName(e.key);
                                        return '${e.value}x $displayName';
                                      })
                                      .join(', '),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonalIcon(
                            onPressed: onShowCartBottomSheet,
                            icon: const Icon(
                              Icons.expand_less_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'View Cart',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: onClearCart,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),

              // Order Confirmation Action Buttons: Single row for fast checkout & punch order
              if (!controller.isEditing)
                if (cart.isNotEmpty)
                  Row(
                    children: [
                      // 1-Tap Fast Cash Checkout
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            key: const ValueKey('fast_cash_btn'),
                            onPressed: () => onFireOrder(
                              immediatePayment: true,
                              directPaymentMethod: 'Cash',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.teal.shade700,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                            icon: const Icon(Icons.payments_rounded, size: 18),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Cash',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 1-Tap Fast UPI Checkout
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            key: const ValueKey('fast_upi_btn'),
                            onPressed: () => onFireOrder(
                              immediatePayment: true,
                              directPaymentMethod: 'UPI',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.indigo.shade700,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                            icon: const Icon(Icons.qr_code_rounded, size: 18),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'UPI',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Punch Order (Pay Later) Button
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: () => onFireOrder(),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                            ),
                            icon: const Icon(
                              Icons.bolt,
                              size: 20,
                            ),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'PUNCH ORDER (#${controller.nextToken}) • ₹${controller.cartTotal.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      // 1-Step Pay & Punch Button
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: null,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            icon: const Icon(
                              Icons.payment_rounded,
                              size: 20,
                            ),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'PAY & PUNCH (1-STEP)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Punch Order (Pay Later) Button
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: null,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            icon: const Icon(
                              Icons.bolt,
                              size: 22,
                            ),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'TAP ITEMS TO START (#${controller.nextToken})',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
              else
                // Primary Update Button when editing
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: cart.isNotEmpty ? () => onFireOrder() : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.update_rounded,
                      size: 26,
                    ),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        cart.isEmpty
                            ? 'TAP ITEMS TO UPDATE (#${controller.editingOrderId})'
                            : 'Update Order #${controller.editingOrderId} • ₹${controller.cartTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDietaryFilterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
    ItemDietaryType? dietaryType,
  }) {
    return ChoiceChip(
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
}
