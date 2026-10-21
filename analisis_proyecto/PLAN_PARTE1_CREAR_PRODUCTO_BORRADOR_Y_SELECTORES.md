# PLAN DE TRABAJO: REDISEÑO DE CREAR PRODUCTO, BORRADOR TEMPORAL PERSISTENTE Y SELECTORES MODERNOS

**Proyecto:** Mochila Lista — App Móvil POS / CRM  
**Archivo de Planificación:** `analisis_proyecto/PLAN_PARTE1_CREAR_PRODUCTO_BORRADOR_Y_SELECTORES.md`  
**Versión:** 2.0 (Plan de Ejecución Integral con Ajustes Clave Incorporados)  
**Metodología:** Loop Autónomo Continuo + Árbitro Adversarial Interno  
**Estado:** COMPLETADO EXITOSAMENTE Y CERTIFICADO CON 0 ERRORES / 0 WARNINGS (120/120 TESTS PASSING)  

---

## 1. INTRODUCCIÓN Y DIAGNÓSTICO FORENSE DE LAS 5 CAPTURAS REALES

A partir de la inspección exhaustiva de `product_create_screen.dart`, `product_presentation_card.dart`, `smart_unit_selector.dart`, `safe_dropdown.dart`, `master_data_service.dart`, `product_service.dart`, `persistent_work_dock.dart`, `deep_nav_return_pill.dart` y de las 5 capturas en vivo enviadas, se evidencia un conjunto de problemas ergonómicos, visuales y de persistencia:

```
+---------------------------------------------------------------------------------------------------+
| DIAGNÓSTICO VISUAL Y FUNCIONAL DE LAS CAPTURAS REALES                                             |
+---------------------------------------------------------------------------------------------------+
| Captura 1: Menu Desplegable Nativo Gigante e Invasivo                                             |
|   - Tocar Marca/Categoría/Proveedor despliega un DropdownButtonFormField vertical nativo que      |
|     ocupa desde arriba hasta el botón "GUARDAR PRODUCTO".                                         |
|   - Carece de buscador instantáneo, filtrado o scroll elástico moderno.                           |
|   - "+ Crear Nuevo..." crea el registro de inmediato en SQLite (sin transacción ni diferido).    |
|   - En la fila superior, la palabra "Categoría" se trunca a "Categ..." por falta de espacio.     |
+---------------------------------------------------------------------------------------------------+
| Captura 2: Truncamiento en "¿Cómo lo vas a vender?" y "Costos y Precio Final"                    |
|   - Scroll horizontal corta el primer chip como "a (x12)" por falta de padding/clip.              |
|   - Fila innecesaria de chips de factores personalizados (x12, x24, x50, x100) que confunde y    |
|     no funciona adecuadamente. Debe ser eliminada por completo en Crear y Editar Producto.       |
|   - En Costos y Precios, la primera columna se trunca como "Costo Present. ...".                 |
|   - El badge dinámico de margen ("🟢 Margen Óptimo...") se desborda contra el margen derecho.    |
+---------------------------------------------------------------------------------------------------+
| Captura 3: Rotura en Módulo de Descuentos y Truncamiento Severo en Stock                         |
|   - En el tipo de descuento, "% / Porcentaje" se parte en 2 líneas apretadas contra el borde.    |
|   - Las 3 columnas de Stock se cortan con elipses: "Stock Unitario...", "+ Ingreso ..." y         |
|     "= Stock Final (...".                                                                         |
+---------------------------------------------------------------------------------------------------+
| Captura 4: Desalineación y Truncamiento en Datos de Compra / Factura                              |
|   - "Cantidad Lotes" se corta como "Cantidad Lo..." en flex: 3.                                   |
|   - El input numérico de Lotes está desalineado verticalmente respecto a Unidad y Factor.        |
+---------------------------------------------------------------------------------------------------+
| Captura 5 y AppBar Global: Ausencia de Persistencia Temporal, Guía (i) y Reseteo Rápido           |
|   - Salir de la ventana destruye todo el formulario y controladores en memoria.                   |
|   - El selector "Proveedor de esta Variante" también sufre del menú desplegable nativo gigante.   |
|   - No hay indicador en PersistentWorkDock ni DeepNavReturnPill para retomar la creación.        |
|   - No existe botón "Limpiar Todo" para vaciar el borrador sin borrar campo por campo.            |
|   - No cuenta con InfoTooltipButton (i) en el AppBar explicando el flujo al usuario.              |
+---------------------------------------------------------------------------------------------------+
```

---

## 2. METODOLOGÍA DEL LOOP AUTÓNOMO Y ÁRBITRO ADVERSARIAL

Para garantizar que la implementación sea intachable, cada Fase se regirá bajo el siguiente ciclo:

```mermaid
graph TD
    A[1. Implementación Técnica y de UI] --> B[2. Análisis de Compilación y Tipado Estricto]
    B --> C[3. Pruebas Unitarias y de Widgets Automatizadas]
    C --> D[4. Auditoría Adversarial Implacable]
    D -->|Falla visual, truncamiento o regresión| E[5. Corrección Inmediata y Refinamiento]
    E --> B
    D -->|100% Criterios de Aceptación Cumplidos| F[6. Aprobación y Paso a la Siguiente Fase]
```

---

## 3. MAPA DE FASES DE IMPLEMENTACIÓN CON LOS 3 AJUSTES CLAVE OBLIGATORIOS

```
========================================================================================================
FASE 1: REDISEÑO DE SELECTORES (MARCA, CATEGORÍA, PROV. GENERAL Y PROV. DE VARIANTE) + CREACIÓN DIFERIDA
FASE 2: SISTEMA DE BORRADOR TEMPORAL EN MEMORIA + INTEGRACIÓN WORKDOCK & PILL + LIMPIAR TODO (RESET 100%)
FASE 3: ANIMACIÓN DE GUARDADO PROFESIONAL + CIERRE Y TRASLADO FLUIDO A INVENTARIO -> PESTAÑA PRODUCTOS
FASE 4: REINGENIERÍA VISUAL, CERO TRUNCAMIENTOS, ELIMINACIÓN DE CHIPS x12/x24/x50/x100 Y NUEVAS FUNCIONES
FASE 5: SISTEMA DE INFO TOOLTIP (i) EN APPBAR + SUITE DE PRUEBAS ADVERSARIALES Y CERTIFICACIÓN
========================================================================================================
```

---

### FASE 1: REDISEÑO DE SELECTORES (MARCA, CATEGORÍA, PROVEEDOR GENERAL Y PROVEEDOR DE VARIANTE) + CREACIÓN DIFERIDA TRANSACCIONAL

#### 1.1. Objetivos Técnicos y de Experiencia
* **Erradicar el Menú Desplegable Nativo Gigante:** Reemplazar el `DropdownButtonFormField` invasivo por un selector moderno y elegante basado en un modal inferior interactivo (`InteractiveSheetWrapper`) con:
  * Buscador instantáneo integrado con debounce y limpieza rápida.
  * Chips de estado y lista con scroll elástico fluido (`BouncingScrollPhysics`).
  * Botón destacado superior/flotante `"+ Crear Nueva Marca / Categoría / Proveedor"`.
  * Visualización clara del elemento seleccionado con checkmark animado.
* **Cobertura Total de Selectores:**
  1. `Marca` en cabecera general.
  2. `Categoría` en cabecera general.
  3. `Proveedor General` en cabecera general.
  4. **`Proveedor de esta Variante` / `Proveedor Específico`** dentro de cada presentación en `product_presentation_card.dart` (con soporte para `"Usar Principal (Heredado)"`, selección directa y creación diferida).
* **Cero Truncamientos en el Formulario:** Rediseñar la fila de `Marca` y `Categoría` para que la etiqueta `"Categoría"` **jamás se recorte como `"Categ..."`**. Los selectores mostrarán el nombre seleccionado con tipografía balanceada y un chevron discreto.
* **Creación Diferida Transaccional en Memoria (SQLite Clean):**
  * Al ingresar una nueva Marca, Categoría o Proveedor mediante `"+ Crear Nuevo..."`, el sistema **NO ejecutará `db.insert` de inmediato**.
  * Se mantendrá en memoria temporal con un identificador provisional y un badge distintivo: `Nuevo · Pendiente`.
  * Únicamente cuando el usuario presione `"GUARDAR PRODUCTO"`, se persistirá en SQLite dentro de la **misma transacción atómica** (`db.transaction`), asociando automáticamente los nuevos IDs foráneos al producto y sus variantes.
  * Si el usuario descarta o limpia el formulario, la base de datos queda **100% limpia sin registros basura ni huérfanos**.

#### 1.2. Archivos a Intervenir y Crear
1. **Nuevo Componente Núcleo:** `app_movil/lib/core/widgets/modern_entity_picker_modal.dart` (Modal interactivo con buscador instantáneo, scroll fluido y creación diferida).
2. **Nuevo Selector Input:** `app_movil/lib/core/widgets/modern_entity_selector_field.dart` (Widget estético tipo botón de entrada con label, ícono, valor actual, badge diferido y chevron, inmune a truncamientos).
3. **Servicios y Repositorios:**
   * `app_movil/lib/features/catalog/services/product_service.dart`: Recibir marcas/categorías/proveedores diferidos en `createFullProduct`.
   * `app_movil/lib/features/catalog/repositories/product_repository.dart`: Extender `createFullProductTransaction` para registrar atómicamente entidades diferidas.
   * `app_movil/lib/features/catalog/providers/inventory_provider.dart`: Métodos de resolución en memoria y actualización de catálogo.
4. **Pantallas y Widgets:**
   * `app_movil/lib/features/catalog/screens/product_create_screen.dart`: Reemplazo de los 3 selectores generales.
   * `app_movil/lib/core/widgets/product_presentation_card.dart`: Reemplazo de `SafeDropdown` en `Proveedor de esta Variante`.

---

### FASE 2: SISTEMA DE BORRADOR TEMPORAL EN MEMORIA + INTEGRACIÓN WORKDOCK & PILL + BOTÓN "LIMPIAR TODO"

#### 2.1. Objetivos Técnicos y de Experiencia
* **Persistencia No Volátil 100% en Memoria (Zero-Friction Exit):**
  * Salir de `Crear Producto` preserva intactos: nombre, visibilidad, marca/categoría/proveedor (reales o diferidos), detalles globales (foto, barcode, descripción), y todas las presentaciones con sus unidades, factores, costos, márgenes, descuentos, stock, compras, códigos de barras e imágenes específicas.
  * Cero escrituras en SQLite hasta presionar `"GUARDAR PRODUCTO"`.
* **Indicadores Externos e Interno:**
  * **En `PersistentWorkDock`:** Tarea activa `WorkTask(id: 'product_create', ...)` con `onResume` y `onDiscard`.
  * **En `DeepNavReturnPill`:** Retorno en 1 toque hacia la ventana de `Crear Producto`.
  * **En `ProductsTab`:** Banner sutil informativo para retomar la creación.
  * **En `AppBar` de `Crear Producto`:** Micro-badge elegante `"Borrador en memoria"`.
* **Botón "Limpiar Todo" (Reseteo Rápido 100% Limpio):**
  * Botón en AppBar con icono de escoba/reinicio y confirmación modal rápida.
  * Limpia todos los campos, resetea selectores, elimina presentaciones extra (dejando solo la inicial en blanco), **elimina la imagen global y las imágenes específicas de las variantes**, y descarta el borrador temporal.

#### 2.2. Archivos a Intervenir y Crear
1. `app_movil/lib/features/catalog/models/product_create_draft.dart`: Modelo completo de datos en borrador.
2. `app_movil/lib/features/catalog/providers/inventory_provider.dart`: Métodos de guardado, consulta y vaciado de borrador.
3. `app_movil/lib/core/widgets/persistent_work_dock.dart`: Tarea de trabajo del producto en creación.
4. `app_movil/lib/core/widgets/deep_nav_return_pill.dart`: Píldora de retorno al borrador.
5. `app_movil/lib/features/catalog/screens/tabs/products_tab.dart`: Banner de reanudación.
6. `app_movil/lib/features/catalog/screens/product_create_screen.dart`: Carga/sincronización y botón "Limpiar Todo".

---

### FASE 3: ANIMACIÓN DE GUARDADO PROFESIONAL + CIERRE Y TRASLADO FLUIDO A INVENTARIO (PESTAÑA PRODUCTOS)

#### 3.1. Objetivos Técnicos y de Experiencia
* **Animación de Guardado Profesional:**
  * Feedback visual con micro-estados: `"Guardando producto y variantes..."` $\rightarrow$ `"¡Producto guardado exitosamente! ✨"` con checkmark elástico y háptica táctil.
* **Cierre y Traslado Fluido:**
  * Al terminar la animación, limpia el borrador temporal, cierra la ventana y traslada al usuario a `InventoryScreen(initialTabIndex: 0)` (pestaña `PRODUCTOS`), refrescando el listado desde SQLite para que el nuevo producto aparezca al inicio inmediatamente.

#### 3.2. Archivos a Intervenir y Crear
1. `app_movil/lib/features/catalog/widgets/product_save_success_dialog.dart`: Diálogo/overlay animado de confirmación.
2. `app_movil/lib/features/catalog/screens/inventory_screen.dart`: Soporte de `initialTabIndex: 0`.
3. `app_movil/lib/features/catalog/screens/product_create_screen.dart`: Orquestación del guardado y navegación fluida.

---

### FASE 4: REINGENIERÍA VISUAL DE SECCIONES, ELIMINACIÓN DE CHIPS x12/x24/x50/x100, CERO TRUNCAMIENTOS Y NUEVAS FUNCIONES

#### 4.1. Objetivos Técnicos y de Experiencia
* **1. Eliminación Definitiva de los Chips de Factor x12, x24, x50, x100 (Crear y Editar Producto):**
  * Eliminar por completo el `Wrap` con `_buildFactorChip("x12 (Docena)", 12)`, `_buildFactorChip("x24 (2 Docenas)", 24)`, `_buildFactorChip("x50 (50 Uds)", 50)` y `_buildFactorChip("x100 (Ciento)", 100)` en `product_presentation_card.dart`.
  * Optimizar `"Ver unidades disponibles"` en `smart_unit_selector.dart`: corregir `padding` y `clipBehavior` para eliminar el recorte lateral `"a (x12)"`, manteniendo una visualización impecable de las unidades estándar del catálogo con su factor automático sincronizado.
* **2. Blindaje Anti-Desborde del Banner de Margen:**
  * En `product_presentation_card.dart` (`_buildMarginTrafficLight`), envolver el banner dinámico (`"🟢 Margen Óptimo (35.6%) - Excelente margen"`) en `Expanded` / `FittedBox(fit: BoxFit.scaleDown)` para evitar que se desborde sobre el margen derecho de la pantalla.
* **3. Corrección de Costos y Precios:**
  * Reemplazar `"Costo Present. (S/)"` por `"Costo (S/)"` con `FittedBox` y autoescalado, asegurando proporciones exactas en las 3 columnas (`Costo`, `Margen` y `Precio`).
* **4. Corrección en Módulo de Descuentos:**
  * Rediseñar el toggle `% Porcentaje` y `S/ Fijo` en una sola línea horizontal amplia sin rotura a 2 líneas.
* **5. Corrección en Bloque de Stock:**
  * Reemplazar etiquetas largas truncadas por etiquetas jerárquicas compactas: `Inicial (Sueltas)`, `+ Ingreso (Sueltas)` y `= Final (Unidad)`.
* **6. Corrección en Datos de Compra / Factura:**
  * Alinear verticalmente el input de `Cantidad Lotes` con `Unidad` y `Factor`, renombrando a `"Cant. Lotes"` con altura unificada.
* **7. Modernización de Scrolls y Nuevas Funciones Útiles:**
  * Auto-enfoque suave (`Scrollable.ensureVisible`).
  * **Botón para Clonar / Duplicar Variante**.
  * **Redondeo Rápido de Precios** (`.50`, `.90`, `.00`).
  * **Sugerencias Rápidas para Nombre de Variante**.

#### 4.2. Archivos a Intervenir
1. `app_movil/lib/core/widgets/smart_unit_selector.dart`
2. `app_movil/lib/core/widgets/product_presentation_card.dart`
3. `app_movil/lib/features/catalog/screens/product_create_screen.dart`
4. `app_movil/lib/features/catalog/screens/product_edit_screen.dart` (asegurar eliminación de los chips de factor también en edición).

---

### FASE 5: SISTEMA DE INFO TOOLTIP (i) EN APPBAR + CERTIFICACIÓN INTEGRAL DE PRUEBAS ADVERSARIALES

#### 5.1. Objetivos Técnicos y de Experiencia
* **Integración de `InfoTooltipButton` `(i)` en AppBar:**
  * Añadir el botón informativo con guía interactiva de borrador temporal, reseteo, variantes y costos.
* **Suite de Pruebas Automatizadas:**
  * Crear `test/product_create_draft_and_selectors_test.dart` y validar con `dart analyze` (0 errores, 0 warnings).

---

## 4. CONCLUSIÓN Y DICTAMEN DEL ÁRBITRO ADVERSARIAL

Todas las 5 Fases del Plan han sido completadas, integradas y auditadas rigurosamente:

1. **Fase 1 (Selectores Modernos y Creación Diferida Transaccional):** `ModernEntityPickerModal` y `ModernEntitySelectorField` integrados en Marca, Categoría, Proveedor General y Proveedor de Variante (`ProductPresentationCard` y `ProductPresentationList`). Entidades creadas con ID negativo temporal se persisten atómicamente en SQLite al guardar.
2. **Fase 2 (Borrador Temporal Persistente y Limpiar Todo):** `ProductCreateDraft` sincroniza 100% en memoria; se activa en `PersistentWorkDock`, `DeepNavReturnPill` y `ProductsTab`; badge `"Borrador"` en AppBar; y acción `"Limpiar Todo"` resetea todos los campos, entidades diferidas, imágenes y variantes a 1 sola limpia.
3. **Fase 3 (Animación y Traslado a Inventario):** Diálogo animado `ProductSaveSuccessDialog` desplegado tras guardar exitosamente; el borrador se vacía y se navega inmediatamente a `InventoryScreen(initialTabIndex: 0)` refrescado desde SQLite.
4. **Fase 4 (Visual, Limpieza y Nuevas Funciones):** Eliminados definitivamente los chips `x12`, `x24`, `x50` y `x100` tanto en Crear como en Editar Producto; corregido `SmartUnitSelector` sin corte lateral `"a (x12)"`; blindaje del badge de margen con `FittedBox(fit: BoxFit.scaleDown)`; integrados chips de sugerencia de nombre, clonación de variantes y redondeo rápido `.50`, `.90`, `.00`.
5. **Fase 5 (InfoTooltipButton y Validación Estática):** `InfoTooltipButton` activo en AppBar; `dart analyze lib test` con **0 errores y 0 warnings**; suite de pruebas en `test/product_create_draft_and_selectors_test.dart` y suite completa de la app con **120/120 tests aprobados al 100%**.

