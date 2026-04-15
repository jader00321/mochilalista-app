import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/crm_models.dart';
import '../../screens/crm/client_detail_screen.dart'; 
import 'payment_entry_modal.dart'; 

class ClientCard extends StatelessWidget {
  final ClientModel client;
  final VoidCallback onRefresh;

  const ClientCard({super.key, required this.client, required this.onRefresh});

  Future<void> _launchWhatsApp(BuildContext context) async {
    if (client.phone.isEmpty || client.phone == "000000000") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Número no válido")));
      return;
    }
    
    String msg = "Hola ${client.fullName}, te saludamos de la librería.";
    if (client.totalDebt > 0) {
      final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
      msg += " Te escribimos para recordarte que tienes un saldo pendiente de ${currency.format(client.totalDebt)}.";
    }

    final url = Uri.parse("https://wa.me/51${client.phone}?text=${Uri.encodeComponent(msg)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo abrir WhatsApp")));
    }
  }

  Future<void> _launchCall(BuildContext context) async {
    if (client.phone.isEmpty || client.phone == "000000000") return;
    final url = Uri.parse("tel:${client.phone}");
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _openPaymentModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentEntryModal(client: client),
    ).then((_) => onRefresh());
  }

  Color _getConfidenceColor(bool isDark) {
    switch (client.nivelConfianza.toLowerCase()) {
      case 'excelente': return isDark ? Colors.green[400]! : Colors.green;
      case 'bueno': return isDark ? Colors.blue[400]! : Colors.blue;
      case 'regular': return isDark ? Colors.orange[400]! : Colors.orange;
      case 'moroso': return isDark ? Colors.red[400]! : Colors.red;
      default: return Colors.grey;
    }
  }

  String _formatPhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 9) {
      return "${clean.substring(0, 3)} ${clean.substring(3, 6)} ${clean.substring(6, 9)}";
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confidenceColor = _getConfidenceColor(isDark);
    
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    // 🔥 FASE 4: LOGICA DE INSIGNIAS
    final bool isAppClient = client.usuarioVinculadoId != null;

    return Card(
      elevation: isDark ? 0 : 2,
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      color: isDark ? const Color(0xFF23232F) : cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: confidenceColor.withOpacity(0.4), width: 1.5)
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ClientDetailScreen(client: client))).then((_) => onRefresh());
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                        child: Text(client.fullName.isNotEmpty ? client.fullName[0].toUpperCase() : "?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26, color: isDark ? Colors.white70 : Colors.black54)),
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(width: 18, height: 18, decoration: BoxDecoration(color: confidenceColor, shape: BoxShape.circle, border: Border.all(color: isDark ? const Color(0xFF23232F) : cardColor, width: 2.5))),
                      )
                    ],
                  ),
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(client.fullName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            // 🔥 FASE 4: BADGE DE APP
                            if (isAppClient)
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
                        if (client.etiquetas.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: client.etiquetas.take(2).map((e) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: isDark ? Colors.purple.withOpacity(0.15) : Colors.purple[50], borderRadius: BorderRadius.circular(8)),
                              child: Text(e, style: TextStyle(fontSize: 12, color: isDark ? Colors.purple[200] : Colors.purple[800], fontWeight: FontWeight.bold)),
                            )).toList(),
                          )
                        else
                          Row(
                            children: [
                              Icon(Icons.phone_android, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              const SizedBox(width: 6),
                              Text(_formatPhone(client.phone), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w500)),
                            ],
                          ),
                      ],
                    ),
                  ),

                  if (client.totalDebt > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("Deuda", style: TextStyle(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(currency.format(client.totalDebt), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent, fontSize: 18)),
                      ],
                    )
                ],
              ),
            ),

            Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),

            Container(
              decoration: BoxDecoration(color: isDark ? Colors.black12 : Colors.grey[50], borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    if (client.totalDebt > 0) ...[
                      Expanded(child: _QuickActionButton(icon: Icons.payments, label: "Cobrar", color: isDark ? Colors.green[400]! : Colors.green[700]!, onTap: () => _openPaymentModal(context))),
                      VerticalDivider(width: 1, color: isDark ? Colors.white10 : Colors.grey[300]),
                    ],
                    Expanded(child: _QuickActionButton(icon: Icons.chat, label: "WhatsApp", color: const Color(0xFF25D366), onTap: () => _launchWhatsApp(context))),
                    VerticalDivider(width: 1, color: isDark ? Colors.white10 : Colors.grey[300]),
                    Expanded(child: _QuickActionButton(icon: Icons.call, label: "Llamar", color: isDark ? Colors.blue[300]! : Colors.blue[600]!, onTap: () => _launchCall(context))),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}