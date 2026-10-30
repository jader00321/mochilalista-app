import 'package:flutter/material.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/core/widgets/product_presentation_card.dart';
import 'package:app_movil/core/widgets/modern_entity_selector_field.dart';
import 'package:app_movil/core/widgets/modern_entity_picker_modal.dart';

class ProductPresentationList extends StatelessWidget {
  final List<Map<String, dynamic>> presentationControllers;
  final bool isDark;
  final List<ProviderModel> providerListForDropdown;
  final Map<int, String> deferredProviderNames;
  final Function(int, bool) deletePresentation;
  final Function(String, int, double) handleCreateLeftover;
  final Function(String) invalidateLeftover;
  final VoidCallback onStateChange;
  final Function(int)? onSetDefault;
  final Function(int)? onMoveUp;
  final Function(int)? onMoveDown;
  final Function(int)? onClone;
  final Map<String, GlobalKey>? presentationKeys;
  final VoidCallback? onBeforeDiscreteMutation;
  final VoidCallback? onDiscreteMutationCompleted;
  final String modoStock;
  final TextEditingController? sharedStockCtrl;

  const ProductPresentationList({
    super.key,
    required this.presentationControllers,
    required this.isDark,
    required this.providerListForDropdown,
    this.deferredProviderNames = const {},
    required this.deletePresentation,
    required this.handleCreateLeftover,
    required this.invalidateLeftover,
    required this.onStateChange,
    this.onSetDefault,
    this.onMoveUp,
    this.onMoveDown,
    this.onClone,
    this.presentationKeys,
    this.onBeforeDiscreteMutation,
    this.onDiscreteMutationCompleted,
    this.modoStock = 'INDEPENDIENTE',
    this.sharedStockCtrl,
    this.baseCostCtrl,
  });

  final TextEditingController? baseCostCtrl;

  String _getProviderName(int? providerId, String? deferredName) {
    if (deferredName != null && deferredName.isNotEmpty) {
      return deferredName;
    }
    if (providerId != null &&
        providerId < 0 &&
        deferredProviderNames.containsKey(providerId)) {
      return deferredProviderNames[providerId]!;
    }
    if (providerId == null) return "Usar Principal (Heredado)";
    if (providerId == 0) return "Sin proveedor (Ninguno)";
    final found = providerListForDropdown
        .where((p) => p.id == providerId)
        .firstOrNull;
    return found?.nombreEmpresa ?? "Proveedor #$providerId";
  }

  Future<void> _openProviderModal(
    BuildContext context,
    Map<String, dynamic> ctrlMap,
  ) async {
    final items = <PickerItem<ProviderModel>>[
      const PickerItem(
        id: null,
        name: "Usar Principal (Heredado)",
        isSpecial: true,
      ),
      const PickerItem(
        id: 0,
        name: "Sin proveedor (Ninguno)",
        isSpecial: true,
      ),
    ];

    deferredProviderNames.forEach((id, name) {
      items.add(PickerItem(id: id, name: name, isDeferred: true));
    });

    for (var p in providerListForDropdown) {
      if (p.id > 0 && p.id != -2) {
        items.add(PickerItem(id: p.id, name: p.nombreEmpresa, rawValue: p));
      }
    }

    FocusManager.instance.primaryFocus?.unfocus();
    final res = await ModernEntityPickerModal.show<ProviderModel>(
      context: context,
      title: "Proveedor Específico",
      searchHint: "Buscar proveedor...",
      items: items,
      selectedId: ctrlMap['providerId'],
      createButtonLabel: "+ Crear Proveedor...",
      createDialogTitle: "Nuevo Proveedor",
      createDialogHint: "Nombre de la empresa...",
    );
    FocusManager.instance.primaryFocus?.unfocus();

    if (res != null) {
      onBeforeDiscreteMutation?.call();
      final newId = res.id;
      final newName = (res.id == null || res.id == 0) ? null : res.name;
      if (newId != null && newId < 0 && newName != null) {
        deferredProviderNames[newId] = newName;
        ctrlMap['providerId'] = newId;
        ctrlMap['deferredProviderName'] = newName;
      } else {
        ctrlMap['providerId'] = res.id == 0 ? null : res.id;
        ctrlMap.remove('deferredProviderName');
      }
      onStateChange();
      onDiscreteMutationCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: presentationControllers.asMap().entries.map((entry) {
        int index = entry.key;
        var ctrlMap = entry.value;
        final String cardId = ctrlMap['id'].toString();
        final cardKey = presentationKeys != null && presentationKeys!.containsKey(cardId)
            ? presentationKeys![cardId]!
            : ValueKey(cardId);

        return ProductPresentationCard(
          key: cardKey,
          controllerMap: ctrlMap,
          presentationIndex: index,
          totalPresentations: presentationControllers.length,
          modoStock: modoStock,
          sharedStockCtrl: sharedStockCtrl,
          baseCostCtrl: baseCostCtrl,
          onSetDefault: onSetDefault != null ? () => onSetDefault!(index) : null,
          onMoveUp: onMoveUp != null && index > 0 ? () => onMoveUp!(index) : null,
          onMoveDown: onMoveDown != null && index < presentationControllers.length - 1
              ? () => onMoveDown!(index)
              : null,
          onClone: onClone != null ? () => onClone!(index) : null,
          onDelete: () => deletePresentation(index, isDark),
          onStateChange: (val) {
            onBeforeDiscreteMutation?.call();
            ctrlMap['estado'] = val ? 'publico' : 'privado';
            onStateChange();
            onDiscreteMutationCompleted?.call();
          },
          onCreateLeftover: (leftoverStock, costoBaseIndiv) {
            handleCreateLeftover(ctrlMap['id'], leftoverStock, costoBaseIndiv);
          },
          onInvalidateLeftover: () {
            invalidateLeftover(ctrlMap['id']);
          },
          onBeforeDiscreteMutation: onBeforeDiscreteMutation,
          onDiscreteMutationCompleted: onDiscreteMutationCompleted,
          providerDropdown: ModernEntitySelectorField(
            label: "Proveedor Específico",
            valueText: _getProviderName(
              ctrlMap['providerId'],
              ctrlMap['deferredProviderName'] as String?,
            ),
            icon: Icons.local_shipping_outlined,
            isDeferred: ctrlMap['providerId'] != null &&
                (ctrlMap['providerId'] as int) < 0,
            isDark: isDark,
            isCompact: true,
            onTap: () => _openProviderModal(context, ctrlMap),
          ),
        );
      }).toList(),
    );
  }
}
