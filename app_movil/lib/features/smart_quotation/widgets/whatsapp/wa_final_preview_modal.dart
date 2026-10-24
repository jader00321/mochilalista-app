import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

/// 💬 MODAL DE REVISIÓN FINAL CON BURBUJA REALISTA ("MOBILE AWARDS")
/// Incorpora:
/// 1. Blindaje total del scroll (enableDrag: false + BouncingScrollPhysics).
/// 2. Vista de Burbuja Realista de WhatsApp con parser Markdown (*B*, _I_, ~S~).
/// 3. Alternador rápido entre 'Ver Burbuja' y 'Editar Texto'.
/// 4. Desplazamiento fluido sin cortes con scrollbar visible y padding generoso.
class WaFinalPreviewModal extends StatefulWidget {
  final bool isDark;
  final String phone;
  final TextEditingController messageCtrl;
  final ValueChanged<String>? onMessageChanged;
  final VoidCallback onSend;
  final VoidCallback? onSharePdfAndMessage;

  const WaFinalPreviewModal({
    super.key,
    required this.isDark,
    required this.phone,
    required this.messageCtrl,
    this.onMessageChanged,
    required this.onSend,
    this.onSharePdfAndMessage,
  });

  @override
  State<WaFinalPreviewModal> createState() => _WaFinalPreviewModalState();
}

class _WaFinalPreviewModalState extends State<WaFinalPreviewModal> {
  late final ScrollController _scrollController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Parser liviano de Markdown de WhatsApp (*negrita*, _cursiva_, ~tachado~)
  List<TextSpan> _parseWhatsAppMarkdown(String text, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    final pattern = RegExp(r'(\*[^*]+\*|_[^_]+_|~[^~]+~)');
    int lastMatchEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: baseStyle,
        ));
      }

      final matchedText = match.group(0)!;
      if (matchedText.startsWith('*') && matchedText.endsWith('*') && matchedText.length > 2) {
        spans.add(TextSpan(
          text: matchedText.substring(1, matchedText.length - 1),
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (matchedText.startsWith('_') && matchedText.endsWith('_') && matchedText.length > 2) {
        spans.add(TextSpan(
          text: matchedText.substring(1, matchedText.length - 1),
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (matchedText.startsWith('~') && matchedText.endsWith('~') && matchedText.length > 2) {
        spans.add(TextSpan(
          text: matchedText.substring(1, matchedText.length - 1),
          style: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
        ));
      } else {
        spans.add(TextSpan(text: matchedText, style: baseStyle));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: baseStyle,
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = widget.isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final chatBg = widget.isDark ? const Color(0xFF0C1317) : const Color(0xFFEFEAE2);
    final cleanPhone = widget.phone.replaceAll(RegExp(r'\D'), '');
    final bool hasValidPhone = cleanPhone.length == 9;

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.92,
      backgroundColor: surfaceColor,
      enableDragToDismiss: false, // 🛡️ Blindaje total: evita que el modal robe gestos de scroll
      applyEffectiveBottomPadding: true,
      bottomAction: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.messageCtrl.text));
                    CustomSnackBar.show(context, message: "Mensaje copiado al portapapeles", isError: false);
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text("Copiar", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.isDark ? Colors.grey[300] : Colors.grey[800],
                    side: BorderSide(color: widget.isDark ? Colors.white24 : Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (widget.onSharePdfAndMessage != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: widget.onSharePdfAndMessage,
                    icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.redAccent),
                    label: const Text(
                      "Compartir PDF + Texto",
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.isDark ? Colors.white : Colors.black87,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: widget.onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: widget.isDark ? 0 : 4,
              ),
              icon: const Icon(Icons.send, size: 20),
              label: Text(
                hasValidPhone
                    ? "Enviar al +51 $cleanPhone"
                    : "Elegir Contacto en WhatsApp",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          children: [
            // Cabecera del Modal con Selector de Modo (Burbuja vs Editor)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 24),
                    const SizedBox(width: 8),
                    Text(
                      "Revisión Final",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Botón alternador entre Vista de Burbuja y Modo Edición
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _isEditing = !_isEditing);
                      },
                      icon: Icon(_isEditing ? Icons.visibility_outlined : Icons.edit_note_rounded, size: 18),
                      label: Text(
                        _isEditing ? "✓ Listo" : "✏️ Editar texto",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFF00A884),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 22, color: widget.isDark ? Colors.white70 : Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            Divider(height: 8, color: widget.isDark ? Colors.white12 : Colors.grey[200]),

            // Contenedor Visual con Scrollbar y BouncingScrollPhysics
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: _isEditing
                      ? (widget.isDark ? const Color(0xFF14141E) : Colors.grey[100])
                      : chatBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.isDark ? Colors.white12 : Colors.grey.shade300,
                    width: 0.8,
                  ),
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  radius: const Radius.circular(8),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(left: 14, right: 14, top: 14, bottom: 36),
                    child: _isEditing
                        ? TextField(
                            controller: widget.messageCtrl,
                            maxLines: null,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.45,
                              color: widget.isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: const InputDecoration.collapsed(
                              hintText: "Escribe o edita el mensaje...",
                            ),
                            onChanged: (text) {
                              widget.onMessageChanged?.call(text);
                              setState(() {});
                            },
                          )
                        : _buildWhatsAppRealisticBubble(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye la burbuja realista de WhatsApp con RichText markdown y metadatos
  Widget _buildWhatsAppRealisticBubble() {
    final bubbleColor = widget.isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3);
    final bubbleTextColor = widget.isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21);

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SelectableText.rich(
              TextSpan(
                children: _parseWhatsAppMarkdown(
                  widget.messageCtrl.text,
                  TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: bubbleTextColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('h:mm a').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isDark ? Colors.white60 : Colors.black45,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.done_all,
                  size: 15,
                  color: Color(0xFF53BDEB),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
