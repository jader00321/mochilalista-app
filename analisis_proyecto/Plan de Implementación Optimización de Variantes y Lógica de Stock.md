# Plan de Implementación: Optimización de Variantes y Lógica de Stock

## Contexto del Problema

El módulo Scanner tiene un flujo de 3 fases: **IA → Matching → Staging**. En la fase de Staging, cada producto extraído de la factura se muestra como un `StagingProductGroup` con sus `StagingVariant`. Cuando un producto se vincula (manual o automáticamente) a uno existente en el inventario, aparecen **tarjetas horizontales** con las variantes disponibles en BD, y un botón **"Comparar"** que abre el `ComparativeUpdateModal`.

Se han detectado **múltiples bugs y carencias** en la tarjeta de variante, el modal comparativo y la lógica de stock. Este plan aborda todos de forma integral.

---

## Diagnóstico Detallado de Bugs

### 🔴 Bug 1: Precio y descuento muestran "S/0.00" en tarjetas de variante

**Causa raíz:** Inconsistencia de claves entre el matching engine y la UI.

- El matching engine ([scanner_matching_engine.dart:155](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_matching_engine.dart#L155)) guarda el precio como `precio_venta`.
- Las tarjetas en [variant_editor_row.dart:436](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart#L436) y [modal_variant_cards.dart:95](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/comparative_modal/ui/modal_variant_cards.dart#L95) leen `precio_venta_final` (clave inexistente → `null` → `0.0`).
- Además, la info de descuento (`precio_oferta`, `tipo_descuento`, `valor_descuento`) está disponible en los siblings pero nunca se renderiza en las tarjetas.

### 🔴 Bug 2: Discrepancia de unidad de venta al vincular

**Causa raíz:** Ni el auto-linking ni el manual-linking validan si la `unidad_venta` del producto BD difiere de la unidad detectada en la factura.

- Si la factura detecta "Millar (x1000)" pero el producto BD tiene "Docena (x12)", el sistema vincula silenciosamente y los cálculos de stock quedan corruptos.
- El stock ingresante se calcula como `cantidadUmpComprada * unidadesPorLote` dividido por el factor de la variante BD, pero si estos factores no coinciden, el resultado es incorrecto.

### 🔴 Bug 3: Falta de alertas de stock (déficit/sobrante) en el modal y tarjeta

**Causa raíz:** El `ComparativeUpdateModal` tiene un `_leftoverSuelto` getter parcial (línea 232-243), pero:
- No usa `UnitCatalogService.validateStockForUnit()` (el estándar del sistema).
- No muestra alertas de **déficit** (cuando las unidades base no alcanzan para completar ni 1 presentación).
- La alerta naranja de sobrante sólo aparece al final del modal, no en tiempo real.
- **El `variant_editor_row.dart` no tiene NINGUNA alerta de stock** — no detecta ni sobrante ni déficit.

### 🔴 Bug 4: Botón "Guardar" no se bloquea por stock inválido del modal

**Causa raíz:** `provider.hasUnresolvedStock` valida correctamente usando `UnitCatalogService`, pero la lógica de sobrante del modal (`_leftoverSuelto`) opera independientemente y no sincroniza su estado con el provider.

### 🟡 Bug 5: Reactividad bidireccional incompleta en el modal

**Problemas encontrados:**

1. `_onUnidadVentaChanged()` (modal, línea 118-146): Recalcula costos usando `widget.variant.totalPagoLote` y `widget.variant.cantidadUmpComprada` en vez de los **controladores editados** (`_pagoTotalCtrl`, `_cantidadUmpCtrl`). Esto ignora ediciones previas del usuario.

2. `_onPurchaseDataChanged()` (modal, línea 148-175): Recalcula correctamente desde los controladores, pero **no actualiza el stock ingresante** cuando cambian los datos de compra.

3. Al cambiar la unidad de venta (factor), el campo "Nuevo Ingreso" en la sección de stock no se recalcula automáticamente.

### 🟡 Bug 6: Falta "enunciado" de datos originales de factura

El usuario solicita que los datos extraídos originalmente por la IA se muestren como referencia inmutable encima de los campos editables, con un botón de restauración individual por campo.

### 🟡 Bug 7: Tarjeta "Nueva Variante" con UI básica

Cuando `isVariantMatch == false`, la tarjeta renderiza todos los campos de entrada en un bloque compacto sin las secciones organizadas tipo ExpansionTile que tiene el modal.

---

## Propuesta de Cambios

### Fase 1: Corrección de datos en tarjetas de variante (Bugs 1)

---

#### [MODIFY] [variant_editor_row.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart)

**Método `_buildVariantCards()` (línea 354-446):**

- Cambiar `p['precio_venta_final']` → `p['precio_venta']` (línea 436).
- Agregar indicador visual de descuento: Si `p['precio_oferta'] != null`, mostrar el precio original tachado y el precio oferta al lado.
- Agregar indicador de unidad de venta: Mostrar `p['unidad'] ?? 'Unidad'` y `p['factor_conversion'] ?? 1` como badge debajo del nombre.

#### [MODIFY] [modal_variant_cards.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/comparative_modal/ui/modal_variant_cards.dart)

**Método `_buildVariantCards()` (línea 4-105):**

- Cambiar `p['precio_venta_final']` → `p['precio_venta']` (línea 95).
- Agregar indicador de descuento (precio oferta con badge "PROMO").
- Agregar indicador de unidad/factor debajo del nombre.
- Aumentar `height` de 70 a 85 para acomodar la nueva información.

---

### Fase 2: Lógica de alerta por discrepancia de unidad al vincular (Bug 2)

---

#### [MODIFY] [variant_editor_row.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart)

**En la sección de "VARIANTE EXISTENTE" (líneas 239-280):**

- Después de mostrar el nombre vinculado, agregar un bloque condicional que compare:
  - `widget.variant.unidadVenta` / `widget.variant.unidadesPorVenta` (factura) vs `widget.variant.matchPresentacion.datos?.unidadVenta` / `widget.variant.matchPresentacion.datos?.unidadesPorVenta` (BD).
- Si difieren, mostrar un **banner de advertencia amarillo/naranja** con:
  - Texto explicativo: "La factura detectó [Unidad x1] pero la variante BD es [Docena x12]. Los datos de la factura se usarán."
  - Botón: "Adoptar unidad BD" que copie los valores de BD al variant actual.

#### [MODIFY] [scanner_provider.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/providers/scanner_provider.dart)

- Nuevo método `adoptDbUnitForVariant(String variantUuid)`: Copia la unidad de venta y factor del `matchPresentacion.datos` al variant, y recalcula costos con `ScannerCostEngine`.

---

### Fase 3: Sistema de alertas de stock integrado (Bugs 3 y 4)

---

#### [MODIFY] [variant_editor_row.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart)

**Para variantes EXISTENTES (bloque `isVariantMatch`):**

- Después del texto "Ingresarán al Stock", agregar cálculo de validación usando `UnitCatalogService.validateStockForUnit()`.
- Mostrar badge condicional:
  - 🟢 **Verde** si `StockValidationStatus.exact`: "Stock cuadra perfectamente".
  - 🟠 **Naranja** si `StockValidationStatus.hasLeftover`: "Sobran N unidades sueltas" + indicador de si ya se creó variante sobrante.
  - 🔴 **Rojo** si `StockValidationStatus.deficit`: "Faltan N unidades para completar 1 [unidad]".

**Para variantes NUEVAS (bloque `!isVariantMatch`):**

- Agregar la misma validación después de los tags de resumen.
- Usar la misma lógica de colores.

#### [MODIFY] [modal_stock_section.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/comparative_modal/ui/modal_stock_section.dart)

- Importar y usar `UnitCatalogService.validateStockForUnit()` en `_buildStockManagementRow()`.
- Calcular validación en tiempo real basada en los controladores actuales (`_stockIngresanteCtrl`, `_uVentaFactorCtrl`).
- Mostrar badge de estado de stock (verde/naranja/rojo) debajo de las opciones de sumar/reemplazar.
- Si hay déficit, mostrar alerta roja con sugerencia de cambiar unidad a "Unidad (x1)".

#### [MODIFY] [comparative_update_modal.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/comparative_modal/comparative_update_modal.dart)

**`_leftoverSuelto` (líneas 232-244):**

- Refactorizar para usar `UnitCatalogService.validateStockForUnit()` en vez de cálculos manuales.
- Leer valores desde los controladores editados, no desde `widget.variant` directamente.

**`_buildLeftoverWarning()` en [modal_stock_section.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/comparative_modal/ui/modal_stock_section.dart):**

- Además del sobrante, agregar alerta de déficit.
- Si déficit: Mostrar en rojo con sugerencia.
- Si sobrante ya resuelto (variante creada): Mostrar en verde "✅ Sobrante ya asignado".

#### [MODIFY] [scanner_provider.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/providers/scanner_provider.dart)

**`hasUnresolvedStock` (líneas 89-130):**

- Ya funciona correctamente con `UnitCatalogService`. No necesita cambios, ya que lee de los valores actuales del variant (que se actualizan vía `_applyChanges`).
- Confirmar que el flujo `_applyChanges → notifyUIUpdate → hasUnresolvedStock` está correcto.

---

### Fase 4: Reactividad bidireccional completa (Bug 5)

---

#### [MODIFY] [comparative_update_modal.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/comparative_modal/comparative_update_modal.dart)

**`_onUnidadVentaChanged()` (líneas 118-146):**

Refactorizar para:
1. Leer datos de compra desde los controladores: `_pagoTotalCtrl`, `_cantidadUmpCtrl`, `_unidLoteCtrl` (no de `widget.variant`).
2. Recalcular stock ingresante automáticamente y actualizar `_stockIngresanteCtrl`.
3. Llamar a `updateState((){})` para triggear re-render del stock.

```dart
void _onUnidadVentaChanged() {
  // Leer desde controladores (datos editados actuales)
  double totalPago = double.tryParse(_pagoTotalCtrl.text) ?? widget.variant.totalPagoLote;
  double cantidadUmp = double.tryParse(_cantidadUmpCtrl.text) ?? widget.variant.cantidadUmpComprada;
  int unidLote = int.tryParse(_unidLoteCtrl.text) ?? widget.variant.unidadesPorLote;
  int factor = int.tryParse(_uVentaFactorCtrl.text) ?? 1;
  
  double costoUnitarioReal = ScannerCostEngine.calculateInvoiceUnitCost(
    totalPago: totalPago, cantidadUmp: cantidadUmp, unidadesPorLote: unidLote
  );
  double nuevoCostoPres = ScannerCostEngine.calculatePresentationCost(
    unitCost: costoUnitarioReal, unidadesPorVenta: factor
  );
  
  _costoCtrl.text = nuevoCostoPres.toStringAsFixed(2);
  
  // Recalcular stock ingresante
  int totalUnidadesBase = (cantidadUmp * unidLote).toInt();
  int stockIngresante = totalUnidadesBase ~/ factor;
  _stockIngresanteCtrl.text = stockIngresante.toString();
  
  _recalcularModal(fromMargen: true);
}
```

**`_onPurchaseDataChanged()` (líneas 148-175):**

Agregar al final la actualización del stock:
```dart
// Después de actualizar _costoCtrl...
int factor = int.tryParse(_uVentaFactorCtrl.text) ?? 1;
int totalUnidadesBase = (cantidadUMP * unidLote).toInt();
_stockIngresanteCtrl.text = (totalUnidadesBase ~/ factor).toString();
```

**`_recalcularModal()` (líneas 177-197):**

Agregar `updateState(() {});` al final para que la UI refleje todos los cambios en tiempo real.

---

### Fase 5: Enunciado de datos originales de factura (Bug 6)

---

#### [MODIFY] [comparative_update_modal.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/comparative_modal/comparative_update_modal.dart)

**En `_initControllers()` o `initState()`:**

- Almacenar los valores originales de la factura (los `_original*` del StagingVariant) en variables locales de solo lectura para mostrarlos como referencia.

#### [MODIFY] [modal_sale_section.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/comparative_modal/ui/modal_sale_section.dart)

**En el "Datos extraídos de Factura" (líneas 27-48):**

- Este bloque ya existe pero muestra datos estáticos de `widget.variant`. Cambiarlo para que muestre los valores **originales** de la factura (antes de edición).
- Agregar un botón "Restaurar de Factura" que resetee los controladores de esa sección a los valores originales.
- Hacer que este bloque se muestre con datos en tiempo real si los controladores cambiaron (tachado + nuevo valor).

#### [MODIFY] [modal_purchase_section.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/comparative_modal/ui/modal_purchase_section.dart)

- Agregar un banner similar de "Datos originales de factura" encima de la tabla comparativa de compra.

---

### Fase 6: Mejora visual de tarjeta "Nueva Variante" (Bug 7)

---

#### [MODIFY] [variant_editor_row.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart)

**Bloque `!isVariantMatch` (líneas 281-347):**

- Reorganizar los campos en 3 secciones visuales claras con headers:
  1. **📦 Identificación**: Nombre específico + Unidad de venta + Factor.
  2. **🛒 Datos de Compra**: Empaque Prov., Unid x Empaque, Cantidad comprada, Pago total → Costo Base (calculado y visible).
  3. **💰 Precio de Venta**: Factor venta, Margen, Precio final.
- Agregar separadores visuales con iconos y colores temáticos (similar al modal).
- Mover los ResumenTags de stock/precio al final del bloque con formato mejorado.
- Agregar las alertas de stock (Fase 3) como bloque final.

---

## Resumen de Archivos Afectados

| Archivo | Fases | Tipo |
|---------|-------|------|
| [variant_editor_row.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart) | 1, 2, 3, 6 | MODIFY |
| [modal_variant_cards.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/comparative_modal/ui/modal_variant_cards.dart) | 1 | MODIFY |
| [comparative_update_modal.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/comparative_modal/comparative_update_modal.dart) | 3, 4, 5 | MODIFY |
| [modal_stock_section.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/comparative_modal/ui/modal_stock_section.dart) | 3 | MODIFY |
| [modal_sale_section.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/comparative_modal/ui/modal_sale_section.dart) | 5 | MODIFY |
| [modal_purchase_section.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/comparative_modal/ui/modal_purchase_section.dart) | 5 | MODIFY |
| [scanner_provider.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/providers/scanner_provider.dart) | 2 | MODIFY |

---

## Open Questions

> [!IMPORTANT]
> **Q1: Comportamiento de "Adoptar unidad BD"**: Cuando la factura dice "Unidad x1" pero la variante BD es "Docena x12", y el usuario presiona "Adoptar unidad BD":
> - ¿Debería recalcular el stock ingresante automáticamente (ej: 1000 unidades ÷ 12 = 83 docenas)?
> - ¿O solo cambiar el nombre/factor y dejar que el usuario ajuste manualmente?
> **Mi recomendación:** Recálculo automático completo (stock + costos), ya que es la opción que previene errores.

> [!IMPORTANT]
> **Q2: Sección de stock para variantes NUEVAS en el modal**: Actualmente, `_buildStockManagementRow()` solo se muestra para `!isNuevo` (línea 380). ¿Debería mostrarse también para variantes nuevas con un formato simplificado (solo "Stock inicial" sin opción de sumar/reemplazar)?
> **Mi recomendación:** Sí, mostrar una versión simplificada con solo el stock ingresante calculado y la validación de sobrante/déficit.

> [!IMPORTANT]
> **Q3: Bloqueo de botón "GUARDAR DECISIÓN" en el modal**: ¿Debería el botón "GUARDAR DECISIÓN" del modal bloquearse si hay déficit de stock? ¿O solo mostrar advertencia y permitir guardar?
> **Mi recomendación:** Permitir guardar pero con advertencia visual (botón naranja con icono ⚠️). El bloqueo real está en el botón "Guardar" de la pantalla principal via `hasUnresolvedStock`.

---

## Verification Plan

### Build Verification
```bash
cd app_movil && flutter analyze
```

### Manual Verification
1. **Tarjetas de variante**: Verificar que muestran precio correcto y badge de descuento.
2. **Vinculación con unidad diferente**: Vincular un producto con Docena a uno extraído como Unidad → Verificar que aparece la advertencia.
3. **Alertas de stock**: Crear escenario con 25 unidades y factor 12 → Verificar alerta naranja de sobrante (1 unidad).
4. **Alertas de déficit**: Crear escenario con 5 unidades y factor 12 → Verificar alerta roja.
5. **Reactividad**: Cambiar unidad de venta en el modal → Verificar que stock y costos se recalculan.
6. **Guard rail final**: Verificar que el botón "Guardar" de staging se bloquea con stock sin resolver.
