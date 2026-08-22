import 'dart:math';

class SpanishLemmatizer {
  /// Reduce una palabra a su raíz lematizada aproximada en español
  /// para facilitar las búsquedas. Principalmente maneja plurales,
  /// acentos y diminutivos comunes.
  static String lemmatize(String word) {
    if (word.isEmpty) return word;
    
    String w = word.toLowerCase().trim();
    
    // Normalizar acentos
    w = w.replaceAll('á', 'a')
         .replaceAll('é', 'e')
         .replaceAll('í', 'i')
         .replaceAll('ó', 'o')
         .replaceAll('ú', 'u');
         
    if (w.length <= 3) return w; // Palabras muy cortas no se procesan
    
    // Reglas de plurales y diminutivos
    if (w.endsWith('ces')) {
      return '${w.substring(0, w.length - 3)}z'; // lápices -> lápiz, luces -> luz
    } else if (w.endsWith('itos') || w.endsWith('itas')) {
      return w.substring(0, w.length - 4); // palitos -> pal
    } else if (w.endsWith('ito') || w.endsWith('ita')) {
      return w.substring(0, w.length - 3); // palito -> pal
    } else if (w.endsWith('es')) {
      // Regla general para 'es', pero tener cuidado con palabras que terminan en 'es' (ej: mes, trenes)
      // Solo aplicamos si la palabra tiene al menos 5 letras para no romper palabras cortas
      if (w.length > 4) {
        return w.substring(0, w.length - 2); // borradores -> borrador
      }
    } else if (w.endsWith('s')) {
      // Regla general para 's' (cuadernos -> cuaderno)
      // Cuidado con palabras que terminan en s singular (paraguas, abrelatas)
      if (w.length > 3) {
         return w.substring(0, w.length - 1);
      }
    }
    
    return w;
  }

  /// Calcula la similitud de Levenshtein entre dos cadenas de texto.
  /// Retorna un valor entre 0.0 (completamente diferentes) y 1.0 (exactamente iguales).
  static double calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    int len1 = s1.length;
    int len2 = s2.length;
    
    List<List<int>> d = List.generate(
      len1 + 1, 
      (i) => List.filled(len2 + 1, 0)
    );

    for (int i = 0; i <= len1; i++) {
      d[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      d[0][j] = j;
    }

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        int cost = (s1[i - 1] == s2[j - 1]) ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1,      // deletion
          d[i][j - 1] + 1,      // insertion
          d[i - 1][j - 1] + cost // substitution
        ].reduce(min);
      }
    }

    int distance = d[len1][len2];
    int maxLen = max(len1, len2);
    
    return 1.0 - (distance / maxLen);
  }
}
