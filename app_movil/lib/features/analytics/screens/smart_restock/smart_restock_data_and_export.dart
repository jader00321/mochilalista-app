part of '../smart_restock_screen.dart';

mixin _SmartRestockDataAndExportMixin on _SmartRestockScreenStateBase {
  @override
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final db = await LocalDatabase.instance.database;

      final products = await db.rawQuery('''
        SELECT pp.id as presentation_id, p.id as product_id, p.nombre, IFNULL(m.nombre, 'Sin Marca') as marca_nombre, 
               pp.nombre_especifico, pp.stock_actual, pp.costo_unitario_calculado, IFNULL(pp.stock_alerta, 5) as stock_alerta,
               pp.usa_stock_compartido, pp.unidades_por_venta, p.modo_stock, p.stock_compartido, p.costo_base
        FROM presentaciones_producto pp
        INNER JOIN productos p ON pp.producto_id = p.id
        LEFT JOIN marcas m ON p.marca_id = m.id
        WHERE p.negocio_id = ? AND pp.activo = 1
      ''', [auth.activeBusinessId]);

      List<SmartRestockItem> results = [];

      final Map<int, List<Map<String, dynamic>>> sharedByProduct = {};
      final List<Map<String, dynamic>> independentRows = [];

      for (var row in products) {
        bool isShared = (row['usa_stock_compartido'] as int? ?? 0) == 1;
        if (isShared) {
          int prodId = row['product_id'] as int;
          sharedByProduct.putIfAbsent(prodId, () => []).add(row);
        } else {
          independentRows.add(row);
        }
      }

      // 1. Consolidación de 1 Sola Tarjeta por Pool Compartido (Regla Obligatoria 3)
      for (var entry in sharedByProduct.entries) {
        int prodId = entry.key;
        final rows = entry.value;
        final firstRow = rows.first;

        final presNames = rows
            .map((r) => (r['nombre_especifico'] as String? ?? 'Unidad').trim())
            .where((n) => n.isNotEmpty)
            .toList();
        final badgeText = "Pool Compartido: ${presNames.join(', ')}";

        int currentPoolStock =
            (firstRow['stock_compartido'] as num?)?.toInt() ??
            ((firstRow['stock_actual'] as num?)?.toInt() ?? 0);
        int configuredAlert = rows
            .map((r) => (r['stock_alerta'] as num?)?.toInt() ?? 5)
            .reduce(math.max);
        double cost =
            (firstRow['costo_base'] as num?)?.toDouble() ??
            ((firstRow['costo_unitario_calculado'] as num?)?.toDouble() ?? 0.0);

        // Detección de Quiebres de Formato en Variantes del Pool Compartido
        List<String> formatBreaks = [];
        int maxMissingBase = 0;
        String? targetBreakVariant;
        int maxVariantFactor = 1;

        for (var r in rows) {
          final int factor = (r['unidades_por_venta'] as num?)?.toInt() ?? 1;
          final String pName = (r['nombre_especifico'] as String? ?? 'Variante')
              .trim();
          if (factor > maxVariantFactor) maxVariantFactor = factor;
          if (factor > 1 && currentPoolStock < factor) {
            int missingBase = factor - currentPoolStock;
            formatBreaks.add(
              "$pName (0 disponibles, faltan $missingBase u. base)",
            );
            if (missingBase > maxMissingBase) {
              maxMissingBase = missingBase;
              targetBreakVariant = pName;
            }
          }
        }
        final String? formatBreakAlert = formatBreaks.isNotEmpty
            ? formatBreaks.join(' • ')
            : null;

        final biData = await _biService.calculateSharedPoolReorderPoint(
          prodId,
          currentPoolStock,
          configuredAlertStock: configuredAlert,
        );

        int rop = (biData['rop'] as num).toInt();
        double vel = (biData['velocity_per_day'] as num).toDouble();
        String velocityDisplay =
            biData['velocity_display'] as String? ??
            "${vel.toStringAsFixed(1)}/d";
        double daysToStockout = (biData['days_to_stockout'] as num).toDouble();
        String stockoutDate = biData['stockout_date'] as String? ?? "";
        int suggestedQty = (biData['suggested_order_qty'] as num).toInt();
        String status = biData['status'] as String? ?? "saludable";

        // Recomendación exacta de compra por variante ante quiebre de formato o sin ventas históricas
        int effectiveSuggested = suggestedQty;
        if (maxMissingBase > 0 && effectiveSuggested < maxMissingBase) {
          effectiveSuggested = maxMissingBase;
        }
        if (vel <= 0) {
          int deficitMin = configuredAlert > currentPoolStock
              ? (configuredAlert - currentPoolStock)
              : 0;
          int needed = math.max(deficitMin, maxMissingBase);
          if (needed > effectiveSuggested) {
            effectiveSuggested = needed;
          }
        }

        // Si hay quiebre de formato o déficit respecto al stock mínimo, el estado no debe ser saludable
        if (formatBreakAlert != null ||
            (vel <= 0 &&
                currentPoolStock <= configuredAlert &&
                configuredAlert > 0)) {
          if (status == 'saludable') {
            status = currentPoolStock == 0 ? 'agotado' : 'critico';
          }
        }

        Color statusColor;
        String statusText;

        if (status == 'agotado') {
          statusColor = Colors.red[900]!;
          statusText = 'Agotado';
        } else if (status == 'critico') {
          statusColor = Colors.redAccent;
          statusText = 'Stock Crítico';
        } else if (status == 'preventivo') {
          statusColor = Colors.orangeAccent;
          statusText = 'Preventivo';
        } else {
          statusColor = Colors.green;
          statusText = 'Saludable';
        }

        String? suggestedOrderRecommendation;
        if (targetBreakVariant != null && maxMissingBase > 0) {
          suggestedOrderRecommendation =
              "Comprar mín. $maxMissingBase u. base para completar 1 $targetBreakVariant";
        } else if (effectiveSuggested > 0) {
          suggestedOrderRecommendation =
              "Comprar $effectiveSuggested u. base para reponer nivel óptimo";
        }

        bool isRestockItem =
            status != 'saludable' ||
            effectiveSuggested > 0 ||
            formatBreakAlert != null;
        int initialOrderQty = effectiveSuggested > 0
            ? effectiveSuggested
            : math.max(1, rop);

        results.add(
          SmartRestockItem(
            presentationId: firstRow['presentation_id'] as int,
            productId: prodId,
            productName: firstRow['nombre'] as String,
            brandName: firstRow['marca_nombre'] as String,
            presentationName: 'Pool Compartido',
            currentStock: currentPoolStock,
            cost: cost,
            velocityPerDay: vel,
            velocityDisplay: velocityDisplay,
            safetyStock: (biData['safety_stock'] as num).toInt(),
            rop: rop,
            suggestedQty: effectiveSuggested,
            orderQty: initialOrderQty,
            isSelected: isRestockItem,
            daysToStockout: daysToStockout,
            stockoutDate: stockoutDate,
            status: status,
            statusColor: statusColor,
            statusText: statusText,
            hasZeroCost: cost <= 0,
            isSharedPool: true,
            sharedPresentationsBadge: badgeText,
            formatBreakAlert: formatBreakAlert,
            suggestedOrderRecommendation: suggestedOrderRecommendation,
            modoStock: firstRow['modo_stock']?.toString() ?? 'COMPARTIDO',
          ),
        );
      }

      // 2. Variantes independientes (usa_stock_compartido = 0)
      for (var row in independentRows) {
        int presId = row['presentation_id'] as int;
        int currentStock = (row['stock_actual'] as num?)?.toInt() ?? 0;
        int configuredAlert = (row['stock_alerta'] as num?)?.toInt() ?? 5;
        double cost =
            (row['costo_unitario_calculado'] as num?)?.toDouble() ?? 0.0;
        String modoStockProd = row['modo_stock']?.toString() ?? 'INDEPENDIENTE';

        final biData = await _biService.calculateReorderPoint(
          presId,
          currentStock,
          configuredAlertStock: configuredAlert,
        );

        int rop = (biData['rop'] as num).toInt();
        double vel = (biData['velocity_per_day'] as num).toDouble();
        String velocityDisplay =
            biData['velocity_display'] as String? ??
            "${vel.toStringAsFixed(1)}/d";
        double daysToStockout = (biData['days_to_stockout'] as num).toDouble();
        String stockoutDate = biData['stockout_date'] as String? ?? "";
        int suggestedQty = (biData['suggested_order_qty'] as num).toInt();
        String status = biData['status'] as String? ?? "saludable";

        int effectiveSuggested = suggestedQty;
        if (vel <= 0 &&
            currentStock <= configuredAlert &&
            configuredAlert > 0) {
          int deficit = math.max(1, configuredAlert - currentStock);
          if (deficit > effectiveSuggested) effectiveSuggested = deficit;
          if (status == 'saludable') {
            status = currentStock == 0 ? 'agotado' : 'critico';
          }
        }

        Color statusColor;
        String statusText;

        if (status == 'agotado') {
          statusColor = Colors.red[900]!;
          statusText = 'Agotado';
        } else if (status == 'critico') {
          statusColor = Colors.redAccent;
          statusText = 'Stock Crítico';
        } else if (status == 'preventivo') {
          statusColor = Colors.orangeAccent;
          statusText = 'Preventivo';
        } else {
          statusColor = Colors.green;
          statusText = 'Saludable';
        }

        String? suggestedOrderRecommendation;
        if (effectiveSuggested > 0) {
          suggestedOrderRecommendation =
              "Comprar $effectiveSuggested und (reposición stock mínimo)";
        }

        bool isRestockItem = status != 'saludable' || effectiveSuggested > 0;
        int initialOrderQty = effectiveSuggested > 0
            ? effectiveSuggested
            : math.max(1, rop);

        results.add(
          SmartRestockItem(
            presentationId: presId,
            productId: row['product_id'] as int,
            productName: row['nombre'] as String,
            brandName: row['marca_nombre'] as String,
            presentationName: row['nombre_especifico'] as String? ?? 'Unidad',
            currentStock: currentStock,
            cost: cost,
            velocityPerDay: vel,
            velocityDisplay: velocityDisplay,
            safetyStock: (biData['safety_stock'] as num).toInt(),
            rop: rop,
            suggestedQty: effectiveSuggested,
            orderQty: initialOrderQty,
            isSelected: isRestockItem,
            daysToStockout: daysToStockout,
            stockoutDate: stockoutDate,
            status: status,
            statusColor: statusColor,
            statusText: statusText,
            hasZeroCost: cost <= 0,
            isSharedPool: false,
            suggestedOrderRecommendation: suggestedOrderRecommendation,
            modoStock: modoStockProd,
          ),
        );
      }

      // Ordenar por urgencia: Agotados primero, luego Críticos, luego Preventivos, luego Saludables
      results.sort((a, b) {
        int rank(String s) {
          switch (s) {
            case 'agotado':
              return 0;
            case 'critico':
              return 1;
            case 'preventivo':
              return 2;
            default:
              return 3;
          }
        }

        int rankDiff = rank(a.status).compareTo(rank(b.status));
        if (rankDiff != 0) return rankDiff;
        // Si tienen el mismo rango, mayor déficit respecto a ROP primero
        int deficitA = a.rop - a.currentStock;
        int deficitB = b.rop - b.currentStock;
        return deficitB.compareTo(deficitA);
      });

      if (mounted) {
        setState(() {
          _items = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar inventario: $e')),
        );
      }
    }
  }

  // Filtrado reactivo en memoria
  @override
  List<SmartRestockItem> get _filteredItems {
    return _items.where((item) {
      // Filtro de estado
      if (_currentFilter == 'por_pedir') {
        if (item.status == 'saludable' && item.suggestedQty <= 0) {
          return false;
        }
      } else if (_currentFilter == 'urgentes') {
        if (item.status != 'agotado' && item.status != 'critico') return false;
      } else if (_currentFilter == 'preventivos') {
        if (item.status != 'preventivo') return false;
      } else if (_currentFilter == 'saludables') {
        if (item.status != 'saludable') return false;
      }

      // Buscador
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = item.productName.toLowerCase().contains(q);
        final matchBrand = item.brandName.toLowerCase().contains(q);
        final matchPres = item.presentationName.toLowerCase().contains(q);
        if (!matchName && !matchBrand && !matchPres) return false;
      }

      return true;
    }).toList();
  }

  // =========================================================================
  // EXPORTACIÓN A PDF DE LA ORDEN DE COMPRA SELECCIONADA
  // =========================================================================
  @override
  Future<void> _exportOC() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final selectedItems = _items.where((i) => i.isSelected).toList();
      if (selectedItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Selecciona al menos un producto para exportar la Orden de Compra.',
            ),
          ),
        );
        return;
      }
      final file = await PurchaseOrderGenerator.exportToPdf(
        selectedItems,
        auth.businessName,
      );
      if (!mounted) return;
      // ignore: deprecated_member_use
      Share.shareXFiles([
        XFile(file.path),
      ], text: 'Orden de Compra Sugerida - ${auth.businessName}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
