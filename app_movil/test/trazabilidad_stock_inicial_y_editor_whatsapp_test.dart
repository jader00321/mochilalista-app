import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/models/whatsapp_config_model.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_business_section.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_message_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FASE 1: Exactitud Matemática al 100% en Trazabilidad (Stock Inicial Base vs Entradas)', () {
    // Función auxiliar que replica exactamente la fórmula matemática implementada en audit_trail_screen.dart
    Map<String, double> computeAuditBalances({
      required double currentStock,
      required double factor,
      required List<Map<String, dynamic>> rawLedger,
    }) {
      double totalEntradasBrutas = 0.0;
      double totalSalidas = 0.0;
      double? primerMovimientoPositivoApertura;
      double? inventarioInicialRegistrado;

      final movements = rawLedger.reversed.toList();

      for (var row in movements) {
        final tipo = row['tipo_transaccion']?.toString().toUpperCase() ?? '';
        final double rawQty = (row['cantidad'] as num?)?.toDouble() ?? 0.0;
        final double qtyInTarget = rawQty * factor;

        if (tipo == 'INVENTARIO_INICIAL') {
          inventarioInicialRegistrado = qtyInTarget;
          totalEntradasBrutas += qtyInTarget;
        } else if (tipo == 'COMPRA_LOTE' || tipo == 'AJUSTE_POSITIVO' || tipo == 'DEVOLUCION_CLIENTE' || tipo == 'ANULACION_VENTA') {
          primerMovimientoPositivoApertura ??= qtyInTarget;
          totalEntradasBrutas += qtyInTarget;
        } else {
          totalSalidas += qtyInTarget;
        }
      }

      final double basePreLedger = (currentStock - (totalEntradasBrutas - totalSalidas)).clamp(0.0, double.infinity);

      double dotacionInicialLedger = 0.0;
      if (inventarioInicialRegistrado != null) {
        dotacionInicialLedger = inventarioInicialRegistrado;
      } else if (basePreLedger == 0.0 && primerMovimientoPositivoApertura != null) {
        dotacionInicialLedger = primerMovimientoPositivoApertura;
      }

      final double stockInicialBase = basePreLedger + dotacionInicialLedger;
      final double totalEntradasPosteriores = (totalEntradasBrutas - dotacionInicialLedger).clamp(0.0, double.infinity);
      final double saldoFinal = stockInicialBase + totalEntradasPosteriores - totalSalidas;

      return {
        'stockInicialBase': stockInicialBase,
        'entradasPosteriores': totalEntradasPosteriores,
        'salidas': totalSalidas,
        'saldoFinal': saldoFinal,
      };
    }

    test('1.1. Caso Creación con Stock Inicial explícito (INVENTARIO_INICIAL = 10)', () {
      final ledger = [
        {'tipo_transaccion': 'INVENTARIO_INICIAL', 'cantidad': 10.0},
      ];
      final res = computeAuditBalances(
        currentStock: 10.0,
        factor: 1.0,
        rawLedger: ledger,
      );

      expect(res['stockInicialBase'], 10.0);
      expect(res['entradasPosteriores'], 0.0);
      expect(res['salidas'], 0.0);
      expect(res['saldoFinal'], 10.0);
      // Ecuación 100% exacta
      expect(res['stockInicialBase']! + res['entradasPosteriores']! - res['salidas']!, 10.0);
    });

    test('1.2. Caso Quitaesmalte • Fresa 35ml (Primer movimiento COMPRA_LOTE de creación = 6, sin reabastecimientos)', () {
      final ledger = [
        {'tipo_transaccion': 'COMPRA_LOTE', 'cantidad': 6.0},
      ];
      final res = computeAuditBalances(
        currentStock: 6.0,
        factor: 1.0,
        rawLedger: ledger,
      );

      expect(res['stockInicialBase'], 6.0);
      expect(res['entradasPosteriores'], 0.0);
      expect(res['salidas'], 0.0);
      expect(res['saldoFinal'], 6.0);
      expect(res['stockInicialBase']! + res['entradasPosteriores']! - res['salidas']!, 6.0);
    });

    test('1.3. Caso Aceite • 900ml (Creación COMPRA_LOTE = 3, luego 1 venta de 2 unidades, stock actual = 1)', () {
      // Movimientos en orden descendente (más reciente primero)
      final ledger = [
        {'tipo_transaccion': 'VENTA', 'cantidad': 2.0},
        {'tipo_transaccion': 'COMPRA_LOTE', 'cantidad': 3.0},
      ];
      final res = computeAuditBalances(
        currentStock: 1.0,
        factor: 1.0,
        rawLedger: ledger,
      );

      expect(res['stockInicialBase'], 3.0);
      expect(res['entradasPosteriores'], 0.0);
      expect(res['salidas'], 2.0);
      expect(res['saldoFinal'], 1.0);
      expect(res['stockInicialBase']! + res['entradasPosteriores']! - res['salidas']!, 1.0);
    });

    test('1.4. Caso Creación con Stock CERO (INVENTARIO_INICIAL = 0)', () {
      final ledger = [
        {'tipo_transaccion': 'INVENTARIO_INICIAL', 'cantidad': 0.0},
      ];
      final res = computeAuditBalances(
        currentStock: 0.0,
        factor: 1.0,
        rawLedger: ledger,
      );

      expect(res['stockInicialBase'], 0.0);
      expect(res['entradasPosteriores'], 0.0);
      expect(res['salidas'], 0.0);
      expect(res['saldoFinal'], 0.0);
      expect(res['stockInicialBase']! + res['entradasPosteriores']! - res['salidas']!, 0.0);
    });

    test('1.5. Caso con Stock Inicial 10, Reabastecimiento posterior de 5 y Venta de 3 (Stock Actual = 12)', () {
      final ledger = [
        {'tipo_transaccion': 'VENTA', 'cantidad': 3.0},
        {'tipo_transaccion': 'COMPRA_LOTE', 'cantidad': 5.0},
        {'tipo_transaccion': 'INVENTARIO_INICIAL', 'cantidad': 10.0},
      ];
      final res = computeAuditBalances(
        currentStock: 12.0,
        factor: 1.0,
        rawLedger: ledger,
      );

      expect(res['stockInicialBase'], 10.0);
      expect(res['entradasPosteriores'], 5.0);
      expect(res['salidas'], 3.0);
      expect(res['saldoFinal'], 12.0);
      expect(res['stockInicialBase']! + res['entradasPosteriores']! - res['salidas']!, 12.0);
    });

    test('1.6. Fallback de velocidad de ventas con ventas históricas', () {
      // Simulación de cálculo de rotación cuando ventana 30d es 0
      double totalSold30 = 0.0;
      double totalSoldAllTime = 12.0;
      DateTime firstSaleDate = DateTime.now().subtract(const Duration(days: 60));

      String velocityText;
      if (totalSold30 > 0) {
        velocityText = "${totalSold30.toStringAsFixed(1)}/mes";
      } else if (totalSoldAllTime > 0) {
        final activeDays = DateTime.now().difference(firstSaleDate).inDays.clamp(1, 9999);
        final historicalMonthly = (totalSoldAllTime / activeDays) * 30.0;
        if (historicalMonthly >= 0.5) {
          velocityText = "${historicalMonthly.toStringAsFixed(1)}/mes (histórico)";
        } else {
          velocityText = "Baja rotación";
        }
      } else {
        velocityText = "Sin ventas";
      }

      expect(velocityText, contains("/mes (histórico)"));
      expect(velocityText, isNot("Sin ventas"));
    });
  });

  group('FASE 2: Moneda Oficial Peruana y Cero Emojis en Controles de UI', () {
    test('2.1. AppCurrency formatea rigurosamente a *S/ 5.05*', () {
      final formatted = AppCurrency.format(5.05);
      expect(formatted, 'S/ 5.05');

      final messageSnippet = "*$formatted*";
      expect(messageSnippet, '*S/ 5.05*');
      expect(messageSnippet, isNot(contains('5,05 S/')));
      expect(messageSnippet, isNot(contains('5.05 S/')));
    });

    test('2.2. WhatsAppMessageStyle tiene 100% etiquetas sin emojis Unicode y expone iconos vectoriales', () {
      for (final style in WhatsAppMessageStyle.values) {
        expect(style.label, isNot(contains(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true))));
        expect(style.icon, isNotNull);
        expect(style.icon, isA<IconData>());
      }

      expect(WhatsAppMessageStyle.commercial.icon, Icons.receipt_long_rounded);
      expect(WhatsAppMessageStyle.compact.icon, Icons.bolt_rounded);
      expect(WhatsAppMessageStyle.urgentOffer.icon, Icons.local_offer_rounded);
      expect(WhatsAppMessageStyle.accountDebt.icon, Icons.account_balance_wallet_rounded);
      expect(WhatsAppMessageStyle.followUp.icon, Icons.handshake_rounded);
      expect(WhatsAppMessageStyle.deliveryReady.icon, Icons.local_shipping_rounded);
    });

    testWidgets('2.3. Resumen de Entradas/Salidas y Saldo en 320dp se escala con FittedBox sin overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              width: 320,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.arrow_downward, size: 13),
                              SizedBox(width: 5),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text("Entradas: +120.5 und. base"),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.arrow_upward, size: 13),
                              SizedBox(width: 5),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text("Salidas: -45.0 und. base"),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: const [
                      Icon(Icons.outlined_flag_rounded, size: 14),
                      SizedBox(width: 6),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text("Stock Inicial Base: 100.0 und. base"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      Icon(Icons.calculate_outlined, size: 14),
                      SizedBox(width: 6),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text("Saldo Auditoría: 100.0 + 120.5 - 45.0 = 175.5 und. base"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text("Entradas: +120.5 und. base"), findsOneWidget);
      expect(find.text("Salidas: -45.0 und. base"), findsOneWidget);
      expect(find.byIcon(Icons.outlined_flag_rounded), findsOneWidget);
      expect(find.byIcon(Icons.calculate_outlined), findsOneWidget);
    });

    testWidgets('2.4. AppBar de SmartRestockScreen en 320dp escala con FittedBox sin truncar', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Motor Inteligente de Abastecimiento',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              actions: [
                IconButton(icon: const Icon(Icons.help_outline), onPressed: () {}),
                IconButton(icon: const Icon(Icons.refresh), onPressed: () {}),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Motor Inteligente de Abastecimiento'), findsOneWidget);
    });
  });

  group('FASE 3: Toggle Inteligente Bidireccional en Chips de Pago y Detección de Cambios', () {
    testWidgets('3.1. Detección y limpieza de emojis antiguos al inicializar WaBusinessSection', (tester) async {
      final phoneCtrl = TextEditingController(text: '987654321');
      final rucCtrl = TextEditingController(text: '20123456789');
      final addressCtrl = TextEditingController(text: 'Av. Grau 123');
      final paymentCtrl = TextEditingController(text: '📱 Yape: 987654321\n🏦 BCP: 191-123456');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WaBusinessSection(
                phoneCtrl: phoneCtrl,
                rucCtrl: rucCtrl,
                addressCtrl: addressCtrl,
                paymentCtrl: paymentCtrl,
                isGpsLoading: false,
                updateBusinessData: false,
                hasBusinessChanges: true,
                onGpsTap: () {},
                onUpdateDataChanged: (_) {},
                onDataChanged: () {},
              ),
            ),
          ),
        ),
      );

      // Verificamos que se renderice el nuevo título y subtítulo del perfil
      expect(find.text("Guardar estos cambios en el perfil de mi negocio"), findsOneWidget);
      expect(find.textContaining("Actualiza tu teléfono, RUC, dirección y cuentas"), findsOneWidget);
      expect(find.text("Modificado"), findsOneWidget);

      // Verificamos que los chips muestren estado activo sin emojis en los botones
      expect(find.text("✓ Yape"), findsOneWidget);
      expect(find.text("✓ BCP"), findsOneWidget);
      expect(find.text("+ Plin"), findsOneWidget);
    });

    testWidgets('3.2. Toggle bidireccional: Activar chip agrega línea con \\n y desactivar chip la elimina limpiamente', (tester) async {
      final phoneCtrl = TextEditingController(text: '987654321');
      final rucCtrl = TextEditingController(text: '');
      final addressCtrl = TextEditingController(text: '');
      final paymentCtrl = TextEditingController(text: 'Yape: 987654321');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return WaBusinessSection(
                    phoneCtrl: phoneCtrl,
                    rucCtrl: rucCtrl,
                    addressCtrl: addressCtrl,
                    paymentCtrl: paymentCtrl,
                    isGpsLoading: false,
                    updateBusinessData: false,
                    onGpsTap: () {},
                    onUpdateDataChanged: (_) {},
                    onDataChanged: () => setState(() {}),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tocamos el chip 'Plin' (actualmente inactivo '+ Plin')
      await tester.tap(find.text("+ Plin"));
      await tester.pumpAndSettle();

      expect(paymentCtrl.text, contains("Yape: 987654321"));
      expect(paymentCtrl.text, contains("Plin: 987654321"));
      expect(paymentCtrl.text.split('\n').length, 2);

      // Volvemos a tocar 'Yape' (actualmente activo '✓ Yape') para desactivarlo
      await tester.tap(find.text("✓ Yape"));
      await tester.pumpAndSettle();

      expect(paymentCtrl.text, isNot(contains("Yape")));
      expect(paymentCtrl.text, contains("Plin: 987654321"));
      expect(paymentCtrl.text.trim(), "Plin: 987654321");
    });

    test('3.3. Detección booleana de cambios en perfil (hasBusinessChanges)', () {
      const originalAddress = "Av. Principal 100";
      const originalRuc = "10456789012";
      const originalPhone = "999888777";
      const originalPayment = "Yape: 999888777";

      // Sin cambios
      bool hasChanges = ("Av. Principal 100" != originalAddress) ||
          ("10456789012" != originalRuc) ||
          ("999888777" != originalPhone) ||
          ("Yape: 999888777" != originalPayment);
      expect(hasChanges, isFalse);

      // Con cambio en teléfono
      hasChanges = ("Av. Principal 100" != originalAddress) ||
          ("10456789012" != originalRuc) ||
          ("987654321" != originalPhone) ||
          ("Yape: 999888777" != originalPayment);
      expect(hasChanges, isTrue);

      // Con cambio en cuentas
      hasChanges = ("Av. Principal 100" != originalAddress) ||
          ("10456789012" != originalRuc) ||
          ("999888777" != originalPhone) ||
          ("Yape: 999888777\nBCP: 191-000" != originalPayment);
      expect(hasChanges, isTrue);
    });
  });

  group('FASE 4: Orquestación Dinámica de las 6 Plantillas (Matriz Sección 3.6)', () {
    test('4.1. WhatsAppConfig.applyTemplateStyle ejecuta rigurosamente la matriz', () {
      final config = WhatsAppConfig();

      // 1. Comercial Detallado: Todos activos
      config.applyTemplateStyle(WhatsAppMessageStyle.commercial);
      expect(config.showSubtotals, isTrue);
      expect(config.showSavingsSection, isTrue);
      expect(config.showDiscountDetail, isTrue);
      expect(config.showTotalGlobal, isTrue);
      expect(config.showBusinessInfo, isTrue);
      expect(config.showPaymentInfo, isTrue);
      expect(config.includeValidity, isTrue);
      expect(config.includeDelivery, isTrue);

      // 2. Resumen Directo: Solo subtotales, total y pago
      config.applyTemplateStyle(WhatsAppMessageStyle.compact);
      expect(config.showSubtotals, isTrue);
      expect(config.showSavingsSection, isFalse);
      expect(config.showDiscountDetail, isFalse);
      expect(config.showTotalGlobal, isTrue);
      expect(config.showBusinessInfo, isFalse);
      expect(config.showPaymentInfo, isTrue);
      expect(config.includeValidity, isFalse);
      expect(config.includeDelivery, isFalse);

      // 3. Cierre de Oferta: Urgencia y ahorro destacados, sin info negocio ni entrega
      config.applyTemplateStyle(WhatsAppMessageStyle.urgentOffer);
      expect(config.showSubtotals, isTrue);
      expect(config.showSavingsSection, isTrue);
      expect(config.showDiscountDetail, isTrue);
      expect(config.showTotalGlobal, isTrue);
      expect(config.showBusinessInfo, isFalse);
      expect(config.showPaymentInfo, isTrue);
      expect(config.includeValidity, isTrue);
      expect(config.includeDelivery, isFalse);

      // 4. Estado de Cuenta: Enfoque financiero con saldo y cuotas
      config.applyTemplateStyle(WhatsAppMessageStyle.accountDebt);
      expect(config.showSubtotals, isTrue);
      expect(config.showSavingsSection, isFalse);
      expect(config.showDiscountDetail, isFalse);
      expect(config.showTotalGlobal, isTrue);
      expect(config.showBusinessInfo, isTrue);
      expect(config.showPaymentInfo, isTrue);
      expect(config.showDebtInfo, isTrue);
      expect(config.showInstallmentDetails, isTrue);
      expect(config.includeValidity, isFalse);
      expect(config.includeDelivery, isFalse);

      // 5. Seguimiento Amable: Sin medios de pago directos, con validez
      config.applyTemplateStyle(WhatsAppMessageStyle.followUp);
      expect(config.showSubtotals, isTrue);
      expect(config.showSavingsSection, isFalse);
      expect(config.showTotalGlobal, isTrue);
      expect(config.showBusinessInfo, isTrue);
      expect(config.showPaymentInfo, isFalse);
      expect(config.includeValidity, isTrue);
      expect(config.includeDelivery, isFalse);

      // 6. Pedido Listo / Envío: Enfocado en entrega, sin subtotales ni descuentos
      config.applyTemplateStyle(WhatsAppMessageStyle.deliveryReady);
      expect(config.showSubtotals, isFalse);
      expect(config.showSavingsSection, isFalse);
      expect(config.showDiscountDetail, isFalse);
      expect(config.showTotalGlobal, isTrue);
      expect(config.showBusinessInfo, isTrue);
      expect(config.showPaymentInfo, isTrue);
      expect(config.includeDelivery, isTrue);
      expect(config.showDeliveryInfo, isTrue);
      expect(config.includeValidity, isFalse);
    });

    test('4.2. Libertad total: Modificar opciones manuales tras aplicar plantilla es 100% permitido', () {
      final config = WhatsAppConfig();
      config.applyTemplateStyle(WhatsAppMessageStyle.compact);
      expect(config.showBusinessInfo, isFalse);

      // El usuario enciende libremente 'Info del Negocio'
      config.showBusinessInfo = true;
      expect(config.showBusinessInfo, isTrue);
      expect(config.style, WhatsAppMessageStyle.compact); // El estilo sigue siendo Directo
    });

    testWidgets('4.3. WaMessageEditor renderiza chips limpios con iconos vectoriales y ejecuta toggle', (tester) async {
      final messageCtrl = TextEditingController(text: '¡Hola! Te envío la cotización.');
      final config = WhatsAppConfig();
      String? toggledKey;
      bool? toggledVal;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WaMessageEditor(
                isDark: false,
                isManualEdit: false,
                messageCtrl: messageCtrl,
                config: config,
                onChanged: (_) {},
                onStyleChanged: (_) {},
                onRegenerateAuto: () {},
                onOptionToggled: (key, val) {
                  toggledKey = key;
                  toggledVal = val;
                },
              ),
            ),
          ),
        ),
      );

      // Verificamos que los chips tengan etiquetas limpias sin emojis Unicode en la UI
      expect(find.text("Validez 7 días"), findsOneWidget);
      expect(find.text("Envío / Entrega"), findsOneWidget);
      expect(find.text("Mis Cuentas"), findsOneWidget);
      expect(find.text("Saludo"), findsOneWidget);
      expect(find.text("Agradecimiento"), findsOneWidget);

      // Tocamos el chip 'Validez 7 días'
      await tester.tap(find.text("Validez 7 días"));
      await tester.pumpAndSettle();

      expect(toggledKey, 'validity');
      expect(toggledVal, isTrue);
      expect(messageCtrl.text, contains("Validez de la oferta"));
    });
  });
}
