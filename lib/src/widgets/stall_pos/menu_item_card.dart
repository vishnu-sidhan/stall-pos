import 'package:flutter/material.dart';
import '../../models/stall_models.dart';
import 'dietary_symbol.dart';

/// Card displaying an individual menu item in the POS register grid with category accents,
/// add-on badge, in-cart counter pill, and price.
class MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final Map<String, int> cart;
  final Color Function(String category) getCategoryColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const MenuItemCard({
    super.key,
    required this.item,
    required this.cart,
    required this.getCategoryColor,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final inCartQty = cart.entries.where((entry) {
      final rawKey = entry.key.contains('+') ? entry.key.split('+').first : entry.key;
      final baseId = rawKey.contains('_var_')
          ? rawKey.split('_var_').first
          : (rawKey.contains('_cat_') ? rawKey.split('_cat_').first : rawKey);
      return baseId == item.id;
    }).fold(0, (sum, entry) => sum + entry.value);

    final itemColor = item.colorHex != null
        ? Color(item.colorHex!)
        : getCategoryColor(item.categoryName);

    return InkWell(
      key: ValueKey(item.id),
      onTap: onTap,
      onLongPress: onLongPress,
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
                      if (item.categoryName.isNotEmpty &&
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
                      Text(
                        '₹${item.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: inCartQty > 0
                              ? itemColor
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
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
