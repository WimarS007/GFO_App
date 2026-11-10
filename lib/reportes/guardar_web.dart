// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Web: crea un enlace temporal y lo «clickea» para que el navegador descargue.
Future<String?> guardarPlataforma(
  String nombre,
  String extension,
  Uint8List bytes,
) async {
  final nombreCompleto = '$nombre.$extension';
  final tipo = extension == 'pdf'
      ? 'application/pdf'
      : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  final blob = html.Blob([bytes], tipo);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final enlace = html.AnchorElement(href: url)
    ..download = nombreCompleto
    ..style.display = 'none';
  html.document.body?.children.add(enlace);
  enlace.click();
  enlace.remove();
  html.Url.revokeObjectUrl(url);
  return nombreCompleto;
}
