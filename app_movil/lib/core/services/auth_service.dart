import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:app_movil/core/services/image_service.dart';

class AuthService {
  final dbHelper = LocalDatabase.instance;

  Future<List<UserModel>> getLocalProfiles() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> users = await db.query('usuarios', where: 'activo = 1');
      
      List<UserModel> profiles = [];
      for (var u in users) {
        var userMap = Map<String, dynamic>.from(u);
        final negocios = await db.query('negocios', where: 'id_dueno = ?', whereArgs: [u['id']], limit: 1);
        if (negocios.isNotEmpty) {
          userMap['negocio_data'] = negocios.first;
        }
        profiles.add(UserModel.fromJson(userMap));
      }
      return profiles;
    } catch (e) {
      debugPrint("Error leyendo perfiles locales: $e");
      throw Exception("No se pudieron cargar los perfiles. Intenta reiniciar la app.");
    }
  }

  Future<UserModel> getUserProfile(int userId) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> users = await db.query('usuarios', where: 'id = ?', whereArgs: [userId], limit: 1);
    if (users.isEmpty) throw Exception("El perfil de usuario ya no existe o fue eliminado.");
    
    var userMap = Map<String, dynamic>.from(users.first);
    final negocios = await db.query('negocios', where: 'id_dueno = ?', whereArgs: [userId], limit: 1);
    if (negocios.isNotEmpty) {
      userMap['negocio_data'] = negocios.first;
    }
    return UserModel.fromJson(userMap);
  }

  Future<UserModel> registerLocalProfile({
    required String nombreDueno,
    required String telefono,
    required String nombreNegocio,
    required String direccion,
    String? logoPath,
    required String moneda,
    String? informacionPago,
  }) async {
    final db = await dbHelper.database;
    int userId = 0;

    try {
      await db.transaction((txn) async {
        userId = await txn.insert('usuarios', {
          'nombre_completo': nombreDueno,
          'email': null, 
          'password_hash': null, 
          'telefono': telefono,
          'activo': 1,
          'fecha_creacion': DateTime.now().toIso8601String()
        });

        String? finalLogoPath;
        if (logoPath != null && logoPath.isNotEmpty) {
          finalLogoPath = await ImageService.processAndSaveImage(logoPath);
        }

        await txn.insert('negocios', {
          'nombre_comercial': nombreNegocio,
          'direccion': direccion,
          'logo_url': finalLogoPath,
          'moneda': moneda,
          'informacion_pago': informacionPago,
          'id_dueno': userId,
          'fecha_creacion': DateTime.now().toIso8601String()
        });
      });

      return await getUserProfile(userId);
    } catch (e) {
      debugPrint("Error registrando perfil: $e");
      throw Exception("Ocurrió un error al crear tu negocio. Verifica los datos o el almacenamiento.");
    }
  }

  Future<UserModel> updateProfile(int userId, String nombre, String telefono, {String? email}) async {
    final db = await dbHelper.database;
    final updateData = <String, dynamic>{
      'nombre_completo': nombre, 
      'telefono': telefono,
    };
    if (email != null) updateData['email'] = email.isEmpty ? null : email;
    await db.update('usuarios', updateData, where: 'id = ?', whereArgs: [userId]);
    return await getUserProfile(userId);
  }

  Future<BusinessModel> createBusiness(int userId, String name, String ruc, String address, String? paymentInfo, double? latitud, double? longitud, String? printerConfig, {String moneda = 'S/ (Soles)'}) async {
    final db = await dbHelper.database;
    int bizId = await db.insert('negocios', {
      'nombre_comercial': name, 'ruc': ruc, 'direccion': address, 'informacion_pago': paymentInfo, 'moneda': moneda,
      'latitud': latitud, 'longitud': longitud, 'configuracion_impresora': printerConfig, 'id_dueno': userId,
      'fecha_creacion': DateTime.now().toIso8601String()
    });
    final biz = await db.query('negocios', where: 'id = ?', whereArgs: [bizId]);
    return BusinessModel.fromJson(biz.first);
  }

  Future<BusinessModel> updateBusiness(int businessId, String name, String ruc, String address, String? paymentInfo, double? latitud, double? longitud, String? printerConfig, {bool clearLogo = false, String? moneda}) async {
    final db = await dbHelper.database;
    Map<String, dynamic> updateData = {
      'nombre_comercial': name, 'ruc': ruc, 'direccion': address, 'informacion_pago': paymentInfo, 
      'latitud': latitud, 'longitud': longitud, 'configuracion_impresora': printerConfig
    };
    if (moneda != null) updateData['moneda'] = moneda;
    
    if (clearLogo) {
      final oldBiz = await db.query('negocios', columns: ['logo_url'], where: 'id = ?', whereArgs: [businessId]);
      if (oldBiz.isNotEmpty && oldBiz.first['logo_url'] != null) {
        await ImageService.deleteLocalImage(oldBiz.first['logo_url'] as String);
      }
      updateData['logo_url'] = null;
    }

    await db.update('negocios', updateData, where: 'id = ?', whereArgs: [businessId]);
    final biz = await db.query('negocios', where: 'id = ?', whereArgs: [businessId]);
    return BusinessModel.fromJson(biz.first);
  }

  Future<BusinessModel> uploadLogo(int businessId, File imageFile) async {
    final db = await dbHelper.database;
    final oldBiz = await db.query('negocios', columns: ['logo_url'], where: 'id = ?', whereArgs: [businessId]);
    String? oldLogo = oldBiz.isNotEmpty ? oldBiz.first['logo_url'] as String? : null;

    String? finalPath = await ImageService.processAndSaveImage(imageFile.path, oldImagePath: oldLogo);
    await db.update('negocios', {'logo_url': finalPath}, where: 'id = ?', whereArgs: [businessId]);
    
    final biz = await db.query('negocios', where: 'id = ?', whereArgs: [businessId]);
    return BusinessModel.fromJson(biz.first);
  }

  Future<bool> deleteLocalProfileWithProgress(int userId, Function(String, double) onProgress) async {
    try {
      final db = await dbHelper.database;
      
      // Obtener todos los negocios del usuario
      final negocios = await db.query('negocios', columns: ['id'], where: 'id_dueno = ?', whereArgs: [userId]);
      final List<int> negocioIds = negocios.map((n) => n['id'] as int).toList();

      for (int i = 0; i < negocioIds.length; i++) {
        int negocioId = negocioIds[i];
        
        onProgress('Borrando operaciones (Nivel 3 - Hojas)...', 0.2);
        await Future.delayed(const Duration(milliseconds: 300));
        await db.delete('pagos', where: 'negocio_id = ?', whereArgs: [negocioId]);
        await db.delete('notificaciones', where: 'negocio_id = ?', whereArgs: [negocioId]);
        await db.delete('stock_ledger', where: 'negocio_id = ?', whereArgs: [negocioId]);
        await db.delete('reglas_promocion', where: 'campana_id IN (SELECT id FROM campanas_promocionales WHERE negocio_id = ?)', whereArgs: [negocioId]);
        await db.delete('items_paquete', where: 'paquete_id IN (SELECT id FROM paquetes WHERE negocio_id = ?)', whereArgs: [negocioId]);
        await db.delete('venta_items', where: 'venta_id IN (SELECT id FROM ventas WHERE negocio_id = ?)', whereArgs: [negocioId]);
        await db.delete('smart_quotation_items', where: 'quotation_id IN (SELECT id FROM smart_quotations WHERE negocio_id = ?)', whereArgs: [negocioId]);
        await db.delete('presentaciones_producto', where: 'producto_id IN (SELECT id FROM productos WHERE negocio_id = ?)', whereArgs: [negocioId]);
        
        onProgress('Borrando operaciones (Nivel 2 - Ramas)...', 0.4);
        await Future.delayed(const Duration(milliseconds: 300));
        await db.delete('ventas', where: 'negocio_id = ?', whereArgs: [negocioId]);
        await db.delete('smart_quotations', where: 'negocio_id = ?', whereArgs: [negocioId]);
        await db.delete('paquetes', where: 'negocio_id = ?', whereArgs: [negocioId]);
        await db.delete('campanas_promocionales', where: 'negocio_id = ?', whereArgs: [negocioId]);
        await db.delete('business_snapshots', where: 'negocio_id = ?', whereArgs: [negocioId]);
        await db.delete('codigos_acceso_negocio', where: 'negocio_id = ?', whereArgs: [negocioId]);
        await db.delete('productos', where: 'negocio_id = ?', whereArgs: [negocioId]);
        
        onProgress('Borrando inventario y catálogos (Nivel 1)...', 0.6);
        await Future.delayed(const Duration(milliseconds: 300));
        await db.delete('categorias', where: 'negocio_id = ?', whereArgs: [negocioId]);
        await db.delete('marcas', where: 'negocio_id = ?', whereArgs: [negocioId]);
        await db.delete('proveedores', where: 'negocio_id = ?', whereArgs: [negocioId]);
        
        onProgress('Borrando clientes y configuraciones...', 0.8);
        await Future.delayed(const Duration(milliseconds: 300));
        await db.delete('clientes', where: 'negocio_id = ?', whereArgs: [negocioId]);
        await db.delete('facturas_carga', where: 'negocio_id = ?', whereArgs: [negocioId]);
        await db.delete('negocio_usuario', where: 'negocio_id = ?', whereArgs: [negocioId]);
      }

      onProgress('Eliminando perfil de usuario...', 0.9);
      await Future.delayed(const Duration(milliseconds: 300));
      // Limpiar historial de productos del usuario para evitar huérfanos
      await db.delete('product_history', where: 'usuario_id = ?', whereArgs: [userId]);
      int count = await db.delete('usuarios', where: 'id = ?', whereArgs: [userId]);
      
      onProgress('Limpieza finalizada.', 1.0);
      await Future.delayed(const Duration(milliseconds: 300));
      return count > 0;
    } catch (e) {
      debugPrint("Error borrando perfil local: $e");
      throw Exception("No se pudo eliminar el perfil debido a un bloqueo en la base de datos.");
    }
  }
}