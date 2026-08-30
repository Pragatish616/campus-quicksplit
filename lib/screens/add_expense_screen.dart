import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/split_engine.dart';

int? parsePaise(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  if (v == null || v.isNaN || v.isInfinite) return null;
  return (v * 100).round();
}

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});
  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();

  ExpenseCategory _category = ExpenseCategory.auto;
  SplitMode _mode = SplitMode.uniform;
  final Set<String> _participants = {};
  String? _payerId;

  /// mode-specific inputs, keyed by personId
  final Map<String, TextEditingController> _exact = {};
  final Map<String, TextEditingController> _pct = {};

  @override
  void initState() {
    super.initState();
    final people = context.read<AppState>().people;
    _participants.addAll(people.map((p) => p.id));
    _payerId = people.isEmpty ? null : people.first.id;
    for (final p in people) {
      _exact[p.id] = TextEditingController();
      _pct[p.id] = TextEditingController();
    }
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    for (final c in _exact.values) {
      c.dispose();
    }
    for (final c in _pct.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _total => parsePaise(_amount.text) ?? 0;

  Map<String, int> get _exactEntered => {
        for (final id in _participants)
          id: parsePaise(_exact[id]?.text ?? '') ?? 0
      };

  /// percentages in basis points (1% = 100bp)
  Map<String, int> get _pctEntered => {
        for (final id in _participants)
          id: ((double.tryParse(_pct[id]?.text.trim() ?? '') ?? 0) * 100).round()
      };

  int get _unallocated => SplitEngine.unallocated(_total, _exactEntered);
  int get _pctTotal => _pctEntered.values.fold<int>(0, (a, b) => a + b);

  String? _validateSplit() {
    if (_participants.isEmpty) return 'Select at least one participant.';
    if (_total <= 0) return 'Amount must be greater than zero.';
    switch (_mode) {
      case SplitMode.uniform:
        return null;
      case SplitMode.exact:
        if (_unallocated != 0) {
          return _unallocated > 0
              ? '${rupees(_unallocated)} is still unallocated.'
              : '${rupees(_unallocated.abs())} over the bill total.';
        }
        return null;
      case SplitMode.ratio:
        if (_pctTotal != 10000) {
          final pct = (_pctTotal / 100).toStringAsFixed(2);
          return 'Percentages add up to $pct% — must be exactly 100%.';
        }
        return null;
    }
  }

  void _save() {
    final messenger = ScaffoldMessenger.of(context);
    if (!_form.currentState!.validate()) return;
    if (_payerId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Pick who paid.')));
      return;
    }
    final err = _validateSplit();
    if (err != null) {
      messenger.showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    final ids = _participants.toList();
    final shares = switch (_mode) {
      SplitMode.uniform => SplitEngine.uniform(_total, ids),
      SplitMode.exact => _exactEntered,
      SplitMode.ratio => SplitEngine.ratio(_total, _pctEntered),
    };
    final expense = Expense(
      id: AppState.newId(),
      title: _title.text.trim(),
      categoryId: _category.id,
      amountPaise: _total,
      createdAt: DateTime.now(),
      mode: _mode,
      payers: {_payerId!: _total},
      shares: shares,
    );
    context.read<AppState>().addExpense(expense);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Added “${expense.title}” · ${rupees(_total)}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final preview = _mode == SplitMode.uniform && _total > 0
        ? SplitEngine.uniform(_total, _participants.toList())
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('New expense')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What was it for?',
                hintText: 'Auto to campus',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Give the expense a title.'
                  : (v.trim().length > 60 ? 'Keep it under 60 characters.' : null),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Total amount',
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
              validator: (v) {
                final p = parsePaise(v ?? '');
                if (p == null) return 'Enter a valid amount.';
                if (p <= 0) return 'Amount must be greater than zero.';
                if (p > 100000000) return 'That looks too large.';
                return null;
              },
            ),
            const SizedBox(height: 18),
            _Label('Category'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExpenseCategory.all
                  .map((c) => ChoiceChip(
                        selected: _category.id == c.id,
                        onSelected: (_) => setState(() => _category = c),
                        avatar: Icon(c.icon, size: 17, color: c.color),
                        label: Text(c.label),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 18),
            _Label('Paid by'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.people
                  .map((p) => ChoiceChip(
                        selected: _payerId == p.id,
                        onSelected: (_) => setState(() => _payerId = p.id),
                        avatar: const Icon(Icons.account_circle_outlined,
                            size: 17),
                        label: Text(p.name),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 18),
            _Label('Split between'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.people.map((p) {
                final on = _participants.contains(p.id);
                return FilterChip(
                  selected: on,
                  label: Text(p.name),
                  onSelected: (s) => setState(() {
                    if (s) {
                      _participants.add(p.id);
                    } else {
                      _participants.remove(p.id);
                    }
                  }),
                );
              }).toList(),
            ),
            if (_participants.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Select at least one participant.',
                    style: TextStyle(color: cs.error, fontSize: 12)),
              ),
            const SizedBox(height: 18),
            _Label('How to split'),
            SegmentedButton<SplitMode>(
              segments: SplitMode.values
                  .map((m) => ButtonSegment(
                        value: m,
                        icon: Icon(m.icon, size: 17),
                        label: Text(m.label),
                      ))
                  .toList(),
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 14),
            if (_mode == SplitMode.uniform)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.auto_awesome_rounded,
                            size: 17, color: cs.primary),
                        const SizedBox(width: 8),
                        Text('Even split preview',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: cs.primary)),
                      ]),
                      const SizedBox(height: 10),
                      if (preview == null || preview.isEmpty)
                        Text('Enter an amount to see the breakdown.',
                            style: TextStyle(color: cs.outline))
                      else
                        ...preview.entries.map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(children: [
                                Text(state.nameOf(e.key)),
                                const Spacer(),
                                Text(rupees(e.value),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ]),
                            )),
                      if (preview != null &&
                          preview.values.toSet().length > 1) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Leftover paise are handed to the first payers so the '
                          'shares add back to exactly ${rupees(_total)}.',
                          style: TextStyle(fontSize: 11.5, color: cs.outline),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (_mode == SplitMode.exact)
              _AllocationCard(
                title: 'Assign exact amounts',
                statusColor: _unallocated == 0
                    ? const Color(0xFF34A853)
                    : cs.error,
                status: _unallocated == 0
                    ? 'Fully allocated'
                    : _unallocated > 0
                        ? '${rupees(_unallocated)} left to assign'
                        : '${rupees(_unallocated.abs())} over budget',
                rows: _participants
                    .map((id) => _AllocRow(
                          name: state.nameOf(id),
                          controller: _exact[id]!,
                          suffix: '₹',
                          onChanged: () => setState(() {}),
                        ))
                    .toList(),
              ),
            if (_mode == SplitMode.ratio)
              _AllocationCard(
                title: 'Assign percentages',
                statusColor:
                    _pctTotal == 10000 ? const Color(0xFF34A853) : cs.error,
                status:
                    '${(_pctTotal / 100).toStringAsFixed(2)}% of 100% allocated',
                rows: _participants
                    .map((id) => _AllocRow(
                          name: state.nameOf(id),
                          controller: _pct[id]!,
                          suffix: '%',
                          trailing: _total > 0 && _pctTotal > 0
                              ? rupees(
                                  SplitEngine.ratio(_total, _pctEntered)[id] ??
                                      0)
                              : null,
                          onChanged: () => setState(() {}),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.check_rounded),
        label: const Text('Save expense'),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );
}

class _AllocRow extends StatelessWidget {
  const _AllocRow({
    required this.name,
    required this.controller,
    required this.suffix,
    required this.onChanged,
    this.trailing,
  });
  final String name;
  final TextEditingController controller;
  final String suffix;
  final String? trailing;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
              flex: 4,
              child: Text(name,
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (trailing != null) ...[
            Text(trailing!,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).colorScheme.outline)),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 3,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.end,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                suffixText: suffix,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllocationCard extends StatelessWidget {
  const _AllocationCard({
    required this.title,
    required this.status,
    required this.statusColor,
    required this.rows,
  });
  final String title;
  final String status;
  final Color statusColor;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5),
              child: Text(status),
            ),
            const SizedBox(height: 8),
            ...rows,
          ],
        ),
      ),
    );
  }
}
