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
import 'package:app_movil/features/auth/widgets/eula_acceptance_modal.dart';
import 'package:app_movil/features/auth/widgets/post_update_welcome_modal.dart';
import 'package:app_movil/features/profile/screens/ai_settings_screen.dart';

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
  String? _detectedClipboardCode;
  bool _isCheckingClipboard = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboardForCode();
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
        final extracted = Ed25519LicenseValidator.extractClipboardLicenseToken(text);
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
    return Ed25519LicenseValidator.extractClipboardLicenseToken(text).isNotEmpty;
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

    final success = await licenseProv.redeemCode(clean);
    if (!mounted) return;

    if (success) {
      _codeController.clear();
      setState(() => _detectedClipboardCode = null);
      CustomSnackBar.show(
        context,
        message: licenseProv.successMessage ?? "¡Licencia activada con éxito!",
        isError: false,
      );
    } else {
      CustomSnackBar.show(
        context,
        message: licenseProv.errorMessage ?? "Error al validar la licencia.",
        isError: true,
      );
    }
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

  void _openQrScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QrScannerSheet(
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
        final capture = await controller.analyzeImage(picked.path);
        if (capture != null && capture.barcodes.isNotEmpty) {
          final code = capture.barcodes.first.rawValue;
          if (code != null && code.trim().isNotEmpty) {
            _codeController.text = code.trim();
            await _activateCode(code.trim());
            return;
          }
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
        title: const Text(
          "Licencia y Activación",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
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
            icon: const Icon(Icons.description_outlined),
            tooltip: "Ver Contrato EULA",
            onPressed: () =>
                EulaAcceptanceModal.show(context, isReadOnly: true),
          ),
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
              _buildActivationCard(licenseProv, isDark),
              const SizedBox(height: 16),

              // Catálogo de Planes y Medios de Pago Peruanos
              _buildPricingAndPaymentCatalog(fingerprint, isDark),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "$daysRemaining días restantes",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: daysRemaining <= 5
                            ? Colors.amber[800]
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                  backgroundColor: isDark ? Colors.white10 : Colors.black12,
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
            const SizedBox(height: 14),

            // Chip Interactivo de Escaneos IA Disponibles
            InkWell(
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
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
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
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Identificador de Hardware (Hardware ID)
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  Widget _buildPricingAndPaymentCatalog(String fingerprint, bool isDark) {
    // Tarifario Comercial Oficial Completo (7 Ítems)
    final plans = [
      {
        "name": "Mensual",
        "price": "S/ 35.00",
        "desc": "Ideal para probar el sistema mes a mes",
        "badge": "Flexible",
        "aiBadge": "+50 IA",
      },
      {
        "name": "Trimestral",
        "price": "S/ 90.00",
        "desc": "Ahorro de S/ 15 vs mensual (S/ 30/mes)",
        "badge": "Popular",
        "aiBadge": "+180 IA",
      },
      {
        "name": "Semestral",
        "price": "S/ 160.00",
        "desc": "Ahorro de S/ 50 (S/ 26.60/mes)",
        "badge": "Recomendado",
        "aiBadge": "+450 IA",
      },
      {
        "name": "Anual",
        "price": "S/ 280.00",
        "desc": "Mayor ahorro comercial (S/ 23.30/mes)",
        "badge": "Mejor Precio",
        "aiBadge": "+1,200 IA",
      },
      {
        "name": "Perpetua",
        "price": "S/ 850.00",
        "desc": "Pago único de por vida + 12 meses de updates",
        "badge": "Liberada",
        "aiBadge": "+200 IA",
      },
      {
        "name": "Bolsa Extra IA",
        "price": "S/ 20.00",
        "desc":
            "+150 escaneos acumulativos sin vencimiento para cualquier plan",
        "badge": "Bolsa IA",
        "aiBadge": "+150 IA",
      },
      {
        "name": "Pase Anual de Updates",
        "price": "S/ 150.00",
        "desc": "12 meses extra de nuevas funciones para Licencias Perpetuas",
        "badge": "Updates",
        "aiBadge": "+100 IA",
      },
    ];

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
                const Icon(
                  Icons.local_offer_rounded,
                  size: 20,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Planes Comerciales Oficiales",
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

            // Aviso de Renovación Acumulativa
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
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
                        color: isDark ? Colors.indigo[200] : Colors.indigo[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Lista de los 7 Productos del Catálogo
            ...plans.map((p) => _buildPlanTile(p, fingerprint, isDark)),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      color: const Color(0xFF6B1D90).withValues(alpha: 0.15),
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
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: OwnerLegalIdentity.supportPhone),
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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
    Map<String, String> plan,
    String fingerprint,
    bool isDark,
  ) {
    final isPerpetual = plan['name'] == 'Perpetua';
    final isExtraAi = plan['name'] == 'Bolsa Extra IA';

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      plan['name']!,
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
                        plan['badge']!,
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
                        plan['aiBadge']!,
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
                  plan['desc']!,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                plan['price']!,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isPerpetual
                      ? Colors.purple
                      : (isDark ? Colors.lightBlue[200] : Colors.blue[900]),
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () {
                  _showOrderPlanModal(
                    planName: plan['name']!,
                    price: plan['price']!,
                    desc: plan['desc']!,
                    aiScansBadge: plan['aiBadge']!,
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
            ],
          ),
        ],
      ),
    );
  }

  void _showOrderPlanModal({
    required String planName,
    required String price,
    required String desc,
    required String aiScansBadge,
    required String fingerprint,
    required bool isDark,
  }) {
    final defaultMessage = OwnerLegalIdentity.buildPlanOrderMessage(
      planName: planName,
      price: price,
      hardwareId: fingerprint,
    );

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
}

/// Modal Bottom Sheet interactivo y editable al pulsar "Pedir"
class OrderPlanBottomSheet extends StatefulWidget {
  final String planName;
  final String price;
  final String desc;
  final String aiScansBadge;
  final String hardwareId;
  final String defaultMessage;
  final bool isDark;
  final ValueChanged<String> onSendWhatsApp;

  const OrderPlanBottomSheet({
    super.key,
    required this.planName,
    required this.price,
    required this.desc,
    required this.aiScansBadge,
    required this.hardwareId,
    required this.defaultMessage,
    required this.isDark,
    required this.onSendWhatsApp,
  });

  @override
  State<OrderPlanBottomSheet> createState() => _OrderPlanBottomSheetState();
}

class _OrderPlanBottomSheetState extends State<OrderPlanBottomSheet> {
  late final TextEditingController _msgController;

  bool _yapePlinActive = false;
  bool _bankAccountsActive = false;
  bool _commercialInvoiceActive = false;

  static const String _yapePlinLine =
      "\n• Estado: Pago realizado vía Yape/Plin. Adjunto comprobante.";
  static const String _bankAccountLine =
      "\n• Consulta: Solicito números de cuenta para transferencia bancaria.";
  static const String _invoiceLine =
      "\n• Requerimiento: Solicito emisión de Factura con RUC.";

  @override
  void initState() {
    super.initState();
    _msgController = TextEditingController(text: widget.defaultMessage);
    _msgController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _msgController.removeListener(_onTextChanged);
    _msgController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _msgController.text;
    final hasYape = text.contains("Pago realizado vía Yape/Plin");
    final hasBank = text.contains(
      "Solicito números de cuenta para transferencia bancaria",
    );
    final hasInv = text.contains("Solicito emisión de Factura con RUC");
    if (hasYape != _yapePlinActive ||
        hasBank != _bankAccountsActive ||
        hasInv != _commercialInvoiceActive) {
      setState(() {
        _yapePlinActive = hasYape;
        _bankAccountsActive = hasBank;
        _commercialInvoiceActive = hasInv;
      });
    } else {
      setState(() {});
    }
  }

  void _toggleLine(bool isSelected, String line) {
    String current = _msgController.text;
    final trimmedLine = line.trim();
    if (isSelected) {
      if (!current.contains(trimmedLine)) {
        if (current.isNotEmpty && !current.endsWith('\n')) {
          current = '$current$line';
        } else {
          current = '$current$trimmedLine';
        }
      }
    } else {
      current = current.replaceAll(line, '').replaceAll(trimmedLine, '');
      current = current.replaceAll(RegExp(r'\n{3,}'), '\n\n').trimRight();
    }
    _msgController.text = current;
    _msgController.selection = TextSelection.fromPosition(
      TextPosition(offset: _msgController.text.length),
    );
  }

  void _resetText() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _msgController.text = widget.defaultMessage;
      _yapePlinActive = false;
      _bankAccountsActive = false;
      _commercialInvoiceActive = false;
    });
    CustomSnackBar.show(
      context,
      message: "Texto restablecido al formato oficial",
      isError: false,
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSummaryCard(isDark),
                    const SizedBox(height: 14),
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
                _toggleLine(val, _yapePlinLine);
              },
              isDark: isDark,
            ),
            _buildComplementChip(
              label: "Pedir BCP/BBVA",
              icon: Icons.account_balance_outlined,
              isSelected: _bankAccountsActive,
              onSelected: (val) {
                FocusManager.instance.primaryFocus?.unfocus();
                _toggleLine(val, _bankAccountLine);
              },
              isDark: isDark,
            ),
            _buildComplementChip(
              label: "Necesito Factura",
              icon: Icons.receipt_long_outlined,
              isSelected: _commercialInvoiceActive,
              onSelected: (val) {
                FocusManager.instance.primaryFocus?.unfocus();
                _toggleLine(val, _invoiceLine);
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
          minLines: 4,
          maxLines: 6,
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

/// Modal / Sheet de Escáner QR con soporte de cámara real y fallback asistido para tests
class _QrScannerSheet extends StatefulWidget {
  final Function(String code) onCodeScanned;

  const _QrScannerSheet({required this.onCodeScanned});

  @override
  State<_QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<_QrScannerSheet> {
  final MobileScannerController _controller = MobileScannerController();
  final TextEditingController _fallbackController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    _fallbackController.dispose();
    super.dispose();
  }

  void _handleDetected(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue;
    if (code != null && code.isNotEmpty) {
      _isProcessing = true;
      widget.onCodeScanned(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Escanear Código QR",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.photo_library_rounded,
                      color: Colors.teal,
                    ),
                    tooltip: "Desde Galería",
                    onPressed: () async {
                      try {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (picked != null) {
                          final capture = await _controller.analyzeImage(
                            picked.path,
                          );
                          if (capture != null && capture.barcodes.isNotEmpty) {
                            final code = capture.barcodes.first.rawValue;
                            if (code != null && code.trim().isNotEmpty) {
                              widget.onCodeScanned(code.trim());
                              return;
                            }
                          }
                          if (context.mounted) {
                            CustomSnackBar.show(
                              context,
                              message:
                                  "No se detectó ningún código QR en la imagen.",
                              isError: true,
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          CustomSnackBar.show(
                            context,
                            message: "Error al leer imagen: $e",
                            isError: true,
                          );
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Apunta la cámara al código QR de activación oficial.",
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),

          // Visor de Cámara con MobileScanner
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: _handleDetected,
                  ),
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Fallback de simulación / pegado para pruebas automatizadas o sin cámara
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fallbackController,
                  decoration: InputDecoration(
                    hintText: "O pega el código QR aquí...",
                    hintStyle: const TextStyle(fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final text = _fallbackController.text.trim();
                  if (text.isNotEmpty) {
                    widget.onCodeScanned(text);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                child: const Text("Aplicar"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
