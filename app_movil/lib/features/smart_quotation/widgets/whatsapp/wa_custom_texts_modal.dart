import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/smart_quotation/models/whatsapp_config_model.dart';
import 'package:app_movil/features/smart_quotation/services/whatsapp_preferences_service.dart';

/// Modal interactivo para editar, guardar y restaurar frases personalizadas de
/// introducción y despedida / firma del mensaje de WhatsApp indexado por contexto.
class WaCustomTextsModal extends StatefulWidget {
  final WhatsAppConfig config;
  final String contextKey;
  final bool isDark;
  final Function(String? newIntro, String? newClosing) onSaved;

  const WaCustomTextsModal({
    super.key,
    required this.config,
    this.contextKey = 'quote',
    required this.isDark,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required WhatsAppConfig config,
    String contextKey = 'quote',
    required bool isDark,
    required Function(String? newIntro, String? newClosing) onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WaCustomTextsModal(
        config: config,
        contextKey: contextKey,
        isDark: isDark,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<WaCustomTextsModal> createState() => _WaCustomTextsModalState();
}

class _WaCustomTextsModalState extends State<WaCustomTextsModal> {
  late final TextEditingController _introCtrl;
  late final TextEditingController _closingCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _introCtrl = TextEditingController(text: widget.config.customIntro ?? "");
    _closingCtrl = TextEditingController(text: widget.config.customClosing ?? "");
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _closingCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave({bool saveAsDefault = false}) async {
    setState(() => _isSaving = true);
    final String? intro = _introCtrl.text.trim().isEmpty ? null : _introCtrl.text.trim();
    final String? closing = _closingCtrl.text.trim().isEmpty ? null : _closingCtrl.text.trim();

    widget.config.customIntro = intro;
    widget.config.customClosing = closing;

    if (saveAsDefault) {
      await WhatsAppPreferencesService.saveCustomTexts(
        customIntro: intro,
        customClosing: closing,
        contextKey: widget.contextKey,
      );
      await WhatsAppPreferencesService.saveDefaultConfig(
        widget.config,
        contextKey: widget.contextKey,
      );
    }

    widget.onSaved(intro, closing);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
      CustomSnackBar.show(
        context,
        message: saveAsDefault
            ? "Frases guardadas como predeterminadas para este tipo de operación"
            : "Frases aplicadas a este mensaje",
        isError: false,
      );
    }
  }

  Future<void> _handleRestore() async {
    setState(() {
      _introCtrl.clear();
      _closingCtrl.clear();
    });
    await WhatsAppPreferencesService.saveCustomTexts(
      customIntro: null,
      customClosing: null,
      contextKey: widget.contextKey,
    );
    widget.config.customIntro = null;
    widget.config.customClosing = null;
    widget.onSaved(null, null);

    if (mounted) {
      Navigator.pop(context);
      CustomSnackBar.show(context, message: "Plantilla original restaurada para este contexto", isError: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final cardColor = widget.isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    String contextBadge;
    switch (widget.contextKey) {
      case 'loan':
        contextBadge = "🏦 Para Préstamos Personales";
        break;
      case 'sale':
        contextBadge = "🛍️ Para Ventas y Comprobantes";
        break;
      case 'quote':
      default:
        contextBadge = "📄 Para Cotizaciones y Proformas";
        break;
    }

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset > 0 ? bottomInset + 20 : 30,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.edit_note, color: Color(0xFF00A884), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Personalizar Intro y Firma",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: textColor,
                        ),
                      ),
                      Text(
                        contextBadge,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00A884),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Configura frases únicas para esta situación sin afectar las plantillas de otras operaciones.",
              style: TextStyle(
                fontSize: 13,
                color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "Frase de Introducción (Opcional):",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _introCtrl,
              maxLines: 2,
              style: TextStyle(fontSize: 14, color: textColor),
              decoration: InputDecoration(
                hintText: widget.contextKey == 'loan'
                    ? "Ej: Te comparto el detalle formal del préstamo personal registrado:"
                    : (widget.contextKey == 'sale'
                        ? "Ej: A continuación, te comparto el comprobante de tu compra:"
                        : "Ej: Aquí te envío la cotización detallada de los productos solicitados:"),
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: widget.isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                filled: true,
                fillColor: widget.isDark ? const Color(0xFF14141C) : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Frase de Despedida / Firma (Opcional):",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _closingCtrl,
              maxLines: 2,
              style: TextStyle(fontSize: 14, color: textColor),
              decoration: InputDecoration(
                hintText: "Ej: ¡Quedamos muy atentos a tu confirmación! Cualquier consulta avísanos.",
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: widget.isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                filled: true,
                fillColor: widget.isDark ? const Color(0xFF14141C) : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _handleRestore,
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text("Restaurar Original"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _handleSave(saveAsDefault: true),
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text("Guardar Siempre"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A884),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
