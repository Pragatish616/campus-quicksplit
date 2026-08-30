import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/split_engine.dart';

class SettleScreen extends StatelessWidget {
  const SettleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final balances = state.balances;
    final settlements = state.settlements;

    // How many transfers a naive "everyone pays back every payer" scheme
    // would need — the number we are optimising away.
    final naive = state.expenses.fold<int>(
        0,
        (a, e) =>
            a + e.shares.keys.where((id) => !e.payers.containsKey(id)).length);

    if (settlements.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 48, color: const Color(0xFF34A853)),
            const SizedBox(height: 12),
            const Text('Everyone is settled up.',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('No transfers needed.',
                style: TextStyle(color: cs.outline)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_fix_high_rounded, color: cs.onPrimaryContainer),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Debt web simplified',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimaryContainer)),
                    const SizedBox(height: 3),
                    Text(
                      '$naive raw IOUs collapsed into '
                      '${settlements.length} transfer'
                      '${settlements.length == 1 ? '' : 's'}.',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onPrimaryContainer.withValues(alpha: .85)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Pay these and you are done',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ...settlements.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      _Chip(text: state.nameOf(s.fromId), color: cs.errorContainer, fg: cs.onErrorContainer),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded,
                          size: 18, color: cs.outline),
                      const SizedBox(width: 8),
                      _Chip(
                          text: state.nameOf(s.toId),
                          color: cs.secondaryContainer,
                          fg: cs.onSecondaryContainer),
                      const Spacer(),
                      Text(rupees(s.amountPaise),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                    ],
                  ),
                ),
              ),
            )),
        const SizedBox(height: 18),
        Text('Net standing',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: state.people.map((p) {
                final v = balances[p.id] ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Text(p.name),
                    const Spacer(),
                    Text(
                      v == 0 ? 'settled' : rupees(v, sign: true),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: v == 0
                            ? cs.outline
                            : v > 0
                                ? const Color(0xFF34A853)
                                : const Color(0xFFEA4335),
                      ),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color, required this.fg});
  final String text;
  final Color color;
  final Color fg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(30)),
        child: Text(text,
            style: TextStyle(
                color: fg, fontSize: 12.5, fontWeight: FontWeight.w600)),
      );
}
