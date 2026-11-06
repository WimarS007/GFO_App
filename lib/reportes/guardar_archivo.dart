import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'guardar_stub.dart' if (dart.library.io) 'guardar_io.dart' as plataforma;

/// Pide al usuario dónde guardar el archivo y lo escribe.
///
/// Devuelve la ruta donde quedó (en la web, solo el nombre del archivo, porque
/// el navegador lo descarga) o `null` si la persona canceló.
Future<String?> guardarArchivo({
  required String nombre,
  required String extension,
  required Uint8List bytes,
}) async {
  final nombreCompleto = '$nombre.$extension';
  final ruta = await FilePicker.platform.saveFile(
    dialogTitle: 'Guardar reporte',
    fileName: nombreCompleto,
    type: FileType.custom,
    allowedExtensions: [extension],
    bytes: bytes, // obligatorio en móvil y web
  );

  // En la web el navegador descarga el archivo y no devuelve una ruta.
  if (kIsWeb) return nombreCompleto;
  if (ruta == null) return null;

  // En escritorio algunas versiones de file_picker solo devuelven la ruta
  // elegida sin escribir el archivo; aquí se asegura que exista.
  return plataforma.asegurarEscrito(ruta, bytes, extension);
}
