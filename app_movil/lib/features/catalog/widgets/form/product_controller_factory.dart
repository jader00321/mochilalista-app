import 'package:flutter/material.dart';

/// Fábrica y gestor de ciclo de vida para mapas de controladores de presentación.
/// Centraliza la instanciación, clonación, creación de variantes sueltas y liberación (dispose)
/// garantizando que ningún TextEditingController quede huérfano en memoria.
class ProductControllerFactory {
  static void disposeControllerMap(Map<String, dynamic> map) {
    (map['specific'] as TextEditingController).dispose();
    (map['unidadVenta'] as TextEditingController).dispose();
    (map['unidadesVenta'] as TextEditingController).dispose();
    (map['costoPres'] as TextEditingController).dispose();
    (map['margen'] as TextEditingController).dispose();
    (map['precioVenta'] as TextEditingController).dispose();
    (map['stockInicial'] as TextEditingController).dispose();
    (map['nuevoIngreso'] as TextEditingController).dispose();
    (map['stockDescuento'] as TextEditingController).dispose();
    (map['stockFinal'] as TextEditingController).dispose();
    (map['valorDescuento'] as TextEditingController).dispose();
    (map['umpCompra'] as TextEditingController).dispose();
    (map['unidadesLote'] as TextEditingController).dispose();
    (map['cantCompra'] as TextEditingController).dispose();
    (map['totalPago'] as TextEditingController).dispose();
    (map['barcode'] as TextEditingController).dispose();
    (map['desc'] as TextEditingController).dispose();
    (map['image'] as TextEditingController).dispose();
    (map['ajusteBase'] as TextEditingController).dispose();
  }

  static Map<String, dynamic> createNewControllerMap({
    required String id,
    int? dbId,
    bool isDefault = false,
    bool isExpanded = true,
    bool isEditMode = false,
    String specificName = "",
    String unidadVenta = "Unidad",
    String unidadesVenta = "1",
    String costoPres = "0.00",
    String margen = "1.35",
    String precioVenta = "0.00",
    String stockInicial = "0",
    String nuevoIngreso = "0",
    String stockDescuento = "0",
    String stockFinal = "0",
    String umpCompra = "",
    String unidadesLote = "1",
    String cantCompra = "",
    String totalPago = "",
    String barcode = "",
    String desc = "",
    String image = "",
    String ajusteBase = "",
    int? providerId,
    String? deferredProviderName,
    String estado = 'publico',
    bool descuentoActivo = false,
    String tipoDescuento = 'porcentaje',
    String valorDescuento = "",
    int? stockBaseOriginal,
    double? costoBaseOriginal,
    double? precioOfertaExacto,
  }) {
    final map = <String, dynamic>{
      'id': id,
      'db_id': dbId,
      'isEditMode': isEditMode,
      'isExpanded': isExpanded,
      'childId': null,
      'leftoverCreated': false,
      'isDefault': isDefault,
      'estado': estado,
      'providerId': providerId,

      'specific': TextEditingController(text: specificName),
      'unidadVenta': TextEditingController(text: unidadVenta),
      'unidadesVenta': TextEditingController(text: unidadesVenta),

      'costoPres': TextEditingController(text: costoPres),
      'margen': TextEditingController(text: margen),
      'precioVenta': TextEditingController(text: precioVenta),

      'descuentoActivo': descuentoActivo,
      'tipoDescuento': tipoDescuento,
      'valorDescuento': TextEditingController(text: valorDescuento),
      'precioOfertaExacto': precioOfertaExacto,

      'stockInicial': TextEditingController(text: stockInicial),
      'nuevoIngreso': TextEditingController(text: nuevoIngreso),
      'stockDescuento': TextEditingController(text: stockDescuento),
      'stockFinal': TextEditingController(text: stockFinal),
      'ajusteBase': TextEditingController(text: ajusteBase),

      'umpCompra': TextEditingController(text: umpCompra),
      'unidadesLote': TextEditingController(text: unidadesLote),
      'cantCompra': TextEditingController(text: cantCompra),
      'totalPago': TextEditingController(text: totalPago),

      'barcode': TextEditingController(text: barcode),
      'desc': TextEditingController(text: desc),
      'image': TextEditingController(text: image),
    };

    if (deferredProviderName != null) {
      map['deferredProviderName'] = deferredProviderName;
    }
    if (stockBaseOriginal != null) {
      map['stockBaseOriginal'] = stockBaseOriginal;
    }
    if (costoBaseOriginal != null) {
      map['costoBaseOriginal'] = costoBaseOriginal;
    }

    return map;
  }

  static Map<String, dynamic> cloneControllerMap({
    required Map<String, dynamic> source,
    required String newId,
  }) {
    final map = createNewControllerMap(
      id: newId,
      dbId: null, // Variante clonada es una nueva entidad
      isDefault: false,
      isExpanded: true,
      isEditMode: source['isEditMode'] == true,
      specificName: (source['specific'] as TextEditingController).text,
      unidadVenta: (source['unidadVenta'] as TextEditingController).text,
      unidadesVenta: (source['unidadesVenta'] as TextEditingController).text,
      costoPres: (source['costoPres'] as TextEditingController).text,
      margen: (source['margen'] as TextEditingController).text,
      precioVenta: (source['precioVenta'] as TextEditingController).text,
      stockInicial: (source['stockInicial'] as TextEditingController).text,
      nuevoIngreso: (source['nuevoIngreso'] as TextEditingController).text,
      stockDescuento: (source['stockDescuento'] as TextEditingController).text,
      stockFinal: (source['stockFinal'] as TextEditingController).text,
      umpCompra: (source['umpCompra'] as TextEditingController).text,
      unidadesLote: (source['unidadesLote'] as TextEditingController).text,
      cantCompra: (source['cantCompra'] as TextEditingController).text,
      totalPago: (source['totalPago'] as TextEditingController).text,
      barcode: (source['barcode'] as TextEditingController).text,
      desc: (source['desc'] as TextEditingController).text,
      image: (source['image'] as TextEditingController).text,
      ajusteBase: (source['ajusteBase'] as TextEditingController).text,
      providerId: source['providerId'],
      deferredProviderName: source['deferredProviderName'],
      estado: source['estado'] ?? 'publico',
      descuentoActivo: source['descuentoActivo'] == true,
      tipoDescuento: source['tipoDescuento'] ?? 'porcentaje',
      valorDescuento: (source['valorDescuento'] as TextEditingController).text,
      stockBaseOriginal: source['stockBaseOriginal'],
      costoBaseOriginal: source['costoBaseOriginal'],
      precioOfertaExacto: source['precioOfertaExacto'] as double?,
    );
    map['activeRoundingTarget'] = source['activeRoundingTarget'] as double?;
    map['preRoundedPrice'] = source['preRoundedPrice'] as String?;
    map['preRoundedMargen'] = source['preRoundedMargen'] as String?;
    map['activeDiscountRoundingTarget'] =
        source['activeDiscountRoundingTarget'] as double?;
    map['preRoundedDiscountValor'] =
        source['preRoundedDiscountValor'] as String?;
    return map;
  }

  static Map<String, dynamic> createLeftoverControllerMap({
    required Map<String, dynamic> parentMap,
    required String newChildId,
    required int leftoverUnits,
    required double costoBaseIndividual,
  }) {
    final parentSpec = (parentMap['specific'] as TextEditingController).text;
    final specName = parentSpec.isNotEmpty ? "$parentSpec - Suelta" : "Suelta";

    return createNewControllerMap(
      id: newChildId,
      dbId: null,
      isDefault: false,
      isExpanded: true,
      isEditMode: parentMap['isEditMode'] == true,
      specificName: specName,
      unidadVenta: "Unidad",
      unidadesVenta: "1",
      costoPres: costoBaseIndividual.toStringAsFixed(2),
      margen: "1.35",
      precioVenta: (costoBaseIndividual * 1.35).toStringAsFixed(2),
      stockInicial: leftoverUnits.toString(),
      nuevoIngreso: "0",
      stockDescuento: "0",
      stockFinal: leftoverUnits.toString(),
      providerId: parentMap['providerId'],
      deferredProviderName: parentMap['deferredProviderName'],
      estado: parentMap['estado'] ?? 'publico',
      stockBaseOriginal: leftoverUnits,
      costoBaseOriginal: costoBaseIndividual,
    );
  }
}
