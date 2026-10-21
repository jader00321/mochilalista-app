# PLAN MAESTRO: REDISEÑO DE TARJETAS DE INVENTARIO Y BLINDAJE 360° DE SINCRONIZACIÓN

**Documento de Trabajo y Especificación de Ingeniería**  
**Versión:** 1.0.0 — Nivel Producción "Mobile Awards"  
**Fecha:** Octubre 2026  
**Metodología:** Loop Autónomo + Árbitro Interno Adversarial  
**Estado:** PENDIENTE DE APROBACIÓN POR EL USUARIO (Fase de Planificación — Sin cambios de código aún)

---

## 1. INTRODUCCIÓN Y DIAGNÓSTICO FORENSE DE LAS 3 CAPTURAS

Tras la certificación exitosa de la **Parte 1** (Descuentos, Redondeo, Gestión de Precio y Filtro de Ofertas) y la **Parte 2** (Stock Inteligente por Unidad de Venta, Paridad en Modales de Venta y Pull-to-Refresh), se ha auditado la pestaña **`PRODUCTOS`** de la ventana **`Inventario` (`Gestión de Negocio`)** en sus 3 modalidades de visualización: **Lista Estándar**, **Cuadrícula / Grid** y **Lista Compacta**.

A partir de las 3 capturas reales proporcionadas por el usuario, se han identificado problemas de usabilidad (UX), riesgos operacionales de inventario, errores visuales de maquetación y desbordamientos horizontales:

```
+----------------------------------------------------------------------------------------------------+
|                                DIAGNÓSTICO FORENSE DE LAS 3 VISTAS                                |
+----------------------------------------------------------------------------------------------------+
| 1. VISTA LISTA ESTÁNDAR (Imagen 1):                                                                |
|    - Los botones rápidos [-] y [+] se encuentran en la esquina inferior derecha.                   |
|    - El botón [+] se DESBORDA fuera del borde derecho de la tarjeta en "Cartulina".               |
|    - Presionar [-] o [+] accidentalmente al hacer scroll genera descuadres no auditados en bodega. |
|    - El stock aparece en singular erróneo: "25 Unidad", "6 Unidad" (debe ser "25 Unidades").       |
|    - El recuadro de imagen muestra un fondo gris con ícono tachado y el texto "Sin imagen",       |
|      luciendo anticuado en comparación con los modernos avatares con iniciales de la app.         |
|    - El botón flotante [+] (FAB) cubre el precio y stock del último producto al final del scroll.  |
+----------------------------------------------------------------------------------------------------+
| 2. VISTA CUADRÍCULA / GRID (Imagen 2):                                                             |
|    - En tarjetas estrechas de 2 columnas (ej. "Cartulina"), el renglón inferior intenta meter      |
|      "S/ 0.61" y "25 Unidad" usando dos widgets Flexible que compiten por ancho horizontal.       |
|    - RESULTADO: El texto del stock se trunca con elipsis: "25 Unid...".                            |
|    - El placeholder gris "Sin imagen" resta elegancia visual a la cuadrícula.                      |
|    - El FAB flotante bloquea la interacción con la última tarjeta de la derecha.                   |
+----------------------------------------------------------------------------------------------------+
| 3. VISTA LISTA COMPACTA (Imagen 3):                                                                |
|    - Diseñada para escaneo veloz de cientos de productos, pero la columna derecha (110px) mete     |
|      Precio + Stock singular ("25 Unidad") + fila de botones [-] y [+].                            |
|    - Los botones ensucien la densidad visual, incrementan la altura de la fila y crean ruido.     |
|    - El FAB flotante cubre los botones del último producto listado.                               |
+----------------------------------------------------------------------------------------------------+
```

---

## 2. ARQUITECTURA DE SOLUCIÓN Y PRINCIPIOS DE DISEÑO

### 2.1. Erradicación Definitiva de los Botones `[-]` y `[+]`
* **Fundamento de Negocio:** El inventario no es un carrito de compras. Un incremento o decremento de stock físico requiere un proceso deliberado (recepción de guía de remisión, conteo físico, merma o ajuste). Los botones sueltos `[-]` y `[+]` en la tarjeta incitan a errores por toques accidentales durante el scroll táctil y no solicitan motivo de ajuste.
* **Solución:** Se eliminan por completo de las 3 vistas (`InventoryItemTile`, `InventoryGridCard`, `InventoryCompactTile`).
* **Nuevo Punto Único de Gestión:** El **Badge / Píldora de Stock** (ej. `[ 📦 25 Unidades ]`) pasa a ser interactivo. Al tocarlo, se abre directamente el modal inteligente y factor-aware **`Abastecer / Editar Stock`** (`QuickRestockModal` / `StockUpdateModal`), con auditoría y soporte de unidades de venta.

### 2.2. Pluralización Inteligente en Español y Factor de Empaque
* **Problema:** `InventoryWrapper.displayStockText` concatenaba `"$displayStock $unidad"`, generando `"25 Unidad"` o `"6 Unidad"`.
* **Solución:** Implementar un helper centralizado `StringFormatters.pluralizeUnit(String unit, int quantity)` que maneje reglas fonéticas del español:
  * Singular (`qty == 1`): `"1 Unidad"`, `"1 Par"`, `"1 Docena"`, `"1 Caja"`, `"1 Paquete"`.
  * Plural (`qty != 1`): `"25 Unidades"`, `"6 Unidades"`, `"28 Pares"`, `"3 Docenas"`, `"10 Cajas"`.
  * Terminación en 'z' -> 'ces' (`Lápiz` -> `Lápices`).
  * Terminación en consonante 'd', 'r', 'n', 'l', 'j' -> 'es' (`Unidad` -> `Unidades`, `Par` -> `Pares`).
  * Terminación en vocal o 'k' -> 's' (`Pack` -> `Packs`).
* **Factor Explícito:** Cuando la variante tenga `unidadesPorVenta > 1`, el chip de empaque mostrará el factor con claridad: `PAR · x2`, `DOCENA · x12`, `PACK · x6`. Si `unidadesPorVenta == 1`, mostrará `UNIDAD`.

### 2.3. Estandarización de 4 Zonas Táctiles por Tarjeta
Para maximizar la productividad y evitar colisiones de navegación:
1. **Toque General en la Tarjeta (`onTap`):** Navega con transición fluida y feedback táctil a **`Detalles de Producto`** (`ProductDetailScreen`).
2. **Toque en el Badge de Stock (`[ 📦 25 Unidades ]`):** Abre el modal **`Abastecer / Editar Stock`** (`QuickRestockModal` con paridad total en `StockUpdateModal`).
3. **Toque en el Precio (`S/ 0.61`):** Abre directamente el modal **`Gestionar Precio`** (`PriceUpdateModal`).
4. **Toque en Menú `⋮` o Pulsación Larga (`onLongPress`):** Despliega el menú de acciones del producto/variante (`ProductActionSheet`).

### 2.4. Evolución Visual del Placeholder "Sin imagen" a Smart Monogram Avatar
* `UniversalImage` ya cuenta con el generador `_buildSmartPlaceholder` (Mobile Awards: degradados semánticos por paleta determinística basada en hash del nombre, monograma tipográfico de iniciales y micro-icono vectorial de la categoría).
* Se asegurará que todas las tarjetas de inventario y carrito invoquen `UniversalImage` pasando correctamente `productName: product.nombre` y `categoryName: categoryName`, y que bajo ninguna circunstancia se renderice el recuadro gris plano con `"Sin imagen"`.

### 2.5. Corrección de Desbordamiento por Botón Flotante (FAB)
* En `products_tab.dart`, se establecerá un padding inferior uniforme en los slivers de las 3 vistas:
  * Lista Estándar: `padding: const EdgeInsets.only(top: 8, bottom: 96)`
  * Cuadrícula: `padding: const EdgeInsets.fromLTRB(16, 16, 16, 96)`
  * Lista Compacta: `padding: const EdgeInsets.only(bottom: 96)`
  Garantizando que al llegar al final del scroll, el último ítem quede completamente despejado por encima del FAB.

---

## 3. PLAN DE TRABAJO ESTRUCTURADO EN 6 FASES

```
+--------------------------------------------------------------------------------------------------------+
|                                    MAPA DE EJECUCIÓN DEL PLAN 360°                                     |
+--------------------------------------------------------------------------------------------------------+
| FASE 1: Rediseño Mobile Awards de las 3 Vistas de Tarjetas de Inventario                               |
|         (inventory_item_tile.dart, inventory_grid_card.dart, inventory_compact_tile.dart, wrapper)     |
+--------------------------------------------------------------------------------------------------------+
| FASE 2: Paridad Total de Modales de Stock (StockUpdateModal vs QuickRestockModal)                      |
|         (stock_update_modal.dart, product_action_sheet.dart)                                           |
+--------------------------------------------------------------------------------------------------------+
| FASE 3: Reflejo Visual de Ofertas y Descuentos en Carrito y "⚡ Vendidos Recientemente"                |
|         (quick_sale_cart_item.dart, manual_quote_item_card.dart, quick_sale_screen.dart)               |
+--------------------------------------------------------------------------------------------------------+
| FASE 4: Reactividad Inmediata en ProductDetailScreen y ProductDetailModal                             |
|         (product_detail_screen.dart, product_detail_financial_dashboard.dart, product_detail_modal.dart)|
+--------------------------------------------------------------------------------------------------------+
| FASE 5: Sincronización en Caliente de Buscadores (360° Cache Sync)                                     |
|         (quick_search_provider.dart, manual_quote_provider.dart, catalog_provider.dart)                |
+--------------------------------------------------------------------------------------------------------+
| FASE 6: Batería de Pruebas Automatizadas y Certificación Adversarial                                   |
|         (flutter test, flutter analyze lib test)                                                       |
+--------------------------------------------------------------------------------------------------------+
```

---

### FASE 1: REDISEÑO "MOBILE AWARDS" DE LAS 3 VISTAS DE TARJETAS DE INVENTARIO

#### 1.1. Pluralización y Factor en `InventoryWrapper` (`lib/features/catalog/models/inventory_wrapper.dart`)
* Agregar método helper estático o de instancia:
  ```dart
  static String pluralize(String unit, int qty) {
    if (qty == 1) return unit;
    final lower = unit.toLowerCase();
    if (lower.endsWith('z')) return "${unit.substring(0, unit.length - 1)}ces";
    if (lower.endsWith('d') || lower.endsWith('r') || lower.endsWith('n') || lower.endsWith('l') || lower.endsWith('j')) {
      return "${unit}es";
    }
    return "${unit}s";
  }
  ```
* Actualizar `displayStockText`:
  * Cuando `displayStock <= 0` -> `"Agotado"`
  * Cuando `displayStock == 1` -> `"1 $unidad"`
  * Cuando `displayStock > 1` -> `"$displayStock ${pluralize(unidad, displayStock)}"`
* Agregar getter `presentationFactorChip`:
  * Si `presentation.unidadesPorVenta > 1` -> `"${(presentation.unidadVenta ?? 'Unidad').toUpperCase()} · x${presentation.unidadesPorVenta}"`
  * Si es 1 o menor -> `(presentation.unidadVenta ?? 'Unidad').toUpperCase()`

#### 1.2. Rediseño de Vista Lista Estándar (`lib/core/widgets/inventory_item_tile.dart`)
* **Eliminar:** Los dos `InkWell` con `Icons.remove` e `Icons.add` que causaban el desbordamiento horizontal derecho.
* **Estructura Interna:**
  1. **Columna Izquierda (Imagen):** `Stack` con `UniversalImage` (Smart Avatar dinámico con iniciales y gradiente si no hay imagen física), badge de oferta `-X%` en esquina superior y velo oscuro con ícono si está agotado.
  2. **Columna Central / Derecha:**
     * **Fila Superior:** Marca en mayúsculas (o categoría si no hay marca) a la izquierda; a la derecha, badge sutil `PÚBLICO` / `PRIVADO` junto a botón sutil de opciones `⋮` (`IconButton` de 32x32 para abrir `ProductActionSheet`).
     * **Fila Media:** Título del producto (`product.nombre`) con peso tipográfico `FontWeight.w700`, nombre de la variante (`presentation.nombreEspecifico`), y el chip de empaque (`presentationFactorChip`).
     * **Fila Inferior:**
       * **A la izquierda:** Precio de venta. Si tiene oferta (`hasOffer == true`), mostrar precio original tachado en tamaño 12px + precio final destacado en tamaño 18px `FontWeight.w900` + badge semántico de descuento (`-X%`). Si no hay oferta, precio regular destacado. Al tocar esta zona del precio, se ejecuta `onTapPrice` abriendo `PriceUpdateModal`.
       * **A la derecha:** Badge de Stock Interactivo (`[ 📦 25 Unidades ]`). Al tocar esta píldora, se dispara `onTapStock` abriendo `QuickRestockModal` / `StockUpdateModal`. El badge tendrá color semántico (verde para óptimo, ámbar para stock bajo `<= 5`, rojo para agotado) y un micro-icono táctil discreto (`Icons.edit_note_rounded` o similar) que indique que es editable.
* **Zonas Táctiles:**
  * Tarjeta completa: `onTap` -> navega a `ProductDetailScreen`.
  * Precio: `onTapPrice` -> abre `PriceUpdateModal`.
  * Badge de Stock: `onTapStock` -> abre `QuickRestockModal`.
  * Botón `⋮` / `onLongPress`: abre `ProductActionSheet`.

#### 1.3. Rediseño de Vista Cuadrícula / Grid (`lib/core/widgets/inventory_grid_card.dart`)
* **Problema resuelto:** Truncamiento `"S/ 0.61  25 Unid..."`.
* **Solución de Maquetación Vertical:**
  1. Imagen superior con relación de aspecto equilibrada, punto de estado `PÚBLICO`/`PRIVADO` y badge `-X%` si hay oferta.
  2. Cuerpo de información:
     * Marca en tipografía mini (10px).
     * Nombre del producto (máx 2 líneas).
     * Nombre de variante + Chip de empaque (`PAR · x2`).
  3. **Pie de Tarjeta Reestructurado:**
     * **Línea de Precio:** Muestra el precio final completo (con precio tachado si hay oferta) en un renglón dedicado, evitando que compita horizontalmente con el stock. Al tocar el precio, abre `PriceUpdateModal`.
     * **Línea / Píldora de Stock:** Ubicada debajo del precio o en una píldora auto-ajustable con ícono de inventario `[ 📦 25 Unidades ]`. Garantiza 100% de visibilidad del texto sin jamás mostrar `...`. Al tocar el badge, abre `QuickRestockModal`.
* **Zonas Táctiles:**
  * Toque en tarjeta: `ProductDetailScreen`.
  * Toque en precio: `PriceUpdateModal`.
  * Toque en stock: `QuickRestockModal`.
  * LongPress: `ProductActionSheet`.

#### 1.4. Rediseño de Vista Lista Compacta (`lib/core/widgets/inventory_compact_tile.dart`)
* **Eliminar:** Los botones rápidos `[-]` y `[+]` de la columna derecha de 110px.
* **Nueva Distribución Ultra-Eficaz:**
  * **Columna Izquierda:** Indicador semántico circular + Título de producto + Marca en gris + Variante en teal + Chip de unidad/factor.
  * **Columna Derecha (Alineada):**
    * **Arriba:** Precio de venta formateado (con soporte de oferta si aplica). Al tocar, abre `PriceUpdateModal`.
    * **Abajo:** Píldora interactiva de stock (`25 Unidades` o `Agotado`) con color semántico. Al tocar, abre `QuickRestockModal`.
  * Altura de fila optimizada y limpia, permitiendo escanear decenas de ítems por segundo con 0 ruido visual.

#### 1.5. Espaciado Inferior y Despeje de FAB en `products_tab.dart`
* En `_buildSliverList`:
  * Para vista estándar, grid y compacta, fijar `SliverPadding(padding: EdgeInsets.only(bottom: 96))` o `110`.
  * De esta forma, el scroll permite que el último producto quede completamente visible por encima del botón flotante de agregar producto `[+]`.

---

### FASE 2: PARIDAD TOTAL DE MODALES DE STOCK (`StockUpdateModal` y `QuickRestockModal`)

#### 2.1. Diagnóstico de Paridad
* En la Parte 2 se construyó `QuickRestockModal` (`lib/features/catalog/widgets/quick_restock_modal.dart`), el cual cuenta con:
  1. Selector de modo: `[ 📦 Sumar Mercancía Recibida | ✏️ Fijar Stock Total Exacto ]`.
  2. Selector de granularidad factor-aware: `[ Por Par (x2) | Por Unidad base (x1) ]`.
  3. Botón de cuadratura rápida: `[ ⚡ Cuadrar ]`.
  4. Indicadores de unidades sueltas y auditoría.
* Sin embargo, `StockUpdateModal` (`lib/core/widgets/stock_update_modal.dart`) mantenía una interfaz más elemental sin selector de granularidad ni botón `[ ⚡ Cuadrar ]`.

#### 2.2. Estrategia de Unificación / Paridad
* **Opción de Oro (Arquitectura Limpia):** En `StockUpdateModal`, implementar el selector de granularidad `[ Por Unidad de Venta (xFactor) | Por Unidad Base (x1) ]` y el botón `[ ⚡ Cuadrar ]`, garantizando paridad 1:1.
* Alternativamente, hacer que el método estático `StockUpdateModal.show(...)` invoque internamente `QuickRestockModal` encapsulado o viceversa, asegurando una única fuente de verdad en la experiencia de usuario.
* Al tocar el Badge de Stock desde cualquiera de las 3 tarjetas de inventario (`InventoryItemTile`, `InventoryGridCard`, `InventoryCompactTile`), se abre el modal inteligente factor-aware, actualiza SQLite en tiempo real y refresca el catálogo en memoria.

---

### FASE 3: REFLEJO VISUAL DE OFERTAS Y DESCUENTOS EN CARRITO Y "⚡ VENDIDOS RECIENTEMENTE"

#### 3.1. Tarjeta del Carrito en Caja Rápida (`lib/features/smart_quotation/widgets/quick_sale/quick_sale_cart_item.dart`)
* **Problema actual:** Cuando un ítem tiene oferta de catálogo (`hasOffer == true`) o un descuento manual, se muestra el precio tachado y el precio efectivo, pero **no se muestra el badge con el porcentaje entero (`-X%`)**.
* **Solución:**
  * Calcular el porcentaje de descuento efectivo:
    ```dart
    final double baseSystemPrice = product.price;
    final bool isDiscounted = effectivePrice < (baseSystemPrice - 0.009);
    int discountPct = 0;
    if (isDiscounted && baseSystemPrice > 0) {
      discountPct = (((baseSystemPrice - effectivePrice) / baseSystemPrice) * 100).round();
    }
    ```
  * En la fila de precio unitario, si `isDiscounted && discountPct > 0`, mostrar junto al precio tachado un badge semántico compacto:
    ```dart
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: isDark ? Colors.red.withValues(alpha: 0.2) : Colors.red[50],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isDark ? Colors.red.withValues(alpha: 0.4) : Colors.red.shade300),
      ),
      child: Text(
        "-$discountPct%",
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.red[300] : Colors.red[800]),
      ),
    )
    ```
  * Prevenir desbordamientos utilizando un `Wrap` con espaciado controlado.

#### 3.2. Tarjeta del Carrito en Cotización Manual (`lib/features/smart_quotation/widgets/manual/manual_quote_item_card.dart`)
* Aplicar la misma solución:
  * Si `hasDiscount` (`manualPrice < item.price`), calcular `discountPct = (((item.price - manualPrice) / item.price) * 100).round()`.
  * Mostrar precio base tachado + precio vigente + badge semántico `-$discountPct%`.

#### 3.3. Chips de "⚡ Vendidos Recientemente" (`lib/features/smart_quotation/screens/quick_sale_screen.dart`)
* En los chips horizontales de productos vendidos recientemente:
  * Actualmente solo se muestra `S/ ${wrapper.effectivePrice.toStringAsFixed(2)}`.
  * Si `wrapper.hasOffer == true`, mostrar el precio tachado `S/ ${wrapper.presentation.precioVentaFinal.toStringAsFixed(2)}`, el precio de oferta `S/ ${wrapper.effectivePrice.toStringAsFixed(2)}` y un micro-badge `-X%`, atrayendo la atención del cajero hacia productos en promoción.

#### 3.4. Reactividad a 0ms al Editar desde "✏️ Editar Catálogo"
* Verificar que cuando el usuario entra al detalle del ítem en el carrito (`QuickSaleDetailModal` o `ManualQuoteDetailModal`), abre `PriceUpdateModal` o `StockUpdateModal`, modifica el precio o stock y guarda:
  * Las funciones `quickProv.syncItemPriceAndStock` y `widget.onCatalogUpdated` actualizan de inmediato el estado del ítem en memoria a 0ms sin requerir reiniciar la pantalla.

---

### FASE 4: REACTIVIDAD INMEDIATA EN `ProductDetailScreen` Y `ProductDetailModal`

#### 4.1. Reactividad en `lib/features/catalog/screens/product_detail_screen.dart`
* **Auditoría:** En `ProductDetailScreen`, los métodos `_openRestockModal` y `_openDiscountModal` abren `QuickRestockModal` y `DiscountIntelligentModal`.
* **Mejora:**
  * Al cerrarse cualquiera de estos modales (incluso mediante swipe-down o cierre estándar), ejecutar `_refreshData()` inmediatamente si hubo cambios o registrar un callback de retorno garantizado.
  * En `_refreshData()`, recargar la presentación actualizada desde SQLite (`fetchProductById` / `getFullProductWithFallback`), recalculando al instante:
    1. Stock visual en unidades de venta (`_selectedPresentation.stockActual ~/ factor`).
    2. Precio regular, precio tachado y precio efectivo.
    3. Badge de descuento entero (`-${_selectedPresentation.discountPercentRounded}%`).
    4. **Tarjeta de Información Financiera (`ProductDetailFinancialDashboard`):** Recalcular en tiempo real el costo de la presentación (`costoUnitarioCalculado`), la utilidad neta (`finalPrice - costoPresentacion`) y el porcentaje de margen comercial (`((finalPrice - costo) / finalPrice) * 100`).
* Añadir acceso a `PriceUpdateModal` desde la tarjeta de precio en el dashboard financiero para paridad completa.

#### 4.2. Reactividad en `lib/core/widgets/product_detail_modal.dart`
* En el modal de detalle del catálogo (`ProductDetailModal`), asegurar que las cantidades máximas de stock (`_maxStock`), el precio efectivo y el badge de ahorro se mantengan sincronizados con las presentaciones más frescas de SQLite.

---

### FASE 5: SINCRONIZACIÓN EN CALIENTE DE BUSCADORES (360° CACHE SYNC)

#### 5.1. Sincronización de `QuickSearchProvider` (`lib/features/smart_quotation/providers/quick_search_provider.dart`)
* Cuando un usuario actualiza el precio, oferta o stock de un producto en inventario o desde un modal:
  * Si `QuickSearchProvider` tiene resultados de búsqueda activos en memoria (`_searchResults.isNotEmpty`), los ítems correspondientes a esa presentación deben actualizar sus valores de stock y precio de inmediato, o invalidar la caché local ejecutando `refreshCurrentSearch()` para que la siguiente consulta no muestre datos obsoletos.
  * Implementar método `syncItem(int presentationId, {int? newStock, double? newPrice, double? newOfferPrice})` en `QuickSearchProvider`.

#### 5.2. Sincronización de `CatalogProvider` y `ManualQuoteProvider`
* `ManualQuoteProvider` (`lib/features/smart_quotation/providers/manual_quote_provider.dart`):
  * Agregar método de sincronización en memoria `syncItemPresentation(...)` o re-ejecutar `loadProducts(refresh: true)` cuando se regrese de una edición de catálogo en `CatalogSearchModal`.
* `CatalogProvider`:
  * Confirmar que `CatalogProvider.updatePresentationInCache(...)` refleje las modificaciones de inventario sin requerir pull-to-refresh forzado.

---

### FASE 6: BATERÍA DE PRUEBAS AUTOMATIZADAS Y CERTIFICACIÓN ADVERSARIAL

#### 6.1. Suite de Pruebas Unitarias y de Widgets
Se creará un archivo de prueba dedicado:
`app_movil/test/inventory_card_redesign_and_360_sync_test.dart`

Casos de prueba que certificarán la implementación:
1. **Test de Pluralización en Español y Factor de Empaque:**
   * Verificar que `InventoryWrapper.pluralize("Unidad", 1)` retorne `"Unidad"`.
   * Verificar que `InventoryWrapper.pluralize("Unidad", 25)` retorne `"Unidades"`.
   * Verificar que `InventoryWrapper.pluralize("Par", 2)` retorne `"Pares"`.
   * Verificar que `InventoryWrapper.pluralize("Lápiz", 5)` retorne `"Lápices"`.
   * Verificar que `InventoryWrapper.displayStockText` retorne `"25 Unidades"` y `"1 Unidad"`.
   * Verificar que el chip de empaque muestre `"PAR · x2"` cuando `unidadesPorVenta == 2`.
2. **Test de Erradicación de Steppers `[-]` y `[+]`:**
   * Renderizar `InventoryItemTile`: certificar que `Icons.remove` e `Icons.add` NO existan en el árbol de widgets.
   * Renderizar `InventoryGridCard`: certificar que no haya botones de incremento rápido y que el stock y precio no se trunquen.
   * Renderizar `InventoryCompactTile`: certificar que la fila no contenga botones `[-]` y `[+]`.
3. **Test de 4 Zonas Táctiles en `InventoryItemTile`:**
   * Tocar la tarjeta -> se llama al callback de navegación / `ProductDetailScreen`.
   * Tocar el badge de stock -> se llama al callback de abastecimiento / abre `QuickRestockModal`.
   * Tocar el precio -> se llama al callback de precio / abre `PriceUpdateModal`.
4. **Test de Reflejo Visual de Descuentos en Carrito (`QuickSaleCartItem` y `ManualQuoteItemCard`):**
   * Al recibir un producto con precio base 10.00 y precio efectivo 8.00 (descuento 20%):
     * Debe existir texto tachado `S/ 10.00`.
     * Debe existir texto vigente `S/ 8.00`.
     * Debe existir badge `-20%`.
5. **Test de Reactividad Financiera en `ProductDetailScreen`:**
   * Al actualizar costo o precio, certificar que el margen y la utilidad se recalculen sin error de división por cero.
6. **Test de Sincronización en Caliente en `QuickSearchProvider`:**
   * Modificar un producto y verificar que la lista de resultados de búsqueda refleje el nuevo precio y stock sin desfase.

#### 6.2. Criterios de Certificación Final
1. `flutter analyze lib test` -> **0 errores, 0 advertencias**.
2. `flutter test test/inventory_card_redesign_and_360_sync_test.dart` -> **100% pasando**.
3. Suite global de pruebas (`flutter test`) -> **100% pasando (más de 220 tests)**.

---

## 4. MATRIZ DE ARCHIVOS INVOLUCRADOS

| Archivo | Módulo / Ubicación | Rol en el Plan |
| :--- | :--- | :--- |
| `inventory_wrapper.dart` | `lib/features/catalog/models/` | Pluralización inteligente en español, chip de factor (`PAR · x2`), textos de stock limpios. |
| `inventory_item_tile.dart` | `lib/core/widgets/` | Eliminación de `[-]`/`[+]`, rediseño de jerarquía visual, badge de stock interactivo, 4 zonas táctiles. |
| `inventory_grid_card.dart` | `lib/core/widgets/` | Eliminación de truncamiento `"25 Unid..."`, precio y stock en renglones independientes, zonas táctiles. |
| `inventory_compact_tile.dart` | `lib/core/widgets/` | Eliminación de botones de ajuste, fila compacta para escaneo rápido, alineación de precio y stock. |
| `products_tab.dart` | `lib/features/catalog/screens/tabs/` | Configuración de callbacks para las 4 zonas táctiles, padding inferior `bottom: 96` para evitar solape con FAB. |
| `stock_update_modal.dart` | `lib/core/widgets/` | Paridad total con `QuickRestockModal`: selector de granularidad y botón `[ ⚡ Cuadrar ]`. |
| `quick_sale_cart_item.dart` | `lib/features/smart_quotation/widgets/quick_sale/` | Visualización de precio tachado, precio efectivo y badge de porcentaje entero `-X%`. |
| `manual_quote_item_card.dart` | `lib/features/smart_quotation/widgets/manual/` | Visualización de precio tachado, precio efectivo y badge `-X%` en cotización. |
| `quick_sale_screen.dart` | `lib/features/smart_quotation/screens/` | Chips de "⚡ Vendidos Recientemente" con precio tachado y badge de oferta activa. |
| `product_detail_screen.dart` | `lib/features/catalog/screens/` | Recarga inmediata en memoria (`_refreshData()`) al volver de modales de stock/precio/descuento. |
| `product_detail_financial_dashboard.dart` | `lib/features/catalog/widgets/detail/` | Recálculo en tiempo real de costo, utilidad neta y margen comercial. |
| `quick_search_provider.dart` | `lib/features/smart_quotation/providers/` | Sincronización en caliente de resultados de búsqueda ante cambios de inventario. |
| `manual_quote_provider.dart` | `lib/features/smart_quotation/providers/` | Sincronización en caliente del catálogo de búsqueda para cotizaciones. |
| `inventory_card_redesign_and_360_sync_test.dart` | `test/` | Batería de pruebas automatizadas y certificación integral. |

---

## 5. CONCLUSIÓN Y SIGUIENTE PASO

Este plan aborda exhaustivamente la eliminación de riesgos operativos en bodega, el rediseño estético y ergonómico de las 3 vistas de tarjetas de inventario ("Mobile Awards"), el reflejo transparente de ofertas y descuentos en los carritos de venta y la sincronización reactiva a 360° en toda la aplicación.

**IMPORTANTE:** Conforme a las instrucciones del usuario, **no se ha modificado ningún archivo de código** en esta etapa. El plan queda a la espera de la revisión y aprobación formal del usuario para proceder a la ejecución autónoma de las fases.
