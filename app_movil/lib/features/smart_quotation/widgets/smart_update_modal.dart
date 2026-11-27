import 'package:flutter/material.dart';

import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';

part 'smart_update/smart_update_sections_part.dart';
part 'smart_update/smart_update_stock_and_shared_cards_part.dart';
part 'smart_update/smart_update_price_and_meta_cards_part.dart';

/// Modal de resolución de conflictos factor-aware de stock, precios y nombres.
class SmartUpdateModal extends StatelessWidget {
  final ValidationResult validation;
  final VoidCallback onUpdatePrices;
  final VoidCallback onFixStock;
  final VoidCallback onFixAll;

  final Function(int itemId, int newQty)? onFixSingleStock;
  final Function(int itemId)? onRemoveSingleItem;
  final Function(int itemId, double newPrice, double newBase)?
  onAcceptSinglePrice;
  final Function(int itemId, String newName)? onAcceptSingleName;
  final VoidCallback? onUpdateNames;
  final VoidCallback? onSyncBundles;
  final VoidCallback? onSyncUnits;
  final VoidCallback? onOpenManualEdit;

  const SmartUpdateModal({
    super.key,
    required this.validation,
    required this.onUpdatePrices,
    required this.onFixStock,
    required this.onFixAll,
    this.onFixSingleStock,
    this.onRemoveSingleItem,
    this.onAcceptSinglePrice,
    this.onAcceptSingleName,
    this.onUpdateNames,
    this.onSyncBundles,
    this.onSyncUnits,
    this.onOpenManualEdit,
  });

  @override
  Widget build(BuildContext context) {
    final stockIssues = validation.stockWarnings;
    final sharedIssues = validation.sharedStockConflicts;
    final priceIssues = validation.priceChanges;
    final nameIssues = validation.nameChanges;
    final bundleIssues = validation.bundleChanges;
    final unitIssues = validation.unitChanges;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool hasNoRealIssues =
        stockIssues.isEmpty &&
        sharedIssues.isEmpty &&
        priceIssues.isEmpty &&
        nameIssues.isEmpty &&
        bundleIssues.isEmpty &&
        unitIssues.isEmpty;
    final bool onlyPriceIssues =
        priceIssues.isNotEmpty &&
        stockIssues.isEmpty &&
        sharedIssues.isEmpty &&
        nameIssues.isEmpty &&
        bundleIssues.isEmpty &&
        unitIssues.isEmpty;
    final bool onlyStockIssues =
        (stockIssues.isNotEmpty || sharedIssues.isNotEmpty) &&
        priceIssues.isEmpty &&
        nameIssues.isEmpty &&
        bundleIssues.isEmpty &&
        unitIssues.isEmpty;

    return InteractiveSheetWrapper(
      title: hasNoRealIssues ? "Todo en Orden" : "Centro de Resoluciones",
      icon: hasNoRealIssues ? Icons.check_circle : Icons.build_circle,
      iconColor: hasNoRealIssues
          ? (isDark ? Colors.green[300] : Colors.green[700])
          : (isDark ? Colors.orange[300] : Colors.orange[800]),
      maxHeightFactor: 0.90,
      applyEffectiveBottomPadding: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasNoRealIssues)
            _buildAllClearContent(context, isDark)
          else ...[
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "El inventario ha cambiado desde que se creó esta cotización. Revisa y aplica los cambios si lo deseas.",
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._buildConflictSections(
                      context: context,
                      isDark: isDark,
                      onlyPriceIssues: onlyPriceIssues,
                      stockIssues: stockIssues,
                      sharedIssues: sharedIssues,
                      priceIssues: priceIssues,
                      nameIssues: nameIssues,
                      bundleIssues: bundleIssues,
                      unitIssues: unitIssues,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildGlobalActionFooter(
              context: context,
              isDark: isDark,
              onlyPriceIssues: onlyPriceIssues,
              onlyStockIssues: onlyStockIssues,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAllClearContent(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Hemos revisado el inventario y todos los productos de esta cotización están disponibles y con los precios correctos.",
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[700],
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "CONTINUAR",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalActionFooter({
    required BuildContext context,
    required bool isDark,
    required bool onlyPriceIssues,
    required bool onlyStockIssues,
  }) {
    final IconData icon = onlyPriceIssues
        ? Icons.check_circle_outline
        : (onlyStockIssues ? Icons.delete_sweep : Icons.auto_awesome);
    final String label = onlyPriceIssues
        ? "ACEPTAR TODOS LOS PRECIOS DE HOY"
        : (onlyStockIssues
              ? "CORREGIR PRODUCTOS AGOTADOS"
              : "CORREGIR Y ACTUALIZAR TODO");
    final Color bg = onlyPriceIssues
        ? (isDark ? Colors.orange[800]! : Colors.orange[700]!)
        : (onlyStockIssues
              ? (isDark ? Colors.red[800]! : Colors.red[700]!)
              : Colors.green[700]!);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (onlyPriceIssues) {
                  onUpdatePrices();
                } else if (onlyStockIssues) {
                  onFixStock();
                } else {
                  onFixAll();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: bg,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: isDark ? 0 : 4,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton(
              style: TextButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => Navigator.pop(context),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "Cancelar y revisar manualmente",
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
