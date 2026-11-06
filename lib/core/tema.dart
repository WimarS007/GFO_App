import 'package:flutter/material.dart';

/// Modo de tema de la app. Por defecto sigue al del sistema.
final ValueNotifier<ThemeMode> modoTema = ValueNotifier(ThemeMode.system);

const _semilla = Color(0xFF00695C);

ThemeData temaClaro() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _semilla),
    );

ThemeData temaOscuro() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _semilla,
        brightness: Brightness.dark,
      ),
    );

/// Botón que alterna entre modo claro y oscuro.
class BotonTema extends StatelessWidget {
  const BotonTema({super.key});

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: oscuro ? 'Modo claro' : 'Modo oscuro',
      icon: Icon(oscuro ? Icons.light_mode : Icons.dark_mode),
      onPressed: () =>
          modoTema.value = oscuro ? ThemeMode.light : ThemeMode.dark,
    );
  }
}
