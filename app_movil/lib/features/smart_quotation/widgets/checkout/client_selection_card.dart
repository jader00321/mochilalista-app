import 'package:flutter/material.dart';
import '../../models/crm_models.dart';

class ClientSelectionCard extends StatelessWidget {
  final ClientModel? selectedClient;
  final VoidCallback onSearchOrAddTap;
  final VoidCallback onEditTap;

  const ClientSelectionCard({
    super.key,
    required this.selectedClient,
    required this.onSearchOrAddTap,
    required this.onEditTap,
  });

  String _formatPhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 9) {
      return "${clean.substring(0, 3)} ${clean.substring(3, 6)} ${clean.substring(6, 9)}";
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue[50], shape: BoxShape.circle),
              child: Icon(Icons.person_pin_rounded, color: isDark ? Colors.blue[300] : Colors.blue[800], size: 22)
            ),
            const SizedBox(width: 12),
            Text("1. Cliente de la Venta", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.blue[100] : Colors.blue[900], letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 16),
        
        if (selectedClient == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2A) : Colors.white, 
              borderRadius: BorderRadius.circular(24), 
              border: Border.all(color: isDark ? Colors.orange.withOpacity(0.3) : Colors.orange.shade200, width: 1.5),
              boxShadow: [if (!isDark) BoxShadow(color: Colors.orange.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: isDark ? Colors.orange.withOpacity(0.1) : Colors.orange[50], shape: BoxShape.circle),
                  child: Icon(Icons.person_search_rounded, color: isDark ? Colors.orange[300] : Colors.orange[700], size: 36)
                ),
                const SizedBox(height: 16),
                Text("Cliente no asignado", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text("Asigna un cliente para registrar la venta correctamente en el historial.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14, height: 1.4), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton.icon(
                    onPressed: onSearchOrAddTap,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text("Buscar / Nuevo Cliente", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.blue[700] : Colors.blue[800], 
                      foregroundColor: Colors.white, 
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                    ),
                  ),
                )
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF23232F) : Colors.white, 
              borderRadius: BorderRadius.circular(24), 
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
              boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue[50], 
                      radius: 28,
                      child: Text(selectedClient!.fullName.isNotEmpty ? selectedClient!.fullName[0].toUpperCase() : "?", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[800], fontWeight: FontWeight.bold, fontSize: 24))
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(selectedClient!.fullName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor, height: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              // 🔥 FASE 4: BADGE DE APP
                              if (selectedClient!.usuarioVinculadoId != null)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.teal.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.teal.withOpacity(0.5))),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.phone_android, size: 12, color: Colors.teal),
                                      SizedBox(width: 4),
                                      Text("APP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal)),
                                    ],
                                  ),
                                )
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.smartphone, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              const SizedBox(width: 6),
                              Text(_formatPhone(selectedClient!.phone), style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          if (selectedClient!.docNumber != null && selectedClient!.docNumber!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.badge_outlined, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                const SizedBox(width: 6),
                                Text(selectedClient!.docNumber!, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 14)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                
                if (selectedClient!.notes != null && selectedClient!.notes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: isDark ? Colors.amber.withOpacity(0.05) : Colors.amber.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.sticky_note_2, size: 16, color: isDark ? Colors.amber[300] : Colors.amber[800]),
                        const SizedBox(width: 8),
                        Expanded(child: Text(selectedClient!.notes!, style: TextStyle(color: isDark ? Colors.amber[100] : Colors.amber[900], fontSize: 13, fontStyle: FontStyle.italic, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onSearchOrAddTap, 
                        icon: const Icon(Icons.swap_horiz, size: 18), 
                        label: const Text("Cambiar"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.grey[300] : Colors.grey[800],
                          side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        )
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: onEditTap, 
                        icon: const Icon(Icons.edit, size: 18), 
                        label: const Text("Editar Datos"),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? Colors.blue[300] : Colors.blue[700],
                          backgroundColor: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue[50],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        )
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
      ],
    );
  }
}