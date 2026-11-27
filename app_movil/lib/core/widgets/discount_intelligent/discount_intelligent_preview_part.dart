part of '../discount_intelligent_modal.dart';

extension _DiscountIntelligentPreviewPart on _DiscountIntelligentModalState {
  Widget _buildPreviewDashboardSection({
    required Color textColor,
    required bool hasValidDiscount,
    required int discountPercentRounded,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.black26
            : Colors.purple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark
              ? Colors.white10
              : Colors.purple.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          _buildPriceSummaryRow(
            labelWidget: Text(
              "Precio Regular",
              style: TextStyle(
                color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
                fontSize: 14,
              ),
            ),
            valueText: AppCurrency.format(_precioBase),
            valueStyle: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          _buildPriceSummaryRow(
            labelWidget: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  "Descuento Aplicado",
                  style: TextStyle(
                    color: widget.isDark ? Colors.purple[300] : Colors.purple,
                    fontSize: 14,
                  ),
                ),
                if (discountPercentRounded > 0)
                  _buildDiscountPercentBadge(discountPercentRounded),
              ],
            ),
            valueText: hasValidDiscount
                ? "- ${AppCurrency.format(_precioBase - _nuevoPrecioFinal)}"
                : AppCurrency.format(0),
            valueStyle: TextStyle(
              color: widget.isDark ? Colors.purple[300] : Colors.purple,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          _buildPriceSummaryRow(
            labelWidget: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                "NUEVO PRECIO",
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            valueText: AppCurrency.format(_nuevoPrecioFinal),
            valueStyle: TextStyle(
              color: widget.isDark ? Colors.green[400] : Colors.green[700],
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSummaryRow({
    required Widget labelWidget,
    required String valueText,
    required TextStyle valueStyle,
  }) {
    return Row(
      children: [
        Expanded(flex: 3, child: labelWidget),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(valueText, style: valueStyle),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiscountPercentBadge(int discountPercentRounded) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.red[900]!.withValues(alpha: 0.4)
            : Colors.red[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: widget.isDark ? Colors.red[400]! : Colors.red.shade300,
        ),
      ),
      child: Text(
        "-$discountPercentRounded%",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: widget.isDark ? Colors.red[300] : Colors.red[800],
        ),
      ),
    );
  }
}
