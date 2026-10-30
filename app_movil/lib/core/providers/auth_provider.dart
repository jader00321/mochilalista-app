import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/core/services/auth_service.dart';
import 'package:app_movil/core/services/pin_reminder_service.dart';
import 'package:app_movil/core/models/user_model.dart';

enum AuthStatus { checking, authenticated, profileSelection }

class AuthProvider with ChangeNotifier {
  final _secureStorage = const FlutterSecureStorage();
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.checking;
  List<UserModel> _localProfiles = [];
  UserModel? _activeUser;
  
  bool _isLoading = false;
  String _errorMessage = '';
  bool _hasPinCache = false;
  bool _isPinReminderSnoozed = false;

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
  String get currentCurrency => _activeUser?.business?.moneda ?? 'S/ (Soles)';
  bool get hasPinCache => _hasPinCache;
  bool get isPinReminderSnoozed => _isPinReminderSnoozed;

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
            _hasPinCache = await profileHasPin(lastUserId);
            _isPinReminderSnoozed = await PinReminderService.isSnoozed(lastUserId);
            _status = AuthStatus.authenticated;
          } catch (_) {
            await prefs.remove('last_active_user_id');
            _status = AuthStatus.profileSelection;
          }
        } else {
          _status = AuthStatus.profileSelection;
        }
      }
    } catch (e) {
      _errorMessage = "No se pudieron cargar los perfiles.";
      _status = AuthStatus.profileSelection;
    } finally {
      notifyListeners();
    }
  }

  Future<void> refreshActiveUser() async {
    if (_activeUser != null) {
      try {
        _activeUser = await _authService.getUserProfile(_activeUser!.id);
        _localProfiles = await _authService.getLocalProfiles();
        _hasPinCache = await profileHasPin(_activeUser!.id);
        _isPinReminderSnoozed = await PinReminderService.isSnoozed(_activeUser!.id);
        notifyListeners();
      } catch (e) {
        // Ignore silent refresh errors
      }
    }
  }

  // 🔥 SOLUCIÓN AL BUG DE NAVEGACIÓN Y CARGA INFINITA
  Future<bool> createProfileAndLogin({
    required String nombreDueno,
    required String telefono,
    required String nombreNegocio,
    required String direccion,
    String? logoPath,
    required String moneda,
    String? pin,
    String? paymentInfo,
    String? ruc,
    String? email,
  }) async {
    _setLoading(true);
    try {
      final newUser = await _authService.registerLocalProfile(
        nombreDueno: nombreDueno,
        telefono: telefono,
        nombreNegocio: nombreNegocio, 
        direccion: direccion,
        logoPath: logoPath,
        moneda: moneda,
        informacionPago: paymentInfo,
        ruc: ruc,
        email: email,
      );

      if (pin != null && pin.isNotEmpty) {
        await _secureStorage.write(key: 'pin_${newUser.id}', value: pin);
      }

      await loginWithProfile(newUser.id);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception:", "").trim();
      return false;
    } finally {
      _setLoading(false); // Apaga siempre el loader para que la app no se congele
    }
  }

  Future<void> loginWithProfile(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_active_user_id', userId);
    
    _activeUser = await _authService.getUserProfile(userId);
    _localProfiles = await _authService.getLocalProfiles(); 
    _hasPinCache = await profileHasPin(userId);
    _isPinReminderSnoozed = await PinReminderService.isSnoozed(userId);
    
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<bool> profileHasPin(int userId) async {
    final pin = await _secureStorage.read(key: 'pin_$userId');
    return pin != null && pin.isNotEmpty;
  }

  Future<bool> verifyPin(int userId, String enteredPin) async {
    final correctPin = await _secureStorage.read(key: 'pin_$userId');
    if (correctPin == null || correctPin.isEmpty) {
      return enteredPin.isEmpty;
    }
    return correctPin == enteredPin;
  }

  Future<void> snoozePinReminder({int days = 7}) async {
    if (_activeUser == null) return;
    await PinReminderService.snooze(_activeUser!.id, days: days);
    _isPinReminderSnoozed = true;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_active_user_id');
    _activeUser = null;
    _isPinReminderSnoozed = false;
    _status = AuthStatus.profileSelection;
    notifyListeners();
  }

  Future<bool> deleteProfileAndDataWithProgress(int userId, String? inputPin, Function(String, double) onProgress) async {
    // No usamos _setLoading(true) aquí porque el modal ya mostrará el progreso
    try {
      bool hasPin = await profileHasPin(userId);
      if (hasPin) {
        bool isCorrect = await verifyPin(userId, inputPin ?? '');
        if (!isCorrect) throw Exception("El PIN ingresado es incorrecto.");
      }

      bool deleted = await _authService.deleteLocalProfileWithProgress(userId, onProgress);
      if (deleted) {
        await _secureStorage.delete(key: 'pin_$userId');
        _hasPinCache = false;
        if (_activeUser?.id == userId) {
          await logout();
        } else {
          await checkInitialState();
        }
      }
      return deleted;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception:", "").trim();
      return false;
    }
  }
  
  Future<bool> updateUserProfile(String nombre, String telefono, {String? email}) async {
    if (_activeUser == null) return false;
    _setLoading(true);
    try {
      final updatedUser = await _authService.updateProfile(_activeUser!.id, nombre, telefono, email: email);
      _activeUser = updatedUser; 
      return true;
    } catch (e) {
      _errorMessage = "No se pudieron actualizar tus datos personales.";
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> changePassword(String currentPin, String newPin) async {
    if (_activeUser == null) return false;
    _setLoading(true);
    try {
      bool isCorrect = await verifyPin(_activeUser!.id, currentPin);
      if (!isCorrect) throw Exception("El PIN actual es incorrecto.");
      
      if (newPin.isEmpty) {
        await _secureStorage.delete(key: 'pin_${_activeUser!.id}');
        _hasPinCache = false;
      } else {
        await _secureStorage.write(key: 'pin_${_activeUser!.id}', value: newPin);
        _hasPinCache = true;
        await PinReminderService.clearSnooze(_activeUser!.id);
        _isPinReminderSnoozed = false;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception:", "").trim();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Restablece directamente el PIN del usuario activo (tras autenticación biométrica exitosa)
  Future<bool> resetPinDirectly(String newPin) async {
    if (_activeUser == null) return false;
    return await resetPinForUser(_activeUser!.id, newPin);
  }

  /// Restablece directamente el PIN para un usuario específico (usado en LockScreen durante recuperación)
  Future<bool> resetPinForUser(int userId, String newPin) async {
    _setLoading(true);
    try {
      if (newPin.isEmpty) {
        await _secureStorage.delete(key: 'pin_$userId');
        if (_activeUser?.id == userId) _hasPinCache = false;
      } else {
        await _secureStorage.write(key: 'pin_$userId', value: newPin);
        if (_activeUser?.id == userId) _hasPinCache = true;
      }
      await PinReminderService.clearSnooze(userId);
      if (_activeUser?.id == userId) _isPinReminderSnoozed = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception:", "").trim();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Verifica la identidad del titular contra los datos del negocio y usuario almacenados localmente en SQLite
  Future<bool> verifyOwnerIdentity(int userId, {required String rucOrDni, required String phoneOrEmail}) async {
    try {
      final user = await _authService.getUserProfile(userId);
      final cleanInputRuc = rucOrDni.trim().replaceAll(RegExp(r'[^0-9]'), '');
      final cleanInputPhone = phoneOrEmail.trim().replaceAll(RegExp(r'[^0-9]'), '');
      final cleanInputEmail = phoneOrEmail.trim().toLowerCase();

      bool rucMatches = false;
      final registeredRuc = user.business?.ruc?.trim().replaceAll(RegExp(r'[^0-9]'), '') ?? '';
      if (cleanInputRuc.isNotEmpty && registeredRuc.isNotEmpty && registeredRuc == cleanInputRuc) {
        rucMatches = true;
      }

      bool contactMatches = false;
      final registeredPhone = user.phone?.trim().replaceAll(RegExp(r'[^0-9]'), '') ?? '';
      final registeredEmail = user.email?.trim().toLowerCase() ?? '';

      if (cleanInputPhone.isNotEmpty && registeredPhone.isNotEmpty && registeredPhone == cleanInputPhone) {
        contactMatches = true;
      } else if (cleanInputEmail.isNotEmpty && registeredEmail.isNotEmpty && registeredEmail == cleanInputEmail) {
        contactMatches = true;
      }

      // Si el negocio tiene RUC registrado, requerimos que coincida el RUC y el medio de contacto
      if (registeredRuc.isNotEmpty) {
        return rucMatches && contactMatches;
      }
      
      // Si no tenía RUC registrado, la coincidencia del teléfono o correo basta
      return contactMatches;
    } catch (e) {
      debugPrint("Error verificando identidad del titular: $e");
      return false;
    }
  }

  Future<bool> createBusinessProfile(String name, String ruc, String address, String? paymentInfo, double? lat, double? lng, bool showAddress, bool showRuc, {String moneda = 'S/ (Soles)'}) async {
    if (_activeUser == null) return false;
    _setLoading(true);
    try {
      String encodedConfig = json.encode({"show_address": showAddress, "show_ruc": showRuc});
      await _authService.createBusiness(_activeUser!.id, name, ruc, address, paymentInfo, lat, lng, encodedConfig, moneda: moneda);
      await loginWithProfile(_activeUser!.id); 
      return true;
    } catch (e) {
      _errorMessage = "Ocurrió un error al crear la información del negocio.";
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateBusinessProfile(String name, String ruc, String address, String? paymentInfo, double? lat, double? lng, bool showAddress, bool showRuc, {bool clearLogo = false, String? moneda}) async {
    if (_activeUser == null || activeBusinessId == null) return false;
    _setLoading(true);
    try {
      String encodedConfig = json.encode({"show_address": showAddress, "show_ruc": showRuc});
      final updatedBusiness = await _authService.updateBusiness(activeBusinessId!, name, ruc, address, paymentInfo, lat, lng, encodedConfig, clearLogo: clearLogo, moneda: moneda);
      
      if (_activeUser != null) {
         _activeUser = UserModel(
           id: _activeUser!.id, codigoUnicoUsuario: _activeUser!.codigoUnicoUsuario, email: _activeUser!.email,
           fullName: _activeUser!.fullName, phone: _activeUser!.phone, isActive: _activeUser!.isActive, business: updatedBusiness 
         );
      }
      return true;
    } catch (e) {
      _errorMessage = "No pudimos actualizar los datos del negocio.";
      return false;
    } finally {
      notifyListeners();
      _setLoading(false);
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
      return true;
    } catch (e) {
      _errorMessage = "La imagen es muy pesada o formato no compatible.";
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}