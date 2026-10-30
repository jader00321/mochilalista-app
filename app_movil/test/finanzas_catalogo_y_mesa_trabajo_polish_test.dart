import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/catalog_header.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/features/catalog/screens/catalog/widgets/catalog_sort_modal.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/services/quotation_service.dart';
import 'package:app_movil/features/smart_quotation/services/matching_service.dart';
import 'package:app_movil/features/smart_quotation/widgets/quotation_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/detalle/quotation_action_buttons.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_finance_actions_modal.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es', null);
  });

  group('FASE 1: Operaciones Financieras & InteractiveSheetWrapper', () {
    testWidgets('InteractiveSheetWrapper admite enableHeaderDragToDismiss con handle y título', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveSheetWrapper(
              title: "Operaciones Financieras",
              showHandle: true,
              showCloseButton: true,
              enableHeaderDragToDismiss: true,
              child: const SizedBox(
                height: 300,
                child: Text("Contenido Financiero"),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text("Operaciones Financieras"), findsOneWidget);
      expect(find.text("Contenido Financiero"), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('Motivos sugeridos se disponen en SingleChildScrollView horizontal con BouncingScrollPhysics', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = ClientModel(
        id: 99,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: "Carlos Mendoza",
        phone: "987654321",
        registeredDate: "2026-10-01",
        saldoAFavor: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TrackingProvider>.value(
            value: TrackingProvider(),
            child: Scaffold(
              body: ClientFinanceActionsModal(
                client: client,
                isDark: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Cambiamos a la pestaña Préstamo (donde están los motivos)
      await tester.tap(find.text("Préstamo"));
      await tester.pumpAndSettle();

      // Buscamos SingleChildScrollView horizontal
      final horizontalScrollFinder = find.byWidgetPredicate(
        (widget) => widget is SingleChildScrollView &&
                    widget.scrollDirection == Axis.horizontal &&
                    widget.physics is BouncingScrollPhysics,
      );
      expect(horizontalScrollFinder, findsOneWidget);

      // Verificamos presencia de los motivos reales
      expect(find.text("Préstamo personal"), findsOneWidget);
      expect(find.text("Fiado mercadería"), findsOneWidget);
      expect(find.text("Adelanto de trabajo"), findsOneWidget);
      expect(find.text("Emergencia"), findsOneWidget);
      expect(find.text("Otros"), findsOneWidget);
    });

    testWidgets('Toggle deselect: presionar chip seleccionado lo desmarca y limpia el TextField', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = ClientModel(
        id: 99,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: "Carlos Mendoza",
        phone: "987654321",
        registeredDate: "2026-10-01",
        saldoAFavor: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TrackingProvider>.value(
            value: TrackingProvider(),
            child: Scaffold(
              body: ClientFinanceActionsModal(
                client: client,
                isDark: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Cambiamos a la pestaña Préstamo
      await tester.tap(find.text("Préstamo"));
      await tester.pumpAndSettle();

      // Aseguramos visibilidad del chip
      final chipFinder = find.widgetWithText(ChoiceChip, "Fiado mercadería");
      await tester.ensureVisible(chipFinder);
      await tester.pumpAndSettle();

      // 1. Tocar chip "Fiado mercadería"
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      // Verificar que el TextField tiene el texto del chip
      expect(find.text("Fiado mercadería"), findsWidgets);

      // 2. Volver a tocar el chip para desmarcarlo (toggle deselect)
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      // El TextField debe estar vacío ahora
      final textFieldFinder = find.byWidgetPredicate(
        (widget) => widget is TextField && (widget.decoration?.hintText?.contains("Préstamo personal") ?? false),
      );
      expect(textFieldFinder, findsOneWidget);
      final TextField field = tester.widget(textFieldFinder);
      expect(field.controller?.text, "");
    });

    testWidgets('Días de Cobro no contiene texto naranja "activos" y los presets no tienen emojis', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = ClientModel(
        id: 99,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: "Carlos Mendoza",
        phone: "987654321",
        registeredDate: "2026-10-01",
        saldoAFavor: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TrackingProvider>.value(
            value: TrackingProvider(),
            child: Scaffold(
              body: ClientFinanceActionsModal(
                client: client,
                isDark: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Cambiamos a la pestaña Préstamo
      await tester.tap(find.text("Préstamo"));
      await tester.pumpAndSettle();

      // Activar división en cuotas
      final switchFinder = find.byType(SwitchListTile);
      if (switchFinder.evaluate().isNotEmpty) {
        await tester.ensureVisible(switchFinder);
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();
      }

      // Verificar que el texto "${7 - _excludedWeekdays.length} activos" fue eliminado
      expect(find.textContaining("activos"), findsNothing);

      // Verificar que los chips de preset no contienen emojis
      expect(find.textContaining("🚫"), findsNothing);
      expect(find.textContaining("💼"), findsNothing);
      expect(find.textContaining("📅"), findsNothing);
      expect(find.textContaining("✨"), findsNothing);

      // Asegurar visibilidad de los presets
      final presetOmitir = find.text("Omitir Domingos");
      await tester.ensureVisible(presetOmitir);
      await tester.pumpAndSettle();

      // Verificar nombres limpios de los presets
      expect(presetOmitir, findsOneWidget);
      expect(find.text("Solo Lun - Vie"), findsOneWidget);
      expect(find.text("Todos los días"), findsOneWidget);
    });
  });

  group('FASE 2: Catálogo de Ventas & Modo Tienda', () {
    testWidgets('CatalogHeader no incluye botón de ordenar redundante en fila del buscador', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CatalogProvider>.value(
            value: CatalogProvider(),
            child: Scaffold(
              body: CatalogHeader(
                onFilterTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // El buscador está presente
      expect(find.byType(TextField), findsOneWidget);
      // NO hay ningún botón IconButton con IconData de sort en el Header del buscador
      final sortIcons = find.byWidgetPredicate(
        (w) => w is Icon && (w.icon == Icons.sort || w.icon == Icons.filter_list),
      );
      expect(sortIcons, findsNothing);
    });

    testWidgets('CatalogSortModal no contiene emojis de texto y usa iconos vectoriales', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogSortModal(
              provider: CatalogProvider(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ningún emoji en las opciones
      expect(find.textContaining("🔤"), findsNothing);
      expect(find.textContaining("💰"), findsNothing);
      expect(find.textContaining("📦"), findsNothing);
      expect(find.textContaining("🔥"), findsNothing);

      // Opciones presentes con texto limpio
      expect(find.text("Nombre (A - Z)"), findsOneWidget);
      expect(find.text("Nombre (Z - A)"), findsOneWidget);
      expect(find.text("Precio: Menor a Mayor"), findsOneWidget);
      expect(find.text("Precio: Mayor a Menor"), findsOneWidget);
    });
  });

  group('FASE 3: Mesa de Trabajo & Blindaje Forense', () {
    test('QuotationService.saveManualQuotation lanza ArgumentError con lista de items vacía', () async {
      expect(
        () => QuotationService().saveManualQuotation(
          negocioId: 1,
          usuarioId: 1,
          clientName: "Cliente Fantasma",
          items: [],
          totalAmount: 0.0,
          totalSavings: 0.0,
          type: "manual",
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('MatchingService.saveQuotation lanza ArgumentError con lista de items vacía', () async {
      expect(
        () => MatchingService().saveQuotation(
          {'items': []},
          1,
          1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    testWidgets('QuotationActionButtons NO incluye botón de eliminar en la barra inferior (Seguridad UX)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuotationActionButtons(
              quotationId: 10,
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

      // La barra inferior contiene VENDER y acciones rápidas
      expect(find.text("VENDER"), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
      expect(find.byIcon(Icons.chat), findsOneWidget);

      // NO contiene botón de eliminar
      expect(find.textContaining("Eliminar"), findsNothing);
      expect(find.textContaining("Borrar"), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('QuotationCard muestra Icons.note_alt_outlined en lugar de Icons.push_pin', (tester) async {
      final quotationWithNotes = SmartQuotationModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        clientName: "Colegio San Martín",
        status: 'READY',
        totalAmount: 180.0,
        itemCount: 5,
        totalSavings: 15.0,
        notas: "Entregar empaquetado por alumno con etiqueta",
        createdAt: DateTime.now().toIso8601String(),
        type: 'manual',
        items: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuotationCard(
              quotation: quotationWithNotes,
              isDark: false,
              onTap: () {},
              onLongPress: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debe tener el icono note_alt_outlined
      expect(find.byIcon(Icons.note_alt_outlined), findsOneWidget);
      // NO debe tener el icono push_pin
      expect(find.byIcon(Icons.push_pin), findsNothing);
    });
  });
}
