import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/crm_models.dart';

class PaymentConfigCard extends StatefulWidget {
  final double totalAmount;
  final Function(String method, String status, double paid, List<InstallmentModel> installments) onChanged;

  const PaymentConfigCard({super.key, required this.totalAmount, required this.onChanged});

  @override
  State<PaymentConfigCard> createState() => _PaymentConfigCardState();
}

class _PaymentConfigCardState extends State<PaymentConfigCard> {
  String _paymentMethod = "efectivo";
  String _paymentStatus = "pagado";
  
  final _amountPaidCtrl = TextEditingController();
  final _numCuotasCtrl = TextEditingController(text: "2");
  final _interestCtrl = TextEditingController(text: "0"); 
  
  String _frecuencia = "mensual"; 
  final List<InstallmentModel> _installments = [];
  final List<TextEditingController> _cuotaCtrls = []; 

  @override
  void initState() {
    super.initState();
    _amountPaidCtrl.addListener(_notifyParent);
    _interestCtrl.addListener(() {
      if (_installments.isNotEmpty) _generateInstallments(); 
    });
  }

  @override
  void dispose() {
    _amountPaidCtrl.dispose();
    _numCuotasCtrl.dispose();
    _interestCtrl.dispose();
    _disposeCuotaCtrls();
    super.dispose();
  }

  void _disposeCuotaCtrls() {
    for (var c in _cuotaCtrls) { c.dispose(); }
    _cuotaCtrls.clear();
  }

  void _notifyParent() {
    double paid = _paymentStatus == "pagado" ? widget.totalAmount : (double.tryParse(_amountPaidCtrl.text) ?? 0.0);
    if (widget.totalAmount - paid <= 0) {
      _installments.clear();
    }
    widget.onChanged(_paymentMethod, _paymentStatus, paid, _installments);
  }

  void _generateInstallments() {
    double paid = double.tryParse(_amountPaidCtrl.text) ?? 0.0;
    double baseDebt = widget.totalAmount - paid;
    if (baseDebt <= 0) return;

    double interestRate = double.tryParse(_interestCtrl.text) ?? 0.0;
    double finalDebt = baseDebt + (baseDebt * interestRate / 100); 

    int numCuotas = int.tryParse(_numCuotasCtrl.text) ?? 1;
    if (numCuotas < 1) numCuotas = 1;

    double basePerQuota = finalDebt / numCuotas;
    
    _installments.clear();
    _disposeCuotaCtrls();

    DateTime currentDate = DateTime.now();
    double accumulated = 0;

    for (int i = 1; i <= numCuotas; i++) {
      if (_frecuencia == "diario") {
        currentDate = currentDate.add(const Duration(days: 1));
      } else if (_frecuencia == "semanal") currentDate = currentDate.add(const Duration(days: 7));
      else if (_frecuencia == "quincenal") currentDate = currentDate.add(const Duration(days: 15));
      else if (_frecuencia == "mensual") currentDate = DateTime(currentDate.year, currentDate.month + 1, currentDate.day);

      double amount = (i == numCuotas) ? (finalDebt - accumulated) : double.parse(basePerQuota.toStringAsFixed(2));
      accumulated += amount;

      _installments.add(InstallmentModel(
        installmentNumber: i, amount: amount, dueDate: DateFormat('yyyy-MM-dd').format(currentDate), status: "pendiente"
      ));

      final ctrl = TextEditingController(text: amount.toStringAsFixed(2));
      _cuotaCtrls.add(ctrl);
    }
    
    setState(() {});
    _notifyParent();
  }

  void _recalculateFrom(int editedIndex, String newValue) {
    double editedAmount = double.tryParse(newValue) ?? 0.0;
    _installments[editedIndex] = InstallmentModel(
      installmentNumber: _installments[editedIndex].installmentNumber, amount: editedAmount, dueDate: _installments[editedIndex].dueDate, status: _installments[editedIndex].status
    );

    double paid = double.tryParse(_amountPaidCtrl.text) ?? 0.0;
    double baseDebt = widget.totalAmount - paid;
    double interestRate = double.tryParse(_interestCtrl.text) ?? 0.0;
    double finalDebt = baseDebt + (baseDebt * interestRate / 100);

    if (editedIndex < _installments.length - 1) {
      double sumPrevious = 0;
      for (int i = 0; i <= editedIndex; i++) { sumPrevious += _installments[i].amount; }

      double remainingDebt = finalDebt - sumPrevious;
      if (remainingDebt < 0) remainingDebt = 0; 

      int cuotasLeft = _installments.length - 1 - editedIndex;
      double newPerCuotaBase = remainingDebt / cuotasLeft;
      double accumulated = sumPrevious;

      for (int i = editedIndex + 1; i < _installments.length; i++) {
        double amount = (i == _installments.length - 1) ? (finalDebt - accumulated) : double.parse(newPerCuotaBase.toStringAsFixed(2));
        _installments[i] = InstallmentModel(
          installmentNumber: _installments[i].installmentNumber, amount: amount, dueDate: _installments[i].dueDate, status: _installments[i].status
        );
        _cuotaCtrls[i].text = amount.toStringAsFixed(2);
        accumulated += amount;
      }
    }
    _notifyParent();
  }

  Future<void> _editInstallmentDate(int index) async {
    DateTime initDate = DateTime.parse(_installments[index].dueDate);
    final picked = await showDatePicker(
      context: context, initialDate: initDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 1000)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).brightness == Brightness.dark
                ? const ColorScheme.dark(primary: Colors.orange, surface: Color(0xFF23232F))
                : ColorScheme.light(primary: Colors.orange[800]!),
          ), child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _installments[index] = InstallmentModel(
          installmentNumber: _installments[index].installmentNumber, amount: _installments[index].amount, dueDate: DateFormat('yyyy-MM-dd').format(picked), status: _installments[index].status
        );
      });
      _notifyParent();
    }
  }

  Widget _buildSelectionCard({
    required String title, required String subtitle, required IconData icon, 
    required bool isSelected, required Color activeColor, required VoidCallback onTap, required bool isDark
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.1) : (isDark ? const Color(0xFF1E1E2A) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? activeColor : (isDark ? Colors.white10 : Colors.grey.shade300), width: isSelected ? 2 : 1),
            boxShadow: [if (!isDark && !isSelected) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: isSelected ? activeColor : (isDark ? Colors.grey[500] : Colors.grey[400]), size: 28),
                  if (isSelected) Icon(Icons.check_circle, color: activeColor, size: 20)
                ],
              ),
              const SizedBox(height: 12),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]), maxLines: 2),
            ],
          ),
        ),
      ),
    );
  }

  // 🔥 NUEVO: Formato estricto para que los métodos de pago nunca salten de línea
  Widget _buildMethodChip(String label, bool isDark, Color textColor) {
    final isSelected = _paymentMethod.toLowerCase() == label.toLowerCase();
    return ChoiceChip(
      label: Center(child: Text(label, style: const TextStyle(fontSize: 14))),
      padding: const EdgeInsets.symmetric(vertical: 10),
      selected: isSelected,
      onSelected: (val) { setState(() => _paymentMethod = label.toLowerCase()); _notifyParent(); },
      selectedColor: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue[50],
      backgroundColor: isDark ? const Color(0xFF1E1E2A) : Colors.white,
      labelStyle: TextStyle(color: isSelected ? (isDark ? Colors.blue[300] : Colors.blue[800]) : textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? (isDark ? Colors.blue.withOpacity(0.5) : Colors.blue.shade200) : (isDark ? Colors.white10 : Colors.grey.shade300))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    double paid = double.tryParse(_amountPaidCtrl.text) ?? 0.0;
    double baseDebt = widget.totalAmount - paid;
    double interestRate = double.tryParse(_interestCtrl.text) ?? 0.0;
    double interestAmount = baseDebt * interestRate / 100;
    double finalDebt = baseDebt + interestAmount;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: isDark ? Colors.green.withOpacity(0.15) : Colors.green[50], shape: BoxShape.circle),
              child: Icon(Icons.payments_rounded, color: isDark ? Colors.green[300] : Colors.green[800], size: 22)
            ),
            const SizedBox(width: 12),
            Text("2. Configuración de Pago", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.green[100] : Colors.green[900], letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 16),
        
        Row(
          children: [
            _buildSelectionCard(
              title: "Pago Completo", subtitle: "El cliente cancela el 100% hoy.", icon: Icons.task_alt, 
              isSelected: _paymentStatus == "pagado", activeColor: isDark ? Colors.green[400]! : Colors.green, isDark: isDark,
              onTap: () { setState(() { _paymentStatus = "pagado"; _installments.clear(); }); _notifyParent(); }
            ),
            const SizedBox(width: 12),
            _buildSelectionCard(
              title: "Dar a Crédito", subtitle: "Generar cronograma de cuotas.", icon: Icons.calendar_month, 
              isSelected: _paymentStatus == "pendiente", activeColor: isDark ? Colors.orange[400]! : Colors.orange, isDark: isDark,
              onTap: () { setState(() => _paymentStatus = "pendiente"); _notifyParent(); }
            ),
          ],
        ),
        const SizedBox(height: 24),

        Text("Método de Ingreso:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700])),
        const SizedBox(height: 10),
        
        // 🔥 SOLUCIÓN ESTÉTICA: Filas bloqueadas (3 arriba, 2 abajo)
        Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildMethodChip("Efectivo", isDark, textColor)),
                const SizedBox(width: 8),
                Expanded(child: _buildMethodChip("Yape", isDark, textColor)),
                const SizedBox(width: 8),
                Expanded(child: _buildMethodChip("Plin", isDark, textColor)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildMethodChip("Tarjeta", isDark, textColor)),
                const SizedBox(width: 8),
                Expanded(child: _buildMethodChip("Transferencia", isDark, textColor)),
                const SizedBox(width: 8),
                Expanded(child: const SizedBox()), // Elemento vacío para cuadrar la grilla
              ],
            ),
          ],
        ),

        if (_paymentStatus == "pendiente") ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF23232F) : Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200), boxShadow: [if(!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0,4))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune, color: isDark ? Colors.orange[300] : Colors.orange[800], size: 20),
                    const SizedBox(width: 8),
                    Text("Parámetros del Crédito", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.orange[200] : Colors.orange[900])),
                  ],
                ),
                const SizedBox(height: 20), 
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildInput(label: "Adelanto (Hoy)", prefix: "S/ ", ctrl: _amountPaidCtrl, isDark: isDark, textColor: textColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildInput(label: "Interés", suffix: "%", ctrl: _interestCtrl, isDark: isDark, textColor: textColor),
                    ),
                  ],
                ),
                if (interestAmount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text("Surcharge de Interés: ${currency.format(interestAmount)}", style: TextStyle(color: isDark ? Colors.red[300] : Colors.red[700], fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildInput(label: "N° Cuotas", ctrl: _numCuotasCtrl, isDark: isDark, textColor: textColor, isInt: true),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        initialValue: _frecuencia,
                        dropdownColor: cardColor,
                        style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(labelText: "Frecuencia", labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14), filled: true, fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), isDense: true),
                        items: const [
                          DropdownMenuItem(value: "diario", child: Text("Diario")),
                          DropdownMenuItem(value: "semanal", child: Text("Semanal")),
                          DropdownMenuItem(value: "quincenal", child: Text("Quincenal")),
                          DropdownMenuItem(value: "mensual", child: Text("Mensual")),
                        ],
                        onChanged: (v) => setState(() => _frecuencia = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20), 
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () { FocusScope.of(context).unfocus(); _generateInstallments(); },
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    label: const Text("Generar Cronograma", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.orange[800] : Colors.orange[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  ),
                ),

                if (_installments.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Divider(color: isDark ? Colors.white10 : Colors.grey[200], height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Cronograma", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isDark ? Colors.red.withOpacity(0.1) : Colors.red[50], borderRadius: BorderRadius.circular(6)), child: Text("Total Financiado: ${currency.format(finalDebt)}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isDark ? Colors.red[300] : Colors.red[800]))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 280), 
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF1A1A24) : Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                    child: ListView.separated(
                      shrinkWrap: true, padding: EdgeInsets.zero, itemCount: _installments.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                      itemBuilder: (ctx, i) {
                        final cuota = _installments[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              CircleAvatar(radius: 16, backgroundColor: isDark ? Colors.orange.withOpacity(0.2) : Colors.orange[100], child: Text("${cuota.installmentNumber}", style: TextStyle(fontSize: 14, color: isDark ? Colors.orange[300] : Colors.orange[900], fontWeight: FontWeight.bold))),
                              const SizedBox(width: 16),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _editInstallmentDate(i),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Vencimiento", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[600])),
                                      Row(
                                        children: [
                                          Text(cuota.dueDate, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
                                          const SizedBox(width: 6),
                                          Icon(Icons.edit_calendar, size: 16, color: isDark ? Colors.blue[300] : Colors.blue[400]),
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
                                  decoration: InputDecoration(prefixText: "S/ ", isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey.shade400)), filled: true, fillColor: isDark ? const Color(0xFF14141C) : Colors.white),
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
          )
        ]
      ],
    );
  }

  Widget _buildInput({required String label, String? prefix, String? suffix, required TextEditingController ctrl, required bool isDark, required Color textColor, bool isInt = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isInt ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: isInt ? [FilteringTextInputFormatter.digitsOnly] : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14),
        prefixText: prefix,
        suffixText: suffix,
        filled: true, fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        isDense: true,
      ),
    );
  }
}