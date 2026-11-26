import 'package:flutter/material.dart';

import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/universal_image.dart';

export 'package:app_movil/core/widgets/search/omni_search_secondary_cards.dart';

class OmniExpandableCardShell extends StatelessWidget {
  final bool isDark;
  final bool isExpanded;
  final Color expandedDarkBorder;
  final Color expandedLightBorder;
  final VoidCallback onTap;
  final Widget child;

  const OmniExpandableCardShell({
    super.key,
    required this.isDark,
    required this.isExpanded,
    required this.expandedDarkBorder,
    required this.expandedLightBorder,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? (isDark ? expandedDarkBorder : expandedLightBorder)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            child: Padding(padding: const EdgeInsets.all(12), child: child),
          ),
        ),
      ),
    );
  }
}

class OmniDetailChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final bool isMonospace;

  const OmniDetailChip(
    this.label,
    this.value,
    this.isDark, {
    super.key,
    this.isMonospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: TextSpan(
          text: "$label: ",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          children: [
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: isMonospace ? 'monospace' : null,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OmniProductResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onOpen;

  const OmniProductResultCard({
    super.key,
    required this.data,
    required this.isDark,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final double price =
        (data['precio_venta_final'] as num?)?.toDouble() ?? 0.0;
    final double? offerPrice = (data['precio_oferta'] as num?)?.toDouble();
    final int stock = (data['stock_actual'] as int?) ?? 0;
    final int factor = (data['unidades_por_venta'] as int?) ?? 1;
    final int displayStock = factor > 0 ? (stock ~/ factor) : stock;
    final String unit = data['unidad_venta'] ?? 'und';
    final String barcode = (data['codigo_barras'] ?? '').toString();
    final String category = data['categoria_nombre'] ?? 'Sin categoría';
    final String brand = data['marca_nombre'] ?? 'Genérico';
    final String? imgUrl = data['pres_img'] ?? data['prod_img'];
    final bool isLowStock = stock <= ((data['stock_alerta'] as int?) ?? 5);

    return OmniExpandableCardShell(
      isDark: isDark,
      isExpanded: isExpanded,
      expandedDarkBorder: Colors.blue.withValues(alpha: 0.5),
      expandedLightBorder: Colors.blue.shade300,
      onTap: onToggleExpand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: imgUrl != null && imgUrl.isNotEmpty
                      ? UniversalImage(
                          path: imgUrl,
                          width: 44,
                          height: 44,
                          productName: data['producto_nombre']?.toString(),
                          categoryName: category,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: isDark ? Colors.white10 : Colors.blue.shade50,
                          child: Icon(
                            Icons.inventory_2_rounded,
                            size: 20,
                            color: isDark ? Colors.blue[300] : Colors.blue[700],
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${data['producto_nombre'] ?? ''} ${data['nombre_especifico'] ?? ''}"
                          .trim(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: isExpanded ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            brand,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[700],
                            ),
                          ),
                        ),
                        Text(
                          "Stock: $displayStock $unit",
                          style: TextStyle(
                            fontSize: 11,
                            color: isLowStock
                                ? Colors.orangeAccent
                                : (isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600]),
                            fontWeight: isLowStock
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 96),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          AppCurrency.format(
                            offerPrice != null && offerPrice > 0
                                ? offerPrice
                                : price,
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: isDark
                                ? Colors.green[400]
                                : Colors.green[700],
                          ),
                        ),
                      ),
                      if (offerPrice != null && offerPrice > 0)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            AppCurrency.format(price),
                            style: const TextStyle(
                              fontSize: 10,
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                ),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onOpen,
                tooltip: "Ver producto",
              ),
            ],
          ),
          if (isExpanded) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OmniDetailChip("Categoría", category, isDark),
                OmniDetailChip("Empaque", "1 $unit = $factor und", isDark),
                if (barcode.isNotEmpty)
                  OmniDetailChip("Código", barcode, isDark, isMonospace: true),
                OmniDetailChip("Stock Total", "$stock unidades", isDark),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.blue[700] : Colors.blue[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  elevation: 0,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Ver Ficha Completa del Producto",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                onPressed: onOpen,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OmniClientResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onOpen;

  const OmniClientResultCard({
    super.key,
    required this.data,
    required this.isDark,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final double deuda = (data['deuda_total'] as num?)?.toDouble() ?? 0.0;
    final double saldo = (data['saldo_a_favor'] as num?)?.toDouble() ?? 0.0;
    final String doc = (data['dni_ruc'] ?? '').toString();
    final String phone = (data['telefono'] ?? '').toString();
    final String notes = (data['notas'] ?? '').toString();
    final String rawName = (data['nombre_completo'] ?? '').toString();

    return OmniExpandableCardShell(
      isDark: isDark,
      isExpanded: isExpanded,
      expandedDarkBorder: Colors.indigo.withValues(alpha: 0.5),
      expandedLightBorder: Colors.indigo.shade300,
      onTap: onToggleExpand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isDark
                    ? Colors.indigo[900]
                    : Colors.indigo[100],
                child: Text(
                  rawName.isNotEmpty ? rawName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.indigo[200] : Colors.indigo[900],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rawName.isNotEmpty ? rawName : 'Sin nombre',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Telf: ${phone.isNotEmpty ? phone : 'S/N'}${doc.isNotEmpty ? ' · DNI/RUC: $doc' : ''}",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 115),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (deuda > 0)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            "Debe: ${AppCurrency.format(deuda)}",
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (saldo > 0)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            "A favor: ${AppCurrency.format(saldo)}",
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (deuda <= 0 && saldo <= 0)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            "Al día",
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                ),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onOpen,
                tooltip: "Ver cliente",
              ),
            ],
          ),
          if (isExpanded) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OmniDetailChip(
                  "Nivel Confianza",
                  data['nivel_confianza']?.toString() ?? 'Bueno',
                  isDark,
                ),
                if (doc.isNotEmpty)
                  OmniDetailChip("Documento", doc, isDark, isMonospace: true),
                if (notes.isNotEmpty) OmniDetailChip("Notas", notes, isDark),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.indigo[700]
                      : Colors.indigo[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  elevation: 0,
                ),
                icon: const Icon(Icons.person_pin_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Ver Perfil y Cuenta Corriente",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                onPressed: onOpen,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
