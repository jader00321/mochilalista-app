import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/utils/whatsapp_uri_builder.dart';
import 'package:app_movil/core/widgets/live_filter_bottom_sheet.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/loyalty_whatsapp_service.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_full_stats_modal.dart';

Directory _resolveAppMovilRoot() {
  final cwd = Directory.current;
  if (File('${cwd.path}${Platform.pathSeparator}pubspec.yaml').existsSync() &&
      Directory('${cwd.path}${Platform.pathSeparator}lib').existsSync()) {
    return cwd;
  }
  final nested = Directory('${cwd.path}${Platform.pathSeparator}app_movil');
  if (nested.existsSync()) {
    return nested;
  }
  throw StateError(
    'No se pudo ubicar app_movil desde Directory.current=${cwd.path}',
  );
}

class _MockCatalogProvider extends CatalogProvider {
  @override
  List<Category> get categories => [
    Category(
      id: 1,
      nombre: 'Útiles Escolares y Oficina Premium',
      productsCount: 14,
    ),
    Category(id: 2, nombre: 'Mochilas y Loncheras', productsCount: 6),
  ];

  @override
  List<Brand> get brands => [
    Brand(id: 10, nombre: 'Faber-Castell Profesional', productsCount: 9),
    Brand(id: 11, nombre: 'Artesco', productsCount: 5),
  ];

  @override
  bool get hasOrphanCategories => true;

  @override
  bool get hasOrphanBrands => true;

  @override
  List<InventoryWrapper> get displayItems => [
    InventoryWrapper(
      product: Product(
        id: 100,
        nombre: 'Cuaderno A4 Cuadriculado',
        categoriaId: 1,
        marcaId: 10,
      ),
      presentation: ProductPresentation(
        id: 1001,
        precioVentaFinal: 12.50,
        precioOferta: 10.00,
        stockActual: 8,
        esDefault: true,
      ),
    ),
    InventoryWrapper(
      product: Product(
        id: 101,
        nombre: 'Lapicero Azul Económico',
        categoriaId: 0,
        marcaId: 0,
      ),
      presentation: ProductPresentation(
        id: 1002,
        precioVentaFinal: 2.50,
        stockActual: 0,
        esDefault: false,
      ),
    ),
  ];

  @override
  int get realTotalPresentationsCount => 2;

  @override
  Map<String, dynamic> get advancedFilters => {
    'category_ids': [1],
    'has_offer': true,
    'min_price': 5.0,
    'max_price': 180.0,
  };

  @override
  int? get selectedCategoryId => 1;

  @override
  Future<int> countFilteredProducts(
    Map<String, dynamic> advancedFilters,
  ) async {
    return displayItems.length;
  }

  @override
  void applyAdvancedFilters(Map<String, dynamic> filters) {}

  @override
  void clearAllFilters() {}
}

ClientModel _buildRichClient() {
  final now = DateTime.now();
  return ClientModel(
    id: 77,
    negocioId: 1,
    creadoPorUsuarioId: 1,
    fullName: 'María Fernanda Quispe Mamani',
    phone: '+51 987 654 321',
    totalDebt: 245.50,
    saldoAFavor: 40.00,
    pendingDeliveryCount: 3,
    registeredDate: now.subtract(const Duration(days: 45)).toIso8601String(),
    puntosActuales: 185,
    puntosHistoricos: 420,
    rachaPagosPuntuales: 4,
    scoreReputacion: 780,
    nivelReputacion: 'ORO',
    lastSales: [
      SaleSummary(
        id: 1,
        sequentialNumber: 101,
        total: 320.00,
        montoPagado: 150.00,
        date: now.subtract(const Duration(days: 2)).toIso8601String(),
        status: 'entregado',
        origenVenta: 'smart_quotation',
      ),
      SaleSummary(
        id: 2,
        sequentialNumber: 102,
        total: 180.00,
        montoPagado: 180.00,
        date: now.subtract(const Duration(days: 12)).toIso8601String(),
        status: 'entregado',
        origenVenta: 'catalogo',
      ),
      SaleSummary(
        id: 3,
        sequentialNumber: 103,
        total: 250.00,
        montoPagado: 174.50,
        date: now.subtract(const Duration(days: 6)).toIso8601String(),
        status: 'entregado',
        origenVenta: 'prestamo_personal',
      ),
    ],
  );
}

LoyaltyRulesModel _buildLoyaltyRules() => LoyaltyRulesModel(
  negocioId: 1,
  puntosPorCompraActivo: true,
  puntosPorUnidadMoneda: 1,
  montoBaseCompra: 1.0,
  compraMinimaParaPuntos: 10.0,
  bonoCotizacionActivo: true,
  puntosBonoCotizacion: 20,
  puntosAbonoInicialActivo: true,
  bonoPagoPuntualActivo: true,
  puntosPagoPuntual: 15,
  bonoRachaActivo: true,
  cadaCuantasCuotasRacha: 3,
  puntosBonoRacha: 30,
  bonoLiquidacionSinMoraActivo: true,
  puntosLiquidacionSinMora: 40,
  updatedAt: '2026-11-26T12:00:00Z',
);

List<RewardGoalModel> _buildRewardGoals() => [
  RewardGoalModel(
    id: 1,
    negocioId: 1,
    nombre: 'Descuento S/ 15',
    descripcion: 'Válido en compras escolares',
    puntosRequeridos: 100,
    tipoBeneficio: 'DESCUENTO_MONTO',
    valorBeneficio: 15.0,
    activo: true,
    createdAt: '2026-11-26T12:00:00Z',
  ),
  RewardGoalModel(
    id: 2,
    negocioId: 1,
    nombre: '10% En Toda la Tienda',
    descripcion: 'Premio especial por fidelidad',
    puntosRequeridos: 250,
    tipoBeneficio: 'DESCUENTO_PORCENTAJE',
    valorBeneficio: 10.0,
    activo: true,
    createdAt: '2026-11-26T12:00:00Z',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Plan 25 Fase 9D-6: Censo Modular y Cobertura DRY', () {
    test('Los 12 archivos modulares de 9D-6 cumplen límites estrictos (< 600 L)', () {
      final root = _resolveAppMovilRoot();

      final expectedLineCaps = <String, int>{
        'lib/features/smart_quotation/services/loyalty_whatsapp_service.dart':
            500,
        'lib/features/smart_quotation/services/loyalty_whatsapp/loyalty_whatsapp_guides_part.dart':
            600,
        'lib/features/smart_quotation/services/loyalty_whatsapp/loyalty_whatsapp_notifications_part.dart':
            600,
        'lib/features/smart_quotation/services/loyalty_whatsapp/loyalty_whatsapp_preview_controls_part.dart':
            600,
        'lib/features/smart_quotation/services/loyalty_whatsapp/loyalty_whatsapp_preview_modal.dart':
            600,
        'lib/core/widgets/live_filter_bottom_sheet.dart': 600,
        'lib/core/widgets/live_filter/live_filter_chips_and_inputs_mixin.dart':
            600,
        'lib/core/widgets/live_filter/live_filter_sections_mixin.dart': 600,
        'lib/features/smart_quotation/widgets/crm/client_full_stats_modal.dart':
            600,
        'lib/features/smart_quotation/widgets/crm/client_stats/client_full_stats_cards_mixin.dart':
            600,
        'lib/features/smart_quotation/widgets/crm/client_stats/client_full_stats_export_and_cancellations_mixin.dart':
            600,
        'lib/features/smart_quotation/widgets/crm/client_stats/client_full_stats_sections_mixin.dart':
            600,
      };

      for (final entry in expectedLineCaps.entries) {
        final file = File('${root.path}${Platform.pathSeparator}${entry.key}');
        expect(file.existsSync(), isTrue, reason: 'Falta archivo ${entry.key}');
        final lines = file.readAsLinesSync().length;
        expect(
          lines,
          lessThan(entry.value),
          reason: '${entry.key} tiene $lines líneas (límite < ${entry.value})',
        );
      }

      // Censo global de app_movil/lib >= 1000 L:
      // Todos los monolitos originales de 9A..9D quedan < 1000 L.
      // Nota documentada: promotions/screens/offers_tab.dart (764 L en baseline
      // fffb329) creció a >= 1000 L por dart format en 5e7c28f y permanece
      // fuera del alcance 9D-6.
      final libDir = Directory('${root.path}${Platform.pathSeparator}lib');
      final over1000 = <String>[];
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final lines = entity.readAsLinesSync().length;
          if (lines >= 1000) {
            final rel = entity.path
                .substring(root.path.length + 1)
                .replaceAll('\\', '/');
            over1000.add(rel);
          }
        }
      }
      expect(
        over1000.where(
          (p) => p != 'lib/features/promotions/screens/offers_tab.dart',
        ),
        isEmpty,
        reason: 'Monolitos inesperados >= 1000 L en app_movil/lib: $over1000',
      );
    });

    test('Reutilización DRY en 9D-6 y cero restos de deuda técnica', () {
      final root = _resolveAppMovilRoot();

      final waService = File(
        '${root.path}/lib/features/smart_quotation/services/loyalty_whatsapp_service.dart',
      ).readAsStringSync();
      final waControls = File(
        '${root.path}/lib/features/smart_quotation/services/loyalty_whatsapp/loyalty_whatsapp_preview_controls_part.dart',
      ).readAsStringSync();
      final waNotifications = File(
        '${root.path}/lib/features/smart_quotation/services/loyalty_whatsapp/loyalty_whatsapp_notifications_part.dart',
      ).readAsStringSync();
      final liveFilterSections = File(
        '${root.path}/lib/core/widgets/live_filter/live_filter_sections_mixin.dart',
      ).readAsStringSync();
      final clientStatsModal = File(
        '${root.path}/lib/features/smart_quotation/widgets/crm/client_full_stats_modal.dart',
      ).readAsStringSync();
      final clientStatsExport = File(
        '${root.path}/lib/features/smart_quotation/widgets/crm/client_stats/client_full_stats_export_and_cancellations_mixin.dart',
      ).readAsStringSync();

      expect(waService.contains('WhatsAppUriBuilder.buildSendUri'), isTrue);
      expect(waService.contains('https://wa.me/'), isFalse);
      expect(waControls.contains('ClipboardHelper.copyWithFeedback'), isTrue);
      expect(waNotifications.contains('AppCurrency.format'), isTrue);

      expect(liveFilterSections.contains('AppCurrency.format'), isTrue);
      expect(liveFilterSections.contains('🔥'), isFalse);

      expect(clientStatsModal.contains('package:intl/intl.dart'), isFalse);
      expect(clientStatsModal.contains('DateFormat('), isFalse);
      expect(clientStatsExport.contains('AppDateFormatter.ddMMyy'), isTrue);
      expect(
        clientStatsExport.contains('AppFeedbackHelper.showSnackBar'),
        isTrue,
      );
      expect(clientStatsModal.contains('📅'), isFalse);
    });
  });

  group('Plan 25 Fase 9D-6: Unit tests de LoyaltyWhatsAppService', () {
    test(
      'formatBusinessName y construcción de plantillas preservan formato y moneda',
      () {
        expect(
          LoyaltyWhatsAppService.formatBusinessName(''),
          equals('NUESTRA TIENDA'),
        );
        expect(
          LoyaltyWhatsAppService.formatBusinessName('  Bodega El Sol  '),
          equals('BODEGA EL SOL'),
        );

        final rules = _buildLoyaltyRules();
        final goals = _buildRewardGoals();

        final fullGuide =
            LoyaltyWhatsAppService.buildLoyaltyGuideAndCatalogMessage(
              businessName: 'Bodega El Sol',
              rules: rules,
              activeGoals: goals,
              clientName: 'Ana Torres',
              puntosActuales: 185,
              businessAddress: 'Av. Arequipa 123',
              businessPhone: '987654321',
            );
        expect(fullGuide, contains('BODEGA EL SOL'));
        expect(fullGuide, contains('Ana Torres'));
        expect(fullGuide, contains('*185 pts*'));
        expect(fullGuide, contains('Av. Arequipa 123'));

        final summary = LoyaltyWhatsAppService.buildSummaryGuideMessage(
          businessName: 'Bodega El Sol',
          rules: rules,
          activeGoals: goals,
          clientName: 'Ana Torres',
          puntosActuales: 185,
        );
        expect(summary, contains('PROGRAMA DE PUNTOS • BODEGA EL SOL'));

        final promoInvite = LoyaltyWhatsAppService.buildPromoInviteMessage(
          businessName: 'Bodega El Sol',
          activeGoals: goals,
          clientName: 'Ana Torres',
          puntosActuales: 185,
        );
        expect(promoInvite, contains('Ana Torres'));

        final rewardsMsg = LoyaltyWhatsAppService.buildAvailableRewardsMessage(
          clientName: 'Ana Torres',
          businessName: 'Bodega El Sol',
          puntosSaldo: 185,
          nivelReputacion: 'ORO',
          claimableGoals: [goals.first],
          upcomingGoal: goals.last,
          missingPoints: 65,
        );
        expect(rewardsMsg, contains('Solo te faltan 65 pts'));

        final promoMsg = LoyaltyWhatsAppService.buildPromotionMessage(
          clientName: 'Ana Torres',
          businessName: 'Bodega El Sol',
          products: [
            {
              'nombre': 'Mochila Escolar',
              'precioRegular': 89.9,
              'precio_oferta': 69.9,
            },
          ],
        );
        expect(promoMsg, contains('S/ 89.90'));
        expect(promoMsg, contains('S/ 69.90'));
      },
    );

    test('WhatsAppUriBuilder evita prefijos 51 duplicados (D-MOV-04)', () {
      expect(
        WhatsAppUriBuilder.buildSendUri(
          phone: '+51 987 654 321',
          message: 'Hola Premio!',
        ).toString(),
        equals('https://wa.me/51987654321?text=Hola%20Premio!'),
      );
      expect(
        WhatsAppUriBuilder.normalizePeruWhatsAppPhone('5151987654321'),
        equals('51987654321'),
      );
      expect(
        WhatsAppUriBuilder.normalizePeruWhatsAppPhone('987654321'),
        equals('51987654321'),
      );
    });
  });

  group('Plan 25 Fase 9D-6: Cero Overflow @ 1.3x en 320dp, 360dp y 412dp', () {
    const viewports = <Size>[Size(320, 568), Size(360, 640), Size(412, 915)];

    for (final viewport in viewports) {
      testWidgets(
        'LiveFilterBottomSheet sin overflow @ 1.3x en ${viewport.width.toInt()}x${viewport.height.toInt()}dp',
        (tester) async {
          final errorLogs = <String>[];
          final prevOnError = FlutterError.onError;
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;

          try {
            FlutterError.onError = (details) =>
                errorLogs.add(details.toString());

            await tester.pumpWidget(
              ChangeNotifierProvider<CatalogProvider>.value(
                value: _MockCatalogProvider(),
                child: MaterialApp(
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(1.3)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Builder(
                      builder: (ctx) => Center(
                        child: ElevatedButton(
                          onPressed: () => LiveFilterBottomSheet.show(ctx),
                          child: const Text('Abrir Filtros'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );

            await tester.tap(find.text('Abrir Filtros'));
            await tester.pumpAndSettle();

            expect(find.text('Filtros del Catálogo'), findsOneWidget);
            expect(find.text('Limpiar'), findsOneWidget);
            expect(find.text('Solo ofertas'), findsOneWidget);

            // Expandir acordeón de Marcas para validar filas de taxonomía en ancho compacto
            final brandsHeader = find.text('Marcas');
            await tester.ensureVisible(brandsHeader);
            await tester.tap(brandsHeader);
            await tester.pumpAndSettle();
            expect(find.text('Faber-Castell Profesional'), findsOneWidget);
          } finally {
            FlutterError.onError = prevOnError;
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }

          expect(
            errorLogs,
            isEmpty,
            reason:
                'FlutterError en LiveFilterBottomSheet @ ${viewport.width}x${viewport.height}:\n${errorLogs.join('\n---\n')}',
          );
        },
      );

      testWidgets(
        'ClientFullStatsModal sin overflow @ 1.3x en ${viewport.width.toInt()}x${viewport.height.toInt()}dp',
        (tester) async {
          late Database db;
          await tester.runAsync(() async {
            db = await databaseFactory.openDatabase(inMemoryDatabasePath);
            await LocalDatabase.createDBForTesting(db);
            LocalDatabase.setCustomDatabase(db);
            await db.insert('negocios', {
              'id': 1,
              'nombre_comercial': 'Bodega El Sol',
              'moneda': 'S/ (Soles)',
            });
            await db.insert('usuarios', {
              'id': 1,
              'nombre_completo': 'Administrador',
              'email': 'admin@bodega.pe',
            });
            await db.insert('clientes', {
              'id': 77,
              'negocio_id': 1,
              'creado_por_usuario_id': 1,
              'nombre_completo': 'María Fernanda Quispe Mamani',
              'telefono': '+51 987 654 321',
            });
            await db.insert('ventas', {
              'id': 900,
              'numero_secuencial': 101,
              'negocio_id': 1,
              'creado_por_usuario_id': 1,
              'cliente_id': 77,
              'metodo_pago': 'efectivo',
              'monto_total': 320.0,
              'monto_pagado': 150.0,
              'fecha_venta': '2026-11-24T10:00:00Z',
              'estado_entrega': 'entregado',
              'origen_venta': 'smart_quotation',
              'is_archived': 0,
            });
            await db.insert('ventas', {
              'id': 901,
              'numero_secuencial': 102,
              'negocio_id': 1,
              'creado_por_usuario_id': 1,
              'cliente_id': 77,
              'metodo_pago': 'credito',
              'monto_total': 250.0,
              'monto_pagado': 174.5,
              'fecha_venta': '2026-11-21T10:00:00Z',
              'estado_entrega': 'entregado',
              'origen_venta': 'prestamo_personal',
              'is_archived': 0,
            });
            await db.insert('ventas', {
              'id': 902,
              'numero_secuencial': 103,
              'negocio_id': 1,
              'creado_por_usuario_id': 1,
              'cliente_id': 77,
              'metodo_pago': 'efectivo',
              'monto_total': 120.0,
              'monto_pagado': 0.0,
              'fecha_venta': '2026-11-20T10:00:00Z',
              'estado_entrega': 'anulado',
              'origen_venta': 'catalogo',
              'is_archived': 1,
              'motivo_anulacion':
                  'Cliente solicitó cambio de talla escolar antes del despacho',
            });
          });

          final errorLogs = <String>[];
          final prevOnError = FlutterError.onError;
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;

          try {
            FlutterError.onError = (details) =>
                errorLogs.add(details.toString());

            final client = _buildRichClient();
            await tester.pumpWidget(
              ChangeNotifierProvider(
                create: (_) => AuthProvider(),
                child: MaterialApp(
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(1.3)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Builder(
                      builder: (ctx) => Center(
                        child: ElevatedButton(
                          onPressed: () {
                            showModalBottomSheet(
                              context: ctx,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => ClientFullStatsModal(
                                client: client,
                                isDark: false,
                              ),
                            );
                          },
                          child: const Text('Abrir Analítica'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );

            await tester.tap(find.text('Abrir Analítica'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 250)),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 900));

            expect(find.text('Analítica del Cliente'), findsOneWidget);
            expect(
              find.text('Rendimiento Comercial (Filtro Activo)'),
              findsOneWidget,
            );

            // Desplazar hasta Análisis de Cancelaciones para validar motivos largos en ancho compacto
            final statsScrollable = find
                .descendant(
                  of: find.byType(ListView).first,
                  matching: find.byWidgetPredicate(
                    (w) =>
                        w is Scrollable &&
                        w.axisDirection == AxisDirection.down,
                  ),
                )
                .first;
            await tester.scrollUntilVisible(
              find.text('Análisis de Cancelaciones'),
              250.0,
              scrollable: statsScrollable,
              maxScrolls: 25,
            );
            await tester.ensureVisible(find.text('Motivos Frecuentes'));
            await tester.pump();
            expect(find.text('Análisis de Cancelaciones'), findsOneWidget);
            expect(find.text('Motivos Frecuentes'), findsOneWidget);
          } finally {
            FlutterError.onError = prevOnError;
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            await tester.runAsync(() async {
              LocalDatabase.setCustomDatabase(null);
              await db.close();
            });
          }

          expect(
            errorLogs,
            isEmpty,
            reason:
                'FlutterError en ClientFullStatsModal @ ${viewport.width}x${viewport.height}:\n${errorLogs.join('\n---\n')}',
          );
        },
      );

      testWidgets(
        'LoyaltyWhatsAppService preview modal sin overflow @ 1.3x en ${viewport.width.toInt()}x${viewport.height.toInt()}dp',
        (tester) async {
          final errorLogs = <String>[];
          final prevOnError = FlutterError.onError;
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;

          try {
            FlutterError.onError = (details) =>
                errorLogs.add(details.toString());

            final rules = _buildLoyaltyRules();
            final goals = _buildRewardGoals();
            final sampleClient = _buildRichClient();

            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (ctx) => Center(
                      child: ElevatedButton(
                        onPressed: () {
                          LoyaltyWhatsAppService.showEditableWhatsAppPreviewModal(
                            context: ctx,
                            title: 'Cartilla Oficial del Club de Puntos',
                            phone: '',
                            initialMessage: 'Mensaje de prueba',
                            rules: rules,
                            activeGoals: goals,
                            businessName: 'Bodega El Sol',
                            availableClients: [sampleClient],
                            businessAddress: 'Av. Arequipa 123',
                            businessPhone: '987654321',
                          );
                        },
                        child: const Text('Abrir Cartilla'),
                      ),
                    ),
                  ),
                ),
              ),
            );

            await tester.tap(find.text('Abrir Cartilla'));
            await tester.pumpAndSettle();

            expect(
              find.text('Cartilla Oficial del Club de Puntos'),
              findsOneWidget,
            );
            expect(find.text('Compartir Cartilla'), findsOneWidget);

            // Cambiar a formato Resumen corto
            final resumenChip = find.text('Resumen Corto');
            await tester.ensureVisible(resumenChip);
            await tester.tap(resumenChip);
            await tester.pumpAndSettle();

            // Seleccionar cliente del dropdown para activar botón "Enviar por WhatsApp"
            await tester.tap(find.text('General para todos').first);
            await tester.pumpAndSettle();
            await tester.tap(
              find.text('María Fernanda Quispe Mamani (185 pts)').last,
            );
            await tester.pumpAndSettle();
            expect(find.text('Enviar por WhatsApp'), findsOneWidget);
          } finally {
            FlutterError.onError = prevOnError;
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }

          expect(
            errorLogs,
            isEmpty,
            reason:
                'FlutterError en LoyaltyWhatsApp preview @ ${viewport.width}x${viewport.height}:\n${errorLogs.join('\n---\n')}',
          );
        },
      );
    }
  });
}
