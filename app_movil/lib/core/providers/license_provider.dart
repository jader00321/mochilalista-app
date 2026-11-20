import 'package:flutter/foundation.dart';
import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/services/license/license_repository.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/config/api_constants.dart';
import 'package:app_movil/core/utils/app_logger.dart';

/// Provider de Gestión de Licencias, Verificación Antifraude y Cuotas IA
class LicenseProvider extends ChangeNotifier {
  final LicenseRepository _repository;

  LicenseModel? _license;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  String _deviceFingerprint = '';
  int _remainingAiScans = 50;
  ClockCheckResult? _clockResult;
  bool _isInitialized = false;

  LicenseProvider({LicenseRepository? repository})
      : _repository = repository ?? LicenseRepository();

  // Getters de Estado
  LicenseModel? get license => _license;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String get deviceFingerprint => _deviceFingerprint;
  int get remainingAiScans => _remainingAiScans;
  ClockCheckResult? get clockResult => _clockResult;
  bool get isInitialized => _isInitialized;

  // Evaluaciones de Estado de Licencia
  bool get isTrial => _license?.isTrial ?? true;
  bool get isPerpetual => _license?.isPerpetual ?? false;
  bool get isActive => _license?.isActive ?? true;
  bool get isExpiringSoon => _license?.status == LicenseStatus.expiringSoon;
  bool get isSoftLock => _license?.status == LicenseStatus.softLock;
  bool get isStrictLock => _license?.status == LicenseStatus.strictLock;
  bool get isPendingMigration => _license?.status == LicenseStatus.pendingMigration;
  bool get isClockDesynced => _license?.status == LicenseStatus.clockDesynced;

  /// Indica si el comerciante puede emitir nuevas transacciones (ventas, cotizaciones, gastos).
  /// En modo BLOQUEO_SUAVE, BLOQUEO_ESTRICTO, PENDIENTE_MIGRACION o RELOJ_DESAJUSTADO, pasa a solo lectura.
  bool get canCreateSales =>
      _license != null &&
      (_license!.status == LicenseStatus.active ||
          _license!.status == LicenseStatus.expiringSoon);

  bool get isUsingCustomApiKey => ApiConstants.isUsingCustomApiKey;

  int get daysRemaining => _license?.daysRemaining ?? 0;
  String get currentPlanName => _license?.plan.dbValue ?? 'TRIAL';
  int get aiAccumulatedScans => _license?.aiAccumulatedScans ?? _remainingAiScans;
  String get aiSelectedMode => _license?.aiSelectedMode ?? 'INCLUDED';
  bool get isUsingByokMode => _license?.isUsingByokMode ?? false;

  /// Inicializa o actualiza la evaluación de la licencia de la app
  Future<void> checkLicense({DateTime? overrideNow}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _deviceFingerprint = await DeviceFingerprint.generate();
      _clockResult = await _repository.checkClockConsistency(overrideNow: overrideNow);
      _license = await _repository.getOrCreateLicense(overrideNow: overrideNow);
      if (_license != null) {
        ApiConstants.setAiSelectedMode(_license!.aiSelectedMode);
      }
      _remainingAiScans = await _repository.getRemainingAiScans(overrideNow: overrideNow);
      _isInitialized = true;
      AppLogger.i('LicenseProvider', 'Licencia evaluada: ${_license?.tipoPlan} (${_license?.estadoActual})');
    } catch (e) {
      _errorMessage = e.toString();
      AppLogger.e('LicenseProvider', 'Error evaluando licencia', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Canjea y activa un código de licencia criptográfica firmado con Ed25519
  Future<bool> redeemCode(String code, {DateTime? overrideNow}) async {
    final clean = code.trim();
    if (clean.isEmpty) {
      _errorMessage = "Por favor, ingresa o escanea un código de activación.";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final updated = await _repository.redeemLicenseCode(clean, overrideNow: overrideNow);
      _license = updated;
      _remainingAiScans = await _repository.getRemainingAiScans(overrideNow: overrideNow);
      _successMessage = "¡Licencia activada con éxito! Plan: ${updated.tipoPlan}";
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verifica si se puede realizar un escaneo IA
  Future<bool> canPerformAiScan({DateTime? overrideNow}) async {
    return await _repository.canPerformAiScan(overrideNow: overrideNow);
  }

  /// Consume un escaneo de cuota IA
  Future<bool> consumeAiScan({DateTime? overrideNow}) async {
    final success = await _repository.consumeAiScan(overrideNow: overrideNow);
    if (success) {
      _license = await _repository.getOrCreateLicense(overrideNow: overrideNow);
      _remainingAiScans = await _repository.getRemainingAiScans(overrideNow: overrideNow);
      notifyListeners();
    }
    return success;
  }

  /// Refresca los escaneos restantes y el modelo de licencia completo
  Future<void> refreshAiScans({DateTime? overrideNow}) async {
    _license = await _repository.getOrCreateLicense(overrideNow: overrideNow);
    _remainingAiScans = await _repository.getRemainingAiScans(overrideNow: overrideNow);
    notifyListeners();
  }

  /// Registra la aceptación del EULA
  Future<void> recordEulaAcceptance(String version) async {
    await _repository.recordEulaAcceptance(version);
    _license = await _repository.getOrCreateLicense();
    _remainingAiScans = await _repository.getRemainingAiScans();
    notifyListeners();
  }

  /// Actualiza la última versión ejecutada
  Future<void> updateLastExecutedVersion(String version) async {
    await _repository.updateLastExecutedAppVersion(version);
    _license = await _repository.getOrCreateLicense();
    _remainingAiScans = await _repository.getRemainingAiScans();
    notifyListeners();
  }

  /// Registra la clave propia BYOK
  Future<void> setCustomApiKey(String key) async {
    await ApiConstants.persistUserCustomApiKey(key);
    _license = await _repository.getOrCreateLicense();
    _remainingAiScans = await _repository.getRemainingAiScans();
    notifyListeners();
  }

  /// Elimina la clave propia BYOK
  Future<void> removeCustomApiKey() async {
    await ApiConstants.clearUserCustomApiKey();
    _license = await _repository.getOrCreateLicense();
    _remainingAiScans = await _repository.getRemainingAiScans();
    notifyListeners();
  }

  /// Modifica el modo seleccionado de IA ('INCLUDED' o 'BYOK')
  Future<void> setAiSelectedMode(String mode) async {
    await _repository.setAiSelectedMode(mode);
    _license = await _repository.getOrCreateLicense();
    _remainingAiScans = await _repository.getRemainingAiScans();
    notifyListeners();
  }

  /// Limpia los mensajes temporales de error o éxito
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
