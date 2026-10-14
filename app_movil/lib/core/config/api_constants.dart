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

  // Modelos recomendados de Gemini para extracción JSON
  static const String geminiModelFlash = 'gemini-3.8-flash';

  // Tiempo de espera máximo para procesamiento de IA (en segundos)
  static const int aiTimeoutSeconds = 45;

  /// Crea un cliente configurado de Google AI con la API Key del .env
  /// El caller es responsable de cerrar el cliente cuando termine.
  static GoogleAIClient createAIClient() {
    final apiKey = googleApiKey;
    if (apiKey.isEmpty) {
      throw Exception(
        "API Key de Google Gemini no configurada en el archivo .env",
      );
    }
    return GoogleAIClient(
      config: GoogleAIConfig.googleAI(
        authProvider: ApiKeyProvider(apiKey),
        timeout: Duration(seconds: aiTimeoutSeconds),
      ),
    );
  }
}
