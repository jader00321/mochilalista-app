# 🚀 PLAN MAESTRO DE TRABAJO (PARTE 1): DESCUENTOS, REDONDEO DE OFERTAS, GESTIONAR PRECIO Y FILTRO DE OFERTAS

**Documento de Especificación Técnica, Diagnóstico Forense y Protocolo Adversarial**  
**Proyecto:** MochilaLista App (Local-First SQLite, 0ms Latency, Flutter)  
**Módulos Involucrados:** 
- **Edición / Creación de Producto:** `ProductPresentationCard` (`product_presentation_card.dart`), `PresentationPricingSection` (`presentation_pricing_section.dart`), `PresentationDiscountSection` (`presentation_discount_section.dart`), `PresentationMathEngine` (`presentation_math_engine.dart`), `ProductFormMapper` (`product_form_mapper.dart`), `ProductCreateOperations` (`product_create_operations.dart`), `ProductEditOperations` (`product_edit_operations.dart`).
- **Modales de Precio y Descuento:** `PriceUpdateModal` (`price_update_modal.dart`), `DiscountIntelligentModal` (`discount_intelligent_modal.dart`), `InteractiveSheetWrapper` (`interactive_sheet_wrapper.dart`).
- **Catálogo e Inventario:** `ProductRepository` (`product_repository.dart`), `ProductService` (`product_service.dart`), `CatalogProvider` (`catalog_provider.dart`), `InventoryProvider` (`inventory_provider.dart`), `LiveFilterBottomSheet` (`live_filter_bottom_sheet.dart`), `FilterDrawer` (`filter_drawer.dart`).
- **Modelos y Visualización:** `ProductPresentation` (`product_model.dart`), `InventoryWrapper` (`inventory_wrapper.dart`), `CatalogItemCard` (`catalog_item_card.dart`), `InventoryItemTile` (`inventory_item_tile.dart`), `ProductDetailModal` (`product_detail_modal.dart`), `ProductDetailScreen` (`product_detail_screen.dart`).
**Fecha:** Octubre 2026  
**Metodología:** Loop Autónomo + Árbitro Adversarial Estricto  

---

## 📸 1. AUDITORÍA FORENSE DE LAS 5 CAPTURAS Y DIAGNÓSTICO EN CÓDIGO FUENTE

A partir de la inspección exhaustiva de los archivos de la app y el análisis de las 5 capturas reales provistas por el usuario, se determina la causa raíz exacta de cada anomalía:

| Captura | Pantalla / Modal | Diagnóstico Forense del Problema | Causa Raíz Exacta en Código Fuente |
| :--- | :--- | :--- | :--- |
| **Imagen 1** | **`Editar Producto`** (`presentation_pricing_section.dart`, `presentation_discount_section.dart`) | **1. Desperdicio de Espacio Vertical y Colisión Visual:** Al activar el módulo de descuentos, aparece un banner morado separado (`PRECIO FINAL CON DESCUENTO: S/ 12.51`) arriba del acordeón, cuyo texto largo colisiona contra el precio y el borde derecho.<br>**2. Decimales Incómodos Sin Redondeo:** El 10% sobre `S/ 13.90` resulta en `S/ 12.51`. No existe forma de redondear la oferta a `.50` o `.00` (`S/ 12.50` o `S/ 12.00`) desde el módulo, ni recálculo reactivo del porcentaje al redondear.<br>**3. Falta de Enunciado Explicativo en "S/ Fijo":** El usuario debe calcular mentalmente cómo se aplica el descuento fijo. | • `presentation_pricing_section.dart` L197-241: Renderiza un `Container` con `Row(mainAxisAlignment: MainAxisAlignment.spaceBetween)` fuera del acordeón del descuento.<br>• `presentation_math_engine.dart` L418-494: El método `roundPrice` solo opera sobre `ventaCtrl` (precio regular base), sin soporte para redondear `precioOferta` ni recalcular inversamente el porcentaje/monto.<br>• `presentation_discount_section.dart` L92-221: No integra el precio final, carece de chips de redondeo y de texto pedagógico. |
| **Imagen 2** | **`Detalles de Producto`** -> Modal **`Gestión de Descuento`** (`discount_intelligent_modal.dart`) | **Falta de Guía Visual y Redondeo Rápido en "Monto Fijo (S/)":**<br>Aunque ya opera bajo la **Opción 2** (`Precio Regular: S/ 13.90 - Descuento: S/ 10.00 = NUEVO PRECIO: S/ 3.90`), el usuario no cuenta con una fórmula visible ni con chips para redondear el precio final resultante (`.50`, `.90`, `.00`) sin esfuerzo mental. | • `discount_intelligent_modal.dart` L223-239: El input de monto solo tiene el label genérico *"Monto a descontar"*, sin mostrar la fórmula pedagógica en vivo.<br>• Carece de fila de chips de redondeo rápido sobre `_nuevoPrecioFinal`. |
| **Imagen 3** | Modal **`Gestionar Precio`** (`price_update_modal.dart`) | **1. Chips Inútiles `2x1` y `3x2`:** Ocupan espacio horizontal innecesario.<br>**2. Bloqueo Injustificado al Subir Precio en `"S/ Nuevo"`:** Al escribir `2` cuando el Precio Regular es `S/ 1.00`, muestra en rojo `"¡La oferta (2.0) es mayor al precio base (1.0)!"` e inhabilita el botón `"APLICAR CAMBIOS"`, impidiendo al comerciante subir su precio de venta.<br>**3. Encabezado Desplazable:** El header (`$ Gestionar Precio` y la `X`) se desplaza y oculta con el scroll. | • `price_update_modal.dart` L85-95: Valida `if (calc >= base)` y asigna `errorMsg = "¡La oferta ($calc) es mayor al precio base ($base)!"`. L137 deshabilita el botón si `errorMsg != null`.<br>• L328-330: Renderiza `_QuickChip(label: "2x1")` y `_QuickChip(label: "3x2")`.<br>• L153-178: `SingleChildScrollView` envuelve la cabecera completa en lugar de mantenerla fija en el slot de cabecera de `InteractiveSheetWrapper`. |
| **Imagen 4** | **`Catálogo de Ventas`** -> Modal **`Filtros del Catálogo`** (`live_filter_bottom_sheet.dart`) | **Conteo Cero y Cero Resultados al Filtrar por `"Solo ofertas 🔥"`:**<br>Al seleccionar `"Solo ofertas 🔥"`, el botón inferior dice `"Aplicar Filtros"` (indicando conteo 0) y al aplicarlo devuelve **0 productos**, a pesar de existir productos con descuento en el inventario. | • `LiveFilterBottomSheet._refreshSqliteCount()` invoca `CatalogProvider.countFilteredProducts(filters)`.<br>• `CatalogProvider` llama a `ProductRepository.countInventoryRaw` y `fetchInventoryRaw`.<br>• **ERROR CRÍTICO DESCUBIERTO:** En `ProductRepository.dart` L83 y L225, la consulta SQL incluye: `OR (pr.id IN (SELECT bi.presentacion_id FROM bundle_items bi INNER JOIN bundles_promocionales bp ON bi.bundle_id = bp.id WHERE bp.activo = 1))`.<br>• Las tablas `bundle_items` y `bundles_promocionales` **NO EXISTEN en SQLite** (las tablas canónicas del proyecto son `items_paquete` y `paquetes`).<br>• SQLite lanza `DatabaseException: no such table: bundle_items`, el bloque `catch` atrapa la excepción y retorna silenciosamente `[]` (0 productos). |
| **Imagen 5** | **`Gestión de Negocio`** -> Pestaña **`PRODUCTOS`** (`inventory_screen.dart`, `inventory_item_tile.dart`) | **Paradoja de Oferta Visible pero Infiltrable:**<br>`jekeke - Color (PAR)` muestra claramente el badge `OFERTA`, precio original tachado `S/ 13.90` y nuevo precio `S/ 12.00`. Sin embargo, al abrir el filtro (`FilterDrawer`) y marcar `"Solo ofertas 🔥"`, devuelve **0 productos** debido al mismo colapso de la consulta SQLite por la tabla fantasma `bundle_items`. | • Mismo fallo de consulta SQL por tablas inexistentes `bundle_items` / `bundles_promocionales` en `ProductRepository.fetchInventoryRaw` (L83) y `countInventoryRaw` (L225).<br>• En memoria, `InventoryWrapper.hasOffer` evalúa correctamente `precioOferta` y `valorDescuento`, por eso la tarjeta pinta el badge, pero la consulta SQLite colapsaba al filtrar. |

---

## 🎯 2. OBJETIVOS ARQUITECTURALES Y DE DISEÑO

1. **Eficiencia Espacial y Ergonomía Visual en `Crear / Editar Producto`:**
   * Retirar el banner morado exterior de `presentation_pricing_section.dart`.
   * Integrar el resumen compacto del precio final con descuento directamente dentro del contenedor de `presentation_discount_section.dart`.
   * Garantizar paddings equilibrados para que las cifras y textos nunca choquen contra los bordes, con transiciones fluidas de expansión y colapso.
2. **Redondeo Reactivo de Ofertas y Recálculo Inverso:**
   * Permitir redondear el precio con descuento a terminaciones comerciales (`.50`, `.90`, `.00 Entero`) con soporte toggle (revertir si se presiona el mismo chip).
   * Al redondear el precio con descuento, recalcular automáticamente el porcentaje o monto descontado en el formulario sin desfases.
   * **Regla de Visualización Entera:** En cualquier tarjeta, modal o lista donde se muestre un badge con el `%` de descuento (Catálogo, Inventario, Detalles), formatear siempre como número entero limpio (`-10%`, `-14%`, nunca `-13.67%`).
3. **Estandarización Absoluta de `"S/ Fijo"` (Opción 2):**
   * En toda la aplicación, `"S/ Fijo"` significará: $\text{Precio con Descuento} = \text{Precio de Venta Original} - \text{Monto a Descontar}$.
   * Añadir enunciado pedagógico en vivo: *"Se restará del precio regular: S/ 13.90 - S/ 1.90 = S/ 12.00"* y chips de redondeo rápido sobre el precio final en `presentation_discount_section.dart` y `discount_intelligent_modal.dart`.
4. **Potencia Comercial y Flexibilidad en `"Gestionar Precio"`:**
   * Eliminar los chips obsoletos `2x1` y `3x2`. Mantener únicamente porcentajes útiles (`-5%`, `-10%`, `-15%`, `-20%`, `-50%`) y chips de redondeo (`.50`, `.90`, `.00`).
   * En la opción `"S/ Nuevo"`:
     * Si el monto es `< Precio Regular`: Tratar como Oferta/Descuento (`S/ 1.00 -> S/ 0.85` con opción de "Quitar Oferta").
     * Si el monto es `> Precio Regular`: **NO mostrar error ni bloquear el botón**. Tratarlo como **actualización directa del Precio Base de Venta**, recalculando en tiempo real el margen y la ganancia, mostrando el aviso *"Nuevo Precio Base de Venta: S/ 1.00 ➔ S/ 2.00"*, y limpiando cualquier oferta previa al guardar.
   * Cabecera fija sticky para que el título y la `X` permanezcan visibles sin importar el scroll o la apertura del teclado.
5. **Solución Definitiva y Paridad Total al Filtro `"Solo ofertas 🔥"`:**
   * Erradicar las referencias a tablas inexistentes `bundle_items` y `bundles_promocionales` en `ProductRepository.dart`. Reemplazarlas por las tablas canónicas existentes en SQLite: `items_paquete` y `paquetes`.
   * Unificar al 100% la condición de oferta entre:
     * Consulta SQL en SQLite (`precio_oferta < precio_venta_final`, `valor_descuento > 0`, `reglas_promocion`, `items_paquete`).
     * Getters canónicos en `ProductPresentation.hasOffer` y `InventoryWrapper.hasOffer`.
     * Filtros reactivos en `CatalogProvider`, `InventoryProvider`, `LiveFilterBottomSheet` y `FilterDrawer`.

---

## 🏗️ 3. PLAN DE EJECUCIÓN EN 5 FASES

```mermaid
flowchart TD
    subgraph FASE 1: Solución Definitiva al Filtro de Ofertas en SQLite y Providers
        F1_1[Corregir tablas fantasma en ProductRepository L83 y L225] --> F1_2[Crear getters canonicos hasOffer y effectivePrice en ProductPresentation]
        F1_2 --> F1_3[Armonizar InventoryWrapper y paridad SQL vs Memoria]
        F1_3 --> F1_4[Garantizar conteo reactivo 0ms en LiveFilterBottomSheet y FilterDrawer]
    end

    subgraph FASE 2: Estandarización de S/ Fijo y Rediseño Compacto del Módulo de Descuentos
        F2_1[Eliminar banner morado externo de PresentationPricingSection] --> F2_2[Rediseñar PresentationDiscountSection con resumen integrado]
        F2_2 --> F2_3[Formula pedagogica en vivo S/ Original - Monto = Nuevo Precio]
        F2_3 --> F2_4[Enunciado pedagogico y redondeo en DiscountIntelligentModal]
    end

    subgraph FASE 3: Motor de Redondeo sobre Precio con Descuento y Regla de % Entero
        F3_1[Implementar roundDiscountPrice en PresentationMathEngine] --> F3_2[Recalculo automatico inverso de porcentaje/monto al redondear]
        F3_3[Chips .50, .90, .00 sobre la oferta con soporte toggle] --> F3_4[Estandarizar badges a enteros limpios -10%, -14%]
    end

    subgraph FASE 4: Refinamiento del Modal Gestionar Precio
        F4_1[Fijar cabecera sticky en PriceUpdateModal] --> F4_2[Eliminar chips 2x1 y 3x2 e integrar chips utiles]
        F4_2 --> F4_3[Permitir precio mayor en S/ Nuevo como actualizacion de precio base]
        F4_3 --> F4_4[Recalculo reactivo de margen/ganancia en vivo y guardado dual]
    end

    subgraph FASE 5: Verificación Adversarial y Batería de Pruebas Automatizadas
        F5_1[Crear test unitario y de widget para filtros de oferta SQLite] --> F5_2[Test de redondeo inverso en descuentos y formula fija]
        F5_2 --> F5_3[Test de subida de precio base en Gestionar Precio]
        F5_3 --> F5_4[Ejecutar suite completa de flutter test sin regresiones]
    end

    FASE 1 --> FASE 2 --> FASE 3 --> FASE 4 --> FASE 5
```

---

### DETALLE PASO A PASO POR FASES

#### FASE 1: Corrección Forense de Tablas SQLite y Paridad Total del Filtro de Ofertas
* **Archivos a intervenir:**
  * `lib/features/catalog/repositories/product_repository.dart`
  * `lib/features/catalog/models/product_model.dart`
  * `lib/features/catalog/models/inventory_wrapper.dart`
  * `lib/features/catalog/providers/catalog_provider.dart`
  * `lib/features/catalog/providers/inventory_provider.dart`
* **Acciones específicas:**
  1. **Corrección de Tablas Fantasma:**
     * En `ProductRepository.fetchInventoryRaw` (L83) y `ProductRepository.countInventoryRaw` (L225):
       ```sql
       -- ANTES (provocaba DatabaseException: no such table: bundle_items):
       OR (pr.id IN (SELECT bi.presentacion_id FROM bundle_items bi INNER JOIN bundles_promocionales bp ON bi.bundle_id = bp.id WHERE bp.activo = 1))
       
       -- CORRECCIÓN CANÓNICA:
       OR (pr.id IN (SELECT ip.presentacion_id FROM items_paquete ip INNER JOIN paquetes pq ON ip.paquete_id = pq.id WHERE pq.activo = 1))
       ```
     * Añadir casteo numérico seguro `CAST(pr.precio_oferta AS REAL) < CAST(pr.precio_venta_final AS REAL)` para evitar anomalías si SQLite preservó tipos mixtos.
  2. **Getters Canónicos en `ProductPresentation`:**
     * Centralizar en `product_model.dart`:
       * `bool get hasOffer`: Evalúa si `precioOferta` es válido y menor a `precioVentaFinal`, o si tiene `valorDescuento > 0` con tipo porcentaje/monto/fijo.
       * `double get effectivePrice`: Retorna el precio de oferta si existe, o aplica el cálculo matemático si hay `valorDescuento` activo.
       * `int get discountPercentRounded`: Retorna el porcentaje redondeado a número entero limpio (`round()`).
  3. **Delegación Transparente en `InventoryWrapper`:**
     * Reemplazar la lógica duplicada de `InventoryWrapper.hasOffer` y `effectivePrice` para que consuman directamente los getters canónicos de `presentation`.
  4. **Blindaje de Conteo en `LiveFilterBottomSheet` y `FilterDrawer`:**
     * Verificar que cuando `_onlyOffers == true`, `params['has_offer'] = 'true'` se transmita con precisión y el contador SQLite devuelva el número exacto de variantes u ofertas en tiempo real.

---

#### FASE 2: Rediseño Compacto del Módulo de Descuentos y Estandarización de `"S/ Fijo"`
* **Archivos a intervenir:**
  * `lib/core/widgets/presentation_card/presentation_pricing_section.dart`
  * `lib/core/widgets/presentation_card/presentation_discount_section.dart`
  * `lib/core/widgets/discount_intelligent_modal.dart`
* **Acciones específicas:**
  1. **Limpieza en `PresentationPricingSection`:**
     * Eliminar el bloque de líneas 197-241 que renderizaba el banner morado exterior `"PRECIO FINAL CON DESCUENTO: S/ 12.51"`.
  2. **Diseño Compacto en `PresentationDiscountSection`:**
     * Integrar dentro del propio contenedor del acordeón el precio final resultante con diseño equilibrado y tipografía legible (`fontSize: 16`, `fontWeight: FontWeight.w900`), sin riesgo de colisión con los bordes.
     * En modo `"S/ Fijo"`:
       * Estandarizar bajo la **Opción 2**: $\text{Precio con Descuento} = \text{Precio Regular} - \text{Monto Descontado}$.
       * Mostrar enunciado explicativo dinámico debajo del campo:
         `"Se restará del precio de venta (S/ 13.90 - S/ 1.90 = S/ 12.00)"`.
     * En modo `"% Porcentaje"`:
       * Mostrar enunciado dinámico:
         `"Se descontará el 10% (S/ 13.90 - S/ 1.39 = S/ 12.51)"`.
  3. **Actualización de `DiscountIntelligentModal` (`ProductDetailScreen`):**
     * Añadir el enunciado explicativo pedagógico debajo del input de valor:
       *"Se restará del precio regular (`S/ 13.90 - S/ 10.00 = S/ 3.90`)"*.
     * Integrar chips de redondeo rápido sobre el nuevo precio (`.50`, `.90`, `.00`) que ajusten automáticamente el valor ingresado sin requerir cálculo mental del usuario.

---

#### FASE 3: Motor de Redondeo sobre Precio con Descuento y Regla de `%` Entero
* **Archivos a intervenir:**
  * `lib/core/widgets/presentation_card/presentation_math_engine.dart`
  * `lib/core/widgets/presentation_card/presentation_discount_section.dart`
  * `lib/core/widgets/catalog_item_card.dart`
  * `lib/core/widgets/inventory_item_tile.dart`
  * `lib/core/widgets/product_detail_modal.dart`
  * `lib/features/catalog/screens/product_detail_screen.dart`
* **Acciones específicas:**
  1. **Método `roundDiscountPrice` en `PresentationMathEngine`:**
     * Incorporar estado de redondeo activo para la oferta (`activeDiscountRoundingTarget`, `preRoundedDiscountValue`).
     * Si el usuario pulsa un chip de redondeo (`.50`, `.90`, `.00`):
       * Se toma el `precioOferta` actual antes de redondear.
       * Se redondea a la fracción solicitada (ej. `12.51 -> 12.50` o `12.00`).
       * **Recálculo reactivo:**
         * Si el tipo es `porcentaje`: Se recalcula el porcentaje exacto necesario para que el precio dé la cifra redondeada:
           $$\text{nuevoPorcentaje} = \frac{\text{precioBase} - \text{precioRedondeado}}{\text{precioBase}} \times 100$$
           Se actualiza `valorDescuentoCtrl.text = nuevoPorcentaje.toStringAsFixed(2);`.
         * Si el tipo es `monto`: Se recalcula el monto a descontar:
           $$\text{nuevoMonto} = \text{precioBase} - \text{precioRedondeado}$$
           Se actualiza `valorDescuentoCtrl.text = nuevoMonto.toStringAsFixed(2);`.
       * **Soporte Toggle:** Si se vuelve a tocar el mismo chip activo, se desactiva el redondeo y se restaura el valor previo.
  2. **Chips en `PresentationDiscountSection`:**
     * Colocar los chips interactivos `[.50] [.90] [.00]` junto al precio con descuento en el módulo.
  3. **Garantía Visual de Porcentaje Entero (`%`):**
     * En todas las tarjetas de Catálogo (`CatalogItemCard`), Detalles (`ProductDetailModal`, `ProductDetailScreen`), etc., asegurar que cualquier insignia o badge que muestre porcentaje lo haga estrictamente como entero limpio:
       `-10%`, `-14%` (usando `round()`), nunca con decimales como `-13.67%`.
     * Las tarjetas que solo muestran el precio tachado y la oferta (como `InventoryItemTile`) mantendrán su diseño intacto con badge `OFERTA` o `-X%` entero.

---

#### FASE 4: Refinamiento de Lógica e Interfaz en `"Gestionar Precio"` (`price_update_modal.dart`)
* **Archivos a intervenir:**
  * `lib/core/widgets/price_update_modal.dart`
* **Acciones específicas:**
  1. **Cabecera Fija Sticky:**
     * Reorganizar el layout para que el título `$ Gestionar Precio`, el subtítulo y el botón `X` permanezcan anclados arriba, fuera del `SingleChildScrollView`, garantizando que nunca se corten al scrollear o abrir el teclado.
  2. **Depuración de Accesos Rápidos:**
     * Retirar definitivamente los chips `2x1` y `3x2`.
     * Dejar una fila horizontal pulida con accesos útiles de porcentaje (`-5%`, `-10%`, `-15%`, `-20%`, `-50%`) y chips de redondeo rápido sobre el precio final (`.50`, `.90`, `.00`).
  3. **Comportamiento Dual en `"S/ Nuevo"`:**
     * Al seleccionar la pestaña `"S/ Nuevo"` e ingresar un valor:
       * **Si `nuevoPrecio < precioRegular`:**
         * Se aplica como **Oferta**.
         * Se muestra la tarjeta verde: `PRECIO FINAL AL CLIENTE` (`S/ 1.00 -> S/ 0.85`) con botón `"Quitar Oferta"`.
       * **Si `nuevoPrecio > precioRegular`:**
         * **NO mostrar error ni bloquear el botón `APLICAR CAMBIOS`**.
         * Tratarlo como **Subida Directa del Precio Regular Base de Venta**.
         * Actualizar reactivamente la tarjeta de Margen y Ganancia usando el nuevo precio ingresado contra el costo de la presentación.
         * En la tarjeta inferior, mostrar un aviso informativo claro en azul/verde:
           *"Nuevo Precio Base de Venta: S/ 1.00 ➔ S/ 2.00"*.
       * Al pulsar `"APLICAR CAMBIOS"`:
         * Si el monto era mayor, actualiza `precioVentaFinal: nuevoPrecio` y envía `oferta: -1` (limpiando cualquier oferta previa).
         * Si el monto era menor, actualiza la oferta y descuento correspondientes.

---

#### FASE 5: Protocolo de Verificación y Banco de Pruebas Adversariales
* **Archivos a intervenir / crear:**
  * `test/discounts_rounding_price_update_and_offers_filter_test.dart`
* **Casos de prueba obligatorios:**
  1. **Test SQLite Filtro de Ofertas:** Verificar que `ProductRepository.fetchInventoryRaw` y `countInventoryRaw` con `has_offer: 'true'` ejecutan consultas válidas en SQLite utilizando `items_paquete` y `paquetes`, retornando las variantes con oferta activa sin lanzar `DatabaseException`.
  2. **Test Redondeo Reactivo de Ofertas:** Verificar que sobre un precio base de `S/ 13.90` con `10%` (`S/ 12.51`), al aplicar redondeo `.00` el precio pasa a `S/ 12.00` y el porcentaje reacciona automáticamente a `13.67%` (guardado exacto) mostrándose visualmente como `-14%`.
  3. **Test Toggle de Redondeo:** Verificar que presionar el chip activo restaura el precio y porcentaje original (`12.51` y `10%`).
  4. **Test Estandarización S/ Fijo (Opción 2):** Verificar que un descuento de `S/ 1.90` sobre `S/ 13.90` calcula exactamente `S/ 12.00` tanto en el formulario como en el modal inteligente.
  5. **Test Subida de Precio en Gestionar Precio:** Verificar que al ingresar `S/ 2.00` sobre base `S/ 1.00` en `"S/ Nuevo"`, no se genera `errorMsg`, el botón permanece habilitado y al guardar se actualiza el precio base de venta a `2.00` limpiando ofertas previas.
  6. **Ejecución de Suite Completa:** `flutter test` de todos los tests del repositorio asegurando 0 regresiones.

---

## 📂 4. MATRIZ DE ARCHIVOS A MODIFICAR

| Archivo | Rol en el Sistema | Cambios Previstos |
| :--- | :--- | :--- |
| `lib/features/catalog/repositories/product_repository.dart` | Consultas SQL de Inventario y Catálogo | Reemplazar tablas fantasma `bundle_items` / `bundles_promocionales` por `items_paquete` / `paquetes`. Casteo numérico en `has_offer`. |
| `lib/features/catalog/models/product_model.dart` | Modelo canónico de presentación | Añadir getters `hasOffer`, `effectivePrice`, `discountPercentRounded`. |
| `lib/features/catalog/models/inventory_wrapper.dart` | Wrapper de producto + variante | Delegar `hasOffer` y `effectivePrice` al modelo canónico `ProductPresentation`. |
| `lib/core/widgets/presentation_card/presentation_pricing_section.dart` | Sección de Precios en Edición | Eliminar banner morado superior redundante. |
| `lib/core/widgets/presentation_card/presentation_discount_section.dart` | Sección de Descuentos en Edición | Integrar precio final compacto, fórmula explicativa de `"S/ Fijo"` y chips de redondeo `.50, .90, .00`. |
| `lib/core/widgets/presentation_card/presentation_math_engine.dart` | Motor matemático reactivo | Añadir `roundDiscountPrice`, recálculo automático de porcentaje/monto al redondear oferta, soporte toggle. |
| `lib/core/widgets/discount_intelligent_modal.dart` | Modal de Gestión de Descuento | Añadir enunciado pedagógico en vivo y chips de redondeo rápido sobre el nuevo precio. |
| `lib/core/widgets/price_update_modal.dart` | Modal Gestionar Precio | Cabecera sticky fija, remover chips `2x1` y `3x2`, permitir precio mayor en `"S/ Nuevo"` como subida de precio base, recálculo reactivo. |
| `lib/core/widgets/catalog_item_card.dart` | Tarjeta del Catálogo | Formateo estricto del porcentaje como número entero limpio (`-10%`, `-14%`). |
| `lib/core/widgets/product_detail_modal.dart` | Modal de Detalle en Catálogo | Armonizar detección de oferta y formateo entero del `%`. |
| `lib/features/catalog/screens/product_detail_screen.dart` | Ficha Completa del Producto | Consumir `hasOffer` y `effectivePrice` canónicos. |
| `test/discounts_rounding_price_update_and_offers_filter_test.dart` | Batería de Pruebas Automatizadas | Tests unitarios y de widgets para todas las fases. |

---

## 🛡️ 5. PROTOCOLO ADVERSARIAL DE VERIFICACIÓN

* **Criterio de Aceptación 1 (Filtro Ofertas):** Al seleccionar `"Solo ofertas 🔥"` en Catálogo (`LiveFilterBottomSheet`) o Inventario (`FilterDrawer`), el conteo debe reflejar de inmediato los productos con descuento activo y listarlos correctamente sin excepciones SQLite.
* **Criterio de Aceptación 2 (Diseño y Redondeo de Descuento):** En `Editar Producto`, el módulo de descuentos debe contener el precio final sin banners morados externos. Al pulsar `.00` sobre `S/ 12.51`, debe pasar a `S/ 12.00` y el porcentaje ajustarse a `13.67%`.
* **Criterio de Aceptación 3 (Porcentaje Entero):** Todas las tarjetas y badges de la app deben mostrar números enteros limpios (`-14%`, `-10%`).
* **Criterio de Aceptación 4 (Gestionar Precio):** En `price_update_modal.dart`, escribir un monto mayor al precio base debe habilitar el botón y permitir guardar el nuevo precio regular sin errores.
* **Criterio de Aceptación 5 (Suite Limpia):** Ejecución exitosa de `flutter test` con 100% de tests aprobados.

---
*Fin del Plan de Trabajo. Esperando revisión y aprobación del usuario antes de proceder a la fase de implementación.*
