import 'package:flutter/material.dart';

import '../widgets/common.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  String _tipoMovimiento = 'entrada';

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Control de inventario',
      subtitle:
          'Registro de productos y movimientos, existencia final, valor del inventario y alerta de reposición.',
      children: [
        const InfoBox(
          text:
              'Existencia final = Existencia inicial + Entradas − Salidas   ·   Valor del inventario = Existencia final × Costo unitario',
        ),
        SectionCard(
          title: 'Registrar producto',
          icon: Icons.add_box_outlined,
          child: SpacedColumn(
            children: const [
              ResponsiveGrid(
                minColumnWidth: 200,
                children: [
                  TextFieldBox(label: 'Código'),
                  TextFieldBox(label: 'Nombre del producto'),
                  NumberField(label: 'Costo unitario', prefix: 'C\$ '),
                  NumberField(label: 'Existencia inicial', suffix: 'unidades'),
                  NumberField(label: 'Stock mínimo', suffix: 'unidades'),
                ],
              ),
              ActionButtons(
                primaryLabel: 'Agregar producto',
                primaryIcon: Icons.add,
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Registrar movimiento',
          icon: Icons.swap_vert,
          child: SpacedColumn(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'entrada',
                    label: Text('Entrada'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                  ButtonSegment(
                    value: 'salida',
                    label: Text('Salida'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                ],
                selected: {_tipoMovimiento},
                onSelectionChanged: (s) =>
                    setState(() => _tipoMovimiento = s.first),
              ),
              const ResponsiveGrid(
                minColumnWidth: 200,
                children: [
                  _ProductoSelector(),
                  NumberField(label: 'Cantidad', suffix: 'unidades'),
                  TextFieldBox(label: 'Referencia / nota (opcional)'),
                ],
              ),
              ActionButtons(
                primaryLabel: 'Registrar $_tipoMovimiento',
                primaryIcon: Icons.check,
              ),
            ],
          ),
        ),
        const SectionCard(
          title: 'Inventario actual',
          icon: Icons.inventory_2_outlined,
          child: SpacedColumn(
            children: [
              ReadOnlyTable(
                firstColumnLabel: 'Producto',
                columns: [
                  'Exist. inicial',
                  'Entradas',
                  'Salidas',
                  'Exist. final',
                  'Stock mínimo',
                  'Costo unit. (C\$)',
                  'Valor (C\$)',
                  'Estado',
                ],
                rows: ['—', '—'],
              ),
              Wrap(
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
        ),
        const SectionCard(
          title: 'Resumen',
          icon: Icons.calculate_outlined,
          child: ResponsiveGrid(
            minColumnWidth: 220,
            children: [
              ResultTile(label: 'Valor total del inventario', unit: 'C\$'),
              ResultTile(label: 'Productos por reponer', unit: 'productos'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductoSelector extends StatelessWidget {
  const _ProductoSelector();

  @override
  Widget build(BuildContext context) {
    return const DropdownMenu<String>(
      label: Text('Producto'),
      expandedInsets: EdgeInsets.zero,
      dropdownMenuEntries: [],
    );
  }
}
