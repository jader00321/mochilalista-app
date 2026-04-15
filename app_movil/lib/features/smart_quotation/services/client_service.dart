import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/api_constants.dart';
import '../models/crm_models.dart';

class ClientService {

  // 🔥 Helper para atrapar la expulsión
  void _checkAuthorization(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception("AUTH_REVOKED");
    }
  }

  Future<ClientModel?> getClientById(int id, String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/clientes/$id');
    try {
      final response = await http.get(
        url, 
        headers: {'Authorization': 'Bearer $token'}
      );
      _checkAuthorization(response);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return ClientModel.fromJson(data);
      }
      return null;
    } catch (e) {
      if (e.toString().contains("AUTH_REVOKED")) rethrow;
      return null;
    }
  }
  
  Future<List<ClientModel>> searchClients(String query, String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/clientes/?q=$query');
    try {
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      _checkAuthorization(response);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((e) => ClientModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (e.toString().contains("AUTH_REVOKED")) rethrow;
      return [];
    }
  }

  Future<ClientModel> createClient(Map<String, dynamic> clientData, String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/clientes/');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(clientData),
      );
      _checkAuthorization(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ClientModel.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      } else {
        throw Exception("Error creando cliente: ${response.body}");
      }
    } catch (e) {
      throw Exception("Error conexión cliente: $e");
    }
  }

  Future<ClientModel> updateClient(int id, Map<String, dynamic> clientData, String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/clientes/$id');
    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(clientData),
      );
      _checkAuthorization(response);

      if (response.statusCode == 200) {
        return ClientModel.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      } else {
        throw Exception("Error actualizando cliente: ${response.body}");
      }
    } catch (e) {
      throw Exception("Error conexión update client: $e");
    }
  }
  
  Future<List<ClientModel>> getTrackingClients(String token, {bool debtorsOnly = false}) async {
    final q = debtorsOnly ? "?con_deuda=true" : "";
    final url = Uri.parse('${ApiConstants.baseUrl}/clientes/tracking$q');
    
    try {
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      _checkAuthorization(response);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((e) => ClientModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (e.toString().contains("AUTH_REVOKED")) rethrow;
      return [];
    }
  }

  Future<List<LedgerItem>> getClientLedger(int clientId, String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/clientes/$clientId/ledger');
    try {
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      _checkAuthorization(response);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((e) => LedgerItem.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (e.toString().contains("AUTH_REVOKED")) rethrow;
      return [];
    }
  }

  Future<List<dynamic>> getPendingQuotations(int clientId, String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/clientes/$clientId/cotizaciones_pendientes');
    try {
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      _checkAuthorization(response);

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return [];
    } catch (e) {
      if (e.toString().contains("AUTH_REVOKED")) rethrow;
      return [];
    }
  }

  Future<List<SaleModel>> getClientDebts(int clientId, String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/clientes/$clientId/deudas');
    try {
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      _checkAuthorization(response);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((e) => SaleModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (e.toString().contains("AUTH_REVOKED")) rethrow;
      return [];
    }
  }

  Future<bool> registerPayment(int clientId, double amount, String method, String token, {int? ventaId, int? cuotaId, bool guardarVuelto = false}) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/clientes/$clientId/pagos');
    
    final body = {
      "monto": amount,
      "metodo_pago": method,
      "guardar_vuelto": guardarVuelto
    };
    
    if (ventaId != null) body["venta_id"] = ventaId;
    if (cuotaId != null) body["cuota_id"] = cuotaId;

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: json.encode(body),
      );
      _checkAuthorization(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        try {
            final err = json.decode(response.body);
            throw Exception(err['detail'] ?? "Error al registrar pago");
        } catch (_) {
            throw Exception("Error ${response.statusCode}");
        }
      }
    } catch (e) {
      throw Exception("Error de conexión al pagar: $e");
    }
  }
}