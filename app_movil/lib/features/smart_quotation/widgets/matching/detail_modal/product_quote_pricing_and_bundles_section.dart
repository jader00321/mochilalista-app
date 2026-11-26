part of '../product_quote_detail_modal.dart';

mixin _ProductQuotePricingAndBundlesMixin on _ProductQuoteDetailStateBase {
  @override
  Widget _buildPricingSection(bool isDark, TextTheme textTheme) {
    final basePrice = _selectedPresentation.precioVentaFinal;
    final hasOffer =
        _selectedPresentation.precioOferta != null &&
        _selectedPresentation.precioOferta! > 0;
    final offerPrice = hasOffer
        ? _selectedPresentation.precioOferta!
        : basePrice;

    final applicableBundles = _getApplicableBundles();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Configuración de Precio",
          style: textTheme.titleMedium?.copyWith(
            color: isDark ? Colors.grey[300] : Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A24) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              _buildRadioOption(
                isDark: isDark,
                textTheme: textTheme,
                mode: _PricingMode.normal,
                title: "Precio Normal",
                subtitle: "Sin descuento aplicado",
                price: basePrice,
                activeColor: Colors.blue,
              ),
              if (hasOffer) ...[
                Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
                _buildRadioOption(
                  isDark: isDark,
                  textTheme: textTheme,
                  mode: _PricingMode.catalogOffer,
                  title: "Oferta de Catálogo",
                  subtitle: "Descuento individual activo",
                  price: offerPrice,
                  activeColor: Colors.green,
                ),
              ],
              Divider(
                height: 1,
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
              _buildRadioOption(
                isDark: isDark,
                textTheme: textTheme,
                mode: _PricingMode.manualDiscount,
                title: "Precio Especial Manual",
                subtitle: "Aplica un descuento personalizado",
                price: null,
                activeColor: Colors.orange,
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: _pricingMode == _PricingMode.manualDiscount
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity, height: 0),
                secondChild: _buildManualDiscountUI(
                  isDark,
                  textTheme,
                  basePrice,
                ),
              ),
            ],
          ),
        ),
        if (applicableBundles.isNotEmpty)
          _buildApplicableBundlesSection(applicableBundles, isDark, textTheme),
      ],
    );
  }

  Widget _buildRadioOption({
    required bool isDark,
    required TextTheme textTheme,
    required _PricingMode mode,
    required String title,
    required String subtitle,
    required double? price,
    required MaterialColor activeColor,
  }) {
    final bool isSelected = _pricingMode == mode;
    return InkWell(
      onTap: () => _selectPricingMode(mode),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? activeColor.withValues(alpha: 0.1)
                    : activeColor.shade50)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Radio<_PricingMode>(
              value: mode,
              // ignore: deprecated_member_use
              groupValue: _pricingMode,
              // ignore: deprecated_member_use
              onChanged: (v) {
                if (v != null) {
                  _selectPricingMode(v);
                }
              },
              activeColor: activeColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      color: isSelected
                          ? (isDark ? activeColor[300] : activeColor[900])
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? (isDark ? activeColor[200] : activeColor[700])
                          : (isDark ? Colors.grey[500] : Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            if (price != null) ...[
              const SizedBox(width: 8),
              Flexible(
                flex: 0,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    AppCurrency.format(price),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? (isDark ? activeColor[300] : activeColor[900])
                          : (isDark ? Colors.grey[400] : Colors.grey[700]),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildManualDiscountUI(
    bool isDark,
    TextTheme textTheme,
    double basePrice,
  ) {
    final double currentDiscount = double.tryParse(_discountCtrl.text) ?? 0.0;
    final double currentPrice = double.tryParse(_priceCtrl.text) ?? basePrice;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.orange.withValues(alpha: 0.05)
            : Colors.orange.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "S/ a Descontar",
                        style: textTheme.labelLarge?.copyWith(
                          color: isDark
                              ? Colors.orange[300]
                              : Colors.orange[900],
                        ),
                      ),
                    ),
                    TextField(
                      controller: _discountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: textTheme.headlineSmall?.copyWith(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        prefixText: "- ",
                        prefixStyle: textTheme.headlineSmall?.copyWith(
                          color: isDark
                              ? Colors.orange[300]
                              : Colors.orange[900],
                        ),
                        isDense: true,
                        border: InputBorder.none,
                        hintText: "0.00",
                      ),
                      onChanged: _onDiscountChanged,
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: isDark
                    ? Colors.orange.withValues(alpha: 0.3)
                    : Colors.orange[300],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Precio Final Unit.",
                        style: textTheme.labelLarge?.copyWith(
                          color: isDark ? Colors.blue[300] : Colors.blue[900],
                        ),
                      ),
                    ),
                    TextField(
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: textTheme.headlineSmall?.copyWith(
                        color: isDark ? Colors.blue[300] : Colors.blue,
                      ),
                      decoration: InputDecoration(
                        prefixText: "S/ ",
                        prefixStyle: textTheme.headlineSmall?.copyWith(
                          color: isDark ? Colors.blue[300] : Colors.blue,
                        ),
                        isDense: true,
                        border: InputBorder.none,
                      ),
                      onChanged: _onPriceChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade300,
              ),
            ),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "Base: ",
                    style: textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  TextSpan(
                    text: AppCurrency.format(basePrice),
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                  TextSpan(
                    text: " → Menos ",
                    style: textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  TextSpan(
                    text: AppCurrency.format(currentDiscount),
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.orange[300] : Colors.orange[800],
                    ),
                  ),
                  TextSpan(
                    text: " = Final: ",
                    style: textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  TextSpan(
                    text: AppCurrency.format(currentPrice),
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.blue[300] : Colors.blue[800],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicableBundlesSection(
    List<BundleModel> applicableBundles,
    bool isDark,
    TextTheme textTheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          "Paquetes Disponibles",
          style: textTheme.titleSmall?.copyWith(
            color: isDark ? Colors.amber[300] : Colors.amber[800],
          ),
        ),
        const SizedBox(height: 8),
        ...applicableBundles.map(
          (b) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.amber.withValues(alpha: 0.1)
                    : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.amber.withValues(alpha: 0.3)
                      : Colors.amber.shade200,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.nombrePaquete,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.amber[200]
                                : Colors.amber[900],
                          ),
                        ),
                        Text(
                          "Se aplica automáticamente (Referencial)",
                          style: textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? Colors.amber[100]
                                : Colors.amber[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
