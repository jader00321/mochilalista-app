import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:app_movil/core/utils/clipboard_helper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/utils/whatsapp_uri_builder.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/loyalty_toast_feedback.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';

part 'loyalty_whatsapp/loyalty_whatsapp_guides_part.dart';
part 'loyalty_whatsapp/loyalty_whatsapp_notifications_part.dart';
part 'loyalty_whatsapp/loyalty_whatsapp_preview_controls_part.dart';
part 'loyalty_whatsapp/loyalty_whatsapp_preview_modal.dart';

class LoyaltyWhatsAppService {
  LoyaltyWhatsAppService._();

  static Future<bool> launchWhatsApp(
    BuildContext context,
    String phone,
    String message,
  ) async {
    final clean = WhatsAppUriBuilder.normalizePeruWhatsAppPhone(phone);
    if (clean.isEmpty) {
      if (context.mounted) {
        LoyaltyToastFeedback.showWarning(
          context,
          'El cliente no tiene un teléfono válido registrado',
        );
      }
      return false;
    }

    final url = WhatsAppUriBuilder.buildSendUri(phone: phone, message: message);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      } else {
        if (context.mounted) {
          LoyaltyToastFeedback.showWarning(
            context,
            'No se pudo abrir WhatsApp en este dispositivo',
          );
        }
        return false;
      }
    } catch (_) {
      if (context.mounted) {
        LoyaltyToastFeedback.showWarning(
          context,
          'Error al intentar abrir WhatsApp',
        );
      }
      return false;
    }
  }

  /// Premio Desbloqueado y Confirmado por el Comerciante
  static Future<bool> sendRewardNotification({
    required BuildContext context,
    required String phone,
    required String clientName,
    required String businessName,
    required ClientRewardModel reward,
    required int puntosSaldo,
    required String nivelReputacion,
  }) => _LoyaltyWhatsappMessages.sendRewardNotification(
    context: context,
    phone: phone,
    clientName: clientName,
    businessName: businessName,
    reward: reward,
    puntosSaldo: puntosSaldo,
    nivelReputacion: nivelReputacion,
  );

  /// "Casi en la Meta" (Impulso Comercial de Compra 80%-95%)
  static Future<bool> sendAlmostAtGoalNotification({
    required BuildContext context,
    required String phone,
    required String clientName,
    required String businessName,
    required RewardGoalModel goal,
    required int puntosFaltantes,
    required int puntosActuales,
  }) => _LoyaltyWhatsappMessages.sendAlmostAtGoalNotification(
    context: context,
    phone: phone,
    clientName: clientName,
    businessName: businessName,
    goal: goal,
    puntosFaltantes: puntosFaltantes,
    puntosActuales: puntosActuales,
  );

  /// Felicitación por Subida de Rango / Racha Impecable
  static Future<bool> sendTierCelebrationNotification({
    required BuildContext context,
    required String phone,
    required String clientName,
    required String businessName,
    required ReputationTier tier,
    required int streak,
    required int score,
  }) => _LoyaltyWhatsappMessages.sendTierCelebrationNotification(
    context: context,
    phone: phone,
    clientName: clientName,
    businessName: businessName,
    tier: tier,
    streak: streak,
    score: score,
  );

  /// Situación del Cliente y Premios Disponibles para Reclamar
  static String buildAvailableRewardsMessage({
    required String clientName,
    required String businessName,
    required int puntosSaldo,
    required String nivelReputacion,
    required List<RewardGoalModel> claimableGoals,
    RewardGoalModel? upcomingGoal,
    int missingPoints = 0,
  }) => _LoyaltyWhatsappMessages.buildAvailableRewardsMessage(
    clientName: clientName,
    businessName: businessName,
    puntosSaldo: puntosSaldo,
    nivelReputacion: nivelReputacion,
    claimableGoals: claimableGoals,
    upcomingGoal: upcomingGoal,
    missingPoints: missingPoints,
  );

  /// Formatea el nombre del negocio en mayúsculas limpias para presentaciones formales
  static String formatBusinessName(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return "NUESTRA TIENDA";
    return clean.toUpperCase();
  }

  /// Cartilla / Guía Oficial de Cómo Ganar Puntos y Premios
  static String buildLoyaltyGuideAndCatalogMessage({
    required String businessName,
    required LoyaltyRulesModel rules,
    required List<RewardGoalModel> activeGoals,
    String? clientName,
    int? puntosActuales,
    bool includeRules = true,
    bool includeCatalog = true,
    bool includeStoreInfo = true,
    String? businessAddress,
    String? businessPhone,
  }) => _LoyaltyWhatsappGuides.buildLoyaltyGuideAndCatalogMessage(
    businessName: businessName,
    rules: rules,
    activeGoals: activeGoals,
    clientName: clientName,
    puntosActuales: puntosActuales,
    includeRules: includeRules,
    includeCatalog: includeCatalog,
    includeStoreInfo: includeStoreInfo,
    businessAddress: businessAddress,
    businessPhone: businessPhone,
  );

  /// Plantilla Rápida Resumida (Lectura rápida en WhatsApp)
  static String buildSummaryGuideMessage({
    required String businessName,
    required LoyaltyRulesModel rules,
    required List<RewardGoalModel> activeGoals,
    String? clientName,
    int? puntosActuales,
  }) => _LoyaltyWhatsappGuides.buildSummaryGuideMessage(
    businessName: businessName,
    rules: rules,
    activeGoals: activeGoals,
    clientName: clientName,
    puntosActuales: puntosActuales,
  );

  /// Plantilla Promocional de Invitación
  static String buildPromoInviteMessage({
    required String businessName,
    required List<RewardGoalModel> activeGoals,
    String? clientName,
    int? puntosActuales,
  }) => _LoyaltyWhatsappGuides.buildPromoInviteMessage(
    businessName: businessName,
    activeGoals: activeGoals,
    clientName: clientName,
    puntosActuales: puntosActuales,
  );

  /// Modal de Vista Previa Editable con Selector de Compartir Nativo y Barra de Personalización
  static Future<void> showEditableWhatsAppPreviewModal({
    required BuildContext context,
    required String title,
    required String phone,
    required String initialMessage,
    LoyaltyRulesModel? rules,
    List<RewardGoalModel>? activeGoals,
    String? businessName,
    String? clientName,
    int? puntosActuales,
    List<ClientModel>? availableClients,
    String? businessAddress,
    String? businessPhone,
    VoidCallback? onSent,
  }) => _showEditableWhatsAppPreviewModalImpl(
    context: context,
    title: title,
    phone: phone,
    initialMessage: initialMessage,
    rules: rules,
    activeGoals: activeGoals,
    businessName: businessName,
    clientName: clientName,
    puntosActuales: puntosActuales,
    availableClients: availableClients,
    businessAddress: businessAddress,
    businessPhone: businessPhone,
    onSent: onSent,
  );

  /// Genera el mensaje comercial formateado para difusión de promociones
  static String buildPromotionMessage({
    required String clientName,
    required String businessName,
    required List<Map<String, dynamic>> products,
  }) => _LoyaltyWhatsappMessages.buildPromotionMessage(
    clientName: clientName,
    businessName: businessName,
    products: products,
  );

  /// Difusor de Ofertas y Liquidación
  static Future<bool> sendPromotionBroadcasterNotification({
    required BuildContext context,
    required String phone,
    required String clientName,
    required String businessName,
    required List<Map<String, dynamic>> products,
    String? customMessage,
  }) => _LoyaltyWhatsappMessages.sendPromotionBroadcasterNotification(
    context: context,
    phone: phone,
    clientName: clientName,
    businessName: businessName,
    products: products,
    customMessage: customMessage,
  );
}
