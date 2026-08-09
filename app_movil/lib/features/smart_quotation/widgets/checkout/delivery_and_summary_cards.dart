import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

// --- WIDGET 1: ENTREGA ---
class DeliveryConfigCard extends StatefulWidget {
  final Function(String status, DateTime? date) onChanged;
  final bool isFullyPaid; 

  const DeliveryConfigCard({super.key, required this.onChanged, required this.isFullyPaid});

  @override
  State<DeliveryConfigCard> createState() => _DeliveryConfigCardState();
}

class _DeliveryConfigCardState extends State<DeliveryConfigCard> {
  String _deliveryStatus = "entregado";
  DateTime? _selectedDate;

  void _notify() => widget.onChanged(_deliveryStatus, _selectedDate);

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).brightness == Brightness.dark
                ? const ColorScheme.dark(primary: Colors.purpleAccent, surface: Color(0xFF23232F))
                : ColorScheme.light(primary: Colors.purple[800]!),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _selectedDate = date);
      _notify();
    }
  }

  Widget _buildSelectionCard({
    required String title, required String subtitle, required IconData icon, 
    required bool isSelected, required Color activeColor, required VoidCallback onTap, required bool isDark
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.1) : (isDark ? const Color(0xFF23232F) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? activeColor : (isDark ? Colors.white10 : Colors.grey.shade300), width: isSelected ? 2 : 1),
          boxShadow: [if (!isDark && !isSelected) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))]
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isSelected ? activeColor.withValues(alpha: 0.2) : (isDark ? Colors.white10 : Colors.grey[100]), shape: BoxShape.circle), child: Icon(icon, color: isSelected ? activeColor : (isDark ? Colors.grey[500] : Colors.grey[400]), size: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: activeColor, size: 22)
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: isDark ? Colors.purple.withValues(alpha: 0.15) : Colors.purple[50], shape: BoxShape.circle),
              child: Icon(Icons.local_shipping, color: isDark ? Colors.purple[300] : Colors.purple[800], size: 22)
            ),
            const SizedBox(width: 12),
            Text("3. Logística de Entrega", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.purple[100] : Colors.purple[900], letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 16),
        
        _buildSelectionCard(
          title: "Entregado Inmediatamente", subtitle: "El cliente se lleva los productos ahora mismo.", icon: Icons.inventory_2_outlined, 
          isSelected: _deliveryStatus == "entregado", activeColor: isDark ? Colors.blue[400]! : Colors.blue, isDark: isDark,
          onTap: () { setState(() { _deliveryStatus = "entregado"; _selectedDate = null; }); _notify(); }
        ),
        const SizedBox(height: 10),
        _buildSelectionCard(
          title: widget.isFullyPaid ? "Retenido (Por Coordinación)" : "Retenido (Falta de Pago)", 
          subtitle: widget.isFullyPaid ? "Pagado, pero el cliente recogerá después." : "No entregar hasta que cancele la deuda.", 
          icon: widget.isFullyPaid ? Icons.handshake_outlined : Icons.lock_clock_outlined, 
          isSelected: _deliveryStatus == "retenido_por_pago", 
          activeColor: widget.isFullyPaid ? (isDark ? Colors.orange[400]! : Colors.orange) : (isDark ? Colors.red[400]! : Colors.red), 
          isDark: isDark,
          onTap: () { setState(() { _deliveryStatus = "retenido_por_pago"; _selectedDate = null; }); _notify(); }
        ),
        const SizedBox(height: 10),
        _buildSelectionCard(
          title: "Envío / Recojo Programado", subtitle: "Requiere fijar una fecha límite en el calendario.", icon: Icons.edit_calendar, 
          isSelected: _deliveryStatus == "pendiente_recojo", activeColor: isDark ? Colors.purple[400]! : Colors.purple, isDark: isDark,
          onTap: () { setState(() => _deliveryStatus = "pendiente_recojo"); _notify(); }
        ),
        
        if (_deliveryStatus == "pendiente_recojo") ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(color: isDark ? Colors.purple.withValues(alpha: 0.1) : Colors.purple[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.purple.withValues(alpha: 0.4) : Colors.purple.shade200, width: 1.5)),
              child: Row(
                children: [
                  Icon(Icons.calendar_month, color: isDark ? Colors.purple[300] : Colors.purple, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Fecha Límite Programada", style: TextStyle(fontSize: 13, color: isDark ? Colors.purple[200] : Colors.purple[800])),
                        const SizedBox(height: 2),
                        Text(
                          _selectedDate == null ? "Toca para seleccionar fecha" : DateFormat('dd/MM/yyyy').format(_selectedDate!),
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 16)
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: isDark ? Colors.purple[300] : Colors.purple, size: 16)
                ],
              ),
            ),
          )
        ]
      ],
    );
  }
}
