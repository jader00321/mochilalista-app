# 🚀 PLAN MAESTRO DE TRABAJO: REFINAMIENTO DE LA BURBUJA FLOTANTE SECUNDARIA (`DeepNavReturnPill`)
## Visibilidad Garantizada, Desacoplamiento Total del Home, Física Fluida 1:1 en Ambas Esquinas, Rediseño Compacto y Gestos Reactivos Milimétricos

**Documento de Especificación Técnica, Diagnóstico Forense y Protocolo Adversarial**  
**Proyecto:** MochilaLista App (Local-First SQLite, 0ms Latency, Flutter)  
**Módulos Involucrados:**
- **Burbuja Flotante Secundaria:** `lib/core/widgets/deep_nav_return_pill.dart`
- **Estado de Sesión en Memoria:** `lib/core/widgets/floating_dock_session_state.dart` (Desacoplamiento hacia `SecondaryBubbleSessionState`)
- **Burbuja Principal del Home:** `lib/core/widgets/persistent_work_dock.dart` (Intacta al 100%)
- **Ventanas Permitidas de Montaje:**
  - `lib/features/catalog/screens/inventory_screen.dart` (Inventario)
  - `lib/features/catalog/screens/catalog/catalog_screen.dart` (Catálogo de Ventas)
  - `lib/features/smart_quotation/screens/crm/client_tracking_screen.dart` (Directorio de Clientes)
  - `lib/features/smart_quotation/screens/sales_history_screen.dart` (Historial de Ventas)
  - Subpantallas directas: `product_detail_screen.dart`, `client_detail_screen.dart`
- **Contenedor Raíz:** `lib/core/screens/home_screen.dart` (IndexedStack de navegación inferior)
**Fecha:** Octubre 2026  
**Metodología:** Loop Autónomo + Árbitro Adversarial Estricto  

---

## 🔍 1. AUDITORÍA FORENSE Y DIAGNÓSTICO EN CÓDIGO FUENTE

A partir de la inspección exhaustiva del código fuente en `deep_nav_return_pill.dart`, `floating_dock_session_state.dart`, `persistent_work_dock.dart` y las pantallas donde se aloja, se ha identificado la causa raíz exacta de cada uno de los problemas reportados:

| Problema Reportado | Archivo y Líneas Exactas | Diagnóstico Forense de la Causa Raíz | Impacto en la Experiencia de Usuario |
| :--- | :--- | :--- | :--- |
| **1. Desaparición en pestañas del Home** (Solo visible desde tarjetas grid) | `deep_nav_return_pill.dart`<br>**Líneas 218-219** | ```dart\nfinal canPop = ModalRoute.of(context)?.canPop ?? false;\nif (!canPop) return const SizedBox.shrink();\n```<br>Cuando el usuario navega a través de las pestañas inferiores del `HomeScreen` (`NavigationBar`), las pantallas de `Inventario`, `Catálogo` y `Clientes` se renderizan como hijos del `IndexedStack` en la ruta raíz. En dicha ruta raíz, `ModalRoute.of(context)?.canPop` devuelve estrictamente **`false`**. La línea 219 silencia y destruye la burbuja devolviendo `SizedBox.shrink()`. Solo aparecía cuando se abría `SalesHistoryScreen` o `ClientTrackingScreen` mediante `Navigator.push` desde el `SmartActionGrid` del Home. | El usuario pierde acceso a sus operaciones en curso (Caja Rápida, Factura Staging, etc.) si navega con naturalidad usando la barra inferior. |
| **2. Acoplamiento indebido con la Burbuja del Home** | `deep_nav_return_pill.dart`<br>**L88-94, L102-107, L235-243**<br>`floating_dock_session_state.dart`<br>**L7-24** | `DeepNavReturnPill` lee y muta directamente las variables estáticas de `FloatingDockSessionState`: `isLeftEdge`, `isEdgeTucked`, `panX`, `panBottom` y `selectedTaskIndex`. Estas son las mismas variables que gobiernan el dock y globo flotante del Home (`PersistentWorkDock`).<br>Cualquier arrastre, pliegue o cambio de tarea en ventanas internas corrompe el estado del Home y viceversa. | Mover o esconder la burbuja en Inventario desubica o repliega arbitrariamente el dock en el Home, violando el principio de aislamiento. |
| **3. Imposibilidad de anclaje en el borde derecho y física tiesa** | `deep_nav_return_pill.dart`<br>**L360, L389-393, L419-428** | **Causa A (Clamp asesino):** En L390 se calculaba:<br>`_panX = (startX + event.localDelta.dx).clamp(0.0, screenWidth - 120.0);`<br>Y en L422 para esconder al borde derecho se evaluaba:<br>`else if (currentX > screenWidth - 100.0) { _isEdgeTucked = true; }`<br>Dado que `_panX` estaba restringido a un tope máximo de `screenWidth - 120.0`, era **matemáticamente imposible** que `currentX` superara `screenWidth - 100.0`!<br>**Causa B (Inestabilidad de deltas locales):** Usar `event.localDelta` dentro de un widget que se traslada bajo el dedo genera fluctuación de coordenadas locales y movimiento tieso.<br>**Causa C (Salto de constraints):** Pasar bruscamente de `right: 16` a `left: _panX` en `AnimatedPositioned` generaba un salto de posición al arrancar el arrastre en la derecha. | El usuario siente el arrastre rígido, torpe, y no puede pegar ni retraer la burbuja hacia la derecha de la pantalla. |
| **4. Sobrecarga visual y flecha `>` innecesaria** | `deep_nav_return_pill.dart`<br>**L476-540** | El widget construye una barra alargada con una columna vertical compuesta por `currentTask.label` (`"Caja Rápida (1)"`) y `currentTask.sublabel` (`"S/ 1,234.50"` o `"5 grupos pendientes"`), rematada con un icono rígido `Icons.arrow_forward_ios_rounded` (`>`). | Parece una tarjeta alargada que estorba la visualización de listas de productos o clientes, en lugar de una cápsula flotante compacta, moderna y minimalista. |
| **5. Transiciones rígidas en conmutación de tareas** | `deep_nav_return_pill.dart`<br>**L402-411, L470-475** | Al soltar el dedo tras la pulsación estacionaria, no se verifica el clamp adecuado en caso de cambio de tareas activas y la animación en `AnimatedSwitcher` carece de curvas de atenuación elásticas con micro-vibración y pulso sutil de borde. | El intercambio de tareas resulta plano y poco reactivo, sin dar la sensación táctil de estar "rotando" entre procesos en curso. |

---

## 🎯 2. OBJETIVOS ARQUITECTURALES Y DE DISEÑO

1. **Aparición Garantizada en las Ventanas Permitidas (100% Independiente de la Ruta de Origen):**
   - Eliminar de raíz la condición `final canPop = ModalRoute.of(context)?.canPop ?? false; if (!canPop) return const SizedBox.shrink();`.
   - La burbuja se mostrará **siempre** en `Inventario`, `Catálogo`, `Directorio de Clientes` e `Historial de Ventas` (y detalles asociados), sin importar si se accedió por pestaña inferior (`IndexedStack`), por `Navigator.push`, por banner o por acceso rápido.
   - Se auto-oculta limpiamente **únicamente** si:
     - No hay usuario/negocio activo (`!auth.hasActiveContext`).
     - No existe ninguna operación pendiente activa (`activeTasks.isEmpty`).
     - El usuario ya se encuentra en la pantalla de esa única operación pendiente (`widget.currentScreenId == currentTask.id`).
2. **Desacoplamiento Absoluto: Creación de `SecondaryBubbleSessionState`:**
   - La burbuja del Home (`PersistentWorkDock`) mantiene al 100% su diseño, lógica, física, animaciones y uso exclusivo de `FloatingDockSessionState`. Cero modificaciones a su comportamiento.
   - Creación de la clase `SecondaryBubbleSessionState` en `lib/core/widgets/floating_dock_session_state.dart` para gestionar de forma aislada:
     - `isLeftEdge`: Lado de anclaje lateral (por defecto `false`, borde derecho para no entorpecer listas).
     - `isEdgeTucked`: Estado de retracción en el borde (pestaña discreta).
     - `panX`: Coordenada horizontal libre.
     - `panBottom`: Coordenada vertical persistente.
     - `selectedTaskIndex`: Índice de la tarea activa mostrada.
   - **Persistencia Global Compartida entre Ventanas Internas:** Si el usuario mueve la burbuja al borde izquierdo superior en `Inventario` y conmuta a `Catálogo`, `Clientes` o `Historial`, la burbuja se mantendrá exactamente en esa misma coordenada, estado retraído/desplegado y tarea seleccionada.
3. **Física Fluida 1:1 en Tiempo Real y Anclaje Magnético Bilateral (Izquierda y Derecha):**
   - **Durante el arrastre (`_isDragging == true`):** Latencia cero (0ms) configurando `duration: Duration.zero` en `AnimatedPositioned`, rastreando deltas globales basados en la posición absoluta del puntero (`event.position`) para eliminar saltos y vibraciones.
   - **Al soltar el dedo (`_isDragging == false`):** Animación suave con curva `Curves.easeOutCubic` (300ms) que calcula magnéticamente el borde más cercano:
     $$\text{centroBurbuja} = \text{panX} + \frac{\text{pillWidth}}{2}$$
     $$\text{isLeftEdge} = \text{centroBurbuja} < \frac{\text{screenWidth}}{2}$$
   - **Corrección de Coordenadas de Borde Derecho:** Unificar la posición horizontal en términos de `leftPos` normalizado respecto al ancho de pantalla:
     $$\text{leftPos (Derecha)} = \text{screenWidth} - \text{pillWidth} - \text{marginRight}$$
     Garantizando que tanto en el borde izquierdo (`left: 16.0`) como en el derecho funcione con idéntica fluidez física, sin saltos ni límites truncados.
4. **Rediseño Visual: Cápsula Flotante Moderna, Compacta y Cero Flecha (`>`):**
   - **Forma:** Cápsula estilizada súper redondeada (`BorderRadius.circular(28)`), con elevación sutil y sombra cromática suave derivada del color semántico del proceso.
   - **Identidad Visual:** Contenedor circular (30x30 dp) con icono nítido del proceso en segundo plano con tinte translúcido distintivo.
   - **Enunciado Breve:** Texto directo sin sobrecarga: `"Caja Rápida"`, `"Cotización"`, `"Factura Staging"`, `"Conciliación"`, `"Producto Nuevo"`.
   - **Píldora Contador Discreto:** Si hay más de 1 tarea activa, muestra un badge numérico ultra compacto `${taskIndex + 1}/$totalTasks` (o un indicador `1` si solo hay una tarea).
   - **Cero Flecha Derecha:** Erradicación total del icono chevron `>` para un acabado limpio y minimalista.
   - **Eliminación de montos en soles:** Se eliminan los subtítulos largos de `S/ 1,234.50` para evitar polución visual.
5. **Máquina de Gestos Reactiva (4 Interacciones Perfeccionadas):**
   - **Gesto 1 (Tap Rápido):** Navega instantáneamente a la pantalla del proceso activo si está desplegada; si estaba retraída en el borde, se despliega con animación elástica.
   - **Gesto 2 (Long-Press Estacionario ~450ms):** Conmuta a la siguiente tarea activa (`selectedTaskIndex = (index + 1) % totalTasks`) mediante `AnimatedSwitcher` con fade + scale sutil y `HapticFeedback.selectionClick()`, sin navegar.
   - **Gesto 3 (Drag Libre 2D):** Si el dedo se mueve más de 8px antes de los 450ms, cancela la conmutación y desplaza la burbuja con fluidez total por la pantalla en X e Y.
   - **Gesto 4 (Retracción en Borde Izquierdo o Derecho):** Al empujar la burbuja contra el borde izquierdo ($X < 24\text{px}$) o derecho ($X > \text{screenWidth} - \text{pillWidth} - 24\text{px}$), se retrae convirtiéndose en una pestaña redondeada discreta con indicador luminoso.

---

## 🏗️ 3. PLAN DE EJECUCIÓN EN 5 FASES

```mermaid
flowchart TD
    subgraph FASE 1: Desacoplamiento de Estado en Memoria
        F1_1[Crear SecondaryBubbleSessionState en floating_dock_session_state.dart] --> F1_2[Preservar FloatingDockSessionState 100% intacto para Home]
        F1_2 --> F1_3[Vincular DeepNavReturnPill exclusivamente a SecondaryBubbleSessionState]
        F1_3 --> F1_4[Garantizar sincronización global entre Inventario, Catálogo, Clientes e Historial]
    end

    subgraph FASE 2: Garantía de Visibilidad en Ventanas Permitidas
        F2_1[Eliminar restricción ModalRoute.canPop en deep_nav_return_pill.dart] --> F2_2[Verificar condiciones de auto-ocultamiento limpio]
        F2_2 --> F2_3[Auditar IndexedStack del HomeScreen: asegurar que se pinte en tabs 1, 2, 3]
        F2_3 --> F2_4[Confirmar que en Home tab 0 no se duplica con PersistentWorkDock]
    end

    subgraph FASE 3: Reingeniería de Física 1:1 y Anclaje Bilateral
        F3_1[Eliminar latencia durante arrastre: duration = Duration.zero] --> F3_2[Corregir cálculo de coordenadas globales con event.position]
        F3_2 --> F3_3[Eliminar clamp restrictivo screenWidth - 120]
        F3_3 --> F3_4[Implementar magnetismo simétrico suave: Curves.easeOutCubic al soltar]
    end

    subgraph FASE 4: Rediseño Visual de Cápsula Flotante
        F4_1[Diseñar cápsula compacta BorderRadius.circular 28] --> F4_2[Contenedor circular para icono con color semántico]
        F4_2 --> F4_3[Enunciado breve directo: Caja Rápida, Cotización, Factura, etc.]
        F4_3 --> F4_4[Píldora contador discreta y eliminación definitiva del icono chevron >]
    end

    subgraph FASE 5: Pulido de los 4 Gestos Reactivos y Blindaje de Pruebas
        F5_1[Perfeccionar máquina de estados: Tap, Long-Press 450ms, Drag 2D, Edge Tuck] --> F5_2[Asegurar retracción simétrica tanto en borde izquierdo como derecho]
        F5_2 --> F5_3[Crear suite de pruebas automatizadas en test/deep_nav_secondary_bubble_test.dart]
        F5_3 --> F5_4[Ejecución de flutter test global y análisis estático con 0 warnings]
    end

    FASE 1 --> FASE 2 --> FASE 3 --> FASE 4 --> FASE 5
```

---

## 📝 4. ESPECIFICACIÓN TÉCNICA DETALLADA POR FASE

### FASE 1: Desacoplamiento de Estado en Memoria (`SecondaryBubbleSessionState`)

#### Archivos Involucrados:
- `lib/core/widgets/floating_dock_session_state.dart`
- `lib/core/widgets/deep_nav_return_pill.dart`
- `lib/core/widgets/persistent_work_dock.dart` (Auditoría de no-interferencia)

#### Especificación de Código:
1. En `lib/core/widgets/floating_dock_session_state.dart`:
   - Mantener la clase `FloatingDockSessionState` intacta para `PersistentWorkDock`.
   - Incorporar la nueva clase:
   ```dart
   /// 🫧 SecondaryBubbleSessionState - Estado en Memoria para Burbuja Flotante Secundaria
   ///
   /// Gobierna de manera 100% aislada la persistencia espacial (X, Y), el anclaje lateral
   /// (izquierdo o derecho), el modo retraído en borde (edge peek) y la tarea activa
   /// de DeepNavReturnPill a lo largo de todas las pantallas internas permitidas.
   /// NUNCA comparte variables con FloatingDockSessionState para blindar el Home.
   class SecondaryBubbleSessionState {
     static bool isLeftEdge = false; // Por defecto a la derecha para no tapar contenido
     static bool isEdgeTucked = false;
     static double? panX;
     static double? panBottom;
     static int selectedTaskIndex = 0;

     /// Restablece el estado secundario a valores iniciales limpios
     static void reset() {
       isLeftEdge = false;
       isEdgeTucked = false;
       panX = null;
       panBottom = null;
       selectedTaskIndex = 0;
     }
   }
   ```
2. En `lib/core/widgets/deep_nav_return_pill.dart`:
   - Reemplazar toda invocación de `FloatingDockSessionState` por `SecondaryBubbleSessionState`.
   - Inicializar en `initState`:
     ```dart
     _isLeftEdge = SecondaryBubbleSessionState.isLeftEdge;
     _isEdgeTucked = SecondaryBubbleSessionState.isEdgeTucked;
     _panBottom = SecondaryBubbleSessionState.panBottom;
     _panX = SecondaryBubbleSessionState.panX;
     ```
   - Sincronizar en `_syncSessionState()`:
     ```dart
     SecondaryBubbleSessionState.isLeftEdge = _isLeftEdge;
     SecondaryBubbleSessionState.isEdgeTucked = _isEdgeTucked;
     SecondaryBubbleSessionState.panBottom = _panBottom;
     SecondaryBubbleSessionState.panX = _panX;
     SecondaryBubbleSessionState.selectedTaskIndex = _selectedTaskIndex;
     ```

---

### FASE 2: Garantía de Visibilidad en las Ventanas Permitidas

#### Archivos Involucrados:
- `lib/core/widgets/deep_nav_return_pill.dart`
- `lib/core/screens/home_screen.dart`
- `lib/features/catalog/screens/inventory_screen.dart`
- `lib/features/catalog/screens/catalog/catalog_screen.dart`
- `lib/features/smart_quotation/screens/crm/client_tracking_screen.dart`
- `lib/features/smart_quotation/screens/sales_history_screen.dart`

#### Diagnóstico y Solución:
1. **Eliminación del Bloqueo:** En `deep_nav_return_pill.dart`, suprimir completamente:
   ```dart
   // ELIMINAR:
   final canPop = ModalRoute.of(context)?.canPop ?? false;
   if (!canPop) return const SizedBox.shrink();
   ```
2. **Condiciones de Visibilidad Robustas:**
   ```dart
   final auth = Provider.of<AuthProvider>(context, listen: false);
   if (!auth.hasActiveContext) return const SizedBox.shrink();

   final activeTasks = _buildActiveTasks(context);
   if (activeTasks.isEmpty) return const SizedBox.shrink();

   // Clamp de seguridad del índice seleccionado
   int selectedIndex = SecondaryBubbleSessionState.selectedTaskIndex;
   if (selectedIndex >= activeTasks.length) {
     selectedIndex = activeTasks.length - 1;
     SecondaryBubbleSessionState.selectedTaskIndex = selectedIndex;
   }
   if (selectedIndex < 0) {
     selectedIndex = 0;
     SecondaryBubbleSessionState.selectedTaskIndex = 0;
   }

   final currentTask = activeTasks[selectedIndex];

   // Auto-ocultar si el usuario ya se encuentra en la pantalla de esa única tarea
   if (activeTasks.length == 1 && widget.currentScreenId == currentTask.id) {
     return const SizedBox.shrink();
   }
   ```
3. **Auditoría de Comportamiento en `HomeScreen` (`IndexedStack`):**
   - En `HomeScreen`, cuando `_currentIndex == 0` (Home Dashboard), los widgets en índices 1, 2 y 3 (`InventoryScreen`, `CatalogScreen`, `ClientTrackingScreen`) quedan envueltos en `Offstage(offstage: true)`. Por tanto, sus respectivas instancias de `DeepNavReturnPill` no se pintan ni responden a toques en el Home. Solo se muestra el `PersistentWorkDock` del Home.
   - Cuando el usuario toca la pestaña `Inventario` (índice 1), `InventoryScreen` pasa a estar activo (`offstage: false`) y su `DeepNavReturnPill` se renderiza de inmediato con todas las operaciones pendientes, cumpliendo el requerimiento de no depender de los accesos rápidos del Home.

---

### FASE 3: Física de Movimiento Fluida 1:1 y Anclaje Bilateral Simétrico

#### Archivos Involucrados:
- `lib/core/widgets/deep_nav_return_pill.dart`

#### Reingeniería Matemática y de Física:
1. **Dimensiones de Referencia de la Cápsula:**
   - Ancho estimado cápsula: `const double pillWidth = 148.0;`
   - Altura cápsula: `const double pillHeight = 44.0;`
   - Ancho pestaña retraída: `const double tuckWidth = 26.0;`
   - Altura pestaña retraída: `const double tuckHeight = 56.0;`
   - Margen horizontal de pantalla: `const double marginX = 16.0;`
2. **Latencia Cero en Arrastre (0ms):**
   - En el `AnimatedPositioned`:
     ```dart
     duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
     curve: Curves.easeOutCubic,
     ```
3. **Rastreo de Coordenadas Globales Sin Deriva:**
   - En lugar de acumular `event.localDelta` (que se distorsiona con el movimiento del contenedor), almacenar `_initialPointerPos = event.position`, `_initialPanX = _currentRenderedX`, `_initialPanBottom = effectiveBottom`.
   - En `onPointerMove`:
     $$\Delta X = \text{event.position.dx} - \text{initialPointerPos.dx}$$
     $$\Delta Y = \text{event.position.dy} - \text{initialPointerPos.dy}$$
     $$\text{nuevoPanX} = (\text{initialPanX} + \Delta X).\text{clamp}(0.0, \text{screenWidth} - \text{pillWidth})$$
     $$\text{nuevoPanBottom} = (\text{initialPanBottom} - \Delta Y).\text{clamp}(\text{minBottom}, \text{maxBottom})$$
4. **Anclaje Magnético Bilateral y Esquinas al Soltar:**
   - En `onPointerUp`:
     - **Retracción al Borde Izquierdo:** Si $\text{currentX} < 20.0$ $\rightarrow$ `_isEdgeTucked = true; _isLeftEdge = true;`
     - **Retracción al Borde Derecho:** Si $\text{currentX} > \text{screenWidth} - \text{pillWidth} - 20.0$ $\rightarrow$ `_isEdgeTucked = true; _isLeftEdge = false;`
     - **Anclaje Libre Flotante:** Si está en el cuerpo de la pantalla:
       - `_isEdgeTucked = false;`
       - $\text{centroBurbuja} = \text{currentX} + (\text{pillWidth} / 2);$
       - `_isLeftEdge = centroBurbuja < (screenWidth / 2);`
       - `_panX = null;` (Delega a la posición magnética `left: 16.0` o `left: screenWidth - pillWidth - 16.0` con animación suave).

---

### FASE 4: Rediseño Visual de Cápsula Flotante Súper Redondeada

#### Archivos Involucrados:
- `lib/core/widgets/deep_nav_return_pill.dart`

#### Especificación de UI y Widget Tree:
1. **Depuración de Textos y Títulos Concisos:**
   - Configurar etiquetas cortas para los 5 procesos en `_PendingTaskItem`:
     - Caja Rápida $\rightarrow$ `"Caja Rápida"`
     - Escáner Staging $\rightarrow$ `"Factura Staging"`
     - Conciliación Lista $\rightarrow$ `"Conciliación"`
     - Cotización Manual $\rightarrow$ `"Cotización"`
     - Creación de Producto $\rightarrow$ `"Producto Nuevo"`
   - Eliminar completamente `sublabel` del árbol visual.
2. **Eliminación Total del Chevron Derecho (`>`):**
   - Suprimir `Icon(Icons.arrow_forward_ios_rounded)`.
3. **Estructura Visual de la Cápsula (`_buildPill`):**
   ```dart
   Container(
     height: 44,
     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
     decoration: BoxDecoration(
       color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
       borderRadius: BorderRadius.circular(28),
       border: Border.all(
         color: _didTriggerStationaryLongPress
             ? currentTask.color
             : currentTask.color.withValues(alpha: isDark ? 0.6 : 0.35),
         width: _didTriggerStationaryLongPress ? 2.5 : 1.5,
       ),
       boxShadow: [
         BoxShadow(
           color: currentTask.color.withValues(alpha: isDark ? 0.35 : 0.22),
           blurRadius: _didTriggerStationaryLongPress ? 14 : 8,
           spreadRadius: _didTriggerStationaryLongPress ? 2 : 0,
           offset: const Offset(0, 3),
         ),
       ],
     ),
     child: Row(
       mainAxisSize: MainAxisSize.min,
       children: [
         // 1. Icono representativo en contenedor circular distintivo
         Container(
           width: 30,
           height: 30,
           decoration: BoxDecoration(
             shape: BoxShape.circle,
             color: currentTask.color.withValues(alpha: 0.16),
           ),
           child: Center(
             child: Icon(currentTask.icon, size: 16, color: currentTask.color),
           ),
         ),
         const SizedBox(width: 8),
         // 2. Enunciado breve y claro
         Text(
           currentTask.label,
           style: TextStyle(
             fontSize: 12.5,
             fontWeight: FontWeight.w700,
             letterSpacing: -0.2,
             color: isDark ? Colors.white : const Color(0xFF1F2937),
           ),
         ),
         // 3. Píldora contador discreta
         if (totalTasks > 1) ...[
           const SizedBox(width: 6),
           Container(
             padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
             decoration: BoxDecoration(
               color: currentTask.color.withValues(alpha: 0.18),
               borderRadius: BorderRadius.circular(10),
             ),
             child: Text(
               '${taskIndex + 1}/$totalTasks',
               style: TextStyle(
                 fontSize: 9.5,
                 fontWeight: FontWeight.w800,
                 color: currentTask.color,
               ),
             ),
           ),
         ],
       ],
     ),
   )
   ```

---

### FASE 5: Pulido de los 4 Gestos Reactivos y Blindaje de Pruebas

#### Archivos Involucrados:
- `lib/core/widgets/deep_nav_return_pill.dart`
- `test/deep_nav_secondary_bubble_test.dart` (Nueva suite de tests exhaustiva)

#### Matriz de Interacciones:
1. **Gesto 1: Tap Rápido:**
   - Si `_isEdgeTucked == true`: despliega con `_isEdgeTucked = false`, emite `HapticFeedback.lightImpact()`.
   - Si `_isEdgeTucked == false`: invoca `currentTask.onTap()`, abriendo de inmediato el proceso.
2. **Gesto 2: Long-Press Estacionario (~450ms):**
   - El temporizador `_stationaryTimer` corre durante 450ms mientras la distancia del puntero sea $\le 8\text{px}$.
   - Al cumplirse: `_didTriggerStationaryLongPress = true; HapticFeedback.mediumImpact(); setState(() {});`.
   - Al soltar el dedo: si hay múltiples tareas, incrementa `SecondaryBubbleSessionState.selectedTaskIndex = (index + 1) % totalTasks` ejecutando `AnimatedSwitcher` sin navegar a ninguna otra ventana.
3. **Gesto 3: Drag Libre 2D:**
   - Si el puntero se mueve $> 8\text{px}$ antes de los 450ms, cancela el timer estacionario e inicia el arrastre 1:1 en tiempo real a 0ms de latencia.
4. **Gesto 4: Retracción en Borde Izquierdo o Derecho:**
   - Arrastrar hacia el borde izquierdo o derecho repliega la burbuja en una pestaña de 26x56 dp.
   - Si se toca o se jala hacia adentro (`details.delta.dx > 1` si izquierda, `details.delta.dx < -1` si derecha), se expande suavemente.

---

## 🛡️ 5. PROTOCOLO DEL ÁRBITRO INTERNO ADVERSARIAL

Antes de autorizar la implementación, el Árbitro Interno formula las siguientes preguntas críticas y verifica sus salvaguardas:

| Pregunta / Trampa Adversarial | Análisis de Riesgo Técnico | Salvaguarda y Blindaje en el Diseño |
| :--- | :--- | :--- |
| **1. ¿Eliminar `canPop` hará que la burbuja aparezca duplicada sobre el Home?** | Si `DeepNavReturnPill` se pintara en el Home, colisionaría visualmente con el `PersistentWorkDock`. | **Blindaje comprobado:** `DeepNavReturnPill` **no está instanciada** en `_HomeDashboardView`. En `HomeScreen`, las pestañas 1, 2 y 3 están en `IndexedStack` y permanecen `Offstage` cuando el usuario está en la pestaña 0 (Home). Por lo tanto, es imposible que aparezca en el Home. |
| **2. ¿Qué pasa si el usuario borra el carrito o limpia la cotización desde otra ventana?** | `SecondaryBubbleSessionState.selectedTaskIndex` podría quedar apuntando a un índice fuera de rango. | **Blindaje comprobado:** El método `build` re-evalúa la longitud de `activeTasks` y realiza un clamp estricto: `if (selectedIndex >= activeTasks.length) selectedIndex = activeTasks.length - 1;` si llega a 0 tareas, devuelve `SizedBox.shrink()` inmediatamente. |
| **3. ¿Cómo se garantiza que el Home dock no sufra regresiones?** | Si algún archivo aún hiciera referencia cruzada entre estados, el Home podría saltar de posición. | **Blindaje comprobado:** `PersistentWorkDock` lee y escribe únicamente en `FloatingDockSessionState`. `DeepNavReturnPill` leerá y escribirá exclusivamente en `SecondaryBubbleSessionState`. Los estados en memoria están 100% aislados. |
| **4. ¿Cómo evitar saltos al soltar la burbuja en pantallas de diferentes resoluciones?** | Dispositivos pequeños (360px) vs grandes (430px) tienen diferentes límites de borde derecho. | **Blindaje comprobado:** El anclaje al borde derecho utiliza `screenWidth - pillWidth - marginX` dinámico obtenido de `MediaQuery.of(context).size.width`, garantizando exactitud milimétrica en cualquier resolución. |
| **5. ¿Se preservan los tests existentes del proyecto?** | El proyecto cuenta con 273 tests automatizados globales que deben seguir pasando al 100%. | **Blindaje comprobado:** Los tests en `sales_history_part2_dock_export_detail_test.dart` y `sales_history_parity_kpis_and_filters_test.dart` que instancian `DeepNavReturnPill` continuarán pasando, y se agregará una suite específica para validar los 4 gestos y el desacoplamiento de estado. |

---

## 🧪 6. SUITE DE PRUEBAS AUTOMATIZADAS PREVISTA (`test/deep_nav_secondary_bubble_test.dart`)

Se construirá una suite de pruebas automatizadas dedicada que verificará:
1. **Independencia de Estado:** Modificar `SecondaryBubbleSessionState` no altera en absoluto `FloatingDockSessionState`, y viceversa.
2. **Aparición en Ruta Raíz (Simulación de Tabs):** Verificar que `DeepNavReturnPill` se renderice visiblemente con tamaño > 0 aun cuando `ModalRoute.of(context)?.canPop == false`, siempre que existan tareas activas.
3. **Rotación por Pulsación Estacionaria (450ms):** Comprobar que tras 450ms inmóvil y posterior liberación, el índice conmuta a la siguiente tarea sin disparar navegación de ruta.
4. **Arrastre y Anclaje Symmetrical:** Comprobar que al arrastrar hacia la derecha (`x > screenWidth / 2`) se ancla al borde derecho sin desbordes.
5. **Retracción Edge-Peek Bilateral:** Comprobar que al empujar al borde izquierdo se repliega con `isLeftEdge = true` y al empujar al borde derecho se repliega con `isLeftEdge = false`.
6. **Rediseño Visual:** Verificar que el icono y label conciso existan en el árbol y que el icono `Icons.arrow_forward_ios_rounded` esté ausente.

---

## 📋 7. RESUMEN DE ARCHIVOS A CREAR Y MODIFICAR

| Archivo | Acción | Propósito Principal |
| :--- | :--- | :--- |
| `lib/core/widgets/floating_dock_session_state.dart` | **Modificar** | Incorporar la clase `SecondaryBubbleSessionState` desacoplada del Home. |
| `lib/core/widgets/deep_nav_return_pill.dart` | **Modificar** | Eliminar restricción `canPop`, conectar con `SecondaryBubbleSessionState`, implementar física 1:1, anclaje bilateral simétrico, rediseño visual de cápsula y pulido de 4 gestos. |
| `test/deep_nav_secondary_bubble_test.dart` | **Crear** | Suite de pruebas unitarias y de widgets que certifique la visibilidad, gestos, física y desacoplamiento. |
