/// 12 -> "12", 12.5 -> "12.5"
String cantidadTexto(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

// ------------------------------------------------- inventario de productos

enum TipoMovInv {
  entrada('Entrada'),
  salida('Salida');

  const TipoMovInv(this.etiqueta);

  final String etiqueta;
}

class ProductoInv {
  const ProductoInv({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.costoUnitario,
    required this.existenciaInicial,
    required this.stockMinimo,
  });

  final String id;
  final String codigo;
  final String nombre;
  final double costoUnitario;
  final double existenciaInicial;
  final double stockMinimo;
}

class MovimientoInv {
  const MovimientoInv({
    required this.id,
    required this.productoId,
    required this.tipo,
    required this.cantidad,
    required this.fecha,
    this.nota = '',
  });

  final String id;
  final String productoId;
  final TipoMovInv tipo;
  final double cantidad;
  final DateTime fecha;
  final String nota;
}

// -------------------------------------------------- activos del hogar

const estadosActivo = ['Nuevo', 'Bueno', 'Regular', 'Malo'];

const categoriasActivo = [
  'Electrodomésticos',
  'Electrónica',
  'Muebles',
  'Cocina y utensilios',
  'Herramientas',
  'Vehículos',
  'Ropa y calzado',
  'Joyas y objetos de valor',
  'Decoración',
  'Otro',
];

const ubicacionesHogar = [
  'Sala',
  'Cocina',
  'Comedor',
  'Dormitorio',
  'Baño',
  'Patio',
  'Garaje',
  'Bodega',
  'Otro',
];

class ActivoHogar {
  const ActivoHogar({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.ubicacion,
    required this.cantidad,
    required this.costoUnitario,
    required this.valorActualUnitario,
    required this.estado,
    this.fechaCompra,
    this.nota = '',
  });

  final String id;
  final String nombre;
  final String categoria;
  final String ubicacion;
  final int cantidad;

  /// Costo de compra por unidad.
  final double costoUnitario;

  /// Valor actual estimado por unidad.
  final double valorActualUnitario;
  final String estado;
  final DateTime? fechaCompra;
  final String nota;

  double get costoTotal => cantidad * costoUnitario;
  double get valorActualTotal => cantidad * valorActualUnitario;
}
