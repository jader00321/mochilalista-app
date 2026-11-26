import 'dart:io';

import 'package:app_movil/core/database/database_connection_factory.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/features/analytics/data/peru_ubigeo_catalog.dart';
import 'package:app_movil/features/analytics/models/commercial_radar_model.dart';
import 'package:app_movil/features/analytics/services/commercial_radar_service.dart';
import 'package:app_movil/features/analytics/services/link_health_verifier.dart';
import 'package:app_movil/features/catalog/repositories/product_repository.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/services/sales_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
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
  expect(file.existsSync(), isTrue, reason: 'Falta el archivo $relPath');
  return file.readAsLinesSync().length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseConnectionFactory.isTestMode = true;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    CommercialRadarService.clearMemoryCache();
    CommercialRadarService.customHttpClient = MockClient(
      (_) async => throw const SocketException('Offline en entorno de prueba'),
    );
    CommercialRadarService.geminiCuratorMock = null;
    LinkHealthVerifier.clearCache();

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
    CommercialRadarService.clearMemoryCache();
    CommercialRadarService.customHttpClient = null;
    LocalDatabase.setCustomDatabase(null);
    await testDb.close();
  });

  group('Plan 25 Fase 7 (7A + 7B) — Censo completo bajo topes estrictos', () {
    test('Todos los módulos de Fase 7A y Fase 7B cumplen límites de líneas', () {
      final root = _resolveAppMovilRoot();

      // Fase 7A
      expect(_lineCount(root, 'lib/core/database/local_db.dart'), lessThan(350));
      for (final p in const [
        'lib/core/database/local_db_schema_v36.dart',
        'lib/core/database/local_db_migrations.dart',
        'lib/core/database/local_db_loyalty_init.dart',
      ]) {
        expect(_lineCount(root, p), lessThan(600));
      }

      expect(_lineCount(root, 'lib/features/catalog/repositories/product_repository.dart'), lessThan(400));
      for (final p in const [
        'lib/features/catalog/repositories/product_repository_queries.dart',
        'lib/features/catalog/repositories/product_repository_stock_audit.dart',
        'lib/features/catalog/repositories/product_repository_mutations.dart',
      ]) {
        expect(_lineCount(root, p), lessThan(600));
      }

      expect(_lineCount(root, 'lib/features/smart_quotation/services/client_service.dart'), lessThan(400));
      for (final p in const [
        'lib/features/smart_quotation/services/client_service_crud.dart',
        'lib/features/smart_quotation/services/client_service_ledger.dart',
        'lib/features/smart_quotation/services/client_service_payments.dart',
        'lib/features/smart_quotation/services/client_service_payment_fifo.dart',
        'lib/features/smart_quotation/services/client_service_loyalty.dart',
        'lib/features/smart_quotation/services/client_service_loyalty_rewards.dart',
      ]) {
        expect(_lineCount(root, p), lessThan(650));
      }

      // Fase 7B
      expect(_lineCount(root, 'lib/features/smart_quotation/services/sales_service.dart'), lessThan(350));
      for (final p in const [
        'lib/features/smart_quotation/services/sales_service_pos_tx.dart',
        'lib/features/smart_quotation/services/sales_service_history_stats.dart',
        'lib/features/smart_quotation/services/sales_service_void_restore.dart',
        'lib/features/smart_quotation/services/sales_service_restore_delivery.dart',
        'lib/features/smart_quotation/services/sales_service_morosidad.dart',
        'lib/features/smart_quotation/services/sales_service_notifications.dart',
      ]) {
        expect(_lineCount(root, p), lessThan(650));
      }

      expect(_lineCount(root, 'lib/features/analytics/services/commercial_radar_service.dart'), lessThan(350));
      for (final p in const [
        'lib/features/analytics/services/commercial_radar_sources.dart',
        'lib/features/analytics/services/commercial_radar_scoring.dart',
        'lib/features/analytics/services/commercial_radar_persistence.dart',
      ]) {
        expect(_lineCount(root, p), lessThan(600));
      }

      expect(_lineCount(root, 'lib/core/providers/notification_provider.dart'), lessThan(350));
      for (final p in const [
        'lib/core/providers/notification_provider_sync.dart',
        'lib/core/providers/notification_provider_generators.dart',
        'lib/core/providers/notification_provider_actions.dart',
        'lib/core/providers/notification_provider_lifecycle.dart',
      ]) {
        expect(_lineCount(root, p), lessThan(600));
      }
    });
  });

  group('Plan 25 Fase 7B — NotificationProvider (ChangeNotifier único)', () {
    test('Ciclo de lectura, archivo y silencio sobre instancia única ChangeNotifier', () async {
      await testDb.insert('usuarios', {
        'id': 1,
        'nombre_completo': 'Usuario Notif',
        'activo': 1,
      });
      await testDb.insert('negocios', {
        'id': 1,
        'nombre_comercial': 'Tienda Central',
        'id_dueno': 1,
      });

      final notifId = await testDb.insert('notificaciones', {
        'user_id': 1,
        'negocio_id': 1,
        'dedup_key': 'stock_bajo_99',
        'titulo': 'Stock Bajo de Prueba',
        'mensaje': 'Quedan pocas unidades.',
        'tipo': 'alerta',
        'nivel_prioridad': 'preventiva',
        'prioridad': 'Media',
        'leida': 0,
        'is_resolved': 0,
        'is_archived': 0,
        'is_silenced': 0,
        'mute_key': 'producto_99',
        'objeto_relacionado_tipo': 'producto',
        'objeto_relacionado_id': 99,
        'metadata_json': '{"product_id": 99}',
        'fecha_creacion': DateTime.now().toIso8601String(),
      });

      final provider = NotificationProvider();
      expect(provider, isA<ChangeNotifier>());

      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.updateContext(1, usuarioId: 1);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await provider.loadPreferences();
      await provider.fetchNotifications();

      expect(notifyCount, greaterThan(0));
      expect(provider.notifications.any((n) => n.id == notifId), isTrue);
      expect(provider.unreadCount, 1);
      expect(provider.pendingCount, 1);

      await provider.markAsRead(notifId);
      expect(provider.unreadCount, 0);

      await provider.archiveNotification(notifId);
      expect(provider.archivedCount, 1);
      expect(provider.pendingCount, 0);

      await provider.unarchiveNotification(notifId);
      expect(provider.archivedCount, 0);

      await provider.silenceNotification(notifId);
      expect(provider.silencedCount, 1);
    });
  });

  group('Plan 25 Fase 7B — CommercialRadarService (aislamiento y RSS offline)', () {
    test('Aisla ubicación/favoritos por profileId y parsea XML/fechas sin red real', () async {
      expect(
        CommercialRadarService.locationJsonPrefKey(1),
        isNot(CommercialRadarService.locationJsonPrefKey(2)),
      );
      expect(
        CommercialRadarService.savedNewsPrefKey(1),
        isNot(CommercialRadarService.savedNewsPrefKey(2)),
      );

      final locProfile1 = RadarLocation.fromLegacyString('Talara / Piura');
      final locProfile2 = RadarLocation.fromLegacyString('Cusco / Cusco');
      await CommercialRadarService.saveLocationForProfile(locProfile1, profileId: 1);
      await CommercialRadarService.saveLocationForProfile(locProfile2, profileId: 2);

      final loaded1 = await CommercialRadarService.loadLocationForProfile(
        profileId: 1,
        fallback: RadarLocation.fromLegacyString('Lima / Lima'),
      );
      final loaded2 = await CommercialRadarService.loadLocationForProfile(
        profileId: 2,
        fallback: RadarLocation.fromLegacyString('Lima / Lima'),
      );
      expect(loaded1.department, 'Piura');
      expect(loaded2.department, 'Cusco');

      final sampleItem = CommercialNewsItem(
        id: 'radar_test_1',
        title: 'Campaña Escolar Mayorista',
        summary: 'Demanda creciente de útiles.',
        impactAnalysis: 'Sube rotación en cuadernos.',
        actionableAdvice: 'Reforzar stock en vitrina.',
        category: 'Campaña',
        sourceName: 'PRODUCE',
        sourceUrl: 'https://www.gob.pe/produce',
        publishedAt: DateTime(2026, 11, 25, 10, 0),
        region: 'Piura',
        isLive: false,
        isOfflineGuide: true,
        scope: RadarNewsScope.regional,
        scopeLabel: 'Regional • Piura',
      );
      await CommercialRadarService.saveNewsItem(sampleItem, profileId: 1);
      expect(await CommercialRadarService.isNewsSaved('radar_test_1', profileId: 1), isTrue);
      expect(await CommercialRadarService.isNewsSaved('radar_test_1', profileId: 2), isFalse);

      const sampleXml = '''
<rss version="2.0">
  <channel>
    <item>
      <title><![CDATA[Comercio minorista crece en Perú - Diario Gestión]]></title>
      <link>https://gestion.pe/economia/nota-ejemplo</link>
      <pubDate>Wed, 25 Nov 2026 14:30:00 GMT</pubDate>
      <source url="https://gestion.pe">Diario Gestión</source>
    </item>
  </channel>
</rss>
''';
      final parsed = CommercialRadarService.parseRssXml(
        sampleXml,
        scope: RadarNewsScope.nacional,
        scopeLabel: 'Nacional • Perú',
        regionName: 'Perú',
      );
      expect(parsed, hasLength(1));
      expect(parsed.first['title'], contains('Comercio minorista crece'));

      final parsedDate = CommercialRadarService.parseRssPubDate('Wed, 25 Nov 2026 14:30:00 GMT');
      expect(parsedDate.year, 2026);
      expect(CommercialRadarService.getOfflineFallbackSignals(region: 'Talara / Piura'), isNotEmpty);
    });
  });

  group('Plan 25 Fase 7B — SalesService (POS, historial, anulación y morosidad)', () {
    test('createSale, voidSale, restoreSale y morosidad operan íntegros desde el import original', () async {
      await testDb.insert('usuarios', {
        'id': 1,
        'nombre_completo': 'Cajero Demo',
        'activo': 1,
      });
      await testDb.insert('negocios', {
        'id': 1,
        'nombre_comercial': 'Bodega Mochila',
        'id_dueno': 1,
      });

      final repo = ProductRepository();
      await repo.createFullProductTransaction(
        {
          'negocio_id': 1,
          'nombre': 'Lapicero Azul Fino',
          'deferred_brand_name': 'Faber',
          'deferred_category_name': 'Útiles',
        },
        [
          {
            'nombre_especifico': 'Caja x 12',
            'unidad_venta': 'Caja',
            'unidades_por_venta': 1,
            'precio_venta_final': 10.0,
            'stock_actual': 10,
            'es_default': 1,
            'activo': 1,
          },
        ],
      );
      final inv = await repo.fetchInventoryRaw(1, {'limit': 10, 'skip': 0});
      final prodId = inv.first['id'] as int;
      final presList = (await repo.fetchPresentationsForProductIdsRaw([prodId]))[prodId]!;
      final presId = presList.first['id'] as int;

      final client = await ClientService().createClient(
        {'nombre_completo': 'Carlos Ruiz', 'telefono': '999111222'},
        1,
        1,
      );

      final salesService = SalesService();
      expect(salesService.dbHelper, same(LocalDatabase.instance));

      final sale = await salesService.createSale(
        {
          'cliente_id': client.id,
          'metodo_pago': 'efectivo',
          'estado_pago': 'pagado',
          'estado_entrega': 'entregado',
          'monto_total': 20.0,
          'monto_pagado': 20.0,
          'items': [
            {
              'presentation_id': presId,
              'product_id': prodId,
              'quantity': 2,
              'unit_price': 10.0,
              'nombre_producto': 'Lapicero Azul Fino',
              'unidad_medida': 'Caja',
            },
          ],
        },
        1,
        1,
      );
      expect(sale.totalAmount, 20.0);

      var presRow = (await testDb.query('presentaciones_producto', where: 'id = ?', whereArgs: [presId])).first;
      expect(presRow['stock_actual'], 8);

      final history = await salesService.getHistory(1);
      expect(history, hasLength(1));
      final stats = await salesService.getStats(1);
      expect(stats.cantidadVentas, 1);
      final fetchedModel = await salesService.getSaleModel(sale.id);
      expect(fetchedModel?.id, sale.id);

      await salesService.voidSale(sale.id, 1, 'Error de digitación');
      presRow = (await testDb.query('presentaciones_producto', where: 'id = ?', whereArgs: [presId])).first;
      expect(presRow['stock_actual'], 10);

      await salesService.restoreSale(sale.id, 1);
      presRow = (await testDb.query('presentaciones_producto', where: 'id = ?', whereArgs: [presId])).first;
      expect(presRow['stock_actual'], 8);

      final creditSale = await salesService.createSale(
        {
          'cliente_id': client.id,
          'metodo_pago': 'credito',
          'estado_pago': 'pendiente',
          'estado_entrega': 'entregado',
          'monto_total': 30.0,
          'monto_pagado': 0.0,
          'items': [
            {
              'presentation_id': presId,
              'product_id': prodId,
              'quantity': 3,
              'unit_price': 10.0,
              'nombre_producto': 'Lapicero Azul Fino',
              'unidad_medida': 'Caja',
            },
          ],
          'cuotas': [
            {
              'numero_cuota': 1,
              'monto': 30.0,
              'fecha_vencimiento': '2025-01-15',
            },
          ],
        },
        1,
        1,
      );
      final cuotas = await testDb.query('cuotas', where: 'venta_id = ?', whereArgs: [creditSale.id]);
      expect(cuotas, hasLength(1));
      final cuotaId = cuotas.first['id'] as int;

      expect(await salesService.getVentaIdFromCuota(cuotaId), creditSale.id);
      expect(await salesService.getCuotaConCliente(cuotaId), isNotNull);
      expect(await salesService.aplicarMorosidadManual(cuotaId, tipo: 'fijo', valor: 5.0), isTrue);
      await salesService.syncCuotaNotification(cuotaId);
      expect(await salesService.quitarMorosidad(cuotaId), isTrue);
    });
  });
}
