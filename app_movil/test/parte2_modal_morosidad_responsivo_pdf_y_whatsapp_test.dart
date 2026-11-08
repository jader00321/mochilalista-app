import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/cuota_morosidad_modal.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/models/pdf_config_model.dart';
import 'package:app_movil/features/smart_quotation/utils/pdf_generator.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/whatsapp_preview_modal.dart';

class _MockSaleProvider extends ChangeNotifier implements SaleProvider {
  bool aplicarManualCalled = false;
  bool configurarAutoCalled = false;
  bool quitarMorosidadCalled = false;

  int? lastCuotaId;
  String? lastTipo;
  double? lastValor;
  double? lastNuevoTotal;
  bool? lastActiva;
  String? lastFrecuencia;
  int? lastIntervalo;

  @override
  Future<bool> aplicarMorosidadManual(
    int cuotaId, {
    required String tipo,
    required double valor,
    double? nuevoMontoTotal,
    int? saleId,
  }) async {
    aplicarManualCalled = true;
    lastCuotaId = cuotaId;
    lastTipo = tipo;
    lastValor = valor;
    lastNuevoTotal = nuevoMontoTotal;
    return true;
  }

  @override
  Future<bool> configurarMorosidadAutomatica(
    int cuotaId, {
    required bool activa,
    String? frecuencia,
    int? intervaloDias,
    String? tipo,
    double? valor,
    bool calcularDesdeVencimiento = true,
    int? saleId,
  }) async {
    configurarAutoCalled = true;
    lastCuotaId = cuotaId;
    lastActiva = activa;
    lastFrecuencia = frecuencia;
    lastIntervalo = intervaloDias;
    lastTipo = tipo;
    lastValor = valor;
    return true;
  }

  @override
  Future<bool> quitarMorosidad(int cuotaId, {int? saleId}) async {
    quitarMorosidadCalled = true;
    lastCuotaId = cuotaId;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildModalApp({
    required Map<String, dynamic> cuota,
    required _MockSaleProvider mockProvider,
    VoidCallback? onSaved,
  }) {
    return ChangeNotifierProvider<SaleProvider>.value(
      value: mockProvider,
      child: MaterialApp(
        home: Scaffold(
          body: CuotaMorosidadModal(
            key: ValueKey('${cuota['id']}_${cuota['mora_monto']}_${cuota['mora_activa']}_${cuota['mora_automatica']}_${cuota['fecha_vencimiento']}'),
            cuota: cuota,
            isDark: true,
            onSaved: onSaved ?? () {},
          ),
        ),
      ),
    );
  }

  group('PARTE 2: Modal Gestor de Morosidad Responsivo, PDF y WhatsApp (Criterios V1 a V8)', () {
    testWidgets('V1: Scroll y Pinned Footer en Modal (viewport 360x640dp sin overflow)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockProvider = _MockSaleProvider();
      final cuota = {
        'id': 2,
        'numero_cuota': 2,
        'monto': 305.0,
        'monto_original': 300.0,
        'mora_monto': 5.0,
        'mora_activa': 0,
        'mora_frecuencia': 'semanal',
        'mora_intervalo_dias': 7,
        'fecha_vencimiento': '2026-10-31',
        'venta_id': 13,
      };

      await tester.pumpWidget(buildModalApp(cuota: cuota, mockProvider: mockProvider));
      await tester.pumpAndSettle();

      // Cambiar a la pestaña Automático Periódico
      final tabAuto = find.text('Automático Periódico');
      expect(tabAuto, findsOneWidget);
      await tester.tap(tabAuto, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verificar ausencia de overflow
      expect(tester.takeException(), isNull);

      // Verificar que el cuerpo central es escrolleable
      final scrollView = find.byType(SingleChildScrollView);
      expect(scrollView, findsWidgets);

      // Verificar que los botones de acción en el footer permanecen visibles
      final saveBtn = find.widgetWithText(ElevatedButton, 'Guardar y Aplicar');
      final cancelBtn = find.widgetWithText(OutlinedButton, 'Cancelar');
      expect(saveBtn, findsOneWidget);
      expect(cancelBtn, findsOneWidget);

      // Deslizar el scroll hacia abajo para verificar navegación fluida
      await tester.drag(scrollView.first, const Offset(0, -250));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(saveBtn, findsOneWidget);
    });

    testWidgets('V2: 4 Estados del Badge Semántico en la Tarjeta Superior', (tester) async {
      final mockProvider = _MockSaleProvider();

      // Estado 1: Sin mora aplicada
      final cuotaSinMora = {
        'id': 1,
        'numero_cuota': 1,
        'monto': 300.0,
        'monto_original': 300.0,
        'mora_monto': 0.0,
        'mora_activa': 0,
        'fecha_vencimiento': '2026-10-24', // Vencida
      };
      await tester.pumpWidget(buildModalApp(cuota: cuotaSinMora, mockProvider: mockProvider));
      await tester.pumpAndSettle();
      expect(find.text('SIN MORA APLICADA'), findsOneWidget);

      // Estado 2: Mora manual activa
      final cuotaMoraManual = {
        'id': 2,
        'numero_cuota': 2,
        'monto': 305.0,
        'monto_original': 300.0,
        'mora_monto': 5.0,
        'mora_activa': 0,
        'fecha_vencimiento': '2026-10-31', // Vencida
      };
      await tester.pumpWidget(buildModalApp(cuota: cuotaMoraManual, mockProvider: mockProvider));
      await tester.pumpAndSettle();
      expect(find.text('MORA MANUAL ACTIVA: +S/ 5.00'), findsOneWidget);

      // Estado 3: Mora periódica activa
      final cuotaMoraPeriodica = {
        'id': 3,
        'numero_cuota': 3,
        'monto': 305.0,
        'monto_original': 300.0,
        'mora_monto': 5.0,
        'mora_activa': 1,
        'mora_automatica': 1,
        'mora_frecuencia': 'semanal',
        'mora_intervalo_dias': 7,
        'fecha_vencimiento': '2026-10-31', // Vencida
      };
      await tester.pumpWidget(buildModalApp(cuota: cuotaMoraPeriodica, mockProvider: mockProvider));
      await tester.pumpAndSettle();
      expect(find.text('MORA PERIÓDICA ACTIVA: +S/ 5.00 cada 7 días'), findsOneWidget);

      // Estado 4: Cuota no vencida (mora programada)
      final futureDate = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 7)));
      final cuotaNoVencida = {
        'id': 4,
        'numero_cuota': 4,
        'monto': 300.0,
        'monto_original': 300.0,
        'mora_monto': 0.0,
        'mora_activa': 1,
        'mora_automatica': 1,
        'fecha_vencimiento': futureDate,
      };
      await tester.pumpWidget(buildModalApp(cuota: cuotaNoVencida, mockProvider: mockProvider));
      await tester.pumpAndSettle();
      expect(find.text('MORA PROGRAMADA SI VENCE'), findsOneWidget);
    });

    testWidgets('V3: Condonación Directa de Mora con botón [Quitar Mora]', (tester) async {
      final mockProvider = _MockSaleProvider();
      final cuotaConMora = {
        'id': 2,
        'numero_cuota': 2,
        'monto': 305.0,
        'monto_original': 300.0,
        'mora_monto': 5.0,
        'mora_activa': 1,
        'fecha_vencimiento': '2026-10-31',
        'venta_id': 13,
      };

      bool onSavedTriggered = false;
      await tester.pumpWidget(buildModalApp(
        cuota: cuotaConMora,
        mockProvider: mockProvider,
        onSaved: () => onSavedTriggered = true,
      ));
      await tester.pumpAndSettle();

      // Botón Quitar Mora en la cabecera
      final quitarMoraBtn = find.text('Quitar Mora');
      expect(quitarMoraBtn, findsWidgets);

      await tester.tap(quitarMoraBtn.first);
      await tester.pumpAndSettle();

      // Diálogo de confirmación
      expect(find.text('¿Quitar / Condonar Morosidad?'), findsOneWidget);
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Sí, Condonar');
      expect(confirmBtn, findsOneWidget);

      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));

      expect(mockProvider.quitarMorosidadCalled, isTrue);
      expect(mockProvider.lastCuotaId, 2);
      expect(onSavedTriggered, isTrue);
    });

    testWidgets('V4: 3 Segmentos Manuales en Una Sola Fila y Presets Rápidos en 1 Toque', (tester) async {
      final mockProvider = _MockSaleProvider();
      final cuota = {
        'id': 1,
        'numero_cuota': 1,
        'monto': 300.0,
        'monto_original': 300.0,
        'mora_monto': 0.0,
        'fecha_vencimiento': '2026-10-24',
      };

      await tester.pumpWidget(buildModalApp(cuota: cuota, mockProvider: mockProvider));
      await tester.pumpAndSettle();

      // 3 segmentos en una fila
      expect(find.text('Porcentaje'), findsOneWidget);
      expect(find.text('Monto Fijo'), findsOneWidget);
      expect(find.text('Nuevo Total'), findsOneWidget);

      // Porcentaje: tocar preset +10%
      final chip10Pct = find.text('+10%');
      expect(chip10Pct, findsOneWidget);
      await tester.tap(chip10Pct);
      await tester.pumpAndSettle();

      // Base 300 * 10% = +30.00 -> Total 330.00
      expect(find.text('+ S/ 30.00'), findsOneWidget);
      expect(find.text('S/ 330.00'), findsWidgets);

      // Cambiar a Monto Fijo
      await tester.tap(find.text('Monto Fijo'));
      await tester.pumpAndSettle();

      // Tocar preset +S/ 20
      final chip20Sol = find.text('+S/ 20');
      expect(chip20Sol, findsOneWidget);
      await tester.tap(chip20Sol);
      await tester.pumpAndSettle();

      // Base 300 + 20 = +20.00 -> Total 320.00
      expect(find.text('+ S/ 20.00'), findsOneWidget);
      expect(find.text('S/ 320.00'), findsWidgets);

      // Cambiar a Nuevo Total
      await tester.tap(find.text('Nuevo Total'));
      await tester.pumpAndSettle();

      // Tocar preset Base + 10
      final chipBase10 = find.text('Base + 10');
      expect(chipBase10, findsOneWidget);
      await tester.tap(chipBase10);
      await tester.pumpAndSettle();

      // Total 310.00 -> Mora +10.00
      expect(find.text('+ S/ 10.00'), findsOneWidget);
      expect(find.text('S/ 310.00'), findsWidgets);
    });

    testWidgets('V5: Auto-activación del Switch Periódico al interactuar', (tester) async {
      final mockProvider = _MockSaleProvider();
      final cuota = {
        'id': 1,
        'numero_cuota': 1,
        'monto': 300.0,
        'monto_original': 300.0,
        'mora_monto': 0.0,
        'mora_activa': 0, // Switch inicialmente apagado
        'fecha_vencimiento': '2026-10-24',
      };

      await tester.pumpWidget(buildModalApp(cuota: cuota, mockProvider: mockProvider));
      await tester.pumpAndSettle();

      // Ir a Automático Periódico
      await tester.tap(find.text('Automático Periódico'));
      await tester.pumpAndSettle();

      // Switch inicialmente en false
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      Switch switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, isFalse);

      // Tocar el chip de frecuencia 'Semanal (7 días)'
      final semanalChip = find.text('Semanal (7 días)');
      expect(semanalChip, findsOneWidget);
      await tester.tap(semanalChip);
      await tester.pumpAndSettle();

      // El switch debe haberse auto-activado a true
      switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, isTrue);
    });

    testWidgets('V6: Simulador y Proyección Matemática Viva en Tiempo Real', (tester) async {
      final mockProvider = _MockSaleProvider();
      final now = DateTime.now();
      final sixDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      final sixDaysAgoStr = DateFormat('yyyy-MM-dd').format(sixDaysAgo);

      final cuotaVencida6d = {
        'id': 2,
        'numero_cuota': 2,
        'monto': 305.0,
        'monto_original': 300.0,
        'mora_monto': 5.0,
        'mora_activa': 1,
        'mora_frecuencia': 'semanal',
        'mora_intervalo_dias': 7,
        'mora_tipo': 'fijo',
        'mora_valor': 5.0,
        'fecha_vencimiento': sixDaysAgoStr,
      };

      await tester.pumpWidget(buildModalApp(cuota: cuotaVencida6d, mockProvider: mockProvider));
      await tester.pumpAndSettle();

      // Ir a Automático Periódico
      await tester.tap(find.text('Automático Periódico'));
      await tester.pumpAndSettle();

      // Con 6 días vencido y frecuencia semanal (7 días): 0 ciclos cumplidos, próximo recargo en 1 día
      expect(find.textContaining('6 días de atraso'), findsWidgets);
      expect(find.textContaining('0 ciclos cumplidos'), findsWidgets);
      expect(find.textContaining('Siguiente recargo (+S/ 5.00): en 1 día'), findsOneWidget);

      // Cambiar frecuencia a Diario (1 día)
      final diarioChip = find.text('Diario (1 día)');
      await tester.tap(diarioChip);
      await tester.pumpAndSettle();

      // 6 días vencido con frecuencia diaria: 6 ciclos cumplidos (+S/ 30.00 de mora)
      expect(find.textContaining('6 ciclos cumplidos'), findsWidgets);
      expect(find.textContaining('+S/ 30.00 de mora hoy'), findsOneWidget);

      // Caso cuota en plazo (futura)
      final sevenDaysFuture = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, now.day).add(const Duration(days: 7)));
      final cuotaFutura = {
        'id': 3,
        'numero_cuota': 3,
        'monto': 300.0,
        'monto_original': 300.0,
        'mora_monto': 0.0,
        'mora_activa': 1,
        'mora_frecuencia': 'diario',
        'mora_intervalo_dias': 1,
        'fecha_vencimiento': sevenDaysFuture,
      };

      await tester.pumpWidget(buildModalApp(cuota: cuotaFutura, mockProvider: mockProvider));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cuota en plazo. La regla no generará ningún cobro ahora'), findsOneWidget);
    });

    test('V7: Refinamiento de Plan de Cuotas en PDF (sin duplicación de total y Venció: dinámico)', () async {
      final quotation = SmartQuotationModel(
        id: 13,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        totalAmount: 1205.0,
        totalSavings: 0.0,
        status: 'READY',
        type: 'prestamo',
        clientName: 'Jj',
        createdAt: '2026-11-04 22:53:00',
        items: [],
      );

      final saleData = {
        'id': 13,
        'origen_venta': 'prestamo_personal',
        'cliente_nombre': 'Jj',
        'cliente_telefono': '922836879',
        'monto_total': 1205.0,
        'monto_pagado': 0.0,
        'porcentaje_interes': 20.0,
        'metodo_pago': 'efectivo',
        'estado_pago': 'pendiente',
        'fecha_venta': '2026-11-04 22:53:00',
        'cuotas': [
          {
            'numero_cuota': 1,
            'fecha_vencimiento': '2026-10-24', // Vencida
            'monto': 300.0,
            'monto_original': 300.0,
            'mora_monto': 0.0,
            'monto_pagado': 0.0,
            'estado': 'pendiente',
          },
          {
            'numero_cuota': 2,
            'fecha_vencimiento': '2026-10-31', // Vencida con mora
            'monto': 305.0,
            'monto_original': 300.0,
            'mora_monto': 5.0,
            'monto_pagado': 0.0,
            'estado': 'pendiente',
          },
          {
            'numero_cuota': 3,
            'fecha_vencimiento': '2026-11-07', // Próxima / Pendiente
            'monto': 300.0,
            'monto_original': 300.0,
            'mora_monto': 0.0,
            'monto_pagado': 0.0,
            'estado': 'pendiente',
          },
        ],
      };

      final pdfConfig = PdfConfig(
        documentTitle: 'COMPROBANTE DE PRÉSTAMO',
        footerNote: 'Condiciones de cobranza',
      );

      final pdfBytesA4 = await PdfGenerator.generatePdf(
        quotation: quotation,
        config: pdfConfig,
        ownerInfo: null,
        saleData: saleData,
      );
      expect(pdfBytesA4, isNotEmpty);

      final pdfBytesTicket = await PdfGenerator.generatePdf(
        quotation: quotation,
        config: pdfConfig.copyWith(pageSize: PdfPageSize.ticket80),
        ownerInfo: null,
        saleData: saleData,
      );
      expect(pdfBytesTicket, isNotEmpty);
    });

    testWidgets('V8: Refinamiento de Mensaje en Editor WhatsApp y Modal', (tester) async {
      final d13Ago = DateTime.now().subtract(const Duration(days: 13));
      final d6Ago = DateTime.now().subtract(const Duration(days: 6));
      final d13Fmt = DateFormat('dd/MM/yyyy').format(d13Ago);
      final d6Fmt = DateFormat('dd/MM/yyyy').format(d6Ago);

      final cuotaVencidaSinMora = {
        'id': 1,
        'numero_cuota': 1,
        'monto': 300.0,
        'monto_original': 300.0,
        'mora_monto': 0.0,
        'monto_pagado': 0.0,
        'fecha_vencimiento': DateFormat('yyyy-MM-dd').format(d13Ago),
      };

      final cuotaVencidaConMora = {
        'id': 2,
        'numero_cuota': 2,
        'monto': 305.0,
        'monto_original': 300.0,
        'mora_monto': 5.0,
        'monto_pagado': 0.0,
        'fecha_vencimiento': DateFormat('yyyy-MM-dd').format(d6Ago),
      };

      // 1. Probar WhatsAppPreviewModal para cuota individual con mora
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatsAppPreviewModal(
              key: const ValueKey('single_cuota'),
              initialClientName: 'Jj',
              initialClientPhone: '922836879',
              isDark: true,
              cuota: cuotaVencidaConMora,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que el preview de WhatsApp muestra el formato refinado Base + Mora sin total redundante
      expect(find.textContaining('Base: S/ 300.00 + Mora: S/ 5.00'), findsOneWidget);
      expect(find.textContaining('Total Cuota: *S/ 305.00*'), findsOneWidget);

      // 2. Probar WhatsAppPreviewModal con múltiples cuotas (sin mora y con mora)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatsAppPreviewModal(
              key: const ValueKey('multiple_cuotas'),
              initialClientName: 'Jj',
              initialClientPhone: '922836879',
              isDark: true,
              totalDebt: 605.0,
              multipleCuotas: [cuotaVencidaSinMora, cuotaVencidaConMora],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar cuota vencida sin mora (limpio sin guion redundante)
      expect(find.textContaining('Cuota #1: *S/ 300.00* (Venció: $d13Fmt) - *Vencida (hace 13 días)*'), findsOneWidget);
      // Verificar cuota vencida con mora
      expect(find.textContaining('Cuota #2: *S/ 305.00* (Base: S/ 300.00 + Mora: S/ 5.00) (Venció: $d6Fmt) - *Vencida (hace 6 días)*'), findsOneWidget);
      // Verificar que no imprima el guion redundante '- (Venció:'
      expect(find.textContaining('- (Venció:'), findsNothing);
    });
  });
}
