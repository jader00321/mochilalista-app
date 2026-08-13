import 'package:flutter/foundation.dart';

/// Un logger centralizado para manejar errores e información importante.
/// Facilita la depuración en desarrollo y permite a futuro enviar logs a servicios como Sentry o Crashlytics.
class AppLogger {
  /// Registra un error. Usa este método en los bloques catch.
  static void error(String context, dynamic error, [StackTrace? stack]) {
    debugPrint("[$context] ERROR: $error");
    if (stack != null) {
      debugPrint("[$context] STACKTRACE:\n$stack");
    }
  }

  /// Registra información o eventos relevantes.
  static void info(String context, String message) {
    debugPrint("[$context] INFO: $message");
  }

  /// Registra un warning o advertencia.
  static void warning(String context, String message) {
    debugPrint("[$context] WARNING: $message");
  }
}
