import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../config/api_constants.dart';
import '../models/extracted_list_model.dart';

class AIExtractionService {
  
  /// Analiza una imagen de una lista escolar enviándola al motor de IA en el servidor.
  /// REQUIERE CONEXIÓN A INTERNET.
  Future<SchoolListAnalysisResponse> analyzeImage(File imageFile, String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/school-lists/analyze');

    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token'; 
    request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> jsonMap = json.decode(decodedBody);
        
        return SchoolListAnalysisResponse.fromJson(jsonMap);
      } else {
        throw Exception("Error ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      throw Exception("Error de conexión IA: Verifica tu acceso a internet.");
    }
  }
}