import 'package:flutter/material.dart';
import 'image_picker_field.dart';
import 'custom_text_field.dart';
import 'barcode_input_field.dart';

class ProductOptionalInfo extends StatelessWidget {
  final TextEditingController descCtrl;
  final TextEditingController imgCtrl;
  final TextEditingController barcodeCtrl;

  const ProductOptionalInfo({
    super.key, 
    required this.descCtrl, 
    required this.imgCtrl, 
    required this.barcodeCtrl
  });
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300)
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: isDark ? Colors.white : Colors.black87,
          collapsedIconColor: isDark ? Colors.white70 : Colors.grey,
          title: Text("Detalles Globales (Opcional)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
          subtitle: Text("Imagen, código y descripción por defecto", style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            padding: const EdgeInsets.all(10), 
            decoration: BoxDecoration(color: isDark ? Colors.orange.withOpacity(0.15) : Colors.orange[50], borderRadius: BorderRadius.circular(10)), 
            child: Icon(Icons.settings_overscan, color: isDark ? Colors.orange[300] : Colors.orange[800], size: 24)
          ),
          children: [
            ImagePickerField(controller: imgCtrl, label: "Imagen Global del Producto", isDark: isDark),
            const SizedBox(height: 20),
            CustomTextField(label: "Descripción Global", controller: descCtrl, maxLines: 3, icon: Icons.description),
            const SizedBox(height: 20),
            BarcodeInputField(controller: barcodeCtrl, label: "Código de Barras Global"),
          ],
        ),
      ),
    );
  }
}