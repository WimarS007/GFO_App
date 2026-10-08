import 'package:flutter/material.dart';

import '../widgets/common.dart';

class ProformaScreen extends StatelessWidget {
  const ProformaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Proforma / reporte integrado',
      subtitle:
          'Resumen financiero y proyección construidos con los resultados de los módulos anteriores.',
      children: const [
        InfoBox(
          text:
              'Los datos se toman de los módulos de análisis y planeación. Solo debes indicar los supuestos de proyección.',
        ),
        SectionCard(
          title: 'Supuestos de proyección',
          icon: Icons.tune,
          child: ResponsiveGrid(
            minColumnWidth: 220,
            children: [
              NumberField(label: 'Crecimiento de ventas proyectado', suffix: '%'),
              NumberField(label: 'Variación esperada de costos', suffix: '%'),
              NumberField(label: 'Inversión adicional prevista', prefix: 'C\$ '),
            ],
          ),
        ),
        ActionButtons(
          primaryLabel: 'Generar proforma',
          primaryIcon: Icons.auto_graph,
        ),
        SectionCard(
          title: 'Estado de resultados proforma',
          child: ReadOnlyTable(
            columns: ['Actual', 'Proyectado', 'Variación (%)'],
            rows: [
              'Ventas netas',
              'Costo de ventas',
              'Utilidad bruta',
              'Gastos de operación',
              'UAII',
              'Gastos por intereses',
              'Impuestos',
              'Utilidad neta',
            ],
          ),
        ),
        SectionCard(
          title: 'Resumen de indicadores',
          icon: Icons.dashboard_customize_outlined,
          child: ResponsiveGrid(
            minColumnWidth: 220,
            children: [
              ResultTile(label: 'Utilidad neta proyectada', unit: 'C\$'),
              ResultTile(label: 'ROE proyectado', unit: '%'),
              ResultTile(label: 'Razón corriente proyectada', unit: 'veces'),
              ResultTile(label: 'Punto de equilibrio', unit: 'unidades'),
              ResultTile(label: 'Grado de apalancamiento total', unit: 'veces'),
              ResultTile(label: 'Saldo de efectivo proyectado', unit: 'C\$'),
            ],
          ),
        ),
        SectionCard(
          title: 'Conclusión para la toma de decisiones',
          icon: Icons.edit_note,
          child: TextFieldBox(
            label: 'Conclusiones y recomendaciones',
            hint: 'Escribe aquí la decisión financiera que apoyan los resultados.',
            maxLines: 5,
          ),
        ),
      ],
    );
  }
}
