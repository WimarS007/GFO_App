import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../estados/montos.dart';
import 'presupuestos_controller.dart';

String _texto(double v) =>
    v == 0 ? '' : formatoMonto(v, decimales: v == v.roundToDouble() ? 0 : 2);

final _soloNumeros = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-()]'));

/// Tabla de captura: una fila por concepto y un campo por trimestre.
/// Escribe directamente en las listas de [valores] y avisa con [onChanged].
class TablaTrimestres extends StatefulWidget {
  const TablaTrimestres({
    super.key,
    required this.filas,
    required this.valores,
    required this.onChanged,
  });

  final List<String> filas;
  final List<List<double>> valores;
  final VoidCallback onChanged;

  @override
  State<TablaTrimestres> createState() => _TablaTrimestresState();
}

class _TablaTrimestresState extends State<TablaTrimestres> {
  late final List<List<TextEditingController>> _ctl;

  static const double _anchoEtiqueta = 240;
  static const double _anchoCampo = 130;

  @override
  void initState() {
    super.initState();
    _ctl = [
      for (final fila in widget.valores)
        [for (final v in fila) TextEditingController(text: _texto(v))],
    ];
  }

  @override
  void dispose() {
    for (final fila in _ctl) {
      for (final c in fila) {
        c.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: _anchoEtiqueta),
              for (final t in trimestres)
                SizedBox(
                  width: _anchoCampo,
                  child: Text(t,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < widget.filas.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: _anchoEtiqueta,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(widget.filas[i]),
                    ),
                  ),
                  for (var j = 0; j < 4; j++)
                    SizedBox(
                      width: _anchoCampo,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: TextField(
                          controller: _ctl[i][j],
                          textAlign: TextAlign.right,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          inputFormatters: [_soloNumeros],
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (t) {
                            widget.valores[i][j] = parseMonto(t) ?? 0;
                            widget.onChanged();
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Una fila de la tabla de resultados.
class FilaResultado {
  const FilaResultado(
    this.concepto,
    this.valores, {
    this.total,
    this.destacada = false,
    this.unidades = false,
  });

  final String concepto;
  final List<double> valores;

  /// Valor de la columna "Año"; null muestra "—".
  final double? total;
  final bool destacada;

  /// true: se muestra como cantidad (sin C$); false: como monto en córdobas.
  final bool unidades;
}

/// Tabla de resultados de solo lectura: T1 a T4 y total del año.
class TablaResultados extends StatelessWidget {
  const TablaResultados({super.key, required this.filas});

  final List<FilaResultado> filas;

  static String _fmt(double v, bool unidades) => unidades
      ? formatoMonto(v, decimales: v == v.roundToDouble() ? 0 : 2)
      : formatoMonto(v);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('Concepto')),
          for (final t in trimestres) DataColumn(label: Text(t), numeric: true),
          const DataColumn(label: Text('Año'), numeric: true),
        ],
        rows: [
          for (final f in filas)
            DataRow(cells: [
              DataCell(Text(f.concepto, style: _estilo(f))),
              for (final v in f.valores)
                DataCell(Text(_fmt(v, f.unidades), style: _estilo(f))),
              DataCell(Text(f.total == null ? '—' : _fmt(f.total!, f.unidades),
                  style: _estilo(f))),
            ]),
        ],
      ),
    );
  }

  static TextStyle? _estilo(FilaResultado f) =>
      f.destacada ? const TextStyle(fontWeight: FontWeight.bold) : null;
}

/// Fila editable de un gasto de operación: nombre, 4 trimestres y si sale de caja.
class LineaGastoRow extends StatefulWidget {
  const LineaGastoRow({
    super.key,
    required this.linea,
    required this.onChanged,
    required this.onDelete,
    this.autofocus = false,
  });

  final LineaGasto linea;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final bool autofocus;

  @override
  State<LineaGastoRow> createState() => _LineaGastoRowState();
}

class _LineaGastoRowState extends State<LineaGastoRow> {
  late final TextEditingController _concepto;
  late final List<TextEditingController> _montos;

  @override
  void initState() {
    super.initState();
    _concepto = TextEditingController(text: widget.linea.concepto);
    _montos = [
      for (final m in widget.linea.montos) TextEditingController(text: _texto(m)),
    ];
  }

  @override
  void dispose() {
    _concepto.dispose();
    for (final c in _montos) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _concepto,
                  autofocus: widget.autofocus,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Gasto',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (t) {
                    widget.linea.concepto = t;
                    widget.onChanged();
                  },
                ),
              ),
              IconButton(
                tooltip: 'Eliminar gasto',
                icon: const Icon(Icons.delete_outline),
                onPressed: widget.onDelete,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var t = 0; t < 4; t++)
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _montos[t],
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    inputFormatters: [_soloNumeros],
                    decoration: InputDecoration(
                      labelText: trimestres[t],
                      prefixText: 'C\$ ',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      widget.linea.montos[t] = parseMonto(v) ?? 0;
                      widget.onChanged();
                    },
                  ),
                ),
            ],
          ),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Sale de caja'),
            subtitle: const Text(
                'Desmárcalo si no hay desembolso de efectivo (depreciación, amortización).'),
            value: widget.linea.afectaCaja,
            onChanged: (v) {
              setState(() => widget.linea.afectaCaja = v ?? true);
              widget.onChanged();
            },
          ),
        ],
      ),
    );
  }
}

/// Lista editable de gastos de operación con botón para agregar.
class GastosEditor extends StatelessWidget {
  const GastosEditor({super.key, required this.controller});

  final PresupuestosController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (controller.gastos.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Sin gastos. Usa «Agregar gasto».',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        for (final g in controller.gastos)
          Padding(
            key: ValueKey(g.id),
            padding: const EdgeInsets.only(bottom: 10),
            child: LineaGastoRow(
              linea: g,
              autofocus: g.id == controller.ultimoGastoId && g.concepto.isEmpty,
              onChanged: controller.notificarCambio,
              onDelete: () => controller.eliminarGasto(g.id),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: controller.agregarGasto,
            icon: const Icon(Icons.add),
            label: const Text('Agregar gasto'),
          ),
        ),
      ],
    );
  }
}
