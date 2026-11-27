import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/utils/app_date_formatter.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/models/notification_model.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/notification_toast_feedback.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/screens/product_edit_screen.dart';

part 'stock_analysis/stock_analysis_actions_part.dart';
part 'stock_analysis/stock_analysis_diagnostic_part.dart';
part 'stock_analysis/stock_analysis_restock_and_kardex_part.dart';

class StockAnalysisModal extends StatefulWidget {
  final NotificationModel notif;
  final Product product;
  final bool isDark;
  final List<Map<String, dynamic>>? initialLedger;

  const StockAnalysisModal({
    super.key,
    required this.notif,
    required this.product,
    required this.isDark,
    this.initialLedger,
  });

  static Future<void> show(
    BuildContext context, {
    required NotificationModel notif,
    Product? product,
    required bool isDark,
  }) async {
    Product? targetProduct = product;
    if (targetProduct == null) {
      final pId = notif.objetoRelacionadoId;
      if (pId == null) {
        NotificationToastFeedback.showError(
          context,
          "No se encontró el ID del producto asociado",
        );
        return;
      }
      final invProv = Provider.of<InventoryProvider>(context, listen: false);
      targetProduct = await invProv.getFullProductWithFallback(pId);
      if (targetProduct == null) {
        if (context.mounted) {
          NotificationToastFeedback.showError(
            context,
            "Producto no encontrado en inventario",
          );
        }
        return;
      }
    }

    if (!context.mounted) {
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => StockAnalysisModal(
        notif: notif,
        product: targetProduct!,
        isDark: isDark,
      ),
    );
  }

  @override
  State<StockAnalysisModal> createState() => _StockAnalysisModalState();
}

class _StockAnalysisModalState extends State<StockAnalysisModal> {
  late Product _product;
  int _selectedPresIndex = 0;
  List<Map<String, dynamic>> _ledgerMovements = [];
  bool _isLoadingLedger = true;
  bool _isSavingStock = false;

  final TextEditingController _quickQtyCtrl = TextEditingController(text: "5");
  late int _currentThreshold;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _initThreshold();
    if (widget.initialLedger != null) {
      _ledgerMovements = List<Map<String, dynamic>>.from(widget.initialLedger!);
      _isLoadingLedger = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadLedger();
        }
      });
    }
  }

  void _updateState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void _initThreshold() {
    if (_product.presentaciones.isNotEmpty) {
      final pres = _product.presentaciones[_selectedPresIndex];
      final alert = pres.stockAlerta;
      _currentThreshold = (alert != null && alert > 0) ? alert : 5;
    } else {
      _currentThreshold = 5;
    }
  }

  @override
  void dispose() {
    _quickQtyCtrl.dispose();
    super.dispose();
  }

  ProductPresentation? get _selectedPres {
    if (_product.presentaciones.isEmpty) {
      return null;
    }
    if (_selectedPresIndex >= _product.presentaciones.length) {
      _selectedPresIndex = 0;
    }
    return _product.presentaciones[_selectedPresIndex];
  }

  bool get _isShared {
    final pres = _selectedPres;
    return (pres?.usaStockCompartido == true ||
        _product.modoStock == 'COMPARTIDO');
  }

  int get _currentStock {
    if (_isShared) {
      return _product.stockCompartido;
    }
    return _selectedPres?.stockActual ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final pres = _selectedPres;
    final int stock = _currentStock;
    final int umbral = _currentThreshold;
    final bool isSafe = stock > umbral;
    final bool isAgotado = stock <= 0;

    final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(
      context,
      minPadding: kMinDefensiveBottomClearance,
    );

    final bgCardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final sectionBg = isDark ? const Color(0xFF1E1E28) : Colors.grey[50];
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    final Color healthColor = isAgotado
        ? Colors.red
        : (stock <= umbral ? Colors.amber[700]! : Colors.green[600]!);

    final double healthPercent = umbral > 0
        ? (stock / (umbral * 2)).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: sectionBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          _buildHeader(
            isDark: isDark,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          const Divider(height: 1),
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      (!_isLoadingLedger && _ledgerMovements.isNotEmpty)
                          ? 0
                          : effectiveBottom + 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildVariantSelector(
                          isDark: isDark,
                          subtitleColor: subtitleColor,
                        ),
                        _buildDiagnosticCard(
                          isDark: isDark,
                          bgCardColor: bgCardColor,
                          textColor: textColor,
                          subtitleColor: subtitleColor,
                          healthColor: healthColor,
                          healthPercent: healthPercent,
                          isSafe: isSafe,
                          isAgotado: isAgotado,
                          stock: stock,
                          umbral: umbral,
                          pres: pres,
                        ),
                        const SizedBox(height: 16),
                        _buildQuickRestockCard(
                          isDark: isDark,
                          bgCardColor: bgCardColor,
                          textColor: textColor,
                          subtitleColor: subtitleColor,
                        ),
                        const SizedBox(height: 16),
                        _buildThresholdCard(
                          isDark: isDark,
                          bgCardColor: bgCardColor,
                          textColor: textColor,
                          subtitleColor: subtitleColor,
                        ),
                        const SizedBox(height: 16),
                        _buildKardexHeader(
                          isDark: isDark,
                          bgCardColor: bgCardColor,
                          textColor: textColor,
                          subtitleColor: subtitleColor,
                          stock: stock,
                        ),
                      ],
                    ),
                  ),
                ),
                if (!_isLoadingLedger && _ledgerMovements.isNotEmpty)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      effectiveBottom + 20,
                    ),
                    sliver: DecoratedSliver(
                      decoration: BoxDecoration(
                        color: bgCardColor,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                        border: Border(
                          left: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade200,
                          ),
                          right: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade200,
                          ),
                          bottom: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade200,
                          ),
                        ),
                      ),
                      sliver: SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                        sliver: SliverList.separated(
                          itemCount: _ledgerMovements.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: isDark ? Colors.white10 : Colors.grey[200],
                          ),
                          itemBuilder: (_, i) => _buildKardexRow(
                            _ledgerMovements[i],
                            isDark: isDark,
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildDockedFooter(
            isDark: isDark,
            bgCardColor: bgCardColor,
            effectiveBottom: effectiveBottom,
          ),
        ],
      ),
    );
  }
}
