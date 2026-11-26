part of '../license_status_and_activation_screen.dart';

mixin _LicenseMlc1SyncMixin on _LicenseScreenStateBase {
  Future<void> _handleSupportContactForResult(
    LicenseRedeemResult result,
  ) async {
    String msg;
    if (result.status == LicenseRedeemStatus.hardwareMismatch) {
      msg =
          "Hola Julio Angello, adquirí una licencia para MochilaLista pero el código indica que fue generado para otro celular (ID código: ${result.tokenDeviceId ?? 'N/A'}, ID de mi celular: ${result.currentDeviceId ?? 'N/A'}). ¿Podrían ayudarme a reasignarlo?";
    } else if (result.status == LicenseRedeemStatus.expiredToken) {
      msg =
          "Hola Julio Angello, mi código de licencia MochilaLista ha expirado. Deseo renovar mi suscripción. Mi ID de equipo es: ${result.currentDeviceId ?? ''}";
    } else {
      msg =
          "Hola Julio Angello, necesito soporte con la activación de mi licencia en MochilaLista. Mi ID de equipo es: ${result.currentDeviceId ?? ''}";
    }
    await _launchWhatsAppMessage(msg);
  }

  @override
  Future<void> _activateCode(String code) async {
    if (CommercialConfigSyncService.looksLikeMlc1Input(code)) {
      await _handleMlc1TokenFlow(code);
      return;
    }

    final extracted = Ed25519LicenseValidator.extractLicenseToken(code);
    final clean = extracted.isNotEmpty ? extracted : code.trim();
    if (clean.isEmpty) {
      CustomSnackBar.show(
        context,
        message: "Por favor, ingresa un código de activación.",
        isError: true,
      );
      return;
    }

    final licenseProv = Provider.of<LicenseProvider?>(context, listen: false);
    if (licenseProv == null) return;

    final result = await licenseProv.redeemCodeDetailed(clean);
    if (!mounted) return;

    if (result.isSuccess) {
      _codeController.clear();
      setState(() => _detectedClipboardCode = null);
    }

    await LicenseActivationFeedbackModal.show(
      context,
      result: result,
      onContactSupport: () => _handleSupportContactForResult(result),
    );
  }

  Future<void> _handleMlc1TokenFlow(String rawCode) async {
    if (_isVerifyingMlc1) return;
    setState(() => _isVerifyingMlc1 = true);

    final catalogProv = _tryCatalogProvider(listen: false);
    final CommercialConfigVerificationResult verification;
    try {
      verification = catalogProv != null
          ? await catalogProv.previewToken(rawCode)
          : await _commercialSyncService.parseAndVerifyToken(rawCode);
    } finally {
      if (mounted) setState(() => _isVerifyingMlc1 = false);
    }

    if (!mounted) return;
    if (!verification.isValid || verification.payload == null) {
      CustomSnackBar.show(
        context,
        message:
            verification.error ??
            'No se pudo validar la ficha comercial MLC1.',
        isError: true,
      );
      return;
    }

    final confirmed = await _showMlc1ConfirmationDialog(verification);
    if (!mounted || confirmed != true) return;

    setState(() => _isVerifyingMlc1 = true);
    try {
      final applyResult = catalogProv != null
          ? await catalogProv.applyToken(verification.cleanToken ?? rawCode)
          : await _commercialSyncService.applyVerifiedToken(
              verification.cleanToken ?? rawCode,
            );

      if (!mounted) return;
      if (!applyResult.isValid) {
        CustomSnackBar.show(
          context,
          message:
              applyResult.error ?? 'No se pudo aplicar la configuración MLC1.',
          isError: true,
        );
        return;
      }

      if (catalogProv == null && applyResult.payload != null) {
        final saved = await _commercialSyncService.getSavedConfig();
        if (mounted) {
          setState(() {
            _fallbackSyncedConfig = saved != null
                ? EffectiveCommercialConfig.fromSaved(saved)
                : EffectiveCommercialConfig.fromPayload(
                    applyResult.payload!,
                    hasSyncedOverride: true,
                    issuedAtLimaLabel: applyResult.issuedAtLima,
                    appliedAtLimaLabel: applyResult.appliedAtLima,
                  );
          });
        }
      }

      if (!mounted) return;
      _codeController.clear();
      setState(() => _detectedClipboardCode = null);

      CustomSnackBar.show(
        context,
        message:
            'Tarifas y medios de pago actualizados (Rev. #${applyResult.revision}).',
        isError: false,
      );
    } finally {
      if (mounted) setState(() => _isVerifyingMlc1 = false);
    }
  }

  Future<bool?> _showMlc1ConfirmationDialog(
    CommercialConfigVerificationResult verification,
  ) {
    final previewConfig = EffectiveCommercialConfig.fromPayload(
      verification.payload!,
      hasSyncedOverride: true,
      issuedAtLimaLabel: verification.issuedAtLima,
    );
    final orderedSpecs = <CommercialSyncProductSpec>[
      previewConfig.mensual,
      previewConfig.trimestral,
      previewConfig.semestral,
      previewConfig.anual,
      previewConfig.perpetua,
      previewConfig.bolsaExtraIa,
      previewConfig.paseAnualUpdates,
      previewConfig.migracion,
    ];

    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          key: const ValueKey('dialog_mlc1_confirm_apply'),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: Colors.teal,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Actualizar Tarifas y Cuentas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.teal.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ficha oficial verificada · Rev. #${previewConfig.revision}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        if (previewConfig.issuedAtLimaLabel != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Emitida el ${previewConfig.issuedAtLimaLabel} (Hora Perú)',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[700],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Resumen de tarifas:',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...orderedSpecs.map((spec) {
                    final details = <String>[];
                    if (spec.days > 0 && spec.id != 'perpetua') {
                      details.add('${spec.days} días');
                    }
                    if (spec.aiCredits > 0) {
                      details.add('+${spec.aiCredits} IA');
                    }
                    if (spec.updatesMonths > 0) {
                      details.add('${spec.updatesMonths}m updates');
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              details.isNotEmpty
                                  ? '${spec.label} (${details.join(' · ')})'
                                  : spec.label,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            spec.formattedPrice,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 16),
                  const Text(
                    'Canales de soporte y pago:',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Soporte WhatsApp: ${previewConfig.supportPhone}',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Yape / Plin: ${previewConfig.yapePhone} (${previewConfig.yapeHolder})',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    previewConfig.hasBcpConfigured
                        ? 'BCP: ${previewConfig.bcpAccount}${previewConfig.bcpHolder.isNotEmpty ? ' · ${previewConfig.bcpHolder}' : ''}'
                        : 'BCP: No configurada (oculta)',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    previewConfig.hasBbvaConfigured
                        ? 'BBVA: ${previewConfig.bbvaAccount}${previewConfig.bbvaHolder.isNotEmpty ? ' · ${previewConfig.bbvaHolder}' : ''}'
                        : 'BBVA: No configurada (oculta)',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Esta actualización es 100 % declarativa y firmada con clave oficial. Puedes volver a los valores de fábrica en cualquier momento.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.end,
          actionsOverflowButtonSpacing: 8,
          actions: [
            TextButton(
              key: const ValueKey('btn_mlc1_dialog_cancel'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              key: const ValueKey('btn_mlc1_dialog_apply'),
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
              label: const Text('Aplicar Tarifas Oficiales'),
            ),
          ],
        );
      },
    );
  }

  @override
  Future<void> _confirmResetCommercialCatalog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('dialog_mlc1_reset_confirm'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restore_rounded, color: Colors.orange, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Restaurar valores de fábrica',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          '¿Deseas eliminar las tarifas sincronizadas y restaurar los precios y cuentas compilados originalmente en esta versión de la aplicación?',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            key: const ValueKey('btn_mlc1_confirm_reset_cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            key: const ValueKey('btn_mlc1_confirm_reset_ok'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Restaurar defaults'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final catalogProv = _tryCatalogProvider(listen: false);
    if (catalogProv != null) {
      await catalogProv.resetToCompiledDefaults();
    } else {
      await _commercialSyncService.resetToCompiledDefaults();
      if (mounted) {
        setState(() => _fallbackSyncedConfig = null);
      }
    }

    if (!mounted) return;
    CustomSnackBar.show(
      context,
      message: 'Catálogo restaurado a los valores de fábrica.',
      isError: false,
    );
  }

  @override
  Future<void> _launchRawWhatsAppUrl(String url) async {
    final effectiveSupportPhone = _resolveEffectiveConfig().supportPhone;
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message:
                "No se pudo abrir WhatsApp. Contacta al $effectiveSupportPhone",
            isError: true,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "Número de soporte: $effectiveSupportPhone",
          isError: false,
        );
      }
    }
  }

  @override
  Future<void> _launchWhatsAppMessage(String message) async {
    final effectiveConfig = _resolveEffectiveConfig();
    final uri = WhatsAppUriBuilder.buildSendUri(
      phone: effectiveConfig.supportPhone,
      message: message,
      fallbackPhone: effectiveConfig.supportWhatsAppUrl,
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message:
                "No se pudo abrir WhatsApp. Contacta al ${effectiveConfig.supportPhone}",
            isError: true,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "Número de soporte: ${effectiveConfig.supportPhone}",
          isError: false,
        );
      }
    }
  }


  @override
  Future<void> _shareClientState(
    LicenseProvider? licenseProv,
    String fingerprint,
  ) async {
    if (_isSharingSyncState) return;
    setState(() => _isSharingSyncState = true);
    try {
      GoogleDriveBackupProvider? driveProv;
      try {
        driveProv = Provider.of<GoogleDriveBackupProvider?>(
          context,
          listen: false,
        );
      } catch (_) {}
      final syncService = ClientSyncService();
      final snapshot = await syncService.buildCurrentSnapshot(
        licenseProv: licenseProv,
        driveProv: driveProv,
        overrideHw: fingerprint,
      );
      final file = await syncService.createMlsyncTempFile(snapshot);
      final shared = await syncService.shareMlsyncFile(
        file,
        hardwareId: fingerprint,
      );
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: shared
              ? "Ficha de estado generada y compartida exitosamente"
              : "Menú de compartir cerrado",
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "No se pudo compartir la ficha de estado: $e",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSharingSyncState = false);
    }
  }
}
