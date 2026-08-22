import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/promotions/models/bundle_model.dart';
import 'package:app_movil/features/promotions/models/bundle_item_model.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:intl/intl.dart';

class BundleBuilderScreen extends StatefulWidget {
  final BundleModel? bundleToEdit;
  final InventoryWrapper? initialItem;
  final List<InventoryWrapper>? initialMultipleItems;
  final String? initialTipoPromocion;
  
  const BundleBuilderScreen({super.key, this.bundleToEdit, this.initialItem, this.initialMultipleItems, this.initialTipoPromocion});

  @override
  State<BundleBuilderScreen> createState() => _BundleBuilderScreenState();
}

class _BundleBuilderScreenState extends State<BundleBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  
  List<BundleItemModel> _selectedItems = [];
  bool _isActive = true;
  String _searchQuery = "";
  
  String _tipoPromocion = 'paquete';
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  final _currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
  
  bool _userEditedName = false;
  bool _userEditedPrice = false;
  bool _userEditedDesc = false;

  @override
  void initState() {
    super.initState();
    if (widget.bundleToEdit != null) {
      _nameController.text = widget.bundleToEdit!.nombrePaquete;
      _descController.text = widget.bundleToEdit!.descripcion ?? '';
      _priceController.text = widget.bundleToEdit!.precioVentaTotal.toStringAsFixed(2);
      _isActive = widget.bundleToEdit!.activo;
      _tipoPromocion = widget.bundleToEdit!.tipoPromocion;
      _fechaInicio = widget.bundleToEdit!.fechaInicio;
      _fechaFin = widget.bundleToEdit!.fechaFin;
      _userEditedName = true;
      _userEditedDesc = _descController.text.isNotEmpty;
      _userEditedDesc = _descController.text.isNotEmpty;
      _userEditedPrice = false; // Permitimos que recalcule al cambiar de tipo

      final prov = Provider.of<PromotionProvider>(context, listen: false);
      _selectedItems = List.from(prov.getItemsForBundle(widget.bundleToEdit!.id));
    } else if (widget.initialMultipleItems != null && widget.initialMultipleItems!.isNotEmpty) {
      if (widget.initialTipoPromocion != null) {
        _tipoPromocion = widget.initialTipoPromocion!;
      }
      for (var item in widget.initialMultipleItems!) {
        _selectedItems.add(BundleItemModel(
          id: 0,
          paqueteId: 0,
          productoId: item.product.id,
          presentacionId: item.presentation.id ?? 0,
          cantidadRequerida: 1,
          precioOriginalUnitario: item.effectivePrice,
        ));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyPromoRules();
        _autoSuggestNameAndPrice();
        setState(() {});
        
        if (widget.initialTipoPromocion != null) {
          final currentPromo = _promoTypes.firstWhere((t) => t['id'] == _tipoPromocion, orElse: () => _promoTypes.first);
          CustomSnackBar.show(context, message: "Sugerencia aplicada: ${currentPromo['label']}", isError: false);
        }
      });
    } else if (widget.initialItem != null) {
      if (widget.initialTipoPromocion != null) {
        _tipoPromocion = widget.initialTipoPromocion!;
      }
      _selectedItems.add(BundleItemModel(
        id: 0,
        paqueteId: 0,
        productoId: widget.initialItem!.product.id,
        presentacionId: widget.initialItem!.presentation.id ?? 0,
        cantidadRequerida: 1,
        precioOriginalUnitario: widget.initialItem!.effectivePrice,
      ));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyPromoRules();
        _autoSuggestNameAndPrice();
        setState(() {});
        
        if (widget.initialTipoPromocion != null) {
          final currentPromo = _promoTypes.firstWhere((t) => t['id'] == _tipoPromocion, orElse: () => _promoTypes.first);
          CustomSnackBar.show(context, message: "Sugerencia aplicada: ${currentPromo['label']}", isError: false);
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  double get _totalBaseCost {
    final inv = Provider.of<InventoryProvider>(context, listen: false);
    double total = 0;
    for (var item in _selectedItems) {
      try {
        final prod = inv.items.firstWhere((p) => p.presentation.id == item.presentacionId);
        total += (prod.presentation.costoUnitarioCalculado ?? 0) * item.cantidadRequerida;
      } catch (e) {
        // Producto no encontrado
      }
    }
    return total;
  }

  double get _totalOriginalPrice {
    final inv = Provider.of<InventoryProvider>(context, listen: false);
    double total = 0;
    for (var item in _selectedItems) {
      try {
        final prod = inv.items.firstWhere((p) => p.presentation.id == item.presentacionId);
        total += prod.effectivePrice * item.cantidadRequerida;
      } catch (e) {
        // Producto no encontrado
      }
    }
    return total;
  }

  void _saveBundle() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItems.isEmpty) {
      CustomSnackBar.show(context, message: "Agrega al menos un producto al paquete", isError: true);
      return;
    }
    
    if (_tipoPromocion == 'flash' && _fechaFin == null) {
      CustomSnackBar.show(context, message: "Las ofertas Flash deben tener una fecha de fin obligatoria", isError: true);
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final prov = Provider.of<PromotionProvider>(context, listen: false);

    final bundle = BundleModel(
      id: widget.bundleToEdit?.id ?? 0,
      negocioId: auth.activeBusinessId ?? 0,
      nombrePaquete: _nameController.text.trim(),
      descripcion: _descController.text.trim(),
      precioVentaTotal: double.tryParse(_priceController.text) ?? 0.0,
      costoTotalCalculado: _totalBaseCost,
      activo: _isActive,
      tipoPromocion: _tipoPromocion,
      fechaInicio: _fechaInicio,
      fechaFin: _fechaFin,
    );

    try {
      await prov.saveBundle(bundle, _selectedItems);
      if (mounted) {
        Navigator.pop(context, true);
        CustomSnackBar.show(context, message: "Paquete guardado exitosamente", isError: false);
      }
    } catch (e) {
      if (mounted) CustomSnackBar.show(context, message: "Error al guardar: $e", isError: true);
    }
  }

  /// Genera un nombre corto para un producto (máx 3 palabras significativas)
  String _shortName(InventoryWrapper wrap) {
    String name = wrap.product.nombre;
    // Tomar solo las primeras 3 palabras significativas
    final words = name.split(' ').where((w) => w.length > 2).take(3).toList();
    return words.isNotEmpty ? words.join(' ') : name;
  }

  /// Genera el nombre completo con marca y presentación
  String _fullName(InventoryWrapper wrap) {
    String full = wrap.product.nombre;
    if (wrap.product.marcaNombre != null && wrap.product.marcaNombre!.isNotEmpty && wrap.product.marcaNombre!.toLowerCase() != 'sin marca') {
      full = "${wrap.product.marcaNombre} $full";
    }
    if (wrap.presentation.nombreEspecifico != null && wrap.presentation.nombreEspecifico!.isNotEmpty) {
      full += " - ${wrap.presentation.nombreEspecifico}";
    }
    return full;
  }

  void _autoSuggestNameAndPrice() {
    if (_selectedItems.isEmpty) return;
    
    final inv = Provider.of<InventoryProvider>(context, listen: false);
    
    // --- Suggest Name (corto) ---
    if (!_userEditedName) {
      List<String> shortNames = [];
      for (var item in _selectedItems.take(3)) {
        try {
          final prod = inv.items.firstWhere((p) => p.presentation.id == item.presentacionId);
          shortNames.add(_shortName(prod));
        } catch (e) { /* producto eliminado */ }
      }
      if (shortNames.isNotEmpty) {
        String prefix;
        switch (_tipoPromocion) {
          case 'liquidez_costo': prefix = "Liquidez: "; break;
          case 'flash': prefix = "⚡ Flash: "; break;
          case '2x1': prefix = "2x1: "; break;
          case 'volumen': prefix = "Mayoreo: "; break;
          case 'escolar': prefix = "🎒 Pack Escolar: "; break;
          default: prefix = "Pack "; break;
        }
        String joined = shortNames.take(2).join(' + ');
        if (_selectedItems.length > 2) joined += " y más";
        _nameController.text = prefix + joined;
      }
    }

    // --- Suggest Description (nombres completos) ---
    if (!_userEditedDesc) {
      List<String> fullNames = [];
      for (var item in _selectedItems) {
        try {
          final prod = inv.items.firstWhere((p) => p.presentation.id == item.presentacionId);
          fullNames.add("${_fullName(prod)} (x${item.cantidadRequerida})");
        } catch (e) { /* producto eliminado */ }
      }
      if (fullNames.isNotEmpty) {
        _descController.text = "Incluye: ${fullNames.join(', ')}";
      }
    }
    
    // --- Suggest Price based on Promo Type ---
    if (!_userEditedPrice) {
      double totalOriginal = _totalOriginalPrice;
      double totalCost = _totalBaseCost;
      if (totalOriginal > 0) {
        double suggested;
        switch (_tipoPromocion) {
          case 'liquidez_costo':
            suggested = totalCost;
            break;
          case 'flash':
            suggested = totalOriginal * 0.85;
            break;
          case '2x1':
            // Precio = el del producto más caro (pagas 1, llevas 2)
            double maxPrice = 0;
            for (var item in _selectedItems) {
              try {
                final prod = inv.items.firstWhere((p) => p.presentation.id == item.presentacionId);
                if (prod.effectivePrice > maxPrice) maxPrice = prod.effectivePrice;
              } catch (e) {
                // Ignore missing products
              }
            }
            suggested = maxPrice > 0 ? maxPrice : totalOriginal * 0.50;
            break;
          case 'volumen':
            suggested = totalOriginal * 0.80;
            break;
          case 'escolar':
            suggested = totalOriginal * 0.88;
            break;
          default:
            suggested = totalOriginal * 0.90;
            break;
        }
        _priceController.text = suggested.toStringAsFixed(2);
      }
    }

    // Forzar rebuild para que la UI de rentabilidad se actualice inmediatamente
    if (mounted) setState(() {});
  }

  /// Aplica reglas automáticas inteligentes al cambiar tipo de promoción
  void _applyPromoRules() {
    if (_selectedItems.isEmpty) return;
    
    if (_tipoPromocion == '2x1') {
      // Si hay 1 solo tipo de producto con cantidad 1, subir a 2 automáticamente
      if (_selectedItems.length == 1 && _selectedItems[0].cantidadRequerida < 2) {
        _selectedItems[0] = BundleItemModel(
          id: _selectedItems[0].id,
          paqueteId: _selectedItems[0].paqueteId,
          productoId: _selectedItems[0].productoId,
          presentacionId: _selectedItems[0].presentacionId,
          cantidadRequerida: 2,
          precioOriginalUnitario: _selectedItems[0].precioOriginalUnitario,
        );
      }
    } else if (_tipoPromocion == 'volumen') {
      // Si la cantidad total es menor a 3, subir el primer producto a 3
      int totalQty = _selectedItems.fold(0, (sum, i) => sum + i.cantidadRequerida);
      if (totalQty < 3 && _selectedItems.isNotEmpty) {
        int needed = 3 - totalQty + _selectedItems[0].cantidadRequerida;
        _selectedItems[0] = BundleItemModel(
          id: _selectedItems[0].id,
          paqueteId: _selectedItems[0].paqueteId,
          productoId: _selectedItems[0].productoId,
          presentacionId: _selectedItems[0].presentacionId,
          cantidadRequerida: needed,
          precioOriginalUnitario: _selectedItems[0].precioOriginalUnitario,
        );
      }
    }
  }

  void _addItem(InventoryWrapper product) {
    setState(() {
      final existingIdx = _selectedItems.indexWhere((i) => i.presentacionId == product.presentation.id);
      if (existingIdx >= 0) {
        _selectedItems[existingIdx] = BundleItemModel(
          id: _selectedItems[existingIdx].id,
          paqueteId: _selectedItems[existingIdx].paqueteId,
          productoId: _selectedItems[existingIdx].productoId,
          presentacionId: _selectedItems[existingIdx].presentacionId,
          cantidadRequerida: _selectedItems[existingIdx].cantidadRequerida + 1,
          precioOriginalUnitario: _selectedItems[existingIdx].precioOriginalUnitario,
        );
      } else {
        _selectedItems.add(BundleItemModel(
          id: 0,
          paqueteId: 0,
          productoId: product.product.id,
          presentacionId: product.presentation.id ?? 0,
          cantidadRequerida: 1,
          precioOriginalUnitario: product.effectivePrice,
        ));
      }
      _autoSuggestNameAndPrice();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _selectedItems.removeAt(index);
      if (_selectedItems.isEmpty) {
        if (!_userEditedName) _nameController.clear();
        if (!_userEditedPrice) _priceController.clear();
      } else {
        _autoSuggestNameAndPrice();
      }
    });
  }

  void _showAddProductModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final invProv = Provider.of<InventoryProvider>(context);
            
            final filteredCatalog = invProv.items.where((p) {
              return p.product.nombre.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                     (p.presentation.codigoBarras?.contains(_searchQuery) ?? false);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Agregar Producto", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      labelText: "Buscar en catálogo",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2C2C3E) : Colors.grey[100],
                    ),
                    onChanged: (v) => setModalState(() => _searchQuery = v),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredCatalog.length,
                      itemBuilder: (context, i) {
                        final p = filteredCatalog[i];
                        final isAlreadyAdded = _selectedItems.any((item) => item.presentacionId == p.presentation.id);
                        
                        final displayName = (p.product.marcaNombre != null && p.product.marcaNombre!.isNotEmpty && p.product.marcaNombre!.toLowerCase() != 'sin marca' ? '${p.product.marcaNombre} ' : '') + 
                                            p.product.nombre + 
                                            (p.presentation.nombreEspecifico != null && p.presentation.nombreEspecifico!.isNotEmpty ? ' - ${p.presentation.nombreEspecifico}' : '');
                        final unidadVenta = p.presentation.unidadVenta ?? 'Unidad';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue[50],
                              backgroundImage: p.presentation.imagenUrl != null ? NetworkImage(p.presentation.imagenUrl!) : null,
                              child: p.presentation.imagenUrl == null ? const Icon(Icons.inventory_2, color: Colors.blue) : null,
                            ),
                            title: Text(
                              displayName,
                              maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                                      child: Text(unidadVenta, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text("Stock: ${p.presentation.stockActual} | Venta: ${_currency.format(p.effectivePrice)}"),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: isAlreadyAdded 
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : IconButton(
                                  icon: const Icon(Icons.add_circle, color: Colors.blue, size: 28),
                                  onPressed: () {
                                    _addItem(p);
                                    CustomSnackBar.show(context, message: "Agregado al paquete", isError: false);
                                    setModalState(() {});
                                    setState((){});
                                  },
                                ),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            );
          }
        );
      }
    ).whenComplete(() {
      setState(() => _searchQuery = "");
    });
  }

  Color _getProfitabilityColor(double price, double cost, bool isDark) {
    if (price <= 0 || cost <= 0) return Colors.grey;
    double margin = (price - cost) / price;
    if (margin < 0.10) return isDark ? Colors.red[300]! : Colors.red;
    if (margin < 0.25) return isDark ? Colors.orange[300]! : Colors.orange;
    return isDark ? Colors.green[300]! : Colors.green;
  }

  static const _promoTypes = [
    {'id': 'paquete', 'icon': Icons.inventory_2, 'label': 'Paquete Fusión', 'color': Colors.blue, 'desc': 'Combina productos complementarios a precio especial. Aumenta el ticket promedio.'},
    {'id': 'flash', 'icon': Icons.bolt, 'label': 'Oferta Flash', 'color': Colors.amber, 'desc': 'Descuento agresivo por tiempo limitado. Ideal para fechas escolares. Requiere fecha de fin.'},
    {'id': 'liquidez_costo', 'icon': Icons.water_drop, 'label': 'Liquidez', 'color': Colors.cyan, 'desc': 'Venta al costo para recuperar capital. Ideal para productos sin rotación.'},
    {'id': '2x1', 'icon': Icons.exposure_plus_2, 'label': '2x1', 'color': Colors.green, 'desc': 'El cliente paga 1 y lleva 2. Se ajusta la cantidad mínima a 2 unidades automáticamente.'},
    {'id': 'volumen', 'icon': Icons.shopping_cart, 'label': 'Mayoreo', 'color': Colors.deepPurple, 'desc': 'Descuento por comprar +3 unidades del mismo producto. Ideal para ventas al por mayor.'},
    {'id': 'escolar', 'icon': Icons.school, 'label': 'Pack Escolar', 'color': Colors.teal, 'desc': 'Agrupación estacional de útiles esenciales para la vuelta a clases a precio competitivo.'},
  ];

  Widget _buildPromoTypeSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Tipo de Promoción", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _promoTypes.map((t) {
            final isSelected = _tipoPromocion == t['id'];
            final accentColor = t['color'] as Color;
            return LayoutBuilder(
              builder: (context, constraints) {
                double w = (MediaQuery.of(context).size.width - 48) / 3;
                if (MediaQuery.of(context).size.width > 600) w = 150;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _tipoPromocion = t['id'] as String;
                      _userEditedPrice = false; // Permitir recálculo al cambiar tipo
                      _applyPromoRules();
                    });
                    _autoSuggestNameAndPrice();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    width: w,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? accentColor.withValues(alpha: 0.15) : (isDark ? const Color(0xFF23232F) : Colors.grey[50]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? accentColor : (isDark ? Colors.white12 : Colors.grey.shade300),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected ? [BoxShadow(color: accentColor.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))] : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t['icon'] as IconData, color: isSelected ? accentColor : Colors.grey, size: 26),
                    const SizedBox(height: 6),
                    Text(
                      t['label'] as String,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? accentColor : (isDark ? Colors.white60 : Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            );
            });
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Tarjeta informativa del tipo seleccionado
        Builder(builder: (ctx) {
          final current = _promoTypes.firstWhere((t) => t['id'] == _tipoPromocion, orElse: () => _promoTypes.first);
          final accentColor = current['color'] as Color;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey(_tipoPromocion),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: accentColor),
                  const SizedBox(width: 10),
                  Expanded(child: Text(current['desc'] as String, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 12.5, height: 1.4))),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDateLimits(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Duración de la Campaña", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width > 500 ? (MediaQuery.of(context).size.width - 44) / 2 : double.infinity,
              child: InkWell(
                onTap: () async {
                  final date = await showDatePicker(context: context, initialDate: _fechaInicio ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                  if (date != null) setState(() => _fechaInicio = date);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(_fechaInicio != null ? DateFormat('dd/MM/yyyy').format(_fechaInicio!) : 'Inicio', style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width > 500 ? (MediaQuery.of(context).size.width - 44) / 2 : double.infinity,
              child: InkWell(
                onTap: () async {
                  final date = await showDatePicker(context: context, initialDate: _fechaFin ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                  if (date != null) setState(() => _fechaFin = date);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.event_busy, size: 16, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Text(_fechaFin != null ? DateFormat('dd/MM/yyyy').format(_fechaFin!) : 'Fin (Opcional)', style: const TextStyle(fontSize: 14)),
                      if (_fechaFin != null) ...[
                        const Spacer(),
                        InkWell(
                          onTap: () => setState(() => _fechaFin = null),
                          child: const Icon(Icons.close, size: 16, color: Colors.grey),
                        )
                      ]
                    ],
                  ),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }

  void _showInfoTooltip(BuildContext context, String title, String message, IconData icon) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            CircleAvatar(radius: 32, backgroundColor: Colors.blue.withValues(alpha: 0.1), child: Icon(icon, size: 32, color: Colors.blue)),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.pop(context),
                child: const Text("Entendido", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final invProv = Provider.of<InventoryProvider>(context);

    double currentPrice = double.tryParse(_priceController.text) ?? 0.0;
    double cost = _totalBaseCost;
    double originalValue = _totalOriginalPrice;
    
    Color profitColor = _getProfitabilityColor(currentPrice, cost, isDark);
    double margin = currentPrice > 0 ? (currentPrice - cost) / currentPrice : 0;
    double savings = originalValue > 0 ? ((originalValue - currentPrice) / originalValue) : 0;
    
    String emojiStatus = "⚪";
    String textStatus = "Define un precio";
    if (currentPrice > 0) {
       if (margin < 0.10) { emojiStatus = "🔴"; textStatus = margin < 0 ? "¡Pérdida!" : "Riesgo / Al costo"; }
       else if (margin < 0.25) { emojiStatus = "🟡"; textStatus = "Margen ajustado"; }
       else { emojiStatus = "🟢"; textStatus = "Buen margen"; }
    }

    final currentPromo = _promoTypes.firstWhere((t) => t['id'] == _tipoPromocion, orElse: () => _promoTypes.first);
    final promoColor = currentPromo['color'] as Color;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bundleToEdit == null ? "Nuevo Paquete" : "Editar Paquete"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check), 
            onPressed: _saveBundle,
            tooltip: "Guardar",
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // BASIC INFO SECTION
            _buildPromoTypeSelector(isDark),
            const SizedBox(height: 24),
            _buildDateLimits(isDark),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Información del Paquete", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isActive ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isActive ? Colors.green.withValues(alpha: 0.5) : Colors.grey)
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Activo", style: TextStyle(fontWeight: FontWeight.bold, color: _isActive ? Colors.green : Colors.grey, fontSize: 12)),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                          activeTrackColor: Colors.green.withValues(alpha: 0.5),
                          activeThumbColor: Colors.green,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Nombre del Paquete", border: OutlineInputBorder(), prefixIcon: Icon(Icons.card_giftcard)),
              validator: (v) => v!.isEmpty ? "Requerido" : null,
              onChanged: (_) { _userEditedName = true; },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: "Descripción corta (Opcional)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.notes)),
              maxLines: 2,
              onChanged: (_) { _userEditedDesc = true; },
            ),
            const SizedBox(height: 16),
            // HERO PRICE CARD
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    promoColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    promoColor.withValues(alpha: isDark ? 0.05 : 0.02)
                  ]
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: promoColor.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(color: promoColor.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 6))
                ]
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: promoColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12)
                        ),
                        child: Text("PRECIO DE VENTA", style: TextStyle(color: promoColor, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                      if (savings > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12)
                          ),
                          child: Text("Ahorro ${(savings * 100).toStringAsFixed(0)}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text("S/ ", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "0.00",
                            isDense: true,
                            contentPadding: EdgeInsets.zero
                          ),
                          onChanged: (v) {
                            _userEditedPrice = true;
                            setState((){});
                          },
                        ),
                      ),
                      Icon(Icons.edit, color: promoColor.withValues(alpha: 0.5), size: 24),
                    ],
                  ),
                  if (originalValue > 0) ...[
                    const SizedBox(height: 4),
                    Text("Valor Original: ${_currency.format(originalValue)}", style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 14)),
                  ],
                  const SizedBox(height: 12),
                  TextButton.icon(
                    icon: Icon(Icons.autorenew, size: 16, color: promoColor),
                    label: Text("Recalcular sugerido", style: TextStyle(color: promoColor, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      backgroundColor: promoColor.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    onPressed: () {
                      _userEditedPrice = false;
                      _autoSuggestNameAndPrice();
                      setState(() {});
                      CustomSnackBar.show(context, message: "Precio recalculado", isError: false);
                    },
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // HEATMAP RENTABILIDAD
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Flexible(child: Text("Análisis de Rentabilidad", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _showInfoTooltip(context, "Rentabilidad y Margen", "El margen indica el porcentaje de ganancia sobre el precio de venta final.\n\nEvita márgenes por debajo del 10% (rojo) para no incurrir en pérdidas luego de gastos operativos.", Icons.analytics),
                      child: const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.water_drop, size: 14),
                  label: const Text("Al Costo", overflow: TextOverflow.ellipsis),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    setState(() {
                      _priceController.text = cost.toStringAsFixed(2);
                      _userEditedPrice = true;
                    });
                    CustomSnackBar.show(context, message: "Precio igualado al costo total", isError: false);
                  },
                )
              ],
            ),
            const SizedBox(height: 8),
            if (margin < 0)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(child: Text("Estás vendiendo por debajo del costo base. Obtendrás pérdidas.", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13))),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: profitColor.withValues(alpha: 0.1), 
                borderRadius: BorderRadius.circular(16), 
                border: Border.all(color: profitColor.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [BoxShadow(color: profitColor.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text("Costo Base", style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                           Text(_currency.format(cost), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                         ],
                       ),
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.end,
                         children: [
                           Text("Margen / Rentabilidad", style: TextStyle(fontSize: 13, color: profitColor, fontWeight: FontWeight.bold)),
                           Text(
                             currentPrice > 0 ? "${(margin * 100).toStringAsFixed(1)}%" : "0.0%", 
                             style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: profitColor)
                           ),
                         ],
                       )
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: currentPrice > 0 ? margin.clamp(0.0, 1.0) : 0,
                      minHeight: 10,
                      backgroundColor: isDark ? Colors.black26 : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(profitColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Row(
                         children: [
                           Text(emojiStatus, style: const TextStyle(fontSize: 16)),
                           const SizedBox(width: 6),
                           Text(textStatus, style: TextStyle(fontWeight: FontWeight.bold, color: profitColor)),
                         ],
                       ),
                       if (savings > 0 && currentPrice > 0)
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                           decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                           child: Text("El cliente ahorra ${(savings * 100).toStringAsFixed(1)}%", style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                         )
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // CONTENT SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 const Text("Contenido del Paquete", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                 TextButton.icon(
                   onPressed: _showAddProductModal, 
                   icon: const Icon(Icons.add_circle, color: Colors.blue), 
                   label: const Text("Agregar", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))
                 )
              ],
            ),
            const SizedBox(height: 8),
            
            if (_selectedItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(32), 
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF23232F) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!, style: BorderStyle.solid)
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text("El paquete está vacío", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("Agrega los productos que conformarán esta oferta.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    ],
                  )
                )
              ),
            
            ..._selectedItems.asMap().entries.map((entry) {
              int idx = entry.key;
              var item = entry.value;
              final prodWrap = invProv.items.where((p) => p.presentation.id == item.presentacionId).firstOrNull;
              
              if (prodWrap == null) {
                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isDark ? Colors.red.withValues(alpha: 0.1) : Colors.red[50],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.withValues(alpha: 0.3))),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 36),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Producto no disponible", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 15)),
                              Text("Este producto fue eliminado del inventario.", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeItem(idx),
                        )
                      ],
                    ),
                  )
                );
              }

              final String fullName = (prodWrap.product.marcaNombre != null && prodWrap.product.marcaNombre!.isNotEmpty && prodWrap.product.marcaNombre!.toLowerCase() != 'sin marca' ? '${prodWrap.product.marcaNombre} ' : '') + 
                                      prodWrap.product.nombre + 
                                      (prodWrap.presentation.nombreEspecifico != null && prodWrap.presentation.nombreEspecifico!.isNotEmpty ? ' - ${prodWrap.presentation.nombreEspecifico}' : '');

              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 50, height: 50,
                          color: isDark ? Colors.white10 : Colors.grey[200],
                          child: prodWrap.presentation.imagenUrl != null 
                              ? UniversalImage(path: prodWrap.presentation.imagenUrl, width: 50, height: 50, fit: BoxFit.cover)
                              : const Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName, 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), 
                              maxLines: 2, 
                              overflow: TextOverflow.ellipsis
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inventory_2_rounded, size: 12, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  prodWrap.presentation.unidadVenta ?? "UND", 
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  "Costo: ${_currency.format(prodWrap.presentation.costoUnitarioCalculado ?? 0)}", 
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500])
                                ),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(color: Colors.grey[400], shape: BoxShape.circle),
                                ),
                                Text(
                                  "Normal: ${_currency.format(prodWrap.effectivePrice)}", 
                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.blue[300] : Colors.blue[700], fontWeight: FontWeight.w600)
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C3E) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(30)
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 20), 
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                if (item.cantidadRequerida > 1) {
                                  setState(() {
                                    _selectedItems[idx] = BundleItemModel(id: item.id, paqueteId: item.paqueteId, productoId: item.productoId, presentacionId: item.presentacionId, cantidadRequerida: item.cantidadRequerida - 1, precioOriginalUnitario: item.precioOriginalUnitario);
                                    _autoSuggestNameAndPrice();
                                  });
                                } else {
                                  _removeItem(idx);
                                }
                              }
                            ),
                            Text("${item.cantidadRequerida}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(
                               icon: const Icon(Icons.add, size: 20), 
                               constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                               padding: EdgeInsets.zero,
                               onPressed: () {
                                  setState(() {
                                    _selectedItems[idx] = BundleItemModel(id: item.id, paqueteId: item.paqueteId, productoId: item.productoId, presentacionId: item.presentacionId, cantidadRequerida: item.cantidadRequerida + 1, precioOriginalUnitario: item.precioOriginalUnitario);
                                    _autoSuggestNameAndPrice();
                                  });
                               }
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            
            const SizedBox(height: 100), // Padding extra al final
          ],
        ),
      ),
      floatingActionButton: _selectedItems.isNotEmpty ? FloatingActionButton.extended(
        onPressed: _saveBundle,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.save, color: Colors.white),
        label: Text(widget.bundleToEdit == null ? "Guardar Paquete" : "Actualizar Paquete", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
