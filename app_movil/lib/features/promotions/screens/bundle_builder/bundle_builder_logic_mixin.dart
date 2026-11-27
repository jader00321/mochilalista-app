part of '../bundle_builder_screen.dart';

mixin _BundleBuilderLogicMixin on _BundleBuilderScreenStateBase {
  Future<void> _saveBundle() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItems.isEmpty) {
      AppFeedbackHelper.showError(
        context,
        "Agrega al menos un producto al paquete",
      );
      return;
    }

    if (_tipoPromocion == 'flash' && _fechaFin == null) {
      AppFeedbackHelper.showError(
        context,
        "Las ofertas Flash deben tener una fecha de fin obligatoria",
      );
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
        AppFeedbackHelper.showSuccess(context, "Paquete guardado exitosamente");
      }
    } catch (e) {
      if (mounted) {
        AppFeedbackHelper.showError(context, "Error al guardar: $e");
      }
    }
  }

  /// Genera un nombre corto para un producto (máx 3 palabras significativas)
  String _shortName(InventoryWrapper wrap) {
    final String name = wrap.product.nombre;
    final words = name.split(' ').where((w) => w.length > 2).take(3).toList();
    return words.isNotEmpty ? words.join(' ') : name;
  }

  /// Genera el nombre completo con marca y presentación
  String _fullName(InventoryWrapper wrap) {
    String full = wrap.product.nombre;
    if (wrap.product.marcaNombre != null &&
        wrap.product.marcaNombre!.isNotEmpty &&
        wrap.product.marcaNombre!.toLowerCase() != 'sin marca') {
      full = "${wrap.product.marcaNombre} $full";
    }
    if (wrap.presentation.nombreEspecifico != null &&
        wrap.presentation.nombreEspecifico!.isNotEmpty) {
      full += " - ${wrap.presentation.nombreEspecifico}";
    }
    return full;
  }

  @override
  void _autoSuggestNameAndPrice() {
    if (_selectedItems.isEmpty) return;

    final inv = Provider.of<InventoryProvider>(context, listen: false);

    if (!_userEditedName) {
      final List<String> shortNames = [];
      for (var item in _selectedItems.take(3)) {
        try {
          final prod = inv.items.firstWhere(
            (p) => p.presentation.id == item.presentacionId,
          );
          shortNames.add(_shortName(prod));
        } catch (_) {}
      }
      if (shortNames.isNotEmpty) {
        final String prefix;
        switch (_tipoPromocion) {
          case 'liquidez_costo':
            prefix = "Liquidez: ";
            break;
          case 'flash':
            prefix = "⚡ Flash: ";
            break;
          case '2x1':
            prefix = "2x1: ";
            break;
          case 'volumen':
            prefix = "Mayoreo: ";
            break;
          case 'escolar':
            prefix = "🎒 Pack Escolar: ";
            break;
          default:
            prefix = "Pack ";
            break;
        }
        String joined = shortNames.take(2).join(' + ');
        if (_selectedItems.length > 2) joined += " y más";
        _nameController.text = prefix + joined;
      }
    }

    if (!_userEditedDesc) {
      final List<String> fullNames = [];
      for (var item in _selectedItems) {
        try {
          final prod = inv.items.firstWhere(
            (p) => p.presentation.id == item.presentacionId,
          );
          fullNames.add("${_fullName(prod)} (x${item.cantidadRequerida})");
        } catch (_) {}
      }
      if (fullNames.isNotEmpty) {
        _descController.text = "Incluye: ${fullNames.join(', ')}";
      }
    }

    if (!_userEditedPrice) {
      final double totalOriginal = _totalOriginalPrice;
      final double totalCost = _totalBaseCost;
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
            double maxPrice = 0;
            for (var item in _selectedItems) {
              try {
                final prod = inv.items.firstWhere(
                  (p) => p.presentation.id == item.presentacionId,
                );
                if (prod.effectivePrice > maxPrice) {
                  maxPrice = prod.effectivePrice;
                }
              } catch (_) {}
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

    if (mounted) setState(() {});
  }

  /// Aplica reglas automáticas inteligentes al cambiar tipo de promoción
  @override
  void _applyPromoRules() {
    if (_selectedItems.isEmpty) return;

    if (_tipoPromocion == '2x1') {
      if (_selectedItems.length == 1 &&
          _selectedItems[0].cantidadRequerida < 2) {
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
      final int totalQty = _selectedItems.fold(
        0,
        (sum, i) => sum + i.cantidadRequerida,
      );
      if (totalQty < 3 && _selectedItems.isNotEmpty) {
        final int needed = 3 - totalQty + _selectedItems[0].cantidadRequerida;
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

  @override
  void _addItem(InventoryWrapper product) {
    setState(() {
      final existingIdx = _selectedItems.indexWhere(
        (i) => i.presentacionId == product.presentation.id,
      );
      if (existingIdx >= 0) {
        _selectedItems[existingIdx] = BundleItemModel(
          id: _selectedItems[existingIdx].id,
          paqueteId: _selectedItems[existingIdx].paqueteId,
          productoId: _selectedItems[existingIdx].productoId,
          presentacionId: _selectedItems[existingIdx].presentacionId,
          cantidadRequerida: _selectedItems[existingIdx].cantidadRequerida + 1,
          precioOriginalUnitario:
              _selectedItems[existingIdx].precioOriginalUnitario,
        );
      } else {
        _selectedItems.add(
          BundleItemModel(
            id: 0,
            paqueteId: 0,
            productoId: product.product.id,
            presentacionId: product.presentation.id ?? 0,
            cantidadRequerida: 1,
            precioOriginalUnitario: product.effectivePrice,
          ),
        );
      }
      _autoSuggestNameAndPrice();
    });
  }

  @override
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

  Color _getProfitabilityColor(double price, double cost, bool isDark) {
    if (price <= 0 || cost <= 0) return Colors.grey;
    final double margin = (price - cost) / price;
    if (margin < 0.10) return isDark ? Colors.red[300]! : Colors.red;
    if (margin < 0.25) return isDark ? Colors.orange[300]! : Colors.orange;
    return isDark ? Colors.green[300]! : Colors.green;
  }
}
