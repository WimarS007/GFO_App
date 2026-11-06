import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Familia de API que habla un proveedor.
enum IaTipo {
  /// Google Gemini (generateContent).
  gemini,

  /// Cualquier API compatible con OpenAI (/chat/completions):
  /// OpenAI, Groq, OpenRouter, DeepSeek, Mistral, Together, Ollama, etc.
  openAiCompatible,

  /// Anthropic Claude (/v1/messages).
  claude,
}

/// Datos de un proveedor de IA. Se declaran en orden de prioridad en
/// `IaSecrets.proveedores`: si uno falla, se usa el siguiente.
class IaProveedorConfig {
  const IaProveedorConfig({
    required this.tipo,
    required this.nombre,
    required this.apiKey,
    required this.modelo,
    this.baseUrl = '',
  });

  /// Google Gemini. Clave gratis: https://aistudio.google.com/apikey
  /// Puedes usar varias claves de Gemini; pon un [nombre] distinto a cada una
  /// (p. ej. 'Gemini 2') para saber cuál falló.
  const IaProveedorConfig.gemini(
    String apiKey, {
    String modelo = 'gemini-flash-latest',
    String nombre = 'Gemini',
  }) : this(
          tipo: IaTipo.gemini,
          nombre: nombre,
          apiKey: apiKey,
          modelo: modelo,
        );

  /// Groq (rápido y con capa gratuita). Clave: https://console.groq.com/keys
  const IaProveedorConfig.groq(
    String apiKey, {
    String modelo = 'llama-3.3-70b-versatile',
  }) : this(
          tipo: IaTipo.openAiCompatible,
          nombre: 'Groq',
          apiKey: apiKey,
          modelo: modelo,
          baseUrl: 'https://api.groq.com/openai/v1',
        );

  /// OpenRouter (muchos modelos, algunos gratis). Clave: https://openrouter.ai/keys
  const IaProveedorConfig.openRouter(
    String apiKey, {
    String modelo = 'meta-llama/llama-3.3-70b-instruct:free',
  }) : this(
          tipo: IaTipo.openAiCompatible,
          nombre: 'OpenRouter',
          apiKey: apiKey,
          modelo: modelo,
          baseUrl: 'https://openrouter.ai/api/v1',
        );

  /// OpenAI (ChatGPT). Clave: https://platform.openai.com/api-keys
  const IaProveedorConfig.openAi(
    String apiKey, {
    String modelo = 'gpt-4o-mini',
  }) : this(
          tipo: IaTipo.openAiCompatible,
          nombre: 'OpenAI',
          apiKey: apiKey,
          modelo: modelo,
          baseUrl: 'https://api.openai.com/v1',
        );

  /// DeepSeek. Clave: https://platform.deepseek.com/api_keys
  const IaProveedorConfig.deepSeek(
    String apiKey, {
    String modelo = 'deepseek-chat',
  }) : this(
          tipo: IaTipo.openAiCompatible,
          nombre: 'DeepSeek',
          apiKey: apiKey,
          modelo: modelo,
          baseUrl: 'https://api.deepseek.com/v1',
        );

  /// Mistral. Clave: https://console.mistral.ai/api-keys
  const IaProveedorConfig.mistral(
    String apiKey, {
    String modelo = 'mistral-small-latest',
  }) : this(
          tipo: IaTipo.openAiCompatible,
          nombre: 'Mistral',
          apiKey: apiKey,
          modelo: modelo,
          baseUrl: 'https://api.mistral.ai/v1',
        );

  /// Anthropic Claude. Clave: https://console.anthropic.com/settings/keys
  const IaProveedorConfig.claude(
    String apiKey, {
    String modelo = 'claude-haiku-5-5',
  }) : this(
          tipo: IaTipo.claude,
          nombre: 'Claude',
          apiKey: apiKey,
          modelo: modelo,
        );

  /// Cualquier otro servicio compatible con OpenAI (Together, Fireworks,
  /// Cerebras, un servidor propio, etc.). [baseUrl] termina antes de
  /// "/chat/completions", p. ej. "https://api.together.xyz/v1".
  const IaProveedorConfig.compatible({
    required String nombre,
    required String apiKey,
    required String modelo,
    required String baseUrl,
  }) : this(
          tipo: IaTipo.openAiCompatible,
          nombre: nombre,
          apiKey: apiKey,
          modelo: modelo,
          baseUrl: baseUrl,
        );

  final IaTipo tipo;
  final String nombre;
  final String apiKey;
  final String modelo;
  final String baseUrl;

  /// Un proveedor con la clave vacía se ignora (así puedes dejar los que no
  /// uses con '' sin borrarlos).
  bool get activo => apiKey.trim().isNotEmpty;

  /// Identificador interno (para recordar cuáles fallaron).
  String get id => '$nombre|$modelo|${apiKey.trim().hashCode}';
}

/// Error de un proveedor concreto. El orquestador lo captura y pasa al
/// siguiente proveedor.
class IaFallo implements Exception {
  const IaFallo(this.mensaje, {this.status, this.definitivo = false});

  final String mensaje;
  final int? status;

  /// True si reintentar no tiene sentido en esta sesión (clave inválida,
  /// sin permiso).
  final bool definitivo;

  @override
  String toString() => mensaje;
}

/// Cliente de un proveedor: recibe un mensaje de sistema y uno de usuario
/// y devuelve el texto generado (o lanza [IaFallo]).
abstract class IaProveedor {
  IaProveedor(this.config, this.cliente);

  final IaProveedorConfig config;
  final http.Client cliente;

  String get nombre => config.nombre;

  static const _tiempoMax = Duration(seconds: 40);

  Future<String> generar({required String sistema, required String usuario});

  factory IaProveedor.crear(IaProveedorConfig c, http.Client cliente) {
    switch (c.tipo) {
      case IaTipo.gemini:
        return _GeminiProveedor(c, cliente);
      case IaTipo.openAiCompatible:
        return _OpenAiProveedor(c, cliente);
      case IaTipo.claude:
        return _ClaudeProveedor(c, cliente);
    }
  }

  Future<http.Response> postJson(
    Uri url,
    Map<String, String> cabeceras,
    Map<String, dynamic> cuerpo,
  ) async {
    try {
      return await cliente
          .post(
            url,
            headers: {'content-type': 'application/json', ...cabeceras},
            body: jsonEncode(cuerpo),
          )
          .timeout(_tiempoMax);
    } on TimeoutException {
      throw const IaFallo('tardó demasiado en responder.');
    } catch (_) {
      throw const IaFallo('no se pudo conectar (revisa tu internet).');
    }
  }

  /// Convierte una respuesta HTTP no exitosa en [IaFallo].
  IaFallo errorHttp(http.Response r) {
    final texto = utf8.decode(r.bodyBytes, allowMalformed: true);
    String? detalle;
    try {
      final j = jsonDecode(texto);
      final e = j is Map ? j['error'] : null;
      if (e is Map) {
        detalle = e['message']?.toString();
      } else if (e is String) {
        detalle = e;
      }
    } catch (_) {}
    final d = (detalle ?? '').toLowerCase();
    final extra = detalle != null ? ': $detalle' : '.';

    switch (r.statusCode) {
      case 400:
        if (d.contains('api key') || d.contains('api_key')) {
          return const IaFallo('la clave no es válida.',
              status: 400, definitivo: true);
        }
        return IaFallo('rechazó la solicitud$extra', status: 400);
      case 401:
      case 403:
        return IaFallo('la clave no es válida o no tiene permiso.',
            status: r.statusCode, definitivo: true);
      case 402:
        return const IaFallo('sin saldo o crédito disponible.',
            status: 402, definitivo: true);
      case 404:
        return IaFallo('el modelo "${config.modelo}" no existe.', status: 404);
      case 429:
        return const IaFallo('alcanzó su límite de uso. Intenta más tarde.',
            status: 429);
      default:
        if (r.statusCode >= 500) {
          return IaFallo('está saturada (${r.statusCode}).',
              status: r.statusCode);
        }
        return IaFallo('error ${r.statusCode}$extra', status: r.statusCode);
    }
  }

  Map<String, dynamic> decodificar(http.Response r) {
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    throw const IaFallo('devolvió una respuesta ilegible.');
  }
}

// ───────────────────────── Gemini ─────────────────────────

class _GeminiProveedor extends IaProveedor {
  _GeminiProveedor(super.config, super.cliente);

  static const _base = 'https://generativelanguage.googleapis.com/v1beta';

  /// Modelo que ya funcionó en esta sesión (se reutiliza).
  String? _modeloElegido;

  Map<String, String> get _cabeceras => {'x-goog-api-key': config.apiKey.trim()};

  Uri _url(String modelo) =>
      Uri.parse('$_base/models/${Uri.encodeComponent(modelo)}:generateContent');

  @override
  Future<String> generar({
    required String sistema,
    required String usuario,
  }) async {
    final cuerpo = {
      'systemInstruction': {
        'parts': [
          {'text': sistema},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': usuario},
          ],
        },
      ],
      'generationConfig': {
        'maxOutputTokens': 4096,
        'temperature': 0.4,
      },
    };

    var modelo = _modeloElegido ?? config.modelo;
    var r = await postJson(_url(modelo), _cabeceras, cuerpo);

    // Si el modelo no existe (Google los retira con el tiempo), se busca
    // automáticamente uno disponible para esta clave y se reintenta una vez.
    if (r.statusCode == 404) {
      final alterno = await _buscarModelo(excluir: modelo);
      if (alterno != null) {
        modelo = alterno;
        r = await postJson(_url(modelo), _cabeceras, cuerpo);
      }
    }
    if (r.statusCode != 200) throw errorHttp(r);
    _modeloElegido = modelo;

    final json = decodificar(r);
    final candidatos = json['candidates'];
    if (candidatos is! List || candidatos.isEmpty) {
      throw const IaFallo('no devolvió respuesta (la bloquearon sus filtros).');
    }
    final partes = ((candidatos.first as Map)['content']?['parts'] as List?)
            ?.whereType<Map>()
            .map((p) => (p['text'] ?? '').toString()) ??
        const <String>[];
    final salida = partes.join('\n').trim();
    if (salida.isEmpty) throw const IaFallo('devolvió una respuesta vacía.');
    return salida;
  }

  /// Pregunta a Google qué modelos de texto tiene disponibles esta clave y
  /// elige el más adecuado (prefiere "flash" estables y recientes).
  Future<String?> _buscarModelo({required String excluir}) async {
    try {
      final r = await cliente
          .get(Uri.parse('$_base/models?pageSize=200'), headers: _cabeceras)
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

      candidatos.sort((a, b) {
        final c = puntaje(b).compareTo(puntaje(a));
        return c != 0 ? c : b.compareTo(a);
      });
      return candidatos.first;
    } catch (_) {
      return null;
    }
  }
}

// ─────────────── OpenAI y compatibles (Groq, etc.) ───────────────

class _OpenAiProveedor extends IaProveedor {
  _OpenAiProveedor(super.config, super.cliente);

  @override
  Future<String> generar({
    required String sistema,
    required String usuario,
  }) async {
    var base = config.baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    // No se envían temperature ni max_tokens a propósito: algunos modelos
    // nuevos los rechazan. La longitud ya se limita en el prompt.
    final r = await postJson(
      Uri.parse('$base/chat/completions'),
      {'authorization': 'Bearer ${config.apiKey.trim()}'},
      {
        'model': config.modelo,
        'messages': [
          {'role': 'system', 'content': sistema},
          {'role': 'user', 'content': usuario},
        ],
      },
    );
    if (r.statusCode != 200) throw errorHttp(r);

    final json = decodificar(r);
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const IaFallo('no devolvió respuesta.');
    }
    final contenido = (choices.first as Map)['message']?['content'];
    final salida = (contenido is String ? contenido : '').trim();
    if (salida.isEmpty) throw const IaFallo('devolvió una respuesta vacía.');
    return salida;
  }
}

// ───────────────────────── Claude ─────────────────────────

class _ClaudeProveedor extends IaProveedor {
  _ClaudeProveedor(super.config, super.cliente);

  @override
  Future<String> generar({
    required String sistema,
    required String usuario,
  }) async {
    final r = await postJson(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      {
        'x-api-key': config.apiKey.trim(),
        'anthropic-version': '2023-06-01',
        // Solo hace falta si la app corre en web; en móvil se ignora.
        'anthropic-dangerous-direct-browser-access': 'true',
      },
      {
        'model': config.modelo,
        'max_tokens': 2048,
        'system': sistema,
        'messages': [
          {'role': 'user', 'content': usuario},
        ],
      },
    );
    if (r.statusCode != 200) throw errorHttp(r);

    final json = decodificar(r);
    final partes = (json['content'] as List?)
            ?.whereType<Map>()
            .where((p) => p['type'] == 'text')
            .map((p) => (p['text'] ?? '').toString()) ??
        const <String>[];
    final salida = partes.join('\n').trim();
    if (salida.isEmpty) throw const IaFallo('devolvió una respuesta vacía.');
    return salida;
  }
}
