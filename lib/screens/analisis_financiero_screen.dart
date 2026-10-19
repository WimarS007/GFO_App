import 'package:flutter/material.dart';

import '../analisis/analisis_calculos.dart';
import '../estados/estados_controller.dart';
import '../estados/estados_models.dart';
import '../estados/montos.dart';
import '../ia/ia_service.dart';
import '../ia/ia_widgets.dart';
import '../widgets/common.dart';

/// Análisis horizontal, vertical, razones y DuPont.
/// Los datos vienen del [EstadosController] compartido; las interpretaciones
/// se piden a la IA con [IaConfig].
class AnalisisFinancieroScreen extends StatefulWidget {
  const AnalisisFinancieroScreen({
    super.key,
    required this.estados,
    required this.ia,
  });

  final EstadosController estados;
  final IaConfig ia;

  @override
  State<AnalisisFinancieroScreen> createState() =>
      _AnalisisFinancieroScreenState();
}

class _AnalisisFinancieroScreenState extends State<AnalisisFinancieroScreen> {
  late final AnalisisFinanciero _a = AnalisisFinanciero(widget.estados);
  late final IaService _servicio = IaService(widget.ia);

  final _acciones = TextEditingController();
  final _precio = TextEditingController();

  final Map<Alcance, String> _resultados = {};
  final Map<Alcance, String> _errores = {};
  final Set<Alcance> _cargando = {};

  @override
  void dispose() {
    _acciones.dispose();
    _precio.dispose();
    _servicio.cerrar();
    super.dispose();
  }

  Future<void> _generar(Alcance alcance) async {
    setState(() {
      _cargando.add(alcance);
      _errores.remove(alcance);
    });
    try {
      final texto = await _servicio.interpretar(
        enfoque: alcance.titulo,
        resumen: _a.resumenParaIa(alcance),
      );
      if (!mounted) return;
      setState(() => _resultados[alcance] = texto);
    } on IaException catch (e) {
      if (!mounted) return;
      setState(() => _errores[alcance] = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando.remove(alcance));
    }
  }

  Widget _panelIa(Alcance alcance, {String? titulo}) => IaPanel(
        titulo: titulo ?? 'Interpretación con IA',
        config: widget.ia,
        puedeGenerar: _a.hayDatos,
        cargando: _cargando.contains(alcance),
        resultado: _resultados[alcance],
        error: _errores[alcance],
        onGenerar: () => _generar(alcance),
      );

  @override
  Widget build(BuildContext context) {
    // Se reconstruye al cambiar los estados financieros.
    return ListenableBuilder(
      listenable: widget.estados,
      builder: (context, _) {
        final c = widget.estados;
        final ant = c.etiqueta(Periodo.anterior);
        final act = c.etiqueta(Periodo.actual);

        return PageScaffold(
          title: 'Análisis financiero',
          subtitle:
              'Análisis horizontal y vertical, razones financieras y sistema DuPont con los datos de los estados financieros.',
          children: [
            const InfoBox(
              text:
                  'Los datos se toman del módulo Estados financieros. Aquí solo se muestran los resultados.',
            ),
            if (!_a.hayDatos)
              const InfoBox(
                icon: Icons.warning_amber_outlined,
                text:
                    'Todavía no hay cifras. Ingresa o importa tus estados en el módulo Estados financieros.',
              ),
            TabSwitcher(
              labels: const [
                'Horizontal',
                'Vertical',
                'Razones financieras',
                'DuPont',
              ],
              pages: [
                _horizontal(ant, act),
                _vertical(ant, act),
                _razones(),
                _dupont(),
              ],
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------- horizontal

  Widget _horizontal(String ant, String act) {
    final cols = [ant, act, 'Variación (C\$)', 'Variación (%)'];
    List<List<String>> celdas(List<FilaAnalisis> filas) => [
          for (final f in filas)
            [
              formatoMonto(f.anterior),
              formatoMonto(f.actual),
              formatoMonto(f.variacion),
              _pct(f.variacionPct),
            ],
        ];
    final balance = _a.filasBalance();
    final resultados = _a.filasResultados();

    return SpacedColumn(
      children: [
        SectionCard(
          title: 'Análisis horizontal · Balance General',
          subtitle: 'Variación absoluta y relativa entre períodos.',
          child: _Tabla(
            columnas: cols,
            filas: balance,
            celdas: celdas(balance),
          ),
        ),
        SectionCard(
          title: 'Análisis horizontal · Estado de Resultados',
          subtitle: 'Variación absoluta y relativa entre períodos.',
          child: _Tabla(
            columnas: cols,
            filas: resultados,
            celdas: celdas(resultados),
          ),
        ),
        _panelIa(Alcance.horizontal),
      ],
    );
  }

  // ------------------------------------------------------------------ vertical

  Widget _vertical(String ant, String act) {
    final cols = ['$ant (%)', '$act (%)'];
    final c = widget.estados;
    List<List<String>> celdas(List<FilaAnalisis> filas, double Function(Periodo) base) {
      final bA = base(Periodo.anterior);
      final bB = base(Periodo.actual);
      return [
        for (final f in filas)
          [
            _pct(AnalisisFinanciero.pctDe(f.anterior, bA)),
            _pct(AnalisisFinanciero.pctDe(f.actual, bB)),
          ],
      ];
    }

    final balance = _a.filasBalance();
    final resultados = _a.filasResultados();

    return SpacedColumn(
      children: [
        SectionCard(
          title: 'Análisis vertical · Balance General',
          subtitle: 'Cada cuenta como porcentaje del total de activos.',
          child: _Tabla(
            columnas: cols,
            filas: balance,
            celdas: celdas(balance, c.totalActivos),
          ),
        ),
        SectionCard(
          title: 'Análisis vertical · Estado de Resultados',
          subtitle: 'Cada cuenta como porcentaje de las ventas netas.',
          child: _Tabla(
            columnas: cols,
            filas: resultados,
            celdas: celdas(resultados, c.ventasNetas),
          ),
        ),
        _panelIa(Alcance.vertical),
      ],
    );
  }

  // ------------------------------------------------------------------- razones

  Widget _grupoRazones(String titulo, IconData icono, List<Razon> razones) {
    return SectionCard(
      title: titulo,
      icon: icono,
      child: ResponsiveGrid(
        minColumnWidth: 220,
        children: [
          for (final r in razones)
            ResultTile(
              label: r.nombre,
              unit: r.unidad,
              value: _valorRazon(r.actual, r.unidad),
              detail: 'Anterior: ${_valorRazon(r.anterior, r.unidad)}',
            ),
        ],
      ),
    );
  }

  Widget _razones() {
    final acciones = parseMonto(_acciones.text);
    final precio = parseMonto(_precio.text);
    final upa = (acciones != null && acciones > 0) ? _a.upa(acciones) : null;
    final pu = (upa != null && upa != 0 && precio != null) ? precio / upa : null;

    return SpacedColumn(
      children: [
        _grupoRazones('Liquidez', Icons.water_drop_outlined, _a.liquidez()),
        _grupoRazones('Actividad', Icons.autorenew, _a.actividad()),
        _grupoRazones(
            'Endeudamiento', Icons.account_balance_outlined, _a.endeudamiento()),
        _grupoRazones('Rentabilidad', Icons.trending_up, _a.rentabilidad()),
        SectionCard(
          title: 'Mercado (opcional)',
          icon: Icons.candlestick_chart_outlined,
          subtitle: 'Requiere datos adicionales; complétalos solo si los tienes.',
          child: SpacedColumn(
            children: [
              ResponsiveGrid(
                minColumnWidth: 220,
                children: [
                  NumberField(
                    label: 'Acciones en circulación',
                    suffix: 'acciones',
                    controller: _acciones,
                    onChanged: (_) => setState(() {}),
                  ),
                  NumberField(
                    label: 'Precio de mercado por acción',
                    prefix: 'C\$ ',
                    controller: _precio,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
              ResponsiveGrid(
                minColumnWidth: 220,
                children: [
                  ResultTile(
                    label: 'Utilidad por acción (UPA)',
                    unit: 'C\$',
                    value: upa == null ? '—' : formatoMonto(upa),
                  ),
                  ResultTile(
                    label: 'Precio / Utilidad',
                    unit: 'veces',
                    value: pu == null ? '—' : formatoMonto(pu),
                  ),
                ],
              ),
            ],
          ),
        ),
        InfoBox(
          icon: Icons.lightbulb_outline,
          text: 'Lectura rápida:\n${_a.lecturaRazones()}',
        ),
        _panelIa(Alcance.razones),
      ],
    );
  }

  // -------------------------------------------------------------------- DuPont

  Widget _dupont() {
    final a = _a.dupont(Periodo.anterior);
    final b = _a.dupont(Periodo.actual);
    String pc(double? v) => v == null ? '—' : formatoMonto(v * 100);
    String x(double? v) => v == null ? '—' : formatoMonto(v);

    return SpacedColumn(
      children: [
        const InfoBox(
          text:
              'ROE = Margen neto × Rotación de activos × Multiplicador de capital',
        ),
        SectionCard(
          title: 'Sistema DuPont',
          icon: Icons.account_tree_outlined,
          child: ResponsiveGrid(
            minColumnWidth: 220,
            children: [
              ResultTile(
                label: 'Margen neto',
                unit: '%',
                value: pc(b.margenNeto),
                detail: 'Anterior: ${pc(a.margenNeto)} %',
              ),
              ResultTile(
                label: 'Rotación de activos',
                unit: 'veces',
                value: x(b.rotacion),
                detail: 'Anterior: ${x(a.rotacion)}',
              ),
              ResultTile(
                label: 'Multiplicador de capital',
                unit: 'veces',
                value: x(b.multiplicador),
                detail: 'Anterior: ${x(a.multiplicador)}',
              ),
              ResultTile(
                label: 'ROE',
                unit: '%',
                value: pc(b.roe),
                detail: 'Anterior: ${pc(a.roe)} %',
              ),
            ],
          ),
        ),
        InfoBox(
          icon: Icons.lightbulb_outline,
          text: 'Lectura rápida: ${_a.lecturaDupont()}',
        ),
        _panelIa(Alcance.dupont),
        _panelIa(Alcance.completo, titulo: 'Informe completo con IA'),
      ],
    );
  }

  // ----------------------------------------------------------------- formatos

  static String _pct(double? v) => v == null ? '—' : '${formatoMonto(v, decimales: 1)} %';

  static String _valorRazon(double? v, String unidad) {
    if (v == null) return '—';
    return formatoMonto(v, decimales: unidad == 'días' ? 1 : 2);
  }
}

/// Tabla de solo lectura con filas de totales en negrita.
class _Tabla extends StatelessWidget {
  const _Tabla({
    required this.columnas,
    required this.filas,
    required this.celdas,
  });

  final List<String> columnas;
  final List<FilaAnalisis> filas;
  final List<List<String>> celdas;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('Cuenta')),
          for (final c in columnas) DataColumn(label: Text(c), numeric: true),
        ],
        rows: [
          for (var i = 0; i < filas.length; i++)
            DataRow(cells: [
              DataCell(Text(
                filas[i].nombre,
                style: filas[i].total
                    ? const TextStyle(fontWeight: FontWeight.bold)
                    : null,
              )),
              for (final t in celdas[i])
                DataCell(Text(
                  t,
                  style: filas[i].total
                      ? const TextStyle(fontWeight: FontWeight.bold)
                      : null,
                )),
            ]),
        ],
      ),
    );
  }
}
