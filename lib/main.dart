import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/dashboard_page.dart';

void main() {
  runApp(const ProviderScope(child: LoggevityApp()));
}

/// Seed for the Material 3 palette.
///
/// Loggevity follows Roamfree's structure - one seed driving both schemes,
/// with nothing else overridden, so every surface including the scaffold
/// background is derived the same way - but uses its own hue. Setting any
/// colour by hand here would break that derivation.
const _seed = Color(0xFFC067FF);

class LoggevityApp extends StatelessWidget {
  const LoggevityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loggevity',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DashboardPage(),
    );
  }
}
