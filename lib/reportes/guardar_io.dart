import 'dart:io';
import 'dart:typed_data';

/// Escritorio: agrega la extensión si falta y escribe los bytes si el archivo
/// no quedó creado. En Android / iOS file_picker ya escribió el contenido.
Future<String> asegurarEscrito(
  String ruta,
  Uint8List bytes,
  String extension,
) async {
  if (Platform.isAndroid || Platform.isIOS) return ruta;

  final sufijo = '.${extension.toLowerCase()}';
  var destino = ruta;
  if (!ruta.toLowerCase().endsWith(sufijo)) {
    destino = '$ruta$sufijo';
    final sinExtension = File(ruta);
    if (await sinExtension.exists()) {
      await sinExtension.rename(destino);
    }
  }

  final archivo = File(destino);
  if (!await archivo.exists() || await archivo.length() == 0) {
    await archivo.writeAsBytes(bytes, flush: true);
  }
  return destino;
}
