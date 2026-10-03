import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';

import 'package:app_movil/core/widgets/custom_text_field.dart';
import 'package:app_movil/core/widgets/safe_dropdown.dart';
import 'package:app_movil/core/widgets/product_optional_info.dart';
import 'package:app_movil/core/widgets/product_presentation_card.dart';
import 'package:app_movil/core/widgets/super_switch.dart';

class ProductCreateScreen extends StatefulWidget {
  final String? initialBarcode;

  const ProductCreateScreen({super.key, this.initialBarcode});

  @override
  State<ProductCreateScreen> createState() => _ProductCreateScreenState();
}

class _ProductCreateScreenState extends State<ProductCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _imgUrlCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();

  int? _selectedCategoryId;
  int? _selectedBrandId;

  final List<Map<String, dynamic>> _controllers = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialBarcode != null) {
      _barcodeCtrl.text = widget.initialBarcode!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).loadMasterData();
    });
    _addPresentation(isDefault: true);
  }

  void _disposeControllerMap(Map<String, dynamic> map) {
    (map['specific'] as TextEditingController).dispose();
    (map['unidadVenta'] as TextEditingController).dispose();
    (map['unidadesVenta'] as TextEditingController).dispose();
    (map['costoPres'] as TextEditingController).dispose();
    (map['margen'] as TextEditingController).dispose();
    (map['precioVenta'] as TextEditingController).dispose();
    (map['stockInicial'] as TextEditingController).dispose();
    (map['nuevoIngreso'] as TextEditingController).dispose();
    (map['stockDescuento'] as TextEditingController).dispose();
    (map['stockFinal'] as TextEditingController).dispose();
    (map['valorDescuento'] as TextEditingController).dispose();
    (map['umpCompra'] as TextEditingController).dispose();
    (map['unidadesLote'] as TextEditingController).dispose();
    (map['cantCompra'] as TextEditingController).dispose();
    (map['totalPago'] as TextEditingController).dispose();
    (map['barcode'] as TextEditingController).dispose();
    (map['desc'] as TextEditingController).dispose();
    (map['image'] as TextEditingController).dispose();
    (map['ajusteBase'] as TextEditingController).dispose();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _imgUrlCtrl.dispose();
    _barcodeCtrl.dispose();
    for (var map in _controllers) {
      _disposeControllerMap(map);
    }
    super.dispose();
  }

  int get _generalState {
    if (_controllers.isEmpty) return 2;
    bool allPublic = _controllers.every((c) => c['estado'] == 'publico');
    bool allPrivate = _controllers.every((c) => c['estado'] == 'privado');
    if (allPublic) return 2;
    if (allPrivate) return 0;
    return 1; // 1 = MIXTO
  }

  void _setGeneralState(int stateIndex) {
    if (stateIndex == 1) return;
    String newState = stateIndex == 2 ? 'publico' : 'privado';
    setState(() {
      for (var c in _controllers) {
        c['estado'] = newState;
      }
    });
  }

  int? get _generalProviderId {
    if (_controllers.isEmpty) return null;
    int? firstId = _controllers.first['providerId'];
    for (var c in _controllers) {
      if (c['providerId'] != firstId) return -2;
    }
    return firstId;
  }

  Future<void> _handleGeneralProviderChange(int? newId, bool isDark) async {
    if (newId == -1) {
      newId = await _handleCreateProvider(isDark);
      if (newId == null) return;
    }
    if (_generalProviderId != -2 && _controllers.length <= 1) {
      setState(() {
        for (var c in _controllers) {
          c['providerId'] = newId;
        }
      });
      return;
    }
    if (!mounted) return;
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "¿Sobreescribir Proveedores?",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Esta acción cambiará el proveedor de TODAS las presentaciones.",
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sí, Aplicar"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        for (var c in _controllers) {
          c['providerId'] = newId;
        }
      });
    }
  }

  void _addPresentation({bool isDefault = false, int? indexInsert}) {
    final newMap = {
      'id': UniqueKey().toString(),
      'childId': null,
      'isEditMode': false,
      'leftoverCreated': false,

      'specific': TextEditingController(),
      'unidadVenta': TextEditingController(text: "Unidad"),
      'unidadesVenta': TextEditingController(text: "1"),
      'costoPres': TextEditingController(text: "0.00"),
      'margen': TextEditingController(text: "1.35"),
      'precioVenta': TextEditingController(text: ""),

      'descuentoActivo': false,
      'tipoDescuento': 'porcentaje',
      'valorDescuento': TextEditingController(text: ""),

      'stockInicial': TextEditingController(text: "0"),
      'nuevoIngreso': TextEditingController(text: ""),
      'stockDescuento': TextEditingController(text: "0"),
      'stockFinal': TextEditingController(text: "0"),

      'umpCompra': TextEditingController(text: ""),
      'unidadesLote': TextEditingController(text: ""),
      'cantCompra': TextEditingController(text: ""),
      'totalPago': TextEditingController(text: ""),

      'barcode': TextEditingController(),
      'desc': TextEditingController(),
      'image': TextEditingController(),
      'ajusteBase': TextEditingController(),
      'providerId': _generalProviderId == -2 ? null : _generalProviderId,
      'isDefault': isDefault,
      'estado': _generalState == 0 ? 'privado' : 'publico',
    };

    setState(() {
      if (indexInsert != null) {
        _controllers.insert(indexInsert, newMap);
      } else {
        _controllers.add(newMap);
      }
    });
  }

  void _handleCreateLeftover(
    String parentId,
    int leftoverUnits,
    double costoBaseIndividual,
  ) {
    int parentIndex = _controllers.indexWhere((c) => c['id'] == parentId);
    if (parentIndex == -1) return;

    Map<String, dynamic> sourceMap = _controllers[parentIndex];
    sourceMap['leftoverCreated'] = true;

    String newChildId = UniqueKey().toString();
    sourceMap['childId'] = newChildId;

    setState(() {
      _controllers.insert(parentIndex + 1, {
        'id': newChildId,
        'childId': null,
        'isEditMode': false,
        'leftoverCreated': false,
        'specific': TextEditingController(
          text: sourceMap['specific'].text.isNotEmpty
              ? "${sourceMap['specific'].text} - Suelta"
              : "Suelta",
        ),
        'unidadVenta': TextEditingController(text: "Unidad"),
        'unidadesVenta': TextEditingController(text: "1"),
        'costoPres': TextEditingController(
          text: costoBaseIndividual.toStringAsFixed(2),
        ),
        'margen': TextEditingController(text: "1.35"),
        'precioVenta': TextEditingController(
          text: (costoBaseIndividual * 1.35).toStringAsFixed(2),
        ),

        'descuentoActivo': false,
        'tipoDescuento': 'porcentaje',
        'valorDescuento': TextEditingController(text: ""),

        'stockInicial': TextEditingController(text: leftoverUnits.toString()),
        'nuevoIngreso': TextEditingController(text: "0"),
        'stockDescuento': TextEditingController(text: "0"),
        'stockFinal': TextEditingController(text: leftoverUnits.toString()),

        'umpCompra': TextEditingController(text: ""),
        'unidadesLote': TextEditingController(text: ""),
        'cantCompra': TextEditingController(text: ""),
        'totalPago': TextEditingController(text: ""),
        'barcode': TextEditingController(),
        'desc': TextEditingController(),
        'image': TextEditingController(),
        'ajusteBase': TextEditingController(),
        'providerId': sourceMap['providerId'],
        'isDefault': false,
        'estado': sourceMap['estado'],
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Variante sobrante creada debajo"),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _invalidateLeftover(String parentId) {
    int parentIndex = _controllers.indexWhere((c) => c['id'] == parentId);
    if (parentIndex != -1) {
      String? childId = _controllers[parentIndex]['childId'];
      if (childId != null) {
        int childIndex = _controllers.indexWhere((c) => c['id'] == childId);
        if (childIndex != -1) {
          _disposeControllerMap(_controllers[childIndex]);
          _controllers.removeAt(childIndex);
        }
      }
      _controllers[parentIndex]['childId'] = null;
      _controllers[parentIndex]['leftoverCreated'] = false;
      setState(() {});
    }
  }

  void _removePresentation(int index) {
    if (_controllers.length > 1) {
      String idToDelete = _controllers[index]['id'];
      String? childId = _controllers[index]['childId'];

      for (var c in _controllers) {
        if (c['childId'] == idToDelete) {
          c['childId'] = null;
          c['leftoverCreated'] = false;
        }
      }

      setState(() {
        _disposeControllerMap(_controllers[index]);
        _controllers.removeAt(index);
      });

      if (childId != null) {
        int childIndex = _controllers.indexWhere((c) => c['id'] == childId);
        if (childIndex != -1) {
          setState(() {
            _disposeControllerMap(_controllers[childIndex]);
            _controllers.removeAt(childIndex);
          });
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debe haber al menos una presentación")),
      );
    }
  }

  Future<int?> _handleCreateBrand(bool isDark) async {
    String? newName = await _showSimpleDialog(
      "Nueva Marca",
      "Nombre de la marca",
      isDark,
    );
    if (!mounted) return null;
    if (newName != null && newName.isNotEmpty) {
      return await Provider.of<InventoryProvider>(
        context,
        listen: false,
      ).createBrand(newName);
    }
    return null;
  }

  Future<int?> _handleCreateCategory(bool isDark) async {
    String? newName = await _showSimpleDialog(
      "Nueva Categoría",
      "Nombre de la categoría",
      isDark,
    );
    if (!mounted) return null;
    if (newName != null && newName.isNotEmpty) {
      return await Provider.of<InventoryProvider>(
        context,
        listen: false,
      ).createCategory(newName);
    }
    return null;
  }

  Future<int?> _handleCreateProvider(bool isDark) async {
    String? newName = await _showSimpleDialog(
      "Nuevo Proveedor",
      "Nombre de la empresa",
      isDark,
    );
    if (!mounted) return null;
    if (newName != null && newName.isNotEmpty) {
      return await Provider.of<InventoryProvider>(
        context,
        listen: false,
      ).createProvider(newName);
    }
    return null;
  }

  Future<String?> _showSimpleDialog(String title, String hint, bool isDark) {
    TextEditingController ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text("Crear"),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Completa la Información General (Nombre)"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final String pDesc = _descCtrl.text.trim();
    final String pImg = _imgUrlCtrl.text.trim();
    final String pCode = _barcodeCtrl.text.trim();

    List<ProductPresentation> presentations = [];

    try {
      for (var c in _controllers) {
        String specific = (c['specific'] as TextEditingController).text.trim();
        String uVenta = (c['unidadVenta'] as TextEditingController).text.trim();
        int factorVenta =
            int.tryParse((c['unidadesVenta'] as TextEditingController).text) ??
            1;

        double margen =
            double.tryParse((c['margen'] as TextEditingController).text) ??
            1.35;
        double pVenta =
            double.tryParse((c['precioVenta'] as TextEditingController).text) ??
            0.0;

        int stockVisual =
            int.tryParse((c['stockFinal'] as TextEditingController).text) ?? 0;
            
        int stockBaseGuardar = stockVisual * factorVenta;
        String ajusteText = (c['ajusteBase'] as TextEditingController).text.trim();
        if (ajusteText.isNotEmpty) {
          stockBaseGuardar = int.tryParse(ajusteText) ?? stockBaseGuardar;
        }

        if (factorVenta > 1) {
          StockValidationResult? validation = c['stockValidation'] as StockValidationResult?;
          if (validation != null) {
            if (validation.status == StockValidationStatus.deficit) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "❌ '$specific': ${validation.userMessage(uVenta, factorVenta)}",
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            if (validation.status == StockValidationStatus.hasLeftover &&
                c['leftoverCreated'] != true) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "⚠️ '$specific' tiene unidades sueltas sin asignar. Crea su variante.",
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
          }
        }

        String umpC = (c['umpCompra'] as TextEditingController).text.trim();
        double cantC =
            double.tryParse((c['cantCompra'] as TextEditingController).text) ??
            0.0;
        double totalP =
            double.tryParse((c['totalPago'] as TextEditingController).text) ??
            0.0;
        int loteC =
            int.tryParse((c['unidadesLote'] as TextEditingController).text) ??
            1;

        double costoPresFinal =
            double.tryParse((c['costoPres'] as TextEditingController).text) ??
            0.0;

        String rawDesc = (c['desc'] as TextEditingController).text.trim();
        String? finalDesc = (rawDesc.isEmpty && pDesc.isNotEmpty)
            ? pDesc
            : (rawDesc.isEmpty ? null : rawDesc);
        String rawImg = (c['image'] as TextEditingController).text.trim();
        String? finalImg = rawImg.isEmpty ? null : rawImg;
        String rawCode = (c['barcode'] as TextEditingController).text.trim();
        String? finalCode = (rawCode.isEmpty && pCode.isNotEmpty)
            ? pCode
            : (rawCode.isEmpty ? null : rawCode);

        bool descuentoActivo = c['descuentoActivo'] == true;
        String tipoDescuento = c['tipoDescuento'] as String;
        double valorDescuento =
            double.tryParse(
              (c['valorDescuento'] as TextEditingController).text,
            ) ??
            0.0;

        double? precioOferta;
        if (descuentoActivo && valorDescuento > 0 && pVenta > 0) {
          if (tipoDescuento == 'porcentaje') {
            precioOferta = pVenta - (pVenta * (valorDescuento / 100));
          } else {
            precioOferta = pVenta - valorDescuento;
          }
        }

        presentations.add(
          ProductPresentation(
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
            descripcion: finalDesc,
            imagenUrl: finalImg,
            codigoBarras: finalCode,
            estado: c['estado'] as String,
            esDefault: c['isDefault'] == true,
            proveedorId: c['providerId'],
            tipoDescuento: descuentoActivo ? tipoDescuento : null,
            valorDescuento: descuentoActivo && valorDescuento > 0
                ? valorDescuento
                : null,
            precioOferta: precioOferta,
          ),
        );
      }
    } catch (e) {
      debugPrint("LOG: Error procesando controladores: $e");
      return;
    }

    final success = await Provider.of<InventoryProvider>(context, listen: false)
        .createFullProduct(
          nombre: _nameCtrl.text,
          marcaId: _selectedBrandId == 0 ? null : _selectedBrandId,
          categoriaId: _selectedCategoryId == 0 ? null : _selectedCategoryId,
          estado: _generalState == 2 ? 'publico' : 'privado',
          descripcion: pDesc.isEmpty ? null : pDesc,
          imagenUrl: pImg.isEmpty ? null : pImg,
          codigoBarras: pCode.isEmpty ? null : pCode,
          presentaciones: presentations,
        );

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "✅ Producto creado exitosamente",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      final msg = Provider.of<InventoryProvider>(
        context,
        listen: false,
      ).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $msg"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final surfaceColor = isDark ? const Color(0xFF1A1A24) : Colors.white;

    List<ProviderModel> providerListForDropdown = List.from(
      provider.activeProviders,
    );
    providerListForDropdown.insert(
      0,
      ProviderModel(
        id: 0,
        nombreEmpresa: "Ninguno",
        idNegocio: 0,
        activo: true,
      ),
    );

    int? currentGenProv = _generalProviderId;
    if (currentGenProv == -2) {
      providerListForDropdown.insert(
        0,
        ProviderModel(
          id: -2,
          nombreEmpresa: "Múltiples Proveedores (Mixto)",
          idNegocio: 0,
          activo: true,
        ),
      );
    }

    List<Category> categoryListForDropdown = List.from(
      provider.activeCategories,
    );
    categoryListForDropdown.insert(
      0,
      Category(id: 0, nombre: "Ninguno", activo: true),
    );

    List<Brand> brandListForDropdown = List.from(provider.activeBrands);
    brandListForDropdown.insert(
      0,
      Brand(id: 0, nombre: "Ninguno", activo: true),
    );

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "Nuevo Producto",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: textColor,
          ),
        ),
        backgroundColor: surfaceColor,
        foregroundColor: textColor,
        elevation: 0,
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: surfaceColor,
          boxShadow: [
            if (!isDark)
              const BoxShadow(
                color: Colors.black12,
                blurRadius: 15,
                offset: Offset(0, -5),
              ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: provider.isLoading
                    ? Colors.grey
                    : (isDark ? Colors.green[700] : Colors.green[800]),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: provider.isLoading ? null : _save,
              child: provider.isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text("GUARDANDO..."),
                      ],
                    )
                  : const Text(
                      "GUARDAR PRODUCTO",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
            ),
          ),
        ),
      ),

      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white10
                          : Colors.blue.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.blue.withValues(alpha: 0.15)
                              : Colors.blue[50],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: isDark
                                  ? Colors.blue[300]
                                  : Colors.blue[800],
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "Información General",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.blue[100]
                                    : Colors.blue[900],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            CustomTextField(
                              label: "Nombre del Producto *",
                              icon: Icons.shopping_bag_outlined,
                              controller: _nameCtrl,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: SafeDropdown<Brand>(
                                    label: "Marca",
                                    icon: Icons.branding_watermark_outlined,
                                    value: _selectedBrandId,
                                    items: brandListForDropdown,
                                    getId: (b) => b.id,
                                    getName: (b) => b.nombre,
                                    isActive: (b) => b.activo == true,
                                    onChanged: (v) {
                                      if (v == -1) {
                                        _handleCreateBrand(isDark).then((id) {
                                          if (id != null) {
                                            setState(
                                              () => _selectedBrandId = id,
                                            );
                                          }
                                        });
                                      } else {
                                        setState(() => _selectedBrandId = v);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SafeDropdown<Category>(
                                    label: "Categoría",
                                    icon: Icons.category_outlined,
                                    value: _selectedCategoryId,
                                    items: categoryListForDropdown,
                                    getId: (c) => c.id,
                                    getName: (c) => c.nombre,
                                    isActive: (c) => c.activo == true,
                                    onChanged: (v) {
                                      if (v == -1) {
                                        _handleCreateCategory(isDark).then((
                                          id,
                                        ) {
                                          if (id != null) {
                                            setState(
                                              () => _selectedCategoryId = id,
                                            );
                                          }
                                        });
                                      } else {
                                        setState(() => _selectedCategoryId = v);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SafeDropdown<ProviderModel>(
                              label: "Proveedor General",
                              icon: Icons.local_shipping_outlined,
                              value: currentGenProv,
                              items: providerListForDropdown,
                              getId: (p) => p.id,
                              getName: (p) => p.nombreEmpresa,
                              isActive: (p) => p.activo == true,
                              onChanged: (v) =>
                                  _handleGeneralProviderChange(v, isDark),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.black26
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.visibility,
                                        size: 16,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Visibilidad de Variantes",
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SuperSwitch(
                                    current: _generalState,
                                    onChanged: _setGeneralState,
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ProductOptionalInfo(
                  descCtrl: _descCtrl,
                  imgCtrl: _imgUrlCtrl,
                  barcodeCtrl: _barcodeCtrl,
                ),
                const SizedBox(height: 30),

                Text(
                  " PRESENTACIONES / VARIANTES",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.teal[300] : Colors.teal[800],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),

                ...List.generate(_controllers.length, (i) {
                  return ProductPresentationCard(
                    key: ValueKey(_controllers[i]['id']),
                    controllerMap: _controllers[i],
                    onDelete: () => _removePresentation(i),
                    onStateChange: (val) {
                      setState(() {
                        _controllers[i]['estado'] = val ? 'publico' : 'privado';
                      });
                    },

                    onCreateLeftover: (leftoverStock, costoBaseIndiv) {
                      _handleCreateLeftover(
                        _controllers[i]['id'],
                        leftoverStock,
                        costoBaseIndiv,
                      );
                    },
                    onInvalidateLeftover: () {
                      _invalidateLeftover(_controllers[i]['id']);
                    },

                    providerDropdown: SafeDropdown<ProviderModel>(
                      label: "Proveedor de esta Variante",
                      icon: null,
                      value: _controllers[i]['providerId'],
                      items: providerListForDropdown,
                      getId: (p) => p.id,
                      getName: (p) => p.nombreEmpresa,
                      isActive: (p) => p.activo == true,
                      allowNull: true,
                      onChanged: (v) {
                        if (v == -1) {
                          _handleCreateProvider(isDark).then((id) {
                            if (id != null) {
                              setState(
                                () => _controllers[i]['providerId'] = id,
                              );
                            }
                          });
                        } else {
                          setState(
                            () => _controllers[i]['providerId'] = v == 0
                                ? null
                                : v,
                          );
                        }
                      },
                    ),
                  );
                }),

                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _addPresentation(),
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: const Text(
                      "AÑADIR OTRA PRESENTACIÓN",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: isDark
                          ? Colors.teal[300]
                          : Colors.teal[700],
                      side: BorderSide(
                        color: isDark
                            ? Colors.teal.withValues(alpha: 0.5)
                            : Colors.teal.shade300,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
