import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/core/widgets/full_screen_image_viewer.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/catalog/screens/product_detail_screen.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

class ProductDetailModal extends StatefulWidget {
  final InventoryWrapper item;
  final void Function(int quantity, [ProductPresentation? presentation])
  onAddToCart;
  final void Function(int quantity, [ProductPresentation? presentation])
  onAddToList;
  final bool isStoreMode;

  const ProductDetailModal({
    super.key,
    required this.item,
    required this.onAddToCart,
    required this.onAddToList,
    this.isStoreMode = false,
  });

  /// 🏆 Despliegue seguro con InteractiveSheetWrapper (Swipe down to dismiss + Blindaje BUG-07)
  static Future<void> show(
    BuildContext context, {
    required InventoryWrapper item,
    required void Function(int quantity, [ProductPresentation? presentation])
    onAddToCart,
    required void Function(int quantity, [ProductPresentation? presentation])
    onAddToList,
    bool isStoreMode = false,
  }) {
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (_) => ProductDetailModal(
        item: item,
        onAddToCart: onAddToCart,
        onAddToList: onAddToList,
        isStoreMode: isStoreMode,
      ),
    );
  }

  @override
  State<ProductDetailModal> createState() => _ProductDetailModalState();
}

class _ProductDetailModalState extends State<ProductDetailModal> {
  int _quantity = 1;
  late ProductPresentation _currentPres;
  late int _maxStock;
  bool _showVariantSelector = false;

  int _computeMaxStock(ProductPresentation pres) {
    final int factor = pres.unidadesPorVenta <= 0 ? 1 : pres.unidadesPorVenta;
    final int physical = pres.stockActual ~/ factor;
    if (pres.usaStockCompartido && pres.cupoMaximoVariante != null) {
      return pres.cupoMaximoVariante! < physical
          ? pres.cupoMaximoVariante!
          : physical;
    }
    return physical;
  }

  @override
  void initState() {
    super.initState();
    _currentPres = widget.item.presentation;
    _maxStock = _computeMaxStock(_currentPres);
  }

  void _selectPresentation(ProductPresentation pres) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentPres = pres;
      _maxStock = _computeMaxStock(pres);
      if (_quantity > _maxStock) {
        _quantity = _maxStock > 0 ? _maxStock : 1;
      }
    });
  }

  void _increment() {
    if (_quantity < _maxStock) {
      setState(() => _quantity++);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Stock máximo disponible: $_maxStock",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orange[800],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _decrement() {
    if (_quantity > 1) {
      setState(() => _quantity--);
    }
  }

  String _pluralize(String unit, int qty) {
    if (qty == 1) return unit;
    final lower = unit.toLowerCase();
    // Palabras terminadas en 'z' -> 'ces' (ej. Pez -> Peces, Lápiz -> Lápices)
    if (lower.endsWith('z')) {
      return "${unit.substring(0, unit.length - 1)}ces";
    }
    // Palabras terminadas en 'd' (ej. Unidad -> Unidades), 'r', 'n', 'l', 'j' -> 'es'
    if (lower.endsWith('d') ||
        lower.endsWith('r') ||
        lower.endsWith('n') ||
        lower.endsWith('l') ||
        lower.endsWith('j')) {
      return "${unit}es";
    }
    // Palabras terminadas en 'k' (ej. Pack -> Packs), 't', 'p' o vocales -> 's'
    return "${unit}s";
  }

  String _formatQuantityUnit(String rawUnit, int quantity, int factor) {
    final unit = rawUnit.trim().isEmpty ? 'Unidad' : rawUnit.trim();
    if (factor > 1) {
      final totalBase = quantity * factor;
      final unitPlural = _pluralize(unit, quantity);
      return "($quantity $unitPlural · $totalBase u.)";
    }
    if (unit.toLowerCase() == 'unidad') {
      return "($quantity un.)";
    }
    final unitPlural = _pluralize(unit, quantity);
    return "($quantity $unitPlural)";
  }

  @override
  Widget build(BuildContext context) {
    final catalogProv = Provider.of<CatalogProvider?>(context, listen: false);
    final auth = Provider.of<AuthProvider?>(context, listen: false);
    final isClient = auth?.isCommunityClient ?? false;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textTheme = theme.textTheme;

    final prod = widget.item.product;
    final brandName = catalogProv?.getBrandName(prod.marcaId) ?? '';

    final bool isOutOfStock = _maxStock <= 0;
    final bool hasOffer = _currentPres.hasOffer;
    final double unitPrice = _currentPres.effectivePrice;
    final double subtotal = unitPrice * _quantity;

    final String imageUrl = _currentPres.imagenUrl ?? prod.imagenUrl ?? "";
    final String imageTag = "modal_cat_${_currentPres.id}";

    double totalSavings = 0;
    if (hasOffer) {
      totalSavings = (_currentPres.precioVentaFinal - unitPrice) * _quantity;
    }

    final String variantDisplay = _currentPres.unidadVenta ?? "Unidad";
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    // 🔥 CÁLCULO FINANCIERO FACTOR-AWARE (FASE 2)
    final int factorVenta = _currentPres.unidadesPorVenta <= 0
        ? 1
        : _currentPres.unidadesPorVenta;
    final double costoPresentacion = _currentPres.costoPresentacionFinal;
    final bool tieneCosto = costoPresentacion > 0;
    final double costoUnitarioBase = tieneCosto
        ? (costoPresentacion / factorVenta)
        : 0.0;
    final double gananciaUnitaria = tieneCosto
        ? (unitPrice - costoPresentacion)
        : 0.0;
    final double gananciaTotal = gananciaUnitaria * _quantity;
    final double margenPorcentual = (tieneCosto && unitPrice > 0)
        ? ((unitPrice - costoPresentacion) / unitPrice * 100)
        : 0.0;
    final String qtyLabel = _formatQuantityUnit(
      variantDisplay,
      _quantity,
      factorVenta,
    );

    // Semáforo de Rentabilidad
    final Color profitColor;
    final Color profitBg;
    final IconData profitIcon;
    final String profitLabel;

    if (!tieneCosto) {
      profitColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
      profitBg = isDark ? Colors.white10 : Colors.grey.shade100;
      profitIcon = Icons.help_outline_rounded;
      profitLabel = "Sin costo";
    } else if (margenPorcentual >= 30) {
      profitColor = isDark ? Colors.green[400]! : const Color(0xFF2E7D32);
      profitBg = isDark
          ? Colors.green.withValues(alpha: 0.15)
          : const Color(0xFFE8F5E9);
      profitIcon = Icons.trending_up_rounded;
      profitLabel = "Excelente";
    } else if (margenPorcentual >= 15) {
      profitColor = isDark ? Colors.amber[300]! : const Color(0xFFE65100);
      profitBg = isDark
          ? Colors.amber.withValues(alpha: 0.15)
          : const Color(0xFFFFF3E0);
      profitIcon = Icons.trending_flat_rounded;
      profitLabel = "Moderado";
    } else {
      profitColor = isDark ? Colors.red[400]! : const Color(0xFFC62828);
      profitBg = isDark
          ? Colors.red.withValues(alpha: 0.15)
          : const Color(0xFFFFEBEE);
      profitIcon = Icons.trending_down_rounded;
      profitLabel = "Bajo";
    }

    final hasMultiplePresentations = prod.presentaciones.length > 1;

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.92,
      backgroundColor: surfaceColor,
      applyEffectiveBottomPadding: false,
      bottomAction: isOutOfStock
          ? null
          : (isClient
                ? SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        widget.onAddToList(_quantity, _currentPres);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.orange[700]
                            : Colors.orange[800],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: isDark ? 0 : 4,
                      ),
                      icon: const Icon(Icons.playlist_add, size: 24),
                      label: const Text(
                        "AGREGAR A MI PEDIDO",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              widget.onAddToList(_quantity, _currentPres);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? const Color(0xFF2E2010)
                                  : const Color(0xFFFFF3E0),
                              foregroundColor: isDark
                                  ? Colors.orange[300]
                                  : Colors.orange[800],
                              side: BorderSide(
                                color: isDark
                                    ? Colors.orange[400]!
                                    : Colors.orange,
                                width: 2,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.playlist_add, size: 24),
                            label: const Text(
                              "A LA LISTA",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              widget.onAddToCart(_quantity, _currentPres);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? Colors.green[700]
                                  : const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              elevation: isDark ? 0 : 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.shopping_cart, size: 22),
                            label: const Text(
                              "COMPRAR",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. CABECERA: IMAGEN + TÍTULOS (AISLADO DE LA 'X')
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (imageUrl.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullScreenImageViewer(
                                imageUrl: imageUrl,
                                tag: imageTag,
                              ),
                            ),
                          );
                        }
                      },
                      child: Hero(
                        tag: imageTag,
                        child: Material(
                          type: MaterialType.transparency,
                          child: Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? Colors.transparent
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: UniversalImage(
                                path: imageUrl,
                                productName: prod.nombre,
                                categoryName: catalogProv?.getCategoryName(
                                  prod.categoriaId,
                                ),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // 🔥 Margen derecho de 44dp garantiza 0 colisiones con el botón 'X'
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 44.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (brandName.isNotEmpty)
                              Text(
                                brandName.toUpperCase(),
                                style: textTheme.labelLarge?.copyWith(
                                  color: isDark
                                      ? Colors.indigo[300]
                                      : Colors.indigo[800],
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            const SizedBox(height: 4),

                            RichText(
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: "${prod.nombre} ",
                                    style: textTheme.titleLarge?.copyWith(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                                  ),
                                  if (_currentPres.nombreEspecifico != null &&
                                      _currentPres.nombreEspecifico!.isNotEmpty)
                                    TextSpan(
                                      text: _currentPres.nombreEspecifico!,
                                      style: textTheme.titleLarge?.copyWith(
                                        color: isDark
                                            ? Colors.teal[300]
                                            : Colors.teal[700],
                                        fontWeight: FontWeight.w800,
                                        height: 1.2,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                if (prod.descripcion != null &&
                    prod.descripcion!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    prod.descripcion!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // 2. SELECTOR DE PRESENTACIONES DENTRO DEL MODAL (SI TIENE > 1)
                if (hasMultiplePresentations) ...[
                  InkWell(
                    onTap: () => setState(
                      () => _showVariantSelector = !_showVariantSelector,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.dashboard_customize_outlined,
                                  size: 18,
                                  color: isDark
                                      ? Colors.blue[300]
                                      : Colors.blue[800],
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    "Seleccionar Variante / Presentación",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.blue.withValues(alpha: 0.25)
                                        : Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    "${prod.presentaciones.length}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.blue[200]
                                          : Colors.blue[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _showVariantSelector ? "Ocultar" : "Ver otras",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.blue[300]
                                      : Colors.blue[800],
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                _showVariantSelector
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 18,
                                color: isDark
                                    ? Colors.blue[300]
                                    : Colors.blue[800],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_showVariantSelector) ...[
                    if (prod.hasSharedStock) ...[
                      if (_currentPres.usaStockCompartido) ...[
                        Builder(
                          builder: (ctx) {
                            final pool = prod.stockCompartido > 0
                                ? prod.stockCompartido
                                : _currentPres.stockActual;
                            final factor = _currentPres.unidadesPorVenta > 0
                                ? _currentPres.unidadesPorVenta
                                : 1;
                            final maxPhysical = pool ~/ factor;
                            final cupo = _currentPres.cupoMaximoVariante;
                            final cupoStr = cupo != null
                                ? " · Cupo: $cupo disp."
                                : "";
                            final modoStr = prod.modoStock == 'MIXTO'
                                ? 'Mixto'
                                : 'Compartido';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(
                                        0xFF1E3A8A,
                                      ).withValues(alpha: 0.25)
                                    : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.blue.shade700
                                      : const Color(0xFF93C5FD),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.hub_rounded,
                                    size: 16,
                                    color: isDark
                                        ? Colors.blue[300]
                                        : const Color(0xFF1E40AF),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Pool Base: $pool und. (= máx. $maxPhysical ${_currentPres.unidadVenta ?? 'Und'}$cupoStr) · $modoStr",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.blue[200]
                                            : const Color(0xFF1E40AF),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ] else ...[
                        Builder(
                          builder: (ctx) {
                            final factor = _currentPres.unidadesPorVenta > 0
                                ? _currentPres.unidadesPorVenta
                                : 1;
                            final ownStock = _currentPres.stockActual ~/ factor;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.teal.withValues(alpha: 0.15)
                                    : const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.teal.shade700
                                      : const Color(0xFF86EFAC),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 16,
                                    color: isDark
                                        ? Colors.teal[300]
                                        : const Color(0xFF166534),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "📦 Stock Propio disponible: $ownStock ${_currentPres.unidadVenta ?? 'Und'} · Mixto",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.teal[200]
                                            : const Color(0xFF166534),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],

                    ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black,
                            Colors.black,
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.94, 1.0],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: prod.presentaciones.map((p) {
                            final isSelected = p.id == _currentPres.id;
                            final specName =
                                (p.nombreEspecifico != null &&
                                    p.nombreEspecifico!.trim().isNotEmpty)
                                ? p.nombreEspecifico!.trim()
                                : (p.esDefault
                                      ? "Principal"
                                      : (p.unidadVenta ?? "Variante"));
                            final factorStr = p.unidadesPorVenta > 1
                                ? " (x${p.unidadesPorVenta})"
                                : "";
                            final vendibleUnits = _computeMaxStock(p);
                            final bool isOutOfStock = vendibleUnits <= 0;

                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: ChoiceChip(
                                label: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          specName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.w900
                                                : FontWeight.bold,
                                            color: isSelected
                                                ? (isDark
                                                      ? Colors.blue[200]
                                                      : Colors.blue[900])
                                                : (isDark
                                                      ? Colors.white
                                                      : Colors.black87),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(width: 5),
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isOutOfStock
                                                ? Colors.red
                                                : (vendibleUnits < 10
                                                      ? Colors.orange
                                                      : Colors.green),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${p.unidadVenta ?? 'Und'}$factorStr · ${AppCurrency.format(p.precioVentaFinal)} · ${isOutOfStock ? 'Agotado' : '$vendibleUnits disp.'}",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isSelected
                                            ? (isDark
                                                  ? Colors.blue[100]
                                                  : Colors.blue[800])
                                            : (isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600]),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                                selected: isSelected,
                                onSelected: (v) =>
                                    v ? _selectPresentation(p) : null,
                                selectedColor: isDark
                                    ? Colors.blue.withValues(alpha: 0.3)
                                    : Colors.blue[100],
                                backgroundColor: isDark
                                    ? Colors.white10
                                    : Colors.grey[100],
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? (isDark
                                            ? Colors.blue[300]
                                            : Colors.blue[900])
                                      : (isDark
                                            ? Colors.grey[300]
                                            : Colors.grey[800]),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],

                // 3. FILA BENTO SIMÉTRICA (3 COLUMNAS: EMPAQUE, PRESENTACIÓN, STOCK)
                Row(
                  children: [
                    Expanded(
                      child: _DetailPill(
                        icon: Icons.inventory_2_outlined,
                        label: "Empaque",
                        value: "$factorVenta u.",
                        color: Colors.blue,
                        isDark: isDark,
                        textTheme: textTheme,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DetailPill(
                        icon: Icons.scale_outlined,
                        label: "Presentación",
                        value: variantDisplay,
                        color: Colors.purple,
                        isDark: isDark,
                        textTheme: textTheme,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DetailPill(
                        icon: isOutOfStock
                            ? Icons.cancel_outlined
                            : Icons.check_circle_outline,
                        label: "Stock",
                        value: isOutOfStock ? "0" : "$_maxStock",
                        color: isOutOfStock ? Colors.grey : Colors.green,
                        isDark: isDark,
                        textTheme: textTheme,
                      ),
                    ),
                  ],
                ),

                // 4. BANDA FINANCIERA FACTOR-AWARE (SOLO MODO VENDEDOR)
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: widget.isStoreMode
                      ? const SizedBox.shrink()
                      : Container(
                          margin: const EdgeInsets.only(top: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1E28)
                                : const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white12
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.query_stats_rounded,
                                          size: 16,
                                          color: isDark
                                              ? Colors.blue[300]
                                              : Colors.blue[800],
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            "DATOS FINANCIEROS",
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                              color: isDark
                                                  ? Colors.blue[300]
                                                  : Colors.blue[800],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: profitBg,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              profitIcon,
                                              size: 14,
                                              color: profitColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              tieneCosto
                                                  ? "${margenPorcentual.toStringAsFixed(1)}% ($profitLabel)"
                                                  : "Sin costo registrado",
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: profitColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          factorVenta > 1
                                              ? "Costo Presentación:"
                                              : "Costo Unitario:",
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          tieneCosto
                                              ? AppCurrency.format(
                                                  costoPresentacion,
                                                )
                                              : "No registrado",
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: tieneCosto
                                                ? textColor
                                                : (isDark
                                                      ? Colors.grey[500]
                                                      : Colors.grey[600]),
                                          ),
                                        ),
                                        if (factorVenta > 1 && tieneCosto)
                                          Text(
                                            "(${AppCurrency.format(costoUnitarioBase)}/u)",
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              color: isDark
                                                  ? Colors.grey[500]
                                                  : Colors.grey[500],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    height: 32,
                                    width: 1,
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.grey.shade300,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Ganancia Neta $qtyLabel:",
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          tieneCosto
                                              ? AppCurrency.format(
                                                  gananciaTotal,
                                                )
                                              : "--",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: !tieneCosto
                                                ? (isDark
                                                      ? Colors.grey[500]
                                                      : Colors.grey[600])
                                                : (gananciaTotal >= 0
                                                      ? (isDark
                                                            ? Colors.green[400]
                                                            : const Color(
                                                                0xFF2E7D32,
                                                              ))
                                                      : (isDark
                                                            ? Colors.red[400]
                                                            : Colors.red[700])),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                ),

                // 5. BOTÓN FICHA COMPLETA (SOLO MODO VENDEDOR)
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  child: widget.isStoreMode
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              icon: Icon(
                                Icons.open_in_new,
                                size: 16,
                                color: isDark
                                    ? Colors.blue[300]
                                    : Colors.blue[800],
                              ),
                              label: Text(
                                "Ver Ficha Completa de Producto",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.blue[300]
                                      : Colors.blue[800],
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                backgroundColor: isDark
                                    ? Colors.blue.withValues(alpha: 0.12)
                                    : Colors.blue[50],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () async {
                                final navigator = Navigator.of(context);
                                navigator.pop();
                                await navigator.push(
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailScreen(
                                      product: prod.presentaciones.isNotEmpty
                                          ? prod
                                          : prod.copyWith(
                                              presentaciones: [_currentPres],
                                            ),
                                      initialPresentationId: _currentPres.id!,
                                      heroTag: 'cat_${_currentPres.id}',
                                    ),
                                  ),
                                );
                                await catalogProv?.initCatalog();
                              },
                            ),
                          ),
                        ),
                ),

                Divider(
                  height: 28,
                  thickness: 1,
                  color: isDark ? Colors.white10 : Colors.grey[200],
                ),

                // 6. SELECTOR DE PRECIO Y CANTIDAD
                if (!isOutOfStock) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Precio Venta",
                              style: textTheme.titleMedium?.copyWith(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (hasOffer)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    Text(
                                      AppCurrency.format(
                                        _currentPres.precioVentaFinal,
                                      ),
                                      style: textTheme.titleLarge?.copyWith(
                                        decoration: TextDecoration.lineThrough,
                                        color: isDark
                                            ? Colors.grey[600]
                                            : Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (_currentPres.discountPercentRounded >
                                        0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.red.withValues(
                                                  alpha: 0.2,
                                                )
                                              : Colors.red[50],
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.red[400]!
                                                : Colors.red,
                                          ),
                                        ),
                                        child: Text(
                                          "-${_currentPres.discountPercentRounded}%",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.red[300]
                                                : Colors.red[800],
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                AppCurrency.format(unitPrice),
                                style: textTheme.displayMedium?.copyWith(
                                  color: hasOffer
                                      ? (isDark ? Colors.red[400] : Colors.red)
                                      : textColor,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF14141C)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _quantity > 1 ? _decrement : null,
                              icon: const Icon(Icons.remove, size: 24),
                              color: isDark ? Colors.red[300] : Colors.red,
                            ),
                            Container(
                              width: 44,
                              alignment: Alignment.center,
                              child: Text(
                                "$_quantity",
                                style: textTheme.titleLarge?.copyWith(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _quantity < _maxStock
                                  ? _increment
                                  : null,
                              icon: const Icon(Icons.add, size: 24),
                              color: isDark
                                  ? Colors.green[400]
                                  : Theme.of(context).primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // TARJETA DE SUBTOTAL
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: hasOffer
                          ? (isDark
                                ? Colors.red.withValues(alpha: 0.15)
                                : Colors.red[50])
                          : (isDark
                                ? Colors.green.withValues(alpha: 0.15)
                                : const Color(0xFFF0FDF4)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasOffer
                            ? (isDark
                                  ? Colors.red.withValues(alpha: 0.3)
                                  : Colors.red.shade200)
                            : (isDark
                                  ? Colors.green.withValues(alpha: 0.3)
                                  : Colors.green.shade200),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                "Subtotal $qtyLabel:",
                                style: textTheme.titleMedium?.copyWith(
                                  color: hasOffer
                                      ? (isDark
                                            ? Colors.red[200]
                                            : Colors.red[900])
                                      : (isDark
                                            ? Colors.green[200]
                                            : Colors.green[900]),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  AppCurrency.format(subtotal),
                                  style: textTheme.displaySmall?.copyWith(
                                    color: hasOffer
                                        ? (isDark
                                              ? Colors.red[300]
                                              : Colors.red[900])
                                        : (isDark
                                              ? Colors.green[300]
                                              : Colors.green[900]),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (hasOffer) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.local_offer,
                                color: isDark
                                    ? Colors.red[300]
                                    : Colors.red[700],
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "¡Ahorras ${AppCurrency.format(totalSavings)}!",
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? Colors.red[300]
                                        : Colors.red[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.production_quantity_limits,
                          size: 44,
                          color: isDark ? Colors.grey[500] : Colors.grey,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Temporalmente Agotado",
                          style: textTheme.titleLarge?.copyWith(
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Intenta seleccionando otra presentación",
                          style: textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),
          // BOTÓN DE CERRAR 'X' FLOTANTE CON HÁPTICA Y FONDO TRANSLÚCIDO
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: isDark ? Colors.white12 : Colors.grey[200],
              shape: const CircleBorder(),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Icon(
                    Icons.close,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final MaterialColor color;
  final bool isDark;
  final TextTheme textTheme;

  const _DetailPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.15) : color[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? color.withValues(alpha: 0.3)
              : color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isDark ? color[300] : color[700]),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? color[200] : color[700],
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : color[900],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
