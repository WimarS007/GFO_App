import 'package:flutter/material.dart';

import '../widgets/common.dart';
import 'ia_service.dart';

/// Tarjeta "Interpretación con IA": botón, estado de carga, resultado o error.
class IaPanel extends StatelessWidget {
  const IaPanel({
    super.key,
    required this.config,
    required this.onGenerar,
    this.resultado,
    this.error,
    this.cargando = false,
    this.puedeGenerar = true,
    this.titulo = 'Interpretación con IA',
  });

  final IaConfig config;
  final VoidCallback onGenerar;
  final String? resultado;
  final String? error;
  final bool cargando;
  final String titulo;

  /// False cuando aún no hay datos en los estados financieros.
  final bool puedeGenerar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SectionCard(
      title: titulo,
      icon: Icons.auto_awesome,
      subtitle: 'Una IA lee tus cifras y las explica en lenguaje sencillo.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            onPressed: (cargando || !puedeGenerar) ? null : onGenerar,
            icon: cargando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(cargando
                ? 'Analizando…'
                : resultado == null
                    ? 'Generar interpretación'
                    : 'Volver a generar'),
          ),
          if (!puedeGenerar) ...[
            const SizedBox(height: 12),
            const Text(
                'Primero ingresa datos en el módulo Estados financieros.'),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(error!,
                  style: TextStyle(color: cs.onErrorContainer)),
            ),
          ],
          if (resultado != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(resultado!),
            ),
            const SizedBox(height: 8),
            Text(
              'Generado por IA a partir de tus cifras. Es orientativo; verifícalo antes de decidir.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
