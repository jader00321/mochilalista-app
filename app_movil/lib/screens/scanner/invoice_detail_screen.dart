import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'dart:convert';

import '../../providers/invoice_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../models/invoice_model.dart';
import '../../models/provider_model.dart';
import '../../widgets/universal_image.dart';
import '../../widgets/custom_snackbar.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final int invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  late MultiSplitViewController _splitController;
  InvoiceModel? _invoice;
  bool _isLoading = true;
  
  // 🔥 Control del Toggle del visor de Auditoría
  bool _showRawJson = false;

  @override
  void initState() {
    super.initState();
    _splitController = MultiSplitViewController(
      areas: [
        Area(size: 0.40, min: 0.20), // Imagen de la factura
        Area(size: 0.60, min: 0.30), // Datos de auditoría
      ],
    );
    _loadInvoiceDetails();
  }

  @override
  void dispose() {
    _splitController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoiceDetails() async {
    setState(() => _isLoading = true);
    final invcProv = Provider.of<InvoiceProvider>(context, listen: false);
    final invoice = await invcProv.getInvoiceDetail(widget.invoiceId);
    
    if (mounted) {
      setState(() {
        _invoice = invoice;
        _isLoading = false;
      });
    }
  }

  void _showStatusDialog(bool isDark) {
    if (_invoice == null) return;
    
    String tempStatus = _invoice!.estado;
    final List<String> opciones = ['procesando', 'revision', 'completado'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Cambiar Estado", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: opciones.map((opcion) {
                return RadioListTile<String>(
                  title: Text(opcion.toUpperCase(), style: TextStyle(color: _getStatusColor(opcion, isDark), fontWeight: FontWeight.bold)),
                  value: opcion,
                  groupValue: tempStatus,
                  activeColor: isDark ? Colors.blue[300] : Colors.blue,
                  onChanged: (val) {
                    setStateDialog(() => tempStatus = val!);
                  },
                );
              }).toList(),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.blue[700] : Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(ctx);
              if (tempStatus != _invoice!.estado) {
                _updateInvoice(estado: tempStatus);
              }
            },
            child: const Text("Guardar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _showProviderSearchModal(BuildContext context, bool isDark) {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    String query = "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          final filtered = invProv.providers.where((p) => 
            p.nombreEmpresa.toLowerCase().contains(query.toLowerCase())
          ).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF23232F) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                children: [
                  Container(width: 50, height: 5, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  Text("Vincular Proveedor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 16),
                  TextField(
                    autofocus: true,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: "Buscar proveedor registrado...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true, fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100]
                    ),
                    onChanged: (val) => setModalState(() => query = val),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                      itemBuilder: (ctx, i) {
                        final ProviderModel prov = filtered[i];
                        return ListTile(
                          title: Text(prov.nombreEmpresa, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                          subtitle: prov.ruc != null ? Text("RUC: ${prov.ruc}") : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            _updateInvoice(proveedorId: prov.id);
                          },
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          );
        }
      )
    );
  }

  Future<void> _updateInvoice({String? estado, int? proveedorId}) async {
    final invcProv = Provider.of<InvoiceProvider>(context, listen: false);
    CustomSnackBar.show(context, message: "Actualizando...", isError: false); 
    
    bool success = await invcProv.updateInvoice(widget.invoiceId, estado: estado, proveedorId: proveedorId);
    if (success && mounted) {
      await _loadInvoiceDetails(); 
      CustomSnackBar.show(context, message: "Factura actualizada con éxito", isError: false);
    } else if (mounted) {
      CustomSnackBar.show(context, message: "Error al actualizar factura", isError: true);
    }
  }

  Color _getStatusColor(String status, bool isDark) {
    switch (status.toLowerCase()) {
      case 'completado': return isDark ? Colors.green[400]! : Colors.green[700]!;
      case 'revision': return isDark ? Colors.orange[400]! : Colors.orange[700]!;
      case 'procesando': return isDark ? Colors.blue[400]! : Colors.blue[700]!;
      default: return isDark ? Colors.grey[400]! : Colors.grey[700]!;
    }
  }

  String _formatJson(Map<String, dynamic>? jsonInput) {
    if (jsonInput == null) return "No hay datos crudos disponibles.";
    final encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(jsonInput);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final invProv = Provider.of<InventoryProvider>(context);

    if (_isLoading) {
      return Scaffold(backgroundColor: bgColor, appBar: AppBar(title: const Text("Cargando Factura...")), body: const Center(child: CircularProgressIndicator()));
    }

    if (_invoice == null) {
      return Scaffold(backgroundColor: bgColor, appBar: AppBar(title: const Text("Error")), body: const Center(child: Text("Factura no encontrada.")));
    }

    final statusColor = _getStatusColor(_invoice!.estado, isDark);
    final providerName = invProv.getProviderName(_invoice!.proveedorId);
    
    // Obtener los ítems extraídos del JSON
    List<dynamic> extractedItems = [];
    if (_invoice!.datosCrudosIaJson != null && _invoice!.datosCrudosIaJson!['items'] != null) {
      extractedItems = _invoice!.datosCrudosIaJson!['items'];
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Factura #${_invoice!.id}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.teal[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: MultiSplitViewTheme(
          data: MultiSplitViewThemeData(dividerThickness: 24),
          child: MultiSplitView(
            axis: Axis.vertical,
            controller: _splitController,
            dividerBuilder: (axis, index, resizable, dragging, highlighted, themeData) {
              return Container(
                color: isDark ? const Color(0xFF1A1A24) : Colors.grey[200], 
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4), 
                  decoration: BoxDecoration(
                    color: dragging ? (isDark ? Colors.blue.withOpacity(0.3) : Colors.blue[100]) : (isDark ? const Color(0xFF23232F) : Colors.white),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: dragging ? Colors.transparent : (isDark ? Colors.white10 : Colors.grey.shade300)),
                  ),
                  child: Icon(Icons.drag_handle, size: 16, color: dragging ? Colors.blue : (isDark ? Colors.grey[400] : Colors.grey[600])),
                ),
              );
            },
            builder: (BuildContext context, Area area) {
              if (area.index == 0) {
                // ZONA 1: VISOR DE IMAGEN
                return Container(
                  color: Colors.black,
                  child: Stack(
                    children: [
                      InteractiveViewer(
                        minScale: 1.0, maxScale: 5.0,
                        child: Center(child: UniversalImage(path: _invoice!.imagenUrl, fit: BoxFit.contain)),
                      ),
                      Positioned(
                        bottom: 12, right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                          child: const Text("🔍 Zoom interactivo", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                );
              } else {
                // ZONA 2: AUDITORÍA Y METADATOS
                return Container(
                  color: isDark ? const Color(0xFF14141C) : Colors.grey[50],
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 1. ESTADO Y FECHA
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Fecha Escaneo:", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[600])),
                              Text(DateFormat("dd MMM yyyy, hh:mm a").format(_invoice!.fechaCarga.toLocal()), style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          InkWell(
                            onTap: () => _showStatusDialog(isDark),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: statusColor.withOpacity(0.5))),
                              child: Row(
                                children: [
                                  Text(_invoice!.estado.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                  const SizedBox(width: 4),
                                  Icon(Icons.edit, size: 14, color: statusColor)
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 2. MONTO TOTAL Y FECHA EMISIÓN (Visual Impactante)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: isDark ? [Colors.teal.shade900, Colors.teal.shade800] : [Colors.teal.shade50, Colors.white]),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.teal.shade700 : Colors.teal.shade100)
                        ),
                        child: Column(
                          children: [
                            Text("MONTO TOTAL FACTURADO", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.teal[200] : Colors.teal[800], letterSpacing: 1.5)),
                            const SizedBox(height: 8),
                            Text(
                              _invoice!.montoTotalFactura != null ? "S/ ${_invoice!.montoTotalFactura!.toStringAsFixed(2)}" : "S/ 0.00",
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.teal[900]),
                            ),
                            if (_invoice!.fechaEmision != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.white54, borderRadius: BorderRadius.circular(8)),
                                child: Text("F. Emisión: ${DateFormat("dd/MM/yyyy").format(_invoice!.fechaEmision!)}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.teal[100] : Colors.teal[900])),
                              )
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 3. TARJETA DE PROVEEDOR
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF23232F) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("PROVEEDOR VINCULADO", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[500] : Colors.grey[600])),
                                InkWell(
                                  onTap: () => _showProviderSearchModal(context, isDark),
                                  child: Text("Cambiar", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue[700])),
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                CircleAvatar(backgroundColor: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue[50], child: Icon(Icons.store, color: isDark ? Colors.blue[300] : Colors.blue)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    providerName.isNotEmpty ? providerName : "Sin proveedor asignado",
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                                  ),
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4. 🔥 AUDITORÍA DE IA (Toggle Interactivo)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF23232F) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.memory, size: 20, color: isDark ? Colors.purple[300] : Colors.purple),
                                    const SizedBox(width: 8),
                                    Text("Auditoría de Extracción", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: isDark ? Colors.purple.withOpacity(0.1) : Colors.purple[50], borderRadius: BorderRadius.circular(6)),
                                  child: Text("${_invoice!.cantidadItemsExtraidos ?? 0} ítems", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.purple[200] : Colors.purple[800])),
                                )
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Toggle
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _showRawJson = false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(color: !_showRawJson ? (isDark ? Colors.blue[800] : Colors.white) : Colors.transparent, borderRadius: BorderRadius.circular(10), boxShadow: !_showRawJson && !isDark ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : []),
                                        child: Center(child: Text("Vista Detallada", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: !_showRawJson ? (isDark ? Colors.white : Colors.blue[800]) : Colors.grey))),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _showRawJson = true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(color: _showRawJson ? (isDark ? Colors.blue[800] : Colors.white) : Colors.transparent, borderRadius: BorderRadius.circular(10), boxShadow: _showRawJson && !isDark ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : []),
                                        child: Center(child: Text("Código JSON", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _showRawJson ? (isDark ? Colors.white : Colors.blue[800]) : Colors.grey))),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Contenido del Toggle
                            if (_showRawJson)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: isDark ? const Color(0xFF0D0D14) : Colors.grey[900], borderRadius: BorderRadius.circular(10)),
                                child: Text(_formatJson(_invoice!.datosCrudosIaJson), style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 11, height: 1.5)),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                                itemCount: extractedItems.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (ctx, i) {
                                  final item = extractedItems[i];
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade300)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['descripcion_detectada'] ?? "Sin descripción", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 12, runSpacing: 8,
                                          children: [
                                            _auditTag("Padre", item['producto_padre_estimado'] ?? "N/A", isDark),
                                            _auditTag("Variante", item['variante_detectada'] ?? "N/A", isDark),
                                            _auditTag("Marca", item['marca_detectada'] ?? "N/A", isDark),
                                          ],
                                        ),
                                        Divider(height: 16, color: isDark ? Colors.white10 : Colors.grey.shade300),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text("Compra: ${item['cantidad_ump_comprada']} ${item['ump_compra'] ?? 'UND'}", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                                                Text("Costo Unit: S/ ${(item['precio_ump_proveedor'] ?? 0).toStringAsFixed(2)}", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                                              ],
                                            ),
                                            Text("S/ ${(item['total_pago_lote'] ?? 0).toStringAsFixed(2)}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.green[400] : Colors.green[700])),
                                          ],
                                        )
                                      ],
                                    ),
                                  );
                                },
                              )
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _auditTag(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: isDark ? Colors.grey[500] : Colors.grey)),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[200] : Colors.blue[800])),
      ],
    );
  }
}