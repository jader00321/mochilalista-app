# Plan de Trabajo: Corrección del Módulo Escáner de Facturas (v1)

## Contexto y Diagnóstico

El módulo de Escáner y Conciliación de Facturas (`features/scanner/`) presenta 7 problemas críticos interconectados que afectan la estabilidad del estado, la precisión de la búsqueda, la experiencia de usuario y la lógica financiera.

---

## Hallazgos del Análisis Profundo

### 🔴 BUG CRÍTICO 1: Fuga de Estado (State Leak)

**Archivo raíz:** [`manual_product_search.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/widgets/manual_product_search.dart)

El modal de búsqueda de facturas (`ManualProductSearch`) está directamente acoplado al `InventoryProvider` global. En la **línea 49**, al buscar un producto:

```dart
await Provider.of<InventoryProvider>(context, listen: false).loadInventory(
  reset: true,
  searchQuery: query
);
```

Esto **destruye el estado de la pantalla de Inventario principal**:
- Resetea los filtros activos (`_lastCategoryIds`, `_lastBrandIds`, etc.)
- Reemplaza `_inventoryItems` con resultados parciales de la búsqueda del modal
- Cuando el usuario cierra el modal y vuelve al Inventario, ve datos contaminados

Además, en [`staging_product_group_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/staging_product_group_card.dart) **línea 35-36**, al vincular un producto, se consume `invProv.items` directamente para extraer los siblings, lo cual agrava la contaminación.

### 🔴 BUG CRÍTICO 2: Sin Paginación en el Modal

**Archivo:** [`manual_product_search.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/widgets/manual_product_search.dart)

El `InventoryProvider` tiene `_limit = 20` (línea 28 de `inventory_provider.dart`). El modal muestra los `results = invProv.items` directamente (línea 62), pero **nunca implementa `loadMore()`**. El `ListView.separated` no tiene listener de scroll para cargar más datos. Resultado: máximo 20 resultados visibles siempre.

### 🟡 BUG 3: Selector de Variantes como Dropdown

**Archivo:** [`variant_editor_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart) — método `_buildVariantSwitcher()` (línea 322)

El selector de variantes está implementado como un `DropdownButton<int>`, lo cual:
- No permite ver visualmente los detalles de cada variante antes de seleccionarla
- Solo muestra nombre y stock en texto plano truncado
- Contrasta con la UX esperada de tarjetas desplazables (horizontal scroll cards)

### 🟡 BUG 4: Modal Comparativo Incompleto

**Archivo:** [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart) — `ComparativeUpdateModal`

Al abrir "Comparar" (línea 241 de `variant_editor_row.dart`), el modal recibe `dbData` que es el mapa raw de la presentación. Sin embargo:
- No muestra el **nombre del producto padre** ni su **marca** ni **categoría**
- Solo muestra la sección de "Costos y Precios" pero no identifica visualmente *qué* producto se está comparando
- Falta un encabezado con: Nombre Producto, Marca, Presentación actual, Categoría, Unidad de Venta

### 🟡 BUG 5: Unidad de Venta No Editable en Modal Comparativo

**Archivo:** [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart) — `_buildGroupedSaleRow()` (línea 156)

Los campos "Unidad" y "Factor" están condicionados a `widget.variant.updateCosto || widget.variant.updatePrecio` (líneas 190-198), pero **no tienen checkbox propio**. Esto significa que:
- Si el usuario solo quiere cambiar la unidad de venta (ej: de "Unidad" a "Docena"), debe activar el checkbox de Costo O el de Precio
- No se puede editar la unidad de venta de forma independiente
- Al cambiar la unidad de venta, no se dispara un recálculo automático del costo de presentación ni del precio sugerido

### 🟡 BUG 6: Sin Botón Restaurar

No existe ningún mecanismo para revertir los cambios hechos a un producto individual. El modelo `StagingVariant` no almacena una copia de sus valores originales de factura. Si el usuario edita mal un costo o un margen, debe recordar el valor anterior o volver a escanear.

### 🟡 BUG 7: Motor de Búsqueda Sin Tolerancia Singular/Plural

**Archivo:** [`scanner_matching_engine.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_matching_engine.dart) — líneas 62-78

La búsqueda tokenizada es estrictamente literal:
```dart
whereClause += ' AND nombre LIKE ?';
whereArgs.add('%$token%');
```

Si la factura dice "Lápices" y la BD tiene "Lápiz", el `LIKE %Lápices%` nunca matcheará "Lápiz". Lo mismo ocurre con:
- "Cuadernos" vs "Cuaderno"
- "Borrador" vs "Borradores"
- "Colores" vs "Color"

La función `_calculateSimilarity()` (línea 212) compara tokens con `==` exacto, sin ninguna normalización morfológica.

---

## Plan de Trabajo por Fases

---

### Fase 1: Desvinculación de Estado y Paginación Infinita

> **Objetivo:** Eliminar la fuga de estado entre el modal de búsqueda del escáner y el inventario principal. Implementar scroll infinito.

#### [MODIFY] [`manual_product_search.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/widgets/manual_product_search.dart)

**Cambio arquitectónico:** Reemplazar completamente la dependencia de `InventoryProvider` por queries SQLite directas e independientes dentro del propio widget:

1. **Estado local completo:**
   - Crear variables locales: `List<InventoryWrapper> _localResults = []`, `bool _hasMore = true`, `int _skip = 0`, `final int _pageSize = 20`
   - Eliminar toda referencia a `Provider.of<InventoryProvider>`

2. **Búsqueda independiente:**
   - Crear método `_searchProducts(String query, {bool reset = true})` que ejecute directamente la query de `ProductQueries.fullInventoryQuery` con parámetros `LIMIT` y `OFFSET` sobre `LocalDatabase.instance`
   - La búsqueda será local (SQLite), completamente aislada del provider global

3. **Infinite scroll:**
   - Añadir un `ScrollController` con listener que detecte cuando el usuario se acerca al final (`scrollController.position.maxScrollExtent - 200`)
   - Al dispararse, llamar `_searchProducts(currentQuery, reset: false)` que incrementa `_skip` y hace `addAll`

4. **Limpieza al cerrar:**
   - Al cerrar el modal, no se contamina ningún estado global

#### [MODIFY] [`staging_product_group_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/staging_product_group_card.dart)

- En `_showProductSearchModal` (línea 28), refactorizar el callback `onSelect` para que al vincular un producto, busque los siblings directamente desde SQLite en vez de consumir `invProv.items`
- Mantener solo el uso de `invProv.getBrandName()` y `invProv.getCategoryName()` (datos de catálogo maestro, no de búsqueda)

---

### Fase 2: Mejora del Algoritmo de Búsqueda (Fuzzy Matching)

> **Objetivo:** Que el motor de búsqueda reconozca igualdades entre singulares/plurales y variaciones morfológicas comunes en español.

#### [MODIFY] [`scanner_matching_engine.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_matching_engine.dart)

1. **Implementar lematización básica en español:**
   - Crear método estático `String _lemmatize(String word)` que aplique reglas de reducción:
     - Eliminar sufijos plurales: `-es`, `-s` (con reglas para "-ces" → "-z", "-ices" → "-iz")
     - Normalizar acentos: `á→a`, `é→e`, `í→i`, `ó→o`, `ú→u`
     - Normalizar diminutivos comunes: `-ito`, `-ita`, `-itos`, `-itas`
   - Aplicar el lematizador tanto al token de búsqueda como al SQL WHERE (usando LIKE sobre la raíz lematizada)

2. **Mejorar `_calculateSimilarity()`:**
   - Aplicar lematización antes de comparar tokens
   - Implementar **distancia de Levenshtein** ligera para tolerancia a typos (umbral ≤ 2 caracteres)
   - Ponderar matches parciales: coincidencia exacta = 100, lematizada = 85, Levenshtein = 70

3. **Expandir la query SQL:**
   - Generar variantes lematizadas de cada token para el WHERE (ej: "Lápices" → buscar LIKE '%lápiz%' OR LIKE '%lápice%')
   - Mantener un fallback con tokens originales si la lematización no produce resultados

#### [NEW] `lib/features/scanner/services/spanish_lemmatizer.dart`

Crear un servicio utilitario dedicado a la lematización básica en español, reutilizable tanto por el `ScannerMatchingEngine` como por la búsqueda del modal.

---

### Fase 3: Rediseño UI del Buscador y Selector de Variantes

> **Objetivo:** Mejorar la visualización del modal de búsqueda y restaurar el selector de variantes como tarjetas con scroll horizontal.

#### [MODIFY] [`manual_product_search.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/widgets/manual_product_search.dart)

En `_buildResultCard()` (línea 135):

1. **Separar visualmente Marca y Categoría:**
   - Categoría: chip con fondo naranja (ya existe) pero con padding más generoso
   - Marca: chip con fondo distinto (azul-gris/blueGrey), con icono de marca, y separado con `SizedBox(width: 8)` + en su propia línea si el espacio es limitado
   - Usar `Wrap` en vez de `Row` para evitar desbordamiento

2. **Enriquecer información visible:**
   - Mostrar el nombre de la presentación/variante de forma más prominente
   - Mostrar el Precio de Venta y Costo actual como chips informativos debajo del stock

#### [MODIFY] [`variant_editor_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart)

Reemplazar `_buildVariantSwitcher()` (línea 322) — el `DropdownButton` actual — por un diseño de **tarjetas horizontales con scroll:**

1. **Diseño nuevo:**
   - `SizedBox(height: ~90)` con `ListView.builder` horizontal
   - Cada tarjeta muestra: nombre de la variante, unidad de venta, stock actual, precio actual
   - La tarjeta seleccionada tiene borde resaltado (verde/azul)
   - Última tarjeta especial: "➕ Crear Nueva" con borde punteado

2. **Interacción:**
   - `onTap` en cada tarjeta llama a `provider.switchVariantLink()` o `provider.switchVariantToNew()`
   - Animación de selección con `AnimatedContainer`

---

### Fase 4: Lógica Financiera, Cálculos Inteligentes y Modal Enriquecido

> **Objetivo:** Permitir edición libre de la Unidad de Venta con recálculo inteligente, y enriquecer el modal comparativo con toda la información del producto.

#### [MODIFY] [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart)

1. **Encabezado enriquecido del modal (`ComparativeUpdateModal`):**
   - Antes de la sección "Actualización de Costos y Precios", agregar una card informativa con:
     - **Nombre del producto padre** (extraer del `group` o pasar como parámetro)
     - **Marca** y **Categoría** como chips
     - **Nombre de la Presentación/Variante** que se está editando
     - **Imagen** del producto si existe
   - Esto requiere pasar `StagingProductGroup group` como parámetro adicional al modal

2. **Unidad de Venta editable con recálculo:**
   - Agregar un checkbox propio para "Actualizar Forma de Venta" independiente de Costo y Precio
   - Al cambiar la unidad de venta (ej: "Unidad" → "Docena"), disparar `_onUnidadVentaChanged()` que:
     - Auto-detecte el factor (Docena=12, Ciento=100, Gruesa=144, etc.)
     - Recalcule el Costo de Presentación = CostoUnitario × NuevoFactor
     - Recalcule el Precio sugerido = NuevoCostoPresentación × Margen

3. **Propagación de contexto:**
   - En [`variant_editor_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart), al abrir el modal comparativo (línea 161), pasar el `group` completo para que el modal tenga acceso a nombre padre, marca y categoría

---

### Fase 5: Botón Restaurar por Producto

> **Objetivo:** Permitir al usuario revertir los cambios de un producto individual a sus valores originales de factura.

#### [MODIFY] [`scanner_models.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/models/scanner_models.dart)

En la clase `StagingVariant` (línea 182):

1. **Agregar campos de respaldo:**
   ```dart
   // Backup de valores originales de factura (set una vez en initState)
   late final double _originalCostoSugerido;
   late final double _originalMargen;
   late final double _originalPrecioVenta;
   late final String _originalNombreEspecifico;
   late final String _originalUnidadVenta;
   late final int _originalUnidadesPorVenta;
   ```

2. **Método de restauración:**
   ```dart
   void restoreOriginals() {
     costoUnitarioSugerido = _originalCostoSugerido;
     factorGananciaVentaSugerido = _originalMargen;
     precioVentaSugerido = _originalPrecioVenta;
     // etc.
   }
   ```

3. **Getter de detección:**
   ```dart
   bool get hasBeenModified => costoUnitarioSugerido != _originalCostoSugerido || ...;
   ```

#### [MODIFY] [`variant_editor_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart)

- Agregar un `IconButton` con `Icons.restore` junto al botón de eliminar (línea 198)
- Solo visible cuando `variant.hasBeenModified == true`
- `onPressed`: llama `variant.restoreOriginals()`, reinicializa controladores, y `setState`

#### [MODIFY] [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart)

- En el AppBar/header del modal comparativo, agregar un botón de "Restaurar valores originales"
- Al presionar, llama `variant.restoreOriginals()`, reinicializa los controladores del modal, y hace `setState`

---

## Verificación

### Pruebas Manuales
1. Abrir el Inventario principal → verificar que se carga normalmente
2. Ir al Escáner → escanear una factura → llegar a la pantalla de Staging
3. Abrir el modal de búsqueda → buscar un producto → verificar que el Inventario principal NO se alteró al cerrar el modal
4. Verificar infinite scroll en el modal (más de 20 resultados)
5. Verificar que "Lápices" encuentra "Lápiz" y viceversa
6. Verificar el selector de variantes como tarjetas horizontales
7. Verificar que el modal comparativo muestra nombre, marca, categoría
8. Verificar que al cambiar la unidad de venta se recalcula todo
9. Verificar el botón restaurar en ambos contextos (row y modal)

### Validación Estática
```
flutter analyze lib/features/scanner/
flutter analyze lib/core/widgets/manual_product_search.dart
```

---

## Resumen de Archivos Afectados

| Archivo | Fase | Acción |
|---------|------|--------|
| `core/widgets/manual_product_search.dart` | 1, 3 | MODIFY (desacoplar estado + UI) |
| `scanner/widgets/staging/staging_product_group_card.dart` | 1 | MODIFY (siblings desde SQLite) |
| `scanner/services/scanner_matching_engine.dart` | 2 | MODIFY (lematización + fuzzy) |
| `scanner/services/spanish_lemmatizer.dart` | 2 | NEW |
| `scanner/widgets/staging/variant_editor_row.dart` | 3, 5 | MODIFY (tarjetas + restaurar) |
| `scanner/widgets/staging/variant_price_calculator.dart` | 4, 5 | MODIFY (modal enriquecido + restaurar) |
| `scanner/models/scanner_models.dart` | 5 | MODIFY (backup fields) |

> [!IMPORTANT]
> **La Fase 1 es bloqueante y debe ejecutarse primero.** La fuga de estado es un bug que afecta al usuario en producción cada vez que usa el escáner de facturas. Las demás fases pueden ejecutarse en cualquier orden tras la Fase 1.
