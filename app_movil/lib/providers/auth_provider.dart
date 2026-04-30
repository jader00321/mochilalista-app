import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

enum AuthStatus { checking, authenticated, profileSelection }

class AuthProvider with ChangeNotifier {
  final _secureStorage = const FlutterSecureStorage();
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.checking;
  List<UserModel> _localProfiles = [];
  UserModel? _activeUser;
  
  bool _isLoading = false;
  String _errorMessage = '';

  AuthStatus get status => _status;
  List<UserModel> get localProfiles => _localProfiles;
  UserModel? get user => _activeUser;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  BusinessModel? get currentBusiness => _activeUser?.business;
  int? get activeBusinessId => _activeUser?.business?.id;
  int? get activeUserId => _activeUser?.id;

  String get userName => _activeUser?.fullName ?? "Usuario";
  String get businessName => _activeUser?.business?.commercialName ?? "Mi Negocio";

  bool get isAuthenticated => _status == AuthStatus.authenticated && _activeUser != null;
  bool get hasActiveContext => activeBusinessId != null;

  // Permisos absolutos por ser offline
  bool get isOwner => true;
  bool get isCommunityClient => false;
  bool get isWorker => false;

  bool get canViewCosts => true;
  bool get canEditInventory => true;
  bool get canApplyDiscounts => true;
  bool get canGiveCredit => true;
  bool get canManageClients => true;
  bool get canVoidSales => true;

  String? get token => null;

  AuthProvider() {
    checkInitialState();
  }

  void clearError() {
    if (_errorMessage.isNotEmpty) {
      _errorMessage = '';
      notifyListeners();
    }
  }

  Future<void> checkInitialState() async {
    _status = AuthStatus.checking;
    notifyListeners();

    try {
      _localProfiles = await _authService.getLocalProfiles();
      
      if (_localProfiles.isEmpty) {
        _status = AuthStatus.profileSelection;
      } else {
        final prefs = await SharedPreferences.getInstance();
        final lastUserId = prefs.getInt('last_active_user_id');
        
        if (lastUserId != null) {
          try {
            _activeUser = await _authService.getUserProfile(lastUserId);
            _status = AuthStatus.authenticated;
          } catch (_) {
            // Si el perfil ya no existe en la BD, lo mandamos a selección
            await prefs.remove('last_active_user_id');
            _status = AuthStatus.profileSelection;
          }
        } else {
          _status = AuthStatus.profileSelection;
        }
      }
    } catch (e) {
      _errorMessage = "No se pudieron cargar los perfiles de tu dispositivo.";
      _status = AuthStatus.profileSelection;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> createProfileAndLogin({
    required String nombreDueno, required String telefono, required String nombreNegocio,
    required String direccion, String? logoPath, required String moneda, String? pin
  }) async {
    _setLoading(true);
    try {
      final newUser = await _authService.registerLocalProfile(
        nombreDueno: nombreDueno, telefono: telefono, nombreNegocio: nombreNegocio, 
        direccion: direccion, logoPath: logoPath, moneda: moneda
      );

      if (pin != null && pin.isNotEmpty) {
        await _secureStorage.write(key: 'pin_${newUser.id}', value: pin);
      }

      await loginWithProfile(newUser.id);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception:", "").trim();
      _setLoading(false);
      return false;
    }
  }

  Future<void> loginWithProfile(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_active_user_id', userId);
    
    _activeUser = await _authService.getUserProfile(userId);
    _status = AuthStatus.authenticated;
    
    _localProfiles = await _authService.getLocalProfiles(); 
    notifyListeners();
  }

  Future<bool> profileHasPin(int userId) async {
    final pin = await _secureStorage.read(key: 'pin_$userId');
    return pin != null && pin.isNotEmpty;
  }

  Future<bool> verifyPin(int userId, String enteredPin) async {
    final correctPin = await _secureStorage.read(key: 'pin_$userId');
    return correctPin == enteredPin;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_active_user_id');
    _activeUser = null;
    _status = AuthStatus.profileSelection;
    notifyListeners();
  }

  // 🔥 NUEVA FUNCIÓN DE CONTINGENCIA: Borrado seguro
  Future<bool> deleteProfileAndData(int userId, String inputPin) async {
    _setLoading(true);
    try {
      // 1. Verificamos el PIN de seguridad si es que tiene uno
      bool hasPin = await profileHasPin(userId);
      if (hasPin) {
        bool isCorrect = await verifyPin(userId, inputPin);
        if (!isCorrect) throw Exception("El PIN ingresado es incorrecto.");
      }

      // 2. Procedemos al borrado de base de datos
      bool deleted = await _authService.deleteLocalProfile(userId);
      if (deleted) {
        // 3. Limpiamos la memoria segura
        await _secureStorage.delete(key: 'pin_$userId');
        
        // 4. Si es el usuario activo, lo deslogueamos
        if (_activeUser?.id == userId) {
          await logout();
        }
        await checkInitialState(); // Recarga la lista de perfiles
      }
      
      _setLoading(false);
      return deleted;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception:", "").trim();
      _setLoading(false);
      return false;
    }
  }

  // --- MÉTODOS DE ACTUALIZACIÓN ---
  
  Future<bool> updateUserProfile(String nombre, String telefono) async {
    if (_activeUser == null) return false;
    _setLoading(true);
    try {
      final updatedUser = await _authService.updateProfile(_activeUser!.id, nombre, telefono);
      _activeUser = updatedUser; 
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = "No se pudieron actualizar tus datos personales.";
      _setLoading(false);
      return false;
    }
  }

  Future<bool> changePassword(String currentPin, String newPin) async {
    if (_activeUser == null) return false;
    _setLoading(true);
    try {
      bool isCorrect = await verifyPin(_activeUser!.id, currentPin);
      if (!isCorrect) throw Exception("El PIN actual es incorrecto.");
      
      await _secureStorage.write(key: 'pin_${_activeUser!.id}', value: newPin);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception:", "").trim();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> createBusinessProfile(String name, String ruc, String address, String paymentInfo, double? lat, double? lng, bool showAddress, bool showRuc) async {
    if (_activeUser == null) return false;
    _setLoading(true);
    try {
      String encodedConfig = json.encode({"show_address": showAddress, "show_ruc": showRuc});
      await _authService.createBusiness(_activeUser!.id, name, ruc, address, paymentInfo, lat, lng, encodedConfig);
      await loginWithProfile(_activeUser!.id); 
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = "Ocurrió un error al crear la información del negocio.";
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateBusinessProfile(String name, String ruc, String address, String paymentInfo, double? lat, double? lng, bool showAddress, bool showRuc, {bool clearLogo = false}) async {
    if (_activeUser == null || activeBusinessId == null) return false;
    _setLoading(true);
    try {
      String encodedConfig = json.encode({"show_address": showAddress, "show_ruc": showRuc});
      final updatedBusiness = await _authService.updateBusiness(activeBusinessId!, name, ruc, address, paymentInfo, lat, lng, encodedConfig, clearLogo: clearLogo);
      
      if (_activeUser != null) {
         _activeUser = UserModel(
           id: _activeUser!.id, codigoUnicoUsuario: _activeUser!.codigoUnicoUsuario, email: _activeUser!.email,
           fullName: _activeUser!.fullName, phone: _activeUser!.phone, isActive: _activeUser!.isActive, business: updatedBusiness 
         );
      }
      notifyListeners();
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = "No pudimos actualizar los datos del negocio.";
      _setLoading(false);
      return false;
    }
  }

  Future<bool> uploadBusinessLogo(File imageFile) async {
    if (_activeUser == null || activeBusinessId == null) return false;
    _setLoading(true);
    try {
      final updatedBusiness = await _authService.uploadLogo(activeBusinessId!, imageFile);
      if (_activeUser != null) {
         _activeUser = UserModel(
           id: _activeUser!.id, codigoUnicoUsuario: _activeUser!.codigoUnicoUsuario, email: _activeUser!.email,
           fullName: _activeUser!.fullName, phone: _activeUser!.phone, isActive: _activeUser!.isActive, business: updatedBusiness 
         );
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = "La imagen es muy pesada o el formato no es compatible.";
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}