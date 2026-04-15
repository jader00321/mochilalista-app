import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProviderInfoCard extends StatefulWidget {
  final TextEditingController providerNameCtrl;
  final TextEditingController rucCtrl;
  final TextEditingController dateCtrl;
  final TextEditingController montoTotalCtrl; // 🔥 NUEVO CONTROLADOR
  final bool isDark;

  const ProviderInfoCard({
    super.key,
    required this.providerNameCtrl,
    required this.rucCtrl,
    required this.dateCtrl,
    required this.montoTotalCtrl,
    required this.isDark,
  });

  @override
  State<ProviderInfoCard> createState() => _ProviderInfoCardState();
}

class _ProviderInfoCardState extends State<ProviderInfoCard> {

  Future<void> _selectDate(BuildContext context) async {
    DateTime initialDate = DateTime.now();
    
    if (widget.dateCtrl.text.isNotEmpty) {
      try {
        if (widget.dateCtrl.text.contains('/')) {
          final parts = widget.dateCtrl.text.split('/');
          initialDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        } else {
          initialDate = DateTime.parse(widget.dateCtrl.text);
        }
      } catch (_) {} 
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'SELECCIONAR FECHA',
      cancelText: 'CANCELAR',
      confirmText: 'ACEPTAR',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: widget.isDark 
                ? const ColorScheme.dark(primary: Colors.green, surface: Color(0xFF23232F))
                : ColorScheme.light(primary: Colors.green[700]!), dialogTheme: DialogThemeData(backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        widget.dateCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), 
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade300),
        boxShadow: [if (!widget.isDark) const BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))]
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          children: [
            // 1. PROVEEDOR
            TextField(
              controller: widget.providerNameCtrl,
              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: "Proveedor Detectado",
                labelStyle: TextStyle(color: widget.isDark ? Colors.green[300] : Colors.green[800], fontSize: 14),
                prefixIcon: Icon(Icons.store, color: widget.isDark ? Colors.green[300] : const Color(0xFF2E7D32)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: widget.isDark ? Colors.green.withOpacity(0.15) : Colors.green[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 16), 
            
            // 2. RUC Y FECHA
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: widget.rucCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: textColor, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: "RUC",
                      labelStyle: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[700]),
                      prefixIcon: Icon(Icons.badge, color: widget.isDark ? Colors.blueGrey[300] : Colors.blueGrey, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[100],
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    borderRadius: BorderRadius.circular(12),
                    child: IgnorePointer(
                      child: TextField(
                        controller: widget.dateCtrl,
                        readOnly: true, 
                        style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: "Fecha",
                          labelStyle: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[700]),
                          prefixIcon: Icon(Icons.calendar_month, color: widget.isDark ? Colors.blueGrey[300] : Colors.blueGrey, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[100],
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 3. 🔥 MONTO TOTAL DE FACTURA
            TextField(
              controller: widget.montoTotalCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: widget.isDark ? Colors.green[400] : Colors.green[700], fontSize: 20, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: "Monto Total del Comprobante",
                labelStyle: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 14, fontWeight: FontWeight.normal),
                prefixText: "S/ ",
                prefixStyle: TextStyle(color: widget.isDark ? Colors.green[400] : Colors.green[700], fontSize: 20, fontWeight: FontWeight.w900),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.isDark ? Colors.white24 : Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.isDark ? Colors.white10 : Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.isDark ? Colors.green.withOpacity(0.5) : Colors.green, width: 2)),
                filled: true,
                fillColor: widget.isDark ? const Color(0xFF1A1A24) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}