# PLAN MAESTRO DE REINGENIERÍA, MODERNIZACIÓN Y DESPLIEGUE REAL DE LA PLATAFORMA ADMIN
## MOCHILALISTA ADMIN — SISTEMA INTEGRAL DE CONTROL COMERCIAL, FIRMADO ASIMÉTRICO ED25519 Y GESTIÓN DE RELEASES LOCALES

**Titular y Autor Exclusivo:** Julio Angello Vasquez Navarro  
**Proyecto:** MochilaLista (Gestión Escolar, Comercial y Cotizador Inteligente con IA)  
**Entorno Operativo:** Laptop Personal del Propietario — Windows 11 / Navegador Web Local  
**Servidor de Control:** `mochilalista_admin/` (Dart Shelf / HTTP Server en `http://localhost:8080`)  
**Fecha de Diagnóstico y Planificación:** 14 de Noviembre de 2026  
**Documento Relacionado:** `informe_proyecto/05_MANUAL_OPERATIVO_DEL_PROPIETARIO_Y_COMANDOS_RELEASE.md`

---

## ÍNDICE GENERAL DEL PLAN MAESTRO
1. [Acta de Diagnóstico Forense en Vivo (`http://localhost:8080`) y Análisis de las 8 Capturas](#1-acta-de-diagnóstico-forense-en-vivo-y-análisis-de-las-8-capturas)
2. [Matriz de Discrepancias Críticas: Manual Operativo vs. Plataforma Real](#2-matriz-de-discrepancias-críticas-manual-operativo-vs-plataforma-real)
3. [FASE 1: Arquitectura de Doble Estado en Vivo (`🧪 Modo Sandbox / Pruebas` vs. `🏢 Modo Producción / Real`)](#fase-1-arquitectura-de-doble-estado-en-vivo-modo-sandbox-vs-modo-producción)
4. [FASE 2: Almacén Físico de APKs, Carga Directa Local y Gestión Completa en el Release Manager](#fase-2-almacén-físico-de-apks-carga-directa-local-y-gestión-completa-en-el-release-manager)
5. [FASE 3: Reparación del Error en Historial, Buscador Omnicanal y Libertad Total en el CRM de Clientes](#fase-3-reparación-del-error-en-historial-buscador-omnicanal-y-libertad-total-en-el-crm-de-clientes)
6. [FASE 4: Estudio Generador con Modo Personalizado Libre e Inspector con Lector de Imagen QR](#fase-4-estudio-generador-con-modo-personalizado-libre-e-inspector-con-lector-de-imagen-qr)
7. [FASE 5: Construcción de la Pestaña `📊 Finanzas, Auditoría y Respaldos` en Disco Duro](#fase-5-construcción-de-la-pestaña-finanzas-auditoría-y-respaldos-en-disco-duro)
8. [FASE 6: Estética Nivel Web Awards, Sincronización del Manual Operativo y Certificación E2E](#fase-6-estética-nivel-web-awards-sincronización-del-manual-operativo-y-certificación-e2e)
9. [Cronograma de Ejecución y Protocolo de Aprobación](#9-cronograma-de-ejecución-y-protocolo-de-aprobación)

---

## 1. ACTA DE DIAGNÓSTICO FORENSE EN VIVO Y ANÁLISIS DE LAS 8 CAPTURAS

Durante la inspección técnica realizada sobre el servidor en ejecución en `http://localhost:8080` (Proceso Windows PID `38168`) y el contraste visual contra las 8 capturas remitidas por el propietario, se determinaron con exactitud las causas raíces de cada anomalía:

### 1.1. Diagnóstico de Procesos y Conectividad HTTP
* **Causa Raíz del Error 404 en Endpoints Nuevos:** El servidor HTTP local estaba ejecutándose sobre una instancia en memoria iniciada con anterioridad a la incorporación de las rutas `/api/clients/:id/history`, `/api/releases/detect-local-build`, `/api/releases/distribution-matrix` y `/api/licenses/inspect`. En Dart, los scripts de servidor no aplican recarga en caliente automática sobre los procesos activos en segundo plano; al invocar el frontend una ruta no registrada en dicho proceso, el servidor devolvía `HTTP 404 Not Found` en formato JSON (`{"error":"Ruta no encontrada: /api/clients/CLI-001/history"}`).
* **Disparador del Error en Pantalla (`124450.png`):** En `admin_app.js`, la función `openClientHistoryModal()` realiza un `fetch('/api/clients/' + clientId + '/history')`. Al recibir código 404, lanzaba `throw new Error('Error al cargar historial')`, desembocando en el diálogo nativo invasivo: `localhost:8080 dice: Error al abrir historial: Error al cargar historial`.

### 1.2. Análisis Forense Específico por Captura

| Captura | Vista / Módulo | Fallo Evidenciado en la Captura | Impacto en la Operación Real del Propietario |
| :--- | :--- | :--- | :--- |
| **`124357.png`** | **Radar Comercial (Dashboard)** | Los KPIs muestran ingresos ficticios (`S/ 920.00` mes, `S/ 1045.00` total) y 4 clientes sembrados con datos inventados (`CLI-001` a `CLI-004`). | El propietario no puede usar la plataforma para sus finanzas reales porque sus cobros reales se mezclarían con números falsos. |
| **`124413.png`** | **Directorio de Clientes (CRM)** | La columna `DEVICE ID` divide el código en dos renglones (`ML-\n9K4B`), no hay botón para copiar el ID en 1 clic, falta el buscador omnicanal prometido y no hay botón directo de WhatsApp en las filas. | Pérdida de tiempo al intentar copiar identificadores de hardware y dificultad para filtrar clientes rápidamente entre decenas de librerías. |
| **`124421.png`** | **Modal Registrar Nuevo Cliente** | El formulario omite el campo `"Versión de App Instalada"` (prometido en la Sección 1.4 del Manual) y no ofrece la opción `"TRIAL GRATUITO (30 días — S/ 0.00)"`. | Todo cliente nuevo entra asumiendo planes de pago o versiones fijas sin poder registrar clientes en período de prueba inicial. |
| **`124439.png`** | **Modal Editar Datos de Cliente** | Solo permite modificar Razón Social, Dueño, RUC, Teléfono y Notas. No permite ajustar el Plan, la Fecha de Vencimiento, la Ventana de Updates, los Créditos IA Extra, el Nonce ni eliminar al cliente. | Inflexibilidad total: si el propietario comete un error al digitar una fecha o necesita corregir un plan de cortesía, queda bloqueado. |
| **`124450.png`** | **Interacción con Historial de Cliente** | Salta la ventana de alerta nativa del navegador: `Error al abrir historial: Error al cargar historial`. | Imposibilidad absoluta de auditar los pagos anteriores, tokens emitidos y dispositivos asociados a un comerciante. |
| **`124508.png`** | **Estudio Generador de Licencias** | Al elegir un cliente, no se muestra su estado actual (cuántos días le quedan, qué versión tiene). Además, los planes son estrictamente fijos; no hay panel para personalizar días, bonos IA o modos de cómputo. | El propietario no puede ofrecer acuerdos especiales (ej. 45 días, 15 días de prueba técnica o bonos de 50 escaneos de regalo). |
| **`124520.png`** | **Release Manager — Catálogo y Matriz** | Versiones con hashes falsos (`4a5b6c7d...`). En la matriz, un cliente que `"Requiere Pase / Renovación"` sigue mostrando habilitado el botón verde `[Enviar APK]`. No se puede marcar con 1 clic que un cliente ya actualizó ni eliminar versiones obsoletas. | Riesgo de enviar actualizaciones que bloqueen al cliente por falta de derecho, y descontrol en el registro de qué versión tiene cada comerciante en su teléfono. |
| **`124535.png`** | **Modal Registrar Versión del APK** | Solicita obligatoriamente un enlace externo (Google Drive/Servidor). No permite cargar el archivo `.apk` compilado en la laptop ni detecta automáticamente el binario universal/ligero. Falta el campo `"Mínima Versión Mayor: 9"`. | El propietario compila localmente en su máquina; verse forzado a subir el APK a Google Drive para registrarlo en su propia laptop es ineficiente y contradice el modelo autónomo offline. |
| **`124557.png`** | **Inspector Forense de Tokens ML9** | Solo permite escribir o pegar texto. No tiene soporte para soltar o seleccionar una imagen PNG del código QR o de la credencial oficial para auditarla visualmente. Discrepancia de nombres de claims con el manual. | Si un cliente envía una captura de su pantalla o una foto del QR por WhatsApp, el propietario tiene que tipear o copiar el token manualmente en vez de simplemente arrastrar la imagen al inspector. |

---

## 2. MATRIZ DE DISCREPANCIAS CRÍTICAS: MANUAL OPERATIVO VS. PLATAFORMA REAL

| Elemento / Capacidad | Prometido en `05_MANUAL_OPERATIVO...md` | Estado Real en `http://localhost:8080` | Solución de Reingeniería Requerida |
| :--- | :--- | :--- | :--- |
| **Pestaña `Auditoría y Respaldos`** | Descrita en el índice (Sección 1.3, ítem 5) como módulo dedicado para balance contable y snapshots. | **Inexistente.** Solo existen 5 pestañas y ninguna incluye la gestión integral de finanzas y backups. | Crear la pestaña formal **`📊 Finanzas, Auditoría y Respaldos`** con libro contable, filtros y gestor de copias físicas. |
| **Buscador Omnicanal en CRM** | "Tabla completa de negocios con búsqueda omnicanal" (Sección 1.3 y 1.4). | **Inexistente.** Solo hay botones de filtro por estado; no hay campo de texto para buscar por nombre, RUC o teléfono. | Implementar barra de búsqueda en tiempo real reactiva sobre todas las columnas de la tabla. |
| **Botón Directo de WhatsApp en Clientes** | "Acceso directo a WhatsApp" (Sección 1.3). | **Solo presente en Acciones Urgentes del Dashboard**, ausente en las filas principales del CRM de clientes. | Añadir botón directo con enlace preformateado a WhatsApp Web en cada fila del directorio. |
| **Almacenamiento Local de APKs** | "Compilación del APK Release Universal en `app_movil/build/...`" (Sección 2.4). | El modal exige una URL de descarga externa (`https://drive...`), ignorando los archivos compilados en disco. | Almacén físico en `mochilalista_admin/releases_apks/`, drag & drop de APKs y autodetección de 1 clic del build local. |
| **Apertura de Carpeta en Windows** | No documentado como función del servidor. | No implementado. El usuario debe buscar manualmente la ruta en el Explorador de Archivos. | Endpoint y botón `[📂 Mostrar en Carpeta de Windows]` que invoca `explorer.exe /select,...` con el archivo seleccionado. |
| **Nombres de Claims en Inspector** | Sección 1.5.2 menciona claims de estándar web (`sub`, `typ`, `exp`). | El motor Ed25519 de MochilaLista utiliza claves compactas optimizadas para QR (`d`, `p`, `y`, `n`, `e`, `u`, `v`, `b`, `c`). | Unificar la terminología en el manual, en el frontend y en las respuestas del API para coherencia 100%. |
| **Diálogos de Usuario** | El manual describe una plataforma ejecutiva y fluida. | Uso persistente de `window.alert()` nativo del navegador, tosco y bloqueante. | Sustituir todos los `alert()` por un sistema de **Notificaciones Toast Flotantes** y modales con diseño Glassmorphism. |

---

## 3. FASE 1: ARQUITECTURA DE DOBLE ESTADO EN VIVO (`🧪 MODO SANDBOX` VS. `🏢 MODO PRODUCCIÓN`)

### 3.1. Justificación y Fundamento de Diseño
El propietario necesita ensayar lanzamientos de prueba, probar qué sucede cuando un cliente vence o cambia de equipo, y verificar la generación de credenciales sin alterar sus registros contables verdaderos.  
Mezclar datos de prueba en la misma base de datos contamina los reportes ante la SUNAT o auditorías comerciales personales. Por tanto, se diseñará un **aislamiento criptográfico y de almacenamiento estricto a nivel de servidor**.

```
                           ┌────────────────────────────────────────┐
                           │      HEADER PLATAFORMA ADMIN           │
                           │   [ 🧪 Sandbox ]  /  [ 🏢 Producción ]  │
                           └──────────────────┬─────────────────────┘
                                              │
                      ┌───────────────────────┴───────────────────────┐
                      ▼                                               ▼
         ┌─────────────────────────┐                     ┌─────────────────────────┐
         │   🧪 MODO SANDBOX       │                     │   🏢 MODO PRODUCCIÓN    │
         │   Borde / Indicador     │                     │   Borde / Indicador     │
         │   Ámbar Neón            │                     │   Esmeralda / Azul Real │
         ├─────────────────────────┤                     ├─────────────────────────┤
         │ • sandbox_clients_db    │                     │ • prod_clients_db       │
         │ • sandbox_releases_db   │                     │ • prod_releases_db      │
         │ • releases_apks/sandbox │                     │ • releases_apks/prod    │
         │ • Datos simulados       │                     │ • 0 clientes ficticios  │
         │ • Botón [↺ Restaurar]   │                     │ • Datos reales 100%     │
         └─────────────────────────┘                     └─────────────────────────┘
```

### 3.2. Especificaciones Técnicas de Implementación

#### A. Persistencia Aislada en Disco
* **Rutas de Almacenamiento Sandbox:**
  * `mochilalista_admin/data/sandbox_clients_db.json`
  * `mochilalista_admin/data/sandbox_releases_db.json`
  * `mochilalista_admin/releases_apks/sandbox/`
* **Rutas de Almacenamiento Producción:**
  * `mochilalista_admin/data/prod_clients_db.json`
  * `mochilalista_admin/data/prod_releases_db.json`
  * `mochilalista_admin/releases_apks/prod/`
* Al iniciar la plataforma en Modo Producción por primera vez, si `prod_clients_db.json` no existe, se inicializará con un arreglo vacío `[]` (cero clientes, cero ingresos acumulados).

#### B. Endpoints de Control de Estado Dual (`server.dart`)
1. **`GET /api/system/mode`**:
   * Retorna el modo activo actual: `{"mode": "sandbox" | "prod", "label": "Modo Pruebas" | "Modo Producción"}`.
2. **`POST /api/system/mode`**:
   * Parámetros: `{"mode": "sandbox" | "prod"}`.
   * Cambia el puntero activo de bases de datos y almacén en `DatabaseService` en caliente sin apagar el servidor.
3. **`POST /api/system/reset-sandbox`**:
   * Solo disponible cuando el modo activo es `sandbox`.
   * Restaura los 4 clientes de prueba educativos y las versiones de demostración para que el propietario pueda reiniciar sus ensayos cuantas veces requiera.
4. **Soporte de Encabezado `X-App-Mode: sandbox|prod`**:
   * Permite que las llamadas API especifiquen o sincronicen el contexto de datos requerido.

#### C. Componentes de Interfaz en el Header Superior (`index.html`)
* **Interruptor Conmutador Segmentado (Toggle Switch):**
  * Botón izquierdo: `🧪 Modo Pruebas (Sandbox)` (estilo pill con indicador ámbar pulsante).
  * Botón derecho: `🏢 Modo Real (Producción)` (estilo pill con indicador esmeralda de alta fidelidad).
* **Botón `[↺ Restaurar Datos de Prueba]`:**
  * Visible dinámicamente **únicamente** cuando se encuentra activo el `Modo Pruebas`.
  * Al presionarlo, despliega un modal ejecutivo de confirmación antes de restablecer los datos de ensayo.
* **Banner Visual de Contexto:**
  * En Modo Pruebas, una línea sutil ámbar en el borde superior del dashboard recuerda: *"Estás en el entorno de pruebas. Ninguna emisión ni cobro aquí registrado afectará tus balances reales."*

---

## 4. FASE 2: ALMACÉN FÍSICO DE APKS, CARGA DIRECTA LOCAL Y GESTIÓN COMPLETA EN EL RELEASE MANAGER

### 4.1. Almacén Local de Binarios (`releases_apks/`)
Actualmente, el sistema simula rutas como `releases/mochilalista-9.23.0.apk` que no existen en el disco duro.  
Se implementará una carpeta física estructurada:
```
mochilalista_admin/
├── releases_apks/
│   ├── sandbox/
│   │   └── mochilalista-v9.23.0-sandbox.apk
│   └── prod/
│       ├── mochilalista-v9.24.0-universal.apk
│       └── mochilalista-v9.24.0-arm64-v8a.apk
```

### 4.2. Modal de Registro de Nueva Versión Rediseñado (`modalCreateRelease`)
Se sustituirá el campo obligatorio de URL externa por un **Cargador Dual Avanzado**:

#### Modo de Entrada A: Subir Archivo `.apk` desde la Computadora
* Zona Drag & Drop interactiva con soporte para arrastrar archivos `.apk` directamente desde cualquier carpeta de Windows.
* Botón clásico `[Seleccionar archivo .apk desde la PC]`.
* Al soltar o seleccionar el archivo:
  1. El cliente web realiza un envío `multipart/form-data` al endpoint `POST /api/releases/upload-apk`.
  2. El servidor almacena el archivo físicamente en `releases_apks/{mode}/`.
  3. El servidor calcula de inmediato mediante el paquete `crypto`:
     * **Hash SHA-256 Oficial:** 64 caracteres hexadecimales en minúsculas.
     * **Peso Exacto del Binario:** Expresado en MB con dos decimales (ej. `28.45 MB`).
  4. Los campos de texto en el formulario se rellenan automáticamente con los valores calculados.

#### Modo de Entrada B: Autodetectar e Importar Build Local con 1 Clic
* Un botón destacado: **`[⚡ Autodetectar e Importar Último APK Compilado]`**.
* El servidor escanea `../app_movil/build/app/outputs/flutter-apk/`:
  * Detecta si existe `app-release.apk` (versión universal) o `app-arm64-v8a-release.apk` (versión 64 bits optimizada).
  * Inspecciona `../app_movil/pubspec.yaml` para extraer el `version: 9.24.0+24`.
  * Copia el archivo APK físico a `releases_apks/{mode}/mochilalista-9.24.0.apk`.
  * Calcula SHA-256 y tamaño en MB, asignando automáticamente `version_name: 9.24.0`, `version_code: 24`, `db_schema_version: 35`.
* **Campo "Enlace de Descarga Externo (Opcional)":** Se mantiene únicamente como alternativa secundaria para propietarios que adicionalmente deseen alojar una réplica en Google Drive.
* **Campo "Mínima Versión Mayor Autorizada":** Selector numérico que fija la versión base requerida (por defecto: `9`), cumpliendo la especificación del manual.

### 4.3. Acciones Físicas en la Tabla de Versiones Publicadas
Para cada versión listada en el catálogo del Release Manager se habilitarán 4 acciones directas:

1. **`[⬇️ Descargar .APK]`:**
   * Enlace a `GET /api/releases/download/:versionName`.
   * Sirve el archivo binario almacenado con cabeceras `Content-Type: application/vnd.android.package-archive` y `Content-Disposition: attachment; filename="mochilalista-vX.Y.Z.apk"`.
2. **`[📂 Mostrar en Carpeta de Windows]`:**
   * Botón que invoca `POST /api/releases/reveal-file` enviando el nombre de versión.
   * El servidor ejecuta en Windows mediante `Process.run`:
     ```powershell
     explorer.exe /select,"C:\Users\vjuli\Documents\mochilalista-app\mochilalista_admin\releases_apks\prod\mochilalista-9.24.0.apk"
     ```
   * Windows abre inmediatamente la ventana del Explorador con el archivo `.apk` seleccionado, listo para arrastrarlo al chat de WhatsApp Web del cliente.
3. **`[📋 Ver / Editar Changelog]`:**
   * Modal para consultar las notas del parche y modificarlas si se desea agregar aclaraciones técnicas.
4. **`[🗑️ Eliminar Versión]`:**
   * Endpoint `DELETE /api/releases/:versionName`.
   * Elimina el registro del catálogo y borra el archivo binario físico de disco tras confirmación modal de seguridad.

### 4.4. Matriz Inteligente de Distribución y Coherencia Comercial
Corrección inmediata de la discrepancia detectada en la captura `124520.png`:
* **Caso 1: Cliente con Derecho Gratuito (`is_eligible_for_free == true`):**
  * Insignia verde: `✓ Derecho Gratuito Incluido`.
  * Botón principal: **`[📲 Enviar Actualización por WhatsApp]`** (con mensaje de felicitación por nueva versión).
  * Botón secundario: **`[✓ Marcar como Actualizado a vX.Y.Z]`** (actualiza `installed_version` en base de datos con 1 clic).
* **Caso 2: Cliente con Suscripción Vencida o Pase Requerido (`is_eligible_for_free == false`):**
  * Insignia ámbar: `⚠️ Requiere Pase Anual / Renovación`.
  * El botón verde `[Enviar APK]` queda **reemplazado** por:
    * Botón primario: **`[💳 Cotizar Pase / Renovación por WhatsApp]`** (mensaje pre-redactado indicando el costo oficial de S/ 150.00 o renovación de plan para desbloquear la actualización de funciones).
    * Botón secundario: **`[🔑 Ir a Emitir Pase]`** (redirige al Estudio de Licencias precargando el plan `PASE_ACTUALIZACION_ANUAL`).
    * Opción de autorización manual: Solo si el propietario decide explícitamente autorizar la entrega de cortesía se habilita el envío del APK.

---

## 5. FASE 3: REPARACIÓN DEL ERROR EN HISTORIAL, BUSCADOR OMNICANAL Y LIBERTAD TOTAL EN EL CRM DE CLIENTES

### 5.1. Solución de Raíz del Error en Historial de Cliente (`124450.png`)
* **Depuración del Endpoint:** Garantizar que el router en `server.dart` capture con precisión la expresión regular `/api/clients/([^/]+)/history` sin colisionar con `/api/clients/([^/]+)`:
  ```dart
  // Router jerárquico inequívoco:
  if (path.endsWith('/history') && method == 'GET') {
    final clientId = path.split('/')[3];
    final history = await dbService.getClientHistory(clientId);
    // ...
  }
  ```
* **Eliminación Total de `window.alert()`:** Toda notificación de éxito, error de red o confirmación se procesará mediante un contenedor de **Toasts Flotantes no intrusivos** en la esquina superior derecha (`#toastContainer`).

### 5.2. Modal Ejecutivo de Historial Multitestaña (`#modalClientHistory`)
El modal de historial se estructurará en dos pestañas claras:

```
┌────────────────────────────────────────────────────────────────────────┐
│ 📜 Historial Comercial — Librería & Bazar San Martín (Carlos Mendoza)   │
│ Titular: Carlos Mendoza (10458923412) • Dispositivo: ML-9K4B          │
│ Recaudación Total: S/ 280.00 • Estado: ACTIVA (ANUAL)                  │
├───────────────────────────────────┬────────────────────────────────────┤
│ [ Pestaña 1: Pagos y Licencias ] │ [ Pestaña 2: Hardware y Equipos ]  │
├───────────────────────────────────┴────────────────────────────────────┤
│                                                                        │
│ TABLA DE PAGOS Y CÓDIGOS EMITIDOS:                                     │
│ Fecha      │ Monto     │ Plan    │ Método │ Código ML9  │ Acciones    │
│ 14/11/2026 │ S/ 280.00 │ ANUAL   │ Yape   │ ML9-eyJk... │ [📋 Copiar]  │
│            │           │         │        │             │ [🖼️ Tarjeta] │
│                                                         │ [🚫 Anular] │
│                                                                        │
│ [+ Registrar Pago Manual Externo]                                      │
└────────────────────────────────────────────────────────────────────────┘
```

* **Acción `[📋 Copiar Código]`:** Copia el token original emitido directamente al portapapeles.
* **Acción `[🖼️ Ver / Descargar Tarjeta PNG]`:** Re-renderiza en Canvas HTML5 la credencial oficial de esa transacción específica para reenviarla al cliente.
* **Acción `[🚫 Anular Transacción]`:** Permite revertir un registro erróneo, recalculando el saldo total pagado y el vencimiento anterior.
* **Pestaña 2 (Historial de Dispositivos):** Muestra la trazabilidad de todos los celulares que tuvo el comerciante: DeviceID antiguo, nuevo DeviceID, fecha de migración, tarifa cobrada (ej. S/ 40.00) y motivo registrado.

### 5.3. Buscador Omnicanal en Tiempo Real y Formato Limpio de Tabla
* **Buscador Omnicanal Reactivo:**
  * Caja de búsqueda ubicada sobre la tabla de clientes con debounce de 150ms.
  * Realiza coincidencias automáticas en minúsculas/mayúsculas sobre:
    * Nombre comercial del negocio
    * Nombre del propietario
    * DNI / RUC
    * Teléfono de WhatsApp
    * DeviceID
    * Versión instalada
    * Notas u observaciones
* **Diseño Anti-Desborde de `DEVICE ID`:**
  * Estilo CSS obligatorio: `white-space: nowrap; font-family: monospace; letter-spacing: 1px;`.
  * Se renderiza en un solo renglón: `ML-9K4B`.
  * Se acompaña de un micro-botón `[📋]` para copiar el DeviceID en 1 clic.
* **Botón Directo de WhatsApp en la Fila:**
  * Enlace con icono oficial de WhatsApp y color verde corporativo que abre el chat directo con el número del cliente (`https://api.whatsapp.com/send?phone=...`).

### 5.4. Formulario de Alta y Edición con Control Total Bajo Reglas Seguras

#### En `Registrar Nuevo Cliente` (`#modalCreateClient`):
* Añadir campo desplegable: **"Plan Inicial de Alta"**:
  * `TRIAL GRATUITO (30 días — S/ 0.00)` *(Selección recomendada por defecto)*.
  * `MENSUAL (30 días — S/ 35.00)`.
  * `TRIMESTRAL (90 días — S/ 90.00)`.
  * `SEMESTRAL (180 días — S/ 160.00)`.
  * `ANUAL (365 días — S/ 280.00)`.
  * `PERPETUO LIBERADO (De por Vida — S/ 850.00)`.
* Añadir campo de texto: **"Versión de App Instalada"** (por defecto: `9.24.0`).
* Añadir selector de **"Créditos IA Extra Iniciales"** (por defecto: `0`).

#### En `Editar Cliente` (`#modalEditClient`):
Otorgar al propietario **control administrativo absoluto**:
* Razón Social y Nombre del Titular.
* DNI / RUC y Teléfono de WhatsApp.
* DeviceID Actual (con advertencia de seguridad).
* **Plan Actual Asignado** (`TRIAL`, `MENSUAL`, `TRIMESTRAL`, `SEMESTRAL`, `ANUAL`, `PERPETUO_LIBERADO`).
* **Estado de Licencia** (`ACTIVA`, `POR_VENCER`, `BLOQUEO_SUAVE`, `BLOQUEO_ESTRICTO`, `PERPETUA`).
* **Fecha de Expiración Exacta** (selector de fecha con calendario HTML5 `type="date"`).
* **Ventana de Actualizaciones (`updates_until`)** (selector de fecha con calendario).
* **Saldo de Créditos IA Extra** (campo numérico editable).
* **Siguiente Nonce Anti-Replay** (campo numérico).
* Notas internas del cliente.
* **Zona de Peligro:** Botón rojo **`[🗑️ Eliminar Cliente del Directorio]`** protegido por ventana modal de doble confirmación que solicita escribir el nombre del negocio antes de proceder con el borrado definitivo.

---

## 6. FASE 4: ESTUDIO GENERADOR CON MODO PERSONALIZADO LIBRE E INSPECTOR CON LECTOR DE IMAGEN QR

### 6.1. Estudio Generador de Licencias Ed25519 (`tabLicenseStudio`)

#### A. Tarjeta de Resumen en Tiempo Real del Cliente Seleccionado
Al elegir un cliente en el selector desplegable, se despliega una **Tarjeta Ejecutiva de Estado**:
* Negocio y Titular: `Librería El Estudiante (Carlos Mendoza)`
* Dispositivo Destino: `ML-9K4B` | Nonce Requerido: `#2`
* Plan Actual: `MENSUAL (Activa)` | Días Remanentes: `24 días restantes`
* Vencimiento Actual: `2027-01-13`
* Saldo de Créditos IA: `50 escaneos base + 0 extra`
* Versión Instalada: `v9.23.0` *(Alerta si hay nueva versión disponible)*

#### B. Panel de Personalización Avanzada (Acordeón Opcional)
Debajo del catálogo de los 8 planes oficiales, se habilitará el interruptor:
`[⚙️ Habilitar Ajustes Comerciales Personalizados]` que permite al propietario:
1. **Días a Otorgar Personalizados:** Campo numérico libre (ej. fijar 15 días para una prórroga corta o 45 días para una promoción).
2. **Bono de Créditos IA de Regalo:** Campo para añadir créditos extra sin costo adicional (`+X escaneos`).
3. **Modo de Cómputo de Caducidad:**
   * Selector: `Regla Acumulativa (Sumar a la fecha remanente)` vs. `Reiniciar Vigencia (Comenzar a contar desde hoy)`.
4. **Sobrescribir Fecha de Expiración:** Opción de elegir con calendario la fecha de vencimiento exacta deseada.

#### C. Panel de Entrega y Salida Multiformato
Al presionar `Generar Licencia Ed25519`, el panel derecho despliega:
* **Token Criptográfico Completo:** Con botón `[📋 Copiar Token]` y feedback visual.
* **Credencial Oficial PNG en Alta Definición (@2x / 900x520 px):**
  * Renderizada en Canvas HTML5 con degradado azul marino profundo, sellos dorados de autenticidad INDECOPI / Ley 822, titular, `DeviceID`, vigencia y QR nítido.
  * Botón 1: **`[⬇️ Descargar Tarjeta PNG]`** (descarga el archivo gráfico en disco).
  * Botón 2: **`[📋 Copiar Imagen al Portapapeles]`** (copia los bytes PNG al portapapeles de Windows para pegarla directamente en WhatsApp Web con `Ctrl + V`).
* **Código QR Aislado:** Para lectura directa desde el teléfono.
* **Botón `[📲 Enviar por WhatsApp]`:** Dispara el mensaje con el texto pre-redactado.
* **Botón `[🔍 Auditar en el Inspector]`:** Transfiere automáticamente el código recién emitido a la pestaña del Inspector Forense y cambia de pestaña para verificarlo al instante.

### 6.2. Inspector Forense de Tokens ML9 con Lector de Imágenes QR (`tabInspector`)

#### A. Unificación de Nombres de Claims del Payload
Se estandariza la tabla de correspondencia entre el estándar criptográfico de MochilaLista y la visualización en pantalla:

| Clave Compacta en Token | Nombre Técnico | Descripción del Claim |
| :---: | :--- | :--- |
| **`d`** | `device_id` / `deviceId` | Identificador único de hardware del teléfono (`ML-XXXX`). |
| **`p`** | `plan` | Tipo de plan comercial (`MENSUAL`, `ANUAL`, `PERPETUO_LIBERADO`, etc.). |
| **`y`** | `days_added` | Cantidad de días sumados a la vigencia. |
| **`n`** | `nonce` | Correlativo estricto anti-reutilización. |
| **`v`** | `min_app_version` | Versión mayor mínima de la aplicación requerida (ej. `9`). |
| **`iat`** | `emitted_at` | Marca de tiempo ISO-8601 de emisión en UTC. |
| **`u`** | `updates_until` | Fecha límite de actualizaciones para planes perpetuos. |
| **`b`** | `business_tag` | Nombre de fantasía o razón social del negocio. |
| **`c`** | `ai_extra_credits` | Créditos de escaneo IA sin vencimiento añadidos. |

#### B. Lector Óptico de Imagen QR (Arrastrar y Soltar)
Además de permitir escribir o pegar el código de texto `ML9-...`, el Inspector incorporará:
* Una zona de carga de imagen: **`[📷 Arrastra aquí la foto del QR o la Credencial PNG]`**.
* El motor JavaScript utiliza la librería ligera `jsQR` (o decodificación nativa mediante Canvas API) para procesar los píxeles de la imagen en el cliente, extraer el texto del código QR y rellenar el formulario de análisis forense en milisegundos.
* El propietario podrá auditar cualquier captura de pantalla que le envíe un cliente por WhatsApp simplemente arrastrándola al navegador.

---

## 7. FASE 5: CONSTRUCCIÓN DE LA PESTAÑA `📊 FINANZAS, AUDITORÍA Y RESPALDOS` EN DISCO DURO

Se creará la 6.ª pestaña principal en la barra de navegación superior: **`tabFinancesAndBackups`**, dividida en dos submódulos:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                      📊 FINANZAS, AUDITORÍA Y RESPALDOS EN DISCO                       │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 1. LIBRO CONTABLE DE INGRESOS Y COBRANZAS                                              │
│ [Desde: AAAA-MM-DD] [Hasta: AAAA-MM-DD] [Plan: Todos ▼] [Método: Todos ▼]              │
│ Total Recaudado: S/ 1,280.00  •  Ticket Promedio: S/ 160.00  •  [📥 Exportar Reporte]   │
│                                                                                        │
│ Fecha      │ Cliente / Negocio │ Titular    │ Monto    │ Plan   │ Método │ Referencia  │
│ 14/11/2026 │ Librería Central  │ C. Mendoza │ S/ 90.00 │ TRIMES │ Yape   │ Op. 98123   │
│ ...                                                                                    │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 2. CENTRO DE GESTIÓN DE RESPALDOS EN DISCO DURO (backups/)                             │
│ [📸 Crear Snapshot Manual Ahora]               [📂 Abrir Carpeta backups/ en Windows]  │
│                                                                                        │
│ Archivo                     │ Fecha y Hora        │ Tamaño  │ Motivo       │ Acciones  │
│ clients_2026-11-14T12-00.json │ 14/11/2026 12:00:00 │ 14.2 KB │ emit_code    │ [⬇️] [⏪] │
│ releases_2026-11-14T12-00.json│ 14/11/2026 12:00:00 │ 3.8 KB  │ save_release │ [⬇️] [⏪] │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### 7.1. Submódulo 1: Libro Contable de Ingresos y Cobranzas
* **Origen de Datos:** Consolida la lista completa de pagos registrados en `payment_history` de todos los clientes del entorno activo (`sandbox` o `prod`).
* **Filtros Interactivos:**
  * Rango de fechas (Selector `Desde` / `Hasta`).
  * Filtro por Plan (`MENSUAL`, `TRIMESTRAL`, `SEMESTRAL`, `ANUAL`, `PERPETUO_LIBERADO`, `BOLSA_IA`, etc.).
  * Filtro por Medio de Pago (`Yape`, `Plin`, `BCP`, `BBVA`, `Interbank`, `Efectivo`).
* **KPIs Dinámicos de Finanzas:**
  * `Total Recaudado`: Sumatoria exacta de los cobros filtrados en Soles (`S/`).
  * `Ticket Promedio`: Ingreso promedio por transacción.
  * `Canal Principal`: Medio de pago con mayor volumen monetario.
* **Exportación Contable:**
  * Botón **`[📥 Exportar Reporte Financiero (CSV)]`**: Genera un archivo CSV con Byte Order Mark UTF-8 (`\uFEFF`) para apertura directa en Microsoft Excel sin corrupciones de caracteres.

### 7.2. Submódulo 2: Centro de Gestión de Respaldos en Disco (`backups/`)
* **Endpoint `GET /api/backups`:** Escanea el directorio físico `mochilalista_admin/backups/` y devuelve la lista de archivos `.json` con fecha de modificación, tamaño en KB y motivo del respaldo.
* **Acciones en el Centro de Respaldos:**
  1. **`[📸 Crear Snapshot Manual Ahora]`:** Endpoint `POST /api/backups/create`. Ejecuta un volcado atómico inmediato de las bases de datos activas con la marca de tiempo actual.
  2. **`[📂 Abrir Carpeta backups/ en Windows]`:** Endpoint `POST /api/backups/open-folder`. Invoca `explorer.exe` en la ruta absoluta de `mochilalista_admin/backups/` para acceso físico inmediato.
  3. **`[⬇️ Descargar Respaldo]`:** Enlace de descarga directa del archivo `.json` para copiar a una memoria USB de almacenamiento frío.
  4. **`[⏪ Restaurar Sistema a este Punto]`:** Endpoint `POST /api/backups/restore`. Permite revertir la base de datos al estado de ese snapshot tras confirmación modal de seguridad, creando previamente un respaldo de seguridad del estado actual.

---

## 8. FASE 6: ESTÉTICA NIVEL WEB AWARDS, SINCRONIZACIÓN DEL MANUAL OPERATIVO Y CERTIFICACIÓN E2E

### 8.1. Refinamiento Visual y Erradicación de Emojis Sueltos
* **Iconografía Vectorial SVG Unificada:**
  * Se sustituirán los emojis de texto (`✏️`, `📜`, `🔄`, `🔑`, `📲`, `✓`, `🗑️`, `📂`) por iconos vectoriales SVG limpios, nítidos en pantallas Retina/4K y con estilos coherentes (`stroke`, `fill`, `viewBox="0 0 24 24"`).
* **Pulido de Temas Oscuro y Claro:**
  * **Tema Oscuro (Deep Obsidian):** Fondo `#0b0f19`, superficies `#111827`, acentos azul índigo `#3b82f6` y esmeralda `#10b981`.
  * **Tema Claro (Executive Slate):** Fondo `#f8fafc`, tarjetas `#ffffff`, bordes `#e2e8f0`, textos `#0f172a`.
  * Animaciones suaves con curvas cúbicas (`transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1)`).
* **Cero Advertencias en Consola (`F12`):**
  * Validación estricta de variables en JavaScript.
  * Supresión de errores de recursos huérfanos o peticiones fallidas.

### 8.2. Sincronización 100% Exacta del Manual Operativo (`05_MANUAL...md`)
Se revisará y actualizará cada una de las secciones de `informe_proyecto/05_MANUAL_OPERATIVO_DEL_PROPIETARIO_Y_COMANDOS_RELEASE.md` para reflejar con precisión quirúrgica:
1. El uso del Conmutador de Estado Dual (`Modo Sandbox` vs. `Modo Producción`).
2. El funcionamiento del Almacén Físico de APKs y el comando Windows `explorer.exe /select,...`.
3. El Buscador Omnicanal y las nuevas opciones de edición total en el CRM de clientes.
4. El Panel de Ajustes Comerciales Personalizados en el Estudio de Licencias.
5. El Lector de Imágenes QR en el Inspector Forense.
6. La operación del Libro Contable y el Centro de Respaldos en Disco de la nueva Pestaña 5.

### 8.3. Certificación Terminal y Batería de Pruebas Multiplataforma
* Verificación estática con `dart analyze` en `mochilalista_admin` (**0 issues**).
* Verificación estática con `flutter analyze --no-pub lib test` en `app_movil` (**0 issues**).
* Ejecución de las pruebas unitarias y de integración que validen:
  * El firmado asimétrico Ed25519 con claves reales.
  * La segregación de bases de datos `sandbox` vs `prod`.
  * La carga física y cálculo de integridad SHA-256 de archivos APK.

---

## 9. CRONOGRAMA DE EJECUCIÓN Y PROTOCOLO DE APROBACIÓN

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                   SECUENCIA DE EJECUCIÓN POR FASES QUIRÚRGICAS                   │
├─────────┬────────────────────────────────────────────────────────┬───────────────┤
│ Fase    │ Alcance Principal                                      │ Dependencias  │
├─────────┼────────────────────────────────────────────────────────┼───────────────┤
│ FASE 1  │ Doble Estado en Vivo (Sandbox vs. Producción)          │ Ninguna       │
│ FASE 2  │ Almacén Local de APKs, Subida y Release Manager Total │ Fase 1        │
│ FASE 3  │ Fix Historial, Buscador Omnicanal y Libertad CRM       │ Fase 1        │
│ FASE 4  │ Estudio Licencias Personalizado y Lector de Imagen QR │ Fase 1, 3     │
│ FASE 5  │ Pestaña Finanzas, Libro Contable y Respaldos en Disco  │ Fase 1, 2, 3  │
│ FASE 6  │ Estética SVG Web Awards, Sincronización Manual y Tests │ Fases 1 a 5   │
└─────────┴────────────────────────────────────────────────────────┴───────────────┘
```

> [!IMPORTANT]
> **COMPROMISO DE INTEGRIDAD Y NO REGRESIÓN:**  
> Ninguna línea de código existente de la app móvil ni de la lógica criptográfica de validación Ed25519 será alterada de manera que rompa las 76 pruebas certificadas en el turno anterior. La reingeniería elevará la plataforma administrativa al estándar comercial definitivo exigido por el propietario.

---
*Documento elaborado y listo para revisión del propietario.*  
**Julio Angello Vasquez Navarro** — *Desarrollador y Titular de MochilaLista*
