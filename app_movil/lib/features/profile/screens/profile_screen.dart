import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🔥 IMPORT NUEVO PARA PORTAPAPELES
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';

import '../../../../providers/auth_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../providers/catalog_provider.dart';
import '../../smart_quotation/providers/quick_sale_provider.dart';
import '../../../../services/auth_service.dart';

import '../widgets/business_info_card.dart';
import '../widgets/profile_menu_item.dart';
import '../widgets/edit_profile_modal.dart';
import '../widgets/edit_business_modal.dart';
import '../widgets/create_business_modal.dart'; 
import '../widgets/change_password_modal.dart';
import '../../../../widgets/custom_snackbar.dart';
import '../../../../screens/login_screen.dart';
import '../../../../screens/home_screen.dart';
import 'team_management_screen.dart'; 
import 'printer_config_screen.dart';
import 'notifications_screen.dart';

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

  String? _getValidImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) return rawUrl;
    return null; 
  }

  Future<void> _refreshProfile() async {
    await Provider.of<AuthProvider>(context, listen: false).checkAuthStatus();
    if (mounted) CustomSnackBar.show(context, message: "Datos sincronizados", isError: false);
  }

  void _showJoinBusinessModal(BuildContext context, AuthProvider auth, bool isDark) {
    final codeCtrl = TextEditingController();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14141C) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Ingresar Invitación", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 10),
                Text("Escribe el código proporcionado por el dueño de la tienda.", style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 20),
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 20, letterSpacing: 3, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: "Código (Ej: ML-VIP-99Y)",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.vpn_key),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : () async {
                      if (codeCtrl.text.trim().isEmpty) return;
                      setState(() => isLoading = true);
                      try {
                        final authService = AuthService();
                        await authService.joinBusiness(auth.token!, codeCtrl.text.trim());
                        if (ctx.mounted) {
                           Navigator.pop(ctx); 
                           Navigator.pop(context); 
                           
                           _clearVolatileMemory(context); 
                           await auth.checkAuthStatus(); 
                           
                           CustomSnackBar.show(context, message: "¡Te has unido exitosamente!", isError: false);
                           
                           Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
                        }
                      } catch (e) {
                        if (ctx.mounted) CustomSnackBar.show(context, message: e.toString(), isError: true);
                      } finally {
                        setState(() => isLoading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("Ingresar Código", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                )
              ],
            ),
          );
        }
      ),
    );
  }
  
  void _confirmAndSwitchBusiness(BuildContext context, int targetBusinessId, String targetBusinessName, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.swap_horiz, color: Colors.orange),
            SizedBox(width: 10),
            Text("Cambiar de Negocio", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "¿Estás seguro de que deseas entrar a '$targetBusinessName'?\n\n"
          "⚠️ ATENCIÓN: Cualquier cotización, lista o carrito de compras no guardado se perderá inmediatamente por seguridad.",
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); 
              Navigator.pop(context); 
              
              _clearVolatileMemory(context);
              
              final authService = AuthService();
              final newToken = await authService.switchContext(auth.token!, targetBusinessId);
              
              if (newToken != null && mounted) {
                await auth.setContextToken(newToken);
                CustomSnackBar.show(context, message: "Conectado a $targetBusinessName", isError: false);
                
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
              } else if (mounted) {
                CustomSnackBar.show(context, message: "No se pudo cambiar de negocio.", isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Sí, Cambiar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _confirmAndCreateBusiness(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.store_mall_directory, color: Colors.blue),
            SizedBox(width: 10),
            Text("Crear Negocio", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Estás a punto de crear tu propio negocio.\n\n"
          "Se cerrará la sesión del negocio actual y entrarás a tu nueva tienda vacía. ¿Deseas continuar?",
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearVolatileMemory(context);
              showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => const CreateBusinessModal(isMandatory: false));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Sí, crear negocio", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _clearVolatileMemory(BuildContext context) {
    Provider.of<CatalogProvider>(context, listen: false).clearCart();
    Provider.of<CatalogProvider>(context, listen: false).clearUtilityList();
    Provider.of<QuickSaleProvider>(context, listen: false).clearCart();
  }

  void _showWorkspaceSelector(BuildContext context, AuthProvider auth) async {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF23232F) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 15),
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text("Mis Negocios", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 5),
            Text("Selecciona el negocio en el que deseas operar", style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 15),
            const Divider(),
            
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: AuthService().getWorkspaces(auth.token!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text("No estás asociado a ningún negocio.", style: TextStyle(color: Colors.grey[500])));
                  }

                  final workspaces = snapshot.data!;
                  return ListView.builder(
                    itemCount: workspaces.length,
                    itemBuilder: (context, index) {
                      final ws = workspaces[index];
                      final isCurrent = ws['negocio_id'] == auth.activeBusinessId;
                      final isSuspended = ws['estado_acceso'] == 'suspendido';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          backgroundImage: ws['logo_url'] != null ? NetworkImage(ws['logo_url']) : null,
                          child: ws['logo_url'] == null ? const Icon(Icons.store, color: Colors.blue) : null,
                        ),
                        title: Text(ws['nombre_negocio'], style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        subtitle: Text("Rol: ${ws['rol'].toUpperCase().replaceAll("_", " ")}", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        trailing: isCurrent 
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : (isSuspended ? const Icon(Icons.block, color: Colors.red) : const Icon(Icons.arrow_forward_ios, size: 16)),
                        onTap: isCurrent || isSuspended ? null : () {
                          _confirmAndSwitchBusiness(context, ws['negocio_id'], ws['nombre_negocio'], auth);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final themeProv = Provider.of<ThemeProvider>(context);
    final user = auth.user;

    if (!auth.isAuthenticated) {
       return Scaffold(
        backgroundColor: themeProv.isDarkMode ? const Color(0xFF14141C) : const Color(0xFFF5F7FA),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton()),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_circle, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 20),
              const Text("Inicia Sesión", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Regístrate o inicia sesión para configurar tu perfil.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false),
                child: const Text("Ir al Login"),
              )
            ],
          ),
        ),
      );
    }

    if (user == null) {
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
                      _buildSectionHeader("Mis Accesos", textColor),
                      const SizedBox(height: 12),
                      _buildSettingsContainer(cardColor, [
                        ProfileMenuItem(
                          title: "Cambiar de Negocio / Tienda", 
                          icon: Icons.swap_horiz, 
                          isDark: isDark, 
                          onTap: () => _showWorkspaceSelector(context, auth)
                        ),
                        _buildDivider(isDark),
                        ProfileMenuItem(
                          title: "Ingresar Código de Invitación", 
                          icon: Icons.vpn_key_outlined, 
                          isDark: isDark, 
                          onTap: () => _showJoinBusinessModal(context, auth, isDark)
                        ),
                        
                        if (!auth.ownsBusiness) ...[
                           _buildDivider(isDark),
                           ProfileMenuItem(
                             title: "Crear Nuevo Negocio", 
                             icon: Icons.add_business_rounded, 
                             isDark: isDark, 
                             onTap: () => _confirmAndCreateBusiness(context)
                           ),
                        ]
                      ]),
                      const SizedBox(height: 35),

                      if (auth.hasActiveContext) ...[
                         _buildSectionHeader(
                           auth.isCommunityClient ? "Tienda Seleccionada" : "Administración del Negocio", 
                           textColor, 
                           actionLabel: auth.isOwner ? "Editar Datos" : null, 
                           onAction: auth.isOwner ? () => _showEditBusiness(context) : null
                         ),
                         const SizedBox(height: 12),
                         BusinessInfoCard(business: auth.currentBusiness, isCommunityClient: auth.isCommunityClient), 
                         const SizedBox(height: 12),
                         
                         if (auth.isOwner || auth.isWorker)
                           _buildSettingsContainer(cardColor, [
                             ProfileMenuItem(
                                 title: "Mi Equipo / Accesos", 
                                 icon: Icons.groups_outlined, 
                                 isDark: isDark, 
                                 onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamManagementScreen()));
                                 }
                              ),
                           ]),
                         const SizedBox(height: 35),
                      ],

                      _buildSectionHeader("Configuración General", textColor),
                      const SizedBox(height: 12),
                      _buildSettingsContainer(cardColor, [
                        ProfileMenuItem(title: "Editar Datos Personales", icon: Icons.person_outline, isDark: isDark, onTap: () => _showEditProfile(context)),
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
                        if (!auth.isCommunityClient) ...[
                           _buildDivider(isDark),
                           ProfileMenuItem(title: "Impresora Térmica", icon: Icons.print_outlined, isDark: isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterConfigScreen())), trailing: const Icon(Icons.bluetooth, size: 22, color: Colors.blue)),
                        ]
                      ]),

                      const SizedBox(height: 35),
                      _buildSectionHeader("Seguridad de la Cuenta", textColor),
                      const SizedBox(height: 12),
                      _buildSettingsContainer(cardColor, [
                        ProfileMenuItem(title: "Cambiar Contraseña", icon: Icons.lock_outline, isDark: isDark, onTap: () => _showChangePassword(context)),
                        _buildDivider(isDark),
                        ProfileMenuItem(title: "Cerrar Sesión", icon: Icons.logout, isDark: isDark, isDestructive: true, onTap: () => _confirmLogout(context, auth, isDark)),
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
    String displayRole = "MODO INVITADO";
    if (auth.hasActiveContext) {
        displayRole = auth.activeRole.toUpperCase();
        if (displayRole == 'DUENO') displayRole = 'DUEÑO DE NEGOCIO';
        if (displayRole == 'CLIENTE_COMUNIDAD') displayRole = 'CLIENTE VIP';
    }
        
    final String? validLogoUrl = _getValidImageUrl(auth.currentBusiness?.logoUrl);

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
                          backgroundImage: validLogoUrl != null ? NetworkImage(validLogoUrl) : null,
                          child: validLogoUrl == null ? const Icon(Icons.store, size: 55, color: Color(0xFF1565C0)) : null,
                        ),
                      ),
                      if (auth.hasActiveContext && auth.isOwner)
                        InkWell(
                          onTap: () => _showPhotoOptions(context, auth, validLogoUrl),
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
                  
                  // 🔥 Agregamos el nombre del negocio activo para el contexto
                  if (auth.hasActiveContext)
                    Text(auth.businessName, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.w500)),
                  
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.3))),
                    child: Text(displayRole, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                  const SizedBox(height: 8),

                  // 🔥 Funcionalidad de Copiar Portapapeles para el Radar ID
                  InkWell(
                    onTap: () {
                      final radarId = auth.user?.codigoUnicoUsuario;
                      if (radarId != null) {
                        Clipboard.setData(ClipboardData(text: radarId));
                        CustomSnackBar.show(context, message: "Radar ID copiado al portapapeles", isError: false);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Radar ID: ${auth.user?.codigoUnicoUsuario ?? '---'}", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                          const SizedBox(width: 6),
                          Icon(Icons.copy, size: 14, color: Colors.white.withOpacity(0.8)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhotoOptions(BuildContext context, AuthProvider auth, String? validLogoUrl) {
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
              
              if (validLogoUrl != null)
                _buildModalOption(icon: Icons.fullscreen, text: "Ver foto en pantalla completa", color: Colors.blue, isDark: isDark, onTap: () {
                  Navigator.pop(ctx);
                  _openFullScreenImage(validLogoUrl);
                }),
              
              _buildModalOption(icon: Icons.image_search, text: "Elegir foto de la galería", color: Colors.green, isDark: isDark, onTap: () {
                Navigator.pop(ctx);
                _pickImage(context, auth);
              }),
              
              if (validLogoUrl != null)
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

  void _openFullScreenImage(String imageUrl) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white), elevation: 0),
      extendBodyBehindAppBar: true,
      body: Center(
        child: PhotoView(
          imageProvider: NetworkImage(imageUrl),
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
            CustomSnackBar.show(context, message: "Foto subida exitosamente", isError: false);
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
            const Text("Cerrar Sesión", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text("¿Estás seguro de que deseas salir de tu cuenta?", style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.grey[700])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); 
              await auth.logout();
              if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
            child: const Text("Sí, salir", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
    );
  }
}