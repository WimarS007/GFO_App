import 'package:flutter/material.dart';

import '../widgets/common.dart';

class CvuScreen extends StatelessWidget {
  const CvuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Punto de equilibrio y C-V-U',
      subtitle:
          'Relación costo-volumen-utilidad: margen de contribución, punto de equilibrio y análisis de escenarios.',
      children: [
        const SectionCard(
          title: 'Datos de entrada',
          icon: Icons.edit_note,
          child: ResponsiveGrid(
            minColumnWidth: 220,
            children: [
              NumberField(label: 'Precio de venta unitario', prefix: 'C\$ '),
              NumberField(label: 'Costo variable unitario', prefix: 'C\$ '),
              NumberField(label: 'Costos fijos totales', prefix: 'C\$ '),
              NumberField(label: 'Unidades vendidas', suffix: 'unidades'),
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
              ResultTile(label: 'Margen de contribución unitario', unit: 'C\$'),
              ResultTile(label: 'Razón de margen de contribución', unit: '%'),
              ResultTile(label: 'Punto de equilibrio', unit: 'unidades'),
              ResultTile(label: 'Punto de equilibrio', unit: 'C\$'),
              ResultTile(label: 'Utilidad operativa', unit: 'C\$'),
              ResultTile(label: 'Margen de seguridad', unit: '%'),
            ],
          ),
        ),
        const ChartPlaceholder(
          label: 'Ingresos vs. costos totales',
          icon: Icons.show_chart,
          height: 240,
        ),
        const SectionCard(
          title: 'Análisis de escenarios',
          icon: Icons.tune,
          subtitle: 'Indica el cambio porcentual de cada variable (puede ser negativo).',
          child: SpacedColumn(
            children: [
              ResponsiveGrid(
                minColumnWidth: 200,
                children: [
                  NumberField(label: 'Cambio en precio', suffix: '%'),
                  NumberField(label: 'Cambio en costo variable', suffix: '%'),
                  NumberField(label: 'Cambio en costos fijos', suffix: '%'),
                  NumberField(label: 'Cambio en volumen', suffix: '%'),
                ],
              ),
              ActionButtons(
                primaryLabel: 'Simular escenario',
                primaryIcon: Icons.play_arrow,
              ),
              ReadOnlyTable(
                columns: ['Base', 'Escenario', 'Diferencia'],
                rows: [
                  'Margen de contribución unitario (C\$)',
                  'Punto de equilibrio (unidades)',
                  'Punto de equilibrio (C\$)',
                  'Utilidad operativa (C\$)',
                ],
              ),
            ],
          ),
        ),
        const InfoBox(
          icon: Icons.lightbulb_outline,
          text:
              'Interpretación: aquí se explicará cuántas unidades se deben vender para cubrir los costos y el efecto del escenario.',
        ),
      ],
    );
  }
}
