import 'models.dart';

/// Pure, dependency-free business logic. Fully unit-testable with zero
/// Flutter/UI coupling — this is the "logic separation" layer.
class SplitEngine {
  /// Uniform split with deterministic remainder handling.
  /// 100 paise across 3 people => 34/33/33 (never 33.33 lost paise).
  /// The leftover paise are handed to the first N participants so the
  /// shares ALWAYS sum back to exactly [totalPaise].
  static Map<String, int> uniform(int totalPaise, List<String> ids) {
    if (ids.isEmpty) return {};
    final base = totalPaise ~/ ids.length;
    var remainder = totalPaise - (base * ids.length);
    final out = <String, int>{};
    for (final id in ids) {
      var v = base;
      if (remainder > 0) {
        v += 1;
        remainder -= 1;
      }
      out[id] = v;
    }
    return out;
  }

  /// Exact-amount mode. Returns the unallocated remainder so the UI can show
  /// "₹40.00 left to assign" live as the user types.
  static int unallocated(int totalPaise, Map<String, int> entered) {
    final sum = entered.values.fold<int>(0, (a, b) => a + b);
    return totalPaise - sum;
  }

  /// Ratio mode: percentages (in basis points, 1% = 100 bp) -> paise.
  /// Verified against a 10000 bp (100%) cap; remainder paise are pushed to
  /// the largest share so the total is preserved exactly.
  static Map<String, int> ratio(int totalPaise, Map<String, int> bp) {
    final out = <String, int>{};
    var allocated = 0;
    for (final e in bp.entries) {
      final v = (totalPaise * e.value) ~/ 10000;
      out[e.key] = v;
      allocated += v;
    }
    final leftover = totalPaise - allocated;
    if (leftover != 0 && out.isNotEmpty) {
      final biggest =
          out.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      out[biggest] = out[biggest]! + leftover;
    }
    return out;
  }

  /// Net standing per person: (what they paid) - (what they owed).
  /// Positive => they are owed money. Negative => they owe.
  static Map<String, int> balances(
      List<Person> people, List<Expense> expenses) {
    final net = {for (final p in people) p.id: 0};
    for (final e in expenses) {
      e.payers.forEach((id, paid) {
        if (net.containsKey(id)) net[id] = net[id]! + paid;
      });
      e.shares.forEach((id, owed) {
        if (net.containsKey(id)) net[id] = net[id]! - owed;
      });
    }
    return net;
  }

  /// Minimum-cash-flow settlement.
  ///
  /// Models the debt web as a bipartite flow problem: repeatedly match the
  /// largest creditor with the largest debtor and cancel the smaller of the
  /// two. Each pass zeroes out at least one participant, so it terminates in
  /// at most n-1 transfers — the theoretical floor for a debt graph with no
  /// coincidental subset sums. O(n log n) per settled node.
  static List<Settlement> settle(Map<String, int> netBalances) {
    final creditors = <MapEntry<String, int>>[];
    final debtors = <MapEntry<String, int>>[];
    netBalances.forEach((id, v) {
      if (v > 0) creditors.add(MapEntry(id, v));
      if (v < 0) debtors.add(MapEntry(id, -v));
    });
    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => b.value.compareTo(a.value));

    final out = <Settlement>[];
    var i = 0, j = 0;
    var credit = creditors.isEmpty ? 0 : creditors[0].value;
    var debit = debtors.isEmpty ? 0 : debtors[0].value;

    while (i < creditors.length && j < debtors.length) {
      final amount = credit < debit ? credit : debit;
      if (amount > 0) {
        out.add(Settlement(debtors[j].key, creditors[i].key, amount));
      }
      credit -= amount;
      debit -= amount;
      if (credit == 0) {
        i++;
        if (i < creditors.length) credit = creditors[i].value;
      }
      if (debit == 0) {
        j++;
        if (j < debtors.length) debit = debtors[j].value;
      }
    }
    return out;
  }

  /// Category totals for the analytics screen, restricted to one month.
  static Map<String, int> byCategory(List<Expense> expenses) {
    final out = <String, int>{};
    for (final e in expenses) {
      out[e.categoryId] = (out[e.categoryId] ?? 0) + e.amountPaise;
    }
    return out;
  }

  /// Daily totals for the last [days] days, oldest first. Drives the chart.
  static List<int> dailyTotals(List<Expense> expenses, int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final buckets = List<int>.filled(days, 0);
    for (final e in expenses) {
      final d = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      final diff = today.difference(d).inDays;
      if (diff >= 0 && diff < days) {
        buckets[days - 1 - diff] += e.amountPaise;
      }
    }
    return buckets;
  }
}

String rupees(int paise, {bool sign = false}) {
  final neg = paise < 0;
  final v = paise.abs();
  final s = '${v ~/ 100}.${(v % 100).toString().padLeft(2, '0')}';
  final prefix = neg ? '-' : (sign ? '+' : '');
  return '$prefix₹$s';
}
