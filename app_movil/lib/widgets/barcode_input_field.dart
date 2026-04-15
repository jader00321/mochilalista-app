import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class BarcodeInputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;

  const BarcodeInputField({super.key, required this.controller, required this.label});

  @override
  State<BarcodeInputField> createState() => _BarcodeInputFieldState();
}

class _BarcodeInputFieldState extends State<BarcodeInputField> {
  
  Future<void> _scanBarcode() async {
    var status = await Permission.camera.request();
    if (!status.isGranted) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permiso de cámara denegado", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red));
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const _ScannerScreen()),
    );

    if (result != null && result is String) {
      setState(() {
        widget.controller.text = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: widget.controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[700]),
        isDense: true,
        filled: true,
        fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.blue.withOpacity(0.5) : Colors.blue.shade300, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: Icon(Icons.qr_code, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey, size: 22),
        suffixIcon: IconButton(
          icon: Icon(Icons.qr_code_scanner, color: isDark ? Colors.teal[300] : Colors.teal, size: 24),
          onPressed: _scanBarcode,
          tooltip: "Escanear Código",
        ),
      ),
    );
  }
}

class _ScannerScreen extends StatefulWidget {
  const _ScannerScreen();

  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  bool _hasPopped = false; 

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF14141C) : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Escanear Código", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: bgColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_hasPopped) return; 

              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _hasPopped = true; 
                  Navigator.pop(context, barcode.rawValue); 
                  break; 
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 3), 
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)]
              ),
            ),
          ),
          const Positioned(
            bottom: 60, left: 0, right: 0,
            child: Text(
              "Apunta al código de barras",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
            ),
          )
        ],
      ),
    );
  }
}