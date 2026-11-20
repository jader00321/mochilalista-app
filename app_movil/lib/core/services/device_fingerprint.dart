import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Generador de identificador único de dispositivo (DeviceFingerprint)
/// Produce una huella estable en formato ML-XXXX ligada al hardware real.
class DeviceFingerprint {
  static const MethodChannel _securityChannel =
      MethodChannel('com.mochilalista.app/device_security');
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _storageKey = 'ml_stable_device_id';

  static String? _overrideFingerprintForTesting;
  static String? _overrideLegacyFingerprintForTesting;
  static String? _overrideAppSigningSha1ForTesting;

  /// Permite establecer una huella simulada para pruebas unitarias
  @visibleForTesting
  static void setMockFingerprint(String? mock) {
    _overrideFingerprintForTesting = mock;
  }

  /// Permite establecer una huella simulada del método legado para pruebas unitarias
  @visibleForTesting
  static void setMockLegacyFingerprint(String? mock) {
    _overrideLegacyFingerprintForTesting = mock;
  }

  /// Permite establecer una huella SHA-1 de firma simulada para pruebas unitarias
  @visibleForTesting
  static void setMockAppSigningSha1(String? mock) {
    _overrideAppSigningSha1ForTesting = mock;
  }

  /// Deriva el formato oficial ML-XXXX a partir de un rawId usando la sal propietaria
  static String deriveFingerprintFromRawId(String rawId) {
    final bytes = utf8.encode('${rawId}_mochilalista_salt_2026_julio');
    final hash = sha256.convert(bytes).toString().toUpperCase();
    return 'ML-${hash.substring(0, 4)}';
  }

  /// Genera o recupera la huella digital criptográfica del dispositivo
  static Future<String> generate() async {
    if (_overrideFingerprintForTesting != null) {
      return _overrideFingerprintForTesting!;
    }

    try {
      // 1. Intentar recuperar huella estable previamente anclada en almacenamiento seguro
      try {
        final cached = await _storage.read(key: _storageKey);
        if (cached != null && cached.startsWith('ML-') && cached.length == 7) {
          return cached;
        }
      } catch (_) {
        // En entornos sin secure storage activo o fallback
      }

      String rawId;
      if (!kIsWeb && Platform.isAndroid) {
        // En Android: invocar canal nativo para Settings.Secure.ANDROID_ID
        try {
          final secureId = await _securityChannel.invokeMethod<String>('getSecureHardwareId');
          if (secureId != null && secureId.trim().isNotEmpty && secureId != 'generic_android_fallback') {
            rawId = secureId.trim();
          } else {
            // Fallback limpio a device_info_plus si el canal responde fallback
            final deviceInfo = DeviceInfoPlugin();
            final androidInfo = await deviceInfo.androidInfo;
            rawId = androidInfo.id;
          }
        } on MissingPluginException {
          // En pruebas o runners sin el plugin nativo registrado
          final deviceInfo = DeviceInfoPlugin();
          final androidInfo = await deviceInfo.androidInfo;
          rawId = androidInfo.id;
        } catch (_) {
          final deviceInfo = DeviceInfoPlugin();
          final androidInfo = await deviceInfo.androidInfo;
          rawId = androidInfo.id;
        }
      } else if (!kIsWeb && Platform.isWindows) {
        rawId = Platform.localHostname;
      } else {
        rawId = 'generic_device_env';
      }

      final fingerprint = deriveFingerprintFromRawId(rawId);

      // Anclar en FlutterSecureStorage para consistencia absoluta
      try {
        await _storage.write(key: _storageKey, value: fingerprint);
      } catch (_) {}

      return fingerprint;
    } catch (_) {
      return 'ML-GEN1';
    }
  }

  /// Genera la huella digital utilizando el método legado (basado en Build.ID)
  /// Utilizado para migración transparente de clientes con licencias ya activas.
  static Future<String> generateLegacy() async {
    if (_overrideLegacyFingerprintForTesting != null) {
      return _overrideLegacyFingerprintForTesting!;
    }

    try {
      String rawId;
      if (!kIsWeb && Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        rawId = androidInfo.id;
      } else if (!kIsWeb && Platform.isWindows) {
        rawId = Platform.localHostname;
      } else {
        rawId = 'generic_device_env';
      }

      return deriveFingerprintFromRawId(rawId);
    } catch (_) {
      return 'ML-GEN1';
    }
  }

  /// Verifica la integridad de la firma de la aplicación (Anti-Tampering)
  static Future<bool> verifyAppSignature() async {
    if (kIsWeb || !Platform.isAndroid) {
      return true;
    }

    try {
      final isValid = await _securityChannel.invokeMethod<bool>('verifyAppSignature');
      return isValid ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Lee la huella SHA-1 activa del certificado del APK instalado (formato con dos puntos AA:BB:...)
  static Future<String?> getAppSigningSha1() async {
    if (_overrideAppSigningSha1ForTesting != null) {
      return _overrideAppSigningSha1ForTesting;
    }
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }

    try {
      final sha1 = await _securityChannel.invokeMethod<String>('getAppSigningSha1');
      return sha1?.trim();
    } catch (_) {
      return null;
    }
  }
}
