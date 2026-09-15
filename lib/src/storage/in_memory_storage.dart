import '../models/stall_models.dart';
import '../models/counter_model.dart';
import '../models/counter_log_entry.dart';
import 'stall_storage.dart';
import 'counter_storage.dart';

/// In-memory implementation of [StallStorage] and [CounterStorage] for testing,
/// demoing, or transient sessions.
class InMemoryStorage implements StallStorage, CounterStorage {
  List<MenuItem> _menu = [];
  List<StallOrder> _orders = [];
  final List<StallOrder> _archivedOrders = [];
  List<ItemCategory> _categories = [];
  List<String> _predefinedNotes = [];
  int _nextToken = 1;

  List<CounterModel> _counters = [];
  List<CounterLogEntry> _logs = [];

  InMemoryStorage({
    List<MenuItem>? initialMenu,
    List<StallOrder>? initialOrders,
    List<ItemCategory>? initialCategories,
    List<String>? initialPredefinedNotes,
    int initialToken = 1,
    List<CounterModel>? initialCounters,
    List<CounterLogEntry>? initialLogs,
  })  : _menu = initialMenu != null ? List.from(initialMenu) : [],
        _orders = initialOrders != null ? List.from(initialOrders) : [],
        _categories = initialCategories != null ? List.from(initialCategories) : [],
        _predefinedNotes = initialPredefinedNotes != null ? List.from(initialPredefinedNotes) : [],
        _nextToken = initialToken,
        _counters = initialCounters != null ? List.from(initialCounters) : [],
        _logs = initialLogs != null ? List.from(initialLogs) : [];

  // ---------------------------------------------------------------------------
  // StallStorage Implementation
  // ---------------------------------------------------------------------------

  @override
  Future<List<MenuItem>> loadMenu() async => List.unmodifiable(_menu);

  @override
  Future<void> saveMenu(List<MenuItem> items) async {
    _menu = List.from(items);
  }

  @override
  Future<List<StallOrder>> loadOrders() async => List.unmodifiable(_orders);

  @override
  Future<void> saveOrders(List<StallOrder> orders) async {
    _orders = List.from(orders);
  }

  @override
  Future<int> loadNextToken() async => _nextToken;

  @override
  Future<void> saveNextToken(int token) async {
    _nextToken = token;
  }

  @override
  Future<List<StallOrder>> clearCompletedOrders() async {
    _orders.removeWhere((o) => o.isCompleted);
    return List.unmodifiable(_orders);
  }

  @override
  Future<int> archiveCompletedOrders({
    Duration threshold = const Duration(hours: 24),
    List<StallOrder>? explicitOrders,
  }) async {
    final now = DateTime.now();
    final toArchive = <StallOrder>[];
    final toKeep = <StallOrder>[];

    if (explicitOrders != null) {
      final explicitTokens = explicitOrders.map((o) => o.token).toSet();
      for (final o in _orders) {
        if (explicitTokens.contains(o.token)) {
          toArchive.add(o);
        } else {
          toKeep.add(o);
        }
      }
    } else {
      for (final o in _orders) {
        if (o.isCompleted &&
            o.completedAt != null &&
            now.difference(o.completedAt!) > threshold) {
          toArchive.add(o);
        } else {
          toKeep.add(o);
        }
      }
    }

    if (toArchive.isEmpty) return 0;

    _archivedOrders.addAll(toArchive);
    _orders = toKeep;
    return toArchive.length;
  }

  @override
  Future<List<StallOrder>> loadArchivedOrders() async =>
      List.unmodifiable(_archivedOrders);

  @override
  Future<void> clearAllOrders({bool resetToken = false}) async {
    _orders.clear();
    _archivedOrders.clear();
    if (resetToken) {
      _nextToken = 1;
    }
  }

  @override
  Future<List<ItemCategory>> loadCategories() async =>
      List.unmodifiable(_categories);

  @override
  Future<void> saveCategories(List<ItemCategory> categories) async {
    _categories = List.from(categories);
  }

  @override
  Future<List<String>> loadPredefinedNotes() async =>
      List.unmodifiable(_predefinedNotes);

  @override
  Future<void> savePredefinedNotes(List<String> notes) async {
    _predefinedNotes = List.from(notes);
  }

  // ---------------------------------------------------------------------------
  // CounterStorage Implementation
  // ---------------------------------------------------------------------------

  @override
  Future<List<CounterModel>> loadCounters() async => List.unmodifiable(_counters);

  @override
  Future<bool> saveCounters(List<CounterModel> counters) async {
    _counters = List.from(counters);
    return true;
  }

  @override
  Future<List<CounterLogEntry>> loadLogs() async => List.unmodifiable(_logs);

  @override
  Future<bool> saveLogs(List<CounterLogEntry> logs) async {
    _logs = List.from(logs);
    return true;
  }

  @override
  Future<bool> clearLogs() async {
    _logs.clear();
    return true;
  }

  @override
  Future<bool> clearAll() async {
    _counters.clear();
    _logs.clear();
    return true;
  }
}

/// Backwards-compatible alias for [InMemoryStorage].
typedef InMemoryStallStorage = InMemoryStorage;

/// Backwards-compatible alias for [InMemoryStorage].
typedef InMemoryCounterStorage = InMemoryStorage;
