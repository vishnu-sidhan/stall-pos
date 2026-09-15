import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/order_controller.dart';
import '../../models/stall_models.dart';
import 'addons_for_cart_item_modal.dart';
import 'dietary_symbol.dart';

/// Unified Item Customizer Bottom Sheet.
///
/// Combines variant/option selection, slash choices, applicable add-ons, and
/// quantity adjustments into a single bottom sheet with real-time price updates
/// and a 1-tap "Add to Cart • ₹XXX" action. Eliminates modal explosion and
/// sequential chained dialogs.
class UnifiedItemCustomizerSheet extends StatefulWidget {
  final MenuItem item;
  final OrderController controller;
  final Color Function(String category) getCategoryColor;
  final MenuItem? targetBaseItem;
  final String buttonLabel;
  final String? initialCartItemId;
  final int? initialQuantity;
  final VoidCallback? onItemUpdated;

  const UnifiedItemCustomizerSheet({
    super.key,
    required this.item,
    required this.controller,
    required this.getCategoryColor,
    this.targetBaseItem,
    this.buttonLabel = 'Add to Cart',
    this.initialCartItemId,
    this.initialQuantity,
    this.onItemUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required MenuItem item,
    required OrderController controller,
    required Color Function(String category) getCategoryColor,
    MenuItem? targetBaseItem,
    String? buttonLabel,
    String? initialCartItemId,
    int? initialQuantity,
    VoidCallback? onItemUpdated,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => UnifiedItemCustomizerSheet(
        item: item,
        controller: controller,
        getCategoryColor: getCategoryColor,
        targetBaseItem: targetBaseItem,
        buttonLabel: buttonLabel ?? 'Add to Cart',
        initialCartItemId: initialCartItemId,
        initialQuantity: initialQuantity,
        onItemUpdated: onItemUpdated,
      ),
    );
  }

  @override
  State<UnifiedItemCustomizerSheet> createState() =>
      _UnifiedItemCustomizerSheetState();
}

class _UnifiedItemCustomizerSheetState
    extends State<UnifiedItemCustomizerSheet> {
  late List<CategoryOption> _variants;
  CategoryOption? _selectedVariant;
  String? _selectedSlashName;
  String? _selectedSlashCategory;

  // Add-ons state (addonId -> quantity)
  final Map<String, int> _selectedAddons = {};
  late List<MenuItem> _availableAddons;

  // Linking state (if item is an add-on)
  MenuItem? _selectedBaseItem;
  int _itemQuantity = 1;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuantity != null && widget.initialQuantity! > 0) {
      _itemQuantity = widget.initialQuantity!;
    }

    final categoryOptions = widget.item.category.options.isNotEmpty
        ? widget.item.category.options
        : (widget.controller.getCategoryConfig(widget.item.categoryName)?.options ??
            const <CategoryOption>[]);

    final slashNames = widget.item.hasSlashNameVariants
        ? widget.item.slashNameVariants.map((s) => s.trim().toLowerCase()).toSet()
        : const <String>{};
    final slashCats = widget.item.hasSlashCategoryVariants
        ? widget.item.slashCategoryVariants.map((s) => s.trim().toLowerCase()).toSet()
        : const <String>{};

    // Combine item variants and category options, deduplicating by normalized name
    final combined = <CategoryOption>[];
    final seen = <String>{};

    for (final v in widget.item.variants) {
      final norm = v.name.trim().toLowerCase();
      if (!slashNames.contains(norm) && !slashCats.contains(norm) && seen.add(norm)) {
        combined.add(v);
      }
    }
    for (final o in categoryOptions) {
      final norm = o.name.trim().toLowerCase();
      if (!slashNames.contains(norm) && !slashCats.contains(norm) && seen.add(norm)) {
        combined.add(o);
      }
    }

    _variants = combined;

    if (_variants.isNotEmpty) {
      final available = _variants.where((v) => v.isAvailable).toList();
      _selectedVariant = available.isNotEmpty ? available.first : null;
    }

    if (widget.item.hasSlashNameVariants) {
      _selectedSlashName = widget.item.slashNameVariants.first;
    }

    if (widget.item.hasSlashCategoryVariants) {
      _selectedSlashCategory = widget.item.slashCategoryVariants.first;
    }

    if (widget.item.effectiveIsAddon) {
      final baseItems = widget.controller.cartBaseItems.where((b) {
        return widget.item.isApplicableToCategory(b.categoryName);
      }).toList();
      _selectedBaseItem = widget.targetBaseItem ??
          (baseItems.isNotEmpty ? baseItems.first : null);
      _availableAddons = const [];
    } else {
      _availableAddons = widget.controller.getAddonsForCategory(
        widget.item.categoryName,
      );
    }
  }

  double get _currentUnitPrice {
    if (widget.item.effectiveIsAddon) {
      return widget.item.price;
    }

    final variantPrice = widget.item.priceForVariant(_selectedVariant);
    final category = _selectedSlashCategory ?? widget.item.categoryName;
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

  double get _totalPrice => _currentUnitPrice * _itemQuantity;

  bool get _canAddToCart {
    if (widget.item.effectiveIsAddon) {
      return _selectedBaseItem != null;
    }
    if (_variants.isNotEmpty) {
      return _selectedVariant != null && _selectedVariant!.isAvailable;
    }
    return true;
  }

  void _onAddToCart() {
    if (!_canAddToCart) return;
    HapticFeedback.mediumImpact();

    if (widget.initialCartItemId != null) {
      widget.controller.removeFromCart(widget.initialCartItemId!);
    }

    if (widget.item.effectiveIsAddon) {
      final target = _selectedBaseItem;
      if (target != null) {
        final resolvedName = _selectedSlashName ?? _selectedVariant?.name;
        widget.controller.addAddonToCart(
          targetCartItemId: target.id,
          addon: widget.item,
          resolvedAddonName: resolvedName,
          quantity: _itemQuantity,
        );
      }
    } else {
      final resolvedName = _selectedSlashName ??
          (_selectedVariant?.name != widget.item.name
              ? _selectedVariant?.name
              : null);
      final resolvedCategory = _selectedSlashCategory != widget.item.categoryName
          ? _selectedSlashCategory
          : null;

      for (int i = 0; i < _itemQuantity; i++) {
        widget.controller.addCustomizedItemToCart(
          baseItem: widget.item,
          resolvedName: resolvedName,
          resolvedCategory: resolvedCategory,
        );

        if (_selectedAddons.isNotEmpty) {
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
    }

    widget.onItemUpdated?.call();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemColor = widget.item.colorHex != null
        ? Color(widget.item.colorHex!)
        : widget.getCategoryColor(widget.item.categoryName);

    final isAddon = widget.item.effectiveIsAddon;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
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

            // Header
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
                                widget.item.hasSlashNameVariants
                                    ? 'Select Option'
                                    : widget.item.displayName,
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
                              ? 'Add-on • ₹${widget.item.price.toStringAsFixed(0)} each'
                              : '${widget.item.displayName} • ₹${widget.item.price.toStringAsFixed(0)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Scrollable Options Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Base item selector if item is an add-on
                    if (isAddon) ...[
                      Text(
                        'ATTACH TO ITEM IN CART',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBaseItemSelector(theme),
                      const SizedBox(height: 16),
                    ],

                    // SECTION 1: Variants & Options (Choice Chips)
                    if (_variants.isNotEmpty) ...[
                      Text(
                        'SELECT PREPARATION / VARIANT',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildVariantChips(theme, itemColor),
                      const SizedBox(height: 16),
                    ],

                    // Slash Name Variants (e.g. Rice / Noodles)
                    if (widget.item.hasSlashNameVariants) ...[
                      Text(
                        'SELECT CHOICE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.item.slashNameVariants.map((name) {
                          final isSelected = _selectedSlashName == name;
                          return ChoiceChip(
                            label: Text(name),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) setState(() => _selectedSlashName = name);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Slash Category Variants (e.g. Regular / Large)
                    if (widget.item.hasSlashCategoryVariants) ...[
                      Text(
                        'CATEGORY OPTION',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.item.slashCategoryVariants.map((cat) {
                          final isSelected = _selectedSlashCategory == cat;
                          final cost = widget.controller.getCategoryCost(cat);
                          final label = cost > 0 ? '$cat (+₹${cost.toStringAsFixed(0)})' : cat;
                          return ChoiceChip(
                            label: Text(label),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) setState(() => _selectedSlashCategory = cat);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // SECTION 2: Add-ons & Modifiers (Multi-choice)
                    if (!isAddon && _availableAddons.isNotEmpty) ...[
                      Text(
                        'ADD-ONS & MODIFIERS',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._availableAddons.map((addon) {
                        final qty = _selectedAddons[addon.id] ?? 0;
                        return AddonQuantityRow(
                          title: addon.displayName,
                          price: addon.price,
                          qty: qty,
                          dietaryType: addon.effectiveDietaryType,
                          canIncrement: qty < OrderController.maxPerAddonItem,
                          onChanged: (newQty) {
                            setState(() {
                              _selectedAddons[addon.id] = newQty;
                            });
                          },
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // SECTION 3: Quantity Stepper & Add to Cart Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  // Quantity Stepper
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
                          onPressed: _itemQuantity > 1
                              ? () => setState(() => _itemQuantity--)
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '$_itemQuantity',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
                          onPressed: _itemQuantity < 99
                              ? () => setState(() => _itemQuantity++)
                              : null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Prominent Action Button
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _canAddToCart ? _onAddToCart : null,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _canAddToCart
                              ? '${widget.buttonLabel} • ₹${_totalPrice.toStringAsFixed(0)}'
                              : 'Unavailable',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantChips(ThemeData theme, Color itemColor) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _variants.map((variant) {
        final isSelected = _selectedVariant?.id == variant.id;
        final isAvailable = variant.isAvailable;

        String labelText = variant.name;
        if (variant.costBadge.isNotEmpty) {
          labelText += ' (${variant.costBadge})';
        }
        if (!isAvailable) {
          labelText += ' • Sold Out';
        }

        return FilterChip(
          label: Text(labelText),
          selected: isSelected,
          onSelected: isAvailable
              ? (val) {
                  if (val) setState(() => _selectedVariant = variant);
                }
              : null,
          selectedColor: itemColor.withAlpha(50),
          checkmarkColor: itemColor,
          side: BorderSide(
            color: isSelected ? itemColor : theme.colorScheme.outlineVariant,
            width: isSelected ? 1.5 : 1,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBaseItemSelector(ThemeData theme) {
    final baseItems = widget.controller.cartBaseItems.where((b) {
      return widget.item.isApplicableToCategory(b.categoryName);
    }).toList();

    if (baseItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withAlpha(60),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.error.withAlpha(100)),
        ),
        child: Text(
          'No eligible items in cart for "${widget.item.categoryName}". Add a main item first.',
          style: TextStyle(fontSize: 13, color: theme.colorScheme.error),
        ),
      );
    }

    return Column(
      children: baseItems.map((base) {
        final isSelected = _selectedBaseItem?.id == base.id;
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            isSelected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
          title: Text(
            base.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            base.categoryName,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
          ),
          selected: isSelected,
          onTap: () {
            setState(() {
              _selectedBaseItem = base;
            });
          },
        );
      }).toList(),
    );
  }
}
