import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/dashboard_page.dart';

void main() {
  runApp(const ProviderScope(child: LoggevityApp()));
}

/// Seed for the Material 3 palette. Loggevity shares Roamfree's approach - a
/// single seed colour driving light and dark schemes - with its own hue.
const _seed = Color(0xFF3E8E7E);

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
