/// Convierte un texto a monto. Devuelve null si no tiene forma de número.
/// Acepta: 1500, 1,500.75, C$ 1,500, $1500, -300, (300) -> -300
double? parseMonto(String texto) {
  var t = texto.trim();
  if (t.isEmpty) return null;

  final valido = RegExp(
    r'^\(?\s*-?\s*(?:C\$|\$)?\s*-?\s*\d[\d,]*(?:\.\d+)?\s*\)?$',
    caseSensitive: false,
  );
  if (!valido.hasMatch(t)) return null;

  final entreParentesis = t.startsWith('(') && t.endsWith(')');
  final conSigno = t.contains('-');
  t = t.replaceAll(RegExp(r'[^0-9.]'), '');
  final v = double.tryParse(t);
  if (v == null) return null;
  return (entreParentesis || conSigno) ? -v : v;
}

/// 1234567.5 -> "1,234,567.50"
String formatoMonto(double v, {int decimales = 2}) {
  final negativo = v < 0 && v.abs() >= 0.5 * _unidad(decimales);
  final partes = v.abs().toStringAsFixed(decimales).split('.');
  final entero = partes[0];
  final buffer = StringBuffer();
  for (var i = 0; i < entero.length; i++) {
    if (i > 0 && (entero.length - i) % 3 == 0) buffer.write(',');
    buffer.write(entero[i]);
  }
  final decimalesTxt = decimales > 0 ? '.${partes[1]}' : '';
  final signo = negativo ? '-' : '';
  return '$signo$buffer$decimalesTxt';
}

double _unidad(int decimales) {
  var u = 1.0;
  for (var i = 0; i < decimales; i++) {
    u /= 10;
  }
  return u;
}
