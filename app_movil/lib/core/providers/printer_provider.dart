import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterProvider extends ChangeNotifier {
  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;
  
  final List<BluetoothDevice> _printers = [];
  final List<BluetoothDevice> _otherDevices = [];
  BluetoothDevice? _selectedDevice;
  bool _isConnected = false;
  bool _isScanning = false;
  bool _isBluetoothOff = false;
  int _paperWidth = 58; // Por defecto 58mm
  String _statusMessage = "Desconectado";

  List<BluetoothDevice> get printers => _printers;
  List<BluetoothDevice> get otherDevices => _otherDevices;
  BluetoothDevice? get selectedDevice => _selectedDevice;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  bool get isBluetoothOff => _isBluetoothOff;
  int get paperWidth => _paperWidth;
  String get statusMessage => _statusMessage;

  PrinterProvider() {
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    _isScanning = true;
    notifyListeners();

    try {
      bool? isAvailable = await _bluetooth.isAvailable;
      bool? isOn = await _bluetooth.isOn;
      
      if (isAvailable == false || isOn == false) {
        _isBluetoothOff = true;
        _statusMessage = "Bluetooth apagado";
        _isScanning = false;
        notifyListeners();
        return;
      }
      _isBluetoothOff = false;

      bool? isConnected = await _bluetooth.isConnected;
      _isConnected = isConnected ?? false;

      // Cargar configuraciones guardadas
      final prefs = await SharedPreferences.getInstance();
      _paperWidth = prefs.getInt('printer_paper_width') ?? 58;
      String? savedMac = prefs.getString('printer_mac_address');

      final allDevices = await _bluetooth.getBondedDevices();
      _categorizeDevices(allDevices);
      
      // Intentar reconectar si hay un dispositivo guardado
      if (savedMac != null && allDevices.isNotEmpty) {
        try {
          _selectedDevice = allDevices.firstWhere((d) => d.address == savedMac);
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

  void _categorizeDevices(List<BluetoothDevice> devices) {
    _printers.clear();
    _otherDevices.clear();
    
    // Palabras clave comunes en impresoras térmicas
    final printerKeywords = ['printer', 'pos', 'thermal', 'print', '58mm', '80mm', 'esc', 'pt-', 'mpt', 'sp-', 'hoin'];
    
    for (var device in devices) {
      final name = (device.name ?? "").toLowerCase();
      bool isPrinter = printerKeywords.any((kw) => name.contains(kw));
      
      if (isPrinter) {
        _printers.add(device);
      } else {
        _otherDevices.add(device);
      }
    }
  }

  Future<void> scanDevices() async {
    _isScanning = true;
    _statusMessage = "Buscando dispositivos...";
    notifyListeners();
    try {
      bool? isOn = await _bluetooth.isOn;
      if (isOn == false) {
        _isBluetoothOff = true;
        _statusMessage = "Enciende tu Bluetooth";
        _isScanning = false;
        notifyListeners();
        return;
      }
      _isBluetoothOff = false;

      final allDevices = await _bluetooth.getBondedDevices();
      _categorizeDevices(allDevices);
      _statusMessage = allDevices.isEmpty ? "No hay dispositivos vinculados" : "Dispositivos encontrados";
    } catch (e) {
      _isBluetoothOff = true;
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
      _statusMessage = _parseBluetoothError(e);
      _isScanning = false;
      notifyListeners();
      return false;
    }
  }

  String _parseBluetoothError(dynamic error) {
    final str = error.toString().toLowerCase();
    if (str.contains("connect_error")) {
      return "No se pudo conectar. Verifica que la impresora esté encendida.";
    } else if (str.contains("socket might closed") || str.contains("timeout")) {
      return "La conexión tardó mucho. Intenta reiniciar la impresora.";
    } else if (str.contains("ioexception")) {
      return "Error de comunicación. Asegúrate de que sea una impresora.";
    } else if (str.contains("not supported")) {
      return "Dispositivo no compatible con esta conexión.";
    } else {
      return "Error inesperado al conectar. Intenta de nuevo.";
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
      debugPrint("Error desconectando: $e");
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