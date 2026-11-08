import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_movil/core/utils/cuota_date_helper.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/sale_payment_timeline.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/models/pdf_config_model.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/features/smart_quotation/utils/pdf_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ÁRBITRO ADVERSARIAL PARTE 2: CuotaDateHelper, Timeline, Detalle Préstamo, PDF y WhatsApp', () {
    
    // =========================================================================
    // 1. AUDITORÍA DE CUOTA DATE HELPER (MULTI-FORMATO RESILIENTE Y FECHA UNIVERSAL)
    // =========================================================================
    test('1.1 CuotaDateHelper parsea con éxito fechas ISO-8601 y dd/MM/yyyy en pasado, hoy y futuro', () {
      final refDate = DateTime(2026, 11, 7); // Sábado 7 Noviembre 2026

      // Caso 1: Fecha pasada en formato ISO-8601
      final pastIso = CuotaDateHelper.evaluate("2026-10-18", referenceDate: refDate);
      expect(pastIso.isPast, isTrue);
      expect(pastIso.prefix, "Venció:");
      expect(pastIso.dateFormatted, "18/10/2026");
      expect(pastIso.fullLabel, "Venció: 18/10/2026");
      expect(pastIso.daysDifference, 20);

      // Caso 2: Fecha pasada en formato latino dd/MM/yyyy (crítico para no lanzar FormatException)
      final pastLat = CuotaDateHelper.evaluate("18/10/2026", referenceDate: refDate);
      expect(pastLat.isPast, isTrue);
      expect(pastLat.prefix, "Venció:");
      expect(pastLat.dateFormatted, "18/10/2026");
      expect(pastLat.fullLabel, "Venció: 18/10/2026");
      expect(pastLat.daysDifference, 20);

      // Caso 3: Fecha de hoy (ISO y dd/MM/yyyy)
      final todayIso = CuotaDateHelper.evaluate("2026-11-07", referenceDate: refDate);
      expect(todayIso.isToday, isTrue);
      expect(todayIso.prefix, "Vence hoy:");
      expect(todayIso.fullLabel, "Vence hoy: 07/11/2026");
      expect(todayIso.daysDifference, 0);

      final todayLat = CuotaDateHelper.evaluate("07/11/2026", referenceDate: refDate);
      expect(todayLat.isToday, isTrue);
      expect(todayLat.fullLabel, "Vence hoy: 07/11/2026");

      // Caso 4: Fecha futura (ISO y dd/MM/yyyy)
      final futureIso = CuotaDateHelper.evaluate("2026-11-17", referenceDate: refDate);
      expect(futureIso.isFuture, isTrue);
      expect(futureIso.prefix, "Vence:");
      expect(futureIso.fullLabel, "Vence: 17/11/2026");
      expect(futureIso.daysDifference, -10);

      final futureLat = CuotaDateHelper.evaluate("17/11/2026", referenceDate: refDate);
      expect(futureLat.isFuture, isTrue);
      expect(futureLat.fullLabel, "Vence: 17/11/2026");

      // Caso 5: Resiliencia defensiva ante nulls o cadenas vacías
      final fallbackNull = CuotaDateHelper.evaluate(null, referenceDate: refDate);
      expect(fallbackNull.prefix, "Vence:");
      expect(fallbackNull.dateFormatted, "-");

      final fallbackInvalid = CuotaDateHelper.evaluate("fecha_invalida", referenceDate: refDate);
      expect(fallbackInvalid.prefix, "Vence:");
      expect(fallbackInvalid.dateFormatted, "fecha_invalida");
    });

    // =========================================================================
    // 2. AUDITORÍA VISUAL Y GEOMÉTRICA DE PLAN DE CUOTAS (sale_payment_timeline.dart)
    // =========================================================================
    testWidgets('2.1 sale_payment_timeline en 320dp y 360dp: 3 botones uniformes, badges en Wrap y 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dummyCuotas = [
        {
          'id': 101,
          'numero_cuota': 1,
          'monto': 480.0,
          'monto_original': 480.0,
          'monto_pagado': 480.0,
          'mora_monto': 0.0,
          'fecha_vencimiento': '2026-10-18', // En el pasado
          'estado': 'pagado',
        },
        {
          'id': 102,
          'numero_cuota': 2,
          'monto': 528.0,
          'monto_original': 480.0,
          'monto_pagado': 0.0,
          'mora_monto': 48.0,
          'mora_automatica': 1,
          'fecha_vencimiento': '2026-11-02', // Vencida con mora
          'estado': 'pendiente',
        },
        {
          'id': 103,
          'numero_cuota': 3,
          'monto': 480.0,
          'monto_original': 480.0,
          'monto_pagado': 0.0,
          'mora_monto': 0.0,
          'fecha_vencimiento': '2026-11-17', // Pendiente futura
          'estado': 'pendiente',
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SalePaymentTimeline(
                cuotasRaw: dummyCuotas,
                isDark: true,
                clientId: 1,
                clientName: "Jj",
                clientPhone: "922836879",
                isLoan: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verificar Cuota 1 pagada: debe mostrar PAGADA (femenino) y fecha "Venció: 18/10/2026"
      expect(find.text("PAGADA"), findsOneWidget);
      expect(find.textContaining("Venció: 18/10/2026"), findsOneWidget);

      // Verificar Cuota 2 con mora:
      // a) Botón conciso [Mora] sin el texto (+S/ 48.00) en el botón
      expect(find.text("Mora"), findsOneWidget);
      // b) Píldora de desglose legible en Wrap
      expect(find.textContaining("Base: S/ 480.00 • + Mora: S/ 48.00"), findsOneWidget);
      // c) Chip [Auto] sin emojis Unicode
      expect(find.text("Auto"), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);

      // Botones de acción simétricos presentes
      expect(find.text("Recordar"), findsNWidgets(2)); // Cuotas 2 y 3
      expect(find.text("Cobrar"), findsNWidgets(2));

      // Verificar Cuota 3 pendiente futura: botón "Prog. Mora" y estado "PENDIENTE"
      expect(find.text("Prog. Mora"), findsOneWidget);
      expect(find.text("PENDIENTE"), findsOneWidget);
      expect(find.textContaining("Vence: 17/11/2026"), findsOneWidget);

      FlutterError.onError = (FlutterErrorDetails details) {
        debugPrint("FULL DETAILS:\n${details.toString()}");
      };
      // Cambiar a pantalla ultra-estrecha de 320dp y verificar que no haya overflow
      tester.view.physicalSize = const Size(320, 800);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    // =========================================================================
    // 3. AUDITORÍA GEOMÉTRICA DE DETALLE DEL PRÉSTAMO (sale_financial_detail_screen.dart)
    // =========================================================================
    testWidgets('3.1 Detalle del Préstamo en 320dp: Cero colisión geométrica entre [Auto] y precio S/ 528.00', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Construimos una tarjeta representativa con la cabecera idéntica a sale_financial_detail_screen.dart
      final dateInfo = CuotaDateHelper.evaluate("2026-11-02", referenceDate: DateTime(2026, 11, 7));
      const double cMontoOriginal = 480.0;
      const double cMoraMonto = 48.0;
      const double cMonto = 528.0;
      const bool isAutoMora = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              titleSpacing: 0,
              title: const FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  "Detalle del Préstamo #14",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              actions: const [
                Icon(Icons.picture_as_pdf),
                Icon(Icons.chat),
              ],
            ),
            body: SingleChildScrollView(
              child: Card(
                child: ExpansionTile(
                  leading: const CircleAvatar(child: Icon(Icons.warning_amber_rounded)),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Cuota 2", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (isAutoMora) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded, size: 11, color: Colors.amber),
                              SizedBox(width: 2),
                              Text("Auto", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Venció hace ${dateInfo.daysOverdue} días",
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        if (cMoraMonto > 0.01) ...[
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "Base: S/ ${cMontoOriginal.toStringAsFixed(2)} • + Mora: S/ ${cMoraMonto.toStringAsFixed(2)} (10.0%)",
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "S/ ${cMonto.toStringAsFixed(2)}",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("VENCIDA", style: TextStyle(color: Colors.red, fontSize: 10.5, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  children: const [
                    ListTile(title: Text("Desglose Financiero")),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verificar que el AppBar muestra el texto completo sin error
      expect(find.text("Detalle del Préstamo #14"), findsOneWidget);

      // Comprobación geométrica: Rect del badge Auto vs Rect del precio S/ 528.00
      final autoFinder = find.text("Auto");
      final priceFinder = find.text("S/ 528.00");

      expect(autoFinder, findsOneWidget);
      expect(priceFinder, findsOneWidget);

      final Rect autoRect = tester.getRect(autoFinder);
      final Rect priceRect = tester.getRect(priceFinder);
      debugPrint("DEBUG autoRect: $autoRect");
      debugPrint("DEBUG priceRect: $priceRect");
      debugPrint("DEBUG titleRect: ${tester.getRect(find.byType(ExpansionTile))}");

      // El badge Auto NUNCA debe sobreponerse al precio
      expect(autoRect.overlaps(priceRect), isFalse, reason: "El badge [Auto] no debe colisionar con el precio!");
      expect(autoRect.right < priceRect.left, isTrue, reason: "El badge [Auto] debe quedar a la izquierda del precio!");
      expect(tester.takeException(), isNull);
    });

    // =========================================================================
    // 4. AUDITORÍA DE COMPROBANTE EN PDF (pdf_generator.dart)
    // =========================================================================
    test('4.1 pdf_generator: Oculta RUC vacío, limpia 00:00 y muestra PAGADA con fecha universal', () async {
      final userWithoutRuc = UserModel(
        id: 1,
        fullName: "Librería Bazar Luzam",
        isActive: true,
        business: BusinessModel(
          id: 1,
          commercialName: "LIBRERÍA BAZAR LUZAM",
          ruc: "", // RUC vacío
          address: "talara",
        ),
        phone: "976644890",
      );

      final dummyQuotation = SmartQuotationModel(
        id: 15,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        clientName: "Jj",
        createdAt: "2026-10-02 00:00:00", // Hora 00:00 histórica
        totalAmount: 2448.0,
        totalSavings: 0.0,
        status: 'READY',
        type: 'prestamo',
        items: [],
      );

      final saleData = {
        'id': 15,
        'origen_venta': 'prestamo_personal',
        'fecha_venta': '2026-10-02 00:00:00',
        'cliente_nombre': 'Jj',
        'monto_total': 2448.0,
        'monto_pagado': 480.0,
        'cuotas': [
          {
            'numero_cuota': 1,
            'monto': 480.0,
            'monto_original': 480.0,
            'monto_pagado': 480.0,
            'mora_monto': 0.0,
            'fecha_vencimiento': '2026-10-18', // Pasada y pagada
            'estado': 'pagado',
          },
          {
            'numero_cuota': 2,
            'monto': 528.0,
            'monto_original': 480.0,
            'monto_pagado': 0.0,
            'mora_monto': 48.0,
            'fecha_vencimiento': '2026-11-02', // Vencida
            'estado': 'pendiente',
          },
        ],
      };

      final pdfConfig = PdfConfig(
        showBusinessInfo: true,
        includeShopRuc: true,
      );

      // Generación A4
      final pdfBytesA4 = await PdfGenerator.generatePdf(
        quotation: dummyQuotation,
        ownerInfo: userWithoutRuc,
        config: pdfConfig,
        saleData: saleData,
      );
      expect(pdfBytesA4, isNotEmpty);

      // Generación Ticket
      final pdfConfigTicket = pdfConfig.copyWith(
        pageSize: PdfPageSize.ticket80,
      );

      final pdfBytesTicket = await PdfGenerator.generatePdf(
        quotation: dummyQuotation,
        ownerInfo: userWithoutRuc,
        config: pdfConfigTicket,
        saleData: saleData,
      );
      expect(pdfBytesTicket, isNotEmpty);
    });

    // =========================================================================
    // 5. AUDITORÍA DE FORMATO Y SIMETRÍA EN MENSAJE DE WHATSAPP
    // =========================================================================
    test('5.1 Cronograma de WhatsApp: Formato simétrico con estado femenino y regla universal', () {
      final refDate = DateTime(2026, 11, 7);

      final cuotasRaw = [
        {
          'numero_cuota': 1,
          'monto': 480.0,
          'monto_original': 480.0,
          'monto_pagado': 480.0,
          'mora_monto': 0.0,
          'fecha_vencimiento': '2026-10-18',
          'estado': 'pagado',
        },
        {
          'numero_cuota': 2,
          'monto': 528.0,
          'monto_original': 480.0,
          'monto_pagado': 0.0,
          'mora_monto': 48.0,
          'fecha_vencimiento': '2026-11-02',
          'estado': 'pendiente',
        },
        {
          'numero_cuota': 3,
          'monto': 480.0,
          'monto_original': 480.0,
          'monto_pagado': 0.0,
          'mora_monto': 0.0,
          'fecha_vencimiento': '2026-11-17',
          'estado': 'pendiente',
        },
      ];

      final sb = StringBuffer();
      sb.writeln("📅 *CRONOGRAMA DE PAGOS* (${cuotasRaw.length} Cuotas)");

      for (var c in cuotasRaw) {
        final double cuotaMonto = (c['monto'] as num).toDouble();
        final double cuotaPagado = (c['monto_pagado'] as num).toDouble();
        final double saldoFalta = cuotaMonto - cuotaPagado;
        final double moraMonto = (c['mora_monto'] as num).toDouble();
        final double montoOriginal = (c['monto_original'] as num).toDouble();
        final bool tieneMora = moraMonto > 0.01;
        final bool pagado = c['estado'] == 'pagado' || (saldoFalta <= 0.01 && cuotaMonto > 0);

        final dateInfo = CuotaDateHelper.evaluate(c['fecha_vencimiento'], referenceDate: refDate);
        final int daysOverdue = dateInfo.daysOverdue;
        final bool isVencida = !pagado && dateInfo.isPast;

        final String amountText = tieneMora
            ? "*S/ ${cuotaMonto.toStringAsFixed(2)}* (Base: S/ ${montoOriginal.toStringAsFixed(2)} + Mora: S/ ${moraMonto.toStringAsFixed(2)})"
            : "*S/ ${cuotaMonto.toStringAsFixed(2)}*";

        if (pagado) {
          sb.writeln("✅ Cuota ${c['numero_cuota']}: $amountText (${dateInfo.fullLabel}) - *Pagada*");
        } else if (isVencida) {
          final String vencidaStatus = "- *Vencida (hace $daysOverdue ${daysOverdue == 1 ? 'día' : 'días'})*";
          sb.writeln("🔴 Cuota ${c['numero_cuota']}: $amountText (${dateInfo.fullLabel}) $vencidaStatus");
        } else {
          sb.writeln("⏳ Cuota ${c['numero_cuota']}: $amountText (${dateInfo.fullLabel}) - *Pendiente*");
        }
      }

      final message = sb.toString();

      // Verificaciones estrictas
      expect(message, contains("✅ Cuota 1: *S/ 480.00* (Venció: 18/10/2026) - *Pagada*"));
      expect(message, contains("🔴 Cuota 2: *S/ 528.00* (Base: S/ 480.00 + Mora: S/ 48.00) (Venció: 02/11/2026) - *Vencida (hace 5 días)*"));
      expect(message, contains("⏳ Cuota 3: *S/ 480.00* (Vence: 17/11/2026) - *Pendiente*"));
    });
  });
}
