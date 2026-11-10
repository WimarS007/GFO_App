import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Escritorio y móvil: diálogo «Guardar como».
Future<String?> guardarPlataforma(
  String nombre,
  String extension,
  Uint8List bytes,
) async {
  final ruta = await FilePicker.platform.saveFile(
    dialogTitle: 'Guardar reporte',
    fileName: '$nombre.$extension',
    type: FileType.custom,
    allowedExtensions: [extension],
    bytes: bytes, // obligatorio en móvil
  );
  if (ruta == null) return null;
  if (Platform.isAndroid || Platform.isIOS) return ruta;

  // En escritorio algunas versiones solo devuelven la ruta sin escribir el
  // archivo: se agrega la extensión si falta y se escriben los bytes.
  final sufijo = '.${extension.toLowerCase()}';
  var destino = ruta;
  if (!ruta.toLowerCase().endsWith(sufijo)) {
    destino = '$ruta$sufijo';
    final sinExtension = File(ruta);
    if (await sinExtension.exists()) await sinExtension.rename(destino);
  }
  final archivo = File(destino);
  if (!await archivo.exists() || await archivo.length() == 0) {
    await archivo.writeAsBytes(bytes, flush: true);
  }
  return destino;
}
