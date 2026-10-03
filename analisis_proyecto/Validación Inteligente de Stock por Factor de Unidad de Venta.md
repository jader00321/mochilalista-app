# Validación Inteligente de Stock por Factor de Unidad de Venta

## Comprensión del Problema

Actualmente, el sistema permite guardar productos/variantes sin importar si la cantidad de stock es coherente con la unidad de venta elegida. Esto genera **incoherencias financieras y de inventario** graves:

**Ejemplo concreto:**
- El usuario compra **4 unidades** de un producto.
- Elige la unidad de venta **½ Docena (x6)**.
- `4 ÷ 6 = 0` ½ Docenas + **4 sobrantes** → El sistema permite guardar, dejando 4 unidades "flotantes" sin registrar.

Además, existe un **bug crítico en modo edición**: cuando el usuario edita un producto existente y cambia la unidad de venta o factor, el sistema recalcula todo usando datos de factura/compra históricos (que ya no son relevantes), destruyendo el stock actual real.

### Tabla de reglas del negocio

| Escenario | Stock Total | Factor | Resultado | ¿Permitir guardar? |
|-----------|------------|--------|-----------|---------------------|
| **Exacto** | 12 | x6 | 2 ½ Docenas, 0 sobrante | ✅ Sí |
| **Sobrante** | 16 | x6 | 2 ½ Docenas, **4 sobrantes** | ⚠️ Solo si crea variante sobrante |
| **Faltante** | 4 | x6 | 0 ½ Docenas, falta **2** para completar 1 | ❌ No — bloquear |
| **Stock vacío** | 0 | x6 | 0 ½ Docenas | ✅ Sí (nada que validar) |

---

## Diagnóstico de los 5 Contextos Afectados

### 1. Tarjeta de la ventana "Clasificar y Confirmar" (Scanner Staging)
- **Archivo:** [variant_editor_row.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart)
- **Problema:** Calcula `_leftoverSuelto` (línea 142) pero solo muestra un Container informativo naranja. **No bloquea**, **no detecta faltantes**, no genera variante con nombre heredado.

### 2. Modal comparativo (Scanner Staging)
- **Archivo:** [variant_price_calculator.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart)
- **Problema:** `_crearVarianteSobrante()` usa nombre fijo `"Unidad Suelta / Detalle"`. El botón "GUARDAR DECISIÓN" **nunca valida sobrantes/faltantes**.

### 3. Pantalla "Nuevo Producto" (Inventario)
- **Archivos:** [product_create_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/screens/product_create_screen.dart) + [product_presentation_card.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/widgets/product_presentation_card.dart)
- **Problema:** `_save()` no valida residuos. La tarjeta muestra sobrantes pero no bloquea.

### 4. Pantalla "Editar Producto" (Inventario)
- **Archivo:** [product_edit_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/screens/product_edit_screen.dart)
- **Problema:** Misma falta de validación que crear. Además tiene el **bug crítico de recálculo con datos de factura históricos**.

### 5. Batch Save (Guardado masivo de staging)
- **Archivo:** [scanner_batch_saver.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_batch_saver.dart)
- **Problema:** El `.toInt()` en línea 110 trunca silenciosamente los sobrantes. No usa `stockIngresanteOverride`.

---

## 🔴 Bug Crítico: Recálculo con Datos Históricos en Modo Edición

> [!CAUTION]
> Este es el bug más peligroso detectado y se incorpora como parte obligatoria de este plan.

### Causa raíz

En [product_presentation_card.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/widgets/product_presentation_card.dart), el método `_evaluarMatematicaGeneral()` (línea 108) hace:

```dart
void _evaluarMatematicaGeneral() {
    double totalPago = double.tryParse(_totalPagoCtrl.text) ?? 0.0;
    if (totalPago > 0) {
      _recalcularDesdeCompra(); // ← ¡PELIGRO EN MODO EDICIÓN!
    } else {
      _recalcularPrecios(fromMargen: true);
      _unidadesSobrantes = 0; 
      _recalcularStock(); 
    }
}
```

**¿Qué pasa cuando el usuario edita un producto existente?**

1. Al cargar el producto desde BD, los campos de compra (`totalPago`, `cantCompra`, `unidadesLote`) se rellenan con **datos históricos** de la última factura.
2. Cuando el usuario cambia la unidad de venta (ej: de `Unidad x1` a `Docena x12`), el `SmartUnitSelector` dispara `_onUnidadVentaChanged()` → `_evaluarMatematicaGeneral()`.
3. Como `totalPago > 0` (dato histórico), entra a `_recalcularDesdeCompra()`.
4. **Esto recalcula TODO**: sobreescribe el `nuevoIngreso`, el `costoPres`, y los sobrantes usando datos de una factura pasada que **ya no tiene relación con el stock actual**.

### Ejemplo del bug en acción

- Producto tiene `stock_actual = 24` (acumulado de varias facturas y ventas).
- Última factura fue de `totalPago = 45, cantCompra = 0.5 MLL (x1000)`, lo que dio 500 unidades base.
- El usuario cambia la unidad de `Unidad (x1)` a `Docena (x12)`.
- El sistema recalcula: `500 ÷ 12 = 41` docenas con `8 sobrantes` → **Sobreescribe** el `nuevoIngreso` con `41` (que es de la factura vieja), destruyendo el stock real de 24.

### Solución propuesta

Diferenciar entre **"modo creación con datos de compra activos"** y **"modo edición donde los datos de compra son solo referenciales"**. La `ProductPresentationCard` necesita un flag `isEditMode` que cuando es `true`:

- **No ejecuta** `_recalcularDesdeCompra()` al cambiar unidades de venta.
- Solo recalcula **costo de presentación** proporcionalmente al nuevo factor: `nuevoCostoPres = costoBaseIndiv * nuevoFactor`.
- Recalcula **stock visual** dividiendo el `stockInicial` (stock base actual en BD) entre el nuevo factor: `stockVisual = stockBaseActual ÷ nuevoFactor`.
- Los datos de compra quedan como **solo lectura informativa** (se muestran pero no interfieren en el cálculo).

---

## Proposed Changes

### Fase 1: Motor de Validación Centralizado

---

#### [MODIFY] [unit_catalog_service.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/services/unit_catalog_service.dart)

Agregar una nueva clase `StockValidationResult` y un método estático `validateStockForUnit`:

```dart
enum StockValidationStatus { 
  EXACT,        // Stock encaja perfecto con el factor
  HAS_LEFTOVER, // Hay sobrantes que necesitan variante
  DEFICIT,      // No alcanza ni para 1 unidad del factor
  EMPTY         // Stock es 0 — no hay nada que validar
}

class StockValidationResult {
  final int fullUnits;        // Cuántas unidades completas se forman
  final int leftover;         // Unidades sobrantes (< factor)
  final int deficit;          // Cuántas faltan para completar 1 unidad
  final StockValidationStatus status;
  final double costoBaseSobrante;
  
  // Mensajes personalizados para cada situación
  String get userMessage { ... } // Genera mensaje descriptivo según el status
}
```

**Método `validateStockForUnit`:**
```dart
static StockValidationResult validateStockForUnit({
    required int totalUnitsBase,   // Total de unidades individuales
    required int presentationFactor, // Factor de la unidad elegida (ej: 12 para docena)
    required double baseUnitCost,   // Costo base individual
    required String unitName,       // Nombre de la unidad (para mensajes)
}) {
    if (totalUnitsBase == 0) return StockValidationResult(status: EMPTY, ...);
    
    int fullUnits = totalUnitsBase ~/ presentationFactor;
    int leftover = totalUnitsBase % presentationFactor;
    
    if (fullUnits == 0 && leftover > 0) {
        // DEFICIT: no alcanza ni para 1 unidad
        int deficit = presentationFactor - leftover;
        return StockValidationResult(status: DEFICIT, deficit: deficit, ...);
    }
    
    if (leftover > 0) {
        return StockValidationResult(status: HAS_LEFTOVER, leftover: leftover, ...);
    }
    
    return StockValidationResult(status: EXACT, ...);
}
```

Esto **centraliza** la lógica que hoy está dispersa y duplicada en 4 archivos.

---

### Fase 2: Corrección del Bug de Recálculo en Modo Edición

---

#### [MODIFY] [product_presentation_card.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/widgets/product_presentation_card.dart)

**Cambios clave:**

1. **Agregar propiedad `isEditMode`** al widget y al `controllerMap`:
   - Cuando `isEditMode == true`, el campo `controllerMap` incluye `'isEditMode': true` y `'stockBaseOriginal': pres.stockActual` (stock base en BD, en unidades individuales).

2. **Rediseñar `_evaluarMatematicaGeneral()`** para respetar el modo:

```dart
void _evaluarMatematicaGeneral() {
    bool isEdit = widget.controllerMap['isEditMode'] == true;
    double totalPago = double.tryParse(_totalPagoCtrl.text) ?? 0.0;
    
    if (!isEdit && totalPago > 0) {
      // MODO CREACIÓN: datos de factura activos → recalcular desde compra
      _recalcularDesdeCompra();
    } else if (isEdit) {
      // MODO EDICIÓN: datos de factura son solo referenciales
      _recalcularEnModoEdicion();
    } else {
      // Sin datos de compra
      _recalcularPrecios(fromMargen: true);
      _unidadesSobrantes = 0;
      _recalcularStock();
    }
}
```

3. **Nuevo método `_recalcularEnModoEdicion()`:**

```dart
void _recalcularEnModoEdicion() {
    int factorVenta = int.tryParse(_unidadesVentaCtrl.text) ?? 1;
    if (factorVenta <= 0) factorVenta = 1;
    
    int stockBaseOriginal = widget.controllerMap['stockBaseOriginal'] ?? 0;
    
    // Recalcular stock visual dividiendo stock base entre nuevo factor
    int stockVisualNuevo = stockBaseOriginal ~/ factorVenta;
    int sobrante = stockBaseOriginal % factorVenta;
    
    _stockInicialCtrl.text = stockVisualNuevo.toString();
    _stockFinalCtrl.text = stockVisualNuevo.toString();
    _nuevoIngresoCtrl.text = ""; // Sin nuevo ingreso al editar
    
    // Recalcular costo de presentación proporcionalmente
    double costoBase = widget.controllerMap['costoBaseOriginal'] ?? 0.0;
    if (costoBase > 0) {
      _costoPresCtrl.text = _formatDecimal(costoBase * factorVenta);
    }
    
    _unidadesSobrantes = sobrante;
    _verifyLeftoverInvalidation();
    _recalcularPrecios(fromMargen: true);
    _recalcularStock();
}
```

4. **Agregar validación de faltantes y sobrantes** usando el nuevo `StockValidationResult`.

5. **Agregar getter `hasUnresolvedStock`** para que el padre pueda consultar si hay problemas sin resolver.

---

#### [MODIFY] [product_edit_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/screens/product_edit_screen.dart)

**Cambios clave en `_loadExistingData()` (línea 75):**

Agregar campos de contexto al `controllerMap`:

```dart
'isEditMode': true,
'stockBaseOriginal': pres.stockActual,  // Stock en unidades base de BD
'costoBaseOriginal': pres.costoUnitarioCalculado != null && pres.unidadesPorVenta > 0
    ? pres.costoUnitarioCalculado! / pres.unidadesPorVenta 
    : 0.0,  // Costo base individual
```

**Cambios clave en `_addPresentation()` (línea 217):**

Las presentaciones nuevas añadidas DENTRO del modo edición **no son `isEditMode`** (porque no tienen datos históricos):

```dart
'isEditMode': false,  // Presentación nueva → funciona como creación
```

**Cambios clave en `_save()` (línea 436):**

Agregar validación pre-guardado:

```dart
// Verificar que ninguna presentación tenga stock incoherente
for (var c in _presentationControllers) {
    int factorVenta = int.tryParse((c['unidadesVenta'] as TextEditingController).text) ?? 1;
    int stockFinal = int.tryParse((c['stockFinal'] as TextEditingController).text) ?? 0;
    
    if (factorVenta > 1 && stockFinal > 0) {
        // Validar usando motor centralizado
        int stockBase = stockFinal * factorVenta;
        var validation = UnitCatalogService.validateStockForUnit(
            totalUnitsBase: stockBase,
            presentationFactor: factorVenta,
            ...
        );
        if (validation.status == StockValidationStatus.DEFICIT) {
            // Mostrar mensaje personalizado y retornar
        }
        if (validation.status == StockValidationStatus.HAS_LEFTOVER 
            && c['leftoverCreated'] != true) {
            // Mostrar mensaje personalizado y retornar
        }
    }
}
```

---

#### [MODIFY] [product_create_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/screens/product_create_screen.dart)

**Misma validación pre-guardado que edit**, en `_save()` (línea 307).

**En `_handleCreateLeftover()` (línea 176):** Mejorar nombre automático:

```dart
String parentName = (sourceMap['specific'] as TextEditingController).text.trim();
String leftoverName = parentName.isNotEmpty ? "$parentName - Suelta" : "Suelta";

// ...
'specific': TextEditingController(text: leftoverName),
```

El nombre es editable porque usa un `TextEditingController` que el usuario puede modificar libremente.

---

### Fase 3: Validación en el Staging (Clasificar y Confirmar)

---

#### [MODIFY] [variant_editor_row.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart)

**Cambios clave:**

1. **Reemplazar cálculo manual de `_leftoverSuelto`** (línea 142) por `StockValidationResult`:

```dart
var validation = UnitCatalogService.validateStockForUnit(
    totalUnitsBase: totalUnidadesBase,
    presentationFactor: unidPorVenta,
    baseUnitCost: costoBaseIndiv,
    unitName: _unidadVentaCtrl.text,
);
_stockValidation = validation; // Nuevo campo de estado
```

2. **Mostrar alertas diferenciadas:**
   - **`DEFICIT` → Container ROJO:**
     ```
     "⛔ Faltan {deficit} unidades para completar 1 {unidad}."
     "Tienes {total} unidades, pero se necesitan {factor} para 1 {unidad}."
     "Cambia la unidad de venta o ajusta la cantidad comprada."
     ```
   - **`HAS_LEFTOVER` → Container NARANJA:**
     ```
     "⚠️ {total} unidades ÷ {factor} = {completas} {unidad} + {sobrante} sueltas"
     ```
     Con botón: `"Crear variante '{nombre} - Suelta' (x1)"`.

3. **Exponer `hasUnresolvedStock`** para que `StagingProductGroupCard` pueda consultar y bloquear el guardado global.

4. **Nombre heredado editable:** La variante sobrante se crea con `"{nombre_padre} - Suelta"` como valor inicial del `_nombreCtrl`, que sigue siendo un `TextField` editable.

---

#### [MODIFY] [variant_price_calculator.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart)

**Cambios clave:**

1. **En `_recalcularModal()` (línea 177):** Usar `StockValidationResult` para calcular estado.

2. **Transformar `_buildLeftoverWarning()` (línea 944) en `_buildStockValidationWarning()`:**
   - **DEFICIT:** Container rojo con mensaje personalizado:
     ```
     "No se puede guardar: tienes {totalUnidades} unidades pero necesitas 
     mínimo {factor} para vender 1 {unidad}. Faltan {deficit} unidades."
     ```
   - **HAS_LEFTOVER:** Container naranja con mensaje y botón:
     ```
     "Quedan {sobrante} unidades sueltas del lote. Debes crear una variante 
     unitaria para registrarlas correctamente."
     [Botón: Crear variante '{nombre} - Suelta' (x1)]
     ```

3. **En `_crearVarianteSobrante()` (línea 210):** Cambiar nombre fijo a nombre heredado:
   ```dart
   String parentName = widget.variant.nombreEspecifico.trim();
   String leftoverName = parentName.isNotEmpty ? "$parentName - Suelta" : "Suelta";
   ```

4. **Deshabilitar botón "GUARDAR DECISIÓN"** cuando:
   - `status == DEFICIT` → Botón gris con texto: `"No se puede guardar — stock insuficiente para {unidad}"`
   - `status == HAS_LEFTOVER` y no se ha creado variante sobrante → Botón gris con texto: `"Primero crea la variante sobrante para las {N} unidades sueltas"`

---

#### [MODIFY] [scanner_batch_saver.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_batch_saver.dart)

**Cambio en líneas 109-111:**

```dart
// ANTES (bug):
int cantidadSumar = ((v.cantidadUmpComprada * v.unidadesPorLote) / v.unidadesPorVenta).toInt();

// DESPUÉS (corrección):
int cantidadSumar;
if (v.stockIngresanteOverride != null) {
    cantidadSumar = v.stockIngresanteOverride!;
} else {
    cantidadSumar = ((v.cantidadUmpComprada * v.unidadesPorLote) / v.unidadesPorVenta).toInt();
}
```

Esto permite que las variantes sobrantes (con factor x1) guarden correctamente su `stockIngresanteOverride` en lugar del cálculo truncado.

---

#### [MODIFY] [invoice_staging_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/screens/invoice_staging_screen.dart)

**Cambio en `_confirmSave()` (línea 127):**

Antes de ejecutar `executeBatchSave()`, recorrer **todas las variantes activas** de todos los grupos y verificar con el motor centralizado:

```dart
void _confirmSave(BuildContext context, ScannerProvider provider) async {
    // Pre-validación de stock
    final staging = provider.stagingData;
    if (staging != null) {
        for (var group in staging.productosAgrupados) {
            for (var variant in group.variantes.where((v) => v.isConfirmed)) {
                int totalBase = (variant.cantidadUmpComprada * variant.unidadesPorLote).toInt();
                var validation = UnitCatalogService.validateStockForUnit(
                    totalUnitsBase: totalBase,
                    presentationFactor: variant.unidadesPorVenta,
                    baseUnitCost: ...,
                    unitName: variant.unidadVenta,
                );
                
                if (validation.status == StockValidationStatus.DEFICIT) {
                    CustomSnackBar.show(context, 
                        message: "❌ '${variant.nombreEspecifico}': ${validation.userMessage}", 
                        isError: true);
                    return;
                }
                // HAS_LEFTOVER sin resolver también bloquea
            }
        }
    }
    
    bool success = await provider.executeBatchSave();
    // ...
}
```

---

### Fase 4: Validación en Crear/Editar Producto (con fix de bug)

---

#### [MODIFY] [product_presentation_card.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/widgets/product_presentation_card.dart) — Resumen completo

| Aspecto | Cambio |
|---------|--------|
| **`_evaluarMatematicaGeneral()`** | Bifurcar por `isEditMode`: NO usar datos de compra al cambiar unidad en edición |
| **Nuevo `_recalcularEnModoEdicion()`** | Recalcular stock y costo proporcionalmente al nuevo factor, usando stock base original |
| **Alertas visuales** | Agregar Container rojo para DEFICIT, mejorar Container naranja para sobrantes |
| **`hasUnresolvedStock` getter** | Exponer si hay faltantes o sobrantes pendientes para que el padre bloquee el guardado |
| **Nombre variante sobrante** | Cambiar de `"Unidad Suelta / Detalle"` a `"{nombre_padre} - Suelta"` (editable por el usuario) |

---

#### [MODIFY] [product_create_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/screens/product_create_screen.dart) — Resumen

| Aspecto | Cambio |
|---------|--------|
| **`_save()` (línea 307)** | Validación pre-guardado con mensajes personalizados por presentación |
| **`_handleCreateLeftover()` (línea 176)** | Nombre: `"{nombre_padre} - Suelta"`, editable |
| **`_addPresentation()` (línea 132)** | Agregar `'isEditMode': false` |

---

#### [MODIFY] [product_edit_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/screens/product_edit_screen.dart) — Resumen

| Aspecto | Cambio |
|---------|--------|
| **`_loadExistingData()` (línea 75)** | Agregar `'isEditMode': true`, `'stockBaseOriginal'`, `'costoBaseOriginal'` |
| **`_addPresentation()` (línea 217)** | Nuevas presentaciones: `'isEditMode': false` |
| **`_save()` (línea 436)** | Validación pre-guardado con mensajes personalizados |
| **`_handleCreateLeftover()` (línea 256)** | Nombre: `"{nombre_padre} - Suelta"`, editable |

---

### Fase 5: Pulido Visual y Mensajes Personalizados

---

#### Mensajes Personalizados por Situación

Los mensajes se generan desde `StockValidationResult.userMessage` y varían según el contexto:

**DEFICIT (Rojo - `Icons.error_outline`):**
```
Línea 1: "⛔ Stock insuficiente para vender por {unidadVenta}"
Línea 2: "Tienes {totalUnidades} unidades, pero se necesitan mínimo 
          {factor} para completar 1 {unidadVenta}."
Línea 3: "Te faltan {deficit} unidades. Cambia la unidad de venta 
          a una menor o ajusta la cantidad."
```

**HAS_LEFTOVER (Naranja - `Icons.warning_amber_rounded`):**
```
Línea 1: "⚠️ {totalUnidades} unidades ÷ {factor} por {unidadVenta} = 
          {completas} {unidadVenta} + {sobrante} sueltas"
Línea 2: "Debes crear una variante para registrar las {sobrante} 
          unidades sueltas correctamente."
[Botón: Crear variante '{nombre} - Suelta' (x1)]
```

**Después de crear variante sobrante (Verde - `Icons.check_circle`):**
```
"✅ Variante sobrante '{nombre} - Suelta' creada con {sobrante} 
unidades y costo S/{costo} c/u"
```

#### Botón de guardado inteligente

En **todas las pantallas**, el botón de guardar:
- Se **deshabilita** visualmente (gris) si hay faltantes o sobrantes sin resolver
- Muestra texto explicativo debajo del botón:
  - Faltante: `"No se puede guardar: {nombre_variante} tiene stock insuficiente para {unidad}"`
  - Sobrante: `"No se puede guardar: {nombre_variante} tiene {N} unidades sin asignar"`

---

## Resumen de Archivos a Modificar

| # | Archivo | Fase | Cambio Principal |
|---|---------|------|------------------|
| 1 | `unit_catalog_service.dart` | F1 | Motor centralizado: `StockValidationResult` + `validateStockForUnit` |
| 2 | `product_presentation_card.dart` | F2+F4 | Bug fix edición + detección faltantes + getter `hasUnresolvedStock` |
| 3 | `product_edit_screen.dart` | F2+F4 | `isEditMode` + `stockBaseOriginal` + validación pre-guardado |
| 4 | `product_create_screen.dart` | F4 | Validación pre-guardado + nombre heredado sobrante |
| 5 | `variant_editor_row.dart` | F3 | Validación staging tarjeta + alertas + nombre heredado |
| 6 | `variant_price_calculator.dart` | F3 | Validación modal + bloqueo botón + nombre heredado |
| 7 | `scanner_batch_saver.dart` | F3 | Fix `stockIngresanteOverride` |
| 8 | `invoice_staging_screen.dart` | F3 | Validación pre-guardado global staging |

---

## Verification Plan

### Manual Verification — Modo Creación

- **Escenario 1 (Faltante):** Comprar 4 unidades, elegir Docena (x12) → Alerta roja: "Faltan 8 unidades para completar 1 Docena". Guardado bloqueado.
- **Escenario 2 (Sobrante):** Comprar 10 unidades, elegir ½ Docena (x6) → Alerta naranja: "10 ÷ 6 = 1 ½ Docena + 4 sueltas". Botón crear variante. Guardado bloqueado hasta crear.
- **Escenario 3 (Exacto):** Comprar 12 unidades, elegir Docena (x12) → Sin alertas, guardado OK.
- **Escenario 4 (Stock 0):** Sin compra → Sin alertas, guardado OK.
- **Escenario 5 (Variante sobrante):** Crear variante → Nombre `"{padre} - Suelta"`, factor x1, stock = sobrantes, editable.

### Manual Verification — Modo Edición (Bug Fix)

- **Escenario 6:** Producto con stock=24, última factura totalPago=45. Cambiar unidad de Unidad (x1) a Docena (x12) → Stock debe recalcularse a `24 ÷ 12 = 2` Docenas, **NO** debe usar datos de factura.
- **Escenario 7:** Mismo producto, cambiar a ½ Docena (x6) → Stock = `24 ÷ 6 = 4` ½ Docenas. Datos de compra NO deben alterar el stock.
- **Escenario 8:** Agregar nueva presentación dentro de edición → Esa nueva presentación SÍ puede usar datos de compra (no es `isEditMode`).

### Manual Verification — Staging (Clasificar y Confirmar)

- **Escenario 9:** En staging, variante con 4 unidades base y unidad Docena → Faltante detectado, botón "GUARDAR DECISIÓN" deshabilitado.
- **Escenario 10:** En staging, variante con 14 unidades base y unidad Docena → Sobrante de 2, botón deshabilitado hasta crear variante sobrante.
- **Escenario 11:** Botón "GUARDAR E INGRESAR STOCK" de la pantalla principal deshabilitado si alguna variante tiene stock sin resolver.

### Verificar en 3 pantallas
- ✅ Staging (Clasificar y Confirmar)
- ✅ Crear Producto
- ✅ Editar Producto
