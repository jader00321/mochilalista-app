import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Bóveda de seguridad para ofuscación y reconstrucción en memoria volátil
/// de secretos y claves criptográficas de MochilaLista.
class SecretVault {
  // Arreglo de bytes enmascarados con rotación XOR cíclica
  static const List<int> _maskedKey = [
    27, 244, 18, 130, 11, 174, 93, 190, 72, 171, 80, 184, 20, 253, 121, 161,
    9, 212, 118, 135, 5, 216, 65, 196, 77, 133, 65, 215, 38, 135, 93, 151,
    44, 221, 8, 162, 14, 226, 34, 151, 13, 141, 65, 245, 4, 227, 78, 164,
    119, 144, 113, 250, 30
  ];

  // Máscara pseudoaleatoria fija para rotación XOR
  static const List<int> _saltMask = [
    0x5A, 0xA5, 0x3C, 0xC3, 0x69, 0x96, 0x0F, 0xF0,
    0x7E, 0xE7, 0x18, 0x81, 0x4B, 0xB4, 0x2D, 0xD2
  ];

  @visibleForTesting
  static String? testKeyOverride;

  /// Reconstruye la clave de Google Gemini exclusivamente en memoria volátil
  /// en el instante en que es solicitada, sin residir en texto plano en el binario.
  static String getGeminiApiKey() {
    if (testKeyOverride != null) return testKeyOverride!;

    final bytes = List<int>.generate(
      _maskedKey.length,
      (i) => _maskedKey[i] ^ _saltMask[i % _saltMask.length],
    );
    return utf8.decode(bytes);
  }

  /// Enmascara una cadena utilizando la máscara interna de la bóveda
  static List<int> maskString(String input) {
    final bytes = utf8.encode(input);
    return List<int>.generate(
      bytes.length,
      (i) => bytes[i] ^ _saltMask[i % _saltMask.length],
    );
  }

  /// Desenmascara un arreglo de bytes utilizando la máscara interna de la bóveda
  static String unmaskBytes(List<int> masked) {
    final bytes = List<int>.generate(
      masked.length,
      (i) => masked[i] ^ _saltMask[i % _saltMask.length],
    );
    return utf8.decode(bytes);
  }
}
