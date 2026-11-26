import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/manual_product_search.dart';
import 'package:app_movil/core/widgets/smart_dropdown_search.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/scanner/widgets/staging/variant_editor_row.dart';

part 'product_group/staging_group_header_and_modals.dart';
part 'product_group/staging_group_parent_details.dart';
part 'product_group/staging_group_stock_strategy.dart';

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
  void _refreshState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupIndex >=
        widget.provider.stagingData!.productosAgrupados.length) {
      return const SizedBox.shrink();
    }

    final group =
        widget.provider.stagingData!.productosAgrupados[widget.groupIndex];
    final bool isParentMatch = group.matchProducto.estado.contains("MATCH");
    final bool isHighlighted =
        widget.provider.highlightedGroupUuid == group.uuidTemporal;

    final borderColor = isHighlighted
        ? Colors.amber[600]!
        : (isParentMatch
              ? (widget.isDark ? Colors.green[700]! : Colors.green.shade300)
              : (widget.isDark ? Colors.blue[700]! : Colors.blue.shade300));
    final headerColor = isHighlighted
        ? (widget.isDark
              ? Colors.amber.withValues(alpha: 0.25)
              : Colors.amber.shade100)
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
              color: Colors.amber.withValues(
                alpha: widget.isDark ? 0.5 : 0.6,
              ),
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
            _buildGroupHeader(
              context,
              group,
              isParentMatch,
              headerColor!,
              textColor,
            ),

            Divider(
              height: 1,
              color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
            ),

            // Banner de advertencia de confianza del matching
            if (isParentMatch &&
                !group.isMatchVerified &&
                group.matchProducto.confianza < 75 &&
                group.matchProducto.confianza > 0)
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
              margin: const EdgeInsets.only(bottom: 28),
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
                  textAlign: TextAlign.center,
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
}
