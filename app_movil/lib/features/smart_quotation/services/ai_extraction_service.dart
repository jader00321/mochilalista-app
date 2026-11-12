import 'dart:convert';
import 'dart:io';
import 'dart:async' hide TimeoutException;
import 'package:flutter/material.dart';
import 'package:googleai_dart/googleai_dart.dart' hide File;
import 'package:app_movil/core/config/api_constants.dart';
import 'package:app_movil/core/services/image_optimizer_service.dart';
import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';

class AIExtractionService {
  /// Analiza una imagen de lista de útiles escolares usando la cascada de Agentes Gemini AI
  /// y retorna la respuesta estructurada con los útiles extraídos.
  Future<SchoolListAnalysisResponse> analyzeImage(
    File imageFile,
    String _, {
    Function(String)? onRetrying,
  }) async {
    // 1. Pre-procesamiento de Alta Fidelidad (2048px, 88% calidad, sin borrosidad)
    if (onRetrying != null) {
      onRetrying("Optimizando nitidez y legibilidad de la lista o pedido...");
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

        final prompt = _buildListExtractionPrompt();

        final response = await client.models.generateContent(
          model: currentModel,
          request: GenerateContentRequest(
            contents: [
              Content.user([
                Part.text(prompt),
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
          final Map<String, dynamic> jsonMap = json.decode(cleanJson);
          return SchoolListAnalysisResponse.fromJson(jsonMap);
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
        debugPrint("ExtractionAI: Auth error - $e\n$stack");
        throw Exception(
          "Problema de autenticación con la IA. Verifica tu API Key en .env. (Ref: Q.401)",
        );
      } on TimeoutException catch (e, stack) {
        debugPrint("ExtractionAI: Timeout en $currentModel - $e\n$stack");
        if (!isLastModel) {
          if (onRetrying != null) {
            onRetrying("Tiempo de espera agotado. Conmutando al agente rápido de respaldo...");
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
        debugPrint("ExtractionAI: [${e.statusCode}] en $currentModel - ${e.message}\n$stack");

        // Servidor temporal ocupado (503) o límite de concurrencia (429) — conmutar en cascada
        if ((e.statusCode == 503 || e.statusCode == 429) && !isLastModel) {
          if (onRetrying != null) {
            onRetrying("Servidor temporalmente ocupado. Conmutando a agente en alta velocidad...");
          }
          await Future.delayed(const Duration(milliseconds: 3500));
          continue;
        }

        if (e.statusCode == 404 && !isLastModel) {
          continue;
        }

        if (e.statusCode == 402) {
          throw Exception(
            "El servicio de procesamiento requiere actualización de cuota. "
            "Contacta a soporte. (Ref: Q.402)",
          );
        }

        throw Exception(
          "No pudimos procesar esta lista en este momento. "
          "Intenta de nuevo en unos segundos. (Ref: Q.${e.statusCode})",
        );
      } on SocketException {
        throw Exception("Sin conexión a Internet. Verifica tu señal y reintenta.");
      } catch (e, stack) {
        if (e.toString().contains("Ref:") ||
            e.toString().contains("alta demanda") ||
            e.toString().contains("conexión a Internet")) {
          rethrow;
        }

        debugPrint("ExtractionAI: Inesperado en $currentModel - $e\n$stack");
        if (!isLastModel) {
          await Future.delayed(const Duration(milliseconds: 2000));
          continue;
        }

        throw Exception(
          "No pudimos procesar esta lista en este momento. "
          "Intenta con otra foto o reintenta en unos segundos. (Ref: Q.500)",
        );
      } finally {
        client?.close();
      }
    }

    throw Exception("No pudimos procesar esta lista de útiles en este momento. (Ref: Q.000)");
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

  String _buildListExtractionPrompt() {
    return '''
Actúa como un experto en digitalización y extracción de datos comerciales para cualquier tipo de pedido o lista:
1. Listas de compras cotidianas o variadas (abarrotes, bebidas, limpieza, ferretería, bazar, farmacia).
2. Pedidos al por mayor para bodegas, negocios o empresas B2B (cajas, paquetes, packs, docenas, fardos, millares).
3. Listas de útiles escolares y papelería (cuadernos, lápices, materiales de estudio).

Analiza la imagen proporcionada y extrae la información siguiendo ESTRICTAMENTE el esquema JSON solicitado.

INSTRUCCIONES DE ANÁLISIS Y EXTRACCIÓN:

1. AUTODETECCIÓN DEL MODO DE COTIZACIÓN ("detected_mode"):
   - "wholesale": Si el documento contiene compras al por mayor, pedidos para negocios, bodegas, empresas, RUC, o cantidades por bulto/caja/fardo/docena.
   - "school": Si el documento es explícitamente una lista de útiles escolares (colegio, alumno, grado/sección, cuadernos escolares).
   - "general": Para listas de compras familiares, compras variadas, abarrotes, cotizaciones de ferretería o listas cotidianas.

2. METADATA (Encabezado):
   - "detected_mode": "general" | "wholesale" | "school".
   - "contact_name": Nombre de la persona, cliente, contacto o estudiante.
   - "organization_name": Nombre de la empresa, negocio, bodega o institución educativa/colegio.
   - "phone": Número de teléfono o WhatsApp si figura en el documento.
   - "reference_info": Grado escolar, referencia de compra (ej: "Pedido mensual", "Canasta familiar") o notas generales.

3. ÍTEMS (Lista de Productos - Cualquier Rubro Comercial):
   Para cada producto extrae con máxima fidelidad:
   - "id": Número secuencial entero (1, 2, 3...).
   - "original_text": Texto exacto visible en la línea original para referencia del comerciante.
   - "full_name": Nombre descriptivo y limpio del producto (ej: "Leche evaporada", "Cuaderno rayado", "Agua sin gas 500ml", "Cemento").
     * Corrige abreviaturas habituales (ej: "Cdorno" -> "Cuaderno", "Lap" -> "Lápiz", "Gas" -> "Gaseosa").
     * Si la marca está integrada, extráela al campo "brand" y deja en "full_name" el nombre del producto.
   - "brand": Marca explícita si se especifica (ej: Gloria, Standford, San Carlos, Truper, Faber-Castell). Si no, null.
   - "quantity": Número entero o decimal. Si no hay número explícito, asume 1.
   - "unit": Presentación normalizada ("unidad", "caja", "paquete", "pack", "docena", "fardo", "bolsa", "kilo", "litro", "lata", "botella").
   - "notes": Colores, dimensiones, variantes o detalles adicionales visibles.

REGLAS CRÍTICAS DE CALIDAD:
- NO inventes productos que no estén visibles en la imagen.
- Si una línea está tachada con un trazo evidente, IGNÓRALA.
- Extrae con precisión tanto presentaciones al por mayor como al menudeo.

Debes responder EXCLUSIVAMENTE con el siguiente formato JSON puro:
{
  "metadata": {
    "detected_mode": "general",
    "contact_name": "string",
    "organization_name": "string",
    "phone": "string",
    "reference_info": "string",
    "institution_name": "string",
    "student_name": "string",
    "grade_level": "string"
  },
  "items": [
    {
      "id": 1,
      "original_text": "string",
      "full_name": "string",
      "brand": "string",
      "quantity": 1,
      "unit": "string",
      "notes": "string"
    }
  ]
}
''';
  }
}