import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/order_controller.dart';
import '../../models/stall_models.dart';
import 'dietary_symbol.dart';
export 'addons_for_cart_item_modal.dart';

/// Modal for choosing options for items containing '/' in name or category,
/// or customizing add-ons linked to main items.
class SlashSelectionModal {
  SlashSelectionModal._();

  static void show(
    BuildContext context, {
    required MenuItem item,
    required OrderController controller,
    required Color Function(String category) getCategoryColor,
  }) {
    final isAddon = item.effectiveIsAddon;
    final hasNameVariants = item.hasSlashNameVariants;
    final nameVariants = item.slashNameVariants;
    final hasCategoryVariants = item.hasSlashCategoryVariants;
    final categoryVariants = item.slashCategoryVariants;
    final baseItems = isAddon
        ? controller.cartBaseItems.where((b) {
            if (!item.isApplicableToCategory(b.categoryName)) return false;
            if (hasNameVariants) {
              return nameVariants.any((v) =>
                  controller.getAddonItemCount(b.id, item.id, resolvedAddonName: v) <
                  OrderController.maxPerAddonItem);
            }
            return controller.getAddonItemCount(b.id, item.id) <
                OrderController.maxPerAddonItem;
          }).toList()
        : <MenuItem>[];

    // Add-on state: quantity stepper or multi-variant quantities
    int singleAddonQty = 1;
    final Map<String, int> variantQuantities = {
      for (final v in nameVariants) v: (v == nameVariants.first ? 1 : 0),
    };
    MenuItem? selectedBaseItem = baseItems.isNotEmpty ? baseItems.first : null;

    // Regular item selection state
    String selectedName = nameVariants.isNotEmpty ? nameVariants.first : item.name;
    String selectedCategory = categoryVariants.isNotEmpty ? categoryVariants.first : item.categoryName;

    final itemColor = item.colorHex != null
        ? Color(item.colorHex!)
        : getCategoryColor(item.categoryName);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final target = selectedBaseItem ?? (baseItems.isNotEmpty ? baseItems.first : null);
            final existingSingleAddonCount = target != null
                ? controller.getAddonItemCount(target.id, item.id)
                : 0;
            final maxAllowedForSingleAddon = (OrderController.maxPerAddonItem - existingSingleAddonCount)
                .clamp(0, OrderController.maxPerAddonItem);

            int totalAddonCount = 0;
            double totalAddonPrice = 0.0;
            String addonSummaryStr = '';

            if (isAddon) {
              if (hasNameVariants) {
                totalAddonCount = variantQuantities.values.fold(0, (a, b) => a + b);
                totalAddonPrice = totalAddonCount * item.price;
                final parts = <String>[];
                variantQuantities.forEach((v, q) {
                  if (q > 0) parts.add(q > 1 ? '${q}x $v' : v);
                });
                addonSummaryStr = parts.map((p) => '[$p]').join(' ');
              } else {
                totalAddonCount = singleAddonQty;
                totalAddonPrice = singleAddonQty * item.price;
                addonSummaryStr = singleAddonQty > 1
                    ? '[${singleAddonQty}x ${item.name}]'
                    : '[${item.name}]';
              }
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(60),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isAddon
                          ? 'Customize Extra'
                          : (hasCategoryVariants && !hasNameVariants
                              ? 'Select Category'
                              : 'Select Option'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DietarySymbol(
                          type: item.effectiveDietaryType,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            isAddon
                                ? '${item.displayName} • +₹${item.price.toStringAsFixed(0)} each'
                                : '${item.displayName} • ₹${item.price.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (isAddon && hasNameVariants) ...[
                              Text(
                                'CHOOSE EXTRAS & QUANTITIES',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...nameVariants.map((variant) {
                                final qty = variantQuantities[variant] ?? 0;
                                final existingForVariant = target != null
                                    ? controller.getAddonItemCount(target.id, item.id, resolvedAddonName: variant)
                                    : 0;
                                final maxForVariant = (OrderController.maxPerAddonItem - existingForVariant)
                                    .clamp(0, OrderController.maxPerAddonItem);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: qty > 0
                                        ? itemColor.withAlpha(25)
                                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: qty > 0 ? itemColor : Theme.of(context).colorScheme.outlineVariant,
                                      width: qty > 0 ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                DietarySymbol(
                                                  type: ItemDietaryType.infer(
                                                    name: variant,
                                                    category: item.categoryName,
                                                  ),
                                                  size: 13,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    variant,
                                                    style: TextStyle(
                                                      fontWeight: qty > 0
                                                          ? FontWeight.bold
                                                          : FontWeight.w600,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              '+₹${item.price.toStringAsFixed(0)} each',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.surface,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Theme.of(context).colorScheme.outlineVariant,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove, size: 16),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                              onPressed: qty > 0
                                                  ? () {
                                                      setModalState(() {
                                                        variantQuantities[variant] = qty - 1;
                                                      });
                                                      HapticFeedback.selectionClick();
                                                    }
                                                  : null,
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 6),
                                              child: Text(
                                                '$qty',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: qty > 0 ? itemColor : null,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.add, size: 16),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                              onPressed: qty < maxForVariant
                                                  ? () {
                                                      setModalState(() {
                                                        variantQuantities[variant] = qty + 1;
                                                      });
                                                      HapticFeedback.selectionClick();
                                                    }
                                                  : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 14),
                            ],
                            if (isAddon && !hasNameVariants) ...[
                              Text(
                                'SELECT QUANTITY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: itemColor.withAlpha(20),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: itemColor, width: 1.5),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            '+₹${item.price.toStringAsFixed(0)} each',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surface,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.outlineVariant,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove, size: 16),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                            onPressed: singleAddonQty > 1
                                                ? () {
                                                    setModalState(() {
                                                      singleAddonQty--;
                                                    });
                                                    HapticFeedback.selectionClick();
                                                  }
                                                : null,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Text(
                                              '$singleAddonQty',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: itemColor,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add, size: 16),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                            onPressed: singleAddonQty < maxAllowedForSingleAddon
                                                ? () {
                                                    setModalState(() {
                                                      singleAddonQty++;
                                                    });
                                                    HapticFeedback.selectionClick();
                                                  }
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            if (isAddon && baseItems.isNotEmpty) ...[
                              Text(
                                baseItems.length > 1 ? 'LINK TO MAIN ITEM' : 'TARGET MAIN ITEM',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...baseItems.map((baseItem) {
                                final isSelected = target?.id == baseItem.id;
                                final inCartCount = controller.cart[baseItem.id] ?? 1;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    onTap: () {
                                      setModalState(() {
                                        selectedBaseItem = baseItem;
                                      });
                                      HapticFeedback.selectionClick();
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Ink(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? itemColor.withAlpha(25)
                                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? itemColor : Theme.of(context).colorScheme.outlineVariant,
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                            color: isSelected ? itemColor : Theme.of(context).colorScheme.outline,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  baseItem.displayName,
                                                  style: TextStyle(
                                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                Text(
                                                  '$inCartCount in cart • ₹${baseItem.price.toStringAsFixed(0)} each',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                            if (!isAddon && hasCategoryVariants && !hasNameVariants) ...[
                              Text(
                                'SELECT CATEGORY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...categoryVariants.map((cat) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    key: ValueKey('cat_choice_$cat'),
                                    onTap: () {
                                      Navigator.pop(sheetContext);
                                      HapticFeedback.selectionClick();
                                      controller.addCustomizedItemToCart(
                                        baseItem: item,
                                        resolvedCategory: cat,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Ink(
                                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: itemColor.withAlpha(60),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.restaurant_menu,
                                            color: itemColor,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  cat,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                if (controller.getCategoryCost(cat) > 0)
                                                  Text(
                                                    '+₹${controller.getCategoryCost(cat).toStringAsFixed(0)} ${controller.getCategoryCostReason(cat) ?? 'extra'}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.deepOrange.shade700,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '₹${(item.price + controller.getCategoryCost(cat)).toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: itemColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                            if (!isAddon && hasNameVariants && !hasCategoryVariants) ...[
                              Text(
                                'SELECT ITEM OPTION',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...nameVariants.map((variant) {
                                final matchingOption = item.effectiveVariants
                                    .cast<CategoryOption?>()
                                    .firstWhere(
                                      (v) =>
                                          v?.name.trim().toLowerCase() ==
                                          variant.trim().toLowerCase(),
                                      orElse: () => null,
                                    );
                                final isVarAvailable = matchingOption?.isAvailable ?? true;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    key: ValueKey('name_choice_$variant'),
                                    onTap: isVarAvailable
                                        ? () {
                                            Navigator.pop(sheetContext);
                                            HapticFeedback.selectionClick();
                                            controller.addCustomizedItemToCart(
                                              baseItem: item,
                                              resolvedName: variant,
                                            );
                                          }
                                        : null,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Ink(
                                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: isVarAvailable
                                            ? Theme.of(context).colorScheme.surfaceContainerHighest
                                            : Colors.red.withAlpha(15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isVarAvailable
                                              ? itemColor.withAlpha(60)
                                              : Colors.red.withAlpha(60),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isVarAvailable
                                                ? Icons.radio_button_off
                                                : Icons.cancel_rounded,
                                            color: isVarAvailable
                                                ? itemColor
                                                : Colors.red.shade700,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          DietarySymbol(
                                            type: matchingOption?.dietaryType ??
                                                ItemDietaryType.infer(
                                                  name: variant,
                                                  category: item.categoryName,
                                                ),
                                            size: 14,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              isVarAvailable ? variant : '$variant (Sold Out)',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                                decoration: isVarAvailable
                                                    ? null
                                                    : TextDecoration.lineThrough,
                                                color: isVarAvailable
                                                    ? null
                                                    : Theme.of(context).colorScheme.outline,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '₹${item.price.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: isVarAvailable
                                                  ? itemColor
                                                  : Theme.of(context).colorScheme.outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                            if (!isAddon && hasNameVariants && hasCategoryVariants) ...[
                              Text(
                                'SELECT ITEM OPTION',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...nameVariants.map((variant) {
                                final isSelected = selectedName == variant;
                                final matchingOption = item.effectiveVariants
                                    .cast<CategoryOption?>()
                                    .firstWhere(
                                      (v) =>
                                          v?.name.trim().toLowerCase() ==
                                          variant.trim().toLowerCase(),
                                      orElse: () => null,
                                    );
                                final isVarAvailable = matchingOption?.isAvailable ?? true;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    key: ValueKey('both_name_$variant'),
                                    onTap: isVarAvailable
                                        ? () {
                                            setModalState(() {
                                              selectedName = variant;
                                            });
                                            HapticFeedback.selectionClick();
                                          }
                                        : null,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Ink(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: isVarAvailable
                                            ? (isSelected
                                                ? itemColor.withAlpha(25)
                                                : Theme.of(context).colorScheme.surfaceContainerHighest)
                                            : Colors.red.withAlpha(15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isVarAvailable
                                              ? (isSelected ? itemColor : itemColor.withAlpha(60))
                                              : Colors.red.withAlpha(60),
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isVarAvailable
                                                ? (isSelected ? Icons.radio_button_checked : Icons.radio_button_off)
                                                : Icons.cancel_rounded,
                                            color: isVarAvailable
                                                ? (isSelected ? itemColor : Theme.of(context).colorScheme.outline)
                                                : Colors.red.shade700,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          DietarySymbol(
                                            type: matchingOption?.dietaryType ??
                                                ItemDietaryType.infer(
                                                  name: variant,
                                                  category: item.categoryName,
                                                ),
                                            size: 14,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              isVarAvailable ? variant : '$variant (Sold Out)',
                                              style: TextStyle(
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                fontSize: 15,
                                                decoration: isVarAvailable
                                                    ? null
                                                    : TextDecoration.lineThrough,
                                                color: isVarAvailable
                                                    ? null
                                                    : Theme.of(context).colorScheme.outline,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: 14),
                              Text(
                                'SELECT CATEGORY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...categoryVariants.map((cat) {
                                final isSelected = selectedCategory == cat;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    key: ValueKey('both_cat_$cat'),
                                    onTap: () {
                                      setModalState(() {
                                        selectedCategory = cat;
                                      });
                                      HapticFeedback.selectionClick();
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Ink(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? itemColor.withAlpha(25)
                                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? itemColor : itemColor.withAlpha(60),
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                            color: isSelected ? itemColor : Theme.of(context).colorScheme.outline,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  cat,
                                                  style: TextStyle(
                                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                if (controller.getCategoryCost(cat) > 0)
                                                  Text(
                                                    '+₹${controller.getCategoryCost(cat).toStringAsFixed(0)} ${controller.getCategoryCostReason(cat) ?? 'extra'}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.deepOrange.shade700,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '₹${(item.price + controller.getCategoryCost(cat)).toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: itemColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (!isAddon && hasNameVariants && hasCategoryVariants) ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        key: const ValueKey('confirm_add_both_variants'),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          HapticFeedback.selectionClick();
                          controller.addCustomizedItemToCart(
                            baseItem: item,
                            resolvedName: selectedName,
                            resolvedCategory: selectedCategory,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: itemColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Add $selectedName ($selectedCategory) • ₹${(item.price + controller.getCategoryCost(selectedCategory)).toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ],
                    if (isAddon) ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: totalAddonCount > 0 && target != null
                            ? () {
                                Navigator.pop(sheetContext);
                                HapticFeedback.selectionClick();
                                if (hasNameVariants) {
                                  final listToAdd = <({MenuItem addon, String? resolvedName, int quantity})>[];
                                  variantQuantities.forEach((v, q) {
                                    if (q > 0) {
                                      listToAdd.add((addon: item, resolvedName: v, quantity: q));
                                    }
                                  });
                                  controller.addMultipleAddonsToCart(
                                    targetCartItemId: target.id,
                                    addons: listToAdd,
                                  );
                                } else {
                                  controller.addAddonToCart(
                                    targetCartItemId: target.id,
                                    addon: item,
                                    quantity: singleAddonQty,
                                  );
                                }
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Added $addonSummaryStr to ${target.displayName}'),
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: itemColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          target != null
                              ? 'Add $addonSummaryStr to ${target.displayName} • +₹${totalAddonPrice.toStringAsFixed(0)}'
                              : 'Select a main item',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}


