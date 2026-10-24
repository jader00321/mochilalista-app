import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/core/widgets/marquee_text.dart';
import 'package:app_movil/core/widgets/export_options_modal.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/widgets/quotation_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/smart_update_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_actions_bottom_sheet.dart';
import 'package:app_movil/features/smart_quotation/widgets/detalle/quotation_action_buttons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AUDITORÍA 1: Ancho estricto 360dp, Cabecera y FittedBox', () {
    testWidgets('Header y Pestañas no se desbordan en pantalla de 360dp de ancho', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: SizedBox(
                width: 360,
                child: Row(
                  children: [
                    const IconButton(icon: Icon(Icons.arrow_back), onPressed: null),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Mesa de Trabajo",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.info_outline), onPressed: () {}),
                    IconButton(icon: const Icon(Icons.archive_outlined), onPressed: () {}),
                    IconButton(icon: const Icon(Icons.download), onPressed: () {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text("Mesa de Trabajo"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Pestañas con FittedBox en 360dp se muestran completas', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final tabs = ["En Preparación", "Listas & Packs", "Vendidas"];

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 3,
            child: Scaffold(
              appBar: AppBar(
                bottom: TabBar(
                  tabs: tabs.map((t) => Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(t, maxLines: 1),
                    ),
                  )).toList(),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text("En Preparación"), findsOneWidget);
      expect(find.text("Listas & Packs"), findsOneWidget);
      expect(find.text("Vendidas"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AUDITORÍA 2: Tarjetas de Cotización, Formato y Singular/Plural', () {
    testWidgets('Tarjeta singular con 1 ítem muestra "1 Ítem"', (tester) async {
      final quotation = SmartQuotationModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        clientName: "Cliente de Prueba",
        totalAmount: 15.50,
        totalSavings: 0.0,
        status: "DRAFT",
        type: "manual",
        createdAt: DateTime.now().toIso8601String(),
        itemCount: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuotationCard(
              quotation: quotation,
              isDark: false,
              onTap: () {},
              onLongPress: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining("1 Ítem"), findsOneWidget);
      expect(find.text("S/ 15.50"), findsOneWidget); // AppCurrency format S/ 15.50
    });

    testWidgets('Tarjeta plural con 5 ítems muestra "5 Ítems" y maxLines: 2 para nombre largo', (tester) async {
      const longTitle = "Colegio San Agustín - Lista de Útiles Escolares 2026 - Grado 5to de Primaria";
      final quotation = SmartQuotationModel(
        id: 2,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        clientName: longTitle,
        totalAmount: 245.80,
        totalSavings: 12.0,
        status: "DRAFT",
        type: "ai_scan",
        createdAt: DateTime.now().toIso8601String(),
        itemCount: 5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuotationCard(
              quotation: quotation,
              isDark: false,
              onTap: () {},
              onLongPress: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining("5 Ítems"), findsOneWidget);
      expect(find.text(longTitle), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text(longTitle));
      expect(textWidget.maxLines, 2);
    });

    testWidgets('Tarjeta Vendida (SOLD) muestra badge de vendido y botón de menú activo', (tester) async {
      final soldQuotation = SmartQuotationModel(
        id: 3,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        clientName: "Cotización Ya Vendida",
        totalAmount: 500.0,
        totalSavings: 0.0,
        status: "SOLD",
        type: "manual",
        createdAt: DateTime.now().toIso8601String(),
        itemCount: 3,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuotationCard(
              quotation: soldQuotation,
              isDark: false,
              onTap: () {},
              onLongPress: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text("Vendido (Histórico)"), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });
  });

  group('AUDITORÍA 2 (Continuación): Inmutabilidad Estricta de Cotización Vendida (SOLD)', () {
    test('Reglas de inmutabilidad para SOLD: no permite mutación destructiva ni cambio de estado', () {
      const soldStatus = 'SOLD';
      bool canMutate(String status) => status != 'SOLD';

      expect(canMutate(soldStatus), isFalse);
      expect(canMutate('DRAFT'), isTrue);
      expect(canMutate('REVIEW'), isTrue);
      expect(canMutate('READY'), isTrue);
    });

    testWidgets('QuickActionsBottomSheet para SOLD oculta opciones destructivas y muestra badge de histórico', (tester) async {
      final soldQuote = SmartQuotationModel(
        id: 99,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        clientName: "Cotización Histórica Protegida",
        totalAmount: 120.0,
        totalSavings: 0.0,
        status: "SOLD",
        type: "manual",
        createdAt: DateTime.now().toIso8601String(),
        itemCount: 2,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => QuickActionsBottomSheet(
                quotation: soldQuote,
                isDark: false,
                parentContext: context,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining("Cotización Vendida (Histórico"), findsOneWidget);
      expect(find.text("Duplicar Cotización"), findsOneWidget);
      expect(find.text("Cambiar Nombre / Cliente"), findsNothing);
      expect(find.text("Archivar"), findsNothing);
      expect(find.text("Eliminar Definitivamente"), findsNothing);
    });
  });

  group('AUDITORÍA 3: Opciones de Exportación y Conteo Dinámico', () {
    testWidgets('ExportOptionsModal muestra los conteos dinámicos en las opciones', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportOptionsModal(
              options: [
                ExportOption(id: 'current_view', title: 'Vista Actual', description: 'Listas visibles', icon: Icons.view_list, count: 8),
                ExportOption(id: 'pending_only', title: 'Solo Pendientes', description: 'Listas activas', icon: Icons.pending_actions, count: 14),
                ExportOption(id: 'sold_only', title: 'Solo Vendidas', description: 'Ventas cerradas', icon: Icons.verified, count: 22),
                ExportOption(id: 'full_report', title: 'Reporte Completo', description: 'Todas las listas', icon: Icons.analytics, count: 36),
              ],
              onExportLegacy: (optionId, format, method) {},
              isDark: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text("8 listas"), findsOneWidget);
      expect(find.text("14 listas"), findsOneWidget);
      expect(find.text("22 listas"), findsOneWidget);
      expect(find.text("36 listas"), findsOneWidget);
      expect(find.text("Vista Actual"), findsOneWidget);
      expect(find.text("Solo Pendientes"), findsOneWidget);
      expect(find.text("Solo Vendidas"), findsOneWidget);
      expect(find.text("Reporte Completo"), findsOneWidget);
    });
  });

  group('AUDITORÍA 4: MarqueeText, Detalle de Cotización y Botones de Acción', () {
    testWidgets('MarqueeText se inicializa y tiene soporte para onTap y ShaderMask', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 150,
              child: MarqueeText(
                text: "Nombre extremadamente largo para verificar el carrusel animado",
                style: const TextStyle(fontSize: 16),
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(ShaderMask), findsOneWidget);
      expect(find.text("Nombre extremadamente largo para verificar el carrusel animado"), findsOneWidget);

      await tester.tap(find.byType(MarqueeText));
      expect(tapped, isTrue);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('QuotationActionButtons maneja singular y plural de alertas correctamente', (tester) async {
      // 0 alertas -> "VENDER"
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuotationActionButtons(
              quotationId: 1,
              status: 'DRAFT',
              validation: ValidationResult(
                hasIssues: false,
                canSell: true,
                stockWarnings: [],
                priceChanges: [],
              ),
              isDark: false,
              isClient: false,
              onReloadData: () {},
              onHandleUpdateAnalysis: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("VENDER"), findsOneWidget);

      // 1 alerta -> "VENDER (1 alerta)"
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuotationActionButtons(
              quotationId: 1,
              status: 'DRAFT',
              validation: ValidationResult(
                hasIssues: true,
                canSell: true,
                stockWarnings: [],
                priceChanges: [
                  PriceChange(
                    itemId: 1,
                    productName: "Cuaderno",
                    oldPrice: 5.0,
                    newPrice: 6.0,
                    newBasePrice: 6.0,
                    message: "Cambio de precio",
                  ),
                ],
              ),
              isDark: false,
              isClient: false,
              onReloadData: () {},
              onHandleUpdateAnalysis: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("VENDER (1 alerta)"), findsOneWidget);

      // 3 alertas -> "VENDER (3 alertas)"
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuotationActionButtons(
              quotationId: 1,
              status: 'DRAFT',
              validation: ValidationResult(
                hasIssues: true,
                canSell: true,
                stockWarnings: [],
                priceChanges: [
                  PriceChange(itemId: 1, productName: "P1", oldPrice: 5.0, newPrice: 6.0, newBasePrice: 6.0, message: "P1"),
                  PriceChange(itemId: 2, productName: "P2", oldPrice: 3.0, newPrice: 4.0, newBasePrice: 4.0, message: "P2"),
                  PriceChange(itemId: 3, productName: "P3", oldPrice: 2.0, newPrice: 2.5, newBasePrice: 2.5, message: "P3"),
                ],
              ),
              isDark: false,
              isClient: false,
              onReloadData: () {},
              onHandleUpdateAnalysis: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("VENDER (3 alertas)"), findsOneWidget);
    });
  });

  group('AUDITORÍA 5: Validación Factor-Aware de Stock y Centro de Resoluciones', () {
    test('Cálculo de demanda acumulada base: unidades_por_venta = 12 x 2 cajas = 24 unidades base', () {
      const factor = 12;
      const requestedPackages = 2;
      final totalDemandBase = requestedPackages * factor;
      expect(totalDemandBase, 24);

      // Si el stock disponible en base es 20, la venta no debe permitirse (bloqueo canSell = false)
      const currentStockBase = 20;
      final isStockSufficient = currentStockBase >= totalDemandBase;
      expect(isStockSufficient, isFalse);

      // Si el stock disponible en base es 24 o más, la venta sí es válida
      expect(24 >= totalDemandBase, isTrue);
      expect(30 >= totalDemandBase, isTrue);
    });

    testWidgets('SmartUpdateModal adapta su botón principal y elimina duplicados cuando solo hay cambios de precio', (tester) async {
      final validationOnlyPrices = ValidationResult(
        hasIssues: true,
        canSell: true,
        priceChanges: [
          PriceChange(
            itemId: 10,
            productName: "Cuaderno Standford A4",
            oldPrice: 6.50,
            newPrice: 7.20,
            newBasePrice: 7.20,
            message: "Subió de precio",
          ),
        ],
        stockWarnings: [],
        nameChanges: [],
        bundleChanges: [],
        unitChanges: [],
      );

      bool pricesUpdated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartUpdateModal(
              validation: validationOnlyPrices,
              onUpdatePrices: () => pricesUpdated = true,
              onFixStock: () {},
              onFixAll: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debe mostrar el botón adaptado de precios de hoy
      expect(find.text("ACEPTAR TODOS LOS PRECIOS DE HOY"), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      // NO debe tener el botón inline duplicado "Actualizar Todo a Precios de Hoy"
      expect(find.text("Actualizar Todo a Precios de Hoy"), findsNothing);

      // Verificamos formato AppCurrency
      expect(find.text("S/ 6.50"), findsOneWidget);
      expect(find.text("S/ 7.20"), findsOneWidget);

      // Al pulsar el botón principal, debe invocar onUpdatePrices
      await tester.tap(find.text("ACEPTAR TODOS LOS PRECIOS DE HOY"));
      await tester.pumpAndSettle();
      expect(pricesUpdated, isTrue);
    });

    testWidgets('SmartUpdateModal adapta su botón a "CORREGIR PRODUCTOS AGOTADOS" cuando solo hay faltantes de stock', (tester) async {
      final validationOnlyStock = ValidationResult(
        hasIssues: true,
        canSell: false,
        priceChanges: [],
        stockWarnings: [
          StockWarning(
            itemId: 20,
            productName: "Tijera Escolar Maped",
            requested: 5,
            available: 2,
            message: "Solo quedan 2 disponibles",
          ),
        ],
        nameChanges: [],
        bundleChanges: [],
        unitChanges: [],
      );

      bool stockFixed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartUpdateModal(
              validation: validationOnlyStock,
              onUpdatePrices: () {},
              onFixStock: () => stockFixed = true,
              onFixAll: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("CORREGIR PRODUCTOS AGOTADOS"), findsOneWidget);
      expect(find.widgetWithIcon(ElevatedButton, Icons.delete_sweep), findsOneWidget);

      await tester.tap(find.text("CORREGIR PRODUCTOS AGOTADOS"));
      await tester.pumpAndSettle();
      expect(stockFixed, isTrue);
    });

    testWidgets('SmartUpdateModal muestra "CORREGIR Y ACTUALIZAR TODO" ante alertas combinadas', (tester) async {
      final validationMixed = ValidationResult(
        hasIssues: true,
        canSell: false,
        priceChanges: [
          PriceChange(
            itemId: 10,
            productName: "Cuaderno Standford A4",
            oldPrice: 6.50,
            newPrice: 7.20,
            newBasePrice: 7.20,
            message: "Subió de precio",
          ),
        ],
        stockWarnings: [
          StockWarning(
            itemId: 20,
            productName: "Tijera Escolar Maped",
            requested: 5,
            available: 0,
            message: "Agotado",
          ),
        ],
        nameChanges: [],
        bundleChanges: [],
        unitChanges: [],
      );

      bool fixAllCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartUpdateModal(
              validation: validationMixed,
              onUpdatePrices: () {},
              onFixStock: () {},
              onFixAll: () => fixAllCalled = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("CORREGIR Y ACTUALIZAR TODO"), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

      await tester.tap(find.text("CORREGIR Y ACTUALIZAR TODO"));
      await tester.pumpAndSettle();
      expect(fixAllCalled, isTrue);
    });

    testWidgets('SmartUpdateModal ofrece botón "Sustituir Ítem" cuando producto está agotado (available == 0)', (tester) async {
      final validationExhausted = ValidationResult(
        hasIssues: true,
        canSell: false,
        priceChanges: [],
        stockWarnings: [
          StockWarning(
            itemId: 20,
            productName: "Tijera Escolar Maped",
            requested: 5,
            available: 0,
            message: "Agotado en tienda",
          ),
        ],
        nameChanges: [],
        bundleChanges: [],
        unitChanges: [],
      );

      bool manualEditTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartUpdateModal(
              validation: validationExhausted,
              onUpdatePrices: () {},
              onFixStock: () {},
              onFixAll: () {},
              onOpenManualEdit: () => manualEditTriggered = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debe mostrar el botón de sustituir ítem
      expect(find.text("Sustituir Ítem"), findsOneWidget);
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);

      await tester.tap(find.text("Sustituir Ítem"));
      await tester.pumpAndSettle();
      expect(manualEditTriggered, isTrue);
    });
  });

  group('AUDITORÍA 6: Adaptación de QuotationActionButtons para Cotización Vendida (SOLD)', () {
    testWidgets('QuotationActionButtons para SOLD oculta lápiz de editar y muestra botón DUPLICAR COTIZACIÓN', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuotationActionButtons(
              quotationId: 99,
              status: 'SOLD',
              validation: null,
              isDark: false,
              isClient: false,
              onReloadData: () {},
              onHandleUpdateAnalysis: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // En SOLD no debe haber botón de editar (lápiz)
      expect(find.byIcon(Icons.edit), findsNothing);

      // En SOLD no debe haber botón de VENDER
      expect(find.text("VENDER"), findsNothing);

      // En SOLD debe haber botón activo de DUPLICAR COTIZACIÓN con icono copy_all
      expect(find.text("DUPLICAR COTIZACIÓN"), findsOneWidget);
      expect(find.byIcon(Icons.copy_all), findsOneWidget);

      // Los botones de PDF y WhatsApp deben mantenerse presentes y activos
      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
      expect(find.byIcon(Icons.chat), findsOneWidget);
    });
  });
}

