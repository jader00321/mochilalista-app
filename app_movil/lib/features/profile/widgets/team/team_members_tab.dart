import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/features/profile/providers/team_provider.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/profile/models/team_management_models.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class TeamMembersTab extends StatelessWidget {
  const TeamMembersTab({super.key});

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
                            backgroundColor: isSuspended ? Colors.red.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.2),
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
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(
            context,
            minPadding: InteractiveSheetWrapper.kMinDefensiveBottomClearance,
          );
          return Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, effectiveBottom),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14141C) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
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
                    initialValue: selectedRole,
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
                  ),
                  const SizedBox(height: InteractiveSheetWrapper.kModalScrollBottomClearance),
                ],
              ),
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
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(
            context,
            minPadding: InteractiveSheetWrapper.kMinDefensiveBottomClearance,
          );
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: EdgeInsets.fromLTRB(24, 24, 24, effectiveBottom),
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
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    child: Column(
                      children: [
                        // Controles Maestros
                        DropdownButtonFormField<String>(
                          initialValue: currentStatus,
                          decoration: InputDecoration(labelText: "Estado de Acceso", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          items: const [
                            DropdownMenuItem(
                              value: "activo",
                              child: Row(
                                children: [
                                  Icon(Icons.circle, color: Colors.green, size: 12),
                                  SizedBox(width: 8),
                                  Text("Activo (Permitido)"),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: "suspendido",
                              child: Row(
                                children: [
                                  Icon(Icons.circle, color: Colors.red, size: 12),
                                  SizedBox(width: 8),
                                  Text("Suspendido (Expulsado)"),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => currentStatus = v!),
                        ),
                        const SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          initialValue: currentRole,
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
                          ),
                        const SizedBox(height: InteractiveSheetWrapper.kModalScrollBottomClearance),
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
      activeThumbColor: Colors.blue,
      onChanged: (val) {
        setState(() {
          perms[key] = val;
        });
      },
    );
  }
}
