import 'package:flutter/material.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';

/// Mapper utilitario para convertir los mapas de controladores reactivos de la UI
/// a instancias de modelo ProductPresentation para persistencia atómica en SQLite.
class ProductFormMapper {
  static List<ProductPresentation> toPresentations({
    required List<Map<String, dynamic>> controllers,
    String? defaultDesc,
    String? defaultImg,
    String? defaultBarcode,
    String modoStock = 'INDEPENDIENTE',
    int stockCompartido = 0,
  }) {
    final List<ProductPresentation> presentacionesFinales = [];
    final pDesc = defaultDesc?.trim() ?? "";
    final pImg = defaultImg?.trim() ?? "";
    final pCode = defaultBarcode?.trim() ?? "";

    for (int i = 0; i < controllers.length; i++) {
      final c = controllers[i];

      String specific = (c['specific'] as TextEditingController).text.trim();
      String uVenta = (c['unidadVenta'] as TextEditingController).text.trim();
      int factorVenta = int.tryParse(
            (c['unidadesVenta'] as TextEditingController).text,
          ) ??
          1;
      if (factorVenta <= 0) factorVenta = 1;

      double costoPresFinal = double.tryParse(
            (c['costoPres'] as TextEditingController).text,
          ) ??
          0.0;
      double margen = double.tryParse(
            (c['margen'] as TextEditingController).text,
          ) ??
          1.35;
      double pVenta = double.tryParse(
            (c['precioVenta'] as TextEditingController).text,
          ) ??
          0.0;

      int stockVisual = int.tryParse(
            (c['stockFinal'] as TextEditingController).text,
          ) ??
          0;
      int stockBaseGuardar = stockVisual * factorVenta;

      bool isShared = false;
      if (modoStock == 'COMPARTIDO') {
        isShared = true;
      } else if (modoStock == 'MIXTO') {
        isShared = c['usaStockCompartido'] == true;
      }

      int finalStockBase = isShared ? stockCompartido : stockBaseGuardar;

      String umpC = (c['umpCompra'] as TextEditingController).text.trim();
      int loteC = int.tryParse(
            (c['unidadesLote'] as TextEditingController).text,
          ) ??
          1;
      if (loteC <= 0) loteC = 1;
      double cantC = double.tryParse(
            (c['cantCompra'] as TextEditingController).text,
          ) ??
          0.0;
      double totalP = double.tryParse(
            (c['totalPago'] as TextEditingController).text,
          ) ??
          0.0;

      String rawDesc = (c['desc'] as TextEditingController).text.trim();
      String? finalDesc = (rawDesc.isEmpty && pDesc.isNotEmpty)
          ? pDesc
          : (rawDesc.isEmpty ? null : rawDesc);
      String rawImg = (c['image'] as TextEditingController).text.trim();
      String? finalImg = (rawImg.isEmpty && pImg.isNotEmpty)
          ? pImg
          : (rawImg.isEmpty ? null : rawImg);
      String rawCode = (c['barcode'] as TextEditingController).text.trim();
      String? finalCode = (rawCode.isEmpty && pCode.isNotEmpty)
          ? pCode
          : (rawCode.isEmpty ? null : rawCode);

      bool descuentoActivo = c['descuentoActivo'] == true;
      String tipoDescuento = (c['tipoDescuento'] as String?) ?? 'porcentaje';
      final bool isFijo = tipoDescuento == 'monto' || tipoDescuento == 'fijo';
      double valorDescuentoInput = double.tryParse(
            (c['valorDescuento'] as TextEditingController).text,
          ) ??
          0.0;

      double? precioOferta;
      if (descuentoActivo && valorDescuentoInput > 0 && pVenta > 0) {
        if (c['precioOfertaExacto'] != null &&
            (c['precioOfertaExacto'] as num) > 0 &&
            (c['precioOfertaExacto'] as num) < pVenta) {
          precioOferta = (c['precioOfertaExacto'] as num).toDouble();
        } else if (!isFijo) {
          precioOferta = pVenta - (pVenta * (valorDescuentoInput / 100));
        } else {
          // En modo S/ Fijo, el valor ingresado es directamente el Precio Oferta deseado
          if (valorDescuentoInput < pVenta) {
            precioOferta = valorDescuentoInput;
          }
        }
      }

      final int? rawProvId = c['providerId'] as int?;
      final bool isProvDeferred = rawProvId != null && rawProvId < 0;

      int? cupoFinal;
      if (isShared) {
        final maxFisico = factorVenta > 0 ? (stockCompartido ~/ factorVenta) : stockCompartido;
        if (c['cupoMaximoVariante'] != null) {
          final cVal = (c['cupoMaximoVariante'] as num).toInt();
          cupoFinal = cVal <= maxFisico ? cVal : maxFisico;
        } else if (stockVisual > 0 && stockVisual < maxFisico) {
          cupoFinal = stockVisual;
        }
      }

      presentacionesFinales.add(
        ProductPresentation(
          id: c['db_id'] as int?,
          nombreEspecifico: specific.isEmpty ? null : specific,
          unidadVenta: uVenta.isEmpty ? "Unidad" : uVenta,
          unidadesPorVenta: factorVenta,
          costoUnitarioCalculado: costoPresFinal,
          factorGananciaVenta: margen,
          precioVentaFinal: pVenta,
          stockActual: finalStockBase,
          usaStockCompartido: isShared,
          cupoMaximoVariante: isShared ? cupoFinal : null,
          umpCompra: umpC.isEmpty ? null : umpC,
          cantidadUmpComprada: cantC > 0 ? cantC : null,
          totalPagoLote: totalP > 0 ? totalP : null,
          unidadesPorLote: loteC,
          precioUmpProveedor: cantC > 0 ? (totalP / cantC) : null,
          codigoBarras: finalCode,
          imagenUrl: finalImg,
          descripcion: finalDesc,
          proveedorId: isProvDeferred ? null : rawProvId,
          deferredProviderName: isProvDeferred
              ? (c['deferredProviderName'] as String?)
              : null,
          esDefault: c['isDefault'] == true,
          orden: i,
          estado: (c['estado'] as String?) ?? 'publico',
          tipoDescuento: descuentoActivo ? (isFijo ? 'fijo' : 'porcentaje') : null,
          valorDescuento: descuentoActivo && valorDescuentoInput > 0
              ? valorDescuentoInput
              : null,
          precioOferta: precioOferta,
        ),
      );
    }

    return presentacionesFinales;
  }
}
