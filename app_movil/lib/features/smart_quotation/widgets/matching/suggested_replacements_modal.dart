import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';

class SuggestedReplacementsModal extends StatefulWidget {
  final MatchPair pair;
  final bool isDark;
  final Function(MatchedProduct product) onSelectReplacement;

  const SuggestedReplacementsModal({
    super.key,
    required this.pair,
    required this.isDark,
    required this.onSelectReplacement,
  });

  static Future<void> show({
    required BuildContext context,
    required MatchPair pair,
    required bool isDark,
    required Function(MatchedProduct product) onSelectReplacement,
  }) {
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) => SuggestedReplacementsModal(
        pair: pair,
        isDark: isDark,
        onSelectReplacement: onSelectReplacement,
      ),
    );
  }

  @override
  State<SuggestedReplacementsModal> createState() => _SuggestedReplacementsModalState();
}

class _SuggestedReplacementsModalState extends State<SuggestedReplacementsModal> {
  bool _isLoading = true;
  List<MatchedProduct> _alternatives = [];

  @override
  void initState() {
    super.initState();
    _loadAlternatives();
  }

  Future<void> _loadAlternatives() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final businessId = auth.activeBusinessId;
    if (businessId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final db = await LocalDatabase.instance.database;
      final currentProdId = widget.pair.selectedProduct?.productId ?? 0;
      final currentPresId = widget.pair.selectedProduct?.presentationId ?? 0;

      // 1. Obtener la categoría del producto actual
      int categoriaId = 0;
      if (currentProdId > 0) {
        final catQuery = await db.query(
          'productos',
          columns: ['categoria_id'],
          where: 'id = ?',
          whereArgs: [currentProdId],
          limit: 1,
        );
        if (catQuery.isNotEmpty) {
          categoriaId = (catQuery.first['categoria_id'] as num?)?.toInt() ?? 0;
        }
      }

      List<Map<String, dynamic>> rows = [];

      // Si tenemos categoría válida (> 0), buscar productos de esa categoría con stock
      if (categoriaId > 0) {
        rows = await db.rawQuery('''
          SELECT p.id as producto_id, p.nombre as producto_nombre, p.imagen_url as prod_imagen,
                 pp.id as presentacion_id, pp.nombre_especifico, pp.precio_venta_final, pp.precio_oferta,
                 pp.stock_actual, pp.unidad_venta, pp.unidades_por_lote, m.nombre as marca_nombre
          FROM presentaciones_producto pp
          JOIN productos p ON pp.producto_id = p.id
          LEFT JOIN marcas m ON p.marca_id = m.id
          WHERE p.negocio_id = ? AND pp.stock_actual > 0 AND p.categoria_id = ? AND pp.id != ?
          ORDER BY pp.stock_actual DESC, pp.precio_venta_final ASC
          LIMIT 20
        ''', [businessId, categoriaId, currentPresId]);
      }

      // Si no hay suficientes por categoría, buscar por nombre o palabras clave
      if (rows.isEmpty) {
        final keywords = widget.pair.sourceItem.fullName.split(' ').where((w) => w.length > 2).take(2).toList();
        final searchPattern = keywords.isNotEmpty ? "%${keywords.first}%" : "%${widget.pair.sourceItem.fullName}%";

        rows = await db.rawQuery('''
          SELECT p.id as producto_id, p.nombre as producto_nombre, p.imagen_url as prod_imagen,
                 pp.id as presentacion_id, pp.nombre_especifico, pp.precio_venta_final, pp.precio_oferta,
                 pp.stock_actual, pp.unidad_venta, pp.unidades_por_lote, m.nombre as marca_nombre
          FROM presentaciones_producto pp
          JOIN productos p ON pp.producto_id = p.id
          LEFT JOIN marcas m ON p.marca_id = m.id
          WHERE p.negocio_id = ? AND pp.stock_actual > 0 AND (p.nombre LIKE ? OR pp.nombre_especifico LIKE ?) AND pp.id != ?
          ORDER BY pp.stock_actual DESC, pp.precio_venta_final ASC
          LIMIT 20
        ''', [businessId, searchPattern, searchPattern, currentPresId]);
      }

      final parsed = rows.map((r) {
        final String prodName = r['producto_nombre'] ?? '';
        final String? specName = r['nombre_especifico'];
        final String fullName = (specName != null && specName.isNotEmpty) ? "$prodName - $specName" : prodName;

        return MatchedProduct(
          productId: r['producto_id'] as int,
          presentationId: r['presentacion_id'] as int,
          fullName: fullName,
          productName: prodName,
          specificName: specName,
          brand: r['marca_nombre'] as String?,
          price: (r['precio_venta_final'] as num?)?.toDouble() ?? 0.0,
          offerPrice: (r['precio_oferta'] as num?)?.toDouble(),
          stock: (r['stock_actual'] as num?)?.toInt() ?? 0,
          imageUrl: (r['prod_imagen'] as String?),
          unit: (r['unidad_venta'] as String?) ?? 'Unidad',
          conversionFactor: (r['unidades_por_lote'] as num?)?.toInt() ?? 1,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _alternatives = parsed;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading suggested replacements: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(context);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 8, 20, effectiveBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Reemplazos Sugeridos",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    Text(
                      "Alternativas con stock para '${widget.pair.sourceItem.fullName}'",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_alternatives.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 48, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    "No se encontraron productos alternativos con stock disponible en esta categoría.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _alternatives.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, index) {
                  final alt = _alternatives[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F1F2B) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: UniversalImage(path: alt.imageUrl, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alt.fullName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "${alt.stock} en stock",
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    currency.format(alt.price),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: isDark ? Colors.blue[300] : Colors.blue[800],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onSelectReplacement(alt);
                          },
                          child: const Text("Usar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
