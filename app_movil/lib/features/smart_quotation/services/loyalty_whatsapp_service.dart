import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/loyalty_toast_feedback.dart';

class LoyaltyWhatsAppService {
  LoyaltyWhatsAppService._();

  static String _cleanPhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 9 && !clean.startsWith('51')) {
      return '51$clean';
    }
    return clean;
  }

  static Future<bool> launchWhatsApp(
    BuildContext context,
    String phone,
    String message,
  ) async {
    final clean = _cleanPhone(phone);
    if (clean.isEmpty || clean == '000000000') {
      if (context.mounted) {
        LoyaltyToastFeedback.showWarning(
          context,
          'El cliente no tiene un teléfono válido registrado',
        );
      }
      return false;
    }

    final url = Uri.parse(
      'https://wa.me/$clean?text=${Uri.encodeComponent(message)}',
    );
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      } else {
        if (context.mounted) {
          LoyaltyToastFeedback.showWarning(
            context,
            'No se pudo abrir WhatsApp en este dispositivo',
          );
        }
        return false;
      }
    } catch (_) {
      if (context.mounted) {
        LoyaltyToastFeedback.showWarning(
          context,
          'Error al intentar abrir WhatsApp',
        );
      }
      return false;
    }
  }

  /// 🎁 Plantilla 1: Premio Desbloqueado y Confirmado por el Comerciante
  static Future<bool> sendRewardNotification({
    required BuildContext context,
    required String phone,
    required String clientName,
    required String businessName,
    required ClientRewardModel reward,
    required int puntosSaldo,
    required String nivelReputacion,
  }) async {
    final tier = ReputationTier.fromKey(nivelReputacion);
    final String benefitText = reward.formattedBenefit;

    final msg =
        '''
🎉 *¡Felicidades, $clientName!* 🎉

En *$businessName* valoramos mucho tu fidelidad y constancia.

Por tus compras y pagos puntuales, acabas de desbloquear un beneficio exclusivo:
🎁 *Premio:* $benefitText
🏆 *Nivel de Fidelidad:* ${tier.displayName}
⭐ *Saldo de Puntos Disponible:* $puntosSaldo pts

Ven a la tienda o escríbenos para canjear tu premio en tu próxima compra. ¡Muchas gracias por tu preferencia! ✨
'''
            .trim();

    return await launchWhatsApp(context, phone, msg);
  }

  /// 🎯 Plantilla 2: "Casi en la Meta" (Impulso Comercial de Compra 80%-95%)
  static Future<bool> sendAlmostAtGoalNotification({
    required BuildContext context,
    required String phone,
    required String clientName,
    required String businessName,
    required RewardGoalModel goal,
    required int puntosFaltantes,
    required int puntosActuales,
  }) async {
    final msg =
        '''
¡Hola, $clientName! 👋

Te saludamos desde *$businessName* para contarte que estás muy cerca de tu próximo premio:

🎯 *Meta:* ${goal.nombre}
🎁 *Beneficio al llegar:* ${goal.formattedBenefit}
📊 *Progreso:* $puntosActuales de ${goal.puntosRequeridos} pts
⚡ *¡Solo te faltan $puntosFaltantes puntos!*

Realiza tu compra o cancela tu cuota a tiempo esta semana y desbloquearás este beneficio de inmediato. ¡Te esperamos! 📦✨
'''
            .trim();

    return await launchWhatsApp(context, phone, msg);
  }

  /// 🌟 Plantilla 3: Felicitación por Subida de Rango / Racha Impecable
  static Future<bool> sendTierCelebrationNotification({
    required BuildContext context,
    required String phone,
    required String clientName,
    required String businessName,
    required ReputationTier tier,
    required int streak,
    required int score,
  }) async {
    String rachaText = streak > 0
        ? '\n🔥 *Racha de Pagos Puntuales:* $streak cuotas a tiempo consecutivas'
        : '';
    final msg =
        '''
🌟 *¡Excelente noticia, $clientName!* 🌟

Queremos felicitarte de parte de *$businessName*. Gracias a tu excelente comportamiento comercial y puntualidad, tu cuenta ha alcanzado:

🏆 *Rango Comercial:* ${tier.displayName}
📈 *Score de Reputación:* $score / 1000 pts$rachaText

Tu categoría te otorga atención preferencial y beneficios especiales en todos tus pedidos. ¡Gracias por ser un cliente ejemplar! 🤝✨
'''
            .trim();

    return await launchWhatsApp(context, phone, msg);
  }

  /// 🎁 Plantilla 5: Situación del Cliente y Premios Disponibles para Reclamar
  static String buildAvailableRewardsMessage({
    required String clientName,
    required String businessName,
    required int puntosSaldo,
    required String nivelReputacion,
    required List<RewardGoalModel> claimableGoals,
    RewardGoalModel? upcomingGoal,
    int missingPoints = 0,
  }) {
    final tier = ReputationTier.fromKey(nivelReputacion);
    final buffer = StringBuffer();
    buffer.writeln('🎉 *¡Hola, $clientName!* 🎉');
    buffer.writeln('Te saludamos con mucho aprecio desde *$businessName*.\n');
    buffer.writeln(
      'Queremos felicitarte por tu excelente récord con nosotros:',
    );
    buffer.writeln('⭐ *Saldo de Puntos Acumulados:* $puntosSaldo pts');
    buffer.writeln('🏆 *Categoría de Cliente:* ${tier.displayName}\n');

    if (claimableGoals.isNotEmpty) {
      buffer.writeln('🎁 *PREMIOS QUE YA PUEDES RECLAMAR HOY:*');
      for (var g in claimableGoals) {
        buffer.writeln(
          '• *${g.nombre}* ➡️ ${g.formattedBenefit} (Usa ${g.puntosRequeridos} pts)',
        );
      }
      buffer.writeln();
    }

    if (upcomingGoal != null && missingPoints > 0) {
      buffer.writeln('📈 *¿PREFIERES SEGUIR AHORRANDO PUNTOS?*');
      buffer.writeln(
        'Tu saldo se mantiene libre. Si decides acumular para una meta mayor:',
      );
      buffer.writeln(
        '🎯 Próximo objetivo: *${upcomingGoal.nombre}* (${upcomingGoal.formattedBenefit})',
      );
      buffer.writeln(
        '⚡ *¡Solo te faltan $missingPoints pts para desbloquearlo!*\n',
      );
    }

    buffer.writeln(
      'Ven a la tienda o escríbenos para reclamar tu premio elegido o seguir ahorrando tus puntos. ¡Muchas gracias por tu preferencia! ✨',
    );
    return buffer.toString().trim();
  }

  /// Formatea el nombre del negocio en mayúsculas limpias para presentaciones formales
  static String formatBusinessName(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return "NUESTRA TIENDA";
    return clean.toUpperCase();
  }

  /// 📜 Plantilla 6: Cartilla / Guía Oficial de Cómo Ganar Puntos y Premios
  static String buildLoyaltyGuideAndCatalogMessage({
    required String businessName,
    required LoyaltyRulesModel rules,
    required List<RewardGoalModel> activeGoals,
    String? clientName,
    int? puntosActuales,
    bool includeRules = true,
    bool includeCatalog = true,
    bool includeStoreInfo = true,
    String? businessAddress,
    String? businessPhone,
  }) {
    final buffer = StringBuffer();
    final cleanBiz = formatBusinessName(businessName);

    buffer.writeln('📜 *GUÍA OFICIAL DE PUNTOS Y PREMIOS • $cleanBiz* 🎁\n');

    if (clientName != null && clientName.trim().isNotEmpty) {
      buffer.writeln(
        'Estimado(a) *${clientName.trim()}*, te compartimos cómo funciona nuestro programa de lealtad para premiar tu preferencia:\n',
      );
    } else {
      buffer.writeln(
        'Te compartimos cómo funciona nuestro programa de lealtad para premiar tu preferencia:\n',
      );
    }

    if (includeRules) {
      buffer.writeln('💡 *¿CÓMO GANAR PUNTOS EN NUESTRA TIENDA?*');

      if (rules.puntosPorCompraActivo) {
        final baseStr = rules.montoBaseCompra == 1.0
            ? 'S/ 1.00'
            : AppCurrency.format(rules.montoBaseCompra);
        final minStr = rules.compraMinimaParaPuntos > 0
            ? ' (en compras desde ${AppCurrency.format(rules.compraMinimaParaPuntos)})'
            : '';
        buffer.writeln(
          '✅ *Compras al Contado:* Ganas *+${rules.puntosPorUnidadMoneda} pto* por cada $baseStr de compra$minStr.',
        );
      }

      if (rules.bonoCotizacionActivo && rules.puntosBonoCotizacion > 0) {
        buffer.writeln(
          '✅ *Cotizaciones Concretadas:* *+${rules.puntosBonoCotizacion} pts extra* al confirmar tu cotización en venta.',
        );
      }

      if (rules.puntosAbonoInicialActivo) {
        buffer.writeln(
          '✅ *Compras al Crédito:* Ganas puntos proporcionales a tu abono inicial al momento de llevar mercadería.',
        );
      }

      if (rules.bonoPagoPuntualActivo && rules.puntosPagoPuntual > 0) {
        buffer.writeln(
          '✅ *Pagos Puntuales:* *+${rules.puntosPagoPuntual} pts* cada vez que cancelas tu cuota en o antes de su vencimiento.',
        );
      }

      if (rules.bonoRachaActivo && rules.puntosBonoRacha > 0) {
        buffer.writeln(
          '🔥 *Racha Impecable:* *+${rules.puntosBonoRacha} pts extra* cada ${rules.cadaCuantasCuotasRacha} pagos puntuales consecutivos.',
        );
      }

      if (rules.bonoLiquidacionSinMoraActivo &&
          rules.puntosLiquidacionSinMora > 0) {
        buffer.writeln(
          '🏆 *Compromiso Total:* *+${rules.puntosLiquidacionSinMora} pts* al liquidar tu crédito o préstamo sin retrasos.',
        );
      }

      buffer.writeln();
    }

    if (includeCatalog && activeGoals.isNotEmpty) {
      buffer.writeln('🎁 *CATÁLOGO DE PREMIOS Y DESCUENTOS:*');
      for (var g in activeGoals) {
        String benefitLabel;
        if (g.tipoBeneficio == 'DESCUENTO_MONTO') {
          benefitLabel = "Descuento de ${AppCurrency.format(g.valorBeneficio)}";
        } else if (g.tipoBeneficio == 'DESCUENTO_PORCENTAJE') {
          benefitLabel = "${g.valorBeneficio.toInt()}% de Descuento";
        } else if (g.tipoBeneficio == 'PRODUCTO_REGALO') {
          benefitLabel = g.valorBeneficio > 0
              ? "Producto de Regalo - ${AppCurrency.format(g.valorBeneficio)}"
              : "Producto de Regalo";
        } else {
          benefitLabel = g.valorBeneficio > 0
              ? "Línea de Crédito hasta ${AppCurrency.format(g.valorBeneficio)}"
              : "Línea de Crédito Preferencial";
        }

        // Supresión de redundancias en paréntesis (ej. no duplicar 10% de Ahorro Especial (10% de Descuento))
        final String lowerName = g.nombre.toLowerCase();
        final bool isRedundant = (g.tipoBeneficio == 'DESCUENTO_PORCENTAJE' && lowerName.contains('${g.valorBeneficio.toInt()}%')) ||
            (g.tipoBeneficio == 'DESCUENTO_MONTO' && lowerName.contains(AppCurrency.format(g.valorBeneficio).toLowerCase())) ||
            lowerName.contains(benefitLabel.toLowerCase());

        if (isRedundant) {
          if (g.descripcion != null && g.descripcion!.isNotEmpty && !lowerName.contains(g.descripcion!.toLowerCase())) {
            buffer.writeln('• *${g.puntosRequeridos} pts:* ${g.nombre} (${g.descripcion!})');
          } else {
            buffer.writeln('• *${g.puntosRequeridos} pts:* ${g.nombre}');
          }
        } else {
          buffer.writeln('• *${g.puntosRequeridos} pts:* ${g.nombre} ($benefitLabel)');
        }
      }
      buffer.writeln();
    }

    if (puntosActuales != null) {
      buffer.writeln('⭐ *Tu saldo disponible hoy:* *$puntosActuales pts*\n');
    }

    if (includeStoreInfo) {
      buffer.writeln(
        '¡Tus puntos se acumulan libremente y tú eliges cuándo reclamar! Visítanos y sigue sumando. Estamos para servirte. ✨',
      );
      if (businessAddress != null && businessAddress.trim().isNotEmpty) {
        buffer.writeln('📍 *Dirección:* ${businessAddress.trim()}');
      }
      if (businessPhone != null && businessPhone.trim().isNotEmpty) {
        buffer.writeln('📞 *Contacto:* ${businessPhone.trim()}');
      }
    }

    return buffer.toString().trim();
  }

  /// ⚡ Plantilla Rápida Resumida (Lectura rápida en WhatsApp)
  static String buildSummaryGuideMessage({
    required String businessName,
    required LoyaltyRulesModel rules,
    required List<RewardGoalModel> activeGoals,
    String? clientName,
    int? puntosActuales,
  }) {
    final buffer = StringBuffer();
    final cleanBiz = formatBusinessName(businessName);

    buffer.writeln('⚡ *PROGRAMA DE PUNTOS • $cleanBiz* 🎁\n');
    if (clientName != null && clientName.trim().isNotEmpty) {
      buffer.writeln('¡Hola, *${clientName.trim()}*! Te resumimos cómo ganar premios:');
    } else {
      buffer.writeln('¡Gana premios por tus compras y pagos puntuales!');
    }

    buffer.writeln('⭐ *Compras al Contado:* +${rules.puntosPorUnidadMoneda} pto por cada S/ ${rules.montoBaseCompra.toStringAsFixed(2)}.');
    if (rules.bonoPagoPuntualActivo) {
      buffer.writeln('⭐ *Pagos Puntuales:* +${rules.puntosPagoPuntual} pts por cancelar tu cuota a tiempo.');
    }
    if (activeGoals.isNotEmpty) {
      final firstGoal = activeGoals.first;
      buffer.writeln('🎁 *Primer Premio:* ${firstGoal.nombre} a los ${firstGoal.puntosRequeridos} pts.');
    }
    if (puntosActuales != null) {
      buffer.writeln('📊 *Tu saldo actual:* *$puntosActuales pts*');
    }
    buffer.writeln('\n¡Visítanos para seguir sumando y canjear tus premios! ✨');
    return buffer.toString().trim();
  }

  /// 🔥 Plantilla Promocional de Invitación
  static String buildPromoInviteMessage({
    required String businessName,
    required List<RewardGoalModel> activeGoals,
    String? clientName,
    int? puntosActuales,
  }) {
    final buffer = StringBuffer();
    final cleanBiz = formatBusinessName(businessName);

    buffer.writeln('🔥 *¡DESCUBRE TUS BENEFICIOS EN $cleanBiz!* 🎁\n');
    if (clientName != null && clientName.trim().isNotEmpty) {
      buffer.writeln('¡Hola, *${clientName.trim()}*! Queremos consentirte por ser nuestro cliente preferencial.');
    } else {
      buffer.writeln('Queremos consentirte por ser nuestro cliente preferencial.');
    }
    if (puntosActuales != null) {
      buffer.writeln('⭐ Ya cuentas con *$puntosActuales pts* acumulados en tu cuenta.');
    }
    if (activeGoals.isNotEmpty) {
      buffer.writeln('\n🏆 *Premios que puedes llevarte:*');
      for (var g in activeGoals.take(3)) {
        buffer.writeln('• ${g.nombre} (Con ${g.puntosRequeridos} pts)');
      }
    }
    buffer.writeln('\n¡Haz tu pedido hoy y sigue acumulando beneficios exclusivos! 📦✨');
    return buffer.toString().trim();
  }

  /// 📱 Modal de Vista Previa Editable con Selector de Compartir Nativo y Barra de Personalización
  static Future<void> showEditableWhatsAppPreviewModal({
    required BuildContext context,
    required String title,
    required String phone,
    required String initialMessage,
    LoyaltyRulesModel? rules,
    List<RewardGoalModel>? activeGoals,
    String? businessName,
    String? clientName,
    int? puntosActuales,
    List<ClientModel>? availableClients,
    String? businessAddress,
    String? businessPhone,
    VoidCallback? onSent,
  }) async {
    final msgCtrl = TextEditingController(text: initialMessage);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF282838) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(
      context,
      minPadding: InteractiveSheetWrapper.kMinDefensiveBottomClearance,
    );

    // Estado local de personalización
    String currentFormat = 'COMPLETO'; // 'COMPLETO', 'RESUMEN', 'PROMO'
    bool secRules = true;
    bool secCatalog = true;
    bool secStore = true;
    ClientModel? selectedClient;
    String currentPhone = phone;
    String? currentClientName = clientName;
    int? currentPuntos = puntosActuales;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          void updateMessageText([String? newFormat]) {
            if (newFormat != null) currentFormat = newFormat;
            if (rules != null && activeGoals != null && businessName != null) {
              if (currentFormat == 'COMPLETO') {
                msgCtrl.text = buildLoyaltyGuideAndCatalogMessage(
                  businessName: businessName,
                  rules: rules,
                  activeGoals: activeGoals,
                  clientName: currentClientName,
                  puntosActuales: currentPuntos,
                  includeRules: secRules,
                  includeCatalog: secCatalog,
                  includeStoreInfo: secStore,
                  businessAddress: businessAddress,
                  businessPhone: businessPhone,
                );
              } else if (currentFormat == 'RESUMEN') {
                msgCtrl.text = buildSummaryGuideMessage(
                  businessName: businessName,
                  rules: rules,
                  activeGoals: activeGoals,
                  clientName: currentClientName,
                  puntosActuales: currentPuntos,
                );
              } else if (currentFormat == 'PROMO') {
                msgCtrl.text = buildPromoInviteMessage(
                  businessName: businessName,
                  activeGoals: activeGoals,
                  clientName: currentClientName,
                  puntosActuales: currentPuntos,
                );
              }
            }
          }

          final bool hasActivePhone = currentPhone.trim().isNotEmpty && currentPhone.trim() != '000000000';

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(ctx).unfocus(),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.90,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                top: false,
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, 14, 18, effectiveBottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Asa superior
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white24
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Encabezado
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366).withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chat_bubble_rounded,
                              color: Color(0xFF25D366),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  hasActivePhone
                                      ? "Destino WhatsApp: $currentPhone"
                                      : "Compartir cartilla con clientes",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Selector rápido opcional de Cliente (cuando se abre sin cliente fijo)
                      if (availableClients != null &&
                          availableClients.isNotEmpty &&
                          (phone.trim().isEmpty || phone.trim() == '000000000')) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF282838) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person_pin_rounded, size: 15, color: Colors.amber[700]),
                              const SizedBox(width: 6),
                              Text(
                                "Personalizar:",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int?>(
                                    isDense: true,
                                    isExpanded: true,
                                    value: selectedClient?.id,
                                    hint: Text(
                                      "General para todos",
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                                      ),
                                    ),
                                    items: [
                                      DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text(
                                          "General para todos",
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                      ...availableClients.map(
                                        (c) => DropdownMenuItem<int?>(
                                          value: c.id,
                                          child: Text(
                                            "${c.fullName} (${c.puntosActuales} pts)",
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: textColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (newId) {
                                      setModalState(() {
                                        if (newId == null) {
                                          selectedClient = null;
                                          currentClientName = null;
                                          currentPuntos = null;
                                          currentPhone = "";
                                        } else {
                                          selectedClient = availableClients.firstWhere((c) => c.id == newId);
                                          currentClientName = selectedClient!.fullName;
                                          currentPuntos = selectedClient!.puntosActuales;
                                          currentPhone = selectedClient!.phone;
                                        }
                                        updateMessageText();
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Barra Compacta de Personalización Rápida
                      if (rules != null && activeGoals != null && businessName != null) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              // Formato
                              ChoiceChip(
                                avatar: const Icon(Icons.auto_awesome_rounded, size: 13),
                                label: const Text("Completo", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                selected: currentFormat == 'COMPLETO',
                                selectedColor: Colors.amber[700],
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                onSelected: (val) {
                                  if (val) setModalState(() => updateMessageText('COMPLETO'));
                                },
                              ),
                              const SizedBox(width: 6),
                              ChoiceChip(
                                avatar: const Icon(Icons.bolt_rounded, size: 13),
                                label: const Text("Resumen Corto", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                selected: currentFormat == 'RESUMEN',
                                selectedColor: Colors.amber[700],
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                onSelected: (val) {
                                  if (val) setModalState(() => updateMessageText('RESUMEN'));
                                },
                              ),
                              const SizedBox(width: 6),
                              ChoiceChip(
                                avatar: const Icon(Icons.local_fire_department_rounded, size: 13),
                                label: const Text("Invitación Promocional", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                selected: currentFormat == 'PROMO',
                                selectedColor: Colors.amber[700],
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                onSelected: (val) {
                                  if (val) setModalState(() => updateMessageText('PROMO'));
                                },
                              ),
                              const SizedBox(width: 8),

                              // Toggles de Secciones (cuando está en formato COMPLETO)
                              if (currentFormat == 'COMPLETO') ...[
                                Container(width: 1, height: 16, color: isDark ? Colors.white24 : Colors.grey.shade300),
                                const SizedBox(width: 8),
                                FilterChip(
                                  avatar: Icon(secRules ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 13),
                                  label: const Text("Cómo ganar", style: TextStyle(fontSize: 11)),
                                  selected: secRules,
                                  selectedColor: Colors.green.withValues(alpha: 0.2),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                  onSelected: (val) {
                                    setModalState(() {
                                      secRules = val;
                                      updateMessageText();
                                    });
                                  },
                                ),
                                const SizedBox(width: 6),
                                FilterChip(
                                  avatar: Icon(secCatalog ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 13),
                                  label: const Text("Catálogo premios", style: TextStyle(fontSize: 11)),
                                  selected: secCatalog,
                                  selectedColor: Colors.green.withValues(alpha: 0.2),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                  onSelected: (val) {
                                    setModalState(() {
                                      secCatalog = val;
                                      updateMessageText();
                                    });
                                  },
                                ),
                                const SizedBox(width: 6),
                                FilterChip(
                                  avatar: Icon(secStore ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 13),
                                  label: const Text("Datos tienda", style: TextStyle(fontSize: 11)),
                                  selected: secStore,
                                  selectedColor: Colors.green.withValues(alpha: 0.2),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                  onSelected: (val) {
                                    setModalState(() {
                                      secStore = val;
                                      updateMessageText();
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                              ],

                              // Botón Restaurar con icono restart_alt
                              ActionChip(
                                avatar: const Icon(Icons.restart_alt_rounded, size: 13),
                                label: const Text("Restaurar", style: TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                onPressed: () {
                                  setModalState(() {
                                    secRules = true;
                                    secCatalog = true;
                                    secStore = true;
                                    updateMessageText('COMPLETO');
                                  });
                                  LoyaltyToastFeedback.showInfo(
                                    ctx,
                                    "Mensaje restaurado al formato original",
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Campo de texto editable (Ocupa 60%-65% del alto)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white12
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: TextFormField(
                            controller: msgCtrl,
                            maxLines: null,
                            expands: true,
                            onTapOutside: (_) => FocusScope.of(ctx).unfocus(),
                            style: TextStyle(
                              fontSize: 13,
                              color: textColor,
                              height: 1.4,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Botones de acción inferiores
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: msgCtrl.text.trim()),
                              );
                              LoyaltyToastFeedback.showSuccess(
                                context,
                                'Mensaje copiado al portapapeles',
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text("Copiar"),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Si no hay teléfono registrado, el botón principal es [Compartir Cartilla] nativo
                          if (!hasActivePhone) ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final textToSend = msgCtrl.text.trim();
                                  Navigator.pop(ctx);
                                  await SharePlus.instance.share(
                                    ShareParams(
                                      text: textToSend,
                                      subject: "Programa de Puntos y Premios • ${businessName ?? 'Tienda'}",
                                    ),
                                  );
                                  onSent?.call();
                                },
                                icon: const Icon(
                                  Icons.share_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                label: const Text(
                                  "Compartir Cartilla",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ] else ...[
                            // Si tiene teléfono, ofrecemos compartir nativo secundario y botón principal enviar WhatsApp
                            IconButton(
                              onPressed: () async {
                                final textToSend = msgCtrl.text.trim();
                                await SharePlus.instance.share(
                                  ShareParams(
                                    text: textToSend,
                                    subject: "Programa de Puntos y Premios • ${businessName ?? 'Tienda'}",
                                  ),
                                );
                              },
                              icon: const Icon(Icons.share_rounded, size: 18),
                              tooltip: "Compartir a otras apps",
                              style: IconButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final textToSend = msgCtrl.text.trim();
                                  Navigator.pop(ctx);
                                  await launchWhatsApp(
                                    context,
                                    currentPhone,
                                    textToSend,
                                  );
                                  onSent?.call();
                                },
                                icon: const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                label: const Text(
                                  "Enviar por WhatsApp",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 📢 Genera el mensaje comercial formateado para difusión de promociones
  static String buildPromotionMessage({
    required String clientName,
    required String businessName,
    required List<Map<String, dynamic>> products,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('¡Hola, $clientName! 👋');
    buffer.writeln(
      'En *$businessName* tenemos promociones exclusivas y liquidaciones especiales pensadas para ti:\n',
    );

    for (int i = 0; i < products.length; i++) {
      final p = products[i];
      final String name = p['nombre'] ?? p['name'] ?? 'Producto';
      final String presentation =
          (p['presentation'] != null &&
              (p['presentation'] as String).isNotEmpty)
          ? ' (${p['presentation']})'
          : '';
      final double regularPrice =
          (p['precioRegular'] as num?)?.toDouble() ??
          (p['regular_price'] as num?)?.toDouble() ??
          0.0;
      final double offerPrice =
          (p['precioEfectivo'] as num?)?.toDouble() ??
          (p['precio_oferta'] as num?)?.toDouble() ??
          (p['offer_price'] as num?)?.toDouble() ??
          0.0;
      final double savings = (regularPrice - offerPrice).clamp(
        0.0,
        double.infinity,
      );

      buffer.writeln('🔥 *${i + 1}. $name$presentation*');
      buffer.writeln(
        '   Antes: ${AppCurrency.format(regularPrice)} ➡️ *¡Hoy: ${AppCurrency.format(offerPrice)}!*',
      );
      if (savings > 0) {
        buffer.writeln('   ✨ _Ahorro de ${AppCurrency.format(savings)}_');
      }
      buffer.writeln();
    }

    buffer.writeln(
      '⚡ _Precios válidos por tiempo limitado o hasta agotar existencias._',
    );
    buffer.writeln(
      '¿Deseas que te reservemos alguno para tu próximo pedido? ¡Escríbenos por aquí! 📦',
    );
    return buffer.toString().trim();
  }

  /// 📢 Plantilla 4: Difusor de Ofertas y Liquidación
  static Future<bool> sendPromotionBroadcasterNotification({
    required BuildContext context,
    required String phone,
    required String clientName,
    required String businessName,
    required List<Map<String, dynamic>> products,
    String? customMessage,
  }) async {
    final msg =
        customMessage ??
        buildPromotionMessage(
          clientName: clientName,
          businessName: businessName,
          products: products,
        );
    return await launchWhatsApp(context, phone, msg);
  }
}
