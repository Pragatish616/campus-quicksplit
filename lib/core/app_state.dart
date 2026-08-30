import 'dart:math';
import 'package:flutter/foundation.dart';
import 'models.dart';
import 'split_engine.dart';
import 'store.dart';

/// Single source of truth. A [ChangeNotifier] exposed through Provider —
/// widgets subscribe with `context.watch`, one-shot actions use
/// `context.read`, so no widget rebuilds unless the data it reads changed.
class AppState extends ChangeNotifier {
  AppState(this._store);
  final Store _store;

  List<Person> _people = [];
  List<Expense> _expenses = [];
  bool _dark = false;

  List<Person> get people => List.unmodifiable(_people);
  List<Expense> get expenses => List.unmodifiable(_expenses);
  bool get isDark => _dark;

  static final _rand = Random();
  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_rand.nextInt(9999)}';

  Future<void> load() async {
    _people = _store.loadPeople();
    _expenses = _store.loadExpenses();
    _dark = _store.isDark;
    if (!_store.seeded && _people.isEmpty) {
      for (final n in ['You', 'Raj', 'Priya']) {
        final p = Person(id: newId(), name: n);
        _people.add(p);
        await _store.putPerson(p);
      }
      await _store.markSeeded();
    }
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _dark = !_dark;
    await _store.setDark(_dark);
    notifyListeners();
  }

  // ---- people -------------------------------------------------------------

  Future<void> addPerson(String name) async {
    final p = Person(id: newId(), name: name.trim());
    _people = [..._people, p];
    await _store.putPerson(p);
    notifyListeners();
  }

  Future<void> removePerson(String id) async {
    _people = _people.where((p) => p.id != id).toList();
    await _store.deletePerson(id);
    notifyListeners();
  }

  Person? personById(String id) {
    for (final p in _people) {
      if (p.id == id) return p;
    }
    return null;
  }

  String nameOf(String id) => personById(id)?.name ?? 'Removed';

  // ---- expenses -----------------------------------------------------------

  Future<void> addExpense(Expense e) async {
    _expenses = [e, ..._expenses];
    await _store.putExpense(e);
    notifyListeners();
  }

  /// Swipe-to-delete with undo: the row leaves the list and the balances
  /// recompute instantly, but the record is only dropped from Hive here — the
  /// undo path re-inserts it, so nothing is ever half-committed.
  Future<void> deleteExpense(String id) async {
    _expenses = _expenses.where((e) => e.id != id).toList();
    await _store.deleteExpense(id);
    notifyListeners();
  }

  Future<void> restoreExpense(Expense e) async {
    _expenses = [..._expenses, e]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _store.putExpense(e);
    notifyListeners();
  }

  // ---- derived ------------------------------------------------------------

  Map<String, int> get balances => SplitEngine.balances(_people, _expenses);

  List<Settlement> get settlements => SplitEngine.settle(balances);

  int get totalSpent =>
      _expenses.fold<int>(0, (a, e) => a + e.amountPaise);

  int get myNet {
    final me = _people.isEmpty ? null : _people.first;
    if (me == null) return 0;
    return balances[me.id] ?? 0;
  }

  List<Expense> get thisMonth {
    final now = DateTime.now();
    return _expenses
        .where((e) =>
            e.createdAt.year == now.year && e.createdAt.month == now.month)
        .toList();
  }
}
