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

part 'profile/profile_menu_sections.dart';
part 'profile/profile_header_and_legal.dart';
part 'profile/profile_layout_helpers_and_delete.dart';
part 'profile/profile_photo_and_edit_modals.dart';

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

abstract class _ProfileStateBase extends State<ProfileScreen>
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


  List<Widget> _buildProfileMenuSections({
    required BuildContext context,
    required AuthProvider auth,
    required ThemeProvider themeProv,
    required bool isDark,
    required bool isGuest,
    required Color cardColor,
    required Color textColor,
  });
  Widget _buildLegalCopyrightCard(
    BuildContext context,
    bool isDark,
    LicenseProvider? licenseProv,
  );
  Widget _buildHeader(BuildContext context, AuthProvider auth, bool isDark);
  Widget _buildSectionHeader(
    String title,
    Color? color, {
    String? actionLabel,
    IconData? iconData,
    VoidCallback? onAction,
  });
  Widget _buildSettingsContainer(Color color, List<Widget> children);
  Widget _buildDivider(bool isDark);
  void _showDeleteBusinessModal(
    BuildContext context,
    AuthProvider auth,
    bool isDark,
  );
  Future<void> _openDirectGpsPicker(
    BuildContext context,
    AuthProvider auth,
  );
  Future<void> _confirmResetTours(BuildContext context, bool isDark);
  void _confirmLogout(BuildContext context, AuthProvider auth, bool isDark);
  void _showPhotoOptions(
    BuildContext context,
    AuthProvider auth,
    String? validLogoPath,
  );
  Future<void> _showEditProfile(
    BuildContext context, {
    String? initialFocusField,
  });
  Future<void> _showEditBusiness(
    BuildContext context, {
    String? initialFocusField,
  });
  Future<void> _showChangePassword(BuildContext context);

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

                        ..._buildProfileMenuSections(
                          context: context,
                          auth: auth,
                          themeProv: themeProv,
                          isDark: isDark,
                          isGuest: isGuest,
                          cardColor: cardColor,
                          textColor: textColor,
                        ),

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
}

class _ProfileScreenState extends _ProfileStateBase
    with
        _ProfileMenuSectionsMixin,
        _ProfileHeaderAndLegalMixin,
        _ProfileLayoutHelpersAndDeleteMixin,
        _ProfilePhotoAndEditModalsMixin {}
