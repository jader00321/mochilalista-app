import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/core/services/license/license_redeem_result.dart';

/// Modal animado e interactivo de retroalimentación tras un intento de canje de licencia.
///
/// Reemplaza las notificaciones planas de pantalla y banners técnicos ("Nonce <= X")
/// por una experiencia visual pulida, respetuosa con el modo claro/oscuro,
/// con sello animado elástico (`Curves.easeOutBack`), sin emojis crudos (solo `Icons.*`)
/// y con explicaciones humanas y transparentes para cada escenario.
class LicenseActivationFeedbackModal extends StatefulWidget {
  final LicenseRedeemResult result;
  final VoidCallback? onDone;
  final VoidCallback? onContactSupport;

  const LicenseActivationFeedbackModal({
    super.key,
    required this.result,
    this.onDone,
    this.onContactSupport,
  });

  /// Despliega el modal como BottomSheet responsivo con `SafeArea`
  static Future<void> show(
    BuildContext context, {
    required LicenseRedeemResult result,
    VoidCallback? onDone,
    VoidCallback? onContactSupport,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LicenseActivationFeedbackModal(
        result: result,
        onDone: onDone,
        onContactSupport: onContactSupport,
      ),
    );
  }

  @override
  State<LicenseActivationFeedbackModal> createState() =>
      _LicenseActivationFeedbackModalState();
}

class _LicenseActivationFeedbackModalState
    extends State<LicenseActivationFeedbackModal> {
  bool _copiedDeviceId = false;

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copiedDeviceId = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copiedDeviceId = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final result = widget.result;

    // Configuración estética según el estado
    final _ModalVisualConfig config = _resolveVisualConfig(result.status, isDark);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
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
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indicador de arrastre superior
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.24)
                        : Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sello elástico animado
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutBack,
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
                    color: config.accentColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: config.accentColor.withValues(alpha: 0.35),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: config.accentColor.withValues(alpha: 0.2),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    config.icon,
                    size: 38,
                    color: config.accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Título
              Text(
                config.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),

              // Subtítulo
              Text(
                config.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 20),

              // Tarjeta contextual con metadatos según el resultado
              _buildContentCard(result, config, isDark),
              const SizedBox(height: 24),

              // Botones de acción
              _buildActionButtons(result, config, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentCard(
    LicenseRedeemResult result,
    _ModalVisualConfig config,
    bool isDark,
  ) {
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFFF8FAFC);
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);

    switch (result.status) {
      case LicenseRedeemStatus.success:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge del plan
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: config.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium_rounded,
                            size: 15, color: config.accentColor),
                        const SizedBox(width: 5),
                        Text(
                          result.plan ?? 'Licencia Oficial',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: config.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (result.daysAdded == 0 && result.aiCreditsAdded > 0) ...[
                _buildInfoRow(
                  icon: Icons.auto_awesome,
                  iconColor: const Color(0xFF3B82F6),
                  title: 'Escaneos IA Acreditados',
                  value: '+${result.aiCreditsAdded} escaneos',
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.check_rounded,
                        size: 15, color: config.accentColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tu fecha de vencimiento actual se mantiene intacta.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                if (result.daysAdded > 0) ...[
                  _buildInfoRow(
                    icon: Icons.calendar_today_rounded,
                    iconColor: const Color(0xFF10B981),
                    title: 'Vigencia Agregada',
                    value: '+${result.daysAdded} días',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                ],
                if (result.aiCreditsAdded > 0) ...[
                  _buildInfoRow(
                    icon: Icons.auto_awesome,
                    iconColor: const Color(0xFF3B82F6),
                    title: 'Escaneos IA Agregados',
                    value: '+${result.aiCreditsAdded} escaneos',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                ],
                if (result.newExpirationDate != null)
                  _buildInfoRow(
                    icon: Icons.event_available_rounded,
                    iconColor: const Color(0xFF6366F1),
                    title: 'Nuevo Vencimiento',
                    value: _formatDate(result.newExpirationDate),
                    isDark: isDark,
                  ),
              ],
            ],
          ),
        );

      case LicenseRedeemStatus.alreadyRedeemedSameNonce:
        final snapshot = result.currentLicenseSnapshot;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_rounded,
                      size: 16, color: config.accentColor),
                  const SizedBox(width: 6),
                  Text(
                    'Licencia actualmente activa',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.badge_rounded,
                iconColor: config.accentColor,
                title: 'Plan Actual',
                value: snapshot?.tipoPlan ?? result.plan ?? 'Oficial',
                isDark: isDark,
              ),
              if (snapshot != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  icon: Icons.timer_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Estado de Vigencia',
                  value: snapshot.daysRemaining > 0
                      ? '${snapshot.daysRemaining} días restantes'
                      : 'Vence: ${_formatDate(snapshot.fechaExpiracion)}',
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  icon: Icons.auto_awesome,
                  iconColor: const Color(0xFF3B82F6),
                  title: 'Escaneos IA Disponibles',
                  value: '${snapshot.remainingAiScans}',
                  isDark: isDark,
                ),
              ],
              const SizedBox(height: 14),
              // Tag de referencia para soporte (sin la palabra Nonce)
              _buildSupportReferenceTag(
                'Ref. soporte: #${result.tokenNonce ?? 1}',
                isDark,
              ),
            ],
          ),
        );

      case LicenseRedeemStatus.supersededOlderNonce:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: config.accentColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tu negocio cuenta con una renovación más reciente.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildSupportReferenceTag(
                'Ref. soporte: #${result.tokenNonce ?? 0} • Vigente: #${result.currentNonce ?? 0}',
                isDark,
              ),
            ],
          ),
        );

      case LicenseRedeemStatus.hardwareMismatch:
        final currentDevId = result.currentDeviceId ?? 'Desconocido';
        final tokenDevId = result.tokenDeviceId ?? 'Desconocido';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comparación de Identificadores:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 10),

              // ID en el código
              _buildDeviceIdRow(
                label: 'ID en el código',
                deviceId: tokenDevId,
                icon: Icons.qr_code_2_rounded,
                iconColor: const Color(0xFF94A3B8),
                isDark: isDark,
              ),
              const SizedBox(height: 8),

              // ID de este celular (con botón copiar)
              _buildDeviceIdRow(
                label: 'ID de este celular',
                deviceId: currentDevId,
                icon: Icons.phone_android_rounded,
                iconColor: config.accentColor,
                isDark: isDark,
                trailing: InkWell(
                  onTap: () => _copyToClipboard(currentDevId),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: config.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _copiedDeviceId
                              ? Icons.check_rounded
                              : Icons.copy_rounded,
                          size: 13,
                          color: config.accentColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _copiedDeviceId ? 'Copiado' : 'Copiar',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: config.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 15, color: config.accentColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Si cambiaste de equipo o reinstalaste la app, comparte tu ID con soporte técnico para reasignar tu código.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case LicenseRedeemStatus.expiredToken:
      case LicenseRedeemStatus.invalidSignatureOrTampered:
      case LicenseRedeemStatus.invalidFormat:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: config.accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: config.accentColor.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 18, color: config.accentColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.status == LicenseRedeemStatus.expiredToken
                      ? 'Este código cumplió el período de vigencia contratado. Puedes renovar tu plan en cualquier momento comunicándote con soporte oficial.'
                      : 'Verifica haber copiado el código de activación completo (inicia con ML) o escanea el código QR oficial recibido por WhatsApp.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildDeviceIdRow({
    required String label,
    required String deviceId,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  deviceId,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    fontFamily: 'monospace',
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? const Color(0xFF94A3B8)
                : const Color(0xFF64748B),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildSupportReferenceTag(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.tag_rounded,
            size: 13,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    LicenseRedeemResult result,
    _ModalVisualConfig config,
    bool isDark,
  ) {
    if (result.status == LicenseRedeemStatus.hardwareMismatch) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onContactSupport?.call();
              },
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: const Text(
                'Contactar a Soporte Oficial',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onDone?.call();
              },
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white70 : Colors.black54,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Entendido'),
            ),
          ),
        ],
      );
    }

    // Botón principal único para los demás estados
    final isSuccess = result.status == LicenseRedeemStatus.success;
    final buttonLabel = isSuccess ? 'Comenzar a Usar' : 'Entendido';

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.of(context).pop();
          widget.onDone?.call();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: config.accentColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Text(
          buttonLabel,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  _ModalVisualConfig _resolveVisualConfig(
      LicenseRedeemStatus status, bool isDark) {
    switch (status) {
      case LicenseRedeemStatus.success:
        final isBonusOnly = widget.result.daysAdded == 0 &&
            widget.result.aiCreditsAdded > 0;
        return _ModalVisualConfig(
          icon: isBonusOnly ? Icons.stars_rounded : Icons.verified_rounded,
          accentColor: const Color(0xFF10B981),
          title: isBonusOnly
              ? '¡Bono IA Acreditado!'
              : '¡Licencia Activada con Éxito!',
          subtitle: isBonusOnly
              ? 'Se han añadido escaneos inteligentes adicionales a tu cuenta oficial.'
              : 'Tu suscripción ha sido verificada y activada correctamente.',
        );

      case LicenseRedeemStatus.alreadyRedeemedSameNonce:
        return const _ModalVisualConfig(
          icon: Icons.check_circle_rounded,
          accentColor: Color(0xFF0284C7),
          title: 'Este código ya está aplicado',
          subtitle:
              'Este código de activación ya fue canjeado anteriormente en este celular y sus beneficios se encuentran activos.',
        );

      case LicenseRedeemStatus.supersededOlderNonce:
        return const _ModalVisualConfig(
          icon: Icons.history_rounded,
          accentColor: Color(0xFF6366F1),
          title: 'Código anterior ya superado',
          subtitle:
              'Este código corresponde a una activación anterior que ya fue reemplazada por una renovación más reciente.',
        );

      case LicenseRedeemStatus.hardwareMismatch:
        return const _ModalVisualConfig(
          icon: Icons.phonelink_erase_rounded,
          accentColor: Color(0xFFF97316),
          title: 'Código emitido para otro celular',
          subtitle:
              'Este código fue generado con la firma de seguridad exclusiva para otro dispositivo. Cada licencia se vincula al celular registrado.',
        );

      case LicenseRedeemStatus.expiredToken:
        return const _ModalVisualConfig(
          icon: Icons.timer_off_rounded,
          accentColor: Color(0xFFEF4444),
          title: 'Código expirado',
          subtitle:
              'El período de validez de este código de activación ha caducado. Contacta a soporte para una nueva renovación.',
        );

      case LicenseRedeemStatus.invalidSignatureOrTampered:
        return const _ModalVisualConfig(
          icon: Icons.gpp_bad_rounded,
          accentColor: Color(0xFFEF4444),
          title: 'Firma digital no válida',
          subtitle:
              'La firma digital del código no pudo ser verificada criptográficamente o el código está incompleto.',
        );

      case LicenseRedeemStatus.invalidFormat:
        return const _ModalVisualConfig(
          icon: Icons.error_outline_rounded,
          accentColor: Color(0xFFEF4444),
          title: 'Código no reconocido',
          subtitle:
              'El texto ingresado no corresponde a un código de activación oficial de MochilaLista.',
        );
    }
  }
}

class _ModalVisualConfig {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;

  const _ModalVisualConfig({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
  });
}
