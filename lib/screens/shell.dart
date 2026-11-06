import 'package:flutter/material.dart';

import '../core/indicadores_compartidos.dart';
import '../core/modules.dart';
import '../core/tema.dart';
import '../estados/estados_controller.dart';
import '../flujo/flujo_controller.dart';
import '../ia/ia_service.dart';
import '../personal/personal_controller.dart';
import '../presupuestos/presupuestos_controller.dart';
import 'acerca_de.dart';
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

  /// Datos compartidos entre módulos.
  final EstadosController _estados = EstadosController();
  final IndicadoresCompartidos _indicadores = IndicadoresCompartidos();
  final FlujoController _flujo = FlujoController();
  late final PresupuestosController _presupuestos = PresupuestosController(
    estados: _estados,
    indicadores: _indicadores,
  );
  late final PersonalController _personal =
      PersonalController(indicadores: _indicadores);
  final IaConfig _ia = const IaConfig();

  @override
  void dispose() {
    _estados.dispose();
    _indicadores.dispose();
    _flujo.dispose();
    _presupuestos.dispose();
    _personal.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Mismo orden que la lista `modules`
    _pages = [
      DashboardScreen(
        onOpen: _go,
        estados: _estados,
        indicadores: _indicadores,
      ),
      EstadosFinancierosScreen(controller: _estados),
      AnalisisFinancieroScreen(estados: _estados, ia: _ia),
      CvuScreen(estados: _estados, indicadores: _indicadores),
      ApalancamientoScreen(estados: _estados, indicadores: _indicadores),
      FlujoEfectivoScreen(estados: _estados, flujo: _flujo),
      PlaneacionPresupuestosScreen(
        estados: _estados,
        presupuestos: _presupuestos,
      ),
      ProformaScreen(estados: _estados, indicadores: _indicadores),
      PresupuestoPersonalScreen(personal: _personal),
      const InventarioScreen(),
    ];
  }

  void _go(int i) => setState(() => _index = i);

  void _acercaDe() => mostrarAcercaDe(context);

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
                child: _SideMenu(
                  selected: _index,
                  onSelect: _go,
                  onAbout: _acercaDe,
                  wide: true,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: Text(modules[_index].title),
          actions: const [BotonTema()],
        ),
        drawer: Drawer(
          child: _SideMenu(
            selected: _index,
            onSelect: (i) {
              Navigator.of(context).pop();
              _go(i);
            },
            onAbout: () {
              Navigator.of(context).pop();
              _acercaDe();
            },
          ),
        ),
        body: body,
      );
    });
  }
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({
    required this.selected,
    required this.onSelect,
    required this.onAbout,
    this.wide = false,
  });

  /// En pantallas anchas el botón de tema va en el menú (no hay AppBar).
  final bool wide;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onAbout;

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
                if (wide) const BotonTema(),
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Divider(height: 1),
          ),
          ListTile(
            dense: true,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.info_outline),
            title: const Text('Acerca de'),
            onTap: onAbout,
          ),
        ],
      ),
    );
  }
}