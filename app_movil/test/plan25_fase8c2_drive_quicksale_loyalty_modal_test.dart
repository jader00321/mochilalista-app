import 'dart:io';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/google_drive_backup_provider.dart';
import 'package:app_movil/core/services/backup/i_google_drive_backup_service.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/profile/widgets/google_drive_backup_sheet.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_loyalty_history_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_sale_detail_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _FakeDriveService implements IGoogleDriveBackupService {
  GoogleDriveUser? user;
  DriveBackupConfig config = const DriveBackupConfig(isEnabled: true);
  final List<GoogleDriveBackupMetadata> backups = [];

  @override
  Future<GoogleDriveUser?> getCurrentUser() async => user;

  @override
  Future<DriveBackupConfig> getConfig() async => config;

  @override
  Future<void> saveConfig(DriveBackupConfig newConfig) async {
    config = newConfig;
  }

  @override
  Future<List<GoogleDriveBackupMetadata>> listBackups() async =>
      List.from(backups);

  @override
  Future<GoogleDriveUser?> signIn() async => user;

  @override
  Future<GoogleDriveUser?> signInSilently() async => user;

  @override
  Future<void> signOut() async {
    user = null;
    backups.clear();
  }

  @override
  Future<void> clearSession() async {
    user = null;
    backups.clear();
  }

  @override
  Future<GoogleDriveBackupMetadata?> uploadEncryptedBackup({
    String? customPassphrase,
  }) async => null;

  @override
  Future<DriveRestoreResult> downloadAndRestoreBackup(
    String fileId, {
    String? customPassphrase,
  }) async => DriveRestoreResult.successSameDevice(deviceId: 'DEV-8C2');

  @override
  Future<bool> checkAndTriggerScheduledBackup({bool? isWifiConnected}) async =>
      false;

  @override
  Future<void> registerTrialMarker(String hardwareId) async {}

  @override
  Future<bool> checkTrialMarkerExists(String hardwareId) async => false;
}

class _FakeInventoryProvider extends InventoryProvider {
  Product? mockProduct;

  @override
  Future<Product?> fetchProductById(int id) async => mockProduct;

  @override
  Future<Product?> getFullProductWithFallback(int id) async => mockProduct;

  @override
  String getCategoryName(int? id) => 'Escolar';

  @override
  String getBrandName(int? id) => 'Stanford';
}

class _MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  int? get activeBusinessId => 1;

  @override
  int? get activeUserId => 1;

  @override
  bool get hasActiveContext => true;

  @override
  String get businessName => 'Librería Central';

  @override
  String get activeBusinessName => 'Librería Central';

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

  setUpAll(() async {
    await initializeDateFormatting('es', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Plan 25 Fase 8C — Censo completo 8C-1 + 8C-2 y contratos 8C-2', () {
    test('Coordinadores < 600 L y sub-módulos 8C-1 + 8C-2 < 650 L sin excepción', () {
      final root = _resolveAppMovilRoot();

      for (final coord in const [
        // 8C-1
        'lib/features/smart_quotation/screens/crm/loyalty_center_screen.dart',
        'lib/features/profile/screens/notifications_screen.dart',
        'lib/features/profile/screens/profile_screen.dart',
        // 8C-2
        'lib/features/profile/widgets/google_drive_backup_sheet.dart',
        'lib/features/smart_quotation/widgets/quick_sale/quick_sale_detail_modal.dart',
        'lib/features/smart_quotation/widgets/crm/client_loyalty_history_modal.dart',
      ]) {
        expect(_lineCount(root, coord), lessThan(600), reason: coord);
      }

      for (final moduleFile in const [
        // 8C-1 sub-módulos
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
        // 8C-2 sub-módulos
        'lib/features/profile/widgets/google_drive/google_drive_restore_dialogs.dart',
        'lib/features/profile/widgets/google_drive/google_drive_oauth_and_direct_restore.dart',
        'lib/features/profile/widgets/google_drive/google_drive_actions_and_unlinked.dart',
        'lib/features/profile/widgets/google_drive/google_drive_connected_and_backups.dart',
        'lib/features/smart_quotation/widgets/quick_sale/detail_modal/quick_sale_detail_logic_mixin.dart',
        'lib/features/smart_quotation/widgets/quick_sale/detail_modal/quick_sale_header_section.dart',
        'lib/features/smart_quotation/widgets/quick_sale/detail_modal/quick_sale_variants_section.dart',
        'lib/features/smart_quotation/widgets/quick_sale/detail_modal/quick_sale_discount_and_totals_section.dart',
        'lib/features/smart_quotation/widgets/crm/loyalty_history/loyalty_history_manual_bonus_dialog.dart',
        'lib/features/smart_quotation/widgets/crm/loyalty_history/loyalty_history_movement_card.dart',
        'lib/features/smart_quotation/widgets/crm/loyalty_history/loyalty_history_rewards_progress_section.dart',
      ]) {
        expect(_lineCount(root, moduleFile), lessThan(650), reason: moduleFile);
      }

      // Paridad de símbolos públicos importados desde rutas originales
      expect(GoogleDriveBackupSheet, isNotNull);
      expect(QuickSaleDetailModal, isNotNull);
      expect(ClientLoyaltyHistoryModal, isNotNull);
      expect(const BoxFormatConstraints(maxHeight: 500).maxHeight, equals(500));
    });
  });

  group('Plan 25 Fase 8C-2 — Paridad Visual 0px Overflow @ TextScaler 1.3x', () {
    for (final size in const [
      Size(320, 568),
      Size(360, 640),
      Size(412, 915),
    ]) {
      testWidgets(
        'GoogleDriveBackupSheet, QuickSaleDetailModal y ClientLoyaltyHistoryModal en ${size.width.toInt()}x${size.height.toInt()}dp @ 1.3x',
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

          try {
            // 1A. GoogleDriveBackupSheet — Estado No Vinculado
            currentStage = 'GoogleDriveBackupSheet (no vinculado)';
            final unlinkedService = _FakeDriveService();
            final unlinkedProv = GoogleDriveBackupProvider(
              service: unlinkedService,
              cacheTtl: const Duration(minutes: 5),
            );
            await tester.runAsync(() => unlinkedProv.initializeFromCache());

            await tester.pumpWidget(
              ChangeNotifierProvider<GoogleDriveBackupProvider?>.value(
                value: unlinkedProv,
                child: _wrapWithTextScaler(
                  const Scaffold(body: GoogleDriveBackupSheet()),
                ),
              ),
            );
            await tester.pump();
            expect(find.byType(GoogleDriveBackupSheet), findsOneWidget);

            // 1B. GoogleDriveBackupSheet — Estado Vinculado con copia
            currentStage = 'GoogleDriveBackupSheet (vinculado)';
            final linkedService = _FakeDriveService()
              ..user = const GoogleDriveUser(
                id: 'g_user_8c2',
                email: 'libreria.central@gmail.com',
                displayName: 'Librería Central',
              )
              ..backups.add(
                GoogleDriveBackupMetadata(
                  fileId: 'backup_1',
                  fileName: 'MochilaLista_2026_11.mlbg',
                  createdAt: DateTime(2026, 11, 20, 14, 30),
                  sizeBytes: 98400,
                ),
              );
            final linkedProv = GoogleDriveBackupProvider(
              service: linkedService,
              cacheTtl: const Duration(minutes: 5),
            );
            await tester.runAsync(() => linkedProv.initializeFromCache());

            await tester.pumpWidget(
              ChangeNotifierProvider<GoogleDriveBackupProvider?>.value(
                value: linkedProv,
                child: _wrapWithTextScaler(
                  const Scaffold(body: GoogleDriveBackupSheet()),
                ),
              ),
            );
            await tester.pump();
            expect(find.text('libreria.central@gmail.com'), findsOneWidget);

            // 2. QuickSaleDetailModal (con múltiples variantes y stock compartido)
            currentStage = 'QuickSaleDetailModal';
            final matched = MatchedProduct(
              productId: 1,
              presentationId: 10,
              fullName: 'Cuaderno A4 Rayado Standford Caja',
              productName: 'Cuaderno A4 Rayado Standford',
              brand: '1',
              price: 45.0,
              offerPrice: 40.0,
              stock: 11,
              unit: '½ Docena',
              conversionFactor: 6,
              usaStockCompartido: true,
              sharedStockPool: 68,
              cupoMaximoVariante: 9,
            );
            final fullProd = Product(
              id: 1,
              nombre: 'Cuaderno A4 Rayado Standford',
              categoriaId: 1,
              marcaId: 1,
              modoStock: 'COMPARTIDO',
              stockCompartido: 68,
              costoBase: 2.0,
              presentaciones: [
                ProductPresentation(
                  id: 10,
                  nombreEspecifico: 'Media Docena',
                  unidadVenta: '½ Docena',
                  unidadesPorVenta: 6,
                  precioVentaFinal: 45.0,
                  precioOferta: 40.0,
                  costoUnitarioCalculado: 2.0,
                  usaStockCompartido: true,
                  cupoMaximoVariante: 9,
                  stockActual: 68,
                ),
                ProductPresentation(
                  id: 11,
                  nombreEspecifico: 'Unidad',
                  unidadVenta: 'Unidad',
                  unidadesPorVenta: 1,
                  precioVentaFinal: 8.5,
                  costoUnitarioCalculado: 2.0,
                  usaStockCompartido: true,
                  stockActual: 68,
                ),
              ],
            );
            final fakeInv = _FakeInventoryProvider()..mockProduct = fullProd;

            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<InventoryProvider>.value(value: fakeInv),
                  ChangeNotifierProvider<QuickSaleProvider>(
                    create: (_) => QuickSaleProvider(),
                  ),
                  ChangeNotifierProvider<AuthProvider>.value(
                    value: _MockAuthProvider(),
                  ),
                ],
                child: _wrapWithTextScaler(
                  Scaffold(
                    body: QuickSaleDetailModal(
                      product: matched,
                      initialQty: 2,
                      onConfirm: (_, __, ___, ____) {},
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('GUARDAR CAMBIOS'), findsOneWidget);

            // 3. ClientLoyaltyHistoryModal (Tabs 0 y 1 con movimiento de puntos)
            final client = ClientModel(
              id: 10,
              negocioId: 1,
              creadoPorUsuarioId: 1,
              fullName: 'María Peña Canción',
              phone: '999888777',
              puntosActuales: 140,
              puntosHistoricos: 220,
              scoreReputacion: 620,
              nivelReputacion: 'PLATA',
              saldoAFavor: 25.0,
              rachaPagosPuntuales: 4,
              registeredDate: '2026-10-01',
            );
            final movement = LoyaltyLedgerModel(
              id: 1,
              negocioId: 1,
              clienteId: 10,
              tipoMovimiento: 'GANANCIA_COMPRA',
              puntosDelta: 40,
              puntosSaldoResultante: 140,
              scoreDelta: 10,
              scoreResultante: 620,
              motivo: 'Compra en Caja Rápida #104',
              fechaRegistro: '2026-11-20T10:30:00',
            );

            for (final tab in const [0, 1]) {
              currentStage = 'ClientLoyaltyHistoryModal tab=$tab';
              await tester.pumpWidget(
                MultiProvider(
                  providers: [
                    ChangeNotifierProvider<TrackingProvider>(
                      create: (_) => TrackingProvider(),
                    ),
                    ChangeNotifierProvider<AuthProvider>.value(
                      value: _MockAuthProvider(),
                    ),
                    ChangeNotifierProvider<QuickSaleProvider>(
                      create: (_) => QuickSaleProvider(),
                    ),
                  ],
                  child: _wrapWithTextScaler(
                    Scaffold(
                      body: ClientLoyaltyHistoryModal(
                        client: client,
                        autoLoadHistory: false,
                        initialMovements: [movement],
                        initialTabIndex: tab,
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 200));
              expect(find.byType(ClientLoyaltyHistoryModal), findsOneWidget);
            }

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
