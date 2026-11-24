import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:archive/archive.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/backup_provider.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/services/backup/i_google_drive_backup_service.dart';
import 'package:app_movil/core/utils/backup_manager.dart';
import 'package:app_movil/core/utils/backup_crypto_helper.dart';
import 'package:app_movil/features/profile/screens/backup_screen.dart';
import 'package:app_movil/features/profile/widgets/google_drive_backup_sheet.dart';

/// Mock configurable del servicio de Google Drive para pruebas aisladas
class MockTestDriveBackupService implements IGoogleDriveBackupService {
  GoogleDriveUser? mockUser;
  DriveBackupConfig mockConfig = const DriveBackupConfig(isEnabled: true, frequency: BackupFrequency.daily);
  final List<GoogleDriveBackupMetadata> mockBackups = [];
  bool shouldThrowOAuthError = false;
  String? registeredTrialMarker;

  @override
  Future<GoogleDriveUser?> signIn() async {
    if (shouldThrowOAuthError) {
      throw Exception("com.google.android.gms.common.api.ApiException: 10: DEVELOPER_ERROR");
    }
    mockUser = const GoogleDriveUser(
      id: "google_user_123",
      email: "comerciante.mochilalista@gmail.com",
      displayName: "Comerciante MochilaLista",
    );
    return mockUser;
  }

  @override
  Future<GoogleDriveUser?> signInSilently() async => mockUser;

  @override
  Future<void> signOut() async {
    mockUser = null;
    mockBackups.clear();
  }

  @override
  Future<void> clearSession() async {
    mockUser = null;
    mockBackups.clear();
  }

  @override
  Future<GoogleDriveUser?> getCurrentUser() async => mockUser;

  @override
  Future<DriveBackupConfig> getConfig() async => mockConfig;

  @override
  Future<void> saveConfig(DriveBackupConfig config) async {
    mockConfig = config;
  }

  @override
  Future<GoogleDriveBackupMetadata?> uploadEncryptedBackup({String? customPassphrase}) async {
    final meta = GoogleDriveBackupMetadata(
      fileId: "drive_file_${mockBackups.length + 1}",
      fileName: "mochilalista_backup_test.mlbg",
      createdAt: DateTime.now(),
      sizeBytes: 1024 * 50,
    );
    mockBackups.insert(0, meta);
    return meta;
  }

  @override
  Future<List<GoogleDriveBackupMetadata>> listBackups() async => List.unmodifiable(mockBackups);

  @override
  Future<DriveRestoreResult> downloadAndRestoreBackup(String fileId, {String? customPassphrase}) async {
    return DriveRestoreResult(
      isSuccess: true,
      isSameDevice: true,
      requiresLicenseMigration: false,
      message: "Restauración exitosa",
    );
  }

  @override
  Future<bool> checkAndTriggerScheduledBackup({bool? isWifiConnected}) async => true;

  @override
  Future<void> registerTrialMarker(String hardwareId) async {
    registeredTrialMarker = hardwareId;
  }

  @override
  Future<bool> checkTrialMarkerExists(String hardwareId) async {
    return registeredTrialMarker == hardwareId;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;
  late Directory tempDir;
  const testDeviceId = 'ML-TEST-A54';

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    DeviceFingerprint.setMockFingerprint(testDeviceId);
    DeviceFingerprint.setMockAppSigningSha1("99:88:77:66:55:44:33:22:11:00:AA:BB:CC:DD:EE:FF:00:11:22:33");

    tempDir = await Directory.systemTemp.createTemp('ml_backup_test_');

    testDb = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(testDb);
    LocalDatabase.setCustomDatabase(testDb);
  });

  tearDown(() async {
    DeviceFingerprint.setMockFingerprint(null);
    DeviceFingerprint.setMockAppSigningSha1(null);
    LocalDatabase.setCustomDatabase(null);
    await testDb.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Pilar 3.1: Integridad Multi-Perfil de .mlbg y Versión Dinámica v9.39.0+83', () {
    test('Empaquetado global .mlbg contiene toda la base SQLite con múltiples negocios y versión dinámica', () async {
      // 1. Insertar Negocio 1 y Usuario 1
      final neg1Id = await testDb.insert('negocios', {
        'nombre_comercial': 'Bodega San Martín',
        'ruc': '10123456789',
        'direccion': 'Av. Peru 100',
        'moneda': 'S/',
      });
      await testDb.insert('usuarios', {
        'nombre_completo': 'Carlos Perez',
        'telefono': '911111111',
      });

      // 2. Insertar Negocio 2 y Usuario 2 (Segundo perfil)
      final neg2Id = await testDb.insert('negocios', {
        'nombre_comercial': 'Librería Central Escolar',
        'ruc': '20123456789',
        'direccion': 'Jr. Lima 200',
        'moneda': 'S/',
      });
      await testDb.insert('usuarios', {
        'nombre_completo': 'Ana Lopez',
        'telefono': '922222222',
      });

      // 3. Insertar productos en ambos negocios
      await testDb.insert('productos', {
        'negocio_id': neg1Id,
        'nombre': 'Arroz Costeño 1kg',
        'estado': 'publico',
      });

      await testDb.insert('productos', {
        'negocio_id': neg2Id,
        'nombre': 'Cuaderno Standford A4',
        'estado': 'publico',
      });

      // 4. Crear archivo físico temporal en la ruta oficial donde BackupManager consulta
      final dbFolder = await getDatabasesPath();
      final testDbFile = File(p.join(dbFolder, 'mochilalista.db'));
      if (await testDbFile.exists()) {
        await testDbFile.delete();
      }
      final exportedDb = await databaseFactoryFfiNoIsolate.openDatabase(testDbFile.path);
      await LocalDatabase.createDBForTesting(exportedDb);
      // Copiar registros al archivo
      await exportedDb.insert('negocios', {
        'id': neg1Id,
        'nombre_comercial': 'Bodega San Martín',
        'ruc': '10123456789',
        'direccion': 'Av. Peru 100',
        'moneda': 'S/',
      });
      await exportedDb.insert('negocios', {
        'id': neg2Id,
        'nombre_comercial': 'Librería Central Escolar',
        'ruc': '20123456789',
        'direccion': 'Jr. Lima 200',
        'moneda': 'S/',
      });
      await exportedDb.insert('productos', {
        'negocio_id': neg1Id,
        'nombre': 'Arroz Costeño 1kg',
        'estado': 'publico',
      });
      await exportedDb.insert('productos', {
        'negocio_id': neg2Id,
        'nombre': 'Cuaderno Standford A4',
        'estado': 'publico',
      });
      await exportedDb.close();

      // 5. Generar paquete .mlbg
      final backupFile = await BackupManager.createBackupFile(
        targetDir: tempDir,
        password: "TestPassword2026!",
        pbkdf2Iterations: 1000,
        customFileName: 'MochilaLista_MultiProfile_Test.mlbg',
      );

      expect(await backupFile.exists(), isTrue);

      // 6. Descifrar el contenedor .mlbg
      final fileBytes = await backupFile.readAsBytes();
      final decryptedZipBytes = await BackupCryptoHelper.decryptBackupPayload(
        fileBytes,
        password: "TestPassword2026!",
        pbkdf2Iterations: 1000,
      );

      final archive = ZipDecoder().decodeBytes(decryptedZipBytes);

      // Verificar existencia del manifiesto y versión dinámica
      final manifestFile = archive.findFile('manifest.json');
      expect(manifestFile, isNotNull);
      final manifestJson = jsonDecode(utf8.decode(manifestFile!.content as List<int>)) as Map<String, dynamic>;

      expect(
        manifestJson['app_version'],
        equals(OwnerLegalIdentity.currentAppVersionWithBuild),
        reason: 'El manifiesto debe reflejar dinámicamente la versión actual v9.39.0+83',
      );
      expect(manifestJson['device_fingerprint'], equals(testDeviceId));

      // Verificar que mochilalista.db está presente dentro del .mlbg
      final dbArchiveFile = archive.findFile('mochilalista.db');
      expect(dbArchiveFile, isNotNull);
    });
  });

  group('Pilar 3.2: Diálogo OAuth No Invasivo ante ApiException: 10 y Controles de Google Drive', () {
    testWidgets('Fallo OAuth muestra diálogo modal informativo con datos técnicos y botón de copiado para soporte',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockService = MockTestDriveBackupService()..shouldThrowOAuthError = true;
      final licenseProv = LicenseProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: licenseProv),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: GoogleDriveBackupSheet(
                backupService: mockService,
                isDark: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar que no hay textos cortados en la cabecera
      expect(find.text("Copia de Seguridad en Google Drive"), findsOneWidget);

      // Pulsar Vincular Cuenta de Google con ensureVisible para scroll dentro de SingleChildScrollView
      final vincularBtn = find.text("Vincular Cuenta de Google");
      await tester.ensureVisible(vincularBtn);
      await tester.pumpAndSettle();
      await tester.tap(vincularBtn);
      await tester.pumpAndSettle();

      // Debe aparecer el diálogo modal limpio y humano (NO un SnackBar rojo invasivo ni jerga técnica visible)
      expect(find.text("No se pudo conectar con Google Drive"), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      expect(find.textContaining("En este momento no fue posible vincular tu cuenta de Google"), findsOneWidget);
      expect(find.textContaining("Google Cloud Console"), findsNothing);
      expect(find.textContaining("SHA-1"), findsNothing);

      // Desplegar información técnica colapsada para soporte
      expect(find.text("Ver información técnica para soporte"), findsOneWidget);
      await tester.tap(find.text("Ver información técnica para soporte"));
      await tester.pumpAndSettle();

      // Ahora sí se muestran los datos técnicos y el botón de copiado
      expect(find.textContaining("com.mochilalista.app"), findsOneWidget);
      expect(find.textContaining(OwnerLegalIdentity.currentAppVersionWithBuild), findsOneWidget);
      expect(find.textContaining("99:88:77:66:55"), findsOneWidget); // Huella SHA-1 simulada
      expect(find.text("Copiar Datos de Soporte"), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

      // Pulsar Entendido para cerrar el diálogo
      await tester.tap(find.text("Entendido"));
      await tester.pumpAndSettle();

      expect(find.text("No se pudo conectar con Google Drive"), findsNothing);
    });

    testWidgets('Estado Vinculado muestra Controles Completos e Historial de 5 Copias', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockService = MockTestDriveBackupService()..shouldThrowOAuthError = false;
      // Pre-vincular usuario
      await mockService.signIn();
      await mockService.uploadEncryptedBackup();
      await mockService.uploadEncryptedBackup();

      final licenseProv = LicenseProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: licenseProv),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: GoogleDriveBackupSheet(
                backupService: mockService,
                isDark: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica datos de usuario y desvincular
      expect(find.text("comerciante.mochilalista@gmail.com"), findsOneWidget);
      expect(find.text("Desvincular"), findsOneWidget);

      // Verifica controles interactivos
      expect(find.text("Respaldar Ahora"), findsOneWidget);
      expect(find.text("Respaldo Automático en Google Drive"), findsOneWidget);
      expect(find.text("Frecuencia de Respaldo Automático"), findsOneWidget);
      expect(find.text("Solo con Wi-Fi"), findsOneWidget);

      // Alternancia Automático vs Manual (Paso 0 Fase 4)
      final autoSwitchFinder = find.widgetWithText(SwitchListTile, "Respaldo Automático en Google Drive");
      expect(autoSwitchFinder, findsOneWidget);

      // Desactivar respaldo automático -> Pasa a Modo manual
      await tester.tap(autoSwitchFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining("Modo manual"), findsOneWidget);
      expect(find.text("Frecuencia de Respaldo Automático"), findsNothing);
      expect(mockService.mockConfig.isEnabled, isFalse);

      // Reactivar respaldo automático -> Habilita selector de frecuencia nuevamente
      await tester.tap(autoSwitchFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining("Sincronización en segundo plano"), findsOneWidget);
      expect(find.text("Frecuencia de Respaldo Automático"), findsOneWidget);
      expect(mockService.mockConfig.isEnabled, isTrue);

      // Verifica lista cronológica de copias
      expect(find.textContaining("Copias en Google Drive (Últimas 5)"), findsOneWidget);
      expect(find.text("2/5 copias"), findsOneWidget);
      expect(find.text("Más reciente"), findsOneWidget);
    });
  });

  group('Pilar 3.3: Rediseño Jerárquico de BackupScreen en 2 Bloques (Nube vs Local) y 0px Overflow', () {
    testWidgets('Renderiza en 320x568dp con separación nítida Nube vs Local, cabecera unificada y 0px overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 48);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetPadding();
      });

      final mockDrive = MockTestDriveBackupService();
      final authProv = AuthProvider();
      final licenseProv = LicenseProvider();
      final backupProv = BackupProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProv),
            ChangeNotifierProvider.value(value: licenseProv),
            ChangeNotifierProvider.value(value: backupProv),
          ],
          child: MaterialApp(
            home: BackupScreen(
              driveBackupService: mockDrive,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Comprobar BLOQUE A: Copia de Seguridad en la Nube (Cabecera unificada sin duplicados)
      expect(find.text("Copia de Seguridad en la Nube"), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
      expect(find.text("Copia de Seguridad en Google Drive"), findsNothing);

      // 2. Comprobar BLOQUE B: Copia Local en el Teléfono (scroll down para visualizar en viewport compacto)
      final localHeaderFinder = find.text("Copia Local en el Teléfono");
      await tester.scrollUntilVisible(
        localHeaderFinder,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(localHeaderFinder, findsOneWidget);
      expect(find.byIcon(Icons.smartphone_rounded), findsOneWidget);
      expect(find.text("Respaldo Local Automático en Memoria del Teléfono"), findsOneWidget);

      // 3. Comprobar BLOQUE C: Seguridad y Bloqueo
      final securityHeaderFinder = find.text("Seguridad y Bloqueo");
      await tester.scrollUntilVisible(
        securityHeaderFinder,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(securityHeaderFinder, findsOneWidget);

      // Sin desbordes
      expect(tester.takeException(), isNull, reason: 'No deben existir desbordes en 320x568dp');
    });

    testWidgets('Renderiza en 360x640dp con separación nítida Nube vs Local, cabecera unificada y 0px overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 48);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetPadding();
      });

      final mockDrive = MockTestDriveBackupService();
      final authProv = AuthProvider();
      final licenseProv = LicenseProvider();
      final backupProv = BackupProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProv),
            ChangeNotifierProvider.value(value: licenseProv),
            ChangeNotifierProvider.value(value: backupProv),
          ],
          child: MaterialApp(
            home: BackupScreen(
              driveBackupService: mockDrive,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Comprobar BLOQUE A: Copia de Seguridad en la Nube (Cabecera unificada sin duplicados)
      expect(find.text("Copia de Seguridad en la Nube"), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
      expect(find.text("Copia de Seguridad en Google Drive"), findsNothing);

      // 2. Comprobar BLOQUE B: Copia Local en el Teléfono (scroll down para visualizar en viewport compacto)
      final localHeaderFinder = find.text("Copia Local en el Teléfono");
      await tester.scrollUntilVisible(
        localHeaderFinder,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(localHeaderFinder, findsOneWidget);
      expect(find.byIcon(Icons.smartphone_rounded), findsOneWidget);
      expect(find.text("Respaldo Local Automático en Memoria del Teléfono"), findsOneWidget);

      // 3. Comprobar BLOQUE C: Seguridad y Bloqueo
      final securityHeaderFinder = find.text("Seguridad y Bloqueo");
      await tester.scrollUntilVisible(
        securityHeaderFinder,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(securityHeaderFinder, findsOneWidget);

      // Sin desbordes
      expect(tester.takeException(), isNull, reason: 'No deben existir desbordes en 360x640dp');
    });
  });
}
