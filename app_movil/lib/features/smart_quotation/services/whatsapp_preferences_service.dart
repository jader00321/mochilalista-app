import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/features/smart_quotation/models/whatsapp_config_model.dart';

/// 💾 SERVICIO DE PERSISTENCIA DE PREFERENCIAS Y PLANTILLAS DE WHATSAPP
/// Guarda y restaura las preferencias visuales del usuario (estilo de mensaje,
/// bloques a incluir, cuentas de pago, intro y cierre personalizados)
/// preservando estrictamente la reactividad a 0ms e indexado por contexto
/// ('quote' para Cotizaciones, 'sale' para Ventas, 'loan' para Préstamos).
class WhatsAppPreferencesService {
  static const String _prefPrefix = 'mochila_wa_user_default_config_v2';
  static const String _introPrefix = 'mochila_wa_custom_intro_v2';
  static const String _closingPrefix = 'mochila_wa_custom_closing_v2';

  static String _prefKey(String ctx) => '${_prefPrefix}_$ctx';
  static String _introKey(String ctx) => '${_introPrefix}_$ctx';
  static String _closingKey(String ctx) => '${_closingPrefix}_$ctx';

  /// Guarda la configuración actual como predeterminada del usuario según el contexto
  static Future<bool> saveDefaultConfig(WhatsAppConfig config, {String contextKey = 'quote'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> data = config.toJson();
      await prefs.setString(_prefKey(contextKey), jsonEncode(data));
      if (config.customIntro != null) {
        await prefs.setString(_introKey(contextKey), config.customIntro!);
      }
      if (config.customClosing != null) {
        await prefs.setString(_closingKey(contextKey), config.customClosing!);
      }
      return true;
    } catch (e) {
      debugPrint("⚠️ Error guardando preferencias de WhatsApp ($contextKey): $e");
      return false;
    }
  }

  /// Aplica las preferencias guardadas a la configuración en curso según el contexto
  static Future<WhatsAppConfig> applySavedPreferences(WhatsAppConfig initialConfig, {String contextKey = 'quote'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? rawJson = prefs.getString(_prefKey(contextKey));
      final String? savedIntro = prefs.getString(_introKey(contextKey));
      final String? savedClosing = prefs.getString(_closingKey(contextKey));

      if (rawJson == null || rawJson.isEmpty) {
        return initialConfig.copyWith(
          customIntro: savedIntro ?? initialConfig.customIntro,
          customClosing: savedClosing ?? initialConfig.customClosing,
        );
      }

      final Map<String, dynamic> data = jsonDecode(rawJson);
      final savedConfig = WhatsAppConfig.fromJson(data);

      return initialConfig.copyWith(
        style: savedConfig.style,
        showSubtotals: savedConfig.showSubtotals,
        showTotalGlobal: savedConfig.showTotalGlobal,
        showSavingsSection: savedConfig.showSavingsSection,
        showDiscountDetail: savedConfig.showDiscountDetail,
        showDebtInfo: savedConfig.showDebtInfo,
        showDeliveryInfo: savedConfig.showDeliveryInfo,
        showInstallmentDetails: savedConfig.showInstallmentDetails,
        showBusinessInfo: savedConfig.showBusinessInfo,
        includeOwnerPhone: savedConfig.includeOwnerPhone,
        includeShopAddress: savedConfig.includeShopAddress,
        includeShopRuc: savedConfig.includeShopRuc,
        showPaymentInfo: savedConfig.showPaymentInfo,
        includeDelivery: savedConfig.includeDelivery,
        includeValidity: savedConfig.includeValidity,
        customIntro: savedIntro ?? savedConfig.customIntro ?? initialConfig.customIntro,
        customClosing: savedClosing ?? savedConfig.customClosing ?? initialConfig.customClosing,
      );
    } catch (e) {
      debugPrint("⚠️ Error aplicando preferencias de WhatsApp ($contextKey): $e");
      return initialConfig;
    }
  }

  /// Guarda frases personalizadas de intro y cierre por contexto
  static Future<bool> saveCustomTexts({
    required String? customIntro,
    required String? customClosing,
    String contextKey = 'quote',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final introK = _introKey(contextKey);
      final closingK = _closingKey(contextKey);

      if (customIntro != null && customIntro.trim().isNotEmpty) {
        await prefs.setString(introK, customIntro.trim());
      } else {
        await prefs.remove(introK);
      }

      if (customClosing != null && customClosing.trim().isNotEmpty) {
        await prefs.setString(closingK, customClosing.trim());
      } else {
        await prefs.remove(closingK);
      }
      return true;
    } catch (e) {
      debugPrint("⚠️ Error guardando textos personalizados de WhatsApp ($contextKey): $e");
      return false;
    }
  }

  /// Carga frases personalizadas guardadas por contexto
  static Future<Map<String, String?>> loadCustomTexts({String contextKey = 'quote'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'customIntro': prefs.getString(_introKey(contextKey)),
        'customClosing': prefs.getString(_closingKey(contextKey)),
      };
    } catch (e) {
      debugPrint("⚠️ Error cargando textos personalizados de WhatsApp ($contextKey): $e");
      return {'customIntro': null, 'customClosing': null};
    }
  }

  /// Restaura los valores de fábrica eliminando las preferencias guardadas para un contexto o para todos
  static Future<bool> resetToDefaults({String? contextKey}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (contextKey != null) {
        await prefs.remove(_prefKey(contextKey));
        await prefs.remove(_introKey(contextKey));
        await prefs.remove(_closingKey(contextKey));
      } else {
        for (final ctx in ['quote', 'sale', 'loan']) {
          await prefs.remove(_prefKey(ctx));
          await prefs.remove(_introKey(ctx));
          await prefs.remove(_closingKey(ctx));
        }
      }
      return true;
    } catch (e) {
      debugPrint("⚠️ Error reseteando preferencias de WhatsApp: $e");
      return false;
    }
  }
}
