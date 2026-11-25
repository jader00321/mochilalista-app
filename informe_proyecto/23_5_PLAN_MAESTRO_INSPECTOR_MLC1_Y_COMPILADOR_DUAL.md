# PLAN MAESTRO 23.5: INSPECTOR FORENSE TRI-PROTOCOLO AUTOEXPLICATIVO (`ML9` + `MLS1` + `MLC1`) Y COMPILADOR DUAL OFICIAL GUIADO

> **Documento Técnico y Operativo Oficial — Versión 1.4 (`100 % COMPLETADO Y CERTIFICADO` — Fases 1 a 4 Cerradas)**  
> **Proyecto:** MochilaLista POS Comercial & MochilaLista Admin Platform  
> **Punto de Partida:** Cierre del Plan Maestro 23 (`e84583a` en rama `dev/mejoras-v9.0-comercializacion-seguridad` — `230/230` pruebas en verde en `mochilalista_admin/` y `1,435/1,435` en `app_movil/`)  
> **Objetivo:** Elevar la claridad operativa y la fiabilidad de distribución sin tocar `app_movil/` mediante dos pilares autoexplicativos:
> 1. **Inspector Forense Tri-Protocolo (`#tabInspector`):** Auditoría integral de fichas declarativas **`MLC1-...`** (texto plano, mensaje de WhatsApp e imagen QR PNG) junto a **`ML9-...`** y **`MLS1-...` / `.mlsync`**, con guía visual interactiva integrada en la propia pestaña.
> 2. **Compilador Dual Oficial Único y Guiado (`compilar_release_dual.bat`):** Lanzador maestro en raíz que compila, certifica forensemente (`aapt2` + `apksigner` compatible SDK `<= 36.x` y `37.0.0+`) y entrega ambos APKs oficiales ofuscados (**Universal** + **ARM64 Ligero**) en `C:\Users\vjuli\Documents\v-app-offline apks\`, acompañado de mini-guía rápida con comandos copiables en `#tabReleaseManager` y actualización del Manual Operativo 05.

> [!IMPORTANT]
> **Salvaguardas Técnicas Preventivas Integradas (Versión 1.1):**
> 1. **Fase 1 (Contrato HTTP `200` en fallo forense `MLC1` y tolerancia numérica):** Cuando una ficha `MLC1-...` falla la firma Ed25519 o el esquema, `POST /api/licenses/inspect` responde HTTP `200` con `ok: false`, `valid: false`, `isValid: false`, `token_kind: 'MLC1'`, `security_alert` y `diagnostic_payload` (consistente con `ML9`/`MLS1` para que la UI muestre el dictamen rojo forense). Los precios `pr` en `diff_vs_current` se comparan con tolerancia `0.005` (`(a - b).abs() < 0.005`) y los textos con `.trim()`.
> 2. **Fase 2 (Compatibilidad QR `512 px`):** Al elevar el canvas interno de `#mlc1QrContainer` a `512 px`, confirmar que `plan23_fase3_mlc1_desktop_emitter_test.dart`, `downloadQrWithQuietZone` y `copyMlc1QrToClipboard` continúan `100 %` en verde.
> 3. **Fase 3 (UTF-8 limpio y cero secretos en `compilar_release_dual.ps1`):** Configurar `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8` y `$OutputEncoding = [System.Text.Encoding]::UTF8` para tildes limpias en Windows, garantizando que jamás se impriman contraseñas o líneas sensibles de `key.properties`.

---

## 0. BLINDAJE ESTRICTO DE ALCANCE, PRODUCCIÓN, SEGURIDAD Y ESTÁNDARES

Antes de iniciar cualquier fase de implementación, rigen de manera obligatoria las siguientes reglas de protección:

1. **Intocabilidad absoluta de `app_movil/`:**
   * **NO modificar** ningún archivo de código fuente, configuración ni assets dentro de `app_movil/` (permanece intacto en **`v9.41.0+85`**).
   * **NO crear tags**, **NO hacer merge a `main`**, y **NO recompilar APKs innecesariamente** durante las pruebas del compilador dual (las pruebas automatizadas y de certificación sobre el release real usan `--verify-only` y mocks aislados en `Directory.systemTemp`).
2. **Prohibición estricta sobre archivos de producción y secretos:**
   * Queda **prohibido** modificar, leer destructivamente o commitear:
     * `mochilalista_admin/data/prod_clients_db.json`
     * `mochilalista_admin/data/prod_releases_db.json`
     * `mochilalista_admin/data/owner_config.json`
     * `mochilalista_admin/data/vault_keyring.json`
     * `mochilalista_admin/data/vault_settings.json`
     * `mochilalista_admin/data/.apk_inspection_cache.json`
     * `mochilalista_admin/private_keys/`
     * `mochilalista_admin/releases_apks/`
     * `app_movil/android/key.properties`
   * Toda prueba unitaria, HTTP, Node.js o PowerShell de este plan debe operar exclusivamente dentro de directorios temporales aislados (`Directory.systemTemp.createTempSync(...)`) y limpiarse en `tearDown()`.
3. **Estándar visual y compatibilidad regresiva estricta en `mochilalista_admin/web/`:**
   * **Cero emojis crudos** en controles de interfaz web (`index.html`, `styles.css`, y bloques UI de `admin_app.js`), utilizando únicamente `<svg>` con atributos `width` y `height` explícitos (verificado por tests existentes en `#tabReleaseManager` y `#tabInspector`).
   * **Soporte completo de temas:** Modo oscuro (**Deep Obsidian**) y modo claro (**`[data-theme="light"]` Executive Slate**).
   * **Invariantes contractuales verificados en pruebas previas de `admin_app.js`:**
     * Conservar intacto el bloque de funciones puras entre `function formatApkSizeMb(` (`admin_app.js:6905`) y `function renderSignatureStatusBadge(` (`admin_app.js:6933`).
     * Conservar el marcador inicial de la sección 5 empezando exactamente con `// =================== 5. INSPECTOR FORENSE DUAL` (`admin_app.js:10146`) y el fin antes de `// =================== 6. FINANZAS` (`admin_app.js:10916`), usado por `plan22_fase4_sync_and_inspector_test.dart`.
     * Conservar intacto el bloque entre `let isVerifyAllCatalogRunning = false;` (`admin_app.js:7353`) y `/**\n * Carga notas compañeras` (extraído por `plan23_fase6_apk_cache_verify_all_test.dart`).
     * Usar comprobaciones nulas (`?.` / `if (el)`) para cualquier nuevo elemento DOM en `admin_app.js` para mantener compatibilidad al 100 % con los preámbulos Node.js de pruebas existentes.
4. **Regla de no-colgado y salidas deterministas:**
   * Todos los comandos y scripts deben ejecutarse de forma síncrona y finalizar limpiamente.
   * En `compilar_release_dual.bat`, `--help` / `-h` / `/?` y cualquier invocación con `--no-pause` o con entrada redirigida deben terminar inmediatamente sin `pause` devolviendo código de salida real (`0` o `!= 0`).

---

## 1. AUDITORÍA FORENSE DEL CÓDIGO ACTUAL (ESTADO EN `e84583a`)

La inspección directa de los archivos en `HEAD` (`e84583a`) confirmó el estado exacto de la arquitectura y detectó **10 hallazgos técnicos clave** que el Plan Maestro 23.5 resuelve de raíz:

### 1.1 Auditoría Backend (`mochilalista_admin/lib/` y `mochilalista_admin/server.dart`)

| # | Archivo y Líneas Auditadas | Hallazgo Verificado en Código Actual | Solución Plan 23.5 |
|---|---|---|---|
| **B1** | `mochilalista_admin/lib/commercial_config_sync_service.dart:1-723` | Posee `buildCanonicalPayload`, `generateSignedToken`, `verifySignedToken`, `validateDecodedPayloadSchema`, `buildSummaryFromPayload`, `buildSummaryFromConfig` y `generateOwnerLegalIdentityDartSnippet`, pero **carece de `extractMlc1Token(String rawInput)` y `looksLikeMlc1Input(String rawInput)`** (que sí existen en `app_movil/lib/core/services/license/commercial_config_sync_service.dart:135-157`). `verifySignedToken` exige `clean.startsWith('MLC1-')`, rechazando mensajes completos de WhatsApp con `INVALID_PREFIX`. | Implementar `static String extractMlc1Token(String rawInput)` y `static bool looksLikeMlc1Input(String rawInput)` con paridad exacta respecto a `app_movil/` (`RegExp(r'mlc1-([A-Za-z0-9_\-+=]{10,}\.[A-Za-z0-9_\-+=]{20,})', caseSensitive: false)`). |
| **B2** | `mochilalista_admin/lib/commercial_config_sync_service.dart:420-452` | Cuando `verifySignedToken()` detecta `INVALID_SIGNATURE`, `INVALID_SCHEMA` o `INVALID_JSON`, retorna inmediatamente sin decodificar de forma segura los campos legibles del payload para diagnóstico forense. | Añadir método auxiliar puro `tryDecodePayloadDiagnostic(String rawInput)` que intente leer Base64Url/JSON de forma no confiable (solo lectura diagnóstica, acotada a `maxPayloadBytes`, preservando `valid: false`) para mostrar qué revisión o valores intentaba transportar una ficha alterada o con firma ajena. |
| **B3** | `mochilalista_admin/server.dart:89-99, 441-450` | `handleRequest()` acepta `CommercialConfigSyncService? commercialSyncService` (`server.dart:413`), pero **omite reenviar `commercialSyncService: commercialSyncService` al invocar `_handleApiRoute(...)`** (`server.dart:442-449`), y `main()` (`server.dart:90`) tampoco inyecta instancia compartida. | Reenviar `commercialSyncService: commercialSyncService` en `handleRequest()` -> `_handleApiRoute()` y crear/inyectar instancia compartida en `main()`. |
| **B4** | `mochilalista_admin/server.dart:1648-1726` | `POST /api/licenses/inspect` despacha únicamente `CLIENT_SYNC` (`MLS1-` / `MLSYNC_V1`) y `LICENSE_TOKEN` (`ML9-` vía `signer.inspectToken`). No detecta `MLC1-` ni compara la ficha contra `configService.commercialSyncRevision` y `owner_config.json`. | Detectar `MLC1-` (`CommercialConfigSyncService.looksLikeMlc1Input`) **antes** que `MLS1-` y `ML9-`, verificar con clave pública activa de `signer` y separación de dominio `MLC1-$payloadB64`, y retornar contrato rico con `token_kind: 'MLC1'`, `input_kind: 'COMMERCIAL_CONFIG'`, `revision_status` y `diff_vs_current`. |

### 1.2 Auditoría Frontend (`#tabInspector`, `#modalCommercialConfigSync` y `#tabReleaseManager`)

| # | Archivo y Líneas Auditadas | Hallazgo Verificado en Código Actual | Solución Plan 23.5 |
|---|---|---|---|
| **F1** | `index.html:69, 807-892` y `admin_app.js:371, 10146-10914` | La barra lateral (`title="Inspector Forense de Tokens ML9"`), `tabTitles.tabInspector` (`'Inspector Forense ML9'`), subtítulo, zona dropzone y placeholder del textarea solo mencionan `ML9` / `MLS1`. No existe guía visual de los 3 protocolos, ni tarjeta dedicada `#inspectMlc1AuditCard`, ni badge `MLC1` en `#inspectorSessionHistoryPanel`. | Añadir `#btnToggleInspectorGuide` + `#inspectorProtocolGuide`, actualizar copys a los **3 protocolos** (`ML9`, `MLS1`/`.mlsync`, `MLC1`), crear `#inspectMlc1AuditCard` con `renderInspectCommercialConfig()`, integrar `MLC1` en `copyInspectorForensicReport` e historial de sesión, manteniendo 100 % compatibilidad con `ML9` y `MLS1`. |
| **F2** | `admin_app.js:13830`, `styles.css:4753` y `admin_app.js:10427-10461` | **Hallazgo crítico de lectura óptica QR `MLC1`:** Un token real `MLC1-...` mide ~1,400–2,100 bytes (~137×137 módulos QR). `#modalCommercialConfigSync` lo renderiza actualmente con `renderSafeQrCode(..., 196, ...)` (~1.43 px/módulo), lo que puede producir solapamiento subpíxel en la imagen PNG descargada e impedir que `jsQR` (`inversionAttempts: 'dontInvert'`) lo lea desde captura/PNG. | Subir la resolución interna del QR de `#mlc1QrContainer` a `512` px manteniendo su tamaño visual de `196x196` px en CSS (`.mlc1-qr-white-box canvas/img`), y reforzar `handleOpticalQrFile()` con `inversionAttempts: 'attemptBoth'` + reintento con reescalado `2x`/`3x` sin suavizado (`imageSmoothingEnabled = false`) para capturas pequeñas de alta densidad. |
| **F3** | `index.html:689-703`, `admin_app.js:8893-9178` | `#tabReleaseManager` no dispone de ninguna guía rápida ni acceso a comandos de `compilar_release_dual.bat` en su cabecera. | Añadir botón `#btnToggleDualBuildGuide` (`Guía de Compilación Dual`) y panel colapsable `#dualBuildGuidePanel` con tabla Universal vs ARM64, 3 comandos copiables y flujo en 4 pasos (100 % libre de emojis y con `<svg>` acotados). |

### 1.3 Auditoría de Compilación Dual, Android SDK `37.0.0` y Documentación

| # | Archivo / Entorno Auditado | Hallazgo Verificado en Entorno Real | Solución Plan 23.5 |
|---|---|---|---|
| **C1** | `compilar_apk_comercial.bat` (`1-81`), `compilar_apk_arm64.bat` (`1-85`), `app_movil/pubspec.yaml:4` (`9.41.0+85`) | Los dos `.bat` actuales compilan por separado, dejan los APKs en `app_movil\build\app\outputs\flutter-apk\`, **no** renombran por SemVer ni copian a `C:\Users\vjuli\Documents\v-app-offline apks\`, **no** ejecutan `aapt2`/`apksigner` y **no** aceptan `--help`, `--dry-run`, `--verify-only` ni `--no-pause`. | Mantener intactos los dos `.bat` legados y crear **`compilar_release_dual.bat`** + **`scripts/compilar_release_dual.ps1`** con flujo guiado `[Paso 1/6]`..`[Paso 6/6]`, flags completos, parseo dinámico de `pubspec.yaml` y mensajes accionables `QUÉ FALLÓ` + `CÓMO SOLUCIONARLO`. |
| **C2** | `C:\Users\vjuli\AppData\Local\Android\Sdk\build-tools\37.0.0` y `v-app-offline apks\mochilalista_v9.41*.apk` | Verificado en vivo sobre SDK `37.0.0`: `aapt2.exe` reporta `versionCode='85'` (Universal: `arm64-v8a`, `armeabi-v7a`, `x86_64`) y `versionCode='2085'` (ARM64: `arm64-v8a`), sin `application-debuggable`; `apksigner.bat` SDK `37.0.0` imprime `V2 Signer: certificate SHA-256 digest: 7c43addc34776f3974eac23fdacc47599efd5393a4dbb28672d06899833ffd20` (mientras SDK `<= 36.x` imprime `Signer #1 certificate SHA-256 digest:`). | Implementar parser dual compatible con SDK `<= 36.x` y `37+` (excluyendo `SourceStamp`), verificación estricta de `com.mochilalista.app`, `versionName`, `versionCode`, ABIs, rechazo inmediato ante `application-debuggable` y rechazo inmediato ante huella distinta de `7c43addc...3ffd20`. |
| **C3** | `informe_proyecto/05_MANUAL_OPERATIVO_DEL_PROPIETARIO_Y_COMANDOS_RELEASE.md:41, 211-223, 358-426` | El índice del punto 3 (`05_MANUAL...`:41) dice `(Release Manager — Planes 19, 22 y 22.5)` y apunta al ancla `#guía-3-...-planes-19-22-y-225`, mientras el encabezado real (`:429`) incluye `y 23`. Además faltan la tabla comparativa/guía tri-protocolo en `1.6` y la guía completa de `compilar_release_dual.bat` en `Guía 2`. | Actualizar `1.3` (ítem 5), `1.6` (Inspector Tri-Protocolo + Guía de Protocolos), `Guía 2` (sección completa de `compilar_release_dual.bat` con flags, lectura de resumen y tabla de solución de errores) y corregir el enlace del índice punto 3 (`Planes 19, 22, 22.5 y 23`). |

---

## 2. DISEÑO ARQUITECTÓNICO DETALLADO POR PILAR

### 2.1 Pilar 1: Inspector Forense Tri-Protocolo (`ML9` + `MLS1` + `MLC1`) con Guía Operativa Integrada

#### A. Backend: `CommercialConfigSyncService` + `POST /api/licenses/inspect` (`server.dart`)

1. **Extracción tolerante paritaria con `app_movil/` (`mochilalista_admin/lib/commercial_config_sync_service.dart`):**
   * Agregar `static String extractMlc1Token(String rawInput)`:
     * Limpia espacios externos y extrae `MLC1-<payload_b64url>.<sig_b64url>` mediante `RegExp(r'mlc1-([A-Za-z0-9_\-+=]{10,}\.[A-Za-z0-9_\-+=]{20,})', caseSensitive: false)`, normalizando el prefijo exacto a `MLC1-`.
     * Soporta de forma transparente: token puro, mensaje completo de WhatsApp emitido desde `#modalCommercialConfigSync` (con asteriscos, pasos numerados, saltos `\r\n` o `\n`) y la cadena decodificada de una imagen QR PNG.
   * Agregar `static bool looksLikeMlc1Input(String rawInput)`:
     * Retorna `true` si `rawInput.trim().toUpperCase().startsWith(tokenPrefix)` o si `extractMlc1Token(rawInput)` no es vacío o si contiene el prefijo delimitado `RegExp(r'(?:^|\s)MLC1-', caseSensitive: false)` (evitando que tokens `MLC1-` truncados o alterados caigan erróneamente al parser `ML9-`).
   * Actualizar `verifySignedToken(String rawToken, ...)`:
     * Intentar extraer con `extractMlc1Token(rawToken)` cuando `rawToken` contenga texto envolvente antes de verificar la firma sobre `utf8.encode('MLC1-$payloadB64')`.
     * Añadir `payload_bytes` y `token_bytes` también en respuestas exitosas (además de `issued_at` ISO UTC y `issued_at_lima`), y añadir método seguro `Map<String, dynamic>? tryDecodePayloadDiagnostic(String rawInput)` que intente decodificar el segmento `payloadB64` (respetando la cota `<= maxPayloadBytes` y JSON `Map`) únicamente para inspección forense de solo lectura cuando la firma Ed25519 o el esquema hayan fallado, **sin marcar nunca `valid: true`**.

2. **Enrutamiento Tri-Protocolo y Enriquecimiento en `POST /api/licenses/inspect` (`mochilalista_admin/server.dart`):**
   * Orden de detección determinista en `/api/licenses/inspect`:
     1. **`MLC1-...` (`CommercialConfigSyncService.looksLikeMlc1Input(token)`)** — evaluado primero.
     2. **`MLS1-...` / `.mlsync`** (`CLIENT_SYNC`).
     3. **`ML9-...`** (`LICENSE_TOKEN`).
   * Para entradas `MLC1-`:
     * Cargar `signer.loadMasterKey()` si `!signer.isLoaded` (en entorno real) o usar `signer.publicKeyBytes` ya cargado (en tests con `initWithSeed`). Si no existe clave pública disponible, responder `valid: false` con `status: 'MISSING_PUBLIC_KEY'`.
     * Ejecutar `syncService.verifySignedToken(token, signer: signer)`.
     * **Si `valid == true`:** construir `current_config_comparison` comparando contra `configService.config` y `configService.commercialSyncRevision`:
       * `revision_status` + `revision_status_label` + `recommendation`:
         * Si `tokenRev == localRev` (`localRev >= 1`):
           * `revision_status`: `'CURRENT'`
           * `revision_status_label`: `'Revisión vigente en Admin'`
           * `recommendation`: `'Revisión vigente actual en Admin — Lista para compartir con tus clientes.'`
         * Si `tokenRev < localRev`:
           * `revision_status`: `'SUPERSEDED'`
           * `revision_status_label`: `'Revisión anterior a la local'`
           * `recommendation`: `'Revisión anterior — Los celulares que ya aplicaron la Rev. #$localRev la rechazarán por protección anti-downgrade; genera una ficha nueva si deseas actualizarlos.'`
         * Si `tokenRev > localRev` (incluyendo cuando local está en `#0` sin emisiones previas o en otro equipo):
           * `revision_status`: `'AHEAD_OR_EXTERNAL'`
           * `revision_status_label`: `'Revisión superior a la local'`
           * `recommendation`: `'Revisión superior a la local — Emitida en otro equipo o antes de restaurar un respaldo.'`
       * `diff_vs_current`: comparar contra un snapshot canónico de `configService.config` (`buildCanonicalPayload(configService.config, revision: localRev < 1 ? 1 : localRev)`):
         * `products_diff`: lista ordenada de los **8 productos comerciales** (`mensual`, `trimestral`, `semestral`, `anual`, `perpetua`, `bolsa_extra_ia`, `pase_anual_updates`, `migracion`) indicando para cada uno `id`, `label`, `token_values` (`pr`, `d`, `ai`, `um`), `current_values` (`pr`, `d`, `ai`, `um`), `changed_fields` (`['pr', 'ai', ...]`) y `matches` (`bool`).
         * `channels_diff`: lista ordenada de los **5 canales de soporte y pago** (`sup`, `yh`, `yp`, `bcp`, `bbva`) con `key`, `label`, `token_value`, `current_value`, `matches` (`bool`).
         * `total_differences` (`int`), `matches_current` (`bool`).
     * **Si `valid == false`:** intentar `tryDecodePayloadDiagnostic(token)`. Si existen campos legibles, retornarlos en `diagnostic_payload` y `diagnostic_summary` (manteniendo `valid: false`, `isValid: false`, `payload: null` o `diagnostic_only: true` bien separado para que ningún consumidor confíe en su contenido) y enviar:
       * `security_alert`: `'FIRMA ED25519 INVÁLIDA O FICHA ALTERADA — No compartir ni aplicar; regenera una ficha oficial desde Configuración'`
   * Contrato completo de respuesta JSON para `MLC1`:
     ```json
     {
       "ok": true,
       "input_kind": "COMMERCIAL_CONFIG",
       "token_kind": "MLC1",
       "valid": true,
       "isValid": true,
       "status": "VALID",
       "error": null,
       "domain_separated": true,
       "domain_message_prefix": "MLC1-",
       "revision": 3,
       "schema_version": 1,
       "issued_at": "2026-11-25T16:40:00.000Z",
       "issued_at_unix": 1795624800,
       "issued_at_lima": "25/11/2026 11:40:00 (Lima GMT-5)",
       "payload_bytes": 1280,
       "token_bytes": 1810,
       "max_payload_bytes": 8192,
       "payload": { "...": "..." },
       "summary": { "...": "..." },
       "current_config_comparison": {
         "local_revision": 3,
         "token_revision": 3,
         "revision_status": "CURRENT",
         "revision_status_label": "Revisión vigente en Admin",
         "recommendation": "Revisión vigente actual en Admin — Lista para compartir con tus clientes.",
         "diff_vs_current": {
           "matches_current": true,
           "total_differences": 0,
           "products_diff": [],
           "channels_diff": []
         }
       }
     }
     ```
     *(Nota: si `valid == false`, incluir `ok: false`, `valid: false`, `isValid: false`, `error`, `status`, `security_alert`, `diagnostic_payload`, `diagnostic_summary`, manteniendo `token_kind: 'MLC1'` y `input_kind: 'COMMERCIAL_CONFIG'` para renderizar la alerta roja forense).*

#### B. Frontend `#tabInspector` (`web/index.html`, `web/css/styles.css`, `web/js/admin_app.js`)

1. **Cabecera y Panel Guía Interactiva de los 3 Protocolos (`#btnToggleInspectorGuide` + `#inspectorProtocolGuide`):**
   * Actualizar tooltip/título en Sidebar (`title="Inspector Forense Tri-Protocolo (ML9 / MLS1 / MLC1)"`) y `tabTitles.tabInspector` (`'Inspector Forense (ML9 / MLS1 / MLC1)'`).
   * En `.card-header` de `#tabInspector`, añadir el botón limpio con `<svg width="15" height="15">` explícito:
     * **`Guía de Protocolos (ML9 / MLS1 / MLC1)`** (`id="btnToggleInspectorGuide"`, `aria-expanded="false"`, `aria-controls="inspectorProtocolGuide"`).
   * Debajo de la cabecera (colapsado por defecto con `style="display:none;"`), insertar `#inspectorProtocolGuide`:
     * **Grid de 3 tarjetas comparativas claras:**
       1. **`ML9-...` — Licencias y Bonos IA (`Admin -> Celular`):** Qué es (llave criptográfica Ed25519 que activa planes o suma escaneos IA), dónde se genera (`Generar Licencia`), cómo la usa el cliente (pega el código o escanea el QR en `Perfil > Licencia`) y qué verifica el Inspector (firma auténtica, vigencia, créditos IA y si el Nonce ya fue canjeado o sigue pendiente).
       2. **`MLS1-...` / `.mlsync` — Diagnóstico y Telemetría (`Celular -> Admin`):** Qué es (reporte del estado real del celular firmado con HMAC-SHA256), quién lo genera (la app del cliente al pedir soporte o compartir estado), qué haces con él (importarlo en Cartera CRM/Ficha 360° o auditarlo aquí para verificar saldo IA real, versión APK, respaldo Drive y rescatar migraciones `PENDIENTE_MIGRACION`).
       3. **`MLC1-...` — Tarifas y Medios de Pago (`Admin -> Celular`):** Qué es (ficha 100 % declarativa de precios y cuentas Yape/Plin/BCP/BBVA firmada con Ed25519, **cero scripts ejecutables**), dónde se genera (`Configuración > Sincronizar con App Móvil`), cómo la usa el cliente (pega o escanea el QR en `Licencia y Activación`) y qué verifica el Inspector (firma auténtica con separación de dominio, estado de revisión anti-downgrade y diferencias contra tu configuración actual).
     * **Mini-guía de las demás herramientas de la ventana:**
       * **Lector Óptico QR:** Arrastra capturas PNG o archivos `.mlsync`/`.json` 100 % sin internet.
       * **4 Estados de Nonce (`ML9`):** `Canjeado en celular` (verde), `Emitido — Pendiente de canje` (azul), `Nonce futuro listo para canje` (ámbar) y `Superado / Histórico` (púrpura).
       * **`Copiar Informe Forense`:** Genera un resumen técnico listo para pegar en soporte o auditorías.
       * **Historial de Sesión:** Conserva las últimas 10 fichas auditadas en memoria de sesión sin modificar la base de datos.

2. **Entrada Tri-Protocolo y Lector Óptico QR Endurecido (`jsQR`):**
   * Actualizar el subtítulo, `#qrOpticalDropZone` y el `placeholder` de `#inspectTokenInput` para anunciar los **3 formatos** (`ML9-...`, `.mlsync` / `MLS1-...`, y `MLC1-...`).
   * Actualizar toast de campo vacío en `inspectToken()` para mencionar `ML9`, `MLS1` o `MLC1`.
   * Mejorar decodificación de QR de alta densidad (`MLC1`) sin internet:
     * En `#modalCommercialConfigSync` (`admin_app.js:13830`), generar el canvas de `#mlc1QrContainer` a `512px` manteniendo visualización `196x196` vía CSS (`.mlc1-qr-white-box canvas, .mlc1-qr-white-box img { width: 196px !important; height: 196px !important; image-rendering: pixelated; }`), logrando que el QR PNG descargado (`576x576` con *quiet zone* 32 px) sea nítido módulo a módulo.
     * En `handleOpticalQrFile()`, intentar `jsQR` con `inversionAttempts: 'attemptBoth'`; si falla en una imagen `< 600px` de ancho/alto, reintentar con reescalado entero `2x`/`3x` (`ctx.imageSmoothingEnabled = false`) y borde blanco temporal antes de recurrir a `BarcodeDetector`.

3. **Tarjeta Dedicada `renderInspectCommercialConfig(data, rawToken, options)` (`#inspectMlc1AuditCard`):**
   * En `#inspectResultContainer`, añadir `<div id="inspectMlc1AuditCard" style="display:none; margin-bottom:1rem;"></div>`.
   * Garantizar aislamiento limpio entre modos:
     * `renderInspectCommercialConfig()` oculta `#inspectLicenseClaimsWrapper`, `#inspectSyncAuditCard` y `#inspectMatchingClientBox`, y muestra `#inspectMlc1AuditCard`.
     * `renderInspectClientSync()` e `inspectToken()` (rama `ML9`) ocultan `#inspectMlc1AuditCard`.
     * `btnClearInspectToken` oculta `#inspectResultContainer` y limpia `#inspectMlc1AuditCard`.
   * Contenido de `#inspectMlc1AuditCard`:
     * **Banner de Veredicto Criptográfico (`#inspectStatusBadge`) + Guía de Siguiente Paso:**
       * Válido (`valid === true`): Verde esmeralda con sello Ed25519 + separación de dominio `MLC1-` + mensaje `recommendation` claro sobre qué hacer a continuación según `revision_status` (`CURRENT`, `SUPERSEDED`, `AHEAD_OR_EXTERNAL`).
       * Inválido (`valid === false`): Banner rojo crítico con alerta explícita (*"FIRMA ED25519 INVÁLIDA O FICHA ALTERADA — No compartir ni aplicar; regenera una ficha oficial desde Configuración"*). Si existe `diagnostic_payload`, mostrar sección colapsable/resaltada de **"Lectura Diagnóstica (NO CONFIABLE — Firma fallida)"**.
     * **Tarjetas de Metadatos con Tooltips:**
       * `Revisión #N` (comparada contra `Revisión local #M` en `owner_config.json`).
       * `Estado frente a Admin` (badge semántico: verde `CURRENT`, ámbar `SUPERSEDED`, azul `AHEAD_OR_EXTERNAL`) + explicación breve.
       * `Fecha de Emisión (Lima GMT-5)` con `title="UTC: ..."` + `Separación de Dominio: MLC1- (Activa)`.
       * `Tamaño del Payload` (`X B / 8,192 B` + tamaño de token completo).
     * **Tabla Comparativa de los 8 Productos Comerciales (`products_diff`):**
       * Columnas: `Producto`, `Precio (S/)`, `Días`, `Bolsa IA`, `Updates (Meses)`, `Estado vs Config actual` (`Coincide` en verde o `Difiere de Config actual` en ámbar mostrando explícitamente `Ficha: ...` vs `Admin actual: ...`).
     * **Tarjeta de Soporte y Medios de Pago (`channels_diff`):**
       * Muestra `Soporte`, `Yape/Plin (Titular y Teléfono)`, `BCP` y `BBVA` comparando Ficha vs Admin actual (`Coincide` / `Difiere`).
     * **Barra de Acciones en 1 Clic:**
       * **`Copiar Informe Forense`** (`#btnInspectMlc1CopyReport` -> `copyInspectorForensicReport()` con snapshot `MLC1` enriquecido).
       * **`Abrir Configuración (#tabSettings)`** (`#btnInspectMlc1OpenSettings` -> `openSettingsFromInspector()`, navegando limpiamente a `#tabSettings` y actualizando `#currentViewName` y `.nav-tab.active`).

4. **Historial de Sesión Tri-Protocolo (`#inspectorSessionHistoryPanel`):**
   * Ampliar `renderInspectorSessionHistory()` para distinguir las 3 clases de badge:
     * `ML9` -> `badge-mono`
     * `MLS1` -> `badge-blue`
     * `MLC1` -> `badge-mlc1` (verde azulado / esmeralda adaptado a Dark y `[data-theme="light"]`).
   * Cada entrada `MLC1` muestra `MLC1`, `Revisión #N (Tarifas y Pagos)`, etiqueta de estado (`Vigente`, `Anterior`, `Superior` o `Firma inválida`), y timestamp en hora Lima con recarga completa en 1 clic.

---

### 2.2 Pilar 2: Script Único `compilar_release_dual.bat` Guiado, Autoexplicativo y Mini-Guía en `#tabReleaseManager`

#### A. Lanzador Maestro Dual (`compilar_release_dual.bat` + `scripts/compilar_release_dual.ps1`)

1. **Estructura y retrocompatibilidad:**
   * Conserva intactos `compilar_apk_comercial.bat` y `compilar_apk_arm64.bat`.
   * Crea **`compilar_release_dual.bat`** en la raíz del repositorio (`chcp 65001 >nul`) como punto de entrada único amigable para doble clic y CLI, delegando la lógica robusta, UTF-8 y testeable a **`scripts/compilar_release_dual.ps1`** (`powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\compilar_release_dual.ps1" %*`).

2. **Parseo dinámico desde `app_movil\pubspec.yaml`:**
   * Lee la línea `version: X.Y.Z+B` (ej. `9.41.0+85`) sin hardcodear versiones.
   * Calcula etiqueta de archivo oficial:
     * Si `Z == 0` -> `tag = "X.Y"` (`9.41.0+85` -> `9.41`).
     * Si `Z > 0` -> `tag = "X.Y.Z"` (`9.41.1+86` -> `9.41.1`).
   * Nombres de entrega en `<out-dir>` (por defecto `C:\Users\vjuli\Documents\v-app-offline apks`):
     * Universal: `mochilalista_v<tag>_atp.apk` (desde `app_movil\build\app\outputs\flutter-apk\app-release.apk`).
     * ARM64 Ligero: `mochilalista_v<tag>_arm64_atp.apk` (desde `app_movil\build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`).
     * Notas compañeras verificadas (solo lectura, **nunca sobrescritas**): `mochilalista_v<tag>_atp.txt` y `mochilalista_v<tag>_atp_cambios.txt`.

3. **Ayuda integrada clara (`--help` / `-h` / `/?`):**
   * Imprime una guía completa en español bien estructurada sin compilar ni pausar:
     * Comparación práctica: **APK Universal (~108 MB)** vs **APK ARM64 Ligero (~39 MB, ideal para WhatsApp Web `< 100 MB` y el 99 % de teléfonos Android modernos)**.
     * Tabla de parámetros con ejemplos listos para copiar y pegar (`compilar_release_dual.bat`, `--verify-only`, `--dry-run`, `--skip-analyze`, `--no-pause`, `--out-dir "ruta"`).
     * Listado exacto de los 6 pre-chequeos automáticos de entorno y firma oficial.

4. **Flujo Guiado en 6 Etapas Numeradas (`[Paso 1/6]` a `[Paso 6/6]`):**
   * **`[Paso 1/6]` Pre-chequeos de entorno y herramientas:**
     * Verifica `app_movil\pubspec.yaml` y extrae `versionName` + `versionCode`.
     * Verifica `app_movil\android\key.properties` y parsea `storeFile=...`, confirmando la existencia real del keystore `.jks` (relativo a `app_movil\android\` o ruta absoluta, **sin imprimir nunca contraseñas en consola ni logs**).
     * Verifica comando `flutter` en PATH (omitible solo si `--verify-only`).
     * Detecta la carpeta `build-tools` de Android SDK con la versión numérica más alta (revisando `$env:ANDROID_HOME`, `$env:ANDROID_SDK_ROOT` y `$env:LOCALAPPDATA\Android\Sdk`) que contenga `aapt2.exe` y `apksigner.bat` (validado en entorno real: `37.0.0` > `36.1.0` > `35.0.0`).
     * Verifica o crea (en modo compilación) la carpeta de salida `<out-dir>`.
   * **`[Paso 2/6]` Análisis estático (`flutter analyze --no-pub`):**
     * Ejecuta `flutter analyze --no-pub` en `app_movil/` (se omite explícitamente si se pasó `--skip-analyze` o `--verify-only` o `--dry-run`).
   * **`[Paso 3/6]` Compilación Universal ofuscada:**
     * Ejecuta `flutter build apk --release --obfuscate --split-debug-info=build/app_symbols --dart-define=PRODUCTION=true` y copia atómicamente `app-release.apk` a `<out-dir>\mochilalista_v<tag>_atp.apk`.
   * **`[Paso 4/6]` Compilación ARM64 Ligero ofuscada:**
     * Ejecuta `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/app_symbols --dart-define=PRODUCTION=true` y copia atómicamente `app-arm64-v8a-release.apk` a `<out-dir>\mochilalista_v<tag>_arm64_atp.apk`.
   * **`[Paso 5/6]` Certificación forense obligatoria sobre AMBOS APKs (`aapt2` + `apksigner`):**
     * **`aapt2 dump badging`:**
       * Confirma `package: name='com.mochilalista.app'`, `versionName == X.Y.Z` y `versionCode` válido (`B` en Universal; `2000 + B` o `B` en ARM64).
       * Confirma ABIs nativas (`arm64-v8a` presente en ARM64 sin `armeabi-v7a`/`x86_64`).
       * **Aborta con `exit 1`** si detecta la bandera `application-debuggable`.
     * **`apksigner verify --verbose --print-certs`:**
       * Soporta ambos formatos oficiales de `build-tools`:
         * SDK `37+`: `V2 Signer: certificate SHA-256 digest: ...`
         * SDK `<= 36.x`: `Signer #1 certificate SHA-256 digest: ...`
         * *(Excluye líneas `SourceStamp`)*.
       * **Aborta con `exit 1`** si la huella SHA-256 no coincide exactamente `1:1` con **`7c43addc34776f3974eac23fdacc47599efd5393a4dbb28672d06899833ffd20`**.
   * **`[Paso 6/6]` Resumen ejecutivo y Checklist de Siguientes Pasos:**
     * Muestra rutas completas de ambos APKs en `<out-dir>`, tamaño exacto en `MB` y `bytes`, porcentaje de ahorro del ARM64 frente al Universal, hashes `SHA-256` de ambos binarios, estado de presencia de `mochilalista_v<tag>_atp.txt` y `mochilalista_v<tag>_atp_cambios.txt` (sin tocar su contenido), y pasos claros para registrar ambos APKs en `MochilaLista Admin > Versiones APK`.

5. **Manejo de Errores Didáctico (`QUÉ FALLÓ` + `CÓMO SOLUCIONARLO`):**
   * Toda falla imprime un bloque estructurado claro indicando exactamente **`QUÉ FALLÓ`** y **`CÓMO SOLUCIONARLO`** (cubriendo: `flutter` ausente del PATH, falta `key.properties` o archivo `.jks`, Android SDK/`build-tools` ausente, errores en `flutter analyze`, fallo de `flutter build apk`, APK con `application-debuggable`, firma no oficial / ajena a `7c43addc...`, y APKs faltantes en `--verify-only`).

6. **Modos no interactivos y de verificación rápida:**
   * `--dry-run`: ejecuta `[Paso 1/6]` completo, muestra versión detectada, `build-tools` seleccionadas, comandos exactos y rutas destino sin compilar ni escribir en disco.
   * `--verify-only`: ejecuta `[Paso 1/6]` (sin requerir `flutter`), `[Paso 5/6]` sobre ambos APKs existentes de la versión actual en `<out-dir>` y `[Paso 6/6]`, certificando en segundos sin recompilar.
   * `--no-pause`: evita cualquier pausa al terminar o fallar, devolviendo el código de salida real.
   * `--skip-analyze` y `--out-dir "ruta"`: soportados con validación limpia de argumentos (parámetros desconocidos muestran `QUÉ FALLÓ` + sugerencia `--help` y salen con código `1`).

#### B. Mini-Guía Rápida de Compilación Dual en `#tabReleaseManager` (`web/index.html`, `web/css/styles.css`, `web/js/admin_app.js`)

1. **Botón en Cabecera (`#btnToggleDualBuildGuide`):**
   * Ubicado junto a `#btnOpenCreateRelease` en `.card-header` de `#tabReleaseManager`, con `<svg width="15" height="15">` acotado explícitamente y texto **`Guía de Compilación Dual`** (`aria-expanded="false"`, `aria-controls="dualBuildGuidePanel"`).
2. **Panel Colapsable `#dualBuildGuidePanel` (oscuro + `[data-theme="light"]`, 0 emojis crudos):**
   * **Tarjetas comparativas compactas:** **APK Universal (`~108 MB`)** vs **APK ARM64 Ligero (`~39 MB`, WhatsApp `< 100 MB`)**, indicando la ruta de salida `C:\Users\vjuli\Documents\v-app-offline apks\`.
   * **3 Comandos Listos con Micro-Botón `Copiar`:**
     1. `compilar_release_dual.bat` — Compilar versión nueva (Universal + ARM64)
     2. `compilar_release_dual.bat --verify-only --no-pause` — Verificar APKs actuales sin recompilar
     3. `compilar_release_dual.bat --dry-run --no-pause` — Simular validación de entorno
   * **Flujo en 4 Pasos para Publicar una Nueva Versión:**
     1. Actualizar versión en `app_movil/pubspec.yaml` y redactar notas `*_atp.txt` / `*_cambios.txt`.
     2. Ejecutar `compilar_release_dual.bat` desde la raíz del proyecto.
     3. Pulsar `Subir / Registrar Nueva Versión del APK`, seleccionar el **Universal** en `Biblioteca Oficial` y publicar.
     4. Abrir `Editar Versión` y vincular la variante **ARM64 Ligero** en la tarjeta correspondiente.

---

### 2.3 Pilar 3: Pruebas Automatizadas, Manual Operativo 05 y Cierre Limpio

1. **Cobertura automatizada en `mochilalista_admin/test/` (100 % aislada):**
   * **Fase 1 (`plan23_5_fase1_mlc1_inspector_backend_test.dart`):** `extractMlc1Token` (token puro, mensaje WhatsApp real con saltos `\r\n`, QR decodificado, entradas inválidas), `looksLikeMlc1Input`, verificación Ed25519 con separación de dominio, detección de adulteración + decodificación diagnóstica segura (`valid: false` + `security_alert`), HTTP `POST /api/licenses/inspect` devolviendo `CURRENT` / `SUPERSEDED` / `AHEAD_OR_EXTERNAL`, `diff_vs_current` (8 productos + soporte/Yape/BCP/BBVA) y retrocompatibilidad `ML9` / `MLS1`.
   * **Fase 2 (`plan23_5_fase2_mlc1_inspector_ui_test.dart`):** Auditoría HTML/CSS/JS (`#btnToggleInspectorGuide`, `#inspectorProtocolGuide`, `#inspectMlc1AuditCard`, `.badge-mlc1`, Dark + `[data-theme="light"]`, 0 emojis crudos, SVG acotados, bloque puro intacto) + ejecución Node.js real de `initInspectorEvents()`, toggle guía, `renderInspectCommercialConfig()` (válido + adulterado + diff vs config), `copyInspectorForensicReport()`, `openSettingsFromInspector()` y `#inspectorSessionHistoryPanel` con `MLC1` + `jsQR` `512px` / upscale helper.
   * **Fase 3 (`plan23_5_fase3_dual_compiler_test.dart`):** Validación real de `compilar_release_dual.bat --help --no-pause`, `--dry-run --no-pause`, `--verify-only --no-pause` sobre los APKs reales `v9.41.0+85` (sin recompilar) + pruebas en `Directory.systemTemp` validando parseo SemVer (`9.41.0+85` -> `9.41`, `9.41.2+87` -> `9.41.2`), bloques `QUÉ FALLÓ` / `CÓMO SOLUCIONARLO` ante faltantes, y mocks de `aapt2`/`apksigner` rechazando `application-debuggable` o firma no oficial y aceptando ambos formatos SDK `<= 36` y `37+`.
   * **Fase 4 (`plan23_5_fase4_release_guide_ui_test.dart`):** Auditoría HTML/CSS/JS de `#btnToggleDualBuildGuide` y `#dualBuildGuidePanel` en `#tabReleaseManager` (Dark + `[data-theme="light"]`, 0 emojis, SVG acotados, bloque puro y bloque `isVerifyAllCatalogRunning` intactos) + Node.js verificando toggle y copia de los 3 comandos + verificación de enlaces y secciones de `05_MANUAL_OPERATIVO_DEL_PROPIETARIO_Y_COMANDOS_RELEASE.md`.

2. **Actualización del Manual Operativo (`informe_proyecto/05_MANUAL_OPERATIVO_DEL_PROPIETARIO_Y_COMANDOS_RELEASE.md`):**
   * Corregir el enlace cosmético del punto 3 del índice (`Planes 19, 22, 22.5 y 23`).
   * Actualizar secciones `1.3` (ítem 5) y `1.6` con tabla comparativa y guía paso a paso de los **3 protocolos** (`ML9`, `MLS1`/`.mlsync`, `MLC1`) y todas las herramientas del Inspector Forense.
   * Agregar en **Guía 2** la documentación completa de **`compilar_release_dual.bat`** (tabla de flags, flujo guiado de 6 pasos, interpretación del resumen final y tabla de solución de errores frecuentes), manteniendo documentados los scripts legados como compatibilidad.

---

## 3. ORDEN DE FASES SECUENCIALES Y CRITERIOS DE ACEPTACIÓN

Cada fase se ejecutará, verificará y reportará en orden estricto antes de avanzar a la siguiente:

| Fase | Nombre y Alcance Exacto | Archivos a Crear / Modificar | Pruebas y Validación Obligatoria de Salida |
|---|---|---|---|
| **Fase 1** *(Completada)* | **Backend Tri-Protocolo `MLC1` en `CommercialConfigSyncService` y `POST /api/licenses/inspect`**<br>• `extractMlc1Token`, `looksLikeMlc1Input` y `tryDecodePayloadDiagnostic`.<br>• Reenvío limpio `commercialSyncService` en `handleRequest` -> `_handleApiRoute`.<br>• Detección `MLC1` prioritaria en `/api/licenses/inspect`, `revision_status` (`CURRENT` / `SUPERSEDED` / `AHEAD_OR_EXTERNAL`), `diff_vs_current` (8 productos + pagos/soporte) y alerta crítica en firma inválida. | • `mochilalista_admin/lib/commercial_config_sync_service.dart`<br>• `mochilalista_admin/server.dart`<br>• `mochilalista_admin/test/plan23_5_fase1_mlc1_inspector_backend_test.dart` | • `dart analyze` (`No issues found!`)<br>• `dart test` completo en `mochilalista_admin/` (`100 %` en verde, incluyendo `plan23_5_fase1_mlc1_inspector_backend_test.dart`, `license_signer_test.dart`, `client_offline_sync_and_migration_test.dart` y `plan23_fase3_mlc1_desktop_emitter_test.dart`) |
| **Fase 2** *(Completada)* | **Frontend `#tabInspector` Tri-Protocolo, Guía Visual Interactiva y Resiliencia QR `MLC1`**<br>• Sidebar/títulos, copys tri-protocolo, `#btnToggleInspectorGuide` + `#inspectorProtocolGuide`.<br>• `#inspectMlc1AuditCard` + `renderInspectCommercialConfig()`, `Abrir Configuración (#tabSettings)`, `Copiar Informe Forense` `MLC1`.<br>• Historial de sesión con badge `MLC1`, QR `512px` nítido en `#modalCommercialConfigSync` y `jsQR` con reescalado offline (`tryDecodeQrCanvasWithUpscale`).<br>• Soporte Dark + `[data-theme="light"]`, 0 emojis, SVG acotados. | • `mochilalista_admin/web/index.html`<br>• `mochilalista_admin/web/css/styles.css`<br>• `mochilalista_admin/web/js/admin_app.js`<br>• `mochilalista_admin/test/plan23_5_fase2_mlc1_inspector_ui_test.dart` | • `node --check` (`admin_app.js`, `qrcode.min.js`) -> `0`<br>• `dart analyze` (`No issues found!`)<br>• `dart test` completo en `mochilalista_admin/` (`100 %` en verde, incluyendo `plan23_5_fase2_mlc1_inspector_ui_test.dart`, `plan22_fase4_sync_and_inspector_test.dart`, `client_offline_sync_and_migration_test.dart` y `plan23_fase3_mlc1_desktop_emitter_test.dart`) |
| **Fase 3** *(Completada)* | **Compilador Dual Oficial Único y Guiado (`compilar_release_dual.bat` + `.ps1`)**<br>• Creación de `compilar_release_dual.bat` y `scripts/compilar_release_dual.ps1` (preservando `.bat` legados).<br>• SemVer dinámico, `--help`, 6 pasos guiados, `aapt2` + `apksigner` (SDK `<= 36` y `37+`), anti-debug, validación huella `7c43addc...`, resumen + checklist, `QUÉ FALLÓ`/`CÓMO SOLUCIONARLO`, `--dry-run`, `--verify-only`, `--skip-analyze`, `--no-pause`, `--out-dir`. | • `compilar_release_dual.bat`<br>• `scripts/compilar_release_dual.ps1`<br>• `mochilalista_admin/test/plan23_5_fase3_dual_compiler_test.dart` | • `compilar_release_dual.bat --help --no-pause`<br>• `compilar_release_dual.bat --dry-run --no-pause`<br>• `compilar_release_dual.bat --verify-only --no-pause` (sobre `v9.41.0+85` real)<br>• `dart test test/plan23_5_fase3_dual_compiler_test.dart` |
| **Fase 4** *(Completada)* | **Mini-Guía en `#tabReleaseManager`, Manual Operativo 05 y Cierre Certificado**<br>• `#btnToggleDualBuildGuide` + `#dualBuildGuidePanel` en `#tabReleaseManager` (Dark + Light, 0 emojis, 3 comandos copiables, flujo 4 pasos).<br>• Actualización de `05_MANUAL_OPERATIVO_DEL_PROPIETARIO_Y_COMANDOS_RELEASE.md` (índice punto 3, Guía 1.6 tri-protocolo, Guía 2 `compilar_release_dual.bat`).<br>• Certificación integral, auditoría `git check-ignore`/`git diff`, Acta de Cierre en este Plan 23.5 y push limpio a `dev/mejoras-v9.0-comercializacion-seguridad` (**sin** tag, **sin** merge a `main`, **`0` cambios en `app_movil/`**). | • `mochilalista_admin/web/index.html`<br>• `mochilalista_admin/web/css/styles.css`<br>• `mochilalista_admin/web/js/admin_app.js`<br>• `mochilalista_admin/test/plan23_5_fase4_release_guide_ui_test.dart`<br>• `informe_proyecto/05_MANUAL_OPERATIVO_DEL_PROPIETARIO_Y_COMANDOS_RELEASE.md`<br>• `informe_proyecto/23_5_PLAN_MAESTRO_INSPECTOR_MLC1_Y_COMPILADOR_DUAL.md` | • `node --check web/js/admin_app.js`<br>• `dart analyze` (`0` issues)<br>• `dart test` completo (`100 %` en verde)<br>• `compilar_release_dual.bat --help/--dry-run/--verify-only --no-pause`<br>• `git status` + `git diff --stat dev...` (`0` cambios en `app_movil/` y `0` secretos) |

---

## 4. CHECKLIST DE CERTIFICACIÓN FINAL (CERRADO AL 100 % EN FASE 4)

- [x] `POST /api/licenses/inspect` audita `MLC1-...` (texto puro, mensaje WhatsApp, QR PNG) con separación de dominio Ed25519, comparación de revisión (`CURRENT` / `SUPERSEDED` / `AHEAD_OR_EXTERNAL`), comparador de diferencias `diff_vs_current` y alerta crítica ante firma manipulada (Fase 1 certificada).
- [x] `#tabInspector` incluye guía desplegable de los 3 protocolos (`#inspectorProtocolGuide`), tarjeta dedicada `#inspectMlc1AuditCard`, informe forense copiable, enlace directo a `#tabSettings` e historial tri-protocolo (`ML9` / `MLS1` / `MLC1`) (Fase 2 certificada).
- [x] Lectura óptica `jsQR` y exportación QR `MLC1` (`512 px` + reescalado `tryDecodeQrCanvasWithUpscale`) verificadas para decodificación offline sin fallos por densidad (Fase 2 certificada).
- [x] `compilar_release_dual.bat` y `scripts/compilar_release_dual.ps1` certificados con `--help`, `--dry-run` y `--verify-only --no-pause` sobre los binarios oficiales `v9.41.0+85` y pruebas aisladas de error/anti-debug/firma (Fase 3 certificada).
- [x] `#tabReleaseManager` integra `#btnToggleDualBuildGuide` y `#dualBuildGuidePanel` con Dark/Light, SVG acotados y cero emojis crudos (Fase 4 certificada).
- [x] `05_MANUAL_OPERATIVO_DEL_PROPIETARIO_Y_COMANDOS_RELEASE.md` actualizado en Índice, Guía 1.3/1.6 y Guía 2 en UTF-8 limpio sin BOM (Fase 4 certificada).
- [x] `node --check`, `dart analyze` y la suite completa `dart test` en `mochilalista_admin/` al `100 %` en verde, `0` cambios en `app_movil/`, `0` archivos sensibles trackeados y push limpio a `dev/mejoras-v9.0-comercializacion-seguridad` (sin tag ni merge a `main`).

---

## 5. ACTA OFICIAL DE CIERRE Y CERTIFICACIÓN FINAL DEL PLAN MAESTRO 23.5

### 5.1 Resumen Consolidado de las 4 Fases Ejecutadas

1. **Fase 1 — Backend Tri-Protocolo `MLC1`:**
   - Implementación en `mochilalista_admin/lib/commercial_config_sync_service.dart` de `extractMlc1Token`, `looksLikeMlc1Input`, `tryDecodePayloadDiagnostic`, `buildDiagnosticSummaryFromMap` y `buildCurrentConfigComparison`.
   - Despacho prioritario `MLC1` y reenvío limpio de `commercialSyncService` en `mochilalista_admin/server.dart` (`POST /api/licenses/inspect`) evaluando `revision_status` (`CURRENT` / `SUPERSEDED` / `AHEAD_OR_EXTERNAL`), `diff_vs_current` (8 productos + 5 canales) y contrato rojo seguro (`HTTP 200`, `valid: false`, `payload: null`, `security_alert` + `diagnostic_payload`) ante adulteración.
   - Suite certificada en `mochilalista_admin/test/plan23_5_fase1_mlc1_inspector_backend_test.dart` (`4` pruebas).
2. **Fase 2 — Frontend `#tabInspector` Tri-Protocolo + Resiliencia QR `MLC1`:**
   - Renovación de `web/index.html`, `web/css/styles.css` y `web/js/admin_app.js` con títulos tri-protocolo (`ML9 / MLS1 / MLC1`), guía visual desplegable (`#btnToggleInspectorGuide` + `#inspectorProtocolGuide`), tarjeta forense dedicada `#inspectMlc1AuditCard`, `renderInspectCommercialConfig()`, acceso directo `openSettingsFromInspector()`, historial con insignia `.badge-mlc1`, exportación QR de `512 px` en `#modalCommercialConfigSync` y `tryDecodeQrCanvasWithUpscale()` en `jsQR` (soporte Dark + `[data-theme="light"]`, SVG acotados, cero emojis crudos).
   - Suite certificada en `mochilalista_admin/test/plan23_5_fase2_mlc1_inspector_ui_test.dart` (`2` pruebas).
3. **Fase 3 — Compilador Dual Oficial Único y Guiado (`compilar_release_dual.bat` + `.ps1`):**
   - Creación de `compilar_release_dual.bat` en raíz y `scripts/compilar_release_dual.ps1` preservando intactos los `.bat` históricos.
   - SemVer dinámico, flags `--help`, `--dry-run`, `--verify-only`, `--skip-analyze`, `--no-pause` y `--out-dir`, flujo guiado de 6 pasos, certificación `aapt2` + `apksigner` dual compatible con SDK `<= 36.x` y `37+`, manejo de errores `QUÉ FALLÓ` / `CÓMO SOLUCIONARLO`, codificación UTF-8 limpia y protección absoluta de contraseñas de `key.properties`.
   - Suite certificada en `mochilalista_admin/test/plan23_5_fase3_dual_compiler_test.dart` (`4` pruebas).
4. **Fase 4 — Mini-Guía en `#tabReleaseManager`, Manual Operativo 05 y Cierre:**
   - Adición de `#btnToggleDualBuildGuide` y `#dualBuildGuidePanel` en `#tabReleaseManager` (tarjetas `Universal ~108 MB` y `ARM64 Ligero ~39 MB`, 3 comandos con copia `navigator.clipboard` + fallback y flujo guiado en 4 pasos; Dark + `[data-theme="light"]`, SVG acotados, cero emojis crudos).
   - Actualización integral de `informe_proyecto/05_MANUAL_OPERATIVO_DEL_PROPIETARIO_Y_COMANDOS_RELEASE.md` (corrección de ancla del punto 3 del Índice, tabla y operación tri-protocolo en Guía 1.3/1.6 y documentación de `compilar_release_dual.bat` + errores frecuentes en Guía 2) en UTF-8 sin BOM.
   - Suite certificada en `mochilalista_admin/test/plan23_5_fase4_release_guide_ui_test.dart` (`3` pruebas).

### 5.2 Resultados Certificados de Validación

* **Suite Backend + UI Completa (`mochilalista_admin/`):** **`243 / 243` pruebas en verde** (`230` heredadas de Plan 23 + `4` Fase 1 + `2` Fase 2 + `4` Fase 3 + `3` Fase 4), **`No issues found!`** en `dart analyze` y código `0` en `node --check` sobre `web/js/admin_app.js` y `web/js/qrcode.min.js`.
* **Certificación en Vivo del Compilador Dual sobre Binarios Oficiales `v9.41.0+85`:**
  * `compilar_release_dual.bat --help --no-pause`: código `0` (guía completa en UTF-8).
  * `compilar_release_dual.bat --dry-run --no-pause`: código `0` (Pre-chequeo SemVer `v9.41.0+85`, keystore `.jks` verificado sin imprimir secretos, SDK `build-tools 37.0.0`).
  * `compilar_release_dual.bat --verify-only --no-pause`: código `0` sobre `C:\Users\vjuli\Documents\v-app-offline apks\`:
    * **Universal (`mochilalista_v9.41_atp.apk`):** `107.73 MB` (`112960854` bytes) | `versionCode=85` | `ABIs='arm64-v8a' 'armeabi-v7a' 'x86_64'` | `debuggable: AUSENTE` | `SHA-256: d8597dd7c2d7e5a17f1ffd41a9f3e518ff62ab87a3905fc715f09db82e7d4514`
    * **ARM64 Ligero (`mochilalista_v9.41_arm64_atp.apk`):** `38.66 MB` (`40542457` bytes, ahorro del `64.11 %`) | `versionCode=2085` | `ABIs='arm64-v8a'` | `debuggable: AUSENTE` | `SHA-256: fdb64551a2ab2d85395a984aed13aad91136f349647aebb4a439940560e10b9e`
    * **Firma RSA-4096 oficial (`V2 Signer:`):** huella verificada `7c43addc34776f3974eac23fdacc47599efd5393a4dbb28672d06899833ffd20`.
* **Inmutabilidad de `app_movil/`:** `git diff --stat -- app_movil/` vacío (**`0` cambios**; app móvil intacta en `v9.41.0+85` con `1,435/1,435` pruebas certificadas en `e84583a`).
* **Auditoría `git check-ignore --no-index -v`:** las 8 rutas críticas (`prod_clients_db.json`, `prod_releases_db.json`, `owner_config.json`, `vault_keyring.json`, `.apk_inspection_cache.json`, `private_keys/ed25519_master.key`, `releases_apks/prod/app.apk` y `app_movil/android/key.properties`) quedaron verificadas bajo reglas `.gitignore` con cero exposición al historial Git.
