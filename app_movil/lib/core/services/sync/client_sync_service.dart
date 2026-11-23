import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/google_drive_backup_provider.dart';
import 'package:app_movil/core/database/local_db.dart';

/// Servicio Criptográfico del Protocolo Dual de Sincronización Offline (.mlsync y MLS1-...)
/// en `app_movil/`.
///
/// Garantiza paridad criptográfica 1:1 con `mochilalista_admin/lib/client_sync_service.dart`.
/// Genera tokens compactos firmados con HMAC-SHA256 (16 bytes truncados en Base64URL sin '=').
///
/// REGLA INVIOLABLE DE PRIVACIDAD:
/// El payload está estrictamente limitado a 21 claves técnicas y operativas.
/// Jamás transmite nombres de clientes finales, precios de costo, montos de venta
/// ni datos comerciales confidenciales del comerciante (Ley N° 29733 de Perú).
class ClientSyncService {
  /// Clave pública fija compartida entre MochilaLista Admin y la App Móvil.
  static const String defaultHmacKey = 'MochilaLista-OfflineSync-v1-IntegrityKey-9f7c';

  /// Regex universal para identificar tokens MLS1-... incrustados en mensajes o portapapeles.
  static final RegExp tokenRegex = RegExp(r'MLS1-([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)');

  /// Lista blanca estricta de 21 claves permitidas en el payload de sincronización offline.
  static const Set<String> allowedWhitelistKeys = {
    'v',
    'hw',
    'bhw',
    'mod',
    'os',
    'av',
    'bc',
    'db',
    'pl',
    'st',
    'exp',
    'dr',
    'n',
    'ai',
    'aiu',
    'byok',
    'pc',
    'drv',
    'bh',
    'lb',
    'ts',
  };

  final String hmacKey;

  ClientSyncService({this.hmacKey = defaultHmacKey});

  /// Override para interceptar llamadas nativas a `SharePlus` en entornos de prueba.
  static Future<bool> Function(ShareParams params)? clientShareOverride;

  /// Override para información de hardware/OS en pruebas unitarias.
  static Map<String, String>? devicePlatformOverride;

  /// Override para directorio temporal en pruebas unitarias.
  static Directory? testTempDir;

  /// Override para conteo de perfiles comerciales en pruebas.
  static int? testPcOverride;

  /// Determina si el código se ejecuta bajo el arnés de pruebas de Flutter.
  static bool get isRunningInTest {
    try {
      final bindingName = WidgetsBinding.instance.runtimeType.toString();
      if (bindingName.contains('TestWidgetsFlutterBinding') ||
          bindingName.contains('AutomatedTestWidgetsFlutterBinding')) {
        return true;
      }
    } catch (_) {}
    return Platform.environment.containsKey('FLUTTER_TEST');
  }

  /// Filtra cualquier dato sensible que no pertenezca a la lista blanca de 21 claves.
  Map<String, dynamic> filterAllowedKeys(Map<String, dynamic> rawMap) {
    final clean = <String, dynamic>{};
    for (final key in allowedWhitelistKeys) {
      if (rawMap.containsKey(key)) {
        clean[key] = rawMap[key];
      }
    }
    return clean;
  }

  /// Genera un token firmado MLS1-... a partir del mapa de métricas operativas.
  String generateSyncToken(Map<String, dynamic> payload) {
    final cleanPayload = filterAllowedKeys(payload);

    // 1. Codificación canónica del JSON en Base64URL sin relleno '='
    final payloadJson = jsonEncode(cleanPayload);
    final payloadBytes = utf8.encode(payloadJson);
    final payloadB64 = base64Url.encode(payloadBytes).replaceAll('=', '');

    // 2. Firma HMAC-SHA256 sobre payloadB64
    final hmac = Hmac(sha256, utf8.encode(hmacKey));
    final digest = hmac.convert(utf8.encode(payloadB64)).bytes;

    // 3. Primeros 16 bytes como tag de autenticidad en Base64URL sin '='
    final tagBytes = digest.sublist(0, 16);
    final tagB64 = base64Url.encode(tagBytes).replaceAll('=', '');

    return 'MLS1-$payloadB64.$tagB64';
  }

  /// Genera la estructura oficial del archivo .mlsync (formato MLSYNC_V1).
  Map<String, dynamic> generateMlsyncFileContent(Map<String, dynamic> payload) {
    final cleanPayload = filterAllowedKeys(payload);
    final token = generateSyncToken(cleanPayload);
    final tsEpoch = cleanPayload['ts'] as int? ?? DateTime.now().millisecondsSinceEpoch;
    final generatedAt = DateTime.fromMillisecondsSinceEpoch(tsEpoch, isUtc: true).toIso8601String();

    return {
      'format': 'MLSYNC_V1',
      'token': token,
      'hardware_id': cleanPayload['hw'] ?? '',
      'generated_at': generatedAt,
      'summary': {
        'app_version': cleanPayload['av'],
        'ai_balance': cleanPayload['ai'],
        'status': cleanPayload['st'],
        'device_model': cleanPayload['mod'],
        'backup_health': cleanPayload['bh'],
      },
    };
  }

  /// Genera un archivo temporal `.mlsync` listo para ser compartido mediante el selector del SO.
  Future<File> createMlsyncTempFile(
    Map<String, dynamic> payload, {
    Directory? targetDir,
  }) async {
    final content = generateMlsyncFileContent(payload);
    Directory dir;
    if (targetDir != null) {
      dir = targetDir;
    } else if (testTempDir != null) {
      dir = testTempDir!;
    } else if (isRunningInTest) {
      dir = Directory.systemTemp;
    } else {
      try {
        dir = await getTemporaryDirectory();
      } catch (_) {
        dir = Directory.systemTemp;
      }
    }
    final rawHw = payload['hw'] as String? ?? 'DISP';
    final safeHw = rawHw.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final file = File('${dir.path}/Estado_MochilaLista_$safeHw.mlsync');
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(content));
    return file;
  }

  /// Comparte un archivo `.mlsync` a través de `share_plus` abriendo el menú nativo del sistema.
  Future<bool> shareMlsyncFile(
    File file, {
    String? hardwareId,
    Future<bool> Function(ShareParams params)? shareOverride,
  }) async {
    final hw = hardwareId ?? 'MochilaLista';
    final params = ShareParams(
      files: [XFile(file.path)],
      text: 'Ficha de Sincronización MochilaLista ($hw)',
      subject: 'Estado MochilaLista $hw',
    );

    if (shareOverride != null) {
      return await shareOverride(params);
    }
    if (clientShareOverride != null) {
      return await clientShareOverride!(params);
    }

    try {
      final result = await SharePlus.instance.share(params);
      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (_) {
      return false;
    }
  }

  /// Anexa la referencia `Ref. soporte: MLS1-...` al mensaje de WhatsApp si no está presente.
  String appendSyncTokenToMessage(String message, String token) {
    if (messageContainsSyncToken(message)) {
      return message.replaceAll(tokenRegex, token);
    }
    final trimmed = message.trimRight();
    return '$trimmed\n\nRef. soporte: $token';
  }

  /// Remueve de manera limpia la referencia `Ref. soporte: MLS1-...` o cualquier token huérfano.
  String removeSyncTokenFromMessage(String message) {
    var cleaned = message.replaceAll(RegExp(r'\n*Ref\.\s*soporte:\s*MLS1-[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'), '');
    cleaned = cleaned.replaceAll(tokenRegex, '');
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return cleaned.trimRight();
  }

  /// Determina si un texto ya contiene un token `MLS1-...`.
  bool messageContainsSyncToken(String message) {
    return tokenRegex.hasMatch(message);
  }

  /// Construye el snapshot operativo del dispositivo con las 21 métricas permitidas.
  ///
  /// Admite parámetros opcionales `override*` para permitir pruebas unitarias
  /// 100% aisladas, deterministas e independientes de la plataforma.
  Future<Map<String, dynamic>> buildCurrentSnapshot({
    LicenseProvider? licenseProv,
    GoogleDriveBackupProvider? driveProv,
    String? overrideHw,
    String? overrideBhw,
    String? overrideMod,
    String? overrideOs,
    String? overrideAv,
    int? overrideBc,
    int? overrideDb,
    String? overridePl,
    String? overrideSt,
    String? overrideExp,
    int? overrideDr,
    int? overrideN,
    int? overrideAi,
    int? overrideAiu,
    bool? overrideByok,
    int? overridePc,
    bool? overrideDrv,
    String? overrideBh,
    String? overrideLb,
    int? overrideTs,
  }) async {
    // 1. Hardware ID actual
    final hw = overrideHw ?? licenseProv?.deviceFingerprint ?? 'ML-DISP';

    // 2. Hardware ID de origen en caso de migración (bhw)
    final bhw = overrideBhw ?? licenseProv?.license?.migratedFromDeviceId;

    // 3 y 4. Modelo y Versión de SO
    String mod = overrideMod ?? 'Dispositivo Móvil';
    String os = overrideOs ?? 'Android';

    if (overrideMod == null || overrideOs == null) {
      if (devicePlatformOverride != null) {
        mod = overrideMod ?? devicePlatformOverride!['mod'] ?? 'Dispositivo Móvil';
        os = overrideOs ?? devicePlatformOverride!['os'] ?? 'Android';
      } else {
        try {
          if (!kIsWeb && Platform.isAndroid) {
            final plugin = DeviceInfoPlugin();
            final androidInfo = await plugin.androidInfo;
            final brand = androidInfo.brand.trim();
            final model = androidInfo.model.trim();
            mod = overrideMod ?? (brand.isNotEmpty ? '$brand $model' : model);
            os = overrideOs ?? 'Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt})';
          } else if (!kIsWeb && Platform.isWindows) {
            mod = overrideMod ?? 'Windows PC';
            os = overrideOs ?? 'Windows';
          }
        } catch (_) {
          mod = overrideMod ?? 'Dispositivo Móvil';
          os = overrideOs ?? 'Android';
        }
      }
    }

    // 5 y 6. Versión de la App y Código de Build
    String av = overrideAv ?? OwnerLegalIdentity.currentAppVersion;
    int bc = overrideBc ?? 81;
    if (overrideBc == null) {
      final withBuild = OwnerLegalIdentity.currentAppVersionWithBuild;
      if (withBuild.contains('+')) {
        final parsed = int.tryParse(withBuild.split('+').last);
        if (parsed != null) bc = parsed;
      }
    }

    // 7. Esquema SQLite local (36)
    final db = overrideDb ?? 36;

    // 8, 9, 10, 11, 12, 13. Datos de Licencia
    final license = licenseProv?.license;
    final pl = overridePl ?? license?.tipoPlan ?? licenseProv?.currentPlanName ?? 'TRIAL';
    final st = overrideSt ??
        license?.estadoActual ??
        (licenseProv?.isPendingMigration == true ? 'PENDIENTE_MIGRACION' : 'ACTIVA');
    final exp = overrideExp ??
        license?.fechaExpiracion.toIso8601String() ??
        DateTime.now().add(const Duration(days: 30)).toIso8601String();
    final dr = overrideDr ?? licenseProv?.daysRemaining ?? license?.daysRemaining ?? 0;
    final n = overrideN ?? license?.ultimoNonce ?? 0;

    // 14, 15, 16. Cuotas de Inteligencia Artificial
    final ai = overrideAi ?? licenseProv?.remainingAiScans ?? license?.aiAccumulatedScans ?? 50;
    final aiu = overrideAiu ?? license?.aiScansUsedMonth ?? 0;
    final byok = overrideByok ?? licenseProv?.isUsingByokMode ?? license?.isUsingByokMode ?? false;

    // 17. Conteo de Perfiles Comerciales (pc)
    int pc = overridePc ?? testPcOverride ?? 1;
    if (overridePc == null && testPcOverride == null) {
      try {
        if (!isRunningInTest) {
          final database = await LocalDatabase.instance.database;
          final countResult = await database.rawQuery('SELECT COUNT(*) as count FROM negocios');
          if (countResult.isNotEmpty && countResult.first['count'] != null) {
            pc = (countResult.first['count'] as num).toInt();
            if (pc < 1) pc = 1;
          }
        }
      } catch (_) {
        pc = 1;
      }
    }

    // 18, 19, 20. Respaldo Google Drive
    final drv = overrideDrv ?? driveProv?.isConnected ?? false;
    String bh = overrideBh ?? 'NONE';
    if (overrideBh == null && driveProv != null) {
      bh = driveProv.healthInfo.status.name.toUpperCase();
    }

    String? lb = overrideLb;
    if (overrideLb == null && driveProv != null && driveProv.backups.isNotEmpty) {
      DateTime latest = driveProv.backups.first.createdAt;
      for (final b in driveProv.backups) {
        if (b.createdAt.isAfter(latest)) {
          latest = b.createdAt;
        }
      }
      lb = latest.toIso8601String();
    }

    // 21. Timestamp UTC del reporte
    final ts = overrideTs ?? DateTime.now().millisecondsSinceEpoch;

    final rawPayload = <String, dynamic>{
      'v': 1,
      'hw': hw,
      'bhw': bhw,
      'mod': mod,
      'os': os,
      'av': av,
      'bc': bc,
      'db': db,
      'pl': pl,
      'st': st,
      'exp': exp,
      'dr': dr,
      'n': n,
      'ai': ai,
      'aiu': aiu,
      'byok': byok,
      'pc': pc,
      'drv': drv,
      'bh': bh,
      'lb': lb,
      'ts': ts,
    };

    return filterAllowedKeys(rawPayload);
  }
}
