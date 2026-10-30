import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/smart_unit_selector.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/scanner/widgets/staging/comparative_modal/comparative_update_modal.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/client_tracking_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/sales_history_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/workbench_screen.dart';

class MockTrackingProviderForTest extends TrackingProvider {
  final List<ClientModel> clients;
  MockTrackingProviderForTest({this.clients = const []});

  @override
  bool get isLoading => false;

  @override
  List<ClientModel> get filteredClients => clients;

  @override
  bool get filterHasDebt => false;

  @override
  bool get filterPendingDelivery => false;

  @override
  String get filterConfidenceLevel => "todos";

  @override
  String get currentSort => "newest";

  @override
  Future<void> loadClients() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // =========================================================================
  // ÁREA 1: Motor Anti-Rebote y Scroll 100% Estable (Historial y Mesa de Trabajo)
  // =========================================================================
  group('ÁREA 1: Motor Anti-Rebote y Scroll Estable', () {
    testWidgets('Historial de Ventas renderiza estructura Column con AnimatedSize para KPIs y Filtros', (tester) async {
      final saleProv = SaleProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<SaleProvider>.value(value: saleProv),
              ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ],
            child: const SalesHistoryScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verificar que SalesHistoryScreen existe y tiene AnimatedSize para KPIs y Filtros
      expect(find.byType(SalesHistoryScreen), findsOneWidget);
      expect(find.byType(AnimatedSize), findsNWidgets(2)); // Bloque 1 KPIs + Bloque 3 Filtros
      expect(find.byType(TabBarView), findsOneWidget);
    });

    testWidgets('Mesa de Trabajo cuenta con blindaje anti-rebote y guarda de recorrido', (tester) async {
      final workbenchProv = WorkbenchProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<WorkbenchProvider>.value(value: workbenchProv),
            ],
            child: const WorkbenchScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(WorkbenchScreen), findsOneWidget);
      expect(find.byType(NotificationListener<ScrollNotification>), findsWidgets);
    });
  });

  // =========================================================================
  // ÁREA 2: Nueva Estructuración y Navegación Inteligente en Directorio de Clientes
  // =========================================================================
  group('ÁREA 2: Directorio de Clientes (CRM)', () {
    testWidgets('AppBar y barra de búsqueda permanecen fijos en la estructura superior', (tester) async {
      final mockClients = [
        ClientModel(
          id: 1,
          negocioId: 1,
          creadoPorUsuarioId: 1,
          fullName: "Bmk",
          phone: "999888777",
          registeredDate: "2026-10-23T10:00:00Z",
        ),
        ClientModel(
          id: 2,
          negocioId: 1,
          creadoPorUsuarioId: 1,
          fullName: "Freddy",
          phone: "910888652",
          totalDebt: 276.21,
          registeredDate: "2026-10-23T11:00:00Z",
        ),
      ];

      final trackingProv = MockTrackingProviderForTest(clients: mockClients);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<TrackingProvider>.value(value: trackingProv),
              ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ],
            child: const ClientTrackingScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // 1. Verificar AppBar fijo con título
      expect(find.text("Directorio de Clientes"), findsOneWidget);

      // 2. Verificar botón Nuevo Cliente en AppBar
      expect(find.byIcon(Icons.person_add), findsOneWidget);

      // 3. Verificar Buscador Fijo superior persistente
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text("Buscar por nombre, teléfono o DNI..."), findsOneWidget);

      // 4. Verificar sección colapsable con AnimatedSize
      expect(find.byType(AnimatedSize), findsOneWidget);

      // 5. Verificar lista de tarjetas y clientes renderizados
      expect(find.text("Bmk"), findsOneWidget);
      expect(find.text("Freddy"), findsOneWidget);
    });
  });

  // =========================================================================
  // ÁREA 3: Pluralización Natural y Coherencia Matemática en Modal Control de Variante
  // =========================================================================
  group('ÁREA 3: Modal Control de Variante - Matemáticas y UI', () {
    test('Pluralización natural en español maneja pares, unidades, cajas y casos regulares', () {
      // Regla: 1 Par / X Pares
      expect(ComparativeUpdateModal.formatUnitLabelForTest(1, 'Par'), '1 Par');
      expect(ComparativeUpdateModal.formatUnitLabelForTest(4, 'Par'), '4 Pares');

      // Regla: 1 Unidad / X Unidades
      expect(ComparativeUpdateModal.formatUnitLabelForTest(1, 'Unidad'), '1 Unidad');
      expect(ComparativeUpdateModal.formatUnitLabelForTest(8, 'Unidad'), '8 Unidades');

      // Cajas, docenas, paquetes
      expect(ComparativeUpdateModal.formatUnitLabelForTest(1, 'Caja'), '1 Caja');
      expect(ComparativeUpdateModal.formatUnitLabelForTest(3, 'Caja'), '3 Cajas');
      expect(ComparativeUpdateModal.formatUnitLabelForTest(2, 'Docena'), '2 Docenas');
      expect(ComparativeUpdateModal.formatUnitLabelForTest(5, 'Paquete'), '5 Paquetes');
      expect(ComparativeUpdateModal.formatUnitLabelForTest(6, 'Blíster'), '6 Blísters');
    });

    testWidgets('SmartUnitSelector con showInputs: false oculta inputs duplicados y muestra solo botón desplegable', (tester) async {
      final unitCtrl = TextEditingController(text: 'Par');
      final factorCtrl = TextEditingController(text: '2');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartUnitSelector(
              unitCtrl: unitCtrl,
              factorCtrl: factorCtrl,
              isDark: false,
              isCompact: true,
              showInputs: false,
            ),
          ),
        ),
      );

      await tester.pump();

      // No debe existir ningún TextField porque showInputs está en false
      expect(find.byType(TextField), findsNothing);

      // Debe mostrar el botón desplegable "Ver unidades disponibles"
      expect(find.text("Ver unidades disponibles"), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('ComparativeUpdateModal renderiza Gestión de Stock con coherencia de unidad Par (x2)', (tester) async {
      final rawVariant = StagingVariant(
        uuidTemporal: 'var-uuid-stock-test',
        nombreEspecifico: 'Lapicero Faber',
        umpCompra: 'Docena',
        cantidadUmpComprada: 1,
        precioUmpProveedor: 12.0,
        totalPagoLote: 12.0,
        unidadesPorLote: 4, // 4 unidades base
        unidadVenta: 'Unidad',
        unidadesPorVenta: 1,
        costoUnitarioSugerido: 3.0,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 4.05,
        matchPresentacion: MatchResult(estado: 'MATCH_EXACTO', confianza: 100),
      );

      final group = StagingProductGroup(
        nombrePadre: 'Lapicero',
        marcaTexto: 'Faber',
        matchProducto: MatchResult(estado: 'MATCH_SISTEMA', confianza: 95),
        matchMarca: MatchResult(estado: 'MATCH_SISTEMA', confianza: 95),
        variantes: [rawVariant],
      );

      final scannerProv = ScannerProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () {
                    ComparativeUpdateModal.show(
                      ctx,
                      variant: rawVariant,
                      group: group,
                      dbData: {
                        'stock_actual': 4, // 4 unidades base actuales
                        'precio_costo': 22.50,
                        'precio_venta': 30.38,
                        'factor_ganancia_venta': 1.35,
                        'unidad': 'Unidad',
                        'factor_conversion': 1,
                      },
                      isDark: true,
                      provider: scannerProv,
                      onConfirm: () {},
                    );
                  },
                  child: const Text('Abrir Modal'),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();

      // Pulsar botón para abrir el modal
      await tester.tap(find.text('Abrir Modal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verificar que el modal se construye con éxito
      expect(find.byType(ComparativeUpdateModal), findsOneWidget);

      // Verificar que Gestión de Stock está visible
      expect(find.textContaining("Gestión de Stock"), findsOneWidget);

      // Verificar títulos de unidades base
      expect(find.text("En Inventario Actual"), findsOneWidget);
      expect(find.text("Nuevo Ingreso Factura"), findsOneWidget);
      expect(find.text("Stock Total Resultante para la Venta"), findsOneWidget);
    });
  });
}
