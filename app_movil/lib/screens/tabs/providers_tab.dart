import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart'; // 🔥 FASE 4
import '../../models/provider_model.dart';
import '../../widgets/master_item_tile.dart';
import '../../widgets/master_detail_modal.dart';
import '../../widgets/sortable_toolbar.dart';
import '../../widgets/custom_snackbar.dart';

class ProvidersTab extends StatefulWidget {
  const ProvidersTab({super.key});

  @override
  State<ProvidersTab> createState() => _ProvidersTabState();
}

class _ProvidersTabState extends State<ProvidersTab> {
  
  // 🔥 NUEVO: Explicación de Exploración
  void _showExplorationModal(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.explore, color: Colors.orange[400]),
            const SizedBox(width: 10),
            const Text("Modo Exploración", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "Para crear o editar proveedores reales en tu base de datos, necesitas registrar tu propio negocio.\n\n"
          "Ve a tu Perfil cuando estés listo.",
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Entendido", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      )
    );
  }

  void _showFormDialog(BuildContext context, {ProviderModel? providerItem, required bool isDark, required bool isGuest}) {
    if (isGuest) {
      _showExplorationModal(context, isDark);
      return;
    }

    final nameCtrl = TextEditingController(text: providerItem?.nombreEmpresa ?? "");
    final rucCtrl = TextEditingController(text: providerItem?.ruc ?? "");
    final contactCtrl = TextEditingController(text: providerItem?.contactoNombre ?? "");
    final phoneCtrl = TextEditingController(text: providerItem?.telefono ?? "");
    final emailCtrl = TextEditingController(text: providerItem?.correo ?? "");
    
    final isEditing = providerItem != null;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          isEditing ? "Editar Proveedor" : "Nuevo Proveedor",
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Registra datos de contacto y facturación.",
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey),
                ),
                const SizedBox(height: 20),
                
                // SECCIÓN 1: EMPRESA
                _buildTextField(nameCtrl, "Empresa / Razón Social *", Icons.business, isDark, textCapitalization: TextCapitalization.words),
                const SizedBox(height: 12),
                _buildTextField(rucCtrl, "RUC (Opcional)", Icons.numbers, isDark, type: TextInputType.number),
                
                Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200])),
                
                // SECCIÓN 2: CONTACTO
                Text("INFORMACIÓN DE CONTACTO", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[500] : Colors.grey, letterSpacing: 1.0)),
                const SizedBox(height: 12),
                
                _buildTextField(contactCtrl, "Nombre Contacto", Icons.person_outline, isDark, textCapitalization: TextCapitalization.words),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildTextField(phoneCtrl, "Teléfono", Icons.phone, isDark, type: TextInputType.phone)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField(emailCtrl, "Correo", Icons.email_outlined, isDark, type: TextInputType.emailAddress)),
                  ],
                )
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.purple[300] : Colors.purple[700],
              foregroundColor: isDark ? Colors.black87 : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) {
                CustomSnackBar.show(context, message: "El nombre de la empresa es obligatorio", isError: true);
                return;
              }

              final provider = Provider.of<InventoryProvider>(context, listen: false);
              bool success = false;

              if (isEditing) {
                success = await provider.updateProvider(
                  providerItem.id, 
                  nameCtrl.text.trim(),
                  ruc: rucCtrl.text.trim(),
                  contacto: contactCtrl.text.trim(),
                  telefono: phoneCtrl.text.trim(),
                  correo: emailCtrl.text.trim()
                );
              } else {
                final id = await provider.createProvider(
                  nameCtrl.text.trim(),
                  ruc: rucCtrl.text.trim(),
                  contacto: contactCtrl.text.trim(),
                  telefono: phoneCtrl.text.trim(),
                  correo: emailCtrl.text.trim()
                );
                success = id != null;
              }

              if (mounted) {
                Navigator.pop(ctx);
                if (success) {
                  CustomSnackBar.show(
                    context, 
                    message: isEditing ? "Proveedor actualizado correctamente" : "Proveedor registrado con éxito"
                  );
                } else {
                  CustomSnackBar.show(
                    context, 
                    message: "Error al procesar el proveedor", 
                    isError: true
                  );
                }
              }
            },
            child: Text(isEditing ? "Guardar" : "Crear", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, bool isDark, {TextInputType type = TextInputType.text, TextCapitalization textCapitalization = TextCapitalization.none}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      textCapitalization: textCapitalization,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[700]),
        filled: true,
        fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.purple.withOpacity(0.5) : Colors.purple)),
        prefixIcon: Icon(icon, color: isDark ? Colors.blueGrey[300] : Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  void _delete(BuildContext context, int id, bool isDark, bool isGuest) async {
    if (isGuest) {
      _showExplorationModal(context, isDark);
      return;
    }

    final provider = Provider.of<InventoryProvider>(context, listen: false);
    bool success = await provider.deleteProvider(id);
    
    if (mounted) {
      if (success) {
        CustomSnackBar.show(context, message: "Proveedor eliminado correctamente", isError: false);
      } else {
        CustomSnackBar.show(
          context, 
          message: provider.lastActionError ?? "No se pudo eliminar el proveedor", 
          isError: true
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isGuest = !auth.hasActiveContext;

    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final providers = provider.providers;

        return Scaffold(
          backgroundColor: Colors.transparent, 
          
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showFormDialog(context, isDark: isDark, isGuest: isGuest),
            label: Text("Nuevo Proveedor", style: TextStyle(color: isDark ? Colors.black87 : Colors.white, fontWeight: FontWeight.bold)),
            icon: Icon(Icons.add, color: isDark ? Colors.black87 : Colors.white),
            backgroundColor: isDark ? Colors.purple[300] : Colors.purple[700],
          ),
          
          body: Column(
            children: [
              SortableToolbar(
                title: "${providers.length} Proveedores",
                currentSort: provider.provSort,
                isAscending: provider.provAsc,
                onSortChanged: (type) => provider.sortProviders(type),
              ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => await provider.loadMasterData(),
                  color: Colors.purple[700],
                  child: providers.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.7,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_shipping_outlined, size: 80, color: isDark ? Colors.white10 : Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                "No hay proveedores registrados.",
                                style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => _showFormDialog(context, isDark: isDark, isGuest: isGuest),
                                child: Text("Registrar Proveedor", style: TextStyle(fontSize: 16, color: isDark ? Colors.purple[300] : Colors.purple)),
                              )
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: providers.length,
                        itemBuilder: (ctx, i) {
                          final p = providers[i];
                          return MasterItemTile(
                            title: p.nombreEmpresa,
                            subtitle: (p.ruc != null && p.ruc!.isNotEmpty) ? "RUC: ${p.ruc}" : "Sin RUC",
                            icon: Icons.local_shipping,
                            color: isDark ? Colors.purple[300]! : Colors.purple,
                            isActive: p.activo,
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => MasterDetailModal(
                                  title: p.nombreEmpresa,
                                  subtitle: "ID Sistema: ${p.id}",
                                  icon: Icons.local_shipping,
                                  color: isDark ? Colors.purple[300]! : Colors.purple,
                                  isActive: p.activo,
                                  usageCount: p.productsCount, 
                                  dataRows: [
                                    {
                                      "label": "RUC", 
                                      "value": (p.ruc != null && p.ruc!.isNotEmpty) ? p.ruc! : "No asignado"
                                    },
                                    {
                                      "label": "Contacto", 
                                      "value": (p.contactoNombre != null && p.contactoNombre!.isNotEmpty) ? p.contactoNombre! : "No asignado"
                                    },
                                    {
                                      "label": "Teléfono", 
                                      "value": (p.telefono != null && p.telefono!.isNotEmpty) ? p.telefono! : "No asignado"
                                    },
                                    {
                                      "label": "Correo", 
                                      "value": (p.correo != null && p.correo!.isNotEmpty) ? p.correo! : "No asignado"
                                    },
                                    {
                                      "label": "Uso", 
                                      "value": "${p.productsCount} items vinculados"
                                    },
                                  ],
                                  onEdit: () => _showFormDialog(context, providerItem: p, isDark: isDark, isGuest: isGuest),
                                  onDelete: () => _delete(context, p.id, isDark, isGuest),
                                  onToggleActive: (val) async {
                                    if (isGuest) {
                                      _showExplorationModal(context, isDark);
                                      return;
                                    }
                                    await provider.updateProvider(p.id, p.nombreEmpresa, activo: val);
                                    if(mounted) {
                                      CustomSnackBar.show(
                                        context, 
                                        message: val ? "Proveedor activado" : "Proveedor suspendido",
                                        backgroundColor: val ? Colors.green[800]! : Colors.orange[800]!
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}