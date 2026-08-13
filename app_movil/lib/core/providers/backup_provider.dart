import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:app_movil/core/utils/backup_manager.dart';

class BackupProvider with ChangeNotifier {
  bool _isLoading = false;
  String _errorMessage = "";
  String _statusMessage = "";

  bool _isAutoBackupEnabled = false;
  String _autoBackupLocation = 'Local'; // 'Local' o 'Drive'
  int _autoBackupIntervalDays = 30; // Opciones: 7, 15, 30

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get statusMessage => _statusMessage;
  bool get isAutoBackupEnabled => _isAutoBackupEnabled;
  String get autoBackupLocation => _autoBackupLocation;
  int get autoBackupIntervalDays => _autoBackupIntervalDays;

  BackupProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isAutoBackupEnabled = prefs.getBool('auto_backup_enabled') ?? false;
    _autoBackupLocation = prefs.getString('auto_backup_location') ?? 'Local';
    _autoBackupIntervalDays = prefs.getInt('auto_backup_interval') ?? 30;
    notifyListeners();
  }

  void _reconfigureWorkmanager() {
    final String taskName = "monthlyBackupTask"; 
    
    Workmanager().cancelByUniqueName("backup_periodico_app");

    if (_isAutoBackupEnabled) {
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
    _reconfigureWorkmanager();
    notifyListeners();
  }

  Future<void> setAutoBackupLocation(String location) async {
    _autoBackupLocation = location;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auto_backup_location', location);
    notifyListeners();
  }

  Future<void> setAutoBackupInterval(int days) async {
    _autoBackupIntervalDays = days;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('auto_backup_interval', days);
    _reconfigureWorkmanager();
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

  Future<bool> backupToCloud() async {
    _statusMessage = "Preparando archivo para la Nube...";
    _setLoading(true);
    try {
      bool success = await BackupManager.exportToCloud();
      if (success) await Future.delayed(const Duration(milliseconds: 800)); // UX Delay
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