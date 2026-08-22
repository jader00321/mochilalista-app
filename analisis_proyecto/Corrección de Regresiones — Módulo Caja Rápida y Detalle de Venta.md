# Corrección de Regresiones — Módulo Caja Rápida y Detalle de Venta

## Resumen del Problema

Se han detectado 4 problemas críticos en el flujo de venta rápida (POS) que afectan la integridad de datos, la lógica de inventario y la experiencia de usuario. A continuación, se detalla el análisis de causa raíz de cada bug y el plan de corrección por fases.

---

## Análisis de Causa Raíz

### Bug 1: Pérdida de la Marca (`brand`)

**Ubicación del Problema:** [`quick_sale_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/quick_sale_provider.dart#L98-L111)

En el método `addToCart()`, línea 104, la marca se asigna así:

```dart
brand: itemWrapper.product.marcaId?.toString() ?? itemWrapper.product.marcaNombre,
```

> [!CAUTION]
> Esto es **incorrecto**. Si `marcaId` existe (ej: `5`), la marca se guarda como el string `"5"` en vez del nombre legible `"UNIMUNDO"`. Luego, en el widget [`sale_items_list.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/history/detail_widgets/sale_items_list.dart#L79), la línea 79 filtra marcas numéricas con `int.tryParse(item['brand_name'].toString()) == null`, lo que provoca que marcas guardadas como `"5"` se oculten.

**Ciclo de vida del dato:**
1. `addToCart()` → `brand = marcaId.toString()` → `"5"` ❌
2. `generateDummyQuotation()` → `brandName: p.brand` → `"5"` ❌
3. `_submitSale()` en checkout → `brand_name: item.brand` → `"5"` ❌
4. Se inserta en `venta_items.brand_name = "5"` ❌
5. `sale_items_list.dart` filtra → `int.tryParse("5") != null` → NO se muestra ❌

**Solución:** Siempre usar `marcaNombre` (el nombre legible), nunca `marcaId.toString()`.

---

### Bug 2: "Volver a Vender" falla con Ofertas/Paquetes

**Ubicación del Problema:** [`quick_sale_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/quick_sale_provider.dart#L253-L317) — método `restoreCartFromHistory()`

El método solo busca productos individuales con `invProv.fetchProductById(prodId)` (línea 275). Cuando el ítem histórico es un **bundle/oferta**, tiene `bundle_id != null` y `presentation_id == null` (o el fake ID negativo). El código llega a la línea 270-273:

```dart
if (prodId == null || presId == null) {
  notFound.add(fallbackName);  // ← Aquí cae la Oferta
  continue;
}
```

> [!IMPORTANT]
> No existe ninguna rama que maneje `item['bundle_id'] != null`. El sistema ni siquiera intenta buscar la oferta en el `PromotionProvider`, por lo que toda oferta genera un error "producto no encontrado".

**Solución:** Agregar una rama condicional al inicio del `for` que detecte `bundle_id != null` y use el `PromotionProvider` para buscar y re-hidratar el bundle.

---

### Bug 3: Stock NO se descuenta para componentes de Ofertas

**Ubicación del Problema:** [`sales_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/sales_service.dart#L72-L103) — método `createSale()`

> [!NOTE]
> **HALLAZGO POSITIVO:** Después de analizar el código en detalle, he descubierto que la lógica de "un-kitting" (descuento recursivo de stock por componentes del bundle) **YA ESTÁ IMPLEMENTADA** correctamente en las líneas 76-103 de `sales_service.dart`.

```dart
// UN-KITTING LOGIC (línea 76-103)
if (item['bundle_id'] != null) {
  int bundleId = item['bundle_id'];
  final bundleItems = await txn.query('items_paquete', ...);
  for (var bItem in bundleItems) {
    int totalDeduct = qtyReq * quantity;
    await txn.rawUpdate('UPDATE presentaciones_producto SET stock_actual = ? WHERE id = ?', ...);
    // + stock_ledger audit
  }
}
```

El descuento de stock funciona porque:
- El `_submitSale()` en [`quick_checkout_modal.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/quick_sale/quick_checkout_modal.dart#L71-L88) pasa `bundle_id` correctamente en `detalleVenta` (línea 75).
- `sales_service.createSale()` detecta `bundle_id != null` y hace el un-kitting recursivo.

**Conclusión:** Este bug **NO existe en el código actual**. La lógica es correcta. Solo recomendaré agregar validación de stock previo (pre-check) antes de la transacción para dar un mejor error al usuario.

---

### Bug 4: Espacio UI restringido por "Datos del Cliente"

**Ubicación del Problema:** [`quick_sale_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/quick_sale_screen.dart#L298-L505)

El layout actual usa una `Column` rígida:
```
Column → [
  QuickSaleHeader (ExpansionTile fijo),
  Container(search bar),
  Expanded(cart OR search results),
  Container(footer COBRAR)
]
```

El `QuickSaleHeader` usa `ExpansionTile` que sí es colapsable, pero **incluso cuando está colapsado**, ocupa espacio vertical fijo (~60px). Cuando hay muchos productos en el carrito, el espacio visible para el `ReorderableListView` queda muy comprimido, como se ve en las capturas.

**Solución:** Convertir el body a `CustomScrollView` con Slivers. El header del cliente se transforma en un `SliverPersistentHeader` con `floating: true, snap: true`, que se oculta al hacer scroll hacia abajo y reaparece con un ligero scroll hacia arriba.

---

## Plan de Trabajo por Fases

### Fase 1: Corrección de Mapeo de Marca (Integridad de Datos)

> Prioridad: **CRÍTICA** — Afecta datos persistidos en la BD.

#### [MODIFY] [`quick_sale_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/quick_sale_provider.dart)

1. **`addToCart()`** (línea 104): Cambiar la asignación de `brand`:
   ```diff
   - brand: itemWrapper.product.marcaId?.toString() ?? itemWrapper.product.marcaNombre,
   + brand: itemWrapper.product.marcaNombre,
   ```

2. **`restoreCartFromHistory()`** (línea 291): Verificar que use `prod.marcaNombre` (ya lo hace correctamente ✅).

#### Verificación
- Agregar un producto con marca conocida (ej. "UNIMUNDO") al carrito.
- Procesar la venta.
- Verificar en el historial que el recibo muestre el badge de marca con el nombre correcto.

---

### Fase 2: Resolución del Bug de Re-Venta de Ofertas

> Prioridad: **ALTA** — El botón "Volver a Vender" crashea para recibos con ofertas.

#### [MODIFY] [`quick_sale_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/quick_sale_provider.dart)

Refactorizar `restoreCartFromHistory()` para manejar bundles:

**Cambio principal:** Al inicio del `for`, antes de verificar `prodId`/`presId`, agregar una rama:

```dart
// NUEVA RAMA: Si el ítem histórico es un bundle/oferta
int? bundleId = item['bundle_id'];
if (bundleId != null) {
  // 1. Buscar el bundle en el PromotionProvider
  // 2. Verificar que siga activo y con stock
  // 3. Usar addBundleToCart() con la cantidad del historial
  // 4. Si no se encuentra → notFound.add(...)
  continue;
}
```

**Parámetro nuevo:** El método necesitará recibir el `PromotionProvider` como parámetro adicional:

```diff
  Future<Map<String, List<String>>> restoreCartFromHistory(
    List<dynamic> historicalItems,
    InventoryProvider invProv,
+   PromotionProvider promoProv,
    {bool clearPrevious = true}
  )
```

#### [MODIFY] [`sale_history_detail_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/sale_history_detail_screen.dart)

Actualizar las llamadas a `restoreCartFromHistory()` para pasar el `PromotionProvider`:
- Línea 186 (`_executeRestoreCart`): Agregar `promoProv` como argumento.
- Obtener el provider vía `Provider.of<PromotionProvider>(context, listen: false)`.

#### [MODIFY] [`sales_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/sales_service.dart)

En `getSaleDetail()`, líneas 396-415: El mapeo de items de venta **no está pasando `bundle_id`** al JSON de salida. Agregar:

```diff
  (e) => <String, dynamic>{
    'id': e['id'],
    'presentation_id': e['presentation_id'],
    'product_id': e['product_id'],
+   'bundle_id': e['bundle_id'],
    'quantity': e['cantidad'],
    ...
  }
```

Sin este campo, `restoreCartFromHistory()` nunca podrá saber que un ítem era un bundle.

#### Verificación
- Vender una oferta/paquete desde Caja Rápida.
- Ir al historial, abrir el recibo y pulsar "Volver a Vender".
- Verificar que la oferta se cargue correctamente en el carrito sin errores.

---

### Fase 3: Validación Pre-Checkout de Stock para Bundles

> Prioridad: **MEDIA** — La lógica de un-kitting funciona, pero se puede mejorar la UX.

#### [MODIFY] [`quick_checkout_modal.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/quick_sale/quick_checkout_modal.dart)

Antes de llamar `processCheckout`, agregar una validación preventiva que verifique que los bundles del carrito aún tengan stock suficiente en sus componentes. Esto evitaría que el error de "Stock insuficiente" surja dentro de la transacción SQL (lo cual da un mensaje técnico), y en su lugar mostrar un mensaje amigable al usuario antes de procesar.

#### Verificación
- Reducir manualmente el stock de un componente de una oferta.
- Intentar cobrar la oferta.
- Verificar que el error sea amigable y descriptivo.

---

### Fase 4: Rediseño UI con Slivers (Layout Retráctil)

> Prioridad: **MEJORA UX** — El carrito necesita más espacio vertical.

#### [MODIFY] [`quick_sale_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/quick_sale_screen.dart)

**Transformación del layout:**

1. Reemplazar `Column` del body por `CustomScrollView`.
2. Convertir `QuickSaleHeader` en un `SliverPersistentHeader` con:
   - `floating: true` → Se muestra al hacer scroll up.
   - `snap: true` → Efecto "spring" suave.
   - `pinned: false` → Se oculta completamente al scroll down.
3. La barra de búsqueda se mantiene fija como un `SliverAppBar` pinned (siempre visible).
4. La sección de ofertas y el carrito se renderizan como `SliverList` o `SliverToBoxAdapter`.
5. El footer de "TOTAL A COBRAR / COBRAR" permanece como `bottomNavigationBar` (fuera del scroll).

> [!WARNING]
> El `ReorderableListView.builder` actual no soporta Slivers nativamente. Se usará `SliverReorderableList` de Flutter como reemplazo directo para mantener la funcionalidad de drag-and-drop dentro del scroll unificado.

#### Verificación
- Abrir Caja Rápida con 5+ productos en el carrito.
- Verificar que al hacer scroll hacia abajo, la sección del cliente desaparezca.
- Verificar que un ligero scroll hacia arriba la traiga de vuelta.
- Verificar que la funcionalidad de reordenar (drag) siga funcionando.

---

## Resumen de Archivos a Modificar

| Fase | Archivo | Tipo de Cambio |
|------|---------|----------------|
| 1 | `quick_sale_provider.dart` | Fix asignación de `brand` |
| 2 | `quick_sale_provider.dart` | Refactor `restoreCartFromHistory` |
| 2 | `sales_service.dart` | Agregar `bundle_id` al mapeo de items |
| 2 | `sale_history_detail_screen.dart` | Pasar `PromotionProvider` |
| 3 | `quick_checkout_modal.dart` | Validación pre-checkout |
| 4 | `quick_sale_screen.dart` | Rediseño con `CustomScrollView` |

## Open Questions

> [!IMPORTANT]
> **Sobre el Bug 3 (Stock de Ofertas):** Mi análisis revela que la lógica de un-kitting **ya está implementada** en `sales_service.dart` (líneas 76-103). El stock de los componentes del bundle sí se descuenta correctamente dentro de la transacción. ¿Puedes confirmar que el bug que observaste ocurre al cobrar desde Caja Rápida? ¿O lo observaste desde otro flujo (ej. venta desde Cotización)? Si el bug persiste, necesitaría ver los logs del error exacto para identificar si hay un fallo en la consulta a `items_paquete`.
