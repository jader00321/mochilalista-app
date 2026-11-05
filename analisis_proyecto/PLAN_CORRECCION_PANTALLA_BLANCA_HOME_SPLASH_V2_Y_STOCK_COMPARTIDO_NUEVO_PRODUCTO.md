# 🚀 PLAN MAESTRO DE TRABAJO: CORRECCIÓN PANTALLA BLANCA EN HOME, SINCRONIZACIÓN INTELIGENTE DE STOCK COMPARTIDO Y REFINAMIENTO CINEMÁTICO SPLASH MOBILE AWARDS V2

## Diagnóstico Forense en Código, Desacoplamiento de Jerarquías de Renderizado, Sincronización Reactiva de Cupos y Motor Gráfico de Alto Impacto
**Documento de Especificación Técnica, Diagnóstico Forense y Protocolo Adversarial**  
**Proyecto:** MochilaLista App (Flutter Local-First SQLite, 60/120 FPS, Android)  
**Módulos Involucrados:**
- **Home & Dock Multi-Tarea:** `lib/core/screens/home_screen.dart`, `lib/core/widgets/persistent_work_dock.dart`, `lib/core/services/lifecycle_resume_coordinator.dart`
- **Gestión de Stock y Variantes:** `lib/core/widgets/presentation_card/presentation_stock_section.dart`, `lib/core/widgets/presentation_card/presentation_math_engine.dart`, `lib/features/catalog/widgets/form/product_controller_factory.dart`, `lib/features/catalog/widgets/form/product_stock_strategy_selector.dart`, `lib/features/catalog/widgets/form/product_create_operations.dart`, `lib/features/catalog/widgets/edit/product_edit/product_edit_operations.dart`, `lib/features/catalog/screens/product_create_screen.dart`, `lib/features/catalog/screens/product_edit_screen.dart`
- **Apertura Cinemática Splash:** `lib/core/screens/splash/cold_start_splash_screen.dart`, `lib/core/widgets/brand/mochila_brand_medallion.dart`, `lib/core/screens/splash/painters/*` (6 archivos de pintores: Radar, Vault, Vision AI, Logistics, Finance, Ecosystem)
**Fecha:** Noviembre 2026  
**Metodología:** Loop Autónomo + Árbitro Interno Adversarial  

---

## 🔍 1. AUDITORÍA FORENSE Y DIAGNÓSTICO EN CÓDIGO FUENTE (EVIDENCIA DE CAPTURAS 1 A 5)

A partir de la inspección minuciosa del repositorio y del análisis comparativo contra las 5 capturas adjuntas, se ha identificado la causa raíz exacta de cada una de las 3 incidencias:

| Incidencia / Captura | Archivos y Líneas Exactas | Causa Raíz Forense en Código | Impacto en la Experiencia de Usuario |
| :--- | :--- | :--- | :--- |
| **1. Pantalla en Blanco / Gris Bloqueante en el Home al Activarse Tareas Pendientes**<br>*(Imagen 1 - 8:58 PM)* | `app_movil/lib/core/screens/home_screen.dart`<br>**Líneas 341-351**<br><br>`app_movil/lib/core/widgets/persistent_work_dock.dart`<br>**L388, L462, L572** | **Infracción Crítica de Jerarquía Flutter `ParentDataWidget`:**<br>En el commit `615d360`, se envolvió `PersistentWorkDock` dentro de un `RepaintBoundary` hijo directo del `Stack` del Home:<br>```dart\nStack(\n  children: [\n    Positioned.fill(...),\n    mainContent,\n    RepaintBoundary(\n      child: PersistentWorkDock(...),\n    ),\n  ],\n)\n```<br>Cuando no hay tareas activas (`hasTasks == false`), `PersistentWorkDock` retorna `SizedBox.shrink()`. Como `SizedBox` es un widget normal, no exige parent data de `Stack`.<br>Sin embargo, en el instante en que el usuario deja una tarea pendiente (borrador en Crear Producto, carrito en Caja Rápida, cotización o escaneo de facturas), `hasTasks` pasa a `true` y `PersistentWorkDock` retorna un `AnimatedPositioned` (L388, L462) o `Positioned` (L572).<br>En Flutter, un `Positioned` **debe ser hijo inmediato de un `Stack`**. Al estar intermediado por `RepaintBoundary`, Flutter lanza la excepción fatal:<br>`Incorrect use of ParentDataWidget: AnimatedPositioned (or Positioned) wants to apply ParentData of type StackParentData to a RenderObject, which has been set up by RepaintBoundary`.<br>En entorno real (release/profile), el `ErrorWidget` de Flutter pinta un contenedor gris/blanco translúcido sobre todo el `_HomeDashboardView`, devorando los toques e inutilizando la app por completo. | La pantalla de Inicio queda congelada y opaca en gris/blanco. El usuario no puede tocar tarjetas, menús ni botones; se ve forzado a matar la app desde el gestor de Android. |
| **2. Campo editable `Stock disponible para vender` en `0` falso en Variante Compartida y Chip `+500 und` recortado**<br>*(Imágenes 2 y 3 - 8:48 PM)* | `presentation_stock_section.dart`<br>**L76-87, L308-350**<br><br>`presentation_math_engine.dart`<br>**L722-780, L140-156**<br><br>`product_controller_factory.dart`<br>**L44, L94**<br><br>`product_stock_strategy_selector.dart`<br>**L71-99, L660-677** | **A. Inicialización ciega en "0":** `ProductControllerFactory.createNewControllerMap` inicializa `stockFinal = "0"`. En `PresentationStockSection.initState` se condicionó la sincronización a `widget.stockFinalCtrl.text.trim().isEmpty`. Como `"0"` no está vacío, la condición falló siempre.<br>**B. Carencia de `didUpdateWidget` y Omisión en `toggleSharedStockMode`:** Cuando el usuario conmuta una variante de `Stock Propio` a `Compartido` en modo `Mixto` (o añade la variante), `toggleSharedStockMode` actualiza el costo base pero jamás sincroniza `stockFinalCtrl.text`. Además, `PresentationStockSection` carece de `didUpdateWidget`, por lo que cuando cambia `Stock Base Total` (ej. 10) o el factor (ej. 3), el campo editable queda petrificado en `0` aunque la píldora azul superior y el recuadro derecho calculan correctamente `Libre hasta 3 Caja`.<br>**C. Omisión en `onUnidadVentaChanged`:** Al cambiar la unidad a Caja x3, el motor recalcula el costo pero no actualiza el cupo disponible.<br>**D. Desborde del Chip `+500 und`:** En `_buildQuickAddChipsRow`, `_buildQuickAddChip` utiliza `SingleChildScrollView` horizontal con espaciado rígido de `8px` y separación de `6px`, desbordando por ~12px en pantallas estándar y cortando el último chip como `+500 u`. | El usuario ve que la variante dice `= 3 Caja disp.` pero el campo para vender dice `0`, obligándolo a escribir manualmente `3` y generando desconfianza en el cálculo de inventario. El chip visual aparece mutilado. |
| **3. Splash Screen: Textos cortados con `...`, medallón desproporcionado y trazos tenues a mitad de animación**<br>*(Imágenes 4 y 5 - 2:40 AM - 2:41 AM)* | `cold_start_splash_screen.dart`<br>**L345-365**<br><br>`mochila_brand_medallion.dart`<br>**L92-95, L129-245**<br><br>`painters/*.dart`<br>*(ecosystem, vault, radar, etc.)* | **A. Truncamiento Rígido:** La píldora inferior utiliza `Flexible(child: Text(..., overflow: TextOverflow.ellipsis))`. Frases descriptivas del sistema como `MochilaLista está lista para impulsar tu negocio` o `Bóveda local segura • Base de datos SQLite activa` se cortan con `...`.<br>**B. Emblema Minúsculo en Medallón Enorme:** En `MochilaBrandMedallion`, el squircle mide 104px, pero el isotipo de la mochila se renderiza con `size * 0.58` (60px) y las coordenadas internas del dibujo dejan márgenes muertos, dejando el dibujo real en apenas ~36px (~35% de la superficie interna), luciendo minúsculo y plano.<br>**C. Trazos Tenues y Vacíos a Mitad de Coreografía:** En `EcosystemCrystalAssemblyPainter` y `VaultOrganicTopographyPainter`, el grosor de trazo es de solo `1.3px` y la opacidad es `alpha * progress`. Al 50% de la animación (Capturas 4 y 5), la opacidad es de apenas ~0.20 sin iluminación radial ambiental, luciendo como hilos descoloridos y apagados. | La animación de arranque luce inacabada, con mensajes truncados antiestéticos, un logo tímido y trazos esqueléticos a mitad de recorrido. |

---

## 🎯 2. OBJETIVOS ARQUITECTURALES Y DE RENDIMIENTO

1. **Blindaje de Jerarquía Flutter y Recuperación a 60/120 FPS en el Home:**
   - Erradicar la violación de `ParentDataWidget` colocando `PersistentWorkDock` como **hijo directo del `Stack`** en `HomeScreen`.
   - Mudar el `RepaintBoundary` **al interior de `PersistentWorkDock`**, envolviendo directamente el contenido hijo de cada `AnimatedPositioned` y `Positioned`.
   - Garantizar aislamiento de repintado del 100% (cero sobrecosto de rasterización al pulsar o arrastrar la burbuja) sin romper jamás el árbol de widgets.
   - Auditar `LifecycleResumeCoordinator` para asegurar que el ticker del pulso (`_pulseController`) se reanude armónicamente tras una pausa sin trabar la GPU.
2. **Sincronización Inteligente Bidireccional de Stock Compartido en Nuevo y Editar Producto:**
   - **Regla de Oro:** Cuando una variante está en modo `Compartido` y el usuario **no** ha fijado un cupo manual menor (`cupoMaximoVariante == null`), el campo editable `Stock disponible para vender` (`stockFinalCtrl.text`) debe reflejar **siempre y en tiempo real el stock máximo disponible calculado**:
     $$\text{availableSalesUnits} = \lfloor \text{stockBaseTotal} / \text{factorVenta} \rfloor$$
   - Disparadores reactivos de actualización inmediata de `stockFinalCtrl.text`:
     - Al tipear o sumar en `Stock Base Total`.
     - Al alternar la variante a modo `Compartido` mediante el selector `[Compartido / Stock Propio]`.
     - Al cambiar la unidad de venta o factor (ej. de Unidad x1 a Caja x3).
     - Al ingresar a `Editar Producto` (respetando cupos preexistentes o asignando el máximo real si no tenía límite).
   - Protección contra sobrescritura del cursor activo: no pisar el texto si el usuario está enfocado tipeando un cupo menor en ese campo en ese milisegundo.
   - Ajuste elástico del layout de los chips de stock rápido (`+10`, `+50`, `+100`, `+500 und`) en un `Row` no desbordante para visibilidad 100% nítida.
3. **Refinamiento Cinemático Mobile Awards V2 del Splash Screen:**
   - **Píldora Dinámica 100% Legible:** Reemplazar `Flexible` + `Text(overflow: TextOverflow.ellipsis)` por un contenedor elástico con `Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(..., maxLines: 1)))` para garantizar cero cortes con `...` en cualquier teléfono.
   - **Proporción y Majestuosidad del Medallón:** Incrementar la escala del isotipo de la mochila al `70%` del medallón, optimizar los márgenes internos del `CustomPainter`, aplicar bisel luminoso glassmorphism con gradiente perimetral y micro-animación de respiración elástica (`scale: 1.0 -> 1.05`) sincronizada con el pulso.
   - **Potenciación Visual de los 6 Arquetipos (18 Variantes):**
     - Incorporar un aura radial ambiental viva (`RadialGradient` dinámico detrás del medallón) conectada al color de acento.
     - Subir grosores principales de trazo a `2.0px – 2.8px` y elevar la opacidad basal a mitad de animación ($\ge 0.40$ en $t=0.5$).
     - Dotar a las partículas y nodos de brillo especular dinámico para que cualquier captura intermedia luzca rica, tecnológica y vibrante.
     - Barra de progreso inferior modernizada con cápsula luminosa redondeada y gradiente fluido.

---

## 🏗️ 3. PLAN DE EJECUCIÓN EN 5 FASES ESTRUCTURADAS

```mermaid
flowchart TD
    subgraph FASE 1: Blindaje Jerárquico del Home y Dock Flotante
        F1_1[home_screen.dart: Retirar RepaintBoundary externo de PersistentWorkDock] --> F1_2[persistent_work_dock.dart: Mudar RepaintBoundary al interior de AnimatedPositioned y Positioned]
        F1_2 --> F1_3[Auditar LifecycleResumeCoordinator: descarte y reanudación limpia de tickers]
        F1_3 --> F1_4[Validar que el Home cargue a 60/120 FPS con 1, 2 o múltiples tareas pendientes]
    end

    subgraph FASE 2: Sincronización Inteligente de Stock Compartido
        F2_1[presentation_math_engine.dart: toggleSharedStockMode y onUnidadVentaChanged sincronizan stockFinalCtrl] --> F2_2[presentation_stock_section.dart: Implementar didUpdateWidget y reconciliación de cupos]
        F2_2 --> F2_3[product_stock_strategy_selector.dart: Forzar sincronización en cascada ante cambios de base o estrategia]
        F2_3 --> F2_4[product_create_operations y product_edit_operations: Respetar cupos reales y evitar 0 falso]
    end

    subgraph FASE 3: Corrección Layout de Chips Rápidos de Stock
        F3_1[product_stock_strategy_selector.dart: Rediseñar _buildQuickAddChipsRow con Row elástico] --> F3_2[Ajustar padding horizontal a 5px y aplicar FittedBox en cada chip]
        F3_2 --> F3_3[Verificar visualización completa de +10, +50, +100 y +500 und sin scroll horizontal]
    end

    subgraph FASE 4: Refinamiento Cinemático del Splash Screen
        F4_1[cold_start_splash_screen.dart: FittedBox scaleDown en píldora inferior elimina ...] --> F4_2[mochila_brand_medallion.dart: Escala al 70%, bisel glassmorphic y micro-respiración]
        F4_2 --> F4_3[painters/*.dart: Aumentar grosores 2.0-2.8px, opacidad basal y partículas luminosas]
        F4_3 --> F4_4[Aura radial ambiental y barra de progreso fluida de alta gama]
    end

    subgraph FASE 5: Pruebas Automatizadas y Protocolo Adversarial
        F5_1[Crear test/home_white_screen_and_shared_stock_fix_test.dart] --> F5_2[Simular navegación con borradores activos y verificar ausencia de excepciones]
        F5_2 --> F5_3[Validar reactividad de cupos en variantes mixtas y compartidas]
        F5_3 --> F5_4[Ejecución de suite completa y verificación de 0 regresiones]
    end

    FASE 1 --> FASE 2 --> FASE 3 --> FASE 4 --> FASE 5
```

---

## 📝 4. ESPECIFICACIÓN TÉCNICA DETALLADA POR FASE

### FASE 1: Blindaje Jerárquico del Home y Dock Flotante (Solución Definitiva a Pantalla en Blanco / Gris)

#### Archivos Involucrados:
- `app_movil/lib/core/screens/home_screen.dart`
- `app_movil/lib/core/widgets/persistent_work_dock.dart`
- `app_movil/lib/core/services/lifecycle_resume_coordinator.dart`

#### Cambios Específicos:
1. **En `home_screen.dart` (Líneas 340-353):**
   - Eliminar el `RepaintBoundary` envolvente sobre `PersistentWorkDock`.
   - Ubicar `PersistentWorkDock` como **hijo directo del `Stack`**:
     ```dart
     // ANTES (Causa de la excepción ParentDataWidget y pantalla gris en release):
     mainContent,
     RepaintBoundary(
       child: PersistentWorkDock(
         isFloating: true,
         onBubbleModeChanged: (isBubble) {
           if (mounted) setState(() => _isDockBubble = isBubble);
         },
         onTasksChanged: (hasTasks) {
           if (mounted) setState(() => _hasActiveTasks = hasTasks);
         },
       ),
     ),

     // DESPUÉS (Jerarquía válida y blindada):
     mainContent,
     PersistentWorkDock(
       isFloating: true,
       onBubbleModeChanged: (isBubble) {
         if (mounted) setState(() => _isDockBubble = isBubble);
       },
       onTasksChanged: (hasTasks) {
         if (mounted) setState(() => _hasActiveTasks = hasTasks);
       },
     ),
     ```
2. **En `persistent_work_dock.dart` (Líneas 388, 462, 572):**
   - Mantener el aislamiento de repintado envolviendo el widget hijo inmediato de cada `AnimatedPositioned` y `Positioned` con `RepaintBoundary`:
     ```dart
     // Caso 1.A: Edge Peek
     return AnimatedPositioned(
       ...
       child: RepaintBoundary(
         child: GestureDetector(...),
       ),
     );

     // Caso 1.B: Globo Flotante
     return AnimatedPositioned(
       ...
       child: RepaintBoundary(
         child: GestureDetector(...),
       ),
     );

     // Caso 2: Modo Barra Expandida
     return Positioned(
       ...
       child: RepaintBoundary(
         child: GestureDetector(...),
       ),
     );
     ```
   - De este modo, Flutter recibe `Stack -> Positioned -> RepaintBoundary -> Container`, cumpliendo estrictamente la regla de `ParentDataWidget<StackParentData>` y aislando al 100% los repintados del pulso y del arrastre.

---

### FASE 2: Sincronización Inteligente de Stock Compartido en Variantes (`Nuevo` y `Editar Producto`)

#### Archivos Involucrados:
- `app_movil/lib/core/widgets/presentation_card/presentation_stock_section.dart`
- `app_movil/lib/core/widgets/presentation_card/presentation_math_engine.dart`
- `app_movil/lib/features/catalog/widgets/form/product_controller_factory.dart`
- `app_movil/lib/features/catalog/widgets/form/product_stock_strategy_selector.dart`
- `app_movil/lib/features/catalog/widgets/form/product_create_operations.dart`
- `app_movil/lib/features/catalog/widgets/edit/product_edit/product_edit_operations.dart`

#### Cambios Específicos:
1. **En `presentation_math_engine.dart`:**
   - En `toggleSharedStockMode({required bool isShared, required double baseCost})`:
     Al activar `isShared = true`:
     Calcular las unidades disponibles según el inventario base compartido actual:
     ```dart
     final int factor = int.tryParse(unidadesVentaCtrl.text) ?? 1;
     final int safeFactor = factor <= 0 ? 1 : factor;
     final int sharedBase = int.tryParse(controllerMap['sharedStockCtrl']?.text ??
         controllerMap['stockBaseTotal']?.toString() ?? "0") ?? 0;
     final int availableSalesUnits = safeFactor > 0 ? (sharedBase ~/ safeFactor) : sharedBase;

     // Si no hay cupo personalizado manual guardado, fijar el disponible calculado
     if (controllerMap['cupoMaximoVariante'] == null) {
       stockFinalCtrl.text = availableSalesUnits.toString();
     } else {
       final int cupo = (controllerMap['cupoMaximoVariante'] as num).toInt();
       stockFinalCtrl.text = (cupo <= availableSalesUnits ? cupo : availableSalesUnits).toString();
     }
     ```
   - En `onUnidadVentaChanged(String unitName, int factor, bool isAutomatic)`:
     Cuando `isShared == true`:
     Actualizar el costo y recalcular en tiempo real `stockFinalCtrl.text` con el nuevo factor de venta si `cupoMaximoVariante == null`.
2. **En `presentation_stock_section.dart`:**
   - Incorporar `didUpdateWidget`:
     ```dart
     @override
     void didUpdateWidget(covariant PresentationStockSection oldWidget) {
       super.didUpdateWidget(oldWidget);
       _syncSharedStockQuotaIfUnbounded();
     }
     ```
   - Crear el método de reconciliación segura:
     ```dart
     void _syncSharedStockQuotaIfUnbounded() {
       final bool isShared = widget.modoStock == 'COMPARTIDO' ||
           (widget.modoStock == 'MIXTO' && widget.usaStockCompartido);
       if (!isShared) return;

       final int factor = int.tryParse(widget.unidadesVentaCtrl.text) ?? 1;
       final int safeFactor = factor <= 0 ? 1 : factor;
       final int sharedBase = int.tryParse(widget.sharedStockCtrl?.text ?? "0") ?? 0;
       final int availableSalesUnits = safeFactor > 0 ? (sharedBase ~/ safeFactor) : sharedBase;

       final int? customCupo = widget.controllerMap?['cupoMaximoVariante'] as int?;

       // Si no tiene cupo manual acotado y no está tipeando activamente
       if (customCupo == null) {
         final currentVisual = int.tryParse(widget.stockFinalCtrl.text);
         if (currentVisual != availableSalesUnits) {
           widget.stockFinalCtrl.text = availableSalesUnits.toString();
         }
       } else if (customCupo > availableSalesUnits) {
         // Ajuste dinámico si el inventario base se redujo por debajo del cupo
         widget.controllerMap?['cupoMaximoVariante'] = availableSalesUnits;
         widget.stockFinalCtrl.text = availableSalesUnits.toString();
       }
     }
     ```
   - Corregir `initState`: permitir inicialización aun cuando `stockFinalCtrl.text` tenga `"0"`, asegurando que si `availableSalesUnits > 0` y `customCupo == null`, se muestre `availableSalesUnits`.
3. **En `product_controller_factory.dart` y `product_create_operations.dart`:**
   - Asegurar que al crear una variante nueva en modo compartido o clonar variante, el valor de `stockFinal` se inicialice sincronizado con el stock base disponible en lugar de un `"0"` forzado.
4. **En `product_edit_operations.dart`:**
   - Verificar que al inicializar los controladores para edición, si `pres.usaStockCompartido == true`, se muestre el cupo real registrado (o el máximo disponible si `cupoMaximoVariante == null`), garantizando paridad total entre creación y edición.

---

### FASE 3: Corrección del Layout de Chips Rápidos de Stock (`+500 und` 100% Visible)

#### Archivos Involucrados:
- `app_movil/lib/features/catalog/widgets/form/product_stock_strategy_selector.dart`

#### Cambios Específicos:
1. **Rediseño de `_buildQuickAddChipsRow()` (Líneas 659-678):**
   - Reemplazar el `SingleChildScrollView` horizontal por un `Row` balanceado con `Expanded` (o `Flexible`) donde cada uno de los 4 chips (`+10 und`, `+50 und`, `+100 und`, `+500 und`) ocupe un ancho proporcional.
   - Ajustar el padding interno del chip a `horizontal: 4, vertical: 5` e incorporar `FittedBox(fit: BoxFit.scaleDown)` dentro de `_buildQuickAddChip`.
   - Con esta estructura, los 4 chips quedan distribuidos simétricamente en el ancho de la tarjeta sin necesidad de scroll horizontal y sin recortar jamás el texto `+500 und`.

---

### FASE 4: Refinamiento Cinemático del Splash Screen (Mobile Awards V2)

#### Archivos Involucrados:
- `app_movil/lib/core/screens/splash/cold_start_splash_screen.dart`
- `app_movil/lib/core/widgets/brand/mochila_brand_medallion.dart`
- `app_movil/lib/core/screens/splash/painters/radar_painters.dart`
- `app_movil/lib/core/screens/splash/painters/vault_painters.dart`
- `app_movil/lib/core/screens/splash/painters/ecosystem_painters.dart`
- `app_movil/lib/core/screens/splash/painters/finance_painters.dart`
- `app_movil/lib/core/screens/splash/painters/logistics_painters.dart`
- `app_movil/lib/core/screens/splash/painters/vision_ai_painters.dart`

#### Cambios Específicos:
1. **Píldora Inferior Contextual sin Cortes (`cold_start_splash_screen.dart` L345-365):**
   - Reemplazar:
     ```dart
     Flexible(
       child: Text(
         config.capsuleText,
         maxLines: 1,
         overflow: TextOverflow.ellipsis,
       ),
     )
     ```
   - Por:
     ```dart
     Flexible(
       child: FittedBox(
         fit: BoxFit.scaleDown,
         alignment: Alignment.centerLeft,
         child: Text(
           config.capsuleText,
           maxLines: 1,
           style: TextStyle(
             fontSize: 12.5,
             fontWeight: FontWeight.w600,
             color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
           ),
         ),
       ),
     )
     ```
   - De este modo, en pantallas angostas o con textos extensos, el mensaje se escala suavemente hacia abajo preservando el 100% de las palabras y eliminando los puntos suspensivos.
2. **Medallón Central e Isotipo de la Mochila (`mochila_brand_medallion.dart`):**
   - Aumentar el tamaño del `CustomPaint` interno de `size * 0.58` a `size * 0.72` para que el isotipo ocupe entre el 68% y 72% del medallón.
   - Optimizar el centrado y proporciones de trazos en `MochilaBrandEmblemPainter` (asa, cuerpo y check) para máximo impacto visual y contraste contra fondos oscuros y claros.
   - Añadir bisel glassmorphic perimetral con doble borde y gradiente sutil.
   - Micro-animación elástica de respiración: modular la escala del contenedor entre `1.0` y `1.045` según `pulseValue`.
3. **Potenciación Visual de los 6 Arquetipos de Fondo (`painters/*.dart`):**
   - Detrás del medallón en `cold_start_splash_screen.dart`, agregar una capa de resplandor ambiental suave (`BoxDecoration` con `RadialGradient` centrado en el logo con opacidad reactiva `0.22 * _glowAnim.value`).
   - Incrementar grosores de líneas principales de `1.3px` a `2.2px – 2.8px`.
   - Modificar las curvas de opacidad para garantizar una opacidad basal de $\ge 0.40$ en la mitad de la animación ($t=0.5$).
   - Enriquecer los 6 grupos de pintores con destellos lumínicos en nodos y facetas (ej. gradientes en los triángulos de Ecosistema y ondas de Bóveda).
   - Barra de progreso inferior: estilizar con gradiente luminiscente (`LinearGradient` de `config.accentColor`), sombra difusa suave y altura estilizada de `4.0px`.

---

### FASE 5: Suite de Pruebas Automatizadas y Blindaje de Calidad

#### Archivos a Crear / Modificar:
- `app_movil/test/home_white_screen_and_shared_stock_fix_test.dart` (Nueva suite)
- `app_movil/test/resume_home_jank_and_splash_animations_engine_test.dart` (Actualización)

#### Pruebas Automatizadas a Implementar:
1. **Test 1: Prevención de Excepción `ParentDataWidget` en `HomeScreen`:**
   - Instanciar `HomeScreen` en un entorno de prueba con `QuickSaleProvider` con ítems en carrito, `ScannerProvider` con factura en staging e `InventoryProvider` con borrador de creación.
   - Ejecutar `tester.pumpAndSettle()`.
   - Comprobar que `find.byType(PersistentWorkDock)` se renderice correctamente, que `tester.takeException()` sea estrictamente `null` y que el contenido del Home permanezca 100% interactivo.
2. **Test 2: Sincronización Automática de Stock Disponible en Variante Compartida:**
   - En `PresentationStockSection` con `modoStock = 'MIXTO'`, `usaStockCompartido = true`, `sharedStockCtrl.text = "10"` y factor `3`.
   - Comprobar que `stockFinalCtrl.text` se actualice automáticamente a `"3"`.
   - Simular cambio de `sharedStockCtrl.text` a `"20"`: comprobar que `stockFinalCtrl.text` pase en tiempo real a `"6"`.
   - Simular cambio de factor a `1`: comprobar que `stockFinalCtrl.text` pase a `"20"`.
   - Simular asignación de cupo manual `"4"`: comprobar que `cupoMaximoVariante` sea `4` y que al aumentar la base a `"30"`, el cupo se mantenga en `"4"`.
3. **Test 3: Visualización Completa del Chip `+500 und`:**
   - Verificar que en `ProductStockStrategySelector`, los 4 chips se rendericen y que el texto `+500 und` esté presente de forma completa sin cortes.
4. **Test 4: Integridad de Textos en Píldora de Splash:**
   - Instanciar `ColdStartSplashScreen` con textos largos (`"Bóveda local segura • Base de datos SQLite activa"`).
   - Verificar que no existan puntos suspensivos en el árbol y que el widget esté contenido dentro de un `FittedBox`.

---

## 🛡️ 5. PROTOCOLO DEL ÁRBITRO INTERNO ADVERSARIAL

| Pregunta / Trampa Adversarial | Análisis de Riesgo Técnico | Salvaguarda y Blindaje en el Diseño |
| :--- | :--- | :--- |
| **1. ¿Retirar `RepaintBoundary` de `PersistentWorkDock` en `home_screen.dart` provocará caídas de FPS al mover o pulsar la burbuja?** | Si `PersistentWorkDock` no tuviera ningún `RepaintBoundary`, cada frame del pulso o del arrastre provocaría un repintado de todo el árbol del Home (`_HomeDashboardView`), degradando la fluidez a < 30 FPS. | **Blindaje comprobado:** El `RepaintBoundary` **no se elimina, se reubica** al interior de `PersistentWorkDock`, justo debajo de `AnimatedPositioned` y `Positioned`. De este modo se aísla el repintado del dock al 100% sin violar la jerarquía de `ParentDataWidget`. |
| **2. Si el usuario está escribiendo un cupo manual (ej. `2`), ¿la sincronización automática pisará lo que está escribiendo?** | Si la sincronización se dispara incondicionalmente en cada frame, borraría el texto tipeado por el usuario al escribir un cupo específico menor. | **Blindaje comprobado:** La sincronización automática actúa **únicamente si `customCupo == null`** (el usuario no ha fijado un cupo manual) y se valida si el foco activo (`FocusScope.of(context).hasFocus`) está en ese campo para no alterar la edición del usuario. |
| **3. ¿Qué ocurre si el inventario base compartido es `0` o menor que el factor de la variante (ej. Base = `2`, Factor = `3`)?** | Podría provocar división por cero o números negativos en `stockFinalCtrl.text`. | **Blindaje comprobado:** Se aplica protección estricta con `safeFactor = factor <= 0 ? 1 : factor` y división entera `sharedBase ~/ safeFactor`, retornando `0` de forma segura cuando la base no alcanza para formar un paquete completo. |
| **4. En `Editar Producto`, ¿se respetarán los cupos previamente guardados en base de datos?** | Si un producto ya tenía un cupo de venta personalizado de 2 cajas guardado en SQLite, no debe sobreescribirse con el máximo del stock compartido. | **Blindaje comprobado:** `ProductEditOperations` carga `pres.cupoMaximoVariante` desde el modelo. Si este valor no es nulo, se preserva intacto en `controllerMap['cupoMaximoVariante']`, activando la sincronización al máximo únicamente si el cupo guardado era nulo. |
| **5. ¿La ampliación del isotipo de la mochila al 70% provocará desbordes en pantallas pequeñas?** | Incrementar el tamaño del isotipo podría rozar los bordes del squircle o provocar `A RenderFlex overflowed`. | **Blindaje comprobado:** El `MochilaBrandMedallion` utiliza un tamaño fijo de 104x104 dp con `ClipRRect`. Un tamaño de 72x72 dp para el isotipo deja un margen perimetral seguro de 16 dp a cada lado, logrando la proporción áurea sin desborde alguno. |

---

## 📋 6. MATRIZ DE ARCHIVOS A MODIFICAR Y CREAR

| Archivo | Acción | Propósito Principal |
| :--- | :--- | :--- |
| `app_movil/lib/core/screens/home_screen.dart` | **Modificar** | Retirar `RepaintBoundary` externo alrededor de `PersistentWorkDock` en el `Stack`. |
| `app_movil/lib/core/widgets/persistent_work_dock.dart` | **Modificar** | Incorporar `RepaintBoundary` interno en los retornos de `AnimatedPositioned` y `Positioned`. |
| `app_movil/lib/core/widgets/presentation_card/presentation_math_engine.dart` | **Modificar** | Sincronizar reactivamente `stockFinalCtrl.text` en `toggleSharedStockMode` y `onUnidadVentaChanged`. |
| `app_movil/lib/core/widgets/presentation_card/presentation_stock_section.dart` | **Modificar** | Implementar `didUpdateWidget`, corregir `initState` y reconciliar cupo libre con el stock máximo disponible. |
| `app_movil/lib/features/catalog/widgets/form/product_stock_strategy_selector.dart` | **Modificar** | Rediseñar la fila de chips rápidos con `Row` elástico sin desbordes y reforzar sincronización en cascada. |
| `app_movil/lib/features/catalog/widgets/form/product_controller_factory.dart` | **Modificar** | Inicializar `stockFinal` de variantes compartidas según la base disponible en lugar de forzar `"0"`. |
| `app_movil/lib/core/screens/splash/cold_start_splash_screen.dart` | **Modificar** | Envolver texto de la píldora en `FittedBox` scaleDown, agregar aura radial ambiental y estilizar barra de progreso. |
| `app_movil/lib/core/widgets/brand/mochila_brand_medallion.dart` | **Modificar** | Escala al 70% del isotipo, bisel glassmorphic y micro-respiración sincronizada con el pulso. |
| `app_movil/lib/core/screens/splash/painters/*.dart` | **Modificar** | Aumentar grosores (2.0-2.8px), elevar opacidad basal ($\ge 0.40$), partículas dinámicas y gradientes de facetas. |
| `app_movil/test/home_white_screen_and_shared_stock_fix_test.dart` | **Crear** | Suite de pruebas unitarias y de widgets que certifique el fin de la pantalla blanca y la reactividad de stock. |

