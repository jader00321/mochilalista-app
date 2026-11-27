part of '../business_backup_service.dart';

Future<Map<String, dynamic>> _readBackupFileImpl(
  String filePath, {
  bool extractImages = false,
}) async {
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
    if (jsonFile == null) {
      throw Exception('No se encontró data.json en el archivo.');
    }

    final content = utf8.decode(jsonFile.content as List<int>);
    data = jsonDecode(content);

    // Copiamos las imágenes al directorio local si es necesario
    final docDir = await getApplicationDocumentsDirectory();
    final newBasePath = docDir.path;

    if (extractImages) {
      for (final f in archive) {
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
    AppLogger.info(
      'BusinessBackupService',
      'El archivo no es un ZIP válido. Intentando lectura como texto plano antiguo.',
    );
    final content = await file.readAsString();
    data = jsonDecode(content);
  }

  if (data['version'] == null || data['data'] == null) {
    throw Exception('Formato de archivo inválido.');
  }
  data['filePath'] = filePath;
  return data;
}

void _updateJsonImagePaths(Map<String, dynamic> data, String newBasePath) {
  final dataMap = data['data'] as Map<String, dynamic>;

  for (final entry in BusinessBackupService._imageTableColumns.entries) {
    final table = entry.key;
    final columns = entry.value;

    if (dataMap.containsKey(table)) {
      final rows = dataMap[table] as List<dynamic>;
      for (final row in rows) {
        for (final column in columns) {
          final oldPath = row[column];
          if (oldPath != null &&
              oldPath.toString().isNotEmpty &&
              !oldPath.toString().startsWith('http')) {
            final fileName = p.basename(oldPath.toString());
            row[column] = p.join(newBasePath, fileName);
          }
        }
      }
    }
  }
}

Future<File> _createBackupZip(
  Map<String, dynamic> backupData,
  Directory dir,
  String businessName,
) async {
  final String jsonString = jsonEncode(backupData);
  final archive = Archive();
  final encodedJson = utf8.encode(jsonString);
  archive.addFile(ArchiveFile('data.json', encodedJson.length, encodedJson));

  final Set<String> imagePaths = {};
  for (final entry in BusinessBackupService._imageTableColumns.entries) {
    final rows = backupData['data'][entry.key];
    if (rows == null) continue;
    for (final row in rows) {
      for (final col in entry.value) {
        final val = row[col];
        if (val != null &&
            val.toString().isNotEmpty &&
            !val.toString().startsWith('http')) {
          imagePaths.add(val.toString());
        }
      }
    }
  }

  for (final path in imagePaths) {
    final file = File(path);
    if (await file.exists()) {
      final fileName = p.basename(path);
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile('images/$fileName', bytes.length, bytes));
    }
  }

  final zipData = ZipEncoder().encode(archive);
  final cleanName = businessName
      .replaceAll(RegExp(r'[^\w\s]+'), '')
      .replaceAll(' ', '_');
  final dateStr = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '-')
      .split('.')[0];
  final File backupFile = File(
    '${dir.path}/${cleanName}_$dateStr${BusinessBackupService._extension}',
  );
  await backupFile.writeAsBytes(zipData);
  return backupFile;
}

Future<List<Map<String, dynamic>>> _queryByParentIds(
  dynamic db,
  String table,
  String fkColumn,
  List<dynamic> parentIds,
) async {
  if (parentIds.isEmpty) return [];
  return await db.query(
    table,
    where: '$fkColumn IN (${List.filled(parentIds.length, '?').join(',')})',
    whereArgs: parentIds,
  );
}

Future<Map<String, dynamic>> _collectBackupData(
  int negocioId, {
  bool includeSecurityPin = false,
}) async {
  final db = await LocalDatabase.instance.database;

  final Map<String, dynamic> backupData = {
    'version': 1,
    'export_date': DateTime.now().toIso8601String(),
    'negocio_id': negocioId,
    'has_security_pin': includeSecurityPin,
    'data': {},
  };

  // 1. Negocio y Usuarios
  backupData['data']['negocios'] = await db.query(
    'negocios',
    where: 'id = ?',
    whereArgs: [negocioId],
  );

  final negociosList = backupData['data']['negocios'] as List;
  if (negociosList.isNotEmpty) {
    final int idDueno = negociosList.first['id_dueno'];
    final userRow = await db.query(
      'usuarios',
      where: 'id = ?',
      whereArgs: [idDueno],
    );
    if (userRow.isNotEmpty) {
      final u = Map<String, dynamic>.from(userRow.first);
      if (includeSecurityPin) {
        const storage = FlutterSecureStorage();
        final String? pin = await storage.read(key: 'pin_$idDueno');
        final String? pinHash = await storage.read(key: 'pin_hash_$idDueno');
        final String? pinSalt = await storage.read(key: 'pin_salt_$idDueno');
        u['password_hash'] = pinHash ?? pin;
        u['password_salt'] = pinSalt;
      } else {
        u['password_hash'] = null;
        u['password_salt'] = null;
      }
      backupData['data']['usuarios'] = [u];
    }
  }

  backupData['data']['codigos_acceso_negocio'] = await db.query(
    'codigos_acceso_negocio',
    where: 'negocio_id = ?',
    whereArgs: [negocioId],
  );

  // 2. Catálogo e Inventario
  backupData['data']['categorias'] = await db.query(
    'categorias',
    where: 'negocio_id = ?',
    whereArgs: [negocioId],
  );
  backupData['data']['marcas'] = await db.query(
    'marcas',
    where: 'negocio_id = ?',
    whereArgs: [negocioId],
  );
  backupData['data']['proveedores'] = await db.query(
    'proveedores',
    where: 'negocio_id = ?',
    whereArgs: [negocioId],
  );
  backupData['data']['productos'] = await db.query(
    'productos',
    where: 'negocio_id = ?',
    whereArgs: [negocioId],
  );
  backupData['data']['facturas_carga'] = await db.query(
    'facturas_carga',
    where: 'negocio_id = ?',
    whereArgs: [negocioId],
  );

  final productIds = (backupData['data']['productos'] as List)
      .map((item) => item['id'])
      .toList();
  backupData['data']['presentaciones_producto'] = await _queryByParentIds(
    db,
    'presentaciones_producto',
    'producto_id',
    productIds,
  );

  // 3. CRM y Cotizaciones
  backupData['data']['clientes'] = await db.query(
    'clientes',
    where: 'negocio_id = ?',
    whereArgs: [negocioId],
  );
  backupData['data']['smart_quotations'] = await db.query(
    'smart_quotations',
    where: 'negocio_id = ?',
    whereArgs: [negocioId],
  );
  final quoteIds = (backupData['data']['smart_quotations'] as List)
      .map((q) => q['id'])
      .toList();
  backupData['data']['smart_quotation_items'] = await _queryByParentIds(
    db,
    'smart_quotation_items',
    'quotation_id',
    quoteIds,
  );

  // 4. Ventas y Pagos
  backupData['data']['ventas'] = await db.query(
    'ventas',
    where: 'negocio_id = ?',
    whereArgs: [negocioId],
  );
  final saleIds = (backupData['data']['ventas'] as List)
      .map((v) => v['id'])
      .toList();
  backupData['data']['venta_items'] = await _queryByParentIds(
    db,
    'venta_items',
    'venta_id',
    saleIds,
  );
  backupData['data']['cuotas'] = await _queryByParentIds(
    db,
    'cuotas',
    'venta_id',
    saleIds,
  );
  backupData['data']['pagos'] = await db.query(
    'pagos',
    where: 'negocio_id = ?',
    whereArgs: [negocioId],
  );

  // 5. Promociones
  backupData['data']['campanas_promocionales'] = await db.query(
    'campanas_promocionales',
    where: 'negocio_id = ?',
    whereArgs: [negocioId],
  );
  backupData['data']['paquetes'] = await db.query(
    'paquetes',
    where: 'negocio_id = ?',
    whereArgs: [negocioId],
  );
  final pkgIds = (backupData['data']['paquetes'] as List)
      .map((item) => item['id'])
      .toList();
  backupData['data']['items_paquete'] = await _queryByParentIds(
    db,
    'items_paquete',
    'paquete_id',
    pkgIds,
  );
  final campaignIds = (backupData['data']['campanas_promocionales'] as List)
      .map((c) => c['id'])
      .toList();
  backupData['data']['reglas_promocion'] = await _queryByParentIds(
    db,
    'reglas_promocion',
    'campana_id',
    campaignIds,
  );

  // Trazabilidad, Historial y Notificaciones
  backupData['data']['stock_ledger'] = await db.query(
    'stock_ledger',
    where: 'negocio_id = ?',
    whereArgs: [negocioId],
  );
  backupData['data']['notificaciones'] = await db.query(
    'notificaciones',
    where: 'negocio_id = ?',
    whereArgs: [negocioId],
  );

  final presentationIds =
      (backupData['data']['presentaciones_producto'] as List)
          .map((item) => item['id'])
          .toList();
  final List<Map<String, dynamic>> allHistory = [];
  if (productIds.isNotEmpty) {
    allHistory.addAll(
      await db.query(
        'product_history',
        where:
            'entidad_tipo = ? AND entidad_id IN (${List.filled(productIds.length, '?').join(',')})',
        whereArgs: ['producto', ...productIds],
      ),
    );
  }
  if (presentationIds.isNotEmpty) {
    allHistory.addAll(
      await db.query(
        'product_history',
        where:
            'entidad_tipo = ? AND entidad_id IN (${List.filled(presentationIds.length, '?').join(',')})',
        whereArgs: ['presentacion', ...presentationIds],
      ),
    );
  }
  backupData['data']['product_history'] = allHistory;

  // 6. Snapshots y V27
  backupData['data']['business_snapshots'] = await db.query(
    'business_snapshots',
    where: 'negocio_id = ?',
    whereArgs: [negocioId],
  );
  backupData['data']['metas_recompensas'] = await db.query(
    'metas_recompensas',
    where: 'negocio_id = ?',
    whereArgs: [negocioId],
  );
  backupData['data']['recompensas_cliente'] = await db.query(
    'recompensas_cliente',
    where: 'negocio_id = ?',
    whereArgs: [negocioId],
  );
  backupData['data']['historial_puntos_reputacion'] = await db.query(
    'historial_puntos_reputacion',
    where: 'negocio_id = ?',
    whereArgs: [negocioId],
  );

  return backupData;
}

Future<bool> _exportBusinessImpl(
  int negocioId,
  String businessName, {
  bool includeSecurityPin = false,
}) async {
  try {
    final backupData = await _collectBackupData(
      negocioId,
      includeSecurityPin: includeSecurityPin,
    );

    final dir = await getTemporaryDirectory();
    final File backupFile = await _createBackupZip(
      backupData,
      dir,
      businessName,
    );

    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [XFile(backupFile.path)],
      text:
          '📦 Backup de Negocio: $businessName\nEste archivo (.mlb) contiene los datos exclusivos de este perfil de negocio y sus imágenes.',
    );

    return true;
  } catch (e, stack) {
    AppLogger.error('BusinessBackupService.exportBusiness', e, stack);
    return false;
  }
}

Future<bool> _exportBusinessToFileImpl(
  int negocioId,
  String businessName, {
  bool includeSecurityPin = false,
  String? targetDirectory,
}) async {
  try {
    final backupData = await _collectBackupData(
      negocioId,
      includeSecurityPin: includeSecurityPin,
    );

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

Future<Map<String, dynamic>?> _pickBackupFileImpl() async {
  try {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      final String filePath = result.files.single.path!;

      if (!filePath.toLowerCase().endsWith('.mlb')) {
        throw Exception(
          "El archivo seleccionado no es un backup válido (.mlb)",
        );
      }

      final Map<String, dynamic> backupData = await _readBackupFileImpl(
        filePath,
        extractImages: false,
      );

      return {
        'filePath': filePath,
        'has_security_pin': backupData['has_security_pin'] == true,
        'data': backupData,
      };
    }
  } catch (e) {
    AppLogger.error('BusinessBackupService.pickBackupFile', e, null);
    throw Exception(e.toString().replaceAll("Exception:", "").trim());
  }
  return null;
}
