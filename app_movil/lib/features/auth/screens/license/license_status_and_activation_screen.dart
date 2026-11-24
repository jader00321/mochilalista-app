import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math' as math;

import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/config/app_changelog_registry.dart';
import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/services/license/ed25519_license_validator.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/services/scanner/qr_gallery_decoder_service.dart';
import 'package:app_movil/features/auth/screens/license/widgets/license_activation_feedback_modal.dart';
import 'package:app_movil/features/auth/widgets/eula_acceptance_modal.dart';
import 'package:app_movil/features/auth/widgets/post_update_welcome_modal.dart';
import 'package:app_movil/features/profile/screens/ai_settings_screen.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/tour/configs/license_status_tour.dart';
import 'package:app_movil/core/services/sync/client_sync_service.dart';
import 'package:app_movil/core/providers/google_drive_backup_provider.dart';

/// Pantalla de Estado de Licencia, Activación Dual (QR / Portapapeles) y Catálogo Comercial
class LicenseStatusAndActivationScreen extends StatefulWidget {
  final String? welcomeTrialNotice;

  const LicenseStatusAndActivationScreen({super.key, this.welcomeTrialNotice});

  /// Helper puro para construir la URI oficial de WhatsApp a partir de un mensaje personalizado
  static Uri buildCustomWhatsAppOrderUri(String customMessage) {
    return OwnerLegalIdentity.buildCustomWhatsAppOrderUri(customMessage);
  }

  @override
  State<LicenseStatusAndActivationScreen> createState() =>
      _LicenseStatusAndActivationScreenState();
}

class _LicenseStatusAndActivationScreenState
    extends State<LicenseStatusAndActivationScreen> {
  final TextEditingController _codeController = TextEditingController();
  final _tourKeys = LicenseStatusTourKeys();
  String? _detectedClipboardCode;
  bool _isCheckingClipboard = false;
  bool? _isPlansExpanded;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboardForCode();
      InteractiveTourService.maybeStartAutomaticTour(
        context,
        LicenseStatusTour.buildConfig(keys: _tourKeys),
      );
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// Revisa si el portapapeles contiene un código válido (formato ML9- con estructura Ed25519)
  Future<void> _checkClipboardForCode() async {
    if (!mounted || _isCheckingClipboard) return;
    _isCheckingClipboard = true;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (_isValidCandidateCode(text)) {
        final extracted = Ed25519LicenseValidator.extractClipboardLicenseToken(
          text,
        );
        if (mounted) {
          setState(() {
            _detectedClipboardCode = extracted;
          });
        }
      } else {
        if (mounted && _detectedClipboardCode != null) {
          setState(() {
            _detectedClipboardCode = null;
          });
        }
      }
    } catch (_) {
    } finally {
      _isCheckingClipboard = false;
    }
  }

  bool _isValidCandidateCode(String text) {
    if (text.isEmpty) return false;
    return Ed25519LicenseValidator.extractClipboardLicenseToken(
      text,
    ).isNotEmpty;
  }

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

  Future<void> _activateCode(String code) async {
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

  Future<void> _launchRawWhatsAppUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message:
                "No se pudo abrir WhatsApp. Contacta al ${OwnerLegalIdentity.supportPhone}",
            isError: true,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "Número de soporte: ${OwnerLegalIdentity.supportPhone}",
          isError: false,
        );
      }
    }
  }

  Future<void> _launchWhatsAppMessage(String message) async {
    final cleanDigits = OwnerLegalIdentity.supportPhone.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final baseUri = cleanDigits.length >= 8
        ? "https://wa.me/$cleanDigits"
        : OwnerLegalIdentity.supportWhatsAppUrl;
    final uri = Uri.parse("$baseUri?text=${Uri.encodeComponent(message)}");
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message:
                "No se pudo abrir WhatsApp. Contacta al ${OwnerLegalIdentity.supportPhone}",
            isError: true,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "Número de soporte: ${OwnerLegalIdentity.supportPhone}",
          isError: false,
        );
      }
    }
  }

  bool _isSharingSyncState = false;

  /// Vía A: Genera la ficha offline .mlsync y la comparte mediante el menú nativo del SO.
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

  void _openQrScanner({Widget? scannerPreviewOverride}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QrScannerSheet(
        scannerPreviewOverride: scannerPreviewOverride,
        onCodeScanned: (scannedCode) {
          Navigator.of(ctx).pop();
          _codeController.text = scannedCode;
          _activateCode(scannedCode);
        },
      ),
    );
  }

  Future<void> _scanQrFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final controller = MobileScannerController();
      try {
        final code = await QrGalleryDecoderService.decodeFromImagePath(
          picked.path,
          analyzeFile: (path) async {
            final capture = await controller.analyzeImage(path);
            if (capture != null && capture.barcodes.isNotEmpty) {
              return capture.barcodes.first.rawValue;
            }
            return null;
          },
        );

        if (code != null && code.trim().isNotEmpty) {
          _codeController.text = code.trim();
          await _activateCode(code.trim());
          return;
        }

        if (mounted) {
          CustomSnackBar.show(
            context,
            message:
                "No se detectó ningún código QR en la imagen seleccionada.",
            isError: true,
          );
        }
      } finally {
        controller.dispose();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "No se pudo leer la imagen de galería: ${e.toString()}",
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final licenseProv = Provider.of<LicenseProvider?>(context);
    final license = licenseProv?.license;
    final fingerprint = licenseProv?.deviceFingerprint ?? 'ML-INIT';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            "Licencia y Activación",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: "Novedades de la Versión",
            onPressed: () => PostUpdateWelcomeModal.show(
              context,
              appVersion: AppChangelogRegistry.currentVersion,
              mode:
                  (license?.isPerpetual == true ||
                      (license?.isActive == true && license?.isTrial == false))
                  ? PostUpdateMode.activeCommercialOrPerpetual
                  : PostUpdateMode.trialOrGrace,
              barrierDismissible: true,
              isManualPreview: true,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.description_outlined),
            tooltip: "Ver Contrato EULA",
            onPressed: () =>
                EulaAcceptanceModal.show(context, isReadOnly: true),
          ),
          InfoTooltipButton(
            title: "Licencia y Activación",
            description:
                "Gestiona tu suscripción oficial, consulta tu saldo de escaneos IA, activa códigos y comunícate con soporte.",
            onStartInteractiveTour: () =>
                InteractiveTourService.startManualTour(
                  context,
                  LicenseStatusTour.buildConfig(keys: _tourKeys),
                ),
            tips: const [
              InfoTip(
                icon: Icons.card_membership_rounded,
                text:
                    "Al renovar una licencia antes de que expire, los días restantes se acumulan automáticamente.",
              ),
              InfoTip(
                icon: Icons.auto_awesome_rounded,
                text:
                    "Tus escaneos IA disponibles nunca vencen ni se pierden al renovar tu plan.",
              ),
              InfoTip(
                icon: Icons.fingerprint_rounded,
                text:
                    "Tu Hardware ID es el identificador seguro que debes enviar a soporte para activar tu licencia.",
              ),
              InfoTip(
                icon: Icons.qr_code_scanner_rounded,
                text:
                    "Puedes activar tu licencia escaneando el QR con tu cámara o importándolo desde tu galería.",
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Chip interactivo flotante si se detectó código en portapapeles
              if (_detectedClipboardCode != null) ...[
                _buildClipboardDetectedBanner(isDark),
                const SizedBox(height: 12),
              ],

              // Banner de bienvenida al periodo de prueba (instalación limpia)
              if (widget.welcomeTrialNotice != null) ...[
                _buildWelcomeTrialBanner(widget.welcomeTrialNotice!, isDark),
                const SizedBox(height: 12),
              ],

              // Tarjeta Ejecutiva de Estado de Licencia
              _buildExecutiveStatusCard(
                licenseProv,
                license,
                fingerprint,
                isDark,
              ),
              const SizedBox(height: 16),

              // Área de Activación Rápida
              KeyedSubtree(
                key: _tourKeys.activationDualKey,
                child: _buildActivationCard(licenseProv, isDark),
              ),
              const SizedBox(height: 16),

              // Catálogo de Planes y Medios de Pago Peruanos
              _buildPricingAndPaymentCatalog(license, fingerprint, isDark),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClipboardDetectedBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.content_paste_go_rounded,
            color: Colors.green,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Código detectado en portapapeles",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
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
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Pegar y Activar",
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildExecutiveStatusCard(
    LicenseProvider? licenseProv,
    LicenseModel? license,
    String fingerprint,
    bool isDark,
  ) {
    final isPerpetual = license?.isPerpetual ?? false;
    final daysRemaining = license?.daysRemaining ?? 30;
    final dateFormat = DateFormat('dd/MM/yyyy');

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
                            Clipboard.setData(ClipboardData(text: fingerprint));
                            CustomSnackBar.show(
                              context,
                              message:
                                  "Hardware ID $fingerprint copiado al portapapeles",
                              isError: false,
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

  Widget _buildActivationCard(LicenseProvider? licenseProv, bool isDark) {
    final isLoading = licenseProv?.isLoading ?? false;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E28) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.vpn_key_rounded, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Activar Código de Licencia",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              "Ingresa el código proporcionado por soporte oficial o escanea el código QR oficial enviado a tu WhatsApp.",
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),

            // Input de código con botón rápido de pegado
            TextField(
              controller: _codeController,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                hintText: "Ejemplo: ML9-...",
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                prefixIcon: const Icon(Icons.key_rounded, size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste_rounded, size: 18),
                  tooltip: "Pegar del portapapeles",
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      final raw = data!.text!.trim();
                      final extracted =
                          Ed25519LicenseValidator.extractLicenseToken(raw);
                      _codeController.text = extracted.isNotEmpty
                          ? 'ML9-$extracted'
                          : raw;
                    }
                  },
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF14141C)
                    : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
              ),
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),

            // Botón Principal de Ancho Completo
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => _activateCode(_codeController.text),
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: Text(
                  isLoading ? "Validando..." : "Activar Código de Licencia",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Fila Secundaria de Botones QR con Simetría Geométrica y Misma Altura
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 300;
                final btnCamera = OutlinedButton.icon(
                  onPressed: _openQrScanner,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 17),
                  label: const Text(
                    "Escanear QR",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: Colors.blue[700],
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );

                final btnGallery = OutlinedButton.icon(
                  onPressed: isLoading ? null : _scanQrFromGallery,
                  icon: const Icon(
                    Icons.photo_library_rounded,
                    size: 17,
                    color: Colors.teal,
                  ),
                  label: const Text(
                    "QR desde Galería",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: Colors.teal[800],
                    side: BorderSide(color: Colors.teal.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      btnCamera,
                      const SizedBox(height: 6),
                      btnGallery,
                    ],
                  );
                }

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: btnCamera),
                      const SizedBox(width: 8),
                      Expanded(child: btnGallery),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingAndPaymentCatalog(
    LicenseModel? license,
    String fingerprint,
    bool isDark,
  ) {
    final hasPaidCommercialLicense =
        license != null && license.isActive && !license.isTrial;
    _isPlansExpanded ??= !hasPaidCommercialLicense;
    final isExpanded = _isPlansExpanded!;

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
              key: _tourKeys.pricingCatalogKey,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey("accordion_pricing_catalog_header"),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _isPlansExpanded = !_isPlansExpanded!;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_offer_rounded,
                          size: 20,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Planes Comerciales Oficiales",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (!isExpanded) ...[
                                const SizedBox(height: 3),
                                Text(
                                  "Explora 7 planes y recargas: mayor ahorro semestral/anual, Licencia Perpetua y Bolsas Extra IA sin vencimiento.",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOutCubic,
                          child: const Icon(
                            Icons.expand_more_rounded,
                            size: 22,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!isExpanded) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey("btn_toggle_expand_plans"),
                  onPressed: () {
                    setState(() {
                      _isPlansExpanded = true;
                    });
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text(
                    "Ver planes y recargas",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                    side: BorderSide(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),

                        // Aviso de Renovación Acumulativa
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Si renuevas antes de que venza tu periodo, tus días no se pierden, se suman automáticamente.",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.lightBlue[200]
                                        : Colors.blue[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Aviso de Cobertura Multinegocio y Cuota IA Compartida
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.indigo.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.storefront_rounded,
                                size: 18,
                                color: Colors.indigo,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Una sola licencia activa ampara todos los perfiles de tu negocio en este celular. La cuota de escaneos IA es compartida y acumulativa entre todos tus perfiles.",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.indigo[200]
                                        : Colors.indigo[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Lista de los 7 Productos del Catálogo Oficial
                        ...officialPlans.map(
                          (p) => _buildPlanTile(p, fingerprint, isDark),
                        ),
                        const SizedBox(height: 14),

                        const Divider(height: 1),
                        const SizedBox(height: 14),

                        // Medios de Pago Directos (Perú) con Copiado en 1 Toque y Toast Flotante
                        Text(
                          "Medios de Pago Directos (Perú):",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Tarjeta Yape / Plin con Copiado en 1 Toque
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF14141C)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6B1D90)
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.qr_code_2_rounded,
                                  color: Color(0xFF6B1D90),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Yape y Plin (Perú)",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    Text(
                                      "${OwnerLegalIdentity.supportPhone} • ${OwnerLegalIdentity.yapePlinHolder}",
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark
                                            ? Colors.grey[300]
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text: OwnerLegalIdentity.supportPhone,
                                    ),
                                  );
                                  CustomSnackBar.show(
                                    context,
                                    message:
                                        "Número Yape/Plin copiado: ${OwnerLegalIdentity.supportPhone}",
                                    isError: false,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6B1D90),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  "Copiar",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Tarjetas Bancarias Opcionales BCP / BBVA
                        _buildBankAccountsSection(isDark),
                        const SizedBox(height: 14),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final msg =
                                  "Hola Julio Angello, deseo renovar/activar mi plan en MochilaLista. Mi ID de equipo es: $fingerprint";
                              _launchWhatsAppMessage(msg);
                            },
                            icon: const Icon(Icons.chat_rounded, size: 18),
                            label: const Text(
                              "Contactar por WhatsApp para activar",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankAccountsSection(bool isDark) {
    final hasBcp = OwnerLegalIdentity.bcpAccountNumber.isNotEmpty;
    final hasBbva = OwnerLegalIdentity.bbvaAccountNumber.isNotEmpty;

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
            accountNumber: OwnerLegalIdentity.bcpAccountNumber,
            cciNumber: OwnerLegalIdentity.bcpCciNumber,
            isDark: isDark,
          ),
        if (hasBbva)
          _buildBankCard(
            bankName: "BBVA Perú",
            accountNumber: OwnerLegalIdentity.bbvaAccountNumber,
            cciNumber: OwnerLegalIdentity.bbvaCciNumber,
            isDark: isDark,
          ),
      ],
    );
  }

  Widget _buildBankCard({
    required String bankName,
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
                  Clipboard.setData(ClipboardData(text: accountNumber));
                  CustomSnackBar.show(
                    context,
                    message: "Cuenta $bankName copiada al portapapeles",
                    isError: false,
                  );
                },
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
                    Clipboard.setData(ClipboardData(text: cciNumber));
                    CustomSnackBar.show(
                      context,
                      message: "CCI $bankName copiado al portapapeles",
                      isError: false,
                    );
                  },
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
                                color:
                                    isDark ? Colors.blue[300] : Colors.blue[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 13,
                            color:
                                isDark ? Colors.blue[300] : Colors.blue[700],
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
              LicenseStatusAndActivationScreen.buildCustomWhatsAppOrderUri(msg);
          _launchRawWhatsAppUrl(uri.toString());
        },
      ),
    );
  }

  static const List<CommercialPlanDetail> officialPlans = [
    CommercialPlanDetail(
      id: "mensual",
      name: "Mensual",
      price: "S/ 35.00",
      desc: "Ideal para probar el sistema mes a mes",
      badge: "Flexible",
      aiBadge: "+50 IA",
      duration: "30 días continuos",
      aiQuota: "50 escaneos inteligentes IA incluidos",
      savings: "Tarifa flexible sin compromisos a largo plazo",
      idealFor: "Negocios que inician o desean probar la plataforma mes a mes",
      benefits: [
        "Acceso total a todos los módulos comerciales y financieros",
        "50 escaneos IA para digitalizar listas escolares y facturas",
        "Soporte técnico directo vía WhatsApp con el desarrollador",
        "Operación 100% offline garantizada para inventario y ventas",
        "Días restantes acumulables si renuevas antes del vencimiento",
      ],
    ),
    CommercialPlanDetail(
      id: "trimestral",
      name: "Trimestral",
      price: "S/ 90.00",
      desc: "Ahorro de S/ 15 vs mensual (S/ 30/mes)",
      badge: "Popular",
      aiBadge: "+180 IA",
      duration: "90 días continuos (3 meses)",
      aiQuota: "180 escaneos inteligentes IA incluidos",
      savings: "Ahorras S/ 15.00 frente a tres pagos mensuales (S/ 30.00/mes)",
      idealFor:
          "Comercios con campañas regulares de temporada escolar o festiva",
      benefits: [
        "Ahorro comercial directo frente al plan mensual",
        "180 escaneos IA acumulables con vigencia continua",
        "Copia de seguridad en Google Drive y exportación de reportes",
        "Soporte prioritario del desarrollador oficial",
        "Sin interrupciones durante un trimestre completo de ventas",
      ],
    ),
    CommercialPlanDetail(
      id: "semestral",
      name: "Semestral",
      price: "S/ 160.00",
      desc: "Ahorro de S/ 50 (S/ 26.60/mes)",
      badge: "Recomendado",
      aiBadge: "+450 IA",
      duration: "180 días continuos (6 meses)",
      aiQuota: "450 escaneos inteligentes IA incluidos",
      savings: "Ahorras S/ 50.00 frente al plan mensual (S/ 26.60/mes)",
      idealFor:
          "Librerías, bazares y papelerías que cubren toda la campaña escolar",
      benefits: [
        "Costo mensual optimizado a solo S/ 26.60 al mes",
        "450 escaneos IA para alta demanda de inicio de clases",
        "Radar Comercial y sugerencias inteligentes de precios",
        "Sincronización multi-dispositivo y respaldo en la nube",
        "Asesoría directa en configuración y carga de catálogos",
      ],
    ),
    CommercialPlanDetail(
      id: "anual",
      name: "Anual",
      price: "S/ 280.00",
      desc: "Mayor ahorro comercial (S/ 23.30/mes)",
      badge: "Mejor Precio",
      aiBadge: "+1,200 IA",
      duration: "365 días continuos (1 año completo)",
      aiQuota: "1,200 escaneos inteligentes IA incluidos",
      savings: "Máximo ahorro anual: S/ 140.00 de ahorro (S/ 23.30/mes)",
      idealFor:
          "Empresas y librerías consolidadas que buscan máxima rentabilidad",
      benefits: [
        "Tarifa mensual más económica del mercado (S/ 23.30/mes)",
        "1,200 escaneos IA para cubrir todo el año sin preocupaciones",
        "Todas las actualizaciones de versión mayores y menores incluidas",
        "Soporte VIP directo y asistencia en restauraciones",
        "Garantía de continuidad operativa sin cortes durante todo el año",
      ],
    ),
    CommercialPlanDetail(
      id: "perpetua",
      name: "Perpetua",
      price: "S/ 850.00",
      desc: "Pago único de por vida + 12 meses de updates",
      badge: "Liberada",
      aiBadge: "+200 IA",
      duration: "Vitalicia (De por vida, sin caducidad)",
      aiQuota: "200 escaneos IA iniciales incluidos",
      savings:
          "Pago único definitivo sin costos de suscripción mensual ni anual",
      idealFor:
          "Dueños de negocio que desean adquirir el software en propiedad definitiva",
      isPerpetual: true,
      benefits: [
        "Licencia de por vida para el dispositivo vinculado",
        "Cero pagos recurrentes obligatorios",
        "12 meses completos de actualizaciones de nuevas funciones incluidos",
        "Uso 100% offline indefinido de todas las funciones base",
        "Opción de transferir licencia en caso de cambio de celular certificado",
      ],
    ),
    CommercialPlanDetail(
      id: "bolsa_extra_ia",
      name: "Bolsa Extra IA",
      price: "S/ 20.00",
      desc: "+150 escaneos acumulativos sin vencimiento para cualquier plan",
      badge: "Bolsa IA",
      aiBadge: "+150 IA",
      duration: "Permanente (No expira nunca)",
      aiQuota: "+150 escaneos IA acumulativos",
      savings: "Tarifa reducida por escaneo: S/ 0.13 por escaneo inteligente",
      idealFor:
          "Negocios con picos intensivos de escaneo OCR de facturas y listas",
      isExtraAi: true,
      benefits: [
        "Recarga inmediata de 150 escaneos de alta precisión con Gemini IA",
        "Tus escaneos nunca vencen y se suman a tu saldo actual",
        "Compatible con cualquier plan activo (Mensual, Anual o Perpetua)",
        "Puede adquirirse tantas veces como sea necesario",
        "Escaneo instantáneo de listas escolares manuscritas y facturas físicas",
      ],
    ),
    CommercialPlanDetail(
      id: "pase_anual_updates",
      name: "Pase Anual de Updates",
      price: "S/ 150.00",
      desc: "12 meses extra de nuevas funciones para Licencias Perpetuas",
      badge: "Updates",
      aiBadge: "+100 IA",
      duration: "365 días de actualizaciones de versión",
      aiQuota: "+100 escaneos IA incluidos con la renovación",
      savings:
          "Extensión económica para mantener el software al día con nuevas normas",
      idealFor:
          "Usuarios de Licencia Perpetua que desean seguir recibiendo mejoras continuas",
      isUpdatePass: true,
      benefits: [
        "12 meses adicionales de acceso a nuevas funciones y mejoras",
        "100 escaneos IA de regalo con la renovación",
        "Compatibilidad con las últimas versiones de Android y cambios tributarios",
        "Tu licencia base sigue funcionando de por vida aunque no renueves el pase",
        "Soporte prioritario continuo del desarrollador oficial",
      ],
    ),
  ];
}

/// Detalle estructurado de un plan comercial oficial para el modal flotante
class CommercialPlanDetail {
  final String id;
  final String name;
  final String price;
  final String desc;
  final String badge;
  final String aiBadge;
  final String duration;
  final String aiQuota;
  final String savings;
  final String idealFor;
  final List<String> benefits;
  final bool isPerpetual;
  final bool isExtraAi;
  final bool isUpdatePass;

  const CommercialPlanDetail({
    required this.id,
    required this.name,
    required this.price,
    required this.desc,
    required this.badge,
    required this.aiBadge,
    required this.duration,
    required this.aiQuota,
    required this.savings,
    required this.idealFor,
    required this.benefits,
    this.isPerpetual = false,
    this.isExtraAi = false,
    this.isUpdatePass = false,
  });
}

/// Modal flotante de beneficios y detalles técnicos del plan comercial
class PlanDetailBottomSheet extends StatelessWidget {
  final CommercialPlanDetail plan;
  final String fingerprint;
  final bool isDark;

  const PlanDetailBottomSheet({
    super.key,
    required this.plan,
    required this.fingerprint,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    Color themeColor;
    if (plan.isPerpetual) {
      themeColor = Colors.purple;
    } else if (plan.isExtraAi) {
      themeColor = Colors.teal;
    } else {
      themeColor = Colors.blue[700]!;
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.verified_outlined,
                    color: themeColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Plan ${plan.name}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Beneficios oficiales y especificaciones técnicas",
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(false),
                  tooltip: "Cerrar",
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white10 : Colors.black12,
          ),

          // Body scrollable
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero Card con Precio y Badges
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF14141C)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: themeColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    plan.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: themeColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      plan.badge,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: themeColor,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      plan.aiBadge,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              plan.price,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: themeColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          plan.desc,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Ficha técnica
                  _buildSpecRow(
                    icon: Icons.calendar_month_rounded,
                    label: "Duración / Cobertura:",
                    value: plan.duration,
                    iconColor: Colors.blue,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 6),
                  _buildSpecRow(
                    icon: Icons.auto_awesome_rounded,
                    label: "Cuota de Inteligencia Artificial:",
                    value: plan.aiQuota,
                    iconColor: Colors.purple,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 6),
                  _buildSpecRow(
                    icon: Icons.savings_outlined,
                    label: "Ahorro comercial:",
                    value: plan.savings,
                    iconColor: Colors.green,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 6),
                  _buildSpecRow(
                    icon: Icons.storefront_outlined,
                    label: "Recomendado para:",
                    value: plan.idealFor,
                    iconColor: Colors.amber[700]!,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),

                  // Lista de beneficios
                  Text(
                    "Beneficios Destacados:",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey[200] : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...plan.benefits.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              b,
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.35,
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Nota de Garantía Oficial y Operación Offline
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          size: 16,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Garantía oficial MochilaLista: Funcionamiento 100% offline garantizado. No requiere conexión permanente para ventas ni control de stock.",
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: isDark
                                  ? Colors.green[200]
                                  : Colors.green[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom actions (SafeArea)
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        foregroundColor:
                            isDark ? Colors.white70 : Colors.black87,
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ),
                      child: const Text(
                        "Cerrar",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      key: const ValueKey("btn_modal_pedir_este_plan"),
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.shopping_bag_rounded, size: 18),
                      label: Text(
                        "Pedir (${plan.price})",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141C) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
                children: [
                  TextSpan(
                    text: "$label ",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal Bottom Sheet interactivo y editable al pulsar "Pedir"
class OrderPlanBottomSheet extends StatefulWidget {
  final String planName;
  final String price;
  final String desc;
  final String aiScansBadge;
  final String hardwareId;
  final String defaultMessage;
  final String? syncToken;
  final bool isDark;
  final ValueChanged<String> onSendWhatsApp;

  static const String yapePlinLine =
      "• Estado: Pago realizado vía Yape/Plin. Adjunto comprobante.";
  static const String bankAccountLine =
      "• Consulta: Solicito números de cuenta para transferencia bancaria.";
  static const String invoiceLine =
      "• Requerimiento: Solicito emisión de Factura con RUC.";

  const OrderPlanBottomSheet({
    super.key,
    required this.planName,
    required this.price,
    required this.desc,
    required this.aiScansBadge,
    required this.hardwareId,
    required this.defaultMessage,
    this.syncToken,
    required this.isDark,
    required this.onSendWhatsApp,
  });

  /// Extrae el cuerpo libre del mensaje escrito por el usuario, despojándolo de
  /// tokens técnicos `MLS1-...` y de líneas correspondientes a complementos rápidos conocidos.
  static String extractUserBody(String fullText) {
    // 1. Quitar referencia de soporte MLS1 y regex general de sync tokens
    var body = ClientSyncService().removeSyncTokenFromMessage(fullText);

    // 2. Quitar complementos rápidos conocidos
    body = body.replaceAll(yapePlinLine, '');
    body = body.replaceAll(bankAccountLine, '');
    body = body.replaceAll(invoiceLine, '');

    // Variaciones defensivas por si el usuario editó espacios o viñetas
    body = body.replaceAll(
      RegExp(
        r'•\s*Estado:\s*Pago realizado vía Yape/Plin\.\s*Adjunto comprobante\.?',
      ),
      '',
    );
    body = body.replaceAll(
      RegExp(
        r'•\s*Consulta:\s*Solicito números de cuenta para transferencia bancaria\.?',
      ),
      '',
    );
    body = body.replaceAll(
      RegExp(
        r'•\s*Requerimiento:\s*Solicito emisión de Factura con RUC\.?',
      ),
      '',
    );

    // 3. Normalizar saltos de línea repetidos
    body = body.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return body.trimRight();
  }

  /// Compone el mensaje final en 3 bloques estructurados:
  /// Bloque 1: Cuerpo del usuario / texto libre base
  /// Bloque 2: Complementos rápidos activos ordenados
  /// Bloque 3: Pie técnico de soporte (`Ref. soporte: MLS1-...`) estrictamente al final
  static String composeMessage({
    required String userBody,
    bool yapePlin = false,
    bool bankAccounts = false,
    bool invoice = false,
    bool includeLicenseRef = true,
    String? syncToken,
  }) {
    final cleanBody = userBody.trimRight();
    final complements = <String>[];
    if (yapePlin) complements.add(yapePlinLine);
    if (bankAccounts) complements.add(bankAccountLine);
    if (invoice) complements.add(invoiceLine);

    String result;
    if (complements.isNotEmpty) {
      if (cleanBody.isNotEmpty) {
        result = '$cleanBody\n\n${complements.join('\n')}';
      } else {
        result = complements.join('\n');
      }
    } else {
      result = cleanBody;
    }

    if (includeLicenseRef && syncToken != null && syncToken.isNotEmpty) {
      result = ClientSyncService().appendSyncTokenToMessage(result, syncToken);
    }

    return result;
  }

  @override
  State<OrderPlanBottomSheet> createState() => _OrderPlanBottomSheetState();
}

class _OrderPlanBottomSheetState extends State<OrderPlanBottomSheet> {
  late final TextEditingController _msgController;

  bool _yapePlinActive = false;
  bool _bankAccountsActive = false;
  bool _commercialInvoiceActive = false;
  bool _includeLicenseRef = true;
  bool _isInternalUpdating = false;

  @override
  void initState() {
    super.initState();
    final initialBody = OrderPlanBottomSheet.extractUserBody(
      widget.defaultMessage,
    );
    final initialMessage = OrderPlanBottomSheet.composeMessage(
      userBody: initialBody,
      yapePlin: false,
      bankAccounts: false,
      invoice: false,
      includeLicenseRef: _includeLicenseRef,
      syncToken: widget.syncToken,
    );
    _msgController = TextEditingController(text: initialMessage);
    _msgController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _msgController.removeListener(_onTextChanged);
    _msgController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_isInternalUpdating) return;
    final text = _msgController.text;
    final hasYape = text.contains("Pago realizado vía Yape/Plin");
    final hasBank = text.contains(
      "Solicito números de cuenta para transferencia bancaria",
    );
    final hasInv = text.contains("Solicito emisión de Factura con RUC");
    final hasSync = ClientSyncService().messageContainsSyncToken(text);

    if (hasYape != _yapePlinActive ||
        hasBank != _bankAccountsActive ||
        hasInv != _commercialInvoiceActive ||
        hasSync != _includeLicenseRef) {
      setState(() {
        _yapePlinActive = hasYape;
        _bankAccountsActive = hasBank;
        _commercialInvoiceActive = hasInv;
        _includeLicenseRef = hasSync;
      });
    } else {
      setState(() {});
    }
  }

  void _toggleChip(String chipType, bool isSelected) {
    final currentText = _msgController.text;
    final userBody = OrderPlanBottomSheet.extractUserBody(currentText);

    if (chipType == 'yape') _yapePlinActive = isSelected;
    if (chipType == 'bank') _bankAccountsActive = isSelected;
    if (chipType == 'invoice') _commercialInvoiceActive = isSelected;

    final composed = OrderPlanBottomSheet.composeMessage(
      userBody: userBody,
      yapePlin: _yapePlinActive,
      bankAccounts: _bankAccountsActive,
      invoice: _commercialInvoiceActive,
      includeLicenseRef: _includeLicenseRef,
      syncToken: widget.syncToken,
    );

    _isInternalUpdating = true;
    _msgController.text = composed;
    _msgController.selection = TextSelection.fromPosition(
      TextPosition(offset: _msgController.text.length),
    );
    _isInternalUpdating = false;
    setState(() {});
  }

  void _onLicenseRefSwitchChanged(bool val) {
    final currentText = _msgController.text;
    final userBody = OrderPlanBottomSheet.extractUserBody(currentText);
    _includeLicenseRef = val;

    final composed = OrderPlanBottomSheet.composeMessage(
      userBody: userBody,
      yapePlin: _yapePlinActive,
      bankAccounts: _bankAccountsActive,
      invoice: _commercialInvoiceActive,
      includeLicenseRef: _includeLicenseRef,
      syncToken: widget.syncToken,
    );

    _isInternalUpdating = true;
    _msgController.text = composed;
    _msgController.selection = TextSelection.fromPosition(
      TextPosition(offset: _msgController.text.length),
    );
    _isInternalUpdating = false;
    setState(() {});
  }

  void _resetText() {
    FocusManager.instance.primaryFocus?.unfocus();
    final defaultBody = OrderPlanBottomSheet.extractUserBody(
      widget.defaultMessage,
    );
    _yapePlinActive = false;
    _bankAccountsActive = false;
    _commercialInvoiceActive = false;
    _includeLicenseRef = true;

    final composed = OrderPlanBottomSheet.composeMessage(
      userBody: defaultBody,
      yapePlin: false,
      bankAccounts: false,
      invoice: false,
      includeLicenseRef: true,
      syncToken: widget.syncToken,
    );

    _isInternalUpdating = true;
    _msgController.text = composed;
    _msgController.selection = TextSelection.fromPosition(
      TextPosition(offset: _msgController.text.length),
    );
    _isInternalUpdating = false;
    setState(() {});

    CustomSnackBar.show(
      context,
      message: "Texto restablecido al formato oficial",
      isError: false,
    );
  }

  Widget _buildLicenseRefSwitch(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141C) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _includeLicenseRef
              ? Colors.green.withValues(alpha: 0.35)
              : (isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: (_includeLicenseRef ? Colors.green : Colors.grey)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.verified_user_outlined,
              size: 18,
              color: _includeLicenseRef ? Colors.green[700] : Colors.grey,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Incluir datos de mi licencia para atención rápida",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Ayuda a verificar tu plan y agilizar tu solicitud",
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: const ValueKey("switch_include_license_ref"),
            value: _includeLicenseRef,
            activeThumbColor: Colors.green,
            activeTrackColor: Colors.green.withValues(alpha: 0.3),
            onChanged: _onLicenseRefSwitchChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final padding = MediaQuery.paddingOf(context);
    final double bottomSafety =
        math.max(
          viewInsets.bottom,
          math.max(viewPadding.bottom, padding.bottom),
        ) +
        12.0;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E28) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Zona 1 — Cabecera Ejecutiva Fija
            _buildFixedHeader(isDark),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.white10 : Colors.black12,
            ),

            // Zona 2 — Cuerpo Desplazable Cómodo (Flexible + SingleChildScrollView)
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSummaryCard(isDark),
                    const SizedBox(height: 12),
                    _buildLicenseRefSwitch(isDark),
                    _buildQuickChips(isDark),
                    const SizedBox(height: 14),
                    _buildEditableMessageField(isDark),
                  ],
                ),
              ),
            ),

            // Zona 3 — Zona de Acciones Inferior Fija (100% Protegida)
            _buildFixedActions(isDark, bottomSafety),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedHeader(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shopping_bag_rounded,
                  color: Colors.green,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Solicitar ${widget.planName}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Revisa y personaliza tu mensaje antes de enviarlo",
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: "Cerrar",
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141C) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      widget.planName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.aiScansBadge,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.price,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.desc,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.phonelink_setup_rounded,
                size: 16,
                color: Colors.blue,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Hardware ID: ${widget.hardwareId}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                  ),
                ),
              ),
              InkWell(
                key: const ValueKey("copy_hardware_id_btn"),
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Clipboard.setData(ClipboardData(text: widget.hardwareId));
                  CustomSnackBar.show(
                    context,
                    message: "Hardware ID copiado (${widget.hardwareId})",
                    isError: false,
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.copy_rounded,
                        size: 13,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Copiar ID",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.blue[300] : Colors.blue[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChips(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Complementos rápidos (opcional):",
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildComplementChip(
              label: "Ya hice Yape/Plin",
              icon: Icons.check_circle_outline_rounded,
              isSelected: _yapePlinActive,
              onSelected: (val) {
                FocusManager.instance.primaryFocus?.unfocus();
                _toggleChip('yape', val);
              },
              isDark: isDark,
            ),
            _buildComplementChip(
              label: "Pedir BCP/BBVA",
              icon: Icons.account_balance_outlined,
              isSelected: _bankAccountsActive,
              onSelected: (val) {
                FocusManager.instance.primaryFocus?.unfocus();
                _toggleChip('bank', val);
              },
              isDark: isDark,
            ),
            _buildComplementChip(
              label: "Necesito Factura",
              icon: Icons.receipt_long_outlined,
              isSelected: _commercialInvoiceActive,
              onSelected: (val) {
                FocusManager.instance.primaryFocus?.unfocus();
                _toggleChip('invoice', val);
              },
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComplementChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required ValueChanged<bool> onSelected,
    required bool isDark,
  }) {
    final activeColor = Colors.blue[700]!;
    return FilterChip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.blue[300] : Colors.blue[700]),
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.grey[200] : Colors.grey[800]),
        ),
      ),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: activeColor,
      backgroundColor: isDark
          ? const Color(0xFF262636)
          : const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected
              ? activeColor
              : (isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
      onSelected: (val) {
        FocusManager.instance.primaryFocus?.unfocus();
        onSelected(val);
      },
    );
  }

  Widget _buildEditableMessageField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "Mensaje (Editable)",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "${_msgController.text.length} caracteres",
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _msgController,
          minLines: 5,
          maxLines: 9,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark
                ? const Color(0xFF14141C)
                : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFixedActions(bool isDark, double bottomSafety) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: bottomSafety,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text(
                    "Copiar Mensaje",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    foregroundColor: isDark ? Colors.white : Colors.blue[900],
                    side: BorderSide(
                      color: isDark
                          ? Colors.white24
                          : Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Clipboard.setData(ClipboardData(text: _msgController.text));
                    CustomSnackBar.show(
                      context,
                      message: "Mensaje copiado al portapapeles",
                      isError: false,
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text(
                    "Restablecer",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange[800],
                    side: BorderSide(
                      color: Colors.orange.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _resetText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.chat_rounded, size: 20),
              label: const Text(
                "Enviar por WhatsApp",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                widget.onSendWhatsApp(_msgController.text);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter que dibuja las 4 esquinas estilizadas del marco y el haz animado de escaneo
class _ScannerOverlayPainter extends CustomPainter {
  final double animationProgress;
  final Color primaryColor;

  _ScannerOverlayPainter({
    required this.animationProgress,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.35);
    final scanSide = math.min(size.width * 0.76, 210.0);
    final scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanSide,
      height: scanSide,
    );

    // Fondo oscurecido con ventana transparente central
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(backgroundPath, dimPaint);

    // 4 esquinas estilizadas
    final cornerPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const cornerLen = 22.0;
    final r = scanRect;

    // Superior-Izquierda
    canvas.drawLine(
      Offset(r.left, r.top + cornerLen),
      Offset(r.left, r.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(r.left, r.top),
      Offset(r.left + cornerLen, r.top),
      cornerPaint,
    );

    // Superior-Derecha
    canvas.drawLine(
      Offset(r.right - cornerLen, r.top),
      Offset(r.right, r.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(r.right, r.top),
      Offset(r.right, r.top + cornerLen),
      cornerPaint,
    );

    // Inferior-Izquierda
    canvas.drawLine(
      Offset(r.left, r.bottom - cornerLen),
      Offset(r.left, r.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(r.left, r.bottom),
      Offset(r.left + cornerLen, r.bottom),
      cornerPaint,
    );

    // Inferior-Derecha
    canvas.drawLine(
      Offset(r.right - cornerLen, r.bottom),
      Offset(r.right, r.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(r.right, r.bottom),
      Offset(r.right, r.bottom - cornerLen),
      cornerPaint,
    );

    // Haz de escaneo animado suave
    final beamY = r.top + (r.height * animationProgress);
    final beamPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primaryColor.withValues(alpha: 0.0),
          primaryColor.withValues(alpha: 0.85),
          primaryColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(r.left, beamY - 1, r.width, 2.5))
      ..strokeWidth = 2.5;

    canvas.drawLine(
      Offset(r.left + 4, beamY),
      Offset(r.right - 4, beamY),
      beamPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.primaryColor != primaryColor;
  }
}

/// Modal / Sheet de Escáner QR con soporte de cámara real, controles para PC (Zoom, Linterna, Focus)
/// y fallback asistido para tests y teclado virtual
class QrScannerSheet extends StatefulWidget {
  final Function(String code) onCodeScanned;
  final Widget? scannerPreviewOverride;

  const QrScannerSheet({
    super.key,
    required this.onCodeScanned,
    this.scannerPreviewOverride,
  });

  @override
  State<QrScannerSheet> createState() => _QrScannerSheetState();
}

typedef _QrScannerSheet = QrScannerSheet;

class _QrScannerSheetState extends State<QrScannerSheet>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  final TextEditingController _fallbackController = TextEditingController();
  late final AnimationController _scanAnimationController;
  bool _isProcessing = false;
  double _currentZoom = 0.0;
  bool _isTorchOn = false;
  Offset? _focusPoint;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
    );
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (!isTest) {
      _scanAnimationController.repeat(reverse: true);
    } else {
      _scanAnimationController.forward();
    }
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _controller.dispose();
    _fallbackController.dispose();
    super.dispose();
  }

  void _handleDetected(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue;
    if (code != null && code.trim().isNotEmpty) {
      _isProcessing = true;
      HapticFeedback.mediumImpact();
      widget.onCodeScanned(code.trim());
    }
  }

  Future<void> _setZoom(double zoom) async {
    try {
      await _controller.setZoomScale(zoom);
      if (mounted) {
        setState(() => _currentZoom = zoom);
      }
    } catch (e) {
      debugPrint('Error configurando zoom: $e');
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) {
        setState(() => _isTorchOn = !_isTorchOn);
      }
    } catch (e) {
      debugPrint('Error conmutando linterna: $e');
    }
  }

  Future<void> _pickAndDecodeFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final code = await QrGalleryDecoderService.decodeFromImagePath(
        picked.path,
        analyzeFile: (path) async {
          final capture = await _controller.analyzeImage(path);
          if (capture != null && capture.barcodes.isNotEmpty) {
            return capture.barcodes.first.rawValue;
          }
          return null;
        },
      );

      if (code != null && code.trim().isNotEmpty) {
        if (mounted) {
          widget.onCodeScanned(code.trim());
        }
        return;
      }

      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "No se detectó ningún código QR en la imagen.",
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "Error al leer imagen de galería: $e",
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark
        ? const Color(0xFF38BDF8)
        : const Color(0xFF0284C7);

    final viewInsets = MediaQuery.viewInsetsOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final bottomPadding =
        math.max(viewInsets.bottom, viewPadding.bottom) + 16.0;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.90),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de arrastre superior
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Encabezado con título y botones de galería y cierre
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          color: primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            "Escanear Código QR",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const ValueKey('btn_scan_gallery'),
                        icon: Icon(
                          Icons.photo_library_rounded,
                          color: isDark
                              ? const Color(0xFF34D399)
                              : const Color(0xFF059669),
                        ),
                        tooltip: "Desde Galería",
                        onPressed: _pickAndDecodeFromGallery,
                      ),
                      IconButton(
                        key: const ValueKey('btn_scan_close'),
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Apunta la cámara al código QR de activación oficial.",
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),

              // Visor de Cámara con controles sobrepuestos
              SizedBox(
                height: math.min(screenHeight * 0.36, 260.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Preview de cámara o override para tests
                      if (widget.scannerPreviewOverride != null)
                        widget.scannerPreviewOverride!
                      else
                        MobileScanner(
                          controller: _controller,
                          onDetect: _handleDetected,
                        ),

                      // Overlay con marco y haz de escaneo animado
                      AnimatedBuilder(
                        animation: _scanAnimationController,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _ScannerOverlayPainter(
                              animationProgress: _scanAnimationController.value,
                              primaryColor: primaryColor,
                            ),
                          );
                        },
                      ),

                      // Tap-to-focus
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapDown: (details) {
                          setState(() {
                            _focusPoint = details.localPosition;
                          });
                        },
                      ),

                      // Indicador animado de foco táctil
                      if (_focusPoint != null)
                        Positioned(
                          left: _focusPoint!.dx - 22,
                          top: _focusPoint!.dy - 22,
                          child: TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 300),
                            tween: Tween(begin: 1.4, end: 1.0),
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFFBBF24),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.filter_center_focus_rounded,
                                      color: Color(0xFFFBBF24),
                                      size: 18,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      // Botón flotante de linterna (Flash)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: const CircleBorder(),
                          child: IconButton(
                            key: const ValueKey('btn_scan_torch'),
                            iconSize: 20,
                            icon: Icon(
                              _isTorchOn
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                              color: _isTorchOn
                                  ? const Color(0xFFFBBF24)
                                  : Colors.white70,
                            ),
                            tooltip: _isTorchOn
                                ? "Apagar linterna"
                                : "Encender linterna",
                            onPressed: _toggleTorch,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Controles de Zoom para pantallas de PC (1x, 1.5x, 2x)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Zoom:",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildZoomChip("1x", 0.0, primaryColor, isDark),
                  const SizedBox(width: 6),
                  _buildZoomChip("1.5x", 0.28, primaryColor, isDark),
                  const SizedBox(width: 6),
                  _buildZoomChip("2x", 0.55, primaryColor, isDark),
                ],
              ),
              const SizedBox(height: 8),

              // Texto guía amigable (CERO EMOJIS CRUDOS)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 15,
                      color: isDark
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Si escaneas desde una pantalla de PC, prueba el zoom 1.5x o sube la imagen desde galería.",
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.25,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Fallback de pegado manual y botón Aplicar (anti-colisión con teclado y barra de 3 botones)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('input_scan_code'),
                      controller: _fallbackController,
                      decoration: InputDecoration(
                        hintText: "O pega el código QR aquí...",
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                        prefixIcon: const Icon(Icons.paste_rounded, size: 18),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF161A22)
                            : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: primaryColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const ValueKey('btn_scan_apply'),
                    onPressed: () {
                      final text = _fallbackController.text.trim();
                      if (text.isNotEmpty) {
                        widget.onCodeScanned(text);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Aplicar",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoomChip(
    String label,
    double zoomScale,
    Color primaryColor,
    bool isDark,
  ) {
    final isSelected = (_currentZoom - zoomScale).abs() < 0.05;
    return GestureDetector(
      key: ValueKey('chip_zoom_$label'),
      onTap: () => _setZoom(zoomScale),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
        ),
      ),
    );
  }
}
