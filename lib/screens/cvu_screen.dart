import 'package:flutter/material.dart';

import '../cvu/cvu_calculos.dart';
import '../cvu/cvu_grafica.dart';
import '../estados/montos.dart';
import '../ia/ia_service.dart';
import '../ia/ia_widgets.dart';
import '../widgets/common.dart';

/// Punto de equilibrio y relación costo-volumen-utilidad (C-V-U).
/// Los datos se escriben en este módulo y los resultados se actualizan al instante.
class CvuScreen extends StatefulWidget {
  const CvuScreen({super.key});

  @override
  State<CvuScreen> createState() => _CvuScreenState();
}

class _CvuScreenState extends State<CvuScreen> {
  // Datos base
  final _precio = TextEditingController();
  final _costoVariable = TextEditingController();
  final _costosFijos = TextEditingController();
  final _unidades = TextEditingController();

  // Escenario (cambios en %)
  final _cambioPrecio = TextEditingController();
  final _cambioCv = TextEditingController();
  final _cambioCf = TextEditingController();
  final _cambioVolumen = TextEditingController();

  // IA
  final IaConfig _iaConfig = const IaConfig();
  late final IaService _ia = IaService(_iaConfig);
  String? _textoIa;
  String? _errorIa;
  bool _cargandoIa = false;

  List<TextEditingController> get _todos => [
        _precio,
        _costoVariable,
        _costosFijos,
        _unidades,
        _cambioPrecio,
        _cambioCv,
        _cambioCf,
        _cambioVolumen,
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

  /// Fracción a partir de un campo en % (vacío = 0).
  double _fraccion(TextEditingController c) => (_valor(c) ?? 0) / 100;

  bool get _hayCambios =>
      _fraccion(_cambioPrecio) != 0 ||
      _fraccion(_cambioCv) != 0 ||
      _fraccion(_cambioCf) != 0 ||
      _fraccion(_cambioVolumen) != 0;

  /// null mientras falte precio, costo variable o costos fijos.
  DatosCvu? get _datos {
    final p = _valor(_precio);
    final cv = _valor(_costoVariable);
    final cf = _valor(_costosFijos);
    if (p == null || cv == null || cf == null) return null;
    return DatosCvu(
      precio: p,
      costoVariable: cv,
      costosFijos: cf,
      unidades: _valor(_unidades),
    );
  }

  DatosCvu _datosEscenario(DatosCvu base) => base.conCambios(
        cambioPrecio: _fraccion(_cambioPrecio),
        cambioCostoVariable: _fraccion(_cambioCv),
        cambioCostosFijos: _fraccion(_cambioCf),
        cambioVolumen: _fraccion(_cambioVolumen),
      );

  /// Cualquier cambio en los campos invalida la interpretación anterior.
  void _cambio() => setState(() {
        _textoIa = null;
        _errorIa = null;
      });

  void _limpiar() {
    for (final c in _todos) {
      c.clear();
    }
    _cambio();
  }

  Future<void> _generarIa(ResultadoCvu? base, ResultadoCvu? escenario) async {
    if (base == null) {
      setState(() => _errorIa =
          'Primero completa el precio, el costo variable y los costos fijos.');
      return;
    }
    setState(() {
      _cargandoIa = true;
      _errorIa = null;
    });
    try {
      final texto = await _ia.interpretar(
        enfoque: 'Punto de equilibrio y relación costo-volumen-utilidad (C-V-U)',
        resumen: resumenCvuParaIa(
          base: base,
          escenario: _hayCambios ? escenario : null,
          cambioPrecio: _fraccion(_cambioPrecio),
          cambioCostoVariable: _fraccion(_cambioCv),
          cambioCostosFijos: _fraccion(_cambioCf),
          cambioVolumen: _fraccion(_cambioVolumen),
        ),
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

  static String _m(double? v) => v == null ? '—' : formatoMonto(v);
  static String _p(double? f) =>
      f == null ? '—' : '${(f * 100).toStringAsFixed(2)}%';

  static String _difM(double? a, double? b) {
    if (a == null || b == null) return '—';
    final d = b - a;
    return '${d > 0 ? '+' : ''}${formatoMonto(d)}';
  }

  static String _difP(double? a, double? b) {
    if (a == null || b == null) return '—';
    final d = (b - a) * 100;
    return '${d > 0 ? '+' : ''}${d.toStringAsFixed(2)} pp';
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final datos = _datos;
    final problema = datos?.problema;
    final base = (datos != null && problema == null) ? ResultadoCvu(datos) : null;

    final datosEsc = datos == null ? null : _datosEscenario(datos);
    final problemaEsc = datosEsc?.problema;
    final escenario =
        (base != null && datosEsc != null && problemaEsc == null)
            ? ResultadoCvu(datosEsc)
            : null;

    return PageScaffold(
      title: 'Punto de equilibrio y C-V-U',
      subtitle:
          'Relación costo-volumen-utilidad: margen de contribución, punto de equilibrio y análisis de escenarios.',
      children: [
        _entrada(),
        if (datos == null)
          const InfoBox(
            text:
                'Ingresa el precio de venta, el costo variable unitario y los costos fijos para calcular. Las unidades vendidas son opcionales (se usan para la utilidad y el margen de seguridad).',
          )
        else if (problema != null)
          InfoBox(icon: Icons.warning_amber_outlined, text: problema),
        _resultados(base),
        _grafica(base),
        _escenarios(base, escenario, problemaEsc),
        IaPanel(
          config: _iaConfig,
          onGenerar: () => _generarIa(base, escenario),
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
                label: 'Precio de venta unitario',
                prefix: 'C\$ ',
                controller: _precio,
                onChanged: (_) => _cambio(),
              ),
              NumberField(
                label: 'Costo variable unitario',
                prefix: 'C\$ ',
                controller: _costoVariable,
                onChanged: (_) => _cambio(),
              ),
              NumberField(
                label: 'Costos fijos totales',
                prefix: 'C\$ ',
                controller: _costosFijos,
                onChanged: (_) => _cambio(),
              ),
              NumberField(
                label: 'Unidades vendidas (opcional)',
                suffix: 'unidades',
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
              label: const Text('Limpiar todo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultados(ResultadoCvu? r) {
    final pe = r?.puntoEquilibrioUnidades;
    final sinPe = r != null && !r.hayEquilibrio;

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
                label: 'Margen de contribución unitario',
                unit: 'C\$',
                value: r == null ? '—' : _m(r.margenContribucionUnitario),
                detail: 'Precio − Costo variable unitario',
              ),
              ResultTile(
                label: 'Razón de margen de contribución',
                unit: '%',
                value: r == null
                    ? '—'
                    : (r.razonMargenContribucion * 100).toStringAsFixed(2),
                detail: 'MC unitario / Precio',
              ),
              ResultTile(
                label: 'Punto de equilibrio',
                unit: 'unidades',
                value: _m(pe),
                detail: sinPe
                    ? 'No existe: el precio no supera el costo variable'
                    : pe == null
                        ? 'Costos fijos / MC unitario'
                        : 'Vende al menos ${pe.ceil()} unidades enteras',
              ),
              ResultTile(
                label: 'Punto de equilibrio',
                unit: 'C\$',
                value: _m(r?.puntoEquilibrioMonetario),
                detail: 'PE en unidades × Precio',
              ),
              ResultTile(
                label: 'Utilidad operativa',
                unit: 'C\$',
                value: _m(r?.utilidadOperativa),
                detail: r != null && r.datos.unidades == null
                    ? 'Ingresa las unidades vendidas'
                    : 'MC total − Costos fijos',
              ),
              ResultTile(
                label: 'Margen de seguridad',
                unit: '%',
                value: r?.margenSeguridadPorcentaje == null
                    ? '—'
                    : (r!.margenSeguridadPorcentaje! * 100).toStringAsFixed(2),
                detail: r?.margenSeguridadUnidades == null
                    ? '(Unidades − PE) / Unidades'
                    : '${_m(r!.margenSeguridadUnidades)} unidades sobre el PE',
              ),
            ],
          ),
          if (r != null && r.datos.unidades != null) _estadoContribucion(r),
        ],
      ),
    );
  }

  /// Estado de resultados por contribución con las unidades vendidas.
  Widget _estadoContribucion(ResultadoCvu r) {
    final filas = <(String, double?)>[
      ('Ingresos por ventas', r.ingresos),
      ('(−) Costos variables', r.costosVariablesTotales),
      ('(=) Margen de contribución total', r.margenContribucionTotal),
      ('(−) Costos fijos', r.datos.costosFijos),
      ('(=) Utilidad operativa', r.utilidadOperativa),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Estado por contribución')),
          DataColumn(label: Text('Monto (C\$)'), numeric: true),
        ],
        rows: [
          for (final f in filas)
            DataRow(cells: [
              DataCell(Text(f.$1,
                  style: f.$1.startsWith('(=)')
                      ? const TextStyle(fontWeight: FontWeight.bold)
                      : null)),
              DataCell(Text(_m(f.$2),
                  style: f.$1.startsWith('(=)')
                      ? const TextStyle(fontWeight: FontWeight.bold)
                      : null)),
            ]),
        ],
      ),
    );
  }

  Widget _grafica(ResultadoCvu? r) {
    return SectionCard(
      title: 'Gráfica del punto de equilibrio',
      icon: Icons.show_chart,
      subtitle: 'Se cruzan los ingresos totales y los costos totales en el punto de equilibrio.',
      child: r == null
          ? const SizedBox(
              height: 120,
              child: Center(
                child: Text('La gráfica aparecerá cuando ingreses datos válidos.'),
              ),
            )
          : GraficaCvu(resultado: r),
    );
  }

  Widget _escenarios(
      ResultadoCvu? base, ResultadoCvu? esc, String? problemaEsc) {
    return SectionCard(
      title: 'Análisis de escenarios',
      icon: Icons.tune,
      subtitle:
          'Indica el cambio porcentual de cada variable (puede ser negativo, por ejemplo -10).',
      child: SpacedColumn(
        gap: 14,
        children: [
          ResponsiveGrid(
            minColumnWidth: 200,
            children: [
              NumberField(
                label: 'Cambio en precio',
                suffix: '%',
                controller: _cambioPrecio,
                onChanged: (_) => _cambio(),
              ),
              NumberField(
                label: 'Cambio en costo variable',
                suffix: '%',
                controller: _cambioCv,
                onChanged: (_) => _cambio(),
              ),
              NumberField(
                label: 'Cambio en costos fijos',
                suffix: '%',
                controller: _cambioCf,
                onChanged: (_) => _cambio(),
              ),
              NumberField(
                label: 'Cambio en volumen',
                suffix: '%',
                controller: _cambioVolumen,
                onChanged: (_) => _cambio(),
              ),
            ],
          ),
          if (base == null)
            const InfoBox(
              text: 'Completa los datos de entrada para comparar el escenario con la situación base.',
            )
          else if (problemaEsc != null)
            InfoBox(
              icon: Icons.warning_amber_outlined,
              text: 'Con esos cambios el escenario no es válido: $problemaEsc',
            )
          else if (esc != null)
            _tablaEscenario(base, esc),
        ],
      ),
    );
  }

  Widget _tablaEscenario(ResultadoCvu b, ResultadoCvu e) {
    DataRow fila(String concepto, String base, String esc, String dif) =>
        DataRow(cells: [
          DataCell(Text(concepto)),
          DataCell(Text(base)),
          DataCell(Text(esc)),
          DataCell(Text(dif,
              style: const TextStyle(fontWeight: FontWeight.bold))),
        ]);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Concepto')),
          DataColumn(label: Text('Base'), numeric: true),
          DataColumn(label: Text('Escenario'), numeric: true),
          DataColumn(label: Text('Diferencia'), numeric: true),
        ],
        rows: [
          fila('Precio de venta unitario (C\$)', _m(b.datos.precio),
              _m(e.datos.precio), _difM(b.datos.precio, e.datos.precio)),
          fila('Costo variable unitario (C\$)', _m(b.datos.costoVariable),
              _m(e.datos.costoVariable),
              _difM(b.datos.costoVariable, e.datos.costoVariable)),
          fila('Costos fijos (C\$)', _m(b.datos.costosFijos),
              _m(e.datos.costosFijos),
              _difM(b.datos.costosFijos, e.datos.costosFijos)),
          fila('Unidades vendidas', _m(b.datos.unidades), _m(e.datos.unidades),
              _difM(b.datos.unidades, e.datos.unidades)),
          fila('Margen de contribución unitario (C\$)',
              _m(b.margenContribucionUnitario),
              _m(e.margenContribucionUnitario),
              _difM(b.margenContribucionUnitario,
                  e.margenContribucionUnitario)),
          fila('Punto de equilibrio (unidades)',
              _m(b.puntoEquilibrioUnidades), _m(e.puntoEquilibrioUnidades),
              _difM(b.puntoEquilibrioUnidades, e.puntoEquilibrioUnidades)),
          fila('Punto de equilibrio (C\$)', _m(b.puntoEquilibrioMonetario),
              _m(e.puntoEquilibrioMonetario),
              _difM(b.puntoEquilibrioMonetario, e.puntoEquilibrioMonetario)),
          fila('Utilidad operativa (C\$)', _m(b.utilidadOperativa),
              _m(e.utilidadOperativa),
              _difM(b.utilidadOperativa, e.utilidadOperativa)),
          fila('Margen de seguridad (%)', _p(b.margenSeguridadPorcentaje),
              _p(e.margenSeguridadPorcentaje),
              _difP(b.margenSeguridadPorcentaje, e.margenSeguridadPorcentaje)),
        ],
      ),
    );
  }
}
