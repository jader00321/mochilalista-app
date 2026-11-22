import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';
import 'package:app_movil/core/widgets/tour/interactive_tour_overlay.dart';

/// Servicio de Persistencia, Reglas Inteligentes y Coordinación de la Guía Turística Interactiva
class InteractiveTourService {
  static const String _kEnabledKey = 'tour_automatic_enabled';
  static const String _kSuppressedAfterRestoreKey = 'tour_suppressed_after_restore';
  static const String _kScreenSeenPrefix = 'tour_screen_seen_';

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

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Verificar si las guías automáticas globales están activadas (por defecto: true)
      final enabled = prefs.getBool(_kEnabledKey) ?? true;
      if (!enabled) return false;

      // 2. Verificar si fueron suprimidas permanentemente tras restaurar un backup
      final suppressed = prefs.getBool(_kSuppressedAfterRestoreKey) ?? false;
      if (suppressed) return false;

      // 3. Verificar si el usuario ya vio u omitió esta pantalla específica
      final seen = prefs.getBool('$_kScreenSeenPrefix$screenId') ?? false;
      if (seen) return false;

      return true;
    } catch (_) {
      // Fail-safe defensivo: si SharedPreferences falla, no bloquear la experiencia
      return false;
    }
  }

  /// Marca una pantalla específica como ya vista / explorada
  static Future<void> markScreenSeen(String screenId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_kScreenSeenPrefix$screenId', true);
    } catch (_) {}
  }

  /// Desactiva globalmente todas las guías turísticas automáticas
  static Future<void> dismissAllAutomaticTours() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabledKey, false);
    } catch (_) {}
  }

  /// Suprime permanentemente el disparo automático tras restaurar un respaldo (Drive o local)
  static Future<void> suppressAutomaticToursAfterRestore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSuppressedAfterRestoreKey, true);
    } catch (_) {}
  }

  /// Consulta si las guías automáticas se encuentran activas en la configuración
  static Future<bool> areAutomaticToursEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_kEnabledKey) ?? true;
      final suppressed = prefs.getBool(_kSuppressedAfterRestoreKey) ?? false;
      return enabled && !suppressed;
    } catch (_) {
      return false;
    }
  }

  /// Permite encender o apagar el interruptor de guías automáticas desde el Perfil
  static Future<void> setAutomaticToursEnabled(bool enabled) async {
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
    } catch (_) {}
  }

  /// Intenta iniciar la guía automática si cumple todas las reglas de negocio
  static Future<void> maybeStartAutomaticTour(
    BuildContext context,
    ScreenTourConfig config,
  ) async {
    if (_isTourCurrentlyActive) return;

    final shouldShow = await shouldAutoShowTour(config.screenId);
    if (!shouldShow || !context.mounted) return;

    _isTourCurrentlyActive = true;
    try {
      await InteractiveTourOverlay.showWelcomeModal(context, config);
    } finally {
      _isTourCurrentlyActive = false;
    }
  }

  /// Inicia inmediatamente el recorrido interactivo paso a paso bajo demanda (manual)
  static Future<void> startManualTour(
    BuildContext context,
    ScreenTourConfig config,
  ) async {
    if (_isTourCurrentlyActive) return;

    _isTourCurrentlyActive = true;
    InteractiveTourOverlay.startTour(
      context,
      config,
      onCompleted: () {
        _isTourCurrentlyActive = false;
      },
    );
  }
}
