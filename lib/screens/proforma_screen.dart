import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/indicadores_compartidos.dart';
import '../estados/estados_controller.dart';
import '../estados/estados_models.dart';
import '../estados/montos.dart';
import '../ia/ia_service.dart';
import '../ia/ia_widgets.dart';
import '../proforma/proforma_calculos.dart';
import '../proforma/proforma_widgets.dart';
import '../widgets/common.dart';

/// Proforma / reporte integrado: proyecta el estado de resultados y el balance
/// del período actual con unos pocos supuestos y resume los indicadores de los
/// demás módulos.
class ProformaScreen extends StatefulWidget {
  const ProformaScreen({
    super.key,
    required this.estados,
    required this.indicadores,
  });

  final EstadosController estados;
  final IndicadoresCompartidos indicadores;

  @override
  State<ProformaScreen> createState() => _ProformaScreenState();
}

class _ProformaScreenState extends State<ProformaScreen> {
  final _crecimiento = TextEditingController();
  final _costos = TextEditingController();
  final _inversion = TextEditingController();
  final _pctDeuda = TextEditingController();
  final _tasaInteres = TextEditingController();
  final _tasaImpuesto = TextEditingController();
  final _dividendos = TextEditingController();
  final _unidades = TextEditingController();
  final _conclusion = TextEditingController();

  List<TextEditingController> get _supuestos => [
        _crecimiento,
        _costos,
        _inversion,
        _pctDeuda,
        _tasaInteres,
        _tasaImpuesto,
        _dividendos,
        _unidades,
      ];

  // IA
  final IaConfig _iaConfig = const IaConfig();
  late final IaService _ia = IaService(_iaConfig);
  String? _textoIa;
  String? _resumenIa; // datos con los que se generó _textoIa
  String? _errorIa;
  bool _cargandoIa = false;

  @override
  void dispose() {
    for (final c in _supuestos) {
      c.dispose();
    }
    _conclusion.dispose();
    _ia.cerrar();
    super.dispose();
  }

  // ------------------------------------------------------------------ datos

  double? _valor(TextEditingController c) => parseMonto(c.text);

  /// Porcentaje escrito (10) -> fracción (0.10). Vacío = 0.
  double _fraccion(TextEditingController c) => (_valor(c) ?? 0) / 100;

  SupuestosProforma get _datos {
    final tasaTxt = _valor(_tasaImpuesto);
    final unidades = _valor(_unidades);
    return SupuestosProforma(
      crecimientoVentas: _fraccion(_crecimiento),
      variacionCostos: _fraccion(_costos),
      inversionAdicional: _valor(_inversion) ?? 0,
      pctDeuda: _fraccion(_pctDeuda),
      tasaInteres: _fraccion(_tasaInteres),
      tasaImpuesto: tasaTxt == null ? null : tasaTxt / 100,
      pctDividendos: _fraccion(_dividendos),
      unidadesActuales: (unidades != null && unidades != 0) ? unidades : null,
    );
  }

  void _cambio() => setState(() => _errorIa = null);

  void _limpiar() {
    for (final c in _supuestos) {
      c.clear();
    }
    _cambio();
  }

  // --------------------------------------------------------------------- IA

  Future<void> _generarIa(ResultadoProforma? r) async {
    if (r == null) {
      setState(() => _errorIa =
          'Primero ingresa el Estado de Resultados en Estados financieros y revisa los supuestos.');
      return;
    }
    final resumen = r.resumenParaIa(widget.estados);
    setState(() {
      _cargandoIa = true;
      _errorIa = null;
    });
    try {
      final texto = await _ia.interpretar(
        enfoque: 'Proforma: estado de resultados y balance proyectados con sus indicadores',
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

  Future<void> _copiarReporte(ResultadoProforma r) async {
    final b = StringBuffer(r.resumenParaIa(widget.estados));
    final c = _conclusion.text.trim();
    if (c.isNotEmpty) {
      b
        ..writeln('\nConclusiones y recomendaciones:')
        ..writeln(c);
    }
    await Clipboard.setData(ClipboardData(text: b.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reporte copiado al portapapeles.')),
    );
  }

  // ---------------------------------------------------------------- formato

  static String _veces(double? v) => v == null ? '—' : v.toStringAsFixed(2);

  static String _pct(double? v) => v == null ? '—' : v.toStringAsFixed(2);

  static String _monto(double? v) => v == null ? '—' : formatoMonto(v);

  /// "5.0 %" o "−5.0 %" para las etiquetas de la sensibilidad.
  static String _etiquetaPct(double fraccion) =>
      '${(fraccion * 100).toStringAsFixed(1)} %';

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.estados, widget.indicadores]),
      builder: (context, _) {
        final e = widget.estados;
        final s = _datos;
        final bloqueo = ResultadoProforma.bloqueo(e, s);
        final r = bloqueo == null ? ResultadoProforma.calcular(e, s) : null;

        // La interpretación se oculta si los datos cambiaron desde que se generó.
        final textoVisible = (_textoIa != null &&
                r != null &&
                _resumenIa == r.resumenParaIa(e))
            ? _textoIa
            : null;

        return PageScaffold(
          title: 'Proforma / reporte integrado',
          subtitle:
              'Proyección del estado de resultados y del balance de ${e.etiqueta(Periodo.actual)}, con los indicadores de los demás módulos.',
          children: [
            const InfoBox(
              text:
                  'Los datos de partida salen del período actual de Estados financieros. Solo indicas los supuestos: el crecimiento de ventas es de volumen (los costos variables lo siguen) y la variación de costos es de precios (afecta a todos los costos y gastos). Las cuentas por cobrar, los inventarios y las cuentas por pagar crecen con las ventas.',
            ),
            _supuestosCard(),
            if (bloqueo != null)
              InfoBox(icon: Icons.warning_amber_outlined, text: bloqueo),
            if (r != null) ...[
              for (final aviso in r.avisos)
                InfoBox(icon: Icons.warning_amber_outlined, text: aviso),
              _estadoResultados(r),
              _balance(r),
              _indicadores(r),
              _sensibilidad(r),
              _lectura(r),
              IaPanel(
                config: _iaConfig,
                onGenerar: () => _generarIa(r),
                resultado: textoVisible,
                error: _errorIa,
                cargando: _cargandoIa,
              ),
            ],
            _conclusionCard(r),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------- secciones

  Widget _supuestosCard() {
    return SectionCard(
      title: 'Supuestos de proyección',
      icon: Icons.tune,
      subtitle: 'Los campos vacíos se toman como cero.',
      child: SpacedColumn(
        gap: 16,
        children: [
          ResponsiveGrid(
            minColumnWidth: 220,
            children: [
              NumberField(
                label: 'Crecimiento de ventas proyectado',
                suffix: '%',
                controller: _crecimiento,
                onChanged: (_) => _cambio(),
              ),
              NumberField(
                label: 'Variación esperada de costos',
                suffix: '%',
                controller: _costos,
                onChanged: (_) => _cambio(),
              ),
              NumberField(
                label: 'Inversión adicional prevista',
                prefix: 'C\$ ',
                controller: _inversion,
                onChanged: (_) => _cambio(),
              ),
              NumberField(
                label: 'Parte de la inversión financiada con deuda',
                suffix: '%',
                controller: _pctDeuda,
                onChanged: (_) => _cambio(),
              ),
              NumberField(
                label: 'Tasa de interés de la deuda nueva',
                suffix: '% anual',
                controller: _tasaInteres,
                onChanged: (_) => _cambio(),
              ),
              NumberField(
                label: 'Tasa de impuesto (opcional)',
                suffix: '%',
                hint: 'Vacío = tasa efectiva actual',
                controller: _tasaImpuesto,
                onChanged: (_) => _cambio(),
              ),
              NumberField(
                label: 'Dividendos sobre la utilidad neta',
                suffix: '%',
                controller: _dividendos,
                onChanged: (_) => _cambio(),
              ),
              NumberField(
                label: 'Unidades vendidas actuales (opcional)',
                suffix: 'unidades',
                hint: 'Para el punto de equilibrio en unidades',
                controller: _unidades,
                onChanged: (_) => _cambio(),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _limpiar,
              icon: const Icon(Icons.refresh),
              label: const Text('Limpiar supuestos'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadoResultados(ResultadoProforma r) {
    return SectionCard(
      title: 'Estado de resultados proforma',
      icon: Icons.receipt_long_outlined,
      subtitle:
          'Tasa de impuesto aplicada: ${(r.tasaImpuestoUsada * 100).toStringAsFixed(2)} %'
          '${r.supuestos.tasaImpuesto == null ? ' (tasa efectiva del período actual)' : ''}.',
      child: TablaProforma(
        filas: r.filasResultados(),
        etiquetaActual: widget.estados.etiqueta(Periodo.actual),
      ),
    );
  }

  Widget _balance(ResultadoProforma r) {
    final dif = r.proyectadoBalance.diferencia;
    final cuadra = dif.abs() < 0.01;
    return SectionCard(
      title: 'Balance general proforma',
      icon: Icons.account_balance_outlined,
      subtitle:
          'El efectivo se obtiene del flujo: utilidad − dividendos − aumento de capital de trabajo − inversión + deuda nueva.',
      child: SpacedColumn(
        gap: 12,
        children: [
          TablaProforma(
            filas: r.filasBalance(),
            etiquetaActual: widget.estados.etiqueta(Periodo.actual),
          ),
          InfoBox(
            icon: cuadra
                ? Icons.check_circle_outline
                : Icons.warning_amber_outlined,
            text: cuadra
                ? 'El balance proforma cuadra: Activos = Pasivos + Patrimonio.'
                : 'El balance proforma no cuadra (diferencia de C\$ ${formatoMonto(dif)}). Revisa que el balance del período actual cuadre en Estados financieros.',
          ),
        ],
      ),
    );
  }

  Widget _indicadores(ResultadoProforma r) {
    final presupuesto = widget.indicadores.saldoEfectivoProyectado;
    final hayUnidades = r.supuestos.unidadesActuales != null;

    return SectionCard(
      title: 'Resumen de indicadores',
      icon: Icons.dashboard_customize_outlined,
      subtitle: 'Valor proyectado; debajo, el valor del período actual.',
      child: ResponsiveGrid(
        minColumnWidth: 220,
        children: [
          ResultTile(
            label: 'Utilidad neta proyectada',
            unit: 'C\$',
            value: _monto(r.proyectadoEr.utilidadNeta),
            detail: 'Actual: ${_monto(r.actualEr.utilidadNeta)}',
          ),
          ResultTile(
            label: 'ROE proyectado',
            unit: '%',
            value: _pct(r.roeProyectado),
            detail: 'Actual: ${_pct(r.roeActual)}',
          ),
          ResultTile(
            label: 'Razón corriente proyectada',
            unit: 'veces',
            value: _veces(r.razonCorrienteProyectada),
            detail: 'Actual: ${_veces(r.razonCorrienteActual)}',
          ),
          ResultTile(
            label: 'Punto de equilibrio',
            unit: hayUnidades ? 'unidades' : 'C\$ en ventas',
            value: hayUnidades
                ? _monto(r.puntoEquilibrioUnidadesProyectado)
                : _monto(r.puntoEquilibrioProyectado),
            detail:
                'Actual: ${hayUnidades ? _monto(r.puntoEquilibrioUnidadesActual) : _monto(r.puntoEquilibrioActual)}'
                '${hayUnidades ? '' : ' · escribe las unidades vendidas para verlo en unidades'}',
          ),
          ResultTile(
            label: 'Grado de apalancamiento total',
            unit: 'veces',
            value: _veces(r.gatProyectado),
            detail: 'Actual: ${_veces(r.gatActual)}',
          ),
          ResultTile(
            label: 'Saldo de efectivo proyectado',
            unit: 'C\$',
            value: _monto(r.efectivoProyectado),
            detail: 'Actual: ${_monto(r.efectivoActual)}',
          ),
          if (presupuesto != null)
            ResultTile(
              label: 'Efectivo según presupuesto de caja',
              unit: 'C\$',
              value: formatoMonto(presupuesto),
              detail: 'Planeación y presupuestos (T4)',
            ),
        ],
      ),
    );
  }

  Widget _sensibilidad(ResultadoProforma r) {
    final e = widget.estados;
    const filas = [-0.10, -0.05, 0.0, 0.05, 0.10];
    const columnas = [-0.05, 0.0, 0.05];
    final s = r.supuestos;

    final valores = [
      for (final f in filas)
        [
          for (final c in columnas)
            ResultadoProforma.utilidadNetaCon(e, s, crecimiento: f, costos: c),
        ],
    ];

    return SectionCard(
      title: 'Sensibilidad de la utilidad neta',
      icon: Icons.grid_on_outlined,
      subtitle:
          'Utilidad neta proyectada (C\$) si el crecimiento de ventas o la variación de costos cambian unos puntos porcentuales. En color, tus supuestos.',
      child: TablaSensibilidad(
        etiquetasFilas: [
          for (final f in filas) _etiquetaPct(s.crecimientoVentas + f),
        ],
        etiquetasColumnas: [
          for (final c in columnas)
            'Costos ${_etiquetaPct(s.variacionCostos + c)}',
        ],
        valores: valores,
        filaBase: 2,
        columnaBase: 1,
      ),
    );
  }

  Widget _lectura(ResultadoProforma r) {
    final puntos = r.lectura();
    return SectionCard(
      title: 'Lectura automática',
      icon: Icons.insights_outlined,
      subtitle: 'Resumen basado en reglas simples; no necesita conexión a la IA.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in puntos)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2, right: 8),
                    child: Icon(Icons.chevron_right, size: 18),
                  ),
                  Expanded(child: Text(p)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _conclusionCard(ResultadoProforma? r) {
    return SectionCard(
      title: 'Conclusión para la toma de decisiones',
      icon: Icons.edit_note,
      child: SpacedColumn(
        gap: 12,
        children: [
          TextFieldBox(
            label: 'Conclusiones y recomendaciones',
            hint: 'Escribe aquí la decisión financiera que apoyan los resultados.',
            maxLines: 5,
            controller: _conclusion,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: r == null ? null : () => _copiarReporte(r),
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Copiar reporte'),
            ),
          ),
        ],
      ),
    );
  }
}
