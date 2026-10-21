import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../estados/montos.dart';
import '../widgets/common.dart';
import 'flujo_controller.dart';

/// Fila editable de una entrada o salida de efectivo: concepto y monto.
class LineaFlujoRow extends StatefulWidget {
  const LineaFlujoRow({
    super.key,
    required this.linea,
    required this.onChanged,
    required this.onDelete,
    this.autofocus = false,
  });

  final LineaFlujo linea;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final bool autofocus;

  @override
  State<LineaFlujoRow> createState() => _LineaFlujoRowState();
}

class _LineaFlujoRowState extends State<LineaFlujoRow> {
  late final TextEditingController _concepto;
  late final TextEditingController _monto;

  @override
  void initState() {
    super.initState();
    _concepto = TextEditingController(text: widget.linea.concepto);
    _monto = TextEditingController(
      text: widget.linea.monto == 0 ? '' : formatoMonto(widget.linea.monto),
    );
  }

  @override
  void dispose() {
    _concepto.dispose();
    _monto.dispose();
    super.dispose();
  }

  Widget _campoConcepto() {
    return TextField(
      controller: _concepto,
      autofocus: widget.autofocus,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Concepto',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      onChanged: (t) {
        widget.linea.concepto = t;
        widget.onChanged();
      },
    );
  }

  Widget _campoMonto() {
    return TextField(
      controller: _monto,
      textAlign: TextAlign.right,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-()]')),
      ],
      decoration: const InputDecoration(
        labelText: 'Monto',
        prefixText: 'C\$ ',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      onChanged: (t) {
        widget.linea.monto = parseMonto(t) ?? 0;
        widget.onChanged();
      },
    );
  }

  Widget _eliminar() => IconButton(
        tooltip: 'Eliminar',
        icon: const Icon(Icons.delete_outline),
        onPressed: widget.onDelete,
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 560) {
        return Row(
          children: [
            Expanded(child: _campoConcepto()),
            const SizedBox(width: 12),
            SizedBox(width: 180, child: _campoMonto()),
            _eliminar(),
          ],
        );
      }
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _campoConcepto()),
              _eliminar(),
            ],
          ),
          const SizedBox(height: 8),
          _campoMonto(),
        ],
      );
    });
  }
}

/// Lista de entradas o salidas de una actividad, con botón para agregar y total.
class LineasSeccion extends StatelessWidget {
  const LineasSeccion({
    super.key,
    required this.controller,
    required this.actividad,
    required this.sentido,
  });

  final FlujoController controller;
  final Actividad actividad;
  final Sentido sentido;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esEntrada = sentido == Sentido.entrada;
    final lineas = controller.lineas(actividad, sentido);
    final total = esEntrada
        ? controller.totalEntradas(actividad)
        : controller.totalSalidas(actividad);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          esEntrada ? 'Entradas de efectivo' : 'Salidas de efectivo',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (lineas.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Sin movimientos. Usa «Agregar».',
                style: theme.textTheme.bodySmall),
          ),
        for (final l in lineas)
          Padding(
            key: ValueKey(l.id),
            padding: const EdgeInsets.only(bottom: 10),
            child: LineaFlujoRow(
              linea: l,
              autofocus: l.id == controller.ultimoAgregadoId && l.concepto.isEmpty,
              onChanged: controller.notificarCambio,
              onDelete: () => controller.eliminar(l.id),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => controller.agregar(actividad, sentido),
            icon: const Icon(Icons.add),
            label: Text(esEntrada ? 'Agregar entrada' : 'Agregar salida'),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            children: [
              Text(esEntrada ? 'Total entradas' : 'Total salidas',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('C\$ ${formatoMonto(total)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de una actividad: entradas, salidas y flujo neto.
class ActividadCard extends StatelessWidget {
  const ActividadCard({
    super.key,
    required this.controller,
    required this.actividad,
    required this.icono,
  });

  final FlujoController controller;
  final Actividad actividad;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SectionCard(
      title: actividad.titulo,
      icon: icono,
      child: SpacedColumn(
        gap: 18,
        children: [
          LineasSeccion(
              controller: controller, actividad: actividad, sentido: Sentido.entrada),
          LineasSeccion(
              controller: controller, actividad: actividad, sentido: Sentido.salida),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              children: [
                Text('Flujo neto · ${actividad.titulo.toLowerCase()}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
                Text('C\$ ${formatoMonto(controller.flujoNeto(actividad))}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
