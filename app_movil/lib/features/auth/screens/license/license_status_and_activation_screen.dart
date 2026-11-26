import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';

import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/config/app_changelog_registry.dart';
import 'package:app_movil/core/utils/app_date_formatter.dart';
import 'package:app_movil/core/utils/clipboard_helper.dart';
import 'package:app_movil/core/utils/whatsapp_uri_builder.dart';
import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/commercial_catalog_provider.dart';
import 'package:app_movil/core/services/license/commercial_config_sync_service.dart';
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

import 'package:app_movil/features/auth/screens/license/widgets/commercial_plan_models.dart';
import 'package:app_movil/features/auth/screens/license/widgets/plan_detail_bottom_sheet.dart';
import 'package:app_movil/features/auth/screens/license/widgets/order_plan_bottom_sheet.dart';
import 'package:app_movil/features/auth/screens/license/widgets/qr_scanner_sheet.dart';

export 'package:app_movil/features/auth/screens/license/widgets/commercial_plan_models.dart' show CommercialPlanDetail;
export 'package:app_movil/features/auth/screens/license/widgets/plan_detail_bottom_sheet.dart';
export 'package:app_movil/features/auth/screens/license/widgets/order_plan_bottom_sheet.dart';
export 'package:app_movil/features/auth/screens/license/widgets/qr_scanner_sheet.dart';

part 'widgets/license_mlc1_sync_dialogs.dart';
part 'widgets/license_activation_card.dart';
part 'widgets/license_status_card.dart';
part 'widgets/license_catalog_section.dart';
part 'widgets/license_bank_accounts_section.dart';

/// Pantalla de Estado de Licencia, Activación Dual (QR / Portapapeles) y Catálogo Comercial
class LicenseStatusAndActivationScreen extends StatefulWidget {
  final String? welcomeTrialNotice;

  const LicenseStatusAndActivationScreen({super.key, this.welcomeTrialNotice});

  /// Helper puro para construir la URI oficial de WhatsApp a partir de un mensaje personalizado
  static Uri buildCustomWhatsAppOrderUri(
    String customMessage, {
    String? supportPhoneOverride,
  }) {
    return OwnerLegalIdentity.buildCustomWhatsAppOrderUri(
      customMessage,
      supportPhoneOverride: supportPhoneOverride,
    );
  }

  /// Combina los textos compilados de cada plan comercial con los precios, días, cuotas IA
  /// y vigencias de updates vigentes desde [EffectiveCommercialConfig].
  static List<CommercialPlanDetail> buildEffectiveOfficialPlans(
    EffectiveCommercialConfig config,
  ) =>
      buildEffectiveCommercialPlans(config);

  static const List<CommercialPlanDetail> officialPlans =
      officialCommercialPlansData;

  @override
  State<LicenseStatusAndActivationScreen> createState() =>
      _LicenseStatusAndActivationScreenState();
}

abstract class _LicenseScreenStateBase
    extends State<LicenseStatusAndActivationScreen> {
  final TextEditingController _codeController = TextEditingController();
  final _tourKeys = LicenseStatusTourKeys();
  final CommercialConfigSyncService _commercialSyncService =
      CommercialConfigSyncService();
  String? _detectedClipboardCode;
  bool _isCheckingClipboard = false;
  bool _isVerifyingMlc1 = false;
  bool? _isPlansExpanded;
  EffectiveCommercialConfig? _fallbackSyncedConfig;

  bool _isSharingSyncState = false;

  CommercialCatalogProvider? _tryCatalogProvider({bool listen = false}) {
    try {
      return Provider.of<CommercialCatalogProvider?>(context, listen: listen);
    } catch (_) {
      return null;
    }
  }

  EffectiveCommercialConfig _resolveEffectiveConfig({bool listen = false}) {
    final prov = _tryCatalogProvider(listen: listen);
    if (prov != null) return prov.effectiveConfig;
    return _fallbackSyncedConfig ?? EffectiveCommercialConfig.defaults();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboardForCode();
      _loadFallbackCommercialConfigIfNeeded();
      InteractiveTourService.maybeStartAutomaticTour(
        context,
        LicenseStatusTour.buildConfig(keys: _tourKeys),
      );
    });
  }

  Future<void> _loadFallbackCommercialConfigIfNeeded() async {
    if (!mounted) return;
    if (_tryCatalogProvider(listen: false) != null) return;
    final saved = await _commercialSyncService.getSavedConfig();
    if (!mounted) return;
    if (saved != null) {
      setState(() {
        _fallbackSyncedConfig = EffectiveCommercialConfig.fromSaved(saved);
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _checkClipboardForCode();
  Future<void> _activateCode(String code);
  Future<void> _confirmResetCommercialCatalog();
  Future<void> _launchRawWhatsAppUrl(String url);
  Future<void> _launchWhatsAppMessage(String message);
  Future<void> _shareClientState(LicenseProvider? licenseProv, String fingerprint);
  Widget _buildClipboardDetectedBanner(bool isDark);
  Widget _buildWelcomeTrialBanner(String message, bool isDark);
  Widget _buildExecutiveStatusCard(LicenseProvider? licenseProv, LicenseModel? license, String fingerprint, bool isDark);
  Widget _buildActivationCard(LicenseProvider? licenseProv, bool isDark);
  Widget _buildPricingAndPaymentCatalog(LicenseModel? license, String fingerprint, bool isDark, EffectiveCommercialConfig effectiveConfig);
  Widget _buildBankAccountsSection(bool isDark, EffectiveCommercialConfig effectiveConfig);
  Widget _buildPlanTile(CommercialPlanDetail plan, String fingerprint, bool isDark);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final licenseProv = Provider.of<LicenseProvider?>(context);
    final license = licenseProv?.license;
    final fingerprint = licenseProv?.deviceFingerprint ?? 'ML-INIT';
    final effectiveConfig = _resolveEffectiveConfig(listen: true);

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
              _buildPricingAndPaymentCatalog(
                license,
                fingerprint,
                isDark,
                effectiveConfig,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _LicenseStatusAndActivationScreenState extends _LicenseScreenStateBase
    with
        _LicenseMlc1SyncMixin,
        _LicenseActivationCardMixin,
        _LicenseStatusCardMixin,
        _LicenseCatalogSectionMixin,
        _LicenseBankAccountsSectionMixin {}
