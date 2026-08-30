import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'core/store.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store();
  await store.init();
  final state = AppState(store);
  await state.load();
  runApp(
    ChangeNotifierProvider.value(value: state, child: const QuickSplitApp()),
  );
}

/// Google-blue seeded Material 3 colour scheme. One seed colour generates a
/// tonal palette that is contrast-checked in both light and dark by the
/// framework itself — no hand-picked hex values scattered through the UI.
const seed = Color(0xFF4285F4);

class QuickSplitApp extends StatelessWidget {
  const QuickSplitApp({super.key});

  ThemeData _theme(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b);
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDark;
    return MaterialApp(
      title: 'Campus QuickSplit',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: const HomeShell(),
    );
  }
}
