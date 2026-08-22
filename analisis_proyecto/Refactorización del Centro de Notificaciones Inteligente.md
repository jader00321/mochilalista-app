# Refactorización del Centro de Notificaciones Inteligente

Transformar el Centro de Notificaciones de una lista de mensajes genérica a un sistema inteligente, semántico, auto-resolutivo y con navegación contextual profunda.

---

## Diagnóstico de la Arquitectura Actual

### Flujo de datos actual
```mermaid
graph LR
  A["SalesService<br>(Stock Bajo)"] -->|INSERT directo en BD| D["notificaciones (SQLite)"]
  B["ClientService<br>(Cuota Pagada)"] -->|INSERT directo en BD| D
  C["ChangePinModal<br>(Info: PIN)"] -->|showAndSaveNotification| D
  D -->|fetchNotifications()| E["NotificationProvider"]
  E -->|isResolved calculado en RAM| F["NotificationsScreen"]
  F -->|_handleDeepLink()| G["Modals contextuales"]
```

### Análisis profundo

| Componente | Estado | Observaciones |
|---|---|---|
| [`notification_model.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/models/notification_model.dart) | ⚠️ Incompleto | `isResolved` es calculado en RAM (no persistido). No tiene campo `isActionable` ni `type` estrictamente categorizado. |
| [`notification_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/providers/notification_provider.dart) | ✅ Buena base | Ya tiene lógica de auto-resolución por stock y cuotas en `fetchNotifications()` (líneas 44-71). Falta **escuchar cambios de inventario en tiempo real**. |
| [`notifications_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/profile/screens/notifications_screen.dart) | ⚠️ Bug semántico | Tab "Pendientes" filtra por `!isResolved` (línea 304), lo cual incluye notificaciones informativas ("Seguridad Actualizada", "Cuota Pagada") que nunca serán resueltas porque no son accionables. |
| [`notification_item_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/profile/widgets/notifications/notification_item_card.dart) | ⚠️ Overflow | Título con `maxLines: 1` (línea 103) causa truncamiento como se ve en las capturas ("Stock Bajo: Goma..."). Mensaje con `maxLines: 2` (línea 117) también insuficiente. |
| Deep Linking | ✅ Buena base | `_handleDeepLink` (línea 91) ya navega contextualmente por tipo de objeto. Stock abre un modal Kardex, cuotas abren modal de deuda, ventas van a detalle. |

### Bugs confirmados con evidencia visual (capturas)

| # | Bug | Evidencia |
|---|---|---|
| 1 | **"Seguridad Actualizada" y "Cuota Pagada" en tab Pendientes** | Captura 2: Notificaciones de tipo `info` y `exito` aparecen bajo "Pendientes" porque su `isResolved` es `false` al no tener lógica de resolución. |
| 2 | **Título truncado "Stock Bajo: Goma..."** | Captura 1: `maxLines: 1` en el título no permite mostrar nombres largos de producto. |
| 3 | **Título del AppBar cortado "Notifica..."** | Todas las capturas: El botón "Marcar todo leídas" empuja el título fuera de pantalla. |
| 4 | **Texto de mensaje truncado "...cayera por deb..."** | Capturas 1 y 5: `maxLines: 2` insuficiente para mensajes descriptivos. |

---

## Propuesta de Cambios

### Fase 1: Categorización Semántica del Modelo y Pestañas

#### [MODIFY] [`notification_model.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/models/notification_model.dart)

**Solución:** Agregar un getter `isActionable` que determine automáticamente, basándose en los campos `type` y `objetoRelacionadoTipo` ya existentes, si la notificación es accionable o puramente informativa.

```dart
/// Una notificación es accionable si es una ALERTA que requiere acción del usuario.
/// Las notificaciones informativas (exito, info) nunca son accionables.
bool get isActionable {
  if (type == 'alerta') return true;
  return false;
}
```

> [!IMPORTANT]
> No se necesita alterar la tabla SQLite ni hacer migraciones. El campo se calcula a partir de `type` que ya existe y ya está correctamente asignado: `'alerta'` para stock/cuotas, `'exito'` para cuotas pagadas, `'info'` para PIN y similares.

#### [MODIFY] [`notifications_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/profile/screens/notifications_screen.dart) (línea 304)

**Solución:** Cambiar la lógica de filtrado de pestañas:

- **Pendientes:** `isActionable && !isResolved` — Solo alertas que requieren intervención.
- **Resueltas:** `isActionable && isResolved` — Alertas que el sistema (o el usuario) ya resolvió.
- **Historial:** Todas las notificaciones, sin filtro (como está ahora).

Resultado: "Seguridad Actualizada" y "Cuota Pagada" solo aparecen en el tab **Historial**, dejando el tab **Pendientes** limpio y exclusivo para alertas reales.

---

### Fase 2: Motor de Auto-Resolución (Smart Sync en Tiempo Real)

#### [MODIFY] [`notification_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/providers/notification_provider.dart)

**El provider ya tiene la lógica de auto-resolución** en `fetchNotifications()` (líneas 44-71), verificando si el stock supera el ROP o si la cuota ya fue pagada. El problema es que **solo se ejecuta al entrar a la pantalla de notificaciones** o al iniciar la app.

**Solución:**  
1. Hacer que `fetchNotifications()` sea invocado automáticamente desde los puntos clave del sistema:
   - Después de que `InventoryProvider` procese un reabastecimiento (`loadProducts()` o `saveProduct()`).
   - Después de que `ClientService` procese un pago de cuota.
2. Para no crear acoplamientos entre providers, el mecanismo más limpio es: En la `notifications_screen.dart`, al hacer `initState`, escuchar cambios del `InventoryProvider` con un listener que llame a `fetchNotifications()`. Esto se complementa con lo que ya existe pero agrega reactividad en tiempo real mientras el usuario está en la pantalla de notificaciones.
3. Además, en el **Home Screen** donde ya se invoca `updateContext()`, agregar un refresh periódico ligero (al regresar de cualquier pantalla de edición de productos o pagos).

> [!NOTE]
> La lógica de resolución automática ya funciona bien cuando se ejecuta. El cambio aquí es puramente de **cuándo** se ejecuta, no de **cómo**.

---

### Fase 3: Rediseño Responsivo de UI

#### [MODIFY] [`notification_item_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/profile/widgets/notifications/notification_item_card.dart)

**Cambios en la tarjeta:**
1. **Título:** Cambiar `maxLines: 1` → `maxLines: 2` (línea 103). Esto permite que "Stock Bajo: Goma de Borrar Faber Castell" se muestre completo en dos líneas antes de truncar.
2. **Mensaje:** Cambiar `maxLines: 2` → `maxLines: 4` (línea 117). Esto elimina el truncamiento agresivo del texto "Una venta reciente provocó que el stock cayera por debajo del...".
3. **Texto "Toca para ver detalles":** Hacerlo más contextual e inteligente según el tipo de objeto relacionado:
   - `producto` → "📦 Toca para ver análisis de stock"
   - `cuota` → "💰 Toca para ver detalles de la deuda"
   - `venta` → "🧾 Toca para ver la venta"
   - Default → "🔍 Toca para más información"

#### [MODIFY] [`notifications_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/profile/screens/notifications_screen.dart) (AppBar)

**Solución para el título cortado:**
1. El problema está en que el `title` ("Notificaciones") y el `actions` (botón "Marcar todo leídas") compiten por el espacio en el AppBar.
2. **Solución:** Usar `titleSpacing: 0` y ajustar el `title` para que se adapte al espacio disponible, o mover el botón "Marcar todo leídas" fuera del AppBar y colocarlo en el `NotificationFilterBar` o como un `Chip` flotante. La solución más elegante es hacer el título más corto y responsivo con `FittedBox` y mover la acción de marcar todas como leídas a un menú desplegable (`PopupMenuButton`) en las `actions` del AppBar.

---

### Fase 4: Deep Linking Inteligente Mejorado

#### [MODIFY] [`notification_item_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/profile/widgets/notifications/notification_item_card.dart)

**Cambio:** En la tarjeta, para las notificaciones **resueltas** (tab Resueltas), cambiar el texto de acción:
- De: "Toca para ver detalles"
- A: "✅ Resuelta automáticamente" (sin ícono de touch, indicando que no necesita acción).

#### [MODIFY] [`notifications_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/profile/screens/notifications_screen.dart)

**Mejora:** El deep linking actual ya funciona bien. La mejora es:
1. Después de navegar a un producto y volver (con `await Navigator.push`), el sistema ya llama a `fetchNotifications()` para auto-resolver (líneas 253-257). Esto ya está implementado.
2. Agregar el mismo patrón (fetch al volver) para el deep link de cuotas (`_showCuotaVencidaModal`), para que si el usuario paga la cuota desde el modal del cliente, al cerrar la pantalla la alerta se mueva automáticamente a "Resueltas".

---

## Verificación

### Pruebas Manuales
1. **Test de Categorización:** Cambiar el PIN → verificar que "Seguridad Actualizada" aparece solo en "Historial", no en "Pendientes".
2. **Test de Auto-Resolución:** Generar una alerta de stock bajo → reabastecer el producto desde el inventario → volver a la pantalla de notificaciones → verificar que la alerta pasó automáticamente a "Resueltas".
3. **Test de Responsividad:** Verificar que los títulos largos ("Stock Bajo: Goma de Borrar Faber Castell XL") se muestran en 2 líneas, sin truncamiento agresivo.
4. **Test de Deep Linking:** Tocar una alerta de "Cuota Vencida" → verificar que abre el modal de deuda del cliente correcto con opción de contactar por WhatsApp.

### Compilación
- `flutter build apk` para confirmar ausencia de errores.
