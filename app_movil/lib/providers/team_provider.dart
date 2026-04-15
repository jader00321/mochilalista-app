import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_constants.dart';
import '../models/team_management_models.dart';

class TeamProvider with ChangeNotifier {
  String? _authToken;
  bool _isLoading = false;
  String _errorMessage = "";

  List<TeamMemberModel> _teamMembers = [];
  List<AccessCodeModel> _accessCodes = []; 

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<TeamMemberModel> get teamMembers => _teamMembers;
  List<AccessCodeModel> get accessCodes => _accessCodes; 

  // 🔥 Callback vital para la seguridad Multi-Tenant
  Function()? onAuthRevoked;

  void updateToken(String? token) {
    _authToken = token;
  }

  void _handleException(dynamic e) {
    if (e.toString().contains("AUTH_REVOKED")) {
      _errorMessage = "Tu acceso a este negocio ha sido revocado o suspendido.";
      if (onAuthRevoked != null) onAuthRevoked!();
    } else {
      _errorMessage = e.toString().replaceAll("Exception:", "").trim();
    }
    notifyListeners();
  }

  Future<void> fetchTeam(int businessId) async {
    if (_authToken == null) return;
    _isLoading = true;
    _errorMessage = "";
    notifyListeners();

    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/business-management/$businessId/team');
      final response = await http.get(url, headers: {'Authorization': 'Bearer $_authToken'});

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        _teamMembers = data.map((json) => TeamMemberModel.fromJson(json)).toList();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception("AUTH_REVOKED");
      } else {
        throw Exception("Error al cargar el equipo (${response.statusCode})");
      }
    } catch (e) {
      _handleException(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAccessCodes(int businessId) async {
    if (_authToken == null) return;
    _isLoading = true;
    _errorMessage = "";
    notifyListeners();

    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/business-management/$businessId/access-codes');
      final response = await http.get(url, headers: {'Authorization': 'Bearer $_authToken'});

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        _accessCodes = data.map((json) => AccessCodeModel.fromJson(json)).toList();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception("AUTH_REVOKED");
      } else {
        throw Exception("Error al cargar códigos (${response.statusCode})");
      }
    } catch (e) {
      _handleException(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AccessCodeModel?> generateAccessCode(int businessId, String role, int maxUses, String? expirationDate) async {
    if (_authToken == null) return null;
    _isLoading = true;
    _errorMessage = "";
    notifyListeners();

    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/business-management/$businessId/access-codes');
      final bodyData = {
        "rol_a_otorgar": role,
        "usos_maximos": maxUses
      };
      if (expirationDate != null) bodyData["fecha_expiracion"] = expirationDate;

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_authToken', 
          'Content-Type': 'application/json'
        },
        body: json.encode(bodyData)
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final newCode = AccessCodeModel.fromJson(data);
        _accessCodes.insert(0, newCode);
        return newCode;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception("AUTH_REVOKED");
      } else {
        throw Exception("No se pudo generar el código.");
      }
    } catch (e) {
      _handleException(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAccessCode(int businessId, int codeId) async {
    if (_authToken == null) return false;
    _isLoading = true;
    _errorMessage = "";
    notifyListeners();

    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/business-management/$businessId/access-codes/$codeId');
      final response = await http.delete(url, headers: {'Authorization': 'Bearer $_authToken'});

      if (response.statusCode == 200 || response.statusCode == 204) {
        _accessCodes.removeWhere((c) => c.id == codeId);
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception("AUTH_REVOKED");
      }
      return false;
    } catch (e) {
      _handleException(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateMemberPermissions(int businessId, int userId, Map<String, dynamic> newPermissions, String newStatus, String newRole) async {
    if (_authToken == null) return false;
    _isLoading = true;
    _errorMessage = "";
    notifyListeners();

    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/business-management/$businessId/team/$userId');
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $_authToken', 
          'Content-Type': 'application/json'
        },
        body: json.encode({
          "estado_acceso": newStatus,
          "permisos": newPermissions,
          "rol_en_negocio": newRole
        })
      );

      if (response.statusCode == 200) {
        await fetchTeam(businessId);
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception("AUTH_REVOKED");
      } else {
        throw Exception("Fallo al actualizar permisos.");
      }
    } catch (e) {
      _handleException(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addUserDirectly(int businessId, String userCode, String role) async {
    if (_authToken == null) return false;
    _isLoading = true;
    _errorMessage = "";
    notifyListeners();

    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/business-management/$businessId/add-user-directly?codigo_usuario=$userCode&rol_asignar=$role');
      final response = await http.post(url, headers: {'Authorization': 'Bearer $_authToken'});

      if (response.statusCode == 200) {
        await fetchTeam(businessId);
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception("AUTH_REVOKED");
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? "Error en el Radar.");
      }
    } catch (e) {
      _handleException(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}