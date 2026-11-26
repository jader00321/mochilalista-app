import 'package:intl/intl.dart';

/// Fuente única de verdad para el formateo de fechas y horas en la app móvil.
///
/// Reutiliza instancias [DateFormat] estáticas cacheadas para evitar asignaciones
/// repetidas dentro de métodos `build()` o `itemBuilder()` en listas largas.
class AppDateFormatter {
  AppDateFormatter._();

  static final DateFormat ddMMyyyy = DateFormat('dd/MM/yyyy');
  static final DateFormat ddMM = DateFormat('dd/MM');
  static final DateFormat ddMMyy = DateFormat('dd/MM/yy');
  static final DateFormat yyyyMMdd = DateFormat('yyyy-MM-dd');
  static final DateFormat mmYyyy = DateFormat('MM/yyyy');
  static final DateFormat ddMMyyyyHHmm = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat ddMMHHmm = DateFormat('dd/MM HH:mm');
  static final DateFormat ddMMyyyyDotHHmm = DateFormat('dd/MM/yyyy • HH:mm');
  static final DateFormat ddMMyyyyHhmma = DateFormat('dd/MM/yyyy - hh:mm a');
  static final DateFormat ddMMyyyyDotHhmma = DateFormat('dd/MM/yyyy • hh:mm a');
  static final DateFormat ddMMMyyyyHhmma = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat ddMMMyyyyDashHhmma = DateFormat('dd MMM yyyy - hh:mm a');
  static final DateFormat ddMMyyyyHhmmsA = DateFormat('dd/MM/yyyy, hh:mm:ss a');
  static final DateFormat hhmm24 = DateFormat('HH:mm');
  static final DateFormat hhmmss24 = DateFormat('HH:mm:ss');
  static final DateFormat hmma = DateFormat('hh:mm a');
  static final DateFormat hmmaCompact = DateFormat('h:mm a');
  static final DateFormat mmmYyyy = DateFormat('MMM yyyy');
  static final DateFormat fileTimestamp = DateFormat('yyyyMMdd_HHmmss');
  static final DateFormat compactDayTime = DateFormat('dd-HHmm');
  static final DateFormat compactHHmmss = DateFormat('HHmmss');

  static const List<String> _monthsShortEs = [
    'ene.',
    'feb.',
    'mar.',
    'abr.',
    'may.',
    'jun.',
    'jul.',
    'ago.',
    'set.',
    'oct.',
    'nov.',
    'dic.',
  ];

  static const List<String> _weekdaysShortEs = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];

  static DateFormat? _esWeekdayDateFmt;
  static DateFormat? _esDayMonthFmt;
  static DateFormat? _esDayMonthYearFmt;

  /// Formatea [date] como `dd/MM/yyyy`.
  static String formatDate(DateTime date) => ddMMyyyy.format(date);

  /// Formatea [date] como `dd/MM/yyyy HH:mm`.
  static String formatDateTime(DateTime date) => ddMMyyyyHHmm.format(date);

  /// Formatea [date] como `yyyy-MM-dd`.
  static String formatIsoDate(DateTime date) => yyyyMMdd.format(date);

  /// Formatea [date] como `HH:mm`.
  static String formatTime24(DateTime date) => hhmm24.format(date);

  /// Formatea [date] como `hh:mm a`.
  static String formatTimeAmPm(DateTime date) => hmma.format(date);

  /// Formatea [date] como `yyyyMMdd_HHmmss` para nombres de respaldo/archivo.
  static String formatFileTimestamp(DateTime date) => fileTimestamp.format(date);

  /// Parsea una marca de tiempo de archivo `yyyyMMdd_HHmmss`.
  static DateTime parseFileTimestamp(String rawDate) {
    final trimmed = rawDate.trim();
    final match = RegExp(r'^(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})$').firstMatch(trimmed);
    if (match != null) {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
        int.parse(match.group(6)!),
      );
    }
    return fileTimestamp.parse(trimmed);
  }

  /// Formatea [date] como `dd MMM` en español sin puntos finales si [stripDot] es true.
  static String formatDayMonthEs(DateTime date, {bool stripDot = false}) {
    try {
      _esDayMonthFmt ??= DateFormat('dd MMM', 'es');
      final formatted = _esDayMonthFmt!.format(date);
      return stripDot ? formatted.replaceAll('.', '') : formatted;
    } catch (_) {
      final day = date.day.toString().padLeft(2, '0');
      final m = _monthsShortEs[date.month - 1];
      final res = '$day $m';
      return stripDot ? res.replaceAll('.', '') : res;
    }
  }

  /// Formatea [date] como `dd MMM yyyy` en español.
  static String formatDayMonthYearEs(DateTime date) {
    try {
      _esDayMonthYearFmt ??= DateFormat('dd MMM yyyy', 'es');
      return _esDayMonthYearFmt!.format(date);
    } catch (_) {
      final day = date.day.toString().padLeft(2, '0');
      final m = _monthsShortEs[date.month - 1];
      return '$day $m ${date.year}';
    }
  }

  /// Formateador único legible en español:
  /// - Con `includeTime: true`: `25 nov. 2026 • 14:30`
  /// - Con `includeWeekday: true`: `Mié, 25/11/2026`
  /// - Por defecto: `25 nov. 2026`
  static String formatDateSpanish(
    DateTime date, {
    bool includeWeekday = false,
    bool includeTime = false,
  }) {
    if (includeTime && !includeWeekday) {
      final day = date.day.toString().padLeft(2, '0');
      final month = _monthsShortEs[date.month - 1];
      final time = hhmm24.format(date);
      return '$day $month ${date.year} • $time';
    }

    if (includeWeekday) {
      try {
        _esWeekdayDateFmt ??= DateFormat('EEE, dd/MM/yyyy', 'es');
        final raw = _esWeekdayDateFmt!.format(date).replaceAll('.', '');
        if (raw.isEmpty) return ddMMyyyy.format(date);
        final capitalized = raw[0].toUpperCase() + raw.substring(1);
        return includeTime ? '$capitalized • ${hhmm24.format(date)}' : capitalized;
      } catch (_) {
        final weekday = _weekdaysShortEs[(date.weekday - 1).clamp(0, 6)];
        final base = '$weekday, ${ddMMyyyy.format(date)}';
        return includeTime ? '$base • ${hhmm24.format(date)}' : base;
      }
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = _monthsShortEs[date.month - 1];
    return '$day $month ${date.year}';
  }
}
