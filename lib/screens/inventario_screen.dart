import 'package:flutter/material.dart';

import '../estados/montos.dart';
import '../inventario/inventario_controller.dart';
import '../inventario/inventario_models.dart';
import '../widgets/common.dart';

/// Control de inventario con dos pestañas: inventario de productos
/// (existencias, movimientos, valor y stock mínimo) e inventario de activos
/// personales del hogar.
class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key, required this.inventario});

  final InventarioController inventario;

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  InventarioController get _inv => widget.inventario;

  // Formulario de producto
  final _codigo = TextEditingController();
  final _nombre = TextEditingController();
  final _costo = TextEditingController();
  final _existInicial = TextEditingController();
  final _stockMin = TextEditingController();

  // Formulario de movimiento
  TipoMovInv _tipo = TipoMovInv.entrada;
  String? _productoId;
  final _cantidad = TextEditingController();
  final _nota = TextEditingController();
  bool _verTodosMov = false;

  // Formulario de activo del hogar
  final _aNombre = TextEditingController();
  final _aCantidad = TextEditingController(text: '1');
  final _aCosto = TextEditingController();
  final _aValor = TextEditingController();
  final _aNota = TextEditingController();
  String _aCategoria = categoriasActivo.first;
  String _aUbicacion = ubicacionesHogar.first;
  String _aEstado = 'Bueno';
  DateTime? _aFecha;

  @override
  void dispose() {
    for (final c in [
      _codigo,
      _nombre,
      _costo,
      _existInicial,
      _stockMin,
      _cantidad,
      _nota,
      _aNombre,
      _aCantidad,
      _aCosto,
      _aValor,
      _aNota,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------- utilidades

  String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  /// Campo vacío = 0; texto que no es número = null.
  double? _leer(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return 0;
    return parseMonto(t);
  }

  Future<bool> _confirmar(String titulo, String texto, String accion) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(accion)),
        ],
      ),
    );
    return ok == true;
  }

  // ------------------------------------------------------------------ acciones

  void _limpiarProducto() {
    for (final c in [_codigo, _nombre, _costo, _existInicial, _stockMin]) {
      c.clear();
    }
  }

  void _agregarProducto() {
    if (_costo.text.trim().isEmpty) {
      _mensaje('Escribe el costo unitario del producto.');
      return;
    }
    final costo = parseMonto(_costo.text);
    final exist = _leer(_existInicial);
    final minimo = _leer(_stockMin);
    if (costo == null || costo < 0) {
      _mensaje('El costo unitario debe ser un número mayor o igual a cero.');
      return;
    }
    if (exist == null || exist < 0 || minimo == null || minimo < 0) {
      _mensaje(
          'La existencia inicial y el stock mínimo deben ser números mayores o iguales a cero.');
      return;
    }
    final error = _inv.agregarProducto(
      codigo: _codigo.text,
      nombre: _nombre.text,
      costoUnitario: costo,
      existenciaInicial: exist,
      stockMinimo: minimo,
    );
    if (error != null) {
      _mensaje(error);
      return;
    }
    _limpiarProducto();
  }

  Future<void> _eliminarProducto(ProductoInv p) async {
    final ok = await _confirmar(
      'Eliminar producto',
      'Se eliminará "${p.nombre}" y todos sus movimientos. Esta acción no se puede deshacer.',
      'Eliminar',
    );
    if (ok) _inv.eliminarProducto(p.id);
  }

  void _registrarMovimiento() {
    final id = _productoId;
    if (id == null) {
      _mensaje('Primero registra un producto.');
      return;
    }
    final cant = parseMonto(_cantidad.text);
    if (cant == null || cant <= 0) {
      _mensaje('Escribe una cantidad mayor que cero.');
      return;
    }
    final error = _inv.registrarMovimiento(
      productoId: id,
      tipo: _tipo,
      cantidad: cant,
      nota: _nota.text,
    );
    if (error != null) {
      _mensaje(error);
      return;
    }
    _cantidad.clear();
    _nota.clear();
  }

  void _eliminarMovimiento(MovimientoInv m) {
    final error = _inv.eliminarMovimiento(m.id);
    if (error != null) _mensaje(error);
  }

  Future<void> _elegirFechaActivo() async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context,
      initialDate: _aFecha ?? hoy,
      firstDate: DateTime(1990),
      lastDate: hoy,
    );
    if (f == null || !mounted) return;
    setState(() => _aFecha = DateTime(f.year, f.month, f.day));
  }

  void _limpiarActivo() {
    setState(() {
      for (final c in [_aNombre, _aCosto, _aValor, _aNota]) {
        c.clear();
      }
      _aCantidad.text = '1';
      _aCategoria = categoriasActivo.first;
      _aUbicacion = ubicacionesHogar.first;
      _aEstado = 'Bueno';
      _aFecha = null;
    });
  }

  void _agregarActivo() {
    final cantidad = int.tryParse(_aCantidad.text.trim());
    if (cantidad == null || cantidad < 1) {
      _mensaje('La cantidad debe ser un número entero de al menos 1.');
      return;
    }
    final costo = _leer(_aCosto);
    final valor = _leer(_aValor);
    if (costo == null || costo < 0 || valor == null || valor < 0) {
      _mensaje(
          'El costo de compra y el valor actual deben ser números mayores o iguales a cero.');
      return;
    }
    final error = _inv.agregarActivo(
      nombre: _aNombre.text,
      categoria: _aCategoria,
      ubicacion: _aUbicacion,
      cantidad: cantidad,
      costoUnitario: costo,
      valorActualUnitario: valor,
      estado: _aEstado,
      fechaCompra: _aFecha,
      nota: _aNota.text,
    );
    if (error != null) {
      _mensaje(error);
      return;
    }
    _limpiarActivo();
  }

  // --------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _inv,
      builder: (context, _) => PageScaffold(
        title: 'Control de inventario',
        subtitle:
            'Productos con existencias y movimientos, y el inventario de los activos personales de tu hogar.',
        children: [
          TabSwitcher(
            labels: const ['Inventario de productos', 'Activos del hogar'],
            pages: [_pestanaProductos(), _pestanaHogar()],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------- pestaña: productos

  Widget _pestanaProductos() {
    final prods = _inv.productos;
    if (_productoId == null || _inv.productoPorId(_productoId!) == null) {
      _productoId = prods.isEmpty ? null : prods.first.id;
    }
    return SpacedColumn(
      children: [
        const InfoBox(
          text:
              'Existencia final = Existencia inicial + Entradas − Salidas   ·   Valor del inventario = Existencia final × Costo unitario',
        ),
        _registrarProducto(),
        _registrarMovimientoCard(prods),
        _inventarioActual(prods),
        _historialMovimientos(),
        _resumenProductos(),
      ],
    );
  }

  Widget _registrarProducto() {
    return SectionCard(
      title: 'Registrar producto',
      icon: Icons.add_box_outlined,
      child: SpacedColumn(
        children: [
          ResponsiveGrid(
            minColumnWidth: 200,
            children: [
              TextFieldBox(label: 'Código', controller: _codigo),
              TextFieldBox(label: 'Nombre del producto', controller: _nombre),
              NumberField(
                  label: 'Costo unitario', prefix: 'C\$ ', controller: _costo),
              NumberField(
                  label: 'Existencia inicial',
                  suffix: 'unidades',
                  controller: _existInicial),
              NumberField(
                  label: 'Stock mínimo',
                  suffix: 'unidades',
                  controller: _stockMin),
            ],
          ),
          ActionButtons(
            primaryLabel: 'Agregar producto',
            primaryIcon: Icons.add,
            onPrimary: _agregarProducto,
            onClear: _limpiarProducto,
          ),
        ],
      ),
    );
  }

  Widget _registrarMovimientoCard(List<ProductoInv> prods) {
    return SectionCard(
      title: 'Registrar movimiento',
      icon: Icons.swap_vert,
      child: SpacedColumn(
        children: [
          SegmentedButton<TipoMovInv>(
            segments: const [
              ButtonSegment(
                value: TipoMovInv.entrada,
                label: Text('Entrada'),
                icon: Icon(Icons.arrow_downward),
              ),
              ButtonSegment(
                value: TipoMovInv.salida,
                label: Text('Salida'),
                icon: Icon(Icons.arrow_upward),
              ),
            ],
            selected: {_tipo},
            onSelectionChanged: (s) => setState(() => _tipo = s.first),
          ),
          if (prods.isEmpty)
            const InfoBox(
                text: 'Primero registra un producto para poder mover su existencia.')
          else
            ResponsiveGrid(
              minColumnWidth: 200,
              children: [
                DropdownButtonFormField<String>(
                  value: _productoId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Producto', border: OutlineInputBorder()),
                  items: [
                    for (final p in prods)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.codigo} · ${p.nombre}',
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _productoId = v),
                ),
                NumberField(
                    label: 'Cantidad',
                    suffix: 'unidades',
                    controller: _cantidad),
                TextFieldBox(
                    label: 'Referencia / nota (opcional)', controller: _nota),
              ],
            ),
          ActionButtons(
            primaryLabel: 'Registrar ${_tipo.etiqueta.toLowerCase()}',
            primaryIcon: Icons.check,
            onPrimary: _registrarMovimiento,
            onClear: () {
              _cantidad.clear();
              _nota.clear();
            },
          ),
        ],
      ),
    );
  }

  Widget _inventarioActual(List<ProductoInv> prods) {
    final cs = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'Inventario actual',
      icon: Icons.inventory_2_outlined,
      child: prods.isEmpty
          ? const Text('Aún no hay productos. Regístralos arriba.')
          : SpacedColumn(
              gap: 12,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Código')),
                      DataColumn(label: Text('Producto')),
                      DataColumn(label: Text('Exist. inicial'), numeric: true),
                      DataColumn(label: Text('Entradas'), numeric: true),
                      DataColumn(label: Text('Salidas'), numeric: true),
                      DataColumn(label: Text('Exist. final'), numeric: true),
                      DataColumn(label: Text('Stock mínimo'), numeric: true),
                      DataColumn(label: Text('Costo unit. (C\$)'), numeric: true),
                      DataColumn(label: Text('Valor (C\$)'), numeric: true),
                      DataColumn(label: Text('Estado')),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final p in prods)
                        DataRow(cells: [
                          DataCell(Text(p.codigo)),
                          DataCell(Text(p.nombre)),
                          DataCell(Text(cantidadTexto(p.existenciaInicial))),
                          DataCell(Text(cantidadTexto(_inv.entradas(p.id)))),
                          DataCell(Text(cantidadTexto(_inv.salidas(p.id)))),
                          DataCell(Text(cantidadTexto(_inv.existenciaFinal(p)))),
                          DataCell(Text(cantidadTexto(p.stockMinimo))),
                          DataCell(Text(formatoMonto(p.costoUnitario))),
                          DataCell(Text(formatoMonto(_inv.valor(p)))),
                          DataCell(_chipEstado(p, cs)),
                          DataCell(IconButton(
                            tooltip: 'Eliminar producto',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _eliminarProducto(p),
                          )),
                        ]),
                    ],
                  ),
                ),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: Icon(Icons.check_circle_outline),
                      label: Text('Stock suficiente'),
                    ),
                    Chip(
                      avatar: Icon(Icons.warning_amber_rounded),
                      label: Text('Reponer: existencia ≤ stock mínimo'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _chipEstado(ProductoInv p, ColorScheme cs) {
    final reponer = _inv.requiereReposicion(p);
    final color = reponer ? cs.error : cs.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          reponer ? Icons.warning_amber_rounded : Icons.check_circle_outline,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(reponer ? 'Reponer' : 'Suficiente',
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _historialMovimientos() {
    final todos = _inv.movimientos.reversed.toList(); // los últimos primero
    const limite = 15;
    final visibles = _verTodosMov ? todos : todos.take(limite).toList();
    return SectionCard(
      title: 'Historial de movimientos',
      icon: Icons.history,
      subtitle: todos.isEmpty
          ? null
          : '${todos.length} movimientos${todos.length > limite && !_verTodosMov ? ' · se muestran los últimos $limite' : ''}',
      child: todos.isEmpty
          ? const Text('Aún no hay movimientos registrados.')
          : SpacedColumn(
              gap: 10,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Fecha')),
                      DataColumn(label: Text('Producto')),
                      DataColumn(label: Text('Tipo')),
                      DataColumn(label: Text('Cantidad'), numeric: true),
                      DataColumn(label: Text('Nota')),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final m in visibles)
                        DataRow(cells: [
                          DataCell(Text(_fecha(m.fecha))),
                          DataCell(Text(
                              _inv.productoPorId(m.productoId)?.nombre ?? '—')),
                          DataCell(Text(m.tipo.etiqueta)),
                          DataCell(Text(cantidadTexto(m.cantidad))),
                          DataCell(Text(m.nota.isEmpty ? '—' : m.nota)),
                          DataCell(IconButton(
                            tooltip: 'Eliminar movimiento',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _eliminarMovimiento(m),
                          )),
                        ]),
                    ],
                  ),
                ),
                if (todos.length > limite)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _verTodosMov = !_verTodosMov),
                      icon: Icon(
                          _verTodosMov ? Icons.expand_less : Icons.expand_more),
                      label: Text(_verTodosMov ? 'Ver menos' : 'Ver todos'),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _resumenProductos() {
    final hay = _inv.productos.isNotEmpty;
    return SectionCard(
      title: 'Resumen',
      icon: Icons.calculate_outlined,
      child: ResponsiveGrid(
        minColumnWidth: 220,
        children: [
          ResultTile(
            label: 'Valor total del inventario',
            unit: 'C\$',
            value: hay ? formatoMonto(_inv.valorTotal) : '—',
          ),
          ResultTile(
            label: 'Productos por reponer',
            unit: 'productos',
            value: hay ? '${_inv.porReponer}' : '—',
          ),
          ResultTile(
            label: 'Productos registrados',
            value: hay ? '${_inv.productos.length}' : '—',
            detail: hay
                ? '${cantidadTexto(_inv.unidadesTotales)} unidades en existencia'
                : null,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------ pestaña: activos del hogar

  Widget _pestanaHogar() {
    return SpacedColumn(
      children: [
        const InfoBox(
          text:
              'Lleva el inventario de lo que tienes en casa (electrodomésticos, muebles, electrónica...). Valor actual total = Cantidad × Valor actual estimado   ·   Depreciación = Costo de compra − Valor actual',
        ),
        _registrarActivo(),
        _listaActivos(),
        _resumenHogar(),
      ],
    );
  }

  Widget _registrarActivo() {
    return SectionCard(
      title: 'Registrar activo del hogar',
      icon: Icons.chair_outlined,
      child: SpacedColumn(
        children: [
          ResponsiveGrid(
            minColumnWidth: 200,
            children: [
              TextFieldBox(label: 'Artículo', controller: _aNombre),
              DropdownButtonFormField<String>(
                value: _aCategoria,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Categoría', border: OutlineInputBorder()),
                items: [
                  for (final c in categoriasActivo)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _aCategoria = v);
                },
              ),
              DropdownButtonFormField<String>(
                value: _aUbicacion,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Ubicación en la casa',
                    border: OutlineInputBorder()),
                items: [
                  for (final u in ubicacionesHogar)
                    DropdownMenuItem(value: u, child: Text(u)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _aUbicacion = v);
                },
              ),
              NumberField(
                  label: 'Cantidad', suffix: 'unidades', controller: _aCantidad),
              NumberField(
                  label: 'Costo de compra (por unidad)',
                  prefix: 'C\$ ',
                  controller: _aCosto),
              NumberField(
                  label: 'Valor actual estimado (por unidad)',
                  prefix: 'C\$ ',
                  controller: _aValor),
              DropdownButtonFormField<String>(
                value: _aEstado,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Estado', border: OutlineInputBorder()),
                items: [
                  for (final e in estadosActivo)
                    DropdownMenuItem(value: e, child: Text(e)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _aEstado = v);
                },
              ),
              InkWell(
                onTap: _elegirFechaActivo,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fecha de compra (opcional)',
                    border: const OutlineInputBorder(),
                    suffixIcon: _aFecha == null
                        ? const Icon(Icons.event, size: 18)
                        : IconButton(
                            tooltip: 'Quitar fecha',
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _aFecha = null),
                          ),
                  ),
                  child: Text(_aFecha == null ? 'Sin fecha' : _fecha(_aFecha!)),
                ),
              ),
              TextFieldBox(label: 'Nota (opcional)', controller: _aNota),
            ],
          ),
          ActionButtons(
            primaryLabel: 'Agregar activo',
            primaryIcon: Icons.add,
            onPrimary: _agregarActivo,
            onClear: _limpiarActivo,
          ),
        ],
      ),
    );
  }

  Widget _listaActivos() {
    final activos = _inv.activos;
    return SectionCard(
      title: 'Inventario del hogar',
      icon: Icons.home_outlined,
      subtitle: activos.isEmpty ? null : '${activos.length} artículos registrados',
      child: activos.isEmpty
          ? const Text('Aún no hay activos. Regístralos arriba.')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Artículo')),
                  DataColumn(label: Text('Categoría')),
                  DataColumn(label: Text('Ubicación')),
                  DataColumn(label: Text('Cant.'), numeric: true),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Fecha de compra')),
                  DataColumn(label: Text('Costo total (C\$)'), numeric: true),
                  DataColumn(label: Text('Valor actual (C\$)'), numeric: true),
                  DataColumn(label: Text('Nota')),
                  DataColumn(label: Text('')),
                ],
                rows: [
                  for (final a in activos)
                    DataRow(cells: [
                      DataCell(Text(a.nombre)),
                      DataCell(Text(a.categoria)),
                      DataCell(Text(a.ubicacion)),
                      DataCell(Text('${a.cantidad}')),
                      DataCell(Text(a.estado)),
                      DataCell(Text(
                          a.fechaCompra == null ? '—' : _fecha(a.fechaCompra!))),
                      DataCell(Text(formatoMonto(a.costoTotal))),
                      DataCell(Text(formatoMonto(a.valorActualTotal))),
                      DataCell(Text(a.nota.isEmpty ? '—' : a.nota)),
                      DataCell(IconButton(
                        tooltip: 'Eliminar activo',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _inv.eliminarActivo(a.id),
                      )),
                    ]),
                ],
              ),
            ),
    );
  }

  Widget _resumenHogar() {
    final hay = _inv.activos.isNotEmpty;
    return SectionCard(
      title: 'Resumen del hogar',
      icon: Icons.calculate_outlined,
      child: SpacedColumn(
        children: [
          ResponsiveGrid(
            minColumnWidth: 220,
            children: [
              ResultTile(
                label: 'Total de artículos',
                value: hay ? '${_inv.totalArticulos}' : '—',
              ),
              ResultTile(
                label: 'Costo de compra total',
                unit: 'C\$',
                value: hay ? formatoMonto(_inv.costoTotalActivos) : '—',
              ),
              ResultTile(
                label: 'Valor actual estimado',
                unit: 'C\$',
                value: hay ? formatoMonto(_inv.valorActualActivos) : '—',
              ),
              ResultTile(
                label: 'Depreciación acumulada',
                unit: 'C\$',
                value: hay ? formatoMonto(_inv.depreciacionActivos) : '—',
              ),
            ],
          ),
          if (hay)
            ResponsiveGrid(
              minColumnWidth: 320,
              children: [
                _tablaAgrupada('Valor por categoría', 'Categoría',
                    _inv.valorPorCategoria),
                _tablaAgrupada('Valor por ubicación', 'Ubicación',
                    _inv.valorPorUbicacion),
              ],
            ),
        ],
      ),
    );
  }

  Widget _tablaAgrupada(
      String titulo, String columna, Map<String, double> datos) {
    final total = _inv.valorActualActivos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text(columna)),
              const DataColumn(label: Text('Valor actual (C\$)'), numeric: true),
              const DataColumn(label: Text('% del total'), numeric: true),
            ],
            rows: [
              for (final e in datos.entries)
                DataRow(cells: [
                  DataCell(Text(e.key)),
                  DataCell(Text(formatoMonto(e.value))),
                  DataCell(Text(total > 0
                      ? '${(e.value / total * 100).toStringAsFixed(1)}%'
                      : '—')),
                ]),
            ],
          ),
        ),
      ],
    );
  }
}
