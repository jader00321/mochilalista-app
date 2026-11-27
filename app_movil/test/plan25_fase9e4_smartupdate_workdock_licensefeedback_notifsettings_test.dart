import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/models/notification_preferences_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/core/services/license/license_redeem_result.dart';
import 'package:app_movil/core/widgets/floating_dock_session_state.dart';
import 'package:app_movil/core/widgets/persistent_work_dock.dart';
import 'package:app_movil/features/auth/screens/license/widgets/license_activation_feedback_modal.dart';
import 'package:app_movil/features/catalog/models/product_create_draft.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/profile/widgets/notifications/notification_settings_modal.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/smart_update_modal.dart';

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

class _MockAuth9E4 extends ChangeNotifier implements AuthProvider {
  @override
  bool get hasActiveContext => true;

  @override
  bool get isAuthenticated => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockQuickSale9E4 extends ChangeNotifier implements QuickSaleProvider {
  @override
  final List<MatchedProduct> cartItems = [
    MatchedProduct(
      productId: 1,
      presentationId: 10,
      fullName: 'Cuaderno Universitario A4 Cuadriculado 100h',
      price: 12.50,
      stock: 40,
    ),
  ];

  @override
  double get totalToPay => 1250.75;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockScanner9E4 extends ChangeNotifier implements ScannerProvider {
  @override
  StagingResponse? get stagingData => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockMatching9E4 extends ChangeNotifier implements MatchingProvider {
  @override
  List<MatchPair> get pairs => const [];

  @override
  double get totalNetAmount => 0.0;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockSmartQuotation9E4 extends ChangeNotifier
    implements SmartQuotationProvider {
  @override
  bool get hasManualDraft => true;

  @override
  List<MatchedProduct>? get draftManualItems => [
    MatchedProduct(
      productId: 2,
      presentationId: 20,
      fullName: 'Plumón Indeleble Negro',
      price: 4.0,
      stock: 10,
    ),
  ];

  @override
  String? get draftQuoteTitle => 'Lista Escolar Primaria Completa';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockInventory9E4 extends ChangeNotifier implements InventoryProvider {
  @override
  bool get hasCreationDraft => true;

  @override
  ProductCreateDraft? get creationDraft => ProductCreateDraft(
    name: 'Temperas Apu Profesional x 12',
    presentations: const [
      {'specific': 'Caja'},
      {'specific': 'Unidad'},
    ],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockNotification9E4 extends ChangeNotifier
    implements NotificationProvider {
  NotificationPreferences _prefs = NotificationPreferences(
    negocioId: 1,
    updatedAt: DateTime(2026, 11, 27),
  );

  @override
  NotificationPreferences get preferences => _prefs;

  @override
  int get archivedCount => 14;

  @override
  int get silencedCount => 6;

  @override
  Future<void> updatePreferences(NotificationPreferences newPrefs) async {
    _prefs = newPrefs;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _wrapViewport9E4({required Size viewport, required Widget child}) {
  return MediaQuery(
    data: MediaQueryData(
      size: viewport,
      textScaler: const TextScaler.linear(1.3),
    ),
    child: MaterialApp(home: child),
  );
}

ValidationResult _buildRichValidation9E4() {
  return ValidationResult(
    hasIssues: true,
    canSell: false,
    stockWarnings: [
      StockWarning(
        itemId: 101,
        productName: 'Cuaderno Stanford A4 Pasta Dura 100 Hojas',
        requested: 5,
        available: 0,
        message: 'Sin stock disponible en almacén principal.',
      ),
      StockWarning(
        itemId: 102,
        productName: 'Lapicero Tinta Gel Punta Fina Azul',
        requested: 8,
        available: 3,
        message: 'Stock reducido tras última venta.',
      ),
    ],
    sharedStockConflicts: [
      SharedStockConflict(
        productId: 50,
        productName: 'Papel Bond A4 75gr Chamex (Pozo Compartido)',
        totalSharedPool: 10,
        totalRequestedBaseUnits: 14,
        excessBaseUnits: 4,
        conflictingItems: const [
          QuoteItemConflictDetail(
            itemId: 201,
            presentationId: 501,
            presentationName: 'Paquete x 6',
            requestedQty: 1,
            conversionFactor: 6,
            requestedBaseUnits: 6,
            cupoMaximo: 1,
          ),
          QuoteItemConflictDetail(
            itemId: 202,
            presentationId: 502,
            presentationName: 'Unidad Suelta',
            requestedQty: 8,
            conversionFactor: 1,
            requestedBaseUnits: 8,
          ),
        ],
      ),
    ],
    priceChanges: [
      PriceChange(
        itemId: 301,
        productName: 'Caja de Colores Faber-Castell x 24 Unidades',
        oldPrice: 28.50,
        newPrice: 32.90,
        newBasePrice: 30.00,
        message: 'Actualizado por lista de precios del proveedor.',
      ),
    ],
    nameChanges: [
      NameChange(
        itemId: 401,
        oldName: 'Tijera Escolar Artesco Punta Roma',
        newName: 'Tijera Ergonómica Artesco 5" Punta Roma',
        message: 'Nombre estandarizado en catálogo.',
      ),
    ],
    bundleChanges: [
      BundleChange(
        itemId: 501,
        bundleId: 77,
        bundleName: 'Pack Regreso a Clases Inicial Económico',
        changes: const ['Se ajustó el precio del combo'],
        isDeactivated: false,
      ),
    ],
    unitChanges: [
      UnitChange(
        itemId: 601,
        productName: 'Plastilina Artesco x 12 Colores',
        oldUnit: 'Unidad',
        newUnit: 'Caja x 12',
        oldFactor: 1,
        newFactor: 12,
        message: 'Factor de conversión actualizado.',
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Plan 25 Fase 9E-4 — Certificación Estructural, DRY y Censo <= 5', () {
    test(
      'Límites post-formato, cierre D-MOV-02, AppCurrency/AppDateFormatter y censo global <= 5',
      () {
        final root = _resolveAppMovilRoot();

        const coordinators = <String, int>{
          'lib/features/smart_quotation/widgets/smart_update_modal.dart': 549,
          'lib/core/widgets/persistent_work_dock.dart': 549,
          'lib/features/auth/screens/license/widgets/license_activation_feedback_modal.dart':
              549,
          'lib/features/profile/widgets/notifications/notification_settings_modal.dart':
              549,
        };

        for (final entry in coordinators.entries) {
          final lines = _countLines(entry.key);
          expect(
            lines,
            lessThanOrEqualTo(entry.value),
            reason: '${entry.key} excede ${entry.value} L ($lines L)',
          );
        }

        const subModules = <String, int>{
          'lib/features/smart_quotation/widgets/smart_update/smart_update_sections_part.dart':
              599,
          'lib/features/smart_quotation/widgets/smart_update/smart_update_stock_and_shared_cards_part.dart':
              599,
          'lib/features/smart_quotation/widgets/smart_update/smart_update_price_and_meta_cards_part.dart':
              599,
          'lib/core/widgets/persistent_work_dock/persistent_work_dock_tasks_part.dart':
              599,
          'lib/core/widgets/persistent_work_dock/persistent_work_dock_bubble_and_bar_part.dart':
              599,
          'lib/features/auth/screens/license/widgets/activation_feedback/license_activation_feedback_cards_part.dart':
              599,
          'lib/features/auth/screens/license/widgets/activation_feedback/license_activation_feedback_actions_part.dart':
              599,
          'lib/features/profile/widgets/notifications/settings/notification_settings_sections_part.dart':
              599,
          'lib/features/profile/widgets/notifications/settings/notification_settings_controls_part.dart':
              599,
        };

        for (final entry in subModules.entries) {
          final lines = _countLines(entry.key);
          expect(
            lines,
            lessThanOrEqualTo(entry.value),
            reason: '${entry.key} excede ${entry.value} L ($lines L)',
          );
        }

        // Cierre D-MOV-02 en license_activation_feedback*
        final feedbackMain = File(
          '$root/lib/features/auth/screens/license/widgets/license_activation_feedback_modal.dart',
        ).readAsStringSync();
        final feedbackCards = File(
          '$root/lib/features/auth/screens/license/widgets/activation_feedback/license_activation_feedback_cards_part.dart',
        ).readAsStringSync();
        expect(feedbackMain.contains('_formatDate('), isFalse);
        expect(feedbackCards.contains('_formatDate('), isFalse);
        expect(feedbackCards.contains('AppDateFormatter.formatDate('), isTrue);

        // AppCurrency en SmartUpdateModal y PersistentWorkDock
        final smartUpdateCards = File(
          '$root/lib/features/smart_quotation/widgets/smart_update/smart_update_price_and_meta_cards_part.dart',
        ).readAsStringSync();
        final dockTasks = File(
          '$root/lib/core/widgets/persistent_work_dock/persistent_work_dock_tasks_part.dart',
        ).readAsStringSync();
        expect(smartUpdateCards.contains('AppCurrency.format('), isTrue);
        expect(dockTasks.contains('AppCurrency.format('), isTrue);

        // Cero shrinkWrap ni emojis crudos UI
        final all9E4 = [...coordinators.keys, ...subModules.keys];
        const forbiddenEmojis = ['🔥', '🔍', '📋', '⭐', '✅', '❌', '⚠️'];
        for (final rel in all9E4) {
          final content = File('$root/$rel').readAsStringSync();
          expect(content.contains('shrinkWrap: true'), isFalse, reason: rel);
          for (final emoji in forbiddenEmojis) {
            expect(content.contains(emoji), isFalse, reason: '$rel -> $emoji');
          }
        }

        // Censo global app_movil/lib/: 0 >= 1000 L y <= 5 en 800..999 L
        final allDart = Directory('$root/lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();

        final filesGe1000 = <String>[];
        final files800To999 = <String>[];
        for (final file in allDart) {
          final count = file.readAsLinesSync().length;
          final rel = file.path
              .replaceAll('\\', '/')
              .replaceFirst('${root.replaceAll('\\', '/')}/', '');
          if (count >= 1000) {
            filesGe1000.add('$count L $rel');
          } else if (count >= 800) {
            files800To999.add('$count L $rel');
          }
        }

        expect(filesGe1000, isEmpty, reason: 'Restan >= 1000 L: $filesGe1000');
        expect(
          files800To999.length,
          lessThanOrEqualTo(5),
          reason:
              'Cota monótona 9E-4 excedida (${files800To999.length}): $files800To999',
        );

        for (final target in coordinators.keys) {
          expect(
            files800To999.any((e) => e.endsWith(target)),
            isFalse,
            reason: '$target no debe continuar en 800–999 L',
          );
        }
      },
    );

    test('Paridad de importación directa y símbolos públicos de 9E-4', () {
      const task = WorkTask(
        id: 't1',
        title: 'Tarea de Prueba',
        shortTitle: 'Tarea',
        subtitle: 'Subtítulo',
        icon: Icons.bolt_rounded,
        color: Colors.blue,
        onResume: _noopCallback,
      );
      expect(task.id, equals('t1'));
      expect(SmartUpdateModal, isNotNull);
      expect(PersistentWorkDock, isNotNull);
      expect(LicenseActivationFeedbackModal.show, isNotNull);
      expect(NotificationSettingsModal.show, isNotNull);
    });
  });

  group('Plan 25 Fase 9E-4 — Certificación Responsiva 0px Overflow @ 1.3x', () {
    const viewports = <Size>[Size(320, 568), Size(360, 640), Size(412, 915)];

    setUp(() {
      FloatingDockSessionState.isBubble = false;
      FloatingDockSessionState.isEdgeTucked = false;
      FloatingDockSessionState.isLeftEdge = false;
      FloatingDockSessionState.panX = null;
      FloatingDockSessionState.panBottom = 80.0;
    });

    for (final vp in viewports) {
      testWidgets(
        'SmartUpdateModal (stock agotado + shared + precios + nombres + ofertas + unidades) 0px @ 1.3x en ${vp.width.toInt()}x${vp.height.toInt()}dp',
        (tester) async {
          await tester.binding.setSurfaceSize(vp);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final errors = <String>[];
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(details.toString());

          try {
            await tester.pumpWidget(
              _wrapViewport9E4(
                viewport: vp,
                child: Scaffold(
                  body: SmartUpdateModal(
                    validation: _buildRichValidation9E4(),
                    onUpdatePrices: () {},
                    onFixStock: () {},
                    onFixAll: () {},
                    onFixSingleStock: (_, __) {},
                    onRemoveSingleItem: (_) {},
                    onAcceptSinglePrice: (_, __, ___) {},
                    onAcceptSingleName: (_, __) {},
                    onUpdateNames: () {},
                    onSyncBundles: () {},
                    onSyncUnits: () {},
                    onOpenManualEdit: () {},
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.text('Centro de Resoluciones'), findsOneWidget);
            expect(find.text('Sustituir Ítem'), findsOneWidget);
            expect(find.text('CORREGIR Y ACTUALIZAR TODO'), findsOneWidget);

            // Desplazar hasta la última sección para validar tarjetas inferiores
            await tester.ensureVisible(
              find.text('Sincronizar Unidades de Venta'),
            );
            await tester.pumpAndSettle();

            expect(errors, isEmpty);
          } finally {
            FlutterError.onError = prevOnError;
          }
        },
      );

      testWidgets(
        'PersistentWorkDock (expandido + colapsado burbuja + edge peek) 0px @ 1.3x en ${vp.width.toInt()}x${vp.height.toInt()}dp',
        (tester) async {
          await tester.binding.setSurfaceSize(vp);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final errors = <String>[];
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(details.toString());

          Widget buildDockHost(Key dockKey) {
            return MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(
                  value: _MockAuth9E4(),
                ),
                ChangeNotifierProvider<QuickSaleProvider>.value(
                  value: _MockQuickSale9E4(),
                ),
                ChangeNotifierProvider<ScannerProvider>.value(
                  value: _MockScanner9E4(),
                ),
                ChangeNotifierProvider<MatchingProvider>.value(
                  value: _MockMatching9E4(),
                ),
                ChangeNotifierProvider<SmartQuotationProvider>.value(
                  value: _MockSmartQuotation9E4(),
                ),
                ChangeNotifierProvider<InventoryProvider>.value(
                  value: _MockInventory9E4(),
                ),
              ],
              child: _wrapViewport9E4(
                viewport: vp,
                child: Scaffold(
                  body: Stack(
                    children: [
                      const Positioned.fill(child: SizedBox()),
                      PersistentWorkDock(key: dockKey, isFloating: true),
                    ],
                  ),
                ),
              ),
            );
          }

          try {
            // 1. Estado expandido multi-tarea y colapso interactivo a burbuja
            FloatingDockSessionState.isBubble = false;
            FloatingDockSessionState.isEdgeTucked = false;
            await tester.pumpWidget(buildDockHost(const ValueKey('dock_exp')));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.text('Caja Rápida'), findsOneWidget);
            expect(find.text('Reanudar'), findsOneWidget);

            // 2. Estado colapsado en burbuja flotante tocando botón minimizar
            await tester.tap(find.byTooltip('Minimizar a globo'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.text('3'), findsOneWidget);

            // 3. Estado edge peek en borde
            FloatingDockSessionState.isBubble = true;
            FloatingDockSessionState.isEdgeTucked = true;
            await tester.pumpWidget(buildDockHost(const ValueKey('dock_edge')));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);

            expect(errors, isEmpty);

            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          } finally {
            FlutterError.onError = prevOnError;
          }
        },
      );

      testWidgets(
        'LicenseActivationFeedbackModal (success + hardwareMismatch) 0px @ 1.3x en ${vp.width.toInt()}x${vp.height.toInt()}dp',
        (tester) async {
          await tester.binding.setSurfaceSize(vp);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final errors = <String>[];
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(details.toString());

          try {
            final successResult = LicenseRedeemResult(
              status: LicenseRedeemStatus.success,
              isSuccess: true,
              message: 'Activada',
              plan: 'ANUAL_COMERCIAL_PRO',
              daysAdded: 365,
              aiCreditsAdded: 1000,
              newExpirationDate: DateTime(2027, 11, 27),
            );

            await tester.pumpWidget(
              _wrapViewport9E4(
                viewport: vp,
                child: Scaffold(
                  body: LicenseActivationFeedbackModal(
                    result: successResult,
                    onDone: () {},
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('27/11/2027'), findsOneWidget);
            expect(find.text('Comenzar a Usar'), findsOneWidget);

            const mismatchResult = LicenseRedeemResult(
              status: LicenseRedeemStatus.hardwareMismatch,
              isSuccess: false,
              message: 'Hardware distinto',
              tokenDeviceId: 'ML-999Z-ALPHA-987654',
              currentDeviceId: 'ML-379E-BRAVO-123456',
            );

            await tester.pumpWidget(
              _wrapViewport9E4(
                viewport: vp,
                child: Scaffold(
                  body: LicenseActivationFeedbackModal(
                    result: mismatchResult,
                    onDone: () {},
                    onContactSupport: () {},
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Contactar a Soporte Oficial'), findsOneWidget);
            expect(find.text('Entendido'), findsOneWidget);

            final expiredSnapshot = LicenseModel(
              deviceFingerprint: 'ML-9E4',
              tipoPlan: 'ANUAL',
              estadoActual: 'POR_VENCER',
              fechaInicio: DateTime(2025, 11, 20),
              fechaExpiracion: DateTime(2026, 11, 20),
              fechaUltimoCheck: DateTime(2026, 11, 27),
              ultimoNonce: 7,
              aiAccumulatedScans: 42,
            );
            final sameNonceResult = LicenseRedeemResult(
              status: LicenseRedeemStatus.alreadyRedeemedSameNonce,
              isSuccess: false,
              message: 'Ya aplicado',
              tokenNonce: 7,
              currentNonce: 7,
              currentLicenseSnapshot: expiredSnapshot,
            );
            await tester.pumpWidget(
              _wrapViewport9E4(
                viewport: vp,
                child: Scaffold(
                  body: LicenseActivationFeedbackModal(
                    result: sameNonceResult,
                    onDone: () {},
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Ref. soporte: #7'), findsOneWidget);
            expect(find.text('Vence: 20/11/2026'), findsOneWidget);

            expect(errors, isEmpty);
          } finally {
            FlutterError.onError = prevOnError;
          }
        },
      );

      testWidgets(
        'NotificationSettingsModal (píldoras, switches, chips, footer) 0px @ 1.3x en ${vp.width.toInt()}x${vp.height.toInt()}dp',
        (tester) async {
          await tester.binding.setSurfaceSize(vp);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final errors = <String>[];
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(details.toString());

          try {
            await tester.pumpWidget(
              ChangeNotifierProvider<NotificationProvider>.value(
                value: _MockNotification9E4(),
                child: _wrapViewport9E4(
                  viewport: vp,
                  child: const Scaffold(
                    body: NotificationSettingsModal(isDark: false),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.text('Configuración de Alertas'), findsOneWidget);
            expect(find.text('Restaurar recomendados'), findsOneWidget);
            expect(find.text('Listo / Guardar'), findsOneWidget);

            // Desplazar hasta el final de las secciones para validar umbral y swipe buttons
            await tester.drag(find.byType(ListView), const Offset(0, -600));
            await tester.pumpAndSettle();
            await tester.drag(find.byType(ListView), const Offset(0, -600));
            await tester.pumpAndSettle();

            expect(errors, isEmpty);
          } finally {
            FlutterError.onError = prevOnError;
          }
        },
      );
    }
  });
}

void _noopCallback() {}
