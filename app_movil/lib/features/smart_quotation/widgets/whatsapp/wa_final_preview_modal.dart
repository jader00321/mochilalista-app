import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class WaFinalPreviewModal extends StatefulWidget {
  final bool isDark;
  final String phone;
  final TextEditingController messageCtrl;
  final VoidCallback onSend;

  const WaFinalPreviewModal({
    super.key,
    required this.isDark,
    required this.phone,
    required this.messageCtrl,
    required this.onSend,
  });

  @override
  State<WaFinalPreviewModal> createState() => _WaFinalPreviewModalState();
}

class _WaFinalPreviewModalState extends State<WaFinalPreviewModal> {
  bool allowFinalEdit = false;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = widget.isDark ? const Color(0xFF23232F) : Colors.white;

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.88,
      backgroundColor: surfaceColor,
      applyEffectiveBottomPadding: true,
      bottomAction: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: widget.onSend,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: widget.isDark ? 0 : 5,
          ),
          icon: const Icon(Icons.send, size: 22),
          label: Text(
            "Enviar al +51 ${widget.phone}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Revisión Final",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 26, color: widget.isDark ? Colors.white : Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Divider(height: 20, color: widget.isDark ? Colors.white10 : Colors.grey[200]),
            
            SwitchListTile(
              title: Text(
                "Habilitar edición final",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
              value: allowFinalEdit,
              activeThumbColor: const Color(0xFF00A884),
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => allowFinalEdit = v),
            ),
            const SizedBox(height: 10),
            
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF14141C) : Colors.grey[100], 
                  borderRadius: BorderRadius.circular(16), 
                  border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade300),
                ),
                child: TextField(
                  controller: widget.messageCtrl,
                  enabled: allowFinalEdit,
                  maxLines: null,
                  style: TextStyle(fontSize: 16, height: 1.4, color: widget.isDark ? Colors.white : Colors.black87),
                  decoration: const InputDecoration.collapsed(hintText: ""),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
