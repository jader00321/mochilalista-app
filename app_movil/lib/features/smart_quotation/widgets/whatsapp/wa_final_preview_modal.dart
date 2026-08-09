import 'package:flutter/material.dart';

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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(color: widget.isDark ? const Color(0xFF23232F) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Revisión Final", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: widget.isDark ? Colors.white : Colors.black87)),
                IconButton(icon: Icon(Icons.close, size: 28, color: widget.isDark ? Colors.white : Colors.black87), onPressed: () => Navigator.pop(context))
              ],
            ),
            Divider(height: 20, color: widget.isDark ? Colors.white10 : Colors.grey[200]),
            
            SwitchListTile(
              title: Text("Habilitar edición final", style: TextStyle(fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87)),
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
                  border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade300)
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
            const SizedBox(height: 24),
            
            SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: widget.onSend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: widget.isDark ? 0 : 5
                  ),
                  icon: const Icon(Icons.send, size: 24),
                  label: Text("Enviar al +51 ${widget.phone}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
