# 🐛 Informe de Errores y Problemas Encontrados
## MochilaLista App v2.0 - Branch `feature/version-offline`

---

## 🔴 ERRORES CRÍTICOS (Afectan funcionalidad)

### ERR-001: Backend Python es código muerto (Dead Code)
- **Severidad:** Alta (mantenibilidad)
- **Ubicación:** Carpeta `backend/` completa (70 archivos Python)
- **Descripción:** El backend FastAPI con 22 endpoints, PostgreSQL, Docker y toda la infraestructura sigue en el repositorio, pero la app Flutter ya no lo consume. Todos los servicios operan contra SQLite local.
- **Impacto:** 
  - Confusión para nuevos desarrolladores
  - Mantenimiento innecesario de Docker/PostgreSQL
  - `requirements.txt` sin versiones pinned (puede romperse en cualquier momento)
  - Tamaño innecesario del repositorio
- **Recomendación:** Mover a un branch `archive/backend-legacy` o eliminar y documentar que era la v1

---

### ERR-002: Uso masivo de `.withOpacity()` deprecado
- **Severidad:** Media-Alta (warnings en compilación)
- **Ubicación:** 70+ archivos `.dart` usan `Colors.xxx.withOpacity()`
- **Descripción:** En Flutter 3.x, `Color.withOpacity()` está deprecado en favor de `Color.withValues(alpha: x)`. Esto genera cientos de warnings en la consola durante la compilación.
- **Impacto:** Ruido en consola, futuras incompatibilidades con Flutter 4.x
- **Recomendación:** Migrar a `Colors.xxx.withValues(alpha: 0.x)` o usar `Color.fromRGBO()`

---

### ERR-003: `requirements.txt` sin versiones pinned
- **Severidad:** Alta (si el backend se usa algún día)
- **Ubicación:** `backend/requirements.txt`
- **Descripción:** Todas las dependencias están sin versión:
  ```
  fastapi        # Sin versión
  sqlalchemy     # Sin versión
  pydantic       # Sin versión
  google-genai   # Sin versión
  ```
- **Impacto:** Build no reproducible. Docker puede instalar versiones incompatibles en cualquier momento.
- **Recomendación:** Pinear versiones: `fastapi==0.115.0`, `sqlalchemy==2.0.30`, etc.

---

### ERR-004: `datetime.utcnow()` deprecado en Python
- **Severidad:** Media
- **Ubicación:** `backend/app/core/security.py` (líneas 12, 14, 24, 26)
- **Descripción:** `datetime.utcnow()` está deprecado desde Python 3.12. Debe usarse `datetime.now(datetime.UTC)`.
- **Impacto:** Warnings en Python 3.12+, posible error en Python 4.x

---

### ERR-005: Falta archivo `.env` y `.env.example`
- **Severidad:** Alta (DX - Developer Experience)
- **Ubicación:** Raíz del proyecto y `app_movil/`
- **Descripción:** No existe un `.env.example` que documente las variables requeridas. El `pubspec.yaml` declara `.env` como asset de Flutter, pero el archivo no existe en el repositorio.
- **Variables necesarias (deducidas del código):**
  ```env
  # Flutter (app_movil/.env)
  GOOGLE_API_KEY=tu_api_key_de_google_gemini
  
  # Backend (.env en raíz)
  DB_USER=postgres
  DB_PASSWORD=tu_password
  DB_NAME=mochilalista_bd
  DB_HOST=db
  SECRET_KEY=clave_secreta_jwt
  GOOGLE_API_KEY=api_key_gemini
  CLOUDINARY_CLOUD_NAME=
  CLOUDINARY_API_KEY=
  CLOUDINARY_API_SECRET=
  CORS_ORIGINS=http://localhost
  ```
- **Recomendación:** Crear `.env.example` en ambas ubicaciones

---

### ERR-006: Credenciales hardcodeadas en `docker-compose.yml`
- **Severidad:** Media
- **Ubicación:** `docker-compose.yml` (líneas 28-29)
- **Descripción:**
  ```yaml
  PGADMIN_DEFAULT_EMAIL: admin@mochilalista.com
  PGADMIN_DEFAULT_PASSWORD: admin
  ```
- **Impacto:** Credenciales expuestas en repositorio público
- **Recomendación:** Mover a variables de entorno

---

### ERR-007: Secret Key hardcodeada como fallback
- **Severidad:** Alta (seguridad)
- **Ubicación:** `backend/app/core/config.py` (línea 9)
- **Descripción:**
  ```python
  SECRET_KEY: str = os.getenv("SECRET_KEY", "ESTA_ES_UNA_CLAVE_SUPER_SECRETA_CAMBIALA_EN_PRODUCCION")
  ```
- **Impacto:** Si no se configura `.env`, el JWT usa una clave conocida públicamente.
- **Recomendación:** Eliminar el fallback, forzar configuración explícita

---

## 🟡 PROBLEMAS DE DISEÑO (Afectan mantenibilidad)

### DES-001: Providers monolíticos excesivamente grandes
- **Severidad:** Media (mantenibilidad)
- **Descripción:** Varios providers son demasiado grandes para un solo archivo:
  | Provider | Líneas | Responsabilidades |
  |----------|--------|-------------------|
  | `scanner_provider.dart` | 587 | Escaneo IA + matching + staging + batch save |
  | `inventory_provider.dart` | 430 | CRUD productos + filtros + sort + master data |
  | `catalog_provider.dart` | 414 | Catálogo + carrito + utilidad + filtros |
- **Recomendación:** Aplicar separación de responsabilidades. Por ejemplo, extraer `BatchSaveService` del `ScannerProvider`

---

### DES-002: Consultas SQL construidas con concatenación de strings
- **Severidad:** Media (seguridad + mantenibilidad)
- **Ubicación:** `product_service.dart`, `scanner_provider.dart`, `master_data_service.dart`
- **Descripción:** Las queries SQL se construyen con concatenación de strings:
  ```dart
  query += " AND (p.nombre LIKE ? OR pr.codigo_barras LIKE ?)";
  ```
  Si bien los valores se pasan como `?` (parameterizados), la estructura de la query se construye dinámicamente, lo que es difícil de mantener y testear.
- **Recomendación:** Crear un `QueryBuilder` o usar un patrón Repository más limpio

---

### DES-003: Duplicación de queries SQL entre Scanner y Product Service
- **Severidad:** Media
- **Descripción:** La query para obtener productos con presentaciones está **duplicada exactamente** en:
  - `product_service.dart` (líneas 18-28)
  - `scanner_provider.dart` (líneas 94-105)
  Ambas construyen el mismo JOIN de 26 columnas.
- **Recomendación:** Extraer a un método compartido o constante SQL

---

### DES-004: Ausencia total de tests
- **Severidad:** Alta
- **Descripción:** El proyecto tiene 186 archivos Dart y 70 archivos Python, pero **cero tests unitarios, de integración o de widgets**. La carpeta `test/` de Flutter está vacía.
- **Impacto:** No hay red de seguridad para refactorizaciones. Cualquier cambio puede romper funcionalidad sin ser detectado.

---

### DES-005: Archivos de pantalla excesivamente grandes
- **Severidad:** Media
- **Descripción:** Varias pantallas superan las 500+ líneas:
  | Archivo | Líneas |
  |---------|--------|
  | `staging_product_group_card.dart` | ~1300 |
  | `sale_history_detail_screen.dart` | ~900 |
  | `manual_quotation_screen.dart` | ~900 |
  | `quotation_detail_screen.dart` | ~850 |
  | `product_edit_screen.dart` | ~850 |
  | `matching_screen.dart` | ~800 |
  | `whatsapp_preview_screen.dart` | ~770 |
- **Recomendación:** Extraer widgets internos a archivos separados

---

### DES-006: `print()` en lugar de `debugPrint()` en producción
- **Severidad:** Baja
- **Ubicación:** `product_service.dart` (líneas 81, 144, 197), `master_data_service.dart` (línea 46)
- **Descripción:** Uso de `print()` que sale en release builds. Debe usarse `debugPrint()` que solo aparece en debug.
- **Recomendación:** Reemplazar todos los `print()` por `debugPrint()`

---

### DES-007: Manejo de errores silencioso (catch vacíos)
- **Severidad:** Media-Alta
- **Ubicación:** Múltiples servicios y providers
- **Descripción:** Muchos catches retornan `false` o `null` sin logging:
  ```dart
  } catch (e) { return false; }     // product_service.dart
  } catch (e) { return null; }      // scanner_provider.dart
  } catch (_) { return ""; }        // inventory_provider.dart
  ```
- **Impacto:** Errores silenciados que son imposibles de diagnosticar en producción.
- **Recomendación:** Agregar `debugPrint` y considerar un servicio de logging centralizado

---

## 🟠 PROBLEMAS DE RENDIMIENTO

### PERF-001: No hay índices SQLite explícitos
- **Severidad:** Media (puede empeorar con datos grandes)
- **Ubicación:** `local_db.dart` - `_createDB()`
- **Descripción:** Las 13 tablas se crean sin índices. Las consultas más frecuentes son:
  - `WHERE p.negocio_id = ? AND pr.activo = 1` (inventario)
  - `WHERE negocio_id = ? AND nombre LIKE ?` (búsqueda)
  - `WHERE pr.codigo_barras = ? OR p.codigo_barras = ?` (escáner)
- **Impacto:** A medida que crecen los datos, las queries se vuelven lentas.
- **Recomendación:** Crear índices en columnas `negocio_id`, `categoria_id`, `marca_id`, `codigo_barras`

---

### PERF-002: Ordenamiento en memoria del catálogo
- **Severidad:** Baja-Media
- **Ubicación:** `catalog_provider.dart` (líneas 213-218)
- **Descripción:** Después de cargar items del catálogo, se re-ordena toda la lista en memoria:
  ```dart
  _displayItems.sort((a, b) => ...);
  ```
  Esto debería hacerse en la query SQL (`ORDER BY p.nombre ASC`).
- **Recomendación:** Mover el sort a la query SQL

---

### PERF-003: Carga duplicada de MasterData
- **Severidad:** Baja
- **Ubicación:** `CatalogProvider` y `InventoryProvider` tienen cada uno su propia instancia de `MasterDataService`
- **Descripción:** Ambos providers cargan categorías/marcas/proveedores independientemente, potencialmente en paralelo.
- **Recomendación:** Compartir una caché centralizada de datos maestros

---

## 🔵 OBSERVACIONES DE UX/UI

### UX-001: NavigationBar no persiste estado entre tabs
- **Severidad:** Baja
- **Descripción:** `IndexedStack` mantiene el estado de cada tab, lo cual es correcto. Sin embargo, al volver al tab de Inicio se recarga el dashboard completo incluyendo `refreshActiveUser()`, lo que puede sentirse lento.

### UX-002: Verificación de internet solo para IA
- **Severidad:** Baja
- **Ubicación:** `hardware_validator.dart`
- **Descripción:** La verificación de internet (`connectivity_plus`) solo se usa antes de llamadas IA, pero no hay un indicador global de conexión/desconexión en la app.

### UX-003: Lock Screen tiene un delay de gracia de 1 minuto
- **Severidad:** Informativo
- **Ubicación:** `home_screen.dart` (línea 53)
- **Descripción:** Si el usuario sale de la app y regresa en menos de 1 minuto, no se le pide PIN. Esto es un buen diseño UX pero debería ser configurable.

---

## 📝 Paquetes No Utilizados (Dead Dependencies)

Basándome en el análisis del código, estos paquetes en `pubspec.yaml` **no se usan activamente** en la versión offline:

| Paquete | Propósito original | Estado |
|---------|-------------------|--------|
| `http` | Llamadas HTTP al backend Python | ❌ No usado |
| `dio` | Cliente HTTP avanzado | ❌ No usado |
| `flutter_map` | Mapas OpenStreetMap | ⚠️ Solo en `map_picker_screen.dart` |
| `latlong2` | Coordenadas para mapas | ⚠️ Solo en `map_picker_screen.dart` |
| `blue_thermal_printer` | Impresión Bluetooth | ⚠️ Solo en `printer_config_screen.dart` |
| `multi_split_view` | Split view layout | ❓ No verificado |
| `local_auth` | Biometría | ❓ No verificado uso actual |

---

## Siguiente Documento
→ Ver **03_PLAN_DE_TRABAJO.md** para el plan de mejoras y perfeccionamiento detallado.
