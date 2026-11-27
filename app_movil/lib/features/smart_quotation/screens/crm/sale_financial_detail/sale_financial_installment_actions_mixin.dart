part of '../sale_financial_detail_screen.dart';

mixin _SaleFinancialInstallmentActionsMixin
    on _SaleFinancialDetailScreenStateBase {
  @override
  Widget _buildInstallmentActionsRow({
    required int index,
    required Map<String, dynamic> c,
    required DateTime dueDate,
    required double cMoraMonto,
    required bool isOverdue,
    required bool isDark,
    required bool isLoan,
  }) {
    final Color moraColor = cMoraMonto > 0.01
        ? Colors.redAccent
        : (isOverdue ? Colors.orange : Colors.blueGrey);
    final Color moraFg = cMoraMonto > 0.01
        ? Colors.redAccent
        : (isOverdue
              ? Colors.orange[800]!
              : (isDark ? Colors.cyanAccent : Colors.teal));

    return Row(
      children: [
        Expanded(
          flex: 1,
          child: KeyedSubtree(
            key: index == 0 ? _tourKeys.installmentDateKey : null,
            child: _buildCuotaActionButton(
              color: Colors.blue.withValues(alpha: 0.12),
              borderColor: Colors.blue.withValues(alpha: 0.3),
              fgColor: isDark ? Colors.blue[300]! : Colors.blue[700]!,
              icon: Icons.calendar_month,
              label: "Fecha",
              onTap: () => _pickAndSaveInstallmentDate(c, dueDate, isDark),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 3,
          child: KeyedSubtree(
            key: index == 0 ? _tourKeys.installmentActionsKey : null,
            child: Row(
              children: [
                Expanded(
                  child: _buildCuotaActionButton(
                    color: moraColor.withValues(alpha: 0.12),
                    borderColor: moraColor.withValues(alpha: 0.3),
                    fgColor: moraFg,
                    icon: cMoraMonto > 0.01
                        ? Icons.timer_outlined
                        : (isOverdue ? Icons.tune : Icons.shield_outlined),
                    label: (cMoraMonto > 0.01 || isOverdue)
                        ? "Mora"
                        : "Prog. Mora",
                    onTap: () => CuotaMorosidadModal.show(
                      context: context,
                      cuota: c,
                      isDark: isDark,
                      onSaved: _loadData,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildCuotaActionButton(
                    color: const Color(0xFF25D366).withValues(alpha: 0.12),
                    borderColor: const Color(0xFF25D366).withValues(alpha: 0.3),
                    fgColor: const Color(0xFF25D366),
                    icon: Icons.chat_bubble_outline,
                    label: "Recordar",
                    onTap: () => WhatsAppPreviewModal.showCuotaReminder(
                      context: context,
                      cuota: c,
                      clientName:
                          _saleData?['cliente_nombre'] ??
                          (_saleData?['cliente_info']?['nombre_completo']),
                      clientPhone:
                          _saleData?['cliente_telefono'] ??
                          (_saleData?['cliente_info']?['telefono']),
                      isDark: isDark,
                      operationTitle: isLoan ? "Préstamo" : "Venta a Crédito",
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildCuotaActionButton(
                    color: Colors.teal.withValues(alpha: 0.15),
                    borderColor: Colors.teal.withValues(alpha: 0.3),
                    fgColor: isDark
                        ? Colors.tealAccent[400]!
                        : Colors.teal.shade800,
                    icon: Icons.payments_outlined,
                    label: "Cobrar",
                    onTap: () => _openCuotaPayment(c),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCuotaActionButton({
    required Color color,
    required Color borderColor,
    required Color fgColor,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: fgColor),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  color: fgColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndSaveInstallmentDate(
    Map<String, dynamic> c,
    DateTime dueDate,
    bool isDark,
  ) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: Colors.blue[300]!,
                    onPrimary: Colors.black,
                    surface: const Color(0xFF23232F),
                    onSurface: Colors.white,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: ColorScheme.light(
                    primary: Colors.blue[800]!,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                  ),
                ),
          child: child!,
        );
      },
    );
    if (newDate != null && !newDate.isAtSameMomentAs(dueDate)) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      final provider = Provider.of<SaleProvider>(context, listen: false);
      final success = await provider.updateInstallmentDate(
        c['id'] as int,
        newDate.toIso8601String(),
        saleId: widget.saleId,
      );
      if (!mounted) return;
      if (success) {
        AppFeedbackHelper.showSnackBar(
          context,
          "Fecha actualizada exitosamente",
          backgroundColor: Colors.green,
        );
        await _loadData();
      } else {
        AppFeedbackHelper.showSnackBar(
          context,
          "Error al actualizar la fecha",
          backgroundColor: Colors.red,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget _buildFinancialRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
    required bool isDark,
  }) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final labelColor = isDark ? Colors.grey[400] : Colors.grey[700];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: labelColor,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 14 : 12.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? textColor,
          ),
        ),
      ],
    );
  }

  Future<void> _openCuotaPayment(Map<String, dynamic> c) async {
    final int? clientId =
        _saleData?['cliente_id'] as int? ??
        _saleData?['cliente_info']?['id'] as int?;
    if (clientId == null || clientId <= 0) return;
    final saleProv = Provider.of<SaleProvider>(context, listen: false);
    final client = await saleProv.getClientById(clientId);
    if (client != null && mounted) {
      final double cuotaMonto = (num.tryParse(c['monto'].toString()) ?? 0.0)
          .toDouble();
      final double cuotaPagado =
          (num.tryParse((c['monto_pagado'] ?? 0.0).toString()) ?? 0.0)
              .toDouble();
      final double saldoCuota = cuotaMonto - cuotaPagado;

      showModalBottomSheet(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => PaymentEntryModal(
          client: client,
          initialTargetType: 'cuota',
          initialTargetId: c['id'] as int?,
          initialAmount: saldoCuota > 0.01 ? saldoCuota : cuotaMonto,
          onPaymentSuccess: () {
            _loadData();
            saleProv.silentRefresh();
          },
        ),
      );
    }
  }
}
