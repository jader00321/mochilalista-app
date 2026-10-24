import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/core/database/local_db.dart';

import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/whatsapp_config_model.dart';
import 'package:app_movil/features/smart_quotation/models/pdf_config_model.dart';
import 'package:app_movil/features/smart_quotation/services/pdf_preferences_service.dart';
import 'package:app_movil/features/smart_quotation/services/whatsapp_preferences_service.dart';
import 'package:app_movil/features/smart_quotation/utils/pdf_generator.dart';

import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/client_search_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_client_section.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_config_section.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_business_section.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_message_editor.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_final_preview_modal.dart';

class WhatsAppPreviewScreen extends StatefulWidget {
  final int? quotationId;
  final int? saleId;

  const WhatsAppPreviewScreen({super.key, this.quotationId, this.saleId});

  @override
  State<WhatsAppPreviewScreen> createState() => _WhatsAppPreviewScreenState();
}

class _WhatsAppPreviewScreenState extends State<WhatsAppPreviewScreen> {
  bool _isLoading = true;
  bool _isManualEdit = false;
  bool _isGpsLoading = false;

  late WhatsAppConfig _config;
  SmartQuotationModel? _quotation;
  Map<String, dynamic>? _saleData;

  ClientModel? _originalClient;
  ClientModel? _selectedClient;
  bool _isUsingSelectedClient = false;

  // ↶ Pila de Historial Undo / Redo Blindada
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  bool _isApplyingUndoRedo = false;
  Timer? _typingDebounceTimer;

  final _clientNameCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _bizAddressCtrl = TextEditingController();
  final _bizRucCtrl = TextEditingController();
  final _bizPhoneCtrl = TextEditingController();
  final _bizPaymentCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  double? _bizLat;
  double? _bizLng;

  String get _currentContextKey {
    if (_saleData != null) {
      final bool isLoan = _saleData!['origen_venta'] == 'prestamo_personal' || _saleData!['is_loan'] == true;
      return isLoan ? 'loan' : 'sale';
    }
    return 'quote';
  }

  @override
  void initState() {
    super.initState();
    _config = WhatsAppConfig();
    _loadData();
  }

  @override
  void dispose() {
    _typingDebounceTimer?.cancel();
    _clientNameCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _bizAddressCtrl.dispose();
    _bizRucCtrl.dispose();
    _bizPhoneCtrl.dispose();
    _bizPaymentCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _onMessageEdited(String newText) {
    if (!_isManualEdit) {
      setState(() => _isManualEdit = true);
    }
    if (_isApplyingUndoRedo) return;
    _typingDebounceTimer?.cancel();
    _typingDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      _recordUndoSnapshot(newText);
    });
  }

  void _recordUndoSnapshot([String? specificText]) {
    if (_isApplyingUndoRedo) return;
    final current = specificText ?? _messageCtrl.text;
    if (_undoStack.isEmpty || _undoStack.last != current) {
      _undoStack.add(current);
      if (_undoStack.length > 50) _undoStack.removeAt(0);
      _redoStack.clear();
      if (mounted) setState(() {});
    }
  }

  void _handleUndo() {
    if (_undoStack.isEmpty) return;
    HapticFeedback.selectionClick();
    _isApplyingUndoRedo = true;
    final currentText = _messageCtrl.text;
    _redoStack.add(currentText);
    final previousText = _undoStack.removeLast();
    _messageCtrl.text = previousText;
    _messageCtrl.selection = TextSelection.collapsed(offset: previousText.length);
    _isManualEdit = true;
    setState(() {});
    _isApplyingUndoRedo = false;
  }

  void _handleRedo() {
    if (_redoStack.isEmpty) return;
    HapticFeedback.selectionClick();
    _isApplyingUndoRedo = true;
    final currentText = _messageCtrl.text;
    _undoStack.add(currentText);
    final nextText = _redoStack.removeLast();
    _messageCtrl.text = nextText;
    _messageCtrl.selection = TextSelection.collapsed(offset: nextText.length);
    _isManualEdit = true;
    setState(() {});
    _isApplyingUndoRedo = false;
  }

  Future<void> _loadData() async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final clientService = ClientService();

    try {
      if (widget.saleId != null) {
        final saleProv = Provider.of<SaleProvider>(context, listen: false);
        _saleData = await saleProv.getSaleDetailSilently(widget.saleId!);
        if (_saleData != null && _saleData!['cotizacion'] != null) {
          _quotation = SmartQuotationModel.fromJson(_saleData!['cotizacion']);
        }
      } else if (widget.quotationId != null) {
        final qProv = Provider.of<SmartQuotationProvider>(context, listen: false);
        _quotation = await qProv.getQuotationById(widget.quotationId!);
      }

      if (_quotation != null) {
        final rawClientName = _saleData?['cliente_nombre'] ?? _quotation!.clientName;
        _clientNameCtrl.text = PdfGenerator.cleanClientDisplayName(rawClientName);

        final int? targetClientId = _saleData?['cliente_id'] ?? _quotation!.clientId;
        if (targetClientId != null) {
          final clientData = await clientService.getClientById(targetClientId);
          if (clientData != null) {
            _originalClient = clientData;
            _clientNameCtrl.text = PdfGenerator.cleanClientDisplayName(clientData.fullName);
            _clientPhoneCtrl.text = clientData.phone;
          }
        } else if (_saleData?['cliente_telefono'] != null) {
          _clientPhoneCtrl.text = _saleData!['cliente_telefono'];
        }

        final biz = authProv.currentBusiness;
        if (biz != null) {
          _bizAddressCtrl.text = biz.address ?? "";
          _bizRucCtrl.text = biz.ruc ?? "";
          _bizPhoneCtrl.text = authProv.user?.phone ?? "";
          _bizPaymentCtrl.text = biz.paymentInfo ?? "BCP: 000-000...\nYape: 999...";
          _bizLat = biz.latitud;
          _bizLng = biz.longitud;
        }

        // Aplicamos preferencias guardadas del usuario de WhatsApp indexadas por contexto
        _config = await WhatsAppPreferencesService.applySavedPreferences(
          _config,
          contextKey: _currentContextKey,
        );
      }

      _regenerateMessage();
    } catch (e) {
      debugPrint("Error loading WA data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Hidrata las rutas locales de fotos de productos desde SQLite para ítems sin imagen
  Future<void> _hydrateProductImages() async {
    if (_quotation == null || _quotation!.items.isEmpty) return;
    try {
      final db = await LocalDatabase.instance.database;
      final List<QuotationItem> updatedItems = [];

      for (final item in _quotation!.items) {
        if ((item.imageUrl == null || item.imageUrl!.trim().isEmpty) && item.productId != null) {
          final res = await db.query(
            'productos',
            columns: ['imagen_url'],
            where: 'id = ?',
            whereArgs: [item.productId],
            limit: 1,
          );
          if (res.isNotEmpty && res.first['imagen_url'] != null) {
            final String? dbImg = res.first['imagen_url'] as String?;
            if (dbImg != null && dbImg.isNotEmpty) {
              updatedItems.add(QuotationItem(
                id: item.id,
                productId: item.productId,
                presentationId: item.presentationId,
                bundleId: item.bundleId,
                productName: item.productName,
                brandName: item.brandName,
                specificName: item.specificName,
                salesUnit: item.salesUnit,
                quantity: item.quantity,
                unitPriceApplied: item.unitPriceApplied,
                originalUnitPrice: item.originalUnitPrice,
                isAvailable: item.isAvailable,
                isManualPrice: item.isManualPrice,
                originalText: item.originalText,
                imageUrl: dbImg,
              ));
              continue;
            }
          }
        }
        updatedItems.add(item);
      }
      _quotation = _quotation!.copyWith(items: updatedItems);
    } catch (e) {
      debugPrint("⚠️ Error hidratando fotos de productos desde SQLite en WhatsAppPreviewScreen: $e");
    }
  }

  /// Actualización reactiva a 0ms cuando cambia el texto del nombre del cliente
  void _onClientDataChanged() {
    final cleanName = _clientNameCtrl.text.trim();
    if (_isManualEdit) {
      final currentText = _messageCtrl.text;
      final greetingRegex = RegExp(r'^¡Hola(?:\s+\*[^*]+\*)?!\s*👋', multiLine: true);
      final String newGreeting = cleanName.isEmpty || PdfGenerator.isInternalDraftCode(cleanName)
          ? '¡Hola! 👋'
          : '¡Hola *$cleanName*! 👋';
      if (greetingRegex.hasMatch(currentText)) {
        _messageCtrl.text = currentText.replaceFirst(greetingRegex, newGreeting);
      }
    } else {
      _regenerateMessage();
    }
  }

  void _regenerateMessage() {
    if (_isManualEdit || _quotation == null) return;

    final sb = StringBuffer();
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final bool isSale = _saleData != null;
    final bool isLoan = isSale && (_saleData!['origen_venta'] == 'prestamo_personal' || _saleData!['is_loan'] == true);

    final rawName = _clientNameCtrl.text.trim();
    final bool hasClient = rawName.isNotEmpty && !PdfGenerator.isInternalDraftCode(rawName);
    final String greeting = hasClient ? "¡Hola *$rawName*! 👋" : "¡Hola! 👋";

    sb.writeln(greeting);
    sb.writeln("");

    // 1. INTRODUCCIÓN SEGÚN ESTILO Y CONTEXTO
    if (_config.customIntro != null && _config.customIntro!.trim().isNotEmpty) {
      sb.writeln(_config.customIntro!.trim());
    } else {
      if (isLoan) {
        switch (_config.style) {
          case WhatsAppMessageStyle.commercial:
            sb.writeln("Es un gusto saludarte. Te comparto el detalle formal del préstamo personal registrado:");
            break;
          case WhatsAppMessageStyle.compact:
            sb.writeln("Resumen de tu préstamo personal:");
            break;
          case WhatsAppMessageStyle.urgentOffer:
            sb.writeln("Información y condiciones aprobadas de tu préstamo personal:");
            break;
          case WhatsAppMessageStyle.accountDebt:
            sb.writeln("Recordatorio del estado actual de tu préstamo personal:");
            break;
          case WhatsAppMessageStyle.followUp:
            sb.writeln("Espero que te encuentres muy bien. Te escribo para consultar si pudiste revisar los términos del préstamo personal:");
            break;
          case WhatsAppMessageStyle.deliveryReady:
            sb.writeln("¡Buenas noticias! La documentación y desembolso de tu préstamo están listos para firma y entrega:");
            break;
        }
      } else if (isSale) {
        final double total = (_saleData!['monto_total'] ?? 0).toDouble();
        final double paid = (_saleData!['monto_pagado'] ?? 0).toDouble();
        final double debt = total - paid;
        final bool isQuickSale = _saleData!['origen_venta'] == 'pos_rapido';

        if (debt > 0.01) {
          switch (_config.style) {
            case WhatsAppMessageStyle.commercial:
              sb.writeln("Muchas gracias por tu preferencia. A continuación, te comparto el comprobante y estado de tu compra:");
              break;
            case WhatsAppMessageStyle.compact:
              sb.writeln("Resumen de compra y saldo pendiente:");
              break;
            case WhatsAppMessageStyle.urgentOffer:
              sb.writeln("¡Gracias por tu compra! Aprovechamos para recordarte el detalle de tu pedido y saldo restante:");
              break;
            case WhatsAppMessageStyle.accountDebt:
              sb.writeln("📌 *ESTADO DE CUENTA:* Te compartimos el balance actualizado de tu pedido y el saldo pendiente de abono:");
              break;
            case WhatsAppMessageStyle.followUp:
              sb.writeln("Hola, paso a consultar si tienes alguna duda sobre tu pedido o si requieres coordinar el abono del saldo pendiente:");
              break;
            case WhatsAppMessageStyle.deliveryReady:
              sb.writeln("📦 *¡Tu pedido está listo!* Puedes pasar a recogerlo a tienda o coordinar la entrega final del saldo restante:");
              break;
          }
        } else {
          switch (_config.style) {
            case WhatsAppMessageStyle.commercial:
              sb.writeln(isQuickSale
                  ? "¡Muchas gracias por tu compra! Te adjunto el detalle de los productos que llevaste:"
                  : "¡Gracias por confirmar tu pedido! Aquí tienes el comprobante detallado de tu compra cancelada:");
              break;
            case WhatsAppMessageStyle.compact:
              sb.writeln("Comprobante de compra cancelada:");
              break;
            case WhatsAppMessageStyle.urgentOffer:
              sb.writeln("¡Felicidades por tu compra! Comprobante de los productos adquiridos con descuento:");
              break;
            case WhatsAppMessageStyle.accountDebt:
              sb.writeln("Comprobante de operación: ¡Tu compra se encuentra 100% CANCELADA! ✅");
              break;
            case WhatsAppMessageStyle.followUp:
              sb.writeln("¡Hola! Esperamos que estés disfrutando tu compra. Quedamos a tu entera disposición si necesitas algo más:");
              break;
            case WhatsAppMessageStyle.deliveryReady:
              sb.writeln("📦 *¡Tu pedido está listo y 100% cancelado!* Ya puedes recogerlo o te lo enviamos según lo acordado:");
              break;
          }
        }
      } else {
        // Cotización
        switch (_config.style) {
          case WhatsAppMessageStyle.commercial:
            sb.writeln("Es un gusto saludarte. Aquí te envío la cotización detallada de los productos solicitados:");
            break;
          case WhatsAppMessageStyle.compact:
            sb.writeln("Resumen directo de tu cotización solicitada:");
            break;
          case WhatsAppMessageStyle.urgentOffer:
            sb.writeln("🔥 ¡Aprovecha nuestros precios especiales! Aquí tienes tu cotización con descuentos exclusivos:");
            break;
          case WhatsAppMessageStyle.accountDebt:
            sb.writeln("Te enviamos el presupuesto detallado para tu revisión y confirmación:");
            break;
          case WhatsAppMessageStyle.followUp:
            sb.writeln("🤝 *Seguimiento de Cotización:* Quería consultar si tuviste oportunidad de revisar la propuesta o si deseas ajustar algún ítem:");
            break;
          case WhatsAppMessageStyle.deliveryReady:
            sb.writeln("📦 *Productos listos para despacho:* Contamos con stock inmediato para preparar tu pedido en cuanto nos des tu visto bueno:");
            break;
        }
      }
    }
    sb.writeln("");

    // 2. SECCIÓN PRINCIPAL: ITEMS (O DETALLE DEL PRÉSTAMO CON PARIDAD CONTABLE)
    if (isLoan) {
      final double totalDebt = (_saleData!['monto_total'] ?? _quotation!.totalAmount).toDouble();
      final double paid = (_saleData!['monto_pagado'] ?? 0.0).toDouble();
      final double debt = totalDebt - paid > 0 ? totalDebt - paid : 0.0;
      final double interestRate = (_saleData!['porcentaje_interes'] ?? 0.0).toDouble();

      double capital = totalDebt;
      double interestAmount = 0.0;
      if (interestRate > 0) {
        capital = totalDebt / (1 + (interestRate / 100));
        interestAmount = totalDebt - capital;
      }

      sb.writeln("🏦 *DETALLE DEL PRÉSTAMO*");
      if (interestRate > 0) {
        sb.writeln("▪ Capital Prestado: *${currency.format(capital).trim()}*");
        sb.writeln("▪ Interés Acordado: *${interestRate.toStringAsFixed(1)}% (${currency.format(interestAmount).trim()})*");
        sb.writeln("▪ Total a Devolver: *${currency.format(totalDebt).trim()}*");
      } else {
        sb.writeln("▪ Capital Registrado: *${currency.format(totalDebt).trim()}*");
      }

      if (paid > 0.01) {
        sb.writeln("▪ Monto Abonado: *${currency.format(paid).trim()}* ✅");
      }
      if (debt > 0.01 && _config.showDebtInfo) {
        sb.writeln("▪ *Saldo Pendiente por Pagar: ${currency.format(debt).trim()}* ⚠️");
      } else if (debt <= 0.01) {
        sb.writeln("▪ Estado del Préstamo: *TOTALMENTE CANCELADO* ✅");
      }
      sb.writeln("");
    } else {
      final String sectionTitle = isSale ? "🛍️ *DETALLE DE TU COMPRA*" : "🛍️ *DETALLE DE PRODUCTOS*";
      sb.writeln(sectionTitle);

      for (var item in _quotation!.items) {
        final lineTotal = item.quantity * item.unitPriceApplied;
        final hasDiscount = (item.originalUnitPrice - item.unitPriceApplied) > 0.01;

        String name = (item.bundleId != null)
            ? (item.productName ?? 'Paquete')
            : item.displayName;

        if (_config.style == WhatsAppMessageStyle.compact) {
          String line = "▪ ${item.quantity}x $name";
          if (_config.showSubtotals) {
            line += " -> *${currency.format(lineTotal).trim()}*";
          }
          sb.writeln(line);
        } else {
          String line = "▪ ${item.quantity}x $name";
          if (_config.showSubtotals) {
            line += " -> *${currency.format(lineTotal).trim()}*";
          }
          if (item.bundleId != null && item.specificName != null && item.specificName!.isNotEmpty && item.specificName != "Paquete") {
            line += "\n   _${item.specificName}_";
          }
          if (_config.showSavingsSection && _config.showDiscountDetail && hasDiscount) {
            final savings = item.originalUnitPrice - item.unitPriceApplied;
            line += "\n   └ _Ahorras: ${currency.format(savings).trim()} c/u_";
          }
          sb.writeln(line);
        }
      }
      sb.writeln("");
    }

    // 3. RESUMEN TOTAL / AHORRO / SALDO
    if (_config.showTotalGlobal && !isLoan) {
      double finalTotal = isSale ? (_saleData!['monto_total'] ?? 0).toDouble() : _quotation!.totalAmount;
      final double finalSavings = isSale ? (_saleData!['descuento_aplicado'] ?? 0).toDouble() : _quotation!.totalSavings;

      sb.writeln("📊 *RESUMEN TOTAL*");
      sb.writeln("▪ Importe Total: *${currency.format(finalTotal).trim()}*");

      if (_config.showSavingsSection && finalSavings > 0.01) {
        if (_config.style == WhatsAppMessageStyle.urgentOffer) {
          sb.writeln("▪ 🎉 *¡AHORRO ESPECIAL: ${currency.format(finalSavings).trim()}!*");
        } else {
          sb.writeln("▪ Ahorro Total: *${currency.format(finalSavings).trim()}* 🎉");
        }
      }

      if (isSale) {
        double paid = (_saleData!['monto_pagado'] ?? 0.0).toDouble();
        double debt = finalTotal - paid;
        if (debt < 0) debt = 0;

        if (paid > 0.01) {
          sb.writeln("▪ Abonado: *${currency.format(paid).trim()}* ✅");
        }
        if (debt > 0.01 && _config.showDebtInfo) {
          sb.writeln("▪ *Saldo Pendiente por Pagar: ${currency.format(debt).trim()}* ⚠️");
        }
      }
      sb.writeln("");
    }

    // 4. CRONOGRAMA DE CUOTAS (PARA PRÉSTAMOS O VENTAS CON CRÉDITO)
    if ((isLoan || isSale) && _config.showInstallmentDetails) {
      final List<dynamic>? cuotasRaw = _saleData?['cuotas'];
      if (cuotasRaw != null && cuotasRaw.isNotEmpty) {
        sb.writeln("📅 *CRONOGRAMA DE PAGOS* (${cuotasRaw.length} Cuotas)");
        for (var c in cuotasRaw) {
          final bool pagado = c['estado'] == 'pagado';
          final String icon = pagado ? "✅ Pagado" : "⏳ Pendiente";
          final String date = DateFormat('dd/MM/yyyy').format(DateTime.parse(c['fecha_vencimiento']));
          sb.writeln("▪ Cuota ${c['numero_cuota']}: *${currency.format(c['monto']).trim()}* (Vence: $date) - $icon");
        }
        sb.writeln("");
      }
    }

    // 5. ESTADO DE ENTREGA
    if (isSale && !isLoan && _config.showDeliveryInfo) {
      final String deliveryStatus = _saleData!['estado_entrega'] ?? 'entregado';
      if (deliveryStatus != 'entregado') {
        sb.writeln("📦 *ESTADO DEL PEDIDO*");
        sb.writeln("▪ Estado: *${deliveryStatus.toUpperCase().replaceAll('_', ' ')}*");
        if (_saleData!['fecha_entrega'] != null) {
          final dateFormatted = DateFormat('dd/MM/yyyy').format(DateTime.parse(_saleData!['fecha_entrega']));
          sb.writeln("▪ Entrega programada: $dateFormatted");
        }
        sb.writeln("");
      }
    }

    // 6. VALIDEZ DE OFERTA EN COTIZACIÓN
    if (!isSale && _config.includeValidity) {
      if (_config.style == WhatsAppMessageStyle.urgentOffer) {
        sb.writeln("⏳ *Promoción por tiempo limitado:* Precios válidos por 7 días calendario.");
        sb.writeln("");
      } else if (_config.style == WhatsAppMessageStyle.commercial) {
        sb.writeln("⏳ *Validez:* Precios válidos por 7 días calendario.");
        sb.writeln("");
      }
    }

    // 7. MEDIOS DE PAGO
    if (_config.showPaymentInfo && _bizPaymentCtrl.text.isNotEmpty) {
      if (isLoan) {
        final double totalDebt = (_saleData!['monto_total'] ?? 0).toDouble();
        final double paid = (_saleData!['monto_pagado'] ?? 0).toDouble();
        if ((totalDebt - paid) > 0.01) {
          sb.writeln("💳 *CUENTAS DE ABONO* (Para amortizar o cancelar cuotas)");
          sb.writeln(_bizPaymentCtrl.text.trim());
          sb.writeln("");
        }
      } else if (isSale) {
        final double total = (_saleData!['monto_total'] ?? 0).toDouble();
        final double paid = (_saleData!['monto_pagado'] ?? 0).toDouble();

        if ((total - paid) > 0.01) {
          sb.writeln("💳 *MEDIOS DE PAGO* (Para cancelar saldo)");
          sb.writeln(_bizPaymentCtrl.text.trim());
          sb.writeln("");
        } else if ((total - paid) <= 0.01) {
          sb.writeln("💳 *PAGADO MEDIANTE:* ${_saleData!['metodo_pago'].toString().toUpperCase()}");
          sb.writeln("");
        }
      } else {
        sb.writeln("💳 *MEDIOS DE PAGO*");
        sb.writeln(_bizPaymentCtrl.text.trim());
        sb.writeln("");
      }
    }

    // 8. INFORMACIÓN DEL NEGOCIO
    if (_config.showBusinessInfo && _config.style != WhatsAppMessageStyle.compact) {
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      final bizName = authProv.businessName;

      sb.writeln("🏢 *Visítanos en $bizName*");

      if (_config.includeShopAddress && _bizAddressCtrl.text.isNotEmpty) {
        sb.writeln("📍 Dirección: ${_bizAddressCtrl.text}");
      }

      if (_config.includeShopAddress && _bizLat != null && _bizLng != null) {
        final String mapLink = "https://www.google.com/maps/search/?api=1&query=$_bizLat,$_bizLng";
        sb.writeln("🗺️ Ver en Mapa: $mapLink");
      }

      if (_config.includeShopRuc && _bizRucCtrl.text.isNotEmpty) {
        sb.writeln("📄 RUC: ${_bizRucCtrl.text}");
      }
      if (_config.includeOwnerPhone && _bizPhoneCtrl.text.isNotEmpty) {
        sb.writeln("📞 Contacto: ${_bizPhoneCtrl.text}");
      }
      sb.writeln("");
    }

    // 9. DESPEDIDA / CIERRE
    if (_config.customClosing != null && _config.customClosing!.trim().isNotEmpty) {
      sb.writeln(_config.customClosing!.trim());
    } else {
      if (!isSale) {
        if (_config.style == WhatsAppMessageStyle.urgentOffer) {
          sb.writeln("¡No dejes pasar esta oportunidad! Confírmanos tu pedido para reservarte el stock.");
        } else {
          sb.writeln("¡Quedamos atentos a tu confirmación!");
        }
      } else if (isLoan) {
        sb.writeln("Cualquier duda o consulta sobre tu estado de pagos, contáctanos.");
      }
    }

    _messageCtrl.text = sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final bool isSale = _saleData != null;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Editor WhatsApp",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: isDark ? const Color(0xFF142C23) : const Color(0xFF00A884),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          const InfoTooltipButton(
            title: "Guía del Editor WhatsApp",
            description: "Personaliza tu mensaje con 6 estilos comerciales, formato rápido, "
                "deshacer/rehacer ilimitado y vista previa en burbuja realista de WhatsApp.",
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt, size: 26),
            tooltip: "Restaurar Mensaje Original",
            onPressed: () {
              _recordUndoSnapshot();
              setState(() => _isManualEdit = false);
              _regenerateMessage();
              CustomSnackBar.show(context, message: "Mensaje restaurado a su plantilla original", isError: false);
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WaClientSection(
                    nameCtrl: _clientNameCtrl,
                    phoneCtrl: _clientPhoneCtrl,
                    isUsingSelectedClient: _isUsingSelectedClient,
                    originalClient: _originalClient,
                    updateClientData: _config.updateClientData,
                    onSearchTap: () => _showClientSelectorModal(isDark),
                    onRevertTap: () {
                      setState(() {
                        _isUsingSelectedClient = false;
                        _selectedClient = null;
                        if (_originalClient != null) {
                          _clientNameCtrl.text = PdfGenerator.cleanClientDisplayName(_originalClient!.fullName);
                          _clientPhoneCtrl.text = _originalClient!.phone;
                        } else {
                          final raw = _saleData?['cliente_nombre'] ?? _quotation?.clientName ?? "";
                          _clientNameCtrl.text = PdfGenerator.cleanClientDisplayName(raw);
                          _clientPhoneCtrl.clear();
                        }
                        _onClientDataChanged();
                      });
                    },
                    onUpdateDataChanged: (v) => setState(() => _config.updateClientData = v),
                    onDataChanged: _onClientDataChanged,
                  ),
                  const SizedBox(height: 16),

                  WaConfigSection(
                    config: _config,
                    isSale: isSale,
                    contextKey: _currentContextKey,
                    onChanged: () => setState(() => _regenerateMessage()),
                  ),
                  const SizedBox(height: 16),

                  WaBusinessSection(
                    phoneCtrl: _bizPhoneCtrl,
                    rucCtrl: _bizRucCtrl,
                    addressCtrl: _bizAddressCtrl,
                    paymentCtrl: _bizPaymentCtrl,
                    isGpsLoading: _isGpsLoading,
                    updateBusinessData: _config.updateBusinessData,
                    onGpsTap: _fillCurrentLocation,
                    onUpdateDataChanged: (v) => setState(() => _config.updateBusinessData = v),
                    onDataChanged: () => setState(() => _regenerateMessage()),
                  ),
                  const SizedBox(height: 20),

                  WaMessageEditor(
                    isDark: isDark,
                    isManualEdit: _isManualEdit,
                    messageCtrl: _messageCtrl,
                    config: _config,
                    paymentAccountsText: _bizPaymentCtrl.text,
                    canUndo: _undoStack.isNotEmpty,
                    canRedo: _redoStack.isNotEmpty,
                    onUndo: _undoStack.isNotEmpty ? _handleUndo : null,
                    onRedo: _redoStack.isNotEmpty ? _handleRedo : null,
                    onBeforeChange: () => _recordUndoSnapshot(),
                    onStyleChanged: (newStyle) {
                      _recordUndoSnapshot();
                      setState(() {
                        _config.style = newStyle;
                        _isManualEdit = false;
                        _regenerateMessage();
                      });
                    },
                    onRegenerateAuto: () {
                      _recordUndoSnapshot();
                      setState(() {
                        _isManualEdit = false;
                        _regenerateMessage();
                      });
                      CustomSnackBar.show(context, message: "Plantilla regenerada automáticamente", isError: false);
                    },
                    onChanged: _onMessageEdited,
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, -10),
                  )
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => _showFinalPreviewModal(isDark),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A884),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: isDark ? 0 : 4,
                  ),
                  icon: const Icon(Icons.remove_red_eye, size: 22),
                  label: const Text(
                    "VISUALIZAR MENSAJE FINAL",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClientSelectorModal(bool isDark) {
    ClientSearchModal.show(
      context,
      onClientSelected: (client) {
        setState(() {
          _selectedClient = client;
          _isUsingSelectedClient = true;
          _clientNameCtrl.text = PdfGenerator.cleanClientDisplayName(client.fullName);
          _clientPhoneCtrl.text = client.phone;
          _onClientDataChanged();
        });
      },
    );
  }

  Future<void> _fillCurrentLocation() async {
    setState(() => _isGpsLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception("El GPS está desactivado. Actívalo e intenta de nuevo.");

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception("Permiso de ubicación denegado.");
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception("Permiso denegado permanentemente. Habilítalo en configuración.");
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (mounted) {
        setState(() {
          _bizLat = position.latitude;
          _bizLng = position.longitude;
          _regenerateMessage();
        });
        CustomSnackBar.show(context, message: "Ubicación agregada con éxito", isError: false);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: e.toString().replaceAll("Exception:", "").trim(),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isGpsLoading = false);
    }
  }

  void _showFinalPreviewModal(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false, // 🛡️ Blindaje total contra intercepción de gestos verticales del scroll
      backgroundColor: Colors.transparent,
      builder: (ctx) => WaFinalPreviewModal(
        isDark: isDark,
        phone: _clientPhoneCtrl.text,
        messageCtrl: _messageCtrl,
        onMessageChanged: (text) {
          _onMessageEdited(text);
        },
        onSend: () {
          Navigator.pop(ctx);
          _executeSendProcess();
        },
        onSharePdfAndMessage: _quotation != null ? () {
          Navigator.pop(ctx);
          _sharePdfAndMessage();
        } : null,
      ),
    );
  }

  /// Ejecuta la persistencia de datos del negocio y cliente si el usuario marcó las casillas correspondientes
  Future<void> _persistPendingDataIfRequested() async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final clientService = ClientService();
    bool savingError = false;

    if (authProv.activeBusinessId == null || authProv.activeUserId == null) {
      return;
    }

    if (_config.updateBusinessData) {
      try {
        bool showAddress = true;
        bool showRuc = true;

        final biz = authProv.currentBusiness;
        if (biz != null && biz.printerConfig != null && biz.printerConfig!.isNotEmpty) {
          try {
            final Map<String, dynamic> prefs = json.decode(biz.printerConfig!);
            showAddress = prefs['show_address'] ?? true;
            showRuc = prefs['show_ruc'] ?? true;
          } catch (_) {}
        }

        await authProv.updateBusinessProfile(
          authProv.businessName,
          _bizRucCtrl.text,
          _bizAddressCtrl.text,
          _bizPaymentCtrl.text,
          _bizLat,
          _bizLng,
          showAddress,
          showRuc,
        );
      } catch (e) {
        savingError = true;
      }
    }

    final cleanPhone = _clientPhoneCtrl.text.replaceAll(RegExp(r'\D'), '');

    if (_config.updateClientData && _clientNameCtrl.text.trim().isNotEmpty) {
      try {
        final clientData = {
          'nombre_completo': _clientNameCtrl.text.trim(),
          'telefono': cleanPhone,
        };
        if (_isUsingSelectedClient && _selectedClient != null) {
          await clientService.updateClient(_selectedClient!.id, clientData);
        } else if (_originalClient != null && !_isUsingSelectedClient) {
          await clientService.updateClient(_originalClient!.id, clientData);
        } else {
          await clientService.createClient(
            clientData,
            authProv.activeBusinessId!,
            authProv.activeUserId!,
          );
        }
      } catch (e) {
        savingError = true;
      }
    }

    if (savingError) {
      if (mounted) CustomSnackBar.show(context, message: "Datos guardados con advertencias", isError: true);
    } else if ((_config.updateBusinessData || _config.updateClientData) && mounted) {
      CustomSnackBar.show(context, message: "Datos actualizados correctamente", isError: false);
    }
  }

  /// Sincronización Total de Compartir PDF + Texto con hidratación de imágenes y preferencias de la Parte 1
  Future<void> _sharePdfAndMessage() async {
    if (_quotation == null) return;
    try {
      // Requisito 2: Ejecución de guardar datos pendientes antes de compartir
      await _persistPendingDataIfRequested();
      if (!mounted) return;

      final authProv = Provider.of<AuthProvider>(context, listen: false);
      final bool isLoan = _currentContextKey == 'loan';

      final initialPdfConfig = PdfConfig(
        documentTitle: isLoan
            ? "COMPROBANTE DE PRESTAMO"
            : (_saleData != null ? "COMPROBANTE DE PAGO" : "COTIZACION"),
        customClientName: _clientNameCtrl.text.trim().isNotEmpty ? _clientNameCtrl.text.trim() : null,
        showTransactionDetails: !isLoan,
        showInstallments: isLoan || (_saleData != null && _saleData!['cuotas'] != null),
      );

      // Requisito 1.1: Aplicar configuración predeterminada guardada por el usuario en la Parte 1
      final finalPdfConfig = await PdfPreferencesService.applySavedPreferences(initialPdfConfig);

      // Requisito 1.2: Si includeImages está activo, hidratar fotos desde SQLite
      if (finalPdfConfig.showImages) {
        await _hydrateProductImages();
      }

      // Requisito 1.3: Sincronizar negocio y cuentas editadas en pantalla
      UserModel? effectiveOwner = authProv.user;
      final currentBiz = authProv.currentBusiness;
      if (effectiveOwner != null && currentBiz != null) {
        final updatedBiz = BusinessModel(
          id: currentBiz.id,
          commercialName: currentBiz.commercialName,
          ruc: _bizRucCtrl.text.isNotEmpty ? _bizRucCtrl.text : currentBiz.ruc,
          address: _bizAddressCtrl.text.isNotEmpty ? _bizAddressCtrl.text : currentBiz.address,
          logoUrl: currentBiz.logoUrl,
          printerConfig: currentBiz.printerConfig,
          paymentInfo: _bizPaymentCtrl.text.isNotEmpty ? _bizPaymentCtrl.text : currentBiz.paymentInfo,
          moneda: currentBiz.moneda,
          latitud: _bizLat ?? currentBiz.latitud,
          longitud: _bizLng ?? currentBiz.longitud,
        );
        effectiveOwner = UserModel(
          id: effectiveOwner.id,
          fullName: effectiveOwner.fullName,
          phone: _bizPhoneCtrl.text.isNotEmpty ? _bizPhoneCtrl.text : effectiveOwner.phone,
          email: effectiveOwner.email,
          isActive: effectiveOwner.isActive,
          codigoUnicoUsuario: effectiveOwner.codigoUnicoUsuario,
          business: updatedBiz,
        );
      }

      final pdfBytes = await PdfGenerator.generatePdf(
        quotation: _quotation!,
        ownerInfo: effectiveOwner,
        config: finalPdfConfig,
        saleData: _saleData,
      );

      final tempDir = await getTemporaryDirectory();
      final fileName = "MochilaLista_${_quotation!.id}.pdf";
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes, flush: true);

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        text: _messageCtrl.text,
      );
    } catch (e) {
      debugPrint("Error sharing PDF and WA message: $e");
      if (mounted) {
        CustomSnackBar.show(context, message: "Error al compartir PDF: $e", isError: true);
      }
    }
  }

  Future<void> _executeSendProcess() async {
    // Requisito 2: Guardar datos pendientes antes de abrir WhatsApp
    await _persistPendingDataIfRequested();
    if (!mounted) return;

    final cleanPhone = _clientPhoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    final message = Uri.encodeComponent(_messageCtrl.text);
    final Uri url = cleanPhone.length == 9
        ? Uri.parse("https://wa.me/51$cleanPhone?text=$message")
        : Uri.parse("https://wa.me/?text=$message");

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) CustomSnackBar.show(context, message: "No se pudo abrir WhatsApp", isError: true);
      }
    } catch (e) {
      debugPrint("Error launching WA: $e");
    }
  }
}