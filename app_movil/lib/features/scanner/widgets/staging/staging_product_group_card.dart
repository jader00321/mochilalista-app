import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/core/widgets/smart_dropdown_search.dart';
import 'package:app_movil/core/widgets/manual_product_search.dart';
import 'package:app_movil/features/scanner/widgets/staging/variant_editor_row.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class StagingProductGroupCard extends StatefulWidget {
  final int groupIndex;
  final ScannerProvider provider;
  final bool isDark;

  const StagingProductGroupCard({
    super.key,
    required this.groupIndex,
    required this.provider,
    required this.isDark,
  });

  @override
  State<StagingProductGroupCard> createState() =>
      _StagingProductGroupCardState();
}

class _StagingProductGroupCardState extends State<StagingProductGroupCard> {
  void _showProductSearchModal(BuildContext context, String groupUuid) {
    FocusScope.of(context).unfocus(); // Limpiar foco antes de abrir
    InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) => ManualProductSearch(
        onSelect: (wrapper) async {
          final invProv = Provider.of<InventoryProvider>(
            context,
            listen: false,
          );

          // Buscar siblings directamente en SQLite
          final db = await LocalDatabase.instance.database;
          final presQuery = await db.query(
            'presentaciones_producto',
            where: 'producto_id = ?',
            whereArgs: [wrapper.product.id],
          );

          List<Map<String, dynamic>> siblings = presQuery.map((p) {
            return {
              "id": p['id'],
              "nombre_presentacion": p['unidad_venta'] ?? "Unidad",
              "nombre_especifico": p['nombre_especifico'],
              "nombre_completo":
                  "${p['unidad_venta'] ?? 'Unidad'} ${p['nombre_especifico'] ?? ''}"
                      .trim(),
              "stock_actual": p['stock_actual'],
              "precio_venta": p['precio_venta_final'],
              "precio_costo": p['costo_unitario_calculado'],
              "factor_conversion": p['unidades_por_venta'],
              "unidad": p['unidad_venta'] ?? "Unidad",
              "ump_compra": p['ump_compra'],
              "cantidad_ump_comprada": p['cantidad_ump_comprada'],
              "precio_ump_proveedor": p['precio_ump_proveedor'],
              "total_pago_lote": p['total_pago_lote'],
              "unidades_por_lote": p['unidades_por_lote'],
              "tipo_descuento": p['tipo_descuento'],
              "valor_descuento": p['valor_descuento'],
              "precio_oferta": p['precio_oferta'],
              "factor_ganancia_venta": p['factor_ganancia_venta'],
            };
          }).toList();

          widget.provider.manualLinkProductGroup(
            groupUuid,
            {
              'id': wrapper.product.id,
              'nombre': wrapper.product.nombre,
              'stock_total_unidades': wrapper.product.stockTotalCalculado,
              'marca_nombre': invProv.getBrandName(wrapper.product.marcaId),
              'categoria_nombre': invProv.getCategoryName(
                wrapper.product.categoriaId,
              ),
            },
            siblings,
            selectedPresentationId: wrapper.presentation.id,
          );
          if (ctx.mounted) {
            Navigator.pop(ctx);
            FocusScope.of(context).unfocus(); // Limpiar foco al cerrar
          }
        },
      ),
    );
  }

  void _confirmDeleteVariant(String variantUuid) {
    if (widget.groupIndex >= widget.provider.stagingData!.productosAgrupados.length) return;
    final group = widget.provider.stagingData!.productosAgrupados[widget.groupIndex];
    final variant = group.variantes.where((v) => v.uuidTemporal == variantUuid).firstOrNull;
    final bool isLeftoverChild = variant?.sourceVariantUuid != null;
    final int unitsToReturn = variant?.allocatedBaseUnits ?? variant?.stockIngresanteBase ?? 0;
    final double costToReturn = variant?.allocatedPurchaseCost ?? variant?.totalPagoLote ?? 0.0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isLeftoverChild ? Icons.restore_page_outlined : Icons.delete_outline,
              color: isLeftoverChild
                  ? (widget.isDark ? Colors.orange[300] : Colors.orange[800])
                  : (widget.isDark ? Colors.red[300] : Colors.red),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isLeftoverChild ? "¿Eliminar variante sobrante?" : "¿Eliminar variante?",
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          isLeftoverChild
              ? "Esta variante fue creada a partir del stock sobrante.\n\nAl eliminarla, sus $unitsToReturn unidades base y su costo (${AppCurrency.format(costToReturn)}) regresarán automáticamente a la presentación principal, restaurando el balance exacto de la factura."
              : "Esta fila se descartará y no ingresará al inventario.",
          style: TextStyle(
            color: widget.isDark ? Colors.grey[300] : Colors.grey[800],
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancelar",
              style: TextStyle(
                color: widget.isDark ? Colors.grey[400] : Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.provider.removeVariantByUuid(variantUuid);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isLeftoverChild
                  ? (widget.isDark ? Colors.orange[800] : Colors.orange[700])
                  : (widget.isDark ? Colors.red[800] : Colors.red[50]),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              isLeftoverChild ? "Eliminar y Devolver" : "Eliminar",
              style: TextStyle(
                color: isLeftoverChild
                    ? Colors.white
                    : (widget.isDark ? Colors.white : Colors.red),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupIndex >=
        widget.provider.stagingData!.productosAgrupados.length) {
      return const SizedBox.shrink();
    }

    final group =
        widget.provider.stagingData!.productosAgrupados[widget.groupIndex];
    bool isParentMatch = group.matchProducto.estado.contains("MATCH");
    final bool isHighlighted = widget.provider.highlightedGroupUuid == group.uuidTemporal;

    final borderColor = isHighlighted
        ? Colors.amber[600]!
        : (isParentMatch
            ? (widget.isDark ? Colors.green[700]! : Colors.green.shade300)
            : (widget.isDark ? Colors.blue[700]! : Colors.blue.shade300));
    final headerColor = isHighlighted
        ? (widget.isDark ? Colors.amber.withValues(alpha: 0.25) : Colors.amber.shade100)
        : (isParentMatch
            ? (widget.isDark
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.green[50])
            : (widget.isDark
                  ? Colors.blue.withValues(alpha: 0.15)
                  : Colors.blue[50]));
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: isHighlighted ? 3.0 : 1.5,
        ),
        boxShadow: [
          if (isHighlighted)
            BoxShadow(
              color: Colors.amber.withValues(alpha: widget.isDark ? 0.5 : 0.6),
              blurRadius: 16,
              spreadRadius: 2,
            )
          else if (!widget.isDark)
            const BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          children: [
          // HEADER DEL PRODUCTO PADRE
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isParentMatch
                            ? (widget.isDark
                                  ? Colors.green[600]
                                  : Colors.green[800])
                            : (widget.isDark
                                  ? Colors.blue[600]
                                  : Colors.blue[800]),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        "${widget.groupIndex + 1}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isParentMatch
                                ? "EN INVENTARIO (ID: ${group.matchProducto.datos?.id})"
                                : "NUEVO PRODUCTO GENERAL",
                            style: TextStyle(
                              color: isParentMatch
                                  ? (widget.isDark
                                        ? Colors.green[300]
                                        : Colors.green[800])
                                  : (widget.isDark
                                        ? Colors.blue[300]
                                        : Colors.blue[800]),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (group.nombreOriginalFactura != null &&
                              group.nombreOriginalFactura!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2, bottom: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 13,
                                    color: widget.isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      "En Factura: '${group.nombreOriginalFactura}'",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: widget.isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (isParentMatch)
                            Text(
                              group.matchProducto.datos?.nombre ?? group.nombrePadre,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: textColor,
                              ),
                            )
                          else
                            SizedBox(
                              height: 36,
                              child: TextFormField(
                                autofocus:
                                    false, // Prevención de foco automático
                                initialValue: group.nombrePadre,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: textColor,
                                ),
                                decoration: InputDecoration(
                                  labelText: "Nombre Producto Principal",
                                  labelStyle: TextStyle(
                                    color: widget.isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[700],
                                    fontSize: 11,
                                  ),
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: widget.isDark
                                      ? const Color(0xFF14141C)
                                      : Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (val) => group.nombrePadre = val,
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (isParentMatch)
                      IconButton(
                        icon: Icon(
                          Icons.link_off,
                          color: widget.isDark ? Colors.red[400] : Colors.red,
                          size: 22,
                        ),
                        onPressed: () => widget.provider.unlinkProductGroup(
                          group.uuidTemporal,
                        ),
                        tooltip: "Desvincular producto del inventario",
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          Icons.search,
                          color: widget.isDark ? Colors.blue[300] : Colors.blue,
                          size: 22,
                        ),
                        onPressed: () => _showProductSearchModal(
                          context,
                          group.uuidTemporal,
                        ),
                        tooltip: "Buscar Existente",
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                if (isParentMatch)
                  _buildReadOnlyParentDetails(group, widget.isDark)
                else
                  _buildEditableParentDetails(
                    context,
                    group,
                    widget.provider,
                    widget.isDark,
                  ),
              ],
            ),
          ),

          Divider(
            height: 1,
            color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
          ),

          // FASE 4 / FASE 1: Banner de advertencia de confianza del matching
          if (isParentMatch && !group.isMatchVerified && group.matchProducto.confianza < 75 && group.matchProducto.confianza > 0)
            _buildMatchConfidenceWarning(group, widget.isDark),

          // LISTA DE VARIANTES (HIJOS)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: group.variantes.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (ctx, vIndex) {
              final variant = group.variantes[vIndex];
              return VariantEditorRow(
                key: ValueKey(variant.uuidTemporal),
                variant: variant,
                group: group,
                isDark: widget.isDark,
                provider: widget.provider,
                onDelete: () => _confirmDeleteVariant(variant.uuidTemporal),
              );
            },
          ),

          // FOOTER: AGREGAR OTRA VARIANTE
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF14141C) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
            ),
            child: TextButton.icon(
              icon: Icon(
                Icons.add_circle_outline,
                size: 18,
                color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
              ),
              label: Text(
                "Añadir otra presentación (Fraccionamiento)",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
              onPressed: () =>
                  widget.provider.addNewVariantToGroup(group.uuidTemporal),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildReadOnlyParentDetails(StagingProductGroup group, bool isDark) {
    String marca = group.matchProducto.datos?.marcaNombre ?? group.marcaTexto;
    if (marca.isEmpty || marca == "null") marca = "Genérica";
    String categoria = group.matchProducto.datos?.categoriaNombre ?? "General";

    int stockMostrar = group.matchProducto.datos?.stockActual ?? 0;
    if (group.variantes.isNotEmpty &&
        group.variantes.first.matchPresentacion.estado.contains("MATCH")) {
      stockMostrar =
          group.variantes.first.matchPresentacion.datos?.stockActual ??
          stockMostrar;
    }

    final String modoStock = group.modoStock;
    final MaterialColor modoColor = modoStock == 'COMPARTIDO'
        ? Colors.teal
        : (modoStock == 'MIXTO' ? Colors.amber : Colors.blueGrey);
    final String modoLabel = modoStock == 'COMPARTIDO'
        ? 'Stock Compartido'
        : (modoStock == 'MIXTO' ? 'Stock Mixto' : 'Stock Independiente');
    final IconData modoIcon = modoStock == 'COMPARTIDO'
        ? Icons.all_inclusive_rounded
        : (modoStock == 'MIXTO'
            ? Icons.electric_bolt_outlined
            : Icons.inventory_2_outlined);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _tag(
          "Stock actual: $stockMostrar",
          isDark ? Colors.green[300]! : Colors.green[800]!,
          isDark,
          icon: Icons.inventory_2_outlined,
        ),
        _tag(
          modoLabel,
          isDark ? modoColor[300]! : modoColor[800]!,
          isDark,
          icon: modoIcon,
        ),
        if (modoStock == 'COMPARTIDO' && group.stockCompartido > 0)
          _tag(
            "Pool: ${group.stockCompartido} uds",
            isDark ? Colors.tealAccent : Colors.teal.shade700,
            isDark,
            icon: Icons.hub_outlined,
          ),
        _tag(
          marca,
          isDark ? Colors.blueGrey[300]! : Colors.blueGrey[800]!,
          isDark,
          icon: Icons.branding_watermark_outlined,
        ),
        _tag(
          categoria,
          isDark ? Colors.indigo[300]! : Colors.indigo[800]!,
          isDark,
          icon: Icons.category_outlined,
        ),
      ],
    );
  }

  Widget _buildEditableParentDetails(
    BuildContext context,
    StagingProductGroup group,
    ScannerProvider provider,
    bool isDark,
  ) {
    final inventoryProv = Provider.of<InventoryProvider>(context);

    dynamic selectedBrand;
    if (group.matchMarca.datos?.id != null) {
      selectedBrand = inventoryProv.brands
          .where((b) => b.id == group.matchMarca.datos!.id)
          .firstOrNull;
    }
    String brandHint = group.marcaTexto.isNotEmpty
        ? group.marcaTexto
        : "Marca...";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 5,
              child: SmartDropdownSearch<dynamic>(
                label: "Marca",
                items: inventoryProv.brands,
                selectedValue: selectedBrand,
                hintText: brandHint,
                itemAsString: (b) => b.nombre,
                onChanged: (b) {
                  if (b != null) {
                    setState(() {
                      group.matchMarca = MatchResult(
                        estado: "MATCH_MANUAL",
                        confianza: 100,
                        datos: MatchData(id: b.id, nombre: b.nombre),
                      );
                      group.marcaTexto = b.nombre;
                    });
                  }
                },
                onAddNew: (text) async {
                  int? newId = await inventoryProv.createBrand(text);
                  if (newId != null && context.mounted) {
                    setState(() {
                      group.matchMarca = MatchResult(
                        estado: "MATCH_MANUAL",
                        confianza: 100,
                        datos: MatchData(id: newId, nombre: text),
                      );
                      group.marcaTexto = text;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: SmartDropdownSearch<dynamic>(
                label: "Categoría",
                items: inventoryProv.categories,
                selectedValue: group.categoriaSugeridaId != null
                    ? inventoryProv.categories
                          .where((c) => c.id == group.categoriaSugeridaId)
                          .firstOrNull
                    : null,
                itemAsString: (c) => c.nombre,
                onChanged: (c) {
                  if (c != null) setState(() => group.categoriaSugeridaId = c.id);
                },
                onAddNew: (text) async {
                  int? newId = await inventoryProv.createCategory(text);
                  if (newId != null && context.mounted) {
                    setState(() => group.categoriaSugeridaId = newId);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildStrategySelectorChips(group, isDark),
      ],
    );
  }

  Widget _buildStrategySelectorChips(StagingProductGroup group, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Estrategia de Stock:",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
            const SizedBox(width: 8),
            Wrap(
              spacing: 6,
              children: [
                _buildStrategyChoiceChip(group, 'COMPARTIDO', '🔗 Compartido', Colors.teal, isDark),
                _buildStrategyChoiceChip(group, 'INDEPENDIENTE', '📦 Independiente', Colors.blueGrey, isDark),
                _buildStrategyChoiceChip(group, 'MIXTO', '⚡ Mixto', Colors.amber, isDark),
              ],
            ),
          ],
        ),
        if (group.modoStock == 'COMPARTIDO')
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "Todas las presentaciones compartirán un stock común en unidades base.",
              style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: isDark ? Colors.tealAccent : Colors.teal.shade800),
            ),
          ),
      ],
    );
  }

  Widget _buildStrategyChoiceChip(StagingProductGroup group, String strategyKey, String label, MaterialColor baseColor, bool isDark) {
    final isSelected = group.modoStock == strategyKey;
    final color = isDark ? baseColor[300]! : baseColor[800]!;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? (isDark ? Colors.black87 : Colors.white) : color,
        ),
      ),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: isDark ? const Color(0xFF1F1F2C) : Colors.grey.shade100,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            widget.provider.setGroupStockStrategy(group.uuidTemporal, strategyKey);
          });
        }
      },
    );
  }

  Widget _tag(String text, Color color, bool isDark, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.15)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? color.withValues(alpha: 0.3)
              : color.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 11,
              color: isDark ? color : Color.lerp(color, Colors.black, 0.2)!,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? color : Color.lerp(color, Colors.black, 0.2)!,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// FASE 1: Banner visual de advertencia de confianza del matching limpio y accionable
  Widget _buildMatchConfidenceWarning(StagingProductGroup group, bool isDark) {
    final confianza = group.matchProducto.confianza;
    final isLow = confianza < 50;
    final color = isLow ? Colors.red : Colors.orange;
    final nombreFactura = group.nombreOriginalFactura ?? group.nombrePadre;

    String nombreInventario = group.matchProducto.datos?.nombre ?? '???';
    if (group.variantes.isNotEmpty &&
        group.variantes.first.matchPresentacion.estado.contains("MATCH")) {
      final vNom = group.variantes.first.matchPresentacion.datos?.nombre;
      if (vNom != null && vNom.isNotEmpty && vNom != "General") {
        nombreInventario += " • Var: $vNom";
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.1) : color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? color.withValues(alpha: 0.4) : color.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isLow ? Icons.error_outline : Icons.warning_amber_rounded,
                color: isDark ? color[300] : color[800],
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isLow
                      ? "Similitud baja ($confianza%) — Verificar"
                      : "Similitud parcial ($confianza%) — Verificar",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isDark ? color[300] : color[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[300] : Colors.grey[800]),
              children: [
                const TextSpan(text: "Factura: ", style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: "\"$nombreFactura\"\n"),
                const TextSpan(text: "Inventario: ", style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: "\"$nombreInventario\""),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Botón Confirmar: Sí es el mismo
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    group.isMatchVerified = true;
                  });
                  widget.provider.notifyUIUpdate();
                },
                icon: const Icon(Icons.check, size: 14),
                label: const Text(
                  "✓ Sí es el mismo",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.green[800] : Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),

              // Botón Buscar otro en inventario
              OutlinedButton.icon(
                onPressed: () => _showProductSearchModal(context, group.uuidTemporal),
                icon: Icon(Icons.search, size: 14, color: isDark ? Colors.blue[300] : Colors.blue[800]),
                label: Text(
                  "Buscar otro",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.blue[300] : Colors.blue[800],
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  minimumSize: const Size(0, 32),
                  side: BorderSide(color: isDark ? Colors.blue.withValues(alpha: 0.5) : Colors.blue.shade400),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              // Botón Desvincular
              OutlinedButton.icon(
                onPressed: () => widget.provider.unlinkProductGroup(group.uuidTemporal),
                icon: Icon(Icons.link_off, size: 14, color: isDark ? color[300] : color[800]),
                label: Text(
                  "Desvincular",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? color[300] : color[800],
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  minimumSize: const Size(0, 32),
                  side: BorderSide(color: isDark ? color.withValues(alpha: 0.5) : color.shade400),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
