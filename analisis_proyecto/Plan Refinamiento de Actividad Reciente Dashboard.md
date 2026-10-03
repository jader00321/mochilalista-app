# Plan: Refinamiento de "Actividad Reciente" (Dashboard)

Este plan detalla la solución al problema de congruencia de datos y las mejoras de UI solicitadas para la sección de "Actividad Reciente" en la pantalla de inicio (Home).

## Entendimiento del Problema
1. **Incongruencia de Datos:** Actualmente, el widget `RecentActivityList` lee directamente de la variable global `salesHistory` del `SaleProvider`. Dado que esta variable muta dependiendo de la pestaña activa en la que el usuario se encuentre dentro de la pantalla "Historial de Ventas" (ej: "Todas" vs "Anuladas"), la pantalla de inicio termina mostrando ventas anuladas si el usuario dejó activa esa pestaña.
2. **Mejora de UI (Falta de Detalles):** Las filas actuales muestran muy poca información (solo "Venta Directa/Cotización", el total y la hora). El usuario necesita identificar rápidamente de qué cliente proviene la venta (o "Sin cliente" si fue una venta rápida) y un identificador (ID de venta) para un reconocimiento veloz, además de mantener si es Venta Directa o por Cotización.

## Propuesta de Solución (Revisada y Optimizada)

Tras una revisión profunda de la arquitectura actual (`SaleProvider` y `SalesService`), propongo el siguiente plan de acción:

### Fase 1: Separación Estricta del Estado (State Management)
En lugar de reciclar la variable `salesHistory` (que está atada a la vista del historial), crearemos un estado independiente dentro de `SaleProvider` exclusivo para el Home.
- **Creación de Estado:** Añadir `List<SaleModel> _recentHomeSales = []` y su respectivo getter en `SaleProvider`.
- **Nuevo Método de Carga:** Crear `loadRecentHomeActivity()`. Este método consultará a `SalesService.getHistory` solicitando explícitamente solo las últimas 5 ventas y forzando `isArchived: false`, sin importar cómo estén los filtros del historial principal.
- **Sincronización Automática:** 
  - Llamaremos a `loadRecentHomeActivity()` dentro de `updateContext()` para que cargue al iniciar sesión.
  - Lo inyectaremos dentro de `processCheckout()` y `silentRefresh()` para asegurar que cuando el usuario haga una nueva venta, el Home se actualice instantáneamente sin recargar toda la app.

### Fase 2: Rediseño de la Interfaz (UI) en `RecentActivityList`
- **Cambio de Origen de Datos:** Cambiar la dependencia visual a `salesProv.recentHomeSales`.
- **Estructura de la Tarjeta (Row):**
  - **Título Principal:** Mostrará el nombre del cliente usando `sale.clientName ?? "Sin cliente"`. Si es "Sin cliente", se le dará un estilo en cursiva y color más tenue.
  - **Identificador y Tipo:** Debajo del nombre, mostraremos el ID de la venta y el tipo, por ejemplo: `Venta Directa (#1024)`.
  - **Fecha y Pago:** Mantendremos el método de pago y la fecha (ej: `Efectivo • 10:30 AM`).
  - **Monto Visual:** El total se mantendrá a la derecha en formato moneda, con el ícono de flecha indicando que se puede ver el detalle.

## Beneficios de este Plan
- **Independencia Total:** Lo que el usuario haga en la pantalla de "Historial de Ventas" (filtrar, buscar, ver anuladas) ya no afectará al Home.
- **Reconocimiento Rápido:** Con el nombre del cliente y el ID visibles, el usuario no tendrá que entrar al detalle de la venta para saber de qué trata.
- **Rendimiento:** Al cargar solo 5 ventas directamente desde SQLite para el Home, evitamos procesar listas largas innecesariamente.

## Open Questions
- El formato del identificador de venta que propongo es `(#ID)` (ej: Venta Directa (#24)). ¿Te parece bien este formato o prefieres otro?
- Revisa este plan refinado. Si estás de acuerdo, confírmame para proceder con la ejecución.
