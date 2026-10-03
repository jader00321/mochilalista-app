# Plan de Trabajo: Reestructuración de Base de Datos y Aislamiento Multi-Negocio (v1)

## 📋 Comprensión del Problema

Tras un análisis profundo de la base de datos ([local_db.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/database/local_db.dart)), los 7 providers, 4 repositorios y 5 servicios, he identificado **3 problemas raíz** que causan la contaminación de datos entre negocios:

### Problema 1: IDs Globales (Confusión de Numeración)
SQLite usa `AUTOINCREMENT` global. Cuando el Negocio A crea la Venta #1 y el Negocio B crea otra, esta se convierte en Venta #2 en la BD. Esto **confunde al usuario** porque espera que cada negocio empiece desde #1. Además, funciones internas como cuotas, pagos y analíticas dependen del `id` para cálculos, y al tomar un ID global, pueden accidentalmente capturar datos de otro negocio si las consultas no filtran correctamente.

**Solución**: Agregar un campo `numero_secuencial` a las tablas `ventas` y `smart_quotations`. Este campo será auto-calculado **por negocio** (MAX+1 WHERE negocio_id = X) y será el que se muestre al usuario como "#00001". El `id` interno de SQLite seguirá existiendo para las relaciones de Foreign Key, pero jamás se mostrará al usuario.

### Problema 2: Consultas Sin Filtro de `negocio_id` (Fuga de Datos)
Encontré **consultas críticas que NO filtran por `negocio_id`**, lo que provoca que un negocio vea datos de otro:

| Archivo | Línea | Query | Problema |
|---------|-------|-------|----------|
| [notification_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/providers/notification_provider.dart) | L85-93 | `FROM cuotas c INNER JOIN ventas v...` | ⚠️ **NO filtra `v.negocio_id`**. Las alertas de cuotas vencidas de TODOS los negocios se mezclan. |
| [notification_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/providers/notification_provider.dart) | L49-56 | `FROM presentaciones_producto WHERE activo = 1 GROUP BY producto_id` | ⚠️ **NO filtra por negocio**. Los productos "resueltos" de todos los negocios se evalúan juntos. |
| [sale_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/sale_provider.dart) | L97-104 | `loadCurrentMonthMargin()` | ⚠️ Usa `v.archivada = 0` en vez de `v.is_archived = 0` (columna incorrecta), y la subconsulta `SELECT costo FROM productos` no existe como columna. Esta función probablemente **crashea silenciosamente** y devuelve 0. |

### Problema 3: Migraciones Acumuladas (19 versiones)
La BD tiene 19 versiones de migración incremental con `ALTER TABLE` dispersos. Esto:
- Hace que el código sea difícil de mantener y auditar.
- Introduce riesgo de errores acumulados en instalaciones que saltaron versiones.

**Solución**: Consolidar TODO el esquema en un único `_createDB()` limpio (versión 1 de la nueva era) y eliminar todas las migraciones antiguas. Solo se mantendrá una migración de upgrade para backups importados.

---

## 🔄 Respuesta a Tu Pregunta Sobre el Backup

> *"¿Puedo ingresar un backup antiguo sin que haya problemas?"*

**Sí, es factible y seguro**, pero con una condición técnica que implementaré automáticamente:

### ¿Por qué funciona?
1. Tu backup antiguo es un archivo `.db` de SQLite completo. Cuando lo restauras, **reemplaza por completo** la base de datos nueva. Esto significa que el esquema que se carga es el del backup, no el de la app nueva.
2. Sin embargo, al abrir la app después de restaurar, el sistema `onUpgrade` de SQLite detectará que la versión del backup (v19 antigua) es **menor** que la versión de la app nueva, y ejecutará automáticamente las migraciones necesarias.

### Lo que implementaré para garantizar seguridad:
1. **Migración de compatibilidad (`onUpgrade`)**: Cuando la app detecte un backup antiguo (versión < la nueva), ejecutará una migración especial que:
   - Agrega las columnas `numero_secuencial` a `ventas` y `smart_quotations`.
   - Recalcula los valores de `numero_secuencial` basándose en el orden cronológico existente por negocio.
   - Como en tu caso solo tienes un negocio con datos, los IDs existentes se mapearán directamente (ID 1 → Secuencial #1, ID 2 → #2, etc.), así que **no perderás la numeración actual**.

2. **Validación en `restoreBackup()`**: Después de restaurar, la app forzará la reapertura de la BD para que `onUpgrade` se ejecute y aplique la migración de compatibilidad.

> [!IMPORTANT]
> **Flujo recomendado**: Crea tu backup → Desinstala la app → Instala la nueva versión → Abre la app (se crea la BD limpia) → Restaura el backup → La migración de compatibilidad se ejecuta automáticamente → Todos tus datos históricos estarán intactos y con IDs secuenciales correctos.

---

## 🔧 Propuesta de Cambios por Fase

### Fase 1: Reestructuración de la Base de Datos

#### [MODIFY] [local_db.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/database/local_db.dart)
- **Resetear la versión a `1`** (nueva era limpia).
- **Consolidar `_createDB()`**: Mantener exactamente el mismo esquema de tablas actual, pero agregando las nuevas columnas `numero_secuencial` a `ventas` y `smart_quotations` directamente en el `CREATE TABLE`.
- **Eliminar TODAS las migraciones antiguas** (v1→v19). El método `_onUpgrade` quedará con una única migración de compatibilidad que detecta backups pre-reestructuración y aplica los cambios necesarios.
- **Agregar columna `numero_secuencial`** a:
  - `ventas`: `numero_secuencial INTEGER` (sin AUTOINCREMENT, calculado por lógica de negocio).
  - `smart_quotations`: `numero_secuencial INTEGER` (mismo concepto).

---

### Fase 2: Capa de Servicio — Generación de IDs Secuenciales

#### [MODIFY] [sale_repository.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/repositories/sale_repository.dart)
- Agregar método `getNextSequentialNumber(int negocioId)` que ejecute:
  ```sql
  SELECT COALESCE(MAX(numero_secuencial), 0) + 1 FROM ventas WHERE negocio_id = ?
  ```
- Esto garantiza que cada negocio tenga su propia secuencia independiente (#1, #2, #3...).

#### [MODIFY] Servicio de ventas (archivo que ejecuta el INSERT de ventas)
- Antes de cada `INSERT INTO ventas`, invocar `getNextSequentialNumber()` e incluir el resultado en el campo `numero_secuencial`.
- Mismo patrón para `smart_quotations`.

---

### Fase 3: Capa de UI — Mostrar IDs Contextuales

#### [MODIFY] Widgets que muestran `#${sale.id}` o `#${quotation.id}`
Archivos afectados:
- [quotation_card.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/quotation_card.dart) (L146, L164)
- [sales_list_builder.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/history/sales_list_builder.dart) (L80)
- [sale_action_bottom_sheet.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/history/sale_action_bottom_sheet.dart) (L193)
- [client_sales_history_tab.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/crm/client_sales_history_tab.dart) (L86)
- [general_preview_tab.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/crm/general_preview_tab.dart) (L54, L67)
- [payment_entry_modal.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/crm/payment_entry_modal.dart) (L346, L351)
- [client_quotations_tab.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/crm/client_quotations_tab.dart) (L70)

**Cambio**: Reemplazar `sale.id` por `sale.sequentialNumber` (o `quotation.sequentialNumber`), con fallback a `sale.id` si el campo es null (compatibilidad con datos pre-migración).

#### [MODIFY] Modelos de datos
- [smart_quotation_model.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/models/smart_quotation_model.dart): Agregar campo `sequentialNumber` al modelo `SmartQuotationModel` y `SaleModel`.

---

### Fase 4: Corrección de Fugas de Datos (Queries Sin Filtro)

#### [MODIFY] [notification_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/providers/notification_provider.dart)
- **L85-93** (`generateAutoNotifications`): Agregar `AND v.negocio_id = ?` al WHERE de la query de cuotas vencidas, pasando `_negocioId` como argumento.
- **L49-56** (`fetchNotifications`): Agregar JOIN con `productos` y filtrar `WHERE p.negocio_id = ?` en la subquery de presentaciones resueltas.

#### [MODIFY] [sale_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/sale_provider.dart)
- **L97-104** (`loadCurrentMonthMargin`): Corregir la columna `v.archivada` → `v.is_archived`, y reemplazar la subconsulta inexistente `SELECT costo FROM productos` por `COALESCE(i.original_unit_price, i.precio_unitario)` que sí existe en `venta_items`.

---

### Fase 5: Backup — Compatibilidad con Restauración

#### [MODIFY] [backup_manager.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/utils/backup_manager.dart)
- Después de `await backupFile.copy(currentDbFile.path)`, agregar una reapertura forzada de la BD con `LocalDatabase.instance.closeConnection()` seguido de un acceso a `LocalDatabase.instance.database` para forzar que `onUpgrade` se ejecute y aplique las migraciones de compatibilidad al backup restaurado.

#### [MODIFY] [local_db.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/database/local_db.dart) (en `_onUpgrade`)
- Implementar la migración de compatibilidad que:
  1. Detecta si las columnas `numero_secuencial` existen (backup antiguo no las tiene).
  2. Si no existen, las agrega con `ALTER TABLE`.
  3. Recalcula `numero_secuencial` usando `ROW_NUMBER() OVER (PARTITION BY negocio_id ORDER BY fecha_venta ASC)`.

---

## ✅ Plan de Verificación

### Verificación Automatizada
- `flutter build apk --release` para confirmar compilación exitosa.

### Verificación Manual (Te la pediré)
1. **Crear Negocio A** → Crear 2 ventas → Verificar que se muestran como #00001 y #00002.
2. **Cambiar a Negocio B** (nuevo) → Crear 1 venta → Verificar que se muestra como #00001 (no #00003).
3. **Verificar que Negocio B** no muestra las ventas, cotizaciones ni clientes de Negocio A.
4. **Verificar notificaciones**: Solo deben aparecer alertas de cuotas vencidas del negocio activo.
5. **Restaurar backup antiguo** → Verificar que los datos se cargan correctamente y los IDs secuenciales se calculan retroactivamente.

---

## ⚠️ Preguntas Abiertas

> [!IMPORTANT]
> **Formato de ID visible al usuario**: ¿Prefieres que el número secuencial se muestre como `#00001` (con ceros, 5 dígitos) o simplemente `#1`? Actualmente el código usa `padLeft(5, '0')` en ventas pero `${quotation.id}` sin padding en cotizaciones. ¿Unificamos a uno solo?

> [!IMPORTANT]
> **Alcance de la secuencia**: ¿Quieres que la secuencia sea independiente para ventas y cotizaciones? Es decir, ¿la primera venta es #1 y la primera cotización también es #1? ¿O prefieres una secuencia global por negocio donde la primera cotización sea #1 y la primera venta sea #2?
