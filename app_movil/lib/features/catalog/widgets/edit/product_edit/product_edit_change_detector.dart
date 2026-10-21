import 'package:flutter/material.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/widgets/edit/product_edit/product_edit_snapshot.dart';

/// Detector forense de modificaciones sin guardar para ProductEditScreen.
/// Compara en profundidad el estado de todos los controladores contra el modelo original
/// o contra el snapshot inicial canónico para blindar la salida accidental mediante PopScope.
class ProductEditChangeDetector {
  static bool hasUnsavedChanges({
    required bool isDirty,
    required Product productToEdit,
    required TextEditingController nameCtrl,
    required TextEditingController descCtrl,
    required TextEditingController imgUrlCtrl,
    required TextEditingController parentBarcodeCtrl,
    required int? selectedBrandId,
    required String? selectedBrandName,
    required int? selectedCategoryId,
    required String? selectedCategoryName,
    required int? generalProviderId,
    String? generalProviderName,
    required List<int> idsToDelete,
    required List<Map<String, dynamic>> presentationControllers,
    ProductEditSnapshot? initialSnapshot,
    int generalState = 2,
  }) {
    if (initialSnapshot != null) {
      final current = ProductEditSnapshot.capture(
        nameCtrl: nameCtrl,
        descCtrl: descCtrl,
        imgUrlCtrl: imgUrlCtrl,
        parentBarcodeCtrl: parentBarcodeCtrl,
        selectedCategoryId: selectedCategoryId,
        selectedCategoryName: selectedCategoryName,
        selectedBrandId: selectedBrandId,
        selectedBrandName: selectedBrandName,
        generalProviderId: generalProviderId,
        generalProviderName: generalProviderName,
        generalState: generalState,
        idsToDelete: idsToDelete,
        presentationControllers: presentationControllers,
      );
      return !current.isIdenticalTo(initialSnapshot);
    }

    if (isDirty) return true;
    final p = productToEdit;
    if (nameCtrl.text.trim() != p.nombre.trim()) return true;
    if (descCtrl.text.trim() != (p.descripcion ?? "").trim()) return true;
    final normBrand = (selectedBrandId == null || selectedBrandId <= 0)
        ? null
        : selectedBrandId;
    final normOrigBrand =
        (p.marcaId == null || p.marcaId! <= 0) ? null : p.marcaId;
    if (normBrand != normOrigBrand) return true;

    if (selectedBrandName != null &&
        selectedBrandName.trim().isNotEmpty &&
        selectedBrandId != null &&
        selectedBrandId < 0) {
      return true;
    }

    final normCat = (selectedCategoryId == null || selectedCategoryId <= 0)
        ? null
        : selectedCategoryId;
    final normOrigCat = (p.categoriaId <= 0) ? null : p.categoriaId;
    if (normCat != normOrigCat) return true;

    if (selectedCategoryName != null &&
        selectedCategoryName.trim().isNotEmpty &&
        selectedCategoryId != null &&
        selectedCategoryId < 0) {
      return true;
    }

    // Normalización de Proveedor General (null y <= 0 equivalentes)
    int? origGeneralProvId;
    if (p.presentaciones.isNotEmpty) {
      final firstNorm = (p.presentaciones.first.proveedorId == null ||
              p.presentaciones.first.proveedorId! <= 0)
          ? null
          : p.presentaciones.first.proveedorId;
      bool allSame = true;
      for (final pres in p.presentaciones) {
        final presNorm = (pres.proveedorId == null || pres.proveedorId! <= 0)
            ? null
            : pres.proveedorId;
        if (presNorm != firstNorm) {
          allSame = false;
          break;
        }
      }
      origGeneralProvId = allSame ? firstNorm : -2;
    }

    final normGeneralProv = (generalProviderId == null ||
            (generalProviderId <= 0 && generalProviderId != -2))
        ? null
        : generalProviderId;

    if (normGeneralProv != origGeneralProvId) {
      return true;
    }
    if (generalProviderId != null &&
        generalProviderId < 0 &&
        generalProviderId != -2) {
      return true;
    }

    if (imgUrlCtrl.text.trim() != (p.imagenUrl ?? "").trim()) return true;
    if (parentBarcodeCtrl.text.trim() != (p.codigoBarras ?? "").trim()) {
      return true;
    }
    if (idsToDelete.isNotEmpty) return true;
    if (presentationControllers.length != p.presentaciones.length) return true;

    final sortedOrig = List<ProductPresentation>.from(p.presentaciones)
      ..sort((a, b) {
        if (a.esDefault && !b.esDefault) return -1;
        if (!a.esDefault && b.esDefault) return 1;
        if (a.orden != b.orden) return a.orden.compareTo(b.orden);
        return (a.id ?? 0).compareTo(b.id ?? 0);
      });

    // Comparar cada controlador de presentación contra el modelo original
    for (int i = 0; i < presentationControllers.length; i++) {
      final ctrl = presentationControllers[i];
      final dbId = ctrl['db_id'] as int?;
      if (dbId == null) return true; // Variante añadida o clonada

      ProductPresentation? orig;
      for (final op in p.presentaciones) {
        if (op.id == dbId) {
          orig = op;
          break;
        }
      }
      if (orig == null) return true;

      // Reordenamiento canónico
      if (i < sortedOrig.length && sortedOrig[i].id != dbId) {
        return true;
      }

      // Variante Principal
      if ((ctrl['isDefault'] == true) != orig.esDefault) return true;

      // Estado
      if (ctrl['estado'] != orig.estado) return true;

      // Nombre y unidades
      if ((ctrl['specific'] as TextEditingController).text.trim() !=
          (orig.nombreEspecifico ?? "").trim()) {
        return true;
      }
      if ((ctrl['unidadVenta'] as TextEditingController).text.trim() !=
          (orig.unidadVenta ?? "Unidad").trim()) {
        return true;
      }
      final factorVal = int.tryParse(
              (ctrl['unidadesVenta'] as TextEditingController).text.trim()) ??
          1;
      if (factorVal != orig.unidadesPorVenta) {
        return true;
      }

      // Precio y costo
      final pVentaText =
          (ctrl['precioVenta'] as TextEditingController).text.trim();
      final pVentaVal = double.tryParse(pVentaText);
      if (pVentaVal != null &&
          (pVentaVal - orig.precioVentaFinal).abs() > 0.005) {
        return true;
      }

      final costoText =
          (ctrl['costoPres'] as TextEditingController).text.trim();
      final costoVal = double.tryParse(costoText);
      final origCostoVal = orig.costoUnitarioCalculado ?? 0.0;
      if (costoVal != null && (costoVal - origCostoVal).abs() > 0.005) {
        return true;
      }

      final margenText =
          (ctrl['margen'] as TextEditingController).text.trim();
      final margenVal = double.tryParse(margenText);
      final origMargenVal = orig.factorGananciaVenta ?? 1.35;
      if (margenVal != null && (margenVal - origMargenVal).abs() > 0.01) {
        return true;
      }

      // Movimiento de stock
      final nuevoIng =
          (ctrl['nuevoIngreso'] as TextEditingController).text.trim();
      if (nuevoIng.isNotEmpty && nuevoIng != "0") return true;

      final stockDesc =
          (ctrl['stockDescuento'] as TextEditingController).text.trim();
      if (stockDesc.isNotEmpty && stockDesc != "0") return true;

      // Descuentos
      final origDescActivo =
          orig.precioOferta != null && orig.precioOferta! > 0;
      if ((ctrl['descuentoActivo'] == true) != origDescActivo) return true;
      if ((ctrl['valorDescuento'] as TextEditingController).text.trim() !=
          (orig.valorDescuento?.toStringAsFixed(2) ?? "")) {
        return true;
      }

      // Código y detalles
      if ((ctrl['barcode'] as TextEditingController).text.trim() !=
          (orig.codigoBarras ?? "").trim()) {
        return true;
      }
      if ((ctrl['desc'] as TextEditingController).text.trim() !=
          (orig.descripcion ?? "").trim()) {
        return true;
      }
      if ((ctrl['image'] as TextEditingController).text.trim() !=
          (orig.imagenUrl ?? "").trim()) {
        return true;
      }

      // Datos de compra
      if (ctrl['umpCompra'] is TextEditingController &&
          (ctrl['umpCompra'] as TextEditingController).text.trim() !=
              (orig.umpCompra ?? "").trim()) {
        return true;
      }
      if (ctrl['unidadesLote'] is TextEditingController) {
        final ctrlLote =
            (ctrl['unidadesLote'] as TextEditingController).text.trim();
        final origLote =
            (orig.unidadesPorLote == 0 || orig.unidadesPorLote == 1)
                ? "1"
                : orig.unidadesPorLote.toString();
        if (ctrlLote.isNotEmpty &&
            ctrlLote != orig.unidadesPorLote.toString() &&
            ctrlLote != origLote) {
          return true;
        }
      }
      if (ctrl['cantCompra'] is TextEditingController &&
          (ctrl['cantCompra'] as TextEditingController).text.trim() !=
              (orig.cantidadUmpComprada?.toStringAsFixed(2) ?? "")) {
        return true;
      }
      if (ctrl['totalPago'] is TextEditingController &&
          (ctrl['totalPago'] as TextEditingController).text.trim() !=
              (orig.totalPagoLote?.toStringAsFixed(2) ?? "")) {
        return true;
      }

      // Proveedor (null y <= 0 equivalentes)
      final normCtrlProv = (ctrl['providerId'] == null ||
              (ctrl['providerId'] as num) <= 0)
          ? null
          : (ctrl['providerId'] as num).toInt();
      final normOrigProv =
          (orig.proveedorId == null || orig.proveedorId! <= 0)
              ? null
              : orig.proveedorId;
      if (normCtrlProv != normOrigProv) return true;
      if (ctrl['providerId'] != null && (ctrl['providerId'] as int) < 0) {
        return true;
      }
    }
    return false;
  }
}
