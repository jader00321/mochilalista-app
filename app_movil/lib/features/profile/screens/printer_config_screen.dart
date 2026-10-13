import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:app_movil/core/providers/printer_provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';

class PrinterConfigScreen extends StatelessWidget {
  const PrinterConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final printerProv = Provider.of<PrinterProvider>(context);

    // 🔥 USAMOS LOS COLORES GLOBALES DEL TEMA
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Impresora Térmica", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          const InfoTooltipButton(
            title: "Impresora Térmica Bluetooth",
            description:
                "Conecta tu impresora de tickets portátil o de escritorio para imprimir comprobantes de venta y tickets de caja al instante.",
            tips: [
              InfoTip(
                icon: Icons.bluetooth_searching_rounded,
                text:
                    "Primero vincula la impresora en los Ajustes de Bluetooth de tu celular Android.",
              ),
              InfoTip(
                icon: Icons.refresh_rounded,
                text:
                    "Presiona el botón de refrescar para detectar los dispositivos Bluetooth emparejados.",
              ),
              InfoTip(
                icon: Icons.receipt_outlined,
                text:
                    "Configura el ancho de papel correcto (58mm para mini portátil o 80mm para escritorio).",
              ),
              InfoTip(
                icon: Icons.print_rounded,
                text:
                    "Usa 'Prueba de Impresión' para verificar la conexión y la nitidez del ticket impreso.",
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: () => printerProv.scanDevices(),
            tooltip: "Buscar dispositivos",
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (printerProv.isBluetoothOff)
              _buildBluetoothBanner(isDark),

            _buildStatusCard(context, printerProv, isDark, cardColor),
            const SizedBox(height: 30),

            Text("Configuración de Papel", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.blue[300] : Colors.blue[800])),
            const SizedBox(height: 6),
            Text("Selecciona el ancho que usa tu impresora.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildPaperOption("58mm", "Mini portátil", 58, printerProv.paperWidth, isDark, () => printerProv.setPaperWidth(58))),
                const SizedBox(width: 15),
                Expanded(child: _buildPaperOption("80mm", "De escritorio", 80, printerProv.paperWidth, isDark, () => printerProv.setPaperWidth(80))),
              ],
            ),
            const SizedBox(height: 35),

            Text("Dispositivos Vinculados", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.blue[300] : Colors.blue[800])),
            const SizedBox(height: 6),
            Text("Asegúrate de haber emparejado la impresora en los ajustes Bluetooth de tu celular primero.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 15),

            if (printerProv.isScanning)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (printerProv.printers.isEmpty && printerProv.otherDevices.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    Icon(Icons.bluetooth_disabled, size: 45, color: isDark ? Colors.grey[600] : Colors.grey),
                    const SizedBox(height: 12),
                    Text("No se encontraron dispositivos vinculados.", textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 15)),
                  ],
                ),
              )
            else ...[
              if (printerProv.printers.isNotEmpty) ...[
                Text("Posibles Impresoras", style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.green[300] : Colors.green[700], fontSize: 14)),
                const SizedBox(height: 8),
                _buildDeviceList(context, printerProv.printers, printerProv, isDark, cardColor, textColor, true),
                const SizedBox(height: 20),
              ],
              
              if (printerProv.otherDevices.isNotEmpty)
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text("Otros dispositivos Bluetooth", style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 14)),
                    children: [
                      _buildDeviceList(context, printerProv.otherDevices, printerProv, isDark, cardColor, textColor, false),
                    ],
                  ),
                ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bluetooth_disabled, color: Colors.orange, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Bluetooth Apagado", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 16)),
                const SizedBox(height: 4),
                Text("Enciende el Bluetooth para conectar tu impresora.", style: TextStyle(color: isDark ? Colors.orange[200] : Colors.orange[900], fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(BuildContext context, List<BluetoothDevice> devices, PrinterProvider prov, bool isDark, Color cardColor, Color textColor, bool isPrinterList) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final device = devices[index];
        final isSelected = prov.selectedDevice?.address == device.address && prov.isConnected;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          tileColor: isSelected ? (isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green[50]) : cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: isSelected ? BorderSide(color: Colors.green.shade400, width: 1.5) : BorderSide.none),
          leading: Icon(isPrinterList ? Icons.print : Icons.bluetooth, color: isSelected ? Colors.green : (isDark ? (isPrinterList ? Colors.blue[300] : Colors.grey[400]) : Colors.grey), size: 28),
          title: Text(device.name ?? "Desconocido", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
          subtitle: Text(device.address ?? "Sin MAC", style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])),
          trailing: isSelected 
            ? ElevatedButton(
                onPressed: () => prov.disconnect(),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.1), foregroundColor: Colors.red, elevation: 0),
                child: const Text("Desconectar", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            : ElevatedButton(
                onPressed: () async {
                  bool success = await prov.connectDevice(device);
                  if (context.mounted && !success) {
                    CustomSnackBar.show(context, message: prov.statusMessage, isError: true);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue[50], foregroundColor: isDark ? Colors.blue[300] : Colors.blue[800], elevation: 0),
                child: const Text("Conectar", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
        );
      },
    );
  }

  Widget _buildStatusCard(BuildContext context, PrinterProvider prov, bool isDark, Color defaultCardColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: prov.isConnected ? LinearGradient(
          colors: isDark ? [Colors.green[800]!.withValues(alpha: 0.4), Colors.green[900]!.withValues(alpha: 0.6)] 
                        : [Colors.green[500]!, Colors.green[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ) : null,
        color: prov.isConnected ? null : defaultCardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Icon(prov.isConnected ? Icons.check_circle : Icons.print_disabled, size: 55, color: prov.isConnected ? (isDark ? Colors.green[400] : Colors.white) : (isDark ? Colors.grey[600] : Colors.grey)),
          const SizedBox(height: 12),
          Text(prov.statusMessage, textAlign: TextAlign.center, style: TextStyle(color: prov.isConnected ? (isDark ? Colors.green[100] : Colors.white) : (isDark ? Colors.white : Colors.grey[800]), fontSize: 18, fontWeight: FontWeight.bold)),
          if (prov.isConnected && prov.selectedDevice != null)
             Text(prov.selectedDevice!.name ?? "", style: TextStyle(color: prov.isConnected ? (isDark ? Colors.green[200] : Colors.white70) : Colors.grey, fontSize: 13)),

          if (prov.isConnected) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                bool printed = await prov.testPrint();
                if (context.mounted) {
                  if (printed) {
                    CustomSnackBar.show(context, message: "Enviando prueba...", isError: false);
                  } else {
                    CustomSnackBar.show(context, message: "Fallo al enviar impresión", isError: true);
                  }
                }
              },
              icon: const Icon(Icons.receipt_long),
              label: const Text("IMPRIMIR PRUEBA", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.green[700] : Colors.white,
                foregroundColor: isDark ? Colors.white : Colors.green[800],
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildPaperOption(String title, String subtitle, int value, int groupValue, bool isDark, VoidCallback onTap) {
    bool isSelected = value == groupValue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue[50]) : (isDark ? const Color(0xFF2C2C3A) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? (isDark ? Colors.blue[300]! : Colors.blue) : Colors.transparent, width: 2),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt, color: isSelected ? (isDark ? Colors.blue[300] : Colors.blue) : Colors.grey, size: 32),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isSelected ? (isDark ? Colors.blue[300] : Colors.blue) : (isDark ? Colors.white70 : Colors.grey[700]))),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: isSelected ? (isDark ? Colors.blue[200] : Colors.blue[800]) : (isDark ? Colors.grey[400] : Colors.grey[600]))),
          ],
        ),
      ),
    );
  }
}