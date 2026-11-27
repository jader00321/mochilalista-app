part of '../license_activation_feedback_modal.dart';

extension _LicenseActivationFeedbackCardsPart
    on _LicenseActivationFeedbackModalState {
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
        return _buildSuccessCard(result, config, isDark, cardBg, cardBorder);
      case LicenseRedeemStatus.alreadyRedeemedSameNonce:
        return _buildAlreadyRedeemedCard(
          result,
          config,
          isDark,
          cardBg,
          cardBorder,
        );
      case LicenseRedeemStatus.supersededOlderNonce:
        return _buildSupersededCard(result, config, isDark, cardBg, cardBorder);
      case LicenseRedeemStatus.hardwareMismatch:
        return _buildHardwareMismatchCard(
          result,
          config,
          isDark,
          cardBg,
          cardBorder,
        );
      case LicenseRedeemStatus.expiredToken:
      case LicenseRedeemStatus.invalidSignatureOrTampered:
      case LicenseRedeemStatus.invalidFormat:
        return _buildFailureInfoBanner(result, config, isDark);
    }
  }

  Widget _buildSuccessCard(
    LicenseRedeemResult result,
    _ModalVisualConfig config,
    bool isDark,
    Color cardBg,
    Color cardBorder,
  ) {
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
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: config.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        size: 15,
                        color: config.accentColor,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          result.plan ?? 'Licencia Oficial',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: config.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                Icon(Icons.check_rounded, size: 15, color: config.accentColor),
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
                value: AppDateFormatter.formatDate(result.newExpirationDate!),
                isDark: isDark,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlreadyRedeemedCard(
    LicenseRedeemResult result,
    _ModalVisualConfig config,
    bool isDark,
    Color cardBg,
    Color cardBorder,
  ) {
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
              Icon(Icons.verified_rounded, size: 16, color: config.accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Licencia actualmente activa',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
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
                  : 'Vence: ${AppDateFormatter.formatDate(snapshot.fechaExpiracion)}',
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
          _buildSupportReferenceTag(
            'Ref. soporte: #${result.tokenNonce ?? 1}',
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSupersededCard(
    LicenseRedeemResult result,
    _ModalVisualConfig config,
    bool isDark,
    Color cardBg,
    Color cardBorder,
  ) {
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
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: config.accentColor,
              ),
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
  }

  Widget _buildHardwareMismatchCard(
    LicenseRedeemResult result,
    _ModalVisualConfig config,
    bool isDark,
    Color cardBg,
    Color cardBorder,
  ) {
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
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 10),
          _buildDeviceIdRow(
            label: 'ID en el código',
            deviceId: tokenDevId,
            icon: Icons.qr_code_2_rounded,
            iconColor: const Color(0xFF94A3B8),
            isDark: isDark,
          ),
          const SizedBox(height: 8),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 15,
                color: config.accentColor,
              ),
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
  }

  Widget _buildFailureInfoBanner(
    LicenseRedeemResult result,
    _ModalVisualConfig config,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: config.accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: config.accentColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: config.accentColor),
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
        color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  deviceId,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
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
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
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
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
