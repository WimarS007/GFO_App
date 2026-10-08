import 'package:flutter/material.dart';

import 'screens/shell.dart';

void main() => runApp(const GfoApp());

class GfoApp extends StatelessWidget {
  const GfoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GFO App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00695C)),
      ),
      home: const AppShell(),
    );
  }
}
