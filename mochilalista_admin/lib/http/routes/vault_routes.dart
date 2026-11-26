import 'dart:convert';
import 'dart:io';

import '../../vault_crypto_service.dart';
import '../../vault_storage_service.dart';
import '../auth_pin_middleware.dart';
import '../http_context.dart';
import '../windows_shell_helpers.dart';

/// Sub-router para Bóveda Cifrada, Kit de Emergencia, Espejo, Nube Local y Sesión PIN (`/api/vault/*`).
class VaultRoutes {
  VaultRoutes._();

  static Future<bool> handle(AdminHttpContext ctx) async {
    final path = ctx.path;
    final method = ctx.method;
    if (!path.startsWith('/api/vault/')) return false;

    final vaultStorage = ctx.vaultStorage;

    if (path == '/api/vault/health' && method == 'GET') {
      final health = await vaultStorage.checkStorageHealth();
      await ctx.sendJson(health);
      return true;
    }

    if (path == '/api/vault/audit' && method == 'GET') {
      final audit = await vaultStorage.runFullIntegrityAudit();
      await ctx.sendJson(audit);
      return true;
    }

    if (path == '/api/vault/sync-mirror' && method == 'POST') {
      await vaultStorage.syncMirror();
      await ctx.sendJson({
        'ok': true,
        'message': 'Espejo cifrado sincronizado exitosamente.',
      });
      return true;
    }

    if (path == '/api/vault/cloud-path/browse' && method == 'POST') {
      await _handleCloudPathBrowse(ctx);
      return true;
    }

    if (path == '/api/vault/set-cloud-path' && method == 'POST') {
      final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
      final cloudPath = body['cloud_path'] as String?;
      await vaultStorage.setCloudSyncPath(cloudPath);
      await ctx.sendJson({
        'ok': true,
        'cloud_path': cloudPath,
        'message': cloudPath != null && cloudPath.trim().isNotEmpty
            ? 'Ruta de sincronización de nube local configurada exitosamente.'
            : 'Sincronización de nube local desactivada.',
      });
      return true;
    }

    if (path == '/api/vault/recover-from-mirror' && method == 'POST') {
      VaultUnlockCredential? cred;
      final bodyStr = await ctx.readBody();
      if (bodyStr.trim().isNotEmpty) {
        try {
          final body = jsonDecode(bodyStr) as Map<String, dynamic>;
          cred = _parseOptionalCredential(
            body['credential_type'] as String?,
            body['secret'] as String?,
          );
        } catch (_) {}
      }
      final importResult =
          await vaultStorage.recoverFromMirror(credential: cred);
      await ctx.sendJson({
        'ok': true,
        'message': 'Bóveda recuperada exitosamente desde el espejo local.',
        'manifest': importResult.internalManifest,
      });
      return true;
    }

    if (path == '/api/vault/export' && method == 'POST') {
      bool includeMasterKey = true;
      final bodyStr = await ctx.readBody();
      if (bodyStr.trim().isNotEmpty) {
        try {
          final body = jsonDecode(bodyStr) as Map<String, dynamic>;
          if (body.containsKey('include_master_key')) {
            includeMasterKey = body['include_master_key'] == true;
          }
        } catch (_) {}
      }
      final vaultJson = await vaultStorage.exportPortableVault(
        includeMasterKey: includeMasterKey,
      );
      final timestamp =
          DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final filename = 'mochilalista_vault_$timestamp.mlvault';
      ctx.request.response.headers
          .add('Content-Disposition', 'attachment; filename="$filename"');
      await ctx.sendJson({
        'ok': true,
        'filename': filename,
        'vault_json': vaultJson,
      });
      return true;
    }

    if (path == '/api/vault/inspect' && method == 'POST') {
      final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
      final vaultJson = body['vault_json'] as String? ?? '';
      final metadata = vaultStorage.inspectVault(vaultJson);
      await ctx.sendJson({
        'ok': true,
        'metadata': metadata,
      });
      return true;
    }

    if (path == '/api/vault/import' && method == 'POST') {
      final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
      final vaultJson = body['vault_json'] as String? ?? '';
      final typeStr = body['credential_type'] as String? ?? 'dpapi';
      final secret = body['secret'] as String?;
      final rewrap = body['rewrap_dpapi'] as bool? ?? true;

      final cred = _parseRequiredCredential(typeStr, secret, defaultType: 'dpapi');
      final importResult = await vaultStorage.importPortableVault(
        vaultJson: vaultJson,
        credential: cred,
        rewrapForCurrentDpapi: rewrap,
      );
      await ctx.sendJson({
        'ok': true,
        'message':
            'Bóveda importada exitosamente y servicios recargados en caliente.',
        'manifest': importResult.internalManifest,
      });
      return true;
    }

    if (path == '/api/vault/generate-rescue-kit' && method == 'POST') {
      final kit = await vaultStorage.generateRescueKit();
      await ctx.sendJson({
        'ok': true,
        'codes': kit.codes,
        'qr_key': kit.qrKey,
      });
      return true;
    }

    if (path == '/api/vault/download-mlkey' && method == 'GET') {
      final mlKeyJson = await vaultStorage.downloadMlKey();
      const filename = 'llave_maestra_mochilalista.mlkey';
      ctx.request.response.headers
          .add('Content-Disposition', 'attachment; filename="$filename"');
      await ctx.sendJson({
        'ok': true,
        'filename': filename,
        'mlkey_json': mlKeyJson,
      });
      return true;
    }

    if (path == '/api/vault/pin/status' && method == 'GET') {
      final token = AuthPinMiddleware.extractVaultSessionToken(ctx.request);
      final pinEnabled = vaultStorage.isPinEnabled();
      final locked = pinEnabled && !vaultStorage.isSessionValid(token);
      await ctx.sendJson({
        'pin_enabled': pinEnabled,
        'locked': locked,
      });
      return true;
    }

    if (path == '/api/vault/pin/lock' && method == 'POST') {
      final token = AuthPinMiddleware.extractVaultSessionToken(ctx.request);
      vaultStorage.revokeSession(token);
      AuthPinMiddleware.clearVaultSessionCookie(ctx.request.response);
      await ctx.sendJson({
        'ok': true,
        'locked': true,
        'message': 'Consola bloqueada manualmente.',
      });
      return true;
    }

    if (path == '/api/vault/pin/configure' && method == 'POST') {
      final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
      final enabled = body['enabled'] as bool? ?? false;
      final pin = body['pin'] as String?;
      final cfgRes = await vaultStorage.configurePin(pin: pin, enabled: enabled);
      final newToken = cfgRes['session_token'] as String?;
      if (enabled && newToken != null && newToken.isNotEmpty) {
        AuthPinMiddleware.setVaultSessionCookie(ctx.request.response, newToken);
      } else if (!enabled) {
        AuthPinMiddleware.clearVaultSessionCookie(ctx.request.response);
      }
      await ctx.sendJson(cfgRes);
      return true;
    }

    if (path == '/api/vault/pin/verify' && method == 'POST') {
      final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
      final pin = body['pin'] as String? ?? '';
      final res = await vaultStorage.verifyPin(pin);
      final token = res['session_token'] as String?;
      if (token != null && token.isNotEmpty) {
        AuthPinMiddleware.setVaultSessionCookie(ctx.request.response, token);
      }
      await ctx.sendJson(res);
      return true;
    }

    if (path == '/api/vault/pin/recover' && method == 'POST') {
      final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
      final typeStr = body['credential_type'] as String? ?? 'mlkey';
      final secret = body['secret'] as String?;
      final newPin = body['new_pin'] as String?;
      final disablePin = body['disable_pin'] as bool? ?? false;

      final cred =
          _parseRequiredCredential(typeStr, secret, defaultType: 'mlkey');
      final res = await vaultStorage.recoverPin(
        credential: cred,
        newPin: newPin,
        disablePin: disablePin,
      );
      final token = res['session_token'] as String?;
      if (disablePin) {
        AuthPinMiddleware.clearVaultSessionCookie(ctx.request.response);
      } else if (token != null && token.isNotEmpty) {
        AuthPinMiddleware.setVaultSessionCookie(ctx.request.response, token);
      }
      await ctx.sendJson(res);
      return true;
    }

    return false;
  }

  static Future<void> _handleCloudPathBrowse(AdminHttpContext ctx) async {
    String? initialPath;
    try {
      final bodyStr = await ctx.readBody();
      if (bodyStr.trim().isNotEmpty) {
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;
        initialPath = body['initial_path'] as String?;
      }
    } catch (_) {}

    final pickRes = await WindowsShellHelpers.pickFolder(
      initialPath: initialPath,
      description:
          'Selecciona una carpeta de nube local (Dropbox, Google Drive u OneDrive) para replicar tu bóveda cifrada',
      onBrowseFolderOverride: ctx.onBrowseFolderOverride,
    );

    if (!pickRes.supported) {
      await ctx.sendJson(
        {
          'ok': false,
          'supported': false,
          'error':
              'El selector nativo de carpetas requiere Windows. Ingresa la ruta manualmente.',
        },
        statusCode: HttpStatus.notImplemented,
      );
      return;
    }

    if (pickRes.failed) {
      await ctx.sendJson(
        {
          'ok': false,
          'supported': true,
          'error': pickRes.error ??
              'No se pudo abrir el selector de carpetas de Windows.',
        },
        statusCode: HttpStatus.internalServerError,
      );
      return;
    }

    final pickedPath = pickRes.path;
    if (pickedPath == null || pickedPath.trim().isEmpty) {
      await ctx.sendJson({
        'ok': true,
        'cancelled': true,
        'path': null,
      });
      return;
    }

    final cleanPicked = pickedPath.trim();
    final validationError = VaultStorageService.validateCloudSyncDirectoryPath(
      cleanPicked,
      projectRootDir: ctx.vaultStorage.projectRootDir,
      mirrorDir: ctx.vaultStorage.mirrorDir,
    );
    if (validationError != null) {
      await ctx.sendJson(
        {'ok': false, 'error': validationError},
        statusCode: HttpStatus.badRequest,
      );
      return;
    }

    await ctx.sendJson({
      'ok': true,
      'cancelled': false,
      'path': cleanPicked,
    });
  }

  static VaultUnlockCredential? _parseOptionalCredential(
    String? typeStr,
    String? secret,
  ) {
    if (typeStr == null) return null;
    switch (typeStr) {
      case 'dpapi':
        return VaultUnlockCredential.dpapi();
      case 'mlkey':
        return secret != null ? VaultUnlockCredential.mlKey(secret) : null;
      case 'rescue_code':
        return secret != null ? VaultUnlockCredential.rescueCode(secret) : null;
      case 'qr_key':
        return secret != null ? VaultUnlockCredential.qrKey(secret) : null;
      case 'pin':
        return secret != null ? VaultUnlockCredential.pin(secret) : null;
      default:
        return null;
    }
  }

  static VaultUnlockCredential _parseRequiredCredential(
    String typeStr,
    String? secret, {
    required String defaultType,
  }) {
    switch (typeStr) {
      case 'dpapi':
        if (defaultType == 'mlkey') {
          return VaultUnlockCredential.dpapi();
        }
        return VaultUnlockCredential.dpapi();
      case 'rescue_code':
        if (secret == null) {
          throw VaultAuthException('Se requiere el Código de Rescate.');
        }
        return VaultUnlockCredential.rescueCode(secret);
      case 'qr_key':
        if (secret == null) {
          throw VaultAuthException('Se requiere la clave QR.');
        }
        return VaultUnlockCredential.qrKey(secret);
      case 'pin':
        if (defaultType == 'dpapi') {
          if (secret == null) throw VaultAuthException('Se requiere el PIN.');
          return VaultUnlockCredential.pin(secret);
        }
        if (secret == null) {
          throw VaultAuthException('Se requiere el archivo .mlkey.');
        }
        return VaultUnlockCredential.mlKey(secret);
      case 'mlkey':
        if (secret == null) {
          throw VaultAuthException('Se requiere el archivo .mlkey.');
        }
        return VaultUnlockCredential.mlKey(secret);
      default:
        if (defaultType == 'dpapi') {
          return VaultUnlockCredential.dpapi();
        }
        if (secret == null) {
          throw VaultAuthException('Se requiere el archivo .mlkey.');
        }
        return VaultUnlockCredential.mlKey(secret);
    }
  }
}
