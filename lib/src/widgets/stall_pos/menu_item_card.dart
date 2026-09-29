import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/order_controller.dart';
import '../../models/stall_models.dart';
import 'dietary_symbol.dart';
import 'unified_item_customizer_sheet.dart';

/// Card displaying an individual menu item in the POS register grid with category accents,
/// add-on badge, in-cart counter pill, and price.
class MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final Map<String, int> cart;
  final Color Function(String category) getCategoryColor;
  final OrderController? controller;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final CategoryOption? boundVariant;
  final double? overridePrice;

  const MenuItemCard({
    super.key,
    required this.item,
    this.cart = const {},
    Color Function(String category)? getCategoryColor,
    this.controller,
    this.onTap,
    this.onLongPress,
    this.boundVariant,
    this.overridePrice,
  }) : getCategoryColor = getCategoryColor ?? _defaultGetCategoryColor;

  static Color _defaultGetCategoryColor(String _) => const Color(0xFF1E88E5);

  void _handleTap(BuildContext context) {
    if (onTap != null) {
      HapticFeedback.selectionClick();
      onTap!();
      return;
    }

    final ctrl = controller;
    if (ctrl == null) return;

    if (item is VariantBoundMenuItem || boundVariant != null) {
      final targetItem = (item is VariantBoundMenuItem)
          ? (item as VariantBoundMenuItem).originalItem
          : item;
      final targetVariant = boundVariant ??
          ((item is VariantBoundMenuItem)
              ? (item as VariantBoundMenuItem).targetVariant
              : null);
      final hydrated = ctrl.hydrateMenuItemCategory(targetItem);
      HapticFeedback.lightImpact();
      ctrl.addToCart(hydrated, selectedVariant: targetVariant);
      return;
    }

    final hydrated = ctrl.hydrateMenuItemCategory(item);
    final activeVariants =
        hydrated.effectiveVariants.where((v) => v.isAvailable).toList();

    if (ctrl.autoAddSingleVariant &&
        activeVariants.length == 1 &&
        hydrated.availableAddons.isEmpty) {
      HapticFeedback.lightImpact();
      ctrl.addToCart(hydrated, selectedVariant: activeVariants.first);
      return;
    }

    if (activeVariants.isNotEmpty || hydrated.availableAddons.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => UnifiedItemCustomizerSheet(
          item: hydrated,
          controller: ctrl,
          getCategoryColor: getCategoryColor,
        ),
      );
      return;
    }

    HapticFeedback.selectionClick();
    ctrl.addToCart(hydrated);
  }

  void _handleLongPress(BuildContext context) {
    if (onLongPress != null) {
      onLongPress!();
      return;
    }

    final ctrl = controller;
    final targetItem = (item is VariantBoundMenuItem)
        ? (item as VariantBoundMenuItem).originalItem
        : item;
    final targetVariant = boundVariant ??
        ((item is VariantBoundMenuItem)
            ? (item as VariantBoundMenuItem).targetVariant
            : null);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => UnifiedItemCustomizerSheet(
        item: ctrl != null ? ctrl.hydrateMenuItemCategory(targetItem) : targetItem,
        controller: ctrl,
        getCategoryColor: getCategoryColor,
        initialSelectedVariant: targetVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inCartQty = cart.entries.where((entry) {
      final rawKey = entry.key.contains('+') ? entry.key.split('+').first : entry.key;
      if (item is VariantBoundMenuItem || boundVariant != null) {
        final targetItem = (item is VariantBoundMenuItem)
            ? (item as VariantBoundMenuItem).originalItem
            : item;
        final targetVariant = boundVariant ??
            ((item is VariantBoundMenuItem)
                ? (item as VariantBoundMenuItem).targetVariant
                : null);
        final baseId = targetItem.id;
        if (targetVariant != null) {
          final targetVar = targetVariant.name.trim();
          return rawKey == '${baseId}_var_$targetVar' ||
              rawKey.startsWith('${baseId}_var_${targetVar}_cat_');
        } else {
          final itemBaseId = rawKey.contains('_var_')
              ? rawKey.split('_var_').first
              : (rawKey.contains('_cat_') ? rawKey.split('_cat_').first : rawKey);
          return itemBaseId == baseId && !rawKey.contains('_var_');
        }
      }
      final baseId = rawKey.contains('_var_')
          ? rawKey.split('_var_').first
          : (rawKey.contains('_cat_') ? rawKey.split('_cat_').first : rawKey);
      return baseId == item.id;
    }).fold(0, (sum, entry) => sum + entry.value);

    final itemColor = getCategoryColor(item.categoryName);

    return InkWell(
      key: ValueKey(item.id),
      onTap: () => _handleTap(context),
      onLongPress: () => _handleLongPress(context),
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: inCartQty > 0
              ? itemColor.withAlpha(45)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: inCartQty > 0 ? itemColor : itemColor.withAlpha(65),
            width: inCartQty > 0 ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: itemColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.effectiveDietaryType != ItemDietaryType.none) ...[
                            DietarySymbol(type: item.effectiveDietaryType, size: 12),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              item.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item is! VariantBoundMenuItem &&
                          boundVariant == null &&
                          item.categoryName.isNotEmpty &&
                          !item.name.toLowerCase().endsWith('(${item.categoryName.toLowerCase()})')) ...[
                        const SizedBox(height: 2),
                        Text(
                          '(${item.categoryName})',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: inCartQty > 0
                                ? itemColor
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 5),
                      Builder(builder: (context) {
                        final effectivePrice = overridePrice ?? item.price;
                        return Text(
                          '₹${effectivePrice.toStringAsFixed(effectivePrice.truncateToDouble() == effectivePrice ? 0 : 2)}',
                          style: TextStyle(
                            color: inCartQty > 0
                                ? itemColor
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        );
                      }),
                      if (inCartQty > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: itemColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$inCartQty',
                            style: TextStyle(
                              color: ItemCategory.getContrastingTextColor(
                                itemColor,
                              ),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
