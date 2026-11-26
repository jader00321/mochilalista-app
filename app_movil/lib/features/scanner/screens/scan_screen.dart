import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// Providers
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';

// Pantallas de Destino
import 'package:app_movil/features/profile/screens/ai_settings_screen.dart';
import 'package:app_movil/features/scanner/screens/invoice_history_screen.dart';
import 'package:app_movil/features/scanner/screens/invoice_review_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/extraction_result_screen.dart';

// Widgets, seguridad y tour
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/utils/hardware_validator.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/tour/configs/invoice_scan_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/quotation_scan_tour.dart';
import 'package:app_movil/features/scanner/widgets/shared/scanning_dialog.dart';

part 'scan/scan_actions_and_modals.dart';
part 'scan/scan_quotation_and_error_panels.dart';
part 'scan/scan_invoice_panel.dart';

class ScanScreen extends StatefulWidget {
  final ScanMode mode;
  final bool autoTriggerTour;
  final InvoiceScanTourKeys? invoiceTourKeys;
  final QuotationScanTourKeys? quotationTourKeys;

  const ScanScreen({
    super.key,
    this.mode = ScanMode.quotation,
    this.autoTriggerTour = true,
    this.invoiceTourKeys,
    this.quotationTourKeys,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  late final InvoiceScanTourKeys _invoiceTourKeys;
  late final QuotationScanTourKeys _quotationTourKeys;

  // Caché de Imagen y Estado de Error
  File? _cachedImageFile;
  bool _hasError = false;
  String _errorMessage = "";

  void _refreshState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _invoiceTourKeys = widget.invoiceTourKeys ?? InvoiceScanTourKeys();
    _quotationTourKeys = widget.quotationTourKeys ?? QuotationScanTourKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.autoTriggerTour) {
        if (widget.mode == ScanMode.invoice) {
          InteractiveTourService.maybeStartAutomaticTour(
            context,
            InvoiceScanTour.buildConfig(keys: _invoiceTourKeys),
          );
        } else {
          InteractiveTourService.maybeStartAutomaticTour(
            context,
            QuotationScanTour.buildConfig(keys: _quotationTourKeys),
          );
        }
      }
    });
  }

  void _startInvoiceTour(BuildContext context) {
    InteractiveTourService.startManualTour(
      context,
      InvoiceScanTour.buildConfig(keys: _invoiceTourKeys),
    );
  }

  void _startQuotationTour(BuildContext context) {
    InteractiveTourService.startManualTour(
      context,
      QuotationScanTour.buildConfig(keys: _quotationTourKeys),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context, bool isQuotation) {
    if (isQuotation) {
      return [
        InfoTooltipButton(
          title: "Escanear Lista",
          description:
              "Digitaliza listas de compras, pedidos al por mayor o requerimientos escolares a partir de fotos o documentos con Inteligencia Artificial.",
          onStartInteractiveTour: () => _startQuotationTour(context),
          tips: const [
            InfoTip(
              icon: Icons.tune_rounded,
              text:
                  "Reconoce automáticamente listas de compras, pedidos y escolares.",
            ),
            InfoTip(
              icon: Icons.camera_alt_outlined,
              text:
                  "Captura fotos en papel o importa imágenes recibidas por WhatsApp.",
            ),
            InfoTip(
              icon: Icons.person_search_outlined,
              text:
                  "Asigna la cotización al instante a clientes registrados o nuevos.",
            ),
          ],
        ),
        const SizedBox(width: 4),
      ];
    }

    return [
      IconButton(
        key: _invoiceTourKeys.historyButtonKey,
        tooltip: 'Historial de Facturas',
        icon: const Icon(Icons.receipt_long_rounded),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const InvoiceHistoryScreen(),
            ),
          );
        },
      ),
      InfoTooltipButton(
        title: "Escanear Factura",
        description:
            "Digitaliza facturas físicas y boletas de compra de tus proveedores con Inteligencia Artificial para actualizar tu stock y costos al instante.",
        onStartInteractiveTour: () => _startInvoiceTour(context),
        tips: const [
          InfoTip(
            icon: Icons.camera_alt_outlined,
            text: "Toma la foto directamente desde arriba con buena luz.",
          ),
          InfoTip(
            icon: Icons.payments_outlined,
            text: "Revisa precios unitarios y márgenes antes de confirmar.",
          ),
          InfoTip(
            icon: Icons.sync_rounded,
            text: "El inventario se repone automáticamente al guardar.",
          ),
        ],
      ),
      const SizedBox(width: 4),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isQuotation = widget.mode == ScanMode.quotation;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isGuest = auth.activeBusinessId == null;

    final String title = isQuotation ? "Escanear Lista" : "Escanear Factura";
    final String subtitle = isQuotation
        ? "Toma una foto clara de cualquier lista de compras, pedido al por mayor, requerimiento de negocio o lista escolar."
        : "Sube tu factura de compra para procesar y reponer el stock.";
    final IconData mainIcon = isQuotation
        ? Icons.document_scanner_rounded
        : Icons.receipt_long_rounded;
    final Color mainColor = isQuotation ? Colors.blue : Colors.teal;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF14141C) : Colors.white,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        centerTitle: true,
        actions: _buildAppBarActions(context, isQuotation),
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 12,
            bottom: math.max(MediaQuery.viewPaddingOf(context).bottom, 16) + 16,
          ),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _hasError
                    ? _buildErrorPanel(isDark, mainColor)
                    : (isQuotation
                          ? _buildQuotationMainPanel(
                              isDark,
                              mainColor,
                              mainIcon,
                              subtitle,
                              isGuest,
                            )
                          : _buildInvoiceMainPanel(isDark, isGuest)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
