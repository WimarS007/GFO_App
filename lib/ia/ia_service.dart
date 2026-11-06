import 'package:http/http.dart' as http;

import 'ia_proveedores.dart';
import 'ia_secrets.dart';

export 'ia_proveedores.dart' show IaProveedorConfig, IaTipo;

/// Configuración de la IA: lista de proveedores en orden de prioridad,
/// tomada de [IaSecrets.proveedores].
///
/// Si esa lista no tiene ninguna clave, se intenta con
/// --dart-define=GEMINI_API_KEY=tu_clave (solo Gemini).
class IaConfig {
  const IaConfig();

  List<IaProveedorConfig> get proveedores {
    final lista = IaSecrets.proveedores.where((p) => p.activo).toList();
    if (lista.isNotEmpty) return lista;

    const deEntorno = String.fromEnvironment('GEMINI_API_KEY');
    if (deEntorno.trim().isNotEmpty) {
      return [const IaProveedorConfig.gemini(deEntorno)];
    }
    return const [];
  }

  bool get configurada => proveedores.isNotEmpty;
}

class IaException implements Exception {
  const IaException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Pide texto a la IA probando varios proveedores en orden: si uno falla,
/// continúa con el siguiente hasta que alguno responda.
class IaService {
  IaService(this.config, {http.Client? cliente})
      : _http = cliente ?? http.Client() {
    _proveedores = [
      for (final c in config.proveedores) IaProveedor.crear(c, _http),
    ];
  }

  final IaConfig config;
  final http.Client _http;
  late final List<IaProveedor> _proveedores;

  /// Nombre del proveedor que respondió la última vez (p. ej. "Groq").
  String? ultimoProveedor;

  // Estado compartido por toda la app (varias pantallas crean su IaService).
  static final Map<String, DateTime> _enEspera = {};
  static final Set<String> _descartados = {};
  static const _espera = Duration(minutes: 2);

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

  /// Orden en que se probarán los proveedores: primero los que no han
  /// fallado hace poco; los que fallaron recientemente quedan al final
  /// (así no se pierde tiempo en uno caído, pero tampoco se descarta).
  List<IaProveedor> _ordenDeIntento() {
    final ahora = DateTime.now();
    final buenos = <IaProveedor>[];
    final enEspera = <IaProveedor>[];
    for (final p in _proveedores) {
      if (_descartados.contains(p.config.id)) continue;
      final hasta = _enEspera[p.config.id];
      if (hasta != null && hasta.isAfter(ahora)) {
        enEspera.add(p);
      } else {
        buenos.add(p);
      }
    }
    final orden = [...buenos, ...enEspera];
    // Si todos fueron descartados por clave inválida, se intenta igual
    // (el usuario pudo haber corregido la clave).
    return orden.isNotEmpty ? orden : List.of(_proveedores);
  }

  /// Pide a la IA que interprete las cifras de [resumen].
  /// [enfoque] indica qué parte se analiza (p. ej. "Razones financieras").
  Future<String> interpretar({
    required String enfoque,
    required String resumen,
  }) async {
    if (_proveedores.isEmpty) {
      throw const IaException(
          'La IA no está disponible: agrega al menos una clave en ia/ia_secrets.dart.');
    }

    final usuario = 'Interpreta este análisis: $enfoque.\n\nDatos:\n$resumen';
    final fallos = <String>[];

    for (final p in _ordenDeIntento()) {
      try {
        final texto = await p.generar(sistema: _sistema, usuario: usuario);
        _enEspera.remove(p.config.id);
        _descartados.remove(p.config.id);
        ultimoProveedor = p.nombre;
        return texto;
      } on IaFallo catch (e) {
        if (e.definitivo) {
          _descartados.add(p.config.id);
        } else {
          _enEspera[p.config.id] = DateTime.now().add(_espera);
        }
        fallos.add('${p.nombre}: ${e.mensaje}');
      } catch (_) {
        _enEspera[p.config.id] = DateTime.now().add(_espera);
        fallos.add('${p.nombre}: error inesperado.');
      }
    }

    if (fallos.length == 1) {
      throw IaException('La IA falló. ${fallos.first}');
    }
    throw IaException(
      'Ninguna IA pudo responder:\n${fallos.map((f) => '• $f').join('\n')}',
    );
  }

  void cerrar() => _http.close();
}
