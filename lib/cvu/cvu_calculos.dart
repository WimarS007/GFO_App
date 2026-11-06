import '../estados/montos.dart';

/// Datos de entrada del modelo costo-volumen-utilidad (C-V-U).
class DatosCvu {
  const DatosCvu({
    required this.precio,
    required this.costoVariable,
    required this.costosFijos,
    this.unidades,
  });

  final double precio;
  final double costoVariable;
  final double costosFijos;

  /// Unidades vendidas. Es opcional: sin ellas se calcula el punto de equilibrio,
  /// pero no la utilidad ni el margen de seguridad.
  final double? unidades;

  /// Mensaje si los datos no permiten calcular; null si son válidos.
  String? get problema {
    if (precio <= 0) return 'El precio de venta unitario debe ser mayor que cero.';
    if (costoVariable < 0) return 'El costo variable unitario no puede ser negativo.';
    if (costosFijos < 0) return 'Los costos fijos no pueden ser negativos.';
    if (unidades != null && unidades! < 0) {
      return 'Las unidades vendidas no pueden ser negativas.';
    }
    return null;
  }

  /// Aplica cambios porcentuales expresados como fracción (0.10 = +10 %).
  DatosCvu conCambios({
    double cambioPrecio = 0,
    double cambioCostoVariable = 0,
    double cambioCostosFijos = 0,
    double cambioVolumen = 0,
  }) {
    final u = unidades;
    return DatosCvu(
      precio: precio * (1 + cambioPrecio),
      costoVariable: costoVariable * (1 + cambioCostoVariable),
      costosFijos: costosFijos * (1 + cambioCostosFijos),
      unidades: u == null ? null : u * (1 + cambioVolumen),
    );
  }
}

/// Resultados del modelo C-V-U. Solo se crea con datos válidos (problema == null).
class ResultadoCvu {
  const ResultadoCvu(this.datos);

  final DatosCvu datos;

  /// Margen de contribución unitario = Precio − Costo variable unitario
  double get margenContribucionUnitario => datos.precio - datos.costoVariable;

  /// Razón de margen de contribución = MC unitario / Precio
  double get razonMargenContribucion => margenContribucionUnitario / datos.precio;

  /// Hay punto de equilibrio solo si cada unidad aporta contribución positiva.
  bool get hayEquilibrio => margenContribucionUnitario > 0;

  /// PE en unidades = Costos fijos / MC unitario
  double? get puntoEquilibrioUnidades =>
      hayEquilibrio ? datos.costosFijos / margenContribucionUnitario : null;

  /// PE en córdobas = PE en unidades × Precio  (= Costos fijos / Razón de MC)
  double? get puntoEquilibrioMonetario {
    final pe = puntoEquilibrioUnidades;
    return pe == null ? null : pe * datos.precio;
  }

  double? get ingresos {
    final u = datos.unidades;
    return u == null ? null : datos.precio * u;
  }

  double? get costosVariablesTotales {
    final u = datos.unidades;
    return u == null ? null : datos.costoVariable * u;
  }

  /// MC total = Ingresos − Costos variables
  double? get margenContribucionTotal {
    final u = datos.unidades;
    return u == null ? null : margenContribucionUnitario * u;
  }

  double? get costosTotales {
    final cv = costosVariablesTotales;
    return cv == null ? null : cv + datos.costosFijos;
  }

  /// Utilidad operativa = MC total − Costos fijos
  double? get utilidadOperativa {
    final mc = margenContribucionTotal;
    return mc == null ? null : mc - datos.costosFijos;
  }

  /// Margen de seguridad en unidades = Unidades vendidas − PE en unidades
  double? get margenSeguridadUnidades {
    final u = datos.unidades;
    final pe = puntoEquilibrioUnidades;
    if (u == null || pe == null) return null;
    return u - pe;
  }

  /// Margen de seguridad (fracción) = (Unidades − PE) / Unidades
  double? get margenSeguridadPorcentaje {
    final u = datos.unidades;
    final ms = margenSeguridadUnidades;
    if (u == null || ms == null || u <= 0) return null;
    return ms / u;
  }
}

// ------------------------------------------------------------ resumen para IA

String _cs(double v) => 'C\$ ${formatoMonto(v)}';
String _num(double? v) => v == null ? 'n/d' : formatoMonto(v);
String _csn(double? v) => v == null ? 'n/d' : _cs(v);
String _pct(double? f) => f == null ? 'n/d' : '${(f * 100).toStringAsFixed(2)}%';
String _cambio(double f) {
  final p = f * 100;
  final signo = p > 0 ? '+' : '';
  return '$signo${p.toStringAsFixed(2)}%';
}

List<String> _lineas(ResultadoCvu r) {
  final d = r.datos;
  final pe = r.puntoEquilibrioUnidades;
  return [
    '- Precio de venta unitario: ${_cs(d.precio)}',
    '- Costo variable unitario: ${_cs(d.costoVariable)}',
    '- Costos fijos totales: ${_cs(d.costosFijos)}',
    '- Unidades vendidas: ${d.unidades == null ? 'no informadas' : _num(d.unidades)}',
    '- Margen de contribución unitario: ${_cs(r.margenContribucionUnitario)}',
    '- Razón de margen de contribución: ${_pct(r.razonMargenContribucion)}',
    if (pe == null)
      '- Punto de equilibrio: no existe, porque el precio no supera el costo variable unitario'
    else
      '- Punto de equilibrio: ${_num(pe)} unidades (${_csn(r.puntoEquilibrioMonetario)})',
    '- Ingresos totales: ${_csn(r.ingresos)}',
    '- Costos totales: ${_csn(r.costosTotales)}',
    '- Utilidad operativa: ${_csn(r.utilidadOperativa)}',
    '- Margen de seguridad: ${_num(r.margenSeguridadUnidades)} unidades (${_pct(r.margenSeguridadPorcentaje)})',
  ];
}

/// Texto con las cifras del C-V-U para que la IA las interprete.
/// [escenario] y los cambios son opcionales.
String resumenCvuParaIa({
  required ResultadoCvu base,
  ResultadoCvu? escenario,
  double cambioPrecio = 0,
  double cambioCostoVariable = 0,
  double cambioCostosFijos = 0,
  double cambioVolumen = 0,
}) {
  final b = StringBuffer()
    ..writeln('Moneda: córdobas (C\$).')
    ..writeln('\nSituación base:')
    ..writeAll(_lineas(base), '\n');

  if (escenario != null) {
    b
      ..writeln()
      ..writeln(
          '\nEscenario simulado (precio ${_cambio(cambioPrecio)}, costo variable ${_cambio(cambioCostoVariable)}, '
          'costos fijos ${_cambio(cambioCostosFijos)}, volumen ${_cambio(cambioVolumen)}):')
      ..writeAll(_lineas(escenario), '\n');
  }
  return b.toString();
}
