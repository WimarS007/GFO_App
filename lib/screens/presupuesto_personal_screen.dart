import 'package:flutter/material.dart';

import '../widgets/common.dart';

class PresupuestoPersonalScreen extends StatelessWidget {
  const PresupuestoPersonalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Presupuesto personal',
      subtitle:
          'Ingresos, gastos, ahorro y saldo disponible. Módulo independiente del presupuesto maestro empresarial.',
      children: const [
        InfoBox(
          text: 'Para la demostración puedes usar datos personales ficticios.',
        ),
        SectionCard(
          title: 'Ingresos mensuales',
          icon: Icons.south_west,
          child: AccountTable(
            columns: ['Monto mensual (C\$)'],
            rows: ['Salario', 'Ingresos extra', 'Otros ingresos'],
            totalLabel: 'Total ingresos',
          ),
        ),
        SectionCard(
          title: 'Gastos mensuales por categoría',
          icon: Icons.north_east,
          child: AccountTable(
            columns: ['Monto mensual (C\$)'],
            rows: [
              'Vivienda',
              'Alimentación',
              'Transporte',
              'Servicios básicos',
              'Educación',
              'Salud',
              'Entretenimiento',
              'Pago de deudas',
              'Otros gastos',
            ],
            totalLabel: 'Total gastos',
          ),
        ),
        ActionButtons(),
        SectionCard(
          title: 'Resumen mensual',
          icon: Icons.calculate_outlined,
          child: ResponsiveGrid(
            minColumnWidth: 220,
            children: [
              ResultTile(label: 'Total de ingresos', unit: 'C\$'),
              ResultTile(label: 'Total de gastos', unit: 'C\$'),
              ResultTile(label: 'Saldo disponible', unit: 'C\$'),
              ResultTile(label: 'Capacidad de ahorro', unit: '%'),
            ],
          ),
        ),
        ChartPlaceholder(
          label: 'Distribución de gastos por categoría',
          icon: Icons.pie_chart_outline,
          height: 240,
        ),
        InfoBox(
          icon: Icons.lightbulb_outline,
          text:
              'Interpretación: aquí se indicará si el saldo es positivo y qué categorías concentran más gasto.',
        ),
      ],
    );
  }
}
