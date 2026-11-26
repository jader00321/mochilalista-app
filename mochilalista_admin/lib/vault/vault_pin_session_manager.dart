import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'dpapi_service.dart';
import 'vault_crypto_service.dart';

/// Gestor de sesiones PIN locales (Slot 4), backoff anti-fuerza bruta y recuperación.
class VaultPinSessionManager {
  int _failedPinAttempts = 0;
  DateTime? _pinLockedUntil;
  final Set<String> _validSessionTokens = {};

  bool isPinEnabled(VaultKeyring? keyring) {
    return keyring?.keySlots['slot_4_pin']?['enabled'] == true;
  }

  bool isSessionValid(VaultKeyring? keyring, String? token) {
    if (!isPinEnabled(keyring)) return true;
    return token != null && _validSessionTokens.contains(token);
  }

  /// Revoca el token de sesión suministrado o todos si [token] es `null`.
  void revokeSession(String? token) {
    if (token != null) {
      _validSessionTokens.remove(token);
    } else {
      _validSessionTokens.clear();
    }
  }

  String _generateSessionToken() {
    final rand = Random.secure();
    final bytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      bytes[i] = rand.nextInt(256);
    }
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Future<Map<String, dynamic>> configurePin({
    required VaultKeyring keyring,
    required Uint8List vmk,
    required String? pin,
    required bool enabled,
    required Future<void> Function() persistAndSync,
  }) async {
    if (!enabled) {
      keyring.keySlots['slot_4_pin'] = {
        'type': 'PIN_OPTIONAL',
        'enabled': false,
        'wrapped_vmk_b64': null,
      };
      keyring.updatedAt = DateTime.now().toUtc();
      await persistAndSync();
      revokeSession(null);
      return {
        'ok': true,
        'pin_enabled': false,
        'message': 'PIN local desactivado exitosamente.',
      };
    }

    if (pin == null || pin.trim().length < 4) {
      throw VaultFormatException(
        'El PIN debe tener al menos 4 dígitos o caracteres.',
      );
    }
    await VaultCryptoService.enrollPinSlot(keyring, vmk, pin.trim());
    await persistAndSync();

    _failedPinAttempts = 0;
    _pinLockedUntil = null;
    final token = _generateSessionToken();
    _validSessionTokens.add(token);

    return {
      'ok': true,
      'pin_enabled': true,
      'token': token,
      'session_token': token,
      'expires_in': 86400,
      'message': 'PIN local activado exitosamente.',
    };
  }

  Future<Map<String, dynamic>> verifyPin({
    required VaultKeyring? keyring,
    required String pin,
    required void Function(Uint8List vmk) onVmkUnlocked,
  }) async {
    if (_pinLockedUntil != null && DateTime.now().isBefore(_pinLockedUntil!)) {
      final waitSec = _pinLockedUntil!.difference(DateTime.now()).inSeconds + 1;
      throw VaultAuthException(
        'Demasiados intentos fallidos. Bóveda bloqueada por $waitSec segundos.',
      );
    }

    if (keyring == null) {
      throw VaultAuthException('Llavero no cargado.');
    }

    final vmk = await VaultCryptoService.unwrapVmkWithPin(keyring, pin.trim());
    if (vmk == null) {
      _failedPinAttempts++;
      if (_failedPinAttempts >= 5) {
        int delaySeconds = 2;
        if (_failedPinAttempts == 6) {
          delaySeconds = 4;
        } else if (_failedPinAttempts == 7) {
          delaySeconds = 8;
        } else if (_failedPinAttempts == 8) {
          delaySeconds = 16;
        } else if (_failedPinAttempts >= 9) {
          delaySeconds = 30;
        }
        _pinLockedUntil = DateTime.now().add(Duration(seconds: delaySeconds));
      }
      throw VaultAuthException(
        'PIN incorrecto. Intento #$_failedPinAttempts.',
      );
    }

    _failedPinAttempts = 0;
    _pinLockedUntil = null;
    onVmkUnlocked(vmk);

    final token = _generateSessionToken();
    _validSessionTokens.add(token);

    return {
      'success': true,
      'ok': true,
      'token': token,
      'session_token': token,
      'expires_in': 86400,
    };
  }

  Future<Map<String, dynamic>> recoverPin({
    required VaultKeyring? keyring,
    required DpapiService dpapiService,
    required VaultUnlockCredential credential,
    String? newPin,
    bool disablePin = false,
    required void Function(Uint8List vmk) onVmkUnlocked,
    required Future<void> Function() persistAndSync,
  }) async {
    if (keyring == null) {
      throw VaultAuthException('Llavero no cargado.');
    }

    Uint8List? vmk;
    switch (credential.type) {
      case VaultUnlockType.dpapi:
        vmk =
            await VaultCryptoService.unwrapVmkWithDpapi(keyring, dpapiService);
        break;
      case VaultUnlockType.mlKey:
        if (credential.secret == null) {
          throw VaultAuthException('Se requiere el archivo .mlkey.');
        }
        vmk = await VaultCryptoService.unwrapVmkWithMlKey(
          keyring,
          credential.secret!,
        );
        break;
      case VaultUnlockType.rescueCode:
        if (credential.secret == null) {
          throw VaultAuthException('Se requiere el Código de Rescate.');
        }
        vmk = await VaultCryptoService.unwrapVmkWithRescueCode(
          keyring,
          credential.secret!,
        );
        break;
      case VaultUnlockType.qrKey:
        if (credential.secret == null) {
          throw VaultAuthException('Se requiere la clave QR.');
        }
        vmk = await VaultCryptoService.unwrapVmkWithQrKey(
          keyring,
          credential.secret!,
        );
        break;
      default:
        throw VaultAuthException(
          'Tipo de factor no soportado para recuperación de PIN.',
        );
    }

    if (vmk == null) {
      throw VaultAuthException(
        'El factor de recuperación suministrado fue rechazado.',
      );
    }

    onVmkUnlocked(vmk);
    _failedPinAttempts = 0;
    _pinLockedUntil = null;

    if (disablePin) {
      keyring.keySlots['slot_4_pin'] = {
        'type': 'PIN_OPTIONAL',
        'enabled': false,
        'wrapped_vmk_b64': null,
      };
      keyring.updatedAt = DateTime.now().toUtc();
    } else if (newPin != null && newPin.trim().isNotEmpty) {
      if (newPin.trim().length < 4) {
        throw VaultFormatException(
          'El nuevo PIN debe tener al menos 4 caracteres.',
        );
      }
      await VaultCryptoService.enrollPinSlot(keyring, vmk, newPin.trim());
    }

    await persistAndSync();

    final token = _generateSessionToken();
    _validSessionTokens.add(token);

    return {
      'success': true,
      'ok': true,
      'token': token,
      'session_token': token,
      'pin_enabled': isPinEnabled(keyring),
    };
  }
}
