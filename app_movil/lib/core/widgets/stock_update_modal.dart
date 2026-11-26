import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/screens/product_edit_screen.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

part 'stock_update/stock_update_shared_banners.dart';
part 'stock_update/stock_update_own_mode_controls.dart';
part 'stock_update/stock_update_stepper_and_preview.dart';

class StockUpdateModal extends StatefulWidget {
  final ProductPresentation presentation;
  final InventoryProvider provider;
  final bool isDark;

  const StockUpdateModal({
    super.key,
    required this.presentation,
    required this.provider,
    required this.isDark,
  });

  /// Despliegue con InteractiveSheetWrapper (Swipe down to dismiss)
  static Future<bool?> show({
    required BuildContext context,
    required ProductPresentation presentation,
    required InventoryProvider provider,
    required bool isDark,
  }) {
    return InteractiveSheetWrapper.show<bool>(
      context: context,
      builder: (ctx) => StockUpdateModal(
        presentation: presentation,
        provider: provider,
        isDark: isDark,
      ),
    );
  }

  @override
  State<StockUpdateModal> createState() => _StockUpdateModalState();
}

class _StockUpdateModalState extends State<StockUpdateModal> {
  // Modo: 0 = Sumar mercancía recibida, 1 = Fijar stock total, 2 = Cupo vendible (stock compartido)
  int _selectedMode = 1;

  late TextEditingController ctrl;
  bool _isSaving = false;
  late int _currentStockBase;

  bool _showExcessWarning = false;
  Timer? _warningTimer;

  bool get _isShared => widget.presentation.usaStockCompartido;

  Product? get _parentProduct {
    for (final item in widget.provider.items) {
      if (item.presentation.id == widget.presentation.id) {
        return item.product;
      }
    }
    return null;
  }

  int get _factor => widget.presentation.unidadesPorVenta > 0
      ? widget.presentation.unidadesPorVenta
      : 1;

  String get _unidadVenta => widget.presentation.unidadVenta ?? 'Unidad';

  bool get _hasFactor => _factor > 1;

  int get _poolBaseUnits {
    if (_isShared) {
      final p = _parentProduct;
      if (p != null) {
        return p.stockCompartido > 0
            ? p.stockCompartido
            : (widget.presentation.stockActual > 0
                  ? widget.presentation.stockActual
                  : p.stockCompartido);
      }
      return widget.presentation.stockActual;
    }
    return _currentStockBase;
  }

  int get _maxPhysicalUnits => _poolBaseUnits ~/ _factor;
  int get _currentStockSalesUnits => _currentStockBase ~/ _factor;
  int get _currentStockRemainder => _currentStockBase % _factor;
  int get _parsedInput => int.tryParse(ctrl.text.trim()) ?? 0;

  int get _calculatedNewStockBase {
    if (_isShared) return _poolBaseUnits;
    if (_selectedMode == 0) {
      return _currentStockBase + (_parsedInput * _factor);
    }
    return _parsedInput * _factor;
  }

  int get _calculatedNewStockSalesUnits => _calculatedNewStockBase ~/ _factor;

  void _refreshState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _currentStockBase = widget.presentation.stockActual;

    if (_isShared) {
      _selectedMode = 2;
      final currentVendible = widget.presentation.unidadesVendiblesDisponibles;
      ctrl = TextEditingController(text: currentVendible.toString());
    } else {
      final initialStock = _selectedMode == 0 ? 1 : _currentStockSalesUnits;
      ctrl = TextEditingController(text: initialStock.toString());
    }

    ctrl.addListener(() => _refreshState(() {}));
  }

  @override
  void dispose() {
    _warningTimer?.cancel();
    ctrl.dispose();
    super.dispose();
  }

  void _triggerExcessWarning() {
    HapticFeedback.heavyImpact();
    _warningTimer?.cancel();
    setState(() {
      _showExcessWarning = true;
    });
    _warningTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showExcessWarning = false;
        });
      }
    });
  }

  void _onModeChanged(int mode) {
    if (_isShared || _selectedMode == mode) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMode = mode;
      ctrl.text = mode == 0 ? "1" : _currentStockSalesUnits.toString();
    });
  }

  void _squareStock() {
    if (_isShared) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _currentStockBase = (_currentStockBase ~/ _factor) * _factor;
      if (_selectedMode == 1) {
        ctrl.text = (_currentStockBase ~/ _factor).toString();
      }
    });
  }

  void _navigateToEdit() {
    final nav = Navigator.of(context);
    nav.pop();
    final Product? targetProduct = _parentProduct;
    if (targetProduct != null) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => ProductEditScreen(
            productToEdit: targetProduct,
            initialPresentationId: widget.presentation.id,
          ),
        ),
      );
    }
  }

  void _update(int val) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_isShared) {
        if (val > _maxPhysicalUnits) {
          _triggerExcessWarning();
          val = _maxPhysicalUnits;
        } else if (val < 0) {
          val = 0;
        }
        ctrl.text = val.toString();
      } else {
        if (_selectedMode == 0) {
          ctrl.text = val < 1 ? "1" : val.toString();
        } else {
          ctrl.text = val < 0 ? "0" : val.toString();
        }
      }
    });
  }

  void _addQuickAmount(int amount) {
    _update(_parsedInput + amount);
  }

  Widget _buildHeader(Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (widget.isDark ? Colors.blue[300]! : Colors.blue[800]!)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _isShared ? Icons.tune_rounded : Icons.inventory_2_outlined,
                  color: widget.isDark ? Colors.blue[300] : Colors.blue[800],
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _isShared
                        ? "Ajustar Stock Disponible"
                        : "Abastecer / Editar Stock",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(
            Icons.close,
            color: widget.isDark ? Colors.grey[500] : Colors.grey,
          ),
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    final int resultingBase = _calculatedNewStockBase;
    final int resultingSalesUnits = _isShared
        ? _parsedInput
        : _calculatedNewStockSalesUnits;

    final bool isOutOfStock = resultingSalesUnits <= 0;
    final bool isCritical =
        resultingSalesUnits > 0 &&
        resultingSalesUnits <= (widget.presentation.stockAlerta ?? 5);

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.94,
      backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
      applyEffectiveBottomPadding: true,
      bottomAction: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isDark
                ? Colors.blue[300]
                : Colors.blue[800],
            foregroundColor: widget.isDark ? Colors.black87 : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          onPressed: _isSaving
              ? null
              : () async {
                  setState(() => _isSaving = true);
                  bool ok;
                  if (_isShared) {
                    final int newQuota = _parsedInput;
                    final int? quotaToSave = newQuota >= _maxPhysicalUnits
                        ? null
                        : newQuota;
                    ok = await widget.provider.updateVariantQuota(
                      widget.presentation.id!,
                      quotaToSave,
                    );
                  } else {
                    ok = await widget.provider.updatePresentation(
                      widget.presentation.id!,
                      stock: resultingBase,
                    );
                  }
                  if (context.mounted) Navigator.pop(context, ok);
                },
          child: _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text(
                  "APLICAR CAMBIOS",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, isKeyboardOpen ? 8 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(textColor),
            const SizedBox(height: 12),
            if (_isShared)
              _buildSharedStockSection(isDark)
            else
              _buildOwnStockModeSection(isDark),
            SizedBox(height: isKeyboardOpen ? 12 : 18),
            _buildStepperAndChips(isDark),
            const SizedBox(height: 16),
            _buildResultPreviewCard(
              isDark: isDark,
              isOutOfStock: isOutOfStock,
              isCritical: isCritical,
              resultingBase: resultingBase,
              resultingSalesUnits: resultingSalesUnits,
            ),
          ],
        ),
      ),
    );
  }
}
