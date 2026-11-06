import 'package:flutter/foundation.dart';

import '../core/indicadores_compartidos.dart';
import '../estados/estados_controller.dart';
import '../estados/estados_models.dart';
import '../estados/montos.dart';

const List<String> trimestres = ['T1', 'T2', 'T3', 'T4'];

/// Supuestos que se escriben como un solo valor.
enum Campo {
  pctVentasContado,
  pctComprasContado,
  pctInventarioFinal,
  costoUnitario,
  unidadesSiguiente,
  cajaMinima,
  cajaInicial,
  cxcInicial,
  cxpInicial,
  inventarioInicial,
}

double suma(List<double> l) => l.fold(0.0, (a, b) => a + b);

List<double> _ceros() => List<double>.filled(4, 0.0);

/// Un gasto de operación con su monto en cada trimestre.
class LineaGasto {
  LineaGasto({required this.id, required this.concepto, this.afectaCaja = true})
      : montos = _ceros();

  final String id;
  String concepto;
  final List<double> montos;

  /// false para gastos sin desembolso de efectivo (depreciación, amortización).
  bool afectaCaja;
}

/// Resultado de todos los presupuestos (un valor por trimestre).
class ResultadoPresupuesto {
  // Ventas
  final List<double> unidades = _ceros();
  final List<double> precios = _ceros();
  final List<double> ventas = _ceros();
  final List<double> ventasContado = _ceros();
  final List<double> ventasCredito = _ceros();
  // Compras
  final List<double> invFinalDeseado = _ceros();
  final List<double> invInicialUnid = _ceros();
  final List<double> comprasUnid = _ceros();
  final List<double> invFinalUnid = _ceros();
  final List<double> comprasMonto = _ceros();
  final List<double> comprasContado = _ceros();
  final List<double> comprasCredito = _ceros();
  // Costo de bienes vendidos
  final List<double> invInicialMonto = _ceros();
  final List<double> invFinalMonto = _ceros();
  final List<double> cbv = _ceros();
  // Gastos de operación
  final List<double> gastosTotales = _ceros();
  final List<double> gastosEfectivo = _ceros();
  final List<double> gastosSinEfectivo = _ceros();
  // Resultado operativo
  final List<double> utilidadBruta = _ceros();
  final List<double> utilidadOperativa = _ceros();
  // Caja
  final List<double> cajaInicial = _ceros();
  final List<double> cobros = _ceros();
  final List<double> pagosCompras = _ceros();
  final List<double> otros = _ceros();
  final List<double> saldoAntes = _ceros();
  final List<double> financiamiento = _ceros();
  final List<double> saldoFinal = _ceros();
}

/// Datos y cálculos de planeación y presupuestos (por trimestre).
///
/// Política asumida: las ventas y compras a crédito se cobran / pagan en el
/// trimestre siguiente; las cuentas por cobrar y por pagar iniciales se
/// cobran / pagan en T1.
class PresupuestosController extends ChangeNotifier {
  PresupuestosController({required this.estados, required this.indicadores}) {
    _cargarGastosBase();
    estados.addListener(_publicar);
  }

  final EstadosController estados;
  final IndicadoresCompartidos indicadores;

  final List<double> unidades = _ceros();
  final List<double> precios = _ceros();
  final List<double> otrosDesembolsos = _ceros();
  final List<LineaGasto> gastos = [];
  final Map<Campo, double> _valores = {};

  bool _usarBalance = false;
  int _seq = 0;

  /// Última línea de gasto agregada (para enfocar su nombre).
  String? ultimoGastoId;

  @override
  void notifyListeners() {
    super.notifyListeners();
    _publicar();
  }

  @override
  void dispose() {
    estados.removeListener(_publicar);
    super.dispose();
  }

  /// Publica el saldo final de efectivo (T4) para el panel principal.
  void _publicar() {
    indicadores.publicarSaldoEfectivo(hayDatos ? calcular().saldoFinal[3] : null);
  }

  // ----------------------------------------------------------------- datos

  bool get hayDatos => unidades.any((u) => u > 0);

  double valor(Campo c) => _valores[c] ?? 0;

  void setValor(Campo c, double v) {
    _valores[c] = v;
    notifyListeners();
  }

  bool get usarBalance => _usarBalance;

  void setUsarBalance(bool v) {
    _usarBalance = v;
    notifyListeners();
  }

  /// Se llama después de modificar listas (unidades, precios, gastos...).
  void notificarCambio() => notifyListeners();

  double get costoUnitario => valor(Campo.costoUnitario);

  // ---------------------------------------------- saldos iniciales / balance

  static String _norm(String s) {
    const conTilde = 'áàäâéèëêíìïîóòöôúùüûñ';
    const sinTilde = 'aaaaeeeeiiiioooouuuun';
    var r = s.toLowerCase();
    for (var i = 0; i < conTilde.length; i++) {
      r = r.replaceAll(conTilde[i], sinTilde[i]);
    }
    return r;
  }

  double _delBalance(Grupo g, List<String> palabras) {
    var total = 0.0;
    for (final c in estados.deGrupo(g)) {
      final n = _norm(c.nombre);
      if (palabras.any((w) => n.contains(w))) total += c.valor(Periodo.actual);
    }
    return total;
  }

  double get efectivoBalance =>
      _delBalance(Grupo.activoCorriente, ['efectivo', 'caja', 'banco']);

  double get cxcBalance => _delBalance(Grupo.activoCorriente,
      ['cuentas por cobrar', 'clientes', 'documentos por cobrar']);

  double get cxpBalance => _delBalance(Grupo.pasivoCorriente,
      ['cuentas por pagar', 'proveedor', 'acreedores comerciales']);

  double get inventarioBalance => _delBalance(
      Grupo.activoCorriente, ['inventario', 'mercader', 'existencia']);

  /// Saldos iniciales: del balance del período actual o escritos a mano.
  double get cajaInicial =>
      _usarBalance ? efectivoBalance : valor(Campo.cajaInicial);

  double get cxcInicial => _usarBalance ? cxcBalance : valor(Campo.cxcInicial);

  double get cxpInicial => _usarBalance ? cxpBalance : valor(Campo.cxpInicial);

  /// Con el balance: Inventarios (C$) / Costo unitario.
  double get inventarioInicialUnidades => _usarBalance
      ? (costoUnitario > 0 ? inventarioBalance / costoUnitario : 0)
      : valor(Campo.inventarioInicial);

  // ------------------------------------------------------ gastos de operación

  String _nuevoId() => 'g${_seq++}';

  void _cargarGastosBase() {
    void add(String nombre, {bool caja = true}) =>
        gastos.add(LineaGasto(id: _nuevoId(), concepto: nombre, afectaCaja: caja));
    add('Gastos de administración');
    add('Gastos de ventas');
    add('Depreciación', caja: false);
    add('Otros gastos');
  }

  LineaGasto agregarGasto() {
    final l = LineaGasto(id: _nuevoId(), concepto: '');
    gastos.add(l);
    ultimoGastoId = l.id;
    notifyListeners();
    return l;
  }

  void eliminarGasto(String id) {
    gastos.removeWhere((g) => g.id == id);
    notifyListeners();
  }

  bool get hayGastosEnEstados =>
      estados.deGrupo(Grupo.gastosOperacion).any((c) => c.actual != 0);

  bool get hayGastosCapturados =>
      gastos.any((g) => g.montos.any((m) => m != 0));

  /// Reemplaza los gastos por las cuentas de "Gastos de operación" de los
  /// estados (período actual), repartidas en partes iguales en los 4 trimestres.
  void cargarGastosDeEstados() {
    gastos.clear();
    for (final c in estados.deGrupo(Grupo.gastosOperacion)) {
      final n = _norm(c.nombre);
      final l = LineaGasto(
        id: _nuevoId(),
        concepto: c.nombre,
        afectaCaja: !(n.contains('depreciacion') || n.contains('amortizacion')),
      );
      for (var t = 0; t < 4; t++) {
        l.montos[t] = c.actual / 4;
      }
      gastos.add(l);
    }
    ultimoGastoId = null;
    notifyListeners();
  }

  // ----------------------------------------------------------------- avisos

  List<String> get avisos {
    final a = <String>[];
    if (!hayDatos) {
      a.add(
          'Ingresa en «Supuestos» las unidades a vender de cada trimestre para calcular los presupuestos.');
      return a;
    }
    for (var t = 0; t < 4; t++) {
      if (unidades[t] > 0 && precios[t] <= 0) {
        a.add('Falta el precio de venta unitario de ${trimestres[t]}.');
      }
    }
    if (costoUnitario <= 0) {
      a.add('Ingresa el costo unitario de compra para calcular compras y costo de bienes vendidos.');
    }
    for (final c in [Campo.pctVentasContado, Campo.pctComprasContado]) {
      if (valor(c) < 0 || valor(c) > 100) {
        a.add('Los porcentajes de contado deben estar entre 0 y 100.');
        break;
      }
    }
    if (_usarBalance && !estados.hayDatos(Periodo.actual, Estado.balance)) {
      a.add(
          'El balance de ${estados.etiqueta(Periodo.actual)} está vacío: los saldos iniciales salen en cero.');
    }
    return a;
  }

  // --------------------------------------------------------------- cálculos

  static double _fraccion(double pct) =>
      (pct < 0 ? 0.0 : (pct > 100 ? 100.0 : pct)) / 100;

  ResultadoPresupuesto calcular() {
    final r = ResultadoPresupuesto();

    final pV = _fraccion(valor(Campo.pctVentasContado));
    final pC = _fraccion(valor(Campo.pctComprasContado));
    final pInv = valor(Campo.pctInventarioFinal) < 0
        ? 0.0
        : valor(Campo.pctInventarioFinal) / 100;
    final costo = costoUnitario;
    final minimo = valor(Campo.cajaMinima);

    var invPrevio = inventarioInicialUnidades;
    var saldoPrevio = cajaInicial;

    for (var t = 0; t < 4; t++) {
      // Ventas
      r.unidades[t] = unidades[t];
      r.precios[t] = precios[t];
      r.ventas[t] = unidades[t] * precios[t];
      r.ventasContado[t] = r.ventas[t] * pV;
      r.ventasCredito[t] = r.ventas[t] - r.ventasContado[t];
      r.cobros[t] = r.ventasContado[t] + (t == 0 ? cxcInicial : r.ventasCredito[t - 1]);

      // Compras (en unidades) con inventario final deseado
      final siguiente = t < 3
          ? unidades[t + 1]
          : (valor(Campo.unidadesSiguiente) > 0
              ? valor(Campo.unidadesSiguiente)
              : unidades[3]);
      r.invFinalDeseado[t] = pInv * siguiente;
      r.invInicialUnid[t] = invPrevio;
      final necesarias = unidades[t] + r.invFinalDeseado[t] - r.invInicialUnid[t];
      r.comprasUnid[t] = necesarias > 0 ? necesarias : 0;
      r.invFinalUnid[t] = r.invInicialUnid[t] + r.comprasUnid[t] - unidades[t];
      invPrevio = r.invFinalUnid[t];

      r.comprasMonto[t] = r.comprasUnid[t] * costo;
      r.comprasContado[t] = r.comprasMonto[t] * pC;
      r.comprasCredito[t] = r.comprasMonto[t] - r.comprasContado[t];
      r.pagosCompras[t] =
          r.comprasContado[t] + (t == 0 ? cxpInicial : r.comprasCredito[t - 1]);

      // Costo de bienes vendidos
      r.invInicialMonto[t] = r.invInicialUnid[t] * costo;
      r.invFinalMonto[t] = r.invFinalUnid[t] * costo;
      r.cbv[t] = r.invInicialMonto[t] + r.comprasMonto[t] - r.invFinalMonto[t];

      // Gastos de operación
      for (final g in gastos) {
        r.gastosTotales[t] += g.montos[t];
        if (g.afectaCaja) {
          r.gastosEfectivo[t] += g.montos[t];
        } else {
          r.gastosSinEfectivo[t] += g.montos[t];
        }
      }

      // Resultado operativo
      r.utilidadBruta[t] = r.ventas[t] - r.cbv[t];
      r.utilidadOperativa[t] = r.utilidadBruta[t] - r.gastosTotales[t];

      // Caja
      r.cajaInicial[t] = saldoPrevio;
      r.otros[t] = otrosDesembolsos[t];
      r.saldoAntes[t] = saldoPrevio +
          r.cobros[t] -
          r.pagosCompras[t] -
          r.gastosEfectivo[t] -
          r.otros[t];
      r.financiamiento[t] = r.saldoAntes[t] < minimo ? minimo - r.saldoAntes[t] : 0;
      r.saldoFinal[t] = r.saldoAntes[t] + r.financiamiento[t];
      saldoPrevio = r.saldoFinal[t];
    }
    return r;
  }

  // ------------------------------------------------------------ resumen para IA

  static String _cs(double v) => 'C\$ ${formatoMonto(v)}';

  static String _fila(String nombre, List<double> v) {
    final partes = [
      for (var t = 0; t < 4; t++) '${trimestres[t]} = ${_cs(v[t])}',
    ];
    return '- $nombre: ${partes.join('; ')}';
  }

  /// Texto con los presupuestos para que la IA los interprete.
  String resumenParaIa() {
    final r = calcular();
    final origen = _usarBalance
        ? 'tomados del balance de ${estados.etiqueta(Periodo.actual)}'
        : 'escritos a mano';
    final b = StringBuffer()
      ..writeln('Moneda: córdobas (C\$). Presupuesto por trimestres (T1 a T4).')
      ..writeln('\nSupuestos:')
      ..writeln(
          '- Ventas al contado: ${valor(Campo.pctVentasContado).toStringAsFixed(1)}%; el resto se cobra el trimestre siguiente.')
      ..writeln(
          '- Compras al contado: ${valor(Campo.pctComprasContado).toStringAsFixed(1)}%; el resto se paga el trimestre siguiente.')
      ..writeln(
          '- Inventario final deseado: ${valor(Campo.pctInventarioFinal).toStringAsFixed(1)}% de las unidades que se venderán el trimestre siguiente.')
      ..writeln('- Costo unitario de compra: ${_cs(costoUnitario)}')
      ..writeln('- Saldo mínimo de caja: ${_cs(valor(Campo.cajaMinima))}')
      ..writeln(
          '- Saldos iniciales ($origen): caja ${_cs(cajaInicial)}, cuentas por cobrar ${_cs(cxcInicial)}, cuentas por pagar ${_cs(cxpInicial)}, inventario inicial ${formatoMonto(inventarioInicialUnidades)} unidades.')
      ..writeln('\nResultados por trimestre:')
      ..writeln(_fila('Ventas', r.ventas))
      ..writeln(_fila('Compras', r.comprasMonto))
      ..writeln(_fila('Costo de bienes vendidos', r.cbv))
      ..writeln(_fila('Gastos de operación', r.gastosTotales))
      ..writeln(_fila('Utilidad operativa', r.utilidadOperativa))
      ..writeln(_fila('Cobros de ventas', r.cobros))
      ..writeln(_fila('Pagos de compras', r.pagosCompras))
      ..writeln(_fila('Saldo antes de financiamiento', r.saldoAntes))
      ..writeln(_fila('Financiamiento requerido', r.financiamiento))
      ..writeln(_fila('Saldo final de efectivo', r.saldoFinal))
      ..writeln('\nTotales del año:')
      ..writeln('- Ventas: ${_cs(suma(r.ventas))}')
      ..writeln('- Utilidad operativa: ${_cs(suma(r.utilidadOperativa))}')
      ..writeln('- Financiamiento total requerido: ${_cs(suma(r.financiamiento))}')
      ..writeln('- Saldo final de efectivo (T4): ${_cs(r.saldoFinal[3])}');
    return b.toString();
  }
}
