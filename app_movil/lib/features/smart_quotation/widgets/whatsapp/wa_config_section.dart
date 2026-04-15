import 'package:flutter/material.dart';
import '../../models/whatsapp_config_model.dart';

class WaConfigSection extends StatelessWidget {
  final WhatsAppConfig config;
  final bool isSale; 
  final VoidCallback onChanged;

  const WaConfigSection({
    super.key, 
    required this.config, 
    required this.isSale, 
    required this.onChanged
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;

    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          iconColor: isDark ? Colors.white : Colors.black87,
          collapsedIconColor: isDark ? Colors.white70 : Colors.grey,
          title: Row(children: [Icon(Icons.tune, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey, size: 24), const SizedBox(width: 10), Text("Personalizar Mensaje", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black87))]),
          children: [
            _buildSwitchTile("Precios y Subtotales", config.showSubtotals, isDark, (v) { config.showSubtotals = v; onChanged(); }),
            _buildSwitchTile("Sección de Ahorro", config.showSavingsSection, isDark, (v) { config.showSavingsSection = v; onChanged(); }),
            if (config.showSavingsSection)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _buildSwitchTile("Detalle por Producto (Antes/Ahora)", config.showDiscountDetail, isDark, (v) { config.showDiscountDetail = v; onChanged(); }, isSubOption: true),
              ),
            _buildSwitchTile("Monto Total S/.", config.showTotalGlobal, isDark, (v) { config.showTotalGlobal = v; onChanged(); }),
            
            if (isSale) ...[
              Divider(indent: 20, endIndent: 20, color: isDark ? Colors.white10 : Colors.grey[200]),
              _buildSwitchTile("Información de Saldo Pendiente", config.showDebtInfo, isDark, (v) { config.showDebtInfo = v; onChanged(); }),
              _buildSwitchTile("Estado de Entrega / Fecha", config.showDeliveryInfo, isDark, (v) { config.showDeliveryInfo = v; onChanged(); }),
            ],

            Divider(indent: 20, endIndent: 20, color: isDark ? Colors.white10 : Colors.grey[200]),
            _buildSwitchTile("Info. del Negocio (Dirección/GPS)", config.showBusinessInfo, isDark, (v) { config.showBusinessInfo = v; onChanged(); }),
            _buildSwitchTile("Cuentas Bancarias / Métodos de Pago", config.showPaymentInfo, isDark, (v) { config.showPaymentInfo = v; onChanged(); }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, bool isDark, Function(bool) onChanged, {bool isSubOption = false}) {
    return SwitchListTile(
      title: Text(title, style: TextStyle(fontSize: isSubOption ? 14 : 15, fontWeight: isSubOption ? FontWeight.normal : FontWeight.w600, color: isSubOption ? (isDark ? Colors.grey[400] : Colors.grey[700]) : (isDark ? Colors.white : Colors.black87))),
      value: value,
      activeThumbColor: const Color(0xFF00A884), // Color corporativo WhatsApp
      dense: true,
      contentPadding: EdgeInsets.only(left: isSubOption ? 40 : 20, right: 20),
      visualDensity: VisualDensity.compact,
      onChanged: onChanged,
    );
  }
}