import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart'; // 🔥 FASE 4
import '../../models/category_model.dart';
import '../../widgets/master_item_tile.dart';
import '../../widgets/master_detail_modal.dart';
import '../../widgets/sortable_toolbar.dart';
import '../../widgets/custom_snackbar.dart';

class CategoriesTab extends StatefulWidget {
  const CategoriesTab({super.key});

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  
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
          "Para crear, editar o eliminar categorías reales en tu base de datos, necesitas registrar tu propio negocio.\n\n"
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

  // --- FORMULARIO CREAR/EDITAR ---
  void _showFormDialog(BuildContext context, {Category? category, required bool isDark, required bool isGuest}) {
    if (isGuest) {
      _showExplorationModal(context, isDark);
      return;
    }

    final nameCtrl = TextEditingController(text: category?.nombre ?? "");
    final descCtrl = TextEditingController(text: category?.descripcion ?? "");
    final isEditing = category != null;

    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          isEditing ? "Editar Categoría" : "Nueva Categoría",
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Agrupa tus productos para organizar mejor tu inventario.",
                style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: textColor, fontSize: 16),
                decoration: InputDecoration(
                  labelText: "Nombre *",
                  labelStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[700]),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.blue.withOpacity(0.5) : Colors.blue)),
                  prefixIcon: Icon(Icons.category_outlined, color: isDark ? Colors.blueGrey[300] : Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                style: TextStyle(color: textColor, fontSize: 16),
                decoration: InputDecoration(
                  labelText: "Descripción (Opcional)",
                  labelStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[700]),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.blue.withOpacity(0.5) : Colors.blue)),
                  prefixIcon: Icon(Icons.description_outlined, color: isDark ? Colors.blueGrey[300] : Colors.grey),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.blue[300] : Colors.blue,
              foregroundColor: isDark ? Colors.black87 : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) {
                CustomSnackBar.show(context, message: "El nombre es obligatorio", isError: true);
                return;
              }
              
              final provider = Provider.of<InventoryProvider>(context, listen: false);
              bool success = false;

              if (isEditing) {
                success = await provider.updateCategory(
                  category.id, 
                  nameCtrl.text.trim(),
                  descripcion: descCtrl.text.trim()
                );
              } else {
                final id = await provider.createCategory(
                  nameCtrl.text.trim(),
                  descripcion: descCtrl.text.trim()
                );
                success = id != null;
              }

              if (mounted) {
                Navigator.pop(ctx); 
                
                if (success) {
                  CustomSnackBar.show(
                    context, 
                    message: isEditing ? "Categoría actualizada correctamente" : "Categoría creada con éxito"
                  );
                } else {
                  CustomSnackBar.show(
                    context, 
                    message: "Error al guardar la categoría", 
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

  void _delete(BuildContext context, int id, bool isDark, bool isGuest) async {
    if (isGuest) {
      _showExplorationModal(context, isDark);
      return;
    }

    final provider = Provider.of<InventoryProvider>(context, listen: false);
    bool success = await provider.deleteCategory(id);
    
    if (mounted) {
      if (success) {
        CustomSnackBar.show(context, message: "Categoría eliminada correctamente", isError: false);
      } else {
        CustomSnackBar.show(
          context, 
          message: provider.lastActionError ?? "No se pudo eliminar la categoría", 
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
        final categories = provider.categories; 

        return Scaffold(
          backgroundColor: Colors.transparent, 
          
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showFormDialog(context, isDark: isDark, isGuest: isGuest),
            label: Text("Nueva Categoría", style: TextStyle(color: isDark ? Colors.black87 : Colors.white, fontWeight: FontWeight.bold)),
            icon: Icon(Icons.add, color: isDark ? Colors.black87 : Colors.white),
            backgroundColor: isDark ? Colors.blue[300] : Colors.blue[800],
          ),
          
          body: Column(
            children: [
              SortableToolbar(
                title: "${categories.length} Categorías",
                currentSort: provider.catSort,
                isAscending: provider.catAsc,
                onSortChanged: (type) => provider.sortCategories(type),
              ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => await provider.loadMasterData(),
                  color: Colors.blue[800],
                  child: categories.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.7,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.category_outlined, size: 80, color: isDark ? Colors.white10 : Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                "No hay categorías aún.",
                                style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => _showFormDialog(context, isDark: isDark, isGuest: isGuest),
                                child: Text("Crear la primera", style: TextStyle(fontSize: 16, color: isDark ? Colors.blue[300] : Colors.blue)),
                              )
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: categories.length,
                        itemBuilder: (ctx, i) {
                          final cat = categories[i];
                          return MasterItemTile(
                            title: cat.nombre,
                            subtitle: (cat.descripcion != null && cat.descripcion!.isNotEmpty)
                                ? cat.descripcion 
                                : "Sin descripción",
                            icon: Icons.category,
                            color: isDark ? Colors.blue[300]! : Colors.blue,
                            isActive: cat.activo,
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => MasterDetailModal(
                                  title: cat.nombre,
                                  subtitle: "ID Sistema: ${cat.id}",
                                  icon: Icons.category,
                                  color: isDark ? Colors.blue[300]! : Colors.blue,
                                  isActive: cat.activo,
                                  usageCount: cat.productsCount, 
                                  dataRows: [
                                    {
                                      "label": "Descripción", 
                                      "value": (cat.descripcion != null && cat.descripcion!.isNotEmpty) ? cat.descripcion! : "Sin descripción"
                                    },
                                    {
                                      "label": "Uso", 
                                      "value": "${cat.productsCount} productos vinculados"
                                    },
                                  ],
                                  onEdit: () => _showFormDialog(context, category: cat, isDark: isDark, isGuest: isGuest),
                                  onDelete: () => _delete(context, cat.id, isDark, isGuest),
                                  onToggleActive: (val) async {
                                    if (isGuest) {
                                      _showExplorationModal(context, isDark);
                                      return;
                                    }
                                    await provider.updateCategory(cat.id, cat.nombre, activo: val);
                                    if(mounted) {
                                        CustomSnackBar.show(
                                            context, 
                                            message: val ? "Categoría activada" : "Categoría suspendida",
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