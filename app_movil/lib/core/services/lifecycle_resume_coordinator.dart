import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/auth/screens/onboarding/lock_screen.dart';

/// ⚡ LifecycleResumeCoordinator - Mobile Awards Standard
/// 
/// Coordina la reanudación fluida de la app a 60/120 FPS eliminando:
/// 1. Tirones por E/S en milisegundo 0 (caché en RAM de configuración de PIN).
/// 2. Concurrencia de shaders/renderizado mediante diferimiento post-transición (450ms).
/// 3. Congelamiento y descongelamiento limpio de AnimationControllers en background.
/// 4. Cooldown inteligente (30s) para evitar consultas a SQLite en salidas breves.
class LifecycleResumeCoordinator {
  LifecycleResumeCoordinator._();

  static final LifecycleResumeCoordinator instance = LifecycleResumeCoordinator._();

  // Constantes de temporización
  static const Duration cooldownDuration = Duration(seconds: 30);
  static const Duration postTransitionDelay = Duration(milliseconds: 450);

  DateTime? _pausedTime;
  Timer? _postTransitionTimer;
  bool _isTransitionInProgress = false;

  // Registro de controladores de animación para congelar/descongelar
  final Set<AnimationController> _registeredControllers = {};

  // Caché en RAM de configuración de PIN para 0ms de latencia en resumed
  int _cachedPinDelayMinutes = 1;
  bool _isPinCacheLoaded = false;

  /// Retorna si hay una transición de ventana de Android en progreso (0ms - 450ms).
  bool get isTransitionInProgress => _isTransitionInProgress;

  /// Momento en que la app pasó a background
  DateTime? get pausedTime => _pausedTime;

  /// Registra un AnimationController para ser pausado al salir y reanudado al volver.
  void registerController(AnimationController controller) {
    _registeredControllers.add(controller);
  }

  /// Desregistra un AnimationController.
  void unregisterController(AnimationController controller) {
    _registeredControllers.remove(controller);
  }

  /// Inicializa o actualiza la caché en RAM de la configuración del PIN de seguridad.
  Future<void> prefetchPinConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedPinDelayMinutes = prefs.getInt('pin_delay_minutes') ?? 1;
      _isPinCacheLoaded = true;
    } catch (_) {
      _cachedPinDelayMinutes = 1;
    }
  }

  /// Actualiza manualmente la caché cuando el usuario cambia el PIN o el tiempo de espera.
  void updateCachedPinDelay(int delayMinutes) {
    _cachedPinDelayMinutes = delayMinutes;
    _isPinCacheLoaded = true;
  }

  /// Llamado cuando el estado de la aplicación cambia a [AppLifecycleState.paused] o [AppLifecycleState.hidden].
  void onAppPaused(BuildContext context) {
    _pausedTime = DateTime.now();
    _isTransitionInProgress = false;
    _postTransitionTimer?.cancel();

    // Pausar inmediatamente todos los tickers registrados para liberar CPU/GPU
    for (final controller in _registeredControllers) {
      if (controller.isAnimating) {
        controller.stop(canceled: false);
      }
    }

    // Comprobación de bloqueo inmediato a 0ms si delayMinutes == 0
    _checkImmediateLock(context);
  }

  /// Llamado cuando el estado de la aplicación cambia a [AppLifecycleState.resumed].
  void onAppResumed(
    BuildContext context, {
    VoidCallback? onPostTransitionSync,
  }) {
    if (_pausedTime == null) return;

    final durationInBackground = DateTime.now().difference(_pausedTime!);
    _isTransitionInProgress = true;

    // 1. Verificación instantánea a 0ms del bloqueo por PIN con valores cacheados
    final shouldLock = _evaluatePinLock(context, durationInBackground);
    if (shouldLock) {
      _pausedTime = null;
      _isTransitionInProgress = false;
      return;
    }

    // 2. Cancelar timers anteriores y diferir post-transición (450ms)
    _postTransitionTimer?.cancel();
    _postTransitionTimer = Timer(postTransitionDelay, () {
      _isTransitionInProgress = false;

      // Reanudar suavemente las animaciones activas
      for (final controller in _registeredControllers) {
        if (!controller.isAnimating) {
          controller.repeat(reverse: true);
        }
      }

      // Re-sincronizar caché de PIN de fondo por si cambió externamente
      prefetchPinConfig();

      // 3. Ejecutar sincronización de datos con regla de cooldown (>= 30s)
      if (durationInBackground >= cooldownDuration) {
        onPostTransitionSync?.call();
      }

      _pausedTime = null;
    });
  }

  bool _evaluatePinLock(BuildContext context, Duration durationInBackground) {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (!auth.hasPinCache || auth.user == null) {
        return false;
      }

      // Si pasaron los minutos configurados (o delay == 0)
      if (durationInBackground.inMinutes >= _cachedPinDelayMinutes) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LockScreen(userId: auth.user!.id)),
          (route) => false,
        );
        return true;
      }
    } catch (_) {
      // Ignorar si el contexto no contiene AuthProvider (ej. en widgets de test)
    }
    return false;
  }

  void _checkImmediateLock(BuildContext context) {
    if (_isPinCacheLoaded && _cachedPinDelayMinutes == 0) {
      try {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        if (auth.hasPinCache && auth.user != null) {
          _pausedTime = null;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => LockScreen(userId: auth.user!.id)),
            (route) => false,
          );
        }
      } catch (_) {
        // Ignorar si el contexto no contiene AuthProvider
      }
    }
  }

  /// Limpieza de recursos (por ejemplo al destruir la sesión).
  void dispose() {
    _postTransitionTimer?.cancel();
    _registeredControllers.clear();
    _pausedTime = null;
  }

  /// Utilidad para testing unitario
  @visibleForTesting
  void resetForTesting() {
    _postTransitionTimer?.cancel();
    _registeredControllers.clear();
    _pausedTime = null;
    _isTransitionInProgress = false;
    _cachedPinDelayMinutes = 1;
    _isPinCacheLoaded = false;
  }

  @visibleForTesting
  void setPausedTimeForTesting(DateTime time) {
    _pausedTime = time;
  }

  @visibleForTesting
  int get cachedPinDelayMinutes => _cachedPinDelayMinutes;
}
