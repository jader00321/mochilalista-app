import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/widgets/modern_entity_picker_modal.dart';

/// Clase utilitaria para selectores interactivos modernos de Marca, Categoría
/// y Proveedor con soporte para búsqueda, creación diferida transaccional (IDs negativos)
/// y resolución de nombres para pantalla clara y concisa.
class ProductEntityPickers {
  static Future<PickerItem<Brand>?> openBrandPicker({
    required BuildContext context,
    required int? selectedBrandId,
    required String? selectedBrandName,
  }) async {
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final items = <PickerItem<Brand>>[
      const PickerItem(
        id: null,
        name: "Sin marca (Ninguna)",
        isSpecial: true,
      ),
    ];

    if (selectedBrandId != null &&
        selectedBrandId < 0 &&
        selectedBrandName != null) {
      items.add(
        PickerItem(
          id: selectedBrandId,
          name: selectedBrandName,
          isDeferred: true,
        ),
      );
    }

    for (var b in provider.activeBrands) {
      if (!items.any((it) => it.id == b.id)) {
        items.add(PickerItem(id: b.id, name: b.nombre, rawValue: b));
      }
    }

    FocusManager.instance.primaryFocus?.unfocus();
    final result = await ModernEntityPickerModal.show<Brand>(
      context: context,
      title: "Seleccionar Marca",
      searchHint: "Buscar marca...",
      items: items,
      selectedId: selectedBrandId,
      createButtonLabel: "+ Crear Marca...",
      createDialogTitle: "Nueva Marca",
      createDialogHint: "Nombre de la marca...",
    );
    FocusManager.instance.primaryFocus?.unfocus();
    return result;
  }

  static String getBrandDisplay({
    required InventoryProvider provider,
    required int? selectedBrandId,
    required String? selectedBrandName,
  }) {
    if (selectedBrandId != null && selectedBrandId < 0) {
      return selectedBrandName ?? "Nueva Marca";
    }
    if (selectedBrandId == null || selectedBrandId == 0) {
      return "Sin marca (Ninguna)";
    }
    final found =
        provider.brands.where((b) => b.id == selectedBrandId).firstOrNull;
    return found?.nombre ?? selectedBrandName ?? "Marca seleccionada";
  }

  static Future<PickerItem<Category>?> openCategoryPicker({
    required BuildContext context,
    required int? selectedCategoryId,
    required String? selectedCategoryName,
  }) async {
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final items = <PickerItem<Category>>[
      const PickerItem(
        id: null,
        name: "Sin categoría (General)",
        isSpecial: true,
      ),
    ];

    if (selectedCategoryId != null &&
        selectedCategoryId < 0 &&
        selectedCategoryName != null) {
      items.add(
        PickerItem(
          id: selectedCategoryId,
          name: selectedCategoryName,
          isDeferred: true,
        ),
      );
    }

    for (var c in provider.activeCategories) {
      if (!items.any((it) => it.id == c.id)) {
        items.add(PickerItem(id: c.id, name: c.nombre, rawValue: c));
      }
    }

    FocusManager.instance.primaryFocus?.unfocus();
    final result = await ModernEntityPickerModal.show<Category>(
      context: context,
      title: "Seleccionar Categoría",
      searchHint: "Buscar categoría...",
      items: items,
      selectedId: selectedCategoryId,
      createButtonLabel: "+ Crear Categoría...",
      createDialogTitle: "Nueva Categoría",
      createDialogHint: "Nombre de la categoría...",
    );
    FocusManager.instance.primaryFocus?.unfocus();
    return result;
  }

  static String getCategoryDisplay({
    required InventoryProvider provider,
    required int? selectedCategoryId,
    required String? selectedCategoryName,
  }) {
    if (selectedCategoryId != null && selectedCategoryId < 0) {
      return selectedCategoryName ?? "Nueva Categoría";
    }
    if (selectedCategoryId == null || selectedCategoryId == 0) {
      return "Sin categoría (General)";
    }
    final found = provider.categories
        .where((c) => c.id == selectedCategoryId)
        .firstOrNull;
    return found?.nombre ?? selectedCategoryName ?? "Categoría seleccionada";
  }

  static Future<PickerItem<ProviderModel>?> openProviderPicker({
    required BuildContext context,
    required int? selectedProviderId,
    required String title,
    required Map<int, String> deferredProviderNames,
  }) async {
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final items = <PickerItem<ProviderModel>>[
      const PickerItem(
        id: null,
        name: "Sin proveedor (Ninguno)",
        isSpecial: true,
      ),
    ];

    if (selectedProviderId != null &&
        selectedProviderId < 0 &&
        deferredProviderNames.containsKey(selectedProviderId)) {
      items.add(
        PickerItem(
          id: selectedProviderId,
          name: deferredProviderNames[selectedProviderId]!,
          isDeferred: true,
        ),
      );
    }

    for (var pr in provider.activeProviders) {
      if (!items.any((it) => it.id == pr.id)) {
        items.add(
          PickerItem(id: pr.id, name: pr.nombreEmpresa, rawValue: pr),
        );
      }
    }

    FocusManager.instance.primaryFocus?.unfocus();
    final result = await ModernEntityPickerModal.show<ProviderModel>(
      context: context,
      title: title,
      searchHint: "Buscar proveedor...",
      items: items,
      selectedId: selectedProviderId,
      createButtonLabel: "+ Crear Proveedor...",
      createDialogTitle: "Nuevo Proveedor",
      createDialogHint: "Nombre del proveedor / empresa...",
    );
    FocusManager.instance.primaryFocus?.unfocus();
    return result;
  }

  static String getProviderDisplay({
    required InventoryProvider provider,
    required int? providerId,
    required Map<int, String> deferredProviderNames,
    String? localDeferredName,
  }) {
    if (providerId == -2) return "Varios Proveedores";
    if (providerId != null && providerId < 0) {
      return localDeferredName ??
          deferredProviderNames[providerId] ??
          "Nuevo Proveedor";
    }
    if (providerId == null || providerId == 0) {
      return "Sin proveedor (Ninguno)";
    }
    final found =
        provider.providers.where((p) => p.id == providerId).firstOrNull;
    return found?.nombreEmpresa ?? "Proveedor seleccionado";
  }
}
