class SmartSearchMatcher {
  SmartSearchMatcher._();

  static final RegExp _spacesRegex = RegExp(r'\s+');

  /// Normaliza una cadena de texto:
  /// 1. Convierte a minúsculas.
  /// 2. Remueve tildes y diacríticos comunes en español (á -> a, é -> e, etc.).
  /// 3. Normaliza la 'ñ' a 'n' para búsquedas tolerantes.
  /// 4. Colapsa múltiples espacios en blanco.
  static String normalize(String? input) {
    if (input == null || input.isEmpty) return '';
    var text = input.toLowerCase().trim();
    text = text
        .replaceAll(RegExp(r'[áàäâã]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöôõ]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[ç]'), 'c');
    return text.replaceAll(_spacesRegex, ' ').trim();
  }

  /// Verifica si una consulta multi-palabra coincide con una lista de campos objetivo.
  /// - Retorna true si la consulta está vacía.
  /// - Tokeniza el query por espacios.
  /// - Criterio AND estricto: cada token debe estar presente en el corpus consolidado normalizado.
  /// - El orden de los tokens no importa (ej. "500 agua" coincide con "Agua Sin Gas 500ml").
  static bool matches({
    required String query,
    required List<String?> targets,
  }) {
    final cleanQuery = normalize(query);
    if (cleanQuery.isEmpty) return true;

    final corpus = targets
        .where((t) => t != null && t.isNotEmpty)
        .map((t) => normalize(t!))
        .join(' ');

    if (corpus.isEmpty) return false;

    final tokens = cleanQuery.split(' ').where((tok) => tok.isNotEmpty).toList();
    for (final token in tokens) {
      if (!corpus.contains(token)) {
        return false;
      }
    }
    return true;
  }
}

