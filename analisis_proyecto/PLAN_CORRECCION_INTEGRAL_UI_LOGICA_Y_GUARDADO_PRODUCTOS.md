# 📋 PLAN MAESTRO: CORRECCIÓN INTEGRAL DE UI, RESPONSIVIDAD, EXPERIENCIA TÁCTIL Y LÓGICA TRANSACCIONAL DE PRODUCTOS (CREAR Y EDITAR)

> **Documento:** `analisis_proyecto/PLAN_CORRECCION_INTEGRAL_UI_LOGICA_Y_GUARDADO_PRODUCTOS.md`  
> **Fecha:** 18 de Octubre, 2026  
> **Metodología:** Loop Autónomo con Árbitro Adversarial (TDD + Verificación Forense Paso a Paso)  
> **Estado:** 🟡 Listo para Aprobación del Usuario (Sin modificaciones de código previas)

---

## 🧭 ÍNDICE EJECUTIVO

1. [Diagnóstico Técnico Forense de los 7 Puntos Críticos](#1-diagnóstico-técnico-forense-de-los-7-puntos-críticos)
   - [Punto 1: Causa Raíz del Fallo al Guardar ("Error:" en Barra Roja)](#punto-1-causa-raíz-del-fallo-al-guardar-error-en-barra-roja)
   - [Punto 2: Deduplicación y Nueva Experiencia Táctil en Selector de Entidades](#punto-2-deduplicación-y-nueva-experiencia-táctil-en-selector-de-entidades)
   - [Punto 3: Reestructuración de Cabezales de Tarjeta y Sección de Variantes](#punto-3-reestructuración-de-cabezales-de-tarjeta-y-sección-de-variantes)
   - [Punto 4: Corrección Matemática de Redondeo y Micro-Animaciones Reactivas](#punto-4-corrección-matemática-de-redondeo-y-micro-animaciones-reactivas)
   - [Punto 5: Refinamiento de Borrador Real y Supresión de Falsas Alertas](#punto-5-refinamiento-de-borrador-real-y-supresión-de-falsas-alertas)
   - [Punto 6: Control Inteligente del Teclado y Cierre Fuera del Foco](#punto-6-control-inteligente-del-teclado-y-cierre-fuera-del-foco)
   - [Punto 7: Auditoría Visual Periférica (Banner Home, Formulario Global)](#punto-7-auditoría-visual-periférica-banner-home-formulario-global)
2. [Arquitectura de Solución y Whitelist Canónico SQLite](#2-arquitectura-de-solución-y-whitelist-canónico-sqlite)
3. [Matriz de Archivos a Intervenir](#3-matriz-de-archivos-a-intervenir)
4. [Fases de Ejecución (Loop Autónomo + Árbitro Adversarial)](#4-fases-de-ejecución-loop-autónomo--árbitro-adversarial)
5. [Criterios de Aceptación y Pruebas Automatizadas](#5-criterios-de-aceptación-y-pruebas-automatizadas)

---

## 1. DIAGNÓSTICO TÉCNICO FORENSE DE LOS 7 PUNTOS CRÍTICOS

---

### PUNTO 1: Causa Raíz del Fallo al Guardar ("Error:" en Barra Roja)
* **Evidencia en Captura:** `Imagen 4` exhibe un `SnackBar` con fondo rojo y texto literal `"Error: "` al pulsar `"GUARDAR PRODUCTO"`.
* **Rastreo del Flujo:**
  1. `ProductCreateOperations.submitProduct` invoca `invProv.createFullProduct(...)` (`product_create_operations.dart:679`).
  2. Si `createFullProduct` retorna `false`, se ejecuta:
     ```dart
     final msg = invProv.errorMessage;
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text("Error: $msg"), backgroundColor: Colors.red),
     );
     ```
  3. En `InventoryProvider` (`inventory_provider.dart:26`), la variable `_errorMessage` se inicializa como `''` y **jamás se asigna** dentro de `createFullProduct` ni `editFullProduct` cuando ocurre un error en el bloque `try/finally`.
  4. En `ProductService.createFullProduct` (`product_service.dart:159-162`), cualquier excepción lanzada por SQLite es capturada, registrada con `AppLogger.error` y retorna simplemente `false`, perdiendo el mensaje de error.
  5. En `ProductEditOperations.saveEditedProduct` (`product_edit_operations.dart:501-525`), si `editFullProduct` retorna `false`, ni siquiera se informa el error al usuario.
* **Causa Raíz en SQLite (`product_repository.dart` & `local_db.dart`):**
  * **Violación de Esquema en `productos`:**
    * En `local_db.dart:289`, la tabla `productos` tiene únicamente:
      `id, negocio_id, categoria_id, marca_id, codigo_barras, nombre, descripcion, imagen_url, estado, fecha_actualizacion`.
    * En `ProductService.createFullProduct` (`product_service.dart:111-125`), se construye `productData` inyectando `'proveedor_id': proveedorId`, `'deferred_brand_name': deferredBrandName`, `'deferred_category_name': deferredCategoryName`, `'deferred_provider_name': deferredProviderName`.
    * En `ProductRepository.createFullProductTransaction` (`product_repository.dart:460-578`), si `deferred_brand_name`, `deferred_category_name` o `deferred_provider_name` son `null`, **no son removidos** del mapa porque la condición es `containsKey(...) && ... != null`.
    * Además, `'proveedor_id'` **nunca es removido** de `productData`.
    * Al ejecutar `await txn.insert('productos', productData)`, SQLite detona:
      `DatabaseException: table productos has no column named proveedor_id` (o `deferred_brand_name`).
  * **Violación de Esquema en `presentaciones_producto`:**
    * En `ProductPresentation.toSqlite(productId)` (`product_model.dart:116`), se genera la clave `'deferred_provider_name': deferredProviderName`.
    * En `ProductRepository.createFullProductTransaction` (`product_repository.dart:541-576`), si `deferred_provider_name` es `null`, **no se elimina** del mapa antes de la inserción.
    * Al ejecutar `await txn.insert('presentaciones_producto', pres)` (`product_repository.dart:585`), SQLite detona:
      `DatabaseException: table presentaciones_producto has no column named deferred_provider_name`.
  * **Mismo problema en Edición (`ProductRepository.editFullProductTransaction`):**
    * `productData` conserva `'proveedor_id'`, lo que rompe `_updateProductTxn(txn, productId, productData)` (`product_repository.dart:749`).
* **Solución a Implementar:**
  1. **Sanitización Estricta mediante Whitelist en Repositorio:** Implementar filtros canónicos basados en `Set<String>` con las columnas oficiales de SQLite para `productos` y `presentaciones_producto`. Eliminar cualquier clave espuria antes de inserciones o actualizaciones.
  2. **Captura y Propagación de Errores Reales:** Modificar `ProductService` para propagar el mensaje de error o retornarlo estructurado (`Result<T>` o almacenar en `InventoryProvider.errorMessage`), garantizando que la barra roja informe la causa real (ej. `"Error: Nombre duplicado"`, `"Error al conectar con la base de datos: ..."`).
  3. **Retroalimentación de Error en `ProductEditOperations`:** Añadir presentación del `SnackBar` de error si falla la actualización en edición.

---

### PUNTO 2: Deduplicación y Nueva Experiencia Táctil en Selector de Entidades
* **Problema A — Duplicados en Modal (`Imagen 1`):**
  * En `modern_entity_picker_modal.dart:223`, se extrae `specialItems = widget.items.where((it) => it.isSpecial).toList()`.
  * En la línea 323, cuando `_filterQuery.isEmpty`, se renderiza una lista de estos `specialItems`:
    ```dart
    ...specialItems.map((item) => _buildItemTile(item)),
    Divider(...),
    ```
  * Inmediatamente después, en la línea 394, el `ListView.builder` itera sobre `filtered`, el cual es:
    ```dart
    if (_filterQuery.isEmpty) return widget.items;
    ```
  * Dado que `widget.items` **ya contenía** los `specialItems`, estos se renderizaban **dos veces**: una arriba del divisor y otra dentro de la lista principal.
* **Problema B — Recorte de Texto `"Sin categoría ..."` en el Selector:**
  * En `modern_entity_selector_field.dart:123`, el campo muestra el texto con `maxLines: 1` y `TextOverflow.ellipsis`.
  * En `product_entity_pickers.dart:126`, el valor por defecto es `"Sin categoría (General)"` (23 caracteres). Al ubicarse en una columna de ancho compartido (~160px), el texto supera el espacio y se trunca.
* **Problema C — Cierre Brusco sin Feedback Táctil ni Cancelación por Desplazamiento:**
  * Actualmente el ítem usa un simple `InkWell(onTap: () { Navigator.pop(context, item); })`, cerrando de golpe sin animación ni posibilidad de cancelar arrastrando el dedo.
* **Solución a Implementar:**
  1. **Filtrado de Especiales en la Lista Principal:** En `modern_entity_picker_modal.dart`, modificar `_filteredItems` para que los ítems especiales solo aparezcan en la cabecera dedicada y se excluyan del `ListView`, o bien eliminar la cabecera y mantenerlos ordenados de forma única en la lista.
  2. **Resiliencia Textual en Selector Cerrado:** Optimizar `getCategoryDisplay` / `getBrandDisplay` / `getProviderDisplay` para entregar etiquetas concisas e informativas en vista previa (ej. `"Sin categoría"`, `"Sin marca"`, `"Sin proveedor"`), acompañadas de `FittedBox` con escalado seguro para que nunca se trunquen con puntos suspensivos.
  3. **Control Táctil de Selección (Press $\rightarrow$ Drag-to-Cancel $\rightarrow$ Release-to-Select):**
     * Convertir los ítems del picker en un widget reactivo (`_PickerItemTile`) con `GestureDetector`.
     * `onTapDown`: Activar micro-animación de pulsado (`scale: 0.97`, borde iluminado sutil y tinte de fondo reactivo).
     * `onTapCancel`: Revertir la animación a escala 1.0 y cancelar selección si el usuario arrastra el dedo o scrollea.
     * `onTapUp`: Desencadenar animación de confirmación (aparición suave de checkmark / destello), vibración háptica (`HapticFeedback.selectionClick()`), breve pausa de 120ms para percibir el feedback y cierre animado fluido con `Navigator.pop(context, item)`.

---

### PUNTO 3: Reestructuración de Cabezales de Tarjeta y Sección de Variantes
* **Problema A — Amontonamiento Crítico en `presentation_card_header.dart` (`Imagen 3`):**
  * `PresentationCardHeader` (`presentation_card_header.dart:52-232`) ubica en una única fila `Row`:
    `Icono estrella` + `Insignia (#1 Principal / #2 Secundaria)` + `Botón Hacer Principal` + `Flecha Subir ▲` + `Flecha Bajar ▼` + `Switch Visible con etiqueta` + `Botón Clonar` + `Botón Eliminar` + `Botón Chevron Colapsar`.
  * Esto totaliza más de 420px de ancho fijo en pantallas móviles de ~360-390px, obligando a los elementos a comprimirse, superponerse y montarse sobre el texto.
* **Problema B — Doble Flecha Chevron `v` al Estar Colapsada:**
  * En `presentation_card_header.dart:221`, el cabezal tiene su propio `IconButton` con `Icons.keyboard_arrow_down`.
  * En `presentation_card_collapsed_view.dart:143`, la vista colapsada vuelve a renderizar otro `Icon(Icons.keyboard_arrow_down)` al lado del precio (`S/ 11.04 v`), duplicando el indicador.
* **Problema C — Desbordamiento en `variant_section_header.dart` y Doble Estrella en `variant_jump_bar.dart`:**
  * En `variant_section_header.dart:25-92`, el título en mayúsculas `"PRESENTACIONES / VARIANTES"` comparte fila con `Spacer()`, el botón de `Reordenar` y el botón de `Expandir/Colapsar`. En terminales con fuentes grandes o pantallas angostas, el botón de expandir queda cortado por el borde derecho.
  * En `variant_jump_bar.dart:79-82`:
    ```dart
    if (isDef) const Text("⭐ ", style: TextStyle(fontSize: 10)),
    Text(label, ...) // donde label ya era "⭐ Principal"
    ```
    Dando como resultado visual: `"⭐ ⭐ Principal"`.
* **Solución a Implementar:**
  1. **Nuevo Cabezal Limpio + Cajón de Acciones Replegable (`presentation_card_header.dart`):**
     * **Fila Superior Fija y Despejada:**
       * Izquierda: Insignia limpia con bordes redondeados (`⭐ Principal` o `#2 Secundaria`).
       * Centro: Indicador discreto de visibilidad (pequeño chip o badge `Visible` / `Oculto`).
       * Derecha: Botón de herramientas de tarjeta `[ ⋯ ]` (o `[ ⚙️ ]`) + Único botón de expansión/colapso (`▲` / `▼`).
     * **Cajón Operativo Expandible (`AnimatedSize` / `AnimatedCrossFade`):**
       * Al presionar `[ ⋯ ]`, se despliega una barra de herramientas horizontal estilizada con padding adecuado que contiene cómodamente:
         `[ ⭐ Hacer Principal ]` (si aplica) • Switch `"Visible"` • `[ ▲ ]` • `[ ▼ ]` • `[ ⧉ Clonar ]` • `[ 🗑️ Eliminar ]`.
       * Cada acción tendrá tamaño táctil accesible ($\ge 44 \times 44$ pt) y cero riesgo de colisión.
  2. **Eliminación del Chevron Redundante:** Suprimir el icono de flecha interior en `presentation_card_collapsed_view.dart`, centralizando el colapso y expansión en el botón único del cabezal y el toque general en la tarjeta.
  3. **Responsividad en `variant_section_header.dart` y Corrección del Chip Jump Bar:**
     * Reestructurar `variant_section_header.dart` utilizando un diseño adaptable (título conciso con badge contador de variantes `[2]` a la izquierda y botones compactos a la derecha sin desborde).
     * En `variant_jump_bar.dart`, eliminar el prefijo manual repetido para que el chip muestre una sola estrella limpia (`⭐ Principal`).

---

### PUNTO 4: Corrección Matemática de Redondeo y Micro-Animaciones Reactivas
* **Problema A — Lógica Rota en Redondeo `.50`, `.90` y `.00` (`Imagen 2`):**
  * En `presentation_math_engine.dart:394-410`:
    ```dart
    if (targetFraction == 1.00) {
      rounded = current.ceilToDouble(); // Salta al entero superior sin importar el decimal
    } else if (targetFraction == 0.50) {
      double floor = current.floorToDouble();
      if (current - floor <= 0.50) {
        rounded = floor + 0.50;
      } else {
        rounded = floor + 1.00; // ❌ ERROR: Convierte 13.80 en 14.00 en vez de 13.50
      }
    } else if (targetFraction == 0.90) { ... }
    ```
* **Problema B — Falta de Feedback Visual en Chips de Sugerencia y Redondeo:**
  * En `presentation_suggestion_chips.dart` y `presentation_pricing_section.dart`, los chips son estáticos y no evidencian animación al ser pulsados.
* **Solución Matemática y Visual a Implementar:**
  1. **Algoritmo Canónico de Redondeo:**
     ```dart
     void roundPrice(double targetFraction) {
       final double current = double.tryParse(ventaCtrl.text) ?? 0.0;
       if (current <= 0) return;
       final double floor = current.floorToDouble();
       final double fraction = current - floor;
       double rounded;

       if (targetFraction == 0.50) {
         // Fija los decimales en .50 conservando exactamente la parte entera actual
         rounded = floor + 0.50;
       } else if (targetFraction == 0.90) {
         // Fija los decimales en .90 conservando exactamente la parte entera actual
         rounded = floor + 0.90;
       } else if (targetFraction == 1.00 || targetFraction == 0.00) {
         // Si fraction < 0.50 redondea hacia abajo; si >= 0.50 redondea hacia arriba
         rounded = (fraction < 0.50) ? floor : (floor + 1.0);
       } else {
         rounded = current;
       }

       ventaCtrl.text = rounded.toStringAsFixed(2);
       recalcularHaciaAtrasDesdeVisual(fromMargen: false);
     }
     ```
  2. **Micro-Animaciones con `AnimatedScale` y Resplandor:**
     * Dotar a los chips de sugerencia (`+ Principal`, `+ Docena`, etc.) y a los chips de redondeo (`.50`, `.90`, `.00`) de un estado de activación temporal con `AnimatedScale(scale: 0.92)` y rebote elástico a `1.0`, con realce momentáneo de color verde esmeralda y háptica táctil suave.

---

### PUNTO 5: Refinamiento de Borrador Real y Supresión de Falsas Alertas
* **Problema A — Borrador Fantasma Permanente en `Crear Producto` (`Imagen 5`):**
  * En `product_create_draft.dart:68`, `hasMeaningfulData` evalúa:
    ```dart
    final pVenta = (p0['precioVenta'] ?? '').toString().trim();
    if (... || pVenta.isNotEmpty || ...) return true;
    ```
  * En `product_controller_factory.dart:40`, toda presentación inicial se instancia con `precioVenta = "0.00"`.
  * Como `"0.00"` **no está vacío**, `hasMeaningfulData` retorna `true` desde el primer milisegundo en que se abre la pantalla sin que el usuario haya escrito nada.
  * Esto desencadena:
    * Almacenamiento inmediato de un borrador en `InventoryProvider.saveCreationDraft`.
    * Aparición del badge `"Borrador"` en el `AppBar`.
    * Activación en el Home del `PersistentWorkDock` con el cartel `"Producto en Creación: Nuevo Pr..."`.
    * Visibilidad permanente del botón de escoba `"Limpiar Todo"`.
* **Problema B — Falsa Alarma de "¿Descartar Cambios?" en `Editar Producto`:**
  * En `product_edit_change_detector.dart:34`:
    ```dart
    if (selectedCategoryId != p.categoriaId) return true;
    ```
  * En el modelo `Product` (`product_model.dart:205`), `categoriaId` es un `int` no anulable que vale `0` si el producto no tiene categoría.
  * En `product_edit_operations.dart:45-47`, si `categoriaId == 0`, se asigna `_selectedCategoryId = null`.
  * Como consecuencia: `null != 0` evalúa a `true`, disparando falsamente el modal de confirmación al presionar "Atrás".
  * Lo mismo ocurre con variaciones de formateo numérico (`"8"` vs `"8.00"`, `""` vs `"0.00"`).
* **Solución a Implementar:**
  1. **Definición Estricta de `hasRealData` en Borrador:**
     * Modificar `hasMeaningfulData` en `ProductCreateDraft`:
       * Ignorar valores por defecto de inicialización (`precioVenta == "0.00"` o `"0"`, `costoPres == "0.00"` o `"0"`, `unidadesVenta == "1"`).
       * Exigir que exista al menos: nombre $> 0$ letras, descripción $> 0$ letras, marca/categoría/proveedor con ID válido $> 0$ o diferido, imagen no vacía, código de barras no vacío, más de 1 variante, o en la primera variante: nombre específico no vacío, precio venta $> 0$, costo $> 0$ o stock $> 0$.
     * En `product_create_screen.dart`, animar con `AnimatedOpacity` / `AnimatedCrossFade` la aparición del badge `"Borrador"` y del botón `"Limpiar Todo"`, manteniéndolos completamente invisibles mientras el formulario esté en su estado inicial puro.
  2. **Normalización Forense en `ProductEditChangeDetector`:**
     * Tratar `null` y `0` como equivalentes para `categoriaId`, `marcaId` y `proveedorId`.
     * Comparar costos y precios numéricamente mediante `double.tryParse` con tolerancia epsilon ($1e-4$) en lugar de comparaciones directas de cadenas de texto.
     * Garantizar que salir de un producto sin editar no active jamás la alerta de descarte.

---

### PUNTO 6: Control Inteligente del Teclado y Cierre Fuera del Foco
* **Problema Detectado:**
  * Al cerrar modales o bottom sheets (como el selector de categoría o diálogos), el foco queda flotando o Flutter restaura el foco al campo previo, desplegando el teclado virtual de forma imprevista.
  * En `ProductEditScreen`, no existe `GestureDetector` global para cerrar el teclado al tocar fuera de los campos.
* **Solución a Implementar:**
  1. **Desenfoque Previo y Posterior a Modales:**
     * En todos los métodos de apertura (`ProductEntityPickers`, modales de reordenar y diálogos), ejecutar `FocusManager.instance.primaryFocus?.unfocus()` inmediatamente antes de invocar `showModalBottomSheet` / `showDialog` y al retornar.
  2. **Despliegue Responsivo de `onTapOutside` en Inputs:**
     * En `MiniInput` (`presentation_custom_field.dart`), agregar `onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus()`.
     * Envolver el cuerpo de `ProductEditScreen` y `ProductCreateScreen` con `GestureDetector(onTap: () => FocusScope.of(context).unfocus(), behavior: HitTestBehavior.translucent)`.

---

### PUNTO 7: Auditoría Visual Periférica (Banner Home, Formulario Global)
* **Problema en `Imagen 5`:**
  * En `home_screen.dart:272`, el `QuotationBanner` se desplaza detrás de la barra de estado del sistema (íconos de hora `9:50`, batería y red) porque el scroll view no cuenta con `SafeArea(top: true)` ni padding superior defensivo cuando el usuario se desplaza verticalmente.
* **Solución a Implementar:**
  1. **Blindaje de Barra de Estado en Home:** Integrar `SafeArea(top: true, bottom: false)` o un degradado sutil de protección superior en `home_screen.dart` para evitar que el texto de las tarjetas choque contra la barra de estado.
  2. **Refinamiento de Secciones Opcionales en Producto:**
     * `Detalles Globales (Opcional)`: Asegurar que el `ExpansionTile` tenga un borde sutil y padding uniforme.
     * `Módulo de Descuentos`: Garantizar que cuando la promoción esté desactivada el contenedor permanezca compacto y sin consumir espacio vertical excesivo.

---

## 2. ARQUITECTURA DE SOLUCIÓN Y WHITELIST CANÓNICO SQLITE

Para erradicar definitivamente cualquier caída por columnas inexistentes en SQLite, se implementará en `ProductRepository` la siguiente arquitectura de sanitización estricta:

```dart
/// Whitelists oficiales basados en el esquema de local_db.dart
static const Set<String> _kProductoColumns = {
  'id',
  'negocio_id',
  'categoria_id',
  'marca_id',
  'codigo_barras',
  'nombre',
  'descripcion',
  'imagen_url',
  'estado',
  'fecha_actualizacion',
};

static const Set<String> _kPresentacionColumns = {
  'id',
  'producto_id',
  'proveedor_id',
  'nombre_especifico',
  'descripcion',
  'imagen_url',
  'codigo_barras',
  'ump_compra',
  'precio_ump_proveedor',
  'cantidad_ump_comprada',
  'total_pago_lote',
  'unidades_por_lote',
  'factura_carga_id',
  'unidad_venta',
  'unidades_por_venta',
  'costo_unitario_calculado',
  'factor_ganancia_venta',
  'precio_venta_final',
  'precio_oferta',
  'tipo_descuento',
  'valor_descuento',
  'stock_actual',
  'estado',
  'stock_alerta',
  'es_default',
  'orden',
  'activo',
};
```

Antes de invocar `txn.insert` o `txn.update`, se ejecutará un filtro que remueve cualquier campo temporal o de orquestación (`proveedor_id` en productos, `deferred_*`, etc.):
```dart
productData.removeWhere((key, _) => !_kProductoColumns.contains(key));
presData.removeWhere((key, _) => !_kPresentacionColumns.contains(key));
```

---

## 3. MATRIZ DE ARCHIVOS A INTERVENIR

| Archivo | Ubicación | Naturaleza del Cambio |
| :--- | :--- | :--- |
| `product_repository.dart` | `lib/features/catalog/repositories/` | Sanitización de columnas SQLite en `createFullProductTransaction` y `editFullProductTransaction`. |
| `product_service.dart` | `lib/features/catalog/services/` | Captura de excepciones reales y retorno de mensajes explicativos hacia el provider. |
| `inventory_provider.dart` | `lib/features/catalog/providers/` | Asignación y persistencia de `_errorMessage` para que la UI reciba la causa real del error. |
| `product_create_operations.dart` | `lib/features/catalog/widgets/form/` | Mensajes de error claros, validación de borrador y resiliencia al guardar. |
| `product_edit_operations.dart` | `lib/features/catalog/widgets/edit/product_edit/` | Feedback de error al guardar y corrección de mapeo de categorías nulas/cero. |
| `product_create_draft.dart` | `lib/features/catalog/models/` | Corrección de `hasMeaningfulData` para descartar `"0.00"` y valores por defecto. |
| `product_edit_change_detector.dart` | `lib/features/catalog/widgets/edit/product_edit/` | Normalización `null == 0` en IDs y comparación numérica de precios/costos. |
| `modern_entity_picker_modal.dart` | `lib/core/widgets/` | Deduplicación de ítems especiales y experiencia táctil (Press $\rightarrow$ Drag-to-Cancel $\rightarrow$ Release). |
| `modern_entity_selector_field.dart` | `lib/core/widgets/` | Ajuste de etiquetas y auto-ajuste tipográfico para evitar recortes con puntos suspensivos. |
| `product_entity_pickers.dart` | `lib/features/catalog/widgets/form/` | Nombres legibles y desenfoque previo de teclado antes de abrir modales. |
| `presentation_card_header.dart` | `lib/core/widgets/presentation_card/` | Rediseño limpio + cajón replegable de acciones operativas `[ ⋯ ]`. |
| `presentation_card_collapsed_view.dart` | `lib/core/widgets/presentation_card/` | Eliminación del icono duplicado de chevron `v`. |
| `variant_section_header.dart` | `lib/features/catalog/widgets/variants/` | Disposición responsiva anti-desborde en cabecera de variantes. |
| `variant_jump_bar.dart` | `lib/features/catalog/widgets/variants/` | Supresión de la doble estrella (`⭐ ⭐`) en chip de variante principal. |
| `presentation_math_engine.dart` | `lib/core/widgets/presentation_card/` | Regla matemática exacta de redondeo (.50, .90, .00) y recálculo de margen. |
| `presentation_pricing_section.dart` | `lib/core/widgets/presentation_card/` | Chips de redondeo animados con feedback táctil y visual reactivo. |
| `presentation_suggestion_chips.dart` | `lib/core/widgets/presentation_card/` | Micro-animación elástica al seleccionar sugerencias de nombres. |
| `presentation_custom_field.dart` | `lib/core/widgets/presentation_card/` | Desenfoque automático con `onTapOutside` en `MiniInput`. |
| `product_create_screen.dart` | `lib/features/catalog/screens/` | Visibilidad condicional animada de `"Borrador"` y escoba `"Limpiar Todo"`. |
| `product_edit_screen.dart` | `lib/features/catalog/screens/` | `GestureDetector` global para desenfoque y blindaje de `PopScope`. |
| `home_screen.dart` | `lib/core/screens/` | `SafeArea` superior para evitar solapamiento del banner bajo la barra de estado. |

---

## 4. FASES DE EJECUCIÓN (LOOP AUTÓNOMO + ÁRBITRO ADVERSARIAL)

### FASE 1: Transaccionalidad SQLite y Eliminación del "Error:" en Rojo (Punto 1)
1. **Acción:**
   * En `product_repository.dart`, aplicar la sanitización con whitelists `_kProductoColumns` y `_kPresentacionColumns` en `createFullProductTransaction` y `editFullProductTransaction`.
   * En `product_service.dart`, encapsular los fallos extrayendo el mensaje real de SQLite (`e.toString()`).
   * En `inventory_provider.dart`, asignar `_errorMessage` cuando ocurra un fallo y limpiarla en operaciones exitosas.
   * En `product_create_operations.dart` y `product_edit_operations.dart`, asegurar feedback visual informativo si ocurre una anomalía.
2. **Verificación Adversarial:**
   * Ejecutar pruebas unitarias de persistencia simulada con inserción y edición de productos con y sin marca, categoría y proveedor diferido.
   * Verificar que `createFullProduct` y `editFullProduct` retornen `true` y muestren el diálogo de éxito animado.

---

### FASE 2: Experiencia Táctil y Deduplicación en Selector de Entidades (Punto 2)
1. **Acción:**
   * En `modern_entity_picker_modal.dart`, eliminar la duplicación de ítems especiales en la lista de resultados.
   * Implementar `_PickerItemTile` con `GestureDetector` gestionando `onTapDown` (presión con micro-escala), `onTapCancel` (cancelación al deslizar) y `onTapUp` (confirmación con checkmark animado, háptica y cierre fluido).
   * En `modern_entity_selector_field.dart`, ajustar la visualización para prevenir `"Sin categoría ..."`.
2. **Verificación Adversarial:**
   * Ejecutar pruebas de widgets verificando que mantener presionado y arrastrar cancele la selección sin cerrar el modal, y soltar confirme la entidad seleccionada.

---

### FASE 3: Reestructuración de Cabezales y Variantes (Punto 3)
1. **Acción:**
   * Rediseñar `presentation_card_header.dart` dejando visibles únicamente la insignia de variante y el toggle de expansión/herramientas, agrupando las acciones operativas (`Hacer Principal`, `Visible`, `▲`, `▼`, `Clonar`, `Eliminar`) dentro de un panel replegable animado `[ ⋯ ]`.
   * Eliminar la flecha redundante en `presentation_card_collapsed_view.dart`.
   * Ajustar la cabecera `variant_section_header.dart` para evitar que los botones se corten en el borde derecho.
   * Corregir el chip en `variant_jump_bar.dart` eliminando la estrella duplicada (`⭐ Principal`).
2. **Verificación Adversarial:**
   * Ejecutar pruebas de renderizado en anchos de pantalla reducidos (320px, 360px) comprobando que no existan desbordamientos de pixeles (Zero Overflow).

---

### FASE 4: Precisión Matemática de Redondeo y Animaciones de Chips (Punto 4)
1. **Acción:**
   * En `presentation_math_engine.dart`, implementar el algoritmo exacto para `.50` (fija decimal en `.50` manteniendo el entero actual), `.90` (fija decimal en `.90` manteniendo el entero actual) y `.00` (evalúa $< 0.50$ al piso o $\ge 0.50$ al techo).
   * En `presentation_pricing_section.dart` y `presentation_suggestion_chips.dart`, incorporar `AnimatedScale` y feedback de pulsación táctil con cambio dinámico de color.
2. **Verificación Adversarial:**
   * Crear batería de tests unitarios evaluando casos límite: `13.80` $\rightarrow$ `.50` = `13.50`, `.90` = `13.90`, `.00` = `14.00`; `13.20` $\rightarrow$ `.50` = `13.50`, `.90` = `13.90`, `.00` = `13.00`.

---

### FASE 5: Saneamiento de Borrador y Falsas Alertas de Cambios (Punto 5)
1. **Acción:**
   * En `product_create_draft.dart`, refinar `hasMeaningfulData` descartando valores por defecto (`"0.00"`, `"1"`, `null`, `0`).
   * En `product_create_screen.dart`, ocultar el badge `"Borrador"` y la escoba `"Limpiar Todo"` hasta que existan datos reales ingresados.
   * En `product_edit_change_detector.dart`, normalizar `null == 0` para categoría y marca, y comparar valores numéricos de costos y precios por valor decimal.
2. **Verificación Adversarial:**
   * Validar que al ingresar a Crear Producto y salir, no se cree borrador en el Home (`PersistentWorkDock`).
   * Validar que al abrir un producto para editar y presionar "Atrás" sin cambios, no aparezca la advertencia de descarte.

---

### FASE 6: Control Inteligente del Teclado y Blindaje Periférico (Puntos 6 y 7)
1. **Acción:**
   * Configurar `onTapOutside` en los `TextField` de las tarjetas para ocultar el teclado con cualquier toque externo.
   * Agregar desenfoque explícito antes y después de abrir modales o bottom sheets para evitar reaperturas fantasma del teclado.
   * En `home_screen.dart`, añadir protección superior de barra de estado para que el `QuotationBanner` no quede cubierto por el reloj de la barra de estado.
2. **Verificación Adversarial:**
   * Comprobar en flujo de testing que ningún modal reabra el teclado al cerrarse.
   * Comprobar que en Home la barra de estado no se superponga con el banner de cotizaciones.

---

## 5. CRITERIOS DE ACEPTACIÓN Y PRUEBAS AUTOMATIZADAS

1. **`flutter test` Exitoso al 100%:** Todas las pruebas existentes y nuevas suites de tests deben pasar en verde sin regresiones.
2. **Persistencia Garantizada:** Crear y editar productos sin error de columnas en SQLite, ejecutando el diálogo animado de éxito.
3. **Cero Duplicados en Modales:** Las opciones `"Sin marca"`, `"Sin categoría"` y `"Sin proveedor"` se muestran exactamente una vez.
4. **Cero Desbordamientos (Zero Overflows):** Ningún elemento de las variantes colisiona ni desborda en pantallas angostas.
5. **Matemática Verificada:** Los chips de redondeo aplican exactamente las reglas definidas.
6. **Borrador Limpio:** La pantalla inicial no genera borradores fantasmas ni muestra alertas de descarte inmerecidas.
