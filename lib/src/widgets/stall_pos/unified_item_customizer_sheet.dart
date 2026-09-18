import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/order_controller.dart';
import '../../models/stall_models.dart';
import 'dietary_symbol.dart';

/// Unified Item Customizer Bottom Sheet.
///
/// Sole entry point for item variant selection, add-ons, quantity adjustment,
/// and cart re-editing with real-time price calculation.
class UnifiedItemCustomizerSheet extends StatefulWidget {
  final MenuItem item;
  final OrderController controller;
  final Color Function(String category) getCategoryColor;
  final String buttonLabel;
  final String? initialCartItemId;
  final CategoryOption? initialSelectedVariant;
  final Map<String, int>? initialSelectedAddons;
  final int? initialQuantity;
  final VoidCallback? onItemUpdated;

  const UnifiedItemCustomizerSheet({
    super.key,
    required this.item,
    required this.controller,
    required this.getCategoryColor,
    this.buttonLabel = 'Add to Cart',
    this.initialCartItemId,
    this.initialSelectedVariant,
    this.initialSelectedAddons,
    this.initialQuantity,
    this.onItemUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required MenuItem item,
    required OrderController controller,
    required Color Function(String category) getCategoryColor,
    String? buttonLabel,
    String? initialCartItemId,
    CategoryOption? initialSelectedVariant,
    Map<String, int>? initialSelectedAddons,
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
        buttonLabel: buttonLabel ?? 'Add to Cart',
        initialCartItemId: initialCartItemId,
        initialSelectedVariant: initialSelectedVariant,
        initialSelectedAddons: initialSelectedAddons,
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

  // Add-ons state: addonId -> quantity (0..2)
  late List<CategoryOption> _addons;
  final Map<String, int> _selectedAddons = {};

  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuantity != null && widget.initialQuantity! > 0) {
      _quantity = widget.initialQuantity!;
    }

    _variants = widget.item.effectiveVariants;
    if (_variants.isNotEmpty) {
      if (widget.initialSelectedVariant != null) {
        _selectedVariant = _variants.firstWhere(
          (v) => v.name.trim().toLowerCase() == widget.initialSelectedVariant!.name.trim().toLowerCase(),
          orElse: () => _variants.firstWhere((v) => v.isAvailable, orElse: () => _variants.first),
        );
      } else {
        final available = _variants.where((v) => v.isAvailable).toList();
        _selectedVariant = available.isNotEmpty ? available.first : _variants.first;
      }
    }

    _addons = widget.item.effectiveAddons
        .where((a) =>
            a.isAvailable &&
            a.name.trim().isNotEmpty &&
            !const {'false', 'true', 'null', 'none'}.contains(a.name.trim().toLowerCase()))
        .toList();
    if (widget.initialSelectedAddons != null) {
      for (final entry in widget.initialSelectedAddons!.entries) {
        if (_addons.any((a) => a.id == entry.key || a.name.trim().toLowerCase() == entry.key.trim().toLowerCase())) {
          _selectedAddons[entry.key] = entry.value;
        }
      }
    }
  }

  double get _currentUnitPrice {
    final basePrice = widget.item.priceForVariant(_selectedVariant);
    final catCost = widget.controller.getCategoryCost(widget.item.categoryName);

    double addonsTotal = 0.0;
    for (final addon in _addons) {
      final count = _selectedAddons[addon.id] ?? _selectedAddons[addon.name] ?? 0;
      if (count > 0) {
        addonsTotal += addon.priceDelta * count;
      }
    }

    return basePrice + catCost + addonsTotal;
  }

  double get _totalPrice => _currentUnitPrice * _quantity;

  bool get _canAddToCart {
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

    final selectedAddonsList = <CategoryOption>[];
    for (final addon in _addons) {
      final count = _selectedAddons[addon.id] ?? _selectedAddons[addon.name] ?? 0;
      for (int i = 0; i < count; i++) {
        selectedAddonsList.add(addon);
      }
    }

    widget.controller.addCustomizedItemToCart(
      baseItem: widget.item,
      selectedVariant: _selectedVariant,
      selectedAddons: selectedAddonsList,
      quantity: _quantity,
    );

    widget.onItemUpdated?.call();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemColor = widget.item.colorHex != null
        ? Color(widget.item.colorHex!)
        : widget.getCategoryColor(widget.item.categoryName);

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
                          '${widget.item.categoryName} • Base ₹${widget.item.price.toStringAsFixed(0)}',
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

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Category Variants Section (Single Select)
                    if (_variants.isNotEmpty) ...[
                      Text(
                        'Select Variant / Portion',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _variants.map((v) {
                          final isSelected = _selectedVariant?.name == v.name;
                          final isSoldOut = !v.isAvailable;
                          final badge = v.costBadge;

                          return ChoiceChip(
                            label: Text(
                              isSoldOut
                                  ? '${v.name} (Sold Out)'
                                  : badge.isNotEmpty
                                      ? '${v.name} ($badge)'
                                      : v.name,
                              style: TextStyle(
                                decoration: isSoldOut ? TextDecoration.lineThrough : null,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected && !isSoldOut,
                            onSelected: isSoldOut
                                ? null
                                : (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedVariant = v;
                                      });
                                    }
                                  },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Add-ons Section
                    if (_addons.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add-ons & Extras',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Optional (Max 2 each)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._addons.map((addon) {
                        final count = _selectedAddons[addon.id] ?? _selectedAddons[addon.name] ?? 0;
                        final badge = addon.costBadge;
                        final canAdd = count < OrderController.maxPerAddonItem;
                        void incrementAddon() {
                          if (!canAdd) return;
                          HapticFeedback.lightImpact();
                          setState(() {
                            _selectedAddons[addon.id] = count + 1;
                          });
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: count > 0
                                ? theme.colorScheme.primaryContainer.withAlpha(50)
                                : theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: count > 0
                                  ? theme.colorScheme.primary.withAlpha(120)
                                  : theme.colorScheme.outlineVariant.withAlpha(80),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: canAdd ? incrementAddon : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            addon.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (badge.isNotEmpty)
                                            Text(
                                              badge,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    // Quantity Stepper
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (count > 0)
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, size: 22),
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            onPressed: () {
                                              HapticFeedback.lightImpact();
                                              setState(() {
                                                if (count <= 1) {
                                                  _selectedAddons.remove(addon.id);
                                                  _selectedAddons.remove(addon.name);
                                                } else {
                                                  _selectedAddons[addon.id] = count - 1;
                                                }
                                              });
                                            },
                                          ),
                                        if (count > 0)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Text(
                                              '$count',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        IconButton(
                                          icon: Icon(
                                            count > 0 ? Icons.add_circle_outline : Icons.add,
                                            size: 22,
                                            color: canAdd
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.outline,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          onPressed: canAdd ? incrementAddon : null,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // Category surcharge notification if active
                    if (widget.item.category.hasAdditionalCost) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer.withAlpha(60),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: theme.colorScheme.tertiary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Includes ${widget.item.category.costDescription}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onTertiaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // Bottom Bar with Quantity and Add Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  // Quantity Stepper
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 20),
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                        ),
                        Text(
                          '$_quantity',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 20),
                          onPressed: () => setState(() => _quantity++),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Add To Cart Button
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _canAddToCart ? _onAddToCart : null,
                      child: Text(
                        '${widget.buttonLabel} • ₹${_totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
}
