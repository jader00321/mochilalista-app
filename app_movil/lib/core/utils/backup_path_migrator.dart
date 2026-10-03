import 'package:app_movil/core/database/local_db.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:app_movil/core/utils/app_logger.dart';

class BackupPathMigrator {
  /// Migrates all absolute image paths in the database to match the current device's application documents directory.
  static Future<void> migrateAllImagePaths() async {
    try {
      final db = await LocalDatabase.instance.database;
      final directory = await getApplicationDocumentsDirectory();
      final newBasePath = directory.path;

      final tablesAndColumns = {
        'negocios': ['logo_url'],
        'marcas': ['imagen_url'],
        'productos': ['imagen_url'],
        'facturas_carga': ['imagen_url'],
        'presentaciones_producto': ['imagen_url'],
        'paquetes': ['imagen_url'],
        'smart_quotations': ['source_image_url'],
        'smart_quotation_items': ['image_url'],
        'ventas': ['foto_entrega'],
        'venta_items': ['image_url'],
      };

      int totalMigrated = 0;

      for (var entry in tablesAndColumns.entries) {
        final table = entry.key;
        for (var column in entry.value) {
          try {
            // Obtenemos todos los registros que tienen una ruta que no es http ni nula
            final rows = await db.query(
              table,
              where: "$column IS NOT NULL AND $column != '' AND $column NOT LIKE 'http%'",
            );

            for (var row in rows) {
              final oldPath = row[column] as String;
              final fileName = p.basename(oldPath);
              final newPath = p.join(newBasePath, fileName);

              if (oldPath != newPath) {
                await db.update(
                  table,
                  {column: newPath},
                  where: 'id = ?',
                  whereArgs: [row['id']],
                );
                totalMigrated++;
              }
            }
          } catch (e) {
            // Ignorar errores si la tabla o columna no existe en esta versión
            AppLogger.info('BackupPathMigrator', 'Omitiendo migración en $table.$column: $e');
          }
        }
      }
      
      AppLogger.info('BackupPathMigrator', 'Se migraron $totalMigrated rutas de imágenes al nuevo directorio.');
    } catch (e, stack) {
      AppLogger.error('BackupPathMigrator.migrateAllImagePaths', e, stack);
    }
  }
}
