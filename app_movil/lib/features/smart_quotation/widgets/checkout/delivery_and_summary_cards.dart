import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          color: isSelected ? activeColor.withOpacity(0.1) : (isDark ? const Color(0xFF23232F) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? activeColor : (isDark ? Colors.white10 : Colors.grey.shade300), width: isSelected ? 2 : 1),
          boxShadow: [if (!isDark && !isSelected) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isSelected ? activeColor.withOpacity(0.2) : (isDark ? Colors.white10 : Colors.grey[100]), shape: BoxShape.circle), child: Icon(icon, color: isSelected ? activeColor : (isDark ? Colors.grey[500] : Colors.grey[400]), size: 24)),
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
              decoration: BoxDecoration(color: isDark ? Colors.purple.withOpacity(0.15) : Colors.purple[50], shape: BoxShape.circle),
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
              decoration: BoxDecoration(color: isDark ? Colors.purple.withOpacity(0.1) : Colors.purple[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.purple.withOpacity(0.4) : Colors.purple.shade200, width: 1.5)),
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

// --- WIDGET 2: RESUMEN FINANCIERO ---
class CheckoutSummaryCard extends StatelessWidget {
  final double subtotal;
  final double savings; 
  final TextEditingController discountCtrl;
  final double totalToPay;
  final double paidAmount;
  final VoidCallback onDiscountUpdated;

  const CheckoutSummaryCard({
    super.key,
    required this.subtotal,
    required this.savings,
    required this.discountCtrl,
    required this.totalToPay,
    required this.paidAmount,
    required this.onDiscountUpdated,
  });

  @override
  Widget build(BuildContext context) {
    double debt = totalToPay - paidAmount;
    if (debt < 0) debt = 0; 

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Card(
      elevation: isDark ? 0 : 8,
      color: cardColor,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: isDark ? Colors.white10 : Colors.blue.shade100, width: 1.5)),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey, size: 24),
                const SizedBox(width: 10),
                Text("4. Resumen Financiero", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
            const SizedBox(height: 24),
            
            _rowSummary("Subtotal Productos", subtotal, isDark),
            if (savings > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: _rowSummary("Ahorro aplicado (Promos)", -savings, isDark, color: isDark ? Colors.green[400] : Colors.green[700], isBold: true),
              ),
            
            Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200])),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Descuento Extra (S/):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                SizedBox(
                  width: 110, height: 45,
                  child: TextField(
                    controller: discountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                    textAlign: TextAlign.right,
                    style: TextStyle(color: isDark ? Colors.red[300] : Colors.red[700], fontWeight: FontWeight.bold, fontSize: 18),
                    decoration: InputDecoration(
                      prefixText: "- ", 
                      prefixStyle: TextStyle(color: isDark ? Colors.red[300] : Colors.red[700], fontWeight: FontWeight.bold, fontSize: 18),
                      isDense: true, 
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
                    ),
                    onChanged: (v) => onDiscountUpdated(),
                  ),
                )
              ],
            ),
            
            // Línea punteada decorativa
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24), 
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final boxWidth = constraints.constrainWidth();
                  const dashWidth = 8.0;
                  const dashSpace = 5.0;
                  final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
                  return Flex(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    direction: Axis.horizontal,
                    children: List.generate(dashCount, (_) {
                      return SizedBox(width: dashWidth, height: 1.5, child: DecoratedBox(decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[400])));
                    }),
                  );
                },
              ),
            ),
            
            _rowSummary("TOTAL FINAL", totalToPay, isDark, isBold: true, fontSize: 24, color: isDark ? Colors.blue[300] : Colors.blue[900]),
            
            if (debt > 0) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: isDark ? Colors.red.withOpacity(0.15) : Colors.red[50], borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    _rowSummary("Abonado Hoy:", paidAmount, isDark, color: isDark ? Colors.green[300] : Colors.green[800], fontSize: 16),
                    const SizedBox(height: 8),
                    _rowSummary("DEUDA RESTANTE:", debt, isDark, isBold: true, color: isDark ? Colors.red[300] : Colors.red[800], fontSize: 18),
                  ],
                ),
              )
            ] else ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: isDark ? Colors.green.withOpacity(0.15) : Colors.green[50], borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user, color: isDark ? Colors.green[400] : Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text("MONTO CUBIERTO EN SU TOTALIDAD", style: TextStyle(color: isDark ? Colors.green[400] : Colors.green[800], fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                  ],
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _rowSummary(String label, double value, bool isDark, {bool isBold = false, double fontSize = 15, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize, color: color ?? (isDark ? Colors.grey[400] : Colors.grey[700]))),
        Text(
          value < 0 ? "- S/ ${(-value).toStringAsFixed(2)}" : "S/ ${value.toStringAsFixed(2)}", 
          style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, fontSize: fontSize, color: color ?? (isDark ? Colors.white : Colors.black87))
        ),
      ],
    );
  }
}