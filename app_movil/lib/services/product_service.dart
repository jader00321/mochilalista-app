import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_constants.dart';
import '../models/product_model.dart';
import '../models/inventory_wrapper.dart';
import 'image_service.dart';

class ProductService {
  String? _token;
  void updateToken(String? token) => _token = token;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json', 
    'Authorization': 'Bearer $_token'
  };

  Future<List<InventoryWrapper>?> fetchInventory(Map<String, dynamic> queryParams) async {
    if (_token == null) return null;
    try {
      final uriBuilder = Uri.parse('${ApiConstants.baseUrl}/products/');
      final uri = uriBuilder.replace(queryParameters: queryParams);
      
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((itemJson) => InventoryWrapper(
          product: Product.fromJson(itemJson['product']),
          presentation: ProductPresentation.fromJson(itemJson['presentation'])
        )).toList();
      }
    } catch (e) { print("Error Fetch Inventory: $e"); }
    return null;
  }

  Future<Product?> fetchProductById(int productId) async {
    if (_token == null) return null;
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/products/$productId');
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        return Product.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      }
    } catch (e) { print("Error Fetching Product: $e"); }
    return null;
  }

  Future<bool> deleteProduct(int id) async {
    final res = await http.delete(Uri.parse('${ApiConstants.baseUrl}/products/$id'), headers: _headers);
    return res.statusCode == 200;
  }

  Future<bool> createFullProduct({
    required String nombre, int? marcaId, required int categoriaId, int? proveedorId, 
    required String estado, String? descripcion, String? imagenUrl, String? codigoBarras, 
    required List<ProductPresentation> presentaciones
  }) async {
    try {
      String? finalParentUrl = await ImageService.processAndUploadImage(imagenUrl, _token!);
      List<Map<String, dynamic>> processedPresentations = [];
      for (var pres in presentaciones) {
        String? finalPresUrl = await ImageService.processAndUploadImage(pres.imagenUrl, _token!);
        var presJson = pres.toJson();
        presJson['imagen_url'] = finalPresUrl;
        processedPresentations.add(presJson);
      }

      final body = json.encode({
        "nombre": nombre, "marca_id": marcaId, "categoria_id": categoriaId, 
        "proveedor_id": proveedorId, "estado": estado, "descripcion": descripcion, 
        "imagen_url": finalParentUrl, "codigo_barras": codigoBarras, 
        "presentaciones": processedPresentations 
      });
      final res = await http.post(Uri.parse('${ApiConstants.baseUrl}/products/full'), headers: _headers, body: body);
      return res.statusCode == 200;
    } catch (e) { return false; }
  }

  Future<bool> editFullProduct({
    required int productId, required String nombre, int? marcaId, required int categoriaId, 
    int? proveedorId, required String estado, String? descripcion, String? imagenUrl, String? codigoBarras, 
    required List<ProductPresentation> presentaciones, required List<int> idsToDelete
  }) async {
    try {
      String? finalParentUrl = await ImageService.processAndUploadImage(imagenUrl, _token!);

      await http.patch(Uri.parse('${ApiConstants.baseUrl}/products/$productId'), headers: _headers, body: json.encode({
        "nombre": nombre, "marca_id": marcaId, "categoria_id": categoriaId, "proveedor_id": proveedorId,
        "estado": estado, "descripcion": descripcion, "imagen_url": finalParentUrl, "codigo_barras": codigoBarras
      }));
      
      for (int id in idsToDelete) {
        await http.delete(Uri.parse('${ApiConstants.baseUrl}/products/presentations/$id'), headers: _headers);
      }
      
      for (var pres in presentaciones) {
        String? finalPresUrl = await ImageService.processAndUploadImage(pres.imagenUrl, _token!);
        var presJson = pres.toJson();
        presJson['imagen_url'] = finalPresUrl; 

        if (pres.id != null) {
          await http.patch(Uri.parse('${ApiConstants.baseUrl}/products/presentations/${pres.id}'), headers: _headers, body: json.encode(presJson));
        } else {
          await http.post(Uri.parse('${ApiConstants.baseUrl}/products/$productId/presentations'), headers: _headers, body: json.encode(presJson));
        }
      }
      return true;
    } catch (e) { return false; }
  }

  Future<bool> updatePresentation(int presentationId, Map<String, dynamic> body) async {
    try {
      final res = await http.patch(Uri.parse('${ApiConstants.baseUrl}/products/presentations/$presentationId'), headers: _headers, body: json.encode(body));
      return res.statusCode == 200;
    } catch (e) { return false; }
  }
}