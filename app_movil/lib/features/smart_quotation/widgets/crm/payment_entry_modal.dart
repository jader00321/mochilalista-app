import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/general_preview_tab.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';

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

class _PaymentEntryModalState extends State<PaymentEntryModal> with SingleTickerProviderStateMixin {
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
    }
    
    _amountCtrl.addListener(() {
      if (mounted) setState(() {}); 
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.92, 
      padding: EdgeInsets.only(
        bottom: InteractiveSheetWrapper.getEffectiveBottomPadding(context, minPadding: 16.0, includeKeyboard: true),
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
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
          )
        ],
      ),
    );
  }

  /// Mini-Header Compacto (< 48px) que maximiza el 85% de la pantalla en Pago Específico
  Widget _buildCollapsedStickyMiniHeader(double enteredAmount, Color textColor, bool isDark) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        // Arrastrar hacia abajo directamente sobre el mini-header lo re-despliega
        if (details.primaryDelta != null && details.primaryDelta! > 5) {
          setState(() => _isHeaderCollapsed = false);
        }
      },
      onTap: () => setState(() => _isHeaderCollapsed = false),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B1B26) : Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.payments_rounded, size: 18, color: Colors.green),
                  const SizedBox(width: 5),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppCurrency.format(enteredAmount),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.green),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text("•", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 10)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _method,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (_selectedTargetId != null) ...[
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedTargetType = null;
                    _selectedTargetId = null;
                    _amountCtrl.clear();
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.red.withValues(alpha: 0.15) : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.red.withValues(alpha: 0.3) : Colors.red.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Limpiar",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.red[300] : Colors.red[700],
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.close, size: 12, color: isDark ? Colors.red[300] : Colors.red[700]),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            InkWell(
              onTap: () => setState(() => _isHeaderCollapsed = false),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Modificar",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.blue[300] : Colors.blue[800],
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.edit, size: 12, color: isDark ? Colors.blue[300] : Colors.blue[800]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta compacta de monto rápido para distribuir en 1 sola fila con Expanded
  Widget _buildQuickAmountCard({
    required String label,
    required double amount,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
    bool isWarning = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: isWarning
              ? (isDark ? Colors.orange.withValues(alpha: 0.12) : Colors.orange.shade50)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isWarning
                ? Colors.orange.withValues(alpha: 0.35)
                : (isDark ? Colors.white12 : Colors.grey.shade300),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isWarning
                    ? (isDark ? Colors.orange[300] : Colors.orange[900])
                    : (isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                AppCurrency.format(amount),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cabecera Extendida con Input, Chips Rápidos en 1 Fila y Métodos de Pago en 1 Fila
  Widget _buildExpandedHeaderInputs(
    double enteredAmount,
    double targetDebt,
    double? oldestInstallmentAmt,
    Color textColor,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campo Monto
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: isDark ? Colors.green[400] : Colors.green[800],
            ),
            decoration: InputDecoration(
              labelText: "Monto a abonar",
              labelStyle: TextStyle(color: isDark ? Colors.green[200] : Colors.green[800], fontSize: 14),
              prefixText: "S/ ",
              prefixStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: isDark ? Colors.green[400] : Colors.green[800],
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              filled: true,
              fillColor: isDark ? Colors.green.withValues(alpha: 0.1) : Colors.green[50],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              isDense: true,
            ),
          ),

          const SizedBox(height: 8),

          // Chips de Monto Rápido en 1 Sola Fila Horizontal Equitativa
          Row(
            children: [
              Expanded(
                child: _buildQuickAmountCard(
                  label: "Total",
                  amount: widget.client.totalDebt,
                  color: isDark ? Colors.green[300]! : const Color(0xFF2E7D32),
                  isDark: isDark,
                  onTap: () {
                    _amountCtrl.text = widget.client.totalDebt.toStringAsFixed(2);
                  },
                ),
              ),
              const SizedBox(width: 8),
              if (oldestInstallmentAmt != null && oldestInstallmentAmt > 0) ...[
                Expanded(
                  child: _buildQuickAmountCard(
                    label: "Cuota Ant.",
                    amount: oldestInstallmentAmt,
                    color: isDark ? Colors.orange[300]! : Colors.orange[800]!,
                    isDark: isDark,
                    isWarning: true,
                    onTap: () {
                      _amountCtrl.text = oldestInstallmentAmt.toStringAsFixed(2);
                    },
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _buildQuickAmountCard(
                  label: "50% Deuda",
                  amount: widget.client.totalDebt / 2,
                  color: isDark ? Colors.blue[300]! : Colors.blue[800]!,
                  isDark: isDark,
                  onTap: () {
                    final half = widget.client.totalDebt / 2;
                    _amountCtrl.text = half.toStringAsFixed(2);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Selector de Métodos de Pago en 1 Sola Fila Horizontal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Método de Pago",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
              if (_tabController.index == 1)
                InkWell(
                  onTap: () => setState(() => _isHeaderCollapsed = true),
                  child: Row(
                    children: [
                      Text(
                        "Compactar",
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.expand_less, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Strip horizontal deslizable con física elástica, desvanecimiento lateral y auto-scroll
          SizedBox(
            height: 38,
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.white,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.85, 0.94, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                controller: _paymentMethodScrollCtrl,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(left: 2, right: 28),
                child: Row(
                  children: [
                    if (widget.client.saldoAFavor > 0) "Saldo a Favor",
                    "Efectivo",
                    "Yape",
                    "Plin",
                    "Transferencia",
                    "Tarjeta",
                  ].map((m) {
                  final isSelected = _method == m;
                  final isSaldoBtn = m == "Saldo a Favor";

                  IconData methodIcon;
                  Color activeColor;
                  switch (m) {
                    case "Saldo a Favor":
                      methodIcon = Icons.savings_outlined;
                      activeColor = Colors.amber;
                      break;
                    case "Efectivo":
                      methodIcon = Icons.payments_outlined;
                      activeColor = Colors.green;
                      break;
                    case "Yape":
                      methodIcon = Icons.qr_code_2_rounded;
                      activeColor = Colors.purpleAccent;
                      break;
                    case "Plin":
                      methodIcon = Icons.bolt_rounded;
                      activeColor = Colors.cyan;
                      break;
                    case "Transferencia":
                      methodIcon = Icons.account_balance_outlined;
                      activeColor = Colors.blueAccent;
                      break;
                    case "Tarjeta":
                    default:
                      methodIcon = Icons.credit_card_outlined;
                      activeColor = Colors.deepPurpleAccent;
                      break;
                  }

                  return Builder(
                    builder: (itemCtx) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _method = m;
                              if (isSaldoBtn && _amountCtrl.text.isEmpty) {
                                double capAmount = widget.client.saldoAFavor < targetDebt
                                    ? widget.client.saldoAFavor
                                    : targetDebt;
                                _amountCtrl.text = capAmount.toStringAsFixed(2);
                              }
                            });
                            // Auto-scroll suave para centrar y asegurar visibilidad completa del método tocado
                            Scrollable.ensureVisible(
                              itemCtx,
                              alignment: 0.5,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            );
                          },
                          borderRadius: BorderRadius.circular(19),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark
                                      ? activeColor.withValues(alpha: 0.25)
                                      : (isSaldoBtn ? Colors.amber.shade100 : Colors.green.shade100))
                                  : (isDark ? const Color(0xFF14141C) : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(19),
                              border: Border.all(
                                color: isSelected
                                    ? (isDark
                                        ? activeColor.withValues(alpha: 0.7)
                                        : (isSaldoBtn ? Colors.amber.shade700 : Colors.green.shade700))
                                    : (isDark ? Colors.white12 : Colors.grey.shade300),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  methodIcon,
                                  size: 16,
                                  color: isSelected
                                      ? (isDark
                                          ? (isSaldoBtn ? Colors.amber[300] : Colors.green[300])
                                          : (isSaldoBtn ? Colors.amber[900] : Colors.green[900]))
                                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  m,
                                  style: TextStyle(
                                    color: isSelected
                                        ? (isDark ? Colors.white : (isSaldoBtn ? Colors.amber[900] : Colors.green[900]))
                                        : (isDark ? Colors.grey[300] : Colors.black87),
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ),

          if (_method == "Saldo a Favor")
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                "Saldo Disponible: ${AppCurrency.format(widget.client.saldoAFavor)}",
                style: TextStyle(
                  color: isDark ? Colors.amber[300] : Colors.amber[900],
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildSpecificSelectionTab(List<SaleModel> debts, bool isDark, Color textColor) {
    if (debts.isEmpty) {
      return Center(
        child: Text(
          "No hay deudas específicas pendientes.",
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 15),
        ),
      );
    }

    return Column(
      children: [
        // Banner de Instrucción Colapsable
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          clipBehavior: Clip.hardEdge,
          child: _isHeaderCollapsed
              ? const SizedBox.shrink()
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue[50],
                  child: Row(
                    children: [
                      Icon(Icons.touch_app_outlined, color: isDark ? Colors.blue[300] : Colors.blue[800], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Selecciona la venta o cuota exacta que se amortizará.",
                          style: TextStyle(
                            color: isDark ? Colors.blue[200] : Colors.blue[900],
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_selectedTargetId != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedTargetType = null;
                              _selectedTargetId = null;
                              _amountCtrl.clear();
                              _isHeaderCollapsed = false;
                            });
                          },
                          child: Text(
                            "Limpiar",
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.red[300] : Colors.red[700],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),

        // Lista de Deudas con Cuotas
        Expanded(
          child: ListView.builder(
            controller: _specificScrollCtrl,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: debts.length,
            itemBuilder: (ctx, i) {
              final sale = debts[i];
              final double faltaVenta = sale.trueTotalAmount - sale.paidAmount;
              
              bool isLoan = sale.origenVenta == 'prestamo_personal';
              String entityName = isLoan ? "Préstamo" : "Venta";
              bool isSaleSelected = _selectedTargetType == 'venta' && _selectedTargetId == sale.id;

              return Card(
                elevation: 0,
                color: isDark ? const Color(0xFF14141C) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSaleSelected
                        ? Colors.blue
                        : (isDark ? Colors.white10 : Colors.grey.shade300),
                    width: isSaleSelected ? 2 : 1,
                  ),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: sale.installments.isEmpty
                  ? RadioListTile<String>(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      value: "venta_${sale.id}",
                      // ignore: deprecated_member_use
                      groupValue: _selectedTargetType != null ? "${_selectedTargetType}_$_selectedTargetId" : null,
                      // ignore: deprecated_member_use
                      onChanged: (val) {
                        setState(() {
                          _selectedTargetType = 'venta';
                          _selectedTargetId = sale.id;
                          _amountCtrl.text = faltaVenta.toStringAsFixed(2);
                          _isHeaderCollapsed = true; // Maximiza espacio vertical
                        });
                      },
                      title: Text(
                        "$entityName #${sale.displayId}",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                      ),
                      subtitle: Text(
                        "Falta: ${AppCurrency.format(faltaVenta)}",
                        style: TextStyle(
                          color: isDark ? Colors.red[300] : Colors.red[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      activeColor: isDark ? Colors.blue[300] : Colors.blue[800],
                    )
                  : Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: debts.length == 1,
                        onExpansionChanged: (expanded) {
                          if (expanded && !_isHeaderCollapsed) {
                            setState(() => _isHeaderCollapsed = true);
                          }
                        },
                        title: Text(
                          "$entityName #${sale.displayId} (A Crédito)",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                        ),
                        subtitle: Text(
                          "Deuda Restante: ${AppCurrency.format(faltaVenta)}",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        iconColor: isDark ? Colors.white : Colors.black,
                        collapsedIconColor: isDark ? Colors.white70 : Colors.grey,
                        children: sale.installments.where((c) => c.status != 'pagado').map((cuota) {
                          final faltaCuota = cuota.amount - cuota.montoPagado;
                          bool isCuotaSelected = _selectedTargetType == 'cuota' && _selectedTargetId == cuota.id;

                          return Container(
                            decoration: BoxDecoration(
                              color: isCuotaSelected
                                  ? (isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue[50])
                                  : (isDark ? Colors.black12 : Colors.grey[50]),
                              border: Border(
                                top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                              ),
                            ),
                            child: RadioListTile<String>(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                              value: "cuota_${cuota.id}",
                              // ignore: deprecated_member_use
                              groupValue: _selectedTargetType != null ? "${_selectedTargetType}_$_selectedTargetId" : null,
                              // ignore: deprecated_member_use
                              onChanged: (val) {
                                setState(() {
                                  _selectedTargetType = 'cuota';
                                  _selectedTargetId = cuota.id;
                                  _amountCtrl.text = faltaCuota.toStringAsFixed(2);
                                  _isHeaderCollapsed = true; // Maximiza espacio vertical
                                });
                              },
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      "Cuota ${cuota.installmentNumber}",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isCuotaSelected ? FontWeight.bold : FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange[100],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "Vence: ${DateFormat('dd/MM').format(DateTime.parse(cuota.dueDate))}",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.orange[300] : Colors.orange[900],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                "Pendiente: ${AppCurrency.format(faltaCuota)}",
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? Colors.green[300] : Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              activeColor: isDark ? Colors.blue[300] : Colors.blue[800],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _submitPayment(double maxDebtAllowed) async {
    double amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    
    if (amount <= 0) {
      CustomSnackBar.show(context, message: "Ingresa un monto válido mayor a 0", isError: true);
      return;
    }

    if (_tabController.index == 1 && _selectedTargetType == null) {
      CustomSnackBar.show(context, message: "Selecciona una cuota o venta a pagar", isError: true);
      return;
    }

    bool isPayingWithSaldo = _method == "Saldo a Favor";

    if (isPayingWithSaldo) {
      if (amount > widget.client.saldoAFavor) {
        CustomSnackBar.show(
          context,
          message: "Saldo a Favor insuficiente. Disponible: ${AppCurrency.format(widget.client.saldoAFavor)}",
          isError: true,
        );
        return;
      }
      if (amount > maxDebtAllowed) {
        amount = maxDebtAllowed;
      }
    } else {
      if (amount > maxDebtAllowed) {
        if (!_keepAsCredit) {
          amount = maxDebtAllowed; 
        }
      }
    }

    setState(() => _isLoading = true);
    
    try {
      final prov = Provider.of<TrackingProvider>(context, listen: false);
      
      bool isAutomatic = _tabController.index == 0;
      int? ventaId = (!isAutomatic && _selectedTargetType == 'venta') ? _selectedTargetId : null;
      int? cuotaId = (!isAutomatic && _selectedTargetType == 'cuota') ? _selectedTargetId : null;

      String backendMethod = _method.toLowerCase().replaceAll(' ', '_');

      bool success = await prov.registerPayment(
        widget.client.id, 
        amount, 
        backendMethod, 
        ventaId: ventaId, 
        cuotaId: cuotaId,
        guardarVuelto: _keepAsCredit && !isPayingWithSaldo,
        isAutomatic: isAutomatic,
      );

      if (mounted) {
        if (success) {
          try {
            Provider.of<SaleProvider>(context, listen: false).silentRefresh();
          } catch (_) {}
          widget.onPaymentSuccess?.call();
          Navigator.pop(context);
          CustomSnackBar.show(context, message: "¡Abono registrado exitosamente!", isError: false);
        } else {
          CustomSnackBar.show(context, message: "Error al registrar pago.", isError: true);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _OptionButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;
  final bool isDark;

  const _OptionButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : (isDark ? const Color(0xFF14141C) : Colors.white),
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          title, 
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}