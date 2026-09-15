import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/order_controller.dart';
import '../../models/stall_models.dart';
import 'addons_for_cart_item_modal.dart';
import 'dietary_symbol.dart';

/// Unified Item Customizer Bottom Sheet.
///
/// Combines variant / option selection (e.g. 'Small' / 'Large', 'Rice' / 'Noodles')
/// and applicable add-ons (e.g. 'Extra Cheese', 'Sauce') into a single, cohesive
/// bottom sheet with live price computation and a 1-tap "Add to Cart" action.
/// Eliminates nested modal stacking.
class ItemCustomizerSheet {
  ItemCustomizerSheet._();

  static Future<void> show(
    BuildContext context, {
    required MenuItem item,
    required OrderController controller,
    required Color Function(String category) getCategoryColor,
    MenuItem? targetBaseItem,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _ItemCustomizerContent(
        item: item,
        controller: controller,
        getCategoryColor: getCategoryColor,
        targetBaseItem: targetBaseItem,
      ),
    );
  }
}

class _ItemCustomizerContent extends StatefulWidget {
  final MenuItem item;
  final OrderController controller;
  final Color Function(String category) getCategoryColor;
  final MenuItem? targetBaseItem;

  const _ItemCustomizerContent({
    required this.item,
    required this.controller,
    required this.getCategoryColor,
    this.targetBaseItem,
  });

  @override
  State<_ItemCustomizerContent> createState() => _ItemCustomizerContentState();
}

class _ItemCustomizerContentState extends State<_ItemCustomizerContent> {
  // Variant selection state
  late List<CategoryOption> _variants;
  CategoryOption? _selectedVariant;
  String? _selectedCategory;

  // Add-ons state (addonId -> quantity)
  final Map<String, int> _selectedAddons = {};
  late List<MenuItem> _availableAddons;

  // Add-on linking state (if this item is an add-on)
  MenuItem? _selectedBaseItem;
  int _addonItemQty = 1;

  @override
  void initState() {
    super.initState();
    final categoryOptions = widget.item.category.options.isNotEmpty
        ? widget.item.category.options
        : (widget.controller.getCategoryConfig(widget.item.categoryName)?.options ??
            const <CategoryOption>[]);

    final slashCats = widget.item.hasSlashCategoryVariants
        ? widget.item.slashCategoryVariants.map((s) => s.trim().toLowerCase()).toSet()
        : const <String>{};
    final slashNames = widget.item.hasSlashNameVariants
        ? widget.item.slashNameVariants.map((s) => s.trim().toLowerCase()).toSet()
        : const <String>{};

    final combined = <CategoryOption>[];
    final seen = <String>{};

    for (final v in widget.item.variants) {
      final norm = v.name.trim().toLowerCase();
      if (!slashCats.contains(norm) && !slashNames.contains(norm) && seen.add(norm)) {
        combined.add(v);
      }
    }
    for (final o in categoryOptions) {
      final norm = o.name.trim().toLowerCase();
      if (!slashCats.contains(norm) && !slashNames.contains(norm) && seen.add(norm)) {
        combined.add(o);
      }
    }

    _variants = combined;

    if (_variants.isNotEmpty) {
      final available = _variants.where((v) => v.isAvailable).toList();
      _selectedVariant = available.isNotEmpty ? available.first : null;
    }

    if (widget.item.hasSlashCategoryVariants && !widget.item.hasSlashNameVariants) {
      _selectedCategory = widget.item.slashCategoryVariants.first;
    }

    if (widget.item.effectiveIsAddon) {
      final baseItems = widget.controller.cartBaseItems.where((b) {
        return widget.item.isApplicableToCategory(b.categoryName);
      }).toList();
      _selectedBaseItem = widget.targetBaseItem ??
          (baseItems.isNotEmpty ? baseItems.first : null);
      _availableAddons = [];
    } else {
      // Find add-ons applicable to this item's category
      _availableAddons = widget.controller.getAddonsForCategory(
        widget.item.categoryName,
      );
    }
  }

  double get _currentUnitPrice {
    if (widget.item.effectiveIsAddon) {
      return widget.item.price * _addonItemQty;
    }

    final variantPrice = widget.item.priceForVariant(_selectedVariant);
    final category = _selectedCategory ?? widget.item.categoryName;
    final catCost = widget.controller.getCategoryCost(category);

    double addonsTotal = 0.0;
    _selectedAddons.forEach((addonId, qty) {
      if (qty > 0) {
        final addon = widget.controller.findItem(addonId);
        addonsTotal += addon.price * qty;
      }
    });

    return variantPrice + catCost + addonsTotal;
  }

  void _onAddToCart() {
    HapticFeedback.mediumImpact();

    if (_variants.isNotEmpty &&
        !widget.item.effectiveIsAddon &&
        (_selectedVariant == null || !_selectedVariant!.isAvailable)) {
      return;
    }

    if (widget.item.effectiveIsAddon) {
      // Link addon to selected base item
      final target = _selectedBaseItem;
      if (target != null) {
        final resolvedName = _selectedVariant?.name;
        widget.controller.addAddonToCart(
          targetCartItemId: target.id,
          addon: widget.item,
          resolvedAddonName: resolvedName,
          quantity: _addonItemQty,
        );
      }
    } else {
      // 1. Add base/variant item
      final resolvedName = _selectedVariant?.name != widget.item.name
          ? _selectedVariant?.name
          : null;
      final resolvedCategory = _selectedCategory != widget.item.categoryName
          ? _selectedCategory
          : null;

      widget.controller.addCustomizedItemToCart(
        baseItem: widget.item,
        resolvedName: resolvedName,
        resolvedCategory: resolvedCategory,
      );

      // 2. Add any selected add-ons
      if (_selectedAddons.isNotEmpty) {
        // Resolve the cart key of the newly added base item
        final baseKey = widget.controller.cartBaseItems.lastOrNull?.id;
        if (baseKey != null) {
          _selectedAddons.forEach((addonId, qty) {
            if (qty > 0) {
              final addon = widget.controller.findItem(addonId);
              widget.controller.addAddonToCart(
                targetCartItemId: baseKey,
                addon: addon,
                quantity: qty,
              );
            }
          });
        }
      }
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final itemColor = widget.item.colorHex != null
        ? Color(widget.item.colorHex!)
        : widget.getCategoryColor(widget.item.categoryName);

    final isAddon = widget.item.effectiveIsAddon;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: itemColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            DietarySymbol(
                              type: widget.item.effectiveDietaryType,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.item.displayName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          isAddon
                              ? 'Extra / Add-on • ₹${widget.item.price.toStringAsFixed(0)} each'
                              : 'Base: ₹${widget.item.price.toStringAsFixed(0)} • ${widget.item.categoryName}',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Options Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Variants & Options
                    if (_variants.isNotEmpty && !isAddon) ...[
                      Text(
                        'SELECT OPTION / SIZE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _variants.map((variant) {
                          final isVarAvailable = variant.isAvailable;
                          final isSelected = isVarAvailable &&
                              (_selectedVariant?.id == variant.id ||
                                  _selectedVariant?.name == variant.name);
                          final variantPrice = widget.item.priceForVariant(variant);

                          return ChoiceChip(
                            key: ValueKey('variant_chip_${variant.name}'),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DietarySymbol(
                                  type: variant.dietaryType ??
                                      ItemDietaryType.infer(
                                        name: variant.name,
                                        category: widget.item.categoryName,
                                      ),
                                  size: 12,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  variant.name,
                                  style: TextStyle(
                                    decoration: isVarAvailable
                                        ? null
                                        : TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isVarAvailable
                                      ? '₹${variantPrice.toStringAsFixed(0)}'
                                      : 'Sold Out',
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 12,
                                    color: isVarAvailable
                                        ? (isSelected
                                            ? (isDark ? Colors.white : Colors.black87)
                                            : theme.colorScheme.onSurfaceVariant)
                                        : Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                            selected: isSelected,
                            onSelected: isVarAvailable
                                ? (selected) {
                                    if (selected) {
                                      HapticFeedback.selectionClick();
                                      setState(() => _selectedVariant = variant);
                                    }
                                  }
                                : null,
                            selectedColor: itemColor.withAlpha(50),
                            side: BorderSide(
                              color: isSelected ? itemColor : theme.colorScheme.outlineVariant,
                              width: isSelected ? 1.8 : 1,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Section 2: Category Variants (if category has slashes, e.g. Rice / Noodles)
                    if (widget.item.hasSlashCategoryVariants &&
                        !widget.item.hasSlashNameVariants &&
                        !isAddon) ...[
                      Text(
                        'CHOOSE CATEGORY PREFERENCE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: widget.item.slashCategoryVariants.map((cat) {
                          final isSelected = _selectedCategory == cat;
                          final extraCost = widget.controller.getCategoryCost(cat);

                          return ChoiceChip(
                            key: ValueKey('cat_choice_$cat'),
                            label: Text(
                              extraCost > 0
                                  ? '$cat (+₹${extraCost.toStringAsFixed(0)})'
                                  : cat,
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedCategory = cat);
                              }
                            },
                            selectedColor: itemColor.withAlpha(50),
                            side: BorderSide(
                              color: isSelected ? itemColor : theme.colorScheme.outlineVariant,
                              width: isSelected ? 1.8 : 1,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Section 3: Add-on Modifiers (if main item has applicable add-ons)
                    if (_availableAddons.isNotEmpty && !isAddon) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CUSTOMIZE EXTRAS / ADD-ONS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'Max 2 per extra',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._availableAddons.map((addon) {
                        final currentQty = _selectedAddons[addon.id] ?? 0;
                        return AddonQuantityRow(
                          title: addon.displayName,
                          price: addon.price,
                          qty: currentQty,
                          dietaryType: addon.effectiveDietaryType,
                          canIncrement: currentQty < OrderController.maxPerAddonItem,
                          onChanged: (newQty) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (newQty <= 0) {
                                _selectedAddons.remove(addon.id);
                              } else {
                                _selectedAddons[addon.id] = newQty;
                              }
                            });
                          },
                        );
                      }),
                      const SizedBox(height: 10),
                    ],

                    // Section 4: If this item is an Addon, choose target item & quantity
                    if (isAddon) ...[
                      Text(
                        'QUANTITY TO ADD',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      AddonQuantityRow(
                        title: widget.item.name,
                        price: widget.item.price,
                        qty: _addonItemQty,
                        dietaryType: widget.item.effectiveDietaryType,
                        canIncrement: _addonItemQty < OrderController.maxPerAddonItem,
                        onChanged: (newQty) {
                          if (newQty >= 1) {
                            HapticFeedback.selectionClick();
                            setState(() => _addonItemQty = newQty);
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      if (widget.controller.cartBaseItems.length > 1) ...[
                        Text(
                          'LINK TO ITEM IN CART',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...widget.controller.cartBaseItems.map((base) {
                          final isSelected = _selectedBaseItem?.id == base.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedBaseItem = base);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Ink(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? itemColor.withAlpha(30)
                                      : theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? itemColor
                                        : theme.colorScheme.outlineVariant,
                                    width: isSelected ? 1.8 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off,
                                      color: isSelected
                                          ? itemColor
                                          : theme.colorScheme.outline,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        base.displayName,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '₹${base.price.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: theme.colorScheme.onSurfaceVariant,
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
                  ],
                ),
              ),
            ),

            // Bottom Sticky Action Button
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withAlpha(120),
                  ),
                ),
              ),
              child: Builder(
                builder: (context) {
                  final allVariantsSoldOut =
                      _variants.isNotEmpty && !isAddon && _selectedVariant == null;

                  return FilledButton(
                    key: const ValueKey('customizer_add_to_cart_btn'),
                    style: FilledButton.styleFrom(
                      backgroundColor: allVariantsSoldOut
                          ? theme.colorScheme.outlineVariant
                          : itemColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: allVariantsSoldOut ? null : _onAddToCart,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          allVariantsSoldOut
                              ? Icons.block_rounded
                              : Icons.add_shopping_cart_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          allVariantsSoldOut
                              ? 'All Variants Sold Out'
                              : 'Add to Order • ₹${_currentUnitPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
