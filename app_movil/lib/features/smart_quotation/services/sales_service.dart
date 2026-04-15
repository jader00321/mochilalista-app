import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/api_constants.dart';
import '../models/crm_models.dart';

class SalesService {
  
  // 🔥 Helper para atrapar la expulsión
  void _checkAuthorization(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception("AUTH_REVOKED");
    }
  }
  
  Future<SaleModel> createSale(Map<String, dynamic> saleData, String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/sales/create');
    try {
      final response = await http.post(
        url, 
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, 
        body: json.encode(saleData)
      ).timeout(const Duration(seconds: 20), onTimeout: () => throw Exception("Tiempo de espera agotado. Revisa tu conexión."));

      _checkAuthorization(response); // 🔥 Verificación Anti-Despido

      if (response.statusCode == 200 || response.statusCode == 201) {
        return SaleModel.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      } else {
        String errorMsg = "Error del servidor (${response.statusCode})";
        try {
          final error = json.decode(utf8.decode(response.bodyBytes));
          errorMsg = error['detail'] ?? "Error desconocido al procesar venta";
        } catch (_) {
          errorMsg = "La base de datos rechazó la operación.";
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      throw Exception("$e");
    }
  }

  Future<List<SaleModel>> getHistory(
    String token, {
    int skip = 0, 
    int limit = 50,
    String? startDate,
    String? endDate,
    String? searchQuery,
    bool isArchived = false,
    String? origenVenta,
    String sortBy = "fecha_venta",
    String order = "desc"
  }) async {
    final Map<String, String> queryParams = {
      'skip': skip.toString(),
      'limit': limit.toString(),
      'is_archived': isArchived.toString(),
      'sort_by': sortBy,
      'order': order,
    };

    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;
    if (searchQuery != null && searchQuery.isNotEmpty) queryParams['search_query'] = searchQuery;
    if (origenVenta != null && origenVenta != "todas") queryParams['origen_venta'] = origenVenta;

    final uri = Uri.parse('${ApiConstants.baseUrl}/sales/history').replace(queryParameters: queryParams);
    
    try {
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 15));
      _checkAuthorization(response); // 🔥 Verificación Anti-Despido

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((e) => SaleModel.fromJson(e)).toList();
      } else {
        throw Exception("Error al obtener el historial");
      }
    } catch (e) {
      throw Exception("Error de conexión: $e");
    }
  }

  Future<SalesStatsModel> getStats(String token, {String? startDate, String? endDate, bool isArchived = false, String? origenVenta}) async {
    final Map<String, String> queryParams = {
      'is_archived': isArchived.toString()
    };
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;
    if (origenVenta != null && origenVenta != "todas") queryParams['origen_venta'] = origenVenta;

    final uri = Uri.parse('${ApiConstants.baseUrl}/sales/stats').replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 10));
      _checkAuthorization(response); // 🔥 Verificación Anti-Despido

      if (response.statusCode == 200) {
        return SalesStatsModel.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      } else {
        throw Exception("Error al obtener estadísticas");
      }
    } catch (e) {
      throw Exception("Error de conexión: $e");
    }
  }

  Future<bool> toggleArchive(String token, int saleId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/sales/$saleId/archive');
    try {
      final response = await http.patch(url, headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 10));
      _checkAuthorization(response); // 🔥 Verificación Anti-Despido

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['is_archived'];
      } else {
        throw Exception("Error al archivar la venta");
      }
    } catch (e) {
      throw Exception("Error de conexión: $e");
    }
  }

  Future<Map<String, dynamic>> getSaleDetail(String token, int saleId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/sales/$saleId/detail');
    try {
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 15));
      _checkAuthorization(response); // 🔥 Verificación Anti-Despido

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception("Error al cargar detalle de venta");
      }
    } catch (e) {
      throw Exception("Error de conexión: $e");
    }
  }

  Future<String> updateDeliveryStatus(String token, int saleId, String newStatus) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/sales/$saleId/delivery');
    try {
      final response = await http.patch(
        url, 
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({"estado_entrega": newStatus})
      ).timeout(const Duration(seconds: 10));
      
      _checkAuthorization(response); // 🔥 Verificación Anti-Despido

      if (response.statusCode == 200) {
        return json.decode(response.body)['estado_entrega'];
      } else {
        throw Exception("Error al actualizar estado logístico");
      }
    } catch (e) {
      throw Exception("Error de conexión: $e");
    }
  }
}