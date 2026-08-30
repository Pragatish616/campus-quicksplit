import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import 'activity_screen.dart';
import 'add_expense_screen.dart';
import 'dashboard_screen.dart';
import 'insights_screen.dart';
import 'settle_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['QuickSplit', 'Activity', 'Settle up', 'Insights'];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index],
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            onPressed: () => context.read<AppState>().toggleTheme(),
            icon: Icon(state.isDark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, .02), end: Offset.zero)
                .animate(anim),
            child: child,
          ),
        ),
        child: switch (_index) {
          0 => const DashboardScreen(key: ValueKey(0)),
          1 => const ActivityScreen(key: ValueKey(1)),
          2 => const SettleScreen(key: ValueKey(2)),
          _ => const InsightsScreen(key: ValueKey(3)),
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add expense'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Activity'),
          NavigationDestination(
              icon: Icon(Icons.handshake_outlined),
              selectedIcon: Icon(Icons.handshake_rounded),
              label: 'Settle'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Insights'),
        ],
      ),
    );
  }
}
