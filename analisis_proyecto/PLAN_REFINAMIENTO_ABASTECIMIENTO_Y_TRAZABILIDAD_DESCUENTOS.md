# PLAN DE TRABAJO MAESTRO: REFINAMIENTO DEL MOTOR DE ABASTECIMIENTO Y TRAZABILIDAD CON HISTORIAL DE DESCUENTOS

**Proyecto:** Mochila Lista — Aplicación Móvil POS / CRM / Analítica  
**Documento:** Plan de Trabajo Detallado e Ingeniería Forense  
**Ruta:** `analisis_proyecto/PLAN_REFINAMIENTO_ABASTECIMIENTO_Y_TRAZABILIDAD_DESCUENTOS.md`  
**Metodología:** Loop Autónomo Continuo + Árbitro Interno Adversarial  
**Estado:** Pendiente de Aprobación por el Usuario  

---

## 1. RESUMEN EJECUTIVO Y OBJETIVOS ESTRATÉGICOS

Tras una inspección forense exhaustiva de los módulos de **Motor Inteligente de Abastecimiento** (`smart_restock_screen.dart`, `inventory_intelligence_service.dart`) y **Trazabilidad del Producto (Kardex Digital)** (`audit_trail_screen.dart`, `product_repository.dart`, `local_db.dart`), y contrastando el código actual contra las **5 capturas de pantalla de pruebas reales en dispositivo físico**, se han identificado cuatro áreas críticas de intervención:

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                       MAPA DE REFINAMIENTO Y ARQUITECTURA OBJETIVO                          │
├───────────────────────────────┬───────────────────────────────┬─────────────────────────────┤
│ 1. MOTOR DE ABASTECIMIENTO    │ 2. REDISEÑO Y CABECERA        │ 3. TRAZABILIDAD (KARDEX)    │
│    LÓGICA "SELECCIONAR TODOS" │    RETRÁCTIL ANTI-REBOTE      │    Y AUDITORÍA DESCUENTOS   │
├───────────────────────────────┼───────────────────────────────┼─────────────────────────────┤
│ • Sincronización contextual   │ • Colapso suave de KPIs y ROP │ • Fila única balanceada de  │
│   con el filtro activo.       │   al scrollear hacia abajo.   │   Entradas / Salidas.       │
│ • Tri-State (☑ / ⊟ / ☐)       │ • Sticky Search & Chips fijos │ • Padding en modal Kardex y │
│   con feedback visual real.   │   con fondo sólido.           │   ShaderMask en chips.      │
│ • Protección contra inflado   │ • Cero rebote (anti-jitter)   │ • Resolución matemática de  │
│   de OC (solo urgentes/pedir).│   con umbral delta + cooldown.│   Stock Inicial vs Kardex.  │
│ • Segmentación limpia de      │ • Descompresión cabecera y    │ • NUEVA FUNCIÓN: Historial  │
│   chips (Urgentes/Preventivos/│   separación alerta sin costo │   completo de Descuentos /  │
│   Saludables/Por Pedir).      │   vs Historial/Trazabilidad.  │   Promociones por Variante. │
└───────────────────────────────┴───────────────────────────────┴─────────────────────────────┘
```

El presente plan establece el diagnóstico forense exacto, la arquitectura técnica de solución dividida en Fases lógicas, la matriz de verificación y las reglas estrictas de arbitraje adversarial.

---

## 2. DIAGNÓSTICO FORENSE LÍNEA POR LÍNEA Y ANÁLISIS DE CAPTURAS

### 2.1. Bloque 1: Falla de Lógica y UX en "Seleccionar Todos" (Capturas 1 y 2)

* **Archivos Involucrados:**
  * `app_movil/lib/features/analytics/screens/smart_restock_screen.dart` (Líneas 149–174, 1043–1093)
* **Evidencia en Captura 1:**
  * Al iniciar la pantalla, el filtro activo es `"✓ Todos (105)"`.
  * Las primeras 26 tarjetas visibles en pantalla corresponden a productos urgentes (`status == 'agotado'` o `'critico'`) y están marcadas con `☑`.
  * Sin embargo, en la barra inferior fija se observa: **`"☐ Seleccionar Todos"` (icono vacío / desmarcado)** con el texto descriptivo `"26 de 105 para pedir"`.
  * **Causa Raíz en Código:**
    * Línea 1046: `final bool allSelected = selectedItems.length == _items.length && _items.isNotEmpty;`
    * Línea 1076: `allSelected ? Icons.check_box : Icons.check_box_outline_blank`
    * Al abrir la pantalla, `selectedItems.length` es 26 y `_items.length` es 105. La condición evalúa `false`, por lo que el control inferior se dibuja como un checkbox vacío `☐`.
    * El usuario percibe una contradicción visual severa: todas las tarjetas visibles en pantalla están marcadas, pero el control general le indica que no hay nada seleccionado o que está desactivado.
* **Evidencia en Captura 2:**
  * Al presionar `"Seleccionar Todos"`, el sistema marca **los 105 productos del catálogo** (`105 de 105 para pedir`), disparando la Inversión Total Sugerida de `S/ 239.28` a `S/ 940.38`.
  * **Causa Raíz en Código:**
    * Líneas 1065–1072:
      ```dart
      setState(() {
        bool target = !allSelected;
        for (var i in _items) {
          i.isSelected = target;
        }
      });
      ```
    * El bucle itera ciegamente sobre `_items` (la totalidad del catálogo en memoria), marcando productos con stock saludable cuya sugerencia de compra es `0` o que no requieren reabastecimiento.
    * Además, la operación ignora por completo la lista visible actual (`_filteredItems`), de modo que si el usuario estuviera en el filtro `"🚨 Urgentes"` o usando el buscador, marcaría productos no visibles pertenecientes a otros filtros.

---

### 2.2. Bloque 2: Rediseño de Tarjetas, Choque de Botones y Modal de Costo (Capturas 1, 2 y 3)

* **Archivos Involucrados:**
  * `app_movil/lib/features/analytics/screens/smart_restock_screen.dart` (Líneas 235–338, 371–405, 728–767, 839–905, 1098–1105)
* **Colisión 1: Choque entre `"⚠️ Sin costo  Asignar costo"` y `"⟲ Historial / Trazabilidad"` (Captura 1):**
  * **Líneas 840–905:**
    ```dart
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (item.hasZeroCost) ...[
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              const Text("Sin costo", style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _showAssignCostModal(item),
                child: const Text("Asignar costo", style: TextStyle(color: Colors.blueAccent, fontSize: 12, decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ] else ...[ ... ],
        Material(
          child: InkWell(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                children: [
                  Icon(Icons.history, size: 14, color: Colors.blueAccent),
                  SizedBox(width: 4),
                  Text("Historial / Trazabilidad", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                ],
              ),
            ),
          ),
        ),
      ],
    )
    ```
  * En un viewport de `360dp`, el ancho neto interno de la tarjeta es de ~`300dp`. El bloque de alerta ocupa ~`155dp` y el botón de historial ocupa ~`150dp`. La suma supera el ancho útil, provocando que el botón azul choque y monte su borde directamente sobre las letras de `"Asignar costo"`.
* **Colisión 2: Truncamiento Prematuro del Nombre del Producto en Cabecera de Tarjeta (Captura 1):**
  * **Líneas 728–767:** El badge semántico utiliza la cadena estática `item.statusText` configurada como `'🔴 Crítico (Stock ≤ ROP)'` (25 caracteres).
  * Este badge ocupa más de `155dp` del ancho horizontal. En consecuencia, el componente `ProductNomenclatureLabel` queda comprimido a apenas `135dp`, provocando que `"Yogurt Parcialmente Descremado"` se trunque de forma agresiva como `"Yogurt Parcialmente ..."`.
* **Colisión 3: Truncamiento en AppBar y Doble Icono en Footer (Capturas 1 y 2):**
  * **AppBar (Líneas 371–405):** El título `'Motor Inteligente de Abastecimiento'` (35 caracteres) compite contra el botón de navegación atrás (~`48dp`) y 3 acciones a la derecha (`InfoTooltipButton` + `IconButton PDF` + `IconButton Refresh` = `144dp`). El ancho disponible para el título es menor a `168dp`, provocando el corte `"Motor Inteligent..."`. Además, el botón `PDF` en AppBar es 100% redundante con el botón azul principal `"Exportar OC"` del pie de página.
  * **Footer (Líneas 1098–1102):**
    ```dart
    const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber),
    const SizedBox(width: 4),
    Text("⚠️ $zeroCostSelectedCount item(s) sin costo asignado no suman al total", ...)
    ```
    Se renderiza un `Icon(Icons.warning_amber_rounded)` seguido de un emoji textual `"⚠️"`, imprimiendo dos triángulos amarillos consecutivos (`⚠️ ⚠️`).
* **Colisión 4: Borde Cortado en Modal "Asignar Costo de Compra" (Captura 3):**
  * **Líneas 260–270:** Se utiliza un `TextField` con `labelText: "Costo Unitario de Compra"` y `OutlineInputBorder`. En modo oscuro y con foco activo, la etiqueta flotante recorta el trazo superior del borde de la caja de texto. Debe reemplazarse por una etiqueta superior limpia y fija de acuerdo con la norma de diseño del sistema.

---

### 2.3. Bloque 3: Saturación Vertical y Falta de Espacio de Navegación (Capturas 1 y 2)

* **Archivos Involucrados:**
  * `app_movil/lib/features/analytics/screens/smart_restock_screen.dart` (Líneas 411–421, 426–469, 522–593, 643–690)
* **Medición de Ocupación de Pantalla:**
  1. `AppBar`: 56dp
  2. `_buildKpiSummaryBar`: 72dp
  3. `_buildFilterAndSearchBar`: 92dp (Buscador 38dp + gap 6dp + Chips 38dp + paddings)
  4. `_buildHelpCard` (Banner ROP cerrado): 52dp
  5. `_buildSummaryBar` (Footer fijo): ~115dp
  6. Barra de estado y navegación del sistema operativo: ~75dp
  * **Total no navegable:** `56 + 72 + 92 + 52 + 115 + 75 = 462dp`.
  * En una pantalla estándar de 750–800dp de altura, más del **60% del espacio vertical está ocupado por elementos fijos**.
  * Solo quedan libres ~`280dp` para la lista de productos, donde una tarjeta de abastecimiento mide ~`240dp`. El usuario solo puede visualizar **una sola tarjeta completa** a la vez, y la tarjeta contigua queda cortada a la mitad por debajo del banner ROP.
* **Causa Raíz de Arquitectura:**
  * Toda la pantalla está estructurada en un simple `Column` con `Expanded(child: _buildList())`. Los KPIs y el banner ROP son estáticos y no reaccionan al scroll del usuario.
  * Si se intenta animar la altura de esos widgets superiores mediante un `ScrollController` ingenuo dentro de un `Column`, se produce el clásico **bucle de rebote (scroll jitter / feedback loop)**: al colapsar la cabecera, la lista se estira hacia arriba, el offset del scroll disminuye, el listener interpreta que el usuario volvió a subir y expande la cabecera nuevamente, generando parpadeos incontrolables.

---

### 2.4. Bloque 4: Trazabilidad, Auditoría de Stock y Nuevo Historial de Descuentos (Capturas 4 y 5)

* **Archivos Involucrados:**
  * `app_movil/lib/features/analytics/screens/audit_trail_screen.dart` (Líneas 50–85, 298–335, 363–386, 417–468)
  * `app_movil/lib/features/analytics/services/inventory_intelligence_service.dart` (Líneas 232–295)
  * `app_movil/lib/features/catalog/repositories/product_repository.dart` (Líneas 431–434, 463–530, 720–732, 920–935)
  * `app_movil/lib/core/widgets/interactive_sheet_wrapper.dart` (Líneas 428–436)
* **Ajuste 1: Párrafo del Modal Kardex sin Padding Horizontal (Captura 5):**
  * En `audit_trail_screen.dart` (líneas 417–432), se invoca `InteractiveSheetWrapper` sin pasar la propiedad `contentPadding`.
  * Por defecto, la línea 432 de `interactive_sheet_wrapper.dart` asigna `padding: widget.contentPadding ?? EdgeInsets.zero`.
  * En consecuencia, el párrafo `"La ventana de Trazabilidad es tu auditoría digital en tiempo real..."` se renderiza con padding cero, tocando físicamente los bordes curvos del modal y de la pantalla.
* **Ajuste 2: Apilamiento Vertical de Entradas / Salidas y Chips Rígidos (Captura 4):**
  * Las píldoras `"↓ Total Entradas: +28 und"` y `"↑ Total Salidas: -64 und"` están dentro de un `Wrap` que, por el ancho de sus márgenes internos, rompe en dos renglones ocupando el doble de espacio vertical en la tarjeta de resumen.
  * La fila de chips (`Todos`, `Movimientos`, `Precios y Costos`, `Ficha`) no tiene gradiente de desvanecimiento lateral (`ShaderMask`), provocando que el último chip visible se corte en seco contra el margen derecho.
* **Ajuste 3: Diagnóstico de la Ecuación de Stock (`+28 Entradas`, `-64 Salidas`, `Stock Actual: 20 und`):**
  * Al auditar `product_repository.dart` (`insertPresentation`, `saveFullProductTransaction`, `editFullProductTransaction`):
    * Cuando un producto es creado en el catálogo con stock inicial (por ejemplo, 56 unidades), este valor se almacena directamente en `presentaciones_producto.stock_actual`.
    * **NO se genera ningún registro en la tabla `stock_ledger` con tipo `'INVENTARIO_INICIAL'`**.
    * Posteriormente, se registran ajustes manuales (+28) y ventas (-64).
    * Al consultar el Kardex, la suma de movimientos arroja: `Entradas = +28`, `Salidas = -64`, flujo neto = `-36`.
    * Como el stock base inicial era `56`: `56 + 28 - 64 = 20 und`.
    * El usuario, al no ver el hito de creación o stock base inicial, percibe una inconsistencia aritmética evidente (`28 - 64 ≠ 20`).
* **NUEVA FUNCIÓN REQUERIDA: Trazabilidad y Registro de Descuentos por Variante:**
  * En `presentaciones_producto`, las ofertas y promociones se gestionan mediante las columnas:
    `precio_oferta` (REAL), `tipo_descuento` (TEXT: 'monto' | 'porcentaje'), `valor_descuento` (REAL).
  * En `product_repository.dart` (`_updatePresentationTxn`), la lista de campos interceptados para auditoría es:
    ```dart
    List<String> fieldsToTrack = ['precio_venta_final', 'costo_unitario_calculado', 'estado'];
    ```
  * Los cambios en descuentos y ofertas no son interceptados ni registrados en `product_history`.
  * Si un usuario aplica un 20% de descuento en el catálogo, luego lo cambia a un precio especial de S/ 10.00 y finalmente lo desactiva, **no queda absolutamente ningún rastro histórico en la base de datos ni en la pantalla de Trazabilidad**.

---

## 3. ARQUITECTURA TÉCNICA DE SOLUCIÓN POR FASES

El plan de trabajo se estructura en **4 Fases de Implementación**, garantizando una ejecución limpia, sin regresiones y verificada punto por punto:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        FASES DEL PLAN DE IMPLEMENTACIÓN                                │
├─────────────────┬─────────────────┬─────────────────┬──────────────────────────────────┤
│ FASE 1          │ FASE 2          │ FASE 3          │ FASE 4                           │
│ LÓGICA & UX     │ REDISEÑO UI     │ CABECERA FLUIDA │ TRAZABILIDAD KARDEX &            │
│ SELECCIÓN TOTAL │ DE TARJETAS     │ ANTI-REBOTE     │ HISTORIAL DE DESCUENTOS          │
├─────────────────┼─────────────────┼─────────────────┼──────────────────────────────────┤
│ • Tri-State en  │ • Reestructurar │ • Scrollable    │ • Padding en modal y fila        │
│   barra bottom. │   fila de costo │   header con    │   única de entradas/salidas.     │
│ • Sincronización│   y trazabilidad│   Slivers /     │ • Registro automático de         │
│   con vista     │ • Compactar     │   Controller    │   INVENTARIO_INICIAL.            │
│   filtrada.     │   badge estado. │   Gesture-Lock. │ • Intercepción de descuentos en  │
│ • Protección    │ • Eliminar PDF  │ • Buscador y    │   product_history.               │
│   contra sobre- │   en AppBar y   │   Chips fijos.  │ • Renderizado de hitos de oferta │
│   pedidos.      │   doble icono ⚠️│ • +50% espacio  │   y filtro en audit_trail_screen.│
└─────────────────┴─────────────────┴─────────────────┴──────────────────────────────────┘
```

---

### FASE 1: Corrección Integral de "Seleccionar Todos" y Sincronización de Filtros

#### 1.1. Estado Tri-State (`☑` / `⊟` / `☐`) y Sincronización Contextual
* Se reemplaza la evaluación global `selectedItems.length == _items.length` por una evaluación reactiva basada en la lista activa visible (`_filteredItems`):
  * `bool allVisibleSelected = _filteredItems.isNotEmpty && _filteredItems.every((i) => i.isSelected);`
  * `bool someVisibleSelected = _filteredItems.any((i) => i.isSelected) && !allVisibleSelected;`
* **Comportamiento Visual del Control Inferior:**
  * Si `allVisibleSelected == true`: Checkbox marcado `☑` (`Icons.check_box`), etiqueta: `"Deseleccionar todos"` o `"Deseleccionar vista (${_filteredItems.length})"`.
  * Si `someVisibleSelected == true`: Checkbox intermedio `⊟` (`Icons.indeterminate_check_box`), etiqueta: `"$selectedCount de ${_filteredItems.length} seleccionados"` con acción rápida para seleccionar el resto o limpiar la selección.
  * Si ninguno está seleccionado: Checkbox vacío `☐` (`Icons.check_box_outline_blank`), etiqueta: `"Seleccionar todos (${_filteredItems.length})"`.

#### 1.2. Protección Inteligente Contra Inflado de Órdenes de Compra
* Al presionar `"Seleccionar Todos"` desde el filtro general, el sistema no debe marcar productos cuyo estado sea `🟢 Saludable` y tengan sugerencia de compra `0` a menos que el usuario lo solicite expresamente.
* Se implementa un selector de acción inteligente:
  * Si el usuario pulsa en estado vacío (`☐`), se seleccionan todos los productos **que requieren abastecimiento** dentro de la vista actual (`status != 'saludable'` o `suggestedQty > 0`).
  * Si ya están marcados los prioritarios, un segundo toque permite seleccionar la totalidad o deseleccionar todo con absoluta claridad.

#### 1.3. Reorganización y Nomenclatura de Chips de Filtro
* Se evalúa y añade un chip dedicado para separar productos saludables de los que demandan compra:
  * `✓ Por Pedir (N)` [Urgentes + Preventivos] $\rightarrow$ **Filtro seleccionado por defecto al abrir la ventana**.
  * `🚨 Urgentes (N)` [Agotados + Críticos].
  * `🟠 Preventivos (N)` [Stock próximo a ROP].
  * `🟢 Saludables (N)` [Inventario en rango óptimo].
  * `Todos (N)` [Inventario total para consulta global].
* Con esta arquitectura, la pantalla de Abastecimiento cumple su rol primordial de forma inmediata: el comerciante entra y solo ve lo que tiene que comprar, sin saturarse con 105 productos de los cuales 60 no requieren acción.

---

### FASE 2: Rediseño de Tarjetas, Descompresión de Títulos y Modal de Costo

#### 2.1. Desacoplamiento de `"Sin costo"` y Botón `"Historial / Trazabilidad"`
* Se rediseña la fila intermedia de la tarjeta de abastecimiento:
  * **Lado Izquierdo:** La advertencia de costo cero se transforma en un chip compacto e interactivo con micro-estilo:
    * Contenedor con borde ámbar suave, icono `warning_amber_rounded` (13px) y texto `"Sin costo • Asignar"`. Al tocarlo, abre el modal de asignación.
    * Si tiene costo asignado, muestra `"Costo est.: S/ X.XX"`.
  * **Lado Derecho:** El botón de historial se compacta a `"⟲ Trazabilidad"`, utilizando `Flexible` y espaciado mínimo garantizado de `12dp`.
  * Se valida mediante layout constraints que ambos elementos convivan con holgura en viewports estrechos de `320dp` a `360dp` sin riesgo alguno de desbordamiento horizontal (`RenderFlex overflow`).

#### 2.2. Descompresión de la Cabecera de Tarjeta
* Se reduce el texto del badge semántico de estado:
  * `'🔴 Crítico (Stock ≤ ROP)'` $\rightarrow$ `'🔴 Stock Crítico'`.
  * `'🚨 Agotado'` $\rightarrow$ `'🚨 Agotado'`.
  * `'🟠 Preventivo'` $\rightarrow$ `'🟠 Preventivo'`.
* La explicación técnica detallada (`"Stock ≤ ROP"`) se traslada a la columna de ROP y al tooltip didáctico `(?)`.
* Con este ajuste, el badge se reduce de `155dp` a ~`90dp`, liberando más de `65dp` adicionales para el componente `ProductNomenclatureLabel`. El nombre del producto (`"Yogurt Parcialmente Descremado..."`) se lee completo y sin cortes artificiales.

#### 2.3. Limpieza de AppBar y Corrección de Doble Icono en Footer
* **AppBar:** Se retira el `IconButton` de PDF redundante. Se mantienen únicamente el botón informativo didáctico `InfoTooltipButton` y el botón de refresco `Refresh`. El título `'Motor Inteligente de Abastecimiento'` se configura con `fontSize: 16`, `maxLines: 1` y espaciado tipográfico optimizado, mostrándose 100% visible sin elipsis.
* **Footer:** En la fila de alerta de costos, se elimina el emoji textual repetido en el `String`, dejando únicamente el widget nativo `Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber)` con el texto: `"$zeroCostSelectedCount item(s) sin costo asignado no suman al total"`.

#### 2.4. Pulido del Modal `"Asignar Costo de Compra"`
* Se retira el `labelText` flotante que rompe el trazo del `OutlineInputBorder`.
* Se implementa una etiqueta superior fija y estilizada:
  ```dart
  Text(
    "Costo Unitario de Compra (Proveedor)",
    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ...),
  ),
  const SizedBox(height: 6),
  TextField(
    controller: costController,
    autofocus: true,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      prefixText: "S/ ",
      hintText: "0.00",
      helperText: "Ejemplo: 3.50 — Se actualizará en todo el inventario",
      ...
    ),
  ),
  ```
* Se conecta el blindaje inferior con `InteractiveSheetWrapper.getEffectiveBottomPadding(context, includeKeyboard: true)` para asegurar que el botón `"Guardar Costo en Inventario"` se mantenga plenamente accesible por encima del teclado numérico.

---

### FASE 3: Cabecera Retráctil Inteligente con Blindaje Anti-Rebote (*Anti-Jitter*)

#### 3.1. Arquitectura de Navegación Vertical Optimizada
Para duplicar el área de visualización de productos sin sacrificar las métricas gerenciales, se implementa una arquitectura basada en **Slivers (`CustomScrollView`) con `SliverPersistentHeader(pinned: true)`**:

```
┌────────────────────────────────────────────────────────┐
│ AppBar Fijo: "Motor Inteligente de Abastecimiento" ⓘ ↻ │
├────────────────────────────────────────────────────────┤
│ SLIVER RETRÁCTIL (Se oculta al scrollear hacia abajo):  │
│ • 3 Tarjetas de KPIs (Por Pedir, Agotados, Inversión)  │
│ • Banner Didáctico: "¿Cómo leer esta pantalla..."      │
├────────────────────────────────────────────────────────┤
│ SLIVER PINNED (Siempre visible y fijo en el tope):     │
│ • Buscador: "Buscar producto por nombre o marca..."    │
│ • Fila de Chips: [Por Pedir] [Urgentes] [Preventivos]  │
│   (Con fondo sólido temático y sombra de elevación)    │
├────────────────────────────────────────────────────────┤
│ SLIVER LIST (Área de lectura maximizada > 75%):        │
│ • Tarjeta Producto 1                                   │
│ • Tarjeta Producto 2                                   │
│ • Tarjeta Producto 3                                   │
│ • Tarjeta Producto N...                                │
├────────────────────────────────────────────────────────┤
│ Bottom Bar Compacto: Checkbox Tri-State + Exportar OC  │
└────────────────────────────────────────────────────────┘
```

#### 3.2. Ventajas Radicales de la Arquitectura de Slivers Frente al Modelo Manual
1. **Cero Rebote Garantizado:** Los Slivers delegan la física del scroll directamente al motor C++ de Flutter (`Viewport` / `RenderSliver`). No dependen de `ScrollController.addListener()` ni de llamadas a `setState()` que recalculan alturas de widgets padre.
2. **Scroll Natural y Reactivo:** Al bajar (`scroll down`), las tarjetas KPI y el banner ROP se deslizan naturalmente fuera de la vista; el Buscador y los Chips quedan anclados en el borde superior de la pantalla con fondo opaco.
3. **Re-despliegue Intuitivo:** Las secciones superiores vuelven a aparecer de forma suave y predecible al alcanzar el tope superior de la lista (`pixels == 0`) o al deslizar suavemente hacia arriba.
4. **Espacio Ganado:** La superficie de lectura para las tarjetas de productos pasa de ~`280dp` a más de **`520dp`**, permitiendo ver cómodamente **de 2 a 3 tarjetas completas** a la vez.

---

### FASE 4: Refinamiento de Trazabilidad y Nuevo Sistema de Historial de Descuentos

#### 4.1. Ajustes Visuales en `AuditTrailScreen` y Modal de Kardex
* **Modal Informativo (Captura 5):** Se añade `contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)` a `InteractiveSheetWrapper`, eliminando el choque del texto con los bordes del dispositivo. Se añade el nuevo hito comercial `"🏷️ Descuentos y Promociones"` a la lista explicativa.
* **Tarjeta Resumen (Captura 4):** Se reemplaza el `Wrap` por una fila horizontal equilibrada con dos tarjetas simétricas:
  ```dart
  Row(
    children: [
      Expanded(child: _buildBadge(Icons.arrow_downward, "Entradas", "+$_totalEntradas und", Colors.greenAccent)),
      const SizedBox(width: 8),
      Expanded(child: _buildBadge(Icons.arrow_upward, "Salidas", "-$_totalSalidas und", Colors.redAccent)),
    ],
  )
  ```
* **Chips de Eventos:** Se envuelve el `ListView` horizontal en un `ShaderMask` con gradiente lineal transparente en los extremos (4% y 96%), logrando que los chips se desvanezcan con elegancia visual en vez de cortarse de forma abrupta.

#### 4.2. Resolución de la Ecuación de Stock Inicial vs Movimientos Kardex
* **En el Flujo de Creación de Productos (`product_repository.dart`):**
  * Al insertar una nueva presentación en `insertPresentation`, `saveFullProductTransaction` o `editFullProductTransaction`: si `stock_actual > 0`, se inserta de manera automática el registro génesis en `stock_ledger`:
    * `tipo_transaccion`: `'INVENTARIO_INICIAL'`.
    * `cantidad`: `stock_actual`.
    * `costo_unitario`: `costo_unitario_calculado`.
    * `precio_venta`: `precio_venta_final`.
    * `fecha_registro`: `DateTime.now().toIso8601String()`.
* **En la Pantalla de Trazabilidad (`audit_trail_screen.dart`):**
  * Para productos preexistentes creados antes de este registro, el sistema calcula el stock base:
    `int stockInicial = _currentStock - (_totalEntradas - _totalSalidas);`
  * Si `stockInicial > 0` y no existe un evento explícito en el ledger, se presenta un badge o renglón explicativo:
    `"Stock Inicial: 56 und • Entradas: +28 und • Salidas: -64 und = Actual: 20 und"`, eliminando cualquier duda sobre la coherencia matemática del inventario.

#### 4.3. NUEVA CAPACIDAD: Trazabilidad Integral de Descuentos por Variante
* **Intercepción en Base de Datos (`product_repository.dart`):**
  * Dentro de la transacción central `_updatePresentationTxn`, se auditan las variaciones en las columnas de oferta:
    `precio_oferta`, `tipo_descuento`, `valor_descuento`.
  * Se detectan y persisten tres eventos clave en la tabla `product_history`:
    1. **`DESCUENTO_ACTIVADO`:**
       * *Condición:* `old['precio_oferta'] == null` o `<= 0`, y nuevo `precio_oferta > 0`.
       * *Registro:* `entidad_tipo: 'PRESENTACION'`, `campo_modificado: 'descuento'`, `valor_anterior: 'Sin descuento'`, `valor_nuevo: '$tipoDescuento: $valorDescuento (Oferta: S/ $precioOferta)'`.
    2. **`DESCUENTO_MODIFICADO`:**
       * *Condición:* Tanto el valor anterior como el nuevo tenían oferta activa, pero cambió el porcentaje, monto o precio resultante.
       * *Registro:* `campo_modificado: 'descuento'`, `valor_anterior: '$oldResumen'`, `valor_nuevo: '$newResumen'`.
    3. **`DESCUENTO_ELIMINADO`:**
       * *Condición:* Había oferta activa y se actualiza con `precio_oferta == null` o `<= 0` (o `oferta == -1`).
       * *Registro:* `campo_modificado: 'descuento'`, `valor_anterior: '$oldResumen'`, `valor_nuevo: 'Desactivado (Regreso a precio de lista S/ $precioRegular)'`.
* **Procesamiento de Negocio (`inventory_intelligence_service.dart`):**
  * En `getAuditTrail`, se añade soporte para `accion == 'descuento'`:
    * Se asigna el icono distintivo `Icons.local_offer_rounded` y color temático magenta / coral (`Color(0xFFE11D48)`).
    * Se generan etiquetas legibles para usuario final: `"Descuento Activado"`, `"Oferta Modificada"`, `"Descuento Retirado"`.
* **Visualización en Línea de Tiempo (`audit_trail_screen.dart`):**
  * Se añade el filtro de eventos: `"🏷️ Descuentos ($count)"` o se integra dentro de `"💰 Precios y Ofertas"`.
  * Se diseña una tarjeta de hito temporal atractiva que muestra con claridad el cambio:
    `[20% OFF] → [S/ 12.00 Precio Final]` o `[Descuento Eliminado] → [Precio Normal S/ 15.00]`.

---

## 4. METODOLOGÍA: LOOP AUTÓNOMO CONTINUO Y ÁRBITRO INTERNO ADVERSARIAL

Durante toda la ejecución de este proyecto aplicaremos el marco de trabajo **Loop Autónomo Continuo + Árbitro Interno Adversarial**:

```
 ┌──────────────────────────────────────────────────────────┐
 │                  CICLO DEL LOOP AUTÓNOMO                 │
 └────────────────────────────┬─────────────────────────────┘
                              ▼
        ┌──────────────────────────────────────────┐
        │ 1. Implementación de Fase en Código      │
        └─────────────────────┬────────────────────┘
                              ▼
        ┌──────────────────────────────────────────┐
        │ 2. Ejecución de Pruebas Unitarias & Widget│
        └─────────────────────┬────────────────────┘
                              ▼
        ┌──────────────────────────────────────────┐
        │ 3. Análisis de Flutter Analyze & Lints   │
        └─────────────────────┬────────────────────┘
                              ▼
        ┌──────────────────────────────────────────┐
        │ 4. Evaluación del Árbitro Adversarial    │
        └──────┬────────────────────────────┬──────┘
               │ (Rechazo con Objeción)     │ (Aprobación 100%)
               ▼                            ▼
        ┌──────────────┐             ┌─────────────────────┐
        │ Auto-Fix     │             │ Avance a Siguiente  │
        │ Corrección   │             │ Fase del Plan       │
        └──────────────┘             └─────────────────────┘
```

### Reglas Inviolables del Árbitro Adversarial:
1. **Regla de Cero Regresiones:** Ningún cambio en `product_repository.dart` puede alterar las transacciones existentes de ventas (`sales_service.dart`), escáner de facturas (`scanner_batch_saver.dart`) ni cotizaciones (`quotation_service.dart`).
2. **Regla de Blindaje Anti-Rebote:** No se aceptarán implementaciones de scroll retráctil que utilicen hacks con `Timer` o `setState` descontrolados que causen saltos de offset o parpadeo visual al hacer scroll.
3. **Regla de Integridad de Precios:** Los filtros de micro-redondeo flotante (`abs() < 0.005`) deben mantenerse estrictamente para evitar que diferencias numéricas espurias generen falsos eventos en el historial.
4. **Regla de Responsividad 360dp:** Todos los widgets modificados (tarjetas de abastecimiento, modales, resúmenes) deben probarse contra viewports móviles estrechos (320–360dp) verificando cero desbordamientos amarillos/negros (`A RenderFlex overflowed`).

---

## 5. PLAN DE PRUEBAS AUTOMATIZADAS Y CRITERIOS DE ACEPTACIÓN

Se construirá un archivo de pruebas dedicado:
`app_movil/test/restock_and_audit_discounts_refinement_test.dart`

### Casos de Prueba Críticos:
* **T-01:** Verificación de estado Tri-State (`allVisibleSelected`, `someVisibleSelected`, `none`) en `SmartRestockScreen`.
* **T-02:** Validación de que "Seleccionar Todos" en la vista de reabastecimiento solo selecciona ítems con déficit de stock (`status != 'saludable'` o `suggestedQty > 0`) y no infla la OC con productos saludables.
* **T-03:** Verificación de persistencia transaccional en `product_history` al aplicar, modificar y eliminar un descuento sobre una presentación de producto.
* **T-04:** Verificación del registro de `INVENTARIO_INICIAL` en `stock_ledger` al crear una presentación con stock mayor a cero.
* **T-05:** Auditoría matemática en `AuditTrailScreen`: conciliación perfecta entre stock inicial, entradas, salidas y stock final.
* **T-06:** Test de layout y renderizado responsivo a 360dp de ancho sin desbordamientos de texto ni colisión de botones.
* **T-07:** Ejecución limpia de `flutter analyze` con cero advertencias o errores en los archivos modificados.

---

## 6. RESUMEN DE ARCHIVOS QUE SERÁN MODIFICADOS

| Archivo | Rol en el Sistema | Modificación Principal |
| :--- | :--- | :--- |
| `app_movil/lib/features/analytics/screens/smart_restock_screen.dart` | Pantalla de Abastecimiento | Lógica Tri-State de selección masiva, Slivers retráctiles anti-rebote, rediseño de cabecera y tarjetas, limpieza de AppBar y modal de costo. |
| `app_movil/lib/features/analytics/screens/audit_trail_screen.dart` | Pantalla de Trazabilidad | Padding en modal, fila única de balance de stock, ShaderMask en chips y renderizado de hitos de descuentos. |
| `app_movil/lib/features/analytics/services/inventory_intelligence_service.dart` | Servicio de Inteligencia de Inventario | Soporte para eventos de descuento en `getAuditTrail` y optimización de ordenamiento. |
| `app_movil/lib/features/catalog/repositories/product_repository.dart` | Repositorio Central de Catálogo | Registro de `INVENTARIO_INICIAL` en `stock_ledger` y auditoría de cambios de descuento en `product_history`. |
| `app_movil/test/restock_and_audit_discounts_refinement_test.dart` | Suite de Pruebas Automatizadas | Tests de regresión, lógica Tri-State y trazabilidad de ofertas. |

---

## 7. CONCLUSIÓN Y PRÓXIMOS PASOS

Este plan ataca de raíz todos los problemas detectados en las pruebas reales, respetando la arquitectura preexistente del sistema y elevando la calidad de la aplicación a los más altos estándares móviles.

**Próximo paso tras la aprobación:** Iniciar de forma autónoma con la **Fase 1 (Lógica Tri-State y Sincronización en Abastecimiento)** y avanzar sucesivamente bajo el arbitraje adversarial.
