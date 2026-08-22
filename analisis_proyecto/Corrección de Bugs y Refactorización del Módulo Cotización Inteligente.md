# Corrección de Bugs y Refactorización del Módulo Cotización Inteligente

## Resumen del Análisis

Tras una auditoría profunda de los archivos clave, he identificado las causas raíz de cada problema reportado. A continuación, el plan técnico organizado por fases.

---

## Fase 1: Estabilización de Estado (Bugs Críticos)

### Problema 1A: Excepción Silenciosa del Modal (`onTap` bloqueado)

**Causa Raíz Identificada:** En [`_openDetailsModal`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart#L430-L494), la línea 436 usa `firstWhere` **sin** `orElse` dentro de un `try-catch`. Si el `InventoryProvider` no tiene cargado el producto (por ejemplo, si el inventario fue recargado o paginado), el `catch` crea un `Product` de emergencia. Sin embargo, la **línea 454** vuelve a usar `firstWhere` con `orElse`, pero si `fullProduct.presentaciones` queda vacío o si `pair.selectedProduct` se vuelve `null` entre renders (race condition con `notifyListeners`), se lanza una excepción no capturada que **silencia el modal sin mostrar error**.

Además, la reconstrucción del `MatchedProduct` dentro del `onSave` callback (líneas 473-486) referencia `fullProduct!` y `brandName` que son variables locales del scope de `_openDetailsModal` — si el widget se reconstruye por un `notifyListeners` intermedio, estas closures quedan "huérfanas".

#### [MODIFY] [`matching_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart)
- Envolver **todo** el cuerpo de `_openDetailsModal` en un `try-catch` con log de error y snackbar de fallback.
- Agregar guard clauses explícitas: si `pair.selectedProduct` es null, retornar inmediatamente.
- Capturar `fullProduct` y `brandName` en variables `final` **antes** del `showModalBottomSheet` para prevenir closures huérfanas.
- Añadir validación defensiva para `presentaciones.isEmpty`.

---

### Problema 1B: Estado Visual Atascado tras Desvincular (Swipe Bug)

**Causa Raíz Identificada:** En [`matching_item_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart#L35-L42), el estado `_isExpanded` es **local** al `State` del widget. Cuando el usuario presiona "Desvincular", se ejecuta `onUnlink` → `matchingProvider.unmatchItem()` → `pair.selectedProduct = null` → `notifyListeners()`.

El `AnimatedSwitcher` en la línea 98 detecta el cambio de `product == null` y muestra `_buildUnlinkedState`. **PERO** `_isExpanded` sigue siendo `true`, lo que hace que el `AnimatedContainer` de la izquierda (línea 75-80) mantenga su width en `50.0` (comprimido) en lugar de volver a `MediaQuery.of(context).size.width * 0.30`.

El widget **no resetea** `_isExpanded = false` cuando el producto pasa de vinculado a desvinculado.

#### [MODIFY] [`matching_item_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart)
- Añadir un `didUpdateWidget` override que compare `oldWidget.pair.selectedProduct != null` con `widget.pair.selectedProduct == null`. Si el producto fue desvinculado, forzar `_isExpanded = false`.
- Esto garantiza que la tarjeta izquierda vuelva a su tamaño original inmediatamente al desvincular.

---

## Fase 2: Arquitectura Financiera de Descuentos

### Problema 2: Lógica de Precios Confusa y Potencialmente Destructiva

**Análisis del Modelo Matemático Actual:**

El flujo actual tiene una cadena de dependencias problemática:

```
InventoryWrapper.effectivePrice → ya aplica la oferta de catálogo automáticamente
                                     ↓
_getCurrentListPrice() → retorna effectivePrice (precio YA con oferta)
                                     ↓
_onDiscountChanged() → calcula: (precio_ya_ofertado) - descuento_manual
                                     ↓
RESULTADO: Descuento doble (oferta + manual sobre la oferta)
```

**Lo que el usuario experimenta (visto en capturas):**
1. Un producto tiene `precioVentaFinal = 1.63` y `precioOferta = 1.13`.
2. La sección "Ofertas Disponibles" muestra "Descuento de Catálogo: 1.13 S/" pero **no se puede desactivar** — no hay opción de "vender a precio normal".
3. Si activa "Precio Especial al Cliente", `_getCurrentListPrice()` retorna `1.13` (la oferta). El descuento manual se aplica **sobre 1.13**, no sobre `1.63`. El usuario no puede, por ejemplo, dar un descuento de S/ 0.30 sobre el precio base real.

**Arquitectura Propuesta — Precio Base Inmutable + 3 Modos Exclusivos:**

```
precioVentaFinal (PRECIO BASE INMUTABLE — siempre visible, nunca se modifica)
    ↓
┌─────────────────────────────────────────┐
│  MODO 1: Precio Normal (sin descuento) │  → finalPrice = precioVentaFinal
│  MODO 2: Oferta de Catálogo            │  → finalPrice = precioOferta
│  MODO 3: Precio Especial Manual        │  → finalPrice = precioVentaFinal - descuento_manual
└─────────────────────────────────────────┘
```

> [!IMPORTANT]
> Los tres modos son **mutuamente excluyentes**. El descuento manual del Modo 3 siempre parte del `precioVentaFinal` (Precio Base), **nunca** del `precioOferta`. Esto elimina el descuento encadenado.

#### [MODIFY] [`product_quote_detail_modal.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/product_quote_detail_modal.dart)
- Reemplazar la variable `_isManualPrice` (bool) por un **enum** `_PricingMode { normal, catalogOffer, manualDiscount }`.
- Crear nueva variable `late _PricingMode _pricingMode` inicializada según el estado entrante.
- Refactorizar `_getCurrentListPrice()` → `_getEffectivePrice()` que retorne el precio según el modo activo:
  - `normal` → `precioVentaFinal`
  - `catalogOffer` → `precioOferta`
  - `manualDiscount` → `precioVentaFinal - descuento`
- Refactorizar `_onDiscountChanged()` para que siempre calcule contra `precioVentaFinal`.
- Refactorizar `_handleSave()` para que pase el `overridePrice` correcto según el modo.

---

## Fase 3: Rediseño del Modal de Detalles (UI de Descuentos)

### Nuevo Layout de la Sección de Precios

La sección actual de "Ofertas Disponibles" + "Precio Especial al Cliente" será reemplazada por un **selector de precio unificado** con 3 opciones mutuamente excluyentes presentadas como radio buttons temáticos.

#### [MODIFY] [`product_quote_detail_modal.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/product_quote_detail_modal.dart)

**Nuevo widget `_buildPricingSection`:**
```
┌──────────────────────────────────────────────┐
│  💰 Método de Precio                          │
│                                              │
│  ◉ Precio Normal          S/ 1.63           │
│    Sin descuento aplicado                    │
│                                              │
│  ○ Oferta de Catálogo     S/ 1.13  (-30%)   │
│    Descuento individual activo               │
│    (Solo visible si existe precioOferta)      │
│                                              │
│  ○ Precio Especial Manual                    │
│    ┌─────────────┬──────────────────┐        │
│    │ Descuento   │ Precio Final     │        │
│    │ - S/ ____   │ S/ 1.33          │        │
│    └─────────────┴──────────────────┘        │
│    Base: S/ 1.63 → Menos S/ 0.30            │
│                                              │
│  Paquetes Disponibles (info, no selección):  │
│  ★ Pack Escolar (S/ 45.00) — Informativo     │
└──────────────────────────────────────────────┘
```

**Características clave de la UI:**
- Los radio buttons tienen styling temático: verde para oferta activa, naranja para manual, neutro para normal.
- El panel de descuento manual se muestra/oculta con `AnimatedCrossFade`.
- Debajo del input manual se muestra en tiempo real: `Base: S/ X.XX → Menos S/ Y.YY = Final: S/ Z.ZZ` con colores de guía.
- Los paquetes (bundles) se mantienen como **informativos** (no se activan desde el modal).

---

## Fase 4: Refactorización UI de Cabecera del Cliente

### Problema 4: UI Estática y Checkbox Tosco

**Estado actual:** El [`ManualQuoteClientHeader`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/manual/manual_quote_client_header.dart) usa un `CheckboxListTile` para "Guardar en CRM" que se siente cuadrado y desconectado del diseño premium.

#### [MODIFY] [`manual_quote_client_header.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/manual/manual_quote_client_header.dart)
- **Reemplazar `CheckboxListTile`** por un `SwitchListTile` moderno con icono de `Icons.cloud_sync` (o `Icons.person_add_alt_1`) y colores temáticos.
- **Envolver la sección de campos secundarios** (DNI, Dirección, Correo, Notas) dentro de un `AnimatedSize` para que la expansión sea suave en lugar del salto brusco del `ExpansionTile` actual.
- Añadir un indicador visual de "guardado automático" cuando `isNewClientMode` está activo.

---

## Verificación

### Pruebas Manuales
1. **Fase 1A:** Abrir y cerrar el modal de detalles repetidamente (>10 veces), incluyendo cambiar de variante, para verificar que no se bloquea.
2. **Fase 1B:** Expandir tarjeta → Desvincular → Verificar que la tarjeta izquierda vuelve a tamaño completo.
3. **Fase 2+3:** Probar los 3 modos de precio en un producto con oferta de catálogo, verificando que el cálculo **siempre** parte del Precio Base.
4. **Fase 4:** Verificar la animación suave del panel del cliente y el nuevo switch de CRM.

### Compilación
- `dart analyze` sobre los archivos modificados para verificar 0 errores.

---

## Resumen de Archivos a Modificar

| Archivo | Fase | Cambio Principal |
|---------|------|-----------------|
| `matching_screen.dart` | 1A | Try-catch + guards en `_openDetailsModal` |
| `matching_item_row.dart` | 1B | `didUpdateWidget` → reset `_isExpanded` |
| `product_quote_detail_modal.dart` | 2+3 | Enum `_PricingMode` + nueva UI de radio buttons |
| `manual_quote_client_header.dart` | 4 | `SwitchListTile` + `AnimatedSize` |
