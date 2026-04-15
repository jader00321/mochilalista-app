import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../providers/auth_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../providers/team_provider.dart';
import '../../../../widgets/custom_snackbar.dart';
import '../../../../models/team_management_models.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  @override
  void initState() {
    super.initState();
    // Cargamos los datos al abrir la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.activeBusinessId != null) {
        final teamProv = Provider.of<TeamProvider>(context, listen: false);
        teamProv.fetchTeam(auth.activeBusinessId!);
        teamProv.fetchAccessCodes(auth.activeBusinessId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = Provider.of<ThemeProvider>(context);
    final isDark = themeProv.isDarkMode;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF14141C) : Colors.blue[800],
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text("Mi Equipo y Accesos", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.orangeAccent,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.people), text: "Miembros"),
              Tab(icon: Icon(Icons.vpn_key), text: "Códigos de Invitación"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TeamMembersTab(),
            _AccessCodesTab(),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 1. PESTAÑA DE MIEMBROS (EL EQUIPO)
// =========================================================================
class _TeamMembersTab extends StatelessWidget {
  const _TeamMembersTab();

  @override
  Widget build(BuildContext context) {
    final teamProv = Provider.of<TeamProvider>(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    if (teamProv.isLoading && teamProv.teamMembers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.radar, color: Colors.white),
              label: const Text("Añadir Directo por Radar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showRadarModal(context),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              await teamProv.fetchTeam(auth.activeBusinessId!);
            },
            child: teamProv.teamMembers.isEmpty
                ? ListView(children: const [SizedBox(height: 100), Center(child: Text("No hay miembros en el equipo."))])
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: teamProv.teamMembers.length,
                    itemBuilder: (context, index) {
                      final member = teamProv.teamMembers[index];
                      final isSuspended = member.estado == 'suspendido';

                      return Card(
                        color: isDark ? const Color(0xFF23232F) : Colors.white,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: isSuspended ? Colors.red.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                            child: Icon(Icons.person, color: isSuspended ? Colors.red : Colors.blue),
                          ),
                          title: Text(
                            member.nombre,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: isSuspended ? TextDecoration.lineThrough : null,
                              color: isSuspended ? Colors.grey : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          subtitle: Text(
                            "Rol: ${member.rol.replaceAll("_", " ").toUpperCase()}",
                            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                          ),
                          trailing: isSuspended
                              ? const Icon(Icons.block, color: Colors.red)
                              : const Icon(Icons.edit_document, color: Colors.blue),
                          onTap: () => _showEditPermissionsModal(context, member),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // --- MODAL: RADAR ---
  void _showRadarModal(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final teamProv = Provider.of<TeamProvider>(context, listen: false);
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    
    final codeCtrl = TextEditingController();
    String selectedRole = "trabajador";

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
                Text("El Radar (Añadir Directo)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 10),
                Text("Ingresa el 'Radar ID' del usuario para añadirlo sin enviar código.", style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 20),
                
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, letterSpacing: 2),
                  decoration: InputDecoration(
                    labelText: "ID de Radar (Ej: ML-9A2KF8)",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.radar),
                  ),
                ),
                const SizedBox(height: 20),
                
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: InputDecoration(
                    labelText: "Rol a otorgar",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: "trabajador", child: Text("Trabajador / Cajero")),
                    DropdownMenuItem(value: "cliente_comunidad", child: Text("Cliente de Comunidad")),
                  ],
                  onChanged: (v) => setState(() => selectedRole = v!),
                ),
                const SizedBox(height: 30),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: teamProv.isLoading ? null : () async {
                      if (codeCtrl.text.trim().isEmpty) return;
                      final ok = await teamProv.addUserDirectly(auth.activeBusinessId!, codeCtrl.text.trim(), selectedRole);
                      if (ok && ctx.mounted) {
                        Navigator.pop(ctx);
                        CustomSnackBar.show(context, message: "Usuario añadido con éxito.", isError: false);
                      } else if (ctx.mounted) {
                        CustomSnackBar.show(context, message: teamProv.errorMessage, isError: true);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: teamProv.isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("Añadir al Equipo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          );
        }
      ),
    );
  }

  // --- MODAL: MATRIZ DE PERMISOS ---
  void _showEditPermissionsModal(BuildContext context, TeamMemberModel member) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final teamProv = Provider.of<TeamProvider>(context, listen: false);
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    if (member.rol == 'dueno') {
      CustomSnackBar.show(context, message: "No puedes editar los permisos del Dueño.", isError: true);
      return;
    }

    String currentRole = member.rol;
    String currentStatus = member.estado;
    Map<String, dynamic> currentPerms = Map.from(member.permisos);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14141C) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Gestión de Usuario", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                Text(member.nombre, style: TextStyle(fontSize: 16, color: Colors.blue[600], fontWeight: FontWeight.bold)),
                const Divider(height: 30),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Controles Maestros
                        DropdownButtonFormField<String>(
                          value: currentStatus,
                          decoration: InputDecoration(labelText: "Estado de Acceso", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          items: const [
                            DropdownMenuItem(value: "activo", child: Text("🟢 Activo (Permitido)")),
                            DropdownMenuItem(value: "suspendido", child: Text("🔴 Suspendido (Expulsado)")),
                          ],
                          onChanged: (v) => setState(() => currentStatus = v!),
                        ),
                        const SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          value: currentRole,
                          decoration: InputDecoration(labelText: "Rol en el Negocio", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          items: const [
                            DropdownMenuItem(value: "trabajador", child: Text("Trabajador / Cajero")),
                            DropdownMenuItem(value: "cliente_comunidad", child: Text("Cliente de Comunidad")),
                          ],
                          onChanged: (v) => setState(() => currentRole = v!),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Matriz de Permisos (Solo para Trabajadores)
                        if (currentRole == 'trabajador')
                          ExpansionTile(
                            initiallyExpanded: true,
                            title: const Text("Matriz de Permisos", style: TextStyle(fontWeight: FontWeight.bold)),
                            children: [
                              _buildPermSwitch("Ver Costos de Compra", "can_view_costs", currentPerms, setState),
                              _buildPermSwitch("Editar Inventario", "can_edit_inventory", currentPerms, setState),
                              _buildPermSwitch("Aplicar Descuentos", "can_apply_discounts", currentPerms, setState),
                              _buildPermSwitch("Dar Crédito", "can_give_credit", currentPerms, setState),
                              _buildPermSwitch("Administrar Clientes", "can_manage_clients", currentPerms, setState),
                              _buildPermSwitch("Anular Ventas", "can_void_sales", currentPerms, setState),
                            ],
                          )
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: teamProv.isLoading ? null : () async {
                      final ok = await teamProv.updateMemberPermissions(auth.activeBusinessId!, member.usuarioId, currentPerms, currentStatus, currentRole);
                      if (ok && ctx.mounted) {
                        Navigator.pop(ctx);
                        CustomSnackBar.show(context, message: "Actualizado correctamente", isError: false);
                      } else if (ctx.mounted) {
                        CustomSnackBar.show(context, message: teamProv.errorMessage, isError: true);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: currentStatus == 'suspendido' ? Colors.red : Colors.blue[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: teamProv.isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("Guardar Cambios", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                )
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildPermSwitch(String title, String key, Map<String, dynamic> perms, StateSetter setState) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      value: perms[key] == true,
      activeColor: Colors.blue,
      onChanged: (val) {
        setState(() {
          perms[key] = val;
        });
      },
    );
  }
}

// =========================================================================
// 2. PESTAÑA DE CÓDIGOS DE INVITACIÓN
// =========================================================================
class _AccessCodesTab extends StatelessWidget {
  const _AccessCodesTab();

  @override
  Widget build(BuildContext context) {
    final teamProv = Provider.of<TeamProvider>(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.qr_code, color: Colors.white),
              label: const Text("Generar Código de Invitación", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showGenerateCodeModal(context),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              await teamProv.fetchAccessCodes(auth.activeBusinessId!);
            },
            child: teamProv.accessCodes.isEmpty
                ? ListView(children: const [SizedBox(height: 100), Center(child: Text("No hay códigos activos."))])
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: teamProv.accessCodes.length,
                    itemBuilder: (context, index) {
                      final code = teamProv.accessCodes[index];
                      final isExhausted = code.isExhausted;

                      return Card(
                        color: isDark ? const Color(0xFF23232F) : Colors.white,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            code.codigo,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isExhausted ? Colors.grey : Colors.green, letterSpacing: 1.5),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 5),
                              Text("Rol: ${code.rolAOtorgar.replaceAll("_", " ").toUpperCase()}", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                              Text("Usos: ${code.usosActuales} / ${code.usosMaximos}", style: TextStyle(color: isExhausted ? Colors.red : Colors.grey)),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              final ok = await teamProv.deleteAccessCode(auth.activeBusinessId!, code.id);
                              if (ok && context.mounted) {
                                CustomSnackBar.show(context, message: "Código eliminado", isError: false);
                              }
                            },
                          ),
                          onTap: () {
                             // Copiar al portapapeles
                             Clipboard.setData(ClipboardData(text: code.codigo));
                             CustomSnackBar.show(context, message: "Código copiado al portapapeles", isError: false);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // --- MODAL: GENERADOR DE CÓDIGOS ---
  void _showGenerateCodeModal(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final teamProv = Provider.of<TeamProvider>(context, listen: false);
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    
    String selectedRole = "trabajador";
    int maxUses = 1;

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
                Text("Generador de Códigos", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 20),
                
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: InputDecoration(labelText: "Rol a otorgar", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  items: const [
                    DropdownMenuItem(value: "trabajador", child: Text("Trabajador / Cajero")),
                    DropdownMenuItem(value: "cliente_comunidad", child: Text("Cliente de Comunidad (VIP)")),
                  ],
                  onChanged: (v) => setState(() => selectedRole = v!),
                ),
                const SizedBox(height: 20),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Usos permitidos:", style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                    Row(
                      children: [
                        IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => setState(() => maxUses = maxUses > 1 ? maxUses - 1 : 1)),
                        Text(maxUses == 1000 ? "Infinito" : maxUses.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => maxUses = maxUses == 10 ? 1000 : (maxUses == 1000 ? 1000 : maxUses + 1))),
                      ],
                    )
                  ],
                ),
                Text("Nota: Sube a 'Infinito' si es un código general para tus clientes.", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 30),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: teamProv.isLoading ? null : () async {
                      final newCode = await teamProv.generateAccessCode(auth.activeBusinessId!, selectedRole, maxUses, null);
                      if (newCode != null && ctx.mounted) {
                        Navigator.pop(ctx);
                        _showCodeSuccessDialog(context, newCode.codigo);
                      } else if (ctx.mounted) {
                        CustomSnackBar.show(context, message: teamProv.errorMessage, isError: true);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: teamProv.isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("Generar Código", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          );
        }
      ),
    );
  }

  void _showCodeSuccessDialog(BuildContext context, String codigo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¡Código Generado!", textAlign: TextAlign.center, style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Comparte este código con la persona que deseas invitar:"),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green, width: 2)),
              child: Text(codigo, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cerrar")),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, color: Colors.white, size: 18),
            label: const Text("Copiar", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: codigo));
              Navigator.pop(ctx);
              CustomSnackBar.show(context, message: "Código copiado al portapapeles", isError: false);
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.share, color: Colors.white, size: 18),
            label: const Text("WhatsApp", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600]),
            onPressed: () async {
              Navigator.pop(ctx);
              final url = Uri.parse("https://wa.me/?text=¡Únete a mi equipo en MochilaLista! Tu código de acceso es: *$codigo*");
              try {
                 await launchUrl(url, mode: LaunchMode.externalApplication);
              } catch (_) {
                 CustomSnackBar.show(context, message: "No se pudo abrir WhatsApp", isError: true);
              }
            },
          )
        ],
      ),
    );
  }
}