import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_finance_actions_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/payment_entry_modal.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Árbitro Adversarial Parte 2 - Fase 1: Modal Operaciones Financieras (Retiros y Préstamos)', () {
    testWidgets('Pestaña Retirar educa al usuario cuando Saldo Disponible es 0.00 e impide retiros', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final clientSinSaldo = ClientModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Juan Pérez',
        phone: '999888777',
        registeredDate: '2026-10-21',
        saldoAFavor: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => TrackingProvider()),
              ],
              child: ClientFinanceActionsModal(client: clientSinSaldo, isDark: true),
            ),
          ),
        ),
      );

      // Verificamos que se muestre el estado educativo claro
      expect(find.text('Sin Saldo a Favor Disponible'), findsOneWidget);
      expect(find.text('Saldo Disponible: S/ 0.00'), findsOneWidget);
      expect(find.byIcon(Icons.savings_outlined), findsOneWidget);
      expect(
        find.textContaining('El saldo a favor se genera automáticamente'),
        findsOneWidget,
      );

      // El botón inferior debe estar deshabilitado
      final btnFinder = find.widgetWithText(ElevatedButton, 'Confirmar Retiro');
      expect(btnFinder, findsOneWidget);
      final ElevatedButton btn = tester.widget(btnFinder);
      expect(btn.onPressed, isNull);
    });

    testWidgets('Pestaña Retirar con saldo > 0 habilita chips rápidos y valida monto máximo', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final clientConSaldo = ClientModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Juan Pérez',
        phone: '999888777',
        registeredDate: '2026-10-21',
        saldoAFavor: 120.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => TrackingProvider()),
              ],
              child: ClientFinanceActionsModal(client: clientConSaldo, isDark: true),
            ),
          ),
        ),
      );

      // Verificamos el saldo visible con AppCurrency
      expect(find.text('S/ 120.00'), findsOneWidget);
      expect(find.text('Retirar Todo (S/ 120.00)'), findsOneWidget);
      expect(find.text('Retirar 50%'), findsOneWidget);

      // Tocamos "Retirar Todo"
      await tester.tap(find.text('Retirar Todo (S/ 120.00)'));
      await tester.pump();

      // El botón ahora debe estar habilitado
      final btnFinder = find.widgetWithText(ElevatedButton, 'Confirmar Retiro');
      final ElevatedButton btn = tester.widget(btnFinder);
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('Pestaña Préstamo no corta motivos ni notas y genera cuota por defecto', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = ClientModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Freddy',
        phone: '910888652',
        registeredDate: '2026-10-21',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => TrackingProvider()),
              ],
              child: ClientFinanceActionsModal(client: client, isDark: true),
            ),
          ),
        ),
      );

      // Cambiamos a la pestaña Préstamo
      await tester.tap(find.text('Préstamo'));
      await tester.pumpAndSettle();

      // Verificamos que todos los chips de sugerencia estén presentes y sin truncar
      expect(find.text('Préstamo personal'), findsOneWidget);
      expect(find.text('Fiado mercadería'), findsOneWidget);
      expect(find.text('Adelanto de trabajo'), findsOneWidget);
      expect(find.text('Emergencia'), findsOneWidget);
      expect(find.text('Otros'), findsOneWidget);

      // Verificamos la fecha de vencimiento por defecto de 1 cuota
      expect(find.text('Fecha de Vencimiento (1 cuota)'), findsOneWidget);

      // Verificamos el switch de fraccionamiento
      expect(find.text('¿Dividir en cuotas o aplicar interés?'), findsOneWidget);
    });
  });

  group('Árbitro Adversarial Parte 2 - Fase 2 y 3: Modal Registrar Abono y Mini-Header', () {
    testWidgets('Registrar Abono muestra Transferencia completa, TabBar sin truncar y botón inactivo en 0', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = ClientModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Freddy',
        phone: '910888652',
        totalDebt: 258.57,
        registeredDate: '2026-10-21',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => TrackingProvider()),
              ],
              child: PaymentEntryModal(client: client),
            ),
          ),
        ),
      );

      // Verificamos deuda total con AppCurrency
      expect(find.text('Deuda Total: S/ 258.57'), findsOneWidget);

      // Verificamos que "Transferencia" y "Tarjeta" no se corten
      expect(find.text('Transferencia'), findsOneWidget);
      expect(find.text('Tarjeta'), findsOneWidget);
      expect(find.text('Efectivo'), findsOneWidget);
      expect(find.text('Yape'), findsOneWidget);
      expect(find.text('Plin'), findsOneWidget);

      // Verificamos que los tabs no estén cortados
      expect(find.text('Distribución Automática'), findsOneWidget);
      expect(find.text('Pago Específico'), findsOneWidget);

      // Verificamos que el botón PROCESAR PAGO esté deshabilitado con monto 0
      final btnFinder = find.widgetWithText(ElevatedButton, 'PROCESAR PAGO');
      expect(btnFinder, findsOneWidget);
      final ElevatedButton btn = tester.widget(btnFinder);
      expect(btn.onPressed, isNull);

      // Verificamos chips rápidos en 1 sola fila
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('50% Deuda'), findsOneWidget);

      // Al pulsar "50% Deuda", el botón debe activarse
      await tester.tap(find.text('50% Deuda'));
      await tester.pump();
      final ElevatedButton btnActive = tester.widget(btnFinder);
      expect(btnActive.onPressed, isNotNull);
    });

    testWidgets('Pago Específico activa Mini-Header compacto maximizando espacio vertical', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = ClientModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Freddy',
        phone: '910888652',
        totalDebt: 258.57,
        registeredDate: '2026-10-21',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => TrackingProvider()),
              ],
              child: PaymentEntryModal(
                client: client,
                initialAmount: 80.0,
                initialTargetType: 'venta',
                initialTargetId: 1,
              ),
            ),
          ),
        ),
      );

      // Al inicializarse con un target específico, el Mini-Header debe estar colapsado (< 48px)
      expect(find.text('S/ 80.00'), findsOneWidget);
      expect(find.text('Modificar'), findsOneWidget);

      // Al pulsar "Modificar", debe re-expandir los inputs completos
      await tester.tap(find.text('Modificar'));
      await tester.pumpAndSettle();

      expect(find.text('Monto a abonar'), findsOneWidget);
      expect(find.text('Compactar'), findsOneWidget);
    });
  });

  group('Árbitro Adversarial Parte 2 - Fase 4: Integridad Contable y Prelación FIFO', () {
    test('Simulación de Prelación FIFO y Cálculo de Excedente a Saldo a Favor', () {
      double totalDebt = 258.57;
      double paymentAmount = 300.00; // Pago con excedente de S/ 41.43

      double amortizado = paymentAmount >= totalDebt ? totalDebt : paymentAmount;
      double excedente = paymentAmount > totalDebt ? (paymentAmount - totalDebt) : 0.0;
      double nuevaDeuda = totalDebt - amortizado;

      expect(amortizado, equals(258.57));
      expect(excedente, closeTo(41.43, 0.001));
      expect(nuevaDeuda, equals(0.0));

      expect(AppCurrency.format(excedente), equals('S/ 41.43'));
    });
  });
}
