import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/config/app_changelog_registry.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/providers/license_provider.dart';

/// Modalidad de presentación del modal post-actualización según el estado de la licencia
enum PostUpdateMode {
  trialOrGrace,
  activeCommercialOrPerpetual,
}

/// Modal emergente que se muestra tras la instalación de una nueva versión
/// Despliega las novedades redactadas en lenguaje comercial claro y guía la activación.
class PostUpdateWelcomeModal extends StatelessWidget {
  final String appVersion;
  final PostUpdateMode mode;
  final VoidCallback? onActivatePlanPressed;
  final VoidCallback? onContinueTrialPressed;

  const PostUpdateWelcomeModal({
    super.key,
    required this.appVersion,
    this.mode = PostUpdateMode.activeCommercialOrPerpetual,
    this.onActivatePlanPressed,
    this.onContinueTrialPressed,
  });

  /// Método estático de conveniencia para despliegue manual
  static Future<void> show(
    BuildContext context, {
    String? appVersion,
    PostUpdateMode mode = PostUpdateMode.activeCommercialOrPerpetual,
    VoidCallback? onActivatePlanPressed,
    VoidCallback? onContinueTrialPressed,
  }) async {
    final version = appVersion ?? AppChangelogRegistry.currentVersion;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PostUpdateWelcomeModal(
        appVersion: version,
        mode: mode,
        onActivatePlanPressed: onActivatePlanPressed,
        onContinueTrialPressed: onContinueTrialPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final licenseProv = Provider.of<LicenseProvider?>(context, listen: false);
    final features = AppChangelogRegistry.getChangelogForVersion(appVersion);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabecera con insignia de versión
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.rocket_launch_rounded, color: Colors.blue, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "¡Actualización Exitosa!",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            "MochilaLista v$appVersion",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Banner de Garantía y Migración según el modo
                _buildStatusBanner(isDark),
                const SizedBox(height: 14),

                // Lista de Novedades del Changelog Registry
                Text(
                  "Novedades destacadas de esta versión:",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),

                ...features.map((item) => _buildFeatureItem(
                      item.icon,
                      item.title,
                      item.description,
                      isDark,
                    )),
                const SizedBox(height: 12),

                // Sello Legal Oficial
                Center(
                  child: Text(
                    "${OwnerLegalIdentity.watermarkNotice}\nLima, Perú",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Botonera de Acciones
                _buildActionButtons(context, licenseProv, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(bool isDark) {
    if (mode == PostUpdateMode.trialOrGrace) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.blue[700], size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Tus datos comerciales han sido migrados con éxito. Recuerda activar tu plan comercial antes de que finalicen tus días de prueba o periodo de gracia.",
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: isDark ? Colors.lightBlue[100] : Colors.blue[900],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_rounded, color: Colors.green, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Tus datos y licencia han sido migrados con éxito y respaldo verificado.",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.green[200] : Colors.green[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, LicenseProvider? licenseProv, bool isDark) {
    if (mode == PostUpdateMode.trialOrGrace) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: () async {
              if (licenseProv != null) {
                await licenseProv.updateLastExecutedVersion(appVersion);
              }
              if (context.mounted) {
                Navigator.of(context).pop();
                onActivatePlanPressed?.call();
              }
            },
            icon: const Icon(Icons.vpn_key_rounded, size: 18),
            label: const Text(
              "Activar Plan / Ver Licencia",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () async {
              if (licenseProv != null) {
                await licenseProv.updateLastExecutedVersion(appVersion);
              }
              if (context.mounted) {
                Navigator.of(context).pop();
                onContinueTrialPressed?.call();
              }
            },
            child: Text(
              "Continuar con mi prueba",
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        ],
      );
    }

    return ElevatedButton(
      onPressed: () async {
        if (licenseProv != null) {
          await licenseProv.updateLastExecutedVersion(appVersion);
        }
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text(
        "Comenzar a Usar",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.blue[600]),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: isDark ? Colors.grey[300] : Colors.black87,
                ),
                children: [
                  TextSpan(
                    text: "$title: ",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
