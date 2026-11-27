part of '../loyalty_whatsapp_service.dart';

Widget _buildPreviewClientSelector({
  required List<ClientModel> availableClients,
  required ClientModel? selectedClient,
  required bool isDark,
  required Color textColor,
  required ValueChanged<int?> onChanged,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF282838) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
    ),
    child: Row(
      children: [
        Icon(Icons.person_pin_rounded, size: 15, color: Colors.amber[700]),
        const SizedBox(width: 6),
        Text(
          "Personalizar:",
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              isDense: true,
              isExpanded: true,
              value: selectedClient?.id,
              hint: Text(
                "General para todos",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(
                    "General para todos",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                ...availableClients.map(
                  (c) => DropdownMenuItem<int?>(
                    value: c.id,
                    child: Text(
                      "${c.fullName} (${c.puntosActuales} pts)",
                      style: TextStyle(fontSize: 11.5, color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildPreviewFormatToolbar({
  required String currentFormat,
  required bool secRules,
  required bool secCatalog,
  required bool secStore,
  required bool isDark,
  required ValueChanged<String> onFormatSelected,
  required ValueChanged<bool> onToggleRules,
  required ValueChanged<bool> onToggleCatalog,
  required ValueChanged<bool> onToggleStore,
  required VoidCallback onRestore,
}) {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    physics: const BouncingScrollPhysics(),
    child: Row(
      children: [
        ChoiceChip(
          avatar: const Icon(Icons.auto_awesome_rounded, size: 13),
          label: const Text(
            "Completo",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          selected: currentFormat == 'COMPLETO',
          selectedColor: Colors.amber[700],
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          onSelected: (val) {
            if (val) onFormatSelected('COMPLETO');
          },
        ),
        const SizedBox(width: 6),
        ChoiceChip(
          avatar: const Icon(Icons.bolt_rounded, size: 13),
          label: const Text(
            "Resumen Corto",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          selected: currentFormat == 'RESUMEN',
          selectedColor: Colors.amber[700],
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          onSelected: (val) {
            if (val) onFormatSelected('RESUMEN');
          },
        ),
        const SizedBox(width: 6),
        ChoiceChip(
          avatar: const Icon(Icons.local_fire_department_rounded, size: 13),
          label: const Text(
            "Invitación Promocional",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          selected: currentFormat == 'PROMO',
          selectedColor: Colors.amber[700],
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          onSelected: (val) {
            if (val) onFormatSelected('PROMO');
          },
        ),
        const SizedBox(width: 8),
        if (currentFormat == 'COMPLETO') ...[
          Container(
            width: 1,
            height: 16,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(width: 8),
          FilterChip(
            avatar: Icon(
              secRules
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 13,
            ),
            label: const Text("Cómo ganar", style: TextStyle(fontSize: 11)),
            selected: secRules,
            selectedColor: Colors.green.withValues(alpha: 0.2),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            onSelected: onToggleRules,
          ),
          const SizedBox(width: 6),
          FilterChip(
            avatar: Icon(
              secCatalog
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 13,
            ),
            label: const Text(
              "Catálogo premios",
              style: TextStyle(fontSize: 11),
            ),
            selected: secCatalog,
            selectedColor: Colors.green.withValues(alpha: 0.2),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            onSelected: onToggleCatalog,
          ),
          const SizedBox(width: 6),
          FilterChip(
            avatar: Icon(
              secStore
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 13,
            ),
            label: const Text("Datos tienda", style: TextStyle(fontSize: 11)),
            selected: secStore,
            selectedColor: Colors.green.withValues(alpha: 0.2),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            onSelected: onToggleStore,
          ),
          const SizedBox(width: 8),
        ],
        ActionChip(
          avatar: const Icon(Icons.restart_alt_rounded, size: 13),
          label: const Text("Restaurar", style: TextStyle(fontSize: 11)),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          onPressed: onRestore,
        ),
      ],
    ),
  );
}

Widget _buildPreviewBottomActions({
  required BuildContext hostContext,
  required BuildContext modalContext,
  required TextEditingController msgCtrl,
  required bool hasActivePhone,
  required String currentPhone,
  required String? businessName,
  required bool isDark,
  required VoidCallback? onSent,
}) {
  return Row(
    children: [
      OutlinedButton.icon(
        onPressed: () {
          ClipboardHelper.copyWithFeedback(
            hostContext,
            msgCtrl.text.trim(),
            feedbackMessage: 'Mensaje copiado al portapapeles',
            useLoyaltyToast: true,
          );
        },
        icon: const Icon(Icons.copy_rounded, size: 16),
        label: const Text("Copiar"),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      const SizedBox(width: 8),
      if (!hasActivePhone) ...[
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final textToSend = msgCtrl.text.trim();
              Navigator.pop(modalContext);
              await SharePlus.instance.share(
                ShareParams(
                  text: textToSend,
                  subject:
                      "Programa de Puntos y Premios • ${businessName ?? 'Tienda'}",
                ),
              );
              onSent?.call();
            },
            icon: const Icon(
              Icons.share_rounded,
              color: Colors.white,
              size: 18,
            ),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "Compartir Cartilla",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ),
      ] else ...[
        IconButton(
          onPressed: () async {
            final textToSend = msgCtrl.text.trim();
            await SharePlus.instance.share(
              ShareParams(
                text: textToSend,
                subject:
                    "Programa de Puntos y Premios • ${businessName ?? 'Tienda'}",
              ),
            );
          },
          icon: const Icon(Icons.share_rounded, size: 18),
          tooltip: "Compartir a otras apps",
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final textToSend = msgCtrl.text.trim();
              Navigator.pop(modalContext);
              await LoyaltyWhatsAppService.launchWhatsApp(
                hostContext,
                currentPhone,
                textToSend,
              );
              onSent?.call();
            },
            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "Enviar por WhatsApp",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    ],
  );
}
