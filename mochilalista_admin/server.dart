import 'dart:io';

import 'lib/apk_inspector_service.dart';
import 'lib/client_sync_service.dart';
import 'lib/commercial_config_sync_service.dart';
import 'lib/config_service.dart';
import 'lib/core/semver_utils.dart';
import 'lib/database_service.dart';
import 'lib/excel_export_service.dart';
import 'lib/http/api_router.dart';
import 'lib/license_signer.dart';
import 'lib/vault_storage_service.dart';

export 'lib/http/windows_shell_helpers.dart'
    show buildWindowsFolderPickerPsArgs, buildWindowsClipboardPsArgs;

Future<String> applyStartupModeFromConfig(
  DatabaseService dbService,
  ConfigService configService,
) async {
  final rawMode = (configService.system['default_mode'] as String? ?? 'sandbox')
      .trim()
      .toLowerCase();
  final targetMode = rawMode == 'prod' ? 'prod' : 'sandbox';
  dbService.setMode(targetMode);
  return targetMode;
}

/// Comparador SemVer numérico delegando a la única fuente de verdad (`SemVerUtils`).
int compareSemVer(String v1, String v2) => SemVerUtils.compare(v1, v2);

Future<void> main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final dbService = DatabaseService();
  await dbService.init();

  final configService = ConfigService();
  await configService.init();
  print(
      '⚙️ [ConfigService] Configuración de propietario cargada: data/owner_config.json');

  final startupMode = await applyStartupModeFromConfig(dbService, configService);
  print(
      '⚙️ [DatabaseService] Entorno inicial aplicado desde configuración: $startupMode');

  final excelService = ExcelExportService(
    dbService: dbService,
    configService: configService,
  );

  final signer = LicenseSigner();
  try {
    await signer.loadMasterKey();
    print('🔑 [LicenseSigner] Clave maestra Ed25519 cargada exitosamente.');
  } catch (e) {
    print('⚠️ [LicenseSigner] $e');
  }

  // Inicializar Servicio de Bóveda y Persistencia Fuera del Repositorio
  final vaultStorage = VaultStorageService(
    dbService: dbService,
    configService: configService,
    signer: signer,
  );
  await vaultStorage.initialize();
  final health = await vaultStorage.checkStorageHealth();
  if (health['recovery_available'] == true) {
    print(
        '⚠️ [VaultStorage] ATENCIÓN: Modo Asistencia de Recuperación Activo.');
    print(
        '⚠️ [VaultStorage] Espejo disponible en ${health['mirror']['mirror_dir']} para restaurar datos locales.');
  } else {
    print(
        '🛡️ [VaultStorage] Bóveda Cifrada Activa. Espejo en: ${health['mirror']['mirror_dir']}');
  }

  // Singleton ApkInspectorService con caché persistente en disco (data/.apk_inspection_cache.json)
  final apkInspector = ApkInspectorService(
    cacheFilePath: 'data/.apk_inspection_cache.json',
  );
  await apkInspector.loadDiskCache();
  print(
      '📦 [ApkInspector] Caché APK cargada desde disco (${apkInspector.liveCacheCount} entradas).');

  final commercialSyncService = CommercialConfigSyncService();

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('================================================================');
  print('🚀 MOCHILALISTA ADMIN — Servidor Local de Licencias y Versiones');
  print('👤 Autor y Titular: Julio Angello Vasquez Navarro');
  print('🌐 Acceso Local: http://localhost:$port');
  print('📁 Entorno Activo: ${dbService.currentMode.toUpperCase()}');
  print('📁 Base de Datos: ${Directory('data').absolute.path}');
  print('================================================================');

  await for (HttpRequest request in server) {
    handleRequest(
      request,
      dbService,
      signer,
      configService,
      excelService,
      vaultStorage,
      apkInspectorService: apkInspector,
      commercialSyncService: commercialSyncService,
    );
  }
}

Future<void> handleRequest(
  HttpRequest request,
  DatabaseService dbService,
  LicenseSigner signer,
  ConfigService configService,
  ExcelExportService excelService,
  VaultStorageService vaultStorage, {
  void Function(int code)? onExitOverride,
  Future<void> Function(String url)? onOpenBrowserOverride,
  ApkInspectorService? apkInspectorService,
  Future<bool> Function(String filePath)? onCopyFileOverride,
  Future<String?> Function()? onBrowseFolderOverride,
  ClientSyncService? clientSyncService,
  CommercialConfigSyncService? commercialSyncService,
}) =>
    ApiRouter.handleRequest(
      request,
      dbService,
      signer,
      configService,
      excelService,
      vaultStorage,
      onExitOverride: onExitOverride,
      onOpenBrowserOverride: onOpenBrowserOverride,
      apkInspectorService: apkInspectorService,
      onCopyFileOverride: onCopyFileOverride,
      onBrowseFolderOverride: onBrowseFolderOverride,
      clientSyncService: clientSyncService,
      commercialSyncService: commercialSyncService,
    );
