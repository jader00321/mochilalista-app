import 'package:intl/intl.dart';

/// Representación inmutable del estado temporal de una cuota frente a una fecha calendario.
class CuotaDateInfo {
  final String dateFormatted; // "dd/MM/yyyy"
  final String prefix;        // "Venció:", "Vence hoy:", "Vence:"
  final String fullLabel;     // "Venció: 18/10/2026"
  final int daysDifference;   // >0 si ya venció (días transcurridos), 0 si es hoy, <0 si vence en el futuro
  final bool isPast;
  final bool isToday;
  final bool isFuture;

  const CuotaDateInfo({
    required this.dateFormatted,
    required this.prefix,
    required this.fullLabel,
    required this.daysDifference,
    required this.isPast,
    required this.isToday,
    required this.isFuture,
  });

  /// Días de vencimiento positivo (0 si no está vencida)
  int get daysOverdue => daysDifference > 0 ? daysDifference : 0;
}

/// Helper centralizado con lógica universal de fechas para cuotas de créditos y préstamos.
class CuotaDateHelper {
  /// Parsea de forma resiliente tanto ISO-8601 (yyyy-MM-dd o con timestamp)
  /// como formato latinoamericano dd/MM/yyyy (18/10/2026) o instancias directas de DateTime.
  static DateTime? parseFlexible(dynamic rawDate) {
    if (rawDate == null) return null;
    if (rawDate is DateTime) return rawDate;
    final str = rawDate.toString().trim();
    if (str.isEmpty) return null;

    // Caso 1: formato dd/MM/yyyy
    if (str.contains('/')) {
      final parts = str.split('/');
      if (parts.length >= 3) {
        final d = int.tryParse(parts[0].trim());
        final m = int.tryParse(parts[1].trim());
        final y = int.tryParse(parts[2].trim().split(' ').first);
        if (d != null && m != null && y != null) {
          return DateTime(y, m, d);
        }
      }
    }

    // Caso 2: formato ISO 8601 (yyyy-MM-dd ...)
    try {
      final dateOnly = str.split('T').first.split(' ').first;
      return DateTime.parse(dateOnly);
    } catch (_) {
      try {
        return DateTime.parse(str);
      } catch (_) {
        return null;
      }
    }
  }

  /// Evalúa el estado temporal de la fecha de vencimiento contra el día actual
  /// (o contra [referenceDate] para pruebas deterministas).
  static CuotaDateInfo evaluate(dynamic rawDueDate, {DateTime? referenceDate}) {
    final dueDate = parseFlexible(rawDueDate);
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (dueDate == null) {
      final fallbackStr = rawDueDate?.toString() ?? "-";
      return CuotaDateInfo(
        dateFormatted: fallbackStr,
        prefix: "Vence:",
        fullLabel: "Vence: $fallbackStr",
        daysDifference: 0,
        isPast: false,
        isToday: false,
        isFuture: true,
      );
    }

    final dueCalendar = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final int daysDiff = today.difference(dueCalendar).inDays;
    final String dateFormatted = DateFormat('dd/MM/yyyy').format(dueCalendar);

    if (daysDiff > 0) {
      // Venció en el pasado (se aplica tanto a cuotas pagadas como impagas)
      return CuotaDateInfo(
        dateFormatted: dateFormatted,
        prefix: "Venció:",
        fullLabel: "Venció: $dateFormatted",
        daysDifference: daysDiff,
        isPast: true,
        isToday: false,
        isFuture: false,
      );
    } else if (daysDiff == 0) {
      // Vence hoy
      return CuotaDateInfo(
        dateFormatted: dateFormatted,
        prefix: "Vence hoy:",
        fullLabel: "Vence hoy: $dateFormatted",
        daysDifference: 0,
        isPast: false,
        isToday: true,
        isFuture: false,
      );
    } else {
      // Vence en el futuro
      return CuotaDateInfo(
        dateFormatted: dateFormatted,
        prefix: "Vence:",
        fullLabel: "Vence: $dateFormatted",
        daysDifference: daysDiff,
        isPast: false,
        isToday: false,
        isFuture: true,
      );
    }
  }
}

