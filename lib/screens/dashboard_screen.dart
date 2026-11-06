import 'package:flutter/material.dart';

import '../analisis/analisis_calculos.dart';
import '../core/indicadores_compartidos.dart';
import '../core/modules.dart';
import '../estados/estados_controller.dart';
import '../estados/estados_models.dart';
import '../estados/montos.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.onOpen,
    required this.estados,
    required this.indicadores,
  });

  final ValueChanged<int> onOpen;
  final EstadosController estados;
  final IndicadoresCompartidos indicadores;

  static String _fmt(double? v) => v == null ? '—' : v.toStringAsFixed(2);

  static double? _buscar(List<Razon> razones, String nombre) {
    for (final r in razones) {
      if (r.nombre == nombre) return r.actual;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([estados, indicadores]),
      builder: (context, _) {
        final analisis = AnalisisFinanciero(estados);
        final razonCorriente = _buscar(analisis.liquidez(), 'Razón corriente');
        final margenNeto = _buscar(analisis.rentabilidad(), 'Margen neto');
        final roeFraccion = analisis.dupont(Periodo.actual).roe;
        final pe = indicadores.puntoEquilibrioUnidades;
        final periodo = estados.etiqueta(Periodo.actual);

        return PageScaffold(
          title: 'Panel principal',
          subtitle: 'Sistema de Análisis y Planeación Financiera',
          children: [
            SectionCard(
              title: 'Indicadores clave',
              icon: Icons.speed,
              subtitle:
                  'Se actualizan con los datos de los módulos. Estados financieros: $periodo.',
              child: ResponsiveGrid(
                minColumnWidth: 200,
                children: [
                  ResultTile(
                    label: 'Razón corriente',
                    unit: 'veces',
                    value: _fmt(razonCorriente),
                    detail: 'Estados financieros',
                  ),
                  ResultTile(
                    label: 'Margen neto',
                    unit: '%',
                    value: _fmt(margenNeto),
                    detail: 'Estados financieros',
                  ),
                  ResultTile(
                    label: 'ROE (DuPont)',
                    unit: '%',
                    value: _fmt(roeFraccion == null ? null : roeFraccion * 100),
                    detail: 'Estados financieros',
                  ),
                  ResultTile(
                    label: 'Punto de equilibrio',
                    unit: 'unidades',
                    value: pe == null ? '—' : formatoMonto(pe),
                    detail: 'Módulo C-V-U',
                  ),
                  ResultTile(
                    label: 'Grado de apalancamiento total',
                    unit: 'veces',
                    value: _fmt(indicadores.gat),
                    detail: 'Módulo Apalancamiento',
                  ),
                  ResultTile(
                    label: 'Saldo de efectivo proyectado',
                    unit: 'C\$',
                    value: indicadores.saldoEfectivoProyectado == null
                        ? '—'
                        : formatoMonto(indicadores.saldoEfectivoProyectado!),
                    detail: 'Planeación y presupuestos (T4)',
                  ),
                  ResultTile(
                    label: 'Saldo disponible personal',
                    unit: 'C\$',
                    value: indicadores.saldoPersonal == null
                        ? '—'
                        : formatoMonto(indicadores.saldoPersonal!),
                    detail: 'Presupuesto personal',
                  ),
                  const ResultTile(
                    label: 'Valor del inventario',
                    unit: 'C\$',
                    detail: 'Módulo pendiente',
                  ),
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
      },
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
