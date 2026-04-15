import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/inventory_provider.dart';
import '../../../models/product_model.dart';
import '../../../models/provider_model.dart';
import '../../../models/category_model.dart'; 
import '../../../models/brand_model.dart';

import '../../../widgets/custom_text_field.dart';
import '../../../widgets/safe_dropdown.dart';
import '../../../widgets/product_optional_info.dart';
import '../../../widgets/product_presentation_card.dart';

class ProductEditScreen extends StatefulWidget {
  final Product productToEdit;
  final int? initialPresentationId;

  const ProductEditScreen({
    super.key, 
    required this.productToEdit, 
    this.initialPresentationId
  });

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _imgUrlCtrl;
  late TextEditingController _parentBarcodeCtrl;
  
  int? _selectedCategoryId;
  int? _selectedBrandId;

  final List<Map<String, dynamic>> _presentationControllers = [];
  final List<int> _idsToDelete = [];
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Provider.of<InventoryProvider>(context, listen: false).loadMasterData(showAll: true);
      _loadExistingData();
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _loadExistingData() {
    final p = widget.productToEdit;
    final invProv = Provider.of<InventoryProvider>(context, listen: false);

    _nameCtrl = TextEditingController(text: p.nombre);
    _descCtrl = TextEditingController(text: p.descripcion ?? "");
    _imgUrlCtrl = TextEditingController(text: p.imagenUrl ?? "");
    _parentBarcodeCtrl = TextEditingController(text: p.codigoBarras ?? "");
    
    _selectedCategoryId = invProv.categories.any((c) => c.id == p.categoriaId) ? p.categoriaId : null;
    _selectedBrandId = p.marcaId != null && invProv.brands.any((b) => b.id == p.marcaId) ? p.marcaId : null;

    List<ProductPresentation> sortedList = List.from(p.presentaciones);
    if (widget.initialPresentationId != null) {
      int idx = sortedList.indexWhere((pres) => pres.id == widget.initialPresentationId);
      if (idx != -1) {
        final selected = sortedList.removeAt(idx);
        sortedList.insert(0, selected);
      }
    }

    for (var pres in sortedList) {
      int? safeProvId = pres.proveedorId;
      if (safeProvId != null && !invProv.providers.any((pr) => pr.id == safeProvId)) {
          safeProvId = null;
      }

      // 🔥 CARGA DE LA MATEMÁTICA SEPARADA (Igual a Creación)
      _presentationControllers.add({
        'id': pres.id.toString(), // Convertimos el ID a String para la lógica de residuos
        'db_id': pres.id, // Guardamos el ID real de la BD
        'childId': null,
        'leftoverCreated': false,

        'specific': TextEditingController(text: pres.nombreEspecifico ?? ""),
        'unidadVenta': TextEditingController(text: pres.unidadVenta ?? "Unidad"),
        'unidadesVenta': TextEditingController(text: pres.unidadesPorVenta.toString()),
        
        'costoPres': TextEditingController(text: pres.costoUnitarioCalculado?.toStringAsFixed(4).replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "") ?? "0.00"),
        'margen': TextEditingController(text: pres.factorGananciaVenta?.toStringAsFixed(2) ?? "1.35"),
        'precioVenta': TextEditingController(text: pres.precioVentaFinal.toStringAsFixed(2)),
        
        // Stock visual = Stock base / Factor venta
        'stockInicial': TextEditingController(text: (pres.stockActual ~/ pres.unidadesPorVenta).toString()),
        'stockDescuento': TextEditingController(text: "0"),
        'stockFinal': TextEditingController(text: (pres.stockActual ~/ pres.unidadesPorVenta).toString()),

        'umpCompra': TextEditingController(text: pres.umpCompra ?? ""),
        'unidadesLote': TextEditingController(text: pres.unidadesPorLote.toString()),
        'cantCompra': TextEditingController(text: pres.cantidadUmpComprada?.toStringAsFixed(2).replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "") ?? ""),
        'totalPago': TextEditingController(text: pres.totalPagoLote?.toStringAsFixed(2) ?? ""),

        'barcode': TextEditingController(text: pres.codigoBarras ?? ""),
        'desc': TextEditingController(text: pres.descripcion ?? ""),
        'image': TextEditingController(text: pres.imagenUrl ?? ""),
        
        'providerId': safeProvId,
        'isDefault': pres.esDefault,
        'estado': pres.estado,
      });
    }
  }

  void _disposeControllerMap(Map<String, dynamic> map) {
    (map['specific'] as TextEditingController).dispose();
    (map['unidadVenta'] as TextEditingController).dispose();
    (map['unidadesVenta'] as TextEditingController).dispose();
    (map['costoPres'] as TextEditingController).dispose();
    (map['margen'] as TextEditingController).dispose();
    (map['precioVenta'] as TextEditingController).dispose();
    (map['stockInicial'] as TextEditingController).dispose();
    (map['stockDescuento'] as TextEditingController).dispose();
    (map['stockFinal'] as TextEditingController).dispose();
    (map['umpCompra'] as TextEditingController).dispose();
    (map['unidadesLote'] as TextEditingController).dispose();
    (map['cantCompra'] as TextEditingController).dispose();
    (map['totalPago'] as TextEditingController).dispose();
    (map['barcode'] as TextEditingController).dispose();
    (map['desc'] as TextEditingController).dispose();
    (map['image'] as TextEditingController).dispose();
  }

  @override
  void dispose() {
    if (!_isLoading) { 
      _nameCtrl.dispose();
      _descCtrl.dispose();
      _imgUrlCtrl.dispose();
      _parentBarcodeCtrl.dispose();
      for (var map in _presentationControllers) {
        _disposeControllerMap(map); 
      }
    }
    super.dispose();
  }

  // ==========================================================
  // 🔥 LÓGICA DE ESTADOS Y PROVEEDOR GENERAL (REDISEÑO) 🔥
  // ==========================================================
  int get _generalState {
    if (_presentationControllers.isEmpty) return 2;
    bool allPublic = _presentationControllers.every((c) => c['estado'] == 'publico');
    bool allPrivate = _presentationControllers.every((c) => c['estado'] == 'privado');
    if (allPublic) return 2;
    if (allPrivate) return 0;
    return 1; 
  }

  void _setGeneralState(int stateIndex) {
    if (stateIndex == 1) return; 
    String newState = stateIndex == 2 ? 'publico' : 'privado';
    setState(() {
      for (var c in _presentationControllers) { c['estado'] = newState; }
    });
  }

  int? get _generalProviderId {
    if (_presentationControllers.isEmpty) return null;
    int? firstId = _presentationControllers.first['providerId'];
    for (var c in _presentationControllers) {
      if (c['providerId'] != firstId) return -2; 
    }
    return firstId;
  }

  Future<void> _handleGeneralProviderChange(int? newId, bool isDark) async {
    if (newId == -1) {
      newId = await _handleCreateProvider(isDark);
      if (newId == null) return;
    }
    if (_generalProviderId != -2 && _presentationControllers.length <= 1) {
      setState(() { for (var c in _presentationControllers) { c['providerId'] = newId; } });
      return;
    }
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("¿Sobreescribir Proveedores?", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: Text("Esta acción cambiará el proveedor de TODAS las presentaciones, perdiendo cualquier proveedor específico.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Sí, Aplicar"))
        ],
      )
    );
    if (confirm == true) {
      setState(() { for (var c in _presentationControllers) { c['providerId'] = newId; } });
    }
  }

  // ==========================================================
  // CONSTRUCTORES DE PRESENTACIÓN Y RESIDUOS
  // ==========================================================
  void _addPresentation() {
    setState(() {
      _presentationControllers.add({
        'id': UniqueKey().toString(),
        'db_id': null, 
        'childId': null,
        'leftoverCreated': false,

        'ump': TextEditingController(text: "Unidad"),
        'specific': TextEditingController(),
        'unidadVenta': TextEditingController(text: "Unidad"),
        'unidadesVenta': TextEditingController(text: "1"),
        'costoPres': TextEditingController(text: "0.00"),
        'margen': TextEditingController(text: "1.35"),
        'precioVenta': TextEditingController(text: ""),
        'stockInicial': TextEditingController(text: "0"),
        'stockDescuento': TextEditingController(text: "0"),
        'stockFinal': TextEditingController(text: "0"),
        'umpCompra': TextEditingController(text: ""),
        'unidadesLote': TextEditingController(text: ""),
        'cantCompra': TextEditingController(text: ""),
        'totalPago': TextEditingController(text: ""),
        'barcode': TextEditingController(),
        'desc': TextEditingController(),
        'image': TextEditingController(),
        'providerId': _generalProviderId == -2 ? null : _generalProviderId,
        'isDefault': false,
        'estado': _generalState == 0 ? 'privado' : 'publico',
      });
    });
  }

  void _handleCreateLeftover(String parentId, int leftoverUnits, double costoBaseIndividual) {
    int parentIndex = _presentationControllers.indexWhere((c) => c['id'] == parentId);
    if (parentIndex == -1) return;
    
    Map<String, dynamic> sourceMap = _presentationControllers[parentIndex];
    sourceMap['leftoverCreated'] = true; 
    
    double margenOriginal = double.tryParse((sourceMap['margen'] as TextEditingController).text) ?? 1.35;
    double pVentaSobrante = costoBaseIndividual * margenOriginal;

    String newChildId = UniqueKey().toString();
    sourceMap['childId'] = newChildId;

    setState(() {
      _presentationControllers.insert(parentIndex + 1, {
        'id': newChildId,
        'db_id': null, // Es una variante totalmente nueva
        'childId': null,
        'leftoverCreated': false,
        
        'specific': TextEditingController(text: "${(sourceMap['specific'] as TextEditingController).text} (Sueltos)".trim()),
        'unidadVenta': TextEditingController(text: "Unidad"),
        'unidadesVenta': TextEditingController(text: "1"),
        'costoPres': TextEditingController(text: costoBaseIndividual.toStringAsFixed(4).replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '')),
        'margen': TextEditingController(text: margenOriginal.toStringAsFixed(2)),
        'precioVenta': TextEditingController(text: pVentaSobrante.toStringAsFixed(2)),
        'stockInicial': TextEditingController(text: leftoverUnits.toString()),
        'stockDescuento': TextEditingController(text: "0"),
        'stockFinal': TextEditingController(text: leftoverUnits.toString()),
        'umpCompra': TextEditingController(text: ""),
        'unidadesLote': TextEditingController(text: ""),
        'cantCompra': TextEditingController(text: ""),
        'totalPago': TextEditingController(text: ""),
        'barcode': TextEditingController(),
        'desc': TextEditingController(),
        'image': TextEditingController(), 
        'providerId': sourceMap['providerId'], 
        'isDefault': false,
        'estado': sourceMap['estado'],
      });
    });
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Variante sobrante creada debajo"), backgroundColor: Colors.green));
  }

  void _invalidateLeftover(String parentId) {
    int parentIndex = _presentationControllers.indexWhere((c) => c['id'] == parentId);
    if (parentIndex != -1) {
      String? childId = _presentationControllers[parentIndex]['childId'];
      if (childId != null) {
        int childIndex = _presentationControllers.indexWhere((c) => c['id'] == childId);
        if (childIndex != -1) {
          _disposeControllerMap(_presentationControllers[childIndex]);
          _presentationControllers.removeAt(childIndex);
        }
      }
      _presentationControllers[parentIndex]['childId'] = null;
      _presentationControllers[parentIndex]['leftoverCreated'] = false;
      setState((){});
    }
  }

  void _deletePresentation(int index, bool isDark) {
    final item = _presentationControllers[index];
    if (item['isDefault'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No puedes borrar la presentación Principal.", style: TextStyle(fontWeight: FontWeight.bold))));
      return;
    }
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [Icon(Icons.warning_amber_rounded, color: isDark ? Colors.red[300] : Colors.red, size: 28), const SizedBox(width: 8), Text("Eliminar Variante", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))]),
        content: Text("¿Seguro que deseas eliminar esta variante?", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontSize: 15))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.red[800] : Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(ctx);
              if (item['db_id'] != null) _idsToDelete.add(item['db_id']);
              
              // Si era un hijo, liberar al padre
              String idToDelete = item['id'];
              for (var c in _presentationControllers) {
                if (c['childId'] == idToDelete) {
                  c['childId'] = null;
                  c['leftoverCreated'] = false;
                }
              }

              // Eliminar padre (y su hijo si tiene)
              String? childId = item['childId'];
              setState(() {
                _disposeControllerMap(_presentationControllers[index]); 
                _presentationControllers.removeAt(index);
              });

              if (childId != null) {
                int childIndex = _presentationControllers.indexWhere((c) => c['id'] == childId);
                if (childIndex != -1) {
                  setState(() {
                    _disposeControllerMap(_presentationControllers[childIndex]);
                    _presentationControllers.removeAt(childIndex);
                  });
                }
              }
            },
            child: const Text("Eliminar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          )
        ],
      )
    );
  }

  // ==========================================================
  // MÉTODOS DE MODALES DE CREACIÓN RÁPIDA
  // ==========================================================
  Future<int?> _handleCreateBrand(bool isDark) async {
    String? newName = await _showSimpleDialog("Nueva Marca", "Nombre de la marca", isDark);
    if (newName != null && newName.isNotEmpty) return await Provider.of<InventoryProvider>(context, listen: false).createBrand(newName);
    return null;
  }
  Future<int?> _handleCreateCategory(bool isDark) async {
    String? newName = await _showSimpleDialog("Nueva Categoría", "Nombre de la categoría", isDark);
    if (newName != null && newName.isNotEmpty) return await Provider.of<InventoryProvider>(context, listen: false).createCategory(newName);
    return null;
  }
  Future<int?> _handleCreateProvider(bool isDark) async {
    String? newName = await _showSimpleDialog("Nuevo Proveedor", "Nombre de la empresa", isDark);
    if (newName != null && newName.isNotEmpty) return await Provider.of<InventoryProvider>(context, listen: false).createProvider(newName);
    return null;
  }

  Future<String?> _showSimpleDialog(String title, String hint, bool isDark) {
    TextEditingController ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        content: TextField(
          controller: ctrl, 
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            filled: true,
            fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100]
          ), 
          textCapitalization: TextCapitalization.sentences, 
          autofocus: true
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancelar", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 16))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), 
            style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.blue[300] : Theme.of(context).primaryColor, foregroundColor: isDark ? Colors.black87 : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Crear", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // GUARDAR EDICIÓN
  // ==========================================================
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return; 
    
    if (_selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("La categoría es obligatoria", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red));
        return;
    }

    if (_presentationControllers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Debe haber al menos una presentación", style: TextStyle(fontWeight: FontWeight.bold))));
      return;
    }

    final String pDesc = _descCtrl.text.trim();
    final String pImg = _imgUrlCtrl.text.trim();
    final String pCode = _parentBarcodeCtrl.text.trim();

    List<ProductPresentation> presentacionesFinales = [];
    
    for (var c in _presentationControllers) {
      String specific = (c['specific'] as TextEditingController).text.trim();
      String uVenta = (c['unidadVenta'] as TextEditingController).text.trim();
      int factorVenta = int.tryParse((c['unidadesVenta'] as TextEditingController).text) ?? 1;
      
      double margen = double.tryParse((c['margen'] as TextEditingController).text) ?? 1.35;
      double pVenta = double.tryParse((c['precioVenta'] as TextEditingController).text) ?? 0.0;
      
      int stockVisual = int.tryParse((c['stockFinal'] as TextEditingController).text) ?? 0;
      int stockBaseGuardar = stockVisual * factorVenta;

      String umpC = (c['umpCompra'] as TextEditingController).text.trim();
      double cantC = double.tryParse((c['cantCompra'] as TextEditingController).text) ?? 0.0;
      double totalP = double.tryParse((c['totalPago'] as TextEditingController).text) ?? 0.0;
      int loteC = int.tryParse((c['unidadesLote'] as TextEditingController).text) ?? 1;

      double costoPresFinal = double.tryParse((c['costoPres'] as TextEditingController).text) ?? 0.0;

      String rawDesc = (c['desc'] as TextEditingController).text.trim();
      String? finalDesc = (rawDesc.isEmpty && pDesc.isNotEmpty) ? pDesc : (rawDesc.isEmpty ? null : rawDesc);
      String rawImg = (c['image'] as TextEditingController).text.trim();
      String? finalImg = (rawImg.isEmpty && pImg.isNotEmpty) ? pImg : (rawImg.isEmpty ? null : rawImg);
      String rawCode = (c['barcode'] as TextEditingController).text.trim();
      String? finalCode = (rawCode.isEmpty && pCode.isNotEmpty) ? pCode : (rawCode.isEmpty ? null : rawCode);

      presentacionesFinales.add(ProductPresentation(
        id: c['db_id'], 
        nombreEspecifico: specific.isEmpty ? null : specific,
        
        unidadVenta: uVenta.isEmpty ? "Unidad" : uVenta,
        unidadesPorVenta: factorVenta,
        costoUnitarioCalculado: costoPresFinal,
        factorGananciaVenta: margen,
        precioVentaFinal: pVenta,
        
        stockActual: stockBaseGuardar,
        
        umpCompra: umpC.isEmpty ? null : umpC,
        cantidadUmpComprada: cantC > 0 ? cantC : null,
        totalPagoLote: totalP > 0 ? totalP : null,
        unidadesPorLote: loteC,
        precioUmpProveedor: cantC > 0 ? (totalP / cantC) : null,
        
        codigoBarras: finalCode,
        imagenUrl: finalImg, 
        descripcion: finalDesc,
        proveedorId: c['providerId'],
        esDefault: c['isDefault'] == true,
        estado: c['estado'] as String, 
      ));
    }

    final provider = Provider.of<InventoryProvider>(context, listen: false);
    
    final success = await provider.editFullProduct(
      productId: widget.productToEdit.id,
      nombre: _nameCtrl.text,
      descripcion: pDesc.isEmpty ? null : pDesc,
      marcaId: _selectedBrandId,
      categoriaId: _selectedCategoryId!, 
      estado: _generalState == 2 ? 'publico' : 'privado', // Conserva consistencia general si aplica
      imagenUrl: pImg.isEmpty ? null : pImg, 
      codigoBarras: pCode.isEmpty ? null : pCode,
      presentaciones: presentacionesFinales,
      idsToDelete: _idsToDelete
    );

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Producto actualizado correctamente", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${provider.errorMessage}", style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final surfaceColor = isDark ? const Color(0xFF14141C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_isLoading) return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator()));

    final provider = Provider.of<InventoryProvider>(context);

    List<ProviderModel> providerListForDropdown = List.from(provider.providers);
    int? currentGenProv = _generalProviderId;
    if (currentGenProv == -2) {
      providerListForDropdown.insert(0, ProviderModel(id: -2, nombreEmpresa: "Múltiples Proveedores (Mixto)", idNegocio: 0, activo: true));
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Editar Producto", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
        backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.white,
        foregroundColor: textColor,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
      ),
      
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A24) : Colors.white, 
          boxShadow: [if(!isDark) const BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -5))],
          border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.transparent))
        ),
        child: SafeArea(
          child: SizedBox(
            height: 50, 
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: provider.isLoading ? Colors.grey : (isDark ? Colors.blue[700] : Colors.blue[800]), 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: isDark ? 0 : 4,
              ),
              onPressed: provider.isLoading ? null : _save, 
              child: provider.isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
                        SizedBox(width: 12),
                        Text("GUARDANDO...", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))
                      ],
                    )
                  : const Text("GUARDAR CAMBIOS", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. BLOQUE INFO GENERAL
              Container(
                decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.blue.withOpacity(0.15)), boxShadow: [if(!isDark) BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue[50], borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                      child: Row(children: [Icon(Icons.info_outline, color: isDark ? Colors.blue[300] : Colors.blue[800], size: 20), const SizedBox(width: 10), Text("Información General", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[100] : Colors.blue[900]))]),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          CustomTextField(label: "Nombre del Producto *", icon: Icons.edit, controller: _nameCtrl, maxLines: 1),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: SafeDropdown<Brand>(label: "Marca", icon: Icons.branding_watermark_outlined, value: _selectedBrandId, items: provider.brands, getId: (b) => b.id, getName: (b) => b.nombre, isActive: (b) => b.activo == true, onChanged: (v) { if (v == -1) {
                                _handleCreateBrand(isDark).then((id) { if (id != null) setState(() => _selectedBrandId = id); });
                              } else {
                                setState(() => _selectedBrandId = v);
                              } })),
                              const SizedBox(width: 12),
                              Expanded(child: SafeDropdown<Category>(label: "Categoría *", icon: Icons.category_outlined, value: _selectedCategoryId, items: provider.categories, getId: (c) => c.id, getName: (c) => c.nombre, isActive: (c) => c.activo == true, onChanged: (v) { if (v == -1) {
                                _handleCreateCategory(isDark).then((id) { if (id != null) setState(() => _selectedCategoryId = id); });
                              } else {
                                setState(() => _selectedCategoryId = v);
                              } })),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SafeDropdown<ProviderModel>(label: "Proveedor General", icon: Icons.local_shipping_outlined, value: currentGenProv, items: providerListForDropdown, getId: (p) => p.id, getName: (p) => p.nombreEmpresa, isActive: (p) => p.activo == true, onChanged: (v) => _handleGeneralProviderChange(v, isDark)),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [Icon(Icons.visibility, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]), const SizedBox(width: 8), Text("Visibilidad de Variantes", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor))]),
                                const SizedBox(height: 12),
                                _buildSuperSwitch(isDark),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ProductOptionalInfo(descCtrl: _descCtrl, imgCtrl: _imgUrlCtrl, barcodeCtrl: _parentBarcodeCtrl),
              const SizedBox(height: 30),
              
              Text(" PRESENTACIONES / VARIANTES", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: isDark ? Colors.teal[300] : Colors.teal[800], letterSpacing: 0.5)),
              const SizedBox(height: 12),

              ..._presentationControllers.asMap().entries.map((entry) {
                int index = entry.key;
                var ctrlMap = entry.value;

                return ProductPresentationCard(
                  key: ValueKey(ctrlMap['id']), // 🔥 CRÍTICO: Key única para no cruzar estados en edición
                  controllerMap: ctrlMap,
                  onDelete: () => _deletePresentation(index, isDark),
                  onStateChange: (val) => setState(() => ctrlMap['estado'] = val ? 'publico' : 'privado'),
                  
                  // Funciones de sobrantes
                  onCreateLeftover: (leftoverStock, costoBaseIndiv) {
                    _handleCreateLeftover(ctrlMap['id'], leftoverStock, costoBaseIndiv);
                  },
                  onInvalidateLeftover: () {
                    _invalidateLeftover(ctrlMap['id']);
                  },

                  providerDropdown: SafeDropdown<ProviderModel>(
                    label: "Proveedor Específico", icon: null, value: ctrlMap['providerId'], items: provider.providers,
                    getId: (p) => p.id, getName: (p) => p.nombreEmpresa, isActive: (p) => p.activo == true, allowNull: true,
                    onChanged: (v) { if (v == -1) { _handleCreateProvider(isDark).then((id) { if (id != null) setState(() => ctrlMap['providerId'] = id); }); } else { setState(() => ctrlMap['providerId'] = v); } }
                  ),
                );
              }),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addPresentation,
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: const Text("AÑADIR OTRA PRESENTACIÓN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), foregroundColor: isDark ? Colors.teal[300] : Colors.teal[700], side: BorderSide(color: isDark ? Colors.teal.withOpacity(0.5) : Colors.teal.shade300, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuperSwitch(bool isDark) {
    int current = _generalState;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (current == 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text("Estado actual: Variado (Seleccione uno para unificar)", style: TextStyle(fontSize: 12, color: isDark ? Colors.orange[300] : Colors.orange[800], fontStyle: FontStyle.italic)),
          ),
        Container(
          height: 42,
          decoration: BoxDecoration(color: isDark ? const Color(0xFF14141C) : Colors.grey[200], borderRadius: BorderRadius.circular(12)),
          child: Stack(
            children: [
              AnimatedAlign(
                alignment: current == 0 ? Alignment.centerLeft : (current == 2 ? Alignment.centerRight : Alignment.center),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: current == 1 
                    ? const SizedBox.shrink() 
                    : FractionallySizedBox(
                        widthFactor: 0.5, 
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: current == 0 ? (isDark ? Colors.orange[800] : Colors.white) : (isDark ? Colors.green[700] : Colors.white),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: !isDark ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))] : [],
                          ),
                        ),
                      ),
              ),
              Row(
                children: [
                  Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _setGeneralState(0), child: Center(child: Text("Ocultar Todos", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: current == 0 ? (isDark ? Colors.white : Colors.orange[800]) : Colors.grey))))),
                  Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _setGeneralState(2), child: Center(child: Text("Publicar Todos", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: current == 2 ? (isDark ? Colors.white : Colors.green[700]) : Colors.grey))))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}