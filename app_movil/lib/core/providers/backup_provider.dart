import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:app_movil/core/utils/backup_manager.dart';

class BackupProvider with ChangeNotifier {
  bool _isLoading = false;
  String _errorMessage = "";
  String _statusMessage = "";

  bool _isAutoBackupEnabled = false;
  String _autoBackupType = 'global'; // 'global', 'perfil', 'ambos'
  String _autoBackupLocation = 'Local'; // 'Local', 'Drive', 'custom'
  String? _autoBackupCustomPath;
  int _autoBackupIntervalDays = 7; // Opciones: 1, 7, 15, 30
  int _lastRegisterTime = 0;
  int _lastRunTime = 0;

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get statusMessage => _statusMessage;
  bool get isAutoBackupEnabled => _isAutoBackupEnabled;
  String get autoBackupType => _autoBackupType;
  String get autoBackupLocation => _autoBackupLocation;
  String? get autoBackupCustomPath => _autoBackupCustomPath;
  int get autoBackupIntervalDays => _autoBackupIntervalDays;
  int get lastRegisterTime => _lastRegisterTime;
  int get lastRunTime => _lastRunTime;

  BackupProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isAutoBackupEnabled = prefs.getBool('auto_backup_enabled') ?? false;
    _autoBackupType = prefs.getString('auto_backup_type') ?? 'global';
    _autoBackupLocation = prefs.getString('auto_backup_location') ?? 'Local';
    _autoBackupCustomPath = prefs.getString('auto_backup_custom_path');
    _autoBackupIntervalDays = prefs.getInt('auto_backup_interval') ?? 7;
    _lastRegisterTime = prefs.getInt('last_auto_backup_register_time') ?? 0;
    _lastRunTime = prefs.getInt('last_auto_backup_run_time') ?? 0;
    notifyListeners();
  }

  Future<void> reloadTimestamps() async {
    final prefs = await SharedPreferences.getInstance();
    _lastRegisterTime = prefs.getInt('last_auto_backup_register_time') ?? 0;
    _lastRunTime = prefs.getInt('last_auto_backup_run_time') ?? 0;
    notifyListeners();
  }

  Future<void> _reconfigureWorkmanager() async {
    final String taskName = "monthlyBackupTask"; 
    
    Workmanager().cancelByUniqueName("backup_periodico_app");

    if (_isAutoBackupEnabled) {
      final prefs = await SharedPreferences.getInstance();
      _lastRegisterTime = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('last_auto_backup_register_time', _lastRegisterTime);
      notifyListeners();

      Workmanager().registerPeriodicTask(
        "backup_periodico_app",
        taskName,
        frequency: Duration(days: _autoBackupIntervalDays),
        initialDelay: const Duration(minutes: 15), 
        constraints: Constraints(
          networkType: NetworkType.connected, 
          requiresBatteryNotLow: true, 
        ),
      );
    }
  }

  Future<void> toggleAutoBackup(bool value) async {
    _isAutoBackupEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup_enabled', value);
    await _reconfigureWorkmanager();
    notifyListeners();
  }

  Future<void> setAutoBackupType(String value, {int? negocioId, String? negocioNombre}) async {
    _autoBackupType = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auto_backup_type', value);
    if (value == 'perfil' && negocioId != null && negocioNombre != null) {
      await prefs.setInt('auto_backup_negocio_id', negocioId);
      await prefs.setString('auto_backup_negocio_nombre', negocioNombre);
    }
    notifyListeners();
  }

  Future<void> setAutoBackupLocation(String location, {String? customPath}) async {
    _autoBackupLocation = location;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auto_backup_location', location);
    
    if (location == 'custom' && customPath != null) {
      _autoBackupCustomPath = customPath;
      await prefs.setString('auto_backup_custom_path', customPath);
    }
    
    notifyListeners();
  }

  Future<void> setAutoBackupInterval(int days) async {
    _autoBackupIntervalDays = days;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('auto_backup_interval', days);
    await _reconfigureWorkmanager();
    notifyListeners();
  }

  Future<bool> backupToWhatsApp() async {
    _setLoading(true);
    try {
      bool success = await BackupManager.exportToWhatsApp();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> backupToDownloads() async {
    _statusMessage = "Guardando en Descargas...";
    _setLoading(true);
    try {
      bool success = await BackupManager.exportToDownloads();
      if (success) await Future.delayed(const Duration(seconds: 1)); // UX Delay
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
      _statusMessage = "";
    }
  }



  Future<bool> restoreDatabase() async {
    _statusMessage = "Inyectando datos en la base de datos...";
    _setLoading(true);
    try {
      bool success = await BackupManager.restoreBackup();
      if (success) {
        _statusMessage = "¡Datos Restaurados con Éxito!";
        notifyListeners();
        await Future.delayed(const Duration(seconds: 2)); // UX Delay for animation to be seen
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
      _statusMessage = "";
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}