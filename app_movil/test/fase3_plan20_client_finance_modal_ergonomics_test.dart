import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_finance_actions_modal.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ClientModel createTestClient({
    required int id,
    required String name,
    double saldoAFavor = 0.0,
    int score = 500, // Tier Plata
  }) {
    return ClientModel(
      id: id,
      negocioId: 1,
      creadoPorUsuarioId: 1,
      fullName: name,
      phone: '999888777',
      registeredDate: '2026-10-21',
      saldoAFavor: saldoAFavor,
      scoreReputacion: score,
    );
  }

  Widget buildTestableModal({
    required ClientModel client,
    int initialTab = 0,
    bool isDark = true,
    TextScaler textScaler = TextScaler.noScaling,
    Size size = const Size(800, 1200),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: textScaler,
        ),
        child: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => TrackingProvider()),
            ],
            child: ClientFinanceActionsModal(
              client: client,
              isDark: isDark,
              initialTab: initialTab,
            ),
          ),
        ),
      ),
    );
  }

  group('Fase 3: Reingeniería Ergonómica del Modal de Operaciones Financieras', () {
    testWidgets('1. Pestaña Otorgar Préstamo: Límite sugerido sin (Plata) ni tier y sin banner redundante', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = createTestClient(id: 1, name: 'Carlos Mendoza');

      await tester.pumpWidget(buildTestableModal(client: client, initialTab: 0));
      await tester.pumpAndSettle();

      // No debe contener denominaciones de metales ni tiers en los títulos
      expect(find.textContaining('(Plata)'), findsNothing);
      expect(find.textContaining('(Oro)'), findsNothing);
      expect(find.textContaining('(Bronce)'), findsNothing);

      // El banner marrón redundante fue removido
      expect(find.text('Registrar Préstamo o Venta al Fiado'), findsNothing);

      // Título limpio y directo
      expect(find.textContaining('Límite de Crédito Sugerido: S/ 350.00'), findsOneWidget);

      // Formulario visible inmediatamente
      expect(find.text('Monto del Préstamo'), findsOneWidget);
      expect(find.text('Efectivo'), findsWidgets);
      expect(find.text('Yape'), findsWidgets);
      expect(find.text('Plin'), findsWidgets);
      expect(find.text('Transferencia'), findsWidgets);
    });

    testWidgets('2. Pestaña Otorgar Préstamo: Tarjeta colapsable inicia compacta y se expande/contrae', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = createTestClient(id: 2, name: 'Ana Gómez');

      await tester.pumpWidget(buildTestableModal(client: client, initialTab: 0));
      await tester.pumpAndSettle();

      const toggleKey = ValueKey('loan_credit_limit_card_toggle');
      expect(find.byKey(toggleKey), findsOneWidget);

      // Estado inicial retraído: muestra "Detalles" y chevron down, pero NO el texto largo
      expect(find.text('Detalles'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
      expect(find.textContaining('Cliente sin historial de atrasos'), findsNothing);

      // Toque para expandir
      await tester.tap(find.byKey(toggleKey));
      await tester.pumpAndSettle();

      expect(find.text('Ocultar'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less_rounded), findsOneWidget);
      expect(find.textContaining('Cliente sin historial de atrasos'), findsOneWidget);

      // Toque para volver a contraer
      await tester.tap(find.byKey(toggleKey));
      await tester.pumpAndSettle();

      expect(find.text('Detalles'), findsOneWidget);
      expect(find.textContaining('Cliente sin historial de atrasos'), findsNothing);
    });

    testWidgets('3. Pestaña Retirar Saldo con S/ 0.00: Cero duplicación de Sin Saldo a Favor Disponible', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final clientSinSaldo = createTestClient(id: 3, name: 'Roberto Díaz', saldoAFavor: 0.0);

      await tester.pumpWidget(buildTestableModal(client: clientSinSaldo, initialTab: 1));
      await tester.pumpAndSettle();

      // Cero duplicación: aparece EXACTAMENTE 1 vez en todo el árbol de widgets
      expect(find.text('Sin Saldo a Favor Disponible'), findsOneWidget);
      expect(find.text('Saldo Disponible: S/ 0.00'), findsOneWidget);
      // Alcancía educativa central (size 40)
      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.savings_outlined && w.size == 40),
        findsOneWidget,
      );
      expect(find.textContaining('El saldo a favor se genera automáticamente'), findsOneWidget);

      // Botón inferior presente y deshabilitado
      final btnFinder = find.widgetWithText(ElevatedButton, 'Confirmar Retiro');
      expect(btnFinder, findsOneWidget);
      final ElevatedButton btn = tester.widget(btnFinder);
      expect(btn.onPressed, isNull);
    });

    testWidgets('4. Pestaña Retirar Saldo con saldo > 0: Tarjeta contextual colapsable y formulario limpio', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final clientConSaldo = createTestClient(id: 4, name: 'Lucía Torres', saldoAFavor: 120.0);

      await tester.pumpWidget(buildTestableModal(client: clientConSaldo, initialTab: 1));
      await tester.pumpAndSettle();

      const toggleKey = ValueKey('withdraw_balance_card_toggle');
      expect(find.byKey(toggleKey), findsOneWidget);

      // Inicia colapsada mostrando el saldo pero no el detalle
      expect(find.textContaining('Saldo a Favor Disponible: S/ 120.00'), findsOneWidget);
      expect(find.text('Detalles'), findsOneWidget);
      expect(find.textContaining('Puedes registrar el desembolso total o parcial'), findsNothing);

      // Toque para expandir
      await tester.tap(find.byKey(toggleKey));
      await tester.pumpAndSettle();

      expect(find.text('Ocultar'), findsOneWidget);
      expect(find.textContaining('Puedes registrar el desembolso total o parcial'), findsOneWidget);

      // Formulario de retiro libre y accesible
      expect(find.text('Retirar Todo (S/ 120.00)'), findsOneWidget);
      expect(find.text('Retirar 50%'), findsOneWidget);
      expect(find.text('Monto a Retirar'), findsOneWidget);
    });

    testWidgets('5. Contenedor de botón inferior sin franja muerta (respiro ergonómico de 12dp)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = createTestClient(id: 5, name: 'Elena Ramos');

      await tester.pumpWidget(buildTestableModal(client: client, initialTab: 0));
      await tester.pumpAndSettle();

      // Ubicar el contenedor del botón inferior
      final btn = find.widgetWithText(ElevatedButton, 'Registrar Préstamo');
      expect(btn, findsOneWidget);

      final containerFinder = find.ancestor(
        of: btn,
        matching: find.byType(Container),
      ).first;

      final Container container = tester.widget(containerFinder);
      final padding = container.padding as EdgeInsets?;
      expect(padding, isNotNull);
      // No debe sumar 28dp de minPadding ni 48dp de SafeArea duplicado
      expect(padding!.bottom, lessThanOrEqualTo(16.0));
      expect(padding.bottom, greaterThanOrEqualTo(10.0));
    });

    testWidgets('6. Responsividad 0px Overflow a 1.3x en 320x568dp, 360x640dp y 412x915dp', (tester) async {
      final client = createTestClient(id: 6, name: 'Marcos Soto', saldoAFavor: 85.0);
      final resolutions = [
        const Size(320.0, 568.0),
        const Size(360.0, 640.0),
        const Size(412.0, 915.0),
      ];

      for (final res in resolutions) {
        tester.view.physicalSize = res;
        tester.view.devicePixelRatio = 1.0;

        // Probar Tab 0 (Préstamo)
        await tester.pumpWidget(buildTestableModal(
          client: client,
          initialTab: 0,
          size: res,
          textScaler: const TextScaler.linear(1.3),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow en Préstamo a ${res.width}x${res.height}');

        // Probar Tab 1 (Retiro con saldo)
        await tester.pumpWidget(buildTestableModal(
          client: client,
          initialTab: 1,
          size: res,
          textScaler: const TextScaler.linear(1.3),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow en Retiro con saldo a ${res.width}x${res.height}');
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('7. Cero emojis crudos en la interfaz del modal', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = createTestClient(id: 7, name: 'Pedro Morales', saldoAFavor: 50.0);

      await tester.pumpWidget(buildTestableModal(client: client, initialTab: 0));
      await tester.pumpAndSettle();

      final emojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true);
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final textWidget in textWidgets) {
        final content = textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
        expect(emojiRegex.hasMatch(content), isFalse, reason: 'Emoji crudo detectado: "$content"');
      }
    });
  });
}
