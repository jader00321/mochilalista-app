part of '../whatsapp_preview_screen.dart';

mixin _WhatsAppMessageBuilderMixin on _WhatsAppPreviewScreenStateBase {
  @override
  void _regenerateMessage() {
    if (_isManualEdit || _quotation == null) return;

    final sb = StringBuffer();
    final bool isSale = _saleData != null;
    final bool isLoan =
        isSale &&
        (_saleData!['origen_venta'] == 'prestamo_personal' ||
            _saleData!['is_loan'] == true);

    final rawName = _clientNameCtrl.text.trim();
    final bool hasClient =
        rawName.isNotEmpty && !PdfGenerator.isInternalDraftCode(rawName);
    final String greeting = hasClient ? "¡Hola *$rawName*! 👋" : "¡Hola! 👋";

    sb.writeln(greeting);
    sb.writeln("");

    _appendIntroSection(sb, isSale: isSale, isLoan: isLoan);
    sb.writeln("");

    if (isLoan) {
      _appendLoanDetailSection(sb);
    } else {
      _appendItemsDetailSection(sb, isSale: isSale);
    }

    if (_config.showTotalGlobal && !isLoan) {
      _appendTotalSummarySection(sb, isSale: isSale);
    }

    if ((isLoan || isSale) && _config.showInstallmentDetails) {
      _appendInstallmentsScheduleSection(sb);
    }

    _appendDeliveryValidityPaymentBusinessClosing(
      sb,
      isSale: isSale,
      isLoan: isLoan,
    );

    _messageCtrl.text = sb.toString();
    _lastCommittedText = _messageCtrl.text;
  }

  void _appendIntroSection(
    StringBuffer sb, {
    required bool isSale,
    required bool isLoan,
  }) {
    if (_config.customIntro != null && _config.customIntro!.trim().isNotEmpty) {
      sb.writeln(_config.customIntro!.trim());
      return;
    }

    if (isLoan) {
      switch (_config.style) {
        case WhatsAppMessageStyle.commercial:
          sb.writeln(
            "Es un gusto saludarte. Te comparto el detalle formal del préstamo personal registrado:",
          );
          break;
        case WhatsAppMessageStyle.wholesale:
          sb.writeln(
            "Estimados, les compartimos el detalle formal del financiamiento/préstamo comercial registrado:",
          );
          break;
        case WhatsAppMessageStyle.school:
          sb.writeln(
            "Estimado apoderado/a, le compartimos el detalle del financiamiento registrado:",
          );
          break;
        case WhatsAppMessageStyle.compact:
          sb.writeln("Resumen de tu préstamo personal:");
          break;
        case WhatsAppMessageStyle.urgentOffer:
          sb.writeln(
            "Información y condiciones aprobadas de tu préstamo personal:",
          );
          break;
        case WhatsAppMessageStyle.accountDebt:
          sb.writeln("Recordatorio del estado actual de tu préstamo personal:");
          break;
        case WhatsAppMessageStyle.followUp:
          sb.writeln(
            "Espero que te encuentres muy bien. Te escribo para consultar si pudiste revisar los términos del préstamo personal:",
          );
          break;
        case WhatsAppMessageStyle.deliveryReady:
          sb.writeln(
            "¡Buenas noticias! La documentación y desembolso de tu préstamo están listos para firma y entrega:",
          );
          break;
      }
      return;
    }

    if (isSale) {
      final double total = (_saleData!['monto_total'] ?? 0).toDouble();
      final double paid = (_saleData!['monto_pagado'] ?? 0).toDouble();
      final double debt = total - paid;
      final bool isQuickSale = _saleData!['origen_venta'] == 'pos_rapido';

      if (debt > 0.01) {
        switch (_config.style) {
          case WhatsAppMessageStyle.commercial:
            sb.writeln(
              "Muchas gracias por tu preferencia. A continuación, te comparto el comprobante y estado de tu compra:",
            );
            break;
          case WhatsAppMessageStyle.wholesale:
            sb.writeln(
              "Estimados, muchas gracias por su compra al por mayor. A continuación, les compartimos el comprobante y saldo pendiente:",
            );
            break;
          case WhatsAppMessageStyle.school:
            sb.writeln(
              "¡Hola! Muchas gracias por tu compra de útiles escolares. Te compartimos el comprobante y saldo pendiente:",
            );
            break;
          case WhatsAppMessageStyle.compact:
            sb.writeln("Resumen de compra y saldo pendiente:");
            break;
          case WhatsAppMessageStyle.urgentOffer:
            sb.writeln(
              "¡Gracias por tu compra! Aprovechamos para recordarte el detalle de tu pedido y saldo restante:",
            );
            break;
          case WhatsAppMessageStyle.accountDebt:
            sb.writeln(
              "📌 *ESTADO DE CUENTA:* Te compartimos el balance actualizado de tu pedido y el saldo pendiente de abono:",
            );
            break;
          case WhatsAppMessageStyle.followUp:
            sb.writeln(
              "Hola, paso a consultar si tienes alguna duda sobre tu pedido o si requieres coordinar el abono del saldo pendiente:",
            );
            break;
          case WhatsAppMessageStyle.deliveryReady:
            sb.writeln(
              "📦 *¡Tu pedido está listo!* Puedes pasar a recogerlo a tienda o coordinar la entrega final del saldo restante:",
            );
            break;
        }
      } else {
        switch (_config.style) {
          case WhatsAppMessageStyle.commercial:
            sb.writeln(
              isQuickSale
                  ? "¡Muchas gracias por tu compra! Te adjunto el detalle de los productos que llevaste:"
                  : "¡Gracias por confirmar tu pedido! Aquí tienes el comprobante detallado de tu compra cancelada:",
            );
            break;
          case WhatsAppMessageStyle.wholesale:
            sb.writeln(
              "¡Muchas gracias por su preferencia comercial! Adjuntamos el comprobante de su compra mayorista 100% CANCELADA:",
            );
            break;
          case WhatsAppMessageStyle.school:
            sb.writeln(
              "¡Muchas gracias por tu compra de útiles escolares! Tu pedido se encuentra 100% CANCELADO:",
            );
            break;
          case WhatsAppMessageStyle.compact:
            sb.writeln("Comprobante de compra cancelada:");
            break;
          case WhatsAppMessageStyle.urgentOffer:
            sb.writeln(
              "¡Felicidades por tu compra! Comprobante de los productos adquiridos con descuento:",
            );
            break;
          case WhatsAppMessageStyle.accountDebt:
            sb.writeln(
              "Comprobante de operación: ¡Tu compra se encuentra 100% CANCELADA! ✅",
            );
            break;
          case WhatsAppMessageStyle.followUp:
            sb.writeln(
              "¡Hola! Esperamos que estés disfrutando tu compra. Quedamos a tu entera disposición si necesitas algo más:",
            );
            break;
          case WhatsAppMessageStyle.deliveryReady:
            sb.writeln(
              "📦 *¡Tu pedido está listo y 100% cancelado!* Ya puedes recogerlo o te lo enviamos según lo acordado:",
            );
            break;
        }
      }
      return;
    }

    switch (_config.style) {
      case WhatsAppMessageStyle.commercial:
        sb.writeln(
          "Es un gusto saludarte. Aquí te envío la cotización detallada de los productos solicitados:",
        );
        break;
      case WhatsAppMessageStyle.wholesale:
        sb.writeln(
          "Estimados, les compartimos la proforma comercial por volumen solicitada para su negocio:",
        );
        break;
      case WhatsAppMessageStyle.school:
        sb.writeln(
          "¡Hola! Aquí te comparto la cotización detallada de la lista de útiles escolares solicitada:",
        );
        break;
      case WhatsAppMessageStyle.compact:
        sb.writeln("Resumen directo de tu cotización solicitada:");
        break;
      case WhatsAppMessageStyle.urgentOffer:
        sb.writeln(
          "🔥 ¡Aprovecha nuestros precios especiales! Aquí tienes tu cotización con descuentos exclusivos:",
        );
        break;
      case WhatsAppMessageStyle.accountDebt:
        sb.writeln(
          "Te enviamos el presupuesto detallado para tu revisión y confirmación:",
        );
        break;
      case WhatsAppMessageStyle.followUp:
        sb.writeln(
          "🤝 *Seguimiento de Cotización:* Quería consultar si tuviste oportunidad de revisar la propuesta o si deseas ajustar algún ítem:",
        );
        break;
      case WhatsAppMessageStyle.deliveryReady:
        sb.writeln(
          "📦 *Productos listos para despacho:* Contamos con stock inmediato para preparar tu pedido en cuanto nos des tu visto bueno:",
        );
        break;
    }
  }

  void _appendItemsDetailSection(StringBuffer sb, {required bool isSale}) {
    if (_config.showClientData) {
      final String? inst = _quotation?.institutionName;
      final String student = _clientNameCtrl.text.trim();
      final String? grade = _quotation?.gradeLevel;
      if (_config.style == WhatsAppMessageStyle.wholesale) {
        if (inst != null && inst.isNotEmpty) {
          sb.writeln("🏢 *Negocio / RUC:* $inst");
        }
        if (student.isNotEmpty && !PdfGenerator.isInternalDraftCode(student)) {
          sb.writeln("👤 *Contacto:* $student");
        }
        if ((inst != null && inst.isNotEmpty) ||
            (student.isNotEmpty &&
                !PdfGenerator.isInternalDraftCode(student))) {
          sb.writeln("");
        }
      } else if (_config.style == WhatsAppMessageStyle.school) {
        if (inst != null && inst.isNotEmpty) sb.writeln("🏫 *Colegio:* $inst");
        if (student.isNotEmpty && !PdfGenerator.isInternalDraftCode(student)) {
          sb.writeln("👦 *Alumno:* $student");
        }
        if (grade != null && grade.isNotEmpty) sb.writeln("📚 *Grado:* $grade");
        if ((inst != null && inst.isNotEmpty) ||
            (student.isNotEmpty &&
                !PdfGenerator.isInternalDraftCode(student))) {
          sb.writeln("");
        }
      } else if (student.isNotEmpty &&
          !PdfGenerator.isInternalDraftCode(student)) {
        sb.writeln("👤 *Cliente:* $student");
        sb.writeln("");
      }
    }

    final String sectionTitle;
    if (isSale) {
      sectionTitle = "🛍️ *DETALLE DE TU COMPRA*";
    } else {
      switch (_config.style) {
        case WhatsAppMessageStyle.wholesale:
          sectionTitle = "📦 *DETALLE DE PEDIDO AL POR MAYOR*";
          break;
        case WhatsAppMessageStyle.school:
          sectionTitle = "🎓 *LISTA DE ÚTILES ESCOLARES*";
          break;
        case WhatsAppMessageStyle.compact:
          sectionTitle = "⚡ *RESUMEN DE PRODUCTOS*";
          break;
        default:
          sectionTitle = "🛍️ *DETALLE DE PRODUCTOS*";
          break;
      }
    }
    sb.writeln(sectionTitle);

    for (var item in _quotation!.items) {
      final lineTotal = item.quantity * item.unitPriceApplied;
      final hasDiscount =
          (item.originalUnitPrice - item.unitPriceApplied) > 0.01;

      final String name = (item.bundleId != null)
          ? (item.productName ?? 'Paquete')
          : (_config.showBrandPackage
                ? item.displayNameClean
                : (item.productName ?? item.displayNameClean));

      final String unitPriceSuffix = _config.showUnitPrices
          ? " — ${AppCurrency.format(item.unitPriceApplied)} c/u"
          : "";

      if (_config.style == WhatsAppMessageStyle.compact) {
        String line = "▪ ${item.quantity}x $name";
        if (_config.showSubtotals) {
          line += " -> *${AppCurrency.format(lineTotal)}*";
        }
        sb.writeln(line);
      } else {
        String line = "▪ ${item.quantity}x $name$unitPriceSuffix";
        if (_config.showSubtotals) {
          line += " -> *${AppCurrency.format(lineTotal)}*";
        }
        if (item.bundleId != null &&
            item.specificName != null &&
            item.specificName!.isNotEmpty &&
            item.specificName != "Paquete") {
          line += "\n   _${item.specificName}_";
        }
        if (_config.showSavingsSection &&
            _config.showDiscountDetail &&
            hasDiscount) {
          final savings = item.originalUnitPrice - item.unitPriceApplied;
          line += "\n   └ _Ahorras: ${AppCurrency.format(savings)} c/u_";
        }
        sb.writeln(line);
      }
    }
    sb.writeln("");
  }
}
