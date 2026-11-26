import 'dart:io';

import 'package:app_movil/core/database/database_connection_factory.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_finance_actions_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/payment_entry_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/cuota_morosidad_modal.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;

  setUpAll(() async {
    await initializeDateFormatting('es', null);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseConnectionFactory.isTestMode = true;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    testDb = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 36,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await LocalDatabase.createDBForTesting(db);
        },
      ),
    );
    LocalDatabase.setCustomDatabase(testDb);
  });

  tearDown(() async {
    LocalDatabase.setCustomDatabase(null);
    await testDb.close();
  });

  group('Plan 25 Fase 8B — Censo estricto de líneas y barrel limpio', () {
    test('crm_models.dart es barrel < 40 L y todos los archivos Fase 8B cumplen límites', () {
      final root = _resolveAppMovilRoot();
      final sep = Platform.pathSeparator;

      final barrelFile = File(
        '${root.path}${sep}lib/features/smart_quotation/models/crm_models.dart'.replaceAll('/', sep),
      );
      expect(barrelFile.readAsLinesSync().length, lessThan(40));
      expect(barrelFile.readAsStringSync().contains('class '), isFalse);

      for (final modelFile in const [
        'lib/features/smart_quotation/models/crm_parse_helpers.dart',
        'lib/features/smart_quotation/models/client_model.dart',
        'lib/features/smart_quotation/models/payment_and_ledger_models.dart',
        'lib/features/smart_quotation/models/sale_and_installment_models.dart',
        'lib/features/smart_quotation/models/quotation_validation_models.dart',
        'lib/features/smart_quotation/models/reputation_tier_model.dart',
        'lib/features/smart_quotation/models/loyalty_models.dart',
      ]) {
        expect(_lineCount(root, modelFile), lessThan(550), reason: modelFile);
      }

      for (final coord in const [
        'lib/features/smart_quotation/widgets/crm/client_finance_actions_modal.dart',
        'lib/features/smart_quotation/widgets/history/detail_widgets/cuota_morosidad_modal.dart',
        'lib/features/smart_quotation/widgets/crm/payment_entry_modal.dart',
      ]) {
        expect(_lineCount(root, coord), lessThan(550), reason: coord);
      }

      for (final partFile in const [
        'lib/features/smart_quotation/widgets/crm/finance_actions/client_finance_draft_manager.dart',
        'lib/features/smart_quotation/widgets/crm/finance_actions/client_finance_draft_and_submit.dart',
        'lib/features/smart_quotation/widgets/crm/finance_actions/client_finance_loan_schedule_logic.dart',
        'lib/features/smart_quotation/widgets/crm/finance_actions/client_finance_installment_dialog.dart',
        'lib/features/smart_quotation/widgets/crm/finance_actions/client_finance_confirmation_dialogs.dart',
        'lib/features/smart_quotation/widgets/crm/finance_actions/client_finance_withdraw_and_cards.dart',
        'lib/features/smart_quotation/widgets/crm/finance_actions/client_finance_loan_tab.dart',
        'lib/features/smart_quotation/widgets/crm/finance_actions/client_finance_loan_schedule_section.dart',
        'lib/features/smart_quotation/widgets/crm/finance_actions/client_finance_inputs_and_one_quota.dart',
        'lib/features/smart_quotation/widgets/history/detail_widgets/cuota_morosidad_manual_section.dart',
        'lib/features/smart_quotation/widgets/history/detail_widgets/cuota_morosidad_auto_section.dart',
        'lib/features/smart_quotation/widgets/history/detail_widgets/cuota_morosidad_preview_actions.dart',
        'lib/features/smart_quotation/widgets/crm/payment_entry_header_and_chips.dart',
        'lib/features/smart_quotation/widgets/crm/payment_entry_specific_and_submit.dart',
      ]) {
        expect(_lineCount(root, partFile), lessThan(650), reason: partFile);
      }
    });
  });

  group('Plan 25 Fase 8B — Paridad de barrels, modelos CRM y ClientFinanceDraftManager', () {
    test('Barrel crm_models y re-exports de client_finance_actions_modal operan al 100%', () {
      final client = ClientModel(
        id: 88,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Lucía Paredes',
        phone: '987654321',
        registeredDate: '2026-11-01',
        totalDebt: 200.0,
        saldoAFavor: 120.0,
        scoreReputacion: 650,
      );
      expect(client.tier, ReputationTier.fromScore(650));

      final cuota = InstallmentModel(
        installmentNumber: 1,
        amount: 100.0,
        dueDate: '2026-12-01',
        status: 'pendiente',
      );
      final sale = SaleModel(
        id: 10,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        clientId: 88,
        paymentMethod: 'credito',
        paymentStatus: 'pendiente',
        deliveryStatus: 'pendiente',
        totalAmount: 100.0,
        paidAmount: 0.0,
        discount: 0.0,
        saleDate: '2026-11-26',
        installments: [cuota],
      );
      expect(sale.pendingDebt, 100.0);

      final val = ValidationResult(
        hasIssues: false,
        canSell: true,
        stockWarnings: const [],
        priceChanges: const [],
      );
      expect(val.canSell, isTrue);

      final stats = SalesStatsModel(
        totalIngresos: 500.0,
        totalDeuda: 100.0,
        cantidadVentas: 2,
      );
      expect(stats.cantidadVentas, 2);

      final mgr = ClientFinanceDraftManager.instance;
      mgr.clearAll(88);
      mgr.setActiveTab(88, 1);
      expect(mgr.getActiveTab(88), 1);

      mgr.setWithdrawDraft(88, FinanceWithdrawDraft(amount: '75.00', method: 'Yape'));
      expect(mgr.getWithdrawDraft(88)?.amount, '75.00');

      mgr.setLoanDraft(
        88,
        FinanceLoanDraft(
          amount: '300.00',
          method: 'Efectivo',
          motivo: 'Stock escolar',
          splitInQuotas: true,
          numCuotas: '3',
          interestRate: '5',
          installments: [cuota],
        ),
      );
      expect(mgr.getLoanDraft(88)?.motivo, 'Stock escolar');

      mgr.clearWithdrawDraft(88);
      expect(mgr.getWithdrawDraft(88), isNull);
      expect(mgr.getLoanDraft(88), isNotNull);

      mgr.clearAll(88);
      expect(mgr.getLoanDraft(88), isNull);
    });
  });

  group('Plan 25 Fase 8B — 0px Overflow en 3 viewports con TextScaler.linear(1.3)', () {
    const viewports = <Size>[
      Size(320, 568),
      Size(360, 640),
      Size(412, 915),
    ];

    for (final size in viewports) {
      testWidgets(
        'ClientFinanceActionsModal, CuotaMorosidadModal y PaymentEntryModal sin overflow en ${size.width.toInt()}x${size.height.toInt()}dp @ 1.3x',
        (tester) async {
          tester.view.physicalSize = Size(size.width * 2.0, size.height * 2.0);
          tester.view.devicePixelRatio = 2.0;

          final capturedErrors = <FlutterErrorDetails>[];
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            capturedErrors.add(details);
          };

          final client = ClientModel(
            id: 501,
            negocioId: 1,
            creadoPorUsuarioId: 1,
            fullName: 'Rosa Quispe Huamán',
            phone: '999444333',
            registeredDate: '2026-10-01',
            totalDebt: 240.0,
            saldoAFavor: 180.0,
            scoreReputacion: 720,
          );

          final cuota = <String, dynamic>{
            'id': 15,
            'numero_cuota': 1,
            'monto': 120.0,
            'monto_original': 120.0,
            'monto_pagado': 20.0,
            'mora_monto': 0.0,
            'mora_activa': 0,
            'mora_automatica': 0,
            'fecha_vencimiento': '2025-11-15',
            'estado': 'pendiente',
          };

          try {
            // 1. ClientFinanceActionsModal (Tab Préstamo + Tab Retiro)
            for (final tab in const [0, 1]) {
              await tester.pumpWidget(
                MultiProvider(
                  providers: [
                    ChangeNotifierProvider(create: (_) => TrackingProvider()),
                  ],
                  child: MaterialApp(
                    builder: (ctx, child) => MediaQuery(
                      data: MediaQuery.of(ctx).copyWith(
                        textScaler: const TextScaler.linear(1.3),
                      ),
                      child: child!,
                    ),
                    home: Scaffold(
                      body: ClientFinanceActionsModal(
                        client: client,
                        isDark: true,
                        initialTab: tab,
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump(const Duration(milliseconds: 350));
              expect(find.byType(ClientFinanceActionsModal), findsOneWidget);
            }

            // 2. CuotaMorosidadModal
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider(create: (_) => SaleProvider()),
                ],
                child: MaterialApp(
                  builder: (ctx, child) => MediaQuery(
                    data: MediaQuery.of(ctx).copyWith(
                      textScaler: const TextScaler.linear(1.3),
                    ),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: CuotaMorosidadModal(
                      cuota: cuota,
                      isDark: false,
                      onSaved: () {},
                    ),
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 350));
            expect(find.byType(CuotaMorosidadModal), findsOneWidget);

            // 3. PaymentEntryModal
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider(create: (_) => TrackingProvider()),
                  ChangeNotifierProvider(create: (_) => SaleProvider()),
                ],
                child: MaterialApp(
                  builder: (ctx, child) => MediaQuery(
                    data: MediaQuery.of(ctx).copyWith(
                      textScaler: const TextScaler.linear(1.3),
                    ),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: PaymentEntryModal(client: client),
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 350));
            expect(find.byType(PaymentEntryModal), findsOneWidget);

            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();

            final overflowErrors = capturedErrors
                .where(
                  (e) =>
                      e.exceptionAsString().toLowerCase().contains('overflowed'),
                )
                .toList();
            expect(
              overflowErrors,
              isEmpty,
              reason:
                  'Overflow detectado en ${size.width}x${size.height} @ 1.3x: ${overflowErrors.map((e) => e.exceptionAsString()).join('\n')}',
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
