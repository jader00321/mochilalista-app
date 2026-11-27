import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:app_movil/core/models/ai_key_model.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/services/ai/ai_vault_service.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/utils/app_date_formatter.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/utils/clipboard_helper.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/tour/configs/ai_settings_tour.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

part 'ai_settings/ai_settings_dialogs_and_actions_mixin.dart';
part 'ai_settings/ai_settings_quota_and_mode_mixin.dart';
part 'ai_settings/ai_settings_vault_and_guide_mixin.dart';

/// Pantalla de Monitoreo de Cuota IA, Selector de Modo y Bóveda Segura Multi-Clave BYOK
class AiSettingsScreen extends StatefulWidget {
  final bool autoTriggerTour;
  final AiSettingsTourKeys? tourKeys;

  const AiSettingsScreen({
    super.key,
    this.autoTriggerTour = true,
    this.tourKeys,
  });

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

abstract class _AiSettingsScreenBase extends State<AiSettingsScreen> {
  List<AiKeyModel> _keys = [];
  String? _activeKeyId;
  bool _isLoadingVault = true;
  String? _testingKeyId;
  late final AiSettingsTourKeys _tourKeys;
  bool _didAttemptAutoTour = false;

  Future<void> _loadVaultData();
  Future<void> _switchMode(String mode);
  Future<void> _launchAiStudio();

  Future<void> _showAddKeyDialog();
  Future<void> _showEditAliasDialog(AiKeyModel key);
  Future<void> _testKey(AiKeyModel key);
  Future<void> _copyKey(AiKeyModel key);
  Future<void> _activateKey(AiKeyModel key);
  Future<void> _confirmDeleteKey(AiKeyModel key);
}

class _AiSettingsScreenState extends _AiSettingsScreenBase
    with
        _AiSettingsDialogsAndActionsMixin,
        _AiSettingsQuotaAndModeMixin,
        _AiSettingsVaultAndGuideMixin {
  @override
  void initState() {
    super.initState();
    _tourKeys = widget.tourKeys ?? AiSettingsTourKeys();
    _loadVaultData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<LicenseProvider?>()?.refreshAiScans();
      }
    });
  }

  ScreenTourConfig _buildTourConfig() {
    return AiSettingsTour.buildConfig(keys: _tourKeys);
  }

  void _startTour(BuildContext context) {
    InteractiveTourService.startManualTour(context, _buildTourConfig());
  }

  void _maybeStartAutoTour() {
    if (!widget.autoTriggerTour || _didAttemptAutoTour || !mounted) return;
    _didAttemptAutoTour = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await InteractiveTourService.maybeStartAutomaticTour(
        context,
        _buildTourConfig(),
      );
    });
  }

  @override
  Future<void> _loadVaultData() async {
    try {
      final keys = await AiVaultService.instance.getKeys();
      final activeId = await AiVaultService.instance.getActiveKeyId();
      if (mounted) {
        setState(() {
          _keys = keys;
          _activeKeyId = activeId ?? (keys.isNotEmpty ? keys.first.id : null);
          _isLoadingVault = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingVault = false);
    } finally {
      _maybeStartAutoTour();
    }
  }

  @override
  Future<void> _switchMode(String mode) async {
    final licenseProv = Provider.of<LicenseProvider?>(context, listen: false);
    if (licenseProv == null) return;

    await licenseProv.setAiSelectedMode(mode);

    if (mode == 'BYOK' && _keys.isEmpty && mounted) {
      AppFeedbackHelper.showSuccess(
        context,
        "Modo BYOK activado. Por favor, agrega una clave para comenzar a escanear.",
      );
    }
  }

  @override
  Future<void> _launchAiStudio() async {
    final uri = Uri.parse('https://aistudio.google.com/apikey');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        AppFeedbackHelper.showError(
          context,
          "No se pudo abrir el navegador: $e",
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

    final isByokMode = licenseProv?.isUsingByokMode ?? false;
    final remainingScans = licenseProv?.remainingAiScans ?? 50;
    final accumulatedScans = licenseProv?.aiAccumulatedScans ?? remainingScans;
    final activeKey = _keys.where((k) => k.id == _activeKeyId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            "Cotizador Universal IA y Cuota",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
        ),
        actions: [
          InfoTooltipButton(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(6),
            onStartInteractiveTour: () => _startTour(context),
            title: "Configuración IA y Bóveda BYOK",
            description:
                "Controla tu bolsa acumulativa compartida de MochilaLista o conecta tus propias API Keys de Google Gemini almacenadas con cifrado local.",
            tips: const [
              InfoTip(
                icon: Icons.swap_horiz_rounded,
                text:
                    "Cambia entre Bolsa MochilaLista y Clave Propia (BYOK) según necesites; en BYOK tu cuota acumulada queda congelada intacta.",
              ),
              InfoTip(
                icon: Icons.vpn_key_rounded,
                text:
                    "Guarda múltiples claves de respaldo y verifica su estado en vivo con Probar Clave antes de escanear.",
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Selector Explícito de Modo de Procesamiento IA
              KeyedSubtree(
                key: _tourKeys.modeSelectorKey,
                child: _buildModeSelector(
                  isByokMode: isByokMode,
                  accumulatedScans: accumulatedScans,
                  activeKey: activeKey,
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 16),

              // 2. Tarjeta de Bolsa Acumulativa Compartida (Sin Reseteo Mensual)
              KeyedSubtree(
                key: _tourKeys.quotaCardKey,
                child: _buildCumulativeQuotaCard(
                  isByokMode: isByokMode,
                  accumulatedScans: accumulatedScans,
                  license: license,
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 16),

              // 3. Bóveda Segura Multi-Clave BYOK
              KeyedSubtree(
                key: _tourKeys.vaultKey,
                child: _buildVaultCard(isDark: isDark, isByokMode: isByokMode),
              ),
              const SizedBox(height: 16),

              // 4. Guía Paso a Paso ¿Cómo obtener una API Key gratis?
              KeyedSubtree(
                key: _tourKeys.securityGuideKey,
                child: _buildStepByStepGuideCard(isDark),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
