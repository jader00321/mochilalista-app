import 'dart:io'; 
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:provider/provider.dart';
import 'package:gal/gal.dart'; 
import 'package:permission_handler/permission_handler.dart';
import 'package:app_movil/core/widgets/marquee_text.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart'; 
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';

import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/widgets/full_screen_image_viewer.dart';

import 'package:app_movil/features/smart_quotation/widgets/smart_update_modal.dart';
import 'package:app_movil/features/smart_quotation/screens/manual_quotation_screen.dart';
import 'package:app_movil/features/smart_quotation/widgets/detalle/quote_detail_header.dart';        
import 'package:app_movil/features/smart_quotation/widgets/detalle/quote_evidence_panel.dart';       
import 'package:app_movil/features/smart_quotation/widgets/detalle/quote_item_list_row.dart';        
import 'package:app_movil/features/smart_quotation/widgets/detalle/quotation_action_buttons.dart';


class QuotationDetailScreen extends StatefulWidget {
  final int quotationId;
  final String? clientName;

  const QuotationDetailScreen({super.key, required this.quotationId, this.clientName});

  @override
  State<QuotationDetailScreen> createState() => _QuotationDetailScreenState();
}

class _QuotationDetailScreenState extends State<QuotationDetailScreen> {
  bool _isLoading = true;
  SmartQuotationModel? _fullQuotation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { _loadData(); });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    final workbenchProv = Provider.of<WorkbenchProvider>(context, listen: false);
    final quotationProv = Provider.of<SmartQuotationProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      _fullQuotation = await quotationProv.getQuotationById(widget.quotationId); 
      
      // Solo el equipo del negocio valida el semáforo de inventario
      if (!auth.isCommunityClient) {
         await workbenchProv.checkTrafficLight(widget.quotationId);
         
         if (mounted && _fullQuotation != null && _fullQuotation!.status == 'READY') {
           final validation = workbenchProv.getValidationFor(widget.quotationId);
           if (validation != null && !validation.canSell) {
              await _changeStatus('PENDING', isAutoRevert: true);
           }
         }
      }
    } catch (e) {
      if (mounted) CustomSnackBar.show(context, message: "Error al cargar: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadImage() async {
    if (_fullQuotation?.sourceImageUrl == null) return;
    try {
      bool hasAccess = false;
      if (Platform.isAndroid) {
        if (await Permission.photos.request().isGranted) {
          hasAccess = true;
        } else if (await Permission.storage.request().isGranted) {
          hasAccess = true;
        }
      } else {
        if (await Permission.photosAddOnly.request().isGranted || await Permission.photos.request().isGranted) hasAccess = true;
      }
      
      if (!hasAccess && await Permission.storage.isPermanentlyDenied) {
          if (mounted) CustomSnackBar.show(context, message: "Habilita el permiso de almacenamiento en Configuración", isError: true);
          return;
      }
      if (mounted) CustomSnackBar.show(context, message: "Descargando...", isError: false);

      final url = Uri.parse(_fullQuotation!.sourceImageUrl!);
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(url);
      final httpResponse = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(httpResponse);
      await Gal.putImageBytes(Uint8List.fromList(bytes), name: "cotizacion_${_fullQuotation!.id}");

      if (mounted) CustomSnackBar.show(context, message: "✅ Imagen guardada en Galería", isError: false);
    } on GalException catch (e) {
      if (mounted) CustomSnackBar.show(context, message: "Permiso denegado por el sistema: ${e.type.message}", isError: true);
    } catch (e) {
      if (mounted) CustomSnackBar.show(context, message: "Error al descargar imagen", isError: true);
    }
  }

  void _handleUpdateAnalysis(ValidationResult validation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SmartUpdateModal(
        validation: validation,
        onUpdatePrices: () => _executeRefresh(prices: true, stock: false, names: false, bundles: false),
        onFixStock: () => _fixAllStock(validation),
        onFixAll: () async {
          await _fixAllStock(validation);
          if (mounted) {
            await _executeRefresh(prices: true, stock: false, names: true, bundles: false);
          }
        },
        onOpenManualEdit: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ManualQuotationScreen(quotationId: widget.quotationId)),
          );
          if (result == true && mounted) _loadData();
        },
        onUpdateNames: () => _executeRefresh(prices: false, stock: false, names: true, bundles: false),
        onSyncBundles: () => _executeRefresh(prices: false, stock: false, names: false, bundles: true),
        onSyncUnits: () => _executeRefresh(prices: false, stock: false, names: true, bundles: false),
        onFixSingleStock: (itemId, newQty) => _handleIndividualFix(itemId: itemId, newQty: newQty),
        onRemoveSingleItem: (itemId) => _handleIndividualFix(itemId: itemId, remove: true),
        onAcceptSinglePrice: (itemId, newPrice, newBase) => _handleIndividualFix(itemId: itemId, newAppliedPrice: newPrice, newOriginalPrice: newBase),
        onAcceptSingleName: (itemId, newName) => _handleIndividualFix(itemId: itemId, newName: newName),
      ),
    );
  }

  Future<void> _fixAllStock(ValidationResult validation) async {
    if (_fullQuotation == null) return;
    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> itemsPayload = [];
      double newTotalAmount = 0.0;
      double newTotalSavings = 0.0;

      final stockWarningsMap = {for (var w in validation.stockWarnings) w.itemId: w};

      for (var qItem in _fullQuotation!.items) {
        final warning = stockWarningsMap[qItem.id];
        if (warning != null) {
          if (warning.available <= 0) {
            // Producto agotado: se retira de la lista para levantar el bloqueo de venta
            continue;
          }
          // Stock parcial disponible: ajustar la cantidad requerida al stock disponible
          final qty = warning.available;
          newTotalAmount += qItem.unitPriceApplied * qty;
          double savings = (qItem.originalUnitPrice - qItem.unitPriceApplied) * qty;
          if (savings > 0) newTotalSavings += savings;

          itemsPayload.add({
            "product_id": qItem.productId, 
            "presentation_id": qItem.presentationId, 
            "bundle_id": qItem.bundleId,
            "quantity": qty,
            "unit_price_applied": qItem.unitPriceApplied, 
            "original_unit_price": qItem.originalUnitPrice, 
            "product_name": qItem.productName,
            "brand_name": qItem.brandName,
            "specific_name": qItem.specificName,
            "sales_unit": qItem.salesUnit,
            "is_manual_price": qItem.isManualPrice, 
            "image_url": qItem.imageUrl,
            "original_text": qItem.originalText
          });
        } else {
          newTotalAmount += qItem.unitPriceApplied * qItem.quantity;
          double savings = (qItem.originalUnitPrice - qItem.unitPriceApplied) * qItem.quantity;
          if (savings > 0) newTotalSavings += savings;

          itemsPayload.add({
            "product_id": qItem.productId, 
            "presentation_id": qItem.presentationId, 
            "bundle_id": qItem.bundleId,
            "quantity": qItem.quantity,
            "unit_price_applied": qItem.unitPriceApplied, 
            "original_unit_price": qItem.originalUnitPrice, 
            "product_name": qItem.productName,
            "brand_name": qItem.brandName,
            "specific_name": qItem.specificName,
            "sales_unit": qItem.salesUnit,
            "is_manual_price": qItem.isManualPrice, 
            "image_url": qItem.imageUrl,
            "original_text": qItem.originalText
          });
        }
      }

      final wbProv = Provider.of<WorkbenchProvider>(context, listen: false);
      await wbProv.saveManualQuotation(
        id: widget.quotationId,
        clientId: _fullQuotation!.clientId,
        clientName: _fullQuotation!.clientName,
        institution: _fullQuotation!.institutionName,
        grade: _fullQuotation!.gradeLevel,
        notas: _fullQuotation!.notas,
        totalAmount: newTotalAmount,
        totalSavings: newTotalSavings > 0 ? newTotalSavings : 0.0,
        items: itemsPayload,
        status: _fullQuotation!.status,
        type: _fullQuotation!.type,
      );

      if (mounted) {
        CustomSnackBar.show(context, message: "Productos agotados y stock corregidos exitosamente", isError: false);
      }
      await _loadData();
    } catch (e) {
      if (mounted) CustomSnackBar.show(context, message: "Error al corregir stock: $e", isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleIndividualFix({
    required int itemId, 
    bool remove = false, 
    int? newQty, 
    double? newAppliedPrice, 
    double? newOriginalPrice,
    String? newName,
  }) async {
    setState(() => _isLoading = true);
    
    try {
      final List<Map<String, dynamic>> itemsPayload = [];
      double newTotalAmount = 0.0;
      double newTotalSavings = 0.0;

      for (var qItem in _fullQuotation!.items) {
        if (qItem.id == itemId) {
          if (remove) continue; 
          
          final qty = newQty ?? qItem.quantity;
          final appliedPrice = newAppliedPrice ?? qItem.unitPriceApplied;
          final originalPrice = newOriginalPrice ?? qItem.originalUnitPrice;

          newTotalAmount += appliedPrice * qty;
          double savings = (originalPrice - appliedPrice) * qty;
          if (savings > 0) newTotalSavings += savings;

          itemsPayload.add({
            "product_id": qItem.productId, 
            "presentation_id": qItem.presentationId, 
            "bundle_id": qItem.bundleId,
            "quantity": qty,
            "unit_price_applied": appliedPrice, 
            "original_unit_price": originalPrice, 
            "product_name": newName ?? qItem.productName,
            "brand_name": qItem.brandName,
            "specific_name": qItem.specificName,
            "sales_unit": qItem.salesUnit,
            "is_manual_price": false, 
            "image_url": qItem.imageUrl,
            "original_text": qItem.originalText
          });
        } else {
          newTotalAmount += qItem.unitPriceApplied * qItem.quantity;
          double savings = (qItem.originalUnitPrice - qItem.unitPriceApplied) * qItem.quantity;
          if (savings > 0) newTotalSavings += savings;

          itemsPayload.add({
            "product_id": qItem.productId, 
            "presentation_id": qItem.presentationId, 
            "bundle_id": qItem.bundleId,
            "quantity": qItem.quantity,
            "unit_price_applied": qItem.unitPriceApplied, 
            "original_unit_price": qItem.originalUnitPrice, 
            "product_name": qItem.productName,
            "brand_name": qItem.brandName,
            "specific_name": qItem.specificName,
            "sales_unit": qItem.salesUnit,
            "is_manual_price": qItem.isManualPrice, 
            "image_url": qItem.imageUrl,
            "original_text": qItem.originalText
          });
        }
      }

      final wbProv = Provider.of<WorkbenchProvider>(context, listen: false);
      await wbProv.saveManualQuotation(
        id: widget.quotationId,
        clientId: _fullQuotation!.clientId,
        clientName: _fullQuotation!.clientName,
        institution: _fullQuotation!.institutionName,
        grade: _fullQuotation!.gradeLevel,
        notas: _fullQuotation!.notas,
        totalAmount: newTotalAmount,
        totalSavings: newTotalSavings > 0 ? newTotalSavings : 0.0,
        items: itemsPayload,
        status: _fullQuotation!.status,
        type: _fullQuotation!.type,
      );

      if (mounted) CustomSnackBar.show(context, message: "Ítem ajustado correctamente", isError: false);
      await _loadData(); 

    } catch (e) {
      if (mounted) CustomSnackBar.show(context, message: "Error al actualizar el ítem", isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _executeRefresh({required bool prices, required bool stock, required bool names, required bool bundles}) async {
    final wp = Provider.of<WorkbenchProvider>(context, listen: false);
    setState(() => _isLoading = true);
    final success = await wp.refreshQuotation(widget.quotationId, fixPrices: prices, fixStock: stock, fixNames: names, fixBundles: bundles);
    if (success && mounted) {
      CustomSnackBar.show(context, message: "Cotización actualizada correctamente.", isError: false);
      _loadData();
    } else if (mounted) {
      CustomSnackBar.show(context, message: "Error al actualizar la cotización.", isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changeStatus(String newStatus, {bool isAutoRevert = false}) async {
    final workbenchProv = Provider.of<WorkbenchProvider>(context, listen: false);
    final validation = workbenchProv.getValidationFor(widget.quotationId);

    if (newStatus == 'READY' && validation != null) {
      if (!validation.canSell) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).cardTheme.color,
            title: Row(children: [Icon(Icons.warning_amber, color: Colors.orange[400]), const SizedBox(width: 10), const Text("Atención")]),
            content: Text("No puedes marcar como 'Listo para Vender' porque hay productos agotados o con stock insuficiente.\n\nPor favor usa el botón 'CORREGIR' primero.", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87, fontSize: 16)),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Entendido", style: TextStyle(fontSize: 16)))],
          )
        );
        return;
      }
    }

    if (newStatus == 'CONVERT_PACK') {
        _confirmConvertToPack(workbenchProv);
        return;
    }

    bool success = await workbenchProv.changeQuotationStatus(widget.quotationId, newStatus);
    
    if (success && mounted) {
      if (isAutoRevert) {
         CustomSnackBar.show(context, message: "Estado cambiado a Pendiente por cambios en inventario.", backgroundColor: Colors.orange[800]!, icon: Icons.info_outline);
      } else {
         String msg = "Estado actualizado";
         if (newStatus == 'READY') msg = "Lista marcada como LISTA para vender";
         if (newStatus == 'ARCHIVED') msg = "Lista archivada";
         CustomSnackBar.show(context, message: msg, isError: false);
      }
      _loadData(); 
    }
  }

  void _confirmConvertToPack(WorkbenchProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        title: const Text("Crear Pack Escolar", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Se creará una copia de esta lista como plantilla 'Pack Escolar'.\n\n¿Deseas continuar?", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(fontSize: 16))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.blue[300] : Colors.blue[800], foregroundColor: isDark ? Colors.black87 : Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              int? newPackId = await provider.convertToPack(widget.quotationId);
              if (newPackId != null && mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: newPackId)));
                CustomSnackBar.show(context, message: "Pack creado exitosamente", isError: false);
              } else if (mounted) {
                CustomSnackBar.show(context, message: "Error al crear el pack", isError: true);
              }
            }, 
            child: const Text("Crear Pack", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))
          )
        ],
      )
    );
  }

  void _handleDeleteRequest() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _fullQuotation?.status;
    
    if (status != 'DRAFT' && status != 'ARCHIVED') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
          title: const Text("Acción no permitida", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text("Solo se pueden eliminar cotizaciones en estado 'Borrador' o 'Archivado'.\n\nCambia el estado antes de eliminar.", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK", style: TextStyle(fontSize: 16)))],
        )
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        title: const Text("¿Eliminar Cotización?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Esta acción es irreversible.", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(fontSize: 16))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prov = Provider.of<WorkbenchProvider>(context, listen: false);
              bool success = await prov.deleteQuotation(widget.quotationId);
              if (success && mounted) {
                Navigator.pop(context); 
                CustomSnackBar.show(context, message: "Cotización eliminada", isError: false);
              } else if (mounted) {
                CustomSnackBar.show(context, message: "Error al eliminar", isError: true);
              }
            },
            child: Text("ELIMINAR", style: TextStyle(color: isDark ? Colors.red[400] : Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      )
    );
  }

  void _showQuotationNameDialog(bool isDark) {
    final title = _fullQuotation?.clientName ?? widget.clientName ?? "Detalle";
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        title: Row(
          children: [
            Icon(Icons.description_outlined, color: isDark ? Colors.blue[300] : Colors.blue[800]),
            const SizedBox(width: 8),
            const Text("Nombre de la Lista", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SelectableText(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.blueGrey[900],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: const Text("Copiar"),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: title));
              Navigator.pop(ctx);
              CustomSnackBar.show(context, message: "Nombre copiado", isError: false);
            },
          ),
          if (_fullQuotation?.status != 'SOLD' && !Provider.of<AuthProvider>(context, listen: false).isCommunityClient)
            ElevatedButton.icon(
              icon: const Icon(Icons.edit, size: 18),
              label: const Text("Editar"),
              onPressed: () {
                Navigator.pop(ctx);
                _showRenameDialog(isDark);
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(bool isDark) {
    final controller = TextEditingController(text: _fullQuotation?.clientName ?? "");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        title: const Text("Cambiar Nombre", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "Nombre o Cliente",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(ctx);
                final workbenchProv = Provider.of<WorkbenchProvider>(context, listen: false);
                final ok = await workbenchProv.renameQuotation(widget.quotationId, newName);
                if (ok) {
                  _loadData();
                  if (mounted) CustomSnackBar.show(context, message: "Nombre actualizado", isError: false);
                }
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  void _showTextEvidenceDialog(bool isDark) {
    String fullText = _fullQuotation?.originalTextDump ?? "";
    if (fullText.isEmpty && _fullQuotation != null) {
        final itemsText = _fullQuotation!.items.where((i) => i.originalText != null && i.originalText!.isNotEmpty).map((i) => "- ${i.originalText}").join("\n");
        if (itemsText.isNotEmpty) fullText = "$itemsText\n\n(Nota: Mostrando texto parcial de items vinculados)";
    }
    if (fullText.isEmpty) fullText = "No hay texto registrado.";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        title: Text("Texto Extraído", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: SelectableText(fullText, style: TextStyle(fontSize: 16, color: isDark ? Colors.grey[300] : Colors.black87)))),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.copy, color: isDark ? Colors.blue[300] : Colors.blue), label: Text("Copiar", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontSize: 16)),
            onPressed: () { Clipboard.setData(ClipboardData(text: fullText)); Navigator.pop(ctx); CustomSnackBar.show(context, message: "Texto copiado", isError: false); },
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cerrar", style: TextStyle(color: Colors.grey, fontSize: 16))),
        ],
      )
    );
  }

  Widget _buildSmartAlertBanner(ValidationResult validation, bool isDark) {
    bool isCritical = !validation.canSell; 

    if (isCritical) {
      // ═══════════════════════════════════════════════════════════════
      // 🔴 BANNER CRÍTICO: Stock insuficiente / Bundle eliminado
      // Tamaño grande, rojo, icono de error. Impide la venta.
      // ═══════════════════════════════════════════════════════════════
      Color bgColor = isDark ? Colors.red[900]! : Colors.red;
      return Container(
        width: double.infinity,
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  const Text("¡Atención! Stock Insuficiente", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)), 
                  const SizedBox(height: 4),
                  Text("Productos agotados detectados.", style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9)))
                ]
              )
            ),
            ElevatedButton(
              onPressed: () => _handleUpdateAnalysis(validation), 
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: bgColor, elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), 
              child: const Text("VER SOLUCIONES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))
            )
          ],
        ),
      );
    } else {
      // ═══════════════════════════════════════════════════════════════
      // 🟡 BANNER INFORMATIVO: Precios desactualizados
      // Más compacto, discreto, no impide la venta.
      // ═══════════════════════════════════════════════════════════════
      Color bgColor = isDark ? Colors.amber[900]!.withValues(alpha: 0.6) : Colors.amber[100]!;
      Color textColor = isDark ? Colors.amber[200]! : Colors.amber[900]!;
      return Container(
        width: double.infinity,
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: textColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text("Hay cambios de precio en algunos productos.", style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 13)),
            ),
            TextButton(
              onPressed: () => _handleUpdateAnalysis(validation), 
              style: TextButton.styleFrom(foregroundColor: textColor, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
              child: const Text("REVISAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))
            )
          ],
        ),
      );
    }
  }
  


  // 🔥 LÓGICA DUAL DE ESTADOS Y COLORES
  Color _getStatusColor(String status, bool isDark, bool isClient) {
    if (isClient) {
        switch (status) {
          case 'PENDING_APPROVAL':
          case 'PENDING': return isDark ? Colors.orange[400]! : Colors.orange;
          case 'READY': return isDark ? Colors.blue[400]! : Colors.blue;
          case 'SOLD': return isDark ? Colors.green[400]! : Colors.green;
          case 'DRAFT':
          case 'ARCHIVED': return isDark ? Colors.red[400]! : Colors.red;
          default: return Colors.grey;
        }
    } else {
        switch (status) {
          case 'PENDING_APPROVAL': return isDark ? Colors.deepOrange[400]! : Colors.deepOrange;
          case 'PENDING': return isDark ? Colors.orange[400]! : Colors.orange;
          case 'READY': return isDark ? Colors.blue[400]! : Colors.blue;
          case 'SOLD': return isDark ? Colors.green[400]! : Colors.green;
          case 'ARCHIVED': return Colors.grey;
          default: return Colors.grey;
        }
    }
  }

  String _getStatusText(String status, bool isClient) {
    if (isClient) {
        switch (status) {
          case 'PENDING_APPROVAL':
          case 'PENDING': return 'En Revisión';
          case 'READY': return 'Revisado / Aceptado';
          case 'SOLD': return 'Compra Confirmada';
          case 'DRAFT':
          case 'ARCHIVED': return 'Rechazado / Cancelado';
          default: return 'Desconocido';
        }
    } else {
        switch (status) {
          case 'PENDING_APPROVAL': return 'Nuevo Pedido Web';
          case 'PENDING': return 'Pendiente';
          case 'READY': return 'Listo para Vender';
          case 'SOLD': return 'Vendido';
          case 'ARCHIVED': return 'Archivado';
          default: return 'Borrador';
        }
    }
  }

  void _showStateSelectorModal(bool isDark) {
    final currentStatus = _fullQuotation?.status ?? 'DRAFT';
    final bool isSold = currentStatus == 'SOLD';
    final workbenchProv = Provider.of<WorkbenchProvider>(context, listen: false);

    InteractiveSheetWrapper.show(
      context: context,
      builder: (sheetCtx) => InteractiveSheetWrapper(
        title: isSold ? "Cotización Vendida" : "Opciones de Cotización",
        icon: isSold ? Icons.verified : Icons.tune,
        iconColor: isSold ? (isDark ? Colors.green[400]! : Colors.green[800]!) : (isDark ? Colors.blue[300] : Colors.blue[700]),
        maxHeightFactor: 0.85,
        applyEffectiveBottomPadding: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSold) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, size: 18, color: isDark ? Colors.green[300] : Colors.green[800]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Cotización Vendida (Histórico Inmutable). Puedes duplicarla para crear un nuevo borrador o compartirla.",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.green[200] : Colors.green[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue[50],
                  child: Icon(Icons.copy_all, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                ),
                title: const Text("Duplicar Cotización", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Crea un nuevo borrador editable basado en esta cotización"),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final newId = await workbenchProv.cloneQuotation(widget.quotationId);
                  if (newId != null && mounted) {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: newId)));
                    CustomSnackBar.show(context, message: "Cotización duplicada como nuevo borrador", isError: false);
                  }
                },
              ),
              const SizedBox(height: 12),
            ] else ...[
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue[50],
                  child: Icon(Icons.edit, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                ),
                title: const Text("Cambiar Nombre / Cliente", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Actualiza el título de esta lista"),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showRenameDialog(isDark);
                },
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "ESTADO DE LA COTIZACIÓN",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[600], letterSpacing: 0.5),
                  ),
                ),
              ),
              if (currentStatus != 'DRAFT')
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    child: const Icon(Icons.edit_note, color: Colors.grey),
                  ),
                  title: const Text("Borrador", style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text("Mover a preparación inicial"),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _changeStatus('DRAFT');
                  },
                ),
              if (currentStatus != 'PENDING')
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.withValues(alpha: 0.2),
                    child: const Icon(Icons.access_time, color: Colors.orange),
                  ),
                  title: const Text("Pendiente (Revisar)", style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text("Lista en proceso de armado o revisión"),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _changeStatus('PENDING');
                  },
                ),
              if (currentStatus != 'READY')
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withValues(alpha: 0.2),
                    child: const Icon(Icons.check_circle_outline, color: Colors.blue),
                  ),
                  title: const Text("Listo para Vender", style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text("Lista armada y validada para despacho"),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _changeStatus('READY');
                  },
                ),
              const Divider(),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.withValues(alpha: 0.2),
                  child: const Icon(Icons.inventory_2, color: Colors.teal),
                ),
                title: const Text("Convertir en Pack Escolar", style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text("Guardar como plantilla reutilizable"),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _confirmConvertToPack(workbenchProv);
                },
              ),
              if (currentStatus != 'ARCHIVED')
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.withValues(alpha: 0.2),
                    child: const Icon(Icons.archive_outlined, color: Colors.purple),
                  ),
                  title: const Text("Archivar", style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text("Ocultar de la Mesa de Trabajo activa"),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _changeStatus('ARCHIVED');
                  },
                ),
              Divider(color: isDark ? Colors.white10 : Colors.grey[200]),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.withValues(alpha: 0.15),
                  child: const Icon(Icons.delete_outline, color: Colors.red),
                ),
                title: const Text("Eliminar Cotización", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                subtitle: const Text("Eliminar definitivamente esta cotización"),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _handleDeleteRequest();
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workbenchProv = Provider.of<WorkbenchProvider>(context);
    final auth = Provider.of<AuthProvider>(context); 
    final isClient = auth.isCommunityClient; 

    final validation = workbenchProv.getValidationFor(widget.quotationId);
    final items = _fullQuotation?.items ?? []; 
    
    // 🔥 CORRECCIÓN: Ocultar evidencia IA si el pedido fue manual
    final bool isAiScan = _fullQuotation?.type == 'ai_scan';
    final bool hasImage = _fullQuotation?.sourceImageUrl != null && _fullQuotation!.sourceImageUrl!.isNotEmpty;
    final bool hasTextEvidence = (_fullQuotation?.originalTextDump != null && _fullQuotation!.originalTextDump!.isNotEmpty) || items.any((i) => i.originalText != null && i.originalText!.isNotEmpty);
    
    // Solo mostramos evidencia si genuinamente hubo un escaneo con IA o se adjuntó una imagen.
    final bool showEvidence = isAiScan || hasImage;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 24,
              child: MarqueeText(
                text: _fullQuotation?.clientName ?? widget.clientName ?? "Detalle",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                onTap: () => _showQuotationNameDialog(isDark),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: _getStatusColor(_fullQuotation?.status ?? 'DRAFT', isDark, isClient), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(
                  _getStatusText(_fullQuotation?.status ?? 'DRAFT', isClient), 
                  style: const TextStyle(fontSize: 13, color: Colors.white70)
                ),
              ],
            )
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1A1A24) : const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Consumer<QuickSaleProvider>(
            builder: (ctx, quickProv, _) => IconButton(
              icon: Icon(
                quickProv.hideProfits ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 24,
                color: Colors.white70,
              ),
              tooltip: quickProv.hideProfits ? "Modo Cliente (Privacidad activa)" : "Modo Vendedor",
              onPressed: () => quickProv.toggleHideProfits(),
            ),
          ),
          if (_fullQuotation?.status != 'SOLD')
            IconButton(icon: const Icon(Icons.refresh, size: 26), tooltip: "Sincronizar", onPressed: _loadData),
          
          if (!isClient)
            IconButton(
              icon: const Icon(Icons.more_vert, size: 26),
              tooltip: "Opciones y Estado",
              onPressed: () => _showStateSelectorModal(isDark),
            ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                if (!isClient && validation != null && (validation.hasIssues || !validation.canSell) && _fullQuotation?.status != 'SOLD') 
                  SliverToBoxAdapter(
                    child: _buildSmartAlertBanner(validation, isDark)
                  ),
                
                if (_fullQuotation?.status == 'SOLD')
                  SliverToBoxAdapter(
                    child: Container(
                      width: double.infinity,
                      color: Colors.green[700],
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified, color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isClient ? "¡COMPRA CONFIRMADA Y PROCESADA!" : "LISTA VENDIDA Y CERRADA",
                              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15, letterSpacing: 0.5),
                              textAlign: TextAlign.center,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                
                SliverPersistentHeader(
                  pinned: false,
                  floating: true,
                  delegate: _QuoteHeaderDelegate(
                    quotation: _fullQuotation,
                    fallbackClientName: widget.clientName,
                    isDark: isDark,
                  ),
                ),
                
                if (showEvidence)
                  SliverToBoxAdapter(
                    child: QuoteEvidencePanel(
                      hasImage: hasImage, hasText: hasTextEvidence, imageUrl: _fullQuotation?.sourceImageUrl, isDark: isDark,
                      onImageTap: () {
                         if (_fullQuotation?.sourceImageUrl != null) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: _fullQuotation!.sourceImageUrl!, tag: "${_fullQuotation!.id}_evidence")));
                         }
                      },
                      onDownloadTap: _downloadImage, onTextEvidenceTap: () => _showTextEvidenceDialog(isDark),
                    ),
                  ),
                
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text("No hay productos en esta cotización", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 16)))
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.only(
                      top: 8, 
                      bottom: 120 + MediaQuery.of(context).padding.bottom,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final item = items[i];
                          final stockWarning = isClient ? null : validation?.stockWarnings.firstWhere((w) => w.itemId == item.id, orElse: () => StockWarning(itemId: -1, productName: "", requested: 0, available: 0));
                          final priceChange = isClient ? null : validation?.priceChanges.firstWhere((p) => p.itemId == item.id, orElse: () => PriceChange(itemId: -1, productName: "", oldPrice: 0, newPrice: 0));
                          
                          return QuoteItemListRow(item: item, stockError: stockWarning, priceError: priceChange, isDark: isDark);
                        },
                        childCount: items.length,
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: QuotationActionButtons(
        quotationId: widget.quotationId,
        status: _fullQuotation?.status ?? 'DRAFT',
        validation: validation,
        isDark: isDark,
        isClient: isClient,
        onReloadData: _loadData,
        onHandleUpdateAnalysis: _handleUpdateAnalysis,
      ),
    );
  }
}


class _QuoteHeaderDelegate extends SliverPersistentHeaderDelegate {
  final SmartQuotationModel? quotation;
  final String? fallbackClientName;
  final bool isDark;

  _QuoteHeaderDelegate({
    required this.quotation,
    this.fallbackClientName,
    required this.isDark,
  });

  @override
  double get minExtent => 85.0;

  @override
  double get maxExtent {
    double baseHeight = 125.0; 
    if (quotation?.institutionName != null && quotation!.institutionName!.isNotEmpty) {
      baseHeight += 45.0; 
    }
    if (quotation?.gradeLevel != null && quotation!.gradeLevel!.isNotEmpty) {
      baseHeight += 25.0;
    }
    
    if (quotation?.notas != null && quotation!.notas!.isNotEmpty) {
      baseHeight += 60.0;
    }
    
    return baseHeight < 135.0 ? 135.0 : baseHeight;
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    double currentExtent = maxExtent - shrinkOffset;
    double shrinkFactor = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);

    return SizedBox(
      height: currentExtent.clamp(minExtent, maxExtent),
      child: ClipRect(
        child: OverflowBox(
          minHeight: minExtent,
          maxHeight: maxExtent,
          alignment: Alignment.topCenter,
          child: QuoteDetailHeader(
            quotation: quotation,
            fallbackClientName: fallbackClientName,
            isDark: isDark,
            shrinkFactor: shrinkFactor,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _QuoteHeaderDelegate oldDelegate) {
    return quotation != oldDelegate.quotation ||
           fallbackClientName != oldDelegate.fallbackClientName ||
           isDark != oldDelegate.isDark;
  }
}