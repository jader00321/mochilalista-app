import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart'; 
import 'package:provider/provider.dart';

import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart'; 
import 'package:app_movil/core/providers/auth_provider.dart'; 
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/models/pdf_config_model.dart'; 
import 'package:app_movil/features/smart_quotation/utils/pdf_generator.dart'; 
import 'package:app_movil/features/smart_quotation/services/pdf_preferences_service.dart';
import 'package:app_movil/features/scanner/services/invoice_file_service.dart';
import 'package:app_movil/features/scanner/widgets/shared/download_feedback_modal.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/client_search_modal.dart';
import 'package:app_movil/core/database/local_db.dart';

/// 📱 PANTALLA DE VISTA PREVIA PDF ("MOBILE AWARDS")
/// Incorpora barra de controles rápidos (A4 vs Ticket 80mm + paleta cromática),
/// botón directo de descarga con modal animado y feedback háptico,
/// zoom interactivo con InteractiveViewer y TransformationController,
/// e hidratación garantizada de imágenes desde SQLite.
class PdfPreviewScreen extends StatefulWidget {
  final int? quotationId; 
  final int? saleId;      

  const PdfPreviewScreen({super.key, this.quotationId, this.saleId});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> with SingleTickerProviderStateMixin {
  late PdfConfig _config;
  SmartQuotationModel? _quotation;
  Map<String, dynamic>? _saleData;
  bool _loadingData = true;

  // 🔍 Variables de Zoom Interactivo y Píldora Auto-desvanecible
  late final TransformationController _zoomController;
  late final AnimationController _zoomAnimController;
  Animation<Matrix4>? _zoomAnimation;
  double _currentScale = 1.0;
  bool _showZoomPill = true;
  Timer? _zoomPillTimer;

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _clientNameCtrl = TextEditingController();
  final TextEditingController _footerNoteCtrl = TextEditingController();
  final TextEditingController _instNameCtrl = TextEditingController();
  final TextEditingController _gradeLevelCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _paymentAccountsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _config = PdfConfig(); 
    _zoomController = TransformationController();
    _zoomController.addListener(_onZoomChanged);
    _zoomAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _zoomController.value = _zoomAnimation!.value;
        }
      });

    _zoomPillTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _showZoomPill) {
        setState(() => _showZoomPill = false);
      }
    });

    _loadData();
  }

  void _onZoomChanged() {
    final scale = _zoomController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.01) {
      setState(() {
        _currentScale = scale;
      });
      _dismissZoomPill();
    }
  }

  void _dismissZoomPill() {
    if (_showZoomPill) {
      _zoomPillTimer?.cancel();
      setState(() => _showZoomPill = false);
    }
  }

  void _handleDoubleTap(TapDownDetails details) {
    HapticFeedback.selectionClick();
    final double targetScale = _currentScale > 1.2 ? 1.0 : 1.8;
    final Matrix4 endMatrix;
    if (targetScale == 1.0) {
      endMatrix = Matrix4.identity();
    } else {
      final position = details.localPosition;
      endMatrix = Matrix4.identity()
        ..setEntry(0, 0, targetScale)
        ..setEntry(1, 1, targetScale)
        ..setEntry(0, 3, -position.dx * (targetScale - 1))
        ..setEntry(1, 3, -position.dy * (targetScale - 1));
    }
    _animateToMatrix(endMatrix);
  }

  void _animateToMatrix(Matrix4 endMatrix) {
    _zoomAnimation = Matrix4Tween(
      begin: _zoomController.value,
      end: endMatrix,
    ).animate(CurvedAnimation(parent: _zoomAnimController, curve: Curves.easeOutCubic));
    _zoomAnimController.forward(from: 0);
    _dismissZoomPill();
  }

  void _zoomIn() {
    HapticFeedback.selectionClick();
    final nextScale = (_currentScale + 0.25).clamp(1.0, 3.0);
    _animateToMatrix(Matrix4.diagonal3Values(nextScale, nextScale, 1.0));
  }

  void _zoomOut() {
    HapticFeedback.selectionClick();
    final nextScale = (_currentScale - 0.25).clamp(1.0, 3.0);
    _animateToMatrix(Matrix4.diagonal3Values(nextScale, nextScale, 1.0));
  }

  void _resetZoom() {
    HapticFeedback.mediumImpact();
    _animateToMatrix(Matrix4.identity());
  }

  @override
  void dispose() {
    _zoomPillTimer?.cancel();
    _zoomAnimController.dispose();
    _zoomController.removeListener(_onZoomChanged);
    _zoomController.dispose();
    _titleCtrl.dispose();
    _clientNameCtrl.dispose();
    _footerNoteCtrl.dispose();
    _instNameCtrl.dispose();
    _gradeLevelCtrl.dispose();
    _notesCtrl.dispose();
    _paymentAccountsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    try {
      if (widget.saleId != null) {
        final saleProv = Provider.of<SaleProvider>(context, listen: false);
        _saleData = await saleProv.getSaleDetail(widget.saleId!);
        
        if (_saleData != null && _saleData!['cotizacion'] != null) {
          _quotation = SmartQuotationModel.fromJson(_saleData!['cotizacion']);
          final bool isLoan = _saleData!['origen_venta'] == 'prestamo_personal';
          _config.documentTitle = isLoan ? "COMPROBANTE DE PRÉSTAMO" : "COMPROBANTE DE PAGO"; 
          _config.showTransactionDetails = !isLoan;
          _config.showInstallments = isLoan;
        }
      } 
      else if (widget.quotationId != null) {
        final qProv = Provider.of<SmartQuotationProvider>(context, listen: false);
        _quotation = await qProv.getQuotationById(widget.quotationId!);
        _config.documentTitle = "COTIZACIÓN"; 
        _config.showTransactionDetails = false;
      }

      // Restaurar preferencias visuales guardadas preservando el título contextual
      _config = await PdfPreferencesService.applySavedPreferences(_config);

      // Hidratación garantizada de imageUrl en ítems desde SQLite si faltara
      if (_quotation != null) {
        await _hydrateProductImages();
        _titleCtrl.text = _config.documentTitle ?? "";
        
        // Resolver nombre inicial del cliente real sanitizado si existe
        final String? initialClient = _saleData != null ? _saleData!['cliente_nombre'] : _quotation!.clientName;
        final String cleanClient = PdfGenerator.cleanClientDisplayName(initialClient);
        if (cleanClient.isNotEmpty) {
          _clientNameCtrl.text = cleanClient;
          _config.customClientName = cleanClient;
        }

        _footerNoteCtrl.text = _config.footerNote ?? "";
        
        final bool isQuickSale = _saleData != null && _saleData!['origen_venta'] == 'pos_rapido';
        final bool hasNotes = _saleData != null && _saleData!['cliente_notas'] != null && _saleData!['cliente_notas'].toString().isNotEmpty;
        final bool hasInst = !isQuickSale && ((_quotation!.institutionName?.isNotEmpty ?? false) || (_quotation!.gradeLevel?.isNotEmpty ?? false));
        _config.showInstitutionInfo = hasInst || hasNotes;

        // Precargar campos editables de institución, grado, notas y cuentas
        _instNameCtrl.text = _quotation!.institutionName ?? "";
        _gradeLevelCtrl.text = _quotation!.gradeLevel ?? "";
        final rawNotes = _saleData != null ? _saleData!['cliente_notas']?.toString() : _quotation!.notas;
        _notesCtrl.text = rawNotes ?? "";
        _paymentAccountsCtrl.text = authProv.user?.business?.paymentInfo ?? "";
      }
    } catch (e) {
      debugPrint("⚠️ Error cargando datos de PDF: $e");
    }

    if (mounted) setState(() => _loadingData = false);
  }

  /// Hidrata las rutas locales de fotos de productos desde SQLite para ítems sin imagen
  Future<void> _hydrateProductImages() async {
    if (_quotation == null || _quotation!.items.isEmpty) return;
    try {
      final db = await LocalDatabase.instance.database;
      final List<QuotationItem> updatedItems = [];

      for (final item in _quotation!.items) {
        if ((item.imageUrl == null || item.imageUrl!.trim().isEmpty) && item.productId != null) {
          final res = await db.query(
            'productos',
            columns: ['imagen_url'],
            where: 'id = ?',
            whereArgs: [item.productId],
            limit: 1,
          );
          if (res.isNotEmpty && res.first['imagen_url'] != null) {
            final String? dbImg = res.first['imagen_url'] as String?;
            if (dbImg != null && dbImg.isNotEmpty) {
              updatedItems.add(QuotationItem(
                id: item.id,
                productId: item.productId,
                presentationId: item.presentationId,
                bundleId: item.bundleId,
                productName: item.productName,
                brandName: item.brandName,
                specificName: item.specificName,
                salesUnit: item.salesUnit,
                quantity: item.quantity,
                unitPriceApplied: item.unitPriceApplied,
                originalUnitPrice: item.originalUnitPrice,
                isAvailable: item.isAvailable,
                isManualPrice: item.isManualPrice,
                originalText: item.originalText,
                imageUrl: dbImg,
              ));
              continue;
            }
          }
        }
        updatedItems.add(item);
      }
      _quotation = _quotation!.copyWith(items: updatedItems);
    } catch (e) {
      debugPrint("⚠️ Error hidratando fotos de productos: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    
    if (_loadingData) {
      return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator()));
    }
    if (_quotation == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(title: const Text("Vista Previa PDF")),
        body: Center(child: Text("Error cargando datos del documento", style: TextStyle(color: isDark ? Colors.white : Colors.black87))),
      );
    }

    final authProv = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Vista Previa PDF", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
        backgroundColor: isDark ? const Color(0xFF14141E) : Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          const InfoTooltipButton(
            iconColor: Colors.white,
            title: "Guía de Vista Previa PDF",
            description: "Personaliza y genera documentos comerciales en alta definición, listos para imprimir en impresoras térmicas POS o compartir en formato ejecutivo.",
            tips: [
              InfoTip(
                icon: Icons.aspect_ratio_rounded,
                text: "Cambia entre Hoja A4 ejecutiva y Ticket térmico continuo de 80mm para impresoras POS.",
              ),
              InfoTip(
                icon: Icons.dashboard_customize_outlined,
                text: "Elige entre 4 plantillas estructurales y 6 paletas de color con opción de guardado por defecto.",
              ),
              InfoTip(
                icon: Icons.pinch_outlined,
                text: "Haz zoom libre con dos dedos o doble toque en cualquier parte del visor para revisar detalles.",
              ),
              InfoTip(
                icon: Icons.person_search_outlined,
                text: "Busca clientes en tu agenda o personaliza notas y cuentas de cobro al pie antes de generar.",
              ),
              InfoTip(
                icon: Icons.share_outlined,
                text: "Descarga el archivo PDF directamente en Descargas, imprímelo por Bluetooth/WiFi o compártelo al instante.",
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 🎛️ BARRA DE CONTROLES RÁPIDOS SOBRE EL VISOR
          _buildQuickControlsBar(isDark),

          // 📄 VISOR PDF INTERACTIVO CON ZOOM FÍSICO REAL
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF0D0D14) : Colors.grey[200],
              child: Stack(
                alignment: Alignment.center,
                children: [
                  GestureDetector(
                    onDoubleTapDown: _handleDoubleTap,
                    child: InteractiveViewer(
                      transformationController: _zoomController,
                      minScale: 1.0,
                      maxScale: 3.0,
                      child: Center(
                        child: PdfPreview(
                          build: (format) => PdfGenerator.generatePdf(
                            quotation: _quotation!,
                            ownerInfo: authProv.user, 
                            config: _config,
                            saleData: _saleData, 
                          ),
                          useActions: false, 
                          canChangeOrientation: false,
                          canChangePageFormat: false,
                          maxPageWidth: _config.pageSize == PdfPageSize.ticket80 ? 400 : 700, 
                          loadingWidget: const Center(child: CircularProgressIndicator()),
                          pdfFileName: "${_config.documentTitle ?? 'DOCUMENTO'}_${_quotation!.id}.pdf",
                        ),
                      ),
                    ),
                  ),

                  // 🔍 PÍLDORA AUTO-DESVANECIBLE SUPERIOR
                  Positioned(
                    top: 14,
                    child: AnimatedOpacity(
                      opacity: _showZoomPill ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 350),
                      child: IgnorePointer(
                        ignoring: !_showZoomPill,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24, width: 0.8),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in, color: Colors.white70, size: 16),
                              SizedBox(width: 6),
                              Text(
                                "🔍 Pellizca o toca 2 veces para Zoom",
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 🔎 BARRA FLOTANTE DE ZOOM: [ - ] 100% [ + ] [ ⛶ ]
                  Positioned(
                    bottom: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E2C).withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300, width: 0.8),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18),
                            visualDensity: VisualDensity.compact,
                            tooltip: "Alejar",
                            onPressed: _currentScale > 1.01 ? _zoomOut : null,
                          ),
                          Container(
                            constraints: const BoxConstraints(minWidth: 44),
                            alignment: Alignment.center,
                            child: Text(
                              "${(_currentScale * 100).round()}%",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            visualDensity: VisualDensity.compact,
                            tooltip: "Acercar",
                            onPressed: _currentScale < 2.99 ? _zoomIn : null,
                          ),
                          Container(
                            height: 16,
                            width: 1,
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          IconButton(
                            icon: const Icon(Icons.fit_screen_outlined, size: 18),
                            visualDensity: VisualDensity.compact,
                            tooltip: "Restablecer 100%",
                            onPressed: (_currentScale - 1.0).abs() > 0.02 ? _resetZoom : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🛠️ BARRA DE ACCIONES INFERIOR (Personalizar + Descargar + Compartir + Imprimir)
          _buildBottomToolbar(context, isDark),
        ],
      ),
    );
  }

  /// Barra flotante compacta para cambiar Formato (A4 vs Ticket 80mm) y Tema al vuelo
  Widget _buildQuickControlsBar(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
      ),
      child: Row(
        children: [
          // Toggle de Tamaño de Hoja: A4 vs Ticket 80mm
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14141E) : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFormatButton(
                  title: "A4",
                  icon: Icons.description_outlined,
                  isSelected: _config.pageSize == PdfPageSize.a4,
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _config.pageSize = PdfPageSize.a4);
                  },
                ),
                _buildFormatButton(
                  title: "Ticket",
                  icon: Icons.receipt_long_outlined,
                  isSelected: _config.pageSize == PdfPageSize.ticket80,
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _config.pageSize = PdfPageSize.ticket80);
                  },
                ),
              ],
            ),
          ),
          const Spacer(),

          // Selector Rápido de Paleta de Color (6 círculos con borde de contraste)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeCircle(PdfTheme.modern, const Color(0xFF1565C0), "Azul", isDark),
              const SizedBox(width: 6),
              _buildThemeCircle(PdfTheme.emerald, const Color(0xFF00796B), "Verde", isDark),
              const SizedBox(width: 6),
              _buildThemeCircle(PdfTheme.dark, const Color(0xFF263238), "Oscuro", isDark),
              const SizedBox(width: 6),
              _buildThemeCircle(PdfTheme.classic, const Color(0xFF212121), "B&N", isDark),
              const SizedBox(width: 6),
              _buildThemeCircle(PdfTheme.burgundy, const Color(0xFF880E4F), "Vino", isDark),
              const SizedBox(width: 6),
              _buildThemeCircle(PdfTheme.indigo, const Color(0xFF283593), "Índigo", isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormatButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final activeBg = isDark ? Colors.blue[800] : Colors.blue[700];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700])),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[800]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCircle(PdfTheme theme, Color color, String label, bool isDark) {
    final bool isSelected = _config.theme == theme;
    // Borde de contraste alto para que B&N sea 100% visible en modo oscuro
    final Color borderColor = isSelected
        ? Colors.white
        : (isDark ? Colors.white38 : (theme == PdfTheme.classic ? Colors.black45 : Colors.transparent));

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _config.theme = theme);
      },
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.4 : 1.2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6, spreadRadius: 1),
          ],
        ),
        child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
      ),
    );
  }

  /// Barra de herramientas inferior con botón Descargar directo y feedback háptico
  Widget _buildBottomToolbar(BuildContext context, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF1B1B26) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surfaceColor, 
        boxShadow: [if (!isDark) const BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -4))]
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Botón Personalizar
            Expanded(
              flex: 4,
              child: ElevatedButton.icon(
                onPressed: () => _showConfigModal(context, isDark),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text("OPCIONES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF2C2C3E) : Colors.grey[900], 
                  foregroundColor: Colors.white, 
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Botón Descargar PDF Directo (Downloads)
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                onPressed: _downloadPdf, 
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text("GUARDAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700], 
                  foregroundColor: Colors.white, 
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Botón Compartir
            IconButton.filledTonal(
              onPressed: _sharePdf,
              icon: const Icon(Icons.share, size: 20),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 8),

            // Botón Imprimir
            IconButton.filled(
              onPressed: _printPdf,
              icon: const Icon(Icons.print, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Guarda el PDF en la carpeta Descargas y abre el modal animado de éxito
  Future<void> _downloadPdf() async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final String cleanTitle = (_config.documentTitle ?? "DOCUMENTO").replaceAll(RegExp(r'\s+'), '_');
    final String fileName = "${cleanTitle}_${_quotation!.id}.pdf";

    await DownloadFeedbackModal.show(
      context,
      title: "Descargar Documento PDF",
      loadingMessage: "Generando archivo y guardando en Descargas...",
      downloadTask: () async {
        final bytes = await PdfGenerator.generatePdf(
          quotation: _quotation!,
          ownerInfo: authProv.user,
          config: _config,
          saleData: _saleData,
        );
        return await InvoiceFileService.saveBytesToDownloads(bytes: bytes, fileName: fileName);
      },
    );
  }

  Future<void> _sharePdf() async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final bytes = await PdfGenerator.generatePdf(quotation: _quotation!, ownerInfo: authProv.user, config: _config, saleData: _saleData);
    await Printing.sharePdf(bytes: bytes, filename: '${_config.documentTitle ?? "Documento"}.pdf');
  }

  Future<void> _printPdf() async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final bytes = await PdfGenerator.generatePdf(quotation: _quotation!, ownerInfo: authProv.user, config: _config, saleData: _saleData);
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  // =========================================================================
  // 🎨 MODAL REDISEÑADO "MOBILE AWARDS" DE OPCIONES DE DOCUMENTO (3 PESTAÑAS)
  // =========================================================================
  void _showConfigModal(BuildContext context, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final authProv = Provider.of<AuthProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      builder: (ctx) => DefaultTabController(
        length: 3,
        child: StatefulBuilder(
          builder: (context, setModalState) {
            void updateConfig(VoidCallback fn) {
              setModalState(fn);
              setState(fn);
            }

            final bool isQuickSale = _saleData != null && _saleData!['origen_venta'] == 'pos_rapido';
            final bool isLoan = _saleData != null && _saleData!['origen_venta'] == 'prestamo_personal';
            final bool isSale = _saleData != null;

            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    // Handle superior
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 42, height: 4,
                      decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                    ),

                    // Cabecera Fija del Modal
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 16, 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.tune_rounded, size: 22, color: isDark ? Colors.blue[300] : Colors.blue[800]),
                              const SizedBox(width: 8),
                              Text("Opciones de Documento", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 24, color: textColor),
                            onPressed: () => Navigator.pop(context),
                          )
                        ],
                      ),
                    ),

                    // Barra de Pestañas Estilizada con Cero Truncamiento
                    TabBar(
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      labelColor: isDark ? Colors.blue[300] : Colors.blue[800],
                      unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
                      indicatorColor: isDark ? Colors.blue[400] : Colors.blue[800],
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      unselectedLabelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                      tabs: const [
                        Tab(text: "🎨 Diseño"),
                        Tab(text: "🏪 Negocio y Cliente"),
                        Tab(text: "📋 Tabla y Totales"),
                      ],
                    ),
                    Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey[200]),

                    // Contenido Desplazable de las 3 Pestañas
                    Expanded(
                      child: TabBarView(
                        children: [
                          // ----------------------------------------------------
                          // PESTAÑA 1: FORMATO Y ESTILO VISUAL
                          // ----------------------------------------------------
                          ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            children: [
                              _buildSectionTitle("Plantilla Estructural del PDF", Icons.dashboard_outlined, isDark),
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _buildLayoutSelectionCard(
                                        title: "Ejecutivo Moderno",
                                        subtitle: "Banda color superior y cabeceras ejecutivas",
                                        icon: Icons.view_compact_outlined,
                                        template: PdfLayoutTemplate.executiveModern,
                                        isDark: isDark,
                                        updateConfig: updateConfig,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildLayoutSelectionCard(
                                        title: "Corporativo Formal",
                                        subtitle: "Bordes dobles formales y sellos de aprobación",
                                        icon: Icons.crop_square_outlined,
                                        template: PdfLayoutTemplate.corporateFramed,
                                        isDark: isDark,
                                        updateConfig: updateConfig,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _buildLayoutSelectionCard(
                                        title: "Catálogo Comercial",
                                        subtitle: "Destaca fotos, badges y detalles de productos",
                                        icon: Icons.photo_library_outlined,
                                        template: PdfLayoutTemplate.commercialCatalog,
                                        isDark: isDark,
                                        updateConfig: updateConfig,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildLayoutSelectionCard(
                                        title: "Mayorista Compacto",
                                        subtitle: "Máxima densidad de datos para cotizaciones extensas",
                                        icon: Icons.table_rows_outlined,
                                        template: PdfLayoutTemplate.compactWholesale,
                                        isDark: isDark,
                                        updateConfig: updateConfig,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 22),

                              _buildSectionTitle("Título del Documento", Icons.title, isDark),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF14141E) : Colors.grey[50],
                                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextField(
                                  controller: _titleCtrl,
                                  style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: "Ej: COTIZACIÓN, NOTA DE VENTA",
                                    hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey),
                                  ),
                                  onChanged: (v) => updateConfig(() => _config.documentTitle = v.toUpperCase()),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Chips Rápidos de Título de 1 Toque
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  "COTIZACIÓN",
                                  "PROFORMA",
                                  "NOTA DE VENTA",
                                  "COMPROBANTE DE PAGO",
                                  "ESTADO DE CUENTA",
                                ].map((chipTitle) {
                                  final bool isSelected = _config.documentTitle == chipTitle;
                                  return ChoiceChip(
                                    label: Text(chipTitle, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                    selected: isSelected,
                                    selectedColor: isDark ? Colors.blue[900] : Colors.blue[100],
                                    onSelected: (sel) {
                                      if (sel) {
                                        updateConfig(() {
                                          _titleCtrl.text = chipTitle;
                                          _config.documentTitle = chipTitle;
                                        });
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 22),

                              _buildSectionTitle("Tamaño de Hoja", Icons.aspect_ratio, isDark),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildChoiceCard(
                                      title: "Hoja A4",
                                      subtitle: "Ejecutiva completa",
                                      icon: Icons.description_outlined,
                                      isSelected: _config.pageSize == PdfPageSize.a4,
                                      isDark: isDark,
                                      onTap: () => updateConfig(() => _config.pageSize = PdfPageSize.a4),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildChoiceCard(
                                      title: "Ticket 80mm",
                                      subtitle: "Rollo térmico POS",
                                      icon: Icons.receipt_long_outlined,
                                      isSelected: _config.pageSize == PdfPageSize.ticket80,
                                      isDark: isDark,
                                      onTap: () => updateConfig(() => _config.pageSize = PdfPageSize.ticket80),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),

                              _buildSectionTitle("Paleta de Color", Icons.palette_outlined, isDark),
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                childAspectRatio: 2.8,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                children: [
                                  _buildThemeSelectionCard("Azul Moderno", const Color(0xFF1565C0), PdfTheme.modern, isDark, updateConfig),
                                  _buildThemeSelectionCard("Esmeralda", const Color(0xFF00796B), PdfTheme.emerald, isDark, updateConfig),
                                  _buildThemeSelectionCard("Ejecutivo", const Color(0xFF263238), PdfTheme.dark, isDark, updateConfig),
                                  _buildThemeSelectionCard("B&N (Ahorro)", const Color(0xFF212121), PdfTheme.classic, isDark, updateConfig),
                                  _buildThemeSelectionCard("Vino Tinto", const Color(0xFF880E4F), PdfTheme.burgundy, isDark, updateConfig),
                                  _buildThemeSelectionCard("Índigo Real", const Color(0xFF283593), PdfTheme.indigo, isDark, updateConfig),
                                ],
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),

                          // ----------------------------------------------------
                          // PESTAÑA 2: MI NEGOCIO Y DATOS DEL CLIENTE
                          // ----------------------------------------------------
                          ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            children: [
                              // Tarjeta de Mi Negocio
                              _buildSectionTitle("Datos de Mi Negocio", Icons.store_rounded, isDark),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF14141E) : Colors.blue.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isDark ? Colors.white12 : Colors.blue.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text("Mostrar Cabecera del Negocio", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                      value: _config.showBusinessInfo,
                                      activeThumbColor: Colors.blue,
                                      onChanged: (v) => updateConfig(() => _config.showBusinessInfo = v),
                                    ),
                                    if (_config.showBusinessInfo) ...[
                                      const SizedBox(height: 8),
                                      // Miniatura de logo actual si existe
                                      _buildLogoPreview(authProv.user?.business?.logoUrl, isDark),
                                      const SizedBox(height: 12),
                                      Text("Campos a incluir en cabecera:", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          FilterChip(
                                            label: const Text("Logo"),
                                            selected: _config.includeLogo,
                                            onSelected: (v) => updateConfig(() => _config.includeLogo = v),
                                          ),
                                          FilterChip(
                                            label: const Text("Dirección"),
                                            selected: _config.includeShopAddress,
                                            onSelected: (v) => updateConfig(() => _config.includeShopAddress = v),
                                          ),
                                          FilterChip(
                                            label: const Text("Teléfono"),
                                            selected: _config.includeOwnerPhone,
                                            onSelected: (v) => updateConfig(() => _config.includeOwnerPhone = v),
                                          ),
                                          FilterChip(
                                            label: const Text("RUC"),
                                            selected: _config.includeShopRuc,
                                            onSelected: (v) => updateConfig(() => _config.includeShopRuc = v),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Tarjeta de Datos del Cliente y Notas
                              _buildSectionTitle("Datos del Cliente & Notas al Pie", Icons.person_outline, isDark),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF14141E) : Colors.orange.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isDark ? Colors.white12 : Colors.orange.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text("Mostrar Bloque de Cliente", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                      value: _config.showClientName,
                                      activeThumbColor: Colors.orange,
                                      onChanged: (v) => updateConfig(() => _config.showClientName = v),
                                    ),
                                    if (_config.showClientName) ...[
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _clientNameCtrl,
                                        style: TextStyle(color: textColor, fontSize: 14),
                                        decoration: InputDecoration(
                                          labelText: "Nombre del Cliente en Documento",
                                          hintText: "Ej: Juan Pérez / Empresa SAC",
                                          labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                                          filled: true,
                                          fillColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          suffixIcon: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (_clientNameCtrl.text.isNotEmpty)
                                                IconButton(
                                                  icon: const Icon(Icons.clear, size: 18),
                                                  tooltip: "Limpiar cliente (✕)",
                                                  onPressed: () {
                                                    updateConfig(() {
                                                      _clientNameCtrl.clear();
                                                      _config.customClientName = null;
                                                    });
                                                  },
                                                ),
                                              IconButton(
                                                icon: const Icon(Icons.search, size: 20),
                                                tooltip: "Buscar en Agenda (🔍)",
                                                onPressed: () {
                                                  ClientSearchModal.show(
                                                    context,
                                                    onClientSelected: (client) {
                                                      final clean = PdfGenerator.cleanClientDisplayName(client.fullName);
                                                      updateConfig(() {
                                                        _clientNameCtrl.text = clean;
                                                        _config.customClientName = clean.isEmpty ? null : clean;
                                                      });
                                                    },
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        onChanged: (v) {
                                          final clean = PdfGenerator.cleanClientDisplayName(v);
                                          updateConfig(() => _config.customClientName = clean.isEmpty ? null : clean);
                                        },
                                      ),
                                      const SizedBox(height: 10),
                                      SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(isQuickSale ? "Mostrar Nota de Venta" : "Información Adicional", style: TextStyle(color: textColor, fontSize: 14)),
                                        subtitle: Text(isQuickSale ? "Imprime la nota registrada" : "Colegio / Grado / Notas", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
                                        value: _config.showInstitutionInfo,
                                        activeThumbColor: Colors.orange,
                                        onChanged: (v) => updateConfig(() => _config.showInstitutionInfo = v),
                                      ),
                                      AnimatedSize(
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.easeInOut,
                                        child: !_config.showInstitutionInfo
                                            ? const SizedBox.shrink()
                                            : Padding(
                                                padding: const EdgeInsets.only(top: 8, bottom: 4),
                                                child: Column(
                                                  children: [
                                                    if (!isQuickSale) ...[
                                                      TextField(
                                                        controller: _instNameCtrl,
                                                        style: TextStyle(color: textColor, fontSize: 13),
                                                        decoration: InputDecoration(
                                                          labelText: "Colegio / Institución",
                                                          labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                                                          filled: true,
                                                          fillColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
                                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                        ),
                                                        onChanged: (v) => updateConfig(() => _config.customInstitutionName = v.trim().isEmpty ? null : v.trim()),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      TextField(
                                                        controller: _gradeLevelCtrl,
                                                        style: TextStyle(color: textColor, fontSize: 13),
                                                        decoration: InputDecoration(
                                                          labelText: "Grado / Nivel / Sección",
                                                          labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                                                          filled: true,
                                                          fillColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
                                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                        ),
                                                        onChanged: (v) => updateConfig(() => _config.customGradeLevel = v.trim().isEmpty ? null : v.trim()),
                                                      ),
                                                      const SizedBox(height: 8),
                                                    ],
                                                    TextField(
                                                      controller: _notesCtrl,
                                                      style: TextStyle(color: textColor, fontSize: 13),
                                                      decoration: InputDecoration(
                                                        labelText: isQuickSale ? "Nota de Venta / Observaciones" : "Notas / Observaciones del Cliente",
                                                        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                                                        filled: true,
                                                        fillColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
                                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                      ),
                                                      onChanged: (v) => updateConfig(() => _config.customNotes = v.trim().isEmpty ? null : v.trim()),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: _footerNoteCtrl,
                                      style: TextStyle(color: textColor, fontSize: 14),
                                      decoration: InputDecoration(
                                        labelText: "Condiciones / Validez al Pie",
                                        hintText: "Ej: Cotización válida por 7 días.",
                                        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                      onChanged: (v) => updateConfig(() => _config.footerNote = v.trim().isEmpty ? null : v.trim()),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        ("⏳ Válida por 7 días", "Válida por 7 días"),
                                        ("⏳ Válida por 15 días", "Válida por 15 días"),
                                        ("🚚 Entrega inmediata", "Entrega inmediata"),
                                        ("🧾 Precios incluyen IGV", "Precios incluyen IGV"),
                                        ("📦 Sujeto a stock", "Sujeto a stock"),
                                        ("🛡️ Garantía de tienda", "Garantía de tienda"),
                                        ("🤝 ¡Gracias por su compra!", "¡Gracias por su compra!"),
                                      ].map((item) {
                                        final displayLabel = item.$1;
                                        final cleanText = item.$2;
                                        final currentText = _footerNoteCtrl.text;
                                        final isSelected = currentText.toLowerCase().contains(cleanText.toLowerCase()) ||
                                            (cleanText.contains("¡Gracias") && currentText.toLowerCase().contains("gracias por su compra"));

                                        return FilterChip(
                                          visualDensity: VisualDensity.compact,
                                          selected: isSelected,
                                          showCheckmark: true,
                                          checkmarkColor: Colors.white,
                                          selectedColor: Colors.orange.shade700,
                                          backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.grey.shade100,
                                          side: BorderSide(color: isSelected ? Colors.orange : (isDark ? Colors.white24 : Colors.grey.shade300)),
                                          label: Text(
                                            displayLabel,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[800]),
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                          onSelected: (_) {
                                            updateConfig(() {
                                              if (isSelected) {
                                                // Eliminar de forma limpia
                                                String updated = currentText.replaceAll(cleanText, '');
                                                if (cleanText.contains("¡Gracias")) {
                                                  updated = updated.replaceAll(RegExp(r'¡?Gracias por su compra!?', caseSensitive: false), '');
                                                }
                                                updated = updated.replaceAll(RegExp(r'\.\s*\.'), '.').trim();
                                                if (updated.startsWith('.')) updated = updated.substring(1).trim();
                                                if (updated.endsWith('.')) updated = updated.substring(0, updated.length - 1).trim();
                                                updated = updated.replaceAll(RegExp(r'\s+'), ' ');
                                                _footerNoteCtrl.text = updated;
                                                _config.footerNote = updated.isEmpty ? null : updated;
                                              } else {
                                                // Exclusión mutua: Válida por 7 días vs Válida por 15 días
                                                String current = currentText.trim();
                                                if (cleanText == "Válida por 7 días" && current.contains(RegExp(r'Válida por 15 días', caseSensitive: false))) {
                                                  current = current.replaceAll(RegExp(r'Válida por 15 días', caseSensitive: false), cleanText);
                                                  _footerNoteCtrl.text = current;
                                                  _config.footerNote = current;
                                                } else if (cleanText == "Válida por 15 días" && current.contains(RegExp(r'Válida por 7 días', caseSensitive: false))) {
                                                  current = current.replaceAll(RegExp(r'Válida por 7 días', caseSensitive: false), cleanText);
                                                  _footerNoteCtrl.text = current;
                                                  _config.footerNote = current;
                                                } else {
                                                  if (current.endsWith('.')) current = current.substring(0, current.length - 1).trim();
                                                  final newText = current.isEmpty ? cleanText : "$current. $cleanText";
                                                  _footerNoteCtrl.text = newText;
                                                  _config.footerNote = newText;
                                                }
                                              }
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 10),
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text("Mostrar Cuentas de Cobro (Yape/Plin)", style: TextStyle(color: textColor, fontSize: 14)),
                                      subtitle: Text("Imprime tus números de pago al pie", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
                                      value: _config.showPaymentAccounts,
                                      activeThumbColor: Colors.orange,
                                      onChanged: (v) => updateConfig(() => _config.showPaymentAccounts = v),
                                    ),
                                    AnimatedSize(
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeInOut,
                                      child: !_config.showPaymentAccounts
                                          ? const SizedBox.shrink()
                                          : Padding(
                                              padding: const EdgeInsets.only(top: 8, bottom: 4),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  TextField(
                                                    controller: _paymentAccountsCtrl,
                                                    maxLines: 2,
                                                    style: TextStyle(color: textColor, fontSize: 13),
                                                    decoration: InputDecoration(
                                                      labelText: "Cuentas de Cobro / Instrucciones de Pago",
                                                      hintText: "Ej: Yape/Plin: 999-888-777 | BCP: 191-xxxx...",
                                                      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                                                      filled: true,
                                                      fillColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    ),
                                                    onChanged: (v) => updateConfig(() => _config.customPaymentInfo = v.trim().isEmpty ? null : v.trim()),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 6,
                                                    children: [
                                                      ("📱 Yape", "Yape"),
                                                      ("📱 Plin", "Plin"),
                                                      ("🏦 BCP", "BCP"),
                                                      ("🏦 CCI", "CCI"),
                                                    ].map((item) {
                                                      final displayLabel = item.$1;
                                                      final rawType = item.$2;
                                                      final current = _paymentAccountsCtrl.text;
                                                      final isSelected = RegExp(r'\b' + rawType + r'\b', caseSensitive: false).hasMatch(current);

                                                      return FilterChip(
                                                        visualDensity: VisualDensity.compact,
                                                        selected: isSelected,
                                                        showCheckmark: true,
                                                        checkmarkColor: Colors.white,
                                                        selectedColor: Colors.orange.shade700,
                                                        backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.grey.shade100,
                                                        side: BorderSide(color: isSelected ? Colors.orange : (isDark ? Colors.white24 : Colors.grey.shade300)),
                                                        label: Text(
                                                          displayLabel,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[800]),
                                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                          ),
                                                        ),
                                                        onSelected: (_) {
                                                          updateConfig(() {
                                                            if (isSelected) {
                                                              // Desmarcar y eliminar limpiamente sin duplicar
                                                              final pattern = RegExp(
                                                                r'(?:^|[|\n])\s*(?:[^\w\s]*\s*)?' + rawType + r'[:\s][^|\n]*',
                                                                caseSensitive: false,
                                                              );
                                                              String updated = current.replaceAll(pattern, '');
                                                              updated = updated.replaceAll(RegExp(r'\|\s*\|'), '|');
                                                              updated = updated.replaceAll(RegExp(r'\n\s*\n'), '\n');
                                                              updated = updated.trim();
                                                              if (updated.startsWith('|')) updated = updated.substring(1).trim();
                                                              if (updated.endsWith('|')) updated = updated.substring(0, updated.length - 1).trim();
                                                              _paymentAccountsCtrl.text = updated;
                                                              _config.customPaymentInfo = updated.isEmpty ? null : updated;
                                                            } else {
                                                              // Marcar y agregar texto limpio sin emojis
                                                              final userPhone = authProv.user?.phone?.trim() ?? "";
                                                              final bizPaymentInfo = authProv.user?.business?.paymentInfo ?? "";
                                                              String accountNum = "";
                                                              final m = RegExp(rawType + r'[:\s]+([0-9\s-]+)', caseSensitive: false).firstMatch(bizPaymentInfo);
                                                              if (m != null && m.group(1) != null && m.group(1)!.trim().isNotEmpty) {
                                                                accountNum = m.group(1)!.trim();
                                                              } else if (rawType == 'Yape' || rawType == 'Plin') {
                                                                accountNum = userPhone;
                                                              }

                                                              final entry = accountNum.isNotEmpty ? "$rawType: $accountNum" : "$rawType: ";
                                                              String text = current.trim();
                                                              String newText;
                                                              if (text.isEmpty) {
                                                                newText = entry;
                                                              } else {
                                                                if (text.contains('\n')) {
                                                                  newText = "$text\n$entry";
                                                                } else {
                                                                  newText = "$text | $entry";
                                                                }
                                                              }
                                                              _paymentAccountsCtrl.text = newText;
                                                              _config.customPaymentInfo = newText;
                                                            }
                                                          });
                                                        },
                                                      );
                                                    }).toList(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),

                          // ----------------------------------------------------
                          // PESTAÑA 3: COLUMNAS DE TABLA Y TOTALES
                          // ----------------------------------------------------
                          ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            children: [
                              // Fotos de Productos
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF14141E) : Colors.purple.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isDark ? Colors.purple.withValues(alpha: 0.2) : Colors.purple.shade100),
                                ),
                                child: SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  secondary: Icon(Icons.image, color: isDark ? Colors.purple[300] : Colors.purple[700]),
                                  title: Text("Incluir Imágenes de Productos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.purple[200] : Colors.purple[900])),
                                  subtitle: Text("Muestra fotos en miniatura de tus productos (Local / Catálogo)", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 12)),
                                  value: _config.showImages,
                                  activeThumbColor: Colors.purple,
                                  onChanged: (v) => updateConfig(() => _config.showImages = v),
                                ),
                              ),
                              const SizedBox(height: 16),

                              if (!isLoan) ...[
                                _buildSectionTitle("Columnas de Productos", Icons.view_column_outlined, isDark),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF14141E) : Colors.green.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isDark ? Colors.white12 : Colors.green.withValues(alpha: 0.2)),
                                  ),
                                  child: Column(
                                    children: [
                                      SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text("Mostrar Columna: Unidad", style: TextStyle(color: textColor, fontSize: 14)),
                                        subtitle: Text("Ej: Docena, Empaque, Kilo", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
                                        value: _config.showProductUnit,
                                        activeThumbColor: Colors.green,
                                        onChanged: (v) => updateConfig(() => _config.showProductUnit = v),
                                      ),
                                      SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text("Mostrar Columna: Precio Unitario", style: TextStyle(color: textColor, fontSize: 14)),
                                        subtitle: Text("Precio por 1 artículo", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
                                        value: _config.showProductUnitPrice,
                                        activeThumbColor: Colors.green,
                                        onChanged: (v) => updateConfig(() {
                                          _config.showProductUnitPrice = v;
                                          if (!v) _config.showProductSavings = false;
                                        }),
                                      ),
                                      if (_config.showProductUnitPrice)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 20),
                                          child: SwitchListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text("Mostrar Descuento Unitario", style: TextStyle(color: textColor, fontSize: 13)),
                                            subtitle: Text("Precio original tachado", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 11)),
                                            value: _config.showProductSavings,
                                            activeThumbColor: Colors.green,
                                            onChanged: (v) => updateConfig(() => _config.showProductSavings = v),
                                          ),
                                        ),
                                      SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text("Mostrar Columna: Subtotal", style: TextStyle(color: textColor, fontSize: 14)),
                                        subtitle: Text("Multiplica precio por cantidad", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
                                        value: _config.showProductSubtotal,
                                        activeThumbColor: Colors.green,
                                        onChanged: (v) => updateConfig(() => _config.showProductSubtotal = v),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              _buildSectionTitle("Totales Financieros", Icons.payments_outlined, isDark),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF14141E) : Colors.teal.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isDark ? Colors.white12 : Colors.teal.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  children: [
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text("Mostrar Total a Pagar", style: TextStyle(color: textColor, fontSize: 14)),
                                      value: _config.showTotalGlobal,
                                      activeThumbColor: Colors.teal,
                                      onChanged: (v) => updateConfig(() {
                                        _config.showTotalGlobal = v;
                                        if (!v) _config.showTotalSavings = false;
                                      }),
                                    ),
                                    if (_config.showTotalGlobal)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 20),
                                        child: SwitchListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text("Mostrar Descuento / Ahorro Global", style: TextStyle(color: textColor, fontSize: 13)),
                                          value: _config.showTotalSavings,
                                          activeThumbColor: Colors.teal,
                                          onChanged: (v) => updateConfig(() => _config.showTotalSavings = v),
                                        ),
                                      ),
                                    if (isSale) ...[
                                      SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text("Mostrar Info de Pago y Deuda", style: TextStyle(color: textColor, fontSize: 14)),
                                        value: _config.showTransactionDetails,
                                        activeThumbColor: Colors.teal,
                                        onChanged: (v) => updateConfig(() => _config.showTransactionDetails = v),
                                      ),
                                      SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text("Mostrar Cronograma de Cuotas", style: TextStyle(color: textColor, fontSize: 14)),
                                        value: _config.showInstallments,
                                        activeThumbColor: Colors.teal,
                                        onChanged: (v) => updateConfig(() => _config.showInstallments = v),
                                      ),
                                    ],
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text("Sello Visual de Estado (Pagado/Pendiente)", style: TextStyle(color: textColor, fontSize: 14)),
                                      value: _config.showStatusStamp,
                                      activeThumbColor: Colors.teal,
                                      onChanged: (v) => updateConfig(() => _config.showStatusStamp = v),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Barra Inferior Fija del Modal: Guardar como diseño por defecto
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final success = await PdfPreferencesService.saveDefaultConfig(_config);
                                if (context.mounted && success) {
                                  HapticFeedback.mediumImpact();
                                  CustomSnackBar.show(context, message: "¡Configuración guardada como diseño por defecto!", isError: false);
                                }
                              },
                              icon: const Icon(Icons.bookmark_added_outlined, size: 18),
                              label: const Text("Guardar mi diseño por defecto", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: () => Navigator.pop(context),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Aplicar", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey),
          const SizedBox(width: 8),
          Text(title.toUpperCase(), style: TextStyle(color: isDark ? Colors.blueGrey[300] : Colors.blueGrey, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.8)),
        ],
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final activeBorder = isDark ? Colors.blue[400] : Colors.blue[700];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.08))
              : (isDark ? const Color(0xFF14141E) : Colors.grey[50]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? activeBorder! : (isDark ? Colors.white12 : Colors.grey.shade300), width: isSelected ? 1.8 : 0.8),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? activeBorder : (isDark ? Colors.grey[400] : Colors.grey[600]), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutSelectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required PdfLayoutTemplate template,
    required bool isDark,
    required Function(VoidCallback) updateConfig,
  }) {
    final bool isSelected = _config.layoutTemplate == template;
    final activeColor = isDark ? Colors.blue[400]! : Colors.blue[800]!;

    return InkWell(
      onTap: () => updateConfig(() => _config.layoutTemplate = template),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.blue.withValues(alpha: 0.18) : Colors.blue.withValues(alpha: 0.08))
              : (isDark ? const Color(0xFF14141E) : Colors.grey[50]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: isSelected ? 2.0 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Nivel 1: Fila superior con [Icono] + [Título completo] + [Check animado]
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? activeColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: isSelected
                      ? Icon(Icons.check_circle_rounded, key: const ValueKey('checked'), size: 17, color: activeColor)
                      : Icon(Icons.radio_button_unchecked_rounded, key: const ValueKey('unchecked'), size: 17, color: isDark ? Colors.white24 : Colors.grey.shade400),
                ),
              ],
            ),
            const SizedBox(height: 7),
            // Nivel 2: Descripción completa en 2 líneas limpias a todo el ancho sin cortes
            Text(
              subtitle,
              maxLines: 2,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.3,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelectionCard(
    String name, Color color, PdfTheme theme, bool isDark, Function(VoidCallback) updateConfig
  ) {
    final bool isSelected = _config.theme == theme;
    return InkWell(
      onTap: () => updateConfig(() => _config.theme = theme),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF14141E) : Colors.grey[50]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : (isDark ? Colors.white12 : Colors.grey.shade300), width: isSelected ? 2 : 0.8),
        ),
        child: Row(
          children: [
            Container(width: 18, height: 18, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(name, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isDark ? Colors.white : Colors.black87))),
            if (isSelected) Icon(Icons.check, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoPreview(String? logoUrl, bool isDark) {
    if (logoUrl != null && logoUrl.isNotEmpty && logoUrl != 'null') {
      return Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: logoUrl.startsWith('http')
                ? Image.network(logoUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.store, size: 24))
                : Image.file(File(logoUrl), fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.store, size: 24)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Logo actual detectado", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text("Se incluirá en el encabezado del documento", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.info_outline, size: 20, color: Colors.amber[700]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "Aún no tienes un logo subido en tu perfil. Puedes agregarlo en Ajustes > Mi Negocio.",
            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
        ),
      ],
    );
  }
}