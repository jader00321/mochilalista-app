part of '../client_finance_actions_modal.dart';

mixin _ClientFinanceInputsAndOneQuotaMixin on _ClientFinanceActionsStateBase {
  @override
  Widget _buildOneQuotaStatusCard(Color textColor, double enteredAmount) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF14141C) : Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDark ? Colors.white10 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Estado de Pago Inicial",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),
              if (_oneQuotaPaidAmount > 0)
                Text(
                  "Abonado: ${AppCurrency.format(_oneQuotaPaidAmount)}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "¿Este préstamo ya fue amortizado o pagado previamente?",
            style: TextStyle(
              fontSize: 11.5,
              color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text("Pendiente / Vencida"),
                selected: _oneQuotaPaidAmount == 0,
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _oneQuotaPaidAmount = 0.0;
                      _oneQuotaStatus = _dueDate.isBefore(DateTime.now())
                          ? 'vencida'
                          : 'pendiente';
                    });
                    _saveCurrentDraft();
                  }
                },
                selectedColor: Colors.orange.withValues(alpha: 0.25),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: _oneQuotaPaidAmount == 0
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _oneQuotaPaidAmount == 0
                      ? Colors.orange
                      : (widget.isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
              ),
              ChoiceChip(
                label: const Text("Ya Pagada"),
                selected: enteredAmount > 0 &&
                    _oneQuotaPaidAmount >= enteredAmount,
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _oneQuotaPaidAmount =
                          enteredAmount > 0 ? enteredAmount : 0.0;
                      _oneQuotaStatus = 'pagado';
                    });
                    _saveCurrentDraft();
                  }
                },
                selectedColor: Colors.green.withValues(alpha: 0.25),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: (enteredAmount > 0 &&
                          _oneQuotaPaidAmount >= enteredAmount)
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: (enteredAmount > 0 &&
                          _oneQuotaPaidAmount >= enteredAmount)
                      ? Colors.green
                      : (widget.isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
              ),
              ChoiceChip(
                label: const Text("Pago Parcial"),
                selected: _oneQuotaPaidAmount > 0 &&
                    _oneQuotaPaidAmount < enteredAmount,
                onSelected: (val) {
                  _showOneQuotaPartialDialog(enteredAmount);
                },
                selectedColor: Colors.blue.withValues(alpha: 0.25),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: (_oneQuotaPaidAmount > 0 &&
                          _oneQuotaPaidAmount < enteredAmount)
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: (_oneQuotaPaidAmount > 0 &&
                          _oneQuotaPaidAmount < enteredAmount)
                      ? Colors.blue
                      : (widget.isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
              ),
            ],
          ),
          if (enteredAmount > 0) ...[
            const SizedBox(height: 8),
            Divider(
                height: 1,
                color: widget.isDark ? Colors.white10 : Colors.grey[200]),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Saldo Deudor Inicial:",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                Text(
                  AppCurrency.format((enteredAmount - _oneQuotaPaidAmount)
                      .clamp(0.0, double.infinity)),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: (enteredAmount - _oneQuotaPaidAmount) > 0
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget _buildWeekdayButton(int dayNumber, String shortLetter, String fullName) {
    final bool isExcluded = _excludedWeekdays.contains(dayNumber);
    final isDark = widget.isDark;

    Color bgColor;
    Color fgColor;
    Border border;
    List<BoxShadow>? shadows;

    if (isExcluded) {
      bgColor = isDark ? Colors.white.withAlpha(8) : Colors.grey[100]!;
      fgColor = isDark ? Colors.grey[600]! : Colors.grey[400]!;
      border = Border.all(
        color: isDark ? Colors.white10 : Colors.grey.shade300,
        width: 1,
      );
      shadows = null;
    } else {
      bgColor = isDark
          ? Colors.orange.withValues(alpha: 0.25)
          : Colors.orange.shade50;
      fgColor = isDark ? Colors.orange[200]! : Colors.orange[900]!;
      border = Border.all(
        color: isDark ? Colors.orange : Colors.orange.shade700,
        width: 1.5,
      );
      shadows = [
        BoxShadow(
          color: Colors.orange.withValues(alpha: isDark ? 0.25 : 0.15),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];
    }

    return Tooltip(
      message: isExcluded
          ? "$fullName (Excluido de cobro)"
          : "$fullName (Día de cobro activo)",
      child: InkWell(
        onTap: () => _toggleWeekday(dayNumber),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 40,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: border,
            boxShadow: shadows,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                shortLetter,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: fgColor,
                  decoration: isExcluded ? TextDecoration.lineThrough : null,
                ),
              ),
              if (!isExcluded) ...[
                const SizedBox(height: 2),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.orange[300] : Colors.orange[800],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget _buildPresetChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = widget.isDark;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? Colors.orange.withValues(alpha: 0.25)
                  : Colors.orange.shade50)
              : (isDark ? Colors.white.withAlpha(12) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.orange : Colors.orange.shade700)
                : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color:
                        Colors.orange.withValues(alpha: isDark ? 0.25 : 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                isSelected ? Icons.check_circle_rounded : icon,
                size: 14,
                color: isSelected
                    ? (isDark ? Colors.orange[300] : Colors.orange[800])
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.orange[200] : Colors.orange[900])
                    : (isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget _buildMethodChip(String method, IconData icon, bool isWithdraw) {
    bool isSelected =
        isWithdraw ? _withdrawMethod == method : _loanMethod == method;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected
                ? Colors.white
                : (widget.isDark ? Colors.grey[400] : Colors.grey[700]),
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
            _saveCurrentDraft();
          });
        }
      },
      selectedColor: isWithdraw ? Colors.teal : Colors.orange[800],
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (widget.isDark ? Colors.grey[300] : Colors.grey[800]),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 13,
      ),
      backgroundColor: widget.isDark ? Colors.white10 : Colors.grey[100],
      side: BorderSide(
        color: isSelected
            ? (isWithdraw
                ? Colors.teal
                : (Colors.orange[800] ?? Colors.orange))
            : (widget.isDark ? Colors.white10 : Colors.grey.shade300),
      ),
    );
  }

  @override
  Widget _buildInputLarge({
    required TextEditingController ctrl,
    required bool isDark,
    required Color textColor,
    required bool isInt,
  }) {
    return TextField(
      controller: ctrl,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      keyboardType: isInt
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: isInt
          ? [FilteringTextInputFormatter.digitsOnly]
          : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      style: TextStyle(
          fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
      decoration: InputDecoration(
        prefixText: "S/ ",
        prefixStyle: TextStyle(
            fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
        filled: true,
        fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey.shade300),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  @override
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
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      keyboardType: isInt
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: isInt
          ? [FilteringTextInputFormatter.digitsOnly]
          : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      style: TextStyle(
          color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 13),
        prefixText: prefix,
        suffixText: suffix,
        filled: true,
        fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
    );
  }
}
