import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleai_dart/googleai_dart.dart' hide File;

class ApiConstants {
  /// Obtiene la llave de Google Gemini de forma segura desde el archivo .env
  static String get googleApiKey {
    final key = dotenv.env['GOOGLE_API_KEY'];
    if (key == null || key.isEmpty) {
      debugPrint(
        "⚠️ ADVERTENCIA CRÍTICA: No se encontró GOOGLE_API_KEY en el archivo .env.",
      );
      return '';
    }
    return key;
  }

  // Modelos oficiales de Gemini (Familia Flash 2026 en Free Tier)
  /// Agente Primario: Mayor inteligencia y capacidad de razonamiento para comprobantes y tablas.
  static const String geminiPrimaryModel = 'gemini-3.8-flash';

  /// Agente Secundario (Respaldo Inmediato): Ultra baja latencia y alta concurrencia.
  static const String geminiFallbackModelFast = 'gemini-3.1-flash-lite';

  /// Agente Terciario (Respaldo de Estabilidad): Generación previa balanceada.
  static const String geminiFallbackModelStable = 'gemini-3.6-flash';

  /// Compatibilidad con referencias previas
  static const String geminiModelFlash = geminiPrimaryModel;

  /// Lista ordenada de agentes en cascada para tolerancia a fallos
  static const List<String> cascadeModels = [
    geminiPrimaryModel,
    geminiFallbackModelFast,
    geminiFallbackModelStable,
  ];

  // Tiempo de espera generoso (95 segundos) para permitir razonamiento multimodal profundo
  static const int aiTimeoutSeconds = 95;

  /// Crea un cliente configurado de Google AI con la API Key del .env
  /// El caller es responsable de cerrar el cliente cuando termine.
  static GoogleAIClient createAIClient({Duration? timeout}) {
    final apiKey = googleApiKey;
    if (apiKey.isEmpty) {
      throw Exception(
        "API Key de Google Gemini no configurada en el archivo .env",
      );
    }
    return GoogleAIClient(
      config: GoogleAIConfig.googleAI(
        authProvider: ApiKeyProvider(apiKey),
        timeout: timeout ?? const Duration(seconds: aiTimeoutSeconds),
      ),
    );
  }
}
