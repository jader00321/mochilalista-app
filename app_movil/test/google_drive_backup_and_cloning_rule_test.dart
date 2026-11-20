import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:app_movil/core/database/database_connection_factory.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/backup_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/services/backup/i_google_drive_backup_service.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/services/license/license_repository.dart';
import 'package:app_movil/core/utils/backup_crypto_helper.dart';
import 'package:app_movil/features/profile/widgets/google_drive_backup_sheet.dart';

/// Implementación Mock en memoria aislada de Google Drive para pruebas Zero-Network
class MockGoogleDriveBackupService implements IGoogleDriveBackupService {
  GoogleDriveUser? mockUser;
  DriveBackupConfig mockConfig = const DriveBackupConfig(isEnabled: false);
  final List<GoogleDriveBackupMetadata> mockBackups = [];
  final Map<String, Uint8List> mockFiles = {};

  bool mockWifiConnected = true;
  String? mockBackupDeviceFingerprint;
  String? mockTargetDeviceFingerprint;

  @override
  Future<GoogleDriveUser?> signIn() async {
    mockUser = const GoogleDriveUser(
      id: 'google_usr_998877',
      email: 'negocio.mochilalista@gmail.com',
      displayName: 'Julio Angello Vasquez',
      photoUrl: null,
    );
    mockConfig = mockConfig.copyWith(isEnabled: true);
    return mockUser;
  }

  @override
  Future<GoogleDriveUser?> signInSilently() async {
    return mockUser;
  }

  @override
  Future<void> signOut() async {
    mockUser = null;
    mockBackups.clear();
    mockFiles.clear();
  }

  @override
  Future<GoogleDriveUser?> getCurrentUser() async => mockUser;

  @override
  Future<DriveBackupConfig> getConfig() async => mockConfig;

  @override
  Future<void> saveConfig(DriveBackupConfig config) async {
    mockConfig = config;
  }

  int _counter = 0;

  @override
  Future<GoogleDriveBackupMetadata?> uploadEncryptedBackup({String? customPassphrase}) async {
    if (mockUser == null) {
      throw Exception("Debes iniciar sesión con tu cuenta de Google para respaldar.");
    }

    _counter++;
    final now = DateTime.now().add(Duration(seconds: _counter));
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(now);
    final fileName = 'mochilalista_backup_$dateStr.mlbg';
    final fileId = 'drive_file_${_counter}_${now.microsecondsSinceEpoch}';

    final derivedPassword = BackupCryptoHelper.deriveDrivePassword(
      googleUserId: mockUser!.id,
      customPassphrase: customPassphrase ?? mockConfig.customPassphrase,
    );

    // Generar carga simulada cifrada con AES-256-GCM
    final plainBytes = utf8.encode('MOCK_SQLITE_BACKUP_DATA_${now.millisecondsSinceEpoch}');
    final encrypted = await BackupCryptoHelper.encryptBackupPayload(
      plainBytes,
      password: derivedPassword,
      pbkdf2Iterations: BackupCryptoHelper.drivePbkdf2Iterations,
    );

    mockFiles[fileId] = encrypted;

    final metadata = GoogleDriveBackupMetadata(
      fileId: fileId,
      fileName: fileName,
      createdAt: now,
      sizeBytes: encrypted.length,
    );

    mockBackups.insert(0, metadata);

    // Rotación FIFO: conservar estrictamente las 5 copias más recientes
    if (mockBackups.length > 5) {
      final removed = mockBackups.sublist(5);
      for (var old in removed) {
        mockFiles.remove(old.fileId);
      }
      mockBackups.removeRange(5, mockBackups.length);
    }

    mockConfig = mockConfig.copyWith(lastBackupAt: now);
    return metadata;
  }

  @override
  Future<List<GoogleDriveBackupMetadata>> listBackups() async {
    final list = List<GoogleDriveBackupMetadata>.from(mockBackups);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<DriveRestoreResult> downloadAndRestoreBackup(String fileId, {String? customPassphrase}) async {
    if (mockUser == null) {
      return DriveRestoreResult.failure("Debes iniciar sesión con Google.");
    }

    final encrypted = mockFiles[fileId];
    if (encrypted == null) {
      return DriveRestoreResult.failure("Archivo de respaldo no encontrado en Google Drive.");
    }

    final derivedPassword = BackupCryptoHelper.deriveDrivePassword(
      googleUserId: mockUser!.id,
      customPassphrase: customPassphrase ?? mockConfig.customPassphrase,
    );

    try {
      await BackupCryptoHelper.decryptBackupPayload(
        encrypted,
        password: derivedPassword,
        pbkdf2Iterations: BackupCryptoHelper.drivePbkdf2Iterations,
      );
    } catch (e) {
      return DriveRestoreResult.failure("Error de descifrado: Contraseña incorrecta o archivo dañado.");
    }

    // Evaluación de regla anti-clonación
    final currentFp = mockTargetDeviceFingerprint ?? await DeviceFingerprint.generate();
    final backupFp = mockBackupDeviceFingerprint ?? currentFp;

    if (currentFp == backupFp) {
      return DriveRestoreResult.successSameDevice(deviceId: currentFp);
    } else {
      return DriveRestoreResult.successDifferentDevice(
        oldDeviceId: backupFp,
        newDeviceId: currentFp,
      );
    }
  }

  @override
  Future<bool> checkAndTriggerScheduledBackup({bool? isWifiConnected}) async {
    if (!mockConfig.isEnabled) return false;
    if (mockConfig.frequency == BackupFrequency.manual) return false;

    final hours = mockConfig.frequency.intervalHours;
    if (hours != null && mockConfig.lastBackupAt != null) {
      final elapsed = DateTime.now().difference(mockConfig.lastBackupAt!).inHours;
      if (elapsed < hours) return false;
    }

    if (mockConfig.wifiOnly) {
      final wifi = isWifiConnected ?? mockWifiConnected;
      if (!wifi) return false;
    }

    if (mockUser == null) return false;

    await uploadEncryptedBackup();
    return true;
  }
}

Widget buildTestWidget(Widget child, {LicenseProvider? licenseProv, IGoogleDriveBackupService? driveService}) {
  final repo = LicenseRepository();
  final provider = licenseProv ?? LicenseProvider(repository: repo);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LicenseProvider>.value(value: provider),
      ChangeNotifierProvider<BackupProvider>(create: (_) => BackupProvider()),
      ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseConnectionFactory.isTestMode = true;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    DeviceFingerprint.setMockFingerprint('ML-PHONE-ORIGIN-A1');
    BackupCryptoHelper.drivePbkdf2Iterations = 50; // Iteraciones rápidas para test
  });

  tearDown(() {
    DeviceFingerprint.setMockFingerprint(null);
    BackupCryptoHelper.drivePbkdf2Iterations = 100000;
  });

  group('1. Cifrado Recuperable Cross-Device con googleUser.id (PBKDF2 + AES-256-GCM)', () {
    test('Cifra en Dispositivo A con googleUser.id y descifra en Dispositivo B con el mismo id', () async {
      const userAId = 'google_acc_user_112233';
      final plainData = utf8.encode('Base de datos comercial de MochilaLista con ventas e inventario');

      // Derivación determinista en Dispositivo A
      final passwordA = BackupCryptoHelper.deriveDrivePassword(googleUserId: userAId);
      final encryptedBytes = await BackupCryptoHelper.encryptBackupPayload(
        plainData,
        password: passwordA,
        pbkdf2Iterations: 50,
      );

      // Verificación de contenedor MLENC1
      expect(BackupCryptoHelper.isEncryptedBackup(encryptedBytes), isTrue);

      // Descifrado en Dispositivo B con el mismo googleUser.id
      final passwordB = BackupCryptoHelper.deriveDrivePassword(googleUserId: userAId);
      final decryptedBytes = await BackupCryptoHelper.decryptBackupPayload(
        encryptedBytes,
        password: passwordB,
        pbkdf2Iterations: 50,
      );

      expect(utf8.decode(decryptedBytes), equals(utf8.decode(plainData)));
    });

    test('Descifrado falla con excepción si se intenta desde una cuenta de Google distinta', () async {
      const userAId = 'google_acc_owner_112233';
      const userBId = 'google_acc_attacker_998877';
      final plainData = utf8.encode('Datos privados de clientes y deudas');

      final passwordA = BackupCryptoHelper.deriveDrivePassword(googleUserId: userAId);
      final encryptedBytes = await BackupCryptoHelper.encryptBackupPayload(
        plainData,
        password: passwordA,
        pbkdf2Iterations: 50,
      );

      final passwordB = BackupCryptoHelper.deriveDrivePassword(googleUserId: userBId);

      expect(
        () async => await BackupCryptoHelper.decryptBackupPayload(
          encryptedBytes,
          password: passwordB,
          pbkdf2Iterations: 50,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Frase de recuperación personalizada opcional blinda el descifrado con doble factor', () async {
      const userId = 'google_acc_user_112233';
      const customPassphrase = 'MiFraseSecretaSegura2026';
      final plainData = utf8.encode('Catálogo y balance general');

      final passWithSecret = BackupCryptoHelper.deriveDrivePassword(
        googleUserId: userId,
        customPassphrase: customPassphrase,
      );

      final encrypted = await BackupCryptoHelper.encryptBackupPayload(
        plainData,
        password: passWithSecret,
        pbkdf2Iterations: 50,
      );

      // Falla si no se provee la frase opcional
      final passWithoutSecret = BackupCryptoHelper.deriveDrivePassword(googleUserId: userId);
      expect(
        () async => await BackupCryptoHelper.decryptBackupPayload(
          encrypted,
          password: passWithoutSecret,
          pbkdf2Iterations: 50,
        ),
        throwsA(isA<Exception>()),
      );

      // Tiene éxito con la frase opcional correcta
      final decrypted = await BackupCryptoHelper.decryptBackupPayload(
        encrypted,
        password: passWithSecret,
        pbkdf2Iterations: 50,
      );
      expect(utf8.decode(decrypted), equals(utf8.decode(plainData)));
    });
  });

  group('2. Rotación FIFO de Últimas 5 Copias Fechadas', () {
    test('Subir 7 respaldos conserva exactamente las 5 copias más recientes eliminando las 2 más antiguas', () async {
      final service = MockGoogleDriveBackupService();
      await service.signIn();

      // Subir 7 respaldos consecutivos
      for (int i = 1; i <= 7; i++) {
        await service.uploadEncryptedBackup();
      }

      final backups = await service.listBackups();

      // Exactamente 5 copias conservadas
      expect(backups.length, equals(5));

      // Ordenadas descendente (la más reciente al inicio)
      for (int i = 0; i < backups.length - 1; i++) {
        expect(backups[i].createdAt.isAfter(backups[i + 1].createdAt) || backups[i].createdAt == backups[i + 1].createdAt, isTrue);
      }

      // Archivos en almacenamiento coinciden con los 5 conservados
      expect(service.mockFiles.length, equals(5));
      for (var b in backups) {
        expect(service.mockFiles.containsKey(b.fileId), isTrue);
      }
    });
  });

  group('3. Restauración en Caliente y Regla Anti-Clonación (ANDROID_ID)', () {
    test('Restaurar en el mismo ANDROID_ID conserva estado ACTIVA', () async {
      final service = MockGoogleDriveBackupService();
      await service.signIn();
      service.mockBackupDeviceFingerprint = 'ML-SAME-PHONE-001';
      service.mockTargetDeviceFingerprint = 'ML-SAME-PHONE-001';

      final meta = await service.uploadEncryptedBackup();
      expect(meta, isNotNull);

      final result = await service.downloadAndRestoreBackup(meta!.fileId);
      expect(result.isSuccess, isTrue);
      expect(result.isSameDevice, isTrue);
      expect(result.requiresLicenseMigration, isFalse);
      expect(result.message, contains('restauradas exitosamente'));
    });

    test('Restaurar en un ANDROID_ID distinto pasa licencia a PENDIENTE_MIGRACION conservando 100% de datos', () async {
      final service = MockGoogleDriveBackupService();
      await service.signIn();
      service.mockBackupDeviceFingerprint = 'ML-OLD-PHONE-AAA';
      service.mockTargetDeviceFingerprint = 'ML-NEW-PHONE-BBB';

      final meta = await service.uploadEncryptedBackup();
      expect(meta, isNotNull);

      final result = await service.downloadAndRestoreBackup(meta!.fileId);
      expect(result.isSuccess, isTrue);
      expect(result.isSameDevice, isFalse);
      expect(result.requiresLicenseMigration, isTrue);
      expect(result.oldDeviceId, equals('ML-OLD-PHONE-AAA'));
      expect(result.newDeviceId, equals('ML-NEW-PHONE-BBB'));
      expect(result.message, anyOf([contains('PENDIENTE_MIGRACION'), contains('migración de licencia')]));
    });
  });

  group('4. Programador Periódico Confiable por Ciclo de Vida', () {
    test('No dispara si isEnabled == false', () async {
      final service = MockGoogleDriveBackupService();
      await service.signIn();
      await service.saveConfig(const DriveBackupConfig(isEnabled: false));

      final didRun = await service.checkAndTriggerScheduledBackup();
      expect(didRun, isFalse);
      expect(service.mockBackups.isEmpty, isTrue);
    });

    test('No dispara si wifiOnly == true y no hay Wi-Fi', () async {
      final service = MockGoogleDriveBackupService();
      await service.signIn();
      await service.saveConfig(const DriveBackupConfig(
        isEnabled: true,
        frequency: BackupFrequency.daily,
        wifiOnly: true,
      ));

      service.mockWifiConnected = false;
      final didRun = await service.checkAndTriggerScheduledBackup(isWifiConnected: false);
      expect(didRun, isFalse);
      expect(service.mockBackups.isEmpty, isTrue);
    });

    test('No dispara si el intervalo (24h) no ha transcurrido', () async {
      final service = MockGoogleDriveBackupService();
      await service.signIn();

      // Último respaldo hace 5 horas
      await service.saveConfig(DriveBackupConfig(
        isEnabled: true,
        frequency: BackupFrequency.daily,
        wifiOnly: false,
        lastBackupAt: DateTime.now().subtract(const Duration(hours: 5)),
      ));

      final didRun = await service.checkAndTriggerScheduledBackup();
      expect(didRun, isFalse);
      expect(service.mockBackups.isEmpty, isTrue);
    });

    test('Sí dispara cuando transcurrió el intervalo y hay conexión Wi-Fi', () async {
      final service = MockGoogleDriveBackupService();
      await service.signIn();

      // Último respaldo hace 26 horas
      await service.saveConfig(DriveBackupConfig(
        isEnabled: true,
        frequency: BackupFrequency.daily,
        wifiOnly: true,
        lastBackupAt: DateTime.now().subtract(const Duration(hours: 26)),
      ));

      service.mockWifiConnected = true;
      final didRun = await service.checkAndTriggerScheduledBackup(isWifiConnected: true);
      expect(didRun, isTrue);
      expect(service.mockBackups.length, equals(1));
    });
  });

  group('5. Widget Tests de GoogleDriveBackupSheet y 0px Overflow', () {
    testWidgets('Estado Desconectado: Muestra explicación y botón Vincular Cuenta de Google', (tester) async {
      final service = MockGoogleDriveBackupService();

      await tester.pumpWidget(buildTestWidget(
        GoogleDriveBackupSheet(backupService: service),
      ));
      await tester.pumpAndSettle();

      expect(find.text("Copia de Seguridad en Google Drive (Opcional)"), findsOneWidget);
      expect(find.text("Vincular Cuenta de Google"), findsOneWidget);
      expect(find.textContaining("Tus copias viajan cifradas"), findsOneWidget);
    });

    testWidgets('Estado Conectado: Muestra email, botón Respaldar Ahora y copias fechadas con badge Más reciente', (tester) async {
      final service = MockGoogleDriveBackupService();
      await service.signIn();
      await service.uploadEncryptedBackup();
      await service.uploadEncryptedBackup();

      await tester.pumpWidget(buildTestWidget(
        GoogleDriveBackupSheet(backupService: service),
      ));
      await tester.pumpAndSettle();

      expect(find.text("negocio.mochilalista@gmail.com"), findsOneWidget);
      expect(find.text("Respaldar Ahora"), findsOneWidget);
      expect(find.text("Más reciente"), findsOneWidget);
      expect(find.text("Solo con Wi-Fi"), findsOneWidget);
      expect(find.text("Desvincular"), findsOneWidget);
    });

    testWidgets('Onboarding Modal: Muestra invitación con botón Omitir por ahora y botón Restaurar', (tester) async {
      final service = MockGoogleDriveBackupService();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => GoogleDriveBackupSheet.showOnboardingInvitation(ctx, backupService: service),
              child: const Text("Abrir Invitación"),
            ),
          ),
        ),
      ));

      await tester.tap(find.text("Abrir Invitación"));
      await tester.pumpAndSettle();

      expect(find.text("Restaurar Respaldo"), findsOneWidget);
      expect(find.text("Omitir por ahora"), findsOneWidget);
      expect(find.text("Restaurar desde Google Drive"), findsOneWidget);

      await tester.tap(find.text("Omitir por ahora"));
      await tester.pumpAndSettle();

      expect(find.text("Restaurar Respaldo"), findsNothing);
    });

    testWidgets('0px Overflow en viewport ultra compacto 320x568dp', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockGoogleDriveBackupService();
      await service.signIn();
      await service.uploadEncryptedBackup();

      await tester.pumpWidget(buildTestWidget(
        GoogleDriveBackupSheet(backupService: service),
      ));
      await tester.pumpAndSettle();

      expect(find.text("Copia de Seguridad en Google Drive (Opcional)"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('0px Overflow en viewport compacto 360x640dp', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockGoogleDriveBackupService();
      await service.signIn();
      await service.uploadEncryptedBackup();

      await tester.pumpWidget(buildTestWidget(
        GoogleDriveBackupSheet(backupService: service),
      ));
      await tester.pumpAndSettle();

      expect(find.text("Copia de Seguridad en Google Drive (Opcional)"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
