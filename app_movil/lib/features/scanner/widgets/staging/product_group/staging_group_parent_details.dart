part of '../staging_product_group_card.dart';

extension _StagingGroupParentDetails on _StagingProductGroupCardState {
  Widget _buildReadOnlyParentDetails(StagingProductGroup group, bool isDark) {
    String marca = group.matchProducto.datos?.marcaNombre ?? group.marcaTexto;
    if (marca.isEmpty || marca == "null") marca = "Genérica";
    final String categoria =
        group.matchProducto.datos?.categoriaNombre ?? "General";

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
        ? Icons.hub_rounded
        : (modoStock == 'MIXTO'
              ? Icons.tune_rounded
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
            icon: Icons.hub_rounded,
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
    final String brandHint = group.marcaTexto.isNotEmpty
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
                    _refreshState(() {
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
                  final int? newId = await inventoryProv.createBrand(text);
                  if (newId != null && context.mounted) {
                    _refreshState(() {
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
                hintText: "Categoría...",
                itemAsString: (c) => c.nombre,
                onChanged: (c) {
                  if (c != null) {
                    _refreshState(() => group.categoriaSugeridaId = c.id);
                  }
                },
                onAddNew: (text) async {
                  final int? newId = await inventoryProv.createCategory(text);
                  if (newId != null && context.mounted) {
                    _refreshState(() => group.categoriaSugeridaId = newId);
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

  Widget _tag(String text, Color color, bool isDark, {IconData? icon}) {
    final Color resolvedColor = isDark
        ? color
        : Color.lerp(color, Colors.black, 0.2)!;
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
            Icon(icon, size: 11, color: resolvedColor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: resolvedColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
