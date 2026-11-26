import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/utils/app_date_formatter.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'dart:convert';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import 'package:app_movil/features/scanner/providers/invoice_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/scanner/models/invoice_model.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/features/scanner/services/invoice_file_service.dart';
import 'package:app_movil/features/scanner/services/invoice_pdf_report_service.dart';
import 'package:app_movil/features/scanner/widgets/shared/download_feedback_modal.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

part 'invoice_detail/invoice_detail_modals_and_downloads.dart';
part 'invoice_detail/invoice_detail_photo_and_header.dart';
part 'invoice_detail/invoice_detail_audit_section.dart';
part 'invoice_detail/invoice_detail_audit_cards.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final int invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

abstract class _InvoiceDetailScreenStateBase
    extends State<InvoiceDetailScreen> {
  late MultiSplitViewController _splitController;
  InvoiceModel? _invoice;
  bool _isLoading = true;

  // 📁 Estado persistente de archivos descargados localmente
  File? _downloadedPhotoFile;
  File? _downloadedPdfFile;

  // 🔥 Control del Toggle del visor de Auditoría
  bool _showRawJson = false;

  // 🔧 TAREA 1.4: Presentaciones vinculadas para facturas manuales
  List<Map<String, dynamic>> _linkedPresentations = [];

  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        if (_scrollController.offset > 300) {
          if (!_showScrollToTop) {
            setState(() => _showScrollToTop = true);
          }
        } else {
          if (_showScrollToTop) {
            setState(() => _showScrollToTop = false);
          }
        }
      }
    });

    _splitController = MultiSplitViewController(
      areas: [
        Area(size: 0.25, min: 0.15), // Imagen de la factura
        Area(size: 0.75, min: 0.40), // Datos de auditoría
      ],
    );
    _loadInvoiceDetails();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _splitController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoiceDetails() async {
    setState(() => _isLoading = true);
    final invcProv = Provider.of<InvoiceProvider>(context, listen: false);
    final invoice = await invcProv.getInvoiceDetail(widget.invoiceId);

    // 🔧 TAREA 1.4: Si la factura es manual (sin datos IA), cargar presentaciones vinculadas
    List<Map<String, dynamic>> linked = [];
    if (invoice != null && invoice.datosCrudosIaJson == null) {
      linked = await invcProv.getLinkedPresentations(widget.invoiceId);
    }

    // 🔍 Detección de archivos ya existentes en Descargas
    File? existingPhoto;
    File? existingPdf;
    if (invoice != null) {
      existingPhoto = await InvoiceFileService.findExistingInvoiceFile(
        displayId: invoice.displayId,
        isPdfReport: false,
      );
      existingPdf = await InvoiceFileService.findExistingInvoiceFile(
        displayId: invoice.displayId,
        isPdfReport: true,
      );
    }

    if (mounted) {
      setState(() {
        _invoice = invoice;
        _linkedPresentations = linked;
        _downloadedPhotoFile = existingPhoto;
        _downloadedPdfFile = existingPdf;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateInvoice({String? estado, int? proveedorId}) async {
    final invcProv = Provider.of<InvoiceProvider>(context, listen: false);
    CustomSnackBar.show(context, message: "Actualizando...", isError: false);

    bool success = await invcProv.updateInvoice(
      widget.invoiceId,
      estado: estado,
      proveedorId: proveedorId,
    );
    if (success && mounted) {
      await _loadInvoiceDetails();
      if (!mounted) {
        return;
      }
      CustomSnackBar.show(
        context,
        message: "Factura actualizada con éxito",
        isError: false,
      );
    } else if (mounted) {
      CustomSnackBar.show(
        context,
        message: "Error al actualizar factura",
        isError: true,
      );
    }
  }

  Color _getStatusColor(String status, bool isDark) {
    switch (status.toLowerCase()) {
      case 'completado':
        return isDark ? Colors.green[400]! : Colors.green[700]!;
      case 'revision':
        return isDark ? Colors.orange[400]! : Colors.orange[700]!;
      case 'procesando':
        return isDark ? Colors.blue[400]! : Colors.blue[700]!;
      default:
        return isDark ? Colors.grey[400]! : Colors.grey[700]!;
    }
  }

  String _formatJson(Map<String, dynamic>? jsonInput) {
    if (jsonInput == null) {
      return "Esta factura fue procesada con una versión anterior del sistema que no guardaba los datos crudos (JSON) de la IA.";
    }
    final encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(jsonInput);
  }

  void _showStatusDialog(bool isDark);
  void _showProviderSearchModal(BuildContext context, bool isDark);
  Future<void> _handleScannedImageAction([String? providerName]);
  Future<void> _handlePdfReportAction(
    String? providerName, {
    String? providerRuc,
  });
  Widget _buildImageZone();
  Widget _buildSummaryHeaderSection({
    required bool isDark,
    required bool isManualInvoice,
    required Color statusColor,
    required String providerName,
    required String? providerRuc,
  });
  Widget _buildProviderCard(bool isDark, String providerName);
  Widget _buildAuditSection({
    required bool isDark,
    required List<dynamic> extractedItems,
  });
  Widget _buildExtractedAiItemsList(bool isDark, List<dynamic> extractedItems);
  Widget _auditTag(String label, String value, bool isDark);
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final invProv = Provider.of<InventoryProvider>(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(title: const Text("Cargando Factura...")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_invoice == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(title: const Text("Error")),
        body: const Center(child: Text("Factura no encontrada.")),
      );
    }

    final statusColor = _getStatusColor(_invoice!.estado, isDark);
    final providerName = invProv.getProviderName(_invoice!.proveedorId);
    final provider = invProv.providers
        .where((p) => p.id == _invoice!.proveedorId)
        .firstOrNull;
    final String? providerRuc = provider?.ruc;

    // Obtener los ítems extraídos del JSON (facturas escaneadas con IA)
    List<dynamic> extractedItems = [];
    if (_invoice!.datosCrudosIaJson != null &&
        _invoice!.datosCrudosIaJson!['items'] != null) {
      extractedItems = _invoice!.datosCrudosIaJson!['items'];
    }

    // 🔧 TAREA 1.4: Determinar si es factura manual
    final bool isManualInvoice = _invoice!.datosCrudosIaJson == null;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            "Factura #${_invoice!.displayId}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.teal[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          const InfoTooltipButton(
            iconColor: Colors.white,
            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.all(6),
            title: "Detalle y Auditoría de Factura",
            description:
                "Visor interactivo con división de pantalla: contrasta la foto original del comprobante contra los datos procesados por IA o ingresados manualmente.",
            tips: [
              InfoTip(
                icon: Icons.unfold_more_rounded,
                text:
                    "Arrastra la barra divisoria central para ampliar el visor de imagen o revisar con comodidad el detalle inferior.",
              ),
              InfoTip(
                icon: Icons.zoom_in_rounded,
                text:
                    "Pellizca con dos dedos sobre la factura para comprobar importes, RUC o códigos pequeños.",
              ),
              InfoTip(
                icon: Icons.checklist_rounded,
                text:
                    "Inspecciona presentaciones vinculadas, datos crudos de auditoría IA y descarga de respaldo en Descargas.",
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: MultiSplitViewTheme(
          data: MultiSplitViewThemeData(dividerThickness: 24),
          child: MultiSplitView(
            axis: Axis.vertical,
            controller: _splitController,
            dividerBuilder:
                (axis, index, resizable, dragging, highlighted, themeData) {
                  return Container(
                    color: isDark ? const Color(0xFF1A1A24) : Colors.grey[200],
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: dragging
                            ? (isDark
                                  ? Colors.blue.withValues(alpha: 0.3)
                                  : Colors.blue[100])
                            : (isDark ? const Color(0xFF23232F) : Colors.white),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: dragging
                              ? Colors.transparent
                              : (isDark
                                    ? Colors.white10
                                    : Colors.grey.shade300),
                        ),
                      ),
                      child: Icon(
                        Icons.drag_handle,
                        size: 16,
                        color: dragging
                            ? Colors.blue
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ),
                  );
                },
            builder: (BuildContext context, Area area) {
              if (area.index == 0) {
                return _buildImageZone();
              } else {
                // ZONA 2: AUDITORÍA Y METADATOS
                return Container(
                  color: isDark ? const Color(0xFF14141C) : Colors.grey[50],
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSummaryHeaderSection(
                        isDark: isDark,
                        isManualInvoice: isManualInvoice,
                        statusColor: statusColor,
                        providerName: providerName,
                        providerRuc: providerRuc,
                      ),
                      const SizedBox(height: 16),
                      _buildProviderCard(isDark, providerName),
                      const SizedBox(height: 20),
                      _buildAuditSection(
                        isDark: isDark,
                        extractedItems: extractedItems,
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                );
              }
            },
          ),
        ),
      ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton(
              mini: true,
              onPressed: () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              },
              backgroundColor: isDark ? Colors.blue[700] : Colors.blue,
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            )
          : null,
    );
  }
}

class _InvoiceDetailScreenState extends _InvoiceDetailScreenStateBase
    with
        _InvoiceDetailModalsAndDownloadsMixin,
        _InvoiceDetailPhotoAndHeaderMixin,
        _InvoiceDetailAuditSectionMixin,
        _InvoiceDetailAuditCardsMixin {}
