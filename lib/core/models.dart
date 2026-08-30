import 'package:flutter/material.dart';

/// All money is stored as integer paise (1 rupee = 100 paise).
/// This eliminates floating-point drift entirely and makes remainder
/// distribution deterministic and auditable.

enum SplitMode { uniform, exact, ratio }

extension SplitModeX on SplitMode {
  String get label => switch (this) {
        SplitMode.uniform => 'Equally',
        SplitMode.exact => 'Exact amounts',
        SplitMode.ratio => 'By percentage',
      };
  IconData get icon => switch (this) {
        SplitMode.uniform => Icons.balance_rounded,
        SplitMode.exact => Icons.pin_rounded,
        SplitMode.ratio => Icons.percent_rounded,
      };
}

class ExpenseCategory {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  const ExpenseCategory(this.id, this.label, this.icon, this.color);

  static const auto = ExpenseCategory(
      'auto', 'Auto / Cab', Icons.local_taxi_rounded, Color(0xFFF9AB00));
  static const food = ExpenseCategory(
      'food', 'Food', Icons.restaurant_rounded, Color(0xFFEA4335));
  static const subs = ExpenseCategory(
      'subs', 'Subscriptions', Icons.subscriptions_rounded, Color(0xFF4285F4));
  static const print = ExpenseCategory(
      'print', 'Printouts', Icons.print_rounded, Color(0xFF34A853));
  static const stay = ExpenseCategory(
      'stay', 'Rent / Stay', Icons.home_work_rounded, Color(0xFF9334E6));
  static const misc = ExpenseCategory(
      'misc', 'Misc', Icons.category_rounded, Color(0xFF5F6368));

  static const all = <ExpenseCategory>[auto, food, subs, print, stay, misc];

  static ExpenseCategory byId(String id) =>
      all.firstWhere((c) => c.id == id, orElse: () => misc);
}

class Person {
  final String id;
  final String name;
  const Person({required this.id, required this.name});

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Map<String, dynamic> toMap() => {'id': id, 'name': name};
  factory Person.fromMap(Map m) =>
      Person(id: m['id'] as String, name: m['name'] as String);
}

class Expense {
  final String id;
  final String title;
  final String categoryId;
  final int amountPaise;
  final DateTime createdAt;
  final SplitMode mode;

  /// personId -> paise actually paid up front (Phase 3: multi-payer).
  final Map<String, int> payers;

  /// personId -> paise owed for this bill. Always sums to [amountPaise].
  final Map<String, int> shares;

  const Expense({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.amountPaise,
    required this.createdAt,
    required this.mode,
    required this.payers,
    required this.shares,
  });

  ExpenseCategory get category => ExpenseCategory.byId(categoryId);

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'categoryId': categoryId,
        'amountPaise': amountPaise,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'mode': mode.name,
        'payers': payers,
        'shares': shares,
      };

  factory Expense.fromMap(Map m) => Expense(
        id: m['id'] as String,
        title: m['title'] as String,
        categoryId: m['categoryId'] as String,
        amountPaise: (m['amountPaise'] as num).toInt(),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch((m['createdAt'] as num).toInt()),
        mode: SplitMode.values.firstWhere((e) => e.name == m['mode'],
            orElse: () => SplitMode.uniform),
        payers: Map<String, int>.from(
            (m['payers'] as Map).map((k, v) => MapEntry(k as String, (v as num).toInt()))),
        shares: Map<String, int>.from(
            (m['shares'] as Map).map((k, v) => MapEntry(k as String, (v as num).toInt()))),
      );
}

/// One optimised repayment instruction.
class Settlement {
  final String fromId;
  final String toId;
  final int amountPaise;
  const Settlement(this.fromId, this.toId, this.amountPaise);
}
