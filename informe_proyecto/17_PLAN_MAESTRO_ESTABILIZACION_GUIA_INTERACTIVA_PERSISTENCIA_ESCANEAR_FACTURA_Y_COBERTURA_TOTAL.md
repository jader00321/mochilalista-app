# PLAN MAESTRO 17: ESTABILIZACIÓN RADICAL DEL MOTOR DE GUÍA TURÍSTICA INTERACTIVA, BLINDAJE DE PERSISTENCIA Y CICLO DE VIDA, REDISEÑO PROFESIONAL DE ESCANEAR FACTURA Y COBERTURA INTEGRAL DEL ECOSISTEMA - VERSIÓN 1.1

**Proyecto:** MochilaLista Mobile Application & MochilaLista Admin  
**Versión Oficial de Release Proyectada:** `v9.37.0+81` (Sucede y consolida a `v9.36.0+80`)  
**Fecha de Auditoría y Elaboración:** 22 de Noviembre de 2026  
**Entorno de Campo y Validación Real:** Samsung Galaxy A54 5G (Android 14 / One UI 6, Pantalla 1080x2340px @ 120Hz, Navegación de 3 Botones `<, ○, |||`, Cuenta Comercial Google Drive Secundaria)  
**Estado:** 100% COMPLETADO Y CERTIFICADO (Fases 1, 2, 3, 4, 5A, 5B y 6 Cerradas)  
**Alcance Técnico Estricto:** Exclusivo para `app_movil/`. **NO toca `mochilalista_admin/`** y mantiene **100% inalterada la vista visual `Escanear Lista`**.

---

## 1. RESUMEN EJECUTIVO Y OBJETIVOS ESTRATÉGICOS

Tras el despliegue de `mochilalista_v9.36_atp.apk` y su validación comercial en campo en un dispositivo físico **Samsung Galaxy A54 5G**, se confirmaron dos hitos de alto valor:
1. **Éxito del Motor de Nube:** La prueba comercial de Google Drive con una cuenta secundaria de Gmail completó la autenticación OAuth2, la generación cifrada AES-256-GCM y la rotación de copias sin anomalías.
2. **Validación del Concepto de Guía Turística:** Los comerciantes reconocieron el valor pedagógico del sistema de inducción (*Coach Marks / Spotlight*), pero el uso real evidenció fallos de coordinación, layout geométrico y persistencia que entorpecen la navegación fluida.

Mediante 11 capturas de pantalla forenses provistas por el usuario, se diagnosticaron 6 defectos críticos en el motor visual, anomalías en la máquina de estados de persistencia, anclajes erróneos en pantallas existentes, desaprovechamiento espacial en la pantalla `Escanear Factura` y la oportunidad de expandir las guías al resto de pantallas operativas de la aplicación.

Este Plan Maestro articula la solución definitiva organizada en **5 Pilares Obligatorios** y estructurada en **6 Fases Secuenciales de Implementación**:

* **Pilar 1 (Reparación Radical del Motor de Guía Turística):** Implementación de un Mutex global hermético en `InteractiveTourService`, guardia de visibilidad por pestaña en `HomeScreen` (`IndexedStack`), corrección geométrica del bloque tarjeta-flecha en `placement == above`, restricción de altura máxima del spotlight en contenedores gigantes (~55% viewport), detección preventiva de widgets `0x0` o no visibles (eliminando el círculo vacío `○`), reemplazo de listas perezosas en `BackupScreen` por auto-scroll continuo y protocolo estandarizado de apertura/cierre animado de acordeones (`onBeforeStep` / `onAfterStep`).
* **Pilar 2 (Ciclo de Vida y Persistencia Blindada):** Máquina de estados determinista en `InteractiveTourService` respaldada en `SharedPreferences` y auditando `StartupFlowCoordinator` para confirmar que ningún flujo de arranque limpie claves `tour_*`, junto con soporte en metadata de backup/restore sin alterar el esquema SQLite `v36`. Regla de activación única para instalaciones limpias/usuarios nuevos; persistencia inviolable tras reinicios del sistema operativo; propagación sincrónica e inmediata de `"Omitir todas las guías automáticas"`; y reactivación reactiva de `"Reiniciar guías de aprendizaje"` con lanzamiento inmediato en `ProfileScreen` y sincronización mediante época reactiva (`tourResetEpoch`) para pantallas en backstack como `HomeScreen`.
* **Pilar 3 (Corrección Forense de Anclajes en 10 Pantallas Actuales):** Reajuste de claves y textos en `HomeScreen` (corrección de spotlight `○`, foco en cabecera de accesos rápidos, alineación en actividad y actualización a las 4 pestañas reales), `ProductCreateScreen` (apertura automática de `Detalles Globales`, encuadre de tarjeta de variante en paso 4 además del título sin truncar `maxLines: 2` y botón Guardar anclado), `InventoryScreen` (resolución de excepción `RenderSliver` en `searchFiltersKey` y cambio automático de subpestaña a Productos), `BackupScreen` (anclaje compacto, preservación de `wantKeepAlive == true` y compatibilidad con `google_drive_reactive_provider_and_sheet_test.dart` con flujo ininterrumpido 1 a 4), `LicenseStatusAndActivationScreen` (anclaje a cabecera de planes sin desborde perimetral) y `ProfileScreen` (`SafeArea` con padding inferior para botones Android).
* **Pilar 4 (Rediseño Visual Profesional de `Escanear Factura`):** Sin alterar la vista `Escanear Lista`, rediseño vertical de `ScanMode.invoice` en `ScanScreen`: cabecera con `InfoTooltipButton` y acceso al Historial de Facturas, tarjeta Hero con badge en vivo de escaneos IA disponibles, tarjetas de acción Cámara/Galería con subtítulos informativos y feedback táctil, y bloque educativo inferior ("¿Qué procesa la IA automáticamente?" y "Consejos de captura") con micro-tarjetas vectoriales libres de emojis crudos (con `Icons.inventory_2_outlined`, `Icons.payments_outlined`, `Icons.sync_rounded`) y 0px de overflow.
* **Pilar 5 (Ampliación del Sistema de Guía al Resto de Pantallas Clave - Fases 5A y 5B):** Catálogo de expansión dividido en dos subfases: Fase 5A (`CatalogScreen` con carrusel de ofertas, `ScanScreen` para Escanear Factura y Escanear Lista sin alterar el diseño de lista, y `SalesCheckoutScreen`) y Fase 5B (`ClientDetailScreen`, `LoyaltyCenterScreen`, `AnalyticsDashboardScreen`, `BundleBuilderScreen` y `PrinterConfigScreen`, excluyendo explícitamente `lock_screen.dart` para no interferir con la seguridad del PIN), cada una con sus pasos pedagógicos y apertura/cierre de acordeones dinámicos.

---

## 2. AUDITORÍA FORENSE Y DIAGNÓSTICO DE CAUSA RAÍZ LÍNEA POR LÍNEA

A continuación se detalla la evidencia técnica exacta extraída del análisis del código fuente real de `app_movil/` y su correlación con las capturas de campo en el Samsung Galaxy A54 5G.

```mermaid
flowchart TD
    subgraph DEFECTOS_DETECTADOS["Defectos Forenses en Código Real"]
        D1["Choque Simultáneo: IndexedStack inicializa tabs a la vez + Mutex prematuro"]
        D2["Flecha Desprendida: CoachCardLayoutCalculator usa maxCardHeight en cardTop"]
        D3["Círculo Vacío ○: SizedBox.shrink() de 0x0 medido como RenderBox válido"]
        D4["Cierre Prematuro en Respaldos: ListView perezoso tiene targetContext == null"]
        D5["Spotlight Gigante: pricingCatalogKey abraza widget de 1200px"]
        D6["Error RenderSliver: KeyedSubtree en SliverPersistentHeader lanza TypeError en localToGlobal"]
        D7["Reaparición en Reinicio: markScreenSeen no se llama al omitir todas ni en cierres anticipados"]
    end

    subgraph SOLUCIONES_ARQUITECTURALES["Soluciones Blindadas en Plan 17"]
        S1["Mutex Global continuo + Guardia de Visibilidad en HomeScreen por _currentIndex"]
        S2["Bloque Unificado Tarjeta + Flecha soldada con Positioned(bottom: ...)"]
        S3["Validación estricta de RenderBox con size.width >= 12 && size.height >= 12"]
        S4["Migración de BackupScreen a SingleChildScrollView + Column (árbol 100% montado)"]
        S5["Anclaje a encabezado/primer item + clamp visual a <= 55% viewport"]
        S6["Anclaje de GlobalKey al contenedor RenderBox interno de SliverStickyHeaderDelegate"]
        S7["Persistencia sincrónica en prefs + auditoría de arranque + ValueNotifier tourResetEpoch"]
    end

    D1 --> S1
    D2 --> S2
    D3 --> S3
    D4 --> S4
    D5 --> S5
    D6 --> S6
    D7 --> S7
```

---

### 2.1 PILAR 1: Defectos en el Motor de Guía Turística (`InteractiveTourOverlay`, `CoachCardWidget` y Coordinador Global)

#### 1. Choque simultáneo de tours en `HomeScreen` (Evidenciado en captura `media_1795361344346_02b0e689.jpg`)
* **Ubicación en código:**
  * `app_movil/lib/core/screens/home_screen.dart` (líneas 58-66, 127-160 y 167-170).
  * `app_movil/lib/features/catalog/screens/inventory_screen.dart` (líneas 84-93).
  * `app_movil/lib/features/smart_quotation/screens/crm/client_tracking_screen.dart` (líneas 37-46).
  * `app_movil/lib/core/services/tour/interactive_tour_service.dart` (líneas 16-20 y 119-134).
* **Diagnóstico línea por línea:**
  1. En `home_screen.dart`, `HomeScreen` contiene un `IndexedStack` que monta simultáneamente 4 vistas: `_HomeDashboardView`, `InventoryScreen`, `CatalogScreen` y `ClientTrackingScreen`.
  2. En `HomeScreen.initState` (línea 58), se programa un callback que espera a `StartupFlowCoordinator.coordinateStartup(context)` antes de evaluar `maybeStartAutomaticTour`. Esta coordinación es asincrónica y toma varios frames.
  3. Al mismo tiempo, en `InventoryScreen.initState` (línea 89) y en `ClientTrackingScreen.initState` (línea 42), ambas pantallas ejecutan inmediatamente en su propio post-frame `maybeStartAutomaticTour`.
  4. En `interactive_tour_service.dart` (líneas 128-133), el control de concurrencia está implementado de forma errónea:
     ```dart
     _isTourCurrentlyActive = true;
     try {
       await InteractiveTourOverlay.showWelcomeModal(context, config);
     } finally {
       _isTourCurrentlyActive = false; // ❌ ERROR CRÍTICO: Libera el mutex al cerrar el modal, antes de iniciar el tour!
     }
     ```
  5. Cuando `ClientTrackingScreen` abre su modal y el usuario toca "Guíame", el modal se cierra y el bloque `finally` establece inmediatamente `_isTourCurrentlyActive = false`. En el siguiente milisegundo, la cola de eventos procesa el post-frame de `InventoryScreen`, encontrando el flag en `false`. Como resultado, se monta el diálogo de bienvenida "Bienvenido a Inventario y Catálogo" **directamente encima** del tour ya activo "Directorio y Gestión de Abonos (3 / 5)", dejando al usuario en un estado visual caótico y bloqueando el tour de `Inicio` que nunca llega a mostrarse.

#### 2. Bug geométrico de flecha desprendida y tarjeta pegada arriba (`placement == above`) (Evidenciado en capturas `media_1795361362727_58976758.jpg`, `media_1795361384552_62d54f5c.jpg` y `media_1795361416717_d5116253.jpg`)
* **Ubicación en código:**
  * `app_movil/lib/core/widgets/tour/coach_card_widget.dart` (líneas 88-97 y 153-176).
* **Diagnóstico línea por línea:**
  1. En `CoachCardLayoutCalculator.compute`:
     ```dart
     case CoachCardPlacement.above:
       maxCardHeight = math.max(120.0, spaceAbove - (showArrow ? arrowHeight : 6.0) - 6.0);
       cardTop = math.max(safeTop, targetRect.top - (showArrow ? arrowHeight : 6.0) - 4.0 - maxCardHeight);
     ```
  2. Si el objetivo está en la zona inferior de la pantalla (e.g. `targetRect.top = 700`, `safeTop = 50`), `spaceAbove` vale `650`.
  3. Por lo tanto, `maxCardHeight` se calcula en `650 - 10 - 6 = 634`.
  4. En consecuencia, `cardTop` se evalúa en `700 - 10 - 4 - 634 = 52` (clavando la tarjeta en el borde superior).
  5. En `CoachCardWidget.build`:
     * El cuerpo de la tarjeta está dentro de `ConstrainedBox(constraints: BoxConstraints(maxHeight: layout.maxCardHeight))` envolviendo una `Column(mainAxisSize: MainAxisSize.min)`. Dado que el contenido real de la tarjeta mide típicamente ~180-220dp, la tarjeta se renderiza entre `top: 52` y `bottom: 252`.
     * Sin embargo, la flecha se posiciona independientemente en:
       `top: layout.cardTop + layout.maxCardHeight - 2.0` = `52 + 634 - 2 = 684`.
  6. **Causa raíz indiscutible:** La flecha se dibuja en `y = 684` (cerca del objetivo en `y = 700`), mientras que la tarjeta termina en `y = 252`. Esto produce una separación abismal de más de **430 píxeles vacíos**, haciendo que la tarjeta parezca pegada al techo de la pantalla y la flecha quede flotando solitaria en el medio del dispositivo.

#### 3. Spotlight sobre contenedores gigantes y títulos truncados (Evidenciado en capturas `media_1795361433309_cb7f82f9.jpg`, `media_1795361456235_1e6822ef.jpg` y `media_1795361353513_427932d1.jpg`)
* **Ubicación en código:**
  * `app_movil/lib/core/widgets/tour/coach_card_widget.dart` (líneas 215-217).
  * `app_movil/lib/features/auth/screens/license/license_status_and_activation_screen.dart` (línea 381).
  * `app_movil/lib/features/profile/screens/backup_screen.dart` (línea 645).
  * `app_movil/lib/core/screens/home_screen.dart` (línea 618).
* **Diagnóstico línea por línea:**
  1. En `CoachCardWidget` (línea 216), el título de la tarjeta está forzado con `maxLines: 1` y `overflow: TextOverflow.ellipsis`. Textos descriptivos naturales como `"Respaldo Seguro en Google Drive"` o `"Presentaciones y Opciones Avanzadas"` se cortan antiestéticamente en `"Respaldo Seguro en Google D..."` y `"Presentaciones y Opciones A..."`.
  2. En `LicenseStatusAndActivationScreen`, la clave `_tourKeys.pricingCatalogKey` envuelve el widget `_buildPricingAndPaymentCatalog(fingerprint, isDark)`. Este contenedor aloja toda la lista de suscripciones, métodos de pago y notas legales, superando los **1,200 píxeles de alto**.
  3. En `BackupScreen`, la clave `_tourKeys.cloudBackupKey` envuelve el `GoogleDriveBackupSheet` completo, que mide más de 600 píxeles de alto.
  4. Cuando `SpotlightPainter` dibuja el recorte sobre estos rectángulos colosales, el marco iluminado sobrepasa los límites del viewport, pintando bordes que recorren el perímetro de toda la pantalla y forzando a la tarjeta a colocarse encima del propio contenido que intenta explicar.

#### 4. Detección de widgets invisibles / `0x0` o fuera de vista (Evidenciado en capturas `media_1795361353513_427932d1.jpg` y `media_1795361456235_1e6822ef.jpg`)
* **Ubicación en código:**
  * `app_movil/lib/core/screens/home_screen.dart` (líneas 280-282 y 457-590).
  * `app_movil/lib/core/widgets/tour/interactive_tour_overlay.dart` (líneas 230-244 y 258-285).
  * `app_movil/lib/features/profile/screens/backup_screen.dart` (líneas 625-820).
* **Diagnóstico línea por línea:**
  1. **En `HomeScreen` (Paso 3 "Licencia y Saldo IA"):**
     * `widget.tourKeys.licenseAlertKey` envuelve a `_buildLicenseBanner(context, isDark)`.
     * Cuando el usuario tiene una licencia válida y no está próximo a vencer ni en soft lock, `_buildLicenseBanner` retorna `const SizedBox.shrink()` (línea 589).
     * En `_focusCurrentStep()`, `targetContext` existe y `renderBox.hasSize` es verdadero con tamaño `Size(0, 0)`.
     * `interactive_tour_overlay.dart` no valida si el tamaño es despreciable. Calcula el padding sobre un punto `0x0`, resultando en un círculo diminuto `○` pegado al margen izquierdo (captura `media_1795361353513_427932d1.jpg`).
  2. **En `BackupScreen` (Cierre prematuro al pulsar "Siguiente" en 1/4):**
     * La pantalla utiliza un `ListView(children: [...])` (línea 625).
     * En Flutter, los elementos de un `ListView` que caen fuera del viewport no son montados en el árbol de renderizado hasta que entran en la ventana visible.
     * Dado que el paso 1 (`GoogleDriveBackupSheet`) ocupa casi toda la pantalla, las secciones correspondientes al paso 2 (`localAutoBackupKey`), paso 3 (`localExportKey`) y paso 4 (`localImportKey`) se encuentran fuera de pantalla y sus `GlobalKey.currentContext` retornan `null`.
     * En `_focusCurrentStep()`:
       ```dart
       if (targetContext == null || !targetContext.mounted) {
         if (_currentIndex < widget.config.steps.length - 1) {
           _currentIndex++;
           _focusCurrentStep(); // ❌ Itera en cadena saltando los pasos 2 y 3 porque no están montados!
           return;
         } else {
           widget.onClose(); // ❌ Al llegar al paso 4 también null, cierra el tour de inmediato!
           return;
         }
       }
       ```
     * Como consecuencia, al presionar "Siguiente" en el paso 1/4, el bucle descarta en cascada los pasos 2 y 3, llega al paso 4 y cierra el tour instantáneamente. El usuario nunca llega a ver los pasos 2, 3 ni 4.

#### 5. Despliegue y contracción automática de secciones plegables (`onBeforeStep` / `onAfterStep`) (Evidenciado en captura `media_1795361384552_62d54f5c.jpg`)
* **Ubicación en código:**
  * `app_movil/lib/features/catalog/screens/product_create_screen.dart` (línea 671).
  * `app_movil/lib/core/widgets/tour/configs/product_create_tour.dart` (líneas 56-65 y 76-87).
* **Diagnóstico línea por línea:**
  1. En `ProductCreateScreen`, el paso 2 de la guía ("Código de Barras Global") tiene como objetivo `_tourKeys.barcodeKey`.
  2. Esta clave está asignada a `ProductOptionalInfo`, el cual es un acordeón colapsable titulado `"Detalles Globales (Opcional)"`. Por defecto se encuentra plegado (`isExpanded = false`).
  3. En `product_create_tour.dart`, los hooks `onExpandSection` y `onCollapseSection` fueron configurados por error en el paso 4 (`step_variants_advanced`), dejando el paso 2 sin hook de despliegue.
  4. Por consiguiente, el tour ilumina el encabezado colapsado del acordeón en lugar del campo real de código de barras y botón de escaneo con cámara, desorientando al usuario.

---

### 2.2 PILAR 2: Diagnóstico de Persistencia, Ciclo de Vida y Reseteo de Guías

#### 1. Reaparición de guías al cerrar por completo la app y volver a abrirla
* **Ubicación en código:**
  * `app_movil/lib/core/services/tour/interactive_tour_service.dart` (líneas 54-60 y 103-116).
  * `app_movil/lib/core/widgets/tour/interactive_tour_overlay.dart` (líneas 75-80, 104-107, 120-124 y 161-166).
* **Diagnóstico línea por línea:**
  1. En `InteractiveTourOverlay`, `markScreenSeen(config.screenId)` solo es invocado en dos momentos:
     * Cuando el usuario pulsa explícitamente el botón secundario "Omitir" dentro del modal de bienvenida (línea 106).
     * Cuando el usuario completa el recorrido completo y se llama a `onClose` en el último paso (línea 163).
  2. Si el usuario pulsa "Guíame" e interrumpe el tour, o si abandona la app, o si ocurre un choque de diálogos como en el Pilar 1, la clave `'tour_screen_seen_$screenId'` **nunca se escribe en `SharedPreferences`**.
  3. Al volver a abrir la app desde cero, `shouldAutoShowTour` lee `prefs.getBool('tour_screen_seen_$screenId') ?? false`, encontrando `false`, disparando nuevamente las guías que el comerciante ya había intentado omitir o recorrer.
  4. Además, se requiere auditar `StartupFlowCoordinator` para asegurar que ningún paso de limpieza de preferencias en arranque limpie estas banderas.

#### 2. `"Omitir todas las guías automáticas"` no desactiva las guías en otras pantallas
* **Ubicación en código:**
  * `app_movil/lib/core/widgets/tour/interactive_tour_overlay.dart` (líneas 120-124).
  * `app_movil/lib/core/services/tour/interactive_tour_service.dart` (líneas 63-68).
* **Diagnóstico línea por línea:**
  1. En `interactive_tour_overlay.dart` (líneas 120-124):
     ```dart
     TextButton(
       onPressed: () {
         Navigator.of(dialogCtx).pop();
         InteractiveTourService.dismissAllAutomaticTours(); // ❌ Llamada asincrónica sin await!
       },
     ```
  2. `dismissAllAutomaticTours()` es una función `Future<void>`, pero se ejecuta de forma flotante (*unawaited*).
  3. No se invoca `markScreenSeen(config.screenId)` para la pantalla actual.
  4. Los widgets hermanos montados en el `IndexedStack` (e.g. `InventoryScreen`, `ClientTrackingScreen`) ya habían evaluado concurrentemente `shouldAutoShowTour` en sus propios post-frame callbacks antes de que `SharedPreferences.setBool` alcanzara a escribir en disco en Android.
  5. Por lo tanto, al descartar el diálogo en `HomeScreen`, los modales de las otras pantallas continúan vivos en cola y se abren sucesivamente.

#### 3. `"Reiniciar guías de aprendizaje"` en `Perfil` no reactiva correctamente ni muestra la guía actual
* **Ubicación en código:**
  * `app_movil/lib/features/profile/screens/profile_screen.dart` (líneas 1025-1035).
  * `app_movil/lib/core/services/tour/interactive_tour_service.dart` (líneas 103-116).
* **Diagnóstico línea por línea:**
  1. Al confirmar `"Reiniciar"` en `ProfileScreen`, se invoca `InteractiveTourService.resetAllTours()`, se actualiza el estado local `_automaticToursEnabled = true` y se muestra un SnackBar informativo.
  2. **Defecto 1:** La pantalla no lanza inmediatamente el tour de bienvenida de `ProfileScreen` en la que el comerciante se encuentra situado en ese instante.
  3. **Defecto 2:** No existe un mecanismo de notificación reactivo (`ValueNotifier<int> tourResetEpoch` o similar). Como las pantallas principales como `HomeScreen` ya se encontraban montadas previamente en el stack de navegación, su `initState` no vuelve a ejecutarse. Al regresar con el botón atrás a `HomeScreen`, la pantalla ignora por completo que las guías fueron reiniciadas y no muestra la guía interactiva.

---

### 2.3 PILAR 3: Diagnóstico en Anclajes y Pasos de Pantallas Existentes

#### 1. `InventoryScreen` (Paso 3 "Buscador y Filtros Avanzados" ilumina icono erróneo) (Evidenciado en captura `media_1795361404027_40175e53.jpg`)
* **Ubicación en código:**
  * `app_movil/lib/features/catalog/screens/inventory_screen.dart` (línea 182).
  * `app_movil/lib/features/catalog/screens/tabs/products_tab.dart` (líneas 697-714).
  * `app_movil/lib/features/catalog/screens/tabs/widgets/inventory_filter_header.dart` (líneas 299-310).
  * `app_movil/lib/core/widgets/tour/interactive_tour_overlay.dart` (líneas 260-285).
* **Diagnóstico línea por línea:**
  1. En `inventory_tour.dart`, el paso 2 es `step_invoice_ai` (apuntando a `invoiceAiKey`, el icono superior de Facturas con IA).
  2. El paso 3 es `step_search_filters` (apuntando a `searchFiltersKey`).
  3. En `products_tab.dart` (línea 697):
     ```dart
     KeyedSubtree(
       key: widget.tourKeys?.searchFiltersKey ?? const ValueKey('tour_search_filters_fallback'),
       child: InventoryFilterHeader(...),
     )
     ```
  4. `InventoryFilterHeader.build` retorna directamente un `SliverPersistentHeader` con `SliverStickyHeaderDelegate`.
  5. En `interactive_tour_overlay.dart` (línea 260):
     ```dart
     final renderBox = targetContext.findRenderObject() as RenderBox?;
     ```
  6. **Causa raíz técnica de alta precisión:** El `RenderObject` de un `SliverPersistentHeader` es un `RenderSliverPinnedPersistentHeader`, el cual **no hereda de `RenderBox`**. El cast `as RenderBox?` arroja una excepción en tiempo de ejecución:
     `TypeError: RenderSliverPinnedPersistentHeader is not a subtype of RenderBox in type cast`.
  7. El bloque `try-catch` en `_focusCurrentStep` captura silenciosamente esta excepción sin registrarla. Al fallar, **`_targetRect` no se actualiza** y conserva las coordenadas del paso anterior (`invoiceAiKey`).
  8. Por esta razón, el paso 3 ("Buscador y Filtros Avanzados") continuaba iluminando el icono de Factura con IA en la esquina superior derecha en lugar de la barra de búsqueda y filtros.

#### 2. `InventoryScreen` (Paso 4 "Crear Producto Nuevo" en subpestañas alternativas) (Evidenciado en captura `media_1795361416717_d5116253.jpg`)
* **Ubicación en código:**
  * `app_movil/lib/features/catalog/screens/inventory_screen.dart` (líneas 333-346).
  * `app_movil/lib/features/catalog/screens/tabs/products_tab.dart` (líneas 935-945).
* **Diagnóstico línea por línea:**
  1. El FloatingActionButton de creación está ubicado exclusivamente dentro de `ProductsTab` (pestaña 0).
  2. Si el usuario inicia la guía desde la pestaña "OFERTAS / BUNDLES", `ProductsTab` se encuentra oculta dentro del `TabBarView`.
  3. En consecuencia, el paso 4 no encuentra el botón de creación montado e ilumina un recuadro vacío en la base de la pantalla. Se requiere que el paso 4 ejecute un `onBeforeStep` que conmute `_tabController.animateTo(0)` antes de enfocar el botón.

#### 3. `HomeScreen` (Paso 5 y 6: Textos y Coherencia de Navegación) (Evidenciado en capturas `media_1795361362727_58976758.jpg` y `media_1795361377234_8f7fb9cc.jpg`)
* **Ubicación en código:**
  * `app_movil/lib/core/widgets/tour/configs/home_screen_tour.dart` (líneas 99-107).
  * `app_movil/lib/core/screens/home_screen.dart` (líneas 150-161).
* **Diagnóstico línea por línea:**
  1. En `home_screen_tour.dart` (línea 104), el paso 6 describe la barra de navegación como:
     `"Muévete con total fluidez entre Inicio, Catálogo, Cotizador Inteligente, Ventas y la Configuración de tu Perfil."`
  2. Sin embargo, la barra de navegación real de `HomeScreen` (líneas 155-160) posee exactamente 4 destinos:
     `Inicio`, `Inventario`, `Catálogo` y `Clientes`.
  3. El texto no refleja la arquitectura real de navegación de la app comercial y confunde al usuario.

#### 4. `ProfileScreen` (Colisión visual inferior de Zona de Peligro)
* **Ubicación en código:**
  * `app_movil/lib/features/profile/screens/profile_screen.dart` (líneas 120-135 y 440-449).
* **Diagnóstico línea por línea:**
  1. `ProfileScreen` no implementa un `SafeArea(bottom: true)` ni calcula el padding inferior seguro de ventana (`MediaQuery.viewPaddingOf(context).bottom`).
  2. En el Samsung Galaxy A54 5G configurado con barra de 3 botones clásica de Android (`<, ○, |||`), la tarjeta roja de "Zona de Peligro" y el botón de eliminación de perfil quedan asomando justo al ras de los botones del sistema, dificultando la pulsación cómoda y violando las guías de diseño ergonómico móvil.

---

### 2.4 PILAR 4: Diagnóstico de la Pantalla `Escanear Factura` (Evidenciado en captura `media_1795361472687_2bd73178.jpg`)

* **Ubicación en código:**
  * `app_movil/lib/features/scanner/screens/scan_screen.dart` (líneas 333-350, 510-568 y 628-655).
* **Diagnóstico de espacio y jerarquía:**
  1. `ScanScreen` atiende dos modos mediante el enum `ScanMode`: `ScanMode.quotation` ("Escanear Lista") y `ScanMode.invoice` ("Escanear Factura").
  2. La vista de `Escanear Lista` (`isQuotation == true`) está plenamente consolidada y aprobada por el usuario (muestra chips temáticos de Compras, Mayorista y Lista Escolar).
  3. Por el contrario, en `Escanear Factura` (`isQuotation == false`):
     * La pantalla muestra un círculo verde esmeralda con el icono de recibo, el texto "Procesa tu Compra" y los dos botones cuadrados "Cámara" y "Galería".
     * **Problema evidenciado:** Toda la interacción queda apelmazada en el 40% superior del viewport, dejando los **600 píxeles inferiores totalmente vacíos y fríos**.
     * Carece de `InfoTooltipButton` en la AppBar para activar su guía interactiva paso a paso.
     * No informa al comerciante cuántos escaneos IA le quedan en su saldo antes de tomar la foto.
     * Los botones no ofrecen subtítulos explicativos ni micro-tips que guíen al usuario para obtener una fotografía con iluminación y nitidez óptimas que faciliten el procesamiento de la IA.

---

## 3. ARQUITECTURA TÉCNICA DETALLADA POR PILARES

```mermaid
flowchart TD
    subgraph P1["Pilar 1: Motor de Guía Turística"]
        Mutex[Mutex Global en InteractiveTourService] --> LockLifecycle[Lock activo desde WelcomeModal hasta onClose]
        TabGuard[Guardia de Visibilidad en HomeScreen] --> CentralTrigger[Disparo automático según _currentIndex activo]
        CardLayout[CoachCardWidget Unificado] --> WeldedArrow[Flecha soldada a la tarjeta con Positioned bottom]
        SpotlightEngine[SpotlightPainter Inteligente] --> HeightClamp[Clamp de Spotlight a max 55% viewport]
        SafeRender[Safe Measure Engine] --> MinSizeCheck[Validación width/height >= 12dp]
        AccordionEngine[Dynamic Accordions] --> AnimateHooks[onBeforeStep expande / onAfterStep contrae]
    end

    subgraph P2["Pilar 2: Ciclo de Vida & Persistencia"]
        PrefsAudit[Auditoría SharedPreferences + StartupFlow] --> SingleRun[Activación exclusiva para Negocio Nuevo]
        DismissAll[Omitir Todas Sincrónico] --> ImmediateFlag[tour_automatic_enabled = false inmediato]
        ResetEngine[Reiniciar Guías] --> EpochTrigger[ValueNotifier tourResetEpoch + Disparo en Perfil]
    end

    subgraph P3["Pilar 3: Corrección en 10 Pantallas"]
        FixHome[HomeScreen: Spotlight Saldo + Accesos + 4 Pestañas]
        FixProd[ProductCreateScreen: Auto-expand Código de Barras + Tarjeta Variante + maxLines 2]
        FixInv[InventoryScreen: RenderBox en Filtros + Auto-switch Tab Productos]
        FixBack[BackupScreen: SingleChildScrollView + wantKeepAlive + Flujo 1 a 4]
        FixLic[LicenseScreen: Anclaje a Cabecera Planes sin overflow]
        FixProf[ProfileScreen: SafeArea bottom + 24dp en Zona de Peligro]
    end

    subgraph P4["Pilar 4: Rediseño Escanear Factura"]
        InvoiceHeader[Cabecera con InfoTooltip + Historial IA]
        HeroCard[Hero Card con Badge Saldo IA en Vivo]
        ActionCards[Tarjetas Cámara & Galería con Subtítulos y Háptica]
        TipsSection[Bloque '¿Qué procesa la IA?' Icons Material + Tips de Enfoque]
    end

    subgraph P5["Pilar 5: Cobertura Integral de Pantallas (Fases 5A y 5B)"]
        Fase5A[Fase 5A: Catálogo + Scan Factura/Lista + SalesCheckout]
        Fase5B[Fase 5B: Detalle Cliente + Fidelización + Analíticas + Combos + Impresora]
    end

    P1 --> P3
    P2 --> P3
    P3 --> P4
    P4 --> P5
```

---

### 3.1 PILAR 1: Reparación Radical del Motor de Guía Turística

1. **Mutex Global Único de Ciclo Completo en `InteractiveTourService`:**
   * Se elimina la liberación prematura de `_isTourCurrentlyActive` en el `finally` de `showWelcomeModal`.
   * El candado global cubre un ciclo de vida atómico:
     * Adquisición al validar y abrir `showWelcomeModal`.
     * Si el usuario presiona "Guíame", el mutex **permanece retenido**.
     * Si el usuario presiona "Omitir" u "Omitir todas", el modal se cierra y el mutex se libera.
     * Si se inicia `startTour`, el mutex solo se libera en el callback `onCompleted` / `onClose`.
     * Cualquier invocación simultánea proveniente de otra pantalla mientras el mutex esté activo es rechazada de inmediato.
   * Se incorpora helper `static void resetRuntimeLockForTesting()` para garantizar aislamiento entre pruebas de widgets.

2. **Guardia de Visibilidad por Pestaña Activa en `HomeScreen`:**
   * En `HomeScreen`, se eliminan los disparos automáticos desacoplados dentro de `InventoryScreen` y `ClientTrackingScreen`.
   * `HomeScreen` centraliza el despacho automático mediante un orquestador dependiente de `_currentIndex`:
     * `_currentIndex == 0`: evalúa y lanza `HomeScreenTour`.
     * `_currentIndex == 1`: evalúa y lanza `InventoryTour`.
     * `_currentIndex == 2`: evalúa y lanza `CatalogTour`.
     * `_currentIndex == 3`: evalúa y lanza `ClientTrackingTour`.
   * En `onDestinationSelected`, al cambiar de pestaña, se invoca `InteractiveTourService.maybeStartAutomaticTour` para la pestaña recién visible, garantizando que ninguna pestaña oculta en `IndexedStack` dispare modales.

3. **Arquitectura de Bloque Unificado en `CoachCardWidget` (`placement == above` y `below`):**
   * Se erradica el cálculo disociado entre `cardTop` y la posición de la flecha.
   * Cuando `placement == CoachCardPlacement.above`:
     * La tarjeta y su flecha se agrupan en una única estructura vertical dentro de un `Positioned`:
       ```dart
       Positioned(
         left: layout.cardLeft,
         width: layout.cardWidth,
         bottom: viewportSize.height - targetRect.top + 6.0,
         child: ConstrainedBox(
           constraints: BoxConstraints(maxHeight: layout.maxCardHeight),
           child: Column(
             mainAxisSize: MainAxisSize.min,
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
               Flexible(child: cardBody), // Tarjeta responsiva
               ArrowDownPainter(...), // Flecha apuntando abajo, físicamente soldada al fondo de la tarjeta
             ],
           ),
         ),
       )
       ```
     * De este modo, sin importar si la tarjeta mide 150dp o 280dp de alto, su base siempre estará unida a la flecha y ambas descansarán exactamente a 6dp por encima de `targetRect.top`. Se elimina para siempre la separación física entre tarjeta y flecha.
   * Cuando `placement == CoachCardPlacement.below`:
     * Mismo principio anclado por arriba (`top: targetRect.bottom + 6.0`), colocando la flecha soldada justo encima de `Flexible(child: cardBody)`.

4. **Acotamiento Inteligente de Spotlight en Contenedores Gigantes:**
   * En `InteractiveTourOverlay`, si `targetRect.height > viewportSize.height * 0.55`:
     * El motor acota visualmente el spotlight visible a un máximo del 45% del viewport desde la parte superior del elemento (`height = math.min(rect.height, usableHeight * 0.45)`, clamped dentro del viewport seguro `[safeTop, safeBottom]`).
   * En `CoachCardWidget`:
     * Se ajusta el título a `maxLines: 2`, `overflow: TextOverflow.ellipsis` y `style: TextStyle(fontSize: 14.5, height: 1.25)`.
     * Se elimina cualquier corte de texto visible en dispositivos medianos y compactos.

5. **Validación Defensiva de RenderBox y Auto-scroll Confiable:**
   * En `_focusCurrentStep`:
     ```dart
     final renderObject = targetContext.findRenderObject();
     final isValidBox = renderObject is RenderBox &&
         renderObject.hasSize &&
         renderObject.size.width >= 12.0 &&
         renderObject.size.height >= 12.0;
     if (!isValidBox) {
       _skipToNextStep();
       return;
     }
     ```
   * En `BackupScreen`:
     * Se sustituye `ListView(children: [...])` por `SingleChildScrollView(child: Column(children: [...]))`, preservando `wantKeepAlive == true` y compatibilidad con `google_drive_reactive_provider_and_sheet_test.dart`.
     * Todas las secciones existen simultáneamente en el árbol de elementos de Flutter, permitiendo a `Scrollable.ensureVisible` desplazarse fluidamente del paso 1/4 al 2/4, 3/4 y 4/4 sin cierres prematuros.

6. **Protocolo Estándar de Acordeones Animados (`onBeforeStep` / `onAfterStep`):**
   * `onBeforeStep`: Despliega el acordeón con animación, espera la finalización del movimiento (`Duration(milliseconds: 300)` + `WidgetsBinding.instance.endOfFrame`) y ejecuta `Scrollable.ensureVisible`.
   * `onAfterStep`: Si el siguiente paso apunta a un elemento fuera de ese acordeón, lo repliega automáticamente, dejando la interfaz limpia.

---

### 3.2 PILAR 2: Ciclo de Vida, Persistencia Real y Reactivación Determinista

1. **Regla Comercial de Persistencia Única:**
   * Las guías automáticas se conciben exclusivamente para **nuevos usuarios / instalaciones limpias**.
   * Una vez que el usuario recorre o descarta las guías de las pantallas, la bandera `tour_automatic_enabled` se apaga automáticamente (`false`).
   * Esta bandera y las pantallas vistas se persisten en `SharedPreferences` y se audita `StartupFlowCoordinator` para confirmar que ningún flujo de arranque limpie claves `tour_*`. Asimismo, se brinda soporte en la metadata de exportación/restauración de backups para que el estado completado se preserve sin alterar el esquema SQLite `v36`.
   * Si el usuario cierra y reabre la app, ninguna guía se vuelve a disparar sola.

2. **Propagación Sincrónica de "Omitir todas las guías automáticas":**
   * Al presionar `"Omitir todas las guías automáticas"` en cualquier modal:
     1. Se marca la pantalla actual como vista (`markScreenSeen(config.screenId)`).
     2. Se persiste sincrónicamente `tour_automatic_enabled = false`.
     3. Se limpia cualquier cola pendiente de guías en memoria.
     4. Se cierra el modal y se garantiza que ninguna otra pantalla abra guías en el futuro.

3. **Reactivación Reactiva mediante `tourResetEpoch`:**
   * En `InteractiveTourService`, se introduce un `ValueNotifier<int> tourResetEpoch = ValueNotifier<int>(0)`.
   * Al pulsar `"Reiniciar"` en el diálogo de `ProfileScreen`:
     1. Se eliminan todas las claves `tour_screen_seen_*`.
     2. Se establece `tour_automatic_enabled = true` y `tour_suppressed_after_restore = false`.
     3. Se incrementa `tourResetEpoch.value++`.
     4. Se actualiza el Switch de `ProfileScreen` inmediatamente.
     5. Se lanza inmediatamente la guía interactiva de `ProfileScreen` en la que se encuentra el comerciante.
   * En `HomeScreen` y vistas principales, se suscribe al `tourResetEpoch` (o se verifica en `didPopNext` / cambio de pestaña). Cuando la época de reinicio es superior a la registrada en la pantalla, la pantalla vuelve a ofrecer su tour automático por primera vez tras el reinicio.

---

### 3.3 PILAR 3: Corrección Forense de Anclajes en 10 Pantallas Actuales

1. **`HomeScreen`:**
   * **Paso 3 (`Licencia y Saldo IA`):** Se ancla al badge de saldo IA o avatar de suscripción en `DashboardHeader` (siempre visible) en lugar del banner condicional `_buildLicenseBanner` (que retorna `SizedBox.shrink()` en licencias normales).
   * **Paso 4 (`Accesos Rápidos Operativos`):** Se acota el `GlobalKey` a la fila superior de botones de acción rápida, evitando el spotlight envolvente de toda la pantalla.
   * **Paso 5 (`Actividad y Ventas`):** Se alinea el foco con `WeeklySalesChart` o `QuotationBanner` según corresponda, desplegando la tarjeta adecuada.
   * **Paso 6 (`Barra de Navegación`):** Se corrige el texto: *"Muévete con total fluidez entre Inicio, Inventario, Catálogo y Clientes."*

2. **`ProductCreateScreen` (`Nuevo Producto`):**
   * **Paso 2 (`Código de Barras Global`):** Se configura `onBeforeStep` para invocar la animación de despliegue de `"Detalles Globales (Opcional)"` antes de medir, y `onAfterStep` para contraerlo.
   * **Paso 4 (`Presentaciones y Opciones Avanzadas`):** Título visible en 2 líneas sin recortar. Anclaje y encuadre completo de la tarjeta de variante individual además del título.
   * **Paso 6 (`Guardar Producto`):** Con el layout unificado del Pilar 1, la tarjeta y flecha se anclan firmemente justo arriba del botón `GUARDAR PRODUCTO`.

3. **`InventoryScreen` (`Gestión de Negocio`):**
   * **Paso 3 (`Buscador y Filtros Avanzados`):** Se corrige el anclaje del `GlobalKey`, colocándolo sobre el `Container` de la barra de búsqueda o el widget interno de `FlexibleSpaceBar`, el cual posee un `RenderBox` válido y no arroja el error de `RenderSliver`.
   * **Paso 4 (`Crear Producto Nuevo`):** Se añade `onBeforeStep: () async { _tabController.animateTo(0); await Future.delayed(const Duration(milliseconds: 250)); }` para asegurar que siempre esté seleccionada la pestaña de Productos y el FAB esté visible y enfocado.

4. **`BackupScreen` y `LicenseStatusAndActivationScreen`:**
   * En `BackupScreen`: Anclaje del paso 1/4 a la tarjeta superior de estado de Google Drive (evitando ocultar el texto "Al día"), preservación de `wantKeepAlive == true`, compatibilidad con `google_drive_reactive_provider_and_sheet_test.dart` y transición fluida a los pasos 2, 3 y 4 gracias a `SingleChildScrollView`.
   * En `LicenseStatusAndActivationScreen`: Anclaje del paso 5/5 al encabezado de planes comerciales o a la primera tarjeta ("Semestral"), evitando envolver el catálogo completo de 1,200px.
   * En `ProfileScreen`: Adición de `SafeArea(bottom: true)` y padding inferior de seguridad (`viewPadding.bottom + 24`) para mantener la "Zona de Peligro" completamente accesible sobre la barra de navegación de Android.

---

### 3.4 PILAR 4: Rediseño Visual Profesional de `Escanear Factura`

> [!IMPORTANT]
> La vista de **`Escanear Lista`** (`isQuotation == true`) se mantiene **100% idéntica** en su estructura visual. Las modificaciones de este pilar aplican con exclusividad al modo **`Escanear Factura`** (`isQuotation == false`).

* **Estructura visual equilibrada y ergonómica:**
  1. **AppBar:**
     * Título claro `"Escanear Factura"`.
     * Botón `InfoTooltipButton` integrado en las acciones para lanzar la guía paso a paso bajo demanda.
     * Botón de acceso directo al Historial de Facturas IA (`Icons.receipt_long_rounded`).
  2. **Tarjeta Hero con Saldo IA:**
     * Contenedor con degradado sutil verde azulado (`teal`).
     * Icono vectorial institucional de escáner.
     * Badge reactivo de **"Escaneos IA Disponibles"** que consulta `licenseProv.scansRemaining`, mostrando al comerciante su cuota en tiempo real antes de abrir la cámara.
  3. **Tarjetas de Acción Primaria (Cámara y Galería):**
     * Disposición horizontal en dos tarjetas amplias con altura de 140dp.
     * **Cámara:** Icono de cámara, título *"Tomar Foto"*, subtítulo *"Captura nítida de la factura física"* y feedback háptico `HapticFeedback.lightImpact()`.
     * **Galería:** Icono de galería, título *"Subir Archivo"*, subtítulo *"Selecciona imagen o PDF de tu galería"* y feedback háptico.
  4. **Bloque Inferior de Valor Agregado ("¿Qué procesa la IA automáticamente?"):**
     * 3 micro-tarjetas con iconos vectoriales Material y tipografía concisa (cero emojis crudos):
       * `Icons.inventory_2_outlined` *Extracción de Ítems y Cantidades:* Detecta automáticamente cada línea de producto.
       * `Icons.payments_outlined` *Costos y Precios de Venta:* Calcula el costo unitario y sugiere el margen de ganancia.
       * `Icons.sync_rounded` *Actualización Directa a Stock:* Reabastece tu inventario sin digitación manual.
  5. **Tip de Captura Óptima:**
     * Micro-banner inferior con `Icons.lightbulb_outline`: *"Consejo: Coloca la factura en una superficie plana con buena iluminación y evita sombras."*
  6. **Resiliencia Responsiva:**
     * 0px de desbordamiento en pantallas desde `320x568dp` hasta `412x915dp`.
     * Protección con `SafeArea` inferior.

---

### 3.5 PILAR 5: Catálogo Exhaustivo de Expansión de Guías Turísticas (Fases 5A y 5B)

Se auditaron todos los módulos de `app_movil/lib/features/` para diseñar la expansión sistemática de las guías en las pantallas clave restantes, excluyendo explícitamente `lock_screen.dart` para no interferir con la seguridad y flujo crítico de desbloqueo por PIN:

| Fase | Pantalla | Archivo Fuente | Pasos Concisos (3 a 5 pasos) | Secciones Plegables / Modales Dinámicos (`onBeforeStep` / `onAfterStep`) |
| :--- | :--- | :--- | :--- | :--- |
| **5A** | **Catálogo Visual de Productos** | `features/catalog/screens/catalog/catalog_screen.dart` | 1. Barra de Búsqueda y Filtros en Vivo<br>2. Carrusel de Ofertas y Combos<br>3. Cuadrícula de Tarjetas de Producto<br>4. Carrito Flotante y Menú de Acciones Rápidas | `onBeforeStep` expande `_isOffersExpanded = true` para el paso 2 y lo contrae en `onAfterStep`. Expande menú flotante en paso 4. |
| **5A** | **Escanear Factura** | `features/scanner/screens/scan_screen.dart` (Modo Factura) | 1. Saldo de Escaneos IA en Vivo<br>2. Captura con Cámara y Consejos de Luz<br>3. Subida desde Galería / Archivos<br>4. Historial de Facturas Procesadas | En paso 2 muestra tooltip con consejos de enfoque y nitidez. |
| **5A** | **Escanear Lista** | `features/scanner/screens/scan_screen.dart` (Modo Cotización) | 1. Modalidades de Lista (Compras, Negocio, Escolar)<br>2. Captura de Listas Escritas a Mano o Impresas<br>3. Asignación Rápida a Cliente | Sin alterar diseño visual; enfoca selectores de escenario. |
| **5A** | **Cobro de Venta (Checkout)** | `features/smart_quotation/screens/sales_checkout_screen.dart` | 1. Selección de Cliente (Contado vs. Crédito)<br>2. Configuración de Pago (Efectivo, Yape/Plin, Cuotas)<br>3. Aplicación de Premios y Descuentos<br>4. Cierre y Emisión de Comprobante | En paso 2 despliega opciones de cuotas si se selecciona crédito. |
| **5B** | **Detalle de Cliente y Abonos** | `features/smart_quotation/screens/crm/client_detail_screen.dart` | 1. Ficha de Estadísticas (Saldo Deudor y Compras)<br>2. Botón Registrar Abono / Pago<br>3. Pestañas de Historial, Ventas y Cotizaciones<br>4. Contacto Directo por WhatsApp | En paso 2 prepara el anclaje al botón de abono rápido. |
| **5B** | **Centro de Fidelización (Puntos y Premios)** | `features/smart_quotation/screens/crm/loyalty_center_screen.dart` | 1. Reglas del Programa (Puntos por Sol)<br>2. Catálogo de Metas y Premios<br>3. Clientes con Premios por Reclamar<br>4. Broadcast de Promociones WhatsApp | `onBeforeStep` conmuta pestañas para mostrar Premios y Canjes según el paso. |
| **5B** | **Dashboard de Analíticas** | `features/analytics/screens/analytics_dashboard_screen.dart` | 1. Radar Comercial e Insights IA<br>2. Resumen de KPIs Financieros<br>3. Gráficas de Ventas y Medios de Pago<br>4. Alertas de Reposición Inteligente | `onBeforeStep` desplaza suavemente a las secciones correspondientes del dashboard. |
| **5B** | **Creador de Ofertas y Combos** | `features/promotions/screens/bundle_builder_screen.dart` | 1. Nombre y Vigencia de la Promoción<br>2. Selección de Productos del Combo<br>3. Fijación de Descuento y Precio Final | Enfoca selector de productos y cálculo automático de ahorro. |
| **5B** | **Impresora Térmica** | `features/profile/screens/printer_config_screen.dart` | 1. Escaneo y Vinculación Bluetooth<br>2. Configuración de Ancho de Papel (58mm / 80mm)<br>3. Impresión de Ticket de Prueba | Valida estado de conexión Bluetooth antes de enfocar. |

---

## 4. PLAN DE TRABAJO MAESTRO EN FASES SECUENCIALES

```mermaid
flowchart LR
    F1[Fase 1: Motor y Layout Coach Marks] --> F2[Fase 2: Persistencia y Ciclo de Vida]
    F2 --> F3[Fase 3: Corrección en 10 Pantallas]
    F3 --> F4[Fase 4: Rediseño Escanear Factura]
    F4 --> F5A[Fase 5A: Expansión Catálogo, Scan y Checkout]
    F5A --> F5B[Fase 5B: Expansión CRM, Fidelización, Analíticas, Promos e Impresora]
    F5B --> F6[Fase 6: Pruebas, Bump v9.37.0 y APK Final Oficial]
```

### FASE 1: Reparación del Motor Visual de Guía (`InteractiveTourOverlay`, `CoachCardWidget` y Mutex Global)
* **Objetivo:** Erradicar choques simultáneos de tours, reparar la geometría de la flecha desprendida en `placement == above`, limitar el spotlight en contenedores gigantes y validar tamaños válidos de widgets.
* **Archivos a modificar:**
  * `app_movil/lib/core/services/tour/interactive_tour_service.dart`
  * `app_movil/lib/core/widgets/tour/coach_card_widget.dart`
  * `app_movil/lib/core/widgets/tour/interactive_tour_overlay.dart`
  * `app_movil/lib/core/widgets/tour/spotlight_painter.dart`
* **Entregables:**
  * Mutex global continuo que permanece bloqueado durante todo el ciclo (Welcome Modal + Tour Overlay).
  * `CoachCardWidget` con bloque unificado (`Positioned` con `bottom` en `placement == above`), asegurando que la flecha y la tarjeta estén soldadas sin separación.
  * Acotamiento visual de rectángulos de spotlight que superen el 55% del viewport.
  * Título de `CoachCardWidget` con `maxLines: 2` y márgenes seguros.
  * Filtro de seguridad que omite widgets con `size.width < 12 || size.height < 12`.

---

### FASE 2: Ciclo de Vida, Persistencia Blindada, "Omitir Todas" y "Reiniciar Guías"
* **Objetivo:** Garantizar que las guías no reaparezcan solas al reiniciar la app, que "Omitir todas" sea instantáneo y persistente, auditar `StartupFlowCoordinator` para confirmar que nada limpie claves en arranque y mantener soporte en metadata de backup/restore sin alterar el esquema SQLite `v36`.
* **Archivos a modificar:**
  * `app_movil/lib/core/services/tour/interactive_tour_service.dart`
  * `app_movil/lib/core/widgets/tour/interactive_tour_overlay.dart`
  * `app_movil/lib/features/profile/screens/profile_screen.dart`
  * `app_movil/lib/core/services/startup_flow_coordinator.dart` (auditoría defensiva de arranque)
* **Entregables:**
  * Persistencia sincrónica con almacenamiento seguro en `SharedPreferences`.
  * Implementación de `ValueNotifier<int> tourResetEpoch` para reactividad en pantallas en backstack.
  * Invocación inmediata de la guía de `ProfileScreen` al confirmar el reinicio.
  * Desactivación automática del switch global tras recorrer u omitir todas las pantallas.

---

### FASE 3: Corrección Forense de Anclajes, Pasos y Textos en las 10 Pantallas Actuales
* **Objetivo:** Resolver el error de `RenderSliver` en `InventoryScreen`, el cierre prematuro en `BackupScreen`, el spotlight `○` en `HomeScreen`, la apertura automática de acordeones en `ProductCreateScreen` (encuadrando la tarjeta de variante además del título) y los paddings en `ProfileScreen`.
* **Archivos a modificar:**
  * `app_movil/lib/core/screens/home_screen.dart`
  * `app_movil/lib/core/widgets/tour/configs/home_screen_tour.dart`
  * `app_movil/lib/features/catalog/screens/product_create_screen.dart`
  * `app_movil/lib/core/widgets/tour/configs/product_create_tour.dart`
  * `app_movil/lib/features/catalog/screens/inventory_screen.dart`
  * `app_movil/lib/features/catalog/screens/tabs/products_tab.dart`
  * `app_movil/lib/features/catalog/screens/tabs/widgets/inventory_filter_header.dart`
  * `app_movil/lib/core/widgets/tour/configs/inventory_tour.dart`
  * `app_movil/lib/features/profile/screens/backup_screen.dart`
  * `app_movil/lib/core/widgets/tour/configs/backup_screen_tour.dart`
  * `app_movil/lib/features/auth/screens/license/license_status_and_activation_screen.dart`
  * `app_movil/lib/core/widgets/tour/configs/license_status_tour.dart`
  * `app_movil/lib/features/profile/screens/profile_screen.dart`
* **Entregables:**
  * Anclaje corregido en `HomeScreen` (saldo real en header, accesos rápidos acotados, 4 pestañas reales descritas).
  * `ProductCreateScreen` con hook `onBeforeStep` que despliega `"Detalles Globales (Opcional)"` en el paso 2 y lo retrae en `onAfterStep`, además de encuadre de la tarjeta de variante en paso 4.
  * `InventoryScreen` con `searchFiltersKey` anclado a un `RenderBox` válido (adiós crash de `RenderSliver`) y cambio automático a la subpestaña Productos en el paso 4.
  * `BackupScreen` migrado a `SingleChildScrollView` preservando `wantKeepAlive == true` y compatibilidad con `google_drive_reactive_provider_and_sheet_test.dart`, garantizando auto-scroll ininterrumpido del paso 1/4 al 4/4.
  * `LicenseStatusAndActivationScreen` con paso 5/5 anclado a la cabecera de suscripciones.
  * `ProfileScreen` con `SafeArea(bottom: true)` y margen holgado para "Zona de Peligro".

---

### FASE 4: Rediseño Visual Profesional de `Escanear Factura` (Sin Alterar `Escanear Lista`)
* **Objetivo:** Dotar a la pantalla de `Escanear Factura` de un diseño profesional, equilibrado, interactivo y con propósito real que llene el espacio inferior sin saturación.
* **Archivos a modificar:**
  * `app_movil/lib/features/scanner/screens/scan_screen.dart`
* **Entregables:**
  * Cabecera con `InfoTooltipButton` integrado y acceso rápido al Historial de Facturas IA.
  * Tarjeta Hero moderna con badge en vivo de escaneos IA disponibles.
  * Tarjetas de acción Cámara y Galería rediseñadas con subtítulos y respuesta táctil háptica.
  * Bloque inferior pedagógico: 3 micro-tarjetas vectoriales explicativas del procesamiento automático de la IA (con `Icons.inventory_2_outlined`, `Icons.payments_outlined`, `Icons.sync_rounded`) + consejo de iluminación y enfoque.
  * 0px de overflow en resoluciones de 320dp a 412dp.

---

### FASE 5A: Ampliación de Guías - Catálogo, Escáner y Checkout
* **Objetivo:** Incorporar configuraciones de tour, anclajes e `InfoTooltipButton` en las pantallas de mayor rotación comercial.
* **Archivos a crear / modificar:**
  * `app_movil/lib/core/widgets/tour/configs/catalog_tour.dart`
  * `app_movil/lib/core/widgets/tour/configs/invoice_scan_tour.dart`
  * `app_movil/lib/core/widgets/tour/configs/quotation_scan_tour.dart`
  * `app_movil/lib/core/widgets/tour/configs/sales_checkout_tour.dart`
  * `app_movil/lib/features/catalog/screens/catalog/catalog_screen.dart`
  * `app_movil/lib/features/scanner/screens/scan_screen.dart`
  * `app_movil/lib/features/smart_quotation/screens/sales_checkout_screen.dart`
* **Entregables:**
  * Guías interactivas con activación manual vía `InfoTooltipButton` y evaluación automática de primera visita.
  * Hooks de animación para apertura/cierre de carruseles de ofertas y acordeones de crédito.

---

### FASE 5B: Ampliación de Guías - CRM, Fidelización, Analíticas, Promociones e Impresora
* **Objetivo:** Incorporar configuraciones de tour en pantallas de fidelización y herramientas operativas avanzadas (excluyendo explícitamente `lock_screen.dart`).
* **Archivos a crear / modificar:**
  * `app_movil/lib/core/widgets/tour/configs/client_detail_tour.dart`
  * `app_movil/lib/core/widgets/tour/configs/loyalty_center_tour.dart`
  * `app_movil/lib/core/widgets/tour/configs/analytics_dashboard_tour.dart`
  * `app_movil/lib/core/widgets/tour/configs/bundle_builder_tour.dart`
  * `app_movil/lib/core/widgets/tour/configs/printer_config_tour.dart`
  * `app_movil/lib/features/smart_quotation/screens/crm/client_detail_screen.dart`
  * `app_movil/lib/features/smart_quotation/screens/crm/loyalty_center_screen.dart`
  * `app_movil/lib/features/analytics/screens/analytics_dashboard_screen.dart`
  * `app_movil/lib/features/promotions/screens/bundle_builder_screen.dart`
  * `app_movil/lib/features/profile/screens/printer_config_screen.dart`
* **Entregables:**
  * Guías interactivas completas para CRM, fidelización por puntos, métricas comerciales, combos e impresión térmica.

---

### FASE 6: Suite de Pruebas Automatizadas, Bump de Versión y Compilación Comercial Oficial (`mochilalista_v9.37_atp.apk`)
* **Objetivo:** Validar la estabilidad del sistema mediante pruebas unitarias y de widgets, sincronizar registros legales y changelog, incrementar la versión a `v9.37.0+81` y generar el APK comercial firmado exclusivamente en el directorio de release oficial.
* **Archivos a modificar / sincronizar:**
  * `app_movil/pubspec.yaml` (versión `9.37.0+81`)
  * `app_movil/lib/core/config/owner_legal_identity.dart`
  * `app_movil/lib/core/config/app_changelog_registry.dart`
  * `app_movil/test/backup_multi_profile_database_integrity_test.dart`
  * `informe_proyecto/05_MANUAL_OPERATIVO_DEL_PROPIETARIO_Y_COMANDOS_RELEASE.md`
  * `app_movil/test/interactive_spotlight_tour_test.dart`
* **Entregables:**
  * Suite de tests automatizados aprobada al 100%.
  * Cero errores en `flutter analyze`.
  * Compilación exitosa del APK release firmado con `apksigner` verificado contra `MainActivity.kt`.
  * Entrega exclusiva del archivo compilado en:
    `C:\Users\vjuli\Documents\v-app-offline apks\mochilalista_v9.37_atp.apk`
    junto con sus notas `mochilalista_v9.37_atp.txt` y `mochilalista_v9.37_atp_cambios.txt`.
  * Commit y push limpio a la rama `dev/mejoras-v9.0-comercializacion-seguridad`.

---

## 5. CRITERIOS DE ACEPTACIÓN Y CERTIFICACIÓN VERIFICABLES

1. **Cero Choques de Tours:** Al ingresar a `HomeScreen` con un perfil nuevo o tras reiniciar guías, solo se presenta la bienvenida de `HomeScreen`. Jamás coinciden dos modales ni un modal sobre un tour activo.
2. **Flecha Rígidamente Soldada:** En todos los pasos con `placement == above` (`HomeScreen` 6/6, `ProductCreateScreen` 6/6, `InventoryScreen` 4/4), la tarjeta y su flecha forman un único bloque posicionado justo encima del objetivo, con cero píxeles de separación.
3. **Cero Círculos Vacíos:** Cuando un widget tiene tamaño nulo o está condicionalmente oculto (`SizedBox.shrink`), el motor lo omite limpiamente y enfoca el siguiente elemento sin pintar círculos `○` de 0x0.
4. **Flujo Completo en Respaldos:** En `BackupScreen`, al pulsar "Siguiente" en el paso 1/4, la pantalla realiza auto-scroll suave y presenta de forma consecutiva los pasos 2/4, 3/4 y 4/4 sin cerrarse prematuramente.
5. **Persistencia Hermética:**
   * Al pulsar `"Omitir todas las guías automáticas"`, ninguna otra pantalla vuelve a abrir guías automáticas, incluso tras cerrar por completo la app desde las aplicaciones recientes y volverla a abrir.
   * Al pulsar `"Reiniciar guías de aprendizaje"` en `Perfil`, se lanza de inmediato la guía de Perfil y, al regresar a `HomeScreen`, esta presenta su guía por primera vez tras el reinicio.
6. **Escanear Factura Profesional:**
   * La vista de `Escanear Factura` aprovecha armónicamente la pantalla vertical mostrando cabecera, tarjeta hero con saldo IA, botones de cámara/galería con subtítulos y bloque explicativo inferior con tips de enfoque.
   * La vista de `Escanear Lista` permanece 100% inalterada.
   * Cero desbordamientos (0px overflow) en `320x568dp`, `360x640dp` y `412x915dp`.
7. **Cobertura Integral:** Las nuevas pantallas del catálogo disponen de su botón `InfoTooltipButton` y recorridos guiados funcionales con despliegue automático de acordeones.
8. **Release Comercial:** Generación del APK final `mochilalista_v9.37_atp.apk` firmado y entregado exclusivamente en `C:\Users\vjuli\Documents\v-app-offline apks\mochilalista_v9.37_atp.apk`.

---

## 6. ACTA OFICIAL DE CIERRE Y CERTIFICACIÓN FINAL DEL PLAN MAESTRO 17

**Fecha de Cierre Oficial:** 22 de Noviembre de 2026  
**Autor y Titular Exclusivo:** Julio Angello Vasquez Navarro  
**Versión Certificada:** `v9.37.0+81` (`mochilalista_v9.37_atp.apk`)  
**Estado:** 100% COMPLETADO, VERIFICADO Y SINCRONIZADO EN GITHUB  

### 6.1 Resumen Ejecutivo de Fases Cerradas
1. **Fase 1 (Motor de Guía Turística):** Resuelto de raíz el candado continuo atómico (Mutex en `InteractiveTourService`), la flecha direccional soldada a la tarjeta en posicionamiento superior e inferior (`CoachCardWidget`), títulos con `maxLines: 2`, omisión defensiva de elementos con dimensiones menores a 12x12dp (`0x0`), protección contra excepciones `RenderSliver` y acotamiento de spotlights gigantes a un máximo del 55% de pantalla.
2. **Fase 2 (Máquina de Estados y Persistencia Hermética):** Persistencia global por instalación/dispositivo (las guías no vuelven a aparecer al cambiar de perfil de negocio ni al restaurar copias de respaldo de Google Drive o `.mlbg`). Sellado sincrónico inmediato de *"Omitir todas las guías automáticas"*, auto-desactivación limpia al culminar o descartar el catálogo, y funcionamiento reactivo instantáneo de *"Reiniciar guías de aprendizaje"* en `ProfileScreen` coordinado mediante `tourResetEpoch`.
3. **Fase 3 (Corrección Forense de Anclajes y Visibilidad en 10 Pantallas):** Coordinación con `IndexedStack` en `HomeScreen` (suspensión del auto-trigger en pestañas en segundo plano hasta la selección explícita), `ListView(cacheExtent: 9999)` en `BackupScreen` preservando `wantKeepAlive: true`, y anclajes milimétricos en Inicio, Perfil, Inventario, Licencias, Cotizador y Clientes con `SafeArea` inferior.
4. **Fase 4 (Rediseño Profesional de Escanear Factura):** Aprovechamiento armónico del espacio vertical con saldo IA en vivo, acceso directo al Historial de Facturas Procesadas, botones optimizados de Cámara y Galería, y guía de pasos del procesamiento OCR con cero emojis crudos y 0px de overflow. La vista `"Escanear Lista"` (`ScanMode.quotation`) se mantuvo 100% inalterada.
5. **Fase 5A (Expansión Comercial 1):** Incorporación de guías en `CatalogScreen` (con hooks automáticos para expandir/colapsar carrusel de ofertas y acordeón), `ScanScreen` (Modo Factura y Modo Lista) y `SalesCheckoutScreen` (Cobro de Venta).
6. **Fase 5B (Expansión Comercial 2 y Cierre de Catálogo):** Incorporación de guías en `ClientDetailScreen`, `LoyaltyCenterScreen` (con hooks animados entre tabs), `AnalyticsDashboardScreen`, `BundleBuilderScreen` y `PrinterConfigScreen`. Exclusión obligatoria estricta de `lock_screen.dart` (PIN Vault).
7. **Fase 6 (Release Comercial y Certificación Criptográfica):** Sincronización oficial a `v9.37.0+81`, regresión global 100% en verde, compilación oficial ofuscada y firmada con RSA-4096 y entrega exclusiva en biblioteca oficial.

### 6.2 Catálogo Canónico Oficial de 19 Pantallas con Guía Turística Interactiva
| # | ID Canónico (`screenId`) | Archivo de Configuración | Pantalla / Vista Oficial | Cantidad de Pasos | Hooks Dinámicos |
|---|--------------------------|--------------------------|--------------------------|:-----------------:|:---------------:|
| 1 | `home_screen` | `home_screen_tour.dart` | Inicio / Dashboard Principal | 6 | Sincronización con `tourResetEpoch` |
| 2 | `profile_screen` | `profile_screen_tour.dart` | Perfil Comercial y Ajustes | 5 | Reinicio reactivo de guías |
| 3 | `product_create_screen` | `product_create_tour.dart` | Creación y Edición de Productos | 6 | Despliegue de código de barras |
| 4 | `quick_sale_screen` | `quick_sale_tour.dart` | Punto de Venta y Caja Rápida | 4 | Anclaje en buscador y cobro |
| 5 | `inventory_screen` | `inventory_tour.dart` | Inventario y Artículos | 4 | Conmutación a pestaña Productos |
| 6 | `workbench_screen` | `workbench_tour.dart` | Cotizador Inteligente y Mesa de Trabajo | 5 | Anclajes de cotización |
| 7 | `client_tracking_screen` | `client_tracking_tour.dart` | Directorio de Clientes y Abonos CRM | 5 | Búsqueda y balance deudores |
| 8 | `sales_history_screen` | `sales_history_tour.dart` | Historial de Ventas, Caja y Reportes | 5 | Filtros de fecha y tickets |
| 9 | `backup_screen` | `backup_screen_tour.dart` | Respaldos en Google Drive y Locales | 4 | Auto-scroll continuo sin cortes |
| 10 | `license_status_screen` | `license_status_tour.dart` | Licencia Oficial y Saldo IA | 5 | Cabecera y catálogo de planes |
| 11 | `catalog_screen` | `catalog_tour.dart` | Catálogo Comercial y Promociones | 4 | Apertura/cierre de ofertas |
| 12 | `invoice_scan_screen` | `invoice_scan_tour.dart` | Escanear Factura (Modo Factura) | 4 | Acceso a historial y saldo IA |
| 13 | `quotation_scan_screen` | `quotation_scan_tour.dart` | Escanear Lista (Modo Lista) | 3 | Modalidades y captura rápida |
| 14 | `sales_checkout_screen` | `sales_checkout_tour.dart` | Cobro de Venta y Despacho en Caja | 4 | Métodos de pago y comprobante |
| 15 | `client_detail_screen` | `client_detail_tour.dart` | Detalle de Cliente y Estado de Cuenta | 4 | Registro de abonos y WhatsApp |
| 16 | `loyalty_center_screen` | `loyalty_center_tour.dart` | Centro de Fidelización y Gamificación | 4 | Cambio animado entre 3 tabs |
| 17 | `analytics_dashboard_screen` | `analytics_dashboard_tour.dart` | Dashboard de Analíticas y Radar Comercial | 4 | KPIs, predicciones y alertas |
| 18 | `bundle_builder_screen` | `bundle_builder_tour.dart` | Creador de Ofertas y Combos | 3 | Descuentos y selección de items |
| 19 | `printer_config_screen` | `printer_config_tour.dart` | Impresora Térmica Bluetooth | 3 | Ancho de papel y escaneo |

*Paridad de Conjuntos:* `InteractiveTourService.knownScreenIds.toSet() == {19 screenIds reales}` garantizado al 100%. Exclusión verificada de `lock_screen`, `products_tab` y `quick_quotation_screen`.

### 6.3 Métricas de Certificación de Calidad
- **Análisis Estático Oficial:** `flutter analyze --no-pub lib test` -> `No issues found!` (0 errores, 0 advertencias, 0 lints).
- **Pruebas Automatizadas Ejecutadas:** 285 pruebas aprobadas (100% éxito, 0 fallos).
- **Control de Desbordamiento:** 0px Overflow garantizado en pantallas de 320x568dp, 360x640dp y 412x915dp a TextScaler 1.3.

### 6.4 Ficha Criptográfica Oficial del Binario Compilado
- **Archivo:** `mochilalista_v9.37_atp.apk`
- **Ubicación Exclusiva:** `C:\Users\vjuli\Documents\v-app-offline apks\mochilalista_v9.37_atp.apk`
- **Tamaño Exacto:** `114,971,810 bytes` (`109.65 MB`)
- **Hash SHA-256:** `AFFA0B61FFB894AF26827378CA0B8850BEB420B1A4EF8BF0C1ED25FABD6D859E`
- **Hash SHA-1:** `E977049EF03CEE06D96A332601628603D62D9D63`
- **Firma del Certificado Release:**
  - **DN:** `CN=Julio Angello Vasquez Navarro, OU=MochilaLista Core Development, O=MochilaLista, L=Piura, ST=Piura, C=PE`
  - **Algoritmo:** `RSA 4096 bits`
  - **Certificado SHA-1:** `e79c5354063f28d25ee4efe644d5670065c6b866`
  - **Certificado SHA-256:** `7c43addc34776f3974eac23fdacc47599efd5393a4dbb28672d06899833ffd20` (1:1 con `MainActivity.kt`)
  - **Esquema de Firma:** `APK Signature Scheme v2 (Verifies: true)`
