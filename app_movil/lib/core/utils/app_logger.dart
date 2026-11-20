import 'package:flutter/foundation.dart';

/// Logger centralizado con silenciamiento universal estricto en Release (MED-04)
/// Previene la exposición de logs, rutas, tokens o datos sensibles de clientes en logcat.
class AppLogger {
  /// Registra información con formato conciso
  static void i(String tag, String message) {
    if (kDebugMode) debugPrint("📘 [$tag] $message");
  }

  /// Registra una advertencia con formato conciso
  static void w(String tag, String message) {
    if (kDebugMode) debugPrint("⚠️ [$tag] $message");
  }

  /// Registra un error con formato conciso
  static void e(String tag, String message, [dynamic error, StackTrace? stack]) {
    if (kDebugMode) {
      debugPrint("🔴 [$tag] $message");
      if (error != null) debugPrint("Error: $error");
      if (stack != null) debugPrint("StackTrace:\n$stack");
    }
  }

  /// Compatibilidad retroactiva con llamadas heredadas
  static void error(String context, dynamic error, [StackTrace? stack]) {
    if (kDebugMode) {
      debugPrint("[$context] ERROR: $error");
      if (stack != null) {
        debugPrint("[$context] STACKTRACE:\n$stack");
      }
    }
  }

  static void info(String context, String message) {
    if (kDebugMode) debugPrint("[$context] INFO: $message");
  }

  static void warning(String context, String message) {
    if (kDebugMode) debugPrint("[$context] WARNING: $message");
  }
}
