import 'dart:math' as math;

/// Gestor de ciclo de vida del arranque en frío (True Cold-Start Only).
/// 
/// Garantiza que la experiencia cinemática de apertura SOLO se ejecute cuando el proceso
/// de la aplicación inicia desde cero (cold start), ignorando reactivaciones desde segundo plano
/// ([AppLifecycleState.resumed]) o cambios de ruta internos.
class AppLaunchManager {
  AppLaunchManager._();

  static bool _coldStartCompleted = false;
  static int _launchCounter = 0;

  /// Indica si el arranque en frío ya se completó durante el proceso actual.
  static bool get coldStartCompleted => _coldStartCompleted;

  /// Marca el arranque en frío como finalizado para que nunca vuelva a dispararse en esta sesión.
  static void markColdStartCompleted() {
    _coldStartCompleted = true;
    _launchCounter++;
  }

  /// Selecciona de forma rotativa o pseudoaleatoria una de las 3 coreografías de animación (0, 1 o 2).
  static int getNextAnimationVariant() {
    return (_launchCounter + DateTime.now().second + math.Random().nextInt(3)) % 3;
  }

  /// Reinicia el estado de arranque en frío (exclusivo para pruebas unitarias).
  static void resetForTesting() {
    _coldStartCompleted = false;
    _launchCounter = 0;
  }
}
