import 'dart:io';
import 'dart:convert';
import 'dart:async' hide TimeoutException;
import 'package:googleai_dart/googleai_dart.dart' hide File;
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
  Future<AIInvoiceResponse?> analyzeInvoiceImage(
    File imageFile, {
    Function(String)? onRetrying,
  }) async {
    int maxRetries = 1;
    int currentTry = 0;

    while (currentTry <= maxRetries) {
      GoogleAIClient? client;
      try {
        client = ApiConstants.createAIClient();

        final imageBytes = await imageFile.readAsBytes();

        final response = await client.models.generateContent(
          model: ApiConstants.geminiModelFlash,
          request: GenerateContentRequest(
            contents: [
              Content.user([
                Part.text(_buildAnalysisPrompt()),
                Part.bytes(imageBytes, 'image/jpeg'),
              ]),
            ],
            generationConfig: const GenerationConfig(
              responseMimeType: 'application/json',
              temperature: 0.1,
            ),
          ),
        );

        if (response.text != null && response.text!.isNotEmpty) {
          String cleanJson = _sanitizeResponse(response.text!);
          final decoded = json.decode(cleanJson);
          return AIInvoiceResponse.fromJson(decoded);
        } else {
          throw Exception("La IA no devolvió datos legibles.");
        }
      } on RateLimitException {
        if (currentTry < maxRetries) {
          currentTry++;
          if (onRetrying != null) onRetrying("Reintentando conexión...");
          await Future.delayed(const Duration(seconds: 2));
          continue;
        } else {
          throw Exception(
            "Los servidores están concurridos en este momento. "
            "Intenta de nuevo en unos segundos.",
          );
        }
      } on AuthenticationException catch (e, stack) {
        AppLogger.error('ScannerAI: Auth error', e, stack);
        throw Exception(
          "Hubo un problema con el servicio de procesamiento. "
          "Si persiste, contacta al soporte. (Ref: S.401)",
        );
      } on TimeoutException catch (e, stack) {
        AppLogger.error('ScannerAI: Timeout', e, stack);
        throw Exception(
          "El procesamiento tardó demasiado. "
          "Verifica tu conexión e intenta de nuevo.",
        );
      } on ApiException catch (e, stack) {
        AppLogger.error(
          'ScannerAI: [${e.statusCode}] ${e.message}', e, stack,
        );

        // Servidor temporal — reintentar
        if (e.statusCode == 503) {
          if (currentTry < maxRetries) {
            currentTry++;
            if (onRetrying != null) onRetrying("Reintentando conexión...");
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
        }

        // Créditos de prepago agotados
        if (e.statusCode == 402) {
          throw Exception(
            "El servicio de procesamiento está temporalmente fuera de servicio. "
            "Contacta al soporte para restablecerlo. (Ref: S.402)",
          );
        }

        // Modelo no encontrado
        if (e.statusCode == 404) {
          throw Exception(
            "El servicio necesita una actualización. "
            "Contacta al soporte para resolverlo. (Ref: S.404)",
          );
        }

        // Cualquier otro error de API
        throw Exception(
          "No pudimos procesar esta imagen en este momento. "
          "Intenta con otra foto o reintenta en unos segundos. (Ref: S.${e.statusCode})",
        );
      } on SocketException {
        throw Exception(
          "Sin conexión a Internet. Verifica tu señal y reintenta.",
        );
      } catch (e, stack) {
        if (e.toString().contains("Ref:") ||
            e.toString().contains("servidores") ||
            e.toString().contains("conexión a Internet")) {
          rethrow;
        }

        AppLogger.error('ScannerAI: Unexpected', e, stack);
        throw Exception(
          "No pudimos procesar esta imagen en este momento. "
          "Intenta con otra foto o reintenta en unos segundos. (Ref: S.500)",
        );
      } finally {
        client?.close();
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
