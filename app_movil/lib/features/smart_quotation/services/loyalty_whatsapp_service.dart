import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';

class LoyaltyWhatsAppService {
  LoyaltyWhatsAppService._();

  static String _cleanPhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 9 && !clean.startsWith('51')) {
      return '51$clean';
    }
    return clean;
  }

  static Future<bool> launchWhatsApp(BuildContext context, String phone, String message) async {
    final clean = _cleanPhone(phone);
    if (clean.isEmpty || clean == '000000000') {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El cliente no tiene un teléfono válido registrado')),
        );
      }
      return false;
    }

    final url = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir WhatsApp en este dispositivo')),
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

    final msg = '''
🎉 *¡Felicidades, $clientName!* 🎉

En *$businessName* valoramos mucho tu fidelidad y constancia.

Por tus compras y pagos puntuales, acabas de desbloquear un beneficio exclusivo:
🎁 *Premio:* $benefitText
🏆 *Nivel de Fidelidad:* ${tier.displayName}
⭐ *Saldo de Puntos Disponible:* $puntosSaldo pts

Ven a la tienda o escríbenos para canjear tu premio en tu próxima compra. ¡Muchas gracias por tu preferencia! ✨
'''.trim();

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
    final msg = '''
¡Hola, $clientName! 👋

Te saludamos desde *$businessName* para contarte que estás muy cerca de tu próximo premio:

🎯 *Meta:* ${goal.nombre}
🎁 *Beneficio al llegar:* ${goal.formattedBenefit}
📊 *Progreso:* $puntosActuales de ${goal.puntosRequeridos} pts
⚡ *¡Solo te faltan $puntosFaltantes puntos!*

Realiza tu compra o cancela tu cuota a tiempo esta semana y desbloquearás este beneficio de inmediato. ¡Te esperamos! 📦✨
'''.trim();

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
    String rachaText = streak > 0 ? '\n🔥 *Racha de Pagos Puntuales:* $streak cuotas a tiempo consecutivas' : '';
    final msg = '''
🌟 *¡Excelente noticia, $clientName!* 🌟

Queremos felicitarte de parte de *$businessName*. Gracias a tu excelente comportamiento comercial y puntualidad, tu cuenta ha alcanzado:

🏆 *Rango Comercial:* ${tier.displayName}
📈 *Score de Reputación:* $score / 1000 pts$rachaText

Tu categoría te otorga atención preferencial y beneficios especiales en todos tus pedidos. ¡Gracias por ser un cliente ejemplar! 🤝✨
'''.trim();

    return await launchWhatsApp(context, phone, msg);
  }

  /// 📢 Genera el mensaje comercial formateado para difusión de promociones
  static String buildPromotionMessage({
    required String clientName,
    required String businessName,
    required List<Map<String, dynamic>> products,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('¡Hola, $clientName! 👋');
    buffer.writeln('En *$businessName* tenemos promociones exclusivas y liquidaciones especiales pensadas para ti:\n');

    for (int i = 0; i < products.length; i++) {
      final p = products[i];
      final String name = p['nombre'] ?? p['name'] ?? 'Producto';
      final String presentation = (p['presentation'] != null && (p['presentation'] as String).isNotEmpty)
          ? ' (${p['presentation']})'
          : '';
      final double regularPrice = (p['precioRegular'] as num?)?.toDouble() ??
          (p['regular_price'] as num?)?.toDouble() ??
          0.0;
      final double offerPrice = (p['precioEfectivo'] as num?)?.toDouble() ??
          (p['precio_oferta'] as num?)?.toDouble() ??
          (p['offer_price'] as num?)?.toDouble() ??
          0.0;
      final double savings = (regularPrice - offerPrice).clamp(0.0, double.infinity);

      buffer.writeln('🔥 *${i + 1}. $name$presentation*');
      buffer.writeln('   Antes: ${AppCurrency.format(regularPrice)} ➡️ *¡Hoy: ${AppCurrency.format(offerPrice)}!*');
      if (savings > 0) {
        buffer.writeln('   ✨ _Ahorro de ${AppCurrency.format(savings)}_');
      }
      buffer.writeln();
    }

    buffer.writeln('⚡ _Precios válidos por tiempo limitado o hasta agotar existencias._');
    buffer.writeln('¿Deseas que te reservemos alguno para tu próximo pedido? ¡Escríbenos por aquí! 📦');
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
    final msg = customMessage ??
        buildPromotionMessage(
          clientName: clientName,
          businessName: businessName,
          products: products,
        );
    return await launchWhatsApp(context, phone, msg);
  }
}

