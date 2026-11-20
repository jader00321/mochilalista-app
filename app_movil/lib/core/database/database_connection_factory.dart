import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show databaseFactoryFfiNoIsolate;

/// Factoría de conexiones de base de datos con soporte dual:
/// - Windows / Linux / Tests: SQLite estándar vía FFI sin Isolate (databaseFactoryFfiNoIsolate)
/// - Android / Móvil físico: Conexión segura con clave de cifrado
class DatabaseConnectionFactory {
  /// Bandera para forzar modo de prueba o desarrollo desacoplado
  static bool isTestMode = false;

  /// Clave en secure storage para la base de datos cifrada en Android
  static const String secureStorageKey = 'db_encryption_key_v1';

  /// Determina si el entorno actual debe usar el motor FFI estándar (Windows, Linux, tests)
  static bool get shouldUseFfi {
    if (isTestMode || kIsWeb) return true;
    try {
      if (Platform.isWindows || Platform.isLinux) return true;
    } catch (_) {
      // Fallback a FFI si Platform no está disponible
      return true;
    }
    return false;
  }

  /// Abre la base de datos aplicando la dualidad:
  /// - En Windows/Linux/Test: databaseFactoryFfiNoIsolate (sin Isolate ni ReceivePort para evitar deadlocks en tests)
  /// - En Android/Dispositivo físico: sqflite estándar o cifrado
  static Future<Database> openSecureDatabase({
    required String path,
    required int version,
    String? encryptionPassword,
    OnDatabaseCreateFn? onCreate,
    OnDatabaseVersionChangeFn? onUpgrade,
    OnDatabaseConfigureFn? onConfigure,
  }) async {
    if (shouldUseFfi) {
      return await databaseFactoryFfiNoIsolate.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: version,
          onCreate: onCreate,
          onUpgrade: onUpgrade,
          onConfigure: onConfigure,
        ),
      );
    }

    // Entorno de dispositivo físico Android
    return await openDatabase(
      path,
      version: version,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
      onConfigure: onConfigure,
    );
  }
}
