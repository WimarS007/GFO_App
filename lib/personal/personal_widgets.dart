import 'package:flutter/material.dart';

import '../estados/montos.dart';
import 'personal_controller.dart';
import 'personal_models.dart';

/// 05/08/2026
String fechaTexto(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Fila editable de una categoría del presupuesto proyectado.
class FilaProyeccionEditable extends StatefulWidget {
  const FilaProyeccionEditable({
    super.key,
    required this.controller,
    required this.linea,
  });

  final PersonalController controller;
  final LineaProyeccion linea;

  @override
  State<FilaProyeccionEditable> createState() => _FilaProyeccionEditableState();
}

class _FilaProyeccionEditableState extends State<FilaProyeccionEditable> {
  late final TextEditingController _categoria;
  late final TextEditingController _monto;
  late final TextEditingController _comentario;
  final _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    final l = widget.linea;
    _categoria = TextEditingController(text: l.categoria);
    _monto = TextEditingController(text: l.monto == 0 ? '' : formatoMonto(l.monto));
    _comentario = TextEditingController(text: l.comentario);
    if (widget.controller.ultimaLineaId == l.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _foco.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _categoria.dispose();
    _monto.dispose();
    _comentario.dispose();
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final l = widget.linea;
    final pct = c.ingresoProyectado == 0 ? null : l.monto / c.ingresoProyectado * 100;

    Widget campo(double ancho, Widget hijo) =>
        SizedBox(width: ancho, child: hijo);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          campo(
            190,
            TextField(
              controller: _categoria,
              focusNode: _foco,
              decoration: const InputDecoration(
                  labelText: 'Categoría',
                  isDense: true,
                  border: OutlineInputBorder()),
              onChanged: (t) {
                l.categoria = t;
                c.notificarCambio();
              },
            ),
          ),
          campo(
            120,
            TextField(
              controller: _monto,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Monto',
                  prefixText: 'C\$ ',
                  isDense: true,
                  border: OutlineInputBorder()),
              onChanged: (t) {
                l.monto = (parseMonto(t) ?? 0).abs();
                c.notificarCambio();
              },
            ),
          ),
          campo(
            150,
            DropdownButtonFormField<String>(
              value: l.tipo,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Tipo',
                  isDense: true,
                  border: OutlineInputBorder()),
              items: [
                for (final t in tiposLinea)
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) {
                if (v == null) return;
                l.tipo = v;
                c.notificarCambio();
              },
            ),
          ),
          campo(
            70,
            Text(pct == null ? '—' : '${pct.toStringAsFixed(1)} %',
                textAlign: TextAlign.center),
          ),
          campo(
            200,
            TextField(
              controller: _comentario,
              decoration: const InputDecoration(
                  labelText: 'Comentario',
                  isDense: true,
                  border: OutlineInputBorder()),
              onChanged: (t) {
                l.comentario = t;
                c.notificarCambio();
              },
            ),
          ),
          IconButton(
            tooltip: 'Quitar categoría',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => c.eliminarLinea(l.id),
          ),
        ],
      ),
    );
  }
}

/// Barras horizontales con el peso de cada elemento sobre el total.
class BarrasDistribucion extends StatelessWidget {
  const BarrasDistribucion({
    super.key,
    required this.items,
    required this.total,
  });

  final List<MapEntry<String, double>> items;
  final double total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(e.key)),
                    Text(
                        'C\$ ${formatoMonto(e.value)}  ·  ${total == 0 ? '0.0' : (e.value / total * 100).toStringAsFixed(1)} %'),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : (e.value / total).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Seguimiento semanal: ingresos, gastos, ahorro, reserva, saldo y avance de la meta.
class TablaSeguimiento extends StatelessWidget {
  const TablaSeguimiento({
    super.key,
    required this.semanas,
    required this.costoMeta,
  });

  final List<SemanaResumen> semanas;
  final double costoMeta;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        columns: const [
          DataColumn(label: Text('Mes')),
          DataColumn(label: Text('Semana')),
          DataColumn(label: Text('Desde')),
          DataColumn(label: Text('Hasta')),
          DataColumn(label: Text('Ingresos'), numeric: true),
          DataColumn(label: Text('Gastos'), numeric: true),
          DataColumn(label: Text('Ahorro meta'), numeric: true),
          DataColumn(label: Text('Reserva'), numeric: true),
          DataColumn(label: Text('Saldo'), numeric: true),
          DataColumn(label: Text('Ahorro acum.'), numeric: true),
          DataColumn(label: Text('% meta'), numeric: true),
        ],
        rows: [
          for (final s in semanas)
            DataRow(cells: [
              DataCell(Text('${s.mes}')),
              DataCell(Text('${s.semana}')),
              DataCell(Text(fechaTexto(s.desde))),
              DataCell(Text(fechaTexto(s.hasta))),
              DataCell(Text(formatoMonto(s.ingresos))),
              DataCell(Text(formatoMonto(s.gastos))),
              DataCell(Text(formatoMonto(s.ahorro))),
              DataCell(Text(formatoMonto(s.reserva))),
              DataCell(Text(formatoMonto(s.saldo),
                  style: TextStyle(color: s.saldo < -0.005 ? cs.error : null))),
              DataCell(Text(formatoMonto(s.ahorroAcumulado))),
              DataCell(Text(costoMeta == 0
                  ? '—'
                  : '${(s.ahorroAcumulado / costoMeta * 100).toStringAsFixed(1)} %')),
            ]),
        ],
      ),
    );
  }
}

/// Lista de movimientos con botón para quitar cada uno.
class TablaMovimientos extends StatelessWidget {
  const TablaMovimientos({
    super.key,
    required this.movimientos,
    required this.onEliminar,
  });

  final List<Movimiento> movimientos;
  final ValueChanged<String> onEliminar;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        columns: const [
          DataColumn(label: Text('Fecha')),
          DataColumn(label: Text('Sem.'), numeric: true),
          DataColumn(label: Text('Tipo')),
          DataColumn(label: Text('Categoría')),
          DataColumn(label: Text('Descripción')),
          DataColumn(label: Text('Monto'), numeric: true),
          DataColumn(label: Text('Prioridad')),
          DataColumn(label: Text('Medio')),
          DataColumn(label: Text('')),
        ],
        rows: [
          for (final m in movimientos)
            DataRow(cells: [
              DataCell(Text(fechaTexto(m.fecha))),
              DataCell(Text('${m.semana}')),
              DataCell(Text(m.tipo.etiqueta)),
              DataCell(Text(m.categoria)),
              DataCell(Text(m.descripcion)),
              DataCell(Text(formatoMonto(m.monto))),
              DataCell(Text(m.prioridad)),
              DataCell(Text(m.medio)),
              DataCell(IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => onEliminar(m.id),
              )),
            ]),
        ],
      ),
    );
  }
}

/// Proyectado vs. real, en promedios semanales.
class TablaComparacion extends StatelessWidget {
  const TablaComparacion({super.key, required this.filas});

  final List<FilaComparacion> filas;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color? color(FilaComparacion f) {
      final e = f.estado;
      if (e == 'Excede el plan' || e == 'Por debajo' || e == 'Sin plan') {
        return cs.error;
      }
      return null;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Categoría')),
          DataColumn(label: Text('Planificado / sem.'), numeric: true),
          DataColumn(label: Text('Real / sem.'), numeric: true),
          DataColumn(label: Text('Diferencia'), numeric: true),
          DataColumn(label: Text('Estado')),
        ],
        rows: [
          for (final f in filas)
            DataRow(cells: [
              DataCell(Text(f.nombre)),
              DataCell(Text(formatoMonto(f.planificado))),
              DataCell(Text(formatoMonto(f.real))),
              DataCell(Text(formatoMonto(f.diferencia))),
              DataCell(Text(f.estado, style: TextStyle(color: color(f)))),
            ]),
        ],
      ),
    );
  }
}
