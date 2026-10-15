import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/order_controller.dart';
import '../../models/stall_models.dart';
import 'dietary_symbol.dart';

/// Panel displaying consolidated item preparation queue across all active tickets,
/// with interactive completion per ticket or by batch.
class ItemSummaryPanel extends StatelessWidget {
  final OrderController controller;
  final Color Function(String category)? getCategoryColor;
  final void Function(int token, String itemId, String itemName, int quantity)? onCompleteTicketItem;
  final void Function(String itemId, String itemName)? onCompleteAllItem;
  final bool isCompactStrip;

  const ItemSummaryPanel({
    super.key,
    required this.controller,
    this.getCategoryColor,
    this.onCompleteTicketItem,
    this.onCompleteAllItem,
    this.isCompactStrip = false,
  });

  Color _resolveCategoryColor(String category, int? itemColorHex) {
    if (itemColorHex != null) {
      return Color(itemColorHex);
    }
    if (getCategoryColor != null) {
      return getCategoryColor!(category);
    }
    return Color(ItemCategory.getColorForCategory(category));
  }

  @override
  Widget build(BuildContext context) {
    final combined = controller.combinedActiveOrders;

    if (isCompactStrip) {
      if (combined.isEmpty) {
        return Container(
          key: const ValueKey('wok_radar_clear'),
          height: 28,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.green.shade900.withAlpha(50),
            border: Border(bottom: BorderSide(color: Colors.green.shade700, width: 1)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 14, color: Colors.greenAccent),
              SizedBox(width: 6),
              Text(
                '✅ Wok Clear — No Pending Prep',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        key: const ValueKey('wok_radar_strip'),
        constraints: const BoxConstraints(maxHeight: 72),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E222D)
              : Colors.orange.shade50,
          border: Border(
            bottom: BorderSide(
              color: Colors.orange.shade700.withAlpha(120),
              width: 1.5,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: combined.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final item = combined[index];
            return InkWell(
              key: ValueKey('prep_pill_${item.cartKey}'),
              onTap: () async {
                HapticFeedback.mediumImpact();
                final outcome = await controller.completeOldestItemByCartKey(item.cartKey);
                if (outcome != null && context.mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        outcome.isOrderFullyCompleted
                            ? 'Marked 1x ${outcome.itemName} Prepared (Order #${outcome.token} READY!)'
                            : 'Marked 1x ${outcome.itemName} Prepared (Order #${outcome.token})',
                      ),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade900.withAlpha(180),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade400, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DietarySymbol(type: item.effectiveDietaryType, size: 12),
                    const SizedBox(width: 5),
                    Text(
                      item.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '× ${item.totalQuantity}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    if (combined.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No active orders in queue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Aggregated items to prepare across all tickets will appear here',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: combined.length,
      itemBuilder: (context, index) {
        final item = combined[index];
        final color = _resolveCategoryColor(item.category, item.colorHex);
        final tickets = controller.getTicketsForItem(item.cartKey);

        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: color.withAlpha(90), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Category Color Strip
                Container(
                  width: 5,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 14),

                // Item Details & Order Tags
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          DietarySymbol(
                            type: item.effectiveDietaryType,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.displayName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Ticket tags: e.g. Orders: #101 (3), #104 (2)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Orders: ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          ...tickets.map((t) {
                            final tooltipNote = [
                              'Order #${t.token}',
                              if (t.isParcel) 'Parcel',
                              if (t.orderNotes != null && t.orderNotes!.trim().isNotEmpty)
                                'Note: ${t.orderNotes!.trim()}',
                              'Tap to mark done',
                            ].join(' • ');

                            return Tooltip(
                              message: tooltipNote,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  key: ValueKey('ticket_chip_${item.itemId}_${t.token}'),
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    if (onCompleteTicketItem != null) {
                                      onCompleteTicketItem!(
                                        t.token,
                                        item.itemId,
                                        item.itemName,
                                        t.quantity,
                                      );
                                    } else {
                                      controller.completeOrderItem(
                                        token: t.token,
                                        itemId: item.itemId,
                                        quantity: t.quantity,
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: t.isParcel
                                          ? Colors.purple.shade50
                                          : Theme.of(
                                              context,
                                            ).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: t.isParcel
                                            ? Colors.purple.shade200
                                            : Theme.of(
                                                context,
                                              ).colorScheme.outlineVariant.withAlpha(100),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.check_circle_outline,
                                          size: 13,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '#${t.token}${t.isParcel ? ' 📦' : ''} (${t.quantity})',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: t.isParcel ? Colors.purple.shade900 : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Right action area: Large Badge with Total Quantity + Quick Complete Button
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: color.withAlpha(70),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'x${item.totalQuantity}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: ItemCategory.getContrastingTextColor(color),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FilledButton.tonalIcon(
                      key: ValueKey('complete_btn_${item.itemId}'),
                      onPressed: () {
                        if (tickets.length == 1) {
                          final t = tickets.first;
                          if (onCompleteTicketItem != null) {
                            onCompleteTicketItem!(
                              t.token,
                              item.itemId,
                              item.itemName,
                              t.quantity,
                            );
                          } else {
                            controller.completeOrderItem(
                              token: t.token,
                              itemId: item.itemId,
                              quantity: t.quantity,
                            );
                          }
                        } else {
                          if (onCompleteAllItem != null) {
                            onCompleteAllItem!(item.itemId, item.itemName);
                          } else {
                            controller.completeAggregatedItem(item.itemId);
                          }
                        }
                      },
                      icon: Icon(
                        tickets.length == 1 ? Icons.check : Icons.done_all,
                        size: 13,
                      ),
                      label: Text(
                        tickets.length == 1 ? 'Done' : 'All Done',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade100,
                        foregroundColor: Colors.green.shade900,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
