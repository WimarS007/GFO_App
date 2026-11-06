import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'reporte_models.dart';

const _verde = PdfColor.fromInt(0xFF00695C);
const _verdeClaro = PdfColor.fromInt(0xFFE0F2F1);
const _gris = PdfColor.fromInt(0xFF616161);
const _borde = PdfColor.fromInt(0xFFBDBDBD);

/// Las fuentes estándar de PDF solo traen caracteres Latin-1 (tildes y ñ sí;
/// el signo «−» o las viñetas no). Se sustituyen para que no salgan cuadros.
String _limpiar(String s) {
  const reemplazos = {
    '\u2212': '-', // −
    '\u2013': '-', // –
    '\u2014': '-', // —
    '\u2018': "'",
    '\u2019': "'",
    '\u201C': '"',
    '\u201D': '"',
    '\u2026': '...',
    '\u2022': '-',
    '\u2192': '->',
    '\u2265': '>=',
    '\u2264': '<=',
  };
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    if (reemplazos.containsKey(ch)) {
      b.write(reemplazos[ch]);
    } else if (r <= 0xFF) {
      b.write(ch);
    } else {
      b.write('?');
    }
  }
  return b.toString();
}

/// Convierte el [Reporte] en un PDF listo para guardar.
Future<Uint8List> generarPdf(Reporte reporte) async {
  final doc = pw.Document(
    title: _limpiar('${reporte.titulo} - ${reporte.empresa}'),
    author: 'GFO App',
    creator: 'GFO App',
  );

  // ---- Portada
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(48),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 120),
        pw.Container(width: 60, height: 6, color: _verde),
        pw.SizedBox(height: 16),
        pw.Text(_limpiar(reporte.titulo),
            style: pw.TextStyle(
                fontSize: 30, fontWeight: pw.FontWeight.bold, color: _verde)),
        pw.SizedBox(height: 6),
        pw.Text(_limpiar(reporte.empresa), style: const pw.TextStyle(fontSize: 18)),
        pw.SizedBox(height: 4),
        pw.Text('Generado el ${reporte.fechaTexto}',
            style: const pw.TextStyle(fontSize: 11, color: _gris)),
        pw.SizedBox(height: 36),
        pw.Text('Contenido',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        for (var i = 0; i < reporte.secciones.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Text('${i + 1}. ${_limpiar(reporte.secciones[i].titulo)}',
                style: const pw.TextStyle(fontSize: 12)),
          ),
        pw.Spacer(),
        pw.Text('Montos en córdobas (C\$). Documento generado con GFO App.',
            style: const pw.TextStyle(fontSize: 9, color: _gris)),
      ],
    ),
  ));

  // ---- Una sección por bloque de páginas
  for (final s in reporte.secciones) {
    final ancho = s.bloques
        .whereType<TablaReporte>()
        .fold<int>(0, (m, t) => t.columnas.length > m ? t.columnas.length : m);
    final horizontal = ancho > 6;
    final formato =
        horizontal ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

    doc.addPage(pw.MultiPage(
      pageFormat: formato,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
      header: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 6),
        margin: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _borde, width: 0.6)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(_limpiar(reporte.empresa),
                style: const pw.TextStyle(fontSize: 9, color: _gris)),
            pw.Text(_limpiar(reporte.titulo),
                style: const pw.TextStyle(fontSize: 9, color: _gris)),
          ],
        ),
      ),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(reporte.fechaTexto,
              style: const pw.TextStyle(fontSize: 8, color: _gris)),
          pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _gris)),
        ],
      ),
      build: (ctx) => [
        pw.Text(_limpiar(s.titulo),
            style: pw.TextStyle(
                fontSize: 18, fontWeight: pw.FontWeight.bold, color: _verde)),
        pw.SizedBox(height: 4),
        for (final b in s.bloques) ..._bloque(b),
      ],
    ));
  }

  return doc.save();
}

List<pw.Widget> _bloque(Bloque b) {
  if (b is TablaReporte) return _tabla(b);
  if (b is NotaReporte) return _nota(b);
  return const [];
}

List<pw.Widget> _nota(NotaReporte n) => [
      pw.SizedBox(height: 8),
      if (n.titulo != null)
        pw.Text(_limpiar(n.titulo!),
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      for (final l in n.lineas)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(_limpiar(n.titulo == null ? l : '- $l'),
              style: const pw.TextStyle(fontSize: 9.5)),
        ),
    ];

List<pw.Widget> _tabla(TablaReporte t) {
  final titulo = t.titulo == null
      ? <pw.Widget>[]
      : [
          pw.SizedBox(height: 12),
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(_limpiar(t.titulo!),
                style: pw.TextStyle(
                    fontSize: 11.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _verde)),
          ),
        ];

  if (t.filas.isEmpty) {
    return [
      ...titulo,
      pw.Text('Sin registros.',
          style: const pw.TextStyle(fontSize: 9.5, color: _gris)),
    ];
  }

  final n = t.columnas.length;
  // Una columna es numérica si alguna de sus celdas lo es.
  final numerica = List<bool>.generate(
      n, (i) => t.filas.any((f) => i < f.celdas.length && f.celdas[i].esNumero));

  final anchos = <int, pw.TableColumnWidth>{
    for (var i = 0; i < n; i++)
      i: pw.FlexColumnWidth(numerica[i] ? 1.25 : (i == 0 ? 3.0 : 2.0)),
  };

  pw.Widget celda(String texto, int col,
      {bool negrita = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Align(
        alignment: numerica[col]
            ? pw.Alignment.centerRight
            : pw.Alignment.centerLeft,
        child: pw.Text(
          _limpiar(texto),
          textAlign: numerica[col] ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: 9,
            color: color,
            fontWeight: negrita ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );
  }

  final filas = <pw.TableRow>[
    pw.TableRow(
      repeat: true,
      decoration: const pw.BoxDecoration(color: _verde),
      children: [
        for (var i = 0; i < n; i++)
          celda(t.columnas[i], i, negrita: true, color: PdfColors.white),
      ],
    ),
    for (final f in t.filas)
      pw.TableRow(
        decoration:
            f.destacada ? const pw.BoxDecoration(color: _verdeClaro) : null,
        children: [
          for (var i = 0; i < n; i++)
            i < f.celdas.length
                ? celda(f.celdas[i].texto, i,
                    negrita: f.destacada || f.celdas[i].negrita)
                : celda('', i),
        ],
      ),
  ];

  return [
    ...titulo,
    pw.Table(
      columnWidths: anchos,
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      border: const pw.TableBorder(
        bottom: pw.BorderSide(color: _borde, width: 0.6),
        horizontalInside: pw.BorderSide(color: _borde, width: 0.3),
      ),
      children: filas,
    ),
  ];
}
