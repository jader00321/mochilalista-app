import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/google_drive_backup_provider.dart';
import 'package:app_movil/core/services/backup/i_google_drive_backup_service.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/widgets/primary_button.dart';
import 'package:app_movil/core/widgets/auth_background.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/auth/screens/onboarding/onboarding_screen.dart';
import 'package:app_movil/core/screens/home_screen.dart';
import 'package:app_movil/features/auth/screens/onboarding/lock_screen.dart';
import 'package:app_movil/features/auth/widgets/eula_acceptance_modal.dart';
import 'package:app_movil/core/services/startup_flow_coordinator.dart';
import 'package:app_movil/core/utils/backup_manager.dart';
import 'package:app_movil/features/profile/services/business_backup_service.dart';
import 'package:app_movil/features/profile/widgets/delete_business_modal.dart';
import 'package:app_movil/features/profile/widgets/google_drive_backup_sheet.dart';
import 'package:app_movil/features/profile/widgets/drive_action_feedback_modal.dart';

// Widgets y lógica extraídos
import 'package:app_movil/features/auth/screens/onboarding/widgets/profile_card_widgets.dart';
import 'package:app_movil/features/auth/screens/onboarding/widgets/profile_management_modals.dart';
import 'package:app_movil/features/auth/screens/onboarding/widgets/profile_restore_handler.dart';

part 'widgets/profile_selection_lists_section.dart';
part 'widgets/profile_backup_section.dart';
part 'widgets/profile_drive_modals.dart';

class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

abstract class _ProfileSelectionStateBase extends State<ProfileSelectionScreen>
    with SingleTickerProviderStateMixin {
  
  // --- Animaciones de entrada ---
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  // --- Estado del modo de pantalla ---
  ProfileScreenMode _screenMode = ProfileScreenMode.normal;
  int? _selectedProfileId;
  bool _isProcessing = false;
  String _processingMessage = "";
  bool _isDriveActionLoading = false;

  // --- Orden persistido de perfiles ---
  List<int> _profileOrder = [];
  int? _lastActiveUserId;
  final Set<int> _pinProfileIds = {};
  final Set<String> _duplicateNames = {};

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    _slideAnim = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _animController.forward();
    _loadProfileOrder();
    _loadProfileMetadata();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await StartupFlowCoordinator.coordinateStartup(context);
    });
  }

  Future<bool> _ensureEulaAccepted() async {
    final licenseProv = Provider.of<LicenseProvider?>(context, listen: false);
    if (licenseProv == null) return false;
    if (licenseProv.license == null) {
      await licenseProv.checkLicense();
    }
    if (licenseProv.license?.eulaAcceptedVersion != null) return true;
    if (!mounted) return false;
    final accepted = await EulaAcceptanceModal.show(context);
    return accepted == true;
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ============================================================
  // GESTIÓN DEL ORDEN PERSISTIDO DE PERFILES
  // ============================================================

  Future<void> _loadProfileOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final orderJson = prefs.getString('profile_order');
    if (orderJson != null && mounted) {
      setState(() {
        _profileOrder = List<int>.from(jsonDecode(orderJson));
      });
    }
  }

  Future<void> _saveProfileOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_order', jsonEncode(_profileOrder));
  }

  Future<void> _loadProfileMetadata() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getInt('last_active_user_id');

      final pinSet = <int>{};
      for (var p in auth.localProfiles) {
        if (await auth.profileHasPin(p.id)) {
          pinSet.add(p.id);
        }
      }

      final counts = <String, int>{};
      for (var p in auth.localProfiles) {
        final name = p.business?.commercialName.trim().toLowerCase() ?? '';
        if (name.isNotEmpty) {
          counts[name] = (counts[name] ?? 0) + 1;
        }
      }
      final duplicates = counts.entries.where((e) => e.value > 1).map((e) => e.key).toSet();

      if (mounted) {
        setState(() {
          _lastActiveUserId = lastId;
          _pinProfileIds.addAll(pinSet);
          _duplicateNames.addAll(duplicates);
        });
      }
    } catch (_) {}
  }

  List<UserModel> _getOrderedProfiles(List<UserModel> profiles) {
    if (_profileOrder.isEmpty) return List.from(profiles);

    final ordered = <UserModel>[];
    for (int id in _profileOrder) {
      final matching = profiles.where((p) => p.id == id);
      if (matching.isNotEmpty) ordered.add(matching.first);
    }
    for (var p in profiles) {
      if (!ordered.any((o) => o.id == p.id)) ordered.add(p);
    }
    return ordered;
  }

  void _onReorder(int oldIndex, int newIndex, List<UserModel> orderedProfiles) {
    if (oldIndex < newIndex) newIndex--;

    final movedProfile = orderedProfiles[oldIndex];
    final newOrder = List<UserModel>.from(orderedProfiles);
    newOrder.removeAt(oldIndex);
    newOrder.insert(newIndex, movedProfile);

    setState(() {
      _profileOrder = newOrder.map((p) => p.id).toList();
    });

    _saveProfileOrder();
    HapticFeedback.mediumImpact();
  }

  // ============================================================
  // NAVEGACIÓN A PERFIL (modo normal)
  // ============================================================

  Future<void> _handleProfileSelection(int userId, AuthProvider auth) async {
    if (!await _ensureEulaAccepted()) return;
    if (!mounted) return;
    bool hasPin = await auth.profileHasPin(userId);

    if (!mounted) return;

    if (hasPin) {
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              LockScreen(userId: userId),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } else {
      await auth.loginWithProfile(userId);
      if (mounted) {
        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  // ============================================================
  // MANEJO DE SELECCIÓN EN MODO SELECCIÓN
  // ============================================================

  void _handleProfileTapInSelectionMode(UserModel profile, AuthProvider auth) {
    setState(() => _selectedProfileId = profile.id);

    if (_screenMode == ProfileScreenMode.selectForBackup) {
      showBackupConfirmationModal(
        context: context,
        profile: profile,
        onCancel: () => setState(() => _selectedProfileId = null),
        onConfirm: () => _executeProfileBackup(profile),
      );
    } else if (_screenMode == ProfileScreenMode.selectForDelete) {
      _showDeleteBusinessModal(context, auth, profile.id);
    }
  }

  void _cancelSelection() {
    if (_screenMode == ProfileScreenMode.selectForBackup) {
      setState(() {
        _screenMode = ProfileScreenMode.normal;
        _selectedProfileId = null;
      });
      Future.microtask(() => _openBackupTypeModal());
    } else {
      setState(() {
        _screenMode = ProfileScreenMode.normal;
        _selectedProfileId = null;
      });
    }
  }

  // ============================================================
  // INVOCACIÓN DE MODALES (puente hacia funciones extraídas)
  // ============================================================

  void _openManagementModal() {
    showProfileManagementModal(
      context: context,
      onBackupOptionSelected: _openBackupTypeModal,
      onDeleteOptionSelected: () {
        setState(() {
          _screenMode = ProfileScreenMode.selectForDelete;
          _selectedProfileId = null;
        });
      },
    );
  }

  void _openBackupTypeModal() {
    showBackupTypeModal(
      context: context,
      onSpecificProfileSelected: () {
        setState(() {
          _screenMode = ProfileScreenMode.selectForBackup;
          _selectedProfileId = null;
        });
      },
      onFullSystemSelected: _executeFullSystemBackup,
    );
  }

  // ============================================================
  // MODAL DE ELIMINACIÓN (reutiliza DeleteBusinessModal existente)
  // ============================================================

  void _showDeleteBusinessModal(BuildContext context, AuthProvider auth, int userId) async {
    bool hasPin = await auth.profileHasPin(userId);
    if (!context.mounted) return;

    final bool? deleted = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteBusinessModal(
        userId: userId,
        hasPin: hasPin,
      ),
    );

    if (!mounted) return;

    if (deleted == true) {
      _profileOrder.remove(userId);
      _saveProfileOrder();

      setState(() {
        _screenMode = ProfileScreenMode.normal;
        _selectedProfileId = null;
      });

      if (context.mounted) {
        auth.checkInitialState();
        CustomSnackBar.show(context, message: "Perfil eliminado correctamente.", isError: false);
      }
    } else {
      setState(() => _selectedProfileId = null);
    }
  }

  Future<void> _executeProfileBackup(UserModel profile);
  Future<void> _executeFullSystemBackup();
  Widget _buildEmptyState(bool isDark);
  Widget _buildManagementButton(bool isDark);
  Widget _buildSelectionHeader(bool isDark);
  Widget _buildReorderableList(List<UserModel> profiles, bool isDark, AuthProvider auth);
  Widget _buildSelectionList(List<UserModel> profiles, bool isDark, AuthProvider auth);
  Widget _buildNormalBottomSection(bool isDark, List<UserModel> profiles);
  Widget _buildCancelButton(bool isDark);
  Widget _buildUnifiedBackupSection(BuildContext context, {required bool isDark, required bool isEmptyState, required List<UserModel> profiles});
  Future<void> _handleDriveSignIn(GoogleDriveBackupProvider driveProv);
  void _openDriveQuickOptionsModal(GoogleDriveBackupProvider driveProv, bool isDark, List<UserModel> profiles);

  // ============================================================
  // BUILD PRINCIPAL
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final orderedProfiles = _getOrderedProfiles(auth.localProfiles);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final isSelectionMode = _screenMode != ProfileScreenMode.normal;

    String headerSubtitle;
    switch (_screenMode) {
      case ProfileScreenMode.normal:
        headerSubtitle = "Selecciona tu espacio de trabajo";
        break;
      case ProfileScreenMode.selectForBackup:
        headerSubtitle = "Selecciona un perfil para respaldar";
        break;
      case ProfileScreenMode.selectForDelete:
        headerSubtitle = "Selecciona un perfil para eliminar";
        break;
    }

    return AuthBackground(
      headerContent: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnim.value,
            child: Column(
              children: [
                Hero(
                  tag: 'app_brand_logo',
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 55,
                      height: 55,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.storefront,
                        size: 55,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "MochilaLista",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    headerSubtitle,
                    key: ValueKey(headerSubtitle),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnim.value,
            child: Transform.translate(
              offset: Offset(0, _slideAnim.value),
              child: child,
            ),
          );
        },
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (orderedProfiles.isEmpty)
                    _buildEmptyState(isDark)
                  else ...[
                    // Barra superior: botón gestionar o indicador de modo selección
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: isSelectionMode
                          ? _buildSelectionHeader(isDark)
                          : _buildManagementButton(isDark),
                    ),
                    const SizedBox(height: 8),

                    // Lista de perfiles
                    Expanded(
                      child: isSelectionMode
                          ? _buildSelectionList(orderedProfiles, isDark, auth)
                          : _buildReorderableList(orderedProfiles, isDark, auth),
                    ),

                    // Sección inferior
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: isSelectionMode
                          ? _buildCancelButton(isDark)
                          : _buildNormalBottomSection(isDark, orderedProfiles),
                    ),
                  ],
                ],
              ),
            ),

            if (_isProcessing)
              ProfileProcessingOverlay(
                message: _processingMessage,
                isDark: isDark,
                surfaceColor: surfaceColor,
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSelectionScreenState extends _ProfileSelectionStateBase
    with
        _ProfileSelectionListsMixin,
        _ProfileBackupSectionMixin,
        _ProfileDriveModalsMixin {}
