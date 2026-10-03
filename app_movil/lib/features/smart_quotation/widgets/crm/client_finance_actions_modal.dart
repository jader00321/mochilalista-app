import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

class ClientFinanceActionsModal extends StatefulWidget {
  final ClientModel client;
  final bool isDark;

  const ClientFinanceActionsModal({super.key, required this.client, required this.isDark});

  @override
  State<ClientFinanceActionsModal> createState() => _ClientFinanceActionsModalState();
}

class _ClientFinanceActionsModalState extends State<ClientFinanceActionsModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _numCuotasCtrl = TextEditingController(text: "1");
  final _interestCtrl = TextEditingController(text: "0");
  
  String _withdrawMethod = "Efectivo";
  String _loanMethod = "Efectivo";
  String _frecuencia = "mensual";
  
  final List<InstallmentModel> _installments = [];
  final List<TextEditingController> _cuotaCtrls = [];
  bool _isScheduleDirty = true;
  Timer? _debounce;
  bool _isLoading = false;

  final List<String> _motivosSug = ["Préstamo personal", "Fiado mercadería", "Adelanto de trabajo", "Emergencia", "Otros"];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _amountCtrl.addListener(() {
      setState(() {}); 
      if (_tabController.index == 1 && _installments.isNotEmpty) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 500), () {
          if (mounted) setState(() { _isScheduleDirty = true; _installments.clear(); _disposeCuotaCtrls(); });
        });
      }
    });
    
    _numCuotasCtrl.addListener(() {
      if (_installments.isNotEmpty) {
        setState(() { _isScheduleDirty = true; _installments.clear(); _disposeCuotaCtrls(); });
      } else if (!_isScheduleDirty) {
        setState(() => _isScheduleDirty = true);
      }
    });
    
    _interestCtrl.addListener(() {
      if (_installments.isNotEmpty) {
        setState(() { _isScheduleDirty = true; _installments.clear(); _disposeCuotaCtrls(); });
      } else if (!_isScheduleDirty) {
        setState(() => _isScheduleDirty = true);
      }
    });
    
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _amountCtrl.clear();
        _noteCtrl.clear();
        _installments.clear();
        _disposeCuotaCtrls();
        _isScheduleDirty = true;
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
    _debounce?.cancel();
    _disposeCuotaCtrls();
    super.dispose();
  }

  void _disposeCuotaCtrls() {
    for (var c in _cuotaCtrls) { c.dispose(); }
    _cuotaCtrls.clear();
  }

  DateTime _addFrequency(DateTime date) {
    if (_frecuencia == "diario") return date.add(const Duration(days: 1));
    if (_frecuencia == "semanal") return date.add(const Duration(days: 7));
    if (_frecuencia == "quincenal") return date.add(const Duration(days: 15));
    return DateTime(date.year, date.month + 1, date.day);
  }

  void _generateInstallments() {
    double amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    if (amount <= 0) return;

    double interestRate = double.tryParse(_interestCtrl.text) ?? 0.0;
    double finalDebt = amount + (amount * interestRate / 100); 

    int numCuotas = int.tryParse(_numCuotasCtrl.text) ?? 1;
    if (numCuotas < 1) numCuotas = 1;

    double basePerQuota = finalDebt / numCuotas;
    
    _installments.clear();
    _disposeCuotaCtrls();

    DateTime currentDate = DateTime.now();
    double accumulated = 0;

    for (int i = 1; i <= numCuotas; i++) {
      currentDate = _addFrequency(currentDate);
      double amt = (i == numCuotas) ? double.parse((finalDebt - accumulated).toStringAsFixed(2)) : double.parse(basePerQuota.toStringAsFixed(2));
      accumulated += amt;
      _installments.add(InstallmentModel(
        installmentNumber: i, amount: amt, dueDate: DateFormat('yyyy-MM-dd').format(currentDate), status: "pendiente"
      ));
      final ctrl = TextEditingController(text: amt.toStringAsFixed(2));
      _cuotaCtrls.add(ctrl);
    }
    
    _isScheduleDirty = false;
    setState(() {});
  }

  void _recalculateFrom(int editedIndex, String newValue) {
    double editedAmount = double.tryParse(newValue) ?? 0.0;
    _installments[editedIndex] = InstallmentModel(
      installmentNumber: _installments[editedIndex].installmentNumber, amount: editedAmount, dueDate: _installments[editedIndex].dueDate, status: _installments[editedIndex].status
    );

    double amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    double interestRate = double.tryParse(_interestCtrl.text) ?? 0.0;
    double finalDebt = amount + (amount * interestRate / 100);

    if (editedIndex < _installments.length - 1) {
      double sumPrevious = 0;
      for (int i = 0; i <= editedIndex; i++) { sumPrevious += _installments[i].amount; }
      double remainingDebt = finalDebt - sumPrevious;
      if (remainingDebt < 0) remainingDebt = 0; 
      int cuotasLeft = _installments.length - 1 - editedIndex;
      double newPerCuotaBase = remainingDebt / cuotasLeft;
      double accumulated = sumPrevious;

      for (int i = editedIndex + 1; i < _installments.length; i++) {
        double amt = (i == _installments.length - 1) ? double.parse((finalDebt - accumulated).toStringAsFixed(2)) : double.parse(newPerCuotaBase.toStringAsFixed(2));
        _installments[i] = InstallmentModel(
          installmentNumber: _installments[i].installmentNumber, amount: amt, dueDate: _installments[i].dueDate, status: _installments[i].status
        );
        _cuotaCtrls[i].text = amt.toStringAsFixed(2);
        accumulated += amt;
      }
    }
  }

  Future<void> _editInstallmentDate(int index) async {
    DateTime initDate = DateTime.parse(_installments[index].dueDate);
    DateTime firstDate;
    if (index == 0) {
       final now = DateTime.now();
       firstDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    } else {
       DateTime prevDate = DateTime.parse(_installments[index - 1].dueDate);
       firstDate = DateTime(prevDate.year, prevDate.month, prevDate.day).add(const Duration(days: 1));
    }
    if (initDate.isBefore(firstDate)) initDate = firstDate;

    final picked = await showDatePicker(
      context: context, initialDate: initDate, firstDate: firstDate, lastDate: DateTime.now().add(const Duration(days: 1000)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: widget.isDark
              ? const ColorScheme.dark(primary: Colors.orange, surface: Color(0xFF23232F))
              : ColorScheme.light(primary: Colors.orange[800]!),
        ), child: child!,
      ),
    );
    if (picked != null) {
      if (picked.isBefore(firstDate)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fecha inválida: Debe ser posterior a la cuota anterior."), backgroundColor: Colors.red));
        return;
      }
      setState(() {
        _installments[index] = InstallmentModel(
          installmentNumber: _installments[index].installmentNumber, amount: _installments[index].amount, dueDate: DateFormat('yyyy-MM-dd').format(picked), status: _installments[index].status
        );
        DateTime currentDate = picked;
        for (int i = index + 1; i < _installments.length; i++) {
           currentDate = _addFrequency(currentDate);
           _installments[i] = InstallmentModel(
              installmentNumber: _installments[i].installmentNumber, amount: _installments[i].amount, dueDate: DateFormat('yyyy-MM-dd').format(currentDate), status: _installments[i].status
           );
        }
      });
      if (mounted && index < _installments.length - 1) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Las fechas de las cuotas siguientes se recalcularon automáticamente."), backgroundColor: Colors.green));
      }
    }
  }

  void _showPreConfirmDialog(TrackingProvider provider, double amount, double interestRate, double finalDebt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.account_balance, color: widget.isDark ? Colors.orange[300] : Colors.orange[800], size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text("Confirmar Préstamo", style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18))),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSummaryRow("Monto Base:", "S/ ${amount.toStringAsFixed(2)}"),
                _buildSummaryRow("Interés (${interestRate.toStringAsFixed(1)}%):", "S/ ${(finalDebt - amount).toStringAsFixed(2)}"),
                const Divider(),
                _buildSummaryRow("Total Préstamo:", "S/ ${finalDebt.toStringAsFixed(2)}", isBold: true),
                const SizedBox(height: 8),
                _buildSummaryRow("Motivo:", _noteCtrl.text.trim()),
                _buildSummaryRow("Entrega en:", _loanMethod),
                const SizedBox(height: 16),
                Text("Cronograma de Pagos:", style: TextStyle(fontWeight: FontWeight.bold, color: widget.isDark ? Colors.grey[300] : Colors.grey[800])),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade200)
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _installments.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: widget.isDark ? Colors.white10 : Colors.grey[200]),
                    itemBuilder: (ctx, i) {
                      final c = _installments[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("C${c.installmentNumber} • ${c.dueDate}", style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.grey[400] : Colors.grey[700])),
                            Text("S/ ${c.amount.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87)),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Revisar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isDark ? Colors.orange[800] : Colors.orange[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _executeSubmitLoan(provider, amount, interestRate, finalDebt);
            },
            child: const Text("Confirmar")
          )
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14))),
          Expanded(flex: 3, child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 16 : 14, color: widget.isDark ? Colors.white : Colors.black87))),
        ],
      ),
    );
  }

  void _submitAction(TrackingProvider provider) {
    double amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    if (amount <= 0) {
      CustomSnackBar.show(context, message: "Ingresa un monto válido mayor a 0", isError: true);
      return;
    }

    if (_tabController.index == 0) {
      // Retiro
      if (amount > widget.client.saldoAFavor) {
        CustomSnackBar.show(context, message: "El monto supera el saldo a favor disponible", isError: true);
        return;
      }
      _executeSubmitWithdrawal(provider, amount);
    } else {
      // Préstamo
      if (_noteCtrl.text.trim().isEmpty) {
        CustomSnackBar.show(context, message: "Debes ingresar un motivo o nota para el préstamo", isError: true);
        return;
      }
      if (_installments.isEmpty || _isScheduleDirty) {
        CustomSnackBar.show(context, message: "Debes generar o regenerar el cronograma de cuotas antes de continuar.", isError: true);
        return;
      }
      double interestRate = double.tryParse(_interestCtrl.text) ?? 0.0;
      double finalDebt = _installments.fold(0.0, (sum, cuota) => sum + cuota.amount);
      _showPreConfirmDialog(provider, amount, interestRate, finalDebt);
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

  Future<void> _executeSubmitLoan(TrackingProvider provider, double amount, double interestRate, double finalDebt) async {
    setState(() => _isLoading = true);
    // Use new signature for registerLoan
    bool ok = await provider.registerLoan(
      widget.client.id, 
      amount, 
      _noteCtrl.text.trim(),
      interestRate: interestRate,
      metodoPago: _loanMethod,
      installments: _installments,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) {
      CustomSnackBar.show(context, message: "Préstamo registrado correctamente");
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final provider = Provider.of<TrackingProvider>(context);
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final surfaceColor = widget.isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    double enteredAmount = double.tryParse(_amountCtrl.text) ?? 0.0;
    bool isWithdrawTab = _tabController.index == 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        padding: EdgeInsets.only(bottom: bottomInset),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(color: surfaceColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withAlpha(76), borderRadius: BorderRadius.circular(2)))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, size: 28, color: Colors.blueGrey),
                  const SizedBox(width: 12),
                  const Expanded(child: Text("Operaciones Financieras", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: widget.isDark ? Colors.white.withAlpha(12) : Colors.grey[200], borderRadius: BorderRadius.circular(12)),
              child: TabBar(
                controller: _tabController, indicatorSize: TabBarIndicatorSize.tab, dividerColor: Colors.transparent,
                indicator: BoxDecoration(borderRadius: BorderRadius.circular(12), color: widget.isDark ? Colors.blueGrey[700] : Colors.blueGrey, boxShadow: [if (!widget.isDark) BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 4, offset: const Offset(0,2))]),
                labelColor: Colors.white, unselectedLabelColor: widget.isDark ? Colors.grey[400] : Colors.grey[600], labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                tabs: const [
                  Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.output, size: 18), SizedBox(width: 6), Text("Retirar")])),
                  Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.account_balance, size: 18), SizedBox(width: 6), Text("Préstamo")])),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // TAB 1: Retiro
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: widget.isDark ? Colors.blueGrey.withAlpha(38) : Colors.blueGrey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: widget.isDark ? Colors.blueGrey.withAlpha(76) : Colors.blueGrey.shade200)
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Saldo Disponible:", style: TextStyle(color: widget.isDark ? Colors.blueGrey[200] : Colors.blueGrey[800], fontSize: 15, fontWeight: FontWeight.bold)),
                              Text(currency.format(widget.client.saldoAFavor), style: TextStyle(color: widget.isDark ? Colors.blueGrey[300] : Colors.blueGrey[900], fontSize: 18, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text("Monto a Retirar", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        _buildInputLarge(ctrl: _amountCtrl, isDark: widget.isDark, textColor: textColor, isInt: false),
                        const SizedBox(height: 24),
                        Text("Método de entrega", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12, runSpacing: 12,
                          children: [
                            _buildMethodChip("Efectivo", Icons.payments, true),
                            _buildMethodChip("Yape", Icons.qr_code_2, true),
                            _buildMethodChip("Plin", Icons.qr_code, true),
                            _buildMethodChip("Transferencia", Icons.account_balance, true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // TAB 2: Préstamo
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: widget.isDark ? Colors.orange.withAlpha(38) : Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.isDark ? Colors.orange.withAlpha(76) : Colors.orange.shade200)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text("Registrar Préstamo o Venta al Fiado", style: TextStyle(color: widget.isDark ? Colors.orange[200] : Colors.orange[900], fontSize: 14, fontWeight: FontWeight.bold))),
                              Icon(Icons.info_outline, color: widget.isDark ? Colors.orange[300] : Colors.orange[800])
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text("Monto del Préstamo", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        _buildInputLarge(ctrl: _amountCtrl, isDark: widget.isDark, textColor: textColor, isInt: false),
                        
                        const SizedBox(height: 20),
                        Text("Método de entrega", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12, runSpacing: 12,
                          children: [
                            _buildMethodChip("Efectivo", Icons.payments, false),
                            _buildMethodChip("Yape", Icons.qr_code_2, false),
                            _buildMethodChip("Plin", Icons.qr_code, false),
                            _buildMethodChip("Transferencia", Icons.account_balance, false),
                          ],
                        ),

                        const SizedBox(height: 24),
                        Text("Motivo / Detalle", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _motivosSug.length,
                            separatorBuilder: (c, i) => const SizedBox(width: 8),
                            itemBuilder: (c, i) {
                              return ActionChip(
                                label: Text(_motivosSug[i], style: const TextStyle(fontSize: 12)),
                                backgroundColor: widget.isDark ? Colors.white10 : Colors.grey[100],
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide.none),
                                onPressed: () {
                                  _noteCtrl.text = _motivosSug[i];
                                  FocusScope.of(context).unfocus();
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _noteCtrl, maxLines: 2,
                          decoration: InputDecoration(hintText: "Ej. Préstamo personal, Fiado mercadería...", filled: true, fillColor: widget.isDark ? Colors.white.withAlpha(12) : Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                        ),
                        
                        const SizedBox(height: 24),
                        Text("Condiciones de Pago", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(flex: 2, child: _buildInput(label: "N° Cuotas", ctrl: _numCuotasCtrl, isDark: widget.isDark, textColor: textColor, isInt: true)),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: _buildInput(label: "Interés", suffix: "%", ctrl: _interestCtrl, isDark: widget.isDark, textColor: textColor)),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                initialValue: _frecuencia, dropdownColor: surfaceColor,
                                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(labelText: "Frecuencia", labelStyle: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14), filled: true, fillColor: widget.isDark ? const Color(0xFF14141C) : Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), isDense: true),
                                items: const [
                                  DropdownMenuItem(value: "diario", child: Text("Diario")),
                                  DropdownMenuItem(value: "semanal", child: Text("Semanal")),
                                  DropdownMenuItem(value: "quincenal", child: Text("Quincenal")),
                                  DropdownMenuItem(value: "mensual", child: Text("Mensual")),
                                ],
                                onChanged: (v) => setState(() { _frecuencia = v!; _isScheduleDirty = true; _installments.clear(); _disposeCuotaCtrls(); }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity, height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () { FocusScope.of(context).unfocus(); _generateInstallments(); },
                            icon: Icon(_isScheduleDirty && enteredAmount > 0 ? Icons.warning_amber_rounded : Icons.auto_awesome, size: 20),
                            label: Text(_isScheduleDirty && enteredAmount > 0 ? "Generar Cronograma" : "Regenerar Cronograma", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            style: ElevatedButton.styleFrom(backgroundColor: _isScheduleDirty && enteredAmount > 0 ? (widget.isDark ? Colors.red[800] : Colors.red[700]) : (widget.isDark ? Colors.orange[800] : Colors.orange[800]), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                          ),
                        ),
                        if (_installments.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Cronograma", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                                decoration: BoxDecoration(color: widget.isDark ? Colors.red.withValues(alpha: 0.1) : Colors.red[50], borderRadius: BorderRadius.circular(6)), 
                                child: Text("Total Préstamo: ${currency.format(_installments.fold(0.0, (sum, cuota) => sum + cuota.amount))}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: widget.isDark ? Colors.red[300] : Colors.red[800]))
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 280), 
                            decoration: BoxDecoration(color: widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade200)),
                            child: ListView.separated(
                              shrinkWrap: true, padding: EdgeInsets.zero, itemCount: _installments.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: widget.isDark ? Colors.white10 : Colors.grey[200]),
                              itemBuilder: (ctx, i) {
                                final cuota = _installments[i];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(radius: 16, backgroundColor: widget.isDark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange[100], child: Text("${cuota.installmentNumber}", style: TextStyle(fontSize: 14, color: widget.isDark ? Colors.orange[300] : Colors.orange[900], fontWeight: FontWeight.bold))),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _editInstallmentDate(i),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("Vencimiento", style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.grey[500] : Colors.grey[600])),
                                              Row(
                                                children: [
                                                  Text(cuota.dueDate, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
                                                  const SizedBox(width: 6),
                                                  Icon(Icons.edit_calendar, size: 16, color: widget.isDark ? Colors.blue[300] : Colors.blue[400]),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 100, height: 40,
                                        child: TextField(
                                          controller: _cuotaCtrls[i],
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          textAlign: TextAlign.right,
                                          style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 15),
                                          decoration: InputDecoration(prefixText: "S/ ", isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: widget.isDark ? Colors.grey[700]! : Colors.grey.shade400)), filled: true, fillColor: widget.isDark ? const Color(0xFF14141C) : Colors.white),
                                          onChanged: (v) => _recalculateFrom(i, v),
                                        ),
                                      )
                                    ],
                                  ),
                                );
                              }
                            ),
                          )
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: surfaceColor, border: Border(top: BorderSide(color: widget.isDark ? Colors.white.withAlpha(25) : Colors.grey[200]!)), boxShadow: [if (!widget.isDark) BoxShadow(color: Colors.black.withAlpha(12), offset: const Offset(0, -4), blurRadius: 10)]),
              child: Row(
                children: [
                  if (enteredAmount > 0)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Monto Total", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          Text(currency.format(enteredAmount), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        ],
                      ),
                    ),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: enteredAmount > 0 && !_isLoading ? () => _submitAction(provider) : null,
                      style: ElevatedButton.styleFrom(backgroundColor: isWithdrawTab ? Colors.teal : Colors.orange[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0, disabledBackgroundColor: widget.isDark ? Colors.white.withAlpha(12) : Colors.grey[300]),
                      child: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(isWithdrawTab ? "Confirmar Retiro" : "Registrar Préstamo", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMethodChip(String method, IconData icon, bool isWithdraw) {
    bool isSelected = isWithdraw ? _withdrawMethod == method : _loanMethod == method;
    return ChoiceChip(
      label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: isSelected ? Colors.white : (widget.isDark ? Colors.grey[400] : Colors.grey[700])), const SizedBox(width: 8), Text(method)]),
      selected: isSelected,
      onSelected: (val) { if (val) setState(() => isWithdraw ? _withdrawMethod = method : _loanMethod = method); },
      selectedColor: isWithdraw ? Colors.teal : Colors.orange,
      labelStyle: TextStyle(color: isSelected ? Colors.white : (widget.isDark ? Colors.grey[300] : Colors.grey[800]), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      backgroundColor: widget.isDark ? Colors.white.withAlpha(12) : Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: isSelected ? BorderSide.none : BorderSide(color: widget.isDark ? Colors.transparent : Colors.grey.shade300)),
    );
  }

  Widget _buildInputLarge({required TextEditingController ctrl, required bool isDark, required Color textColor, required bool isInt}) {
    return TextField(
      controller: ctrl,
      keyboardType: isInt ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: isInt ? [FilteringTextInputFormatter.digitsOnly] : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
      decoration: InputDecoration(
        prefixText: "S/ ", prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
        filled: true, fillColor: isDark ? Colors.white.withAlpha(12) : Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildInput({required String label, String? prefix, String? suffix, required TextEditingController ctrl, required bool isDark, required Color textColor, bool isInt = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isInt ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: isInt ? [FilteringTextInputFormatter.digitsOnly] : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label, labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14),
        prefixText: prefix, suffixText: suffix,
        filled: true, fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), isDense: true,
      ),
    );
  }
}
