import 'dart:io';
import 'dart:convert';
import 'dart:async' hide TimeoutException;
import 'package:googleai_dart/googleai_dart.dart' hide File;
import 'package:app_movil/core/utils/app_logger.dart';
import 'package:app_movil/core/config/api_constants.dart';
import 'package:app_movil/core/services/image_optimizer_service.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';

/// Servicio dedicado a la comunicación con Google Gemini AI
/// para el análisis inteligente de facturas de proveedores.
///
/// Responsabilidad única: Enviar imagen → Recibir JSON estructurado.
class ScannerAIService {
  /// Analiza una imagen de factura usando la cascada de Agentes Gemini AI y retorna
  /// la respuesta estructurada con los items extraídos.
  ///
  /// Retorna `null` si hay error o la IA no devuelve datos.
  Future<AIInvoiceResponse?> analyzeInvoiceImage(
    File imageFile, {
    Function(String)? onRetrying,
  }) async {
    // 1. Pre-procesamiento de Alta Fidelidad (2048px, 88% calidad, sin borrosidad)
    if (onRetrying != null) {
      onRetrying("Optimizando nitidez y resolución del comprobante...");
    }
    final imageBytes = await ImageOptimizerService.getOptimizedBytes(imageFile);

    final modelsToTry = ApiConstants.cascadeModels;

    for (int i = 0; i < modelsToTry.length; i++) {
      final currentModel = modelsToTry[i];
      final isLastModel = i == modelsToTry.length - 1;
      final modelLabel = currentModel == ApiConstants.geminiPrimaryModel
          ? "Agente Principal (Gemini 3.8 Flash)"
          : (currentModel == ApiConstants.geminiFallbackModelFast
              ? "Agente Rápido (Gemini 3.1 Flash-Lite)"
              : "Agente de Estabilidad (Gemini 3.6 Flash)");

      GoogleAIClient? client;
      try {
        if (i > 0 && onRetrying != null) {
          onRetrying("Conectando con $modelLabel...");
        }

        client = ApiConstants.createAIClient();

        final response = await client.models.generateContent(
          model: currentModel,
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
        if (!isLastModel) {
          if (onRetrying != null) {
            onRetrying("Límite temporal alcanzado. Conmutando al agente de respaldo...");
          }
          await Future.delayed(const Duration(milliseconds: 3500));
          continue;
        } else {
          throw Exception(
            "Los servidores de IA están con alta demanda en este momento. "
            "Por favor, reintenta en unos segundos.",
          );
        }
      } on AuthenticationException catch (e, stack) {
        AppLogger.error('ScannerAI: Auth error', e, stack);
        throw Exception(
          "Problema de autenticación con la IA. Verifica tu API Key en .env. (Ref: S.401)",
        );
      } on TimeoutException catch (e, stack) {
        AppLogger.error('ScannerAI: Timeout en $currentModel', e, stack);
        if (!isLastModel) {
          if (onRetrying != null) {
            onRetrying("Tiempo excedido. Conmutando al agente rápido de respaldo...");
          }
          await Future.delayed(const Duration(milliseconds: 2000));
          continue;
        } else {
          throw Exception(
            "El análisis tomó más tiempo del esperado. "
            "Verifica tu conexión a Internet e intenta de nuevo.",
          );
        }
      } on ApiException catch (e, stack) {
        AppLogger.error(
          'ScannerAI: [${e.statusCode}] en $currentModel - ${e.message}', e, stack,
        );

        // Servidor temporal 503 o 429 — conmutar a siguiente agente en cascada
        if ((e.statusCode == 503 || e.statusCode == 429) && !isLastModel) {
          if (onRetrying != null) {
            onRetrying("Servidor ocupado. Conmutando al agente de respaldo en alta velocidad...");
          }
          await Future.delayed(const Duration(milliseconds: 3500));
          continue;
        }

        if (e.statusCode == 404 && !isLastModel) {
          continue; // Pasa al siguiente modelo si el actual no estuviese disponible
        }

        throw Exception(
          "No pudimos procesar esta imagen en este momento. "
          "Intenta de nuevo en unos segundos. (Ref: S.${e.statusCode})",
        );
      } on SocketException {
        throw Exception(
          "Sin conexión a Internet. Verifica tu señal y reintenta.",
        );
      } catch (e, stack) {
        if (e.toString().contains("Ref:") ||
            e.toString().contains("alta demanda") ||
            e.toString().contains("conexión a Internet")) {
          rethrow;
        }

        AppLogger.error('ScannerAI: Unexpected', e, stack);
        if (!isLastModel) {
          await Future.delayed(const Duration(milliseconds: 2000));
          continue;
        }

        throw Exception(
          "No pudimos procesar esta imagen en este momento. "
          "Intenta de nuevo en unos segundos. (Ref: S.500)",
        );
      } finally {
        client?.close();
      }
    }
    return null;
  }

  String _sanitizeResponse(String rawText) {
    String clean = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
    final firstBrace = clean.indexOf('{');
    final lastBrace = clean.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      clean = clean.substring(firstBrace, lastBrace + 1);
    }
    // Remueve comas sobrantes antes de llaves o corchetes de cierre
    clean = clean.replaceAllMapped(RegExp(r',\s*([}\]])'), (m) => m.group(1)!);
    return clean;
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
