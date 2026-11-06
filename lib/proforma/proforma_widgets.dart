import 'package:flutter/material.dart';

import '../estados/montos.dart';
import 'proforma_calculos.dart';

/// Texto de una variación porcentual: "+12.5 %", "−3.0 %" o "—".
String textoVariacion(double? pct) {
  if (pct == null) return '—';
  final signo = pct > 0 ? '+' : '';
  return '$signo${pct.toStringAsFixed(1)} %';
}

/// Tabla Actual / Proyectado / Variación para el estado de resultados y el balance.
class TablaProforma extends StatelessWidget {
  const TablaProforma({
    super.key,
    required this.filas,
    required this.etiquetaActual,
  });

  final List<FilaProforma> filas;
  final String etiquetaActual;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('Concepto')),
          DataColumn(label: Text('Actual\n($etiquetaActual)'), numeric: true),
          const DataColumn(label: Text('Proyectado'), numeric: true),
          const DataColumn(label: Text('Variación (C\$)'), numeric: true),
          const DataColumn(label: Text('Variación (%)'), numeric: true),
        ],
        rows: [
          for (final f in filas)
            DataRow(
              cells: [
                DataCell(Text(f.nombre, style: _estilo(f.total))),
                DataCell(Text(formatoMonto(f.actual), style: _estilo(f.total))),
                DataCell(
                    Text(formatoMonto(f.proyectado), style: _estilo(f.total))),
                DataCell(
                    Text(formatoMonto(f.variacion), style: _estilo(f.total))),
                DataCell(Text(textoVariacion(f.variacionPct),
                    style: _estilo(f.total))),
              ],
            ),
        ],
      ),
    );
  }

  static TextStyle? _estilo(bool total) =>
      total ? const TextStyle(fontWeight: FontWeight.bold) : null;
}

/// Tabla de sensibilidad: utilidad neta según crecimiento de ventas (filas)
/// y variación de costos (columnas). Resalta la combinación base.
class TablaSensibilidad extends StatelessWidget {
  const TablaSensibilidad({
    super.key,
    required this.etiquetasFilas,
    required this.etiquetasColumnas,
    required this.valores,
    required this.filaBase,
    required this.columnaBase,
  });

  final List<String> etiquetasFilas;
  final List<String> etiquetasColumnas;

  /// valores[fila][columna]; null cuando no se puede calcular.
  final List<List<double?>> valores;
  final int filaBase;
  final int columnaBase;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('Crecimiento de ventas')),
          for (final c in etiquetasColumnas)
            DataColumn(label: Text(c), numeric: true),
        ],
        rows: [
          for (var i = 0; i < etiquetasFilas.length; i++)
            DataRow(
              cells: [
                DataCell(Text(
                  etiquetasFilas[i],
                  style: i == filaBase
                      ? const TextStyle(fontWeight: FontWeight.bold)
                      : null,
                )),
                for (var j = 0; j < etiquetasColumnas.length; j++)
                  DataCell(
                    _celda(valores[i][j], i == filaBase && j == columnaBase, cs),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static Widget _celda(double? v, bool base, ColorScheme cs) {
    final texto = v == null ? '—' : formatoMonto(v);
    final color = (v != null && v < 0) ? cs.error : null;
    final contenido = Text(
      texto,
      style: TextStyle(
        color: color,
        fontWeight: base ? FontWeight.bold : null,
      ),
    );
    if (!base) return contenido;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: contenido,
    );
  }
}
