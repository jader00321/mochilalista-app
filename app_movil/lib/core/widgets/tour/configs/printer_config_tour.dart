import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Claves de widgets para anclaje visual en [PrinterConfigScreen]
class PrinterConfigTourKeys {
  final statusCardKey = GlobalKey();
  final paperWidthKey = GlobalKey();
  final scanBluetoothKey = GlobalKey();
}

/// Configuración pedagógica de la Guía Turística para [PrinterConfigScreen]
class PrinterConfigTour {
  static ScreenTourConfig buildConfig({
    required PrinterConfigTourKeys keys,
  }) {
    return ScreenTourConfig(
      screenId: 'printer_config_screen',
      screenTitle: 'Impresora Térmica Bluetooth',
      welcomeSummary:
          'Conecta tu impresora portátil o de escritorio para imprimir tickets de caja y comprobantes de venta físicos en cualquier momento.',
      icon: Icons.print_rounded,
      steps: [
        TourStep(
          id: 'printer_status_test',
          targetKey: keys.statusCardKey,
          title: 'Estado del Enlace y Ticket de Prueba',
          description:
              'Verifica en un vistazo si tu impresora Bluetooth está lista para emitir comprobantes e imprime un ticket de prueba para calibrar nitidez.',
          tip:
              'Realiza siempre una prueba de impresión al encender tu equipo para asegurar la alineación del cabezal térmico.',
          icon: Icons.check_circle_outline_rounded,
          borderRadius: 20.0,
        ),
        TourStep(
          id: 'printer_paper_width',
          targetKey: keys.paperWidthKey,
          title: 'Formato y Ancho de Papel',
          description:
              'Configura el ancho según tu modelo de impresora: 58 mm para terminales portátiles de mano o 80 mm para impresoras fijas de mostrador.',
          tip:
              'Elegir el ancho exacto evita que los textos del ticket salgan cortados o desfasados.',
          icon: Icons.receipt_long_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'printer_scan_devices',
          targetKey: keys.scanBluetoothKey,
          title: 'Detección y Dispositivos Vinculados',
          description:
              'Empareja primero tu impresora en los ajustes Bluetooth de tu celular Android y presiona refrescar para detectarla y conectarte en un toque.',
          tip:
              'Si no aparece en la lista, verifica que la impresora esté encendida con batería suficiente.',
          icon: Icons.bluetooth_searching_rounded,
          borderRadius: 16.0,
        ),
      ],
    );
  }
}
