import 'package:flutter/foundation.dart';

import 'inventario_models.dart';

/// Datos y cálculos del módulo de inventario: productos con existencias y
/// movimientos (Existencia final = inicial + entradas − salidas) y el
/// inventario de activos personales del hogar.
class InventarioController extends ChangeNotifier {
  final List<ProductoInv> _productos = [];
  final List<MovimientoInv> _movs = [];
  final List<ActivoHogar> _activos = [];
  int _seq = 0;

  String _nuevoId(String p) => '$p${_seq++}';

  // ------------------------------------------------------------ productos

  List<ProductoInv> get productos => List.unmodifiable(_productos);

  /// Movimientos en el orden en que se registraron.
  List<MovimientoInv> get movimientos => List.unmodifiable(_movs);

  ProductoInv? productoPorId(String id) {
    for (final p in _productos) {
      if (p.id == id) return p;
    }
    return null;
  }

  double entradas(String productoId) => _movs
      .where((m) => m.productoId == productoId && m.tipo == TipoMovInv.entrada)
      .fold(0.0, (s, m) => s + m.cantidad);

  double salidas(String productoId) => _movs
      .where((m) => m.productoId == productoId && m.tipo == TipoMovInv.salida)
      .fold(0.0, (s, m) => s + m.cantidad);

  double existenciaFinal(ProductoInv p) =>
      p.existenciaInicial + entradas(p.id) - salidas(p.id);

  double valor(ProductoInv p) => existenciaFinal(p) * p.costoUnitario;

  /// Hay que reponer cuando la existencia final es menor o igual al stock mínimo.
  bool requiereReposicion(ProductoInv p) => existenciaFinal(p) <= p.stockMinimo;

  double get valorTotal => _productos.fold(0.0, (s, p) => s + valor(p));

  int get porReponer => _productos.where(requiereReposicion).length;

  double get unidadesTotales =>
      _productos.fold(0.0, (s, p) => s + existenciaFinal(p));

  /// Devuelve un mensaje de error, o null si se agregó.
  String? agregarProducto({
    required String codigo,
    required String nombre,
    required double costoUnitario,
    required double existenciaInicial,
    required double stockMinimo,
  }) {
    final cod = codigo.trim();
    final nom = nombre.trim();
    if (cod.isEmpty || nom.isEmpty) {
      return 'Escribe el código y el nombre del producto.';
    }
    if (_productos.any((p) => p.codigo.toLowerCase() == cod.toLowerCase())) {
      return 'Ya existe un producto con el código "$cod".';
    }
    _productos.add(ProductoInv(
      id: _nuevoId('p'),
      codigo: cod,
      nombre: nom,
      costoUnitario: costoUnitario,
      existenciaInicial: existenciaInicial,
      stockMinimo: stockMinimo,
    ));
    notifyListeners();
    return null;
  }

  /// Elimina el producto y todos sus movimientos.
  void eliminarProducto(String id) {
    _productos.removeWhere((p) => p.id == id);
    _movs.removeWhere((m) => m.productoId == id);
    notifyListeners();
  }

  /// Devuelve un mensaje de error, o null si se registró.
  String? registrarMovimiento({
    required String productoId,
    required TipoMovInv tipo,
    required double cantidad,
    String nota = '',
    DateTime? fecha,
  }) {
    final p = productoPorId(productoId);
    if (p == null) return 'Elige un producto.';
    if (tipo == TipoMovInv.salida && cantidad > existenciaFinal(p)) {
      return 'No hay suficiente existencia de "${p.nombre}": disponible ${cantidadTexto(existenciaFinal(p))}.';
    }
    _movs.add(MovimientoInv(
      id: _nuevoId('m'),
      productoId: productoId,
      tipo: tipo,
      cantidad: cantidad,
      fecha: fecha ?? DateTime.now(),
      nota: nota.trim(),
    ));
    notifyListeners();
    return null;
  }

  /// Devuelve un mensaje de error, o null si se eliminó.
  String? eliminarMovimiento(String id) {
    final i = _movs.indexWhere((m) => m.id == id);
    if (i < 0) return null;
    final m = _movs[i];
    final p = productoPorId(m.productoId);
    if (p != null && m.tipo == TipoMovInv.entrada) {
      if (existenciaFinal(p) - m.cantidad < 0) {
        return 'No se puede eliminar esta entrada: la existencia quedaría negativa porque ya se registraron salidas.';
      }
    }
    _movs.removeAt(i);
    notifyListeners();
    return null;
  }

  // ------------------------------------------------------ activos del hogar

  List<ActivoHogar> get activos => List.unmodifiable(_activos);

  int get totalArticulos => _activos.fold(0, (s, a) => s + a.cantidad);

  double get costoTotalActivos => _activos.fold(0.0, (s, a) => s + a.costoTotal);

  double get valorActualActivos =>
      _activos.fold(0.0, (s, a) => s + a.valorActualTotal);

  /// Costo de compra menos valor actual (positivo = pérdida de valor).
  double get depreciacionActivos => costoTotalActivos - valorActualActivos;

  /// Valor actual por categoría, de mayor a menor.
  Map<String, double> get valorPorCategoria => _agrupar((a) => a.categoria);

  /// Valor actual por ubicación de la casa, de mayor a menor.
  Map<String, double> get valorPorUbicacion => _agrupar((a) => a.ubicacion);

  Map<String, double> _agrupar(String Function(ActivoHogar) clave) {
    final m = <String, double>{};
    for (final a in _activos) {
      m.update(clave(a), (v) => v + a.valorActualTotal,
          ifAbsent: () => a.valorActualTotal);
    }
    final ordenado = m.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in ordenado) e.key: e.value};
  }

  /// Devuelve un mensaje de error, o null si se agregó.
  String? agregarActivo({
    required String nombre,
    required String categoria,
    required String ubicacion,
    required int cantidad,
    required double costoUnitario,
    required double valorActualUnitario,
    required String estado,
    DateTime? fechaCompra,
    String nota = '',
  }) {
    final nom = nombre.trim();
    if (nom.isEmpty) return 'Escribe el nombre del artículo.';
    if (cantidad < 1) return 'La cantidad debe ser al menos 1.';
    _activos.add(ActivoHogar(
      id: _nuevoId('a'),
      nombre: nom,
      categoria: categoria,
      ubicacion: ubicacion,
      cantidad: cantidad,
      costoUnitario: costoUnitario,
      valorActualUnitario: valorActualUnitario,
      estado: estado,
      fechaCompra: fechaCompra,
      nota: nota.trim(),
    ));
    notifyListeners();
    return null;
  }

  void eliminarActivo(String id) {
    _activos.removeWhere((a) => a.id == id);
    notifyListeners();
  }
}
