part of '../price_update_modal.dart';

extension _PriceUpdateHeaderAndMargin on _PriceUpdateModalState {
  Widget _buildModalTitleWidget(Color textColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            "Gestionar Precio",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: textColor,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "Actualiza el precio regular o define una oferta.",
          style: TextStyle(
            color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildRegularPriceField(Color textColor) {
    return TextField(
      controller: priceCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      scrollPadding: const EdgeInsets.only(bottom: 90),
      style: TextStyle(
        color: textColor,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        labelText: "Precio Regular (S/)",
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
        prefixText: "S/ ",
        prefixStyle: TextStyle(
          color: widget.isDark ? Colors.green[300] : Colors.green[800],
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      onChanged: (_) {
        _updateState();
        _calculate();
      },
    );
  }

  Widget _buildMarginCalculatorCard(double effectiveTargetPrice) {
    final double costoPresentacion = widget.presentation.costoPresentacionFinal;
    if (costoPresentacion <= 0 || effectiveTargetPrice <= 0) {
      return const SizedBox.shrink();
    }

    final double ganancia = effectiveTargetPrice - costoPresentacion;
    final double margenPercent =
        ((effectiveTargetPrice - costoPresentacion) / effectiveTargetPrice) *
        100;

    final Color marginColor = margenPercent >= 20
        ? (widget.isDark ? Colors.green[400]! : Colors.green[700]!)
        : (margenPercent >= 10
              ? (widget.isDark ? Colors.amber[400]! : Colors.amber[800]!)
              : (widget.isDark ? Colors.red[400]! : Colors.red[700]!));

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: marginColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: marginColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            margenPercent >= 20
                ? Icons.check_circle
                : (margenPercent >= 10
                      ? Icons.info_outline
                      : Icons.warning_amber),
            color: marginColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text(
                      "Margen: ${margenPercent.toStringAsFixed(1)}%",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: marginColor,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      "Ganancia: ${AppCurrency.format(ganancia, includeThousandsSeparator: false)}",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: widget.isDark
                            ? Colors.grey[300]
                            : Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "Costo estimado: ${AppCurrency.format(costoPresentacion, includeThousandsSeparator: false)}",
                  style: TextStyle(
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasePriceUpdateBanner(double currentBase, double val) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.blue.withValues(alpha: 0.15)
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDark ? Colors.blue.shade400 : Colors.blue.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: widget.isDark ? Colors.blue[300] : Colors.blue[800],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Nuevo Precio Base de Venta: ${AppCurrency.format(currentBase, includeThousandsSeparator: false)} ➔ ${AppCurrency.format(val, includeThousandsSeparator: false)}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: widget.isDark ? Colors.blue[200] : Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Al aplicar cambios, el precio regular se actualizará a este monto y cualquier oferta anterior quedará eliminada.",
            style: TextStyle(
              fontSize: 11,
              color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
