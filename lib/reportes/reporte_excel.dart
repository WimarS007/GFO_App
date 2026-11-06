import 'dart:math' as math;
import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'reporte_models.dart';

final _verde = ExcelColor.fromHexString('#00695C');
final _verdeClaro = ExcelColor.fromHexString('#E0F2F1');

/// Convierte el [Reporte] en un libro de Excel (.xlsx): una hoja de resumen y
/// una hoja por sección. Los montos se guardan como números reales, así se
/// pueden sumar, filtrar o graficar.
Uint8List generarExcel(Reporte reporte) {
  final excel = Excel.createExcel();
  final hojaInicial = excel.getDefaultSheet() ?? 'Sheet1';

  // ---- Hoja de resumen
  excel.rename(hojaInicial, 'Resumen');
  final resumen = excel['Resumen'];
  var fila = 0;
  _texto(resumen, fila++, 0, reporte.titulo,
      estilo: CellStyle(bold: true, fontSize: 16, fontColorHex: _verde));
  _texto(resumen, fila++, 0, reporte.empresa,
      estilo: CellStyle(bold: true, fontSize: 12));
  _texto(resumen, fila++, 0, 'Generado el ${reporte.fechaTexto}');
  _texto(resumen, fila++, 0, 'Montos en córdobas (C\$).');
  fila++;
  _texto(resumen, fila++, 0, 'Contenido', estilo: CellStyle(bold: true));

  final usados = <String>{'Resumen'};
  final hojas = <String>[];
  for (final s in reporte.secciones) {
    hojas.add(_nombreHoja(s.titulo, usados));
  }
  for (var i = 0; i < reporte.secciones.length; i++) {
    _texto(resumen, fila++, 0, '${i + 1}. ${reporte.secciones[i].titulo}');
    _texto(resumen, fila - 1, 1, 'Hoja «${hojas[i]}»');
  }
  resumen.setColumnWidth(0, 48);
  resumen.setColumnWidth(1, 36);

  // ---- Una hoja por sección
  for (var i = 0; i < reporte.secciones.length; i++) {
    _hoja(excel[hojas[i]], reporte, reporte.secciones[i]);
  }

  final bytes = excel.encode();
  if (bytes == null) {
    throw StateError('No se pudo generar el archivo de Excel.');
  }
  return Uint8List.fromList(bytes);
}

// ------------------------------------------------------------------ hojas

void _hoja(Sheet hoja, Reporte reporte, SeccionReporte seccion) {
  var fila = 0;
  _texto(hoja, fila++, 0, seccion.titulo,
      estilo: CellStyle(bold: true, fontSize: 14, fontColorHex: _verde));
  _texto(hoja, fila++, 0, '${reporte.empresa} · ${reporte.fechaTexto}');
  fila++;

  // Ancho de cada columna según el contenido más largo.
  final anchos = <int, int>{};
  void medir(int col, String t) {
    final largo = t.length;
    if (largo > (anchos[col] ?? 0)) anchos[col] = largo;
  }

  for (final b in seccion.bloques) {
    if (b is TablaReporte) {
      if (b.titulo != null) {
        _texto(hoja, fila++, 0, b.titulo!,
            estilo: CellStyle(bold: true, fontColorHex: _verde));
      }
      if (b.filas.isEmpty) {
        _texto(hoja, fila++, 0, 'Sin registros.');
        fila++;
        continue;
      }

      // Encabezado
      for (var c = 0; c < b.columnas.length; c++) {
        medir(c, b.columnas[c]);
        _texto(
          hoja,
          fila,
          c,
          b.columnas[c],
          estilo: CellStyle(
            bold: true,
            fontColorHex: ExcelColor.white,
            backgroundColorHex: _verde,
            horizontalAlign: c == 0 ? HorizontalAlign.Left : HorizontalAlign.Center,
          ),
        );
      }
      fila++;

      // Filas
      for (final f in b.filas) {
        for (var c = 0; c < b.columnas.length; c++) {
          final celda = c < f.celdas.length ? f.celdas[c] : const Celda.vacia();
          medir(c, celda.texto);
          _celda(hoja, fila, c, celda, destacada: f.destacada);
        }
        fila++;
      }
      fila++;
    } else if (b is NotaReporte) {
      if (b.titulo != null) {
        _texto(hoja, fila++, 0, b.titulo!, estilo: CellStyle(bold: true));
      }
      for (final l in b.lineas) {
        _texto(hoja, fila++, 0, l);
      }
      fila++;
    }
  }

  for (final e in anchos.entries) {
    final minimo = e.key == 0 ? 30.0 : 14.0;
    hoja.setColumnWidth(
        e.key, math.min(60.0, math.max(minimo, e.value * 1.1 + 2)));
  }
}

// ----------------------------------------------------------------- celdas

void _texto(Sheet hoja, int fila, int col, String texto, {CellStyle? estilo}) {
  hoja.updateCell(
    CellIndex.indexByColumnRow(columnIndex: col, rowIndex: fila),
    TextCellValue(texto),
    cellStyle: estilo,
  );
}

void _celda(Sheet hoja, int fila, int col, Celda c, {required bool destacada}) {
  final negrita = destacada || c.negrita;
  final fondo = destacada ? _verdeClaro : null;
  final index = CellIndex.indexByColumnRow(columnIndex: col, rowIndex: fila);

  final numero = c.numero;
  if (numero == null) {
    hoja.updateCell(
      index,
      TextCellValue(c.texto),
      cellStyle: CellStyle(
        bold: negrita,
        backgroundColorHex: fondo ?? ExcelColor.none,
        horizontalAlign:
            c.texto == 'n/d' ? HorizontalAlign.Right : HorizontalAlign.Left,
      ),
    );
    return;
  }

  // El porcentaje llega en puntos (12.5) y Excel lo espera como fracción (0.125).
  final esPct = c.formato == FormatoNumero.porcentaje;
  final NumFormat formato;
  switch (c.formato) {
    case FormatoNumero.entero:
      formato = NumFormat.standard_3; // #,##0
      break;
    case FormatoNumero.decimal:
      formato = NumFormat.standard_2; // 0.00
      break;
    case FormatoNumero.porcentaje:
      formato = NumFormat.standard_10; // 0.00%
      break;
    default:
      formato = NumFormat.standard_4; // #,##0.00
  }

  hoja.updateCell(
    index,
    DoubleCellValue(esPct ? numero / 100 : numero),
    cellStyle: CellStyle(
      bold: negrita,
      backgroundColorHex: fondo ?? ExcelColor.none,
      horizontalAlign: HorizontalAlign.Right,
      numberFormat: formato,
    ),
  );
}

/// Nombre válido de hoja: máximo 31 caracteres, sin []:*?/\ y sin repetirse.
String _nombreHoja(String titulo, Set<String> usados) {
  var base = titulo.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
  if (base.isEmpty) base = 'Hoja';
  if (base.length > 31) base = base.substring(0, 31).trim();

  var nombre = base;
  var n = 2;
  while (usados.contains(nombre)) {
    final sufijo = ' ($n)';
    nombre = base.substring(0, math.min(base.length, 31 - sufijo.length)) + sufijo;
    n++;
  }
  usados.add(nombre);
  return nombre;
}
