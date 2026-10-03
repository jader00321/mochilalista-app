# Plan de Implementación: Normalización de Stock Real, Ventas Factor-Aware y Paginación

## Contexto del Problema

El sistema tiene un concepto de **"stock base"** (`stockActual`) que almacena unidades individuales en la base de datos. Cuando un producto se vende en una unidad compuesta (par, docena, caja, paquete), se usa un **factor de conversión** (`unidadesPorVenta`). El **"stock real"** visible al usuario debe ser `stockActual / factor`.

### Problemas Detectados:

1. **Guardado de Stock al crear producto**: El campo `stockActual` se calcula como `stockVisual * factor` antes de guardar ✅ — ESTO YA FUNCIONA CORRECTAMENTE en `product_create_screen.dart` L440 y `product_edit_screen.dart` L699.

2. **Visualización de Stock inconsistente**: Algunos componentes usan `stockActual` directamente (stock base), otros usan `displayStock` (stock real). Esto genera confusión.

3. **Ventas NO consideran el factor**: Al vender 2 cajas (factor=12), `sales_service.dart` L127 deduce `2` del `stock_actual` en vez de `24` (2×12). **BUG CRÍTICO**.

4. **Validación de stock en carrito usa stock base**: `CatalogProvider.addToCart()` valida contra `stockActual` (base), pero el usuario piensa en unidades de venta. Si tiene 24 unidades base y factor=12 (2 cajas), el sistema permitiría "agregar 24 cajas" en lugar de limitar a 2.

5. **Paginación**: Todos los providers usan `_limit = 20`. El usuario necesita 50 items y que los más nuevos aparezcan primero.

6. **Contadores de modales**: Ya muestran variantes correctamente en `inventory_filter_header.dart`.

---

## User Review Required

> [!IMPORTANT]
> **Decisión de diseño sobre stock en ventas**: Actualmente cuando el usuario agrega "1 Caja" al carrito de venta rápida, el sistema registra `quantity: 1` y deduce 1 del stock base. La corrección hará que deduzca `1 × factor` del stock base. Esto afectará **todas las ventas nuevas** inmediatamente.

> [!WARNING]
> **Stock en `MatchedProduct`**: El campo `stock` del modelo `MatchedProduct` actualmente guarda `stockActual` (base). La corrección cambiará esto a `displayStock` (stock real). Esto impacta los límites de cantidad en el carrito de caja rápida y la validación al comprar.

> [!CAUTION]
> **Datos históricos**: Las ventas anteriores que se hicieron con el bug ya dedujeron incorrectamente el stock. No corregiremos datos históricos — solo el flujo futuro.

---

## Open Questions

> [!IMPORTANT]
> **¿Qué ordenamiento default quieres para el inventario?** Opciones:
> - **Opción A**: Más nuevos primero (`ORDER BY pr.id DESC`) — lo solicitaste
> - **Opción B**: Más nuevos primero solo al cargar inicial, pero mantener A-Z cuando el usuario cambia el orden

> [!IMPORTANT]
> **¿El `StockUpdateModal` debe trabajar en unidades de venta o unidades base?** Actualmente muestra y guarda `stockActual` (base). ¿Preferirías que muestre "10 Cajas" en vez de "120 unidades" y que al guardar multiplique por factor?

---

## Proposed Changes

### Componente 1: Modelo y Capa de Datos — Stock Display Centralizado

#### [MODIFY] [inventory_wrapper.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/models/inventory_wrapper.dart)

Ya tiene `displayStock` y `displayStockText` definidos correctamente. Se agregarán getters de conveniencia:
- `displayStockForValidation` → para validar límites del carrito usando stock real (unidades de venta)

```diff
+ /// Stock real para validaciones de carrito (en unidades de venta)
+ int get displayStockForValidation => displayStock;
```

---

### Componente 2: Widgets de Inventario — Normalización de Stock Visual

#### [MODIFY] [inventory_grid_card.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/widgets/inventory_grid_card.dart)

**Problema**: Línea 26 usa `presentation.stockActual` directamente.

```diff
- final int stock = presentation.stockActual;
+ final int stock = item.displayStock;
```

Línea 128 — también actualizar el texto para mostrar la unidad:
```diff
- Text(isOut ? "0" : "$stock", ...)
+ Text(isOut ? "Agotado" : item.displayStockText, ...)
```

---

#### [MODIFY] [product_action_sheet.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/widgets/product_action_sheet.dart)

**Problema**: Línea 373 usa `widget.presentation.stockActual` directamente. Pero este widget recibe `ProductPresentation`, no `InventoryWrapper`. Necesitamos calcular in-line.

```diff
- final int stock = widget.presentation.stockActual;
+ int factor = widget.presentation.unidadesPorVenta;
+ if (factor <= 0) factor = 1;
+ final int stock = widget.presentation.stockActual ~/ factor;
```

---

#### [MODIFY] [product_detail_modal.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/widgets/product_detail_modal.dart)

**Problema**: Línea 32 usa `stockActual` para `_maxStock`, lo cual limita incorrectamente las cantidades del carrito del catálogo.

```diff
- _maxStock = widget.item.presentation.stockActual;
+ _maxStock = widget.item.displayStock;
```

---

#### [MODIFY] [catalog_item_card.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/widgets/catalog_item_card.dart)

**Problema**: Línea 58 usa `pres.stockActual` directamente.

```diff
- final bool isOutOfStock = pres.stockActual <= 0;
+ final bool isOutOfStock = item.isOutOfStock;
```

---

#### [MODIFY] [stock_update_modal.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/widgets/stock_update_modal.dart)

**Problema**: Muestra y edita `stockActual` directamente (stock base). Necesita mostrar stock real y convertir al guardar. Se agregará label de contexto y conversión.

```diff
  // initState:
- currentStock = widget.presentation.stockActual;
+ int factor = widget.presentation.unidadesPorVenta;
+ if (factor <= 0) factor = 1;
+ currentStock = widget.presentation.stockActual ~/ factor;

  // onPressed de guardar:
- await widget.provider.updatePresentation(widget.presentation.id!, stock: currentStock);
+ int stockBase = currentStock * factor;
+ await widget.provider.updatePresentation(widget.presentation.id!, stock: stockBase);
```

Agregar label visual que muestre la unidad de venta: "Unidad: Caja (×12)"

---

### Componente 3: Flujo de Ventas — Deducción Factor-Aware

#### [MODIFY] [sales_service.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/sales_service.dart)

**BUG CRÍTICO** en L108-132: La deducción de stock no considera el factor de conversión.

```diff
  } else if (item['presentation_id'] != null) {
    int presId = item['presentation_id'];

    final presCheck = await txn.query(
      'presentaciones_producto',
-     columns: ['stock_actual', 'stock_alerta', 'costo_unitario_calculado', 'precio_venta_final'],
+     columns: ['stock_actual', 'stock_alerta', 'costo_unitario_calculado', 'precio_venta_final', 'unidades_por_venta'],
      where: 'id = ?',
      whereArgs: [presId],
    );

    int currentStock = (presCheck.first['stock_actual'] as int?) ?? 0;
    int stockAlerta = (presCheck.first['stock_alerta'] as int?) ?? 5;
+   int factor = (presCheck.first['unidades_por_venta'] as int?) ?? 1;
+   if (factor <= 0) factor = 1;
    
-   if (currentStock < quantity) {
+   int baseUnitsToDeduct = quantity * factor;
+   if (currentStock < baseUnitsToDeduct) {
      throw Exception("Stock insuficiente para uno de los productos.");
    }
    
-   int newStock = currentStock - quantity;
+   int newStock = currentStock - baseUnitsToDeduct;

    await txn.rawUpdate(
      'UPDATE presentaciones_producto SET stock_actual = ? WHERE id = ?',
      [newStock, presId],
    );

    // Registro en Trazabilidad Histórica (Audit Log)
    await txn.insert('stock_ledger', {
      'presentation_id': presId,
      'negocio_id': negocioId,
      'tipo_transaccion': 'VENTA',
-     'cantidad': -quantity,
+     'cantidad': -baseUnitsToDeduct,
      ...
    });
```

---

#### [MODIFY] [quick_sale_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/quick_sale_provider.dart)

**Problema**: L97 y L109 — `addToCart` almacena `stockActual` (base) en `MatchedProduct.stock`, pero el usuario interactúa en unidades de venta. La validación de stock máximo debe usar stock real.

```diff
  // L97: Validación al incrementar
- return updateQuantity(presId, ..., itemWrapper.presentation.stockActual);
+ return updateQuantity(presId, ..., itemWrapper.displayStock);

  // L109: Stock almacenado en MatchedProduct  
- stock: itemWrapper.presentation.stockActual,
+ stock: itemWrapper.displayStock,
```

---

#### [MODIFY] [catalog_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/providers/catalog_provider.dart)

**Problema**: L332-341 y L359-361 — `addToCart` y `updateCartItemQuantity` validan contra `stockActual` (base).

```diff
  // addToCart — L332
- if (newQty <= item.presentation.stockActual) {
+ if (newQty <= item.displayStock) {

  // L335
- _shoppingCart[index].quantity = item.presentation.stockActual;
+ _shoppingCart[index].quantity = item.displayStock;

  // L337
- "Solo se agregaron hasta alcanzar el stock máximo (${item.presentation.stockActual})."
+ "Solo se agregaron hasta alcanzar el stock máximo (${item.displayStockText})."

  // L340-341
- int realQty = quantity > item.presentation.stockActual
-     ? item.presentation.stockActual
+ int realQty = quantity > item.displayStock
+     ? item.displayStock

  // updateCartItemQuantity — L359-361
- if (newQuantity > item.item.presentation.stockActual) {
+ if (newQuantity > item.item.displayStock) {
-   "Solo hay ${item.item.presentation.stockActual} unidades disponibles."
+   "Solo hay ${item.item.displayStockText} disponibles."
```

---

#### [MODIFY] [matching_product_search_modal.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_product_search_modal.dart)

**Problema**: L272-273 y L292 — Usa `pres.stockActual` directamente para stock display.

```diff
  // L272-273
- Color stockColor = _getStockColor(pres.stockActual);
- String stockText = pres.stockActual > 0 ? "Stock: ${pres.stockActual}" : "AGOTADO";
+ int factor = pres.unidadesPorVenta;
+ if (factor <= 0) factor = 1;
+ int realStock = pres.stockActual ~/ factor;
+ String unitName = pres.unidadVenta ?? "Unidad";
+ Color stockColor = _getStockColor(realStock);
+ String stockText = realStock > 0 ? "Stock: $realStock $unitName" : "AGOTADO";

  // L292
- stock: pres.stockActual,
+ stock: realStock,
```

---

### Componente 4: Paginación — 50 Items y Más Nuevos Primero

#### [MODIFY] [inventory_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/providers/inventory_provider.dart)

```diff
- final int _limit = 20;
+ final int _limit = 50;
```

#### [MODIFY] [catalog_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/providers/catalog_provider.dart)

```diff
- final int _limit = 20;
+ final int _limit = 50;
```

#### [MODIFY] [quick_search_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/quick_search_provider.dart)

```diff
- final int _limit = 20;
+ final int _limit = 50;
```

#### [MODIFY] [sale_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/sale_provider.dart)

```diff
- final int _limit = 20;
+ final int _limit = 50;
```

#### [MODIFY] [manual_product_search.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/widgets/manual_product_search.dart)

```diff
- final int _limit = 20;
+ final int _limit = 50;
```

#### [MODIFY] [matching_product_search_modal.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_product_search_modal.dart)

```diff
- final int _limit = 20;
+ final int _limit = 50;
```

#### [MODIFY] [manual_quote_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/manual_quote_provider.dart)

```diff
- final int _limit = 20;
+ final int _limit = 50;
```

#### [MODIFY] [invoice_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/providers/invoice_provider.dart)

```diff
- final int _limit = 20;
+ final int _limit = 50;
```

---

#### [MODIFY] [product_repository.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/repositories/product_repository.dart)

**Problema**: L87 — El ORDER BY es `LOWER(p.nombre)` por defecto. Para "más nuevos primero", debe ser por `pr.id DESC` cuando no hay búsqueda activa.

```diff
- query += " ORDER BY LOWER(p.nombre) $sortDir LIMIT ? OFFSET ?";
+ String orderClause;
+ if (queryParams['q'] != null && queryParams['q'].toString().isNotEmpty) {
+   orderClause = "ORDER BY LOWER(p.nombre) $sortDir";
+ } else {
+   orderClause = "ORDER BY pr.id DESC";
+ }
+ query += " $orderClause LIMIT ? OFFSET ?";
```

---

### Componente 5: Verificación de `isOutOfStock` y `isLowStock`

#### [MODIFY] [inventory_wrapper.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/models/inventory_wrapper.dart)

`isOutOfStock` y `isLowStock` deben basarse en `displayStock` para coherencia visual:

```diff
- bool get isOutOfStock => presentation.stockActual <= 0;
+ bool get isOutOfStock => displayStock <= 0;

- bool get isLowStock =>
-     presentation.stockActual > 0 &&
-     presentation.stockActual <= (presentation.stockAlerta ?? 5);
+ bool get isLowStock =>
+     displayStock > 0 &&
+     displayStock <= (presentation.stockAlerta ?? 5);
```

---

## Resumen de Archivos Impactados

| Archivo | Cambio | Riesgo |
|---------|--------|--------|
| `inventory_wrapper.dart` | `isOutOfStock`/`isLowStock` basados en `displayStock` | Medio |
| `inventory_grid_card.dart` | Usar `displayStock` | Bajo |
| `product_action_sheet.dart` | Calcular stock real inline | Bajo |
| `product_detail_modal.dart` | `_maxStock` = `displayStock` | Bajo |
| `catalog_item_card.dart` | `isOutOfStock` via wrapper | Bajo |
| `stock_update_modal.dart` | Mostrar/guardar con factor | Medio |
| `sales_service.dart` | `quantity * factor` en deducción | **ALTO** |
| `quick_sale_provider.dart` | `displayStock` en cart limits | Medio |
| `catalog_provider.dart` | `displayStock` en cart limits | Medio |
| `matching_product_search_modal.dart` | Stock real en modal + paginación | Bajo |
| 8 archivos de paginación | `_limit = 50` | Bajo |
| `product_repository.dart` | `ORDER BY pr.id DESC` por defecto | Bajo |

---

## Verification Plan

### Automated Tests
- `flutter analyze` — Verificar 0 errores de compilación tras cambios
- `flutter build apk --debug` — Verificar build completo

### Manual Verification
1. **Crear producto** con factor > 1 (ej: "Par", factor=2, stock=10 pares) → verificar que el DB guarda `stock_actual=20`
2. **Visualizar en grid/tile/detail** → debe mostrar "10 Pares", no "20"
3. **Vender 2 pares** desde Caja Rápida → verificar que `stock_actual` baja de 20 a 16 (2×2=4 deducidas)
4. **Stock Update Modal** → al abrir debe mostrar "10", al cambiar a "8" y guardar debe escribir `16` en DB
5. **Verificar paginación** → cargar inventario y confirmar que llegan 50 items, ordenados por ID descendente
6. **Verificar carrito catálogo** → agregar más unidades que el stock real debe bloquearse
