import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../screens/scan_screen.dart';
import '../../providers/auth_provider.dart';
import '../../features/smart_quotation/providers/smart_quotation_provider.dart';
import '../../features/smart_quotation/screens/matching_screen.dart'; 

class QuotationBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onGoToWorkbench;

  const QuotationBanner({
    super.key,
    this.title = "Gestiona tus Listas",
    this.subtitle = "Administra cotizaciones, verifica stock y cierra ventas de listas escolares.",
    this.buttonText = "INGRESAR AL ÁREA",
    required this.onGoToWorkbench,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;

    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final quotationScanner = Provider.of<SmartQuotationProvider>(context, listen: false);
    final isClient = authProv.isCommunityClient;

    return Material(
      elevation: isDark ? 0 : 12,
      shadowColor: isDark ? Colors.transparent : Colors.blue.withOpacity(0.15),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: isDark ? BorderSide(color: Colors.white.withOpacity(0.1), width: 1.5) : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          if (isClient) {
            if (quotationScanner.items.isNotEmpty) {
              _showResumeDialog(
                context, 
                title: "Pedido Pendiente",
                msg: "¿Deseas retomar el pedido escolar que estabas escaneando o empezar uno nuevo?",
                isDark: isDark,
                onNew: () {
                  quotationScanner.clearState(); 
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen(mode: ScanMode.quotation))); 
                },
                onResume: () {
                  // 🔥 CORRECCIÓN: Se eliminó el parámetro token
                  Navigator.push(context, MaterialPageRoute(builder: (_) => MatchingScreen(
                    extractedItems: quotationScanner.items,
                    metadata: quotationScanner.metadata,
                  )));
                }
              );
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen(mode: ScanMode.quotation)));
            }
          } else {
            onGoToWorkbench();
          }
        },
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: isDark 
              ? LinearGradient(colors: [Colors.white.withOpacity(0.05), Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight)
              : null,
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                child: Text(isClient ? "INTELIGENCIA ARTIFICIAL" : "MESA DE TRABAJO", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[800], fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: isDark ? Colors.white : Colors.black87, height: 1.2, letterSpacing: -0.5)),
                        const SizedBox(height: 8),
                        Text(subtitle, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14, height: 1.4)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 75, height: 75,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue[50], 
                      shape: BoxShape.circle,
                      boxShadow: [if(!isDark) BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]
                    ),
                    child: Icon(isClient ? Icons.document_scanner_rounded : Icons.checklist_rtl_rounded, size: 36, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                  )
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(buttonText, style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[700], fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: isDark ? Colors.blue[300] : Colors.blue[700], size: 20),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showResumeDialog(BuildContext context, {required String title, required String msg, required bool isDark, required VoidCallback onNew, required VoidCallback onResume}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 20)),
        content: Text(msg, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 15, height: 1.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); onNew(); },
            child: const Text("Iniciar Nueva", style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.blue[600] : Colors.blue[800], 
              foregroundColor: Colors.white, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0
            ),
            onPressed: () { Navigator.pop(ctx); onResume(); },
            child: const Text("Retomar Pedido", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          )
        ],
      ),
    );
  }
}