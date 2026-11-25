import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/core/config/app_changelog_registry.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';
import 'package:app_movil/core/widgets/tour/interactive_tour_overlay.dart';

/// Servicio de Persistencia, Reglas Inteligentes y Coordinación de la Guía Turística Interactiva
class InteractiveTourService {
  static const String _kEnabledKey = 'tour_automatic_enabled';
  static const String _kSuppressedAfterRestoreKey =
      'tour_suppressed_after_restore';
  static const String _kScreenSeenPrefix = 'tour_screen_seen_';
  static const String _kInstallOriginSealedKey =
      'tour_install_cohort_sealed_v21';
  static const String _kCohortCleanFirstInstall = 'clean_first_install';
  static const String _kCohortUpdatedOrExisting = 'updated_or_existing';
  static const String _kUserManualOptInKey = 'tour_user_manual_opt_in';
  static const String _kUserManualOptInVersionKey =
      'tour_user_manual_opt_in_version';

  /// Catálogo canónico de los 35 screenId oficiales registrados actualmente en la app
  static const List<String> knownScreenIds = [
    'home_screen',
    'inventory_screen',
    'inventory_offers_tab',
    'inventory_categories_tab',
    'inventory_brands_tab',
    'inventory_providers_tab',
    'workbench_screen',
    'quick_sale_screen',
    'manual_quotation_screen',
    'matching_screen',
    'quotation_detail_screen',
    'product_create_screen',
    'product_detail_screen',
    'product_edit_screen',
    'profile_screen',
    'ai_settings_screen',
    'notifications_screen',
    'commercial_radar_screen',
    'backup_screen',
    'client_tracking_screen',
    'sales_history_screen',
    'sale_history_detail_screen',
    'sale_financial_detail_screen',
    'license_status_screen',
    'catalog_screen',
    'invoice_scan_screen',
    'invoice_review_screen',
    'invoice_staging_screen',
    'quotation_scan_screen',
    'sales_checkout_screen',
    'client_detail_screen',
    'loyalty_center_screen',
    'analytics_dashboard_screen',
    'bundle_builder_screen',
    'printer_config_screen',
  ];

  /// Época incremental de reinicio de tours para sincronización reactiva de pantallas en backstack
  static final ValueNotifier<int> tourResetEpoch = ValueNotifier<int>(0);

  /// Notificador reactivo del estado de guías automáticas globales para sincronización de UI (ProfileScreen)
  static final ValueNotifier<bool> automaticToursEnabledNotifier =
      ValueNotifier<bool>(true);

  /// Caché sincrónica en memoria para evitar condiciones de carrera en el mismo frame o entre pestañas concurrentes
  static bool? _cachedAutomaticEnabled;
  static bool? _cachedSuppressedAfterRestore;
  static String? _cachedInstallOriginSealed;
  static bool? _cachedUserManualOptIn;

  /// Flag estático opcional para forzar la ejecución automática en pruebas controladas
  /// sin importar si el runtimeType contiene 'Test'.
  static bool? autoTriggerOverrideForTesting;

  /// Flag en memoria para prevenir aperturas duplicadas simultáneas
  static bool _isTourCurrentlyActive = false;

  /// Indica si actualmente hay un recorrido visual o modal de bienvenida activo
  static bool get isTourActive => _isTourCurrentlyActive;

  /// Sella la instalación actual como preexistente o actualizada desde una versión previa,
  /// impidiendo que nuevas pantallas o actualizaciones reactiven automáticamente los tours.
  static Future<void> sealAutomaticToursForExistingOrUpdatedInstall({
    bool respectCurrentVersionOptIn = false,
    String? currentAppVersion,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final targetVersion =
          currentAppVersion ?? AppChangelogRegistry.currentVersion;
      final manualOptIn = prefs.getBool(_kUserManualOptInKey) ?? false;
      final optInVersion = prefs.getString(_kUserManualOptInVersionKey);

      if (respectCurrentVersionOptIn &&
          manualOptIn &&
          optInVersion == targetVersion) {
        if (prefs.getString(_kInstallOriginSealedKey) == null) {
          await prefs.setString(
            _kInstallOriginSealedKey,
            _kCohortUpdatedOrExisting,
          );
        }
        _cachedInstallOriginSealed = _kCohortUpdatedOrExisting;
        _cachedUserManualOptIn = true;
        return;
      }

      _cachedInstallOriginSealed = _kCohortUpdatedOrExisting;
      _cachedAutomaticEnabled = false;
      _cachedUserManualOptIn = false;
      if (automaticToursEnabledNotifier.value) {
        automaticToursEnabledNotifier.value = false;
      }

      await prefs.setString(
        _kInstallOriginSealedKey,
        _kCohortUpdatedOrExisting,
      );
      await prefs.setBool(_kEnabledKey, false);
      await prefs.setBool(_kUserManualOptInKey, false);
      await prefs.remove(_kUserManualOptInVersionKey);
    } catch (_) {
      _cachedInstallOriginSealed = _kCohortUpdatedOrExisting;
      _cachedAutomaticEnabled = false;
      _cachedUserManualOptIn = false;
      automaticToursEnabledNotifier.value = false;
    }
  }

  /// Sella únicamente cuando no existe historial previo como primera instalación limpia.
  static Future<void> sealCleanFirstInstallIfUnsealed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingCohort = prefs.getString(_kInstallOriginSealedKey);
      if (existingCohort != null) {
        _cachedInstallOriginSealed = existingCohort;
        return;
      }
      await prefs.setString(
        _kInstallOriginSealedKey,
        _kCohortCleanFirstInstall,
      );
      _cachedInstallOriginSealed = _kCohortCleanFirstInstall;
    } catch (_) {}
  }

  /// Evalúa si corresponde disparar automáticamente la guía de bienvenida para [screenId]
  static Future<bool> shouldAutoShowTour(String screenId) async {
    // 🛡️ REGLA FUNDAMENTAL DE COMPILACIÓN: Cero importación de flutter_test en lib/
    // Detección segura de entorno de pruebas
    if (autoTriggerOverrideForTesting != true) {
      if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
        return false;
      }
    }

    // 1. Verificación sincrónica instantánea en memoria
    if (_cachedAutomaticEnabled == false) return false;
    if (_cachedSuppressedAfterRestore == true) return false;
    if (_cachedInstallOriginSealed == _kCohortUpdatedOrExisting &&
        _cachedUserManualOptIn != true) {
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final cohort = prefs.getString(_kInstallOriginSealedKey);
      final manualOptIn = prefs.getBool(_kUserManualOptInKey) ?? false;
      final suppressed = prefs.getBool(_kSuppressedAfterRestoreKey) ?? false;
      _cachedInstallOriginSealed = cohort;
      _cachedUserManualOptIn = manualOptIn;
      _cachedSuppressedAfterRestore = suppressed;

      // 2. Verificar supresión tras restore
      if (suppressed) {
        _cachedAutomaticEnabled = false;
        if (automaticToursEnabledNotifier.value) {
          automaticToursEnabledNotifier.value = false;
        }
        return false;
      }

      // 3. Si la instalación fue sellada como actualización/existente sin opt-in manual, bloquear siempre
      if (cohort == _kCohortUpdatedOrExisting && !manualOptIn) {
        _cachedAutomaticEnabled = false;
        if (automaticToursEnabledNotifier.value) {
          automaticToursEnabledNotifier.value = false;
        }
        if (prefs.getBool(_kEnabledKey) != false) {
          await prefs.setBool(_kEnabledKey, false);
        }
        return false;
      }

      // 4. Si aún no existe sello v21 pero hay rastro previo de versión anterior en SharedPreferences, sellar
      if (cohort == null && !manualOptIn) {
        final hasLegacyUserTrace = prefs.getInt('last_active_user_id') != null;
        final hasLegacyVersionTrace =
            prefs.getString('last_executed_app_version') != null;
        final hasAnySeenScreen = prefs.getKeys().any(
          (k) => k.startsWith(_kScreenSeenPrefix),
        );
        if (hasLegacyUserTrace || hasLegacyVersionTrace || hasAnySeenScreen) {
          await sealAutomaticToursForExistingOrUpdatedInstall();
          return false;
        }
      }

      // 5. Verificar si las guías automáticas globales están activadas (por defecto: true en clean install)
      final enabled = prefs.getBool(_kEnabledKey) ?? true;
      _cachedAutomaticEnabled = enabled;
      if (automaticToursEnabledNotifier.value != enabled) {
        automaticToursEnabledNotifier.value = enabled;
      }
      if (!enabled) return false;

      // 6. Verificar si el usuario ya vio u omitió esta pantalla específica
      final seen = prefs.getBool('$_kScreenSeenPrefix$screenId') ?? false;
      if (seen) return false;

      return true;
    } catch (_) {
      // Fail-safe defensivo: si SharedPreferences falla, no bloquear la experiencia
      return false;
    }
  }

  /// Marca una pantalla específica como ya vista / explorada y auto-desactiva si se completó el catálogo
  static Future<void> markScreenSeen(String screenId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_kScreenSeenPrefix$screenId', true);

      // Auto-desactivación limpia al completar o haber omitido todas las pantallas conocidas
      bool allSeen = true;
      for (final id in knownScreenIds) {
        final seen = prefs.getBool('$_kScreenSeenPrefix$id') ?? false;
        if (!seen) {
          allSeen = false;
          break;
        }
      }
      if (allSeen) {
        _cachedAutomaticEnabled = false;
        _cachedUserManualOptIn = false;
        _cachedInstallOriginSealed = _kCohortUpdatedOrExisting;
        automaticToursEnabledNotifier.value = false;
        await prefs.setBool(_kEnabledKey, false);
        await prefs.setBool(_kUserManualOptInKey, false);
        await prefs.remove(_kUserManualOptInVersionKey);
        await prefs.setString(
          _kInstallOriginSealedKey,
          _kCohortUpdatedOrExisting,
        );
      }
    } catch (_) {}
  }

  /// Desactiva globalmente todas las guías turísticas automáticas con propagación sincrónica inmediata
  static Future<void> dismissAllAutomaticTours() async {
    _cachedAutomaticEnabled = false;
    _cachedUserManualOptIn = false;
    _cachedInstallOriginSealed = _kCohortUpdatedOrExisting;
    automaticToursEnabledNotifier.value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabledKey, false);
      await prefs.setBool(_kUserManualOptInKey, false);
      await prefs.remove(_kUserManualOptInVersionKey);
      await prefs.setString(
        _kInstallOriginSealedKey,
        _kCohortUpdatedOrExisting,
      );
    } catch (_) {}
  }

  /// Suprime permanentemente el disparo automático tras restaurar un respaldo (Drive o local)
  static Future<void> suppressAutomaticToursAfterRestore() async {
    _cachedSuppressedAfterRestore = true;
    _cachedAutomaticEnabled = false;
    _cachedUserManualOptIn = false;
    _cachedInstallOriginSealed = _kCohortUpdatedOrExisting;
    automaticToursEnabledNotifier.value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSuppressedAfterRestoreKey, true);
      await prefs.setBool(_kEnabledKey, false);
      await prefs.setBool(_kUserManualOptInKey, false);
      await prefs.remove(_kUserManualOptInVersionKey);
      await prefs.setString(
        _kInstallOriginSealedKey,
        _kCohortUpdatedOrExisting,
      );
    } catch (_) {}
  }

  /// Consulta si las guías automáticas se encuentran activas en la configuración
  static Future<bool> areAutomaticToursEnabled() async {
    if (_cachedInstallOriginSealed == _kCohortUpdatedOrExisting &&
        _cachedUserManualOptIn != true) {
      return false;
    }
    if (_cachedAutomaticEnabled != null &&
        _cachedSuppressedAfterRestore != null) {
      return _cachedAutomaticEnabled! && !_cachedSuppressedAfterRestore!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final cohort = prefs.getString(_kInstallOriginSealedKey);
      final manualOptIn = prefs.getBool(_kUserManualOptInKey) ?? false;
      final suppressed = prefs.getBool(_kSuppressedAfterRestoreKey) ?? false;
      _cachedInstallOriginSealed = cohort;
      _cachedUserManualOptIn = manualOptIn;
      _cachedSuppressedAfterRestore = suppressed;

      if (cohort == _kCohortUpdatedOrExisting && !manualOptIn) {
        _cachedAutomaticEnabled = false;
        if (automaticToursEnabledNotifier.value) {
          automaticToursEnabledNotifier.value = false;
        }
        return false;
      }

      final enabled = prefs.getBool(_kEnabledKey) ?? true;
      _cachedAutomaticEnabled = enabled;
      final result = enabled && !suppressed;
      if (automaticToursEnabledNotifier.value != result) {
        automaticToursEnabledNotifier.value = result;
      }
      return result;
    } catch (_) {
      return false;
    }
  }

  /// Permite encender o apagar el interruptor de guías automáticas desde el Perfil
  static Future<void> setAutomaticToursEnabled(
    bool enabled, {
    bool userInitiated = false,
  }) async {
    _cachedAutomaticEnabled = enabled;
    if (enabled) {
      _cachedSuppressedAfterRestore = false;
      if (userInitiated) {
        _cachedUserManualOptIn = true;
      }
    } else {
      _cachedUserManualOptIn = false;
      _cachedInstallOriginSealed = _kCohortUpdatedOrExisting;
    }
    automaticToursEnabledNotifier.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabledKey, enabled);
      if (enabled) {
        // Al reactivar explícitamente, anular la supresión por restore
        await prefs.setBool(_kSuppressedAfterRestoreKey, false);
        if (userInitiated) {
          await prefs.setBool(_kUserManualOptInKey, true);
          await prefs.setString(
            _kUserManualOptInVersionKey,
            AppChangelogRegistry.currentVersion,
          );
        }
      } else {
        await prefs.setBool(_kUserManualOptInKey, false);
        await prefs.remove(_kUserManualOptInVersionKey);
        await prefs.setString(
          _kInstallOriginSealedKey,
          _kCohortUpdatedOrExisting,
        );
      }
    } catch (_) {}
  }

  /// Reinicia el historial de aprendizaje de todas las pantallas y reactiva las guías
  static Future<void> resetAllTours({bool userInitiated = true}) async {
    _cachedAutomaticEnabled = true;
    _cachedSuppressedAfterRestore = false;
    _cachedUserManualOptIn = userInitiated;
    automaticToursEnabledNotifier.value = true;
    tourResetEpoch.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabledKey, true);
      await prefs.setBool(_kSuppressedAfterRestoreKey, false);
      await prefs.setBool(_kUserManualOptInKey, userInitiated);
      if (userInitiated) {
        await prefs.setString(
          _kUserManualOptInVersionKey,
          AppChangelogRegistry.currentVersion,
        );
      } else {
        await prefs.remove(_kUserManualOptInVersionKey);
      }

      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_kScreenSeenPrefix)) {
          await prefs.remove(key);
        }
      }
      for (final id in knownScreenIds) {
        await prefs.remove('$_kScreenSeenPrefix$id');
      }
    } catch (_) {}
  }

  /// Reinicia el flag en memoria para pruebas controladas
  static void resetRuntimeLockForTesting() {
    _isTourCurrentlyActive = false;
    _cachedAutomaticEnabled = null;
    _cachedSuppressedAfterRestore = null;
    _cachedInstallOriginSealed = null;
    _cachedUserManualOptIn = null;
    automaticToursEnabledNotifier.value = true;
  }

  /// Intenta iniciar la guía automática si cumple todas las reglas de negocio
  static Future<void> maybeStartAutomaticTour(
    BuildContext context,
    ScreenTourConfig config, {
    VoidCallback? onTourCompleted,
  }) async {
    if (_isTourCurrentlyActive) return;

    final shouldShow = await shouldAutoShowTour(config.screenId);
    if (!shouldShow || !context.mounted) return;

    _isTourCurrentlyActive = true;
    bool tourStarted = false;
    try {
      tourStarted = await InteractiveTourOverlay.showWelcomeModal(
        context,
        config,
        onTourStarted: () {
          // Candado retenido mientras se monta el OverlayEntry
        },
        onTourCompleted: () {
          _isTourCurrentlyActive = false;
          onTourCompleted?.call();
        },
      );
    } catch (_) {
      _isTourCurrentlyActive = false;
      onTourCompleted?.call();
      return;
    }

    // Si el usuario no inició el tour (omitió o cerró el modal), liberar el candado
    if (!tourStarted) {
      _isTourCurrentlyActive = false;
      onTourCompleted?.call();
    }
  }

  /// Inicia inmediatamente el recorrido interactivo paso a paso bajo demanda (manual)
  static Future<void> startManualTour(
    BuildContext context,
    ScreenTourConfig config, {
    VoidCallback? onTourCompleted,
  }) async {
    if (_isTourCurrentlyActive) return;

    _isTourCurrentlyActive = true;
    final started = InteractiveTourOverlay.startTour(
      context,
      config,
      onCompleted: () {
        _isTourCurrentlyActive = false;
        onTourCompleted?.call();
      },
    );
    if (!started) {
      _isTourCurrentlyActive = false;
      onTourCompleted?.call();
    }
  }

  /// Cancela limpiamente cualquier guía interactiva activa ante botón Atrás del sistema.
  static Future<bool> cancelActiveTour() async {
    if (!_isTourCurrentlyActive) return false;
    final cancelled = await InteractiveTourOverlay.cancelActiveTour();
    if (!cancelled) {
      _isTourCurrentlyActive = false;
    }
    return true;
  }
}
