part of 'payment_entry_modal.dart';

mixin _PaymentEntrySpecificAndSubmitMixin on _PaymentEntryStateBase {
  @override
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

        // Previsualización dinámica de cascada inteligente en Pago Específico con excedente
        Builder(
          builder: (ctx) {
            if (_selectedTargetType != 'cuota' || _selectedTargetId == null) return const SizedBox.shrink();
            final double entered = double.tryParse(_amountCtrl.text) ?? 0.0;
            InstallmentModel? targetCuota;
            SaleModel? targetSale;
            for (var s in debts) {
              for (var c in s.installments) {
                if (c.id == _selectedTargetId) {
                  targetCuota = c;
                  targetSale = s;
                  break;
                }
              }
              if (targetCuota != null) break;
            }
            if (targetCuota == null || targetSale == null) return const SizedBox.shrink();
            final double faltaTarget = targetCuota.amount - targetCuota.montoPagado;
            if (entered <= faltaTarget + 0.01) return const SizedBox.shrink();

            final double surplus = entered - faltaTarget;
            final subsequentCuotas = targetSale.installments
                .where((c) => c.status != 'pagado' && c.id != targetCuota!.id && c.installmentNumber > targetCuota.installmentNumber)
                .toList();
            subsequentCuotas.sort((a, b) => a.installmentNumber.compareTo(b.installmentNumber));

            String cascadeInfo;
            if (subsequentCuotas.isNotEmpty) {
              final nextC = subsequentCuotas.first;
              final double faltaNext = nextC.amount - nextC.montoPagado;
              final double nextApplied = surplus >= faltaNext ? faltaNext : surplus;
              final bool nextLiquidada = (faltaNext - nextApplied) <= 0.01;
              cascadeInfo = "Cancela Cuota ${targetCuota.installmentNumber} (${AppCurrency.format(faltaTarget)}) y amortiza ${AppCurrency.format(nextApplied)} a Cuota ${nextC.installmentNumber}${nextLiquidada ? ' (Liquidada)' : ''} del mismo préstamo/venta.";
            } else {
              cascadeInfo = "Cancela Cuota ${targetCuota.installmentNumber} (${AppCurrency.format(faltaTarget)}) y el remanente de ${AppCurrency.format(surplus)} queda como saldo a favor o vuelto.";
            }

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B281B) : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: isDark ? Colors.greenAccent : Colors.green.shade800, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cascadeInfo,
                      style: TextStyle(
                        color: isDark ? Colors.green[200] : Colors.green[900],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // Lista de Deudas con Cuotas
        Expanded(
          child: ListView.builder(
            controller: _specificScrollCtrl,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24 + kModalScrollBottomClearance),
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
                                  Builder(
                                    builder: (_) {
                                      final now = DateTime.now();
                                      final todayStart = DateTime(now.year, now.month, now.day);
                                      final due = DateTime.tryParse(cuota.dueDate);
                                      final bool isVencida = due != null && due.isBefore(todayStart);

                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isVencida
                                              ? (isDark ? Colors.red.withValues(alpha: 0.2) : Colors.red[100])
                                              : (isDark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange[100]),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isVencida
                                              ? "Venció: ${DateFormat('dd/MM').format(due)}"
                                              : "Vence: ${due != null ? DateFormat('dd/MM').format(due) : cuota.dueDate}",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isVencida
                                                ? (isDark ? Colors.red[300] : Colors.red[900])
                                                : (isDark ? Colors.orange[300] : Colors.orange[900]),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                cuota.tieneMora
                                    ? "Pendiente: ${AppCurrency.format(faltaCuota)} (incl. +${AppCurrency.format(cuota.moraMonto)} mora)"
                                    : "Pendiente: ${AppCurrency.format(faltaCuota)}",
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

  @override
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
