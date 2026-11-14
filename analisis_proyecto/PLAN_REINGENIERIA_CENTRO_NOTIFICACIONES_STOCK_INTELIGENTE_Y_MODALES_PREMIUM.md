# PLAN DE TRABAJO MAESTRO: REINGENIERÍA DEL CENTRO DE NOTIFICACIONES, ALERTAS DE STOCK INTELIGENTE Y MODALES PREMIUM (MOBILE AWARDS QUALITY)

**Documento:** `analisis_proyecto/PLAN_REINGENIERIA_CENTRO_NOTIFICACIONES_STOCK_INTELIGENTE_Y_MODALES_PREMIUM.md`  
**Estado:** Propuesta de Planificación Técnica Exhaustiva — Pendiente de Aprobación del Usuario  
**Metodología:** Loop Autónomo + Árbitro Interno Adversarial (Blindaje Quirúrgico sin Regresiones)  
**Objetivo Primario:** Transformar integralmente el **Centro de Notificaciones** (`notifications_screen.dart`), su motor de generación de alertas de stock y cobranzas (`notification_provider.dart`, `sales_service.dart`), su sistema de retroalimentación táctil flotante y todo su ecosistema de modales asociados (`Análisis de Stock`, `Opciones para esta notificación`, `Notificaciones Archivadas`, `Ítems en No Deseadas` y `Configuración de Alertas`), erradicando falsas alarmas, spam recurrente al vender, mensajes (`SnackBar`) pegados en Android, colisiones con la barra de navegación del sistema (`SafeArea`) y jerga técnica interna expuesta.

---

## 1. RESUMEN EJECUTIVO Y ANÁLISIS DE IMPACTO

El Centro de Notificaciones de la aplicación es el centro de control operativo del comerciante: le informa de cuotas por cobrar, alertas de inventario crítico y acuerdos de cotización pendientes. Sin embargo, tras pruebas exhaustivas en condiciones reales y el análisis de las **8 capturas adjuntas**, se han evidenciado deficiencias críticas que degradan la confianza del usuario y la experiencia visual:

1. **Falsas Alarmas en Registro de Inventario:** Cuando el comerciante crea conscientemente un producto nuevo con poco inventario inicial (ej. 3 und. con umbral 5), el sistema genera de inmediato una alerta alarmista afirmando que el stock *"cayó a 3 und."*, a pesar de que en el historial no existe ningún movimiento de venta o salida.
2. **Spam Consecutivo en Ventas de Stock Bajo:** Al vender sucesivamente unidades de un producto ya alertado (`5 -> 4 -> 3 -> 2`), el sistema reactiva, desarchiva o satura la lista con avisos repetitivos, ignorando si el comerciante ya había archivado o resuelto la alerta preventiva.
3. **Modal `Análisis de Stock` Rudimentario y Pasivo:** El botón de la tarjeta utiliza la etiqueta técnica contable `[Kardex]` y abre un modal casi vacío que muestra `"No hay movimientos recientes"` y obliga a ir a la pantalla completa de edición de producto para cualquier corrección menor.
4. **Barras Negras (`SnackBar`) Pegadas Indefinidamente:** Al archivar o silenciar, Flutter en Android mantiene el `SnackBar` con acción `[Deshacer]` congelado sobre los botones del sistema `< O |||`, sin auto-ocultarse.
5. **Colisión contra la Barra de Navegación de Android (`SafeArea`):** En modales como `Opciones para esta notificación` y `Configuración de Alertas`, los botones inferiores quedan incrustados o cortados por la barra de navegación del sistema.
6. **Textos Rotos y Exposición de Jerga Técnica:** Quiebres torpes de texto en modales (`"Productos Agotados (0\nund.)"`, `"Notificaciones\nArchivadas"`, `"Smart Grouping por\nCliente"`), buscadores que mencionan `"mute key"` y chips que exponen códigos como `Alertas relacionadas bloqueadas (cuota_3)` con duplicados innecesarios y emojis desfasados (`💰`).

---

## 2. DIAGNÓSTICO TÉCNICO EN PROFUNDIDAD (EVIDENCIA EN CÓDIGO FUENTE)

### 2.1. Diagnóstico de Alertas de Stock y Falsas Alarmas (Capturas 3 y 4)
* **Archivos afectados:**
  * `lib/core/providers/notification_provider.dart` (Líneas 540–688)
  * `lib/features/smart_quotation/services/sales_service.dart` (Líneas 432–525)
  * `lib/features/profile/screens/notifications_screen.dart` (Líneas 407–537)
* **Causa Raíz del Problema 1 (Falsa alarma al registrar producto):**
  * En `NotificationProvider.generateAutoNotifications()`, la consulta SQL busca cualquier presentación donde `stock_actual <= stock_alerta`.
  * Aunque existe un filtro rudimentario de gracia (`graceProductIds`) basado en `productos.fecha_creacion < 7 días`, si el producto se importó, se creó desde otra pantalla sin `fecha_creacion` estándar o si el usuario corre la sincronización, el sistema genera la alerta:
    ```dart
    'El stock de "$prodNombre" cayó a ${stockActual.toInt()} und. (umbral: ${stockAlerta.toInt()} und.). Reabastece pronto.'
    ```
  * En ningún momento se valida si en la tabla canónica `stock_ledger` ha ocurrido al menos un movimiento de salida o venta (`tipo_transaccion = 'VENTA'`). Al crearse el producto solo tiene un asiento de `'INVENTARIO_INICIAL'`, por lo que el stock no *"cayó"*, sino que nació con esa cantidad.
* **Causa Raíz del Problema 2 (Spam en cascada 5 -> 4 -> 3 -> 2):**
  * En `sales_service.dart` (Líneas 487–503), cada vez que se vende una unidad y el stock resultante es `<= stockAlerta`, el código ejecuta:
    ```dart
    await txn.update('notificaciones', {
      'titulo': title,
      'mensaje': content,
      'leida': 0,
      'is_resolved': 0,
      'fecha_resolucion': null,
      ...
    }, where: 'id = ?', whereArgs: [existNotif.first['id']]);
    ```
  * Esto provoca que si el comerciante ya había resuelto (`is_resolved = 1`) o archivado (`is_archived = 1`) la notificación de stock bajo a las 5 und., cada venta sucesiva a 4, 3 o 2 und. **resucita la alerta en `Pendientes`**, marca `leida = 0` y dispara spam visual e insistente.
* **Causa Raíz del Problema 3 (Modal `Análisis de Stock` vacío y botón `[Kardex]`):**
  * En `notification_item_card.dart` (Línea 494) el botón está hardcodeado con la etiqueta `"Kardex"`.
  * En `notifications_screen.dart` (Líneas 415–430), `_showStockAnalysisModal` consulta `venta_items` y `presentaciones_producto JOIN facturas_carga fc`.
  * Dado que la mayoría de productos registrados manualmente o mediante catálogo no están asociados a `facturas_carga` de escáner y no tienen ventas todavía, ambas listas retornan vacías. La función alimenta un modal primitivo que solo muestra un contenedor azul con el número y el texto `"No hay movimientos recientes"`, sin opciones de compra sugerida, costo, proveedor ni abastecimiento rápido in-modal.

---

### 2.2. Diagnóstico de SnackBar Pegados en Android (Captura 1)
* **Archivos afectados:**
  * `lib/features/profile/screens/notifications_screen.dart` (Líneas 1767–1835)
  * `lib/features/profile/widgets/notifications/archived_notifications_modal.dart` (Líneas 56, 86, 116)
  * `lib/features/profile/widgets/notifications/silenced_notifications_modal.dart` (Líneas 56, 86, 116)
* **Causa Raíz:**
  * Se invoca:
    ```dart
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Notificación archivada"),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(label: "Deshacer", ...),
      ),
    );
    ```
  * En el framework de Flutter en Android, cuando un `SnackBar` contiene un `SnackBarAction` y el dispositivo tiene habilitados servicios del sistema, gestos o accesibilidad, el temporizador nativo del SnackBar se congela o se suprime, quedando la barra negra anclada permanentemente en la pantalla.
  * Además, al no gestionar elevación sobre `Overlay`, se dibuja justo sobre el margen de la barra de navegación del sistema operativo Android (`< O |||`).

---

### 2.3. Diagnóstico de Modales de Opciones, Archivadas y No Deseadas (Capturas 2, 5 y 6)
* **Archivos afectados:**
  * `lib/features/profile/screens/notifications_screen.dart` (Líneas 1840–1973)
  * `lib/features/profile/widgets/notifications/archived_notifications_modal.dart` (Líneas 250–320)
  * `lib/features/profile/widgets/notifications/silenced_notifications_modal.dart` (Líneas 320–515)
* **Causa Raíz en `Opciones para esta notificación` (Captura 2):**
  * Título muestra emojis crudos (`⚠️ Stock Bajo...`) tomados del string `notif.title`.
  * El pie del modal (`SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(vertical: 16), ...))`) carece de margen defensivo contra la barra de navegación física de Android.
  * Opciones planas (`ListTile`) sin tarjetas enriquecidas, sin acciones contextuales (ej. reabastecer o ajustar umbral si es stock, WhatsApp si es cuota) ni capacidad de posponer temporalmente (`Snooze`).
* **Causa Raíz en `Notificaciones Archivadas` (Captura 5):**
  * El título en `Column` junto al icono y a los botones superiores `more_vert` y `close` colapsa el ancho disponible, provocando que la palabra `"Archivadas"` se parta a una segunda línea antiestética.
* **Causa Raíz en `Ítems en No Deseadas` (Captura 6):**
  * Buscador expone la frase técnica `"mute key"`.
  * El chip de estado expone el identificador crudo `(cuota_3)` en vez de traducir a qué entidad pertenece.
  * La lista muestra duplicados de la misma entidad (ej. dos cuotas vencidas históricas de Freddy silenciadas por separado con la misma clave `cuota_3`).
  * Emoticonos visuales residuales (`💰`) en títulos antiguos.

---

### 2.4. Diagnóstico de `Configuración de Alertas` y Modales de Tarjeta (Capturas 7 y 8)
* **Archivos afectados:**
  * `lib/features/profile/widgets/notifications/notification_settings_modal.dart` (Líneas 230–543)
  * `lib/core/models/notification_preferences_model.dart`
  * `lib/features/profile/screens/notifications_screen.dart` (Líneas 539–715)
* **Causa Raíz:**
  * `SwitchListTile.adaptive` con icono secundario a la izquierda y switch a la derecha constriñe el texto del título a un ancho insuficiente, quebrando cadenas como `"Productos Agotados (0\nund.)"` y `"Smart Grouping por\nCliente"`.
  * Ausencia de configuraciones para controlar el tiempo de gracia de stock nuevo y la consolidación anti-spam de ventas continuas.
  * Al final del `ListView`, los controles de navegación por swipe quedan parcialmente ocultos bajo la barra física de Android (Captura 8), evidenciando la falta de un pie de página fijo (`Docked Footer`) con padding defensivo de `SafeArea`.

---

## 3. PLAN DE REINGENIERÍA ESTRUCTURADO EN 5 FASES MAESTRAS

```
+----------------------------------------------------------------------------------------------------+
|               ARQUITECTURA DE REINGENIERÍA DEL CENTRO DE NOTIFICACIONES (V2.5)                     |
+----------------------------------------------------------------------------------------------------+
|                                                                                                    |
|  FASE 1: MOTOR DE STOCK INTELIGENTE Y MODAL DE ANÁLISIS EJECUTIVO                                  |
|  • Cero falsas alarmas al crear producto: Regla de gracia por stock_ledger (sin ventas = sin spam) |
|  • Anti-spam en ventas (5->4->3->2): Actualización in-place y respeto a archivadas / resueltas     |
|  • Renombrar [Kardex] -> [Análisis] / [Ver Stock]                                                  |
|  • Rediseño en 3 zonas de Análisis de Stock: Diagnóstico + Abastecer In-Modal + Umbral Rápido      |
|                                                                                                    |
|  FASE 2: TOAST FLOTANTE ANIMADO PREMIUM (OVERLAY ENTRY)                                            |
|  • Erradicación total de ScaffoldMessenger.of(context).showSnackBar en todo el módulo             |
|  • NotificationToastFeedback con AnimatedSlide + AnimatedOpacity + temporizador estricto de 3.0s   |
|  • Botón [Deshacer] integrado de micro-latencia con micro-háptica y auto-destrucción garantizada   |
|                                                                                                    |
|  FASE 3: REDISEÑO DE MODALES DE OPCIONES, ARCHIVADAS Y NO DESEADAS                                 |
|  • Borde inferior blindado: viewPadding.bottom + 16dp universal                                    |
|  • Opciones para esta notificación: Tarjetas modulares, acciones directas contextuales y Snooze   |
|  • Archivadas y No Deseadas: Títulos fluidos, deduplicación por mute_key y lenguaje humano         |
|  • Barra de acciones fijas inferiores: [Restaurar todo] / [Limpiar bandeja]                        |
|                                                                                                    |
|  FASE 4: PERFECCIONAMIENTO DE CONFIGURACIÓN Y MODALES DE ACCIÓN EN TARJETAS                        |
|  • Configuración de Alertas: Cero títulos partidos, selector de gracia y anti-spam de stock       |
|  • Docked Footer fijo con [Restaurar recomendados] y [Listo / Guardar] respetando SafeArea         |
|  • Auditoría integral de modales de cobro, mora, WhatsApp y cotización sin regresiones             |
|                                                                                                    |
|  FASE 5: RESPONSIVIDAD 320/360DP, MODO CLARO/OSCURO Y VALIDACIÓN ADVERSARIAL                       |
|  • Filtros horizontales fluidos con indicador de scroll táctil                                     |
|  • 0px Overflow garantizado en pantallas compactas                                                 |
|  • Cero .withOpacity (adopción pura de .withValues(alpha: ...)) y cero emojis en widgets UI        |
|  • 0 warnings en flutter analyze + ejecución de la Matriz del Árbitro Adversarial                  |
+----------------------------------------------------------------------------------------------------+
```

---

### FASE 1: Inteligencia Real en Alertas de Stock + Rediseño del Modal `Análisis de Stock` (Capturas 3 y 4)

#### 1.1. Especificación Lógica Anti-Falsas Alarmas en Creación de Producto
* **Regla de Oro:** *Un producto o presentación recién registrado con stock bajo NO debe ser reportado como una caída de stock.*
* **Implementación en SQLite & Providers:**
  1. Al evaluar si un producto con déficit (`stock_actual <= stock_alerta`) debe disparar una notificación de `Stock Bajo`:
     * Consultar en `stock_ledger` si existen transacciones de salida:
       ```sql
       SELECT COUNT(*) as ventas_count 
       FROM stock_ledger sl
       INNER JOIN presentaciones_producto pp ON sl.presentation_id = pp.id
       WHERE pp.producto_id = ? AND sl.tipo_transaccion IN ('VENTA', 'SALIDA_MANUAL')
       ```
     * Si `ventas_count == 0`:
       - Verificar el tiempo de permanencia transcurrido desde `productos.fecha_creacion`.
       - Si han transcurrido menos de `diasGraciaStockBajo` (configurable en preferencias: `0 = Solo en primera venta`, `3 días`, `7 días`; por defecto `3 días`), **NO SE DISPARA ALERTA PREVENTIVA**.
  2. **Excepción Crítica:** Si el producto tiene stock `0 und.` (`¡Producto Agotado!`), esta regla de gracia preventiva no aplica: el producto agotado siempre emitirá alerta crítica inmediata porque imposibilita la venta.

#### 1.2. Especificación Lógica Anti-Spam en Ventas Consecutivas (`5 -> 4 -> 3 -> 2`)
* **Implementación en `sales_service.dart` y `notification_provider.dart`:**
  1. **Actualización Silenciosa In-Place:**
     * Cuando se vende una unidad y ya existe una notificación activa (`is_resolved == 0`, `is_archived == 0`, `is_silenced == 0`) para ese producto:
       - Actualizar in-place el texto y `metadata_json` (`stock_actual: nuevoStock`).
       - Mantener el estado `leida` existente (no forzar `leida = 0` si el comerciante ya había visto la alerta previa).
  2. **Respeto Estricto al Descarte / Archivado / Resuelto (Escalamiento Inteligente):**
     * Si la notificación existente está en `is_archived == 1` o `is_resolved == 1`:
       - Al bajar de 5 a 4, 3, 2 o 1 und., el sistema **NO reactiva** la notificación (`is_resolved` permanece `1` y `is_archived` permanece `1`). No se crea ninguna notificación duplicada.
       - **Escalamiento Único a Agotado:** Si el stock llega a `0 und.`, el sistema archiva/resuelve la alerta preventiva previa y genera/actualiza la alerta crítica independiente: `🚨 ¡Producto Agotado! (0 und.)`.
       - **Reabastecimiento:** Si el producto recibe stock que lo sitúa por encima del umbral (`> stock_alerta`), la notificación se marca automáticamente como resuelta. Si posteriormente vuelve a venderse y cruza el umbral hacia abajo, se generará una nueva alerta legítima.

#### 1.3. Rediseño Ejecutivo del Modal `Análisis de Stock`
* **Cambio de Botón en Tarjeta:** Cambiar etiqueta `[Kardex]` por **`[Análisis]`** (o `[Ver Stock]`) con icono `Icons.insights_rounded`.
* **Estructura en 3 Zonas del Modal `StockAnalysisModal`:**
  1. **Zona 1: Panel Diagnóstico Visual:**
     * Cabecera con nombre del producto, marca, categoría y SKU.
     * Barra horizontal de salud de inventario con medidor visual de porcentaje respecto al umbral óptimo (Verde > Umbral, Ámbar = Umbral, Rojo = Agotado).
     * Tarjeta métrica comparativa: `Stock Actual` vs. `Umbral Mínimo`.
     * Fila ejecutiva de datos comerciales: `Costo Unitario`, `Precio de Venta Sugerido`, `Margen de Ganancia %` y `Proveedor Habitual`.
     * Si maneja presentaciones múltiples o stock compartido, selector de variantes con desglose individual.
  2. **Zona 2: Módulo de Abastecimiento Rápido In-Modal (`+ Sumar Stock Aquí`):**
     * Botonera de chips táctiles rápidos: `[+5]`, `[+10]`, `[+12 (Docena)]`, `[+24 (Fardo)]` y campo de entrada numérica directa.
     * Al confirmar, se ejecuta una transacción atómica directa a SQLite en `0ms`:
       - Incrementa `stock_actual` en `presentaciones_producto` (o `stock_compartido` en `productos`).
       - Inserta el asiento en `stock_ledger` con `tipo_transaccion: 'INGRESO'` y `origen: 'ABASTECIMIENTO_RAPIDO_MODAL'`.
       - Si el nuevo stock supera el umbral, auto-resuelve la alerta en segundo plano y muestra feedback inmediato.
  3. **Zona 3: Ajuste Rápido de Umbral Mínimo en 1 Toque:**
     * Permite reducir el umbral (ej. de 5 a 2) con un selector interactivo `[-]` `[2 und.]` `[+]`.
     * Si el comerciante baja el umbral a una cifra menor o igual al stock actual, la alerta de stock bajo se auto-resuelve de inmediato.
  4. **Zona 4: Línea de Tiempo de Movimientos (Kardex Real):**
     * Consulta canónica sobre `stock_ledger` ordenada descendentemente por fecha.
     * Si existen movimientos: tarjetas informativas ricas con icono de color (`Venta (Salida)`, `Abastecimiento (Entrada)`, `Ajuste de Inventario`, `Inventario Inicial`).
     * **Estado Vacío Elegante:** Si solo existe el asiento inicial, en lugar del espacio blanco vacío, mostrar una tarjeta informativa limpia con icono `Icons.inventory_2_outlined`:
       *"Producto registrado el [dd/MM/yyyy] con un inventario inicial de [N] unidades. No se registran ventas previas."*

---

### FASE 2: Erradicación de `SnackBar` Pegados y Adopción del Toast Flotante Premium (Captura 1)

#### 2.1. Arquitectura de `NotificationToastFeedback`
* **Ubicación:** `lib/core/widgets/notification_toast_feedback.dart`
* **Mecanismo:** Montado sobre el `Overlay` del contexto activo (`rootOverlay: true`). Totalmente desacoplado de `ScaffoldMessenger`, eliminando la causa raíz del bug de Android.
* **Componentes Visuales:**
  * Contenedor con radio de curvatura de 16dp, fondo oscuro de alta densidad (`#1E1E28` en Dark Mode, `#23232F` en Light Mode con sombra profunda `Offset(0, 6)`, `blurRadius: 16`).
  * Borde perimetral tintado con el color temático de la acción.
  * Icono vectorial representativo (`Icons.inventory_2_rounded` para archivar, `Icons.notifications_off_rounded` para silenciar, `Icons.check_circle_rounded` para resolver).
  * Texto explicativo conciso y de alto contraste.
  * Botón interactivo **`[Deshacer]`** integrado:
    - Tipografía destacada en color ámbar/dorado (`#FFD54F`), efecto `InkWell` con micro-háptica `HapticFeedback.lightImpact()`.
    - Al ser presionado, invoca el callback de reversión (`undoAction`) y remueve el toast instantáneamente sin parpadeos.
  * **Barra de Progreso de Tiempo Restante (3.0s):** Delgada línea animada en la parte inferior del toast (1.5dp de grosor) que se contrae de 100% a 0% durante 3.0 segundos, dando certeza visual de su cierre automático.
* **Gestión de Ciclo de Vida e Inmunidad al Bloqueo:**
  * Uso de `Timer` estricto de `3000ms`.
  * Animación de entrada: `AnimatedSlide(Offset(0, 0.5) -> Offset.zero)` y `AnimatedOpacity(0.0 -> 1.0)` en 220ms (`Curves.easeOutBack`).
  * Animación de salida: `AnimatedOpacity(1.0 -> 0.0)` a los 2800ms para desaparecer suavemente a los 3000ms.
  * Respeto de posición inferior: anclaje dinámico a:
    ```dart
    bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom + 16.0
    ```
* **Limpieza de Código:** Eliminar toda llamada a `ScaffoldMessenger.of(context).showSnackBar` en `notifications_screen.dart`, `archived_notifications_modal.dart` y `silenced_notifications_modal.dart`, reemplazándolas por:
  ```dart
  NotificationToastFeedback.show(
    context: context,
    message: "Notificación archivada",
    icon: Icons.inventory_2_outlined,
    accentColor: Colors.amber,
    undoLabel: "Deshacer",
    onUndo: () => prov.unarchiveNotification(notif.id),
  );
  ```

---

### FASE 3: Rediseño de Modales de Opciones, Archivadas y No Deseadas + Respeto Estricto de `SafeArea` (Capturas 2, 5 y 6)

#### 3.1. Blindaje Universal de `SafeArea` Inferior
* Todos los modales del módulo de notificaciones deben adoptar de manera obligatoria la fórmula de protección:
  ```dart
  final bottomClearance = MediaQuery.of(context).viewPadding.bottom + 16.0;
  ```
  O utilizar `InteractiveSheetWrapper.getEffectiveBottomPadding(context, minPadding: 28.0)`.
* Esto garantiza que los botones de acción inferior (`[Eliminar definitivamente]`, `[Restaurar todo]`, `[Listo / Guardar]`) nunca queden pegados ni sean tapados por los tres botones de navegación de Android (`< O |||`) mostrados en las capturas.

#### 3.2. Rediseño del Modal `Opciones para esta notificación` (Captura 2)
* **Cabecera Limpia sin Emojis:**
  * Extracción y saneamiento del título mediante `notif.cleanTitle` (eliminando `⚠️`, `🚨`, `💰`, etc.).
  * Contenedor circular con icono vectorial acorde a la categoría (`Icons.inventory_2_outlined`, `Icons.receipt_long_rounded`, `Icons.payments_outlined`).
  * Píldora de estado de la notificación: `Pendiente`, `Resuelta`, `Crítica` o `Preventiva`.
* **Sección de Acciones Rápidas Contextuales (Direct Action Cards):**
  * Si es **Stock / Inventario**:
    - `[⚡ Reabastecer Rápido]`: Abre el panel de abastecimiento en 1 toque.
    - `[⚙️ Ajustar Umbral de Alerta]`: Permite calibrar el umbral mínimo del producto.
  * Si es **Cobranzas / Cuotas**:
    - `[💬 Enviar Recordatorio WhatsApp]`: Abre la vista previa del mensaje con datos del cliente.
    - `[💵 Registrar Cobro / Abono]`: Abre el modal de amortización de deuda.
  * Si es **Cotización**:
    - `[📄 Ver Cotización]`: Navega al detalle de la propuesta comercial.
* **Módulo de Posponer (`Snooze` Inteligente):**
  * Fila de chips interactivos: `[1 día]`, `[3 días]`, `[1 semana]`.
  * Posponer oculta temporalmente la notificación de `Pendientes` sin tener que silenciarla definitivamente, programando su reaparición automática si la situación persiste.
* **Bloque de Gestión del Estado:**
  * Tarjetas agrupadas con esquinas redondeadas y micro-interacciones:
    - `Archivar notificación` (con toast animado y opción de deshacer).
    - `Mover a No Deseadas` (bloquear futuras alertas de esta cuota/producto).
    - `Marcar como resuelta / pendiente`.
    - `Eliminar definitivamente` (con diálogo de confirmación seguro).

#### 3.3. Pulido de `Notificaciones Archivadas` (Captura 5) e `Ítems en No Deseadas` (Captura 6)
* **Corrección del Título Roto en `Notificaciones Archivadas`:**
  * Rediseñar la cabecera en un `Row` con distribución adaptativa o usar `FittedBox` / tamaño tipográfico de 16.5dp con `maxLines: 1` para que `"Notificaciones Archivadas"` permanezca en una sola línea horizontal armónica.
* **Humanización y Deduplicación en `Ítems en No Deseadas`:**
  * **Cambio de texto en el buscador:** Reemplazar el hint técnico `"Buscar por palabra clave, folio o mute key..."` por **`"Buscar por cliente, producto o referencia..."`**.
  * **Traducción de Códigos Técnicos:** Reemplazar el chip `🚫 Alertas relacionadas bloqueadas (cuota_3)` por una etiqueta en lenguaje natural:
    - Si el `mute_key` es `cuota_X` -> Consultar o resolver: **`"Silenciado: Cuota de [Nombre Cliente]"`**.
    - Si el `mute_key` es `producto_X` -> **`"Silenciado: [Nombre del Producto]"`**.
    - Si el `mute_key` es `cliente_X` -> **`"Silenciado: Alertas de [Nombre Cliente]"`**.
  * **Consolidación y Deduplicación Estricta:**
    - Agrupar la lista `silencedNotifications` por `effectiveMuteKey`. Si existen múltiples registros históricos silenciados con la misma clave (ej. las 2 cuotas de Freddy con `cuota_3` de la Captura 6), mostrar una **única tarjeta consolidada** que indique `"1 elemento silenciado"` o `"Historial de 2 avisos silenciados"`.
  * **Erradicación de Emojis:** Limpiar cualquier emoji residual de títulos antiguos (`💰 Cuota Vencida...` -> `Cuota Vencida • Freddy`).
  * **Control de Foco del Teclado:** Integrar `onTapOutside: (_) => FocusScope.of(context).unfocus()` en el buscador para ocultar el teclado al tocar la lista.
  * **Barra Fija Inferior de Acciones Globales:**
    - Pie de página anclado con botones estilizados: `[Restaurar todo]` y `[Limpiar bandeja]`.

---

### FASE 4: Perfeccionamiento de `Configuración de Alertas` y Modales de Tarjeta (Capturas 7 y 8)

#### 4.1. Rediseño del Modal `Configuración de Alertas` (`notification_settings_modal.dart`)
* **Eliminación de Títulos Partidos (`_PremiumSwitchCard`):**
  * Reemplazar el `SwitchListTile.adaptive` estándar por un widget optimizado que distribuya el icono, título y switch de manera balanceada, asegurando que títulos como `"Productos Agotados (0 und.)"` y `"Smart Grouping por Cliente"` queden en una sola línea fluida sin partir palabras en sílabas huérfanas.
* **Nuevos Controles de Inteligencia de Inventario:**
  * En la sección `ALERTAS DE INVENTARIO` / `TIEMPOS Y CONDICIONES`:
    1. **Tiempo de Gracia en Producto Nuevo:**
       * Selector por chips: `[Al 1er movimiento]`, `[3 días (Recomendado)]`, `[7 días]`.
       * Leyenda explicativa: *"No alertar stock bajo al registrar un producto nuevo hasta que ocurra su primera venta o se cumpla el plazo de gracia."*
    2. **Protección Anti-Spam en Ventas Consecutivas:**
       * Switch: *"Actualización silenciosa de stock bajo"* (Evita relanzar o desarchivar alertas al vender unidades sucesivas de un producto ya bajo).
* **Cabecera con Accesos Directos por Sección:**
  * Barra horizontal compacta con píldoras deslizables: `[Bandejas]`, `[Cobranzas]`, `[Inventario]`, `[Tiempos]`, `[Interacción]`. Permite saltar con un toque a la sección deseada mediante un `ScrollController`.
* **Pie Fijo de Guardado y Reseteo (`Docked Footer`):**
  * Barra fija inferior separada por un divisor sutil, con:
    - Botón secundario: `[Restaurar valores recomendados]`.
    - Botón primario: `[Listo / Guardar cambios]`.
  * Aplicación estricta de `padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewPadding.bottom + 12)` para que **NUNCA** colisione ni se corte contra la barra de navegación de Android (solucionando el defecto de la Captura 8).

#### 4.2. Auditoría Integral de Modales de Tarjetas (`Cobrar`, `Mora`, `WhatsApp`, etc.)
* Revisar los modales que se abren desde las tarjetas:
  - `_showCuotaVencidaModal`
  - `_showNotificationDetails`
  - `WhatsAppPreviewModal.showCuotaReminder`
  - `PaymentEntryModal`
  - `CuotaMorosidadModal`
* Asegurar que todos cuenten con:
  - `InteractiveSheetWrapper` o padding inferior defensivo.
  - Cero llamadas a `showSnackBar` (uso exclusivo de `NotificationToastFeedback`).
  - Animaciones fluidas a 60fps sin tirones de frame.

---

### FASE 5: Responsividad en Pantallas Estrechas (`320dp`/`360dp`), Modo Claro/Oscuro y Cero Regresiones

#### 5.1. Responsividad y Ergonomía de Pestañas y Filtros
* **Barra de Filtros Horizontales (`notification_filter_bar.dart`):**
  * Indicadores visuales sutiles (degradado en los bordes) para que el comerciante note claramente que la barra es deslizable horizontalmente.
  * Optimización de padding para terminales ultra-compactos (`320dp` y `360dp`), evitando cualquier `A RenderFlex overflowed by X pixels`.
* **Sincronización Matemática Coherente:**
  * Garantizar que los badges de conteo (`Todas`, `Cobranzas`, `Inventario`, `Cotizaciones`) coincidan matemáticamente 1:1 con la cantidad de tarjetas visibles en pantalla en las tres pestañas (`Pendientes`, `Resueltas`, `Historial`).

#### 5.2. Estandarización Visual, Temas y Limpieza de Código
* **Modo Claro y Oscuro:**
  * Sustitución rigurosa de cualquier `withOpacity(...)` por `withValues(alpha: ...)`.
  * Contraste cromático validado (WCAG AA) para textos y badges sobre fondos oscuros (`#1E1E28`, `#23232F`) y claros (`#FFFFFF`, `#F8F9FA`).
* **Cero Emojis en Código de UI:**
  * Erradicar emojis incrustados como iconos en títulos o botones (`⚠️`, `🚨`, `💰`, `📦`). Usar exclusivamente la familia `Icons.*` de Flutter con contenedores geométricos tintados.
* **Calidad de Código:**
  * `0 issues` en `flutter analyze`.
  * Cero advertencias de linter y respeto de buenas prácticas de arquitectura.

---

## 4. MATRIZ DEL ÁRBITRO INTERNO ADVERSARIAL (AUDITORÍA EXTREMA PRE-EJECUCIÓN)

| ID | Escenario / Caso Borde | Comportamiento Defectuoso Previo | Comportamiento Esperado (Blindaje V2.5) | Criterio de Aprobación |
| :--- | :--- | :--- | :--- | :--- |
| **ARB-01** | **Creación de Producto con Stock Inicial 3 (Umbral 5)** | El sistema dispara inmediatamente una alerta preventiva diciendo que el stock *"cayó a 3 und."* (Captura 3). | Al no registrar transacciones de venta en `stock_ledger` y estar dentro del periodo de gracia, **NO se genera ninguna alerta**. | Cero alertas en `Pendientes` al registrar producto nuevo. |
| **ARB-02** | **Primera Venta Real de Producto con Stock Bajo** | N/A | Al realizarse la primera venta en el TPV o Caja Rápida que reduce el stock, el sistema registra el asiento de `VENTA` en `stock_ledger` y emite legítimamente la alerta de Stock Bajo. | Alerta emitida únicamente tras la salida comercial real. |
| **ARB-03** | **Ventas Sucesivas del Mismo Producto (`5 -> 4 -> 3 -> 2`)** | El sistema resucita alertas resueltas/archivadas o spamea con avisos repetidos cada vez que se vende una unidad. | Se actualiza silenciosamente in-place la notificación existente sin crear nuevas tarjetas, sin desarchivar y sin emitir ruidos innecesarios. | 1 sola tarjeta consolidada con el stock actual actualizado. |
| **ARB-04** | **Producto que Llega a 0 Unidades (Agotado)** | Podía confundirse con una alerta preventiva normal o quedar oculta si estaba archivada. | El sistema escala automáticamente la alerta a prioridad `critica`: `🚨 ¡Producto Agotado! (0 und.)`. | Alerta crítica visible y prioritaria en la lista. |
| **ARB-05** | **Modal `Análisis de Stock` en Producto sin Ventas Previas** | Mostraba un enorme espacio blanco vacío con `"No hay movimientos recientes"` (Captura 4). | Muestra panel diagnóstico completo con stock actual, costo, precio, proveedor y tarjeta informativa limpia sobre el registro inicial. | Cero huecos blancos; interfaz profesional de nivel Mobile Awards. |
| **ARB-06** | **Abastecimiento Rápido In-Modal (`+ Sumar Stock`)** | No existía: obligaba a navegar a `ProductEditScreen`, editar y guardar manualmente. | Botones `[+5]`, `[+10]`, `[+12]`, `[+24]` suman stock en SQLite a `0ms`, registran en `stock_ledger` y auto-resuelven la alerta si supera el umbral. | Stock actualizado en BD y notificación resuelta instantáneamente. |
| **ARB-07** | **Ajuste de Umbral Mínimo In-Modal** | No existía. | Permite cambiar el umbral de 5 a 2 directamente; si el stock actual (3) supera el nuevo umbral (2), la alerta se auto-resuelve. | Notificación auto-resuelta sin salir del modal. |
| **ARB-08** | **Archivar / Silenciar y Deshacer (Toast Anti-Pegado)** | El `SnackBar` nativo con `SnackBarAction` se quedaba pegado indefinidamente en Android (Captura 1). | `NotificationToastFeedback` sobre `OverlayEntry` flota elegantemente, ofrece `[Deshacer]` y se auto-destruye estrictamente a los 3.0 segundos. | El aviso desaparece con animación fluida a los 3.0s sin intervención del usuario. |
| **ARB-09** | **Borde Inferior de Android en Modales (`SafeArea`)** | Botones inferiores pegados o cortados por la barra `< O |||` de Android (Capturas 2 y 8). | Cálculo exacto de `viewPadding.bottom + 16dp` en todos los modales; pie fijo en `Configuración de Alertas`. | Separación visual de mínimo 16dp sobre la barra del sistema. |
| **ARB-10** | **Deduplicación y Humanización en No Deseadas** | Buscador mencionaba `"mute key"`, chip exponía `(cuota_3)` y mostraba tarjetas duplicadas de Freddy (Captura 6). | Buscador amigable, traducción a `"Silenciado: Cuota de Freddy"`, deduplicación por clave y eliminación de emojis `💰`. | 1 sola tarjeta por ítem silenciado con texto 100% humano. |
| **ARB-11** | **Títulos Partidos en Configuración de Alertas** | Textos como `"Productos Agotados (0\nund.)"` y `"Smart Grouping por\nCliente"` (Capturas 7 y 8). | Títulos formateados en layout flexible que previene quiebres forzados de palabras. | Tipografía fluida y legible sin saltos de línea torpes. |
| **ARB-12** | **Compilación y Rendimiento** | Posibles advertencias de linter o incompatibilidad de temas. | `flutter analyze` reporta 0 issues; uso exclusivo de `.withValues(alpha: ...)`. | Código limpio, modular y sin regresiones. |

---

## 5. REPORTE DE ARCHIVOS A INTERVENIR (UNA VEZ APROBADO EL PLAN)

| Módulo / Capa | Archivo | Responsabilidad Principal |
| :--- | :--- | :--- |
| **Core Models** | `lib/core/models/notification_preferences_model.dart` | Agregar campos de configuración: `diasGraciaStockBajo` y `antiSpamStockSilencioso`. |
| **Core Models** | `lib/core/models/notification_model.dart` | Añadir getter `cleanTitle` para erradicar emojis crudos y enriquecer metadata tipada. |
| **Core Widgets** | `lib/core/widgets/notification_toast_feedback.dart` *(Nuevo)* | Componente `OverlayEntry` con `AnimatedSlide`, timer forzoso de 3.0s y botón `[Deshacer]`. |
| **Core Providers** | `lib/core/providers/notification_provider.dart` | Implementar regla de gracia en stock inicial por `stock_ledger` y actualización silenciosa anti-spam. |
| **Sales Service** | `lib/features/smart_quotation/services/sales_service.dart` | Respetar estado archivado/resuelto en ventas consecutivas (5->4->3->2) sin relanzar alertas. |
| **Notifications UI** | `lib/features/profile/screens/notifications_screen.dart` | Reemplazar SnackBar por Toast, modernizar modal de Opciones, integrar nuevo `StockAnalysisModal`. |
| **Stock Modal** | `lib/features/profile/widgets/notifications/stock_analysis_modal.dart` *(Nuevo)* | Rediseño en 3 zonas: Diagnóstico visual, Abastecimiento Rápido in-modal, Ajuste de umbral y Kardex real. |
| **Cards UI** | `lib/features/profile/widgets/notifications/notification_item_card.dart` | Renombrar botón `[Kardex]` a `[Análisis]`, limpieza de títulos y micro-háptica. |
| **Archived Modal** | `lib/features/profile/widgets/notifications/archived_notifications_modal.dart` | Corregir título partido, añadir pie fijo de acciones rápidas y usar Toast animado. |
| **Silenced Modal** | `lib/features/profile/widgets/notifications/silenced_notifications_modal.dart` | Deduplicar por `mute_key`, traducir códigos a lenguaje humano, buscador amigable y pie fijo. |
| **Settings Modal** | `lib/features/profile/widgets/notifications/notification_settings_modal.dart` | Corregir títulos partidos, añadir controles de gracia/anti-spam y docked footer con `SafeArea`. |
| **Filter Bar UI** | `lib/features/profile/widgets/notifications/notification_filter_bar.dart` | Mejorar indicador de scroll táctil y responsividad garantizada en pantallas de 320/360dp. |

---

## 6. PROTOCOLO DE EJECUCIÓN (LISTO PARA LA SEGUNDA ORDEN)

Una vez revisado y aprobado este Plan de Trabajo Maestro por el usuario:
1. **Fase 1:** Se implementará la lógica de gracia en `NotificationProvider` y `SalesService`, seguida por la construcción del nuevo `StockAnalysisModal` y la actualización de las tarjetas en `notification_item_card.dart`.
2. **Fase 2:** Se creará `NotificationToastFeedback` y se erradicarán todos los `showSnackBar` del módulo de notificaciones.
3. **Fase 3:** Se rediseñará el modal `Opciones para esta notificación`, se pulirá `ArchivedNotificationsModal` y se humanizará/deduplicará `SilencedNotificationsModal` con blindaje de `SafeArea`.
4. **Fase 4:** Se refactorizará `NotificationSettingsModal` con docked footer fijo y se auditarán todos los modales de cobro/mora/cotización.
5. **Fase 5:** Se ajustará la barra de filtros para 320/360dp, se garantizará cero emojis en UI, se ejecutará `flutter analyze` hasta certificar **0 issues** y se verificará el cumplimiento del 100% de la Matriz del Árbitro Adversarial.

