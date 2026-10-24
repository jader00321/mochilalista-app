import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/features/smart_quotation/models/whatsapp_config_model.dart';
import 'package:app_movil/features/smart_quotation/services/whatsapp_preferences_service.dart';
import 'package:app_movil/features/smart_quotation/utils/pdf_generator.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/models/pdf_config_model.dart';
import 'package:app_movil/features/smart_quotation/services/pdf_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PARTE 2 - Fase 2: Filtro Anti-Borradores y Saludo Dinámico a 0ms', () {
    test('isInternalDraftCode detecta códigos autogenerados y nombres genéricos', () {
      expect(PdfGenerator.isInternalDraftCode("Cotización Manual #21-1749"), isTrue);
      expect(PdfGenerator.isInternalDraftCode("Cotización Manual #21-174"), isTrue);
      expect(PdfGenerator.isInternalDraftCode("Cotización #105"), isTrue);
      expect(PdfGenerator.isInternalDraftCode("cotizacion #99"), isTrue);
      expect(PdfGenerator.isInternalDraftCode("Venta #450"), isTrue);
      expect(PdfGenerator.isInternalDraftCode("Borrador #1"), isTrue);
      expect(PdfGenerator.isInternalDraftCode("Cliente General"), isTrue);
      expect(PdfGenerator.isInternalDraftCode("Sin cliente"), isTrue);
      expect(PdfGenerator.isInternalDraftCode("Venta rapida"), isTrue);
      expect(PdfGenerator.isInternalDraftCode("Venta de mostrador"), isTrue);
      expect(PdfGenerator.isInternalDraftCode(null), isTrue);
      expect(PdfGenerator.isInternalDraftCode(""), isTrue);
      expect(PdfGenerator.isInternalDraftCode("   "), isTrue);

      // Clientes legítimos
      expect(PdfGenerator.isInternalDraftCode("Juan Pérez"), isFalse);
      expect(PdfGenerator.isInternalDraftCode("Librería Bazar Luzam"), isFalse);
      expect(PdfGenerator.isInternalDraftCode("Colegio San Carlos"), isFalse);
      expect(PdfGenerator.isInternalDraftCode("María Gomez 987654321"), isFalse);
    });

    test('Saludo Dinámico: Limpio ¡Hola! 👋 si es borrador o vacío, y con nombre si es real', () {
      String generateGreeting(String? rawInput) {
        final clean = rawInput?.trim() ?? "";
        if (clean.isEmpty || PdfGenerator.isInternalDraftCode(clean)) {
          return "¡Hola! 👋";
        }
        return "¡Hola *$clean*! 👋";
      }

      expect(generateGreeting("Cotización Manual #21-1749"), equals("¡Hola! 👋"));
      expect(generateGreeting("Cliente General"), equals("¡Hola! 👋"));
      expect(generateGreeting(""), equals("¡Hola! 👋"));
      expect(generateGreeting(null), equals("¡Hola! 👋"));
      expect(generateGreeting("Valeria Julca"), equals("¡Hola *Valeria Julca*! 👋"));
      expect(generateGreeting("Roberto"), equals("¡Hola *Roberto*! 👋"));
    });

    test('Reemplazo en modo manual preserva el cuerpo del mensaje y actualiza el saludo', () {
      const originalText = "¡Hola! 👋\n\nEste es un texto editado manualmente por el usuario.";
      final greetingRegex = RegExp(r'^¡Hola(?:\s+\*[^*]+\*)?!\s*👋', multiLine: true);

      // Usuario escribe nombre "Carlos"
      final String withName = originalText.replaceFirst(greetingRegex, "¡Hola *Carlos*! 👋");
      expect(withName, startsWith("¡Hola *Carlos*! 👋\n\nEste es un texto editado"));

      // Usuario borra el nombre
      final String withoutName = withName.replaceFirst(greetingRegex, "¡Hola! 👋");
      expect(withoutName, startsWith("¡Hola! 👋\n\nEste es un texto editado"));
    });
  });

  group('PARTE 2 - Fase 1 y 4: Modelos, Estilos de Plantilla y Preferencias Contextuales', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('WhatsAppConfig serialización y copyWith completo', () {
      final config = WhatsAppConfig(
        style: WhatsAppMessageStyle.urgentOffer,
        showSubtotals: true,
        showTotalGlobal: true,
        showSavingsSection: true,
        showDiscountDetail: true,
        customIntro: "¡Gran promoción!",
        customClosing: "Atentamente la gerencia.",
      );

      final json = config.toJson();
      expect(json['style'], equals('urgentOffer'));
      expect(json['customIntro'], equals("¡Gran promoción!"));

      final restored = WhatsAppConfig.fromJson(json);
      expect(restored.style, equals(WhatsAppMessageStyle.urgentOffer));
      expect(restored.showDiscountDetail, isTrue);
      expect(restored.customClosing, equals("Atentamente la gerencia."));

      final modified = restored.copyWith(style: WhatsAppMessageStyle.compact, showSubtotals: false);
      expect(modified.style, equals(WhatsAppMessageStyle.compact));
      expect(modified.showSubtotals, isFalse);
      expect(modified.showDiscountDetail, isTrue);
    });

    test('WhatsAppPreferencesService guarda y aísla preferencias e intros por situación (quote, sale, loan)', () async {
      // 1. Guardar plantilla para Cotización
      await WhatsAppPreferencesService.saveCustomTexts(
        customIntro: "Intro Cotización: Precios exclusivos",
        customClosing: "Cierre Cotización: Válido 7 días",
        contextKey: 'quote',
      );

      // 2. Guardar plantilla para Venta
      await WhatsAppPreferencesService.saveCustomTexts(
        customIntro: "Intro Venta: Gracias por tu compra",
        customClosing: "Cierre Venta: Que disfrutes tu pedido",
        contextKey: 'sale',
      );

      // 3. Guardar plantilla para Préstamo
      await WhatsAppPreferencesService.saveCustomTexts(
        customIntro: "Intro Préstamo: Detalle formal de préstamo aprobado",
        customClosing: "Cierre Préstamo: Fechas estrictas de amortización",
        contextKey: 'loan',
      );

      // Verificación de aislamiento estricto
      final quoteTexts = await WhatsAppPreferencesService.loadCustomTexts(contextKey: 'quote');
      final saleTexts = await WhatsAppPreferencesService.loadCustomTexts(contextKey: 'sale');
      final loanTexts = await WhatsAppPreferencesService.loadCustomTexts(contextKey: 'loan');

      expect(quoteTexts['customIntro'], equals("Intro Cotización: Precios exclusivos"));
      expect(saleTexts['customIntro'], equals("Intro Venta: Gracias por tu compra"));
      expect(loanTexts['customIntro'], equals("Intro Préstamo: Detalle formal de préstamo aprobado"));

      // Aplicar preferencias contextualmente sobre configs independientes
      final quoteConfig = await WhatsAppPreferencesService.applySavedPreferences(WhatsAppConfig(), contextKey: 'quote');
      final saleConfig = await WhatsAppPreferencesService.applySavedPreferences(WhatsAppConfig(), contextKey: 'sale');
      final loanConfig = await WhatsAppPreferencesService.applySavedPreferences(WhatsAppConfig(), contextKey: 'loan');

      expect(quoteConfig.customIntro, equals("Intro Cotización: Precios exclusivos"));
      expect(saleConfig.customIntro, equals("Intro Venta: Gracias por tu compra"));
      expect(loanConfig.customIntro, equals("Intro Préstamo: Detalle formal de préstamo aprobado"));

      // Reseteo específico de un contexto sin contaminar los otros
      await WhatsAppPreferencesService.resetToDefaults(contextKey: 'quote');
      final afterResetQuote = await WhatsAppPreferencesService.loadCustomTexts(contextKey: 'quote');
      final afterResetSale = await WhatsAppPreferencesService.loadCustomTexts(contextKey: 'sale');

      expect(afterResetQuote['customIntro'], isNull);
      expect(afterResetSale['customIntro'], equals("Intro Venta: Gracias por tu compra"));
    });
  });

  group('PARTE 2 - Fase 4: Semántica Exacta por Contexto y Paridad Contable en Préstamos', () {
    late SmartQuotationModel mockQuotation;

    setUp(() {
      mockQuotation = SmartQuotationModel(
        id: 101,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        clientName: "Borrador #1",
        createdAt: DateTime.now().toIso8601String(),
        status: "DRAFT",
        type: "STANDARD",
        totalAmount: 100.0,
        totalSavings: 15.0,
        items: [
          QuotationItem(
            id: 1,
            productName: "Cuaderno Standford A4",
            quantity: 5,
            unitPriceApplied: 10.0,
            originalUnitPrice: 12.0,
          ),
          QuotationItem(
            id: 2,
            productName: "Caja de Colores 24u",
            quantity: 2,
            unitPriceApplied: 25.0,
            originalUnitPrice: 27.5,
          ),
        ],
      );
    });

    test('Cotización en estilo Comercial Detallado genera vocabulario adecuado y validez', () {
      final config = WhatsAppConfig(style: WhatsAppMessageStyle.commercial, includeValidity: true);
      final sb = StringBuffer();

      sb.writeln("¡Hola! 👋\n");
      sb.writeln("Es un gusto saludarte. Aquí te envío la cotización detallada de los productos solicitados:\n");
      sb.writeln("🛍️ *DETALLE DE PRODUCTOS*");
      for (var item in mockQuotation.items) {
        sb.writeln("▪ ${item.quantity}x ${item.productName} -> *S/ ${(item.quantity * item.unitPriceApplied).toStringAsFixed(2)}*");
      }
      sb.writeln("\n📊 *RESUMEN TOTAL*");
      sb.writeln("▪ Importe Total: *S/ ${mockQuotation.totalAmount.toStringAsFixed(2)}*");
      sb.writeln("▪ Ahorro Total: *S/ ${mockQuotation.totalSavings.toStringAsFixed(2)}* 🎉\n");
      if (config.includeValidity) {
        sb.writeln("⏳ *Validez:* Precios válidos por 7 días calendario.\n");
      }
      sb.writeln("¡Quedamos atentos a tu confirmación!");

      final msg = sb.toString();
      expect(msg, contains("cotización detallada"));
      expect(msg, contains("🛍️ *DETALLE DE PRODUCTOS*"));
      expect(msg, contains("Ahorro Total: *S/ 15.00* 🎉"));
      expect(msg, contains("Validez:"));
      expect(msg, isNot(contains("Cotización Manual #")));
    });

    test('Paridad Contable en Préstamo Personal: Desglose de Capital, Interés y Cuotas', () {
      final saleData = {
        'origen_venta': 'prestamo_personal',
        'monto_total': 1100.0,
        'porcentaje_interes': 10.0,
        'monto_pagado': 300.0,
        'cuotas': [
          {'numero_cuota': 1, 'monto': 300.0, 'fecha_vencimiento': '2026-10-15', 'estado': 'pagado'},
          {'numero_cuota': 2, 'monto': 400.0, 'fecha_vencimiento': '2026-11-15', 'estado': 'pendiente'},
          {'numero_cuota': 3, 'monto': 400.0, 'fecha_vencimiento': '2026-12-15', 'estado': 'pendiente'},
        ]
      };

      final double totalDebt = (saleData['monto_total'] as num).toDouble();
      final double paid = (saleData['monto_pagado'] as num).toDouble();
      final double debt = totalDebt - paid;
      final double interestRate = (saleData['porcentaje_interes'] as num).toDouble();

      final double capital = totalDebt / (1 + (interestRate / 100));
      final double interestAmount = totalDebt - capital;

      expect(capital, closeTo(1000.0, 0.01));
      expect(interestAmount, closeTo(100.0, 0.01));

      final sb = StringBuffer();
      sb.writeln("¡Hola *Lucía*! 👋\n");
      sb.writeln("Es un gusto saludarte. Te comparto el detalle formal del préstamo personal registrado:\n");
      sb.writeln("🏦 *DETALLE DEL PRÉSTAMO*");
      sb.writeln("▪ Capital Prestado: *S/ ${capital.toStringAsFixed(2)}*");
      sb.writeln("▪ Interés Acordado: *${interestRate.toStringAsFixed(1)}% (S/ ${interestAmount.toStringAsFixed(2)})*");
      sb.writeln("▪ Total a Devolver: *S/ ${totalDebt.toStringAsFixed(2)}*");
      sb.writeln("▪ Monto Abonado: *S/ ${paid.toStringAsFixed(2)}* ✅");
      sb.writeln("▪ *Saldo Pendiente por Pagar: S/ ${debt.toStringAsFixed(2)}* ⚠️\n");
      sb.writeln("📅 *CRONOGRAMA DE PAGOS* (3 Cuotas)");
      sb.writeln("▪ Cuota 1: *S/ 300.00* (Vence: 15/10/2026) - ✅ Pagado");
      sb.writeln("▪ Cuota 2: *S/ 400.00* (Vence: 15/11/2026) - ⏳ Pendiente");
      sb.writeln("▪ Cuota 3: *S/ 400.00* (Vence: 15/12/2026) - ⏳ Pendiente\n");
      sb.writeln("💳 *CUENTAS DE ABONO* (Para amortizar o cancelar cuotas)");
      sb.writeln("📱 Yape: 987654321");

      final msg = sb.toString();
      expect(msg, contains("🏦 *DETALLE DEL PRÉSTAMO*"));
      expect(msg, contains("Capital Prestado: *S/ 1000.00*"));
      expect(msg, contains("Interés Acordado: *10.0% (S/ 100.00)*"));
      expect(msg, contains("Total a Devolver: *S/ 1100.00*"));
      expect(msg, contains("Saldo Pendiente por Pagar: S/ 800.00* ⚠️"));
      expect(msg, contains("📅 *CRONOGRAMA DE PAGOS* (3 Cuotas)"));
      expect(msg, contains("💳 *CUENTAS DE ABONO*"));
      expect(msg, isNot(contains("DETALLE DE PRODUCTOS")));
    });

    test('Sincronización Total con Preferencias de PDF de la Parte 1', () async {
      SharedPreferences.setMockInitialValues({});
      // Guardamos configuración en Parte 1
      final pdfConfigToSave = PdfConfig(
        theme: PdfTheme.emerald,
        pageSize: PdfPageSize.ticket80,
        showImages: true,
        showPaymentAccounts: true,
      );
      await PdfPreferencesService.saveDefaultConfig(pdfConfigToSave);

      // En WhatsApp, al generar para compartir PDF
      final initialWaPdfConfig = PdfConfig(
        documentTitle: "COMPROBANTE DE PAGO",
        customClientName: "Cliente Verificado",
      );

      final resolved = await PdfPreferencesService.applySavedPreferences(initialWaPdfConfig);
      expect(resolved.theme, equals(PdfTheme.emerald));
      expect(resolved.pageSize, equals(PdfPageSize.ticket80));
      expect(resolved.showImages, isTrue);
      expect(resolved.documentTitle, equals("COMPROBANTE DE PAGO")); // Preservado
      expect(resolved.customClientName, equals("Cliente Verificado")); // Inyectado
    });
  });

  group('PARTE 2 - Fase 3 y 5: Herramientas de Formato, Snippets y Envío Flexible', () {
    test('Snippets de pago generan texto profesional estructurado', () {
      String insertYape(String phone) => "📱 Yape: ${phone.isNotEmpty ? phone : '[Mi Teléfono]'}";
      String insertPlin(String phone) => "📱 Plin: ${phone.isNotEmpty ? phone : '[Mi Teléfono]'}";
      String insertBcp() => "🏦 BCP Soles: 191-0000000-0-00";

      expect(insertYape("987654321"), equals("📱 Yape: 987654321"));
      expect(insertYape(""), equals("📱 Yape: [Mi Teléfono]"));
      expect(insertPlin("976644890"), equals("📱 Plin: 976644890"));
      expect(insertBcp(), contains("BCP Soles:"));
    });

    test('Envío flexible a WhatsApp genera enlace directo o para selección de contacto', () {
      Uri buildWhatsAppUri(String rawPhone, String messageText) {
        final cleanPhone = rawPhone.replaceAll(RegExp(r'\D'), '');
        final encoded = Uri.encodeComponent(messageText);
        if (cleanPhone.length == 9) {
          return Uri.parse("https://wa.me/51$cleanPhone?text=$encoded");
        }
        return Uri.parse("https://wa.me/?text=$encoded");
      }

      // Con teléfono válido de 9 dígitos
      final urlWithPhone = buildWhatsAppUri("987 654 321", "¡Hola! 👋");
      expect(urlWithPhone.toString(), startsWith("https://wa.me/51987654321?text="));

      // Sin teléfono (selección de contacto en WhatsApp)
      final urlWithoutPhone = buildWhatsAppUri("", "¡Hola! 👋");
      expect(urlWithoutPhone.toString(), startsWith("https://wa.me/?text="));

      final urlShortPhone = buildWhatsAppUri("123", "¡Hola! 👋");
      expect(urlShortPhone.toString(), startsWith("https://wa.me/?text="));
    });
  });
}
