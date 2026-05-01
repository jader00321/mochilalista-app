import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../config/api_constants.dart';
import '../models/extracted_list_model.dart';

class AIExtractionService {
  
  Future<SchoolListAnalysisResponse> analyzeImage(File imageFile, String _) async {
    final apiKey = ApiConstants.googleApiKey;
    if (apiKey.isEmpty) {
      throw Exception("Falta configurar GOOGLE_API_KEY en el archivo .env");
    }

    try {
      final model = GenerativeModel(
        model: ApiConstants.geminiModelFlash,
        apiKey: apiKey,
      );

      final imageBytes = await imageFile.readAsBytes();
      final imagePart = DataPart('image/jpeg', imageBytes); 

      final prompt = TextPart('''
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
      ''');

      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      if (response.text != null && response.text!.isNotEmpty) {
        String cleanJson = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
        final Map<String, dynamic> jsonMap = json.decode(cleanJson);
        return SchoolListAnalysisResponse.fromJson(jsonMap);
      } else {
        throw Exception("La IA no devolvió datos legibles.");
      }
    } catch (e) {
      debugPrint("Error IA Extracción: $e");
      throw Exception("Error de procesamiento con la Inteligencia Artificial. Reintenta.");
    }
  }
}