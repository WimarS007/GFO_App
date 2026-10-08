import 'package:flutter/material.dart';

import '../core/modules.dart';
import 'analisis_financiero_screen.dart';
import 'apalancamiento_screen.dart';
import 'cvu_screen.dart';
import 'dashboard_screen.dart';
import 'estados_financieros_screen.dart';
import 'flujo_efectivo_screen.dart';
import 'inventario_screen.dart';
import 'planeacion_presupuestos_screen.dart';
import 'presupuesto_personal_screen.dart';
import 'proforma_screen.dart';

/// Contenedor principal: menú lateral (pantallas anchas) o drawer (móvil).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Mismo orden que la lista `modules`
    _pages = [
      DashboardScreen(onOpen: _go),
      const EstadosFinancierosScreen(),
      const AnalisisFinancieroScreen(),
      const CvuScreen(),
      const ApalancamientoScreen(),
      const FlujoEfectivoScreen(),
      const PlaneacionPresupuestosScreen(),
      const ProformaScreen(),
      const PresupuestoPersonalScreen(),
      const InventarioScreen(),
    ];
  }

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      final body = IndexedStack(index: _index, children: _pages);

      if (wide) {
        return Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 280,
                child: _SideMenu(selected: _index, onSelect: _go),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        );
      }

      return Scaffold(
        appBar: AppBar(title: Text(modules[_index].title)),
        drawer: Drawer(
          child: _SideMenu(
            selected: _index,
            onSelect: (i) {
              Navigator.of(context).pop();
              _go(i);
            },
          ),
        ),
        body: body,
      );
    });
  }
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet, color: cs.primary, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GFO App',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Gestión Financiera Operativa',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < modules.length; i++) ...[
            if (i == 0 || modules[i].group != modules[i - 1].group)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
                child: Text(
                  modules[i].group.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.outline, fontWeight: FontWeight.bold),
                ),
              ),
            ListTile(
              dense: true,
              selected: i == selected,
              selectedTileColor: cs.primaryContainer,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              leading: Icon(modules[i].icon),
              title: Text(modules[i].title),
              onTap: () => onSelect(i),
            ),
          ],
        ],
      ),
    );
  }
}
