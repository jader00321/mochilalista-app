import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';

class ProductCategorySuggestion {
  final int productId;
  final String productName;
  final String currentCategoryName;
  final String suggestedCategoryName;
  Category? matchedCategory;
  bool selected;

  ProductCategorySuggestion({
    required this.productId,
    required this.productName,
    required this.currentCategoryName,
    required this.suggestedCategoryName,
    this.matchedCategory,
    this.selected = true,
  });
}

class AutoCategorizationService {
  static const Map<String, List<String>> categoryKeywords = {
    'Lácteos': [
      'leche', 'yogur', 'yogurt', 'queso', 'mantequilla', 'manjar', 'crema de leche',
      'gloria', 'laive', 'pura vida', 'bonle', 'danlac', 'ideal', 'condensada',
    ],
    'Limpieza': [
      'detergente', 'lejia', 'lejía', 'jabon', 'jabón', 'lavavajilla', 'ayudin', 'ayudín',
      'cloro', 'desinfectante', 'poett', 'suavizante', 'ariel', 'ace', 'bolivar', 'bolívar',
      'sapolio', 'patito', 'clorox', 'esponja', 'fibra', 'trapeador', 'ambientador',
    ],
    'Cuidado Personal': [
      'shampoo', 'champu', 'champú', 'acondicionador', 'desodorante', 'pasta dental',
      'kolynos', 'colgate', 'toalla higienica', 'toalla higiénica', 'prestobarba',
      'crema dental', 'nivea', 'rexona', 'pantene', 'sedal', 'head & shoulders',
      'h&s', 'hys', 'protector', 'enjuague', 'algodon', 'algodón', 'papel higienico', 'papel higiénico',
      'huggies', 'pampers', 'pañal', 'pañales', 'talco',
    ],
    'Golosinas y Snacks': [
      'galleta', 'chocolate', 'caramelo', 'chupetin', 'chupetín', 'sublime', 'princesa',
      'margarita', 'morocha', 'coronita', 'oreo', 'casino', 'chizitos', 'papas lays',
      'lays', 'piqueo', 'doritos', 'wafer', 'cuacua', 'cua cua', 'doña pepa',
      'chicle', 'bombom', 'marshmallow', 'gomitas', 'tentacion', 'tentación', 'snack',
    ],
    'Bebidas': [
      'gaseosa', 'agua', 'jugo', 'rehidratante', 'nectar', 'néctar', 'inca kola',
      'coca cola', 'fanta', 'sprite', 'san mateo', 'cielo', 'pulp', 'frugos',
      'gatorade', 'sporade', 'cerveza', 'pisco', 'vino', 'energizante', 'volt',
      'red bull', 'monster', 'san luis', 'aguafiel',
    ],
    'Útiles Escolares': [
      'cuaderno', 'lapicero', 'lapiz', 'lápiz', 'borrador', 'tajador', 'regla',
      'tijera', 'plumon', 'plumón', 'colores', 'cartulina', 'papel bond', 'goma',
      'silicona', 'archivador', 'folder', 'fólder', 'cartuchera', 'plastilina',
      'vinifan', 'standford', 'faber castell', 'pilot', 'artesco', 'atlas',
      'compas', 'compás', 'tempera', 'témpera', 'resaltador', 'corrector',
    ],
    'Abarrotes y Despensa': [
      'atun', 'atún', 'conserva', 'sardina', 'fideo', 'fideos', 'arroz', 'azucar',
      'azúcar', 'aceite', 'sal', 'menestra', 'lenteja', 'frejol', 'fréjol',
      'avena', 'salsa de tomate', 'don victorio', 'molitalia', 'primor', 'fanny',
      'florida', 'dona victorio', 'costeño', 'paisana', 'quaker', 'maicena', 'vinagre',
    ],
    'Panadería': [
      'pan', 'tostada', 'bizcocho', 'queque', 'chancay', 'paneton', 'panetón',
      'bimbo', 'union', 'unión', 'kekito',
    ],
  };

  /// Analiza el nombre de un producto y sugiere una categoría
  static String? suggestCategoryName(String productName) {
    if (productName.trim().isEmpty) return null;
    final lower = productName.toLowerCase();

    for (var entry in categoryKeywords.entries) {
      for (var kw in entry.value) {
        final regex = RegExp(r'\b' + RegExp.escape(kw) + r'\b', caseSensitive: false);
        if (regex.hasMatch(lower)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// Empareja la categoría sugerida con las categorías existentes
  static Category? matchExistingCategory(String suggestedCatName, List<Category> existing) {
    final lowerSuggested = suggestedCatName.toLowerCase().trim();
    for (var cat in existing) {
      final catLower = cat.nombre.toLowerCase().trim();
      if (catLower == lowerSuggested ||
          catLower.contains(lowerSuggested) ||
          lowerSuggested.contains(catLower)) {
        return cat;
      }
    }
    return null;
  }

  /// Obtiene los productos con sugerencias inteligentes para un negocio
  static Future<List<ProductCategorySuggestion>> getSuggestionsForBusiness(
    int negocioId,
    List<Category> existingCategories,
  ) async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT p.id, p.nombre, p.categoria_id, c.nombre as categoria_actual
      FROM productos p
      LEFT JOIN categorias c ON p.categoria_id = c.id
      WHERE p.negocio_id = ?
      ORDER BY p.nombre ASC
    ''', [negocioId]);

    final List<ProductCategorySuggestion> suggestions = [];

    for (var row in rows) {
      final pId = row['id'] as int;
      final pName = row['nombre'] as String;
      final currentCatName = row['categoria_actual'] as String?;
      
      final suggestedCatName = suggestCategoryName(pName);
      if (suggestedCatName != null) {
        final isDifferent = currentCatName == null || 
            currentCatName.toLowerCase().trim() != suggestedCatName.toLowerCase().trim();
        
        if (isDifferent) {
          final matchedCat = matchExistingCategory(suggestedCatName, existingCategories);
          suggestions.add(ProductCategorySuggestion(
            productId: pId,
            productName: pName,
            currentCategoryName: currentCatName ?? 'Sin categoría',
            suggestedCategoryName: suggestedCatName,
            matchedCategory: matchedCat,
          ));
        }
      }
    }

    return suggestions;
  }

  /// Aplica las sugerencias seleccionadas. Crea categorías que no existan si es necesario.
  static Future<int> applySuggestions(
    List<ProductCategorySuggestion> approvedSuggestions,
    InventoryProvider provider,
  ) async {
    if (approvedSuggestions.isEmpty) return 0;
    final db = await LocalDatabase.instance.database;
    int updatedCount = 0;

    // 1. Asegurar que todas las categorías sugeridas existan
    final Map<String, int> categoryNameToId = {};
    for (var cat in provider.categories) {
      categoryNameToId[cat.nombre.toLowerCase().trim()] = cat.id;
    }

    for (var s in approvedSuggestions) {
      if (!s.selected) continue;
      final key = s.suggestedCategoryName.toLowerCase().trim();
      if (!categoryNameToId.containsKey(key)) {
        final newId = await provider.createCategory(s.suggestedCategoryName);
        if (newId != null) {
          categoryNameToId[key] = newId;
        }
      }
    }

    // 2. Aplicar la actualización en la BD
    await db.transaction((txn) async {
      for (var s in approvedSuggestions) {
        if (!s.selected) continue;
        final key = s.suggestedCategoryName.toLowerCase().trim();
        final targetCatId = categoryNameToId[key] ?? s.matchedCategory?.id;
        if (targetCatId != null) {
          await txn.update(
            'productos',
            {'categoria_id': targetCatId},
            where: 'id = ?',
            whereArgs: [s.productId],
          );
          updatedCount++;
        }
      }
    });

    // 3. Recargar inventario para reflejar cambios
    await provider.loadInventory(reset: true);

    return updatedCount;
  }
}
