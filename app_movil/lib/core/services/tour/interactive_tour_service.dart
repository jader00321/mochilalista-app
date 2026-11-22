import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';
import 'package:app_movil/core/widgets/tour/interactive_tour_overlay.dart';

/// Servicio de Persistencia, Reglas Inteligentes y Coordinación de la Guía Turística Interactiva
class InteractiveTourService {
  static const String _kEnabledKey = 'tour_automatic_enabled';
  static const String _kSuppressedAfterRestoreKey = 'tour_suppressed_after_restore';
  static const String _kScreenSeenPrefix = 'tour_screen_seen_';

  /// Catálogo canónico de los 19 screenId oficiales registrados actualmente en la app
  static const List<String> knownScreenIds = [
    'home_screen',
    'inventory_screen',
    'workbench_screen',
    'quick_sale_screen',
    'product_create_screen',
    'profile_screen',
    'backup_screen',
    'client_tracking_screen',
    'sales_history_screen',
    'license_status_screen',
    'catalog_screen',
    'invoice_scan_screen',
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
  static final ValueNotifier<bool> automaticToursEnabledNotifier = ValueNotifier<bool>(true);

  /// Caché sincrónica en memoria para evitar condiciones de carrera en el mismo frame o entre pestañas concurrentes
  static bool? _cachedAutomaticEnabled;
  static bool? _cachedSuppressedAfterRestore;

  /// Flag estático opcional para forzar la ejecución automática en pruebas controladas
  /// sin importar si el runtimeType contiene 'Test'.
  static bool? autoTriggerOverrideForTesting;

  /// Flag en memoria para prevenir aperturas duplicadas simultáneas
  static bool _isTourCurrentlyActive = false;

  /// Indica si actualmente hay un recorrido visual o modal de bienvenida activo
  static bool get isTourActive => _isTourCurrentlyActive;

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

    try {
      final prefs = await SharedPreferences.getInstance();

      // 2. Verificar si las guías automáticas globales están activadas (por defecto: true)
      final enabled = prefs.getBool(_kEnabledKey) ?? true;
      _cachedAutomaticEnabled = enabled;
      if (automaticToursEnabledNotifier.value != enabled) {
        automaticToursEnabledNotifier.value = enabled;
      }
      if (!enabled) return false;

      // 3. Verificar si fueron suprimidas permanentemente tras restaurar un backup
      final suppressed = prefs.getBool(_kSuppressedAfterRestoreKey) ?? false;
      _cachedSuppressedAfterRestore = suppressed;
      if (suppressed) return false;

      // 4. Verificar si el usuario ya vio u omitió esta pantalla específica
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
        automaticToursEnabledNotifier.value = false;
        await prefs.setBool(_kEnabledKey, false);
      }
    } catch (_) {}
  }

  /// Desactiva globalmente todas las guías turísticas automáticas con propagación sincrónica inmediata
  static Future<void> dismissAllAutomaticTours() async {
    _cachedAutomaticEnabled = false;
    automaticToursEnabledNotifier.value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabledKey, false);
    } catch (_) {}
  }

  /// Suprime permanentemente el disparo automático tras restaurar un respaldo (Drive o local)
  static Future<void> suppressAutomaticToursAfterRestore() async {
    _cachedSuppressedAfterRestore = true;
    _cachedAutomaticEnabled = false;
    automaticToursEnabledNotifier.value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSuppressedAfterRestoreKey, true);
      await prefs.setBool(_kEnabledKey, false);
    } catch (_) {}
  }

  /// Consulta si las guías automáticas se encuentran activas en la configuración
  static Future<bool> areAutomaticToursEnabled() async {
    if (_cachedAutomaticEnabled != null && _cachedSuppressedAfterRestore != null) {
      return _cachedAutomaticEnabled! && !_cachedSuppressedAfterRestore!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_kEnabledKey) ?? true;
      final suppressed = prefs.getBool(_kSuppressedAfterRestoreKey) ?? false;
      _cachedAutomaticEnabled = enabled;
      _cachedSuppressedAfterRestore = suppressed;
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
  static Future<void> setAutomaticToursEnabled(bool enabled) async {
    _cachedAutomaticEnabled = enabled;
    if (enabled) {
      _cachedSuppressedAfterRestore = false;
    }
    automaticToursEnabledNotifier.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabledKey, enabled);
      if (enabled) {
        // Al reactivar explícitamente, anular la supresión por restore
        await prefs.setBool(_kSuppressedAfterRestoreKey, false);
      }
    } catch (_) {}
  }

  /// Reinicia el historial de aprendizaje de todas las pantallas y reactiva las guías
  static Future<void> resetAllTours() async {
    _cachedAutomaticEnabled = true;
    _cachedSuppressedAfterRestore = false;
    automaticToursEnabledNotifier.value = true;
    tourResetEpoch.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabledKey, true);
      await prefs.setBool(_kSuppressedAfterRestoreKey, false);

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
}
