import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/smart_unit_selector.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_custom_field.dart';

/// Sección de Datos de Compra / Factura para la tarjeta de presentación.
/// Permite ingresar unidad de compra, factor de lote, cantidad de lotes y total pagado
/// para el cálculo automático de costos unitarios.
class PresentationPurchaseSection extends StatelessWidget {
  final TextEditingController umpCompraCtrl;
  final TextEditingController unidadesLoteCtrl;
  final TextEditingController cantCompraCtrl;
  final TextEditingController totalPagoCtrl;
  final bool isEditMode;
  final bool isDark;
  final void Function(String unitName, int factor, bool isAutomatic) onUmpChanged;
  final VoidCallback onCantCompraChanged;
  final VoidCallback onTotalPagoChanged;

  const PresentationPurchaseSection({
    super.key,
    required this.umpCompraCtrl,
    required this.unidadesLoteCtrl,
    required this.cantCompraCtrl,
    required this.totalPagoCtrl,
    required this.isEditMode,
    required this.isDark,
    required this.onUmpChanged,
    required this.onCantCompraChanged,
    required this.onTotalPagoChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          "Datos de Compra / Factura (Opcional)",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.teal[300] : Colors.teal[800],
          ),
        ),
        iconColor: isDark ? Colors.teal[300] : Colors.teal[800],
        collapsedIconColor: isDark ? Colors.teal[300] : Colors.teal[800],
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 0,
        ),
        childrenPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 12,
        ),
        collapsedBackgroundColor: isDark
            ? Colors.teal.withValues(alpha: 0.05)
            : Colors.teal[50],
        backgroundColor: isDark
            ? Colors.teal.withValues(alpha: 0.05)
            : Colors.teal[50],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        children: [
          Text(
            isEditMode
                ? "Datos de referencia de la factura actual. En modo edición, estos datos no alteran el stock automáticamente."
                : "Si llenas estos datos, calcularemos tu Costo y Stock automáticamente.",
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: SmartUnitSelector(
                  unitCtrl: umpCompraCtrl,
                  factorCtrl: unidadesLoteCtrl,
                  isDark: isDark,
                  onChanged: onUmpChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Cant. Lotes",
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: cantCompraCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        onChanged: (_) => onCantCompraChanged(),
                        decoration: InputDecoration(
                          hintText: "10.5",
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white24 : Colors.black26,
                            fontSize: 13,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF14141C)
                              : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark ? Colors.teal[400]! : Colors.teal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: MiniInput(
                  ctrl: totalPagoCtrl,
                  label: "Total Pagado (S/)",
                  isNum: true,
                  hint: "0.0",
                  isBold: true,
                  isDark: isDark,
                  onChanged: onTotalPagoChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
