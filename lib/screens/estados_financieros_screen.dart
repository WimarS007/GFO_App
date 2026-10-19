import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../estados/estados_controller.dart';
import '../estados/estados_models.dart';
import '../estados/estados_widgets.dart';
import '../estados/excel_importer.dart';
import '../widgets/common.dart';

class EstadosFinancierosScreen extends StatefulWidget {
  const EstadosFinancierosScreen({super.key, required this.controller});

  /// Controlador compartido con otros módulos (p. ej. Análisis financiero).
  final EstadosController controller;

  @override
  State<EstadosFinancierosScreen> createState() =>
      _EstadosFinancierosScreenState();
}

class _EstadosFinancierosScreenState extends State<EstadosFinancierosScreen> {
  EstadosController get _c => widget.controller;
  final _empresa = TextEditingController();
  final _anterior = TextEditingController();
  final _actual = TextEditingController();
  bool _importando = false;

  @override
  void dispose() {
    _empresa.dispose();
    _anterior.dispose();
    _actual.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- importar

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
      final r = ExcelImporter.leer(bytes);
      if (!mounted) return;
      if (r.vacio) {
        await _dialogo(
          'No se encontraron cuentas',
          _textoSinCuentas(r),
        );
      } else {
        _c.aplicarImportacion(r);
        _anterior.text = _c.periodoTexto(Periodo.anterior);
        _actual.text = _c.periodoTexto(Periodo.actual);
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

  String _textoSinCuentas(ResultadoImportacion r) {
    final b = StringBuffer(
        'No se encontraron filas con nombre de cuenta y valores numéricos.');
    if (r.hojasIgnoradas.isNotEmpty) {
      b.write(
          '\n\nHojas que no se reconocieron como Balance General ni Estado de Resultados: ${r.hojasIgnoradas.join(', ')}. Renombra la hoja (por ejemplo "Balance General" o "Estado de Resultados") e inténtalo de nuevo.');
    }
    if (r.celdasConFormula > 0) {
      b.write(
          '\n\nSe encontraron celdas con fórmulas, que no se leen. Copia y pega como valores.');
    }
    return b.toString();
  }

  String _textoResumen(ResultadoImportacion r) {
    final b = StringBuffer('Se importaron ${r.cuentas.length} cuentas:');
    if (r.estados.contains(Estado.balance)) {
      b.write('\n• Balance General: ${r.cuentasDe(Estado.balance)}');
    }
    if (r.estados.contains(Estado.resultados)) {
      b.write('\n• Estado de Resultados: ${r.cuentasDe(Estado.resultados)}');
    }
    b.write(
        '\n\nSe reemplazaron las cuentas de los estados que venían en el archivo.');
    if (r.sinClasificar.isNotEmpty) {
      b.write(
          '\n\nEstas cuentas no se pudieron clasificar y se colocaron en el primer grupo por defecto (Activos corrientes o Gastos de operación). Revísalas y muévelas con el botón de carpeta de cada fila:\n- ${r.sinClasificar.join('\n- ')}');
    }
    if (r.celdasConFormula > 0) {
      b.write(
          '\n\nAlgunas celdas tenían fórmulas y no se leen; si faltan valores, copia y pega como valores en Excel y vuelve a importar.');
    }
    if (r.hojasIgnoradas.isNotEmpty) {
      b.write('\n\nHojas ignoradas: ${r.hojasIgnoradas.join(', ')}.');
    }
    return b.toString();
  }

  Future<void> _mostrarFormato() {
    return _dialogo(
      'Formato del archivo Excel',
      'Archivo .xlsx. Puede tener una hoja para el Balance General y otra para el Estado de Resultados (nómbralas así), o ambos en la misma hoja.\n\n'
      '• Columna A: nombre de la cuenta. Las siguientes columnas: valores del período anterior y del período actual.\n\n'
      '• Si hay una fila de encabezado con "Anterior" y "Actual", o con dos años (por ejemplo 2024 y 2025), se usa para saber qué columna es cada período. Si no hay encabezado, la primera columna con números es el período anterior y la segunda el actual.\n\n'
      '• Para clasificar las cuentas puedes poner títulos de grupo en filas aparte: Activos corrientes, Activos no corrientes, Pasivos corrientes, Pasivos no corrientes y Patrimonio. Si no los pones, se intenta clasificar por el nombre de la cuenta.\n\n'
      '• Las filas de totales (Total activos, Utilidad neta, etc.) se omiten porque el sistema las calcula.\n\n'
      '• Costos y gastos van como valores positivos.\n\n'
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

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => PageScaffold(
        title: 'Estados financieros',
        subtitle:
            'Registra el Balance General y el Estado de Resultados. Estos datos alimentan los demás módulos.',
        children: [
          _datosGenerales(),
          _importar(),
          TabSwitcher(
            labels: const ['Balance General', 'Estado de Resultados'],
            pages: [_balance(), _resultados()],
          ),
        ],
      ),
    );
  }

  Widget _datosGenerales() {
    return SectionCard(
      title: 'Datos generales',
      icon: Icons.business,
      child: ResponsiveGrid(
        minColumnWidth: 220,
        children: [
          TextField(
            controller: _empresa,
            decoration: const InputDecoration(
              labelText: 'Nombre de la empresa',
              border: OutlineInputBorder(),
            ),
            onChanged: (t) => _c.empresa = t,
          ),
          TextField(
            controller: _anterior,
            decoration: const InputDecoration(
              labelText: 'Período anterior',
              hintText: 'Ej. 2024',
              border: OutlineInputBorder(),
            ),
            onChanged: (t) => _c.setPeriodo(Periodo.anterior, t),
          ),
          TextField(
            controller: _actual,
            decoration: const InputDecoration(
              labelText: 'Período actual',
              hintText: 'Ej. 2025',
              border: OutlineInputBorder(),
            ),
            onChanged: (t) => _c.setPeriodo(Periodo.actual, t),
          ),
        ],
      ),
    );
  }

  Widget _importar() {
    return SectionCard(
      title: 'Importar desde Excel',
      icon: Icons.upload_file,
      subtitle:
          'Carga tus estados desde un archivo .xlsx. También puedes escribirlos o corregirlos a mano abajo.',
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
            label: Text(_importando ? 'Leyendo archivo…' : 'Importar archivo Excel'),
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

  // -------------------------------------------------------- Balance General

  Widget _balance() {
    final ant = Periodo.anterior;
    final act = Periodo.actual;

    return SpacedColumn(
      children: [
        const InfoBox(
          text:
              'Escribe los saldos en córdobas (C\$). Usa «Agregar cuenta» para añadir las que necesites y el botón de carpeta para pasar una cuenta a otro grupo.',
        ),
        for (final g in Grupo.deEstado(Estado.balance))
          GrupoSection(controller: _c, grupo: g),
        SectionCard(
          title: 'Resumen del Balance General',
          icon: Icons.fact_check_outlined,
          child: SpacedColumn(
            children: [
              ResumenTabla(
                etiquetaAnterior: _c.etiqueta(ant),
                etiquetaActual: _c.etiqueta(act),
                filas: [
                  FilaResumen('Total activos corrientes',
                      _c.totalActivosCorrientes(ant), _c.totalActivosCorrientes(act)),
                  FilaResumen('Total activos', _c.totalActivos(ant),
                      _c.totalActivos(act),
                      destacada: true),
                  FilaResumen('Total pasivos corrientes',
                      _c.totalPasivosCorrientes(ant), _c.totalPasivosCorrientes(act)),
                  FilaResumen('Total pasivos', _c.totalPasivos(ant),
                      _c.totalPasivos(act),
                      destacada: true),
                  FilaResumen('Total patrimonio', _c.totalPatrimonio(ant),
                      _c.totalPatrimonio(act),
                      destacada: true),
                  FilaResumen('Pasivo + Patrimonio', _c.pasivoMasPatrimonio(ant),
                      _c.pasivoMasPatrimonio(act)),
                  FilaResumen('Diferencia (Activo − Pasivo − Patrimonio)',
                      _c.diferenciaBalance(ant), _c.diferenciaBalance(act)),
                ],
              ),
              for (final p in Periodo.values)
                if (_c.hayDatos(p, Estado.balance))
                  CuadreBalance(
                    etiqueta: _c.etiqueta(p),
                    diferencia: _c.diferenciaBalance(p),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------- Estado de Resultados

  Widget _resultados() {
    final ant = Periodo.anterior;
    final act = Periodo.actual;

    return SpacedColumn(
      children: [
        const InfoBox(
          text:
              'Escribe los costos y gastos como valores positivos; el sistema los resta automáticamente. Puedes agregar todas las cuentas que necesites en cada grupo.',
        ),
        for (final g in Grupo.deEstado(Estado.resultados))
          GrupoSection(controller: _c, grupo: g),
        SectionCard(
          title: 'Resultados calculados',
          icon: Icons.calculate_outlined,
          child: ResumenTabla(
            etiquetaAnterior: _c.etiqueta(ant),
            etiquetaActual: _c.etiqueta(act),
            filas: [
              FilaResumen('Ventas netas', _c.ventasNetas(ant), _c.ventasNetas(act)),
              FilaResumen('Utilidad bruta', _c.utilidadBruta(ant),
                  _c.utilidadBruta(act),
                  destacada: true),
              FilaResumen('Utilidad de operación', _c.utilidadOperacion(ant),
                  _c.utilidadOperacion(act)),
              FilaResumen('UAII', _c.uaii(ant), _c.uaii(act), destacada: true),
              FilaResumen('Utilidad antes de impuestos',
                  _c.utilidadAntesImpuestos(ant), _c.utilidadAntesImpuestos(act)),
              FilaResumen('Utilidad neta', _c.utilidadNeta(ant),
                  _c.utilidadNeta(act),
                  destacada: true),
            ],
          ),
        ),
        const InfoBox(
          icon: Icons.functions,
          text:
              'Utilidad bruta = Ventas − Costo de ventas   ·   Utilidad de operación = Utilidad bruta − Gastos de operación   ·   UAII = Utilidad de operación + Otros ingresos − Otros gastos   ·   Utilidad antes de impuestos = UAII − Gastos financieros   ·   Utilidad neta = Utilidad antes de impuestos − Impuesto',
        ),
      ],
    );
  }
}
