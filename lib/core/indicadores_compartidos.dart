import 'package:flutter/foundation.dart';

/// Resultados de módulos que otras pantallas (por ejemplo el panel principal)
/// necesitan leer. Cada módulo publica aquí su último resultado.
class IndicadoresCompartidos extends ChangeNotifier {
  double? _puntoEquilibrioUnidades;
  double? _gat;

  /// Punto de equilibrio en unidades (módulo C-V-U).
  double? get puntoEquilibrioUnidades => _puntoEquilibrioUnidades;

  /// Grado de apalancamiento total (módulo Apalancamiento).
  double? get gat => _gat;

  void publicarPuntoEquilibrio(double? v) {
    if (v == _puntoEquilibrioUnidades) return;
    _puntoEquilibrioUnidades = v;
    notifyListeners();
  }

  void publicarGat(double? v) {
    if (v == _gat) return;
    _gat = v;
    notifyListeners();
  }
}
