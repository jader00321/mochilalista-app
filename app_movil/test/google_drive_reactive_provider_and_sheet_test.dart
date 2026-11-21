import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/google_drive_backup_provider.dart';
import 'package:app_movil/core/providers/backup_provider.dart';
import 'package:app_movil/core/services/backup/i_google_drive_backup_service.dart';
import 'package:app_movil/features/profile/widgets/google_drive_backup_sheet.dart';
import 'package:app_movil/features/profile/screens/backup_screen.dart';

/// Mock instrumental de IGoogleDriveBackupService para verificar reactividad y Stale-While-Revalidate
class InstrumentalMockGoogleDriveService implements IGoogleDriveBackupService {
  GoogleDriveUser? mockUser;
  DriveBackupConfig mockConfig = const DriveBackupConfig(isEnabled: true);
  final List<GoogleDriveBackupMetadata> mockBackupsList = [];

  int listBackupsCalls = 0;
  int uploadCalls = 0;
  int restoreCalls = 0;
  bool shouldThrowOnList = false;
  Completer<void>? listBackupsCompleter;

  @override
  Future<GoogleDriveUser?> getCurrentUser() async => mockUser;

  @override
  Future<DriveBackupConfig> getConfig() async => mockConfig;

  @override
  Future<void> saveConfig(DriveBackupConfig config) async {
    mockConfig = config;
  }

  @override
  Future<List<GoogleDriveBackupMetadata>> listBackups() async {
    listBackupsCalls++;
    if (listBackupsCompleter != null) {
      await listBackupsCompleter!.future;
    }
    if (shouldThrowOnList) {
      throw Exception("Error simulado de red en Google Drive");
    }
    return List.from(mockBackupsList);
  }

  @override
  Future<GoogleDriveUser?> signIn() async {
    mockUser = const GoogleDriveUser(
      id: 'g_user_react_123',
      email: 'comerciante.activo@gmail.com',
      displayName: 'Comerciante Exitoso',
    );
    return mockUser;
  }

  @override
  Future<GoogleDriveUser?> signInSilently() async => mockUser;

  @override
  Future<void> signOut() async {
    mockUser = null;
    mockBackupsList.clear();
  }

  @override
  Future<void> clearSession() async {
    mockUser = null;
    mockBackupsList.clear();
  }

  @override
  Future<GoogleDriveBackupMetadata?> uploadEncryptedBackup({String? customPassphrase}) async {
    uploadCalls++;
    final meta = GoogleDriveBackupMetadata(
      fileId: 'backup_file_${DateTime.now().millisecondsSinceEpoch}',
      fileName: 'MochilaLista_Backup.mlbg',
      createdAt: DateTime.now(),
      sizeBytes: 85000,
    );
    mockBackupsList.insert(0, meta);
    return meta;
  }

  @override
  Future<DriveRestoreResult> downloadAndRestoreBackup(String fileId, {String? customPassphrase}) async {
    restoreCalls++;
    return DriveRestoreResult.successSameDevice(deviceId: 'DEV-TEST-123');
  }

  @override
  Future<bool> checkAndTriggerScheduledBackup({bool? isWifiConnected}) async => false;

  @override
  Future<void> registerTrialMarker(String hardwareId) async {}

  @override
  Future<bool> checkTrialMarkerExists(String hardwareId) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase 2: Certificación de GoogleDriveBackupProvider y Stale-While-Revalidate', () {
    testWidgets('1. Pintado instantáneo sin spinners al reentrar con TTL vigente', (tester) async {
      final mockService = InstrumentalMockGoogleDriveService();
      mockService.mockUser = const GoogleDriveUser(
        id: 'g_user_1',
        email: 'bodega.central@gmail.com',
        displayName: 'Bodega Central',
      );
      mockService.mockBackupsList.add(
        GoogleDriveBackupMetadata(
          fileId: 'f1',
          fileName: 'Copia1.mlbg',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          sizeBytes: 70000,
        ),
      );

      final provider = GoogleDriveBackupProvider(
        service: mockService,
        cacheTtl: const Duration(minutes: 5),
      );

      // Precargar en caché RAM
      await provider.initializeFromCache();
      expect(provider.isConnected, isTrue);
      expect(mockService.listBackupsCalls, equals(1));

      // Montar widget dentro de MaterialApp
      Widget buildHost(Widget child) {
        return MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<GoogleDriveBackupProvider?>.value(value: provider),
              ],
              child: child,
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHost(const GoogleDriveBackupSheet()));
      // 1 solo frame (renderizado inicial directo)
      await tester.pump();

      // Verificar que NO hay spinner bloqueante
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'No debe mostrar CircularProgressIndicator si los datos ya están en caché.');

      expect(find.text("bodega.central@gmail.com"), findsOneWidget);
      expect(find.text("Respaldar Ahora"), findsOneWidget);
      expect(find.text("1/5 copias"), findsOneWidget);

      // Desmontar widget (simulando que el usuario navega a otra pantalla)
      await tester.pumpWidget(buildHost(const SizedBox()));
      await tester.pump();

      // Re-montar widget (simulando que el usuario regresa a Respaldos y Seguridad)
      await tester.pumpWidget(buildHost(const GoogleDriveBackupSheet()));
      await tester.pump();

      // Verificar que sigue sin mostrar spinner y que los datos están al instante
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text("bodega.central@gmail.com"), findsOneWidget);
      expect(find.text("1/5 copias"), findsOneWidget);

      // Comprobar que dentro del TTL de 5 minutos NO se disparó otra llamada a red
      expect(mockService.listBackupsCalls, equals(1),
          reason: 'El TTL de 5 minutos debe impedir llamadas de red innecesarias al reentrar.');
    });

    testWidgets('2. Cero desmontaje ni saltos al hacer scroll en BackupScreen (wantKeepAlive == true)', (tester) async {
      final mockService = InstrumentalMockGoogleDriveService();
      mockService.mockUser = const GoogleDriveUser(
        id: 'g_user_keepalive',
        email: 'ferreteria.lima@gmail.com',
        displayName: 'Ferretería Lima',
      );
      mockService.mockBackupsList.add(
        GoogleDriveBackupMetadata(
          fileId: 'f_keep',
          fileName: 'Ferreteria_Copia.mlbg',
          createdAt: DateTime.now(),
          sizeBytes: 95000,
        ),
      );

      final driveProv = GoogleDriveBackupProvider(
        service: mockService,
        cacheTtl: const Duration(minutes: 5),
      );
      await driveProv.initializeFromCache();

      final backupProv = BackupProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<GoogleDriveBackupProvider?>.value(value: driveProv),
            ChangeNotifierProvider<BackupProvider>.value(value: backupProv),
          ],
          child: const MaterialApp(
            home: BackupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("ferreteria.lima@gmail.com"), findsOneWidget);
      expect(find.text("1/5 copias"), findsOneWidget);
      final initialCalls = mockService.listBackupsCalls;

      // Hacer scroll profundo hacia abajo en el ListView
      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pumpAndSettle();

      // Hacer scroll de regreso hasta la parte superior
      await tester.drag(find.byType(ListView), const Offset(0, 1200));
      await tester.pumpAndSettle();

      // Gracias a AutomaticKeepAliveClientMixin, no se destruyó el estado ni se disparó spinner
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text("ferreteria.lima@gmail.com"), findsOneWidget);
      expect(find.text("1/5 copias"), findsOneWidget);
      expect(mockService.listBackupsCalls, equals(initialCalls),
          reason: 'El scroll no debe destruir el widget ni disparar recargas innecesarias.');
    });

    testWidgets('3. Patrón Stale-While-Revalidate: Preserva vista previa y actualiza silenciosamente / muestra error discreto', (tester) async {
      final mockService = InstrumentalMockGoogleDriveService();
      mockService.mockUser = const GoogleDriveUser(
        id: 'g_user_swr',
        email: 'market.sol@gmail.com',
        displayName: 'Market Sol',
      );
      mockService.mockBackupsList.add(
        GoogleDriveBackupMetadata(
          fileId: 'c1',
          fileName: 'CopiaVieja.mlbg',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          sizeBytes: 50000,
        ),
      );

      // Usar TTL de 0 para forzar revalidación silenciosa
      final provider = GoogleDriveBackupProvider(
        service: mockService,
        cacheTtl: Duration.zero,
      );
      await provider.initializeFromCache();
      await provider.syncBackupsSilently(force: true);
      expect(provider.backups.length, equals(1));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<GoogleDriveBackupProvider?>.value(value: provider),
              ],
              child: const GoogleDriveBackupSheet(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("market.sol@gmail.com"), findsOneWidget);
      expect(find.text("1/5 copias"), findsOneWidget);

      // Añadir una segunda copia al servicio en la nube
      mockService.mockBackupsList.add(
        GoogleDriveBackupMetadata(
          fileId: 'c2',
          fileName: 'CopiaNueva.mlbg',
          createdAt: DateTime.now(),
          sizeBytes: 55000,
        ),
      );

      final completer = Completer<void>();
      mockService.listBackupsCompleter = completer;

      // Disparar sincronización silenciosa (Stale-While-Revalidate)
      final syncFuture = provider.syncBackupsSilently();
      // Durante la sincronización, la copia vieja SIGUE VISIBLE sin saltos
      await tester.pump();
      expect(provider.isSyncingSilently, isTrue);
      expect(find.text("market.sol@gmail.com"), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget); // Indicador sutil de sincronización activa

      completer.complete();
      await syncFuture;
      mockService.listBackupsCompleter = null;
      await tester.pumpAndSettle();

      // Al completar, ahora muestra 2 copias sin saltos visuales destructivos
      expect(provider.backups.length, equals(2));
      expect(find.text("2/5 copias"), findsOneWidget);

      // Simular fallo de red en la siguiente revalidación
      mockService.shouldThrowOnList = true;
      await provider.syncBackupsSilently(force: true);
      await tester.pumpAndSettle();

      // Las 2 copias deben permanecer visibles y desplegar aviso discreto con Reintentar
      expect(provider.backups.length, equals(2));
      expect(find.text("No se pudieron sincronizar las copias más recientes. Mostrando copia guardada."), findsOneWidget);
      expect(find.text("Reintentar"), findsOneWidget);
    });

    test('4. Coordinación anti-carrera en instalación limpia: resetForCleanInstall deja provider 100% limpio', () {
      final mockService = InstrumentalMockGoogleDriveService();
      final provider = GoogleDriveBackupProvider(service: mockService);

      provider.resetForCleanInstall();

      expect(provider.isConnected, isFalse);
      expect(provider.currentUser, isNull);
      expect(provider.backups, isEmpty);
      expect(provider.lastSyncedAt, isNull);
      expect(provider.lastError, isNull);
      expect(provider.isInitialLoading, isFalse);
      expect(provider.hasInitialized, isTrue);
    });

    testWidgets('5. Retrocompatibilidad nullable: GoogleDriveBackupSheet sin Provider en el árbol no arroja ProviderNotFoundException', (tester) async {
      final mockService = InstrumentalMockGoogleDriveService();
      mockService.mockUser = null;

      // Montar GoogleDriveBackupSheet de forma aislada sin ningún Provider en el árbol
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleDriveBackupSheet(backupService: mockService),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe montar correctamente y mostrar estado No Vinculado sin fallar
      expect(find.text("Vincular Cuenta de Google"), findsOneWidget);
      expect(find.text("Copia de Seguridad en Google Drive"), findsOneWidget);
    });
  });

  group('Fase 4: Certificación de Pulido Visual y Usabilidad en Respaldos y Seguridad', () {
    testWidgets('1. Barra de estado superior en BackupScreen configura systemOverlayStyle según brillo', (tester) async {
      final mockService = InstrumentalMockGoogleDriveService();
      final driveProv = GoogleDriveBackupProvider(service: mockService);
      final mockBackupProv = BackupProvider();

      // Caso 1: Tema Claro -> Iconos oscuros de barra de estado
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<BackupProvider>.value(value: mockBackupProv),
              ChangeNotifierProvider<GoogleDriveBackupProvider?>.value(value: driveProv),
            ],
            child: const BackupScreen(key: Key('light_backup')),
          ),
        ),
      );
      await tester.pump();

      final lightAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(lightAppBar.systemOverlayStyle?.statusBarIconBrightness, equals(Brightness.dark));

      // Caso 2: Tema Oscuro -> Iconos claros de barra de estado
      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: ThemeData.dark(),
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider<BackupProvider>.value(value: mockBackupProv),
                ChangeNotifierProvider<GoogleDriveBackupProvider?>.value(value: driveProv),
              ],
              child: const BackupScreen(key: Key('dark_backup')),
            ),
          ),
        ),
      );
      await tester.pump();

      final darkAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(darkAppBar.systemOverlayStyle?.statusBarIconBrightness, equals(Brightness.light));
    });

    test('2. GoogleDriveBackupMetadata.formattedDate convierte UTC a hora local determinista y sin errores de locale', () {
      // Caso A: Hora en la tarde (17:35 local -> 05:35 PM)
      final localDateA = DateTime(2026, 11, 20, 17, 35);
      final metaA = GoogleDriveBackupMetadata(
        fileId: 'meta_1',
        fileName: 'backup_1.mlbg',
        createdAt: localDateA.toUtc(),
        sizeBytes: 85000,
      );
      expect(metaA.formattedDate, equals('20/11/2026 • 05:35 PM'));

      // Caso B: Hora en la mañana (09:05 local -> 09:05 AM)
      final localDateB = DateTime(2026, 11, 20, 9, 5);
      final metaB = GoogleDriveBackupMetadata(
        fileId: 'meta_2',
        fileName: 'backup_2.mlbg',
        createdAt: localDateB.toUtc(),
        sizeBytes: 1024,
      );
      expect(metaB.formattedDate, equals('20/11/2026 • 09:05 AM'));

      // Caso C: Medianoche (00:00 local -> 12:00 AM)
      final localDateC = DateTime(2026, 1, 1, 0, 0);
      final metaC = GoogleDriveBackupMetadata(
        fileId: 'meta_3',
        fileName: 'backup_3.mlbg',
        createdAt: localDateC.toUtc(),
        sizeBytes: 2048,
      );
      expect(metaC.formattedDate, equals('01/01/2026 • 12:00 AM'));

      // Caso D: Mediodía (12:00 local -> 12:00 PM)
      final localDateD = DateTime(2026, 6, 15, 12, 0);
      final metaD = GoogleDriveBackupMetadata(
        fileId: 'meta_4',
        fileName: 'backup_4.mlbg',
        createdAt: localDateD.toUtc(),
        sizeBytes: 4096,
      );
      expect(metaD.formattedDate, equals('15/06/2026 • 12:00 PM'));
    });

    testWidgets('3. Tarjeta de usuario conectado en 3 filas: correo sin truncar al 100% y reloj de última copia', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockService = InstrumentalMockGoogleDriveService();
      mockService.mockUser = const GoogleDriveUser(
        id: 'u_long',
        email: 'vjulioangello.largename.business@gmail.com',
        displayName: 'Julio Angello',
      );
      mockService.mockConfig = const DriveBackupConfig(
        isEnabled: true,
        lastBackupAt: null,
      );

      final driveProv = GoogleDriveBackupProvider(service: mockService);
      await driveProv.initializeFromCache();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<GoogleDriveBackupProvider?>.value(
              value: driveProv,
              child: const GoogleDriveBackupSheet(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Fila 1: Nombre de usuario y botón Desvincular
      expect(find.text("Julio Angello"), findsOneWidget);
      expect(find.text("Desvincular"), findsOneWidget);

      // Fila 2: Correo completo visible sin truncamiento
      expect(find.text("vjulioangello.largename.business@gmail.com"), findsOneWidget);

      // Fila 3: Indicador discreto con semáforo Sin copias en la nube
      expect(find.text("Sin copias en la nube"), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);

      // Cero excepciones de RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Botón manual de actualizar copias (Icons.refresh_rounded) y micro-spinner durante sincronización silenciosa', (tester) async {
      final mockService = InstrumentalMockGoogleDriveService();
      mockService.mockUser = const GoogleDriveUser(
        id: 'u_refresh',
        email: 'bodega.central@gmail.com',
        displayName: 'Bodega Central',
      );
      final driveProv = GoogleDriveBackupProvider(
        service: mockService,
        cacheTtl: Duration.zero,
      );
      await driveProv.initializeFromCache();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<GoogleDriveBackupProvider?>.value(
              value: driveProv,
              child: const GoogleDriveBackupSheet(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Botón de refresco manual presente
      final refreshButtonFinder = find.byTooltip("Actualizar lista de copias");
      expect(refreshButtonFinder, findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      // Simular sincronización pendiente
      final completer = Completer<void>();
      mockService.listBackupsCompleter = completer;

      // Presionar el botón de refresco manual
      await tester.tap(refreshButtonFinder);
      await tester.pump();

      // Ahora driveProv.isSyncingSilently está en true: se muestra micro-spinner y se oculta el botón
      expect(driveProv.isSyncingSilently, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsNothing);

      // Completar la sincronización
      completer.complete();
      await tester.pumpAndSettle();
      mockService.listBackupsCompleter = null;

      expect(driveProv.isSyncingSilently, isFalse);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(mockService.listBackupsCalls, greaterThanOrEqualTo(2));
    });

    testWidgets('5. Historial de copias en 2 filas: fecha completa en fila propia sin truncar contra botón Restaurar', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockService = InstrumentalMockGoogleDriveService();
      mockService.mockUser = const GoogleDriveUser(
        id: 'u_item',
        email: 'minimarket.donpepe@gmail.com',
        displayName: 'Don Pepe',
      );
      final localDate = DateTime(2026, 11, 20, 17, 14);
      final testBackup = GoogleDriveBackupMetadata(
        fileId: 'b_row_test',
        fileName: 'MochilaLista_20261120.mlbg',
        createdAt: localDate.toUtc(),
        sizeBytes: 70656, // 69.0 KB
      );
      mockService.mockBackupsList.add(testBackup);

      final driveProv = GoogleDriveBackupProvider(
        service: mockService,
        cacheTtl: Duration.zero,
      );
      await driveProv.initializeFromCache();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<GoogleDriveBackupProvider?>.value(
              value: driveProv,
              child: const GoogleDriveBackupSheet(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Fecha completa sin truncamiento (100% legible)
      expect(find.text("20/11/2026 • 05:14 PM"), findsOneWidget);

      // Fila 2: Tamaño, badge Más reciente y botón Restaurar con icono
      expect(find.text("69.0 KB"), findsOneWidget);
      expect(find.text("Más reciente"), findsOneWidget);
      expect(find.text("Restaurar"), findsOneWidget);
      expect(find.byIcon(Icons.restore_rounded), findsOneWidget);

      // Cero excepciones de RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. Modal guiado WhatsApp: fecha completa en fila propia sin truncar contra badge Más reciente', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockService = InstrumentalMockGoogleDriveService();
      final localDate = DateTime(2026, 11, 20, 17, 14);
      final testBackup = GoogleDriveBackupMetadata(
        fileId: 'b_modal_test',
        fileName: 'MochilaLista_20261120.mlbg',
        createdAt: localDate.toUtc(),
        sizeBytes: 70656, // 69.0 KB
      );
      final driveProv = GoogleDriveBackupProvider(service: mockService);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    GoogleDriveBackupSheet.showGuidedWhatsAppRestoreModal(
                      context,
                      driveProvider: driveProv,
                      allBackups: [testBackup],
                      userEmail: 'vjulioangello@gmail.com',
                    );
                  },
                  child: const Text("Abrir Modal"),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Abrir modal
      await tester.tap(find.text("Abrir Modal"));
      await tester.pumpAndSettle();

      // Verificar que la fecha se muestra completa y los detalles coexisten sin desbordamiento
      expect(find.text("20/11/2026 • 05:14 PM"), findsOneWidget);
      expect(find.text("Más reciente"), findsOneWidget);
      expect(find.text("69.0 KB"), findsOneWidget);
      expect(find.text("Respaldo integral multi-perfil"), findsOneWidget);

      // Cero excepciones de RenderFlex overflow
      expect(tester.takeException(), isNull);
    });
  });

  group('Fase 6: Semáforo Visual de Salud de Respaldo (Sin Huecos y Cero Emojis)', () {
    test('1. computeHealthInfo: Estado none cuando la lista de copias está vacía', () {
      final health = GoogleDriveBackupProvider.computeHealthInfo(
        backups: [],
      );

      expect(health.status, equals(BackupHealthStatus.none));
      expect(health.label, equals("Sin copias en la nube"));
      expect(health.icon, equals(Icons.cloud_off_outlined));
    });

    test('2. computeHealthInfo: Estado optimal (verde) cuando la copia más reciente tiene <= 24 horas', () {
      final fixedNow = DateTime(2026, 11, 20, 18, 0);
      final backupRecent = GoogleDriveBackupMetadata(
        fileId: 'b_opt_1',
        fileName: 'MochilaLista_20261120.mlbg',
        createdAt: DateTime(2026, 11, 20, 10, 0), // Hace 8 horas
        sizeBytes: 50000,
      );
      final backupOlder = GoogleDriveBackupMetadata(
        fileId: 'b_opt_2',
        fileName: 'MochilaLista_20261118.mlbg',
        createdAt: DateTime(2026, 11, 18, 10, 0), // Hace 2 días
        sizeBytes: 50000,
      );

      final health = GoogleDriveBackupProvider.computeHealthInfo(
        backups: [backupOlder, backupRecent],
        referenceNow: fixedNow,
      );

      expect(health.status, equals(BackupHealthStatus.optimal));
      expect(health.label, equals("Al día • 2/5 copias"));
      expect(health.icon, equals(Icons.verified_user_rounded));
    });

    test('3. computeHealthInfo: Estado attention (ámbar) cuando la copia más reciente tiene > 24 horas', () {
      final fixedNow = DateTime(2026, 11, 20, 18, 0);
      final backupOld = GoogleDriveBackupMetadata(
        fileId: 'b_att_1',
        fileName: 'MochilaLista_20261117.mlbg',
        createdAt: DateTime(2026, 11, 17, 18, 0), // Hace 3 días exactos
        sizeBytes: 50000,
      );

      final health = GoogleDriveBackupProvider.computeHealthInfo(
        backups: [backupOld],
        referenceNow: fixedNow,
      );

      expect(health.status, equals(BackupHealthStatus.attention));
      expect(health.label, equals("Hace 3 días • Respalda pronto"));
      expect(health.icon, equals(Icons.schedule_rounded));
    });

    testWidgets('4. Semáforo visual en GoogleDriveBackupSheet renderiza badge con 0px overflow en 320x568dp', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockService = InstrumentalMockGoogleDriveService();
      mockService.mockUser = const GoogleDriveUser(
        id: 'g_user_health_test',
        email: 'vjulioangello@gmail.com',
        displayName: 'Julio Angello',
      );
      mockService.mockBackupsList.add(GoogleDriveBackupMetadata(
        fileId: 'b_h_1',
        fileName: 'MochilaLista_Recent.mlbg',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        sizeBytes: 65000,
      ));

      final driveProv = GoogleDriveBackupProvider(service: mockService);
      await driveProv.initializeFromCache();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<GoogleDriveBackupProvider>.value(
              value: driveProv,
              child: const GoogleDriveBackupSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el badge de salud "Al día • 1/5 copias"
      expect(find.text("Al día • 1/5 copias"), findsOneWidget);
      expect(find.byIcon(Icons.verified_user_rounded), findsOneWidget);

      // Cero excepciones de RenderFlex overflow
      expect(tester.takeException(), isNull);
    });
  });
}
