import 'package:flutter/material.dart';

import '../apalancamiento/apalancamiento_calculos.dart';
import '../estados/montos.dart';
import '../ia/ia_service.dart';
import '../ia/ia_widgets.dart';
import '../widgets/common.dart';

/// Grado de apalancamiento operativo (GAO), financiero (GAF) y total (GAT).
/// Los datos se escriben en este módulo y los resultados se actualizan al instante.
class ApalancamientoScreen extends StatefulWidget {
  const ApalancamientoScreen({super.key});

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

  // IA
  final IaConfig _iaConfig = const IaConfig();
  late final IaService _ia = IaService(_iaConfig);
  String? _textoIa;
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
  void dispose() {
    for (final c in _todos) {
      c.dispose();
    }
    _ia.cerrar();
    super.dispose();
  }

  // ------------------------------------------------------------------ datos

  double? _valor(TextEditingController c) => parseMonto(c.text);

  /// null mientras falten ventas, costos variables o costos fijos.
  /// Intereses, dividendos y tasa vacíos se toman como 0.
  DatosApalancamiento? get _datos {
    final v = _valor(_ventas);
    final cv = _valor(_costosVariables);
    final cf = _valor(_costosFijos);
    if (v == null || cv == null || cf == null) return null;
    return DatosApalancamiento(
      ventas: v,
      costosVariables: cv,
      costosFijos: cf,
      intereses: _valor(_intereses) ?? 0,
      dividendosPreferentes: _valor(_dividendos) ?? 0,
      tasaImpuestos: (_valor(_tasa) ?? 0) / 100,
    );
  }

  /// Cualquier cambio en los campos invalida la interpretación anterior.
  void _alCambiar() => setState(() {
        _textoIa = null;
        _errorIa = null;
      });

  void _limpiar() {
    for (final c in _todos) {
      c.clear();
    }
    _cambioVentas.text = _cambioInicial;
    _alCambiar();
  }

  Future<void> _generarIa(ResultadoApalancamiento? r) async {
    if (r == null) {
      setState(() => _errorIa =
          'Primero completa las ventas, los costos variables y los costos fijos.');
      return;
    }
    setState(() {
      _cargandoIa = true;
      _errorIa = null;
    });
    try {
      final texto = await _ia.interpretar(
        enfoque: 'Apalancamiento operativo, financiero y total (GAO, GAF y GAT)',
        resumen: resumenApalancamientoParaIa(r),
      );
      if (!mounted) return;
      setState(() => _textoIa = texto);
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
    final datos = _datos;
    final problema = datos?.problema;
    final r = (datos != null && problema == null)
        ? ResultadoApalancamiento(datos)
        : null;

    return PageScaffold(
      title: 'Apalancamiento',
      subtitle:
          'Grado de apalancamiento operativo (GAO), financiero (GAF) y total (GAT).',
      children: [
        _entrada(),
        if (datos == null)
          const InfoBox(
            text:
                'Ingresa las ventas, los costos variables y los costos fijos para calcular. Los intereses, los dividendos preferentes y la tasa son opcionales: si están vacíos se toman como cero.',
          )
        else if (problema != null)
          InfoBox(icon: Icons.warning_amber_outlined, text: problema),
        _resultados(r),
        _explicacion(r),
        IaPanel(
          config: _iaConfig,
          onGenerar: () => _generarIa(r),
          resultado: _textoIa,
          error: _errorIa,
          cargando: _cargandoIa,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- secciones

  Widget _entrada() {
    return SectionCard(
      title: 'Datos de entrada',
      icon: Icons.edit_note,
      child: SpacedColumn(
        gap: 14,
        children: [
          ResponsiveGrid(
            minColumnWidth: 220,
            children: [
              NumberField(
                label: 'Ventas',
                prefix: 'C\$ ',
                controller: _ventas,
                onChanged: (_) => _alCambiar(),
              ),
              NumberField(
                label: 'Costos variables totales',
                prefix: 'C\$ ',
                controller: _costosVariables,
                onChanged: (_) => _alCambiar(),
              ),
              NumberField(
                label: 'Costos fijos',
                prefix: 'C\$ ',
                controller: _costosFijos,
                onChanged: (_) => _alCambiar(),
              ),
              NumberField(
                label: 'Gastos por intereses (opcional)',
                prefix: 'C\$ ',
                controller: _intereses,
                onChanged: (_) => _alCambiar(),
              ),
              NumberField(
                label: 'Dividendos preferentes (opcional)',
                prefix: 'C\$ ',
                controller: _dividendos,
                onChanged: (_) => _alCambiar(),
              ),
              NumberField(
                label: 'Tasa de impuestos (opcional)',
                suffix: '%',
                hint: 'Solo para dividendos preferentes',
                controller: _tasa,
                onChanged: (_) => _alCambiar(),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _limpiar,
              icon: const Icon(Icons.refresh),
              label: const Text('Limpiar todo'),
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
