# PLAN MAESTRO 10: PERSISTENCIA BLINDADA FUERA DEL PROYECTO, PORTABILIDAD EN 1 CLIC (.MLVAULT) Y RECUPERACIÓN MULTI-LLAVE "A PRUEBA DE OLVIDOS" (ENVELOPE ENCRYPTION & DPAPI)

**Documento Oficial de Ingeniería y Seguridad Criptográfica**  
**Proyecto:** MochilaLista POS — Plataforma Administrativa Offline (`mochilalista_admin/`)  
**Autor y Titular Exclusivo:** Julio Angello Vasquez Navarro  
**Marco Legal:** Ley de Derecho de Autor (D.L. 822) e INDECOPI Perú • Ley de Protección de Datos Personales (Ley N° 29733)  
**Fecha de Emisión:** Noviembre 2026 (Versión 1.1 — Revisada y Blindada)  
**Estado:** PLAN REVISADO Y BLINDADO — LISTO PARA AUTORIZACIÓN DE EJECUCIÓN  

---

## ÍNDICE GENERAL

1. [Resumen Ejecutivo y Diagnóstico de Persistencia](#1-resumen-ejecutivo-y-diagnóstico-de-persistencia)
2. [Arquitectura Criptográfica y Modelo de Amenazas](#2-arquitectura-criptográfica-y-modelo-de-amenazas)
   * 2.1. Jerarquía Real de Cifrado de Sobre en 2 Niveles (`Key Slots -> VMK -> DEK -> Payload`)
   * 2.2. Algoritmos Criptográficos y Parámetros Estrictos
   * 2.3. Matriz de Análisis de Amenazas Mitigadas
3. [PILAR 1: Desacoplamiento y Espejo Cifrado Fuera de la Carpeta del Proyecto](#3-pilar-1-desacoplamiento-y-espejo-cifrado-fuera-de-la-carpeta-del-proyecto)
   * 3.1. Transparencia Total en la UI: Rutas Físicas Reales y Cero Dependencia de Caché
   * 3.2. Doble Almacenamiento Atómico Transaccional Cifrado (`%APPDATA%\MochilaListaAdminVault\`)
   * 3.3. Carpeta Espejo Secundaria Configurable (Nube Local: Google Drive / OneDrive)
   * 3.4. Auto-Recuperación Inteligente Asistida en 1 Clic al Arrancar `server.dart`
4. [PILAR 2: Paquete Portable Cifrado de 1 Clic (`.mlvault`)](#4-pilar-2-paquete-portable-cifrado-de-1-clic-mlvault)
   * 4.1. Especificación del Formato Binario/Estructurado `.mlvault` con Nonces y Tags Únicos
   * 4.2. Manifiesto Interno de Integridad SHA-256 Protegido en Payload
   * 4.3. Flujo de Exportación en 1 Clic sin Re-Imprimir Códigos
   * 4.4. Flujo de Importación, Desempaque y Recarga en Caliente en 5 Segundos
5. [PILAR 3: Seguridad y Recuperación Multi-Llave ("A Prueba de Olvidos" con Envelope Encryption)](#5-pilar-3-seguridad-y-recuperación-multi-llave-a-prueba-de-olvidos-con-envelope-encryption)
   * 5.1. Arquitectura de Llavero Maestro `vault_keyring.json` y Envoltura de `VMK`
   * 5.2. Factor 1: Confianza Nativa de Windows (`Windows DPAPI` por `stdin` — Cero Contraseñas Diarias)
   * 5.3. Factor 2: Archivo Llave Física de Respaldo (`llave_maestra_mochilalista.mlkey`)
   * 5.4. Factor 3: Kit de Emergencia Imprimible / PDF (8 Códigos Cortos de Rescate + Código QR)
   * 5.5. Factor 4: Bloqueo Local con PIN, Middleware HTTP 423 y Flujo "¿Olvidaste tu PIN?"
   * 5.6. Matriz de Garantías Criptográficas y Ausencia de Puntos Únicos de Falla
6. [PILAR 4: Asistente Guiado de Blindaje en 3 Pasos, Pruebas Aisladas y Manual Operativo](#6-pilar-4-asistente-guiado-de-blindaje-en-3-pasos-pruebas-aisladas-y-manual-operativo)
   * 6.1. Vista UI `#tabSecurityVault` en Sidebar y Asistente Guiado en 3 Pasos
   * 6.2. Documento Imprimible del Kit de Emergencia (`@media print` CSS para Papel o PDF)
   * 6.3. Suite de Pruebas Automatizadas Estrictamente Aisladas en `Directory.systemTemp`
   * 6.4. Actualización del Manual Operativo del Propietario (`05_MANUAL_OPERATIVO_DEL_PROPIETARIO_Y_COMANDOS_RELEASE.md`)
7. [Plan de Trabajo por Fases Secuenciales de Ejecución (Fases 1, 2, 3 y 4)](#7-plan-de-trabajo-por-fases-secuenciales-de-ejecución)
8. [Matriz de Trazabilidad de Archivos, Endpoints y Claves](#8-matriz-de-trazabilidad-de-archivos-endpoints-y-claves)

---

## 1. RESUMEN EJECUTIVO Y DIAGNÓSTICO DE PERSISTENCIA

### 1.1. Contexto Operativo Post-Plan 09
Con la culminación y certificación al 100% del **Plan Maestro 09**, la plataforma `mochilalista_admin/` alcanzó la paridad matemática y funcional con la app móvil (`app_movil/`):
* Motor criptográfico `Ed25519` con regla anti-doble conteo en claim `c`.
* Compatibilidad total con el esquema SQLite `v36` y versión móvil `v9.30.0+74`.
* Configuración centralizada del propietario (`data/owner_config.json`) con plantillas WhatsApp dinámicas y supresión bancaria inteligente.
* Motor exportador profesional a Microsoft Excel multi-hoja (`.xlsx`).
* Nueva interfaz ejecutiva basada en Sidebar colapsable, Dashboard con micro-gráficos SVG, CRM simplificado y Drawer 360° de cliente.

### 1.2. Diagnóstico del Estado Actual de Persistencia y Riesgos Latentes
A pesar de la excelencia visual y operativa alcanzada, una auditoría técnica profunda revela vulnerabilidades estructurales en la forma en que los datos críticos se almacenan físicamente:

```
[RUTAS ACTUALES DE PERSISTENCIA EN MOCHILALISTA_ADMIN]
c:\Users\vjuli\Documents\mochilalista-app\mochilalista_admin\
├── data/
│   ├── prod_clients_db.json          <-- Base de datos comercial real (Clientes, cobros, licencias)
│   ├── prod_releases_db.json         <-- Catálogo de versiones publicadas
│   ├── sandbox_clients_db.json       <-- Datos de prueba
│   └── owner_config.json             <-- Personalización, tarifas y cuentas bancarias
├── private_keys/
│   └── ed25519_master.key            <-- CLAVE MAESTRA PRIVADA (El activo más valioso de la empresa)
├── backups/                          <-- Snapshots locales automáticos
└── releases_apks/                    <-- Binarios APK compilados
```

#### Vulnerabilidades Críticas Identificadas:
1. **Acoplamiento Directo al Árbol del Proyecto Git:** Todos los archivos de producción viven dentro de la carpeta `mochilalista-app/mochilalista_admin/`. Si el propietario ejecuta comandos de limpieza (`git clean -fdx`), borra el repositorio para reclonarlo, o sufre una manipulación accidental en la carpeta `Documents/`, **la base de clientes y la clave privada Ed25519 podrían ser eliminadas irrevocablemente**.
2. **Falta de Portabilidad Asistida:** Si el propietario adquiere una nueva laptop, formatea Windows o desea operar temporalmente en otra computadora, actualmente debe copiar manualmente archivos dispersos a través del explorador de Windows, corriendo el riesgo de olvidar `ed25519_master.key` o `owner_config.json`, o exponerlos sin cifrar en un pendrive USB.
3. **El Dilema de la Contraseña Humana ("Miedo al Olvido"):** Para proteger copias de seguridad se suele recurrir a contraseñas maestras. Sin embargo, en la práctica comercial unipersonal, si el propietario olvida la contraseña compleja que puso hace 8 meses, **queda bloqueado de su propio negocio**. Obligar a memorizar contraseñas rígidas es una receta para el desastre operativo; no proteger los respaldos permite que cualquiera con acceso al archivo emita licencias piratas.
4. **Falsa Percepción del Usuario sobre el Navegador:** Al acceder a través de `http://localhost:8080`, un usuario novato podría creer erróneamente que sus clientes se guardan en la "caché del navegador" y temer que al limpiar cookies o cerrar Chrome se perderán sus datos. La UI debe comunicar de forma transparente y visual la ubicación física real y garantizar cero dependencia del navegador.

### 1.3. Objetivos Fundamentales del Plan Maestro 10 (Versión 1.1)
El **Plan Maestro 10** resuelve de raíz estas vulnerabilidades mediante cuatro pilares indivisibles:
1. **Doble almacenamiento atómico automático y cifrado** fuera del repositorio en `%APPDATA%\MochilaListaAdminVault\` + carpeta de nube local opcional, con auto-recuperación asistida en 1 clic al arrancar `server.dart` sin exponer jamás claves en texto plano.
2. **Paquete portable cifrado de 1 clic (`.mlvault`)** que empaqueta en 5 segundos clientes, cobros, configuración y clave privada bajo cifrado de grado militar `AES-256-GCM` con nonces y auth tags independientes por cada ranura.
3. **Seguridad y recuperación multi-llave "a prueba de olvidos" mediante Cifrado de Sobre en 2 Niveles (`VMK` + `DEK`):**
   * *Nivel 1 (Vault Master Key - `VMK`):* Clave simétrica de 256 bits generada una sola vez, que jamás toca el disco en texto plano, custodiada en `data/vault_keyring.json` bajo 4 factores independientes:
     * *Factor 1 (Windows DPAPI por `stdin`):* Desbloqueo sin contraseñas en su laptop diaria mediante las credenciales de Windows Hello.
     * *Factor 2 (Archivo Llave `.mlkey`):* Desbloqueo físico arrastrando un archivo guardado en USB o teléfono.
     * *Factor 3 (Kit de Emergencia PDF):* 8 códigos alfanuméricos cortos legibles y código QR imprimibles para recuperación infalible ante cualquier contingencia.
     * *Factor 4 (PIN Personal Opcional):* Pantalla de bloqueo local respaldada por middleware HTTP 423 y enlace *"¿Olvidaste tu PIN?"* recuperable en 1 clic.
   * *Nivel 2 (Data Encryption Key - `DEK`):* Clave efímera generada en cada exportación de `.mlvault`, envuelta por la `VMK`, permitiendo generar infinitos respaldos sin volver a imprimir códigos ni invalidar la llave USB existente.
4. **Asistente visual guiado de blindaje en 3 pasos** en la interfaz web, con barra de salud de seguridad, recarga en caliente de servicios y manual operativo actualizado.

---

## 2. ARQUITECTURA CRIPTOGRÁFICA Y MODELO DE AMENAZAS

### 2.1. Jerarquía Real de Cifrado de Sobre en 2 Niveles (`Key Slots -> VMK -> DEK -> Payload`)
Para eliminar la incoherencia técnica entre generar una clave de datos nueva en cada exportación y mantener válidos los códigos impresos y la llave USB previamente entregados al propietario, se adopta formalmente la arquitectura en **dos niveles criptográficos desacoplados**:

```
+---------------------------------------------------------------------------------------------------+
|                         NIVEL 1: LLAVE MAESTRA DE BÓVEDA (VMK - 256 bits)                         |
|         Generada una sola vez en el primer arranque. JAMÁS se guarda en texto plano en disco.     |
+---------------------------------------------------------------------------------------------------+
                                  |
         +------------------------+------------------------+------------------------+
         |                        |                        |                        |
         v                        v                        v                        v
+------------------+     +------------------+     +------------------+     +------------------+
|  Slot 1: DPAPI   |     |  Slot 2: .mlkey  |     | Slot 3: Rescate  |     |   Slot 4: PIN    |
| Enc_DPAPI(VMK)   |     | Enc_GCM(VMK,KEK) |     | 8x Enc_GCM(VMK)  |     | Enc_GCM(VMK,KEK) |
| (Windows Hello)  |     | (USB / Celular)  |     | (Papel / PDF)    |     | (Opcional Local) |
+------------------+     +------------------+     +------------------+     +------------------+
         |                        |                        |                        |
         +------------------------+------------------------+------------------------+
                                  | (Cualquiera de los 4 factores desenvuelve la misma VMK)
                                  v
+---------------------------------------------------------------------------------------------------+
|                  NIVEL 2: LLAVE EFÍMERA DE CIFRADO DE DATOS (DEK - 256 bits)                     |
|         Generada aleatoriamente en cada exportación de .mlvault o espejo de seguridad.            |
+---------------------------------------------------------------------------------------------------+
                                  |
         +------------------------+------------------------+
         |                                                 |
         v                                                 v
+-----------------------------------+             +-----------------------------------+
| ENVOLTURA DE LA DEK CON LA VMK    |             | CIFRADO DE LA CARGA ÚTIL COMERCIAL|
| wrapped_dek_by_vmk =              |             | Ciphertext =                      |
| AES-256-GCM(VMK, Nonce_12, DEK)   |             | AES-256-GCM(DEK, Nonce_12,        |
|                                   |             |             Payload_JSON_GZip,    |
|                                   |             |             AAD=PublicHeader)     |
+-----------------------------------+             +-----------------------------------+
```

#### Propiedades Criptográficas de la Jerarquía en 2 Niveles:
1. **Invarianza de los Factores Físicos:** El propietario descarga su `llave_maestra_mochilalista.mlkey` e imprime su Kit de Emergencia de 8 códigos **una sola vez**. A partir de ese momento, puede generar 50 archivos `.mlvault` distintos a lo largo de los meses; **todos y cada uno de esos archivos podrán ser abiertos con la misma llave USB y con cualquiera de los 8 códigos impresos**, porque los key slots custodian la misma `VMK` que desenvuelve la `DEK` correspondiente.
2. **Desempaque y Portabilidad a Nueva PC sin Invalidación:** Al migrar a una computadora nueva, el propietario usa su `.mlkey` o 1 código de rescate para desenvolver la `VMK`. La nueva computadora descifra la `DEK`, extrae los datos y **re-envuelve la misma `VMK` en su nuevo Windows DPAPI local**, dejando la nueva laptop lista para operar sin alterar ni requerir reimprimir los códigos de emergencia guardados.
3. **Cero Exposición de Secretos:** La `VMK` solo existe en la memoria RAM volátil del proceso de `server.dart`. En disco duro (tanto en `mochilalista_admin/data/vault_keyring.json` como en `%APPDATA%\MochilaListaAdminVault\vault_keyring.json`), la `VMK` únicamente reside envuelta en los slots criptográficos.

### 2.2. Algoritmos Criptográficos y Parámetros Estrictos
1. **Cifrado Simétrico Autenticado (AEAD):**
   * **Algoritmo:** `AES-256-GCM` (Galois/Counter Mode).
   * **Longitud de Claves (`VMK` y `DEK`):** 256 bits (32 bytes criptográficamente seguros vía `Random.secure()`).
   * **Nonces (IV):** 96 bits (12 bytes aleatorios obligatorios y únicos por cada ranura y por el payload).
   * **Etiquetas de Autenticación (Auth Tags):** 128 bits (16 bytes) para garantizar confidencialidad e integridad criptográfica simultánea.
   * **Datos Autenticados Adicionales (AAD):** El encabezado público del archivo (`format`, `version`, `created_at`, `app_version`, `db_schema_version`, `includes_master_key`) se pasa como AAD al descifrar el payload, impidiendo ataques de sustitución de cabecera.
2. **Derivación de Claves (KDF):**
   * **Algoritmo:** `PBKDF2` con pseudo-random function `HMAC-SHA256`.
   * **Iteraciones:** `100,000` iteraciones fijas.
   * **Salts:** Criptográficamente aleatorios de 128 bits (16 bytes) únicos por cada código de rescate y por el PIN.
3. **Cifrado de Plataforma Windows:**
   * **Mecanismo:** `Windows DPAPI` (`DataProtectionScope.CurrentUser`).
   * **Canal de Comunicación:** Estrictamente vía streams binarios/Base64 en `stdin` y `stdout` de PowerShell, sin exponer jamás argumentos en la línea de comandos del sistema operativo.

### 2.3. Matriz de Análisis de Amenazas Mitigadas

| Escenario de Amenaza | Riesgo sin Plan 10 | Mitigación Criptográfica con Plan 10 | Experiencia del Propietario |
| :--- | :--- | :--- | :--- |
| **1. Borrado accidental de la carpeta del proyecto** (`git clean`, formateo de partición dev, borrado accidental) | **Pérdida total** de clientes, cobros y clave privada Ed25519. | El espejo atómico en `%APPDATA%\MochilaListaAdminVault\` conserva la última versión íntegra y cifrada. | Al arrancar `server.dart`, detecta la pérdida y ofrece **Restaurar en 1 Clic** vía DPAPI. |
| **2. Robo de copia de respaldo en la nube** (Google Drive / OneDrive hackeado o compartido por descuido) | El atacante lee datos de clientes y extrae `ed25519_master.key` para emitir licencias piratas. | El archivo `.mlvault` está cifrado con `AES-256-GCM`. Sin la `VMK` (que requiere Windows DPAPI de la PC del dueño, la llave física o el código de rescate), el archivo es ruido indistinguible de datos aleatorios. | Seguridad militar garantizada sin esfuerzo diario. |
| **3. Olvido total de PIN o contraseña** | Bloqueo absoluto de la plataforma o pérdida de la copia cifrada. | **Arquitectura Multi-Llave:** La `VMK` está en 4 ranuras independientes. Si olvida el PIN, desbloquea con DPAPI (en su PC), con su archivo `.mlkey` o con 1 de sus 8 Códigos de Emergencia. | Reseteo de PIN en 5 segundos sin perder un solo registro. |
| **4. Cambio de Laptop o Formateo de Windows** | Proceso manual engorroso, riesgo de olvidar archivos o corromper permisos. | Exporta `.mlvault` a un pendrive USB. En la nueva laptop, arrastra `.mlvault` + `.mlkey` (o digita 1 Código de Rescate). | La nueva laptop queda 100% operativa y emitiendo licencias en 5 segundos. |
| **5. Acceso indebido de un tercero en la misma PC** (Préstamo temporal de laptop) | Un tercero abre `http://localhost:8080` y ve cobros o emite licencias no autorizadas. | Pantalla de bloqueo local protegida por middleware HTTP 423 con PIN de acceso. | Bloqueo total de endpoints API y pantalla; desbloqueo en 2 segundos por el propietario. |

---

## 3. PILAR 1: DESACOPLAMIENTO Y ESPEJO CIFRADO FUERA DE LA CARPETA DEL PROYECTO

### 3.1. Transparencia Total en la UI: Rutas Físicas Reales y Cero Dependencia de Caché
En la nueva vista del Sidebar (`Sistema > Seguridad y Portabilidad` - `#tabSecurityVault`), se dispondrá de un panel de **Transparencia Física de Almacenamiento**:
* **Ubicaciones Físicas Reales:** Visualización explícita de las rutas completas en el disco duro:
  * Directorio Local del Proyecto: `c:\Users\vjuli\Documents\mochilalista-app\mochilalista_admin\data\`
  * Bóveda Espejo Cifrada del Sistema: `C:\Users\vjuli\AppData\Roaming\MochilaListaAdminVault\`
  * Carpeta Espejo de Nube Local: `(Configurable por el usuario, ej. G:\Mi unidad\MochilaLista_Sync\)`
* **Métricas de Salud en Tiempo Real:** Tamaño en bytes, fecha y hora de última sincronización, y checksum SHA-256 de los archivos críticos:
  * `prod_clients_db.json`
  * `prod_releases_db.json`
  * `owner_config.json`
  * `ed25519_master.key`
  * `vault_keyring.json`
* **Mensaje Educativo de Seguridad:** Un banner permanente aclara al propietario:
  > *"Tus datos residen 100% en el almacenamiento físico de tu computadora. La plataforma web administrativa opera localmente sobre tu disco duro y no almacena ningún registro sensible en la memoria caché ni en las cookies del navegador. Si borras tu historial o cambias de navegador, tus datos permanecen totalmente a salvo."*

### 3.2. Doble Almacenamiento Atómico Transaccional Cifrado (`%APPDATA%\MochilaListaAdminVault\`)
Se crea el servicio especializado `VaultStorageService` en `mochilalista_admin/lib/vault_storage_service.dart`.
Para evitar que una copia en texto plano de la base comercial o de la clave privada quede expuesta en el perfil del usuario del sistema operativo:

> [!IMPORTANT]
> **REGLA DE ORO DE SEGURIDAD EN EL ESPEJO DEL SISTEMA:**  
> `%APPDATA%\MochilaListaAdminVault\` **NUNCA** almacena `ed25519_master.key` ni `prod_clients_db.json` en texto claro.  
> Almacena estrictamente un espejo cifrado `auto_mirror_latest.mlvault`, el llavero protegido `vault_keyring.json` y el manifiesto `vault_manifest.json`.

Cada vez que se invoque una escritura en modo Producción (`DatabaseService.saveClients`, `DatabaseService.saveReleases`, `ConfigService.saveConfig` o generación de claves en `LicenseSigner`):
1. Se persiste el archivo local en `mochilalista_admin/data/` (o `private_keys/`).
2. Se desenvuelve la `VMK` (vía DPAPI en memoria).
3. Se genera un paquete cifrado `auto_mirror_latest.mlvault` (`AES-256-GCM`) conteniendo la base comercial, la configuración y la clave maestra Ed25519.
4. Se escribe de forma atómica en `%APPDATA%\MochilaListaAdminVault\auto_mirror_latest.mlvault` (usando archivo temporal `.tmp` y renombrado atómico para resistir cortes de energía).
5. Se actualiza el manifiesto público `vault_manifest.json` en `%APPDATA%` con marcas de tiempo y el hash `ciphertext_sha256`.

### 3.3. Carpeta Espejo Secundaria Configurable (Nube Local)
El propietario podrá definir en `#tabSecurityVault` una ruta adicional en su sistema de archivos (ej. su carpeta local de Google Drive para escritorio o OneDrive).
* Cuando esta opción esté activa y la ruta sea válida, `VaultStorageService` sincronizará de forma asíncrona un archivo cifrado `MochilaLista_Backup_Sync.mlvault` en esa carpeta externa.
* **Garantía:** Si la cuenta de Google Drive o OneDrive sufre una filtración, el atacante solo obtiene un archivo cifrado con `AES-256-GCM`. Sin la `VMK` (que requiere el DPAPI de la laptop física, la llave física o el código impreso), el archivo es matemáticamente indescifrable.

### 3.4. Auto-Recuperación Inteligente Asistida en 1 Clic al Arrancar `server.dart`
Durante la inicialización de `server.dart:main()`:
1. `VaultStorageService.checkStorageHealth()` audita la presencia de los archivos críticos locales en `data/` y `private_keys/`.
2. **Detección de Pérdida Accidental:** Si `data/prod_clients_db.json` no existe (o está vacío) y `private_keys/ed25519_master.key` no existe, pero `%APPDATA%\MochilaListaAdminVault\` contiene `auto_mirror_latest.mlvault` íntegro:
   * `VaultStorageService` intenta desenvolver silenciosamente la `VMK` usando **Slot 1 (Windows DPAPI)** de la misma laptop.
   * Al confirmar que DPAPI descifra la `VMK`, la consola reporta:
     ```text
     ⚠️ [VaultStorageService] ALERTA: Directorio local 'data/' o 'private_keys/' vacío.
     🛡️ [VaultStorageService] Bóveda Espejo Cifrada detectada en: %APPDATA%\MochilaListaAdminVault
     🔑 [VaultStorageService] Validación DPAPI exitosa para el usuario actual de Windows.
     ℹ️ Servidor iniciado en MODO ASISTENCIA DE RECUPERACIÓN. Abre http://localhost:8080 para restaurar en 1 clic.
     ```
   * El endpoint `GET /api/vault/health` reporta el estado `RECOVERY_AVAILABLE`.
   * En la interfaz web se despliega automáticamente un modal emergente de alto contraste:
     > **¡Bóveda de Respaldo Cifrada Detectada!**  
     > Se detectó una instalación limpia o carpeta del proyecto borrada. Se encontró tu Bóveda Espejo completa y tu clave Ed25519 protegidas bajo tu usuario de Windows.  
     > **[Restaurar Todo en 1 Clic (Sin Contraseñas)]**
   * Al hacer clic, `POST /api/vault/recover-from-mirror` descifra el paquete, restaura los archivos en `data/` y `private_keys/`, ejecuta la **recarga en caliente de los servicios** y notifica el éxito de la restauración sin requerir reinicio del servidor.

---

## 4. PILAR 2: PAQUETE PORTABLE CIFRADO DE 1 CLIC (`.MLVAULT`)

### 4.1. Especificación del Formato Binario/Estructurado `.mlvault` con Nonces y Tags Únicos
El archivo `.mlvault` es un contenedor JSON estructurado codificado en UTF-8, donde **cada slot cifrado con AES-GCM cuenta con su propio nonce de 96 bits y auth tag de 128 bits**, eliminando por completo cualquier reutilización de vectores de inicialización:

```json
{
  "format": "MLVAULT",
  "version": "1.1.0",
  "created_at": "2026-11-19T20:30:00.000Z",
  "app_version": "9.30.0+74",
  "db_schema_version": 36,
  "includes_master_key": true,
  "stats": {
    "total_clients": 45,
    "total_licenses_issued": 128,
    "total_releases": 12
  },
  "wrapped_dek_by_vmk": {
    "cipher": "AES-256-GCM",
    "nonce_b64": "unique-12-bytes-nonce-for-dek",
    "auth_tag_b64": "16-bytes-tag-for-dek",
    "wrapped_key_b64": "ciphertext-of-256bit-dek"
  },
  "key_slots": {
    "slot_1_dpapi": {
      "type": "WINDOWS_DPAPI_CURRENT_USER",
      "wrapped_vmk_b64": "dpapi-protected-vmk-bytes"
    },
    "slot_2_file": {
      "type": "MLKEY_FILE",
      "cipher": "AES-256-GCM",
      "nonce_b64": "unique-12-bytes-nonce-for-slot2",
      "auth_tag_b64": "16-bytes-tag-for-slot2",
      "wrapped_vmk_b64": "ciphertext-of-vmk"
    },
    "slot_3_emergency": {
      "type": "RESCUE_CODES",
      "kdf": "PBKDF2-HMAC-SHA256",
      "kdf_iterations": 100000,
      "codes": [
        {
          "code_id": 1,
          "salt_b64": "16-bytes-salt-code1",
          "nonce_b64": "unique-12-bytes-nonce-code1",
          "auth_tag_b64": "16-bytes-tag-code1",
          "wrapped_vmk_b64": "ciphertext-of-vmk"
        },
        {
          "code_id": 2,
          "salt_b64": "16-bytes-salt-code2",
          "nonce_b64": "unique-12-bytes-nonce-code2",
          "auth_tag_b64": "16-bytes-tag-code2",
          "wrapped_vmk_b64": "ciphertext-of-vmk"
        },
        { "code_id": 3, "salt_b64": "...", "nonce_b64": "...", "auth_tag_b64": "...", "wrapped_vmk_b64": "..." },
        { "code_id": 4, "salt_b64": "...", "nonce_b64": "...", "auth_tag_b64": "...", "wrapped_vmk_b64": "..." },
        { "code_id": 5, "salt_b64": "...", "nonce_b64": "...", "auth_tag_b64": "...", "wrapped_vmk_b64": "..." },
        { "code_id": 6, "salt_b64": "...", "nonce_b64": "...", "auth_tag_b64": "...", "wrapped_vmk_b64": "..." },
        { "code_id": 7, "salt_b64": "...", "nonce_b64": "...", "auth_tag_b64": "...", "wrapped_vmk_b64": "..." },
        { "code_id": 8, "salt_b64": "...", "nonce_b64": "...", "auth_tag_b64": "...", "wrapped_vmk_b64": "..." }
      ],
      "qr_slot": {
        "cipher": "AES-256-GCM",
        "nonce_b64": "unique-12-bytes-nonce-qr",
        "auth_tag_b64": "16-bytes-tag-qr",
        "wrapped_vmk_b64": "ciphertext-of-vmk"
      }
    },
    "slot_4_pin": {
      "type": "PIN_OPTIONAL",
      "enabled": false,
      "kdf": "PBKDF2-HMAC-SHA256",
      "kdf_iterations": 100000,
      "salt_b64": "16-bytes-salt-pin",
      "nonce_b64": "unique-12-bytes-nonce-pin",
      "auth_tag_b64": "16-bytes-tag-pin",
      "wrapped_vmk_b64": "ciphertext-of-vmk"
    }
  },
  "payload_envelope": {
    "cipher": "AES-256-GCM",
    "compression": "GZIP",
    "nonce_b64": "unique-12-bytes-nonce-payload",
    "auth_tag_b64": "16-bytes-tag-payload",
    "ciphertext_sha256": "sha256-of-ciphertext-for-fast-integrity-check",
    "encrypted_payload_b64": "ciphertext-of-gzipped-payload-json"
  }
}
```

### 4.2. Manifiesto Interno de Integridad SHA-256 Protegido en Payload
Para evitar que un atacante inspeccione o altere los hashes individuales de los archivos sin descifrar el paquete, los hashes por archivo se trasladan **estrictamente al interior de la carga útil cifrada**:

```json
{
  "internal_manifest": {
    "clients_sha256": "hash-sha256-of-prod_clients_db.json",
    "releases_sha256": "hash-sha256-of-prod_releases_db.json",
    "config_sha256": "hash-sha256-of-owner_config.json",
    "master_key_sha256": "hash-sha256-of-ed25519_master.key",
    "total_records": { "clients": 45, "payments": 112, "releases": 12 }
  },
  "files": {
    "prod_clients_db_json": "[ ... array de clientes en texto plano ... ]",
    "prod_releases_db_json": "[ ... array de releases en texto plano ... ]",
    "owner_config_json": "{ ... objeto de configuracion ... }",
    "ed25519_master_key": "-----BEGIN PRIVATE KEY-----\n..."
  }
}
```
* Tras validar el Auth Tag de AES-GCM y descomprimir el payload, `VaultCryptoService` recalcula el hash SHA-256 de cada archivo en memoria y lo compara contra `internal_manifest`. Si existe cualquier discrepancia, la restauración se aborta inmediatamente.

### 4.3. Flujo de Exportación en 1 Clic sin Re-Imprimir Códigos
1. El propietario hace clic en **`Exportar Bóveda Portable (.mlvault)`** en `#tabSecurityVault`.
2. `server.dart` ejecuta:
   * Desenvuelve la `VMK` usando **Slot 1 (DPAPI)** (o el slot activo en memoria).
   * Genera una `DEK` efímera aleatoria de 256 bits.
   * Empaqueta y comprime en GZIP el payload JSON con su `internal_manifest`.
   * Cifra el payload con la `DEK` usando `AES-256-GCM` (generando nonce y tag únicos).
   * Envuelve la `DEK` con la `VMK` (`wrapped_dek_by_vmk`).
   * Copia las ranuras de clave existentes de `vault_keyring.json` (`slot_1_dpapi`, `slot_2_file`, `slot_3_emergency`, `slot_4_pin`).
3. El archivo resultante `MochilaLista_Vault_YYYY-MM-DD.mlvault` se descarga en el navegador.
4. **Beneficio Crucial:** El propietario **no tiene que volver a generar llaves físicas ni imprimir nuevos códigos**. Su pendrive USB y su hoja física guardada abren esta nueva exportación y cualquier exportación futura.

### 4.4. Flujo de Importación, Desempaque y Recarga en Caliente en 5 Segundos
Para mudar la plataforma a otra laptop o tras formatear Windows:
1. En la nueva laptop, se arranca `mochilalista_admin/` y se ingresa a `Seguridad y Portabilidad > Importar Bóveda`.
2. Se arrastra el archivo `.mlvault`.
3. Se selecciona el método de desbloqueo disponible:
   * **Opción A (Archivo `.mlkey`):** Se suelta el archivo llave desde la memoria USB.
   * **Opción B (Código de Rescate):** Se digita cualquiera de los 8 códigos de la hoja física.
   * **Opción C (PIN Personal):** Si configuró un PIN y lo recuerda.
   * **Opción D (Windows DPAPI):** Si es el mismo usuario de Windows en la misma máquina.
4. `VaultCryptoService` valida el factor seleccionado, desenvuelve la `VMK`, desenvuelve la `DEK`, descifra el payload y verifica los hashes del `internal_manifest`.
5. Si existían datos previos en la máquina, se crea un snapshot preventivo de seguridad en `backups/`.
6. Se escriben los archivos en `data/` y `private_keys/`.
7. **Re-envoltura de la VMK en la nueva PC:** La nueva laptop envuelve la `VMK` en su propio Windows DPAPI local, guardándola en su nuevo `data/vault_keyring.json`.
8. **Recarga en Caliente de Servicios (Hot Reload):**
   * `signer.reloadMasterKey()`
   * `dbService.reloadFromDisk()`
   * `configService.reloadFromDisk()`
9. La plataforma queda instantáneamente lista para operar: el CRM muestra todos los clientes y la firma Ed25519 emite licencias de inmediato sin requerir reiniciar el servidor.

---

## 5. PILAR 3: SEGURIDAD Y RECUPERACIÓN MULTI-LLAVE ("A PRUEBA DE OLVIDOS")

### 5.1. Arquitectura de Llavero Maestro `vault_keyring.json`
El archivo `data/vault_keyring.json` custodia localmente la `VMK` envuelta en los 4 factores, garantizando que el servidor conozca en todo momento cómo validar los accesos sin exponer secretos:

```json
{
  "format": "MLKEYRING",
  "version": "1.1.0",
  "updated_at": "2026-11-19T20:30:00.000Z",
  "key_slots": {
    "slot_1_dpapi": {
      "type": "WINDOWS_DPAPI_CURRENT_USER",
      "wrapped_vmk_b64": "..."
    },
    "slot_2_file": {
      "type": "MLKEY_FILE",
      "nonce_b64": "...",
      "auth_tag_b64": "...",
      "wrapped_vmk_b64": "..."
    },
    "slot_3_emergency": {
      "type": "RESCUE_CODES",
      "codes": [
        { "code_id": 1, "salt_b64": "...", "nonce_b64": "...", "auth_tag_b64": "...", "wrapped_vmk_b64": "..." }
      ],
      "qr_slot": { "nonce_b64": "...", "auth_tag_b64": "...", "wrapped_vmk_b64": "..." }
    },
    "slot_4_pin": {
      "type": "PIN_OPTIONAL",
      "enabled": false,
      "salt_b64": "...",
      "nonce_b64": "...",
      "auth_tag_b64": "...",
      "wrapped_vmk_b64": "..."
    }
  }
}
```

### 5.2. Factor 1: Confianza Nativa de Windows (`Windows DPAPI` por `stdin`)
* **Mecanismo:** La `VMK` se protege mediante `ProtectedData.Protect` con ámbito `CurrentUser`.
* **Blindaje por `stdin` / `stdout`:**  
  Para impedir que los bytes de la clave o criptogramas aparezcan en el Administrador de Tareas, visores de procesos (`Process Explorer`) o historial de comandos de PowerShell, `WindowsDpapiService` invoca `powershell.exe -NoProfile -NonInteractive -Command -` y alimenta los datos binarios/Base64 estrictamente a través del flujo de entrada estándar (**`stdin`**), leyendo la salida protegida desde **`stdout`**.
* **Comportamiento Operativo:**
  * En la laptop habitual del propietario, Windows reconoce su sesión iniciada (con Windows Hello PIN o huella).
  * La plataforma se desbloquea de forma transparente sin pedir claves.
  * Si un tercero copia ilegalmente el archivo a otra computadora o intenta abrirlo desde otra cuenta de Windows, DPAPI falla criptográficamente, protegiendo los datos.

### 5.3. Factor 2: Archivo Llave Física de Respaldo (`llave_maestra_mochilalista.mlkey`)
* **Mecanismo:** Se genera una clave simétrica `KEK_mlkey` de 256 bits (`Random.secure()`) que envuelve la `VMK` con `AES-256-GCM` (con nonce y tag únicos).
* **Custodia:** La clave `KEK_mlkey` se entrega al usuario en el archivo descargable `llave_maestra_mochilalista.mlkey` para guardarlo en un pendrive USB o en su teléfono celular. La clave en claro **nunca** se almacena en el servidor.
* **Uso:** En una laptop nueva, arrastrar `.mlvault` y `.mlkey` descifra la `VMK` y restaura el sistema en 5 segundos.

### 5.4. Factor 3: Kit de Emergencia Imprimible / PDF (8 Códigos Cortos de Rescate + Código QR)
* **Estructura de los 8 Códigos:**
  * Códigos alfanuméricos en formato legible: `ML-XXXX-YYYY-ZZZZ` (ej. `ML-7492-XKPQ-3815`).
  * Cada código cuenta con un salt independiente de 16 bytes y deriva su clave con `PBKDF2-HMAC-SHA256` a `100,000` iteraciones.
  * Cada código envuelve a la `VMK` con `AES-256-GCM` con su propio nonce de 12 bytes y auth tag de 16 bytes.
  * **Regla de Rescate:** **Basta ingresar CUALQUIERA de los 8 códigos para descifrar la `VMK` y restaurar la plataforma.**
* **Código QR de Rescate:** Contiene la clave directa `KEK_qr` codificada en Base64 para escaneo rápido con cámara o lector de códigos.

### 5.5. Factor 4: Bloqueo Local con PIN, Middleware HTTP 423 y Flujo "¿Olvidaste tu PIN?"
* **Protección Real del Servidor (Middleware HTTP 423 Locked):**  
  El bloqueo con PIN no es meramente un velo cosmético en JavaScript. Se implementa un **middleware de sesión en `server.dart`**:
  * Si `pin_enabled == true` y la petición HTTP no incluye una cabecera `X-Vault-Session-Token` válida:
  * El servidor rechaza inmediatamente todas las rutas `/api/*` devolviendo el código de estado estándar **`HTTP 423 Locked`** (`{"error": "Session is locked. Enter PIN or recovery factor."}`).
  * **Rutas Exentas del Bloqueo:**
    * `GET /api/vault/health`
    * `GET /api/vault/pin/status`
    * `POST /api/vault/pin/verify`
    * `POST /api/vault/pin/recover`
    * Recursos estáticos del frontend (`/`, `/css/*`, `/js/*`, etc.)
* **Protección Anti-Fuerza Bruta:**
  * Tras 5 intentos consecutivos erróneos de PIN, se activa un retardo progresivo (*exponential backoff*): 2s, 4s, 8s, 16s hasta un máximo de 30 segundos por intento.
* **Recuperación Inmediata "¿Olvidaste tu PIN?":**
  * Si el propietario olvida el PIN, hace clic en `"¿Olvidaste tu PIN?"`:
  * El sistema permite saltarse el bloqueo y redefinir el PIN al instante mediante la validación de cualquiera de los otros 3 factores:
    * Validación automática con Windows DPAPI (si está en su laptop de confianza).
    * Cargar el archivo `.mlkey`.
    * Ingresar 1 Código de Rescate.
  * El PIN se actualiza o desactiva en el acto **sin perder ningún cliente ni registro comercial**.

### 5.6. Matriz de Garantías Criptográficas y Ausencia de Puntos Únicos de Falla

```
+---------------------------------------------------------------------------------------------------+
| FACTOR EMPLEADO       | ¿REQUIERE MEMORIZAR? | ¿DÓNDE FUNCIONA?     | ¿QUÉ PROTEGE?              |
+-----------------------+----------------------+----------------------+----------------------------+
| 1. Windows DPAPI      | No (Windows Hello)   | Misma PC y usuario   | Uso diario con fricción 0  |
| 2. Archivo .mlkey     | No (Archivo en USB)  | Cualquier PC/laptop  | Mudanza rápida en 1 clic   |
| 3. Códigos Rescate/QR | No (Papel / PDF)     | Cualquier PC/laptop  | Contingencia extrema       |
| 4. PIN Local          | Sí (PIN de 4-8 dig)  | Navegador local      | Miradas de terceros en PC  |
+---------------------------------------------------------------------------------------------------+
```

---

## 6. PILAR 4: ASISTENTE GUIADO DE BLINDAJE EN 3 PASOS, PRUEBAS AISLADAS Y MANUAL OPERATIVO

### 6.1. Vista UI `#tabSecurityVault` en Sidebar y Asistente Guiado en 3 Pasos
Se agrega el ítem **`Seguridad y Portabilidad`** en el Sidebar (`web/index.html`) dentro del grupo `Sistema`.
La vista incluye el **Asistente Visual de Blindaje en 3 Pasos** y la **Barra de Progreso de Salud**:

```
+---------------------------------------------------------------------------------------------------+
| SALUD DE SEGURIDAD Y PORTABILIDAD                                                   [ 100% BLINDADO ] |
| [===============================================================================================] |
+---------------------------------------------------------------------------------------------------+
| PASO 1: BÓVEDA EXTERNA Y ESPEJO AUTOMÁTICO                             [ ACTIVO Y SINCRONIZADO ]  |
| • Espejo cifrado en %APPDATA%\MochilaListaAdminVault\ auto_mirror_latest.mlvault sincronizado.    |
| • Carpeta de Nube Local: G:\Mi unidad\MochilaLista_Sync\                                          |
| [ Cambiar Carpeta ]   [ Forzar Sincronización Manual ]                                            |
+---------------------------------------------------------------------------------------------------+
| PASO 2: ARCHIVO LLAVE FÍSICA (.mlkey)                                  [ LLAVE GENERADA Y ACTIVA ]|
| • Llave física generada el 19/11/2026. Úsala para abrir tu plataforma en otra PC sin contraseñas.|
| [ Descargar Archivo Llave (.mlkey) ]                                                              |
+---------------------------------------------------------------------------------------------------+
| PASO 3: KIT DE EMERGENCIA IMPRIMIBLE (8 CÓDIGOS + QR)                  [ KIT GENERADO Y VALIDADO ]|
| • 8 códigos cortos de rescate y código QR para recuperación ante cualquier contingencia extrema.  |
| [ Ver e Imprimir Kit de Emergencia PDF ]                                                          |
+---------------------------------------------------------------------------------------------------+
| MUDANZA Y PORTABILIDAD DE LA PLATAFORMA                                                           |
| [ Exportar Bóveda Portable (.mlvault) ]       [ Importar Bóveda Portable desde Archivo ]          |
+---------------------------------------------------------------------------------------------------+
| BLOQUEO LOCAL DE PANTALLA                                                                         |
| [ ] Proteger consola local con PIN al iniciar sesión (Middleware HTTP 423)                       |
+---------------------------------------------------------------------------------------------------+
```

### 6.2. Documento Imprimible del Kit de Emergencia (`@media print` CSS para Papel o PDF)
* Plantilla HTML/CSS embebida estilizada:
  * Logotipo corporativo de MochilaLista y sellos legales (D.L. 822 e INDECOPI).
  * Titular: `Julio Angello Vasquez Navarro`.
  * Cuadrícula tipográfica clara con los **8 Códigos Cortos de Rescate**.
  * Código QR vectorial de alta definición.
  * Reglas CSS `@media print` que aseguran contraste perfecto a 300 DPI, eliminando barras de navegación y fondos oscuros.

### 6.3. Suite de Pruebas Automatizadas Estrictamente Aisladas en `Directory.systemTemp`
* Todas las suites de prueba operarán dentro de directorios temporales aislados (`Directory.systemTemp.createTempSync('ml_vault_test_')`).
* Queda **estrictamente prohibido** leer, escribir o borrar sobre los archivos de producción reales.

#### Suites Requeridas:
1. `test/vault_crypto_test.dart`:
   * Generación y persistencia de `VMK` en `vault_keyring.json`.
   * Envoltura con nonces y tags únicos por cada ranura (DPAPI, `.mlkey`, 8 códigos, QR, PIN).
   * Generación de `DEK` efímera y envoltura con `VMK`.
   * Cifrado/descifrado de payload con `AES-256-GCM` y validación de `internal_manifest`.
   * Desbloqueo individual exitoso con cada uno de los 4 factores.
   * Rechazo inmediato ante alteración de bytes o nonces duplicados.
2. `test/vault_storage_and_recovery_test.dart`:
   * Doble escritura atómica hacia espejo cifrado `%APPDATA%`.
   * Detección de carpeta local vacía y auto-recuperación exitosa en 1 clic.
   * Mudanza simulada multi-PC con recarga en caliente de servicios y verificación cruzada de firmas Ed25519.
3. `test/security_vault_ui_test.dart`:
   * Verificación de elementos HTML en `web/index.html` y estilos `@media print`.
   * Verificación del middleware de sesión en `server.dart` (retorno de `HTTP 423 Locked`).
   * Verificación de sintaxis con `node --check`.

### 6.4. Actualización del Manual Operativo del Propietario
Se actualizará el documento oficial:
`informe_proyecto/05_MANUAL_OPERATIVO_DEL_PROPIETARIO_Y_COMANDOS_RELEASE.md`
Añadiendo el **Capítulo 8: Manual de Portabilidad, Respaldo Fuera del Proyecto y Recuperación Multi-Llave**.

---

## 7. PLAN DE TRABAJO POR FASES SECUENCIALES DE EJECUCIÓN

```
+---------------------------------------------------------------------------------------------------+
|                                 CRONOGRAMA DE EJECUCIÓN DEL PLAN 10                               |
+---------------------------------------------------------------------------------------------------+
| FASE 1: Motor Criptográfico Envelope Encryption en 2 Niveles y Servicio DPAPI                    |
| • lib/vault_crypto_service.dart (VMK + DEK, slots con nonces/tags únicos, 8 códigos PBKDF2)       |
| • lib/dpapi_service.dart (WindowsDpapiService vía stdin/stdout + MockDpapiService)               |
| • test/vault_crypto_test.dart (100% pruebas en verde sobre Directory.systemTemp)                  |
+---------------------------------------------------------------------------------------------------+
| FASE 2: Doble Almacenamiento Cifrado, Espejo %APPDATA%, Recarga en Caliente y Endpoints REST      |
| • lib/vault_storage_service.dart (Sincronización de auto_mirror_latest.mlvault y auto-recuperación)|
| • lib/license_signer.dart (Método reloadMasterKey)                                                |
| • Hooks y reloadFromDisk en lib/database_service.dart y lib/config_service.dart                   |
| • Endpoints REST y Middleware HTTP 423 en server.dart (/api/vault/*)                              |
| • test/vault_storage_and_recovery_test.dart (100% pruebas en verde)                                |
+---------------------------------------------------------------------------------------------------+
| FASE 3: Interfaz Web del Centro de Seguridad, Asistente de 3 Pasos y Kit de Emergencia PDF        |
| • web/index.html (Nuevo tab #tabSecurityVault en Sidebar > Sistema, modales y kit imprimible)     |
| • web/css/styles.css (Barra de progreso, cuadrícula de códigos y estilos @media print)            |
| • web/js/admin_app.js (Conexión a endpoints, drag & drop .mlvault, asistente y bloqueo PIN)     |
| • test/security_vault_ui_test.dart (100% pruebas en verde y node --check en 0)                    |
+---------------------------------------------------------------------------------------------------+
| FASE 4: Auditoría Integral en Vivo, Pruebas Cruzadas de Traslado Multi-PC y Cierre                |
| • Auditoría en vivo en http://localhost:8080 en servidor real                                     |
| • Simulación E2E de mudanza a otra PC                                                             |
| • Actualización de 05_MANUAL_OPERATIVO_DEL_PROPIETARIO_Y_COMANDOS_RELEASE.md                      |
| • Certificación completa: dart analyze, dart test, flutter test y Acta de Cierre                  |
+---------------------------------------------------------------------------------------------------+
```

---

## 8. MATRIZ DE TRAZABILIDAD DE ARCHIVOS, ENDPOINTS Y CLAVES

### 8.1. Archivos a Crear y Modificar

| Componente | Archivo | Tipo de Acción | Propósito en el Plan 10 |
| :--- | :--- | :---: | :--- |
| **Criptografía** | `mochilalista_admin/lib/vault_crypto_service.dart` | **Crear** | Cifrado `AES-256-GCM`, jerarquía `VMK` + `DEK`, key slots con nonces/tags únicos, PBKDF2 y manifiesto interno. |
| **Seguridad SO** | `mochilalista_admin/lib/dpapi_service.dart` | **Crear** | Interfaz `DpapiService`, `WindowsDpapiService` (PowerShell wrapper vía `stdin`/`stdout`) y `MockDpapiService`. |
| **Almacenamiento**| `mochilalista_admin/lib/vault_storage_service.dart` | **Crear** | Doble escritura atómica hacia `auto_mirror_latest.mlvault`, sincronización `%APPDATA%`, nube y auto-recuperación. |
| **Firma Licencias**| `mochilalista_admin/lib/license_signer.dart` | **Modificar** | Incorporación de `reloadMasterKey({String keyPath})` para recarga en caliente tras importar o recuperar bóveda. |
| **Persistencia** | `mochilalista_admin/lib/database_service.dart` | **Modificar** | Incorporación de `reloadFromDisk()` y hook de sincronización atómica tras escritura de clientes/releases. |
| **Configuración** | `mochilalista_admin/lib/config_service.dart` | **Modificar** | Incorporación de `reloadFromDisk()` y hook de sincronización atómica del espejo tras guardar configuración. |
| **Servidor HTTP** | `mochilalista_admin/server.dart` | **Modificar** | Detección de auto-recuperación en arranque, middleware de sesión HTTP 423 con PIN y endpoints `/api/vault/*`. |
| **Estructura UI** | `mochilalista_admin/web/index.html` | **Modificar** | Ítem `Seguridad y Portabilidad` en Sidebar, vista `#tabSecurityVault`, modales y kit imprimible. |
| **Estilos UI** | `mochilalista_admin/web/css/styles.css` | **Modificar** | Estilos para tarjetas de salud, barra de progreso, cuadrícula de códigos y reglas `@media print`. |
| **Lógica UI** | `mochilalista_admin/web/js/admin_app.js` | **Modificar** | Conexión con endpoints de bóveda, drag & drop de `.mlvault`, asistente de 3 pasos y bloqueo PIN. |
| **Pruebas** | `mochilalista_admin/test/vault_crypto_test.dart` | **Crear** | Tests de Envelope Encryption en 2 niveles, PBKDF2, nonces únicos, validación de integridad y descifrado. |
| **Pruebas** | `mochilalista_admin/test/vault_storage_and_recovery_test.dart` | **Crear** | Tests de doble escritura cifrada, auto-recuperación desde `%APPDATA%` y mudanza simulada a otra PC. |
| **Pruebas** | `mochilalista_admin/test/security_vault_ui_test.dart` | **Crear** | Verificación de elementos HTML, estilos CSS `@media print`, middleware de PIN y funciones JavaScript. |
| **Manual** | `informe_proyecto/05_MANUAL_OPERATIVO_DEL_PROPIETARIO_Y_COMANDOS_RELEASE.md` | **Modificar** | Guía práctica de portabilidad a nueva laptop y protocolo de emergencia con Kit de Rescate. |

### 8.2. Catálogo Oficial de Nuevos Endpoints REST (`server.dart`)

| Método | Endpoint | Descripción Operativa |
| :--- | :--- | :--- |
| `GET` | `/api/vault/health` | Reporta el estado de salud de la persistencia: rutas físicas reales, fechas de modificación, hashes SHA-256, estado de sincronización con `%APPDATA%` y flag `recovery_available`. *(Exento de bloqueo PIN)*. |
| `POST` | `/api/vault/sync-mirror` | Fuerza la sincronización atómica manual de todos los datos de producción hacia `auto_mirror_latest.mlvault` en `%APPDATA%\MochilaListaAdminVault\` y la carpeta de nube local. |
| `POST` | `/api/vault/set-cloud-path` | Configura o actualiza la ruta de la Carpeta Espejo de Nube Local (ej. Google Drive o OneDrive). |
| `POST` | `/api/vault/recover-from-mirror` | Restaura en 1 clic los datos de producción y la clave `Ed25519` desde el espejo cifrado de `%APPDATA%` hacia la carpeta del proyecto, ejecutando recarga en caliente. |
| `POST` | `/api/vault/export` | Genera y descarga el paquete portable cifrado `MochilaLista_Vault_YYYY-MM-DD.mlvault` con envelope encryption y manifiesto SHA-256. Acepta parámetro `include_master_key: true/false`. |
| `POST` | `/api/vault/inspect` | Inspecciona un archivo `.mlvault` sin desempaquetarlo: extrae metadatos públicos, fecha de creación, conteo de clientes y ranuras de clave disponibles. |
| `POST` | `/api/vault/import` | Desempaqueta y restaura una bóveda `.mlvault` en la plataforma, validando la clave proporcionada (DPAPI, `.mlkey`, código de rescate o PIN). Ejecuta recarga en caliente de servicios. |
| `POST` | `/api/vault/generate-rescue-kit` | Genera los 8 códigos cortos de rescate y la clave QR para el Kit de Emergencia imprimible, envolviendo la `VMK` en los slots correspondientes. |
| `GET` | `/api/vault/download-mlkey` | Genera y descarga el archivo llave física oficial `llave_maestra_mochilalista.mlkey` vinculado a la `VMK` actual. |
| `GET` | `/api/vault/pin/status` | Reporta si el bloqueo por PIN local está activo y si la sesión actual se encuentra bloqueada o autenticada. *(Exento de bloqueo PIN)*. |
| `POST` | `/api/vault/pin/configure` | Configura o actualiza el PIN de bloqueo local en la interfaz web. |
| `POST` | `/api/vault/pin/verify` | Valida el PIN ingresado en la pantalla de bloqueo local y emite el token de sesión. *(Exento de bloqueo PIN)*. |
| `POST` | `/api/vault/pin/recover` | Permite restablecer o desactivar el PIN de bloqueo local validando mediante Windows DPAPI, archivo `.mlkey` o 1 Código de Rescate. *(Exento de bloqueo PIN)*. |

### 8.3. Blindaje en `.gitignore`
Se verificará que las siguientes rutas continúen 100% blindadas en el archivo `.gitignore` raíz y en `mochilalista_admin/.gitignore`, garantizando que ninguna bóveda ni clave sea subida por error a repositorios remotos:
```gitignore
# Archivos de Claves Criptográficas y Bóvedas de Seguridad
mochilalista_admin/private_keys/
mochilalista_admin/data/prod_clients_db.json
mochilalista_admin/data/prod_releases_db.json
mochilalista_admin/data/owner_config.json
mochilalista_admin/data/vault_keyring.json
data/vault_keyring.json
mochilalista_admin/backups/
*.mlvault
*.mlkey
```

---

## 9. DECLARACIÓN FORMAL DE CIERRE DEL DISEÑO

El presente **Plan Maestro 10 (Versión 1.1)** establece una arquitectura definitiva, realista y matemáticamente inexpugnable para la persistencia, portabilidad y recuperación de la plataforma administrativa de MochilaLista. Integra la jerarquía criptográfica en 2 niveles (`VMK` + `DEK`), el espejo cifrado en `%APPDATA%`, la recarga en caliente de servicios y el blindaje por `stdin` de DPAPI y middleware HTTP 423 para el PIN.

Queda presentado para la revisión y aprobación del propietario Julio Angello Vasquez Navarro antes de autorizar el inicio de la **Fase 1** en código fuente.
