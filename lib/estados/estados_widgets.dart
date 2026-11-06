import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/common.dart';
import 'estados_controller.dart';
import 'estados_models.dart';
import 'montos.dart';

/// Fila editable de una cuenta: nombre, valor del período anterior y actual.
class CuentaRow extends StatefulWidget {
  const CuentaRow({
    super.key,
    required this.cuenta,
    required this.destinos,
    required this.etiquetaAnterior,
    required this.etiquetaActual,
    required this.onChanged,
    required this.onDelete,
    required this.onMove,
    this.autofocus = false,
    this.mostrarComportamiento = false,
  });

  final Cuenta cuenta;
  final List<Grupo> destinos;
  final String etiquetaAnterior;
  final String etiquetaActual;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final ValueChanged<Grupo> onMove;
  final bool autofocus;

  /// Muestra el selector Variable / Fijo (costo de ventas y gastos de operación).
  final bool mostrarComportamiento;

  @override
  State<CuentaRow> createState() => _CuentaRowState();
}

class _CuentaRowState extends State<CuentaRow> {
  late final TextEditingController _nombre;
  late final TextEditingController _anterior;
  late final TextEditingController _actual;

  static String _texto(double v) => v == 0 ? '' : formatoMonto(v);

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.cuenta.nombre);
    _anterior = TextEditingController(text: _texto(widget.cuenta.anterior));
    _actual = TextEditingController(text: _texto(widget.cuenta.actual));
  }

  @override
  void dispose() {
    _nombre.dispose();
    _anterior.dispose();
    _actual.dispose();
    super.dispose();
  }

  Widget _campoNombre() {
    return TextField(
      controller: _nombre,
      autofocus: widget.autofocus,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Cuenta',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      onChanged: (t) {
        widget.cuenta.nombre = t;
        widget.onChanged();
      },
    );
  }

  Widget _campoMonto(Periodo p, TextEditingController c, String etiqueta) {
    return TextField(
      controller: c,
      textAlign: TextAlign.right,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-()]')),
      ],
      decoration: InputDecoration(
        labelText: etiqueta,
        prefixText: 'C\$ ',
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: (t) {
        widget.cuenta.setValor(p, parseMonto(t) ?? 0);
        widget.onChanged();
      },
    );
  }

  Widget _acciones() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<Grupo>(
          tooltip: 'Mover a otro grupo',
          icon: const Icon(Icons.drive_file_move_outline),
          onSelected: widget.onMove,
          itemBuilder: (_) => [
            for (final g in widget.destinos)
              if (g != widget.cuenta.grupo)
                PopupMenuItem(value: g, child: Text('Mover a: ${g.titulo}')),
          ],
        ),
        IconButton(
          tooltip: 'Eliminar cuenta',
          icon: const Icon(Icons.delete_outline),
          onPressed: widget.onDelete,
        ),
      ],
    );
  }

  Widget _selectorComportamiento() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Comportamiento del costo:',
              style: Theme.of(context).textTheme.bodySmall),
          SegmentedButton<Comportamiento>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(
                  value: Comportamiento.variable, label: Text('Variable')),
              ButtonSegment(value: Comportamiento.fijo, label: Text('Fijo')),
            ],
            selected: {widget.cuenta.comportamiento},
            onSelectionChanged: (s) {
              setState(() => widget.cuenta.comportamiento = s.first);
              widget.onChanged();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filaPrincipal(),
        if (widget.mostrarComportamiento) _selectorComportamiento(),
      ],
    );
  }

  Widget _filaPrincipal() {
    return LayoutBuilder(builder: (context, constraints) {
      final anterior =
          _campoMonto(Periodo.anterior, _anterior, widget.etiquetaAnterior);
      final actual = _campoMonto(Periodo.actual, _actual, widget.etiquetaActual);

      if (constraints.maxWidth >= 680) {
        return Row(
          children: [
            Expanded(flex: 3, child: _campoNombre()),
            const SizedBox(width: 12),
            SizedBox(width: 170, child: anterior),
            const SizedBox(width: 12),
            SizedBox(width: 170, child: actual),
            _acciones(),
          ],
        );
      }
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _campoNombre()),
              _acciones(),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: anterior),
              const SizedBox(width: 8),
              Expanded(child: actual),
            ],
          ),
        ],
      );
    });
  }
}

/// Tarjeta con todas las cuentas de un grupo, botón para agregar y subtotal.
class GrupoSection extends StatelessWidget {
  const GrupoSection({super.key, required this.controller, required this.grupo});

  final EstadosController controller;
  final Grupo grupo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cuentas = controller.deGrupo(grupo);
    final destinos = Grupo.deEstado(grupo.estado);
    final etAnt = controller.etiqueta(Periodo.anterior);
    final etAct = controller.etiqueta(Periodo.actual);
    final esCosto =
        grupo == Grupo.costoVentas || grupo == Grupo.gastosOperacion;

    return SectionCard(
      title: grupo.titulo,
      subtitle: esCosto
          ? 'Marca cada cuenta como variable o fija: se usa en Punto de equilibrio y Apalancamiento.'
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cuentas.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Sin cuentas en este grupo. Usa «Agregar cuenta».',
                style: theme.textTheme.bodySmall,
              ),
            ),
          for (final c in cuentas)
            Padding(
              key: ValueKey(c.id),
              padding: const EdgeInsets.only(bottom: 10),
              child: CuentaRow(
                cuenta: c,
                destinos: destinos,
                etiquetaAnterior: etAnt,
                etiquetaActual: etAct,
                autofocus: c.id == controller.ultimoAgregadoId && c.nombre.isEmpty,
                mostrarComportamiento: esCosto,
                onChanged: controller.notificarCambio,
                onDelete: () => controller.eliminar(c.id),
                onMove: (g) => controller.mover(c.id, g),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => controller.agregar(grupo),
              icon: const Icon(Icons.add),
              label: const Text('Agregar cuenta'),
            ),
          ),
          const SizedBox(height: 6),
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
              runSpacing: 4,
              children: [
                Text('Total ${grupo.titulo.toLowerCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '$etAnt: C\$ ${formatoMonto(controller.totalGrupo(grupo, Periodo.anterior))}'
                  '   ·   $etAct: C\$ ${formatoMonto(controller.totalGrupo(grupo, Periodo.actual))}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FilaResumen {
  const FilaResumen(this.concepto, this.anterior, this.actual,
      {this.destacada = false});

  final String concepto;
  final double anterior;
  final double actual;
  final bool destacada;
}

/// Tabla de resultados calculados (solo lectura).
class ResumenTabla extends StatelessWidget {
  const ResumenTabla({
    super.key,
    required this.etiquetaAnterior,
    required this.etiquetaActual,
    required this.filas,
  });

  final String etiquetaAnterior;
  final String etiquetaActual;
  final List<FilaResumen> filas;

  @override
  Widget build(BuildContext context) {
    TextStyle? estilo(FilaResumen f) =>
        f.destacada ? const TextStyle(fontWeight: FontWeight.bold) : null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('Concepto')),
          DataColumn(label: Text('$etiquetaAnterior (C\$)'), numeric: true),
          DataColumn(label: Text('$etiquetaActual (C\$)'), numeric: true),
        ],
        rows: [
          for (final f in filas)
            DataRow(cells: [
              DataCell(Text(f.concepto, style: estilo(f))),
              DataCell(Text(formatoMonto(f.anterior), style: estilo(f))),
              DataCell(Text(formatoMonto(f.actual), style: estilo(f))),
            ]),
        ],
      ),
    );
  }
}

/// Aviso de si el balance cuadra (Activo = Pasivo + Patrimonio).
class CuadreBalance extends StatelessWidget {
  const CuadreBalance({
    super.key,
    required this.etiqueta,
    required this.diferencia,
  });

  final String etiqueta;
  final double diferencia;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cuadra = diferencia.abs() < 0.01;
    final fondo = cuadra ? cs.primaryContainer : cs.errorContainer;
    final texto = cuadra ? cs.onPrimaryContainer : cs.onErrorContainer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            cuadra ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            color: texto,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cuadra
                  ? '$etiqueta: el balance cuadra (Activos = Pasivos + Patrimonio).'
                  : '$etiqueta: el balance no cuadra. Diferencia de C\$ ${formatoMonto(diferencia)} entre Activos y Pasivos + Patrimonio.',
              style: TextStyle(color: texto),
            ),
          ),
        ],
      ),
    );
  }
}
