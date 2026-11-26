import 'dart:io';

import 'package:app_movil/core/database/database_connection_factory.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/catalog/repositories/product_repository.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
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

  group('Plan 25 Fase 7A — Censo de tamaños bajo topes estrictos', () {
    test('local_db, product_repository y client_service cumplen sus topes de líneas', () {
      final root = _resolveAppMovilRoot();

      expect(_lineCount(root, 'lib/core/database/local_db.dart'), lessThan(350));
      expect(_lineCount(root, 'lib/core/database/local_db_schema_v36.dart'), lessThan(550));
      expect(_lineCount(root, 'lib/core/database/local_db_migrations.dart'), lessThan(600));
      expect(_lineCount(root, 'lib/core/database/local_db_loyalty_init.dart'), lessThan(550));

      expect(_lineCount(root, 'lib/features/catalog/repositories/product_repository.dart'), lessThan(400));
      expect(_lineCount(root, 'lib/features/catalog/repositories/product_repository_queries.dart'), lessThan(600));
      expect(_lineCount(root, 'lib/features/catalog/repositories/product_repository_stock_audit.dart'), lessThan(600));
      expect(_lineCount(root, 'lib/features/catalog/repositories/product_repository_mutations.dart'), lessThan(600));

      expect(_lineCount(root, 'lib/features/smart_quotation/services/client_service.dart'), lessThan(400));
      for (final partFile in const [
        'lib/features/smart_quotation/services/client_service_crud.dart',
        'lib/features/smart_quotation/services/client_service_ledger.dart',
        'lib/features/smart_quotation/services/client_service_payments.dart',
        'lib/features/smart_quotation/services/client_service_payment_fifo.dart',
        'lib/features/smart_quotation/services/client_service_loyalty.dart',
        'lib/features/smart_quotation/services/client_service_loyalty_rewards.dart',
      ]) {
        expect(_lineCount(root, partFile), lessThan(650));
      }
    });
  });

  group('Plan 25 Fase 7A — Inmutabilidad SQLite v36 (LocalDatabase)', () {
    test('PRAGMA user_version es 36 y existen todas las tablas críticas del esquema v36', () async {
      final versionRows = await testDb.rawQuery('PRAGMA user_version');
      expect(versionRows.first['user_version'], 36);

      final tableNames = await LocalDatabase.instance.getAllTableNames();
      const expectedTables = <String>[
        'usuarios',
        'negocios',
        'negocio_usuario',
        'codigos_acceso_negocio',
        'categorias',
        'marcas',
        'proveedores',
        'productos',
        'facturas_carga',
        'presentaciones_producto',
        'clientes',
        'smart_quotations',
        'smart_quotation_items',
        'ventas',
        'venta_items',
        'cuotas',
        'pagos',
        'notificaciones',
        'campanas_promocionales',
        'paquetes',
        'items_paquete',
        'reglas_promocion',
        'stock_ledger',
        'product_history',
        'business_snapshots',
        'metas_recompensas',
        'recompensas_cliente',
        'historial_puntos_reputacion',
        'eventos_financieros_cliente',
        'reglas_puntos_negocio',
        'notificaciones_silenciadas',
        'preferencias_notificaciones',
        'licencia_app',
      ];
      for (final table in expectedTables) {
        expect(tableNames, contains(table), reason: 'Falta tabla SQLite v36: $table');
      }

      expect(await LocalDatabase.isMuted(testDb, 1, 'no_existe'), isFalse);
      expect(await LocalDatabase.isChannelEnabled(testDb, 1, 'notif_cuotas_vencidas'), isTrue);
    });
  });

  group('Plan 25 Fase 7A — Paridad operativa de ProductRepository y ClientService', () {
    test('ProductRepository y ClientService operan completos desde sus imports originales', () async {
      await testDb.insert('usuarios', {
        'id': 1,
        'nombre_completo': 'Dueño Demo',
        'activo': 1,
      });
      await testDb.insert('negocios', {
        'id': 1,
        'nombre_comercial': 'Librería Central',
        'id_dueno': 1,
      });

      final repo = ProductRepository();
      await repo.createFullProductTransaction(
        {
          'negocio_id': 1,
          'nombre': 'Cuaderno A4 Cuadriculado',
          'deferred_brand_name': 'Alpha',
          'deferred_category_name': 'Cuadernos',
        },
        [
          {
            'nombre_especifico': 'Unidad',
            'unidad_venta': 'Unidad',
            'unidades_por_venta': 1,
            'precio_venta_final': 8.5,
            'stock_actual': 20,
            'es_default': 1,
            'activo': 1,
          },
        ],
      );

      final rawInventory = await repo.fetchInventoryRaw(1, {'limit': 20, 'skip': 0});
      expect(rawInventory, hasLength(1));
      final prodId = rawInventory.first['id'] as int;
      final loadedProd = await repo.getProductByIdRaw(prodId);
      expect(loadedProd?['nombre'], 'Cuaderno A4 Cuadriculado');
      expect((loadedProd?['presentaciones'] as List).length, 1);

      final presByProd = await repo.fetchPresentationsForProductIdsRaw([prodId]);
      expect(presByProd[prodId], hasLength(1));
      final counts = await repo.countInventoryRaw(1, {});
      expect(counts['products'], 1);

      final clientService = ClientService();
      expect(clientService.dbHelper, same(LocalDatabase.instance));

      final createdClient = await clientService.createClient(
        {'nombre_completo': 'María López', 'telefono': '987654321'},
        1,
        1,
      );
      expect(createdClient.fullName, 'María López');

      final found = await clientService.searchClients('María', 1);
      expect(found, hasLength(1));

      await clientService.recalculateClientDebt(createdClient.id);
      final ledger = await clientService.getClientLedger(createdClient.id);
      expect(ledger, isEmpty);

      final goals = await clientService.getRewardGoals(1);
      expect(goals.length, greaterThanOrEqualTo(4));
      final rules = await clientService.getLoyaltyRules(1);
      expect(rules.negocioId, 1);
    });
  });
}
