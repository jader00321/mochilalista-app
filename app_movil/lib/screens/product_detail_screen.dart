import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/product_model.dart';
import '../../../providers/inventory_provider.dart';
import '../../../widgets/universal_image.dart'; 
import 'product_edit_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final int initialPresentationId;

  const ProductDetailScreen({
    super.key, 
    required this.product,
    required this.initialPresentationId
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late ProductPresentation _selectedPresentation;
  late Product _currentProduct;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
    _updateSelectedPresentation(widget.initialPresentationId);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).loadMasterData();
    });
  }

  void _updateSelectedPresentation(int id) {
    try {
      _selectedPresentation = _currentProduct.presentaciones.firstWhere((p) => p.id == id);
    } catch (e) {
      if (_currentProduct.presentaciones.isNotEmpty) {
        _selectedPresentation = _currentProduct.presentaciones.first;
      }
    }
  }

  Future<void> _refreshData() async {
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    await provider.loadInventory(reset: true); 
    try {
      final updatedProduct = provider.products.firstWhere((p) => p.id == _currentProduct.id);
      setState(() {
        _currentProduct = updatedProduct;
        if (updatedProduct.presentaciones.any((p) => p.id == _selectedPresentation.id)) {
          _selectedPresentation = updatedProduct.presentaciones.firstWhere((p) => p.id == _selectedPresentation.id);
        } else {
          _selectedPresentation = updatedProduct.presentaciones.first;
        }
      });
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _navigateToEdit() async {
    await Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => ProductEditScreen(
          productToEdit: _currentProduct, 
          initialPresentationId: _selectedPresentation.id
        )
      )
    );
    _refreshData();
  }

  void _showImageModal(String? imagePath, bool isDark) {
    if (imagePath == null || imagePath.isEmpty) return; 

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: isDark ? Colors.black : Colors.black87,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true, 
              minScale: 0.5,
              maxScale: 4.0,    
              child: Center(
                child: UniversalImage(
                  path: imagePath,
                  fit: BoxFit.contain, 
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                ),
              ),
            ),
            
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
                style: IconButton.styleFrom(backgroundColor: Colors.white24),
              ),
            ),

            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                    stops: [0.0, 1.0]
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (_selectedPresentation.unidadVenta ?? "Unidad").toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    if (_selectedPresentation.nombreEspecifico != null && _selectedPresentation.nombreEspecifico!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _selectedPresentation.nombreEspecifico!,
                          style: TextStyle(color: Colors.teal[300], fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = Provider.of<InventoryProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    String categoryName = inventoryProvider.getCategoryName(_currentProduct.categoriaId);
    if (categoryName.isEmpty) categoryName = "General";

    String brandName = inventoryProvider.getBrandName(_currentProduct.marcaId);
    if (brandName.isEmpty) brandName = "GENÉRICO";

    int? activeProviderId = _selectedPresentation.proveedorId;
    String providerName = "---";
    if (activeProviderId != null) {
      try {
        providerName = inventoryProvider.providers.firstWhere((p) => p.id == activeProviderId).nombreEmpresa;
      } catch (_) {}
    }

    final String? displayImage = (_selectedPresentation.imagenUrl != null && _selectedPresentation.imagenUrl!.isNotEmpty)
        ? _selectedPresentation.imagenUrl
        : _currentProduct.imagenUrl;

    final String displayDesc = (_selectedPresentation.descripcion != null && _selectedPresentation.descripcion!.isNotEmpty)
        ? _selectedPresentation.descripcion!
        : (_currentProduct.descripcion ?? "Sin descripción detallada.");

    final String displayBarcode = (_selectedPresentation.codigoBarras != null && _selectedPresentation.codigoBarras!.isNotEmpty)
        ? _selectedPresentation.codigoBarras!
        : (_currentProduct.codigoBarras ?? "---");

    final bool hasOffer = _selectedPresentation.precioOferta != null && _selectedPresentation.precioOferta! > 0;
    final double finalPrice = hasOffer ? _selectedPresentation.precioOferta! : _selectedPresentation.precioVentaFinal;
    final bool isPublic = _selectedPresentation.estado == 'publico';

    return Scaffold(
      backgroundColor: bgColor,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: Colors.blue[800],
        child: CustomScrollView(
          slivers: [
            // 1. APPBAR CON IMAGEN
            SliverAppBar(
              expandedHeight: 300.0,
              pinned: true,
              backgroundColor: isDark ? const Color(0xFF14141C) : Theme.of(context).primaryColor,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
                  child: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white, size: 24),
                    onPressed: _navigateToEdit,
                    tooltip: "Editar Producto",
                  ),
                )
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: GestureDetector(
                  onTap: () => _showImageModal(displayImage, isDark),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: isDark ? const Color(0xFF14141C) : Colors.white, child: UniversalImage(path: displayImage)),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black54, Colors.transparent, Colors.black45],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. CONTENIDO PRINCIPAL
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // NOMBRE Y ESTADO
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentProduct.nombre,
                                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.2, color: textColor),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  brandName.toUpperCase(),
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: isDark ? Colors.indigo[300] : Colors.grey[600], letterSpacing: 1.0),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isPublic ? (isDark ? Colors.green.withOpacity(0.15) : Colors.green.withOpacity(0.1)) : (isDark ? Colors.orange.withOpacity(0.15) : Colors.grey.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isPublic ? (isDark ? Colors.green.withOpacity(0.4) : Colors.green) : (isDark ? Colors.orange.withOpacity(0.4) : Colors.grey))
                          ),
                          child: Row(
                            children: [
                              Icon(isPublic ? Icons.public : Icons.lock_outline, size: 18, color: isPublic ? (isDark ? Colors.green[300] : Colors.green[700]) : (isDark ? Colors.orange[300] : Colors.grey[700])),
                              const SizedBox(width: 6),
                              Text(isPublic ? "Público" : "Privado", style: TextStyle(color: isPublic ? (isDark ? Colors.green[300] : Colors.green[800]) : (isDark ? Colors.orange[300] : Colors.grey[800]), fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      ],
                    ),
                    
                    const SizedBox(height: 24),

                    // 🔥 SELECTOR DE VARIANTES
                    Text("Seleccionar Variante:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 105, 
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _currentProduct.presentaciones.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final p = _currentProduct.presentaciones[index];
                          final bool isSelected = p.id == _selectedPresentation.id;
                          final bool isPrincipal = p.esDefault;

                          return GestureDetector(
                            onTap: () => setState(() => _selectedPresentation = p),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 155,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? (isDark ? Colors.teal.withOpacity(0.15) : Colors.teal.withOpacity(0.05)) : (isDark ? const Color(0xFF23232F) : Colors.white),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? (isDark ? Colors.teal[300]! : Colors.teal) : (isDark ? Colors.white10 : Colors.grey.shade300),
                                  width: isSelected ? 2 : 1
                                ),
                                boxShadow: isSelected ? [] : [if(!isDark) BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))]
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          (p.nombreEspecifico != null && p.nombreEspecifico!.isNotEmpty) 
                                              ? p.nombreEspecifico! 
                                              : (p.unidadVenta ?? 'Unidad').toUpperCase(),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontWeight: FontWeight.w900, color: isSelected ? (isDark ? Colors.teal[200] : Colors.teal[800]) : textColor, fontSize: 14),
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isPrincipal)
                                        Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.star, size: 16, color: isDark ? Colors.amber[300] : Colors.amber)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "${p.unidadVenta ?? 'Unidad'} (x${p.unidadesPorVenta})", 
                                    style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]), 
                                    maxLines: 1, overflow: TextOverflow.ellipsis
                                  ),
                                  const SizedBox(height: 6),
                                  Text("S/ ${p.precioVentaFinal.toStringAsFixed(2)}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24), 

                    // 🔥 DASHBOARD FINANCIERO INTEGRADO Y DETALLADO
                    _buildFinancialDashboard(isDark, hasOffer, finalPrice),

                    // 🔥 REDUCCIÓN DE ESPACIO DE 20 a 10px
                    const SizedBox(height: 10), 

                    // GRID DE DETALLES
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      // 🔥 MODIFICADO PARA DARLE MÁS ALTURA A LAS TARJETAS (Evitar cortes)
                      childAspectRatio: 1.9, 
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        _InfoCard(icon: Icons.qr_code, label: "Código de Barras", value: displayBarcode, isDark: isDark),
                        _InfoCard(
                          icon: Icons.inventory_2, 
                          label: "Empaque Compra", 
                          value: (_selectedPresentation.umpCompra != null && _selectedPresentation.umpCompra!.isNotEmpty) ? "${_selectedPresentation.unidadesPorLote} unid / ${_selectedPresentation.umpCompra}" : "No registrado", 
                          isDark: isDark
                        ),
                        _InfoCard(icon: Icons.category, label: "Categoría", value: categoryName, isDark: isDark), 
                        _InfoCard(icon: Icons.local_shipping, label: "Proveedor", value: providerName, isDark: isDark), 
                      ],
                    ),

                    const SizedBox(height: 24), 

                    // DESCRIPCIÓN
                    Text("Descripción Detallada", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF23232F) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200)
                      ),
                      child: Text(
                        displayDesc,
                        style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800], height: 1.6, fontSize: 15),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // 🔥 REDISEÑO DEL DASHBOARD FINANCIERO 🔥
  Widget _buildFinancialDashboard(bool isDark, bool hasOffer, double finalPrice) {
    double costoPresentacion = _selectedPresentation.costoUnitarioCalculado ?? 0.0;
    double factorVenta = _selectedPresentation.unidadesPorVenta.toDouble();
    double costoBase = factorVenta > 0 ? (costoPresentacion / factorVenta) : costoPresentacion;
    
    double margenDecimal = _selectedPresentation.factorGananciaVenta ?? 1.35;
    int margenPorcentaje = ((margenDecimal - 1.0) * 100).round();
    
    int stockVisual = factorVenta > 0 ? (_selectedPresentation.stockActual ~/ factorVenta) : _selectedPresentation.stockActual;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          // CABECERA: INTENCIÓN DE VENTA
          Container(
            width: double.infinity, 
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Row(
                  children: [
                    Icon(Icons.storefront, color: isDark ? Colors.blue[300] : Colors.blue[800], size: 20),
                    const SizedBox(width: 8),
                    Text("INFORMACIÓN FINANCIERA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.blue[300] : Colors.blue[900])),
                  ],
                ),
                const SizedBox(height: 10), 
                // 🔥 SOLUCIÓN AL DESBORDAMIENTO: ETIQUETA DIRECTA EN OTRA LÍNEA
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: isDark ? Colors.blue[800] : Colors.blue, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    "${(_selectedPresentation.unidadVenta ?? 'Unidad').toUpperCase()} (x${_selectedPresentation.unidadesPorVenta})", 
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)
                  ),
                )
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // FILA 1: COSTOS Y RENTABILIDAD
                Row(
                  children: [
                    // COSTO BASE (Gris)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Costo Base/U", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[500] : Colors.grey[600])),
                          const SizedBox(height: 4),
                          Text("S/ ${costoBase.toStringAsFixed(2)}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.grey[300] : Colors.black87)),
                        ],
                      ),
                    ),
                    
                    Container(height: 40, width: 1, color: isDark ? Colors.white10 : Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 12)),
                    
                    // COSTO DE LA VARIANTE (Naranja)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Costo Present.", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.orange[300] : Colors.orange[800])),
                          const SizedBox(height: 4),
                          Text("S/ ${costoPresentacion.toStringAsFixed(2)}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.orange[300] : Colors.orange[900])),
                        ],
                      ),
                    ),

                    Container(height: 40, width: 1, color: isDark ? Colors.white10 : Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 12)),
                    
                    // MARGEN (Azul)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text("Margen", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue[600])),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                            child: Text("+$margenPorcentaje%", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: isDark ? Colors.blue[300] : Colors.blue[700])),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
                const SizedBox(height: 20),

                // FILA 2: PRECIO Y STOCK
                Row(
                  children: [
                    // PRECIO FINAL
                    Expanded(
                      flex: 6,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: isDark ? Colors.green.withOpacity(0.15) : Colors.green.shade50, shape: BoxShape.circle),
                            child: Icon(Icons.attach_money, color: isDark ? Colors.green[400] : Colors.green[700], size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("PRECIO DE VENTA", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (hasOffer)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Text("S/${_selectedPresentation.precioVentaFinal.toStringAsFixed(2)}", style: TextStyle(decoration: TextDecoration.lineThrough, color: isDark ? Colors.red[300] : Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
                                      ),
                                    Text(
                                      "S/ ${finalPrice.toStringAsFixed(2)}",
                                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: hasOffer ? (isDark ? Colors.red[400] : Colors.red[800]) : (isDark ? Colors.green[400] : Colors.green[800])),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Container(height: 50, width: 1, color: isDark ? Colors.white10 : Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 16)),
                    
                    // STOCK
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text("STOCK DISPONIBLE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.purple[300] : Colors.purple[700])),
                          const SizedBox(height: 6),
                          Text(
                            "$stockVisual",
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: stockVisual > 0 ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.red[300] : Colors.red)),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _InfoCard({required this.icon, required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: isDark ? Colors.teal.withOpacity(0.15) : Colors.teal.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: isDark ? Colors.teal[300] : Colors.teal[700], size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[500], fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                // 🔥 SOLUCIÓN AL CORTE DE TEXTO (Permite 2 líneas)
                Text(
                  value, 
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, height: 1.2), 
                  maxLines: 2, 
                  overflow: TextOverflow.ellipsis
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}