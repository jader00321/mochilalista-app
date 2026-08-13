import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/core/widgets/smart_dropdown_search.dart';
import 'package:app_movil/core/widgets/manual_product_search.dart';
import 'package:app_movil/features/scanner/widgets/staging/variant_editor_row.dart';

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
  State<StagingProductGroupCard> createState() => _StagingProductGroupCardState();
}

class _StagingProductGroupCardState extends State<StagingProductGroupCard> {
  
  void _showProductSearchModal(BuildContext context, String groupUuid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ManualProductSearch(
        onSelect: (wrapper) {
          final invProv = Provider.of<InventoryProvider>(context, listen: false);
          final siblingsWrappers = invProv.items.where((w) => w.product.id == wrapper.product.id).toList();
          
          List<Map<String, dynamic>> siblings = siblingsWrappers.map((w) {
            return {
              "id": w.presentation.id,
              "nombre_presentacion": w.presentation.unidadVenta ?? "Unidad",
              "nombre_especifico": w.presentation.nombreEspecifico,
              "nombre_completo": "${w.presentation.unidadVenta ?? 'Unidad'} ${w.presentation.nombreEspecifico ?? ''}".trim(),
              "stock_actual": w.presentation.stockActual,
              "precio_venta": w.presentation.precioVentaFinal,
              "precio_costo": w.presentation.costoUnitarioCalculado,
              "factor_conversion": w.presentation.unidadesPorVenta,
              "unidad": w.presentation.unidadVenta ?? "Unidad"
            };
          }).toList();

          widget.provider.manualLinkProductGroup(
            groupUuid, 
            {
              'id': wrapper.product.id,
              'nombre': wrapper.product.nombre,
              'stock_total_unidades': wrapper.product.stockTotalCalculado,
              'marca_nombre': invProv.getBrandName(wrapper.product.marcaId),
              'categoria_nombre': invProv.getCategoryName(wrapper.product.categoriaId)
            },
            siblings 
          );
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _confirmDeleteVariant(String variantUuid) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Â¿Eliminar variante?", style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)), 
        content: Text("Esta fila se descartarÃ¡ y no ingresarÃ¡ al inventario.", style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 13)), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancelar", style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey, fontSize: 14))), 
          ElevatedButton(
            onPressed: () { 
              Navigator.pop(ctx); 
              widget.provider.removeVariantByUuid(variantUuid); 
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: widget.isDark ? Colors.red[800] : Colors.red[50], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text("Eliminar", style: TextStyle(color: widget.isDark ? Colors.white : Colors.red, fontWeight: FontWeight.bold, fontSize: 14))
          )
        ]
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupIndex >= widget.provider.stagingData!.productosAgrupados.length) return const SizedBox.shrink();

    final group = widget.provider.stagingData!.productosAgrupados[widget.groupIndex];
    bool isParentMatch = group.matchProducto.estado.contains("MATCH");
    
    final borderColor = isParentMatch ? (widget.isDark ? Colors.green[700]! : Colors.green.shade300) : (widget.isDark ? Colors.blue[700]! : Colors.blue.shade300);
    final headerColor = isParentMatch ? (widget.isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green[50]) : (widget.isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue[50]);
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      elevation: widget.isDark ? 0 : 2,
      color: widget.isDark ? const Color(0xFF23232F) : Colors.white,
      shadowColor: widget.isDark ? Colors.transparent : Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borderColor, width: 1.5)),
      child: Column(
        children: [
          // HEADER DEL PRODUCTO PADRE
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: headerColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: isParentMatch ? (widget.isDark ? Colors.green[600] : Colors.green[800]) : (widget.isDark ? Colors.blue[600] : Colors.blue[800]), shape: BoxShape.circle),
                      child: Text("${widget.groupIndex + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isParentMatch ? "EN INVENTARIO (ID: ${group.matchProducto.datos?.id})" : "NUEVO PRODUCTO GENERAL",
                            style: TextStyle(color: isParentMatch ? (widget.isDark ? Colors.green[300] : Colors.green[800]) : (widget.isDark ? Colors.blue[300] : Colors.blue[800]), fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
                          ),
                          if (group.nombreOriginalFactura != null && group.nombreOriginalFactura!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2, bottom: 4),
                              child: Text("En Factura: '${group.nombreOriginalFactura}'", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: widget.isDark ? Colors.white70 : Colors.black54)),
                            ),

                          if (isParentMatch)
                            Text(group.matchProducto.datos?.nombre ?? group.nombrePadre, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textColor))
                          else
                            SizedBox(
                              height: 36,
                              child: TextFormField(
                                initialValue: group.nombrePadre,
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: textColor), 
                                decoration: InputDecoration(
                                  labelText: "Nombre Producto Principal",
                                  labelStyle: TextStyle(color: widget.isDark ? Colors.grey[500] : Colors.grey[700], fontSize: 11),
                                  isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), 
                                  filled: true, fillColor: widget.isDark ? const Color(0xFF14141C) : Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
                                ),
                                onChanged: (val) => group.nombrePadre = val,
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (isParentMatch)
                      IconButton(icon: Icon(Icons.link_off, color: widget.isDark ? Colors.red[400] : Colors.red, size: 22), onPressed: () => widget.provider.unlinkProductGroup(group.uuidTemporal), tooltip: "Desvincular", padding: EdgeInsets.zero, constraints: const BoxConstraints())
                    else 
                      IconButton(icon: Icon(Icons.search, color: widget.isDark ? Colors.blue[300] : Colors.blue, size: 22), onPressed: () => _showProductSearchModal(context, group.uuidTemporal), tooltip: "Buscar Existente", padding: EdgeInsets.zero, constraints: const BoxConstraints())
                  ],
                ),
                
                const SizedBox(height: 12),
                
                if (isParentMatch)
                  _buildReadOnlyParentDetails(group, widget.isDark)
                else
                  _buildEditableParentDetails(context, group, widget.provider, widget.isDark),
              ],
            ),
          ),

          Divider(height: 1, color: widget.isDark ? Colors.white10 : Colors.grey.shade200),

          // LISTA DE VARIANTES (HIJOS)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: group.variantes.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: widget.isDark ? Colors.white10 : Colors.grey.shade200, indent: 16, endIndent: 16),
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
            decoration: BoxDecoration(color: widget.isDark ? const Color(0xFF14141C) : Colors.white, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14))),
            child: TextButton.icon(
              icon: Icon(Icons.add_circle_outline, size: 18, color: widget.isDark ? Colors.grey[400] : Colors.grey[700]),
              label: Text("AÃ±adir otra presentaciÃ³n (Fraccionamiento)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: widget.isDark ? Colors.grey[400] : Colors.grey[700])),
              onPressed: () => widget.provider.addNewVariantToGroup(group.uuidTemporal),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildReadOnlyParentDetails(StagingProductGroup group, bool isDark) {
    String marca = group.matchProducto.datos?.marcaNombre ?? group.marcaTexto;
    if (marca.isEmpty || marca == "null") marca = "GenÃ©rica";
    String categoria = group.matchProducto.datos?.categoriaNombre ?? "General";

    return Wrap(
      spacing: 6, runSpacing: 6,
      children: [
        _tag("Stock Gral: ${group.matchProducto.datos?.stockActual}", isDark ? Colors.grey[400]! : Colors.grey, isDark),
        _tag(marca, isDark ? Colors.blueGrey[300]! : Colors.blueGrey, isDark),
        _tag(categoria, isDark ? Colors.indigo[300]! : Colors.indigo, isDark),
      ],
    );
  }

  Widget _buildEditableParentDetails(BuildContext context, StagingProductGroup group, ScannerProvider provider, bool isDark) {
    final inventoryProv = Provider.of<InventoryProvider>(context);
    
    dynamic selectedBrand;
    if (group.matchMarca.datos?.id != null) {
      selectedBrand = inventoryProv.brands.where((b) => b.id == group.matchMarca.datos!.id).firstOrNull;
    }
    String brandHint = group.marcaTexto.isNotEmpty ? group.marcaTexto : "Marca...";

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: SmartDropdownSearch<dynamic>(
            label: "Marca", items: inventoryProv.brands, selectedValue: selectedBrand, hintText: brandHint, itemAsString: (b) => b.nombre,
            onChanged: (b) {
              if (b != null) {
                setState(() {
                  group.matchMarca = MatchResult(estado: "MATCH_MANUAL", confianza: 100, datos: MatchData(id: b.id, nombre: b.nombre));
                  group.marcaTexto = b.nombre;
                });
              }
            },
            onAddNew: (text) async {
              int? newId = await inventoryProv.createBrand(text);
              if (newId != null && context.mounted) setState(() { group.matchMarca = MatchResult(estado: "MATCH_MANUAL", confianza: 100, datos: MatchData(id: newId, nombre: text)); group.marcaTexto = text; });
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: SmartDropdownSearch<dynamic>(
            label: "CategorÃ­a", items: inventoryProv.categories,
            selectedValue: group.categoriaSugeridaId != null ? inventoryProv.categories.where((c) => c.id == group.categoriaSugeridaId).firstOrNull : null,
            itemAsString: (c) => c.nombre,
            onChanged: (c) { if (c != null) setState(() => group.categoriaSugeridaId = c.id); },
            onAddNew: (text) async {
               int? newId = await inventoryProv.createCategory(text);
               if (newId != null && context.mounted) setState(() => group.categoriaSugeridaId = newId);
            },
          ),
        ),
      ],
    );
  }

  Widget _tag(String text, Color color, bool isDark) { 
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
      decoration: BoxDecoration(color: isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: isDark ? color.withValues(alpha: 0.3) : color.withValues(alpha: 0.5))), 
      child: Text(text, style: TextStyle(fontSize: 10, color: isDark ? color : Color.lerp(color, Colors.black, 0.2)!, fontWeight: FontWeight.bold, letterSpacing: 0.5))
    ); 
  }
}
