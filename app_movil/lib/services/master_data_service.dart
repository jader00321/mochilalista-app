import '../database/local_db.dart';
import '../models/category_model.dart';
import '../models/brand_model.dart';
import '../models/provider_model.dart';
import 'image_service.dart';

class MasterDataService {
  int? _negocioId;
  
  void updateContext(int? negocioId) => _negocioId = negocioId;
  
  final dbHelper = LocalDatabase.instance;

  Future<Map<String, dynamic>?> fetchAllMasterData(bool showAll) async {
    if (_negocioId == null) return null;
    try {
      final db = await dbHelper.database;
      
      String whereClause = showAll ? "negocio_id = ?" : "negocio_id = ? AND activo = 1";
      List<dynamic> args = [_negocioId];
      
      // 🔥 REPLICACIÓN EXACTA DE PYTHON: Subconsultas para el conteo de productos
      final catsData = await db.rawQuery('''
        SELECT c.*, 
        (SELECT COUNT(*) FROM productos p WHERE p.categoria_id = c.id AND p.negocio_id = c.negocio_id) as products_count
        FROM categorias c WHERE $whereClause
      ''', args);

      final brandsData = await db.rawQuery('''
        SELECT m.*, 
        (SELECT COUNT(*) FROM productos p WHERE p.marca_id = m.id AND p.negocio_id = m.negocio_id) as products_count
        FROM marcas m WHERE $whereClause
      ''', args);

      final provsData = await db.rawQuery('''
        SELECT pv.*, 
        (SELECT COUNT(*) FROM presentaciones_producto pp WHERE pp.proveedor_id = pv.id) as products_count
        FROM proveedores pv WHERE $whereClause
      ''', args);

      return {
        'categories': catsData.map((e) => Category.fromJson(e)).toList(),
        'brands': brandsData.map((e) => Brand.fromJson(e)).toList(),
        'providers': provsData.map((e) => ProviderModel.fromJson(e)).toList(),
      };
    } catch (e) { print("Error MasterData: $e"); }
    return null;
  }

  Future<int?> createCategory(String nombre, String? descripcion) async {
    if (_negocioId == null) return null;
    final db = await dbHelper.database;
    return await db.insert('categorias', {
      'negocio_id': _negocioId, 
      'nombre': nombre, 
      'descripcion': descripcion, 
      'activo': 1
    });
  }

  Future<bool> updateCategory(int id, String nombre, String? descripcion, bool? activo) async {
    final db = await dbHelper.database;
    final Map<String, dynamic> body = {"nombre": nombre};
    if (descripcion != null) body["descripcion"] = descripcion;
    if (activo != null) body["activo"] = activo ? 1 : 0;
    
    int rows = await db.update('categorias', body, where: 'id = ?', whereArgs: [id]);
    return rows > 0;
  }

  Future<String?> deleteCategory(int id) async {
    final db = await dbHelper.database;
    try {
      final pCountRows = await db.query('productos', columns: ['id'], where: 'categoria_id = ?', whereArgs: [id]);
      if (pCountRows.isNotEmpty) {
        return "No se puede eliminar porque hay ${pCountRows.length} productos usándola.";
      }
      await db.delete('categorias', where: 'id = ?', whereArgs: [id]);
      return null;
    } catch (e) { return "Error al eliminar la categoría."; }
  }

  Future<int?> createBrand(String nombre, String? urlImagen) async {
    if (_negocioId == null) return null;
    final db = await dbHelper.database;
    String? finalUrl = await ImageService.processAndSaveImage(urlImagen); 
    return await db.insert('marcas', {
      'negocio_id': _negocioId, 
      'nombre': nombre, 
      'imagen_url': finalUrl, 
      'activo': 1
    });
  }

  Future<bool> updateBrand(int id, String nombre, String? urlImagen, bool? activo) async {
    final db = await dbHelper.database;
    final Map<String, dynamic> body = {"nombre": nombre};
    if (activo != null) body["activo"] = activo ? 1 : 0;
    
    if (urlImagen != null) {
      final oldData = await db.query('marcas', columns: ['imagen_url'], where: 'id = ?', whereArgs: [id]);
      String? oldPath = oldData.isNotEmpty ? oldData.first['imagen_url'] as String? : null;
      body["imagen_url"] = await ImageService.processAndSaveImage(urlImagen, oldImagePath: oldPath);
    }
    
    int rows = await db.update('marcas', body, where: 'id = ?', whereArgs: [id]);
    return rows > 0;
  }

  Future<String?> deleteBrand(int id) async {
    final db = await dbHelper.database;
    try {
      final pCountRows = await db.query('productos', columns: ['id'], where: 'marca_id = ?', whereArgs: [id]);
      if (pCountRows.isNotEmpty) {
        return "No se puede eliminar porque hay ${pCountRows.length} productos usándola.";
      }
      final oldData = await db.query('marcas', columns: ['imagen_url'], where: 'id = ?', whereArgs: [id]);
      await db.delete('marcas', where: 'id = ?', whereArgs: [id]);
      if (oldData.isNotEmpty && oldData.first['imagen_url'] != null) {
        await ImageService.deleteLocalImage(oldData.first['imagen_url'] as String);
      }
      return null;
    } catch (e) { return "Error al eliminar la marca."; }
  }

  Future<int?> createProvider(String nombre, String? ruc, String? contacto, String? telefono, String? correo) async {
    if (_negocioId == null) return null;
    final db = await dbHelper.database;
    return await db.insert('proveedores', {
      'negocio_id': _negocioId, 
      'nombre_empresa': nombre, 
      'ruc': ruc, 
      'contacto_nombre': contacto, 
      'telefono': telefono, 
      'email': correo, 
      'activo': 1, 
      'fecha_creacion': DateTime.now().toIso8601String()
    });
  }

  Future<bool> updateProvider(int id, String nombre, String? ruc, String? contacto, String? telefono, String? correo, bool? activo) async {
    final db = await dbHelper.database;
    final Map<String, dynamic> body = {"nombre_empresa": nombre};
    if (ruc != null) body["ruc"] = ruc;
    if (contacto != null) body["contacto_nombre"] = contacto;
    if (telefono != null) body["telefono"] = telefono;
    if (correo != null) body["email"] = correo;
    if (activo != null) body["activo"] = activo ? 1 : 0;
    
    int rows = await db.update('proveedores', body, where: 'id = ?', whereArgs: [id]);
    return rows > 0;
  }

  Future<String?> deleteProvider(int id) async {
    final db = await dbHelper.database;
    try {
      final pCountRows = await db.query('presentaciones_producto', columns: ['id'], where: 'proveedor_id = ?', whereArgs: [id]);
      if (pCountRows.isNotEmpty) {
        return "No se puede eliminar porque hay ${pCountRows.length} presentaciones usando este proveedor.";
      }
      await db.delete('proveedores', where: 'id = ?', whereArgs: [id]);
      return null;
    } catch (e) { return "Error al eliminar el proveedor."; }
  }
}