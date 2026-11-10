import 'dart:typed_data';

Future<String?> guardarPlataforma(
  String nombre,
  String extension,
  Uint8List bytes,
) async =>
    throw UnsupportedError('Esta plataforma no puede guardar archivos.');
