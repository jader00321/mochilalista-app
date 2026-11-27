import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/models/ai_key_model.dart';
import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/backup_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/services/ai/ai_vault_service.dart';
import 'package:app_movil/core/services/backup/i_google_drive_backup_service.dart';
import 'package:app_movil/core/widgets/tour/configs/ai_settings_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/backup_screen_tour.dart';
import 'package:app_movil/features/profile/screens/ai_settings_screen.dart';
import 'package:app_movil/features/profile/screens/backup_screen.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/ledger_timeline_tab.dart';
import 'package:app_movil/features/smart_quotation/widgets/matching/matching_item_row.dart';

class _MockAuth9D5 extends ChangeNotifier implements AuthProvider {
  late final BusinessModel _business = BusinessModel(
    id: 1,
    commercialName: 'Librería Plan 25 9D-5',
    address: 'Av. Los Próceres 450',
    moneda: 'S/ (Soles)',
  );

  late final UserModel _user = UserModel(
    id: 1,
    fullName: 'Julio Administrador',
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
  bool get hasPinCache => true;

  @override
  String get userName => _user.fullName;

  @override
  String get businessName => _business.commercialName;

  @override
  String get errorMessage => '';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockLicense9D5 extends ChangeNotifier implements LicenseProvider {
  String _selectedMode = 'BYOK';

  @override
  bool get isActive => true;

  @override
  bool get isPerpetual => false;

  @override
  String get currentPlanName => 'MENSUAL';

  @override
  LicenseModel? get license => null;

  @override
  String get aiSelectedMode => _selectedMode;

  @override
  bool get isUsingByokMode => _selectedMode == 'BYOK';

  @override
  int get remainingAiScans => 42;

  @override
  int get aiAccumulatedScans => 42;

  @override
  Future<void> refreshAiScans({DateTime? overrideNow}) async {}

  @override
  Future<void> setAiSelectedMode(String mode) async {
    _selectedMode = mode;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockBackupProvider9D5 extends ChangeNotifier implements BackupProvider {
  bool _autoEnabled = true;
  String _autoType = 'ambos';
  String _autoLocation = 'custom';
  int _intervalDays = 15;

  @override
  bool get isLoading => false;

  @override
  String get errorMessage => '';

  @override
  String get statusMessage => '';

  @override
  bool get isAutoBackupEnabled => _autoEnabled;

  @override
  String get autoBackupType => _autoType;

  @override
  String get autoBackupLocation => _autoLocation;

  @override
  String? get autoBackupCustomPath =>
      '/storage/emulated/0/Documents/MochilaLista/Backups';

  @override
  int get autoBackupIntervalDays => _intervalDays;

  @override
  int get lastRegisterTime =>
      DateTime(2026, 11, 20, 10, 0).millisecondsSinceEpoch;

  @override
  int get lastRunTime => DateTime(2026, 11, 22, 14, 30).millisecondsSinceEpoch;

  @override
  Future<void> reloadTimestamps() async {}

  @override
  Future<void> toggleAutoBackup(bool value) async {
    _autoEnabled = value;
    notifyListeners();
  }

  @override
  Future<void> setAutoBackupType(
    String value, {
    int? negocioId,
    String? negocioNombre,
  }) async {
    _autoType = value;
    notifyListeners();
  }

  @override
  Future<void> setAutoBackupInterval(int days) async {
    _intervalDays = days;
    notifyListeners();
  }

  @override
  Future<void> setAutoBackupLocation(
    String location, {
    String? customPath,
  }) async {
    _autoLocation = location;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockDriveBackupService9D5 implements IGoogleDriveBackupService {
  GoogleDriveUser? _user = const GoogleDriveUser(
    id: 'drive_9d5',
    email: 'libreria.plan25@gmail.com',
    displayName: 'Librería Plan 25',
  );
  DriveBackupConfig _config = const DriveBackupConfig(
    isEnabled: true,
    frequency: BackupFrequency.daily,
  );

  @override
  Future<GoogleDriveUser?> getCurrentUser() async => _user;

  @override
  Future<GoogleDriveUser?> signIn() async => _user;

  @override
  Future<GoogleDriveUser?> signInSilently() async => _user;

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<void> clearSession() async => _user = null;

  @override
  Future<DriveBackupConfig> getConfig() async => _config;

  @override
  Future<void> saveConfig(DriveBackupConfig config) async => _config = config;

  @override
  Future<List<GoogleDriveBackupMetadata>> listBackups() async => [
    GoogleDriveBackupMetadata(
      fileId: 'drv_1',
      fileName: 'MochilaLista_20261126.mlbg',
      createdAt: DateTime(2026, 11, 26, 9, 0),
      sizeBytes: 128000,
    ),
  ];

  @override
  Future<GoogleDriveBackupMetadata?> uploadEncryptedBackup({
    String? customPassphrase,
  }) async => null;

  @override
  Future<DriveRestoreResult> downloadAndRestoreBackup(
    String fileId, {
    String? customPassphrase,
  }) async => DriveRestoreResult(
    isSuccess: true,
    isSameDevice: true,
    requiresLicenseMigration: false,
    message: 'OK',
  );

  @override
  Future<bool> checkAndTriggerScheduledBackup({bool? isWifiConnected}) async =>
      true;

  @override
  Future<void> registerTrialMarker(String hardwareId) async {}

  @override
  Future<bool> checkTrialMarkerExists(String hardwareId) async => true;
}

class _MockMatchingProvider9D5 extends ChangeNotifier
    implements MatchingProvider {
  int? lastUpdatedItemId;
  int? lastUpdatedQty;

  @override
  Map<int, int> get sharedDemandPerProduct => const <int, int>{10: 65};

  @override
  void updatePairQuantity(int sourceItemId, int newQty) {
    lastUpdatedItemId = sourceItemId;
    lastUpdatedQty = newQty;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockTrackingProvider9D5 extends ChangeNotifier
    implements TrackingProvider {
  late List<LedgerItem> _ledger = _buildSampleLedger();

  static List<LedgerItem> _buildSampleLedger() {
    return [
      LedgerItem(
        idRef: 1,
        tipo: 'cargo',
        subtipo: 'prestamo',
        fecha: DateTime(2026, 11, 24, 10, 30),
        monto: 325.50,
        montoBase: 300.00,
        moraMonto: 25.50,
        detalle: 'Préstamo Escolar Campaña Marzo - Cliente Frecuente',
        saldoResultante: 325.50,
        ventaId: 501,
        nota: 'Cuotas mensuales acordadas',
        canDelete: true,
      ),
      LedgerItem(
        idRef: 2,
        tipo: 'abono',
        subtipo: 'pago',
        fecha: DateTime(2026, 11, 25, 16, 45),
        monto: 120.00,
        detalle: 'Abono Cuota #1 Vía Yape Empresarial',
        saldoResultante: 205.50,
        ventaId: 501,
        pagoId: 801,
        metodoPago: 'Yape',
        nota: 'Abono histórico verificado en caja',
        canEdit: true,
        canDelete: true,
      ),
      LedgerItem(
        idRef: 3,
        tipo: 'evento',
        tipoEvento: 'reprogramacion_fecha',
        fecha: DateTime(2026, 11, 26, 9, 15),
        monto: 0.0,
        detalle: 'Reprogramación de vencimiento de cuota #2',
        saldoResultante: 205.50,
        eventoId: 901,
        nota: 'Acordado por WhatsApp',
        canDelete: true,
      ),
    ];
  }

  void setEmptyLedger() {
    _ledger = const <LedgerItem>[];
    notifyListeners();
  }

  @override
  bool get isLoadingLedger => false;

  @override
  List<LedgerItem> get currentClientLedger => _ledger;

  @override
  Future<bool> editarPago(
    int clientId,
    int pagoId, {
    required double nuevoMonto,
    required String nuevoMetodoPago,
    DateTime? nuevaFechaPago,
    String? nuevaNota,
  }) async => true;

  @override
  Future<bool> revertirPago(int clientId, int pagoId) async => true;

  @override
  Future<bool> revertirVentaOPrestamo(int clientId, int ventaId) async => true;

  @override
  Future<bool> eliminarEventoFinanciero(int clientId, int eventoId) async =>
      true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _setTestViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  await tester.binding.setSurfaceSize(size);
}

Future<void> _resetTestViewport(WidgetTester tester) async {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
  await tester.binding.setSurfaceSize(null);
}

int _countLines(String relativePath) {
  final file = File(relativePath);
  expect(file.existsSync(), isTrue, reason: 'No existe $relativePath');
  return file.readAsLinesSync().length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es', null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/package_info'),
          (call) async => <String, dynamic>{
            'appName': 'MochilaLista',
            'packageName': 'com.mochilalista.app',
            'version': '9.41.0',
            'buildNumber': '85',
          },
        );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'pin_delay_minutes': 5,
      'tour_screen_seen_backup_screen': true,
      'tour_screen_seen_ai_settings_screen': true,
    });
    final sampleKeys = [
      AiKeyModel(
        id: 'key_1',
        alias: 'Gmail Corporativo Librería Principal',
        apiKey: 'AIzaSyTestPrimaryKey1234567890ABCD',
        createdAt: DateTime(2026, 11, 10),
        lastTestedAt: DateTime(2026, 11, 26, 11, 30),
        isWorking: true,
      ).toMap(),
      AiKeyModel(
        id: 'key_2',
        alias: 'Respaldo Sucursal Centro',
        apiKey: 'AIzaSyTestBackupKey0987654321WXYZ',
        createdAt: DateTime(2026, 11, 12),
        lastTestedAt: DateTime(2026, 11, 25, 18, 45),
        isWorking: false,
      ).toMap(),
    ];
    FlutterSecureStorage.setMockInitialValues({
      AiVaultService.vaultStorageKey: jsonEncode(sampleKeys),
      AiVaultService.activeKeyIdStorageKey: 'key_1',
    });
  });

  group('Plan Maestro 25 - Fase 9D-5: Censo Modular, DRY y Contratos', () {
    test(
      'Todos los coordinadores (< 600 L) y sub-módulos (<= 600 L) cumplen límites',
      () {
        const coordinators = [
          'lib/features/profile/screens/ai_settings_screen.dart',
          'lib/features/profile/screens/backup_screen.dart',
          'lib/features/smart_quotation/widgets/matching/matching_item_row.dart',
          'lib/features/smart_quotation/widgets/crm/ledger_timeline_tab.dart',
        ];
        const submodules = [
          'lib/features/profile/screens/ai_settings/ai_settings_dialogs_and_actions_mixin.dart',
          'lib/features/profile/screens/ai_settings/ai_settings_quota_and_mode_mixin.dart',
          'lib/features/profile/screens/ai_settings/ai_settings_vault_and_guide_mixin.dart',
          'lib/features/profile/screens/backup/backup_action_tiles.dart',
          'lib/features/profile/screens/backup/backup_auto_and_security_widgets.dart',
          'lib/features/profile/screens/backup/backup_local_sections_mixin.dart',
          'lib/features/profile/screens/backup/backup_smart_business_section.dart',
          'lib/features/smart_quotation/widgets/matching/item_row/matching_item_side_panels_mixin.dart',
          'lib/features/smart_quotation/widgets/matching/item_row/matching_item_linked_header_mixin.dart',
          'lib/features/smart_quotation/widgets/matching/item_row/matching_item_linked_body_mixin.dart',
          'lib/features/smart_quotation/widgets/crm/ledger_timeline/ledger_timeline_card_mixin.dart',
          'lib/features/smart_quotation/widgets/crm/ledger_timeline/ledger_timeline_modals_mixin.dart',
        ];

        for (final path in coordinators) {
          expect(
            _countLines(path),
            lessThan(600),
            reason: 'Coordinador $path debe tener < 600 L',
          );
        }
        for (final path in submodules) {
          expect(
            _countLines(path),
            lessThanOrEqualTo(600),
            reason: 'Sub-módulo $path debe tener <= 600 L',
          );
        }
      },
    );

    test(
      'Adopción DRY (AppDateFormatter, AppFeedbackHelper, AppCurrency, ClipboardHelper, UniversalImage) y exports públicos',
      () {
        final aiSrc = [
          'lib/features/profile/screens/ai_settings_screen.dart',
          'lib/features/profile/screens/ai_settings/ai_settings_dialogs_and_actions_mixin.dart',
          'lib/features/profile/screens/ai_settings/ai_settings_vault_and_guide_mixin.dart',
        ].map((p) => File(p).readAsStringSync()).join('\n');
        expect(aiSrc.contains('AppDateFormatter.ddMMHHmm'), isTrue);
        expect(aiSrc.contains('AppFeedbackHelper.'), isTrue);
        expect(aiSrc.contains('ClipboardHelper.copyWithFeedback'), isTrue);
        expect(aiSrc.contains('DateFormat('), isFalse);
        expect(aiSrc.contains('CustomSnackBar.'), isFalse);

        final backupSrc = [
          'lib/features/profile/screens/backup_screen.dart',
          'lib/features/profile/screens/backup/backup_local_sections_mixin.dart',
          'lib/features/profile/screens/backup/backup_smart_business_section.dart',
        ].map((p) => File(p).readAsStringSync()).join('\n');
        expect(backupSrc.contains('AppFeedbackHelper.'), isTrue);
        expect(backupSrc.contains('CustomSnackBar.'), isFalse);

        final rowSrc = [
          'lib/features/smart_quotation/widgets/matching/matching_item_row.dart',
          'lib/features/smart_quotation/widgets/matching/item_row/matching_item_side_panels_mixin.dart',
          'lib/features/smart_quotation/widgets/matching/item_row/matching_item_linked_header_mixin.dart',
          'lib/features/smart_quotation/widgets/matching/item_row/matching_item_linked_body_mixin.dart',
        ].map((p) => File(p).readAsStringSync()).join('\n');
        expect(rowSrc.contains('AppCurrency.format'), isTrue);
        expect(rowSrc.contains('AppFeedbackHelper.showError'), isTrue);
        expect(rowSrc.contains('UniversalImage'), isTrue);
        expect(rowSrc.contains('CustomSnackBar.'), isFalse);
        expect(rowSrc.contains("ValueKey('unlinked')"), isTrue);
        expect(
          rowSrc.contains(r"ValueKey('linked_${product.productId}')"),
          isTrue,
        );

        final ledgerSrc = [
          'lib/features/smart_quotation/widgets/crm/ledger_timeline_tab.dart',
          'lib/features/smart_quotation/widgets/crm/ledger_timeline/ledger_timeline_card_mixin.dart',
          'lib/features/smart_quotation/widgets/crm/ledger_timeline/ledger_timeline_modals_mixin.dart',
        ].map((p) => File(p).readAsStringSync()).join('\n');
        expect(ledgerSrc.contains('AppDateFormatter.'), isTrue);
        expect(ledgerSrc.contains('AppCurrency.format'), isTrue);
        expect(ledgerSrc.contains('AppFeedbackHelper.showSnackBar'), isTrue);
        expect(ledgerSrc.contains('DateFormat('), isFalse);
        expect(ledgerSrc.contains('ScaffoldMessenger.'), isFalse);
        expect(ledgerSrc.contains(RegExp(r"ValueKey\(\s*'empty_")), isTrue);
        expect(ledgerSrc.contains(RegExp(r"ValueKey\(\s*'list_")), isTrue);
      },
    );

    testWidgets(
      'Paridad funcional: TourKeys, ValueKeys en MatchingItemRow y filtros en LedgerTimelineTab',
      (tester) async {
        final aiTourKeys = AiSettingsTourKeys();
        final backupTourKeys = BackupScreenTourKeys();
        final matchingProv = _MockMatchingProvider9D5();
        final ledgerProv = _MockTrackingProvider9D5();

        expect(
          BackupScreenTour.buildConfig(keys: backupTourKeys).screenId,
          'backup_screen',
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<LicenseProvider?>.value(
            value: _MockLicense9D5(),
            child: MaterialApp(
              home: AiSettingsScreen(
                autoTriggerTour: false,
                tourKeys: aiTourKeys,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(aiTourKeys.modeSelectorKey), findsOneWidget);
        expect(find.byKey(aiTourKeys.quotaCardKey), findsOneWidget);
        expect(find.byKey(aiTourKeys.vaultKey), findsOneWidget);
        expect(find.byKey(aiTourKeys.securityGuideKey), findsOneWidget);
        expect(find.text('En Uso'), findsOneWidget);

        // MatchingItemRow unlinked vs linked ValueKeys & expand toggle
        final unlinkedPair = MatchPair(
          sourceItem: ExtractedItem(
            id: 10,
            originalText: '1 Cartulina',
            fullName: 'Cartulina Fosforescente',
            quantity: 1,
          ),
          status: MatchStatus.none,
        );
        await tester.pumpWidget(
          ChangeNotifierProvider<MatchingProvider>.value(
            value: matchingProv,
            child: MaterialApp(
              home: Scaffold(
                body: MatchingItemRow(
                  pair: unlinkedPair,
                  index: 0,
                  isClient: false,
                  onTapProduct: () {},
                  onChangeRequest: () {},
                  onDelete: () {},
                  onUnlink: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(const ValueKey('unlinked')), findsOneWidget);

        // LedgerTimelineTab: ValueKeys list & empty filtro
        await tester.pumpWidget(
          ChangeNotifierProvider<TrackingProvider>.value(
            value: ledgerProv,
            child: const MaterialApp(
              home: Scaffold(body: LedgerTimelineTab(clientId: 50)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('list_all_false')), findsOneWidget);

        await tester.tap(find.text('Vista Cliente'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('list_all_true')), findsOneWidget);
        expect(
          find.text('Reprogramación de vencimiento de cuota #2'),
          findsNothing,
        );
      },
    );
  });

  group('Plan Maestro 25 - Fase 9D-5: Responsividad 0px Overflow @ 1.3x', () {
    const viewports = <Size>[Size(320, 568), Size(360, 640), Size(412, 915)];

    Widget wrapViewport(Size size, Widget child) {
      return MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: const TextScaler.linear(1.3),
        ),
        child: MaterialApp(home: child),
      );
    }

    for (final vp in viewports) {
      testWidgets(
        'AiSettingsScreen con Bóveda multi-clave 0px Overflow en ${vp.width.toInt()}x${vp.height.toInt()}dp @ 1.3x',
        (tester) async {
          await _setTestViewport(tester, vp);
          addTearDown(() => _resetTestViewport(tester));

          final errors = <FlutterErrorDetails>[];
          final prevHandler = FlutterError.onError;
          FlutterError.onError = errors.add;
          try {
            await tester.pumpWidget(
              ChangeNotifierProvider<LicenseProvider?>.value(
                value: _MockLicense9D5(),
                child: wrapViewport(
                  vp,
                  const AiSettingsScreen(autoTriggerTour: false),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.text('Abrir Google AI Studio'),
              120,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pump();
          } finally {
            FlutterError.onError = prevHandler;
          }

          expect(
            errors,
            isEmpty,
            reason:
                'Overflow/Error en AiSettingsScreen @ ${vp.width.toInt()}x${vp.height.toInt()}: ${errors.map((e) => e.exceptionAsString()).join(' | ')}',
          );
          expect(find.byType(AiSettingsScreen), findsOneWidget);
        },
      );

      testWidgets(
        'BackupScreen con AutoBackup expandido y PinDelay 0px Overflow en ${vp.width.toInt()}x${vp.height.toInt()}dp @ 1.3x',
        (tester) async {
          await _setTestViewport(tester, vp);
          addTearDown(() => _resetTestViewport(tester));

          bool sawAutoTimer = false;
          bool sawSmartSection = false;
          final errors = <FlutterErrorDetails>[];
          final prevHandler = FlutterError.onError;
          FlutterError.onError = errors.add;
          try {
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(
                    value: _MockAuth9D5(),
                  ),
                  ChangeNotifierProvider<BackupProvider>.value(
                    value: _MockBackupProvider9D5(),
                  ),
                ],
                child: wrapViewport(
                  vp,
                  BackupScreen(
                    driveBackupService: _MockDriveBackupService9D5(),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            await tester.scrollUntilVisible(
              find.byType(AutoBackupTimerWidget),
              120,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            sawAutoTimer =
                find.byType(AutoBackupTimerWidget).evaluate().length == 1;

            await tester.scrollUntilVisible(
              find.byType(SmartBackupSection),
              120,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            sawSmartSection =
                find.byType(SmartBackupSection).evaluate().length == 1;

            await tester.scrollUntilVisible(
              find.byType(PinDelayConfigWidget),
              120,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
          } finally {
            FlutterError.onError = prevHandler;
          }

          expect(
            errors,
            isEmpty,
            reason:
                'Overflow/Error en BackupScreen @ ${vp.width.toInt()}x${vp.height.toInt()}: ${errors.map((e) => e.exceptionAsString()).join(' | ')}',
          );
          expect(sawAutoTimer, isTrue);
          expect(sawSmartSection, isTrue);
          expect(find.byType(PinDelayConfigWidget), findsOneWidget);
        },
      );

      testWidgets(
        'MatchingItemRow (colapsado y expandido con descuento y pool compartido) 0px Overflow en ${vp.width.toInt()}x${vp.height.toInt()}dp @ 1.3x',
        (tester) async {
          await _setTestViewport(tester, vp);
          addTearDown(() => _resetTestViewport(tester));

          final matchingProv = _MockMatchingProvider9D5();
          final pair = MatchPair(
            sourceItem: ExtractedItem(
              id: 7,
              originalText: '4 Docenas Lápices HB Artesco',
              fullName: 'Lápices Grafito HB No. 2 Caja x12',
              quantity: 4,
              unit: 'Caja',
            ),
            selectedProduct: MatchedProduct(
              productId: 10,
              presentationId: 101,
              fullName: 'Lápiz Técnico HB Artesco Caja x12',
              productName: 'Lápiz Técnico HB',
              specificName: 'Caja x12 Unidades',
              brand: 'ARTESCO',
              price: 18.50,
              offerPrice: 14.90,
              stock: 20,
              unit: 'Caja',
              conversionFactor: 12,
              usaStockCompartido: true,
              sharedStockPool: 48,
              cupoMaximoVariante: 3,
            ),
            status: MatchStatus.manual,
          );
          pair.selectedQuantity = 4;

          final errors = <FlutterErrorDetails>[];
          final prevHandler = FlutterError.onError;
          FlutterError.onError = errors.add;
          try {
            await tester.pumpWidget(
              ChangeNotifierProvider<MatchingProvider>.value(
                value: matchingProv,
                child: wrapViewport(
                  vp,
                  Scaffold(
                    body: SingleChildScrollView(
                      child: MatchingItemRow(
                        pair: pair,
                        index: 11,
                        isRepeated: true,
                        isClient: true,
                        onTapProduct: () {},
                        onChangeRequest: () {},
                        onDelete: () {},
                        onUnlink: () {},
                        onSuggestedReplacements: () {},
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            // Expandir tarjeta para cubrir Imagen + Stepper +/- + Desvincular/Cambiar
            await tester.tap(find.byIcon(Icons.keyboard_arrow_left));
            await tester.pumpAndSettle();
          } finally {
            FlutterError.onError = prevHandler;
          }

          expect(
            errors,
            isEmpty,
            reason:
                'Overflow/Error en MatchingItemRow @ ${vp.width.toInt()}x${vp.height.toInt()}: ${errors.map((e) => e.exceptionAsString()).join(' | ')}',
          );
          expect(find.byKey(const ValueKey('linked_10')), findsOneWidget);
          expect(find.text('Desvincular'), findsOneWidget);
          expect(find.text('Cambiar'), findsOneWidget);
        },
      );

      testWidgets(
        'LedgerTimelineTab (timeline con mora, chips y hoja Editar Abono) 0px Overflow en ${vp.width.toInt()}x${vp.height.toInt()}dp @ 1.3x',
        (tester) async {
          await _setTestViewport(tester, vp);
          addTearDown(() => _resetTestViewport(tester));

          final trackingProv = _MockTrackingProvider9D5();
          final errors = <FlutterErrorDetails>[];
          final prevHandler = FlutterError.onError;
          FlutterError.onError = errors.add;
          try {
            await tester.pumpWidget(
              ChangeNotifierProvider<TrackingProvider>.value(
                value: trackingProv,
                child: wrapViewport(
                  vp,
                  const Scaffold(body: LedgerTimelineTab(clientId: 501)),
                ),
              ),
            );
            await tester.pumpAndSettle();

            if (vp.width == 320) {
              final menuFinder = find.byIcon(Icons.more_vert_rounded).last;
              await tester.scrollUntilVisible(
                menuFinder,
                80,
                scrollable: find.byType(Scrollable).last,
              );
              await tester.pumpAndSettle();
              await tester.tap(menuFinder);
              await tester.pumpAndSettle();
              final editBtn = find.text('Corregir / Editar Abono');
              if (editBtn.evaluate().isNotEmpty) {
                await tester.tap(editBtn.first);
                await tester.pumpAndSettle();
              }
            }
          } finally {
            FlutterError.onError = prevHandler;
          }

          expect(
            errors,
            isEmpty,
            reason:
                'Overflow/Error en LedgerTimelineTab @ ${vp.width.toInt()}x${vp.height.toInt()}: ${errors.map((e) => e.exceptionAsString()).join(' | ')}',
          );
          expect(find.byType(LedgerTimelineTab), findsOneWidget);
        },
      );
    }
  });
}
