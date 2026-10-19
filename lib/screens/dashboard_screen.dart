import 'package:flutter/material.dart';

import '../core/modules.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onOpen});

  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Panel principal',
      subtitle: 'Sistema de Análisis y Planeación Financiera · IS2122',
      children: [
        SectionCard(
          title: 'Indicadores clave',
          icon: Icons.speed,
          subtitle: 'Se mostrarán con los resultados de los módulos.',
          child: const ResponsiveGrid(
            minColumnWidth: 200,
            children: [
              ResultTile(label: 'Razón corriente', unit: 'veces'),
              ResultTile(label: 'Margen neto', unit: '%'),
              ResultTile(label: 'ROE (DuPont)', unit: '%'),
              ResultTile(label: 'Punto de equilibrio', unit: 'unidades'),
              ResultTile(label: 'Grado de apalancamiento total', unit: 'veces'),
              ResultTile(label: 'Saldo de efectivo proyectado', unit: 'C\$'),
              ResultTile(label: 'Saldo disponible personal', unit: 'C\$'),
              ResultTile(label: 'Valor del inventario', unit: 'C\$'),
            ],
          ),
        ),
        SectionCard(
          title: 'Módulos',
          icon: Icons.apps,
          child: ResponsiveGrid(
            minColumnWidth: 280,
            children: [
              for (var i = 1; i < modules.length; i++)
                _ModuleCard(info: modules[i], onTap: () => onOpen(i)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.info, required this.onTap});

  final ModuleInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: Icon(info.icon),
                  ),
                  const Spacer(),
                  if (info.complementary)
                    const Chip(
                      label: Text('Complementario'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(info.title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(info.description, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
