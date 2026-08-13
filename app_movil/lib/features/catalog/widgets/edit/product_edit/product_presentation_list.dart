import 'package:flutter/material.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/core/widgets/safe_dropdown.dart';
import 'package:app_movil/core/widgets/product_presentation_card.dart';

class ProductPresentationList extends StatelessWidget {
  final List<Map<String, dynamic>> presentationControllers;
  final bool isDark;
  final List<ProviderModel> providerListForDropdown;
  final Future<int?> Function(bool) handleCreateProvider;
  final Function(int, bool) deletePresentation;
  final Function(String, int, double) handleCreateLeftover;
  final Function(String) invalidateLeftover;
  final VoidCallback onStateChange;

  const ProductPresentationList({
    super.key,
    required this.presentationControllers,
    required this.isDark,
    required this.providerListForDropdown,
    required this.handleCreateProvider,
    required this.deletePresentation,
    required this.handleCreateLeftover,
    required this.invalidateLeftover,
    required this.onStateChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: presentationControllers.asMap().entries.map((entry) {
        int index = entry.key;
        var ctrlMap = entry.value;

        return ProductPresentationCard(
          key: ValueKey(ctrlMap['id']), 
          controllerMap: ctrlMap,
          onDelete: () => deletePresentation(index, isDark),
          onStateChange: (val) {
             ctrlMap['estado'] = val ? 'publico' : 'privado';
             onStateChange();
          },
          onCreateLeftover: (leftoverStock, costoBaseIndiv) {
            handleCreateLeftover(ctrlMap['id'], leftoverStock, costoBaseIndiv);
          },
          onInvalidateLeftover: () {
            invalidateLeftover(ctrlMap['id']);
          },
          providerDropdown: SafeDropdown<ProviderModel>(
            label: "Proveedor Específico", 
            icon: null, 
            value: ctrlMap['providerId'], 
            items: providerListForDropdown,
            getId: (p) => p.id, 
            getName: (p) => p.nombreEmpresa, 
            isActive: (p) => p.activo == true, 
            allowNull: true,
            onChanged: (v) { 
              if (v == -1) { 
                handleCreateProvider(isDark).then((id) { 
                  if (id != null) {
                    ctrlMap['providerId'] = id;
                    onStateChange();
                  }
                }); 
              } else { 
                ctrlMap['providerId'] = v == 0 ? null : v;
                onStateChange();
              } 
            }
          ),
        );
      }).toList(),
    );
  }
}