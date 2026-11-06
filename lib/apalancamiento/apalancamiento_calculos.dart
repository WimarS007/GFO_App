import '../estados/montos.dart';

/// Datos de entrada para los grados de apalancamiento.
class DatosApalancamiento {
  const DatosApalancamiento({
    required this.ventas,
    required this.costosVariables,
    required this.costosFijos,
    this.intereses = 0,
    this.dividendosPreferentes = 0,
    this.tasaImpuestos = 0,
  });

  final double ventas;
  final double costosVariables;
  final double costosFijos;
  final double intereses;
  final double dividendosPreferentes;

  /// Tasa de impuestos como fracción (0.30 = 30 %). Solo se usa para llevar los
  /// dividendos preferentes a antes de impuestos.
  final double tasaImpuestos;

  /// Mensaje si los datos no permiten calcular; null si son válidos.
  String? get problema {
    if (ventas <= 0) return 'Las ventas deben ser mayores que cero.';
    if (costosVariables < 0 ||
        costosFijos < 0 ||
        intereses < 0 ||
        dividendosPreferentes < 0) {
      return 'Los costos, los intereses y los dividendos no pueden ser negativos.';
    }
    if (tasaImpuestos < 0 || tasaImpuestos >= 1) {
      return 'La tasa de impuestos debe ser mayor o igual a 0% y menor que 100%.';
    }
    return null;
  }
}

/// Resultados de GAO, GAF y GAT. Solo se crea con datos válidos (problema == null).
class ResultadoApalancamiento {
  const ResultadoApalancamiento(this.datos);

  final DatosApalancamiento datos;

  /// Margen de contribución = Ventas − Costos variables
  double get margenContribucion => datos.ventas - datos.costosVariables;

  /// UAII = Margen de contribución − Costos fijos
  double get uaii => margenContribucion - datos.costosFijos;

  /// Dividendos preferentes antes de impuestos = DP / (1 − tasa)
  double get dividendosAntesImpuestos =>
      datos.dividendosPreferentes / (1 - datos.tasaImpuestos);

  /// UAII − Intereses − Dividendos preferentes antes de impuestos
  double get utilidadTrasCargasFinancieras =>
      uaii - datos.intereses - dividendosAntesImpuestos;

  /// GAO = Margen de contribución / UAII  (solo con UAII positiva)
  double? get gao => uaii > 0 ? margenContribucion / uaii : null;

  /// GAF = UAII / (UAII − Intereses − DP / (1 − T))
  double? get gaf => (uaii > 0 && utilidadTrasCargasFinancieras > 0)
      ? uaii / utilidadTrasCargasFinancieras
      : null;

  /// GAT = GAO × GAF
  double? get gat {
    final o = gao;
    final f = gaf;
    return (o == null || f == null) ? null : o * f;
  }

  String? get avisoGao => uaii > 0
      ? null
      : 'La UAII es cero o negativa, así que el GAO no se puede calcular: con estos datos la empresa está en su punto de equilibrio operativo o por debajo de él.';

  String? get avisoGaf {
    if (uaii <= 0) {
      return 'El GAF necesita una UAII positiva.';
    }
    if (utilidadTrasCargasFinancieras <= 0) {
      return 'La UAII no alcanza para cubrir los intereses y los dividendos preferentes, así que el GAF no se puede calcular (la utilidad sería cero o negativa).';
    }
    return null;
  }
}

// ------------------------------------------------------------ resumen para IA

String _cs(double v) => 'C\$ ${formatoMonto(v)}';
String _x(double? v) => v == null ? 'no calculable' : '${v.toStringAsFixed(2)} veces';

/// Texto con las cifras de apalancamiento para que la IA las interprete.
String resumenApalancamientoParaIa(ResultadoApalancamiento r) {
  final d = r.datos;
  final b = StringBuffer()
    ..writeln('Moneda: córdobas (C\$).')
    ..writeln('\nDatos ingresados:')
    ..writeln('- Ventas: ${_cs(d.ventas)}')
    ..writeln('- Costos variables totales: ${_cs(d.costosVariables)}')
    ..writeln('- Costos fijos: ${_cs(d.costosFijos)}')
    ..writeln('- Gastos por intereses: ${_cs(d.intereses)}')
    ..writeln('- Dividendos preferentes: ${_cs(d.dividendosPreferentes)}')
    ..writeln('- Tasa de impuestos aplicada a los dividendos preferentes: ${(d.tasaImpuestos * 100).toStringAsFixed(2)}%')
    ..writeln('\nResultados:')
    ..writeln('- Margen de contribución: ${_cs(r.margenContribucion)}')
    ..writeln('- UAII: ${_cs(r.uaii)}')
    ..writeln('- GAO (Margen de contribución / UAII): ${_x(r.gao)}')
    ..writeln('- GAF (UAII / (UAII − intereses − dividendos preferentes antes de impuestos)): ${_x(r.gaf)}')
    ..writeln('- GAT (GAO × GAF): ${_x(r.gat)}');
  if (r.avisoGao != null) b.writeln('- Nota GAO: ${r.avisoGao}');
  if (r.avisoGaf != null) b.writeln('- Nota GAF: ${r.avisoGaf}');
  return b.toString();
}
