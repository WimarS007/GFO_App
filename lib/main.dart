import 'package:flutter/material.dart';

import 'core/tema.dart';
import 'screens/shell.dart';

void main() => runApp(const GfoApp());

class GfoApp extends StatelessWidget {
  const GfoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: modoTema,
      builder: (context, modo, _) => MaterialApp(
        title: 'GFO App',
        debugShowCheckedModeBanner: false,
        theme: temaClaro(),
        darkTheme: temaOscuro(),
        themeMode: modo,
        home: const AppShell(),
      ),
    );
  }
}
