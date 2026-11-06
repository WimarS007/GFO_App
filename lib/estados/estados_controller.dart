import 'package:flutter/foundation.dart';

import 'estados_models.dart';
import 'excel_importer.dart';

/// Datos y cálculos de los estados financieros.
/// Todos los montos de costos y gastos se ingresan como valores positivos.
class EstadosController extends ChangeNotifier {
  EstadosController() {
    _cargarCuentasBase();
  }

  String empresa = '';
  String _periodoAnterior = '';
  String _periodoActual = '';
  final List<Cuenta> _cuentas = [];
  int _seq = 0;

  /// Última cuenta agregada (para enfocar su campo de nombre).
  String? ultimoAgregadoId;

  // ---------------------------------------------------------------- períodos

  String periodoTexto(Periodo p) =>
      p == Periodo.anterior ? _periodoAnterior : _periodoActual;

  /// Etiqueta para mostrar en encabezados.
  String etiqueta(Periodo p) {
    final t = periodoTexto(p).trim();
    if (t.isNotEmpty) return t;
    return p == Periodo.anterior ? 'Período anterior' : 'Período actual';
  }

  void setPeriodo(Periodo p, String texto) {
    if (p == Periodo.anterior) {
      _periodoAnterior = texto;
    } else {
      _periodoActual = texto;
    }
    notifyListeners();
  }

  // ----------------------------------------------------------------- cuentas

  List<Cuenta> deGrupo(Grupo g) =>
      _cuentas.where((c) => c.grupo == g).toList();

  String _nuevoId() => 'c${_seq++}';

  Cuenta agregar(Grupo g) {
    final c = Cuenta(id: _nuevoId(), nombre: '', grupo: g);
    _cuentas.add(c);
    ultimoAgregadoId = c.id;
    notifyListeners();
    return c;
  }

  void eliminar(String id) {
    _cuentas.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  void mover(String id, Grupo destino) {
    for (final c in _cuentas) {
      if (c.id == id) c.grupo = destino;
    }
    notifyListeners();
  }

  /// Se llama después de modificar el nombre o un valor de una cuenta.
  void notificarCambio() => notifyListeners();

  bool hayDatos(Periodo p, Estado e) =>
      _cuentas.any((c) => c.grupo.estado == e && c.valor(p) != 0);

  void _cargarCuentasBase() {
    void add(Grupo g, String nombre) =>
        _cuentas.add(Cuenta(id: _nuevoId(), nombre: nombre, grupo: g));

    add(Grupo.activoCorriente, 'Efectivo y equivalentes');
    add(Grupo.activoCorriente, 'Cuentas por cobrar');
    add(Grupo.activoCorriente, 'Inventarios');
    add(Grupo.activoCorriente, 'Otros activos corrientes');
    add(Grupo.activoNoCorriente, 'Propiedad, planta y equipo (neto)');
    add(Grupo.activoNoCorriente, 'Otros activos no corrientes');
    add(Grupo.pasivoCorriente, 'Cuentas por pagar');
    add(Grupo.pasivoCorriente, 'Préstamos a corto plazo');
    add(Grupo.pasivoCorriente, 'Otros pasivos corrientes');
    add(Grupo.pasivoNoCorriente, 'Préstamos a largo plazo');
    add(Grupo.patrimonio, 'Capital social');
    add(Grupo.patrimonio, 'Utilidades retenidas');

    add(Grupo.ventas, 'Ventas netas');
    add(Grupo.costoVentas, 'Costo de ventas');
    add(Grupo.gastosOperacion, 'Gastos de administración');
    add(Grupo.gastosOperacion, 'Gastos de ventas');
    add(Grupo.otrosIngresos, 'Otros ingresos');
    add(Grupo.otrosGastos, 'Otros gastos');
    add(Grupo.gastosFinancieros, 'Gastos por intereses');
    add(Grupo.impuestos, 'Impuesto sobre la renta');
  }

  // ------------------------------------------------------------- importación

  /// Reemplaza las cuentas de los estados que vienen en el archivo.
  /// Si el archivo solo trae el balance, el estado de resultados no se toca.
  void aplicarImportacion(ResultadoImportacion r) {
    for (final e in r.estados) {
      _cuentas.removeWhere((c) => c.grupo.estado == e);
    }
    for (final i in r.cuentas) {
      _cuentas.add(Cuenta(
        id: _nuevoId(),
        nombre: i.nombre,
        grupo: i.grupo,
        anterior: i.anterior,
        actual: i.actual,
      ));
    }
    if (r.periodoAnterior != null) _periodoAnterior = r.periodoAnterior!;
    if (r.periodoActual != null) _periodoActual = r.periodoActual!;
    ultimoAgregadoId = null;
    notifyListeners();
  }

  // ------------------------------------------------------- Balance General

  double totalGrupo(Grupo g, Periodo p) => _cuentas
      .where((c) => c.grupo == g)
      .fold(0.0, (suma, c) => suma + c.valor(p));

  double totalActivosCorrientes(Periodo p) =>
      totalGrupo(Grupo.activoCorriente, p);

  double totalActivos(Periodo p) =>
      totalGrupo(Grupo.activoCorriente, p) +
      totalGrupo(Grupo.activoNoCorriente, p);

  double totalPasivosCorrientes(Periodo p) =>
      totalGrupo(Grupo.pasivoCorriente, p);

  double totalPasivos(Periodo p) =>
      totalGrupo(Grupo.pasivoCorriente, p) +
      totalGrupo(Grupo.pasivoNoCorriente, p);

  double totalPatrimonio(Periodo p) => totalGrupo(Grupo.patrimonio, p);

  double pasivoMasPatrimonio(Periodo p) =>
      totalPasivos(p) + totalPatrimonio(p);

  /// Activo − (Pasivo + Patrimonio). Debe ser 0 si el balance cuadra.
  double diferenciaBalance(Periodo p) =>
      totalActivos(p) - pasivoMasPatrimonio(p);

  // ------------------------------------------------ Estado de Resultados

  double ventasNetas(Periodo p) => totalGrupo(Grupo.ventas, p);

  /// Utilidad bruta = Ventas netas − Costo de ventas
  double utilidadBruta(Periodo p) =>
      ventasNetas(p) - totalGrupo(Grupo.costoVentas, p);

  /// Utilidad de operación = Utilidad bruta − Gastos de operación
  double utilidadOperacion(Periodo p) =>
      utilidadBruta(p) - totalGrupo(Grupo.gastosOperacion, p);

  /// UAII = Utilidad de operación + Otros ingresos − Otros gastos
  double uaii(Periodo p) =>
      utilidadOperacion(p) +
      totalGrupo(Grupo.otrosIngresos, p) -
      totalGrupo(Grupo.otrosGastos, p);

  /// Utilidad antes de impuestos = UAII − Gastos financieros
  double utilidadAntesImpuestos(Periodo p) =>
      uaii(p) - totalGrupo(Grupo.gastosFinancieros, p);

  /// Utilidad neta = Utilidad antes de impuestos − Impuesto sobre la renta
  double utilidadNeta(Periodo p) =>
      utilidadAntesImpuestos(p) - totalGrupo(Grupo.impuestos, p);

  // ----------------------------------- costos fijos / variables (C-V-U)

  /// Costos de operación (costo de ventas + gastos de operación) según su comportamiento.
  double _costosOperacion(Periodo p, Comportamiento tipo) => _cuentas
      .where((c) =>
          (c.grupo == Grupo.costoVentas || c.grupo == Grupo.gastosOperacion) &&
          c.comportamiento == tipo)
      .fold(0.0, (suma, c) => suma + c.valor(p));

  double costosVariables(Periodo p) =>
      _costosOperacion(p, Comportamiento.variable);

  double costosFijos(Periodo p) => _costosOperacion(p, Comportamiento.fijo);

  /// Margen de contribución = Ventas netas − Costos variables
  double margenContribucion(Periodo p) => ventasNetas(p) - costosVariables(p);

  /// Costos fijos + Otros gastos − Otros ingresos.
  /// Así, Margen de contribución − este valor = UAII de los estados.
  double costosFijosParaUaii(Periodo p) =>
      costosFijos(p) +
      totalGrupo(Grupo.otrosGastos, p) -
      totalGrupo(Grupo.otrosIngresos, p);

  double gastosFinancieros(Periodo p) =>
      totalGrupo(Grupo.gastosFinancieros, p);
}
