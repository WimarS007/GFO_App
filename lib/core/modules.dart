import 'package:flutter/material.dart';

class ModuleInfo {
  const ModuleInfo({
    required this.title,
    required this.description,
    required this.icon,
    required this.group,
    this.complementary = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final String group;
  final bool complementary;
}

/// El orden de esta lista debe coincidir con el orden de las páginas en shell.dart
const modules = <ModuleInfo>[
  ModuleInfo(
    title: 'Panel principal',
    description: 'Resumen de indicadores y acceso a los módulos.',
    icon: Icons.dashboard_outlined,
    group: 'General',
  ),
  ModuleInfo(
    title: 'Estados financieros',
    description: 'Balance General y Estado de Resultados por período.',
    icon: Icons.account_balance_outlined,
    group: 'Unidad 2 · Análisis financiero',
  ),
  ModuleInfo(
    title: 'Análisis financiero',
    description: 'Análisis horizontal y vertical, razones financieras y DuPont.',
    icon: Icons.analytics_outlined,
    group: 'Unidad 2 · Análisis financiero',
  ),
  ModuleInfo(
    title: 'Punto de equilibrio y C-V-U',
    description: 'Margen de contribución, punto de equilibrio y escenarios.',
    icon: Icons.show_chart,
    group: 'Unidad 2 · Análisis financiero',
  ),
  ModuleInfo(
    title: 'Apalancamiento',
    description: 'Grado de apalancamiento operativo, financiero y total.',
    icon: Icons.compare_arrows,
    group: 'Unidad 2 · Análisis financiero',
  ),
  ModuleInfo(
    title: 'Flujo de efectivo',
    description: 'Actividades de operación, inversión y financiamiento.',
    icon: Icons.currency_exchange,
    group: 'Unidad 3 · Planeación financiera',
  ),
  ModuleInfo(
    title: 'Planeación y presupuestos',
    description: 'Ventas, compras, costo de bienes vendidos, gastos y caja.',
    icon: Icons.event_note_outlined,
    group: 'Unidad 3 · Planeación financiera',
  ),
  ModuleInfo(
    title: 'Proforma / reporte integrado',
    description: 'Resumen financiero y proyección para la toma de decisiones.',
    icon: Icons.summarize_outlined,
    group: 'Unidad 3 · Planeación financiera',
  ),
  ModuleInfo(
    title: 'Presupuesto personal',
    description: 'Ingresos, gastos, ahorro y saldo disponible.',
    icon: Icons.savings_outlined,
    group: 'Complementarios',
    complementary: true,
  ),
  ModuleInfo(
    title: 'Control de inventario',
    description: 'Existencias, movimientos, valor del inventario y stock mínimo.',
    icon: Icons.inventory_2_outlined,
    group: 'Complementarios',
    complementary: true,
  ),
];
