import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

class CuotaReminderModal extends StatefulWidget {
  final Map<String, dynamic> cuota;
  final String dateFormatted;
  final String? initialClientName;
  final String? initialClientPhone;
  final bool isDark;

  const CuotaReminderModal({
    super.key,
    required this.cuota,
    required this.dateFormatted,
    this.initialClientName,
    this.initialClientPhone,
    required this.isDark,
  });

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> cuota,
    required String dateFormatted,
    String? clientName,
    String? clientPhone,
    required bool isDark,
  }) {
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (_) => CuotaReminderModal(
        cuota: cuota,
        dateFormatted: dateFormatted,
        initialClientName: clientName,
        initialClientPhone: clientPhone,
        isDark: isDark,
      ),
    );
  }

  @override
  State<CuotaReminderModal> createState() => _CuotaReminderModalState();
}

class _CuotaReminderModalState extends State<CuotaReminderModal> {
  late TextEditingController _phoneCtrl;
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    String phone = widget.initialClientPhone?.trim() ?? "";
    if (phone == "000000000") phone = "";
    _phoneCtrl = TextEditingController(text: phone);
    _nameCtrl = TextEditingController(text: widget.initialClientName?.trim() ?? "Estimado cliente");
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  String _buildMessage() {
    final name = _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : "Estimado cliente";
    final cuotaNum = widget.cuota['numero_cuota'];
    final monto = AppCurrency.format((widget.cuota['monto'] as num).toDouble());
    return "Hola $name 👋. Le recordamos que su cuota #$cuotaNum por $monto vence el ${widget.dateFormatted}. Puede realizar su pago mediante Yape, Plin o en tienda física. ¡Muchas gracias!";
  }

  Future<void> _sendWhatsApp() async {
    final rawPhone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (rawPhone.length < 9) {
      CustomSnackBar.show(context, message: "Ingresa un número de celular válido (mínimo 9 dígitos).", isError: true);
      return;
    }

    final waPhone = rawPhone.startsWith('51') ? rawPhone : '51$rawPhone';
    final msg = _buildMessage();
    final url = Uri.parse("https://wa.me/$waPhone?text=${Uri.encodeComponent(msg)}");

    Navigator.pop(context);

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          CustomSnackBar.show(context, message: "No se pudo abrir WhatsApp.", isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, message: "Error al abrir WhatsApp: $e", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cuotaNum = widget.cuota['numero_cuota'];
    final montoFormatted = AppCurrency.format((widget.cuota['monto'] as num).toDouble());

    return InteractiveSheetWrapper(
      title: "Recordatorio de Cuota",
      icon: Icons.chat_outlined,
      iconColor: Colors.green,
      backgroundColor: surfaceColor,
      applyEffectiveBottomPadding: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Confirma los datos antes de abrir WhatsApp",
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            // Tarjeta de Resumen de la Cuota
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.orange.withValues(alpha: 0.12) : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.orange.withValues(alpha: 0.35) : Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isDark ? Colors.orange.withValues(alpha: 0.25) : Colors.orange.shade100,
                    child: Text(
                      "#$cuotaNum",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.orange[300] : Colors.orange[900],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Cuota #$cuotaNum · $montoFormatted",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Vence: ${widget.dateFormatted}",
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Campo Nombre del Cliente
            TextField(
              controller: _nameCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                labelText: "Nombre del Cliente",
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                prefixIcon: Icon(Icons.person_outline, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E28) : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),

            // Campo Celular
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                labelText: "Número de Celular (WhatsApp)",
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                hintText: "Ej. 987654321",
                hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                prefixIcon: const Icon(Icons.phone_android, color: Colors.green),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E28) : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),

            // Vista Previa del Mensaje
            Text(
              "VISTA PREVIA DEL MENSAJE",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E28) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
              ),
              child: Text(
                _buildMessage(),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Botones de Acción
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[400]!),
                    ),
                    child: Text(
                      "Cancelar",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _sendWhatsApp,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text(
                      "Enviar por WhatsApp",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
