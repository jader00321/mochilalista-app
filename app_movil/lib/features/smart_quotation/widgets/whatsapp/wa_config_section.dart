import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/smart_quotation/models/whatsapp_config_model.dart';
import 'package:app_movil/features/smart_quotation/services/whatsapp_preferences_service.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_custom_texts_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_dynamic_popover.dart';

class WaConfigSection extends StatelessWidget {
  final WhatsAppConfig config;
  final bool isSale;
  final String contextKey;
  final VoidCallback onChanged;

  const WaConfigSection({
    super.key,
    required this.config,
    required this.isSale,
    this.contextKey = 'quote',
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

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
        exampleSnippet: "• 2x Cuaderno A4: S/ 12.00",
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
        exampleSnippet: "🎉 *¡Ahorro Total: S/ 18.00!*",
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
          exampleSnippet: "Mochila: ~S/ 65.00~ *S/ 48.00*",
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
        exampleSnippet: "💰 *TOTAL A PAGAR: S/ 120.00*",
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
        exampleSnippet: "🏪 *Librería San José*\n📞 Tel: 987654321",
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
        exampleSnippet: "📱 Yape / Plin: 987654321\n🏦 BCP: 191-2345678-0-12",
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
          exampleSnippet: "💵 Abonado: S/ 50.00\n⚠️ *Saldo Pendiente: S/ 30.00*",
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
          exampleSnippet: "📅 Cuota 1 de 2: S/ 15.00 (Vence: 28/10)",
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
          exampleSnippet: "📦 Entrega: Despacho a domicilio coordinado",
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
          exampleSnippet: "⏳ *Cotización válida por 7 días hábiles.*",
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
          exampleSnippet: "🚚 Envíos a todo el país previa coordinación.",
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
                Text(
                  config.customIntro != null || config.customClosing != null
                      ? "✨ Frase personalizada activa"
                      : "Plantilla original activa",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: config.customIntro != null || config.customClosing != null
                        ? Colors.orange
                        : (isDark ? Colors.grey[500] : Colors.grey[600]),
                  ),
                ),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? activeColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      softWrap: true,
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
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Botón discreto de ayuda ⓘ
              GestureDetector(
                onTap: openPopover,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.info_outline,
                    size: 14,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                ),
              ),
              const SizedBox(width: 2),
              if (isActive)
                Icon(Icons.check, size: 14, color: activeColor)
              else
                Icon(Icons.add, size: 14, color: isDark ? Colors.grey[600] : Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}