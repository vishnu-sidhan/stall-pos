import 'package:flutter/material.dart';
import '../../controllers/order_controller.dart';
import '../../models/stall_models.dart';

/// Clean, full-view widget providing a centralized interface to inspect, search, and edit
/// all menu category display names and additional surcharges/packaging fees.
class ManageCategoriesView extends StatefulWidget {
  final OrderController controller;
  final Color Function(String category) getCategoryColor;

  const ManageCategoriesView({
    super.key,
    required this.controller,
    required this.getCategoryColor,
  });

  /// Static helper to launch the Category Edit / Add page.
  static Future<void> showAddEditCategoryPage(
    BuildContext context, {
    String? categoryName,
    required OrderController controller,
    required Color Function(String category) getCategoryColor,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => CategoryEditPage(
          categoryName: categoryName,
          controller: controller,
          getCategoryColor: getCategoryColor,
        ),
      ),
    );
  }

  /// Backward-compatible helper to launch the Category Edit / Add page.
  static Future<void> showAddEditCategoryDialog(
    BuildContext context, {
    String? categoryName,
    required OrderController controller,
    required Color Function(String category) getCategoryColor,
  }) =>
      showAddEditCategoryPage(
        context,
        categoryName: categoryName,
        controller: controller,
        getCategoryColor: getCategoryColor,
      );

  @override
  State<ManageCategoriesView> createState() => _ManageCategoriesViewState();
}

class _ManageCategoriesViewState extends State<ManageCategoriesView> {
  String _searchFilter = '';

  List<String> _getAllCategories() {
    final set = <String>{};
    // Include all categories discovered from active menu
    for (final c in widget.controller.categories) {
      if (c != 'All') set.add(c);
    }
    // Include all saved category configs
    for (final c in widget.controller.categoryConfigs) {
      if (c.name.trim().isNotEmpty && c.name.trim().toLowerCase() != 'all') {
        set.add(c.name.trim());
      }
    }
    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (_searchFilter.trim().isEmpty) return list;
    final query = _searchFilter.trim().toLowerCase();
    return list.where((cat) => cat.toLowerCase().contains(query)).toList();
  }

  void _addNewCategory() async {
    await ManageCategoriesView.showAddEditCategoryDialog(
      context,
      controller: widget.controller,
      getCategoryColor: widget.getCategoryColor,
    );
    if (mounted) setState(() {});
  }

  void _confirmDeleteCategory(String cat) async {
    final norm = cat.trim().toLowerCase();
    if (norm == 'all' || norm == 'general') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Category "$cat" cannot be deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final matchingItems = widget.controller.menu
        .where((i) => i.categoryName.trim().toLowerCase() == norm)
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "$cat" deleted.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final categories = _getAllCategories();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top action bar: Search + Add Category button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 20),
                        hintText: 'Filter categories...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) => setState(() => _searchFilter = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: _addNewCategory,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Category'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Category List
            Expanded(
              child: categories.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                        child: Text(
                          _searchFilter.isNotEmpty
                              ? 'No categories matching "$_searchFilter"'
                              : 'No categories found. Click "+ Add Category" to create one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: categories.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final config = widget.controller.getCategoryConfig(cat);
                        final catColor = widget.getCategoryColor(cat);
                        final hasCost = config != null && config.hasAdditionalCost;
                        final isCostActive = hasCost && config.isEnabled;

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.outlineVariant.withAlpha(80),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: catColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                            title: Text(
                              cat,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (isCostActive)
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.deepOrange.withAlpha(30),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.deepOrange.withAlpha(120),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              config.costDescription,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.deepOrange.shade800,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                      else if (hasCost && !config.isEnabled)
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withAlpha(40),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.grey.withAlpha(90), width: 0.8),
                                            ),
                                            child: Text(
                                              '${config.costDescription} (Disabled)',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                      else
                                        Text(
                                          'No extra surcharge',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context).colorScheme.outline,
                                          ),
                                        ),
                                      if (config != null && config.hasOptions) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '• ${config.effectiveOptions.length} option(s)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context).colorScheme.outline,
                                          ),
                                        ),
                                      ],
                                      if (config != null && config.addons.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '• ${config.addons.length} add-on(s)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context).colorScheme.outline,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasCost)
                                  Switch(
                                    value: config.isEnabled,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    onChanged: (val) async {
                                      await widget.controller.saveCategoryConfig(
                                        config.copyWith(isEnabled: val),
                                      );
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  tooltip: 'Edit Category Name, Options & Fees',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () async {
                                    await ManageCategoriesView.showAddEditCategoryDialog(
                                      context,
                                      categoryName: cat,
                                      controller: widget.controller,
                                      getCategoryColor: widget.getCategoryColor,
                                    );
                                    if (mounted) setState(() {});
                                  },
                                ),
                                if (cat.trim().toLowerCase() != 'all' && cat.trim().toLowerCase() != 'general')
                                  IconButton(
                                    key: ValueKey('delete_category_${cat.replaceAll(' ', '_')}'),
                                    icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade700),
                                    tooltip: 'Delete Category',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _confirmDeleteCategory(cat),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Full-page wrapper around ManageCategoriesView for standalone page navigation.
class ManageCategoriesPage extends StatelessWidget {
  final OrderController controller;
  final Color Function(String category) getCategoryColor;

  const ManageCategoriesPage({
    super.key,
    required this.controller,
    required this.getCategoryColor,
  });

  static Future<void> show(
    BuildContext context, {
    required OrderController controller,
    required Color Function(String category) getCategoryColor,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => ManageCategoriesPage(
          controller: controller,
          getCategoryColor: getCategoryColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Surcharges & Options'),
      ),
      body: SafeArea(
        child: ManageCategoriesView(
          controller: controller,
          getCategoryColor: getCategoryColor,
        ),
      ),
    );
  }
}

/// Modal dialog wrapper around ManageCategoriesView for standalone dialog usages.
class ManageCategoriesDialog extends StatelessWidget {
  final OrderController controller;
  final Color Function(String category) getCategoryColor;

  const ManageCategoriesDialog({
    super.key,
    required this.controller,
    required this.getCategoryColor,
  });

  static Future<void> show(
    BuildContext context, {
    required OrderController controller,
    required Color Function(String category) getCategoryColor,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ManageCategoriesDialog(
        controller: controller,
        getCategoryColor: getCategoryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.tune_rounded,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Category Surcharges & Options',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'Manage extra packaging fees and preparation option charges',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 480,
        child: ManageCategoriesView(
          controller: controller,
          getCategoryColor: getCategoryColor,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

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

class CategoryEditPage extends StatefulWidget {
  final String? categoryName;
  final OrderController controller;
  final Color Function(String category) getCategoryColor;

  const CategoryEditPage({
    super.key,
    this.categoryName,
    required this.controller,
    required this.getCategoryColor,
  });

  @override
  State<CategoryEditPage> createState() => _CategoryEditPageState();
}

class _CategoryEditPageState extends State<CategoryEditPage> {
  late final ItemCategory _existingConfig;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _reasonCtrl;
  late final List<_OptionEntry> _optionEntries;
  late final List<_AddonEntry> _addonEntries;
  late bool _isEnabled;
  late int? _selectedColorHex;

  bool get _isEditing =>
      widget.categoryName != null && widget.categoryName!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final catName = widget.categoryName?.trim() ?? '';
    _existingConfig = (_isEditing ? widget.controller.getCategoryConfig(catName) : null) ??
        ItemCategory(
          id: catName.isNotEmpty
              ? 'cat_${catName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}'
              : 'cat_${DateTime.now().millisecondsSinceEpoch}',
          name: catName,
          additionalCost: 0.0,
        );

    _nameCtrl = TextEditingController(text: catName);
    _costCtrl = TextEditingController(
      text: _existingConfig.additionalCost > 0
          ? (_existingConfig.additionalCost.truncateToDouble() ==
                  _existingConfig.additionalCost
              ? _existingConfig.additionalCost.toStringAsFixed(0)
              : _existingConfig.additionalCost.toStringAsFixed(2))
          : '',
    );
    _reasonCtrl = TextEditingController(
      text: _existingConfig.costReason ?? '',
    );

    List<CategoryOption> initialOptions = _existingConfig.effectiveOptions;
    if (initialOptions.isEmpty && catName.contains('/')) {
      final segments = catName
          .split('/')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (segments.length > 1) {
        initialOptions = segments
            .map((s) => CategoryOption(id: s, name: s))
            .toList();
      }
    }

    _optionEntries = initialOptions.map((opt) {
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
    _nameCtrl.dispose();
    _costCtrl.dispose();
    _reasonCtrl.dispose();
    for (final opt in _optionEntries) {
      opt.dispose();
    }
    for (final addon in _addonEntries) {
      addon.dispose();
    }
    super.dispose();
  }

  Future<void> _saveCategory() async {
    final rawName = _nameCtrl.text.trim();
    if (rawName.isEmpty) return;

    final parsedCost = double.tryParse(_costCtrl.text.trim()) ?? 0.0;
    final cleanReason = _reasonCtrl.text.trim().isNotEmpty
        ? _reasonCtrl.text.trim()
        : null;

    final oldName = widget.categoryName?.trim() ?? '';
    final newName = rawName;

    if (_isEditing && newName.toLowerCase() != oldName.toLowerCase()) {
      await widget.controller.renameCategory(oldName, newName);
    }

    final updatedOptions = _optionEntries.map((e) {
      final parsedOptCost = double.tryParse(e.costCtrl.text.trim()) ?? 0.0;
      return CategoryOption(
        id: e.id,
        name: e.name,
        additionalCost: parsedOptCost >= 0 ? parsedOptCost : 0.0,
        isEnabled: e.isEnabled,
      );
    }).toList();

    final updatedAddons = _addonEntries.map((e) {
      final parsedPrice = double.tryParse(e.priceCtrl.text.trim()) ?? 0.0;
      return CategoryOption(
        id: e.id,
        name: e.name,
        priceDelta: parsedPrice >= 0 ? parsedPrice : 0.0,
        isEnabled: e.isEnabled,
      );
    }).toList();

    final baseConfig = _isEditing
        ? _existingConfig
        : ItemCategory(
            id: 'cat_${newName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
            name: newName,
          );

    final updated = baseConfig.copyWith(
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
    await widget.controller.syncCategoriesWithMenu();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _confirmDelete() async {
    final cat = widget.categoryName;
    if (cat == null) return;

    final matchingItems = widget.controller.menu
        .where((i) => i.categoryName.trim().toLowerCase() == cat.trim().toLowerCase())
        .toList();

    bool? shouldDelete;
    bool deleteItems = false;

    if (matchingItems.isEmpty) {
      shouldDelete = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Delete Category "$cat"?'),
          content: const Text('Are you sure you want to delete this category?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, 'delete_all'),
              child: const Text('Delete Items as Well'),
            ),
          ],
        ),
      );
      if (result == 'delete_all') {
        shouldDelete = true;
        deleteItems = true;
      } else if (result == 'reassign') {
        shouldDelete = true;
        deleteItems = false;
      }
    }

    if (shouldDelete == true && mounted) {
      await widget.controller.deleteCategory(cat, deleteItems: deleteItems);
      if (mounted) {
        Navigator.pop(context);
      }
    }
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

    if (added == true && mounted) {
      final name = nameCtrl.text.trim();
      final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
      setState(() {
        _addonEntries.add(
          _AddonEntry(
            id: 'addon_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
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
    final theme = Theme.of(context);
    final effectiveCategoryName = _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'General';
    final catColor = _selectedColorHex != null
        ? Color(_selectedColorHex!)
        : widget.getCategoryColor(effectiveCategoryName);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Category: ${widget.categoryName}' : 'Add New Category',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isEditing &&
              widget.categoryName?.trim().toLowerCase() != 'all' &&
              widget.categoryName?.trim().toLowerCase() != 'general')
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
              tooltip: 'Delete Category',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Name
                  TextField(
                    controller: _nameCtrl,
                    autofocus: false,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Category Name',
                      hintText: 'e.g. Rice / Noodles, Momos, Beverages',
                      helperText: 'Use "/" to define slash sub-categories (e.g. Rice / Noodles)',
                      prefixIcon: const Icon(Icons.category_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: theme.brightness == Brightness.dark
                          ? theme.colorScheme.surfaceContainerHighest
                          : theme.colorScheme.surfaceContainerLow,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),

                  // Option / Variant Charges Section
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Option / Variant Charges',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Extra charges for sub-category variations (e.g. Fried, Pan Fried)',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _addOptionPrompt,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text(
                          'Add Option',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_optionEntries.isNotEmpty) ...[
                    ..._optionEntries.asMap().entries.map((optItem) {
                      final index = optItem.key;
                      final opt = optItem.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                opt.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: opt.costCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Extra Cost',
                                  prefixText: '+₹ ',
                                  isDense: true,
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
                    const SizedBox(height: 12),
                  ] else ...[
                    Text(
                      'No options configured. Tap "Add Option" to configure sub-category variants (e.g. Steam, Fried).',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Category Surcharge / Packaging Fee Section (Always rendered for all categories)
                  const Text(
                    'Category Surcharge / Packaging Fee',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('category_additional_cost_input'),
                    controller: _costCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Additional Cost (₹)',
                      prefixText: '₹ ',
                      hintText: 'e.g. 5',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      'Packaging Fee',
                      'Container Fee',
                      'Delivery Surcharge',
                      'Special Prep',
                    ].map((s) {
                      return ActionChip(
                        label: Text(s, style: const TextStyle(fontSize: 11)),
                        onPressed: () {
                          _reasonCtrl.text = s;
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('category_cost_reason_input'),
                    controller: _reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cost Reason (Optional)',
                      hintText: 'e.g. Packaging container fee',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Category Add-ons Section
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Category Add-ons',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Available across all items in this category (e.g. Extra Cheese, Mayo, Peri Peri).',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        key: const ValueKey('add_category_extra_btn'),
                        onPressed: _addAddonPrompt,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text(
                          'Add Extra',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_addonEntries.isNotEmpty) ...[
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
                    ),
                    const SizedBox(height: 16),
                  ] else
                    const SizedBox(height: 12),

                  // Color Accent
                  const Text(
                    'Category Color Accent',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: catColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        label: const Text('Auto Color', style: TextStyle(fontSize: 12)),
                        side: BorderSide(
                          color: _selectedColorHex == null ? theme.colorScheme.primary : Colors.grey.shade300,
                          width: _selectedColorHex == null ? 2 : 1,
                        ),
                        onPressed: () {
                          setState(() => _selectedColorHex = null);
                        },
                      ),
                      ...ItemCategory.palette.map((colorVal) {
                        final isSel = _selectedColorHex == colorVal;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedColorHex = colorVal);
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Color(colorVal),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? Colors.black : Colors.white,
                                width: isSel ? 2.5 : 1.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            child: isSel
                                ? const Icon(Icons.check, size: 16, color: Colors.white)
                                : null,
                          ),
                        );
                      }),
                    ],
                  ),

                  // Delete Category Danger Zone Card (if editing and not All/General)
                  if (_isEditing &&
                      widget.categoryName?.trim().toLowerCase() != 'all' &&
                      widget.categoryName?.trim().toLowerCase() != 'general') ...[
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withAlpha(25),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.error.withAlpha(60),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Danger Zone',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Deleting this category will prompt you to reassign or remove all associated menu items.',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            key: const ValueKey('dialog_delete_category_btn'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                              side: BorderSide(color: theme.colorScheme.error.withAlpha(150)),
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            label: const Text(
                              'Delete Category',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            onPressed: _confirmDelete,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant.withAlpha(80),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(theme.brightness == Brightness.dark ? 30 : 10),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  key: const ValueKey('category_edit_save_btn'),
                  onPressed: _saveCategory,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: const Text(
                    'Save Changes',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
