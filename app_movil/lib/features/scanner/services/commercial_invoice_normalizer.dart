import 'package:app_movil/features/scanner/services/spanish_lemmatizer.dart';

/// Servicio especializado en normalización y matching de tokens para facturas
/// y tickets comerciales en Perú (SUNAT / POS / Glosas abreviadas).
class CommercialInvoiceNormalizer {
  /// Remueve acentos y diacríticos manteniendo letras base (á -> a, etc.)
  static String removeDiacritics(String text) {
    if (text.isEmpty) return text;
    var str = text;
    const withDia = 'áéíóúÁÉÍÓÚàèìòùÀÈÌÒÙäëïöüÄËÏÖÜâêîôûÂÊÎÔÛ';
    const withoutDia = 'aeiouAEIOUaeiouAEIOUaeiouAEIOUaeiouAEIOU';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }

  /// Normaliza abreviaturas comerciales, medidas, números y símbolos comunes
  /// en facturación electrónica del Perú.
  static String normalizeCommercialString(String text) {
    if (text.isEmpty) return text;

    String clean = removeDiacritics(text).toLowerCase();

    // 1. Normalizar abreviaturas de numeración: N°, No, Nro, Num, # -> 'n'
    clean = clean.replaceAll(RegExp(r'\b(no|nro|num|numero)\b\.?', caseSensitive: false), 'n');
    clean = clean.replaceAll('n°', 'n ');
    clean = clean.replaceAll('nº', 'n ');
    clean = clean.replaceAll('#', 'n ');

    // 2. Normalizar medidas y dimensiones: ej. 100cm x 100cm -> 100x100cm
    clean = clean.replaceAllMapped(
      RegExp(r'(\d+)\s*(cm|m|mm|mt|mts)?\s*(x|\*)\s*(\d+)\s*(cm|m|mm|mt|mts)?', caseSensitive: false),
      (match) {
        String w = match.group(1)!;
        String h = match.group(4)!;
        String unit = (match.group(2) ?? match.group(5) ?? 'cm').toLowerCase();
        return '${w}x$h$unit';
      },
    );

    // 3. Normalizar unidades comerciales comunes
    clean = clean.replaceAll(RegExp(r'\b(und|unid|uni|pza|pz)\b\.?', caseSensitive: false), 'unidad');
    clean = clean.replaceAll(RegExp(r'\b(doc|dzn|docen)\b\.?', caseSensitive: false), 'docena');
    clean = clean.replaceAll(RegExp(r'\b(pqt|pqte|paq|pq)\b\.?', caseSensitive: false), 'paquete');
    clean = clean.replaceAll(RegExp(r'\b(cto|ctos)\b\.?', caseSensitive: false), 'ciento');
    clean = clean.replaceAll(RegExp(r'\b(mill|mil)\b\.?', caseSensitive: false), 'millar');

    // 4. Limpiar caracteres especiales de puntuación (paréntesis, comillas, guiones)
    clean = clean.replaceAll(RegExp(r'''[()\[\]{}"'/\,\\.:;\-_]'''), ' ');

    // 5. Espacios redundantes
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();

    return clean;
  }

  /// Extrae tokens limpios de un texto comercial
  static List<String> extractTokens(String text) {
    String normalized = normalizeCommercialString(text);
    return normalized
        .split(' ')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && (t.length > 1 || RegExp(r'^\d+$').hasMatch(t) || t == 'n'))
        .toList();
  }

  /// Verifica si dos tokens individuales coinciden, contemplando:
  /// 1. Coincidencia idéntica.
  /// 2. Prefix Stemming para palabras >= 5 letras (ej: "escarch" con "escarchado", "latinoam" con "latinoamericana").
  /// 3. Lematización de plurales/singular en español (SpanishLemmatizer).
  /// 4. Fuzzy distance Levenshtein >= 0.8.
  static double matchTokens(String tokenA, String tokenB) {
    if (tokenA == tokenB) return 1.0;
    if (tokenA.isEmpty || tokenB.isEmpty) return 0.0;

    String cleanA = removeDiacritics(tokenA).toLowerCase();
    String cleanB = removeDiacritics(tokenB).toLowerCase();

    if (cleanA == cleanB) return 1.0;

    // Prefix Stemming: En facturas y POS muchas palabras vienen recortadas por límite de caracteres
    if (cleanA.length >= 5 && cleanB.length >= 5) {
      if (cleanA.startsWith(cleanB) || cleanB.startsWith(cleanA)) {
        return 1.0;
      }
    }

    // Lematización (plurales y sufijos)
    String lemA = SpanishLemmatizer.lemmatize(cleanA);
    String lemB = SpanishLemmatizer.lemmatize(cleanB);
    if (lemA == lemB) return 0.95;

    // Si lematizado también cumple prefix stemming >= 4 letras
    if (lemA.length >= 4 && lemB.length >= 4) {
      if (lemA.startsWith(lemB) || lemB.startsWith(lemA)) {
        return 0.90;
      }
    }

    // Levenshtein fuzzy distance
    double lev = SpanishLemmatizer.calculateSimilarity(lemA, lemB);
    if (lev >= 0.80) {
      return lev;
    }

    return 0.0;
  }

  /// Evalúa la similitud compuesta entre la descripción de una factura y el universo
  /// completo de un producto candidato (Nombre Padre + Variante + Marca + SKU).
  ///
  /// Retorna un CompositeMatchResult con score de 0 a 100, la mejor variante coincidente
  /// y las métricas de cobertura de tokens de la factura.
  static CompositeMatchResult evaluateCompositeMatch({
    required String facturaDescripcion,
    required String productoNombre,
    required String? marcaNombre,
    required List<Map<String, dynamic>> variantes,
    String? facturaMarca,
  }) {
    List<String> tokensFactura = extractTokens(facturaDescripcion);
    if (tokensFactura.isEmpty) {
      return CompositeMatchResult(score: 0, tokenCoverage: 0.0, bestSibling: null);
    }

    List<String> tokensPadre = extractTokens(productoNombre);
    List<String> tokensMarca = marcaNombre != null ? extractTokens(marcaNombre) : [];

    // 1. Similitud pura del Nombre Padre
    double parentTokenScore = 0;
    int parentMatchedCount = 0;
    for (var tp in tokensPadre) {
      double bestMatch = 0;
      for (var tf in tokensFactura) {
        double m = matchTokens(tf, tp);
        if (m > bestMatch) bestMatch = m;
      }
      if (bestMatch >= 0.8) {
        parentTokenScore += bestMatch;
        parentMatchedCount++;
      }
    }
    double parentCoverage = tokensPadre.isNotEmpty ? parentMatchedCount / tokensPadre.length : 0.0;
    double parentSim = tokensPadre.isNotEmpty ? (parentTokenScore / tokensPadre.length) * 100 : 0.0;

    // 2. Evaluar cada variante y encontrar la que mejor explica los tokens restantes
    Map<String, dynamic>? bestSibling;
    double highestCompositeScore = -1;
    double bestCoverage = 0.0;
    int bestSiblingScore = -1;

    // Si no hay variantes registradas, evaluar con lista vacía
    var siblingsToEval = variantes.isNotEmpty ? variantes : [<String, dynamic>{}];

    for (var sibling in siblingsToEval) {
      String varName = sibling['nombre_especifico'] as String? ?? sibling['nombre_completo'] as String? ?? '';
      List<String> tokensVar = extractTokens(varName);

      // Evaluar qué tokens de la FACTURA están cubiertos por (Padre + Variante + Marca)
      int coveredFacturaTokens = 0;
      double totalTokenScore = 0;

      for (var tf in tokensFactura) {
        double maxTfMatch = 0;

        // ¿Match con Nombre Padre?
        for (var tp in tokensPadre) {
          double m = matchTokens(tf, tp);
          if (m > maxTfMatch) maxTfMatch = m;
        }

        // ¿Match con Variante?
        for (var tv in tokensVar) {
          double m = matchTokens(tf, tv);
          if (m > maxTfMatch) maxTfMatch = m;
        }

        // ¿Match con Marca?
        for (var tm in tokensMarca) {
          double m = matchTokens(tf, tm);
          if (m > maxTfMatch) maxTfMatch = m;
        }

        if (maxTfMatch >= 0.75) {
          coveredFacturaTokens++;
          totalTokenScore += maxTfMatch;
        }
      }

      double coverage = coveredFacturaTokens / tokensFactura.length;

      // Calcular coincidencia específica de la variante
      double varTokenScore = 0;
      for (var tv in tokensVar) {
        double bestMatch = 0;
        for (var tf in tokensFactura) {
          double m = matchTokens(tf, tv);
          if (m > bestMatch) bestMatch = m;
        }
        if (bestMatch >= 0.8) {
          varTokenScore += bestMatch;
        }
      }
      double varSim = tokensVar.isNotEmpty ? (varTokenScore / tokensVar.length) * 100 : 0.0;

      // Match de Marca
      double marcaBonus = 0;
      if (facturaMarca != null && facturaMarca.isNotEmpty && marcaNombre != null) {
        List<String> tokensFacturaMarca = extractTokens(facturaMarca);
        for (var tfm in tokensFacturaMarca) {
          for (var tm in tokensMarca) {
            if (matchTokens(tfm, tm) >= 0.8) {
              marcaBonus = 15;
              break;
            }
          }
          if (marcaBonus > 0) break;
        }
      } else if (marcaNombre != null && marcaNombre.isNotEmpty) {
        // La marca no vino detectada como campo aparte, pero está en la descripción de la factura
        for (var tf in tokensFactura) {
          for (var tm in tokensMarca) {
            if (matchTokens(tf, tm) >= 0.8) {
              marcaBonus = 12;
              break;
            }
          }
          if (marcaBonus > 0) break;
        }
      }

      // SCORING COMPUESTO
      // El nombre del padre debe tener una presencia base razonable (>= 50% de sus tokens o parentSim >= 50)
      double compositeScore = 0.0;

      if (parentCoverage >= 0.5 || parentSim >= 50) {
        // Base de nombre padre (hasta 45%)
        compositeScore += (parentSim * 0.45);

        // Aporte de variante (hasta 35% si tiene variante y coincide)
        if (tokensVar.isNotEmpty) {
          compositeScore += (varSim * 0.35);
        } else {
          // Si no tiene variante registrada, el nombre padre pesa más
          compositeScore += (parentSim * 0.25);
        }

        // Aporte de marca (hasta 15%)
        compositeScore += marcaBonus;

        // BONIFICACIÓN DE COBERTURA GLOBAL:
        // Si la gran mayoría de los tokens de la factura están completamente explicados
        // entre Padre + Variante + Marca, este producto es una coincidencia EXACTA.
        if (coverage >= 0.85) {
          compositeScore += 20; // Super bonificación: elimina falsas alertas amarillas
        } else if (coverage >= 0.70) {
          compositeScore += 10;
        }
      } else {
        // Baja presencia del nombre padre -> penalizar
        compositeScore = (totalTokenScore / tokensFactura.length) * 40;
      }

      int finalIntScore = compositeScore.round().clamp(0, 100);

      if (finalIntScore > highestCompositeScore) {
        highestCompositeScore = finalIntScore.toDouble();
        bestCoverage = coverage;
        bestSibling = sibling.isNotEmpty ? sibling : null;
        bestSiblingScore = varSim.round();
      }
    }

    return CompositeMatchResult(
      score: highestCompositeScore.round().clamp(0, 100),
      tokenCoverage: bestCoverage,
      bestSibling: bestSibling,
      bestSiblingScore: bestSiblingScore,
    );
  }
}

class CompositeMatchResult {
  final int score;
  final double tokenCoverage;
  final Map<String, dynamic>? bestSibling;
  final int bestSiblingScore;

  CompositeMatchResult({
    required this.score,
    required this.tokenCoverage,
    this.bestSibling,
    this.bestSiblingScore = 0,
  });
}
