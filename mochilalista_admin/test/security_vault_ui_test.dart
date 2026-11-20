import 'dart:io';
import 'package:test/test.dart';
import '../lib/config_service.dart';
import '../lib/database_service.dart';
import '../lib/dpapi_service.dart';
import '../lib/license_signer.dart';
import '../lib/vault_storage_service.dart';

void main() {
  group('FASE 3 PLAN MAESTRO 10: Certificación de Interfaz Web de Bóveda y Portabilidad', () {
    late String htmlContent;
    late String cssContent;
    late String jsContent;

    setUpAll(() {
      final htmlFile = File('web/index.html');
      final cssFile = File('web/css/styles.css');
      final jsFile = File('web/js/admin_app.js');

      expect(htmlFile.existsSync(), isTrue, reason: 'index.html debe existir');
      expect(cssFile.existsSync(), isTrue, reason: 'styles.css debe existir');
      expect(jsFile.existsSync(), isTrue, reason: 'admin_app.js debe existir');

      htmlContent = htmlFile.readAsStringSync();
      cssContent = cssFile.readAsStringSync();
      jsContent = jsFile.readAsStringSync();
    });

    test('1. Sidebar y Vista Principal de Bóveda de Seguridad (#tabSecurityVault)', () {
      // Sidebar item con icono SVG y data-tab oficial
      expect(htmlContent.contains('data-tab="tabSecurityVault"'), isTrue);
      expect(htmlContent.contains('Seguridad y Portabilidad'), isTrue);

      // Pestaña principal presente
      expect(htmlContent.contains('id="tabSecurityVault"'), isTrue);
      expect(htmlContent.contains('Centro de Seguridad, Bóveda Cifrada y Portabilidad'), isTrue);

      // Bloque 1: Banner de Salud y Barra de Blindaje
      expect(htmlContent.contains('id="vaultHealthScore"'), isTrue);
      expect(htmlContent.contains('id="vaultProgressBar"'), isTrue);
      expect(htmlContent.contains('id="vaultHealthStatusText"'), isTrue);
      expect(htmlContent.contains('id="factorMirrorStatus"'), isTrue);
      expect(htmlContent.contains('id="factorKeyStatus"'), isTrue);
      expect(htmlContent.contains('id="factorRescueStatus"'), isTrue);
      expect(htmlContent.contains('id="factorPinStatus"'), isTrue);

      // Bloque 2: Transparencia Física (Cero Mito de Caché)
      expect(htmlContent.contains('id="txtLocalPath"'), isTrue);
      expect(htmlContent.contains('id="btnCopyLocalPath"'), isTrue);
      expect(htmlContent.contains('id="txtMirrorPath"'), isTrue);
      expect(htmlContent.contains('id="btnCopyMirrorPath"'), isTrue);
      expect(htmlContent.contains('id="tbodyVaultFiles"'), isTrue);
      expect(htmlContent.contains('id="btnSyncMirrorNow"'), isTrue);

      // Bloque 3: Asistente de Blindaje en 3 Pasos
      expect(htmlContent.contains('id="inputCloudSyncPath"'), isTrue);
      expect(htmlContent.contains('id="btnSaveCloudSyncPath"'), isTrue);
      expect(htmlContent.contains('id="btnDownloadMlKey"'), isTrue);
      expect(htmlContent.contains('id="btnOpenRescueKitModal"'), isTrue);

      // Bloque 4: Tarjeta de Mudanza Multi-PC (.mlvault)
      expect(htmlContent.contains('id="chkExportIncludeKey"'), isTrue);
      expect(htmlContent.contains('id="btnExportVault"'), isTrue);
      expect(htmlContent.contains('id="btnOpenImportVaultModal"'), isTrue);

      // Bloque 5: Bloqueo Local de Consola con PIN (HTTP 423 Locked)
      expect(htmlContent.contains('id="chkEnablePin"'), isTrue);
      expect(htmlContent.contains('id="btnLockConsoleNow"'), isTrue);
      expect(htmlContent.contains('id="pinSetupContainer"'), isTrue);
      expect(htmlContent.contains('id="inputVaultPin"'), isTrue);
      expect(htmlContent.contains('id="inputVaultPinConfirm"'), isTrue);
      expect(htmlContent.contains('id="btnSavePinConfig"'), isTrue);
    });

    test('2. Modales de Bóveda (#modalImportVault, #modalAutoRecovery, #vaultPinLockOverlay, #printableEmergencyKit)', () {
      // Modal: Importar Bóveda Portable
      expect(htmlContent.contains('id="modalImportVault"'), isTrue);
      expect(htmlContent.contains('id="vaultDropZone"'), isTrue);
      expect(htmlContent.contains('id="vaultFileInput"'), isTrue);
      expect(htmlContent.contains('id="vaultInspectSummary"'), isTrue);
      expect(htmlContent.contains('id="metaVaultVersion"'), isTrue);
      expect(htmlContent.contains('id="metaVaultClients"'), isTrue);
      expect(htmlContent.contains('id="metaVaultHasKey"'), isTrue);
      expect(htmlContent.contains('id="metaVaultSlots"'), isTrue);
      expect(htmlContent.contains('id="vaultUnlockFactorSection"'), isTrue);
      expect(htmlContent.contains('id="chkImportRewrap"'), isTrue);
      expect(htmlContent.contains('id="btnSubmitImportVault"'), isTrue);
      expect(htmlContent.contains('placeholder="Ej: ML-A1B2-C3D4-E5F6"'), isTrue);

      // Modal: Auto-Recuperación en 1 Clic desde %APPDATA%
      expect(htmlContent.contains('id="modalAutoRecovery"'), isTrue);
      expect(htmlContent.contains('id="btnAutoRecoverNow"'), isTrue);
      expect(htmlContent.contains('id="btnDismissAutoRecover"'), isTrue);

      // Overlay: Bloqueo de Consola por PIN a Pantalla Completa
      expect(htmlContent.contains('id="vaultPinLockOverlay"'), isTrue);
      expect(htmlContent.contains('id="formUnlockPin"'), isTrue);
      expect(htmlContent.contains('id="vaultPinInput"'), isTrue);
      expect(htmlContent.contains('id="btnSubmitUnlockPin"'), isTrue);
      expect(htmlContent.contains('id="vaultPinBackoffNotice"'), isTrue);
      expect(htmlContent.contains('id="linkForgotPin"'), isTrue);
      expect(htmlContent.contains('id="vaultPinRecoveryPanel"'), isTrue);
      expect(htmlContent.contains('id="recoveryKeyFileInput"'), isTrue);
      expect(htmlContent.contains('id="recoveryCodeInput"'), isTrue);
      expect(htmlContent.contains('id="btnRecoveryDpapi"'), isTrue);
      expect(htmlContent.contains('id="btnSubmitRecovery"'), isTrue);
      expect(htmlContent.contains('ML-XXXX-YYYY-ZZZZ'), isTrue);

      // Modal: Kit Imprimible / PDF de Emergencia
      expect(htmlContent.contains('id="printableEmergencyKit"'), isTrue);
      expect(htmlContent.contains('id="emergencyKitPrintArea"'), isTrue);
      expect(htmlContent.contains('id="kitGeneratedDate"'), isTrue);
      expect(htmlContent.contains('id="kitVaultId"'), isTrue);
      expect(htmlContent.contains('id="rescueCodesGrid"'), isTrue);
      expect(htmlContent.contains('id="rescueQrContainer"'), isTrue);
      expect(htmlContent.contains('id="btnCopyRescueCodes"'), isTrue);
      expect(htmlContent.contains('id="btnEmergencyPrint"'), isTrue);
    });

    test('3. Estilos CSS de Bóveda y Reglas Exclusivas @media print', () {
      expect(cssContent.contains('.vault-health-banner'), isTrue);
      expect(cssContent.contains('.vault-progress-track'), isTrue);
      expect(cssContent.contains('.vault-progress-fill'), isTrue);
      expect(cssContent.contains('.vault-factor-card'), isTrue);
      expect(cssContent.contains('.vault-drop-zone'), isTrue);
      expect(cssContent.contains('.factor-choice-row'), isTrue);
      expect(cssContent.contains('.vault-lock-overlay'), isTrue);
      expect(cssContent.contains('.vault-lock-card'), isTrue);
      expect(cssContent.contains('.rescue-codes-grid'), isTrue);
      expect(cssContent.contains('.rescue-code-item'), isTrue);

      // Reglas de impresión (@media print)
      expect(cssContent.contains('@media print'), isTrue);
      expect(cssContent.contains('@page'), isTrue);
      expect(cssContent.contains('#printableEmergencyKit'), isTrue);
      expect(cssContent.contains('#emergencyKitPrintArea'), isTrue);
      expect(cssContent.contains('.no-print'), isTrue);
      expect(cssContent.contains('white-space: nowrap'), isTrue);
    });

    test('4. Higiene y Robustez en JavaScript (admin_app.js)', () {
      // Cero window.alert o window.confirm
      expect(jsContent.contains('window.alert('), isFalse);
      expect(jsContent.contains('alert('), isFalse);
      expect(jsContent.contains('window.confirm('), isFalse);
      expect(jsContent.contains('confirm('), isFalse);

      // Paridad estricta de contratos JSON con server.dart
      expect(jsContent.contains('vault_json:'), isTrue);
      expect(jsContent.contains('credential_type:'), isTrue);
      expect(jsContent.contains('rewrap_dpapi:'), isTrue);
      expect(jsContent.contains('include_master_key:'), isTrue);
      expect(jsContent.contains('cloud_path:'), isTrue);
      expect(jsContent.contains('disable_pin: true'), isTrue);

      // Interceptor global de fetch para HTTP 423 Locked
      expect(jsContent.contains('_originalFetch'), isTrue);
      expect(jsContent.contains('X-Vault-Session-Token'), isTrue);
      expect(jsContent.contains('response.status === 423'), isTrue);
      expect(jsContent.contains('showVaultPinLockOverlay()'), isTrue);

      // Funciones de Bóveda operativas
      expect(jsContent.contains('initVaultEvents()'), isTrue);
      expect(jsContent.contains('checkVaultInitialStatus()'), isTrue);
      expect(jsContent.contains('loadVaultHealth()'), isTrue);
      expect(jsContent.contains('renderVaultFilesTable('), isTrue);
      expect(jsContent.contains('syncMirrorManual()'), isTrue);
      expect(jsContent.contains('saveCloudSyncPath()'), isTrue);
      expect(jsContent.contains('downloadMlKey()'), isTrue);
      expect(jsContent.contains('openRescueKitModal()'), isTrue);
      expect(jsContent.contains('exportPortableVault()'), isTrue);
      expect(jsContent.contains('handleVaultFileSelected('), isTrue);
      expect(jsContent.contains('inspectLoadedVault()'), isTrue);
      expect(jsContent.contains('submitImportVault()'), isTrue);
      expect(jsContent.contains('autoRecoverFromMirror()'), isTrue);
    });

    test('5. Contrato Backend en Aislamiento Temporal (Health, PIN Status y Lock)', () async {
      final tempProject = Directory.systemTemp.createTempSync('vault_ui_proj_');
      final tempMirror = Directory.systemTemp.createTempSync('vault_ui_mirror_');
      try {
        final dbService = DatabaseService(
          dataDir: '${tempProject.path}/data',
          backupDir: '${tempProject.path}/backups',
          releasesDir: '${tempProject.path}/releases_apks',
        );
        await dbService.init();

        final configService = ConfigService(
          dataDirectory: Directory('${tempProject.path}/data'),
          backupsDirectory: Directory('${tempProject.path}/backups'),
        );
        await configService.init();

        final signer = LicenseSigner();

        final service = VaultStorageService(
          projectRootDir: tempProject.path,
          mirrorDir: tempMirror.path,
          dpapiService: MockDpapiService('PC-TEST-UI'),
          dbService: dbService,
          configService: configService,
          signer: signer,
        );
        await service.initialize();

        // 1. Health check con vault_keyring y estadísticas de archivos
        final health = await service.checkStorageHealth();
        expect(health['primary_storage_path'], contains('data'));
        expect(health['mirror_storage_path'], contains('vault_ui_mirror_'));
        expect(health['files'], isA<Map>());
        final files = health['files'] as Map<String, dynamic>;
        expect(files.containsKey('vault_keyring'), isTrue);
        expect(files.containsKey('clients_db'), isTrue);
        expect(files['vault_keyring']['exists'], isTrue);

        // 2. PIN status y lock
        expect(service.isPinEnabled(), isFalse);
        await service.configurePin(pin: '9876', enabled: true);
        expect(service.isPinEnabled(), isTrue);

        final verifyRes = await service.verifyPin('9876');
        expect(verifyRes['ok'], isTrue);
        final token = verifyRes['session_token'] as String;
        expect(service.isSessionValid(token), isTrue);

        service.revokeSession(token);
        expect(service.isSessionValid(token), isFalse);
      } finally {
        if (tempProject.existsSync()) tempProject.deleteSync(recursive: true);
        if (tempMirror.existsSync()) tempMirror.deleteSync(recursive: true);
      }
    });
  });
}
