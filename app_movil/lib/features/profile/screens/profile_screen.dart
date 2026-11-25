import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';

import 'package:app_movil/features/profile/widgets/business_info_card.dart';
import 'package:app_movil/features/profile/widgets/profile_menu_item.dart';
import 'package:app_movil/features/profile/widgets/edit_profile_modal.dart';
import 'package:app_movil/features/profile/widgets/edit_business_modal.dart';
import 'package:app_movil/features/profile/widgets/delete_business_modal.dart';
import 'package:app_movil/features/profile/widgets/change_pin_modal.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/auth/screens/onboarding/profile_selection_screen.dart';
import 'package:app_movil/core/screens/home_screen.dart';
import 'package:app_movil/features/profile/screens/printer_config_screen.dart';
import 'package:app_movil/features/profile/screens/notifications_screen.dart';
import 'package:app_movil/features/profile/screens/backup_screen.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/utils/hardware_validator.dart';
import 'package:app_movil/features/profile/screens/map_picker_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/tour/configs/profile_screen_tour.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/features/profile/widgets/profile_completion_indicator.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/config/app_changelog_registry.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/features/auth/screens/license/license_status_and_activation_screen.dart';
import 'package:app_movil/features/auth/widgets/eula_acceptance_modal.dart';
import 'package:app_movil/features/auth/widgets/post_update_welcome_modal.dart';
import 'package:app_movil/features/profile/screens/ai_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool autoTriggerTour;
  final ProfileScreenTourKeys? tourKeys;

  const ProfileScreen({
    super.key,
    this.autoTriggerTour = true,
    this.tourKeys,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final ProfileScreenTourKeys _tourKeys;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  bool _automaticToursEnabled = true;
  bool _hasPendingHomeRefresh = false;

  ScreenTourConfig _buildTourConfig() {
    return ProfileScreenTour.buildConfig(keys: _tourKeys);
  }

  void _markProfileMutated() {
    _hasPendingHomeRefresh = true;
  }

  void _onToursEnabledChanged() {
    if (mounted) {
      setState(() {
        _automaticToursEnabled =
            InteractiveTourService.automaticToursEnabledNotifier.value;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tourKeys = widget.tourKeys ?? ProfileScreenTourKeys();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();

    _automaticToursEnabled =
        InteractiveTourService.automaticToursEnabledNotifier.value;
    InteractiveTourService.automaticToursEnabledNotifier.addListener(
      _onToursEnabledChanged,
    );

    InteractiveTourService.areAutomaticToursEnabled().then((v) {
      if (mounted) setState(() => _automaticToursEnabled = v);
    });

    if (widget.autoTriggerTour) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await InteractiveTourService.maybeStartAutomaticTour(
          context,
          _buildTourConfig(),
        );
      });
    }
  }

  @override
  void dispose() {
    InteractiveTourService.automaticToursEnabledNotifier.removeListener(
      _onToursEnabledChanged,
    );
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  String? _getValidLocalImagePath(String? rawPath) {
    if (rawPath == null || rawPath.trim().isEmpty || rawPath == 'null') {
      return null;
    }
    return rawPath;
  }

  Future<void> _refreshProfile() async {
    await Provider.of<AuthProvider>(context, listen: false).refreshActiveUser();
    if (mounted) {
      CustomSnackBar.show(
        context,
        message: "Datos actualizados",
        isError: false,
      );
    }
  }

  void _clearVolatileMemory(BuildContext context) {
    Provider.of<CatalogProvider>(context, listen: false).clearCart();
    Provider.of<CatalogProvider>(context, listen: false).clearUtilityList();
    Provider.of<QuickSaleProvider>(context, listen: false).clearCart();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final themeProv = Provider.of<ThemeProvider>(context);
    final licenseProv = Provider.of<LicenseProvider?>(context);
    final user = auth.user;

    if (user == null || !auth.isAuthenticated) {
      return Scaffold(
        backgroundColor: themeProv.isDarkMode
            ? const Color(0xFF14141C)
            : const Color(0xFFF5F7FA),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = themeProv.isDarkMode;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bool isGuest = !auth.hasActiveContext;
    final String? validLogoPath = _getValidLocalImagePath(
      auth.currentBusiness?.logoUrl,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_hasPendingHomeRefresh);
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: RefreshIndicator(
          onRefresh: _refreshProfile,
          color: Colors.blue[800],
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                _buildHeader(context, auth, isDark),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KeyedSubtree(
                          key: _tourKeys.businessDetailsCardKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                "Administración del Negocio",
                                textColor,
                                actionLabel: "Editar Datos",
                                iconData: Icons.edit_note_rounded,
                                onAction: () => _showEditBusiness(context),
                              ),
                              const SizedBox(height: 16),
                              BusinessInfoCard(business: auth.currentBusiness),
                            ],
                          ),
                        ),
                        // 🔧 TAREA 3.2: Indicador de completitud del perfil
                        KeyedSubtree(
                          key: _tourKeys.completionIndicatorKey,
                          child: ProfileCompletionIndicator(
                            user: user,
                            hasPin: auth.hasPinCache,
                            isDark: isDark,
                            onEditProfile: (field) => _showEditProfile(
                              context,
                              initialFocusField: field,
                            ),
                            onEditBusiness: (field) => _showEditBusiness(
                              context,
                              initialFocusField: field,
                            ),
                            onChangeLogo: () {
                              if (auth.currentBusiness == null) {
                                _showEditBusiness(context);
                              } else {
                                _showPhotoOptions(
                                  context,
                                  auth,
                                  validLogoPath,
                                );
                              }
                            },
                            onChangePin: () => _showChangePassword(context),
                            onConfigureGps: () =>
                                _openDirectGpsPicker(context, auth),
                          ),
                        ),
                        const SizedBox(height: 35),

                        _buildSectionHeader("Configuración General", textColor),
                        const SizedBox(height: 12),
                        KeyedSubtree(
                          key: _tourKeys.operationalCenterKey,
                          child: _buildSettingsContainer(cardColor, [
                          ProfileMenuItem(
                            title: "Editar Datos Personales",
                            icon: Icons.person_outline,
                            isDark: isDark,
                            onTap: () => _showEditProfile(context),
                          ),
                          _buildDivider(isDark),

                          KeyedSubtree(
                            key: _tourKeys.licenseSupportKey,
                            child: ProfileMenuItem(
                              title: "Estado y Activación de Licencia",
                              icon: Icons.verified_outlined,
                              isDark: isDark,
                              onTap: () async {
                                _markProfileMutated();
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const LicenseStatusAndActivationScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          _buildDivider(isDark),

                          ProfileMenuItem(
                            title: "Cotizador Universal IA y API Key",
                            icon: Icons.auto_awesome_outlined,
                            isDark: isDark,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AiSettingsScreen(),
                              ),
                            ),
                          ),
                          _buildDivider(isDark),

                          KeyedSubtree(
                            key: _tourKeys.backupsKey,
                            child: ProfileMenuItem(
                              title: "Respaldos y Seguridad",
                              icon: Icons.security_rounded,
                              isDark: isDark,
                              onTap: () async {
                                _markProfileMutated();
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const BackupScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          _buildDivider(isDark),

                          ProfileMenuItem(
                            title: isDark ? "Modo Noche" : "Modo Claro",
                            icon: isDark
                                ? Icons.nightlight_round
                                : Icons.wb_sunny_outlined,
                            isDark: isDark,
                            onTap: () => themeProv.toggleTheme(!isDark),
                            trailing: Switch(
                              value: isDark,
                              activeThumbColor: Colors.blue[400],
                              onChanged: (v) => themeProv.toggleTheme(v),
                            ),
                          ),
                          _buildDivider(isDark),
                          ProfileMenuItem(
                            title: "Notificaciones",
                            icon: Icons.notifications_none,
                            isDark: isDark,
                            onTap: () async {
                              _markProfileMutated();
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationsScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDivider(isDark),
                          KeyedSubtree(
                            key: _tourKeys.printerKey,
                            child: ProfileMenuItem(
                              title: "Impresora Térmica",
                              icon: Icons.print_outlined,
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PrinterConfigScreen(),
                                ),
                              ),
                              trailing: const Icon(
                                Icons.bluetooth,
                                size: 22,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ]),
                        ),

                        const SizedBox(height: 35),
                        _buildSectionHeader(
                          "Seguridad de la Cuenta",
                          textColor,
                        ),
                        const SizedBox(height: 12),

                        // 🔧 Recordatorio amigable de PIN de seguridad con snooze de 7 días
                        if (!auth.hasPinCache &&
                            !isGuest &&
                            !auth.isPinReminderSnoozed)
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.amber.withValues(alpha: 0.12)
                                  : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? Colors.amber.withValues(alpha: 0.35)
                                    : Colors.amber.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.shield_outlined,
                                    color: Colors.amber,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Protege tu Negocio con un PIN",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.amber[200]
                                              : Colors.amber[900],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Configura un PIN de 4 dígitos para bloquear la app y proteger tus finanzas.",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[700],
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton(
                                  onPressed: () => _showChangePassword(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    "Activar",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                  tooltip: "Recordar en 7 días",
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 26,
                                    minHeight: 26,
                                  ),
                                  onPressed: () async {
                                    await auth.snoozePinReminder(days: 7);
                                    if (context.mounted) {
                                      CustomSnackBar.show(
                                        context,
                                        message:
                                            "Recordatorio pospuesto por 7 días. Puedes crear tu PIN en la sección inferior.",
                                        isError: false,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),

                        KeyedSubtree(
                          key: _tourKeys.securityPinKey,
                          child: _buildSettingsContainer(cardColor, [
                            ProfileMenuItem(
                              title: auth.hasPinCache
                                  ? "Cambiar PIN de Seguridad"
                                  : "Crear PIN de Seguridad",
                              icon: Icons.lock_outline,
                              isDark: isDark,
                              onTap: () => _showChangePassword(context),
                            ),
                          ]),
                        ),

                        const SizedBox(height: 35),
                        _buildSectionHeader("Aprendizaje y Ayuda", textColor),
                        const SizedBox(height: 12),
                        KeyedSubtree(
                          key: _tourKeys.toursSettingsKey,
                          child: _buildSettingsContainer(cardColor, [
                            ProfileMenuItem(
                              title: "Guías interactivas automáticas",
                              icon: Icons.explore_outlined,
                              isDark: isDark,
                              onTap: () async {
                                final next = !_automaticToursEnabled;
                                await InteractiveTourService.setAutomaticToursEnabled(
                                  next,
                                  userInitiated: true,
                                );
                                if (mounted) {
                                  setState(() => _automaticToursEnabled = next);
                                }
                              },
                              trailing: Switch(
                                value: _automaticToursEnabled,
                                activeThumbColor: Colors.blue[400],
                                onChanged: (val) async {
                                  await InteractiveTourService.setAutomaticToursEnabled(
                                    val,
                                    userInitiated: true,
                                  );
                                  if (mounted) {
                                    setState(
                                      () => _automaticToursEnabled = val,
                                    );
                                  }
                                },
                              ),
                            ),
                            _buildDivider(isDark),
                            ProfileMenuItem(
                              title: "Reiniciar guías de aprendizaje",
                              icon: Icons.restart_alt_rounded,
                              isDark: isDark,
                              onTap: () => _confirmResetTours(context, isDark),
                            ),
                          ]),
                        ),

                        const SizedBox(height: 35),
                        _buildSectionHeader("Sesión Activa", textColor),
                        const SizedBox(height: 12),
                        KeyedSubtree(
                          key: _tourKeys.sessionSwitchKey,
                          child: _buildSettingsContainer(cardColor, [
                            ProfileMenuItem(
                              title: "Cambiar de Negocio / Cerrar Sesión",
                              icon: Icons.swap_horiz_rounded,
                              isDark: isDark,
                              isDestructive: false,
                              onTap: () =>
                                  _confirmLogout(context, auth, isDark),
                            ),
                          ]),
                        ),

                        const SizedBox(height: 35),
                        // 🛡️ ZONA DE PELIGRO (DANGER ZONE)
                        Container(
                          key: _tourKeys.dangerZoneKey,
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1418)
                                : const Color(0xFFFFF5F5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.red.withValues(alpha: 0.25)
                                  : Colors.red.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.warning_amber_rounded,
                                      size: 18,
                                      color: Colors.red[400],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Zona de Peligro",
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.red[300]
                                            : Colors.red[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Esta acción eliminará de forma permanente este perfil de negocio y todos sus registros locales en este dispositivo.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _showDeleteBusinessModal(
                                    context,
                                    auth,
                                    isDark,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_forever_outlined,
                                    size: 18,
                                  ),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      "Eliminar este perfil de negocio",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark
                                        ? Colors.red[300]
                                        : Colors.red[700],
                                    side: BorderSide(
                                      color: isDark
                                          ? Colors.red.withValues(alpha: 0.4)
                                          : Colors.red.shade300,
                                    ),
                                    backgroundColor: isDark
                                        ? Colors.red.withValues(alpha: 0.06)
                                        : Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        // 🏛️ Sello Legal de Derechos de Autor y Titularidad Intelectual
                        _buildLegalCopyrightCard(context, isDark, licenseProv),
                        SizedBox(
                          height: math.max(
                            MediaQuery.viewPaddingOf(context).bottom + 24.0,
                            48.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegalCopyrightCard(
    BuildContext context,
    bool isDark,
    LicenseProvider? licenseProv,
  ) {
    final planName = licenseProv?.currentPlanName ?? 'TRIAL';
    final statusName = licenseProv?.license?.estadoActual ?? 'ACTIVA';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A24) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: Colors.blue),
              Text(
                "${OwnerLegalIdentity.appCommercialName} v${OwnerLegalIdentity.currentAppVersion}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "$planName ($statusName)",
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Desarrollado y Distribuido por ${OwnerLegalIdentity.authorFullName}",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "Todos los derechos reservados © 2026. ${OwnerLegalIdentity.legalFrameworkNotice}.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: () =>
                    EulaAcceptanceModal.show(context, isReadOnly: true),
                icon: const Icon(Icons.description_outlined, size: 15),
                label: const Text(
                  "Ver Contrato EULA",
                  style: TextStyle(fontSize: 11.5),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LicenseStatusAndActivationScreen(),
                  ),
                ),
                icon: const Icon(Icons.verified_outlined, size: 15),
                label: const Text(
                  "Gestionar Licencia",
                  style: TextStyle(fontSize: 11.5),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              TextButton.icon(
                onPressed: () => PostUpdateWelcomeModal.show(
                  context,
                  appVersion: AppChangelogRegistry.currentVersion,
                  mode:
                      (licenseProv?.isPerpetual == true ||
                          (licenseProv?.isActive == true &&
                              licenseProv?.isTrial == false))
                      ? PostUpdateMode.activeCommercialOrPerpetual
                      : PostUpdateMode.trialOrGrace,
                  onActivatePlanPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LicenseStatusAndActivationScreen(),
                    ),
                  ),
                  barrierDismissible: true,
                  isManualPreview: true,
                ),
                icon: const Icon(Icons.rocket_launch_rounded, size: 15),
                label: Text(
                  "Novedades v${OwnerLegalIdentity.currentAppVersion}",
                  style: const TextStyle(fontSize: 11.5),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    Color? color, {
    String? actionLabel,
    IconData? iconData,
    VoidCallback? onAction,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: isNarrow ? 14.5 : 15.5,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (iconData != null) ...[
                        Icon(iconData, size: 15, color: Colors.blue),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        actionLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSettingsContainer(Color color, List<Widget> children) =>
      Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: children),
      );

  Widget _buildDivider(bool isDark) => Divider(
    height: 1,
    indent: 65,
    endIndent: 20,
    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
  );

  void _showDeleteBusinessModal(
    BuildContext context,
    AuthProvider auth,
    bool isDark,
  ) async {
    final bool? deleted = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteBusinessModal(
        userId: auth.activeUserId!,
        hasPin: auth.hasPinCache,
      ),
    );

    if (deleted == true) {
      if (!context.mounted) return;
      _clearVolatileMemory(context);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildHeader(BuildContext context, AuthProvider auth, bool isDark) {
    final String? validLogoPath = _getValidLocalImagePath(
      auth.currentBusiness?.logoUrl,
    );

    final invProv = Provider.of<InventoryProvider>(context);
    final workbench = Provider.of<WorkbenchProvider>(context);
    final salesProv = Provider.of<SaleProvider>(context);

    final int productsCount = invProv.totalProductsCount;
    final int draftsCount = workbench.inProcessList.length;

    final double salesDouble = salesProv.todaySalesTotal;
    final String salesTotal = salesDouble == 0
        ? "Sin ventas"
        : AppCurrency.format(salesDouble);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0D47A1), const Color(0xFF001633)]
              : [const Color(0xFF1976D2), const Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 30, top: 10),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                left: 10,
                top: 0,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                  ),
                  onPressed: () =>
                      Navigator.of(context).pop(_hasPendingHomeRefresh),
                ),
              ),
              // 🔧 TAREA 3.4: Info Tooltip en el perfil
              Positioned(
                right: 10,
                top: 0,
                child: InfoTooltipButton(
                  iconColor: Colors.white60,
                  title: 'Tu Perfil',
                  description:
                      'Desde aquí gestionas toda la información de tu cuenta y negocio. Puedes actualizar tus datos personales, configurar tu negocio, gestionar respaldos y personalizar la app.',
                  tips: const [
                    InfoTip(
                      icon: Icons.person,
                      text:
                          'Edita tu nombre, teléfono y correo electrónico en "Editar Datos Personales".',
                    ),
                    InfoTip(
                      icon: Icons.store,
                      text:
                          'Actualiza la información de tu negocio (nombre, RUC, dirección, logo) con "Editar Datos".',
                    ),
                    InfoTip(
                      icon: Icons.security,
                      text:
                          'En "Respaldos y Seguridad" puedes exportar e importar toda tu información.',
                    ),
                    InfoTip(
                      icon: Icons.camera_alt,
                      text:
                          'Toca el ícono de cámara sobre tu logo para cambiarlo.',
                    ),
                    InfoTip(
                      icon: Icons.swap_horiz_rounded,
                      text:
                          'Alterna entre negocios o cierra sesión desde "Sesión Activa".',
                    ),
                  ],
                  onStartInteractiveTour: () =>
                      InteractiveTourService.startManualTour(
                        context,
                        _buildTourConfig(),
                      ),
                ),
              ),
              KeyedSubtree(
                key: _tourKeys.businessCardKey,
                child: Column(
                  children: [
                    const SizedBox(height: 15),
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                          child: CircleAvatar(
                            radius: 52,
                            backgroundColor: Colors.white,
                            backgroundImage:
                                (validLogoPath != null &&
                                    !validLogoPath.startsWith('http'))
                                ? FileImage(File(validLogoPath))
                                : null,
                            child: validLogoPath == null
                                ? _buildBusinessAvatarFallback(
                                    auth.businessName,
                                  )
                                : null,
                          ),
                        ),
                        InkWell(
                          onTap: () =>
                              _showPhotoOptions(context, auth, validLogoPath),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: auth.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          auth.userName,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (auth.currentBusiness != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            auth.businessName,
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        "DUEÑO DE NEGOCIO",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: _buildMicroKpi("Productos", "$productsCount"),
                        ),
                        Expanded(
                          child: _buildMicroKpi("Borradores", "$draftsCount"),
                        ),
                        Expanded(
                          child: _buildMicroKpi("Ventas Hoy", salesTotal),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhotoOptions(
    BuildContext context,
    AuthProvider auth,
    String? validLogoPath,
  ) {
    if (auth.isLoading) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final effectiveBottom =
            InteractiveSheetWrapper.getEffectiveBottomPadding(
              ctx,
              minPadding: kMinDefensiveBottomClearance,
            );
        return Container(
          margin: EdgeInsets.fromLTRB(16, 16, 16, effectiveBottom + 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF23232F) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 15),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (validLogoPath != null &&
                      !validLogoPath.startsWith('http'))
                    _buildModalOption(
                      icon: Icons.fullscreen,
                      text: "Ver foto en pantalla completa",
                      color: Colors.blue,
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        _openFullScreenImage(validLogoPath);
                      },
                    ),

                  _buildModalOption(
                    icon: Icons.camera_alt,
                    text: "Tomar foto con la cámara",
                    color: Colors.blue,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(context, auth, source: ImageSource.camera);
                    },
                  ),

                  _buildModalOption(
                    icon: Icons.image_search,
                    text: "Elegir foto de la galería",
                    color: Colors.green,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(context, auth, source: ImageSource.gallery);
                    },
                  ),

                  if (validLogoPath != null)
                    _buildModalOption(
                      icon: Icons.delete_outline,
                      text: "Eliminar foto actual",
                      color: Colors.red,
                      isDark: isDark,
                      isDestructive: true,
                      onTap: () async {
                        Navigator.pop(ctx);
                        final biz = auth.currentBusiness!;
                        bool success = await auth.updateBusinessProfile(
                          biz.commercialName,
                          biz.ruc ?? "",
                          biz.address ?? "",
                          biz.paymentInfo ?? "",
                          biz.latitud,
                          biz.longitud,
                          true,
                          true,
                          clearLogo: true,
                        );
                        if (context.mounted) {
                          if (success) {
                            _markProfileMutated();
                            CustomSnackBar.show(
                              context,
                              message: "La foto ha sido eliminada.",
                              isError: false,
                            );
                          } else {
                            CustomSnackBar.show(
                              context,
                              message: auth.errorMessage,
                              isError: true,
                            );
                          }
                        }
                      },
                    ),

                  const SizedBox(height: 15),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalOption({
    required IconData icon,
    required String text,
    required Color color,
    required bool isDark,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDestructive
              ? Colors.red
              : (isDark ? Colors.white : Colors.black87),
        ),
      ),
      onTap: onTap,
    );
  }

  void _openFullScreenImage(String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          extendBodyBehindAppBar: true,
          body: Center(
            child: PhotoView(
              imageProvider: FileImage(File(imagePath)),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            ),
          ),
        ),
      ),
    );
  }

  String _captureProfileFingerprint(AuthProvider auth) {
    final biz = auth.currentBusiness;
    return '${auth.userName}|${auth.user?.phone ?? ''}|${auth.user?.email ?? ''}|'
        '${auth.businessName}|${biz?.ruc ?? ''}|${biz?.address ?? ''}|'
        '${biz?.logoUrl ?? ''}|${biz?.paymentInfo ?? ''}|${biz?.moneda ?? ''}|'
        '${biz?.latitud ?? ''}|${biz?.longitud ?? ''}|${auth.hasPinCache}|${auth.isPinReminderSnoozed}';
  }

  Future<void> _pickImage(
    BuildContext context,
    AuthProvider auth, {
    ImageSource source = ImageSource.gallery,
  }) async {
    if (auth.isLoading) return;
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (image != null) {
        bool success = await auth.uploadBusinessLogo(File(image.path));
        if (context.mounted) {
          if (success) {
            _markProfileMutated();
            CustomSnackBar.show(
              context,
              message: "Foto guardada exitosamente",
              isError: false,
            );
          } else {
            CustomSnackBar.show(
              context,
              message: auth.errorMessage,
              isError: true,
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        CustomSnackBar.show(
          context,
          message: source == ImageSource.camera
              ? "Error al abrir la cámara"
              : "Error al abrir la galería",
          isError: true,
        );
      }
    }
  }

  Future<void> _showEditProfile(
    BuildContext context, {
    String? initialFocusField,
  }) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final before = _captureProfileFingerprint(auth);
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditProfileModal(initialFocusField: initialFocusField),
    );
    if (context.mounted) {
      await auth.refreshActiveUser();
      if (_captureProfileFingerprint(auth) != before) {
        _markProfileMutated();
      }
    }
  }

  Future<void> _showEditBusiness(
    BuildContext context, {
    String? initialFocusField,
  }) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final before = _captureProfileFingerprint(auth);
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditBusinessModal(initialFocusField: initialFocusField),
    );
    if (context.mounted) {
      await auth.refreshActiveUser();
      if (_captureProfileFingerprint(auth) != before) {
        _markProfileMutated();
      }
    }
  }

  Future<void> _showChangePassword(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final before = _captureProfileFingerprint(auth);
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ChangePasswordModal(),
    );
    if (context.mounted) {
      await auth.refreshActiveUser();
      if (_captureProfileFingerprint(auth) != before) {
        _markProfileMutated();
      }
    }
  }

  Future<void> _openDirectGpsPicker(
    BuildContext context,
    AuthProvider auth,
  ) async {
    final isGpsReady = await HardwareValidator.checkGPS(context);
    if (!isGpsReady) return;
    if (!context.mounted) return;

    final biz = auth.currentBusiness;
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLat: biz?.latitud,
          initialLng: biz?.longitud,
        ),
      ),
    );

    if (result != null && biz != null) {
      bool success = await auth.updateBusinessProfile(
        biz.commercialName,
        biz.ruc ?? '',
        biz.address ?? '',
        biz.paymentInfo,
        result.latitude,
        result.longitude,
        biz.printerConfig != null &&
                biz.printerConfig!.contains('"show_address":false')
            ? false
            : true,
        biz.printerConfig != null &&
                biz.printerConfig!.contains('"show_ruc":false')
            ? false
            : true,
      );
      if (!context.mounted) return;
      if (success) {
        _markProfileMutated();
        await auth.refreshActiveUser();
        if (context.mounted) {
          CustomSnackBar.show(
            context,
            message: "Ubicación GPS actualizada",
            isError: false,
          );
        }
      } else {
        if (context.mounted) {
          CustomSnackBar.show(
            context,
            message: auth.errorMessage,
            isError: true,
          );
        }
      }
    }
  }

  Future<void> _confirmResetTours(BuildContext context, bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.restart_alt_rounded, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Reiniciar Guías",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          "¿Deseas reiniciar las guías de aprendizaje? Volverás a ver las explicaciones interactivas paso a paso en las pantallas principales de la app.",
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? const Color(0xFF38BDF8)
                  : const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Reiniciar",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await InteractiveTourService.resetAllTours(userInitiated: true);
      if (!context.mounted) return;
      setState(() => _automaticToursEnabled = true);
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
      CustomSnackBar.show(
        context,
        message: "Guías interactivas reiniciadas. Disfruta tu recorrido.",
        isError: false,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) return;
        await InteractiveTourService.maybeStartAutomaticTour(
          context,
          _buildTourConfig(),
        );
      });
    }
  }

  void _confirmLogout(BuildContext context, AuthProvider auth, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Cambiar de Negocio",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          "Al cerrar este negocio, serás redirigido a la pantalla principal para seleccionar otro o crear uno nuevo. Todo tu progreso sin guardar (carritos y ventas en curso) se limpiará.",
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancelar",
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _clearVolatileMemory(context);
              await auth.logout();

              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileSelectionScreen(),
                  ),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Sí, salir",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicroKpi(String label, String value) {
    bool isEmpty = value == "Sin ventas" || value == "0";
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: isEmpty
                    ? Colors.white.withValues(alpha: 0.6)
                    : Colors.white,
                fontSize: isEmpty ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessAvatarFallback(String name) {
    String initials = "NG";
    final cleanName = name.trim();
    if (cleanName.isNotEmpty) {
      final parts = cleanName.split(RegExp(r'\s+'));
      if (parts.length > 1 && parts[1].isNotEmpty) {
        initials = (parts[0][0] + parts[1][0]).toUpperCase();
      } else {
        initials = cleanName
            .substring(0, cleanName.length > 1 ? 2 : 1)
            .toUpperCase();
      }
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.blue[400]!, Colors.blue[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
