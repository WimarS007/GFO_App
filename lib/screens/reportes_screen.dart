import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../reportes/guardar_archivo.dart';
import '../reportes/reporte_builder.dart';
import '../reportes/reporte_excel.dart';
import '../reportes/reporte_pdf.dart';
import '../widgets/common.dart';

enum _Formato { pdf, excel }

/// Módulo «Generar reporte»: la persona elige qué secciones incluir y si lo
/// quiere en PDF o en Excel.
class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key, required this.constructor});

  final ConstructorReporte constructor;

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  late final Set<SeccionId> _seleccion = {...SeccionId.values};
  _Formato _formato = _Formato.pdf;
  bool _generando = false;

  ConstructorReporte get _c => widget.constructor;

  /// Pantalla que se actualiza cuando cambian los datos de cualquier módulo
  /// (para que el aviso «Sin datos» esté al día).
  Listenable get _datos => Listenable.merge([
        _c.estados,
        _c.flujo,
        _c.presupuestos,
        _c.personal,
        _c.inventario,
      ]);

  void _seleccionarConDatos() => setState(() {
        _seleccion
          ..clear()
          ..addAll(SeccionId.values.where(_c.tieneDatos));
      });

  Future<void> _generar() async {
    if (_seleccion.isEmpty || _generando) return;
    final mensajes = ScaffoldMessenger.of(context);
    setState(() => _generando = true);

    // Deja pintar el indicador de progreso antes del trabajo pesado.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    try {
      final reporte = _c.construir(_seleccion);
      final Uint8List bytes;
      final String extension;
      if (_formato == _Formato.pdf) {
        bytes = await generarPdf(reporte);
        extension = 'pdf';
      } else {
        bytes = generarExcel(reporte);
        extension = 'xlsx';
      }

      final ruta = await guardarArchivo(
        nombre: reporte.nombreArchivo,
        extension: extension,
        bytes: bytes,
      );
      mensajes.showSnackBar(SnackBar(
        content: Text(ruta == null
            ? 'Se canceló el guardado.'
            : 'Reporte guardado: $ruta'),
      ));
    } catch (e) {
      mensajes.showSnackBar(SnackBar(
        content: Text('No se pudo generar el reporte: $e'),
        duration: const Duration(seconds: 6),
      ));
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  static IconData _icono(SeccionId id) {
    switch (id) {
      case SeccionId.estados:
        return Icons.account_balance_outlined;
      case SeccionId.analisis:
        return Icons.analytics_outlined;
      case SeccionId.cvu:
        return Icons.show_chart;
      case SeccionId.apalancamiento:
        return Icons.compare_arrows;
      case SeccionId.flujo:
        return Icons.currency_exchange;
      case SeccionId.presupuestos:
        return Icons.event_note_outlined;
      case SeccionId.personal:
        return Icons.savings_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _datos,
      builder: (context, _) {
        final theme = Theme.of(context);
        final sinDatos = _seleccion.where((s) => !_c.tieneDatos(s)).toList();

        return PageScaffold(
          title: 'Generar reporte',
          subtitle:
              'Elige qué incluir y descárgalo en PDF o en Excel con los datos actuales de la app.',
          children: [
            SectionCard(
              title: 'Contenido del reporte',
              icon: Icons.checklist,
              subtitle: '${_seleccion.length} de ${SeccionId.values.length} '
                  'secciones seleccionadas',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => setState(() =>
                            _seleccion.addAll(SeccionId.values)),
                        child: const Text('Todas'),
                      ),
                      OutlinedButton(
                        onPressed: _seleccionarConDatos,
                        child: const Text('Solo las que tienen datos'),
                      ),
                      OutlinedButton(
                        onPressed: () => setState(_seleccion.clear),
                        child: const Text('Ninguna'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final id in SeccionId.values)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _seleccion.contains(id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _seleccion.add(id);
                        } else {
                          _seleccion.remove(id);
                        }
                      }),
                      secondary: Icon(_icono(id)),
                      title: Row(
                        children: [
                          Flexible(child: Text(id.titulo)),
                          if (!_c.tieneDatos(id)) ...[
                            const SizedBox(width: 8),
                            Chip(
                              label: const Text('Sin datos'),
                              visualDensity: VisualDensity.compact,
                              labelStyle: theme.textTheme.labelSmall,
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(id.descripcion),
                    ),
                ],
              ),
            ),
            SectionCard(
              title: 'Formato de salida',
              icon: Icons.description_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<_Formato>(
                    segments: const [
                      ButtonSegment(
                        value: _Formato.pdf,
                        icon: Icon(Icons.picture_as_pdf_outlined),
                        label: Text('PDF'),
                      ),
                      ButtonSegment(
                        value: _Formato.excel,
                        icon: Icon(Icons.table_view_outlined),
                        label: Text('Excel'),
                      ),
                    ],
                    selected: {_formato},
                    onSelectionChanged: (s) =>
                        setState(() => _formato = s.first),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formato == _Formato.pdf
                        ? 'Documento con portada y tablas con formato, listo para leer, imprimir o enviar.'
                        : 'Libro de Excel (.xlsx) con una hoja por sección. Los montos son números, así que puedes sumarlos, filtrarlos o graficarlos.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (sinDatos.isNotEmpty)
              InfoBox(
                text:
                    'Estas secciones no tienen datos y saldrán con un aviso: ${sinDatos.map((s) => s.titulo).join(', ')}.',
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed:
                    (_seleccion.isEmpty || _generando) ? null : _generar,
                icon: _generando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_formato == _Formato.pdf
                        ? Icons.picture_as_pdf_outlined
                        : Icons.table_view_outlined),
                label: Text(_generando
                    ? 'Generando…'
                    : 'Generar ${_formato == _Formato.pdf ? 'PDF' : 'Excel'}'),
              ),
            ),
          ],
        );
      },
    );
  }
}
