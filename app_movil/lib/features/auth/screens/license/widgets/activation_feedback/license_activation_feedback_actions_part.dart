part of '../license_activation_feedback_modal.dart';

extension _LicenseActivationFeedbackActionsPart
    on _LicenseActivationFeedbackModalState {
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
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onContactSupport?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_rounded, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Contactar a Soporte Oficial',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
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
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Entendido'),
              ),
            ),
          ),
        ],
      );
    }

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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            buttonLabel,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ),
    );
  }

  _ModalVisualConfig _resolveVisualConfig(
    LicenseRedeemStatus status,
    bool isDark,
  ) {
    switch (status) {
      case LicenseRedeemStatus.success:
        final isBonusOnly =
            widget.result.daysAdded == 0 && widget.result.aiCreditsAdded > 0;
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
