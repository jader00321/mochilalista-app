/// Utilitarios deterministas de fecha y hora para Zona Oficial Perú (America/Lima, GMT-5).
/// Garantiza resultados idénticos en Windows local y runners CI con distinto huso horario.
class PeruTimeHelper {
  static const Duration limaOffset = Duration(hours: -5);

  static final RegExp _dateOnlyRegex = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  static final RegExp _explicitTzRegex =
      RegExp(r'(?:Z|[+-]\d{2}:?\d{2})$', caseSensitive: false);

  /// Convierte un [DateTime] a su fecha/hora de calendario en America/Lima (GMT-5).
  /// Devuelve un [DateTime] marcado en UTC cuyos campos corresponden a hora Lima
  /// para formateo seguro sin depender del timezone del host.
  static DateTime toLimaDateTime(DateTime dt) {
    final shifted = dt.toUtc().add(limaOffset);
    return DateTime.utc(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
      shifted.microsecond,
    );
  }

  /// Parsea [input] (`DateTime`, epoch ms/seg o ISO-8601) y retorna su equivalente en hora Lima.
  /// Las cadenas de solo fecha (`YYYY-MM-DD`) se preservan como fecha calendario Lima 00:00:00.
  static DateTime? parseToLimaDateTime(dynamic input) {
    if (input == null) return null;
    if (input is DateTime) {
      return toLimaDateTime(input);
    }
    if (input is int) {
      final ms = input.abs() > 1000000000000 ? input : input * 1000;
      return toLimaDateTime(
        DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
      );
    }

    final raw = input.toString().trim();
    if (raw.isEmpty || raw == '-') return null;

    final dateMatch = _dateOnlyRegex.firstMatch(raw);
    if (dateMatch != null) {
      final y = int.parse(dateMatch.group(1)!);
      final m = int.parse(dateMatch.group(2)!);
      final d = int.parse(dateMatch.group(3)!);
      return DateTime.utc(y, m, d, 0, 0, 0);
    }

    if (RegExp(r'^\d{10,13}$').hasMatch(raw)) {
      final numVal = int.tryParse(raw);
      if (numVal != null) {
        final ms = raw.length <= 10 ? numVal * 1000 : numVal;
        return toLimaDateTime(
          DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        );
      }
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;

    if (_explicitTzRegex.hasMatch(raw)) {
      return toLimaDateTime(parsed);
    }

    // Marca de tiempo sin zona horaria explícita: conservar sus componentes calendario
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  /// Formatea a `YYYY-MM-DD` en zona horaria Lima (GMT-5).
  static String formatLimaDate(dynamic input, {String fallback = ''}) {
    final lima = parseToLimaDateTime(input);
    if (lima == null) return fallback;
    final y = lima.year.toString().padLeft(4, '0');
    final m = lima.month.toString().padLeft(2, '0');
    final d = lima.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Formatea a `YYYY-MM-DD HH:mm:ss` en zona horaria Lima (GMT-5).
  static String formatLimaDateTime(dynamic input, {String fallback = ''}) {
    final lima = parseToLimaDateTime(input);
    if (lima == null) return fallback;
    final y = lima.year.toString().padLeft(4, '0');
    final m = lima.month.toString().padLeft(2, '0');
    final d = lima.day.toString().padLeft(2, '0');
    final h = lima.hour.toString().padLeft(2, '0');
    final min = lima.minute.toString().padLeft(2, '0');
    final s = lima.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$s';
  }

  /// Genera timestamp seguro para nombres de archivos en hora Lima (`YYYY-MM-DDTHH-mm-ss-mmm`).
  static String formatLimaFilenameTimestamp([DateTime? dt]) {
    final lima = toLimaDateTime(dt ?? DateTime.now());
    final y = lima.year.toString().padLeft(4, '0');
    final m = lima.month.toString().padLeft(2, '0');
    final d = lima.day.toString().padLeft(2, '0');
    final h = lima.hour.toString().padLeft(2, '0');
    final min = lima.minute.toString().padLeft(2, '0');
    final s = lima.second.toString().padLeft(2, '0');
    final ms = lima.millisecond.toString().padLeft(3, '0');
    final us = lima.microsecond.toString().padLeft(3, '0');
    return '$y-$m-${d}T$h-$min-$s-$ms$us';
  }

  /// Verifica de forma inclusiva si [input] cae dentro del rango calendario Lima [fromDate]..[toDate].
  static bool isWithinLimaDateRange(
    dynamic input, {
    String? fromDate,
    String? toDate,
  }) {
    final ymd = formatLimaDate(input);
    if (ymd.isEmpty) return false;

    if (fromDate != null && fromDate.trim().isNotEmpty) {
      final fromYmd = formatLimaDate(fromDate.trim());
      if (fromYmd.isNotEmpty && ymd.compareTo(fromYmd) < 0) {
        return false;
      }
    }

    if (toDate != null && toDate.trim().isNotEmpty) {
      final toYmd = formatLimaDate(toDate.trim());
      if (toYmd.isNotEmpty && ymd.compareTo(toYmd) > 0) {
        return false;
      }
    }

    return true;
  }
}
