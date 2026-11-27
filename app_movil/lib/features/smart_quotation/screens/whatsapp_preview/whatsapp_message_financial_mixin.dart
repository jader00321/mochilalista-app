part of '../whatsapp_preview_screen.dart';

mixin _WhatsAppMessageFinancialMixin on _WhatsAppPreviewScreenStateBase {
  @override
  void _appendLoanDetailSection(StringBuffer sb) {
    final double totalWithInterest =
        (_saleData!['monto_total'] ?? _quotation!.totalAmount).toDouble();
    final double paid = (_saleData!['monto_pagado'] ?? 0.0).toDouble();
    final double interestRate = (_saleData!['porcentaje_interes'] ?? 0.0)
        .toDouble();
    final double abonoInicial = (_saleData!['abono_inicial'] ?? 0.0).toDouble();

    double moraTotal = (_saleData!['mora_total'] as num?)?.toDouble() ?? 0.0;
    if (moraTotal <= 0 && _saleData!['cuotas'] != null) {
      final list = _saleData!['cuotas'] as List;
      moraTotal = list.fold(
        0.0,
        (acc, c) => acc + ((c['mora_monto'] as num?)?.toDouble() ?? 0.0),
      );
    }

    // Regla de Oro: Proteger Capital e Interés Original ante recargos de mora
    final double pureTotalWithInterest = (totalWithInterest - moraTotal) > 0
        ? (totalWithInterest - moraTotal)
        : 0.0;
    final double debtWithInterest = (pureTotalWithInterest - abonoInicial) > 0
        ? (pureTotalWithInterest - abonoInicial)
        : 0.0;
    final double debtBase = (interestRate > 0 && debtWithInterest > 0)
        ? debtWithInterest / (1 + (interestRate / 100))
        : debtWithInterest;
    final double interestAmount = debtWithInterest - debtBase;
    final double capitalNeto = abonoInicial + debtBase;
    final double debt = totalWithInterest - paid > 0
        ? totalWithInterest - paid
        : 0.0;

    final String rateLabel = interestRate > 0
        ? '${interestRate.toStringAsFixed(1).replaceAll('.0', '')}%'
        : '0%';
    final String interestDisplay = interestAmount > 0.01
        ? "+ ${AppCurrency.format(interestAmount)}"
        : AppCurrency.format(0.0);

    sb.writeln("🏦 *DETALLE DEL PRÉSTAMO*");
    sb.writeln("▪ Capital Prestado: *${AppCurrency.format(capitalNeto)}*");
    sb.writeln("▪ Interés Aplicado ($rateLabel): *$interestDisplay*");
    if (moraTotal > 0.01) {
      sb.writeln("▪ Recargo por Mora: *+ ${AppCurrency.format(moraTotal)}*");
    }
    sb.writeln(
      "▪ Total a Devolver: *${AppCurrency.format(totalWithInterest)}*",
    );

    if (abonoInicial > 0.01) {
      sb.writeln("▪ Abono Inicial: *${AppCurrency.format(abonoInicial)}*");
    }
    if (paid > 0.01) {
      sb.writeln("▪ Monto Total Abonado: *${AppCurrency.format(paid)}* ✅");
    }
    if (debt > 0.01 && _config.showDebtInfo) {
      sb.writeln(
        "▪ *Saldo Pendiente por Pagar: ${AppCurrency.format(debt)}* ⚠️",
      );
    } else if (debt <= 0.01) {
      sb.writeln("▪ Estado del Préstamo: *TOTALMENTE CANCELADO* ✅");
    }
    sb.writeln("");
  }

  @override
  void _appendTotalSummarySection(StringBuffer sb, {required bool isSale}) {
    final double finalTotal = isSale
        ? (_saleData!['monto_total'] ?? 0).toDouble()
        : _quotation!.totalAmount;
    final double finalSavings = isSale
        ? (_saleData!['descuento_aplicado'] ?? 0).toDouble()
        : _quotation!.totalSavings;

    double moraTotalSale = 0.0;
    if (isSale) {
      moraTotalSale = (_saleData!['mora_total'] as num?)?.toDouble() ?? 0.0;
      if (moraTotalSale <= 0 && _saleData!['cuotas'] != null) {
        final list = _saleData!['cuotas'] as List;
        moraTotalSale = list.fold(
          0.0,
          (acc, c) => acc + ((c['mora_monto'] as num?)?.toDouble() ?? 0.0),
        );
      }
    }

    sb.writeln("📊 *RESUMEN TOTAL*");
    sb.writeln("▪ Importe Total: *${AppCurrency.format(finalTotal)}*");

    if (_config.showSavingsSection && finalSavings > 0.01) {
      if (_config.style == WhatsAppMessageStyle.urgentOffer) {
        sb.writeln(
          "▪ 🎉 *¡AHORRO ESPECIAL: ${AppCurrency.format(finalSavings)}!*",
        );
      } else {
        sb.writeln("▪ Ahorro Total: *${AppCurrency.format(finalSavings)}* 🎉");
      }
    }

    if (moraTotalSale > 0.01) {
      sb.writeln(
        "▪ Recargo por Mora: *+ ${AppCurrency.format(moraTotalSale)}*",
      );
    }

    if (isSale) {
      final double paid = (_saleData!['monto_pagado'] ?? 0.0).toDouble();
      double debt = finalTotal - paid;
      if (debt < 0) debt = 0;

      if (paid > 0.01) {
        sb.writeln("▪ Abonado: *${AppCurrency.format(paid)}* ✅");
      }
      if (debt > 0.01 && _config.showDebtInfo) {
        sb.writeln(
          "▪ *Saldo Pendiente por Pagar: ${AppCurrency.format(debt)}* ⚠️",
        );
      }
    }
    sb.writeln("");
  }

  @override
  void _appendInstallmentsScheduleSection(StringBuffer sb) {
    final List<dynamic>? cuotasRaw = _saleData?['cuotas'];
    if (cuotasRaw == null || cuotasRaw.isEmpty) return;

    sb.writeln("📅 *CRONOGRAMA DE PAGOS* (${cuotasRaw.length} Cuotas)");
    for (var c in cuotasRaw) {
      final double cuotaMonto = (num.tryParse(c['monto'].toString()) ?? 0.0)
          .toDouble();
      final double cuotaPagado =
          (num.tryParse((c['monto_pagado'] ?? 0.0).toString()) ?? 0.0)
              .toDouble();
      final double saldoFalta = (cuotaMonto - cuotaPagado) > 0.001
          ? (cuotaMonto - cuotaPagado)
          : 0.0;
      final double moraMonto =
          (num.tryParse((c['mora_monto'] ?? 0.0).toString()) ?? 0.0).toDouble();
      final double montoOriginal =
          (num.tryParse((c['monto_original'] ?? cuotaMonto).toString()) ??
                  cuotaMonto)
              .toDouble();
      final bool tieneMora = moraMonto > 0.01;
      final bool pagado =
          c['estado'] == 'pagado' || (saldoFalta <= 0.01 && cuotaMonto > 0);

      final dateInfo = CuotaDateHelper.evaluate(c['fecha_vencimiento']);
      final int daysOverdue = dateInfo.daysOverdue;
      final bool isVencida = !pagado && dateInfo.isPast;

      final String amountText = tieneMora
          ? "*${AppCurrency.format(cuotaMonto)}* (Base: ${AppCurrency.format(montoOriginal)} + Mora: ${AppCurrency.format(moraMonto)})"
          : "*${AppCurrency.format(cuotaMonto)}*";

      if (pagado) {
        sb.writeln(
          "✅ Cuota ${c['numero_cuota']}: $amountText (${dateInfo.fullLabel}) - *Pagada*",
        );
      } else if (isVencida) {
        final String vencidaStatus =
            "- *Vencida (hace $daysOverdue ${daysOverdue == 1 ? 'día' : 'días'})*";
        if (cuotaPagado > 0.01) {
          sb.writeln(
            "🔴 Cuota ${c['numero_cuota']}: $amountText (Abonó: ${AppCurrency.format(cuotaPagado)} • Falta: ${AppCurrency.format(saldoFalta)}) (${dateInfo.fullLabel}) $vencidaStatus",
          );
        } else {
          sb.writeln(
            "🔴 Cuota ${c['numero_cuota']}: $amountText (${dateInfo.fullLabel}) $vencidaStatus",
          );
        }
      } else if (cuotaPagado > 0.01) {
        sb.writeln(
          "🟠 Cuota ${c['numero_cuota']}: $amountText (Abonó: ${AppCurrency.format(cuotaPagado)} • Falta: ${AppCurrency.format(saldoFalta)}) (${dateInfo.fullLabel}) - *Pago Parcial*",
        );
      } else if (dateInfo.isToday) {
        sb.writeln(
          "⏳ Cuota ${c['numero_cuota']}: $amountText (${dateInfo.fullLabel}) - *Vence Hoy*",
        );
      } else {
        sb.writeln(
          "⏳ Cuota ${c['numero_cuota']}: $amountText (${dateInfo.fullLabel}) - *Pendiente*",
        );
      }
    }
    sb.writeln("");
  }

  @override
  void _appendDeliveryValidityPaymentBusinessClosing(
    StringBuffer sb, {
    required bool isSale,
    required bool isLoan,
  }) {
    if (isSale && !isLoan && _config.showDeliveryInfo) {
      final String deliveryStatus = _saleData!['estado_entrega'] ?? 'entregado';
      if (deliveryStatus != 'entregado') {
        sb.writeln("📦 *ESTADO DEL PEDIDO*");
        sb.writeln(
          "▪ Estado: *${deliveryStatus.toUpperCase().replaceAll('_', ' ')}*",
        );
        if (_saleData!['fecha_entrega'] != null) {
          final dateFormatted = AppDateFormatter.ddMMyyyy.format(
            DateTime.parse(_saleData!['fecha_entrega']),
          );
          sb.writeln("▪ Entrega programada: $dateFormatted");
        }
        sb.writeln("");
      }
    }

    if (!isSale && _config.includeValidity) {
      if (_config.style == WhatsAppMessageStyle.urgentOffer) {
        sb.writeln(
          "⏳ *Promoción por tiempo limitado:* Precios válidos por 7 días calendario.",
        );
      } else {
        sb.writeln("⏳ *Validez:* Precios válidos por 7 días calendario.");
      }
      sb.writeln("");
    }

    if (_config.showPaymentInfo) {
      final paymentText = _bizPaymentCtrl.text.trim();
      if (isLoan) {
        final double totalDebt = (_saleData!['monto_total'] ?? 0).toDouble();
        final double paid = (_saleData!['monto_pagado'] ?? 0).toDouble();
        if ((totalDebt - paid) > 0.01 && paymentText.isNotEmpty) {
          sb.writeln(
            "💳 *CUENTAS DE ABONO* (Para amortizar o cancelar cuotas)",
          );
          sb.writeln(paymentText);
          sb.writeln("");
        }
      } else if (isSale) {
        final double total = (_saleData!['monto_total'] ?? 0).toDouble();
        final double paid = (_saleData!['monto_pagado'] ?? 0).toDouble();
        if ((total - paid) > 0.01 && paymentText.isNotEmpty) {
          sb.writeln("💳 *MEDIOS DE PAGO* (Para cancelar saldo)");
          sb.writeln(paymentText);
          sb.writeln("");
        } else if ((total - paid) <= 0.01 &&
            _saleData!['metodo_pago'] != null) {
          sb.writeln(
            "💳 *PAGADO MEDIANTE:* ${_saleData!['metodo_pago'].toString().toUpperCase()}",
          );
          sb.writeln("");
        }
      } else {
        sb.writeln("💳 *MEDIOS DE PAGO*");
        sb.writeln(
          paymentText.isNotEmpty
              ? paymentText
              : "Aceptamos efectivo, transferencias y pagos digitales (Yape / Plin).",
        );
        sb.writeln("");
      }
    }

    if (_config.showBusinessInfo &&
        _config.style != WhatsAppMessageStyle.compact) {
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      sb.writeln("🏢 *Visítanos en ${authProv.businessName}*");
      if (_config.includeShopAddress && _bizAddressCtrl.text.isNotEmpty) {
        sb.writeln("📍 Dirección: ${_bizAddressCtrl.text}");
      }
      if (_config.includeShopAddress && _bizLat != null && _bizLng != null) {
        sb.writeln(
          "🗺️ Ver en Mapa: https://www.google.com/maps/search/?api=1&query=$_bizLat,$_bizLng",
        );
      }
      if (_config.includeShopRuc && _bizRucCtrl.text.isNotEmpty) {
        sb.writeln("📄 RUC: ${_bizRucCtrl.text}");
      }
      if (_config.includeOwnerPhone && _bizPhoneCtrl.text.isNotEmpty) {
        sb.writeln("📞 Contacto: ${_bizPhoneCtrl.text}");
      }
      sb.writeln("");
    }

    if (_config.customClosing != null &&
        _config.customClosing!.trim().isNotEmpty) {
      sb.writeln(_config.customClosing!.trim());
    } else if (!isSale) {
      sb.writeln(
        _config.style == WhatsAppMessageStyle.urgentOffer
            ? "¡No dejes pasar esta oportunidad! Confírmanos tu pedido para reservarte el stock."
            : "¡Quedamos atentos a tu confirmación!",
      );
    } else if (isLoan) {
      sb.writeln(
        "Cualquier duda o consulta sobre tu estado de pagos, contáctanos.",
      );
    }
  }
}
