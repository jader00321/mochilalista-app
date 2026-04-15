import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'dart:convert'; 

import '../../providers/scanner_provider.dart';
import '../../models/scanner_models.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/universal_image.dart'; 
import 'invoice_staging_screen.dart'; 

import '../../widgets/review/provider_info_card.dart';
import '../../widgets/review/review_item_card.dart';

class InvoiceReviewScreen extends StatefulWidget {
  const InvoiceReviewScreen({super.key});

  @override
  State<InvoiceReviewScreen> createState() => _InvoiceReviewScreenState();
}

class _InvoiceReviewScreenState extends State<InvoiceReviewScreen> {
  late TextEditingController _providerNameCtrl;
  late TextEditingController _rucCtrl;
  late TextEditingController _dateCtrl;
  late TextEditingController _montoTotalCtrl; 
  
  List<AIItemExtracted> _localItems = [];
  bool _isInit = false;

  late MultiSplitViewController _splitController;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _splitController = MultiSplitViewController(
      areas: [
        Area(size: 0.35, min: 0.20), 
        Area(size: 0.65, min: 0.45), 
      ],
    );

    _scrollController.addListener(() {
      if (_scrollController.offset > 200 && !_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      } else if (_scrollController.offset <= 200 && _showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final provider = Provider.of<ScannerProvider>(context, listen: false);
      
      _providerNameCtrl = TextEditingController(text: provider.aiRawData?.proveedorDetectado ?? "");
      _rucCtrl = TextEditingController(text: provider.aiRawData?.rucDetectado ?? "");
      _dateCtrl = TextEditingController(text: provider.aiRawData?.fechaDetectada ?? "");
      _montoTotalCtrl = TextEditingController(text: provider.aiRawData?.montoTotalFactura?.toStringAsFixed(2) ?? "");
      
      if (provider.aiRawData != null) {
        _localItems = provider.aiRawData!.items.map((item) {
          if ((item.productoPadreEstimado == null || item.productoPadreEstimado!.isEmpty) && 
              item.descripcion.isNotEmpty) {
            item.productoPadreEstimado = item.descripcion;
          }
          return item;
        }).toList();
      }
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _providerNameCtrl.dispose();
    _rucCtrl.dispose();
    _dateCtrl.dispose();
    _montoTotalCtrl.dispose();
    _splitController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOutCubic);
  }

  // 🔥 VISOR DE AUDITORÍA: VISTA AMIGABLE + VISTA JSON
  void _showRawDataAudit(BuildContext context, bool isDark) {
    final provider = Provider.of<ScannerProvider>(context, listen: false);
    
    String rawJson = "Sin datos registrados.";
    if (provider.aiRawData != null) {
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      rawJson = encoder.convert(provider.aiRawData!.toJson());
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool showRawJson = false; 
        
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollController) => Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A24) : Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
                ),
                padding: const EdgeInsets.only(top: 8, bottom: 24, left: 16, right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(Icons.memory, color: isDark ? Colors.blue[300] : Colors.blue, size: 28),
                        const SizedBox(width: 10),
                        Text("Auditoría de Extracción", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // TOGGLE BUTTONS
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => showRawJson = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !showRawJson ? (isDark ? Colors.blue[800] : Colors.white) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: !showRawJson && !isDark ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : []
                                ),
                                child: Center(child: Text("Vista Resumida", style: TextStyle(fontWeight: FontWeight.bold, color: !showRawJson ? (isDark ? Colors.white : Colors.blue[800]) : Colors.grey))),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => showRawJson = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: showRawJson ? (isDark ? Colors.blue[800] : Colors.white) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: showRawJson && !isDark ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : []
                                ),
                                child: Center(child: Text("Código JSON", style: TextStyle(fontWeight: FontWeight.bold, color: showRawJson ? (isDark ? Colors.white : Colors.blue[800]) : Colors.grey))),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // CONTENIDO DINÁMICO
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(showRawJson ? 16 : 0),
                        decoration: BoxDecoration(
                          color: showRawJson ? (isDark ? const Color(0xFF0D0D14) : Colors.white) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: showRawJson ? Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300) : null
                        ),
                        child: showRawJson 
                          ? SingleChildScrollView(
                              controller: scrollController,
                              child: Text(
                                rawJson,
                                style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: isDark ? Colors.green[300] : Colors.green[800], height: 1.5),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: provider.aiRawData?.items.length ?? 0,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final aiItem = provider.aiRawData!.items[i];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF23232F) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200)
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(aiItem.descripcion, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("Llevado: ${aiItem.cantidadUmpComprada} ${aiItem.umpCompra}", style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                                          Text("Total: S/ ${aiItem.totalPagoLote.toStringAsFixed(2)}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.green[300] : Colors.green[700])),
                                        ],
                                      )
                                    ],
                                  ),
                                );
                              },
                            ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.blue[800] : Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text("ENTENDIDO", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    )
                  ]
                )
              )
            );
          }
        );
      }
    );
  }

  void _showInvoiceMetadataModal(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
           decoration: BoxDecoration(
             color: isDark ? const Color(0xFF1A1A24) : Colors.grey[100],
             borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
           ),
           padding: const EdgeInsets.only(top: 8, bottom: 24),
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
                Container(width: 40, height: 5, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 16),
                Text("Datos del Comprobante", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 16),
                ProviderInfoCard(
                  providerNameCtrl: _providerNameCtrl,
                  rucCtrl: _rucCtrl,
                  dateCtrl: _dateCtrl,
                  montoTotalCtrl: _montoTotalCtrl, 
                  isDark: isDark,
                ),
             ]
           )
        )
      )
    );
  }

  void _addManualItem() {
    setState(() {
      _localItems.add(
        AIItemExtracted(
          descripcion: "Nuevo Producto",
          productoPadreEstimado: "",
          varianteDetectada: "",
          umpCompra: "UND",
          unidadesPorLote: 1,
          cantidadUmpComprada: 1.0,
          precioUmpProveedor: 0.0,
          totalPagoLote: 0.0,
          unidadVenta: "Unidad", // 🔥 AHORA RESPETA LA NUEVA LÓGICA
        )
      );
    });
  }

  void _confirmRemoveItem(String targetUuid) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: isDark ? Colors.red[300] : Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text("Eliminar Fila", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16))),
          ],
        ),
        content: Text("¿Estás seguro de que deseas descartar este producto de la lista?", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontSize: 14))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.red[800] : Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _localItems.removeWhere((item) => item.uuidTemporal == targetUuid);
              });
              CustomSnackBar.show(context, message: "Ítem eliminado correctamente", isError: false);
            },
            child: const Text("Sí, Eliminar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          )
        ],
      )
    );
  }

  void _analyzeAndContinue() async {
    final provider = Provider.of<ScannerProvider>(context, listen: false);

    if (_localItems.isEmpty) {
      CustomSnackBar.show(context, message: "La lista no puede estar vacía", isError: true);
      return;
    }

    if (_providerNameCtrl.text.trim().isEmpty) {
      CustomSnackBar.show(context, message: "El nombre del proveedor es obligatorio (Abre 'Resumen Factura')", isError: true);
      return;
    }

    provider.updateRawItems(
      _localItems, 
      _providerNameCtrl.text.trim(),
      _rucCtrl.text.trim(),
      _dateCtrl.text.trim(),
      double.tryParse(_montoTotalCtrl.text.trim())
    );

    final success = await provider.runMatchingProcess();
    if (!mounted) return;

    if (success) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceStagingScreen()));
    } else {
      CustomSnackBar.show(context, message: provider.statusMessage.isNotEmpty ? provider.statusMessage : "Error al procesar datos", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ScannerProvider>(context);
    final imageFile = provider.currentImage;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    if (imageFile == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(title: const Text("Error")),
        body: const Center(child: Text("No hay imagen cargada")),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Revisión de Compras", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text("${_localItems.length} ítems detectados", style: TextStyle(fontSize: 12, color: isDark ? Colors.green[200] : Colors.green[100], fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF142C23) : const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.code, color: Colors.white, size: 24),
            tooltip: "Ver Auditoría IA",
            onPressed: () => _showRawDataAudit(context, isDark),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              icon: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
              label: const Text("Resumen", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              style: TextButton.styleFrom(
                backgroundColor: isDark ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
              ),
              onPressed: () => _showInvoiceMetadataModal(context, isDark),
            ),
          ),
        ],
      ),
      
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A24) : Colors.white,
          boxShadow: [if (!isDark) const BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]
        ),
        child: SafeArea(
          child: SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: provider.isLoading ? null : _analyzeAndContinue,
              icon: provider.isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline, size: 20),
              label: Text(provider.isLoading ? "PROCESANDO..." : "CONFIRMAR E IR A INVENTARIO", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? Colors.green[600] : Colors.green[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
            ),
          ),
        ),
      ),
      
      body: SafeArea(
        child: Container(
          color: isDark ? const Color(0xFF14141C) : Colors.grey[200],
          child: MultiSplitViewTheme(
            data: MultiSplitViewThemeData(dividerThickness: 35),
            child: MultiSplitView(
              axis: Axis.vertical,
              controller: _splitController,
              dividerBuilder: (axis, index, resizable, dragging, highlighted, themeData) {
                return Container(
                  color: isDark ? const Color(0xFF1A1A24) : Colors.grey[100], 
                  alignment: Alignment.center,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6), 
                    decoration: BoxDecoration(
                      color: dragging ? (isDark ? Colors.green.withOpacity(0.3) : Colors.green[100]) : (isDark ? const Color(0xFF23232F) : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: dragging ? Colors.transparent : (isDark ? Colors.white10 : Colors.grey.shade300)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.drag_handle, size: 20, color: dragging ? Colors.green : (isDark ? Colors.grey[400] : Colors.grey[600])),
                        const SizedBox(width: 10),
                        Text("ARRASTRAR", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: dragging ? Colors.green : (isDark ? Colors.grey[400] : Colors.grey[600]))),
                      ],
                    ),
                  ),
                );
              },
              builder: (BuildContext context, Area area) {
                if (area.index == 0) {
                  return _buildImageViewer(imageFile);
                } else {
                  return _buildFormSection(isDark);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageViewer(dynamic imageFile) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          InteractiveViewer(
            minScale: 1.0, maxScale: 5.0,
            child: Center(child: UniversalImage(path: imageFile.path, fit: BoxFit.contain)),
          ),
          Positioned(
            bottom: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
              child: const Text("🔍 Pellizca para Zoom", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFormSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(color: isDark ? const Color(0xFF14141C) : Colors.grey[50]),
      child: Stack(
        children: [
          _localItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 50, color: isDark ? Colors.white24 : Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text("No hay ítems detectados.", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _addManualItem,
                        icon: const Icon(Icons.add, size: 20), 
                        label: const Text("Agregar Producto", style: TextStyle(fontSize: 13)),
                      )
                    ],
                  ),
                )
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 80, top: 16), 
                  itemCount: _localItems.length + 1, 
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    if (i == _localItems.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: OutlinedButton.icon(
                          onPressed: _addManualItem,
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          label: const Text("Añadir Fila Manualmente", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            foregroundColor: isDark ? Colors.blue[300] : Colors.blue[800],
                            side: BorderSide(color: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.withOpacity(0.5), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      );
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: ReviewItemCard(
                        key: ValueKey(_localItems[i].uuidTemporal), 
                        item: _localItems[i],
                        isDark: isDark,
                        onDelete: () => _confirmRemoveItem(_localItems[i].uuidTemporal), 
                        onChanged: (updatedItem) {
                          _localItems[i] = updatedItem;
                        },
                      ),
                    );
                  },
                ),

          if (_showScrollToTop)
            Positioned(
              bottom: 16, right: 16,
              child: FloatingActionButton(
                mini: true,
                onPressed: _scrollToTop,
                backgroundColor: isDark ? Colors.blueGrey[800] : Colors.white,
                foregroundColor: isDark ? Colors.white : Colors.black87,
                elevation: 4,
                child: const Icon(Icons.keyboard_arrow_up, size: 24),
              ),
            )
        ],
      ),
    );
  }
}