import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/split_engine.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});
  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _add() {
    final state = context.read<AppState>();
    final n = _name.text.trim();
    if (n.isEmpty) {
      setState(() => _error = 'Name cannot be empty.');
      return;
    }
    if (n.length > 24) {
      setState(() => _error = 'Keep names under 24 characters.');
      return;
    }
    if (state.people
        .any((p) => p.name.toLowerCase() == n.toLowerCase())) {
      setState(() => _error = 'That name is already in the group.');
      return;
    }
    state.addPerson(n);
    _name.clear();
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final balances = state.balances;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Group members')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _add(),
                  decoration: InputDecoration(
                    labelText: 'Add someone',
                    errorText: _error,
                    prefixIcon: const Icon(Icons.person_add_alt_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: FilledButton(
                    onPressed: _add, child: const Text('Add')),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...state.people.map((p) {
            final net = balances[p.id] ?? 0;
            final locked = net != 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.secondaryContainer,
                    child: Text(p.initials,
                        style: TextStyle(
                            color: cs.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ),
                  title: Text(p.name),
                  subtitle: Text(
                      locked ? 'open balance ${rupees(net, sign: true)}' : 'settled up',
                      style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(
                    tooltip: locked
                        ? 'Settle their balance first'
                        : 'Remove from group',
                    color: locked ? cs.outline : cs.error,
                    onPressed: () {
                      if (locked) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${p.name} still has an open balance of '
                              '${rupees(net.abs())}. Settle it on the Settle '
                              'tab first — removing them now would destroy '
                              'money in the ledger.',
                            ),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                        return;
                      }
                      state.removePerson(p.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Removed ${p.name}')),
                      );
                    },
                    icon: const Icon(Icons.person_remove_outlined),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Text(
            'A member with an open balance cannot be removed — that would '
            'silently destroy money in the ledger.',
            style: TextStyle(fontSize: 11.5, color: cs.outline),
          ),
        ],
      ),
    );
  }
}
