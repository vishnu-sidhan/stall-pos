import 'package:flutter/material.dart';
import '../../controllers/order_controller.dart';
import '../../helpers/composite_item_helper.dart';
import '../../models/stall_models.dart';
import 'dietary_symbol.dart';

/// Stepper row widget for modifying add-on quantities with +/- buttons.
class AddonQuantityRow extends StatelessWidget {
  final String title;
  final double price;
  final int qty;
  final ValueChanged<int> onChanged;
  final bool canIncrement;
  final String? subtitle;
  final ItemDietaryType? dietaryType;

  const AddonQuantityRow({
    super.key,
    required this.title,
    required this.price,
    required this.qty,
    required this.onChanged,
    this.canIncrement = true,
    this.subtitle,
    this.dietaryType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      decoration: BoxDecoration(
        color: qty > 0
            ? Theme.of(context).colorScheme.primaryContainer.withAlpha(50)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: qty > 0
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: qty > 0 ? 1.5 : 1,
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
                      type: dietaryType ?? ItemDietaryType.infer(name: title),
                      size: 13,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight:
                              qty > 0 ? FontWeight.bold : FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  subtitle ?? '+₹${price.toStringAsFixed(0)} each',
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
              border:
                  Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 16),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: qty > 0 ? () => onChanged(qty - 1) : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '$qty',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color:
                          qty > 0 ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: canIncrement ? () => onChanged(qty + 1) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal for adding add-ons to an existing item directly from the cart.
class AddonsForCartItemModal {
  AddonsForCartItemModal._();

  static void show(
    BuildContext context, {
    required String cartItemId,
    required OrderController controller,
    VoidCallback? onUpdated,
  }) {
    final cartItem = controller.findItem(cartItemId);
    final availableAddons = controller.getAddonsForCategory(cartItem.categoryName);
    if (availableAddons.isEmpty) return;

    if (!controller.canAddAnyAddon(cartItemId)) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 2 per add-on already reached for this item.'),
          backgroundColor: Colors.deepOrange,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final Map<String, int> selectedQuantities = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            double totalAdded = 0.0;
            int totalCount = 0;
            final parts = <String>[];

            for (final addon in availableAddons) {
              if (addon.hasSlashNameVariants) {
                for (final v in addon.slashNameVariants) {
                  final key = CompositeItemHelper.buildVariantKey(addon.id, v);
                  final qty = selectedQuantities[key] ?? 0;
                  if (qty > 0) {
                    totalCount += qty;
                    totalAdded += qty * addon.price;
                    parts.add(qty > 1 ? '${qty}x $v' : v);
                  }
                }
              } else {
                final qty = selectedQuantities[addon.id] ?? 0;
                if (qty > 0) {
                  totalCount += qty;
                  totalAdded += qty * addon.price;
                  parts.add(qty > 1 ? '${qty}x ${addon.name}' : addon.name);
                }
              }
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
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
                      'Add Extras to ${cartItem.displayName}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select add-ons to attach to this item',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: availableAddons.length,
                        itemBuilder: (context, i) {
                          final addon = availableAddons[i];
                          if (addon.hasSlashNameVariants) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6, top: 4),
                                  child: Text(
                                    addon.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                ...addon.slashNameVariants.map((v) {
                                  final key = CompositeItemHelper.buildVariantKey(addon.id, v);
                                  final qty = selectedQuantities[key] ?? 0;
                                  final existingForVariant = controller.getAddonItemCount(
                                    cartItemId,
                                    addon.id,
                                    resolvedAddonName: v,
                                  );
                                  final maxForVariant = (OrderController.maxPerAddonItem - existingForVariant)
                                      .clamp(0, OrderController.maxPerAddonItem);

                                  return AddonQuantityRow(
                                    title: v,
                                    price: addon.price,
                                    qty: qty,
                                    dietaryType: ItemDietaryType.infer(
                                      name: v,
                                      category: addon.categoryName,
                                    ),
                                    canIncrement: qty < maxForVariant,
                                    subtitle: maxForVariant == 0
                                        ? 'Max 2 already added'
                                        : '+₹${addon.price.toStringAsFixed(0)} each',
                                    onChanged: (newQty) {
                                      setModalState(() {
                                        selectedQuantities[key] = newQty;
                                      });
                                    },
                                  );
                                }),
                              ],
                            );
                          }

                          final qty = selectedQuantities[addon.id] ?? 0;
                          final existingCount = controller.getAddonItemCount(cartItemId, addon.id);
                          final maxCount = (OrderController.maxPerAddonItem - existingCount)
                              .clamp(0, OrderController.maxPerAddonItem);

                          return AddonQuantityRow(
                            title: addon.name,
                            price: addon.price,
                            qty: qty,
                            dietaryType: addon.effectiveDietaryType,
                            canIncrement: qty < maxCount,
                            subtitle: maxCount == 0
                                ? 'Max 2 already added'
                                : '+₹${addon.price.toStringAsFixed(0)} each',
                            onChanged: (newQty) {
                              setModalState(() {
                                selectedQuantities[addon.id] = newQty;
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: totalCount > 0
                          ? () {
                              Navigator.pop(ctx);
                              final listToAdd = <({MenuItem addon, String? resolvedName, int quantity})>[];
                              selectedQuantities.forEach((key, q) {
                                if (q > 0) {
                                  final parsedVar = CompositeItemHelper.parseVariantKey(key);
                                  if (parsedVar != null) {
                                    final addon = controller.findItem(parsedVar.baseId);
                                    listToAdd.add((addon: addon, resolvedName: parsedVar.variant, quantity: q));
                                  } else {
                                    final addon = controller.findItem(key);
                                    listToAdd.add((addon: addon, resolvedName: null, quantity: q));
                                  }
                                }
                              });
                              controller.addMultipleAddonsToCart(
                                targetCartItemId: cartItemId,
                                addons: listToAdd,
                              );
                              onUpdated?.call();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        totalCount > 0
                            ? 'Add ${parts.join(', ')} • +₹${totalAdded.toStringAsFixed(0)}'
                            : 'Select Add-ons',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
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
