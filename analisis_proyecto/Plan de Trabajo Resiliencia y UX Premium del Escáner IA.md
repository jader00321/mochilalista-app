# Plan de Trabajo: Resiliencia y UX Premium del Escáner IA

## Resumen del Diagnóstico

Se auditaron **6 archivos** del flujo de escaneo. El módulo tiene **dos flujos paralelos** que usan la misma pantalla (`ScanScreen`):

| Flujo | Servicio IA | Provider | Pantalla Destino |
|---|---|---|---|
| **Cotización** (lista escolar) | `AIExtractionService` | `SmartQuotationProvider` | `ExtractionResultScreen` |
| **Factura** (reposición) | `ScannerAIService` | `ScannerProvider` | `InvoiceReviewScreen` |

Ambos flujos comparten **exactamente los mismos 3 problemas**.

---

## Hallazgos Detallados

### 🔴 PROBLEMA #1: Errores Técnicos al Descubierto

**Archivos afectados**:
- [`scanner_ai_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_ai_service.dart#L49-L52) — Hace `rethrow` del error crudo de Gemini.
- [`ai_extraction_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/ai_extraction_service.dart#L83-L86) — Lanza un `Exception` genérico que envuelve el stack.
- [`scan_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/screens/scan_screen.dart#L124-L138) — Muestra `errorMsg` en un `SnackBar` rojo con el JSON técnico completo.

**Ejemplo real de lo que ve el usuario:**
```
Error: ServerException(message: Resource has been exhausted (e.g. check quota)., 
status: StatusCode.RESOURCE_EXHAUSTED, details: null)
```

**No hay ningún manejo de errores HTTP 503, 429 ni `RESOURCE_EXHAUSTED`.** El SDK `google_generative_ai` lanza `ServerException` con el status, pero ni `ScannerAIService` ni `AIExtractionService` lo interceptan para traducirlo.

---

### 🔴 PROBLEMA #2: Pérdida de Estado (Imagen sin Caché Funcional)

**Archivo afectado**: [`scan_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/screens/scan_screen.dart#L62-L143)

El flujo actual funciona así:
1. Usuario selecciona imagen → `_pickImage()` obtiene un `File`
2. Se muestra el `_ScanningDialog` (modal de carga)
3. Se llama al provider → Si falla, se cierra el dialog y se muestra un `SnackBar`
4. El `SnackBar` tiene un botón "Reintentar" que llama a `_pickImage(source)` **¡lo cual le pide al usuario seleccionar una nueva foto!**

El `File imageFile` es una **variable local** dentro de `_pickImage()`. Si el proceso falla, se pierde. El `ScannerProvider` sí almacena `_currentImage`, pero el `SmartQuotationProvider` también lo hace en `_currentImage`, y **ninguno de los dos se usa para reintentar** desde la UI.

> [!CAUTION]
> **Resultado**: El usuario debe volver a tomar/buscar la foto cada vez que falla. Si fue una foto de cámara, la foto original podría haberse perdido del cache temporal de Android.

---

### 🟡 PROBLEMA #3: Carga Estática e Insuficiente

**Archivo afectado**: [`scan_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/screens/scan_screen.dart#L297-L387) — Clase `_ScanningDialog`

El diálogo de carga actual:
- ✅ Tiene un diseño glassmorphism con blur bonito
- ✅ Tiene un ícono con animación de pulso
- ❌ El texto es **estático**: siempre dice "Leyendo Lista con IA..." o "Analizando Factura..."
- ❌ El `LinearProgressIndicator` es **indeterminado** (no comunica progreso)
- ❌ No hay pasos intermedios que informen al usuario qué está haciendo el sistema
- ❌ Si la IA tarda 8-15 segundos, el usuario **no sabe si la app se colgó** o si está procesando normalmente

---

## Propuesta de Implementación por Fases

### Fase 1: Manejo de Errores IA + Exponential Backoff + Caché de Imagen

#### 1.1 — Exponential Backoff y Traducción de Errores en los Servicios

**Archivos a modificar**:
- [`scanner_ai_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_ai_service.dart)
- [`ai_extraction_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/ai_extraction_service.dart)

**Cambios**:
- Envolver la llamada a `model.generateContent()` en un bucle de reintentos (máximo **1 reintento** con espera de **2 segundos**).
- Interceptar `ServerException` del SDK de Gemini (importado desde `google_generative_ai`):
  - Si el status contiene `RESOURCE_EXHAUSTED`, `UNAVAILABLE`, o el mensaje contiene `503` / `429` → Reintentar automáticamente 1 vez.
  - Si sigue fallando → Lanzar un mensaje **amigable**: `"Los servidores de IA están muy concurridos en este momento. Por favor, intenta de nuevo en unos segundos."`
- Interceptar `SocketException` / `TimeoutException` → `"Sin conexión a Internet. Verifica tu señal y reintenta."`
- Cualquier otro error → `"Ocurrió un error inesperado al procesar la imagen. Intenta con otra foto o reintenta."`

> [!IMPORTANT]
> Usaremos un callback opcional `onRetrying` para que el servicio pueda notificar a la UI cuando está reintentando, y así la pantalla de carga pueda mostrar "Reintentando conexión..." en tiempo real.

#### 1.2 — Caché de Imagen para Reintento Inmediato

**Archivos a modificar**:
- [`scan_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/screens/scan_screen.dart) — Estado `_ScanScreenState`

**Cambios**:
- Agregar una variable de instancia `File? _cachedImageFile` en el State.
- Cuando el usuario selecciona una imagen (cámara o galería), guardar el `File` en `_cachedImageFile` **antes** de enviarla a la IA.
- Crear un nuevo método `_retryWithCachedImage()` que use `_cachedImageFile` directamente, saltándose el `ImagePicker`.
- Crear un nuevo método `_pickNewImage()` que limpie `_cachedImageFile` y vuelva a invocar el picker (para el botón "Escanear una nueva foto").

---

### Fase 2: Rediseño de la UI de Error con Dos Botones

**Archivo a modificar**:
- [`scan_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/screens/scan_screen.dart)

**Cambios**:
- **Eliminar** el `SnackBar` de error actual (líneas 124-138).
- **Reemplazarlo** por un cambio de estado que muestre un **overlay de error premium** integrado en la pantalla (no un snackbar efímero).

**Diseño del Overlay de Error**:
- Fondo semi-transparente con blur.
- Ícono de alerta animado (scale bounce).
- Título: **"No pudimos procesar la imagen"**
- Subtítulo: El mensaje amigable que viene del servicio (ya traducido en Fase 1).
- **Botón Primario**: `"🔄 Reintentar Escaneo"` — Llama a `_retryWithCachedImage()`. Color verde/azul prominente.
- **Botón Secundario**: `"📷 Escanear una nueva foto"` — Llama a `_pickNewImage()`. Color gris/outline discreto.
- Miniatura de la imagen cacheada visible en una esquina (para que el usuario confirme visualmente qué foto se va a re-enviar).

---

### Fase 3: Carga Dinámica y Animaciones por Pasos

**Archivo a modificar**:
- [`scan_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/screens/scan_screen.dart) — Clase `_ScanningDialog`

**Cambios**:
- Convertir `_ScanningDialog` en un widget **con estado dinámico** que reciba un `ValueNotifier<String>` desde `_pickImage()`.
- La secuencia de pasos se actualizará automáticamente por **timer interno** + **callbacks del servicio**:

| Segundo | Texto | Ícono |
|---|---|---|
| 0s | "Preparando imagen..." | `Icons.image_search` |
| 2s | "Enviando a la Inteligencia Artificial..." | `Icons.cloud_upload` |
| 5s | "Analizando contenido con IA..." | `Icons.auto_awesome` |
| 10s | "Extrayendo datos, casi listo..." | `Icons.checklist` |
| (callback) | "Reintentando conexión..." | `Icons.refresh` |

- Cada cambio de texto tendrá una **animación de fade+slide** (salida del texto viejo, entrada del nuevo).
- Reemplazar el `LinearProgressIndicator` indeterminado por un **indicador de pasos visual** (dots o barra segmentada que avanza con cada fase).
- Mantener el diseño glassmorphism actual, que ya es muy bueno.

---

## Resumen de Archivos Afectados

| Archivo | Fase | Tipo de Cambio |
|---|---|---|
| [`scanner_ai_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_ai_service.dart) | Fase 1 | Backoff + traducción de errores |
| [`ai_extraction_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/ai_extraction_service.dart) | Fase 1 | Backoff + traducción de errores |
| [`scan_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/screens/scan_screen.dart) | Fase 1, 2, 3 | Caché, UI error, carga dinámica |

---

## Verificación

### Automated Tests
- `flutter analyze` para verificar compilación limpia.

### Manual Verification
- **Escenario A**: Poner el celular en modo avión después de seleccionar foto → Debe mostrar overlay de error amigable con botón de reintentar.
- **Escenario B**: Enviar una imagen cuando la API está saturada → Debe reintentar 1 vez automáticamente, si sigue fallando, mostrar mensaje amigable.
- **Escenario C**: Presionar "Reintentar Escaneo" tras un error → Debe enviar la misma foto sin pedir seleccionar de nuevo.
- **Escenario D**: Presionar "Escanear una nueva foto" → Debe abrir el picker (cámara/galería).
- **Escenario E**: Observar la pantalla de carga durante procesamiento normal → Los textos deben cambiar progresivamente con animación.

---

## Open Questions

> [!IMPORTANT]
> **¿Prefieres que el overlay de error se muestre como un Dialog modal (bloquea toda la pantalla) o como un panel integrado que reemplace el contenido central de `ScanScreen`?**
> Mi recomendación es un **panel integrado** (reemplaza el ícono grande y los botones de cámara/galería) porque así el usuario no siente que "algo se rompió" — simplemente la pantalla cambia de estado fluidamente.
