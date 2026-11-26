part of 'payment_entry_modal.dart';

mixin _PaymentEntryHeaderAndChipsMixin on _PaymentEntryStateBase {
  @override
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

  /// Obtiene el monto numérico esperado asociado a una etiqueta de chip rápido
  @override
  double _getExpectedAmountForLabel(String label) {
    final provider = Provider.of<TrackingProvider>(context, listen: false);
    switch (label) {
      case "Total":
      case "Deuda Total":
        return widget.client.totalDebt;
      case "Cuota Ant.":
        return _getOldestInstallmentAmount(provider) ?? 0.0;
      case "Total Vencido":
        return _getTotalOverdueAmount(provider);
      case "Próxima Cuota":
        return _getNextUpcomingInstallmentAmount(provider) ?? 0.0;
      case "50% Deuda":
        return widget.client.totalDebt / 2;
      default:
        return 0.0;
    }
  }

  /// Manejo interactivo de Toggle On / Off para etiquetas de monto rápido
  void _handleQuickChipTap(String label, double amount) {
    HapticFeedback.lightImpact();
    if (_selectedQuickChipLabel == label) {
      // 🏷️ FASE 4: Segundo toque en el chip activo -> Desmarcar y limpiar campo
      _selectedQuickChipLabel = null;
      _amountCtrl.clear();
    } else {
      // Primer toque -> Marcar este chip e inyectar el monto
      _selectedQuickChipLabel = label;
      _amountCtrl.text = amount.toStringAsFixed(2);
    }
    setState(() {});
  }

  /// Tarjeta compacta de monto rápido con animación suave e indicador activo de selección
  Widget _buildQuickAmountCard({
    required String label,
    required double amount,
    required Color color,
    required bool isDark,
    bool isWarning = false,
  }) {
    final bool isSelected = _selectedQuickChipLabel == label;

    return InkWell(
      onTap: () => _handleQuickChipTap(label, amount),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2E7D32).withValues(alpha: 0.25) : Colors.green.shade50)
              : (isWarning
                  ? (isDark ? Colors.orange.withValues(alpha: 0.12) : Colors.orange.shade50)
                  : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.greenAccent : const Color(0xFF2E7D32))
                : (isWarning
                    ? Colors.orange.withValues(alpha: 0.35)
                    : (isDark ? Colors.white12 : Colors.grey.shade300)),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Icon(
                    Icons.check_rounded,
                    size: 11,
                    color: isDark ? Colors.greenAccent : const Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 3),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    color: isSelected
                        ? (isDark ? Colors.greenAccent : const Color(0xFF2E7D32))
                        : (isWarning
                            ? (isDark ? Colors.orange[300] : Colors.orange[900])
                            : (isDark ? Colors.grey[400] : Colors.grey[700])),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                AppCurrency.format(amount),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? (isDark ? Colors.greenAccent : const Color(0xFF2E7D32))
                      : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cabecera Extendida con Input, Carrusel de Chips Rápidos y Métodos de Pago en 1 Fila
  @override
  Widget _buildExpandedHeaderInputs(
    double enteredAmount,
    double targetDebt,
    double? oldestInstallmentAmt,
    double totalOverdueAmt,
    double? nextInstallmentAmt,
    Color textColor,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campo Monto con auto-unfocus al tocar fuera
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
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

          // Chips de Monto Rápido en Carrusel Horizontal de 1 Sola Línea con Toggle On/Off
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildQuickAmountCard(
                    label: "Total",
                    amount: widget.client.totalDebt,
                    color: isDark ? Colors.green[300]! : const Color(0xFF2E7D32),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  if (oldestInstallmentAmt != null && oldestInstallmentAmt > 0) ...[
                    _buildQuickAmountCard(
                      label: "Cuota Ant.",
                      amount: oldestInstallmentAmt,
                      color: isDark ? Colors.orange[300]! : Colors.orange[800]!,
                      isDark: isDark,
                      isWarning: true,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (totalOverdueAmt > 0.01) ...[
                    _buildQuickAmountCard(
                      label: "Total Vencido",
                      amount: totalOverdueAmt,
                      color: isDark ? Colors.red[300]! : Colors.red[800]!,
                      isDark: isDark,
                      isWarning: true,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (nextInstallmentAmt != null && nextInstallmentAmt > 0) ...[
                    _buildQuickAmountCard(
                      label: "Próxima Cuota",
                      amount: nextInstallmentAmt,
                      color: isDark ? Colors.blue[300]! : Colors.blue[800]!,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                  ],
                  _buildQuickAmountCard(
                    label: "50% Deuda",
                    amount: widget.client.totalDebt / 2,
                    color: isDark ? Colors.cyan[300]! : Colors.cyan[800]!,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildQuickAmountCard(
                    label: "Deuda Total",
                    amount: widget.client.totalDebt,
                    color: isDark ? Colors.green[300]! : const Color(0xFF2E7D32),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
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
