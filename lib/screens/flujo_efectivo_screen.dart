import 'package:flutter/material.dart';

import '../widgets/common.dart';

class FlujoEfectivoScreen extends StatelessWidget {
  const FlujoEfectivoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Flujo de efectivo',
      subtitle:
          'Entradas y salidas de efectivo clasificadas en actividades de operación, inversión y financiamiento.',
      children: [
        const SectionCard(
          title: 'Saldo inicial',
          child: ResponsiveGrid(
            minColumnWidth: 240,
            children: [
              NumberField(label: 'Saldo inicial de efectivo', prefix: 'C\$ '),
            ],
          ),
        ),
        const SectionCard(
          title: 'Actividades de operación',
          icon: Icons.store_outlined,
          child: SpacedColumn(
            children: [
              AccountTable(
                title: 'Entradas',
                rows: ['Cobros a clientes', 'Otros cobros de operación'],
                totalLabel: 'Total entradas',
              ),
              AccountTable(
                title: 'Salidas',
                rows: [
                  'Pagos a proveedores',
                  'Pagos de gastos de operación',
                  'Pago de impuestos',
                ],
                totalLabel: 'Total salidas',
              ),
            ],
          ),
        ),
        const SectionCard(
          title: 'Actividades de inversión',
          icon: Icons.precision_manufacturing_outlined,
          child: SpacedColumn(
            children: [
              AccountTable(
                title: 'Entradas',
                rows: ['Venta de activos fijos'],
                totalLabel: 'Total entradas',
              ),
              AccountTable(
                title: 'Salidas',
                rows: ['Compra de activos fijos'],
                totalLabel: 'Total salidas',
              ),
            ],
          ),
        ),
        const SectionCard(
          title: 'Actividades de financiamiento',
          icon: Icons.account_balance_outlined,
          child: SpacedColumn(
            children: [
              AccountTable(
                title: 'Entradas',
                rows: ['Préstamos recibidos', 'Aportes de capital'],
                totalLabel: 'Total entradas',
              ),
              AccountTable(
                title: 'Salidas',
                rows: [
                  'Pago de préstamos',
                  'Pago de intereses',
                  'Pago de dividendos',
                ],
                totalLabel: 'Total salidas',
              ),
            ],
          ),
        ),
        const ActionButtons(),
        const SectionCard(
          title: 'Resultados',
          icon: Icons.calculate_outlined,
          child: ResponsiveGrid(
            minColumnWidth: 220,
            children: [
              ResultTile(label: 'Flujo neto de operación', unit: 'C\$'),
              ResultTile(label: 'Flujo neto de inversión', unit: 'C\$'),
              ResultTile(label: 'Flujo neto de financiamiento', unit: 'C\$'),
              ResultTile(label: 'Variación neta de efectivo', unit: 'C\$'),
              ResultTile(label: 'Saldo final de efectivo', unit: 'C\$'),
            ],
          ),
        ),
      ],
    );
  }
}
