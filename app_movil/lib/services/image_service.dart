import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_constants.dart';

class ImageService {
  static Future<String?> processAndUploadImage(String? path, String token) async {
    if (path == null || path.isEmpty || path == 'null') return null;
    if (path.startsWith('http')) return path;

    try {
      final File imageFile = File(path);
      if (!imageFile.existsSync()) return null;

      final url = Uri.parse('${ApiConstants.baseUrl}/upload/');
      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token';
      
      String extension = imageFile.path.split('.').last.toLowerCase();
      MediaType mediaType = MediaType('image', 'jpeg');
      if (extension == 'png') mediaType = MediaType('image', 'png');
      if (extension == 'webp') mediaType = MediaType('image', 'webp');

      request.files.add(await http.MultipartFile.fromPath(
        'file', 
        imageFile.path,
        contentType: mediaType
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['url']; 
      }
      return null;
    } catch (e) {
      print("Error subiendo imagen: $e");
      return null;
    }
  }
}