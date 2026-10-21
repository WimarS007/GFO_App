import 'package:flutter/material.dart';

import '../estados/estados_controller.dart';
import '../estados/estados_models.dart';
import '../estados/fuente_estados.dart';
import '../estados/montos.dart';
import '../flujo/flujo_controller.dart';
import '../flujo/flujo_widgets.dart';
import '../ia/ia_service.dart';
import '../ia/ia_widgets.dart';
import '../widgets/common.dart';

/// Flujo de efectivo (método directo): entradas y salidas del período actual
/// por actividad. El saldo inicial y la verificación se conectan con el balance.
class FlujoEfectivoScreen extends StatefulWidget {
  const FlujoEfectivoScreen({
    super.key,
    required this.estados,
    required this.flujo,
  });

  final EstadosController estados;
  final FlujoController flujo;

  @override
  State<FlujoEfectivoScreen> createState() => _FlujoEfectivoScreenState();
}

class _FlujoEfectivoScreenState extends State<FlujoEfectivoScreen> {
  final _saldoManual = TextEditingController();

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
    final v = widget.flujo.saldoInicialManual;
    if (v != 0) _saldoManual.text = formatoMonto(v);
  }

  @override
  void dispose() {
    _saldoManual.dispose();
    _ia.cerrar();
    super.dispose();
  }

  String? _resumen() => widget.flujo.hayMovimientos
      ? widget.flujo.resumenParaIa(widget.estados)
      : null;

  Future<void> _generarIa() async {
    final resumen = _resumen();
    if (resumen == null) {
      setState(() => _errorIa =
          'Primero registra al menos una entrada o salida de efectivo.');
      return;
    }
    setState(() {
      _cargandoIa = true;
      _errorIa = null;
    });
    try {
      final texto = await _ia.interpretar(
        enfoque: 'Estado de flujo de efectivo (operación, inversión y financiamiento)',
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

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.estados, widget.flujo]),
      builder: (context, _) {
        final f = widget.flujo;
        final e = widget.estados;

        // La interpretación se oculta si los datos cambiaron desde que se generó.
        final textoVisible =
            (_textoIa != null && _resumenIa == _resumen()) ? _textoIa : null;

        return PageScaffold(
          title: 'Flujo de efectivo',
          subtitle:
              'Entradas y salidas de efectivo de ${e.etiqueta(Periodo.actual)} clasificadas en actividades de operación, inversión y financiamiento.',
          children: [
            const InfoBox(
              text:
                  'Método directo: escribe los montos siempre en positivo; las entradas suman y las salidas restan. Puedes agregar todas las líneas que necesites.',
            ),
            _saldoInicial(f, e),
            ActividadCard(
                controller: f,
                actividad: Actividad.operacion,
                icono: Icons.store_outlined),
            ActividadCard(
                controller: f,
                actividad: Actividad.inversion,
                icono: Icons.precision_manufacturing_outlined),
            ActividadCard(
                controller: f,
                actividad: Actividad.financiamiento,
                icono: Icons.account_balance_outlined),
            _resultados(f, e),
            _verificacion(f, e),
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

  // ---------------------------------------------------------------- secciones

  Widget _saldoInicial(FlujoController f, EstadosController e) {
    final anterior = e.etiqueta(Periodo.anterior);
    return SectionCard(
      title: 'Saldo inicial de efectivo',
      icon: Icons.account_balance_wallet_outlined,
      child: SpacedColumn(
        gap: 12,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tomar el saldo inicial del balance'),
            subtitle: Text(
                'Efectivo y equivalentes (efectivo, caja y bancos) al cierre de $anterior.'),
            value: f.saldoDesdeEstados,
            onChanged: f.setSaldoDesdeEstados,
          ),
          if (f.saldoDesdeEstados) ...[
            ResponsiveGrid(
              minColumnWidth: 260,
              children: [
                ValorDeEstados(
                  label: 'Efectivo al cierre de $anterior (C\$)',
                  valor: formatoMonto(f.efectivoEnBalance(e, Periodo.anterior)),
                ),
              ],
            ),
            if (f.efectivoEnBalance(e, Periodo.anterior) == 0)
              InfoBox(
                icon: Icons.warning_amber_outlined,
                text: f.hayCuentasDeEfectivo(e)
                    ? 'Las cuentas de efectivo del balance de $anterior están en cero.'
                    : 'No se encontró ninguna cuenta de efectivo, caja o bancos en los activos corrientes del balance. Agrégala en Estados financieros o escribe el saldo a mano.',
              ),
          ] else
            ResponsiveGrid(
              minColumnWidth: 260,
              children: [
                NumberField(
                  label: 'Saldo inicial de efectivo',
                  prefix: 'C\$ ',
                  controller: _saldoManual,
                  onChanged: (t) => f.setSaldoInicialManual(parseMonto(t) ?? 0),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _resultados(FlujoController f, EstadosController e) {
    String c(double v) => formatoMonto(v);

    return SectionCard(
      title: 'Resultados',
      icon: Icons.calculate_outlined,
      child: ResponsiveGrid(
        minColumnWidth: 220,
        children: [
          ResultTile(
            label: 'Flujo neto de operación',
            unit: 'C\$',
            value: c(f.flujoNeto(Actividad.operacion)),
            detail: 'Entradas − Salidas',
          ),
          ResultTile(
            label: 'Flujo neto de inversión',
            unit: 'C\$',
            value: c(f.flujoNeto(Actividad.inversion)),
            detail: 'Entradas − Salidas',
          ),
          ResultTile(
            label: 'Flujo neto de financiamiento',
            unit: 'C\$',
            value: c(f.flujoNeto(Actividad.financiamiento)),
            detail: 'Entradas − Salidas',
          ),
          ResultTile(
            label: 'Variación neta de efectivo',
            unit: 'C\$',
            value: c(f.variacionNeta),
            detail: 'Operación + Inversión + Financiamiento',
          ),
          ResultTile(
            label: 'Saldo inicial de efectivo',
            unit: 'C\$',
            value: c(f.saldoInicial(e)),
            detail: f.saldoDesdeEstados ? 'Tomado del balance' : 'Escrito a mano',
          ),
          ResultTile(
            label: 'Saldo final de efectivo',
            unit: 'C\$',
            value: c(f.saldoFinal(e)),
            detail: 'Saldo inicial + Variación neta',
          ),
        ],
      ),
    );
  }

  /// Compara el saldo final calculado con el efectivo del balance actual.
  Widget _verificacion(FlujoController f, EstadosController e) {
    final actual = e.etiqueta(Periodo.actual);
    final hayBalance = f.hayCuentasDeEfectivo(e) && e.hayDatos(Periodo.actual, Estado.balance);

    final Widget contenido;
    if (!hayBalance) {
      contenido = const InfoBox(
        text:
            'Para verificar el saldo final, ingresa el balance del período actual con una cuenta de efectivo, caja o bancos en Estados financieros.',
      );
    } else {
      final balance = f.efectivoEnBalance(e, Periodo.actual);
      final dif = f.saldoFinal(e) - balance;
      final cuadra = dif.abs() < 0.01;
      contenido = SpacedColumn(
        gap: 12,
        children: [
          ResponsiveGrid(
            minColumnWidth: 220,
            children: [
              ResultTile(
                label: 'Saldo final calculado',
                unit: 'C\$',
                value: formatoMonto(f.saldoFinal(e)),
              ),
              ResultTile(
                label: 'Efectivo según el balance',
                unit: 'C\$',
                value: formatoMonto(balance),
                detail: actual,
              ),
              ResultTile(
                label: 'Diferencia',
                unit: 'C\$',
                value: formatoMonto(dif),
                detail: 'Calculado − Balance',
              ),
            ],
          ),
          InfoBox(
            icon: cuadra ? Icons.check_circle_outline : Icons.warning_amber_outlined,
            text: cuadra
                ? 'El saldo final coincide con el efectivo del balance de $actual.'
                : 'El saldo final no coincide con el efectivo del balance de $actual. Revisa el saldo inicial y los movimientos registrados.',
          ),
        ],
      );
    }

    return SectionCard(
      title: 'Verificación con el balance',
      icon: Icons.fact_check_outlined,
      subtitle: 'El saldo final debería ser igual al efectivo del balance del período actual.',
      child: contenido,
    );
  }
}
