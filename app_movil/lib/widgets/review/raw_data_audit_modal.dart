import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../providers/scanner_provider.dart';

class RawDataAuditModal {
  static void show(BuildContext context, bool isDark) {
    final provider = Provider.of<ScannerProvider>(context, listen: false);
    
    String rawJson = "Sin datos registrados.";
    if (provider.aiRawData != null) {
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      rawJson = encoder.convert(provider.aiRawData!.toJson());
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool showRawJson = false; 
        
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollController) => Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A24) : Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
                ),
                padding: const EdgeInsets.only(top: 8, bottom: 24, left: 16, right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(Icons.memory, color: isDark ? Colors.blue[300] : Colors.blue, size: 28),
                        const SizedBox(width: 10),
                        Text("Auditoría de Extracción", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // TOGGLE BUTTONS
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => showRawJson = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !showRawJson ? (isDark ? Colors.blue[800] : Colors.white) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: !showRawJson && !isDark ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)] : []
                                ),
                                child: Center(child: Text("Vista Resumida", style: TextStyle(fontWeight: FontWeight.bold, color: !showRawJson ? (isDark ? Colors.white : Colors.blue[800]) : Colors.grey))),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => showRawJson = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: showRawJson ? (isDark ? Colors.blue[800] : Colors.white) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: showRawJson && !isDark ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)] : []
                                ),
                                child: Center(child: Text("Código JSON", style: TextStyle(fontWeight: FontWeight.bold, color: showRawJson ? (isDark ? Colors.white : Colors.blue[800]) : Colors.grey))),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // CONTENIDO DINÁMICO
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(showRawJson ? 16 : 0),
                        decoration: BoxDecoration(
                          color: showRawJson ? (isDark ? const Color(0xFF0D0D14) : Colors.white) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: showRawJson ? Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300) : null
                        ),
                        child: showRawJson 
                          ? SingleChildScrollView(
                              controller: scrollController,
                              child: Text(
                                rawJson,
                                style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: isDark ? Colors.green[300] : Colors.green[800], height: 1.5),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: provider.aiRawData?.items.length ?? 0,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final aiItem = provider.aiRawData!.items[i];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF23232F) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200)
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(aiItem.descripcion, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("Llevado: ${aiItem.cantidadUmpComprada} ${aiItem.umpCompra}", style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                                          Text("Total: S/ ${aiItem.totalPagoLote.toStringAsFixed(2)}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.green[300] : Colors.green[700])),
                                        ],
                                      )
                                    ],
                                  ),
                                );
                              },
                            ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.blue[800] : Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text("ENTENDIDO", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    )
                  ]
                )
              )
            );
          }
        );
      }
    );
  }
}
