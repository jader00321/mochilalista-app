import '../database/local_db.dart';
import '../models/user_model.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'image_service.dart';

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
  }) async {
    final db = await dbHelper.database;
    int userId = 0;

    try {
      await db.transaction((txn) async {
        userId = await txn.insert('usuarios', {
          'nombre_completo': nombreDueno,
          'email': 'local_${DateTime.now().millisecondsSinceEpoch}@offline.com', 
          'password_hash': 'offline_secured', 
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
          'informacion_pago': '{"moneda": "$moneda"}',
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

  Future<UserModel> updateProfile(int userId, String nombre, String telefono) async {
    final db = await dbHelper.database;
    await db.update('usuarios', {'nombre_completo': nombre, 'telefono': telefono}, where: 'id = ?', whereArgs: [userId]);
    return await getUserProfile(userId);
  }

  Future<BusinessModel> createBusiness(int userId, String name, String ruc, String address, String? paymentInfo, double? latitud, double? longitud, String? printerConfig) async {
    final db = await dbHelper.database;
    int bizId = await db.insert('negocios', {
      'nombre_comercial': name, 'ruc': ruc, 'direccion': address, 'informacion_pago': paymentInfo, 
      'latitud': latitud, 'longitud': longitud, 'configuracion_impresora': printerConfig, 'id_dueno': userId,
      'fecha_creacion': DateTime.now().toIso8601String()
    });
    final biz = await db.query('negocios', where: 'id = ?', whereArgs: [bizId]);
    return BusinessModel.fromJson(biz.first);
  }

  Future<BusinessModel> updateBusiness(int businessId, String name, String ruc, String address, String? paymentInfo, double? latitud, double? longitud, String? printerConfig, {bool clearLogo = false}) async {
    final db = await dbHelper.database;
    Map<String, dynamic> updateData = {
      'nombre_comercial': name, 'ruc': ruc, 'direccion': address, 'informacion_pago': paymentInfo, 
      'latitud': latitud, 'longitud': longitud, 'configuracion_impresora': printerConfig
    };
    
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

  Future<bool> deleteLocalProfile(int userId) async {
    try {
      final db = await dbHelper.database;
      // PRAGMA foreign_keys = ON borrará negocios, productos y ventas en cascada.
      int count = await db.delete('usuarios', where: 'id = ?', whereArgs: [userId]);
      return count > 0;
    } catch (e) {
      debugPrint("Error borrando perfil local: $e");
      throw Exception("No se pudo eliminar el perfil debido a un bloqueo en la base de datos.");
    }
  }
}