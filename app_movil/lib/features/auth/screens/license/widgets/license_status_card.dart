part of '../license_status_and_activation_screen.dart';

mixin _LicenseStatusCardMixin on _LicenseScreenStateBase {
  @override
  Widget _buildClipboardDetectedBanner(bool isDark) {
    final isMlc1 =
        _detectedClipboardCode != null &&
        CommercialConfigSyncService.looksLikeMlc1Input(_detectedClipboardCode!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (isMlc1 ? Colors.teal : Colors.green).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isMlc1 ? Colors.teal : Colors.green).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isMlc1
                ? Icons.verified_user_outlined
                : Icons.content_paste_go_rounded,
            color: isMlc1 ? Colors.teal : Colors.green,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMlc1
                      ? "Ficha de tarifas detectada en portapapeles"
                      : "Código detectado en portapapeles",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  _detectedClipboardCode!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              final codeToUse = _detectedClipboardCode!;
              _codeController.text = codeToUse;
              _activateCode(codeToUse);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isMlc1 ? Colors.teal : Colors.green[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isMlc1 ? "Revisar y Aplicar" : "Pegar y Activar",
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget _buildWelcomeTrialBanner(String message, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.stars_rounded, color: Colors.blue[700], size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
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

  @override
  Widget _buildExecutiveStatusCard(
    LicenseProvider? licenseProv,
    LicenseModel? license,
    String fingerprint,
    bool isDark,
  ) {
    final isPerpetual = license?.isPerpetual ?? false;
    final daysRemaining = license?.daysRemaining ?? 30;
    final dateFormat = AppDateFormatter.ddMMyyyy;

    // Propiedades dinámicas exactas desde LicenseModel
    final badgeLabel =
        license?.dynamicPlanBadgeLabel ?? "Prueba Gratuita (Trial)";
    final badgeColor =
        license?.dynamicPlanBadgeColor ?? const Color(0xFF00695C);
    final badgeIcon = license?.dynamicPlanBadgeIcon ?? Icons.verified_rounded;

    // Cálculo proporcional de la barra de progreso preservando suma acumulativa
    final progress =
        license?.progressRatio ?? (daysRemaining / 30.0).clamp(0.0, 1.0);
    final hasAccumulatedDays = license?.hasAccumulatedBonusDays ?? false;

    // Cuotas IA y BYOK
    final remainingAiScans = licenseProv?.remainingAiScans ?? 50;
    final isUsingByok = licenseProv?.isUsingByokMode ?? false;
    final accumulatedScans =
        licenseProv?.aiAccumulatedScans ?? remainingAiScans;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E28) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KeyedSubtree(
              key: _tourKeys.planStatusKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabecera sin quiebre de línea y Badge Dinámico Exacto
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Text(
                        "Estado de la Licencia",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: badgeColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, size: 14, color: badgeColor),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                badgeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Días restantes o Acceso Perpetuo
                  if (isPerpetual) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.purple.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.all_inclusive_rounded,
                            color: Colors.purple,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Acceso de por vida habilitado",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  license?.updatesUntil != null
                                      ? "Actualizaciones incluidas hasta: ${dateFormat.format(license!.updatesUntil!)}"
                                      : "Actualizaciones de estabilidad de por vida",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          "$daysRemaining días restantes",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: daysRemaining <= 5
                                ? Colors.amber[800]
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        Text(
                          license != null
                              ? "Vence: ${dateFormat.format(license.fechaExpiracion)}"
                              : "Calculando...",
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: isDark
                            ? Colors.white10
                            : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          daysRemaining <= 5 ? Colors.amber : Colors.blue,
                        ),
                      ),
                    ),
                    if (hasAccumulatedDays) ...[
                      const SizedBox(height: 4),
                      Text(
                        "Incluye días acumulados de tu periodo anterior.",
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Chip Interactivo de Escaneos IA Disponibles
            KeyedSubtree(
              key: _tourKeys.aiQuotaKey,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Escaneos IA Disponibles",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.lightBlue[200]
                                    : Colors.blue[900],
                              ),
                            ),
                            Text(
                              isUsingByok
                                  ? "Escaneos Ilimitados (BYOK) • Saldo guardado: $accumulatedScans usos"
                                  : "$accumulatedScans escaneos acumulados disponibles",
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Identificador de Hardware (Hardware ID)
            KeyedSubtree(
              key: _tourKeys.hardwareIdKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Identificador de este dispositivo (Hardware ID):",
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF14141C)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.phonelink_setup_rounded,
                          size: 20,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fingerprint,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          tooltip: "Copiar ID",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          onPressed: () {
                            ClipboardHelper.copyWithFeedback(
                              context,
                              fingerprint,
                              feedbackMessage:
                                  "Hardware ID $fingerprint copiado al portapapeles",
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.share_rounded,
                            size: 18,
                            color: Colors.green,
                          ),
                          tooltip: "Enviar por WhatsApp",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          onPressed: () {
                            final msg =
                                "Hola Julio Angello, solicito activación/renovación para MochilaLista. Mi ID de equipo es: $fingerprint";
                            _launchWhatsAppMessage(msg);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Código de seguridad único generado para esta instalación (no es tu IMEI)",
                    style: TextStyle(
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Vía A: Botón para compartir ficha de estado offline (.mlsync)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const ValueKey("btn_share_client_sync_state"),
                      icon: _isSharingSyncState
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, size: 16),
                      label: const Text(
                        "Compartir estado con Soporte",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.lightBlue[300]
                            : Colors.blue[800],
                        side: BorderSide(
                          color: isDark
                              ? Colors.blue.withValues(alpha: 0.3)
                              : Colors.blue.withValues(alpha: 0.4),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 9,
                          horizontal: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isSharingSyncState
                          ? null
                          : () => _shareClientState(licenseProv, fingerprint),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
