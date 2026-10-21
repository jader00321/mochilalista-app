import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/barcode_input_field.dart';
import 'package:app_movil/core/widgets/image_picker_field.dart';
import 'package:app_movil/core/widgets/custom_text_field.dart';

/// Sección de Detalles Avanzados para la tarjeta de presentación.
/// Incluye campo con escáner de código de barras, selector de imagen,
/// selector interactivo de proveedor y descripción específica.
class PresentationAdvancedSection extends StatelessWidget {
  final TextEditingController barcodeCtrl;
  final TextEditingController imageCtrl;
  final TextEditingController descCtrl;
  final Widget providerDropdown;
  final bool isDark;

  const PresentationAdvancedSection({
    super.key,
    required this.barcodeCtrl,
    required this.imageCtrl,
    required this.descCtrl,
    required this.providerDropdown,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: barcodeCtrl.text.isNotEmpty,
        title: Text(
          "Detalles Avanzados (Foto, Código, Proveedor)",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.blue[300] : Colors.blue,
          ),
        ),
        iconColor: isDark ? Colors.blue[300] : Colors.blue,
        collapsedIconColor: isDark ? Colors.blue[300] : Colors.blue,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.symmetric(vertical: 10),
        children: [
          BarcodeInputField(
            controller: barcodeCtrl,
            label: "Código de Barras Específico",
          ),
          const SizedBox(height: 16),
          ImagePickerField(
            controller: imageCtrl,
            label: "Imagen Específica",
            isDark: isDark,
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
            child: providerDropdown,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: "Descripción Específica",
            controller: descCtrl,
            maxLines: 2,
            icon: Icons.description_outlined,
          ),
        ],
      ),
    );
  }
}
