import 'dart:io';

import '../../lib/http/html_assembler.dart';

/// Central loader for `mochilalista_admin/web` assets in automated tests.
///
/// Decouples tests from the internal file layout (single monolith vs. split
/// `partials/`, `css/`, `js/core/`, `js/features/` modules in Plan Maestro 25)
/// while preserving exact file resolution regardless of working directory.
class WebBundleLoader {
  WebBundleLoader._();

  static String _join(String base, List<String> parts) {
    final cleanParts = parts
        .expand((part) => part.split(RegExp(r'[/\\]+')))
        .where((part) => part.isNotEmpty)
        .toList();
    var current = base;
    if (current.endsWith('/') || current.endsWith(r'\')) {
      current = current.substring(0, current.length - 1);
    }
    for (final part in cleanParts) {
      current = '$current${Platform.pathSeparator}$part';
    }
    return current;
  }

  /// Resolves the `mochilalista_admin/` root directory whether tests run from
  /// `mochilalista_admin/` or the repository root.
  static Directory resolveAdminRoot() {
    var cursor = Directory.current.absolute;
    for (var i = 0; i < 6; i++) {
      final indexFile = File(_join(cursor.path, ['web', 'index.html']));
      final pubspecFile = File(_join(cursor.path, ['pubspec.yaml']));
      if (indexFile.existsSync() && pubspecFile.existsSync()) {
        return cursor;
      }
      final nestedAdmin = Directory(_join(cursor.path, ['mochilalista_admin']));
      if (nestedAdmin.existsSync() &&
          File(_join(nestedAdmin.path, ['web', 'index.html'])).existsSync() &&
          File(_join(nestedAdmin.path, ['pubspec.yaml'])).existsSync()) {
        return nestedAdmin;
      }
      final parent = cursor.parent;
      if (parent.path == cursor.path) break;
      cursor = parent;
    }
    throw StateError(
      'No se pudo resolver mochilalista_admin/ desde ${Directory.current.path}',
    );
  }

  /// Resolves the repository root directory containing `mochilalista_admin/`
  /// and `scripts/`.
  static Directory resolveRepoRoot() {
    final adminRoot = resolveAdminRoot();
    final parent = adminRoot.parent;
    if (Directory(_join(parent.path, ['scripts'])).existsSync() ||
        File(_join(parent.path, ['.gitignore'])).existsSync()) {
      return parent;
    }
    throw StateError(
      'No se pudo resolver la raiz del repositorio desde ${adminRoot.path}',
    );
  }

  /// Resolves a file inside the repository root by relative path.
  static File resolveRepoFile(String relativePath) {
    return File(_join(resolveRepoRoot().path, [relativePath]));
  }

  /// Resolves the `mochilalista_admin/web/` directory.
  static Directory resolveWebRoot() {
    return Directory(_join(resolveAdminRoot().path, ['web']));
  }

  /// Resolves a file inside `mochilalista_admin/web/` by relative path
  /// (e.g. `'index.html'`, `'js/qrcode.min.js'`, `'favicon.ico'`).
  static File resolveWebAssetFile(String relativePath) {
    var normalized = relativePath.trim();
    if (normalized.startsWith('web/') || normalized.startsWith(r'web\')) {
      normalized = normalized.substring(4);
    }
    return File(_join(resolveWebRoot().path, [normalized]));
  }

  /// Absolute path to an asset inside `mochilalista_admin/web/`.
  static String resolveWebAssetPath(String relativePath) {
    return resolveWebAssetFile(relativePath).absolute.path;
  }

  /// Ordered CSS files loaded by the admin web console, matching the exact
  /// `<link rel="stylesheet">` cascade declared in `web/index.html`.
  static List<String> cssFilePaths() {
    final indexFile = resolveWebAssetFile('index.html');
    if (!indexFile.existsSync()) {
      throw StateError('No existe ${indexFile.path}');
    }
    final rawIndex = indexFile.readAsStringSync();
    final linkRegex = RegExp(
      r'''<link\b[^>]*rel=["\x27]stylesheet["\x27][^>]*href=["\x27](css/[^"?\x27]+)(?:\?[^"\x27]*)?["\x27]''',
      caseSensitive: false,
    );
    final paths = linkRegex
        .allMatches(rawIndex)
        .map((m) => resolveWebAssetPath(m.group(1)!))
        .toList();
    if (paths.isEmpty) {
      throw StateError('No se detectaron hojas CSS en ${indexFile.path}');
    }
    return paths;
  }

  /// Ordered application JS files loaded by the admin web console
  /// (excludes third-party vendor bundles such as `qrcode.min.js`/`jsqr.min.js`).
  static List<String> jsFilePaths() {
    final indexFile = resolveWebAssetFile('index.html');
    if (!indexFile.existsSync()) {
      throw StateError('No existe ${indexFile.path}');
    }
    final rawIndex = indexFile.readAsStringSync();
    final scriptRegex = RegExp(
      r'''<script\b[^>]*src=["\x27](js/[^"?\x27]+)(?:\?[^"\x27]*)?["\x27]''',
      caseSensitive: false,
    );
    const vendorScripts = {'js/qrcode.min.js', 'js/jsqr.min.js'};
    final paths = scriptRegex
        .allMatches(rawIndex)
        .map((m) => m.group(1)!)
        .where((rel) => !vendorScripts.contains(rel.toLowerCase()))
        .map(resolveWebAssetPath)
        .toList();
    if (paths.isEmpty) {
      throw StateError('No se detectaron scripts JS en ${indexFile.path}');
    }
    return paths;
  }

  /// Loads the assembled HTML of the admin web console via [HtmlTemplateAssembler].
  static String loadHtml() {
    final webRoot = resolveWebRoot();
    final assembled = HtmlTemplateAssembler.assembleSync(webRoot.path);
    if (assembled == null) {
      throw StateError('No existe ${webRoot.path}/index.html');
    }
    return assembled;
  }

  /// Loads the concatenated CSS of the admin web console in load order.
  static String loadCss() {
    return cssFilePaths().map((path) {
      final file = File(path);
      if (!file.existsSync()) {
        throw StateError('No existe CSS en $path');
      }
      return file.readAsStringSync();
    }).join('\n');
  }

  /// Loads the concatenated application JS of the admin web console in load order.
  static String loadJs() {
    return jsFilePaths().map((path) {
      final file = File(path);
      if (!file.existsSync()) {
        throw StateError('No existe JS en $path');
      }
      return file.readAsStringSync();
    }).join('\n');
  }

  /// Writes the concatenated application JS bundle to [dir]/[filename] for
  /// tests that evaluate the frontend script under Node.js.
  static File writeConcatenatedJsTo(
    Directory dir, {
    String filename = 'admin_bundle_test.js',
  }) {
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final outFile = File(_join(dir.path, [filename]));
    outFile.writeAsStringSync(loadJs());
    return outFile;
  }
}
