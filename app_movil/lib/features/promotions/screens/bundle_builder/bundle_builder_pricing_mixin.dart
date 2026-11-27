part of '../bundle_builder_screen.dart';

mixin _BundleBuilderPricingMixin on _BundleBuilderScreenStateBase {
  Widget _buildHeroPriceCard({
    required bool isDark,
    required Color promoColor,
    required double savings,
    required double originalValue,
  }) {
    return AnimatedContainer(
      key: _tourKeys.pricingSavingsKey,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            promoColor.withValues(alpha: isDark ? 0.2 : 0.1),
            promoColor.withValues(alpha: isDark ? 0.05 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: promoColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: promoColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runAlignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: promoColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "PRECIO DE VENTA",
                  style: TextStyle(
                    color: promoColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              if (savings > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Ahorro ${(savings * 100).toStringAsFixed(0)}%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "S/ ",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "0.00",
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) {
                    _userEditedPrice = true;
                    setState(() {});
                  },
                ),
              ),
              Icon(
                Icons.edit,
                color: promoColor.withValues(alpha: 0.5),
                size: 24,
              ),
            ],
          ),
          if (originalValue > 0) ...[
            const SizedBox(height: 4),
            Text(
              "Valor Original: ${AppCurrency.format(originalValue)}",
              style: const TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextButton.icon(
            icon: Icon(Icons.autorenew, size: 16, color: promoColor),
            label: Text(
              "Recalcular sugerido",
              style: TextStyle(color: promoColor, fontWeight: FontWeight.bold),
            ),
            style: TextButton.styleFrom(
              backgroundColor: promoColor.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              _userEditedPrice = false;
              _autoSuggestNameAndPrice();
              setState(() {});
              AppFeedbackHelper.showSuccess(context, "Precio recalculado");
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfitabilitySection({
    required bool isDark,
    required Color profitColor,
    required double currentPrice,
    required double cost,
    required double margin,
    required double savings,
  }) {
    final String textStatus;
    if (currentPrice <= 0) {
      textStatus = "Define un precio";
    } else if (margin < 0.10) {
      textStatus = margin < 0 ? "¡Pérdida!" : "Riesgo / Al costo";
    } else if (margin < 0.25) {
      textStatus = "Margen ajustado";
    } else {
      textStatus = "Buen margen";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const Flexible(
                    child: Text(
                      "Análisis de Rentabilidad",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _showInfoTooltip(
                      context,
                      "Rentabilidad y Margen",
                      "El margen indica el porcentaje de ganancia sobre el precio de venta final.\n\nEvita márgenes por debajo del 10% (rojo) para no incurrir en pérdidas luego de gastos operativos.",
                      Icons.analytics,
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(Icons.water_drop, size: 14),
              label: const Text(
                "Al Costo",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                setState(() {
                  _priceController.text = cost.toStringAsFixed(2);
                  _userEditedPrice = true;
                });
                AppFeedbackHelper.showSuccess(
                  context,
                  "Precio igualado al costo total",
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (margin < 0)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Estás vendiendo por debajo del costo base. Obtendrás pérdidas.",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: profitColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: profitColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: profitColor.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Costo Base",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            AppCurrency.format(cost),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Margen / Rentabilidad",
                          style: TextStyle(
                            fontSize: 13,
                            color: profitColor,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            currentPrice > 0
                                ? "${(margin * 100).toStringAsFixed(1)}%"
                                : "0.0%",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                              color: profitColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: currentPrice > 0 ? margin.clamp(0.0, 1.0) : 0,
                  minHeight: 10,
                  backgroundColor: isDark ? Colors.black26 : Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(profitColor),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle_rounded, size: 12, color: profitColor),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          textStatus,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: profitColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (savings > 0 && currentPrice > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "El cliente ahorra ${(savings * 100).toStringAsFixed(1)}%",
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
