import 'package:flutter/material.dart';

class DetailNotesCard extends StatelessWidget {
  final String saleNote;
  final String clientNote;
  final int cotizacionId;
  final int? clientId;
  final bool isDark;
  final Function(String, String, int) onEditTap;

  const DetailNotesCard({
    super.key, required this.saleNote, required this.clientNote, 
    required this.cotizacionId, this.clientId, required this.isDark, required this.onEditTap
  });

  @override
  Widget build(BuildContext context) {
    if (saleNote.isEmpty && clientNote.isEmpty) return const SizedBox.shrink();
    
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        elevation: 0,
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("NOTAS DE LA VENTA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[300] : Colors.grey[800], letterSpacing: 1)),
              const SizedBox(height: 16),
              
              if (saleNote.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.speaker_notes, color: isDark ? Colors.orange[300] : Colors.orange[800], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Nota de la Compra:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.orange[200] : Colors.orange[900])),
                          const SizedBox(height: 6),
                          Text(saleNote, style: TextStyle(fontSize: 17, color: textColor, height: 1.4)),
                        ],
                      ),
                    ),
                    if (cotizacionId > 0)
                      IconButton(
                        icon: Icon(Icons.edit, color: isDark ? Colors.orange[300] : Colors.orange[800], size: 22),
                        onPressed: () => onEditTap('sale', saleNote, cotizacionId),
                        tooltip: "Editar nota de venta",
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                  ],
                ),
              ],

              if (saleNote.isNotEmpty && clientNote.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                ),

              if (clientNote.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.assignment_ind, color: isDark ? Colors.blue[300] : Colors.blue[800], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Observación CRM del Cliente:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.blue[200] : Colors.blue[900])),
                          const SizedBox(height: 6),
                          Text(clientNote, style: TextStyle(fontSize: 17, color: textColor, height: 1.4, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                    if (clientId != null && clientId! > 0)
                      IconButton(
                        icon: Icon(Icons.edit, color: isDark ? Colors.blue[300] : Colors.blue[800], size: 22),
                        onPressed: () => onEditTap('client', clientNote, clientId!),
                        tooltip: "Editar nota CRM",
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}