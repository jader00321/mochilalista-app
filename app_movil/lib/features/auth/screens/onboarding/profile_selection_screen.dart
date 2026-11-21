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

// Widgets y lógica extraídos
import 'package:app_movil/features/auth/screens/onboarding/widgets/profile_card_widgets.dart';
import 'package:app_movil/features/auth/screens/onboarding/widgets/profile_management_modals.dart';
import 'package:app_movil/features/auth/screens/onboarding/widgets/profile_restore_handler.dart';

class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen>
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

  // ============================================================
  // EJECUCIÓN DE BACKUP: Perfil específico
  // ============================================================

  Future<void> _executeProfileBackup(UserModel profile) async {
    final negocioId = profile.business?.id;
    final businessName = profile.business?.commercialName ?? "Negocio";

    if (negocioId == null) {
      if (mounted) CustomSnackBar.show(context, message: "Este perfil no tiene un negocio asociado.", isError: true);
      setState(() {
        _screenMode = ProfileScreenMode.normal;
        _selectedProfileId = null;
      });
      return;
    }

    setState(() {
      _screenMode = ProfileScreenMode.normal;
      _selectedProfileId = null;
      _isProcessing = true;
      _processingMessage = "Creando backup de\n$businessName...";
    });

    try {
      bool ok = await BusinessBackupService.exportBusinessToFile(negocioId, businessName);

      if (mounted) {
        setState(() => _isProcessing = false);
        if (ok) {
          CustomSnackBar.show(context, message: "¡Backup de \"$businessName\" guardado en Descargas!", isError: false);
        } else {
          CustomSnackBar.show(context, message: "Error al crear el backup.", isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        CustomSnackBar.show(context, message: "Error: $e", isError: true);
      }
    }
  }

  // ============================================================
  // EJECUCIÓN DE BACKUP: Sistema completo
  // ============================================================

  Future<void> _executeFullSystemBackup() async {
    setState(() {
      _isProcessing = true;
      _processingMessage = "Creando backup del\nsistema completo...";
    });

    try {
      bool ok = await BackupManager.exportToDownloads();

      if (mounted) {
        setState(() => _isProcessing = false);
        if (ok) {
          CustomSnackBar.show(context, message: "¡Backup del sistema guardado en Descargas!", isError: false);
        } else {
          CustomSnackBar.show(context, message: "Error al crear el backup del sistema.", isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        CustomSnackBar.show(context, message: "Error: $e", isError: true);
      }
    }
  }

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

  // ============================================================
  // SUB-BUILDERS DE UI
  // ============================================================

  Widget _buildEmptyState(bool isDark) {
    return Expanded(
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.store_mall_directory_outlined, size: 80, color: isDark ? Colors.grey[700] : Colors.grey[300]),
              const SizedBox(height: 16),
              Text("No hay negocios registrados", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              Text("Crea tu primer perfil para empezar.", textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
              const SizedBox(height: 40),
              PrimaryButton(
                text: "CREAR NUEVO NEGOCIO",
                icon: Icons.add_business_rounded,
                onPressed: () async {
                  if (!await _ensureEulaAccepted()) return;
                  if (!mounted) return;
                  Navigator.push(context, PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
                  ));
                },
              ),
              const SizedBox(height: 12),
              _buildGoogleDriveSection(context, isDark: isDark, isEmptyState: true, profiles: const []),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => showProfileRestoreBottomSheet(context),
                child: Text(
                  "¿Tienes un archivo local (.mlbg)? Restaurar aquí",
                  style: TextStyle(
                    color: isDark ? Colors.blue[300] : Colors.blue[700],
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                icon: Icon(Icons.explore_outlined, size: 18, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
                label: Text(
                  "Explorar la app sin registrarse (Modo Demo)",
                  style: TextStyle(
                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                onPressed: () async {
                  if (!await _ensureEulaAccepted()) return;
                  if (!mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)).withValues(alpha: 0.35),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManagementButton(bool isDark) {
    return Align(
      key: const ValueKey('management_btn'),
      alignment: Alignment.centerRight,
      child: Material(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _openManagementModal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 18, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                const SizedBox(width: 6),
                Text("Gestionar", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.grey[400] : Colors.grey[600])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionHeader(bool isDark) {
    final isBackup = _screenMode == ProfileScreenMode.selectForBackup;
    final color = isBackup ? Colors.indigoAccent : Colors.redAccent;
    final icon = isBackup ? Icons.backup_rounded : Icons.delete_forever_rounded;
    final text = isBackup ? "Toca el perfil que deseas respaldar" : "Toca el perfil que deseas eliminar";

    return Container(
      key: const ValueKey('selection_header'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.1 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color))),
        ],
      ),
    );
  }

  Widget _buildReorderableList(List<UserModel> profiles, bool isDark, AuthProvider auth) {
    return ReorderableListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: profiles.length,
      buildDefaultDragHandles: true,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final double elevateVal = lerpDouble(0, 12, Curves.easeInOut.transform(animation.value))!;
            return Material(
              elevation: elevateVal,
              color: Colors.transparent,
              shadowColor: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              child: child,
            );
          },
          child: child,
        );
      },
      onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, profiles),
      itemBuilder: (context, index) {
        final p = profiles[index];
        final isLastActive = p.id == _lastActiveUserId;
        final hasPin = _pinProfileIds.contains(p.id);
        final bName = p.business?.commercialName.trim().toLowerCase() ?? '';
        final isDuplicate = _duplicateNames.contains(bName);

        return AnimatedProfileCard(
          key: ValueKey(p.id),
          controller: _animController,
          index: index,
          onTap: () => _handleProfileSelection(p.id, auth),
          child: ProfileCardContent(
            profile: p,
            isDark: isDark,
            isSelectionMode: false,
            screenMode: _screenMode,
            isLastActive: isLastActive,
            hasPin: hasPin,
            isDuplicateName: isDuplicate,
          ),
        );
      },
    );
  }

  Widget _buildSelectionList(List<UserModel> profiles, bool isDark, AuthProvider auth) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: profiles.length,
      itemBuilder: (context, index) {
        final p = profiles[index];
        final isSelected = _selectedProfileId == p.id;
        final isLastActive = p.id == _lastActiveUserId;
        final hasPin = _pinProfileIds.contains(p.id);
        final bName = p.business?.commercialName.trim().toLowerCase() ?? '';
        final isDuplicate = _duplicateNames.contains(bName);

        return AnimatedProfileCard(
          key: ValueKey(p.id),
          controller: _animController,
          index: index,
          onTap: () => _handleProfileTapInSelectionMode(p, auth),
          child: ProfileCardContent(
            profile: p,
            isDark: isDark,
            isSelectionMode: true,
            isSelected: isSelected,
            screenMode: _screenMode,
            isLastActive: isLastActive,
            hasPin: hasPin,
            isDuplicateName: isDuplicate,
          ),
        );
      },
    );
  }

  Widget _buildNormalBottomSection(bool isDark, List<UserModel> profiles) {
    return AnimatedBuilder(
      key: const ValueKey('normal_bottom'),
      animation: _animController,
      builder: (context, child) {
        final start = 0.2 + (profiles.length * 0.1).clamp(0.0, 0.5);
        final end = start + 0.3;

        final slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
          CurvedAnimation(parent: _animController, curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOutCubic)),
        );
        final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _animController, curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOut)),
        );

        return Opacity(
          opacity: fadeAnimation.value,
          child: Transform.translate(offset: Offset(0, slideAnimation.value), child: child),
        );
      },
      child: Column(
        children: [
          const SizedBox(height: 16),
          PrimaryButton(
            text: "CREAR NUEVO NEGOCIO",
            icon: Icons.add_business_rounded,
            onPressed: () async {
              if (!await _ensureEulaAccepted()) return;
              if (!mounted) return;
              Navigator.push(context, PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
              ));
            },
          ),
          const SizedBox(height: 12),
          _buildGoogleDriveSection(context, isDark: isDark, isEmptyState: false, profiles: profiles),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => showProfileRestoreBottomSheet(context),
            child: Text(
              "¿Tienes un archivo local (.mlbg)? Restaurar aquí",
              style: TextStyle(
                color: isDark ? Colors.blue[300] : Colors.blue[700],
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Botón discreto y elegante para Modo Explorador (CERO emojis Unicode)
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.explore_outlined,
                    size: 17,
                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Explorar la app sin registrarse (Modo Demo)",
                    style: TextStyle(
                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
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

  Widget _buildCancelButton(bool isDark) {
    final isBackup = _screenMode == ProfileScreenMode.selectForBackup;
    final color = isBackup ? Colors.indigoAccent : Colors.redAccent;

    return Padding(
      key: const ValueKey('cancel_btn'),
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: Icon(Icons.arrow_back_rounded, size: 20, color: color),
          label: Text(
            isBackup ? "Cancelar y volver" : "Cancelar",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color),
          ),
          onPressed: _cancelSelection,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECCIÓN INTELIGENTE DE GOOGLE DRIVE EN PERFILES
  // ============================================================

  Widget _buildGoogleDriveSection(
    BuildContext context, {
    required bool isDark,
    required bool isEmptyState,
    required List<UserModel> profiles,
  }) {
    final driveProv = Provider.of<GoogleDriveBackupProvider?>(context);
    if (driveProv == null) return const SizedBox.shrink();

    final isConnected = driveProv.isConnected && driveProv.currentUser != null;

    if (!isConnected) {
      // Estado A: Google Drive NO vinculado
      return InkWell(
        key: const ValueKey('drive_unlinked_card'),
        onTap: _isDriveActionLoading ? null : () => _handleDriveSignIn(driveProv),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_download_rounded,
                  size: 22,
                  color: Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Recuperar desde Google Drive",
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Vincula tu correo para respaldar o restaurar tus negocios en la nube",
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.25,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (_isDriveActionLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                ),
            ],
          ),
        ),
      );
    }

    // Estado B: Google Drive YA vinculado (Semáforo de salud reactivo)
    final health = GoogleDriveBackupProvider.computeHealthInfo(
      backups: driveProv.backups,
      isDark: isDark,
    );

    return InkWell(
      key: const ValueKey('drive_linked_card'),
      onTap: () => _openDriveQuickOptionsModal(driveProv, isDark, profiles),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: health.color.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: health.color.withValues(alpha: isDark ? 0.35 : 0.45),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: health.color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                health.icon,
                size: 18,
                color: health.color,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driveProv.currentUser?.email ?? "Cuenta Google",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    health.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: health.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.more_vert_rounded,
              size: 18,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDriveSignIn(GoogleDriveBackupProvider driveProv) async {
    if (!await _ensureEulaAccepted()) return;
    if (!mounted) return;

    setState(() {
      _isDriveActionLoading = true;
    });

    try {
      final licenseHardwareId = Provider.of<LicenseProvider?>(context, listen: false)?.deviceFingerprint;
      final user = await driveProv.signIn(licenseHardwareId: licenseHardwareId);
      if (!mounted) return;

      if (user != null) {
        if (driveProv.backups.isNotEmpty) {
          await GoogleDriveBackupSheet.showGuidedWhatsAppRestoreModal(
            context,
            driveProvider: driveProv,
            allBackups: driveProv.backups,
            userEmail: user.email,
            isDark: Theme.of(context).brightness == Brightness.dark,
            onRestoreSuccess: () async {
              await _loadProfileOrder();
              await _loadProfileMetadata();
              if (mounted) setState(() {});
            },
          );
        } else {
          CustomSnackBar.show(
            context,
            message: "Cuenta vinculada (${user.email}). No se encontraron copias previas.",
            isError: false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final licenseHardwareId = Provider.of<LicenseProvider?>(context, listen: false)?.deviceFingerprint;
        await GoogleDriveBackupSheet.showOAuthErrorDialog(
          context,
          e,
          isDark: Theme.of(context).brightness == Brightness.dark,
          passedHardwareId: licenseHardwareId,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDriveActionLoading = false;
        });
      }
    }
  }

  void _openDriveQuickOptionsModal(
    GoogleDriveBackupProvider driveProv,
    bool isDark,
    List<UserModel> profiles,
  ) {
    final bottomSafety = math.max(
      MediaQuery.viewInsetsOf(context).bottom,
      math.max(
        MediaQuery.viewPaddingOf(context).bottom,
        MediaQuery.paddingOf(context).bottom,
      ),
    ) + 12.0;

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => SafeArea(
        top: false,
        bottom: true,
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomSafety),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E28) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_sync_rounded,
                        color: Color(0xFF25D366),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Google Drive",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            driveProv.currentUser?.email ?? "",
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Opción 1: Ver y Restaurar Copias
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.history_rounded, color: Colors.blue, size: 20),
                  ),
                  title: const Text(
                    "Ver y Restaurar Copias de la Nube",
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    driveProv.backups.isNotEmpty
                        ? "Explora las ${driveProv.backups.length} copias disponibles"
                        : "No hay copias guardadas en Google Drive aún",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    if (driveProv.backups.isEmpty) {
                      CustomSnackBar.show(
                        context,
                        message: "No hay copias de seguridad en Google Drive aún.",
                      );
                    } else {
                      GoogleDriveBackupSheet.showGuidedWhatsAppRestoreModal(
                        context,
                        driveProvider: driveProv,
                        allBackups: driveProv.backups,
                        userEmail: driveProv.currentUser?.email ?? "",
                        isDark: isDark,
                        onRestoreSuccess: () async {
                          await _loadProfileOrder();
                          await _loadProfileMetadata();
                          if (mounted) setState(() {});
                        },
                      );
                    }
                  },
                ),
                Divider(height: 12, color: isDark ? Colors.white12 : Colors.black12),

                // Opción 2: Respaldar Ahora
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cloud_upload_rounded, color: Colors.green, size: 20),
                  ),
                  title: const Text(
                    "Respaldar Ahora en Google Drive",
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    profiles.isNotEmpty
                        ? "Genera una copia inmediata de tus ${profiles.length} perfil(es)"
                        : "Crea al menos un negocio antes de respaldar",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    if (profiles.isEmpty) {
                      CustomSnackBar.show(
                        context,
                        message: "Crea al menos un negocio antes de realizar un respaldo.",
                        isError: true,
                      );
                    } else {
                      _executeDriveBackupNow(driveProv);
                    }
                  },
                ),
                Divider(height: 12, color: isDark ? Colors.white12 : Colors.black12),

                // Opción 3: Desvincular Cuenta
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.link_off_rounded, color: Colors.redAccent, size: 20),
                  ),
                  title: const Text(
                    "Desvincular Cuenta de Google",
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.redAccent),
                  ),
                  subtitle: Text(
                    "Tus copias en la nube se mantendrán intactas",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _confirmAndSignOutDrive(driveProv, isDark);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndSignOutDrive(
    GoogleDriveBackupProvider driveProv,
    bool isDark,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.link_off_rounded, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "¿Desvincular Google Drive?",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: const Text(
          "Tus respaldos en la nube se mantendrán a salvo en tu cuenta de Google, pero la sincronización automática en este celular se detendrá.",
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Desvincular"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await driveProv.signOut();
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "Cuenta de Google desvinculada.",
          isError: false,
        );
      }
    }
  }

  Future<void> _executeDriveBackupNow(GoogleDriveBackupProvider driveProv) async {
    setState(() {
      _isProcessing = true;
      _processingMessage = "Guardando respaldo en\nGoogle Drive...";
    });

    try {
      final meta = await driveProv.performBackupNow();
      if (mounted) {
        setState(() => _isProcessing = false);
        CustomSnackBar.show(
          context,
          message: "¡Copia de seguridad guardada en Google Drive! (${meta?.formattedSize ?? ''})",
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        CustomSnackBar.show(
          context,
          message: "No se pudo completar el respaldo: $e",
          isError: true,
        );
      }
    }
  }
}