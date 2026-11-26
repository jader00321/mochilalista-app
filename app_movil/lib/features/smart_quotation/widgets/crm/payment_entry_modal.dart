import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/general_preview_tab.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';

part 'payment_entry_header_and_chips.dart';
part 'payment_entry_specific_and_submit.dart';

class PaymentEntryModal extends StatefulWidget {
  final ClientModel client;
  final String? initialTargetType; 
  final int? initialTargetId;
  final double? initialAmount;
  final VoidCallback? onPaymentSuccess;

  const PaymentEntryModal({
    super.key, 
    required this.client,
    this.initialTargetType,
    this.initialTargetId,
    this.initialAmount,
    this.onPaymentSuccess,
  });

  @override
  State<PaymentEntryModal> createState() => _PaymentEntryModalState();
}

abstract class _PaymentEntryStateBase extends State<PaymentEntryModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _amountCtrl = TextEditingController();
  final ScrollController _specificScrollCtrl = ScrollController();
  final ScrollController _paymentMethodScrollCtrl = ScrollController();
  
  String _method = "Efectivo";
  bool _isLoading = false;
  
  String? _selectedTargetType; 
  int? _selectedTargetId;

  bool _keepAsCredit = false; 

  // Cabecera retráctil para maximizar el espacio en Pago Específico
  bool _isHeaderCollapsed = false;

  // 🏷️ FASE 4: Rastreo unívoco del chip de monto rápido activo para Toggle On/Off
  String? _selectedQuickChipLabel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (widget.initialTargetId != null) {
      _selectedTargetType = widget.initialTargetType;
      _selectedTargetId = widget.initialTargetId;
      _tabController.index = 1;
      _isHeaderCollapsed = true;
    }
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _amountCtrl.text = widget.initialAmount!.toStringAsFixed(2);
      if ((widget.initialAmount! - widget.client.totalDebt).abs() < 0.01) {
        _selectedQuickChipLabel = "Total";
      }
    }
    
    _amountCtrl.addListener(() {
      if (mounted) {
        // Desmarcar chip automáticamente si el usuario escribe o borra un valor manual distinto
        if (_selectedQuickChipLabel != null) {
          final entered = double.tryParse(_amountCtrl.text) ?? 0.0;
          final expected = _getExpectedAmountForLabel(_selectedQuickChipLabel!);
          if ((entered - expected).abs() > 0.01) {
            _selectedQuickChipLabel = null;
          }
        }
        setState(() {});
      }
    });
    
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 0) {
          _isHeaderCollapsed = false;
          _selectedTargetType = null;
          _selectedTargetId = null;
        } else if (_tabController.index == 1) {
          final debts = Provider.of<TrackingProvider>(context, listen: false).currentClientDebts;
          if (debts.length == 1 || _selectedTargetId != null) {
            _isHeaderCollapsed = true;
          }
        }
        if (mounted) setState(() {});
      }
    });

    _specificScrollCtrl.addListener(() {
      if (_tabController.index == 1) {
        // Se compacta únicamente si el usuario se desplaza hacia abajo en la lista
        if (_specificScrollCtrl.offset > 25 && !_isHeaderCollapsed) {
          setState(() => _isHeaderCollapsed = true);
        }
        // NUNCA re-desplegar automáticamente por scroll ascendente o rebote al tope
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = Provider.of<TrackingProvider>(context, listen: false);
      p.loadClientDebts(widget.client.id).then((_) {
        if (mounted && _tabController.index == 1 && (p.currentClientDebts.length == 1 || _selectedTargetId != null)) {
          setState(() => _isHeaderCollapsed = true);
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountCtrl.dispose();
    _specificScrollCtrl.dispose();
    _paymentMethodScrollCtrl.dispose();
    super.dispose();
  }

  double _calculateTargetDebt(TrackingProvider provider) {
    if (_tabController.index == 0) return widget.client.totalDebt;

    double targetDebt = widget.client.totalDebt;

    if (_tabController.index == 1 && _selectedTargetId != null) {
      if (_selectedTargetType == 'venta') {
        try {
          final sale = provider.currentClientDebts.firstWhere((s) => s.id == _selectedTargetId);
          targetDebt = sale.trueTotalAmount - sale.paidAmount;
        } catch (_) {}
      } else if (_selectedTargetType == 'cuota') {
        for (var sale in provider.currentClientDebts) {
          try {
            final cuota = sale.installments.firstWhere((c) => c.id == _selectedTargetId);
            targetDebt = cuota.amount - cuota.montoPagado;
            break;
          } catch (_) {}
        }
      }
    }
    
    return targetDebt;
  }

  double? _getOldestInstallmentAmount(TrackingProvider provider) {
    DateTime? oldestDate;
    double? oldestAmount;

    for (var sale in provider.currentClientDebts) {
      for (var cuota in sale.installments) {
        if (cuota.status != 'pagado') {
          final due = DateTime.tryParse(cuota.dueDate);
          if (due != null) {
            if (oldestDate == null || due.isBefore(oldestDate)) {
              oldestDate = due;
              oldestAmount = cuota.amount - cuota.montoPagado;
            }
          }
        }
      }
    }
    return oldestAmount;
  }

  double _getTotalOverdueAmount(TrackingProvider provider) {
    double total = 0.0;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    for (var sale in provider.currentClientDebts) {
      for (var cuota in sale.installments) {
        if (cuota.status != 'pagado') {
          final due = DateTime.tryParse(cuota.dueDate);
          if (due != null && due.isBefore(todayStart)) {
            total += (cuota.amount - cuota.montoPagado);
          }
        }
      }
    }
    return total;
  }

  double? _getNextUpcomingInstallmentAmount(TrackingProvider provider) {
    DateTime? earliestFuture;
    double? nextAmt;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    for (var sale in provider.currentClientDebts) {
      for (var cuota in sale.installments) {
        if (cuota.status != 'pagado') {
          final due = DateTime.tryParse(cuota.dueDate);
          if (due != null && !due.isBefore(todayStart)) {
            if (earliestFuture == null || due.isBefore(earliestFuture)) {
              earliestFuture = due;
              nextAmt = cuota.amount - cuota.montoPagado;
            }
          }
        }
      }
    }
    return nextAmt;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackingProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    double enteredAmount = double.tryParse(_amountCtrl.text) ?? 0.0;
    double maxDebtAllowed = widget.client.totalDebt;
    double targetDebt = _calculateTargetDebt(provider);
    
    bool isPayingWithSaldo = _method == "Saldo a Favor";
    bool generatesChange = !isPayingWithSaldo && (enteredAmount > maxDebtAllowed) && maxDebtAllowed > 0;
    double changeAmount = generatesChange ? (enteredAmount - maxDebtAllowed) : 0.0;

    bool isSpecificTab = _tabController.index == 1;
    bool hasTarget = !isSpecificTab || _selectedTargetId != null;
    bool canSubmit = enteredAmount > 0 && hasTarget && !_isLoading;

    final oldestInstallmentAmt = _getOldestInstallmentAmount(provider);
    final totalOverdueAmt = _getTotalOverdueAmount(provider);
    final nextInstallmentAmt = _getNextUpcomingInstallmentAmount(provider);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92, 
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          maintainBottomViewPadding: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(76),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Bar (Título y Deuda)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Registrar Abono",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Deuda Total: ${AppCurrency.format(widget.client.totalDebt)}",
                          style: TextStyle(
                            color: isDark ? Colors.red[300] : Colors.red[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 26, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ==================== CABECERA DINÁMICA RETRÁCTIL CON ALTURA FLUIDA ====================
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              clipBehavior: Clip.hardEdge,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: (isSpecificTab && _isHeaderCollapsed)
                    ? KeyedSubtree(
                        key: const ValueKey('collapsed_mini_header'),
                        child: _buildCollapsedStickyMiniHeader(enteredAmount, textColor, isDark),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('expanded_header_inputs'),
                        child: _buildExpandedHeaderInputs(
                          enteredAmount,
                          targetDebt,
                          oldestInstallmentAmt,
                          totalOverdueAmt,
                          nextInstallmentAmt,
                          textColor,
                          isDark,
                        ),
                      ),
              ),
            ),

          // ==================== TAB BAR CON PROTECCIÓN ANTI-TRUNCAMIENTO ====================
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14141C) : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark ? Colors.blueGrey[700] : Colors.blueGrey[800],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text("Distribución Automática"),
                  ),
                ),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text("Pago Específico"),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),

          // ==================== CONTENIDO DE LAS PESTAÑAS ====================
          Expanded(
            child: provider.isLoadingDebts
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      GeneralPreviewTab(
                        debts: provider.currentClientDebts, 
                        isDark: isDark, 
                        amount: enteredAmount,
                      ),
                      _buildSpecificSelectionTab(provider.currentClientDebts, isDark, textColor),
                    ],
                  ),
          ),

          // ==================== BANNER DE EXCEDENTE ====================
          if (changeAmount > 0.01)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.amber.withValues(alpha: 0.1) : Colors.amber[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.amber.withValues(alpha: 0.3) : Colors.amber.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: isDark ? Colors.amber[300] : Colors.amber[900], size: 24),
                      const SizedBox(width: 8),
                      Text(
                        "Excedente: ${AppCurrency.format(changeAmount)}",
                        style: TextStyle(
                          color: isDark ? Colors.amber[300] : Colors.amber[900],
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _OptionButton(
                          title: "Dar Vuelto",
                          isSelected: !_keepAsCredit,
                          onTap: () => setState(() => _keepAsCredit = false),
                          color: Colors.orange,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _OptionButton(
                          title: "Guardar Saldo",
                          isSelected: _keepAsCredit,
                          onTap: () => setState(() => _keepAsCredit = true),
                          color: Colors.green,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),

          // ==================== BOTÓN INFERIOR DE ACCIÓN ====================
          Builder(
            builder: (btnCtx) {
              final bottomPadding = InteractiveSheetWrapper.getEffectiveBottomPadding(
                btnCtx,
                minPadding: kMinDefensiveBottomClearance,
                includeKeyboard: true,
              );
              return Container(
                padding: EdgeInsets.fromLTRB(20, 10, 20, bottomPadding),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: canSubmit ? () => _submitPayment(maxDebtAllowed) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: isDark ? Colors.white10 : Colors.grey[300],
                      disabledForegroundColor: isDark ? Colors.grey[600] : Colors.grey[500],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: canSubmit ? 2 : 0,
                    ),
                    child: _isLoading 
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          generatesChange && !_keepAsCredit ? "REGISTRAR Y DAR VUELTO" : "PROCESAR PAGO",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                        ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
  ),
);
}

  /// Mini-Header Compacto (< 48px) que maximiza el 85% de la pantalla en Pago Específico

  Widget _buildCollapsedStickyMiniHeader(double enteredAmount, Color textColor, bool isDark);
  double _getExpectedAmountForLabel(String label);
  Widget _buildExpandedHeaderInputs(
    double enteredAmount,
    double targetDebt,
    double? oldestInstallmentAmt,
    double totalOverdueAmt,
    double? nextInstallmentAmt,
    Color textColor,
    bool isDark,
  );
  Widget _buildSpecificSelectionTab(List<SaleModel> debts, bool isDark, Color textColor);
  void _submitPayment(double maxDebtAllowed);
}

class _PaymentEntryModalState extends _PaymentEntryStateBase
    with
        _PaymentEntryHeaderAndChipsMixin,
        _PaymentEntrySpecificAndSubmitMixin {}
