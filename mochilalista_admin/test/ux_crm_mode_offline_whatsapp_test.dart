import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

import '../server.dart';
import '../lib/database_service.dart';
import 'support/web_bundle_loader.dart';

void main() {
  group('FASE 7: Certificación Integral UX, CRM Offline-First, Ficha 360° y WhatsApp', () {
    late Directory tempDir;
    late DatabaseService dbService;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ml_ux_cert_');
      dbService = DatabaseService(
        dataDir: '${tempDir.path}/data',
        backupDir: '${tempDir.path}/backups',
        releasesDir: '${tempDir.path}/releases',
      );
      await dbService.init();
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    // =========================================================================
    // PILAR 1: Segregación y Conmutación Dual de Entornos (sandbox ↔ prod)
    // =========================================================================
    group('Pilar 1: Segregación y Conmutación Dual de Entornos', () {
      test('1.1 Inicializa en sandbox y conmuta atómicamente a prod', () async {
        expect(dbService.currentMode, equals('sandbox'));

        dbService.setMode('prod');
        expect(dbService.currentMode, equals('prod'));

        dbService.setMode('sandbox');
        expect(dbService.currentMode, equals('sandbox'));
      });

      test('1.2 Rechaza modos inválidos con ArgumentError', () {
        expect(() => dbService.setMode('staging'), throwsArgumentError);
        expect(() => dbService.setMode('testing'), throwsArgumentError);
        expect(() => dbService.setMode(''), throwsArgumentError);
      });

      test('1.3 Aislamiento total de datos: escrituras en sandbox no afectan prod', () async {
        // En sandbox, crear un cliente demo
        dbService.setMode('sandbox');
        final clientDemo = await dbService.createClient({
          'business_name': 'Demo Sandbox Store',
          'owner_name': 'User Sandbox',
          'phone': '911222333',
          'current_device_id': 'ML-SBOX',
          'license_type': 'TRIAL',
        });
        expect(clientDemo['id'], isNotNull);

        final sandboxClients = await dbService.getClients();
        expect(sandboxClients.any((c) => c['business_name'] == 'Demo Sandbox Store'), isTrue);

        // Conmutar a prod
        dbService.setMode('prod');
        final prodClientsInitial = await dbService.getClients();
        // El cliente de sandbox NO debe existir en prod
        expect(prodClientsInitial.any((c) => c['business_name'] == 'Demo Sandbox Store'), isFalse);

        // Crear cliente real en prod
        final clientProd = await dbService.createClient({
          'business_name': 'Cliente Producción Real',
          'owner_name': 'Empresario Real',
          'phone': '999888777',
          'current_device_id': 'ML-PROD',
          'license_type': 'MENSUAL',
        });
        expect(clientProd['id'], isNotNull);

        final prodClientsAfter = await dbService.getClients();
        expect(prodClientsAfter.any((c) => c['business_name'] == 'Cliente Producción Real'), isTrue);

        // Conmutar de vuelta a sandbox y verificar que el cliente de prod NO existe en sandbox
        dbService.setMode('sandbox');
        final sandboxClientsAfter = await dbService.getClients();
        expect(sandboxClientsAfter.any((c) => c['business_name'] == 'Cliente Producción Real'), isFalse);
      });

      test('1.4 resetSandbox restablece sandbox sin tocar producción', () async {
        dbService.setMode('prod');
        await dbService.createClient({
          'business_name': 'Cliente Intocable',
          'owner_name': 'Dueño Intocable',
          'phone': '987111222',
          'current_device_id': 'ML-SAFE',
          'license_type': 'MENSUAL',
        });

        // Restablecer sandbox
        await dbService.resetSandbox();

        // Verificar que sandbox fue restaurado a datos iniciales
        dbService.setMode('sandbox');
        final sandboxClients = await dbService.getClients();
        expect(sandboxClients.isNotEmpty, isTrue);

        // Verificar que prod se mantiene intacto con su cliente
        dbService.setMode('prod');
        final prodClients = await dbService.getClients();
        expect(prodClients.any((c) => c['business_name'] == 'Cliente Intocable'), isTrue);
      });
    });

    // =========================================================================
    // PILAR 2: Comparador SemVer Riguroso y Salvaguarda de 0 Releases
    // =========================================================================
    group('Pilar 2: Comparador SemVer Riguroso y Salvaguarda 0 Releases', () {
      test('2.1 Comparaciones SemVer exactas de versión', () {
        expect(compareSemVer('9.34.0', '9.34.0'), equals(0));
        expect(compareSemVer('10.0.0', '9.99.9'), greaterThan(0));
        expect(compareSemVer('9.35.0', '9.34.9'), greaterThan(0));
        expect(compareSemVer('9.34.1', '9.34.0'), greaterThan(0));
        expect(compareSemVer('9.30.0', '9.34.0'), lessThan(0));
      });

      test('2.2 Manejo de prefijos "v" y metadatos de compilación (+ o -)', () {
        expect(compareSemVer('v9.34.0', '9.34.0'), equals(0));
        expect(compareSemVer('V9.34.0+78', '9.34.0+77'), equals(0));
        expect(compareSemVer('v9.34.0-rc1', '9.34.0'), equals(0));
        expect(compareSemVer('v10.0.0+100', 'v9.34.0+78'), greaterThan(0));
      });

      test('2.3 Salvaguarda #3: Cuando no hay versiones publicadas (0 releases), ningún cliente es obsoleto', () async {
        // En prod inicial no hay releases aún
        dbService.setMode('prod');
        final releases = await dbService.getReleases();
        expect(releases.isEmpty, isTrue);

        // Determinar versión más reciente usando la lógica oficial de server.dart
        String? latestVersion;
        for (final r in releases) {
          final vn = r['version_name'] as String? ?? '';
          if (vn.trim().isNotEmpty) {
            if (latestVersion == null || compareSemVer(vn, latestVersion) > 0) {
              latestVersion = vn.trim();
            }
          }
        }
        expect(latestVersion, isNull);

        // Si latestVersion es null, los clientes nunca se marcan como obsoletos
        final clientVer = '9.24.0';
        int outdatedCount = 0;
        if (latestVersion != null &&
            clientVer.isNotEmpty &&
            compareSemVer(clientVer, latestVersion) < 0) {
          outdatedCount++;
        }
        expect(outdatedCount, equals(0), reason: 'Salvaguarda #3 activa: 0 releases publicadas -> 0 desactualizados');
      });
    });

    // =========================================================================
    // PILAR 3: Modelo de Negocio 100% Offline-First en DatabaseService
    // =========================================================================
    group('Pilar 3: Modelo de Negocio 100% Offline-First en DatabaseService', () {
      test('3.1 Registro de Prospectos: anti-colisión con ID PENDIENTE y valores iniciales limpios', () async {
        // Crear 3 prospectos con hardware ID vacío o 'PENDIENTE'
        final p1 = await dbService.createClient({
          'business_name': 'Librería Alfa',
          'owner_name': 'Propietario 1',
          'phone': '987654321',
          'current_device_id': '',
          'license_type': 'PROSPECTO',
        });

        final p2 = await dbService.createClient({
          'business_name': 'Librería Beta',
          'owner_name': 'Propietario 2',
          'phone': '987654322',
          'current_device_id': 'PENDIENTE',
          'license_type': 'PROSPECTO',
        });

        final p3 = await dbService.createClient({
          'business_name': 'Librería Gamma',
          'owner_name': 'Propietario 3',
          'phone': '987654323',
          'current_device_id': null,
          'license_type': 'PROSPECTO',
        });

        // Ninguno debe colisionar
        expect(p1['id'], isNotNull);
        expect(p2['id'], isNotNull);
        expect(p3['id'], isNotNull);
        expect(p1['current_device_id'], equals('PENDIENTE'));
        expect(p2['current_device_id'], equals('PENDIENTE'));
        expect(p3['current_device_id'], equals('PENDIENTE'));

        // Atributos de prospecto: sin expiración, sin días trial falsos, 0 saldo IA reportado
        expect(p1['license_status'], equals('PROSPECTO'));
        expect(p1['license_expires'], isNull);
        expect(p1['trial_days_remaining'], isNull);
        expect(p1['updates_until'], isNull);
        expect(p1['ai_reported_balance'], equals(0));
      });

      test('3.2 Registro TRIAL con días reales y updates_until nulo (Offline-First)', () async {
        final trialClient = await dbService.createClient({
          'business_name': 'Bazar Don Pepe',
          'owner_name': 'Pepe Morales',
          'phone': '999111222',
          'current_device_id': 'ML-TR17',
          'license_type': 'TRIAL',
          'trial_days_remaining': 17,
        });

        expect(trialClient['trial_days_remaining'], equals(17));
        expect(trialClient['updates_until'], isNull,
            reason: 'En arquitectura Offline-First el trial no caduca en versiones');

        final expires = DateTime.parse(trialClient['license_expires'] as String);
        final diffDays = expires.difference(DateTime.now().toUtc()).inDays;
        expect(diffDays, inInclusiveRange(16, 17));
      });

      test('3.3 Normalización robusta de teléfonos Perú (+51)', () {
        expect(DatabaseService.normalizePeruPhone('987654321'), equals('+51987654321'));
        expect(DatabaseService.normalizePeruPhone('51987654321'), equals('+51987654321'));
        expect(DatabaseService.normalizePeruPhone('+51 987 654 321'), equals('+51987654321'));
        expect(DatabaseService.normalizePeruPhone('  +51-987-654-321  '), equals('+51987654321'));
        expect(DatabaseService.normalizePeruPhone(''), equals(''));
      });

      test('3.4 Separación transparente entre Créditos IA Reportados y Bonos Pendientes', () async {
        final client = await dbService.createClient({
          'business_name': 'Minimarket Los Pinos',
          'owner_name': 'Carmen Flores',
          'phone': '912345678',
          'current_device_id': 'ML-PINO',
          'license_type': 'MENSUAL',
          'ai_reported_balance': 38,
          'ai_pending_bonus': 15,
        });

        expect(client['ai_reported_balance'], equals(38));
        expect(client['ai_pending_bonus'], equals(15));
      });

      test('3.5 Sincronización de estado reportado desde el celular (syncClientReportedState)', () async {
        final client = await dbService.createClient({
          'business_name': 'Tienda El Progreso',
          'owner_name': 'Raúl Rojas',
          'phone': '955444333',
          'current_device_id': 'ML-OLD9',
          'license_type': 'TRIAL',
          'trial_days_remaining': 30,
        });
        final cId = client['id'] as String;

        // Simular sincronización desde reporte del celular
        final updated = await dbService.syncClientReportedState(
          clientId: cId,
          deviceId: 'ML-SYNC9',
          deviceModel: 'Xiaomi Redmi Note 12',
          installedVersion: '9.34.0',
          aiReportedBalance: 45,
          trialDaysRemaining: 18,
          notes: 'Sync validado por captura de WhatsApp',
        );

        expect(updated, isNotNull);
        expect(updated!['current_device_id'], equals('ML-SYNC9'));
        expect(updated['device_model'], equals('Xiaomi Redmi Note 12'));
        expect(updated['installed_version'], equals('9.34.0'));
        expect(updated['ai_reported_balance'], equals(45));
        expect(updated['trial_days_remaining'], equals(18));
      });
    });

    // =========================================================================
    // PILAR 4: CRUD Dinámico de Pagos e Historial de Hardware
    // =========================================================================
    group('Pilar 4: CRUD Dinámico de Pagos e Historial de Hardware', () {
      test('4.1 Alta, modificación y eliminación de pagos manuales', () async {
        final client = await dbService.createClient({
          'business_name': 'Comercial Andina',
          'owner_name': 'Ernesto Quispe',
          'phone': '944333222',
          'current_device_id': 'ML-PAGO',
          'license_type': 'MENSUAL',
        });
        final cId = client['id'] as String;

        // 1. Agregar Pago 1
        final updatedAfterP1 = await dbService.addPayment(cId, {
          'amount': 35.0,
          'plan': 'MENSUAL',
          'method': 'Yape',
          'reference': 'OP-98765',
          'notes': 'Pago mes noviembre',
          'date': '2026-11-20T10:00:00Z',
        });
        expect(updatedAfterP1, isNotNull);
        final p1List = updatedAfterP1!['payment_history'] as List;
        expect(p1List.isNotEmpty, isTrue);
        final p1 = p1List.last as Map<String, dynamic>;
        expect(p1['amount'], equals(35.0));
        final p1Id = p1['id'] as String;

        // 2. Agregar Pago 2
        final updatedAfterP2 = await dbService.addPayment(cId, {
          'amount': 90.0,
          'plan': 'TRIMESTRAL',
          'method': 'Plin',
          'reference': 'OP-98766',
          'notes': 'Adelanto trimestre',
          'date': '2026-11-20T11:00:00Z',
        });
        expect(updatedAfterP2, isNotNull);
        final p2List = updatedAfterP2!['payment_history'] as List;
        expect(p2List.length, equals(2));
        final p2Id = (p2List.last as Map<String, dynamic>)['id'] as String;

        // 3. Modificar Pago 1
        final updatedAfterEdit = await dbService.updatePayment(cId, p1Id, {
          'amount': 40.0,
          'plan': 'MENSUAL',
          'method': 'Transferencia BCP',
          'reference': 'OP-98765-MOD',
          'notes': 'Ajuste con comisión',
        });
        expect(updatedAfterEdit, isNotNull);
        final listAfterEdit = updatedAfterEdit!['payment_history'] as List;
        final editedP1 = listAfterEdit.firstWhere((p) => p['id'] == p1Id) as Map<String, dynamic>;
        expect(editedP1['amount'], equals(40.0));
        expect(editedP1['method'], equals('Transferencia BCP'));

        // 4. Eliminar Pago 2
        final updatedAfterDelete = await dbService.deletePayment(cId, p2Id);
        expect(updatedAfterDelete, isNotNull);

        // Verificar que solo queda Pago 1 actualizado
        final clFinal = await dbService.getClientById(cId);
        final listFinal = clFinal!['payment_history'] as List;
        expect(listFinal.length, equals(1));
        expect(listFinal.first['id'], equals(p1Id));
        expect(listFinal.first['amount'], equals(40.0));
      });

      test('4.2 getClientHistory expone tanto "device_history" como alias "hardware"', () async {
        final client = await dbService.createClient({
          'business_name': 'Ferretería El Tornillo',
          'owner_name': 'Manuel Gómez',
          'phone': '911999888',
          'current_device_id': 'ML-DEV1',
          'license_type': 'ANUAL',
        });
        final cId = client['id'] as String;

        final history = await dbService.getClientHistory(cId);
        expect(history, isNotNull);
        expect(history!.containsKey('device_history'), isTrue);
        expect(history.containsKey('hardware'), isTrue);

        final devHistory = history['device_history'] as List;
        final hwHistory = history['hardware'] as List;
        expect(devHistory, equals(hwHistory), reason: 'Alias hardware debe ser idéntico a device_history');
      });
    });

    // =========================================================================
    // PILAR 5: Verificación Estructural de Interfaz, QR y Modo Escritorio
    // =========================================================================
    group('Pilar 5: Verificación Estructural de Interfaz, QR y Modo Escritorio', () {
      late String html;
      late String css;
      late String js;
      late String qrJs;
      late String batContent;
      late String ps1Content;

      setUpAll(() {
        html = WebBundleLoader.loadHtml();
        css = WebBundleLoader.loadCss();
        js = WebBundleLoader.loadJs();
        qrJs = WebBundleLoader.resolveWebAssetFile('js/qrcode.min.js').readAsStringSync();
        batContent = WebBundleLoader.resolveRepoFile('Iniciar_MochilaLista_Admin.bat').readAsStringSync();
        ps1Content = WebBundleLoader.resolveRepoFile('Crear_Acceso_Directo_Escritorio.ps1').readAsStringSync();
      });

      test('5.1 index.html contiene todos los componentes creados en las Fases 1 a 6', () {
        // Conmutador Dual
        expect(html.contains('id="btnModeSandbox"'), isTrue);
        expect(html.contains('id="btnModeProd"'), isTrue);

        // Sidebar retraído y Tooltip flotante
        expect(html.contains('id="sidebarFloatingTooltip"'), isTrue);

        // Compositor Universal WhatsApp
        expect(html.contains('id="modalWaComposer"'), isTrue);
        expect(html.contains('id="waCompPhoneDisplay"'), isTrue);
        expect(html.contains('id="waCompMessage"'), isTrue);
        expect(html.contains('id="btnWaCompSend"'), isTrue);
        expect(html.contains('id="btnWaCompCopy"'), isTrue);

        // Ficha 360° Pestañas y selector histórico de licencias
        expect(html.contains('id="drawerClient360"'), isTrue);
        expect(html.contains('data-dtab="drawerTabOverview"'), isTrue);
        expect(html.contains('data-dtab="drawerTabQr"'), isTrue);
        expect(html.contains('data-dtab="drawerTabFinances"'), isTrue);
        expect(html.contains('data-dtab="drawerTabHardware"'), isTrue);
        expect(html.contains('data-dtab="drawerTabEdit"'), isTrue);
        expect(html.contains('id="drawerQrCodeSelector"'), isTrue);
        expect(html.contains('id="modalSyncReported"'), isTrue);

        // Zona de peligro para eliminación de clientes
        expect(html.contains('drawer-danger-zone'), isTrue);
        expect(html.contains('btnDrawerDeleteClient'), isTrue);
      });

      test('5.2 styles.css contiene las clases de modo, tooltip flotante y compositor WhatsApp', () {
        expect(css.contains('.mode-sandbox'), isTrue);
        expect(css.contains('.mode-prod'), isTrue);
        expect(css.contains('.sidebar-floating-tooltip'), isTrue);
        expect(css.contains('.wa-composer-icon-bubble'), isTrue);
        expect(css.contains('.btn-crm-action'), isTrue);
        expect(css.contains('.crm-actions-cell'), isTrue);
      });

      test('5.3 admin_app.js contiene renderSafeQrCode, openWhatsAppComposer y comparador SemVer', () {
        expect(js.contains('function renderSafeQrCode('), isTrue);
        expect(js.contains('async function openWhatsAppComposer('), isTrue);
        expect(js.contains('function openSyncReportedModal('), isTrue);
        expect(js.contains('function compareSemVer('), isTrue);
        expect(js.contains('async function openClient360Drawer('), isTrue);
      });

      test('5.4 qrcode.min.js define formalmente QRCode.CorrectLevel', () {
        expect(qrJs.contains('QRCode.CorrectLevel'), isTrue);
        expect(qrJs.contains('M:0') || qrJs.contains('M: 0'), isTrue);
      });

      test('5.5 Iniciar_MochilaLista_Admin.bat ejecuta en modo ventana --app=http://localhost:8080 con loop de espera', () {
        expect(batContent.contains('--app=http://localhost:8080'), isTrue);
        expect(batContent.contains('http://localhost:8080'), isTrue);
        expect(batContent.contains('mochilalista_admin'), isTrue);
        expect(batContent.contains('dart run server.dart'), isTrue);
      });

      test('5.6 Crear_Acceso_Directo_Escritorio.ps1 resuelve escritorio nativo/OneDrive y vincula ícono oficial', () {
        expect(ps1Content.contains("[Environment]::GetFolderPath('Desktop')"), isTrue);
        expect(ps1Content.contains('MochilaLista Admin.lnk'), isTrue);
        expect(ps1Content.contains('Iniciar_MochilaLista_Admin.bat'), isTrue);
        expect(ps1Content.contains('favicon.ico') || ps1Content.contains('app_icon.ico'), isTrue);
      });

      test('5.7 Existencia e integridad de recursos de identidad visual oficial', () {
        final favicon = WebBundleLoader.resolveWebAssetFile('favicon.ico');
        final appIcon = WebBundleLoader.resolveWebAssetFile('app_icon.ico');
        final icon192 = WebBundleLoader.resolveWebAssetFile('icon_192.png');
        final icon512 = WebBundleLoader.resolveWebAssetFile('icon_512.png');
        final manifest = WebBundleLoader.resolveWebAssetFile('manifest.json');

        expect(favicon.existsSync(), isTrue, reason: 'web/favicon.ico debe existir');
        expect(appIcon.existsSync(), isTrue, reason: 'web/app_icon.ico debe existir');
        expect(icon192.existsSync(), isTrue, reason: 'web/icon_192.png debe existir');
        expect(icon512.existsSync(), isTrue, reason: 'web/icon_512.png debe existir');
        expect(manifest.existsSync(), isTrue, reason: 'web/manifest.json debe existir');

        expect(favicon.lengthSync(), greaterThan(0));
        expect(appIcon.lengthSync(), greaterThan(50000), reason: 'Icono multi-resolución debe superar 50KB');
        expect(icon192.lengthSync(), greaterThan(0));
        expect(icon512.lengthSync(), greaterThan(0));

        final manifestJson = jsonDecode(manifest.readAsStringSync());
        expect(manifestJson['name'], contains('MochilaLista'));
      });
    });
  });
}
