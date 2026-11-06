import '../apalancamiento/apalancamiento_calculos.dart';
import '../estados/estados_controller.dart';
import '../estados/estados_models.dart';
import '../estados/montos.dart';

/// Supuestos de proyección. Todos los porcentajes se expresan como fracción
/// (0.10 = 10 %).
class SupuestosProforma {
  const SupuestosProforma({
    this.crecimientoVentas = 0,
    this.variacionCostos = 0,
    this.inversionAdicional = 0,
    this.pctDeuda = 0,
    this.tasaInteres = 0,
    this.tasaImpuesto,
    this.pctDividendos = 0,
    this.unidadesActuales,
  });

  /// Crecimiento de las ventas (volumen). Los costos variables y las cuentas
  /// operativas del balance crecen en la misma proporción.
  final double crecimientoVentas;

  /// Variación de precios de los costos y gastos (inflación de insumos, salarios...).
  /// Se aplica a todos los costos y gastos, fijos y variables.
  final double variacionCostos;

  /// Inversión adicional en activos no corrientes (C$).
  final double inversionAdicional;

  /// Parte de la inversión que se financia con deuda a largo plazo.
  final double pctDeuda;

  /// Tasa de interés anual de la deuda nueva.
  final double tasaInteres;

  /// Tasa de impuesto. Si es null se usa la tasa efectiva del período actual.
  final double? tasaImpuesto;

  /// Parte de la utilidad neta que se reparte como dividendos.
  final double pctDividendos;

  /// Unidades vendidas en el período actual (opcional): permite expresar el
  /// punto de equilibrio en unidades.
  final double? unidadesActuales;

  /// Deuda nueva = Inversión × % financiado con deuda
  double get deudaNueva => inversionAdicional * pctDeuda;

  /// Mensaje si los supuestos no son válidos; null si lo son.
  String? get problema {
    if (crecimientoVentas <= -1) {
      return 'El crecimiento de ventas no puede ser −100 % o menor.';
    }
    if (variacionCostos <= -1) {
      return 'La variación de costos no puede ser −100 % o menor.';
    }
    if (inversionAdicional < 0) {
      return 'La inversión adicional no puede ser negativa.';
    }
    if (pctDeuda < 0 || pctDeuda > 1) {
      return 'El porcentaje de la inversión financiado con deuda debe estar entre 0 y 100.';
    }
    if (tasaInteres < 0) {
      return 'La tasa de interés no puede ser negativa.';
    }
    final t = tasaImpuesto;
    if (t != null && (t < 0 || t >= 1)) {
      return 'La tasa de impuesto debe ser mayor o igual a 0 % y menor que 100 %.';
    }
    if (pctDividendos < 0 || pctDividendos > 1) {
      return 'El porcentaje de dividendos debe estar entre 0 y 100.';
    }
    final u = unidadesActuales;
    if (u != null && u <= 0) {
      return 'Las unidades vendidas deben ser mayores que cero.';
    }
    return null;
  }

  /// Copia con puntos porcentuales de más o de menos (fracciones) en el
  /// crecimiento de ventas y en la variación de costos. Se usa en la sensibilidad.
  SupuestosProforma conCambios({double crecimiento = 0, double costos = 0}) =>
      SupuestosProforma(
        crecimientoVentas: crecimientoVentas + crecimiento,
        variacionCostos: variacionCostos + costos,
        inversionAdicional: inversionAdicional,
        pctDeuda: pctDeuda,
        tasaInteres: tasaInteres,
        tasaImpuesto: tasaImpuesto,
        pctDividendos: pctDividendos,
        unidadesActuales: unidadesActuales,
      );
}

/// Una fila de las tablas proforma: valor actual, proyectado y variación.
class FilaProforma {
  const FilaProforma(this.nombre, this.actual, this.proyectado,
      {this.total = false});

  final String nombre;
  final double actual;
  final double proyectado;

  /// Subtotales y totales se muestran en negrita.
  final bool total;

  double get variacion => proyectado - actual;

  /// Variación relativa en %. Null si el valor actual es 0.
  double? get variacionPct =>
      actual == 0 ? null : variacion / actual.abs() * 100;
}

/// Estado de resultados de un período (real o proyectado).
class EstadoResultadosProforma {
  const EstadoResultadosProforma({
    required this.ventas,
    required this.costoVentas,
    required this.gastosOperacion,
    required this.otrosNeto,
    required this.intereses,
    required this.impuestos,
    required this.costosVariables,
    required this.costosFijos,
  });

  final double ventas;
  final double costoVentas;
  final double gastosOperacion;

  /// Otros ingresos − Otros gastos
  final double otrosNeto;
  final double intereses;
  final double impuestos;

  /// Costos y gastos de operación según su comportamiento (para C-V-U y apalancamiento).
  final double costosVariables;
  final double costosFijos;

  double get utilidadBruta => ventas - costoVentas;
  double get uaii => utilidadBruta - gastosOperacion + otrosNeto;
  double get utilidadAntesImpuestos => uaii - intereses;
  double get utilidadNeta => utilidadAntesImpuestos - impuestos;

  double get margenContribucion => ventas - costosVariables;

  /// Costos fijos + Otros gastos − Otros ingresos (así MC − este valor = UAII).
  double get costosFijosParaUaii => costosFijos - otrosNeto;

  /// Margen neto en %. Null si no hay ventas.
  double? get margenNeto => ventas == 0 ? null : utilidadNeta / ventas * 100;

  /// Ventas de equilibrio (C$) = Costos fijos / Razón de margen de contribución.
  double? get puntoEquilibrioMonetario {
    if (ventas <= 0) return null;
    final razon = margenContribucion / ventas;
    if (razon <= 0) return null;
    final pe = costosFijosParaUaii / razon;
    return pe < 0 ? 0.0 : pe;
  }

  /// Grado de apalancamiento total. Null si no se puede calcular.
  double? get gat {
    final d = DatosApalancamiento(
      ventas: ventas,
      costosVariables: costosVariables,
      costosFijos: costosFijosParaUaii,
      intereses: intereses,
    );
    if (d.problema != null) return null;
    return ResultadoApalancamiento(d).gat;
  }
}

/// Balance general resumido de un período (real o proyectado).
class BalanceProforma {
  const BalanceProforma({
    required this.efectivo,
    required this.otrosActivosCorrientes,
    required this.activosNoCorrientes,
    required this.pasivosCorrientes,
    required this.pasivosNoCorrientes,
    required this.patrimonio,
  });

  final double efectivo;
  final double otrosActivosCorrientes;
  final double activosNoCorrientes;
  final double pasivosCorrientes;
  final double pasivosNoCorrientes;
  final double patrimonio;

  double get activosCorrientes => efectivo + otrosActivosCorrientes;
  double get activos => activosCorrientes + activosNoCorrientes;
  double get pasivos => pasivosCorrientes + pasivosNoCorrientes;
  double get pasivoMasPatrimonio => pasivos + patrimonio;

  /// Activo − (Pasivo + Patrimonio). Debe ser 0 si el balance cuadra.
  double get diferencia => activos - pasivoMasPatrimonio;

  double? get razonCorriente =>
      pasivosCorrientes == 0 ? null : activosCorrientes / pasivosCorrientes;
}

/// Resultado completo de la proforma. Solo se crea con datos válidos.
class ResultadoProforma {
  ResultadoProforma._({
    required this.supuestos,
    required this.actualEr,
    required this.proyectadoEr,
    required this.actualBalance,
    required this.proyectadoBalance,
    required this.dividendos,
    required this.tasaImpuestoUsada,
    required this.tasaEfectivaActual,
  });

  final SupuestosProforma supuestos;
  final EstadoResultadosProforma actualEr;
  final EstadoResultadosProforma proyectadoEr;
  final BalanceProforma actualBalance;
  final BalanceProforma proyectadoBalance;

  /// Dividendos repartidos con la utilidad proyectada.
  final double dividendos;

  /// Tasa de impuesto aplicada en la proyección (fracción).
  final double tasaImpuestoUsada;

  /// Tasa efectiva del período actual (fracción); null si no se puede calcular.
  final double? tasaEfectivaActual;

  // ------------------------------------------------------------ construcción

  static String _norm(String s) {
    const conTilde = 'áàäâéèëêíìïîóòöôúùüûñ';
    const sinTilde = 'aaaaeeeeiiiioooouuuun';
    var r = s.toLowerCase();
    for (var i = 0; i < conTilde.length; i++) {
      r = r.replaceAll(conTilde[i], sinTilde[i]);
    }
    return r;
  }

  static bool _esEfectivo(String nombre) {
    final n = _norm(nombre);
    return n.contains('efectivo') || n.contains('caja') || n.contains('banco');
  }

  static bool _esCuentaPorPagar(String nombre) {
    final n = _norm(nombre);
    return n.contains('pagar') ||
        n.contains('proveedor') ||
        n.contains('acreedor');
  }

  /// Mensaje si no se puede construir la proforma; null si todo está listo.
  static String? bloqueo(EstadosController e, SupuestosProforma s) {
    final p = s.problema;
    if (p != null) return p;
    if (e.ventasNetas(Periodo.actual) <= 0) {
      return 'Las ventas netas de ${e.etiqueta(Periodo.actual)} están en cero. Ingresa el Estado de Resultados en el módulo Estados financieros.';
    }
    return null;
  }

  /// Construye la proforma a partir del período actual de los estados
  /// financieros. Devuelve null si [bloqueo] devuelve un mensaje.
  static ResultadoProforma? calcular(
      EstadosController e, SupuestosProforma s) {
    if (bloqueo(e, s) != null) return null;

    const p = Periodo.actual;
    final fv = 1 + s.crecimientoVentas; // volumen
    final fc = 1 + s.variacionCostos; // precios de costos

    // ---- Estado de resultados real
    final actual = EstadoResultadosProforma(
      ventas: e.ventasNetas(p),
      costoVentas: e.totalGrupo(Grupo.costoVentas, p),
      gastosOperacion: e.totalGrupo(Grupo.gastosOperacion, p),
      otrosNeto: e.totalGrupo(Grupo.otrosIngresos, p) -
          e.totalGrupo(Grupo.otrosGastos, p),
      intereses: e.gastosFinancieros(p),
      impuestos: e.totalGrupo(Grupo.impuestos, p),
      costosVariables: e.costosVariables(p),
      costosFijos: e.costosFijos(p),
    );

    // ---- Costos y gastos proyectados, cuenta por cuenta:
    //      variables: × volumen × precios; fijos: × precios.
    var costoVentasP = 0.0;
    var gastosOpP = 0.0;
    var variablesP = 0.0;
    var fijosP = 0.0;
    for (final g in [Grupo.costoVentas, Grupo.gastosOperacion]) {
      for (final c in e.deGrupo(g)) {
        final esVariable = c.comportamiento == Comportamiento.variable;
        final v = c.valor(p) * (esVariable ? fv * fc : fc);
        if (g == Grupo.costoVentas) {
          costoVentasP += v;
        } else {
          gastosOpP += v;
        }
        if (esVariable) {
          variablesP += v;
        } else {
          fijosP += v;
        }
      }
    }

    final ventasP = actual.ventas * fv;
    final deudaNueva = s.deudaNueva;
    final interesesP = actual.intereses + deudaNueva * s.tasaInteres;

    // ---- Impuesto
    final uaiActual = actual.utilidadAntesImpuestos;
    final double? efectiva = uaiActual > 0 && actual.impuestos > 0
        ? actual.impuestos / uaiActual
        : null;
    var tasa = s.tasaImpuesto ?? efectiva ?? 0.0;
    if (tasa < 0) tasa = 0;
    if (tasa >= 1) tasa = 0.99;

    final antesImp = ventasP - costoVentasP - gastosOpP + actual.otrosNeto - interesesP;
    final impuestosP = antesImp > 0 ? antesImp * tasa : 0.0;

    final proyectado = EstadoResultadosProforma(
      ventas: ventasP,
      costoVentas: costoVentasP,
      gastosOperacion: gastosOpP,
      otrosNeto: actual.otrosNeto,
      intereses: interesesP,
      impuestos: impuestosP,
      costosVariables: variablesP,
      costosFijos: fijosP,
    );

    final un = proyectado.utilidadNeta;
    final dividendos = un > 0 ? un * s.pctDividendos : 0.0;

    // ---- Balance real
    var efectivoAct = 0.0;
    var otrosAcAct = 0.0;
    for (final c in e.deGrupo(Grupo.activoCorriente)) {
      if (_esEfectivo(c.nombre)) {
        efectivoAct += c.valor(p);
      } else {
        otrosAcAct += c.valor(p);
      }
    }
    var pcOperativoAct = 0.0;
    var pcOtrosAct = 0.0;
    for (final c in e.deGrupo(Grupo.pasivoCorriente)) {
      if (_esCuentaPorPagar(c.nombre)) {
        pcOperativoAct += c.valor(p);
      } else {
        pcOtrosAct += c.valor(p);
      }
    }
    final ancAct = e.totalGrupo(Grupo.activoNoCorriente, p);
    final pncAct = e.totalGrupo(Grupo.pasivoNoCorriente, p);
    final patAct = e.totalPatrimonio(p);

    final balanceActual = BalanceProforma(
      efectivo: efectivoAct,
      otrosActivosCorrientes: otrosAcAct,
      activosNoCorrientes: ancAct,
      pasivosCorrientes: pcOperativoAct + pcOtrosAct,
      pasivosNoCorrientes: pncAct,
      patrimonio: patAct,
    );

    // ---- Balance proyectado
    // Cuentas por cobrar, inventarios, otros activos corrientes y cuentas por
    // pagar crecen con las ventas; el resto se mantiene. El efectivo sale del
    // flujo: utilidad − dividendos − aumento de capital de trabajo − inversión
    // + deuda nueva.
    final otrosAcP = otrosAcAct * fv;
    final pcP = pcOperativoAct * fv + pcOtrosAct;
    final ancP = ancAct + s.inversionAdicional;
    final pncP = pncAct + deudaNueva;
    final patP = patAct + un - dividendos;
    final efectivoP = efectivoAct +
        (un - dividendos) -
        (otrosAcP - otrosAcAct) -
        s.inversionAdicional +
        (pcP - balanceActual.pasivosCorrientes) +
        deudaNueva;

    final balanceProyectado = BalanceProforma(
      efectivo: efectivoP,
      otrosActivosCorrientes: otrosAcP,
      activosNoCorrientes: ancP,
      pasivosCorrientes: pcP,
      pasivosNoCorrientes: pncP,
      patrimonio: patP,
    );

    return ResultadoProforma._(
      supuestos: s,
      actualEr: actual,
      proyectadoEr: proyectado,
      actualBalance: balanceActual,
      proyectadoBalance: balanceProyectado,
      dividendos: dividendos,
      tasaImpuestoUsada: tasa,
      tasaEfectivaActual: efectiva,
    );
  }

  // ---------------------------------------------------------------- tablas

  /// Estado de resultados proforma (actual vs proyectado).
  List<FilaProforma> filasResultados() {
    final a = actualEr;
    final b = proyectadoEr;
    return [
      FilaProforma('Ventas netas', a.ventas, b.ventas, total: true),
      FilaProforma('Costo de ventas', a.costoVentas, b.costoVentas),
      FilaProforma('Utilidad bruta', a.utilidadBruta, b.utilidadBruta,
          total: true),
      FilaProforma(
          'Gastos de operación', a.gastosOperacion, b.gastosOperacion),
      FilaProforma('Otros ingresos (gastos), neto', a.otrosNeto, b.otrosNeto),
      FilaProforma('UAII', a.uaii, b.uaii, total: true),
      FilaProforma('Gastos por intereses', a.intereses, b.intereses),
      FilaProforma('Utilidad antes de impuestos', a.utilidadAntesImpuestos,
          b.utilidadAntesImpuestos,
          total: true),
      FilaProforma('Impuestos', a.impuestos, b.impuestos),
      FilaProforma('Utilidad neta', a.utilidadNeta, b.utilidadNeta,
          total: true),
    ];
  }

  /// Balance general proforma (actual vs proyectado).
  List<FilaProforma> filasBalance() {
    final a = actualBalance;
    final b = proyectadoBalance;
    return [
      FilaProforma('Efectivo y equivalentes', a.efectivo, b.efectivo),
      FilaProforma('Otros activos corrientes', a.otrosActivosCorrientes,
          b.otrosActivosCorrientes),
      FilaProforma('Total activos corrientes', a.activosCorrientes,
          b.activosCorrientes,
          total: true),
      FilaProforma('Activos no corrientes', a.activosNoCorrientes,
          b.activosNoCorrientes),
      FilaProforma('TOTAL ACTIVOS', a.activos, b.activos, total: true),
      FilaProforma(
          'Pasivos corrientes', a.pasivosCorrientes, b.pasivosCorrientes),
      FilaProforma('Pasivos no corrientes', a.pasivosNoCorrientes,
          b.pasivosNoCorrientes),
      FilaProforma('TOTAL PASIVOS', a.pasivos, b.pasivos, total: true),
      FilaProforma('Patrimonio', a.patrimonio, b.patrimonio),
      FilaProforma('PASIVO + PATRIMONIO', a.pasivoMasPatrimonio,
          b.pasivoMasPatrimonio,
          total: true),
    ];
  }

  // ------------------------------------------------------------ indicadores

  /// ROE en %. Null si el patrimonio es cero o negativo.
  static double? _roe(double utilidad, double patrimonio) =>
      patrimonio > 0 ? utilidad / patrimonio * 100 : null;

  double? get roeActual =>
      _roe(actualEr.utilidadNeta, actualBalance.patrimonio);

  double? get roeProyectado =>
      _roe(proyectadoEr.utilidadNeta, proyectadoBalance.patrimonio);

  double? get razonCorrienteActual => actualBalance.razonCorriente;

  double? get razonCorrienteProyectada => proyectadoBalance.razonCorriente;

  double? get puntoEquilibrioActual => actualEr.puntoEquilibrioMonetario;

  double? get puntoEquilibrioProyectado =>
      proyectadoEr.puntoEquilibrioMonetario;

  /// Precio promedio actual = Ventas / Unidades (solo si se informaron unidades).
  double? get _precioPromedio {
    final u = supuestos.unidadesActuales;
    if (u == null || u <= 0 || actualEr.ventas <= 0) return null;
    return actualEr.ventas / u;
  }

  /// Punto de equilibrio en unidades = Ventas de equilibrio / Precio promedio.
  double? _enUnidades(double? pe) {
    final precio = _precioPromedio;
    return (pe == null || precio == null) ? null : pe / precio;
  }

  double? get puntoEquilibrioUnidadesActual => _enUnidades(puntoEquilibrioActual);

  double? get puntoEquilibrioUnidadesProyectado =>
      _enUnidades(puntoEquilibrioProyectado);

  double? get gatActual => actualEr.gat;

  double? get gatProyectado => proyectadoEr.gat;

  double get efectivoActual => actualBalance.efectivo;

  double get efectivoProyectado => proyectadoBalance.efectivo;

  // ----------------------------------------------------------------- avisos

  List<String> get avisos {
    final a = <String>[];
    if (actualBalance.diferencia.abs() >= 0.01) {
      a.add(
          'El balance del período actual no cuadra (diferencia de C\$ ${formatoMonto(actualBalance.diferencia)}); el balance proforma arrastra esa misma diferencia.');
    }
    if (proyectadoEr.utilidadNeta < 0) {
      a.add(
          'Con estos supuestos la empresa proyecta una pérdida de C\$ ${formatoMonto(-proyectadoEr.utilidadNeta)}.');
    }
    if (efectivoProyectado < 0) {
      a.add(
          'El efectivo proyectado es negativo (C\$ ${formatoMonto(efectivoProyectado)}): hará falta financiamiento adicional o reducir la inversión.');
    }
    if (proyectadoBalance.patrimonio <= 0) {
      a.add(
          'El patrimonio proyectado es cero o negativo, por eso el ROE no se puede calcular.');
    }
    if (supuestos.tasaImpuesto == null &&
        tasaEfectivaActual == null &&
        proyectadoEr.utilidadAntesImpuestos > 0) {
      a.add(
          'No hay impuestos en el período actual ni tasa escrita: la proyección no calcula impuestos. Escribe una tasa de impuesto para incluirlos.');
    }
    return a;
  }

  // ------------------------------------------------------ lectura sin IA

  static String _pct(double v) => '${v.toStringAsFixed(1)} %';

  /// Lectura breve basada en reglas simples; funciona sin conexión a la IA.
  List<String> lectura() {
    final l = <String>[];
    final a = actualEr;
    final b = proyectadoEr;
    final dv = FilaProforma('', a.ventas, b.ventas).variacionPct;
    final du = FilaProforma('', a.utilidadNeta, b.utilidadNeta).variacionPct;

    if (b.utilidadNeta < 0) {
      l.add(
          'La proyección termina en pérdida: los costos crecen más que los ingresos.');
    } else if (du != null && a.utilidadNeta > 0) {
      l.add(du >= 0
          ? 'Las ventas cambian ${_pct(dv ?? 0)} y la utilidad neta sube ${_pct(du)}.'
          : 'Las ventas cambian ${_pct(dv ?? 0)}, pero la utilidad neta baja ${_pct(-du)}: los costos y gastos crecen más rápido que los ingresos.');
    } else {
      l.add(
          'La utilidad neta proyectada es C\$ ${formatoMonto(b.utilidadNeta)}.');
    }

    final mn = b.margenNeto;
    final mnA = a.margenNeto;
    if (mn != null && mnA != null) {
      l.add(
          'El margen neto pasa de ${_pct(mnA)} a ${_pct(mn)}.');
    }

    final rc = razonCorrienteProyectada;
    if (rc != null) {
      l.add(rc < 1
          ? 'Liquidez débil: la razón corriente proyectada (${rc.toStringAsFixed(2)}) indica que los activos corrientes no cubren los pasivos corrientes.'
          : rc < 2
              ? 'Liquidez aceptable: razón corriente proyectada de ${rc.toStringAsFixed(2)}.'
              : 'Liquidez holgada: razón corriente proyectada de ${rc.toStringAsFixed(2)}.');
    }

    final gat = gatProyectado;
    if (gat != null) {
      l.add(gat > 3
          ? 'El grado de apalancamiento total proyectado es alto (${gat.toStringAsFixed(2)} veces): una pequeña caída en ventas golpearía fuerte la utilidad.'
          : 'El grado de apalancamiento total proyectado es ${gat.toStringAsFixed(2)} veces.');
    }

    final ms = supuestos.inversionAdicional;
    if (ms > 0 && efectivoProyectado < 0) {
      l.add(
          'La inversión adicional no se puede cubrir con los recursos proyectados.');
    }
    return l;
  }

  // ------------------------------------------------------ sensibilidad

  /// Utilidad neta proyectada si el crecimiento de ventas y la variación de
  /// costos cambian en los puntos porcentuales indicados (fracciones).
  static double? utilidadNetaCon(EstadosController e, SupuestosProforma s,
      {double crecimiento = 0, double costos = 0}) {
    final r = calcular(e, s.conCambios(crecimiento: crecimiento, costos: costos));
    return r?.proyectadoEr.utilidadNeta;
  }

  // ------------------------------------------------------------ resumen para IA

  static String _cs(double v) => 'C\$ ${formatoMonto(v)}';
  static String _n(double? v) => v == null ? 'n/d' : formatoMonto(v);
  static String _p(double? v) => v == null ? 'n/d' : '${v.toStringAsFixed(2)}%';
  static String _x(double? v) => v == null ? 'n/d' : '${v.toStringAsFixed(2)} veces';

  /// Texto con las cifras de la proforma para que la IA las interprete
  /// (también sirve como reporte para copiar).
  String resumenParaIa(EstadosController e) {
    final s = supuestos;
    final empresa = e.empresa.trim();
    final b = StringBuffer()
      ..writeln('Empresa: ${empresa.isEmpty ? '(sin nombre)' : empresa}')
      ..writeln('Moneda: córdobas (C\$).')
      ..writeln(
          'Proforma construida sobre el período ${e.etiqueta(Periodo.actual)}.')
      ..writeln('\nSupuestos de proyección:')
      ..writeln('- Crecimiento de ventas: ${(s.crecimientoVentas * 100).toStringAsFixed(2)}%')
      ..writeln('- Variación de costos y gastos: ${(s.variacionCostos * 100).toStringAsFixed(2)}%')
      ..writeln('- Inversión adicional: ${_cs(s.inversionAdicional)} (${(s.pctDeuda * 100).toStringAsFixed(0)}% con deuda nueva de ${_cs(s.deudaNueva)} a ${(s.tasaInteres * 100).toStringAsFixed(2)}% de interés)')
      ..writeln('- Tasa de impuesto aplicada: ${(tasaImpuestoUsada * 100).toStringAsFixed(2)}%${s.tasaImpuesto == null ? ' (tasa efectiva del período actual)' : ''}')
      ..writeln('- Dividendos: ${(s.pctDividendos * 100).toStringAsFixed(0)}% de la utilidad neta (${_cs(dividendos)})')
      ..writeln('\nEstado de resultados (actual | proyectado | variación %):');
    for (final f in filasResultados()) {
      b.writeln(
          '- ${f.nombre}: ${_n(f.actual)} | ${_n(f.proyectado)} | ${_p(f.variacionPct)}');
    }
    b.writeln('\nBalance general (actual | proyectado | variación %):');
    for (final f in filasBalance()) {
      b.writeln(
          '- ${f.nombre}: ${_n(f.actual)} | ${_n(f.proyectado)} | ${_p(f.variacionPct)}');
    }
    b
      ..writeln('\nIndicadores (actual | proyectado):')
      ..writeln('- ROE: ${_p(roeActual)} | ${_p(roeProyectado)}')
      ..writeln('- Razón corriente: ${_x(razonCorrienteActual)} | ${_x(razonCorrienteProyectada)}')
      ..writeln('- Punto de equilibrio (ventas, C\$): ${_n(puntoEquilibrioActual)} | ${_n(puntoEquilibrioProyectado)}');
    if (supuestos.unidadesActuales != null) {
      b.writeln(
          '- Punto de equilibrio (unidades): ${_n(puntoEquilibrioUnidadesActual)} | ${_n(puntoEquilibrioUnidadesProyectado)}');
    }
    b
      ..writeln('- Grado de apalancamiento total: ${_x(gatActual)} | ${_x(gatProyectado)}')
      ..writeln('- Efectivo: ${_n(efectivoActual)} | ${_n(efectivoProyectado)}');
    for (final aviso in avisos) {
      b.writeln('- Nota: $aviso');
    }
    return b.toString();
  }
}
