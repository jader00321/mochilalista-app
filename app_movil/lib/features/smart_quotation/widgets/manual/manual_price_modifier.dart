import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ManualPriceModifier extends StatelessWidget {
  final bool isManualPrice;
  final double systemPrice;
  final TextEditingController discountCtrl;
  final TextEditingController priceCtrl;
  final FocusNode? discountFocusNode;
  final Function(bool) onToggle;
  final Function(String) onDiscountChanged;
  final Function(String) onPriceChanged;
  final bool isDark;
  final NumberFormat currency;
  final VoidCallback? onEditCatalogPrice;
  final bool catalogHasOffer;
  final double? catalogOfferPrice;
  final int catalogDiscountPercent;

  const ManualPriceModifier({
    super.key,
    required this.isManualPrice,
    required this.systemPrice,
    required this.discountCtrl,
    required this.priceCtrl,
    this.discountFocusNode,
    required this.onToggle,
    required this.onDiscountChanged,
    required this.onPriceChanged,
    required this.isDark,
    required this.currency,
    this.onEditCatalogPrice,
    this.catalogHasOffer = false,
    this.catalogOfferPrice,
    this.catalogDiscountPercent = 0,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: isManualPrice
            ? (isDark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange[50])
            : (isDark ? Colors.white10 : Colors.grey[50]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isManualPrice
              ? (isDark ? Colors.orange.withValues(alpha: 0.5) : Colors.orange.shade300)
              : (isDark ? Colors.transparent : Colors.grey.shade300),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nivel 1: Título a la izquierda + Switch a la derecha
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_offer_outlined,
                          size: 18,
                          color: isManualPrice
                              ? (isDark ? Colors.orange[300] : Colors.orange[800])
                              : (isDark ? Colors.grey[400] : Colors.grey[700]),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Aplicar Descuento",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isManualPrice
                                ? (isDark ? Colors.orange[300] : Colors.orange[900])
                                : textColor,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: isManualPrice,
                      activeThumbColor: Colors.orange,
                      onChanged: onToggle,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Nivel 2: Precio Base + Botón Editar Catálogo (Garantiza 0 colisiones en pantallas angostas)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (catalogHasOffer && catalogOfferPrice != null) ...[
                            Text(
                              currency.format(systemPrice),
                              style: TextStyle(
                                fontSize: 12,
                                decoration: TextDecoration.lineThrough,
                                color: isDark ? Colors.grey[500] : Colors.grey[500],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              currency.format(catalogOfferPrice),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.green[300] : Colors.green[700],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "-$catalogDiscountPercent%",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.green[300] : Colors.green[800],
                                ),
                              ),
                            ),
                          ] else ...[
                            Text(
                              "Precio Base: ${currency.format(systemPrice)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onEditCatalogPrice != null)
                      InkWell(
                        onTap: onEditCatalogPrice,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_outlined, size: 14, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                              const SizedBox(width: 4),
                              Text(
                                "Editar Catálogo",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.blue[300] : Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (isManualPrice) ...[
            Divider(height: 1, color: isDark ? Colors.orange.withValues(alpha: 0.3) : Colors.orange[200]),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "S/ a Descontar",
                          style: TextStyle(
                            color: isDark ? Colors.orange[300] : Colors.orange[900],
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF14141C) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.orange.withValues(alpha: 0.5) : Colors.orange.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: TextField(
                            focusNode: discountFocusNode,
                            controller: discountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                            decoration: InputDecoration(
                              prefixText: "- S/ ",
                              prefixStyle: TextStyle(
                                color: isDark ? Colors.orange[300] : Colors.orange[900],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              hintText: "0.00",
                              hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                              isDense: true,
                              border: InputBorder.none,
                            ),
                            onChanged: onDiscountChanged,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Precio Final Unit.",
                          style: TextStyle(
                            color: isDark ? Colors.blue[300] : Colors.blue[900],
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF14141C) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.blue.withValues(alpha: 0.5) : Colors.blue.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.blue[300] : Colors.blue[900],
                            ),
                            decoration: InputDecoration(
                              prefixText: "S/ ",
                              prefixStyle: TextStyle(
                                color: isDark ? Colors.blue[300] : Colors.blue[900],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              isDense: true,
                              border: InputBorder.none,
                            ),
                            onChanged: onPriceChanged,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
