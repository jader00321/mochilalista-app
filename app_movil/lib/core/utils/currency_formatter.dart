import 'package:intl/intl.dart';

/// Helper centralizado para estandarizar el formato monetario peruano oficial
/// en todo el sistema (S/ #,##0.00 con prefijo invariable y dos decimales).
class AppCurrency {
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'S/ ',
    customPattern: 'S/ #,##0.00',
  );

  /// Formatea un valor numérico como moneda estándar peruana. Ejemplo: 258.57 -> "S/ 258.57"
  static String format(num? amount) {
    if (amount == null) return 'S/ 0.00';
    return _formatter.format(amount);
  }
}
