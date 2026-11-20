import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleai_dart/googleai_dart.dart' hide File;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/core/security/secret_vault.dart';
import 'package:app_movil/core/services/ai/ai_vault_service.dart';

class ApiConstants {
  static const String _byokStorageKey = 'user_custom_gemini_api_key';

  // Clave BYOK en memoria configurada por el comerciante (o cargada desde almacenamiento)
  static String? _userCustomApiKey;
  static String _selectedMode = 'INCLUDED';

  /// Establece el modo activo de IA: 'INCLUDED' (bolsa incluida) o 'BYOK' (clave propia)
  static void setAiSelectedMode(String mode) {
    _selectedMode = (mode.toUpperCase().trim() == 'BYOK') ? 'BYOK' : 'INCLUDED';
  }

  /// Retorna el modo activo de IA
  static String get aiSelectedMode => _selectedMode;

  /// Indica si el modo activo configurado es BYOK
  static bool get isUsingByokMode => _selectedMode == 'BYOK';

  /// Actualiza la clave activa proveniente de AiVaultService sin alterar el modo seleccionado
  static void setCustomApiKeyFromVault(String? key) {
    if (key != null && key.trim().isNotEmpty) {
      _userCustomApiKey = key.trim();
    } else {
      _userCustomApiKey = null;
    }
  }

  /// Inicializa la clave BYOK y la bóveda segura al iniciar la app
  static Future<void> initializeCustomKey() async {
    try {
      await AiVaultService.instance.initialize();
    } catch (e) {
      debugPrint("⚠️ No se pudo inicializar la clave BYOK desde almacenamiento: $e");
    }
  }

  /// Alias canónico de inicialización en arranque en frío
  static Future<void> init() => initializeCustomKey();

  /// Guarda o actualiza de forma persistente la clave BYOK propia del comerciante
  static Future<void> persistUserCustomApiKey(String? key) async {
    setUserCustomApiKey(key);
    try {
      if (key != null && key.trim().isNotEmpty) {
        await AiVaultService.instance.addKey(
          alias: 'Mi Clave Gemini',
          apiKey: key.trim(),
        );
      }
      final prefs = await SharedPreferences.getInstance();
      if (_userCustomApiKey != null && _userCustomApiKey!.isNotEmpty) {
        await prefs.setString(_byokStorageKey, _userCustomApiKey!);
      } else {
        await prefs.remove(_byokStorageKey);
      }
    } catch (e) {
      debugPrint("⚠️ No se pudo persistir la clave BYOK en almacenamiento: $e");
    }
  }

  /// Registra o actualiza la clave BYOK propia del comerciante exclusivamente en memoria
  static void setUserCustomApiKey(String? key) {
    if (key != null && key.trim().isNotEmpty) {
      _userCustomApiKey = key.trim();
      _selectedMode = 'BYOK';
    } else {
      _userCustomApiKey = null;
    }
  }

  /// Limpia la clave BYOK en memoria y almacenamiento para volver a la clave del sistema
  static Future<void> clearUserCustomApiKey() async {
    _userCustomApiKey = null;
    _selectedMode = 'INCLUDED';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_byokStorageKey);
    } catch (_) {}
  }

  /// Indica si el usuario está utilizando una clave propia (BYOK)
  static bool get isUsingCustomApiKey =>
      _userCustomApiKey != null && _userCustomApiKey!.isNotEmpty;

  /// Obtiene la llave de Google Gemini con orden de prioridad según el modo seleccionado:
  /// - En modo BYOK: usa estrictamente la clave del comerciante (si no tiene, retorna vacío)
  /// - En modo INCLUDED: usa la cuota oficial provista por MochilaLista (SecretVault o .env)
  static String get googleApiKey {
    // 1. Prioridad: Si está en modo BYOK, usa exclusivamente la clave propia
    if (_selectedMode == 'BYOK') {
      if (_userCustomApiKey != null && _userCustomApiKey!.isNotEmpty) {
        return _userCustomApiKey!;
      }
      debugPrint(
        "⚠️ ADVERTENCIA: Modo BYOK seleccionado pero sin clave propia configurada.",
      );
      return '';
    }

    // 2. Modo INCLUDED: Clave oficial ofuscada por XOR en memoria
    final vaultKey = SecretVault.getGeminiApiKey();
    if (vaultKey.isNotEmpty) {
      return vaultKey;
    }

    // 3. Fallback de desarrollo si .env está presente
    final envKey = dotenv.env['GOOGLE_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }

    debugPrint(
      "⚠️ ADVERTENCIA: No se encontró GOOGLE_API_KEY en SecretVault ni en .env.",
    );
    return '';
  }

  // Modelos oficiales de Gemini (Familia Flash 2026 en Free Tier)
  /// Agente Primario: Mayor inteligencia y capacidad de razonamiento para comprobantes y tablas.
  static const String geminiPrimaryModel = 'gemini-3.8-flash';

  /// Agente Secundario (Respaldo Inmediato): Ultra baja latencia y alta concurrencia.
  static const String geminiFallbackModelFast = 'gemini-3.1-flash-lite';

  /// Agente Terciario (Respaldo de Estabilidad): Generación previa balanceada.
  static const String geminiFallbackModelStable = 'gemini-3.6-flash';

  /// Compatibilidad con referencias previas
  static const String geminiModelFlash = geminiPrimaryModel;

  /// Lista ordenada de agentes en cascada para tolerancia a fallos
  static const List<String> cascadeModels = [
    geminiPrimaryModel,
    geminiFallbackModelFast,
    geminiFallbackModelStable,
  ];

  // Tiempo de espera generoso (95 segundos) para permitir razonamiento multimodal profundo
  static const int aiTimeoutSeconds = 95;

  /// Crea un cliente configurado de Google AI con la clave activa (BYOK o SecretVault)
  /// El caller es responsable de cerrar el cliente cuando termine.
  static GoogleAIClient createAIClient({Duration? timeout}) {
    final apiKey = googleApiKey;
    if (apiKey.isEmpty) {
      throw Exception(
        "API Key de Google Gemini no configurada en SecretVault ni BYOK",
      );
    }
    return GoogleAIClient(
      config: GoogleAIConfig.googleAI(
        authProvider: ApiKeyProvider(apiKey),
        timeout: timeout ?? const Duration(seconds: aiTimeoutSeconds),
      ),
    );
  }
}
