import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

class ManualPriceModifier extends StatefulWidget {
  final bool isManualPrice;
  final double systemPrice;
  final TextEditingController discountCtrl;
  final TextEditingController priceCtrl;
  final FocusNode? discountFocusNode;
  final Function(bool) onToggle;
  final Function(String) onDiscountChanged;
  final Function(String) onPriceChanged;
  final bool? isDark;
  final NumberFormat? currency;
  final VoidCallback? onEditCatalogPrice;
  final VoidCallback? onRestoreCatalogOffer;
  final bool catalogHasOffer;
  final double? catalogOfferPrice;
  final int catalogDiscountPercent;
  final bool isCustomPrice;

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
    this.isDark,
    this.currency,
    this.onEditCatalogPrice,
    this.onRestoreCatalogOffer,
    this.catalogHasOffer = false,
    this.catalogOfferPrice,
    this.catalogDiscountPercent = 0,
    this.isCustomPrice = false,
  });

  @override
  State<ManualPriceModifier> createState() => _ManualPriceModifierState();
}

class _ManualPriceModifierState extends State<ManualPriceModifier> {
  late bool _isCustomExpanded;

  @override
  void initState() {
    super.initState();
    // Inicia por defecto en Estado Compacto Activo (_isCustomExpanded = false)
    _isCustomExpanded = false;
  }

  @override
  void didUpdateWidget(covariant ManualPriceModifier oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Detalle inteligente: Si el producto NO tiene oferta en BD y el usuario activa el switch manualmente,
    // auto-desplegar para que pueda escribir el monto de inmediato.
    if (!oldWidget.isManualPrice && widget.isManualPrice && !widget.catalogHasOffer) {
      _isCustomExpanded = true;
    } else if (oldWidget.isManualPrice && !widget.isManualPrice) {
      _isCustomExpanded = false;
    }
  }

  void _handleSwitchToggle(bool value) {
    if (value && !widget.catalogHasOffer) {
      setState(() {
        _isCustomExpanded = true;
      });
    } else if (!value) {
      FocusScope.of(context).unfocus();
      setState(() {
        _isCustomExpanded = false;
      });
    }
    widget.onToggle(value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final textColor = isDark ? Colors.white : Colors.black87;

    String? badgeText;
    Color? badgeBgColor;
    Color? badgeTextColor;
    Color? badgeBorderColor;

    if (widget.catalogHasOffer && widget.catalogOfferPrice != null) {
      if (!widget.isManualPrice) {
        badgeText = "🚫 Oferta desactivada para esta operación";
        badgeBgColor = isDark ? Colors.blueGrey.withValues(alpha: 0.25) : Colors.blueGrey.shade50;
        badgeTextColor = isDark ? Colors.blueGrey[200]! : Colors.blueGrey[800]!;
        badgeBorderColor = isDark ? Colors.blueGrey.withValues(alpha: 0.4) : Colors.blueGrey.shade200;
      } else if (widget.isCustomPrice) {
        badgeText = "✨ Descuento Especial (Solo aquí)";
        badgeBgColor = isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange.shade50;
        badgeTextColor = isDark ? Colors.orange[300]! : Colors.orange[900]!;
        badgeBorderColor = isDark ? Colors.orange.withValues(alpha: 0.4) : Colors.orange.shade300;
      } else {
        badgeText = "📦 Oferta de Catálogo";
        badgeBgColor = isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.shade50;
        badgeTextColor = isDark ? Colors.green[300]! : Colors.green[800]!;
        badgeBorderColor = isDark ? Colors.green.withValues(alpha: 0.4) : Colors.green.shade300;
      }
    } else if (widget.isManualPrice) {
      badgeText = "✨ Descuento Especial (Solo aquí)";
      badgeBgColor = isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange.shade50;
      badgeTextColor = isDark ? Colors.orange[300]! : Colors.orange[900]!;
      badgeBorderColor = isDark ? Colors.orange.withValues(alpha: 0.4) : Colors.orange.shade300;
    }

    return Container(
      decoration: BoxDecoration(
        color: widget.isManualPrice
            ? (isDark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange[50])
            : (isDark ? Colors.white10 : Colors.grey[50]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isManualPrice
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
                          color: widget.isManualPrice
                              ? (isDark ? Colors.orange[300] : Colors.orange[800])
                              : (isDark ? Colors.grey[400] : Colors.grey[700]),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Aplicar Descuento",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: widget.isManualPrice
                                ? (isDark ? Colors.orange[300] : Colors.orange[900])
                                : textColor,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: widget.isManualPrice,
                      activeThumbColor: Colors.orange,
                      onChanged: _handleSwitchToggle,
                    ),
                  ],
                ),
                if (badgeText != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: badgeBgColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeBorderColor!),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: badgeTextColor,
                          ),
                        ),
                      ),
                      if (widget.catalogHasOffer &&
                          widget.catalogOfferPrice != null &&
                          widget.isCustomPrice &&
                          widget.isManualPrice)
                        InkWell(
                          onTap: () {
                            if (widget.onRestoreCatalogOffer != null) {
                              widget.onRestoreCatalogOffer!();
                            } else {
                              final offerPriceStr = widget.catalogOfferPrice!.toStringAsFixed(2);
                              final disc = (widget.systemPrice - widget.catalogOfferPrice!).clamp(0.0, double.infinity);
                              final discStr = disc > 0 ? disc.toStringAsFixed(2) : "";
                              widget.priceCtrl.text = offerPriceStr;
                              widget.discountCtrl.text = discStr;
                              widget.onPriceChanged(offerPriceStr);
                              widget.onDiscountChanged(discStr);
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.blue.withValues(alpha: 0.18) : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark ? Colors.blue.withValues(alpha: 0.4) : Colors.blue.shade300,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded, size: 12, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                                const SizedBox(width: 3),
                                Text(
                                  "↺ Usar oferta de catálogo",
                                  style: TextStyle(
                                    fontSize: 10.5,
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
                ],
                const SizedBox(height: 8),
                // Nivel 2: Precio Reactivo (a 0ms por pulsación de tecla) + Botón Editar Catálogo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: ListenableBuilder(
                        listenable: Listenable.merge([widget.priceCtrl, widget.discountCtrl]),
                        builder: (context, _) {
                          // Si el switch está apagado: Mostrar siempre "Precio Base: S/ X"
                          if (!widget.isManualPrice) {
                            return Text(
                              "Precio Base: ${AppCurrency.format(widget.systemPrice)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                              ),
                            );
                          }

                          // Si el switch está encendido: Calcular precio activo en tiempo real
                          final priceVal = double.tryParse(widget.priceCtrl.text.replaceAll(',', '.'));
                          final discVal = double.tryParse(widget.discountCtrl.text.replaceAll(',', '.'));

                          double activePrice;
                          if (priceVal != null && priceVal > 0) {
                            activePrice = priceVal;
                          } else if (discVal != null && discVal > 0) {
                            activePrice = (widget.systemPrice - discVal).clamp(0.0, double.infinity);
                          } else if (widget.catalogHasOffer && widget.catalogOfferPrice != null) {
                            activePrice = widget.catalogOfferPrice!;
                          } else {
                            activePrice = widget.systemPrice;
                          }

                          final bool hasDiscount = (widget.systemPrice > 0) && (activePrice < widget.systemPrice);

                          if (hasDiscount) {
                            final int percent = (((widget.systemPrice - activePrice) / widget.systemPrice) * 100).round();
                            return Row(
                              children: [
                                Text(
                                  AppCurrency.format(widget.systemPrice),
                                  style: TextStyle(
                                    fontSize: 12,
                                    decoration: TextDecoration.lineThrough,
                                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  AppCurrency.format(activePrice),
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
                                    "-$percent%",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.green[300] : Colors.green[800],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return Text(
                              "Precio Base: ${AppCurrency.format(widget.systemPrice)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    if (widget.onEditCatalogPrice != null)
                      InkWell(
                        onTap: widget.onEditCatalogPrice,
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
          if (widget.isManualPrice) ...[
            Divider(height: 1, color: isDark ? Colors.orange.withValues(alpha: 0.3) : Colors.orange[200]),
            InkWell(
              onTap: () {
                if (_isCustomExpanded) {
                  FocusScope.of(context).unfocus();
                }
                setState(() {
                  _isCustomExpanded = !_isCustomExpanded;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isCustomExpanded ? "Modificar monto o precio unitario" : "Personalizar descuento u oferta",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.orange[200] : Colors.orange[800],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isCustomExpanded ? "Contraer" : "Personalizar",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.orange[300] : Colors.orange[900],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _isCustomExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          size: 16,
                          color: isDark ? Colors.orange[300] : Colors.orange[900],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _isCustomExpanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
                                    focusNode: widget.discountFocusNode,
                                    controller: widget.discountCtrl,
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
                                    onChanged: widget.onDiscountChanged,
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
                                    controller: widget.priceCtrl,
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
                                    onChanged: widget.onPriceChanged,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}
