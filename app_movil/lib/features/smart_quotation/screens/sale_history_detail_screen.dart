// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';

import 'package:app_movil/core/widgets/full_screen_image_viewer.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/detail_header_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/detail_client_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/detail_notes_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/detail_status_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/sale_items_list.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/sale_action_footer.dart';

import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/payment_entry_modal.dart';
import 'package:app_movil/features/smart_quotation/screens/quick_sale_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/quotation_detail_screen.dart'; 
import 'package:app_movil/features/smart_quotation/screens/manual_quotation_screen.dart'; 

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
    } else if (origen == 'prestamo_personal') {
      return {'label': "Préstamo Personal", 'color': isDark ? Colors.amber[300] : Colors.amber[800], 'icon': Icons.account_balance_wallet};
    } else if (origen == 'ai_scan') {
      return {'label': "Lista Escaneada con IA", 'color': isDark ? Colors.purple[300] : Colors.purple, 'icon': Icons.auto_awesome};
    } else if (origen == 'client_web') {
      return {'label': "Pedido desde Web", 'color': isDark ? Colors.blue[300] : Colors.blue, 'icon': Icons.public};
    } else {
      return {'label': "Lista Creada Manualmente", 'color': isDark ? Colors.teal[300] : Colors.teal, 'icon': Icons.edit_note};
    }
  }

  void _handleArchive(bool isDark) async {
    final nav = Navigator.of(context);
    final saleProv = Provider.of<SaleProvider>(context, listen: false);
    final trackingProv = Provider.of<TrackingProvider>(context, listen: false);
    final dialogBgColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    String? selectedReason;
    if (_saleData!['is_archived'] != 1) {
      final List<String> motivos = [
        "Error de digitación",
        "Falta de stock",
        "Precio muy alto",
        "Cliente arrepentido",
        "Mala atención",
        "Otro"
      ];
      selectedReason = await showDialog<String>(
        context: context,
        builder: (ctx) {
          String? currentVal;
          return StatefulBuilder(
            builder: (context, setModalState) {
              return AlertDialog(
                backgroundColor: dialogBgColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text("¿Anular Venta?", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Selecciona el motivo de la anulación:", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700])),
                    ...motivos.map((m) => ListTile(
                      title: Text(m, style: TextStyle(fontSize: 14, color: textColor)),
                      leading: Radio<String>(
                        value: m,
                        groupValue: currentVal,
                        onChanged: (val) => setModalState(() => currentVal = val),
                      ),
                      contentPadding: EdgeInsets.zero,
                      onTap: () => setModalState(() => currentVal = m),
                    )),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontSize: 16))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: currentVal == null ? null : () => Navigator.pop(ctx, currentVal), 
                    child: const Text("Anular", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  )
                ],
              );
            }
          );
        }
      );
      if (selectedReason == null) return;
    } else {
      // It is archived, confirm restore
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: dialogBgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(_saleData!['origen_venta'] == 'prestamo_personal' ? "¿Restaurar Préstamo?" : "¿Restaurar Venta?", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          content: Text(_saleData!['origen_venta'] == 'prestamo_personal' ? "Este préstamo volverá a estar activo." : "Esta venta volverá a aparecer en el historial principal y sumará a tus ingresos.", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontSize: 16))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Restaurar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            )
          ],
        )
      );
      if (confirm != true) return;
    }

    setState(() => _isProcessingAction = true);
    
    try {
      int idTarget = widget.saleId ?? _saleData!['id'];
      if (_saleData!['is_archived'] == 1) {
         await saleProv.restoreSale(idTarget);
      } else {
         await saleProv.voidSale(idTarget, selectedReason!);
      }
      
      try {
        await trackingProv.loadClients();
      } catch (_) {}

      if (mounted) {
        final isLoan = _saleData!['origen_venta'] == 'prestamo_personal';
        _showSnack(_saleData!['is_archived'] == 1 ? (isLoan ? "Préstamo restaurado exitosamente." : "Venta restaurada exitosamente.") : (isLoan ? "Préstamo anulado exitosamente." : "Venta anulada y stock devuelto."));
        nav.pop(); 
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingAction = false);
        _showSnack(e.toString().replaceAll("Exception: ", ""), isError: true);
      }
    }
  }

  void _handleRegisterPayment() async {
    final clientId = _saleData?['cliente_id'];
    if (clientId == null || clientId <= 0) {
      _showSnack("Esta operación no tiene un cliente asociado para registrar abonos.", isError: true);
      return;
    }

    final saleProv = Provider.of<SaleProvider>(context, listen: false);
    final client = await saleProv.getClientById(clientId);
    if (client == null) {
      _showSnack("No se encontró el registro del cliente.", isError: true);
      return;
    }

    if (mounted) {
      final double totalAmount = (_saleData?['monto_total'] ?? 0.0).toDouble();
      final double paidAmount = (_saleData?['monto_pagado'] ?? 0.0).toDouble();
      final double diff = totalAmount - paidAmount;
      final double pendingDebt = diff > 0.01 ? diff : 0.0;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => PaymentEntryModal(
          client: client,
          initialTargetType: 'venta',
          initialTargetId: _saleData?['id'],
          initialAmount: pendingDebt,
          onPaymentSuccess: () {
            _loadSaleDetail();
            saleProv.silentRefresh();
          },
        ),
      );
    }
  }

  void _handleSellAgainQuickSale(bool isDark) {
    final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final promoProv = Provider.of<PromotionProvider>(context, listen: false);
    
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
                _executeRestoreCart(items, invProv, promoProv, quickProv, clearFirst: false);
              },
              child: Text("Mezclar", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                Navigator.pop(ctx);
                _executeRestoreCart(items, invProv, promoProv, quickProv, clearFirst: true);
              },
              child: const Text("Limpiar y Cargar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            )
          ],
        )
      );
    } else {
      _executeRestoreCart(items, invProv, promoProv, quickProv, clearFirst: true);
    }
  }

  Future<void> _executeRestoreCart(List<dynamic> items, InventoryProvider invProv, PromotionProvider promoProv, QuickSaleProvider quickProv, {required bool clearFirst}) async {
    setState(() => _isProcessingAction = true);

    final report = await quickProv.restoreCartFromHistory(items, invProv, promoProv, clearPrevious: clearFirst);
    
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
    InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) {
        return InteractiveSheetWrapper(
          applyEffectiveBottomPadding: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.content_copy, color: isDark ? Colors.blue[300] : Colors.blue[800], size: 28),
                    const SizedBox(width: 12),
                    Text("Opciones de Duplicación", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
                const SizedBox(height: 10),
                Text("Elige cómo deseas duplicar esta lista vendida sin alterar la original.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 20),
                
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  leading: CircleAvatar(radius: 24, backgroundColor: isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue[50], child: Icon(Icons.shopping_cart_checkout, color: isDark ? Colors.blue[300] : Colors.blue)),
                  title: Text("Vender Nuevamente (Genérica)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text("Crea una copia editable exacta para asignársela a un nuevo cliente.", style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey[600])),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleCloneToGeneric(cotizacionId);
                  },
                ),
                Divider(height: 16, color: isDark ? Colors.white10 : Colors.grey[200]),
                
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  leading: CircleAvatar(radius: 24, backgroundColor: isDark ? Colors.purple.withValues(alpha: 0.15) : Colors.purple[50], child: Icon(Icons.inventory_2, color: isDark ? Colors.purple[300] : Colors.purple)),
                  title: Text("Guardar como Plantilla (Pack)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text("Convierte esta lista en un catálogo recurrente.", style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey[600])),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleConvertToPack(cotizacionId);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
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
    final isLoan = type == 'loan';
    
    final String title;
    final String hintText;
    final Color color;
    final IconData icon;

    if (isClient) {
      title = currentNote.isEmpty ? "Agregar Nota al Cliente" : "Editar Nota del Cliente";
      hintText = "Escribe la observación general del cliente aquí...";
      color = isDark ? Colors.blue[300]! : Colors.blue[800]!;
      icon = Icons.assignment_ind;
    } else if (isLoan) {
      title = currentNote.isEmpty ? "Agregar Nota del Préstamo" : "Editar Nota del Préstamo";
      hintText = "Escribe el motivo u observación del préstamo aquí...";
      color = isDark ? Colors.amber[300]! : Colors.amber[800]!;
      icon = Icons.monetization_on_outlined;
    } else {
      title = currentNote.isEmpty ? "Agregar Nota de Venta" : "Editar Nota de la Venta";
      hintText = "Escribe los detalles o nota de la venta aquí...";
      color = isDark ? Colors.orange[300]! : Colors.orange[800]!;
      icon = Icons.speaker_notes;
    }

    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18))),
          ],
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
          decoration: InputDecoration(
            hintText: hintText,
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
      } else if (isLoan) {
        success = await saleProv.updateSaleNote(id, newText);
        if (success) {
          setState(() {
            _saleData!['nota_prestamo'] = newText;
            _saleData!['notes'] = newText;
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

  void _showAddNoteMenu({
    required int cotizacionId,
    required int? clientId,
    required String currentSaleNote,
    required String currentClientNote,
    required bool isDark,
    required bool isLoan,
    required int saleId,
  }) {
    InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) {
        return InteractiveSheetWrapper(
          applyEffectiveBottomPadding: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_note, color: isDark ? Colors.amber[300] : Colors.amber[800], size: 28),
                    const SizedBox(width: 12),
                    Text("Gestionar Notas", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isLoan
                      ? "¿Qué tipo de nota deseas registrar en este préstamo?"
                      : "¿Qué tipo de nota deseas agregar o modificar?",
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 20),
                
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange[50],
                    child: Icon(
                      isLoan ? Icons.monetization_on_outlined : Icons.speaker_notes,
                      color: isDark ? Colors.orange[300] : Colors.orange[800],
                    ),
                  ),
                  title: Text(
                    currentSaleNote.isEmpty
                        ? (isLoan ? "Agregar Motivo del Préstamo" : "Agregar Nota de Venta")
                        : (isLoan ? "Editar Motivo del Préstamo" : "Editar Nota de Venta"),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87),
                  ),
                  subtitle: Text(
                    isLoan
                        ? "Motivo, condiciones o acuerdos particulares de este préstamo."
                        : "Detalles exclusivos para este recibo en particular.",
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (isLoan) {
                      _showEditNoteDialog(type: 'loan', currentNote: currentSaleNote, id: saleId);
                    } else if (cotizacionId > 0) {
                      _showEditNoteDialog(type: 'sale', currentNote: currentSaleNote, id: cotizacionId);
                    } else {
                      _showEditNoteDialog(type: 'loan', currentNote: currentSaleNote, id: saleId);
                    }
                  },
                ),
                
                if (clientId != null && clientId > 0) ...[
                  Divider(height: 16, color: isDark ? Colors.white10 : Colors.grey[200]),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue[50],
                      child: Icon(Icons.assignment_ind, color: isDark ? Colors.blue[300] : Colors.blue[800]),
                    ),
                    title: Text(
                      currentClientNote.isEmpty ? "Agregar Nota al Cliente (CRM)" : "Editar Nota del Cliente",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87),
                    ),
                    subtitle: Text(
                      "Se guardará en el perfil general del cliente.",
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showEditNoteDialog(type: 'client', currentNote: currentClientNote, id: clientId);
                    },
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
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

    final dateFormat = DateFormat('dd/MM/yyyy - hh:mm a');
    final String dateString = _saleData!['fecha_venta'] != null ? dateFormat.format(DateTime.parse(_saleData!['fecha_venta'])) : "";

    final bool isQuickSale = origenVenta == 'pos_rapido';
    final bool isLoan = origenVenta == 'prestamo_personal';
    final int cotizacionId = _saleData!['cotizacion_id'] ?? 0;
    final int? clientId = _saleData!['cliente_id'];
    final int effectiveSaleId = widget.saleId ?? (_saleData!['id'] as int? ?? 0);

    // Extraer datos de la cotización origen si existe
    final Map<String, dynamic>? cotizacion = _saleData!['cotizacion'] as Map<String, dynamic>?;
    final String institution = cotizacion?['institution_name'] ?? "";
    final String grade = cotizacion?['grade_level'] ?? "";
    final String imageUrl = "";

    final String clientNote = _saleData!['cliente_notas'] ?? ""; 
    final String saleNote = isLoan 
        ? (_saleData!['nota_prestamo'] ?? "") 
        : (cotizacion?['notas'] ?? _saleData!['nota_prestamo'] ?? ""); 

    double totalAmount = (_saleData!['monto_total'] ?? 0).toDouble();
    final double paidAmount = (_saleData!['monto_pagado'] ?? 0).toDouble();
    
    double pendingDebt = totalAmount - paidAmount;
    if (pendingDebt < 0) pendingDebt = 0;
    
    final List<dynamic> cuotasRaw = _saleData!['cuotas'] ?? [];

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          try {
            Provider.of<SaleProvider>(context, listen: false).silentRefresh();
          } catch (_) {}
        }
      },
      child: Stack(
        children: [
          Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text(
              isLoan
                  ? "Préstamo #${_saleData!['numero_secuencial'] ?? _saleData!['id']}"
                  : "Recibo #${_saleData!['numero_secuencial'] ?? _saleData!['id']}",
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 20),
            ),
            backgroundColor: bgColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
            actions: [
              IconButton(
                icon: const Icon(Icons.note_add),
                tooltip: "Añadir o Editar Notas",
                onPressed: () => _showAddNoteMenu(
                  cotizacionId: cotizacionId,
                  clientId: clientId,
                  currentSaleNote: saleNote,
                  currentClientNote: clientNote,
                  isDark: isDark,
                  isLoan: isLoan,
                  saleId: effectiveSaleId,
                ),
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
                      Text(_saleData!['is_archived'] == 1 ? (isLoan ? "Restaurar Préstamo" : "Restaurar Venta") : (isLoan ? "Anular Préstamo" : "Anular Venta"), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16))
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
                  clientId: _saleData!['cliente_id'],
                ),

                DetailNotesCard(
                  saleNote: saleNote,
                  clientNote: clientNote,
                  cotizacionId: cotizacionId,
                  clientId: clientId,
                  saleId: effectiveSaleId,
                  isDark: isDark,
                  isLoan: isLoan,
                  onEditTap: (type, currentNote, id) => _showEditNoteDialog(
                    type: (isLoan || type == 'loan') ? 'loan' : type, 
                    currentNote: currentNote, 
                    id: (isLoan || type == 'loan') ? effectiveSaleId : id,
                  ),
                ),

                DetailStatusCard(
                  saleData: _saleData!,
                  totalAmount: totalAmount,
                  paidAmount: paidAmount,
                  pendingDebt: pendingDebt,
                  cuotasRaw: cuotasRaw,
                  isDark: isDark,
                  onPaymentSuccess: _loadSaleDetail,
                ),

                if (imageUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Card(
                      elevation: 0, color: isDark ? Colors.purple.withValues(alpha: 0.15) : Colors.purple.shade50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.purple.withValues(alpha: 0.3) : Colors.purple.shade200)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: Icon(Icons.image, color: isDark ? Colors.purple[200] : Colors.purple, size: 30), 
                        title: Text("Ver lista física escaneada", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.purple[100] : Colors.purple)), 
                        trailing: Icon(Icons.arrow_forward_ios, size: 20, color: isDark ? Colors.purple[200] : Colors.purple),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: imageUrl, tag: "evidence_${_saleData!['id']}"))),
                      ),
                    ),
                  ),

                if (!isLoan)
                  SaleItemsList(
                    items: items,
                    isDark: isDark,
                    cardColor: cardColor,
                    textColor: textColor,
                  ),
                SizedBox(height: kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom + 60),
              ],
            ),
          ),

          bottomNavigationBar: SaleActionFooter(
            isDark: isDark,
            cardColor: cardColor,
            cotizacionId: cotizacionId,
            saleId: widget.saleId,
            isQuickSale: isQuickSale,
            isLoan: isLoan,
            pendingDebt: pendingDebt,
            onSellAgainQuickSale: () => _handleSellAgainQuickSale(isDark),
            onDuplicateOptions: () => _showDuplicateOptionsModal(cotizacionId, isDark),
            onRegisterPayment: _handleRegisterPayment,
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}