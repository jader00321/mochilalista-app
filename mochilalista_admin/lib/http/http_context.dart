import 'dart:convert';
import 'dart:io';

import '../apk_inspector_service.dart';
import '../client_sync_service.dart';
import '../commercial_config_sync_service.dart';
import '../config_service.dart';
import '../database_service.dart';
import '../excel_export_service.dart';
import '../license_signer.dart';
import '../vault_storage_service.dart';

/// Contexto compartido por los sub-routers HTTP del panel administrativo.
class AdminHttpContext {
  final HttpRequest request;
  final String path;
  final String method;
  final DatabaseService dbService;
  final LicenseSigner signer;
  final ConfigService configService;
  final ExcelExportService excelService;
  final VaultStorageService vaultStorage;
  final ApkInspectorService inspector;
  final ClientSyncService syncService;
  final CommercialConfigSyncService? commercialSyncService;
  final void Function(int code)? onExitOverride;
  final Future<void> Function(String url)? onOpenBrowserOverride;
  final Future<bool> Function(String filePath)? onCopyFileOverride;
  final Future<String?> Function()? onBrowseFolderOverride;

  AdminHttpContext({
    required this.request,
    required this.path,
    required this.method,
    required this.dbService,
    required this.signer,
    required this.configService,
    required this.excelService,
    required this.vaultStorage,
    required this.inspector,
    required this.syncService,
    this.commercialSyncService,
    this.onExitOverride,
    this.onOpenBrowserOverride,
    this.onCopyFileOverride,
    this.onBrowseFolderOverride,
  });

  Future<String> readBody() async {
    final bytes = await request.fold<List<int>>(
      [],
      (prev, chunk) => prev..addAll(chunk),
    );
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<void> sendJson(
    dynamic payload, {
    int statusCode = HttpStatus.ok,
  }) async {
    request.response.statusCode = statusCode;
    request.response.write(jsonEncode(payload));
    await request.response.close();
  }
}
