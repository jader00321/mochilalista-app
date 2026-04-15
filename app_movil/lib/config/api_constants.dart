import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get baseUrl {
    // 1. PRIORIDAD MÁXIMA: El archivo .env
    // (Aquí es donde pondrás la IP de tu computadora para que tu celular se conecte)
    final envUrl = dotenv.env['API_BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }

    // 2. RESPALDO INTELIGENTE: Si el .env está vacío o no existe, 
    // detectamos en qué dispositivo se está ejecutando la app para no fallar.
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api/v1'; // Navegador Web
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api/v1'; // Emulador de Android
    } else if (Platform.isIOS) {
      return 'http://127.0.0.1:8000/api/v1'; // Simulador de iOS
    }
    
    // Default genérico
    return 'http://127.0.0.1:8000/api/v1';
  }

  // Endpoints principales
  static const String productsEndpoint = '/products';
  static const String analyzeEndpoint = '/school-lists/analyze';
  static const String smartQuotations = '/smart-quotations';
}