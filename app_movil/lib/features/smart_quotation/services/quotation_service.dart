import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/api_constants.dart';
import '../models/smart_quotation_model.dart';
import '../models/crm_models.dart';

class QuotationService {
  
  // 🔥 Helper para atrapar la expulsión
  void _checkAuthorization(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception("AUTH_REVOKED");
    }
  }

  Future<SmartQuotationModel> cloneQuotation(int quotationId, String token, {int? targetClientId}) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/smart-quotations/$quotationId/clone');
    final body = targetClientId != null ? json.encode({"target_client_id": targetClientId}) : null;
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: body);
      _checkAuthorization(response);

      if (response.statusCode == 200) {
        return SmartQuotationModel.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      } else {
        throw Exception("Error al clonar: ${response.body}");
      }
    } catch (e) { throw Exception("$e"); }
  }

  Future<ValidationResult> validateIntegrity(int quotationId, String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/smart-quotations/$quotationId/validate');
    try {
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      _checkAuthorization(response);

      if (response.statusCode == 200) {
        return ValidationResult.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      } else {
        throw Exception("Error al validar: ${response.body}");
      }
    } catch (e) { throw Exception("$e"); }
  }

  Future<int> saveManualQuotation({
    required String token,
    int? id,
    int? clientId,          
    String? clientName,     
    String? institutionName, 
    String? gradeLevel,      
    String? notas, 
    
    String? realClientName,
    String? realClientPhone,
    String? realClientDni,
    String? realClientAddress,
    String? realClientEmail,
    String? realClientNotes,

    required double totalAmount,
    required double totalSavings, 
    required List<Map<String, dynamic>> items,
    String status = "DRAFT", 
    String type = "manual",  
  }) async {
    final isEdit = id != null;
    final url = Uri.parse(isEdit ? '${ApiConstants.baseUrl}/smart-quotations/$id' : '${ApiConstants.baseUrl}/smart-quotations/');
    
    final body = {
      "client_id": clientId,
      "client_name": clientName,
      "institution_name": institutionName,
      "grade_level": gradeLevel,
      "notas": notas, 
      
      "real_client_name": realClientName,
      "real_client_phone": realClientPhone,
      "real_client_dni": realClientDni,
      "real_client_address": realClientAddress,
      "real_client_email": realClientEmail,
      "real_client_notes": realClientNotes,

      "total_amount": totalAmount,
      "total_savings": totalSavings,
      "status": status,
      "type": type,
      "items": items,
      "is_template": type == 'pack' 
    };

    try {
      final response = await (isEdit ? http.put : http.post)(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: json.encode(body)
      );

      _checkAuthorization(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['id'];
      } else {
        final err = json.decode(response.body);
        throw Exception(err['detail'] ?? "Error al guardar la cotización");
      }
    } catch (e) {
      throw Exception("$e");
    }
  }

  Future<bool> updateQuotationStatus(int id, String status, String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/smart-quotations/$id');
    try {
      final response = await http.patch(
        url,
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({"status": status}),
      );
      _checkAuthorization(response);

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception("Error al actualizar estado: ${response.body}");
      }
    } catch (e) { throw Exception("$e"); }
  }

  Future<bool> refreshQuotation(int id, String token, {bool fixPrices = true, bool fixStock = false}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/smart-quotations/$id/refresh')
        .replace(queryParameters: {
          'fix_prices': fixPrices.toString(),
          'fix_stock': fixStock.toString(),
        });
    try {
      final response = await http.post(uri, headers: {'Authorization': 'Bearer $token'});
      _checkAuthorization(response);

      if (response.statusCode == 200) {
        return true;
      } else {
        final msg = json.decode(response.body)['detail'] ?? "Error desconocido";
        throw Exception(msg);
      }
    } catch (e) { throw Exception("$e"); }
  }
}