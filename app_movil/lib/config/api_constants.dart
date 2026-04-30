import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get baseUrl {
    // 1. PRIORIDAD: Archivo .env (Ideal para pruebas en celular físico)
    final envUrl = dotenv.env['API_BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }

    // 2. RESPALDO: Detección automática de entorno
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api/v1'; // Navegador
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api/v1'; // Emulador Android (IP especial de puente)
    } 
    
    // Default para iOS o local
    return 'http://127.0.0.1:8000/api/v1';
  }

  // ========================================================================
  // 🔥 ENDPOINTS DE INTELIGENCIA ARTIFICIAL (Únicos que salen a la red)
  // ========================================================================
  
  // Endpoint para enviar la foto de la lista escolar y recibir los productos detectados
  static const String analyzeEndpoint = '/school-lists/analyze';
  
  // Endpoint para procesar fotos de facturas de proveedores
  static const String analyzeInvoiceEndpoint = '/invoices/analyze';

  // Tiempos de espera (Timeout) recomendados para la IA
  static const int connectionTimeout = 30; // 30 segundos para subida de fotos
}