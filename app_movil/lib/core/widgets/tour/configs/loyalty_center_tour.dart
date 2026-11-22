import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Claves de widgets para anclaje visual en [LoyaltyCenterScreen]
class LoyaltyCenterTourKeys {
  final rulesConfigKey = GlobalKey();
  final rewardsCatalogKey = GlobalKey();
  final pendingClientsKey = GlobalKey();
  final broadcastWhatsappKey = GlobalKey();
}

/// Configuración pedagógica de la Guía Turística para [LoyaltyCenterScreen]
class LoyaltyCenterTour {
  static ScreenTourConfig buildConfig({
    required LoyaltyCenterTourKeys keys,
    Future<void> Function(int index)? onSwitchTab,
    Future<void> Function()? onRestoreInitialTab,
  }) {
    return ScreenTourConfig(
      screenId: 'loyalty_center_screen',
      screenTitle: 'Centro de Fidelización y Premios',
      welcomeSummary:
          'Premia la preferencia y puntualidad de tus clientes con puntos automáticos, metas de recompensa y campañas exclusivas por WhatsApp.',
      icon: Icons.stars_rounded,
      steps: [
        TourStep(
          id: 'loyalty_rules_config',
          targetKey: keys.rulesConfigKey,
          title: 'Reglas de Acumulación y Puntos',
          description:
              'Establece cuántos puntos acumula tu cliente por cada sol en compras al contado y premia con puntos extra los pagos puntuales de cuotas.',
          tip:
              'Un esquema claro y generoso estimula las compras recurrentes y mejora tu liquidez.',
          icon: Icons.tune_rounded,
          onBeforeStep: () async {
            if (onSwitchTab != null) {
              await onSwitchTab(1);
            }
          },
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'loyalty_rewards_catalog',
          targetKey: keys.rewardsCatalogKey,
          title: 'Catálogo de Metas y Premios',
          description:
              'Crea recompensas comerciales atractivas: descuentos en porcentaje, dinero directo a favor o productos de obsequio al alcanzar cierto puntaje.',
          tip:
              'Los premios aprobados se pueden canjear en 1 toque en Caja Rápida como saldo a favor.',
          icon: Icons.card_giftcard_rounded,
          onBeforeStep: () async {
            if (onSwitchTab != null) {
              await onSwitchTab(1);
            }
          },
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'loyalty_reputation_clients',
          targetKey: keys.pendingClientsKey,
          title: 'Reputación y Puntos de Clientes',
          description:
              'Supervisa los niveles de lealtad de tu clientela (Bronce, Plata, Oro, Diamante) y detecta quiénes están cerca de alcanzar su siguiente recompensa.',
          tip:
              'Filtra por "Casi en la Meta" para incentivar compras de cierre de mes.',
          icon: Icons.military_tech_rounded,
          onBeforeStep: () async {
            if (onSwitchTab != null) {
              await onSwitchTab(0);
            }
          },
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'loyalty_broadcast_whatsapp',
          targetKey: keys.broadcastWhatsappKey,
          title: 'Difusión y Ofertas por WhatsApp',
          description:
              'Selecciona productos en oferta o baja rotación y envía campañas promocionales segmentadas por WhatsApp a tus clientes más fieles.',
          tip:
              'La difusión dirigida multiplica el impacto de tus promociones sin costo adicional.',
          icon: Icons.campaign_rounded,
          onBeforeStep: () async {
            if (onSwitchTab != null) {
              await onSwitchTab(2);
            }
          },
          onAfterStep: () async {
            if (onRestoreInitialTab != null) {
              await onRestoreInitialTab();
            }
          },
          borderRadius: 16.0,
        ),
      ],
    );
  }
}
