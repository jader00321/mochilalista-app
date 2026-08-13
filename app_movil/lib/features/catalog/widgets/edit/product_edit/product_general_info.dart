import 'package:flutter/material.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/core/widgets/custom_text_field.dart';
import 'package:app_movil/core/widgets/safe_dropdown.dart';

class ProductGeneralInfo extends StatelessWidget {
  final TextEditingController nameCtrl;
  final int? selectedBrandId;
  final int? selectedCategoryId;
  final int? generalProviderId;
  final int generalState;
  final List<Brand> brandListForDropdown;
  final List<Category> categoryListForDropdown;
  final List<ProviderModel> providerListForDropdown;
  final bool isDark;
  
  final Function(int?) onBrandChanged;
  final Function(int?) onCategoryChanged;
  final Function(int?) onProviderChanged;
  final Function(int) onStateChanged;

  const ProductGeneralInfo({
    super.key,
    required this.nameCtrl,
    required this.selectedBrandId,
    required this.selectedCategoryId,
    required this.generalProviderId,
    required this.generalState,
    required this.brandListForDropdown,
    required this.categoryListForDropdown,
    required this.providerListForDropdown,
    required this.isDark,
    required this.onBrandChanged,
    required this.onCategoryChanged,
    required this.onProviderChanged,
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
        border: Border.all(color: isDark ? Colors.white10 : Colors.blue.withValues(alpha: 0.15)), 
        boxShadow: [if(!isDark) BoxShadow(color: Colors.blue.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity, 
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue[50], borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(children: [
              Icon(Icons.info_outline, color: isDark ? Colors.blue[300] : Colors.blue[800], size: 20), 
              const SizedBox(width: 10), 
              Text("Información General", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[100] : Colors.blue[900]))
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CustomTextField(label: "Nombre del Producto *", icon: Icons.edit, controller: nameCtrl, maxLines: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SafeDropdown<Brand>(
                        label: "Marca", 
                        icon: Icons.branding_watermark_outlined, 
                        value: selectedBrandId, 
                        items: brandListForDropdown, 
                        getId: (b) => b.id, 
                        getName: (b) => b.nombre, 
                        isActive: (b) => b.activo == true, 
                        onChanged: onBrandChanged
                      )
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SafeDropdown<Category>(
                        label: "Categoría", 
                        icon: Icons.category_outlined, 
                        value: selectedCategoryId, 
                        items: categoryListForDropdown, 
                        getId: (c) => c.id, 
                        getName: (c) => c.nombre, 
                        isActive: (c) => c.activo == true, 
                        onChanged: onCategoryChanged
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SafeDropdown<ProviderModel>(
                  label: "Proveedor General", 
                  icon: Icons.local_shipping_outlined, 
                  value: generalProviderId, 
                  items: providerListForDropdown, 
                  getId: (p) => p.id, 
                  getName: (p) => p.nombreEmpresa, 
                  isActive: (p) => p.activo == true, 
                  onChanged: onProviderChanged
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12), 
                  decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.visibility, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]), 
                        const SizedBox(width: 8), 
                        Text("Visibilidad de Variantes", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor))
                      ]),
                      const SizedBox(height: 12),
                      _buildSuperSwitch(isDark),
                    ],
                  ),
                )
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
            child: Text("Estado actual: Variado (Seleccione uno para unificar)", style: TextStyle(fontSize: 12, color: isDark ? Colors.orange[300] : Colors.orange[800], fontStyle: FontStyle.italic)),
          ),
        Container(
          height: 42,
          decoration: BoxDecoration(color: isDark ? const Color(0xFF14141C) : Colors.grey[200], borderRadius: BorderRadius.circular(12)),
          child: Stack(
            children: [
              AnimatedAlign(
                alignment: current == 0 ? Alignment.centerLeft : (current == 2 ? Alignment.centerRight : Alignment.center),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: current == 1 
                    ? const SizedBox.shrink() 
                    : FractionallySizedBox(
                        widthFactor: 0.5, 
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: current == 0 ? (isDark ? Colors.orange[800] : Colors.white) : (isDark ? Colors.green[700] : Colors.white),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: !isDark ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))] : [],
                          ),
                        ),
                      ),
              ),
              Row(
                children: [
                  Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onStateChanged(0), child: Center(child: Text("Ocultar Todos", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: current == 0 ? (isDark ? Colors.white : Colors.orange[800]) : Colors.grey))))),
                  Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onStateChanged(2), child: Center(child: Text("Publicar Todos", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: current == 2 ? (isDark ? Colors.white : Colors.green[700]) : Colors.grey))))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}