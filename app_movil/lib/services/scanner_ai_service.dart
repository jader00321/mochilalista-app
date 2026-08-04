import 'dart:io';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../utils/app_logger.dart';
import '../config/api_constants.dart';
import '../models/scanner_models.dart';

/// Servicio dedicado a la comunicación con Google Gemini AI
/// para el análisis inteligente de facturas de proveedores.
///
/// Responsabilidad única: Enviar imagen → Recibir JSON estructurado.
class ScannerAIService {
  /// Analiza una imagen de factura usando Gemini AI y retorna
  /// la respuesta estructurada con los items extraídos.
  ///
  /// Retorna `null` si hay error o la IA no devuelve datos.
  Future<AIInvoiceResponse?> analyzeInvoiceImage(File imageFile) async {
    try {
      final apiKey = ApiConstants.googleApiKey;
      if (apiKey.isEmpty) {
        throw Exception("API Key de Google Gemini no configurada en el archivo .env");
      }

      final model = GenerativeModel(
        model: ApiConstants.geminiModelFlash,
        apiKey: apiKey,
      );

      final imageBytes = await imageFile.readAsBytes();
      final imagePart = DataPart('image/jpeg', imageBytes);

      final prompt = TextPart(_buildAnalysisPrompt());

      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      if (response.text != null && response.text!.isNotEmpty) {
        String cleanJson = response.text!
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final decoded = json.decode(cleanJson);
        return AIInvoiceResponse.fromJson(decoded);
      } else {
        throw Exception("La IA no devolvió datos legibles.");
      }
    } catch (e, stack) {
      AppLogger.error('ScannerAIService.analyzeInvoiceImage', e, stack);
      rethrow;
    }
  }

  /// Prompt de análisis de facturas para Gemini.
  /// Extraído del ScannerProvider original para mantener coherencia.
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
        5. 'precio_ump_proveedor': El precio unitario del lote. Si no está claro en la foto, INFIÉRELO DIVIDIENDO: (total_pago_lote / cantidad_ump_comprada).

        REGLAS DE DESCRIPCIÓN:
        - 'producto_padre_estimado': El nombre general limpio (Ej: "Cuaderno Stanford", "Lápiz Chequeador").
        - 'variante_detectada': Características específicas, colores, tamaños (Ej: "A4 Cuadriculado", "Color Rojo").
        - 'marca_detectada': Solo si se menciona explícitamente (Faber Castell, Artesco, etc).

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
