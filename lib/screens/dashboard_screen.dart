import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/split_engine.dart';
import 'people_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final balances = state.balances;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        _TotalCard(total: state.totalSpent, net: state.myNet, count: state.expenses.length),
        const SizedBox(height: 20),
        Row(
          children: [
            Text('Who owes what',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PeopleScreen())),
              icon: const Icon(Icons.group_add_outlined, size: 18),
              label: const Text('Manage'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (state.people.isEmpty)
          const _Empty(
              icon: Icons.group_outlined,
              text: 'Add a few people to start splitting.')
        else
          ...state.people.map((p) {
            final net = balances[p.id] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _BalanceTile(person: p, net: net),
            );
          }),
        const SizedBox(height: 20),
        Text('Recent',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (state.expenses.isEmpty)
          const _Empty(
              icon: Icons.receipt_long_outlined,
              text: 'No expenses yet. Tap “Add expense”.')
        else
          ...state.expenses.take(4).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: e.category.color.withValues(alpha: .16),
                      child: Icon(e.category.icon,
                          color: e.category.color, size: 20),
                    ),
                    title: Text(e.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${e.mode.label} · ${e.shares.length} people'),
                    trailing: Text(rupees(e.amountPaise),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface)),
                  ),
                ),
              )),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total, required this.net, required this.count});
  final int total;
  final int net;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final positive = net >= 0;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primaryContainer, cs.tertiaryContainer],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  size: 18, color: cs.onPrimaryContainer),
              const SizedBox(width: 8),
              Text('Total group spend',
                  style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.cloud_off_rounded, size: 13, color: cs.onSurface),
                  const SizedBox(width: 5),
                  Text('Offline',
                      style: TextStyle(fontSize: 11, color: cs.onSurface)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: Text(
              rupees(total),
              key: ValueKey(total),
              style: TextStyle(
                fontSize: 38,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            net == 0
                ? 'You are all settled up · $count entries'
                : positive
                    ? 'You are owed ${rupees(net)} · $count entries'
                    : 'You owe ${rupees(net.abs())} · $count entries',
            style: TextStyle(
                color: cs.onPrimaryContainer.withValues(alpha: .8),
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({required this.person, required this.net});
  final Person person;
  final int net;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settled = net == 0;
    final owed = net > 0;
    final color = settled
        ? cs.outline
        : owed
            ? const Color(0xFF34A853)
            : const Color(0xFFEA4335);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.secondaryContainer,
          child: Text(person.initials,
              style: TextStyle(
                  color: cs.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ),
        title: Text(person.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(settled
            ? 'settled up'
            : owed
                ? 'gets back'
                : 'owes'),
        trailing: Text(
          settled ? '—' : rupees(net.abs()),
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
        child: Column(children: [
          Icon(icon, color: cs.outline),
          const SizedBox(height: 8),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.outline)),
        ]),
      ),
    );
  }
}
