/// Minúsculas, sin tildes ni signos de puntuación, para comparar textos.
String normalizar(String s) {
  const conTilde = 'áàäâéèëêíìïîóòöôúùüûñ';
  const sinTilde = 'aaaaeeeeiiiioooouuuun';
  var r = s.toLowerCase();
  for (var i = 0; i < conTilde.length; i++) {
    r = r.replaceAll(conTilde[i], sinTilde[i]);
  }
  r = r.replaceAll(RegExp(r'[:;,.()]'), ' ');
  return r.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Tipo de movimiento del registro semanal.
enum TipoMov {
  ingreso('Ingreso'),
  gasto('Gasto'),
  ahorro('Ahorro'),
  reserva('Reserva');

  const TipoMov(this.etiqueta);

  final String etiqueta;

  static TipoMov? desdeTexto(String texto) {
    final n = normalizar(texto);
    for (final t in values) {
      if (normalizar(t.etiqueta) == n) return t;
    }
    return null;
  }
}

enum Frecuencia {
  semanal('Semanal'),
  mensual('Mensual');

  const Frecuencia(this.etiqueta);

  final String etiqueta;

  static Frecuencia desdeTexto(String texto) =>
      normalizar(texto).startsWith('mensual') ? mensual : semanal;
}

const prioridades = ['Necesidad', 'Deseo', 'Meta'];
const medios = ['Efectivo', 'Transferencia', 'Tarjeta', 'Otro'];

/// Tipos de una línea del presupuesto proyectado.
const tiposLinea = ['Necesidad', 'Deseo', 'Reserva', 'Ahorro', 'Según el caso'];

const tiposProyeccion = ['Real actual', 'Deseada'];

const categoriasBase = [
  'Apoyo familiar',
  'Ingreso extra',
  'Transporte',
  'Alimentación',
  'Datos/Internet',
  'Copias y materiales',
  'Salud',
  'Personal/Ocio',
  'Reserva imprevistos',
  'Meta de ahorro',
  'Otro',
];

/// Un ingreso, gasto, ahorro o reserva del registro semanal.
/// El monto se escribe siempre positivo; el tipo decide cómo se suma.
class Movimiento {
  Movimiento({
    required this.id,
    required this.fecha,
    required this.semana,
    required this.tipo,
    required this.categoria,
    this.descripcion = '',
    this.monto = 0,
    this.prioridad = '',
    this.medio = '',
    this.observacion = '',
  });

  final String id;
  DateTime fecha;

  /// Número de semana del seguimiento (1 = primera semana).
  int semana;
  TipoMov tipo;
  String categoria;
  String descripcion;
  double monto;
  String prioridad;
  String medio;
  String observacion;
}

/// Una categoría del presupuesto proyectado.
class LineaProyeccion {
  LineaProyeccion({
    required this.id,
    required this.categoria,
    this.monto = 0,
    this.tipo = 'Necesidad',
    this.comentario = '',
  });

  final String id;
  String categoria;
  double monto;
  String tipo;
  String comentario;
}

/// Resumen de una semana (de lunes a domingo).
class SemanaResumen {
  SemanaResumen({
    required this.semana,
    required this.desde,
    required this.hasta,
  });

  final int semana;
  final DateTime desde;
  final DateTime hasta;
  double ingresos = 0;
  double gastos = 0;
  double ahorro = 0;
  double reserva = 0;
  double ahorroAcumulado = 0;

  /// Cuatro semanas forman un mes presupuestario.
  int get mes => (semana / 4).ceil();

  /// Saldo = Ingresos − Gastos − Ahorro − Reserva
  double get saldo => ingresos - gastos - ahorro - reserva;

  bool get hayActividad =>
      ingresos != 0 || gastos != 0 || ahorro != 0 || reserva != 0;
}

/// Una fila de la comparación proyectado vs. real (promedios semanales).
class FilaComparacion {
  const FilaComparacion({
    required this.nombre,
    required this.planificado,
    required this.real,
    required this.esGasto,
  });

  final String nombre;
  final double planificado;
  final double real;

  /// true: gasto (conviene no pasar el plan). false: ahorro o reserva (conviene cumplirlo).
  final bool esGasto;

  double get diferencia => real - planificado;

  String get estado {
    if (esGasto) {
      if (planificado == 0 && real > 0) return 'Sin plan';
      return real > planificado + 0.005 ? 'Excede el plan' : 'Dentro del plan';
    }
    return real + 0.005 >= planificado ? 'Cumple' : 'Por debajo';
  }
}

/// Resultados calculados a partir de los movimientos.
class ResumenPersonal {
  ResumenPersonal({
    required this.semanas,
    required this.gastosPorCategoria,
    required this.gastoNecesidad,
    required this.gastoDeseo,
    required this.gastoOtraPrioridad,
    required this.semanasConRegistro,
    required this.movimientosFuera,
  });

  final List<SemanaResumen> semanas;

  /// Categorías de gasto de mayor a menor.
  final List<MapEntry<String, double>> gastosPorCategoria;
  final double gastoNecesidad;
  final double gastoDeseo;
  final double gastoOtraPrioridad;

  /// Semanas en las que hay al menos un movimiento.
  final int semanasConRegistro;

  /// Movimientos con semana menor que 1 (fuera del período): no se suman.
  final int movimientosFuera;

  double _suma(double Function(SemanaResumen) f) =>
      semanas.fold(0.0, (a, s) => a + f(s));

  double get ingresos => _suma((s) => s.ingresos);
  double get gastos => _suma((s) => s.gastos);
  double get ahorro => _suma((s) => s.ahorro);
  double get reserva => _suma((s) => s.reserva);

  /// Saldo disponible = Ingresos − Gastos − Ahorro − Reserva
  double get saldo => ingresos - gastos - ahorro - reserva;
}
