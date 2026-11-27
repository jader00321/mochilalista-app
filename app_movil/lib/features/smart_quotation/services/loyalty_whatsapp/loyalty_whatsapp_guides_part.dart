part of '../loyalty_whatsapp_service.dart';

class _LoyaltyWhatsappGuides {
  _LoyaltyWhatsappGuides._();

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
    final cleanBiz = LoyaltyWhatsAppService.formatBusinessName(businessName);

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
        final bool isRedundant =
            (g.tipoBeneficio == 'DESCUENTO_PORCENTAJE' &&
                lowerName.contains('${g.valorBeneficio.toInt()}%')) ||
            (g.tipoBeneficio == 'DESCUENTO_MONTO' &&
                lowerName.contains(
                  AppCurrency.format(g.valorBeneficio).toLowerCase(),
                )) ||
            lowerName.contains(benefitLabel.toLowerCase());

        if (isRedundant) {
          if (g.descripcion != null &&
              g.descripcion!.isNotEmpty &&
              !lowerName.contains(g.descripcion!.toLowerCase())) {
            buffer.writeln(
              '• *${g.puntosRequeridos} pts:* ${g.nombre} (${g.descripcion!})',
            );
          } else {
            buffer.writeln('• *${g.puntosRequeridos} pts:* ${g.nombre}');
          }
        } else {
          buffer.writeln(
            '• *${g.puntosRequeridos} pts:* ${g.nombre} ($benefitLabel)',
          );
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

  static String buildSummaryGuideMessage({
    required String businessName,
    required LoyaltyRulesModel rules,
    required List<RewardGoalModel> activeGoals,
    String? clientName,
    int? puntosActuales,
  }) {
    final buffer = StringBuffer();
    final cleanBiz = LoyaltyWhatsAppService.formatBusinessName(businessName);

    buffer.writeln('⚡ *PROGRAMA DE PUNTOS • $cleanBiz* 🎁\n');
    if (clientName != null && clientName.trim().isNotEmpty) {
      buffer.writeln(
        '¡Hola, *${clientName.trim()}*! Te resumimos cómo ganar premios:',
      );
    } else {
      buffer.writeln('¡Gana premios por tus compras y pagos puntuales!');
    }

    buffer.writeln(
      '⭐ *Compras al Contado:* +${rules.puntosPorUnidadMoneda} pto por cada ${AppCurrency.format(rules.montoBaseCompra)}.',
    );
    if (rules.bonoPagoPuntualActivo) {
      buffer.writeln(
        '⭐ *Pagos Puntuales:* +${rules.puntosPagoPuntual} pts por cancelar tu cuota a tiempo.',
      );
    }
    if (activeGoals.isNotEmpty) {
      final firstGoal = activeGoals.first;
      buffer.writeln(
        '🎁 *Primer Premio:* ${firstGoal.nombre} a los ${firstGoal.puntosRequeridos} pts.',
      );
    }
    if (puntosActuales != null) {
      buffer.writeln('📊 *Tu saldo actual:* *$puntosActuales pts*');
    }
    buffer.writeln('\n¡Visítanos para seguir sumando y canjear tus premios! ✨');
    return buffer.toString().trim();
  }

  static String buildPromoInviteMessage({
    required String businessName,
    required List<RewardGoalModel> activeGoals,
    String? clientName,
    int? puntosActuales,
  }) {
    final buffer = StringBuffer();
    final cleanBiz = LoyaltyWhatsAppService.formatBusinessName(businessName);

    buffer.writeln('🔥 *¡DESCUBRE TUS BENEFICIOS EN $cleanBiz!* 🎁\n');
    if (clientName != null && clientName.trim().isNotEmpty) {
      buffer.writeln(
        '¡Hola, *${clientName.trim()}*! Queremos consentirte por ser nuestro cliente preferencial.',
      );
    } else {
      buffer.writeln(
        'Queremos consentirte por ser nuestro cliente preferencial.',
      );
    }
    if (puntosActuales != null) {
      buffer.writeln(
        '⭐ Ya cuentas con *$puntosActuales pts* acumulados en tu cuenta.',
      );
    }
    if (activeGoals.isNotEmpty) {
      buffer.writeln('\n🏆 *Premios que puedes llevarte:*');
      for (var g in activeGoals.take(3)) {
        buffer.writeln('• ${g.nombre} (Con ${g.puntosRequeridos} pts)');
      }
    }
    buffer.writeln(
      '\n¡Haz tu pedido hoy y sigue acumulando beneficios exclusivos! 📦✨',
    );
    return buffer.toString().trim();
  }
}
