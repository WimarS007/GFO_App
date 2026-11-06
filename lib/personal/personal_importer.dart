import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../estados/montos.dart';
import 'personal_models.dart';

class MovimientoImportado {
  const MovimientoImportado({
    required this.tipo,
    required this.categoria,
    required this.monto,
    this.fecha,
    this.semana,
    this.descripcion = '',
    this.prioridad = '',
    this.medio = '',
    this.observacion = '',
  });

  final TipoMov tipo;
  final String categoria;
  final double monto;
  final DateTime? fecha;
  final int? semana;
  final String descripcion;
  final String prioridad;
  final String medio;
  final String observacion;
}

class LineaImportada {
  const LineaImportada({
    required this.categoria,
    required this.monto,
    required this.tipo,
    this.comentario = '',
  });

  final String categoria;
  final double monto;
  final String tipo;
  final String comentario;
}

class ResultadoImportacionPersonal {
  const ResultadoImportacionPersonal({
    this.nombre,
    this.meta,
    this.costoMeta,
    this.semanas,
    this.fechaInicio,
    this.movimientos = const [],
    this.lineas = const [],
    this.ingresoProyectado,
    this.frecuencia,
    this.tipoProyeccion,
    this.filasOmitidas = 0,
    this.hojasIgnoradas = const [],
    this.celdasConFormula = 0,
  });

  final String? nombre;
  final String? meta;
  final double? costoMeta;
  final int? semanas;
  final DateTime? fechaInicio;
  final List<MovimientoImportado> movimientos;
  final List<LineaImportada> lineas;
  final double? ingresoProyectado;
  final String? frecuencia;
  final String? tipoProyeccion;

  /// Filas del registro con datos pero sin tipo de movimiento válido.
  final int filasOmitidas;
  final List<String> hojasIgnoradas;
  final int celdasConFormula;

  bool get hayDatosGenerales =>
      nombre != null ||
      meta != null ||
      costoMeta != null ||
      semanas != null ||
      fechaInicio != null;

  bool get hayProyeccion =>
      lineas.isNotEmpty || ingresoProyectado != null || frecuencia != null;

  bool get vacio =>
      !hayDatosGenerales && movimientos.isEmpty && !hayProyeccion;
}

/// Acumulador mutable mientras se recorren las hojas.
class _Acum {
  String? nombre;
  String? meta;
  double? costoMeta;
  int? semanas;
  DateTime? fechaInicio;
  double? ingresoProyectado;
  String? frecuencia;
  String? tipoProyeccion;
  final movimientos = <MovimientoImportado>[];
  final lineas = <LineaImportada>[];
  var omitidas = 0;
  var formulas = 0;

  int get total =>
      movimientos.length +
      lineas.length +
      [nombre, meta, costoMeta, semanas, fechaInicio, ingresoProyectado, frecuencia, tipoProyeccion]
          .where((x) => x != null)
          .length;
}

/// Lee el Excel de presupuesto personal (formato de la plantilla de ejemplo):
/// datos y meta, registro semanal de movimientos y presupuesto proyectado.
/// Busca por los títulos de las filas y columnas, no por la posición de las celdas,
/// y no depende del nombre de las hojas.
class PersonalImporter {
  static ResultadoImportacionPersonal leer(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final a = _Acum();
    final ignoradas = <String>[];

    for (final entrada in excel.tables.entries) {
      final antes = a.total;
      final filas = entrada.value.rows;
      _leerEtiquetas(filas, a);
      _leerRegistro(filas, a);
      _leerProyeccion(filas, a);
      if (a.total == antes) ignoradas.add(entrada.key);
    }

    return ResultadoImportacionPersonal(
      nombre: a.nombre,
      meta: a.meta,
      costoMeta: a.costoMeta,
      semanas: a.semanas,
      fechaInicio: a.fechaInicio,
      movimientos: a.movimientos,
      lineas: a.lineas,
      ingresoProyectado: a.ingresoProyectado,
      frecuencia: a.frecuencia,
      tipoProyeccion: a.tipoProyeccion,
      filasOmitidas: a.omitidas,
      hojasIgnoradas: ignoradas,
      celdasConFormula: a.formulas,
    );
  }

  // ------------------------------------------------- datos generales y proyección

  static String? _claveEtiqueta(String n) {
    if (n == 'nombre') return 'nombre';
    if (n.startsWith('meta al final') || n == 'meta') return 'meta';
    if (n.startsWith('costo de la meta')) return 'costo';
    if (n.startsWith('duracion')) return 'semanas';
    if (n.startsWith('inicio del seguimiento')) return 'inicio';
    if (n.startsWith('tipo de proyeccion')) return 'tipoProy';
    if (n.startsWith('ingreso mensual o semanal')) return 'ingresoProy';
    if (n == 'frecuencia') return 'frecuencia';
    return null;
  }

  /// Filas con la forma "Etiqueta: valor".
  static void _leerEtiquetas(List<List<Data?>> filas, _Acum a) {
    for (final fila in filas) {
      for (var i = 0; i < fila.length; i++) {
        final t = _texto(fila[i]);
        if (t == null) continue;
        final clave = _claveEtiqueta(normalizar(t));
        if (clave == null) continue;

        // Primer valor no vacío a la derecha de la etiqueta
        Data? valor;
        for (var j = i + 1; j < fila.length; j++) {
          final v = fila[j]?.value;
          if (v == null) continue;
          if (v is FormulaCellValue) {
            a.formulas++;
            continue;
          }
          valor = fila[j];
          break;
        }
        if (valor == null) continue;

        switch (clave) {
          case 'nombre':
            a.nombre ??= _texto(valor);
          case 'meta':
            a.meta ??= _texto(valor);
          case 'costo':
            a.costoMeta ??= _numero(valor);
          case 'semanas':
            final n = _numero(valor);
            if (n != null && n >= 0) a.semanas ??= n.round();
          case 'inicio':
            a.fechaInicio ??= _fecha(valor);
          case 'tipoProy':
            a.tipoProyeccion ??= _texto(valor);
          case 'ingresoProy':
            a.ingresoProyectado ??= _numero(valor);
          case 'frecuencia':
            a.frecuencia ??= _texto(valor);
        }
      }
    }
  }

  // ------------------------------------------------------------ registro semanal

  static void _leerRegistro(List<List<Data?>> filas, _Acum a) {
    for (var r = 0; r < filas.length; r++) {
      final cols = <String, int>{};
      for (var i = 0; i < filas[r].length; i++) {
        final t = _texto(filas[r][i]);
        if (t == null) continue;
        final n = normalizar(t);
        if (n == 'fecha') cols['fecha'] = i;
        if (n == 'semana') cols['semana'] = i;
        if (n == 'tipo de movimiento' || n == 'tipo') cols['tipo'] = i;
        if (n == 'categoria') cols['categoria'] = i;
        if (n == 'descripcion') cols['descripcion'] = i;
        if (n == 'monto') cols['monto'] = i;
        if (n == 'prioridad') cols['prioridad'] = i;
        if (n == 'medio') cols['medio'] = i;
        if (n == 'observacion') cols['observacion'] = i;
      }
      if (!(cols.containsKey('tipo') &&
          cols.containsKey('monto') &&
          cols.containsKey('categoria'))) {
        continue;
      }

      for (var k = r + 1; k < filas.length; k++) {
        final fila = filas[k];
        Data? c(String clave) =>
            cols.containsKey(clave) ? _celda(fila, cols[clave]!) : null;

        if (c('monto')?.value is FormulaCellValue) a.formulas++;
        final monto = _numero(c('monto'));
        final tipoTxt = _texto(c('tipo'));
        if (tipoTxt == null && monto == null) continue; // fila vacía

        final tipo = tipoTxt == null ? null : TipoMov.desdeTexto(tipoTxt);
        if (tipo == null || monto == null || monto == 0) {
          a.omitidas++;
          continue;
        }

        final semana = _numero(c('semana'));
        a.movimientos.add(MovimientoImportado(
          tipo: tipo,
          categoria: _texto(c('categoria')) ?? '',
          monto: monto.abs(),
          fecha: _fecha(c('fecha')),
          semana: (semana != null && semana >= 1) ? semana.round() : null,
          descripcion: _texto(c('descripcion')) ?? '',
          prioridad: _texto(c('prioridad')) ?? '',
          medio: _texto(c('medio')) ?? '',
          observacion: _texto(c('observacion')) ?? '',
        ));
      }
      return; // un solo bloque de registro por hoja
    }
  }

  // ----------------------------------------------------- presupuesto proyectado

  static void _leerProyeccion(List<List<Data?>> filas, _Acum a) {
    for (var r = 0; r < filas.length; r++) {
      int? colCategoria, colMonto, colTipo, colComentario;
      for (var i = 0; i < filas[r].length; i++) {
        final t = _texto(filas[r][i]);
        if (t == null) continue;
        final n = normalizar(t);
        if (n == 'categoria') colCategoria = i;
        if (n == 'monto planificado') colMonto = i;
        if (n == 'tipo') colTipo = i;
        if (n == 'comentario') colComentario = i;
      }
      if (colCategoria == null || colMonto == null) continue;

      for (var k = r + 1; k < filas.length; k++) {
        final fila = filas[k];
        final categoria = _texto(_celda(fila, colCategoria));
        if (categoria == null) break;
        if (normalizar(categoria).startsWith('interpretacion')) break;
        if (_celda(fila, colMonto)?.value is FormulaCellValue) a.formulas++;
        final monto = _numero(_celda(fila, colMonto));
        if (monto == null) continue;
        a.lineas.add(LineaImportada(
          categoria: categoria,
          monto: monto.abs(),
          tipo: _tipoLinea(colTipo == null ? null : _texto(_celda(fila, colTipo))),
          comentario: colComentario == null
              ? ''
              : (_texto(_celda(fila, colComentario)) ?? ''),
        ));
      }
      return;
    }
  }

  /// Ajusta el texto del tipo a uno de [tiposLinea]; por defecto "Según el caso".
  static String _tipoLinea(String? texto) {
    if (texto == null) return 'Según el caso';
    final n = normalizar(texto);
    for (final t in tiposLinea) {
      if (normalizar(t) == n) return t;
    }
    return 'Según el caso';
  }

  // -------------------------------------------------------------------- celdas

  static Data? _celda(List<Data?> fila, int i) =>
      (i >= 0 && i < fila.length) ? fila[i] : null;

  static String? _texto(Data? d) {
    final v = d?.value;
    if (v is TextCellValue) {
      final t = v.toString().trim();
      return t.isEmpty ? null : t;
    }
    return null;
  }

  static double? _numero(Data? d) {
    final v = d?.value;
    if (v is IntCellValue) return v.value.toDouble();
    if (v is DoubleCellValue) return v.value;
    if (v is TextCellValue) return parseMonto(v.toString());
    return null;
  }

  /// Fecha de una celda: fecha de Excel, número de serie o texto (2026-08-03 o 3/8/2026).
  static DateTime? _fecha(Data? d) {
    final v = d?.value;
    if (v is DateCellValue) return DateTime(v.year, v.month, v.day);
    if (v is DateTimeCellValue) return DateTime(v.year, v.month, v.day);
    if (v is IntCellValue || v is DoubleCellValue) {
      final n = _numero(d);
      if (n != null && n > 20000 && n < 80000) {
        final f = DateTime.utc(1899, 12, 30).add(Duration(days: n.floor()));
        return DateTime(f.year, f.month, f.day);
      }
      return null;
    }
    if (v is TextCellValue) {
      final t = v.toString().trim();
      final iso = DateTime.tryParse(t);
      if (iso != null) return DateTime(iso.year, iso.month, iso.day);
      final m = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(t);
      if (m != null) {
        return DateTime(
            int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
      }
    }
    return null;
  }
}
