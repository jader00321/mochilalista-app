part of '../invoice_detail_screen.dart';

mixin _InvoiceDetailAuditCardsMixin on _InvoiceDetailScreenStateBase {
  @override
  Widget _buildExtractedAiItemsList(bool isDark, List<dynamic> extractedItems) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: extractedItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final item = extractedItems[i];
        final String itemDesc =
            item['descripcion_detectada']?.toString().trim() ??
            "Sin descripción";
        final String? parent = item['producto_padre_estimado']
            ?.toString()
            .trim();
        final String? variant = item['variante_detectada']?.toString().trim();
        final String? brand = item['marca_detectada']?.toString().trim();
        final String? code =
            (item['codigo_detectada'] ?? item['codigo_detectado'])
                ?.toString()
                .trim();
        final String? uSale = item['unidad_venta']?.toString().trim();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.transparent : Colors.grey.shade300,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.blue[900] : Colors.blue[50])
                          ?.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: (isDark ? Colors.blue[700] : Colors.blue[200])!,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '#${(i + 1).toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.blue[200] : Colors.blue[800],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      itemDesc.isEmpty ? "Sin descripción" : itemDesc,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (parent != null && parent.isNotEmpty && parent != 'N/A')
                    _auditTag("Padre", parent, isDark),
                  if (variant != null && variant.isNotEmpty && variant != 'N/A')
                    _auditTag("Variante", variant, isDark),
                  if (brand != null && brand.isNotEmpty && brand != 'N/A')
                    _auditTag("Marca", brand, isDark),
                  if (code != null && code.isNotEmpty && code != 'N/A')
                    _auditTag("Código", code, isDark),
                  if (uSale != null && uSale.isNotEmpty)
                    _auditTag("U. Venta", uSale, isDark),
                ],
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  double totalPago =
                      num.tryParse(
                        item['total_pago_lote']?.toString() ?? '0',
                      )?.toDouble() ??
                      0.0;
                  double cantidadUmp =
                      num.tryParse(
                        item['cantidad_ump_comprada']?.toString() ?? '1',
                      )?.toDouble() ??
                      1.0;
                  int unidadesLote =
                      int.tryParse(
                        item['unidades_por_lote']?.toString() ?? '1',
                      ) ??
                      1;
                  double precioUmp =
                      num.tryParse(
                        item['precio_ump_proveedor']?.toString() ?? '0',
                      )?.toDouble() ??
                      0.0;
                  double costoUnitarioReal =
                      (cantidadUmp > 0 && unidadesLote > 0)
                      ? totalPago / (cantidadUmp * unidadesLote)
                      : 0.0;
                  String ump = item['ump_compra'] ?? 'UND';

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                "Compra:",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                "$cantidadUmp $ump (x$unidadesLote)",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                "Precio UMP ($ump):",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                AppCurrency.format(precioUmp),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                "Costo Unitario Real:",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                AppCurrency.format(
                                  costoUnitarioReal,
                                  decimals: 3,
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.orange[300]
                                      : Colors.orange[800],
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                "Total Pagado:",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[800],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  AppCurrency.format(totalPago),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? Colors.green[400]
                                        : Colors.green[700],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget _auditTag(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isDark ? Colors.grey[500] : Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.blue[200] : Colors.blue[800],
          ),
        ),
      ],
    );
  }
}
