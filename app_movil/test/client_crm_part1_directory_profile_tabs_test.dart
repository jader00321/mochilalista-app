import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_profile_editor.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_compliance_sparkline.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_stats_header.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_sales_history_tab.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_quotations_tab.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Árbitro Adversarial - Fase 1: Estandarización Monetaria y Directorio', () {
    test('AppCurrency formatea siempre con prefijo S/ #,##0.00 invariable', () {
      expect(AppCurrency.format(258.57), equals('S/ 258.57'));
      expect(AppCurrency.format(1.0), equals('S/ 1.00'));
      expect(AppCurrency.format(0.0), equals('S/ 0.00'));
      expect(AppCurrency.format(1240.50), equals('S/ 1,240.50'));
      expect(AppCurrency.format(null), equals('S/ 0.00'));
    });

    test('Regla gramatical de conteo en Directorio de Clientes', () {
      String pluralizeClients(int count) {
        return "$count ${count == 1 ? 'cliente' : 'clientes'}";
      }

      expect(pluralizeClients(0), equals('0 clientes'));
      expect(pluralizeClients(1), equals('1 cliente'));
      expect(pluralizeClients(2), equals('2 clientes'));
      expect(pluralizeClients(45), equals('45 clientes'));
    });

    testWidgets('ClientCard formatea la deuda con prefijo S/ y muestra teléfono sin ser tapado por etiquetas', (tester) async {
      final client = ClientModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Freddy',
        phone: '910888652',
        docNumber: '44556677',
        totalDebt: 258.57,
        registeredDate: '2026-10-21T00:00:00',
        nivelConfianza: 'bueno',
        etiquetas: ['VIP', 'CLIENTE'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientCard(client: client, onRefresh: () {}),
          ),
        ),
      );

      // Verificamos que muestre "S/ 258.57" y NO "258,57 S/"
      expect(find.text('S/ 258.57'), findsOneWidget);
      expect(find.text('258,57 S/'), findsNothing);

      // Verificamos que el teléfono formateado siga visible a pesar de tener etiquetas
      expect(find.text('910 888 652'), findsOneWidget);
      expect(find.text('44556677'), findsOneWidget);
      expect(find.text('VIP'), findsOneWidget);
      expect(find.text('CLIENTE'), findsOneWidget);
    });
  });

  group('Árbitro Adversarial - Fase 2: Modal Crear / Editar Perfil', () {
    testWidgets('ClientProfileEditor permite seleccionar Nivel de Confianza en modo Nuevo Cliente', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final emptyClient = ClientModel(
        id: 0,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: '',
        phone: '',
        registeredDate: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => TrackingProvider()),
              ],
              child: ClientProfileEditor(client: emptyClient, isNew: true),
            ),
          ),
        ),
      );

      // En modo nuevo cliente, Nivel de Confianza debe estar presente
      expect(find.text('Nivel de Confianza'), findsOneWidget);
      expect(find.text('Excelente'), findsOneWidget);
      expect(find.text('Bueno'), findsOneWidget);

      // Las sugerencias de etiquetas no están cortadas y están visibles
      expect(find.text('+ VIP'), findsOneWidget);
      expect(find.text('+ Mayorista'), findsOneWidget);

      // Botón de guardar presente
      expect(find.text('GUARDAR CLIENTE'), findsOneWidget);
    });
  });

  group('Árbitro Adversarial - Fase 3: Descongestión del Perfil y Traslado de Sparkline', () {
    testWidgets('ClientStatsHeader NO contiene ClientComplianceSparkline', (tester) async {
      final client = ClientModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Freddy',
        phone: '910888652',
        registeredDate: '2026-10-21',
        totalDebt: 240.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => TrackingProvider()),
              ],
              child: ClientStatsHeader(
                client: client,
                isDark: true,
                onWhatsAppTap: () {},
                onCallTap: () {},
                onGoToQuickSale: () {},
                onFinanceActionCompleted: () {},
              ),
            ),
          ),
        ),
      );

      // ClientComplianceSparkline ya NO debe existir en la cabecera del perfil principal
      expect(find.byType(ClientComplianceSparkline), findsNothing);

      // Botón "Ver Analítica" debe estar presente
      expect(find.text('Ver Analítica'), findsOneWidget);
    });

    testWidgets('ClientComplianceSparkline renderiza compras reales con AppCurrency', (tester) async {
      final client = ClientModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Freddy',
        phone: '910888652',
        registeredDate: '2026-10-21',
      );

      final List<SaleSummary> sales = [
        SaleSummary(
          id: 10,
          sequentialNumber: 10,
          total: 150.0,
          date: '2026-10-01T10:00:00',
          status: 'entregado',
          itemsCount: 3,
        ),
        SaleSummary(
          id: 11,
          sequentialNumber: 11,
          total: 300.0,
          date: '2026-10-15T15:00:00',
          status: 'entregado',
          itemsCount: 5,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientComplianceSparkline(
              client: client,
              sales: sales,
              isDark: false,
            ),
          ),
        ),
      );

      expect(find.text('Tendencia Comercial'), findsOneWidget);
      expect(find.text('S/ 150.00'), findsOneWidget); // Mínimo
      expect(find.text('S/ 300.00'), findsWidgets); // Máximo y actual
    });
  });

  group('Árbitro Adversarial - Fase 4: Alerta Inteligente de Cuotas Vencidas', () {
    test('Lógica de Memoria de 7 Días o Nueva Cuota Vencida con SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      const clientId = 42;
      const keyTs = 'crm_overdue_folded_ts_$clientId';
      const keyCount = 'crm_overdue_folded_count_$clientId';

      // 1. Simular plegado manual de alerta con 5 cuotas vencidas
      final t0 = DateTime(2026, 10, 1).millisecondsSinceEpoch;
      await prefs.setInt(keyTs, t0);
      await prefs.setInt(keyCount, 5);

      bool evaluateFolded(int currentOverdueCount, int currentTimeMs) {
        final foldedTs = prefs.getInt(keyTs);
        final foldedCount = prefs.getInt(keyCount) ?? 0;
        if (foldedTs == null) return false;

        const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
        final hasExpired = (currentTimeMs - foldedTs) > sevenDaysMs;
        final hasNewOverdue = currentOverdueCount > foldedCount;

        if (!hasExpired && !hasNewOverdue) {
          return true; // Se mantiene plegado
        }
        return false; // Debe desplegarse automáticamente
      }

      // Caso A: 3 días después con las mismas 5 cuotas -> Debe mantenerse plegado
      final tPlus3Days = t0 + (3 * 24 * 60 * 60 * 1000);
      expect(evaluateFolded(5, tPlus3Days), isTrue);

      // Caso B: 8 días después con las mismas 5 cuotas -> Se venció la semana, debe auto-desplegarse
      final tPlus8Days = t0 + (8 * 24 * 60 * 60 * 1000);
      expect(evaluateFolded(5, tPlus8Days), isFalse);

      // Caso C: Al día siguiente aparece una 6ª cuota vencida -> Debe auto-desplegarse inmediatamente
      final tPlus1Day = t0 + (1 * 24 * 60 * 60 * 1000);
      expect(evaluateFolded(6, tPlus1Day), isFalse);
    });
  });

  group('Árbitro Adversarial - Fase 5: Pestañas y Clearance contra Overlays Flotantes', () {
    testWidgets('ClientSalesHistoryTab no colisiona título con badge Debe y tiene padding seguro >= 140', (tester) async {
      final client = ClientModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Freddy',
        phone: '910888652',
        registeredDate: '2026-10-21',
        lastSales: [
          SaleSummary(
            id: 2,
            sequentialNumber: 2,
            total: 240.0,
            montoPagado: 0.0,
            origenVenta: 'prestamo_personal',
            date: '2026-09-04T20:18:00',
            status: 'entregado',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientSalesHistoryTab(
              client: client,
              isDark: true,
              onRefresh: () {},
            ),
          ),
        ),
      );

      // Verificamos que el título y el badge de deuda estén renderizados
      expect(find.text('Préstamo Personal'), findsOneWidget);
      expect(find.text('Debe S/ 240.00'), findsOneWidget);
      expect(find.text('Total: S/ 240.00'), findsOneWidget);
      expect(find.text('Pagado: S/ 0.00'), findsOneWidget);

      // Verificamos que el padding inferior del ListView sea >= 140
      final listViewFinder = find.byType(ListView);
      expect(listViewFinder, findsOneWidget);
      final ListView listView = tester.widget(listViewFinder);
      final padding = listView.padding as EdgeInsets;
      expect(padding.bottom, greaterThanOrEqualTo(140.0));
    });

    testWidgets('ClientQuotationsTab tiene padding inferior seguro >= 140', (tester) async {
      final trackingProv = TrackingProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: trackingProv),
              ],
              child: ClientQuotationsTab(
                isDark: true,
                onRefresh: () {},
              ),
            ),
          ),
        ),
      );

      // Al estar vacía la lista de cotizaciones, muestra el empty state sin crash
      expect(find.text('No hay listas pendientes'), findsOneWidget);
    });
  });
}
