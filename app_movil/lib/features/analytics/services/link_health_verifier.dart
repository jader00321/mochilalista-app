import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:app_movil/core/config/owner_legal_identity.dart';

/// Registro de verificación de enlace con TTL de 24 horas
class LinkHealthRecord {
  final bool isValid;
  final int statusCode;
  final DateTime verifiedAt;

  const LinkHealthRecord({
    required this.isValid,
    required this.statusCode,
    required this.verifiedAt,
  });

  bool get isExpired {
    return DateTime.now().difference(verifiedAt) > const Duration(hours: 24);
  }
}

/// Verificador de salud de enlaces HTTP/HTTPS
/// - Soporta cliente HTTP inyectable para pruebas unitarias sin tráfico real de red
/// - Timeout estricto de 3.0s
/// - Estrategia HEAD con fallback a GET ante 405 Method Not Allowed o 403 Forbidden
/// - Tolera redirecciones 301/302 de Google News
/// - Descarta 404, 410, 5xx y errores de resolución DNS (NXDOMAIN)
class LinkHealthVerifier {
  final http.Client? _client;
  static const Duration defaultTimeout = Duration(milliseconds: 3000);
  static const String userAgent = 'MochilaLista/${OwnerLegalIdentity.currentAppVersion} (Android; Mobile)';

  // Caché en memoria para evitar verificaciones duplicadas del mismo enlace
  static final Map<String, LinkHealthRecord> _cache = {};

  LinkHealthVerifier({http.Client? client}) : _client = client;

  /// Limpia la caché en memoria (útil en tests)
  static void clearCache() {
    _cache.clear();
  }

  /// Verifica si un enlace está activo y responde con código HTTP 200..399
  Future<bool> verifyLink(String rawUrl, {Duration timeout = defaultTimeout}) async {
    final cleanUrl = rawUrl.trim();
    if (cleanUrl.isEmpty) return false;

    final uri = Uri.tryParse(cleanUrl);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return false;
    }

    // Verificar caché
    final cached = _cache[cleanUrl];
    if (cached != null && !cached.isExpired) {
      return cached.isValid;
    }

    final client = _client ?? http.Client();
    final bool isOwnedClient = _client == null;

    try {
      final headers = {
        'User-Agent': userAgent,
        'Accept': '*/*',
      };

      // 1. Intento primario con HEAD para mínimo consumo de datos y latencia
      http.Response response;
      try {
        response = await client.head(uri, headers: headers).timeout(timeout);
      } catch (e) {
        // Si HEAD falla por timeout o error de red, intentamos un GET ligero si no fue error fatal de dominio
        response = await client.get(
          uri,
          headers: {...headers, 'Range': 'bytes=0-200'},
        ).timeout(timeout);
      }

      // Si el servidor no soporta HEAD (405 Method Not Allowed) o devuelve 403
      if (response.statusCode == 405 || response.statusCode == 403) {
        try {
          response = await client.get(
            uri,
            headers: {...headers, 'Range': 'bytes=0-200'},
          ).timeout(timeout);
        } catch (_) {}
      }

      // Códigos 200..399 son válidos (incluyendo redirecciones 301/302 de Google News y portales gubernamentales)
      final isValid = response.statusCode >= 200 && response.statusCode < 400;

      _cache[cleanUrl] = LinkHealthRecord(
        isValid: isValid,
        statusCode: response.statusCode,
        verifiedAt: DateTime.now(),
      );

      return isValid;
    } catch (_) {
      // SocketException, TimeoutException, NXDOMAIN, etc.
      _cache[cleanUrl] = LinkHealthRecord(
        isValid: false,
        statusCode: 0,
        verifiedAt: DateTime.now(),
      );
      return false;
    } finally {
      if (isOwnedClient) {
        client.close();
      }
    }
  }

  /// Retorna la URL candidata si es válida; de lo contrario, retorna la URL de respaldo provista
  Future<String> resolveWorkingUrl(
    String candidateUrl, {
    required String fallbackUrl,
  }) async {
    final isValid = await verifyLink(candidateUrl);
    if (isValid) return candidateUrl;
    return fallbackUrl;
  }
}
