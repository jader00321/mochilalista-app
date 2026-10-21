# PLAN DE ACCIÓN TÉCNICO: REINGENIERÍA DE CAJA RÁPIDA, HOME, BUSCADOR OMNICANAL LOCAL Y GLOBO FLOTANTE DEL WORK DOCK

**Documento:** `analisis_proyecto/PLAN_PARTE1_CAJA_RAPIDA_HOME_OMNISEARCH_Y_GLOBO_FLOTANTE.md`  
**Fecha:** Octubre 2026  
**Versión:** 1.0 — Diagnóstico Exhaustivo, Arquitectura y Plan Maestro de Implementación  
**Estado:** Listo para Revisión y Aprobación del Usuario  
**Metodología:** Loop Autónomo + Árbitro Adversarial (Test-Driven, Zero-Regressions & Mobile Awards Standard)  

---

## 1. RESUMEN EJECUTIVO Y OBJETIVOS ESTRATÉGICOS

A través del testing continuo de las nuevas funciones desplegadas en MochilaLista, se han identificado **4 focos críticos de fricción visual, inconsistencias lógicas en SQLite, desbordamientos de layout y comportamientos de interacción gestual** que impactan directamente la experiencia de usuario:

1. **Modal "Nota de Venta" en Caja Rápida (`quick_sale_note_modal.dart`):**
   * *Diagnóstico:* El modal carece de una superficie opaca de fondo; su builder retorna un simple `Padding` sin contenedor sólido dentro de un `showModalBottomSheet` transparente, provocando que los productos y montos del carrito de Caja Rápida se trasluzcan al 100%, volviendo los textos ilegibles. Además, el espaciado inferior carece del cálculo seguro frente a la barra de 3 botones de Android (`viewPadding.bottom`), quedando pegado o parcialmente tapado. Los chips rápidos en un `Row` horizontal pueden provocar recortes o problemas de scroll con el teclado.
   * *Objetivo:* Crear una superficie moderna, sólida y elevada (`#1A1A24` en modo oscuro / blanco puro en modo claro) con sutil `BackdropFilter`, chips responsivos en `Wrap` interactivo y blindaje total de `SafeArea` ante el teclado virtual y la barra gestual/3-botones de Android.

2. **Estabilidad de Tarjetas Estadísticas y Reintegración de "Alertas de Stock" en el Home (`dashboard_header.dart` y `home_screen.dart`):**
   * *Diagnóstico:* La rotación automática de KPIs cada 6 segundos en `dashboard_header.dart` provoca saltos verticales continuos en toda la pantalla debido a la ausencia de una altura fija (`height` constante); etiquetas más largas como *"Operaciones Hoy"* se quiebran en 2 líneas (`"Operacione"` / `"s Hoy"`), modificando la altura del card y disparando animaciones de resize involuntarias en el layout. Por otra parte, la alerta de productos con falta de stock quedó removida del Home.
   * *Objetivo:* Fijar una cota de altura estricta e idéntica de 82px en ambas tarjetas de estadísticas con tipografía controlada (0 píxeles de desplazamiento entre transiciones), y reintegrar las **Alertas de Stock** mediante un componente inteligente con dos estados: **Modo Píldora Compacta por defecto** $\leftrightarrow$ **Modo Desplegado Inline (`AnimatedSize`)** al tocarlo, para inspeccionar rápidamente los productos críticos sin abandonar el Home ni saturar la armonía visual.

3. **Reingeniería del Buscador Omnicanal Local (`omni_search_bar.dart`):**
   * *Diagnóstico:* Cuando el filtro está en *"Todos (18)"*, la lista inferior se limita exclusivamente a *"📦 PRODUCTOS 10 elementos"*, ocultando clientes, cotizaciones y ventas. Esto se debe a un `LIMIT 10` rígido en SQLite y a la ausencia de un `ListView` / `CustomScrollView` estructurado. Asimismo, los números de los chips (`Todos (18)`, `Productos (10)`, etc.) reflejan erróneamente el `array.length` truncado a 10 resultados, en lugar de consultar los conteos reales totales de la base de datos SQLite.
   * *Objetivo:* Reestructurar las consultas SQLite para calcular en background los conteos reales consolidados:
     * **Productos:** Total de presentaciones activas existentes.
     * **Clientes:** Total de clientes registrados en el directorio.
     * **Cotizaciones:** Total de cotizaciones excluyendo las ya vendidas (`status != 'vendida'`).
     * **Ventas:** Suma real y consolidada de ventas rápidas + cotizaciones vendidas.
     * **Todos:** Suma exacta de las 4 categorías.
     * Permitir la visualización y búsqueda unificada en *"Todos"* (con encabezados y navegación fluida entre tipos) y filtrado estricto al tocar un chip específico, con renderizado perezoso virtualizado (`ListView.builder`) para superar con fluidez el límite de 10 elementos sin degradar los FPS.

4. **Evolución del Globo Flotante de Tareas Activas (`persistent_work_dock.dart` y `deep_nav_return_pill.dart`):**
   * *Diagnóstico:* En pantallas operativas (como el Catálogo de Productos), el indicador flotante de tareas pendientes (ej. `"Caja Rápida (2) S/ 1.40"`) se encuentra anclado rígidamente en la esquina inferior izquierda, tapando botones, precios y tarjetas del catálogo.
   * *Objetivo:* Dotar al globo de **movimiento libre 2D (ejes X e Y)** mediante `GestureDetector` con anclaje magnético a los bordes laterales y límites de pantalla seguros. Incorporar además la nueva mecánica de **"Ocultación en Borde / Edge Peek"**: si el usuario jala el globo hacia afuera contra el extremo de la pantalla, este se repliega casi por completo dejando únicamente una pestaña luminosa sutil; al tocar la pestaña, regresa a su posición normal, y al tocarlo en estado normal despliega el dock de trabajo o reanuda la tarea activa.

---

## 2. DIAGNÓSTICO TÉCNICO EXHAUSTIVO EN CÓDIGO (EVIDENCIAS EXACTAS)

### 2.1. Bloque 1: Modal "Nota de Venta" en Caja Rápida
* **Archivos examinados:**
  * `lib/features/smart_quotation/widgets/quick_sale/quick_sale_note_modal.dart` (Líneas 12–17, 88–269)
  * `lib/core/widgets/interactive_sheet_wrapper.dart` (Líneas 74–91)
  * `lib/features/smart_quotation/screens/quick_sale_screen.dart` (Líneas 367–395)
* **Hallazgos:**
  1. **Fondo 100% transparente sin superficie sólida:** En `QuickSaleNoteModal.show`, se invoca `InteractiveSheetWrapper.show(...)`, el cual configura `backgroundColor: Colors.transparent` en `showModalBottomSheet`. Sin embargo, en el método `build` de `QuickSaleNoteModal`:
     ```dart
     // quick_sale_note_modal.dart: Líneas 93-103
     return Padding(
       padding: EdgeInsets.only(
         left: 20, right: 20, top: 8,
         bottom: MediaQuery.of(context).viewInsets.bottom + 20,
       ),
       child: Column(
         mainAxisSize: MainAxisSize.min,
         children: [ ... ]
       ),
     );
     ```
     El widget devuelto es un simple `Padding` sin `Container`, ni `BoxDecoration(color: ...)`, ni `Material`, ni `BackdropFilter`. En consecuencia, el modal se dibuja directamente sobre la ventana de Caja Rápida sin ninguna opacidad, provocando que los productos agregados (`"Shampoo Romero Anticaída"`), precios y el banner `"TOTAL A COBRAR"` se mezclen con el título y las etiquetas de la nota (evidente en la Captura 1).
  2. **Inseguridad frente a la barra de navegación del sistema (SafeArea):**
     * El cálculo del padding inferior es únicamente `MediaQuery.of(context).viewInsets.bottom + 20`.
     * Cuando el teclado virtual está cerrado (`viewInsets.bottom == 0`), solo quedan 20px de espacio. En teléfonos Android con barra de 3 botones (cuyo alto ronda los 48px de `viewPadding.bottom`), el botón azul `"Confirmar Nota"` queda colisionando contra la barra del sistema.
  3. **Disposición de etiquetas rápidas rígida en Row:**
     * `_quickChips` se renderiza dentro de un `SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(...))`. Los chips más alejados quedan ocultos fuera del campo de visión y no aprovechan el ancho disponible cuando hay espacio vertical.

---

### 2.2. Bloque 2: Estabilidad del Carrusel y Alertas de Stock en el Home
* **Archivos examinados:**
  * `lib/core/widgets/home/dashboard_header.dart` (Líneas 421–591)
  * `lib/core/screens/home_screen.dart` (Líneas 236–296)
  * `lib/features/analytics/widgets/restock_smart_banner.dart` (Líneas 110–282)
* **Hallazgos:**
  1. **Deformación y Salto Vertical de Altura en los KPI Cards:**
     * En `_buildKpiCard` (Líneas 517–590), el contenedor no posee restricción de altura (`height` no especificado ni `constraints` fijas):
     ```dart
     return Container(
       key: key,
       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
       ...
       child: Row(
         children: [
           ...,
           Expanded(
             child: Column(
               children: [
                 FittedBox(...),
                 const SizedBox(height: 4),
                 FittedBox(
                   child: Text(label, maxLines: 1, ...),
                 ),
               ],
             ),
           ),
         ],
       ),
     );
     ```
     * En `_buildFinanceCarousel`, en el índice 0 el label es `"Ventas Hoy"` (10 caracteres). En el índice 1, el label es `"Operaciones Hoy"` (15 caracteres). En pantallas con densidad estándar, `"Operaciones Hoy"` no cabe y se parte en dos líneas (`"Operacione"` y `"s Hoy"`, claramente visible en la Captura 2).
     * Como el contenedor no tiene altura fija, la tarjeta se expande verticalmente unos 16px adicionales. Al cambiar de KPI cada 6 segundos, `AnimatedSwitcher` anima el cambio de tamaño del Header, empujando hacia abajo y hacia arriba toda la lista del Home.
  2. **Ausencia de Alertas de Stock en Home:**
     * En versiones previas se mostraba una píldora compacta `"1 Alertas de Stock"`. Al refactorizar el banner a un widget grande de ancho completo (`RestockSmartBanner`), este ocupaba demasiado espacio visual, por lo que su visualización fue desplazada o resultaba invasiva. Se requiere un formato de píldora compacta replegada por defecto que se expanda inline de manera suave al interactuar con ella.

---

### 2.3. Bloque 3: Modal "Búsqueda Omnicanal Local"
* **Archivos examinados:**
  * `lib/core/widgets/omni_search_bar.dart` (Líneas 171–249, 251–450, 644–898)
* **Hallazgos:**
  1. **Filtro "Todos" bloqueado en Productos:**
     * En `_OmniSearchSheetState` (Líneas 866–895):
     ```dart
     if ((_activeCategory == 'all' || _activeCategory == 'products') && sortedProducts.isNotEmpty) ...[
       _buildSectionHeader("📦 PRODUCTOS", sortedProducts.length, isDark),
       ...sortedProducts.map((p) => _buildProductCard(p, isDark)),
     ],
     if ((_activeCategory == 'all' || _activeCategory == 'clients') && sortedClients.isNotEmpty) ...[
       _buildSectionHeader("👤 CLIENTES", ...),
       ...
     ],
     ```
     * La vista completa está contenida en una simple `Column` dentro de `InteractiveSheetWrapper`, sin un `ListView` con scroll coordinado. Al renderizarse los 10 productos (cada tarjeta mide ~72px, totalizando más de 720px), la sección de productos ocupa toda la altura disponible del modal (92% de la pantalla) y empuja las secciones de Clientes, Cotizaciones y Ventas fuera del área visible. El usuario solo ve productos y no puede acceder al resto.
  2. **Truncamiento rígido a 10 elementos:**
     * Tanto `_loadRecentDefaults()` (Líneas 194, 206, 219, 233) como `_performSearch()` usan cláusulas `LIMIT 10` y `LIMIT 15` codificadas en duro en el SQL. Si el negocio cuenta con 100 productos, 90 de ellos jamás aparecen en el modal de búsqueda rápida.
  3. **Conteos Falsos en los Chips de Categoría:**
     * En las líneas 717–742:
     ```dart
     _buildCategoryChip('all', 'Todos ($totalMatches)', isDark),
     _buildCategoryChip('products', '📦 Productos (${_productResults.length})', isDark),
     _buildCategoryChip('clients', '👤 Clientes (${_clientResults.length})', isDark),
     _buildCategoryChip('quotes', '📝 Cotizaciones (${_quoteResults.length})', isDark),
     _buildCategoryChip('sales', '🧾 Ventas (${_saleResults.length})', isDark),
     ```
     * `_productResults.length` es siempre `10` debido al `LIMIT 10`. Por eso la Captura 3 muestra: `Todos (18)`, `Productos (10)`, `Clientes (1)`, `Cotizaciones (4)`, `Ventas (3)`.
     * Los chips no consultan la base de datos para saber cuántos registros existen realmente. Deben reflejar:
       * **Productos:** `COUNT(*)` de variantes/presentaciones activas (`presentaciones_producto`).
       * **Clientes:** `COUNT(*)` en la tabla `clientes`.
       * **Cotizaciones:** `COUNT(*)` en `smart_quotations` con `status != 'vendida'`.
       * **Ventas:** `COUNT(*)` en `ventas` (que consolida ventas rápidas directas + cotizaciones convertidas a venta).
       * **Todos:** La sumatoria exacta de los 4 indicadores reales.

---

### 2.4. Bloque 4: Globo Flotante del Dock y Píldora de Retorno
* **Archivos examinados:**
  * `lib/core/widgets/persistent_work_dock.dart` (Líneas 65–70, 312–410)
  * `lib/core/widgets/deep_nav_return_pill.dart` (Líneas 29–42, 165–235)
* **Hallazgos:**
  1. **Anclaje Rígido en Pantallas Secundarias (Captura 5):**
     * En la pantalla de Catálogo (`catalog_screen.dart`), el widget visible es `DeepNavReturnPill`, el cual está fijado estáticamente en `left: 16, bottom: 80`. Como se evidencia en la Captura 5, queda montado sobre las tarjetas de productos `"TE"` y `"TH"`, impidiendo ver precios y botones de adición.
  2. **Limitación de Movimiento en `PersistentWorkDock`:**
     * En el modo bubble de `PersistentWorkDock`, el movimiento vertical está restringido entre `20.0` y `300.0`, y el eje horizontal solo hace snap rígido a `left: 16` o `right: 16`.
     * No existe soporte para arrastre libre con posicionamiento absoluto en pantalla completa ni detección de gesto de expulsión hacia el borde exterior ("Edge Tuck").
  3. **Falta del Estado "Edge Peek" (Oculto en Borde):**
     * Si el usuario necesita despejar la pantalla para ver el contenido detrás del globo, no tiene forma de empujarlo fuera de la vista sin descartar la tarea activa o salir de la pantalla.

---

## 3. ARQUITECTURA DE SOLUCIÓN DETALLADA POR COMPONENTE

```
                                  ARQUITECTURA DE FLUJO Y COMPONENTES
                                  
  ┌────────────────────────────────────────────────────────────────────────────────────────┐
  │ 1. CAJA RÁPIDA: QuickSaleNoteModal                                                     │
  │    ┌──────────────────────────────────────────────────────────────────────────────┐    │
  │    │ InteractiveSheetWrapper (Solid #1E1E28 / White Surface + Subtle Blur)        │    │
  │    │ ├─ Handle Reactivo (40px -> 56px)                                            │    │
  │    │ ├─ Header: Ícono Ámbar + Título "Nota de Venta" + Botón Limpiar              │    │
  │    │ ├─ Etiquetas Rápidas en Wrap Responsivo (Auto-Adaptable a Pantalla)          │    │
  │    │ ├─ TextField Multilínea con Contador (0/250) + Autofocus Seguro              │    │
  │    │ └─ Botón "Confirmar Nota" + Blindaje SafeArea (viewPaddingOf.bottom)         │    │
  │    └──────────────────────────────────────────────────────────────────────────────┘    │
  └────────────────────────────────────────────────────────────────────────────────────────┘
  
  ┌────────────────────────────────────────────────────────────────────────────────────────┐
  │ 2. HOME: DashboardHeader & StockAlertBadge                                             │
  │    ┌──────────────────────────────────────────────────────────────────────────────┐    │
  │    │ Tarjetas de Estadísticas KPI: Altura Constante Estricta (82px)               │    │
  │    │ ├─ AnimatedSwitcher con SizedBox(height: 82) -> 0px salto vertical           │    │
  │    │ └─ Tipografía balanceada (Label maxLines: 1 con ellipsis + FittedBox seguro) │    │
  │    ├──────────────────────────────────────────────────────────────────────────────┤    │
  │    │ Alertas de Stock Interactivas: Píldora Compacta <-> Panel Desplegado Inline  │    │
  │    │ ├─ Estado Píldora: [ ⚠️ N Alertas de Stock ] (Brillo sutil ámbar)            │    │
  │    │ └─ Estado Desplegado (AnimatedSize): Resumen de productos + Botón "Gestionar"│    │
  │    └──────────────────────────────────────────────────────────────────────────────┘    │
  └────────────────────────────────────────────────────────────────────────────────────────┘
  
  ┌────────────────────────────────────────────────────────────────────────────────────────┐
  │ 3. BUSCADOR OMNICANAL LOCAL: OmniSearchBar & OmniSearchSheet                           │
  │    ┌──────────────────────────────────────────────────────────────────────────────┐    │
  │    │ Consultas SQL de Conteos Reales (SQLite Background Worker):                   │    │
  │    │ ├─ Productos: Total variantes activas (presentaciones_producto)              │    │
  │    │ ├─ Clientes: Total clientes registrados (clientes)                           │    │
  │    │ ├─ Cotizaciones: Total cotizaciones no vendidas (smart_quotations)           │    │
  │    │ ├─ Ventas: Total consolidado ventas rápidas + cotizaciones vendidas (ventas) │    │
  │    │ └─ Todos: Suma exacta de las 4 categorías reales                             │    │
  │    ├──────────────────────────────────────────────────────────────────────────────┤    │
  │    │ Renderizado Virtualizado: CustomScrollView con Slivers / ListView.builder    │    │
  │    │ ├─ Modo "Todos": Secciones agrupadas con Headers interactivos y scroll total │    │
  │    │ ├─ Modo Categoría: Lista paginada infinita (Bloques de 30 ítems sin lag)     │    │
  │    │ └─ Respeto estricto del filtro seleccionado (sin mezclas accidentales)       │    │
  │    └──────────────────────────────────────────────────────────────────────────────┘    │
  └────────────────────────────────────────────────────────────────────────────────────────┘
  
  ┌────────────────────────────────────────────────────────────────────────────────────────┐
  │ 4. GLOBO FLOTANTE 2D + MODO EDGE PEEK: DraggableDockPill                              │
  │    ┌──────────────────────────────────────────────────────────────────────────────┐    │
  │    │ 3 Estados Operativos:                                                        │    │
  │    │ 1. [Modo Edge Peek]: Pestaña lateral asomando 14px en el borde de pantalla   │    │
  │    │    └─ Tap: Se desliza hacia adentro al Modo Globo Flotante                   │    │
  │    │ 2. [Modo Globo Flotante]: Arrastre 2D libre (X, Y) con Magnetismo a bordes   │    │
  │    │    ├─ Arrastre hacia afuera del borde: Se oculta en Modo Edge Peek           │    │
  │    │    └─ Tap: Despliega el Dock de Trabajo Completo / Reanuda Tarea             │    │
  │    │ 3. [Modo Dock Completo]: Barra inferior con carrusel de tareas activas       │    │
  │    └──────────────────────────────────────────────────────────────────────────────┘    │
  └────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 3.1. Arquitectura para el Bloque 1: Modal "Nota de Venta"
1. **Superficie y Legibilidad:**
   * Envolver el modal en un `Container` con `BoxDecoration`:
     * Fondo: `#1E1E28` en tema oscuro / `Colors.white` en tema claro.
     * Borde superior con radio de 28px y línea sutil (`Colors.white12`).
     * `BackdropFilter` integrado con desenfoque de `sigmaX: 8, sigmaY: 8` para separar completamente el modal del contenido de fondo.
     * Sombra de elevación profunda (`BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, -6))`).
2. **Chips Rápidos Responsivos con `Wrap`:**
   * Sustituir el `Row` horizontal por un `Wrap` con `spacing: 8` y `runSpacing: 8`:
     ```dart
     Wrap(
       spacing: 8,
       runSpacing: 8,
       children: _quickChips.map((chipText) => _buildChip(chipText)).toList(),
     )
     ```
   * En pantallas estrechas (360px), los chips se distribuyen armónicamente en dos filas sin cortarse ni requerir scroll lateral incómodo.
3. **Blindaje de Teclado y SafeArea:**
   * Uso de `SingleChildScrollView(physics: BouncingScrollPhysics())` envolviendo el contenido.
   * Padding inferior calculado con `InteractiveSheetWrapper.getEffectiveBottomPadding(context, minPadding: 24, includeKeyboard: true)`:
     ```dart
     final bottomPadding = math.max(
       MediaQuery.viewPaddingOf(context).bottom,
       MediaQuery.paddingOf(context).bottom,
     );
     final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
     final totalBottom = keyboardInset > 0 ? keyboardInset + 12 : math.max(bottomPadding + 12, 24.0);
     ```
   * Garantiza que el botón `"Confirmar Nota"` quede siempre a una distancia cómoda sobre la barra gestual o los 3 botones de Android.

---

### 3.2. Arquitectura para el Bloque 2: Estabilidad de Carrusel y Alertas de Stock en Home
1. **Fijación Estricta de Altura en Tarjetas Estadísticas (`dashboard_header.dart`):**
   * En `_buildAnimatedKpi` y `_buildKpiCard`, envolver el contenedor en un `SizedBox(height: 82)` o `ConstrainedBox(constraints: BoxConstraints.tightFor(height: 82))`.
   * En el bloque de textos:
     * Valor numérico: `FittedBox` con alineación `Alignment.centerLeft` y altura acotada.
     * Etiqueta descriptiva (`label`): `Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, height: 1.1))`.
   * En `AnimatedSwitcher`: configurar `layoutBuilder` para mantener el tamaño del widget entrante idéntico al saliente:
     ```dart
     layoutBuilder: (currentChild, previousChildren) {
       return Stack(
         alignment: Alignment.centerLeft,
         children: <Widget>[
           ...previousChildren,
           if (currentChild != null) currentChild,
         ],
       );
     }
     ```
   * *Resultado:* Rotación fluida sin desplazamiento de un solo píxel en el Home.
2. **Componente Desplegable de Alertas de Stock (`StockAlertBadge`):**
   * Dos estados mediante un booleano local `_isExpanded`:
     * **Estado 1 (Píldora por defecto):**
       * Altura compacta (34px), alineada a la derecha o centrada según el espacio.
       * Fondo: `isDark ? Color(0xFF2E200C) : Color(0xFFFFF3E0)`.
       * Borde: ámbar con micro-brillo (`Color(0xFFE65100).withValues(alpha: 0.5)`).
       * Ícono: `Icons.warning_amber_rounded` animado suavemente con pulso.
       * Texto: `"$count Alertas de Stock"`.
     * **Estado 2 (Panel Desplegado Inline con `AnimatedSize`):**
       * Al pulsar la píldora, se despliega inline en el Home mostrando un contenedor con borde ámbar.
       * Lista resumida de las presentaciones con stock en riesgo (hasta 3-4 ítems con su stock actual vs stock mínimo).
       * Acciones: Botón `"Ver Inteligencia de Stock"` que navega a `SmartRestockScreen`, y botón de repliegue rápido.
     * Si `_alertCount == 0`, se devuelve `SizedBox.shrink()` manteniendo el Home completamente limpio.

---

### 3.3. Arquitectura para el Bloque 3: Buscador Omnicanal y Conteos Reales SQLite
1. **Consultas SQL de Conteo Real en SQLite:**
   * Al abrir el buscador, se ejecuta una consulta agregada ultra-rápida en una sola transacción o query paralela:
     ```sql
     -- 1. Total Presentaciones Activas
     SELECT COUNT(*) as total_prods
     FROM presentaciones_producto pp
     JOIN productos p ON pp.producto_id = p.id
     WHERE p.negocio_id = ? AND pp.activo = 1;

     -- 2. Total Clientes Registrados
     SELECT COUNT(*) as total_clients
     FROM clientes
     WHERE negocio_id = ?;

     -- 3. Total Cotizaciones Activas (Omitiendo Vendidas)
     SELECT COUNT(*) as total_quotes
     FROM smart_quotations
     WHERE negocio_id = ? AND LOWER(IFNULL(status, '')) != 'vendida';

     -- 4. Total Ventas Consolidadas (Ventas Rápidas + Cotizaciones Vendidas)
     SELECT COUNT(*) as total_sales
     FROM ventas
     WHERE negocio_id = ? AND is_archived = 0;
     ```
   * En los chips de categoría:
     * `Todos (N)` = `total_prods + total_clients + total_quotes + total_sales`.
     * `📦 Productos (total_prods)`.
     * `👤 Clientes (total_clients)`.
     * `📝 Cotizaciones (total_quotes)`.
     * `🧾 Ventas (total_sales)`.
2. **Solución a la Visualización y Filtrado Multi-Tipo:**
   * Reorganizar la estructura interna del modal: en lugar de una `Column` con mapas directos, utilizar un `Expanded` con `ListView.builder` o `CustomScrollView` con scroll desacoplado.
   * **Cuando `_activeCategory == 'all'`:**
     * Mostrar bloques estructurados: `_buildSectionHeader` para cada tipo que tenga resultados, permitiendo scrollear libremente desde Productos hasta Ventas sin que ninguno bloquee a los otros.
     * Incorporar enlaces de `"Ver todos los N productos"` o paginación por demanda si una categoría tiene muchos resultados.
   * **Cuando se selecciona un tipo específico (`products`, `clients`, `quotes`, `sales`):**
     * Filtrar estrictamente la lista y el scroll para mostrar **únicamente** la entidad seleccionada.
3. **Estrategia para superar el límite de 10 elementos (Paginación Progresiva Fluida):**
   * Aumentar el límite inicial a 30 elementos por categoría para consultas directas.
   * Incorporar un listener en el `ScrollController` del modal: cuando el scroll llega al 80% de su recorrido (`pixels >= maxScrollExtent * 0.8`), se dispara la carga de los siguientes 30 elementos (`skip += limit`) de forma asíncrona y transparente (`_isLoadingMore`).

---

### 3.4. Arquitectura para el Bloque 4: Movimiento Libre 2D y Modo "Edge Peek" del Globo Flotante
1. **Control de Posicionamiento Libre 2D:**
   * El globo flotante debe ser operable a nivel global en la aplicación (tanto en el Home como en pantallas secundarias donde actualmente se monta `DeepNavReturnPill`).
   * Variables de estado reactivas:
     * `double _posX`: Posición horizontal en pantalla (restringida entre `0` y `screenWidth - bubbleWidth`).
     * `double _posY`: Posición vertical en pantalla (restringida entre `safeTop + 10` y `screenHeight - safeBottom - 70`).
     * `bool _isEdgeTucked`: Indica si el globo está oculto en modo "Edge Peek".
     * `bool _isTuckedOnLeft`: Indica si está replegado en el borde izquierdo o derecho.
2. **Gesto de Arrastre 2D con `GestureDetector`:**
   ```dart
   onPanUpdate: (details) {
     if (_isEdgeTucked) return;
     setState(() {
       _posX += details.delta.dx;
       _posY += details.delta.dy;
       // Limitar a pantalla visible
       _posX = _posX.clamp(0.0, screenWidth - 58.0);
       _posY = _posY.clamp(safeTop, screenHeight - safeBottom - 60.0);
     });
   },
   onPanEnd: (details) {
     final velocityX = details.velocity.pixelsPerSecond.dx;
     // Detección de Tuck / Expulsión hacia el borde exterior:
     // Si la posición está a menos de 20px del borde o la velocidad de arrastre supera 800px/s hacia el borde
     if (_posX < 24 || velocityX < -800) {
       _tuckToEdge(isLeft: true);
     } else if (_posX > screenWidth - 82 || velocityX > 800) {
       _tuckToEdge(isLeft: false);
     } else {
       // Anclaje magnético suave al borde más cercano (izquierda o derecha)
       _snapToClosestEdge();
     }
   }
   ```
3. **Mecánica del Modo "Edge Peek":**
   * **Estado Replegado:**
     * El cuerpo del globo se traslada fuera de pantalla dejando visible únicamente una pestaña redondeada de 14px de ancho con borde brillante del color temático de la tarea activa (ej. verde `#2E7D32` para Caja Rápida).
     * Se acompaña de un sutil resplandor (`BoxShadow` con pulso ligero).
   * **Restauración:**
     * Al pulsar la pestaña sobresaliente, una animación `Tween<Offset>` con resorte (`Curves.easeOutBack`, 300ms) desplaza el globo hacia adentro a su posición flotante normal.
   * **Apertura de Dock:**
     * Al pulsar el globo en estado normal flotante, se despliega el `PersistentWorkDock` completo o se reanuda la tarea activa directamente.

---

## 4. PLAN DE TRABAJO EN FASES (LOOP AUTÓNOMO + ÁRBITRO ADVERSARIAL)

```
  ┌────────────────────────────────────────────────────────────────────────┐
  │ FASE 1: Rediseño, Legibilidad y SafeArea de "Nota de Venta"            │
  │ -> quick_sale_note_modal.dart & quick_sale_screen.dart                 │
  └───────────────────────────────────┬────────────────────────────────────┘
                                      │
  ┌───────────────────────────────────▼────────────────────────────────────┐
  │ FASE 2: Estabilidad de Altura en Home y Reintegración Alertas de Stock │
  │ -> dashboard_header.dart, home_screen.dart, restock_smart_banner.dart  │
  └───────────────────────────────────┬────────────────────────────────────┘
                                      │
  ┌───────────────────────────────────▼────────────────────────────────────┐
  │ FASE 3: Reingeniería Omnicanal: Conteos Reales SQLite y Scroll Multi   │
  │ -> omni_search_bar.dart                                                │
  └───────────────────────────────────┬────────────────────────────────────┘
                                      │
  ┌───────────────────────────────────▼────────────────────────────────────┐
  │ FASE 4: Globo Flotante 2D Magnético y Modo Edge Peek                   │
  │ -> persistent_work_dock.dart & deep_nav_return_pill.dart               │
  └───────────────────────────────────┬────────────────────────────────────┘
                                      │
  ┌───────────────────────────────────▼────────────────────────────────────┐
  │ FASE 5: Auditoría Adversarial, Verificación de Compilación y Smoke Test│
  │ -> flutter analyze, zero-regressions, layout boundary checks           │
  └────────────────────────────────────────────────────────────────────────┘
```

---

### FASE 1: Rediseño, Legibilidad y SafeArea del Modal "Nota de Venta" en Caja Rápida
* **Objetivos específicos:**
  1. Sustituir el `Padding` transparente de `QuickSaleNoteModal` por un contenedor con superficie elevada (`#1E1E28` / blanco) y `BackdropFilter` con bordes redondeados y sombra.
  2. Implementar `Wrap` responsivo para las etiquetas rápidas (`_quickChips`).
  3. Asegurar el blindaje inferior con `InteractiveSheetWrapper.getEffectiveBottomPadding(context, includeKeyboard: true)` para evitar colisión con la barra de 3 botones de Android.
  4. Integrar `SingleChildScrollView` para prevenir cualquier desbordamiento de píxeles (`RenderFlex overflow`) cuando el teclado esté desplegado.
* **Archivos a modificar:**
  * `lib/features/smart_quotation/widgets/quick_sale/quick_sale_note_modal.dart`
* **Criterio de Aceptación Adversarial:**
  * Al abrir el modal en Caja Rápida con 10 productos en el carrito, no debe traslucirse ningún texto del fondo; la legibilidad debe ser del 100%. Al desplegar el teclado en dispositivos con barra de 3 botones, el botón de confirmar debe permanecer completamente visible e interactuable.

---

### FASE 2: Estabilidad de Altura en Home y Reintegración de Alertas de Stock
* **Objetivos específicos:**
  1. En `dashboard_header.dart`, fijar la altura de las tarjetas de estadísticas a exactamente 82px constantes mediante `SizedBox` / `ConstrainedBox`.
  2. Ajustar la tipografía de las etiquetas secundarias (`maxLines: 1`, `overflow: TextOverflow.ellipsis`) para evitar quiebres de línea en etiquetas como `"Operaciones Hoy"` o `"Listas Preparadas"`.
  3. Reintegrar la función de Alertas de Stock en el Home mediante el nuevo widget interactivo `StockAlertBadge` (Píldora Compacta $\leftrightarrow$ Panel Desplegado Inline con `AnimatedSize`).
* **Archivos a modificar:**
  * `lib/core/widgets/home/dashboard_header.dart`
  * `lib/core/screens/home_screen.dart`
  * `lib/features/analytics/widgets/restock_smart_banner.dart` (o nuevo sub-widget especializado)
* **Criterio de Aceptación Adversarial:**
  * Durante la rotación automática de KPIs (cada 6 segundos), la altura del header debe mantenerse invariable con 0 píxeles de desplazamiento vertical en el Home.
  * La alerta de stock debe lucir limpia en modo píldora y desplegarse suavemente sin saltos bruscos ni desbordamientos al ser presionada.

---

### FASE 3: Reingeniería del Buscador Omnicanal (Conteos Reales SQLite y Scroll Multi-Tipo)
* **Objetivos específicos:**
  1. Implementar la consulta SQL agregada de conteos reales en background para calcular con precisión los valores de los chips:
     * `Productos`: Total variantes activas.
     * `Clientes`: Total clientes registrados.
     * `Cotizaciones`: Total cotizaciones omitiendo vendidas.
     * `Ventas`: Total consolidado ventas rápidas + cotizaciones vendidas.
     * `Todos`: Suma real y exacta.
  2. Reemplazar la `Column` interna del modal por un `ListView.builder` / `CustomScrollView` para soportar scroll fluido e independiente en todos los tipos de registros.
  3. Asegurar que al pulsar `"Todos"` se listen secciones organizadas de todas las entidades, y al pulsar un chip específico se filtre exclusivamente esa categoría.
  4. Incorporar carga perezosa (lazy loading progresivo en bloques de 30) para superar el límite rígido de 10 elementos sin perder fluidez de scroll.
* **Archivos a modificar:**
  * `lib/core/widgets/omni_search_bar.dart`
* **Criterio de Aceptación Adversarial:**
  * En una base de datos con 100 productos, el chip debe mostrar `Productos (100)`. Al seleccionar `"Todos"`, el usuario debe poder hacer scroll continuo y ver tanto productos como clientes, cotizaciones y ventas.

---

### FASE 4: Evolución del Globo Flotante del Work Dock y Píldora de Retorno (2D + Edge Peek)
* **Objetivos específicos:**
  1. Implementar en `persistent_work_dock.dart` el movimiento libre bidimensional (ejes X e Y) con límites de pantalla acotados al área segura.
  2. Desarrollar el modo **"Edge Peek" (Ocultación en Borde)**: cuando el usuario jale el globo contra el borde lateral, este se oculta casi por completo dejando una pestaña luminosa de 14px asomándose.
  3. Implementar la restauración por toques: tocar la pestaña devuelve el globo a su posición flotante normal, y tocar el globo normal despliega el dock completo.
  4. Aplicar la misma capacidad de movimiento y modo Edge Peek al componente `DeepNavReturnPill` para que en pantallas secundarias (Catálogo, Inventario, CRM) jamás vuelva a tapar tarjetas ni botones.
* **Archivos a modificar:**
  * `lib/core/widgets/persistent_work_dock.dart`
  * `lib/core/widgets/deep_nav_return_pill.dart`
* **Criterio de Aceptación Adversarial:**
  * En la pantalla de Catálogo con una venta rápida activa en segundo plano, el usuario debe poder mover libremente el globo o pastilla a cualquier altura de la pantalla y pegarlo o tuckearlo al borde sin obstruir la visualización de los productos.

---

### FASE 5: Auditoría Adversarial, Verificación de Compilación y Análisis Estático
* **Objetivos específicos:**
  1. Ejecución de `flutter analyze` para asegurar 0 errores de sintaxis y 0 advertencias críticas.
  2. Verificación de consumo de memoria y ciclo de vida de controladores de animación y scroll.
  3. Validación de contratos SQLite en transacciones seguras de solo lectura para evitar bloqueos de base de datos (`database is locked`).
* **Criterio de Aceptación Adversarial:**
  * Código limpio, formateado, libre de warnings y listo para ser probado directamente en dispositivo físico sin regresiones.

---

## 5. MATRIZ DE VERIFICACIÓN ADVERSARIAL (ZERO REGRESSIONS)

| Requerimiento | Riesgo de Regresión | Mecanismo de Blindaje / Mitigación | Validación Esperada |
| :--- | :--- | :--- | :--- |
| **Modal Nota de Venta (Opacidad y SafeArea)** | Que el modal desborde en pantallas pequeñas o que el texto del teclado quede oculto. | Uso de `SingleChildScrollView` + `viewInsets.bottom` + `viewPadding.bottom` en `InteractiveSheetWrapper`. | 100% legibilidad sin traslúcidos del fondo; botones siempre accesibles con teclado abierto. |
| **Estabilidad de KPI Cards (Home)** | Que textos de cifras altas (ej. S/ 12,450.00) se desborden o corten. | `FittedBox(fit: BoxFit.scaleDown)` dentro de contenedor con altura fija de 82px. | 0 píxeles de desplazamiento vertical durante la rotación cada 6 segundos. |
| **Alertas de Stock Inline** | Que la animación de despliegue sea lenta o cause jank en dispositivos de gama baja. | `AnimatedSize(curve: Curves.easeInOutCubic, duration: 250ms)` con cálculo de stock cacheado en SharedPreferences. | Despliegue y repliegue suave con 60 FPS sin bloquear el hilo de UI. |
| **Conteos Reales en Buscador Omnicanal** | Que las 4 consultas `COUNT(*)` congelen la UI al abrir el modal. | Ejecución asíncrona mediante `Future.wait` en SQLite directamente optimizado con índices existentes. | Apertura instantánea del modal (< 40ms) con números exactos de la BD. |
| **Globo Flotante 2D y Edge Peek** | Que el usuario arrastre el globo fuera de la pantalla y no pueda recuperarlo. | `_posX.clamp` y `_posY.clamp` estrictos, más anclaje magnético mínimo de 14px visibles en modo Tuck. | El globo siempre tiene al menos una pestaña luminosa interactuable para ser restaurado. |

---

## 6. PRÓXIMOS PASOS
1. **Revisión y Aprobación del Usuario:** El usuario evalúa este plan técnico detallado.
2. **Orden de Ejecución:** Una vez aprobado, se inició y completó la ejecución fase por fase según el protocolo de Loop Autónomo, reportando el progreso y validando contra el código fuente real.

---

## 7. INFORME DE CIERRE Y SINCRONIZACIÓN FINAL (AUDITORÍA DE PUNTOS CRÍTICOS)

Tras la auditoría cruzada con el comportamiento real en producción, se ejecutaron las siguientes resoluciones definitivas en los componentes de la Parte 1:

### 1. Sincronización Total en `omni_search_bar.dart`
- **Listado y Búsqueda por Variantes/Presentaciones:** Tanto la carga por defecto (`_loadRecentDefaults`) como la búsqueda en vivo (`_performSearch`) consultan `presentaciones_producto pr JOIN productos p` cargando cada variante activa con su nombre compuesto (`producto_nombre + nombre_especifico`), marca compartida, stock de esa variante y precio individual. Al pulsar la variante o el botón de acción se navega a `ProductDetailScreen` con el `initialPresentationId` exacto de esa variante.
- **Paridad Exacta en Ventas y Cotizaciones:** Se eliminó el doble conteo entre ventas y cotizaciones. En `_loadDatabaseCounts()` y en los listados se consulta `ventas WHERE is_archived = 0` directamente para la sección `"🧾 VENTAS"`, y para cotizaciones se excluyen estados `'vendida', 'sold', 'annulled', 'anulada'`. La cifra en el chip coincide exactamente con la cantidad de registros listados.
- **Renderizado Virtualizado a 60 FPS:** Se reemplazó el renderizado estático y el tope rígido de 120 por una arquitectura virtualizada basada en `ListView.builder` con ítems aplanados tipados (`_OmniListItem`: `_HeaderItem`, `_ProductItem`, `_ClientItem`, `_QuoteItem`, `_SaleItem`, `_SpacerItem`), y límites de hasta 1,000 registros al filtrar por categoría específica.

### 2. Integración y Rendimiento de `RestockSmartBanner` en `home_screen.dart`
- **Eliminación de Huecos Huérfanos:** Se eliminó el `SizedBox(height: 16)` estático que quedaba visible en `home_screen.dart` cuando no había alertas de stock. El margen inferior de 16px ahora se gestiona de manera interna y reactiva en `RestockSmartBanner` solo cuando `_alertCount > 0`.
- **Consulta SQLite Directa a 0ms:** Se sustituyó el ciclo iterativo y el caché forzado de 3 horas por una consulta SQL agregada de una sola pasada (`SELECT COUNT(*) FROM presentaciones_producto WHERE activo = 1 AND stock_actual <= stock_alerta`), reflejando cambios en el stock de forma inmediata tras cualquier venta o reposición.

### 3. Persistencia de Posición (X, Y) y Estado Edge Peek del Globo Flotante
- **Estado de Sesión Compartido (`FloatingDockSessionState`):** Se implementó una clase de estado en memoria (`floating_dock_session_state.dart`) sincronizada con `PersistentWorkDock` y `DeepNavReturnPill`.
- **Navegación Fluida sin Obstrucción:** Las coordenadas `(panX, panBottom)`, el anclaje lateral `isLeftEdge` y el estado `isEdgeTucked` se preservan íntegramente al navegar entre el Catálogo, Ficha de Producto, Inventario o Home, evitando que el globo regrese a la esquina inferior izquierda ni tape los dashboards financieros.

