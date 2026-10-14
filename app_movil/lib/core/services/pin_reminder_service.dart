import 'package:shared_preferences/shared_preferences.dart';

/// Servicio responsable de gestionar la postergación temporal (snooze)
/// del banner de recordatorio de activación de PIN de seguridad.
class PinReminderService {
  static const String _prefKeyPrefix = 'pin_reminder_snoozed_until_ms_';

  /// Retorna `true` si el recordatorio está actualmente pospuesto para el usuario dado.
  static Future<bool> isSnoozed(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final snoozedUntilMs = prefs.getInt('$_prefKeyPrefix$userId');
      if (snoozedUntilMs == null) return false;
      
      final now = DateTime.now().millisecondsSinceEpoch;
      return now < snoozedUntilMs;
    } catch (_) {
      return false;
    }
  }

  /// Pospone el recordatorio por la cantidad de días especificada (por defecto 7 días).
  static Future<void> snooze(int userId, {int days = 7}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final snoozeUntil = DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch;
      await prefs.setInt('$_prefKeyPrefix$userId', snoozeUntil);
    } catch (_) {}
  }

  /// Limpia la postergación (por ejemplo cuando se configura un nuevo PIN).
  static Future<void> clearSnooze(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefKeyPrefix$userId');
    } catch (_) {}
  }

  /// Retorna los días restantes de postergación, o null si no está pospuesto o ya expiró.
  static Future<int?> getRemainingDays(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final snoozedUntilMs = prefs.getInt('$_prefKeyPrefix$userId');
      if (snoozedUntilMs == null) return null;
      
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now >= snoozedUntilMs) return null;

      final diffMs = snoozedUntilMs - now;
      final days = (diffMs / (1000 * 60 * 60 * 24)).ceil();
      return days;
    } catch (_) {
      return null;
    }
  }
}
