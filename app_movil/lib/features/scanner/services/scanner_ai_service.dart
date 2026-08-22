import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:app_movil/core/utils/app_logger.dart';
import 'package:app_movil/core/config/api_constants.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';

/// Servicio dedicado a la comunicación con Google Gemini AI
/// para el análisis inteligente de facturas de proveedores.
///
/// Responsabilidad única: Enviar imagen → Recibir JSON estructurado.
class ScannerAIService {
  /// Analiza una imagen de factura usando Gemini AI y retorna
  /// la respuesta estructurada con los items extraídos.
  ///
  /// Retorna `null` si hay error o la IA no devuelve datos.
  Future<AIInvoiceResponse?> analyzeInvoiceImage(File imageFile, {Function(String)? onRetrying}) async {
    int maxRetries = 1;
    int currentTry = 0;

    while (currentTry <= maxRetries) {
      try {
        final apiKey = ApiConstants.googleApiKey;
        if (apiKey.isEmpty) {
          throw Exception("API Key de Google Gemini no configurada en el archivo .env");
        }

        final model = GenerativeModel(
          model: ApiConstants.geminiModelFlash,
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.1,
          ),
        );

        final imageBytes = await imageFile.readAsBytes();
        final imagePart = DataPart('image/jpeg', imageBytes);

        final prompt = TextPart(_buildAnalysisPrompt());

        final response = await model.generateContent([
          Content.multi([prompt, imagePart])
        ]);

        if (response.text != null && response.text!.isNotEmpty) {
          String cleanJson = _sanitizeResponse(response.text!);
          final decoded = json.decode(cleanJson);
          return AIInvoiceResponse.fromJson(decoded);
        } else {
          throw Exception("La IA no devolvió datos legibles.");
        }
      } catch (e, stack) {
        if (e is ServerException) {
          final msg = e.message.toString().toLowerCase();
          bool isRateLimit = msg.contains('503') || 
                             msg.contains('429') || 
                             msg.contains('exhausted') || 
                             msg.contains('resource_exhausted') ||
                             msg.contains('unavailable');
          
          if (isRateLimit) {
            if (currentTry < maxRetries) {
              currentTry++;
              if (onRetrying != null) onRetrying("Reintentando conexión...");
              await Future.delayed(const Duration(seconds: 2));
              continue;
            } else {
              throw Exception("Los servidores de IA están muy concurridos en este momento. Por favor, intenta de nuevo en unos segundos.");
            }
          }
        }
        
        if (e is SocketException || e is TimeoutException) {
           throw Exception("Sin conexión a Internet. Verifica tu señal y reintenta.");
        }
        
        if (e.toString().contains("Los servidores de IA") || e.toString().contains("Sin conexión a Internet") || e.toString().contains("API Key")) {
           rethrow;
        }

        AppLogger.error('ScannerAIService.analyzeInvoiceImage', e, stack);
        throw Exception("Ocurrió un error inesperado al procesar la imagen. Intenta con otra foto o reintenta.");
      }
    }
    return null;
  }

  String _sanitizeResponse(String rawText) {
    // 1. Limpiar marcas de markdown
    return rawText.replaceAll('```json', '').replaceAll('```', '').trim();
  }

  /// Prompt de análisis de facturas para Gemini usando Few-Shot Prompting.
  String _buildAnalysisPrompt() {
    return '''
Actúa como un experto contable y analista de inventarios de papelería en Perú.
Tu misión es digitalizar esta factura física/electrónica con PRECISIÓN ABSOLUTA.

COMPLEJIDAD DEL NEGOCIO Y FLEXIBILIDAD:
Los proveedores venden productos en Lotes (Millares, Cientos, Docenas, Cajas).
A menudo, el cliente compra FRACCIONES de ese lote (Ej: "0.25 MLL" significa 1/4 de millar).
Debes deducir la matemática de la factura incluso si faltan datos implícitos.

REGLAS ESTRICTAS DE EXTRACCIÓN DE ÍTEMS:
1. 'ump_compra': La unidad de empaque del proveedor. (Ej: "DOC", "MLL", "CTO", "UND", "PAQ", "CJA"). Si no se especifica, usa "UND".
2. 'unidades_por_lote': Deduce cuántas unidades individuales vienen en ese 'ump_compra'. (MLL=1000, CTO=100, DOC=12, GRZ=144, UND=1. Si dice 'Caja x 50', es 50).
3. 'cantidad_ump_comprada': El número exacto en la columna "Cantidad". (Ej: si dice 0.25 MLL, pon 0.25. Si dice 3 DOC, pon 3.0).
4. 'total_pago_lote': El importe TOTAL pagado por esa línea específica (Subtotal o Importe de Venta).
5. 'precio_ump_proveedor': Si total_pago_lote y cantidad_ump_comprada están disponibles, calcula como (total_pago_lote / cantidad_ump_comprada).
6. 'unidad_venta': La unidad en la que el comerciante revende al público. Si compra Docenas (DOC) pero vende por Unidad, pon "Unidad".

REGLAS DE DESCRIPCIÓN (CHAIN OF THOUGHT):
1. Primero, identifica si hay una 'marca_detectada' (Faber Castell, Artesco, Stanford, Vinifan, etc).
2. Luego, extrae el 'producto_padre_estimado'. ¡LA MARCA NUNCA DEBE IR EN ESTE CAMPO!
3. Finalmente, extrae la 'variante_detectada' (Tamaño, color, diseño, modelo).

--- EJEMPLOS (FEW-SHOT PROMPTING) ---

EJEMPLO 1: "LAPIZ FC MONGOL HB X 12"
{
  "descripcion_detectada": "LAPIZ FC MONGOL HB X 12",
  "marca_detectada": "Faber Castell",
  "producto_padre_estimado": "Lápiz Mongol",
  "variante_detectada": "HB"
}

EJEMPLO 2: "CUADERNO STANFORD A4 CUADR. X 60HJ"
{
  "descripcion_detectada": "CUADERNO STANFORD A4 CUADR. X 60HJ",
  "marca_detectada": "Stanford",
  "producto_padre_estimado": "Cuaderno",
  "variante_detectada": "A4 Cuadriculado 60 hojas"
}

EJEMPLO 3: "SKETCH BOOK ARTESCO ESPIRAL"
{
  "descripcion_detectada": "SKETCH BOOK ARTESCO ESPIRAL",
  "marca_detectada": "Artesco",
  "producto_padre_estimado": "Sketch Book",
  "variante_detectada": "Espiral"
}

Extrae el monto total de toda la factura en 'monto_total_factura'.
Extrae los datos respetando estrictamente el esquema JSON solicitado:
{
  "proveedor_detectado": "string",
  "ruc_detectado": "string",
  "fecha_detectada": "YYYY-MM-DD",
  "monto_total_factura": float,
  "items": [
    {
      "descripcion_detectada": "string",
      "producto_padre_estimado": "string",
      "variante_detectada": "string",
      "marca_detectada": "string",
      "codigo_detectado": "string",
      "ump_compra": "string",
      "unidades_por_lote": int,
      "cantidad_ump_comprada": float,
      "precio_ump_proveedor": float,
      "total_pago_lote": float,
      "unidad_venta": "string"
    }
  ]
}
''';
  }
}
