import 'package:flutter/material.dart';

import '../widgets/common.dart';
import 'ia_service.dart';

/// Tarjeta "Interpretación con IA": botón, estado de carga, resultado o error.
///
/// Si se pasa [interpretacionLocal], la tarjeta también ofrece una
/// interpretación sin IA (reglas sobre las mismas cifras) que se muestra
/// cuando la IA falla o cuando la persona la pide con el botón.
class IaPanel extends StatefulWidget {
  const IaPanel({
    super.key,
    required this.config,
    required this.onGenerar,
    this.resultado,
    this.error,
    this.cargando = false,
    this.puedeGenerar = true,
    this.titulo = 'Interpretación con IA',
    this.interpretacionLocal,
  });

  final IaConfig config;
  final VoidCallback onGenerar;
  final String? resultado;
  final String? error;
  final bool cargando;
  final String titulo;

  /// False cuando aún no hay datos en los estados financieros.
  final bool puedeGenerar;

  /// Genera la interpretación sin IA con los datos actuales. Debe devolver
  /// null si todavía no hay datos suficientes. Se vuelve a llamar en cada
  /// reconstrucción, así que siempre refleja las cifras más recientes.
  final String? Function()? interpretacionLocal;

  @override
  State<IaPanel> createState() => _IaPanelState();
}

class _IaPanelState extends State<IaPanel> {
  /// La persona pidió la interpretación local con el botón.
  bool _pideLocal = false;

  @override
  void didUpdateWidget(covariant IaPanel old) {
    super.didUpdateWidget(old);
    // Llegó una interpretación nueva de la IA: se muestra esa.
    if (widget.resultado != null && widget.resultado != old.resultado) {
      _pideLocal = false;
    }
  }

  String? _calcularLocal() {
    try {
      return widget.interpretacionLocal?.call();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final local = _calcularLocal();
    final hayError = widget.error != null;
    final mostrarLocal = local != null && (_pideLocal || hayError);
    final texto = mostrarLocal ? local : widget.resultado;

    return SectionCard(
      title: widget.titulo,
      icon: Icons.auto_awesome,
      subtitle: widget.interpretacionLocal == null
          ? 'Una IA lee tus cifras y las explica en lenguaje sencillo.'
          : 'Una IA lee tus cifras y las explica en lenguaje sencillo. Si la IA no responde, se muestra una interpretación local sin conexión.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: (widget.cargando || !widget.puedeGenerar)
                    ? null
                    : () {
                        setState(() => _pideLocal = false);
                        widget.onGenerar();
                      },
                icon: widget.cargando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(widget.cargando
                    ? 'Analizando…'
                    : widget.resultado == null
                        ? 'Generar interpretación'
                        : 'Volver a generar'),
              ),
              if (widget.interpretacionLocal != null)
                OutlinedButton.icon(
                  onPressed: (widget.cargando ||
                          !widget.puedeGenerar ||
                          local == null)
                      ? null
                      : () => setState(() => _pideLocal = true),
                  icon: const Icon(Icons.offline_bolt_outlined),
                  label: const Text('Interpretación local (sin IA)'),
                ),
            ],
          ),
          if (!widget.puedeGenerar) ...[
            const SizedBox(height: 12),
            const Text(
                'Primero ingresa datos en el módulo Estados financieros.'),
          ],
          if (hayError) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(widget.error!,
                  style: TextStyle(color: cs.onErrorContainer)),
            ),
          ],
          if (texto != null) ...[
            const SizedBox(height: 12),
            if (mostrarLocal) ...[
              Row(
                children: [
                  Icon(Icons.offline_bolt_outlined,
                      size: 18, color: cs.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hayError
                          ? 'La IA no respondió: esta es la interpretación local (sin IA).'
                          : 'Interpretación local (sin IA)',
                      style: t.labelLarge?.copyWith(
                          color: cs.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(texto),
            ),
            const SizedBox(height: 8),
            Text(
              mostrarLocal
                  ? 'Generada en tu dispositivo con reglas fijas sobre tus cifras, sin IA. Es orientativa y menos detallada; verifícala antes de decidir.'
                  : 'Generado por IA a partir de tus cifras. Es orientativo; verifícalo antes de decidir.',
              style: t.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
