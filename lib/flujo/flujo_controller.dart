import 'package:flutter/foundation.dart';

import '../estados/estados_controller.dart';
import '../estados/estados_models.dart';
import '../estados/montos.dart';

enum Actividad {
  operacion('Actividades de operación'),
  inversion('Actividades de inversión'),
  financiamiento('Actividades de financiamiento');

  const Actividad(this.titulo);

  final String titulo;
}

enum Sentido { entrada, salida }

/// Una entrada o salida de efectivo. Los montos se escriben siempre positivos;
/// el sentido (entrada o salida) decide si suman o restan.
class LineaFlujo {
  LineaFlujo({
    required this.id,
    required this.concepto,
    required this.actividad,
    required this.sentido,
    this.monto = 0,
  });

  final String id;
  String concepto;
  final Actividad actividad;
  final Sentido sentido;
  double monto;
}

/// Datos y cálculos del flujo de efectivo (método directo).
class FlujoController extends ChangeNotifier {
  FlujoController() {
    _cargarBase();
  }

  final List<LineaFlujo> _lineas = [];
  int _seq = 0;

  /// Última línea agregada (para enfocar su campo de nombre).
  String? ultimoAgregadoId;

  bool _saldoDesdeEstados = false;
  double _saldoInicialManual = 0;

  // ------------------------------------------------------------ saldo inicial

  bool get saldoDesdeEstados => _saldoDesdeEstados;

  void setSaldoDesdeEstados(bool v) {
    _saldoDesdeEstados = v;
    notifyListeners();
  }

  double get saldoInicialManual => _saldoInicialManual;

  void setSaldoInicialManual(double v) {
    _saldoInicialManual = v;
    notifyListeners();
  }

  // ------------------------------------------------------------------ líneas

  List<LineaFlujo> lineas(Actividad a, Sentido s) =>
      _lineas.where((l) => l.actividad == a && l.sentido == s).toList();

  String _nuevoId() => 'f${_seq++}';

  LineaFlujo agregar(Actividad a, Sentido s) {
    final l = LineaFlujo(id: _nuevoId(), concepto: '', actividad: a, sentido: s);
    _lineas.add(l);
    ultimoAgregadoId = l.id;
    notifyListeners();
    return l;
  }

  void eliminar(String id) {
    _lineas.removeWhere((l) => l.id == id);
    notifyListeners();
  }

  /// Se llama después de modificar el concepto o el monto de una línea.
  void notificarCambio() => notifyListeners();

  void _cargarBase() {
    void add(Actividad a, Sentido s, String concepto) => _lineas.add(
        LineaFlujo(id: _nuevoId(), concepto: concepto, actividad: a, sentido: s));

    add(Actividad.operacion, Sentido.entrada, 'Cobros a clientes');
    add(Actividad.operacion, Sentido.entrada, 'Otros cobros de operación');
    add(Actividad.operacion, Sentido.salida, 'Pagos a proveedores');
    add(Actividad.operacion, Sentido.salida, 'Pagos de gastos de operación');
    add(Actividad.operacion, Sentido.salida, 'Pago de impuestos');
    add(Actividad.inversion, Sentido.entrada, 'Venta de activos fijos');
    add(Actividad.inversion, Sentido.salida, 'Compra de activos fijos');
    add(Actividad.financiamiento, Sentido.entrada, 'Préstamos recibidos');
    add(Actividad.financiamiento, Sentido.entrada, 'Aportes de capital');
    add(Actividad.financiamiento, Sentido.salida, 'Pago de préstamos');
    add(Actividad.financiamiento, Sentido.salida, 'Pago de intereses');
    add(Actividad.financiamiento, Sentido.salida, 'Pago de dividendos');
  }

  // ---------------------------------------------------------------- cálculos

  double _suma(Actividad a, Sentido s) => _lineas
      .where((l) => l.actividad == a && l.sentido == s)
      .fold(0.0, (suma, l) => suma + l.monto);

  double totalEntradas(Actividad a) => _suma(a, Sentido.entrada);

  double totalSalidas(Actividad a) => _suma(a, Sentido.salida);

  /// Flujo neto de la actividad = Entradas − Salidas
  double flujoNeto(Actividad a) => totalEntradas(a) - totalSalidas(a);

  /// Variación neta de efectivo = Operación + Inversión + Financiamiento
  double get variacionNeta =>
      Actividad.values.fold(0.0, (suma, a) => suma + flujoNeto(a));

  bool get hayMovimientos => _lineas.any((l) => l.monto != 0);

  // ---------------------------------------------- conexión con los estados

  static bool _esEfectivo(String nombre) {
    var n = nombre.toLowerCase();
    const conTilde = 'áéíóúñ';
    const sinTilde = 'aeioun';
    for (var i = 0; i < conTilde.length; i++) {
      n = n.replaceAll(conTilde[i], sinTilde[i]);
    }
    return n.contains('efectivo') || n.contains('caja') || n.contains('banco');
  }

  /// ¿El balance tiene alguna cuenta de efectivo (efectivo, caja o bancos)?
  bool hayCuentasDeEfectivo(EstadosController e) => e
      .deGrupo(Grupo.activoCorriente)
      .any((c) => _esEfectivo(c.nombre));

  /// Efectivo al cierre del período según el balance.
  double efectivoEnBalance(EstadosController e, Periodo p) => e
      .deGrupo(Grupo.activoCorriente)
      .where((c) => _esEfectivo(c.nombre))
      .fold(0.0, (suma, c) => suma + c.valor(p));

  /// Saldo inicial: el efectivo del balance del período anterior, o el escrito a mano.
  double saldoInicial(EstadosController e) => _saldoDesdeEstados
      ? efectivoEnBalance(e, Periodo.anterior)
      : _saldoInicialManual;

  /// Saldo final = Saldo inicial + Variación neta de efectivo
  double saldoFinal(EstadosController e) => saldoInicial(e) + variacionNeta;

  // ------------------------------------------------------------ resumen para IA

  static String _cs(double v) => 'C\$ ${formatoMonto(v)}';

  /// Texto con las cifras del flujo de efectivo para que la IA las interprete.
  String resumenParaIa(EstadosController e) {
    final b = StringBuffer()
      ..writeln(
          'Moneda: córdobas (C\$). Flujo de efectivo del período ${e.etiqueta(Periodo.actual)}, método directo.');

    for (final a in Actividad.values) {
      b.writeln('\n${a.titulo}:');
      for (final s in Sentido.values) {
        for (final l in lineas(a, s)) {
          if (l.monto == 0) continue;
          final nombre = l.concepto.trim().isEmpty ? '(sin nombre)' : l.concepto.trim();
          b.writeln(
              '- ${s == Sentido.entrada ? 'Entrada' : 'Salida'} · $nombre: ${_cs(l.monto)}');
        }
      }
      b.writeln('- Total entradas: ${_cs(totalEntradas(a))}');
      b.writeln('- Total salidas: ${_cs(totalSalidas(a))}');
      b.writeln('- Flujo neto: ${_cs(flujoNeto(a))}');
    }

    b
      ..writeln('\nResumen:')
      ..writeln('- Variación neta de efectivo: ${_cs(variacionNeta)}')
      ..writeln(
          '- Saldo inicial de efectivo: ${_cs(saldoInicial(e))}${_saldoDesdeEstados ? ' (tomado del balance)' : ''}')
      ..writeln('- Saldo final de efectivo: ${_cs(saldoFinal(e))}');

    if (hayCuentasDeEfectivo(e) && e.hayDatos(Periodo.actual, Estado.balance)) {
      final balance = efectivoEnBalance(e, Periodo.actual);
      final dif = saldoFinal(e) - balance;
      b.writeln(
          '- Efectivo según el balance del período actual: ${_cs(balance)} (diferencia con el saldo final calculado: ${_cs(dif)})');
    }
    return b.toString();
  }
}
