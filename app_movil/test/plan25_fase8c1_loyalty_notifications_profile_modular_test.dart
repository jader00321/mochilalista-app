import 'dart:io';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/profile/screens/notifications_screen.dart';
import 'package:app_movil/features/profile/screens/profile_screen.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/loyalty_center_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Directory _resolveAppMovilRoot() {
  final cwd = Directory.current;
  if (File('${cwd.path}${Platform.pathSeparator}pubspec.yaml').existsSync() &&
      Directory('${cwd.path}${Platform.pathSeparator}lib').existsSync()) {
    return cwd;
  }
  final nested = Directory('${cwd.path}${Platform.pathSeparator}app_movil');
  if (nested.existsSync() &&
      File('${nested.path}${Platform.pathSeparator}pubspec.yaml').existsSync()) {
    return nested;
  }
  throw StateError('No se pudo localizar la raíz app_movil desde ${cwd.path}');
}

int _lineCount(Directory root, String relPath) {
  final sep = Platform.pathSeparator;
  final file = File('${root.path}$sep${relPath.replaceAll('/', sep)}');
  expect(file.existsSync(), isTrue, reason: 'Falta archivo $relPath');
  return file.readAsLinesSync().length;
}

class _MockAuthProvider extends ChangeNotifier implements AuthProvider {
  final UserModel _user = UserModel(
    id: 1,
    fullName: 'Comerciante Prueba',
    phone: '999888777',
    isActive: true,
  );

  final BusinessModel _business = BusinessModel(
    id: 1,
    commercialName: 'Librería Central',
    address: 'Jr. Comercio 456',
    moneda: 'PEN',
  );

  @override
  UserModel? get user => _user;

  @override
  bool get isAuthenticated => true;

  @override
  bool get hasActiveContext => true;

  @override
  int? get activeBusinessId => 1;

  @override
  BusinessModel? get currentBusiness => _business;

  @override
  bool get hasPinCache => true;

  @override
  bool get isPinReminderSnoozed => true;

  @override
  bool get isLoading => false;

  @override
  bool get isCommunityClient => false;

  @override
  String get userName => 'Comerciante Prueba';

  @override
  String get businessName => 'Librería Central';

  @override
  String get activeBusinessName => 'Librería Central';

  @override
  String get errorMessage => '';

  @override
  Future<void> refreshActiveUser() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockLicenseProvider extends ChangeNotifier implements LicenseProvider {
  @override
  bool get isPerpetual => false;

  @override
  bool get isActive => true;

  @override
  bool get isTrial => true;

  @override
  String get currentPlanName => 'TRIAL';

  @override
  LicenseModel? get license => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockInventoryProvider extends ChangeNotifier implements InventoryProvider {
  @override
  int get totalProductsCount => 5;

  @override
  bool get showStockAlertColors => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockWorkbenchProvider extends ChangeNotifier implements WorkbenchProvider {
  @override
  List<SmartQuotationModel> get inProcessList => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockSaleProvider extends ChangeNotifier implements SaleProvider {
  @override
  double get todaySalesTotal => 0.0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrapWithTextScaler(Widget home) {
  return MaterialApp(
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(
        textScaler: const TextScaler.linear(1.3),
      ),
      child: child!,
    ),
    home: home,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;

  setUpAll(() async {
    await initializeDateFormatting('es', null);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    testDb = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(testDb);
    LocalDatabase.setCustomDatabase(testDb);
  });

  tearDown(() async {
    LocalDatabase.setCustomDatabase(null);
    if (testDb.isOpen) {
      await testDb.close();
    }
  });

  group('Plan 25 Fase 8C-1 — Censo estricto de líneas y contratos públicos', () {
    test('Coordinadores < 600 L y módulos cohesivos < 650 L sin excepción', () {
      final root = _resolveAppMovilRoot();

      for (final coord in const [
        'lib/features/smart_quotation/screens/crm/loyalty_center_screen.dart',
        'lib/features/profile/screens/notifications_screen.dart',
        'lib/features/profile/screens/profile_screen.dart',
      ]) {
        expect(_lineCount(root, coord), lessThan(600), reason: coord);
      }

      for (final moduleFile in const [
        'lib/features/smart_quotation/screens/crm/loyalty_center/loyalty_center_metrics_and_actions.dart',
        'lib/features/smart_quotation/screens/crm/loyalty_center/loyalty_center_reputation_tab.dart',
        'lib/features/smart_quotation/screens/crm/loyalty_center/loyalty_center_reputation_card.dart',
        'lib/features/smart_quotation/screens/crm/loyalty_center/loyalty_center_rewards_tab.dart',
        'lib/features/smart_quotation/screens/crm/loyalty_center/loyalty_center_reward_cards.dart',
        'lib/features/smart_quotation/screens/crm/loyalty_center/loyalty_center_offers_tab.dart',
        'lib/features/profile/screens/notifications/notifications_app_bar.dart',
        'lib/features/profile/screens/notifications/notifications_actions_and_deeplinks.dart',
        'lib/features/profile/screens/notifications/notifications_cuota_detail_modal.dart',
        'lib/features/profile/screens/notifications/notifications_generic_detail_modal.dart',
        'lib/features/profile/screens/notifications/notifications_grouped_client_section.dart',
        'lib/features/profile/screens/notifications/notifications_pulse_and_cards.dart',
        'lib/features/profile/screens/notifications/notifications_card_action_menu.dart',
        'lib/features/profile/screens/profile/profile_menu_sections.dart',
        'lib/features/profile/screens/profile/profile_header_and_legal.dart',
        'lib/features/profile/screens/profile/profile_layout_helpers_and_delete.dart',
        'lib/features/profile/screens/profile/profile_photo_and_edit_modals.dart',
      ]) {
        expect(_lineCount(root, moduleFile), lessThan(650), reason: moduleFile);
      }

      // Paridad de símbolos públicos importados desde las rutas originales
      expect(LoyaltyCenterScreen, isNotNull);
      expect(NotificationsScreen, isNotNull);
      expect(ProfileScreen, isNotNull);
    });
  });

  group('Plan 25 Fase 8C-1 — Paridad Visual 0px Overflow @ TextScaler 1.3x', () {
    for (final size in const [
      Size(320, 568),
      Size(360, 640),
      Size(412, 915),
    ]) {
      testWidgets(
        'LoyaltyCenterScreen, NotificationsScreen y ProfileScreen en ${size.width.toInt()}x${size.height.toInt()}dp @ 1.3x',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          final capturedMessages = <String>[];
          String currentStage = 'init';
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            final msg = details.exceptionAsString();
            if (msg.toLowerCase().contains('overflowed')) {
              capturedMessages.add('[$currentStage] ${details.toString()}');
            } else {
              capturedMessages.add('[$currentStage] $msg');
            }
          };

          final authProv = _MockAuthProvider();
          final licenseProv = _MockLicenseProvider();
          final themeProv = ThemeProvider();
          final invProv = _MockInventoryProvider();
          final workbenchProv = _MockWorkbenchProvider();
          final saleProv = _MockSaleProvider();
          final notifProv = NotificationProvider();

          try {
            await tester.runAsync(() async {
              await testDb.insert('negocios', {
                'id': 1,
                'nombre_comercial': 'Librería Central',
                'moneda': 'S/ (Soles)',
              });
              await testDb.insert('usuarios', {
                'id': 1,
                'nombre_completo': 'Comerciante Prueba',
                'email': 'admin@libreria.com',
              });
              await LocalDatabase.seedDefaultMetasRecompensas(testDb);
              final int clientId = await testDb.insert('clientes', {
                'negocio_id': 1,
                'creado_por_usuario_id': 1,
                'nombre_completo': 'María Peña Canción',
                'telefono': '987654321',
                'puntos_actuales': 85,
                'puntos_historicos': 120,
                'score_reputacion': 580,
                'nivel_reputacion': 'PLATA',
                'fecha_registro': '2026-10-15',
              });
              final int saleId = await testDb.insert('ventas', {
                'negocio_id': 1,
                'creado_por_usuario_id': 1,
                'cliente_id': clientId,
                'origen_venta': 'smart_quotation',
                'monto_total': 240.0,
                'monto_pagado': 0.0,
                'metodo_pago': 'Credito',
                'fecha_venta': '2026-10-15',
              });
              await testDb.insert('cuotas', {
                'venta_id': saleId,
                'numero_cuota': 1,
                'monto': 120.0,
                'monto_original': 120.0,
                'mora_monto': 0.0,
                'monto_pagado': 0.0,
                'fecha_vencimiento': '2026-10-20',
                'estado': 'pendiente',
              });
              await testDb.insert('cuotas', {
                'venta_id': saleId,
                'numero_cuota': 2,
                'monto': 125.0,
                'monto_original': 120.0,
                'mora_monto': 5.0,
                'monto_pagado': 0.0,
                'fecha_vencimiento': '2026-10-25',
                'estado': 'pendiente',
              });
              final int prodId = await testDb.insert('productos', {
                'negocio_id': 1,
                'nombre': 'Cuaderno A4 Rayado Standford',
              });
              await testDb.insert('presentaciones_producto', {
                'producto_id': prodId,
                'nombre_especifico': 'x 100 Hojas',
                'precio_venta_final': 8.50,
                'precio_oferta': 7.00,
                'stock_actual': 12,
                'activo': 1,
              });

              notifProv.updateContext(1);
              await Future<void>.delayed(const Duration(milliseconds: 50));
              await notifProv.generateAutoNotifications(1);
              await notifProv.fetchNotifications();
            });

            // 1. LoyaltyCenterScreen (tabs 0, 1, 2)
            for (final tab in const [0, 1, 2]) {
              currentStage = 'LoyaltyCenterScreen tab=$tab';
              await tester.pumpWidget(
                MultiProvider(
                  providers: [
                    ChangeNotifierProvider<AuthProvider>.value(value: authProv),
                  ],
                  child: _wrapWithTextScaler(
                    LoyaltyCenterScreen(
                      initialTabIndex: tab,
                      autoTriggerTour: false,
                    ),
                  ),
                ),
              );
              await tester.pump();
              await tester.runAsync(() async {
                await Future.delayed(const Duration(milliseconds: 250));
              });
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 200));
              expect(find.text('Fidelización y Premios'), findsOneWidget);
            }

            // 2. NotificationsScreen
            currentStage = 'NotificationsScreen';
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<NotificationProvider>.value(value: notifProv),
                  ChangeNotifierProvider<AuthProvider>.value(value: authProv),
                  ChangeNotifierProvider<InventoryProvider>.value(value: invProv),
                ],
                child: _wrapWithTextScaler(
                  const NotificationsScreen(autoTriggerTour: false),
                ),
              ),
            );
            await tester.runAsync(() async {
              await Future.delayed(const Duration(milliseconds: 250));
            });
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.text('Notificaciones'), findsOneWidget);

            // 3. ProfileScreen
            currentStage = 'ProfileScreen';
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(value: authProv),
                  ChangeNotifierProvider<LicenseProvider>.value(value: licenseProv),
                  ChangeNotifierProvider<ThemeProvider>.value(value: themeProv),
                  ChangeNotifierProvider<InventoryProvider>.value(value: invProv),
                  ChangeNotifierProvider<WorkbenchProvider>.value(value: workbenchProv),
                  ChangeNotifierProvider<SaleProvider>.value(value: saleProv),
                ],
                child: _wrapWithTextScaler(
                  const ProfileScreen(autoTriggerTour: false),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Editar Datos Personales'), findsOneWidget);

            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();

            final overflowErrors = capturedMessages
                .where((m) => m.toLowerCase().contains('overflowed'))
                .toList();
            expect(
              overflowErrors,
              isEmpty,
              reason:
                  'Overflow detectado en ${size.width}x${size.height} @ 1.3x:\n${overflowErrors.join('\n')}',
            );
            expect(tester.takeException(), isNull);
          } finally {
            FlutterError.onError = prevOnError;
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }
        },
      );
    }
  });
}
