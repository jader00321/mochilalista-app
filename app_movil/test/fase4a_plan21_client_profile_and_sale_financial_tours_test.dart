import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/tour/coach_card_widget.dart';
import 'package:app_movil/core/widgets/tour/configs/client_detail_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/profile_screen_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/sale_financial_detail_tour.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/profile/screens/profile_screen.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/client_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/sale_financial_detail_screen.dart';

class _MockAuth4A extends ChangeNotifier implements AuthProvider {
  late final BusinessModel _business = BusinessModel(
    id: 1,
    commercialName: 'Librería Plan 21 4A',
    address: 'Av. Los Próceres 450',
    moneda: 'S/ (Soles)',
  );

  late final UserModel _user = UserModel(
    id: 1,
    fullName: 'Angello Vendedor',
    phone: '999888777',
    isActive: true,
    business: _business,
  );

  @override
  UserModel? get user => _user;

  @override
  BusinessModel? get currentBusiness => _business;

  @override
  bool get isAuthenticated => true;

  @override
  bool get hasActiveContext => true;

  @override
  int? get activeBusinessId => 1;

  @override
  int? get activeUserId => 1;

  @override
  bool get isOwner => true;

  @override
  bool get isWorker => false;

  @override
  bool get isCommunityClient => false;

  @override
  bool get canManageClients => true;

  @override
  bool get hasPinCache => true;

  @override
  bool get isPinReminderSnoozed => true;

  @override
  bool get isLoading => false;

  @override
  String get userName => 'Angello Vendedor';

  @override
  String get businessName => 'Librería Plan 21 4A';

  @override
  String get errorMessage => '';

  @override
  Future<void> refreshActiveUser() async {}

  @override
  Future<void> checkInitialState() async {}

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockTheme4A extends ChangeNotifier implements ThemeProvider {
  @override
  ThemeMode get themeMode => ThemeMode.light;

  @override
  bool get isDarkMode => false;

  @override
  Future<void> toggleTheme(bool isDark) async {}

  @override
  Future<void> toggleCurrentTheme() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockLicense4A extends ChangeNotifier implements LicenseProvider {
  @override
  bool get isPerpetual => false;

  @override
  bool get isActive => true;

  @override
  String get currentPlanName => 'MENSUAL';

  @override
  LicenseModel? get license => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockInventory4A extends ChangeNotifier implements InventoryProvider {
  @override
  int get totalProductsCount => 48;

  @override
  int get totalPresentationsCount => 64;

  @override
  bool get showStockAlertColors => true;

  @override
  bool get isLoading => false;

  @override
  bool get isLoadingMore => false;

  @override
  bool get hasMoreData => false;

  @override
  bool get hasCreationDraft => false;

  @override
  List<InventoryWrapper> get items => const <InventoryWrapper>[];

  @override
  List<Category> get categories => const <Category>[];

  @override
  List<Brand> get brands => const <Brand>[];

  @override
  List<ProviderModel> get providers => const <ProviderModel>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockWorkbench4A extends ChangeNotifier implements WorkbenchProvider {
  @override
  bool get isLoading => false;

  @override
  List<SmartQuotationModel> get inProcessList => const <SmartQuotationModel>[];

  @override
  List<SmartQuotationModel> get readyAndPacksList =>
      const <SmartQuotationModel>[];

  @override
  List<SmartQuotationModel> get soldList => const <SmartQuotationModel>[];

  @override
  Future<void> loadDashboard({bool silent = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockTracking4A extends ChangeNotifier implements TrackingProvider {
  final List<SaleModel> _debts;

  _MockTracking4A({List<SaleModel> debts = const []}) : _debts = debts;

  @override
  List<SaleModel> get currentClientDebts => _debts;

  @override
  bool get isLoadingDebts => false;

  @override
  bool get isLoadingLedger => false;

  @override
  List<LedgerItem> get currentClientLedger => const <LedgerItem>[];

  @override
  bool get isLoadingQuotations => false;

  @override
  List<SmartQuotationModel> get currentClientQuotations =>
      const <SmartQuotationModel>[];

  @override
  int get pendingRewardsCount => 0;

  @override
  Future<void> loadClientDebts(int clientId) async {}

  @override
  Future<void> loadClientLedger(int clientId) async {}

  @override
  Future<void> loadClientQuotations(int clientId) async {}

  @override
  Future<void> loadPendingRewardsCount() async {}

  @override
  Future<ClientModel?> getClientById(int clientId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockQuickSale4A extends ChangeNotifier implements QuickSaleProvider {
  @override
  bool get hideProfits => false;

  @override
  List<MatchedProduct> get cartItems => const <MatchedProduct>[];

  @override
  void setClientInfo({
    ClientModel? client,
    int? id,
    String? name,
    String? phone,
    double? saldo,
    String? clientNote,
    String? saleNote,
  }) {}

  @override
  void clearCart() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockSaleProvider4A extends ChangeNotifier implements SaleProvider {
  final Map<String, dynamic> _saleDetail;

  _MockSaleProvider4A({required Map<String, dynamic> saleDetail})
    : _saleDetail = saleDetail;

  @override
  bool get isLoading => false;

  @override
  double get todaySalesTotal => 250.0;

  @override
  int get todaySalesCount => 2;

  @override
  String get errorMessage => '';

  @override
  List<SaleModel> get salesHistory => const <SaleModel>[];

  @override
  Future<Map<String, dynamic>?> getSaleDetail(int saleId) async => _saleDetail;

  @override
  Future<void> silentRefresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Map<String, dynamic> _buildSampleSaleDetail({int saleId = 42}) {
  final yesterday = DateTime.now()
      .subtract(const Duration(days: 2))
      .toIso8601String();
  final nextWeek = DateTime.now()
      .add(const Duration(days: 10))
      .toIso8601String();
  return {
    'id': saleId,
    'numero_secuencial': saleId,
    'origen_venta': 'venta_normal',
    'monto_total': 305.0,
    'monto_pagado': 50.0,
    'porcentaje_interes': 5.0,
    'mora_total': 5.0,
    'estado_entrega': 'pendiente_recojo',
    'cliente_id': 1,
    'cliente_nombre': 'Ana María Cliente 4A',
    'cliente_telefono': '999888777',
    'cotizacion_id': 0,
    'cuotas': [
      {
        'id': 101,
        'numero_cuota': 1,
        'monto': 155.0,
        'monto_original': 150.0,
        'mora_monto': 5.0,
        'mora_porcentaje': 3.3,
        'mora_automatica': 1,
        'monto_pagado': 0.0,
        'fecha_vencimiento': yesterday,
        'estado': 'pendiente',
      },
      {
        'id': 102,
        'numero_cuota': 2,
        'monto': 150.0,
        'monto_original': 150.0,
        'mora_monto': 0.0,
        'mora_porcentaje': 0.0,
        'mora_automatica': 0,
        'monto_pagado': 0.0,
        'fecha_vencimiento': nextWeek,
        'estado': 'pendiente',
      },
    ],
    'items': [
      {
        'brand_name': 'Faber-Castell',
        'product_name': 'Cuaderno A4 Especial Plan 21',
        'specific_name': 'Rayado 100 hojas',
        'sales_unit': 'Paquete',
        'unit_price_applied': 25.0,
        'original_unit_price': 30.0,
        'quantity': 4,
        'image_url': '',
        'original_text': 'Cuaderno A4 escolar',
      },
    ],
  };
}

ClientModel _buildSampleClient() {
  return ClientModel(
    id: 1,
    negocioId: 1,
    creadoPorUsuarioId: 1,
    fullName: 'Ana María Cliente 4A',
    phone: '999888777',
    docNumber: '45678912',
    address: 'Jr. Lima 345',
    totalDebt: 255.0,
    saldoAFavor: 40.0,
    registeredDate: '2026-11-01T10:00:00.000Z',
    etiquetas: const ['Frecuente', 'Escolar'],
    puntosActuales: 180,
    rachaPagosPuntuales: 4,
    nivelReputacion: 'ORO',
  );
}

Widget _wrapWithProviders({
  required Widget child,
  required Size viewport,
  Map<String, dynamic>? saleDetail,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: _MockAuth4A()),
      ChangeNotifierProvider<ThemeProvider>.value(value: _MockTheme4A()),
      ChangeNotifierProvider<LicenseProvider>.value(value: _MockLicense4A()),
      ChangeNotifierProvider<InventoryProvider>.value(
        value: _MockInventory4A(),
      ),
      ChangeNotifierProvider<WorkbenchProvider>.value(
        value: _MockWorkbench4A(),
      ),
      ChangeNotifierProvider<TrackingProvider>.value(value: _MockTracking4A()),
      ChangeNotifierProvider<QuickSaleProvider>.value(
        value: _MockQuickSale4A(),
      ),
      ChangeNotifierProvider<SaleProvider>.value(
        value: _MockSaleProvider4A(
          saleDetail: saleDetail ?? _buildSampleSaleDetail(),
        ),
      ),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        size: viewport,
        textScaler: const TextScaler.linear(1.3),
      ),
      child: MaterialApp(home: child),
    ),
  );
}

Future<void> _pumpBounded(WidgetTester tester, {int frames = 6}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 25,
}) async {
  for (int i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 80));
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 80));
      return;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final emojiRegex = RegExp(
    r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
    unicode: true,
  );

  setUpAll(() async {
    await initializeDateFormatting('es', null);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    InteractiveTourService.autoTriggerOverrideForTesting = null;
    InteractiveTourService.resetRuntimeLockForTesting();
  });

  tearDown(() async {
    InteractiveTourService.autoTriggerOverrideForTesting = null;
    InteractiveTourService.resetRuntimeLockForTesting();
  });

  group('Plan Maestro 21 - Sub-turno 4A: Modelos y Contratos de Guías', () {
    test(
      '1. ClientDetailTour (7 pasos), ProfileScreenTour (8 pasos) y SaleFinancialDetailTour (6 pasos): integridad y cero emojis crudos',
      () {
        final clientConfig = ClientDetailTour.buildConfig(
          keys: ClientDetailTourKeys(),
        );
        expect(clientConfig.screenId, equals('client_detail_screen'));
        expect(clientConfig.steps.length, equals(7));
        expect(
          clientConfig.steps.map((s) => s.description).join(' '),
          allOf(
            contains('Operaciones Financieras'),
            contains('Retirar Saldo'),
            contains('Caja Rápida'),
            contains('Cotizar'),
            contains('Recordar'),
            contains('Estado de Cuenta'),
          ),
        );

        final profileConfig = ProfileScreenTour.buildConfig();
        expect(profileConfig.screenId, equals('profile_screen'));
        expect(profileConfig.steps.length, equals(8));
        expect(
          profileConfig.steps.map((s) => '${s.title} ${s.description}').join(' '),
          allOf(
            contains('modal del negocio'),
            contains('GPS'),
            contains('moneda'),
            contains('PIN'),
            contains('Reiniciar guías'),
            contains('Cerrar Sesión'),
            contains('Zona de Peligro'),
          ),
        );

        final saleFinConfig = SaleFinancialDetailTour.buildConfig();
        expect(saleFinConfig.screenId, equals('sale_financial_detail_screen'));
        expect(saleFinConfig.steps.length, equals(6));
        expect(
          saleFinConfig.steps.map((s) => '${s.title} ${s.description}').join(' '),
          allOf(
            contains('Base'),
            contains('Mora'),
            contains('Prog. Mora'),
            contains('Recordar'),
            contains('Cobrar'),
            contains('PDF'),
            contains('WhatsApp'),
          ),
        );

        for (final config in [clientConfig, profileConfig, saleFinConfig]) {
          expect(emojiRegex.hasMatch(config.screenTitle), isFalse);
          expect(emojiRegex.hasMatch(config.welcomeSummary), isFalse);
          for (final step in config.steps) {
            expect(step.title.trim(), isNotEmpty);
            expect(step.description.trim(), isNotEmpty);
            expect(step.tip?.trim(), isNotEmpty);
            expect(emojiRegex.hasMatch(step.title), isFalse);
            expect(emojiRegex.hasMatch(step.description), isFalse);
            if (step.tip != null) {
              expect(emojiRegex.hasMatch(step.tip!), isFalse);
            }
          }
        }
      },
    );
  });

  group('Plan Maestro 21 - Sub-turno 4A: Recorridos Interactivos Reales', () {
    testWidgets(
      '2. ClientDetailScreen: botón (i) ejecuta los 7 pasos completos sin desbordes ni arrastre de TabBarView',
      (tester) async {
        const viewport = Size(360, 640);
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final capturedErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = capturedErrors.add;

        try {
          await tester.pumpWidget(
            _wrapWithProviders(
              viewport: viewport,
              child: ClientDetailScreen(
                client: _buildSampleClient(),
                autoRefreshOnLoad: false,
                autoTriggerTour: false,
              ),
            ),
          );

          await _pumpBounded(tester, frames: 6);

          final tabController =
              tester.widget<TabBar>(find.byType(TabBar)).controller!;
          expect(tabController.index, equals(0));

          await tester.tap(find.byTooltip('Información'));
          await _pumpBounded(tester, frames: 5);
          await tester.tap(find.text('Iniciar guía interactiva paso a paso'));
          await _pumpUntilFound(tester, find.text('1 / 7'));

          expect(InteractiveTourService.isTourActive, isTrue);
          expect(find.byType(CoachCardWidget), findsOneWidget);
          expect(
            find.text('Balance, Semáforo de Crédito y Reputación'),
            findsOneWidget,
          );

          final expectedTitles = [
            'Abonar a Deuda y Amortizaciones',
            'Modal Operaciones Financieras (+ Préstamo)',
            'Accesos Rápidos Comerciales',
            'Recordatorio por WhatsApp (Recordar)',
            'Pestañas Contables del Cliente',
            'Menú Superior de Gestión',
          ];

          for (int i = 0; i < expectedTitles.length; i++) {
            await tester.tap(find.text('Siguiente'));
            await _pumpUntilFound(tester, find.text('${i + 2} / 7'));
            expect(find.text('${i + 2} / 7'), findsOneWidget);
            expect(find.text(expectedTitles[i]), findsOneWidget);
            expect(tabController.index, equals(0));
          }

          await tester.tap(find.text('¡Listo!'));
          await _pumpBounded(tester, frames: 8);

          expect(InteractiveTourService.isTourActive, isFalse);
          expect(find.byType(CoachCardWidget), findsNothing);
          expect(capturedErrors, isEmpty);
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );

    testWidgets(
      '3. ProfileScreen: botón (i) ejecuta los 8 pasos completos con scroll vertical seguro',
      (tester) async {
        const viewport = Size(360, 640);
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final capturedErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = capturedErrors.add;

        try {
          await tester.pumpWidget(
            _wrapWithProviders(
              viewport: viewport,
              child: const ProfileScreen(autoTriggerTour: false),
            ),
          );

          await _pumpBounded(tester, frames: 12);

          await tester.tap(find.byTooltip('Información'));
          await _pumpBounded(tester, frames: 6);
          await tester.tap(find.text('Iniciar guía interactiva paso a paso'));
          await _pumpUntilFound(tester, find.text('1 / 8'));

          expect(InteractiveTourService.isTourActive, isTrue);
          expect(find.text('Identidad, Logo y Plan Activo'), findsOneWidget);

          final expectedTitles = [
            'Información y Modal del Negocio',
            'Indicador de Completitud del Perfil',
            'Centro Operativo (IA, Impresora, Drive y Licencia)',
            'Seguridad y Bóveda PIN',
            'Guías Automáticas y Reinicio',
            'Cambiar de Negocio y Cerrar Sesión',
            'Zona de Peligro: Eliminar Perfil Actual',
          ];

          for (int i = 0; i < expectedTitles.length; i++) {
            await tester.tap(find.text('Siguiente'));
            await _pumpUntilFound(tester, find.text('${i + 2} / 8'));
            expect(find.text('${i + 2} / 8'), findsOneWidget);
            expect(find.text(expectedTitles[i]), findsOneWidget);
          }

          await tester.tap(find.text('¡Listo!'));
          await _pumpBounded(tester, frames: 8);

          expect(InteractiveTourService.isTourActive, isFalse);
          expect(find.byType(CoachCardWidget), findsNothing);
          expect(capturedErrors, isEmpty);
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );

    testWidgets(
      '4. SaleFinancialDetailScreen: botón (i), tour de 6 pasos con expansión/restauración de cuota al completar, X, Back y dispose',
      (tester) async {
        const viewport = Size(360, 640);
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final capturedErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = capturedErrors.add;

        try {
          await tester.pumpWidget(
            _wrapWithProviders(
              viewport: viewport,
              child: const SaleFinancialDetailScreen(
                saleId: 42,
                autoTriggerTour: false,
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Cuota 1 inicialmente contraída
          expect(find.text('Monto Base:'), findsNothing);

          // A) Abrir desde botón (i) en AppBar y completar los 6 pasos
          await tester.tap(find.byTooltip('Información'));
          await _pumpBounded(tester, frames: 5);
          await tester.tap(find.text('Iniciar guía interactiva paso a paso'));
          await _pumpUntilFound(tester, find.text('1 / 6'));

          expect(find.text('Ver Comprobante y Resumen'), findsOneWidget);
          expect(find.text('Monto Base:'), findsNothing);

          await tester.tap(find.text('Siguiente'));
          await _pumpUntilFound(tester, find.text('2 / 6'));
          expect(find.text('Tarjeta de Balance Financiero'), findsOneWidget);
          expect(find.text('Monto Base:'), findsNothing);

          // Paso 3: expande automáticamente Cuota 1 mostrando tabla Base/Mora/Saldo
          await tester.tap(find.text('Siguiente'));
          await _pumpUntilFound(tester, find.text('3 / 6'));
          expect(
            find.text('Cronograma de Cuotas (Base + Mora + Auto)'),
            findsOneWidget,
          );
          expect(find.text('Monto Base:'), findsOneWidget);

          // Paso 4: acciones Mora / Recordar / Cobrar con cuota expandida
          await tester.tap(find.text('Siguiente'));
          await _pumpUntilFound(tester, find.text('4 / 6'));
          expect(
            find.text('Acciones de Cobro, Mora y Recordar'),
            findsOneWidget,
          );
          expect(find.text('Monto Base:'), findsOneWidget);

          // Paso 5: Fecha y prórroga con cuota expandida
          await tester.tap(find.text('Siguiente'));
          await _pumpUntilFound(tester, find.text('5 / 6'));
          expect(
            find.text('Edición de Fecha y Ajustes del Plan'),
            findsOneWidget,
          );
          expect(find.text('Monto Base:'), findsOneWidget);

          // Paso 6: Exportación PDF/WhatsApp (restaura Cuota 1 contraída)
          await tester.tap(find.text('Siguiente'));
          await _pumpUntilFound(tester, find.text('6 / 6'));
          expect(
            find.text('Exportación y Envío (PDF y WhatsApp)'),
            findsOneWidget,
          );
          expect(find.text('Monto Base:'), findsNothing);

          await tester.tap(find.text('¡Listo!'));
          await _pumpBounded(tester, frames: 8);
          expect(InteractiveTourService.isTourActive, isFalse);
          expect(find.text('Monto Base:'), findsNothing);

          // B) Cerrar con botón X en el paso 4 restaura Cuota 1 contraída
          await tester.tap(find.byTooltip('Información'));
          await _pumpBounded(tester, frames: 5);
          await tester.tap(find.text('Iniciar guía interactiva paso a paso'));
          await _pumpUntilFound(tester, find.text('1 / 6'));
          for (int s = 0; s < 3; s++) {
            await tester.tap(find.text('Siguiente'));
            await _pumpUntilFound(tester, find.text('${s + 2} / 6'));
          }
          expect(find.text('Monto Base:'), findsOneWidget);

          await tester.tap(find.byTooltip('Cerrar guía'));
          await _pumpBounded(tester, frames: 10);
          expect(InteractiveTourService.isTourActive, isFalse);
          expect(find.text('Monto Base:'), findsNothing);

          // C) Pulsar botón Atrás del sistema en el paso 3 restaura Cuota 1 contraída
          await tester.tap(find.byTooltip('Información'));
          await _pumpBounded(tester, frames: 5);
          await tester.tap(find.text('Iniciar guía interactiva paso a paso'));
          await _pumpUntilFound(tester, find.text('1 / 6'));
          for (int s = 0; s < 2; s++) {
            await tester.tap(find.text('Siguiente'));
            await _pumpUntilFound(tester, find.text('${s + 2} / 6'));
          }
          expect(find.text('Monto Base:'), findsOneWidget);

          await tester.binding.handlePopRoute();
          await _pumpBounded(tester, frames: 10);
          expect(InteractiveTourService.isTourActive, isFalse);
          expect(find.text('Monto Base:'), findsNothing);

          // D) Desmontar pantalla en medio del paso 3 no arroja setState after dispose
          await tester.tap(find.byTooltip('Información'));
          await _pumpBounded(tester, frames: 5);
          await tester.tap(find.text('Iniciar guía interactiva paso a paso'));
          await _pumpUntilFound(tester, find.text('1 / 6'));
          await tester.tap(find.text('Siguiente'));
          await _pumpUntilFound(tester, find.text('2 / 6'));
          await tester.tap(find.text('Siguiente'));
          await _pumpBounded(tester, frames: 2);

          await tester.pumpWidget(const SizedBox.shrink());
          await _pumpBounded(tester, frames: 8);

          expect(tester.takeException(), isNull);
          expect(capturedErrors, isEmpty);
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );
  });

  group('Plan Maestro 21 - Sub-turno 4A: Responsividad 0px Overflow a 1.3x', () {
    const viewports = [
      Size(320, 568),
      Size(360, 640),
      Size(412, 915),
    ];

    for (final viewport in viewports) {
      testWidgets(
        '5. Responsividad ${viewport.width.toInt()}x${viewport.height.toInt()}dp @ 1.3x: ClientDetailScreen, ProfileScreen y SaleFinancialDetailScreen con 0px Overflow',
        (tester) async {
          final capturedErrors = <FlutterErrorDetails>[];
          final originalOnError = FlutterError.onError;
          FlutterError.onError = capturedErrors.add;

          try {
            await tester.binding.setSurfaceSize(viewport);
            addTearDown(() => tester.binding.setSurfaceSize(null));

            // 1) ClientDetailScreen (con Pulse animation -> pumping acotado)
            await tester.pumpWidget(
              _wrapWithProviders(
                viewport: viewport,
                child: ClientDetailScreen(
                  client: _buildSampleClient(),
                  autoRefreshOnLoad: false,
                  autoTriggerTour: false,
                ),
              ),
            );
            await _pumpBounded(tester, frames: 6);
            expect(find.text('Perfil del Cliente'), findsOneWidget);

            // 2) ProfileScreen
            await tester.pumpWidget(
              _wrapWithProviders(
                viewport: viewport,
                child: const ProfileScreen(autoTriggerTour: false),
              ),
            );
            await _pumpBounded(tester, frames: 12);
            expect(find.text('Zona de Peligro'), findsOneWidget);

            // 3) SaleFinancialDetailScreen (AppBar con (i), PDF y WhatsApp + título íntegro)
            await tester.pumpWidget(
              _wrapWithProviders(
                viewport: viewport,
                child: const SaleFinancialDetailScreen(
                  saleId: 42,
                  autoTriggerTour: false,
                ),
              ),
            );
            await tester.pumpAndSettle();

            final titleFinder = find.text('Detalle de Venta #42');
            expect(titleFinder, findsOneWidget);
            final titleRect = tester.getRect(titleFinder);
            expect(titleRect.left, greaterThanOrEqualTo(0.0));
            expect(titleRect.right, lessThanOrEqualTo(viewport.width));
            expect(titleRect.width, greaterThan(70.0));

            await tester.pumpWidget(const SizedBox.shrink());
            await _pumpBounded(tester, frames: 4);

            expect(
              capturedErrors,
              isEmpty,
              reason:
                  'Se detectaron overflows o errores de layout en ${viewport.width}x${viewport.height}dp',
            );
          } finally {
            FlutterError.onError = originalOnError;
          }
        },
      );
    }
  });
}
