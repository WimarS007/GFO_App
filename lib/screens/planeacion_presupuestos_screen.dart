import 'package:flutter/material.dart';

import '../estados/estados_controller.dart';
import '../estados/estados_models.dart';
import '../estados/fuente_estados.dart';
import '../estados/montos.dart';
import '../ia/ia_service.dart';
import '../ia/ia_widgets.dart';
import '../presupuestos/presupuestos_controller.dart';
import '../presupuestos/presupuestos_widgets.dart';
import '../widgets/common.dart';

/// Planeación y presupuestos: ventas, compras, costo de bienes vendidos,
/// gastos de operación y presupuesto de caja, por trimestre.
/// Los saldos iniciales y los gastos pueden tomarse de los estados financieros.
class PlaneacionPresupuestosScreen extends StatefulWidget {
  const PlaneacionPresupuestosScreen({
    super.key,
    required this.estados,
    required this.presupuestos,
  });

  final EstadosController estados;
  final PresupuestosController presupuestos;

  @override
  State<PlaneacionPresupuestosScreen> createState() =>
      _PlaneacionPresupuestosScreenState();
}

class _PlaneacionPresupuestosScreenState
    extends State<PlaneacionPresupuestosScreen> {
  /// Controladores de los supuestos de un solo valor (viven aquí para que el
  /// texto no se pierda al cambiar de pestaña).
  late final Map<Campo, TextEditingController> _campos;

  // IA
  final IaConfig _iaConfig = const IaConfig();
  late final IaService _ia = IaService(_iaConfig);
  String? _textoIa;
  String? _resumenIa; // datos con los que se generó _textoIa
  String? _errorIa;
  bool _cargandoIa = false;

  @override
  void initState() {
    super.initState();
    final p = widget.presupuestos;
    _campos = {
      for (final c in Campo.values)
        c: TextEditingController(text: _textoInicial(p.valor(c))),
    };
  }

  static String _textoInicial(double v) =>
      v == 0 ? '' : formatoMonto(v, decimales: v == v.roundToDouble() ? 0 : 2);

  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    _ia.cerrar();
    super.dispose();
  }

  String? _resumen() =>
      widget.presupuestos.hayDatos ? widget.presupuestos.resumenParaIa() : null;

  Future<void> _generarIa() async {
    final resumen = _resumen();
    if (resumen == null) {
      setState(() => _errorIa =
          'Primero ingresa las unidades a vender de cada trimestre en «Supuestos».');
      return;
    }
    setState(() {
      _cargandoIa = true;
      _errorIa = null;
    });
    try {
      final texto = await _ia.interpretar(
        enfoque:
            'Presupuesto de ventas, compras, costo de bienes vendidos, gastos de operación y caja',
        resumen: resumen,
      );
      if (!mounted) return;
      setState(() {
        _textoIa = texto;
        _resumenIa = resumen;
      });
    } on IaException catch (e) {
      if (!mounted) return;
      setState(() => _errorIa = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargandoIa = false);
    }
  }

  Future<void> _cargarGastos() async {
    final p = widget.presupuestos;
    if (p.hayGastosCapturados) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reemplazar gastos'),
          content: const Text(
              'Se reemplazarán los gastos que ya escribiste por las cuentas de «Gastos de operación» de los estados financieros (repartidas en partes iguales entre los 4 trimestres).'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Reemplazar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    p.cargarGastosDeEstados();
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.estados, widget.presupuestos]),
      builder: (context, _) {
        final p = widget.presupuestos;
        final r = p.calcular();

        // La interpretación se oculta si los datos cambiaron desde que se generó.
        final textoVisible =
            (_textoIa != null && _resumenIa == _resumen()) ? _textoIa : null;

        return PageScaffold(
          title: 'Planeación y presupuestos',
          subtitle:
              'Presupuesto de ventas, compras, costo de bienes vendidos, gastos de operación y caja, por trimestre.',
          children: [
            for (final a in p.avisos)
              InfoBox(icon: Icons.warning_amber_outlined, text: a),
            TabSwitcher(
              labels: const [
                'Supuestos',
                'Ventas',
                'Compras',
                'Costo de bienes vendidos',
                'Gastos de operación',
                'Caja',
                'Resumen',
              ],
              pages: [
                _supuestos(p),
                _ventas(r),
                _compras(r),
                _costoBienesVendidos(r),
                _gastos(p, r),
                _caja(p, r),
                _resumenMaestro(p, r),
              ],
            ),
            IaPanel(
              config: _iaConfig,
              onGenerar: _generarIa,
              resultado: textoVisible,
              error: _errorIa,
              cargando: _cargandoIa,
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------- supuestos

  Widget _campo(Campo c, String etiqueta,
      {String? prefijo, String? sufijo, String? pista}) {
    return NumberField(
      label: etiqueta,
      prefix: prefijo,
      suffix: sufijo,
      hint: pista,
      controller: _campos[c],
      onChanged: (t) => widget.presupuestos.setValor(c, parseMonto(t) ?? 0),
    );
  }

  Widget _supuestos(PresupuestosController p) {
    final actual = widget.estados.etiqueta(Periodo.actual);
    return SpacedColumn(
      children: [
        const InfoBox(
          text:
              'Política asumida: las ventas y compras a crédito se cobran y pagan en el trimestre siguiente; las cuentas por cobrar y por pagar iniciales se cobran y pagan en T1. Todo en córdobas (C\$).',
        ),
        SectionCard(
          title: 'Proyección de ventas',
          icon: Icons.trending_up,
          child: SpacedColumn(
            gap: 14,
            children: [
              TablaTrimestres(
                filas: const [
                  'Unidades a vender',
                  'Precio de venta unitario (C\$)',
                ],
                valores: [p.unidades, p.precios],
                onChanged: p.notificarCambio,
              ),
              ResponsiveGrid(
                minColumnWidth: 280,
                children: [
                  _campo(Campo.unidadesSiguiente,
                      'Unidades estimadas del trimestre siguiente (T5)',
                      sufijo: 'unidades',
                      pista: 'Vacío = se usa T4'),
                ],
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Políticas y costos',
          icon: Icons.rule,
          child: ResponsiveGrid(
            minColumnWidth: 240,
            children: [
              _campo(Campo.pctVentasContado, 'Ventas al contado', sufijo: '%'),
              _campo(Campo.pctComprasContado, 'Compras al contado', sufijo: '%'),
              _campo(Campo.pctInventarioFinal,
                  'Inventario final deseado',
                  sufijo: '% de las ventas del trimestre siguiente'),
              _campo(Campo.costoUnitario, 'Costo unitario de compra',
                  prefijo: 'C\$ '),
              _campo(Campo.cajaMinima, 'Saldo mínimo de caja', prefijo: 'C\$ '),
            ],
          ),
        ),
        SectionCard(
          title: 'Saldos iniciales',
          icon: Icons.account_balance_wallet_outlined,
          child: SpacedColumn(
            gap: 12,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tomar los saldos iniciales del balance'),
                subtitle: Text(
                    'Efectivo, cuentas por cobrar, cuentas por pagar e inventarios al cierre de $actual.'),
                value: p.usarBalance,
                onChanged: p.setUsarBalance,
              ),
              if (p.usarBalance)
                ResponsiveGrid(
                  minColumnWidth: 240,
                  children: [
                    ValorDeEstados(
                        label: 'Efectivo (C\$)',
                        valor: formatoMonto(p.efectivoBalance)),
                    ValorDeEstados(
                        label: 'Cuentas por cobrar (C\$)',
                        valor: formatoMonto(p.cxcBalance)),
                    ValorDeEstados(
                        label: 'Cuentas por pagar (C\$)',
                        valor: formatoMonto(p.cxpBalance)),
                    ValorDeEstados(
                        label: 'Inventarios (C\$)',
                        valor: formatoMonto(p.inventarioBalance)),
                    ValorDeEstados(
                      label: 'Inventario inicial calculado (unidades)',
                      valor: p.costoUnitario > 0
                          ? formatoMonto(p.inventarioInicialUnidades)
                          : '—',
                      ayuda: 'Inventarios / Costo unitario de compra',
                    ),
                  ],
                )
              else
                ResponsiveGrid(
                  minColumnWidth: 240,
                  children: [
                    _campo(Campo.cajaInicial, 'Saldo inicial de caja',
                        prefijo: 'C\$ '),
                    _campo(Campo.cxcInicial, 'Cuentas por cobrar iniciales',
                        prefijo: 'C\$ '),
                    _campo(Campo.cxpInicial, 'Cuentas por pagar iniciales',
                        prefijo: 'C\$ '),
                    _campo(Campo.inventarioInicial, 'Inventario inicial',
                        sufijo: 'unidades'),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ ventas

  Widget _ventas(ResultadoPresupuesto r) {
    return SpacedColumn(
      children: [
        SectionCard(
          title: 'Presupuesto de ventas',
          icon: Icons.point_of_sale,
          child: TablaResultados(filas: [
            FilaResultado('Unidades a vender', r.unidades,
                total: suma(r.unidades), unidades: true),
            FilaResultado('Precio de venta unitario (C\$)', r.precios),
            FilaResultado('Ventas totales (C\$)', r.ventas,
                total: suma(r.ventas), destacada: true),
            FilaResultado('Ventas al contado (C\$)', r.ventasContado,
                total: suma(r.ventasContado)),
            FilaResultado('Ventas a crédito (C\$)', r.ventasCredito,
                total: suma(r.ventasCredito)),
          ]),
        ),
        if (r.ventasCredito[3] > 0)
          InfoBox(
            text:
                'Las ventas a crédito de T4 (C\$ ${formatoMonto(r.ventasCredito[3])}) quedan como cuentas por cobrar al final del año.',
          ),
      ],
    );
  }

  // ----------------------------------------------------------------- compras

  Widget _compras(ResultadoPresupuesto r) {
    var sobrante = false;
    for (var t = 0; t < 4; t++) {
      if (r.invFinalUnid[t] > r.invFinalDeseado[t] + 0.000001) sobrante = true;
    }
    return SpacedColumn(
      children: [
        SectionCard(
          title: 'Presupuesto de compras',
          icon: Icons.shopping_cart_outlined,
          subtitle:
              'Unidades a comprar = Ventas + Inventario final deseado − Inventario inicial',
          child: TablaResultados(filas: [
            FilaResultado('Unidades a vender', r.unidades,
                total: suma(r.unidades), unidades: true),
            FilaResultado('(+) Inventario final deseado (unid.)', r.invFinalDeseado,
                unidades: true),
            FilaResultado('(−) Inventario inicial (unid.)', r.invInicialUnid,
                unidades: true),
            FilaResultado('Unidades a comprar', r.comprasUnid,
                total: suma(r.comprasUnid), destacada: true, unidades: true),
            FilaResultado('Compras totales (C\$)', r.comprasMonto,
                total: suma(r.comprasMonto), destacada: true),
            FilaResultado('Compras al contado (C\$)', r.comprasContado,
                total: suma(r.comprasContado)),
            FilaResultado('Compras a crédito (C\$)', r.comprasCredito,
                total: suma(r.comprasCredito)),
          ]),
        ),
        if (sobrante)
          const InfoBox(
            text:
                'En algún trimestre el inventario inicial es mayor que lo necesario: no se compra y el inventario final queda por encima del deseado.',
          ),
      ],
    );
  }

  // ---------------------------------------------------- costo de bienes vendidos

  Widget _costoBienesVendidos(ResultadoPresupuesto r) {
    return SectionCard(
      title: 'Presupuesto del costo de bienes vendidos',
      icon: Icons.inventory_2_outlined,
      subtitle:
          'Costo de bienes vendidos = Inventario inicial + Compras − Inventario final',
      child: TablaResultados(filas: [
        FilaResultado('Inventario inicial (C\$)', r.invInicialMonto,
            total: r.invInicialMonto[0]),
        FilaResultado('(+) Compras (C\$)', r.comprasMonto,
            total: suma(r.comprasMonto)),
        FilaResultado('(−) Inventario final (C\$)', r.invFinalMonto,
            total: r.invFinalMonto[3]),
        FilaResultado('Costo de bienes vendidos (C\$)', r.cbv,
            total: suma(r.cbv), destacada: true),
      ]),
    );
  }

  // ------------------------------------------------------ gastos de operación

  Widget _gastos(PresupuestosController p, ResultadoPresupuesto r) {
    return SpacedColumn(
      children: [
        SectionCard(
          title: 'Gastos de operación presupuestados',
          icon: Icons.receipt_long_outlined,
          subtitle: 'Escribe el monto de cada gasto en cada trimestre.',
          child: SpacedColumn(
            gap: 14,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: p.hayGastosEnEstados ? _cargarGastos : null,
                    icon: const Icon(Icons.download_outlined),
                    label: Text(
                        'Cargar de los estados (${widget.estados.etiqueta(Periodo.actual)} ÷ 4)'),
                  ),
                  if (!p.hayGastosEnEstados)
                    Text('Primero ingresa gastos de operación en Estados financieros.',
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              GastosEditor(controller: p),
            ],
          ),
        ),
        SectionCard(
          title: 'Resumen de gastos',
          icon: Icons.calculate_outlined,
          child: TablaResultados(filas: [
            FilaResultado('Total gastos de operación (C\$)', r.gastosTotales,
                total: suma(r.gastosTotales), destacada: true),
            FilaResultado('Pagados en efectivo (C\$)', r.gastosEfectivo,
                total: suma(r.gastosEfectivo)),
            FilaResultado('Sin desembolso, p. ej. depreciación (C\$)',
                r.gastosSinEfectivo,
                total: suma(r.gastosSinEfectivo)),
          ]),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------- caja

  Widget _caja(PresupuestosController p, ResultadoPresupuesto r) {
    final minimo = p.valor(Campo.cajaMinima);
    final financiamientoTotal = suma(r.financiamiento);
    final trimestresConFinanciamiento = [
      for (var t = 0; t < 4; t++)
        if (r.financiamiento[t] > 0) trimestres[t],
    ];

    return SpacedColumn(
      children: [
        SectionCard(
          title: 'Otros desembolsos',
          icon: Icons.payments_outlined,
          subtitle:
              'Impuestos, intereses, dividendos, compra de activos y cualquier otra salida de efectivo.',
          child: TablaTrimestres(
            filas: const ['Otros desembolsos (C\$)'],
            valores: [p.otrosDesembolsos],
            onChanged: p.notificarCambio,
          ),
        ),
        SectionCard(
          title: 'Presupuesto de caja',
          icon: Icons.account_balance_wallet_outlined,
          child: TablaResultados(filas: [
            FilaResultado('Saldo inicial de caja (C\$)', r.cajaInicial,
                total: r.cajaInicial[0]),
            FilaResultado('(+) Cobros de ventas (C\$)', r.cobros,
                total: suma(r.cobros)),
            FilaResultado('(−) Pagos de compras (C\$)', r.pagosCompras,
                total: suma(r.pagosCompras)),
            FilaResultado('(−) Pagos de gastos de operación (C\$)', r.gastosEfectivo,
                total: suma(r.gastosEfectivo)),
            FilaResultado('(−) Otros desembolsos (C\$)', r.otros,
                total: suma(r.otros)),
            FilaResultado('(=) Saldo antes de financiamiento (C\$)', r.saldoAntes,
                destacada: true),
            FilaResultado('Saldo mínimo de caja (C\$)', List.filled(4, minimo)),
            FilaResultado('(+) Financiamiento requerido (C\$)', r.financiamiento,
                total: financiamientoTotal),
            FilaResultado('(=) Saldo final de efectivo (C\$)', r.saldoFinal,
                total: r.saldoFinal[3], destacada: true),
          ]),
        ),
        if (p.hayDatos)
          InfoBox(
            icon: financiamientoTotal > 0
                ? Icons.warning_amber_outlined
                : Icons.check_circle_outline,
            text: financiamientoTotal > 0
                ? 'La caja no alcanza el saldo mínimo en ${trimestresConFinanciamiento.join(', ')}: se necesitaría financiamiento por C\$ ${formatoMonto(financiamientoTotal)} en total.'
                : 'La caja se mantiene sobre el saldo mínimo en todos los trimestres. Saldo final proyectado: C\$ ${formatoMonto(r.saldoFinal[3])}.',
          ),
      ],
    );
  }

  // ----------------------------------------------------------------- resumen

  Widget _resumenMaestro(PresupuestosController p, ResultadoPresupuesto r) {
    final ventasAnio = suma(r.ventas);
    final ventasReales = widget.estados.ventasNetas(Periodo.actual);
    final actual = widget.estados.etiqueta(Periodo.actual);

    return SpacedColumn(
      children: [
        SectionCard(
          title: 'Presupuesto maestro del año',
          icon: Icons.dashboard_customize_outlined,
          child: ResponsiveGrid(
            minColumnWidth: 220,
            children: [
              ResultTile(
                  label: 'Ventas presupuestadas',
                  unit: 'C\$',
                  value: formatoMonto(ventasAnio)),
              ResultTile(
                  label: 'Costo de bienes vendidos',
                  unit: 'C\$',
                  value: formatoMonto(suma(r.cbv))),
              ResultTile(
                  label: 'Utilidad operativa presupuestada',
                  unit: 'C\$',
                  value: formatoMonto(suma(r.utilidadOperativa))),
              ResultTile(
                  label: 'Financiamiento requerido',
                  unit: 'C\$',
                  value: formatoMonto(suma(r.financiamiento))),
              ResultTile(
                  label: 'Saldo de efectivo proyectado (T4)',
                  unit: 'C\$',
                  value: formatoMonto(r.saldoFinal[3]),
                  detail: 'Se muestra en el panel principal'),
              if (ventasReales > 0 && ventasAnio > 0)
                ResultTile(
                  label: 'Ventas vs. $actual (estados)',
                  unit: '%',
                  value: ((ventasAnio / ventasReales - 1) * 100).toStringAsFixed(2),
                  detail: 'Ventas reales: C\$ ${formatoMonto(ventasReales)}',
                ),
            ],
          ),
        ),
        SectionCard(
          title: 'Estado de resultados operativo presupuestado',
          icon: Icons.summarize_outlined,
          child: TablaResultados(filas: [
            FilaResultado('Ventas (C\$)', r.ventas, total: ventasAnio),
            FilaResultado('(−) Costo de bienes vendidos (C\$)', r.cbv,
                total: suma(r.cbv)),
            FilaResultado('(=) Utilidad bruta (C\$)', r.utilidadBruta,
                total: suma(r.utilidadBruta), destacada: true),
            FilaResultado('(−) Gastos de operación (C\$)', r.gastosTotales,
                total: suma(r.gastosTotales)),
            FilaResultado('(=) Utilidad operativa (C\$)', r.utilidadOperativa,
                total: suma(r.utilidadOperativa), destacada: true),
          ]),
        ),
      ],
    );
  }
}
