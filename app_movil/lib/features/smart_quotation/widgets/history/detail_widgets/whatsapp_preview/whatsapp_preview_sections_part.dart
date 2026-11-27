part of '../whatsapp_preview_modal.dart';

extension _WhatsAppPreviewSectionsPart on _WhatsAppPreviewModalState {
  void _showEditContactModal(BuildContext context, bool isDark) {
    final tempNameCtrl = TextEditingController(text: _nameCtrl.text);
    final tempPhoneCtrl = TextEditingController(text: _phoneCtrl.text);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: Color(0xFF25D366)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Editar Contacto",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tempNameCtrl,
              decoration: const InputDecoration(
                labelText: "Nombre del Cliente",
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tempPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Número de Celular",
                prefixIcon: Icon(Icons.phone_android),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              _updateState(() {
                _nameCtrl.text = tempNameCtrl.text.trim();
                _phoneCtrl.text = tempPhoneCtrl.text.trim();
                _messageCtrl.text = _generateMessage();
              });
              Navigator.pop(ctx);
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  Future<void> _sendWhatsApp() async {
    final rawPhone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (rawPhone.length < 9) {
      AppFeedbackHelper.showError(
        context,
        "Ingresa un número de celular válido (mínimo 9 dígitos).",
      );
      return;
    }

    final msg = _messageCtrl.text.trim();
    if (msg.isEmpty) {
      AppFeedbackHelper.showError(context, "El mensaje no puede estar vacío.");
      return;
    }

    final url = WhatsAppUriBuilder.buildSendUri(
      phone: _phoneCtrl.text,
      message: msg,
    );
    Navigator.pop(context);

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          AppFeedbackHelper.showError(context, "No se pudo abrir WhatsApp.");
        }
      }
    } catch (e) {
      if (mounted) {
        AppFeedbackHelper.showError(context, "Error al abrir WhatsApp: $e");
      }
    }
  }

  Widget _buildToneCard(String id, String label, bool isDark) {
    final isSelected = _activeTemplate == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _applyTemplate(id),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(
                    0xFF25D366,
                  ).withValues(alpha: isDark ? 0.25 : 0.15)
                : (isDark ? const Color(0xFF1E1E28) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF25D366)
                  : (isDark ? Colors.white12 : Colors.grey.shade300),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected
                  ? (isDark ? Colors.greenAccent : const Color(0xFF1B5E20))
                  : (isDark ? Colors.grey[300] : Colors.grey[800]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModuleChip(
    String label,
    bool isChecked,
    ValueChanged<bool> onToggle,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(
          isChecked ? "✓ $label" : "+ $label",
          style: TextStyle(
            fontSize: 11,
            fontWeight: isChecked ? FontWeight.bold : FontWeight.w600,
            color: isChecked
                ? (isDark ? Colors.greenAccent : const Color(0xFF1B5E20))
                : (isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
        ),
        selected: isChecked,
        onSelected: onToggle,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: isDark
            ? const Color(0xFF1A1A22)
            : Colors.grey.shade100,
        selectedColor: const Color(
          0xFF25D366,
        ).withValues(alpha: isDark ? 0.25 : 0.15),
        side: BorderSide(
          color: isChecked
              ? const Color(0xFF25D366)
              : (isDark ? Colors.white12 : Colors.grey.shade300),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildContactHeaderBar({
    required BuildContext context,
    required bool isDark,
    required Color cardBg,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_rounded, size: 18, color: Color(0xFF25D366)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _nameCtrl.text.trim().isNotEmpty
                  ? _nameCtrl.text.trim()
                  : "Cliente",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 145),
            child: InkWell(
              onTap: () => _showEditContactModal(context, isDark),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.phone_android,
                        size: 13,
                        color: Color(0xFF25D366),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _phoneCtrl.text.trim().isNotEmpty
                            ? _phoneCtrl.text.trim()
                            : "Sin celular",
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit,
                        size: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatesCarousel(bool isDark) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 34),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildToneCard('formal', '📋 Cobranza Formal', isDark),
            _buildToneCard('cordial', '🤝 Recordatorio Amable', isDark),
            _buildToneCard('mora', '🚨 Aviso con Mora', isDark),
            _buildToneCard('resumen', '⚡ Resumen Breve', isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleChipsCarousel(bool isDark) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 30),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildModuleChip("Desglose Cuotas", _showDesglose, (val) {
              _updateState(() {
                _showDesglose = val;
                _messageCtrl.text = _generateMessage();
              });
            }, isDark),
            _buildModuleChip("Detalle Mora", _showMora, (val) {
              _updateState(() {
                _showMora = val;
                _messageCtrl.text = _generateMessage();
              });
            }, isDark),
            _buildModuleChip("Cuentas Abono", _showCuentas, (val) {
              _updateState(() {
                _showCuentas = val;
                _messageCtrl.text = _generateMessage();
              });
            }, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageHeaderRow(BuildContext context, bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          Text(
            "MENSAJE EDITABLE:",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: () {
                  _updateState(() {
                    _messageCtrl.text = _generateMessage();
                  });
                  AppFeedbackHelper.showSuccess(context, "Mensaje restaurado");
                },
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text(
                  "Restaurar",
                  style: TextStyle(fontSize: 11.5),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  foregroundColor: isDark ? Colors.blue[300] : Colors.blue[800],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  ClipboardHelper.copyWithFeedback(
                    context,
                    _messageCtrl.text,
                    feedbackMessage: "Texto copiado al portapapeles",
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text("Copiar", style: TextStyle(fontSize: 11.5)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  foregroundColor: isDark
                      ? Colors.tealAccent
                      : Colors.teal.shade800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageEditor(
    BuildContext context,
    bool isDark,
    Color cardBg,
    Color textColor,
  ) {
    return TextField(
      controller: _messageCtrl,
      maxLines: 11,
      minLines: 7,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      style: TextStyle(fontSize: 13, height: 1.4, color: textColor),
      decoration: InputDecoration(
        filled: true,
        fillColor: cardBg,
        hintText: "Escribe o edita el mensaje aquí...",
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF25D366), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildFooterActionsRow(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(
                color: isDark ? Colors.white24 : Colors.grey[400]!,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "Cancelar",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _sendWhatsApp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.send_rounded, size: 18),
                  SizedBox(width: 8),
                  Text(
                    "Enviar por WhatsApp",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
