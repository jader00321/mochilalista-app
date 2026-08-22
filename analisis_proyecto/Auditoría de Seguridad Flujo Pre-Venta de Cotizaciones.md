# Auditoría de Seguridad: Flujo Pre-Venta de Cotizaciones

## Resumen Ejecutivo

Se realizó una auditoría profunda de **8 archivos** involucrados en el flujo de venta. La lógica existente es **sorprendentemente robusta** — ya cubre stock, precios, nombres y bundles. Sin embargo, se detectaron **3 vulnerabilidades críticas** y **2 debilidades menores** que podrían permitir ventas con datos desactualizados.

---

## Hallazgos de la Auditoría

### 🟢 Lo que YA funciona bien

| Componente | Estado |
|---|---|
| `validateIntegrity()` en `quotation_service.dart` | ✅ Compara stock, precios, nombres y bundles contra la BD real |
| Auto-downgrade de `READY → DRAFT` si hay stock insuficiente | ✅ Funciona en `_evaluateHealthAndAutoDowngrade()` |
| Banner de alerta visual en la pantalla de detalle | ✅ Se muestra correctamente |
| `SmartUpdateModal` (Centro de Resoluciones) | ✅ Muy completo, con acciones individuales y masivas |
| Verificación de "Última Milla" en `checkout_progress_dialog.dart` | ✅ Verifica stock justo antes de descontar (líneas 102-123) |

---

### 🔴 VULNERABILIDAD #1: El botón "VENDER" permite navegar a Checkout con BundleChanges activas

**Archivo**: [`quotation_action_buttons.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/detalle/quotation_action_buttons.dart#L141-L148)

**Línea crítica (143)**:
```dart
if (canSell && warningCount == 0) {
   Navigator.push(context, MaterialPageRoute(builder: (_) => SalesCheckoutScreen(quotationId: quotationId)));
}
```

**El problema**: `canSell` solo se pone en `false` cuando hay `stockWarnings`. Los `bundleChanges` con cambios de **nombre, precio o composición** (pero sin bundle eliminado/desactivado) ponen `hasIssues = true` pero **NO bloquean `canSell`**.

`warningCount` se calcula como:
```dart
int warningCount = (validation?.priceChanges.length ?? 0) + (validation?.nameChanges.length ?? 0);
```
**¡Los `bundleChanges` NO se incluyen en `warningCount`!** Esto significa que si una oferta cambió de precio o composición (pero no fue eliminada ni desactivada), el usuario puede presionar "VENDER" directamente y navegar al Checkout sin ver ninguna alerta.

> [!CAUTION]
> **Impacto**: Una oferta que antes costaba S/ 25.00 y ahora cuesta S/ 35.00 se venderá al precio viejo (S/ 25.00), causando pérdida financiera. Peor aún, si los productos internos cambiaron, se descontarán los productos equivocados del inventario.

---

### 🔴 VULNERABILIDAD #2: La "Última Milla" del Checkout NO verifica Bundles

**Archivo**: [`checkout_progress_dialog.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/checkout/checkout_progress_dialog.dart#L102-L123)

```dart
// Líneas 102-123: Solo verifica presentationId directo
for (var item in widget.quotation.items) {
  if (item.presentationId != null) {
    // Solo chequea stock de presentaciones individuales
  }
}
```

**El problema**: Si un ítem tiene `bundleId != null` pero `presentationId == null` (como es el caso de las ofertas/paquetes), este loop **lo ignora completamente**. La verificación de última milla no descompone el bundle en sus items internos para verificar el stock de cada componente.

> [!CAUTION]
> **Impacto**: Si entre que el usuario abre la pantalla de Checkout y presiona "Confirmar Venta" alguien vende un producto que era componente de un paquete (dejándolo en stock 0), la venta procederá sin error y dejará el inventario en **negativo**.

---

### 🔴 VULNERABILIDAD #3: `SalesCheckoutScreen` NO ejecuta ninguna validación de integridad

**Archivo**: [`sales_checkout_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/sales_checkout_screen.dart#L70-L92)

```dart
Future<void> _loadQuotation() async {
  final q = await qProvider.getQuotationById(widget.quotationId);
  // Solo carga la cotización y el cliente
  // ⚠️ NO llama a checkTrafficLight() ni validateIntegrity()
}
```

**El problema**: Cuando el usuario navega desde `QuotationDetailScreen` al `SalesCheckoutScreen`, la pantalla de checkout **simplemente carga la cotización guardada** sin re-validar contra el inventario real. Si pasaron minutos (o incluso horas) entre que el usuario abrió el detalle y presionó "Vender", los datos podrían estar desactualizados.

> [!WARNING]
> **Impacto**: La pantalla de Checkout muestra precios y totales que podrían ser incorrectos. El usuario configura cuotas, descuentos y entrega basándose en un total que ya no refleja la realidad.

---

### 🟡 DEBILIDAD MENOR #1: `bundleChanges` con cambios estructurales NO bloquean `canSell`

**Archivo**: [`quotation_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/quotation_service.dart#L194-L205)

Cuando se detectan cambios en un bundle (nombre, precio, composición) **que no es eliminado ni desactivado**, el servicio establece `hasIssues = true` pero **no toca `canSell`**. Esto es correcto para cambios cosméticos, pero un cambio de **composición** (productos internos diferentes) debería ser BLOQUEANTE, ya que se descontarían productos equivocados del inventario.

---

### 🟡 DEBILIDAD MENOR #2: Auto-downgrade solo aplica a cotizaciones con `status == 'READY'`

**Archivo**: [`workbench_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/workbench_provider.dart#L221-L228)

Si una cotización tiene `status == 'PENDING'` y tiene problemas de integridad, el auto-downgrade **no la toca**. Esto es un comportamiento aceptable a nivel funcional, pero significa que el usuario podría cambiar manualmente de `PENDING → READY` y luego intentar vender sin que se re-evalúe la integridad si la caché del `_trafficLights` no se ha refrescado.

---

## Propuesta de Implementación por Fases

### Fase 1: Cierre de Vulnerabilidades Críticas (Backend/Lógica)

#### 1.1 — Incluir `bundleChanges` en el conteo de alertas y bloqueo

**Archivo**: [`quotation_action_buttons.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/detalle/quotation_action_buttons.dart)

- Agregar `bundleChanges.length` al cálculo de `warningCount`.
- Si algún `BundleChange` tiene `isDeleted`, `isDeactivated`, o cambios de **composición** (no solo nombre/precio), debe forzar `canSell = false` a nivel del botón.

#### 1.2 — Clasificar cambios de bundles como BLOQUEANTES vs. ADVERTENCIA

**Archivo**: [`quotation_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/quotation_service.dart) — método `validateIntegrity()`

- Los cambios de **composición** (productos diferentes, cantidades cambiadas, productos agregados/removidos) → `canSell = false`.
- Los cambios de **solo nombre o solo precio** del bundle → `hasIssues = true` pero `canSell` se mantiene (es advertencia).

#### 1.3 — Ampliar la verificación de "Última Milla" para incluir bundles

**Archivo**: [`checkout_progress_dialog.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/checkout/checkout_progress_dialog.dart)

- Para ítems con `bundleId != null`: consultar `items_paquete` y verificar stock de cada `presentacion_id` componente.
- Si algún componente tiene stock insuficiente, lanzar la excepción bloqueante.

---

### Fase 2: Validación de Integridad en el Checkout (Barrera de Entrada)

#### 2.1 — Ejecutar `validateIntegrity()` al cargar `SalesCheckoutScreen`

**Archivo**: [`sales_checkout_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/sales_checkout_screen.dart)

- Después de cargar la cotización en `_loadQuotation()`, llamar a `checkTrafficLight()`.
- Si la validación devuelve `canSell == false` o contiene `bundleChanges` bloqueantes:
  - **Bloquear la pantalla** mostrando un modal/overlay que impida interactuar con los controles de pago.
  - Proporcionar un botón para volver a la pantalla de detalle (donde puede usar el Centro de Resoluciones).

---

### Fase 3: Feedback Visual Premium y Redirección a Edición

#### 3.1 — Modal de "Venta Bloqueada" profesional

**Ubicación**: Se creará como widget inline en `SalesCheckoutScreen` (overlay sobre el contenido).

**Diseño propuesto**:
- Icono: `Icons.shield` con animación de pulso en rojo.
- Título: **"Venta Bloqueada"**
- Subtítulo: **"Se detectaron cambios en el inventario que afectan esta cotización"**
- Lista de problemas detectados (ej: "La oferta 'Pack Escolar 2025' cambió de composición", "2 productos agotados")
- Botón primario: **"Ir a Corregir"** → Navega `pop()` de vuelta al detalle.
- Botón secundario: **"Refrescar y Reintentar"** → Re-ejecuta la validación.

#### 3.2 — Indicador visual en `quotation_action_buttons.dart`

- Si hay `bundleChanges` presentes, el botón debe mostrar etiqueta **"VENDER (X alertas)"** en color naranja (igual que los priceChanges), para que el usuario sepa que debe revisar antes de proceder.

---

## Verificación

### Automated Tests
- `flutter analyze` para verificar limpieza de código.

### Manual Verification
- **Escenario A**: Crear una cotización con un bundle, modificar la composición del bundle (agregar/quitar producto), intentar vender → Debe bloquearse.
- **Escenario B**: Crear cotización con bundle, cambiar solo el precio del bundle → Debe mostrar advertencia naranja pero permitir vender.
- **Escenario C**: Navegar al Checkout, desde otra sesión agotar un producto componente de un paquete, presionar "Confirmar Venta" → Debe lanzar error de última milla.
- **Escenario D**: Abrir una cotización antigua en detalle, presionar "Vender" cuando hay bundles eliminados → Debe bloquearse con modal profesional.

---

## Open Questions

> [!IMPORTANT]
> **¿Los cambios de precio en bundles deben ser BLOQUEANTES o solo ADVERTENCIA?**
> Mi recomendación es tratarlos como **advertencia** (igual que los `PriceChange` de productos individuales), porque el precio cotizado es un compromiso con el cliente. Pero si prefieres que cualquier cambio en un bundle sea bloqueante, puedo ajustar la lógica.
