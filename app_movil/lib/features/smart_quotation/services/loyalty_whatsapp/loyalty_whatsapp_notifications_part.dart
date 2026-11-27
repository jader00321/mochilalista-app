part of '../loyalty_whatsapp_service.dart';

class _LoyaltyWhatsappMessages {
  _LoyaltyWhatsappMessages._();

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

    return LoyaltyWhatsAppService.launchWhatsApp(context, phone, msg);
  }

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

    return LoyaltyWhatsAppService.launchWhatsApp(context, phone, msg);
  }

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

    return LoyaltyWhatsAppService.launchWhatsApp(context, phone, msg);
  }

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
    return LoyaltyWhatsAppService.launchWhatsApp(context, phone, msg);
  }
}
