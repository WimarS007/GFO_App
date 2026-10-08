import 'package:flutter/material.dart';

import '../widgets/common.dart';

const _trimestres = ['T1', 'T2', 'T3', 'T4'];
const _trimestresTotal = ['T1', 'T2', 'T3', 'T4', 'Total'];

class PlaneacionPresupuestosScreen extends StatelessWidget {
  const PlaneacionPresupuestosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'Planeación y presupuestos',
      subtitle:
          'Presupuesto de ventas, compras, costo de bienes vendidos, gastos de operación y presupuesto de caja.',
      children: [
        TabSwitcher(
          labels: [
            'Supuestos',
            'Ventas',
            'Compras',
            'Costo de bienes vendidos',
            'Gastos de operación',
            'Caja',
          ],
          pages: [
            _Supuestos(),
            _Ventas(),
            _Compras(),
            _CostoBienesVendidos(),
            _GastosOperacion(),
            _Caja(),
          ],
        ),
      ],
    );
  }
}

class _Supuestos extends StatelessWidget {
  const _Supuestos();

  @override
  Widget build(BuildContext context) {
    return const SpacedColumn(
      children: [
        SectionCard(
          title: 'Proyección de ventas',
          child: AccountTable(
            columns: _trimestres,
            rows: ['Unidades a vender', 'Precio de venta unitario (C\$)'],
          ),
        ),
        SectionCard(
          title: 'Supuestos de cobro, compras y caja',
          child: ResponsiveGrid(
            minColumnWidth: 240,
            children: [
              NumberField(label: 'Ventas al contado', suffix: '%'),
              NumberField(label: 'Ventas a crédito cobradas en el siguiente trimestre', suffix: '%'),
              NumberField(label: 'Costo unitario de compra', prefix: 'C\$ '),
              NumberField(label: 'Inventario final deseado (% de ventas siguientes)', suffix: '%'),
              NumberField(label: 'Inventario inicial', suffix: 'unidades'),
              NumberField(label: 'Compras pagadas al contado', suffix: '%'),
              NumberField(label: 'Saldo inicial de caja', prefix: 'C\$ '),
              NumberField(label: 'Saldo mínimo de caja', prefix: 'C\$ '),
            ],
          ),
        ),
        ActionButtons(
          primaryLabel: 'Generar presupuestos',
          primaryIcon: Icons.auto_graph,
        ),
      ],
    );
  }
}

class _Ventas extends StatelessWidget {
  const _Ventas();

  @override
  Widget build(BuildContext context) {
    return const SectionCard(
      title: 'Presupuesto de ventas',
      child: ReadOnlyTable(
        columns: _trimestresTotal,
        rows: [
          'Unidades a vender',
          'Precio de venta unitario (C\$)',
          'Ventas totales (C\$)',
          'Ventas al contado (C\$)',
          'Ventas a crédito (C\$)',
        ],
      ),
    );
  }
}

class _Compras extends StatelessWidget {
  const _Compras();

  @override
  Widget build(BuildContext context) {
    return const SectionCard(
      title: 'Presupuesto de compras',
      child: ReadOnlyTable(
        columns: _trimestresTotal,
        rows: [
          'Unidades a vender',
          '(+) Inventario final deseado',
          '(−) Inventario inicial',
          'Unidades a comprar',
          'Costo unitario (C\$)',
          'Compras totales (C\$)',
        ],
      ),
    );
  }
}

class _CostoBienesVendidos extends StatelessWidget {
  const _CostoBienesVendidos();

  @override
  Widget build(BuildContext context) {
    return const SectionCard(
      title: 'Presupuesto del costo de bienes vendidos',
      child: ReadOnlyTable(
        columns: _trimestresTotal,
        rows: [
          'Inventario inicial (C\$)',
          '(+) Compras (C\$)',
          '(−) Inventario final (C\$)',
          'Costo de bienes vendidos (C\$)',
        ],
      ),
    );
  }
}

class _GastosOperacion extends StatelessWidget {
  const _GastosOperacion();

  @override
  Widget build(BuildContext context) {
    return const SpacedColumn(
      children: [
        SectionCard(
          title: 'Presupuesto de gastos de operación',
          child: AccountTable(
            columns: _trimestres,
            rows: [
              'Gastos de administración',
              'Gastos de ventas',
              'Depreciación',
              'Otros gastos',
            ],
            totalLabel: 'Total gastos de operación',
          ),
        ),
        ActionButtons(
          primaryLabel: 'Actualizar',
          primaryIcon: Icons.refresh,
        ),
      ],
    );
  }
}

class _Caja extends StatelessWidget {
  const _Caja();

  @override
  Widget build(BuildContext context) {
    return const SpacedColumn(
      children: [
        SectionCard(
          title: 'Presupuesto de caja',
          child: ReadOnlyTable(
            columns: _trimestres,
            rows: [
              'Saldo inicial de caja',
              '(+) Cobros de ventas',
              '(−) Pagos de compras',
              '(−) Pagos de gastos de operación',
              'Saldo antes de financiamiento',
              'Financiamiento requerido',
              'Saldo final de efectivo',
            ],
          ),
        ),
        InfoBox(
          icon: Icons.lightbulb_outline,
          text:
              'Interpretación: aquí se indicará si hay trimestres con efectivo insuficiente y cuánto financiamiento se necesitaría.',
        ),
      ],
    );
  }
}
