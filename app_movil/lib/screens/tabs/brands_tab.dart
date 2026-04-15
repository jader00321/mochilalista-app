import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart'; // 🔥 FASE 4
import '../../models/brand_model.dart';
import '../../widgets/master_item_tile.dart';
import '../../widgets/master_detail_modal.dart';
import '../../widgets/sortable_toolbar.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/image_picker_field.dart';

class BrandsTab extends StatefulWidget {
  const BrandsTab({super.key});

  @override
  State<BrandsTab> createState() => _BrandsTabState();
}

class _BrandsTabState extends State<BrandsTab> {
  
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
          "Para crear o editar marcas reales en tu base de datos, necesitas registrar tu propio negocio.\n\n"
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

  void _showFormDialog(BuildContext context, {Brand? brand, required bool isDark, required bool isGuest}) {
    if (isGuest) {
      _showExplorationModal(context, isDark);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (ctx) => _BrandFormDialog(brand: brand, isDark: isDark),
    );
  }

  void _delete(BuildContext context, int id, bool isDark, bool isGuest) async {
    if (isGuest) {
      _showExplorationModal(context, isDark);
      return;
    }

    final provider = Provider.of<InventoryProvider>(context, listen: false);
    bool success = await provider.deleteBrand(id);
    
    if (mounted) {
      if (success) {
        CustomSnackBar.show(context, message: "Marca eliminada", isError: false);
      } else {
        CustomSnackBar.show(
          context, 
          message: provider.lastActionError ?? "No se pudo eliminar", 
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
        final brands = provider.brands;

        return Scaffold(
          backgroundColor: Colors.transparent, 
          
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showFormDialog(context, isDark: isDark, isGuest: isGuest),
            label: Text("Nueva Marca", style: TextStyle(color: isDark ? Colors.black87 : Colors.white, fontWeight: FontWeight.bold)),
            icon: Icon(Icons.add, color: isDark ? Colors.black87 : Colors.white),
            backgroundColor: isDark ? Colors.orange[300] : Colors.orange[800],
          ),
          
          body: Column(
            children: [
              SortableToolbar(
                title: "${brands.length} Marcas",
                currentSort: provider.brandSort,
                isAscending: provider.brandAsc,
                onSortChanged: (type) => provider.sortBrands(type),
              ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => await provider.loadMasterData(),
                  color: Colors.orange[800],
                  child: brands.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.7,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.branding_watermark_outlined, size: 80, color: isDark ? Colors.white10 : Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text("No hay marcas registradas.", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => _showFormDialog(context, isDark: isDark, isGuest: isGuest),
                                child: Text("Registrar Marca", style: TextStyle(fontSize: 16, color: isDark ? Colors.orange[300] : Colors.orange[800])),
                              )
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: brands.length,
                        itemBuilder: (ctx, i) {
                          final brand = brands[i];
                          return MasterItemTile(
                            title: brand.nombre,
                            subtitle: "${brand.productsCount} productos asociados",
                            icon: Icons.branding_watermark,
                            color: isDark ? Colors.orange[300]! : Colors.orange,
                            isActive: brand.activo,
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => MasterDetailModal(
                                  title: brand.nombre,
                                  subtitle: "ID Sistema: ${brand.id}",
                                  icon: Icons.branding_watermark,
                                  color: isDark ? Colors.orange[300]! : Colors.orange,
                                  isActive: brand.activo,
                                  usageCount: brand.productsCount, 
                                  dataRows: [
                                    {
                                      "label": "Logo URL", 
                                      "value": (brand.urlImagen != null && brand.urlImagen!.isNotEmpty) ? "Configurado" : "Sin logo"
                                    },
                                    {
                                      "label": "Uso", 
                                      "value": "${brand.productsCount} productos vinculados"
                                    },
                                  ],
                                  onEdit: () {
                                    _showFormDialog(context, brand: brand, isDark: isDark, isGuest: isGuest);
                                  },
                                  onDelete: () {
                                    _delete(context, brand.id, isDark, isGuest);
                                  },
                                  onToggleActive: (val) async {
                                    if (isGuest) {
                                      _showExplorationModal(context, isDark);
                                      return;
                                    }
                                    await provider.updateBrand(brand.id, brand.nombre, activo: val);
                                    if(mounted) CustomSnackBar.show(context, message: val ? "Activada" : "Suspendida", backgroundColor: val ? Colors.green[800]! : Colors.orange[800]!);
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

// Formulario de Marca se mantiene igual internamente
class _BrandFormDialog extends StatefulWidget {
  final Brand? brand;
  final bool isDark;

  const _BrandFormDialog({required this.brand, required this.isDark});

  @override
  State<_BrandFormDialog> createState() => _BrandFormDialogState();
}

class _BrandFormDialogState extends State<_BrandFormDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _imgCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.brand?.nombre ?? "");
    _imgCtrl = TextEditingController(text: widget.brand?.urlImagen ?? "");
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _imgCtrl.dispose();
    super.dispose();
  }

  void _saveData() async {
    if (_nameCtrl.text.trim().isEmpty) {
      CustomSnackBar.show(context, message: "El nombre es obligatorio", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final isEditing = widget.brand != null;
    bool success = false;

    if (isEditing) {
      success = await provider.updateBrand(
        widget.brand!.id, 
        _nameCtrl.text.trim(), 
        urlImagen: _imgCtrl.text.trim()
      );
    } else {
      final id = await provider.createBrand(
        _nameCtrl.text.trim(), 
        urlImagen: _imgCtrl.text.trim()
      );
      success = id != null;
    }

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context); 
      
      if (success) {
        CustomSnackBar.show(context, message: isEditing ? "Marca actualizada" : "Marca creada");
      } else {
        CustomSnackBar.show(context, message: "Error al procesar la marca", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final isEditing = widget.brand != null;

    return AlertDialog(
      backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        isEditing ? "Editar Marca" : "Nueva Marca",
        style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Registra las marcas comerciales para estandarizar tus productos.",
              style: TextStyle(fontSize: 14, color: widget.isDark ? Colors.grey[400] : Colors.grey),
            ),
            const SizedBox(height: 20),
            
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: textColor, fontSize: 16),
              decoration: InputDecoration(
                labelText: "Nombre Marca *",
                labelStyle: TextStyle(color: widget.isDark ? Colors.grey[500] : Colors.grey[700]),
                filled: true,
                fillColor: widget.isDark ? const Color(0xFF14141C) : Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.isDark ? Colors.white10 : Colors.transparent)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.isDark ? Colors.orange.withOpacity(0.5) : Colors.orange)),
                prefixIcon: Icon(Icons.branding_watermark, color: widget.isDark ? Colors.blueGrey[300] : Colors.grey),
              ),
            ),
            const SizedBox(height: 20),
            
            ImagePickerField(
              controller: _imgCtrl,
              label: "Logo de la Marca",
              isDark: widget.isDark,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text("Cancelar", style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey, fontSize: 16)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isDark ? Colors.orange[300] : Colors.orange[800],
            foregroundColor: widget.isDark ? Colors.black87 : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isLoading ? null : _saveData, 
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(isEditing ? "Guardar" : "Crear", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        )
      ],
    );
  }
}