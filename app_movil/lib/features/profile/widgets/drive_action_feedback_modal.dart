import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/core/services/backup/i_google_drive_backup_service.dart';

/// Tipo de acción de Google Drive
enum DriveActionType {
  backup,
  restore,
  signIn,
  signOut,
}

/// Estado del flujo de acción
enum DriveActionStatus {
  progress,
  success,
  error,
}

/// Modal interactivo y animado de retroalimentación para operaciones de Google Drive
///
/// Reemplaza las notificaciones planas de pantalla completa y snackbars por una hoja modal
/// elegante con progreso en vivo por etapas y confirmación enriquecida con metadatos reales.
class DriveActionFeedbackModal extends StatefulWidget {
  final DriveActionType actionType;
  final Future<void> Function(void Function(String step)) task;
  final GoogleDriveBackupMetadata? Function()? getResultMetadata;
  final int Function()? getUpdatedBackupsCount;
  final String? customSuccessTitle;
  final String? customSuccessSubtitle;
  final VoidCallback? onDone;
  final VoidCallback? onRetry;

  const DriveActionFeedbackModal({
    super.key,
    required this.actionType,
    required this.task,
    this.getResultMetadata,
    this.getUpdatedBackupsCount,
    this.customSuccessTitle,
    this.customSuccessSubtitle,
    this.onDone,
    this.onRetry,
  });

  /// Abre el modal interactivo y ejecuta la tarea asíncrona de forma coordinada
  static Future<void> show({
    required BuildContext context,
    required DriveActionType actionType,
    required Future<void> Function(void Function(String step)) task,
    GoogleDriveBackupMetadata? Function()? getResultMetadata,
    int Function()? getUpdatedBackupsCount,
    String? customSuccessTitle,
    String? customSuccessSubtitle,
    VoidCallback? onDone,
    VoidCallback? onRetry,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DriveActionFeedbackModal(
        actionType: actionType,
        task: task,
        getResultMetadata: getResultMetadata,
        getUpdatedBackupsCount: getUpdatedBackupsCount,
        customSuccessTitle: customSuccessTitle,
        customSuccessSubtitle: customSuccessSubtitle,
        onDone: onDone,
        onRetry: onRetry,
      ),
    );
  }

  @override
  State<DriveActionFeedbackModal> createState() => _DriveActionFeedbackModalState();
}

class _DriveActionFeedbackModalState extends State<DriveActionFeedbackModal>
    with SingleTickerProviderStateMixin {
  late DriveActionStatus _status;
  String _currentStep = '';
  String? _errorMessage;
  GoogleDriveBackupMetadata? _resultMetadata;
  int? _updatedCount;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _status = DriveActionStatus.progress;
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _setInitialStep();
    _spinController.repeat();
    _executeTask();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _setInitialStep() {
    switch (widget.actionType) {
      case DriveActionType.backup:
        _currentStep = "Preparando y cifrando datos del negocio...";
        break;
      case DriveActionType.restore:
        _currentStep = "Descargando copia de seguridad desde Google Drive...";
        break;
      case DriveActionType.signIn:
        _currentStep = "Autenticando y sincronizando con Google Drive...";
        break;
      case DriveActionType.signOut:
        _currentStep = "Desvinculando cuenta de Google...";
        break;
    }
  }

  Future<void> _executeTask() async {
    try {
      await widget.task((step) {
        if (mounted) {
          setState(() {
            _currentStep = step;
          });
        }
      });

      if (!mounted) return;

      _resultMetadata = widget.getResultMetadata?.call();
      _updatedCount = widget.getUpdatedBackupsCount?.call();

      _spinController.stop();
      HapticFeedback.mediumImpact();

      setState(() {
        _status = DriveActionStatus.success;
      });
    } catch (e) {
      if (!mounted) return;
      _spinController.stop();
      HapticFeedback.heavyImpact();
      setState(() {
        _status = DriveActionStatus.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E28) : Colors.white;

    final bottomPadding = math.max(
      MediaQuery.viewPaddingOf(context).bottom,
      MediaQuery.viewInsetsOf(context).bottom,
    ) + 16.0;

    final screenHeight = MediaQuery.sizeOf(context).height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.85,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              );
            },
            child: _buildBodyForCurrentStatus(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyForCurrentStatus(bool isDark) {
    switch (_status) {
      case DriveActionStatus.progress:
        return _buildProgressView(isDark);
      case DriveActionStatus.success:
        return _buildSuccessView(isDark);
      case DriveActionStatus.error:
        return _buildErrorView(isDark);
    }
  }

  // ============================================================
  // FASE 1: PROGRESO EN VIVO
  // ============================================================
  Widget _buildProgressView(bool isDark) {
    String headerTitle;
    IconData actionIcon;
    Color accentColor;

    switch (widget.actionType) {
      case DriveActionType.backup:
        headerTitle = "Copia de seguridad en curso";
        actionIcon = Icons.cloud_upload_rounded;
        accentColor = const Color(0xFF10B981);
        break;
      case DriveActionType.restore:
        headerTitle = "Restaurando datos";
        actionIcon = Icons.settings_backup_restore_rounded;
        accentColor = const Color(0xFF0284C7);
        break;
      case DriveActionType.signIn:
        headerTitle = "Vinculando Google Drive";
        actionIcon = Icons.cloud_sync_rounded;
        accentColor = const Color(0xFF0284C7);
        break;
      case DriveActionType.signOut:
        headerTitle = "Desvinculando cuenta";
        actionIcon = Icons.link_off_rounded;
        accentColor = const Color(0xFFEF4444);
        break;
    }

    return Column(
      key: const ValueKey('feedback_progress_view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildDragHandle(isDark),
        const SizedBox(height: 16),
        RotationTransition(
          turns: _spinController,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.18 : 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                actionIcon,
                color: accentColor,
                size: 38,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          headerTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            _currentStep,
            key: ValueKey(_currentStep),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.35,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(height: 22),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 5,
            width: 180,
            child: LinearProgressIndicator(
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ============================================================
  // FASE 2: RESULTADO EXITOSO
  // ============================================================
  Widget _buildSuccessView(bool isDark) {
    String successTitle;
    String successSubtitle;
    IconData successIcon = Icons.cloud_done_rounded;
    Color successColor = const Color(0xFF10B981);

    switch (widget.actionType) {
      case DriveActionType.backup:
        successTitle = widget.customSuccessTitle ?? "¡Respaldo guardado en la nube!";
        successSubtitle = widget.customSuccessSubtitle ??
            "Tu información está cifrada y a salvo en tu cuenta oficial de Google Drive.";
        successIcon = Icons.cloud_done_rounded;
        successColor = const Color(0xFF10B981);
        break;
      case DriveActionType.restore:
        successTitle = widget.customSuccessTitle ?? "¡Restauración completada con éxito!";
        successSubtitle = widget.customSuccessSubtitle ??
            "Tus negocios y configuraciones se sincronizaron en este celular.";
        successIcon = Icons.verified_user_rounded;
        successColor = const Color(0xFF0284C7);
        break;
      case DriveActionType.signIn:
        successTitle = widget.customSuccessTitle ?? "¡Cuenta vinculada con éxito!";
        successSubtitle = widget.customSuccessSubtitle ??
            "Tu cuenta de Google ahora está lista para respaldar de forma segura.";
        successIcon = Icons.check_circle_rounded;
        successColor = const Color(0xFF10B981);
        break;
      case DriveActionType.signOut:
        successTitle = widget.customSuccessTitle ?? "Cuenta desvinculada";
        successSubtitle = widget.customSuccessSubtitle ??
            "Tus copias de seguridad en la nube se mantienen a salvo en tu cuenta de Google.";
        successIcon = Icons.cloud_queue_rounded;
        successColor = isDark ? Colors.grey[300]! : Colors.grey[700]!;
        break;
    }

    return Column(
      key: const ValueKey('feedback_success_view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildDragHandle(isDark),
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          tween: Tween<double>(begin: 0.0, end: 1.0),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: successColor.withValues(alpha: isDark ? 0.22 : 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: successColor.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: Icon(
              successIcon,
              color: successColor,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          successTitle,
          key: const ValueKey('drive_feedback_title'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          successSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),

        // Tarjeta enriquecida de metadatos si fue respaldo
        if (widget.actionType == DriveActionType.backup && _resultMetadata != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161A22) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetadataItem(
                  icon: Icons.data_usage_rounded,
                  label: "Tamaño",
                  value: _resultMetadata!.formattedSize,
                  valueKey: 'drive_feedback_size',
                  isDark: isDark,
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
                _buildMetadataItem(
                  icon: Icons.access_time_filled_rounded,
                  label: "Fecha y hora",
                  value: _resultMetadata!.formattedDate.split('•').last.trim(),
                  isDark: isDark,
                ),
                if (_updatedCount != null) ...[
                  Container(
                    width: 1,
                    height: 32,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  _buildMetadataItem(
                    icon: Icons.inventory_2_rounded,
                    label: "Copias",
                    value: "$_updatedCount/5",
                    valueKey: 'drive_feedback_copies',
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            key: const ValueKey('btn_drive_feedback_done'),
            onPressed: () {
              Navigator.pop(context);
              widget.onDone?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: successColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              "Listo",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FASE ERROR
  // ============================================================
  Widget _buildErrorView(bool isDark) {
    return Column(
      key: const ValueKey('feedback_error_view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildDragHandle(isDark),
        const SizedBox(height: 12),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.22 : 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFEF4444).withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.cloud_off_rounded,
            color: Color(0xFFEF4444),
            size: 38,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "No se pudo completar la operación",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? "Ocurrió un error inesperado al conectar con Google Drive. Revisa tu conexión a internet o los permisos de tu cuenta.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white70 : Colors.black87,
                    side: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text("Cerrar"),
                ),
              ),
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _status = DriveActionStatus.progress;
                        _errorMessage = null;
                      });
                      _setInitialStep();
                      _spinController.repeat();
                      _executeTask();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text("Reintentar"),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMetadataItem({
    required IconData icon,
    required String label,
    required String value,
    String? valueKey,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          key: valueKey != null ? ValueKey(valueKey) : null,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildDragHandle(bool isDark) {
    return Center(
      child: Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: isDark ? Colors.white24 : Colors.black12,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
