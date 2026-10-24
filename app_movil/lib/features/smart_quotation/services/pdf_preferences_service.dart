import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/features/smart_quotation/models/pdf_config_model.dart';

/// 💾 SERVICIO DE PERSISTENCIA DE PREFERENCIAS DE DOCUMENTO PDF
/// Guarda y restaura las preferencias visuales del usuario (tema, columnas,
/// inclusión de logo/imágenes, cuentas de pago, etc.) preservando estrictamente
/// el [documentTitle] contextual de la operación en curso.
class PdfPreferencesService {
  static const String _prefKey = 'mochila_pdf_user_default_config_v2';

  /// Guarda la configuración actual como predeterminada del usuario
  static Future<bool> saveDefaultConfig(PdfConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> data = config.toJson();
      // Omitimos customClientName para no contaminar nuevos documentos con nombres de clientes pasados
      data.remove('customClientName');
      await prefs.setString(_prefKey, jsonEncode(data));
      return true;
    } catch (e) {
      debugPrint("⚠️ Error guardando preferencias de PDF: $e");
      return false;
    }
  }

  /// Aplica las preferencias guardadas a la configuración en curso,
  /// respetando obligatoriamente el [documentTitle] contextual inicial.
  static Future<PdfConfig> applySavedPreferences(PdfConfig initialConfig) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? rawJson = prefs.getString(_prefKey);
      if (rawJson == null || rawJson.isEmpty) {
        return initialConfig;
      }

      final Map<String, dynamic> data = jsonDecode(rawJson);
      final savedConfig = PdfConfig.fromJson(data);

      // PRECISIÓN CRÍTICA: Restauramos preferencias visuales pero PRESERVAMOS
      // el documentTitle contextual de la operación actual (Cotización, Venta, Préstamo).
      return initialConfig.copyWith(
        theme: savedConfig.theme,
        layoutTemplate: savedConfig.layoutTemplate,
        pageSize: savedConfig.pageSize,
        showImages: savedConfig.showImages,
        showBusinessInfo: savedConfig.showBusinessInfo,
        includeLogo: savedConfig.includeLogo,
        includeShopAddress: savedConfig.includeShopAddress,
        includeOwnerPhone: savedConfig.includeOwnerPhone,
        includeShopRuc: savedConfig.includeShopRuc,
        showProductUnit: savedConfig.showProductUnit,
        showProductUnitPrice: savedConfig.showProductUnitPrice,
        showProductSubtotal: savedConfig.showProductSubtotal,
        showProductSavings: savedConfig.showProductSavings,
        showTotalGlobal: savedConfig.showTotalGlobal,
        showTotalSavings: savedConfig.showTotalSavings,
        showTransactionDetails: initialConfig.showTransactionDetails, // Respeta contexto
        showInstallments: initialConfig.showInstallments,             // Respeta contexto
        showPaymentAccounts: savedConfig.showPaymentAccounts,
        showStatusStamp: savedConfig.showStatusStamp,
        footerNote: savedConfig.footerNote ?? initialConfig.footerNote,
      );
    } catch (e) {
      debugPrint("⚠️ Error aplicando preferencias de PDF: $e");
      return initialConfig;
    }
  }
}
