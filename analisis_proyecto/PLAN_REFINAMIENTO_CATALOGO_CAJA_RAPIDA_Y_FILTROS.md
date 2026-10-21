# 🚀 PLAN DE TRABAJO: REFINAMIENTO INTEGRAL DEL CATÁLOGO, CAJA RÁPIDA, CARRITO Y FILTROS REACTIVOS

**Documento de Especificación, Arquitectura y Protocolo Adversarial**  
**Proyecto:** MochilaLista App (Local-First SQLite, 0ms Latency, Flutter)  
**Módulos Involucrados:** Catálogo (`catalog_screen.dart`, `catalog_item_card.dart`), Caja Rápida (`quick_sale_screen.dart`, `quick_sale_note_modal.dart`), Modales de Carrito / Lista (`catalog_cart_modal.dart`), Modales y Barras de Filtros (`live_filter_bottom_sheet.dart`, `filter_drawer.dart`, `catalog_header.dart`, `custom_search_bar.dart`), Repositorios y Modelos (`product_repository.dart`, `inventory_wrapper.dart`, `catalog_provider.dart`, `inventory_provider.dart`, `quick_search_provider.dart`).  
**Fecha:** Octubre 2026  
**Metodología:** Loop Autónomo + Árbitro Adversarial Estricto  

---

## 📸 1. ANÁLISIS FORENSE DE LAS 5 CAPTURAS Y DIAGNÓSTICO DEL SISTEMA

Tras una inspección minuciosa de los archivos de código y las 5 capturas proporcionadas por el usuario, se han identificado los siguientes cuellos de botella y fallas:

| Captura | Pantalla | Diagnóstico del Problema | Causa Raíz en Código |
| :--- | :--- | :--- | :--- |
| **Imagen 1** (`media_1792444723733.jpg`) | **Catálogo (Grid)** | 1. Títulos largos (ej. *"Shampoo Romero Anticaída Sachet 12x15ml..."*) se truncan abruptamente.<br>2. Se listan píldoras de variante duplicadas (`[UNIDAD] [UNIDAD]`) que confunden al comerciante.<br>3. Los datos financieros (`C: S/ 0.77 · G: S/ 0.23 · +23%`) tienen letra diminuta (`9.5pt`) ilegible. | `catalog_item_card.dart`:<br>- Línea 167: `RichText(maxLines: 2)`.<br>- Líneas 187-229: `ListView.separated` innecesario porque cada presentación ya es un ítem independiente en `displayItems`.<br>- Líneas 285, 307, 328: Fuentes forzadas a `9.5` en una sola fila apretada. |
| **Imagen 2** (`media_1792444807545.jpg`) | **Catálogo de Ventas** | 1. El carrusel de categorías superior solo muestra `"Todas"` y `"abarrotes"`. No permite aislar productos sin categoría.<br>2. Tarjetas con nombres largos de agua y refrescos con el nombre de presentación truncado. | `catalog_header.dart` y `live_filter_bottom_sheet.dart` no ofrecen el filtro `[ Sin Categoría ]` ni `[ Sin Marca ]`. |
| **Imagen 3** (`media_1792444816293.jpg`) | **Caja Rápida (Nota de Venta)** | Las etiquetas rápidas (`"Entrega pendiente"`, `"Envío a domicilio"`, etc.) se muestran en un `Wrap` que ocupa 4 filas verticales masivas, empujando el campo de texto hacia abajo y creando un modal gigante que choca con el teclado. | `quick_sale_note_modal.dart`:<br>Línea 224: `Wrap(spacing: 8, runSpacing: 8, children: _quickChips.map(...))` en lugar de un `SingleChildScrollView(scrollDirection: Axis.horizontal)`. |
| **Imagen 4** (`media_1792444836912.jpg`) | **Modal Mi Lista de Útiles / Carrito** | El título `"Shampoo Limpieza Renovadora 12x18..."` se corta a las 2 líneas, impidiendo ver la presentación o especificación completa del producto antes de cotizar. | `catalog_cart_modal.dart`:<br>Línea 172: `RichText(maxLines: 2, overflow: TextOverflow.ellipsis)`. |
| **Imagen 5** (`media_1792444899256.jpg`) | **Caja Rápida (Resultados)** | En la barra de categorías de Caja Rápida solo se listan categorías existentes. Si hay productos creados sin categoría asignada, quedan ocultos o inaccesibles por filtro. | `quick_sale_screen.dart` y `quick_search_provider.dart` solo iteran `searchProv.categories` sin evaluar huérfanos. |

---

## 🎯 2. OBJETIVOS ARQUITECTURALES DEL REFINAMIENTO

1. **Legibilidad Visual Superior (Estándar Mobile Awards):** Dar hasta 3 líneas completas al nombre y especificación del producto en tarjetas de catálogo y modales de carrito, garantizando fuentes cómodas y tipografía nítida sin compresión artificial.
2. **Eliminación de Redundancia en Variantes:** Cada presentación en la cuadrícula del Catálogo es un ítem autónomo; se elimina el carrusel interno redundante de variantes en la tarjeta y se conserva una etiqueta limpia de unidad y el botón rápido `+`.
3. **Métricas Financieras Dignificadas:** Restablecer un tamaño de fuente legible (11 - 11.5pt) para Costo, Margen y Ganancia, redistribuyéndolos en 2 líneas limpias o micro-píldoras ejecutivas con auto-escalado seguro `FittedBox`.
4. **Filtro Inteligente de Huérfanos Condicional (`[ Sin Categoría ]`, `[ Sin Marca ]`):** Añadir la capacidad de filtrar elementos sin categoría y sin marca en el Catálogo, Filtro Reactivo, Caja Rápida e Inventario, **únicamente si existen productos huérfanos en la base de datos**.
5. **Activación Real y Auditoría del Filtro "Solo Ofertas":** Normalizar la evaluación de ofertas en SQLite y en memoria para que cubra descuentos directos (`precio_oferta`), descuentos por porcentaje/monto (`tipo_descuento`, `valor_descuento`) y promociones/bundles asociados.
6. **Modal de Nota de Venta Compacto y Ergonómico:** Retornar a una fila fluida con scroll horizontal para las etiquetas rápidas en Caja Rápida, reduciendo drásticamente la altura del modal.
7. **Cero Regresiones y Resiliencia Local-First (0ms):** Preservar la reactividad inmediata contra SQLite, sin tiempos de espera, sin saltos de layout ni errores de desbordamiento `RenderFlex`.

---

## 🏗️ 3. PLAN DE EJECUCIÓN DIVIDIDO EN 5 FASES

```mermaid
flowchart TD
    subgraph FASE 1: Rediseño de Tarjetas y Carrito
        F1_1[3 Líneas para Nombres Largos] --> F1_2[Eliminar Selectores de Variante Redundantes]
        F1_2 --> F1_3[Restructurar Métricas Financieras en 2 Líneas]
        F1_3 --> F1_4[Modales de Carrito a 3 Líneas]
        F1_4 --> F1_5[Calibrar childAspectRatio en GridView]
    end

    subgraph FASE 2: Filtros de Huérfanos Condicionales
        F2_1[Conteo SQLite de Huérfanos <1ms] --> F2_2[Soporte ID 0 en Repositorio y Queries]
        F2_2 --> F2_3[Exponer hasOrphans en Providers]
        F2_3 --> F2_4[Chips Sin Categoría y Sin Marca en UI]
    end

    subgraph FASE 3: Filtro Solo Ofertas Real
        F3_1[Auditoría en InventoryWrapper y Modelo] --> F3_2[Query SQLite Inclusiva pr.precio_oferta y descuentos]
        F3_2 --> F3_3[Normalizar llaves has_offer y hasOffer]
        F3_3 --> F3_4[Reactividad en LiveFilterBottomSheet]
    end

    subgraph FASE 4: Modal Nota de Venta Compacto
        F4_1[Reemplazar Wrap por Row Horizontal] --> F4_2[Reducción de Altura y Padding]
        F4_2 --> F4_3[Blindaje Teclado e Insets]
    end

    subgraph FASE 5: Auditoría y Árbitro Adversarial
        FA_1[Pruebas Layout 360dp a 450dp] --> FA_2[Auditoría Modo Oscuro / Claro]
        FA_2 --> FA_3[dart analyze y flutter test 100% Pass]
    end

    FASE 1 --> FASE 2 --> FASE 3 --> FASE 4 --> FASE 5
```

---

### FASE 1: REDISEÑO ERGONÓMICO DE TARJETAS DEL CATÁLOGO (`CatalogItemCard`) Y MODALES DE CARRITO (`CatalogCartModal`)

#### 1.1 Archivos a Modificar
* `app_movil/lib/core/widgets/catalog_item_card.dart`
* `app_movil/lib/core/widgets/catalog_cart_modal.dart`
* `app_movil/lib/features/catalog/screens/catalog/catalog_screen.dart`
* `app_movil/lib/features/smart_quotation/widgets/quick_sale/quick_search_result_tile.dart`
* `app_movil/lib/features/smart_quotation/widgets/quick_sale/quick_sale_cart_item.dart`

#### 1.2 Cambios Específicos
1. **Espacio para 3 Líneas en `CatalogItemCard`:**
   * Modificar el `RichText` del título para configurar `maxLines: 3, overflow: TextOverflow.ellipsis`.
   * Mantener el tamaño de fuente en `13.5` a `14.0` con `height: 1.2` para máxima legibilidad tanto del nombre base como del `nombreEspecifico` (color teal acentuado).
2. **Eliminación Total del Selector Interno de Variantes:**
   * Remover el bloque `if (hasMultiplePresentations) SizedBox(height: 24, child: ListView.separated(...))` de `catalog_item_card.dart`.
   * En su lugar, mostrar de forma limpia y estilizada la insignia de la unidad de venta actual (`salesUnitBadge.toUpperCase()`) en un `Container` compacto con micro-bordes redondeados y fondo azul sutil.
   * Esto libera más de 28px de altura vertical en la tarjeta, permitiendo que las 3 líneas de texto y las métricas financieras convivan sin apretujarse.
3. **Reestructuración de Datos Financieros (Costo, Margen, Ganancia):**
   * Reemplazar la diminuta fila horizontal comprimida (`fontSize: 9.5`) por una estructura limpia de **dos micro-líneas ejecutivas** con tipografía estándar (`11.0` - `11.5pt`):
     * **Línea Superior:** Costo de la presentación (`C: S/ 0.77` o `Sin costo`) con indicador de estado (punto circular verde/ámbar/gris).
     * **Línea Inferior:** Ganancia neta y Margen porcentual (`G: S/ 0.23 · +23%`), destacando el porcentaje con color según rentabilidad (verde $\ge 30\%$, ámbar $\ge 15\%$, rojo $< 15\%$).
   * Envolver ambas líneas en `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft)` para garantizar blindaje total contra desbordamientos en pantallas pequeñas.
4. **Espacio de 3 Líneas en `CatalogCartModal`:**
   * En `catalog_cart_modal.dart`, actualizar el `RichText` del producto a `maxLines: 3` (reemplazando `maxLines: 2`).
   * Configurar `CrossAxisAlignment.start` en la fila del ítem para que la miniatura de la imagen quede alineada con la parte superior del texto de 3 líneas.
5. **Separación Horizontal y 3 Líneas en Caja Rápida:**
   * En `quick_search_result_tile.dart`, permitir hasta 3 líneas en el bloque de producto y presentación, y añadir `SizedBox(width: 12)` entre la columna de información y la columna derecha de precio/stock para evitar colisiones visuales.
   * En `quick_sale_cart_item.dart`, expandir a 3 líneas completas para el nombre del producto y presentación.
6. **Ajuste de Proporción y Blindaje de Altura en GridView (`catalog_screen.dart`):**
   * Calibrar el `childAspectRatio` del `SliverGridDelegateWithFixedCrossAxisCount` a `0.60` (o factor dinámico) para proporcionar el espacio vertical exacto que requieren las 3 líneas y las métricas financieras tanto en Modo Comerciante como en Modo Tienda, garantizando **cero errores de `RenderFlex overflow`**.

---

### FASE 2: MOTOR Y UI DE FILTROS PARA ELEMENTOS SIN CATEGORÍA Y SIN MARCA

#### 2.1 Archivos a Modificar
* `app_movil/lib/features/catalog/repositories/product_repository.dart`
* `app_movil/lib/features/catalog/services/product_service.dart`
* `app_movil/lib/features/catalog/providers/catalog_provider.dart`
* `app_movil/lib/features/catalog/providers/inventory_provider.dart`
* `app_movil/lib/features/smart_quotation/providers/quick_search_provider.dart`
* `app_movil/lib/core/widgets/catalog_header.dart`
* `app_movil/lib/core/widgets/live_filter_bottom_sheet.dart`
* `app_movil/lib/core/widgets/filter_drawer.dart`
* `app_movil/lib/features/smart_quotation/screens/quick_sale_screen.dart`
* `app_movil/lib/core/widgets/custom_search_bar.dart`

#### 2.2 Cambios Específicos
1. **Detección Rápida de Huérfanos en SQLite (< 1ms) con Esquema Blindado:**
   * La tabla `productos` no posee columna `activo` (esta reside en `presentaciones_producto`). Por ende, se implementa en `ProductRepository` la consulta optimizada con `INNER JOIN` y `COUNT(DISTINCT)`:
     ```sql
     SELECT 
       COUNT(DISTINCT CASE WHEN (p.categoria_id IS NULL OR p.categoria_id = 0) THEN p.id END) as orphan_categories,
       COUNT(DISTINCT CASE WHEN (p.marca_id IS NULL OR p.marca_id = 0) THEN p.id END) as orphan_brands
     FROM productos p
     INNER JOIN presentaciones_producto pr ON pr.producto_id = p.id
     WHERE p.negocio_id = ? AND pr.activo = 1;
     ```
   * En el caso del Catálogo público, se puede añadir condicionalmente `AND pr.estado = 'publico'`.
   * Los contadores de huérfanos se recalculan automáticamente cada vez que se recarga el inventario o catálogo, o cuando se crea/edita/elimina un producto.
   * Exponer en `CatalogProvider`, `InventoryProvider` y `QuickSearchProvider` los getters:
     * `bool get hasOrphanCategories => _orphanCategoriesCount > 0;`
     * `bool get hasOrphanBrands => _orphanBrandsCount > 0;`
2. **Soporte de ID Centinela `0` en Consultas SQL:**
   * En `ProductRepository.fetchInventoryRaw` y `countInventoryRaw`:
     * Cuando `category_ids` contiene `0`:
       Si solo contiene `0`: agregar `AND (p.categoria_id IS NULL OR p.categoria_id = 0)`.
       Si contiene `0` y otros IDs reales: agregar `AND (p.categoria_id IS NULL OR p.categoria_id = 0 OR p.categoria_id IN (...ids...))`.
     * Cuando `brand_ids` contiene `0`:
       Si solo contiene `0`: agregar `AND (p.marca_id IS NULL OR p.marca_id = 0)`.
       Si contiene `0` y otros IDs reales: agregar `AND (p.marca_id IS NULL OR p.marca_id = 0 OR p.marca_id IN (...ids...))`.
3. **Despliegue Condicional en UI (Solo si existen huérfanos):**
   * **`catalog_header.dart` (Barra superior de Catálogo):**
     * Si `provider.hasOrphanCategories == true`, renderizar justo después de `"Todas"` el chip `[ Sin Categoría ]` (ID: `0`). Si es seleccionado, filtra exclusivamente los productos sin categoría.
   * **`live_filter_bottom_sheet.dart` (Modal de Filtros de Catálogo):**
     * En el acordeón de **Categorías**, si `catProv.hasOrphanCategories == true`, agregar como primer chip `[ Sin Categoría ]`.
     * En el acordeón de **Marcas**, si `catProv.hasOrphanBrands == true`, agregar como primer chip `[ Sin Marca ]`.
     * Actualizar `_calculateLiveCount` para que evalúe correctamente cuando `_selectedCategoryIds.contains(0)` (`w.product.categoriaId == null || w.product.categoriaId == 0`) y cuando `_selectedBrandIds.contains(0)` (`w.product.marcaId == null || w.product.marcaId == 0`).
   * **`quick_sale_screen.dart` (Caja Rápida):**
     * En el carrusel horizontal de categorías, si `searchProv.hasOrphanCategories == true`, renderizar el chip `[ Sin Categoría ]` con ID `0`.
   * **`filter_drawer.dart` (Filtro de Inventario):**
     * En acordeón de Categorías: chip `[ Sin Categoría ]` si `provider.hasOrphanCategories`.
     * En acordeón de Marcas: chip `[ Sin Marca ]` si `provider.hasOrphanBrands`.
   * **`custom_search_bar.dart` (Pestaña Productos):**
     * En el carrusel horizontal: chip `[ Sin Categoría ]` si `provider.hasOrphanCategories`.

---

### FASE 3: CORRECCIÓN Y ACTIVACIÓN REAL DEL FILTRO "SOLO OFERTAS"

#### 3.1 Archivos a Modificar
* `app_movil/lib/features/catalog/models/inventory_wrapper.dart`
* `app_movil/lib/features/catalog/repositories/product_repository.dart`
* `app_movil/lib/core/widgets/live_filter_bottom_sheet.dart`
* `app_movil/lib/core/widgets/filter_drawer.dart`
* `app_movil/lib/features/catalog/providers/catalog_provider.dart`
* `app_movil/lib/features/catalog/providers/inventory_provider.dart`
* `app_movil/lib/core/widgets/catalog_item_card.dart`

#### 3.2 Cambios Específicos
1. **Unificación y Paridad 100% de `hasOffer` y `effectivePrice` en Dominio (`InventoryWrapper`):**
   * Validar que cuando exista `valorDescuento > 0`, el descuento esté realmente activo:
     ```dart
     bool get hasOffer {
       final hasPromoPrice = presentation.precioOferta != null && 
                             presentation.precioOferta! > 0 && 
                             presentation.precioOferta! < presentation.precioVentaFinal;
       final hasActiveDiscount = presentation.valorDescuento != null && 
                                presentation.valorDescuento! > 0 &&
                                presentation.tipoDescuento != null &&
                                presentation.tipoDescuento!.isNotEmpty &&
                                presentation.tipoDescuento != 'ninguno';
       return hasPromoPrice || hasActiveDiscount;
     }
     ```
   * En `effectivePrice`, calcular el precio con descuento cuando `hasOffer` sea verdadero por `valorDescuento` (porcentaje o monto fijo).
   * En `CatalogItemCard`, reflejar visualmente el precio de oferta tachado y el precio efectivo cuando `item.hasOffer` sea verdadero (cubriendo tanto `precioOferta` como `valorDescuento`).
2. **Evaluación de Ofertas en `ProductRepository`:**
   * En `fetchInventoryRaw` y `countInventoryRaw`, actualizar la cláusula SQL cuando `queryParams['has_offer'] == 'true'` para mantener paridad 100% con memoria:
     ```sql
     AND (
       (pr.precio_oferta IS NOT NULL AND pr.precio_oferta > 0 AND pr.precio_oferta < pr.precio_venta_final)
       OR (pr.valor_descuento IS NOT NULL AND pr.valor_descuento > 0 AND pr.tipo_descuento IS NOT NULL AND pr.tipo_descuento != '' AND pr.tipo_descuento != 'ninguno')
       OR (pr.id IN (SELECT rp.presentacion_id FROM reglas_promocion rp INNER JOIN campanas_promocionales cp ON rp.campana_id = cp.id WHERE cp.activo = 1))
       OR (pr.id IN (SELECT bi.presentacion_id FROM bundle_items bi INNER JOIN bundles_promocionales bp ON bi.bundle_id = bp.id WHERE bp.activo = 1))
     )
     ```
3. **Normalización de Claves entre Filtros y Providers:**
   * `FilterDrawer` enviaba `'hasOffer'`, mientras que `LiveFilterBottomSheet` enviaba `'has_offer'`.
   * En `InventoryProvider` y `CatalogProvider`, aceptar indistintamente ambas claves (`filters['has_offer'] ?? filters['hasOffer']`) y mapearlas consistentemente hacia `queryParams['has_offer'] = 'true'`.
4. **Corrección de Conteo en Vivo en `LiveFilterBottomSheet`:**
   * En `_calculateLiveCount`, reemplazar la evaluación manual por `if (_onlyOffers && !w.hasOffer) return false;`.

---

### FASE 4: REDISEÑO COMPACTO DEL MODAL DE NOTA DE VENTA EN CAJA RÁPIDA (`QuickSaleNoteModal`)

#### 4.1 Archivos a Modificar
* `app_movil/lib/features/smart_quotation/widgets/quick_sale/quick_sale_note_modal.dart`

#### 4.2 Cambios Específicos
1. **Sustitución de `Wrap` por Fila con Scroll Horizontal:**
   * Reemplazar el `Wrap(spacing: 8, runSpacing: 8, children: ...)` por:
     ```dart
     SingleChildScrollView(
       scrollDirection: Axis.horizontal,
       physics: const BouncingScrollPhysics(),
       padding: const EdgeInsets.symmetric(horizontal: 2),
       child: Row(
         children: _quickChips.map((chipText) {
           return Padding(
             padding: const EdgeInsets.only(right: 8.0),
             child: FilterChip(...),
           );
         }).toList(),
       ),
     )
     ```
2. **Optimización de Espaciado y Altura:**
   * Reducir márgenes verticales excesivos entre el encabezado, las etiquetas y el campo de texto.
   * Conseguir que el modal ocupe menos de la mitad de la pantalla, dejando visibilidad completa y permitiendo que al abrirse el teclado virtual el campo de texto permanezca perfectamente enfocado sin saltos bruscos ni desbordamientos (`resizeToAvoidBottomInset`).

---

### FASE 5: AUDITORÍA VISUAL Y FUNCIONAL PERIFÉRICA, CASOS BORDE Y VALIDACIÓN ADVERSARIAL

#### 5.1 Áreas Periféricas Auditadas
1. **Caja Rápida (`quick_search_result_tile.dart` y `quick_sale_cart_item.dart`):**
   * Verificar que los nombres de productos de hasta 3 líneas se muestren sin cortes abruptos ni colisiones con los indicadores de stock o precios.
2. **Pestañas de Inventario:**
   * Verificar que al filtrar por `[ Sin Categoría ]` en la pestaña de productos, la lista responda al instante (0ms) mostrando solo aquellos con `categoria_id == null || categoria_id == 0`.
3. **Modo Tienda vs Modo Comerciante:**
   * Confirmar que al activar el `Modo Tienda` (ocultar costos y ganancias para el cliente), las métricas financieras de 2 líneas desaparezcan limpiamente con animación fluida `AnimatedSwitcher` y sin deformar la altura de la tarjeta.
4. **Validación de Compilación y Calidad:**
   * `dart analyze lib test` con **0 errores y 0 advertencias**.
   * Ejecución exitosa de la suite completa de pruebas unitarias (`flutter test`).

---

## ⚖️ 4. PROTOCOLO DEL ÁRBITRO ADVERSARIAL: CASOS DE PRUEBA Y CRITERIOS DE ACEPTACIÓN

Durante la ejecución en loop autónomo, el **Árbitro Adversarial** someterá cada fase a pruebas rigurosas. Ninguna fase se dará por concluida sin superar al 100% sus criterios de aceptación:

### Prueba Adversarial 1: Nombres Extra Largos y Comportamiento Tipográfico
* **Acción:** Cargar productos con nombres extensos (ej. *"Shampoo Romero Anticaída Sachet 12x15ml Tratamiento Capilar Reparador"*).
* **Exigencia del Árbitro:**
  * Debe renderizar hasta 3 líneas completas de texto sin puntos suspensivos prematuros en la línea 1 o 2.
  * El tamaño de fuente debe ser normal y legible (`13.5` - `14.0`), sin encoger la letra de forma microscópica.
  * No debe haber error de `RenderFlex overflowed by X pixels`.

### Prueba Adversarial 2: Desaparición de Variantes Duplicadas y Claridad Financiera
* **Acción:** Inspeccionar un producto con múltiples presentaciones en el Catálogo.
* **Exigencia del Árbitro:**
  * En la tarjeta NO debe figurar ningún selector o lista de botones `[UNIDAD] [UNIDAD]`.
  * La tarjeta debe mostrar únicamente la insignia de su unidad/presentación actual.
  * Los datos de Costo, Margen y Ganancia deben presentarse claramente distribuidos en 2 micro-líneas con tamaño de fuente $\ge 11\text{pt}$ y auto-escalado `FittedBox`.

### Prueba Adversarial 3: Aparición Condicional de Huérfanos
* **Acción:**
  * **Caso A:** Base de datos con al menos 1 producto sin categoría y 1 sin marca $\rightarrow$ Deben aparecer los chips `[ Sin Categoría ]` y `[ Sin Marca ]` en Catálogo, Filtros Reactivos, Caja Rápida e Inventario. Al seleccionarlos, la cuadrícula debe listar con precisión quirúrgica dichos productos.
  * **Caso B:** Base de datos donde todos los productos tienen categoría y marca asignada $\rightarrow$ Los chips `[ Sin Categoría ]` y `[ Sin Marca ]` **NO deben mostrarse en ninguna pantalla**, evitando confundir al usuario.

### Prueba Adversarial 4: Exactitud Quirúrgica del Filtro "Solo Ofertas"
* **Acción:** Activar el switch o chip `"Solo ofertas"` en `LiveFilterBottomSheet` y en `FilterDrawer`.
* **Exigencia del Árbitro:**
  * El contador reactivo del botón `"Ver X Resultados"` debe coincidir exactamente con el número de variantes que tienen una oferta activa real.
  * Al aplicar el filtro, la cuadrícula NO debe mostrar ningún producto cuyo precio de oferta sea nulo o igual al precio original.
  * Deben incluirse variantes con descuentos por porcentaje o monto fijo (`valor_descuento > 0`).

### Prueba Adversarial 5: Modal de Nota de Venta Ultra-Compacto
* **Acción:** Abrir el modal `"Nota de Venta"` desde el icono de notas de la barra superior de Caja Rápida.
* **Exigencia del Árbitro:**
  * Las etiquetas rápidas deben residir en una **única fila horizontal deslizable**.
  * El modal debe reducir su ocupación de pantalla significativamente respecto a la versión anterior.
  * Al tocar el campo de texto y desplegarse el teclado virtual, no debe haber ningún error de desbordamiento ni recorte de botones.

---

## 📌 5. MATRIZ DE ARCHIVOS IMPACTADOS Y RESPONSABILIDADES

| Archivo | Fase | Responsabilidad |
| :--- | :---: | :--- |
| `lib/core/widgets/catalog_item_card.dart` | 1 | 3 líneas de título, eliminación de selectores internos de variante, métricas financieras a 2 líneas legibles. |
| `lib/core/widgets/catalog_cart_modal.dart` | 1 | 3 líneas de título para ítems en Carrito y Lista de Útiles. |
| `lib/features/catalog/screens/catalog/catalog_screen.dart` | 1 | Calibración de `childAspectRatio` en el GridView del catálogo. |
| `lib/features/catalog/repositories/product_repository.dart` | 2, 3 | Soporte SQL de huérfanos (ID `0`) y query inclusiva para `has_offer`. |
| `lib/features/catalog/providers/catalog_provider.dart` | 2, 3 | Detección de huérfanos (`hasOrphanCategories`), filtrado unificado de ofertas. |
| `lib/features/catalog/providers/inventory_provider.dart` | 2, 3 | Detección de huérfanos (`hasOrphanCategories`, `hasOrphanBrands`), normalización de `has_offer`. |
| `lib/features/smart_quotation/providers/quick_search_provider.dart` | 2 | Detección y filtrado de huérfanos en Caja Rápida. |
| `lib/core/widgets/catalog_header.dart` | 2 | Chip condicional `[ Sin Categoría ]` en el carrusel superior. |
| `lib/core/widgets/live_filter_bottom_sheet.dart` | 2, 3 | Chips condicionales `[ Sin Categoría ]` y `[ Sin Marca ]`, conteo reactivo y filtrado real de ofertas. |
| `lib/core/widgets/filter_drawer.dart` | 2, 3 | Chips condicionales de huérfanos en acordeones, compatibilidad con `has_offer`. |
| `lib/features/smart_quotation/screens/quick_sale_screen.dart` | 2 | Chip condicional `[ Sin Categoría ]` en barra de categorías de Caja Rápida. |
| `lib/core/widgets/custom_search_bar.dart` | 2 | Chip condicional `[ Sin Categoría ]` en pestaña de productos. |
| `lib/features/catalog/models/inventory_wrapper.dart` | 3 | Flag `hasOffer` y getter `effectivePrice` unificados con `valorDescuento`. |
| `lib/features/smart_quotation/widgets/quick_sale/quick_sale_note_modal.dart` | 4 | Fila horizontal con scroll (`SingleChildScrollView`) para etiquetas rápidas y reducción de altura. |
| `lib/features/smart_quotation/widgets/quick_sale/quick_search_result_tile.dart` | 5 | Auditoría de nombres largos y compatibilidad de diseño. |
| `lib/features/smart_quotation/widgets/quick_sale/quick_sale_cart_item.dart` | 5 | Auditoría de nombres largos en carrito de caja rápida. |

---

## 🏁 6. DEFINICIÓN DE TERMINADO (DoD)
1. Documento de Plan aprobado por el usuario.
2. Implementación de las 5 Fases sin omitir ningún archivo ni detalle arquitectural.
3. Superación de todas las pruebas adversariales del Árbitro.
4. `dart analyze lib test` ejecutado sin advertencias ni errores (0 issues).
5. Suite de pruebas `flutter test` pasando al 100%.
