import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/core/models/ai_key_model.dart';
import 'package:app_movil/core/config/api_constants.dart';
import 'package:app_movil/core/utils/app_logger.dart';

/// Resultado estructurado de la prueba de conectividad de una API Key
class AiKeyTestResult {
  final bool isSuccess;
  final int? statusCode;
  final String message;

  const AiKeyTestResult({
    required this.isSuccess,
    this.statusCode,
    required this.message,
  });
}

/// Servicio Bóveda Segura Multi-Clave BYOK para Google AI Studio (Gemini)
/// Almacena las claves encriptadas en FlutterSecureStorage y gestiona la clave activa.
class AiVaultService {
  static final AiVaultService instance = AiVaultService();

  final FlutterSecureStorage _secureStorage;

  static const String vaultStorageKey = 'mochilalista_ai_vault_keys';
  static const String activeKeyIdStorageKey = 'mochilalista_active_byok_key_id';
  static const String legacySharedPreferencesKey = 'user_custom_gemini_api_key';

  AiVaultService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Inicializa la bóveda y ejecuta migración transparente si detecta una clave plana heredada en SharedPreferences
  Future<void> initialize({SharedPreferences? customPrefs}) async {
    try {
      final keys = await getKeys();

      // Si la bóveda está vacía, verificamos si existe una clave heredada en texto plano
      if (keys.isEmpty) {
        final prefs = customPrefs ?? await SharedPreferences.getInstance();
        final legacyKey = prefs.getString(legacySharedPreferencesKey);

        if (legacyKey != null && legacyKey.trim().isNotEmpty) {
          final cleanKey = legacyKey.trim();
          final migratedId = 'byok_migrated_${DateTime.now().millisecondsSinceEpoch}';

          final migratedModel = AiKeyModel(
            id: migratedId,
            alias: 'Mi Clave Gemini (Migrada)',
            apiKey: cleanKey,
            createdAt: DateTime.now(),
          );

          await _saveKeysToStorage([migratedModel]);
          await _secureStorage.write(key: activeKeyIdStorageKey, value: migratedId);

          // 🛡️ Destrucción inmediata del rastro en texto plano
          await prefs.remove(legacySharedPreferencesKey);
          AppLogger.i('AiVaultService', 'Clave plana heredada migrada con éxito a FlutterSecureStorage y destruida de SharedPreferences.');
        }
      }

      // Sincronizar ApiConstants con la clave activa de la bóveda
      final active = await getActiveKey();
      ApiConstants.setCustomApiKeyFromVault(active?.apiKey);
    } catch (e) {
      AppLogger.w('AiVaultService', 'Advertencia inicializando AiVaultService: $e');
    }
  }

  /// Obtiene la lista completa de claves registradas en la bóveda
  Future<List<AiKeyModel>> getKeys() async {
    try {
      final rawJson = await _secureStorage.read(key: vaultStorageKey);
      if (rawJson == null || rawJson.trim().isEmpty) return [];

      final decoded = jsonDecode(rawJson) as List<dynamic>;
      return decoded
          .map((item) => AiKeyModel.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.w('AiVaultService', 'Error leyendo claves de la bóveda: $e');
      return [];
    }
  }

  /// Retorna el ID de la clave activa seleccionada actualmente
  Future<String?> getActiveKeyId() async {
    try {
      return await _secureStorage.read(key: activeKeyIdStorageKey);
    } catch (_) {
      return null;
    }
  }

  /// Retorna el modelo de la clave activa seleccionada (o null si no hay ninguna)
  Future<AiKeyModel?> getActiveKey() async {
    final keys = await getKeys();
    if (keys.isEmpty) return null;

    final activeId = await getActiveKeyId();
    if (activeId == null) {
      return keys.first;
    }

    try {
      return keys.firstWhere((k) => k.id == activeId);
    } catch (_) {
      return keys.first;
    }
  }

  /// Agrega una nueva clave con alias obligatorio a la bóveda
  Future<AiKeyModel> addKey({
    required String alias,
    required String apiKey,
  }) async {
    final cleanAlias = alias.trim();
    final cleanKey = apiKey.trim();

    if (cleanAlias.isEmpty) {
      throw Exception("El alias o nombre de la clave es obligatorio (ej. 'Gmail Principal').");
    }
    if (cleanKey.isEmpty) {
      throw Exception("La API Key de Google AI Studio es obligatoria.");
    }

    final keys = await getKeys();
    final newId = 'byok_${DateTime.now().microsecondsSinceEpoch}';

    final newModel = AiKeyModel(
      id: newId,
      alias: cleanAlias,
      apiKey: cleanKey,
      createdAt: DateTime.now(),
    );

    keys.add(newModel);
    await _saveKeysToStorage(keys);

    // Si es la primera clave o no hay activa, marcarla como activa automáticamente
    final currentActiveId = await getActiveKeyId();
    if (currentActiveId == null || keys.length == 1) {
      await _secureStorage.write(key: activeKeyIdStorageKey, value: newId);
      ApiConstants.setCustomApiKeyFromVault(cleanKey);
    }

    AppLogger.i('AiVaultService', 'Clave BYOK añadida a la bóveda con alias: $cleanAlias');
    return newModel;
  }

  /// Define una clave como la clave activa para escaneos BYOK
  Future<void> setActiveKey(String id) async {
    final keys = await getKeys();
    final match = keys.where((k) => k.id == id).toList();

    if (match.isEmpty) {
      throw Exception("La clave solicitada no existe en la bóveda.");
    }

    await _secureStorage.write(key: activeKeyIdStorageKey, value: id);
    ApiConstants.setCustomApiKeyFromVault(match.first.apiKey);
    AppLogger.i('AiVaultService', 'Clave activa cambiada a: ${match.first.alias}');
  }

  /// Modifica el alias de una clave existente
  Future<void> updateAlias(String id, String newAlias) async {
    final cleanAlias = newAlias.trim();
    if (cleanAlias.isEmpty) {
      throw Exception("El alias no puede estar vacío.");
    }

    final keys = await getKeys();
    final index = keys.indexWhere((k) => k.id == id);
    if (index == -1) {
      throw Exception("Clave no encontrada.");
    }

    keys[index] = keys[index].copyWith(alias: cleanAlias);
    await _saveKeysToStorage(keys);
    AppLogger.i('AiVaultService', 'Alias actualizado para clave $id: $cleanAlias');
  }

  /// Elimina una clave de la bóveda
  Future<void> deleteKey(String id) async {
    final keys = await getKeys();
    final currentActiveId = await getActiveKeyId();

    keys.removeWhere((k) => k.id == id);
    await _saveKeysToStorage(keys);

    if (currentActiveId == id) {
      if (keys.isNotEmpty) {
        final newActiveId = keys.first.id;
        await _secureStorage.write(key: activeKeyIdStorageKey, value: newActiveId);
        ApiConstants.setCustomApiKeyFromVault(keys.first.apiKey);
      } else {
        await _secureStorage.delete(key: activeKeyIdStorageKey);
        ApiConstants.setCustomApiKeyFromVault(null);
      }
    }

    AppLogger.i('AiVaultService', 'Clave eliminada de la bóveda: $id');
  }

  /// Verificación Real Inmune a Obsolescencia:
  /// Consulta strictly `GET https://generativelanguage.googleapis.com/v1beta/models?pageSize=1&key=$apiKey`
  /// con timeout de 6 segundos. Consumo de 0 tokens y sin depender de nombres de modelos específicos.
  Future<AiKeyTestResult> testApiKey(String apiKey, {http.Client? httpClient}) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      return const AiKeyTestResult(
        isSuccess: false,
        message: "La clave ingresada está vacía.",
      );
    }

    final client = httpClient ?? http.Client();
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?pageSize=1&key=$cleanKey');

    try {
      final response = await client.get(url).timeout(const Duration(seconds: 6));
      final isSuccess = response.statusCode == 200;

      // Actualizar estado en la bóveda si la clave está registrada
      await _updateTestState(cleanKey, isSuccess);

      if (isSuccess) {
        return const AiKeyTestResult(
          isSuccess: true,
          statusCode: 200,
          message: "Clave verificada con éxito. Conexión correcta con Google AI Studio.",
        );
      } else if (response.statusCode == 400 || response.statusCode == 403) {
        return AiKeyTestResult(
          isSuccess: false,
          statusCode: response.statusCode,
          message: "Clave inválida o revocada por Google (Código ${response.statusCode}).",
        );
      } else {
        return AiKeyTestResult(
          isSuccess: false,
          statusCode: response.statusCode,
          message: "Respuesta inesperada de Google AI Studio (Código ${response.statusCode}).",
        );
      }
    } on SocketException catch (_) {
      return const AiKeyTestResult(
        isSuccess: false,
        message: "Sin conexión a internet. Verifica tu red móvil o Wi-Fi.",
      );
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('TimeoutException')) {
        return const AiKeyTestResult(
          isSuccess: false,
          message: "Tiempo de espera agotado al conectar con Google AI Studio.",
        );
      }
      return AiKeyTestResult(
        isSuccess: false,
        message: "No se pudo verificar la clave: $errStr",
      );
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
  }

  Future<void> _updateTestState(String cleanKey, bool isSuccess) async {
    try {
      final keys = await getKeys();
      final index = keys.indexWhere((k) => k.apiKey == cleanKey);
      if (index != -1) {
        keys[index] = keys[index].copyWith(
          lastTestedAt: DateTime.now(),
          isWorking: isSuccess,
        );
        await _saveKeysToStorage(keys);
      }
    } catch (_) {}
  }

  Future<void> _saveKeysToStorage(List<AiKeyModel> keys) async {
    final encoded = jsonEncode(keys.map((k) => k.toMap()).toList());
    await _secureStorage.write(key: vaultStorageKey, value: encoded);
  }
}
