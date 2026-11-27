import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_movil/core/config/app_changelog_registry.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/core/screens/home_screen.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/services/license/license_repository.dart';
import 'package:app_movil/core/services/startup_flow_coordinator.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/discount_intelligent_modal.dart';
import 'package:app_movil/core/widgets/tour/configs/home_screen_tour.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/profile/services/business_backup_service.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_search_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/services/quotation_service.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/whatsapp_preview_modal.dart';

String _resolveAppMovilRoot() {
  final dir = Directory.current.path.replaceAll('\\', '/');
  if (dir.endsWith('/app_movil')) {
    return dir;
  }
  return '$dir/app_movil';
}

int _countLines(String relativePath) {
  final file = File('${_resolveAppMovilRoot()}/$relativePath');
  if (!file.existsSync()) {
    fail('Archivo modular requerido no existe: $relativePath');
  }
  return file.readAsLinesSync().length;
}

class _MockInventory9E5 extends InventoryProvider {
  int? updatedId;
  double? updatedOffer;
  String? updatedTipoDesc;

  @override
  Future<bool> updatePresentation(
    int presentationId, {
    String? nombreEspecifico,
    String? unidadVenta,
    int? unidadesPorVenta,
    double? costoUnitarioCalculado,
    double? factorGananciaVenta,
    double? precioVentaFinal,
    double? precioUmpProveedor,
    double? cantidadUmpComprada,
    double? totalPagoLote,
    int? unidadesPorLote,
    String? umpCompra,
    double? oferta,
    String? tipoDesc,
    double? valorDesc,
    int? stock,
    int? cupoMaximoVariante,
    bool clearCupo = false,
    String? estado,
    String? imagenUrl,
  }) async {
    updatedId = presentationId;
    updatedOffer = oferta;
    updatedTipoDesc = tipoDesc;
    return true;
  }
}

class _ExpiringLicenseProv9E5 extends ChangeNotifier
    implements LicenseProvider {
  @override
  LicenseModel? get license => LicenseModel(
    deviceFingerprint: 'ML-9E5-FP',
    tipoPlan: 'MENSUAL',
    estadoActual: 'POR_VENCER',
    fechaInicio: DateTime.now().subtract(const Duration(days: 27)),
    fechaExpiracion: DateTime.now().add(const Duration(days: 3)),
    fechaUltimoCheck: DateTime.now(),
    eulaAcceptedVersion: LicenseRepository.canonicalEulaVersion,
    eulaAcceptedTimestamp: DateTime.now(),
    lastExecutedAppVersion: AppChangelogRegistry.currentVersion,
  );

  @override
  bool get isClockDesynced => false;

  @override
  bool get isStrictLock => false;

  @override
  bool get isPendingMigration => false;

  @override
  bool get isSoftLock => false;

  @override
  bool get isExpiringSoon => true;

  @override
  int get daysRemaining => 3;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _scaledMediaApp({required Size viewport, required Widget child}) {
  return MaterialApp(
    builder: (context, widget) => MediaQuery(
      data: MediaQueryData(
        size: viewport,
        padding: const EdgeInsets.only(top: 24),
        viewPadding: const EdgeInsets.only(top: 24),
        textScaler: const TextScaler.linear(1.3),
      ),
      child: widget!,
    ),
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;

  setUpAll(() async {
    await initializeDateFormatting('es', null);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    StartupFlowCoordinator.resetSessionStateForTesting();
    InteractiveTourService.autoTriggerOverrideForTesting = false;
    InteractiveTourService.resetRuntimeLockForTesting();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      LicenseRepository.deviceEulaVersionKey:
          LicenseRepository.canonicalEulaVersion,
      LicenseRepository.deviceEulaTimestampKey: '2026-11-27T01:00:00.000Z',
    });
    DeviceFingerprint.setMockFingerprint('ML-9E5-TEST');

    testDb = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
    );
    await LocalDatabase.createDBForTesting(testDb);
    LocalDatabase.setCustomDatabase(testDb);

    await testDb.insert('usuarios', {
      'id': 1,
      'nombre_completo': 'Vendedor Demo',
      'telefono': '999111222',
      'email': 'demo@mochilalista.pe',
      'activo': 1,
      'fecha_creacion': '2026-11-27T01:00:00.000Z',
    });
    await testDb.insert('negocios', {
      'id': 1,
      'nombre_comercial': 'Librería Escolares Perú',
      'ruc': '10456789012',
      'direccion': 'Av. Principal 100',
      'moneda': 'S/ (Soles)',
      'id_dueno': 1,
      'fecha_creacion': '2026-11-27T01:00:00.000Z',
    });
    final licenseRepo = LicenseRepository();
    await licenseRepo.getOrCreateLicense();
    await licenseRepo.recordEulaAcceptance(
      LicenseRepository.canonicalEulaVersion,
    );
    await licenseRepo.updateLastExecutedAppVersion(
      OwnerLegalIdentity.currentAppVersionWithBuild,
    );
  });

  tearDown(() async {
    DeviceFingerprint.setMockFingerprint(null);
    LocalDatabase.setCustomDatabase(null);
    InteractiveTourService.autoTriggerOverrideForTesting = null;
    await testDb.close();
  });

  group('Plan 25 Fase 9E-5 — Hito Final Bloque III (0 >= 800 L) y DRY', () {
    test(
      'Topes post-formato 9E-5, shrinkWrap=0 en 9E-5 y censo global 0 >= 800 L en app_movil/lib',
      () {
        final serviceFacades = <String>[
          'lib/features/smart_quotation/services/quotation_service.dart',
          'lib/features/profile/services/business_backup_service.dart',
        ];
        final serviceParts = <String>[
          'lib/features/smart_quotation/services/quotation/quotation_demand_part.dart',
          'lib/features/smart_quotation/services/quotation/quotation_validation_part.dart',
          'lib/features/smart_quotation/services/quotation/quotation_refresh_part.dart',
          'lib/features/profile/services/business_backup/business_backup_export_part.dart',
          'lib/features/profile/services/business_backup/business_backup_import_part.dart',
          'lib/features/profile/services/business_backup/business_backup_import_operations_part.dart',
        ];
        final uiCoordinators = <String>[
          'lib/core/widgets/discount_intelligent_modal.dart',
          'lib/features/smart_quotation/widgets/history/detail_widgets/whatsapp_preview_modal.dart',
          'lib/core/screens/home_screen.dart',
        ];
        final uiParts = <String>[
          'lib/core/widgets/discount_intelligent/discount_intelligent_controls_part.dart',
          'lib/core/widgets/discount_intelligent/discount_intelligent_preview_part.dart',
          'lib/features/smart_quotation/widgets/history/detail_widgets/whatsapp_preview/whatsapp_preview_message_builder_part.dart',
          'lib/features/smart_quotation/widgets/history/detail_widgets/whatsapp_preview/whatsapp_preview_sections_part.dart',
          'lib/core/screens/home/home_tabs_and_tours_part.dart',
          'lib/core/screens/home/home_dashboard_view_part.dart',
          'lib/core/screens/home/home_banners_part.dart',
        ];

        for (final path in serviceFacades) {
          expect(
            _countLines(path),
            lessThan(450),
            reason: '$path debe mantenerse < 450 L',
          );
        }
        for (final path in serviceParts) {
          expect(
            _countLines(path),
            lessThan(550),
            reason: '$path debe mantenerse < 550 L',
          );
        }
        for (final path in uiCoordinators) {
          expect(
            _countLines(path),
            lessThan(550),
            reason: '$path debe mantenerse < 550 L',
          );
        }
        for (final path in uiParts) {
          expect(
            _countLines(path),
            lessThan(600),
            reason: '$path debe mantenerse < 600 L',
          );
        }

        final libRoot = Directory('${_resolveAppMovilRoot()}/lib');
        final dartFiles = libRoot
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();

        final ge800 = <String>[];
        for (final f in dartFiles) {
          final lines = f.readAsLinesSync().length;
          if (lines >= 800) {
            ge800.add('${f.path}: $lines L');
          }
        }
        expect(
          ge800,
          isEmpty,
          reason:
              'Hito Final Bloque III exige FILES_GE_800L_IN_APP_MOVIL=0: $ge800',
        );

        final all9e5 = [
          ...serviceFacades,
          ...serviceParts,
          ...uiCoordinators,
          ...uiParts,
        ];
        for (final path in all9e5) {
          final content = File(
            '${_resolveAppMovilRoot()}/$path',
          ).readAsStringSync();
          expect(
            RegExp(r'shrinkWrap:\s*true').hasMatch(content),
            isFalse,
            reason: '$path no debe contener shrinkWrap: true',
          );
        }

        final waSections = File(
          '${_resolveAppMovilRoot()}/lib/features/smart_quotation/widgets/history/detail_widgets/whatsapp_preview/whatsapp_preview_sections_part.dart',
        ).readAsStringSync();
        expect(waSections, contains('WhatsAppUriBuilder.buildSendUri'));
        expect(waSections, contains('ClipboardHelper.copyWithFeedback'));
        expect(waSections, contains('AppFeedbackHelper.'));

        final discountPreview = File(
          '${_resolveAppMovilRoot()}/lib/core/widgets/discount_intelligent/discount_intelligent_preview_part.dart',
        ).readAsStringSync();
        expect(discountPreview, contains('AppCurrency.format'));
      },
    );

    test(
      'Paridad de importación directa, contratos de QuotationService y BusinessBackupService',
      () async {
        final qs = QuotationService();
        expect(qs.cloneQuotation, isA<Function>());
        expect(qs.validateIntegrity, isA<Function>());
        expect(qs.saveManualQuotation, isA<Function>());
        expect(qs.updateQuotationStatus, isA<Function>());
        expect(qs.refreshQuotation, isA<Function>());
        expect(qs.hardDeleteQuotation, isA<Function>());

        await expectLater(
          qs.saveManualQuotation(
            negocioId: 1,
            usuarioId: 1,
            totalAmount: 0,
            totalSavings: 0,
            items: const [],
          ),
          throwsArgumentError,
        );

        final qId = await qs.saveManualQuotation(
          negocioId: 1,
          usuarioId: 1,
          clientName: 'Cliente 9E5',
          totalAmount: 25.0,
          totalSavings: 0.0,
          items: [
            {
              'product_id': null,
              'presentation_id': null,
              'bundle_id': null,
              'quantity': 1,
              'unit_price_applied': 25.0,
              'original_unit_price': 25.0,
              'product_name': 'Ítem Manual',
            },
          ],
        );
        expect(qId, greaterThan(0));
        final integrity = await qs.validateIntegrity(qId);
        expect(integrity.hasIssues, isFalse);

        expect(BusinessBackupService.readBackupFile, isA<Function>());
        expect(BusinessBackupService.exportBusiness, isA<Function>());
        expect(BusinessBackupService.exportBusinessToFile, isA<Function>());
        expect(BusinessBackupService.pickBackupFile, isA<Function>());
        expect(BusinessBackupService.importBusiness, isA<Function>());

        await expectLater(
          BusinessBackupService.readBackupFile('/ruta/inexistente_9e5.mlb'),
          throwsException,
        );

        final tempDir = Directory.systemTemp.createTempSync('plan25_9e5_');
        try {
          final tempFile = File('${tempDir.path}/legacy_backup.mlb');
          tempFile.writeAsStringSync(
            jsonEncode({
              'version': 1,
              'has_security_pin': false,
              'data': {'negocios': []},
            }),
          );
          final parsed = await BusinessBackupService.readBackupFile(
            tempFile.path,
          );
          expect(parsed['version'], equals(1));
          expect(parsed['filePath'], equals(tempFile.path));
        } finally {
          tempDir.deleteSync(recursive: true);
        }

        expect(DiscountIntelligentModal.show, isA<Function>());
        expect(WhatsAppPreviewModal.showCuotaReminder, isA<Function>());
        expect(WhatsAppPreviewModal.showOverdueSummary, isA<Function>());
        expect(const HomeScreen(), isA<HomeScreen>());
        expect(HomeScreenTourKeys().bottomNavKey, isA<GlobalKey>());
      },
    );
  });

  group('Plan 25 Fase 9E-5 — Certificación Responsiva 0px Overflow @ 1.3x', () {
    const viewports = [Size(320, 568), Size(360, 640), Size(412, 915)];

    for (final viewport in viewports) {
      testWidgets(
        'DiscountIntelligentModal 0px @ 1.3x en ${viewport.width.toInt()}x${viewport.height.toInt()}dp',
        (tester) async {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final mockProv = _MockInventory9E5();
          final pres = ProductPresentation(
            id: 901,
            precioVentaFinal: 1850.50,
            precioOferta: 1499.90,
            tipoDescuento: 'fijo',
            valorDescuento: 1499.90,
            stockActual: 25,
          );

          await tester.pumpWidget(
            _scaledMediaApp(
              viewport: viewport,
              child: Scaffold(
                body: DiscountIntelligentModal(
                  presentation: pres,
                  provider: mockProv,
                  isDark: false,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.textContaining('Gestión de Descuento'), findsOneWidget);
          expect(find.textContaining(AppCurrency.format(1850.5)), findsWidgets);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'WhatsAppPreviewModal 0px @ 1.3x en ${viewport.width.toInt()}x${viewport.height.toInt()}dp',
        (tester) async {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final dueOld = DateTime.now()
              .subtract(const Duration(days: 10))
              .toIso8601String();
          final overdueCuotas = [
            {
              'numero_cuota': 1,
              'monto': 1500.00,
              'monto_original': 1400.00,
              'mora_monto': 100.00,
              'monto_pagado': 200.00,
              'fecha_vencimiento': dueOld,
            },
          ];

          await tester.pumpWidget(
            _scaledMediaApp(
              viewport: viewport,
              child: Scaffold(
                body: WhatsAppPreviewModal(
                  isDark: false,
                  initialClientName:
                      'Distribuidora Escolar Santa Rosa del Sur SAC',
                  initialClientPhone: '987654321',
                  multipleCuotas: overdueCuotas,
                  totalDebt: 1300.00,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Restaurar'), findsOneWidget);
          expect(find.text('Copiar'), findsOneWidget);
          expect(find.text('Enviar por WhatsApp'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'HomeScreen con banners (expiring + PIN) 0px @ 1.3x en ${viewport.width.toInt()}x${viewport.height.toInt()}dp',
        (tester) async {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final auth = AuthProvider();
          await auth.loginWithProfile(1);
          final licenseProv = _ExpiringLicenseProv9E5();
          final invProv = InventoryProvider()..updateContext(1);
          final promoProv = PromotionProvider()..updateContext(1, invProv);

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(value: auth),
                ChangeNotifierProvider<LicenseProvider?>.value(
                  value: licenseProv,
                ),
                ChangeNotifierProvider(create: (_) => ThemeProvider()),
                ChangeNotifierProvider<InventoryProvider>.value(value: invProv),
                ChangeNotifierProvider<PromotionProvider>.value(
                  value: promoProv,
                ),
                ChangeNotifierProvider(
                  create: (_) => CatalogProvider()..updateContext(1, 1),
                ),
                ChangeNotifierProvider(
                  create: (_) => WorkbenchProvider()..updateContext(1, 1),
                ),
                ChangeNotifierProvider(
                  create: (_) => SaleProvider()..updateContext(1, 1),
                ),
                ChangeNotifierProvider(
                  create: (_) =>
                      NotificationProvider()..updateContext(1, usuarioId: 1),
                ),
                ChangeNotifierProvider(
                  create: (_) => TrackingProvider()..updateContext(1, 1),
                ),
                ChangeNotifierProvider(
                  create: (_) =>
                      SmartQuotationProvider()..updateContext(1, 1, null),
                ),
                ChangeNotifierProvider(create: (_) => MatchingProvider()),
                ChangeNotifierProvider(
                  create: (_) => ScannerProvider()..updateContext(1, 1, null),
                ),
                ChangeNotifierProvider(
                  create: (_) => QuickSaleProvider()..updateContext(1, 1),
                ),
                ChangeNotifierProvider(
                  create: (_) => QuickSearchProvider()..updateContext(1),
                ),
              ],
              child: _scaledMediaApp(
                viewport: viewport,
                child: const HomeScreen(),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          expect(find.byType(NavigationBar), findsOneWidget);
          expect(find.textContaining('Suscripción por Vencer'), findsOneWidget);
          expect(
            find.textContaining('Protege tu negocio con un PIN'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
