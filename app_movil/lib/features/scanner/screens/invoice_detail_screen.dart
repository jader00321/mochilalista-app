import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'dart:convert';

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

class InvoiceDetailScreen extends StatefulWidget {
  final int invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  late MultiSplitViewController _splitController;
  InvoiceModel? _invoice;
  bool _isLoading = true;

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
          if (!_showScrollToTop) setState(() => _showScrollToTop = true);
        } else {
          if (_showScrollToTop) setState(() => _showScrollToTop = false);
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

    if (mounted) {
      setState(() {
        _invoice = invoice;
        _linkedPresentations = linked;
        _isLoading = false;
      });
    }
  }

  void _showStatusDialog(bool isDark) {
    if (_invoice == null) return;

    String tempStatus = _invoice!.estado;
    final List<String> opciones = ['procesando', 'revision', 'completado'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Cambiar Estado",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: opciones.map((opcion) {
                return RadioListTile<String>(
                  title: Text(
                    opcion.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(opcion, isDark),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  value: opcion,
                  // ignore: deprecated_member_use
                  groupValue: tempStatus,
                  activeColor: isDark ? Colors.blue[300] : Colors.blue,
                  // ignore: deprecated_member_use
                  onChanged: (val) {
                    setStateDialog(() => tempStatus = val!);
                  },
                );
              }).toList(),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.blue[700] : Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              if (tempStatus != _invoice!.estado) {
                _updateInvoice(estado: tempStatus);
              }
            },
            child: const Text(
              "Guardar",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProviderSearchModal(BuildContext context, bool isDark) {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    String query = "";

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(context, minPadding: kMinDefensiveBottomClearance);
          final filtered = invProv.providers
              .where(
                (p) =>
                    p.nombreEmpresa.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();

          return SafeArea(
            top: false,
            bottom: true,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF23232F) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Vincular Proveedor",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      autofocus: true,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: "Buscar proveedor registrado...",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF14141C)
                            : Colors.grey[100],
                      ),
                      onChanged: (val) => setModalState(() => query = val),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.only(bottom: effectiveBottom + kModalScrollBottomClearance),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: isDark ? Colors.white10 : Colors.grey[200],
                        ),
                        itemBuilder: (ctx, i) {
                          final ProviderModel prov = filtered[i];
                          return ListTile(
                            title: Text(
                              prov.nombreEmpresa,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: prov.ruc != null
                                ? Text("RUC: ${prov.ruc}")
                                : null,
                            onTap: () {
                              Navigator.pop(ctx);
                              _updateInvoice(proveedorId: prov.id);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
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
      if (!mounted) return;
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

  Future<void> _downloadScannedImage([String? providerName]) async {
    if (_invoice == null) return;
    if (_invoice!.imagenUrl.trim().isEmpty ||
        _invoice!.imagenUrl == 'local_ia_scan' ||
        _invoice!.imagenUrl == 'null') {
      CustomSnackBar.show(
        context,
        message: "Esta factura no cuenta con una imagen original disponible para descargar.",
        isError: true,
      );
      return;
    }

    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final String resolvedProviderName = (providerName != null && providerName.isNotEmpty && providerName != "Sin proveedor")
        ? providerName
        : invProv.getProviderName(_invoice!.proveedorId);

    await DownloadFeedbackModal.show(
      context,
      title: "Descargando Imagen",
      loadingMessage: "Guardando foto de comprobante en la carpeta Descargas...",
      downloadTask: () => InvoiceFileService.saveScannedImageToDownloads(
        sourcePath: _invoice!.imagenUrl,
        displayId: _invoice!.displayId,
        providerName: resolvedProviderName,
      ),
    );
  }

  Future<void> _downloadPdfReport(String? providerName, {String? providerRuc}) async {
    if (_invoice == null) return;
    final auth = Provider.of<AuthProvider>(context, listen: false).user;
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final String resolvedProviderName = (providerName != null && providerName.isNotEmpty && providerName != "Sin proveedor")
        ? providerName
        : invProv.getProviderName(_invoice!.proveedorId);
    final provider = invProv.providers.where((p) => p.id == _invoice!.proveedorId).firstOrNull;
    final String? resolvedProviderRuc = providerRuc ?? provider?.ruc;

    await DownloadFeedbackModal.show(
      context,
      title: "Generando Reporte PDF",
      loadingMessage: "Estructurando auditoría y datos extraídos en formato ejecutivo...",
      downloadTask: () => InvoicePdfReportService.generateAndSavePdfReport(
        invoice: _invoice!,
        providerName: resolvedProviderName,
        providerRuc: resolvedProviderRuc,
        currentUser: auth,
        linkedPresentations: _linkedPresentations,
      ),
    );
  }

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
    final provider = invProv.providers.where((p) => p.id == _invoice!.proveedorId).firstOrNull;
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
        title: Text(
          "Factura #${_invoice!.displayId}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.teal[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: "Descargar Imagen Escaneada",
            onPressed: () => _downloadScannedImage(providerName),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: "Descargar Reporte PDF",
            onPressed: () => _downloadPdfReport(providerName, providerRuc: providerRuc),
          ),
          const InfoTooltipButton(
            title: "Detalle y Auditoría de Factura",
            description:
                "Visor interactivo con división de pantalla: compara la foto original de la factura contra los datos extraídos por IA o registrados manualmente.",
            tips: [
              InfoTip(
                icon: Icons.unfold_more_rounded,
                text:
                    "Arrastra la barra divisoria central para expandir el visor de la foto o el listado de productos.",
              ),
              InfoTip(
                icon: Icons.zoom_in_rounded,
                text:
                    "Haz zoom con dos dedos en la imagen de la factura para comprobar precios o códigos borrosos.",
              ),
              InfoTip(
                icon: Icons.checklist_rounded,
                text:
                    "Revisa los ítems vinculados directamente a tus presentaciones de producto y stock en almacén.",
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
                // ZONA 1: VISOR DE IMAGEN
                return Container(
                  color: Colors.black,
                  child: Stack(
                    children: [
                      InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 5.0,
                        child: Center(
                          child: _invoice!.imagenUrl == 'local_ia_scan'
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.image_not_supported_rounded,
                                      size: 60,
                                      color: Colors.grey[700],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "Imagen no disponible\n(Factura Legacy)",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                )
                              : UniversalImage(
                                  path: _invoice!.imagenUrl,
                                  fit: BoxFit.contain,
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "🔍 Zoom interactivo",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                // ZONA 2: AUDITORÍA Y METADATOS
                return Container(
                  color: isDark ? const Color(0xFF14141C) : Colors.grey[50],
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 1. ESTADO Y FECHA
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Fecha Escaneo:",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[600],
                                ),
                              ),
                              // 🔧 TAREA 1.4: Mostrar tipo de factura debajo de la fecha
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    isManualInvoice ? Icons.edit_note_rounded : Icons.document_scanner_outlined,
                                    size: 14,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isManualInvoice ? "Factura Manual" : "Escaneada con IA",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                DateFormat(
                                  "dd MMM yyyy, hh:mm a",
                                ).format(_invoice!.fechaCarga.toLocal()),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () => _showStatusDialog(isDark),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _invoice!.estado.toUpperCase(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.edit,
                                    size: 14,
                                    color: statusColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 2. MONTO TOTAL Y FECHA EMISIÓN (Visual Impactante)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [Colors.teal.shade900, Colors.teal.shade800]
                                : [Colors.teal.shade50, Colors.white],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.teal.shade700
                                : Colors.teal.shade100,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "MONTO TOTAL FACTURADO",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.teal[200]
                                    : Colors.teal[800],
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _invoice!.montoTotalFactura != null
                                  ? "S/ ${_invoice!.montoTotalFactura!.toStringAsFixed(2)}"
                                  : "S/ 0.00",
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.teal[900],
                              ),
                            ),
                            if (_invoice!.fechaEmision != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.black26
                                      : Colors.white54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "F. Emisión: ${DateFormat("dd/MM/yyyy").format(_invoice!.fechaEmision!)}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.teal[100]
                                        : Colors.teal[900],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ACCIONES PROFESIONALES DE DESCARGA
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: const Text(
                                "Descargar Foto",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.blue.withValues(alpha: 0.5)
                                      : Colors.blue.shade300,
                                ),
                                foregroundColor: isDark
                                    ? Colors.blue[300]
                                    : Colors.blue[800],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => _downloadScannedImage(providerName),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                              label: const Text(
                                "Reporte PDF",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? Colors.teal.shade700
                                    : Colors.teal.shade800,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              onPressed: () => _downloadPdfReport(providerName, providerRuc: providerRuc),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3. TARJETA DE PROVEEDOR
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF23232F)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "PROVEEDOR VINCULADO",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[600],
                                  ),
                                ),
                                InkWell(
                                  onTap: () =>
                                      _showProviderSearchModal(context, isDark),
                                  child: Text(
                                    "Cambiar",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.blue[300]
                                          : Colors.blue[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isDark
                                      ? Colors.blue.withValues(alpha: 0.15)
                                      : Colors.blue[50],
                                  child: Icon(
                                    Icons.store,
                                    color: isDark
                                        ? Colors.blue[300]
                                        : Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    providerName.isNotEmpty
                                        ? providerName
                                        : "Sin proveedor asignado",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4. 🔥 AUDITORÍA DE IA (Toggle Interactivo)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF23232F)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.memory,
                                      size: 20,
                                      color: isDark
                                          ? Colors.purple[300]
                                          : Colors.purple,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Auditoría de Extracción",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.purple.withValues(alpha: 0.1)
                                        : Colors.purple[50],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "${_invoice!.cantidadItemsExtraidos ?? 0} ítems",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.purple[200]
                                          : Colors.purple[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Toggle
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.black26
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _showRawJson = false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: !_showRawJson
                                              ? (isDark
                                                    ? Colors.blue[800]
                                                    : Colors.white)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          boxShadow: !_showRawJson && !isDark
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: 0.05,
                                                        ),
                                                    blurRadius: 4,
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        child: Center(
                                          child: Text(
                                            "Vista Detallada",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: !_showRawJson
                                                  ? (isDark
                                                        ? Colors.white
                                                        : Colors.blue[800])
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _showRawJson = true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _showRawJson
                                              ? (isDark
                                                    ? Colors.blue[800]
                                                    : Colors.white)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          boxShadow: _showRawJson && !isDark
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: 0.05,
                                                        ),
                                                    blurRadius: 4,
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        child: Center(
                                          child: Text(
                                            "Código JSON",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: _showRawJson
                                                  ? (isDark
                                                        ? Colors.white
                                                        : Colors.blue[800])
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Contenido del Toggle
                            GestureDetector(
                              onHorizontalDragEnd: (details) {
                                if (details.primaryVelocity! > 0) {
                                  // Swipe Right -> View Details
                                  if (_showRawJson) setState(() => _showRawJson = false);
                                } else if (details.primaryVelocity! < 0) {
                                  // Swipe Left -> View JSON
                                  if (!_showRawJson) setState(() => _showRawJson = true);
                                }
                              },
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (Widget child, Animation<double> animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0.05, 0),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Builder(
                                  key: ValueKey<bool>(_showRawJson),
                                  builder: (context) {
                                  if (_showRawJson) {
                                    return Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF0D0D14)
                                            : Colors.grey[900],
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        _formatJson(_invoice!.datosCrudosIaJson),
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          color: Colors.greenAccent,
                                          fontSize: 11,
                                          height: 1.5,
                                        ),
                                      ),
                                    );
                                  } else if (extractedItems.isEmpty && _linkedPresentations.isEmpty) {
                                    return Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white10
                                            : Colors.grey[50],
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.transparent
                                              : Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.inventory_2_outlined,
                                            size: 40,
                                            color: isDark
                                                ? Colors.grey[600]
                                                : Colors.grey[400],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            "Sin ítems registrados",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "Esta factura no tiene productos extraídos o vinculados.",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? Colors.grey[500]
                                                  : Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else if (extractedItems.isEmpty && _linkedPresentations.isNotEmpty) {
                                    // =========================================================
                                    // 🔧 TAREA 1.4: Vista para facturas manuales
                                    // Mostrar las presentaciones vinculadas por factura_carga_id
                                    // =========================================================
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.teal.withValues(alpha: 0.15) : Colors.teal[50],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_note_rounded, size: 16, color: isDark ? Colors.teal[300] : Colors.teal[700]),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  "${_linkedPresentations.length} presentaciones vinculadas manualmente",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.teal[200] : Colors.teal[800],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: _linkedPresentations.length,
                                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                                          itemBuilder: (ctx, i) {
                                            final pres = _linkedPresentations[i];
                                            final pCosto = (pres['precio_costo'] as num?)?.toDouble();
                                            final pVenta = (pres['precio_venta'] as num?)?.toDouble();
                                            final stock = (pres['cantidad_stock'] as num?)?.toDouble();
                                            return Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: isDark ? Colors.white10 : Colors.grey[50],
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: isDark ? Colors.transparent : Colors.grey.shade300,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    pres['producto_nombre'] ?? "Producto",
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.white : Colors.black87,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    pres['presentacion_nombre'] ?? "Presentación",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Wrap(
                                                    spacing: 12,
                                                    runSpacing: 8,
                                                    children: [
                                                      if (pCosto != null)
                                                        _auditTag("Costo", "S/ ${pCosto.toStringAsFixed(2)}", isDark),
                                                      if (pVenta != null)
                                                        _auditTag("Venta", "S/ ${pVenta.toStringAsFixed(2)}", isDark),
                                                      if (stock != null)
                                                        _auditTag("Stock", stock.toStringAsFixed(stock.truncateToDouble() == stock ? 0 : 1), isDark),
                                                      if (pres['unidad_medida'] != null)
                                                        _auditTag("UMP", pres['unidad_medida'].toString(), isDark),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  } else {
                                    return ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: extractedItems.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 12),
                                      itemBuilder: (ctx, i) {
                                        final item = extractedItems[i];
                                        final String itemDesc = item['descripcion_detectada']?.toString().trim() ?? "Sin descripción";
                                        final String? parent = item['producto_padre_estimado']?.toString().trim();
                                        final String? variant = item['variante_detectada']?.toString().trim();
                                        final String? brand = item['marca_detectada']?.toString().trim();
                                        final String? code = (item['codigo_detectada'] ?? item['codigo_detectado'])?.toString().trim();
                                        final String? uSale = item['unidad_venta']?.toString().trim();

                                        return Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.white10
                                                : Colors.grey[50],
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isDark
                                                  ? Colors.transparent
                                                  : Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: (isDark ? Colors.blue[900] : Colors.blue[50])?.withValues(alpha: 0.8),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(
                                                        color: (isDark ? Colors.blue[700] : Colors.blue[200])!,
                                                        width: 0.8,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      '#${(i + 1).toString().padLeft(2, '0')}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w800,
                                                        color: isDark ? Colors.blue[200] : Colors.blue[800],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      itemDesc.isEmpty ? "Sin descripción" : itemDesc,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.bold,
                                                        color: isDark
                                                            ? Colors.white
                                                            : Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 12,
                                                runSpacing: 8,
                                                children: [
                                                  if (parent != null && parent.isNotEmpty && parent != 'N/A')
                                                    _auditTag("Padre", parent, isDark),
                                                  if (variant != null && variant.isNotEmpty && variant != 'N/A')
                                                    _auditTag("Variante", variant, isDark),
                                                  if (brand != null && brand.isNotEmpty && brand != 'N/A')
                                                    _auditTag("Marca", brand, isDark),
                                                  if (code != null && code.isNotEmpty && code != 'N/A')
                                                    _auditTag("Código", code, isDark),
                                                  if (uSale != null && uSale.isNotEmpty)
                                                    _auditTag("U. Venta", uSale, isDark),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Builder(builder: (context) {
                                                double totalPago = num.tryParse(item['total_pago_lote']?.toString() ?? '0')?.toDouble() ?? 0.0;
                                                double cantidadUmp = num.tryParse(item['cantidad_ump_comprada']?.toString() ?? '1')?.toDouble() ?? 1.0;
                                                int unidadesLote = int.tryParse(item['unidades_por_lote']?.toString() ?? '1') ?? 1;
                                                double precioUmp = num.tryParse(item['precio_ump_proveedor']?.toString() ?? '0')?.toDouble() ?? 0.0;
                                                double costoUnitarioReal = (cantidadUmp > 0 && unidadesLote > 0) 
                                                    ? totalPago / (cantidadUmp * unidadesLote) 
                                                    : 0.0;
                                                String ump = item['ump_compra'] ?? 'UND';
                                                
                                                return Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? Colors.black26 : Colors.white,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text("Compra:", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                                                          const SizedBox(width: 8),
                                                          Flexible(child: Text("$cantidadUmp $ump (x$unidadesLote)", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text("Precio UMP ($ump):", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                                                          const SizedBox(width: 8),
                                                          Flexible(child: Text("S/ ${precioUmp.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text("Costo Unitario Real:", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                                                          const SizedBox(width: 8),
                                                          Flexible(child: Text("S/ ${costoUnitarioReal.toStringAsFixed(3)}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.orange[300] : Colors.orange[800]), textAlign: TextAlign.right)),
                                                        ],
                                                      ),
                                                      const Divider(height: 16),
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text("Total Pagado:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[300] : Colors.grey[800])),
                                                          Text("S/ ${totalPago.toStringAsFixed(2)}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.green[400] : Colors.green[700])),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  }
                                },
                              ),
                             ),
                            ),
                          ],
                        ),
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

  Widget _auditTag(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isDark ? Colors.grey[500] : Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.blue[200] : Colors.blue[800],
          ),
        ),
      ],
    );
  }
}
