# 🗺️ Plan de Trabajo - MochilaLista App v2.0
## Perfeccionamiento, Corrección de Errores y Optimización

---

## 📋 Organización del Plan

El plan se divide en **6 Fases** ordenadas por prioridad y dependencia. Cada fase es un bloque ejecutable de forma independiente, y cada tarea tiene una descripción técnica de qué se hará y por qué.

---

## 🔥 FASE 1: Limpieza Crítica y Estabilización
> **Objetivo:** Eliminar código muerto, corregir errores de compilación y preparar el proyecto para ser mantenible.
> **Tiempo estimado:** 2-3 horas
> **Riesgo:** Bajo (cambios seguros, no tocan lógica de negocio)

### Tarea 1.1: Crear archivos `.env.example`
- **Qué se hará:** Crear `app_movil/.env.example` y `.env.example` en la raíz con todas las variables de entorno documentadas
- **Por qué:** Sin esto, cualquier developer que clone el proyecto no sabe qué variables necesita. El `pubspec.yaml` referencia `.env` como asset pero el archivo no existe
- **Archivos afectados:**
  - `[NUEVO] app_movil/.env.example`
  - `[NUEVO] .env.example`

### Tarea 1.2: Migrar `withOpacity()` a API moderna
- **Qué se hará:** Reemplazar todas las llamadas a `.withOpacity(x)` por `.withValues(alpha: x)` en los 70+ archivos afectados
- **Por qué:** `withOpacity` está deprecado en Flutter 3.x y genera cientos de warnings que ocultan errores reales
- **Archivos afectados:** 70+ archivos `.dart`
- **Herramienta:** Se puede automatizar con find & replace regex

### Tarea 1.3: Reemplazar `print()` por `debugPrint()`
- **Qué se hará:** Buscar todas las instancias de `print(` en el proyecto Flutter y reemplazar por `debugPrint(`
- **Por qué:** `print()` aparece en builds de producción y consume recursos. `debugPrint()` es eliminado en release.
- **Archivos afectados:** `product_service.dart`, `master_data_service.dart`, y otros

### Tarea 1.4: Eliminar dependencias no utilizadas del `pubspec.yaml`
- **Qué se hará:** Verificar y remover paquetes muertos que ya no se usan:
  - `http` (reemplazado por acceso directo a SQLite)
  - `dio` (nunca usado en la versión offline)
- **Por qué:** Reducir tamaño del APK y tiempo de compilación
- **Archivos afectados:** `pubspec.yaml`, `pubspec.lock`

### Tarea 1.5: Documentar el estado del backend Python
- **Qué se hará:** Crear un `backend/README.md` explicando que el backend es código legacy de la v1.0, que la app ahora funciona offline-first, y que el backend se mantiene como referencia para futura implementación de sincronización en la nube
- **Por qué:** Evitar confusión sobre qué código está activo
- **Archivos afectados:**
  - `[NUEVO] backend/README.md`
  - `[MODIFICAR] README.md` principal (aclarar el estado actual)

---

## 🛡️ FASE 2: Seguridad y Robustez
> **Objetivo:** Fortalecer el manejo de errores, seguridad de datos y estabilidad de la app.
> **Tiempo estimado:** 3-4 horas
> **Riesgo:** Bajo-Medio (mejoras en manejo de errores sin cambiar lógica)

### Tarea 2.1: Implementar manejo de errores centralizado
- **Qué se hará:** Crear una clase `AppLogger` que reemplace los catches vacíos con logging estructurado:
  ```dart
  class AppLogger {
    static void error(String context, dynamic error, [StackTrace? stack]) {
      debugPrint("[$context] ERROR: $error");
      if (stack != null) debugPrint(stack.toString());
    }
    static void info(String context, String message) {
      debugPrint("[$context] $message");
    }
  }
  ```
- **Por qué:** Actualmente hay 30+ catches que silencian errores, haciendo imposible diagnosticar problemas
- **Archivos afectados:**
  - `[NUEVO] lib/utils/app_logger.dart`
  - `[MODIFICAR] Todos los servicios y providers con catches vacíos`

### Tarea 2.2: Mejorar catches silenciosos en servicios
- **Qué se hará:** Reemplazar todos los `catch (e) { return false; }` con logging apropiado y mensajes de error descriptivos
- **Por qué:** Errores que se tragan silenciosamente son la fuente #1 de bugs difíciles de reproducir
- **Archivos afectados:**
  - `product_service.dart` (4 catches vacíos)
  - `master_data_service.dart` (1 catch vacío)
  - `scanner_provider.dart` (2 catches vacíos)
  - Otros providers

### Tarea 2.3: Validación de integridad en restauración de backup
- **Qué se hará:** Antes de restaurar un backup `.db`, validar:
  1. Que el archivo no esté corrupto (verificar header SQLite)
  2. Que tenga las tablas esperadas
  3. Crear backup automático antes de sobreescribir
- **Por qué:** Actualmente `restoreBackup()` sobrescribe la BD sin verificar integridad. Si el archivo es corrupto, se pierde toda la data.
- **Archivos afectados:** `backup_manager.dart`

### Tarea 2.4: Agregar confirmación de operaciones destructivas
- **Qué se hará:** Verificar que todas las operaciones de eliminación (borrar perfil, borrar producto, restaurar backup) tengan doble confirmación con dialog apropiado
- **Por qué:** Prevenir pérdida accidental de datos

---

## ⚡ FASE 3: Optimización de Rendimiento y Memoria
> **Objetivo:** Reducir consumo de memoria, mejorar velocidad de queries y optimizar el tamaño del APK.
> **Tiempo estimado:** 4-5 horas
> **Riesgo:** Medio (cambios en queries y estructura de datos)

### Tarea 3.1: Crear índices SQLite para consultas frecuentes
- **Qué se hará:** Agregar índices en `_createDB()` y en una nueva migración (v5):
  ```sql
  CREATE INDEX idx_productos_negocio ON productos(negocio_id);
  CREATE INDEX idx_productos_categoria ON productos(categoria_id);
  CREATE INDEX idx_productos_marca ON productos(marca_id);
  CREATE INDEX idx_presentaciones_producto ON presentaciones_producto(producto_id);
  CREATE INDEX idx_presentaciones_barcode ON presentaciones_producto(codigo_barras);
  CREATE INDEX idx_presentaciones_estado ON presentaciones_producto(estado, activo);
  CREATE INDEX idx_ventas_negocio ON ventas(negocio_id);
  CREATE INDEX idx_ventas_cliente ON ventas(cliente_id);
  CREATE INDEX idx_clientes_negocio ON clientes(negocio_id);
  CREATE INDEX idx_quotations_negocio ON smart_quotations(negocio_id);
  ```
- **Por qué:** Las queries principales hacen JOINs entre productos y presentaciones filtrados por negocio_id. Sin índices, SQLite escanea todas las filas.
- **Impacto esperado:** Mejora de 2-5x en velocidad de queries con catálogos de 500+ productos
- **Archivos afectados:** `local_db.dart`

### Tarea 3.2: Eliminar duplicación de queries SQL
- **Qué se hará:** Extraer las queries SQL compartidas entre `product_service.dart` y `scanner_provider.dart` a una clase `ProductQueries`:
  ```dart
  class ProductQueries {
    static const String inventoryJoin = '''
      SELECT p.*, pr.id AS pres_id, pr.nombre_especifico, ...
      FROM presentaciones_producto pr
      INNER JOIN productos p ON pr.producto_id = p.id
      WHERE p.negocio_id = ? AND pr.activo = 1
    ''';
  }
  ```
- **Por qué:** La query de 26 columnas está duplicada en 2 archivos. Un cambio en uno puede olvidarse en el otro.
- **Archivos afectados:**
  - `[NUEVO] lib/database/product_queries.dart`
  - `product_service.dart`
  - `scanner_provider.dart`

### Tarea 3.3: Mover ordenamiento del catálogo a SQL
- **Qué se hará:** Reemplazar el sort en memoria del `CatalogProvider` con `ORDER BY` en la query SQL
- **Por qué:** Ordenar 1000+ items en Dart es más lento que en SQLite
- **Archivos afectados:** `catalog_provider.dart`, `product_service.dart`

### Tarea 3.4: Optimizar procesamiento de imágenes
- **Qué se hará:** Revisar `ImageService` para asegurar:
  1. Compresión de imágenes antes de guardar (reducir a 800px max)
  2. Cache de thumbnails para listas
  3. Limpieza de imágenes huérfanas periódicamente
- **Por qué:** Las fotos de productos pueden crecer rápidamente y consumir almacenamiento del celular
- **Archivos afectados:** `image_service.dart`, potencialmente nuevo `image_cache_manager.dart`

### Tarea 3.5: Caché centralizada de datos maestros
- **Qué se hará:** Crear un singleton `MasterDataCache` que comparta categorías/marcas/proveedores entre `InventoryProvider` y `CatalogProvider`
- **Por qué:** Actualmente ambos providers cargan los mismos datos de forma independiente, desperdiciando memoria y queries
- **Archivos afectados:**
  - `[NUEVO] lib/services/master_data_cache.dart`
  - `catalog_provider.dart`
  - `inventory_provider.dart`

---

## 🏗️ FASE 4: Refactorización Arquitectural
> **Objetivo:** Separar responsabilidades, reducir el tamaño de archivos grandes y mejorar la testabilidad.
> **Tiempo estimado:** 6-8 horas
> **Riesgo:** Medio-Alto (reestructuración significativa, requiere testing manual)

### Tarea 4.1: Descomponer `ScannerProvider` (587 líneas)
- **Qué se hará:** Separar en 3 clases especializadas:
  1. `ScannerAIService` - Comunicación con Gemini y parsing de respuesta
  2. `ScannerMatchingEngine` - Lógica de matching contra SQLite
  3. `ScannerBatchSaver` - Transacción de guardado masivo
  El `ScannerProvider` se convierte en coordinador que usa estos 3 servicios.
- **Por qué:** Un provider de 587 líneas con IA + matching + staging + batch save viola el principio de responsabilidad única
- **Archivos afectados:**
  - `scanner_provider.dart`
  - `[NUEVO] lib/services/scanner_ai_service.dart`
  - `[NUEVO] lib/services/scanner_matching_engine.dart`
  - `[NUEVO] lib/services/scanner_batch_saver.dart`

### Tarea 4.2: Descomponer widgets gigantes
- **Qué se hará:** Extraer sub-widgets de los archivos más grandes:
  - `staging_product_group_card.dart` (~1300 líneas) → 4-5 widgets menores
  - `product_action_sheet.dart` (~800 líneas) → 3-4 widgets
  - `product_edit_screen.dart` (~850 líneas) → Extraer formularios
- **Por qué:** Archivos de 800-1300 líneas son imposibles de mantener y causan scroll interminable
- **Archivos afectados:** Los mencionados arriba + nuevos archivos de widgets

### Tarea 4.3: Implementar patrón Repository
- **Qué se hará:** Crear una capa de repositorio entre providers y la base de datos:
  ```
  Provider → Repository → LocalDatabase (SQLite)
                        → RemoteAPI (futuro)
  ```
  Esto prepara la app para futura sincronización con servidor.
- **Por qué:** Los providers acceden directamente a `LocalDatabase.instance`, creando acoplamiento fuerte. Un repositorio abstrae la fuente de datos.
- **Archivos afectados:**
  - `[NUEVO] lib/repositories/product_repository.dart`
  - `[NUEVO] lib/repositories/client_repository.dart`
  - `[NUEVO] lib/repositories/sale_repository.dart`
  - Refactorizar servicios existentes

### Tarea 4.4: Organizar features con estructura consistente
- **Qué se hará:** Mover las pantallas de `screens/scanner/` y `screens/tabs/` a `features/`:
  ```
  features/
  ├── auth/          # Onboarding + Lock Screen
  ├── inventory/     # Inventario + Tabs (productos, categorías, marcas, proveedores)
  ├── scanner/       # Escaneo de facturas + staging + review
  ├── catalog/       # Catálogo público + carrito
  ├── smart_quotation/ # (ya existe - cotizaciones, ventas, CRM)
  └── profile/       # (ya existe - perfil, backup, equipo)
  ```
- **Por qué:** La organización actual mezcla features con screens generales. `screens/scanner/` debería ser un feature.

---

## 🎨 FASE 5: Mejoras de UX/UI
> **Objetivo:** Pulir la experiencia del usuario, agregar feedback visual y mejorar accesibilidad.
> **Tiempo estimado:** 3-4 horas
> **Riesgo:** Bajo (mejoras visuales sin impacto en lógica)

### Tarea 5.1: Indicador global de conectividad
- **Qué se hará:** Agregar un banner sutil en la parte superior de la app que muestra "Sin Internet" cuando no hay conexión. Útil para funciones que requieren IA.
- **Por qué:** `connectivity_plus` ya está instalado pero solo se usa puntualmente en `hardware_validator.dart`
- **Archivos afectados:**
  - `home_screen.dart`
  - Potencialmente nuevo widget `connectivity_banner.dart`

### Tarea 5.2: Delay de gracia configurable para PIN
- **Qué se hará:** Hacer que el tiempo de 1 minuto antes de pedir PIN sea configurable (1, 5, 15 minutos, inmediato)
- **Por qué:** Actualmente está hardcodeado en 1 minuto. Un vendedor que alterna entre app y otra cosa se bloquea frecuentemente.
- **Archivos afectados:** `home_screen.dart`, `backup_screen.dart` (settings), `SharedPreferences`

### Tarea 5.3: Feedback visual durante operaciones largas
- **Qué se hará:** Agregar indicadores de progreso con mensajes descriptivos durante:
  - Escaneo IA (ya tiene `statusMessage` pero puede ser más descriptivo)
  - Batch save de inventario
  - Exportación de backup a Google Drive
  - Generación de PDF
- **Por qué:** Las operaciones de IA pueden tardar 10-30 segundos. El usuario necesita saber que algo está pasando.

### Tarea 5.4: Empty states mejorados
- **Qué se hará:** Diseñar estados vacíos con ilustraciones y mensajes motivadores para:
  - Inventario vacío (primer uso)
  - Sin cotizaciones
  - Sin clientes registrados
  - Sin historial de ventas
- **Por qué:** Un estado vacío con solo texto gris es desmoralizante para un usuario nuevo

### Tarea 5.5: Mejorar el tema oscuro
- **Qué se hará:** Revisar y ajustar colores del tema oscuro en:
  - Cards (actualmente `Color(0xFF23232F)` - verificar contraste)
  - Bordes y separadores
  - Colores de acento y estados de botones
- **Archivos afectados:** `main.dart` (theme), `theme_provider.dart`

---

## 📄 FASE 6: Documentación y DevOps
> **Objetivo:** Documentar la arquitectura, crear tests básicos y mejorar el workflow de desarrollo.
> **Tiempo estimado:** 3-4 horas
> **Riesgo:** Bajo (no afecta funcionalidad)

### Tarea 6.1: Actualizar README.md principal
- **Qué se hará:** Actualizar el README para reflejar:
  - Que la app es offline-first
  - Que el backend es legacy/referencia
  - Screenshots reales (reemplazar URLs placeholder)
  - Instrucciones de ejecución actualizadas
  - Diagrama de arquitectura con Mermaid
- **Archivos afectados:** `README.md`

### Tarea 6.2: Crear documentación de arquitectura
- **Qué se hará:** Crear `docs/ARCHITECTURE.md` con:
  - Diagrama de flujo de datos
  - Esquema de base de datos (ERD)
  - Mapa de providers y sus dependencias
  - Flujos de usuario principales
- **Archivos afectados:** `[NUEVO] docs/ARCHITECTURE.md`

### Tarea 6.3: Agregar tests unitarios básicos
- **Qué se hará:** Crear tests para las funciones más críticas:
  - `UserModel.fromJson()` / `toSqlite()`
  - `Product.fromJson()` / `ProductPresentation.fromJson()`
  - `CartItem.subtotal` cálculos
  - `normalizeText()` en catalog_provider
- **Por qué:** Cubrir al menos las funciones de serialización/deserialización que son la base de toda la app
- **Archivos afectados:** `[NUEVO] test/` con tests unitarios

### Tarea 6.4: Crear `.gitignore` robusto
- **Qué se hará:** Verificar y mejorar los `.gitignore` para asegurar que no se suban:
  - Archivos `.env` con secrets
  - Builds de Flutter
  - Archivos de IDE
  - Base de datos local
- **Archivos afectados:** `.gitignore`, `app_movil/.gitignore`, `backend/.gitignore`

### Tarea 6.5: Pinear versiones en `requirements.txt`
- **Qué se hará:** Actualizar `backend/requirements.txt` con versiones explícitas:
  ```
  fastapi==0.115.0
  uvicorn==0.30.0
  sqlalchemy==2.0.30
  pydantic==2.7.0
  pydantic-settings==2.3.0
  ...
  ```
- **Por qué:** Build reproducible. Sin versiones, cada `pip install` puede instalar versiones incompatibles.

---

## 📊 Resumen de Prioridades

| Fase | Prioridad | Horas est. | Impacto | Riesgo |
|------|----------|------------|---------|--------|
| **F1: Limpieza Crítica** | 🔴 Urgente | 2-3h | Alto | Bajo |
| **F2: Seguridad** | 🟠 Alta | 3-4h | Alto | Bajo-Medio |
| **F3: Rendimiento** | 🟡 Media | 4-5h | Medio-Alto | Medio |
| **F4: Refactorización** | 🟡 Media | 6-8h | Alto | Medio-Alto |
| **F5: UX/UI** | 🟢 Normal | 3-4h | Medio | Bajo |
| **F6: Documentación** | 🟢 Normal | 3-4h | Medio | Bajo |
| **TOTAL** | | **21-28h** | | |

---

## 🔄 Orden Recomendado de Ejecución

```
F1 (Limpieza) → F2 (Seguridad) → F3 (Rendimiento) → F6 (Docs) → F5 (UX) → F4 (Refactorización)
```

> **Nota:** La Fase 4 (Refactorización) se deja para el final porque es la de mayor riesgo y se beneficia de tener el proyecto ya limpio y documentado. Cada fase puede ejecutarse independientemente tras aprobar este plan.

---

## ⏭️ Próximos Pasos

1. **Revisar este plan** y solicitar modificaciones si es necesario
2. **Aprobar las fases** que quieras ejecutar (todas o seleccionar específicas)
3. **Indicarme que ejecute** y empezaré fase por fase con commits claros
