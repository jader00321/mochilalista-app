import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/widgets/primary_button.dart';
import 'package:app_movil/core/widgets/auth_background.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/auth/screens/onboarding/onboarding_screen.dart';
import 'package:app_movil/core/screens/home_screen.dart';
import 'package:app_movil/features/auth/screens/onboarding/lock_screen.dart';
import 'package:app_movil/core/utils/backup_manager.dart';
import 'package:app_movil/features/profile/services/business_backup_service.dart';
import 'package:app_movil/features/profile/widgets/delete_business_modal.dart';

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
                onPressed: () {
                  Navigator.push(context, PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
                  ));
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => showProfileRestoreBottomSheet(context),
                child: Text("¿Tienes un backup? Restaurar aquí", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[700], decoration: TextDecoration.underline, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 16),
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
                onPressed: () {
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
          const SizedBox(height: 24),
          PrimaryButton(
            text: "CREAR NUEVO NEGOCIO",
            icon: Icons.add_business_rounded,
            onPressed: () {
              Navigator.push(context, PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
              ));
            },
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => showProfileRestoreBottomSheet(context),
            child: Text(
              "¿Tienes un backup? Restaurar aquí",
              style: TextStyle(
                color: isDark ? Colors.blue[300] : Colors.blue[700],
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
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
}