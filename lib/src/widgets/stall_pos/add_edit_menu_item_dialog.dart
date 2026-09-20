import 'package:flutter/material.dart';
import '../../controllers/order_controller.dart';
import '../../models/stall_models.dart';
import 'dietary_symbol.dart';

/// Modal dialog for adding or editing menu items.
class AddEditMenuItemDialog {
  AddEditMenuItemDialog._();

  static void show(
    BuildContext context, {
    MenuItem? existingItem,
    required OrderController controller,
    required List<String> categories,
    required Color Function(String category) getCategoryColor,
    required Map<String, int> resolvedCategoryColors,
  }) {
    final isEditing = existingItem != null;
    final nameCtrl = TextEditingController(text: existingItem?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existingItem != null ? existingItem.price.toStringAsFixed(0) : '',
    );
    final descCtrl = TextEditingController(text: existingItem?.description ?? '');
    String selectedCat =
        existingItem?.categoryName ??
        (controller.selectedCategory != 'All'
            ? controller.selectedCategory
            : 'General');
    final categoryCtrl = TextEditingController(text: selectedCat);
    bool isAvailable = existingItem?.isAvailable ?? true;
    ItemDietaryType? selectedDietary = existingItem?.dietaryType;

    final existingCategories = categories.where((c) => c != 'All').toList();
    if (!existingCategories.contains('General')) {
      existingCategories.insert(0, 'General');
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final effectiveCategory = categoryCtrl.text.trim().isEmpty
              ? 'General'
              : categoryCtrl.text.trim();
          final currentEffectiveColor = getCategoryColor(effectiveCategory);

          return AlertDialog(
            title: Text(isEditing ? 'Edit Menu Item' : 'Add Menu Item'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: !isEditing,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Item Name *',
                      hintText: 'e.g. Masala Chai, Veg Roll',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Price (₹) *',
                      hintText: 'e.g. 50',
                      prefixText: '₹ ',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Dietary Preference',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Active: ',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          DietarySymbol(
                            type: selectedDietary ??
                                ItemDietaryType.infer(
                                  name: nameCtrl.text.trim(),
                                  category: effectiveCategory,
                                ),
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (selectedDietary ??
                                    ItemDietaryType.infer(
                                      name: nameCtrl.text.trim(),
                                      category: effectiveCategory,
                                    ))
                                .label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: (selectedDietary ??
                                      ItemDietaryType.infer(
                                        name: nameCtrl.text.trim(),
                                        category: effectiveCategory,
                                      ))
                                  .color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ChoiceChip(
                        avatar: const Icon(Icons.auto_awesome, size: 14),
                        label: Text(
                          'Auto (${ItemDietaryType.infer(name: nameCtrl.text.trim(), category: effectiveCategory).label})',
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: selectedDietary == null,
                        onSelected: (selected) {
                          setDialogState(() => selectedDietary = null);
                        },
                      ),
                      ChoiceChip(
                        avatar: const DietarySymbol(
                          type: ItemDietaryType.veg,
                          size: 11,
                        ),
                        label: const Text('Veg', style: TextStyle(fontSize: 11)),
                        selected: selectedDietary == ItemDietaryType.veg,
                        selectedColor: Colors.green.withAlpha(40),
                        onSelected: (selected) {
                          setDialogState(
                            () => selectedDietary =
                                selected ? ItemDietaryType.veg : null,
                          );
                        },
                      ),
                      ChoiceChip(
                        avatar: const DietarySymbol(
                          type: ItemDietaryType.nonVeg,
                          size: 11,
                        ),
                        label: const Text(
                          'Non-Veg',
                          style: TextStyle(fontSize: 11),
                        ),
                        selected: selectedDietary == ItemDietaryType.nonVeg,
                        selectedColor: Colors.red.withAlpha(40),
                        onSelected: (selected) {
                          setDialogState(
                            () => selectedDietary =
                                selected ? ItemDietaryType.nonVeg : null,
                          );
                        },
                      ),
                      ChoiceChip(
                        avatar: const DietarySymbol(
                          type: ItemDietaryType.egg,
                          size: 11,
                        ),
                        label: const Text('Egg', style: TextStyle(fontSize: 11)),
                        selected: selectedDietary == ItemDietaryType.egg,
                        selectedColor: Colors.amber.withAlpha(40),
                        onSelected: (selected) {
                          setDialogState(
                            () => selectedDietary =
                                selected ? ItemDietaryType.egg : null,
                          );
                        },
                      ),
                      ChoiceChip(
                        label: const Text('None', style: TextStyle(fontSize: 11)),
                        selected: selectedDietary == ItemDietaryType.none,
                        onSelected: (selected) {
                          setDialogState(
                            () => selectedDietary =
                                selected ? ItemDietaryType.none : null,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Available for Order',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'When turned off, item is hidden from POS take-order register',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: isAvailable,
                    onChanged: (val) {
                      setDialogState(() {
                        isAvailable = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Category',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: existingCategories.map((cat) {
                      final isCurrent =
                          categoryCtrl.text.trim().toLowerCase() ==
                          cat.trim().toLowerCase();
                      final catColor = getCategoryColor(cat);
                      final catConfig = controller.getCategoryConfig(cat);
                      final hasCost = catConfig?.hasAdditionalCost == true;
                      final displayCat = controller.getCategoryDisplayName(cat);

                      return ChoiceChip(
                        avatar: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: catColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        label: Text(
                          hasCost
                              ? '$displayCat (+₹${catConfig!.additionalCost.toStringAsFixed(catConfig.additionalCost.truncateToDouble() == catConfig.additionalCost ? 0 : 2)})'
                              : displayCat,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: isCurrent,
                        selectedColor: catColor.withAlpha(50),
                        side: BorderSide(
                          color: isCurrent ? catColor : Colors.grey.shade300,
                          width: isCurrent ? 1.5 : 1.0,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() {
                              categoryCtrl.text = cat;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: categoryCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Or enter custom category',
                      hintText: 'e.g. Beverages, Snacks, Dessert',
                      isDense: true,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'e.g. Freshly brewed with ginger and cardamom',
                      alignLabelWithHint: true,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: currentEffectiveColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: currentEffectiveColor, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: currentEffectiveColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        DietarySymbol(
                          type: selectedDietary ??
                              ItemDietaryType.infer(
                                name: nameCtrl.text.trim(),
                                category: effectiveCategory,
                              ),
                          size: 13,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            nameCtrl.text.trim().isEmpty
                                ? 'Preview ($effectiveCategory)'
                                : '${nameCtrl.text.trim()} • ₹${priceCtrl.text.trim().isEmpty ? '0' : priceCtrl.text.trim()}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: currentEffectiveColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                  final category = categoryCtrl.text.trim().isEmpty
                      ? 'General'
                      : categoryCtrl.text.trim();
                  final description = descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim();

                  if (name.isNotEmpty && price > 0) {
                    final catObj = controller.resolveItemCategory(category);
                    if (isEditing) {
                      controller.updateMenuItem(
                        existingItem.copyWith(
                          name: name,
                          price: price,
                          category: catObj,
                          isAvailable: isAvailable,
                          dietaryType: selectedDietary,
                          clearDietaryType: selectedDietary == null,
                          description: description,
                          clearDescription: description == null,
                        ),
                      );
                    } else {
                      final newId = DateTime.now().millisecondsSinceEpoch.toString();
                      controller.addMenuItem(
                        MenuItem(
                          id: newId,
                          name: name,
                          price: price,
                          category: catObj,
                          unavailableVariants: isAvailable ? const [] : [newId],
                          dietaryType: selectedDietary,
                          description: description,
                        ),
                      );
                    }
                    Navigator.pop(ctx);
                  }
                },
                child: Text(isEditing ? 'Save Changes' : 'Add Item'),
              ),
            ],
          );
        },
      ),
    );
  }

  static void showOptionsBottomSheet(
    BuildContext context, {
    required MenuItem item,
    required OrderController controller,
    required List<String> categories,
    required Color Function(String category) getCategoryColor,
    required Map<String, int> resolvedCategoryColors,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Row(
                children: [
                  DietarySymbol(type: item.effectiveDietaryType, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: getCategoryColor(item.categoryName),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('${item.categoryName} • ₹${item.price.toStringAsFixed(0)}'),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: item.isAvailable ? Colors.green.withAlpha(30) : Colors.red.withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.isAvailable ? 'Available' : 'Unavailable',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: item.isAvailable ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                item.isAvailable ? Icons.remove_circle_outline : Icons.check_circle_outline,
                color: item.isAvailable ? Colors.orange : Colors.green,
              ),
              title: Text(
                item.isAvailable ? 'Mark Unavailable Today' : 'Mark Available Today',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: item.isAvailable ? Colors.orange.shade800 : Colors.green.shade800,
                ),
              ),
              subtitle: Text(
                item.isAvailable
                    ? 'Hides this item from POS take-order menu'
                    : 'Restores this item to POS take-order menu',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                controller.toggleItemAvailability(item.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Item Details'),
              onTap: () {
                Navigator.pop(ctx);
                show(
                  context,
                  existingItem: item,
                  controller: controller,
                  categories: categories,
                  getCategoryColor: getCategoryColor,
                  resolvedCategoryColors: resolvedCategoryColors,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete Item',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteItem(context, item, controller);
              },
            ),
          ],
        ),
      ),
    );
  }

  static void _confirmDeleteItem(
    BuildContext context,
    MenuItem item,
    OrderController controller,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Menu Item?'),
        content: Text(
          'Are you sure you want to delete "${item.name}" from the menu?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              controller.deleteMenuItem(item.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
