import 'package:campus_quicksplit/core/models.dart';
import 'package:campus_quicksplit/core/split_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('uniform split', () {
    test('never loses a paisa on an indivisible amount', () {
      final s = SplitEngine.uniform(10000, ['a', 'b', 'c']); // ₹100 / 3
      expect(s.values.fold<int>(0, (x, y) => x + y), 10000);
      expect(s['a'], 3334);
      expect(s['b'], 3333);
      expect(s['c'], 3333);
    });

    test('handles a single participant', () {
      expect(SplitEngine.uniform(500, ['a']), {'a': 500});
    });
  });

  group('exact split', () {
    test('reports the unallocated remainder', () {
      expect(SplitEngine.unallocated(10000, {'a': 4000, 'b': 2000}), 4000);
      expect(SplitEngine.unallocated(10000, {'a': 12000}), -2000);
    });
  });

  group('ratio split', () {
    test('60/40 of ₹250 and totals are preserved', () {
      final s = SplitEngine.ratio(25000, {'a': 6000, 'b': 4000});
      expect(s['a'], 15000);
      expect(s['b'], 10000);
      expect(s.values.fold<int>(0, (x, y) => x + y), 25000);
    });

    test('rounding leftovers land on the largest share', () {
      final s = SplitEngine.ratio(10000, {'a': 3333, 'b': 3333, 'c': 3334});
      expect(s.values.fold<int>(0, (x, y) => x + y), 10000);
    });
  });

  group('settlement optimisation', () {
    test('collapses a 3-person debt web into 2 transfers', () {
      final people = const [
        Person(id: 'a', name: 'A'),
        Person(id: 'b', name: 'B'),
        Person(id: 'c', name: 'C'),
      ];
      final expenses = [
        Expense(
          id: '1',
          title: 'Auto',
          categoryId: 'auto',
          amountPaise: 30000,
          createdAt: DateTime.now(),
          mode: SplitMode.uniform,
          payers: const {'a': 30000},
          shares: const {'a': 10000, 'b': 10000, 'c': 10000},
        ),
        Expense(
          id: '2',
          title: 'Pizza',
          categoryId: 'food',
          amountPaise: 30000,
          createdAt: DateTime.now(),
          mode: SplitMode.uniform,
          payers: const {'b': 30000},
          shares: const {'a': 10000, 'b': 10000, 'c': 10000},
        ),
      ];
      final net = SplitEngine.balances(people, expenses);
      expect(net['a'], 10000);
      expect(net['b'], 10000);
      expect(net['c'], -20000);

      final tx = SplitEngine.settle(net);
      expect(tx.length, 2); // not 4
      expect(tx.every((t) => t.fromId == 'c'), isTrue);
      expect(tx.fold<int>(0, (x, t) => x + t.amountPaise), 20000);
    });

    test('returns nothing when the group is square', () {
      expect(SplitEngine.settle({'a': 0, 'b': 0}), isEmpty);
    });
  });

  test('currency formatting', () {
    expect(rupees(12345), '₹123.45');
    expect(rupees(-500), '-₹5.00');
    expect(rupees(500, sign: true), '+₹5.00');
  });
}
