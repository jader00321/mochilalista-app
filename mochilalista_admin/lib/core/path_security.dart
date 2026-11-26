import 'dart:io';

/// Utilidades compartidas de canonicalización de rutas, contención y bloqueo
/// de directorios críticos del sistema operativo o sensibles del proyecto.
class PathSecurity {
  PathSecurity._();

  /// Clave de mapa insensible a mayúsculas en Windows y exacta en POSIX.
  static String cacheKeyForPath(String canonicalPath) =>
      Platform.isWindows ? canonicalPath.toLowerCase() : canonicalPath;

  /// Normaliza una ruta eliminando segmentos `..`, unificando separadores y resolviendo enlaces.
  static String canonicalizePath(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) return trimmed;
    try {
      final f = File(trimmed);
      if (f.existsSync()) {
        return f.resolveSymbolicLinksSync();
      }
      final d = Directory(trimmed);
      if (d.existsSync()) {
        return d.resolveSymbolicLinksSync();
      }
    } catch (_) {}

    final abs = File(trimmed).absolute.path;
    return normalizeLexicalPath(abs);
  }

  /// Normaliza léxicamente una ruta absoluta resolviendo `.` y `..`.
  static String normalizeLexicalPath(String rawAbs) {
    final sep = Platform.pathSeparator;
    String path = rawAbs.replaceAll('/', sep).replaceAll(r'\', sep);

    String prefix = '';
    if (Platform.isWindows) {
      if (path.startsWith(r'\\')) {
        prefix = r'\\';
        path = path.substring(2);
      } else if (path.length >= 2 && path[1] == ':') {
        prefix = '${path.substring(0, 2)}$sep';
        path = path.substring(2);
      }
    } else if (path.startsWith('/')) {
      prefix = '/';
      path = path.substring(1);
    }

    final resolved = <String>[];
    for (final seg in path.split(sep)) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') {
        if (resolved.isNotEmpty) resolved.removeLast();
      } else {
        resolved.add(seg);
      }
    }
    return '$prefix${resolved.join(sep)}';
  }

  static String _toComparableSlashPath(String canonicalPath) {
    var slash = canonicalPath.replaceAll(r'\', '/').trim();
    while (slash.length > 3 && slash.endsWith('/')) {
      slash = slash.substring(0, slash.length - 1);
    }
    if (!Platform.isWindows && slash.length > 1 && slash.endsWith('/')) {
      slash = slash.substring(0, slash.length - 1);
    }
    return Platform.isWindows ? slash.toLowerCase() : slash;
  }

  /// Verifica estrictamente que [targetPath] reside dentro de [rootDir] (o coincide con él).
  static bool isPathWithinDirectory(String rootDir, String targetPath) {
    if (rootDir.trim().isEmpty || targetPath.trim().isEmpty) return false;
    final rootCmp = _toComparableSlashPath(canonicalizePath(rootDir));
    final targetCmp = _toComparableSlashPath(canonicalizePath(targetPath));
    if (rootCmp.isEmpty || targetCmp.isEmpty) return false;
    if (targetCmp == rootCmp) return true;
    final prefix = rootCmp.endsWith('/') ? rootCmp : '$rootCmp/';
    return targetCmp.startsWith(prefix);
  }

  /// Detecta si [rawPath] representa una unidad raíz (`C:\`, `D:`, `/`, `\\server`).
  static bool isDriveOrRootPath(String rawPath) {
    final slashNorm = rawPath.replaceAll(r'\', '/').trim();
    if (slashNorm.isEmpty) return true;
    if (RegExp(r'^[A-Za-z]:/?$').hasMatch(slashNorm)) return true;
    if (slashNorm == '/' || RegExp(r'^//[^/]+/?$').hasMatch(slashNorm)) {
      return true;
    }
    return false;
  }

  /// Verifica si una ruta es insegura o prohibida para búsqueda de APKs.
  static bool isForbiddenApkSearchDir(
    String rawPath, {
    String dataDirPath = 'data',
    String backupsDirPath = 'backups',
  }) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) return true;
    if (isDriveOrRootPath(trimmed)) return true;

    final canon = canonicalizePath(trimmed);
    if (canon.isEmpty || isDriveOrRootPath(canon)) return true;

    final canonSlash = canon.replaceAll(r'\', '/').trim();
    final cmp = Platform.isWindows ? canonSlash.toLowerCase() : canonSlash;
    final segments = cmp.split('/').where((s) => s.isNotEmpty).toList();

    if (segments.contains('private_keys') || segments.contains('.git')) {
      return true;
    }

    final forbiddenProjectRoots = <String>[
      dataDirPath,
      backupsDirPath,
      'data',
      'backups',
      'private_keys',
      '../app_movil/android',
      'app_movil/android',
    ];
    for (final root in forbiddenProjectRoots) {
      if (isPathWithinDirectory(root, canon)) return true;
    }

    if (Platform.isWindows) {
      final sysRoot = (Platform.environment['SystemRoot'] ?? r'C:\Windows')
          .replaceAll(r'\', '/')
          .toLowerCase();
      if (cmp == sysRoot || cmp.startsWith('$sysRoot/')) return true;
      if (cmp == 'c:/windows' || cmp.startsWith('c:/windows/')) return true;
    } else {
      const posixSystemRoots = [
        '/etc',
        '/usr',
        '/bin',
        '/sbin',
        '/var',
        '/proc',
        '/sys',
        '/dev',
        '/system',
      ];
      for (final pRoot in posixSystemRoots) {
        if (cmp == pRoot || cmp.startsWith('$pRoot/')) return true;
      }
    }

    return false;
  }

  /// Valida que la carpeta de nube local seleccionada no sea raíz de disco,
  /// directorio del sistema operativo ni carpeta interna sensible del proyecto.
  static String? validateCloudSyncDirectoryPath(
    String? rawPath, {
    String? projectRootDir,
    String? mirrorDir,
  }) {
    final clean = rawPath?.trim() ?? '';
    if (clean.isEmpty) return null;

    String norm(String p) {
      var s = p.trim().replaceAll('/', r'\');
      while (s.length > 3 && s.endsWith(r'\')) {
        s = s.substring(0, s.length - 1);
      }
      return s.toLowerCase();
    }

    final normalized = norm(clean);
    if (RegExp(r'^[a-z]:\\?$').hasMatch(normalized) ||
        normalized == r'\' ||
        normalized == '/') {
      return 'No puedes usar la raíz de un disco como carpeta de Nube Local.';
    }

    final forbiddenSystemPrefixes = <String>[
      r'c:\windows',
      r'c:\program files',
      r'c:\program files (x86)',
      '/etc',
      '/usr',
      '/bin',
      '/sbin',
      '/system',
    ];
    for (final sysPath in forbiddenSystemPrefixes) {
      final sysNorm = sysPath.replaceAll('/', r'\').toLowerCase();
      if (normalized == sysNorm || normalized.startsWith('$sysNorm\\')) {
        return 'No se permite usar carpetas del sistema operativo como destino de sincronización.';
      }
    }

    final baseNorm = norm(Directory(projectRootDir ?? '.').absolute.path);
    final rawLower = clean.replaceAll(r'\', '/').toLowerCase();
    if (rawLower.contains('/private_keys') ||
        rawLower.endsWith('/mochilalista_admin/data') ||
        rawLower == 'data' ||
        rawLower == 'private_keys' ||
        rawLower == 'backups') {
      return 'No se permite apuntar la Nube Local hacia carpetas internas críticas del servidor (data, backups o private_keys).';
    }

    final forbiddenInternal = <String>[
      '$baseNorm\\data',
      '$baseNorm\\private_keys',
      '$baseNorm\\backups',
      '$baseNorm\\releases_apks',
    ];
    if (mirrorDir != null && mirrorDir.trim().isNotEmpty) {
      forbiddenInternal.add(norm(Directory(mirrorDir).absolute.path));
    }

    final absNorm = norm(Directory(clean).absolute.path);
    for (final blocked in forbiddenInternal) {
      if (absNorm == blocked || absNorm.startsWith('$blocked\\')) {
        return 'La ruta seleccionada apunta a una carpeta interna de resguardo del proyecto. Elige una carpeta externa (Dropbox, Google Drive u OneDrive).';
      }
    }

    return null;
  }
}
