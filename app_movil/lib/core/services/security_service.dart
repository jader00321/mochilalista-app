import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Servicio de seguridad criptográfica para autenticación de usuario (PIN)
/// Implementa derivación robusta PBKDF2-HMAC-SHA256, sal única de 32 bytes,
/// comparación en tiempo constante y rate limiting progresivo anti fuerza bruta.
class SecurityService {
  final FlutterSecureStorage _storage;

  /// Cantidad de iteraciones PBKDF2 oficiales (configurable para tests veloces)
  static int defaultIterations = 100000;

  SecurityService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Comparación en tiempo constante para mitigar ataques de temporización (Timing Attacks)
  static bool constantTimeEquals(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);
    if (aBytes.length != bBytes.length) return false;
    int diff = 0;
    for (int i = 0; i < aBytes.length; i++) {
      diff |= aBytes[i] ^ bBytes[i];
    }
    return diff == 0;
  }

  /// Genera una sal criptográfica pseudoaleatoria segura de 32 bytes
  static List<int> generateSalt([int length = 32]) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  /// Genera el hash PBKDF2-HMAC-SHA256 a partir de un PIN y una sal
  static Future<String> hashPin(
    String pin,
    List<int> saltBytes, {
    int? iterations,
  }) async {
    final iter = iterations ?? defaultIterations;
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iter,
      bits: 256,
    );
    final secretKey = SecretKey(utf8.encode(pin));
    final derivedKey = await pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: saltBytes,
    );
    final hashBytes = await derivedKey.extractBytes();
    return base64Encode(hashBytes);
  }

  /// Comprueba si el usuario tiene configurado un PIN (formato PBKDF2 o legado)
  Future<bool> hasPin(int userId) async {
    final hash = await _storage.read(key: 'pin_hash_$userId');
    if (hash != null && hash.isNotEmpty) return true;
    final legacy = await _storage.read(key: 'pin_$userId');
    return legacy != null && legacy.isNotEmpty;
  }

  /// Establece un nuevo PIN derivándolo con PBKDF2 y una sal de 32 bytes recién generada
  Future<void> setPin(int userId, String pin, {int? iterations}) async {
    if (pin.isEmpty) {
      await removePin(userId);
      return;
    }

    final saltBytes = generateSalt(32);
    final hash = await hashPin(pin, saltBytes, iterations: iterations);

    await _storage.write(key: 'pin_hash_$userId', value: hash);
    await _storage.write(key: 'pin_salt_$userId', value: base64Encode(saltBytes));
    await _storage.delete(key: 'pin_$userId'); // Elimina cualquier remanente en claro
    await resetFailedAttempts(userId);
  }

  /// Elimina por completo el PIN del usuario y limpia bloqueos
  Future<void> removePin(int userId) async {
    await _storage.delete(key: 'pin_hash_$userId');
    await _storage.delete(key: 'pin_salt_$userId');
    await _storage.delete(key: 'pin_$userId');
    await resetFailedAttempts(userId);
  }

  /// Verifica si el usuario está actualmente bloqueado por exceso de intentos erróneos
  Future<bool> isLockedOut(int userId) async {
    final remaining = await getRemainingLockoutSeconds(userId);
    return remaining > 0;
  }

  /// Retorna los segundos restantes de bloqueo o 0 si no está bloqueado
  Future<int> getRemainingLockoutSeconds(int userId) async {
    final lockoutStr = await _storage.read(key: 'pin_lockout_until_ms_$userId');
    if (lockoutStr == null) return 0;
    final lockoutMs = int.tryParse(lockoutStr);
    if (lockoutMs == null) return 0;

    final diffMs = lockoutMs - DateTime.now().millisecondsSinceEpoch;
    if (diffMs <= 0) {
      await _storage.delete(key: 'pin_lockout_until_ms_$userId');
      return 0;
    }
    return (diffMs / 1000).ceil();
  }

  /// Retorna la cantidad de intentos fallidos consecutivos registrados
  Future<int> getFailedAttempts(int userId) async {
    final attemptsStr = await _storage.read(key: 'pin_failed_attempts_$userId');
    if (attemptsStr == null) return 0;
    return int.tryParse(attemptsStr) ?? 0;
  }

  /// Registra un intento fallido y aplica bloqueo progresivo (MED-02):
  /// - 3 intentos: 30 segundos
  /// - 5 intentos: 300 segundos (5 minutos)
  /// - 10+ intentos: 900 segundos (15 minutos)
  Future<int> registerFailedAttempt(int userId) async {
    final currentAttempts = (await getFailedAttempts(userId)) + 1;
    int lockoutDurationSeconds = 0;

    if (currentAttempts >= 10) {
      lockoutDurationSeconds = 900;
    } else if (currentAttempts >= 5) {
      lockoutDurationSeconds = 300;
    } else if (currentAttempts >= 3) {
      lockoutDurationSeconds = 30;
    }

    await _storage.write(
      key: 'pin_failed_attempts_$userId',
      value: currentAttempts.toString(),
    );

    if (lockoutDurationSeconds > 0) {
      final lockoutUntilMs =
          DateTime.now().millisecondsSinceEpoch + (lockoutDurationSeconds * 1000);
      await _storage.write(
        key: 'pin_lockout_until_ms_$userId',
        value: lockoutUntilMs.toString(),
      );
    }

    return lockoutDurationSeconds;
  }

  /// Reinicia los intentos fallidos a 0 y borra cualquier bloqueo activo
  Future<void> resetFailedAttempts(int userId) async {
    await _storage.delete(key: 'pin_failed_attempts_$userId');
    await _storage.delete(key: 'pin_lockout_until_ms_$userId');
  }

  /// Verifica el PIN ingresado con soporte para:
  /// 1. Verificación de Rate Limiting (falla de inmediato si está bloqueado)
  /// 2. Hash PBKDF2-HMAC-SHA256 con sal única y comparación en tiempo constante
  /// 3. Migración transparente de PIN plano anterior (cero fricción para el usuario)
  /// 4. Reinicio automático de intentos al ingresar el PIN correcto
  Future<bool> verifyPin(int userId, String enteredPin, {int? iterations}) async {
    if (await isLockedOut(userId)) {
      return false;
    }

    final storedHash = await _storage.read(key: 'pin_hash_$userId');
    final storedSaltBase64 = await _storage.read(key: 'pin_salt_$userId');

    if (storedHash != null && storedSaltBase64 != null) {
      final saltBytes = base64Decode(storedSaltBase64);
      final calculatedHash = await hashPin(enteredPin, saltBytes, iterations: iterations);

      final matches = constantTimeEquals(calculatedHash, storedHash);
      if (matches) {
        await resetFailedAttempts(userId);
        return true;
      } else {
        await registerFailedAttempt(userId);
        return false;
      }
    }

    // Compatibilidad retroactiva: Migración transparente desde texto plano
    final legacyPin = await _storage.read(key: 'pin_$userId');
    if (legacyPin == null || legacyPin.isEmpty) {
      return enteredPin.isEmpty;
    }

    final legacyMatches = constantTimeEquals(enteredPin, legacyPin);
    if (legacyMatches) {
      // Migración silenciosa inmediata a PBKDF2 con sal criptográfica
      final saltBytes = generateSalt(32);
      final newHash = await hashPin(enteredPin, saltBytes, iterations: iterations);

      await _storage.write(key: 'pin_hash_$userId', value: newHash);
      await _storage.write(key: 'pin_salt_$userId', value: base64Encode(saltBytes));
      await _storage.delete(key: 'pin_$userId');

      await resetFailedAttempts(userId);
      return true;
    } else {
      await registerFailedAttempt(userId);
      return false;
    }
  }
}
