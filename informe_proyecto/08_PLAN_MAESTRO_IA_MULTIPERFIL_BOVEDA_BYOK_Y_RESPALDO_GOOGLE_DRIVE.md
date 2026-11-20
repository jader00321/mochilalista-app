# PLAN MAESTRO DE TRABAJO: CUOTA IA MULTI-PERFIL ACUMULATIVA, BÓVEDA MULTI-CLAVE BYOK, RESPALDO EN GOOGLE DRIVE Y MEJORAS ADMIN
## MOCHILALISTA (`app_movil`) — BLOQUE 2: MOTOR DE INTELIGENCIA ARTIFICIAL, SEGURIDAD DE CLAVES Y CONTINUIDAD DE DATOS EN LA NUBE

**Titular de Propiedad Intelectual y Autor Exclusivo:** Julio Angello Vasquez Navarro  
**Marco Legal y Jurisdicción:** Decreto Legislativo 822 (Ley sobre el Derecho de Autor del Perú), INDECOPI y Ley N° 29733 (Protección de Datos Personales) — Lima, República del Perú  
**Aplicación Principal:** `app_movil` (MochilaLista Mobile POS, Facturación & Cotizador Inteligente)  
**Plataforma de Control:** `mochilalista_admin` (Consola de Administración y Emisión de Licencias)  
**Versión Base de Auditoría:** `pubspec.yaml` v9.30.0+74  
**Fecha de Auditoría Forense y Planificación:** 18 de Noviembre de 2026  
**Documentos Relacionados Precedentes:**
* `informe_proyecto/01_AUDITORIA_SEGURIDAD_ACTUAL.md`
* `informe_proyecto/04_PROTECCION_PROPIEDAD_INTELECTUAL_LICENCIA_PERPETUA_Y_ACTUALIZACIONES.md`
* `informe_proyecto/06_PLAN_MAESTRO_REINGENIERIA_PLATAFORMA_ADMIN_Y_DESPLIEGUE_REAL.md`
* `informe_proyecto/07_PLAN_MAESTRO_ONBOARDING_EULA_LICENCIAS_Y_SEGURIDAD_HARDWARE.md`

---

## ÍNDICE GENERAL DEL PLAN MAESTRO 08

1. [Diagnóstico Forense de las 2 Capturas Reales de `Cotizador Universal IA y Cuota`](#1-diagnóstico-forense-de-las-2-capturas-reales-de-cotizador-universal-ia-y-cuota)
2. [PILAR 1: Multi-Perfil con Licencia Única y Bolsa de Cuota IA Compartida Global + 100% Acumulativa](#2-pilar-1-multi-perfil-con-licencia-única-y-bolsa-de-cuota-ia-compartida-global--100-acumulativa)
   * 2.1. Diagnóstico del desacoplamiento actual entre Perfiles SQLite y `licencia_app`
   * 2.2. Nueva Regla de Negocio: Saldo de IA 100% Acumulativo sin Reinicio Mensual Destructivo
   * 2.3. Matriz de Cuotas Acumulativas por Tipo de Plan y Recargas Extra
   * 2.4. Esquema SQLite `v35 -> v36`, Migración Cero-Pérdida y Ajuste de Tests
   * 2.5. Sincronización Reactiva entre Perfiles y Chip en `LicenseStatusAndActivationScreen`
3. [PILAR 2: Rediseño Integral de `Cotizador Universal IA y Cuota` + Bóveda Segura Multi-Clave BYOK](#3-pilar-2-rediseño-integral-de-cotizador-universal-ia-y-cuota--bóveda-segura-multi-clave-byok)
   * 3.1. Selector Explícito de Modo de Operación IA (Cuota MochilaLista vs. Clave Propia BYOK) y Reglas Estrictas de Consumo
   * 3.2. Bóveda Segura Multi-Clave en `FlutterSecureStorage` (Cifrado Keystore) y Eliminación Definitiva de Clave Plana Heredada
   * 3.3. Gestión con Alias, Cifrado Visual en Lista y Endpoint Inmune a Obsolescencia en `"Probar Clave"`
   * 3.4. Guía Interactiva Paso a Paso con Deep Link Directo a Google AI Studio
4. [PILAR 3: Blindaje de Migración sin Pérdida de Datos y Respaldo Automático Opcional en Google Drive](#4-pilar-3-blindaje-de-migración-sin-pérdida-de-datos-y-respaldo-automático-opcional-en-google-drive)
   * 4.1. Auditoría Forense: ¿Por qué se perdieron datos al cambiar de teléfono? (`android:allowBackup="false"`)
   * 4.2. Por qué Android Auto Backup es Insuficiente y la Superioridad del Modelo WhatsApp
   * 4.3. Arquitectura del Respaldo Opcional en Google Drive (`.mlbg`) con Clave de Cifrado Recuperable en Celular Nuevo (`googleUser.id`)
   * 4.4. Historial Fechado de Copias (Selector de Fecha de Restauración)
   * 4.5. Programador Periódico Confiable en Primer Plano / Reanudación (`AppLifecycleState.resumed`)
   * 4.6. Protocolo de Restauración en Caliente en Dispositivo Nuevo y Gobernanza Anti-Clonación (`ANDROID_ID`)
   * 4.7. Dependencias Limpias (`GoogleAuthClient` Propio), Permisos, Google Cloud Console (OAuth 2.0) y Aislamiento para Tests Offline
5. [PILAR 4: Anexo Preparatorio — Hoja de Ruta de Mejoras Posteriores en `mochilalista_admin/`](#5-pilar-4-anexo-preparatorio--hoja-de-ruta-de-mejoras-posteriores-en-mochilalista_admin)
   * 5.1. Visualizador Inmediato de Código QR y Credencial PNG en Cartera CRM (`web/index.html` y `web/js/admin_app.js`)
   * 5.2. Depuración de Redundancias en la Interfaz de Administración
   * 5.3. Sincronización de Créditos Acumulativos y Vinculación `ANDROID_ID` en `server.dart`
6. [Estructura de Fases de Ejecución, Archivos a Crear/Modificar y Matriz de Pruebas](#6-estructura-de-fases-de-ejecución-archivos-a-crearmodificar-y-matriz-de-pruebas)
7. [Protocolo de Aprobación y Transición a la Fase 1](#7-protocolo-de-aprobación-y-transición-a-la-fase-1)

---

## 1. DIAGNÓSTICO FORENSE DE LAS 2 CAPTURAS REALES DE `COTIZADOR UNIVERSAL IA Y CUOTA`

A partir de las pruebas operativas en el celular físico del autor, se auditaron las 2 capturas reales de la pantalla **`Cotizador Universal IA y Cuota`** (`AiSettingsScreen`):

| Elemento Auditado | Evidencia en la Captura | Diagnóstico Técnico en el Código Fuente | Decisión de Reingeniería en el Bloque 2 |
| :--- | :--- | :--- | :--- |
| **Tarjeta "Consumo del Mes" (Captura `8.06.28 PM (1)`)** | Título *"Consumo del Mes"*, badge *"Cuota Incluida"*, contador *"49 disponibles de 50 escaneos mensuales (1 usados)"*. Texto inferior: *"El cupo se restablece automáticamente el 1 de diciembre"*. | `ai_settings_screen.dart` (Líneas 108-110) calcula `nextResetDate = DateTime(now.year, now.month + 1, 1)`. En `license_repository.dart` (Líneas 406-414), al cambiar de mes se resetea `ai_scans_used_month` a 0, perdiendo los escaneos no consumidos del periodo anterior. | **Eliminar por completo el reseteo mensual destructivo.** Reemplazar por una **Bolsa Única Acumulativa**. Los escaneos no caducan; se suman acumulativamente al saldo del dispositivo y se comparten entre todos los perfiles comerciales del teléfono. |
| **Tarjeta "Clave Propia (BYOK)" (Captura `8.06.28 PM`)** | Campo único de texto *"AIzaSy..."* con botón de visibilidad y pegado. Botón inferior *"Guardar Clave Propia"*. No hay lista de claves ni nombre descriptivo. | `ApiConstants._userCustomApiKey` y `SharedPreferences` (Línea 32) solo almacenan una cadena simple bajo `'user_custom_gemini_api_key'`. No utiliza almacenamiento cifrado en Keystore, no admite múltiples claves ni alias identificatorios. | **Diseñar una Bóveda Segura Multi-Clave en `FlutterSecureStorage`:** permite almacenar múltiples claves con Alias obligatorio (ej. *"Gmail Personal"*, *"Tienda Norte"*), máscara visual (`AIza••••••••7x9Q`), botón de verificación real de conexión (`Probar Clave`) y copia segura con `CustomSnackBar`. |
| **Indefinición de Fuente de IA (Captura `8.06.28 PM`)** | Si el usuario ingresa una clave propia, la app asume forzosamente que siempre debe usar BYOK sin permitirle conmutar voluntariamente a su bolsa de MochilaLista. | `ApiConstants.googleApiKey` da prioridad estricta a `_userCustomApiKey` si existe, sin selector de estado en la UI. | **Implementar Selector Explícito de Modo de Uso:** el usuario decide libremente entre: **Modo A (Cuota MochilaLista)** o **Modo B (Clave Propia BYOK)**. Usar BYOK congela el gasto de su cuota oficial, preservándola íntegra. |
| **Tarjeta "¿Cómo obtener una API Key gratis?" (Captura `8.06.28 PM`)** | Pasos enumerados en texto plano: *"1 Ingresa a aistudio.google.com..."*. El comerciante debe abrir manualmente el navegador y escribir la URL. | `ai_settings_screen.dart` (Líneas 470-520) solo muestra widgets `Text` informativos sin botón de acción externa. | **Incorporar Botón Directo:** *"Abrir Google AI Studio"* vía `url_launcher` hacia `https://aistudio.google.com/apikey`, con feedback guiado para comerciantes no técnicos. |

---

## 2. PILAR 1: MULTI-PERFIL CON LICENCIA ÚNICA Y BOLSA DE CUOTA IA COMPARTIDA GLOBAL + 100% ACUMULATIVA

### 2.1. Diagnóstico del Desacoplamiento Actual entre Perfiles SQLite y `licencia_app`
La arquitectura de `app_movil` maneja múltiples negocios/perfiles comerciales en SQLite mediante las tablas:
* `usuarios`: Almacena la cuenta del perfil local (`id`, `nombre_completo`, `email`, etc.).
* `negocios`: Almacena cada sucursal/comercio (`id`, `nombre_comercial`, `moneda`, etc.).
* `negocio_usuario`: Vincula al usuario activo con su negocio respectivo.

Por otro lado, la tabla `licencia_app` (asegurada en el Plan 07) es **estrictamente de nivel de dispositivo**:
```sql
CREATE TABLE IF NOT EXISTS licencia_app (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_fingerprint TEXT NOT NULL,
  tipo_plan TEXT NOT NULL DEFAULT 'TRIAL',
  estado_actual TEXT NOT NULL DEFAULT 'ACTIVA',
  ...
)
```
**Conclusión Arquitectónica:** `licencia_app` NO depende de `negocio_id` ni de `usuario_id`. En consecuencia:
1. **Una sola licencia activa ya ampara el 100% de los perfiles comerciales en ese dispositivo físico.** El cambio de perfil en `AuthProvider` no altera el estado de la licencia ni expulsa al usuario.
2. Sin embargo, el consumo de IA no debe permitir que un comerciante cree perfiles infinitos para "multiplicar" sus escaneos. La bolsa de escaneos IA debe ser **global y compartida por el dispositivo**.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        DISPOSITIVO FÍSICO                              │
│                    Hardware ID: ML-XXXX (ANDROID_ID)                   │
├────────────────────────────────────────────────────────────────────────┤
│                  TABLA MAESTRA: `licencia_app`                         │
│       Estado: ACTIVA | Plan: MENSUAL | Bolsa IA Acumulada: 47          │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ (Bolsa Única Compartida)
         ┌──────────────────────────┼──────────────────────────┐
         ▼                          ▼                          ▼
  ┌──────────────┐           ┌──────────────┐           ┌──────────────┐
  │  Perfil A    │           │  Perfil B    │           │  Perfil C    │
  │ (Bodega Luz) │           │ (Librería)   │           │ (Bazar Sur)  │
  ├──────────────┤           ├──────────────┤           ├──────────────┤
  │ Consume 1 IA │           │ Consume 2 IA │           │ Consume 0 IA │
  └──────┬───────┘           └──────┬───────┘           └──────┬───────┘
         │                          │                          │
         └──────────────────────────┴──────────────────────────┘
                                    ▼
              Saldo Global Restante en Dispositivo: 44 Usos
         (Reflejado instantáneamente en el 100% de los perfiles)
```

### 2.2. Nueva Regla de Negocio: Saldo de IA 100% Acumulativo
Actualmente, el sistema calcula:
$$\text{remainingAiScans} = (\text{totalMonthlyQuota} - \text{aiScansUsedMonth})$$
Y cada fin de mes el saldo se pierde. 

**Nueva Regla de Negocio Obligatoria:**
1. **Los escaneos de IA no tienen caducidad temporal ni reseteo mensual.**
2. Cada evento que aporta escaneos incrementa el saldo acumulado disponible:
   $$\text{SaldoDisponible}_{\text{nuevo}} = \text{SaldoDisponible}_{\text{previo}} + \text{EscaneosOtorgados}$$
3. Cada escaneo procesado con éxito (en Facturas o Cotizador) con el modo cuota MochilaLista decrementa exactamente en 1 la bolsa global:
   $$\text{SaldoDisponible}_{\text{nuevo}} = \text{SaldoDisponible}_{\text{previo}} - 1$$
4. El comerciante que no gaste sus escaneos en meses de baja demanda los conserva íntegros para temporadas altas (Campaña Escolar, Fiestas Patrias, Navidad).

### 2.3. Matriz de Cuotas Acumulativas por Tipo de Plan y Recargas Extra
Al canjear un código de licencia o bono, el sistema acreditará las siguientes unidades a la bolsa acumulada:

| Tipo de Plan / Bono | Duración Base | Escaneos IA Acreditados a la Bolsa | Justificación Comercial / Proporcionalidad |
| :--- | :--- | :--- | :--- |
| **TRIAL (Prueba Gratuita)** | 30 días | **+50 escaneos** | Suficiente para probar exhaustivamente el escaneo de facturas y cotizaciones. |
| **MENSUAL** | 30 días | **+50 escaneos** | Cuota estándar equilibrada para pequeñas librerías/bodegas. |
| **TRIMESTRAL** | 90 días | **+180 escaneos** | 60 escaneos/mes equivalentes (+30 escaneos de bonificación por fidelidad). |
| **SEMESTRAL** | 180 días | **+450 escaneos** | 75 escaneos/mes equivalentes (+150 escaneos de bonificación comercial). |
| **ANUAL** | 365 días | **+1,200 escaneos** | 100 escaneos/mes equivalentes (+600 escaneos de ahorro respecto a 12 mensuales). |
| **PERPETUO (Liberada)** | De por vida | **+200 escaneos iniciales** | Bolsa de bienvenida + 12 meses de actualizaciones. |
| **BOLSA EXTRA IA (+150)** | Sin vencimiento | **+150 escaneos** | Recarga pura de IA independiente del tipo de plan (S/ 20.00). |
| **PASE ANUAL DE UPDATES** | 365 días | **+100 escaneos de bono** | Incentivo de actualización para licencias perpetuas (S/ 150.00). |
| **BONO PROMOCIONAL ADMIN** | Variable | **+X escaneos libres** | Emitido puntualmente desde `mochilalista_admin` según criterio del propietario. |

### 2.4. Esquema SQLite `v35 -> v36`, Migración Cero-Pérdida y Ajuste de Tests
La incorporación de la bolsa acumulativa y el selector de modo requiere una actualización de esquema en `lib/core/database/local_db.dart`:

1. **Incremento de Versión de Base de Datos:**
   * La versión de SQLite sube formalmente de **`version: 35` a `version: 36`**.
2. **Estructura para Instalaciones Nuevas (`_onCreate` / `ensureLicenciaAppTable`):**
   ```sql
   CREATE TABLE IF NOT EXISTS licencia_app (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     device_fingerprint TEXT NOT NULL,
     tipo_plan TEXT NOT NULL DEFAULT 'TRIAL',
     estado_actual TEXT NOT NULL DEFAULT 'ACTIVA',
     fecha_inicio TEXT NOT NULL,
     fecha_expiracion TEXT NOT NULL,
     ultimo_nonce INTEGER NOT NULL DEFAULT 0,
     ultimo_codigo_usado TEXT,
     updates_until TEXT,
     max_major_version INTEGER DEFAULT 9,
     business_owner_tag TEXT,
     fecha_ultimo_check TEXT NOT NULL,
     ai_scans_used_month INTEGER NOT NULL DEFAULT 0,
     ai_scans_month_key TEXT NOT NULL DEFAULT '',
     ai_extra_credits INTEGER NOT NULL DEFAULT 0,
     custom_gemini_api_key TEXT,
     eula_accepted_version TEXT,
     eula_accepted_timestamp TEXT,
     migrated_from_device_id TEXT,
     last_executed_app_version TEXT,
     ai_accumulated_scans INTEGER NOT NULL DEFAULT 50,
     ai_selected_mode TEXT NOT NULL DEFAULT 'INCLUDED'
   );
   ```
3. **Migración Cero-Pérdida para Usuarios Existentes en `_onUpgrade` (`safeUpgradeWithSnapshot`):**
   ```dart
   if (oldVersion < 36) {
     AppLogger.i('LocalDatabase', 'Migrando esquema SQLite a v36: Cuota IA Acumulativa y Modo BYOK');
     await ensureColumnExists(db, 'licencia_app', 'ai_accumulated_scans', 'INTEGER NOT NULL DEFAULT 50');
     await ensureColumnExists(db, 'licencia_app', 'ai_selected_mode', "TEXT NOT NULL DEFAULT 'INCLUDED'");

     // Migración justa del saldo: respetar lo no gastado del mes en curso + créditos extra históricos
     final rows = await db.query('licencia_app', limit: 1);
     if (rows.isNotEmpty) {
       final row = rows.first;
       final usedMonth = (row['ai_scans_used_month'] as num?)?.toInt() ?? 0;
       final extraCredits = (row['ai_extra_credits'] as num?)?.toInt() ?? 0;
       final plan = PlanType.fromString(row['tipo_plan'] as String? ?? 'TRIAL');
       final planBase = plan.baseMonthlyAiScans;

       // Cálculo exacto sin restar arbitrariamente a 0:
       final initialAccumulated = math.max(0, (planBase + extraCredits) - usedMonth);

       await db.update(
         'licencia_app',
         {'ai_accumulated_scans': initialAccumulated},
         where: 'id = ?',
         whereArgs: [row['id']],
       );
       AppLogger.i('LocalDatabase', 'Saldo IA v36 migrado exitosamente con $initialAccumulated usos acumulados.');
     }
   }
   ```
4. **Ajuste Preventivo de Pruebas Automatizadas:**
   * Se revisarán las suites existentes (como `security_phase1_vault_and_db_migration_test.dart`) que verifiquen estrictamente `db.getVersion() == 35` para actualizar su expectativa a `36`, garantizando **0 falsos negativos**.

### 2.5. Sincronización Reactiva entre Perfiles y Chip en `LicenseStatusAndActivationScreen`
* `LicenseProvider` notifica via `notifyListeners()` ante cualquier consumo (`consumeAiScan()`) o recarga (`addExtraAiCredits()`).
* Cualquier vista suscrita (`AiSettingsScreen`, `LicenseStatusAndActivationScreen`, `SmartActionGrid`, `ScanScreen`) se repinta al instante sin requerir reiniciar la app.
* En `LicenseStatusAndActivationScreen`, el chip interactivo de escaneos IA pasa a mostrar:
  * Si usa Bolsa MochilaLista: `"X escaneos acumulados disponibles"` (sin mención de mes).
  * Si usa BYOK: `"Escaneos Ilimitados Activos (BYOK) • Saldo guardado: X usos"`.

---

## 3. PILAR 2: REDISEÑO INTEGRAL DE `COTIZADOR UNIVERSAL IA Y CUOTA` + BÓVEDA SEGURA MULTI-CLAVE BYOK

### 3.1. Selector Explícito de Modo de Operación IA y Reglas Estrictas de Consumo
En la pantalla `AiSettingsScreen`, se implementará en la parte superior un **Selector de Modo en Tarjeta Toggle**:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   MODO DE PROCESAMIENTO CON IA                         │
├───────────────────────────────────┬────────────────────────────────────┤
│ [●] Bolsa MochilaLista            │ [○] Clave Propia (BYOK)            │
│ 47 escaneos acumulados            │ Ilimitado con tu clave Gemini      │
└───────────────────────────────────┴────────────────────────────────────┘
```

**Reglas Arquitectónicas de Consumo Estricto:**
1. **Regla de Modo `INCLUDED` (Bolsa MochilaLista):**
   * Cuando `ai_selected_mode == 'INCLUDED'`, `ApiConstants.googleApiKey` y `LicenseRepository.consumeAiScan` utilizan **exclusivamente la clave oficial** de MochilaLista y debitan exactamente `1` uso de `ai_accumulated_scans`.
   * Esto se cumple **incluso si el usuario tiene claves BYOK registradas en su bóveda**. El usuario tiene el control absoluto de cuándo gastar su bolsa y cuándo usar su clave propia.
2. **Regla de Modo `BYOK` (Clave Propia):**
   * Cuando `ai_selected_mode == 'BYOK'`, la app procesa las llamadas utilizando la clave activa de su bóveda personal.
   * `LicenseRepository.consumeAiScan` retorna `true` inmediatamente sin restar **ni un solo escaneo** de `ai_accumulated_scans` (saldo congelado).
3. **Blindaje ante Clave Faltante en Modo `BYOK`:**
   * Si el usuario selecciona el modo `BYOK` pero **no existe ninguna clave activa válida en la bóveda** (bóveda vacía o clave activa eliminada):
     * La app **NUNCA debe consumir silenciosamente** de la bolsa de MochilaLista.
     * En su lugar, el sistema detiene el proceso y muestra un aviso interactivo con `CustomSnackBar` o diálogo modal:
       > *“Tienes seleccionado el modo Clave Propia (BYOK), pero no hay ninguna clave activa configurada en tu bóveda. Configura una clave en la Bóveda o cambia al modo Bolsa MochilaLista para continuar.”*
4. **Aviso de Gobernanza de Licencia:** Debajo del selector se mostrará un banner aclaratorio permanente:
   > *“El modo Clave Propia (BYOK) te permite procesar listas y facturas ilimitadas con tu cuenta de Google AI Studio sin consumir tus usos de MochilaLista. La aplicación requiere una licencia activa para operar el sistema contable y de inventario.”*

### 3.2. Bóveda Segura Multi-Clave en `FlutterSecureStorage` (Cifrado Keystore) y Eliminación Definitiva de Clave Plana Heredada
Se creará la clase de soporte:
`lib/core/services/ai/ai_vault_service.dart`

**Modelo de Clave (`AiKeyModel`):**
```dart
class AiKeyModel {
  final String id;              // UUID v4
  final String alias;           // Ej: "Mi Gmail Personal", "Tienda Central"
  final String apiKey;          // "AIzaSy..."
  final DateTime createdAt;     // Timestamp de creación
  final DateTime? lastTestedAt; // Última verificación exitosa
  final bool isWorking;         // Estado de la última prueba
}
```
* Las claves se serializan en un JSON seguro cifrado dentro de `FlutterSecureStorage` bajo la clave `mochilalista_ai_vault_keys`.
* La clave activa seleccionada se almacena en `mochilalista_active_byok_key_id`.
* En compilaciones Android, `FlutterSecureStorage` utiliza Android Keystore con cifrado AES-CBC/GCM por hardware, protegiendo las credenciales frente a ataques de extracción de memoria física.

**Protocolo de Migración y Destrucción de Clave Heredada en Texto Plano:**
* Al inicializar `AiVaultService`, el sistema comprobará si existe la clave legacy en `SharedPreferences` (`user_custom_gemini_api_key`).
* Si existe y la bóveda está vacía:
  1. La importa a la bóveda segura en `FlutterSecureStorage` asignándole automáticamente el alias `"Mi Clave Gemini (Migrada)"` y marcándola como activa.
  2. **Eliminación Definitiva Inmediata:** Ejecuta inmediatamente:
     ```dart
     final prefs = await SharedPreferences.getInstance();
     await prefs.remove('user_custom_gemini_api_key');
     ```
     Garantizando que **no quede ningún rastro de claves de API en texto plano** dentro de XMLs no protegidos del almacenamiento compartido de Android.

### 3.3. Gestión con Alias, Cifrado Visual en Lista y Endpoint Inmune a Obsolescencia en `"Probar Clave"`
La interfaz de `AiSettingsScreen` presentará la lista de claves registradas:
1. **Identificación por Alias:** Cada elemento destaca el nombre asignado en negrita (ej. *"Clave Principal Angello"*).
2. **Cifrado Visual:** La clave real se muestra enmascarada: `AIzaSyB••••••••••••••••3x9Q` (primeros 6 y últimos 4 caracteres visibles).
3. **Endpoint Inmune a Obsolescencia en `"Probar Clave"`:**
   * **Problema Previsto:** Invocar modelos específicos como `gemini-1.5-flash` o `gemini-pro` genera errores cuando Google retira versiones antiguas o renombra modelos en su catálogo.
   * **Solución Definitiva:** La función `"Probar Clave"` consultará estrictamente el endpoint canónico de listado de modelos de la API de Google AI Studio:
     $$\text{GET } \text{https://generativelanguage.googleapis.com/v1beta/models?pageSize=1\&key=<API\_KEY>}$$
   * **Ventajas Críticas:**
     * **0 Tokens consumidos:** No gasta cuota de inferencia.
     * **Inmune a cambios de versión:** El listado de modelos es la raíz de la API y jamás caduca mientras la clave sea válida.
     * **Respuesta Confiable:** Si la clave es válida, Google responde `200 OK` con metadata de modelos. Si es inválida o fue revocada, responde `400/403 API_KEY_INVALID`.
   * **Parámetros Técnicos:** Timeout estricto de 6 segundos e inyección de cliente HTTP (`http.Client`) para permitir pruebas unitarias automatizadas con mocks y 0 llamadas a la red.
4. **Acciones Disponibles por Tarjeta (Iconos Vectoriales con Feedback `CustomSnackBar`):**
   * **`Activar` / `En Uso`:** Chip interactivo que marca la clave activa para las llamadas del cotizador.
   * **`Probar Clave`:** Ejecuta la comprobación descrita mostrando badge verde *"Conexión Exitosa"* con timestamp o badge rojo descriptivo en caso de fallo.
   * **`Copiar`:** Copia la clave completa al portapapeles informando *"Clave '[Alias]' copiada con éxito"*.
   * **`Editar Alias`:** Modal rápido para renombrar el alias.
   * **`Eliminar`:** Confirmación antes de descartar la clave de la bóveda.

### 3.4. Guía Interactiva Paso a Paso con Deep Link Directo
Debajo de la bóveda, la tarjeta educativa se rediseñará con los siguientes pasos:
1. Botón principal destacado: **`Abrir Google AI Studio`** con icono externo `Icons.open_in_browser_rounded` que lanza directamente `https://aistudio.google.com/apikey`.
2. Pasos visuales claros con numeración circular:
   * **Paso 1:** Inicia sesión con cualquier cuenta habitual de Google (Gmail).
   * **Paso 2:** Presiona en *"Create API key"* y copia el código generado.
   * **Paso 3:** Regresa a MochilaLista, asigna un nombre y guárdala en tu bóveda.
3. Banner inferior verde: *"Google AI Studio ofrece un nivel gratuito con miles de peticiones al mes sin requerir tarjeta de crédito."*

---

## 4. PILAR 3: BLINDAJE DE MIGRACIÓN SIN PÉRDIDA DE DATOS Y RESPALDO AUTOMÁTICO OPCIONAL EN GOOGLE DRIVE

### 4.1. Auditoría Forense: ¿Por qué se perdieron datos al cambiar de teléfono?
En la inspección técnica de `android/app/src/main/AndroidManifest.xml` (Línea 35) se constató la presencia de:
```xml
android:allowBackup="false"
```
**Causas Raíz Identificadas:**
1. **Bloqueo de Copia Nativa del Sistema Operativo:** Al configurar `android:allowBackup="false"`, Android desactiva completamente el servicio de *Android Cloud Backup*. Cuando un usuario utiliza la herramienta *"Transferir datos de mi celular antiguo"* (vía cable o Google Cloud), Android excluye explícitamente el directorio `/data/data/com.mochilalista.app/databases/` por orden del manifiesto.
2. **Divergencia de Application ID en Versiones Tempranas:** En fases alfa anteriores a la v9.20, el proyecto utilizaba `com.example.app_movil`. Al migrar a `com.mochilalista.app`, Android reconoció la app como un paquete totalmente diferente, aislándolo en una nueva sandbox de almacenamiento.
3. **Preservación en Actualizaciones Normales:** Se comprobó que actualizar el APK sobre el mismo teléfono conservando `com.mochilalista.app` **NO pierde datos**, ya que el motor `safeUpgradeWithSnapshot` de SQLite preserva los archivos `mochilalista.db`, `mochilalista.db-wal` y `mochilalista.db-shm`.

### 4.2. Por qué Android Auto Backup es Insuficiente y la Superioridad del Modelo WhatsApp
Habilitar simplemente `android:allowBackup="true"` sería una solución deficiente y riesgosa:
* Es una "caja negra": el usuario no sabe cuándo se hizo el respaldo ni si falló.
* Solo se ejecuta cuando el teléfono está inactivo, conectado a Wi-Fi y cargando durante horas.
* No permite seleccionar fechas de restauración ni ofrece confirmación visual.
* **Solución Profesional (Modelo WhatsApp):** Implementar un módulo específico de **Copia de Seguridad en Google Drive**, donde los datos viajan cifrados en nuestro contenedor oficial `.mlbg` y el usuario tiene visibilidad total de la fecha, hora y tamaño de cada copia.

### 4.3. Arquitectura del Respaldo Opcional en Google Drive (`.mlbg`) con Clave de Cifrado Recuperable en Celular Nuevo
1. **El Problema del Cifrado Atado al Dispositivo Viejo:**
   * Si el archivo `.mlbg` se cifrara con una clave basada en el `ANDROID_ID` del teléfono emisor, al perder el celular o cambiar de equipo sería **matemáticamente imposible descifrar los datos en el nuevo teléfono**, provocando una pérdida total de información.
2. **Derivación Determinista de Clave de Cifrado Recuperable:**
   * El respaldo subido a `drive.appdata` utilizará cifrado simétrico `AES-256-GCM`, derivando su clave de 256 bits mediante `PBKDF2-HMAC-SHA256` a partir de los datos de identidad de la cuenta de Google autenticada:
     $$\text{Key} = \text{PBKDF2}\Big(\text{Secret}=\text{googleUser.id},\; \text{Salt}=\text{"MochilaLista_DriveVault_v1_Salt"},\; \text{Iterations}=100{,}000\Big)$$
   * **Ventajas de Seguridad y Resiliencia:**
     * **Seguridad Absoluta en la Nube:** Si un tercero accede indebidamente al Google Drive del usuario, no puede descifrar el archivo sin la sal de la app y la implementación de derivación.
     * **Recuperabilidad Inmediata en Celular Nuevo:** Cuando el comerciante inicia sesión con su misma cuenta de Google (`googleUser.id` idéntico) en un teléfono recién comprado, la app regenera exactamente la misma clave y puede descifrar y restaurar el respaldo de inmediato.
     * **Frase de Recuperación Opcional:** El comerciante podrá opcionalmente activar una contraseña o PIN adicional si desea máxima protección contra accesos no autorizados a su Google Drive.
3. **Almacenamiento en `drive.appdata` (Carpeta Privada de Aplicación):**
   * Se utilizará el scope: `https://www.googleapis.com/auth/drive.appdata`.
   * Los respaldos se alojan en el directorio privado de la aplicación en Google Drive. No aparecen mezclados en *"Mi Unidad"*, previniendo borrados accidentales por parte del usuario o de terceros con acceso a la cuenta.

```
┌────────────────────────────────────────────────────────────────────────┐
│                         TELÉFONO ANDROID                               │
│       Base de Datos Local SQLite: `mochilalista.db`                    │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Cifrado AES-256-GCM (PBKDF2(googleUser.id))
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│             Archivo de Respaldo: `backup_20261118_2330.mlbg`           │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ GoogleDriveBackupService (OAuth 2.0)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   CUENTA PERSONAL DE GOOGLE DRIVE                      │
│            Carpeta Segura: `drive.appdata` (Oculta al usuario)         │
│   ├─ backup_20261118_2330.mlbg (1.4 MB) - [Último]                     │
│   ├─ backup_20261117_2015.mlbg (1.3 MB)                               │
│   ├─ backup_20261116_1845.mlbg (1.3 MB)                               │
│   ├─ backup_20261115_2100.mlbg (1.2 MB)                               │
│   └─ backup_20261114_1910.mlbg (1.2 MB) - [Histórico 5]               │
└────────────────────────────────────────────────────────────────────────┘
```

### 4.4. Historial Fechado de Copias (Selector de Restauración)
* El servicio mantendrá las **últimas 5 copias fechadas** en Google Drive, eliminando automáticamente la más antigua al generar la sexta (política FIFO de rotación de copias).
* En la pantalla de recuperación o ajustes, el comerciante verá la lista:
  * *"18 de Noviembre de 2026 — 11:30 PM (1.4 MB) — [Más reciente]"*
  * *"17 de Noviembre de 2026 — 08:15 PM (1.3 MB)"*
  * *"16 de Noviembre de 2026 — 06:45 PM (1.3 MB)"*
* Permite seleccionar exactamente a qué punto en el tiempo desea regresar si cometió un error grave en sus ventas del día.

### 4.5. Programador Periódico Confiable en Primer Plano / Reanudación (`AppLifecycleState.resumed`)
* **Diagnóstico sobre `WorkManager` y Procesos Headless en Android:**
  * En Android, las tareas en segundo plano que corren en *Isolates* headless sin una `Activity` activa fallan con frecuencia al intentar renovar tokens de `GoogleSignIn` o solicitar interacción de cuenta.
* **Solución de Arquitectura Robusta: Programador Basado en Ciclo de Vida y Arranque:**
  * La verificación periódica se orquestará en **primer plano no bloqueante** aprovechando el ciclo de vida de la app:
    1. **Al Iniciar la App:** Invocado desde `StartupFlowCoordinator` de forma asíncrona tras verificar el EULA y la licencia.
    2. **Al Reanudar la App:** Registrado a través de `AppLifecycleListener` en el evento `AppLifecycleState.resumed`.
  * **Lógica de Ejecución en Segundo Plano Asíncrono (Sin Congelar la UI):**
    ```dart
    Future<void> checkAndTriggerScheduledDriveBackup() async {
      if (!isDriveBackupEnabled) return;
      final now = DateTime.now();
      final lastBackup = await getLastBackupTimestamp();
      final intervalHours = getScheduledIntervalHours(); // Diario (24h), Semanal (168h), Mensual (720h)

      if (now.difference(lastBackup).inHours >= intervalHours) {
        // Verificar filtro Wi-Fi
        if (requiresOnlyWifi) {
          final isWifi = await isConnectedToWifi();
          if (!isWifi) return; // Esperar a conexión Wi-Fi sin molestar
        }
        // Disparar respaldo silencioso en hilo secundario
        unawaited(_executeDriveBackupSilently());
      }
    }
    ```
  * Esta estrategia garantiza un **100% de confiabilidad** sin fallos de autenticación headless, respetando la cuota de datos móviles del comerciante.

### 4.6. Protocolo de Restauración en Caliente en Dispositivo Nuevo y Gobernanza Anti-Clonación (`ANDROID_ID`)
Para restaurar una copia desde Google Drive sin provocar corrupción ni inconsistencias en la base de datos en ejecución, se establece el siguiente **Protocolo de Restauración en Caliente**:

```
[1. Descarga .mlbg desde Google Drive]
                │
                ▼
[2. Descifrado AES-256-GCM con PBKDF2(googleUser.id)]
                │
                ▼
[3. Checkpoint WAL Forzado: PRAGMA wal_checkpoint(TRUNCATE)]
                │
                ▼
[4. Cierre Limpio de Conexión SQLite: LocalDatabase().closeConnection()]
                │
                ▼
[5. Sobrescritura Atómica del Archivo `mochilalista.db`]
                │
                ▼
[6. Reapertura de Base de Datos y Gobernanza Anti-Clonación]
       ├─ ¿Hardware ID coincide con el equipo actual?
       ├─ SI -> Estado ACTIVA preservado (100% operativo).
       └─ NO -> Marca estado PENDIENTE_MIGRACION (Datos 100% restaurados,
                 solicita migración de licencia al nuevo ANDROID_ID).
                │
                ▼
[7. Notificación Reactiva a Providers (AuthProvider & LicenseProvider)]
```

* **Garantía Comercial:** El comerciante recupera el 100% de su catálogo, inventario, ventas, clientes y deudas en su celular nuevo. La app protege la propiedad intelectual del software impidiendo que una misma licencia opere en paralelo en dos teléfonos sin haber solicitado la migración formal.

### 4.7. Dependencias Limpias (`GoogleAuthClient` Propio), Permisos, Google Cloud Console y Aislamiento para Tests Offline

1. **Dependencias a Incorporar en `pubspec.yaml`:**
   * `google_sign_in: ^6.2.2` (Autenticación OAuth 2.0 nativa en Android).
   * `googleapis: ^13.2.0` (Cliente oficial de APIs de Google, incluyendo Drive v3).
   * `http: ^1.2.0` (Cliente base estándar para peticiones autenticadas).
   * *(Se descarta `extension_google_sign_in_as_googleapis_auth` para evitar conflictos de versiones y mantener el árbol de dependencias limpio).*

2. **Cliente Ligero Propio `GoogleAuthClient` (~15 Líneas):**
   ```dart
   import 'package:http/http.dart' as http;

   class GoogleAuthClient extends http.BaseClient {
     final Map<String, String> _headers;
     final http.Client _client = http.Client();

     GoogleAuthClient(this._headers);

     @override
     Future<http.StreamedResponse> send(http.BaseRequest request) {
       request.headers.addAll(_headers);
       return _client.send(request);
     }

     @override
     void close() {
       _client.close();
       super.close();
     }
   }
   ```
   * Se instancia simplemente con `GoogleAuthClient(await googleUser.authHeaders)` y se entrega directamente a `drive.DriveApi(authClient)`, garantizando un enlace nativo, seguro y sin dependencias superfluas.

3. **Permisos en `android/app/src/main/AndroidManifest.xml`:**
   * `android.permission.INTERNET` (ya presente).
   * `android.permission.ACCESS_NETWORK_STATE` (para validar conectividad y Wi-Fi antes de subir).

4. **Requisitos de Google Cloud Console (Para el Propietario):**
   * Crear Proyecto: `MochilaLista Mobile POS`.
   * Habilitar API: `Google Drive API`.
   * Pantalla de Consentimiento OAuth: Configurar nombre de la app, correo de soporte y scope `drive.appdata`.
   * Credenciales OAuth 2.0: Tipo Android, package `com.mochilalista.app`, y registrar las huellas digitales SHA-1:
     * Huella Debug: obtenida de `~/.android/debug.keystore`.
     * Huella Release: obtenida del keystore comercial de producción.

5. **Blindaje de Pruebas Automatizadas (Zero-Network Test Isolation):**
   * Se diseñará la interfaz abstracta `IGoogleDriveBackupService`.
   * En `test/`, se implementará `MockGoogleDriveBackupService` con almacenamiento en memoria simulado.
   * **Garantía Estricta:** `flutter test` en Windows correrá al 100% en verde con 0 dependencias de red, 0 llamadas a Google y 0 fallos de autenticación.

---

## 5. PILAR 4: ANEXO PREPARATORIO — HOJA DE RUTA DE MEJORAS POSTERIORES EN `MOCHILALISTA_ADMIN/`

Este anexo delimita las mejoras que se abordarán posteriormente en la plataforma web de escritorio del propietario (`mochilalista_admin`):

### 5.1. Visualizador Inmediato de Código QR y Credencial PNG en Cartera CRM (`web/index.html` y `web/js/admin_app.js`)
* En la interfaz web de escritorio servida por `server.dart`:
  * En la tabla de clientes de la Cartera CRM (`web/index.html` y `web/js/admin_app.js`), agregar un botón de acción rápida: **`Ver QR y Credencial`** junto a cada cliente con licencia activa.
  * Modal interactivo que renderiza inmediatamente el Código QR vectorial utilizando `qrcode.min.js` ya presente en el proyecto.
  * Opciones directas:
    * **`Escanear en Pantalla`**: Permite al cliente apuntar la cámara de su celular al monitor de la laptop y activar su app en 2 segundos.
    * **`Copiar Imagen / Credencial PNG`**: Genera un canvas gráfico de la credencial oficial con logotipo, Hardware ID, tipo de plan y vigencia, listo para pegar en WhatsApp Web.

### 5.2. Depuración de Redundancias en la Interfaz de Administración
* Revisar `web/index.html` y `web/js/admin_app.js` para simplificar los formularios de emisión:
  1. Campo único de pegado rápido de Hardware ID (`ML-XXXX`).
  2. Selector de Plan Comercial unificado (Mensual, Trimestral, Semestral, Anual, Perpetua, Bolsa Extra).
  3. Emisión instantánea de token firmado y generación de mensaje oficial para WhatsApp en 1 solo clic.

### 5.3. Sincronización de Créditos Acumulativos y Vinculación `ANDROID_ID` en `server.dart`
* En `mochilalista_admin/server.dart` y `mochilalista_admin/lib/license_signer.dart`:
  * Actualizar la carga útil (Payload) del token Ed25519 para sincronizar los créditos de las nuevas bolsas acumulativas (+50, +180, +450, +1200, +150 IA).
  * Validar que los identificadores de hardware emitidos coincidan con la estructura esperada de derivación basada en `ANDROID_ID`.

---

## 6. ESTRUCTURA DE FASES DE EJECUCIÓN, ARCHIVOS A CREAR/MODIFICAR Y MATRIZ DE PRUEBAS

El trabajo del Bloque 2 se organizará en **4 Fases estrictamente secuenciales**:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                       BLOQUE 2: ESTRUCTURA DE FASES SECUENCIALES                       │
├───────────────────┬───────────────────┬────────────────────────┬───────────────────────┤
│      FASE 1       │      FASE 2       │         FASE 3         │        FASE 4         │
│ Cuota Acumulativa │   Bóveda Segura   │    Google Drive        │   Regresión Global    │
│  y Multi-Perfil   │   Multi-Clave     │     Backup Cifrado     │  y Certificación E2E  │
│  (DB v35 -> v36)  │   BYOK & UI       │      (Estilo WA)       │    de Producción      │
└───────────────────┴───────────────────┴────────────────────────┴───────────────────────┘
```

### FASE 1: Motor de Cuota IA Acumulativa, Bolsa Compartida Multi-Perfil y Migración SQLite v36
* **Objetivo:** Actualizar el esquema a `v36` bajo `safeUpgradeWithSnapshot`, convertir el sistema de cuota mensual a una bolsa acumulativa compartida en SQLite, migrando datos existentes sin pérdidas y sincronizando `LicenseProvider`, `scan_screen.dart` y `smart_quotation_provider.dart`.
* **Archivos a Modificar:**
  * `lib/core/models/license_model.dart`: Adición de campos `aiAccumulatedScans`, `aiSelectedMode`, getters reactivos de cuota acumulativa y normalización de planes.
  * `lib/core/database/local_db.dart`: Incremento a `version: 36`, actualización de `ensureLicenciaAppTable` y bloque `if (oldVersion < 36)` en `safeUpgradeWithSnapshot` con fórmula cero-pérdida.
  * `lib/core/services/license/license_repository.dart`: Desactivar `_resetMonthlyAiScans`, implementar `consumeAiScan()` decrementando de la bolsa acumulada, acreditación proporcional de planes y bonos.
  * `lib/core/providers/license_provider.dart`: Métodos reactivos para alternar modo (`INCLUDED` vs `BYOK`) y reflejar el saldo acumulado en tiempo real.
* **Archivos a Crear:**
  * `test/ai_cumulative_quota_and_multiprofile_test.dart`: Suite completa que certifique:
    1. Incremento de esquema SQLite a `v36` y migración justa de datos previos desde `v35`.
    2. Bolsa compartida: Perfil A y Perfil B debitan de la misma bolsa de 50 usos.
    3. Persistencia acumulativa: El cambio de mes (simulado) no borra el saldo restante.
    4. Suma acumulativa al renovar planes o cargar bolsas extra (+150).
    5. Aislamiento estricto de consumo según `ai_selected_mode`.

---

### FASE 2: Rediseño de `AiSettingsScreen` y Bóveda Segura Multi-Clave BYOK
* **Objetivo:** Implementar la bóveda en `FlutterSecureStorage` con soporte multi-clave, alias obligatorio, cifrado visual en lista, endpoint canónico inmune a obsolescencia para comprobación real de conexión, borrado de clave plana y selector de modo en la pantalla.
* **Archivos a Crear:**
  * `lib/core/services/ai/ai_vault_service.dart`: Servicio de bóveda segura (CRUD de claves con alias, encriptadas en Keystore, con migración de clave anterior y borrado en `SharedPreferences`).
  * `lib/core/models/ai_key_model.dart`: Modelo de clave con id, alias, clave enmascarada y estado de prueba.
  * `test/ai_vault_and_byok_security_test.dart`: Suite que verifique registro con alias, máscara visual, prueba de conexión con endpoint canónico de modelos y conmutación de claves.
* **Archivos a Modificar:**
  * `lib/core/config/api_constants.dart`: Conexión con `AiVaultService`, priorización de clave activa y aislamiento cuando el modo seleccionado es MochilaLista.
  * `lib/features/profile/screens/ai_settings_screen.dart`: Rediseño completo:
    * Selector superior de modo (Cuota MochilaLista vs. Clave Propia BYOK) con banner de licencia.
    * Eliminación definitiva del texto de reinicio mensual del 1 de cada mes.
    * Lista de claves con alias, máscara, botones `Activar`, `Probar`, `Copiar`, `Editar`, `Eliminar`.
    * Tarjeta educativa con botón directo `Abrir Google AI Studio` vía `url_launcher`.
  * `lib/features/auth/screens/license/license_status_and_activation_screen.dart`: Actualización del chip de IA para mostrar la cuota acumulada compartida.

---

### FASE 3: Sistema de Respaldo Opcional en Google Drive Cifrado AES-256-GCM
* **Objetivo:** Implementar la infraestructura de respaldo en Google Drive (`drive.appdata`) con derivación determinista de clave (`googleUser.id`), selector de historial fechado (últimas 5 copias), restauración en caliente en teléfono nuevo y cliente ligero `GoogleAuthClient`.
* **Archivos a Crear:**
  * `lib/core/services/backup/i_google_drive_backup_service.dart`: Interfaz abstracta del servicio de nube.
  * `lib/core/services/backup/google_drive_backup_service.dart`: Implementación real con `google_sign_in`, `googleapis` Drive v3 en `drive.appdata` y `GoogleAuthClient`.
  * `lib/features/profile/widgets/google_drive_backup_sheet.dart`: Modal de configuración en *Respaldos y Seguridad* con botón vincular cuenta, historial de copias fechadas y switch Wi-Fi.
  * `test/google_drive_backup_and_cloning_rule_test.dart`: Suite con `MockGoogleDriveBackupService` que valide creación de copias fechadas, derivación recuperable con `googleUser.id`, rotación FIFO de 5 copias y activación de regla anti-clonación al restaurar en hardware distinto.
* **Archivos a Modificar:**
  * `pubspec.yaml`: Incorporación de `google_sign_in: ^6.2.2`, `googleapis: ^13.2.0`, `http: ^1.2.0`.
  * `android/app/src/main/AndroidManifest.xml`: Verificación de permisos de red y estado de red.
  * `lib/core/services/startup_flow_coordinator.dart`: Gancho opcional de onboarding (invitación a restaurar desde Google Drive si es instalación limpia, con botón `Omitir por ahora`) y disparador silencioso de respaldo periódico en reanudación.
  * `lib/features/profile/screens/business_backup_screen.dart`: Sección dedicada a Copia en Google Drive junto al respaldo local.

---

### FASE 4: Regresión Global, Compilación Android y Certificación Final
* **Objetivo:** Ejecutar la suite integral de pruebas del Bloque 2, verificar 0 issues en analizadores estáticos y compilar el APK de prueba en terminal real.
* **Comandos de Certificación:**
  1. `cd app_movil; flutter analyze --no-pub lib test` -> `No issues found!`.
  2. `cd mochilalista_admin; dart analyze` -> `No issues found!`.
  3. Batería completa de pruebas del Bloque 2 + Regresión Plan 07:
     * `test/ai_cumulative_quota_and_multiprofile_test.dart`
     * `test/ai_vault_and_byok_security_test.dart`
     * `test/google_drive_backup_and_cloning_rule_test.dart`
     * Suites de seguridad, licencias y EULA de Plan 07.
  4. Compilación real del APK: `flutter build apk --debug`.

---

## 7. PROTOCOLO DE APROBACIÓN Y TRANSICIÓN A LA FASE 1

Este documento establece el marco maestro completo, sin omisiones ni simplificaciones, para dotar a MochilaLista de:
1. Una política de IA atractiva, justa y acumulativa que fidelice a los comerciantes.
2. Una bóveda segura multi-clave BYOK que ofrezca libertad técnica total sin comprometer la seguridad.
3. Un mecanismo moderno de respaldo en la nube de Google Drive que resuelva de forma definitiva la pérdida de datos en cambios de celular sin arriesgar la soberanía offline de la app.

Queda a la espera de la revisión y aprobación formal del titular para iniciar la ejecución de la **FASE 1 (Cuota IA Acumulativa, Bolsa Compartida Multi-Perfil y Migración SQLite v36)**.
