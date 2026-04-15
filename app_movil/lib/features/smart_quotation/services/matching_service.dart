import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../config/api_constants.dart';
import '../models/extracted_list_model.dart';
import '../models/matching_model.dart';

class MatchingService {
  
  void _checkAuthorization(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception("AUTH_REVOKED");
    }
  }

  // 🔥 NUEVO: Recibe el rol del cliente para pasárselo al backend
  Future<List<BackendMatchResult>> runBatchMatching(
    List<ExtractedItem> items, 
    String token,
    bool isClientRole 
  ) async {
    // 🔥 Añadimos el query parameter para que FastAPI sepa cómo actuar
    final uri = Uri.parse('${ApiConstants.baseUrl}/smart-inventory-matcher/match-batch').replace(
      queryParameters: {
        'is_client': isClientRole.toString()
      }
    );

    final itemsPayload = items.map((item) => {
      "id": item.id,
      "full_name": item.fullName,
      "brand": item.brand,
      "quantity": item.quantity
    }).toList();

    final body = json.encode({"items": itemsPayload});

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      _checkAuthorization(response);

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> resultsJson = decoded['results'];
        return resultsJson.map((json) => BackendMatchResult.fromJson(json)).toList();
      } else {
        throw Exception("Error ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      throw Exception("$e");
    }
  }

  Future<int> saveQuotation(Map<String, dynamic> quotationData, String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/smart-quotations/');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(quotationData),
      );

      _checkAuthorization(response);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['id'];
      } else {
        throw Exception("Error al guardar: ${response.body}");
      }
    } catch (e) {
      throw Exception("$e");
    }
  }

  Future<String?> uploadImageToBackend(File imageFile, String token) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/upload/');
      final request = http.MultipartRequest('POST', url)..headers['Authorization'] = 'Bearer $token';
      
      String extension = imageFile.path.split('.').last.toLowerCase();
      MediaType mediaType = MediaType('image', 'jpeg');
      if (extension == 'png') mediaType = MediaType('image', 'png');
      if (extension == 'webp') mediaType = MediaType('image', 'webp');

      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path, contentType: mediaType));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      _checkAuthorization(response);

      if (response.statusCode == 200) {
        return json.decode(response.body)['url']; 
      }
      return null;
    } catch (e) { 
      if (e.toString().contains("AUTH_REVOKED")) rethrow;
      return null; 
    }
  }
}