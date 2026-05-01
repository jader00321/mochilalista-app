import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  /// Obtiene la llave de Google Gemini de forma segura desde el archivo .env
  static String get googleApiKey {
    final key = dotenv.env['GOOGLE_API_KEY'];
    if (key == null || key.isEmpty) {
      debugPrint("⚠️ ADVERTENCIA CRÍTICA: No se encontró GOOGLE_API_KEY en el archivo .env");
      return '';
    }
    return key;
  }

  // Modelos recomendados de Gemini para extracción JSON
  static const String geminiModelFlash = 'gemini-2.5-flash'; 
  
  // Tiempo de espera máximo para procesamiento de IA (en segundos)
  static const int aiTimeoutSeconds = 45;
}