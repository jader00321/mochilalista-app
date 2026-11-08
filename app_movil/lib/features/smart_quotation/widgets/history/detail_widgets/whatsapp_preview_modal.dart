import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/utils/cuota_date_helper.dart';
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
  bool _showDesglose = true;
  bool _showMora = true;
  bool _showCuentas = false;

  @override
  void initState() {
    super.initState();
    String phone = widget.initialClientPhone?.trim() ?? "";
    if (phone == "000000000" || phone == "00000000" || phone.replaceAll('0', '').isEmpty) {
      phone = "";
    }
    _phoneCtrl = TextEditingController(text: phone);
    _nameCtrl = TextEditingController(text: widget.initialClientName?.trim() ?? "Estimado cliente");
    _messageCtrl = TextEditingController(text: _generateMessage(templateType: 'formal'));
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  double _calculateExigibleTotal() {
    if (widget.cuota != null) {
      final c = widget.cuota!;
      final double totalCuota = (num.tryParse(c['monto'].toString()) ?? 0.0).toDouble();
      final double pagado = (num.tryParse((c['monto_pagado'] ?? 0.0).toString()) ?? 0.0).toDouble();
      return totalCuota - pagado > 0 ? totalCuota - pagado : 0.0;
    }

    if (widget.multipleCuotas != null && widget.multipleCuotas!.isNotEmpty) {
      double sum = 0.0;
      for (var raw in widget.multipleCuotas!) {
        final c = raw is Map ? raw : (raw as dynamic);
        final monto = (num.tryParse((c['monto'] ?? c['amount'] ?? 0.0).toString()) ?? 0.0).toDouble();
        final pagado = (num.tryParse((c['monto_pagado'] ?? c['montoPagado'] ?? 0.0).toString()) ?? 0.0).toDouble();
        final falta = monto - pagado > 0 ? monto - pagado : 0.0;
        sum += falta;
      }
      if (sum > 0.01) return sum;
    }

    return widget.totalDebt ?? 0.0;
  }

  String _generateMessage({
    String? templateType,
    bool? showDesglose,
    bool? showMora,
    bool? showCuentas,
  }) {
    final tType = templateType ?? _activeTemplate;
    final sDesglose = showDesglose ?? _showDesglose;
    final sMora = showMora ?? _showMora;
    final sCuentas = showCuentas ?? _showCuentas;

    final name = _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : "Estimado cliente";
    final double totalExigible = _calculateExigibleTotal();

    const String cuentasBlock = "\n\n💳 *Canales oficiales de abono:*\n"
        "📱 *Yape / Plin:* Al número registrado de la tienda.\n"
        "🏦 *Transferencia Bancaria:* Solicitar número de cuenta o CCI.\n"
        "🏪 *Tienda física:* En nuestro horario habitual.\n\n"
        "Una vez realizado el pago, por favor envíenos la constancia para registrarla en su estado de cuenta. ¡Muchas gracias!";

    // =========================================================================
    // 1. CASO CUOTA INDIVIDUAL
    // =========================================================================
    if (widget.cuota != null) {
      final c = widget.cuota!;
      final cuotaNum = c['numero_cuota'] ?? 1;
      final double totalCuota = (num.tryParse(c['monto'].toString()) ?? 0.0).toDouble();
      final double pagado = (num.tryParse((c['monto_pagado'] ?? 0.0).toString()) ?? 0.0).toDouble();
      final double montoOriginal = (num.tryParse((c['monto_original'] ?? totalCuota).toString()) ?? totalCuota).toDouble();
      final double moraMonto = (num.tryParse((c['mora_monto'] ?? 0.0).toString()) ?? 0.0).toDouble();
      final double saldoFalta = totalCuota - pagado > 0 ? totalCuota - pagado : 0.0;

      final dateInfo = CuotaDateHelper.evaluate(c['fecha_vencimiento']);
      final int daysDiff = dateInfo.daysOverdue;
      final bool isVencida = dateInfo.isPast && saldoFalta > 0.01;

      if (tType == 'cordial') {
        final sb = StringBuffer();
        sb.write("Hola $name 👋. Le saludamos cordialmente de la tienda. Le recordamos que su cuota #$cuotaNum por ${AppCurrency.format(totalCuota)} ${dateInfo.prefix.toLowerCase()} ${dateInfo.dateFormatted}. Agradecemos su puntualidad. ¡Que tenga un excelente día!");
        if (sCuentas) sb.write(cuentasBlock);
        return sb.toString();
      }

      if (tType == 'mora') {
        final sb = StringBuffer();
        sb.writeln("Hola $name 👋. Te saludamos de la tienda.");
        sb.writeln("\n🚨 *AVISO URGENTE: CUOTA EN MOROSIDAD*");
        sb.write("Le informamos que su *Cuota #$cuotaNum* por ${AppCurrency.format(totalCuota)} venció el ${dateInfo.dateFormatted} (hace $daysDiff ${daysDiff == 1 ? 'día' : 'días'})");
        if (sMora && moraMonto > 0.01) {
          sb.writeln(" e incluye un recargo por mora acumulada de ${AppCurrency.format(moraMonto)}.");
        } else {
          sb.writeln(".");
        }
        sb.writeln("Le solicitamos regularizar su pago a la brevedad posible para evitar el incremento de recargos adicionales.");
        if (sCuentas) {
          sb.write(cuentasBlock);
        } else {
          sb.write("\nPuede realizar su abono por Yape, Plin o en tienda física. ¡Muchas gracias!");
        }
        return sb.toString();
      }

      if (tType == 'resumen') {
        final sb = StringBuffer();
        sb.write("Hola $name 👋. Le recordamos su cuota #$cuotaNum (${dateInfo.fullLabel}) por un saldo exigible de *${AppCurrency.format(saldoFalta)}*.");
        if (sCuentas) sb.write(cuentasBlock);
        return sb.toString();
      }

      // Template Formal / Cobranza detallada (default)
      final sb = StringBuffer();
      sb.writeln("Hola $name 👋. Te saludamos de la tienda.");
      if (isVencida) {
        sb.writeln("\n⚠️ *RECORDATORIO DE CUOTA VENCIDA*");
        sb.writeln("Le informamos que su *Cuota #$cuotaNum* venció el ${dateInfo.dateFormatted} (hace $daysDiff ${daysDiff == 1 ? 'día' : 'días'}).");
      } else {
        sb.writeln("\n📅 *RECORDATORIO DE PAGO*");
        sb.writeln("Le recordamos que su *Cuota #$cuotaNum* ${dateInfo.prefix.toLowerCase()} ${dateInfo.dateFormatted}.");
      }

      if (sMora && moraMonto > 0.01) {
        sb.writeln("▪ Total Cuota: *${AppCurrency.format(totalCuota)}* (Base: ${AppCurrency.format(montoOriginal)} + Mora: ${AppCurrency.format(moraMonto)})");
      } else {
        sb.writeln("▪ Total Cuota: *${AppCurrency.format(totalCuota)}*");
      }

      if (pagado > 0.01) {
        sb.writeln("▪ Estado: ${isVencida ? '🔴 Vencida hace $daysDiff d • Pago Parcial' : '🟠 Pago Parcial'}");
        sb.writeln("▪ Abonado: ${AppCurrency.format(pagado)} ✅ | *Falta cancelar: ${AppCurrency.format(saldoFalta)}* 🔴");
      } else {
        sb.writeln("▪ *Monto exigible: ${AppCurrency.format(saldoFalta)}* 🔴");
      }

      if (sCuentas) {
        sb.write(cuentasBlock);
      } else {
        sb.writeln("\nPuede realizar su abono mediante Yape, Plin o directamente en tienda física. Si ya efectuó el pago, por favor haga caso omiso a este mensaje. ¡Muchas gracias!");
      }
      return sb.toString();
    }

    // =========================================================================
    // 2. CASO MÚLTIPLES CUOTAS VENCIDAS (Resumen desde Perfil de Cliente / Alertas)
    // =========================================================================
    final int count = widget.multipleCuotas?.length ?? 0;
    final sb = StringBuffer();

    if (tType == 'resumen') {
      sb.writeln("Hola $name 👋. Te saludamos de la tienda.");
      sb.writeln("\n⚡ *RESUMEN DE CUOTAS PENDIENTES*");
      sb.writeln("Le recordamos que mantiene *$count cuota(s) pendiente(s)* por un saldo total exigible de *${AppCurrency.format(totalExigible)}*.");
      if (sDesglose && count > 0) {
        sb.writeln("\n*Cuotas:*");
        _appendCuotasList(sb, sMora);
      }
      if (sCuentas) {
        sb.write(cuentasBlock);
      } else {
        sb.writeln("\nAgradeceremos su regularización vía Yape, Plin o en tienda física. ¡Muchas gracias!");
      }
      return sb.toString().trim();
    }

    if (tType == 'cordial') {
      sb.writeln("Hola $name 👋. Esperamos que se encuentre muy bien. Le saludamos cordialmente de la tienda.");
      sb.writeln("\n🤝 *RECORDATORIO AMABLE DE PAGO*");
      sb.writeln("Le escribimos para recordarle que mantiene un saldo pendiente de *${AppCurrency.format(totalExigible)}* correspondiente a *$count cuota(s)*.");
      if (sDesglose && count > 0) {
        sb.writeln("\n*Detalle de cuotas:*");
        _appendCuotasList(sb, sMora);
      }
      if (sCuentas) {
        sb.write(cuentasBlock);
      } else {
        sb.writeln("\nAgradecemos de antemano su amable atención y puntualidad. ¡Que tenga un excelente día!");
      }
      return sb.toString().trim();
    }

    if (tType == 'mora') {
      sb.writeln("Hola $name 👋. Te saludamos de la tienda.");
      sb.writeln("\n🚨 *AVISO URGENTE: CUOTAS EN MOROSIDAD*");
      sb.writeln("Le informamos que registra *$count cuota(s) vencida(s)* con recargos acumulados, alcanzando un saldo exigible de *${AppCurrency.format(totalExigible)}*.");
      if (sDesglose && count > 0) {
        sb.writeln("\n*Desglose con mora acumulada:*");
        _appendCuotasList(sb, sMora);
      }
      sb.writeln("\nLe invitamos a regularizar su cuenta hoy mismo para evitar la acumulación de mayores recargos diarios.");
      if (sCuentas) {
        sb.write(cuentasBlock);
      } else {
        sb.writeln("Puede abonar mediante Yape, Plin o directamente en tienda física. ¡Muchas gracias!");
      }
      return sb.toString().trim();
    }

    // Template Formal / Cobranza detallada (default)
    sb.writeln("Hola $name 👋. Te saludamos de la tienda.");
    if (count > 0) {
      sb.writeln("\n⚠️ *ESTADO DE CUENTA: CUOTAS EN OBSERVACIÓN*");
      sb.writeln("Le escribimos para recordarle que mantiene *$count cuota(s) pendiente(s)* por un saldo total exigible de *${AppCurrency.format(totalExigible)}*:\n");
      if (sDesglose) {
        _appendCuotasList(sb, sMora);
      }
    } else {
      sb.writeln("\nLe escribimos para recordarle que cuenta con un saldo pendiente de *${AppCurrency.format(totalExigible)}*.");
    }

    if (sCuentas) {
      sb.write(cuentasBlock);
    } else {
      sb.writeln("\nAgradeceremos su pronta regularización vía Yape, Plin o en tienda física. ¡Muchas gracias por su atención!");
    }
    return sb.toString().trim();
  }

  void _appendCuotasList(StringBuffer sb, bool sMora) {
    if (widget.multipleCuotas == null) return;
    for (var raw in widget.multipleCuotas!) {
      final c = raw is Map ? raw : (raw as dynamic);
      final numCuota = c['numero_cuota'] ?? c['installmentNumber'] ?? '';
      final monto = (num.tryParse((c['monto'] ?? c['amount'] ?? 0.0).toString()) ?? 0.0).toDouble();
      final montoOriginal = (num.tryParse((c['monto_original'] ?? c['montoOriginal'] ?? monto).toString()) ?? monto).toDouble();
      final mora = (num.tryParse((c['mora_monto'] ?? c['moraMonto'] ?? 0.0).toString()) ?? 0.0).toDouble();
      final pagado = (num.tryParse((c['monto_pagado'] ?? c['montoPagado'] ?? 0.0).toString()) ?? 0.0).toDouble();
      final due = c['fecha_vencimiento'] ?? c['dueDate'] ?? '';
      final falta = (monto - pagado) > 0 ? (monto - pagado) : 0.0;
      final String moraDetail = (sMora && mora > 0.01)
          ? " (Base: ${AppCurrency.format(montoOriginal)} + Mora: ${AppCurrency.format(mora)})"
          : "";

      final dateInfo = CuotaDateHelper.evaluate(due);
      final int daysOver = dateInfo.daysOverdue;
      final bool isVencida = dateInfo.isPast && falta > 0.01;
      final String vencidaStatus = isVencida ? "- *Vencida (hace $daysOver ${daysOver == 1 ? 'día' : 'días'})*" : "";

      if (pagado > 0.01) {
        if (falta <= 0.01) {
          sb.writeln("✅ Cuota #$numCuota: *${AppCurrency.format(monto)}*$moraDetail (${dateInfo.fullLabel}) - *Pagada*");
        } else if (isVencida) {
          sb.writeln("🔴 Cuota #$numCuota: *${AppCurrency.format(monto)}*$moraDetail (Abonó: ${AppCurrency.format(pagado)} • Falta: ${AppCurrency.format(falta)}) (${dateInfo.fullLabel}) $vencidaStatus");
        } else {
          sb.writeln("🟠 Cuota #$numCuota: *${AppCurrency.format(monto)}*$moraDetail (Abonó: ${AppCurrency.format(pagado)} • Falta: ${AppCurrency.format(falta)}) (${dateInfo.fullLabel}) - *Pago Parcial*");
        }
      } else {
        if (isVencida) {
          sb.writeln("🔴 Cuota #$numCuota: *${AppCurrency.format(monto)}*$moraDetail (${dateInfo.fullLabel}) $vencidaStatus");
        } else if (dateInfo.isToday) {
          sb.writeln("⏳ Cuota #$numCuota: *${AppCurrency.format(monto)}*$moraDetail (${dateInfo.fullLabel}) - *Vence Hoy*");
        } else {
          sb.writeln("⏳ Cuota #$numCuota: *${AppCurrency.format(monto)}*$moraDetail (${dateInfo.fullLabel}) - *Pendiente*");
        }
      }
    }
  }

  void _applyTemplate(String type) {
    setState(() {
      _activeTemplate = type;
      _messageCtrl.text = _generateMessage();
    });
  }

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
            Text(
              "Editar Contacto",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? Colors.white : Colors.black87,
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
              setState(() {
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
                ? const Color(0xFF25D366).withValues(alpha: isDark ? 0.25 : 0.15)
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

  Widget _buildModuleChip(String label, bool isChecked, ValueChanged<bool> onToggle, bool isDark) {
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
        backgroundColor: isDark ? const Color(0xFF1A1A22) : Colors.grey.shade100,
        selectedColor: const Color(0xFF25D366).withValues(alpha: isDark ? 0.25 : 0.15),
        side: BorderSide(
          color: isChecked
              ? const Color(0xFF25D366)
              : (isDark ? Colors.white12 : Colors.grey.shade300),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E1E28) : Colors.grey[100]!;
    final textColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: InteractiveSheetWrapper(
        title: "Estudio de WhatsApp",
        icon: Icons.chat_rounded,
        iconColor: const Color(0xFF25D366),
        backgroundColor: surfaceColor,
        applyEffectiveBottomPadding: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
                "Revisa o edita libremente el mensaje antes de enviarlo por WhatsApp.",
                style: TextStyle(fontSize: 12.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(height: 10),

              // ===============================================================
              // 1. BARRA SUPERIOR COMPACTA DE 1 SOLA LÍNEA (40dp)
              // ===============================================================
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_rounded, size: 18, color: Color(0xFF25D366)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : "Cliente",
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
                    InkWell(
                      onTap: () => _showEditContactModal(context, isDark),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.phone_android, size: 13, color: Color(0xFF25D366)),
                            const SizedBox(width: 4),
                            Text(
                              _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : "Sin celular",
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.edit, size: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // ===============================================================
              // 2. CARRUSEL HORIZONTAL DE PLANTILLAS DE TONO (1 Sola Línea)
              // ===============================================================
              SizedBox(
                height: 34,
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
              ),
              const SizedBox(height: 8),

              // ===============================================================
              // 3. CHIPS MODULARES DE CONTENIDO RÁPIDO (Activar / Desactivar)
              // ===============================================================
              SizedBox(
                height: 30,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildModuleChip(
                        "Desglose Cuotas",
                        _showDesglose,
                        (val) {
                          setState(() {
                            _showDesglose = val;
                            _messageCtrl.text = _generateMessage();
                          });
                        },
                        isDark,
                      ),
                      _buildModuleChip(
                        "Detalle Mora",
                        _showMora,
                        (val) {
                          setState(() {
                            _showMora = val;
                            _messageCtrl.text = _generateMessage();
                          });
                        },
                        isDark,
                      ),
                      _buildModuleChip(
                        "Cuentas Abono",
                        _showCuentas,
                        (val) {
                          setState(() {
                            _showCuentas = val;
                            _messageCtrl.text = _generateMessage();
                          });
                        },
                        isDark,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ===============================================================
              // 4. CABECERA DEL MENSAJE EDITABLE CON UTILIDADES
              // ===============================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _messageCtrl.text = _generateMessage();
                          });
                          CustomSnackBar.show(context, message: "Mensaje restaurado");
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 14),
                        label: const Text("Restaurar", style: TextStyle(fontSize: 11.5)),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          foregroundColor: isDark ? Colors.blue[300] : Colors.blue[800],
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _messageCtrl.text));
                          CustomSnackBar.show(context, message: "Texto copiado al portapapeles");
                        },
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text("Copiar", style: TextStyle(fontSize: 11.5)),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          foregroundColor: isDark ? Colors.tealAccent : Colors.teal.shade800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // ===============================================================
              // 5. EDITOR EXPANDIDO (8 A 12 LÍNEAS VISIBLES)
              // ===============================================================
              TextField(
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
              const SizedBox(height: 14),

              // ===============================================================
              // 6. BOTONES DE ACCIÓN
              // ===============================================================
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
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
                        padding: const EdgeInsets.symmetric(vertical: 13),
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
      ),
    ),
  );
  }
}
