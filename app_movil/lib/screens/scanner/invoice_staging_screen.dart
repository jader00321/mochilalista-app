import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/scanner_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/custom_snackbar.dart';

// Módulos UI
import '../../widgets/staging/staging_vendor_card.dart';
import '../../widgets/staging/staging_product_group_card.dart';

class InvoiceStagingScreen extends StatefulWidget {
  const InvoiceStagingScreen({super.key});

  @override
  State<InvoiceStagingScreen> createState() => _InvoiceStagingScreenState();
}

class _InvoiceStagingScreenState extends State<InvoiceStagingScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final invProv = Provider.of<InventoryProvider>(context, listen: false);
      invProv.loadCategories();
      invProv.loadBrands();
      invProv.loadMasterData(); 
      invProv.loadInventory(reset: true);
    });

    _scrollController.addListener(() {
      if (_scrollController.offset > 200 && !_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      } else if (_scrollController.offset <= 200 && _showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0, 
      duration: const Duration(milliseconds: 500), 
      curve: Curves.easeInOutCubic
    );
  }

  Future<bool> _onWillPop() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('¿Pausar Clasificación?', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        content: Text('Tu progreso se guardará en memoria. Podrás retomarlo o descartarlo luego desde la pantalla principal.', style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Quedarme', style: TextStyle(fontSize: 16))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Guardar y Salir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );

    if (shouldPop == true) {
      Provider.of<ScannerProvider>(context, listen: false).saveProgress();
      return true;
    }
    return false;
  }

  void _confirmResetProcess() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.restore_page, color: isDark ? Colors.blue[300] : Colors.blue, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text("¿Deshacer Cambios?", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text("Se borrarán todas las modificaciones y enlaces manuales que hayas hecho aquí. La lista volverá a como la Inteligencia Artificial la clasificó al entrar.", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 15, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontSize: 16))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.blue[800] : Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(ctx);
              _restoreInitialStaging();
            },
            child: const Text("Sí, Restaurar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          )
        ],
      )
    );
  }

  void _restoreInitialStaging() async {
    final provider = Provider.of<ScannerProvider>(context, listen: false);
    bool success = await provider.runMatchingProcess();
    
    if (success && mounted) {
      CustomSnackBar.show(context, message: "Lista restaurada a su estado inicial.", isError: false);
    } else if (mounted) {
      CustomSnackBar.show(context, message: "Error al restaurar: ${provider.statusMessage}", isError: true);
    }
  }

  void _confirmSave(BuildContext context, ScannerProvider provider) async {
    bool success = await provider.executeBatchSave();
    if (success && mounted) {
      CustomSnackBar.show(context, message: "¡Inventario actualizado con éxito!", isError: false);
      provider.clearData(); 
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (mounted) {
      CustomSnackBar.show(context, message: provider.statusMessage, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ScannerProvider>(context);
    final staging = provider.stagingData;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    if (staging == null) {
      return Scaffold(
        backgroundColor: bgColor, 
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text("Restaurando datos...", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 16, fontWeight: FontWeight.bold))
            ],
          )
        )
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const Text("Clasificar y Confirmar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          backgroundColor: isDark ? const Color(0xFF1A1A24) : const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.restore_page, size: 26),
              tooltip: "Deshacer cambios y restaurar",
              onPressed: provider.isLoading ? null : _confirmResetProcess,
            ),
            const SizedBox(width: 8)
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // BARRA DE ESTADÍSTICAS
                Container(
                  color: isDark ? const Color(0xFF23232F) : Colors.blue[900],
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem(Icons.update, "Actualizar: ${provider.countLinked}", isDark ? Colors.green[300]! : Colors.greenAccent),
                      _statItem(Icons.add_circle_outline, "Crear: ${provider.countNew}", isDark ? Colors.blue[300]! : Colors.lightBlueAccent),
                      _statItem(Icons.list, "Total: ${provider.totalActiveVariants}", Colors.white),
                    ],
                  ),
                ),

                // LISTA PRINCIPAL
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: staging.productosAgrupados.length + 2, 
                    itemBuilder: (ctx, i) {
                      if (i == 0) {
                         return StagingVendorCard(provider: provider, staging: staging, isDark: isDark);
                      }
                      
                      if (i == staging.productosAgrupados.length + 1) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          width: double.infinity, height: 60,
                          child: OutlinedButton.icon(
                            onPressed: () => provider.addNewProductGroup(),
                            icon: const Icon(Icons.add, size: 26),
                            label: const Text("AGREGAR PRODUCTO MANUALMENTE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.blue[300] : Colors.blue[800],
                              side: BorderSide(color: isDark ? Colors.blue.withOpacity(0.5) : Colors.blue.shade800, width: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              backgroundColor: isDark ? Colors.blue.withOpacity(0.05) : Colors.white
                            ),
                          ),
                        );
                      }

                      final groupIndex = i - 1;
                      final group = staging.productosAgrupados[groupIndex];
                      
                      return StagingProductGroupCard(
                        key: ValueKey(group.uuidTemporal),
                        groupIndex: groupIndex,
                        provider: provider,
                        isDark: isDark,
                      );
                    },
                  ),
                ),
              ],
            ),
            
            // 🔥 BOTÓN IR ARRIBA
            if (_showScrollToTop)
              Positioned(
                bottom: 16,
                right: 16,
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
        
        // BOTÓN FINAL
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A24) : Colors.white,
            boxShadow: [if (!isDark) const BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -5))],
            border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.transparent))
          ),
          child: SafeArea(
            child: SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: provider.isLoading ? null : () => _confirmSave(context, provider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.green[700] : const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: isDark ? 0 : 4,
                ),
                child: provider.isLoading 
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
                        SizedBox(width: 12),
                        Text("GUARDANDO...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
                      ],
                    )
                  : const Text("GUARDAR E INGRESAR STOCK", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }
}