import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/features/profile/widgets/profile_completion_indicator.dart';

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
    await Provider.of<AuthProvider>(context, listen: false).refreshActiveUser();
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
    final bool isGuest = !auth.hasActiveContext;

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
                      _buildSectionHeader(
                        "Administración del Negocio", textColor, 
                        actionLabel: "Editar Datos", 
                        iconData: Icons.edit_note_rounded,
                        onAction: () => _showEditBusiness(context)
                      ),
                      const SizedBox(height: 16),
                      BusinessInfoCard(business: auth.currentBusiness), 
                      // 🔧 TAREA 3.2: Indicador de completitud del perfil
                      ProfileCompletionIndicator(
                          user: user,
                          hasPin: auth.hasPinCache,
                          isDark: isDark,
                          onEditProfile: () => _showEditProfile(context),
                          onEditBusiness: () => _showEditBusiness(context),
                          onChangePin: () => _showChangePassword(context),
                        ),
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

                      // 🔧 TAREA 5.4: Recordatorio amigable de PIN de seguridad si no está configurado
                      if (!auth.hasPinCache && !isGuest)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.amber.withValues(alpha: 0.12) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.amber.withValues(alpha: 0.35) : Colors.amber.shade300,
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
                                child: const Icon(Icons.shield_outlined, color: Colors.amber, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Protege tu Negocio con un PIN",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isDark ? Colors.amber[200] : Colors.amber[900],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Configura un PIN de 4 dígitos para bloquear la app y proteger tus finanzas.",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _showChangePassword(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                child: const Text("Activar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),

                      _buildSettingsContainer(cardColor, [
                        ProfileMenuItem(
                          title: auth.hasPinCache ? "Cambiar PIN de Seguridad" : "Crear PIN de Seguridad", 
                          icon: Icons.lock_outline, 
                          isDark: isDark, 
                          onTap: () => _showChangePassword(context)
                        ),
                        _buildDivider(isDark),
                        ProfileMenuItem(title: "Cambiar de Negocio / Cerrar Sesión", icon: Icons.logout, isDark: isDark, isDestructive: true, onTap: () => _confirmLogout(context, auth, isDark)),
                        _buildDivider(isDark),
                        ProfileMenuItem(title: "Eliminar Perfil Definitivamente", icon: Icons.delete_forever, isDark: isDark, isDestructive: true, onTap: () => _showDeleteBusinessModal(context, auth, isDark)),
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

  Widget _buildSectionHeader(String title, Color? color, {String? actionLabel, IconData? iconData, VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5), overflow: TextOverflow.ellipsis),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 12),
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (iconData != null) ...[
                    Icon(iconData, size: 16, color: Colors.blue),
                    const SizedBox(width: 4),
                  ],
                  Text(actionLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue)),
                ],
              ),
            ),
          )
        ]
      ],
    );
  }

  Widget _buildSettingsContainer(Color color, List<Widget> children) => Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(children: children));
  
  Widget _buildDivider(bool isDark) => Divider(height: 1, indent: 65, endIndent: 20, color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]);

  void _showDeleteBusinessModal(BuildContext context, AuthProvider auth, bool isDark) async {
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
        (route) => false
      );
    }
  }

  Widget _buildHeader(BuildContext context, AuthProvider auth, bool isDark) {
    final String? validLogoPath = _getValidLocalImagePath(auth.currentBusiness?.logoUrl);
    
    final invProv = Provider.of<InventoryProvider>(context);
    final workbench = Provider.of<WorkbenchProvider>(context);
    final salesProv = Provider.of<SaleProvider>(context);

    final int productsCount = invProv.totalProductsCount;
    final int draftsCount = workbench.inProcessList.length;
    
    final double salesDouble = salesProv.todaySalesTotal;
    final String salesTotal = salesDouble == 0 ? "Sin ventas" : NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ').format(salesDouble);

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
              // 🔧 TAREA 3.4: Info Tooltip en el perfil
              Positioned(
                right: 10,
                top: 0,
                child: InfoTooltipButton(
                  iconColor: Colors.white60,
                  title: 'Tu Perfil',
                  description: 'Desde aquí gestionas toda la información de tu cuenta y negocio. Puedes actualizar tus datos personales, configurar tu negocio, gestionar respaldos y personalizar la app.',
                  tips: const [
                    InfoTip(icon: Icons.person, text: 'Edita tu nombre, teléfono y correo electrónico en "Editar Datos Personales".'),
                    InfoTip(icon: Icons.store, text: 'Actualiza la información de tu negocio (nombre, RUC, dirección, logo) con "Editar Datos".'),
                    InfoTip(icon: Icons.security, text: 'En "Respaldos y Seguridad" puedes exportar e importar toda tu información.'),
                    InfoTip(icon: Icons.camera_alt, text: 'Toca el ícono de cámara sobre tu logo para cambiarlo.'),
                    InfoTip(icon: Icons.dark_mode, text: 'Activa el modo oscuro/claro según tu preferencia.'),
                  ],
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
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.15)),
                        child: CircleAvatar(
                          radius: 52, 
                          backgroundColor: Colors.white,
                          backgroundImage: (validLogoPath != null && !validLogoPath.startsWith('http')) ? FileImage(File(validLogoPath)) : null,
                          child: validLogoPath == null ? _buildBusinessAvatarFallback(auth.businessName) : null,
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
                    Text(auth.businessName, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16, fontWeight: FontWeight.w500)),
                  
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
                    child: const Text("DUEÑO DE NEGOCIO", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMicroKpi("Productos", "$productsCount"),
                      _buildMicroKpi("Borradores", "$draftsCount"),
                      _buildMicroKpi("Ventas Hoy", salesTotal),
                    ],
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
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10))),
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
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
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
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.logout, color: Colors.red)),
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

  Widget _buildMicroKpi(String label, String value) {
    bool isEmpty = value == "Sin ventas" || value == "0";
    return Column(
      children: [
        Text(value, style: TextStyle(color: isEmpty ? Colors.white.withValues(alpha: 0.6) : Colors.white, fontSize: isEmpty ? 16 : 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w500)),
      ],
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
        initials = cleanName.substring(0, cleanName.length > 1 ? 2 : 1).toUpperCase();
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
        child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }
}