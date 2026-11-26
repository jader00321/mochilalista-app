import 'dart:io';

import '../core/path_security.dart';

/// Ensamblador determinista en memoria de `web/index.html` y marcadores
/// `<!-- @PARTIAL:ruta_relativa -->` con validación estricta de contención dentro de `web/`.
class HtmlTemplateAssembler {
  HtmlTemplateAssembler._();

  static final RegExp _partialRegex =
      RegExp(r'<!--\s*@PARTIAL:([^\s>]+?)\s*-->');

  /// Lee `index.html` dentro de [webRoot] y expande marcadores `@PARTIAL` de forma recursiva.
  /// Retorna `null` si `index.html` no existe en [webRoot].
  static Future<String?> assemble(String webRoot) async {
    final rootCanon = PathSecurity.canonicalizePath(webRoot);
    final indexFile = File('$rootCanon${Platform.pathSeparator}index.html');
    if (!await indexFile.exists()) return null;

    final rawIndex = await indexFile.readAsString();
    return _expandContent(
      rawIndex,
      webRootCanon: rootCanon,
      visited: {PathSecurity.cacheKeyForPath(PathSecurity.canonicalizePath(indexFile.path))},
      depth: 0,
    );
  }

  static Future<String> _expandContent(
    String template, {
    required String webRootCanon,
    required Set<String> visited,
    required int depth,
  }) async {
    if (depth > 8) {
      throw const FormatException(
        'Profundidad máxima de inclusión @PARTIAL excedida.',
      );
    }

    final matches = _partialRegex.allMatches(template).toList();
    if (matches.isEmpty) return template;

    final buffer = StringBuffer();
    int cursor = 0;

    for (final match in matches) {
      buffer.write(template.substring(cursor, match.start));
      cursor = match.end;

      final rawRel = (match.group(1) ?? '').trim();
      final resolvedPath = _resolveSafePartialPath(webRootCanon, rawRel);
      final canonKey = PathSecurity.cacheKeyForPath(resolvedPath);
      if (visited.contains(canonKey)) {
        throw FormatException('Inclusión @PARTIAL circular detectada: $rawRel');
      }

      final partialFile = File(resolvedPath);
      if (!await partialFile.exists()) {
        throw FileSystemException(
          'Archivo @PARTIAL no encontrado',
          resolvedPath,
        );
      }

      final partialContent = await partialFile.readAsString();
      final nextVisited = <String>{...visited, canonKey};
      final expanded = await _expandContent(
        partialContent,
        webRootCanon: webRootCanon,
        visited: nextVisited,
        depth: depth + 1,
      );
      buffer.write(expanded);
    }

    buffer.write(template.substring(cursor));
    return buffer.toString();
  }

  static String _resolveSafePartialPath(String webRootCanon, String rawRel) {
    if (rawRel.isEmpty ||
        rawRel.contains(r'\') ||
        rawRel.contains('\x00') ||
        rawRel.startsWith('/') ||
        RegExp(r'^[A-Za-z]:').hasMatch(rawRel)) {
      throw FormatException('Ruta @PARTIAL inválida o insegura: $rawRel');
    }

    final cleanRel = rawRel.replaceAll('/', Platform.pathSeparator);
    final segments = cleanRel.split(Platform.pathSeparator);
    if (segments.any((s) => s == '..')) {
      throw FormatException(
        'Bloqueado path traversal en marcador @PARTIAL: $rawRel',
      );
    }

    final rawTarget = '$webRootCanon${Platform.pathSeparator}$cleanRel';
    final canonTarget = PathSecurity.canonicalizePath(rawTarget);
    if (!PathSecurity.isPathWithinDirectory(webRootCanon, canonTarget)) {
      throw FormatException(
        'Bloqueado escape fuera del directorio web en @PARTIAL: $rawRel',
      );
    }
    return canonTarget;
  }
}
