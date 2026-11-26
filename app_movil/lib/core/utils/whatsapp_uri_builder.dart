/// Constructor canónico DRY de enlaces WhatsApp (`wa.me/`) con normalización
/// segura de teléfonos de Perú (`+51` / `51`) e internacionales.
class WhatsAppUriBuilder {
  WhatsAppUriBuilder._();

  /// Normaliza teléfonos evitando duplicar el prefijo peruano (`5151...` / `51+51...`):
  /// - `'987654321'` -> `'51987654321'`
  /// - `'+51 987 654 321'` -> `'51987654321'`
  /// - `'51987654321'` -> `'51987654321'`
  /// - `'+1 415 555 0101'` -> `'14155550101'` (internacional explícito con `+` conserva código país)
  /// - `'000000000'` o inválido (`< 8` dígitos) -> `''`
  static String normalizePeruWhatsAppPhone(String rawPhone) {
    final trimmed = rawPhone.trim();
    if (trimmed.isEmpty) return '';

    final hasPlusPrefix = trimmed.startsWith('+');
    var digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty || RegExp(r'^0+$').hasMatch(digits)) {
      return '';
    }

    if (digits.startsWith('00') && digits.length > 10) {
      digits = digits.substring(2);
    }

    if (digits.length == 9) {
      return '51$digits';
    }

    if (digits.startsWith('51') && digits.length == 11) {
      return digits;
    }

    if (digits.startsWith('5151') && digits.length == 13) {
      return digits.substring(2);
    }

    if (hasPlusPrefix && digits.length >= 8) {
      return digits;
    }

    if (digits.length >= 8) {
      return digits;
    }

    return '';
  }

  /// Construye un [Uri] oficial `https://wa.me/...` codificando [message] con
  /// [Uri.encodeComponent] cuando no esté vacío.
  static Uri buildSendUri({
    required String phone,
    String? message,
    String? fallbackPhone,
  }) {
    var normalized = normalizePeruWhatsAppPhone(phone);
    if (normalized.isEmpty && fallbackPhone != null && fallbackPhone.trim().isNotEmpty) {
      normalized = normalizePeruWhatsAppPhone(fallbackPhone);
    }

    final base = normalized.isNotEmpty
        ? 'https://wa.me/$normalized'
        : 'https://wa.me/';

    if (message != null && message.isNotEmpty) {
      return Uri.parse('$base?text=${Uri.encodeComponent(message)}');
    }
    return Uri.parse(base);
  }
}
