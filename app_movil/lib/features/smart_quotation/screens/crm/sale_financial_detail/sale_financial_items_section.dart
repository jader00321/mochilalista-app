part of '../sale_financial_detail_screen.dart';

mixin _SaleFinancialItemsMixin on _SaleFinancialDetailScreenStateBase {
  Widget _buildItemsSection(
    List<dynamic> items,
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Text(
            "Productos Adquiridos (${items.length})",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? Colors.blueGrey[300] : Colors.blueGrey,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final item = items[i];
            final String brand = item['brand_name']?.toString() ?? "";
            final String prodName =
                item['product_name']?.toString() ?? "Producto";
            final String specificName = item['specific_name']?.toString() ?? "";

            String fullName = brand.isNotEmpty
                ? "[$brand] $prodName"
                : prodName;
            if (specificName.isNotEmpty && specificName != 'null') {
              fullName += " ($specificName)";
            }

            final String salesUnit = item['sales_unit']?.toString() ?? "Unidad";
            final double unitP =
                (num.tryParse(item['unit_price_applied']?.toString() ?? '0') ??
                        0.0)
                    .toDouble();
            final double originalP =
                (num.tryParse(item['original_unit_price']?.toString() ?? '0') ??
                        unitP)
                    .toDouble();
            final int quantity =
                int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;

            final String imageUrl = item['image_url']?.toString() ?? "";
            final String originalText = item['original_text']?.toString() ?? "";

            return Card(
              elevation: 0,
              color: cardColor,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isDark ? Colors.white10 : Colors.transparent,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl.isNotEmpty && imageUrl != 'null')
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: UniversalImage(
                          path: imageUrl,
                          width: 45,
                          height: 45,
                          fit: BoxFit.cover,
                          productName: prodName,
                        ),
                      )
                    else
                      Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          color: isDark
                              ? Colors.blueGrey[400]
                              : Colors.blueGrey,
                          size: 24,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: textColor,
                            ),
                          ),
                          if (originalText.isNotEmpty &&
                              originalText != "null") ...[
                            const SizedBox(height: 2),
                            Text(
                              "Cotizado como: $originalText",
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "$quantity $salesUnit",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.blueGrey[300]
                                        : Colors.blueGrey[700],
                                  ),
                                ),
                              ),
                              Text(
                                "x ${AppCurrency.format(unitP)}",
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              if (originalP > unitP)
                                Text(
                                  AppCurrency.format(originalP),
                                  style: TextStyle(
                                    color: Colors.red[300],
                                    fontSize: 11,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 96),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          AppCurrency.format(unitP * quantity),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
