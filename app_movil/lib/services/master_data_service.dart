import '../database/local_db.dart';
import '../models/category_model.dart';
import '../models/brand_model.dart';
import '../models/provider_model.dart';
import 'image_service.dart';

class MasterDataService {
  int? _negocioId;
  
  // 🔥 Reemplaza a updateToken
  void updateContext(int? negocioId) => _negocioId = negocioId;
  
  final dbHelper = LocalDatabase.instance;

  Future<Map<String, dynamic>?> fetchAllMasterData(bool showAll) async {
    if (_negocioId == null) return null;
    try {
      final db = await dbHelper.database;
      
      String whereClause = showAll ? "negocio_id = ?" : "negocio_id = ? AND activo = 1";
      List<dynamic> args = [_negocioId];
      
      final catsData = await db.query('categorias', where: whereClause, whereArgs: args);
      final brandsData = await db.query('marcas', where: whereClause, whereArgs: args);
      final provsData = await db.query('proveedores', where: whereClause, whereArgs: args);

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
      await db.delete('categorias', where: 'id = ?', whereArgs: [id]);
      return null;
    } catch (e) { return "No se puede eliminar porque hay productos usándola."; }
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
      final oldData = await db.query('marcas', columns: ['imagen_url'], where: 'id = ?', whereArgs: [id]);
      await db.delete('marcas', where: 'id = ?', whereArgs: [id]);
      if (oldData.isNotEmpty && oldData.first['imagen_url'] != null) {
        await ImageService.deleteLocalImage(oldData.first['imagen_url'] as String);
      }
      return null;
    } catch (e) { return "No se puede eliminar porque hay productos usándola."; }
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
      await db.delete('proveedores', where: 'id = ?', whereArgs: [id]);
      return null;
    } catch (e) { return "No se puede eliminar porque hay productos usando este proveedor."; }
  }
}