import 'dart:typed_data';

import 'guardar_stub.dart'
    if (dart.library.html) 'guardar_web.dart'
    if (dart.library.io) 'guardar_io.dart' as plataforma;

/// Guarda el archivo según la plataforma:
/// - Web: el navegador lo descarga directamente.
/// - Escritorio / móvil: diálogo «Guardar como».
///
/// Devuelve la ruta (o el nombre del archivo en la web) o `null` si la persona
/// canceló.
Future<String?> guardarArchivo({
  required String nombre,
  required String extension,
  required Uint8List bytes,
}) =>
    plataforma.guardarPlataforma(nombre, extension, bytes);
