import 'package:flutter/foundation.dart';

/// Resultados de módulos que otras pantallas (por ejemplo el panel principal)
/// necesitan leer. Cada módulo publica aquí su último resultado.
class IndicadoresCompartidos extends ChangeNotifier {
  double? _puntoEquilibrioUnidades;
  double? _gat;
  double? _saldoEfectivoProyectado;
  double? _saldoPersonal;

  /// Punto de equilibrio en unidades (módulo C-V-U).
  double? get puntoEquilibrioUnidades => _puntoEquilibrioUnidades;

  /// Grado de apalancamiento total (módulo Apalancamiento).
  double? get gat => _gat;

  /// Saldo final de efectivo del último trimestre (módulo Planeación y presupuestos).
  double? get saldoEfectivoProyectado => _saldoEfectivoProyectado;

  /// Saldo disponible del presupuesto personal.
  double? get saldoPersonal => _saldoPersonal;

  void publicarSaldoPersonal(double? v) {
    if (v == _saldoPersonal) return;
    _saldoPersonal = v;
    notifyListeners();
  }

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

  void publicarSaldoEfectivo(double? v) {
    if (v == _saldoEfectivoProyectado) return;
    _saldoEfectivoProyectado = v;
    notifyListeners();
  }
}
