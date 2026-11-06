import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../estados/montos.dart';
import '../ia/ia_service.dart';
import '../ia/ia_widgets.dart';
import '../personal/personal_controller.dart';
import '../personal/personal_importer.dart';
import '../personal/personal_models.dart';
import '../personal/personal_widgets.dart';
import '../widgets/common.dart';

/// Presupuesto personal con seguimiento semanal (lunes a domingo): meta de
/// ahorro, registro de movimientos, resumen por semana, presupuesto proyectado
/// y comparación con lo real. Se puede importar desde un Excel con el formato
/// de la plantilla de ejemplo.
class PresupuestoPersonalScreen extends StatefulWidget {
  const PresupuestoPersonalScreen({super.key, required this.personal});

  final PersonalController personal;

  @override
  State<PresupuestoPersonalScreen> createState() =>
      _PresupuestoPersonalScreenState();
}

class _PresupuestoPersonalScreenState extends State<PresupuestoPersonalScreen> {
  PersonalController get _p => widget.personal;

  // Datos y meta
  final _nombre = TextEditingController();
  final _meta = TextEditingController();
  final _costo = TextEditingController();
  final _semanas = TextEditingController();
  final _ingresoProy = TextEditingController();

  // Formulario de movimiento
  final _monto = TextEditingController();
  final _descripcion = TextEditingController();
  final _observacion = TextEditingController();
  late DateTime _fecha;
  TipoMov _tipo = TipoMov.gasto;
  String _categoria = 'Transporte';
  String _prioridad = 'Necesidad';
  String _medio = 'Efectivo';
  bool _verTodos = false;

  bool _importando = false;

  // IA
  final IaConfig _iaConfig = const IaConfig();
  late final IaService _ia = IaService(_iaConfig);
  String? _textoIa;
  String? _resumenIa; // datos con los que se generó _textoIa
  String? _errorIa;
  bool _cargandoIa = false;

  @override
  void initState() {
    super.initState();
    final h = DateTime.now();
    _fecha = DateTime(h.year, h.month, h.day);
    _sincronizar();
  }

  @override
  void dispose() {
    for (final c in [
      _nombre,
      _meta,
      _costo,
      _semanas,
      _ingresoProy,
      _monto,
      _descripcion,
      _observacion,
    ]) {
      c.dispose();
    }
    _ia.cerrar();
    super.dispose();
  }

  /// Copia los datos del controlador a los campos de texto (al importar).
  void _sincronizar() {
    _nombre.text = _p.nombre;
    _meta.text = _p.meta;
    _costo.text = _p.costoMeta == 0 ? '' : formatoMonto(_p.costoMeta);
    _semanas.text = _p.semanas == 0 ? '' : '${_p.semanas}';
    _ingresoProy.text =
        _p.ingresoProyectado == 0 ? '' : formatoMonto(_p.ingresoProyectado);
  }

  // ---------------------------------------------------------------- importar

  Future<void> _importarExcel() async {
    final seleccion = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    if (seleccion == null || seleccion.files.isEmpty || !mounted) return;

    final bytes = seleccion.files.single.bytes;
    if (bytes == null) {
      _mensaje('No se pudo leer el contenido del archivo.');
      return;
    }

    setState(() => _importando = true);
    try {
      final r = PersonalImporter.leer(bytes);
      if (!mounted) return;
      if (r.vacio) {
        await _dialogo('No se encontraron datos', _textoSinDatos(r));
      } else {
        _p.aplicarImportacion(r);
        _sincronizar();
        await _dialogo('Importación completada', _textoResumen(r));
      }
    } catch (e) {
      if (!mounted) return;
      await _dialogo(
        'No se pudo leer el archivo',
        'Verifica que sea un archivo .xlsx válido (los .xls antiguos no son compatibles; guárdalo como .xlsx desde Excel).\n\nDetalle: $e',
      );
    } finally {
      if (mounted) setState(() => _importando = false);
    }
  }

  String _textoSinDatos(ResultadoImportacionPersonal r) {
    final b = StringBuffer(
        'No se encontraron datos de presupuesto personal en el archivo.\n\nRevisa que tenga el registro de movimientos (con las columnas Tipo de movimiento, Categoría y Monto), los datos de la meta o el presupuesto proyectado.');
    if (r.celdasConFormula > 0) {
      b.write(
          '\n\nSe encontraron celdas con fórmulas, que no se leen. Copia y pega como valores.');
    }
    return b.toString();
  }

  String _textoResumen(ResultadoImportacionPersonal r) {
    final b = StringBuffer('Se importó:');
    if (r.hayDatosGenerales) {
      b.write('\n• Datos y meta del estudiante');
    }
    if (r.movimientos.isNotEmpty) {
      b.write('\n• Registro semanal: ${r.movimientos.length} movimientos');
    }
    if (r.hayProyeccion) {
      b.write(
          '\n• Presupuesto proyectado: ${r.lineas.length} categorías');
    }
    b.write(
        '\n\nSe reemplazaron los datos que venían en el archivo; lo demás se conservó.');
    if (r.filasOmitidas > 0) {
      b.write(
          '\n\nSe omitieron ${r.filasOmitidas} filas del registro sin un tipo de movimiento válido (Ingreso, Gasto, Ahorro o Reserva) o sin monto.');
    }
    if (r.celdasConFormula > 0) {
      b.write(
          '\n\nAlgunas celdas tenían fórmulas y no se leen; si faltan valores, copia y pega como valores en Excel y vuelve a importar.');
    }
    if (r.hojasIgnoradas.isNotEmpty) {
      b.write(
          '\n\nHojas sin datos de presupuesto (se ignoraron): ${r.hojasIgnoradas.join(', ')}. Los totales y el seguimiento se calculan aquí a partir del registro.');
    }
    return b.toString();
  }

  Future<void> _mostrarFormato() {
    return _dialogo(
      'Formato del archivo Excel',
      'Archivo .xlsx con el formato de la plantilla "Mi control de presupuesto estudiantil". No importa el nombre de las hojas; se buscan por sus títulos:\n\n'
      '• Datos y meta: filas con "Nombre", "Meta al final del semestre", "Costo de la meta", "Duración del seguimiento (semanas)" e "Inicio del seguimiento (lunes)", con el valor en la celda de la derecha.\n\n'
      '• Registro semanal: una tabla con las columnas Fecha, Semana, Tipo de movimiento (Ingreso, Gasto, Ahorro o Reserva), Categoría, Descripción, Monto, Prioridad, Medio y Observación. Los montos van en positivo. Si falta la semana se calcula con la fecha.\n\n'
      '• Presupuesto proyectado: filas "Tipo de proyección", "Ingreso mensual o semanal disponible" y "Frecuencia", y una tabla con Categoría, Monto planificado, Tipo y Comentario.\n\n'
      '• Los totales y el seguimiento semanal no se importan: se calculan aquí.\n\n'
      '• Las celdas con fórmulas no se leen: copia y pega como valores antes de importar.',
    );
  }

  Future<void> _dialogo(String titulo, String contenido) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: SingleChildScrollView(child: Text(contenido)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  // -------------------------------------------------------------- movimientos

  Future<void> _elegirFecha({required bool inicio}) async {
    final actual = inicio ? _p.fechaInicio : _fecha;
    final f = await showDatePicker(
      context: context,
      initialDate: actual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (f == null || !mounted) return;
    if (inicio) {
      _p.setFechaInicio(f);
    } else {
      setState(() => _fecha = f);
    }
  }

  void _cambiarTipo(TipoMov t) {
    setState(() {
      _tipo = t;
      // Categoría y prioridad habituales para cada tipo
      switch (t) {
        case TipoMov.ingreso:
          _categoria = 'Apoyo familiar';
        case TipoMov.gasto:
          _categoria = 'Transporte';
          _prioridad = 'Necesidad';
        case TipoMov.ahorro:
          _categoria = 'Meta de ahorro';
          _prioridad = 'Meta';
        case TipoMov.reserva:
          _categoria = 'Reserva imprevistos';
          _prioridad = 'Necesidad';
      }
    });
  }

  void _agregarMovimiento() {
    final monto = parseMonto(_monto.text);
    if (monto == null || monto <= 0) {
      _mensaje('Escribe un monto mayor que cero (siempre en positivo).');
      return;
    }
    _p.agregarMovimiento(
      fecha: _fecha,
      tipo: _tipo,
      categoria: _categoria,
      monto: monto,
      descripcion: _descripcion.text,
      prioridad: _prioridad,
      medio: _medio,
      observacion: _observacion.text,
    );
    _monto.clear();
    _descripcion.clear();
    _observacion.clear();
    setState(() => _errorIa = null);
  }

  Future<void> _nuevaCategoria() async {
    final c = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Nombre', border: OutlineInputBorder()),
          onSubmitted: (t) => Navigator.of(ctx).pop(t),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(c.text),
              child: const Text('Agregar')),
        ],
      ),
    );
    c.dispose();
    if (nombre == null || nombre.trim().isEmpty || !mounted) return;
    _p.agregarCategoria(nombre);
    setState(() => _categoria = nombre.trim());
  }

  Future<void> _borrarMovimientos() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar movimientos'),
        content: const Text(
            'Se eliminarán todos los movimientos del registro. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Borrar')),
        ],
      ),
    );
    if (ok == true) _p.borrarMovimientos();
  }

  // --------------------------------------------------------------------- IA

  Future<void> _generarIa() async {
    if (!_p.hayMovimientos) {
      setState(() =>
          _errorIa = 'Primero registra al menos un movimiento o importa tu Excel.');
      return;
    }
    final resumen = _p.resumenParaIa();
    setState(() {
      _cargandoIa = true;
      _errorIa = null;
    });
    try {
      final texto = await _ia.interpretar(
        enfoque: 'Presupuesto personal de un estudiante: ingresos, gastos, ahorro para una meta y reserva',
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

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _p,
      builder: (context, _) {
        final r = _p.calcular();
        final textoVisible =
            (_textoIa != null && _resumenIa == _p.resumenParaIa()) ? _textoIa : null;

        return PageScaffold(
          title: 'Presupuesto personal',
          subtitle:
              'Registra tus movimientos de lunes a domingo, sigue tu ahorro hacia una meta y compara lo planificado con lo real.',
          children: [
            const InfoBox(
              text:
                  'Registrar → revisar → ajustar → avanzar hacia la meta. Escribe los montos siempre en positivo; el tipo (ingreso, gasto, ahorro o reserva) decide cómo se suman.',
            ),
            _importar(),
            _datosMeta(),
            _resultados(r),
            _registrar(),
            _movimientos(),
            _seguimiento(r),
            _distribucion(r),
            _proyectado(),
            _comparacion(r),
            _interpretacion(r, textoVisible),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------- secciones

  Widget _importar() {
    return SectionCard(
      title: 'Importar desde Excel',
      icon: Icons.upload_file,
      subtitle:
          'Carga tu control de presupuesto desde un archivo .xlsx con el formato de la plantilla. También puedes escribir todo a mano abajo.',
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: _importando ? null : _importarExcel,
            icon: _importando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.table_view),
            label:
                Text(_importando ? 'Leyendo archivo…' : 'Importar archivo Excel'),
          ),
          TextButton.icon(
            onPressed: _mostrarFormato,
            icon: const Icon(Icons.help_outline),
            label: const Text('¿Qué formato debe tener?'),
          ),
        ],
      ),
    );
  }

  Widget _datosMeta() {
    final fin = _p.fechaFin;
    return SectionCard(
      title: 'Datos y meta',
      icon: Icons.flag_outlined,
      child: SpacedColumn(
        gap: 12,
        children: [
          ResponsiveGrid(
            minColumnWidth: 240,
            children: [
              TextFieldBox(
                label: 'Nombre',
                controller: _nombre,
                onChanged: _p.setNombre,
              ),
              TextFieldBox(
                label: 'Meta al final del semestre',
                hint: 'Ej.: compra de materiales y útiles',
                controller: _meta,
                onChanged: _p.setMeta,
              ),
              NumberField(
                label: 'Costo de la meta',
                prefix: 'C\$ ',
                controller: _costo,
                onChanged: (t) => _p.setCostoMeta((parseMonto(t) ?? 0).abs()),
              ),
              NumberField(
                label: 'Duración del seguimiento',
                suffix: 'semanas',
                controller: _semanas,
                onChanged: (t) =>
                    _p.setSemanas((parseMonto(t) ?? 0).abs().round()),
              ),
            ],
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _elegirFecha(inicio: true),
                icon: const Icon(Icons.event),
                label: Text('Inicio (lunes): ${fechaTexto(_p.fechaInicio)}'),
              ),
              Text(fin == null
                  ? 'Indica la duración para ver el final del seguimiento.'
                  : 'Final (domingo): ${fechaTexto(fin)}'),
            ],
          ),
          if (_p.fechaInicio.weekday != DateTime.monday)
            const InfoBox(
              icon: Icons.warning_amber_outlined,
              text:
                  'La fecha de inicio no es lunes: las semanas del seguimiento no coincidirán con lunes a domingo.',
            ),
        ],
      ),
    );
  }

  Widget _resultados(ResumenPersonal r) {
    String c(double v) => formatoMonto(v);
    final avance = _p.avanceMeta(r);

    return SectionCard(
      title: 'Resultados',
      icon: Icons.calculate_outlined,
      child: SpacedColumn(
        gap: 14,
        children: [
          ResponsiveGrid(
            minColumnWidth: 220,
            children: [
              ResultTile(label: 'Total de ingresos', unit: 'C\$', value: c(r.ingresos)),
              ResultTile(label: 'Total de gastos', unit: 'C\$', value: c(r.gastos)),
              ResultTile(
                label: 'Ahorro para la meta',
                unit: 'C\$',
                value: c(r.ahorro),
                detail: avance == null
                    ? 'Define el costo de la meta'
                    : 'Faltan C\$ ${c((_p.costoMeta - r.ahorro).clamp(0, double.infinity).toDouble())}',
              ),
              ResultTile(label: 'Reserva acumulada', unit: 'C\$', value: c(r.reserva)),
              ResultTile(
                label: 'Saldo disponible',
                unit: 'C\$',
                value: c(r.saldo),
                detail: 'Ingresos − Gastos − Ahorro − Reserva',
              ),
              ResultTile(
                label: 'Avance de la meta',
                unit: '%',
                value: avance == null ? '—' : (avance * 100).toStringAsFixed(1),
              ),
              ResultTile(
                label: 'Aporte semanal recomendado',
                unit: 'C\$',
                value: c(_p.aporteSemanal),
                detail: 'Costo de la meta / Duración',
              ),
              ResultTile(
                label: 'Ahorro promedio por semana',
                unit: 'C\$',
                value: c(_p.ahorroPromedioSemanal(r)),
                detail: '${r.semanasConRegistro} semanas con registro',
              ),
            ],
          ),
          if (avance != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: avance.clamp(0.0, 1.0),
                minHeight: 10,
              ),
            ),
          if (r.movimientosFuera > 0)
            InfoBox(
              icon: Icons.warning_amber_outlined,
              text:
                  '${r.movimientosFuera} movimientos tienen una semana menor que 1 (anterior al inicio del seguimiento) y no se suman.',
            ),
          if (_p.semanas > 0 && r.semanas.length > _p.semanas)
            InfoBox(
              icon: Icons.info_outline,
              text:
                  'Hay movimientos después de la semana ${_p.semanas}; el seguimiento se extiende hasta la semana ${r.semanas.length}.',
            ),
        ],
      ),
    );
  }

  Widget _registrar() {
    final semana = _p.semanaDe(_fecha);
    final categorias = _p.categorias;
    if (!categorias.contains(_categoria)) _categoria = categorias.first;

    return SectionCard(
      title: 'Registrar movimiento',
      icon: Icons.add_circle_outline,
      subtitle: 'Anota cada ingreso, gasto, ahorro o reserva el día que ocurre.',
      child: SpacedColumn(
        gap: 12,
        children: [
          SegmentedButton<TipoMov>(
            showSelectedIcon: false,
            segments: [
              for (final t in TipoMov.values)
                ButtonSegment(value: t, label: Text(t.etiqueta)),
            ],
            selected: {_tipo},
            onSelectionChanged: (s) => _cambiarTipo(s.first),
          ),
          ResponsiveGrid(
            minColumnWidth: 200,
            children: [
              InkWell(
                onTap: () => _elegirFecha(inicio: false),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fecha',
                    helperText: semana < 1
                        ? 'Antes del inicio del seguimiento'
                        : 'Semana $semana',
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.event, size: 18),
                  ),
                  child: Text(fechaTexto(_fecha)),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _categoria,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Categoría', border: OutlineInputBorder()),
                      items: [
                        for (final c in categorias)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _categoria = v);
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Nueva categoría',
                    icon: const Icon(Icons.add),
                    onPressed: _nuevaCategoria,
                  ),
                ],
              ),
              TextFieldBox(label: 'Descripción', controller: _descripcion),
              NumberField(label: 'Monto', prefix: 'C\$ ', controller: _monto),
              DropdownButtonFormField<String>(
                value: _prioridad,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Prioridad', border: OutlineInputBorder()),
                items: [
                  for (final p in prioridades)
                    DropdownMenuItem(value: p, child: Text(p)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _prioridad = v);
                },
              ),
              DropdownButtonFormField<String>(
                value: _medio,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Medio', border: OutlineInputBorder()),
                items: [
                  for (final m in medios)
                    DropdownMenuItem(value: m, child: Text(m)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _medio = v);
                },
              ),
              TextFieldBox(label: 'Observación (opcional)', controller: _observacion),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _agregarMovimiento,
              icon: const Icon(Icons.add),
              label: const Text('Agregar movimiento'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _movimientos() {
    final todos = _p.movimientos.reversed.toList(); // los últimos primero
    const limite = 15;
    final visibles = _verTodos ? todos : todos.take(limite).toList();

    return SectionCard(
      title: 'Registro semanal',
      icon: Icons.list_alt_outlined,
      subtitle: todos.isEmpty
          ? null
          : '${todos.length} movimientos${todos.length > limite && !_verTodos ? ' · se muestran los últimos $limite' : ''}',
      child: todos.isEmpty
          ? const Text(
              'Aún no hay movimientos. Regístralos arriba o importa tu archivo Excel.')
          : SpacedColumn(
              gap: 10,
              children: [
                TablaMovimientos(
                  movimientos: visibles,
                  onEliminar: _p.eliminarMovimiento,
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    if (todos.length > limite)
                      TextButton.icon(
                        onPressed: () => setState(() => _verTodos = !_verTodos),
                        icon: Icon(
                            _verTodos ? Icons.expand_less : Icons.expand_more),
                        label: Text(_verTodos ? 'Ver menos' : 'Ver todos'),
                      ),
                    TextButton.icon(
                      onPressed: _borrarMovimientos,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text('Borrar todos'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _seguimiento(ResumenPersonal r) {
    return SectionCard(
      title: 'Seguimiento semanal',
      icon: Icons.date_range_outlined,
      subtitle:
          'Cada corte va de lunes a domingo. Cuatro semanas forman un mes presupuestario.',
      child: r.semanas.isEmpty
          ? const Text(
              'Indica la duración del seguimiento o registra movimientos para ver las semanas.')
          : TablaSeguimiento(semanas: r.semanas, costoMeta: _p.costoMeta),
    );
  }

  Widget _distribucion(ResumenPersonal r) {
    return SectionCard(
      title: 'Distribución de gastos',
      icon: Icons.pie_chart_outline,
      child: r.gastos == 0
          ? const Text('Todavía no hay gastos registrados.')
          : SpacedColumn(
              gap: 16,
              children: [
                BarrasDistribucion(items: r.gastosPorCategoria, total: r.gastos),
                const Divider(height: 1),
                BarrasDistribucion(
                  items: [
                    MapEntry('Necesidades', r.gastoNecesidad),
                    MapEntry('Deseos', r.gastoDeseo),
                    if (r.gastoOtraPrioridad > 0)
                      MapEntry('Sin prioridad', r.gastoOtraPrioridad),
                  ],
                  total: r.gastos,
                ),
              ],
            ),
    );
  }

  Widget _proyectado() {
    final pct = _p.pctAsignado;
    final dif = _p.diferenciaProyeccion;
    return SectionCard(
      title: 'Presupuesto proyectado',
      icon: Icons.account_tree_outlined,
      subtitle:
          'Distribuye el dinero que realmente recibes o el que necesitarías. Los porcentajes sirven para analizar; no obligan a gastar más si aumenta el ingreso.',
      child: SpacedColumn(
        gap: 14,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  for (final t in tiposProyeccion)
                    ButtonSegment(value: t, label: Text(t)),
                ],
                selected: {_p.tipoProyeccion},
                onSelectionChanged: (s) => _p.setTipoProyeccion(s.first),
              ),
              SegmentedButton<Frecuencia>(
                showSelectedIcon: false,
                segments: [
                  for (final f in Frecuencia.values)
                    ButtonSegment(value: f, label: Text(f.etiqueta)),
                ],
                selected: {_p.frecuencia},
                onSelectionChanged: (s) => _p.setFrecuencia(s.first),
              ),
              SizedBox(
                width: 240,
                child: NumberField(
                  label: 'Ingreso disponible (${_p.frecuencia.etiqueta.toLowerCase()})',
                  prefix: 'C\$ ',
                  controller: _ingresoProy,
                  onChanged: (t) =>
                      _p.setIngresoProyectado((parseMonto(t) ?? 0).abs()),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final l in _p.lineas)
                FilaProyeccionEditable(
                  key: ValueKey(l.id),
                  controller: _p,
                  linea: l,
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _p.agregarLinea,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar categoría'),
                ),
              ),
            ],
          ),
          ResponsiveGrid(
            minColumnWidth: 200,
            children: [
              ResultTile(
                label: 'Total asignado',
                unit: 'C\$',
                value: formatoMonto(_p.totalAsignado),
                detail: pct == null
                    ? 'Escribe el ingreso disponible'
                    : '${(pct * 100).toStringAsFixed(1)} % del ingreso',
              ),
              ResultTile(
                label: 'Diferencia',
                unit: 'C\$',
                value: formatoMonto(dif),
                detail: 'Ingreso − Total asignado',
              ),
              ResultTile(label: 'Estado', value: _p.estadoProyeccion),
              ResultTile(
                label: 'Ahorro proyectado',
                unit: 'C\$',
                value: formatoMonto(_p.ahorroProyectado),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _comparacion(ResumenPersonal r) {
    final filas = _p.comparar(r);
    return SectionCard(
      title: 'Proyectado vs. real',
      icon: Icons.compare_arrows,
      subtitle:
          'Promedio por semana con registro frente a lo planificado (si el presupuesto es mensual, se divide entre 4).',
      child: filas.isEmpty
          ? const Text(
              'Completa el presupuesto proyectado y registra movimientos para compararlos.')
          : TablaComparacion(filas: filas),
    );
  }

  Widget _interpretacion(ResumenPersonal r, String? textoIa) {
    final puntos = _p.lectura(r);
    return SpacedColumn(
      children: [
        SectionCard(
          title: 'Interpretación',
          icon: Icons.lightbulb_outline,
          subtitle: 'Lectura basada en reglas simples; no necesita conexión a la IA.',
          child: puntos.isEmpty
              ? const Text(
                  'Aquí aparecerá la lectura de tu presupuesto cuando registres movimientos.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final t in puntos)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2, right: 8),
                              child: Icon(Icons.chevron_right, size: 18),
                            ),
                            Expanded(child: Text(t)),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        IaPanel(
          config: _iaConfig,
          onGenerar: _generarIa,
          resultado: textoIa,
          error: _errorIa,
          cargando: _cargandoIa,
          puedeGenerar: true,
        ),
      ],
    );
  }
}
