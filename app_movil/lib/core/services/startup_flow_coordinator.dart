import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:app_movil/core/config/app_changelog_registry.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/services/backup/google_drive_backup_service.dart';
import 'package:app_movil/core/services/backup/i_google_drive_backup_service.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/utils/app_logger.dart';
import 'package:app_movil/features/auth/screens/license/license_status_and_activation_screen.dart';
import 'package:app_movil/features/auth/widgets/eula_acceptance_modal.dart';
import 'package:app_movil/features/auth/widgets/post_update_welcome_modal.dart';

/// Resultado descriptivo de la evaluación de arranque para trazabilidad y pruebas
enum StartupScenarioResult {
  freshInstallNavigatedToLicense,
  legacyUpgradeShowedUpdateModal,
  trialUpgradeShowedUpdateModal,
  commercialUpgradeShowedUpdateModal,
  normalStartupNoModal,
  eulaCancelled,
}

/// Coordinador Central de Flujo de Arranque, EULA, Actualizaciones y Activación
/// Implementa la máquina de estados de 4 caminos del Plan 07 (Sección 3.1).
class StartupFlowCoordinator {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _firstTrialStorageKey = 'ml_first_trial_timestamp';

  /// Bandera pública que expone si se detectó una violación de firma (Anti-Tampering)
  static bool isIntegrityCompromised = false;

  /// Control de ejecución única por sesión de la aplicación
  static bool _hasCoordinatedThisSession = false;
  static bool _isCoordinating = false;

  /// Restablece las banderas de integridad y sesión para pruebas deterministas
  @visibleForTesting
  static void resetSessionStateForTesting() {
    isIntegrityCompromised = false;
    _hasCoordinatedThisSession = false;
    _isCoordinating = false;
  }

  /// Restablece la bandera de integridad para pruebas (retrocompatibilidad)
  static void resetIntegrityCompromised() {
    isIntegrityCompromised = false;
    _hasCoordinatedThisSession = false;
    _isCoordinating = false;
  }

  /// Determina si la base de datos contiene registros comerciales históricos
  /// (usado para diferenciar instalación limpia nueva de un usuario antiguo actualizando).
  static Future<bool> hasPriorCommercialData({Database? db}) async {
    try {
      final database = db ?? await LocalDatabase.instance.database;

      final productsCount = Sqflite.firstIntValue(
            await database.rawQuery('SELECT COUNT(*) FROM productos'),
          ) ??
          0;
      if (productsCount > 0) return true;

      final salesCount = Sqflite.firstIntValue(
            await database.rawQuery('SELECT COUNT(*) FROM ventas'),
          ) ??
          0;
      if (salesCount > 0) return true;

      final clientsCount = Sqflite.firstIntValue(
            await database.rawQuery('SELECT COUNT(*) FROM clientes'),
          ) ??
          0;
      if (clientsCount > 0) return true;

      return false;
    } catch (e) {
      AppLogger.w('StartupFlowCoordinator', 'Error verificando datos comerciales previos: $e');
      return false;
    }
  }

  /// Dispara silenciosamente la evaluación de respaldos periódicos en Google Drive
  static void triggerScheduledDriveBackupSilently({IGoogleDriveBackupService? backupService}) {
    unawaited(() async {
      try {
        final service = backupService ?? GoogleDriveBackupService.instance;
        await service.checkAndTriggerScheduledBackup();
      } catch (e) {
        debugPrint('ℹ️ [StartupFlowCoordinator] Respaldo silencioso omitido/error: $e');
      }
    }());
  }

  /// Ejecuta la orquestación de arranque en el primer frame tras la autenticación o selección de perfil
  static Future<StartupScenarioResult> coordinateStartup(
    BuildContext context, {
    Database? customDb,
    DateTime? overrideNow,
    Future<bool> Function()? signatureVerifier,
    IGoogleDriveBackupService? driveBackupService,
    Future<bool> Function(BuildContext context)? onPromptCloudRestore,
    bool forceCheck = false,
  }) async {
    // 🛡️ Guard de sesión: Evaluar el flujo de bienvenida/actualización exactamente una vez por sesión
    if (!forceCheck && (_hasCoordinatedThisSession || _isCoordinating)) {
      return StartupScenarioResult.normalStartupNoModal;
    }
    _isCoordinating = true;

    try {
      // 1. Verificación de Seguridad Anti-Tampering (No bloqueante en DEBUG/desarrollo)
      try {
        final verify = signatureVerifier ?? DeviceFingerprint.verifyAppSignature;
        final isSignatureValid = await verify();
        if (!isSignatureValid) {
          isIntegrityCompromised = true;
          AppLogger.w('StartupFlowCoordinator', 'Firma de APK adulterada o no oficial detectada.');
        }
      } catch (_) {}

      if (!context.mounted) return StartupScenarioResult.normalStartupNoModal;

      final licenseProv = Provider.of<LicenseProvider?>(context, listen: false);
      if (licenseProv == null) return StartupScenarioResult.normalStartupNoModal;

      // 🛡️ ELIMINACIÓN DE CONDICIÓN DE CARRERA:
      // Si la licencia aún está cargándose asíncronamente en el primer frame, esperar explícitamente a checkLicense()
      if (licenseProv.license == null) {
        await licenseProv.checkLicense(overrideNow: overrideNow);
      }
      if (!context.mounted) return StartupScenarioResult.normalStartupNoModal;

      final license = licenseProv.license;
      if (license == null) return StartupScenarioResult.normalStartupNoModal;

      // 2. Anclaje de timestamp de primer trial en FlutterSecureStorage para evitar abuso de pruebas
      try {
        final cachedFirstTrial = await _storage.read(key: _firstTrialStorageKey);
        if (cachedFirstTrial == null && license.isTrial) {
          final nowIso = (overrideNow ?? DateTime.now()).toIso8601String();
          await _storage.write(key: _firstTrialStorageKey, value: nowIso);
        }
      } catch (_) {}

      final currentVersion = AppChangelogRegistry.currentVersion;
      final lastVersion = license.lastExecutedAppVersion;
      final hasAcceptedEula = license.eulaAcceptedVersion != null;

      // =========================================================================
      // ESCENARIO A: INSTALACIÓN LIMPIA NUEVA
      // lastExecutedAppVersion == null Y SIN datos comerciales previos en SQLite
      // =========================================================================
      if (lastVersion == null) {
        final hasData = await hasPriorCommercialData(db: customDb);

        if (!hasData) {
          AppLogger.i('StartupFlowCoordinator', 'Detectada Instalación Limpia Nueva (Escenario A).');

          // Mostrar EULA de aceptación obligatoria
          if (!hasAcceptedEula && context.mounted) {
            final accepted = await EulaAcceptanceModal.show(context);
            if (accepted != true) {
              return StartupScenarioResult.eulaCancelled;
            }
          }

          // Gancho opcional de restauración desde Google Drive en Onboarding
          if (onPromptCloudRestore != null && context.mounted) {
            final restored = await onPromptCloudRestore(context);
            if (restored) {
              _hasCoordinatedThisSession = true;
              return StartupScenarioResult.freshInstallNavigatedToLicense;
            }
          }

          // Marcar la versión actual de inmediato para que NUNCA se interprete como update
          await licenseProv.updateLastExecutedVersion(currentVersion);

          // Redirigir a Licencia y Activación recomendando activar antes de los 30 días
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LicenseStatusAndActivationScreen(
                  welcomeTrialNotice:
                      "¡Bienvenido a MochilaLista! Dispones de 30 días de prueba gratuita y 50 escaneos con IA. Te recomendamos activar tu plan comercial antes de que finalice tu prueba.",
                ),
              ),
            );
          }

          _hasCoordinatedThisSession = true;
          return StartupScenarioResult.freshInstallNavigatedToLicense;
        } else {
          // =====================================================================
          // ESCENARIO B1: USUARIO ANTIGUO ACTUALIZANDO POR PRIMERA VEZ
          // lastExecutedAppVersion == null pero SÍ tiene datos comerciales en SQLite
          // =====================================================================
          AppLogger.i('StartupFlowCoordinator', 'Detectado Usuario Antiguo con Datos Previos (Escenario B1).');

          if (!hasAcceptedEula && context.mounted) {
            final accepted = await EulaAcceptanceModal.show(context);
            if (accepted != true) {
              return StartupScenarioResult.eulaCancelled;
            }
          }

          if (context.mounted) {
            await PostUpdateWelcomeModal.show(
              context,
              appVersion: currentVersion,
              mode: PostUpdateMode.trialOrGrace,
              onActivatePlanPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LicenseStatusAndActivationScreen()),
                );
              },
            );
          }

          await licenseProv.updateLastExecutedVersion(currentVersion);
          _hasCoordinatedThisSession = true;
          return StartupScenarioResult.legacyUpgradeShowedUpdateModal;
        }
      }

      // =========================================================================
      // ESCENARIOS CON VERSIÓN REGISTRADA PREVIAMENTE
      // =========================================================================
      final isNewVersion = (lastVersion != currentVersion);

      if (isNewVersion) {
        // Si la nueva versión requiere aceptación de EULA pendiente
        if (!hasAcceptedEula && context.mounted) {
          final accepted = await EulaAcceptanceModal.show(context);
          if (accepted != true) {
            return StartupScenarioResult.eulaCancelled;
          }
        }

        final isPaidOrPerpetual = license.isPerpetual || (license.isActive && !license.isTrial);

        if (isPaidOrPerpetual) {
          // =====================================================================
          // ESCENARIO C: USUARIO CON LICENCIA COMERCIAL ACTIVA O PERPETUA
          // =====================================================================
          AppLogger.i('StartupFlowCoordinator', 'Detectada Actualización con Licencia Activa (Escenario C).');

          if (context.mounted) {
            await PostUpdateWelcomeModal.show(
              context,
              appVersion: currentVersion,
              mode: PostUpdateMode.activeCommercialOrPerpetual,
            );
          }

          await licenseProv.updateLastExecutedVersion(currentVersion);
          _hasCoordinatedThisSession = true;
          return StartupScenarioResult.commercialUpgradeShowedUpdateModal;
        } else {
          // =====================================================================
          // ESCENARIO B2: USUARIO EN TRIAL O GRACIA ACTUALIZANDO DE VERSIÓN
          // =====================================================================
          AppLogger.i('StartupFlowCoordinator', 'Detectada Actualización en Trial/Gracia (Escenario B2).');

          if (context.mounted) {
            await PostUpdateWelcomeModal.show(
              context,
              appVersion: currentVersion,
              mode: PostUpdateMode.trialOrGrace,
              onActivatePlanPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LicenseStatusAndActivationScreen()),
                );
              },
            );
          }

          await licenseProv.updateLastExecutedVersion(currentVersion);
          _hasCoordinatedThisSession = true;
          return StartupScenarioResult.trialUpgradeShowedUpdateModal;
        }
      }

      // Si la versión es idéntica pero el EULA no fue aceptado
      if (!hasAcceptedEula && context.mounted) {
        final accepted = await EulaAcceptanceModal.show(context);
        if (accepted != true) {
          return StartupScenarioResult.eulaCancelled;
        }
      }

      // Disparo asíncrono no bloqueante del respaldo periódico en segundo plano
      triggerScheduledDriveBackupSilently(backupService: driveBackupService);

      _hasCoordinatedThisSession = true;
      return StartupScenarioResult.normalStartupNoModal;
    } finally {
      _isCoordinating = false;
    }
  }
}
