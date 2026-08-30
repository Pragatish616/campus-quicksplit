import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/split_engine.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final items = state.expenses;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 42, color: cs.outline),
            const SizedBox(height: 10),
            Text('Nothing logged yet.', style: TextStyle(color: cs.outline)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final e = items[i];
        final showHeader = i == 0 ||
            !_sameDay(items[i - 1].createdAt, e.createdAt);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 16, bottom: 8),
                child: Text(
                  _dayLabel(e.createdAt),
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: cs.primary),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ExpenseCard(expense: e),
            ),
          ],
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    return DateFormat('EEEE, d MMM').format(d).toUpperCase();
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense});
  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    final e = expense;
    final payerId = e.payers.keys.isEmpty ? null : e.payers.keys.first;

    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(Icons.delete_outline_rounded, color: cs.onErrorContainer),
      ),
      onDismissed: (_) {
        final messenger = ScaffoldMessenger.of(context);
        state.deleteExpense(e.id);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Deleted “${e.title}”'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () => state.restoreExpense(e),
            ),
          ),
        );
      },
      child: Card(
        child: Theme(
          data: Theme.of(context)
              .copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            shape: const Border(),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            leading: CircleAvatar(
              backgroundColor: e.category.color.withValues(alpha: .16),
              child: Icon(e.category.icon, color: e.category.color, size: 20),
            ),
            title: Text(e.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${payerId == null ? '—' : state.nameOf(payerId)} paid · '
              '${DateFormat('h:mm a').format(e.createdAt)}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(rupees(e.amountPaise),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                Text(e.mode.label,
                    style: TextStyle(fontSize: 10.5, color: cs.outline)),
              ],
            ),
            children: e.shares.entries
                .map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Icon(Icons.subdirectory_arrow_right_rounded,
                            size: 15, color: cs.outline),
                        const SizedBox(width: 8),
                        Text(state.nameOf(s.key)),
                        const Spacer(),
                        Text('owes ${rupees(s.value)}',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}
