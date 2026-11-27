part of '../whatsapp_preview_modal.dart';

extension _WhatsAppPreviewMessageBuilderPart on _WhatsAppPreviewModalState {
  static const String _cuentasBlock =
      "\n\n💳 *Canales oficiales de abono:*\n"
      "📱 *Yape / Plin:* Al número registrado de la tienda.\n"
      "🏦 *Transferencia Bancaria:* Solicitar número de cuenta o CCI.\n"
      "🏪 *Tienda física:* En nuestro horario habitual.\n\n"
      "Una vez realizado el pago, por favor envíenos la constancia para registrarla en su estado de cuenta. ¡Muchas gracias!";

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

    final name = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : "Estimado cliente";

    if (widget.cuota != null) {
      return _buildSingleCuotaMessage(
        name: name,
        tType: tType,
        sMora: sMora,
        sCuentas: sCuentas,
      );
    }

    return _buildMultipleCuotasMessage(
      name: name,
      tType: tType,
      sDesglose: sDesglose,
      sMora: sMora,
      sCuentas: sCuentas,
      totalExigible: _calculateExigibleTotal(),
    );
  }

  String _buildSingleCuotaMessage({
    required String name,
    required String tType,
    required bool sMora,
    required bool sCuentas,
  }) {
    final c = widget.cuota!;
    final cuotaNum = c['numero_cuota'] ?? 1;
    final double totalCuota = (num.tryParse(c['monto'].toString()) ?? 0.0)
        .toDouble();
    final double pagado =
        (num.tryParse((c['monto_pagado'] ?? 0.0).toString()) ?? 0.0).toDouble();
    final double montoOriginal =
        (num.tryParse((c['monto_original'] ?? totalCuota).toString()) ??
                totalCuota)
            .toDouble();
    final double moraMonto =
        (num.tryParse((c['mora_monto'] ?? 0.0).toString()) ?? 0.0).toDouble();
    final double saldoFalta = totalCuota - pagado > 0
        ? totalCuota - pagado
        : 0.0;

    final dateInfo = CuotaDateHelper.evaluate(c['fecha_vencimiento']);
    final int daysDiff = dateInfo.daysOverdue;
    final bool isVencida = dateInfo.isPast && saldoFalta > 0.01;

    if (tType == 'cordial') {
      final sb = StringBuffer();
      sb.write(
        "Hola $name 👋. Le saludamos cordialmente de la tienda. Le recordamos que su cuota #$cuotaNum por ${AppCurrency.format(totalCuota)} ${dateInfo.prefix.toLowerCase()} ${dateInfo.dateFormatted}. Agradecemos su puntualidad. ¡Que tenga un excelente día!",
      );
      if (sCuentas) sb.write(_cuentasBlock);
      return sb.toString();
    }

    if (tType == 'mora') {
      final sb = StringBuffer();
      sb.writeln("Hola $name 👋. Te saludamos de la tienda.");
      sb.writeln("\n🚨 *AVISO URGENTE: CUOTA EN MOROSIDAD*");
      sb.write(
        "Le informamos que su *Cuota #$cuotaNum* por ${AppCurrency.format(totalCuota)} venció el ${dateInfo.dateFormatted} (hace $daysDiff ${daysDiff == 1 ? 'día' : 'días'})",
      );
      if (sMora && moraMonto > 0.01) {
        sb.writeln(
          " e incluye un recargo por mora acumulada de ${AppCurrency.format(moraMonto)}.",
        );
      } else {
        sb.writeln(".");
      }
      sb.writeln(
        "Le solicitamos regularizar su pago a la brevedad posible para evitar el incremento de recargos adicionales.",
      );
      if (sCuentas) {
        sb.write(_cuentasBlock);
      } else {
        sb.write(
          "\nPuede realizar su abono por Yape, Plin o en tienda física. ¡Muchas gracias!",
        );
      }
      return sb.toString();
    }

    if (tType == 'resumen') {
      final sb = StringBuffer();
      sb.write(
        "Hola $name 👋. Le recordamos su cuota #$cuotaNum (${dateInfo.fullLabel}) por un saldo exigible de *${AppCurrency.format(saldoFalta)}*.",
      );
      if (sCuentas) sb.write(_cuentasBlock);
      return sb.toString();
    }

    final sb = StringBuffer();
    sb.writeln("Hola $name 👋. Te saludamos de la tienda.");
    if (isVencida) {
      sb.writeln("\n⚠️ *RECORDATORIO DE CUOTA VENCIDA*");
      sb.writeln(
        "Le informamos que su *Cuota #$cuotaNum* venció el ${dateInfo.dateFormatted} (hace $daysDiff ${daysDiff == 1 ? 'día' : 'días'}).",
      );
    } else {
      sb.writeln("\n📅 *RECORDATORIO DE PAGO*");
      sb.writeln(
        "Le recordamos que su *Cuota #$cuotaNum* ${dateInfo.prefix.toLowerCase()} ${dateInfo.dateFormatted}.",
      );
    }

    if (sMora && moraMonto > 0.01) {
      sb.writeln(
        "▪ Total Cuota: *${AppCurrency.format(totalCuota)}* (Base: ${AppCurrency.format(montoOriginal)} + Mora: ${AppCurrency.format(moraMonto)})",
      );
    } else {
      sb.writeln("▪ Total Cuota: *${AppCurrency.format(totalCuota)}*");
    }

    if (pagado > 0.01) {
      sb.writeln(
        "▪ Estado: ${isVencida ? '🔴 Vencida hace $daysDiff d • Pago Parcial' : '🟠 Pago Parcial'}",
      );
      sb.writeln(
        "▪ Abonado: ${AppCurrency.format(pagado)} ✅ | *Falta cancelar: ${AppCurrency.format(saldoFalta)}* 🔴",
      );
    } else {
      sb.writeln("▪ *Monto exigible: ${AppCurrency.format(saldoFalta)}* 🔴");
    }

    if (sCuentas) {
      sb.write(_cuentasBlock);
    } else {
      sb.writeln(
        "\nPuede realizar su abono mediante Yape, Plin o directamente en tienda física. Si ya efectuó el pago, por favor haga caso omiso a este mensaje. ¡Muchas gracias!",
      );
    }
    return sb.toString();
  }

  String _buildMultipleCuotasMessage({
    required String name,
    required String tType,
    required bool sDesglose,
    required bool sMora,
    required bool sCuentas,
    required double totalExigible,
  }) {
    final int count = widget.multipleCuotas?.length ?? 0;
    final sb = StringBuffer();

    if (tType == 'resumen') {
      sb.writeln("Hola $name 👋. Te saludamos de la tienda.");
      sb.writeln("\n⚡ *RESUMEN DE CUOTAS PENDIENTES*");
      sb.writeln(
        "Le recordamos que mantiene *$count cuota(s) pendiente(s)* por un saldo total exigible de *${AppCurrency.format(totalExigible)}*.",
      );
      if (sDesglose && count > 0) {
        sb.writeln("\n*Cuotas:*");
        _appendCuotasList(sb, sMora);
      }
      if (sCuentas) {
        sb.write(_cuentasBlock);
      } else {
        sb.writeln(
          "\nAgradeceremos su regularización vía Yape, Plin o en tienda física. ¡Muchas gracias!",
        );
      }
      return sb.toString().trim();
    }

    if (tType == 'cordial') {
      sb.writeln(
        "Hola $name 👋. Esperamos que se encuentre muy bien. Le saludamos cordialmente de la tienda.",
      );
      sb.writeln("\n🤝 *RECORDATORIO AMABLE DE PAGO*");
      sb.writeln(
        "Le escribimos para recordarle que mantiene un saldo pendiente de *${AppCurrency.format(totalExigible)}* correspondiente a *$count cuota(s)*.",
      );
      if (sDesglose && count > 0) {
        sb.writeln("\n*Detalle de cuotas:*");
        _appendCuotasList(sb, sMora);
      }
      if (sCuentas) {
        sb.write(_cuentasBlock);
      } else {
        sb.writeln(
          "\nAgradecemos de antemano su amable atención y puntualidad. ¡Que tenga un excelente día!",
        );
      }
      return sb.toString().trim();
    }

    if (tType == 'mora') {
      sb.writeln("Hola $name 👋. Te saludamos de la tienda.");
      sb.writeln("\n🚨 *AVISO URGENTE: CUOTAS EN MOROSIDAD*");
      sb.writeln(
        "Le informamos que registra *$count cuota(s) vencida(s)* con recargos acumulados, alcanzando un saldo exigible de *${AppCurrency.format(totalExigible)}*.",
      );
      if (sDesglose && count > 0) {
        sb.writeln("\n*Desglose con mora acumulada:*");
        _appendCuotasList(sb, sMora);
      }
      sb.writeln(
        "\nLe invitamos a regularizar su cuenta hoy mismo para evitar la acumulación de mayores recargos diarios.",
      );
      if (sCuentas) {
        sb.write(_cuentasBlock);
      } else {
        sb.writeln(
          "Puede abonar mediante Yape, Plin o directamente en tienda física. ¡Muchas gracias!",
        );
      }
      return sb.toString().trim();
    }

    sb.writeln("Hola $name 👋. Te saludamos de la tienda.");
    if (count > 0) {
      sb.writeln("\n⚠️ *ESTADO DE CUENTA: CUOTAS EN OBSERVACIÓN*");
      sb.writeln(
        "Le escribimos para recordarle que mantiene *$count cuota(s) pendiente(s)* por un saldo total exigible de *${AppCurrency.format(totalExigible)}*:\n",
      );
      if (sDesglose) {
        _appendCuotasList(sb, sMora);
      }
    } else {
      sb.writeln(
        "\nLe escribimos para recordarle que cuenta con un saldo pendiente de *${AppCurrency.format(totalExigible)}*.",
      );
    }

    if (sCuentas) {
      sb.write(_cuentasBlock);
    } else {
      sb.writeln(
        "\nAgradeceremos su pronta regularización vía Yape, Plin o en tienda física. ¡Muchas gracias por su atención!",
      );
    }
    return sb.toString().trim();
  }

  void _appendCuotasList(StringBuffer sb, bool sMora) {
    if (widget.multipleCuotas == null) return;
    for (final raw in widget.multipleCuotas!) {
      final c = raw is Map ? raw : (raw as dynamic);
      final numCuota = c['numero_cuota'] ?? c['installmentNumber'] ?? '';
      final monto =
          (num.tryParse((c['monto'] ?? c['amount'] ?? 0.0).toString()) ?? 0.0)
              .toDouble();
      final montoOriginal =
          (num.tryParse(
                    (c['monto_original'] ?? c['montoOriginal'] ?? monto)
                        .toString(),
                  ) ??
                  monto)
              .toDouble();
      final mora =
          (num.tryParse(
                    (c['mora_monto'] ?? c['moraMonto'] ?? 0.0).toString(),
                  ) ??
                  0.0)
              .toDouble();
      final pagado =
          (num.tryParse(
                    (c['monto_pagado'] ?? c['montoPagado'] ?? 0.0).toString(),
                  ) ??
                  0.0)
              .toDouble();
      final due = c['fecha_vencimiento'] ?? c['dueDate'] ?? '';
      final falta = (monto - pagado) > 0 ? (monto - pagado) : 0.0;
      final String moraDetail = (sMora && mora > 0.01)
          ? " (Base: ${AppCurrency.format(montoOriginal)} + Mora: ${AppCurrency.format(mora)})"
          : "";

      final dateInfo = CuotaDateHelper.evaluate(due);
      final int daysOver = dateInfo.daysOverdue;
      final bool isVencida = dateInfo.isPast && falta > 0.01;
      final String vencidaStatus = isVencida
          ? "- *Vencida (hace $daysOver ${daysOver == 1 ? 'día' : 'días'})*"
          : "";

      if (pagado > 0.01) {
        if (falta <= 0.01) {
          sb.writeln(
            "✅ Cuota #$numCuota: *${AppCurrency.format(monto)}*$moraDetail (${dateInfo.fullLabel}) - *Pagada*",
          );
        } else if (isVencida) {
          sb.writeln(
            "🔴 Cuota #$numCuota: *${AppCurrency.format(monto)}*$moraDetail (Abonó: ${AppCurrency.format(pagado)} • Falta: ${AppCurrency.format(falta)}) (${dateInfo.fullLabel}) $vencidaStatus",
          );
        } else {
          sb.writeln(
            "🟠 Cuota #$numCuota: *${AppCurrency.format(monto)}*$moraDetail (Abonó: ${AppCurrency.format(pagado)} • Falta: ${AppCurrency.format(falta)}) (${dateInfo.fullLabel}) - *Pago Parcial*",
          );
        }
      } else {
        if (isVencida) {
          sb.writeln(
            "🔴 Cuota #$numCuota: *${AppCurrency.format(monto)}*$moraDetail (${dateInfo.fullLabel}) $vencidaStatus",
          );
        } else if (dateInfo.isToday) {
          sb.writeln(
            "⏳ Cuota #$numCuota: *${AppCurrency.format(monto)}*$moraDetail (${dateInfo.fullLabel}) - *Vence Hoy*",
          );
        } else {
          sb.writeln(
            "⏳ Cuota #$numCuota: *${AppCurrency.format(monto)}*$moraDetail (${dateInfo.fullLabel}) - *Pendiente*",
          );
        }
      }
    }
  }
}
