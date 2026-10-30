class UnitMatch {
  final String name;
  final int factor;
  final bool isConfigurable;

  UnitMatch({
    required this.name,
    required this.factor,
    required this.isConfigurable,
  });
}

enum StockValidationStatus { exact, hasLeftover, deficit, empty }

class StockValidationResult {
  final int fullUnits;
  final int leftover;
  final int deficit;
  final StockValidationStatus status;
  final double costoBaseSobrante;

  StockValidationResult({
    required this.fullUnits,
    required this.leftover,
    required this.deficit,
    required this.status,
    required this.costoBaseSobrante,
  });

  factory StockValidationResult.empty() => StockValidationResult(
        fullUnits: 0,
        leftover: 0,
        deficit: 0,
        status: StockValidationStatus.empty,
        costoBaseSobrante: 0.0,
      );

  String userMessage(String unitName, int factor) {
    if (status == StockValidationStatus.deficit) {
      return "Faltan $deficit unidades para completar 1 $unitName.\nTienes ${factor - deficit} unidades, pero se necesitan mínimo $factor para 1 $unitName.\nCambia a Unidad (x1) o ajusta la cantidad.";
    } else if (status == StockValidationStatus.hasLeftover) {
      int total = fullUnits * factor + leftover;
      return "$total unidades ÷ $factor por $unitName = $fullUnits $unitName + $leftover sueltas\nDebes crear una variante unitaria para las $leftover unidades.";
    }
    return "Stock validado correctamente.";
  }
}

class UnitCatalogService {
  // Unidades de factor fijo (estándar)
  static final List<Map<String, dynamic>> _fixedUnits = [
    {
      'name': 'Unidad',
      'factor': 1,
      'synonyms': ['und', 'unid', 'u', 'pieza', 'pza', 'pz', 'unit', 'ud', 'unidad']
    },
    {
      'name': 'Par',
      'factor': 2,
      'synonyms': ['par', 'pares', 'pr']
    },
    {
      'name': '½ Docena',
      'factor': 6,
      'synonyms': ['media docena', '1/2 docena', 'media doc', '½ docena', '½ doc']
    },
    {
      'name': 'Decena',
      'factor': 10,
      'synonyms': ['dec', 'decena']
    },
    {
      'name': 'Docena',
      'factor': 12,
      'synonyms': ['doc', 'docena', 'dzn', 'dz', 'docna']
    },
    {
      'name': 'Ciento',
      'factor': 100,
      'synonyms': ['cto', 'cien', 'ciento', 'centenar']
    },
    {
      'name': 'Millar',
      'factor': 1000,
      'synonyms': ['mll', 'mil', 'millar']
    },
    {
      'name': 'Gruesa',
      'factor': 144,
      'synonyms': ['grz', 'gruesa']
    },
  ];

  // Unidades de factor configurable (el usuario define cuánto trae)
  static final List<Map<String, dynamic>> _configurableUnits = [
    {'name': 'Paquete', 'synonyms': ['paq', 'pack', 'pkg', 'pqte', 'paquete']},
    {'name': 'Caja', 'synonyms': ['cj', 'box', 'caja']},
    {'name': 'Display', 'synonyms': ['disp', 'exhibidor', 'display']},
    {'name': 'Blíster', 'synonyms': ['bls', 'blister', 'blíster']},
    {'name': 'Tira', 'synonyms': ['tira', 'strip']},
    {'name': 'Fardo', 'synonyms': ['fdo', 'fardo', 'bulto']},
    {'name': 'Saco', 'synonyms': ['saco', 'costal']},
    {'name': 'Bolsa', 'synonyms': ['bolsa', 'bag']},
  ];

  /// Resuelve una unidad a partir de un texto libre ingresado por el usuario.
  static UnitMatch? resolveUnit(String input) {
    if (input.trim().isEmpty) return null;
    
    // Normalizar input: a minúsculas, sin acentos simples, sin espacios extra
    String normalizedInput = _normalizeText(input);

    // 1. Buscar en unidades fijas
    for (var unit in _fixedUnits) {
      List<String> synonyms = List<String>.from(unit['synonyms']);
      if (synonyms.contains(normalizedInput)) {
        return UnitMatch(
          name: unit['name'],
          factor: unit['factor'],
          isConfigurable: false,
        );
      }
    }

    // 2. Buscar en unidades configurables
    for (var unit in _configurableUnits) {
      List<String> synonyms = List<String>.from(unit['synonyms']);
      if (synonyms.contains(normalizedInput)) {
        return UnitMatch(
          name: unit['name'],
          factor: 1, // Factor por defecto; la UI debe respetarle el que ya tenía si existe.
          isConfigurable: true,
        );
      }
    }

    return null; // No reconocido
  }

  /// Función inversa: dado un factor, retorna el nombre de la unidad fija si existe.
  static String? resolveFromFactor(int factor) {
    for (var unit in _fixedUnits) {
      if (unit['factor'] == factor) {
        return unit['name'];
      }
    }
    return null;
  }

  /// Obtiene el factor para una unidad ingresada.
  /// Si es configurable, se puede pasar `currentFactor` para mantenerlo.
  static int getFactorForUnit(String input, {int currentFactor = 1}) {
    UnitMatch? match = resolveUnit(input);
    if (match != null) {
      return match.isConfigurable ? currentFactor : match.factor;
    }
    return currentFactor; // Si no lo reconoce, mantiene el actual
  }

  /// Indica si el texto ingresado corresponde a una unidad del sistema.
  static bool isStandardUnit(String val) {
    return resolveUnit(val) != null;
  }

  /// Retorna la lista de unidades fijas para los chips de sugerencia.
  static List<Map<String, dynamic>> getAllFixedUnits() {
    return _fixedUnits;
  }

  /// Calcula los residuos/sobrantes de stock o detecta faltantes (déficit).
  static StockValidationResult validateStockForUnit({
    required int totalUnitsBase,
    required int presentationFactor,
    required double baseUnitCost,
    required String unitName,
  }) {
    if (totalUnitsBase == 0 || presentationFactor == 0) {
      return StockValidationResult(fullUnits: 0, leftover: 0, deficit: 0, status: StockValidationStatus.empty, costoBaseSobrante: baseUnitCost);
    }

    int fullUnits = totalUnitsBase ~/ presentationFactor;
    int leftover = totalUnitsBase % presentationFactor;
    int deficit = 0;

    StockValidationStatus status = StockValidationStatus.exact;

    if (fullUnits == 0 && leftover > 0) {
      status = StockValidationStatus.deficit;
      deficit = presentationFactor - leftover;
    } else if (leftover > 0) {
      status = StockValidationStatus.hasLeftover;
    }

    return StockValidationResult(
      fullUnits: fullUnits,
      leftover: leftover,
      deficit: deficit,
      status: status,
      costoBaseSobrante: baseUnitCost,
    );
  }

  static String _normalizeText(String text) {
    return text.toLowerCase().trim()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
  }
}
