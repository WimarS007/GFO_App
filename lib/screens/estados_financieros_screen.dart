import 'package:flutter/material.dart';

import '../widgets/common.dart';

class EstadosFinancierosScreen extends StatelessWidget {
  const EstadosFinancierosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Estados financieros',
      subtitle:
          'Registra el Balance General y el Estado de Resultados. Estos datos alimentan los demás módulos.',
      children: [
        SectionCard(
          title: 'Datos generales',
          icon: Icons.business,
          child: const ResponsiveGrid(
            minColumnWidth: 220,
            children: [
              TextFieldBox(label: 'Nombre de la empresa'),
              TextFieldBox(label: 'Período anterior', hint: 'Ej. 2024'),
              TextFieldBox(label: 'Período actual', hint: 'Ej. 2025'),
            ],
          ),
        ),
        const TabSwitcher(
          labels: ['Balance General', 'Estado de Resultados'],
          pages: [_BalanceGeneral(), _EstadoResultados()],
        ),
      ],
    );
  }
}

const _periodos = ['Período anterior', 'Período actual'];

class _BalanceGeneral extends StatelessWidget {
  const _BalanceGeneral();

  @override
  Widget build(BuildContext context) {
    return SpacedColumn(
      children: [
        const SectionCard(
          title: 'Activos',
          child: AccountTable(
            columns: _periodos,
            rows: [
              'Efectivo y equivalentes',
              'Cuentas por cobrar',
              'Inventarios',
              'Otros activos corrientes',
              'Propiedad, planta y equipo (neto)',
              'Otros activos no corrientes',
            ],
            totalLabel: 'Total activos',
          ),
        ),
        const SectionCard(
          title: 'Pasivos',
          child: AccountTable(
            columns: _periodos,
            rows: [
              'Cuentas por pagar',
              'Préstamos a corto plazo',
              'Otros pasivos corrientes',
              'Préstamos a largo plazo',
            ],
            totalLabel: 'Total pasivos',
          ),
        ),
        const SectionCard(
          title: 'Patrimonio',
          child: AccountTable(
            columns: _periodos,
            rows: ['Capital social', 'Utilidades retenidas'],
            totalLabel: 'Total patrimonio',
          ),
        ),
        const SectionCard(
          title: 'Verificación',
          icon: Icons.fact_check_outlined,
          child: ResponsiveGrid(
            minColumnWidth: 240,
            children: [
              ResultTile(label: 'Pasivo + Patrimonio', unit: 'C\$'),
              ResultTile(label: 'Activo = Pasivo + Patrimonio'),
            ],
          ),
        ),
        const ActionButtons(
          primaryLabel: 'Guardar balance',
          primaryIcon: Icons.save_outlined,
        ),
      ],
    );
  }
}

class _EstadoResultados extends StatelessWidget {
  const _EstadoResultados();

  @override
  Widget build(BuildContext context) {
    return SpacedColumn(
      children: [
        const SectionCard(
          title: 'Cuentas del estado de resultados',
          child: AccountTable(
            columns: _periodos,
            rows: [
              'Ventas netas',
              'Costo de ventas',
              'Gastos de operación',
              'Otros ingresos (gastos)',
              'Gastos por intereses',
              'Impuesto sobre la renta',
            ],
          ),
        ),
        const SectionCard(
          title: 'Resultados (período actual)',
          icon: Icons.calculate_outlined,
          child: ResponsiveGrid(
            minColumnWidth: 200,
            children: [
              ResultTile(label: 'Utilidad bruta', unit: 'C\$'),
              ResultTile(label: 'UAII', unit: 'C\$'),
              ResultTile(label: 'Utilidad antes de impuestos', unit: 'C\$'),
              ResultTile(label: 'Utilidad neta', unit: 'C\$'),
            ],
          ),
        ),
        const ActionButtons(
          primaryLabel: 'Guardar estado de resultados',
          primaryIcon: Icons.save_outlined,
        ),
      ],
    );
  }
}
