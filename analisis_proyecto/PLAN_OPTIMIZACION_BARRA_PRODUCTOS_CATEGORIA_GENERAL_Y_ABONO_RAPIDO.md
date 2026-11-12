# PLAN MAESTRO DE TRABAJO: OPTIMIZACIÓN DE BARRA DE HERRAMIENTAS, CICLO DE VIDA DE ALERTA DE STOCK, UNIFICACIÓN DE CATEGORÍA GENERAL Y TOGGLE LIBRE EN ABONO RÁPIDO

**Documento:** `analisis_proyecto/PLAN_OPTIMIZACION_BARRA_PRODUCTOS_CATEGORIA_GENERAL_Y_ABONO_RAPIDO.md`  
**Estado:** Propuesta de Planificación Técnica y Arquitectónica — Pendiente de Aprobación del Usuario  
**Metodología:** Loop Autónomo + Árbitro Adversarial  
**Módulos Afectados:**
1. `Gestión de Negocio` -> Pestaña `PRODUCTOS` (`inventory_filter_header.dart`, `products_tab.dart`, `custom_search_bar.dart`, `filter_drawer.dart`, `live_filter_bottom_sheet.dart`)
2. `Gestión de Negocio` -> Pestaña `CATEGORÍAS` (`categories_tab.dart`, `master_data_service.dart`, `inventory_provider.dart`, `product_repository.dart`)
3. `Perfil del Cliente` -> Modal `Registrar Abono` (`payment_entry_modal.dart`)

---

## 1. RESUMEN EJECUTIVO Y OBJETIVOS DE NEGOCIO / UX

Tras una rigurosa inspección visual asistida por las capturas de pantalla reales provistas (`9.16.05 PM.jpeg` y `11.47.32 AM (3).jpeg`) y una auditoría estática exhaustiva del código fuente en Dart y SQLite, se han identificado **4 áreas de mejora crítica** que impactan directamente la ergonomía, la claridad visual y la fidelidad operativa de la aplicación móvil:

1. **Compresión severa del Contador de Productos y Variantes (Captura 1):** La incorporación reciente del botón de estilo de alerta de stock (`🎨`) saturó el ancho horizontal de la barra de herramientas fija (`InventoryFilterHeader`). En dispositivos con anchos de `360dp` a `390dp`, el texto `105 Productos / 115 Variantes` dentro de su `FittedBox` sufre una reducción tipográfica extrema (descendiendo a ~6-7sp), tornándose microscópico e ilegible.
2. **Fuga de Ciclo de Vida del Aviso de Alerta de Stock (`🎨`) (Captura 1):** La notificación que informa el cambio de estilo de alerta visual utiliza el `ScaffoldMessenger.of(context).showSnackBar` del `Scaffold` raíz. Como consecuencia, el aviso queda anclado en pantalla durante 3 o más segundos, sobrevive al cambio de pestañas (`OFERTAS / BUNDLES`, `CATEGORÍAS`) y permanece visible incluso al navegar a otras pantallas de la app.
3. **Inconsistencia y Estigmatización de `[ Sin Categoría ]` vs. `General` (Captura 1):** En los chips horizontales de filtro se visualiza la etiqueta tosca `[ Sin Categoría ]`. Además de transmitir descuido estético, en la pestaña `CATEGORÍAS` los productos sin categoría o clasificados como `General` quedan completamente invisibilizados y desvinculados del conteo y la administración del catálogo.
4. **Imposibilidad de Desmarcar Etiquetas de Monto Rápido en `Registrar Abono` (Captura 2):** En el modal `Registrar Abono`, una vez que el usuario pulsa un chip de monto sugerido (`✓ Total S/ 3,149.00`), no existe mecanismo de Toggle para deseleccionarlo y limpiar el campo; presionar la misma etiqueta no produce ningún efecto de cancelación, obligando al usuario a borrar manualmente dígito por dígito con el teclado.

### Objetivos Clave de la Optimización:
* **Legibilidad y Responsividad 100% Garantizadas:** Reestructurar la distribución de la barra de herramientas para liberar entre `35dp` y `45dp` de espacio horizontal neto a favor del contador, imponiendo un piso tipográfico infranqueable (`12.5sp`–`13sp` bold para productos y `11sp` para variantes) con cero desbordamientos (`RenderFlex overflowed = 0`) desde `320dp` hasta tablets.
* **Ciclo de Vida Encapsulado y Desvanecimiento Automático a 2s:** Implementar un Toast flotante moderno y local en `ProductsTab` con temporizador reiniciable (`Timer` de 2000 ms), desacoplado del `ScaffoldMessenger` global y con destrucción instantánea ante cambios de pestaña o navegación.
* **Institucionalización de la Categoría `General`:** Renombrar `[ Sin Categoría ]` a `General` de manera uniforme, con visibilidad condicional inteligente (oculta si hay 0 productos asociados) y presencia formal en la pestaña `CATEGORÍAS` para contabilizar y auditar todos los productos huérfanos o generales de forma segura.
* **Toggle Libre y Sincronización Bidireccional en Abonos:** Permitir seleccionar y deseleccionar con un segundo toque cualquier etiqueta de monto rápido, limpiando el campo de entrada (`""`) para entrada manual sin fricción, y desmarcando visualmente los chips en tiempo real si el usuario edita o borra el número con el teclado.

---

## 2. DIAGNÓSTICO TÉCNICO EN PROFUNDIDAD (EVIDENCIA EN CÓDIGO)

### Diagnóstico Fase 1: Saturación Horizontal en `InventoryFilterHeader`
* **Archivo:** `lib/features/catalog/screens/tabs/widgets/inventory_filter_header.dart` (Líneas 296-388)
* **Evidencia Matemática del Espacio:**
  ```dart
  // Padding exterior del contenedor:
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14) // 32dp consumidos
  
  // Controles derechos acumulados en Row:
  - Botón ID (SortType.id): Icono (20dp) + Arrow (14dp) + Spacing (4dp) + Padding horizontal (20dp) = 58dp
  - Separador: 6dp
  - Botón A-Z (SortType.alpha): Icono (20dp) + Padding horizontal (20dp) = 40dp
  - Separador: 6dp
  - Botón Alerta Stock (🎨): Icono (20dp) + Padding horizontal (20dp) = 40dp
  - Divisor vertical con margen (horizontal: 10 * 2 + 1): 21dp
  - Selector de vistas segmentado: 3 botones de 36dp (108dp) + 2 divisores (2dp) + bordes (2dp) = 112dp
  - Separación entre Expanded y Row: 10dp
  
  // Total consumido por la derecha y márgenes:
  32dp + 58dp + 6dp + 40dp + 6dp + 40dp + 21dp + 112dp + 10dp = 325dp!!
  ```
* **Consecuencia:** En una pantalla estándar de Android con ancho lógico de `360dp`, quedan únicamente **35dp libres** para la columna del contador. En pantallas de `390dp`, quedan solo **65dp**. Al envolver los textos en `FittedBox(fit: BoxFit.scaleDown)`, Flutter se ve forzado a reducir la escala del texto a un microscópico `5sp`–`7sp` para evitar el crash por `RenderFlex overflowed`, volviendo el texto totalmente ilegible.

---

### Diagnóstico Fase 2: Fuga de Notificación Toast en `ScaffoldMessenger`
* **Archivo:** `lib/features/catalog/screens/tabs/widgets/inventory_filter_header.dart` (Líneas 241-258)
  ```dart
  onTap: () {
    provider.toggleStockAlertColors();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(!isActive ? "Colores de stock activados" : "Estilo neutro activado (colores desactivados)"),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(label: "Detalles", onPressed: () => _showColorAlertExplanation(context, isDark)),
      ),
    );
  }
  ```
* **Consecuencia:**
  1. `ScaffoldMessenger.of(context)` resuelve hacia el `Scaffold` ancestro raíz de `HomeScreen` / `MainLayout`.
  2. El `SnackBar` no pertenece a la vista `ProductsTab`. Si el usuario pulsa `🎨` y de inmediato toca la pestaña `CATEGORÍAS` o `OFERTAS / BUNDLES`, o navega a `Clientes` en el BottomBar, el SnackBar **permanece flotando en pantalla** interfiriendo con los controles de las otras vistas.
  3. Al tener una duración rígida de 3 segundos más un `SnackBarAction`, el temporizador se bloquea o demora en descartarse, generando sensación de congelamiento o sobrecarga visual.

---

### Diagnóstico Fase 3: Aislamiento de Productos Huérfanos y `[ Sin Categoría ]`
* **Archivos:**
  * `lib/core/widgets/custom_search_bar.dart` (Líneas 208-216)
  * `lib/core/widgets/filter_drawer.dart` (Línea 480)
  * `lib/core/widgets/live_filter_bottom_sheet.dart` (Línea 630)
  * `lib/features/catalog/screens/tabs/categories_tab.dart` (Líneas 460-545)
  * `lib/features/catalog/repositories/product_repository.dart` (Líneas 283-314)
* **Evidencia en Código:**
  * En SQLite, los productos sin categoría se guardan con `categoria_id IS NULL OR categoria_id = 0`.
  * La consulta `countOrphansRaw` obtiene:
    ```sql
    COUNT(DISTINCT CASE WHEN (p.categoria_id IS NULL OR p.categoria_id = 0) THEN p.id END) as orphan_categories
    ```
  * En `custom_search_bar.dart`:
    ```dart
    if (provider.hasOrphanCategories && index == 0) {
      return FilterChip(
        label: const Text('[ Sin Categoría ]'),
        selected: isSelected,
        onSelected: (val) => _toggleCategory(0, val, provider),
      );
    }
    ```
  * En `categories_tab.dart`:
    La lista solo itera sobre `provider.categories` (que provienen de la tabla `categorias`). Como no existe un registro con ID 0 en dicha tabla, **los productos sin categoría no aparecen en la pestaña `CATEGORÍAS`**, ni tampoco se unifican aquellos productos asignados a la categoría default `"General"`.
  * Además, los corchetes `[ ]` rompen con la línea gráfica del sistema de diseño de la app.

---

### Diagnóstico Fase 4: Ausencia de Toggle en Chips de Monto en `PaymentEntryModal`
* **Archivo:** `lib/features/smart_quotation/widgets/crm/payment_entry_modal.dart` (Líneas 608-610, 736-805)
* **Evidencia en Código:**
  ```dart
  Widget _buildQuickAmountCard({
    required String label,
    required double amount,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
    bool isWarning = false,
  }) {
    final double entered = double.tryParse(_amountCtrl.text) ?? 0.0;
    final bool isSelected = entered > 0 && (entered - amount).abs() < 0.01;
    // ...
  }
  ```
  Y en su invocación:
  ```dart
  _buildQuickAmountCard(
    label: "Total",
    amount: widget.client.totalDebt,
    color: isDark ? Colors.green[300]! : const Color(0xFF2E7D32),
    isDark: isDark,
    onTap: () {
      _amountCtrl.text = widget.client.totalDebt.toStringAsFixed(2);
    },
  )
  ```
* **Problema:** En el callback `onTap`, la acción siempre reasigna `_amountCtrl.text = amount.toStringAsFixed(2);`. Si `isSelected` es verdadero (el chip ya está marcado), tocarlo no hace nada. No existe un condicional que detecte si ya estaba seleccionado para limpiar el texto (`_amountCtrl.clear()`), impidiendo desmarcar la sugerencia y forzando al usuario a borrar manualmente.

---

## 3. PLAN DE TRABAJO Y SOLUCIÓN POR FASES

```
+-------------------------------------------------------------------------------------------------+
|                                 ARQUITECTURA DE LA SOLUCIÓN                                     |
+-------------------------------------------------------------------------------------------------+
|                                                                                                 |
|   [ FASE 1: BARRA DE PRODUCTOS ]        [ FASE 2: TOAST ALERTA STOCK ]                          |
|   - Padding horizontal: 16 -> 12        - Toast flotante local en ProductsTab                   |
|   - Botones Sort/🎨: pad horiz 10 -> 7   - Timer cancelable de 2.0s                              |
|   - Spacers: 6 -> 4 | Divider: 10 -> 5  - Reset de timer en clicks sucesivos                    |
|   - View Selector: 36 -> 30 por ítem    - Destrucción inmediata en dispose() / tab switch       |
|   - Ganancia: +38dp netos al Contador   - Cero fugas en ScaffoldMessenger global                |
|   - Tipografía mínima: 13sp / 11sp bold                                                         |
|                                                                                                 |
|   [ FASE 3: CATEGORÍA GENERAL ]         [ FASE 4: TOGGLE LIBRE ABONOS ]                         |
|   - Renombrar '[ Sin Categoría ]' ->    - Carrusel horizontal 100% preservado                   |
|     'General' (limpio, profesional)     - Tap en no seleccionado -> Marca e inyecta monto       |
|   - Visibilidad inteligente (>0 ítems)  - Tap en ya seleccionado -> Desmarca y limpia campo ("")|
|   - Inyección en tab CATEGORÍAS         - Edición manual -> Desmarca chip automáticamente       |
|   - Filtro reactivo & protección base                                                           |
+-------------------------------------------------------------------------------------------------+
```

---

### FASE 1: Optimización de Espacio y Legibilidad del Contador en la Barra de Herramientas de `PRODUCTOS`

#### 1.1. Rediseño Métrico y Compactación de Controles Derechos
* **Archivo:** `lib/features/catalog/screens/tabs/widgets/inventory_filter_header.dart`
* **Intervenciones Concretas:**
  1. **Reducción del Padding del Contenedor Raíz:**
     * Disminuir de `horizontal: 16` a `horizontal: 12` (ganancia neta: **+8dp**).
  2. **Compactación Ergonómica de Botones de Ordenamiento (`# ↓`, `AZ`) y Alerta de Stock (`🎨`):**
     * Disminuir padding interno de `horizontal: 10, vertical: 8` a `horizontal: 7, vertical: 6` (ganancia neta: **+18dp** entre los 3 botones).
     * Mantener un área táctil mínima accesible (`minHeight: 36dp`, `minWidth: 32dp`).
     * Reducir el espaciador horizontal entre botones de `SizedBox(width: 6)` a `SizedBox(width: 4)` (ganancia neta: **+4dp**).
  3. **Optimización del Divisor Vertical:**
     * Disminuir márgenes laterales de `margin: const EdgeInsets.symmetric(horizontal: 10)` a `margin: const EdgeInsets.symmetric(horizontal: 5)` (ganancia neta: **+10dp**).
  4. **Compactación del Selector de 3 Vistas (`Lista | Cuadrícula | Compacta`):**
     * Disminuir el ancho de cada celda de `width: 36` a `width: 30` o `31` y su altura a `36dp`, ajustando el tamaño de los iconos a `18.5dp` (ganancia neta: **+15dp** a **+18dp**).
  5. **Espaciador Central:**
     * Disminuir `SizedBox(width: 10)` a `SizedBox(width: 6)` entre el contador y el bloque derecho (ganancia neta: **+4dp**).
  * **Balance Total de Espacio Horizontal Recuperado:** Entre **+39dp y +44dp** transferidos directamente a favor del contador izquierdo.

#### 1.2. Blindaje Tipográfico y Anti-Truncamiento del Contador
* Sustituir el `FittedBox` agresivo sin piso mínimo por una composición tipográfica legible y robusta:
  * Línea 1 (`Productos`): `fontSize: 13.0sp`, `fontWeight: FontWeight.w800`, `letterSpacing: -0.2`.
  * Línea 2 (`Variantes`): `fontSize: 11.0sp`, `fontWeight: FontWeight.w600`, color atenuado.
  * Añadir `maxLines: 1`, `overflow: TextOverflow.ellipsis` controlado únicamente como salvaguarda en pantallas extremas (< 310dp).
  * Con los +40dp ganados, el contador dispondrá de un ancho de **75dp a 105dp** en pantallas de 360dp a 390dp, espacio más que suficiente para albergar `"999 Productos"` (~72dp) y `"999 Variantes"` (~60dp) sin sufrir ninguna compresión.

---

### FASE 2: Auto-Ocultamiento Suave y Ciclo de Vida de la Tarjeta Flotante de "Estilo de Alerta de Stock" (`🎨`)

#### 2.1. Arquitectura de Estado Local y Temporizador Reactivo
* **Archivos:**
  * `lib/features/catalog/screens/tabs/products_tab.dart`
  * `lib/features/catalog/screens/tabs/widgets/inventory_filter_header.dart`
* **Implementación Técnica:**
  1. **Desvincular `ScaffoldMessenger`:** Remover el llamado `ScaffoldMessenger.of(context).showSnackBar(...)` de `_buildStockAlertColorButton`.
  2. **Notificación Directa mediante Callback:**
     * Agregar un callback `VoidCallback? onStockAlertToggled` en `InventoryFilterHeader`.
     * En `ProductsTab`, gestionar el estado del Toast local:
       ```dart
       String? _stockAlertToastMessage;
       bool _showStockAlertToast = false;
       Timer? _stockAlertToastTimer;
       ```
  3. **Lógica de Temporización y Re-disparo Dinámico:**
     * Al recibir el evento de alternancia, verificar el estado activo en `InventoryProvider`.
     * Cancelar de inmediato cualquier temporizador activo previo (`_stockAlertToastTimer?.cancel()`).
     * Actualizar el mensaje de inmediato en memoria:
       * Activo: `"Colores de stock activados"`
       * Inactivo: `"Estilo neutro activado"`
     * Activar `_showStockAlertToast = true` mediante `setState`.
     * Iniciar un nuevo `Timer(const Duration(milliseconds: 2000), () { if (mounted) setState(() => _showStockAlertToast = false); });`.
     * Si el usuario presiona el botón 5 veces consecutivas, el mensaje muta instantáneamente en pantalla y el contador se reinicia a 2.0 segundos sin encolar ni apilar widgets.

#### 2.2. Diseño Visual y Ciclo de Vida Limpio
* **Componente Visual:** Integrar en el `Stack` principal de `ProductsTab` una pastilla flotante animada con `AnimatedSlide` y `AnimatedOpacity` (o `AnimatedSwitcher`):
  * Ubicación: Parte superior central, justo debajo de la barra de búsqueda o superpuesta sutilmente.
  * Estilo: Glassmorphism / Dark Surface con borde semitransparente teal/verde, icono `Icons.palette_rounded` y texto en `13sp` con tipografía nítida.
* **Blindaje en `dispose()` y Cambio de Pestañas:**
  * En el método `dispose()` de `_ProductsTabState`, ejecutar `_stockAlertToastTimer?.cancel();`.
  * Si el usuario desliza o conmuta la pestaña en `InventoryScreen` (a `OFERTAS / BUNDLES` o `CATEGORÍAS`), el widget oculta inmediatamente el aviso para que nunca invada pantallas ajenas.

---

### FASE 3: Unificación Profesional de la Categoría `General` (Reemplazo de `[ Sin Categoría ]` en Filtros y Pestaña `CATEGORÍAS`)

#### 3.1. Estandarización en Chips de Filtro de `PRODUCTOS`
* **Archivo:** `lib/core/widgets/custom_search_bar.dart` (y sincronización en `filter_drawer.dart` y `live_filter_bottom_sheet.dart`)
* **Acciones:**
  1. **Reemplazo Textual y Estético:**
     * Cambiar el texto `'[ Sin Categoría ]'` por `'General'`.
     * Eliminar los corchetes `[ ]` para que adopte el diseño idéntico, sobrio y homogéneo de los chips de categorías reales.
  2. **Visibilidad Condicional Inteligente:**
     * Actualmente se comprueba `provider.hasOrphanCategories`.
     * El chip `'General'` **solo debe mostrarse si:**
       * `provider.orphanCategoriesCount > 0`, **O**
       * Existe una categoría formal llamada `"General"` en `provider.categories` con `productsCount > 0`.
     * Si ambos conteos son `0`, el chip `'General'` se oculta automáticamente, evitando clutter innecesario.
  3. **Prevención de Duplicados:**
     * Si la base de datos ya contiene un registro con `nombre == 'General'`, unificarlo para que en el scroll horizontal de chips solo aparezca **un único chip `General`** representativo.

#### 3.2. Incorporación de la Categoría `General` en la Pestaña `CATEGORÍAS`
* **Archivos:**
  * `lib/features/catalog/screens/tabs/categories_tab.dart`
  * `lib/features/catalog/providers/inventory_provider.dart`
* **Acciones:**
  1. **Inclusión de `General` en el Listado:**
     * En `categories_tab.dart`, al construir la lista a partir de `provider.categories`, evaluar si existe al menos 1 producto en el inventario con categoría general o sin categoría asignada (`provider.orphanCategoriesCount > 0` o categoría `General` existente).
     * Si no existe un registro explícito en la base de datos pero hay productos huérfanos, inyectar una categoría sintética/base del sistema:
       * `id: 0`
       * `nombre: "General"`
       * `descripcion: "Categoría base del sistema para productos sin categoría asignada"`
       * `productsCount: provider.orphanCategoriesCount`
       * `activo: true`
  2. **Interacción y Filtrado al Tocar:**
     * Al tocar la tarjeta de `General`, desplegar el `MasterDetailModal` indicando el uso real: `"${category.productsCount} productos vinculados"`.
     * Ofrecer la acción de visualizar/filtrar dichos productos en el catálogo de inventario.
  3. **Protección del Sistema:**
     * Bloquear la opción de eliminación (`canDelete = false`) indicando: `"Categoría base protegida del sistema. No puede ser eliminada."`.

---

### FASE 4: Desmarcado Libre (Toggle On/Off) en las Etiquetas de Monto Rápido del Modal `Registrar Abono`

#### 4.1. Conservación Estricta del Layout Horizontal Deslizable
* **Archivo:** `lib/features/smart_quotation/widgets/crm/payment_entry_modal.dart` (Líneas 728-805)
* Se mantiene exactamente la estructura visual actual del carrusel:
  ```dart
  SizedBox(
    height: 52,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row( ... ),
    ),
  )
  ```
* No se altera la disposición en una sola línea horizontal deslizable, la cual cuenta con la plena aprobación del usuario.

#### 4.2. Lógica de Toggle Completa (Seleccionar / Desmarcar)
* **Archivo:** `payment_entry_modal.dart` (Líneas 608-682, 735-805)
* **Lógica a Implementar:**
  1. En `_buildQuickAmountCard`:
     * Ya se evalúa `final bool isSelected = entered > 0 && (entered - amount).abs() < 0.01;`.
  2. Al presionar el chip (`onTap`):
     ```dart
     onTap: () {
       if (isSelected) {
         // Desmarcar: Limpiar el campo dejándolo en blanco para entrada manual
         _amountCtrl.clear();
       } else {
         // Marcar: Inyectar el monto formateado a 2 decimales
         _amountCtrl.text = amount.toStringAsFixed(2);
       }
       // El listener de _amountCtrl disparará setState(() {}) actualizando la UI
     }
     ```
  3. **Comportamiento Reactivo y Transiciones:**
     * Al desmarcarse, `AnimatedContainer` y `AnimatedSwitcher` realizan la transición suave al estado neutro sin sobresaltos.
     * Al quedar `_amountCtrl.text` vacío (`""`), `enteredAmount` se convierte en `0.0`:
       * Se deshabilita el botón `PROCESAR PAGO` hasta que el usuario ingrese un monto.
       * Se limpia el desglose de cuotas automáticas en `GeneralPreviewTab`, esperando la cifra manual.
  4. **Desmarcado Automático por Edición Manual:**
     * Gracias a la condición reactiva `(entered - amount).abs() < 0.01`, si el usuario selecciona `"Total"` (`3149.00`) y luego mediante el teclado borra un dígito o escribe `"2000"`, la condición `isSelected` se evalúa inmediatamente a `false`, desmarcando el chip de inmediato sin desincronización de estado.

---

## 4. MATRIZ DE RESPONSIVIDAD Y BLINDAJE ANTI-REGRESIÓN

| Factor / Escenario | Comportamiento Actual | Solución Blindada | Validación Adversarial |
| :--- | :--- | :--- | :--- |
| **Dispositivo 320dp (Smallest Phone)** | Overflow `RenderFlex` o texto contador encogido a 5sp | Espacio horizontal optimizado (+40dp) y tipografía con piso mínimo de 12.5sp | `flutter test` de overflow en 320x568 |
| **Dispositivo 360dp (Android Estándar)** | Contador reducido y comprimido | Contador holgado con 85dp+ de ancho disponible, texto 13sp bold nítido | Prueba en emulador / Layout inspector |
| **Repetidos Clicks en Botón `🎨`** | Se acumulan SnackBars o se queda pegado 3+ segundos | Timer reiniciable de 2.0s, texto muta en vivo sin apilamiento | Simulación de 5 toques rápidos consecutivos |
| **Cambio de Pestaña con Toast activo** | SnackBar permanece en pantalla en pestañas ajenas | Toast destruido inmediatamente por el ciclo de vida local | Conmutación instantánea de pestañas |
| **Inventario sin productos en `General`** | Chip `[ Sin Categoría ]` se muestra siempre si hay huérfanos | Chip `General` solo visible si `count > 0` | Verificación con BD vacía y con ítems |
| **Re-pulsación de Chip de Monto Rápido** | No hace nada; monto permanece fijo | Desmarca el chip y vacía el campo numérico (`""`) | Tap repetido en chip seleccionado |
| **Edición manual tras seleccionar chip** | Puede quedar seleccionado incongruentemente | Se desmarca instantáneamente al cambiar el valor numérico | Escritura de dígito alternativo en `_amountCtrl` |

---

## 5. PROTOCOLO DE VERIFICACIÓN Y CRITERIOS DE ACEPTACIÓN DEL ÁRBITRO ADVERSARIAL

Para dar por concluida la implementación tras la orden de ejecución, deberán cumplirse rigurosamente los siguientes criterios de calidad:

1. **Prueba de Cero Overflows (`flutter analyze` & Layout Inspector):**
   * Ejecutar análisis estático sin warnings ni errores en los archivos modificados.
   * Verificar en pantallas de `320dp`, `360dp` y `412dp` que `InventoryFilterHeader` mantenga `RenderFlex overflowed = 0`.
2. **Prueba de Legibilidad Tipográfica:**
   * Comprobar que en ningún escenario de pantalla el texto `"X Productos"` baje de `12.5sp` ni se mutile con elipsis prematura.
3. **Prueba de Ciclo de Vida del Toast (`🎨`):**
   * Pulsar `🎨` -> Verificar aparición suave del Toast.
   * Esperar 2.0 segundos -> Verificar desvanecimiento automático completo.
   * Pulsar `🎨` repetidamente -> Verificar actualización inmediata y reseteo del temporizador.
   * Pulsar `🎨` e inmediatamente cambiar a `CATEGORÍAS` -> Verificar que el Toast desaparezca instantáneamente.
4. **Prueba de Sincronización de `General`:**
   * Comprobar que en `PRODUCTOS` el chip aparezca como `General` (sin corchetes).
   * Comprobar que en la pestaña `CATEGORÍAS` figure `General` con el conteo exacto de productos huérfanos o generales.
   * Tocar la categoría `General` en `CATEGORÍAS` y comprobar que abre el modal con sus productos vinculados y el botón eliminar bloqueado por seguridad.
5. **Prueba de Toggle en `Registrar Abono`:**
   * Abrir modal en cliente con deuda.
   * Tocar chip `"Total"` -> Se marca con `✓` verde y el campo se llena con el monto exacto.
   * Volver a tocar chip `"Total"` -> Se desmarca suavemente y el campo queda completamente vacío (`""`).
   * Tocar chip `"Total"` y luego teclear `"100"` -> El chip `"Total"` se desmarca en tiempo real.

