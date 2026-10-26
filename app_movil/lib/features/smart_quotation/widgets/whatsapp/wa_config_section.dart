import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/smart_quotation/models/whatsapp_config_model.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/services/whatsapp_preferences_service.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_custom_texts_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_dynamic_popover.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

class WaConfigSection extends StatelessWidget {
  final WhatsAppConfig config;
  final bool isSale;
  final String contextKey;
  final VoidCallback onChanged;
  final SmartQuotationModel? quotation;
  final Map<String, dynamic>? saleData;
  final String? businessName;
  final String? businessPhone;
  final String? paymentAccountsText;

  const WaConfigSection({
    super.key,
    required this.config,
    required this.isSale,
    this.contextKey = 'quote',
    required this.onChanged,
    this.quotation,
    this.saleData,
    this.businessName,
    this.businessPhone,
    this.paymentAccountsText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    final bool isLoan = contextKey == 'loan' || (isSale && saleData?['origen_venta'] == 'prestamo_personal');
    final double totalAmount = isSale
        ? (saleData?['monto_total'] != null ? (saleData!['monto_total'] as num).toDouble() : (quotation?.totalAmount ?? 0.0))
        : (quotation?.totalAmount ?? 0.0);

    // 1. Snippet real para Precios y Subtotales
    String realSubtotalsSnippet;
    if (isLoan) {
      final double interesRate = (saleData?['porcentaje_interes'] != null ? (saleData!['porcentaje_interes'] as num).toDouble() : 0.0);
      final double abonoInicial = (saleData?['abono_inicial'] != null ? (saleData!['abono_inicial'] as num).toDouble() : 0.0);
      final double debtWithInterest = totalAmount - abonoInicial;
      final double debtBase = (interesRate > 0 && debtWithInterest > 0)
          ? debtWithInterest / (1 + (interesRate / 100))
          : debtWithInterest;
      final double interestAmount = debtWithInterest - debtBase;
      final double capitalNeto = abonoInicial + debtBase;
      realSubtotalsSnippet = "• Capital: ${AppCurrency.format(capitalNeto)}\n• Interés: + ${AppCurrency.format(interestAmount)}";
    } else if (quotation != null && quotation!.items.isNotEmpty) {
      final sampleItems = quotation!.items.take(2).map((it) {
        final double itemSub = it.unitPriceApplied * it.quantity;
        return "• ${it.quantity}x ${it.displayName}: ${AppCurrency.format(itemSub)}";
      }).join("\n");
      realSubtotalsSnippet = sampleItems;
    } else {
      realSubtotalsSnippet = "• 2x Cuaderno A4: S/ 12.00\n• 1x Caja Colores: S/ 18.50";
    }

    // 2. Snippet real para Sección de Ahorro y Detalle Descuento
    double totalSavings = 0.0;
    String? realDiscountDetailSnippet;
    if (quotation != null) {
      for (final it in quotation!.items) {
        if (it.originalUnitPrice > it.unitPriceApplied) {
          totalSavings += (it.originalUnitPrice - it.unitPriceApplied) * it.quantity;
          realDiscountDetailSnippet ??= "${it.displayName}: ~${AppCurrency.format(it.originalUnitPrice)}~ *${AppCurrency.format(it.unitPriceApplied)}*";
        }
      }
    }
    final String realSavingsSnippet = totalSavings > 0
        ? "🎉 *¡Ahorro Total: ${AppCurrency.format(totalSavings)}!*"
        : "🎉 *¡Ahorro Total: S/ 18.00!* (Promoción activa)";
    realDiscountDetailSnippet ??= "Mochila Escolar: ~S/ 65.00~ *S/ 48.00*";

    // 3. Snippet real para Monto Total
    final String realTotalSnippet = isLoan
        ? "🏦 *TOTAL A DEVOLVER: ${AppCurrency.format(totalAmount)}*"
        : "💰 *TOTAL A PAGAR: ${AppCurrency.format(totalAmount)}*";

    // 4. Snippet real para Info Negocio
    final String bName = (businessName != null && businessName!.trim().isNotEmpty) ? businessName!.trim() : "Librería y Papelería";
    final String bPhone = (businessPhone != null && businessPhone!.trim().isNotEmpty) ? businessPhone!.trim() : "987654321";
    final String realBizSnippet = "🏪 *$bName*\n📞 Contacto: $bPhone";

    // 5. Snippet real para Medios de Pago
    String realPaymentSnippet;
    if (paymentAccountsText != null && paymentAccountsText!.trim().isNotEmpty) {
      final lines = paymentAccountsText!.trim().split('\n').take(2).join('\n');
      realPaymentSnippet = "💳 *MEDIOS DE PAGO*\n$lines";
    } else {
      realPaymentSnippet = "💳 *MEDIOS DE PAGO*\n📱 Yape / Plin: 987654321\n🏦 BCP: 191-2345678-0-12";
    }

    // 6. Snippet real para Saldo Pendiente (Venta o Préstamo)
    String realDebtSnippet = "💵 Abonado: S/ 50.00\n⚠️ *Saldo Pendiente: S/ 30.00*";
    if (isSale && saleData != null) {
      final double paid = (saleData!['monto_pagado'] != null ? (saleData!['monto_pagado'] as num).toDouble() : 0.0);
      final double debt = (totalAmount - paid).clamp(0.0, double.infinity);
      realDebtSnippet = "💵 Abonado: ${AppCurrency.format(paid)}\n⚠️ *Saldo Pendiente: ${AppCurrency.format(debt)}*";
    }

    // 7. Snippet real para Cuotas (Venta o Préstamo)
    String realInstallmentSnippet = "📅 Cuota 1 de 2: S/ 15.00 (Vence: 28/10)";
    if (isSale && saleData != null && saleData!['cuotas'] != null && (saleData!['cuotas'] as List).isNotEmpty) {
      final firstCuota = (saleData!['cuotas'] as List).first;
      final date = DateFormat('dd/MM/yyyy').format(DateTime.parse(firstCuota['fecha_vencimiento']));
      realInstallmentSnippet = "📅 Cuota ${firstCuota['numero_cuota']}: ${AppCurrency.format(firstCuota['monto'])} (Vence: $date)";
    }

    // 8. Snippet real para Estado Entrega (Venta)
    final String deliveryStatus = isSale && saleData != null ? (saleData!['estado_entrega'] ?? 'coordinado') : 'coordinado';
    final String realDeliverySnippet = "📦 *Entrega:* Despacho ${deliveryStatus.toString().toUpperCase()}";

    // 9. Snippet real para Validez Oferta (Cotización)
    final String realValiditySnippet = "⏳ *Validez:* Precios válidos por 7 días calendario.";

    // 10. Snippet real para Datos Entrega (Cotización)
    final String realQuoteDeliverySnippet = "🚚 *Entrega:* Coordinación directa para despacho o recojo en tienda.";

    final List<Widget> optionCards = [
      _buildOptionCard(
        context: context,
        title: "Precios y Subtotales",
        subtitle: "S/. por producto",
        icon: Icons.attach_money,
        isActive: config.showSubtotals,
        isDark: isDark,
        onTap: () {
          config.showSubtotals = !config.showSubtotals;
          onChanged();
        },
        popoverDescription: "Incluye el precio unitario y el subtotal calculado de cada ítem en la lista del mensaje.",
        exampleSnippet: realSubtotalsSnippet,
      ),
      _buildOptionCard(
        context: context,
        title: "Sección de Ahorro",
        subtitle: "Descuento total",
        icon: Icons.savings_outlined,
        isActive: config.showSavingsSection,
        isDark: isDark,
        onTap: () {
          config.showSavingsSection = !config.showSavingsSection;
          onChanged();
        },
        popoverDescription: "Destaca el monto total ahorrado por el cliente gracias a promociones o precios rebajados.",
        exampleSnippet: realSavingsSnippet,
      ),
      if (config.showSavingsSection)
        _buildOptionCard(
          context: context,
          title: "Detalle Descuento",
          subtitle: "Antes y Ahora",
          icon: Icons.local_offer_outlined,
          isActive: config.showDiscountDetail,
          isDark: isDark,
          onTap: () {
            config.showDiscountDetail = !config.showDiscountDetail;
            onChanged();
          },
          popoverDescription: "Imprime el precio original tachado junto al precio actual para evidenciar la rebaja.",
          exampleSnippet: realDiscountDetailSnippet,
        ),
      _buildOptionCard(
        context: context,
        title: "Monto Total S/.",
        subtitle: "Suma final neta",
        icon: Icons.calculate_outlined,
        isActive: config.showTotalGlobal,
        isDark: isDark,
        onTap: () {
          config.showTotalGlobal = !config.showTotalGlobal;
          onChanged();
        },
        popoverDescription: "Muestra la línea principal con el monto total final a pagar en soles.",
        exampleSnippet: realTotalSnippet,
      ),
      _buildOptionCard(
        context: context,
        title: "Info del Negocio",
        subtitle: "Teléfono y RUC",
        icon: Icons.storefront_outlined,
        isActive: config.showBusinessInfo,
        isDark: isDark,
        onTap: () {
          config.showBusinessInfo = !config.showBusinessInfo;
          onChanged();
        },
        popoverDescription: "Agrega en la cabecera o pie los datos formales de tu tienda o empresa.",
        exampleSnippet: realBizSnippet,
      ),
      _buildOptionCard(
        context: context,
        title: "Medios de Pago",
        subtitle: "Yape, Plin y bancos",
        icon: Icons.payment_outlined,
        isActive: config.showPaymentInfo,
        isDark: isDark,
        onTap: () {
          config.showPaymentInfo = !config.showPaymentInfo;
          onChanged();
        },
        popoverDescription: "Inserta tus números de billeteras digitales y cuentas para agilizar la transferencia.",
        exampleSnippet: realPaymentSnippet,
      ),
      if (isSale) ...[
        _buildOptionCard(
          context: context,
          title: "Saldo Pendiente",
          subtitle: "Deuda por cobrar",
          icon: Icons.warning_amber_rounded,
          isActive: config.showDebtInfo,
          isDark: isDark,
          onTap: () {
            config.showDebtInfo = !config.showDebtInfo;
            onChanged();
          },
          popoverDescription: "Indica el monto ya abonado por el cliente y el saldo exacto pendiente de pago.",
          exampleSnippet: realDebtSnippet,
        ),
        _buildOptionCard(
          context: context,
          title: "Detalle Cuotas",
          subtitle: "Plan de pagos",
          icon: Icons.calendar_month_outlined,
          isActive: config.showInstallmentDetails,
          isDark: isDark,
          onTap: () {
            config.showInstallmentDetails = !config.showInstallmentDetails;
            onChanged();
          },
          popoverDescription: "Detalla el cronograma de cuotas pactadas y sus fechas de vencimiento.",
          exampleSnippet: realInstallmentSnippet,
        ),
        _buildOptionCard(
          context: context,
          title: "Estado Entrega",
          subtitle: "Envío / Recojo",
          icon: Icons.local_shipping_outlined,
          isActive: config.showDeliveryInfo,
          isDark: isDark,
          onTap: () {
            config.showDeliveryInfo = !config.showDeliveryInfo;
            onChanged();
          },
          popoverDescription: "Informa al cliente sobre la modalidad de entrega acordada para su pedido.",
          exampleSnippet: realDeliverySnippet,
        ),
      ] else ...[
        _buildOptionCard(
          context: context,
          title: "Validez Oferta",
          subtitle: "Días de vigencia",
          icon: Icons.timer_outlined,
          isActive: config.includeValidity,
          isDark: isDark,
          onTap: () {
            config.includeValidity = !config.includeValidity;
            onChanged();
          },
          popoverDescription: "Establece el tiempo límite de vigencia de los precios cotizados.",
          exampleSnippet: realValiditySnippet,
        ),
        _buildOptionCard(
          context: context,
          title: "Datos Entrega",
          subtitle: "Método de envío",
          icon: Icons.moped_outlined,
          isActive: config.includeDelivery,
          isDark: isDark,
          onTap: () {
            config.includeDelivery = !config.includeDelivery;
            onChanged();
          },
          popoverDescription: "Aclara si el flete está incluido o si el retiro es en tienda física.",
          exampleSnippet: realQuoteDeliverySnippet,
        ),
      ],
    ];

    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: isDark ? const Color(0xFF00C49F) : const Color(0xFF00A884), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Personalizar Mensaje",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: textColor,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    WaCustomTextsModal.show(
                      context,
                      config: config,
                      contextKey: contextKey,
                      isDark: isDark,
                      onSaved: (intro, closing) {
                        onChanged();
                      },
                    );
                  },
                  icon: const Icon(Icons.edit_note, size: 18, color: Color(0xFF00A884)),
                  label: const Text(
                    "Intro/Firma",
                    style: TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 🧱 Grilla de 2 Columnas Balanceada (50% / 50%) con Cero Truncamiento
            Column(
              children: [
                for (int i = 0; i < optionCards.length; i += 2) ...[
                  if (i > 0) const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: optionCards[i]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: (i + 1 < optionCards.length)
                            ? optionCards[i + 1]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 12),
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    config.customIntro != null || config.customClosing != null
                        ? "✨ Frase personalizada activa"
                        : "Plantilla original activa",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: config.customIntro != null || config.customClosing != null
                          ? Colors.orange
                          : (isDark ? Colors.grey[500] : Colors.grey[600]),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    await WhatsAppPreferencesService.saveDefaultConfig(config, contextKey: contextKey);
                    if (context.mounted) {
                      CustomSnackBar.show(
                        context,
                        message: "Configuración guardada por defecto",
                        isError: false,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.save_outlined, size: 16, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                        const SizedBox(width: 4),
                        Text(
                          "Guardar por defecto",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.blue[300] : Colors.blue[700],
                          ),
                        ),
                      ],
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

  Widget _buildOptionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
    required String popoverDescription,
    String? exampleSnippet,
  }) {
    final Color activeColor = const Color(0xFF00A884);
    final Color activeBg = isDark
        ? activeColor.withValues(alpha: 0.22)
        : activeColor.withValues(alpha: 0.12);
    final Color inactiveBg = isDark
        ? const Color(0xFF14141C)
        : Colors.grey.shade100;
    final Color activeBorder = activeColor;
    final Color inactiveBorder = isDark ? Colors.white10 : Colors.grey.shade300;

    void openPopover() {
      WaDynamicPopover.show(
        context,
        title: title,
        description: popoverDescription,
        exampleSnippet: exampleSnippet,
        icon: icon,
      );
    }

    return Material(
      color: isActive ? activeBg : inactiveBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        onLongPress: openPopover,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? activeBorder : inactiveBorder,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fila superior: Icono + Spacer + Botón ⓘ + Check ✓/+
              Row(
                children: [
                  Icon(
                    icon,
                    size: 19,
                    color: isActive ? activeColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: openPopover,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.info_outline,
                        size: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: isActive
                        ? Icon(Icons.check_circle_rounded, key: const ValueKey('checked'), size: 15, color: activeColor)
                        : Icon(Icons.add_circle_outline_rounded, key: const ValueKey('unchecked'), size: 15, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Fila inferior: Título y Subtítulo al 100% del ancho de la tarjeta
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  color: isActive
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.grey[300] : Colors.grey[800]),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}