import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Motor criptográfico para cifrado y descifrado de archivos de respaldo (.mlbg)
/// Utiliza AES-256-GCM con autenticación criptográfica de integridad y
/// derivación de claves mediante PBKDF2-HMAC-SHA256 con sal aleatoria de 32 bytes.
class BackupCryptoHelper {
  /// Encabezado mágico para identificar copias cifradas oficiales (MLENC1)
  static const List<int> magicHeader = [0x4D, 0x4C, 0x45, 0x4E, 0x43, 0x31];

  /// Clave maestra interna de derivación cuando el usuario no asigna contraseña explícita
  static const String defaultMasterBackupKey = 'mochilalista_master_backup_vault_v1';

  /// Iteraciones estándar para derivación de clave de respaldo
  static int defaultPbkdf2Iterations = 10000;

  /// Sal fija oficial para derivación determinista de respaldos en Google Drive
  static const String driveVaultFixedSalt = "MochilaLista_DriveVault_v1_Salt";

  /// Iteraciones de PBKDF2 para respaldos en la nube de Google Drive (100,000 iteraciones en producción)
  static int drivePbkdf2Iterations = 100000;

  /// Deriva la clave de cifrado deterministamente para Google Drive a partir de googleUser.id
  /// y una sal fija oficial, combinada opcionalmente con una frase de recuperación personalizada.
  static String deriveDrivePassword({
    required String googleUserId,
    String? customPassphrase,
  }) {
    final cleanId = googleUserId.trim();
    if (customPassphrase != null && customPassphrase.trim().isNotEmpty) {
      return '${cleanId}_${customPassphrase.trim()}_$driveVaultFixedSalt';
    }
    return '${cleanId}_$driveVaultFixedSalt';
  }

  /// Detecta si el archivo es un archivo comprimido ZIP estándar sin cifrar (PK\x03\x04)
  static bool isLegacyZip(List<int> bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04;
  }

  /// Detecta si el archivo cuenta con la cabecera mágica de cifrado MLENC1
  static bool isEncryptedBackup(List<int> bytes) {
    if (bytes.length < magicHeader.length) return false;
    for (int i = 0; i < magicHeader.length; i++) {
      if (bytes[i] != magicHeader[i]) return false;
    }
    return true;
  }

  /// Cifra el arreglo de bytes usando AES-256-GCM y PBKDF2-HMAC-SHA256
  static Future<Uint8List> encryptBackupPayload(
    List<int> plainBytes, {
    String? password,
    int? pbkdf2Iterations,
  }) async {
    final actualPassword = (password != null && password.trim().isNotEmpty)
        ? password.trim()
        : defaultMasterBackupKey;
    final iter = pbkdf2Iterations ?? defaultPbkdf2Iterations;

    // Generar sal criptográfica única de 32 bytes
    final random = Random.secure();
    final salt = List<int>.generate(32, (_) => random.nextInt(256));

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iter,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(actualPassword)),
      nonce: salt,
    );

    final algorithm = AesGcm.with256bits();
    final secretBox = await algorithm.encrypt(
      plainBytes,
      secretKey: secretKey,
    );

    final payloadWithNonceAndMac = secretBox.concatenation(nonce: true, mac: true);

    final builder = BytesBuilder(copy: false);
    builder.add(magicHeader); // 6 bytes
    builder.add(salt);        // 32 bytes
    builder.add(payloadWithNonceAndMac); // 12 bytes nonce + ciphertext + 16 bytes MAC
    return builder.toBytes();
  }

  /// Descifra el arreglo de bytes si cuenta con cabecera MLENC1, o lo devuelve intacto si es ZIP legado
  static Future<Uint8List> decryptBackupPayload(
    List<int> bytes, {
    String? password,
    int? pbkdf2Iterations,
  }) async {
    // 1. Compatibilidad retroactiva absoluta con copias legacy ZIP sin cifrar
    if (isLegacyZip(bytes)) {
      return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    }

    if (!isEncryptedBackup(bytes)) {
      throw Exception("El archivo no tiene un formato de respaldo reconocido (MLENC1 o ZIP).");
    }

    const minSize = 6 + 32 + 12 + 16;
    if (bytes.length < minSize) {
      throw Exception("El archivo de respaldo está incompleto o dañado.");
    }

    final salt = bytes.sublist(6, 38);
    final encryptedData = bytes.sublist(38);

    final iter = pbkdf2Iterations ?? defaultPbkdf2Iterations;
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iter,
      bits: 256,
    );
    final algorithm = AesGcm.with256bits();

    // Intentar con la contraseña provista y con la clave maestra por defecto
    final passwordsToTry = <String>[];
    if (password != null && password.trim().isNotEmpty) {
      passwordsToTry.add(password.trim());
    }
    if (!passwordsToTry.contains(defaultMasterBackupKey)) {
      passwordsToTry.add(defaultMasterBackupKey);
    }

    for (final pwd in passwordsToTry) {
      try {
        final secretKey = await pbkdf2.deriveKey(
          secretKey: SecretKey(utf8.encode(pwd)),
          nonce: salt,
        );

        final secretBox = SecretBox.fromConcatenation(
          encryptedData,
          nonceLength: 12,
          macLength: 16,
        );

        final decrypted = await algorithm.decrypt(
          secretBox,
          secretKey: secretKey,
        );
        return Uint8List.fromList(decrypted);
      } catch (_) {
        // Continuar intentando con la siguiente clave
      }
    }

    throw Exception("Contraseña incorrecta o archivo de respaldo dañado.");
  }
}
