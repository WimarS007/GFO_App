import 'package:flutter/material.dart';

import '../widgets/common.dart';

class ApalancamientoScreen extends StatefulWidget {
  const ApalancamientoScreen({super.key});

  @override
  State<ApalancamientoScreen> createState() => _ApalancamientoScreenState();
}

class _ApalancamientoScreenState extends State<ApalancamientoScreen> {
  bool _usarEstados = false;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Apalancamiento',
      subtitle:
          'Grado de apalancamiento operativo (GAO), financiero (GAF) y total (GAT).',
      children: [
        SectionCard(
          title: 'Datos de entrada',
          icon: Icons.edit_note,
          child: SpacedColumn(
            gap: 12,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Usar datos de los estados financieros'),
                subtitle: const Text('Ventas, UAII e intereses se toman del módulo de estados.'),
                value: _usarEstados,
                onChanged: (v) => setState(() => _usarEstados = v),
              ),
              const ResponsiveGrid(
                minColumnWidth: 220,
                children: [
                  NumberField(label: 'Ventas', prefix: 'C\$ '),
                  NumberField(label: 'Costos variables totales', prefix: 'C\$ '),
                  NumberField(label: 'Costos fijos', prefix: 'C\$ '),
                  NumberField(label: 'Gastos por intereses', prefix: 'C\$ '),
                  NumberField(label: 'Dividendos preferentes (opcional)', prefix: 'C\$ '),
                  NumberField(label: 'Tasa de impuestos (opcional)', suffix: '%'),
                ],
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
              ResultTile(label: 'UAII', unit: 'C\$'),
              ResultTile(label: 'GAO · Grado de apalancamiento operativo', unit: 'veces'),
              ResultTile(label: 'GAF · Grado de apalancamiento financiero', unit: 'veces'),
              ResultTile(label: 'GAT · Grado de apalancamiento total', unit: 'veces'),
            ],
          ),
        ),
        const InfoBox(
          text: 'GAO = Margen de contribución / UAII   ·   GAF = UAII / (UAII − Intereses)   ·   GAT = GAO × GAF',
        ),
        const InfoBox(
          icon: Icons.lightbulb_outline,
          text:
              'Interpretación: aquí se explicará cuánto cambia la utilidad ante una variación en las ventas.',
        ),
      ],
    );
  }
}
