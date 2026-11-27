import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/services/security_service.dart';
import 'package:app_movil/core/utils/app_logger.dart';

part 'business_backup/business_backup_export_part.dart';
part 'business_backup/business_backup_import_part.dart';
part 'business_backup/business_backup_import_operations_part.dart';

class BusinessBackupService {
  static const String _extension = '.mlb';

  static const Map<String, List<String>> _imageTableColumns = {
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

  static Future<Map<String, dynamic>> readBackupFile(
    String filePath, {
    bool extractImages = false,
  }) => _readBackupFileImpl(filePath, extractImages: extractImages);

  /// Exportar negocio específico (compartir por WhatsApp/otros)
  static Future<bool> exportBusiness(
    int negocioId,
    String businessName, {
    bool includeSecurityPin = false,
  }) => _exportBusinessImpl(
    negocioId,
    businessName,
    includeSecurityPin: includeSecurityPin,
  );

  /// Exportar a descargas (Para backup automático)
  static Future<bool> exportBusinessToFile(
    int negocioId,
    String businessName, {
    bool includeSecurityPin = false,
    String? targetDirectory,
  }) => _exportBusinessToFileImpl(
    negocioId,
    businessName,
    includeSecurityPin: includeSecurityPin,
    targetDirectory: targetDirectory,
  );

  /// Seleccionar archivo y revisar metadata
  static Future<Map<String, dynamic>?> pickBackupFile() =>
      _pickBackupFileImpl();

  /// Importar negocio: si [replaceTargetNegocioId] es nulo crea un nuevo perfil;
  /// en caso contrario borra y reemplaza los datos del negocio indicado.
  static Future<bool> importBusiness(
    int currentUserId,
    String filePath, {
    int? replaceTargetNegocioId,
    bool applyPin = false,
  }) => _importBusinessImpl(
    currentUserId,
    filePath,
    replaceTargetNegocioId: replaceTargetNegocioId,
    applyPin: applyPin,
  );
}
