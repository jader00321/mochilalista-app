# Plan de Trabajo: Corrección Financiera y Auditoría de Flujo de Cotización (v2 — DEFINITIVO)

## Resumen de la Auditoría

Archivos analizados: **14 en total** (incluyendo `sales_service.dart`, `quotation_service.dart`, `local_db.dart`).

---

## 🔴 Hallazgos Críticos (Actualizados con Capturas)

### Hallazgo #1: Bundles Sobreescriben Ofertas Individuales Más Baratas (CONFIRMADO EN CAPTURA)

**Evidencia visual:** En la captura 3, el producto "Block de Cartulina CAMY" muestra:
- "Precio de Lista: 3,46 S/" (que es el `precioOferta`)
- "Precio Final Unit. S/ 4.32" (que es el `overridePrice` del bundle)

**¿Cómo ocurre?** En [`matching_provider.dart:216-222`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/matching_provider.dart#L216-L222):

```dart
double totalOriginal = matchedPairsForBundle.fold(0.0, 
    (sum, p) => sum + (p.originalUnitPrice * p.selectedQuantity));
// originalUnitPrice = precioVentaFinal = 4.32
double discountFactor = bundle.precioVentaTotal / totalOriginal;
p.overridePrice = p.originalUnitPrice * discountFactor;
// overridePrice = 4.32 * factor = ~4.00+ (MAYOR que offerPrice 3.46)
```

El bundle calcula su descuento sobre `originalUnitPrice` (`precioVentaFinal = 4.32`), sin considerar que el producto ya tiene un `precioOferta = 3.46` que es **más barato**. Luego, en `effectiveUnitPrice`:

```dart
// overridePrice (4.00) ?? offerPrice (3.46) ?? price (4.32)
// Retorna 4.00 porque overridePrice tiene prioridad
```

> [!CAUTION]
> **Resultado:** El usuario ve S/ 4.32 como "precio final" cuando la oferta individual es S/ 3.46. El bundle **encarece** el producto en lugar de abaratarlo. Este es un **error financiero grave** que genera cobro excesivo al cliente.

---

### Hallazgo #2: Precio Mostrado como "Precio de Lista" es el Precio con Descuento

En [`product_quote_detail_modal.dart:124-128`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/product_quote_detail_modal.dart#L124-L128):

```dart
double _getCurrentListPrice() {
    return _selectedPresentation.precioOferta != null && precioOferta! > 0 
           ? _selectedPresentation.precioOferta! 
           : _selectedPresentation.precioVentaFinal;
}
```

La UI etiqueta esto como **"Precio de Lista"** (captura 1, línea 505 del modal), pero en realidad es el precio **ya descontado** (`precioOferta`). El precio base real (`precioVentaFinal`) nunca se muestra, impidiendo que el usuario entienda la composición del descuento.

---

### Hallazgo #3: Desborde Visual en Tarjeta Expandida (Captura 2)

En la captura 2, la tarjeta #14 ("Block medio 99") en estado expandido muestra los dígitos del precio apilados verticalmente: `4`, `7`, `3`, `2`, `S/`. 

**Causa raíz:** En la zona de precios expandida ([`matching_item_row.dart:262-348`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart#L262-L348)), el `AnimatedCrossFade` del control de cantidad en estado expandido (`firstChild: Column(...)` con el container de `+/-`) tiene un ancho fijo implícito. Cuando el texto del precio y el control `+/-` compiten por espacio horizontal, el `Expanded` del precio se reduce a un ancho mínimo y el texto colapsa verticalmente porque el `FittedBox` solo escala hacia abajo, no controla el wrapping de caracteres individuales.

---

### Hallazgo #4: Nombre de Tabla SQL Incorrecto (`paquetes_promocion` → `paquetes`)

La tabla real es `paquetes` ([`local_db.dart:164`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/database/local_db.dart#L164)). No existe ninguna tabla `paquetes_promocion`.

**6 referencias incorrectas en 2 archivos:**

| Archivo | Líneas | Impacto |
|---------|--------|---------|
| [`matching_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/matching_service.dart#L193) | 193 | `bundle_items_snapshot` se guarda como `null` |
| [`quotation_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/quotation_service.dart#L103) | 103 | Validación pre-venta marca bundles válidos como "eliminados" |
| [`quotation_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/quotation_service.dart#L336) | 336 | Guardado manual pierde snapshot |
| [`quotation_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/quotation_service.dart#L394) | 394 | Refresh de cotización falla para bundles |

---

## Propuesta de Cambios por Fases

### Fase 1: Corrección Lógica de Descuentos y Reflejo en UI

> **Objetivo:** Separar precio base vs precio oferta. Corregir la lógica de bundles que sobreescribe ofertas más baratas. Corregir desborde visual.

#### [MODIFY] [`matching_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/matching_provider.dart) — `_detectAndApplyBundles()`

**Bug crítico:** El bundle debe comparar contra `effectiveUnitPrice` (que ya incluye `offerPrice`), NO contra `originalUnitPrice` (`precioVentaFinal`). Además, el `overridePrice` solo debe aplicarse si realmente es **menor** que el `effectiveUnitPrice` actual del par.

Cambios:
```dart
// ANTES (incorrecto):
double totalOriginal = matchedPairsForBundle.fold(0.0, 
    (sum, p) => sum + (p.originalUnitPrice * p.selectedQuantity));
// ...
p.overridePrice = p.originalUnitPrice * discountFactor;

// DESPUÉS (correcto):
double totalEffective = matchedPairsForBundle.fold(0.0, 
    (sum, p) => sum + (p.effectiveUnitPrice * p.selectedQuantity));
// Solo aplicar si el bundle es realmente más barato
if (totalEffective > 0 && bundle.precioVentaTotal < totalEffective) {
    double discountFactor = bundle.precioVentaTotal / totalEffective;
    for (var p in matchedPairsForBundle) {
        double bundlePrice = p.effectiveUnitPrice * discountFactor;
        // Solo sobreescribir si el precio del bundle es realmente menor
        if (bundlePrice < p.effectiveUnitPrice) {
            p.bundleId = bundle.id;
            p.overridePrice = bundlePrice;
        }
    }
}
```

#### [MODIFY] [`product_quote_detail_modal.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/product_quote_detail_modal.dart) — Transparencia de precios

1. **Agregar `_getBasePrice()`** que siempre retorne `precioVentaFinal`.

2. **Renombrar `_getCurrentListPrice()` a `_getEffectivePrice()`** (mantiene la misma lógica: `offerPrice ?? precioVentaFinal`).

3. **En la UI del `SwitchListTile`:** Cuando existe `precioOferta`, mostrar:
   - ~~"Precio de Lista: S/ 3.46"~~ → **"Precio Base: S/ 4.32"** (tachado) + **"Oferta: S/ 3.46"** (resaltado en verde).
   - Si NO tiene `precioOferta`: **"Precio de Lista: S/ 4.32"** (sin cambios).

4. **Validación en `initState`:** Si `currentOverridePrice > effectivePrice`, forzar `_priceCtrl.text` al `effectivePrice` para no mostrar precios inflados heredados de un bundle mal aplicado.

5. **Limitar precio máximo en `_onPriceChanged`:** Mantener el cap contra `_getEffectivePrice()` (el tope es el precio con oferta, no el base).

#### [MODIFY] [`matching_item_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart) — Desborde visual

**Corrección del desborde en captura 2:** En la zona de precios expandida (líneas 262-348), el `Row` que contiene el precio y el control `+/-` no tiene restricciones adecuadas.

- Envolver el `AnimatedCrossFade` de controles en un `ConstrainedBox` o `SizedBox` con `width` fijo (ej: `width: 110`) para que no comprima infinitamente el `Expanded` del precio.
- Asegurar que el precio use `FittedBox` con `maxLines: 1` y `softWrap: false` para evitar el apilamiento vertical de caracteres.

---

### Fase 2: Auditoría y Optimización de la Pantalla de Validación

> **Objetivo:** Mejorar rendimiento y UX en `extraction_result_screen.dart`.

#### [MODIFY] [`extraction_result_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/extraction_result_screen.dart)

1. **Debounce en `_saveToProvider`:** Agregar un `Timer` de 300ms en `_InternalItemCardState`. Cada `onChanged` cancela el timer anterior y reinicia. Solo al expirar se llama a `provider.updateItem()`. Esto evita 30+ rebuilds por tecla.

2. **Contador en botón COTIZAR:** Cambiar el label para incluir conteo de items listos:
   ```dart
   int readyCount = provider.items.where((i) => i.fullName.trim().isNotEmpty).length;
   label: Text("COTIZAR ($readyCount/${provider.items.length})")
   ```

3. **Auto-scroll al añadir fila:** Después de `provider.addItem()`, ejecutar:
   ```dart
   WidgetsBinding.instance.addPostFrameCallback((_) {
     _scrollController.animateTo(
       _scrollController.position.maxScrollExtent + 200,
       duration: const Duration(milliseconds: 400),
       curve: Curves.easeOut,
     );
   });
   ```

---

### Fase 3: Corrección de Tabla SQL, Guardado y Política de Stock

> **Objetivo:** Corregir queries rotos, eliminar agrupación de duplicados, y aplicar política de stock correcta.

#### [MODIFY] [`matching_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/matching_service.dart)

- Línea 193: `'paquetes_promocion'` → `'paquetes'`.

#### [MODIFY] [`quotation_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/quotation_service.dart)

- Líneas 103, 336, 394: Todas las ocurrencias de `'paquetes_promocion'` → `'paquetes'`.

#### [MODIFY] [`matching_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/matching_provider.dart) — `saveQuotation()`

**Cambio 1: Eliminar agrupación de duplicados.** El usuario indicó que prefiere que items con el mismo `presentationId` pero precios diferentes se guarden por separado, ya que puede ser una estrategia de venta válida.

Reemplazar el bloque de agrupación (líneas 335-358):
```dart
// ANTES: Agrupaba por presentationId y tomaba el precio más bajo
final Map<int, Map<String, dynamic>> groupedItems = {};
for (var p in _pairs.where((p) => p.selectedProduct != null)) {
  int pId = p.selectedProduct!.presentationId;
  if (groupedItems.containsKey(pId)) { /* agrupación */ }
  else { groupedItems[pId] = p.toQuotationItemJson()!; }
}

// DESPUÉS: Cada par se guarda como un item independiente
final List<Map<String, dynamic>> validItems = [];
for (var p in _pairs.where((p) => p.selectedProduct != null)) {
  var itemJson = p.toQuotationItemJson();
  if (itemJson != null) validItems.add(itemJson);
}
```

**Cambio 2: Política de stock.** El sistema de cotización por IA **DEBE** permitir guardar la cotización aunque haya productos sin stock suficiente. La cotización es una propuesta para el cliente, y el stock se conseguirá después. El bloqueo de stock solo debe ocurrir en el momento de la **venta**.

Verificación en `sales_service.dart`:
- ✅ **Confirmado:** [`sales_service.dart:88`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/sales_service.dart#L88) ya lanza `Exception("Stock insuficiente...")` al intentar vender con stock insuficiente para bundles.
- ✅ **Confirmado:** [`sales_service.dart:119-121`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/sales_service.dart#L119-L121) ya lanza `Exception("Stock insuficiente...")` para productos individuales.
- ✅ **Confirmado:** `matching_provider.saveQuotation()` **NO** bloquea por stock al guardar cotizaciones. Esto es correcto.

**Resultado:** No se requieren cambios en la política de stock. La arquitectura ya es correcta: cotizar = sin bloqueo, vender = con bloqueo.

#### Verificación de compatibilidad en otros sistemas

He verificado que los siguientes flujos aceptan items duplicados (mismo `presentationId` con precios diferentes) sin problemas:

| Sistema | Archivo | ¿Compatible? | Detalles |
|---------|---------|:---:|---------|
| **Clonar cotización** | [`quotation_service.dart:10-48`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/quotation_service.dart#L10-L48) | ✅ | Clona items 1:1 del original sin agrupar |
| **Editar cotización** | [`quotation_service.dart:325-375`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/quotation_service.dart#L325-L375) | ✅ | Borra y re-inserta todos los items |
| **Refresh cotización** | [`quotation_service.dart:386-535`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/quotation_service.dart#L386-L535) | ✅ | Actualiza cada item individualmente por `id` |
| **Vender cotización** | [`sales_service.dart:45-70`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/sales_service.dart#L45-L70) | ✅ | Itera items 1:1 y descuenta stock por cada uno |
| **Validar integridad** | [`quotation_service.dart:51-115`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/quotation_service.dart#L51-L115) | ✅ | Valida cada item independientemente |

Todos los sistemas iteran items individualmente sin depender de unicidad de `presentationId`.

---

### Fase 4: Campo `discount_catalog_amount` y Trazabilidad de Descuentos

> **Objetivo:** Persistir exactamente cuánto del descuento viene del catálogo vs cuánto es manual, para auditoría financiera posterior.

#### Análisis Estructural

Actualmente, la tabla `smart_quotation_items` guarda:
- `unit_price_applied`: El precio final que se cobra (incluye todos los descuentos).
- `original_unit_price`: El `precioVentaFinal` (precio base sin descuento de catálogo).
- `is_manual_price`: Booleano que indica si el usuario aplicó un precio especial.

**Lo que falta:** No hay forma de saber, al revisar una cotización guardada, cuánto del descuento es automático (de catálogo/oferta) y cuánto fue manual del vendedor. Esto impide:
- Reportes de margen real vs margen con descuento.
- Auditoría de vendedores que aplican descuentos excesivos.
- Análisis de efectividad de las ofertas de catálogo.

#### Propuesta de Implementación

##### [MODIFY] [`local_db.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/database/local_db.dart) — Migración v18

Agregar nueva columna a `smart_quotation_items`:
```sql
ALTER TABLE smart_quotation_items ADD COLUMN discount_catalog_amount REAL DEFAULT 0.0
```

Semántica:
- `discount_catalog_amount` = `precioVentaFinal - precioOferta` (si aplica oferta de catálogo), o `0.0` si no hay oferta.
- El descuento manual se puede calcular como: `precioOferta (o precioVentaFinal) - unit_price_applied`.
- **Fórmula completa:** `original_unit_price - unit_price_applied = discount_catalog_amount + descuento_manual`.

##### [MODIFY] [`matching_model.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/models/matching_model.dart) — `toQuotationItemJson()`

Agregar el cálculo:
```dart
"discount_catalog_amount": (selectedProduct!.offerPrice != null && selectedProduct!.offerPrice! > 0)
    ? (selectedProduct!.price - selectedProduct!.offerPrice!)
    : 0.0,
```

##### [MODIFY] [`matching_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/matching_service.dart) — `saveQuotation()`

Agregar `'discount_catalog_amount': item['discount_catalog_amount'] ?? 0.0` al insert de `smart_quotation_items`.

##### [MODIFY] [`quotation_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/quotation_service.dart) — Guardado manual y refresh

- En `saveOrUpdateManualQuotation` (línea 355): agregar `'discount_catalog_amount'` al insert.
- En `refreshQuotation` con `fixPrices` (líneas 472-478): recalcular `discount_catalog_amount` cuando se actualizan precios:
  ```dart
  double basePrice = (p['precio_venta_final'] as num).toDouble();
  double offerPrice = (p['precio_oferta'] != null && (p['precio_oferta'] as num) > 0) 
      ? (p['precio_oferta'] as num).toDouble() : basePrice;
  updates['discount_catalog_amount'] = basePrice - offerPrice;
  ```

##### Datos existentes

Para cotizaciones ya guardadas (sin la columna), el valor será `0.0` por defecto. Esto es aceptable porque no tenemos forma retroactiva de saber si tenían oferta de catálogo.

---

## Plan de Verificación

### Compilación
- `flutter build apk` debe pasar sin errores.

### Pruebas Funcionales

| # | Test | Resultado Esperado |
|---|------|-------------------|
| 1 | Abrir modal de producto con `precioOferta` | Muestra precio base tachado, precio oferta en verde |
| 2 | Activar "Precio Especial al Cliente" sobre producto con oferta | El descuento se calcula sobre el precio oferta, NO sobre el base |
| 3 | Producto en bundle con oferta individual más barata | El bundle NO sobreescribe la oferta. El precio mostrado es el de la oferta individual |
| 4 | Guardar cotización con productos sin stock | Se guarda exitosamente (sin bloqueo) |
| 5 | Vender cotización con producto sin stock | Se BLOQUEA con mensaje de error |
| 6 | Vincular mismo producto a 2 filas con precios diferentes | Se guardan como 2 items separados |
| 7 | Verificar `bundle_items_snapshot` | Ya no es `null` (queries usan `paquetes` correctamente) |
| 8 | Editar nombre en pantalla de Validación | El debounce impide rebuilds excesivos |
| 9 | Tarjeta expandida con precio largo | El precio escala correctamente sin desborde vertical |
