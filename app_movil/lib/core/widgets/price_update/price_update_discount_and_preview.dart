part of '../price_update_modal.dart';

extension _PriceUpdateDiscountAndPreview on _PriceUpdateModalState {
  Widget _buildDiscountTypeTabs() {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF14141C) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: "% Porcentaje",
              selected: discountType == 0,
              isDark: widget.isDark,
              onTap: () {
                if (discountType != 0) {
                  final double base = double.tryParse(priceCtrl.text) ?? 0.0;
                  final double val = double.tryParse(discountCtrl.text) ?? 0.0;
                  if (base > 0 && val > 0 && val < base) {
                    final double calcPercent = ((base - val) / base) * 100;
                    discountCtrl.text = calcPercent.round().toString();
                  }
                  _updateState(() {
                    discountType = 0;
                    _activeRoundingTarget = null;
                  });
                  _calculate();
                }
              },
            ),
          ),
          Expanded(
            child: _TabButton(
              label: "S/ Fijo",
              selected: discountType == 1,
              isDark: widget.isDark,
              onTap: () {
                if (discountType != 1) {
                  final double base = double.tryParse(priceCtrl.text) ?? 0.0;
                  final double val = double.tryParse(discountCtrl.text) ?? 0.0;
                  if (base > 0 && val > 0 && val < 100) {
                    final double calcOffer = base * (1 - (val / 100));
                    discountCtrl.text = calcOffer.toStringAsFixed(2);
                  }
                  _updateState(() {
                    discountType = 1;
                    _activeRoundingTarget = null;
                  });
                  _calculate();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountInputField(Color textColor) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      child: TextField(
        controller: discountCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        scrollPadding: const EdgeInsets.only(bottom: 90),
        style: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          labelText: discountType == 0
              ? "Porcentaje de Oferta (%)"
              : "Precio Oferta (S/)",
          labelStyle: TextStyle(
            color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: widget.isDark ? Colors.blue[300]! : Colors.blue,
            ),
          ),
          errorText: errorMsg,
          suffixText: discountType == 0 ? "%" : "S/",
          suffixStyle: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        onChanged: (_) => _onDiscountInputChanged(),
      ),
    );
  }

  Widget _buildQuickDiscountSection(double currentBase) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Descuentos Rápidos:",
          style: TextStyle(
            fontSize: 12,
            color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _QuickChip(
                label: "-5%",
                isDark: widget.isDark,
                onTap: () => _applyQuickPercent(5),
              ),
              const SizedBox(width: 8),
              _QuickChip(
                label: "-10%",
                isDark: widget.isDark,
                onTap: () => _applyQuickPercent(10),
              ),
              const SizedBox(width: 8),
              _QuickChip(
                label: "-15%",
                isDark: widget.isDark,
                onTap: () => _applyQuickPercent(15),
              ),
              const SizedBox(width: 8),
              _QuickChip(
                label: "-20%",
                isDark: widget.isDark,
                onTap: () => _applyQuickPercent(20),
              ),
              const SizedBox(width: 8),
              _QuickChip(
                label: "-50%",
                isDark: widget.isDark,
                onTap: () => _applyQuickPercent(50),
              ),
            ],
          ),
        ),
        if (finalOfferPrice != null && finalOfferPrice! < currentBase) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                "Redondear oferta:",
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              _QuickChip(
                label: ".50",
                isDark: widget.isDark,
                isActive: _activeRoundingTarget == 0.50,
                onTap: () => _applyRoundingChip(0.50),
              ),
              _QuickChip(
                label: ".90",
                isDark: widget.isDark,
                isActive: _activeRoundingTarget == 0.90,
                onTap: () => _applyRoundingChip(0.90),
              ),
              _QuickChip(
                label: ".00",
                isDark: widget.isDark,
                isActive:
                    _activeRoundingTarget == 1.00 ||
                    _activeRoundingTarget == 0.00,
                onTap: () => _applyRoundingChip(1.00),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildOfferPreviewSection(double currentBase) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      child:
          finalOfferPrice != null &&
              finalOfferPrice! < currentBase &&
              errorMsg == null
          ? Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.green[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isDark
                      ? Colors.green.withValues(alpha: 0.4)
                      : Colors.green.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    "PRECIO FINAL AL CLIENTE",
                    style: TextStyle(
                      color: widget.isDark ? Colors.green[300] : Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppCurrency.format(
                            currentBase,
                            includeThousandsSeparator: false,
                          ),
                          style: TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: widget.isDark
                                ? Colors.grey[500]
                                : Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            Icons.arrow_right_alt,
                            color: widget.isDark
                                ? Colors.green[300]
                                : Colors.green,
                          ),
                        ),
                        Text(
                          AppCurrency.format(
                            finalOfferPrice!,
                            includeThousandsSeparator: false,
                          ),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: widget.isDark
                                ? Colors.green[400]
                                : Colors.green[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _updateState(() {
                      finalOfferPrice = null;
                      discountCtrl.clear();
                      _activeRoundingTarget = null;
                      _preRoundedValor = null;
                      isBasePriceUpdate = false;
                      errorMsg = null;
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        "Quitar Oferta",
                        style: TextStyle(
                          color: widget.isDark ? Colors.red[300] : Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  const _TabButton({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                    ),
                ]
              : null,
          border: selected
              ? Border.all(
                  color: isDark
                      ? Colors.blue.withValues(alpha: 0.5)
                      : Colors.transparent,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? (isDark ? Colors.blue[300] : Colors.black87)
                  : (isDark ? Colors.grey[500] : Colors.grey),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final bool isDark;
  final bool isActive;
  final VoidCallback onTap;
  const _QuickChip({
    required this.label,
    required this.isDark,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark
                    ? Colors.blue.withValues(alpha: 0.35)
                    : Colors.blue.shade100)
              : (isDark ? const Color(0xFF14141C) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? (isDark ? Colors.blue.shade300 : Colors.blue.shade700)
                : (isDark ? Colors.white24 : Colors.grey.shade300),
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive) ...[
              Icon(
                Icons.check_rounded,
                size: 13,
                color: isDark ? Colors.blue[200] : Colors.blue[900],
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
                fontSize: 12.5,
                color: isActive
                    ? (isDark ? Colors.blue[100] : Colors.blue[900])
                    : (isDark ? Colors.blueGrey[200] : Colors.blueGrey[800]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
