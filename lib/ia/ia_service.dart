import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ia_secrets.dart';

/// Configuración de la conexión con la IA (API de Google Gemini).
/// La clave se toma de [IaSecrets] (o de --dart-define=GEMINI_API_KEY).
class IaConfig {
  const IaConfig();

  static const modeloPredeterminado = 'gemini-flash-latest';

  String get apiKey {
    const deEntorno = String.fromEnvironment('GEMINI_API_KEY');
    return (deEntorno.isNotEmpty ? deEntorno : IaSecrets.geminiApiKey).trim();
  }

  String get modelo => const String.fromEnvironment(
        'GEMINI_MODEL',
        defaultValue: modeloPredeterminado,
      );

  bool get configurada => apiKey.isNotEmpty;
}

class IaException implements Exception {
  const IaException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Cliente mínimo de la API de Google Gemini (generateContent).
class IaService {
  IaService(this.config, {http.Client? cliente})
      : _http = cliente ?? http.Client();

  final IaConfig config;
  final http.Client _http;

  static Uri _url(String modelo) => Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/${Uri.encodeComponent(modelo)}:generateContent');

  /// Modelo que ya funcionó en esta sesión (se reutiliza).
  String? _modeloElegido;

  Map<String, String> get _cabeceras => {
        'content-type': 'application/json',
        'x-goog-api-key': config.apiKey,
      };

  Future<http.Response> _post(String modelo, String cuerpo) async {
    try {
      return await _http
          .post(_url(modelo), headers: _cabeceras, body: cuerpo)
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const IaException(
          'La IA tardó demasiado en responder. Intenta de nuevo.');
    } catch (_) {
      throw const IaException(
          'No se pudo conectar con la IA. Revisa tu conexión a internet.');
    }
  }

  /// Pregunta a Google qué modelos de texto tiene disponibles esta clave y
  /// elige el más adecuado (prefiere "flash" estables y recientes).
  Future<String?> _buscarModelo({required String excluir}) async {
    try {
      final r = await _http
          .get(
            Uri.parse(
                'https://generativelanguage.googleapis.com/v1beta/models?pageSize=200'),
            headers: _cabeceras,
          )
          .timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) return null;
      final lista = (jsonDecode(utf8.decode(r.bodyBytes))['models'] as List?) ??
          const [];

      const excluidas = [
        'tts', 'image', 'embedding', 'live', 'audio', 'robotics',
        'computer-use', 'native', 'aqa', 'veo', 'imagen',
      ];
      final candidatos = <String>[];
      for (final m in lista.whereType<Map>()) {
        final nombre = (m['name'] ?? '').toString().replaceFirst('models/', '');
        final metodos = (m['supportedGenerationMethods'] as List?) ?? const [];
        if (!nombre.startsWith('gemini')) continue;
        if (nombre == excluir) continue;
        if (!metodos.contains('generateContent')) continue;
        if (excluidas.any(nombre.contains)) continue;
        candidatos.add(nombre);
      }
      if (candidatos.isEmpty) return null;

      int puntaje(String n) {
        var p = 0;
        if (n.contains('flash')) p += 100;
        if (n.contains('lite')) p -= 30;
        if (n.contains('preview') || n.contains('exp')) p -= 50;
        if (n.contains('latest')) p += 10;
        return p;
      }

      // Mayor puntaje primero; a igualdad, el nombre más "alto" (versión mayor).
      candidatos.sort((a, b) {
        final c = puntaje(b).compareTo(puntaje(a));
        return c != 0 ? c : b.compareTo(a);
      });
      return candidatos.first;
    } catch (_) {
      return null;
    }
  }

  static const _sistema = '''
Eres un analista financiero que ayuda a estudiantes y pequeños empresarios de Nicaragua (moneda: córdobas, C\$).
Recibirás cifras ya calculadas de los estados financieros de una empresa.
Reglas:
- Responde siempre en español, con lenguaje claro y sin jerga innecesaria.
- Usa únicamente las cifras recibidas. Si falta un dato (n/d), dilo; no inventes valores.
- No hagas cálculos nuevos que contradigan los recibidos.
- Estructura: 1) Hallazgos principales, 2) Puntos fuertes, 3) Riesgos o alertas, 4) Recomendaciones concretas.
- Sé breve: máximo 250 palabras. Usa viñetas cortas.
- Esto es apoyo académico/orientativo, no asesoría financiera, contable o legal profesional.
''';

  /// Pide a la IA que interprete las cifras de [resumen].
  /// [enfoque] indica qué parte se analiza (p. ej. "Razones financieras").
  Future<String> interpretar({
    required String enfoque,
    required String resumen,
  }) async {
    if (!config.configurada) {
      throw const IaException(
          'La IA no está disponible: falta la clave de Gemini en ia/ia_secrets.dart.');
    }

    final cuerpo = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': _sistema},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': 'Interpreta este análisis: $enfoque.\n\nDatos:\n$resumen'},
          ],
        },
      ],
      'generationConfig': {
        'maxOutputTokens': 4096,
        'temperature': 0.4,
      },
    });

    var modelo = _modeloElegido ?? config.modelo;
    var r = await _post(modelo, cuerpo);

    // Si el modelo no existe (Google los retira con el tiempo), se busca
    // automáticamente uno disponible para esta clave y se reintenta una vez.
    if (r.statusCode == 404) {
      final alterno = await _buscarModelo(excluir: modelo);
      if (alterno != null) {
        modelo = alterno;
        r = await _post(modelo, cuerpo);
      }
    }
    if (r.statusCode == 200) _modeloElegido = modelo;

    final texto = utf8.decode(r.bodyBytes);
    if (r.statusCode != 200) {
      throw IaException(_mensajeError(r.statusCode, texto));
    }

    try {
      final json = jsonDecode(texto) as Map<String, dynamic>;
      final candidatos = json['candidates'] as List?;
      if (candidatos == null || candidatos.isEmpty) {
        throw const IaException(
            'La IA no devolvió respuesta (puede haber sido bloqueada por sus filtros).');
      }
      final partes = ((candidatos.first as Map)['content']?['parts'] as List?)
              ?.whereType<Map>()
              .map((p) => (p['text'] ?? '').toString()) ??
          const <String>[];
      final salida = partes.join('\n').trim();
      if (salida.isEmpty) {
        throw const IaException('La IA devolvió una respuesta vacía.');
      }
      return salida;
    } on IaException {
      rethrow;
    } catch (_) {
      throw const IaException('No se pudo leer la respuesta de la IA.');
    }
  }

  static String _mensajeError(int status, String cuerpo) {
    String? detalle;
    try {
      final j = jsonDecode(cuerpo) as Map<String, dynamic>;
      detalle = (j['error'] as Map?)?['message'] as String?;
    } catch (_) {}

    final d = (detalle ?? '').toLowerCase();
    switch (status) {
      case 400:
        if (d.contains('api key')) {
          return 'La clave de la IA no es válida. Revisa ia/ia_secrets.dart.';
        }
        return 'La IA rechazó la solicitud${detalle != null ? ': $detalle' : '.'}';
      case 401:
      case 403:
        return 'La clave de la IA no es válida o no tiene permiso. Revisa ia/ia_secrets.dart.';
      case 404:
        return 'El modelo de IA configurado no existe. Revisa IaConfig en ia_service.dart.';
      case 429:
        return 'Se alcanzó el límite gratuito de uso. Espera un momento e intenta de nuevo.';
      case 500:
      case 503:
        return 'La IA está saturada en este momento. Intenta de nuevo en unos minutos.';
      default:
        return 'Error de la IA ($status)${detalle != null ? ': $detalle' : '.'}';
    }
  }

  void cerrar() => _http.close();
}