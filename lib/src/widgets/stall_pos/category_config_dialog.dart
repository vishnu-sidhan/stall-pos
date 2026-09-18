import 'package:flutter/material.dart';
import '../../controllers/order_controller.dart';
import '../../models/item_category.dart';

class _OptionEntry {
  final String id;
  String name;
  final TextEditingController costCtrl;
  bool isEnabled;

  _OptionEntry({
    required this.id,
    required this.name,
    required this.costCtrl,
    this.isEnabled = true,
  });

  void dispose() {
    costCtrl.dispose();
  }
}

class _AddonEntry {
  final String id;
  String name;
  final TextEditingController priceCtrl;
  bool isEnabled;

  _AddonEntry({
    required this.id,
    required this.name,
    required this.priceCtrl,
    this.isEnabled = true,
  });

  void dispose() {
    priceCtrl.dispose();
  }
}

/// Modal dialog for configuring category settings such as display names,
/// multi-category variant charges (e.g. Steam/Fried/Pan Fried for Momos),
/// packaging fees, and category accent colors.
class CategoryConfigDialog extends StatefulWidget {
  final String categoryName;
  final OrderController controller;
  final Color Function(String category) getCategoryColor;

  const CategoryConfigDialog({
    super.key,
    required this.categoryName,
    required this.controller,
    required this.getCategoryColor,
  });

  static Future<void> show(
    BuildContext context, {
    required String categoryName,
    required OrderController controller,
    required Color Function(String category) getCategoryColor,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => CategoryConfigDialog(
        categoryName: categoryName,
        controller: controller,
        getCategoryColor: getCategoryColor,
      ),
    );
  }

  @override
  State<CategoryConfigDialog> createState() => _CategoryConfigDialogState();
}

class _CategoryConfigDialogState extends State<CategoryConfigDialog> {
  late final ItemCategory _existingConfig;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _reasonCtrl;
  late final List<_OptionEntry> _optionEntries;
  late final List<_AddonEntry> _addonEntries;

  late bool _isEnabled;
  late int? _selectedColorHex;

  @override
  void initState() {
    super.initState();
    _existingConfig = widget.controller.getCategoryConfig(widget.categoryName) ??
        ItemCategory(
          id: 'cat_${widget.categoryName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
          name: widget.categoryName.trim(),
          additionalCost: 0.0,
        );

    _nameCtrl = TextEditingController(text: widget.categoryName.trim());
    _costCtrl = TextEditingController(
      text: _existingConfig.additionalCost > 0
          ? (_existingConfig.additionalCost.truncateToDouble() == _existingConfig.additionalCost
              ? _existingConfig.additionalCost.toStringAsFixed(0)
              : _existingConfig.additionalCost.toStringAsFixed(2))
          : '',
    );
    _reasonCtrl = TextEditingController(
      text: _existingConfig.costReason ?? '',
    );

    _optionEntries = _existingConfig.effectiveOptions.map((opt) {
      return _OptionEntry(
        id: opt.id,
        name: opt.name,
        costCtrl: TextEditingController(
          text: opt.additionalCost > 0
              ? (opt.additionalCost.truncateToDouble() == opt.additionalCost
                  ? opt.additionalCost.toStringAsFixed(0)
                  : opt.additionalCost.toStringAsFixed(2))
              : '',
        ),
        isEnabled: opt.isEnabled,
      );
    }).toList();

    _addonEntries = _existingConfig.addons.map((addon) {
      final priceVal = addon.priceDelta > 0
          ? addon.priceDelta
          : (addon.price != null && addon.price! > 0 ? addon.price! : 0.0);
      return _AddonEntry(
        id: addon.id,
        name: addon.name,
        priceCtrl: TextEditingController(
          text: priceVal > 0
              ? (priceVal.truncateToDouble() == priceVal
                  ? priceVal.toStringAsFixed(0)
                  : priceVal.toStringAsFixed(2))
              : '',
        ),
        isEnabled: addon.isEnabled,
      );
    }).toList();

    _isEnabled = _existingConfig.isEnabled;
    _selectedColorHex = _existingConfig.colorHex;
  }

  @override
  void dispose() {
    for (final opt in _optionEntries) {
      opt.dispose();
    }
    for (final addon in _addonEntries) {
      addon.dispose();
    }
    _nameCtrl.dispose();
    _costCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _addOptionPrompt() async {
    final newOptCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final addedName = await showDialog<String>(
      context: context,
      builder: (promptCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Add Category Option / Variant',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: newOptCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Option Name',
              hintText: 'e.g. Steam, Fried, Tandoori',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter option name';
              }
              if (_optionEntries.any(
                  (e) => e.name.trim().toLowerCase() == val.trim().toLowerCase())) {
                return 'Option already exists';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(promptCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(promptCtx, newOptCtrl.text.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (addedName != null && addedName.isNotEmpty && mounted) {
      setState(() {
        _optionEntries.add(
          _OptionEntry(
            id: 'opt_${addedName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
            name: addedName,
            costCtrl: TextEditingController(text: ''),
            isEnabled: true,
          ),
        );
      });
    }
  }

  void _addAddonPrompt() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final added = await showDialog<bool>(
      context: context,
      builder: (promptCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Add Category Add-on / Extra',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Add-on Name',
                  hintText: 'e.g. Extra Cheese, Mayo, Peri Peri',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter add-on name';
                  }
                  if (_addonEntries.any((e) =>
                      e.name.trim().toLowerCase() == val.trim().toLowerCase())) {
                    return 'Add-on already exists';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Additional Price (₹)',
                  hintText: 'e.g. 20',
                  prefixText: '+₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(promptCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(promptCtx, true);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (added == true && nameCtrl.text.trim().isNotEmpty && mounted) {
      final name = nameCtrl.text.trim();
      final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
      setState(() {
        _addonEntries.add(
          _AddonEntry(
            id: 'addon_${DateTime.now().millisecondsSinceEpoch}_${_addonEntries.length}',
            name: name,
            priceCtrl: TextEditingController(
              text: price > 0
                  ? (price.truncateToDouble() == price
                      ? price.toStringAsFixed(0)
                      : price.toStringAsFixed(2))
                  : '',
            ),
            isEnabled: true,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.getCategoryColor(widget.categoryName);
    final currentColor =
        _selectedColorHex != null ? Color(_selectedColorHex!) : baseColor;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      title: Row(
        children: [
          Container(
            width: 10,
            height: 24,
            decoration: BoxDecoration(
              color: currentColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Category: ${widget.categoryName}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configure category name, option / variant charges (e.g. Steam / Fried for Momos), packaging fees, and accent colors.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),

              // Category Name Input Field
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g. Rice / Noodles, Momos, Beverages',
                  prefixIcon: const Icon(Icons.label_outline_rounded, size: 20),
                  helperText: 'Use "/" to define slash sub-categories (e.g. Rice / Noodles)',
                  helperMaxLines: 2,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),

              // Category Options Section (for multi-categories like Steam / Fried / Pan Fried)
              if (_optionEntries.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 16, color: currentColor),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Option / Variant Charges',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addOptionPrompt,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Option', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set individual additional cost for each category option (e.g. Steam: ₹0, Fried: ₹10, Pan Fried: ₹20).',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._optionEntries.asMap().entries.map((item) {
                        final index = item.key;
                        final entry = item.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: currentColor.withAlpha(25),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: currentColor.withAlpha(70)),
                                  ),
                                  child: Text(
                                    entry.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: entry.costCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true),
                                  decoration: InputDecoration(
                                    prefixText: '₹ ',
                                    hintText: '0',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              if (_optionEntries.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Remove option',
                                  onPressed: () {
                                    setState(() {
                                      _optionEntries.removeAt(index);
                                    });
                                  },
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                // Single-cost category inputs
                TextField(
                  controller: _costCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Additional Cost (₹)',
                    hintText: 'e.g. 5, 10',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    helperText: 'Applied to items in this category',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reasonCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Reason / Label (Optional)',
                    hintText: 'e.g. Packaging Fee, Container Charge',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    'Packaging Fee',
                    'Container Charge',
                    'Takeaway Surcharge',
                    'Eco Box',
                  ].map((reason) {
                    return ActionChip(
                      label: Text(reason, style: const TextStyle(fontSize: 11)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          _reasonCtrl.text = reason;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _addOptionPrompt,
                  icon: const Icon(Icons.alt_route_rounded, size: 16),
                  label: const Text(
                    'Add Sub-Category Options / Variants',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Category Add-ons / Extras
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Category Add-ons',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addAddonPrompt,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Extra', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Available across all items in this category (e.g. Extra Cheese, Mayo, Peri Peri).',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              if (_addonEntries.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant.withAlpha(120),
                    ),
                  ),
                  child: Column(
                    children: [
                      ..._addonEntries.asMap().entries.map((entryItem) {
                        final index = entryItem.key;
                        final entry = entryItem.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  entry.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: entry.priceCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    prefixText: '+₹ ',
                                    hintText: '0',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Remove add-on',
                                onPressed: () {
                                  setState(() {
                                    _addonEntries.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'No add-ons configured for this category.',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // Enable/Disable switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Enable Additional Cost',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Toggle off to temporarily disable charges without deleting them',
                  style: TextStyle(fontSize: 11),
                ),
                value: _isEnabled,
                onChanged: (val) {
                  setState(() {
                    _isEnabled = val;
                  });
                },
              ),
              const SizedBox(height: 8),

              // Color selection row
              Row(
                children: [
                  const Text(
                    'Category Color Accent',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: currentColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ItemCategory.palette.take(8).map((colorInt) {
                  final c = Color(colorInt);
                  final isSelected = _selectedColorHex == colorInt;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedColorHex = colorInt;
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: c.withAlpha(150),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.categoryName.trim().toLowerCase() != 'all' &&
            widget.categoryName.trim().toLowerCase() != 'general')
          TextButton.icon(
            key: const ValueKey('dialog_delete_category_btn'),
            icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade700),
            label: Text('Delete Category', style: TextStyle(color: Colors.red.shade700)),
            onPressed: () async {
              final cat = widget.categoryName.trim();
              final matchingItems = widget.controller.menu
                  .where((i) => i.categoryName.trim().toLowerCase() == cat.toLowerCase())
                  .toList();

              bool? shouldDelete;
              bool deleteItems = false;

              if (matchingItems.isEmpty) {
                shouldDelete = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text('Delete Category "$cat"?'),
                    content: const Text('Are you sure you want to delete this category?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              } else {
                final result = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text('Delete Category "$cat"?'),
                    content: Text(
                      'This category currently contains ${matchingItems.length} item(s).\n\n'
                      'Choose how to handle existing items:',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, 'cancel'),
                        child: const Text('Cancel'),
                      ),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, 'reassign'),
                        child: const Text('Reassign to "General"'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                        onPressed: () => Navigator.pop(ctx, 'delete_all'),
                        child: const Text('Delete Items as Well'),
                      ),
                    ],
                  ),
                );

                if (result == 'reassign') {
                  shouldDelete = true;
                  deleteItems = false;
                } else if (result == 'delete_all') {
                  shouldDelete = true;
                  deleteItems = true;
                }
              }

              if (shouldDelete == true && mounted) {
                await widget.controller.deleteCategory(cat, deleteItems: deleteItems);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final parsedCost = double.tryParse(_costCtrl.text.trim()) ?? 0.0;
            final cleanReason = _reasonCtrl.text.trim().isNotEmpty
                ? _reasonCtrl.text.trim()
                : null;

            final newName = _nameCtrl.text.trim().isNotEmpty
                ? _nameCtrl.text.trim()
                : widget.categoryName.trim();
            final oldName = widget.categoryName.trim();

            if (newName.toLowerCase() != oldName.toLowerCase()) {
              await widget.controller.renameCategory(oldName, newName);
            }

            final updatedOptions = _optionEntries.map((e) {
              final parsedOptCost =
                  double.tryParse(e.costCtrl.text.trim()) ?? 0.0;
              return CategoryOption(
                id: e.id,
                name: e.name,
                additionalCost: parsedOptCost >= 0 ? parsedOptCost : 0.0,
                isEnabled: e.isEnabled,
              );
            }).toList();

            final updatedAddons = _addonEntries.map((e) {
              final parsedPrice =
                  double.tryParse(e.priceCtrl.text.trim()) ?? 0.0;
              return CategoryOption(
                id: e.id,
                name: e.name,
                priceDelta: parsedPrice >= 0 ? parsedPrice : 0.0,
                isEnabled: e.isEnabled,
              );
            }).toList();

            final updated = _existingConfig.copyWith(
              name: newName,
              additionalCost: parsedCost >= 0 ? parsedCost : 0.0,
              costReason: cleanReason,
              clearCostReason: cleanReason == null,
              isEnabled: _isEnabled,
              colorHex: _selectedColorHex,
              options: updatedOptions,
              addons: updatedAddons,
            );

            await widget.controller.saveCategoryConfig(updated);

            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text('Save Changes'),
        ),
      ],
    );
  }
}
