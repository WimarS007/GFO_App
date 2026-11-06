import 'dart:math' as math;

import '../analisis/analisis_calculos.dart';
import '../apalancamiento/apalancamiento_calculos.dart';
import '../estados/estados_controller.dart';
import '../estados/estados_models.dart';
import '../estados/montos.dart';
import '../flujo/flujo_controller.dart';
import '../inventario/inventario_controller.dart';
import '../personal/personal_controller.dart';
import '../presupuestos/presupuestos_controller.dart';
import 'reporte_models.dart';

/// Secciones que se pueden incluir en el reporte.
enum SeccionId {
  estados('Estados financieros',
      'Balance General y Estado de Resultados de ambos períodos.'),
  analisis('Análisis financiero',
      'Análisis horizontal y vertical, razones financieras y DuPont.'),
  cvu('Punto de equilibrio (C-V-U)',
      'Margen de contribución y punto de equilibrio según los estados.'),
  apalancamiento('Apalancamiento', 'Grados de apalancamiento operativo, financiero y total.'),
  flujo('Flujo de efectivo',
      'Actividades de operación, inversión y financiamiento.'),
  presupuestos('Planeación y presupuestos',
      'Ventas, compras, costo de bienes vendidos, gastos y caja por trimestre.'),
  personal('Presupuesto personal',
      'Ingresos, gastos, ahorro, saldo y comparación con lo proyectado.'),
  inventario('Control de inventario',
      'Existencias, valor del inventario, movimientos y activos del hogar.');

  const SeccionId(this.titulo, this.descripcion);

  final String titulo;
  final String descripcion;
}

/// Arma un [Reporte] con los datos actuales de la app.
class ConstructorReporte {
  ConstructorReporte({
    required this.estados,
    required this.flujo,
    required this.presupuestos,
    required this.personal,
    required this.inventario,
  });

  final EstadosController estados;
  final FlujoController flujo;
  final PresupuestosController presupuestos;
  final PersonalController personal;
  final InventarioController inventario;

  static const _ant = Periodo.anterior;
  static const _act = Periodo.actual;

  String get _pAnt => estados.etiqueta(_ant);
  String get _pAct => estados.etiqueta(_act);

  // ------------------------------------------------------------ disponibilidad

  bool _hayEstados() => AnalisisFinanciero(estados).hayDatos;

  bool _hayVentas() =>
      estados.ventasNetas(_ant) > 0 || estados.ventasNetas(_act) > 0;

  /// ¿La sección tiene datos para mostrar? (Para avisar en la pantalla.)
  bool tieneDatos(SeccionId id) {
    switch (id) {
      case SeccionId.estados:
      case SeccionId.analisis:
        return _hayEstados();
      case SeccionId.cvu:
      case SeccionId.apalancamiento:
        return _hayVentas();
      case SeccionId.flujo:
        return flujo.hayMovimientos;
      case SeccionId.presupuestos:
        return presupuestos.hayDatos;
      case SeccionId.personal:
        return personal.hayMovimientos;
      default: // inventario
        return inventario.productos.isNotEmpty ||
            inventario.activos.isNotEmpty;
    }
  }

  // ------------------------------------------------------------------ armado

  Reporte construir(Set<SeccionId> ids) {
    final secciones = <SeccionReporte>[];
    for (final id in SeccionId.values) {
      if (!ids.contains(id)) continue;
      secciones.add(_seccion(id));
    }
    final empresa = estados.empresa.trim();
    return Reporte(
      titulo: 'Reporte financiero',
      empresa: empresa.isEmpty ? '(sin nombre)' : empresa,
      generado: DateTime.now(),
      secciones: secciones,
    );
  }

  SeccionReporte _seccion(SeccionId id) {
    if (!tieneDatos(id)) {
      return SeccionReporte(titulo: id.titulo, bloques: [
        NotaReporte([_mensajeSinDatos(id)]),
      ]);
    }
    switch (id) {
      case SeccionId.estados:
        return _estados();
      case SeccionId.analisis:
        return _analisis();
      case SeccionId.cvu:
        return _cvu();
      case SeccionId.apalancamiento:
        return _apalancamiento();
      case SeccionId.flujo:
        return _flujo();
      case SeccionId.presupuestos:
        return _presupuestos();
      case SeccionId.personal:
        return _personal();
      default: // inventario
        return _inventario();
    }
  }

  String _mensajeSinDatos(SeccionId id) {
    switch (id) {
      case SeccionId.estados:
      case SeccionId.analisis:
        return 'Sin datos: ingresa o importa los estados financieros en el módulo «Estados financieros».';
      case SeccionId.cvu:
      case SeccionId.apalancamiento:
        return 'Sin datos: las ventas netas están en cero. Ingresa el Estado de Resultados en «Estados financieros».';
      case SeccionId.flujo:
        return 'Sin datos: no hay movimientos de efectivo registrados en «Flujo de efectivo».';
      case SeccionId.presupuestos:
        return 'Sin datos: escribe las unidades a vender de cada trimestre en «Planeación y presupuestos».';
      case SeccionId.personal:
        return 'Sin datos: no hay movimientos registrados en «Presupuesto personal».';
      default: // inventario
        return 'Sin datos: no hay productos ni activos registrados en «Control de inventario».';
    }
  }

  // ----------------------------------------------------------------- ayudas

  static Celda _t(String s, {bool negrita = false}) =>
      Celda.texto(s, negrita: negrita);

  static Celda _m(double? v, {bool negrita = false}) =>
      Celda.numero(v, negrita: negrita);

  static Celda _pct(double? v, {bool negrita = false}) => Celda.numero(v,
      formato: FormatoNumero.porcentaje, negrita: negrita);

  static Celda _dec(double? v, {bool negrita = false}) =>
      Celda.numero(v, formato: FormatoNumero.decimal, negrita: negrita);

  static String _fecha(DateTime d) {
    String x(int n) => n.toString().padLeft(2, '0');
    return '${x(d.day)}/${x(d.month)}/${d.year}';
  }

  static FilaReporte _filaAnalisis(FilaAnalisis f) => FilaReporte([
        _t(f.nombre, negrita: f.total),
        _m(f.anterior, negrita: f.total),
        _m(f.actual, negrita: f.total),
      ], destacada: f.total);

  // --------------------------------------------------------------- 1. estados

  SeccionReporte _estados() {
    final a = AnalisisFinanciero(estados);
    final cols = ['Concepto', _pAnt, _pAct];
    final avisos = <String>[];
    for (final p in Periodo.values) {
      final d = estados.diferenciaBalance(p);
      if (estados.hayDatos(p, Estado.balance) && d.abs() >= 0.01) {
        avisos.add(
            'El balance de ${estados.etiqueta(p)} no cuadra: diferencia de C\$ ${formatoMonto(d)}.');
      }
    }
    return SeccionReporte(titulo: SeccionId.estados.titulo, bloques: [
      NotaReporte([
        'Empresa: ${estados.empresa.trim().isEmpty ? '(sin nombre)' : estados.empresa.trim()}',
        'Períodos: $_pAnt y $_pAct. Montos en córdobas (C\$).',
      ]),
      TablaReporte(
        titulo: 'Balance General',
        columnas: cols,
        filas: [for (final f in a.filasBalance()) _filaAnalisis(f)],
      ),
      TablaReporte(
        titulo: 'Estado de Resultados',
        columnas: cols,
        filas: [for (final f in a.filasResultados()) _filaAnalisis(f)],
      ),
      if (avisos.isNotEmpty) NotaReporte(avisos, titulo: 'Avisos'),
    ]);
  }

  // -------------------------------------------------------------- 2. análisis

  SeccionReporte _analisis() {
    final a = AnalisisFinanciero(estados);
    final bal = a.filasBalance();
    final res = a.filasResultados();

    FilaReporte horizontal(FilaAnalisis f) => FilaReporte([
          _t(f.nombre, negrita: f.total),
          _m(f.anterior, negrita: f.total),
          _m(f.actual, negrita: f.total),
          _m(f.variacion, negrita: f.total),
          _pct(f.variacionPct, negrita: f.total),
        ], destacada: f.total);

    FilaReporte vertical(FilaAnalisis f, double baseAnt, double baseAct) =>
        FilaReporte([
          _t(f.nombre, negrita: f.total),
          _pct(AnalisisFinanciero.pctDe(f.anterior, baseAnt),
              negrita: f.total),
          _pct(AnalisisFinanciero.pctDe(f.actual, baseAct), negrita: f.total),
        ], destacada: f.total);

    FilaReporte razon(Razon r) {
      final unidad = r.unidad;
      Celda c(double? v) {
        if (unidad == '%') return _pct(v);
        if (unidad == 'C\$') return _m(v);
        return _dec(v);
      }

      final etiqueta = unidad == '%' || unidad == 'C\$'
          ? r.nombre
          : '${r.nombre} ($unidad)';
      return FilaReporte([_t(etiqueta), c(r.anterior), c(r.actual)]);
    }

    TablaReporte tablaRazones(String titulo, List<Razon> l) => TablaReporte(
        titulo: titulo,
        columnas: ['Razón', _pAnt, _pAct],
        filas: [for (final r in l) razon(r)]);

    final dpA = a.dupont(_ant);
    final dpB = a.dupont(_act);
    double? porc(double? f) => f == null ? null : f * 100;

    List<String> lineas(String s) =>
        s.split('\n').where((x) => x.trim().isNotEmpty).toList();

    return SeccionReporte(titulo: SeccionId.analisis.titulo, bloques: [
      TablaReporte(
        titulo: 'Análisis horizontal · Balance General',
        columnas: ['Concepto', _pAnt, _pAct, 'Variación', 'Variación %'],
        filas: [for (final f in bal) horizontal(f)],
      ),
      TablaReporte(
        titulo: 'Análisis horizontal · Estado de Resultados',
        columnas: ['Concepto', _pAnt, _pAct, 'Variación', 'Variación %'],
        filas: [for (final f in res) horizontal(f)],
      ),
      TablaReporte(
        titulo: 'Análisis vertical · Balance General (% del total de activos)',
        columnas: ['Concepto', _pAnt, _pAct],
        filas: [
          for (final f in bal)
            vertical(f, estados.totalActivos(_ant), estados.totalActivos(_act)),
        ],
      ),
      TablaReporte(
        titulo: 'Análisis vertical · Estado de Resultados (% de las ventas)',
        columnas: ['Concepto', _pAnt, _pAct],
        filas: [
          for (final f in res)
            vertical(f, estados.ventasNetas(_ant), estados.ventasNetas(_act)),
        ],
      ),
      tablaRazones('Razones de liquidez', a.liquidez()),
      tablaRazones('Razones de actividad', a.actividad()),
      tablaRazones('Razones de endeudamiento', a.endeudamiento()),
      tablaRazones('Razones de rentabilidad', a.rentabilidad()),
      TablaReporte(
        titulo: 'Sistema DuPont',
        columnas: ['Componente', _pAnt, _pAct],
        filas: [
          FilaReporte([
            _t('Margen neto'),
            _pct(porc(dpA.margenNeto)),
            _pct(porc(dpB.margenNeto)),
          ]),
          FilaReporte([
            _t('Rotación de activos (veces)'),
            _dec(dpA.rotacion),
            _dec(dpB.rotacion),
          ]),
          FilaReporte([
            _t('Multiplicador de capital (veces)'),
            _dec(dpA.multiplicador),
            _dec(dpB.multiplicador),
          ]),
          FilaReporte([
            _t('ROE', negrita: true),
            _pct(porc(dpA.roe), negrita: true),
            _pct(porc(dpB.roe), negrita: true),
          ], destacada: true),
        ],
      ),
      NotaReporte([
        ...lineas(a.lecturaRazones()),
        ...lineas(a.lecturaDupont()),
      ], titulo: 'Lectura'),
    ]);
  }

  // ------------------------------------------------------------------ 3. CVU

  SeccionReporte _cvu() {
    List<Celda> fila(String nombre, double? Function(Periodo) f,
            {bool pct = false, bool negrita = false}) =>
        [
          _t(nombre, negrita: negrita),
          pct ? _pct(f(_ant), negrita: negrita) : _m(f(_ant), negrita: negrita),
          pct ? _pct(f(_act), negrita: negrita) : _m(f(_act), negrita: negrita),
        ];

    double? razon(Periodo p) {
      final v = estados.ventasNetas(p);
      return v > 0 ? estados.margenContribucion(p) / v : null;
    }

    double? pe(Periodo p) {
      final r = razon(p);
      if (r == null || r <= 0) return null;
      return math.max(0.0, estados.costosFijosParaUaii(p) / r);
    }

    double? seguridad(Periodo p) {
      final e = pe(p);
      final v = estados.ventasNetas(p);
      if (e == null || v <= 0) return null;
      return (v - e) / v * 100;
    }

    return SeccionReporte(titulo: SeccionId.cvu.titulo, bloques: [
      TablaReporte(
        titulo: 'Margen de contribución y punto de equilibrio',
        columnas: ['Concepto', _pAnt, _pAct],
        filas: [
          FilaReporte(fila('Ventas netas', estados.ventasNetas)),
          FilaReporte(fila('Costos variables', estados.costosVariables)),
          FilaReporte(
              fila('Margen de contribución', estados.margenContribucion,
                  negrita: true),
              destacada: true),
          FilaReporte(fila(
              'Razón de margen de contribución', (p) => razon(p) == null ? null : razon(p)! * 100,
              pct: true)),
          FilaReporte(fila(
              'Costos fijos (incluye otros gastos − otros ingresos)',
              estados.costosFijosParaUaii)),
          FilaReporte(fila('UAII', estados.uaii, negrita: true),
              destacada: true),
          FilaReporte(
              fila('Punto de equilibrio (ventas, C\$)', pe, negrita: true),
              destacada: true),
          FilaReporte(fila('Margen de seguridad', seguridad, pct: true)),
        ],
      ),
      const NotaReporte([
        'Calculado a partir de los estados financieros, según la clasificación de cada costo como fijo o variable.',
        'Para el análisis por unidad (precio y costo variable unitarios) y los escenarios, usa el módulo «Punto de equilibrio y C-V-U».',
      ], titulo: 'Nota'),
    ]);
  }

  // --------------------------------------------------------- 4. apalancamiento

  SeccionReporte _apalancamiento() {
    final resultados = <Periodo, ResultadoApalancamiento?>{};
    final problemas = <String>[];
    for (final p in Periodo.values) {
      final d = DatosApalancamiento(
        ventas: estados.ventasNetas(p),
        costosVariables: estados.costosVariables(p),
        costosFijos: estados.costosFijosParaUaii(p),
        intereses: estados.gastosFinancieros(p),
      );
      final problema = d.problema;
      if (problema != null) {
        resultados[p] = null;
        if (estados.ventasNetas(p) > 0) {
          problemas.add('${estados.etiqueta(p)}: $problema');
        } else {
          problemas.add(
              '${estados.etiqueta(p)}: no hay ventas, por eso no se calcula.');
        }
      } else {
        resultados[p] = ResultadoApalancamiento(d);
      }
    }

    List<Celda> fila(String nombre, double? Function(ResultadoApalancamiento) f,
        {bool dec = false, bool negrita = false}) {
      Celda c(Periodo p) {
        final r = resultados[p];
        final v = r == null ? null : f(r);
        return dec ? _dec(v, negrita: negrita) : _m(v, negrita: negrita);
      }

      return [_t(nombre, negrita: negrita), c(_ant), c(_act)];
    }

    final avisos = <String>[];
    for (final p in Periodo.values) {
      final r = resultados[p];
      if (r == null) continue;
      if (r.avisoGao != null) avisos.add('${estados.etiqueta(p)}: ${r.avisoGao}');
      if (r.avisoGaf != null) avisos.add('${estados.etiqueta(p)}: ${r.avisoGaf}');
    }

    return SeccionReporte(titulo: SeccionId.apalancamiento.titulo, bloques: [
      TablaReporte(
        titulo: 'Grados de apalancamiento',
        columnas: ['Concepto', _pAnt, _pAct],
        filas: [
          FilaReporte(fila('Margen de contribución', (r) => r.margenContribucion)),
          FilaReporte(fila('Costos fijos', (r) => r.datos.costosFijos)),
          FilaReporte(fila('UAII', (r) => r.uaii, negrita: true),
              destacada: true),
          FilaReporte(fila('Gastos por intereses', (r) => r.datos.intereses)),
          FilaReporte(fila('GAO (veces)', (r) => r.gao, dec: true)),
          FilaReporte(fila('GAF (veces)', (r) => r.gaf, dec: true)),
          FilaReporte(fila('GAT (veces)', (r) => r.gat, dec: true, negrita: true),
              destacada: true),
        ],
      ),
      if (problemas.isNotEmpty || avisos.isNotEmpty)
        NotaReporte([...problemas, ...avisos], titulo: 'Avisos'),
      const NotaReporte([
        'GAO = Margen de contribución / UAII. GAF = UAII / (UAII − intereses). GAT = GAO × GAF.',
        'Se calcula con los estados financieros, sin dividendos preferentes.',
      ], titulo: 'Fórmulas'),
    ]);
  }

  // --------------------------------------------------------------- 5. flujo

  SeccionReporte _flujo() {
    final filas = <FilaReporte>[];
    for (final a in Actividad.values) {
      filas.add(FilaReporte([_t(a.titulo, negrita: true), const Celda.vacia()],
          destacada: true));
      for (final s in Sentido.values) {
        for (final l in flujo.lineas(a, s)) {
          if (l.monto == 0) continue;
          final nombre =
              l.concepto.trim().isEmpty ? '(sin nombre)' : l.concepto.trim();
          final prefijo = s == Sentido.entrada ? 'Entrada' : 'Salida';
          filas.add(FilaReporte([_t('   $prefijo · $nombre'), _m(l.monto)]));
        }
      }
      filas.add(FilaReporte([_t('   Total entradas'), _m(flujo.totalEntradas(a))]));
      filas.add(FilaReporte([_t('   Total salidas'), _m(flujo.totalSalidas(a))]));
      filas.add(FilaReporte(
          [_t('Flujo neto', negrita: true), _m(flujo.flujoNeto(a), negrita: true)],
          destacada: true));
    }

    final inicial = flujo.saldoInicial(estados);
    final bloques = <Bloque>[
      TablaReporte(
        titulo: 'Flujo de efectivo · $_pAct (método directo)',
        columnas: const ['Concepto', 'Monto'],
        filas: filas,
      ),
      TablaReporte(
        titulo: 'Resumen',
        columnas: const ['Concepto', 'Monto'],
        filas: [
          FilaReporte([_t('Variación neta de efectivo'), _m(flujo.variacionNeta)]),
          FilaReporte([
            _t(flujo.saldoDesdeEstados
                ? 'Saldo inicial (tomado del balance)'
                : 'Saldo inicial'),
            _m(inicial),
          ]),
          FilaReporte([
            _t('Saldo final de efectivo', negrita: true),
            _m(flujo.saldoFinal(estados), negrita: true),
          ], destacada: true),
        ],
      ),
    ];

    if (flujo.hayCuentasDeEfectivo(estados) &&
        estados.hayDatos(_act, Estado.balance)) {
      final enBalance = flujo.efectivoEnBalance(estados, _act);
      final dif = flujo.saldoFinal(estados) - enBalance;
      bloques.add(NotaReporte([
        'Efectivo según el balance de $_pAct: C\$ ${formatoMonto(enBalance)}.',
        dif.abs() < 0.01
            ? 'El saldo final del flujo coincide con el balance.'
            : 'Diferencia con el saldo final calculado: C\$ ${formatoMonto(dif)}.',
      ], titulo: 'Conciliación con el balance'));
    }
    return SeccionReporte(titulo: SeccionId.flujo.titulo, bloques: bloques);
  }

  // ---------------------------------------------------------- 6. presupuestos

  SeccionReporte _presupuestos() {
    final r = presupuestos.calcular();
    final cols = ['Concepto', ...trimestres, 'Total'];

    FilaReporte fila(String nombre, List<double> v,
        {bool total = true, bool negrita = false, bool unidades = false}) {
      Celda c(double x) => unidades
          ? Celda.numero(x, formato: FormatoNumero.decimal, negrita: negrita)
          : _m(x, negrita: negrita);
      return FilaReporte([
        _t(nombre, negrita: negrita),
        for (final x in v) c(x),
        total ? c(suma(v)) : const Celda.vacia(),
      ], destacada: negrita);
    }

    return SeccionReporte(titulo: SeccionId.presupuestos.titulo, bloques: [
      TablaReporte(titulo: 'Presupuesto de ventas', columnas: cols, filas: [
        fila('Unidades a vender', r.unidades, unidades: true),
        fila('Precio de venta', r.precios, total: false),
        fila('Ventas', r.ventas, negrita: true),
        fila('Ventas de contado', r.ventasContado),
        fila('Ventas a crédito', r.ventasCredito),
      ]),
      TablaReporte(titulo: 'Presupuesto de compras', columnas: cols, filas: [
        fila('Inventario inicial (unid.)', r.invInicialUnid,
            total: false, unidades: true),
        fila('Inventario final deseado (unid.)', r.invFinalDeseado,
            total: false, unidades: true),
        fila('Compras (unid.)', r.comprasUnid, unidades: true),
        fila('Compras', r.comprasMonto, negrita: true),
        fila('Compras de contado', r.comprasContado),
        fila('Compras a crédito', r.comprasCredito),
      ]),
      TablaReporte(
          titulo: 'Costo de bienes vendidos y resultado operativo',
          columnas: cols,
          filas: [
            fila('Inventario inicial', r.invInicialMonto, total: false),
            fila('Compras', r.comprasMonto),
            fila('Inventario final', r.invFinalMonto, total: false),
            fila('Costo de bienes vendidos', r.cbv, negrita: true),
            fila('Utilidad bruta', r.utilidadBruta, negrita: true),
            fila('Gastos de operación', r.gastosTotales),
            fila('Utilidad operativa', r.utilidadOperativa, negrita: true),
          ]),
      TablaReporte(
        titulo: 'Gastos de operación',
        columnas: cols,
        filas: [
          for (final g in presupuestos.gastos)
            fila(
              g.concepto.trim().isEmpty
                  ? '(sin nombre)'
                  : '${g.concepto.trim()}${g.afectaCaja ? '' : ' (sin efectivo)'}',
              g.montos,
            ),
        ],
      ),
      TablaReporte(titulo: 'Presupuesto de caja', columnas: cols, filas: [
        fila('Saldo inicial de caja', r.cajaInicial, total: false),
        fila('Cobros', r.cobros),
        fila('Pagos de compras', r.pagosCompras),
        fila('Gastos pagados en efectivo', r.gastosEfectivo),
        fila('Otros desembolsos', r.otros),
        fila('Saldo antes de financiamiento', r.saldoAntes, total: false),
        fila('Financiamiento necesario', r.financiamiento),
        fila('Saldo final de caja', r.saldoFinal, total: false, negrita: true),
      ]),
      if (presupuestos.avisos.isNotEmpty)
        NotaReporte(presupuestos.avisos, titulo: 'Avisos'),
    ]);
  }

  // ------------------------------------------------------------- 7. personal

  SeccionReporte _personal() {
    final r = personal.calcular();
    final avance = personal.avanceMeta(r);
    final comparacion = personal.comparar(r);
    final lectura = personal.lectura(r);

    return SeccionReporte(titulo: SeccionId.personal.titulo, bloques: [
      TablaReporte(
        titulo: 'Meta de ahorro',
        columnas: const ['Concepto', 'Valor'],
        filas: [
          FilaReporte([
            _t('Persona'),
            _t(personal.nombre.trim().isEmpty ? '(sin nombre)' : personal.nombre.trim())
          ]),
          FilaReporte([
            _t('Meta'),
            _t(personal.meta.trim().isEmpty ? '(sin meta)' : personal.meta.trim())
          ]),
          FilaReporte([_t('Costo de la meta'), _m(personal.costoMeta)]),
          FilaReporte([
            _t('Duración (semanas)'),
            Celda.numero(personal.semanas.toDouble(),
                formato: FormatoNumero.entero)
          ]),
          FilaReporte([_t('Aporte semanal necesario'), _m(personal.aporteSemanal)]),
          FilaReporte([
            _t('Ahorro acumulado'),
            _m(r.ahorro),
          ]),
          FilaReporte([
            _t('Avance de la meta'),
            _pct(avance == null ? null : avance * 100),
          ]),
        ],
      ),
      TablaReporte(
        titulo: 'Resumen del período',
        columnas: const ['Concepto', 'Monto'],
        filas: [
          FilaReporte([_t('Ingresos'), _m(r.ingresos)]),
          FilaReporte([_t('Gastos'), _m(r.gastos)]),
          FilaReporte([_t('Ahorro'), _m(r.ahorro)]),
          FilaReporte([_t('Reserva'), _m(r.reserva)]),
          FilaReporte(
              [_t('Saldo disponible', negrita: true), _m(r.saldo, negrita: true)],
              destacada: true),
        ],
      ),
      TablaReporte(
        titulo: 'Seguimiento semanal',
        columnas: const [
          'Semana', 'Desde', 'Hasta', 'Ingresos', 'Gastos', 'Ahorro',
          'Reserva', 'Saldo'
        ],
        filas: [
          for (final s in r.semanas)
            if (s.hayActividad)
              FilaReporte([
                Celda.numero(s.semana.toDouble(), formato: FormatoNumero.entero),
                _t(_fecha(s.desde)),
                _t(_fecha(s.hasta)),
                _m(s.ingresos),
                _m(s.gastos),
                _m(s.ahorro),
                _m(s.reserva),
                _m(s.saldo),
              ]),
        ],
      ),
      if (r.gastosPorCategoria.isNotEmpty)
        TablaReporte(
          titulo: 'Gastos por categoría',
          columnas: const ['Categoría', 'Monto', '% del gasto'],
          filas: [
            for (final e in r.gastosPorCategoria)
              FilaReporte([
                _t(e.key),
                _m(e.value),
                _pct(r.gastos == 0 ? null : e.value / r.gastos * 100),
              ]),
          ],
        ),
      TablaReporte(
        titulo: 'Gastos según prioridad',
        columnas: const ['Prioridad', 'Monto'],
        filas: [
          FilaReporte([_t('Necesidad'), _m(r.gastoNecesidad)]),
          FilaReporte([_t('Deseo'), _m(r.gastoDeseo)]),
          FilaReporte([_t('Otra / sin clasificar'), _m(r.gastoOtraPrioridad)]),
        ],
      ),
      if (comparacion.isNotEmpty)
        TablaReporte(
          titulo: 'Proyectado vs. real (promedio semanal)',
          columnas: const [
            'Concepto', 'Planificado', 'Real', 'Diferencia', 'Estado'
          ],
          filas: [
            for (final f in comparacion)
              FilaReporte([
                _t(f.nombre),
                _m(f.planificado),
                _m(f.real),
                _m(f.diferencia),
                _t(f.estado),
              ]),
          ],
        ),
      if (lectura.isNotEmpty) NotaReporte(lectura, titulo: 'Lectura'),
    ]);
  }

  // ------------------------------------------------------------ 8. inventario

  SeccionReporte _inventario() {
    final bloques = <Bloque>[];
    final productos = inventario.productos;

    if (productos.isNotEmpty) {
      bloques.add(TablaReporte(
        titulo: 'Existencias por producto',
        columnas: const [
          'Código', 'Producto', 'Costo unit.', 'Exist. inicial', 'Entradas',
          'Salidas', 'Exist. final', 'Stock mín.', 'Valor', 'Estado'
        ],
        filas: [
          for (final p in productos)
            FilaReporte([
              _t(p.codigo),
              _t(p.nombre),
              _m(p.costoUnitario),
              _dec(p.existenciaInicial),
              _dec(inventario.entradas(p.id)),
              _dec(inventario.salidas(p.id)),
              _dec(inventario.existenciaFinal(p)),
              _dec(p.stockMinimo),
              _m(inventario.valor(p)),
              _t(inventario.requiereReposicion(p) ? 'Reponer' : 'Suficiente'),
            ]),
          FilaReporte([
            _t('', negrita: true),
            _t('TOTAL', negrita: true),
            const Celda.vacia(),
            const Celda.vacia(),
            const Celda.vacia(),
            const Celda.vacia(),
            _dec(inventario.unidadesTotales, negrita: true),
            const Celda.vacia(),
            _m(inventario.valorTotal, negrita: true),
            _t('${inventario.porReponer} por reponer', negrita: true),
          ], destacada: true),
        ],
      ));
    }

    final movs = inventario.movimientos;
    if (movs.isNotEmpty) {
      bloques.add(TablaReporte(
        titulo: 'Movimientos de inventario',
        columnas: const ['Fecha', 'Producto', 'Tipo', 'Cantidad', 'Nota'],
        filas: [
          for (final m in movs)
            FilaReporte([
              _t(_fecha(m.fecha)),
              _t(inventario.productoPorId(m.productoId)?.nombre ?? '(eliminado)'),
              _t(m.tipo.etiqueta),
              _dec(m.cantidad),
              _t(m.nota),
            ]),
        ],
      ));
    }

    final activos = inventario.activos;
    if (activos.isNotEmpty) {
      bloques.add(TablaReporte(
        titulo: 'Activos del hogar',
        columnas: const [
          'Artículo', 'Categoría', 'Ubicación', 'Cant.', 'Costo unit.',
          'Costo total', 'Valor actual', 'Estado'
        ],
        filas: [
          for (final a in activos)
            FilaReporte([
              _t(a.nombre),
              _t(a.categoria),
              _t(a.ubicacion),
              Celda.numero(a.cantidad.toDouble(), formato: FormatoNumero.entero),
              _m(a.costoUnitario),
              _m(a.costoTotal),
              _m(a.valorActualTotal),
              _t(a.estado),
            ]),
          FilaReporte([
            _t('TOTAL', negrita: true),
            const Celda.vacia(),
            const Celda.vacia(),
            Celda.numero(inventario.totalArticulos.toDouble(),
                formato: FormatoNumero.entero, negrita: true),
            const Celda.vacia(),
            _m(inventario.costoTotalActivos, negrita: true),
            _m(inventario.valorActualActivos, negrita: true),
            const Celda.vacia(),
          ], destacada: true),
        ],
      ));
    }

    return SeccionReporte(titulo: SeccionId.inventario.titulo, bloques: bloques);
  }
}
