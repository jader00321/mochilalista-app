# Integridad Transaccional, Reportes y UX del Historial de Ventas

Resolución de bugs graves de lógica financiera al anular/restaurar ventas, corrección del motor de exportación PDF/CSV, mejora de la UX del Historial de Ventas y auditoría de filtros temporales.

## User Review Required

> [!CAUTION]
> **Anular/Restaurar ventas es la operación más peligrosa de la app.** Actualmente, `toggleArchiveSale()` en el provider solo invoca `toggleArchive()` en el servicio, que simplemente cambia el bit `is_archived` entre 0 y 1. **NO devuelve stock, NO recalcula deuda del cliente, NO registra trazabilidad.** Esto significa que cada venta "anulada" hasta ahora ha dejado el inventario desincronizado.

> [!WARNING]
> **El reporte PDF siempre muestra "PRODS. VENDIDOS: 0" y "VENTAS TRANSF.: 0.00 S/"** porque la línea 108 de [`history_export_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/history_export_service.dart#L108) suma `sale.installments.length` en lugar de los ítems vendidos, y las líneas 126-128 hardcodean `0.0` en vez de calcular por método de pago.

## Open Questions

> [!IMPORTANT]
> **¿Qué hacer con las ventas ya anuladas históricamente?** Las ventas que fueron "anuladas" en versiones anteriores nunca devolvieron stock. ¿Deseas que implemente una migración one-time que detecte las ventas archivadas y devuelva retroactivamente el stock, o preferimos solo corregir el flujo hacia adelante (nuevas anulaciones)?

---

## Hallazgos de la Auditoría de Código

Tras analizar en profundidad 8 archivos clave, estos son los problemas detectados:

### Problema 1: `toggleArchive()` es una operación "ciega"
- **Archivo:** [`sales_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/sales_service.dart#L333-L344) (líneas 333-344)
- **Raíz:** Solo cambia `is_archived = 0/1`. No toca `presentaciones_producto.stock_actual`, no registra `stock_ledger`, no recalcula `clientes.deuda_total`, no actualiza `clientes.entregas_pendientes`.
- **Impacto:** Los productos vendidos nunca regresan al inventario. El margen mensual queda inflado. La deuda del cliente queda incorrecta.

### Problema 2: Reportes PDF con datos hardcodeados en cero
- **Archivo:** [`history_export_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/history_export_service.dart#L106-L131) (líneas 106-131)
- **Raíz L108:** `int totalItems = sales.fold(0, (sum, s) => sum + s.installments.length)` — Usa `installments.length` (cuotas de pago) en vez de sumar las cantidades de los ítems vendidos. Como la mayoría de ventas no tienen cuotas, da 0.
- **Raíz L126-128:** `buildMetricCard("VENTAS TRANSF.", currencyFmt.format(0.0), ...)` — Literalmente hardcodeado a `0.0`. Nunca se calcula por método de pago.

### Problema 3: Tarjetas estadísticas muestran "Ingresos" en pestaña de Anuladas
- **Archivo:** [`history_dashboard_cards.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/history/history_dashboard_cards.dart#L26-L61) (líneas 26-61)
- **Raíz:** Las tarjetas son estáticas. Siempre muestran "Ventas Realizadas / Ingresos / Por Cobrar" independientemente de la pestaña activa. Si estás en "Archivadas/Anuladas", los labels deberían cambiar a "Tickets Anulados / Monto Retenido / etc.".

### Problema 4: Buscador limitado a `nombre_completo` del cliente
- **Archivo:** [`sale_repository.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/repositories/sale_repository.dart#L41-L43) (líneas 41-43)
- **Raíz:** `query += " AND c.nombre_completo LIKE ?"` — Solo busca por nombre. No busca por `#recibo`, DNI/documento, ni método de pago.
- **Archivo:** [`history_filter_bar.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/history/history_filter_bar.dart#L143) (línea 143)
- **Raíz:** `onSubmitted` dispara la búsqueda solo al presionar Enter. No hay debounce en `onChanged`.

### Problema 5: Pestaña "Listas Escolares" con nomenclatura obsoleta
- **Archivo:** [`sales_history_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/sales_history_screen.dart#L201-L204) (líneas 201-204)

---

## Proposed Changes

### Fase 1: Integridad Transaccional (Lógica Financiera y Stock)

#### [MODIFY] [`sales_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/sales_service.dart)
- **Eliminar** la función actual `toggleArchive()` (líneas 333-344).
- **Crear** `voidSale(int saleId, int negocioId)`:
  1. Abrir transacción `db.transaction()`.
  2. Obtener los `venta_items` de la venta.
  3. Para cada ítem con `presentation_id`: sumar `cantidad` de vuelta a `presentaciones_producto.stock_actual`.
  4. Para cada ítem con `bundle_id`: recorrer `items_paquete` y sumar las cantidades proporcionales de vuelta.
  5. Registrar en `stock_ledger` con `tipo_transaccion: 'ANULACION'` y cantidad positiva.
  6. Marcar la venta como `is_archived = 1`.
  7. Si la venta tenía `cotizacion_id`, restablecer el estado de la cotización a `READY` (para que pueda re-venderse).
  8. Fuera de la transacción: llamar `recalculateClientDebt()` y `recalculateClientDeliveries()` si hay `cliente_id`.
- **Crear** `restoreSale(int saleId, int negocioId)`:
  1. Abrir transacción `db.transaction()`.
  2. Obtener los `venta_items` de la venta.
  3. Para cada ítem con `presentation_id`: **verificar** que `stock_actual >= cantidad`. Si no hay stock suficiente, lanzar excepción descriptiva.
  4. Restar stock nuevamente (re-descontar).
  5. Para ítems con `bundle_id`: verificar y restar componentes del paquete.
  6. Registrar en `stock_ledger` con `tipo_transaccion: 'RESTAURACION'` y cantidad negativa.
  7. Marcar la venta como `is_archived = 0`.
  8. Si la venta tenía `cotizacion_id`, restablecer la cotización a `SOLD`.
  9. Fuera de la transacción: recalcular deuda y entregas del cliente.

#### [MODIFY] [`sale_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/sale_provider.dart)
- **Reemplazar** `toggleArchiveSale()` (líneas 519-530) con dos métodos separados:
  - `voidSale(int saleId)`: Llama a `_salesService.voidSale()`, luego refresca lista y stats.
  - `restoreSale(int saleId)`: Llama a `_salesService.restoreSale()`, luego refresca lista y stats.

#### [MODIFY] [`sale_action_bottom_sheet.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/history/sale_action_bottom_sheet.dart)
- **Actualizar** `_toggleArchive()` (líneas 57-75):
  - Si `sale.isArchived == true` → llamar `provider.restoreSale()`.
  - Si `sale.isArchived == false` → llamar `provider.voidSale()`.
  - Mostrar feedback con `CustomSnackBar` indicando si se restauró o anuló.
  - Capturar excepciones de stock insuficiente al restaurar y mostrar mensaje descriptivo.
- **Agregar** diálogo de confirmación antes de anular (operación destructiva).

---

### Fase 2: Súper Buscador y UX del Historial

#### [MODIFY] [`sale_repository.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/repositories/sale_repository.dart)
- **Refactorizar** el bloque de búsqueda (líneas 41-43):
  - Cambiar de `AND c.nombre_completo LIKE ?` a una cláusula `AND (c.nombre_completo LIKE ? OR CAST(v.id AS TEXT) LIKE ? OR c.documento LIKE ? OR v.metodo_pago LIKE ?)`.
  - Agregar los 4 argumentos `%query%` en `args`.

#### [MODIFY] [`history_filter_bar.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/history/history_filter_bar.dart)
- **Agregar** `Debouncer` de 300ms al campo de búsqueda.
- **Cambiar** el `onSubmitted` por `onChanged` con debounce.
- **Actualizar** el `hintText` a: `"Buscar por cliente, #recibo, DNI o método..."`.

#### [MODIFY] [`sales_history_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/sales_history_screen.dart)
- **Renombrar** Tab `"Listas Escolares"` → `"Cotizaciones Vendidas"` (línea 202).

#### [MODIFY] [`history_dashboard_cards.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/history/history_dashboard_cards.dart)
- **Hacer las tarjetas contextuales:** Leer `provider.currentTab`.
  - Si `currentTab == "archivadas"`: Mostrar tarjetas con labels "Tickets Anulados", "Monto Anulado (S/)", "Monto Retenido (S/)" con colores rojos/grises para denotar la naturaleza del tab.
  - Si `currentTab != "archivadas"`: Mantener los labels actuales ("Ventas Realizadas", "Ingresos", "Por Cobrar").

---

### Fase 3: Refactorización del Motor de Reportes (PDF/Excel)

#### [MODIFY] [`history_export_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/history_export_service.dart)
- **Corregir L108 (PRODS. VENDIDOS):**
  - Actualmente usa `sales.fold(0, (sum, s) => sum + s.installments.length)`.
  - El modelo `SaleModel` no carga ítems internamente (solo se cargan en `getSaleDetail()`). Por tanto, la solución correcta es recibir un parámetro `int totalProductsSold` precalculado desde el Provider, usando la query SQL: `SELECT SUM(vi.cantidad) FROM venta_items vi JOIN ventas v ON vi.venta_id = v.id WHERE v.negocio_id = ? AND v.is_archived = ? AND ...`.
- **Corregir L126-128 (VENTAS TRANSF. y BILLETERA DIGITAL):**
  - Agregar al `SalesStatsModel` campos: `totalEfectivo`, `totalTransferencia`, `totalDigital` (Yape/Plin).
  - Calcularlos en `getStatsRaw()` del repository usando `SUM(CASE WHEN metodo_pago = 'efectivo' THEN monto_pagado ELSE 0 END)`, etc.
  - Pasar estos valores al PDF en vez de `0.0`.
- **Hacer el título del reporte sensible al contexto:**
  - Recibir un parámetro `String reportTitle` (ej: "REPORTE DE CAJA RÁPIDA" vs "REPORTE GLOBAL DE VENTAS").

#### [MODIFY] [`sale_repository.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/repositories/sale_repository.dart)
- **Expandir** `getStatsRaw()` para incluir:
  - `SUM(CASE WHEN metodo_pago = 'efectivo' THEN monto_pagado ELSE 0 END) AS total_efectivo`
  - `SUM(CASE WHEN metodo_pago = 'transferencia' THEN monto_pagado ELSE 0 END) AS total_transferencia`
  - `SUM(CASE WHEN metodo_pago IN ('yape', 'plin') THEN monto_pagado ELSE 0 END) AS total_digital`
- **Agregar** `getProductsSoldCount()` query para contar productos vendidos filtrados.

#### [MODIFY] [`crm_models.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/models/crm_models.dart)
- **Expandir** `SalesStatsModel` con los campos `totalEfectivo`, `totalTransferencia`, `totalDigital`, `totalProductosVendidos`.

#### [MODIFY] [`sale_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/sale_provider.dart)
- **Actualizar** `_loadDynamicStats()` y `silentRefresh()` para usar el stats expandido.

#### [MODIFY] [`sales_history_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/sales_history_screen.dart)
- **Actualizar** `_exportReport()` para pasar el título contextual al servicio de exportación basado en `_currentTabIndex`.

---

### Fase 4: Auditoría Global de Filtros Temporales

#### [MODIFY] [`sale_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/sale_provider.dart)
- **Verificar** que `setQuickFilter('seis_meses')` no genere meses negativos cuando `now.month <= 6` (ej: Enero - 6 = mes -5). Usar `DateTime(now.year, now.month - 6, now.day)` que Dart maneja correctamente, pero **validar** que no lance excepciones.
- **Verificar** que `setTab()` dispare `_loadDynamicStats()` correctamente después de cambiar de tab, garantizando que las estadísticas siempre reflejen la pestaña activa.

#### [VERIFY] Todos los archivos modificados
- Verificar imports, null safety, y que no se hayan roto referencias existentes.
- Ejecutar compilación `flutter build apk` para confirmar zero errors.

---

## Verification Plan

### Automated Tests
```bash
cd app_movil && flutter build apk --release
```

### Manual Verification
1. **Anular una venta:** Verificar que el stock del producto sube y que la venta aparece en la pestaña "Archivadas/Anuladas".
2. **Restaurar una venta:** Verificar que el stock baja de nuevo y que la venta regresa a su pestaña original.
3. **Restaurar sin stock:** Verificar que muestre un error claro si no hay stock suficiente.
4. **Buscar por #recibo:** Escribir "00065" en el buscador y verificar que encuentra la venta.
5. **Buscar por método:** Escribir "yape" y verificar que filtra correctamente.
6. **Exportar PDF desde tab "Caja Rápida":** Verificar que el título diga "REPORTE DE CAJA RÁPIDA" y que "PRODS. VENDIDOS" ya no muestre 0.
7. **Ver tarjetas en tab "Anuladas":** Verificar que muestren "Tickets Anulados" y "Monto Anulado" en vez de "Ingresos".
