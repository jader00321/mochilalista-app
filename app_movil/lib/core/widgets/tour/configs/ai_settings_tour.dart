import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Claves de widgets para anclaje visual en [AiSettingsScreen]
class AiSettingsTourKeys {
  final GlobalKey modeSelectorKey;
  final GlobalKey quotaCardKey;
  final GlobalKey vaultKey;
  final GlobalKey securityGuideKey;

  AiSettingsTourKeys({
    GlobalKey? modeSelectorKey,
    GlobalKey? quotaCardKey,
    GlobalKey? vaultKey,
    GlobalKey? securityGuideKey,
  }) : modeSelectorKey =
           modeSelectorKey ?? GlobalKey(debugLabel: 'ai_tour_mode_selector'),
       quotaCardKey = quotaCardKey ?? GlobalKey(debugLabel: 'ai_tour_quota_card'),
       vaultKey = vaultKey ?? GlobalKey(debugLabel: 'ai_tour_vault_card'),
       securityGuideKey =
           securityGuideKey ?? GlobalKey(debugLabel: 'ai_tour_security_guide');
}

/// Guía Turística Interactiva completa para [AiSettingsScreen] (4 pasos)
class AiSettingsTour {
  static final AiSettingsTourKeys defaultKeys = AiSettingsTourKeys();

  static ScreenTourConfig buildConfig({AiSettingsTourKeys? keys}) {
    final k = keys ?? defaultKeys;

    return ScreenTourConfig(
      screenId: 'ai_settings_screen',
      screenTitle: 'Configuración IA y Bóveda',
      welcomeSummary:
          'Administra tu cuota compartida de escaneo IA, cambia entre modo oficial MochilaLista o clave propia BYOK y protege tus credenciales en hardware.',
      icon: Icons.auto_awesome_rounded,
      steps: [
        TourStep(
          id: 'step_ai_mode_selector',
          targetKey: k.modeSelectorKey,
          title: 'Selector de Modo IA: Oficial vs BYOK',
          description:
              'Alterna con un toque entre usar tu Bolsa Acumulativa de MochilaLista o conectar tu propia API Key de Google Gemini (BYOK) sin afectar tu licencia activa.',
          tip: 'En modo BYOK tu bolsa acumulada queda congelada intacta para cuando la necesites.',
          icon: Icons.swap_horiz_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_ai_quota_monitor',
          targetKey: k.quotaCardKey,
          title: 'Monitor de Cuota Acumulativa',
          description:
              'Visualiza en vivo cuántos escaneos IA disponibles conserva tu equipo en su bolsa compartida sin reseteo mensual.',
          tip: 'Actualiza esta vista en cualquier momento para ver el saldo sincronizado tras una recarga o cambio de plan.',
          icon: Icons.data_usage_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_ai_vault_keys',
          targetKey: k.vaultKey,
          title: 'Bóveda Multi-Clave y Prueba en Vivo',
          description:
              'Registra múltiples API Keys de Gemini con alias personalizados, elige cuál está activa y usa Probar Clave para verificar conectividad antes de escanear.',
          tip: 'Si una clave alcanza su límite temporal gratuito, activa otra de respaldo en un solo toque.',
          icon: Icons.vpn_key_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_ai_security_guide',
          targetKey: k.securityGuideKey,
          title: 'Protección Cifrada y Guía Gratuita',
          description:
              'Todas tus claves se almacenan cifradas mediante almacenamiento seguro de hardware y nunca se muestran completas. Aquí también tienes los pasos para obtener tu API Key gratis.',
          tip: 'Usa el botón Abrir Google AI Studio si aún no generas tu clave personal de Gemini.',
          icon: Icons.verified_user_outlined,
          borderRadius: 16.0,
        ),
      ],
    );
  }
}
