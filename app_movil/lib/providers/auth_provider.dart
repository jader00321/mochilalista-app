import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

enum AuthStatus { checking, authenticated, notAuthenticated }

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.checking;
  UserModel? _user;
  String? _token;
  String _errorMessage = '';
  bool _isLoading = false;

  int? _activeBusinessId;
  String? _activeRole;
  Map<String, dynamic> _permissions = {};
  
  BusinessModel? _currentBusiness; 

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  
  String get userName => _user?.fullName ?? "Usuario Invitado"; 
  String get userEmail => _user?.email ?? "";
  String get userRole => _activeRole?.toUpperCase() ?? "INVITADO";
  
  bool get ownsBusiness => _user?.business != null; 
  
  String get businessName => _currentBusiness?.commercialName ?? "Sin Negocio";
  BusinessModel? get currentBusiness => _currentBusiness; 

  bool get hasActiveContext => _activeBusinessId != null;
  int? get activeBusinessId => _activeBusinessId;
  String get activeRole => _activeRole ?? "limbo";

  bool get isOwner => _activeRole == 'dueno';
  bool get isCommunityClient => _activeRole == 'cliente_comunidad';
  bool get isWorker => _activeRole == 'trabajador';

  bool get canViewCosts => isOwner || (_permissions['can_view_costs'] == true);
  bool get canEditInventory => isOwner || (_permissions['can_edit_inventory'] == true);
  bool get canApplyDiscounts => isOwner || (_permissions['can_apply_discounts'] == true);
  bool get canGiveCredit => isOwner || (_permissions['can_give_credit'] == true);
  bool get canManageClients => isOwner || (_permissions['can_manage_clients'] == true);
  bool get canVoidSales => isOwner || (_permissions['can_void_sales'] == true);

  AuthProvider() {
    checkAuthStatus();
  }

  void clearError() {
    if (_errorMessage.isNotEmpty) {
      _errorMessage = '';
      notifyListeners();
    }
  }

  void _decodeTokenAndSetContext(String jwtToken) {
    try {
      final parts = jwtToken.split('.');
      if (parts.length != 3) return;

      final payload = parts[1];
      final String normalized = base64Url.normalize(payload);
      final String decoded = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> payloadMap = json.decode(decoded);

      _activeBusinessId = payloadMap['negocio_id'];
      _activeRole = payloadMap['rol_en_negocio'];
      _permissions = payloadMap['permisos'] ?? {};
    } catch (e) {
      debugPrint("Error decodificando JWT: $e");
      _activeBusinessId = null;
      _activeRole = null;
      _permissions = {};
    }
  }

  Future<void> _fetchCurrentBusiness() async {
    if (_token != null && _activeBusinessId != null) {
       _currentBusiness = await _authService.getCurrentBusiness(_token!);
       notifyListeners();
    }
  }

  Future<void> _autoSwitchToFirstWorkspace() async {
    if (_token == null) return;
    try {
      final workspaces = await _authService.getWorkspaces(_token!);
      if (workspaces.isNotEmpty) {
        final defaultNegocioId = workspaces.first['negocio_id'];
        final contextToken = await _authService.switchContext(_token!, defaultNegocioId);
        
        if (contextToken != null) {
          await setContextToken(contextToken);
        }
      }
    } catch (e) {
      debugPrint("Fallo al intentar el auto-switch: $e");
    }
  }

  Future<void> checkAuthStatus() async {
    _status = AuthStatus.checking;
    try {
      final storedToken = await _storage.read(key: 'jwt_token');
      
      if (storedToken == null) {
        await _logoutLocal(); 
        return;
      }
      
      final userProfile = await _authService.getUserProfile(storedToken);
      _token = storedToken;
      _user = userProfile;
      _decodeTokenAndSetContext(storedToken); 
      
      if (_activeBusinessId == null) {
         await _autoSwitchToFirstWorkspace();
      } else {
         // 🔥 CRÍTICO: Refrescar token contextual silenciosamente en el Auto-Login
         try {
           final freshContextToken = await _authService.switchContext(storedToken, _activeBusinessId!);
           if (freshContextToken != null) {
             await setContextToken(freshContextToken); // Esto actualiza permisos y negocio
           } else {
             await _fetchCurrentBusiness(); // Respaldo si falla el switch
           }
         } catch (e) {
           // Si el servidor rechaza el switch context (Ej: Trabajador Suspendido), 
           // se fuerza el cierre de sesión local por seguridad.
           debugPrint("Error al refrescar contexto: $e");
           await _logoutLocal();
           return;
         }
      }

      _status = AuthStatus.authenticated;
    } catch (e) { 
      await _logoutLocal(); 
    } finally { 
      notifyListeners(); 
    }
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _errorMessage = ''; 
    try {
      final response = await _authService.login(email, password);
      final newToken = response['access_token'];
      await _storage.write(key: 'jwt_token', value: newToken);
      
      final userProfile = await _authService.getUserProfile(newToken);
      _token = newToken;
      _user = userProfile;
      _decodeTokenAndSetContext(newToken); 
      
      if (_activeBusinessId == null) {
         await _autoSwitchToFirstWorkspace();
      } else {
         await _fetchCurrentBusiness(); 
      }

      _status = AuthStatus.authenticated;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception:", "").trim();
      _status = AuthStatus.notAuthenticated;
      _setLoading(false);
      return false;
    }
  }

  Future<void> setContextToken(String newContextToken) async {
    await _storage.write(key: 'jwt_token', value: newContextToken);
    _token = newContextToken;
    _decodeTokenAndSetContext(newContextToken);
    await _fetchCurrentBusiness(); 
    notifyListeners();
  }

  Future<void> clearContext() async {
    _activeBusinessId = null;
    _activeRole = null;
    _currentBusiness = null;
    _permissions = {};
    notifyListeners();
  }

  Future<void> logout() async {
    await _logoutLocal();
    notifyListeners();
  }

  Future<void> _logoutLocal() async {
    await _storage.delete(key: 'jwt_token');
    _token = null;
    _user = null;
    _currentBusiness = null;
    _activeBusinessId = null;
    _activeRole = null;
    _permissions = {};
    _status = AuthStatus.notAuthenticated;
  }

  Future<bool> register(String nombre, String email, String password, String negocio, String telefono) async {
    _setLoading(true);
    _errorMessage = ''; 
    try {
      await _authService.register(nombre, email, password, negocio, telefono);
      bool loggedIn = await login(email, password);
      _setLoading(false);
      return loggedIn;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception:", "").trim();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateUserProfile(String nombre, String telefono) async {
    if (_token == null) return false;
    _setLoading(true);
    try {
      final updatedUser = await _authService.updateProfile(_token!, nombre, telefono);
      _user = updatedUser; 
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception:", "").trim();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    if (_token == null) return false;
    _setLoading(true);
    try {
      await _authService.changePassword(_token!, currentPassword, newPassword);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception:", "").trim();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> createBusinessProfile(String name, String ruc, String address, String paymentInfo, double? lat, double? lng, bool showAddress, bool showRuc) async {
    if (_token == null) return false;
    _setLoading(true);
    try {
      String encodedConfig = json.encode({"show_address": showAddress, "show_ruc": showRuc});
      
      final newBusiness = await _authService.createBusiness(_token!, name, ruc, address, paymentInfo, lat, lng, encodedConfig);
      
      final newToken = await _authService.switchContext(_token!, newBusiness.id);
      if (newToken != null) {
         await setContextToken(newToken);
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception:", "").trim();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateBusinessProfile(String name, String ruc, String address, String paymentInfo, double? lat, double? lng, bool showAddress, bool showRuc, {bool clearLogo = false}) async {
    if (_token == null) return false;
    _setLoading(true);
    try {
      String encodedConfig = json.encode({"show_address": showAddress, "show_ruc": showRuc});
      final updatedBusiness = await _authService.updateBusiness(_token!, name, ruc, address, paymentInfo, lat, lng, encodedConfig, clearLogo: clearLogo);
      
      if (_activeBusinessId != updatedBusiness.id) {
          final newToken = await _authService.switchContext(_token!, updatedBusiness.id);
          if (newToken != null) {
             await setContextToken(newToken);
          }
      } else {
          _currentBusiness = updatedBusiness; 
          notifyListeners();
      }

      if (_user != null) {
         _user = UserModel(
           id: _user!.id,
           codigoUnicoUsuario: _user!.codigoUnicoUsuario,
           email: _user!.email,
           fullName: _user!.fullName,
           phone: _user!.phone,
           isActive: _user!.isActive,
           business: updatedBusiness 
         );
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception:", "").trim();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> uploadBusinessLogo(File imageFile) async {
    if (_token == null) return false;
    _setLoading(true);
    try {
      final updatedBusiness = await _authService.uploadLogo(_token!, imageFile);
      if (_currentBusiness != null) {
        final bypassUrl = "${updatedBusiness.logoUrl}?t=${DateTime.now().millisecondsSinceEpoch}";
        _currentBusiness = BusinessModel(
            id: updatedBusiness.id, 
            commercialName: updatedBusiness.commercialName, 
            ruc: updatedBusiness.ruc, 
            address: updatedBusiness.address, 
            printerConfig: updatedBusiness.printerConfig, 
            paymentInfo: updatedBusiness.paymentInfo, 
            latitud: updatedBusiness.latitud, 
            longitud: updatedBusiness.longitud,
            logoUrl: bypassUrl, 
          );
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception:", "").trim();
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}