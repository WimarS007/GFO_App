enum Estado { balance, resultados }

enum Periodo { anterior, actual }

/// Cómo se comporta un costo respecto al volumen de ventas.
/// Lo usan los módulos de punto de equilibrio (C-V-U) y apalancamiento.
enum Comportamiento { variable, fijo }

/// Grupo (clasificación) al que pertenece cada cuenta.
/// La clasificación permite que otros módulos usen los datos
/// (activos corrientes, UAII, utilidad neta, etc.).
enum Grupo {
  activoCorriente(Estado.balance, 'Activos corrientes'),
  activoNoCorriente(Estado.balance, 'Activos no corrientes'),
  pasivoCorriente(Estado.balance, 'Pasivos corrientes'),
  pasivoNoCorriente(Estado.balance, 'Pasivos no corrientes'),
  patrimonio(Estado.balance, 'Patrimonio'),
  ventas(Estado.resultados, 'Ventas netas'),
  costoVentas(Estado.resultados, 'Costo de ventas'),
  gastosOperacion(Estado.resultados, 'Gastos de operación'),
  otrosIngresos(Estado.resultados, 'Otros ingresos'),
  otrosGastos(Estado.resultados, 'Otros gastos'),
  gastosFinancieros(Estado.resultados, 'Gastos financieros (intereses)'),
  impuestos(Estado.resultados, 'Impuesto sobre la renta');

  const Grupo(this.estado, this.titulo);

  final Estado estado;
  final String titulo;

  static List<Grupo> deEstado(Estado e) =>
      values.where((g) => g.estado == e).toList();
}

class Cuenta {
  Cuenta({
    required this.id,
    required this.nombre,
    required this.grupo,
    this.anterior = 0,
    this.actual = 0,
  });

  final String id;
  String nombre;
  Grupo grupo;
  double anterior;
  double actual;

  Comportamiento? _comportamiento;

  /// Si el usuario no lo marca: el costo de ventas es variable y los gastos de
  /// operación son fijos. Solo importa para esos dos grupos.
  Comportamiento get comportamiento =>
      _comportamiento ??
      (grupo == Grupo.costoVentas ? Comportamiento.variable : Comportamiento.fijo);

  set comportamiento(Comportamiento v) => _comportamiento = v;

  double valor(Periodo p) => p == Periodo.anterior ? anterior : actual;

  void setValor(Periodo p, double v) {
    if (p == Periodo.anterior) {
      anterior = v;
    } else {
      actual = v;
    }
  }
}
