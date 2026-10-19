import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../estados/montos.dart';
import 'cvu_calculos.dart';

/// Gráfica del punto de equilibrio: ingresos totales vs. costos totales.
class GraficaCvu extends StatelessWidget {
  const GraficaCvu({super.key, required this.resultado});

  final ResultadoCvu resultado;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tieneActual = (resultado.datos.unidades ?? 0) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _Leyenda(color: cs.primary, texto: 'Ingresos totales'),
            _Leyenda(color: cs.error, texto: 'Costos totales'),
            _Leyenda(color: cs.outline, texto: 'Costos fijos'),
            if (resultado.hayEquilibrio)
              _Leyenda(color: cs.tertiary, texto: 'Punto de equilibrio'),
            if (tieneActual)
              _Leyenda(color: cs.secondary, texto: 'Ventas actuales'),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 300,
          width: double.infinity,
          child: CustomPaint(
            painter: _GraficaPainter(
              resultado: resultado,
              colorIngresos: cs.primary,
              colorCostos: cs.error,
              colorFijos: cs.outline,
              colorPunto: cs.tertiary,
              colorActual: cs.secondary,
              colorCuadricula: cs.outlineVariant,
              colorEjes: cs.outline,
              colorTexto: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 4, color: color),
        const SizedBox(width: 6),
        Text(texto, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _GraficaPainter extends CustomPainter {
  _GraficaPainter({
    required this.resultado,
    required this.colorIngresos,
    required this.colorCostos,
    required this.colorFijos,
    required this.colorPunto,
    required this.colorActual,
    required this.colorCuadricula,
    required this.colorEjes,
    required this.colorTexto,
  });

  final ResultadoCvu resultado;
  final Color colorIngresos;
  final Color colorCostos;
  final Color colorFijos;
  final Color colorPunto;
  final Color colorActual;
  final Color colorCuadricula;
  final Color colorEjes;
  final Color colorTexto;

  static String _abreviar(double v) {
    final a = v.abs();
    if (a >= 1e6) return '${(v / 1e6).toStringAsFixed(a >= 1e7 ? 0 : 1)}M';
    if (a >= 1e3) return '${(v / 1e3).toStringAsFixed(a >= 1e4 ? 0 : 1)}K';
    return v.toStringAsFixed(a >= 100 || v == v.roundToDouble() ? 0 : 1);
  }

  /// ancla: -1 = el texto termina en x, 0 = centrado en x, 1 = empieza en x.
  void _texto(Canvas canvas, Size size, String s, double x, double y,
      {int ancla = 0, bool centrarVertical = false, Color? color, bool negrita = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color ?? colorTexto,
          fontSize: 11,
          fontWeight: negrita ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = ancla < 0 ? x - tp.width : (ancla == 0 ? x - tp.width / 2 : x);
    dx = dx.clamp(0.0, math.max(0.0, size.width - tp.width)).toDouble();
    final dy = centrarVertical ? y - tp.height / 2 : y;
    tp.paint(canvas, Offset(dx, dy));
  }

  void _lineaPunteada(Canvas canvas, Offset a, Offset b, Paint paint) {
    const trazo = 6.0;
    const hueco = 4.0;
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final fin = math.min(d + trazo, total);
      canvas.drawLine(a + dir * d, a + dir * fin, paint);
      d += trazo + hueco;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    const izq = 62.0, der = 18.0, arriba = 20.0, abajo = 40.0;
    final w = size.width - izq - der;
    final h = size.height - arriba - abajo;
    if (w <= 0 || h <= 0) return;

    final d = resultado.datos;
    final pe = resultado.puntoEquilibrioUnidades;
    final actual = d.unidades ?? 0;

    var xMax = math.max(pe ?? 0, actual) * 1.5;
    if (xMax <= 0) xMax = 100;
    final yMax =
        math.max(d.precio * xMax, d.costoVariable * xMax + d.costosFijos) * 1.08;

    double px(double x) => izq + x / xMax * w;
    double py(double y) => arriba + h - y / yMax * h;

    final cuadricula = Paint()
      ..color = colorCuadricula
      ..strokeWidth = 1;
    final ejes = Paint()
      ..color = colorEjes
      ..strokeWidth = 1.5;

    // Cuadrícula y etiquetas del eje Y
    _texto(canvas, size, 'C\$', izq - 8, 0, ancla: -1);
    for (var i = 0; i <= 4; i++) {
      final y = yMax * i / 4;
      final yy = py(y);
      canvas.drawLine(Offset(izq, yy), Offset(izq + w, yy), cuadricula);
      _texto(canvas, size, _abreviar(y), izq - 8, yy,
          ancla: -1, centrarVertical: true);
    }

    // Etiquetas del eje X
    for (var i = 0; i <= 5; i++) {
      final x = xMax * i / 5;
      _texto(canvas, size, _abreviar(x), px(x), arriba + h + 6);
    }
    _texto(canvas, size, 'Unidades vendidas', izq + w / 2, arriba + h + 22);

    // Ejes
    canvas.drawLine(Offset(izq, arriba), Offset(izq, arriba + h), ejes);
    canvas.drawLine(Offset(izq, arriba + h), Offset(izq + w, arriba + h), ejes);

    // Costos fijos (línea punteada)
    final pFijos = Paint()
      ..color = colorFijos
      ..strokeWidth = 1.8;
    _lineaPunteada(canvas, Offset(px(0), py(d.costosFijos)),
        Offset(px(xMax), py(d.costosFijos)), pFijos);

    // Ingresos y costos totales
    final pIngresos = Paint()
      ..color = colorIngresos
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    final pCostos = Paint()
      ..color = colorCostos
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(px(0), py(0)), Offset(px(xMax), py(d.precio * xMax)), pIngresos);
    canvas.drawLine(Offset(px(0), py(d.costosFijos)),
        Offset(px(xMax), py(d.costoVariable * xMax + d.costosFijos)), pCostos);

    // Ventas actuales
    if (actual > 0) {
      final pActual = Paint()
        ..color = colorActual
        ..strokeWidth = 1.5;
      _lineaPunteada(canvas, Offset(px(actual), arriba),
          Offset(px(actual), arriba + h), pActual);
      _texto(canvas, size, 'Ventas actuales', px(actual), arriba + h - 16,
          color: colorActual, negrita: true);
    }

    // Punto de equilibrio
    if (pe != null) {
      final punto = Offset(px(pe), py(pe * d.precio));
      final pGuia = Paint()
        ..color = colorPunto
        ..strokeWidth = 1.2;
      _lineaPunteada(canvas, punto, Offset(punto.dx, arriba + h), pGuia);
      _lineaPunteada(canvas, punto, Offset(izq, punto.dy), pGuia);
      canvas.drawCircle(punto, 6, Paint()..color = colorPunto);
      canvas.drawCircle(
          punto,
          6,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      _texto(canvas, size, 'PE: ${formatoMonto(pe)} u', punto.dx, punto.dy - 24,
          color: colorPunto, negrita: true);
    }
  }

  @override
  bool shouldRepaint(covariant _GraficaPainter old) => true;
}
