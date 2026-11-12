import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El cliente no tiene un teléfono válido registrado'),
          ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo abrir WhatsApp en este dispositivo'),
            ),
          );
        }
        return false;
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al intentar abrir WhatsApp')),
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

  /// 📜 Plantilla 6: Cartilla / Guía Oficial de Cómo Ganar Puntos y Premios
  static String buildLoyaltyGuideAndCatalogMessage({
    required String businessName,
    required LoyaltyRulesModel rules,
    required List<RewardGoalModel> activeGoals,
    String? clientName,
    int? puntosActuales,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      '📜 *GUÍA OFICIAL DE PUNTOS Y PREMIOS • $businessName* 🎁\n',
    );

    if (clientName != null && clientName.isNotEmpty) {
      buffer.writeln(
        'Estimado(a) *$clientName*, te compartimos cómo funciona nuestro programa de lealtad para premiar tu preferencia:\n',
      );
    } else {
      buffer.writeln(
        'Te compartimos cómo funciona nuestro programa de lealtad para premiar tu preferencia:\n',
      );
    }

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

    if (activeGoals.isNotEmpty) {
      buffer.writeln('🎁 *CATÁLOGO DE PREMIOS Y DESCUENTOS:*');
      for (var g in activeGoals) {
        buffer.writeln(
          '• *${g.puntosRequeridos} pts:* ${g.nombre} (${g.formattedBenefit})',
        );
      }
      buffer.writeln();
    }

    if (puntosActuales != null) {
      buffer.writeln('⭐ *Tu saldo disponible hoy:* *$puntosActuales pts*\n');
    }

    buffer.writeln(
      '¡Tus puntos se acumulan libremente y tú eliges cuándo reclamar! Visítanos y sigue sumando. Estamos para servirte. ✨',
    );
    return buffer.toString().trim();
  }

  /// 📱 Modal de Vista Previa Editable antes de enviar cualquier mensaje a WhatsApp
  static Future<void> showEditableWhatsAppPreviewModal({
    required BuildContext context,
    required String title,
    required String phone,
    required String initialMessage,
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

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
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
                  padding: EdgeInsets.fromLTRB(20, 16, 20, effectiveBottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Asa
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
                      const SizedBox(height: 14),

                      // Encabezado
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF25D366,
                              ).withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chat_bubble_rounded,
                              color: Color(0xFF25D366),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
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
                                  phone.isNotEmpty
                                      ? "Destino: $phone"
                                      : "Vista previa del mensaje",
                                  style: TextStyle(
                                    fontSize: 12,
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
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Campo de texto editable
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
                      const SizedBox(height: 14),

                      // Botones de acción
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: msgCtrl.text.trim()),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Mensaje copiado al portapapeles',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text("Copiar"),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final textToSend = msgCtrl.text.trim();
                                Navigator.pop(ctx);
                                await launchWhatsApp(
                                  context,
                                  phone,
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
