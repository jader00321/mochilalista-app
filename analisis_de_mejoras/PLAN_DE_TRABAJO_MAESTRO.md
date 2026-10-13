# 📋 PLAN DE TRABAJO MAESTRO: Mejora Integral de MochilaLista 2.0

> **Versión del Plan:** 2.0 (FINAL)  
> **Fecha de creación:** 12 de Octubre 2026  
> **Fecha de finalización:** 13 de Octubre 2026  
> **Estado:** ✅ **COMPLETADO AL 100% (23/23 Tareas implementadas y verificadas)**  
> **Basado en:** Informes 01, 02, 03 y 04 del análisis de backup BAZAR LUZAM  
> **Objetivo:** Corregir bugs, mejorar funciones existentes y potenciar la productividad del usuario  

---

## 📐 METODOLOGÍA

- El trabajo se dividirá en **5 fases secuenciales**.
- **Cada fase se implementará y verificará completamente** antes de avanzar a la siguiente.
- **No se duplicarán funciones existentes:** antes de crear algo nuevo, se verificará si ya existe en la app.
- **No se harán cambios bruscos**: las modificaciones serán incrementales y compatibles con la lógica existente.
- **Prioridad:** Bugs críticos → Mejoras de datos → Mejoras UX → Nuevas funciones → Funciones avanzadas.

---

## 🗺️ INVENTARIO DE FUNCIONALIDADES EXISTENTES

Antes de planificar, se documentan las funciones que **YA EXISTEN** en la app para evitar duplicaciones:

### Pantallas principales existentes:
| Pantalla | Ubicación | Estado |
|----------|-----------|--------|
| **Home Dashboard** | `home_screen.dart` → `_HomeDashboardView` | ✅ Funcional con DashboardHeader, WeeklySalesChart, SmartActionGrid, RestockSmartBanner, RecentActivityList, QuotationBanner |
| **Inventario** (5 pestañas) | `inventory_screen.dart` | ✅ Pestañas: Productos, Ofertas/Bundles, Categorías, Marcas, Proveedores |
| **Catálogo** | `catalog_screen.dart` (51KB) | ✅ Con filtros, carrito, modal de detalle |
| **Caja Rápida (QuickSale)** | `quick_sale_screen.dart` (40KB) | ✅ Funcional con búsqueda, escáner barcode, carrito, checkout |
| **Escáner IA** (factura) | `scan_screen.dart` → `invoice_review_screen.dart` → `invoice_staging_screen.dart` | ✅ Funcional |
| **Historial Facturas IA** | `invoice_history_screen.dart` → `invoice_detail_screen.dart` | ✅ Funcional pero con el bug de datos vacíos |
| **Cotización Manual** | `manual_quotation_screen.dart` | ✅ Funcional |
| **Mesa de Trabajo** | `workbench_screen.dart` | ✅ Funcional |
| **Historial de Ventas** | `sales_history_screen.dart` → `sale_history_detail_screen.dart` | ✅ Funcional |
| **Clientes (CRM)** | `client_tracking_screen.dart` → `sale_client_detail_screen.dart` | ✅ Funcional |
| **Perfil del Usuario** | `profile_screen.dart` | ✅ Con header KPIs, BusinessInfoCard, menú de configuración |
| **Editar Perfil** (modal) | `edit_profile_modal.dart` | ✅ Solo permite editar: Nombre y Teléfono (**NO email**) |
| **Editar Negocio** (modal) | `edit_business_modal.dart` | ✅ Permite: Nombre, RUC, Dirección, Info de Pago, GPS, Privacidad |
| **Notificaciones** | `notifications_screen.dart` | ✅ Funcional |
| **Backup/Restauración** | `backup_screen.dart` → `business_backup_service.dart` | ✅ Funcional pero con bugs en el remapeo |
| **Detalle de Producto** | `product_detail_screen.dart` (49KB) | ✅ Funcional pero mejorable |
| **Crear/Editar Producto** | `product_create_screen.dart` / `product_edit_screen.dart` | ✅ Funcional |
| **Analytics Dashboard** | `analytics_dashboard_screen.dart` | ✅ Funcional |
| **Reabastecimiento** | `smart_restock_screen.dart` + `restock_smart_banner.dart` | ✅ YA EXISTE - Banner en Home + Pantalla completa |
| **Escáner de Barcode** | `barcode_scanner_screen.dart` | ✅ YA EXISTE en caja rápida |
| **Ofertas/Bundles** | `offers_tab.dart` + `bundle_builder_screen.dart` (56KB) | ✅ YA EXISTE |
| **Audit Trail** | `audit_trail_screen.dart` | ✅ YA EXISTE |
| **Predictive Analytics** | `predictive_analytics_screen.dart` | ✅ YA EXISTE |
| **Impresora Térmica** | `printer_config_screen.dart` | ✅ Funcional |
| **PIN de Seguridad** | `change_pin_modal.dart` + `lock_screen.dart` | ✅ Funcional |

### Widgets reutilizables existentes:
- `product_detail_modal.dart` (19KB) - Modal de detalle desde el catálogo
- `product_action_sheet.dart` (22KB) - Acciones sobre producto
- `product_presentation_card.dart` (69KB) - Card de presentación
- `discount_intelligent_modal.dart` (13KB) - Modal inteligente de descuentos
- `smart_unit_selector.dart` (15KB) - Selector de unidades
- `filter_drawer.dart` (18KB) - Filtros avanzados
- `catalog_filter_drawer.dart` (12KB) - Filtros del catálogo

### Funciones que YA EXISTEN y NO se deben duplicar:
1. ✅ **Escáner de barcode** → Ya existe en `barcode_scanner_screen.dart`
2. ✅ **Reabastecimiento inteligente** → Ya existe en `smart_restock_screen.dart`
3. ✅ **Dashboard con gráficos** → Ya existe `weekly_sales_chart.dart` + `analytics_dashboard_screen.dart`
4. ✅ **Sistema de bundles/paquetes** → Ya existe en `bundle_builder_screen.dart`
5. ✅ **Predictive analytics** → Ya existe en `predictive_analytics_screen.dart`
6. ✅ **Selector de unidades** → Ya existe `smart_unit_selector.dart`

---

# 📅 FASES DE IMPLEMENTACIÓN

---

## FASE 1: 🔴 CORRECCIONES CRÍTICAS DE BUGS
**Estimación:** 1-2 sesiones  
**Prioridad:** MÁXIMA — Corregir problemas que afectan la integridad de datos

### Tarea 1.1: Corregir bug de `origen_id` sin remapear en `stock_ledger` al importar backup
- **Archivo:** `business_backup_service.dart` (líneas 791-797)
- **Problema:** Al importar un backup, el campo `origen_id` de `stock_ledger` no se remapea según el `tipo_transaccion` (COMPRA_LOTE → invoiceIdMap, VENTA → saleIdMap)
- **Solución:** Agregar lógica de remapeo condicional en el loop de inserción de stock_ledger
- **Riesgo:** BAJO — Solo afecta la importación, no la operación normal
- **Verificación:** Exportar un backup de prueba, importarlo y verificar que los `origen_id` apuntan a las facturas/ventas correctas

### Tarea 1.2: Corregir bug de `product_history` sin remapear presentaciones
- **Archivo:** `business_backup_service.dart` (líneas 800-808)
- **Problema:** Solo remapea IDs de tipo `'producto'` pero no de tipo `'presentacion'`
- **Solución:** Agregar caso para `entidad_tipo == 'presentacion'` usando `presentationIdMap`
- **Riesgo:** BAJO

### Tarea 1.3: Eliminar código duplicado en servicio de backup (refactoring)
- **Archivo:** `business_backup_service.dart`
- **Problema:** `exportBusiness()` y `exportBusinessToFile()` tienen ~250 líneas duplicadas de recopilación de datos
- **Solución:** Extraer la lógica compartida a un método privado `_collectBackupData()`
- **Riesgo:** BAJO — Solo refactoring interno, sin cambios de funcionalidad
- **Verificación:** Ambas funciones (exportar por WhatsApp y exportar a archivo) deben seguir funcionando idéntico

### Tarea 1.4: Corregir visualización de facturas manuales en el historial
- **Archivos:** `invoice_detail_screen.dart`, `invoice_history_screen.dart`
- **Problema:** Las facturas ingresadas manualmente (sin `datos_crudos_ia_json`) se muestran vacías en el historial
- **Solución en 2 partes:**
  1. En `invoice_history_screen.dart`: Cuando `cantidadItemsExtraidos` es null, consultar la cantidad de presentaciones vinculadas por `factura_carga_id` y mostrarla como etiqueta
  2. En `invoice_detail_screen.dart`: Cuando `datosCrudosIaJson` es null, construir la vista de ítems consultando `presentaciones_producto` por `factura_carga_id` en lugar de intentar parsear el JSON inexistente
  3. Diferenciar visualmente facturas escaneadas (📷) vs manuales (✍️) en ambas pantallas
- **Riesgo:** MEDIO — Requiere agregar una nueva consulta al provider y adaptar la UI
- **Verificación:** Restaurar el backup de BAZAR LUZAM y verificar que las 19 facturas muestran sus ítems correctamente

---

## FASE 2: 🟡 VALIDACIONES Y LIMPIEZA DE DATOS
**Estimación:** 1-2 sesiones  
**Prioridad:** ALTA — Prevenir contaminación de datos futuros

### Tarea 2.1: Validación de duplicados al crear Marcas
- **Archivos:** `brands_tab.dart` (formulario `_BrandFormDialog`)
- **Qué existe:** El formulario de crear/editar marca en `brands_tab.dart` tiene campos para nombre e imagen, pero NO valida duplicados
- **Mejora:** Al guardar una nueva marca, buscar coincidencias por nombre (case-insensitive). Si hay coincidencia, mostrar diálogo de confirmación preguntando si usar la existente o crear nueva
- **Riesgo:** BAJO
- **Verificación:** Intentar crear "sedal" cuando ya existe "Sedal" y que muestre advertencia

### Tarea 2.2: Validación de duplicados al crear Proveedores (por RUC y nombre)
- **Archivos:** `providers_tab.dart`
- **Qué existe:** El formulario de crear proveedor tiene campos para nombre, RUC, contacto, teléfono, email, pero NO valida duplicados
- **Mejora:** Al guardar, buscar por RUC idéntico Y por nombre similar. Si hay coincidencia, mostrar advertencia
- **Riesgo:** BAJO
- **Verificación:** Intentar crear "PUNTO BLANCO S.A.C." cuando ya existe "PUNTO BLANCO SAC" y que sugiera fusionar

### Tarea 2.3: Validación de duplicados al crear Categorías
- **Archivos:** `categories_tab.dart`
- **Mejora:** Misma lógica que marcas — validar por nombre similar/idéntico
- **Riesgo:** BAJO

### Tarea 2.4: Sistema de Fusión de Duplicados en pestañas de Marcas, Categorías y Proveedores
- **Archivos:** `brands_tab.dart`, `categories_tab.dart`, `providers_tab.dart`
- **Qué existe:** Cada pestaña tiene lista de items con funciones de crear, editar y eliminar. NO tienen sistema de fusión
- **Funcionalidad nueva:** Agregar un botón/opción en cada pestaña que:
  1. Detecte automáticamente posibles duplicados (por nombre similar, RUC idéntico, etc.)
  2. Muestre un modal con los pares detectados y sugiera fusión
  3. Permita al usuario elegir qué datos conservar (de uno existente o crear datos propios)
  4. Al fusionar, actualice todos los `productos` que referencien al duplicado eliminado para que apunten al que permanece
  5. Elimine el registro duplicado
- **Implementación:** Agregar botón "🔄 Detectar Duplicados" en la toolbar de cada pestaña. Al presionarse, abre un modal con la lista de posibles duplicados
- **Base de datos:** La fusión actualiza FK en `productos` (para marcas/categorías), `presentaciones_producto` y `facturas_carga` (para proveedores)
- **Riesgo:** MEDIO — Requiere transacciones de BD cuidadosas para no perder datos
- **Verificación:** Fusionar "Sedal" (id:27) con "Sedal" (id:38), verificar que los productos que usaban id:38 ahora usan id:27, y que id:38 fue eliminado

### Tarea 2.5: Validación de fecha en facturas
- **Archivos:** `invoice_staging_screen.dart` o donde se establece la fecha de emisión
- **Mejora:** Validar que la fecha no sea futura ni más de 1 año antigua. Mostrar advertencia (no bloquear)
- **Riesgo:** BAJO

---

## FASE 3: 🟢 MEJORAS DE INTERFAZ Y UX (Perfil + Info del negocio)
**Estimación:** 2-3 sesiones  
**Prioridad:** ALTA — Mejorar la experiencia de usuario y completar datos del negocio

### Tarea 3.1: Mejorar el modal de Editar Perfil para incluir Email
- **Archivos:** `edit_profile_modal.dart`
- **Qué existe:** El modal solo permite editar Nombre y Teléfono. **NO hay campo para email** después del onboarding
- **Mejora:** Agregar campo de email con validación. Agregar animaciones suaves de entrada
- **Riesgo:** BAJO — Solo agrega un campo más al formulario existente
- **Verificación:** Abrir "Editar Datos Personales", verificar que aparece el campo de email, guardarlo y confirmar que se persiste

### Tarea 3.2: Indicador de "Perfil Completo" en la pantalla de Perfil
- **Archivos:** `profile_screen.dart`, posible nuevo widget `profile_completion_indicator.dart`
- **Qué existe:** La pantalla de perfil tiene un header con avatar, nombre, badge "DUEÑO DE NEGOCIO" y 3 micro KPIs (Productos, Borradores, Ventas Hoy). NO tiene indicador de completitud
- **Mejora:** Agregar debajo del `BusinessInfoCard` un widget de barra de progreso animada que muestre:
  - % de completitud del perfil
  - Lista de campos pendientes (tocables para ir directamente a completarlos)
  - Campos evaluados: Nombre ✅, Teléfono ✅, Email ❌, RUC ❌, Logo ❌, Dirección ✅, Info Pago ✅, GPS ❌, PIN ❌
  - Al tocar un campo pendiente, abre directamente el modal correspondiente (editar perfil, editar negocio, cambiar PIN, etc.)
- **Animaciones:** Barra de progreso con animación de llenado, checkmarks animados, efecto confetti al llegar al 100%
- **Riesgo:** BAJO — Solo agrega un widget nuevo, no modifica lógica existente
- **Verificación:** Verificar que el porcentaje se calcula correctamente y que los enlaces llevan al modal correcto

### Tarea 3.3: Mejora visual del BusinessInfoCard
- **Archivos:** `business_info_card.dart`
- **Qué existe:** Card con header gradient (nombre + RUC), mapa OpenStreetMap, dirección, "Cuenta Verificada". Es funcional pero básico
- **Mejora:**
  - Agregar sección de "Información de Pago" (Yape/Plin) que actualmente NO se muestra en el card
  - Agregar ícono indicador de GPS (si tiene o no ubicación)
  - Mejorar la sección de dirección con chips informativos
  - Si no tiene logo, mostrar sugerencia sutil "📷 Agrega un logo para tu negocio"
- **Riesgo:** BAJO

### Tarea 3.4: Globos de información (Info Tooltips) en pantallas principales
- **Archivos:** Crear widget reutilizable `info_tooltip_button.dart`, integrar en múltiples pantallas
- **Qué existe:** NO existe ningún sistema de tooltips/ayuda contextual
- **Funcionalidad:** Widget `InfoTooltipButton` que muestra un BottomSheet con:
  - Título de la sección
  - Descripción de qué hace y para qué sirve
  - Consejos de uso práctico
- **Pantallas donde integrarlo (en esta fase solo las principales):**
  1. Pantalla de Inventario (AppBar)
  2. Historial de Facturas IA
  3. Pantalla de Perfil
  4. Notificaciones
- **Riesgo:** BAJO — Solo agrega íconos de ayuda, no modifica lógica
- **Verificación:** Tocar el ícono ℹ️ y verificar que se muestra el BottomSheet con la información correcta

---

## FASE 4: 🔵 MEJORAS FUNCIONALES EXISTENTES
**Estimación:** 2-3 sesiones  
**Prioridad:** MEDIA-ALTA — Mejorar funciones que ya existen para mayor utilidad

### Tarea 4.1: Mejorar la pantalla de Detalle de Producto
- **Archivos:** `product_detail_screen.dart` (49KB — pantalla principal de detalle)
- **Qué existe:** Ya es una pantalla completa de 1188 líneas con:
  - Header con imagen/placeholder
  - Selector de presentaciones
  - Información de precios
  - Botones de acción (editar, descuento)
  - Historial via audit trail
- **Mejoras a implementar:**
  1. **Agregar indicador visual de margen de ganancia** (🟢/🟡/🔴 según %) para cada presentación — ACTUALMENTE NO EXISTE
  2. **Mostrar información del proveedor** vinculado a la presentación — EL CAMPO EXISTE (`proveedor_id`) PERO NO SE MUESTRA
  3. **Mostrar fecha de última compra** (última factura vinculada) — NO SE MUESTRA ACTUALMENTE
  4. **Sugerencia de reabastecimiento** cuando el stock está bajo — ACTUALMENTE se marca con un ícono pero no tiene CTA
  5. **Enlace rápido a "Crear Bundle"** si el producto no tiene ofertas — ACTUALMENTE no existe este acceso directo
  6. Mejorar el layout con secciones colapsables y mejor organización visual
- **Riesgo:** MEDIO — La pantalla es grande (49KB), los cambios deben ser incrementales y bien probados
- **Verificación:** Abrir el detalle de un producto, verificar que muestra margen, proveedor, última compra, y las nuevas funciones son accesibles

### Tarea 4.2: Mejorar el historial de facturas con diferenciación visual
- **Archivos:** `invoice_history_screen.dart`
- **Qué existe:** Lista de facturas con ícono de estado, proveedor, fecha, monto y etiquetas. Ya funciona pero todas se ven iguales
- **Mejoras:**
  1. Ícono diferente para facturas manuales (✍️) vs escaneadas (📷)
  2. Mostrar chips con nombres de productos vinculados (si hay pocos, mostrarlos; si hay muchos, mostrar "N ítems")
  3. Advertencia visual para fechas inusuales
- **Nota:** El bug de contenido vacío se corrige en la Fase 1 (Tarea 1.4). Esta tarea es solo mejora visual
- **Riesgo:** BAJO

### Tarea 4.3: Mejorar las notificaciones con badge en el home
- **Archivos:** `home_screen.dart`, `dashboard_header.dart`, `notifications_screen.dart`
- **Qué existe:** Ya existe `NotificationProvider` que carga notificaciones y la pantalla `NotificationsScreen`. El acceso es desde el Perfil
- **Mejoras:**
  1. **Agregar badge numérico** en el ícono del DashboardHeader que muestre notificaciones no leídas
  2. **Banner contextual** en el Home cuando hay notificaciones críticas (cuotas vencidas, stock bajo)
  3. **Acceso directo** a notificaciones desde el DashboardHeader (no solo desde Perfil)
- **Riesgo:** BAJO — Solo agrega indicadores visuales

### Tarea 4.4: Mejorar la Caja Rápida (QuickSale) con sugerencias contextuales
- **Archivos:** `quick_sale_screen.dart`, `quick_sale_header.dart`
- **Qué existe:** Ya funciona completamente con búsqueda, escáner de barcode, carrito, checkout modal, ofertas expandibles. Es una pantalla de 795 líneas
- **Mejoras (SIN cambios bruscos en la interfaz ni lógica):**
  1. **Productos recientes:** Mostrar una fila de productos vendidos recientemente (últimos 5) debajo de la barra de búsqueda para acceso rápido — NO EXISTE ACTUALMENTE
  2. **Indicador de margen** en cada item del carrito (sutil, solo un color) — NO EXISTE
  3. **Resumen mejorado** en el header que muestre la ganancia estimada del carrito actual — NO EXISTE
- **Riesgo:** BAJO — Son adiciones visuales que no modifican la lógica de venta existente
- **Verificación:** Verificar que la búsqueda, el escáner y el checkout siguen funcionando exactamente igual después de los cambios

### Tarea 4.5: Categorías predefinidas sugeridas al usuario
- **Archivos:** `categories_tab.dart`, posible diálogo sugerente
- **Qué existe:** La pestaña de categorías permite crear categorías con nombre e ícono. Actualmente el usuario solo tiene 1 categoría "abarrotes"
- **Mejora:** Cuando hay más de 15 productos y solo 1-2 categorías, mostrar un banner sugerente con categorías predefinidas comunes para bodega/librería (Lácteos, Limpieza, Cuidado Personal, Golosinas, Bebidas, Útiles Escolares, etc.)
- **Riesgo:** BAJO — Solo agrega un banner informativo

---

## FASE 5: 🟣 NUEVAS FUNCIONES Y OPTIMIZACIONES
**Estimación:** 2-3 sesiones  
**Prioridad:** MEDIA — Funciones nuevas que potencian la productividad

### Tarea 5.1: Recordatorios de cobro por WhatsApp
- **Archivos:** Posiblemente en `sale_client_detail_screen.dart` o `client_tracking_screen.dart`
- **Qué existe:** El CRM ya tiene vista de clientes con sus deudas. Ya existe funcionalidad de compartir por WhatsApp en cotizaciones (`whatsapp_preview_screen.dart`). Pero NO existe para cobros/cuotas
- **Funcionalidad:** Agregar botón "Enviar recordatorio por WhatsApp" en cada cuota vencida que genere un mensaje predefinido con el monto, fecha de vencimiento y métodos de pago del negocio
- **Riesgo:** BAJO — Usa la misma librería share_plus que ya usa la app

### Tarea 5.2: Calculadora de margen al registrar precios
- **Archivos:** `product_presentation_card.dart` (69KB), `price_update_modal.dart`, o donde se editan precios de presentaciones
- **Qué existe:** Ya existe `price_update_modal.dart` (14KB) para actualizar precios. Ya muestra precio de costo y venta
- **Mejora:** Agregar indicador visual de margen en el modal de precio: al cambiar el precio de venta, mostrar en tiempo real el % de margen y un color indicativo (🟢 > 20%, 🟡 10-20%, 🔴 < 10%)
- **Riesgo:** BAJO

### Tarea 5.3: Auto-categorización sugerida de productos
- **Archivos:** Nuevo servicio `auto_categorization_service.dart`
- **Qué existe:** Los productos tienen `categoria_id` pero la mayoría están en una sola categoría genérica. NO existe auto-categorización
- **Funcionalidad:** Servicio que analiza el nombre del producto y sugiere una categoría basada en palabras clave (yogurt→Lácteos, shampoo→Cuidado Personal, etc.)
- **Integración:** Botón "🏷️ Sugerir categorías" en la pestaña de productos o en el perfil
- **Riesgo:** BAJO — Solo sugiere, no aplica automáticamente

### Tarea 5.4: Recordatorio amigable de PIN de seguridad
- **Archivos:** `home_screen.dart` o `profile_screen.dart`
- **Qué existe:** El sistema de PIN ya existe y funciona (`change_pin_modal.dart`, `lock_screen.dart`). Pero no hay recordatorio si no está activado
- **Mejora:** Si el PIN no está configurado, mostrar un banner sutil cada cierto tiempo
- **Riesgo:** BAJO

### Tarea 5.5: Mejora del onboarding — Sugerir categorías al crear negocio
- **Archivos:** Pantallas de onboarding en `auth/screens/onboarding/`
- **Qué existe:** El onboarding actual permite crear usuario y negocio. NO sugiere categorías iniciales
- **Mejora:** Después de crear el negocio, mostrar un paso adicional que sugiera categorías predefinidas según el tipo de negocio
- **Riesgo:** BAJO — Es un paso opcional que no afecta el flujo existente

---

## 📊 RESUMEN GLOBAL DE TAREAS POR FASE

| Fase | Nombre | Tareas | Archivos afectados | Estado | Commits |
|------|--------|--------|-------------------|--------|---------|
| **1** | Correcciones Críticas | 4 tareas | `business_backup_service.dart`, `invoice_detail_screen.dart`, `invoice_history_screen.dart`, `invoice_provider.dart` | ✅ COMPLETADA | `2140deb` |
| **2** | Validaciones y Limpieza | 5 tareas | `brands_tab.dart`, `categories_tab.dart`, `providers_tab.dart`, `inventory_provider.dart` | ✅ COMPLETADA | `5da26be` |
| **3** | Mejoras UI/UX Perfil | 4 tareas | `profile_screen.dart`, `edit_profile_modal.dart`, `business_info_card.dart`, `info_tooltip_button.dart` (7 pantallas) | ✅ COMPLETADA | `18dc977`, `d0ded20` |
| **4** | Mejoras Funcionales | 5 tareas | `product_detail_screen.dart`, `invoice_history_screen.dart`, `home_screen.dart`, `quick_sale_screen.dart`, `categories_tab.dart` | ✅ COMPLETADA | `0f6acea`, `2e6cc92`, `2320e90` |
| **5** | Nuevas Funciones | 5 tareas | `sale_client_detail_screen.dart`, `price_update_modal.dart`, `auto_categorization_service.dart`, `home_screen.dart`, `onboarding_screen.dart` | ✅ COMPLETADA | `c10108b`, `d790ebf`, `4d0cb36`, `78e3d72`, `debf660` |

**Total: 23/23 tareas completadas exitosamente (100%)**

---

## 🔄 ORDEN DE EJECUCIÓN (HISTORIAL DE EJECUCIÓN COMPLETADO)

```
FASE 1 [✅] ──→ FASE 2 [✅] ──→ FASE 3 [✅] ──→ FASE 4 [✅] ──→ FASE 5 [✅] ──→ PROYECTO 100%
  │                │                │                │                │
  ├── 1.1 ✅       ├── 2.1 ✅       ├── 3.1 ✅       ├── 4.1 ✅       ├── 5.1 ✅
  ├── 1.2 ✅       ├── 2.2 ✅       ├── 3.2 ✅       ├── 4.2 ✅       ├── 5.2 ✅
  ├── 1.3 ✅       ├── 2.3 ✅       ├── 3.3 ✅       ├── 4.3 ✅       ├── 5.3 ✅
  └── 1.4 ✅       ├── 2.4 ✅       └── 3.4 ✅       ├── 4.4 ✅       ├── 5.4 ✅
                   └── 2.5 ✅                        └── 4.5 ✅       └── 5.5 ✅
```

---

## 📝 NOTAS IMPORTANTES PARA LA IMPLEMENTACIÓN

1. **Principio de no ruptura:** Cada cambio se verifica para asegurar que no rompe funciones existentes. Si una modificación es riesgosa, se hace en pasos más pequeños.

2. **Compatibilidad de backup:** Los cambios en `business_backup_service.dart` deben mantener compatibilidad con backups existentes (format version 1).

3. **Respeto a la UI existente:** Las mejoras visuales son incrementales — se mejora lo existente, no se reemplaza completamente. El estilo visual actual (dark mode, gradients, rounded corners) se mantiene consistente.

4. **Prioridad del usuario:** El usuario (Luz Navarro de BAZAR LUZAM) es una comerciante de bodega/librería en Talara, Perú. Las mejoras deben ser prácticas y fáciles de entender para un usuario no técnico.

5. **Pruebas con datos reales:** Cuando sea posible, se verifican los cambios usando los datos del backup analizado para confirmar que los problemas detectados se resuelven correctamente.
