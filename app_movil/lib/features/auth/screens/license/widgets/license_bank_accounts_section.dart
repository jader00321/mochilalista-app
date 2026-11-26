part of '../license_status_and_activation_screen.dart';

mixin _LicenseBankAccountsSectionMixin on _LicenseScreenStateBase {
  @override
  Widget _buildBankAccountsSection(
    bool isDark,
    EffectiveCommercialConfig effectiveConfig,
  ) {
    final hasBcp = effectiveConfig.hasBcpConfigured;
    final hasBbva = effectiveConfig.hasBbvaConfigured;

    if (!hasBcp && !hasBbva) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14141C) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.account_balance_outlined,
              size: 16,
              color: Colors.blue[700],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Para transferencias directas vía BCP o BBVA, solicita las cuentas bancarias directamente a nuestro WhatsApp oficial.",
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (hasBcp)
          _buildBankCard(
            bankName: "Banco de Crédito (BCP)",
            holderName: effectiveConfig.bcpHolder,
            accountNumber: effectiveConfig.bcpAccount,
            cciNumber: effectiveConfig.bcpCci,
            isDark: isDark,
          ),
        if (hasBbva)
          _buildBankCard(
            bankName: "BBVA Perú",
            holderName: effectiveConfig.bbvaHolder,
            accountNumber: effectiveConfig.bbvaAccount,
            cciNumber: effectiveConfig.bbvaCci,
            isDark: isDark,
          ),
      ],
    );
  }

  Widget _buildBankCard({
    required String bankName,
    String holderName = '',
    required String accountNumber,
    required String cciNumber,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141C) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bankName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          if (holderName.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              "Titular: ${holderName.trim()}",
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Cta: $accountNumber",
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
              TextButton(
                onPressed: () {
                  ClipboardHelper.copyWithFeedback(
                    context,
                    accountNumber,
                    feedbackMessage: "Cuenta $bankName copiada al portapapeles",
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text("Copiar Cta", style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          if (cciNumber.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: Text(
                    "CCI: $cciNumber",
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ClipboardHelper.copyWithFeedback(
                      context,
                      cciNumber,
                      feedbackMessage: "CCI $bankName copiado al portapapeles",
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    "Copiar CCI",
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget _buildPlanTile(
    CommercialPlanDetail plan,
    String fingerprint,
    bool isDark,
  ) {
    final isPerpetual = plan.isPerpetual;
    final isExtraAi = plan.isExtraAi;

    Color cardBorderColor;
    Color cardBgColor;
    Color badgeColor;

    if (isPerpetual) {
      cardBorderColor = Colors.purple.withValues(alpha: 0.35);
      cardBgColor = Colors.purple.withValues(alpha: 0.08);
      badgeColor = Colors.purple;
    } else if (isExtraAi) {
      cardBorderColor = Colors.teal.withValues(alpha: 0.35);
      cardBgColor = Colors.teal.withValues(alpha: 0.08);
      badgeColor = Colors.teal;
    } else {
      cardBorderColor = isDark ? Colors.white10 : Colors.black12;
      cardBgColor = isDark ? const Color(0xFF14141C) : const Color(0xFFF8FAFC);
      badgeColor = Colors.blue[700]!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: ValueKey("plan_tile_${plan.id}"),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    _showPlanDetailModal(
                      plan: plan,
                      fingerprint: fingerprint,
                      isDark: isDark,
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            plan.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              plan.badge,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              plan.aiBadge,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        plan.desc,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              "Ver beneficios",
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.blue[300]
                                    : Colors.blue[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 13,
                            color: isDark ? Colors.blue[300] : Colors.blue[700],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  plan.price,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isPerpetual
                        ? Colors.purple
                        : (isDark ? Colors.lightBlue[200] : Colors.blue[900]),
                  ),
                ),
                const SizedBox(height: 4),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey("btn_pedir_${plan.id}"),
                    onTap: () {
                      _showOrderPlanModal(
                        planName: plan.name,
                        price: plan.price,
                        desc: plan.desc,
                        aiScansBadge: plan.aiBadge,
                        fingerprint: fingerprint,
                        isDark: isDark,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 13,
                            color: Colors.green[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Pedir",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPlanDetailModal({
    required CommercialPlanDetail plan,
    required String fingerprint,
    required bool isDark,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PlanDetailBottomSheet(
        plan: plan,
        fingerprint: fingerprint,
        isDark: isDark,
      ),
    );

    if (result == true && mounted) {
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      _showOrderPlanModal(
        planName: plan.name,
        price: plan.price,
        desc: plan.desc,
        aiScansBadge: plan.aiBadge,
        fingerprint: fingerprint,
        isDark: isDark,
      );
    }
  }

  Future<void> _showOrderPlanModal({
    required String planName,
    required String price,
    required String desc,
    required String aiScansBadge,
    required String fingerprint,
    required bool isDark,
  }) async {
    LicenseProvider? licenseProv;
    try {
      licenseProv = Provider.of<LicenseProvider?>(context, listen: false);
    } catch (_) {}
    GoogleDriveBackupProvider? driveProv;
    try {
      driveProv = Provider.of<GoogleDriveBackupProvider?>(
        context,
        listen: false,
      );
    } catch (_) {}
    final syncService = ClientSyncService();
    String? syncToken;
    try {
      final snapshot = await syncService.buildCurrentSnapshot(
        licenseProv: licenseProv,
        driveProv: driveProv,
        overrideHw: fingerprint,
      );
      syncToken = syncService.generateSyncToken(snapshot);
    } catch (_) {}

    final effectiveConfig = _resolveEffectiveConfig();
    final defaultMessage = OwnerLegalIdentity.buildPlanOrderMessage(
      planName: planName,
      price: price,
      hardwareId: fingerprint,
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrderPlanBottomSheet(
        planName: planName,
        price: price,
        desc: desc,
        aiScansBadge: aiScansBadge,
        hardwareId: fingerprint,
        defaultMessage: defaultMessage,
        syncToken: syncToken,
        isDark: isDark,
        onSendWhatsApp: (msg) {
          Navigator.of(ctx).pop();
          final uri =
              LicenseStatusAndActivationScreen.buildCustomWhatsAppOrderUri(
                msg,
                supportPhoneOverride: effectiveConfig.supportPhone,
              );
          _launchRawWhatsAppUrl(uri.toString());
        },
      ),
    );
  }
}
