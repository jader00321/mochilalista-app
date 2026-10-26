# 🚀 PLAN MAESTRO DE REFINAMIENTO: INTELIGENCIA DE NEGOCIO, PERSONALIZACIÓN, MODALES Y VENTANA DEDICADA RADAR COMERCIAL IA

**Documento de Especificación Técnica, Auditoría Forense y Protocolo de Implementación Adversarial**  
**Proyecto:** MochilaLista App (Local-First SQLite, 0ms Latency, Flutter Mobile — Estándar Mobile Awards)  
**Módulos Involucrados:**
- **Núcleo de Inteligencia de Negocio:** `analytics_dashboard_screen.dart`, `analytics_provider.dart`.
- **Modales del Dashboard:** `dashboard_customizer_modal.dart`, `financial_summary_card.dart`, `interactive_sheet_wrapper.dart`.
- **Servicios y Modelos del Radar Comercial IA:** `commercial_radar_service.dart`, `commercial_radar_model.dart`, `commercial_radar_card.dart`.
- **Nueva Pantalla Completa Dedicada:** `commercial_radar_screen.dart`.
- **Integración con Home y Gestión Operativa:** `home_screen.dart`, `smart_action_grid.dart`.
- **Configuración de Secciones:** `dashboard_section_config.dart`.
- **Batería de Pruebas Automatizadas:** `test/business_intelligence_and_commercial_radar_reengineering_test.dart` y nuevo archivo de pruebas dedicado.
**Fecha:** Octubre 2026  
**Metodología:** Loop Autónomo + Árbitro Interno Adversarial Estricto  

---

## 📸 1. AUDITORÍA FORENSE DE LAS 5 CAPTURAS Y DIAGNÓSTICO EN CÓDIGO FUENTE

A partir de la inspección exhaustiva de las 5 capturas remitidas por el usuario y la auditoría línea por línea del código fuente en `lib/features/analytics/` y `lib/core/`, se determina la causa raíz exacta de cada inconsistencia visual, fallo de maquetación y defecto de interacción:

| Captura | Pantalla / Componente | Diagnóstico Forense del Defecto | Causa Raíz Exacta en Código Fuente |
| :--- | :--- | :--- | :--- |
| **Capturas 1 y 2** | **AppBar del Dashboard (`analytics_dashboard_screen.dart`)** | **Título Truncado con Puntos Suspensivos (`"Inteligenci..."`):**<br>El título superior no cabe en pantallas estándar de `360dp` de ancho y se corta abruptamente como `"Inteligenci..."`, a pesar de usar un tamaño de fuente de solo 17sp. | • `analytics_dashboard_screen.dart` L220-309: El `AppBar` acumula en la misma fila horizontal el botón de retroceso `leading` (38dp) más **5 botones de acción a la derecha**: `InfoTooltipButton` (36dp) + `IconButton(tune)` (36dp) + `IconButton(refresh)` (36dp) + `IconButton(visibility)` (36dp) + `PopupMenuButton(download)` (36dp) + insets del toolbar (~32dp).<br>• En un ancho físico de 360dp, los iconos y márgenes consumen ~215dp, dejando solo ~145dp para el título. `"Inteligencia de Negocio"` requiere al menos 200dp a 18sp. Al desbordar el contenedor interno de Flutter, el `AppBar` aplica elipsis forzada. |
| **Capturas 1 y 2** | **Fila 2 de Chips Superiores (`_buildQuickJumpChip`)** | **1. Chips Apagados / Inertes sin ScrollSpy:**<br>Al desplazarse verticalmente por la ventana o presionar un chip, todos permanecen en gris estático (`Colors.white.withValues(alpha: 0.08)`); no hay indicación visual de qué sección está en pantalla (en la Captura 2 estamos en `Radar Comercial` pero el chip `📰 Radar` sigue gris y cortado a la derecha).<br>**2. Salto Impreciso (`_jumpToGroup`):**<br>Al pulsar un chip, la pantalla aterriza arriba o abajo del contenido deseado.<br>**3. Desconexión con la Personalización:**<br>Los chips están hardcodeados (`resumen`, `graficos`, `inventario`, `radar`), sin adaptarse si el usuario reordena u oculta secciones. | • `analytics_dashboard_screen.dart` L653-670: Los 4 chips son hijos fijos de un `ListView` horizontal que no mantiene ningún estado reactivo `_activeGroup` ni detecta el scroll vertical.<br>• `analytics_dashboard_screen.dart` L701-720: `_buildQuickJumpChip` no posee estilos para estado activo/seleccionado (ni iluminación, ni fondo contrastante, ni indicador deslizante).<br>• `analytics_dashboard_screen.dart` L177-208: `_jumpToGroup` intenta usar `Scrollable.ensureVisible` con `alignment: 0.08` (un porcentaje arbitrario del viewport que desatiende la altura fija del header sliver de 98px) o un fallback de ratio `(index / length) * maxExtent` que falla estrepitosamente debido a las dispares alturas de las tarjetas.<br>• No existe listener de `ScrollController` que compute las coordenadas globales de las secciones activas ni dispare `Scrollable.ensureVisible` en el chip horizontal correspondiente. |
| **Capturas 3, 4 y 5** | **Modales Inferiores (`DashboardCustomizerModal` y `FinancialSummaryCard`)** | **Doble Barra de Arrastre (`—` sobre `—`) y Doble Sombra Fantasmal:**<br>En la parte superior de los modales aparece un segundo fondo oscuro con sombra y una segunda barra gris de arrastre apilada verticalmente sobre la barra principal. Además, la interacción de arrastre se siente rígida y pesada. | • `dashboard_customizer_modal.dart` L88-107: El modal envuelve su contenido en `InteractiveSheetWrapper`, el cual **ya renderiza su propia decoración de fondo con sombra, esquinas redondeadas y su propio handle reactivo animado** (`showHandle: true`). Adentro, en `child`, se renderiza un segundo `Container` con `borderRadius` y **un segundo drag handle manual** (`Container` de 44x5 con fondo gris). Al anidarse, se pintan 2 drag handles y 2 bordes redondeados superpuestos.<br>• `financial_summary_card.dart` L54-77: Comete un error idéntico pero más severo: anida `InteractiveSheetWrapper` -> `DraggableScrollableSheet` -> `Container` con su propio drag handle manual. Ambos interceptores de gestos compiten entre sí, bloqueando la física de resorte. |
| **Capturas 3 y 4** | **Selector de Presets en `DashboardCustomizerModal`** | **Bug de Desincronización del Preset al Reabrir:**<br>El usuario selecciona `💼 Financiero`, guarda los cambios y la ventana se actualiza. Pero al volver a abrir el modal (Captura 4), el chip que aparece seleccionado en azul es `✨ Completo`, aunque los switches siguen en el estado de `Financiero`. | • `dashboard_customizer_modal.dart` L45: `String _selectedPreset = 'Completo';` se inicializa rígidamente en `'Completo'`. En `initState` jamás se evalúan las secciones activas recibidas en `widget.initialSections` para deducir qué preset coincide con el estado guardado.<br>• Falta una función declarativa `DashboardSectionConfig.detectPreset(sections)` que compare los IDs activos con los conjuntos de cada preset y marque `'Personalizado'` si el usuario alteró los switches individualmente. |
| **Capturas 3 y 4** | **Tarjetas de Secciones en la Lista Reordenable** | **Textos Descriptivos Cortados con Puntos Suspensivos:**<br>Los subtítulos de las secciones se cortan con `...` (`"Ingresos, ganancia neta y marge..."`, `"Ventas, crecimiento simétric..."`, `"Noticias locales, clima, carre..."`), dificultando saber qué incluye cada sección. | • `dashboard_customizer_modal.dart` L255-263: El `ListTile` define `subtitle` con `maxLines: 1`, `overflow: TextOverflow.ellipsis` y un tamaño diminuto de `11sp`. No aprovecha el espacio vertical disponible de la tarjeta. |
| **Captura 5** | **Modal "Análisis Financiero Detallado"** | **Recorte Inferior de la Palabra `"Ingresos"`:**<br>En el gráfico de barras, el texto `"Ingresos"` debajo de la barra azul tiene su borde inferior recortado, luciendo como `"Inaresos"` o letras decapitadas. | • `financial_summary_card.dart` L121-136: En `bottomTitles`, `SideTitles` carece de la propiedad `reservedSize` (usa el valor por defecto de 22dp). El widget de título añade `padding: EdgeInsets.only(top: 8.0)` + `fontSize: 12`, totalizando más de 24dp de altura, por lo que `fl_chart` recorta los trazos descendentes (la parte inferior de la "g" y "p"). |
| **Captura 2** | **Tarjeta del Radar Comercial IA (`commercial_radar_card.dart`)** | **1. Saltos Bruscos en el Scroll:**<br>Al bajar y subir en Estadísticas, la tarjeta recarga y agrega noticias dinámicamente, alterando la altura de la página y desorientando al usuario.<br>**2. Datos Incompletos y Emojis Sucios:**<br>Muestra fuentes genéricas (`Facebook`), sin fecha de publicación ni antigüedad relativa (`"Hace 3 horas"`), y titulares con emojis invasivos (`🔴🔵...👇`).<br>**3. Análisis IA sin Estructura Accionable:**<br>El consejo de la IA es un texto plano sin división clara entre el impacto logístico y las medidas comerciales. | • `commercial_radar_card.dart` L20-29: `_CommercialRadarCardState` no implementa `AutomaticKeepAliveClientMixin`. Cuando la tarjeta sale del viewport, `SliverList` destruye su estado. Al reingresar, se ejecuta `initState()` y `_startRadarStream()` desde cero, vaciando y rellenando la lista en vivo.<br>• Muestra todas las noticias devueltas en la pantalla de estadísticas, provocando una tarjeta kilométrica e inestable.<br>• `commercial_radar_service.dart` L208, L243: `publishedAt` se asigna siempre a `DateTime.now()` en lugar de parsear el `<pubDate>` del RSS. No se extrae la editorial real ni se eliminan emojis tipográficos. |

---

## 🎯 2. PRINCIPIOS RECTORES Y ARQUITECTURA DE SOLUCIÓN

```mermaid
flowchart TD
    subgraph S1 [1. AppBar Compacto & Título 100% Legible]
        A1[Leading Compacto 40dp]
        A2[Título Completo 18.5sp: 'Inteligencia de Negocio']
        A3[FittedBox con escala protegida para 360dp]
        A4[Acciones Esenciales: Personalizar + Ojo + Menú ⋮]
        A5[Menú de Opciones: Actualizar, Ayuda, PDF, CSV]
    end

    subgraph S2 [2. Filas de Chips y Navegación ScrollSpy]
        B1[Fila 1: Filtro de Periodo con ShaderMask]
        B2[Fila 2: Chips Dinámicos según Secciones Activas]
        B3[ScrollSpy: Detección Continua del Área Visible]
        B4[Animación Ola Vibrante / Píldora Deslizante Activa]
        B5[Auto-scroll Horizontal en Chips con ensureVisible]
        B6[Salto Milimétrico exacto: Offset RenderBox - Header 98px + 8px]
    end

    subgraph S3 [3. Limpieza de Modales y Personalización]
        C1[Eliminación del Drag Handle y Borde Redundante en CustomizerModal]
        C2[Eliminación de DraggableScrollableSheet duplicado en FinancialSummaryCard]
        C3[Física 100% Fluida en InteractiveSheetWrapper con 1 Sola Capa]
        C4[fl_chart: reservedSize 34px para 'Ingresos' Impecable]
        C5[Detección Inteligente de Preset Guardado al Abrir Modal]
        C6[Chip 'Personalizado' + Botón 'Activar Todo / Restaurar']
        C7[Subtítulos en 2 líneas legibles a 12.5sp sin elipsis]
    end

    subgraph S4 [4. Reingeniería Radar Comercial IA]
        D1[Estadísticas: Preview Fijo de Máximo 2 Noticias]
        D2[AutomaticKeepAliveClientMixin + Caché en Memoria: Cero Saltos]
        D3[Botón Directo: 'Explorar más noticias y alertas (Abrir Radar IA)']
        D4[Nueva Ventana Completa: CommercialRadarScreen]
        D5[Acceso Directo desde Home en 'Gestión Operativa']
        D6[Parseo Real de Fechas RFC-822 + Antigüedad Relativa]
        D7[Curaduría Editorial Verificada + Limpieza de Emojis]
        D8[Prompt IA Estructurado: Impacto en Ruta vs Medidas Clave]
    end

    S1 --> S2
    S2 --> S3
    S2 --> S4
```

---

## 🏗️ 3. PLAN DE TRABAJO DETALLADO POR FASES (LOOP AUTÓNOMO + ÁRBITRO INTERNO)

---

### FASE 1: Solución Definitiva al Título Cortado en AppBar (`"Inteligencia de Negocio"`) sin Achicar la Letra

#### Diagnóstico Técnico:
En pantallas con ancho de `360dp`, el título `"Inteligencia de Negocio"` requiere entre `195dp` y `210dp` con una tipografía de `18sp - 18.5sp` en negrita. Con 5 iconos individuales en `actions` más el `leading`, el espacio sobrante es de apenas `140dp`, provocando inevitablemente el recorte `"Inteligenci..."`.

#### Arquitectura de Solución:
1. **Jerarquización Inteligente de Acciones en el AppBar:**
   - Mantener como iconos táctiles directos en el AppBar únicamente las 2 acciones de interacción visual inmediata en la pantalla:
     1. **`Personalizar Dashboard`** (`Icons.tune`, 36dp de ancho).
     2. **`Ocultar / Mostrar Saldos`** (`Icons.visibility` / `visibility_off`, 36dp de ancho).
   - Agrupar las acciones complementarias y de exportación en un elegante menú desbordante **`PopupMenuButton` (`Icons.more_vert`)**:
     - `↻ Actualizar datos / Recalcular reporte`
     - `ⓘ Guía del Panel & Consejos` (despliega el modal de información y tips de uso).
     - `📄 Exportar reporte a PDF`
     - `📊 Exportar datos a Excel (CSV)`
2. **Pull-to-Refresh Integrado:**
   - La acción de refrescar no solo estará en el menú desplegable, sino disponible de manera natural envolviendo el `CustomScrollView` en un `RefreshIndicator` conectado a `prov.runStaggeredAnalysis()`.
3. **Maquetación Blindada del Título:**
   - `leadingWidth: 40`, `titleSpacing: NavigationToolbar.kMiddleSpacing` (o `4.0`).
   - El título se envuelve en un `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft)` con estilo `TextStyle(fontSize: 18.5, fontWeight: FontWeight.bold, letterSpacing: -0.3)`.
   - En dispositivos de 360dp o más se mostrará al 100% de tamaño (18.5sp) sin ningún recorte. En dispositivos de ultra-baja resolución (ej. 320dp), `FittedBox` ajustará proporcionalmente fracciones de punto sin mostrar jamás puntos suspensivos `...`.

---

### FASE 2: Refinamiento de Chips Superiores, Animación "Ola Vibrante" (`ScrollSpy`) y Salto Milimétrico a Secciones

#### Diagnóstico Técnico:
1. La segunda fila de chips (`_buildQuickJumpChip`) es un `ListView` estático sin estado seleccionado ni reactividad ante el scroll de la ventana.
2. Los chips están desconectados de la configuración del usuario: si el usuario desactiva `Radar Comercial` o reordena sus tarjetas, la fila muestra los mismos 4 chips en el mismo orden rígido.
3. El cálculo de salto en `_jumpToGroup` usa `Scrollable.ensureVisible` con `alignment: 0.08` o un fallback de ratio que no descuenta la altura del header persistente (`98px`), aterrizando fuera de foco.

#### Arquitectura de Solución:
1. **Adaptación Dinámica a Secciones Activas del Usuario:**
   - Crear una propiedad calculada `List<String> get _activeCategoryGroups`:
     - Itera sobre las secciones visibles del usuario (`_sections.where((s) => s.isVisible)`).
     - Extrae los `categoryGroup` únicos preservando el orden exacto configurado por el usuario.
     - Mapea cada grupo a su etiqueta e icono:
       - `'resumen'` ➔ `"📊 Resumen"`
       - `'graficos'` ➔ `"📈 Gráficos"`
       - `'inventario'` ➔ `"📦 Inventario"`
       - `'radar'` ➔ `"📰 Radar Comercial"`
     - Si una categoría completa está oculta por el usuario, su chip desaparece automáticamente de la fila. Si el usuario reordena las secciones, los chips adoptan el nuevo orden.
2. **Sistema de `ScrollSpy` Reactivo con Animación "Ola Vibrante":**
   - Incorporar en el estado `_activeGroup` (identificador del grupo visible actualmente en el viewport).
   - En `_onScroll`:
     - Para cada grupo activo, identificar la primera sección visible perteneciente a ese grupo.
     - Obtener la posición vertical relativa de su `RenderBox` respecto al viewport de la pantalla.
     - La sección cuya posición se encuentre inmediatamente bajo la cabecera fija pinned (offset `y <= headerHeight + 24.0`) se determina como la sección activa actual.
     - Si `_activeGroup` cambia, actualizar el estado con micro-transición y ejecutar `Scrollable.ensureVisible` sobre la `GlobalKey` del chip horizontal correspondiente para que la fila de chips auto-deslice y el chip activo **nunca quede cortado en los bordes**.
3. **Diseño de la Píldora Deslizante / Iluminación Activa:**
   - El chip activo se ilumina con un degradado moderno azul eléctrico / cyan (`Colors.blueAccent` a `Colors.indigoAccent`), con texto blanco en negrita y sutil sombra perimetral.
   - Los chips inactivos mantienen una apariencia sutil translúcida con buen contraste.
4. **Salto Milimétrico Preciso (`_jumpToGroup`):**
   - Al tocar un chip:
     - Asignar inmediatamente `_activeGroup = group` para desplazar la ola visual del chip.
     - Localizar la `GlobalKey` de la primera tarjeta visible de ese grupo.
     - Calcular el offset exacto:
       ```dart
       final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
       if (renderBox != null) {
         final position = renderBox.localToGlobal(Offset.zero, ancestor: context.findRenderObject());
         final targetOffset = (_scrollController.offset + position.dy - 106.0) // 98px header + 8px margen limpio
             .clamp(0.0, _scrollController.position.maxScrollExtent);
         _scrollController.animateTo(
           targetOffset,
           duration: const Duration(milliseconds: 450),
           curve: Curves.easeInOutCubic,
         );
       }
       ```
     - Configurar `cacheExtent: 3500` en el `CustomScrollView` para garantizar que todos los widgets de sección mantengan su `RenderBox` instanciado y accesible en memoria para el cálculo milimétrico instantáneo.

---

### FASE 3: Corrección del Bug de "Doble Sombra / Doble Barra" en Modales y Perfeccionamiento de `"Personalizar Dashboard"`

#### Diagnóstico Técnico:
1. En `dashboard_customizer_modal.dart` y `financial_summary_card.dart`, se añade un segundo `Container` con bordes redondeados y un drag handle manual adentro del `InteractiveSheetWrapper`, produciendo la duplicación visual `—` sobre `—` y la doble sombra.
2. En `dashboard_customizer_modal.dart`, `_selectedPreset` se reinicia a `'Completo'` en cada apertura, ignorando la configuración guardada.
3. Los textos descriptivos de las tarjetas reordenables usan `maxLines: 1` a `11sp`, truncándose con `...`.
4. En el modal financiero, `SideTitles` carece de `reservedSize: 34`, recortando la palabra `"Ingresos"`.

#### Arquitectura de Solución:
1. **Unificación Estricta a 1 Sola Capa Limpia en los Modales:**
   - **`DashboardCustomizerModal`:**
     - Eliminar el drag handle interno manual (`Container(margin: EdgeInsets.only(top: 12), width: 44, height: 5, ...)`).
     - Eliminar el `Container` duplicado con `borderRadius` redundante; delegar toda la estructura, esquinas redondeadas y física de descarte a `InteractiveSheetWrapper`.
     - Establecer `backgroundColor: Colors.transparent` en `showModalBottomSheet`.
   - **`FinancialSummaryCard` (Modal Análisis Financiero):**
     - Eliminar la anidación conflictiva de `DraggableScrollableSheet` dentro de `InteractiveSheetWrapper`.
     - Utilizar directamente `InteractiveSheetWrapper` con título `"Análisis Financiero Detallado"`, icono `Icons.analytics`, y su cuerpo `ListView` interno con física suave de rebote.
     - Eliminar el drag handle manual secundario.
   - **Corrección de `"Ingresos"` en `FlChart`:**
     - En `financial_summary_card.dart`, configurar `bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34, ...))`. El texto `"Ingresos"` tendrá espacio vertical holgado sin recorte.
2. **Detección Dinámica del Preset Guardado al Abrir el Modal:**
   - Implementar `DashboardSectionConfig.detectPreset(List<DashboardSectionConfig> sections)`:
     - Si todas las secciones están visibles y en orden base ➔ `'Completo'`.
     - Si los IDs visibles coinciden exactamente con la lista de `'Financiero'` ➔ `'Financiero'`.
     - Si coinciden con `'Operativo / Stock'` ➔ `'Operativo / Stock'`.
     - Si coinciden con `'Comercial & Radar'` ➔ `'Comercial & Radar'`.
     - Si el usuario creó una combinación propia ➔ `'Personalizado'`.
   - En `DashboardCustomizerModal.initState()`, invocar `_selectedPreset = DashboardSectionConfig.detectPreset(_sections);`.
   - Incluir en la barra horizontal deslizable el chip **`"🎨 Personalizado"`** (se ilumina cuando el estado actual no coincide con ninguno de los presets predefinidos).
   - Mantener la fila en **1 sola línea horizontal deslizable** (sin ocupar espacio vertical) y agregar un botón de acción rápida `"Activar Todo / Restaurar"`.
3. **Rediseño de las Tarjetas Reordenables en `DashboardCustomizerModal`:**
   - Cambiar `maxLines: 2` y `overflow: TextOverflow.visible` en el subtítulo.
   - Incrementar la fuente del subtítulo a `12.5sp` con color de alto contraste (`Color(0xFF94A3B8)` en modo oscuro, `Color(0xFF64748B)` en modo claro).
   - Configurar `title` a `14sp` con `FontWeight.w600`.
   - Ninguna descripción de sección volverá a truncarse con `...`.

---

### FASE 4: Reingeniería del Radar Comercial IA (Estabilidad en Estadísticas + Ventana Dedicada + Acceso desde Home)

#### Diagnóstico Técnico:
1. `CommercialRadarCard` recrea su estado y vuelve a consultar la red en cada desplazamiento vertical por falta de `AutomaticKeepAliveClientMixin`.
2. Muestra todas las noticias devueltas dentro de la pantalla de Estadísticas, produciendo desplazamientos bruscos en la ventana.
3. El servicio no parsea las fechas RSS reales ni extrae la editorial periodística verificada; los titulares contienen emojis ruidosos y el análisis de la IA carece de estructura por puntos de impacto logístico y medidas prácticas.
4. No existe una pantalla dedicada ni un acceso directo desde la "Gestión Operativa" del Home.

#### Arquitectura de Solución:
1. **Blindaje de la Tarjeta en `analytics_dashboard_screen.dart` (`CommercialRadarCard`):**
   - Incorporar `with AutomaticKeepAliveClientMixin` con `wantKeepAlive => true` en `_CommercialRadarCardState`.
   - Implementar caché estática en memoria en `CommercialRadarService` para que el streaming solo se ejecute una vez por sesión (o al presionar forzar recarga).
   - **Límite Estricto de 2 Noticias:**
     - En el dashboard de Estadísticas, la tarjeta solo renderizará las **primeras 2 noticias destacadas** con una estructura visual estable y compacta (cero saltos de altura al hacer scroll).
   - **Botón Llamativo de Apertura:**
     - Al pie de las 2 noticias, colocar un botón destacado:
       `"📰 Explorar más noticias y alertas comerciales (Abrir Radar IA)"` con icono de flecha hacia adelante y efecto visual interactivo.
2. **Creación de la Pantalla Completa Dedicada (`CommercialRadarScreen`):**
   - Crear el archivo `lib/features/analytics/screens/commercial_radar_screen.dart`.
   - **Componentes y Capacidades:**
     - `AppBar` con título `"Radar Comercial IA"`, subtítulo dinámico con región seleccionada y botón de recarga manual `↻`.
     - Barra superior de **Enfoque Geográfico** con selector de región (`Talara / Piura`, `Región Norte`, `Todo el Perú`, regiones predefinidas y opción personalizada con diálogo modal).
     - Fila horizontal de filtros por categoría:
       `[✓ Todas]` `[📍 Mi Región]` `[🌦️ Clima y Rutas]` `[⚖️ Leyes y SUNAT]` `[🚛 Proveedores y Abastecimiento]` `[📅 Fechas y Campañas]`.
     - Lista completa de noticias con paginación controlada ("Cargar más noticias") que preserva la posición del scroll de lectura.
     - Soporte para `RefreshIndicator` (Pull-to-refresh).
     - Tarjetas expansibles de noticia con imagen o banner ilustrativo temático, enlace directo a la fuente oficial vía `url_launcher`.
3. **Integración con la "Gestión Operativa" del Home (`smart_action_grid.dart`):**
   - Registrar la nueva tarjeta de acción `'commercial_radar'` en `_getDefaultCardIds()` y `_getCardDefinitions`:
     - `id: 'commercial_radar'`
     - `title: "Radar IA"`
     - `subtitle: "Noticias y Alertas"`
     - `icon: Icons.radar` (o `Icons.satellite_alt_rounded`)
     - `colorBuilder: (isDark) => isDark ? Colors.cyan[300]! : Colors.cyan[700]!`
     - `onTapBuilder: (ctx, isDark) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const CommercialRadarScreen()))`
   - Visible inmediatamente para todos los comerciantes en la cuadrícula de acciones rápidas del `HomeScreen`.
4. **Parseo Real de Fechas, Curaduría Editorial y Limpieza de Emojis:**
   - **Parseo de Fechas:** Parsear el tag `<pubDate>` del RSS (formato RFC 822 / RFC 1123, ej. `Sat, 24 Oct 2026 06:15:00 GMT`) a `DateTime`.
   - **Antigüedad Relativa:** Formatear como `"24 oct. 2026 • Hace 3 horas"` (o `"Hace 45 min"`, `"Ayer"`).
   - **Curaduría Editorial:** Limpiar fuentes como `"Facebook"` extrayendo el medio real a partir del titular (ej. `"El Tiempo Piura"`, `"RPP Noticias"`, `"Gestión"`, `"Andina"`, `"La República"`, `"SENAMHI"`, `"SUNAT"`).
   - **Limpieza de Emojis:** Sanitizar los titulares RSS eliminando emojis invasivos (`🔴`, `🔵`, `👇`, `🚨`, `⚠️`) para proyectar un acabado profesional y pulcro.
   - **Ampliación de Consultas de Búsqueda:**
     - Enriquecer los términos de búsqueda en Google News Perú para cubrir: comercio minorista/mayorista, estado de carreteras y fletes de carga, lluvias / Fenómeno de El Niño en el norte, normativas SUNAT/MYPE, distribuidores y campañas comerciales.
5. **Potenciación del Análisis IA Estructurado:**
   - Actualizar el modelo `CommercialNewsItem` para estructurar la síntesis de Gemini en dos bloques accionables:
     1. **`Impacto en tu Negocio / Ruta:`** Explica concretamente las implicancias en tiempos de llegada de mercadería, fletes, afluencia de compradores o normativas tributarias.
     2. **`Medidas y Recomendaciones Clave:`** Lista acciones preventivas o comerciales sugeridas (adelantar pedidos, verificar stock de seguridad, armar combos).

---

### FASE 5: Batería de Pruebas Automatizadas y Certificación Adversarial

#### Diagnóstico Técnico:
Es indispensable garantizar que las nuevas funcionalidades, la reactividad del `ScrollSpy`, el cálculo del offset milimétrico, la estabilidad del caché en memoria y la nueva pantalla `CommercialRadarScreen` cuenten con cobertura automatizada completa y sin regresiones sobre los tests existentes.

#### Protocolo de Pruebas:
1. **Pruebas Unitarias de Modelos y Lógica:**
   - `DashboardSectionConfig.detectPreset`: Valida la detección correcta de presets (`Completo`, `Financiero`, `Operativo / Stock`, `Comercial & Radar`, `Personalizado`).
   - `CommercialNewsItem`: Valida el parseo de fechas RFC-822, cálculo de tiempo transcurrido (`timeAgoFormatted`) y sanitización de emojis en titulares.
   - `CommercialRadarService`: Valida la extracción de fuentes oficiales y el uso de caché en memoria para evitar recargas innecesarias.
2. **Pruebas de Widgets y UI:**
   - `AnalyticsDashboardScreen`: Verifica que el título `"Inteligencia de Negocio"` no se trunque en pantallas de 360dp, que solo existan los botones esenciales en el AppBar y que las acciones secundarias figuren en el menú desbordante.
   - Verificación de la fila de chips dinámicos: oculta chips de categorías inactivas y refleja el orden configurado por el usuario.
   - Modales limpios: Verifica que `DashboardCustomizerModal` y `FinancialSummaryCard` no tengan drag handles duplicados ni anidamientos de `DraggableScrollableSheet` conflictivos.
   - `CommercialRadarCard`: Verifica que en Estadísticas se rendericen como máximo 2 noticias y que exista el botón para abrir `CommercialRadarScreen`.
   - `SmartActionGrid`: Verifica que la tarjeta `'commercial_radar'` esté presente en la lista por defecto y navegue a `CommercialRadarScreen`.
3. **Ejecución y Verificación:**
   - Ejecución de `flutter test` garantizando 100% de pruebas pasando sin advertencias ni regresiones.

---

## 📋 4. MATRIZ DE ARCHIVOS AFECTADOS Y COMPONENTES A CREAR

| Archivo | Tipo de Intervención | Propósito Principal |
| :--- | :--- | :--- |
| `lib/features/analytics/screens/analytics_dashboard_screen.dart` | **Refactorización UI/UX** | AppBar con título 100% visible a 18.5sp, menú desbordante optimizado, Fila 2 de chips con `ScrollSpy` dinámico ("Ola Vibrante"), auto-scroll horizontal y salto milimétrico con deducción exacta del header fijo (98px + 8px). |
| `lib/features/analytics/widgets/dashboard/dashboard_customizer_modal.dart` | **Corrección UI & Lógica** | Eliminación de drag handle y contenedor duplicados, detección automática del preset activo al abrir (`detectPreset`), chip `"Personalizado"`, subtítulos en 2 líneas a 12.5sp sin truncamiento y botón "Restaurar". |
| `lib/features/analytics/widgets/dashboard/financial_summary_card.dart` | **Corrección UI & Gráfico** | Eliminación del `DraggableScrollableSheet` duplicado y drag handle redundante; corrección de `reservedSize: 34` en `bottomTitles` para que la palabra `"Ingresos"` no se recorte. |
| `lib/features/analytics/models/dashboard_section_config.dart` | **Nueva Lógica Declarativa** | Método estático `detectPreset(...)` para sincronizar el estado visual de los chips con la configuración de secciones guardada. |
| `lib/features/analytics/widgets/dashboard/commercial_radar_card.dart` | **Estabilización & Preview** | Incorporación de `AutomaticKeepAliveClientMixin`, tope de máximo 2 noticias estables, eliminación de saltos de altura y botón CTA para abrir la ventana completa. |
| `lib/features/analytics/screens/commercial_radar_screen.dart` | **NUEVA PANTALLA** | Ventana completa dedicada para el Radar Comercial IA con filtros de categorías, selector de región, paginación controlada, pull-to-refresh y apertura de noticias originales. |
| `lib/features/analytics/services/commercial_radar_service.dart` | **Mejora del Servicio IA** | Parseo real de fechas RSS, curaduría de editoriales verificadas, eliminación de emojis sucios, ampliación de queries de búsqueda y prompt IA estructurado con impacto en ruta y medidas concretas. |
| `lib/features/analytics/models/commercial_radar_model.dart` | **Refinamiento del Modelo** | Campos de impacto logístico y medidas sugeridas, parseo de fechas RFC-822 y getter para tiempo relativo (`"Hace 3 horas"`). |
| `lib/core/widgets/home/smart_action_grid.dart` | **Integración Home** | Nueva tarjeta de acción rápida del Radar Comercial IA en la cuadrícula de `"Gestión Operativa"` con navegación a `CommercialRadarScreen`. |
| `test/business_intelligence_and_commercial_radar_reengineering_test.dart` | **Ampliación de Pruebas** | Tests unitarios y de widgets para todas las nuevas capacidades, garantizando cero regresiones. |

---

## ⚖️ 5. CRITERIOS DE ACEPTACIÓN ADVERSARIAL (CHECKLIST DE CERTIFICACIÓN)

- [ ] **Título del AppBar:** El texto `"Inteligencia de Negocio"` se visualiza 100% completo, sin `...`, con tipografía jerárquica de `18.5sp` en pantallas de `360dp`.
- [ ] **AppBar Limpio:** Los iconos de acción en el AppBar están optimizados (`Personalizar`, `Ojo`, `Menú ⋮`); el menú incluye refrescar, exportar PDF/CSV y guía del panel.
- [ ] **Ola Vibrante en Chips:** La segunda fila de chips ilumina el chip activo en tiempo real conforme el usuario navega verticalmente por la pantalla (`ScrollSpy`).
- [ ] **Chips Dinámicos:** Si el usuario oculta una categoría en la personalización, su chip desaparece; si reordena las secciones, los chips siguen el orden configurado.
- [ ] **Auto-scroll Horizontal:** El chip activo en la segunda fila se auto-centra suavemente para no quedar cortado a la derecha ni a la izquierda.
- [ ] **Salto Milimétrico:** Al presionar cualquier chip de salto rápido, la pantalla se desplaza y aterriza exactamente en el título de la sección elegida, descontando con precisión matemática la cabecera fija de 98px + 8px de margen.
- [ ] **Modales sin Doble Handle:** Ningún modal (`Personalizar Dashboard`, `Análisis Financiero Detallado`, etc.) presenta doble barra gris ni doble sombra en su parte superior.
- [ ] **Gráfico Financiero Limpio:** La palabra `"Ingresos"` en el gráfico de barras del modal financiero no sufre ningún recorte inferior en sus trazos descendentes.
- [ ] **Preset Guardado Fiel:** Al seleccionar un preset (ej. `Financiero`) y reabrir el modal, se ilumina el chip correspondiente; si hay cambios manuales, se ilumina `🎨 Personalizado`.
- [ ] **Subtítulos Legibles:** Las tarjetas de secciones en la personalización muestran sus subtítulos en 2 líneas completas a 12.5sp sin puntos suspensivos `...`.
- [ ] **Estadísticas Estables (0 Saltos):** La tarjeta del Radar Comercial en Estadísticas muestra como máximo 2 noticias estables y nunca vuelve a recargar ni saltar al hacer scroll vertical (`AutomaticKeepAliveClientMixin`).
- [ ] **Nueva Ventana Completa:** Se crea `CommercialRadarScreen` con navegación fluida, filtros de categorías, cambio de región y todas las noticias analizadas.
- [ ] **Acceso desde Home:** La nueva tarjeta del Radar Comercial IA aparece en la cuadrícula de `"Gestión Operativa"` del Home y abre la pantalla dedicada.
- [ ] **Noticias Enriquecidas:** Cada tarjeta de noticia muestra la fecha de publicación con tiempo transcurrido (`"24 oct. 2026 • Hace 3 horas"`), editorial verificada, titular limpio de emojis y análisis IA dividido en impacto y medidas clave.
- [ ] **Calidad de Código y Tests:** Todos los tests automatizados pasan con éxito y `flutter analyze` reporta 0 errores críticos.
