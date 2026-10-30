# PLAN MAESTRO: PULIDO DE OPERACIONES FINANCIERAS, CATÁLOGO DE VENTAS Y SANEAMIENTO FORENSE DE MESA DE TRABAJO

**Documento:** `analisis_proyecto/PLAN_PULIDO_FINANZAS_CATALOGO_Y_MESA_TRABAJO.md`  
**Fecha:** 28 de Octubre de 2026  
**Versión:** 1.0 — Especificación Técnica Definitiva (Mobile Awards Quality)  
**Estado:** Esperando Aprobación de Plan de Trabajo (Paso 1: Diagnóstico e Inspección Forense)  
**Metodología:** Loop Autónomo + Árbitro Adversarial (Test-Driven, Zero-Regressions & Zero-Overflows)

---

## 1. RESUMEN EJECUTIVO Y OBJETIVOS ESTRATÉGICOS

### 1.1. Contexto Global
A partir de la inspección detallada de las 5 capturas en dispositivos móviles físicos y de la auditoría estricta del código fuente en los módulos de **Operaciones Financieras** (`client_finance_actions_modal.dart`, `interactive_sheet_wrapper.dart`), **Catálogo de Ventas** (`catalog_screen.dart`, `catalog_header.dart`, `catalog_counter_bar.dart` en `catalog_filter_header.dart`, `catalog_sort_modal.dart`) y **Mesa de Trabajo** (`workbench_screen.dart`, `quotation_card.dart`, `quotation_detail_screen.dart`, `manual_quotation_screen.dart`, `quotation_service.dart`), se identificaron defectos de diseño visual, problemas de ergonomía táctil y una anomalía crítica de integridad en base de datos.

### 1.2. Problemas Críticos a Resolver
1. **Modal `Operaciones Financieras` (Imágenes 1 y 2):**
   * **Chips de Motivo/Detalle en 3 filas verticales:** Ocupan espacio innecesario; deben pasar a una sola fila horizontal con desplazamiento fluido (`SingleChildScrollView` horizontal + `BouncingScrollPhysics`).
   * **Selección rígida no desmarcable:** El chip seleccionado no puede desmarcarse al volver a tocarlo (falta toggle real) y no se sincroniza reactivamente cuando el usuario escribe o borra en el campo de texto.
   * **Superposición en Cronograma:** El indicador de día hábil ajustado (`↪ Día hábil`) se monta y colisiona físicamente sobre el botón `⏭ +1d` y el monto en soles en pantallas de 320px–360px.
   * **Sobrecarga de información:** La etiqueta redundante `4 activos` / `7 activos` en la cabecera de días permitidos sobrecarga la interfaz.
   * **Iconografía discordante:** El banner informativo duplica iconos (`✨ ✨` y `🔄 🔄`) por mezclar un `Icon` de Flutter con emojis en el string, y los chips de presets usan emojis de colores desentonados (`🚫`, `💼`, `📅`).
   * **Cierre táctil bloqueado:** El modal no se puede cerrar arrastrando hacia abajo desde su cabecera superior porque se desactivó globalmente el drag para proteger el scroll interno.
2. **Catálogo de Ventas (Imágenes 3 y 4):**
   * **Botón de Ordenamiento Duplicado:** Aparece tanto en la fila del buscador (`[A↓Z A - Z]`) como en la barra de conteo (`[🔤 A - Z v]`). El de la barra de búsqueda reduce el ancho disponible y trunca el placeholder.
   * **Iconos y Emojis en Ordenamiento:** Se utiliza el emoji azul `🔤` y otros emojis en el botón y modal de ordenamiento en lugar de iconografía vectorial ejecutiva.
   * **Tarjeta Amarilla de "Modo Tienda":** El banner *"🛡️ Modo Tienda: Costos y márgenes ocultos para atención directa al cliente"* genera desconfianza en el cliente si este mira la pantalla del vendedor.
   * **Ayuda Contextual Incompleta:** El modal de información `ⓘ Catálogo de Ventas` no explica para qué sirve el Modo Tienda con tacto comercial.
3. **Mesa de Trabajo — Registro Fantasma `# Sin Cliente - #1` (Imagen 5):**
   * **Registro corrupto huérfano:** Existe una cotización con 0 ítems, S/ 0.00, estado `Borrador`, origen `Manual`, fecha 22/08/2026 y un icono de chincheta `📌`, sin cliente asignado.
   * **Bloqueo para eliminar:** Al abrirse muestra la pantalla de Detalle con 0 productos, pero la barra inferior solo ofrece opciones de venta/edición; no permite eliminarla limpiamente y cualquier intento de borrado en SQLite falla silenciosamente o queda bloqueado.

---

## 2. DIAGNÓSTICO FORENSE Y EVIDENCIA VISUAL EN CÓDIGO (ARCHIVOS Y LÍNEAS EXACTAS)

### 2.1. Operaciones Financieras: Chips de Motivo / Detalle y Toggle
* **Archivo:** `app_movil/lib/features/smart_quotation/widgets/crm/client_finance_actions_modal.dart`
* **Líneas exactas:** 1580–1615
* **Código actual defectuoso:**
  ```dart
  Wrap(
    spacing: 8,
    runSpacing: 8,
    children: _motivosSug.map((motivo) {
      final isSelected = _noteCtrl.text == motivo;
      return ChoiceChip(
        label: Text(motivo),
        selected: isSelected,
        onSelected: (val) {
          if (val) { // ❌ SOLO ACTÚA SI val ES TRUE. Si ya estaba seleccionado, val es false y NO HACE NADA.
            _noteCtrl.text = motivo;
            FocusScope.of(context).unfocus();
            _saveCurrentDraft();
            setState(() {});
          }
        },
        ...
  ```
* **Causa Raíz:**
  1. `Wrap` provoca que los 5 chips se dividan en 3 filas verticales, alargando innecesariamente el scroll del modal.
  2. `if (val)` ignora el evento cuando `val == false` (cuando el usuario vuelve a presionar el chip seleccionado). Nunca vacía el campo ni deselecciona el chip.
  3. `_noteCtrl.addListener(_saveCurrentDraft);` en la línea 194 guarda el borrador pero **no llama a `setState(() {})`**, por lo que al tipear o borrar texto en el `TextField`, los chips no actualizan su estado visual `isSelected` en tiempo real.

### 2.2. Operaciones Financieras: Colisión en Cronograma, Iconos Duplicados y `X activos`
* **Archivo:** `app_movil/lib/features/smart_quotation/widgets/crm/client_finance_actions_modal.dart`
* **Líneas exactas:**
  * **Etiqueta redundante (Líneas 1905–1912):**
    ```dart
    Text(
      "${7 - _excludedWeekdays.length} activos",
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.orange,
      ),
    ),
    ```
  * **Emojis en Presets (Líneas 1948–2015):**
    ```dart
    _buildPresetChip(label: "🚫 Omitir Domingos", ...)
    _buildPresetChip(label: "💼 Solo Lun - Vie", ...)
    _buildPresetChip(label: "📅 Todos los días", ...)
    ```
  * **Doble Icono en Feedback (Líneas 669–682 y 2088–2118):**
    En las líneas 669–682, el string se construye con emojis: `"✨ Fechas actualizadas..."`, `"🔄 Fechas restauradas..."`. Luego, en la línea 2090:
    ```dart
    Icon(
      _scheduleUpdateFeedback!.contains("restauradas")
          ? Icons.sync_rounded
          : Icons.auto_awesome_rounded,
      size: 15,
      ...
    ),
    const SizedBox(width: 8),
    Expanded(child: Text(_scheduleUpdateFeedback!)) // ❌ Trae otro "✨ " o "🔄 ", viéndose "✨ ✨" o "🔄 🔄"
    ```
  * **Superposición de Fecha, Badge `↪ Día hábil`, Botón `+1d` y Monto (Líneas 2167–2250):**
    ```dart
    Expanded(
      child: InkWell(
        onTap: () => _editInstallmentDate(i),
        child: Row(
          children: [
            Text(_formatDateSpanish(dueDate), ...),
            const SizedBox(width: 4),
            Icon(Icons.edit_calendar, size: 15, ...),
            if (_installmentShiftReasons.containsKey(cuota.installmentNumber)) ...[
              const SizedBox(width: 6),
              Container(
                child: Text(_installmentShiftReasons[cuota.installmentNumber]!), // "↪ Día hábil"
              ),
            ],
          ],
        ),
      ),
    ),
    Tooltip(
      child: InkWell(
        child: Container(child: Text("+1d")),
      ),
    ),
    Text(AppCurrency.format(cuota.amount))
    ```
* **Causa Raíz:** En pantallas de 320px–360px de ancho, el `Row` horizontal dentro de `Expanded` agrupa el texto largo de fecha (`"Sáb, 28/11/2026"`), el icono de calendario y el badge de ajuste en una sola línea inflexible. Esto desborda el ancho disponible y aplasta el badge directamente sobre el botón `+1d`.

### 2.3. Modal `InteractiveSheetWrapper`: Bloqueo del Drag de Cierre Superior
* **Archivos:**
  * `app_movil/lib/core/widgets/interactive_sheet_wrapper.dart` (Líneas 131–160, 334–366)
  * `app_movil/lib/features/smart_quotation/widgets/crm/client_finance_actions_modal.dart` (Líneas 1103–1123)
* **Código actual en `client_finance_actions_modal.dart`:**
  ```dart
  return InteractiveSheetWrapper(
    enableDragToDismiss: false, // ❌ Desactiva TODO el drag vertical
    maintainFixedHeightOnKeyboard: true,
    maxHeightFactor: 0.92,
    applyEffectiveBottomPadding: false,
    showHandle: false, // ❌ Oculta el handle del wrapper y dibuja uno manual sin detector de gestos
    ...
  ```
* **Causa Raíz:** Para evitar que el scroll vertical de la lista de cuotas entrara en conflicto con el arrastre del modal, se colocó `enableDragToDismiss: false`. Pero al hacerlo, se anuló también el gesto de cierre en la barra superior. Además, el handle y el header se dibujaron manualmente dentro de `child: Column(...)` sin ningún `GestureDetector` enlazado a la animación de desplazamiento del modal.

### 2.4. Catálogo: Botón de Ordenar Duplicado y Tarjeta Amarilla de Tienda
* **Archivos:**
  * `app_movil/lib/core/widgets/catalog_header.dart` (Líneas 161–194)
  * `app_movil/lib/features/catalog/screens/catalog/widgets/catalog_filter_header.dart` (Líneas 102–153)
  * `app_movil/lib/features/catalog/screens/catalog/widgets/catalog_sort_modal.dart` (Líneas 89–93)
  * `app_movil/lib/features/catalog/screens/catalog/catalog_screen.dart` (Líneas 566–604, 659–680, 809)
* **Código actual en `catalog_header.dart` (Líneas 161–194):**
  Un botón completo de ordenamiento `InkWell` con `provider.sortOption.icon` y `provider.sortOption.shortLabel` está incrustado en la misma fila del `TextField` de búsqueda, quitándole más de 80px de ancho y haciendo que el texto `"Buscar producto, marca..."` se corte en `"Buscar producto, m..."`.
* **Código actual en `catalog_filter_header.dart` (Línea 132):**
  Muestra `"${provider.sortOption.emoji} ${provider.sortOption.shortLabel}"`, inyectando el emoji `🔤` en la barra del contador.
* **Código actual en `catalog_screen.dart` (Líneas 566–604 y 809):**
  `_buildStoreModeBanner` renderiza la tarjeta amarilla fija con el texto explícito de costos y márgenes ocultos, alarmando innecesariamente a los clientes si estos ven la pantalla.

### 2.5. Mesa de Trabajo: Registro Fantasma `# Sin Cliente - #1` (0 Ítems, S/ 0.00) y Bloqueo de Eliminación
* **Archivos:**
  * `app_movil/lib/features/smart_quotation/services/quotation_service.dart` (Líneas 461–538, 712–726)
  * `app_movil/lib/features/smart_quotation/providers/workbench_provider.dart` (Líneas 230–270, 485–507)
  * `app_movil/lib/features/smart_quotation/screens/quotation_detail_screen.dart` (Líneas 403–445, 989–1025)
  * `app_movil/lib/features/smart_quotation/widgets/quick_actions_bottom_sheet.dart` (Líneas 176–187, 369–412, 472–517)
  * `app_movil/lib/features/smart_quotation/widgets/quotation_card.dart` (Líneas 144, 162–166)
  * `app_movil/lib/core/database/local_db.dart` (Líneas 335, 343)
* **Causa Raíz de Creación de `# Sin Cliente - #1`:**
  1. `QuotationService.saveManualQuotation`: No verifica `if (items.isEmpty)`. Si se llamaba con una lista vacía de productos (por ejemplo, autoguardado temprano, pruebas previas del 22/08/2026 o inicializaciones), creaba una fila en `smart_quotations` con `total_amount = 0.0`, `status = 'DRAFT'` y 0 filas hijas en `smart_quotation_items`.
  2. Al no tener `client_name`, `QuotationCard` ejecutaba su fallback: `quotation.clientName ?? "Sin Cliente - #${quotation.displayId}"`, resultando en `# Sin Cliente - #1`.
  3. El icono de chincheta `📌` en `QuotationCard` (línea 164) se mostraba simplemente porque `quotation.notas != null && quotation.notas!.isNotEmpty`, haciendo creer que estaba "fijada" cuando en realidad era solo una nota interna residual.
* **Causa Raíz del Bloqueo para Eliminar:**
  1. **Ausencia de botón de borrado en la pantalla Detalle:** Cuando el usuario abre `# Sin Cliente - #1`, entra a `QuotationDetailScreen`. La barra inferior (`QuotationActionButtons`) solo muestra `[Editar]`, `[PDF]`, `[WhatsApp]` y `[VENDER (S/ 0.00)]`. No existe botón de eliminar en la barra de acciones ni en el cuerpo vacío. Si presiona `[Editar]`, `ManualQuotationScreen` frena el guardado diciendo *"La lista está vacía"* y tampoco ofrece botón de eliminación.
  2. **Bloqueo Transaccional / Foreign Key en SQLite:** En `local_db.dart` (línea 343), la tabla `ventas` tiene `FOREIGN KEY (cotizacion_id) REFERENCES smart_quotations (id)`. Si algún registro de ventas (activo, de prueba o anulado) mantenía una referencia a ese `id`, el comando `await db.delete('smart_quotations', where: 'id = ?')` fallaba con `FOREIGN KEY constraint failed`. En `WorkbenchProvider.deleteQuotation`, el error era atrapado en `catch` y silenciado, retornando `false`, mostrando en el diálogo *"El servidor bloqueó la eliminación"* y dejando el ítem en pantalla sin sanear.

---

## 3. ARQUITECTURA DE SOLUCIÓN Y DISEÑO TÉCNICO

```
+----------------------------------------------------------------------------------------------------+
|                                    ARQUITECTURA DE PULIDO Y BLINDAJE                              |
+----------------------------------------------------------------------------------------------------+
|                                                                                                    |
|  1. MODAL OPERACIONES FINANCIERAS                                                                  |
|     [ InteractiveSheetWrapper ]                                                                     |
|       +-- Cabecera con Drag Detector Exclusivo (dragDistance > 90px / vel > 380 px/s)             |
|       +-- Chips Motivo/Detalle: SingleChildScrollView horizontal + Toggle desmarcable + Sync Real  |
|       +-- Cronograma de Cuotas: Layout de 2 líneas (Fecha + Sub-badge 'Día hábil') -> CERO COLISIÓN|
|       +-- Eliminación de 'X activos' + Un solo icono vectorial en Feedback (sin emojis duplicados)|
|                                                                                                    |
|  2. CATÁLOGO DE VENTAS                                                                             |
|     [ CatalogHeader ]                                                                              |
|       +-- Buscador a ancho completo (sin botón de ordenar duplicado al lado del filtro)             |
|     [ CatalogCounterBar ]                                                                          |
|       +-- Único punto de ordenamiento con icono vectorial (Icons.sort_by_alpha_rounded)            |
|     [ CatalogSortModal ]                                                                           |
|       +-- Acabado Mobile Awards: Iconos vectoriales estilizados en lugar de emojis                 |
|     [ Modo Tienda ]                                                                                |
|       +-- Eliminación total del banner amarillo alarmante                                          |
|       +-- Inclusión de explicación sutil y elegante en modal de ayuda contextual [i]               |
|                                                                                                    |
|  3. MESA DE TRABAJO Y INTEGRIDAD FORENSE                                                           |
|     [ Saneamiento Automático SQLite ]                                                              |
|       +-- Purga transparente de cotizaciones fantasma (0 ítems + S/ 0.00 + DRAFT huérfano)        |
|     [ Blindaje de Guardado ]                                                                       |
|       +-- Validación estricta items.isNotEmpty en QuotationService y WorkbenchProvider             |
|     [ Eliminación Total y Desfijado Garantizado ]                                                  |
|       +-- Desvinculación segura de FK cotizacion_id en ventas antes de borrar                      |
|       +-- Botón 'Eliminar Borrador' en barra inferior de QuotationDetailScreen y empty state       |
|       +-- Icono de notas desacoplado de concepto de pin (con tooltip y opción de limpieza)         |
+----------------------------------------------------------------------------------------------------+
```

---

## 4. PLAN DE TRABAJO PASO A PASO (FASES DETALLADAS)

### FASE 1: Pulido de Operaciones Financieras y Drag Superior en `InteractiveSheetWrapper`

#### 1.1. Chips de Motivo / Detalle en Fila Única Horizontal con Toggle Desmarcable y Sync
* **Archivos:** `client_finance_actions_modal.dart`
* **Cambios:**
  1. Reemplazar el `Wrap` de motivos por un `SingleChildScrollView` horizontal con `BouncingScrollPhysics` y espaciado de 8px entre chips.
  2. Implementar lógica de toggle bidireccional en `ChoiceChip.onSelected`:
     * Si `val == true`, asignar `_noteCtrl.text = motivo`.
     * Si `val == false` (el usuario vuelve a tocar el seleccionado), ejecutar `_noteCtrl.clear()`.
  3. Asegurar que `_noteCtrl.addListener` invoque `setState(() {})` para que cualquier cambio manual (escritura o borrado en el `TextField`) actualice inmediatamente el estado de selección de los chips.

#### 1.2. Reestructuración del Cronograma de Cuotas Anticolisión y Limpieza Visual
* **Archivos:** `client_finance_actions_modal.dart`
* **Cambios:**
  1. **Eliminar etiqueta redundante:** Suprimir el `Text("${7 - _excludedWeekdays.length} activos")` de la cabecera de días de cobro.
  2. **Iconos vectoriales en presets:** Reemplazar `"🚫 Omitir Domingos"` por `Icons.event_busy_rounded` o `Icons.block_rounded`, `"💼 Solo Lun - Vie"` por `Icons.business_center_outlined` y `"📅 Todos los días"` por `Icons.calendar_month_outlined`.
  3. **Solución a iconos dobles en Feedback:**
     * En `_recalculateMultipleInstallments`, eliminar los emojis iniciales de los textos (`"✨ Fechas actualizadas..."` -> `"Fechas actualizadas..."`, `"🔄 Fechas restauradas..."` -> `"Fechas restauradas..."`).
     * En el contenedor del feedback, conservar un único `Icon(Icons.auto_awesome_rounded)` o `Icon(Icons.sync_rounded)` vectorial con estilo refinado.
  4. **Layout Anticolisión en Cuotas:**
     * Reestructurar el widget de cada cuota para que el área de fecha se organice en un `Column` de dos líneas dentro de `Expanded`:
       * Línea 1: Fecha en texto negrita (`_formatDateSpanish(dueDate)`) + micro-icono `Icons.edit_calendar`.
       * Línea 2: Si tiene ajuste (`_installmentShiftReasons`), mostrar el micro-badge `Día hábil` / `Dom omitido` debajo de la fecha con un micro-icono vectorial, sin invadir jamás el espacio horizontal del botón `+1d` ni el monto en soles.

#### 1.3. Cierre Intencional por Arrastre Superior en `InteractiveSheetWrapper`
* **Archivos:** `interactive_sheet_wrapper.dart`, `client_finance_actions_modal.dart`
* **Cambios:**
  1. En `InteractiveSheetWrapper`, agregar soporte para `enableHeaderDragToDismiss: true` (o cuando `enableDragToDismiss: false`, permitir arrastre vertical capturado exclusivamente por el área de la barra superior/handle).
  2. Umbral de descarte en cabecera: Exigir un arrastre intencional pronunciado (`_dragOffset > 90.0` o `velocity > 380 px/s`) con animación de resorte elástico si no se alcanza el umbral.
  3. En `client_finance_actions_modal.dart`, integrar el detector de arrastre superior en el handle `───` y la franja del título `"Operaciones Financieras"` para permitir el cierre suave por swipe hacia abajo sin interferir con el scroll de cuotas.

---

### FASE 2: Depuración y Refinamiento Ejecutivo en `Catálogo de Ventas`

#### 2.1. Eliminación del Botón de Ordenar Duplicado en la Barra de Búsqueda
* **Archivos:** `catalog_header.dart`
* **Cambios:**
  1. Remover el bloque `InkWell` del selector de ordenamiento (líneas 161–194) de la fila del buscador.
  2. Expandir el `TextField` de búsqueda para que ocupe todo el ancho disponible hasta el botón de filtros `Icons.tune`. El placeholder `"Buscar producto, marca..."` se mostrará completo y sin cortes.

#### 2.2. Modernización del Botón de Ordenamiento en Contador y Modal
* **Archivos:** `catalog_filter_header.dart` (`CatalogCounterBar`), `catalog_sort_modal.dart`, `catalog_provider.dart`
* **Cambios:**
  1. En `CatalogCounterBar`, eliminar el emoji `🔤` y renderizar un `Icon(provider.sortOption.icon, size: 16)` con color temático y tipografía de alta jerarquía.
  2. En `CatalogSortModal`, reemplazar el texto con emoji por un contenedor circular estilizado con `Icon(option.icon, size: 20)` y acabado Mobile Awards con micro-animaciones de selección.

#### 2.3. Eliminación de la Tarjeta Amarilla de "Modo Tienda" y Explicación en Ayuda Contextual
* **Archivos:** `catalog_screen.dart`
* **Cambios:**
  1. Eliminar `_buildStoreModeBanner` y su renderizado condicional en la pantalla principal.
  2. En el botón `InfoTooltipButton` de la AppBar (`ⓘ Catálogo de Ventas`), agregar el siguiente tip sutil y comercial:
     * Icono: `Icons.storefront_rounded`
     * Texto: *"Modo Tienda: Actívalo en la barra superior para mostrar una vista limpia de vitrina comercial al presentar el catálogo a clientes."*

---

### FASE 3: Auditoría Forense, Saneamiento y Control Total en `Mesa de Trabajo`

#### 3.1. Blindaje contra Cotizaciones Fantasma Vacías (`0 Ítems` y `S/ 0.00`)
* **Archivos:** `quotation_service.dart`, `matching_service.dart`, `workbench_provider.dart`, `manual_quote_save_ext.dart`
* **Cambios:**
  1. En `QuotationService.saveManualQuotation`: Lanzar excepción o rechazar si `items.isEmpty`.
  2. En `MatchingService.saveQuotation`: Validar que `items` contenga al menos un ítem antes de insertar en `smart_quotations`.
  3. En `WorkbenchProvider.saveManualQuotation` y `manual_quote_save_ext.dart`: Blindar la interfaz para que jamás envíe una cotización sin ítems a la base de datos.

#### 3.2. Rutina de Saneamiento Automático al Cargar Mesa de Trabajo
* **Archivos:** `workbench_provider.dart`
* **Cambios:**
  1. En `loadDashboard()`, antes de consultar las cotizaciones activas, ejecutar una limpieza automática en SQLite:
     ```dart
     await db.rawDelete('''
       DELETE FROM smart_quotations 
       WHERE (total_amount = 0.0 OR total_amount IS NULL)
         AND (status = 'DRAFT' OR status = 'PENDING')
         AND id NOT IN (SELECT DISTINCT quotation_id FROM smart_quotation_items)
         AND id NOT IN (SELECT DISTINCT cotizacion_id FROM ventas WHERE cotizacion_id IS NOT NULL)
     ''');
     ```
  2. Esto elimina de inmediato cualquier registro corrupto huérfano como `# Sin Cliente - #1` al abrir la pantalla o refrescar con pull-to-refresh.

#### 3.3. Eliminación Segura y Desvinculación de Foreign Keys
* **Archivos:** `workbench_provider.dart`, `quotation_service.dart`
* **Cambios:**
  1. En `deleteQuotation(int id)`:
     * Antes de borrar, desvincular cualquier venta anulada o huérfana:
       `await db.update('ventas', {'cotizacion_id': null}, where: 'cotizacion_id = ?', whereArgs: [id]);`
     * Eliminar primero los ítems en `smart_quotation_items` y luego la cotización en `smart_quotations` dentro de una transacción segura.

#### 3.4. Control Total de Eliminación en `QuotationDetailScreen` y Desmitificación del Pin
* **Archivos:** `quotation_detail_screen.dart`, `quotation_action_buttons.dart`, `quotation_card.dart`, `quick_actions_bottom_sheet.dart`
* **Cambios:**
  1. En `QuotationDetailScreen`, cuando `status == 'DRAFT'` o cuando `items.isEmpty`, agregar un botón visible y directo de **"Eliminar Borrador"** tanto en el empty state como en la barra inferior de acciones, permitiendo al usuario descartar el borrador en un solo toque con confirmación.
  2. En `QuotationCard`:
     * Cambiar el icono ambiguo `Icons.push_pin` por `Icons.note_alt_outlined` con mensaje explicativo de notas.
     * En `QuickActionsBottomSheet`, ofrecer la opción de **"Limpiar Nota"** o **"Desfijar"** y garantizar que **"Eliminar Definitivamente"** refresque la lista de forma instantánea.

---

### FASE 4: Verificación, Pruebas Automatizadas y Criterios del Árbitro Adversarial

#### 4.1. Pruebas Automatizadas (Test Suite Integral)
* **Archivo:** `app_movil/test/finanzas_catalogo_y_mesa_trabajo_polish_test.dart`
* **Casos de prueba obligatorios:**
  1. `testWidgets`: Chips de `Motivo / Detalle` en una fila con scroll horizontal, toggle funcional (desmarca y limpia texto) y sincronización reactiva al escribir en el TextField.
  2. `testWidgets`: Layout de cronograma anticolisión en 320px–360px con badge de día hábil en sub-línea y ausencia de `X activos` y emojis repetidos.
  3. `testWidgets`: Arrastre vertical superior en `InteractiveSheetWrapper` dispara descarte cuando `dragDistance > 90px`.
  4. `testWidgets`: Buscador de catálogo a ancho completo sin botón de ordenar duplicado; botón de ordenar en contador con icono vectorial y modal estilizado.
  5. `testWidgets`: Activación de Modo Tienda no muestra banner amarillo en pantalla y el modal `ⓘ` contiene el tip comercial pulido.
  6. `test`: Saneamiento automático en `loadDashboard()` elimina cotizaciones huérfanas de 0 ítems y S/ 0.00.
  7. `test`: `deleteQuotation` desvincula ventas y elimina cotizaciones en borrador exitosamente sin errores de clave foránea.

#### 4.2. Criterios de Aceptación del Árbitro Adversarial
* [ ] 0 desbordamientos (`RenderFlex overflow`) en pantallas de 320px a 360px.
* [ ] 0 errores de linter en todos los archivos modificados (`flutter analyze` limpio).
* [ ] 100% de tests aprobados sin regresiones en tests preexistentes.
* [ ] Cero persistencia de cotizaciones vacías de 0 ítems.
* [ ] Experiencia visual y táctil alineada a los estándares de **Mobile Awards**.
