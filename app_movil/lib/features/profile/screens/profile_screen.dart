import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';

import '../../../../providers/auth_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../providers/catalog_provider.dart';
import '../../smart_quotation/providers/quick_sale_provider.dart';

import '../widgets/business_info_card.dart';
import '../widgets/profile_menu_item.dart';
import '../widgets/edit_profile_modal.dart';
import '../widgets/edit_business_modal.dart';
import '../widgets/change_pin_modal.dart'; // Si lo renombraste a pin
import '../../../../widgets/custom_snackbar.dart';
import '../../../../screens/onboarding/profile_selection_screen.dart'; 
import 'printer_config_screen.dart';
import 'notifications_screen.dart';
import 'backup_screen.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String? _getValidLocalImagePath(String? rawPath) {
    if (rawPath == null || rawPath.trim().isEmpty || rawPath == 'null') return null;
    return rawPath; 
  }

  Future<void> _refreshProfile() async {
    // 🔥 USANDO checkInitialState en lugar del antiguo checkAuthStatus
    await Provider.of<AuthProvider>(context, listen: false).checkInitialState();
    if (mounted) CustomSnackBar.show(context, message: "Datos actualizados", isError: false);
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
    final user = auth.user;

    if (user == null || !auth.isAuthenticated) {
      return Scaffold(
        backgroundColor: themeProv.isDarkMode ? const Color(0xFF14141C) : const Color(0xFFF5F7FA),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = themeProv.isDarkMode;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87; 

    return Scaffold(
      backgroundColor: bgColor,
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        color: Colors.blue[800],
        child: SingleChildScrollView(
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
                      _buildSectionHeader("Administración del Negocio", textColor, 
                        actionLabel: "Editar Datos", 
                        onAction: () => _showEditBusiness(context)
                      ),
                      const SizedBox(height: 12),
                      BusinessInfoCard(business: auth.currentBusiness), 
                      const SizedBox(height: 35),

                      _buildSectionHeader("Configuración General", textColor),
                      const SizedBox(height: 12),
                      _buildSettingsContainer(cardColor, [
                        ProfileMenuItem(title: "Editar Datos Personales", icon: Icons.person_outline, isDark: isDark, onTap: () => _showEditProfile(context)),
                        _buildDivider(isDark),
                        
                        ProfileMenuItem(
                          title: "Respaldos y Seguridad", 
                          icon: Icons.security_rounded, 
                          isDark: isDark, 
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen()))
                        ),
                        _buildDivider(isDark),

                        ProfileMenuItem(
                          title: isDark ? "Modo Noche" : "Modo Claro",
                          icon: isDark ? Icons.nightlight_round : Icons.wb_sunny_outlined, 
                          isDark: isDark, 
                          onTap: () => themeProv.toggleTheme(!isDark), 
                          trailing: Switch(
                            value: isDark, 
                            activeThumbColor: Colors.blue[400], 
                            onChanged: (v) => themeProv.toggleTheme(v)
                          )
                        ),
                        _buildDivider(isDark),
                        ProfileMenuItem(title: "Notificaciones", icon: Icons.notifications_none, isDark: isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
                        _buildDivider(isDark),
                        ProfileMenuItem(title: "Impresora Térmica", icon: Icons.print_outlined, isDark: isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterConfigScreen())), trailing: const Icon(Icons.bluetooth, size: 22, color: Colors.blue)),
                      ]),

                      const SizedBox(height: 35),
                      _buildSectionHeader("Seguridad de la Cuenta", textColor),
                      const SizedBox(height: 12),
                      _buildSettingsContainer(cardColor, [
                        ProfileMenuItem(title: "Cambiar PIN de Seguridad", icon: Icons.lock_outline, isDark: isDark, onTap: () => _showChangePassword(context)),
                        _buildDivider(isDark),
                        ProfileMenuItem(title: "Cambiar de Negocio / Cerrar Sesión", icon: Icons.logout, isDark: isDark, isDestructive: true, onTap: () => _confirmLogout(context, auth, isDark)),
                      ]),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color? color, {String? actionLabel, VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap), child: Text(actionLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue)))
      ],
    );
  }

  Widget _buildSettingsContainer(Color color, List<Widget> children) => Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(children: children));
  
  Widget _buildDivider(bool isDark) => Divider(height: 1, indent: 65, endIndent: 20, color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]);

  Widget _buildHeader(BuildContext context, AuthProvider auth, bool isDark) {
    final String? validLogoPath = _getValidLocalImagePath(auth.currentBusiness?.logoUrl);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isDark ? [const Color(0xFF0D47A1), const Color(0xFF001633)] : [const Color(0xFF1976D2), const Color(0xFF0D47A1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
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
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Column(
                children: [
                  const SizedBox(height: 15),
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15)),
                        child: CircleAvatar(
                          radius: 52, 
                          backgroundColor: Colors.white,
                          backgroundImage: (validLogoPath != null && !validLogoPath.startsWith('http')) ? FileImage(File(validLogoPath)) : null,
                          child: validLogoPath == null ? const Icon(Icons.store, size: 55, color: Color(0xFF1565C0)) : null,
                        ),
                      ),
                      InkWell(
                        onTap: () => _showPhotoOptions(context, auth, validLogoPath),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                          child: auth.isLoading 
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(auth.userName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  if (auth.currentBusiness != null)
                    Text(auth.businessName, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.w500)),
                  
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.3))),
                    child: const Text("DUEÑO DE NEGOCIO", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhotoOptions(BuildContext context, AuthProvider auth, String? validLogoPath) {
    if (auth.isLoading) return; 
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF23232F) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 15),
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              
              if (validLogoPath != null && !validLogoPath.startsWith('http'))
                _buildModalOption(icon: Icons.fullscreen, text: "Ver foto en pantalla completa", color: Colors.blue, isDark: isDark, onTap: () {
                  Navigator.pop(ctx);
                  _openFullScreenImage(validLogoPath);
                }),
              
              _buildModalOption(icon: Icons.image_search, text: "Elegir foto de la galería", color: Colors.green, isDark: isDark, onTap: () {
                Navigator.pop(ctx);
                _pickImage(context, auth);
              }),
              
              if (validLogoPath != null)
                _buildModalOption(icon: Icons.delete_outline, text: "Eliminar foto actual", color: Colors.red, isDark: isDark, isDestructive: true, onTap: () async {
                  Navigator.pop(ctx);
                  final biz = auth.currentBusiness!;
                  bool success = await auth.updateBusinessProfile(biz.commercialName, biz.ruc ?? "", biz.address ?? "", biz.paymentInfo ?? "", biz.latitud, biz.longitud, true, true, clearLogo: true);
                  if (context.mounted) {
                    if (success) {
                      CustomSnackBar.show(context, message: "La foto ha sido eliminada.", isError: false);
                    } else {
                      CustomSnackBar.show(context, message: auth.errorMessage, isError: true);
                    }
                  }
                }),
                
              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalOption({required IconData icon, required String text, required Color color, required bool isDark, bool isDestructive = false, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDestructive ? Colors.red : (isDark ? Colors.white : Colors.black87))),
      onTap: onTap,
    );
  }

  void _openFullScreenImage(String imagePath) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white), elevation: 0),
      extendBodyBehindAppBar: true,
      body: Center(
        child: PhotoView(
          imageProvider: FileImage(File(imagePath)), 
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
        ),
      ),
    )));
  }

  Future<void> _pickImage(BuildContext context, AuthProvider auth) async {
    if (auth.isLoading) return; 
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        bool success = await auth.uploadBusinessLogo(File(image.path));
        if (context.mounted) {
          if (success) {
            CustomSnackBar.show(context, message: "Foto guardada exitosamente", isError: false);
          } else {
            CustomSnackBar.show(context, message: auth.errorMessage, isError: true);
          }
        }
      }
    } catch (e) {
      if (context.mounted) CustomSnackBar.show(context, message: "Error al abrir la galería", isError: true);
    }
  }

  void _showEditProfile(BuildContext context) => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => const EditProfileModal());
  void _showEditBusiness(BuildContext context) => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => const EditBusinessModal());
  void _showChangePassword(BuildContext context) => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => const ChangePasswordModal());

  void _confirmLogout(BuildContext context, AuthProvider auth, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.logout, color: Colors.red)),
            const SizedBox(width: 12),
            const Expanded(child: Text("Cambiar de Negocio", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          ],
        ),
        content: Text("Al cerrar este negocio, serás redirigido a la pantalla principal para seleccionar otro o crear uno nuevo. Todo tu progreso sin guardar (carritos y ventas en curso) se limpiará.", style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.grey[700])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); 
              _clearVolatileMemory(context);
              await auth.logout();
              
              if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()), (route) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
            child: const Text("Sí, salir", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
    );
  }
}