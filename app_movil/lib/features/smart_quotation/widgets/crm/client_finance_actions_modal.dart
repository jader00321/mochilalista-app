import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

class ClientFinanceActionsModal extends StatefulWidget {
  final ClientModel client;
  final bool isDark;

  const ClientFinanceActionsModal({
    super.key,
    required this.client,
    required this.isDark,
  });

  @override
  State<ClientFinanceActionsModal> createState() => _ClientFinanceActionsModalState();
}

class _ClientFinanceActionsModalState extends State<ClientFinanceActionsModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _numCuotasCtrl = TextEditingController(text: "2");
  final _interestCtrl = TextEditingController(text: "0");

  String _withdrawMethod = "Efectivo";
  String _loanMethod = "Efectivo";
  String _frecuencia = "mensual";

  // Fecha de vencimiento para préstamo simple (1 cuota)
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  // Fraccionamiento en cuotas múltiples
  bool _splitInQuotas = false;
  final List<InstallmentModel> _installments = [];

  bool _isLoading = false;

  final List<String> _motivosSug = [
    "Préstamo personal",
    "Fiado mercadería",
    "Adelanto de trabajo",
    "Emergencia",
    "Otros",
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _amountCtrl.addListener(() {
      if (mounted) setState(() {});
      if (_splitInQuotas) {
        _recalculateMultipleInstallments();
      }
    });

    _numCuotasCtrl.addListener(() {
      if (_splitInQuotas) _recalculateMultipleInstallments();
    });

    _interestCtrl.addListener(() {
      if (_splitInQuotas) _recalculateMultipleInstallments();
    });

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _amountCtrl.clear();
        _noteCtrl.clear();
        _installments.clear();
        _splitInQuotas = false;
        _dueDate = DateTime.now().add(const Duration(days: 30));
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _numCuotasCtrl.dispose();
    _interestCtrl.dispose();
    super.dispose();
  }

  DateTime _addFrequency(DateTime date) {
    if (_frecuencia == "diario") return date.add(const Duration(days: 1));
    if (_frecuencia == "semanal") return date.add(const Duration(days: 7));
    if (_frecuencia == "quincenal") return date.add(const Duration(days: 15));
    return DateTime(date.year, date.month + 1, date.day);
  }

  void _recalculateMultipleInstallments() {
    double amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    if (amount <= 0) {
      _installments.clear();
      return;
    }

    double interestRate = double.tryParse(_interestCtrl.text) ?? 0.0;
    double finalDebt = amount + (amount * interestRate / 100);

    int numCuotas = int.tryParse(_numCuotasCtrl.text) ?? 2;
    if (numCuotas < 2) numCuotas = 2;

    double basePerQuota = finalDebt / numCuotas;
    _installments.clear();

    DateTime currentDate = DateTime.now();
    double accumulated = 0;

    for (int i = 1; i <= numCuotas; i++) {
      currentDate = _addFrequency(currentDate);
      double amt = (i == numCuotas)
          ? double.parse((finalDebt - accumulated).toStringAsFixed(2))
          : double.parse(basePerQuota.toStringAsFixed(2));
      accumulated += amt;
      _installments.add(InstallmentModel(
        installmentNumber: i,
        amount: amt,
        dueDate: DateFormat('yyyy-MM-dd').format(currentDate),
        status: "pendiente",
      ));
    }
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (context, child) {
        return Theme(
          data: widget.isDark ? ThemeData.dark() : ThemeData.light(),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dueDate) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _editInstallmentDate(int index) async {
    final current = DateTime.tryParse(_installments[index].dueDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (context, child) {
        return Theme(
          data: widget.isDark ? ThemeData.dark() : ThemeData.light(),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        final c = _installments[index];
        _installments[index] = InstallmentModel(
          installmentNumber: c.installmentNumber,
          amount: c.amount,
          dueDate: DateFormat('yyyy-MM-dd').format(picked),
          status: c.status,
        );
      });
    }
  }

  void _submitAction(TrackingProvider provider) {
    double amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    if (amount <= 0) {
      CustomSnackBar.show(context, message: "Ingresa un monto válido mayor a 0", isError: true);
      return;
    }

    if (_tabController.index == 0) {
      // Retiro de saldo
      if (amount > widget.client.saldoAFavor) {
        CustomSnackBar.show(context, message: "El monto supera el saldo a favor disponible", isError: true);
        return;
      }
      _executeSubmitWithdrawal(provider, amount);
    } else {
      // Préstamo
      String motivo = _noteCtrl.text.trim();
      if (motivo.isEmpty) {
        motivo = "Préstamo personal";
      }

      double interestRate = _splitInQuotas ? (double.tryParse(_interestCtrl.text) ?? 0.0) : 0.0;

      List<InstallmentModel> finalInstallments = [];
      if (_splitInQuotas && _installments.isNotEmpty) {
        finalInstallments = List.from(_installments);
      } else {
        // Cuota única nativa con fecha de vencimiento seleccionada
        finalInstallments = [
          InstallmentModel(
            installmentNumber: 1,
            amount: amount,
            dueDate: DateFormat('yyyy-MM-dd').format(_dueDate),
            status: "pendiente",
          ),
        ];
      }

      double finalDebt = finalInstallments.fold(0.0, (sum, c) => sum + c.amount);
      _showPreConfirmDialog(provider, amount, interestRate, finalDebt, motivo, finalInstallments);
    }
  }

  Future<void> _executeSubmitWithdrawal(TrackingProvider provider, double amount) async {
    setState(() => _isLoading = true);
    bool ok = await provider.withdrawBalance(widget.client.id, amount, _withdrawMethod);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) {
      CustomSnackBar.show(context, message: "Retiro registrado correctamente");
      Navigator.pop(context);
    }
  }

  Future<void> _executeSubmitLoan(
    TrackingProvider provider,
    double amount,
    double interestRate,
    double finalDebt,
    String motivo,
    List<InstallmentModel> installments,
  ) async {
    setState(() => _isLoading = true);
    bool ok = await provider.registerLoan(
      widget.client.id,
      amount,
      motivo,
      interestRate: interestRate,
      metodoPago: _loanMethod,
      installments: installments,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) {
      CustomSnackBar.show(context, message: "Préstamo registrado correctamente");
      Navigator.pop(context);
    }
  }

  void _showPreConfirmDialog(
    TrackingProvider provider,
    double amount,
    double interestRate,
    double finalDebt,
    String motivo,
    List<InstallmentModel> installments,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.account_balance, color: widget.isDark ? Colors.orange[300] : Colors.orange[800], size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Confirmar Préstamo",
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSummaryRow("Monto Base:", AppCurrency.format(amount)),
                if (interestRate > 0)
                  _buildSummaryRow(
                    "Interés (${interestRate.toStringAsFixed(1)}%):",
                    AppCurrency.format(finalDebt - amount),
                  ),
                const Divider(),
                _buildSummaryRow("Total a Cobrar:", AppCurrency.format(finalDebt), isBold: true),
                const SizedBox(height: 8),
                _buildSummaryRow("Motivo:", motivo),
                _buildSummaryRow("Entrega en:", _loanMethod),
                const SizedBox(height: 16),
                Text(
                  "Cronograma de Cuotas (${installments.length}):",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.grey[300] : Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: installments.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: widget.isDark ? Colors.white10 : Colors.grey[200]),
                    itemBuilder: (ctx, i) {
                      final c = installments[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Cuota ${c.installmentNumber} • ${DateFormat('dd/MM/yyyy').format(DateTime.parse(c.dueDate))}",
                              style: TextStyle(
                                fontSize: 13,
                                color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
                              ),
                            ),
                            Text(
                              AppCurrency.format(c.amount),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: widget.isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Revisar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isDark ? Colors.orange[800] : Colors.orange[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _executeSubmitLoan(provider, amount, interestRate, finalDebt, motivo, installments);
            },
            child: const Text("Confirmar y Guardar", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isBold ? 16 : 14,
              color: isBold
                  ? (widget.isDark ? Colors.orange[300] : Colors.orange[800])
                  : (widget.isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final surfaceColor = widget.isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final provider = Provider.of<TrackingProvider>(context);

    double enteredAmount = double.tryParse(_amountCtrl.text) ?? 0.0;
    bool isWithdrawTab = _tabController.index == 0;
    bool hasAvailableBalance = widget.client.saldoAFavor > 0.01;

    bool canSubmitWithdraw = isWithdrawTab && hasAvailableBalance && enteredAmount > 0 && enteredAmount <= widget.client.saldoAFavor;
    bool canSubmitLoan = !isWithdrawTab && enteredAmount > 0;
    bool canSubmit = isWithdrawTab ? canSubmitWithdraw : canSubmitLoan;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(76),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 26,
                    color: widget.isDark ? Colors.blueGrey[300] : Colors.blueGrey[700],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Operaciones Financieras",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // TabBar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white.withAlpha(12) : Colors.grey[200],
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: widget.isDark ? Colors.blueGrey[700] : Colors.blueGrey[800],
                  boxShadow: [
                    if (!widget.isDark)
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.output, size: 18),
                        SizedBox(width: 8),
                        Text("Retirar"),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance, size: 18),
                        SizedBox(width: 8),
                        Text("Préstamo"),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // TabBarView
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ==================== TAB 1: RETIRO ====================
                  _buildWithdrawTab(textColor, hasAvailableBalance, enteredAmount),

                  // ==================== TAB 2: PRÉSTAMO ====================
                  _buildLoanTab(textColor, enteredAmount),
                ],
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(top: BorderSide(color: widget.isDark ? Colors.white10 : Colors.grey.shade200)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: canSubmit && !_isLoading ? () => _submitAction(provider) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isWithdrawTab ? Colors.teal : Colors.orange[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: canSubmit ? 2 : 0,
                    disabledBackgroundColor: widget.isDark ? Colors.white10 : Colors.grey[300],
                    disabledForegroundColor: widget.isDark ? Colors.grey[600] : Colors.grey[500],
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          isWithdrawTab ? "Confirmar Retiro" : "Registrar Préstamo",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawTab(Color textColor, bool hasAvailableBalance, double enteredAmount) {
    if (!hasAvailableBalance) {
      // Estado educativo claro cuando no hay saldo a favor
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.savings_outlined, color: Colors.teal, size: 40),
              ),
              const SizedBox(height: 18),
              Text(
                "Sin Saldo a Favor Disponible",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Saldo Disponible: ${AppCurrency.format(widget.client.saldoAFavor)}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.isDark ? Colors.white10 : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  "El saldo a favor se genera automáticamente cuando el cliente realiza abonos mayores a su deuda o se le aprueba una devolución de mercadería.\n\nActualmente este cliente no posee saldo a favor acumulado para retirar.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Flujo normal cuando sí hay saldo disponible
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        // Balance Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Saldo a Favor Disponible",
                    style: TextStyle(
                      color: widget.isDark ? Colors.teal[200] : Colors.teal[900],
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppCurrency.format(widget.client.saldoAFavor),
                    style: TextStyle(
                      color: widget.isDark ? Colors.teal[300] : Colors.teal[800],
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.account_balance_wallet, color: Colors.teal, size: 36),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Quick action chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: Text("Retirar Todo (${AppCurrency.format(widget.client.saldoAFavor)})"),
              backgroundColor: widget.isDark ? Colors.teal.withValues(alpha: 0.15) : Colors.teal[50],
              side: BorderSide(color: Colors.teal.withValues(alpha: 0.4)),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal),
              onPressed: () {
                _amountCtrl.text = widget.client.saldoAFavor.toStringAsFixed(2);
              },
            ),
            ActionChip(
              label: const Text("Retirar 50%"),
              backgroundColor: widget.isDark ? Colors.white10 : Colors.grey[100],
              side: BorderSide(color: widget.isDark ? Colors.white10 : Colors.grey.shade300),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: widget.isDark ? Colors.white70 : Colors.black87,
              ),
              onPressed: () {
                final half = (widget.client.saldoAFavor / 2);
                _amountCtrl.text = half.toStringAsFixed(2);
              },
            ),
          ],
        ),

        const SizedBox(height: 20),

        Text("Monto a Retirar", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
        const SizedBox(height: 8),
        _buildInputLarge(ctrl: _amountCtrl, isDark: widget.isDark, textColor: textColor, isInt: false),

        if (enteredAmount > widget.client.saldoAFavor) ...[
          const SizedBox(height: 6),
          const Text(
            "⚠️ El monto supera el saldo disponible para retiro",
            style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],

        const SizedBox(height: 22),

        Text("Método de entrega", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildMethodChip("Efectivo", Icons.money, true),
            _buildMethodChip("Yape", Icons.qr_code_2, true),
            _buildMethodChip("Plin", Icons.qr_code, true),
            _buildMethodChip("Transferencia", Icons.account_balance, true),
          ],
        ),
      ],
    );
  }

  Widget _buildLoanTab(Color textColor, double enteredAmount) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // Banner informativo
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Registrar Préstamo o Venta al Fiado",
                  style: TextStyle(
                    color: widget.isDark ? Colors.orange[200] : Colors.orange[900],
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        Text("Monto del Préstamo", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
        const SizedBox(height: 8),
        _buildInputLarge(ctrl: _amountCtrl, isDark: widget.isDark, textColor: textColor, isInt: false),

        const SizedBox(height: 20),

        Text("Método de entrega", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildMethodChip("Efectivo", Icons.money, false),
            _buildMethodChip("Yape", Icons.qr_code_2, false),
            _buildMethodChip("Plin", Icons.qr_code, false),
            _buildMethodChip("Transferencia", Icons.account_balance, false),
          ],
        ),

        const SizedBox(height: 20),

        // Motivo / Detalle con Wrap para cero cortes
        Text("Motivo / Detalle", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _motivosSug.map((motivo) {
            final isSelected = _noteCtrl.text == motivo;
            return ChoiceChip(
              label: Text(motivo),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  _noteCtrl.text = motivo;
                  FocusScope.of(context).unfocus();
                  setState(() {});
                }
              },
              selectedColor: Colors.orange.withValues(alpha: 0.25),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.orange : (widget.isDark ? Colors.grey[300] : Colors.grey[800]),
              ),
              backgroundColor: widget.isDark ? Colors.white10 : Colors.grey[100],
              side: BorderSide(
                color: isSelected ? Colors.orange : (widget.isDark ? Colors.white10 : Colors.grey.shade300),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 12),

        TextField(
          controller: _noteCtrl,
          maxLines: 2,
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: "Ej. Préstamo personal, Fiado mercadería...",
            hintStyle: TextStyle(color: widget.isDark ? Colors.grey[500] : Colors.grey),
            filled: true,
            fillColor: widget.isDark ? const Color(0xFF14141C) : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: widget.isDark ? Colors.white10 : Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: widget.isDark ? Colors.white10 : Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),

        const SizedBox(height: 22),

        // Fecha de vencimiento (Por defecto para 1 cuota)
        if (!_splitInQuotas) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF14141C) : Colors.grey[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade300),
            ),
            child: InkWell(
              onTap: () => _selectDueDate(context),
              child: Row(
                children: [
                  Icon(Icons.event_available, color: widget.isDark ? Colors.orange[300] : Colors.orange[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Fecha de Vencimiento (1 cuota)",
                          style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd/MM/yyyy').format(_dueDate),
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.edit_calendar, color: widget.isDark ? Colors.orange[300] : Colors.orange[700], size: 20),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 14),

        // Switch Fraccionamiento
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "¿Dividir en cuotas o aplicar interés?",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
          ),
          subtitle: Text(
            _splitInQuotas ? "Fraccionado en cuotas periódicas" : "Cuota única al vencimiento",
            style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          value: _splitInQuotas,
          activeThumbColor: Colors.orange,
          onChanged: (val) {
            setState(() {
              _splitInQuotas = val;
              if (val) {
                _recalculateMultipleInstallments();
              } else {
                _installments.clear();
              }
            });
          },
        ),

        if (_splitInQuotas) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildInput(
                  label: "N° Cuotas",
                  ctrl: _numCuotasCtrl,
                  isDark: widget.isDark,
                  textColor: textColor,
                  isInt: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _buildInput(
                  label: "Interés",
                  suffix: "%",
                  ctrl: _interestCtrl,
                  isDark: widget.isDark,
                  textColor: textColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: _frecuencia,
                  dropdownColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
                  style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: "Frecuencia",
                    labelStyle: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                    filled: true,
                    fillColor: widget.isDark ? const Color(0xFF14141C) : Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: "diario", child: Text("Diario")),
                    DropdownMenuItem(value: "semanal", child: Text("Semanal")),
                    DropdownMenuItem(value: "quincenal", child: Text("Quincenal")),
                    DropdownMenuItem(value: "mensual", child: Text("Mensual")),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _frecuencia = v;
                        _recalculateMultipleInstallments();
                      });
                    }
                  },
                ),
              ),
            ],
          ),

          if (_installments.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Cronograma Generado", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Total: ${AppCurrency.format(_installments.fold<double>(0.0, (sum, c) => sum + c.amount))}",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.orange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade200),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: _installments.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: widget.isDark ? Colors.white10 : Colors.grey[200]),
                itemBuilder: (ctx, i) {
                  final cuota = _installments[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.orange.withValues(alpha: 0.2),
                          child: Text(
                            "${cuota.installmentNumber}",
                            style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => _editInstallmentDate(i),
                            child: Row(
                              children: [
                                Text(
                                  DateFormat('dd/MM/yyyy').format(DateTime.parse(cuota.dueDate)),
                                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.edit_calendar, size: 15, color: widget.isDark ? Colors.blue[300] : Colors.blue[600]),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          AppCurrency.format(cuota.amount),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildMethodChip(String method, IconData icon, bool isWithdraw) {
    bool isSelected = isWithdraw ? _withdrawMethod == method : _loanMethod == method;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : (widget.isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
          const SizedBox(width: 6),
          Text(method),
        ],
      ),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            if (isWithdraw) {
              _withdrawMethod = method;
            } else {
              _loanMethod = method;
            }
          });
        }
      },
      selectedColor: isWithdraw ? Colors.teal : Colors.orange[800],
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (widget.isDark ? Colors.grey[300] : Colors.grey[800]),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 13,
      ),
      backgroundColor: widget.isDark ? Colors.white10 : Colors.grey[100],
      side: BorderSide(
        color: isSelected
            ? (isWithdraw ? Colors.teal : (Colors.orange[800] ?? Colors.orange))
            : (widget.isDark ? Colors.white10 : Colors.grey.shade300),
      ),
    );
  }

  Widget _buildInputLarge({
    required TextEditingController ctrl,
    required bool isDark,
    required Color textColor,
    required bool isInt,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isInt ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: isInt
          ? [FilteringTextInputFormatter.digitsOnly]
          : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
      decoration: InputDecoration(
        prefixText: "S/ ",
        prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
        filled: true,
        fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildInput({
    required String label,
    String? prefix,
    String? suffix,
    required TextEditingController ctrl,
    required bool isDark,
    required Color textColor,
    bool isInt = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isInt ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: isInt
          ? [FilteringTextInputFormatter.digitsOnly]
          : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
        prefixText: prefix,
        suffixText: suffix,
        filled: true,
        fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
    );
  }
}
