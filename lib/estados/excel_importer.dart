import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'estados_models.dart';
import 'montos.dart';

class CuentaImportada {
  const CuentaImportada({
    required this.nombre,
    required this.grupo,
    required this.anterior,
    required this.actual,
  });

  final String nombre;
  final Grupo grupo;
  final double anterior;
  final double actual;
}

class ResultadoImportacion {
  const ResultadoImportacion({
    required this.cuentas,
    required this.estados,
    this.periodoAnterior,
    this.periodoActual,
    this.sinClasificar = const [],
    this.hojasIgnoradas = const [],
    this.celdasConFormula = 0,
  });

  final List<CuentaImportada> cuentas;

  /// Estados encontrados en el archivo (balance y/o resultados).
  final Set<Estado> estados;
  final String? periodoAnterior;
  final String? periodoActual;

  /// Cuentas que no se pudieron clasificar y se colocaron en un grupo por defecto.
  final List<String> sinClasificar;
  final List<String> hojasIgnoradas;
  final int celdasConFormula;

  bool get vacio => cuentas.isEmpty;

  int cuentasDe(Estado e) => cuentas.where((c) => c.grupo.estado == e).length;
}

class _Columnas {
  const _Columnas({this.anterior, this.actual, this.etiquetaAnterior, this.etiquetaActual});

  final int? anterior;
  final int? actual;
  final String? etiquetaAnterior;
  final String? etiquetaActual;
}

/// Lee un archivo .xlsx y lo convierte en cuentas clasificadas.
class ExcelImporter {
  static ResultadoImportacion leer(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);

    final cuentas = <CuentaImportada>[];
    final sinClasificar = <String>[];
    final hojasIgnoradas = <String>[];
    String? etiquetaAnterior;
    String? etiquetaActual;
    var formulas = 0;

    for (final entrada in excel.tables.entries) {
      final filas = entrada.value.rows;
      final detectado = _detectarEstado(_normalizar(entrada.key), filas);
      if (detectado == null) {
        hojasIgnoradas.add(entrada.key);
        continue;
      }
      Estado estado = detectado;

      Grupo? grupoActual;
      _Columnas? columnas;
      var cuentasEnHoja = 0;

      for (final fila in filas) {
        // Encabezado de columnas (Anterior/Actual o años)
        final cols = _detectarColumnas(fila, permitirAnios: cuentasEnHoja == 0);
        if (cols != null) {
          columnas = cols;
          etiquetaAnterior = cols.etiquetaAnterior ?? etiquetaAnterior;
          etiquetaActual = cols.etiquetaActual ?? etiquetaActual;
          continue;
        }

        // Nombre de la cuenta: primer texto que no sea un número
        var indiceNombre = -1;
        String? nombre;
        for (var i = 0; i < fila.length; i++) {
          if (_numero(fila[i]) == null) {
            final t = _texto(fila[i]);
            if (t != null) {
              indiceNombre = i;
              nombre = t;
              break;
            }
          }
        }
        if (nombre == null) continue;

        final n = _normalizar(nombre);

        // Cambio de estado dentro de la misma hoja
        if (n.contains('estado de resultado')) {
          estado = Estado.resultados;
          grupoActual = null;
          continue;
        }
        if (n.contains('balance general') || n.contains('estado de situacion')) {
          estado = Estado.balance;
          grupoActual = null;
          continue;
        }

        // Celdas numéricas a la derecha del nombre
        final indicesNumericos = <int>[];
        for (var i = indiceNombre + 1; i < fila.length; i++) {
          if (fila[i]?.value is FormulaCellValue) formulas++;
          if (_numero(fila[i]) != null) indicesNumericos.add(i);
        }

        // Título de grupo (Activos corrientes, Patrimonio, ...)
        if (_encabezados.containsKey(n) &&
            (estado == Estado.balance || indicesNumericos.isEmpty)) {
          grupoActual = _encabezados[n];
          continue;
        }

        if (indicesNumericos.isEmpty) continue; // títulos o texto suelto
        if (_esTotal(n, estado)) continue;

        // Clasificación: título de grupo > nombre de la cuenta > por defecto
        Grupo? grupo = (grupoActual != null && grupoActual.estado == estado)
            ? grupoActual
            : null;
        grupo ??= _grupoPorNombre(n, estado);
        if (grupo == null) {
          grupo = estado == Estado.balance
              ? Grupo.activoCorriente
              : Grupo.gastosOperacion;
          sinClasificar.add(nombre);
        }

        // Valores
        double anterior = 0;
        double actual = 0;
        if (columnas != null &&
            (columnas.anterior != null || columnas.actual != null)) {
          if (columnas.anterior != null) {
            anterior = _numero(_celda(fila, columnas.anterior!)) ?? 0;
          }
          if (columnas.actual != null) {
            actual = _numero(_celda(fila, columnas.actual!)) ?? 0;
          }
        } else {
          final valores = [
            for (final i in indicesNumericos) _numero(fila[i]) ?? 0,
          ];
          if (valores.length >= 2) {
            anterior = valores[0];
            actual = valores[1];
          } else {
            actual = valores[0];
          }
        }

        cuentas.add(CuentaImportada(
          nombre: nombre.replaceAll(RegExp(r'\s+'), ' ').trim(),
          grupo: grupo,
          anterior: anterior,
          actual: actual,
        ));
        cuentasEnHoja++;
      }
    }

    return ResultadoImportacion(
      cuentas: cuentas,
      estados: {for (final c in cuentas) c.grupo.estado},
      periodoAnterior: etiquetaAnterior,
      periodoActual: etiquetaActual,
      sinClasificar: sinClasificar,
      hojasIgnoradas: hojasIgnoradas,
      celdasConFormula: formulas,
    );
  }

  // ------------------------------------------------------------- celdas

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

  // ------------------------------------------------------------ detección

  static String _normalizar(String s) {
    const conTilde = 'áàäâéèëêíìïîóòöôúùüûñ';
    const sinTilde = 'aaaaeeeeiiiioooouuuun';
    var r = s.toLowerCase();
    for (var i = 0; i < conTilde.length; i++) {
      r = r.replaceAll(conTilde[i], sinTilde[i]);
    }
    r = r.replaceAll(RegExp(r'[:;,.()]'), ' ');
    return r.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static Estado? _detectarEstado(String nombreHoja, List<List<Data?>> filas) {
    if (nombreHoja.contains('resultado') ||
        nombreHoja.contains('perdida') ||
        nombreHoja.contains('ganancia')) {
      return Estado.resultados;
    }
    if (nombreHoja.contains('balance') || nombreHoja.contains('situacion')) {
      return Estado.balance;
    }
    // Sin pista en el nombre: se mira el contenido
    var balance = 0;
    var resultados = 0;
    for (final fila in filas) {
      for (final celda in fila) {
        final t = _texto(celda);
        if (t == null || _numero(celda) != null) continue;
        final n = _normalizar(t);
        if (n.contains('activo') ||
            n.contains('pasivo') ||
            n.contains('patrimonio')) {
          balance++;
        }
        if (n.contains('ventas') ||
            n.contains('utilidad') ||
            n.contains('costo de')) {
          resultados++;
        }
        break; // solo la primera columna de texto de cada fila
      }
    }
    if (balance == 0 && resultados == 0) return null;
    return resultados > balance ? Estado.resultados : Estado.balance;
  }

  static _Columnas? _detectarColumnas(
    List<Data?> fila, {
    required bool permitirAnios,
  }) {
    int? anterior;
    int? actual;
    var hayNumerosNoAnio = false;
    final anios = <int, int>{}; // columna -> año

    for (var i = 0; i < fila.length; i++) {
      final valor = _numero(fila[i]);
      if (valor != null) {
        final esAnio =
            valor == valor.roundToDouble() && valor >= 1900 && valor <= 2100;
        if (esAnio) {
          anios[i] = valor.toInt();
        } else {
          hayNumerosNoAnio = true;
        }
        continue;
      }
      final t = _texto(fila[i]);
      if (t == null) continue;
      final n = _normalizar(t);
      if (n.contains('anterior')) anterior = i;
      if (n.contains('actual')) actual = i;
    }

    if (hayNumerosNoAnio) return null;

    // Fila solo de texto con "Anterior" / "Actual"
    if (anios.isEmpty && (anterior != null || actual != null)) {
      return _Columnas(anterior: anterior, actual: actual);
    }

    // Fila con dos años (ej. 2024 y 2025)
    if (permitirAnios && anios.length >= 2 && anterior == null && actual == null) {
      final columnas = anios.keys.toList()..sort();
      final c1 = columnas[0];
      final c2 = columnas[1];
      final a1 = anios[c1]!;
      final a2 = anios[c2]!;
      if (a1 == a2) return null;
      final anteriorCol = a1 < a2 ? c1 : c2;
      final actualCol = a1 < a2 ? c2 : c1;
      return _Columnas(
        anterior: anteriorCol,
        actual: actualCol,
        etiquetaAnterior: '${anios[anteriorCol]}',
        etiquetaActual: '${anios[actualCol]}',
      );
    }
    return null;
  }

  static bool _esTotal(String n, Estado estado) {
    if (n.startsWith('total') || n.startsWith('suma') || n.startsWith('sumas')) {
      return true;
    }
    if (n.contains('pasivo mas patrimonio') ||
        n.contains('pasivo + patrimonio') ||
        n.contains('pasivo y patrimonio') ||
        n.contains('pasivos y patrimonio')) {
      return true;
    }
    if (estado == Estado.resultados) {
      return n.startsWith('utilidad') ||
          n.startsWith('perdida') ||
          n.startsWith('resultado') ||
          n.startsWith('uaii') ||
          n.startsWith('ebit') ||
          n.startsWith('margen');
    }
    return false;
  }

  // -------------------------------------------------------- clasificación

  /// Títulos que cambian el grupo actual. Un valor null reinicia el grupo
  /// (títulos generales como "Activos" o "Pasivos").
  static const Map<String, Grupo?> _encabezados = {
    'activo': null,
    'activos': null,
    'pasivo': null,
    'pasivos': null,
    'activo corriente': Grupo.activoCorriente,
    'activos corrientes': Grupo.activoCorriente,
    'activo circulante': Grupo.activoCorriente,
    'activos circulantes': Grupo.activoCorriente,
    'activo no corriente': Grupo.activoNoCorriente,
    'activos no corrientes': Grupo.activoNoCorriente,
    'activo no circulante': Grupo.activoNoCorriente,
    'activos no circulantes': Grupo.activoNoCorriente,
    'activo fijo': Grupo.activoNoCorriente,
    'activos fijos': Grupo.activoNoCorriente,
    'pasivo corriente': Grupo.pasivoCorriente,
    'pasivos corrientes': Grupo.pasivoCorriente,
    'pasivo circulante': Grupo.pasivoCorriente,
    'pasivos circulantes': Grupo.pasivoCorriente,
    'pasivo a corto plazo': Grupo.pasivoCorriente,
    'pasivos a corto plazo': Grupo.pasivoCorriente,
    'pasivo no corriente': Grupo.pasivoNoCorriente,
    'pasivos no corrientes': Grupo.pasivoNoCorriente,
    'pasivo a largo plazo': Grupo.pasivoNoCorriente,
    'pasivos a largo plazo': Grupo.pasivoNoCorriente,
    'pasivo fijo': Grupo.pasivoNoCorriente,
    'patrimonio': Grupo.patrimonio,
    'patrimonio neto': Grupo.patrimonio,
    'capital contable': Grupo.patrimonio,
    'ingresos': Grupo.ventas,
    'ventas': Grupo.ventas,
    'costos': Grupo.costoVentas,
    'gastos de operacion': Grupo.gastosOperacion,
    'gastos operativos': Grupo.gastosOperacion,
    'otros ingresos': Grupo.otrosIngresos,
    'otros gastos': Grupo.otrosGastos,
    'gastos financieros': Grupo.gastosFinancieros,
    'impuestos': Grupo.impuestos,
  };

  static const List<(Grupo, List<String>)> _palabrasBalance = [
    (Grupo.pasivoNoCorriente, ['largo plazo', 'hipotec', 'bonos por pagar']),
    (
      Grupo.activoNoCorriente,
      [
        'propiedad', 'planta', 'equipo', 'terreno', 'edificio', 'maquinaria',
        'mobiliario', 'vehiculo', 'mejoras', 'intangible', 'plusvalia',
        'depreciacion', 'no corriente', 'activo fijo', 'activos fijos',
        'patente', 'software',
      ]
    ),
    (
      Grupo.pasivoCorriente,
      [
        'por pagar', 'proveedores', 'acreedores', 'corto plazo', 'sobregiro',
        'porcion circulante', 'ingresos diferidos', 'retenciones', 'pasivo',
      ]
    ),
    (
      Grupo.patrimonio,
      [
        'capital', 'utilidades retenidas', 'utilidad retenida',
        'utilidades acumuladas', 'reserva', 'patrimonio',
        'resultado del ejercicio', 'resultados acumulados', 'superavit',
        'aportes',
      ]
    ),
    (
      Grupo.activoCorriente,
      [
        'efectivo', 'caja', 'banco', 'por cobrar', 'clientes', 'inventario',
        'mercaderia', 'existencias', 'gastos pagados', 'pagado por adelantado',
        'anticipos', 'inversiones temporales', 'iva acreditable',
        'activo corriente',
      ]
    ),
  ];

  static const List<(Grupo, List<String>)> _palabrasResultados = [
    (
      Grupo.otrosIngresos,
      [
        'otros ingresos', 'ingresos financieros', 'ingresos por interes',
        'ingresos no operativos',
      ]
    ),
    (
      Grupo.otrosGastos,
      ['otros gastos', 'otros egresos', 'gastos no operativos', 'perdida']
    ),
    (Grupo.gastosFinancieros, ['interes', 'financier', 'comision bancaria']),
    (Grupo.impuestos, ['impuesto']),
    (Grupo.costoVentas, ['costo']),
    (
      Grupo.gastosOperacion,
      [
        'gasto', 'sueldo', 'salario', 'alquiler', 'depreciacion',
        'administrativ', 'publicidad', 'servicios',
      ]
    ),
    (Grupo.ventas, ['venta', 'ingreso']),
  ];

  static Grupo? _grupoPorNombre(String n, Estado estado) {
    final reglas =
        estado == Estado.balance ? _palabrasBalance : _palabrasResultados;
    for (final (grupo, palabras) in reglas) {
      for (final p in palabras) {
        if (n.contains(p)) return grupo;
      }
    }
    return null;
  }
}