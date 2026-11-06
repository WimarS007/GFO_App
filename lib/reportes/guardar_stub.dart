import 'dart:typed_data';

/// Plataformas sin dart:io (web): no hay nada más que hacer.
Future<String> asegurarEscrito(
  String ruta,
  Uint8List bytes,
  String extension,
) async =>
    ruta;
