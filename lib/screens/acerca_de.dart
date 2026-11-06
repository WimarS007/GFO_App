import 'package:flutter/material.dart';

import '../core/modules.dart';

const _version = '1.0.0';
const _institucion = 'Universidad Nacional de Ingenieria / Gestion Financiera Operativa 2M3-SIS-S';
const _integrantes = <String>[
  'Br. Wimar Jair Sandy Zambrana',
  'Br. Jose Carlos Gutierrez Jimenez',
  'Br. Alexander Jose Sevilla Porras',
  'Br. Brayan Javier Castro Soza',
  'Br. Merelyn Edith Soza Mendieta',
  'Br. Kamilo Benjamin Cerda Guadamuz',
];

/// Muestra el diálogo "Acerca de" de la app.
void mostrarAcercaDe(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => const _AcercaDeDialog(),
  );
}

class _AcercaDeDialog extends StatelessWidget {
  const _AcercaDeDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlertDialog(
      icon: Icon(Icons.account_balance_wallet, color: cs.primary, size: 40),
      title: const Text('GFO App'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Gestión Financiera Operativa · v$_version',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: cs.outline),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'GFO App reúne en un solo lugar las herramientas de la asignatura Gestión Financiera Operativa. Permite ingresar o importar estados financieros y obtener análisis horizontal y vertical, razones financieras, punto de equilibrio, apalancamiento, flujo de efectivo y presupuestos. Incluye además presupuesto personal, control de inventario y exportación de reportes a PDF o Excel.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text('Equipo',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (final n in _integrantes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 16, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(n)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Text(_institucion, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'GFO App',
            applicationVersion: _version,
          ),
          child: const Text('Licencias'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
