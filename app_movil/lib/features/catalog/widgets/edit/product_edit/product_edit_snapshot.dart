import 'package:flutter/material.dart';
import 'package:app_movil/features/catalog/widgets/form/product_controller_factory.dart';

/// 📸 Snapshot inmutable de una presentación individual
@immutable
class PresentationSnapshot {
  final String id;
  final int? dbId;
  final bool isDefault;
  final String estado;
  final int? providerId;
  final String? deferredProviderName;
  final String specific;
  final String unidadVenta;
  final String unidadesVenta;
  final String costoPres;
  final String margen;
  final String precioVenta;
  final bool descuentoActivo;
  final String tipoDescuento;
  final String valorDescuento;
  final String stockInicial;
  final String nuevoIngreso;
  final String stockDescuento;
  final String stockFinal;
  final String ajusteBase;
  final String umpCompra;
  final String unidadesLote;
  final String cantCompra;
  final String totalPago;
  final String barcode;
  final String desc;
  final String image;
  final double? activeRoundingTarget;
  final String? preRoundedPrice;
  final String? preRoundedMargen;

  const PresentationSnapshot({
    required this.id,
    this.dbId,
    required this.isDefault,
    required this.estado,
    this.providerId,
    this.deferredProviderName,
    required this.specific,
    required this.unidadVenta,
    required this.unidadesVenta,
    required this.costoPres,
    required this.margen,
    required this.precioVenta,
    required this.descuentoActivo,
    required this.tipoDescuento,
    required this.valorDescuento,
    required this.stockInicial,
    required this.nuevoIngreso,
    required this.stockDescuento,
    required this.stockFinal,
    required this.ajusteBase,
    required this.umpCompra,
    required this.unidadesLote,
    required this.cantCompra,
    required this.totalPago,
    required this.barcode,
    required this.desc,
    required this.image,
    this.activeRoundingTarget,
    this.preRoundedPrice,
    this.preRoundedMargen,
  });

  factory PresentationSnapshot.fromControllerMap(Map<String, dynamic> map) {
    String textOf(dynamic ctrl) {
      if (ctrl is TextEditingController) return ctrl.text.trim();
      return (ctrl ?? "").toString().trim();
    }

    return PresentationSnapshot(
      id: map['id']?.toString() ?? "",
      dbId: map['db_id'] as int?,
      isDefault: map['isDefault'] == true,
      estado: map['estado']?.toString() ?? 'publico',
      providerId: map['providerId'] as int?,
      deferredProviderName: map['deferredProviderName'] as String?,
      specific: textOf(map['specific']),
      unidadVenta: textOf(map['unidadVenta']),
      unidadesVenta: textOf(map['unidadesVenta']),
      costoPres: textOf(map['costoPres']),
      margen: textOf(map['margen']),
      precioVenta: textOf(map['precioVenta']),
      descuentoActivo: map['descuentoActivo'] == true,
      tipoDescuento: map['tipoDescuento']?.toString() ?? 'porcentaje',
      valorDescuento: textOf(map['valorDescuento']),
      stockInicial: textOf(map['stockInicial']),
      nuevoIngreso: textOf(map['nuevoIngreso']),
      stockDescuento: textOf(map['stockDescuento']),
      stockFinal: textOf(map['stockFinal']),
      ajusteBase: textOf(map['ajusteBase']),
      umpCompra: textOf(map['umpCompra']),
      unidadesLote: textOf(map['unidadesLote']),
      cantCompra: textOf(map['cantCompra']),
      totalPago: textOf(map['totalPago']),
      barcode: textOf(map['barcode']),
      desc: textOf(map['desc']),
      image: textOf(map['image']),
      activeRoundingTarget: map['activeRoundingTarget'] as double?,
      preRoundedPrice: map['preRoundedPrice'] as String?,
      preRoundedMargen: map['preRoundedMargen'] as String?,
    );
  }

  bool isIdenticalTo(PresentationSnapshot other) {
    if (dbId != other.dbId) return false;
    if (isDefault != other.isDefault) return false;
    if (estado != other.estado) return false;

    // Normalizar providerId (null y 0 son equivalentes a sin proveedor, ids < 0 son diferidos)
    final p1 = (providerId == null || providerId == 0) ? null : providerId;
    final p2 = (other.providerId == null || other.providerId == 0) ? null : other.providerId;
    if (p1 != p2) return false;
    if (deferredProviderName != other.deferredProviderName) return false;

    if (activeRoundingTarget != other.activeRoundingTarget) return false;
    if (preRoundedPrice != other.preRoundedPrice) return false;
    if (preRoundedMargen != other.preRoundedMargen) return false;

    if (specific != other.specific) return false;
    if (unidadVenta != other.unidadVenta) return false;
    if (unidadesVenta != other.unidadesVenta) return false;

    // Comparar valores numéricos de precio y costo con tolerancia a formateo decimal
    final pv1 = double.tryParse(precioVenta) ?? 0.0;
    final pv2 = double.tryParse(other.precioVenta) ?? 0.0;
    if ((pv1 - pv2).abs() > 0.005) return false;

    final c1 = double.tryParse(costoPres) ?? 0.0;
    final c2 = double.tryParse(other.costoPres) ?? 0.0;
    if ((c1 - c2).abs() > 0.005) return false;

    final m1 = double.tryParse(margen) ?? 0.0;
    final m2 = double.tryParse(other.margen) ?? 0.0;
    if ((m1 - m2).abs() > 0.01) return false;

    if (descuentoActivo != other.descuentoActivo) return false;
    if (descuentoActivo) {
      if (tipoDescuento != other.tipoDescuento) return false;
      final vd1 = double.tryParse(valorDescuento) ?? 0.0;
      final vd2 = double.tryParse(other.valorDescuento) ?? 0.0;
      if ((vd1 - vd2).abs() > 0.005) return false;
    }

    if (stockInicial != other.stockInicial) return false;
    if (nuevoIngreso != other.nuevoIngreso) return false;
    if (stockDescuento != other.stockDescuento) return false;
    if (stockFinal != other.stockFinal) return false;

    if (barcode != other.barcode) return false;
    if (desc != other.desc) return false;
    if (image != other.image) return false;

    if (umpCompra != other.umpCompra) return false;
    if (unidadesLote != other.unidadesLote) return false;
    if (cantCompra != other.cantCompra) return false;
    if (totalPago != other.totalPago) return false;

    return true;
  }
}

/// 🌟 Snapshot inmutable de toda la pantalla ProductEditScreen
@immutable
class ProductEditSnapshot {
  final String name;
  final String desc;
  final String imgUrl;
  final String barcode;
  final int? categoryId;
  final String? categoryName;
  final int? brandId;
  final String? brandName;
  final int? generalProviderId;
  final String? generalProviderName;
  final int generalState;
  final List<int> idsToDelete;
  final List<PresentationSnapshot> presentations;

  const ProductEditSnapshot({
    required this.name,
    required this.desc,
    required this.imgUrl,
    required this.barcode,
    this.categoryId,
    this.categoryName,
    this.brandId,
    this.brandName,
    this.generalProviderId,
    this.generalProviderName,
    required this.generalState,
    required this.idsToDelete,
    required this.presentations,
  });

  static ProductEditSnapshot capture({
    required TextEditingController nameCtrl,
    required TextEditingController descCtrl,
    required TextEditingController imgUrlCtrl,
    required TextEditingController parentBarcodeCtrl,
    required int? selectedCategoryId,
    required String? selectedCategoryName,
    required int? selectedBrandId,
    required String? selectedBrandName,
    required int? generalProviderId,
    String? generalProviderName,
    required int generalState,
    required List<int> idsToDelete,
    required List<Map<String, dynamic>> presentationControllers,
  }) {
    return ProductEditSnapshot(
      name: nameCtrl.text.trim(),
      desc: descCtrl.text.trim(),
      imgUrl: imgUrlCtrl.text.trim(),
      barcode: parentBarcodeCtrl.text.trim(),
      categoryId: (selectedCategoryId == null || selectedCategoryId <= 0) ? null : selectedCategoryId,
      categoryName: selectedCategoryName,
      brandId: (selectedBrandId == null || selectedBrandId <= 0) ? null : selectedBrandId,
      brandName: selectedBrandName,
      generalProviderId: (generalProviderId == null || generalProviderId == 0) ? null : generalProviderId,
      generalProviderName: generalProviderName,
      generalState: generalState,
      idsToDelete: List.unmodifiable(idsToDelete),
      presentations: List.unmodifiable(
        presentationControllers.map((m) => PresentationSnapshot.fromControllerMap(m)),
      ),
    );
  }

  bool isIdenticalTo(ProductEditSnapshot other) {
    if (name != other.name) return false;
    if (desc != other.desc) return false;
    if (imgUrl != other.imgUrl) return false;
    if (barcode != other.barcode) return false;

    if (categoryId != other.categoryId) return false;
    if (categoryName != other.categoryName) return false;
    if (brandId != other.brandId) return false;
    if (brandName != other.brandName) return false;
    if (generalProviderId != other.generalProviderId) return false;
    if (generalProviderName != other.generalProviderName) return false;
    if (generalState != other.generalState) return false;

    if (idsToDelete.length != other.idsToDelete.length) return false;
    for (int i = 0; i < idsToDelete.length; i++) {
      if (idsToDelete[i] != other.idsToDelete[i]) return false;
    }

    if (presentations.length != other.presentations.length) return false;
    for (int i = 0; i < presentations.length; i++) {
      if (!presentations[i].isIdenticalTo(other.presentations[i])) {
        return false;
      }
    }

    return true;
  }

  /// Restaura los datos del snapshot en los controladores y mapas existentes
  void restoreInto({
    required TextEditingController nameCtrl,
    required TextEditingController descCtrl,
    required TextEditingController imgUrlCtrl,
    required TextEditingController parentBarcodeCtrl,
    required List<Map<String, dynamic>> targetControllers,
    required Map<String, GlobalKey> targetKeys,
    required List<int> targetIdsToDelete,
  }) {
    nameCtrl.text = name;
    descCtrl.text = desc;
    imgUrlCtrl.text = imgUrl;
    parentBarcodeCtrl.text = barcode;

    targetIdsToDelete.clear();
    targetIdsToDelete.addAll(idsToDelete);

    // Liberar controladores previos
    for (var m in targetControllers) {
      ProductControllerFactory.disposeControllerMap(m);
    }
    targetControllers.clear();
    targetKeys.clear();

    // Reconstruir controladores desde el snapshot
    for (var p in presentations) {
      final keyId = p.id.isNotEmpty ? p.id : UniqueKey().toString();
      targetKeys[keyId] = GlobalKey();

      final newMap = ProductControllerFactory.createNewControllerMap(
        id: keyId,
        dbId: p.dbId,
        isDefault: p.isDefault,
        isExpanded: p.isDefault,
        isEditMode: true,
        specificName: p.specific,
        unidadVenta: p.unidadVenta,
        unidadesVenta: p.unidadesVenta,
        costoPres: p.costoPres,
        margen: p.margen,
        precioVenta: p.precioVenta,
        stockInicial: p.stockInicial,
        nuevoIngreso: p.nuevoIngreso,
        stockDescuento: p.stockDescuento,
        stockFinal: p.stockFinal,
        umpCompra: p.umpCompra,
        unidadesLote: p.unidadesLote,
        cantCompra: p.cantCompra,
        totalPago: p.totalPago,
        barcode: p.barcode,
        desc: p.desc,
        image: p.image,
        providerId: p.providerId,
        deferredProviderName: p.deferredProviderName,
        estado: p.estado,
        descuentoActivo: p.descuentoActivo,
        tipoDescuento: p.tipoDescuento,
        valorDescuento: p.valorDescuento,
      );

      newMap['activeRoundingTarget'] = p.activeRoundingTarget;
      newMap['preRoundedPrice'] = p.preRoundedPrice;
      newMap['preRoundedMargen'] = p.preRoundedMargen;

      targetControllers.add(newMap);
    }
  }
}
