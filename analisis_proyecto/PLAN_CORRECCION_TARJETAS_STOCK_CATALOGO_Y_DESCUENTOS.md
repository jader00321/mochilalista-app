# 🚀 PLAN MAESTRO DE TRABAJO: CORRECCIÓN DE TARJETAS DE INVENTARIO, MODAL DE STOCK, CATÁLOGO DE VENTAS Y REINGENIERÍA DEL MÓDULO DE DESCUENTOS

**Documento de Especificación Técnica, Diagnóstico Forense y Protocolo Adversarial**  
**Proyecto:** MochilaLista App (Local-First SQLite, 0ms Latency, Flutter)  
**Módulos Involucrados:**
- **Pestaña Productos (Inventario):** `inventory_item_tile.dart` (Lista), `inventory_grid_card.dart` (Cuadrícula), `inventory_compact_tile.dart` (Compacta).
- **Modal Abastecer / Editar Stock:** `stock_update_modal.dart` (`lib/core/widgets/stock_update_modal.dart`) y paridad en `quick_restock_modal.dart` (`lib/features/catalog/widgets/quick_restock_modal.dart`).
- **Catálogo de Ventas (Tarjetas y Grid Dinámico):** `catalog_item_card.dart` (`lib/core/widgets/catalog_item_card.dart`), `catalog_screen.dart` (`lib/features/catalog/screens/catalog/catalog_screen.dart`).
- **Módulo de Descuentos en Crear / Editar Producto:** `presentation_discount_section.dart` (`lib/core/widgets/presentation_card/presentation_discount_section.dart`), `presentation_math_engine.dart` (`lib/core/widgets/presentation_card/presentation_math_engine.dart`), `product_presentation_card.dart` (`lib/core/widgets/product_presentation_card.dart`), `product_edit_operations.dart` (`lib/features/catalog/widgets/edit/product_edit/product_edit_operations.dart`), `product_form_mapper.dart` (`lib/features/catalog/widgets/form/product_form_mapper.dart`), `product_controller_factory.dart` (`lib/features/catalog/widgets/form/product_controller_factory.dart`), `product_model.dart` (`lib/features/catalog/models/product_model.dart`).
**Fecha:** Octubre 2026  
**Metodología:** Loop Autónomo + Árbitro Adversarial Estricto  

---

## 📸 1. AUDITORÍA FORENSE DE LAS 5 CAPTURAS Y DIAGNÓSTICO EN CÓDIGO FUENTE

A partir de la inspección exhaustiva de las 5 capturas adjuntas y la auditoría línea por línea del código fuente, se identifica la causa raíz exacta de cada problema reportado:

| Captura | Pantalla / Componente | Diagnóstico Forense del Problema | Causa Raíz Exacta en Código Fuente |
| :--- | :--- | :--- | :--- |
| **Imagen 1** | **Inventario: Pestaña `PRODUCTOS`** (`SAN CARLOS - jekeke Principal`) | **Colisión Física entre Precio y Píldora de Stock:** Con stock largo (`5708880 Unidades`) o precio largo, el texto `S/ 6.90` y la píldora `[ 📦 5708880 Unidades ✏️ ]` se superponen violentamente. | • `inventory_item_tile.dart` L253-389: `Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Flexible(child: InkWell(child: PriceColumn)), StockBadge ])`. Al ser `Flexible` con ancho no acotado y `PulsingStockBadge` de tamaño intrínseco amplio, el ancho horizontal supera los ~230px disponibles entre la imagen (85px) y los márgenes, forzando a los elementos a colisionar sin salto de línea. |
| **Imagen 2** | **Inventario: Pestaña `PRODUCTOS`** (`SAN CARLOS - jekeke Color`) | **Etiqueta Roja de Porcentaje Duplicada:** En productos con oferta, aparece un badge rojo `-10%` en la esquina superior izquierda de la foto y un segundo badge idéntico `[-10%]` pegado al precio tachado `S/ 13.90 [-10%]`. | • `inventory_item_tile.dart` L154-165 renderiza el badge `-10%` sobre la imagen, pero en L281-296 reinserta un `Container` rojo con `discountBadgeText` al costado del precio tachado.<br>• `inventory_compact_tile.dart` L160-175 replica la misma duplicidad innecesaria. |
| **Imagen 3** | **Modal `Abastecer / Editar Stock`** (`StockUpdateModal`) | **1. Chip Desbordado a la Derecha:** En `Unidad de ingreso:`, el segundo chip `"Por Unidad base"` se sale del contenedor por la derecha.<br>**2. Falla Lógica de Negocio:** Permitir ingresar unidades base en presentaciones con factor (ej. Par x2 o Docena x12) genera decimales y sobrantes (`_currentStockRemainder`), requiriendo alertas amarillas y cuadres rápidos que pertenecen exclusivamente a la edición completa del producto. | • `stock_update_modal.dart` L343-387: `Row(children: [ ChoiceChip("Por Par (x2)"), ChoiceChip("Por Unidad base (x1)") ])` excede el ancho horizontal del modal en móviles de 360-390px.<br>• `stock_update_modal.dart` L66-80 y L391-426: Lógica dual innecesaria con `_unitGranularity` y banner amarillo `Hay X u. suelta(s)` con botón `[ ⚡ Cuadrar ]`. |
| **Imagen 4** | **`Catálogo de Ventas`** (`catalog_item_card.dart` y grid) | **1. Superposición Crítica:** En la tarjeta izquierda (`SEDAL`), un título de 3 líneas hace que el chip `UNIDAD` se monte directamente sobre el texto de costo `🟢 C: S/ 0.68`.<br>**2. Asimetría Visual:** La tarjeta vecina derecha (`SAN CARLOS`) con título de 1 línea queda con altura desproporcionada. | • `catalog_item_card.dart` L134-191: El texto del producto está dentro de `Expanded(child: Column(children: [ RichText(maxLines: 3), SizedBox(5), salesUnitBadge ]))`. Al exceder la altura asignada por `flex: 7`, el chip de presentación se desborda verticalmente y se dibuja sobre el `Row` inferior de costo y precio.<br>• `catalog_screen.dart` L1058-1064: Uso de `SliverGrid` con `childAspectRatio: 0.60` rígido, que impide alturas dinámicas por contenido y no adapta simétricamente las filas vecinas. |
| **Imagen 5** | **`Módulo de Descuentos` en Crear / Editar Producto** (`PresentationDiscountSection`) | **1. Modo `S/ Fijo` Incoherente y Destructivo:** Campo muestra `0.85`, pero cuadro dice `"Se restará del precio: 1.00 - 0.85 = 0.15"`. Al tocar y quitar un chip de redondeo (`.50`, etc.), el precio final muta destructivamente a `S/ 0.15 (-85%)`.<br>**2. Modo `% Porcentaje` Corrompido:** Muestra `0.85` en vez de `15%`, badge dice `-1%`, y al quitar redondeo muta a `S/ 0.99`. | • `presentation_discount_section.dart` L254-262 y L297-308: Trata `valorDcto` como monto a descontar (`precioVenta - valorDcto = 0.15`), mientras el input contiene el precio final deseado (`0.85`).<br>• `presentation_math_engine.dart` L454-463: Al desactivar el redondeo, limpia `precioOfertaExacto = null`, haciendo que el precio final retroceda a `baseVenta - valorDcto` (`1.00 - 0.85 = 0.15`).<br>• `product_edit_operations.dart` L112-120: Hidrata `valorDescuento` directamente sin convertir entre porcentaje y precio en soles, inyectando `0.85` en `valorDescuentoCtrl` aun cuando el tipo sea porcentaje. |

---

## 🎯 2. OBJETIVOS ARQUITECTURALES Y DE DISEÑO

1. **Adaptabilidad Total en Tarjetas de Inventario (0 Colisiones, 0 Truncamiento `...`, Letra Intacta):**
   - En las 3 vistas de la pestaña `PRODUCTOS` (`inventory_item_tile.dart`, `inventory_grid_card.dart`, `inventory_compact_tile.dart`), implementar un layout adaptativo inteligente: cuando el precio y la píldora de stock no quepan cómodamente en una fila o superen el ancho disponible, la píldora de stock descenderá limpiamente a su propia fila dedicada, garantizando que números de stock millonarios (ej. `5708880 Unidades`) o precios extensos se lean 100% completos.
   - Eliminar el contenedor rojo duplicado de porcentaje que aparece junto al precio original tachado en `inventory_item_tile.dart` y `inventory_compact_tile.dart`. La etiqueta roja quedará visible **únicamente sobre la imagen del producto**.
2. **Modal `Abastecer / Editar Stock` Simplificado, Factor-Aware y Blindado:**
   - Erradicar el chip `"Por Unidad base"` y la alerta amarilla de cuadre de unidades sueltas de este modal rápido.
   - El modal operará **exclusivamente según la Unidad de Venta configurada en la variante** (ej. `Por Par (x2)`, `Por Docena (x12)`, `Por Unidad (x1)`).
   - El recuadro de `Unidad de ingreso:` mostrará únicamente el chip/indicador de la unidad de venta activa con su factor (ej. `[ ✓ Por Par (x2) ]`), perfectamente integrado y sin desbordes.
   - El número ingresado (`_parsedInput`) representará siempre **Unidades de Venta**, y al guardar se multiplicará por el factor (`unidadesPorVenta`) para registrar las unidades base exactas en SQLite (`stock: _parsedInput * factor`), logrando cuadratura 100% exacta y consistente.
3. **Catálogo de Ventas: Cero Superposición y Cuadrícula con Altura Simétrica por Fila:**
   - En `catalog_item_card.dart`, reformular la distribución interna para que el nombre de hasta 3 líneas, la variante y el chip de presentación (`UNIDAD`, `PAR`) fluyan con espacio vertical natural sin invadir ni superponerse jamás a la sección financiera (`C: S/ 0.68`, `G: S/ 0.17`, Precios y Botón `+`).
   - En `catalog_screen.dart`, sustituir el `childAspectRatio` fijo por una arquitectura de filas con altura intrínseca simétrica (`IntrinsicHeight` en filas de 2 tarjetas o delegado dinámico). Si una tarjeta crece a 3 líneas de nombre, la tarjeta contigua en la misma fila crecerá automáticamente a la misma altura exacta, manteniendo una cuadrícula estética, alineada y profesional.
4. **Reingeniería Matemática y Recarga Reactiva del `Módulo de Descuentos`:**
   - **Modo `S/ Fijo` Clarificado:** El campo de texto pasa a representar el **Precio Final de Oferta** deseado por el usuario (etiquetado como `Precio Oferta S/` o `Precio Final S/`). El sistema calcula automáticamente el dinero ahorrado (`precioOriginal - precioOferta`) y el porcentaje de descuento equivalente, mostrando un enunciado informativo claro:  
     *`"Descuento aplicado: S/ 0.15 menos sobre el precio normal de S/ 1.00 (-15%)"`*.
   - **Modo `% Porcentaje` Estricto:** El campo `Valor %` opera estrictamente con el porcentaje (`15%`) y jamás recibe montos en soles.
   - **Conversión Bidireccional Fluida al Cambiar Modo:** Al alternar entre `% Porcentaje` y `S/ Fijo`, el sistema convierte y sincroniza el valor numérico en tiempo real sin alterar el Precio Final (`S/ 0.85` <-> `15%`).
   - **Blindaje Total de Chips de Redondeo (`.50`, `.90`, `.00`):** Al activar un redondeo se ajusta la oferta; al desactivarlo (toggle off) se restaura con exactitud matemática el estado, modo y valor previo sin corromper el precio ni alterar céntimos.
   - **Hidratación Limpia al Abrir `Editar Producto`:** Si la variante ya tiene promoción en SQLite, `ProductEditOperations` hidrata el modo correcto, el porcentaje exacto y el precio de oferta exacto desde el primer instante.

---

## 🏗️ 3. PLAN DE EJECUCIÓN EN 5 FASES

```mermaid
flowchart TD
    subgraph FASE 1: Tarjetas de Inventario y Eliminación de Etiqueta Roja Duplicada
        F1_1[inventory_item_tile: LayoutBuilder adaptativo para precio y stock pill] --> F1_2[inventory_grid_card & compact_tile: blindaje anti-truncamiento]
        F1_2 --> F1_3[Eliminar badge rojo repetido al costado del precio tachado]
        F1_3 --> F1_4[Preservar únicamente el badge rojo en la esquina superior de la foto]
    end

    subgraph FASE 2: Simplificación Factor-Aware del Modal Abastecer / Editar Stock
        F2_1[Eliminar chip 'Por Unidad base' y erradicar _unitGranularity] --> F2_2[Eliminar banner amarillo de unidades sueltas y botón Cuadrar]
        F2_2 --> F2_3[Diseñar chip único elegante: Unidad de ingreso: Por Presentación xFactor]
        F2_3 --> F2_4[Multiplicar _parsedInput * factor para persistencia base exacta en SQLite]
    end

    subgraph FASE 3: Catálogo de Ventas: Cero Superposición y Simetría de Fila
        F3_1[Reestructurar catalog_item_card con espaciado vertical natural] --> F3_2[Aislar chip de presentación del bloque financiero]
        F3_2 --> F3_3[Implementar IntrinsicHeight en filas de tarjetas en catalog_screen]
        F3_3 --> F3_4[Garantizar altura idéntica entre tarjetas vecinas en la misma fila]
    end

    subgraph FASE 4: Reingeniería del Módulo de Descuentos en Crear / Editar Producto
        F4_1[Redefinir modo S/ Fijo como Precio Oferta S/ con cálculo de ahorro y %] --> F4_2[Modo % Porcentaje estricto y conversión matemática bidireccional]
        F4_2 --> F4_3[Blindaje de chips de redondeo .50/.90/.00 con memoria previa y toggle off]
        F4_3 --> F4_4[Auditoría de hidratación inicial en ProductEditOperations y persistencia en mapper]
    end

    subgraph FASE 5: Suite de Tests Automatizados y Verificación Integral 360°
        F5_1[Crear suite de pruebas automatizadas en test/cards_stock_catalog_discounts_test.dart] --> F5_2[Verificar pruebas de colisión y stock largo]
        F5_2 --> F5_3[Verificar pruebas de modal de stock, catálogo simétrico y módulo de descuentos]
        F5_3 --> F5_4[Ejecutar suite completa de regresión de flutter test]
    end

    FASE 1 --> FASE 2 --> FASE 3 --> FASE 4 --> FASE 5
```

---

## 📝 4. ESPECIFICACIÓN TÉCNICA DETALLADA POR FASE

### FASE 1: Pestaña `PRODUCTOS` (Inventario) — Adaptabilidad para Precios/Stocks Largos y Eliminación de Etiqueta Roja Duplicada

#### Archivos Involucrados:
- `lib/core/widgets/inventory_item_tile.dart`
- `lib/core/widgets/inventory_grid_card.dart`
- `lib/core/widgets/inventory_compact_tile.dart`

#### 1.1. Disposición Adaptativa en `InventoryItemTile` (Vista Lista):
- **Diagnóstico:** En la vista de lista, la columna de información dispone el precio y el stock en un `Row` con `mainAxisAlignment: MainAxisAlignment.spaceBetween`. Cuando el stock es largo (`5708880 Unidades`) o el precio tiene descuento con precio tachado, el espacio horizontal disponible (~220-250px) resulta insuficiente, provocando la colisión visible en la `Imagen 1`.
- **Implementación Adaptativa:**
  - Envolver la zona inferior de la tarjeta en un `LayoutBuilder`.
  - Evaluar el ancho disponible `constraints.maxWidth`:
    - Si el ancho disponible es suficiente (ej. `>= 240px`) Y los textos de precio y stock no son excesivamente largos: renderizar en una sola fila (`Row`) con espaciado limpio.
    - Si el ancho disponible es ajustado o los contenidos superan el umbral: cambiar automáticamente a una disposición vertical (`Column(crossAxisAlignment: CrossAxisAlignment.start)`), donde:
      * **Fila 1:** Bloque de precio completo (precio tachado si hay oferta + precio final destacado + ícono de lápiz de edición de precio).
      * **Fila 2:** Píldora de stock interactiva (`PulsingStockBadge` con `unidadVentaText` completo y micro-icono de edición), con margen superior de 6px.
  - **Regla Estricta:** No achicar el tamaño de la tipografía ni agregar `TextOverflow.ellipsis` al stock o al precio. Cualquier cifra debe mostrarse íntegra.

#### 1.2. Eliminación de Etiqueta Roja Duplicada:
- **`inventory_item_tile.dart`:**
  - Mantener intacto el badge rojo de descuento sobre la esquina superior izquierda de la imagen/avatar del producto (L154-165).
  - **Eliminar el `Container` rojo de L281-296** que se dibuja al costado del precio original tachado `S/ 13.90 [-10%]`. El precio original tachado se mostrará limpiamente con su estilo `TextDecoration.lineThrough` en color rojo atenuado, sin la etiqueta roja repetida.
- **`inventory_compact_tile.dart`:**
  - Eliminar el contenedor rojo repetido de L160-175 junto al precio tachado.
- **`inventory_grid_card.dart`:**
  - Verificar que solo conserve la etiqueta de oferta en la cabecera de la imagen (L96-110) y ninguna etiqueta duplicada junto al precio tachado.

#### 1.3. Ajuste Adaptativo en `InventoryGridCard` e `InventoryCompactTile`:
- En `inventory_grid_card.dart`: la cuadrícula ya posee dos renglones dedicados (L201: Precio, L247: Stock). Ajustar el contenedor del stock para que no aplique `TextOverflow.ellipsis` en forma destructiva, sino que si el texto es extenso se reduzca ligeramente el padding lateral o permita ajuste de salto limpio.
- En `inventory_compact_tile.dart`: estructurar la columna derecha de precio y stock para que no comprima la columna izquierda del nombre, manteniendo un ancho mínimo balanceado.

---

### FASE 2: Modal `Abastecer / Editar Stock` — Simplificación y Factor-Aware

#### Archivos Involucrados:
- `lib/core/widgets/stock_update_modal.dart`
- `lib/features/catalog/widgets/quick_restock_modal.dart`

#### 2.1. Eliminación de la Opción `"Por Unidad base"` y Modo Único en Unidad de Venta:
- En `stock_update_modal.dart`, remover la variable `_unitGranularity` y el método `_onGranularityChanged`.
- El modal trabajará **exclusivamente con la Unidad de Venta configurada** para la presentación (`_unidadVenta`, ej. `Par`, `Docena`, `Unidad`) y su factor (`_factor = unidadesPorVenta > 0 ? unidadesPorVenta : 1`).
- En la sección `Unidad de ingreso:`, sustituir los dos chips por un **indicador único integrado**:
  ```dart
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: (isDark ? Colors.indigo[900]! : Colors.indigo[50]!).withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: (isDark ? Colors.indigo[400]! : Colors.indigo.shade200).withValues(alpha: 0.5)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Unidad de ingreso:",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.indigo[200] : Colors.indigo[900]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.blue[800] : Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, size: 13, color: isDark ? Colors.white : Colors.blue[900]),
              const SizedBox(width: 4),
              Text(
                "Por $_unidadVenta (x$_factor)",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.blue[900],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  )
  ```
  Al ser un solo indicador que ocupa el espacio justo, **jamás se desborda ni se corta por la derecha**.

#### 2.2. Erradicación de la Alerta Amarilla de Cuadratura:
- Eliminar el bloque de L391-426 (`Banner de Cuadratura si hay unidades sueltas` con el botón `[ ⚡ Cuadrar ]`), dado que en este modal rápido todo se maneja en unidades enteras de venta y la gestión de unidades sueltas pertenece a la pantalla completa de `Editar Producto`.

#### 2.3. Matemática y Persistencia Exacta:
- Inicialización en `initState`:
  - Modo 0 (`Sumar Compra`): `ctrl.text = "1"` (1 unidad de venta).
  - Modo 1 (`Fijar Stock Total`): `ctrl.text = _currentStockSalesUnits.toString()` (stock actual de la variante en unidades de venta: `_currentStockBase ~/ _factor`).
- Cálculo del nuevo stock base (`_calculatedNewStockBase`):
  - Si Modo 0: `_currentStockBase + (_parsedInput * _factor)`.
  - Si Modo 1: `_parsedInput * _factor`.
- Tarjeta informativa de resultado:
  - Muestra claramente: `"Resultado: $_parsedInput $_unidadVenta = ${resultingBase} unidades base"`.
- Al pulsar `"APLICAR CAMBIOS"`:
  - Se llama a `widget.provider.updatePresentation(widget.presentation.id!, stock: resultingBase)`.
  - El stock guardado en SQLite es exactamente múltiplo del factor, garantizando consistencia absoluta en todo el sistema.
- Aplicar la misma paridad en `quick_restock_modal.dart` para preservar la coherencia en todo el repositorio.

---

### FASE 3: Tarjetas de `Catálogo de Ventas` — Cero Superposición y Cuadrícula Simétrica

#### Archivos Involucrados:
- `lib/core/widgets/catalog_item_card.dart`
- `lib/features/catalog/screens/catalog/catalog_screen.dart`

#### 3.1. Reingeniería Interna de `catalog_item_card.dart`:
- **Causa del Solapamiento:** En `catalog_item_card.dart`, el texto del producto y el chip de venta (`UNIDAD`) estaban constreñidos dentro de un `Expanded` con `flex: 7` rígido junto con el bloque financiero. Al tener un título largo de 3 líneas (como en la `Imagen 4`), el texto y el chip excedían el espacio vertical y se dibujaban encima del renglón `🟢 C: S/ 0.68`.
- **Solución Estructural:**
  - Desacoplar el título y el chip del bloque financiero:
    * El título (hasta 3 líneas) y el chip de empaque (`UNIDAD`, `PAR`) se colocan en un bloque superior que toma su altura natural necesaria.
    * El bloque financiero (costo `C:`, ganancia `G:`, precio tachado, precio final y botón `+`) se ancla al fondo mediante un `Spacer()` o `Column(mainAxisAlignment: MainAxisAlignment.spaceBetween)`.
  - De esta manera, el crecimiento vertical del título expande la tarjeta completa hacia abajo en lugar de colisionar con los números de costo.

#### 3.2. Altura Simétrica por Fila en `catalog_screen.dart`:
- **Problema de `SliverGrid(childAspectRatio: 0.60)`:** El `SliverGrid` con aspect ratio fijo fuerza a todas las tarjetas a tener la misma altura fija (ej. 288px), provocando desbordes cuando el texto es largo y dejando huecos cuando el texto es corto.
- **Solución Arquitectural (Filas Intrínsecas Simétricas):**
  - Implementar en `catalog_screen.dart` la renderización de las tarjetas en pares de 2 por fila mediante `SliverList.builder`:
    ```dart
    SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, rowIndex) {
          final int firstIndex = rowIndex * 2;
          final int secondIndex = firstIndex + 1;
          final bool hasSecond = secondIndex < provider.displayItems.length;

          final item1 = provider.displayItems[firstIndex];
          final item2 = hasSecond ? provider.displayItems[secondIndex] : null;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: CatalogItemCard(
                      item: item1,
                      isStoreMode: _isStoreMode,
                      onDetails: () => _showDetailModal(context, item1),
                      onPresentationDetails: (pres) => _showDetailModal(
                        context,
                        item1.copyWith(presentation: pres),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: item2 != null
                        ? CatalogItemCard(
                            item: item2,
                            isStoreMode: _isStoreMode,
                            onDetails: () => _showDetailModal(context, item2),
                            onPresentationDetails: (pres) => _showDetailModal(
                              context,
                              item2.copyWith(presentation: pres),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        },
        childCount: (provider.displayItems.length / 2).ceil(),
      ),
    )
    ```
  - **Efecto Visual Garantizado:**
    * `IntrinsicHeight` mide la altura requerida por la tarjeta más alta de la fila (ej. la de 3 líneas).
    * `crossAxisAlignment: CrossAxisAlignment.stretch` estira automáticamente a la tarjeta vecina a esa misma altura exacta.
    * Ambas tarjetas de la fila lucen perfectamente alineadas y simétricas, sin importar si una tiene 1 línea y la otra 3.

---

### FASE 4: Reingeniería de Lógica y Recarga Reactiva del `Módulo de Descuentos` en `Crear / Editar Producto`

#### Archivos Involucrados:
- `lib/core/widgets/presentation_card/presentation_discount_section.dart`
- `lib/core/widgets/presentation_card/presentation_math_engine.dart`
- `lib/core/widgets/product_presentation_card.dart`
- `lib/features/catalog/widgets/edit/product_edit/product_edit_operations.dart`
- `lib/features/catalog/widgets/form/product_form_mapper.dart`
- `lib/features/catalog/models/product_model.dart`

#### 4.1. Redefinición Clara del Modo `S/ Fijo` (Precio Final de Oferta):
- En el modo `S/ Fijo`, el campo de texto se etiqueta claramente como **`Precio Oferta S/`** (o `Precio Final S/`).
- El valor ingresado por el usuario representa **el precio de venta con oferta que se cobrará** (ej. `0.85` sobre un precio original de `1.00`).
- La matemática calcula:
  * `montoDescontado = precioVentaOriginal - precioOfertaIngresado` (`1.00 - 0.85 = 0.15`).
  * `porcentajeDescuento = ((precioVentaOriginal - precioOfertaIngresado) / precioVentaOriginal) * 100` (`15%`).
- El recuadro informativo muestra:
  * *"Descuento aplicado: S/ 0.15 menos sobre el precio normal de S/ 1.00 (-15%)"*.
- El contenedor de resumen inferior muestra:
  * `PRECIO FINAL: [-15%] S/ 0.85`.
- Se valida que `precioOfertaIngresado > 0` y `precioOfertaIngresado < precioVentaOriginal`. Si el usuario ingresa un valor mayor o igual al precio normal, se muestra advertencia de que la oferta debe ser menor al precio regular.

#### 4.2. Corrección del Modo `% Porcentaje`:
- En el modo `% Porcentaje`, el campo se etiqueta como **`Valor %`**.
- El valor ingresado representa estrictamente el porcentaje a descontar (ej. `15` para `15%`).
- La matemática calcula:
  * `precioOferta = precioVentaOriginal * (1 - (valorPorcentaje / 100))` (`1.00 * (1 - 0.15) = 0.85`).
  * `montoDescontado = precioVentaOriginal - precioOferta` (`0.15`).
- El contenedor de resumen muestra:
  * `PRECIO FINAL: [-15%] S/ 0.85`.

#### 4.3. Sincronización Bidireccional Fluida al Cambiar entre `% Porcentaje` y `S/ Fijo`:
- Cuando el usuario presiona el botón para cambiar de modo:
  - De `% Porcentaje` a `S/ Fijo`:
    * Toma el precio de oferta actual calculado (`0.85`).
    * Actualiza `valorDescuentoCtrl.text = precioOferta.toStringAsFixed(2)` (`"0.85"`).
    * Actualiza `controllerMap['tipoDescuento'] = 'monto'`.
  - De `S/ Fijo` a `% Porcentaje`:
    * A partir del precio de oferta actual (`0.85`) y el precio base (`1.00`), calcula el porcentaje exacto: `((1.00 - 0.85) / 1.00) * 100 = 15.0%`.
    * Actualiza `valorDescuentoCtrl.text = "15"` (o formato limpio sin decimales espurios si es entero).
    * Actualiza `controllerMap['tipoDescuento'] = 'porcentaje'`.
- De este modo, alternar entre ambas pestañas **jamás altera el Precio Final ni confunde soles con porcentajes**.

#### 4.4. Blindaje de Chips de Redondeo de Oferta (`.50`, `.90`, `.00`) y Toggle OFF:
- En `PresentationMathEngine`:
  - Guardar el estado previo antes de aplicar redondeo:
    * `controllerMap['preRoundedDiscountValue'] = valorDescuentoCtrl.text.trim();`
    * `controllerMap['preRoundedDiscountType'] = tipoDescuento;`
    * `controllerMap['preRoundedOfferPrice'] = precioOferta;`
  - Al pulsar un chip de redondeo (ej. `.50`):
    * Calcula el precio redondeado (ej. `0.50`).
    * En modo `S/ Fijo`: actualiza el input a `"0.50"` y `precioOfertaExacto = 0.50`.
    * En modo `% Porcentaje`: calcula el nuevo porcentaje equivalente y actualiza el input a `"50.00"` y `precioOfertaExacto = 0.50`.
  - Al volver a presionar el mismo chip para desactivarlo (**Toggle OFF**):
    * Restaura con fidelidad milimétrica:
      `valorDescuentoCtrl.text = preRoundedDiscountValue;`  
      `controllerMap['precioOfertaExacto'] = preRoundedOfferPrice;`
    * Limpia los punteros temporales de redondeo.
    * Vuelve a recalcular el precio final sin desvíos: `PRECIO FINAL: [-15%] S/ 0.85`.
    * **Fin total del bug destructivo** que convertía el precio a `S/ 0.15 (-85%)` o `S/ 0.99 (-1%)`.

#### 4.5. Hidratación Inicial al Abrir `Editar Producto` (`ProductEditOperations`):
- En `ProductEditOperations.loadProductData`:
  - Si la presentación tiene oferta guardada (`pres.hasOffer` o `pres.precioOferta != null`):
    * `descuentoActivo = true`.
    * Determinar el tipo canónico: si `pres.tipoDescuento == 'monto'` o `'fijo'`, o si `pres.precioOferta != null`:
      - Si el tipo es porcentaje: verificar que `pres.valorDescuento` no sea en realidad un monto en soles menor a 1 (como `0.85`): si `pres.valorDescuento == pres.precioOferta` y ambos son `< pres.precioVentaFinal`, el porcentaje real es `((pres.precioVentaFinal - pres.precioOferta!) / pres.precioVentaFinal) * 100` (`15%`).
      - Si el modo es `S/ Fijo`: inyectar el precio de oferta `pres.precioOferta!.toStringAsFixed(2)` (`"0.85"`).
      - Si el modo es `% Porcentaje`: inyectar el porcentaje exacto (`"15"`).
    * `precioOfertaExacto = pres.precioOferta`.
  - Al guardar en `ProductFormMapper`:
    - Persistir consistentemente:
      * `precio_oferta = precioFinalCalculado` (`0.85`).
      * `tipo_descuento = tipoDescuento` (`'fijo'` o `'porcentaje'`).
      * `valor_descuento = tipoDescuento == 'porcentaje' ? valorPorcentaje : montoDescontado`.
    - Garantizando que SQLite siempre almacene datos sanos, congruentes y estandarizados.

---

### FASE 5: Suite de Tests Automatizados y Verificación Integral 360°

#### Archivo de Test:
- `test/cards_stock_catalog_discounts_test.dart`

#### Casos de Prueba Automatizados:
1. **Prueba de Tarjetas de Inventario (Vista Lista, Grid y Compacta):**
   - Verificar que con stock millonario (`5708880 Unidades`) y precio largo, el layout en `InventoryItemTile` separa precio y stock en filas independientes sin colisiones.
   - Verificar que la etiqueta roja de porcentaje solo se renderiza sobre la imagen del producto y no existe duplicidad en el precio tachado.
2. **Prueba de Modal `Abastecer / Editar Stock` (`StockUpdateModal`):**
   - Verificar que no existe el chip `"Por Unidad base"` y que solo existe el chip de la unidad de venta configurada (`Por Par (x2)`).
   - Verificar que ingresar `10` en modo Sumar Compra resulta en `20` unidades base guardadas.
   - Verificar que ingresar `10` en modo Fijar Stock resulta en `20` unidades base guardadas.
   - Verificar que no se muestra el banner amarillo de cuadratura de residuo.
3. **Prueba de Catálogo de Ventas (`CatalogItemCard` y Grid Simétrico):**
   - Verificar que una tarjeta con título de 3 líneas no monta el chip de presentación sobre el texto de costo `C:`.
   - Verificar que en una fila de 2 tarjetas donde una tiene 3 líneas y la otra 1 línea, el contenedor `IntrinsicHeight` otorga la misma altura simétrica a ambas tarjetas.
4. **Prueba Matemática del Módulo de Descuentos:**
   - Verificar que en modo `S/ Fijo` con precio base `1.00`, ingresar `0.85` muestra precio final `0.85`, ahorro `0.15` y badge `-15%`.
   - Verificar que al cambiar a `% Porcentaje` el input se convierte automáticamente a `15%`.
   - Verificar que al activar el chip `.50` y luego desactivarlo (toggle off), el precio y porcentaje regresan exactamente a `0.85` y `15%`, sin degradar a `0.15` ni `0.99`.
   - Verificar la hidratación de datos al editar un producto con oferta previa.
5. **Ejecución Completa de la Suite de Regresión:**
   - Ejecutar `flutter test` garantizando 100% de tests en verde en todo el proyecto.

---

## 🛡️ 5. MATRIZ DE VERIFICACIÓN DEL ÁRBITRO INTERNO ADVERSARIAL

Para asegurar que ninguna solución genere regresiones colaterales ni quiebre flujos preexistentes, el Árbitro Interno Adversarial someterá los cambios a las siguientes pruebas de estrés:

| ID | Escenario de Estrés Adversarial | Riesgo Crítico / Hipótesis de Falla | Salvaguarda y Criterio de Aceptación Estricto |
| :--- | :--- | :--- | :--- |
| **ADV-01** | **Stock Millonario en Pantalla Angosta (320px - 360px):** Producto con nombre largo, precio de oferta largo (`S/ 1234.56`) y stock de `9999999 Unidades`. | El texto de stock desborda horizontalmente o empuja la tarjeta fuera de la pantalla. | El `LayoutBuilder` detecta la saturación y divide precio y stock en dos renglones dedicados. La píldora de stock ocupa el 100% del ancho inferior con lectura completa. Cero overflow de renderflex. |
| **ADV-02** | **Variante con Factor en `StockUpdateModal`:** Producto vendido por `Docena (x12)`, stock actual base = 25 (2 docenas + 1 suelta). | El usuario ingresa 5 docenas. ¿Qué ocurre con la 1 unidad suelta previa al fijar stock total? | En el modal rápido, fijar `5 Docenas` establece el stock base en exactamente `60` unidades base (`5 * 12`), sin residuos espurios. Si el usuario desea gestionar unidades base sueltas, lo hace en la ventana completa de `Editar Producto`. |
| **ADV-03** | **Títulos de Extrema Longitud en Catálogo de Ventas:** Producto con nombre de 4 líneas y múltiples palabras técnicas. | El texto empuja los botones de costo y compra fuera de la vista de la tarjeta. | El título está acotado con `maxLines: 3` y `TextOverflow.ellipsis`, mientras la tarjeta tiene espacio holgado para el chip y la sección financiera inferior anclada con `Spacer`. |
| **ADV-04** | **Ciclo Repetido de Chips de Redondeo en Descuentos:** El usuario pulsa `.50`, luego `.90`, luego `.00`, y vuelve a presionar `.00` para apagar el redondeo. | Corrupción acumulativa de redondeo de punto flotante (`0.8500000000000001` o deriva a `0.99`). | `preRoundedDiscountValue` guarda el valor base original antes del primer chip del ciclo. Al apagar el redondeo activo, se restaura el valor prístino original en String limpio. |
| **ADV-05** | **Alternancia Rápida entre `% Porcentaje` y `S/ Fijo`:** El usuario cambia 10 veces seguidas entre ambos botones sin alterar el texto. | Acumulación de error de conversión matemática que termine cambiando `0.85` por `0.84` u `0.86`. | La conversión utiliza redondeo a 2 decimales (`toStringAsFixed(2)`) y sincroniza con el precio de oferta exacto en memoria, manteniendo paridad constante. |

---

## 📋 6. ENTREGABLES DE LA EJECUCIÓN

1. **Código Fuente Refactorizado y Blindado:**
   - `lib/core/widgets/inventory_item_tile.dart`
   - `lib/core/widgets/inventory_grid_card.dart`
   - `lib/core/widgets/inventory_compact_tile.dart`
   - `lib/core/widgets/stock_update_modal.dart`
   - `lib/features/catalog/widgets/quick_restock_modal.dart`
   - `lib/core/widgets/catalog_item_card.dart`
   - `lib/features/catalog/screens/catalog/catalog_screen.dart`
   - `lib/core/widgets/presentation_card/presentation_discount_section.dart`
   - `lib/core/widgets/presentation_card/presentation_math_engine.dart`
   - `lib/core/widgets/product_presentation_card.dart`
   - `lib/features/catalog/widgets/edit/product_edit/product_edit_operations.dart`
   - `lib/features/catalog/widgets/form/product_form_mapper.dart`
2. **Suite de Pruebas Automatizadas:**
   - `test/cards_stock_catalog_discounts_test.dart`
   - Actualización de pruebas existentes que contemplaban la interfaz anterior.
3. **Informe Final de Certificación de Calidad:**
   - Evidencia de ejecución con `flutter test` en 100% de tests pasando.
   - Confirmación de resolución estricta de las 5 capturas y los 4 bloques solicitados.
