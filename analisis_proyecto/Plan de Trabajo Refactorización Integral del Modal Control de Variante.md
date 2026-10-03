# Plan de Trabajo: Refactorización Integral del Modal "Control de Variante"

## Contexto y Comprensión del Problema

El modal `ComparativeUpdateModal` (ubicado en `comparative_modal/`) es el centro neurálgico donde el usuario decide cómo se registrarán los datos de compra y venta de cada variante extraída de una factura. Actualmente, las 4 secciones del modal (Compra, Venta, Stock, Descuento) operan de forma **casi aislada**: los campos no se recalculan correctamente entre sí cuando el usuario modifica un valor, y la interfaz visual tiene problemas de legibilidad y usabilidad.

### Archivos Involucrados

| Archivo | Rol |
|---------|-----|
| [`comparative_update_modal.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/comparative_modal/comparative_update_modal.dart) | Estado central, controllers, lógica de recálculo y `_applyChanges()` |
| [`modal_purchase_section.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/comparative_modal/ui/modal_purchase_section.dart) | UI de Comparativa de Compra (Proveedor) |
| [`modal_sale_section.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/comparative_modal/ui/modal_sale_section.dart) | UI de Cálculo Financiero (Unidades y Precios) |
| [`modal_stock_section.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/comparative_modal/ui/modal_stock_section.dart) | UI de Gestión de Stock + Alertas de sobrante/faltante |
| [`modal_discount_section.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/comparative_modal/ui/modal_discount_section.dart) | UI de Promociones/Descuentos |
| [`modal_helpers.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/comparative_modal/ui/modal_helpers.dart) | Widgets helpers reutilizables |
| [`scanner_models.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/models/scanner_models.dart) | Modelo `StagingVariant` (datos, snapshots, originales) |
| [`scanner_cost_engine.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_cost_engine.dart) | Motor de cálculos financieros |
| [`scanner_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/providers/scanner_provider.dart) | `createLeftoverVariant()`, `removeLeftoverVariantForSource()` |

---

## Fase 1: Sección "Comparativa de Compra (Proveedor)" — Sistema Reactivo Bidireccional

### Problemas Detectados
1. **Ud. Compra y Factor no son bidireccionales:** Al cambiar "Ud. Compra" (ej. de UND a Docena), el factor se actualiza, pero al cambiar el factor, la Ud. Compra no se actualiza siempre (solo funciona para factores conocidos via `UnitCatalogService.resolveFromFactor`).
2. **El recálculo no propaga correctamente:** `_onUmpNameChanged()` y `_onUmpFactorChanged()` llaman a `_onPurchaseDataChanged()`, pero esta función usa `widget.variant.totalPagoLote` (valor fijo del modelo) en lugar de leer dinámicamente de los controllers.
3. **Bloque "Último valor registrado":** Actualmente muestra los datos **vivos** del modelo (que cambian cuando el usuario edita). Debería mostrar los datos **originales de la factura** que son inmutables y sirven como referencia para restaurar.

### Solución Propuesta
- Corregir `_onUmpNameChanged()` y `_onUmpFactorChanged()` para que sean plenamente bidireccionales.
- Refactorizar `_onPurchaseDataChanged()` para que **siempre lea de los controllers** (no del modelo) y propague correctamente:
  - Si cambia **Cant. Comprada** o **P. Unitario** → recalcular **Pago Total**, **Costo Unitario** y propagar a sección Venta.
  - Si cambia **Pago Total** → recalcular **P. Unitario** (si Cant > 0), luego **Costo Unitario** y propagar.
  - Si cambia **Ud. Compra** o **Factor** → recalcular **Costo Unitario** (mismo total pero más/menos unidades base) y propagar.
- El bloque "Último valor registrado" usará los **getters `_original...`** del modelo `StagingVariant` que son inmutables (`_originalUmpCompra`, `_originalCantidadUmpComprada`, etc.), y el botón restaurar llenará los controllers con esos valores originales.

---

## Fase 2: Sección "Cálculo Financiero: Unidades y Precios" — Rediseño UI + Lógica Reactiva

### Problemas Detectados
1. **No hay campo de Factor de Venta visible:** El `SmartUnitSelector` en modo `isMini` muestra el campo de factor pero está muy apretado y no es claro.
2. **Falta campo de "Unidades Base Compradas":** El usuario necesita ver cuántas unidades individuales tiene (ej. 4 docenas = 48 unidades base).
3. **Falta campo de "Stock Final para Venta":** Si se vende en Par (x2) y hay 48 unidades base, el stock final es 24 Pares.
4. **El costo no se recalcula al cambiar datos de compra:** `_onUnidadVentaChanged()` usa `widget.variant.totalPagoLote` (fijo) en lugar de leer del controller de Pago Total.
5. **El scroll de chips para elegir unidades se ve muy apretado visualmente.**
6. **El bloque "Último valor registrado"** muestra datos que cambian (como el de compra). Debe usar originales fijos.

### Solución Propuesta

#### Rediseño Visual
- Separar la sección en sub-bloques claros:
  1. **Sub-bloque: Unidad de Venta** — Selector de unidad + factor con chips visuales mejorados (scroll horizontal con más espacio).
  2. **Sub-bloque: Cálculos** — Tabla clara con: Unidades Base, Stock Final (según unidad de venta elegida), Costo por Presentación, Margen, Precio de Venta.
  3. **Sub-bloque: Alerta de Sobrante/Faltante** — Se moverá aquí desde la sección de stock para mayor coherencia visual.

#### Lógica Reactiva
- `_onUnidadVentaChanged()` leerá siempre de los controllers de compra para calcular:
  ```
  costoUnitarioReal = totalPago / (cantidadUMP * unidadesPorLote)
  costoPresentación = costoUnitarioReal * factorDeVenta
  precioVenta = costoPresentación * margen
  unidadesBase = cantidadUMP * unidadesPorLote
  stockFinal = unidadesBase / factorDeVenta (parte entera)
  sobrante = unidadesBase % factorDeVenta
  ```
- Al cambiar cualquier dato de compra (Fase 1), se propagará automáticamente a esta sección.
- El bloque "Último valor registrado" usará los datos **originales** (`_originalUnidadVenta`, `_originalUnidadesPorVenta`, `_originalCostoSugerido`, etc.).

---

## Fase 3: Sección "Gestión de Stock" — Rediseño + Reactividad

### Problemas Detectados
1. El stock ingresante se calcula de forma estática y no reacciona correctamente a cambios en unidades compradas o unidades base.
2. La interfaz es funcional pero visualmente básica.

### Solución Propuesta
- El campo "Nuevo Ingreso" se recalculará automáticamente cuando cambien las unidades compradas o el factor del lote.
- Mejorar el diseño visual con iconografía más clara y separación entre las opciones "Sumar" y "Reemplazar".
- Mostrar el cálculo desglosado: `{cantidadUMP} × {factorLote} = {unidadesBase} unidades`.

---

## Fase 4: Sección "Descuento" — Rediseño UI + Lógica Mejorada

### Problemas Detectados
1. La interfaz actual es confusa: las 3 opciones (mantener, desactivar, editar) no explican claramente qué efecto tiene cada una.
2. Falta contexto visual sobre cómo impacta el precio final.

### Solución Propuesta
- Rediseñar con Cards visuales en lugar de RadioListTile planos.
- Cada opción mostrará un "preview" del precio resultante.
- La opción "Editar descuento" tendrá 2 sub-modos: por monto fijo o por porcentaje, con preview dinámico del precio oferta resultante.

---

## Fase 5: Variante Sobrante — Cierre de Modal + Validación

### Problemas Detectados
1. Al crear la variante sobrante, el modal se queda abierto y no se ve la variante nueva creada.
2. La alerta de sobrante/faltante no desaparece correctamente cuando el stock vuelve a ser exacto.

### Solución Propuesta
- Al presionar "Crear variante unitaria con sobrante":
  1. Primero se ejecuta `_applyChanges()` para guardar los datos actuales de la variante principal.
  2. Luego `_crearVarianteSobrante()`.
  3. Finalmente `Navigator.pop(context)` para cerrar el modal y que el usuario vea la nueva variante creada en la lista.
- La alerta se recalculará reactivamente cada vez que cambien los controllers de stock o factor de venta.

---

## Fase 6: Verificación de Persistencia en BD

### Objetivo
Asegurar que al presionar "GUARDAR DECISIÓN" → `_applyChanges()`, todos los datos se transfieran correctamente al modelo `StagingVariant`, y que posteriormente cuando el provider ejecute el guardado final en la BD, los datos de compra, venta y stock queden registrados sin errores.

### Verificaciones
- Cruzar cada campo del controller con su correspondiente en `_applyChanges()`.
- Verificar que `stockIngresanteOverride` se calcule correctamente respecto al factor de venta.
- Verificar que el `createLeftoverVariant()` herede correctamente el costo base de la variante padre.

---

## Open Questions

> [!IMPORTANT]
> **Sobre el bloque "Último valor registrado" en la sección de Compra:** ¿Quieres que muestre los datos originales extraídos de la factura (inmutables desde que se escaneó), o los datos que actualmente están guardados en la BD del inventario? Mi propuesta es que muestre los **datos originales de la factura** ya que eso es lo que se "extrajo" y sirve como referencia estática.

> [!IMPORTANT]
> **Sobre la alerta de sobrante en la sección de Venta:** ¿Deseas que el botón "Crear variante sobrante" aparezca directamente dentro de la sección de Venta (cerca del Stock Final), o prefieres mantenerlo como una alerta separada debajo de todas las secciones como está actualmente?
