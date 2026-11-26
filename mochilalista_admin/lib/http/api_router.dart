import 'dart:convert';
import 'dart:io';

import '../apk_inspector_service.dart';
import '../client_sync_service.dart';
import '../commercial_config_sync_service.dart';
import '../config_service.dart';
import '../database_service.dart';
import '../excel_export_service.dart';
import '../license_signer.dart';
import '../vault_crypto_service.dart';
import '../vault_storage_service.dart';
import 'auth_pin_middleware.dart';
import 'http_context.dart';
import 'routes/clients_routes.dart';
import 'routes/config_routes.dart';
import 'routes/finances_backups_routes.dart';
import 'routes/licenses_sync_routes.dart';
import 'routes/releases_files_routes.dart';
import 'routes/releases_routes.dart';
import 'routes/system_routes.dart';
import 'routes/vault_routes.dart';
import 'static_handler.dart';

/// Enrutador central HTTP protegido por [AuthPinMiddleware] y fallback estático seguro [StaticHandler].
class ApiRouter {
  ApiRouter._();

  static Future<void> handleRequest(
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
    String webRoot = 'web',
  }) async {
    final path = request.uri.path;
    final method = request.method;

    AuthPinMiddleware.applyCorsHeaders(request.response);

    if (method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final headerMode = request.headers.value('X-App-Mode');
    if (headerMode != null &&
        (headerMode == 'sandbox' || headerMode == 'prod')) {
      if (dbService.currentMode != headerMode) {
        dbService.setMode(headerMode);
      }
    }

    try {
      if (path.startsWith('/api/')) {
        await _dispatchApiRoute(
          AdminHttpContext(
            request: request,
            path: path,
            method: method,
            dbService: dbService,
            signer: signer,
            configService: configService,
            excelService: excelService,
            vaultStorage: vaultStorage,
            inspector: apkInspectorService ?? ApkInspectorService(),
            syncService: clientSyncService ?? ClientSyncService(),
            commercialSyncService: commercialSyncService,
            onExitOverride: onExitOverride,
            onOpenBrowserOverride: onOpenBrowserOverride,
            onCopyFileOverride: onCopyFileOverride,
            onBrowseFolderOverride: onBrowseFolderOverride,
          ),
        );
        return;
      }

      await StaticHandler.handle(request, path, webRoot: webRoot);
    } catch (e, stack) {
      print('Error procesando $method $path: $e\n$stack');
      try {
        if (e is VaultAuthException) {
          request.response.statusCode = HttpStatus.unauthorized;
        } else if (e is VaultIntegrityException || e is VaultFormatException) {
          request.response.statusCode = HttpStatus.badRequest;
        } else {
          request.response.statusCode = HttpStatus.internalServerError;
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'error': e.toString()}));
        await request.response.close();
      } catch (_) {}
    }
  }

  static Future<void> _dispatchApiRoute(AdminHttpContext ctx) async {
    ctx.request.response.headers.contentType = ContentType.json;

    // Guardián de seguridad obligatorio antes de invocar cualquier sub-router
    final allowed = await AuthPinMiddleware.enforcePinIfLocked(
      ctx.request,
      ctx.path,
      ctx.vaultStorage,
    );
    if (!allowed) return;

    final handlers = <Future<bool> Function(AdminHttpContext)>[
      VaultRoutes.handle,
      SystemRoutes.handle,
      ClientsRoutes.handle,
      LicensesSyncRoutes.handle,
      FinancesBackupsRoutes.handle,
      ReleasesFilesRoutes.handle,
      ReleasesRoutes.handle,
      ConfigRoutes.handle,
    ];

    for (final handler in handlers) {
      if (await handler(ctx)) return;
    }

    await ctx.sendJson(
      {'error': 'Ruta no encontrada: ${ctx.path}'},
      statusCode: HttpStatus.notFound,
    );
  }
}
