import '../estados/estados_controller.dart';
import '../estados/estados_models.dart';
import '../estados/montos.dart';

/// Qué parte del análisis se quiere interpretar (usado por la IA).
enum Alcance {
  horizontal('Análisis horizontal'),
  vertical('Análisis vertical'),
  razones('Razones financieras'),
  dupont('Sistema DuPont'),
  completo('Análisis completo');

  const Alcance(this.titulo);
  final String titulo;
}

/// Una fila de las tablas horizontal / vertical.
class FilaAnalisis {
  const FilaAnalisis(this.nombre, this.anterior, this.actual,
      {this.total = false});

  final String nombre;
  final double anterior;
  final double actual;

  /// Subtotales y totales se muestran en negrita.
  final bool total;

  double get variacion => actual - anterior;

  /// Variación relativa en %. Null si el período anterior es 0.
  double? get variacionPct =>
      anterior == 0 ? null : variacion / anterior.abs() * 100;
}

/// Una razón financiera calculada en ambos períodos.
class Razon {
  const Razon(this.nombre, this.unidad, this.anterior, this.actual);

  final String nombre;
  final String unidad;
  final double? anterior;
  final double? actual;

  double? valor(Periodo p) => p == Periodo.anterior ? anterior : actual;
}

/// Componentes del sistema DuPont para un período.
class DuPontPeriodo {
  const DuPontPeriodo(this.margenNeto, this.rotacion, this.multiplicador);

  /// Margen neto en fracción (0.12 = 12 %).
  final double? margenNeto;
  final double? rotacion;
  final double? multiplicador;

  /// ROE en fracción = margen × rotación × multiplicador.
  double? get roe => (margenNeto == null ||
          rotacion == null ||
          multiplicador == null)
      ? null
      : margenNeto! * rotacion! * multiplicador!;
}

/// Todos los cálculos del módulo Análisis financiero.
/// Lee los datos del [EstadosController]; no guarda estado propio.
class AnalisisFinanciero {
  AnalisisFinanciero(this.c);

  final EstadosController c;

  static const _dias = 365.0;

  // ----------------------------------------------------------------- utilidades

  static double? _div(double a, double b) => b == 0 ? null : a / b;

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  /// Suma las cuentas del grupo cuyo nombre contenga alguna de las claves.
  /// Devuelve null si ninguna cuenta coincide (p. ej. el usuario no tiene
  /// una cuenta de inventarios), para mostrar "—" en vez de un cero falso.
  double? _porNombre(Grupo g, Periodo p, List<String> claves) {
    final coinciden = c.deGrupo(g).where((cu) {
      final n = _norm(cu.nombre);
      return claves.any(n.contains);
    }).toList();
    if (coinciden.isEmpty) return null;
    return coinciden.fold<double>(0.0, (s, cu) => s + cu.valor(p));
  }

  double? _inventarios(Periodo p) =>
      _porNombre(Grupo.activoCorriente, p, ['inventari']);

  double? _porCobrar(Periodo p) =>
      _porNombre(Grupo.activoCorriente, p, ['cobrar', 'cliente']);

  double? _porPagar(Periodo p) =>
      _porNombre(Grupo.pasivoCorriente, p, ['pagar', 'proveedor']);

  double _costoVentas(Periodo p) => c.totalGrupo(Grupo.costoVentas, p);

  /// ¿Hay algún dato cargado en cualquiera de los dos estados?
  bool get hayDatos =>
      c.hayDatos(Periodo.anterior, Estado.balance) ||
      c.hayDatos(Periodo.actual, Estado.balance) ||
      c.hayDatos(Periodo.anterior, Estado.resultados) ||
      c.hayDatos(Periodo.actual, Estado.resultados);

  // ------------------------------------------------------------------- tablas

  FilaAnalisis _fila(String nombre, double Function(Periodo) f,
          {bool total = false}) =>
      FilaAnalisis(nombre, f(Periodo.anterior), f(Periodo.actual),
          total: total);

  List<FilaAnalisis> _cuentasDe(Grupo g) => [
        for (final cu in c.deGrupo(g))
          if (cu.nombre.trim().isNotEmpty || cu.anterior != 0 || cu.actual != 0)
            FilaAnalisis(
              cu.nombre.trim().isEmpty ? '(sin nombre)' : cu.nombre.trim(),
              cu.anterior,
              cu.actual,
            ),
      ];

  /// Balance General con cuentas, subtotales y totales.
  List<FilaAnalisis> filasBalance() => [
        ..._cuentasDe(Grupo.activoCorriente),
        _fila('Total activos corrientes', c.totalActivosCorrientes,
            total: true),
        ..._cuentasDe(Grupo.activoNoCorriente),
        _fila('Total activos no corrientes',
            (p) => c.totalGrupo(Grupo.activoNoCorriente, p),
            total: true),
        _fila('TOTAL ACTIVOS', c.totalActivos, total: true),
        ..._cuentasDe(Grupo.pasivoCorriente),
        _fila('Total pasivos corrientes', c.totalPasivosCorrientes,
            total: true),
        ..._cuentasDe(Grupo.pasivoNoCorriente),
        _fila('Total pasivos no corrientes',
            (p) => c.totalGrupo(Grupo.pasivoNoCorriente, p),
            total: true),
        _fila('TOTAL PASIVOS', c.totalPasivos, total: true),
        ..._cuentasDe(Grupo.patrimonio),
        _fila('TOTAL PATRIMONIO', c.totalPatrimonio, total: true),
        _fila('PASIVO + PATRIMONIO', c.pasivoMasPatrimonio, total: true),
      ];

  /// Estado de Resultados (totales por grupo y utilidades).
  List<FilaAnalisis> filasResultados() => [
        _fila('Ventas netas', c.ventasNetas, total: true),
        _fila('Costo de ventas', _costoVentas),
        _fila('Utilidad bruta', c.utilidadBruta, total: true),
        _fila('Gastos de operación',
            (p) => c.totalGrupo(Grupo.gastosOperacion, p)),
        _fila('Utilidad de operación', c.utilidadOperacion, total: true),
        _fila('Otros ingresos', (p) => c.totalGrupo(Grupo.otrosIngresos, p)),
        _fila('Otros gastos', (p) => c.totalGrupo(Grupo.otrosGastos, p)),
        _fila('UAII', c.uaii, total: true),
        _fila('Gastos financieros',
            (p) => c.totalGrupo(Grupo.gastosFinancieros, p)),
        _fila('Utilidad antes de impuestos', c.utilidadAntesImpuestos,
            total: true),
        _fila('Impuesto sobre la renta',
            (p) => c.totalGrupo(Grupo.impuestos, p)),
        _fila('UTILIDAD NETA', c.utilidadNeta, total: true),
      ];

  /// Porcentaje de [valor] sobre [base]. Null si la base es 0.
  static double? pctDe(double valor, double base) =>
      base == 0 ? null : valor / base * 100;

  // ------------------------------------------------------------------- razones

  Razon _razon(String nombre, String unidad, double? Function(Periodo) f) =>
      Razon(nombre, unidad, f(Periodo.anterior), f(Periodo.actual));

  List<Razon> liquidez() => [
        _razon('Razón corriente', 'veces',
            (p) => _div(c.totalActivosCorrientes(p), c.totalPasivosCorrientes(p))),
        _razon('Prueba ácida', 'veces', (p) {
          final inv = _inventarios(p) ?? 0;
          return _div(c.totalActivosCorrientes(p) - inv,
              c.totalPasivosCorrientes(p));
        }),
        _razon('Capital de trabajo neto', 'C\$',
            (p) => c.totalActivosCorrientes(p) - c.totalPasivosCorrientes(p)),
      ];

  List<Razon> actividad() => [
        _razon('Rotación de inventarios', 'veces', (p) {
          final inv = _inventarios(p);
          return inv == null ? null : _div(_costoVentas(p), inv);
        }),
        _razon('Período promedio de cobro', 'días', (p) {
          final cxc = _porCobrar(p);
          return cxc == null ? null : _div(cxc * _dias, c.ventasNetas(p));
        }),
        _razon('Período promedio de pago', 'días', (p) {
          final cxp = _porPagar(p);
          return cxp == null ? null : _div(cxp * _dias, _costoVentas(p));
        }),
        _razon('Rotación de activos totales', 'veces',
            (p) => _div(c.ventasNetas(p), c.totalActivos(p))),
      ];

  List<Razon> endeudamiento() => [
        _razon('Razón de deuda', '%', (p) {
          final r = _div(c.totalPasivos(p), c.totalActivos(p));
          return r == null ? null : r * 100;
        }),
        _razon('Deuda / Patrimonio', 'veces',
            (p) => _div(c.totalPasivos(p), c.totalPatrimonio(p))),
        _razon('Cobertura de intereses', 'veces',
            (p) => _div(c.uaii(p), c.totalGrupo(Grupo.gastosFinancieros, p))),
      ];

  List<Razon> rentabilidad() {
    double? pct(double a, double b) {
      final r = _div(a, b);
      return r == null ? null : r * 100;
    }

    return [
      _razon('Margen bruto', '%',
          (p) => pct(c.utilidadBruta(p), c.ventasNetas(p))),
      _razon('Margen operativo', '%',
          (p) => pct(c.uaii(p), c.ventasNetas(p))),
      _razon('Margen neto', '%',
          (p) => pct(c.utilidadNeta(p), c.ventasNetas(p))),
      _razon('ROA', '%', (p) => pct(c.utilidadNeta(p), c.totalActivos(p))),
      _razon('ROE', '%', (p) => pct(c.utilidadNeta(p), c.totalPatrimonio(p))),
    ];
  }

  /// UPA = utilidad neta del período actual / acciones en circulación.
  double? upa(double acciones) =>
      _div(c.utilidadNeta(Periodo.actual), acciones);

  // -------------------------------------------------------------------- DuPont

  DuPontPeriodo dupont(Periodo p) => DuPontPeriodo(
        _div(c.utilidadNeta(p), c.ventasNetas(p)),
        _div(c.ventasNetas(p), c.totalActivos(p)),
        _div(c.totalActivos(p), c.totalPatrimonio(p)),
      );

  // ------------------------------------------------------- lecturas sin IA

  /// Lectura breve basada en reglas simples; funciona sin conexión a la IA.
  String lecturaRazones() {
    final partes = <String>[];
    final rc = liquidez()[0].actual;
    if (rc != null) {
      partes.add(rc < 1
          ? 'Liquidez débil: la razón corriente (${rc.toStringAsFixed(2)}) indica que los activos corrientes no cubren los pasivos corrientes.'
          : rc < 2
              ? 'Liquidez aceptable: la razón corriente es ${rc.toStringAsFixed(2)}.'
              : 'Liquidez holgada: la razón corriente es ${rc.toStringAsFixed(2)}; verifica que no haya recursos ociosos.');
    }
    final rd = endeudamiento()[0].actual;
    if (rd != null) {
      partes.add(rd > 60
          ? 'Endeudamiento alto: ${rd.toStringAsFixed(1)} % de los activos está financiado con deuda.'
          : 'Endeudamiento moderado: ${rd.toStringAsFixed(1)} % de los activos está financiado con deuda.');
    }
    final mn = rentabilidad()[2].actual;
    final roe = rentabilidad()[4].actual;
    if (mn != null && roe != null) {
      partes.add(
          'Rentabilidad: margen neto de ${mn.toStringAsFixed(1)} % y ROE de ${roe.toStringAsFixed(1)} %.');
    }
    if (partes.isEmpty) {
      return 'Ingresa datos en Estados financieros para ver una lectura.';
    }
    return partes.join('\n');
  }

  String lecturaDupont() {
    final a = dupont(Periodo.anterior);
    final b = dupont(Periodo.actual);
    if (b.roe == null) {
      return 'Ingresa datos en Estados financieros para ver una lectura.';
    }
    final comp = <String, double?>{};
    double? cambio(double? x, double? y) =>
        (x == null || y == null || x == 0) ? null : (y - x) / x.abs();
    comp['el margen neto'] = cambio(a.margenNeto, b.margenNeto);
    comp['la rotación de activos'] = cambio(a.rotacion, b.rotacion);
    comp['el multiplicador de capital'] =
        cambio(a.multiplicador, b.multiplicador);
    final validos = comp.entries.where((e) => e.value != null).toList();
    if (validos.isEmpty) {
      return 'ROE actual: ${(b.roe! * 100).toStringAsFixed(1)} %. '
          'Falta el período anterior para comparar qué componente cambió.';
    }
    validos.sort((x, y) => y.value!.abs().compareTo(x.value!.abs()));
    final top = validos.first;
    final dir = top.value! >= 0 ? 'subió' : 'bajó';
    return 'ROE actual: ${(b.roe! * 100).toStringAsFixed(1)} %. '
        'El componente que más cambió fue ${top.key}, que $dir '
        '${(top.value!.abs() * 100).toStringAsFixed(1)} % respecto al período anterior.';
  }

  // ------------------------------------------------------- resumen para la IA

  static String _n(double? v, {int d = 2}) =>
      v == null ? 'n/d' : formatoMonto(v, decimales: d);

  /// Texto con las cifras del análisis, que se envía a la IA como contexto.
  String resumenParaIa(Alcance alcance) {
    final b = StringBuffer();
    final empresa = c.empresa.trim();
    b.writeln('Empresa: ${empresa.isEmpty ? '(sin nombre)' : empresa}');
    b.writeln('Moneda: córdobas (C\$)');
    b.writeln('Período anterior: ${c.etiqueta(Periodo.anterior)}');
    b.writeln('Período actual: ${c.etiqueta(Periodo.actual)}');
    b.writeln();

    final todo = alcance == Alcance.completo;

    if (todo || alcance == Alcance.horizontal) {
      b.writeln('== ANÁLISIS HORIZONTAL (cuenta | anterior | actual | variación C\$ | variación %) ==');
      for (final f in [...filasBalance(), ...filasResultados()]) {
        b.writeln('${f.nombre} | ${_n(f.anterior)} | ${_n(f.actual)} | '
            '${_n(f.variacion)} | ${_n(f.variacionPct, d: 1)}');
      }
      b.writeln();
    }

    if (todo || alcance == Alcance.vertical) {
      final baseA = c.totalActivos(Periodo.anterior);
      final baseB = c.totalActivos(Periodo.actual);
      b.writeln('== ANÁLISIS VERTICAL · BALANCE (% del total de activos: anterior | actual) ==');
      for (final f in filasBalance()) {
        b.writeln('${f.nombre} | ${_n(pctDe(f.anterior, baseA), d: 1)} | '
            '${_n(pctDe(f.actual, baseB), d: 1)}');
      }
      final vA = c.ventasNetas(Periodo.anterior);
      final vB = c.ventasNetas(Periodo.actual);
      b.writeln('== ANÁLISIS VERTICAL · RESULTADOS (% de ventas netas: anterior | actual) ==');
      for (final f in filasResultados()) {
        b.writeln('${f.nombre} | ${_n(pctDe(f.anterior, vA), d: 1)} | '
            '${_n(pctDe(f.actual, vB), d: 1)}');
      }
      b.writeln();
    }

    if (todo || alcance == Alcance.razones) {
      b.writeln('== RAZONES FINANCIERAS (razón | anterior | actual | unidad) ==');
      for (final r in [
        ...liquidez(),
        ...actividad(),
        ...endeudamiento(),
        ...rentabilidad()
      ]) {
        b.writeln(
            '${r.nombre} | ${_n(r.anterior)} | ${_n(r.actual)} | ${r.unidad}');
      }
      b.writeln();
    }

    if (todo || alcance == Alcance.dupont) {
      final a = dupont(Periodo.anterior);
      final d = dupont(Periodo.actual);
      String pc(double? v) => v == null ? 'n/d' : (v * 100).toStringAsFixed(2);
      String x(double? v) => v == null ? 'n/d' : v.toStringAsFixed(2);
      b.writeln('== DUPONT (ROE = margen neto × rotación de activos × multiplicador de capital) ==');
      b.writeln('Margen neto % | ${pc(a.margenNeto)} | ${pc(d.margenNeto)}');
      b.writeln('Rotación de activos (veces) | ${x(a.rotacion)} | ${x(d.rotacion)}');
      b.writeln('Multiplicador de capital (veces) | ${x(a.multiplicador)} | ${x(d.multiplicador)}');
      b.writeln('ROE % | ${pc(a.roe)} | ${pc(d.roe)}');
    }

    return b.toString();
  }
}
