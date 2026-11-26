import 'dart:io';

import 'time_utils.dart';

/// Helper centralizado DRY para creación atómica y rotación de snapshots en `backups/`.
///
/// Unifica la lógica de rotación compartida entre `ConfigService` y `DatabaseService`
/// evitando duplicación (`D-ADM-08`) y blindando archivos protegidos.
class BackupRotationHelper {
  BackupRotationHelper._();

  static const int defaultMaxAutoSnapshots = 30;

  /// Tokens protegidos en auditoría, listado y purgas manuales de respaldos.
  static const List<String> protectedTokens = [
    'manual',
    'vault',
    'pre_restore',
    'before_restore',
    'pre_import',
    'pre_save',
    'pre_reset',
  ];

  /// Tokens protegidos durante la rotación automática de snapshots (`maxAutoSnapshots`).
  /// Mantiene `pre_save` rotable para que `ConfigService.saveConfig()` conserve los últimos 30.
  static const List<String> autoRotationProtectedTokens = [
    'manual',
    'vault',
    'pre_restore',
    'before_restore',
    'pre_import',
    'pre_reset',
  ];

  /// Determina si un nombre de archivo está protegido contra purgas/rotaciones.
  static bool isProtectedBackupFilename(
    String filename, {
    List<String> tokens = protectedTokens,
  }) {
    final lower = filename.toLowerCase();
    for (final token in tokens) {
      if (lower.contains(token)) return true;
    }
    return false;
  }

  /// Genera el nombre de snapshot con timestamp en hora Perú (`America/Lima`).
  static String buildTimestampedFilename({
    required String prefix,
    required String reason,
    DateTime? timestamp,
  }) {
    final stamp = PeruTimeHelper.formatLimaFilenameTimestamp(timestamp);
    return '${prefix}_${reason}_$stamp.json';
  }

  /// Escribe un archivo snapshot de forma atómica (temporal + rename) en `backups/`.
  static Future<File> writeAtomicSnapshot({
    required Directory backupsDirectory,
    required String prefix,
    required String reason,
    required String content,
    DateTime? timestamp,
  }) async {
    if (!await backupsDirectory.exists()) {
      await backupsDirectory.create(recursive: true);
    }
    final filename = buildTimestampedFilename(
      prefix: prefix,
      reason: reason,
      timestamp: timestamp,
    );
    final targetFile = File('${backupsDirectory.path}/$filename');
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final tmpFile = File('${targetFile.path}.$pid.$stamp.tmp');
    try {
      await tmpFile.writeAsString(content, flush: true);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tmpFile.rename(targetFile.path);
    } finally {
      if (await tmpFile.exists()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
    }
    return targetFile;
  }

  /// Copia un archivo origen a `backups/` generando su nombre con hora Lima GMT-5.
  static Future<File?> copyFileAsSnapshot({
    required File sourceFile,
    required Directory backupsDirectory,
    required String prefix,
    required String reason,
    DateTime? timestamp,
  }) async {
    if (!await sourceFile.exists()) return null;
    if (!await backupsDirectory.exists()) {
      await backupsDirectory.create(recursive: true);
    }
    final filename = buildTimestampedFilename(
      prefix: prefix,
      reason: reason,
      timestamp: timestamp,
    );
    final destFile = File('${backupsDirectory.path}/$filename');
    return sourceFile.copy(destFile.path);
  }

  /// Limpia los snapshots automáticos que comiencen con alguno de [autoPrefixes],
  /// conservando los últimos [maxAutoSnapshots] y protegiendo los que contengan [tokens].
  static Future<void> cleanOldSnapshots({
    required Directory backupsDirectory,
    required List<String> autoPrefixes,
    int maxAutoSnapshots = defaultMaxAutoSnapshots,
    List<String> protectedTokensList = protectedTokens,
  }) async {
    if (maxAutoSnapshots < 0) return;
    if (!await backupsDirectory.exists()) return;

    final autoSnapshots = <File>[];
    final entities = await backupsDirectory.list().toList();

    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        final filename = entity.uri.pathSegments.last;
        final matchesPrefix =
            autoPrefixes.any((prefix) => filename.startsWith(prefix));
        if (!matchesPrefix) continue;
        if (isProtectedBackupFilename(filename, tokens: protectedTokensList)) {
          continue;
        }
        autoSnapshots.add(entity);
      }
    }

    if (autoSnapshots.length <= maxAutoSnapshots) return;

    final fileStats = <String, FileStat>{};
    for (final file in autoSnapshots) {
      fileStats[file.path] = await file.stat();
    }

    autoSnapshots.sort((a, b) {
      final statA = fileStats[a.path]!;
      final statB = fileStats[b.path]!;
      final cmp = statB.modified.compareTo(statA.modified);
      if (cmp != 0) return cmp;
      return b.path.compareTo(a.path);
    });

    final toDelete = autoSnapshots.sublist(maxAutoSnapshots);
    for (final file in toDelete) {
      try {
        await file.delete();
      } catch (e) {
        stderr.writeln(
          'Warning: Error eliminando snapshot antiguo ${file.path}: $e',
        );
      }
    }
  }
}
