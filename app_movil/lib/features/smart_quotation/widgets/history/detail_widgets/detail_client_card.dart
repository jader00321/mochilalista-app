import 'package:flutter/material.dart';

class DetailClientCard extends StatelessWidget {
  final Map<String, dynamic> saleData;
  final bool isQuickSale;
  final String institution;
  final String grade;
  final bool isDark;

  const DetailClientCard({
    super.key, required this.saleData, required this.isQuickSale, 
    required this.institution, required this.grade, required this.isDark
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("DATOS DEL CLIENTE", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey, letterSpacing: 1)),
              const SizedBox(height: 16),
              Row(children: [Icon(Icons.person, size: 26, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey), const SizedBox(width: 12), Expanded(child: Text(saleData['cliente_nombre'] ?? "Cliente No Registrado", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)))]),
              
              if (saleData['cliente_telefono'] != null && saleData['cliente_telefono'].toString().isNotEmpty && saleData['cliente_telefono'] != "000000000") ...[
                const SizedBox(height: 12),
                Row(children: [Icon(Icons.phone, size: 24, color: isDark ? Colors.grey[400] : Colors.grey), const SizedBox(width: 12), Text(saleData['cliente_telefono'].toString(), style: TextStyle(color: textColor, fontSize: 16))]),
              ],

              if (!isQuickSale && (institution.isNotEmpty || grade.isNotEmpty)) ...[
                 const SizedBox(height: 16),
                 Container(
                   padding: const EdgeInsets.all(16),
                   decoration: BoxDecoration(color: isDark ? Colors.indigo.withOpacity(0.15) : Colors.indigo[50], borderRadius: BorderRadius.circular(12)),
                   child: Column(
                     children: [
                       if (institution.isNotEmpty) Row(children: [Icon(Icons.school, size: 22, color: isDark ? Colors.indigo[200] : Colors.indigo), const SizedBox(width: 12), Expanded(child: Text(institution, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? Colors.white : Colors.black87)))]),
                       if (grade.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [Icon(Icons.class_, size: 22, color: isDark ? Colors.indigo[200] : Colors.indigo), const SizedBox(width: 12), Text(grade, style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87))])),
                     ],
                   ),
                 )
              ],
            ],
          ),
        ),
      ),
    );
  }
}