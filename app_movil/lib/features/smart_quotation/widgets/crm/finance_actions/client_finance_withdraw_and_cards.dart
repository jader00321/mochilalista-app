part of '../client_finance_actions_modal.dart';

mixin _ClientFinanceWithdrawAndCardsMixin on _ClientFinanceActionsStateBase {
  Widget _buildCollapsibleCard({
    required Key toggleKey,
    required bool isExpanded,
    required VoidCallback onToggle,
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color titleColor,
    required String subtitle,
    required Color subtitleColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: toggleKey,
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 18, color: iconColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isExpanded ? "Ocultar" : "Detalles",
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: titleColor.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            isExpanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 16,
                            color: titleColor.withValues(alpha: 0.8),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 26),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.25,
                          color: subtitleColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget _buildDynamicContextualCard(
    bool isDark,
    double enteredAmount,
    TrackingProvider provider,
  ) {
    final bool isLoan = _tabController.index == 0;

    if (isLoan) {
      // 1. Detección de cuotas vencidas en tiempo real
      int overdueCount = 0;
      final today = DateTime.now();
      final todayClean = DateTime(today.year, today.month, today.day);
      for (final sale in provider.currentClientDebts) {
        if (sale.isArchived) continue;
        for (final c in sale.installments) {
          if (c.status != 'pagado' && c.status != 'anulada') {
            final due = DateTime.tryParse(c.dueDate);
            if (due != null) {
              final dueClean = DateTime(due.year, due.month, due.day);
              if (dueClean.isBefore(todayClean)) {
                overdueCount++;
              }
            }
          }
        }
      }

      final double suggestedLimit = widget.client.tier.limiteCreditoSugerido;

      final String title;
      final String subtitle;
      final IconData icon;
      final Color iconColor;
      final Color titleColor;
      final Color subtitleColor;
      final Color bgColor;
      final Color borderColor;

      if (overdueCount > 0) {
        title = "Límite Congelado: S/ 0.00 (Mora Activa)";
        subtitle = enteredAmount > 0
            ? "Atención: ${widget.client.fullName} tiene $overdueCount ${overdueCount == 1 ? 'cuota vencida' : 'cuotas vencidas'}. Estás por otorgar un préstamo adicional a un cliente con mora activa."
            : "El cliente tiene $overdueCount ${overdueCount == 1 ? 'cuota vencida' : 'cuotas vencidas'}. Su límite de crédito sugerido está suspendido en S/ 0.00 hasta regularizar su deuda.";
        icon = Icons.warning_amber_rounded;
        iconColor = Colors.redAccent;
        titleColor = isDark ? const Color(0xFFFF8A80) : const Color(0xFF991B1B);
        subtitleColor = isDark ? Colors.grey[300]! : const Color(0xFF7F1D1D);
        bgColor = isDark ? const Color(0xFF3B1E22) : const Color(0xFFFEF2F2);
        borderColor = isDark ? Colors.red.withValues(alpha: 0.5) : const Color(0xFFFECACA);
      } else if (enteredAmount <= 0) {
        title = "Límite de Crédito Sugerido: ${AppCurrency.format(suggestedLimit)}";
        subtitle = widget.client.rachaPagosPuntuales > 0
            ? "Cliente puntual con racha de ${widget.client.rachaPagosPuntuales} pagos a tiempo. Recomendado para operaciones de confianza."
            : "Cliente sin historial de atrasos. Se sugiere iniciar con operaciones prudentes dentro de su tope base.";
        icon = Icons.shield_outlined;
        iconColor = Color(widget.client.tier.colorHex);
        titleColor = isDark ? Colors.grey[200]! : const Color(0xFF1E293B);
        subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF64748B);
        bgColor = isDark ? const Color(0xFF282837) : const Color(0xFFF8FAFC);
        borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);
      } else if (enteredAmount <= suggestedLimit) {
        final restan = suggestedLimit - enteredAmount;
        title = "Monto Dentro del Rango Seguro";
        subtitle = "Monto dentro del rango seguro recomendado para ${widget.client.fullName}. Restan ${AppCurrency.format(restan)} de su tope sugerido.";
        icon = Icons.check_circle_outline_rounded;
        iconColor = isDark ? Colors.greenAccent : const Color(0xFF16A34A);
        titleColor = isDark ? Colors.greenAccent : const Color(0xFF166534);
        subtitleColor = isDark ? Colors.grey[300]! : const Color(0xFF15803D);
        bgColor = isDark ? const Color(0xFF132D21) : const Color(0xFFF0FDF4);
        borderColor = isDark ? Colors.green.withValues(alpha: 0.5) : const Color(0xFFBBF7D0);
      } else {
        final exceso = enteredAmount - suggestedLimit;
        title = "Atención: Excede Límite Recomendado";
        subtitle = "El monto ingresado excede por ${AppCurrency.format(exceso)} el límite sugerido de ${AppCurrency.format(suggestedLimit)}. Evalúa la capacidad de pago del cliente.";
        icon = Icons.warning_amber_rounded;
        iconColor = isDark ? Colors.amberAccent : const Color(0xFFD97706);
        titleColor = isDark ? Colors.amberAccent : const Color(0xFFB45309);
        subtitleColor = isDark ? Colors.grey[300]! : const Color(0xFF92400E);
        bgColor = isDark ? const Color(0xFF382914) : const Color(0xFFFFFBEB);
        borderColor = isDark ? Colors.amber.withValues(alpha: 0.5) : const Color(0xFFFDE68A);
      }

      return _buildCollapsibleCard(
        toggleKey: const ValueKey('loan_credit_limit_card_toggle'),
        isExpanded: _isLoanInfoExpanded,
        onToggle: () {
          setState(() {
            _isLoanInfoExpanded = !_isLoanInfoExpanded;
          });
        },
        icon: icon,
        iconColor: iconColor,
        title: title,
        titleColor: titleColor,
        subtitle: subtitle,
        subtitleColor: subtitleColor,
        bgColor: bgColor,
        borderColor: borderColor,
      );
    }

    // Pestaña Retirar Saldo (Tab 1)
    if (widget.client.saldoAFavor <= 0.01) {
      // Erradicar por completo la duplicación: el estado educativo único se renderiza en _buildWithdrawTab
      return const SizedBox.shrink();
    }

    final String title;
    final String subtitle;
    final IconData icon;
    final Color iconColor;
    final Color titleColor;
    final Color subtitleColor;
    final Color bgColor;
    final Color borderColor;

    if (enteredAmount <= 0) {
      title = "Saldo a Favor Disponible: ${AppCurrency.format(widget.client.saldoAFavor)}";
      subtitle = "Puedes registrar el desembolso total o parcial del saldo a favor de ${widget.client.fullName}.";
      icon = Icons.account_balance_wallet_rounded;
      iconColor = Colors.teal;
      titleColor = isDark ? Colors.tealAccent : const Color(0xFF0F766E);
      subtitleColor = isDark ? Colors.grey[300]! : const Color(0xFF115E59);
      bgColor = isDark ? const Color(0xFF132D2D) : const Color(0xFFF0FDFA);
      borderColor = isDark ? Colors.teal.withValues(alpha: 0.5) : const Color(0xFF99F6E4);
    } else if (enteredAmount <= widget.client.saldoAFavor) {
      final rem = widget.client.saldoAFavor - enteredAmount;
      title = "Retiro Válido: ${AppCurrency.format(enteredAmount)}";
      subtitle = "Tras este retiro, el nuevo saldo a favor de ${widget.client.fullName} será de ${AppCurrency.format(rem)}.";
      icon = Icons.check_circle_outline_rounded;
      iconColor = isDark ? Colors.greenAccent : const Color(0xFF16A34A);
      titleColor = isDark ? Colors.greenAccent : const Color(0xFF166534);
      subtitleColor = isDark ? Colors.grey[300]! : const Color(0xFF15803D);
      bgColor = isDark ? const Color(0xFF132D21) : const Color(0xFFF0FDF4);
      borderColor = isDark ? Colors.green.withValues(alpha: 0.5) : const Color(0xFFBBF7D0);
    } else {
      final exceso = enteredAmount - widget.client.saldoAFavor;
      title = "Monto Excede el Saldo Disponible";
      subtitle = "No es posible retirar ${AppCurrency.format(enteredAmount)}. El monto supera el saldo disponible por ${AppCurrency.format(exceso)}.";
      icon = Icons.error_outline_rounded;
      iconColor = Colors.redAccent;
      titleColor = isDark ? const Color(0xFFFF8A80) : const Color(0xFF991B1B);
      subtitleColor = isDark ? Colors.grey[300]! : const Color(0xFF7F1D1D);
      bgColor = isDark ? const Color(0xFF3B1E22) : const Color(0xFFFEF2F2);
      borderColor = isDark ? Colors.red.withValues(alpha: 0.5) : const Color(0xFFFECACA);
    }

    return _buildCollapsibleCard(
      toggleKey: const ValueKey('withdraw_balance_card_toggle'),
      isExpanded: _isWithdrawInfoExpanded,
      onToggle: () {
        setState(() {
          _isWithdrawInfoExpanded = !_isWithdrawInfoExpanded;
        });
      },
      icon: icon,
      iconColor: iconColor,
      title: title,
      titleColor: titleColor,
      subtitle: subtitle,
      subtitleColor: subtitleColor,
      bgColor: bgColor,
      borderColor: borderColor,
    );
  }


  // =========================================================================
  // TAB 1: RETIRO DE SALDO A FAVOR
  // =========================================================================

  @override
  Widget _buildWithdrawTab(
      Color textColor, bool hasAvailableBalance, double enteredAmount) {
    if (!hasAvailableBalance) {
      return Center(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                child: const Icon(Icons.savings_outlined,
                    color: Colors.teal, size: 40),
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
                  color: widget.isDark
                      ? const Color(0xFF1A1A24)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.isDark
                        ? Colors.white10
                        : Colors.grey.shade300,
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

    return ListView(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
      children: [
        // Quick action chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: Text(
                  "Retirar Todo (${AppCurrency.format(widget.client.saldoAFavor)})"),
              backgroundColor: widget.isDark
                  ? Colors.teal.withValues(alpha: 0.15)
                  : Colors.teal[50],
              side: BorderSide(color: Colors.teal.withValues(alpha: 0.4)),
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal),
              onPressed: () {
                _amountCtrl.text =
                    widget.client.saldoAFavor.toStringAsFixed(2);
              },
            ),
            ActionChip(
              label: const Text("Retirar 50%"),
              backgroundColor:
                  widget.isDark ? Colors.white10 : Colors.grey[100],
              side: BorderSide(
                  color: widget.isDark ? Colors.white10 : Colors.grey.shade300),
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

        Text("Monto a Retirar",
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600])),
        const SizedBox(height: 8),
        _buildInputLarge(
            ctrl: _amountCtrl,
            isDark: widget.isDark,
            textColor: textColor,
            isInt: false),

        if (enteredAmount > widget.client.saldoAFavor) ...[
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: Colors.redAccent),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  "El monto supera el saldo disponible para retiro",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 22),

        Text("Método de entrega",
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600])),
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

}
