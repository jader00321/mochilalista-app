import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/loyalty_whatsapp_service.dart';

class PromotionBroadcastModal extends StatefulWidget {
  final String businessName;
  final List<Map<String, dynamic>> selectedProducts;
  final List<ClientModel> targetClients;

  const PromotionBroadcastModal({
    super.key,
    required this.businessName,
    required this.selectedProducts,
    required this.targetClients,
  });

  static Future<void> show(
    BuildContext context, {
    required String businessName,
    required List<Map<String, dynamic>> selectedProducts,
    required List<ClientModel> targetClients,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PromotionBroadcastModal(
        businessName: businessName,
        selectedProducts: selectedProducts,
        targetClients: targetClients,
      ),
    );
  }

  @override
  State<PromotionBroadcastModal> createState() => _PromotionBroadcastModalState();
}

class _PromotionBroadcastModalState extends State<PromotionBroadcastModal> {
  late TextEditingController _messageCtrl;
  final Set<int> _sentClientIds = {};

  @override
  void initState() {
    super.initState();
    final firstClientName = widget.targetClients.isNotEmpty
        ? widget.targetClients.first.fullName.split(' ').first
        : 'Cliente';

    final initialMessage = LoyaltyWhatsAppService.buildPromotionMessage(
      clientName: firstClientName,
      businessName: widget.businessName,
      products: widget.selectedProducts,
    );
    _messageCtrl = TextEditingController(text: initialMessage);
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _messageCtrl.text));
    CustomSnackBar.show(context, message: 'Mensaje copiado al portapapeles');
  }

  Future<void> _sendToClient(ClientModel client) async {
    final clientFirstName = client.fullName.split(' ').first;
    // Adaptar el saludo al cliente específico si el usuario no lo modificó completamente
    var textToSend = _messageCtrl.text;
    if (widget.targetClients.isNotEmpty) {
      final oldFirst = widget.targetClients.first.fullName.split(' ').first;
      if (textToSend.contains('¡Hola, $oldFirst!')) {
        textToSend = textToSend.replaceFirst('¡Hola, $oldFirst!', '¡Hola, $clientFirstName!');
      }
    }

    final sent = await LoyaltyWhatsAppService.sendPromotionBroadcasterNotification(
      context: context,
      phone: client.phone,
      clientName: clientFirstName,
      businessName: widget.businessName,
      products: widget.selectedProducts,
      customMessage: textToSend,
    );

    if (sent && mounted) {
      setState(() => _sentClientIds.add(client.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final cardColor = isDark ? const Color(0xFF282836) : Colors.grey.shade50;

    final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(
      context,
      minPadding: InteractiveSheetWrapper.kMinDefensiveBottomClearance,
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, effectiveBottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Asa superior
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cabecera del modal
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.campaign_rounded, color: Color(0xFF25D366), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Difusión de Promociones',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          '${widget.selectedProducts.length} productos • ${widget.targetClients.length} destinatarios',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Mensaje editable
              Text(
                'Mensaje de WhatsApp (Editable)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
                child: TextField(
                  controller: _messageCtrl,
                  maxLines: 5,
                  style: TextStyle(fontSize: 13, color: textColor, height: 1.35),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(12),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Botón Copiar al Portapapeles
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _copyToClipboard,
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Copiar Mensaje', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Subtítulo Cola de Envío
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cola de Envío',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  Text(
                    '${_sentClientIds.length} de ${widget.targetClients.length} enviados',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _sentClientIds.length == widget.targetClients.length && widget.targetClients.isNotEmpty
                          ? Colors.green
                          : Colors.amber[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Lista de clientes scrolleable
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: widget.targetClients.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: isDark ? Colors.white10 : Colors.grey.shade100,
                  ),
                  itemBuilder: (ctx, i) {
                    final client = widget.targetClients[i];
                    final isSent = _sentClientIds.contains(client.id);
                    final tier = client.tier;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Color(tier.colorHex).withValues(alpha: 0.15),
                            child: Icon(tier.icon, color: Color(tier.colorHex), size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  client.fullName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.phone_rounded, size: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                    const SizedBox(width: 3),
                                    Text(
                                      client.phone.isNotEmpty ? client.phone : 'Sin teléfono',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Color(tier.colorHex).withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        tier.badgeText,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(tier.colorHex),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isSent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Enviado',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: () => _sendToClient(client),
                              icon: const Icon(Icons.send_rounded, size: 13),
                              label: const Text('Enviar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

