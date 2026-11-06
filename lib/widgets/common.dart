import 'package:flutter/material.dart';

/// Página con encabezado y ancho máximo, con espacio entre sus hijos.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: t.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle, style: t.bodyMedium),
              const SizedBox(height: 20),
              SpacedColumn(children: children),
            ],
          ),
        ),
      ),
    );
  }
}

/// Columna con separación uniforme entre hijos.
class SpacedColumn extends StatelessWidget {
  const SpacedColumn({super.key, required this.children, this.gap = 16});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: Card.outlined(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Distribuye los hijos en columnas según el ancho disponible.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minColumnWidth = 240,
    this.spacing = 12,
  });

  final List<Widget> children;
  final double minColumnWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      var cols = ((w + spacing) / (minColumnWidth + spacing)).floor();
      if (cols < 1) cols = 1;
      final itemW = (w - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final c in children) SizedBox(width: itemW, child: c),
        ],
      );
    });
  }
}

class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.label,
    this.prefix,
    this.suffix,
    this.hint,
    this.controller,
    this.onChanged,
  });

  final String label;
  final String? prefix;
  final String? suffix;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        suffixText: suffix,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class TextFieldBox extends StatelessWidget {
  const TextFieldBox({
    super.key,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.controller,
    this.onChanged,
  });

  final String label;
  final String? hint;
  final int maxLines;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// Tarjeta de resultado. El valor queda en "—" hasta conectar los cálculos.
class ResultTile extends StatelessWidget {
  const ResultTile({
    super.key,
    required this.label,
    this.unit,
    this.value = '—',
    this.detail,
  });

  final String label;
  final String? unit;
  final String value;

  /// Texto pequeño opcional bajo el valor (p. ej. el valor del período anterior).
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: t.labelMedium?.copyWith(color: cs.onPrimaryContainer)),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: value,
                style: t.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
              ),
              if (unit != null)
                TextSpan(
                  text: '  $unit',
                  style: t.bodyMedium?.copyWith(color: cs.onPrimaryContainer),
                ),
            ]),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail!,
                style: t.bodySmall?.copyWith(color: cs.onPrimaryContainer)),
          ],
        ],
      ),
    );
  }
}

class InfoBox extends StatelessWidget {
  const InfoBox({super.key, required this.text, this.icon = Icons.info_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: cs.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(color: cs.onSecondaryContainer)),
          ),
        ],
      ),
    );
  }
}

class ChartPlaceholder extends StatelessWidget {
  const ChartPlaceholder({
    super.key,
    required this.label,
    this.icon = Icons.bar_chart,
    this.height = 200,
  });

  final String label;
  final IconData icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: cs.outline),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: cs.outline)),
          Text('(gráfico pendiente)',
              style: TextStyle(color: cs.outline, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Tabla de captura: una fila por concepto, un campo numérico por columna.
class AccountTable extends StatelessWidget {
  const AccountTable({
    super.key,
    required this.rows,
    this.title,
    this.columns = const ['Monto (C\$)'],
    this.totalLabel,
  });

  final String? title;
  final List<String> rows;
  final List<String> columns;
  final String? totalLabel;

  static const double _labelW = 230;
  static const double _fieldW = 140;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(title!,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: _labelW),
                  for (final c in columns)
                    SizedBox(
                      width: _fieldW,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(c,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: _labelW, child: Text(r)),
                      for (final _ in columns)
                        const SizedBox(
                          width: _fieldW,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: TextField(
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true, signed: true),
                              decoration: InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (totalLabel != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: _labelW,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(totalLabel!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      for (final _ in columns)
                        const SizedBox(
                          width: _fieldW,
                          child: Text('—',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Tabla de solo lectura para resultados (celdas en "—" hasta tener cálculos).
class ReadOnlyTable extends StatelessWidget {
  const ReadOnlyTable({
    super.key,
    required this.columns,
    required this.rows,
    this.firstColumnLabel = 'Concepto',
  });

  final List<String> columns;
  final List<String> rows;
  final String firstColumnLabel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(firstColumnLabel)),
          for (final c in columns) DataColumn(label: Text(c), numeric: true),
        ],
        rows: [
          for (final r in rows)
            DataRow(cells: [
              DataCell(Text(r)),
              for (final _ in columns) const DataCell(Text('—')),
            ]),
        ],
      ),
    );
  }
}

/// Selector de sub-secciones con chips.
class TabSwitcher extends StatefulWidget {
  const TabSwitcher({super.key, required this.labels, required this.pages});

  final List<String> labels;
  final List<Widget> pages;

  @override
  State<TabSwitcher> createState() => _TabSwitcherState();
}

class _TabSwitcherState extends State<TabSwitcher> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < widget.labels.length; i++)
              ChoiceChip(
                label: Text(widget.labels[i]),
                selected: _i == i,
                onSelected: (_) => setState(() => _i = i),
              ),
          ],
        ),
        const SizedBox(height: 16),
        widget.pages[_i],
      ],
    );
  }
}

/// Botones de acción. Los callbacks quedan vacíos hasta conectar la lógica.
class ActionButtons extends StatelessWidget {
  const ActionButtons({
    super.key,
    this.primaryLabel = 'Calcular',
    this.primaryIcon = Icons.calculate_outlined,
    this.onPrimary,
    this.onClear,
  });

  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: onPrimary ?? () {},
          icon: Icon(primaryIcon),
          label: Text(primaryLabel),
        ),
        OutlinedButton.icon(
          onPressed: onClear ?? () {},
          icon: const Icon(Icons.refresh),
          label: const Text('Limpiar'),
        ),
      ],
    );
  }
}
