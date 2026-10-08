import 'package:flutter/material.dart';

import '../widgets/common.dart';

class AnalisisFinancieroScreen extends StatelessWidget {
  const AnalisisFinancieroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Análisis financiero',
      subtitle:
          'Análisis horizontal y vertical, razones financieras y sistema DuPont con los datos de los estados financieros.',
      children: const [
        InfoBox(
          text:
              'Los datos se toman del módulo Estados financieros. Aquí solo se muestran los resultados.',
        ),
        TabSwitcher(
          labels: ['Horizontal', 'Vertical', 'Razones financieras', 'DuPont'],
          pages: [_Horizontal(), _Vertical(), _Razones(), _DuPont()],
        ),
      ],
    );
  }
}

class _Horizontal extends StatelessWidget {
  const _Horizontal();

  @override
  Widget build(BuildContext context) {
    return const SectionCard(
      title: 'Análisis horizontal',
      subtitle: 'Variación absoluta y relativa entre períodos.',
      child: ReadOnlyTable(
        firstColumnLabel: 'Cuenta',
        columns: [
          'Período anterior',
          'Período actual',
          'Variación (C\$)',
          'Variación (%)',
        ],
        rows: [
          'Efectivo y equivalentes',
          'Cuentas por cobrar',
          'Inventarios',
          'Activos fijos netos',
          'Total activos',
          'Cuentas por pagar',
          'Préstamos',
          'Total patrimonio',
          'Ventas netas',
          'Costo de ventas',
          'Utilidad bruta',
          'UAII',
          'Utilidad neta',
        ],
      ),
    );
  }
}

class _Vertical extends StatelessWidget {
  const _Vertical();

  @override
  Widget build(BuildContext context) {
    return const SpacedColumn(
      children: [
        SectionCard(
          title: 'Análisis vertical · Balance General',
          subtitle: 'Cada cuenta como porcentaje del total de activos.',
          child: ReadOnlyTable(
            firstColumnLabel: 'Cuenta',
            columns: ['Período anterior (%)', 'Período actual (%)'],
            rows: [
              'Efectivo y equivalentes',
              'Cuentas por cobrar',
              'Inventarios',
              'Activos fijos netos',
              'Cuentas por pagar',
              'Préstamos',
              'Patrimonio',
            ],
          ),
        ),
        SectionCard(
          title: 'Análisis vertical · Estado de Resultados',
          subtitle: 'Cada cuenta como porcentaje de las ventas netas.',
          child: ReadOnlyTable(
            firstColumnLabel: 'Cuenta',
            columns: ['Período anterior (%)', 'Período actual (%)'],
            rows: [
              'Ventas netas',
              'Costo de ventas',
              'Utilidad bruta',
              'Gastos de operación',
              'UAII',
              'Utilidad neta',
            ],
          ),
        ),
      ],
    );
  }
}

class _Razones extends StatelessWidget {
  const _Razones();

  @override
  Widget build(BuildContext context) {
    return const SpacedColumn(
      children: [
        SectionCard(
          title: 'Liquidez',
          icon: Icons.water_drop_outlined,
          child: ResponsiveGrid(
            minColumnWidth: 220,
            children: [
              ResultTile(label: 'Razón corriente', unit: 'veces'),
              ResultTile(label: 'Prueba ácida', unit: 'veces'),
              ResultTile(label: 'Capital de trabajo neto', unit: 'C\$'),
            ],
          ),
        ),
        SectionCard(
          title: 'Actividad',
          icon: Icons.autorenew,
          child: ResponsiveGrid(
            minColumnWidth: 220,
            children: [
              ResultTile(label: 'Rotación de inventarios', unit: 'veces'),
              ResultTile(label: 'Período promedio de cobro', unit: 'días'),
              ResultTile(label: 'Período promedio de pago', unit: 'días'),
              ResultTile(label: 'Rotación de activos totales', unit: 'veces'),
            ],
          ),
        ),
        SectionCard(
          title: 'Endeudamiento',
          icon: Icons.account_balance_outlined,
          child: ResponsiveGrid(
            minColumnWidth: 220,
            children: [
              ResultTile(label: 'Razón de deuda', unit: '%'),
              ResultTile(label: 'Deuda / Patrimonio', unit: 'veces'),
              ResultTile(label: 'Cobertura de intereses', unit: 'veces'),
            ],
          ),
        ),
        SectionCard(
          title: 'Rentabilidad',
          icon: Icons.trending_up,
          child: ResponsiveGrid(
            minColumnWidth: 220,
            children: [
              ResultTile(label: 'Margen bruto', unit: '%'),
              ResultTile(label: 'Margen operativo', unit: '%'),
              ResultTile(label: 'Margen neto', unit: '%'),
              ResultTile(label: 'ROA', unit: '%'),
              ResultTile(label: 'ROE', unit: '%'),
            ],
          ),
        ),
        SectionCard(
          title: 'Mercado (opcional)',
          icon: Icons.candlestick_chart_outlined,
          subtitle: 'Requiere datos adicionales; complétalos solo si los tienes.',
          child: SpacedColumn(
            children: [
              ResponsiveGrid(
                minColumnWidth: 220,
                children: [
                  NumberField(label: 'Acciones en circulación', suffix: 'acciones'),
                  NumberField(label: 'Precio de mercado por acción', prefix: 'C\$ '),
                ],
              ),
              ResponsiveGrid(
                minColumnWidth: 220,
                children: [
                  ResultTile(label: 'Utilidad por acción (UPA)', unit: 'C\$'),
                  ResultTile(label: 'Precio / Utilidad', unit: 'veces'),
                ],
              ),
            ],
          ),
        ),
        InfoBox(
          icon: Icons.lightbulb_outline,
          text: 'Interpretación: aquí se mostrará una lectura breve de las razones calculadas.',
        ),
      ],
    );
  }
}

class _DuPont extends StatelessWidget {
  const _DuPont();

  @override
  Widget build(BuildContext context) {
    return const SpacedColumn(
      children: [
        InfoBox(
          text:
              'ROE = Margen neto × Rotación de activos × Multiplicador de capital',
        ),
        SectionCard(
          title: 'Sistema DuPont',
          icon: Icons.account_tree_outlined,
          child: ResponsiveGrid(
            minColumnWidth: 220,
            children: [
              ResultTile(label: 'Margen neto', unit: '%'),
              ResultTile(label: 'Rotación de activos', unit: 'veces'),
              ResultTile(label: 'Multiplicador de capital', unit: 'veces'),
              ResultTile(label: 'ROE', unit: '%'),
            ],
          ),
        ),
        InfoBox(
          icon: Icons.lightbulb_outline,
          text:
              'Interpretación: aquí se indicará qué componente explica mejor el rendimiento sobre el patrimonio.',
        ),
      ],
    );
  }
}
