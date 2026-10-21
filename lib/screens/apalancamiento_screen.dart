import 'package:flutter/material.dart';

import '../apalancamiento/apalancamiento_calculos.dart';
import '../core/indicadores_compartidos.dart';
import '../estados/estados_controller.dart';
import '../estados/estados_models.dart';
import '../estados/fuente_estados.dart';
import '../estados/montos.dart';
import '../ia/ia_service.dart';
import '../ia/ia_widgets.dart';
import '../widgets/common.dart';

/// Grado de apalancamiento operativo (GAO), financiero (GAF) y total (GAT).
/// Puede trabajar con datos escritos aquí o tomados de los estados financieros.
class ApalancamientoScreen extends StatefulWidget {
  const ApalancamientoScreen({
    super.key,
    required this.estados,
    required this.indicadores,
  });

  final EstadosController estados;
  final IndicadoresCompartidos indicadores;

  @override
  State<ApalancamientoScreen> createState() => _ApalancamientoScreenState();
}

class _ApalancamientoScreenState extends State<ApalancamientoScreen> {
  static const _cambioInicial = '10';

  final _ventas = TextEditingController();
  final _costosVariables = TextEditingController();
  final _costosFijos = TextEditingController();
  final _intereses = TextEditingController();
  final _dividendos = TextEditingController();
  final _tasa = TextEditingController();
  final _cambioVentas = TextEditingController(text: _cambioInicial);

  // Conexión con los estados financieros
  bool _usarEstados = false;
  Periodo _periodo = Periodo.actual;

  // IA
  final IaConfig _iaConfig = const IaConfig();
  late final IaService _ia = IaService(_iaConfig);
  String? _textoIa;
  String? _resumenIa; // datos con los que se generó _textoIa
  String? _errorIa;
  bool _cargandoIa = false;

  List<TextEditingController> get _todos => [
        _ventas,
        _costosVariables,
        _costosFijos,
        _intereses,
        _dividendos,
        _tasa,
        _cambioVentas,
      ];

  @override
  void initState() {
    super.initState();
    widget.estados.addListener(_publicar);
  }

  @override
  void dispose() {
    widget.estados.removeListener(_publicar);
    for (final c in _todos) {
      c.dispose();
    }
    _ia.cerrar();
    super.dispose();
  }

  // ------------------------------------------------------------------ datos

  double? _valor(TextEditingController c) => parseMonto(c.text);

  /// null mientras falten datos obligatorios.
  /// Con estados: ventas, costos variables, costos fijos e intereses vienen del
  /// Estado de Resultados; dividendos preferentes y tasa se escriben aquí.
  DatosApalancamiento? get _datos {
    final dividendos = _valor(_dividendos) ?? 0;
    final tasa = (_valor(_tasa) ?? 0) / 100;

    if (_usarEstados) {
      final e = widget.estados;
      final p = _periodo;
      final ventas = e.ventasNetas(p);
      if (ventas <= 0) return null;
      return DatosApalancamiento(
        ventas: ventas,
        costosVariables: e.costosVariables(p),
        costosFijos: e.costosFijosParaUaii(p),
        intereses: e.gastosFinancieros(p),
        dividendosPreferentes: dividendos,
        tasaImpuestos: tasa,
      );
    }

    final v = _valor(_ventas);
    final cv = _valor(_costosVariables);
    final cf = _valor(_costosFijos);
    if (v == null || cv == null || cf == null) return null;
    return DatosApalancamiento(
      ventas: v,
      costosVariables: cv,
      costosFijos: cf,
      intereses: _valor(_intereses) ?? 0,
      dividendosPreferentes: dividendos,
      tasaImpuestos: tasa,
    );
  }

  String get _mensajeSinDatos => _usarEstados
      ? 'Las ventas netas de ${widget.estados.etiqueta(_periodo)} están en cero. Ingresa el Estado de Resultados en el módulo Estados financieros.'
      : 'Ingresa las ventas, los costos variables y los costos fijos para calcular. Los intereses, los dividendos preferentes y la tasa son opcionales: si están vacíos se toman como cero.';

  ResultadoApalancamiento? get _resultado {
    final d = _datos;
    return (d != null && d.problema == null)
        ? ResultadoApalancamiento(d)
        : null;
  }

  /// Publica el GAT para el panel principal.
  void _publicar() => widget.indicadores.publicarGat(_resultado?.gat);

  void _cambio() {
    setState(() => _errorIa = null);
    _publicar();
  }

  void _limpiar() {
    for (final c in _todos) {
      c.clear();
    }
    _cambioVentas.text = _cambioInicial;
    _cambio();
  }

  Future<void> _generarIa(ResultadoApalancamiento? r) async {
    if (r == null) {
      setState(() => _errorIa = _usarEstados
          ? 'Primero ingresa el Estado de Resultados en Estados financieros.'
          : 'Primero completa las ventas, los costos variables y los costos fijos.');
      return;
    }
    final resumen = resumenApalancamientoParaIa(r);
    setState(() {
      _cargandoIa = true;
      _errorIa = null;
    });
    try {
      final texto = await _ia.interpretar(
        enfoque: 'Apalancamiento operativo, financiero y total (GAO, GAF y GAT)',
        resumen: resumen,
      );
      if (!mounted) return;
      setState(() {
        _textoIa = texto;
        _resumenIa = resumen;
      });
    } on IaException catch (e) {
      if (!mounted) return;
      setState(() => _errorIa = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargandoIa = false);
    }
  }

  // ---------------------------------------------------------------- formato

  static String _veces(double? v) => v == null ? '—' : v.toStringAsFixed(2);

  static String _mov(double pct) => pct >= 0
      ? 'aumenta ${pct.toStringAsFixed(2)}%'
      : 'disminuye ${(-pct).toStringAsFixed(2)}%';

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.estados,
      builder: (context, _) {
        final datos = _datos;
        final problema = datos?.problema;
        final r = (datos != null && problema == null)
            ? ResultadoApalancamiento(datos)
            : null;

        // La interpretación se oculta si los datos cambiaron desde que se generó.
        final textoVisible = (_textoIa != null &&
                r != null &&
                _resumenIa == resumenApalancamientoParaIa(r))
            ? _textoIa
            : null;

        return PageScaffold(
          title: 'Apalancamiento',
          subtitle:
              'Grado de apalancamiento operativo (GAO), financiero (GAF) y total (GAT).',
          children: [
            _entrada(),
            if (datos == null)
              InfoBox(text: _mensajeSinDatos)
            else if (problema != null)
              InfoBox(icon: Icons.warning_amber_outlined, text: problema),
            _resultados(r),
            _explicacion(r),
            IaPanel(
              config: _iaConfig,
              onGenerar: () => _generarIa(r),
              resultado: textoVisible,
              error: _errorIa,
              cargando: _cargandoIa,
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------- secciones

  Widget _entrada() {
    final e = widget.estados;
    final p = _periodo;

    final camposFinancieros = [
      NumberField(
        label: 'Dividendos preferentes (opcional)',
        prefix: 'C\$ ',
        controller: _dividendos,
        onChanged: (_) => _cambio(),
      ),
      NumberField(
        label: 'Tasa de impuestos (opcional)',
        suffix: '%',
        hint: 'Solo para dividendos preferentes',
        controller: _tasa,
        onChanged: (_) => _cambio(),
      ),
    ];

    return SectionCard(
      title: 'Datos de entrada',
      icon: Icons.edit_note,
      child: SpacedColumn(
        gap: 14,
        children: [
          FuenteEstados(
            estados: e,
            usar: _usarEstados,
            onUsar: (v) {
              setState(() => _usarEstados = v);
              _cambio();
            },
            periodo: _periodo,
            onPeriodo: (v) {
              setState(() => _periodo = v);
              _cambio();
            },
            descripcion:
                'Ventas, costos e intereses salen del Estado de Resultados (según lo que marcaste como costo fijo o variable).',
          ),
          if (_usarEstados)
            ResponsiveGrid(
              minColumnWidth: 220,
              children: [
                ValorDeEstados(
                    label: 'Ventas netas (C\$)',
                    valor: formatoMonto(e.ventasNetas(p))),
                ValorDeEstados(
                    label: 'Costos variables totales (C\$)',
                    valor: formatoMonto(e.costosVariables(p))),
                ValorDeEstados(
                  label: 'Costos fijos (C\$)',
                  valor: formatoMonto(e.costosFijosParaUaii(p)),
                  ayuda:
                      'Incluye otros gastos − otros ingresos, para que la UAII coincida con los estados',
                ),
                ValorDeEstados(
                    label: 'Gastos por intereses (C\$)',
                    valor: formatoMonto(e.gastosFinancieros(p))),
                ...camposFinancieros,
              ],
            )
          else
            ResponsiveGrid(
              minColumnWidth: 220,
              children: [
                NumberField(
                  label: 'Ventas',
                  prefix: 'C\$ ',
                  controller: _ventas,
                  onChanged: (_) => _cambio(),
                ),
                NumberField(
                  label: 'Costos variables totales',
                  prefix: 'C\$ ',
                  controller: _costosVariables,
                  onChanged: (_) => _cambio(),
                ),
                NumberField(
                  label: 'Costos fijos',
                  prefix: 'C\$ ',
                  controller: _costosFijos,
                  onChanged: (_) => _cambio(),
                ),
                NumberField(
                  label: 'Gastos por intereses (opcional)',
                  prefix: 'C\$ ',
                  controller: _intereses,
                  onChanged: (_) => _cambio(),
                ),
                ...camposFinancieros,
              ],
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _limpiar,
              icon: const Icon(Icons.refresh),
              label: const Text('Limpiar campos'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultados(ResultadoApalancamiento? r) {
    return SectionCard(
      title: 'Resultados',
      icon: Icons.calculate_outlined,
      child: SpacedColumn(
        gap: 14,
        children: [
          ResponsiveGrid(
            minColumnWidth: 220,
            children: [
              ResultTile(
                label: 'Margen de contribución',
                unit: 'C\$',
                value: r == null ? '—' : formatoMonto(r.margenContribucion),
                detail: 'Ventas − Costos variables',
              ),
              ResultTile(
                label: 'UAII',
                unit: 'C\$',
                value: r == null ? '—' : formatoMonto(r.uaii),
                detail: 'Margen de contribución − Costos fijos',
              ),
              ResultTile(
                label: 'GAO · Grado de apalancamiento operativo',
                unit: 'veces',
                value: _veces(r?.gao),
                detail: 'Margen de contribución / UAII',
              ),
              ResultTile(
                label: 'GAF · Grado de apalancamiento financiero',
                unit: 'veces',
                value: _veces(r?.gaf),
                detail: 'UAII / (UAII − Intereses − Div. pref. / (1 − tasa))',
              ),
              ResultTile(
                label: 'GAT · Grado de apalancamiento total',
                unit: 'veces',
                value: _veces(r?.gat),
                detail: 'GAO × GAF',
              ),
            ],
          ),
          if (r?.avisoGao != null)
            InfoBox(icon: Icons.warning_amber_outlined, text: r!.avisoGao!),
          if (r != null && r.avisoGao == null && r.avisoGaf != null)
            InfoBox(icon: Icons.warning_amber_outlined, text: r.avisoGaf!),
        ],
      ),
    );
  }

  Widget _explicacion(ResultadoApalancamiento? r) {
    final gao = r?.gao;
    final gaf = r?.gaf;
    final gat = r?.gat;
    final g = (_valor(_cambioVentas) ?? 0);

    final lineas = <String>[
      if (gao != null)
        'GAO de ${_veces(gao)}: por cada 1% que cambien las ventas, la UAII cambia ${_veces(gao)}% en el mismo sentido. Mientras más costos fijos, mayor es el GAO y el riesgo operativo.',
      if (gaf != null)
        'GAF de ${_veces(gaf)}: por cada 1% que cambie la UAII, la utilidad disponible para los accionistas cambia ${_veces(gaf)}%. Mientras más deuda y dividendos preferentes, mayor es el GAF y el riesgo financiero.',
      if (gat != null)
        'GAT de ${_veces(gat)}: por cada 1% que cambien las ventas, la utilidad disponible para los accionistas cambia ${_veces(gat)}%. Combina el riesgo operativo y el financiero.',
    ];

    String? ejemplo;
    if (gao != null && g != 0) {
      final dUaii = gao * g;
      final sentido = g > 0 ? 'un aumento' : 'una disminución';
      final base =
          'Ejemplo: con $sentido de ${g.abs().toStringAsFixed(2)}% en las ventas, la UAII ${_mov(dUaii)}';
      final aviso = dUaii <= -100 ? ' (se volvería cero o negativa)' : '';
      if (gat != null) {
        ejemplo =
            '$base$aviso y la utilidad disponible para los accionistas ${_mov(gat * g)}.';
      } else {
        ejemplo = '$base$aviso.';
      }
    }

    return SectionCard(
      title: 'Explicación básica',
      icon: Icons.lightbulb_outline,
      child: SpacedColumn(
        gap: 12,
        children: [
          if (r == null)
            const Text('La explicación aparecerá cuando ingreses datos válidos.')
          else if (lineas.isEmpty)
            const Text(
                'Con estos datos no se puede calcular ningún grado de apalancamiento; revisa los avisos de arriba.')
          else
            for (final l in lineas)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(l)),
                ],
              ),
          if (r != null)
            SizedBox(
              width: 260,
              child: NumberField(
                label: 'Cambio en ventas para el ejemplo',
                suffix: '%',
                controller: _cambioVentas,
                onChanged: (_) => setState(() {}),
              ),
            ),
          if (ejemplo != null) InfoBox(text: ejemplo),
        ],
      ),
    );
  }
}
