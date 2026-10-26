import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/smart_quotation/models/whatsapp_config_model.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_dynamic_popover.dart';

class WaMessageEditor extends StatelessWidget {
  final bool isDark;
  final bool isManualEdit;
  final TextEditingController messageCtrl;
  final ValueChanged<String> onChanged;
  final WhatsAppConfig config;
  final Function(WhatsAppMessageStyle) onStyleChanged;
  final VoidCallback onRegenerateAuto;
  final String? paymentAccountsText;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback? onBeforeChange;

  const WaMessageEditor({
    super.key,
    required this.isDark,
    required this.isManualEdit,
    required this.messageCtrl,
    required this.onChanged,
    required this.config,
    required this.onStyleChanged,
    required this.onRegenerateAuto,
    this.paymentAccountsText,
    this.onUndo,
    this.onRedo,
    this.canUndo = false,
    this.canRedo = false,
    this.onBeforeChange,
  });

  void _applyFormat(String prefix, String suffix) {
    onBeforeChange?.call();
    final text = messageCtrl.text;
    final selection = messageCtrl.selection;
    if (!selection.isValid || selection.start < 0) {
      messageCtrl.text = "$text$prefix$suffix";
      messageCtrl.selection = TextSelection.collapsed(offset: messageCtrl.text.length - suffix.length);
      onChanged(messageCtrl.text);
      return;
    }
    if (selection.isCollapsed) {
      final newText = text.replaceRange(selection.start, selection.end, "$prefix$suffix");
      messageCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + prefix.length),
      );
    } else {
      final selectedText = text.substring(selection.start, selection.end);
      final formatted = "$prefix$selectedText$suffix";
      final newText = text.replaceRange(selection.start, selection.end, formatted);
      messageCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: selection.start,
          extentOffset: selection.start + formatted.length,
        ),
      );
    }
    onChanged(messageCtrl.text);
  }

  void _toggleSnippet({
    required bool isPresent,
    required String snippetToInsert,
    required Pattern patternToRemove,
  }) {
    onBeforeChange?.call();
    String text = messageCtrl.text;
    if (isPresent) {
      text = text.replaceAll(patternToRemove, '');
      text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
      messageCtrl.text = text;
      messageCtrl.selection = TextSelection.collapsed(offset: messageCtrl.text.length);
    } else {
      if (text.trim().isEmpty) {
        text = snippetToInsert;
      } else {
        text = "${text.trim()}\n\n$snippetToInsert";
      }
      messageCtrl.text = text;
      messageCtrl.selection = TextSelection.collapsed(offset: messageCtrl.text.length);
    }
    onChanged(messageCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final currentText = messageCtrl.text;
    final bool hasValidity = currentText.contains(RegExp(r'validez|días calendario|promoción por tiempo limitado', caseSensitive: false));
    final bool hasDelivery = currentText.contains(RegExp(r'entrega|envíos|estado del pedido', caseSensitive: false));
    final bool hasAccounts = currentText.contains(RegExp(r'MEDIOS DE PAGO|CUENTAS DE ABONO|Medios de Pago|Cuentas de Abono', caseSensitive: false));
    final bool hasGreeting = currentText.contains(RegExp(r'¡Hola|Estimad|Buen día|Buenos días', caseSensitive: false));
    final bool hasThanks = currentText.contains(RegExp(r'¡Muchas gracias|Muchas gracias|Gracias por su preferencia|Gracias por tu preferencia|¡Gracias!', caseSensitive: false));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector de Estilo de Mensaje por Situación (6 Estilos)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "ESTILO DE PLANTILLA",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                letterSpacing: 0.8,
              ),
            ),
            if (isManualEdit)
              InkWell(
                onTap: onRegenerateAuto,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.refresh, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        "Regenerar auto",
                        style: TextStyle(
                          color: isDark ? Colors.orange[300] : Colors.orange[800],
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Chips con soporte para 6 estilos de plantilla y popover explicativo
        Builder(
          builder: (context) {
            final styles = WhatsAppMessageStyle.values;
            const Color activeColor = Color(0xFF00A884);

            String getStylePreview(WhatsAppMessageStyle style) {
              switch (style) {
                case WhatsAppMessageStyle.commercial:
                  return "📄 *COTIZACIÓN FORMAL*\n• 2x Cuaderno A4: S/ 12.00\n💰 *TOTAL A PAGAR: S/ 12.00*\n💳 *Medios de pago:* Yape / BCP";
                case WhatsAppMessageStyle.compact:
                  return "⚡ *RESUMEN DIRECTO:* 2 productos | Total a pagar: *S/ 12.00*";
                case WhatsAppMessageStyle.urgentOffer:
                  return "🔥 *¡CIERRE DE OFERTA!*\n🎉 *¡Ahorro Total: S/ 18.00!*\n⏳ Válido por 7 días calendario.";
                case WhatsAppMessageStyle.accountDebt:
                  return "🔔 *ESTADO DE CUENTA*\n💵 Abonado: S/ 50.00\n⚠️ *Saldo Pendiente: S/ 30.00*";
                case WhatsAppMessageStyle.followUp:
                  return "🤝 ¡Hola! ¿Pudiste revisar la cotización que te enviamos? Con gusto ajustamos lo que necesites.";
                case WhatsAppMessageStyle.deliveryReady:
                  return "📦 *PEDIDO LISTO:* Tu pedido está empaquetado y listo para despacho o retiro en tienda.";
              }
            }

            Widget buildStyleCard(WhatsAppMessageStyle style) {
              final isSelected = config.style == style;
              return GestureDetector(
                onLongPress: () {
                  WaDynamicPopover.show(
                    context,
                    title: style.label,
                    description: style.description,
                    exampleSnippet: getStylePreview(style),
                    icon: Icons.auto_awesome,
                  );
                },
                child: InkWell(
                  onTap: () {
                    onBeforeChange?.call();
                    onStyleChanged(style);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? activeColor.withValues(alpha: isDark ? 0.22 : 0.12)
                          : (isDark ? const Color(0xFF1E1E2C) : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? activeColor
                            : (isDark ? Colors.white12 : Colors.grey.shade300),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          size: 15,
                          color: isSelected ? activeColor : (isDark ? Colors.grey[500] : Colors.grey[400]),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            style.label,
                            softWrap: true,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.2,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? (isDark ? const Color(0xFF25D366) : const Color(0xFF007A5E))
                                  : textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: buildStyleCard(styles[0])),
                    const SizedBox(width: 8),
                    Expanded(child: buildStyleCard(styles[1])),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: buildStyleCard(styles[2])),
                    const SizedBox(width: 8),
                    Expanded(child: buildStyleCard(styles[3])),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: buildStyleCard(styles[4])),
                    const SizedBox(width: 8),
                    Expanded(child: buildStyleCard(styles[5])),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        // Título de la vista previa editable
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "VISTA PREVIA (EDITABLE)",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
                letterSpacing: 0.8,
              ),
            ),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: messageCtrl.text));
                CustomSnackBar.show(context, message: "Mensaje copiado al portapapeles", isError: false);
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.copy, size: 14, color: isDark ? Colors.teal[300] : const Color(0xFF00A884)),
                    const SizedBox(width: 4),
                    Text(
                      "Copiar texto",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.teal[300] : const Color(0xFF00A884),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Barra de Herramientas de Formato WhatsApp, Deshacer/Rehacer y Snippets
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14141C) : Colors.grey[100],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // NIVEL 1: Formato WhatsApp y Pila Deshacer / Rehacer
              Row(
                children: [
                  // Botón Deshacer ↶
                  _buildActionIconButton(
                    icon: Icons.undo,
                    tooltip: "Deshacer (↶)",
                    isEnabled: canUndo,
                    isDark: isDark,
                    onTap: onUndo,
                  ),
                  const SizedBox(width: 4),
                  // Botón Rehacer ↷
                  _buildActionIconButton(
                    icon: Icons.redo,
                    tooltip: "Rehacer (↷)",
                    isEnabled: canRedo,
                    isDark: isDark,
                    onTap: onRedo,
                  ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 20, color: isDark ? Colors.white24 : Colors.grey[300]),
                  const SizedBox(width: 8),

                  // Formato Negrita
                  _buildToolButton(
                    label: "B",
                    tooltip: "Negrita (*texto*)",
                    isBold: true,
                    isDark: isDark,
                    onTap: () => _applyFormat("*", "*"),
                  ),
                  const SizedBox(width: 4),
                  // Formato Cursiva
                  _buildToolButton(
                    label: "I",
                    tooltip: "Cursiva (_texto_)",
                    isItalic: true,
                    isDark: isDark,
                    onTap: () => _applyFormat("_", "_"),
                  ),
                  const SizedBox(width: 4),
                  // Formato Tachado
                  _buildToolButton(
                    label: "S",
                    tooltip: "Tachado (~texto~)",
                    isStrike: true,
                    isDark: isDark,
                    onTap: () => _applyFormat("~", "~"),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // NIVEL 2: Snippets Comerciales en Wrap Multi-Línea Visible (Cero Cortes Horizontales)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  // 1. Validez 7 días
                  _buildSnippetChip(
                    context: context,
                    label: hasValidity ? "Validez 7 días" : "+ ⏳ Validez 7 días",
                    isSelected: hasValidity,
                    snippetDescription: "Inserta o elimina cláusula formal de validez por 7 días de la oferta.",
                    isDark: isDark,
                    onTap: () => _toggleSnippet(
                      isPresent: hasValidity,
                      snippetToInsert: "⏳ *Validez de la oferta:* 7 días calendario a partir de hoy.",
                      patternToRemove: RegExp(r'⏳\s*\*?(Validez[^\n]*|Promoción por tiempo limitado[^\n]*)\*?\n?([^\n]*días calendario[^\n]*\n*)?', caseSensitive: false),
                    ),
                  ),
                  // 2. Envío / Entrega
                  _buildSnippetChip(
                    context: context,
                    label: hasDelivery ? "Envío / Entrega" : "+ 🚚 Envío / Entrega",
                    isSelected: hasDelivery,
                    snippetDescription: "Agrega o quita nota de coordinación para entrega a domicilio o retiro.",
                    isDark: isDark,
                    onTap: () => _toggleSnippet(
                      isPresent: hasDelivery,
                      snippetToInsert: "🚚 *Entrega:* Coordinamos envíos a domicilio o recojo directo en tienda.",
                      patternToRemove: RegExp(r'(🚚|📦)\s*\*?(Entrega|ESTADO DEL PEDIDO|Envíos)[^\n]*\*?\n?([\s\S]*?)(?=(\n\s*\n|⏳|💳|🤝|🙏|$))', caseSensitive: false),
                    ),
                  ),
                  // 3. Mis Cuentas
                  _buildSnippetChip(
                    context: context,
                    label: hasAccounts ? "Mis Cuentas" : "+ 💳 Mis Cuentas",
                    isSelected: hasAccounts,
                    snippetDescription: "Inserta o elimina tus cuentas bancarias y números de pago configurados.",
                    isDark: isDark,
                    onTap: () {
                      final acc = paymentAccountsText != null && paymentAccountsText!.trim().isNotEmpty
                          ? paymentAccountsText!.trim()
                          : "📱 Yape / Plin / Transferencia bancaria disponible al solicitar.";
                      _toggleSnippet(
                        isPresent: hasAccounts,
                        snippetToInsert: "💳 *Medios de Pago:*\n$acc",
                        patternToRemove: RegExp(r'💳\s*\*?(MEDIOS DE PAGO|CUENTAS DE ABONO|Medios de Pago|Cuentas de Abono)[^\n]*\*?\n?([\s\S]*?)(?=(\n\s*\n|📦|🚚|⏳|🤝|🙏|$))', caseSensitive: false),
                      );
                    },
                  ),
                  // 4. Saludo
                  _buildSnippetChip(
                    context: context,
                    label: hasGreeting ? "Saludo" : "+ 👋 Saludo",
                    isSelected: hasGreeting,
                    snippetDescription: "Inserta o elimina saludo comercial cordial al inicio del mensaje.",
                    isDark: isDark,
                    onTap: () => _toggleSnippet(
                      isPresent: hasGreeting,
                      snippetToInsert: "👋 ¡Hola! Te comparto la información detallada:",
                      patternToRemove: RegExp(r'👋\s*\*?¡?Hola[^\n]*\*?\n?|Estimad[^\n]*\n?|Buenos? días[^\n]*\n?', caseSensitive: false),
                    ),
                  ),
                  // 5. Agradecimiento
                  _buildSnippetChip(
                    context: context,
                    label: hasThanks ? "Agradecimiento" : "+ 🙏 Agradecimiento",
                    isSelected: hasThanks,
                    snippetDescription: "Inserta o retira frase de agradecimiento y confianza profesional.",
                    isDark: isDark,
                    onTap: () => _toggleSnippet(
                      isPresent: hasThanks,
                      snippetToInsert: "🙏 ¡Muchas gracias por tu preferencia y confianza!",
                      patternToRemove: RegExp(r'(🤝|🙏)\s*\*?¡?Gracias[^\n]*\*?\n?', caseSensitive: false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Área editable de texto
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A24) : Colors.white,
            border: Border.all(
              color: isManualEdit
                  ? Colors.orange.shade300
                  : (isDark ? Colors.white10 : Colors.grey.shade300),
              width: 1.5,
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: TextField(
            controller: messageCtrl,
            maxLines: null,
            style: TextStyle(fontSize: 15, height: 1.45, color: textColor),
            decoration: const InputDecoration.collapsed(
              hintText: "Escribe o personaliza el mensaje de WhatsApp...",
            ),
            onChanged: onChanged,
          ),
        ),

        // Banner de advertencia de modo manual (Blindado contra overflow con Expanded)
        if (isManualEdit)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: [
                const Icon(Icons.edit_note, size: 16, color: Colors.orange),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Modo manual activo. Toca 'Regenerar auto' para restaurar la plantilla.",
                    softWrap: true,
                    style: TextStyle(
                      color: isDark ? Colors.orange[300] : Colors.orange[900],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActionIconButton({
    required IconData icon,
    required String tooltip,
    required bool isEnabled,
    required bool isDark,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark ? const Color(0xFF252535) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
            ),
            child: Icon(
              icon,
              size: 16,
              color: isEnabled
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.white24 : Colors.grey.shade400),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required String label,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
    bool isBold = false,
    bool isItalic = false,
    bool isStrike = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark ? const Color(0xFF252535) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
                fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                decoration: isStrike ? TextDecoration.lineThrough : null,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSnippetChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required String snippetDescription,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final Color activeColor = const Color(0xFF00A884);
    return Material(
      color: isSelected
          ? (isDark ? activeColor.withValues(alpha: 0.22) : activeColor.withValues(alpha: 0.12))
          : (isDark ? const Color(0xFF252535) : Colors.white),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        onLongPress: () {
          WaDynamicPopover.show(
            context,
            title: label,
            description: snippetDescription,
            icon: Icons.snippet_folder_outlined,
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? activeColor : (isDark ? Colors.white10 : Colors.grey.shade300),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                const Icon(Icons.check, size: 12, color: Color(0xFF00A884)),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? const Color(0xFF25D366) : const Color(0xFF007A5E))
                      : (isDark ? Colors.grey[300] : Colors.grey[800]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
