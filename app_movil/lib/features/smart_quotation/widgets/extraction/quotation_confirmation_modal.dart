import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';

/// ⚡ MODAL DINÁMICO Y ANIMADO DE CONFIRMACIÓN PRE-COTIZACIÓN
/// Desplegado al presionar el botón `COTIZAR (X/Y)` en Datos Extraídos.
/// Permite al comerciante revisar el resumen del lote y confirmar el enfoque
/// de stock (Precio Público / Menudeo vs. Priorizar Mayorista / Cajas).
class QuotationConfirmationModal extends StatefulWidget {
  final int totalItems;
  final int readyItems;
  final int zeroOrEmptyItems;
  final QuotationContextMode currentMode;
  final bool isClientRole;
  final void Function(bool prioritizeWholesale, QuotationContextMode selectedMode) onConfirm;

  const QuotationConfirmationModal({
    super.key,
    required this.totalItems,
    required this.readyItems,
    required this.zeroOrEmptyItems,
    required this.currentMode,
    this.isClientRole = false,
    required this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required int totalItems,
    required int readyItems,
    required int zeroOrEmptyItems,
    required QuotationContextMode currentMode,
    bool isClientRole = false,
    required void Function(bool prioritizeWholesale, QuotationContextMode selectedMode) onConfirm,
  }) {
    HapticFeedback.mediumImpact();
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Cerrar modal de confirmación",
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.90, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, __) {
        return QuotationConfirmationModal(
          totalItems: totalItems,
          readyItems: readyItems,
          zeroOrEmptyItems: zeroOrEmptyItems,
          currentMode: currentMode,
          isClientRole: isClientRole,
          onConfirm: onConfirm,
        );
      },
    );
  }

  @override
  State<QuotationConfirmationModal> createState() => _QuotationConfirmationModalState();
}

class _QuotationConfirmationModalState extends State<QuotationConfirmationModal> {
  late bool _prioritizeWholesale;
  late QuotationContextMode _selectedMode;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.currentMode;
    _prioritizeWholesale = widget.currentMode == QuotationContextMode.wholesale;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bool allReady = widget.zeroOrEmptyItems == 0 && widget.readyItems == widget.totalItems;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade300,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cabecera con Icono Destacado (Fijo Arriba)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: isDark ? 0.25 : 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: 26,
                            color: isDark ? Colors.blue[300] : Colors.blue[800],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Generar Cotización",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 19,
                                  color: textColor,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Resumen del lote y enfoque de stock",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Contenido Central Escrolleable y Flexible para Pantallas Compactas
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [

                    // Resumen Visual del Lote (Fase 3)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: allReady
                            ? (isDark ? Colors.green[900]!.withValues(alpha: 0.22) : Colors.green.shade50)
                            : (isDark ? Colors.orange[900]!.withValues(alpha: 0.22) : Colors.orange.shade50),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: allReady
                              ? (isDark ? Colors.green[600]!.withValues(alpha: 0.5) : Colors.green.shade300)
                              : (isDark ? Colors.orange[600]!.withValues(alpha: 0.5) : Colors.orange.shade300),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            allReady ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                            color: allReady
                                ? (isDark ? Colors.green[300] : Colors.green[800])
                                : (isDark ? Colors.orange[300] : Colors.orange[800]),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Vas a cotizar ${widget.readyItems} de ${widget.totalItems} productos",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    color: allReady
                                        ? (isDark ? Colors.green[200] : Colors.green[900])
                                        : (isDark ? Colors.orange[200] : Colors.orange[900]),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  allReady
                                      ? "Todos los productos tienen descripción y cantidad válida."
                                      : "Dejaste ${widget.zeroOrEmptyItems} producto(s) sin nombre o con cantidad 0.",
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.35,
                                    color: allReady
                                        ? (isDark ? Colors.green[300] : Colors.green[800])
                                        : (isDark ? Colors.orange[300] : Colors.orange[900]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Selector Rápido de Enfoque de Precios y Presentaciones (Fase 3)
                    Text(
                      "¿CÓMO DESEAS BUSCAR EN EL INVENTARIO?",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Opción 1: Menudeo / Unidad
                    _buildStrategyOption(
                      isSelected: !_prioritizeWholesale,
                      icon: Icons.sell_outlined,
                      title: "🏷️ Precio Público / Menudeo",
                      description: "Ideal para compras al detalle, pedidos familiares o listas escolares.",
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _prioritizeWholesale = false);
                      },
                    ),

                    const SizedBox(height: 10),

                    // Opción 2: Mayorista / Cajas / Bultos
                    _buildStrategyOption(
                      isSelected: _prioritizeWholesale,
                      icon: Icons.inventory_2_outlined,
                      title: "📦 Priorizar Mayorista / Cajas / Paquetes",
                      description: "Prioriza presentaciones por volumen (cajas, paquetes, packs, fardos, docenas).",
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _prioritizeWholesale = true);
                      },
                    ),

                    const SizedBox(height: 14),

                    // Explicación amigable
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: isDark ? Colors.blue[300] : Colors.blue[800]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "El sistema vinculará automáticamente tus productos y calculará los mejores precios disponibles.",
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.35,
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Botones de Acción (Fijos y Siempre Accesibles Abajo)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: isDark ? Colors.grey[300] : Colors.grey[700],
                      side: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade400,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Revisar",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      Navigator.pop(context);
                      widget.onConfirm(_prioritizeWholesale, _selectedMode);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "Sí, Cotizar →",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ),
),
),
);
  }

  Widget _buildStrategyOption({
    required bool isSelected,
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final activeColor = isDark ? Colors.blue[400]! : Colors.blue[800]!;
    final cardBg = isSelected
        ? (isDark ? Colors.blue.withValues(alpha: 0.18) : Colors.blue.shade50)
        : (isDark ? const Color(0xFF161622) : Colors.grey.shade50);
    final borderColor = isSelected
        ? activeColor
        : (isDark ? Colors.white12 : Colors.grey.shade300);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected ? 1.8 : 1.0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20,
                color: isSelected ? activeColor : (isDark ? Colors.grey[500] : Colors.grey[400]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected
                          ? (isDark ? Colors.blue[200] : Colors.blue[900])
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

