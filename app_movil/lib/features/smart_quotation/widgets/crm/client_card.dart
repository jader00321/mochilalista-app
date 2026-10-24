import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/client_detail_screen.dart'; 
import 'package:app_movil/features/smart_quotation/widgets/crm/payment_entry_modal.dart';
import 'package:app_movil/core/widgets/confirm_action_modal.dart'; 

class ClientCard extends StatelessWidget {
  final ClientModel client;
  final VoidCallback onRefresh;

  const ClientCard({super.key, required this.client, required this.onRefresh});

  Future<void> _launchWhatsApp(BuildContext context) async {
    if (client.phone.isEmpty || client.phone == "000000000") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Número no válido")));
      return;
    }
    
    ConfirmActionModal.show(
      context,
      title: "Enviar WhatsApp",
      subtitle: "¿Deseas enviar un mensaje a ${client.fullName} al número ${_formatPhone(client.phone)}?",
      icon: Icons.chat,
      color: const Color(0xFF25D366),
      onConfirm: () async {
        String msg = "Hola ${client.fullName}, te saludamos de la librería.";
        if (client.totalDebt > 0) {
          msg += " Te escribimos para recordarte que tienes un saldo pendiente de ${AppCurrency.format(client.totalDebt)}.";
        }

        final url = Uri.parse("https://wa.me/51${client.phone.replaceAll(' ', '')}?text=${Uri.encodeComponent(msg)}");
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo abrir WhatsApp")));
        }
      },
    );
  }

  Future<void> _launchCall(BuildContext context) async {
    if (client.phone.isEmpty || client.phone == "000000000") return;

    ConfirmActionModal.show(
      context,
      title: "Llamar al Cliente",
      subtitle: "¿Deseas llamar a ${client.fullName} al número ${_formatPhone(client.phone)}?",
      icon: Icons.call,
      color: Theme.of(context).brightness == Brightness.dark ? Colors.blue[300]! : Colors.blue[600]!,
      onConfirm: () async {
        final url = Uri.parse("tel:${client.phone.replaceAll(' ', '')}");
        if (await canLaunchUrl(url)) await launchUrl(url);
      },
    );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confidenceColor = _getConfidenceColor(isDark);
    
    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    final bool isAppClient = client.usuarioVinculadoId != null;
    final bool hasValidPhone = client.phone.isNotEmpty && client.phone != "000000000";

    return Card(
      elevation: isDark ? 0 : 2,
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: confidenceColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context, 
            MaterialPageRoute(builder: (_) => ClientDetailScreen(client: client)),
          ).then((_) => onRefresh());
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                        child: Text(
                          client.fullName.isNotEmpty ? client.fullName[0].toUpperCase() : "?", 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: isDark ? Colors.white70 : Colors.black54),
                        ),
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 16, height: 16, 
                          decoration: BoxDecoration(
                            color: confidenceColor, 
                            shape: BoxShape.circle, 
                            border: Border.all(color: cardColor, width: 2.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                client.fullName, 
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textColor), 
                                maxLines: 1, 
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isAppClient)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.15), 
                                  borderRadius: BorderRadius.circular(6), 
                                  border: Border.all(color: Colors.teal.withValues(alpha: 0.5)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.phone_android, size: 12, color: Colors.teal),
                                    SizedBox(width: 3),
                                    Text("APP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),

                        // Contacto (Teléfono y DNI) siempre visible y sutil
                        Row(
                          children: [
                            Icon(Icons.phone_android, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              hasValidPhone ? _formatPhone(client.phone) : "Sin teléfono",
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (client.docNumber != null && client.docNumber!.trim().isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text("•", style: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400], fontSize: 12)),
                              const SizedBox(width: 8),
                              Text(
                                client.docNumber!.trim(),
                                style: TextStyle(
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),

                        // Etiquetas CRM
                        if (client.etiquetas.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: client.etiquetas.take(2).map((e) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.purple.withValues(alpha: 0.15) : Colors.purple[50],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isDark ? Colors.purple.withValues(alpha: 0.3) : Colors.purple.shade200),
                              ),
                              child: Text(
                                e,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.purple[200] : Colors.purple[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (client.totalDebt > 0.01) ...[
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Deuda",
                            style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppCurrency.format(client.totalDebt),
                          style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent, fontSize: 17),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),

            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.black12 : Colors.grey[50], 
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    if (client.totalDebt > 0.01) ...[
                      Expanded(
                        child: _QuickActionButton(
                          icon: Icons.payments,
                          label: "Cobrar",
                          color: isDark ? Colors.green[400]! : Colors.green[700]!,
                          onTap: () => _openPaymentModal(context),
                        ),
                      ),
                      VerticalDivider(width: 1, color: isDark ? Colors.white10 : Colors.grey[300]),
                    ],
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.chat,
                        label: "WhatsApp",
                        color: const Color(0xFF25D366),
                        onTap: () => _launchWhatsApp(context),
                      ),
                    ),
                    VerticalDivider(width: 1, color: isDark ? Colors.white10 : Colors.grey[300]),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.call,
                        label: "Llamar",
                        color: isDark ? Colors.blue[300]! : Colors.blue[600]!,
                        onTap: () => _launchCall(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}