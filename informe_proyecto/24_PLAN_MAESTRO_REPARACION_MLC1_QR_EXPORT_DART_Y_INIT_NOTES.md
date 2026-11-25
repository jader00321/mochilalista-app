# PLAN MAESTRO 24: REPARACIÓN INTEGRAL DE SINCRONIZACIÓN `MLC1` (QR FUNCIONAL, VÍA 1/VÍA 2 COMPLETA, VERIFICACIÓN CRUZADA) Y `--init-notes` EN COMPILADOR DUAL

> **Documento Técnico y Plan de Ejecución Oficial — Versión 1.6 (`100 % COMPLETADO Y CERTIFICADO — Fases 1 a 6 Cerradas`)**  
> **Proyecto:** MochilaLista POS Comercial & MochilaLista Admin Platform  
> **Punto de Partida Certificado:** Cierre de Planes Maestros 23 (`e84583a`) y 23.5 (`09a84df`) en rama `dev/mejoras-v9.0-comercializacion-seguridad` (`243/243` pruebas en verde en `mochilalista_admin/` y `1,435/1,435` pruebas en verde en `app_movil/`)  
> **Objetivo Estratégico:** Dejar al **100 %** la experiencia y confiabilidad técnica de la **Sincronización Comercial Segura (`MLC1`)** y cerrar **2 mejoras productivas puntuales** (exportación Dart completa lista para `Ctrl+A` → `Ctrl+V` / descarga `.dart`, y flag `--init-notes` no destructivo en `compilar_release_dual.bat`) antes de iniciar la gran modularización arquitectónica del Plan Maestro 25.

> [!IMPORTANT]
> **Salvaguardas Técnicas Preventivas Integradas (Paso 0 — Versión 1.1):**
> 1. **Fase 1 (Verificación round-trip inmediata ISO/IEC 18004 V1–V40):** Validar en Node.js con `jsqr.min.js` durante la propia Fase 1 que el nuevo `qrcode.min.js` implementa correctamente la información de versión BCH (18 bits para V7–V40), encabezados de longitud de 16 bits en modo Byte (V10–V40) y las 40 entradas completas de `RS_BLOCK_TABLE` (`L/M/Q/H`) y `PATTERN_POSITION_TABLE`, decodificando round-trip 5 tamaños reales (`~200 B`, `~450 B`, `~1,990 B`, `~2,350 B` y `~2,900 B`).
> 2. **Fase 1 (Compatibilidad total de `renderSafeQrCode`):** Confirmar `node --check` en `qrcode.min.js` y `admin_app.js`, y cero regresiones en los consumidores actuales (`ML9`, Ficha 360°, Credenciales PNG, Kit de Rescate y `downloadQrWithQuietZone`).
> 3. **Fase 5 (Ejecución móvil determinista):** Ejecutar la suite móvil con `flutter test --no-pub -j 1` para evitar contención paralela SQLite en Windows.

---

## 0. BLINDAJE ESTRICTO DE ALCANCE, SEGURIDAD Y COMPATIBILIDAD

Antes de ejecutar cualquier fase del Plan Maestro 24, rigen de forma obligatoria las siguientes reglas de protección:

1. **Intocabilidad absoluta de datos reales, secretos y archivos sensibles:**
   * **PROHIBIDO modificar, exponer o commitear:**
     * `mochilalista_admin/data/prod_clients_db.json` y `prod_releases_db.json`
     * `mochilalista_admin/data/owner_config.json`
     * `mochilalista_admin/data/vault_keyring.json` y `vault_settings.json`
     * `mochilalista_admin/data/.apk_inspection_cache.json`
     * `mochilalista_admin/private_keys/`
     * `mochilalista_admin/releases_apks/`
     * `app_movil/android/key.properties`
   * **Prohibición de exposición de secretos:** Jamás imprimir en consola, logs, tests ni documentos claves privadas, semillas Ed25519 ni contraseñas. La verificación criptográfica Admin ↔ App Móvil compara exclusivamente el hash SHA-256 de la **clave pública** de 32 bytes.
2. **Intocabilidad de módulos críticos móviles:**
   * **PROHIBIDO tocar** `app_movil/lib/features/auth/screens/onboarding/lock_screen.dart`.
   * **PROHIBIDO alterar** el esquema de base de datos **SQLite `v36`** en `app_movil/lib/core/database/local_db.dart`.
   * Todos los cambios en `app_movil/` se limitan estrictamente a la refactorización limpia de constantes comerciales en `lib/core/config/` (`owner_commercial_defaults.dart` + `owner_legal_identity.dart` + `commercial_catalog_provider.dart`) y pruebas unitarias de verificación cruzada `MLC1` y defaults Dart.
3. **Compatibilidad total 100 % retroactiva con `v9.41.0+85` ya instalada en celulares:**
   * Mantener inalterado el contrato del protocolo `MLC1`:
     * Prefijo exacto `MLC1-` (`MLC1-<payload_b64url>.<sig_b64url>` sin padding `=`).
     * Firma Ed25519 con separación de dominio sobre `utf8.encode('MLC1-$payloadB64')`.
     * Esquema tipado `v == 1`, claves permitidas `{'v', 'ver', 'iat', 'sup', 'yh', 'yp', 'bcp', 'bbva', 'p'}` y los 8 IDs de producto (`mensual`, `trimestral`, `semestral`, `anual`, `perpetua`, `bolsa_extra_ia`, `pase_anual_updates`, `migracion`) con campos `{'pr', 'd', 'ai', 'um', 'lb', 'ds'}` y cota `<= 8192` bytes.
   * Mantener la resolución del PNG exportado por `downloadQrWithQuietZone` por debajo de `1024 px` (p. ej. `512 px` base + `32 px` quiet zone = `576×576 px`) para evitar que `QrGalleryDecoderService` (`app_movil/lib/core/services/scanner/qr_gallery_decoder_service.dart:50`, `maxDim = 1024` con `Interpolation.linear`) reescale y suavice la imagen en `v9.41.0+85`.
4. **Estándares de UI, contratos de prueba y ejecución:**
   * **Cero emojis crudos** en controles UI de `mochilalista_admin/web/` (`index.html`, `styles.css`, bloques UI en `admin_app.js`); usar exclusivamente `<svg>` acotados (`width`/`height` o clase `.btn-icon`/`.icon-svg`).
   * **Soporte dual de temas:** Modo oscuro (**Deep Obsidian**) y modo claro (**`[data-theme="light"]` Executive Slate**).
   * **Bloques contractuales intactos en `admin_app.js`:**
     * Bloque de funciones puras `formatApkSizeMb` .. `renderSignatureStatusBadge`.
     * Marcadores de Sección 5 (`// =================== 5. INSPECTOR FORENSE DUAL` .. `// =================== 6. FINANZAS`).
     * Bloque `isVerifyAllCatalogRunning` .. `/**\n * Carga notas compañeras`.
     * Marcadores de Sección 8 (`// =================== 8. CENTRO DE PERSONALIZACIÓN TOTAL` .. `// =================== 9. EXPORTACIÓN A MICROSOFT EXCEL`).
     * Uso defensivo de `?.` en cualquier nuevo ID DOM dentro de `admin_app.js` para preservar compatibilidad con harnesses Node.js de planes previos.
   * **Pruebas aisladas y git seguro:** Todas las pruebas deben operar en `Directory.systemTemp` con limpieza garantizada en `tearDown()`, todos los comandos deben ejecutarse de forma síncrona sin colgarse, y el cierre final se realizará en la rama `dev/mejoras-v9.0-comercializacion-seguridad` (**sin** `git tag` ni merge a `main`).

---

## 1. AUDITORÍA FORENSE EN MODO SOLO LECTURA (CAUSAS RAÍZ VERIFICADAS)

La inspección directa del código fuente, scripts, pruebas existentes y artefactos reales (con verificación viva read-only en Dart y Node.js) confirmó las **causas raíz exactas** de todos los síntomas observados en las capturas `165136.png`, `165145.png`, `165202.png` y `165214.png`:

### 1.1 Diagnóstico Exacto del QR Vacío (`165136.png`, `165202.png`)

1. **Motor QR truncado en `mochilalista_admin/web/js/qrcode.min.js` (524 líneas):**
   * Aunque la cabecera indica *EasyQRCodeJS / QRCode.js*, el archivo es una implementación mínima truncada (`Minimal standalone QR Engine (Version 1-10 Byte Mode)`).
   * `_generateQRMatrix(data)` (`qrcode.min.js:65-77`) solo asigna `typeNumber` hasta **`14`** (`if (data.length > 200) typeNumber = 14;`) y fija `var errorCorrectionLevel = 1;` ignorando `options.correctLevel`.
   * `QRUtil.PATTERN_POSITION_TABLE` (`qrcode.min.js:357-360`) y `QRRSBlock.RS_BLOCK_TABLE` (`qrcode.min.js:480-484`) solo contienen **14 versiones** (`1..14`, únicamente Nivel L), y `QRRSBlock.getRSBlocks(typeNumber, errorCorrectLevel)` (`qrcode.min.js:485-497`) **ignora completamente `errorCorrectLevel`** indexando `(typeNumber - 1) % 14`.
   * La capacidad máxima absoluta del motor actual (Versión 14-L) es de `461` *codewords* (`3×115 + 1×116 = 461 B` = **`3,688 bits`**).
2. **Desbordamiento real con el token `MLC1-...` (`1,990 B`):**
   * Auditado en vivo sobre el catálogo actual: el JSON canónico mide **`1,423 B`** (de los cuales **`583 B` = `40.97 %`** corresponden a las 8 descripciones `ds` de `~73 B` promedio c/u) y el token firmado `MLC1-<b64>.<sig>` alcanza **`1,990 B`** (`1,898` B payload Base64Url + `5` B prefijo + `1` B punto + `86` B firma Ed25519).
   * En modo 8-bit Byte (obligatorio porque Base64Url contiene minúsculas, incompatibles con modo Alfanumérico), `1,990 B` requieren `15,920 + 20 =` **`15,940 bits`**.
   * Al ejecutar `QRCodeModel.createData()` (`qrcode.min.js:269-271`), la condición `15940 > 3688` lanza la excepción reproducida en Node.js:
     ```text
     Error: code length overflow. (15940>3688)
     ```
   * Esta excepción ocurre **antes** de `this._el.appendChild(canvas)` (`qrcode.min.js:56`), mientras `this._el.innerHTML = ''` ya se ejecutó en `:31`.
3. **Captura silenciosa en `renderSafeQrCode()` (`admin_app.js:65-99`) y falla en cascada de botones:**
   * `renderSafeQrCode()` intenta crear `new QRCode(..., { correctLevel: M })`, falla, reintenta en el `catch` sin `correctLevel`, vuelve a lanzar `code length overflow. (15940>3688)`, imprime `console.error` y retorna `null`, dejando `#mlc1QrContainer` completamente vacío dentro de `.mlc1-qr-white-box` (recuadro blanco en blanco visible en `165136.png`).
   * Al pulsar **`Descargar QR PNG`**, `downloadQrWithQuietZone('#mlc1QrContainer', ...)` (`admin_app.js:2493-2500`) no encuentra `<canvas>` ni `<img>` y dispara el toast `"No hay código QR disponible para descargar."` (`165202.png`).
   * Al pulsar **`Copiar QR`**, `copyMlc1QrToClipboard()` (`admin_app.js:14423-14426`) falla con `"Genera primero la ficha MLC1 para copiar el QR."`.

### 1.2 Análisis de Capacidad QR Estándar (ISO/IEC 18004) y Estrategia Óptima Compatible con `v9.41.0+85`

| Configuración QR (Modo 8-bit Byte) | Capacidad Máxima | Versión para `1,990 B` | Módulos | Margen libre con BCP+BBVA (`~2,250 B`) | Tamaño módulo en canvas `512 px` |
|---|---|---|---|---|---|
| Motor actual (`qrcode.min.js`) | `458 B` (V14) | **Falla (`overflow`)** | N/A | N/A | N/A |
| **Nivel `M` (15 % ECC)** | `2,331 B` (V40-M) | Versión **38-M** | `169 × 169` | Ajustado (`81 B` sobre `2,250 B`) | `3 px` (`507 px`, margen `2 px`) |
| **Nivel `L` (7 % ECC) — Recomendado para `MLC1`** | **`2,953 B`** (V40-L) | Versión **34-L** | **`153 × 153`** | **Amplio (`+703 B` sobre `2,250 B`; `+963 B` sobre `1,990 B`)** | **`3 px` enteros (`459×459 px` centrados en `512×512 px`, +`26 px` borde extra)** |

* **Por qué elegir ISO/IEC 18004 completo + `CorrectLevel.L` automático para payloads densos (`> 900 B`) y conservar `ds` intacto:**
  1. Preserva **100 % intacto** el payload `v == 1` incluyendo las descripciones comerciales editables `ds` (que `license_status_and_activation_screen.dart:121` en `v9.41.0+85` ya lee y muestra cuando vienen en el token).
  2. Versión 34-L (`153×153`) tiene **~18 % menos densidad de módulos** que Versión 38-M (`169×169`), ofreciendo cuadros significativamente más anchos y fáciles de enfocar para cámaras móviles y decodificadores `jsQR` / `mobile_scanner`.
  3. Manteniendo `renderSafeQrCode(qrContainer, data.token, 512, '#0f172a', '#ffffff')` (contrato verificado por `plan23_5_fase2_mlc1_inspector_ui_test.dart:113, 499`), el renderizado con **tamaño de módulo entero exacto** (`tileSize = Math.floor(512 / 153) = 3 px`) produce una matriz nítida de `459×459 px` centrada en `512×512 px` (`0` aliasing subpíxel), y `downloadQrWithQuietZone(..., 32)` exporta un PNG de **`576×576 px`** (con *quiet zone* blanca combinada de `~58 px`), estrictamente `< 1024 px` para que `QrGalleryDecoderService` en `v9.41.0+85` no lo reescale con interpolación lineal.
  4. Adicionalmente, el motor QR V1–V40 realizará fallback automático `H -> Q -> M -> L` ante cualquier texto largo que supere la capacidad del nivel pedido, erradicando para siempre los overflows silenciosos tanto en `MLC1` como en `ML9` largos.

### 1.3 Diagnóstico de Paridad Criptográfica Admin ↔ App Móvil (Comprobado en Vivo)

Verificado mediante script de solo lectura sin exponer semillas ni claves privadas:
* **Clave pública derivada de `mochilalista_admin/private_keys/ed25519_master.key`:** `32` bytes, SHA-256 = `1c3ec0b9d87ff8acb49b1df871b65c0b40e47d1f11c65b348b5407b80a65e106`.
* **Clave pública embebida en `app_movil/lib/core/services/license/ed25519_license_validator.dart:46-51` (`_defaultOfficialPublicKeyBytes`):** `32` bytes, SHA-256 = `1c3ec0b9d87ff8acb49b1df871b65c0b40e47d1f11c65b348b5407b80a65e106`.
* *(Nota de auditoría de rutas: el validador Ed25519 reside en `app_movil/lib/core/services/license/ed25519_license_validator.dart`, no bajo `features/auth/services/`.)*
* **Resultado:** Coincidencia matemática exacta **1:1** (`PUB_EXACT_MATCH = true`). No requiere rotación ni modificación de claves; sí requiere una prueba automatizada cruzada real que valide el flujo completo emisor Admin → receptor Móvil (`CommercialConfigSyncService` + `CommercialCatalogProvider`).

### 1.4 Diagnóstico Exacto de `-` en `Updates` y Fallos UX de Vía 1 (`165136.png`, `165145.png`)

1. **Por qué `Perpetuo Liberado` y `Pase Anual de Updates` muestran `-` en `Updates`:**
   * Verificado directamente sobre `owner_config.json` legado: ambos slugs tienen `"updates_window_months": 0` y `"updates_months": 0` guardados en disco antes del Plan 23.
   * En `ConfigService._normalizeCatalogEntries()` (`mochilalista_admin/lib/config_service.dart:1116-1135`), la rama `if (rawEntry != null && rawEntry.containsKey('updates_window_months'))` lee el `0` existente como válido y **nunca** aplica `12` desde `defaultsCatalog`.
   * En `CommercialConfigSyncService.buildCanonicalPayload()` (`mochilalista_admin/lib/commercial_config_sync_service.dart:257-262`), `rawEntry['updates_window_months'] ?? rawEntry['updates_months']` evalúa `0` (no `null`), por lo que el parámetro `fallback: 12` **nunca se dispara**.
   * En consecuencia, `CANON_PROD perpetua | um=0` y `CANON_PROD pase_anual_updates | um=0` viajan con `um = 0` tanto en el resumen como en el token firmado `MLC1-...`, y `renderMlc1CommercialSummary()` (`admin_app.js:14266`) imprime **`-`**.
2. **Por qué las pestañas Vía 1 y Vía 2 salen apiladas verticalmente:**
   * En `styles.css:4612-4618`, `.mlc1-tabs-bar` tiene `display: flex; flex-wrap: wrap;` y los dos botones (`.mlc1-tab-btn`) poseen etiquetas muy largas (`Vía 1: Ficha Firmada MLC1 (Actualización Offline Instantánea)` y `Vía 2: Constantes Dart (Futuras Compilaciones APK)`), cuya suma supera el ancho útil del modal y fuerza el salto de línea de Vía 2 debajo de Vía 1.
3. **Por qué la tabla resumen es incómoda y confusa:**
   * En `index.html:4705`, `<div class="table-responsive" style="max-height: 185px; overflow-y:auto;">` oculta la mitad de los 8 productos detrás de un scroll estrecho.
   * En `admin_app.js:14265`, `p.days >= 99999 ? 'Vitalicia' : `${p.days || 0} d`` muestra `0 d` confuso para `bolsa_extra_ia`, `pase_anual_updates` y `migracion`.
   * Faltan instrucciones paso a paso para el cliente junto a la zona del código/QR y falta el botón **`Auditar esta ficha en Inspector`** paritario con `ML9` (`#btnAuditInInspector` y `#btnDrawerAuditInspector`).

### 1.5 Diagnóstico de Vía 2 (`165214.png`): Fragmento Incompleto vs Archivo Completo

* `CommercialConfigSyncService.generateOwnerLegalIdentityDartSnippet()` (`mochilalista_admin/lib/commercial_config_sync_service.dart:909-1021`) emite únicamente 17 líneas `static const` sueltas más `defaultCommercialPlans`, **sin** encabezado `class ...`, **sin** llaves de cierre y **omitiendo** los métodos y constantes de versión (`currentAppVersion`, `currentAppVersionWithBuild`, `formatPlanArticleName`, `buildPlanOrderMessage`, etc.) de `app_movil/lib/core/config/owner_legal_identity.dart`.
* Adicionalmente, en `app_movil/lib/core/providers/commercial_catalog_provider.dart:68-171`, los 8 planes por defecto (`defaultPlansMap`), `yapePlinPhone` y titulares `bcpHolder` / `bbvaHolder` estaban desconectados de `OwnerLegalIdentity`.
* **Evaluación comparativa `Opción A` vs `Opción B`:**

| Criterio | **Opción A (RECOMENDADA): Archivo dedicado `owner_commercial_defaults.dart`** | Opción B: Generar completo `owner_legal_identity.dart` |
|---|---|---|
| Flujo del propietario (`Ctrl+A` → `Ctrl+V` o Descargar `.dart`) | **100 % íntegro y seguro** (`owner_commercial_defaults.dart` es 100 % declarativo). | Riesgo alto al mezclar datos con lógica y versiones. |
| Riesgo de pisar `currentAppVersionWithBuild` (`9.41.0+85`) en futuros releases | **Cero riesgo:** `owner_legal_identity.dart` conserva versión y métodos de negocio intactos. | Alto: Admin tendría que saber la versión exacta de `pubspec.yaml` móvil o la sobrescribiría al pegar. |
| Fuente única de verdad para tarifas compiladas en `app_movil` | **`OwnerCommercialDefaults`** nutre tanto a `OwnerLegalIdentity` (reexportación `const`) como a `EffectiveCommercialConfig.defaults()`. | Seguiría requiriendo duplicar lógica en strings dentro de `mochilalista_admin`. |
| Compatibilidad con los 12 archivos de test en `app_movil/test/` | **100 % compatible** sin cambiar una sola firma pública de `OwnerLegalIdentity`. | Exigiría sincronizar toda la clase en un string template del backend Admin. |

**Decisión Arquitectónica (Opción A):** Extraer las constantes comerciales puras a **`app_movil/lib/core/config/owner_commercial_defaults.dart`** (`class OwnerCommercialDefaults`), importado por `owner_legal_identity.dart` (conservando todas sus constantes y firmas públicas `const` sin cambios) y consumido por `EffectiveCommercialConfig.defaults()` en `commercial_catalog_provider.dart` (preservando la compatibilidad estricta de `license_screen_catalog_and_clipboard_test.dart:295` cuando no hay override). Vía 2 en Admin generará `owner_commercial_defaults.dart` completo de principio a fin, con ruta exacta, instrucciones en 2 pasos, **`Copiar Archivo Completo (.dart)`** y **`Descargar archivo .dart`**.

### 1.6 Diagnóstico de `compilar_release_dual.bat` / `scripts/compilar_release_dual.ps1` (`--init-notes`)

* `scripts/compilar_release_dual.ps1` (`:36-41, 74-116, 121-176, 579-592, 705-735`) ya gestiona `DryRun`, `VerifyOnly`, `SkipAnalyze`, `NoPause`, `OutDir` y reporta en `[Paso 6/6]` el estado de `mochilalista_v<tag>_atp.txt` y `mochilalista_v<tag>_atp_cambios.txt`, pero aún no ofrece `--init-notes` para inicializar ambas plantillas en UTF-8 sin BOM con los hashes, tamaños, `%` de ahorro y huella RSA-4096 reales del build, respetando sin sobrescribir cualquier archivo ya existente (como `v9.41`).
* Nota de auditoría detectada en `#dualBuildGuidePanel` (`plan23_5_fase4_release_guide_ui_test.dart:76-81`): existe una aserción exacta de `3` botones `.btn-copy-dual-cmd`; al agregar el 4.º comando copiable con `--init-notes`, se actualizará limpiamente esa expectativa junto con la suite Plan 24.

---

## 2. PLAN DE EJECUCIÓN EN 6 FASES SECUENCIALES MANEJABLES

---

### FASE 1: Motor QR ISO/IEC 18004 (V1–V40) Offline, Corrección de `Updates` (`12 meses`) y Paridad Criptográfica Admin ↔ Móvil

**Objetivo:** Garantizar que el QR de `MLC1` (y `ML9` densos) se renderice nítido sin overflows hasta `2,953 B`, que `Perpetuo Liberado` y `Pase Anual de Updates` reflejen `12 meses` de raíz, y que exista verificación criptográfica cruzada real entre Admin y App Móvil.

#### Archivos a modificar:
1. `mochilalista_admin/web/js/qrcode.min.js`
   * Reemplazar el motor truncado V14 por una implementación completa **ISO/IEC 18004 Versiones 1 a 40** 100 % offline y autocontenida:
     * Tablas oficiales completas `RS_BLOCK_TABLE` (40 versiones × 4 niveles `L/M/Q/H`) y `PATTERN_POSITION_TABLE` (Versiones 1–40).
     * Modo 8-bit Byte con longitud de 8 bits (V1–V9) y 16 bits (V10–V40), respetando `correctLevel` (`L=1`, `M=0`, `Q=3`, `H=2`).
     * Selección automática de la versión mínima válida `1..40` para los bytes UTF-8 de entrada, con fallback automático gradual de nivel (`H -> Q -> M -> L`) si la cadena excede el nivel solicitado (permitiendo hasta `2,953 B` en V40-L).
     * Dibujo `<canvas>` nítido con tamaño de módulo entero (`tileSize = Math.floor(size / count)` cuando `size >= count * 2`, centrado simétricamente sobre `colorLight` `#ffffff`) para evitar difuminado subpíxel; preservando la API `new QRCode(target, options)`, `makeCode(text)`, `toDataURL()` y `QRCode.CorrectLevel`.
2. `mochilalista_admin/web/js/admin_app.js` (`renderSafeQrCode`, `:65-99`)
   * Conservar la firma exacta `renderSafeQrCode(container, text, size = 196, colorDark = '#0f172a', colorLight = '#ffffff')`.
   * Cuando `utf8ByteLength(text) > 900` (como fichas `MLC1-...` de ~1,990 B), elegir `QRCode.CorrectLevel.L` automáticamente para generar Versión 34 (`153×153` módulos más grandes) en lugar de Versión 38 (`169×169`), con fallback inteligente si fallara el nivel pedido y mensaje visual explícito si excediera el límite físico absoluto de V40-L (`2,953 B`).
3. `mochilalista_admin/lib/config_service.dart` (`_normalizeCatalogEntries`, `:1080-1150`)
   * En `_normalizeCatalogEntries()`: para slugs cuya definición oficial en `getDefaultConfig()['catalog']` posee `updates_window_months > 0` (`PERPETUO_LIBERADO` y `PASE_ACTUALIZACION_ANUAL`), si el valor cargado/entrante es `<= 0`, sanear automáticamente a `12` (`defEntry['updates_window_months']`), manteniendo íntegro cualquier valor explícito `> 0` (p. ej. `24`).
4. `mochilalista_admin/lib/commercial_config_sync_service.dart` (`buildCanonicalPayload`, `:253-262`)
   * Garantizar que para `PERPETUO_LIBERADO` y `PASE_ACTUALIZACION_ANUAL`, si `updates_window_months` y `updates_months` son `null` o `<= 0` (p. ej. config legado sin normalizar), se resuelva a `defaultUm = 12`, asegurando que la columna `Updates` en el resumen y en el payload firmado `p['perpetua']['um']` / `p['pase_anual_updates']['um']` sea **`12`**.

#### Entregables y criterios de verificación de Fase 1 (`CERTIFICADA`):
* **Round-trip Node.js con `jsqr.min.js` verificado:** 5 tamaños reales (`220 B` V11-M, `460 B` V17-M, `1,990 B` V33-L con quiet zone `32 px` = `576×576 px`, `2,350 B` extendido V36-L = `576×576 px` y `2,900 B` estrés V40-L = `704×704 px`) decodificados al 100 % byte a byte al payload original, más guardia controlada de overflow (`> 2,953 B`) sin excepciones ni emojis crudos.
* **Paridad de API QR:** `node --check` en `qrcode.min.js` y `admin_app.js` limpio (`exit 0`), preservando firma de `renderSafeQrCode()` y compatibilidad de `ML9`, Ficha 360°, Credenciales PNG, Kit de Rescate y `downloadQrWithQuietZone`.
* **Saneamiento raíz `Updates = 12 meses`:** `plan24_fase1_qr_and_updates_test.dart` en `Directory.systemTemp` certifica la autocorrección `<= 0 -> 12` en `PERPETUO_LIBERADO` y `PASE_ACTUALIZACION_ANUAL` (y la preservación de ediciones explícitas `24`) tanto en `ConfigService.init()` como en `CommercialConfigSyncService.buildCanonicalPayload()`, además de re-validar firma Ed25519 sobre tokens `MLC1-...` decodificados desde QR RGBA con `jsQR`.
* **Comparación SHA-256 pública Admin ↔ Móvil certificada** sin exponer claves privadas (`1c3ec0b9d87ff8acb49b1df871b65c0b40e47d1f11c65b348b5407b80a65e106`).

---

### FASE 2: Rediseño UX de Vía 1 en `#modalCommercialConfigSync` y Botón 1-Clic `Auditar esta ficha en Inspector`

**Objetivo:** Corregir todos los defectos visuales y de usabilidad de Vía 1 mostrados en `165136.png` y `165145.png`, añadiendo inspección directa en 1 clic paritaria con `ML9`.

#### Archivos a modificar:
1. `mochilalista_admin/web/index.html` (`#modalCommercialConfigSync`, `:4657-4782`)
   * **Pestañas horizontales lado a lado:** Mantener `.mlc1-tabs-bar` con los dos botones `.mlc1-tab-btn` (`data-mlc1-tab="mlc1PaneToken"` y `data-mlc1-tab="mlc1PaneDart"`) usando etiquetas claras y concisas para barra horizontal equilibrada:
     * `Vía 1: Ficha Firmada MLC1 (Offline)`
     * `Vía 2: Archivo Dart Completo (Futuros APKs)`
   * **Tabla resumen de 8 productos (`#mlc1SummaryBox`):**
     * Encabezados claros: `Producto` | `Precio` | `Vigencia` | `Bolsa IA` | `Updates`.
     * Eliminar el límite apretado `max-height: 185px; overflow-y:auto;` para visualizar cómodamente los **8 productos completos** sin scroll interno incómodo.
   * **Zona de resultado (`#mlc1TokenResultContainer`) e instrucciones para cliente:**
     * Añadir caja estructurada de instrucciones en 3 pasos claros (*Cómo aplica esta ficha el cliente en su celular*) con `<svg>` acotados y cero emojis crudos.
     * Añadir badge discreto de capacidad/densidad QR (ej. `#mlc1QrMetaBadge`) en la tarjeta QR junto a `#btnDownloadMlc1Qr` y `#btnCopyMlc1Qr`.
     * Añadir botón en 1 clic **`Auditar esta ficha en Inspector`** (`id="btnAuditMlc1InInspector"`, inicialmente `disabled` hasta que exista token generado, con ícono lupa `<svg>` acotado).
2. `mochilalista_admin/web/css/styles.css` (`:4612-4770`)
   * `.mlc1-tabs-bar`: `display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0.55rem;` en desktop (apilando a `1fr` únicamente bajo `@media (max-width: 640px)`), garantizando pestañas **lado a lado** con altura uniforme y soporte Dark + `[data-theme="light"]`.
   * Estilos limpios para `.mlc1-summary-card`, `.mlc1-plans-mini-table`, `.mlc1-client-steps-box`, `.mlc1-qr-card` y `.mlc1-qr-white-box` (preview visual nítido a `220×220 px` con `image-rendering: pixelated` mientras el canvas interno permanece a `512×512 px`), verificando contraste y bordes tanto en modo oscuro como en `[data-theme="light"]`.
3. `mochilalista_admin/web/js/admin_app.js`
   * **`renderMlc1CommercialSummary(summary)` (`:14243-14278`):**
     * Formatear `Vigencia` de forma inequívoca (cero `0 d` confuso):
       * `p.days >= 99999` → `'Vitalicia'`
       * `p.id === 'bolsa_extra_ia'` → `'Recarga'`
       * `p.id === 'pase_anual_updates'` → `'Pase anual'` (o `'Único / Pase'`)
       * `p.id === 'migracion'` → `'Único'`
       * Otros `days > 0` → `` `${p.days} días` ``
     * Formatear `Updates`: `(p.updates_months || 0) > 0 ? `${p.updates_months} meses` : '-'`.
   * **`populateSettingsForm()` (`:13746`):**
     * Fallback preventivo `12` si `PERPETUO_LIBERADO` o `PASE_ACTUALIZACION_ANUAL` trajeran `0` desde memoria.
   * **Sincronización del botón `#btnAuditMlc1InInspector` y función `auditMlc1TokenInInspector()`:**
     * Habilitar `#btnAuditMlc1InInspector` en `generateMlc1SyncToken()` y `loadAndOpenCommercialSyncModal()` cuando exista token vigente; deshabilitarlo cuando no exista token.
     * Al hacer clic: validar token en `#mlc1TokenOutput`, cerrar `#modalCommercialConfigSync`, activar la pestaña `#tabInspector` (actualizando `.nav-tab.active`, `.tab-pane.active` y `#currentViewName`), pegar el token en `#inspectTokenInput`, invocar `inspectToken()` (desplegando `#inspectMlc1AuditCard`) y mostrar toast informativo.
   * **`renderSafeQrCode` + error guard en `btnDownloadMlc1Qr` / `copyMlc1QrToClipboard()`:** Mantener compatibilidad total con `downloadQrWithQuietZone('#mlc1QrContainer', ..., 32)` y verificar que tras emitir `MLC1` el canvas QR exista siempre.

#### Entregables y criterios de verificación de Fase 2 (`CERTIFICADA`):
* Auditoría HTML/CSS/JS en Node.js ([plan24_fase2_mlc1_modal_ui_and_inspector_test.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/mochilalista_admin/test/plan24_fase2_mlc1_modal_ui_and_inspector_test.dart)): pestañas `.mlc1-tabs-bar` en grid 2 columnas lado a lado (`repeat(2, minmax(0, 1fr))`), encabezados `Producto / Precio / Vigencia / Bolsa IA / Updates` sin `max-height: 185px`, 0 `0 d` en `renderMlc1CommercialSummary`, `12 meses` en `perpetua` y `pase_anual_updates`, instrucciones 3 pasos `.mlc1-client-steps-box`, badge `#mlc1QrMetaBadge`, QR `512×512 px` decodificable con `jsqr.min.js`, botón `#btnAuditMlc1InInspector` que cierra el modal, abre `#tabInspector`, pega el token y ejecuta `inspectToken()`, 0 emojis crudos, `<svg>` acotados, Dark + Light y harnesses previos 100 % en verde.

---

### FASE 3: Vía 2 — Refactorización `owner_commercial_defaults.dart` (`Opción A`), Archivo Dart 100 % Completo y Descarga `.dart` (`165214.png`)

**Objetivo:** Que el propietario copie (`Ctrl+A` → `Ctrl+V`) o descargue un archivo `.dart` **100 % completo, compilable y autosuficiente** sin riesgo de borrar métodos ni versiones de `OwnerLegalIdentity`.

#### Archivos a crear/modificar:
1. **NUEVO `app_movil/lib/core/config/owner_commercial_defaults.dart`:**
   * Archivo 100 % declarativo y puro (sin dependencias de Flutter UI ni SQLite) que define `class OwnerCommercialDefaults` con:
     * `static const int commercialSyncDefaultRevision = 0;` *(o el entero exportado desde Admin)*
     * `authorFullName`, `appCommercialName`, `legalFrameworkNotice`, `personalDataLawNotice`
     * `supportPhone`, `supportWhatsAppUrl`, `officialWebsite`
     * `yapePlinHolder`, `yapePlinPhone`
     * `bcpAccountHolder`, `bcpAccountNumber`, `bcpCciNumber`
     * `bbvaAccountHolder`, `bbvaAccountNumber`, `bbvaCciNumber`
     * `static const Map<String, Map<String, Object>> defaultCommercialPlans = { ... };` (los 8 IDs canónicos: `mensual`, `trimestral`, `semestral`, `anual`, `perpetua`, `bolsa_extra_ia`, `pase_anual_updates`, `migracion` con `pr`, `d`, `ai`, `um`, `lb`, `ds`).
2. `app_movil/lib/core/config/owner_legal_identity.dart`
   * Importar `package:app_movil/core/config/owner_commercial_defaults.dart`.
   * Delegar las constantes comerciales homónimas a `OwnerCommercialDefaults.*` (`static const String authorFullName = OwnerCommercialDefaults.authorFullName;`, `supportPhone`, `supportWhatsAppUrl`, `officialWebsite`, `yapePlinHolder`, `bcpAccountNumber`, `bcpCciNumber`, `bbvaAccountNumber`, `bbvaCciNumber`, `legalFrameworkNotice`, `personalDataLawNotice`) y exponer también `yapePlinPhone`, `bcpAccountHolder`, `bbvaAccountHolder`, `commercialSyncDefaultRevision` y `defaultCommercialPlans`.
   * Mantener **100 % intactos** `currentAppVersion` (`"9.41.0"`), `currentAppVersionWithBuild` (`"9.41.0+85"`), `legalJurisdiction`, títulos EULA y todos los métodos (`formatPlanArticleName`, `buildPlanOrderMessage`, `buildCustomWhatsAppOrderUri`, `buildPlanWhatsAppUri`, `watermarkNotice`, `ticketFooterLegal`, `getLicenseAttribution`).
3. `app_movil/lib/core/providers/commercial_catalog_provider.dart`
   * Construir `EffectiveCommercialConfig.defaults()` leyendo desde `OwnerCommercialDefaults` (precios, días, créditos IA, meses de updates, etiquetas y descripciones de `OwnerCommercialDefaults.defaultCommercialPlans`, `supportPhone`, `supportWhatsAppUrl`, `yapePlinHolder`, `bcpAccountHolder`/`Number`/`Cci`, `bbvaAccountHolder`/`Number`/`Cci`), manteniendo compatibilidad regresiva con `license_screen_catalog_and_clipboard_test.dart:295` cuando `yapePlinPhone == '922836879'` y sin alterar el comportamiento cuando `SharedPreferences` tiene override `MLC1`.
4. `mochilalista_admin/lib/commercial_config_sync_service.dart` (`generateOwnerCommercialDefaultsDartFile` / `generateOwnerLegalIdentityDartSnippet`)
   * Actualizar el generador Dart para producir **el archivo `owner_commercial_defaults.dart` 100 % completo de principio a fin** (docstrings, `class OwnerCommercialDefaults {`, todas las constantes escapadas con `_escapeDartSingleQuoted`, el mapa `defaultCommercialPlans` completo con los 8 productos y el cierre `}`), manteniendo un alias o actualización limpia en `generateOwnerLegalIdentityDartSnippet()` si algún test existente lo invoca.
   * Revisar y actualizar la aserción de ruta en `GET /api/config/dart-defaults-snippet` (`server.dart:3123`) incluyendo también metadata opcional `target_file_path: 'app_movil/lib/core/config/owner_commercial_defaults.dart'` y `download_filename: 'owner_commercial_defaults.dart'`.
5. `mochilalista_admin/web/index.html` y `mochilalista_admin/web/js/admin_app.js` (Vía 2 `#mlc1PaneDart`)
   * Mostrar claramente la ruta destino en código copiable/resaltado: `app_movil/lib/core/config/owner_commercial_defaults.dart`.
   * Incluir instrucciones claras en 2 pasos (*Paso 1: Abre el archivo `owner_commercial_defaults.dart` en VS Code/editor · Paso 2: Pulsa `Ctrl+A` y `Ctrl+V` o reemplaza el archivo descargándolo*).
   * Actualizar el botón existente `#btnCopyMlc1Dart` a **`Copiar Archivo Completo (.dart)`** y agregar **`Descargar archivo .dart`** (`id="btnDownloadMlc1Dart"`, generando Blob `text/plain;charset=utf-8` con nombre `owner_commercial_defaults.dart`).

#### Entregables y criterios de verificación de Fase 3 (`CERTIFICADA`):
* Creado [owner_commercial_defaults.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/config/owner_commercial_defaults.dart) (`class OwnerCommercialDefaults` puro y declarativo) con delegación en [owner_legal_identity.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/config/owner_legal_identity.dart) y [commercial_catalog_provider.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/providers/commercial_catalog_provider.dart) conservando intactas versiones compiladas (`9.41.0+85`), métodos públicos y compatibilidad regresiva de `EffectiveCommercialConfig.defaults()`.
* `GET /api/config/dart-defaults-snippet` y `POST /api/config/generate-sync-token` emiten `target_file_path`, `download_filename` y el archivo `owner_commercial_defaults.dart` completo de principio a fin certificado con `dart analyze` (`No issues found!`) en `Directory.systemTemp` ([plan24_fase3_dart_defaults_export_test.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/mochilalista_admin/test/plan24_fase3_dart_defaults_export_test.dart)), junto con `#mlc1PaneDart` (`Copiar Archivo Completo (.dart)` + `Descargar archivo .dart`), `flutter analyze --no-pub` limpio y pruebas móviles y desktop en verde.

---

### FASE 4: Flag `--init-notes` No Destructivo en `compilar_release_dual.bat` y Guía en `#tabReleaseManager`

**Objetivo:** Permitir generar automáticamente las plantillas compañeras `mochilalista_v<tag>_atp.txt` y `mochilalista_v<tag>_atp_cambios.txt` en UTF-8 sin BOM con métricas reales del build, **jamás sobrescribiendo** notas existentes.

#### Archivos a modificar:
1. `scripts/compilar_release_dual.ps1`
   * Agregar variable `$InitNotes = $false` y parseo CLI para `--init-notes` / `-InitNotes` (compatible con ejecución normal, `--verify-only`, `--dry-run`, `--skip-analyze`, `--no-pause` y `--out-dir`).
   * Actualizar `Show-UsageHelp` (`--help` / `-h` / `/?`) documentando `--init-notes` y agregando ejemplo `compilar_release_dual.bat --verify-only --init-notes --no-pause`.
   * En `[Paso 1/6]` (`$DryRun`), informar si creará o respetará las notas compañeras cuando `--init-notes` esté activo.
   * Extraer en `Certify-ApkForensic` también `MinSdk` / `TargetSdk` desde `aapt2 dump badging` (`sdkVersion:'24'`, `targetSdkVersion:'36'`) con fallback limpio `24` / `36`.
   * En `[Paso 6/6]`: si `$InitNotes`:
     * Obtener timestamp actual en `America/Lima (GMT-5)` (`[TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTimeOffset]::UtcNow, 'SA Pacific Standard Time')`).
     * Para **`mochilalista_v<tag>_atp.txt`**:
       * Si existe → NO modificar; reportar `Ya existe en disco — respetada sin sobrescribir`.
       * Si no existe → escribir en **UTF-8 sin BOM** (`New-Object System.Text.UTF8Encoding($false)`) con el formato oficial de `mochilalista_v9.41_atp.txt`: versión `vX.Y.Z+B`, fecha/hora `America/Lima (GMT-5)`, sección `[1] APK UNIVERSAL` (nombre, ruta, MB, bytes exactos, SHA-256 real, `versionCode`, ABIs, SDK, SQLite `v36`, `application-debuggable AUSENTE`), sección `[2] APK ARM64 LIGERO` (nombre, ruta, MB, bytes, `-$SavingsPct %` frente al Universal, SHA-256 real, `versionCode`, ABI `arm64-v8a`), sección `CERTIFICACIÓN CRIPTOGRÁFICA Y FIRMA DIGITAL` (titular, RSA 4096 bits, huella `7c43addc...3ffd20`) y sección editable `ALCANCE TÉCNICO DEL RELEASE`; reportar `Creada plantilla técnica en UTF-8 sin BOM`.
     * Para **`mochilalista_v<tag>_atp_cambios.txt`**:
       * Si existe → NO modificar; reportar `Ya existe en disco — respetada sin sobrescribir`.
       * Si no existe → escribir en **UTF-8 sin BOM** plantilla limpia de novedades comerciales para clientes (formato viñetas `• Título: Descripción`, **cero emojis crudos**); reportar `Creada plantilla de cambios en UTF-8 sin BOM`.
2. `mochilalista_admin/web/index.html` (`#dualBuildGuidePanel`, `:743-787`)
   * Documentar `--init-notes` agregando el 4.º comando copiable con `<svg>` acotado:
     `compilar_release_dual.bat --verify-only --init-notes --no-pause`
   * Actualizar el paso 1 de la guía de 4 pasos para mencionar la opción `--init-notes` en la creación de notas compañeras.
3. `mochilalista_admin/test/plan23_5_fase4_release_guide_ui_test.dart`
   * Actualizar la expectativa del número de botones `.btn-copy-dual-cmd` (`3` → `4`) y probar también la copia del 4.º comando `--init-notes`.

#### Entregables y criterios de verificación de Fase 4 (`CERTIFICADA`):
* Implementado `--init-notes` / `-InitNotes` en [compilar_release_dual.ps1](file:///C:/Users/vjuli/Documents/mochilalista-app/scripts/compilar_release_dual.ps1) (conservando BOM UTF-8 `EF BB BF`), `--help`, simulación `--dry-run --init-notes`, extracción `MinSdk`/`TargetSdk` y generación no destructiva en `[Paso 6/6]` en UTF-8 sin BOM con hora `America/Lima (GMT-5)` y métricas reales.
* Actualizado `#dualBuildGuidePanel` en [index.html](file:///C:/Users/vjuli/Documents/mochilalista-app/mochilalista_admin/web/index.html) (4.º comando `--verify-only --init-notes --no-pause`) y [plan23_5_fase4_release_guide_ui_test.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/mochilalista_admin/test/plan23_5_fase4_release_guide_ui_test.dart), junto con [plan24_fase4_init_notes_test.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/mochilalista_admin/test/plan24_fase4_init_notes_test.dart) en `Directory.systemTemp` e inmutabilidad verificada por SHA-256 sobre las notas reales `mochilalista_v9.41_atp*.txt`.

---

### FASE 5: Suite de Pruebas Integrales (QR Round-Trip `jsQR`, Verificación Cruzada Admin ↔ Móvil, UI y `--init-notes`)

**Objetivo:** Certificar al 100 % todas las piezas nuevas y verificar cero regresiones en ambos subproyectos.

#### Pruebas nuevas a implementar (100 % aisladas en `Directory.systemTemp` con `tearDown()`):
1. **`mochilalista_admin/test/plan24_fase1_mlc1_qr_and_cross_test.dart`:**
   * **Test 1 (QR Round-Trip real con `jsQR`):** Ejecuta en Node.js `qrcode.min.js` + `renderSafeQrCode()` sobre un token `MLC1-...` real de `1,990 B` y otro extendido con BCP+BBVA de `~2,300 B`, renderiza el patrón a un buffer RGBA puro (`512×512`) + quiet zone blanca de `32 px` (`576×576`, simulando exactamente `downloadQrWithQuietZone`) y decodifica con `jsqr.min.js` verificando `decoded.data === token`.
   * **Test 2 (Saneamiento de `Updates` `12 meses`):** Carga un `owner_config.json` legado en `tempDir` con `updates_window_months: 0` en `PERPETUO_LIBERADO` y `PASE_ACTUALIZACION_ANUAL`, valida `12` en `ConfigService`, `buildCanonicalPayload`, `/api/config/generate-sync-token` y `/api/config/dart-defaults-snippet`, y valida preservación de ediciones explícitas (`24`).
   * **Test 3 (Verificación de huella pública Admin ↔ Móvil):** Compara el SHA-256 de la clave pública derivada (sin imprimir clave privada ni semilla) contra `_defaultOfficialPublicKeyBytes` en `ed25519_license_validator.dart` confirmando `1c3ec0b9d87ff8acb49b1df871b65c0b40e47d1f11c65b348b5407b80a65e106`.
   * **Test 4 (Vía 2 Archivo Dart completo y análisis sintáctico):** Emite `owner_commercial_defaults.dart` vía `GET /api/config/dart-defaults-snippet` con cuentas BCP/BBVA y caracteres especiales (`'`, `$`), verifica que contiene clase completa `OwnerCommercialDefaults`, los 8 productos y pasa `dart analyze` en `tempDir`.
2. **`mochilalista_admin/test/plan24_fase2_mlc1_modal_ui_and_inspector_test.dart`:**
   * Auditoría HTML/CSS/JS de `#modalCommercialConfigSync` (tabs lado a lado en grid horizontal, tabla completa de 8 productos sin `0 d`, instrucciones cliente, botón `#btnAuditMlc1InInspector`, botones Vía 2 `#btnCopyMlc1Dart` + `#btnDownloadMlc1Dart`, soporte Dark + `[data-theme="light"]`, 0 emojis crudos, `<svg>` acotados y contratos intactos).
   * Ejecución real en Node.js del flujo completo: `openCommercialConfigSyncModal` → `generateMlc1SyncToken` → verificación de QR generado, descarga con quiet zone `32 px`, etiquetas claras (`Recarga`, `Pase anual`, `Único`, `12 meses`), descarga `.dart`, y clic en `#btnAuditMlc1InInspector` verificando cierre del modal, activación de `#tabInspector`, llenado de `#inspectTokenInput` y disparo de `inspectToken()`.
3. **`mochilalista_admin/test/plan24_fase4_init_notes_test.dart`:**
   * Pruebas en `Directory.systemTemp` de `compilar_release_dual.bat --verify-only --init-notes --no-pause`, `--dry-run --init-notes --no-pause`, creación UTF-8 sin BOM de `*_atp.txt` y `*_atp_cambios.txt`, no sobrescritura ante archivos existentes (`Ya existe en disco — respetada sin sobrescribir`), y ausencia total de secretos/contraseñas.
4. **`app_movil/test/plan24_mlc1_cross_verification_and_defaults_test.dart`:**
   * **Prueba cruzada real Admin ↔ Móvil:** Emite un token `MLC1-...` con la estructura exacta generada por `mochilalista_admin` (`v=1`, `ver`, `iat`, `sup`, `yh`, `yp`, `bcp` completo, `bbva` completo, 8 productos con `perpetua.um=12` y `pase_anual_updates.um=12`), lo verifica en el receptor real `CommercialConfigSyncService` + `CommercialCatalogProvider` de `app_movil`, y comprueba la paridad de los 8 productos, soporte, Yape/Plin, BCP y BBVA.
   * Verifica la integridad de `OwnerCommercialDefaults` ↔ `OwnerLegalIdentity` ↔ `EffectiveCommercialConfig.defaults()` y que la clave pública embebida mantiene el SHA-256 oficial `1c3ec0b9d87ff8acb49b1df871b65c0b40e47d1f11c65b348b5407b80a65e106`.

#### Ejecución obligatoria de certificación total (`FASE 5 CERTIFICADA`):
* `mochilalista_admin/test/plan24_fase5_cross_parity_test.dart` y `app_movil/test/plan24_mlc1_cross_verification_and_defaults_test.dart` implementadas y aprobadas verificando paridad pública SHA-256 (`1c3ec0b9d87ff8acb49b1df871b65c0b40e47d1f11c65b348b5407b80a65e106`) sin exponer secretos, vector `MLC1` completo Admin ↔ Móvil (BCP+BBVA, 8 productos, `um=12`), round-trip QR `jsqr.min.js` e integridad `OwnerCommercialDefaults` ↔ `OwnerLegalIdentity` ↔ `EffectiveCommercialConfig.defaults()`.
* `cd mochilalista_admin && dart analyze && dart test` (`100 %` en verde, `0` fallos).
* `cd app_movil && flutter analyze --no-pub && flutter test --no-pub -j 1` (`100 %` en verde, `0` fallos, sin tocar `lock_screen.dart` ni `local_db.dart` `v36`).
* Verificación real sin modificar notas de `v9.41`: `compilar_release_dual.bat --verify-only --init-notes --no-pause` certifica ambos APKs de `v9.41` e informa `Ya existe en disco — respetada sin sobrescribir` para ambas notas `.txt` reales en `C:\Users\vjuli\Documents\v-app-offline apks\`.

---

### FASE 6: Documentación Operativa, Acta Oficial de Cierre y Push Limpio (`CERTIFICADA`)

**Objetivo:** Actualizar la documentación oficial del propietario y cerrar el Plan Maestro 24 con trazabilidad completa y repositorio limpio.

#### Tareas (`COMPLETADAS`):
1. Actualizado [05_MANUAL_OPERATIVO_DEL_PROPIETARIO_Y_COMANDOS_RELEASE.md](file:///C:/Users/vjuli/Documents/mochilalista-app/informe_proyecto/05_MANUAL_OPERATIVO_DEL_PROPIETARIO_Y_COMANDOS_RELEASE.md) (UTF-8 sin BOM):
   * Guías `1.3` (ítem 4) y `1.11` (punto 4): documentado el modal `#modalCommercialConfigSync` mejorado (pestañas horizontales lado a lado, motor QR ISO/IEC 18004 V1–V40 con `CorrectLevel.L` y round-trip `jsQR` `576×576 px`, tabla de 8 productos con `12 meses` y etiquetas claras, guía cliente en 3 pasos, botón `Auditar esta ficha en Inspector` y Vía 2 exportando/descargando `app_movil/lib/core/config/owner_commercial_defaults.dart`).
   * Guía `2.3`: documentado `--init-notes`, `[Paso 6/6]` no destructivo y el 4.º comando copiable en `#dualBuildGuidePanel`.
2. Añadida la **Sección 4: Acta Oficial de Cierre y Certificación Final del Plan Maestro 24** con métricas reales verificadas.
3. Validación post-edición, auditoría `git check-ignore`, staging explícito de los **20 archivos** del Plan 24, commit y push limpio en `dev/mejoras-v9.0-comercializacion-seguridad` (**sin** `git tag` ni merge a `main`).

---

## 3. MATRIZ DE RIESGOS Y MITIGACIONES PREVENTIVAS

| Riesgo | Impacto | Mitigación Concreta Integrada |
|---|---|---|
| Regresión de tests existentes por cambios en `#dualBuildGuidePanel` o `EffectiveCommercialConfig.defaults()` | Bloqueo de suite previa (`plan23_5_fase4` o `license_screen_catalog`) | Preservar `yapePhone = OwnerLegalIdentity.supportPhone` en defaults por defecto de `EffectiveCommercialConfig`; actualizar coordinadamente la aserción de 3 → 4 botones en `plan23_5_fase4_release_guide_ui_test.dart`. |
| PNG del QR `MLC1` mayor a `1024 px` activando reescalado lineal en `v9.41.0+85` | Dificultad de lectura en galería móvil | Mantener canvas base en `512×512 px` con `tileSize` entero + quiet zone `32 px` = `576×576 px` (`< 1024 px`), certificado en prueba Node con `jsqr.min.js`. |
| Ruptura de harnesses Node en `admin_app.js` al añadir IDs DOM nuevos | Fallo de tests JS de Planes 22, 23 y 23.5 | Usar `?.` y guardas nulas en todos los nuevos IDs (`#btnAuditMlc1InInspector`, `#btnDownloadMlc1Dart`, `#mlc1QrMetaBadge`) y mantener intactos los 4 bloques contractuales de `admin_app.js`. |
| Sobrescritura accidental de notas reales `mochilalista_v9.41_atp*.txt` | Pérdida de ficha técnica redactada | En `--init-notes`, validar `Test-Path -LiteralPath` antes de abrir escritura; si existe, omitir escritura siempre e informar `Ya existe en disco — respetada sin sobrescribir`. |
| Pérdida accidental de BOM UTF-8 en `scripts/compilar_release_dual.ps1` | Error de sintaxis PowerShell 5.1 por bytes `0x93`/`0x94` | Hardening `NO_BOM_PARSE_ERRORS=0` mediante `[char]0x00D3`, `[char]0x00D1`, `[char]0x2014`, `(T "...")` y escritura explícita con único BOM `EF BB BF`. |
| Filtración de secretos en tests o consola | Incidente de seguridad | Jamás leer ni imprimir `seed`, contraseñas de `key.properties` ni `prod_*` en stdout; toda prueba de emisión o compilación se ejecuta en `Directory.systemTemp` con llaves y fixtures sintéticos. |

---

## 4. ACTA OFICIAL DE CIERRE Y CERTIFICACIÓN FINAL DEL PLAN MAESTRO 24

> [!NOTE]
> **Estado Final:** `100 % COMPLETADO Y CERTIFICADO` (Fases 1 a 6 cerradas sobre rama `dev/mejoras-v9.0-comercializacion-seguridad`, sin `git tag` ni merge a `main`).

### 4.1. Consolidado Técnico de las 6 Fases Ejecutadas
* **Fase 1:** Motor QR completo **ISO/IEC 18004 (Versiones 1–40, hasta `2,953 B`)** offline en `mochilalista_admin/web/js/qrcode.min.js`, selección automática de `CorrectLevel.L` para payloads `> 900 B` en `renderSafeQrCode()` (`admin_app.js`), y saneamiento de raíz `<= 0 -> 12` meses en `ConfigService._normalizeCatalogEntries()` y `CommercialConfigSyncService.buildCanonicalPayload()`.
* **Fase 2:** Rediseño UX de Vía 1 en `#modalCommercialConfigSync` (`web/index.html`, `web/css/styles.css`, `web/js/admin_app.js`): pestañas horizontales lado a lado (`grid-template-columns: repeat(2, minmax(0, 1fr))`), tabla completa de 8 productos sin `0 d`, guía cliente de 3 pasos, badge `#mlc1QrMetaBadge`, preview `220×220 px pixelated`, soporte Dark + `[data-theme="light"]` y botón 1-clic `Auditar esta ficha en Inspector` (`auditMlc1TokenInInspector()`).
* **Fase 3 (`Opción A` Vía 2):** Creación de [owner_commercial_defaults.dart](file:///C:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/config/owner_commercial_defaults.dart) (100 % declarativo), delegación limpia desde `OwnerLegalIdentity` y `EffectiveCommercialConfig.defaults()`, generador de archivo `.dart` completo (`generateOwnerCommercialDefaultsDartFile()`) certificado con `dart analyze` en `Directory.systemTemp`, campos `target_file_path` / `download_filename` en `server.dart`, y Vía 2 con **`Copiar Archivo Completo (.dart)`** y **`Descargar archivo .dart`** (`UTF-8 sin BOM`).
* **Fase 4:** Flag opcional **`--init-notes`** no destructivo en `scripts/compilar_release_dual.ps1` (extracción `MinSdk`/`TargetSdk`, fechas `America/Lima (GMT-5)`, creación en UTF-8 sin BOM solo cuando faltan e inmutabilidad estricta ante notas existentes), actualizado `#dualBuildGuidePanel` a 4 comandos copiables y `plan23_5_fase4_release_guide_ui_test.dart`.
* **Fase 5:** Hardening definitivo `NO_BOM_PARSE_ERRORS=0` en `scripts/compilar_release_dual.ps1` con único BOM `EF BB BF`, prueba cruzada de paridad Admin (`plan24_fase5_cross_parity_test.dart`) y suite móvil de verificación `MLC1` ↔ `OwnerCommercialDefaults` (`plan24_mlc1_cross_verification_and_defaults_test.dart`).
* **Fase 6:** Documentación integral UTF-8 sin BOM en `05_MANUAL_OPERATIVO_DEL_PROPIETARIO_Y_COMANDOS_RELEASE.md`, emisión de esta Acta Oficial de Cierre y commit/push limpio de los 20 archivos del Plan 24.

### 4.2. Métricas Literales de Certificación Dual
| Verificación | Alcance | Resultado Certificado |
|---|---|---|
| `node --check` (`qrcode.min.js`, `admin_app.js`) | Sintaxis Frontend + Motor QR ISO V1–V40 | Código `0` (`5/5` round-trip `jsqr.min.js`: V11-M `220 B`, V17-M `460 B`, V33-L `1,990 B` -> `576×576`, V36-L `2,350 B` -> `576×576`, V40-L `2,900 B` -> `704×704`) |
| `mochilalista_admin/` (`dart analyze` + `dart test`) | Suite Desktop completa (incluye Planes 23, 23.5 y 24 Fases 1–5) | `No issues found!` \| **`255/255` (`100 %`, `0` fallos, `0` omitidas)** |
| `app_movil/` (`flutter analyze --no-pub` + `flutter test --no-pub -j 1`) | Suite Móvil completa (sin tocar `lock_screen.dart`, SQLite `v36` ni `pubspec.yaml`) | `No issues found!` \| **`1,438/1,438` (`100 %`, `0` fallos, `0` omitidas)** |
| **Total combinado del Monorepo** | **`mochilalista_admin/` + `app_movil/`** | **`1,693/1,693` pruebas en verde** |
| Paridad de clave pública Ed25519 Admin ↔ Móvil | Comparación exclusiva de huella SHA-256 de clave pública (cero secretos) | `1c3ec0b9d87ff8acb49b1df871b65c0b40e47d1f11c65b348b5407b80a65e106` (coincidencia `1:1`) |
| `compilar_release_dual.bat --verify-only --init-notes --no-pause` | Binarios reales `v9.41.0+85` y notas `.txt` en `C:\Users\vjuli\Documents\v-app-offline apks\` | Código `0` \| Ambos APKs certificados RSA-4096 \| Notas existentes reportadas `Ya existe en disco — respetada sin sobrescribir` (SHA-256 idéntico antes/después) |
| Protección de secretos (`git check-ignore --no-index -v`) | `prod_*`, `owner_config.json`, `vault_keyring.json`, `.apk_inspection_cache.json`, `ed25519_master.key`, `*.apk`, `key.properties` | `8/8` rutas ignoradas y excluidas del staging |
