import 'dart:convert';
import 'dart:io';

import '../vault_storage_service.dart';

/// Middleware centralizado de seguridad HTTP: cabeceras CORS, gestión de cookies HttpOnly
/// `vault_session_token` y bloqueo estricto `HTTP 423 Locked` cuando la bóveda tiene PIN activo.
class AuthPinMiddleware {
  AuthPinMiddleware._();

  static const Set<String> exemptApiPaths = {
    '/api/vault/health',
    '/api/vault/pin/status',
    '/api/vault/pin/verify',
    '/api/vault/pin/recover',
    '/api/vault/pin/lock',
    '/api/system/open-browser',
  };

  static void applyCorsHeaders(HttpResponse response) {
    response.headers.add('Access-Control-Allow-Origin', '*');
    response.headers
        .add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    response.headers.add('Access-Control-Allow-Headers',
        'Content-Type, X-App-Mode, X-File-Name, X-Vault-Session-Token');
  }

  static String? extractVaultSessionToken(HttpRequest request) {
    final headerToken = request.headers.value('X-Vault-Session-Token')?.trim();
    if (headerToken != null && headerToken.isNotEmpty) {
      return headerToken;
    }
    final cookieToken = request.cookies
        .cast<Cookie?>()
        .firstWhere((c) => c?.name == 'vault_session_token', orElse: () => null)
        ?.value
        .trim();
    if (cookieToken != null && cookieToken.isNotEmpty) {
      return cookieToken;
    }
    return null;
  }

  static void setVaultSessionCookie(HttpResponse response, String token) {
    final cookie = Cookie('vault_session_token', token)
      ..path = '/'
      ..httpOnly = true
      ..sameSite = SameSite.lax;
    response.cookies.add(cookie);
  }

  static void clearVaultSessionCookie(HttpResponse response) {
    final cookie = Cookie('vault_session_token', '')
      ..path = '/'
      ..httpOnly = true
      ..sameSite = SameSite.lax
      ..maxAge = 0;
    response.cookies.add(cookie);
  }

  /// Verifica si la petición `/api/*` puede continuar o debe responder `423 Locked`.
  /// Retorna `true` si la sesión es válida, está exenta o no hay PIN habilitado.
  static Future<bool> enforcePinIfLocked(
    HttpRequest request,
    String path,
    VaultStorageService vaultStorage,
  ) async {
    if (!vaultStorage.isPinEnabled()) return true;
    if (exemptApiPaths.contains(path)) return true;

    final token = extractVaultSessionToken(request);
    if (vaultStorage.isSessionValid(token)) return true;

    request.response.statusCode = 423; // Locked
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'error': 'Session is locked. Enter PIN or recovery factor.',
      'locked': true,
    }));
    await request.response.close();
    return false;
  }
}
