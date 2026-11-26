import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/features/scanner/services/invoice_file_service.dart';
import 'package:app_movil/features/scanner/widgets/shared/download_feedback_modal.dart';
import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';
import 'package:app_movil/features/smart_quotation/models/pdf_config_model.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/services/pdf_preferences_service.dart';
import 'package:app_movil/features/smart_quotation/utils/pdf_generator.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/client_search_modal.dart';

part 'pdf_preview/pdf_preview_toolbars.dart';
part 'pdf_preview/pdf_config_modal.dart';
part 'pdf_preview/pdf_config_design_tab.dart';
part 'pdf_preview/pdf_config_business_tab.dart';
part 'pdf_preview/pdf_config_footer_chips_section.dart';
part 'pdf_preview/pdf_config_table_tab.dart';

/// PANTALLA DE VISTA PREVIA PDF ("MOBILE AWARDS")
/// Incorpora barra de controles rápidos (A4 vs Ticket 80mm + paleta cromática),
/// botón directo de descarga con modal animado y feedback háptico,
/// zoom interactivo con InteractiveViewer y TransformationController,
/// e hidratación garantizada de imágenes desde SQLite.
class PdfPreviewScreen extends StatefulWidget {
  final int? quotationId;
  final int? saleId;
  final QuotationContextMode? contextMode;

  const PdfPreviewScreen({
    super.key,
    this.quotationId,
    this.saleId,
    this.contextMode,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

abstract class _PdfPreviewScreenStateBase extends State<PdfPreviewScreen>
    with SingleTickerProviderStateMixin {
  late PdfConfig _config;
  SmartQuotationModel? _quotation;
  Map<String, dynamic>? _saleData;
  bool _loadingData = true;

  // Variables de Zoom Interactivo y Píldora Auto-desvanecible
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
    _zoomAnimController =
        AnimationController(
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
    _zoomAnimation = Matrix4Tween(begin: _zoomController.value, end: endMatrix)
        .animate(
          CurvedAnimation(
            parent: _zoomAnimController,
            curve: Curves.easeOutCubic,
          ),
        );
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
          _config.documentTitle = isLoan
              ? "COMPROBANTE DE PRÉSTAMO"
              : "COMPROBANTE DE PAGO";
          _config.showTransactionDetails = !isLoan;
          _config.showInstallments = isLoan;
        }
      } else if (widget.quotationId != null) {
        final qProv = Provider.of<SmartQuotationProvider>(
          context,
          listen: false,
        );
        _quotation = await qProv.getQuotationById(widget.quotationId!);
        final mode =
            widget.contextMode ??
            _quotation?.contextMode ??
            QuotationContextMode.school;
        switch (mode) {
          case QuotationContextMode.general:
            _config.documentTitle = "PROFORMA COMERCIAL";
            break;
          case QuotationContextMode.wholesale:
            _config.documentTitle = "PRESUPUESTO MAYORISTA";
            break;
          case QuotationContextMode.school:
            _config.documentTitle = "COTIZACIÓN";
            break;
        }
        _config.showTransactionDetails = false;
      }

      // Restaurar preferencias visuales guardadas preservando el título contextual
      _config = await PdfPreferencesService.applySavedPreferences(_config);

      // Si es un préstamo o venta al crédito, reemplazar condiciones de cotización por términos de crédito/cobranza
      if (_saleData != null) {
        final bool isLoan = _saleData!['origen_venta'] == 'prestamo_personal';
        final bool isCredit =
            !isLoan &&
            (_saleData!['estado_pago'] == 'pendiente' ||
                (_saleData!['cuotas'] != null &&
                    (_saleData!['cuotas'] as List).isNotEmpty));
        if (isLoan || isCredit) {
          if (_config.footerNote == null ||
              _config.footerNote!.trim().isEmpty ||
              _config.footerNote!.toLowerCase().contains("válida por") ||
              _config.footerNote!.toLowerCase().contains("valida por") ||
              _config.footerNote!.toLowerCase().contains("cotización") ||
              _config.footerNote!.toLowerCase().contains("cotizacion")) {
            _config.footerNote =
                "El pago puntual de cada cuota evita la generación de recargos por mora. Comprobante emitido para control y cobranza.";
          }
        }
      }

      // Hidratación garantizada de imageUrl en ítems desde SQLite si faltara
      if (_quotation != null) {
        await _hydrateProductImages();
        _titleCtrl.text = _config.documentTitle ?? "";

        // Resolver nombre inicial del cliente real sanitizado si existe
        final String? initialClient = _saleData != null
            ? _saleData!['cliente_nombre']
            : _quotation!.clientName;
        final String cleanClient = PdfGenerator.cleanClientDisplayName(
          initialClient,
        );
        if (cleanClient.isNotEmpty) {
          _clientNameCtrl.text = cleanClient;
          _config.customClientName = cleanClient;
        }

        _footerNoteCtrl.text = _config.footerNote ?? "";

        final bool isQuickSale =
            _saleData != null && _saleData!['origen_venta'] == 'pos_rapido';
        final bool hasNotes =
            _saleData != null &&
            _saleData!['cliente_notas'] != null &&
            _saleData!['cliente_notas'].toString().isNotEmpty;
        final bool hasInst =
            !isQuickSale &&
            ((_quotation!.institutionName?.isNotEmpty ?? false) ||
                (_quotation!.gradeLevel?.isNotEmpty ?? false));
        _config.showInstitutionInfo = hasInst || hasNotes;

        // Precargar campos editables de institución, grado, notas y cuentas
        _instNameCtrl.text = _quotation!.institutionName ?? "";
        _gradeLevelCtrl.text = _quotation!.gradeLevel ?? "";
        final rawNotes = _saleData != null
            ? _saleData!['cliente_notas']?.toString()
            : _quotation!.notas;
        _notesCtrl.text = rawNotes ?? "";
        _paymentAccountsCtrl.text = authProv.user?.business?.paymentInfo ?? "";
      }
    } catch (e) {
      debugPrint("⚠️ Error cargando datos de PDF: $e");
    }

    if (mounted) {
      setState(() => _loadingData = false);
    }
  }

  /// Hidrata las rutas locales de fotos de productos desde SQLite para ítems sin imagen
  Future<void> _hydrateProductImages() async {
    if (_quotation == null || _quotation!.items.isEmpty) return;
    try {
      final db = await LocalDatabase.instance.database;
      final List<QuotationItem> updatedItems = [];

      for (final item in _quotation!.items) {
        if ((item.imageUrl == null || item.imageUrl!.trim().isEmpty) &&
            item.productId != null) {
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
              updatedItems.add(
                QuotationItem(
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
                ),
              );
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

  Widget _buildQuickControlsBar(bool isDark);
  Widget _buildZoomHintPill();
  Widget _buildZoomFloatingBar(bool isDark);
  Widget _buildBottomToolbar(BuildContext context, bool isDark);
  void _showConfigModal(BuildContext context, bool isDark);
  Widget _buildDesignTab({
    required bool isDark,
    required Color textColor,
    required void Function(VoidCallback) updateConfig,
  });
  Widget _buildBusinessAndClientTab({
    required BuildContext context,
    required AuthProvider authProv,
    required ScrollController businessScrollController,
    required GlobalKey additionalInfoKey,
    required GlobalKey paymentAccountsKey,
    required bool isDark,
    required bool isQuickSale,
    required Color textColor,
    required void Function(VoidCallback) updateConfig,
  });
  Widget _buildTableAndTotalsTab({
    required bool isDark,
    required bool isLoan,
    required bool isSale,
    required Color textColor,
    required void Function(VoidCallback) updateConfig,
  });
  Widget _buildSectionTitle(String title, IconData icon, bool isDark);
  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  });
  Widget _buildLayoutSelectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required PdfLayoutTemplate template,
    required bool isDark,
    required Function(VoidCallback) updateConfig,
  });
  Widget _buildThemeSelectionCard(
    String name,
    Color color,
    PdfTheme theme,
    bool isDark,
    Function(VoidCallback) updateConfig,
  );
  Widget _buildLogoPreview(
    String? logoUrl,
    bool isDark, {
    String? businessName,
  });
  Widget _buildValiditySection({
    required bool isDark,
    required Color textColor,
    required void Function(VoidCallback) updateConfig,
  });
  Widget _buildConditionsSection({
    required bool isDark,
    required Color textColor,
    required void Function(VoidCallback) updateConfig,
  });
  Widget _buildPaymentAccountsSection({
    required AuthProvider authProv,
    required GlobalKey paymentAccountsKey,
    required bool isDark,
    required Color textColor,
    required void Function(VoidCallback) updateConfig,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    if (_loadingData) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_quotation == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(title: const Text("Vista Previa PDF")),
        body: Center(
          child: Text(
            "Error cargando datos del documento",
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
        ),
      );
    }

    final authProv = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            "Vista Previa PDF",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF14141E) : Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: const [
          InfoTooltipButton(
            iconColor: Colors.white,
            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.all(6),
            title: "Guía de Vista Previa PDF",
            description:
                "Personaliza y genera proformas, comprobantes de venta y estados de cuotas en alta definición para imprimir o compartir.",
            tips: [
              InfoTip(
                icon: Icons.aspect_ratio_rounded,
                text:
                    "Alterna entre Hoja A4 ejecutiva y Ticket térmico continuo de 80mm según tu impresora POS configurada.",
              ),
              InfoTip(
                icon: Icons.dashboard_customize_outlined,
                text:
                    "Elige entre 4 plantillas estructurales y 6 paletas de color con guardado como formato predeterminado.",
              ),
              InfoTip(
                icon: Icons.pinch_outlined,
                text:
                    "Haz zoom libre con dos dedos o doble toque en cualquier parte del visor para comprobar importes y cronogramas.",
              ),
              InfoTip(
                icon: Icons.person_search_outlined,
                text:
                    "Vincula clientes CRM o ajusta condiciones y cuentas de cobro al pie antes de exportar.",
              ),
              InfoTip(
                icon: Icons.share_outlined,
                text:
                    "Guarda el PDF en Descargas, imprime directo por Bluetooth/WiFi o compártelo al instante.",
              ),
            ],
          ),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildQuickControlsBar(isDark),
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
                          maxPageWidth: _config.pageSize == PdfPageSize.ticket80
                              ? 400
                              : 700,
                          loadingWidget: const Center(
                            child: CircularProgressIndicator(),
                          ),
                          pdfFileName:
                              "${_config.documentTitle ?? 'DOCUMENTO'}_${_quotation!.id}.pdf",
                        ),
                      ),
                    ),
                  ),
                  _buildZoomHintPill(),
                  _buildZoomFloatingBar(isDark),
                ],
              ),
            ),
          ),
          _buildBottomToolbar(context, isDark),
        ],
      ),
    );
  }
}

class _PdfPreviewScreenState extends _PdfPreviewScreenStateBase
    with
        _PdfPreviewToolbarsMixin,
        _PdfConfigModalMixin,
        _PdfConfigDesignTabMixin,
        _PdfConfigBusinessTabMixin,
        _PdfConfigFooterChipsSectionMixin,
        _PdfConfigTableTabMixin {}
