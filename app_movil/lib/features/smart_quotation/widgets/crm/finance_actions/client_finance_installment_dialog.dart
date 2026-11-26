part of '../client_finance_actions_modal.dart';

mixin _ClientFinanceInstallmentDialogMixin on _ClientFinanceActionsStateBase {
  @override
  void _showInstallmentStatusDialog(int index) {
    final current = _installments[index];
    final amount = current.amount;

    final d = DateTime.tryParse(current.dueDate) ?? DateTime.now();
    final today = DateTime.now();
    final todayClean = DateTime(today.year, today.month, today.day);
    final dClean = DateTime(d.year, d.month, d.day);
    final bool isOverdue = dClean.isBefore(todayClean);

    int selectedOption = 0;
    if (current.montoPagado >= amount && amount > 0) {
      selectedOption = 1;
    } else if (current.montoPagado > 0) {
      selectedOption = 2;
    } else {
      selectedOption = 0;
    }

    final TextEditingController paidCtrl = TextEditingController(
      text: current.montoPagado > 0
          ? current.montoPagado.toStringAsFixed(2)
          : '',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final double currentPaid = double.tryParse(paidCtrl.text.replaceAll(',', '.')) ?? 0.0;
            final double remainingToCollect = (amount - currentPaid) > 0 ? (amount - currentPaid) : 0.0;

            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: AlertDialog(
                backgroundColor:
                    widget.isDark ? const Color(0xFF23232F) : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                title: Text(
                  "Estado Cuota #${current.installmentNumber} (${AppCurrency.format(amount)})",
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Si este préstamo es histórico o ya se amortizó parte de esta cuota, define su estado actual:",
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.isDark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tarjeta 1: Pendiente / Vencida
                      InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedOption = 0;
                            paidCtrl.clear();
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: selectedOption == 0
                                ? (isOverdue ? Colors.red.withValues(alpha: 0.12) : Colors.amber.withValues(alpha: 0.12))
                                : (widget.isDark ? Colors.white10 : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedOption == 0
                                  ? (isOverdue ? Colors.redAccent : Colors.amber[700]!)
                                  : (widget.isDark ? Colors.white12 : Colors.grey.shade300),
                              width: selectedOption == 0 ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isOverdue ? Icons.warning_amber_rounded : Icons.schedule_rounded,
                                color: isOverdue ? Colors.redAccent : Colors.amber[700],
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isOverdue ? "Vencida / Sin Pagar" : "Pendiente / Sin Pagar",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        color: widget.isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Monto abonado: S/ 0.00",
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selectedOption == 0)
                                Icon(Icons.check_circle_rounded,
                                    color: isOverdue ? Colors.redAccent : Colors.amber[700], size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tarjeta 2: Ya Pagada Totalmente
                      InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedOption = 1;
                            paidCtrl.text = amount.toStringAsFixed(2);
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: selectedOption == 1
                                ? Colors.green.withValues(alpha: 0.12)
                                : (widget.isDark ? Colors.white10 : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedOption == 1
                                  ? Colors.green
                                  : (widget.isDark ? Colors.white12 : Colors.grey.shade300),
                              width: selectedOption == 1 ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Ya Pagada Totalmente",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        color: widget.isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Monto abonado: ${AppCurrency.format(amount)}",
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selectedOption == 1)
                                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tarjeta 3: Pago Parcial / Abono
                      InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedOption = 2;
                            if (paidCtrl.text.isEmpty || currentPaid >= amount) {
                              paidCtrl.text = (amount * 0.5).toStringAsFixed(2);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: selectedOption == 2
                                ? Colors.blue.withValues(alpha: 0.12)
                                : (widget.isDark ? Colors.white10 : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedOption == 2
                                  ? Colors.blue
                                  : (widget.isDark ? Colors.white12 : Colors.grey.shade300),
                              width: selectedOption == 2 ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.payments_rounded, color: Colors.blue, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Pago Parcial / Abono",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        color: widget.isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Ingresa el monto amortizado hasta la fecha",
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selectedOption == 2)
                                const Icon(Icons.check_circle_rounded, color: Colors.blue, size: 18),
                            ],
                          ),
                        ),
                      ),

                      // Sección Condicional Animada para Pago Parcial (Solo visible si selectedOption == 2)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: selectedOption == 2
                            ? Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: paidCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d*\.?\d{0,2}'))
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
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: BorderSide.none),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 12),
                                        isDense: true,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Chips rápidos de porcentaje 25%, 50%, 75%
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ActionChip(
                                            label: const Center(
                                              child: Text("25%",
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 0),
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () {
                                              double v = double.parse(
                                                  (amount * 0.25)
                                                      .toStringAsFixed(2));
                                              paidCtrl.text =
                                                  v.toStringAsFixed(2);
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
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 0),
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () {
                                              double v = double.parse(
                                                  (amount * 0.50)
                                                      .toStringAsFixed(2));
                                              paidCtrl.text =
                                                  v.toStringAsFixed(2);
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
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 0),
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () {
                                              double v = double.parse(
                                                  (amount * 0.75)
                                                      .toStringAsFixed(2));
                                              paidCtrl.text =
                                                  v.toStringAsFixed(2);
                                              setDialogState(() {});
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Resumen en vivo
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
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
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "Abonado: ${AppCurrency.format(currentPaid)}",
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                ),
                                              ),
                                              Text(
                                                "Resta: ${AppCurrency.format(remainingToCollect)}",
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: remainingToCollect > 0
                                                      ? Colors.orange[800]
                                                      : Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (currentPaid >= amount && amount > 0) ...[
                                            const SizedBox(height: 4),
                                            const Text(
                                              "El abono cubre el total de la cuota (se registrará como Pagada).",
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancelar",
                        style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      double finalPaid = 0.0;
                      String finalStatus = 'pendiente';

                      if (selectedOption == 0) {
                        finalPaid = 0.0;
                        finalStatus = isOverdue ? 'vencida' : 'pendiente';
                      } else if (selectedOption == 1) {
                        finalPaid = amount;
                        finalStatus = 'pagado';
                      } else {
                        double p = double.tryParse(paidCtrl.text.replaceAll(',', '.')) ?? 0.0;
                        if (p >= amount && amount > 0) {
                          finalPaid = amount;
                          finalStatus = 'pagado';
                        } else if (p > 0) {
                          finalPaid = p;
                          finalStatus = 'parcial';
                        } else {
                          finalPaid = 0.0;
                          finalStatus = isOverdue ? 'vencida' : 'pendiente';
                        }
                      }

                      setState(() {
                        _installments[index] = current.copyWith(
                          montoPagado: finalPaid,
                          status: finalStatus,
                        );
                      });
                      _saveCurrentDraft();
                      Navigator.pop(ctx);
                    },
                    child: const Text("Aplicar",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

}
