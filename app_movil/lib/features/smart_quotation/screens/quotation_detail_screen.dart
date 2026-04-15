import 'dart:typed_data';
import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart'; 
import 'package:permission_handler/permission_handler.dart';

import '../providers/workbench_provider.dart';
import '../providers/smart_quotation_provider.dart';
import '../../../providers/auth_provider.dart'; 
import '../models/smart_quotation_model.dart';
import '../models/crm_models.dart';

import '../../../widgets/custom_snackbar.dart';
import '../../../widgets/full_screen_image_viewer.dart';

import '../widgets/smart_update_modal.dart';
import '../widgets/detalle/quote_detail_header.dart';        
import '../widgets/detalle/quote_evidence_panel.dart';       
import '../widgets/detalle/quote_item_list_row.dart';        

import 'manual_quotation_screen.dart'; 
import 'sales_checkout_screen.dart';   
import 'pdf_preview_screen.dart';   
import 'whatsapp_preview_screen.dart'; 

class QuotationDetailScreen extends StatefulWidget {
  final int quotationId;
  final String? clientName;

  const QuotationDetailScreen({super.key, required this.quotationId, this.clientName});

  @override
  State<QuotationDetailScreen> createState() => _QuotationDetailScreenState();
}

class _QuotationDetailScreenState extends State<QuotationDetailScreen> {
  bool _isLoading = true;
  final bool _filterErrorItems = false; 
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
        } else if (await Permission.storage.request().isGranted) hasAccess = true;
      } else {
        if (await Permission.photosAddOnly.request().isGranted || await Permission.photos.request().isGranted) hasAccess = true;
      }
      
      if (!hasAccess && await Permission.storage.isPermanentlyDenied) {
          if (mounted) CustomSnackBar.show(context, message: "Habilita el permiso de almacenamiento en Configuración", isError: true);
          return;
      }
      if (mounted) CustomSnackBar.show(context, message: "Descargando...", isError: false);

      var response = await Dio().get(_fullQuotation!.sourceImageUrl!, options: Options(responseType: ResponseType.bytes));
      await Gal.putImageBytes(Uint8List.fromList(response.data), name: "cotizacion_${_fullQuotation!.id}");

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
        onUpdatePrices: () => _executeRefresh(prices: true, stock: false),
        onFixStock: () => _executeRefresh(prices: false, stock: true),
        onFixAll: () => _executeRefresh(prices: true, stock: true),
        
        onFixSingleStock: (itemId, newQty) => _handleIndividualFix(itemId: itemId, newQty: newQty),
        onRemoveSingleItem: (itemId) => _handleIndividualFix(itemId: itemId, remove: true),
        onAcceptSinglePrice: (itemId, newPrice, newBase) => _handleIndividualFix(itemId: itemId, newAppliedPrice: newPrice, newOriginalPrice: newBase),
      ),
    );
  }

  Future<void> _handleIndividualFix({
    required int itemId, 
    bool remove = false, 
    int? newQty, 
    double? newAppliedPrice, 
    double? newOriginalPrice
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
          newTotalSavings += (originalPrice - appliedPrice) * qty;

          itemsPayload.add({
            "product_id": qItem.productId, 
            "presentation_id": qItem.presentationId, 
            "quantity": qty,
            "unit_price_applied": appliedPrice, 
            "original_unit_price": originalPrice, 
            "product_name": qItem.productName,
            "brand_name": qItem.brandName,
            "specific_name": qItem.specificName,
            "sales_unit": qItem.salesUnit,
            "is_manual_price": false, 
            "image_url": qItem.imageUrl,
            "original_text": qItem.originalText
          });
        } else {
          newTotalAmount += qItem.unitPriceApplied * qItem.quantity;
          newTotalSavings += (qItem.originalUnitPrice - qItem.unitPriceApplied) * qItem.quantity;

          itemsPayload.add({
            "product_id": qItem.productId, 
            "presentation_id": qItem.presentationId, 
            "quantity": qItem.quantity,
            "unit_price_applied": qItem.unitPriceApplied, 
            "original_unit_price": qItem.originalUnitPrice, 
            "product_name": qItem.productName,
            "brand_name": qItem.brandName,
            "specific_name": qItem.specificName,
            "sales_unit": qItem.salesUnit,
            "is_manual_price": false, 
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

  Future<void> _executeRefresh({required bool prices, required bool stock}) async {
    final workbench = Provider.of<WorkbenchProvider>(context, listen: false);
    bool success = await workbench.refreshQuotation(widget.quotationId, fixPrices: prices, fixStock: stock);
    
    if (success) {
      if (mounted) CustomSnackBar.show(context, message: "Cotización actualizada", isError: false);
      await _loadData(); 
    } else {
      if (mounted) CustomSnackBar.show(context, message: "Error al actualizar", isError: true);
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
    Color bgColor = isCritical ? (isDark ? Colors.red[900]! : Colors.red) : (isDark ? Colors.orange[900]! : Colors.orange[800]!);
    Color iconColor = Colors.white;
    String title = isCritical ? "¡Atención! Stock Insuficiente" : "Precios Desactualizados";
    String actionLabel = "VER SOLUCIONES";

    return Container(
      width: double.infinity,
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(isCritical ? Icons.error : Icons.warning_rounded, color: iconColor, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: iconColor, fontSize: 16)), 
                const SizedBox(height: 4),
                Text(isCritical ? "Productos agotados detectados." : "Detectamos cambios de precio.", style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9)))
              ]
            )
          ),
          ElevatedButton(
            onPressed: () => _handleUpdateAnalysis(validation), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: bgColor, elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), 
            child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))
          )
        ],
      ),
    );
  }
  
  // 🔥 NUEVO: Banner de confirmación visual para pedidos ya vendidos
  Widget _buildSoldBanner(bool isDark, bool isClient) {
    return Container(
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
    );
  }

  Widget _buildBottomActionBar(ValidationResult? validation, bool isDark) {
    bool canSell = validation == null || validation.canSell; 
    bool isSold = _fullQuotation?.status == 'SOLD';
    
    final disabledIconColor = isDark ? Colors.white24 : Colors.grey[300]!;
    final disabledBgColor = isDark ? Colors.white10 : Colors.grey[200]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(color: isDark ? Theme.of(context).colorScheme.surface : Colors.white, boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, -10))], borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        child: Row(
          children: [
            _buildActionButton(
              icon: Icons.edit, activeColor: isDark ? Colors.blueGrey[300]! : Colors.blueGrey, tooltip: "Editar", 
              onTap: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => ManualQuotationScreen(quotationId: widget.quotationId)));
                if (result == true) _loadData();
              }, 
              disabledIconColor: disabledIconColor, disabledBgColor: disabledBgColor,
              isDisabled: isSold // 🔒 Bloqueamos edición si está vendido
            ),
            _buildActionButton(icon: Icons.picture_as_pdf, activeColor: isDark ? Colors.red[400]! : Colors.red[700]!, tooltip: "PDF", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PdfPreviewScreen(quotationId: widget.quotationId))), disabledIconColor: disabledIconColor, disabledBgColor: disabledBgColor),
            _buildActionButton(icon: Icons.chat, activeColor: isDark ? Colors.green[400]! : Colors.green[600]!, tooltip: "WhatsApp", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WhatsAppPreviewScreen(quotationId: widget.quotationId))), disabledIconColor: disabledIconColor, disabledBgColor: disabledBgColor),
            
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 55,
                child: isSold 
                 ? ElevatedButton.icon( // 🔥 Si está vendido, cambia a botón de "Historial"
                     onPressed: () { 
                         // Aquí podrías redirigir a ver el comprobante/historial
                         CustomSnackBar.show(context, message: "Esta lista ya fue cobrada y no se puede modificar.", icon: Icons.info);
                     },
                     style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200], foregroundColor: isDark ? Colors.white70 : Colors.grey[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                     icon: const Icon(Icons.lock, size: 24),
                     label: const Text("CERRADA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                   )
                 : ElevatedButton.icon(
                    onPressed: () { 
                      if (canSell) {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => SalesCheckoutScreen(quotationId: widget.quotationId))); 
                      } else {
                        _handleUpdateAnalysis(validation);
                      } 
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: canSell ? (isDark ? Colors.green[700] : const Color(0xFF2E7D32)) : (isDark ? Colors.red[700] : Colors.red[600]), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: isDark ? 0 : 4),
                    icon: Icon(canSell ? Icons.point_of_sale : Icons.build_circle, color: Colors.white, size: 24),
                    label: Text(canSell ? "VENDER" : "CORREGIR", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                  ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientBottomBar(bool isDark) {
    bool isSold = _fullQuotation?.status == 'SOLD';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(color: isDark ? Theme.of(context).colorScheme.surface : Colors.white, boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, -10))], borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        child: isSold 
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green[600]),
                const SizedBox(width: 10),
                Text("Gracias por tu compra.", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.green[300] : Colors.green[800], fontSize: 16))
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront, color: Colors.blue[600]),
                const SizedBox(width: 10),
                Text("El negocio te notificará sobre este pedido.", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87))
              ],
            ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color activeColor, required String tooltip, required VoidCallback onTap, required Color disabledIconColor, required Color disabledBgColor, bool isDisabled = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 10), 
      child: IconButton(
        onPressed: isDisabled ? null : onTap, 
        icon: Icon(icon, color: isDisabled ? disabledIconColor : activeColor, size: 24), 
        tooltip: tooltip, 
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(12),
          backgroundColor: isDisabled ? disabledBgColor.withOpacity(0.5) : activeColor.withOpacity(0.15), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
        )
      )
    );
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
            Text(_fullQuotation?.clientName ?? widget.clientName ?? "Detalle", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          IconButton(icon: const Icon(Icons.refresh, size: 26), onPressed: _loadData),
          
          if (!isClient && _fullQuotation?.status != 'SOLD') // 🔒 Si está vendido, ocultar menú
            PopupMenuButton<String>(
              color: isDark ? const Color(0xFF23232F) : Colors.white,
              icon: const Icon(Icons.more_vert, size: 26),
              onSelected: (val) {
                if (val == 'DELETE') {
                  _handleDeleteRequest(); 
                } else {
                  _changeStatus(val);
                }
              },
              itemBuilder: (BuildContext context) {
                final current = _fullQuotation?.status ?? 'DRAFT';
                List<PopupMenuEntry<String>> options = [];
                if (current != 'DRAFT') options.add(PopupMenuItem(value: 'DRAFT', child: _StatusRow(icon: Icons.edit_note, color: Colors.grey, text: "Borrador", isDark: isDark)));
                if (current != 'PENDING') options.add(PopupMenuItem(value: 'PENDING', child: _StatusRow(icon: Icons.access_time, color: Colors.orange, text: "Pendiente", isDark: isDark)));
                if (current != 'READY') options.add(PopupMenuItem(value: 'READY', child: _StatusRow(icon: Icons.check_circle_outline, color: Colors.blue, text: "Listo para Vender", isDark: isDark)));
                options.add(const PopupMenuDivider());
                options.add(PopupMenuItem(value: 'CONVERT_PACK', child: _StatusRow(icon: Icons.copy_all, color: Colors.teal, text: "Convertir en Pack Escolar", isDark: isDark)));
                if (current != 'ARCHIVED') options.add(PopupMenuItem(value: 'ARCHIVED', child: _StatusRow(icon: Icons.archive_outlined, color: Colors.purple, text: "Archivar", isDark: isDark)));
                options.add(const PopupMenuDivider());
                options.add(PopupMenuItem(value: 'DELETE', child: _StatusRow(icon: Icons.delete_outline, color: Colors.red, text: "Eliminar Cotización", isDark: isDark)));
                return options;
              },
            ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!isClient && validation != null && (validation.hasIssues || !validation.canSell) && _fullQuotation?.status != 'SOLD') 
                  _buildSmartAlertBanner(validation, isDark),
                
                // 🔥 Mostramos el banner verde de VENDIDO si corresponde
                if (_fullQuotation?.status == 'SOLD')
                  _buildSoldBanner(isDark, isClient),
                
                QuoteDetailHeader(quotation: _fullQuotation, fallbackClientName: widget.clientName, isDark: isDark),
                
                if (showEvidence)
                  QuoteEvidencePanel(
                    hasImage: hasImage, hasText: hasTextEvidence, imageUrl: _fullQuotation?.sourceImageUrl, isDark: isDark,
                    onImageTap: () {
                       if (_fullQuotation?.sourceImageUrl != null) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: _fullQuotation!.sourceImageUrl!, tag: "${_fullQuotation!.id}_evidence")));
                       }
                    },
                    onDownloadTap: _downloadImage, onTextEvidenceTap: () => _showTextEvidenceDialog(isDark),
                  ),
                
                Expanded(
                  child: items.isEmpty 
                    ? Center(child: Text("No hay productos en esta cotización", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 16)))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 20, top: 8),
                        itemCount: items.length, 
                        itemBuilder: (ctx, i) {
                          final item = items[i];
                          final stockWarning = isClient ? null : validation?.stockWarnings.firstWhere((w) => w.itemId == item.id, orElse: () => StockWarning(itemId: -1, productName: "", requested: 0, available: 0));
                          final priceChange = isClient ? null : validation?.priceChanges.firstWhere((p) => p.itemId == item.id, orElse: () => PriceChange(itemId: -1, productName: "", oldPrice: 0, newPrice: 0));
                          
                          if (_filterErrorItems && !isClient) {
                            bool hasError = (stockWarning != null && stockWarning.itemId != -1) || (priceChange != null && priceChange.itemId != -1);
                            if (!hasError) return const SizedBox.shrink();
                          }
                          
                          return QuoteItemListRow(item: item, stockError: stockWarning, priceError: priceChange, isDark: isDark);
                        },
                      ),
                ),
              ],
            ),
      bottomNavigationBar: isClient ? _buildClientBottomBar(isDark) : _buildBottomActionBar(validation, isDark),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final bool isDark;
  
  const _StatusRow({required this.icon, required this.color, required this.text, required this.isDark});
  
  @override
  Widget build(BuildContext context) {
    Color finalColor = isDark ? (color == Colors.blue ? Colors.blue[300]! : color == Colors.red ? Colors.red[300]! : color == Colors.orange ? Colors.orange[300]! : color == Colors.teal ? Colors.teal[300]! : color == Colors.purple ? Colors.purple[300]! : color) : color;
    
    return Row(children: [
      Icon(icon, color: finalColor, size: 22), 
      const SizedBox(width: 12), 
      Text(text, style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500))
    ]);
  }
}