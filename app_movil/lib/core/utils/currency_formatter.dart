import 'package:intl/intl.dart';

/// Helper centralizado para estandarizar el formato monetario peruano oficial
/// en todo el sistema (`S/ #,##0.00` con prefijo invariable por defecto).
class AppCurrency {
  AppCurrency._();

  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'S/ ',
    customPattern: 'S/ #,##0.00',
  );

  static final Map<int, NumberFormat> _groupedFormatters = {2: _formatter};

  /// Formatea un valor numérico como moneda estándar peruana.
  /// Ejemplo por defecto: `1258.57 -> "S/ 1,258.57"`.
  /// Con `includeThousandsSeparator: false`: `1258.57 -> "S/ 1258.57"`.
  static String format(
    num? amount, {
    int decimals = 2,
    bool includeThousandsSeparator = true,
  }) {
    final safe = (amount ?? 0).toDouble();
    final safeValue = safe.isNaN || !safe.isFinite ? 0.0 : safe;
    final clampedDecimals = decimals.clamp(0, 6);

    if (clampedDecimals == 2 && includeThousandsSeparator) {
      return _formatter.format(safeValue);
    }

    final isNeg = safeValue < 0;
    final absVal = safeValue.abs();
    final prefix = isNeg ? '-S/ ' : 'S/ ';

    if (!includeThousandsSeparator) {
      return '$prefix${absVal.toStringAsFixed(clampedDecimals)}';
    }

    final fmt = _groupedFormatters.putIfAbsent(
      clampedDecimals,
      () => NumberFormat(
        clampedDecimals > 0 ? '#,##0.${'0' * clampedDecimals}' : '#,##0',
        'en_US',
      ),
    );
    return '$prefix${fmt.format(absVal)}';
  }
}
