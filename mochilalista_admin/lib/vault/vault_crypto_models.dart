import 'dart:typed_data';

/// Excepciones formales del subsistema de Bóveda y Criptografía (Plan 10).
class VaultException implements Exception {
  final String message;
  VaultException(this.message);
  @override
  String toString() => 'VaultException: $message';
}

class VaultAuthException extends VaultException {
  VaultAuthException(super.message);
}

class VaultIntegrityException extends VaultException {
  VaultIntegrityException(super.message);
}

class VaultFormatException extends VaultException {
  VaultFormatException(super.message);
}

/// Modelo de Llavero Maestro (Formato MLKEYRING v1.1.0).
/// Custodia la VMK envuelta en las 4 ranuras independientes (jamás en texto plano).
class VaultKeyring {
  final String format;
  final String version;
  DateTime updatedAt;
  final Map<String, dynamic> keySlots;

  VaultKeyring({
    this.format = 'MLKEYRING',
    this.version = '1.1.0',
    DateTime? updatedAt,
    required this.keySlots,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc();

  Map<String, dynamic> toJson() => {
        'format': format,
        'version': version,
        'updated_at': updatedAt.toIso8601String(),
        'key_slots': keySlots,
      };

  factory VaultKeyring.fromJson(Map<String, dynamic> json) {
    if (json['format'] != 'MLKEYRING' && json['format'] != 'MLVAULT') {
      throw VaultFormatException(
        'Formato de llavero inválido: esperado MLKEYRING o MLVAULT',
      );
    }
    return VaultKeyring(
      format: 'MLKEYRING',
      version: json['version'] as String? ?? '1.1.0',
      updatedAt: DateTime.tryParse(
            json['updated_at'] as String? ??
                json['created_at'] as String? ??
                '',
          ) ??
          DateTime.now().toUtc(),
      keySlots: Map<String, dynamic>.from(json['key_slots'] as Map? ?? {}),
    );
  }
}

/// Resultado de inicialización del llavero que entrega la VMK temporalmente en memoria.
class KeyringCreationResult {
  final VaultKeyring keyring;
  final Uint8List vmk;
  KeyringCreationResult({required this.keyring, required this.vmk});
}

/// Resultado de generación del Kit de Emergencia Imprimible.
class RescueKitResult {
  final List<String> codes;
  final String qrKey;
  RescueKitResult({required this.codes, required this.qrKey});
}

/// Contenedor de archivos de producción a empaquetar en una bóveda.
class VaultPayloadFiles {
  final String clientsJson;
  final String releasesJson;
  final String configJson;
  final String? masterKeyEd25519;

  VaultPayloadFiles({
    required this.clientsJson,
    required this.releasesJson,
    required this.configJson,
    this.masterKeyEd25519,
  });
}

/// Tipos de credenciales para desbloquear una bóveda.
enum VaultUnlockType { dpapi, mlKey, rescueCode, qrKey, pin }

/// Credencial de desbloqueo provista para importar o abrir una bóveda.
class VaultUnlockCredential {
  final VaultUnlockType type;
  final String? secret;

  VaultUnlockCredential.dpapi()
      : type = VaultUnlockType.dpapi,
        secret = null;

  VaultUnlockCredential.mlKey(String mlKey)
      : type = VaultUnlockType.mlKey,
        secret = mlKey;

  VaultUnlockCredential.rescueCode(String code)
      : type = VaultUnlockType.rescueCode,
        secret = code;

  VaultUnlockCredential.qrKey(String qr)
      : type = VaultUnlockType.qrKey,
        secret = qr;

  VaultUnlockCredential.pin(String pin)
      : type = VaultUnlockType.pin,
        secret = pin;
}

/// Resultado del desempaque e importación exitosa de una bóveda.
class VaultImportResult {
  final VaultPayloadFiles files;
  final VaultKeyring keyring;
  final Uint8List vmk;
  final Map<String, dynamic> internalManifest;

  VaultImportResult({
    required this.files,
    required this.keyring,
    required this.vmk,
    required this.internalManifest,
  });
}
