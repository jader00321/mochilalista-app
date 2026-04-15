import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterProvider extends ChangeNotifier {
  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;
  
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isConnected = false;
  bool _isScanning = false;
  int _paperWidth = 58; // Por defecto 58mm
  String _statusMessage = "Desconectado";

  List<BluetoothDevice> get devices => _devices;
  BluetoothDevice? get selectedDevice => _selectedDevice;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  int get paperWidth => _paperWidth;
  String get statusMessage => _statusMessage;

  PrinterProvider() {
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    _isScanning = true;
    notifyListeners();

    try {
      bool? isConnected = await _bluetooth.isConnected;
      _isConnected = isConnected ?? false;

      // Cargar configuraciones guardadas
      final prefs = await SharedPreferences.getInstance();
      _paperWidth = prefs.getInt('printer_paper_width') ?? 58;
      String? savedMac = prefs.getString('printer_mac_address');

      _devices = await _bluetooth.getBondedDevices();
      
      // Intentar reconectar si hay un dispositivo guardado
      if (savedMac != null && _devices.isNotEmpty) {
        try {
          _selectedDevice = _devices.firstWhere((d) => d.address == savedMac);
          if (!_isConnected && _selectedDevice != null) {
            _statusMessage = "Conectando a impresora guardada...";
            notifyListeners();
            await _bluetooth.connect(_selectedDevice!);
            _isConnected = true;
            _statusMessage = "Conectado";
          }
        } catch (e) {
          _statusMessage = "Impresora guardada no encontrada";
        }
      }
    } catch (e) {
      _statusMessage = "Error al iniciar Bluetooth";
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> scanDevices() async {
    _isScanning = true;
    _statusMessage = "Buscando dispositivos...";
    notifyListeners();
    try {
      _devices = await _bluetooth.getBondedDevices();
      _statusMessage = _devices.isEmpty ? "No hay dispositivos vinculados" : "Dispositivos encontrados";
    } catch (e) {
      _statusMessage = "Asegúrate de encender el Bluetooth";
    }
    _isScanning = false;
    notifyListeners();
  }

  Future<bool> connectDevice(BluetoothDevice device) async {
    _isScanning = true;
    _statusMessage = "Conectando a ${device.name}...";
    notifyListeners();

    try {
      bool? isConnected = await _bluetooth.isConnected;
      if (isConnected == true) {
        await _bluetooth.disconnect();
      }
      
      await _bluetooth.connect(device);
      _selectedDevice = device;
      _isConnected = true;
      _statusMessage = "Conectado a ${device.name}";

      // Guardar en memoria para autoconexión futura
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_mac_address', device.address ?? "");

      _isScanning = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isConnected = false;
      _statusMessage = "Error al conectar: ${e.toString()}";
      _isScanning = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _bluetooth.disconnect();
      _isConnected = false;
      _selectedDevice = null;
      _statusMessage = "Desconectado";
      
      // Borrar de la memoria
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('printer_mac_address');
      
      notifyListeners();
    } catch (e) {
      print("Error desconectando: $e");
    }
  }

  Future<void> setPaperWidth(int width) async {
    _paperWidth = width;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('printer_paper_width', width);
    notifyListeners();
  }

  // --- FUNCIÓN DE PRUEBA DE IMPRESIÓN ---
  Future<bool> testPrint() async {
    if (!_isConnected) return false;
    try {
      _bluetooth.printNewLine();
      _bluetooth.printCustom("MochilaLista POS", 2, 1); // 2: Bold+Large, 1: Center
      _bluetooth.printNewLine();
      _bluetooth.printCustom("Prueba de Impresion Exitosa!", 1, 1);
      _bluetooth.printCustom("Ancho configurado: ${_paperWidth}mm", 0, 1);
      _bluetooth.printNewLine();
      _bluetooth.printCustom("--------------------------------", 0, 1);
      _bluetooth.printNewLine();
      _bluetooth.printNewLine();
      return true;
    } catch (e) {
      return false;
    }
  }
}