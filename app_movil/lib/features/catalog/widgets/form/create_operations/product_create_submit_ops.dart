import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/widgets/product_save_success_dialog.dart';

class ProductCreateSubmitOps {
  ProductCreateSubmitOps._();

  static Future<bool> submitProduct({
    required BuildContext context,
    required GlobalKey<FormState> formKey,
    required TextEditingController nameCtrl,
    required TextEditingController descCtrl,
    required TextEditingController imgUrlCtrl,
    required TextEditingController barcodeCtrl,
    required int? selectedBrandId,
    required String? selectedBrandName,
    required int? selectedCategoryId,
    required String? selectedCategoryName,
    required int? generalProviderId,
    required String? generalProviderName,
    required int generalState,
    required List<Map<String, dynamic>> controllers,
    required Map<int, String> deferredProviderNames,
    String modoStock = 'INDEPENDIENTE',
    int stockCompartido = 0,
    double costoBase = 0.0,
    Map<String, GlobalKey>? keys,
  }) async {
    if (!formKey.currentState!.validate()) return false;
    if (nameCtrl.text.trim().isEmpty) {
      AppFeedbackHelper.showSnackBar(
        context,
        "Completa la Información General (Nombre)",
        backgroundColor: Colors.red,
      );
      return false;
    }

    if (modoStock == 'COMPARTIDO' || modoStock == 'MIXTO') {
      final sharedControllers = controllers.where((c) {
        if (modoStock == 'COMPARTIDO') return true;
        return c['usaStockCompartido'] == true;
      }).toList();

      if (sharedControllers.isNotEmpty && stockCompartido > 0) {
        final allZeroFormable = sharedControllers.every((c) {
          final factor =
              int.tryParse(
                (c['unidadesVenta'] as TextEditingController?)?.text ?? '1',
              ) ??
              1;
          final safeFactor = factor <= 0 ? 1 : factor;
          return stockCompartido < safeFactor;
        });

        if (allZeroFormable) {
          AppFeedbackHelper.showSnackBar(
            context,
            "El stock compartido no alcanza para formar ningún paquete. Agrega una variante por Unidad o ajusta el inventario.",
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          );
          return false;
        }
      }
    }

    final String pDesc = descCtrl.text.trim();
    final String pImg = imgUrlCtrl.text.trim();
    final String pCode = barcodeCtrl.text.trim();
    final List<ProductPresentation> presentations = [];

    try {
      for (var c in controllers) {
        final String specific = (c['specific'] as TextEditingController).text
            .trim();
        final String uVenta = (c['unidadVenta'] as TextEditingController).text
            .trim();
        final int factorVenta =
            int.tryParse((c['unidadesVenta'] as TextEditingController).text) ??
            1;
        final double margen =
            double.tryParse((c['margen'] as TextEditingController).text) ??
            1.35;
        final double pVenta =
            double.tryParse((c['precioVenta'] as TextEditingController).text) ??
            0.0;
        final int stockVisual =
            int.tryParse((c['stockFinal'] as TextEditingController).text) ?? 0;

        int stockBaseGuardar = stockVisual * factorVenta;
        final String ajusteText = (c['ajusteBase'] as TextEditingController)
            .text
            .trim();
        if (ajusteText.isNotEmpty) {
          stockBaseGuardar = int.tryParse(ajusteText) ?? stockBaseGuardar;
        }

        bool isShared = false;
        if (modoStock == 'COMPARTIDO') {
          isShared = true;
        } else if (modoStock == 'MIXTO') {
          isShared = c['usaStockCompartido'] == true;
        }

        final int finalStockBase = isShared
            ? stockCompartido
            : stockBaseGuardar;

        if (factorVenta > 1 && !isShared) {
          StockValidationResult? validation =
              c['stockValidation'] as StockValidationResult?;
          if (validation == null) {
            int baseUnits = 0;
            if (ajusteText.isNotEmpty) {
              baseUnits = int.tryParse(ajusteText) ?? 0;
            } else {
              baseUnits =
                  int.tryParse(
                    (c['stockInicial'] as TextEditingController).text,
                  ) ??
                  0;
              final cant =
                  double.tryParse(
                    (c['cantCompra'] as TextEditingController).text,
                  ) ??
                  0.0;
              final lote =
                  int.tryParse(
                    (c['unidadesLote'] as TextEditingController).text,
                  ) ??
                  1;
              if (baseUnits == 0 && cant > 0 && lote > 0) {
                baseUnits = (cant * lote).toInt();
              }
            }
            validation = UnitCatalogService.validateStockForUnit(
              totalUnitsBase: baseUnits,
              presentationFactor: factorVenta,
              baseUnitCost: 0.0,
              unitName: uVenta,
            );
          }

          if (validation.status == StockValidationStatus.deficit) {
            final key = keys?[c['id']];
            if (key?.currentContext != null) {
              Scrollable.ensureVisible(
                key!.currentContext!,
                duration: const Duration(milliseconds: 300),
              );
            }
            AppFeedbackHelper.showSnackBar(
              context,
              "'${specific.isNotEmpty ? specific : uVenta}': ${validation.userMessage(uVenta, factorVenta)}",
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            );
            return false;
          }
          if (validation.status == StockValidationStatus.hasLeftover &&
              c['leftoverCreated'] != true) {
            final key = keys?[c['id']];
            if (key?.currentContext != null) {
              Scrollable.ensureVisible(
                key!.currentContext!,
                duration: const Duration(milliseconds: 300),
              );
            }
            AppFeedbackHelper.showSnackBar(
              context,
              "'${specific.isNotEmpty ? specific : uVenta}': ${validation.userMessage(uVenta, factorVenta)}",
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            );
            return false;
          }
        }

        final String umpC = (c['umpCompra'] as TextEditingController).text
            .trim();
        final double cantC =
            double.tryParse((c['cantCompra'] as TextEditingController).text) ??
            0.0;
        final double totalP =
            double.tryParse((c['totalPago'] as TextEditingController).text) ??
            0.0;
        final int loteC =
            int.tryParse((c['unidadesLote'] as TextEditingController).text) ??
            1;
        final double costoPresFinal =
            double.tryParse((c['costoPres'] as TextEditingController).text) ??
            0.0;

        final String rawDesc = (c['desc'] as TextEditingController).text.trim();
        final String? finalDesc = (rawDesc.isEmpty && pDesc.isNotEmpty)
            ? pDesc
            : (rawDesc.isEmpty ? null : rawDesc);
        final String rawImg = (c['image'] as TextEditingController).text.trim();
        final String? finalImg = rawImg.isEmpty ? null : rawImg;
        final String rawCode = (c['barcode'] as TextEditingController).text
            .trim();
        final String? finalCode = (rawCode.isEmpty && pCode.isNotEmpty)
            ? pCode
            : (rawCode.isEmpty ? null : rawCode);

        final bool descuentoActivo = c['descuentoActivo'] == true;
        final String tipoDescuento = c['tipoDescuento'] as String;
        final double valorDescuento =
            double.tryParse(
              (c['valorDescuento'] as TextEditingController).text,
            ) ??
            0.0;

        double? precioOferta;
        if (descuentoActivo && valorDescuento > 0 && pVenta > 0) {
          if (c['precioOfertaExacto'] != null &&
              (c['precioOfertaExacto'] as num) > 0 &&
              (c['precioOfertaExacto'] as num) < pVenta) {
            precioOferta = (c['precioOfertaExacto'] as num).toDouble();
          } else if (tipoDescuento == 'porcentaje') {
            precioOferta = pVenta - (pVenta * (valorDescuento / 100));
          } else {
            precioOferta = pVenta - valorDescuento;
          }
        }

        final pId = c['providerId'] as int?;
        String? defVariantProvName;
        if (pId != null && pId < 0) {
          defVariantProvName = deferredProviderNames[pId];
        }

        presentations.add(
          ProductPresentation(
            nombreEspecifico: specific.isEmpty ? null : specific,
            unidadVenta: uVenta.isEmpty ? "Unidad" : uVenta,
            unidadesPorVenta: factorVenta,
            costoUnitarioCalculado: costoPresFinal,
            factorGananciaVenta: margen,
            precioVentaFinal: pVenta,
            stockActual: finalStockBase,
            usaStockCompartido: isShared,
            umpCompra: umpC.isEmpty ? null : umpC,
            cantidadUmpComprada: cantC > 0 ? cantC : null,
            totalPagoLote: totalP > 0 ? totalP : null,
            unidadesPorLote: loteC,
            precioUmpProveedor: cantC > 0 ? (totalP / cantC) : null,
            descripcion: finalDesc,
            imagenUrl: finalImg,
            codigoBarras: finalCode,
            estado: c['estado'] as String,
            esDefault: c['isDefault'] == true,
            proveedorId: (pId != null && pId > 0) ? pId : null,
            deferredProviderName: defVariantProvName,
            tipoDescuento: descuentoActivo ? tipoDescuento : null,
            valorDescuento: descuentoActivo && valorDescuento > 0
                ? valorDescuento
                : null,
            precioOferta: precioOferta,
          ),
        );
      }
    } catch (e) {
      debugPrint("LOG: Error procesando controladores: $e");
      return false;
    }

    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final String? defBrandName =
        (selectedBrandId != null && selectedBrandId < 0)
        ? selectedBrandName
        : null;
    final int? safeBrandId = (selectedBrandId != null && selectedBrandId > 0)
        ? selectedBrandId
        : null;
    final String? defCategoryName =
        (selectedCategoryId != null && selectedCategoryId < 0)
        ? selectedCategoryName
        : null;
    final int? safeCategoryId =
        (selectedCategoryId != null && selectedCategoryId > 0)
        ? selectedCategoryId
        : null;

    final String? defGenProvName =
        (generalProviderId != null && generalProviderId < 0)
        ? (deferredProviderNames[generalProviderId] ?? generalProviderName)
        : null;
    final int? safeGenProvId =
        (generalProviderId != null && generalProviderId > 0)
        ? generalProviderId
        : null;

    final success = await invProv.createFullProduct(
      nombre: nameCtrl.text.trim(),
      marcaId: safeBrandId,
      categoriaId: safeCategoryId,
      proveedorId: safeGenProvId,
      estado: generalState == 2 ? 'publico' : 'privado',
      descripcion: pDesc.isEmpty ? null : pDesc,
      imagenUrl: pImg.isEmpty ? null : pImg,
      codigoBarras: pCode.isEmpty ? null : pCode,
      presentaciones: presentations,
      deferredBrandName: defBrandName,
      deferredCategoryName: defCategoryName,
      deferredProviderName: defGenProvName,
      modoStock: modoStock,
      stockCompartido: stockCompartido,
      costoBase: costoBase,
    );

    if (success && context.mounted) {
      invProv.clearCreationDraft();
      await ProductSaveSuccessDialog.show(
        context: context,
        productName: nameCtrl.text.trim(),
        presentationCount: presentations.length,
        mode: ProductSaveDialogMode.create,
      );
      return true;
    } else if (context.mounted) {
      final msg = invProv.errorMessage.isNotEmpty
          ? invProv.errorMessage
          : "No se pudo registrar el producto";
      AppFeedbackHelper.showSnackBar(
        context,
        "Error: $msg",
        backgroundColor: Colors.red,
      );
    }
    return false;
  }
}
