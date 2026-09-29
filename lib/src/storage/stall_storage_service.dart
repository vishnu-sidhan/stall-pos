import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stall_models.dart';
import 'stall_storage.dart';

/// Local storage service responsible for managing Stall POS menus, orders, and tokens via SharedPreferences.
class StallStorageService implements StallStorage {
  static const String _menuKey = 'stall_menu';
  static const String _ordersKey = 'stall_orders';
  static const String _tokenKey = 'stall_next_token';
  static const String _categoriesKey = 'stall_categories';
  static const String _predefinedNotesKey = 'stall_predefined_notes';
  static const String _autoAddSingleVariantKey = 'stall_auto_add_single_variant';
  static const String _splitVariantsAsCategoriesKey = 'stall_split_variants_as_categories';
  static const String _explodeSingleCategoryKey = 'stall_explode_single_category';

  final SharedPreferences? _prefs;
  bool _autoAddSingleVariant = true;
  bool _splitVariantsAsCategories = true;

  StallStorageService({SharedPreferences? prefs}) : _prefs = prefs {
    if (prefs != null) {
      _autoAddSingleVariant = prefs.getBool(_autoAddSingleVariantKey) ?? true;
      _splitVariantsAsCategories = prefs.getBool(_splitVariantsAsCategoriesKey) ??
          prefs.getBool(_explodeSingleCategoryKey) ??
          true;
    }
  }

  Future<SharedPreferences> _getPrefs() async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    _autoAddSingleVariant = p.getBool(_autoAddSingleVariantKey) ?? _autoAddSingleVariant;
    _splitVariantsAsCategories = p.getBool(_splitVariantsAsCategoriesKey) ??
        p.getBool(_explodeSingleCategoryKey) ??
        _splitVariantsAsCategories;
    return p;
  }

  /// Loads menu items.
  @override
  Future<List<MenuItem>> loadMenu() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_menuKey);
    if (raw == null) return [];

    try {
      final List decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => MenuItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves menu items.
  @override
  Future<void> saveMenu(List<MenuItem> items) async {
    final prefs = await _getPrefs();
    await prefs.setString(
      _menuKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  /// Loads all orders.
  @override
  Future<List<StallOrder>> loadOrders() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_ordersKey);
    if (raw == null) return [];

    try {
      final List decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => StallOrder.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves orders.
  @override
  Future<void> saveOrders(List<StallOrder> orders) async {
    final prefs = await _getPrefs();
    await prefs.setString(
      _ordersKey,
      jsonEncode(orders.map((e) => e.toJson()).toList()),
    );
  }

  /// Loads the next order token counter.
  @override
  Future<int> loadNextToken() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_tokenKey) ?? 1;
  }

  /// Saves the next order token counter.
  @override
  Future<void> saveNextToken(int token) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_tokenKey, token);
  }

  /// Deletes only completed orders from storage, keeping active/pending orders intact.
  @override
  Future<List<StallOrder>> clearCompletedOrders() async {
    final current = await loadOrders();
    final remaining = current.where((o) => !o.isCompleted).toList();
    await saveOrders(remaining);
    return remaining;
  }

  static const String _archiveKey = 'stall_orders_archive';

  /// Archives completed orders into a separate archive store,
  /// keeping the active orders list lightweight.
  /// If [explicitOrders] is provided, archives those specific orders;
  /// otherwise archives orders completed longer ago than [threshold].
  @override
  Future<int> archiveCompletedOrders({
    Duration threshold = const Duration(hours: 24),
    List<StallOrder>? explicitOrders,
  }) async {
    final prefs = await _getPrefs();
    final currentOrders = await loadOrders();
    final now = DateTime.now();

    final toKeep = <StallOrder>[];
    final toArchive = <StallOrder>[];

    if (explicitOrders != null) {
      final explicitTokens = explicitOrders.map((o) => o.token).toSet();
      for (final order in currentOrders) {
        if (explicitTokens.contains(order.token)) {
          toArchive.add(order);
        } else {
          toKeep.add(order);
        }
      }
    } else {
      for (final order in currentOrders) {
        if (order.isCompleted &&
            order.completedAt != null &&
            now.difference(order.completedAt!) > threshold) {
          toArchive.add(order);
        } else {
          toKeep.add(order);
        }
      }
    }

    if (toArchive.isEmpty) return 0;

    final existingArchived = await loadArchivedOrders();
    final combinedArchive = [...existingArchived, ...toArchive];

    await prefs.setString(
      _archiveKey,
      jsonEncode(combinedArchive.map((e) => e.toJson()).toList()),
    );
    await saveOrders(toKeep);

    return toArchive.length;
  }

  /// Loads archived orders from storage.
  @override
  Future<List<StallOrder>> loadArchivedOrders() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_archiveKey);
    if (raw == null) return [];

    try {
      final List decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => StallOrder.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Clears all order history entirely and resets token counter.
  @override
  Future<void> clearAllOrders({bool resetToken = false}) async {
    final prefs = await _getPrefs();
    await prefs.remove(_ordersKey);
    await prefs.remove(_archiveKey);
    if (resetToken) {
      await prefs.setInt(_tokenKey, 1);
    }
  }

  /// Loads category configurations and additional costs.
  @override
  Future<List<ItemCategory>> loadCategories() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_categoriesKey);
    if (raw == null) return [];

    try {
      final List decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => ItemCategory.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves category configurations.
  @override
  Future<void> saveCategories(List<ItemCategory> categories) async {
    final prefs = await _getPrefs();
    await prefs.setString(
      _categoriesKey,
      jsonEncode(categories.map((e) => e.toJson()).toList()),
    );
  }

  /// Loads predefined quick notes for orders.
  @override
  Future<List<String>> loadPredefinedNotes() async {
    final prefs = await _getPrefs();
    final rawList = prefs.getStringList(_predefinedNotesKey);
    if (rawList != null) return rawList;

    final rawJson = prefs.getString(_predefinedNotesKey);
    if (rawJson != null) {
      try {
        final List decoded = jsonDecode(rawJson) as List;
        return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  /// Saves predefined quick notes for orders.
  @override
  Future<void> savePredefinedNotes(List<String> notes) async {
    final prefs = await _getPrefs();
    await prefs.setStringList(_predefinedNotesKey, notes);
  }

  /// Whether to automatically add single-variant items directly to the cart without opening the customization sheet.
  @override
  bool get autoAddSingleVariant =>
      _prefs?.getBool(_autoAddSingleVariantKey) ?? _autoAddSingleVariant;

  /// Persists the auto-add single variant preference.
  @override
  Future<void> setAutoAddSingleVariant(bool value) async {
    _autoAddSingleVariant = value;
    final prefs = await _getPrefs();
    await prefs.setBool(_autoAddSingleVariantKey, value);
  }

  /// Whether to group variants into individual category accordions when only one category is active.
  @override
  bool get splitVariantsAsCategories =>
      _prefs?.getBool(_splitVariantsAsCategoriesKey) ??
      _prefs?.getBool(_explodeSingleCategoryKey) ??
      _splitVariantsAsCategories;

  /// Persists the split variants as categories preference.
  @override
  Future<void> setSplitVariantsAsCategories(bool value) async {
    _splitVariantsAsCategories = value;
    final prefs = await _getPrefs();
    await prefs.setBool(_splitVariantsAsCategoriesKey, value);
    await prefs.setBool(_explodeSingleCategoryKey, value);
  }

  /// Alias for [splitVariantsAsCategories].
  @override
  bool get explodeSingleCategory => splitVariantsAsCategories;

  /// Alias for [setSplitVariantsAsCategories].
  @override
  Future<void> setExplodeSingleCategory(bool value) =>
      setSplitVariantsAsCategories(value);
}

