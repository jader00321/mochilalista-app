# PLAN MAESTRO: REINGENIERÍA VISUAL Y LÓGICA DE RADAR COMERCIAL IA, TRAZABILIDAD, ABASTECIMIENTO INTELIGENTE Y COTIZACIÓN INTELIGENTE

**Documento:** `analisis_proyecto/PLAN_REINGENIERIA_RADAR_TRAZABILIDAD_ABASTECIMIENTO_Y_COTIZACION.md`  
**Fecha:** 28 de Octubre de 2026  
**Versión:** 1.0 — Especificación Técnica Definitiva (Mobile Awards Quality)  
**Estado:** Esperando Aprobación de Plan de Trabajo (Paso 1: Diagnóstico Forense y Diseño Arquitectónico)  
**Metodología:** Loop Autónomo + Árbitro Interno Adversarial (Zero-Regressions, Zero-Overflows & 100% Mathematical Accuracy)

---

## 1. RESUMEN EJECUTIVO Y OBJETIVOS ESTRATÉGICOS

### 1.1. Contexto Global
Tras el despliegue exitoso de la arquitectura de gestión de variantes y stock multivariable, la inspección exhaustiva de la aplicación en dispositivos móviles reales (pantallas estándar de `360dp` a `400dp` y 5 capturas forenses adjuntas) ha revelado inconsistencias críticas de renderizado, diseño visual, experiencia de usuario y cálculo lógico en 4 módulos clave:
1. **Radar Comercial IA & Sección en Inteligencia de Negocio (`Imágenes 1, 2 y 3`):**
   * Desbordamientos en etiquetas de cabecera (`[📍 Proveedores y Abastecimiento] [Cámara de Com...`).
   * Flechas y emojis duplicados en botones de lectura y acción (`↗ Leer en... ↗️`, `[ ⇋ 📋 Ir a Mesa de Trabajo ]`).
   * Feeds estáticos limitados a 2 noticias fijas en BI y solo 5 noticias de respaldo.
   * Carencia de *Pull-to-Refresh* acumulativo que añada noticias frescas sin borrar las del día.
   * Falta de caducidad automática al cambiar de día calendario.
   * Noticias Guardadas (`🔖`) mezcladas indebidamente dentro de la fila de filtros de categorías en vez de contar con un control dedicado.
   * Textos cortados en el panel superior de monitoreo, semáforos (`Abastecimie...`, `Campaña N...`), placeholder del buscador y fechas relativas.
   * Presencia de emojis discordantes (`📍`, `🌦️`, `⚖️`, `📊`, `📰`, `📦`) en lugar de iconos vectoriales estilizados.
2. **Trazabilidad (Kárdex) y Abastecimiento Inteligente (`Imagen 4`):**
   * La fila de conciliación de balance (`ⓘ Stock Inicial Base: 56 und • Saldo: (56 + 28 - 64 = 2...`) se corta con puntos suspensivos sin mostrar el resultado final.
   * La ventana de Trazabilidad no detecta ni diferencia si una variante opera con **`🔗 Stock Compartido`** o **`📦 Stock Independiente`**, provocando desajustes en el historial de entradas/salidas cuando otra variante hermana vende del pool común.
   * En `Abastecimiento Inteligente`, el cálculo de compra no desglosa las variantes con paquetes incompletos en el pool común (ej. si quedan 5 unidades base, no alcanza para armar una `Caja x12`), ni diferencia con claridad matemática los productos con estrategia `Mixta` frente a los puramente `Independientes`.
3. **Cotización Inteligente / Matching (`Imagen 5`):**
   * En tarjetas vinculadas retraídas con descuento (Fila #3 `Goma de borrar` $\rightarrow$ `SAN CARLOS kiwkkd Surtido`), el Precio Final desaparece por completo (sólo se ve el badge verde `-S/ 1.50` y `5 uds.`), dejando al usuario a ciegas sobre cuánto cobrar.
   * Deformación y estiramiento vertical desproporcionado en la Fila #3: ambas tarjetas (izquierda y derecha) se estiran hacia abajo dejando un enorme hueco vacío en la mitad inferior.

### 1.2. Metodología de Ejecución: Loop Autónomo + Árbitro Adversarial
* **Fase de Diagnóstico Forense (Paso Actual):** Mapeo de archivos y líneas exactas de código causantes de cada falla visual y lógica.
* **Fase de Aprobación Previa:** **Cero modificaciones de código** hasta recibir la orden explícita del usuario tras revisar este plan.
* **Fase de Ejecución por Fases Blindadas:** Modificaciones atómicas progresivas con pruebas estáticas de análisis (`dart analyze`), pruebas unitarias/widgets y validación de overflow en viewports de `320px` a tablets.
* **Árbitro Interno Adversarial:** Simulación activa de escenarios extremos (pantallas de 320dp, textos largos de productos, descuentos complejos, rotación de medianoche, desconexión de red) para certificar cero regresiones.

---

## 2. DIAGNÓSTICO FORENSE Y EVIDENCIA VISUAL EN CÓDIGO (ARCHIVOS Y LÍNEAS EXACTAS)

### 2.1. Módulo 1: Radar Comercial IA e Inteligencia de Negocio (Imágenes 1, 2 y 3)

#### A. Desbordamiento en Fila de Etiquetas y Flechas Duplicadas (Imagen 1)
* **Archivo:** `app_movil/lib/features/analytics/widgets/dashboard/commercial_radar_card.dart`
* **Líneas exactas:**
  * **Líneas 673–731:** La fila de metadatos de la tarjeta renderiza:
    ```dart
    Row(
      children: [
        Container(
          // Chip de Categoría no flexible
          child: Row(children: [Icon(catIcon), Text(item.category)]),
        ),
        SizedBox(width: 8),
        Container(
          // Chip de Fuente no flexible (ej. "Cámara de Comercio de Lima")
          child: Text(item.sourceName),
        ),
        SizedBox(width: 8),
        Expanded(child: Text(item.formattedDateWithTimeAgo)),
        Icon(Icons.open_in_new),
      ],
    )
    ```
    **Causa Raíz:** En un viewport de 360dp, cuando la categoría es `"Proveedores y Abastecimiento"` (larga) y la fuente es `"Cámara de Comercio..."`, el `Row` no tiene espacio suficiente y la fuente se corta rígidamente (`Cámara de Com...`).
  * **Líneas 862–865:** Botón inferior de lectura:
    ```dart
    icon: const Icon(Icons.arrow_outward, size: 14),
    label: Text(
      "Leer en ${item.sourceName} ↗",
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
    ),
    ```
    **Causa Raíz:** Se incluye simultáneamente el icono vectorial `Icons.arrow_outward` y el carácter tipográfico/emoji `↗` en el texto del label, generando la duplicación visual `↗ Leer en Cámara de Comercio ↗️`.

#### B. Variedad Estática de Noticias en Inteligencia de Negocio (Imagen 1)
* **Archivo:** `app_movil/lib/features/analytics/widgets/dashboard/commercial_radar_card.dart`
* **Línea exacta:** 373
* **Código defectuoso:**
  ```dart
  final previewItems = filtered.take(2).toList();
  ```
* **Causa Raíz:** Siempre toma los primeros 2 elementos de la lista en memoria. Al no haber rotación, paginación local en carrusel ni refresco aleatorio por hora/sesión, el comerciante siempre ve exactamente las mismas 2 noticias al abrir Inteligencia de Negocio.

#### C. Catálogo Reducido y Falta de Acumulación Diaria en Radar Comercial IA (Imágenes 2 y 3)
* **Archivos:**
  * `app_movil/lib/features/analytics/screens/commercial_radar_screen.dart` (Líneas 118–147)
  * `app_movil/lib/features/analytics/services/commercial_radar_service.dart` (Líneas 10–25, 434–520)
* **Causa Raíz:**
  1. En `_fetchNews({bool forceRefresh = false})` de `commercial_radar_screen.dart`:
     `if (forceRefresh) _allNewsItems.clear();` — Al deslizar hacia abajo para recargar (*Pull-to-Refresh*), el sistema borra todas las noticias descubiertas en el día y las reemplaza.
  2. En `commercial_radar_service.dart`: La función `_getOfflineFallback` únicamente contiene 5 noticias fijas (una por categoría). Si la API no retorna resultados nuevos, el usuario ve permanentemente el mismo set de 5 alertas.
  3. No existe verificación de cambio de día calendario (`DateTime.now().day != savedDate.day`) para expirar automáticamente las noticias del día previo y generar un lote fresco matutino.

#### D. Ubicación Inadecuada de Noticias Guardadas (🔖) (Imagen 2)
* **Archivo:** `app_movil/lib/features/analytics/screens/commercial_radar_screen.dart`
* **Líneas exactas:** 51–59
* **Código defectuoso:**
  ```dart
  List<String> get _categories => [
    'Todas',
    '📍 Mi Región',
    '🌦️ Clima y Rutas',
    '⚖️ Leyes y SUNAT',
    '🚛 Proveedores y Abastecimiento',
    '📅 Fechas y Campañas',
    '📌 Guardadas (${_savedNewsMap.length})', // ❌ Mezclado en la fila horizontal de categorías temáticas
  ];
  ```
* **Causa Raíz:** Mezclar un estado de colección personal (`Guardadas`) con filtros temáticos de contenido genera confusión de navegación. Además, requiere scroll horizontal para ser visto y carece de persistencia robusta en base de datos.

#### E. Textos Cortados en Panel Superior, Placeholder y Fechas (Imagen 2)
* **Archivo:** `app_movil/lib/features/analytics/screens/commercial_radar_screen.dart`
* **Líneas exactas:**
  * **Líneas 648–678 y 882–927 (`_buildPulseItem`):** En una fila de 3 columnas en 360dp, los títulos `"Abastecimiento"` y `"Campaña Navideña"` tienen `maxLines: 1, overflow: TextOverflow.ellipsis`, cortándose en `"Abastecimie..."` y `"Campaña N..."`.
  * **Línea 715:** `hintText: "Buscar noticias, rutas, SUNAT o abastecimiento..."` — El placeholder es demasiado extenso para la caja de búsqueda de 38dp y se corta en `"...o abastecimi..."`.
  * **Línea 1032–1042:** `Text(item.formattedDateWithTimeAgo)` — En la tarjeta, al estar junto al badge de fuente, `26 oct 2026 • Hace 3 horas` se corta en `Hace 3 ho...`.
* **Archivo:** `app_movil/lib/features/analytics/models/commercial_radar_model.dart` (Líneas 48–73)

#### F. Icono Duplicado en Botón "Ir a Mesa de Trabajo" (Imagen 3)
* **Archivo:** `app_movil/lib/features/analytics/screens/commercial_radar_screen.dart`
* **Líneas exactas:** 1172–1176 y 1190–1194
* **Código defectuoso:**
  ```dart
  icon: const Icon(Icons.checklist_rounded, size: 15),
  label: const Text(
    "📋 Ir a Mesa de Trabajo", // ❌ Icono vectorial + Emoji 📋
    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
  ),
  ```
  Y en el botón hermano:
  ```dart
  icon: const Icon(Icons.inventory_2_outlined, size: 15),
  label: const Text("📦 Revisar Stock Crítico"), // ❌ Icono vectorial + Emoji 📦
  ```
* **Causa Raíz:** Redundancia de icono vectorial junto a emoji discordante dentro del texto.

#### G. Emojis Discordantes en Pestañas y Chips
* **Archivos:**
  * `app_movil/lib/features/analytics/screens/analytics_dashboard_screen.dart` (Líneas 146–158: `"📊 Resumen"`, `"📈 Gráficos"`, `"📦 Inventario"`, `"📰 Radar Comercial"`).
  * `app_movil/lib/features/analytics/screens/commercial_radar_screen.dart` (Líneas 51–59: `'📍 Mi Región'`, `'🌦️ Clima y Rutas'`, `'⚖️ Leyes y SUNAT'`).
* **Causa Raíz:** Uso de emojis Unicode de color en lugar de componentes nativos `Icon(Icons.*)` con la paleta tipográfica y temática de la app.

---

### 2.2. Módulo 2: Trazabilidad y Abastecimiento Inteligente (Imagen 4)

#### A. Truncamiento de la Conciliación de Stock Inicial (Imagen 4)
* **Archivo:** `app_movil/lib/features/analytics/screens/audit_trail_screen.dart`
* **Líneas exactas:** 478–502
* **Código defectuoso:**
  ```dart
  if (_currentStock != (_totalEntradas - _totalSalidas)) ...[
    Container(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 12, color: Colors.white70),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              "Stock Inicial Base: ${_currentStock - (_totalEntradas - _totalSalidas)} und  •  Saldo: (${_currentStock - (_totalEntradas - _totalSalidas)} + $_totalEntradas - $_totalSalidas = $_currentStock und)",
              style: const TextStyle(fontSize: 10, color: Colors.white70),
              overflow: TextOverflow.ellipsis, // ❌ En 360dp esta cadena de 115 caracteres se trunca inevitablemente
            ),
          ),
        ],
      ),
    ),
  ],
  ```
* **Causa Raíz:** Renderizar una fórmula matemática larga completa en una sola línea dentro de un `Row` con `TextOverflow.ellipsis`.

#### B. Emojis en Fila Desplazable de Filtros de Trazabilidad
* **Archivo:** `app_movil/lib/features/analytics/screens/audit_trail_screen.dart`
* **Líneas exactas:** 557–572
* **Código defectuoso:**
  * `"📦 Movimientos"`
  * `"💰 Precios y Costos"`
  * `"🏷️ Descuentos"`
  * `"📋 Ficha"`
* **Causa Raíz:** Inclusión de emojis dentro de los strings de texto de los chips. Se debe mantener el excelente scroll horizontal actual, pero utilizando `avatar: Icon(...)` vectorial coherente.

#### C. Kárdex Desconectado de la Arquitectura de Variantes (Compartido vs. Independiente)
* **Archivos:**
  * `app_movil/lib/features/analytics/screens/audit_trail_screen.dart` (Líneas 58–88, 103–133)
  * `app_movil/lib/features/analytics/services/inventory_intelligence_service.dart` (Líneas 383–408)
* **Causa Raíz:**
  1. En `inventory_intelligence_service.dart`: Cuando se consulta una variante específica (`presentationId != -1`), la consulta SQL ejecuta rígidamente:
     `WHERE sl.presentation_id = ?`
  2. Si la variante tiene `usa_stock_compartido == 1` (ej. `jekeke • Color`), las ventas de presentaciones hermanas del mismo producto (ej. `jekeke • Docena` o `jekeke • Unidad`) descuentan del mismo pozo base en `productos.stock_compartido`, pero NO aparecen en el kárdex de la variante seleccionada.
  3. Esto provoca que `_totalEntradas` y `_totalSalidas` no concilien con el `stock_actual` de la variante, forzando la aparición errónea de diferencias en el saldo.
  4. La pantalla no muestra ningún badge que le aclare al usuario si la variante opera con `🔗 Stock Compartido (Factor xN)` o con `📦 Stock Independiente`.

#### D. Desconexión en Abastecimiento Inteligente para Variantes y Modo Mixto
* **Archivo:** `app_movil/lib/features/analytics/screens/smart_restock_screen.dart` (Líneas 120–240)
* **Causa Raíz:**
  1. En productos con **Stock Compartido**: Actualmente sólo muestra una tarjeta consolidada `"Pool Compartido: 56 und"`. No analiza si existen presentaciones con factores altos (ej. `Caja x12`) que ya no pueden armarse con las unidades base existentes (ej. 5 unidades base no arman ni una sola caja), omitiendo recomendar la compra en múltiplos de las presentaciones desabastecidas.
  2. En productos con **Stock Mixto**: Las variantes independientes se mezclan visualmente con las de productos puramente independientes sin indicar que pertenecen a un producto con estrategia mixta, dificultando la toma de decisiones del comerciante.

---

### 2.3. Módulo 3: Cotización Inteligente / Matching (Imagen 5)

#### A. Ocultamiento del Precio Final en Tarjeta Retraída con Descuento (Fila #3)
* **Archivo:** `app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart`
* **Líneas exactas:** 651–725
* **Código defectuoso:**
  ```dart
  Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          children: [
            Row(
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isExpanded
                          ? "${AppCurrency.format(widget.pair.effectiveUnitPrice)} c/u"
                          : AppCurrency.format(widget.pair.subtotal), // ❌ Precio Final
                    ),
                  ),
                ),
                if (widget.pair.hasDiscount) ...[
                  const SizedBox(width: 6),
                  Container(
                    // Badge Verde de Descuento
                    child: Text("-${AppCurrency.format(...)}"),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      // Controles de cantidad
      AnimatedCrossFade(
        crossFadeState: _isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        secondChild: Container(child: Text("${widget.pair.selectedQuantity} uds.")),
      ),
    ],
  )
  ```
* **Causa Raíz:** En una pantalla de 360dp, el ancho disponible para la tarjeta derecha es de aprox. 142px. El selector de cantidad (`"5 uds."`) toma aprox. 68px. El `Expanded` de precios dispone de menos de 50px. Al tener un `Container` de descuento de aprox. 65px (`"-S/ 1.50"`), el `Flexible` que contiene el `FittedBox` del Precio Final (`"S/ 27.75"`) es comprimido a **0 píxeles de ancho**, reduciendo el texto a escala 0 (completamente invisible).

#### B. Deformación y Estiramiento Vertical Vacío en Tarjetas Izquierda y Derecha (Fila #3)
* **Archivo:** `app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart`
* **Líneas exactas:** 121–175, 261–265, 732–855, 865–955
* **Causa Raíz:**
  1. La fila utiliza `IntrinsicHeight` en la raíz (línea 121) con `Row(crossAxisAlignment: CrossAxisAlignment.stretch)`.
  2. Dentro de `_buildLinkedState`, la tarjeta derecha utiliza múltiples widgets con cálculo intrínseco incompatible: dos `AnimatedCrossFade` (imagen y controles de cantidad) y un `IntrinsicHeight` anidado adicional en los botones de acción inferiores (línea 865).
  3. En Flutter, `RenderAnimatedCrossFade.computeMaxIntrinsicHeight` devuelve por especificación `math.max(firstChild.height, secondChild.height)`. Por lo tanto, aunque la tarjeta esté retraída (`_isExpanded == false`), el `IntrinsicHeight` de la raíz calcula la altura máxima del widget expandido (más de 230px), estirando tanto la tarjeta izquierda marrón como la tarjeta derecha azul, y dejando un enorme espacio muerto vacío debajo de los botones de acción.

---

## 3. ARQUITECTURA TÉCNICA DE SOLUCIÓN Y ESPECIFICACIONES DETALLADAS

```
+---------------------------------------------------------------------------------------------------+
|               ARQUITECTURA DE REINGENIERÍA MULTI-MÓDULO (MOBILE AWARDS QUALITY)                   |
+---------------------------------------------------------------------------------------------------+
|                                                                                                   |
|  [MÓDULO 1: RADAR COMERCIAL IA]                                                                   |
|   * Catálogo Extendido (30+ noticias clasificadas y rotación automática).                         |
|   * Pull-to-Refresh Acumulativo (Agrega sin borrar lo del día).                                   |
|   * Caducidad Diaria Matutina (Purga automática al cambiar el día calendario).                    |
|   * Pestaña Superior Segmentada Dedicada: [ 📡 Noticias del Día ] | [ 🔖 Guardadas (X) ].         |
|   * Cero Textos Cortados (Semáforos adaptativos, buscador optimizado, fechas compactas).          |
|   * Iconos Vectoriales Nativos (Eliminación de emojis sucios y flechas duplicadas).               |
|                                                                                                   |
|  [MÓDULO 2: TRAZABILIDAD Y ABASTECIMIENTO INTELIGENTE CON VARIANTES]                             |
|   * Fila de Conciliación de Balance en 2 líneas responsivas (Cero truncamiento en 320dp).        |
|   * Kárdex Variante-Consciente:                                                                   |
|     - [🔗 Stock Compartido (Factor xN)]: Rastrea pool central e identifica ventas hermanas.       |
|     - [📦 Stock Independiente]: Aísla estrictamente movimientos de la variante (Cuadre 100%).    |
|   * Abastecimiento Inteligente:                                                                   |
|     - Stock Compartido: Analiza pozo base + paquetes completos faltantes (ej. Caja x12).         |
|     - Stock Independiente: Agotamiento y compra individual por presentación.                     |
|     - Stock Mixto: Separación explícita con badges temáticos en la interfaz.                      |
|                                                                                                   |
|  [MÓDULO 3: COTIZACIÓN INTELIGENTE (MATCHING)]                                                    |
|   * Precio Final SIEMPRE Visible en Grande en vista retraída (Jerarquía clara: Precio > Descuento)|
|   * Layout de Precio + Descuento Verticalizado o con Wrap Elástico (Cero escala 0 en FittedBox).  |
|   * Eliminación del Estiramiento Vertical Vacío:                                                  |
|     - Sustitución de AnimatedCrossFade por renderizado condicional optimizado con AnimatedSize.   |
|     - Eliminación de IntrinsicHeight anidado redundante.                                          |
|     - Altura simétrica y compacta garantizada en estado retraído y desplegado.                    |
|                                                                                                   |
+---------------------------------------------------------------------------------------------------+
```

---

### BLOQUE 1: Reingeniería de Radar Comercial IA e Inteligencia de Negocio

#### 1.1. Catálogo Extendido y Variedad Real en Inteligencia de Negocio
* **En `CommercialRadarService`:**
  * Incrementar el catálogo de noticias locales y nacionales de 5 a **más de 25 alertas estructuradas** categorizadas (`Clima y Rutas`, `Leyes y SUNAT`, `Proveedores y Abastecimiento`, `Campañas`, `Mi Región`).
  * Implementar un algoritmo de **Rotación Dinámica** para la sección de `Inteligencia de Negocio` (`commercial_radar_card.dart`):
    * En vez de `previewItems = filtered.take(2).toList()`, implementar una rotación basada en el ciclo de sesión y un botón sutil `🔀 Alternar alertas` en la tarjeta, o un carrusel compacto de noticias con indicadores (`dots`), permitiendo explorar hasta 6 noticias sin salir de la pantalla de Estadísticas.
* **Corrección de Desbordamientos y Doble Flecha en `commercial_radar_card.dart`:**
  * Reestructurar la fila de metadatos (línea 673) utilizando un `Wrap` compacto o un `Row` con `Flexible` en el nombre de la fuente y `TextOverflow.ellipsis`:
    ```dart
    Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: catColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(catIcon, size: 12, color: catColor),
              const SizedBox(width: 4),
              Text(item.category, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: catColor)),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: sourceBg, borderRadius: BorderRadius.circular(4)),
            child: Text(
              item.sourceName,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: sourceColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(item.compactTimeAgo, style: TextStyle(fontSize: 10.5, color: dateColor)),
      ],
    )
    ```
  * Corregir el botón inferior (línea 864): Eliminar el carácter emoji `↗` del `Text`, manteniendo exclusivamente el icono vectorial `Icon(Icons.arrow_outward, size: 14)`.

#### 1.2. Pull-to-Refresh Acumulativo y Caducidad Diaria Matutina
* **En `CommercialRadarScreen` y `CommercialRadarService`:**
  * **Regla de Acumulación Intradía:** Al ejecutar *Pull-to-Refresh*, el stream consulta o genera nuevas alertas y las incorpora mediante `_mergeNewsItems(newItems)`:
    * Si la noticia ya existe por `id`, la actualiza; si es nueva, la agrega al inicio o final de la lista sin vaciar el catálogo del día.
    * Elevar el límite visual de visualización y paginación para soportar hasta 50 noticias por día sin degradar la memoria.
  * **Regla de Caducidad Diaria (Midnight Expiry):**
    * Registrar en `SharedPreferences` la clave `radar_news_cache_date` con formato `yyyy-MM-dd`.
    * Al iniciar la pantalla o el servicio, si `savedDate != todayString`, las noticias no guardadas del día anterior expiran automáticamente y se invoca la generación/consulta del nuevo día fresco.

#### 1.3. Pestaña Superior Segmentada Dedicada para "Guardadas (🔖)"
* **Eliminar `Guardadas` de la fila horizontal de categorías.**
* **Incorporar en la cabecera fija o AppBar un conmutador segmentado elegante:**
  ```dart
  // [ 📡 Noticias del Día (24) ]   [ 🔖 Guardadas (5) ]
  ```
* **Persistencia Blindada:**
  * Crear la tabla SQLite `radar_noticias_guardadas` (o almacenamiento local JSON tipado con schema) para asegurar que las noticias guardadas:
    1. Nunca caduquen al cambiar de día.
    2. Se sincronicen instantáneamente al tocar el icono de bookmark `Icons.bookmark_border` / `Icons.bookmark`.
    3. Muestren su propio contador en tiempo real en la pestaña `🔖 Guardadas (X)`.

#### 1.4. Refinamiento Visual Anti-Cortes y Vectorización de Iconos
* **Semáforo del Panel Superior (`_buildPulseItem`):**
  * Ajustar títulos a etiquetas responsivas que no se trunquen en 360dp:
    * `"Rutas/Fletes"`
    * `"Abastecimiento"` $\rightarrow$ Si el ancho de pantalla es menor a 380dp, usar `"Abastec."` o reducir el tamaño a `9.5sp` con `FittedBox`.
    * `"Campaña Navideña"` $\rightarrow$ Formateo adaptativo `"Navidad"` o `"${campana.nombreCorto}"` con `días restantes`.
* **Placeholder del Buscador:**
  * Cambiar a `"Buscar noticias, rutas, SUNAT..."` (33 caracteres, ajustado a 360dp).
* **Fechas Relativas Compactas:**
  * En `commercial_radar_model.dart`: Formatear a `26 oct 2026 • Hace 3h` o `Ayer`, garantizando cero saltos de línea ni textos cortados.
* **Eliminación de Iconos Duplicados y Emojis:**
  * Botón: `Icon(Icons.checklist_rounded)` + `Text("Ir a Mesa de Trabajo")` (sin emoji `📋`).
  * Botón: `Icon(Icons.inventory_2_outlined)` + `Text("Revisar Stock Crítico")` (sin emoji `📦`).
  * Sustituir emojis en categorías de Radar y en pestañas de Inteligencia de Negocio (`_FluidChipTabBar`) por iconos vectoriales `Icons.analytics_outlined`, `Icons.insights`, `Icons.inventory_2_outlined`, `Icons.radar`.

---

### BLOQUE 2: Rediseño Responsivo de Trazabilidad y Adaptación a Variantes

#### 2.1. Conciliación de Balance Responsiva en 2 Líneas (Imagen 4)
* **Archivo:** `app_movil/lib/features/analytics/screens/audit_trail_screen.dart`
* **Rediseño:** Sustituir la fila única desbordada por un contenedor de 2 líneas adaptables con separación visual limpia:
  ```dart
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white12),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, size: 13, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  "Stock Inicial: $stockInicial und",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            Text(
              "Entradas: +$_totalEntradas  •  Salidas: -$_totalSalidas",
              style: const TextStyle(fontSize: 10.5, color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calculate_outlined, size: 12, color: Colors.cyanAccent),
              const SizedBox(width: 6),
              Text(
                "Saldo Auditoría: $stockInicial + $_totalEntradas - $_totalSalidas = $_currentStock und",
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
              ),
            ],
          ),
        ),
      ],
    ),
  )
  ```
* **Preservación del Scroll Horizontal en Chips de Filtro:**
  * Mantener intacto el `ListView(scrollDirection: Axis.horizontal)` de los chips (`Todos (18)`, `Movimientos (17)`...).
  * Reemplazar los emojis de texto por iconos vectoriales `Icons.swap_horiz` (`Movimientos`), `Icons.price_change` (`Precios y Costos`), `Icons.local_offer` (`Descuentos`), `Icons.assignment` (`Ficha`).

#### 2.2. Kárdex de Trazabilidad Adaptado a Variantes (Compartido vs. Independiente)
* **En `audit_trail_screen.dart` y `inventory_intelligence_service.dart`:**
  * Al consultar una variante, verificar sus metadatos (`usa_stock_compartido`, `unidades_por_venta`, `modo_stock` del producto padre).
  * **Si opera con Stock Compartido (`usa_stock_compartido == 1`):**
    * Mostrar badge en cabecera: `🔗 Stock Compartido (Factor x${pres.unidadesPorVenta})`.
    * La consulta de movimientos debe recuperar todas las operaciones que afectaron el pool común del producto.
    * En las tarjetas de la línea de tiempo: Si el movimiento provino de una variante hermana, indicarlo claramente:
      * `Venta en Caja: -2 und (Color)`
      * `Venta en Caja: -24 und base (vía presentación hermana: Caja x12)`
    * La ecuación de saldo concilia el pool de unidades base y su equivalencia en la presentación activa.
  * **Si opera con Stock Independiente (`usa_stock_compartido == 0`):**
    * Mostrar badge en cabecera: `📦 Stock Independiente`.
    * Aislar exclusivamente los movimientos de esa presentación (`WHERE sl.presentation_id = ?`).
    * La ecuación `Inicial + Entradas - Salidas = Actual` cuadra con precisión del 100%.

#### 2.3. Abastecimiento Inteligente: Cálculo de Pool y Paquetes Faltantes
* **En `smart_restock_screen.dart` y `inventory_intelligence_service.dart`:**
  * **Para Variantes con Stock Compartido:**
    * Analizar el pool base conjunto.
    * Calcular la cobertura para cada presentación según su factor `unidadesPorVenta`.
    * Si el pool base actual no alcanza para completar paquetes de presentaciones clave (ej. quedan 5 unidades sueltas y se vende en `Caja x12` o `Docena x6`), alertar:
      * `⚠️ Quiebre de formato: Caja x12 (0 disponibles, faltan 7 und. base)`.
    * Recomendar la compra en unidades base totales y sugerir su equivalencia en presentación de compra estándar mayorista.
  * **Para Variantes Independientes:**
    * Mantener el cálculo rigurosamente individual de ROP, stock de seguridad y sugerencia de compra.
  * **Para Productos Mixtos:**
    * Separar visualmente la tarjeta del grupo compartido de las tarjetas de variantes con stock propio mediante badges distintivos `🔗 Pool Mixto` y `📦 Stock Propio (Mixto)`.

---

### BLOQUE 3: Refinamiento Visual y Estructural de Cotización Inteligente (Matching)

#### 3.1. Visibilidad Absoluta del Precio Final en Tarjetas Retraídas
* **Archivo:** `app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart`
* **Rediseño:**
  * En la tarjeta derecha vinculada, el **Precio Final** (`AppCurrency.format(pair.subtotal)`) nunca debe ser aplastado por el badge de descuento.
  * Reestructurar la zona media con distribución en columna compacta cuando está retraída:
    ```dart
    // Fila Principal: Precio Final Grande + Selector/Badge de Cantidad
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Si tiene descuento, mostrar precio tachado + badge de ahorro en línea superior limpia
              if (widget.pair.hasDiscount) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppCurrency.format(widget.pair.originalUnitPrice * widget.pair.selectedQuantity),
                      style: TextStyle(
                        fontSize: 10,
                        decoration: TextDecoration.lineThrough,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isDark ? Colors.green.withValues(alpha: 0.3) : Colors.green.shade200),
                      ),
                      child: Text(
                        "-${AppCurrency.format(widget.pair.totalSavings)}",
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.green[300] : Colors.green[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
              ],
              // PRECIO FINAL SIEMPRE VISIBLE EN GRANDE
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  AppCurrency.format(widget.pair.subtotal),
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: widget.pair.hasDiscount
                        ? (isDark ? Colors.greenAccent : Colors.green[700])
                        : textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // Cantidad seleccionada compacta
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? Colors.blue.withValues(alpha: 0.12) : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.shade200),
          ),
          child: Text(
            "${widget.pair.selectedQuantity} uds.",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.blue[300] : Colors.blue[800]),
          ),
        ),
      ],
    )
    ```

#### 3.2. Eliminación Radical del Estiramiento Vacío en Tarjetas Izquierda y Derecha
* **Causa Raíz Diagnosticada:** El uso de `AnimatedCrossFade` dentro de un `Row` con `IntrinsicHeight` provoca que la tarjeta mida la altura de los controles desplegados aunque esté retraída.
* **Solución de Ingeniería:**
  1. Reemplazar los `AnimatedCrossFade` por widgets con renderizado condicional directo `if (_isExpanded)` envueltos en `AnimatedSize` o transiciones limpias:
     * Si `!_isExpanded`: no se construye ni se mide la imagen de 50px ni los controles numéricos de 3 líneas. La altura intrínseca se reduce exactamente a los ~90px que necesita la tarjeta retraída.
  2. Eliminar el `IntrinsicHeight` anidado redundante en la barra inferior de botones de acción (`[ ⊘ ] [ 🔍 ]`).
  3. Establecer `mainAxisSize: MainAxisSize.min` en las columnas internas de `_buildLinkedState` y `_buildSourceInfo`.
  4. Garantizar simetría perfecta: Tanto la tarjeta marrón de la izquierda como la azul de la derecha mantendrán una altura compacta y proporcionada (~90-95px retraídas) sin dejar un solo píxel de espacio vacío.

---

## 4. PLAN DE IMPLEMENTACIÓN POR FASES (PASO A PASO)

### FASE 1: Reingeniería Visual y Operativa de Radar Comercial IA & Inteligencia de Negocio
* **Objetivo:** Resolver desbordamientos, flechas duplicadas, emojis discordantes, incorporar *Pull-to-Refresh* acumulativo, caducidad diaria y pestaña dedicada para `Guardadas`.
* **Tareas Técnicas:**
  1. Modificar `commercial_radar_card.dart` para resolver el overflow en la fila de etiquetas mediante `Flexible` y `TextOverflow.ellipsis`, y eliminar la flecha duplicada en el botón inferior.
  2. Ampliar el catálogo de noticias de respaldo en `commercial_radar_service.dart` a 25+ noticias multitemáticas e implementar rotación variada en la sección de Inteligencia de Negocio.
  3. Implementar en `commercial_radar_service.dart` y `commercial_radar_screen.dart` la acumulación intradía al recargar hacia abajo y la caducidad automática al cambiar de fecha.
  4. Crear la Pestaña Segmentada Superior `[ 📡 Noticias del Día ] | [ 🔖 Guardadas (X) ]` en `commercial_radar_screen.dart`, retirando `Guardadas` de la fila de chips y blindando su persistencia local.
  5. Ajustar textos en el panel de semáforos, acortar placeholder de búsqueda y formatear fechas relativas para garantizar cero cortes.
  6. Reemplazar todos los emojis de botones y pestañas por `Icons.*` en `commercial_radar_screen.dart` y `analytics_dashboard_screen.dart`.

### FASE 2: Responsividad y Adaptación de Trazabilidad a Variantes
* **Objetivo:** Eliminar el truncamiento de la fórmula de saldo y conectar el kárdex al sistema de variantes (`Compartido` vs. `Independiente`).
* **Tareas Técnicas:**
  1. Modificar `_buildSummaryCard` en `audit_trail_screen.dart` para renderizar el `Stock Inicial Base` y la ecuación de saldo en 2 líneas adaptables sin truncamiento alguno.
  2. Sustituir los emojis en la fila deslizable de filtros de eventos por iconos vectoriales `Icons.*`, manteniendo intacto su comportamiento de scroll horizontal.
  3. Modificar `InventoryIntelligenceService.getAuditTrail` y `audit_trail_screen.dart` para identificar si la variante opera con `Stock Compartido` o `Stock Independiente`:
     - Mostrar badge temático en cabecera.
     - Vincular kárdex al pool en variantes compartidas identificando movimientos de presentaciones hermanas.
     - Asegurar cuadre matemático estricto del 100% en la ecuación de auditoría.

### FASE 3: Abastecimiento Inteligente Multivariable y Paquetes Faltantes
* **Objetivo:** Refinar el cálculo de reposición en productos con stock compartido, independiente y mixto.
* **Tareas Técnicas:**
  1. Actualizar `smart_restock_screen.dart` e `inventory_intelligence_service.dart` para que el cálculo de productos con `Stock Compartido` evalúe tanto las unidades base como la demanda por presentación, alertando si el stock existente no alcanza a formar paquetes completos (ej. cajas de 12 o docenas).
  2. Incorporar badges distintivos para productos con estrategia `Mixta`, permitiendo auditar claramente qué variantes dependen del pool y cuáles tienen stock propio.
  3. Asegurar que las órdenes de compra generadas (`PurchaseOrderGenerator`) reflejen con precisión las unidades base requeridas.

### FASE 4: Cotización Inteligente (Matching) — Precios Visibles y Cero Estiramiento
* **Objetivo:** Corregir la desaparición del precio final con descuento en vista retraída y eliminar de raíz la deformación vertical en la Fila #3.
* **Tareas Técnicas:**
  1. Rediseñar la sección de precios de `matching_item_row.dart` en estado retraído: el Precio Final se ubica como protagonista en grande, y el descuento se posiciona arriba de forma compacta (precio original tachado + badge `-S/ X.XX`).
  2. Reemplazar los `AnimatedCrossFade` por control condicional limpio y `AnimatedSize`, eliminando los `IntrinsicHeight` anidados redundantes.
  3. Ajustar `mainAxisSize: MainAxisSize.min` en las columnas de ambas tarjetas para que retraídas adopten su altura natural compacta sin huecos vacíos.
  4. Verificar que al expandir la tarjeta derecha se mantenga la simetría y la distribución armónica de los controles.

### FASE 5: Árbitro Interno Adversarial, Verificación Multi-Pantalla y Pruebas
* **Objetivo:** Blindaje 360° contra regresiones y validación de aceptación.
* **Tareas Técnicas:**
  1. Ejecución de análisis estático `flutter analyze` en todo el proyecto asegurando 0 errores y 0 warnings.
  2. Ejecución de suite de tests existentes (`flutter test`).
  3. Verificación visual y de restricciones en viewports estrechos (320dp, 360dp, 400dp y tablets).

---

## 5. MATRIZ DE RIESGOS, REGRESIONES Y BLINDAJE ADVERSARIAL

| Riesgo Identificado | Probabilidad | Severidad | Mitigación Técnica Adversarial |
| :--- | :---: | :---: | :--- |
| **Pérdida de noticias guardadas al cambiar de día** | Media | Alta | Aislamiento estricto: Las noticias marcadas con bookmark se almacenan en tabla dedicada local que el limpiador diario ignora por completo. |
| **Descuadre del saldo en Trazabilidad al compartir stock** | Alta | Crítica | El cálculo de kárdex para variantes compartidas suma las operaciones de todo el pool de unidades base, correlacionando el factor de conversión exacto. |
| **Colapso del precio final en pantallas ultra estrechas (<340dp)** | Media | Alta | El precio final se renderiza en su propia línea vertical antes del selector de cantidad, blindado con `FittedBox` y tamaño mínimo garantizado. |
| **Regresión en el scroll horizontal de filtros de Trazabilidad** | Baja | Media | Se conserva exactamente el `ListView` con `BouncingScrollPhysics`, limitando el cambio exclusivamente a los iconos del `FilterChip`. |
| **Flicker o salto visual al recargar con Pull-to-Refresh** | Media | Baja | Las nuevas noticias se intercalan (*interleaving*) preservando la lista previa en memoria y actualizando la UI de forma reactiva. |

---

## 6. CRITERIOS DE ACEPTACIÓN DEFINITIVOS (CHECKLIST)

- [ ] **Imagen 1 superada:** Fila de etiquetas en tarjeta de `Inteligencia de Negocio` no se desborda en 360dp y el botón inferior muestra una sola flecha vectorial elegante (cero duplicación de `↗`).
- [ ] **Imagen 1 superada:** Sección de noticias en `Inteligencia de Negocio` cuenta con variedad real y rotación fluida.
- [ ] **Imagen 2 superada:** Pull-to-Refresh en `Radar Comercial IA` acumula nuevas noticias sin eliminar las previas del día.
- [ ] **Imagen 2 superada:** Noticias cambian automáticamente al pasar la medianoche (caducidad diaria automática).
- [ ] **Imagen 2 superada:** `Guardadas (🔖)` cuenta con su propia Pestaña Superior Segmentada o control de cabecera dedicado (fuera de los chips de categorías).
- [ ] **Imagen 2 superada:** Cero textos cortados en semáforos (`Rutas`, `Abastecimiento`, `Campañas`), buscador o fechas relativas.
- [ ] **Imagen 3 superada:** Botón `[Ir a Mesa de Trabajo]` y `[Revisar Stock Crítico]` muestran un único icono vectorial nativo sin emojis repetidos.
- [ ] **Imagen 3 superada:** Emojis discordantes (`📍`, `🌦️`, `⚖️`, `📊`, `📰`, `📦`) reemplazados por iconos `Icons.*`.
- [ ] **Imagen 4 superada:** Fila `Stock Inicial Base` y ecuación de saldo en `Trazabilidad` se muestran en 2 líneas adaptables sin truncar números ni texto en 320dp a tablets.
- [ ] **Imagen 4 superada:** Chips de filtro inferiores mantienen intacto su scroll horizontal con iconos limpios.
- [ ] **Imagen 4 superada:** Trazabilidad identifica con precisión variantes con `Stock Compartido` vs. `Stock Independiente`, cuadrando la ecuación matemática al 100%.
- [ ] **Imagen 4 superada:** `Abastecimiento Inteligente` desglosa paquetes incompletos en pool compartido y clasifica con claridad productos `Mixtos`.
- [ ] **Imagen 5 superada:** En `Cotización Inteligente`, la tarjeta derecha retraída con descuento muestra **SIEMPRE el Precio Final visible en grande**, junto al ahorro verde.
- [ ] **Imagen 5 superada:** Tarjetas izquierda y derecha de la Fila #3 tienen altura compacta y simétrica, eliminando por completo el hueco vacío inferior.
- [ ] `flutter analyze` ejecuta con **0 errores y 0 advertencias**.
