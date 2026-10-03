import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/utils/app_logger.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

class BusinessBackupService {
  static const String _extension = '.mlb';

  static Future<Map<String, dynamic>> readBackupFile(String filePath, {bool extractImages = false}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('El archivo no existe.');
    }
    
    final bytes = await file.readAsBytes();
    Map<String, dynamic> data;

    try {
      // Intentamos decodificar como ZIP (Nuevo formato .mlb)
      final archive = ZipDecoder().decodeBytes(bytes);
      final jsonFile = archive.findFile('data.json');
      if (jsonFile == null) throw Exception('No se encontró data.json en el archivo.');
      
      final content = utf8.decode(jsonFile.content as List<int>);
      data = jsonDecode(content);

      // Copiamos las imágenes al directorio local si es necesario
      final docDir = await getApplicationDocumentsDirectory();
      final newBasePath = docDir.path;
      
      if (extractImages) {
        for (var f in archive) {
          if (f.isFile && f.name.startsWith('images/')) {
            final fileName = p.basename(f.name);
            final localPath = p.join(newBasePath, fileName);
            final outFile = File(localPath);
            await outFile.writeAsBytes(f.content as List<int>);
          }
        }
      }

      // Actualizamos las rutas absolutas en el JSON para que coincidan con el nuevo dispositivo
      _updateJsonImagePaths(data, newBasePath);

    } catch (e) {
      // Fallback: Si no es un ZIP, asumimos que es el texto JSON plano heredado
      AppLogger.info('BusinessBackupService', 'El archivo no es un ZIP válido. Intentando lectura como texto plano antiguo.');
      final content = await file.readAsString();
      data = jsonDecode(content);
    }

    if (data['version'] == null || data['data'] == null) {
      throw Exception('Formato de archivo inválido.');
    }
    data['filePath'] = filePath;
    return data;
  }

  static void _updateJsonImagePaths(Map<String, dynamic> data, String newBasePath) {
    final dataMap = data['data'] as Map<String, dynamic>;
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

    for (var entry in tablesAndColumns.entries) {
      final table = entry.key;
      final columns = entry.value;
      
      if (dataMap.containsKey(table)) {
        final rows = dataMap[table] as List<dynamic>;
        for (var row in rows) {
          for (var column in columns) {
             final oldPath = row[column];
             if (oldPath != null && oldPath.toString().isNotEmpty && !oldPath.toString().startsWith('http')) {
                 final fileName = p.basename(oldPath.toString());
                 row[column] = p.join(newBasePath, fileName);
             }
          }
        }
      }
    }
  }

  static Future<File> _createBackupZip(Map<String, dynamic> backupData, Directory dir, String businessName) async {
    final String jsonString = jsonEncode(backupData);
    final archive = Archive();
    archive.addFile(ArchiveFile('data.json', utf8.encode(jsonString).length, utf8.encode(jsonString)));
    
    final Set<String> imagePaths = {};
    
    void collect(String table, String col) {
      if (backupData['data'][table] != null) {
        for (var row in backupData['data'][table]) {
          final val = row[col];
          if (val != null && val.toString().isNotEmpty && !val.toString().startsWith('http')) {
            imagePaths.add(val.toString());
          }
        }
      }
    }

    collect('negocios', 'logo_url');
    collect('marcas', 'imagen_url');
    collect('productos', 'imagen_url');
    collect('facturas_carga', 'imagen_url');
    collect('presentaciones_producto', 'imagen_url');
    collect('paquetes', 'imagen_url');
    collect('smart_quotations', 'source_image_url');
    collect('smart_quotation_items', 'image_url');
    collect('ventas', 'foto_entrega');
    collect('venta_items', 'image_url');

    for (String path in imagePaths) {
      final file = File(path);
      if (file.existsSync()) {
        final fileName = p.basename(path);
        final bytes = file.readAsBytesSync();
        archive.addFile(ArchiveFile('images/$fileName', bytes.length, bytes));
      }
    }

    final zipData = ZipEncoder().encode(archive);
    final cleanName = businessName.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
    final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final File backupFile = File('${dir.path}/${cleanName}_$dateStr$_extension');
    await backupFile.writeAsBytes(zipData);
    return backupFile;
  }

  // Exportar negocio específico
  static Future<bool> exportBusiness(int negocioId, String businessName, {bool includeSecurityPin = false}) async {
    try {
      final db = await LocalDatabase.instance.database;
      
      Map<String, dynamic> backupData = {
        'version': 1,
        'export_date': DateTime.now().toIso8601String(),
        'negocio_id': negocioId,
        'has_security_pin': includeSecurityPin,
        'data': {}
      };

      // 1. Negocio y Usuarios
      backupData['data']['negocios'] = await db.query('negocios', where: 'id = ?', whereArgs: [negocioId]);
      
      final negociosList = backupData['data']['negocios'] as List;
      if (negociosList.isNotEmpty) {
          int idDueno = negociosList.first['id_dueno'];
          final userRow = await db.query('usuarios', where: 'id = ?', whereArgs: [idDueno]);
          if (userRow.isNotEmpty) {
             var u = Map<String,dynamic>.from(userRow.first);
             if (includeSecurityPin) {
                final storage = FlutterSecureStorage();
                String? pin = await storage.read(key: 'pin_$idDueno');
                u['password_hash'] = pin; // Usamos este campo en el JSON para transportarlo
             } else {
                u['password_hash'] = null; 
             }
             backupData['data']['usuarios'] = [u];
          }
      }
      
      backupData['data']['codigos_acceso_negocio'] = await db.query('codigos_acceso_negocio', where: 'negocio_id = ?', whereArgs: [negocioId]);

      // 2. Catálogo e Inventario
      backupData['data']['categorias'] = await db.query('categorias', where: 'negocio_id = ?', whereArgs: [negocioId]);
      backupData['data']['marcas'] = await db.query('marcas', where: 'negocio_id = ?', whereArgs: [negocioId]);
      backupData['data']['proveedores'] = await db.query('proveedores', where: 'negocio_id = ?', whereArgs: [negocioId]);
      backupData['data']['productos'] = await db.query('productos', where: 'negocio_id = ?', whereArgs: [negocioId]);
      backupData['data']['facturas_carga'] = await db.query('facturas_carga', where: 'negocio_id = ?', whereArgs: [negocioId]);
      
      // Presentaciones (asociadas a productos del negocio)
      final productIds = (backupData['data']['productos'] as List).map((p) => p['id']).toList();
      if (productIds.isNotEmpty) {
        backupData['data']['presentaciones_producto'] = await db.query(
          'presentaciones_producto',
          where: 'producto_id IN (${List.filled(productIds.length, '?').join(',')})',
          whereArgs: productIds,
        );
      } else {
        backupData['data']['presentaciones_producto'] = [];
      }

      // 3. CRM y Cotizaciones
      backupData['data']['clientes'] = await db.query('clientes', where: 'negocio_id = ?', whereArgs: [negocioId]);
      backupData['data']['smart_quotations'] = await db.query('smart_quotations', where: 'negocio_id = ?', whereArgs: [negocioId]);
      
      final quoteIds = (backupData['data']['smart_quotations'] as List).map((q) => q['id']).toList();
      if (quoteIds.isNotEmpty) {
        backupData['data']['smart_quotation_items'] = await db.query(
          'smart_quotation_items',
          where: 'quotation_id IN (${List.filled(quoteIds.length, '?').join(',')})',
          whereArgs: quoteIds,
        );
      } else {
        backupData['data']['smart_quotation_items'] = [];
      }

      // 4. Ventas y Pagos
      backupData['data']['ventas'] = await db.query('ventas', where: 'negocio_id = ?', whereArgs: [negocioId]);
      final saleIds = (backupData['data']['ventas'] as List).map((v) => v['id']).toList();
      
      if (saleIds.isNotEmpty) {
        backupData['data']['venta_items'] = await db.query(
          'venta_items',
          where: 'venta_id IN (${List.filled(saleIds.length, '?').join(',')})',
          whereArgs: saleIds,
        );
        backupData['data']['cuotas'] = await db.query(
          'cuotas',
          where: 'venta_id IN (${List.filled(saleIds.length, '?').join(',')})',
          whereArgs: saleIds,
        );
      } else {
        backupData['data']['venta_items'] = [];
        backupData['data']['cuotas'] = [];
      }

      backupData['data']['pagos'] = await db.query('pagos', where: 'negocio_id = ?', whereArgs: [negocioId]);

      // 5. Promociones
      backupData['data']['campanas_promocionales'] = await db.query('campanas_promocionales', where: 'negocio_id = ?', whereArgs: [negocioId]);
      backupData['data']['paquetes'] = await db.query('paquetes', where: 'negocio_id = ?', whereArgs: [negocioId]);
      
      final pkgIds = (backupData['data']['paquetes'] as List).map((p) => p['id']).toList();
      if (pkgIds.isNotEmpty) {
        backupData['data']['items_paquete'] = await db.query(
          'items_paquete',
          where: 'paquete_id IN (${List.filled(pkgIds.length, '?').join(',')})',
          whereArgs: pkgIds,
        );
      } else {
        backupData['data']['items_paquete'] = [];
      }

      // Campañas y Reglas de Promoción
      final campaignIds = (backupData['data']['campanas_promocionales'] as List).map((c) => c['id']).toList();
      if (campaignIds.isNotEmpty) {
        backupData['data']['reglas_promocion'] = await db.query(
          'reglas_promocion',
          where: 'campana_id IN (${List.filled(campaignIds.length, '?').join(',')})',
          whereArgs: campaignIds,
        );
      } else {
        backupData['data']['reglas_promocion'] = [];
      }

      // Trazabilidad, Historial y Notificaciones
      backupData['data']['stock_ledger'] = await db.query('stock_ledger', where: 'negocio_id = ?', whereArgs: [negocioId]);
      backupData['data']['notificaciones'] = await db.query('notificaciones', where: 'negocio_id = ?', whereArgs: [negocioId]);
      
      if (productIds.isNotEmpty) {
        backupData['data']['product_history'] = await db.query(
          'product_history',
          where: 'entidad_tipo = ? AND entidad_id IN (${List.filled(productIds.length, '?').join(',')})',
          whereArgs: ['producto', ...productIds],
        );
      } else {
        backupData['data']['product_history'] = [];
      }

      // 6. Snapshots
      backupData['data']['business_snapshots'] = await db.query('business_snapshots', where: 'negocio_id = ?', whereArgs: [negocioId]);

      final dir = await getTemporaryDirectory();
      final File backupFile = await _createBackupZip(backupData, dir, businessName);

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(backupFile.path)], 
        text: '📦 Backup de Negocio: $businessName\nEste archivo (.mlb) contiene los datos exclusivos de este perfil de negocio y sus imágenes.'
      );

      return true;
    } catch (e, stack) {
      AppLogger.error('BusinessBackupService.exportBusiness', e, stack);
      return false;
    }
  }

  // Exportar a descargas (Para backup automático)
  static Future<bool> exportBusinessToFile(int negocioId, String businessName, {bool includeSecurityPin = false, String? targetDirectory}) async {
    try {
      final db = await LocalDatabase.instance.database;
      
      Map<String, dynamic> backupData = {
        'version': 1,
        'export_date': DateTime.now().toIso8601String(),
        'negocio_id': negocioId,
        'has_security_pin': includeSecurityPin,
        'data': {}
      };

      // 1. Negocio y Usuarios
      backupData['data']['negocios'] = await db.query('negocios', where: 'id = ?', whereArgs: [negocioId]);
      
      final negociosList = backupData['data']['negocios'] as List;
      if (negociosList.isNotEmpty) {
          int idDueno = negociosList.first['id_dueno'];
          final userRow = await db.query('usuarios', where: 'id = ?', whereArgs: [idDueno]);
          if (userRow.isNotEmpty) {
             var u = Map<String,dynamic>.from(userRow.first);
             if (includeSecurityPin) {
                final storage = FlutterSecureStorage();
                String? pin = await storage.read(key: 'pin_$idDueno');
                u['password_hash'] = pin;
             } else {
                u['password_hash'] = null; 
             }
             backupData['data']['usuarios'] = [u];
          }
      }
      
      backupData['data']['codigos_acceso_negocio'] = await db.query('codigos_acceso_negocio', where: 'negocio_id = ?', whereArgs: [negocioId]);

      // 2. Catálogo e Inventario
      backupData['data']['categorias'] = await db.query('categorias', where: 'negocio_id = ?', whereArgs: [negocioId]);
      backupData['data']['marcas'] = await db.query('marcas', where: 'negocio_id = ?', whereArgs: [negocioId]);
      backupData['data']['proveedores'] = await db.query('proveedores', where: 'negocio_id = ?', whereArgs: [negocioId]);
      backupData['data']['productos'] = await db.query('productos', where: 'negocio_id = ?', whereArgs: [negocioId]);
      backupData['data']['facturas_carga'] = await db.query('facturas_carga', where: 'negocio_id = ?', whereArgs: [negocioId]);
      
      final productIds = (backupData['data']['productos'] as List).map((p) => p['id']).toList();
      if (productIds.isNotEmpty) {
        backupData['data']['presentaciones_producto'] = await db.query(
          'presentaciones_producto',
          where: 'producto_id IN (${List.filled(productIds.length, '?').join(',')})',
          whereArgs: productIds,
        );
      } else {
        backupData['data']['presentaciones_producto'] = [];
      }

      // 3. CRM y Cotizaciones
      backupData['data']['clientes'] = await db.query('clientes', where: 'negocio_id = ?', whereArgs: [negocioId]);
      backupData['data']['smart_quotations'] = await db.query('smart_quotations', where: 'negocio_id = ?', whereArgs: [negocioId]);
      
      final quoteIds = (backupData['data']['smart_quotations'] as List).map((q) => q['id']).toList();
      if (quoteIds.isNotEmpty) {
        backupData['data']['smart_quotation_items'] = await db.query(
          'smart_quotation_items',
          where: 'quotation_id IN (${List.filled(quoteIds.length, '?').join(',')})',
          whereArgs: quoteIds,
        );
      } else {
        backupData['data']['smart_quotation_items'] = [];
      }

      // 4. Ventas y Pagos
      backupData['data']['ventas'] = await db.query('ventas', where: 'negocio_id = ?', whereArgs: [negocioId]);
      final saleIds = (backupData['data']['ventas'] as List).map((v) => v['id']).toList();
      
      if (saleIds.isNotEmpty) {
        backupData['data']['venta_items'] = await db.query(
          'venta_items',
          where: 'venta_id IN (${List.filled(saleIds.length, '?').join(',')})',
          whereArgs: saleIds,
        );
        backupData['data']['cuotas'] = await db.query(
          'cuotas',
          where: 'venta_id IN (${List.filled(saleIds.length, '?').join(',')})',
          whereArgs: saleIds,
        );
      } else {
        backupData['data']['venta_items'] = [];
        backupData['data']['cuotas'] = [];
      }

      backupData['data']['pagos'] = await db.query('pagos', where: 'negocio_id = ?', whereArgs: [negocioId]);

      // 5. Promociones
      backupData['data']['campanas_promocionales'] = await db.query('campanas_promocionales', where: 'negocio_id = ?', whereArgs: [negocioId]);
      backupData['data']['paquetes'] = await db.query('paquetes', where: 'negocio_id = ?', whereArgs: [negocioId]);
      
      final pkgIds = (backupData['data']['paquetes'] as List).map((p) => p['id']).toList();
      if (pkgIds.isNotEmpty) {
        backupData['data']['items_paquete'] = await db.query(
          'items_paquete',
          where: 'paquete_id IN (${List.filled(pkgIds.length, '?').join(',')})',
          whereArgs: pkgIds,
        );
      } else {
        backupData['data']['items_paquete'] = [];
      }

      // Campañas y Reglas de Promoción
      final campaignIds = (backupData['data']['campanas_promocionales'] as List).map((c) => c['id']).toList();
      if (campaignIds.isNotEmpty) {
        backupData['data']['reglas_promocion'] = await db.query(
          'reglas_promocion',
          where: 'campana_id IN (${List.filled(campaignIds.length, '?').join(',')})',
          whereArgs: campaignIds,
        );
      } else {
        backupData['data']['reglas_promocion'] = [];
      }

      // Trazabilidad, Historial y Notificaciones
      backupData['data']['stock_ledger'] = await db.query('stock_ledger', where: 'negocio_id = ?', whereArgs: [negocioId]);
      backupData['data']['notificaciones'] = await db.query('notificaciones', where: 'negocio_id = ?', whereArgs: [negocioId]);
      
      if (productIds.isNotEmpty) {
        backupData['data']['product_history'] = await db.query(
          'product_history',
          where: 'entidad_tipo = ? AND entidad_id IN (${List.filled(productIds.length, '?').join(',')})',
          whereArgs: ['producto', ...productIds],
        );
      } else {
        backupData['data']['product_history'] = [];
      }

      // 6. Snapshots
      backupData['data']['business_snapshots'] = await db.query('business_snapshots', where: 'negocio_id = ?', whereArgs: [negocioId]);

      final dir = Directory(targetDirectory ?? '/storage/emulated/0/Download');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      await _createBackupZip(backupData, dir, businessName);

      return true;
    } catch (e, stack) {
      AppLogger.error('BusinessBackupService.exportBusinessToFile', e, stack);
      return false;
    }
  }

  // Seleccionar archivo y revisar metadata
  static Future<Map<String, dynamic>?> pickBackupFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        
        if (!filePath.toLowerCase().endsWith('.mlb')) {
          throw Exception("El archivo seleccionado no es un backup válido (.mlb)");
        }

        Map<String, dynamic> backupData = await readBackupFile(filePath, extractImages: false);
        
        return {
          'filePath': filePath,
          'has_security_pin': backupData['has_security_pin'] == true,
          'data': backupData
        };
      }
    } catch (e) {
      AppLogger.error('BusinessBackupService.pickBackupFile', e, null);
      throw Exception(e.toString().replaceAll("Exception:", "").trim());
    }
    return null;
  }

  // Importar negocio
  // Si replaceTargetNegocioId es nulo, se crea un NUEVO perfil de negocio.
  // Si tiene un ID, se BORRAN los datos de ese negocio y se reemplazan.
  static Future<bool> importBusiness(int currentUserId, String filePath, {int? replaceTargetNegocioId, bool applyPin = false}) async {
    try {
        Map<String, dynamic> backupData = await readBackupFile(filePath, extractImages: true);
        Map<String, dynamic> data = backupData['data'];

        final db = await LocalDatabase.instance.database;

        await db.transaction((txn) async {
          int targetNegocioId;

          if (replaceTargetNegocioId != null) {
            targetNegocioId = replaceTargetNegocioId;
            // 1. Limpiar manualmente las tablas hijas sin negocio_id
            await txn.rawDelete('''
              DELETE FROM smart_quotation_items WHERE quotation_id IN 
              (SELECT id FROM smart_quotations WHERE negocio_id = ?)
            ''', [targetNegocioId]);
            await txn.rawDelete('''
              DELETE FROM venta_items WHERE venta_id IN 
              (SELECT id FROM ventas WHERE negocio_id = ?)
            ''', [targetNegocioId]);
            await txn.rawDelete('''
              DELETE FROM cuotas WHERE venta_id IN 
              (SELECT id FROM ventas WHERE negocio_id = ?)
            ''', [targetNegocioId]);
            await txn.rawDelete('''
              DELETE FROM items_paquete WHERE paquete_id IN 
              (SELECT id FROM paquetes WHERE negocio_id = ?)
            ''', [targetNegocioId]);
            await txn.rawDelete('''
              DELETE FROM reglas_promocion WHERE campana_id IN 
              (SELECT id FROM campanas_promocionales WHERE negocio_id = ?)
            ''', [targetNegocioId]);
            await txn.rawDelete('''
              DELETE FROM presentaciones_producto WHERE producto_id IN 
              (SELECT id FROM productos WHERE negocio_id = ?)
            ''', [targetNegocioId]);
            await txn.rawDelete('''
              DELETE FROM product_history WHERE entidad_tipo = 'producto' AND entidad_id IN 
              (SELECT id FROM productos WHERE negocio_id = ?)
            ''', [targetNegocioId]);
            await txn.rawDelete('''
              DELETE FROM product_history WHERE entidad_tipo = 'presentacion' AND entidad_id IN 
              (SELECT id FROM presentaciones_producto WHERE producto_id IN (SELECT id FROM productos WHERE negocio_id = ?))
            ''', [targetNegocioId]);

            // 2. Limpiar tablas con negocio_id (orden dependientes primero)
            final tablesToClean = [
              'stock_ledger', 'notificaciones', 'codigos_acceso_negocio', 'business_snapshots',
              'pagos', 'ventas', 'smart_quotations', 'clientes',
              'paquetes', 'campanas_promocionales',
              'facturas_carga', 'productos',
              'proveedores', 'marcas', 'categorias'
            ];
            for (String table in tablesToClean) {
              await txn.delete(table, where: 'negocio_id = ?', whereArgs: [targetNegocioId]);
            }
            
            // Actualizar la información del negocio en sí (nombre, logo, config)
            List<dynamic> negocios = data['negocios'] ?? [];
            if (negocios.isNotEmpty) {
               Map<String, dynamic> negocioData = Map<String, dynamic>.from(negocios.first);
               negocioData.remove('id');
               negocioData.remove('id_dueno');
               await txn.update('negocios', negocioData, where: 'id = ?', whereArgs: [targetNegocioId]);
            }
          } else {
            // Modo Merge (Crear nuevo negocio)
            List<dynamic> negocios = data['negocios'] ?? [];
            if (negocios.isEmpty) throw Exception("Backup inválido: No hay negocio.");
            Map<String, dynamic> negocio = Map<String, dynamic>.from(negocios.first);
            
            // 1. Crear un usuario clon para este negocio importado
            final usuariosList = await txn.query('usuarios', where: 'id = ?', whereArgs: [currentUserId], limit: 1);
            if (usuariosList.isEmpty) throw Exception("Usuario actual no encontrado.");
            Map<String, dynamic> usuarioClon = Map<String, dynamic>.from(usuariosList.first);
            usuarioClon.remove('id');
            usuarioClon['nombre_completo'] = "${usuarioClon['nombre_completo']} (Clon Importado)";
            int nuevoUsuarioId = await txn.insert('usuarios', usuarioClon);
            
            // 2. Insertar el negocio con el nuevo dueño
            negocio.remove('id');
            negocio['id_dueno'] = nuevoUsuarioId;
            negocio['nombre_comercial'] = "${negocio['nombre_comercial']} (Importado)";
            targetNegocioId = await txn.insert('negocios', negocio);
            
            // 3. Vincular el nuevo usuario al negocio
            await txn.insert('negocio_usuario', {
              'usuario_id': nuevoUsuarioId,
              'negocio_id': targetNegocioId,
              'rol_en_negocio': 'propietario',
              'estado_acceso': 'activo'
            });
            
            // Utilizar el nuevo usuario para la creación de registros
            currentUserId = nuevoUsuarioId;
          }

          // Función auxiliar para remapear IDs
          Map<int, int> categoryIdMap = {};
          Map<int, int> brandIdMap = {};
          Map<int, int> supplierIdMap = {};
          Map<int, int> productIdMap = {};
          Map<int, int> presentationIdMap = {};
          Map<int, int> clientIdMap = {};
          Map<int, int> quotationIdMap = {};
          Map<int, int> saleIdMap = {};
          Map<int, int> invoiceIdMap = {};
          Map<int, int> packageIdMap = {};
          Map<int, int> campaignIdMap = {};

          // Insertar Categorias
          for (var item in data['categorias'] ?? []) {
            int oldId = item['id'];
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            item['negocio_id'] = targetNegocioId;
            int newId = await txn.insert('categorias', item);
            categoryIdMap[oldId] = newId;
          }

          // Insertar Codigos de Acceso
          for (var item in data['codigos_acceso_negocio'] ?? []) {
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            item['negocio_id'] = targetNegocioId;
            item['creado_por_usuario_id'] = currentUserId;
            await txn.insert('codigos_acceso_negocio', item);
          }

          // Insertar Marcas
          for (var item in data['marcas'] ?? []) {
            int oldId = item['id'];
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            item['negocio_id'] = targetNegocioId;
            int newId = await txn.insert('marcas', item);
            brandIdMap[oldId] = newId;
          }

          // Insertar Proveedores
          for (var item in data['proveedores'] ?? []) {
            int oldId = item['id'];
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            item['negocio_id'] = targetNegocioId;
            int newId = await txn.insert('proveedores', item);
            supplierIdMap[oldId] = newId;
          }

          // Insertar Clientes
          for (var item in data['clientes'] ?? []) {
            int oldId = item['id'];
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            item['negocio_id'] = targetNegocioId;
            item['creado_por_usuario_id'] = currentUserId; // Asignar al usuario actual
            int newId = await txn.insert('clientes', item);
            clientIdMap[oldId] = newId;
          }

          // Insertar Productos
          for (var item in data['productos'] ?? []) {
            int oldId = item['id'];
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            item['negocio_id'] = targetNegocioId;
            if (item['categoria_id'] != null) item['categoria_id'] = categoryIdMap[item['categoria_id']];
            if (item['marca_id'] != null) item['marca_id'] = brandIdMap[item['marca_id']];
            int newId = await txn.insert('productos', item);
            productIdMap[oldId] = newId;
          }
          
          // Insertar Facturas Carga
          for (var item in data['facturas_carga'] ?? []) {
            int oldId = item['id'];
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            item['negocio_id'] = targetNegocioId;
            if (item['proveedor_id'] != null) item['proveedor_id'] = supplierIdMap[item['proveedor_id']];
            int newId = await txn.insert('facturas_carga', item);
            invoiceIdMap[oldId] = newId;
          }

          // Insertar Presentaciones
          for (var item in data['presentaciones_producto'] ?? []) {
            int oldId = item['id'];
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            if (item['producto_id'] != null) item['producto_id'] = productIdMap[item['producto_id']];
            if (item['proveedor_id'] != null) item['proveedor_id'] = supplierIdMap[item['proveedor_id']];
            if (item['factura_carga_id'] != null) item['factura_carga_id'] = invoiceIdMap[item['factura_carga_id']];
            int newId = await txn.insert('presentaciones_producto', item);
            presentationIdMap[oldId] = newId;
          }

          // Insertar Campañas
          for (var item in data['campanas_promocionales'] ?? []) {
            int oldId = item['id'];
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            item['negocio_id'] = targetNegocioId;
            int newId = await txn.insert('campanas_promocionales', item);
            campaignIdMap[oldId] = newId;
          }

          // Insertar Paquetes
          for (var item in data['paquetes'] ?? []) {
            int oldId = item['id'];
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            item['negocio_id'] = targetNegocioId;
            if (item['campana_id'] != null) item['campana_id'] = campaignIdMap[item['campana_id']];
            int newId = await txn.insert('paquetes', item);
            packageIdMap[oldId] = newId;
          }

          // Insertar Paquete Items
          for (var item in data['items_paquete'] ?? []) {
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            if (item['paquete_id'] != null) item['paquete_id'] = packageIdMap[item['paquete_id']];
            if (item['producto_id'] != null) item['producto_id'] = productIdMap[item['producto_id']];
            if (item['presentacion_id'] != null) item['presentacion_id'] = presentationIdMap[item['presentacion_id']];
            await txn.insert('items_paquete', item);
          }

          // Insertar Reglas de Promoción
          for (var item in data['reglas_promocion'] ?? []) {
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            if (item['campana_id'] != null) item['campana_id'] = campaignIdMap[item['campana_id']];
            if (item['presentacion_id'] != null) item['presentacion_id'] = presentationIdMap[item['presentacion_id']];
            await txn.insert('reglas_promocion', item);
          }

          // Insertar Cotizaciones
          for (var item in data['smart_quotations'] ?? []) {
            int oldId = item['id'];
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            item['negocio_id'] = targetNegocioId;
            item['creado_por_usuario_id'] = currentUserId;
            if (item['client_id'] != null) item['client_id'] = clientIdMap[item['client_id']];
            int newId = await txn.insert('smart_quotations', item);
            quotationIdMap[oldId] = newId;
          }

          // Insertar Cotizacion Items
          for (var item in data['smart_quotation_items'] ?? []) {
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            if (item['quotation_id'] != null) item['quotation_id'] = quotationIdMap[item['quotation_id']];
            if (item['product_id'] != null) item['product_id'] = productIdMap[item['product_id']];
            if (item['presentation_id'] != null) item['presentation_id'] = presentationIdMap[item['presentation_id']];
            if (item['bundle_id'] != null) item['bundle_id'] = packageIdMap[item['bundle_id']];
            await txn.insert('smart_quotation_items', item);
          }

          // Insertar Ventas
          for (var item in data['ventas'] ?? []) {
            int oldId = item['id'];
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            item['negocio_id'] = targetNegocioId;
            item['creado_por_usuario_id'] = currentUserId;
            if (item['cotizacion_id'] != null) item['cotizacion_id'] = quotationIdMap[item['cotizacion_id']];
            if (item['cliente_id'] != null) item['cliente_id'] = clientIdMap[item['cliente_id']];
            int newId = await txn.insert('ventas', item);
            saleIdMap[oldId] = newId;
          }

          // Insertar Venta Items
          for (var item in data['venta_items'] ?? []) {
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            if (item['venta_id'] != null) item['venta_id'] = saleIdMap[item['venta_id']];
            if (item['product_id'] != null) item['product_id'] = productIdMap[item['product_id']];
            if (item['presentation_id'] != null) item['presentation_id'] = presentationIdMap[item['presentation_id']];
            if (item['bundle_id'] != null) item['bundle_id'] = packageIdMap[item['bundle_id']];
            await txn.insert('venta_items', item);
          }

          // Insertar Cuotas
          Map<int, int> cuotaIdMap = {};
          for (var item in data['cuotas'] ?? []) {
            int oldId = item['id'];
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            if (item['venta_id'] != null) item['venta_id'] = saleIdMap[item['venta_id']];
            int newId = await txn.insert('cuotas', item);
            cuotaIdMap[oldId] = newId;
          }

          // Insertar Pagos
          for (var item in data['pagos'] ?? []) {
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            item['negocio_id'] = targetNegocioId;
            item['creado_por_usuario_id'] = currentUserId;
            if (item['cliente_id'] != null) item['cliente_id'] = clientIdMap[item['cliente_id']];
            if (item['venta_id'] != null) item['venta_id'] = saleIdMap[item['venta_id']];
            if (item['cuota_id'] != null) item['cuota_id'] = cuotaIdMap[item['cuota_id']];
            await txn.insert('pagos', item);
          }

          // Insertar Snapshots
          for (var item in data['business_snapshots'] ?? []) {
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            item['negocio_id'] = targetNegocioId;
            await txn.insert('business_snapshots', item);
          }

          // Insertar Stock Ledger
          for (var item in data['stock_ledger'] ?? []) {
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            item['negocio_id'] = targetNegocioId;
            if (item['presentation_id'] != null) item['presentation_id'] = presentationIdMap[item['presentation_id']];
            await txn.insert('stock_ledger', item);
          }

          // Insertar Product History
          for (var item in data['product_history'] ?? []) {
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            if (item['entidad_tipo'] == 'producto' && item['entidad_id'] != null) {
              item['entidad_id'] = productIdMap[item['entidad_id']];
            }
            item['usuario_id'] = currentUserId; // Reasignar al usuario que importa
            await txn.insert('product_history', item);
          }

          // Insertar Notificaciones
          for (var item in data['notificaciones'] ?? []) {
            item = Map<String, dynamic>.from(item);
            item.remove('id');
            item['negocio_id'] = targetNegocioId;
            item['user_id'] = currentUserId;
            await txn.insert('notificaciones', item);
          }

          // Aplicar PIN de seguridad si fue solicitado en Replace
          if (applyPin && backupData['has_security_pin'] == true) {
             final usuariosList = data['usuarios'] as List?;
             if (usuariosList != null && usuariosList.isNotEmpty) {
                String? backupPin = usuariosList.first['password_hash'];
                if (backupPin != null && backupPin.isNotEmpty) {
                    final storage = FlutterSecureStorage();
                    await storage.write(key: 'pin_$currentUserId', value: backupPin);
                }
             }
          }

        });
        return true;
    } catch (e, stack) {
      AppLogger.error('BusinessBackupService.importBusiness', e, stack);
      return false;
    }
  }
}
