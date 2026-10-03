import 'dart:convert';
import 'dart:io';
import 'dart:async' hide TimeoutException;
import 'package:flutter/material.dart';
import 'package:googleai_dart/googleai_dart.dart' hide File;
import 'package:app_movil/core/config/api_constants.dart';
import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';

class AIExtractionService {
  
  Future<SchoolListAnalysisResponse> analyzeImage(File imageFile, String _, {Function(String)? onRetrying}) async {
    int maxRetries = 1;
    int currentTry = 0;

    while (currentTry <= maxRetries) {
      GoogleAIClient? client;
      try {
        client = ApiConstants.createAIClient();

        final imageBytes = await imageFile.readAsBytes();

        final prompt = '''
          Actúa como un experto en digitalización de listas de útiles escolares.
          Analiza la imagen proporcionada y extrae la información siguiendo ESTRICTAMENTE el esquema JSON solicitado.

          INSTRUCCIONES DE EXTRACCIÓN DETALLADA:
          
          1. METADATA (Encabezado):
             - Busca nombre del colegio, nombre del alumno y grado/sección.
             
          2. ÍTEMS (Lista de Productos):
             Recorre línea por línea y para cada producto extrae:
             
             - "id": Genera un número secuencial (1, 2, 3...).
             - "original_text": Transcribe el texto exacto que ves en la línea para referencia.
             - "full_name": El nombre completo y DESCRIPTIVO del producto. 
               * Corrige ortografía (ej: "Cdorno" -> "Cuaderno").
               * Si la marca está integrada (ej: "Colores Faber"), extráela al campo brand y deja aquí solo "Colores".
             - "brand": Si se especifica una marca explícita (ej: Faber-Castell, Artesco), ponla aquí. Si no, null.
             - "quantity": Extrae el número como entero. Si no hay, asume 1.
             - "unit": Expande abreviaturas ("c/u" -> "unidad", "pqte" -> "paquete", "mill" -> "millar").
             - "notes": Detalles visuales, colores o instrucciones adicionales.

          REGLAS CRÍTICAS DE CALIDAD:
          - NO inventes productos que no estén visibles.
          - Si una línea está tachada, IGNÓRALA.
          
          Debes responder EXCLUSIVAMENTE con el siguiente formato JSON puro, sin marcadores markdown:
          {
            "metadata": {
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

        final response = await client.models.generateContent(
          model: ApiConstants.geminiModelFlash,
          request: GenerateContentRequest(
            contents: [
              Content.user([
                Part.text(prompt),
                Part.bytes(imageBytes, 'image/jpeg'),
              ]),
            ],
          ),
        );

        if (response.text != null && response.text!.isNotEmpty) {
          String cleanJson = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
          final Map<String, dynamic> jsonMap = json.decode(cleanJson);
          return SchoolListAnalysisResponse.fromJson(jsonMap);
        } else {
          throw Exception("La IA no devolvió datos legibles.");
        }
      } on RateLimitException {
        // Rate limit (429) — reintentar si hay intentos restantes
        if (currentTry < maxRetries) {
          currentTry++;
          if (onRetrying != null) onRetrying("Reintentando conexión...");
          await Future.delayed(const Duration(seconds: 2));
          continue;
        } else {
          throw Exception(
            "Los servidores de IA están muy concurridos en este momento. "
            "Por favor, intenta de nuevo en unos segundos.",
          );
        }
      } on AuthenticationException catch (e, stack) {
        // API key inválida o sin permisos
        debugPrint("Error IA Extracción [AUTH]: $e\n$stack");
        throw Exception(
          "Hubo un problema con el servicio de procesamiento. "
          "Si el problema persiste, contacta al soporte. (Ref: AUTH-Q01)",
        );
      } on TimeoutException catch (e, stack) {
        // Timeout del SDK
        debugPrint("Error IA Extracción [TIMEOUT]: $e\n$stack");
        throw Exception(
          "El procesamiento tardó demasiado. Verifica tu conexión e intenta de nuevo.",
        );
      } on ApiException catch (e, stack) {
        // Errores generales del API (404, 500, etc.)
        final msg = e.message.toLowerCase();

        // Reintentar si es error de servidor temporal (503, unavailable)
        if (msg.contains('503') || msg.contains('unavailable')) {
          if (currentTry < maxRetries) {
            currentTry++;
            if (onRetrying != null) onRetrying("Reintentando conexión...");
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
        }

        // Modelo no encontrado
        if (msg.contains('404') || msg.contains('not found')) {
          debugPrint("Error IA Extracción [MODEL]: $e\n$stack");
          throw Exception(
            "El servicio de procesamiento necesita una actualización. "
            "Contacta al soporte para resolverlo rápidamente. (Ref: MDL-Q02)",
          );
        }

        debugPrint("Error IA Extracción [API]: $e\n$stack");
        throw Exception(
          "No pudimos procesar esta imagen en este momento. "
          "Intenta con otra foto o reintenta en unos segundos. (Ref: API-Q04)",
        );
      } on SocketException {
        throw Exception("Sin conexión a Internet. Verifica tu señal y reintenta.");
      } catch (e, stack) {
        // Reenviar excepciones que ya tienen mensaje formateado
        if (e.toString().contains("Los servidores de IA") || 
            e.toString().contains("Sin conexión a Internet") || 
            e.toString().contains("API Key") ||
            e.toString().contains("Ref:")) {
           rethrow;
        }

        debugPrint("Error IA Extracción: $e\n$stack");
        throw Exception(
          "No pudimos procesar esta imagen en este momento. "
          "Intenta con otra foto o reintenta en unos segundos. (Ref: GEN-Q03)",
        );
      } finally {
        client?.close();
      }
    }
    throw Exception("No pudimos procesar esta imagen en este momento. (Ref: GEN-Q04)");
  }
}