import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_constants.dart';
import '../models/category_model.dart';
import '../models/brand_model.dart';
import '../models/provider_model.dart';
import 'image_service.dart';

class MasterDataService {
  String? _token;
  void updateToken(String? token) => _token = token;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json', 
    'Authorization': 'Bearer $_token'
  };

  // --- OBTENER TODOS LOS MAESTROS ---
  Future<Map<String, dynamic>?> fetchAllMasterData(bool showAll) async {
    if (_token == null) return null;
    try {
      final q = showAll ? "" : "?solo_activos=true";
      final results = await Future.wait([
        http.get(Uri.parse('${ApiConstants.baseUrl}/categories/$q'), headers: _headers),
        http.get(Uri.parse('${ApiConstants.baseUrl}/brands/$q'), headers: _headers),
        http.get(Uri.parse('${ApiConstants.baseUrl}/providers/$q'), headers: _headers),
      ]);

      if (results[0].statusCode == 200 && results[1].statusCode == 200 && results[2].statusCode == 200) {
        return {
          'categories': (json.decode(utf8.decode(results[0].bodyBytes)) as List).map((e) => Category.fromJson(e)).toList(),
          'brands': (json.decode(utf8.decode(results[1].bodyBytes)) as List).map((e) => Brand.fromJson(e)).toList(),
          'providers': (json.decode(utf8.decode(results[2].bodyBytes)) as List).map((e) => ProviderModel.fromJson(e)).toList(),
        };
      }
    } catch (e) { print("Error MasterData: $e"); }
    return null;
  }

  // --- CATEGORÍAS ---
  Future<int?> createCategory(String nombre, String? descripcion) async {
    final res = await http.post(Uri.parse('${ApiConstants.baseUrl}/categories/'), headers: _headers, body: json.encode({"nombre": nombre, "descripcion": descripcion, "activo": true}));
    if (res.statusCode == 200 || res.statusCode == 201) return Category.fromJson(json.decode(res.body)).id;
    return null;
  }

  Future<bool> updateCategory(int id, String nombre, String? descripcion, bool? activo) async {
    // 🔥 CORRECCIÓN: Tipado explícito <String, dynamic>
    final Map<String, dynamic> body = {"nombre": nombre};
    if (descripcion != null) body["descripcion"] = descripcion;
    if (activo != null) body["activo"] = activo;
    final res = await http.patch(Uri.parse('${ApiConstants.baseUrl}/categories/$id'), headers: _headers, body: json.encode(body));
    return res.statusCode == 200;
  }

  Future<String?> deleteCategory(int id) async {
    final res = await http.delete(Uri.parse('${ApiConstants.baseUrl}/categories/$id'), headers: _headers);
    if (res.statusCode == 200) return null; 
    return json.decode(res.body)['detail'] ?? "Error desconocido";
  }

  // --- MARCAS ---
  Future<int?> createBrand(String nombre, String? urlImagen) async {
    String? finalUrl = await ImageService.processAndUploadImage(urlImagen, _token!);
    final res = await http.post(Uri.parse('${ApiConstants.baseUrl}/brands/'), headers: _headers, body: json.encode({"nombre": nombre, "imagen_url": finalUrl, "activo": true}));
    if (res.statusCode == 200 || res.statusCode == 201) return Brand.fromJson(json.decode(res.body)).id;
    return null;
  }

  Future<bool> updateBrand(int id, String nombre, String? urlImagen, bool? activo) async {
    // 🔥 CORRECCIÓN: Tipado explícito <String, dynamic>
    final Map<String, dynamic> body = {"nombre": nombre};
    if (activo != null) body["activo"] = activo;
    if (urlImagen != null) body["imagen_url"] = await ImageService.processAndUploadImage(urlImagen, _token!);
    final res = await http.patch(Uri.parse('${ApiConstants.baseUrl}/brands/$id'), headers: _headers, body: json.encode(body));
    return res.statusCode == 200;
  }

  Future<String?> deleteBrand(int id) async {
    final res = await http.delete(Uri.parse('${ApiConstants.baseUrl}/brands/$id'), headers: _headers);
    if (res.statusCode == 200) return null;
    return json.decode(res.body)['detail'];
  }

  // --- PROVEEDORES ---
  Future<int?> createProvider(String nombre, String? ruc, String? contacto, String? telefono, String? correo) async {
    final res = await http.post(Uri.parse('${ApiConstants.baseUrl}/providers/'), headers: _headers, body: json.encode({
      "nombre_empresa": nombre, "ruc": ruc, "contacto_nombre": contacto, "telefono": telefono, "email": correo, "activo": true
    }));
    if (res.statusCode == 200 || res.statusCode == 201) return ProviderModel.fromJson(json.decode(res.body)).id;
    return null;
  }

  Future<bool> updateProvider(int id, String nombre, String? ruc, String? contacto, String? telefono, String? correo, bool? activo) async {
    // 🔥 CORRECCIÓN: Tipado explícito <String, dynamic>
    final Map<String, dynamic> body = {"nombre_empresa": nombre};
    if (ruc != null) body["ruc"] = ruc;
    if (contacto != null) body["contacto_nombre"] = contacto;
    if (telefono != null) body["telefono"] = telefono;
    if (correo != null) body["email"] = correo;
    if (activo != null) body["activo"] = activo;
    final res = await http.patch(Uri.parse('${ApiConstants.baseUrl}/providers/$id'), headers: _headers, body: json.encode(body));
    return res.statusCode == 200;
  }

  Future<String?> deleteProvider(int id) async {
    final res = await http.delete(Uri.parse('${ApiConstants.baseUrl}/providers/$id'), headers: _headers);
    if (res.statusCode == 200) return null;
    return json.decode(res.body)['detail'];
  }
}