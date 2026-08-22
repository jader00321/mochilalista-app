# Corrección de Regresiones v1 — Módulo Escáner de Facturas

## Contexto y Diagnóstico Post-Auditoría

El plan v1 se ejecutó parcialmente. Varias correcciones se implementaron correctamente (desacoplamiento del `InventoryProvider`, tarjetas horizontales, botón restaurar, modal enriquecido), pero surgieron **regresiones críticas** y funcionalidades incompletas. Este plan las aborda todas.

### Estado Actual del Código vs. Plan v1

| Ítem del Plan v1 | Estado Actual | Regresión/Pendiente |
|---|---|---|
| Desacoplar búsqueda del `InventoryProvider` | ✅ Implementado via `ProductService` independiente | 🔴 **Buscador retorna 0 resultados** (ver Bug 1) |
| Infinite Scroll | ✅ Implementado con `ScrollController` | ✅ Funciona correctamente |
| Lematización (Spanish Lemmatizer) | ✅ Servicio creado y utilizado | ✅ Funciona correctamente |
| Tarjetas horizontales de variantes | ✅ `_buildVariantCards()` implementado | ✅ Funciona correctamente |
| Botón Restaurar | ✅ Implementado en modelo y UI | ✅ Funciona correctamente |
| Modal enriquecido (nombre, marca, categoría) | ✅ Implementado con `group` param | ✅ Funciona correctamente |
| Checkbox independiente de Unidad de Venta | ✅ `updateUnidadVenta` separado | ✅ Funciona correctamente |
| **Inyección de datos de variante vinculada** | ❌ **Nunca se implementó** | 🔴 **Bug "Amnesia" (S/ 0.00)** |
| **Sistema dual de unidades** | ❌ **No implementado** | 🟡 Pendiente |
| **Recálculo al cambiar presentación en modal** | ❌ **No implementado** | 🟡 Pendiente |

---

## 🔴 HALLAZGOS CRÍTICOS DEL ANÁLISIS

### Bug 1: Buscador Retorna 0 Resultados

**Archivos involucrados:**
- [`manual_product_search.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/widgets/manual_product_search.dart) → Líneas 36-40, 84-88
- [`product_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/services/product_service.dart) → Líneas 14-23
- [`product_repository.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/repositories/product_repository.dart) → Líneas 10-69

**Causa raíz:** El widget `ManualProductSearch` crea una instancia **nueva** de `ProductService` (línea 21) y llama `_productService.updateContext(invProv.negocioId)` en `initState`. Sin embargo, el `ProductService` pasa el `negocioId` a su `ProductRepository` interno, que ejecuta `ProductQueries.fullInventoryQuery`. 

El problema está en la **cadena de parseo de parámetros** en `fetchInventoryRaw`:

```dart
// product_repository.dart L62-63
args.add(int.parse(queryParams['limit'] ?? '20'));  // ← Funciona OK si limit es String
args.add(int.parse(queryParams['skip'] ?? '0'));      // ← Funciona OK si skip es String
```

Pero en `manual_product_search.dart` L84-88:
```dart
final newItems = await _productService.fetchInventory({
  'q': query.isEmpty ? null : query,
  'skip': _skip,      // ← AQUÍ: _skip es int, NO String
  'limit': _limit,    // ← AQUÍ: _limit es int, NO String
});
```

Y en `product_repository.dart` L62:
```dart
args.add(int.parse(queryParams['limit'] ?? '20'));
```

`int.parse()` lanza `FormatException` cuando recibe un `int` en lugar de `String`, porque `queryParams['limit']` ya es un `int` (`20`) y `int.toString()` nunca se llama. Esto causa que `fetchInventoryRaw` caiga en el `catch` (L66-68) y retorne una lista vacía `[]`.

> [!CAUTION]
> Este es un bug silencioso. El `catch` en `ProductRepository.fetchInventoryRaw` retorna `[]` sin propagar el error, y `ProductService.fetchInventory` retorna `null` solo si `_negocioId == null`. El resultado `[]` se interpreta como "0 resultados" en la UI.

### Bug 2: "Amnesia de Datos" — S/ 0.00, N/A, Stock 0

**Archivos involucrados:**
- [`scanner_matching_engine.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_matching_engine.dart) → Líneas 106-142
- [`scanner_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/providers/scanner_provider.dart) → Líneas 350-416
- [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart) → Líneas 43-50

**Causa raíz (Matching Automático):** En `scanner_matching_engine.dart`, cuando se encuentra un match con la BD, se extraen los datos de la presentación desde la tabla `presentaciones_producto`:

```dart
// L106-110
final presQuery = await db.query(
  'presentaciones_producto',
  where: 'producto_id = ?',
  whereArgs: [prodId],
);
```

Los nombres de columnas en la tabla SQLite usan `precio_venta_final` y `costo_unitario_calculado`, y estos se pasan correctamente al `MatchData` (L136-137). **PERO** los datos de `availablePresentations` (L140) son los rows crudos de SQLite. El problema aparece cuando el modal comparativo accede a estos datos a través de claves **inconsistentes**:

- El `MatchData` usa `precioVentaFinal` (propiedad Dart)
- El modal comparativo accede a `widget.dbData['precio_costo']` (L305) — que **no existe** en el row crudo de SQLite (la columna se llama `costo_unitario_calculado`)
- El `manualLinkProductGroup()` (L350-416) construye manualmente el mapa de siblings con claves como `precio_venta` y `precio_costo`, pero el matching automático usa los row crudos con claves como `precio_venta_final` y `costo_unitario_calculado`

**Resultado:** Dos fuentes de datos con nomenclaturas diferentes alimentan al mismo modal. El modal comparativo espera `precio_costo` pero recibe `costo_unitario_calculado`, mostrando `S/ 0.00`.

**Causa raíz (Vinculación Manual):** En `scanner_provider.dart` L383-402, `manualLinkProductGroup()` construye `MatchData` con datos de los siblings, pero:
- `costoUnitarioCalculado` se setea desde `bestMatch['precio_costo']` — que sí existe porque el mapa fue construido manualmente en `staging_product_group_card.dart` L54
- Sin embargo, la `StagingVariant` NO actualiza su `costoUnitarioSugerido` ni `precioVentaSugerido` cuando cambia de match. Los controladores del modal comparativo leen de `widget.variant.costoUnitarioSugerido` (L48) que sigue teniendo el valor calculado por el matching engine original (basado en la factura), no el de la BD

> [!IMPORTANT]  
> El `ComparativeUpdateModal` lee sus valores iniciales del `StagingVariant`, NO del `dbData`. Los campos `_costoCtrl`, `_margenCtrl`, `_precioCtrl` se inicializan con `widget.variant.costoUnitarioSugerido` (el valor de la factura), lo cual es correcto para la columna "Nuevo (Factura)". El problema real es que la columna **"Actual (BD)"** lee de `widget.dbData['precio_costo']` — y esa clave no existe en el row crudo de SQLite del matching automático. La corrección debe unificar las claves.

### Bug 3: Falta de Sistema Dual de Unidades

**Archivo:** [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart)

La sección de costos no diferencia entre:
- **Unidad de Compra** (ej. DOC, MLL, CAJA) → Viene de la factura
- **Unidad de Venta** (ej. Unidad, Docena) → Es la unidad en que se vende al cliente
- **Factor de Conversión** (ej. 1 DOC = 12 UND)

Actualmente solo muestra "Unidad" y "Factor" de forma genérica sin contexto.

---

## Plan de Trabajo por Fases

---

### Fase 1: Reparación Crítica de Datos

> **Objetivo:** Que el buscador funcione y que los datos de la variante vinculada se muestren correctamente.

#### [MODIFY] [`product_repository.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/repositories/product_repository.dart)

**Corrección del parseo `int.parse` (L62-63):**

Cambiar la conversión para aceptar tanto `int` como `String`:

```dart
// ANTES:
args.add(int.parse(queryParams['limit'] ?? '20'));
args.add(int.parse(queryParams['skip'] ?? '0'));

// DESPUÉS:
args.add(queryParams['limit'] is int ? queryParams['limit'] : int.parse(queryParams['limit']?.toString() ?? '20'));
args.add(queryParams['skip'] is int ? queryParams['skip'] : int.parse(queryParams['skip']?.toString() ?? '0'));
```

---

#### [MODIFY] [`scanner_matching_engine.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_matching_engine.dart)

**Normalizar `availablePresentations` (L140):**

Los row crudos de SQLite se pasan tal cual a `availablePresentations`. Necesitan un mapeo intermedio que unifique las claves para que sean compatibles con el modal comparativo:

```dart
// Crear método _normalizePresentationRow() que mapee:
// 'costo_unitario_calculado' → 'precio_costo'
// 'precio_venta_final' → 'precio_venta'
// 'unidades_por_venta' → 'factor_conversion'
// 'unidad_venta' → 'unidad'
// etc.
```

Aplicar este mapeo a cada elemento de `presQuery` antes de pasarlo a `availablePresentations`, y también al `bestPres` que se usa para construir el `MatchData`.

---

#### [MODIFY] [`scanner_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/providers/scanner_provider.dart)

**En `switchVariantLink()` (L439-482):**

Actualmente solo actualiza `matchPresentacion` pero NO sincroniza el estado temporal de la variante. Agregar sincronización profunda de los datos de la BD a los campos editables del `StagingVariant`:

```dart
// Después de actualizar matchPresentacion, si la presentación seleccionada tiene datos reales:
// variant.costoUnitarioSugerido = dbData de la presentación seleccionada
// variant.precioVentaSugerido = dbData de la presentación seleccionada  
// variant.factorGananciaVentaSugerido = dbData margen
// variant.unidadVenta = dbData unidad
// variant.unidadesPorVenta = dbData factor
```

> [!IMPORTANT]
> Esta sincronización NO debe ocurrir automáticamente al vincular. Solo debe pre-poblar los campos del `StagingVariant` para que el modal comparativo muestre datos reales en la columna "Nuevo". El usuario decide qué actualizar con los checkboxes.

**En `manualLinkProductGroup()` (L350-416):**

Misma corrección: cuando se encuentra un `bestMatch`, además de actualizar `matchPresentacion`, sincronizar los datos de la presentación de BD al `StagingVariant`. Pero respetar que los valores de factura (`totalPagoLote`, `cantidadUmpComprada`, etc.) no se sobreescriban.

---

### Fase 2: Arquitectura del Estado Temporal

> **Objetivo:** Garantizar que ningún cambio se persiste hasta pulsar "Guardar Decisión" y que el botón "Restaurar" funcione en todos los contextos.

#### [MODIFY] [`scanner_models.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/models/scanner_models.dart)

**Refuerzo del sistema de backup en `StagingVariant`:**

El sistema actual de `_originalXxx` guarda los valores asignados en el constructor. Sin embargo, cuando `switchVariantLink()` sincroniza nuevos datos (Fase 1), los backups se pierden porque son `late final`.

Solución: Los backups deben guardar los valores **de factura** (los calculados por el `ScannerMatchingEngine`), NO los del constructor. Ya están correctos como `late final` porque se setean en el constructor y no cambian.

**Agregar método `snapshotForRestore()`** que permita guardar un snapshot de los valores actuales de la variante antes de que el usuario modifique algo en el modal. Esto permite restaurar al estado "como llegó del matching" independientemente de los edits del usuario:

```dart
// Backup intermedio para el modal (diferente al _original que es de factura)
double? _snapshotCosto;
double? _snapshotMargen;
// ... etc

void takeSnapshot() { ... }
void restoreFromSnapshot() { ... }
```

> [!NOTE]
> `restoreOriginals()` restaura a los valores sugeridos por la IA/factura. `restoreFromSnapshot()` restauraría al último estado estable antes de editar en el modal. Evaluar si se necesitan ambos o solo uno.

#### Verificación del Estado Temporal

El flujo actual ya es correcto en cuanto a que `GUARDAR DECISIÓN` (`_applyChanges()` en `variant_price_calculator.dart` L114-131) solo modifica el `StagingVariant` en memoria. La persistencia real ocurre en `ScannerBatchSaver.executeBatchSave()` al pulsar "GUARDAR E INGRESAR STOCK". No hay auto-save accidental.

---

### Fase 3: Lógica Financiera Avanzada — Sistema Dual de Unidades

> **Objetivo:** Mostrar claramente Unidad de Compra → Factor → Unidad de Venta con cálculos automáticos.

#### [MODIFY] [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart)

**Rediseño de `_buildGroupedSaleRow()` (L231-356):**

Reemplazar la sección actual de costos por un diseño de **3 zonas claramente separadas**:

**Zona 1 — Información de Compra (Solo lectura):**
```
┌─────────────────────────────────────────────┐
│  📦 Datos de la Factura                      │
│  Empaque: DOC  |  Cantidad: 2  |  Total: S/220 │
│  → Costo Unit. Base: S/ 9.17 c/u             │
└─────────────────────────────────────────────┘
```

Datos extraídos directamente de `widget.variant`:
- `umpCompra` (unidad de empaque del proveedor)
- `cantidadUmpComprada`
- `totalPagoLote`
- `unidadesPorLote`
- Costo unitario calculado = `totalPagoLote / (cantidadUmpComprada * unidadesPorLote)`

**Zona 2 — Forma de Venta (Editable con checkbox independiente):**
```
┌─────────────────────────────────────────────┐
│  ☐  Unidad de Venta                         │
│  Actual (BD): Unidad (x1)                    │
│  Nuevo:       [Docena ▼]  Factor: [12]       │
└─────────────────────────────────────────────┘
```

- Checkbox `updateUnidadVenta` (ya existe)
- Al cambiar la unidad, auto-detectar factor (Docena→12, Ciento→100, etc.)
- Disparar recálculo cascada: nuevo costo presentación → nuevo precio sugerido

**Zona 3 — Costos y Precio de Venta (Editables con checkboxes):**
```
┌─────────────────────────────────────────────┐
│  ☑ Costo Unit. Presentación                 │
│  Actual: S/ 8.50    →  Nuevo: [S/ 9.17]     │
│                                              │
│  ☐ Precio de Venta                           │
│  Actual: S/ 12.00   →  Margen: [x1.35]      │
│                         Precio: [S/ 12.38]   │
└─────────────────────────────────────────────┘
```

- Costo Unitario de Presentación = Costo Base × Factor Venta
- Al editar Margen → recalcular Precio
- Al editar Precio → recalcular Margen (inverso)

#### [MODIFY] [`scanner_cost_engine.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_cost_engine.dart)

Agregar método de conveniencia:

```dart
/// Calcula el costo unitario base de la factura
static double calculateInvoiceUnitCost({
  required double totalPago,
  required double cantidadUmp,
  required int unidadesPorLote,
}) => calculateUnitCost(totalPago: totalPago, cantidadUmp: cantidadUmp, unidadesPorLote: unidadesPorLote);
```

(Esto ya existe, pero documentar que es "Costo Base de Factura" para evitar confusión con "Costo de Presentación").

---

### Fase 4: Rediseño UI — Selector de Presentaciones en el Modal Comparativo

> **Objetivo:** Agregar el scroll horizontal de tarjetas de presentaciones dentro del modal `ComparativeUpdateModal` para permitir cambiar de presentación sin cerrar el modal.

#### [MODIFY] [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart)

**Agregar scroll horizontal de presentaciones entre el encabezado y la sección de costos:**

1. Extraer `availablePresentations` del `widget.variant.matchPresentacion.datos`
2. Construir un `ListView.builder` horizontal con tarjetas compactas (similar a `_buildVariantCards()` de `variant_editor_row.dart`)
3. Al tocar una tarjeta diferente:
   - Actualizar `widget.dbData` para que la sección comparativa muestre los datos de la nueva presentación
   - Actualizar `widget.variant.matchPresentacion` con la nueva presentación seleccionada
   - Reinicializar los controladores del modal
   - Llamar `setState()` para refrescar la UI

> [!WARNING]
> Al cambiar de presentación dentro del modal, se debe actualizar tanto el `dbData` (columna "Actual BD") como sincronizar el `MatchData` de la variante. Esto implica que al salir del modal, el `StagingVariant` reflejará la nueva presentación seleccionada.

---

## Open Questions

> [!IMPORTANT]
> **¿Doble restaurar?** ¿Necesitas dos niveles de "Restaurar"?
> 1. **Restaurar a valores de factura** (lo que sugirió la IA): Ya implementado con `restoreOriginals()`
> 2. **Restaurar a valores de BD** (lo que tenía la presentación antes de editar): Requiere un snapshot adicional
> 
> Actualmente solo existe el nivel 1. ¿Implementamos ambos?

> [!IMPORTANT]
> **Sincronización profunda:** Cuando se vincula un producto existente, ¿qué valores del `StagingVariant` deben actualizarse con los de la BD?
> - **Opción A (Conservadora):** Solo actualizar `matchPresentacion.datos` (para la columna "Actual BD" del modal). Los campos editables (`costoUnitarioSugerido`, `precioVentaSugerido`) mantienen los valores calculados de la factura.
> - **Opción B (Sincronización completa):** Pre-poblar los campos editables con los datos de BD, y dejar que el usuario decida qué conservar (los de factura o los de BD) mediante los checkboxes.
>
> Recomiendo **Opción A**: los campos "Nuevo" deben reflejar lo calculado de la factura. El usuario activa checkboxes para decidir qué actualizar. La columna "Actual (BD)" siempre muestra el dato real de la base de datos.

---

## Resumen de Archivos Afectados

| Archivo | Fase | Cambio Principal |
|---------|------|-----------------|
| [`product_repository.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/repositories/product_repository.dart) | 1 | Fix `int.parse` crash — acepta `int` y `String` |
| [`scanner_matching_engine.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_matching_engine.dart) | 1 | Normalizar claves de `availablePresentations` |
| [`scanner_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/providers/scanner_provider.dart) | 1, 2 | Sincronización profunda en `switchVariantLink` y `manualLinkProductGroup` |
| [`scanner_models.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/models/scanner_models.dart) | 2 | Refuerzo de backups, snapshot system |
| [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart) | 3, 4 | Sistema dual de unidades + selector de presentaciones |
| [`scanner_cost_engine.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_cost_engine.dart) | 3 | Documentación y naming clarification |

---

## Verification Plan

### Automated Tests
```bash
cd app_movil && flutter analyze lib/features/scanner/ lib/core/widgets/manual_product_search.dart lib/features/catalog/repositories/product_repository.dart
```

### Manual Verification
1. **Buscador:** Abrir modal → debe cargar lista completa de productos → buscar por texto → verificar resultados → scroll para cargar más
2. **Vinculación:** Seleccionar un producto → modal comparativo debe mostrar datos reales de la BD (no S/ 0.00)
3. **Unidades:** Cambiar "Unidad" a "Docena" → Factor debe auto-rellenarse a 12 → Costo presentación y Precio deben recalcularse
4. **Restaurar:** Modificar valores → icono restaurar debe aparecer → al presionar, volver a valores originales
5. **Selector presentaciones:** En modal comparativo, tocar otra presentación → datos deben cambiar dinámicamente
6. **No auto-save:** Hacer cambios → cerrar modal sin "Guardar" → reabrir → datos deben estar sin cambios
