import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

class WhatsAppPreviewModal extends StatefulWidget {
  final String? initialClientName;
  final String? initialClientPhone;
  final bool isDark;
  final Map<String, dynamic>? cuota;
  final List<dynamic>? multipleCuotas;
  final double? totalDebt;
  final String? operationTitle;

  const WhatsAppPreviewModal({
    super.key,
    this.initialClientName,
    this.initialClientPhone,
    required this.isDark,
    this.cuota,
    this.multipleCuotas,
    this.totalDebt,
    this.operationTitle,
  });

  /// Abre el estudio de WhatsApp para una cuota individual
  static Future<void> showCuotaReminder({
    required BuildContext context,
    required Map<String, dynamic> cuota,
    String? clientName,
    String? clientPhone,
    required bool isDark,
    String? operationTitle,
  }) {
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (_) => WhatsAppPreviewModal(
        cuota: cuota,
        initialClientName: clientName,
        initialClientPhone: clientPhone,
        isDark: isDark,
        operationTitle: operationTitle,
      ),
    );
  }

  /// Abre el estudio de WhatsApp para múltiples cuotas vencidas (desde perfil del cliente)
  static Future<void> showOverdueSummary({
    required BuildContext context,
    required List<dynamic> overdueCuotas,
    required double totalDebt,
    String? clientName,
    String? clientPhone,
    required bool isDark,
  }) {
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (_) => WhatsAppPreviewModal(
        multipleCuotas: overdueCuotas,
        totalDebt: totalDebt,
        initialClientName: clientName,
        initialClientPhone: clientPhone,
        isDark: isDark,
      ),
    );
  }

  @override
  State<WhatsAppPreviewModal> createState() => _WhatsAppPreviewModalState();
}

class _WhatsAppPreviewModalState extends State<WhatsAppPreviewModal> {
  late TextEditingController _phoneCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _messageCtrl;

  String _activeTemplate = 'formal';

  @override
  void initState() {
    super.initState();
    String phone = widget.initialClientPhone?.trim() ?? "";
    if (phone == "000000000" || phone == "00000000" || phone.replaceAll('0', '').isEmpty) {
      phone = "";
    }
    _phoneCtrl = TextEditingController(text: phone);
    _nameCtrl = TextEditingController(text: widget.initialClientName?.trim() ?? "Estimado cliente");
    _messageCtrl = TextEditingController(text: _generateInitialMessage('formal'));
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  String _generateInitialMessage(String templateType) {
    final name = _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : "Estimado cliente";

    // 1. Caso Cuota Individual
    if (widget.cuota != null) {
      final c = widget.cuota!;
      final cuotaNum = c['numero_cuota'] ?? 1;
      final double totalCuota = (num.tryParse(c['monto'].toString()) ?? 0.0).toDouble();
      final double pagado = (num.tryParse((c['monto_pagado'] ?? 0.0).toString()) ?? 0.0).toDouble();
      final double montoOriginal = (num.tryParse((c['monto_original'] ?? totalCuota).toString()) ?? totalCuota).toDouble();
      final double moraMonto = (num.tryParse((c['mora_monto'] ?? 0.0).toString()) ?? 0.0).toDouble();
      final double saldoFalta = totalCuota - pagado > 0 ? totalCuota - pagado : 0.0;

      final DateTime? due = DateTime.tryParse(c['fecha_vencimiento']?.toString().split('T').first ?? "");
      final String dateStr = due != null ? DateFormat('dd/MM/yyyy').format(due) : (c['fecha_vencimiento']?.toString() ?? "");
      final today = DateTime.now();
      final int daysDiff = due != null ? DateTime(today.year, today.month, today.day).difference(DateTime(due.year, due.month, due.day)).inDays : 0;
      final bool isVencida = daysDiff > 0 && saldoFalta > 0.01;

      if (templateType == 'cordial') {
        return "Hola $name 👋. Le saludamos cordialmente de la tienda. Le recordamos que su cuota #$cuotaNum por ${AppCurrency.format(totalCuota)} vence el $dateStr. Agradecemos su puntualidad. ¡Que tenga un excelente día!";
      }

      if (templateType == 'cuentas') {
        return "Hola $name 👋. Le compartimos los canales oficiales para realizar su abono de la cuota #$cuotaNum (${AppCurrency.format(saldoFalta)}):\n\n"
               "📱 *Yape / Plin:* Al número registrado de la tienda.\n"
               "🏦 *Transferencia Bancaria:* Solicitar número de cuenta o CCI.\n"
               "🏪 *Tienda física:* En nuestro horario habitual.\n\n"
               "Una vez realizado el pago, por favor envíenos la constancia para registrarla en su estado de cuenta. ¡Muchas gracias!";
      }

      // Template Formal / Cobranza detallada
      final sb = StringBuffer();
      sb.writeln("Hola $name 👋. Te saludamos de la tienda.");
      if (isVencida) {
        sb.writeln("\n⚠️ *RECORDATORIO DE CUOTA VENCIDA*");
        sb.writeln("Le informamos que su *Cuota #$cuotaNum* venció el $dateStr (hace $daysDiff días).");
      } else {
        sb.writeln("\n📅 *RECORDATORIO DE PAGO*");
        sb.writeln("Le recordamos que su *Cuota #$cuotaNum* vence el $dateStr.");
      }

      if (moraMonto > 0.01) {
        sb.writeln("▪ Total Cuota: *${AppCurrency.format(totalCuota)}* (Orig: ${AppCurrency.format(montoOriginal)} + Mora: ${AppCurrency.format(moraMonto)} = Total: ${AppCurrency.format(totalCuota)})");
      } else {
        sb.writeln("▪ Total Cuota: *${AppCurrency.format(totalCuota)}*");
      }

      if (pagado > 0.01) {
        sb.writeln("▪ Estado: ${isVencida ? '🔴 Vencida hace $daysDiff d • Pago Parcial' : '🟠 Pago Parcial'}");
        sb.writeln("▪ Abonado: ${AppCurrency.format(pagado)} ✅ | *Falta cancelar: ${AppCurrency.format(saldoFalta)}* 🔴");
      } else {
        sb.writeln("▪ *Monto exigible: ${AppCurrency.format(saldoFalta)}* 🔴");
      }

      sb.writeln("\nPuede realizar su abono mediante Yape, Plin o directamente en tienda física. Si ya efectuó el pago, por favor haga caso omiso a este mensaje. ¡Muchas gracias!");
      return sb.toString();
    }

    // 2. Caso Múltiples Cuotas Vencidas (desde el Perfil del Cliente)
    final sb = StringBuffer();
    sb.writeln("Hola $name 👋. Te saludamos de la tienda.");
    final double totalD = widget.totalDebt ?? 0.0;
    final int count = widget.multipleCuotas?.length ?? 0;

    if (count > 0) {
      sb.writeln("\n⚠️ *ESTADO DE CUENTA: CUOTAS EN OBSERVACIÓN*");
      sb.writeln("Le escribimos para recordarle que mantiene *$count cuota(s) pendiente(s)* por un saldo total exigible de *${AppCurrency.format(totalD)}*:\n");

      for (var raw in widget.multipleCuotas!) {
        final c = raw is Map ? raw : (raw as dynamic);
        final numCuota = c['numero_cuota'] ?? c['installmentNumber'] ?? '';
        final monto = (c['monto'] ?? c['amount'] ?? 0.0).toDouble();
        final montoOriginal = (c['monto_original'] ?? c['montoOriginal'] ?? monto).toDouble();
        final mora = (c['mora_monto'] ?? c['moraMonto'] ?? 0.0).toDouble();
        final pagado = (c['monto_pagado'] ?? c['montoPagado'] ?? 0.0).toDouble();
        final due = c['fecha_vencimiento'] ?? c['dueDate'] ?? '';
        final falta = (monto - pagado) > 0 ? (monto - pagado) : 0.0;
        final String moraDetail = mora > 0.01 
            ? " (Orig: ${AppCurrency.format(montoOriginal)} + Mora: ${AppCurrency.format(mora)} = Total: ${AppCurrency.format(monto)})" 
            : "";

        final DateTime? dueDt = DateTime.tryParse(due.toString().split('T').first);
        final int daysOver = dueDt != null 
            ? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).difference(DateTime(dueDt.year, dueDt.month, dueDt.day)).inDays 
            : 0;

        if (pagado > 0.01) {
          if (daysOver > 0) {
            sb.writeln("🔴 Cuota #$numCuota: *${AppCurrency.format(monto)}*$moraDetail - Vencida hace $daysOver d • Pago Parcial (Abonado: ${AppCurrency.format(pagado)} | Falta: ${AppCurrency.format(falta)})");
          } else {
            sb.writeln("🟠 Cuota #$numCuota: *${AppCurrency.format(monto)}*$moraDetail (Vence: ${due.toString().split('T').first}) - Pago Parcial (Abonado: ${AppCurrency.format(pagado)} | Falta: ${AppCurrency.format(falta)})");
          }
        } else {
          if (daysOver > 0) {
            sb.writeln("🔴 Cuota #$numCuota: *${AppCurrency.format(monto)}*$moraDetail - Vencida hace $daysOver d");
          } else {
            sb.writeln("⏳ Cuota #$numCuota: *${AppCurrency.format(monto)}*$moraDetail (Vence: ${due.toString().split('T').first})");
          }
        }
      }
    } else {
      sb.writeln("\nLe escribimos para recordarle que cuenta con un saldo pendiente de *${AppCurrency.format(totalD)}*.");
    }

    sb.writeln("\nAgradeceremos su pronta regularización vía Yape, Plin o en tienda física. ¡Muchas gracias por su atención!");
    return sb.toString();
  }

  void _applyTemplate(String type) {
    setState(() {
      _activeTemplate = type;
      _messageCtrl.text = _generateInitialMessage(type);
    });
  }

  Future<void> _sendWhatsApp() async {
    final rawPhone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (rawPhone.length < 9) {
      CustomSnackBar.show(context, message: "Ingresa un número de celular válido (mínimo 9 dígitos).", isError: true);
      return;
    }

    final waPhone = rawPhone.startsWith('51') ? rawPhone : '51$rawPhone';
    final msg = _messageCtrl.text.trim();
    if (msg.isEmpty) {
      CustomSnackBar.show(context, message: "El mensaje no puede estar vacío.", isError: true);
      return;
    }

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
    final cardBg = isDark ? const Color(0xFF1E1E28) : Colors.grey[100]!;
    final textColor = isDark ? Colors.white : Colors.black87;

    return InteractiveSheetWrapper(
      title: "Estudio de WhatsApp",
      icon: Icons.chat_rounded,
      iconColor: const Color(0xFF25D366),
      backgroundColor: surfaceColor,
      applyEffectiveBottomPadding: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Revisa o edita libremente el mensaje antes de enviarlo por WhatsApp.",
              style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(height: 14),

            // Campos de Cliente y Celular
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _nameCtrl,
                    onChanged: (_) {
                      setState(() {
                        _messageCtrl.text = _generateInitialMessage(_activeTemplate);
                      });
                    },
                    style: TextStyle(color: textColor, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: "Cliente",
                      prefixIcon: const Icon(Icons.person_outline, size: 18),
                      filled: true,
                      fillColor: cardBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: "Celular (WhatsApp)",
                      hintText: "Ej. 987654321",
                      prefixIcon: const Icon(Icons.phone_android, size: 18, color: Color(0xFF25D366)),
                      filled: true,
                      fillColor: cardBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Selector de Plantillas Rápidas
            Text(
              "PLANTILLAS SUGERIDAS",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text("Cobranza / Desglose", style: TextStyle(fontSize: 11)),
                  selected: _activeTemplate == 'formal',
                  onSelected: (_) => _applyTemplate('formal'),
                  selectedColor: const Color(0xFF25D366).withValues(alpha: 0.25),
                ),
                ChoiceChip(
                  label: const Text("Recordatorio Amable", style: TextStyle(fontSize: 11)),
                  selected: _activeTemplate == 'cordial',
                  onSelected: (_) => _applyTemplate('cordial'),
                  selectedColor: const Color(0xFF25D366).withValues(alpha: 0.25),
                ),
                ChoiceChip(
                  label: const Text("Cuentas de Abono", style: TextStyle(fontSize: 11)),
                  selected: _activeTemplate == 'cuentas',
                  onSelected: (_) => _applyTemplate('cuentas'),
                  selectedColor: const Color(0xFF25D366).withValues(alpha: 0.25),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Área de Edición Multilínea
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "MENSAJE EDITABLE (ENVIARÁS EXACTAMENTE ESTE TEXTO):",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _messageCtrl.text));
                    CustomSnackBar.show(context, message: "Texto copiado al portapapeles");
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text("Copiar", style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
            const SizedBox(height: 4),

            TextField(
              controller: _messageCtrl,
              maxLines: 7,
              minLines: 4,
              style: TextStyle(fontSize: 13, height: 1.4, color: textColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: cardBg,
                hintText: "Escribe o edita el mensaje aquí...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF25D366), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 18),

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
                      style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.grey[300] : Colors.grey[700]),
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
                      backgroundColor: const Color(0xFF25D366),
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

