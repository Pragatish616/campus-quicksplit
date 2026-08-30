import 'package:hive_flutter/hive_flutter.dart';
import 'models.dart';

/// Local-first persistence layer (Phase 2).
///
/// Hive is a pure-Dart, key-value NoSQL engine that writes to a binary file in
/// the app's own document directory. No network, no auth, no cold-start sync:
/// the app is fully usable in airplane mode, which is the whole point of the
/// problem statement. Boxes are opened once at startup and every mutation is
/// written through immediately, so a force-kill never loses a transaction.
class Store {
  static const _peopleBox = 'people_v1';
  static const _expenseBox = 'expenses_v1';
  static const _prefsBox = 'prefs_v1';

  late final Box _people;
  late final Box _expenses;
  late final Box _prefs;

  Future<void> init() async {
    await Hive.initFlutter();
    _people = await Hive.openBox(_peopleBox);
    _expenses = await Hive.openBox(_expenseBox);
    _prefs = await Hive.openBox(_prefsBox);
  }

  List<Person> loadPeople() => _people.values
      .map((e) => Person.fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();

  List<Expense> loadExpenses() {
    final list = _expenses.values
        .map((e) => Expense.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> putPerson(Person p) => _people.put(p.id, p.toMap());
  Future<void> deletePerson(String id) => _people.delete(id);

  Future<void> putExpense(Expense e) => _expenses.put(e.id, e.toMap());
  Future<void> deleteExpense(String id) => _expenses.delete(id);

  bool get isDark => _prefs.get('dark', defaultValue: false) as bool;
  Future<void> setDark(bool v) => _prefs.put('dark', v);

  bool get seeded => _prefs.get('seeded', defaultValue: false) as bool;
  Future<void> markSeeded() => _prefs.put('seeded', true);
}
