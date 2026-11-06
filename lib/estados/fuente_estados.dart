import 'package:flutter/material.dart';

import '../widgets/common.dart';
import 'estados_controller.dart';
import 'estados_models.dart';

/// Interruptor "Usar datos de los estados financieros" con selector de período.
class FuenteEstados extends StatelessWidget {
  const FuenteEstados({
    super.key,
    required this.estados,
    required this.usar,
    required this.onUsar,
    required this.periodo,
    required this.onPeriodo,
    required this.descripcion,
  });

  final EstadosController estados;
  final bool usar;
  final ValueChanged<bool> onUsar;
  final Periodo periodo;
  final ValueChanged<Periodo> onPeriodo;
  final String descripcion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Usar datos de los estados financieros'),
          subtitle: Text(descripcion),
          value: usar,
          onChanged: onUsar,
        ),
        if (usar) ...[
          const SizedBox(height: 8),
          SegmentedButton<Periodo>(
            segments: [
              ButtonSegment(
                value: Periodo.anterior,
                label: Text(estados.etiqueta(Periodo.anterior)),
              ),
              ButtonSegment(
                value: Periodo.actual,
                label: Text(estados.etiqueta(Periodo.actual)),
              ),
            ],
            selected: {periodo},
            onSelectionChanged: (s) => onPeriodo(s.first),
          ),
          if (!estados.hayDatos(periodo, Estado.resultados)) ...[
            const SizedBox(height: 10),
            InfoBox(
              icon: Icons.warning_amber_outlined,
              text:
                  'El Estado de Resultados de ${estados.etiqueta(periodo)} está vacío. Ingrésalo en el módulo Estados financieros.',
            ),
          ],
        ],
      ],
    );
  }
}

/// Campo de solo lectura que muestra un valor tomado de otro módulo.
class ValorDeEstados extends StatelessWidget {
  const ValorDeEstados({
    super.key,
    required this.label,
    required this.valor,
    this.ayuda,
  });

  final String label;
  final String valor;
  final String? ayuda;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        helperText: ayuda,
        helperMaxLines: 2,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.link, size: 18),
      ),
      child: Text(valor),
    );
  }
}
