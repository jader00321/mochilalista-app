import 'package:flutter/material.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/widgets/form/product_entity_pickers.dart';
import 'package:app_movil/core/widgets/product_presentation_card.dart';
import 'package:app_movil/core/widgets/modern_entity_selector_field.dart';

/// Lista reactiva de tarjetas de presentaciones para la pantalla de Creación de Producto.
/// Cuenta con aislamiento de repintado mediante RepaintBoundary en cada tarjeta
/// y selector modal interactivo para proveedores específicos de variante.
class ProductCreatePresentationList extends StatelessWidget {
  final List<Map<String, dynamic>> controllers;
  final Map<String, GlobalKey> presentationKeys;
  final bool isDark;
  final InventoryProvider provider;
  final Map<int, String> deferredProviderNames;
  final Function(int) onSetDefault;
  final Function(int) onMoveUp;
  final Function(int) onMoveDown;
  final Function(int) onRemove;
  final Function(int) onClone;
  final Function(int, bool) onStateChange;
  final Function(String, int, double) onCreateLeftover;
  final Function(String) onInvalidateLeftover;
  final VoidCallback onSyncDraft;
  final String modoStock;
  final TextEditingController? sharedStockCtrl;

  const ProductCreatePresentationList({
    super.key,
    required this.controllers,
    required this.presentationKeys,
    required this.isDark,
    required this.provider,
    required this.deferredProviderNames,
    required this.onSetDefault,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    required this.onClone,
    required this.onStateChange,
    required this.onCreateLeftover,
    required this.onInvalidateLeftover,
    required this.onSyncDraft,
    this.modoStock = 'INDEPENDIENTE',
    this.sharedStockCtrl,
    this.baseCostCtrl,
  });

  final TextEditingController? baseCostCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(controllers.length, (i) {
        final presId = controllers[i]['id'].toString();
        return Container(
          key: presentationKeys[presId],
          child: RepaintBoundary(
            child: ProductPresentationCard(
              key: ValueKey(presId),
              controllerMap: controllers[i],
              presentationIndex: i,
              totalPresentations: controllers.length,
              modoStock: modoStock,
              sharedStockCtrl: sharedStockCtrl,
              baseCostCtrl: baseCostCtrl,
              onSetDefault: () => onSetDefault(i),
              onMoveUp: i > 0 ? () => onMoveUp(i) : null,
              onMoveDown: i < controllers.length - 1 ? () => onMoveDown(i) : null,
              onDelete: () => onRemove(i),
              onClone: () => onClone(i),
              onStateChange: (val) => onStateChange(i, val),
              onCreateLeftover: (leftoverStock, costoBaseIndiv) =>
                  onCreateLeftover(controllers[i]['id'], leftoverStock, costoBaseIndiv),
              onInvalidateLeftover: () => onInvalidateLeftover(controllers[i]['id']),
              onDiscreteMutationCompleted: onSyncDraft,
              providerDropdown: ModernEntitySelectorField(
                label: "Proveedor de esta Variante",
                valueText: ProductEntityPickers.getProviderDisplay(
                  provider: provider,
                  providerId: controllers[i]['providerId'],
                  deferredProviderNames: deferredProviderNames,
                ),
                icon: Icons.local_shipping_outlined,
                isDeferred: controllers[i]['providerId'] != null &&
                    (controllers[i]['providerId'] as int) < 0,
                isDark: isDark,
                isCompact: true,
                onTap: () async {
                  FocusManager.instance.primaryFocus?.unfocus();
                  final res = await ProductEntityPickers.openProviderPicker(
                    context: context,
                    selectedProviderId: controllers[i]['providerId'],
                    title: "Proveedor de esta Variante",
                    deferredProviderNames: deferredProviderNames,
                  );
                  FocusManager.instance.primaryFocus?.unfocus();
                  if (res != null) {
                    controllers[i]['providerId'] = res.id;
                    if (res.id != null && res.id! < 0) {
                      deferredProviderNames[res.id!] = res.name;
                    }
                    onSyncDraft();
                  }
                },
              ),
            ),
          ),
        );
      }),
    );
  }
}
