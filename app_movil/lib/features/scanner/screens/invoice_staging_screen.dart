import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';

// Módulos UI
import 'package:app_movil/features/scanner/widgets/staging/staging_vendor_card.dart';
import 'package:app_movil/features/scanner/widgets/staging/staging_product_group_card.dart';

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
      curve: Curves.easeInOutCubic,
    );
  }

  Future<bool> _onWillPop() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '¿Pausar Clasificación?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Tu progreso se guardará en memoria. Podrás retomarlo o descartarlo luego desde la pantalla principal.',
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quedarme', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Guardar y Salir',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldPop == true) {
      if (!mounted) return false;
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
            Icon(
              Icons.restore_page,
              color: isDark ? Colors.blue[300] : Colors.blue,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "¿Deshacer Cambios?",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          "Se borrarán todas las modificaciones y enlaces manuales que hayas hecho aquí. La lista volverá a como la Inteligencia Artificial la clasificó al entrar.",
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            fontSize: 15,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.blue[800] : Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _restoreInitialStaging();
            },
            child: const Text(
              "Sí, Restaurar",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _restoreInitialStaging() async {
    final provider = Provider.of<ScannerProvider>(context, listen: false);
    bool success = await provider.runMatchingProcess();

    if (success && mounted) {
      CustomSnackBar.show(
        context,
        message: "Lista restaurada a su estado inicial.",
        isError: false,
      );
    } else if (mounted) {
      CustomSnackBar.show(
        context,
        message: "Error al restaurar: ${provider.statusMessage}",
        isError: true,
      );
    }
  }

  void _showStockErrorModal(BuildContext context, ScannerProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Recolectar productos con error
    List<Map<String, dynamic>> errors = [];
    final staging = provider.stagingData;
    if (staging != null) {
      for (var group in staging.productosAgrupados) {
        for (var variant in group.variantes) {
          if (!variant.isConfirmed) continue;
          
          int totalUnidadesBase = variant.stockIngresanteOverride ?? (variant.cantidadUmpComprada * variant.unidadesPorLote).toInt();
          
          var validation = UnitCatalogService.validateStockForUnit(
            totalUnitsBase: totalUnidadesBase,
            presentationFactor: variant.unidadesPorVenta,
            baseUnitCost: 0.0,
            unitName: variant.unidadVenta,
          );
          
          if (validation.status == StockValidationStatus.deficit) {
            errors.add({
              'name': variant.nombreEspecifico.isEmpty ? 'Variante Principal' : variant.nombreEspecifico,
              'group': group.matchProducto.datos?.nombre ?? group.nombrePadre,
              'status': validation.status,
              'diff': validation.deficit,
              'unit': variant.unidadVenta,
            });
          } else if (validation.status == StockValidationStatus.hasLeftover) {
            int assignedLeftovers = 0;
            for (var other in group.variantes) {
              if (other != variant &&
                  other.cantidadUmpComprada == 0 &&
                  other.stockIngresanteOverride != null) {
                assignedLeftovers += other.stockIngresanteOverride!;
              }
            }
            if (assignedLeftovers < validation.leftover) {
              errors.add({
                'name': variant.nombreEspecifico.isEmpty ? 'Variante Principal' : variant.nombreEspecifico,
                'group': group.matchProducto.datos?.nombre ?? group.nombrePadre,
                'status': validation.status,
                'diff': validation.leftover - assignedLeftovers,
                'unit': 'Sueltas',
              });
            }
          }
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.6,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_rounded, color: Colors.orange, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Problemas de Stock", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                          const SizedBox(height: 4),
                          Text("Resuelve estas alertas antes de guardar.", style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              // List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: errors.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final err = errors[i];
                    final isDeficit = err['status'] == StockValidationStatus.deficit;
                    final color = isDeficit ? Colors.red : Colors.orange;
                    
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? color.withValues(alpha: 0.05) : color.withValues(alpha: 0.05),
                        border: Border.all(color: isDark ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(isDeficit ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(err['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                                const SizedBox(height: 4),
                                Text(err['group'], style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "${isDeficit ? 'Faltan' : 'Sobran'}\n${err['diff']} ${err['unit']}",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12),
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Button
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.blue[800] : Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Entendido, ir a corregir", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  void _confirmSave(BuildContext context, ScannerProvider provider) {
    if (provider.hasUnresolvedStock) {
      _showStockErrorModal(context, provider);
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.save_rounded, color: isDark ? Colors.blue[300] : Colors.blue[700]),
            const SizedBox(width: 10),
            Text(
              "¿Guardar Inventario?",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          "Se crearán los nuevos productos y se actualizarán los precios y stocks de los productos existentes de acuerdo a tu clasificación. Esta acción afectará tu base de datos.",
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[700],
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Revisar más", style: TextStyle(color: Colors.grey, fontSize: 14)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.blue[700] : Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _processSave(context, provider);
            },
            child: const Text("Sí, Guardar Todo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _processSave(BuildContext context, ScannerProvider provider) async {
    bool success = await provider.executeBatchSave();
    if (success && context.mounted) {
      CustomSnackBar.show(
        context,
        message: "¡Inventario actualizado con éxito!",
        isError: false,
      );
      provider.clearData();
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (context.mounted) {
      CustomSnackBar.show(
        context,
        message: provider.statusMessage,
        isError: true,
      );
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
              Text(
                "Restaurando datos...",
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "Clasificar y Confirmar",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          backgroundColor: isDark
              ? const Color(0xFF1A1A24)
              : const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.restore_page, size: 26),
              tooltip: "Deshacer cambios y restaurar",
              onPressed: provider.isLoading ? null : _confirmResetProcess,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              Column(
                children: [
                  // BARRA DE ESTADÍSTICAS Y PROGRESO
                  Container(
                    color: isDark ? const Color(0xFF23232F) : Colors.blue[900],
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatChip(
                              Icons.check_circle,
                              "Vinculados",
                              provider.countLinked,
                              isDark ? Colors.green[400]! : Colors.greenAccent,
                            ),
                            _buildStatChip(
                              Icons.add_circle,
                              "Nuevos",
                              provider.countNew,
                              isDark
                                  ? Colors.blue[400]!
                                  : Colors.lightBlueAccent,
                            ),
                            _buildStatChip(
                              Icons.inventory_2,
                              "Total",
                              provider.totalActiveVariants,
                              Colors.white,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Barra de progreso visual
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Row(
                            children: [
                              if (provider.totalActiveVariants > 0) ...[
                                Expanded(
                                  flex: provider.countLinked,
                                  child: Container(
                                    height: 6,
                                    color: isDark
                                        ? Colors.green[400]
                                        : Colors.greenAccent,
                                  ),
                                ),
                                Expanded(
                                  flex: provider.countNew,
                                  child: Container(
                                    height: 6,
                                    color: isDark
                                        ? Colors.blue[400]
                                        : Colors.lightBlueAccent,
                                  ),
                                ),
                                Expanded(
                                  flex:
                                      provider.totalActiveVariants -
                                      provider.countLinked -
                                      provider.countNew,
                                  child: Container(
                                    height: 6,
                                    color: Colors.white24,
                                  ),
                                ),
                              ] else ...[
                                Expanded(
                                  child: Container(
                                    height: 6,
                                    color: Colors.white24,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
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
                          return StagingVendorCard(
                            provider: provider,
                            staging: staging,
                            isDark: isDark,
                          );
                        }

                        if (i == staging.productosAgrupados.length + 1) {
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 20,
                            ),
                            width: double.infinity,
                            height: 60,
                            child: OutlinedButton.icon(
                              onPressed: () => provider.addNewProductGroup(),
                              icon: const Icon(Icons.add, size: 26),
                              label: const Text(
                                "AGREGAR PRODUCTO MANUALMENTE",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark
                                    ? Colors.blue[300]
                                    : Colors.blue[800],
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.blue.withValues(alpha: 0.5)
                                      : Colors.blue.shade800,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                backgroundColor: isDark
                                    ? Colors.blue.withValues(alpha: 0.05)
                                    : Colors.white,
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
                    backgroundColor: isDark
                        ? Colors.blueGrey[800]
                        : Colors.white,
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    elevation: 4,
                    child: const Icon(Icons.keyboard_arrow_up, size: 24),
                  ),
                ),
            ],
          ),
        ), // Cierre de GestureDetector
        // BOTÓN FINAL
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A24) : Colors.white,
            boxShadow: [
              if (!isDark)
                const BoxShadow(
                  color: Colors.black12,
                  blurRadius: 15,
                  offset: Offset(0, -5),
                ),
            ],
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white10 : Colors.transparent,
              ),
            ),
          ),
          child: SafeArea(
            child: SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: provider.isLoading
                    ? null
                    : () => _confirmSave(context, provider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? (provider.hasUnresolvedStock ? Colors.orange[800] : Colors.green[700])
                      : (provider.hasUnresolvedStock ? Colors.orange[700] : const Color(0xFF2E7D32)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: isDark ? 0 : 4,
                ),
                child: provider.isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            "GUARDANDO...",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        provider.hasUnresolvedStock ? "VER ERRORES DE STOCK" : "GUARDAR E INGRESAR STOCK",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, int count, Color color) {
    return Flexible(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                "$count",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
