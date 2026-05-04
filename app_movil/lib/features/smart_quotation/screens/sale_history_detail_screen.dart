import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/sale_provider.dart';
import '../providers/quick_sale_provider.dart';
import '../../../../providers/inventory_provider.dart';
import '../../smart_quotation/providers/workbench_provider.dart';

import '../../../widgets/universal_image.dart';
import '../../../widgets/full_screen_image_viewer.dart';

import '../widgets/history/detail_widgets/detail_header_card.dart';
import '../widgets/history/detail_widgets/detail_client_card.dart';
import '../widgets/history/detail_widgets/detail_notes_card.dart';
import '../widgets/history/detail_widgets/detail_status_card.dart';

import 'quick_sale_screen.dart';
import 'pdf_preview_screen.dart';   
import 'whatsapp_preview_screen.dart'; 
import '../../smart_quotation/screens/quotation_detail_screen.dart'; 
import '../../smart_quotation/screens/manual_quotation_screen.dart'; 

class SaleHistoryDetailScreen extends StatefulWidget {
  final int? saleId;
  final int? quotationId; 

  const SaleHistoryDetailScreen({super.key, this.saleId, this.quotationId});

  @override
  State<SaleHistoryDetailScreen> createState() => _SaleHistoryDetailScreenState();
}

class _SaleHistoryDetailScreenState extends State<SaleHistoryDetailScreen> {
  bool _isLoading = true;
  bool _isProcessingAction = false;
  Map<String, dynamic>? _saleData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSaleDetail();
    });
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        backgroundColor: isError ? Colors.red : Colors.green[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      )
    );
  }

  Future<void> _loadSaleDetail() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final saleProv = Provider.of<SaleProvider>(context, listen: false);
    Map<String, dynamic>? data;

    if (widget.saleId != null && widget.saleId! > 0) {
      data = await saleProv.getSaleDetail(widget.saleId!);
    } else if (widget.quotationId != null) {
      try {
        final sale = saleProv.salesHistory.firstWhere((s) => s.quotationId == widget.quotationId);
        data = await saleProv.getSaleDetail(sale.id);
      } catch (e) {
        data = null;
      }
    }

    if (mounted) {
      setState(() {
        _saleData = data;
        _isLoading = false;
      });

      if (data == null) {
        _showSnack("Error al cargar el detalle de la venta", isError: true);
      }
    }
  }

  Map<String, dynamic> _getOrigenStyles(String? origen, bool isDark) {
    if (origen == 'pos_rapido') {
      return {'label': "Venta en Caja Rápida", 'color': isDark ? Colors.pink[300] : Colors.pinkAccent, 'icon': Icons.point_of_sale};
    } else if (origen == 'ai_scan') {
      return {'label': "Lista Escaneada con IA", 'color': isDark ? Colors.purple[300] : Colors.purple, 'icon': Icons.auto_awesome};
    } else if (origen == 'client_web') {
      return {'label': "Pedido desde Web", 'color': isDark ? Colors.blue[300] : Colors.blue, 'icon': Icons.public};
    } else {
      return {'label': "Lista Creada Manualmente", 'color': isDark ? Colors.teal[300] : Colors.teal, 'icon': Icons.edit_note};
    }
  }

  void _handleArchive(bool isDark) async {
    final dialogBgColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_saleData!['is_archived'] == 1 ? "¿Restaurar Venta?" : "¿Anular Venta?", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        content: Text(_saleData!['is_archived'] == 1
            ? "Esta venta volverá a aparecer en el historial principal y sumará a tus ingresos." 
            : "Esta venta se marcará como anulada y restará de tus ingresos diarios. ¿Continuar?",
            style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontSize: 16))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _saleData!['is_archived'] == 1 ? Colors.green : Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isProcessingAction = true);
              final saleProv = Provider.of<SaleProvider>(context, listen: false);
              
              if (widget.saleId != null) {
                 await saleProv.toggleArchiveSale(widget.saleId!);
              } else if (_saleData!['id'] != null) {
                 await saleProv.toggleArchiveSale(_saleData!['id']);
              }
              
              if (mounted) {
                _showSnack(_saleData!['is_archived'] == 1 ? "Venta restaurada exitosamente." : "Venta anulada.");
                Navigator.pop(context); 
              }
            },
            child: Text(_saleData!['is_archived'] == 1 ? "Restaurar" : "Anular", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      )
    );
  }

  void _handleSellAgainQuickSale(bool isDark) {
    final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    
    final items = _saleData!['items'] as List<dynamic>? ?? [];

    if (items.isEmpty) {
      _showSnack("No hay productos vigentes para vender.", isError: true);
      return;
    }

    if (!quickProv.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Caja Ocupada", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
          content: Text("Tienes productos en curso en la Caja Rápida.\n\n¿Deseas limpiar la caja antes de agregar esta venta, o quieres mezclarlos?", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executeRestoreCart(items, invProv, quickProv, clearFirst: false);
              },
              child: Text("Mezclar", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                Navigator.pop(ctx);
                _executeRestoreCart(items, invProv, quickProv, clearFirst: true);
              },
              child: const Text("Limpiar y Cargar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            )
          ],
        )
      );
    } else {
      _executeRestoreCart(items, invProv, quickProv, clearFirst: true);
    }
  }

  Future<void> _executeRestoreCart(List<dynamic> items, InventoryProvider invProv, QuickSaleProvider quickProv, {required bool clearFirst}) async {
    setState(() => _isProcessingAction = true);

    final report = await quickProv.restoreCartFromHistory(items, invProv, clearPrevious: clearFirst);
    
    if (!mounted) return;
    setState(() => _isProcessingAction = false);

    String msg = "Productos enviados a la Caja Rápida.";
    bool isWarning = false;

    if (report['notFound']!.isNotEmpty || report['outOfStock']!.isNotEmpty) {
      isWarning = true;
      msg = "Algunos productos fallaron:\n";
      if (report['outOfStock']!.isNotEmpty) msg += "- ${report['outOfStock']!.length} producto(s) sin stock.\n";
      if (report['notFound']!.isNotEmpty) msg += "- ${report['notFound']!.length} producto(s) no encontrados.";
    }

    _showSnack(msg, isError: isWarning);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const QuickSaleScreen()));
  }

  void _showDuplicateOptionsModal(int cotizacionId, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF23232F) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28))
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.content_copy, color: isDark ? Colors.blue[300] : Colors.blue[800], size: 30),
                  const SizedBox(width: 12),
                  Text("Opciones de Duplicación", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                ],
              ),
              const SizedBox(height: 12),
              Text("Elige cómo deseas duplicar esta lista vendida sin alterar la original.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15)),
              const SizedBox(height: 24),
              
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                leading: CircleAvatar(radius: 26, backgroundColor: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue[50], child: Icon(Icons.shopping_cart_checkout, color: isDark ? Colors.blue[300] : Colors.blue)),
                title: Text("Vender Nuevamente (Genérica)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                subtitle: Text("Crea una copia editable exacta para asignársela a un nuevo cliente.", style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[500] : Colors.grey[600])),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleCloneToGeneric(cotizacionId);
                },
              ),
              Divider(height: 20, color: isDark ? Colors.white10 : Colors.grey[200]),
              
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                leading: CircleAvatar(radius: 26, backgroundColor: isDark ? Colors.purple.withOpacity(0.15) : Colors.purple[50], child: Icon(Icons.inventory_2, color: isDark ? Colors.purple[300] : Colors.purple)),
                title: Text("Guardar como Plantilla (Pack)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                subtitle: Text("Convierte esta lista en un catálogo recurrente.", style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[500] : Colors.grey[600])),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleConvertToPack(cotizacionId);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      }
    );
  }

  Future<void> _handleCloneToGeneric(int cotizacionId) async {
    setState(() => _isProcessingAction = true);
    final workbenchProv = Provider.of<WorkbenchProvider>(context, listen: false);
    int? newQuotationId = await workbenchProv.cloneQuotation(cotizacionId);
    
    if (mounted) {
      setState(() => _isProcessingAction = false);
      if (newQuotationId != null) {
        _showSnack("Lista duplicada exitosamente.");
        Navigator.push(context, MaterialPageRoute(builder: (_) => ManualQuotationScreen(quotationId: newQuotationId)));
      } else {
        _showSnack("No se pudo duplicar la cotización", isError: true);
      }
    }
  }

  Future<void> _handleConvertToPack(int cotizacionId) async {
    setState(() => _isProcessingAction = true);
    final workbenchProv = Provider.of<WorkbenchProvider>(context, listen: false);
    int? newPackId = await workbenchProv.convertToPack(cotizacionId);
    
    if (mounted) {
      setState(() => _isProcessingAction = false);
      if (newPackId != null) {
        _showSnack("Pack Escolar creado exitosamente");
        Navigator.push(context, MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: newPackId)));
      } else {
        _showSnack("No se pudo crear el pack", isError: true);
      }
    }
  }

  Future<void> _showEditNoteDialog({required String type, required String currentNote, required int id}) async {
    final ctrl = TextEditingController(text: currentNote);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isClient = type == 'client';
    
    final title = isClient ? (currentNote.isEmpty ? "Agregar Nota al Cliente" : "Editar Nota del Cliente") : (currentNote.isEmpty ? "Agregar Nota de Venta" : "Editar Nota de la Venta");
    final color = isClient ? (isDark ? Colors.blue[300] : Colors.blue[800]) : (isDark ? Colors.orange[300] : Colors.orange[800]);

    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(isClient ? Icons.assignment_ind : Icons.speaker_notes, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18))),
          ],
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
          decoration: InputDecoration(
            hintText: "Escribe la nota aquí...",
            hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey),
            filled: true,
            fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar", style: TextStyle(fontSize: 16))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Guardar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          )
        ]
      )
    );

    if (confirm == true && mounted) {
      setState(() => _isProcessingAction = true);
      final saleProv = Provider.of<SaleProvider>(context, listen: false);
      bool success = false;
      final newText = ctrl.text.trim();
      
      if (isClient) {
        success = await saleProv.updateClientNote(id, newText);
        if (success) {
          setState(() {
            _saleData!['cliente_notas'] = newText;
          });
        }
      } else {
        success = await saleProv.updateQuotationNote(id, newText);
        if (success) {
          setState(() {
            if (_saleData!['cotizacion'] != null) {
              _saleData!['cotizacion']['notas'] = newText;
            }
          });
        }
      }

      setState(() => _isProcessingAction = false);

      if (success) {
        _showSnack(currentNote.isEmpty ? "Nota agregada correctamente" : "Nota actualizada correctamente");
      } else {
        _showSnack("Error al guardar la nota", isError: true);
      }
    }
  }

  void _showAddNoteMenu(int cotizacionId, int? clientId, String currentSaleNote, String currentClientNote, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF23232F) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28))
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.edit_note, color: isDark ? Colors.amber[300] : Colors.amber[800], size: 30),
                  const SizedBox(width: 12),
                  Text("Gestionar Notas", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                ],
              ),
              const SizedBox(height: 12),
              Text("¿Qué tipo de nota deseas agregar o modificar?", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15)),
              const SizedBox(height: 24),
              
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                leading: CircleAvatar(radius: 26, backgroundColor: isDark ? Colors.orange.withOpacity(0.15) : Colors.orange[50], child: Icon(Icons.speaker_notes, color: isDark ? Colors.orange[300] : Colors.orange[800])),
                title: Text(currentSaleNote.isEmpty ? "Agregar Nota de Venta" : "Editar Nota de Venta", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                subtitle: Text("Detalles exclusivos para este recibo en particular.", style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[500] : Colors.grey[600])),
                onTap: () {
                  Navigator.pop(ctx);
                  if(cotizacionId > 0) {
                     _showEditNoteDialog(type: 'sale', currentNote: currentSaleNote, id: cotizacionId);
                  } else {
                     _showSnack("No se puede agregar nota a esta venta (ID Inválido)", isError: true);
                  }
                },
              ),
              
              if (clientId != null && clientId > 0) ...[
                Divider(height: 20, color: isDark ? Colors.white10 : Colors.grey[200]),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  leading: CircleAvatar(radius: 26, backgroundColor: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue[50], child: Icon(Icons.assignment_ind, color: isDark ? Colors.blue[300] : Colors.blue[800])),
                  title: Text(currentClientNote.isEmpty ? "Agregar Nota al Cliente (CRM)" : "Editar Nota del Cliente", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text("Se guardará en el perfil general del cliente.", style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[500] : Colors.grey[600])),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditNoteDialog(type: 'client', currentNote: currentClientNote, id: clientId);
                  },
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_isLoading) return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator()));
    if (_saleData == null) return Scaffold(backgroundColor: bgColor, appBar: AppBar(title: const Text("Detalle")), body: const Center(child: Text("Error al cargar datos.")));

    // Extraemos de la consulta optimizada SQLite
    final items = _saleData!['items'] as List<dynamic>? ?? [];
    final origenVenta = _saleData!['origen_venta'];
    final styles = _getOrigenStyles(origenVenta, isDark);
    
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final dateFormat = DateFormat('dd/MM/yyyy - hh:mm a');
    final String dateString = _saleData!['fecha_venta'] != null ? dateFormat.format(DateTime.parse(_saleData!['fecha_venta'])) : "";

    final bool isQuickSale = origenVenta == 'pos_rapido';
    final int cotizacionId = _saleData!['cotizacion_id'] ?? 0;
    final int? clientId = _saleData!['cliente_id'];

    // Extraer datos de la cotización origen si existe
    final Map<String, dynamic>? cotizacion = _saleData!['cotizacion'] as Map<String, dynamic>?;
    final String institution = cotizacion?['institution_name'] ?? "";
    final String grade = cotizacion?['grade_level'] ?? "";
    final String imageUrl = "";

    final String clientNote = _saleData!['cliente_notas'] ?? ""; 
    final String saleNote = cotizacion?['notas'] ?? ""; 

    final double totalAmount = (_saleData!['monto_total'] ?? 0).toDouble();
    final double paidAmount = (_saleData!['monto_pagado'] ?? 0).toDouble();
    double pendingDebt = totalAmount - paidAmount;
    if (pendingDebt < 0) pendingDebt = 0;
    
    final List<dynamic> cuotasRaw = _saleData!['cuotas'] ?? [];

    return Stack(
      children: [
        Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text("Recibo #${_saleData!['id'].toString().padLeft(5, '0')}", style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 20)),
            backgroundColor: Colors.transparent,
            iconTheme: IconThemeData(color: textColor),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.note_add),
                tooltip: "Añadir o Editar Notas",
                onPressed: () => _showAddNoteMenu(cotizacionId, clientId, saleNote, clientNote, isDark),
              ),
              PopupMenuButton<String>(
                color: isDark ? const Color(0xFF23232F) : Colors.white,
                icon: Icon(Icons.more_vert, color: textColor),
                onSelected: (val) { if (val == 'archive') _handleArchive(isDark); },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'archive', 
                    child: Row(children: [
                      Icon(_saleData!['is_archived'] == 1 ? Icons.unarchive : Icons.auto_delete, color: _saleData!['is_archived'] == 1 ? (isDark ? Colors.green[400] : Colors.green) : (isDark ? Colors.red[400] : Colors.red), size: 24), 
                      const SizedBox(width: 12), 
                      Text(_saleData!['is_archived'] == 1 ? "Restaurar Venta" : "Anular Venta", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16))
                    ])
                  )
                ],
              )
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                DetailHeaderCard(
                  saleData: _saleData!,
                  styles: styles,
                  totalAmount: totalAmount,
                  dateString: dateString,
                  isDark: isDark,
                ),

                const SizedBox(height: 16),

                DetailClientCard(
                  saleData: _saleData!,
                  isQuickSale: isQuickSale,
                  institution: institution,
                  grade: grade,
                  isDark: isDark,
                ),

                DetailNotesCard(
                  saleNote: saleNote,
                  clientNote: clientNote,
                  cotizacionId: cotizacionId,
                  clientId: clientId,
                  isDark: isDark,
                  onEditTap: (type, currentNote, id) => _showEditNoteDialog(
                    type: type, 
                    currentNote: currentNote, 
                    id: id
                  ),
                ),

                DetailStatusCard(
                  saleData: _saleData!,
                  totalAmount: totalAmount,
                  paidAmount: paidAmount,
                  pendingDebt: pendingDebt,
                  cuotasRaw: cuotasRaw,
                  isDark: isDark,
                ),

                if (imageUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Card(
                      elevation: 0, color: isDark ? Colors.purple.withOpacity(0.15) : Colors.purple.shade50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.purple.withOpacity(0.3) : Colors.purple.shade200)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: Icon(Icons.image, color: isDark ? Colors.purple[200] : Colors.purple, size: 30), 
                        title: Text("Ver lista física escaneada", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.purple[100] : Colors.purple)), 
                        trailing: Icon(Icons.arrow_forward_ios, size: 20, color: isDark ? Colors.purple[200] : Colors.purple),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: imageUrl, tag: "evidence_${_saleData!['id']}"))),
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("PRODUCTOS ENTREGADOS (${items.length})", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey, letterSpacing: 1)),
                      const SizedBox(height: 16),
                      ListView.separated(
                        physics: const NeverScrollableScrollPhysics(), shrinkWrap: true, itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final item = items[i];
                          final double unitPrice = (item['unit_price_applied'] ?? 0.0).toDouble();
                          final double originalPrice = (item['original_unit_price'] ?? unitPrice).toDouble();
                          final int qty = item['quantity'] ?? 1;
                          final double subtotal = unitPrice * qty;
                          final String imgUrl = item['image_url'] ?? "";
                          final bool hadDiscount = originalPrice > unitPrice + 0.01;

                          bool isStructured = item['product_name'] != null && item['product_name'].toString().isNotEmpty;

                          return Container(
                            padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 55, height: 55,
                                  decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[100], border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade300), borderRadius: BorderRadius.circular(12)), 
                                  child: ClipRRect(borderRadius: BorderRadius.circular(12), child: imgUrl.isNotEmpty ? UniversalImage(path: imgUrl, fit: BoxFit.cover) : Icon(Icons.inventory_2, color: isDark ? Colors.grey[600] : Colors.grey, size: 30))
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start, 
                                    children: [
                                      if (isStructured) ...[
                                        if (item['brand_name'] != null && item['brand_name'].toString().isNotEmpty)
                                           Text(item['brand_name'].toString().toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.indigo[300] : Colors.indigo[600], letterSpacing: 0.5)),
                                        
                                        Text(item['product_name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.2, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        
                                        if (item['specific_name'] != null && item['specific_name'].toString().isNotEmpty)
                                           Padding(
                                             padding: const EdgeInsets.only(top: 2),
                                             child: Text(item['specific_name'], style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: isDark ? Colors.teal[300] : Colors.teal[700]), maxLines: 1, overflow: TextOverflow.ellipsis),
                                           ),
                                      ] else ...[
                                        Text(item['product_name_snapshot'] ?? 'Producto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.2, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis), 
                                      ],
                                      
                                      const SizedBox(height: 10), 
                                      Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 10,
                                        runSpacing: 8,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[200], borderRadius: BorderRadius.circular(6)),
                                            child: Text("Cant: $qty", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor))
                                          ),
                                          if (isStructured && item['sales_unit'] != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(color: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                                              child: Text(item['sales_unit'].toString().toUpperCase(), style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[700], fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          if (hadDiscount) Text(currency.format(originalPrice), style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, decoration: TextDecoration.lineThrough, fontSize: 12, fontWeight: FontWeight.bold)),
                                          Text(currency.format(unitPrice), style: TextStyle(color: hadDiscount ? (isDark ? Colors.green[400] : Colors.green[700]) : (isDark ? Colors.grey[400] : Colors.grey[700]), fontSize: 13, fontWeight: hadDiscount ? FontWeight.bold : FontWeight.normal)),
                                        ],
                                      )
                                    ]
                                  )
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 85,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(currency.format(subtotal), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textColor)),
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),

          bottomNavigationBar: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: cardColor,
              boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, -10))],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28))
            ),
            child: SafeArea( 
              child: Row(
                children: [
                  Expanded(child: _buildIconButton(Icons.picture_as_pdf, isDark ? Colors.red[400]! : Colors.red[700]!, "PDF", isDark, () => Navigator.push(context, MaterialPageRoute(builder: (_) => PdfPreviewScreen(quotationId: cotizacionId, saleId: widget.saleId))))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildIconButton(Icons.chat, isDark ? Colors.green[400]! : Colors.green[600]!, "WhatsApp", isDark, () => Navigator.push(context, MaterialPageRoute(builder: (_) => WhatsAppPreviewScreen(quotationId: cotizacionId, saleId: widget.saleId))))),
                  const SizedBox(width: 16),
                  
                  if (isQuickSale)
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _handleSellAgainQuickSale(isDark),
                        icon: const Icon(Icons.refresh, size: 24),
                        label: const Text("Volver a Vender", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), backgroundColor: isDark ? Colors.pink[400] : Colors.pinkAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      ),
                    )
                  else if (cotizacionId > 0)
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _showDuplicateOptionsModal(cotizacionId, isDark),
                        icon: const Icon(Icons.content_copy, size: 24),
                        label: const Text("Opciones", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), backgroundColor: isDark ? Colors.blue[400] : Colors.blue[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      ),
                    )
                ],
              ),
            ),
          ),
        ),

        if (_isProcessingAction)
          Container(
            color: Colors.black87,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 24),
                  Text("Procesando...", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
                ],
              )
            ),
          )
      ],
    );
  }

  Widget _buildIconButton(IconData icon, Color color, String label, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(icon, color: color, size: 26)],
        ),
      ),
    );
  }
}