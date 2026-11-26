import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' hide Hmac;
import 'package:cryptography/cryptography.dart';

/// Interfaz abstracta para la protección de datos a nivel de sistema operativo (Plan 10 - Sección 5.2).
abstract class DpapiService {
  bool get isSupported;
  Future<Uint8List?> protect(Uint8List data, {Uint8List? entropy});
  Future<Uint8List?> unprotect(Uint8List encryptedData, {Uint8List? entropy});
}

/// Implementación nativa de Windows DPAPI (Data Protection API).
/// Protege la VMK con el ámbito `DataProtectionScope.CurrentUser` vía stdin/stdout en PowerShell.
class WindowsDpapiService implements DpapiService {
  @override
  bool get isSupported => Platform.isWindows;

  @override
  Future<Uint8List?> protect(Uint8List data, {Uint8List? entropy}) async {
    if (!isSupported) return null;
    if (data.isEmpty) return Uint8List(0);

    try {
      const script =
          'Add-Type -AssemblyName System.Security; '
          r'$in = [Console]::In.ReadToEnd(); '
          'try { '
          r'  $j = $in | ConvertFrom-Json; '
          r'  $b = [Convert]::FromBase64String($j.d); '
          r'  $e = if ($j.e) { [Convert]::FromBase64String($j.e) } else { $null }; '
          r'  $p = [System.Security.Cryptography.ProtectedData]::Protect($b, $e, [System.Security.Cryptography.DataProtectionScope]::CurrentUser); '
          r'  [Console]::Out.Write([Convert]::ToBase64String($p)); '
          '} catch { exit 1 }';

      final process = await Process.start(
        'powershell.exe',
        ['-NoProfile', '-NonInteractive', '-Command', script],
      );

      final inputJson = jsonEncode({
        'd': base64Encode(data),
        'e': entropy != null ? base64Encode(entropy) : null,
      });

      process.stdin.write(inputJson);
      await process.stdin.close();

      final outFuture = process.stdout.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;
      if (exitCode != 0) return null;

      final outStr = (await outFuture).trim();
      if (outStr.isEmpty) return null;

      return Uint8List.fromList(base64Decode(outStr));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Uint8List?> unprotect(
    Uint8List encryptedData, {
    Uint8List? entropy,
  }) async {
    if (!isSupported) return null;
    if (encryptedData.isEmpty) return null;

    try {
      const script =
          'Add-Type -AssemblyName System.Security; '
          r'$in = [Console]::In.ReadToEnd(); '
          'try { '
          r'  $j = $in | ConvertFrom-Json; '
          r'  $b = [Convert]::FromBase64String($j.d); '
          r'  $e = if ($j.e) { [Convert]::FromBase64String($j.e) } else { $null }; '
          r'  $u = [System.Security.Cryptography.ProtectedData]::Unprotect($b, $e, [System.Security.Cryptography.DataProtectionScope]::CurrentUser); '
          r'  [Console]::Out.Write([Convert]::ToBase64String($u)); '
          '} catch { exit 1 }';

      final process = await Process.start(
        'powershell.exe',
        ['-NoProfile', '-NonInteractive', '-Command', script],
      );

      final inputJson = jsonEncode({
        'd': base64Encode(encryptedData),
        'e': entropy != null ? base64Encode(entropy) : null,
      });

      process.stdin.write(inputJson);
      await process.stdin.close();

      final outFuture = process.stdout.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;
      if (exitCode != 0) return null;

      final outStr = (await outFuture).trim();
      if (outStr.isEmpty) return null;

      return Uint8List.fromList(base64Decode(outStr));
    } catch (_) {
      return null;
    }
  }
}

/// Implementación simulada (Mock) de DPAPI para pruebas multiplataforma deterministas.
class MockDpapiService implements DpapiService {
  final String machineScopeId;

  MockDpapiService([this.machineScopeId = 'DEFAULT_PC']);

  @override
  bool get isSupported => true;

  @override
  Future<Uint8List?> protect(Uint8List data, {Uint8List? entropy}) async {
    if (data.isEmpty) return Uint8List(0);

    try {
      final scopeBytes = utf8.encode(machineScopeId);
      final keyBytes = sha256.convert([...scopeBytes, ...?entropy]).bytes;
      final algorithm = AesGcm.with256bits();
      final secretKey = SecretKey(keyBytes);
      final nonce = algorithm.newNonce();
      final box =
          await algorithm.encrypt(data, secretKey: secretKey, nonce: nonce);

      final prefix = utf8.encode('MOCKDPAPI:');
      final result = <int>[
        ...prefix,
        ...nonce,
        ...box.mac.bytes,
        ...box.cipherText,
      ];
      return Uint8List.fromList(result);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Uint8List?> unprotect(
    Uint8List encryptedData, {
    Uint8List? entropy,
  }) async {
    if (encryptedData.isEmpty) return null;

    try {
      final prefix = utf8.encode('MOCKDPAPI:');
      if (encryptedData.length < prefix.length + 12 + 16) return null;

      for (int i = 0; i < prefix.length; i++) {
        if (encryptedData[i] != prefix[i]) return null;
      }

      final nonce = encryptedData.sublist(prefix.length, prefix.length + 12);
      final mac = Mac(
        encryptedData.sublist(prefix.length + 12, prefix.length + 12 + 16),
      );
      final cipherText = encryptedData.sublist(prefix.length + 12 + 16);

      final scopeBytes = utf8.encode(machineScopeId);
      final keyBytes = sha256.convert([...scopeBytes, ...?entropy]).bytes;
      final algorithm = AesGcm.with256bits();
      final secretKey = SecretKey(keyBytes);

      final clear = await algorithm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: secretKey,
      );
      return Uint8List.fromList(clear);
    } catch (_) {
      return null;
    }
  }
}
