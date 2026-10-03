# Plan: Escáner — Reingeniería del Modal "Gestión del Producto" (REFORMULADO)

---

## Análisis Profundo del Modelo de Datos

Antes de planificar cualquier cambio, debo entender exactamente qué variables maneja cada capa del sistema.

### Modelo de Persistencia: `ProductPresentation` (BD SQLite)

Cada **presentación** (variante) de un producto almacena DOS grupos de datos financieros:

```
┌──────────────────────────────────────────────────────────┐
│               DATOS DE COMPRA (Proveedor)                │
│                                                          │
│   umpCompra           → "UND", "CAJA", "MLL"            │
│   precioUmpProveedor  → Precio por unidad del proveedor  │
│   cantidadUmpComprada → Cuántas UMP se compraron         │
│   totalPagoLote       → Monto total pagado al proveedor  │
│   unidadesPorLote     → Cuántas unidades individuales    │
│                         vienen en 1 UMP de compra        │
│   facturaCargaId      → Referencia a la factura origen   │
├──────────────────────────────────────────────────────────┤
│               DATOS DE VENTA (Tu Negocio)                │
│                                                          │
│   unidadVenta           → "Unidad", "Docena", "Caja"     │
│   unidadesPorVenta      → Cuántas unidades individuales  │
│                           componen 1 unidad de venta     │
│   costoUnitarioCalculado → Costo real por ud. de venta   │
│   factorGananciaVenta    → Margen (ej. x1.35)           │
│   precioVentaFinal       → Precio al público             │
│   stockActual            → Existencias actuales          │
│   precioOferta / tipoDescuento / valorDescuento          │
└──────────────────────────────────────────────────────────┘
```

### Modelo de Staging: `StagingVariant` (Datos escaneados de la factura)

Replica la misma estructura pero con valores **extraídos de la factura nueva**:

| Campo StagingVariant | Equivale a (BD) | Origen |
|---|---|---|
| `umpCompra` | `umpCompra` | Extraído de la factura escaneada |
| `cantidadUmpComprada` | `cantidadUmpComprada` | Extraído de la factura |
| `precioUmpProveedor` | `precioUmpProveedor` | Extraído de la factura |
| `totalPagoLote` | `totalPagoLote` | Extraído de la factura |
| `unidadesPorLote` | `unidadesPorLote` | Usuario lo configura en Revisión de Compras |
| `unidadVenta` | `unidadVenta` | Usuario lo configura en Revisión de Compras |
| `unidadesPorVenta` | `unidadesPorVenta` | Calculado (= `unidadesPorLote` por defecto) |
| `costoUnitarioSugerido` | `costoUnitarioCalculado` | Calculado por ScannerCostEngine |
| `factorGananciaVentaSugerido` | `factorGananciaVenta` | Sugerido por el sistema |
| `precioVentaSugerido` | `precioVentaFinal` | Calculado: costo × margen |

### Datos del `dbData` (Presentación actual en BD, mapa `availablePresentations`)

El `dbData` que recibe el modal proviene de la consulta normalizada de la tabla `presentaciones` y contiene estas **keys**:

| Key en dbData | Campo real (BD) |
|---|---|
| `unidad` | `unidadVenta` (Ud. de Venta) |
| `factor_conversion` | `unidadesPorVenta` (Factor de Venta) |
| `precio_costo` | `costoUnitarioCalculado` |
| `factor_ganancia_venta` | `factorGananciaVenta` |
| `precio_venta` | `precioVentaFinal` |
| `stock_actual` | `stockActual` |
| `precio_oferta` | `precioOferta` |
| `tipo_descuento` | `tipoDescuento` |
| `valor_descuento` | `valorDescuento` |

> [!IMPORTANT]
> **Hallazgo crítico:** El `dbData` (normalizedSiblings) **NO contiene** los campos de compra de la BD (`ump_compra`, `precio_ump_proveedor`, `cantidad_ump_comprada`, `total_pago_lote`, `unidades_por_lote`). Esto significa que el modal actualmente **no puede comparar datos de compra BD vs compra Factura** porque la consulta no los trae. Si se quiere implementar esa comparación, habría que ampliar la query SQL que construye `normalizedSiblings` en `scanner_matching_engine.dart`.

---

## Diagnóstico Preciso de los Problemas

### 🔴 Problema 1: Tabla de Comparación — ¿Qué se compara realmente?

**Estado actual de la tabla en el modal (L385-483):**

| Concepto | Columna "Actual (BD)" | Columna "Nuevo (Factura)" | ¿Correcto? |
|---|---|---|---|
| **Unidad** | `dbData['unidad']` = Ud. de **Venta** (BD) | `_uVentaCtrl` = Ud. de **Venta** (Factura) | ✅ Correcto: compara Venta vs Venta |
| **Factor** | `dbData['factor_conversion']` = Factor de **Venta** (BD) | `_uVentaFactorCtrl` = Factor de **Venta** (Factura) | ✅ Correcto: compara Venta vs Venta |
| **Costo Pres.** | `dbData['precio_costo']` = Costo de **Venta** (BD) | `_costoCtrl` = Costo sugerido de **Venta** (Factura) | ✅ Correcto |
| **Margen** | `dbData['factor_ganancia_venta']` = Margen (BD) | `_margenCtrl` = Margen sugerido | ✅ Correcto |
| **P. Venta** | `dbData['precio_venta']` = Precio (BD) | `_precioCtrl` = Precio sugerido | ✅ Correcto |

> [!NOTE]
> **Conclusión:** La tabla realmente SÍ compara datos equivalentes (Venta BD vs Venta Factura). El error estaba en mi plan anterior al renombrar las columnas como "Ud. Compra (Fact.)". Las etiquetas `"Actual (BD)"` y `"Nuevo (Factura)"` son correctas conceptualmente. El problema era sólo de **claridad contextual**: falta un subtítulo que aclare que esta sección trata sobre la **Unidad de Venta** y su precio.

### 🔴 Problema 2: Formato de 4 decimales (L376)

```dart
Text("→ Costo Unitario Base: S/ ${costoUnitarioBase.toStringAsFixed(4)} c/u", ...)
```
Esto muestra `S/ 22.5000 c/u`. Debería ser `toStringAsFixed(2)` → `S/ 22.50 c/u`.

### 🔴 Problema 3: Falta Reset a Valores Originales

El botón "Deshacer Modal" (L264-274) solo restaura al **snapshot** (valores previos a la apertura del modal). No hay forma de restablecer a los valores **originales de la factura** (`restoreOriginals()` existe en el modelo pero no se invoca desde la UI).

### 🔴 Problema 4: Stock No Editable (L520-592)

`stockIngresante` se calcula como `((cantidadUmpComprada * unidadesPorLote) / factor).toInt()` y se muestra como `Text("+$stockIngresante")`. Es estático. Si hubo mermas físicas, el usuario no puede ajustarlo.

### 🔴 Problema 5: Sección "Nombre Específico" ocupa espacio fijo

`_buildCompareRow("Nombre Específico", ...)` (L311) genera un contenedor completo siempre visible. No hay campo de Marca dentro del modal (solo se muestra como badge estático en la cabecera).

### 🔴 Problema 6: Descuentos Limitados

La sección de descuento (L594-633) solo tiene un `CheckboxListTile` de "Mantener este descuento". No hay opción de desactivar descuento ni editar manualmente.

---

## Plan de Trabajo por Fases

### Fase 1: Claridad Financiera y Reset

#### [MODIFY] [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart)

**1.1. Formato a 2 decimales (L376):**
```diff
- Text("→ Costo Unitario Base: S/ ${costoUnitarioBase.toStringAsFixed(4)} c/u", ...)
+ Text("→ Costo Unitario Base: S/ ${costoUnitarioBase.toStringAsFixed(2)} c/u", ...)
```

**1.2. Clarificar contexto de la tabla comparativa (L352-357):**

Renombrar el título de la sección para que el usuario entienda que se están comparando **datos de venta**:
```diff
- Text("Cálculo Financiero: Unidades y Precios", ...)
+ Text("Comparativa de Venta: Precios y Unidades", ...)
```

Y renombrar las cabeceras de columna para mayor claridad (L389-390):
```diff
- Expanded(flex: 4, child: Text("Actual (BD)", ...)),
- Expanded(flex: 4, child: Text("Nuevo (Factura)", ...)),
+ Expanded(flex: 4, child: Text("Actual (Inventario)", ...)),
+ Expanded(flex: 4, child: Text("Nuevo (Sugerido)", ...)),
```

> [!NOTE]
> Se usa "Sugerido" en vez de "Factura" porque estos valores NO son datos crudos de la factura — son **cálculos derivados** por el `ScannerCostEngine` a partir de los datos de compra. El usuario ya editó los datos crudos de compra en la ventana de "Revisión de Compras".

**1.3. Botón "Restablecer a Valores Originales" en la cabecera (L260-276):**

Añadir un `IconButton(Icons.restore)` junto al botón "Deshacer Modal" existente. Este botón invocará `restoreOriginals()` (ya implementado en `StagingVariant`) para resetear TODO a los valores calculados de la factura original:

```dart
IconButton(
  icon: const Icon(Icons.restore, size: 22),
  tooltip: "Restablecer valores de factura",
  color: Colors.orange,
  onPressed: () {
    setState(() {
      widget.variant.restoreOriginals();
      _initControllers();
    });
  },
)
```

---

### Fase 2: Secciones Colapsables (Nombre/Marca y Descuentos)

#### [MODIFY] [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart) (L307-317)

**2.1. Agrupar "Nombre Específico" + nuevo campo "Marca" en un `ExpansionTile` cerrado por defecto:**

```dart
Theme(
  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
  child: ExpansionTile(
    initiallyExpanded: false,
    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
    title: Text("Nombre Específico y Marca"),
    leading: Icon(Icons.edit_note),
    children: [
      _buildCompareRow("Nombre Específico", dbValue, _nomCtrl, widget.variant.updateNombre, ...),
      _buildCompareRow("Marca", widget.group.marcaTexto, _marcaCtrl, widget.variant.updateMarca, ...),
    ],
  ),
)
```

#### [MODIFY] [`scanner_models.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/models/scanner_models.dart) (L182-320)

Añadir campo `bool updateMarca = false` a `StagingVariant`, incluirlo en `takeSnapshot()`, `restoreFromSnapshot()`, `restoreOriginals()` y `hasBeenModified`.

#### [MODIFY] [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart) (L31-63)

Añadir `_marcaCtrl` al state del modal, inicializarlo en `_initControllers()` y disponer en `dispose()`.

**2.2. Expandir la sección de Descuentos con opciones múltiples:**

Convertir `_buildDiscountRow()` (L594-633) en un `ExpansionTile` con tres opciones tipo `RadioListTile`:

1. **Mantener descuento actual** — Se recalculará con el nuevo precio si se actualiza.
2. **Desactivar descuento** — Se pondrá `precioOferta = null`.
3. **Editar descuento manualmente** — Se mostrará un `TextFormField` para ingresar el nuevo valor.

Añadir al state:
```dart
String _discountMode = 'keep'; // 'keep', 'remove', 'edit'
late TextEditingController _manualDiscountCtrl;
```

---

### Fase 3: Stock Editable

#### [MODIFY] [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart) (L520-592)

**3.1. Convertir "Nuevo Ingreso" de `Text` a `TextFormField`:**

```diff
// Antes (L555-557):
- Text("+$stockIngresante", style: TextStyle(fontSize: 14, ...))

// Después:
+ SizedBox(
+   width: 60, height: 28,
+   child: TextFormField(
+     controller: _stockIngresanteCtrl,
+     keyboardType: TextInputType.number,
+     ...
+   ),
+ )
```

**3.2. Recalcular totales dinámicamente:**
Los textos de "Sumar al existente (Total: X)" y "Reemplazar (Total: X)" ahora leerán el valor del `TextFormField` en lugar del cálculo estático:

```dart
int manualIngreso = int.tryParse(_stockIngresanteCtrl.text) ?? stockIngresante;
int stockSumado = stockBD + manualIngreso;
int stockReemplazo = manualIngreso;
```

**3.3. Añadir `_stockIngresanteCtrl` al state:**

Nuevo `TextEditingController` inicializado con el valor calculado `stockIngresante` en `initState()`. Se actualizará cuando el usuario cambie la presentación seleccionada en el carrusel.

#### [MODIFY] [`scanner_models.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/models/scanner_models.dart)

Añadir campo `int? stockIngresanteOverride` a `StagingVariant` para persistir el ajuste manual.

---

### Fase 4: Mejoras Menores al Carrusel Existente

#### [MODIFY] [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart) (L218-231)

**4.1. Mostrar unidad de venta en cada tarjeta del carrusel:**
```dart
Text("${p['unidad'] ?? 'Ud.'} (x${p['factor_conversion'] ?? 1})", 
  style: TextStyle(fontSize: 10, ...)),
```

**4.2. Indicador de descuento en tarjetas:**
```dart
if (p['precio_oferta'] != null && (p['precio_oferta'] as num) > 0)
  Icon(Icons.local_offer, size: 12, color: Colors.purple[300]),
```

---

## Resumen de Archivos Modificados

| Archivo | Cambios |
|---|---|
| `variant_price_calculator.dart` | Formato 2 decimales, renombrar etiquetas, botón reset, secciones colapsables (Nombre+Marca), descuentos expandidos, stock editable, mejoras al carrusel |
| `scanner_models.dart` | Añadir `updateMarca`, `stockIngresanteOverride` a `StagingVariant` con snapshot/restore |

## Verificación

- `flutter analyze` debe reportar 0 errores.
- **Test 1:** El costo base debe mostrar exactamente 2 decimales (`S/ 22.50 c/u`).
- **Test 2:** Las columnas dicen "Actual (Inventario)" y "Nuevo (Sugerido)".
- **Test 3:** El botón 🔄 resetea a los valores originales de factura.
- **Test 4:** "Nombre y Marca" está colapsado por defecto y expandible.
- **Test 5:** El campo "Nuevo Ingreso" es editable y recalcula totales en tiempo real.
- **Test 6:** Los descuentos ofrecen 3 opciones (mantener, desactivar, editar).
