import 'ia_proveedores.dart';

/// Claves de la IA. Es la ÚNICA parte que debes editar.
///
/// La app prueba los proveedores en el ORDEN de la lista [proveedores]:
/// si el primero falla (límite gratuito, saturado, sin internet, clave
/// inválida...), pasa automáticamente al segundo, luego al tercero, etc.
///
/// - Para agregar uno: descomenta su línea y pega tu clave.
/// - Para quitar uno: borra la línea o deja la clave vacía ('').
/// - Para cambiar prioridad: cambia el orden de las líneas.
/// - Para cambiar el modelo: agrega  modelo: 'nombre-del-modelo'.
///
/// Si usas Git, agrega este archivo al .gitignore para no subir tus claves.
class IaSecrets {
  /// Clave de Gemini (se conserva por compatibilidad).
  static const geminiApiKey =
      'AQ.Ab8RN6JsAtxN3piprF67qLh4fFwQ1xvPQD-lzztuo4kwYPdohA';

  static const List<IaProveedorConfig> proveedores = [
    // Varias claves de Gemini en orden de prioridad — https://aistudio.google.com/apikey
    // Si la 1ª alcanza su límite o falla, se usa la 2ª, luego la 3ª, etc.
    // TIP: el límite gratuito es por proyecto de Google, así que crea cada
    // clave en un proyecto distinto ("Create API key in new project").
    IaProveedorConfig.gemini(geminiApiKey, nombre: 'Gemini 1'),
    // IaProveedorConfig.gemini('PEGA_AQUI_CLAVE_2', nombre: 'Gemini 2'),
    // IaProveedorConfig.gemini('PEGA_AQUI_CLAVE_3', nombre: 'Gemini 3'),

    // También puedes variar el modelo con la misma clave:
    // IaProveedorConfig.gemini(geminiApiKey, modelo: 'gemini-2.5-flash-lite', nombre: 'Gemini lite'),

    // 2º: Groq (gratis, muy rápido) — https://console.groq.com/keys
    // IaProveedorConfig.groq('PEGA_AQUI_TU_CLAVE_DE_GROQ'),

    // 3º: OpenRouter (modelos gratis) — https://openrouter.ai/keys
    // IaProveedorConfig.openRouter('PEGA_AQUI_TU_CLAVE_DE_OPENROUTER'),

    // 4º: OpenAI — https://platform.openai.com/api-keys
    // IaProveedorConfig.openAi('PEGA_AQUI_TU_CLAVE_DE_OPENAI'),

    // 5º: Claude — https://console.anthropic.com/settings/keys
    // IaProveedorConfig.claude('PEGA_AQUI_TU_CLAVE_DE_CLAUDE'),

    // Otros disponibles: .deepSeek(...)  .mistral(...)
    // Cualquier servicio compatible con OpenAI:
    // IaProveedorConfig.compatible(
    //   nombre: 'Together',
    //   apiKey: 'TU_CLAVE',
    //   modelo: 'meta-llama/Llama-3.3-70B-Instruct-Turbo',
    //   baseUrl: 'https://api.together.xyz/v1',
    // ),
  ];
}
