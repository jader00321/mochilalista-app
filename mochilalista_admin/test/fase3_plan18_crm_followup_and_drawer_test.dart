import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import '../lib/database_service.dart';
import '../lib/license_signer.dart';
import '../lib/config_service.dart';
import '../lib/excel_export_service.dart';
import '../lib/vault_storage_service.dart';
import 'support/web_bundle_loader.dart';
import '../server.dart';

void main() {
  group('Fase 3 - Plan Maestro 18: Cartera CRM, Próximo Seguimiento y Ficha 360°', () {
    late Directory tempDir;
    late DatabaseService db;
    late File clientsDbFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ml_crm_followup_test_');
      final dataDir = Directory('${tempDir.path}/data')..createSync(recursive: true);
      clientsDbFile = File('${dataDir.path}/sandbox_clients_db.json');
      clientsDbFile.writeAsStringSync(jsonEncode([]));
      db = DatabaseService(dataDir: dataDir.path);
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('1. DatabaseService: createClient persiste next_followup_date correctamente', () async {
      final client = await db.createClient({
        'business_name': 'Bodega El Triunfo',
        'owner_name': 'Carlos Mendoza',
        'phone': '987654321',
        'current_device_id': 'ML-7890',
        'license_type': 'MENSUAL',
        'license_status': 'ACTIVA',
        'installed_version': '9.36.0',
        'next_followup_date': '2026-11-30',
        'notes': 'Cliente interesado en bono IA adicional',
      });

      expect(client['id'], isNotNull);
      expect(client['business_name'], equals('Bodega El Triunfo'));
      expect(client['next_followup_date'], equals('2026-11-30'));

      final loaded = await db.getClientById(client['id'] as String);
      expect(loaded, isNotNull);
      expect(loaded!['next_followup_date'], equals('2026-11-30'));
    });

    test('2. DatabaseService: updateClient permite modificar y limpiar next_followup_date', () async {
      final client = await db.createClient({
        'business_name': 'Libreria Ramos',
        'owner_name': 'Rosa Ramos',
        'phone': '912345678',
        'current_device_id': 'ML-1122',
        'license_type': 'TRIMESTRAL',
        'license_status': 'ACTIVA',
        'installed_version': '9.36.0',
        'next_followup_date': '2026-12-01',
      });

      final cid = client['id'] as String;

      // Modificar fecha
      final updated1 = await db.updateClient(cid, {
        'next_followup_date': '2027-01-15',
      });
      expect(updated1!['next_followup_date'], equals('2027-01-15'));

      // Limpiar fecha pasando null o string vacío
      final updated2 = await db.updateClient(cid, {
        'next_followup_date': '',
      });
      expect(updated2!['next_followup_date'], isNull);

      final reloaded = await db.getClientById(cid);
      expect(reloaded!['next_followup_date'], isNull);
    });

    test('3. DatabaseService: Retrocompatibilidad con clientes sin next_followup_date', () async {
      // Escribir un cliente legacy directamente en el JSON sin el campo next_followup_date
      final legacyClient = {
        'id': 'CLI-LEGACY-001',
        'business_name': 'Farmacia Antigua',
        'owner_name': 'Dr. Salazar',
        'phone': '999888777',
        'current_device_id': 'ML-LEGA',
        'license_type': 'ANUAL',
        'license_status': 'ACTIVA',
        'created_at': '2026-01-01T00:00:00.000',
      };

      clientsDbFile.writeAsStringSync(jsonEncode([legacyClient]));

      final loaded = await db.getClientById('CLI-LEGACY-001');
      expect(loaded, isNotNull);
      expect(loaded!['next_followup_date'], isNull);

      // Debe poder agregarse el campo mediante updateClient sin alterar los demás datos
      final updated = await db.updateClient('CLI-LEGACY-001', {
        'next_followup_date': '2026-12-24',
      });
      expect(updated!['next_followup_date'], equals('2026-12-24'));
      expect(updated['business_name'], equals('Farmacia Antigua'));
    });

    test('4. index.html: Contiene los 3 nuevos chips de filtro CRM y alerta de Dashboard', () {
      final content = WebBundleLoader.loadHtml();
      expect(content, isNotEmpty);

      // Chips de filtro nuevos
      expect(content, contains('data-filter="trial"'));
      expect(content, contains('id="countTrial"'));
      expect(content, contains('data-filter="pending_bonus"'));
      expect(content, contains('id="chipFilterPendingBonus"'));
      expect(content, contains('id="countPendingBonus"'));
      expect(content, contains('data-filter="followup_due"'));
      expect(content, contains('id="chipFilterFollowupDue"'));
      expect(content, contains('id="countFollowupDue"'));

      // Alerta de dashboard
      expect(content, contains('id="dashPendingActionsAlert"'));
      expect(content, contains('id="dashFollowupAlertItem"'));
      expect(content, contains('id="dashFollowupAlertCount"'));
      expect(content, contains('id="dashBonusAlertItem"'));
      expect(content, contains('id="dashBonusAlertCount"'));

      // Campo en modal alta nuevo cliente
      expect(content, contains('id="grpNewFollowupDate"'));
      expect(content, contains('id="newFollowupDate"'));

      // Campos en Ficha 360°
      expect(content, contains('id="drawerFollowup"'));
      expect(content, contains('id="btnDrawerQuickEditFollowup"'));
      expect(content, contains('id="grpDrawerEditUpdates"'));
      expect(content, contains('id="grpDrawerEditFollowup"'));
      expect(content, contains('id="drawerEditFollowupDate"'));

      // Header de tabla hardware con white-space nowrap
      expect(content, contains('<th style="width:96px; min-width:96px; white-space:nowrap;">Fecha</th>'));
    });

    test('5. styles.css: Padding de .drawer-body y estilos de alerta / micro-botones', () {
      final content = WebBundleLoader.loadCss();
      expect(content, isNotEmpty);

      expect(content, contains('padding: 1.4rem 1.4rem 3rem 1.4rem;'));
      expect(content, contains('.dash-pending-alert'));
      expect(content, contains('.dash-alert-pill'));
      expect(content, contains('.dash-alert-pill.bonus'));
      expect(content, contains('.filter-chip.accent-pending'));
      expect(content, contains('.btn-micro-receipt'));
    });

    test('6. admin_app.js: Helpers formatPlanHumanLabel, formatPeruvianPhoneDisplay y getLocalIsoDate', () {
      final content = WebBundleLoader.loadJs();
      expect(content, isNotEmpty);

      expect(content, contains('function getLocalIsoDate('));
      expect(content, contains('function formatPeruvianPhoneDisplay('));
      expect(content, contains('function formatPlanHumanLabel('));
      expect(content, contains('currentClientFilter === \'followup_due\''));
      expect(content, contains('currentClientFilter === \'pending_bonus\''));
      expect(content, contains('currentClientFilter === \'trial\''));
      expect(content, contains('updateDrawerEditPlanFields(plan)'));
      expect(content, contains('grpUpdates.style.display = isPerpetualOrPass ? \'block\' : \'none\';'));
      expect(content, contains('btn-micro-receipt'));
    });

    test('7. Blindaje Visual: Cero emojis crudos en los nuevos componentes de Fase 3', () {
      final content = WebBundleLoader.loadHtml();

      // Extraer bloque de la alerta del dashboard
      final startDash = content.indexOf('id="dashPendingActionsAlert"');
      final endDash = content.indexOf('kpi-grid', startDash);
      final dashSection = content.substring(startDash, endDash);

      // Cero emojis en la alerta
      expect(dashSection.contains('🔔'), isFalse);
      expect(dashSection.contains('ℹ️'), isFalse);
      expect(dashSection.contains('⚠️'), isFalse);
      expect(dashSection.contains('📅'), isFalse);
      expect(dashSection.contains('⚡'), isFalse);

      // Verificar que los botones usan SVGs
      expect(dashSection, contains('<svg'));
    });

    test('8. REST HTTP E2E: Ciclo completo POST /api/clients y PUT /api/clients/:id con next_followup_date', () async {
      final dataDirectory = Directory('${tempDir.path}/data');
      final backupsDirectory = Directory('${tempDir.path}/backups');
      await dataDirectory.create(recursive: true);
      await backupsDirectory.create(recursive: true);

      final configService = ConfigService(dataDirectory: dataDirectory, backupsDirectory: backupsDirectory);
      await configService.init();

      final signer = LicenseSigner();
      final testSeed = List<int>.generate(32, (i) => (i * 3 + 7) % 256);
      await signer.initWithSeed(testSeed);

      final excelService = ExcelExportService(dbService: db, configService: configService);
      final vaultStorage = VaultStorageService(
        dbService: db,
        configService: configService,
        signer: signer,
      );
      await vaultStorage.initialize();

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) => handleRequest(
            req,
            db,
            signer,
            configService,
            excelService,
            vaultStorage,
          ));

      final client = HttpClient();

      try {
        // 1. POST /api/clients con next_followup_date inicial
        final postReq = await client.post('127.0.0.1', server.port, '/api/clients');
        postReq.headers.contentType = ContentType.json;
        postReq.write(jsonEncode({
          'business_name': 'Boutique Lima',
          'owner_name': 'Maria Paredes',
          'phone': '987111222',
          'current_device_id': 'ML-5566',
          'license_type': 'MENSUAL',
          'next_followup_date': '2026-11-22',
        }));
        final postRes = await postReq.close();
        expect(postRes.statusCode, equals(HttpStatus.created));

        final postBodyStr = await utf8.decodeStream(postRes);
        final createdData = jsonDecode(postBodyStr) as Map<String, dynamic>;
        expect(createdData['id'], isNotNull);
        expect(createdData['next_followup_date'], equals('2026-11-22'));
        final clientId = createdData['id'] as String;

        // 2. PUT /api/clients/:id actualizando fecha a 2026-11-30
        final putReq1 = await client.put('127.0.0.1', server.port, '/api/clients/$clientId');
        putReq1.headers.contentType = ContentType.json;
        putReq1.write(jsonEncode({
          'next_followup_date': '2026-11-30',
        }));
        final putRes1 = await putReq1.close();
        expect(putRes1.statusCode, equals(HttpStatus.ok));

        final putBodyStr1 = await utf8.decodeStream(putRes1);
        final updatedData1 = jsonDecode(putBodyStr1) as Map<String, dynamic>;
        expect(updatedData1['next_followup_date'], equals('2026-11-30'));

        // 3. PUT /api/clients/:id limpiando fecha a "" (debe almacenarse null)
        final putReq2 = await client.put('127.0.0.1', server.port, '/api/clients/$clientId');
        putReq2.headers.contentType = ContentType.json;
        putReq2.write(jsonEncode({
          'next_followup_date': '',
        }));
        final putRes2 = await putReq2.close();
        expect(putRes2.statusCode, equals(HttpStatus.ok));

        final putBodyStr2 = await utf8.decodeStream(putRes2);
        final updatedData2 = jsonDecode(putBodyStr2) as Map<String, dynamic>;
        expect(updatedData2['next_followup_date'], isNull);

        // 4. GET /api/clients/:id confirmando persistencia
        final getReq = await client.get('127.0.0.1', server.port, '/api/clients/$clientId');
        final getRes = await getReq.close();
        expect(getRes.statusCode, equals(HttpStatus.ok));

        final getBodyStr = await utf8.decodeStream(getRes);
        final reloadedData = jsonDecode(getBodyStr) as Map<String, dynamic>;
        expect(reloadedData['next_followup_date'], isNull);
        expect(reloadedData['business_name'], equals('Boutique Lima'));
      } finally {
        client.close();
        await server.close(force: true);
      }
    });
  });
}
