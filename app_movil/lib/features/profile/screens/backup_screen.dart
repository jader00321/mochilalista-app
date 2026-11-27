import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/backup_provider.dart';
import 'package:app_movil/core/services/backup/i_google_drive_backup_service.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/utils/backup_manager.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/tour/configs/backup_screen_tour.dart';
import 'package:app_movil/features/auth/screens/onboarding/profile_selection_screen.dart';
import 'package:app_movil/features/profile/services/business_backup_service.dart';
import 'package:app_movil/features/profile/widgets/google_drive_backup_sheet.dart';

part 'backup/backup_action_tiles.dart';
part 'backup/backup_auto_and_security_widgets.dart';
part 'backup/backup_local_sections_mixin.dart';
part 'backup/backup_smart_business_section.dart';

class BackupScreen extends StatefulWidget {
  final IGoogleDriveBackupService? driveBackupService;
  const BackupScreen({super.key, this.driveBackupService});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

abstract class _BackupScreenBase extends State<BackupScreen> {
  final _tourKeys = BackupScreenTourKeys();
}

class _BackupScreenState extends _BackupScreenBase
    with _BackupLocalSectionsMixin {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      InteractiveTourService.maybeStartAutomaticTour(
        context,
        BackupScreenTour.buildConfig(keys: _tourKeys),
      );
    });
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backupProvider = Provider.of<BackupProvider>(context);
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              ),
        title: const Text(
          "Respaldos y Seguridad",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // 🔧 TAREA 3.4: Info Tooltip
          InfoTooltipButton(
            title: 'Respaldos y Seguridad',
            description:
                'Desde aquí proteges toda tu información. Puedes crear respaldos manuales o automáticos, exportar tu base de datos completa y configurar la seguridad de tu app.',
            onStartInteractiveTour: () =>
                InteractiveTourService.startManualTour(
                  context,
                  BackupScreenTour.buildConfig(keys: _tourKeys),
                ),
            tips: const [
              InfoTip(
                icon: Icons.inventory_2,
                text:
                    'Backup por Negocio (.mlb): Exporta solo los datos del negocio actual. Ideal para migrar a otro dispositivo.',
              ),
              InfoTip(
                icon: Icons.storage,
                text:
                    'Exportación Global (.db): Guarda una copia exacta de TODOS tus negocios. Úsalo como respaldo total.',
              ),
              InfoTip(
                icon: Icons.security,
                text:
                    'Protección Automática: Activa los backups automáticos para que la app respalde tus datos sin que tengas que hacer nada.',
              ),
              InfoTip(
                icon: Icons.lock,
                text:
                    'Seguridad: Configura el tiempo de bloqueo automático para proteger tu app cuando no la uses.',
              ),
              InfoTip(
                icon: Icons.warning_amber,
                text:
                    'Zona de Peligro: Solo usa la importación global si cambiaste de celular o necesitas recuperar una versión anterior.',
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Stack(
          children: [
            ListView(
              cacheExtent: 9999,
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 10,
                bottom:
                    math.max(MediaQuery.viewPaddingOf(context).bottom, 16.0) +
                    24.0,
              ),
              children: [
                // =======================================================
                // BLOQUE A: COPIA DE SEGURIDAD EN LA NUBE (GOOGLE DRIVE)
                // =======================================================
                _buildSectionHeader(
                  icon: Icons.cloud_done_rounded,
                  title: "Copia de Seguridad en la Nube",
                  subtitle:
                      "Base de datos completa: todos tus perfiles y negocios con cifrado AES-256-GCM en Google Drive.",
                  color: Colors.blue,
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                GoogleDriveBackupSheet(
                  statusCardKey: _tourKeys.cloudBackupKey,
                  backupService: widget.driveBackupService,
                  isDark: isDark,
                  showHeader: false,
                ),
                const SizedBox(height: 36),

                // =======================================================
                // BLOQUE B: COPIA LOCAL EN EL TELÉFONO (.MLBG / .MLB)
                // =======================================================
                _buildSectionHeader(
                  icon: Icons.smartphone_rounded,
                  title: "Copia Local en el Teléfono",
                  subtitle:
                      "Archivos .mlbg y .mlb guardados en el almacenamiento interno de este celular o compartidos por WhatsApp.",
                  color: Colors.indigoAccent,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),

                // B1. Respaldo Local Automático en Memoria del Teléfono (Workmanager)
                KeyedSubtree(
                  key: _tourKeys.localAutoBackupKey,
                  child: _buildLocalAutoBackupCard(
                    backupProvider,
                    cardColor,
                    isDark,
                  ),
                ),
                const SizedBox(height: 20),

                // B2. Exportación Global Manual (.mlbg)
                KeyedSubtree(
                  key: _tourKeys.localExportKey,
                  child: _buildLocalExportCard(
                    context,
                    backupProvider,
                    cardColor,
                    isDark,
                  ),
                ),
                const SizedBox(height: 20),

                // B3. Backup por Negocio (.mlb)
                SmartBackupSection(isDark: isDark, cardColor: cardColor),
                const SizedBox(height: 20),

                // B4. Restauración Local de Backup
                KeyedSubtree(
                  key: _tourKeys.localImportKey,
                  child: _buildLocalRestoreCard(
                    context,
                    backupProvider,
                    isDark,
                  ),
                ),
                const SizedBox(height: 36),

                // =======================================================
                // BLOQUE C: SEGURIDAD Y BLOQUEO
                // =======================================================
                _buildSectionHeader(
                  icon: Icons.lock_outline_rounded,
                  title: "Seguridad y Bloqueo",
                  subtitle:
                      "Protege tu app de accesos no autorizados mediante clave de seguridad.",
                  color: Colors.teal,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                PinDelayConfigWidget(isDark: isDark),
                const SizedBox(height: 40),
              ],
            ),

            if (backupProvider.isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.blue),
                        const SizedBox(height: 20),
                        Text(
                          backupProvider.statusMessage.isNotEmpty
                              ? backupProvider.statusMessage
                              : "Procesando...",
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
