import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/custom_text_field.dart';
import 'package:app_movil/core/widgets/modern_entity_selector_field.dart';

class ProductGeneralInfo extends StatelessWidget {
  final TextEditingController nameCtrl;
  final String brandDisplay;
  final bool isBrandDeferred;
  final VoidCallback onSelectBrand;
  final String categoryDisplay;
  final bool isCategoryDeferred;
  final VoidCallback onSelectCategory;
  final String generalProviderDisplay;
  final bool isGeneralProviderDeferred;
  final VoidCallback onSelectGeneralProvider;
  final int generalState;
  final bool isDark;
  final Function(int) onStateChanged;

  const ProductGeneralInfo({
    super.key,
    required this.nameCtrl,
    required this.brandDisplay,
    required this.isBrandDeferred,
    required this.onSelectBrand,
    required this.categoryDisplay,
    required this.isCategoryDeferred,
    required this.onSelectCategory,
    required this.generalProviderDisplay,
    required this.isGeneralProviderDeferred,
    required this.onSelectGeneralProvider,
    required this.generalState,
    required this.isDark,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? const Color(0xFF1A1A24) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.blue.withValues(alpha: 0.15),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.blue.withValues(alpha: 0.15)
                  : Colors.blue[50],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: isDark ? Colors.blue[300] : Colors.blue[800],
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  "Información General",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.blue[100] : Colors.blue[900],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CustomTextField(
                  label: "Nombre del Producto *",
                  icon: Icons.edit,
                  controller: nameCtrl,
                  maxLines: 1,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ModernEntitySelectorField(
                        label: "Marca",
                        valueText: brandDisplay,
                        icon: Icons.branding_watermark_outlined,
                        isDeferred: isBrandDeferred,
                        isDark: isDark,
                        onTap: onSelectBrand,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ModernEntitySelectorField(
                        label: "Categoría",
                        valueText: categoryDisplay,
                        icon: Icons.category_outlined,
                        isDeferred: isCategoryDeferred,
                        isDark: isDark,
                        onTap: onSelectCategory,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ModernEntitySelectorField(
                  label: "Proveedor General",
                  valueText: generalProviderDisplay,
                  icon: Icons.local_shipping_outlined,
                  isDeferred: isGeneralProviderDeferred,
                  isDark: isDark,
                  onTap: onSelectGeneralProvider,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            size: 16,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Visibilidad de Variantes",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSuperSwitch(isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuperSwitch(bool isDark) {
    int current = generalState;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (current == 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              "Estado actual: Variado (Seleccione uno para unificar)",
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.orange[300] : Colors.orange[800],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14141C) : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                alignment: current == 0
                    ? Alignment.centerLeft
                    : (current == 2 ? Alignment.centerRight : Alignment.center),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: current == 1
                    ? const SizedBox.shrink()
                    : FractionallySizedBox(
                        widthFactor: 0.5,
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: current == 0
                                ? (isDark ? Colors.orange[800] : Colors.white)
                                : (isDark ? Colors.green[700] : Colors.white),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: !isDark
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                        ),
                      ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onStateChanged(0),
                      child: Center(
                        child: Text(
                          "Ocultar Todos",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: current == 0
                                ? (isDark ? Colors.white : Colors.orange[800])
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onStateChanged(2),
                      child: Center(
                        child: Text(
                          "Publicar Todos",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: current == 2
                                ? (isDark ? Colors.white : Colors.green[700])
                                : Colors.grey,
                          ),
                        ),
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
