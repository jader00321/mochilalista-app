import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/models/notification_model.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/notification_toast_feedback.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/screens/product_edit_screen.dart';

class StockAnalysisModal extends StatefulWidget {
  final NotificationModel notif;
  final Product product;
  final bool isDark;
  final List<Map<String, dynamic>>? initialLedger;

  const StockAnalysisModal({
    super.key,
    required this.notif,
    required this.product,
    required this.isDark,
    this.initialLedger,
  });

  static Future<void> show(
    BuildContext context, {
    required NotificationModel notif,
    Product? product,
    required bool isDark,
  }) async {
    Product? targetProduct = product;
    if (targetProduct == null) {
      final pId = notif.objetoRelacionadoId;
      if (pId == null) {
        NotificationToastFeedback.showError(context, "No se encontró el ID del producto asociado");
        return;
      }
      final invProv = Provider.of<InventoryProvider>(context, listen: false);
      targetProduct = await invProv.getFullProductWithFallback(pId);
      if (targetProduct == null) {
        if (context.mounted) {
          NotificationToastFeedback.showError(context, "Producto no encontrado en inventario");
        }
        return;
      }
    }

    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => StockAnalysisModal(
        notif: notif,
        product: targetProduct!,
        isDark: isDark,
      ),
    );
  }

  @override
  State<StockAnalysisModal> createState() => _StockAnalysisModalState();
}

class _StockAnalysisModalState extends State<StockAnalysisModal> {
  late Product _product;
  int _selectedPresIndex = 0;
  List<Map<String, dynamic>> _ledgerMovements = [];
  bool _isLoadingLedger = true;
  bool _isSavingStock = false;

  final TextEditingController _quickQtyCtrl = TextEditingController(text: "5");
  late int _currentThreshold;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _initThreshold();
    if (widget.initialLedger != null) {
      _ledgerMovements = List<Map<String, dynamic>>.from(widget.initialLedger!);
      _isLoadingLedger = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadLedger();
      });
    }
  }

  void _initThreshold() {
    if (_product.presentaciones.isNotEmpty) {
      final pres = _product.presentaciones[_selectedPresIndex];
      final alert = pres.stockAlerta;
      _currentThreshold = (alert != null && alert > 0) ? alert : 5;
    } else {
      _currentThreshold = 5;
    }
  }

  @override
  void dispose() {
    _quickQtyCtrl.dispose();
    super.dispose();
  }

  ProductPresentation? get _selectedPres {
    if (_product.presentaciones.isEmpty) return null;
    if (_selectedPresIndex >= _product.presentaciones.length) {
      _selectedPresIndex = 0;
    }
    return _product.presentaciones[_selectedPresIndex];
  }

  bool get _isShared {
    final pres = _selectedPres;
    return (pres?.usaStockCompartido == true || _product.modoStock == 'COMPARTIDO');
  }

  int get _currentStock {
    if (_isShared) {
      return _product.stockCompartido;
    }
    return _selectedPres?.stockActual ?? 0;
  }

  Future<void> _loadLedger() async {
    if (mounted && !_isLoadingLedger) {
      setState(() => _isLoadingLedger = true);
    }
    try {
      final db = await LocalDatabase.instance.database;
      final presId = _selectedPres?.id;

      final List<Map<String, dynamic>> rows;
      if (presId != null) {
        rows = await db.rawQuery('''
          SELECT sl.*, pp.nombre_especifico as pres_nombre
          FROM stock_ledger sl
          LEFT JOIN presentaciones_producto pp ON sl.presentation_id = pp.id
          WHERE pp.producto_id = ?
          ORDER BY sl.id DESC LIMIT 30
        ''', [_product.id]);
      } else {
        rows = [];
      }

      if (mounted) {
        setState(() {
          _ledgerMovements = rows;
          _isLoadingLedger = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading ledger in StockAnalysisModal: $e");
      if (mounted) setState(() => _isLoadingLedger = false);
    }
  }

  Future<void> _applyQuickRestock(int qtyToAdd) async {
    if (qtyToAdd <= 0 || _isSavingStock) return;
    setState(() => _isSavingStock = true);
    HapticFeedback.mediumImpact();

    try {
      final db = await LocalDatabase.instance.database;
      final pres = _selectedPres;
      if (pres == null) return;

      final nowIso = DateTime.now().toUtc().toIso8601String();
      final bool isShared = _isShared;
      final int oldStock = _currentStock;
      final int newStock = oldStock + qtyToAdd;

      await db.transaction((txn) async {
        if (isShared) {
          await txn.rawUpdate('''
            UPDATE productos 
            SET stock_compartido = ?, fecha_actualizacion = ?
            WHERE id = ?
          ''', [newStock, nowIso, _product.id]);
        } else {
          await txn.rawUpdate('''
            UPDATE presentaciones_producto
            SET stock_actual = ?
            WHERE id = ?
          ''', [newStock, pres.id]);
        }

        final prodRows = await txn.rawQuery('SELECT negocio_id FROM productos WHERE id = ?', [_product.id]);
        final int negocioId = prodRows.isNotEmpty ? (prodRows.first['negocio_id'] as int? ?? 1) : 1;

        await txn.insert('stock_ledger', {
          'presentation_id': pres.id,
          'negocio_id': negocioId,
          'tipo_transaccion': 'INGRESO',
          'cantidad': qtyToAdd,
          'costo_unitario': pres.costoUnitarioCalculado,
          'precio_venta': pres.precioVentaFinal,
          'origen_id': null,
          'fecha_registro': nowIso,
        });
      });

      // Refrescar en memoria del InventoryProvider
      if (!mounted) return;
      final invProv = Provider.of<InventoryProvider>(context, listen: false);
      try {
        await invProv.loadInventory(reset: true);
      } catch (_) {}
      final updatedProd = await invProv.getFullProductWithFallback(_product.id);
      if (updatedProd != null) {
        _product = updatedProd;
      }

      if (!mounted) return;
      // Si el nuevo stock supera el umbral, auto-resolver la alerta
      final notifProv = Provider.of<NotificationProvider>(context, listen: false);
      if (newStock > _currentThreshold) {
        await notifProv.resolveProductStockNotification(_product.id);
      }
      await notifProv.fetchNotifications();

      if (!mounted) return;
      NotificationToastFeedback.show(
        context: context,
        message: "Se sumaron +$qtyToAdd und. al inventario correctamente",
        icon: Icons.check_circle_rounded,
        accentColor: Colors.green,
      );

      await _loadLedger();
    } catch (e) {
      debugPrint("Error in quick restock: $e");
      if (mounted) {
        NotificationToastFeedback.show(
          context: context,
          message: "No se pudo actualizar el stock: $e",
          icon: Icons.error_outline_rounded,
          accentColor: Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingStock = false);
    }
  }

  Future<void> _updateThreshold(int newThreshold) async {
    if (newThreshold < 1 || newThreshold == _currentThreshold) return;
    HapticFeedback.lightImpact();

    try {
      final db = await LocalDatabase.instance.database;
      final pres = _selectedPres;
      if (pres == null) return;

      await db.update(
        'presentaciones_producto',
        {'stock_alerta': newThreshold},
        where: 'id = ?',
        whereArgs: [pres.id],
      );

      if (mounted) setState(() => _currentThreshold = newThreshold);

      if (!mounted) return;
      try {
        final invProv = Provider.of<InventoryProvider>(context, listen: false);
        await invProv.loadInventory(reset: true);
      } catch (_) {}

      if (!mounted) return;
      // Si el stock actual ahora supera el nuevo umbral, auto-resolver
      final notifProv = Provider.of<NotificationProvider>(context, listen: false);
      if (_currentStock > newThreshold) {
        await notifProv.resolveProductStockNotification(_product.id);
      }
      await notifProv.fetchNotifications();

      if (!mounted) return;
      NotificationToastFeedback.show(
        context: context,
        message: "Umbral mínimo actualizado a $newThreshold und.",
        icon: Icons.tune_rounded,
        accentColor: Colors.blue,
      );
    } catch (e) {
      debugPrint("Error updating threshold: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final pres = _selectedPres;
    final int stock = _currentStock;
    final int umbral = _currentThreshold;
    final bool isSafe = stock > umbral;
    final bool isAgotado = stock <= 0;

    final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(
      context,
      minPadding: kMinDefensiveBottomClearance,
    );

    final bgCardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final sectionBg = isDark ? const Color(0xFF1E1E28) : Colors.grey[50];
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    // Color semántico de salud
    final Color healthColor = isAgotado
        ? Colors.red
        : (stock <= umbral ? Colors.amber[700]! : Colors.green[600]!);

    final double healthPercent = umbral > 0 ? (stock / (umbral * 2)).clamp(0.0, 1.0) : 0.0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: sectionBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle & Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.insights_rounded, color: isDark ? Colors.blue[300] : Colors.blue[700], size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Análisis de Stock",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            _product.nombre,
                            style: TextStyle(fontSize: 12.5, color: subtitleColor, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      tooltip: "Cerrar",
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, effectiveBottom + 20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                // Selector de variantes si tiene más de 1 presentación
                if (_product.presentaciones.length > 1) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: List.generate(_product.presentaciones.length, (idx) {
                          final p = _product.presentaciones[idx];
                          final isSel = idx == _selectedPresIndex;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text((p.nombreEspecifico != null && p.nombreEspecifico!.isNotEmpty) ? p.nombreEspecifico! : "Variante #${idx + 1}"),
                              selected: isSel,
                              onSelected: (v) {
                                if (v) {
                                  setState(() {
                                    _selectedPresIndex = idx;
                                    _initThreshold();
                                  });
                                  _loadLedger();
                                }
                              },
                              selectedColor: Colors.blue.withValues(alpha: isDark ? 0.3 : 0.15),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                color: isSel ? (isDark ? Colors.blue[200] : Colors.blue[900]) : subtitleColor,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],

                // 1. PANEL DIAGNÓSTICO VISUAL
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: bgCardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Diagnóstico de Inventario", style: TextStyle(fontSize: 11.5, color: subtitleColor, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                const SizedBox(height: 2),
                                Text(
                                  isAgotado ? "¡Producto Agotado!" : (isSafe ? "Stock Saludable" : "Stock Bajo Preventivo"),
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: healthColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: healthColor.withValues(alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(isSafe ? Icons.check_circle_rounded : Icons.warning_rounded, size: 13, color: healthColor),
                                const SizedBox(width: 4),
                                Text(
                                  _isShared ? "Stock Compartido" : "Stock Propio",
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: healthColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Barra de salud animada
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: healthPercent,
                          minHeight: 8,
                          backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Métricas comparativas
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[100],
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Stock Actual", style: TextStyle(fontSize: 11, color: subtitleColor)),
                                  const SizedBox(height: 2),
                                  Text("$stock und.", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: healthColor)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[100],
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Umbral Mínimo", style: TextStyle(fontSize: 11, color: subtitleColor)),
                                  const SizedBox(height: 2),
                                  Text("$umbral und.", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textColor)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Sugerido", style: TextStyle(fontSize: 11, color: isDark ? Colors.blue[300] : Colors.blue[800])),
                                  const SizedBox(height: 2),
                                  Text(
                                    "${(umbral * 2 - stock).clamp(0, 999)} und.",
                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: isDark ? Colors.blue[200] : Colors.blue[900]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Datos comerciales
                      if (pres != null) ...[
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            Text(
                              "Costo: S/ ${(pres.costoUnitarioCalculado ?? 0.0).toStringAsFixed(2)}",
                              style: TextStyle(fontSize: 12, color: subtitleColor, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              "Venta: S/ ${pres.precioVentaFinal.toStringAsFixed(2)}",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            Builder(builder: (_) {
                              final factor = pres.factorGananciaVenta;
                              final margenStr = (factor != null && factor > 0)
                                  ? '+${(factor * 100).toStringAsFixed(0)}%'
                                  : 'N/A';
                              return Text(
                                "Margen: $margenStr",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green[600]),
                              );
                            }),
                          ],
                        ),
                        if ((pres.unidadesPorVenta > 1) || _isShared) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: isDark ? 0.15 : 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.withValues(alpha: isDark ? 0.3 : 0.2)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.layers_outlined, size: 16, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    (pres.unidadesPorVenta > 1)
                                        ? "Empaque: 1 presentación = ${pres.unidadesPorVenta} unidades base."
                                        : "Modo: Stock Compartido (afecta todas las presentaciones vinculadas).",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.blue[200] : Colors.blue[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. MÓDULO DE ABASTECIMIENTO RÁPIDO IN-MODAL
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: bgCardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "Abastecimiento Rápido",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_isSavingStock)
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text("Suma existencias directamente sin abrir la edición completa", style: TextStyle(fontSize: 12, color: subtitleColor)),
                      const SizedBox(height: 14),

                      // Chips de suma rápida
                      Row(
                        children: [5, 10, 12, 24].map((n) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: OutlinedButton(
                                onPressed: _isSavingStock ? null : () => _applyQuickRestock(n),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                                  side: BorderSide(color: Colors.blue.withValues(alpha: 0.4)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  backgroundColor: Colors.blue.withValues(alpha: isDark ? 0.15 : 0.05),
                                ),
                                child: Text("+$n", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: isDark ? Colors.blue[300] : Colors.blue[800])),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      // Input táctil para cantidad libre
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                              ),
                              child: TextField(
                                controller: _quickQtyCtrl,
                                keyboardType: TextInputType.number,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                                decoration: InputDecoration(
                                  hintText: "Otra cantidad...",
                                  hintStyle: TextStyle(fontSize: 12, color: subtitleColor),
                                  prefixIcon: Icon(Icons.add_shopping_cart_rounded, size: 16, color: subtitleColor),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _isSavingStock
                                ? null
                                : () {
                                    final val = int.tryParse(_quickQtyCtrl.text.trim()) ?? 0;
                                    if (val > 0) _applyQuickRestock(val);
                                  },
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text("Sumar", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. AJUSTE RÁPIDO DE UMBRAL MÍNIMO
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: bgCardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Ajustar Umbral de Alerta", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                            const SizedBox(height: 2),
                            Text("Alertar cuando el stock sea menor o igual a:", style: TextStyle(fontSize: 11.5, color: subtitleColor)),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: _currentThreshold > 1 ? () => _updateThreshold(_currentThreshold - 1) : null,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "$_currentThreshold und.",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: textColor),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                            color: Colors.blue,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () => _updateThreshold(_currentThreshold + 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. LÍNEA DE TIEMPO (KARDEX REAL DESDE STOCK_LEDGER)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: bgCardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Historial de Movimientos (Kardex)", style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 10),
                      if (_isLoadingLedger)
                        const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                      else if (_ledgerMovements.isEmpty)
                        // Estado limpio explicativo cuando no hay ventas
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.inventory_2_outlined, color: Colors.blue[400], size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Producto registrado con un inventario inicial de $stock und. Aún no registra salidas ni ventas.",
                                  style: TextStyle(fontSize: 12.5, color: subtitleColor, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _ledgerMovements.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                          itemBuilder: (context, i) {
                            final m = _ledgerMovements[i];
                            final tipo = m['tipo_transaccion']?.toString() ?? 'MOVIMIENTO';
                            final int qty = (m['cantidad'] as num?)?.toInt() ?? 0;
                            final dateStr = m['fecha_registro']?.toString() ?? '';
                            final dt = DateTime.tryParse(dateStr)?.toLocal() ?? DateTime.now();

                            final bool isSale = tipo == 'VENTA' || tipo == 'SALIDA_MANUAL';
                            final bool isInitial = tipo == 'INVENTARIO_INICIAL';
                            final Color rowColor = isSale
                                ? Colors.red
                                : (isInitial ? Colors.blue : Colors.green);

                            final IconData rowIcon = isSale
                                ? Icons.arrow_downward_rounded
                                : (isInitial ? Icons.fiber_new_rounded : Icons.arrow_upward_rounded);

                            final String rowTitle = isSale
                                ? "Venta (Salida)"
                                : (isInitial ? "Inventario Inicial" : "Abastecimiento (Entrada)");

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: rowColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(rowIcon, color: rowColor, size: 16),
                              ),
                              title: Text(rowTitle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                              subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(dt), style: TextStyle(fontSize: 11, color: subtitleColor)),
                              trailing: Text(
                                "${isSale ? '-' : '+'}$qty",
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: rowColor),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

          // PIE FIJO ACOPLADO (Docked Footer) CON RESPETO ESTRICTO A SAFEAREA
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, effectiveBottom + 8),
            decoration: BoxDecoration(
              color: bgCardColor,
              border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProductEditScreen(productToEdit: _product)),
                  );
                  if (context.mounted) {
                    final notifProv = Provider.of<NotificationProvider>(context, listen: false);
                    await notifProv.resolveProductStockNotification(_product.id);
                    await notifProv.fetchNotifications();
                  }
                },
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text("Ir a Editar Producto", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
