import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/core/widgets/primary_button.dart';
import 'package:app_movil/core/widgets/auth_background.dart';
import 'package:app_movil/features/auth/screens/onboarding/onboarding_screen.dart';
import 'package:app_movil/core/screens/home_screen.dart';
import 'package:app_movil/features/auth/screens/onboarding/lock_screen.dart';
import 'package:app_movil/core/providers/backup_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:app_movil/core/utils/backup_manager.dart';
import 'package:app_movil/features/profile/services/business_backup_service.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/profile/widgets/delete_business_modal.dart';
class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

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
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleProfileSelection(int userId, AuthProvider auth) async {
    // 1. Verificamos si este usuario configuró un PIN en su almacenamiento seguro local
    bool hasPin = await auth.profileHasPin(userId);

    if (!mounted) return;

    if (hasPin) {
      // Si tiene seguridad, lo mandamos al LockScreen para que ponga la huella o el PIN
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
      // Si no tiene seguridad, lo logueamos directamente e iniciamos la app
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

    if (deleted == true) {
      if (context.mounted) {
        auth.checkInitialState();
        CustomSnackBar.show(context, message: "Perfil eliminado correctamente.", isError: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final profiles = auth.localProfiles;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;

    return AuthBackground(
      headerContent: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnim.value,
            child: Column(
              children: [
                Container(
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
                Text(
                  "Selecciona tu espacio de trabajo",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.transparent,
            ),
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
              if (profiles.isEmpty)
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.store_mall_directory_outlined,
                            size: 80,
                            color: isDark ? Colors.grey[700] : Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No hay negocios registrados",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Crea tu primer perfil para empezar.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 40),
                          PrimaryButton(
                            text: "CREAR NUEVO NEGOCIO",
                            icon: Icons.add_business_rounded,
                            onPressed: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) =>
                                      const OnboardingScreen(),
                                  transitionsBuilder:
                                      (context, animation, secondaryAnimation, child) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        );
                                      },
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              _showRestoreBottomSheet(context);
                            },
                            child: Text(
                              "¿Tienes un backup? Restaurar aquí",
                              style: TextStyle(
                                color: isDark ? Colors.blue[300] : Colors.blue[700],
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: profiles.length,
                    itemBuilder: (context, index) {
                      final p = profiles[index];
                      final business = p.business;
                      final String bName =
                          business?.commercialName ?? "Negocio sin nombre";
                      final bool hasLogo =
                          business?.logoUrl != null &&
                          business!.logoUrl!.isNotEmpty &&
                          business.logoUrl != 'null';
                      final List<Color> gradient = _avatarGradients[p.id % _avatarGradients.length];

                      String initials = "N";
                      if (bName.isNotEmpty) {
                        final parts = bName.trim().split(RegExp(r'\s+'));
                        initials = parts.length > 1
                            ? (parts[0][0] + parts[1][0]).toUpperCase()
                            : parts[0][0].toUpperCase();
                      }

                      return _AnimatedProfileCard(
                        controller: _animController,
                        index: index,
                        onTap: () => _handleProfileSelection(p.id, auth),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.03)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey.shade200,
                            ),
                            boxShadow: [
                              if (!isDark)
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: hasLogo ? null : LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                                  boxShadow: [
                                    if (!hasLogo) BoxShadow(color: gradient[0].withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: hasLogo
                                    ? ClipOval(
                                        child: UniversalImage(
                                          path: business.logoUrl,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          initials,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        bName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.person_outline,
                                            size: 14,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            p.fullName,
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () {
                                    _showDeleteBusinessModal(context, auth, p.id);
                                  },
                                ),
                                // Indicador de estado
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.blue.withValues(alpha: 0.1)
                                        : Colors.blue.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 16,
                                    color: isDark
                                        ? Colors.blue[300]
                                        : Colors.blue[700],
                                  ),
                                ),
                              ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                AnimatedBuilder(
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
                      child: Transform.translate(
                        offset: Offset(0, slideAnimation.value),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      PrimaryButton(
                        text: "CREAR NUEVO NEGOCIO",
                        icon: Icons.add_business_rounded,
                        onPressed: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) =>
                                  const OnboardingScreen(),
                              transitionsBuilder:
                                  (context, animation, secondaryAnimation, child) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          _showRestoreBottomSheet(context);
                        },
                        child: Text(
                          "¿Tienes un backup? Restaurar aquí",
                          style: TextStyle(
                            color: isDark ? Colors.blue[300] : Colors.blue[700],
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  void _showRestoreBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E28) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restore_rounded, color: isDark ? Colors.blue[300] : Colors.blue[700], size: 28),
                const SizedBox(width: 12),
                Text("Restaurar Backup", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
              ],
            ),
            const SizedBox(height: 8),
            Text("Elige el tipo de archivo que deseas restaurar.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 24),
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _handleUnifiedRestore(context, type: 'mlb');
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.purple.withValues(alpha: 0.1) : Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.inventory_2_rounded, color: Colors.purple),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Importar Negocio (.mlb)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text("Agrega un perfil de negocio exportado previamente.", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.purple),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _handleUnifiedRestore(context, type: 'db');
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.redAccent.withValues(alpha: 0.1) : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.storage_rounded, color: Colors.redAccent),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Restaurar Sistema Completo (.mlbg o .db)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text("Reemplaza TODA la aplicación con una copia global.", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.redAccent),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _handleUnifiedRestore(BuildContext context, {String? type}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Abrir el selector genérico para evitar PlatformException en Android
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
    } catch (e) {
      if (context.mounted) CustomSnackBar.show(context, message: "Error al abrir archivos: $e", isError: true);
      return;
    }

    if (result == null || result.files.single.path == null) return;
    
    final path = result.files.single.path!;
    final lowerPath = path.toLowerCase();

    // Validación estricta de la extensión según el botón presionado
    if (type != null) {
      if (type == 'mlb' && !lowerPath.endsWith('.mlb') && !lowerPath.endsWith('.json')) {
        if (context.mounted) CustomSnackBar.show(context, message: "Formato incorrecto. Debes elegir un archivo de negocio (.mlb o .json).", isError: true);
        return;
      } else if (type == 'db' && !lowerPath.endsWith('.db') && !lowerPath.endsWith('.mlbg')) {
        if (context.mounted) CustomSnackBar.show(context, message: "Formato incorrecto. Debes elegir un archivo de sistema (.mlbg o .db).", isError: true);
        return;
      }
    }

    if (lowerPath.endsWith('.mlb') || lowerPath.endsWith('.json')) {
      // Flujo de importar Negocio (.mlb)
      if (!context.mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.localProfiles.isEmpty) {
        CustomSnackBar.show(context, message: "Debes tener al menos una cuenta para importar un negocio.", isError: true);
        return;
      }
      
      CustomSnackBar.show(context, message: "Procesando archivo de negocio...", isError: false);
      Map<String, dynamic> backupData;
      try {
        backupData = await BusinessBackupService.readBackupFile(path);
      } catch (e) {
        if (context.mounted) CustomSnackBar.show(context, message: e.toString(), isError: true);
        return;
      }

      if (!context.mounted) return;
      bool applyPin = false;
      if (backupData['has_security_pin'] == true) {
          bool? confirmPin = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.lock_person_rounded, color: Colors.purple, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text("Clave Detectada", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.purple))),
                ],
              ),
              content: const Text("El archivo contiene una clave de seguridad. ¿Deseas configurarla como la clave de este nuevo perfil?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Ignorar", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => Navigator.pop(ctx, true), 
                  child: const Text("Sí, Usarla", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                )
              ],
            )
          );
          if (confirmPin == null) return;
          applyPin = confirmPin;
      }

      if (!context.mounted) return;
      CustomSnackBar.show(context, message: "Importando negocio...", isError: false);
      
      // Usamos el ID del primer usuario local como dueño provisional
      bool ok = await BusinessBackupService.importBusiness(auth.localProfiles.first.id, backupData['filePath'] ?? path, applyPin: applyPin);
      
      if (context.mounted) {
        if (ok) {
          CustomSnackBar.show(context, message: "Negocio importado correctamente. Inicia sesión.", isError: false);
          auth.checkInitialState();
        } else {
          CustomSnackBar.show(context, message: "No se pudo importar el negocio.", isError: true);
        }
      }

    } else if (lowerPath.endsWith('.db') || lowerPath.endsWith('.mlbg')) {
      // Flujo de restaurar Sistema completo (.db o .mlbg)
      if (!context.mounted) return;
      bool? confirmDb = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text("Restaurar Sistema", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.redAccent))),
            ],
          ),
          content: const Text("Estás a punto de reemplazar TODA la base de datos de la aplicación. Perderás todos los negocios actuales.\n\n¿Deseas continuar?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.pop(ctx, true), 
              child: const Text("Restaurar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            )
          ],
        )
      );

      if (confirmDb != true) return;
      
      if (!context.mounted) return;
      CustomSnackBar.show(context, message: "Restaurando sistema...", isError: false);
      final backupProvider = Provider.of<BackupProvider>(context, listen: false);
      
      try {
        bool success = await BackupManager.restoreBackupFromFilePath(path);
        if (context.mounted) {
          if (success) {
            CustomSnackBar.show(context, message: "Base de datos restaurada. Reiniciando...", isError: false);
            Provider.of<AuthProvider>(context, listen: false).checkInitialState();
          } else {
            CustomSnackBar.show(context, message: backupProvider.errorMessage.isNotEmpty ? backupProvider.errorMessage : "Error al restaurar la base de datos.", isError: true);
          }
        }
      } catch (e) {
        if (context.mounted) {
          CustomSnackBar.show(context, message: e.toString(), isError: true);
        }
      }
    } else {
      if (context.mounted) CustomSnackBar.show(context, message: "Formato de archivo no soportado (.db, .mlbg o .mlb)", isError: true);
    }
  }
}

class _AnimatedProfileCard extends StatefulWidget {
  final Widget child;
  final AnimationController controller;
  final int index;
  final VoidCallback onTap;

  const _AnimatedProfileCard({
    required this.child,
    required this.controller,
    required this.index,
    required this.onTap,
  });

  @override
  State<_AnimatedProfileCard> createState() => _AnimatedProfileCardState();
}

class _AnimatedProfileCardState extends State<_AnimatedProfileCard> with SingleTickerProviderStateMixin {
  late Animation<double> _scaleAnimation;
  late AnimationController _tapController;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = 0.2 + (widget.index * 0.1).clamp(0.0, 0.5);
    final end = start + 0.3;

    final slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: widget.controller,
        curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOutCubic),
      ),
    );

    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: widget.controller,
        curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOut),
      ),
    );

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        return Opacity(
          opacity: fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, slideAnimation.value),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => _tapController.forward(),
        onTapUp: (_) {
          _tapController.reverse();
          widget.onTap();
        },
        onTapCancel: () => _tapController.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}

const List<List<Color>> _avatarGradients = [
  [Color(0xFF00C6FF), Color(0xFF0072FF)], // Blue
  [Color(0xFFF77062), Color(0xFFFE5196)], // Pink/Orange
  [Color(0xFF11998E), Color(0xFF38EF7D)], // Green
  [Color(0xFF8E2DE2), Color(0xFF4A00E0)], // Purple
  [Color(0xFFF2994A), Color(0xFFF2C94C)], // Yellow/Orange
];