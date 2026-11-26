part of '../client_finance_actions_modal.dart';

mixin _ClientFinanceConfirmationDialogsMixin on _ClientFinanceActionsStateBase {
  @override
  void _showOneQuotaPartialDialog(double enteredAmount) {
    final ctrl = TextEditingController(
      text: _oneQuotaPaidAmount > 0
          ? _oneQuotaPaidAmount.toStringAsFixed(2)
          : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final double p = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
          final double remaining = (enteredAmount - p) > 0 ? (enteredAmount - p) : 0.0;

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: AlertDialog(
              backgroundColor:
                  widget.isDark ? const Color(0xFF23232F) : Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text("Abono / Pago Parcial Histórico",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Indica el monto que ya fue amortizado de este préstamo de ${AppCurrency.format(enteredAmount)}:",
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
                    ],
                    onChanged: (_) => setDialogState(() {}),
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: InputDecoration(
                      labelText: "Monto Abonado",
                      prefixText: "S/ ",
                      hintText: "0.00",
                      filled: true,
                      fillColor: widget.isDark
                          ? const Color(0xFF14141C)
                          : Colors.grey[100],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ActionChip(
                          label: const Center(
                            child: Text("25%",
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 0),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            double v = double.parse(
                                (enteredAmount * 0.25).toStringAsFixed(2));
                            ctrl.text = v.toStringAsFixed(2);
                            setDialogState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ActionChip(
                          label: const Center(
                            child: Text("50%",
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 0),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            double v = double.parse(
                                (enteredAmount * 0.50).toStringAsFixed(2));
                            ctrl.text = v.toStringAsFixed(2);
                            setDialogState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ActionChip(
                          label: const Center(
                            child: Text("75%",
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 0),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            double v = double.parse(
                                (enteredAmount * 0.75).toStringAsFixed(2));
                            ctrl.text = v.toStringAsFixed(2);
                            setDialogState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? Colors.black26
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.isDark
                            ? Colors.white12
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Abonado: ${AppCurrency.format(p)}",
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          "Resta: ${AppCurrency.format(remaining)}",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: remaining > 0
                                ? Colors.orange[800]
                                : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child:
                      const Text("Cancelar", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    double finalPaid = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
                    if (finalPaid > enteredAmount) finalPaid = enteredAmount;
                    setState(() {
                      _oneQuotaPaidAmount = finalPaid;
                      if (finalPaid >= enteredAmount && enteredAmount > 0) {
                        _oneQuotaStatus = 'pagado';
                      } else if (finalPaid > 0) {
                        _oneQuotaStatus = 'parcial';
                      } else {
                        _oneQuotaStatus =
                            _dueDate.isBefore(DateTime.now()) ? 'vencida' : 'pendiente';
                      }
                    });
                    _saveCurrentDraft();
                    Navigator.pop(ctx);
                  },
                  child: const Text("Guardar"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  @override
  void _showPreConfirmDialog(
    TrackingProvider provider,
    double amount,
    double interestRate,
    double finalDebt,
    String motivo,
    List<InstallmentModel> installments,
  ) {
    final double totalAmortizado =
        installments.fold(0.0, (sum, c) => sum + c.montoPagado);
    final double saldoDeudorInicial =
        (finalDebt - totalAmortizado).clamp(0.0, double.infinity);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            widget.isDark ? const Color(0xFF23232F) : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.account_balance,
                color: widget.isDark
                    ? Colors.orange[300]
                    : Colors.orange[800],
                size: 28),
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
                _buildSummaryRow("Fecha Emisión:",
                    _formatDateSpanish(_loanEmissionDate)),
                _buildSummaryRow("Monto Base:", AppCurrency.format(amount)),
                if (interestRate > 0)
                  _buildSummaryRow(
                    "Interés (${interestRate.toStringAsFixed(1)}%):",
                    AppCurrency.format(finalDebt - amount),
                  ),
                const Divider(),
                _buildSummaryRow("Total Préstamo:",
                    AppCurrency.format(finalDebt),
                    isBold: true),
                if (totalAmortizado > 0) ...[
                  _buildSummaryRow("Amortizado Histórico:",
                      AppCurrency.format(totalAmortizado)),
                  _buildSummaryRow("Saldo Deudor Inicial:",
                      AppCurrency.format(saldoDeudorInicial),
                      isBold: true),
                ],
                const SizedBox(height: 8),
                _buildSummaryRow("Motivo:", motivo),
                _buildSummaryRow("Entrega en:", _loanMethod),
                const SizedBox(height: 16),
                Text(
                  "Cronograma de Cuotas (${installments.length}):",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.isDark
                        ? Colors.grey[300]
                        : Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? const Color(0xFF1A1A24)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: widget.isDark
                            ? Colors.white10
                            : Colors.grey.shade200),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: installments.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: widget.isDark
                            ? Colors.white10
                            : Colors.grey[200]),
                    itemBuilder: (ctx, i) {
                      final c = installments[i];
                      final d = DateTime.tryParse(c.dueDate) ?? DateTime.now();
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                "Cuota ${c.installmentNumber} • ${_formatDateSpanish(d)}",
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: widget.isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[800],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppCurrency.format(c.amount),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: widget.isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                _buildConfirmQuotaBadge(c, d),
                              ],
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
              backgroundColor: widget.isDark
                  ? Colors.orange[800]
                  : Colors.orange[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _executeSubmitLoan(provider, amount, interestRate, finalDebt,
                  motivo, installments);
            },
            child: const Text("Confirmar y Guardar",
                style: TextStyle(fontWeight: FontWeight.bold)),
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
          Text(label,
              style: TextStyle(
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14)),
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

  Widget _buildConfirmQuotaBadge(InstallmentModel c, DateTime d) {
    if (c.montoPagado >= c.amount && c.amount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 10, color: Colors.green),
            SizedBox(width: 3),
            Text(
              "Pagada",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    } else if (c.montoPagado > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pie_chart_outline, size: 10, color: Colors.blue),
            const SizedBox(width: 3),
            Text(
              "Abono: ${AppCurrency.format(c.montoPagado)}",
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      );
    } else if (d.isBefore(DateTime.now())) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 10, color: Colors.redAccent),
            SizedBox(width: 3),
            Text(
              "Vencida",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          "Pendiente",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
      );
    }
  }

}
