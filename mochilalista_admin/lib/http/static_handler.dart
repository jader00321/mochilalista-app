import 'dart:io';

import '../core/path_security.dart';
import 'html_assembler.dart';

/// Servidor estático seguro para `web/` con contención estricta anti path-traversal (`D-ADM-09`),
/// comprobación asíncrona de archivos (`D-ADM-10`) y ensamblado de parciales HTML.
class StaticHandler {
  StaticHandler._();

  static Future<void> handle(
    HttpRequest request,
    String path, {
    String webRoot = 'web',
  }) async {
    if (_containsUnsafePathPattern(request, path)) {
      await _sendForbidden(request);
      return;
    }

    final webRootCanon = PathSecurity.canonicalizePath(webRoot);
    final normalizedPath = path.isEmpty ? '/' : path;

    if (normalizedPath == '/' || normalizedPath == '/index.html') {
      await _serveAssembledIndex(request, webRootCanon);
      return;
    }

    final relSegments = normalizedPath
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    if (relSegments.any((s) => s == '..' || s.contains(r'\')) ||
        (relSegments.isNotEmpty && relSegments.first.toLowerCase() == 'partials')) {
      await _sendForbidden(request);
      return;
    }

    final rawFilePath = relSegments.isEmpty
        ? '$webRootCanon${Platform.pathSeparator}index.html'
        : '$webRootCanon${Platform.pathSeparator}${relSegments.join(Platform.pathSeparator)}';
    final resolvedPath = PathSecurity.canonicalizePath(rawFilePath);

    if (!PathSecurity.isPathWithinDirectory(webRootCanon, resolvedPath)) {
      await _sendForbidden(request);
      return;
    }

    final file = File(resolvedPath);
    if (await file.exists()) {
      final ext = resolvedPath.split('.').last.toLowerCase();
      request.response.headers.contentType = _contentTypeForExtension(ext);
      await file.openRead().pipe(request.response);
      return;
    }

    // No devolver SPA HTML si se solicitó un archivo específico con extensión inexistente
    final lastSegment = relSegments.isNotEmpty ? relSegments.last : '';
    if (lastSegment.contains('.')) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Recurso estático no encontrado');
      await request.response.close();
      return;
    }

    // Fallback SPA seguro hacia index.html ensamblado
    await _serveAssembledIndex(request, webRootCanon);
  }

  static Future<void> _serveAssembledIndex(
    HttpRequest request,
    String webRootCanon,
  ) async {
    final html = await HtmlTemplateAssembler.assemble(webRootCanon);
    if (html != null) {
      request.response.headers.contentType =
          ContentType('text', 'html', charset: 'utf-8');
      request.response.write(html);
      await request.response.close();
      return;
    }
    request.response.statusCode = HttpStatus.notFound;
    request.response.write('Página no encontrada');
    await request.response.close();
  }

  static bool _containsUnsafePathPattern(HttpRequest request, String path) {
    final rawUri = request.uri.toString();
    final candidates = <String>[rawUri, path];
    try {
      candidates.add(Uri.decodeFull(rawUri));
    } catch (_) {}
    try {
      candidates.add(Uri.decodeComponent(path));
    } catch (_) {
      return true;
    }

    for (final c in candidates) {
      if (c.contains('\x00') || c.contains(r'\')) return true;
      final pathOnly = c.split('?').first.split('#').first;
      final segs = pathOnly.split('/');
      if (segs.any((s) => s == '..')) return true;
    }
    return false;
  }

  static Future<void> _sendForbidden(HttpRequest request) async {
    request.response.statusCode = HttpStatus.forbidden;
    request.response.headers.contentType = ContentType.text;
    request.response.write('Forbidden');
    await request.response.close();
  }

  static ContentType _contentTypeForExtension(String ext) {
    switch (ext) {
      case 'html':
        return ContentType.html;
      case 'css':
        return ContentType('text', 'css', charset: 'utf-8');
      case 'js':
        return ContentType('application', 'javascript', charset: 'utf-8');
      case 'json':
        return ContentType.json;
      case 'png':
        return ContentType('image', 'png');
      case 'jpg':
      case 'jpeg':
        return ContentType('image', 'jpeg');
      case 'svg':
        return ContentType('image', 'svg+xml');
      case 'ico':
        return ContentType('image', 'x-icon');
      default:
        return ContentType.binary;
    }
  }
}
