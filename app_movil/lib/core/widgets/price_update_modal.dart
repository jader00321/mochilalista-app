import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class PriceUpdateModal extends StatefulWidget {
  final ProductPresentation presentation;
  final InventoryProvider provider;
  final bool isDark;

  const PriceUpdateModal({
    super.key,
    required this.presentation,
    required this.provider,
    required this.isDark,
  });

  /// 🏆 Despliegue con InteractiveSheetWrapper (Swipe down to dismiss + Blindaje BUG-07)
  static Future<void> show({
    required BuildContext context,
    required ProductPresentation presentation,
    required InventoryProvider provider,
    required bool isDark,
  }) {
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) => PriceUpdateModal(
        presentation: presentation,
        provider: provider,
        isDark: isDark,
      ),
    );
  }

  @override
  State<PriceUpdateModal> createState() => _PriceUpdateModalState();
}

class _PriceUpdateModalState extends State<PriceUpdateModal> {
  late TextEditingController priceCtrl;
  late TextEditingController discountCtrl;
  late int discountType; // 0: % Dscnt, 1: S/ Nuevo
  double? finalOfferPrice;
  double? _activeRoundingTarget;
  String? _preRoundedValor;
  bool isBasePriceUpdate = false;
  String? errorMsg;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    priceCtrl = TextEditingController(
      text: widget.presentation.precioVentaFinal.toStringAsFixed(2),
    );
    discountCtrl = TextEditingController();

    if (widget.presentation.hasOffer) {
      finalOfferPrice = widget.presentation.precioOferta ??
          widget.presentation.effectivePrice;
      discountType = widget.presentation.tipoDescuento == 'monto' ? 1 : 0;
      if (discountType == 0) {
        discountCtrl.text =
            (widget.presentation.valorDescuento ?? 0).toStringAsFixed(0);
      } else {
        discountCtrl.text =
            (widget.presentation.valorDescuento ?? 0).toStringAsFixed(2);
      }
    } else {
      discountType = 0;
    }
  }

  @override
  void dispose() {
    priceCtrl.dispose();
    discountCtrl.dispose();
    super.dispose();
  }

  void _onDiscountInputChanged() {
    _activeRoundingTarget = null;
    _preRoundedValor = null;
    _calculate();
  }

  void _calculate() {
    double base = double.tryParse(priceCtrl.text) ?? 0.0;
    double val = double.tryParse(discountCtrl.text) ?? 0.0;

    if (val <= 0) {
      setState(() {
        finalOfferPrice = null;
        isBasePriceUpdate = false;
        errorMsg = null;
      });
      return;
    }

    if (discountType == 0) {
      if (val >= 100) {
        setState(() {
          finalOfferPrice = null;
          isBasePriceUpdate = false;
          errorMsg = "El porcentaje debe ser menor a 100%";
        });
        return;
      }
      double calc = base * (1 - (val / 100));
      setState(() {
        finalOfferPrice = calc;
        isBasePriceUpdate = false;
        errorMsg = null;
      });
    } else {
      // Modo S/ Nuevo
      if (val >= base) {
        // Precision 4: Tratar como actualización de precio regular, sin error
        setState(() {
          finalOfferPrice = null;
          isBasePriceUpdate = true;
          errorMsg = null;
        });
      } else {
        setState(() {
          finalOfferPrice = val;
          isBasePriceUpdate = false;
          errorMsg = null;
        });
      }
    }
  }

  void _applyQuickPercent(double percent) {
    setState(() {
      discountType = 0;
      _activeRoundingTarget = null;
      _preRoundedValor = null;
      discountCtrl.text = percent.toStringAsFixed(0);
      _calculate();
    });
  }

  void _applyRoundingChip(double targetFraction) {
    double base = double.tryParse(priceCtrl.text) ?? 0.0;
    if (base <= 0) return;
    HapticFeedback.selectionClick();

    final bool isSameActive = _activeRoundingTarget != null &&
        ((_activeRoundingTarget! - targetFraction).abs() < 0.01 ||
            ((_activeRoundingTarget! == 1.00 ||
                    _activeRoundingTarget! == 0.00) &&
                (targetFraction == 1.00 || targetFraction == 0.00)));

    if (isSameActive) {
      if (_preRoundedValor != null) {
        discountCtrl.text = _preRoundedValor!;
      }
      _activeRoundingTarget = null;
      _preRoundedValor = null;
      _calculate();
      return;
    }

    _preRoundedValor ??= discountCtrl.text.trim();

    double currentOffer = finalOfferPrice ?? (base * 0.90);
    if (currentOffer <= 0 || currentOffer >= base) {
      currentOffer = base * 0.90;
    }

    double floor = currentOffer.floorToDouble();
    double roundedOffer;

    if (targetFraction == 0.50) {
      roundedOffer = floor + 0.50;
    } else if (targetFraction == 0.90) {
      roundedOffer = floor + 0.90;
    } else if (targetFraction == 1.00 || targetFraction == 0.00) {
      roundedOffer = floor;
    } else {
      roundedOffer = currentOffer;
    }

    if (roundedOffer >= base) {
      roundedOffer = (base - 0.10) > 0 ? (base - 0.10) : 0.50;
    }
    if (roundedOffer <= 0) {
      roundedOffer = 0.50;
    }

    if (discountType == 0) {
      double newPercent = ((base - roundedOffer) / base) * 100;
      discountCtrl.text = newPercent.toStringAsFixed(2);
    } else {
      discountCtrl.text = roundedOffer.toStringAsFixed(2);
    }

    _activeRoundingTarget = targetFraction;
    finalOfferPrice = roundedOffer;
    isBasePriceUpdate = false;
    errorMsg = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final double currentBase = double.tryParse(priceCtrl.text) ?? 0.0;
    final double val = double.tryParse(discountCtrl.text) ?? 0.0;
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    final double effectiveTargetPrice = isBasePriceUpdate
        ? val
        : (finalOfferPrice ?? currentBase);

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.92,
      backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
      applyEffectiveBottomPadding: true,
      icon: Icons.attach_money,
      iconColor: widget.isDark ? Colors.green[300] : Colors.green[700],
      titleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Gestionar Precio",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: textColor,
              fontSize: 18,
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
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.close,
            color: widget.isDark ? Colors.grey[500] : Colors.grey,
          ),
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
      bottomAction: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                widget.isDark ? Colors.blue[300] : Colors.blue[800],
            foregroundColor: widget.isDark ? Colors.black87 : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          onPressed: (errorMsg != null || _isSaving)
              ? null
              : () async {
                  setState(() => _isSaving = true);
                  if (discountType == 1 && val >= currentBase && val > 0) {
                    // Precision 4: Limpieza completa de oferta al subir el precio base
                    await widget.provider.updatePresentation(
                      widget.presentation.id!,
                      precioVentaFinal: val,
                      oferta: -1,
                      tipoDesc: 'ninguno',
                      valorDesc: 0.0,
                    );
                  } else if (finalOfferPrice != null &&
                      finalOfferPrice! > 0 &&
                      finalOfferPrice! < currentBase) {
                    await widget.provider.updatePresentation(
                      widget.presentation.id!,
                      precioVentaFinal: double.tryParse(priceCtrl.text),
                      oferta: finalOfferPrice,
                      tipoDesc: discountType == 0 ? 'porcentaje' : 'monto',
                      valorDesc: val,
                    );
                  } else {
                    // Sin oferta o se quitó la oferta
                    await widget.provider.updatePresentation(
                      widget.presentation.id!,
                      precioVentaFinal: double.tryParse(priceCtrl.text),
                      oferta: -1,
                      tipoDesc: 'ninguno',
                      valorDesc: 0.0,
                    );
                  }
                  if (context.mounted) Navigator.pop(context);
                },
          child: _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text(
                  "APLICAR CAMBIOS",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
                setState(() {});
                _calculate();
              },
            ),

            // 🔧 Calculadora de margen en tiempo real
            Builder(
              builder: (_) {
                final double costoPresentacion =
                    widget.presentation.costoPresentacionFinal;

                if (costoPresentacion <= 0) return const SizedBox.shrink();
                if (effectiveTargetPrice <= 0) return const SizedBox.shrink();

                final double ganancia = effectiveTargetPrice - costoPresentacion;
                final double margenPercent =
                    ((effectiveTargetPrice - costoPresentacion) /
                            effectiveTargetPrice) *
                        100;

                final Color marginColor = margenPercent >= 20
                    ? (widget.isDark ? Colors.green[400]! : Colors.green[700]!)
                    : (margenPercent >= 10
                        ? (widget.isDark
                            ? Colors.amber[400]!
                            : Colors.amber[800]!)
                        : (widget.isDark
                            ? Colors.red[400]!
                            : Colors.red[700]!));

                return Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: marginColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: marginColor.withValues(alpha: 0.35)),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  "Ganancia: S/ ${ganancia.toStringAsFixed(2)}",
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
                              "Costo estimado: S/ ${costoPresentacion.toStringAsFixed(2)}",
                              style: TextStyle(
                                color: widget.isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                color: widget.isDark
                    ? const Color(0xFF14141C)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      label: "% Dscnt",
                      selected: discountType == 0,
                      isDark: widget.isDark,
                      onTap: () {
                        setState(() => discountType = 0);
                        _calculate();
                      },
                    ),
                  ),
                  Expanded(
                    child: _TabButton(
                      label: "S/ Nuevo",
                      selected: discountType == 1,
                      isDark: widget.isDark,
                      onTap: () {
                        setState(() => discountType = 1);
                        _calculate();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: TextField(
                controller: discountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                scrollPadding: const EdgeInsets.only(bottom: 90),
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: discountType == 0
                      ? "Porcentaje de Oferta (%)"
                      : "Nuevo Precio (S/)",
                  labelStyle: TextStyle(
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color:
                          widget.isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color:
                          widget.isDark ? Colors.white24 : Colors.grey.shade300,
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
                  suffixStyle: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onChanged: (_) => _onDiscountInputChanged(),
              ),
            ),

            // Banner explicativo si se ingresó un precio regular mayor en S/ Nuevo
            if (isBasePriceUpdate && val > 0) ...[
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? Colors.blue.withValues(alpha: 0.15)
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isDark
                        ? Colors.blue.shade400
                        : Colors.blue.shade300,
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
                          color: widget.isDark
                              ? Colors.blue[300]
                              : Colors.blue[800],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Nuevo Precio Base de Venta: S/ ${currentBase.toStringAsFixed(2)} ➔ S/ ${val.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: widget.isDark
                                  ? Colors.blue[200]
                                  : Colors.blue[900],
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
                        color: widget.isDark
                            ? Colors.grey[400]
                            : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Accesos rápidos por porcentaje
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

            // Redondeo rápido de oferta (.50, .90, .00)
            if (finalOfferPrice != null && finalOfferPrice! < currentBase) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    "Redondear oferta:",
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isDark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _QuickChip(
                    label: ".50",
                    isDark: widget.isDark,
                    isActive: _activeRoundingTarget == 0.50,
                    onTap: () => _applyRoundingChip(0.50),
                  ),
                  const SizedBox(width: 8),
                  _QuickChip(
                    label: ".90",
                    isDark: widget.isDark,
                    isActive: _activeRoundingTarget == 0.90,
                    onTap: () => _applyRoundingChip(0.90),
                  ),
                  const SizedBox(width: 8),
                  _QuickChip(
                    label: ".00",
                    isDark: widget.isDark,
                    isActive: _activeRoundingTarget == 1.00 ||
                        _activeRoundingTarget == 0.00,
                    onTap: () => _applyRoundingChip(1.00),
                  ),
                ],
              ),
            ],

            // Preview del precio de oferta
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: finalOfferPrice != null &&
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
                              color: widget.isDark
                                  ? Colors.green[300]
                                  : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "S/ ${currentBase.toStringAsFixed(2)}",
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Icon(
                                  Icons.arrow_right_alt,
                                  color: widget.isDark
                                      ? Colors.green[300]
                                      : Colors.green,
                                ),
                              ),
                              Text(
                                "S/ ${finalOfferPrice!.toStringAsFixed(2)}",
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
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () => setState(() {
                              finalOfferPrice = null;
                              discountCtrl.clear();
                              _activeRoundingTarget = null;
                              _preRoundedValor = null;
                              isBasePriceUpdate = false;
                              errorMsg = null;
                            }),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              "Quitar Oferta",
                              style: TextStyle(
                                color: widget.isDark
                                    ? Colors.red[300]
                                    : Colors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ],
        ),
      ),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
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
