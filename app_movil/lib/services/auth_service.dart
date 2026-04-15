import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; 
import 'package:mime/mime.dart';               
import '../../config/api_constants.dart';
import '../models/user_model.dart';

class AuthService {
  
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/login/access-token');
    try {
      final response = await http.post(url, body: {'username': email, 'password': password}).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return json.decode(response.body);
      if (response.statusCode == 404) throw Exception("Este correo electrónico no está registrado.");
      if (response.statusCode == 401) throw Exception("La contraseña es incorrecta. Inténtalo de nuevo.");
      if (response.statusCode == 403) throw Exception("Esta cuenta se encuentra desactivada.");
      throw Exception("Las credenciales ingresadas no son válidas.");
    } catch (e) {
      String errorMessage = e.toString().replaceAll("Exception: ", "").trim();
      if (errorMessage.contains("SocketException")) throw Exception("No hay conexión a internet.");
      throw Exception(errorMessage);
    }
  }

  Future<UserModel> getUserProfile(String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/users/me');
    try {
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return UserModel.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      throw Exception("Tu sesión ha expirado.");
    } catch (e) { throw Exception("No pudimos cargar tu perfil."); }
  }

  // 🔥 NUEVO: Obtener los datos del negocio en el que estás actualmente (Cliente o Trabajador)
  Future<BusinessModel?> getCurrentBusiness(String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/business/current');
    try {
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return BusinessModel.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      return null;
    } catch (e) { return null; }
  }

  Future<List<Map<String, dynamic>>> getWorkspaces(String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/users/me/workspaces');
    try {
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) { return []; }
  }

  Future<String?> switchContext(String token, int negocioId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/auth/switch-context/$negocioId');
    try {
      final response = await http.post(url, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['access_token'];
      }
      return null;
    } catch (e) { return null; }
  }

  Future<UserModel> register(String nombre, String email, String password, String negocio, String telefono) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/users/register');
    final body = {'nombre_completo': nombre, 'email': email, 'password': password, 'nombre_negocio': negocio.isNotEmpty ? negocio : null, 'telefono': telefono.isNotEmpty ? telefono : null};
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: json.encode(body)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 || response.statusCode == 201) return UserModel.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      if (response.statusCode == 400 || response.statusCode == 409) {
        try {
            final error = json.decode(response.body);
            if (error['detail'].toString().toLowerCase().contains("already registered")) throw Exception("Este correo electrónico ya tiene una cuenta.");
            throw Exception("No pudimos crear la cuenta. Verifica tus datos.");
        } catch (_) { throw Exception("Error al intentar registrar el usuario."); }
      }
      throw Exception("Error del servidor (${response.statusCode}).");
    } catch (e) { throw Exception(e.toString().replaceAll("Exception: ", "").trim()); }
  }

  Future<bool> joinBusiness(String token, String codigo) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/users/join-business?codigo_invitacion=$codigo');
    try {
      final response = await http.post(url, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return true;
      try {
        final error = json.decode(response.body);
        throw Exception(error['detail']);
      } catch (_) { throw Exception("Código inválido o expirado."); }
    } catch (e) { throw Exception(e.toString().replaceAll("Exception: ", "").trim()); }
  }

  Future<UserModel> updateProfile(String token, String nombre, String telefono) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/users/me');
    final body = {'nombre_completo': nombre, 'telefono': telefono};
    try {
      final response = await http.put(url, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: json.encode(body)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return UserModel.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      try {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? "No se pudo guardar la información del perfil.");
      } catch (_) { throw Exception("Error del servidor al actualizar perfil (${response.statusCode})."); }
    } catch (e) { throw Exception(e.toString().replaceAll("Exception: ", "").trim()); }
  }

  Future<void> changePassword(String token, String currentPass, String newPass) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/users/change-password');
    final body = {'current_password': currentPass, 'new_password': newPass};
    try {
      final response = await http.post(url, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: json.encode(body)).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        try {
            final error = json.decode(response.body);
            final detail = error['detail'].toString().toLowerCase();
            
            if (detail.contains("incorrect password") || detail.contains("incorrecta")) {
               throw Exception("La contraseña actual es incorrecta. Verifícala e intenta de nuevo.");
            }
            throw Exception(error['detail'] ?? "No se pudo cambiar la contraseña.");
        } catch (_) { 
            throw Exception("La contraseña actual no coincide. Por favor, revisa tus datos."); 
        }
      }
    } catch (e) { throw Exception(e.toString().replaceAll("Exception: ", "").trim()); }
  }

  // 🔥 NUEVA FUNCIÓN: CREAR NEGOCIO DESDE CERO
  Future<BusinessModel> createBusiness(String token, String name, String ruc, String address, String? paymentInfo, double? latitud, double? longitud, String? printerConfig) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/business/'); // POST a la raíz
    final Map<String, dynamic> body = {
      'nombre_comercial': name, 'ruc': ruc, 'direccion': address, 'informacion_pago': paymentInfo, 'latitud': latitud, 'longitud': longitud, 'configuracion_impresora': printerConfig
    };

    try {
      final response = await http.post(url, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: json.encode(body)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 || response.statusCode == 201) return BusinessModel.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      try {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? "Hubo un problema al crear.");
      } catch (_) { throw Exception("Error del servidor (${response.statusCode})."); }
    } catch (e) { throw Exception(e.toString().replaceAll("Exception: ", "").trim()); }
  }

  // 🔥 ACTUALIZADA: SOLO ACTUALIZA EL NEGOCIO ACTUAL
  Future<BusinessModel> updateBusiness(String token, String name, String ruc, String address, String? paymentInfo, double? latitud, double? longitud, String? printerConfig, {bool clearLogo = false}) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/business/current'); // PUT a /current
    final Map<String, dynamic> body = {
      'nombre_comercial': name, 'ruc': ruc, 'direccion': address, 'informacion_pago': paymentInfo, 'latitud': latitud, 'longitud': longitud, 'configuracion_impresora': printerConfig
    };
    
    if (clearLogo) body['logo_url'] = null; 

    try {
      final response = await http.put(url, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: json.encode(body)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 || response.statusCode == 201) return BusinessModel.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      try {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? "Hubo un problema al actualizar.");
      } catch (_) { throw Exception("Error del servidor (${response.statusCode})."); }
    } catch (e) { throw Exception(e.toString().replaceAll("Exception: ", "").trim()); }
  }

  Future<BusinessModel> uploadLogo(String token, File imageFile) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/business/upload-logo');
    try {
      String mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
      var type = mimeType.split('/')[0];
      var subType = mimeType.split('/')[1];

      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path, contentType: MediaType(type, subType)));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return BusinessModel.fromJson(data);
      } else {
        throw Exception("No se pudo procesar la imagen. Intenta con otra.");
      }
    } catch (e) { throw Exception(e.toString().replaceAll("Exception: ", "").trim()); }
  }
}