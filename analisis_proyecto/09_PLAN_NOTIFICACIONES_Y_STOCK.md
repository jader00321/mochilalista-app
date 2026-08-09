# 📋 Plan de Trabajo: Mejora de Notificaciones y Sistema de Stock Inteligente

He analizado profundamente tu solicitud y el estado actual de la aplicación (`notifications_screen.dart`, `local_db.dart`, `sales_service.dart`, y `notification_provider.dart`). Tu idea de evitar la saturación de notificaciones de stock (spam) mediante una **"notificación viva" con seguimiento** es excelente y técnicamente muy viable.

A continuación, presento el plan detallado para llevar estas características al siguiente nivel.

---

## 🎯 FASE 1: Rediseño de la Ventana de Notificaciones

Actualmente la pantalla es una lista simple. Vamos a transformarla en un panel de control completo.

### 1.1 Estructura de Pestañas (Tabs)
Reemplazaremos los `ChoiceChip` superiores por un `TabBar` real con tres vistas deslizables:
- **Pendientes:** Alertas críticas que requieren acción (ej. Cuotas vencidas, Stock bajo).
- **Resueltas:** Alertas que ya fueron solucionadas por el sistema (ej. Cuotas pagadas, Stock repuesto).
- **Historial:** El registro absoluto de todas las notificaciones (pendientes y resueltas).

### 1.2 Sistema de Filtros Avanzado
Dentro de cada pestaña, añadiremos un botón de "Filtros" que desplegará:
- **Estado de Lectura:** Mostrar solo `Leídas` o `No Leídas`.
- **Selector de Tiempo Específico:** Filtros rápidos (Hoy, 7 días, Este Mes) y un **Selector de Fecha/Mes** (Date Picker) para buscar notificaciones de un periodo exacto.

### 1.3 Nuevo Sistema de Eliminación (Protección de Historial)
- **Eliminar Deslizamiento:** Quitaré el widget `Dismissible` que permitía borrar arrastrando.
- **Borrado Protegido:** Solo se permitirá borrar desde la pestaña **Historial**.
- **Selección Múltiple:** Implementaré un modo de selección (al mantener presionada una notificación, aparecerán *checkboxes*). Esto habilitará un botón flotante para "Eliminar X seleccionadas".
- **Confirmación:** Toda eliminación lanzará un `AlertDialog` preguntando: *"¿Estás seguro de eliminar X notificaciones permanentemente?"*.

---

## 🧠 FASE 2: Sistema Inteligente de Alertas de Stock

Tu preocupación sobre el "spam" de notificaciones cada vez que se vende un producto es muy válida. Si un producto baja de 5 a 4, de 4 a 3, y de 3 a 2 unidades en ventas distintas, no deberías recibir 3 notificaciones diferentes.

### 2.1 La "Notificación Viva" (Upsert Inteligente)
En lugar de crear un nuevo registro en la base de datos por cada venta, implementaremos una lógica de rastreo por producto:
1. Cuando ocurre una venta que reduce el stock por debajo del límite (`stock_alerta`), el sistema buscará si ya existe una notificación de stock para ese producto.
2. **Si NO existe:** Crea una notificación nueva (Ej: *"Stock Bajo: Cuaderno Loro"*).
3. **Si SÍ existe:** **NO crea otra**. Simplemente **actualiza** la existente:
   - Modifica el texto: *"El stock ha bajado a 2 unidades."*
   - Cambia su estado a `No Leída` (para que te des cuenta de la actualización).
   - Actualiza la `fecha_creacion` al momento exacto de la última venta, empujándola a la cima de tus notificaciones "Pendientes".

> [!TIP]
> **Eficiencia:** Este método consume 0 recursos extra de almacenamiento, ya que solo recicla 1 sola fila en la base de datos por cada producto.

### 2.2 Seguimiento de Historial sin Sobrecargar la DB
Me pediste que la notificación tenga un seguimiento claro de *"las veces que hubo falta, cuándo se redujo y cuándo se repuso"* sin saturar los recursos del celular.

**Solución Óptima:** No duplicaremos datos guardando un historial gigante de texto dentro de la notificación (eso saturaría la base de datos). Como la app ya registra cada venta (`venta_items`) y cada compra (`facturas_carga`), **usaremos esos datos reales**.

- **El Cambio:** Al tocar la notificación de stock, ya no solo te llevará a la pantalla de "Editar Producto". En su lugar, abriremos un modal elegante llamado **"Análisis de Stock"** para ese producto.
- **¿Qué mostrará?**
  1. El stock actual en grande.
  2. Una pequeña **Línea de Tiempo (Kardex simplificado)** generada en tiempo real consultando las últimas ventas y compras de ese producto exacto.
  3. Así podrás ver: *"Hoy 10:00am - Venta de 2 unidades"*, *"Ayer - Ingreso de 20 unidades"*.

### 2.3 Auto-Resolución Mejorada
Actualmente, el sistema considera "Resuelta" una alerta de stock solo si el stock es mayor a `0`. Lo corregiremos para que pase a "Resuelta" **solo cuando el stock supere el límite de alerta (`stock_alerta`)**. Si lo configuras en 5, y el stock sube a 10 mediante un abastecimiento, la notificación se irá automáticamente a la pestaña de "Resueltas".

---

## ❓ Preguntas para ti (Opcional)

1. ¿Te parece bien usar la línea de tiempo (Kardex simplificado) consultando las ventas reales cuando tocas la notificación, o prefieres que la información esté escrita textualmente dentro de la descripción de la notificación en sí? *(Recomiendo fuertemente el Kardex simplificado por rendimiento).*
2. Para la selección múltiple en el Historial, ¿deseas que también haya un botón de "Seleccionar Todo" para vaciar el historial completo rápido?

---

**Si estás de acuerdo con este plan, haz clic en "Proceed" (Proceder) o indícame si deseas ajustar algún detalle.**



📋 Plan de Trabajo Reevaluado: Notificaciones y Stock Inteligente
He analizado tu mensaje original nuevamente con mucho detenimiento. Tienes toda la razón, había puntos técnicos y lógicos cruciales que merecían una evaluación mucho más profunda, especialmente en por qué no se resuelven las alertas de stock actualmente y cómo implementar el historial de la notificación sin consumir memoria.

Aquí tienes el plan de trabajo corregido, detallado y listo para ejecutar.

🎯 FASE 1: Rediseño Visual y Arquitectura de la Ventana
1.1 Nueva Estructura de Pestañas (Tabs)
Se eliminarán las etiquetas superiores actuales (ChoiceChip). En su lugar, usaremos un DefaultTabController con 3 pestañas principales (Tabs):

Pendientes: Alertas activas que requieren tu atención.
Resueltas: Alertas que ya fueron solucionadas.
Historial: El registro completo (mezcla de pendientes y resueltas).
1.2 Sistema de Filtros Independiente
Debajo de las pestañas, implementaremos un botón o fila desplegable de filtros combinables:

Estado: Leídas / No Leídas.
Filtro de Tiempo Preciso:
Rápidos: 1 Día, 1 Semana, 1 Mes.
Específico: Un botón de calendario (Date/Month Picker) para seleccionar un mes y año exacto (Ej: "Marzo 2026").
1.3 Nuevo Sistema de Eliminación Seguro
Bloqueo de Swipe: Eliminaré completamente la opción de borrar deslizando (Dismissible) para evitar borrados accidentales.
Restricción por Pestaña: El botón de eliminar solo existirá en la pestaña "Historial".
Selección Múltiple y Confirmación:
Al mantener presionada una notificación, entrarás en "Modo Selección" (aparecerán checkboxes).
Podrás seleccionar varias a la vez.
Al presionar "Eliminar", siempre saltará una ventana emergente (Dialog) preguntando: "¿Estás seguro de eliminar permanentemente X notificaciones?".
1.4 Llevando el Diseño al "Siguiente Nivel"
Micro-animaciones: Añadiremos animaciones de entrada en cascada (Staggered Animations) al cargar la lista.
Diseño Premium: Las tarjetas tendrán un ligero efecto "Glassmorphism" si estás en modo oscuro, y sombras más difuminadas en modo claro.
Indicadores de Estado: Reemplazaremos el simple punto de "No leída" por un borde sutil brillante que invite a interactuar.
🧠 FASE 2: Corrección y Evolución de las Alertas de Stock
Aquí está el análisis profundo del problema actual y cómo implementaremos tu idea magistralmente.

2.1 ¿Por qué NO se está resolviendo la alerta actualmente? (Errores detectados)
He revisado el código y encontré dos errores cruciales en el sistema actual que están causando tu frustración:

Lógica Matemática Errónea: El sistema actual considera que una alerta está "resuelta" si el stock del producto es mayor a 0 (stock_actual > 0). ¡Esto es incorrecto! Si tu límite de alerta es 5, y tú reabasteces de 0 a 3 unidades, el sistema lo marca como resuelto (porque 3 > 0), pero debería seguir en alerta. Lo cambiaré para que compare contra el stock_alerta real del producto (stock_actual > stock_alerta).
Falta de Actualización al Volver: Cuando tocas la notificación, te lleva a la pantalla para editar y reabastecer el producto. Pero al regresar a las notificaciones, la pantalla no se refresca automáticamente. Añadiré un comando que espere a que regreses de esa pantalla y fuerce una recarga inmediata de la base de datos (await Navigator.push(...)).
2.2 La "Notificación Viva" y su Historial (Consumo Ineficiente Solucionado)
Tu idea es brillante: "No quiero una notificación nueva por cada venta, quiero UNA notificación por producto que se actualice y tenga su historial".

El problema técnico: Si guardamos un texto enorme con el historial dentro de la notificación, la base de datos se saturará rápido y el celular se volverá lento. La Solución Elegante:

Tendrás UNA SOLA NOTIFICACIÓN en tu base de datos por producto (Ej: "Alerta Stock: Cuaderno").
Cuando vendas un cuaderno y el stock baje, el sistema no creará otra notificación. Buscará esa única notificación, actualizará su título ("Stock Crítico: 2 unidades"), la marcará como "No leída" y cambiará su fecha a "Ahora" para que suba al primer lugar de Pendientes.
El Historial (El truco de rendimiento): Cuando toques "Ver Detalles" en esa notificación, se abrirá un panel que mostrará un "Historial de Movimientos de este Producto". Este historial NO estará guardado en la notificación. En ese preciso milisegundo, la app buscará las últimas ventas (venta_items) y compras (facturas_carga) de ese producto y armará una línea de tiempo visual (Ej: "Ayer - Vendiste 3", "Hoy - Vendiste 1").
Beneficio: Tienes todo el contexto y seguimiento sin gastar ni un byte extra de memoria en notificaciones duplicadas.
2.3 Flujo de Auto-Resolución Automática
Una vez que vayas a reabastecer el producto y su stock supere el límite de alerta, esta "Notificación Viva" pasará automáticamente a la pestaña "Resueltas" y se quedará ahí como parte de tu historial, hasta que el stock vuelva a caer en el futuro (momento en el cual regresará a "Pendientes").

Si este plan ahora sí cubre todos los puntos cruciales y lógicos que esperabas, por favor presiona "Proceed" para que empiece a escribir el código.