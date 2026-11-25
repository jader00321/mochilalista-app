# 05. MANUAL OPERATIVO DEL PROPIETARIO, GENERACIÓN DE LICENCIAS Y COMANDOS DE RELEASE

**Proyecto:** MochilaLista — Sistema Comercial Offline-First de Punto de Venta, Inventarios, Cotizaciones Inteligentes y Fidelización CRM  
**Titular y Autor Exclusivo:** Julio Angello Vasquez Navarro  
**Derechos de Propiedad Intelectual:** Registrado y protegido bajo el Decreto Legislativo 822 (Ley sobre el Derecho de Autor) y directrices de INDECOPI (Perú)  
**Fecha de Certificación y Cierre:** Noviembre 2026  
**Identificador de Paquete Android:** `com.mochilalista.app`  

---

## INTRODUCCIÓN Y OBJETO DEL MANUAL

Este documento constituye el **Manual Oficial de Operaciones Comerciales, Criptográficas y de Ingeniería de Release** redactado para uso exclusivo de **Julio Angello Vasquez Navarro**.

Aquí se detallan todos los procedimientos paso a paso, comandos de terminal, protocolos criptográficos y reglas de contingencia para gestionar el negocio comercial de **MochilaLista**, operar el **Centro Ejecutivo de Control, Licencias y Versiones (`http://localhost:8080`)** con sus **8 pestañas oficiales**, conmutar entre el **Modo Pruebas (Sandbox)** y el **Modo Real (Producción)**, generar licencias asimétricas Ed25519 con ajuste estándar o personalizado, exportar libros contables profesionales a **Microsoft Excel Multi-Hoja (`.xlsx`) de 5 hojas oficiales**, personalizar la identidad corporativa en caliente (`owner_config.json`), compilar binarios firmados y ofuscados (APK Universal y APK Ligero ARM64 para WhatsApp), auditar códigos ópticamente con el lector QR integrado, asegurar la persistencia en **bóvedas espejo cifradas fuera de la carpeta del proyecto (`%APPDATA%`)** y garantizar la portabilidad a nueva laptop en 1 clic (`.mlvault`) con **recuperación multi-llave "a prueba de olvidos"**, con **cero pérdida de datos, cero fugas de secretos y máxima soberanía tecnológica**.

---

## ÍNDICE GENERAL

1. [GUÍA 1: Arranque y Operación de la Plataforma Admin en Laptop/PC](#guía-1-arranque-y-operación-de-la-plataforma-admin-en-laptoppc)
   - 1.1. Arquitectura de Doble Estado (`Modo Pruebas` vs. `Modo Real`)
   - 1.2. Métodos de Inicio del Servidor Local (`server.dart`)
   - 1.3. Navegación por las 8 Pestañas Oficiales (`http://localhost:8080`)
   - 1.4. Flujo de Alta y Edición Total en Cartera CRM con Buscador Omnicanal
   - 1.5. Generador de Licencias Ed25519 con Tarjeta de Resumen y Ajustes Personalizados
   - 1.6. [Inspector Forense Tri-Protocolo (`#tabInspector`: Tokens `ML9-...`, Fichas `.mlsync` / `MLS1-...` y Fichas Comerciales `MLC1-...`)](#16-inspector-forense-tri-protocolo-tabinspector-tokens-ml9--fichas-mlsync--mls1--y-fichas-comerciales-mlc1-)
   - 1.7. Pestaña Finanzas & Respaldos: Libro Contable y Centro de Respaldos en Disco (`backups/`)
   - 1.8. Venta de Bolsas Extra de Escaneos IA (+150 escaneos)
   - 1.9. Reasignación Técnica de Dispositivo por Cambio o Pérdida de Celular
   - 1.10. Ficha 360° del Cliente y Re-descarga de Credenciales PNG
   - 1.11. Centro de Personalización y Exportación a Libros Excel Multi-Hoja (`#tabSettings`)
   - 1.12. Bóveda de Seguridad, Persistencia y Multi-Llave (`#tabSecurityVault`)
2. [GUÍA 2: Compilación y Firma Oficial Release de la App Móvil](#guía-2-compilación-y-firma-oficial-release-de-la-app-móvil)
   - 2.1. Creación del Keystore de Producción (`keytool`)
   - 2.2. Configuración Segura de `android/key.properties` y Anti-Fugas en `.gitignore`
   - 2.3. Compilador Dual Oficial Único y Guiado (`compilar_release_dual.bat` — Recomendado)
   - 2.4. Scripts Individuales de Compatibilidad (`compilar_apk_comercial.bat` y `compilar_apk_arm64.bat`)
   - 2.5. Compilación del App Bundle para Google Play Store (`flutter build appbundle`)
   - 2.6. Auditoría Forense Manual y Verificación de Firma (`aapt2` + `apksigner`)
3. [GUÍA 3: Publicación y Notificación de Actualizaciones (Release Manager — Planes 19, 22, 22.5 y 23)](#guía-3-publicación-y-notificación-de-actualizaciones-release-manager--planes-19-22-225-y-23)
   - 3.1. Diferenciación Estricta: `HOTFIX` vs. `FEATURE_RELEASE`
   - 3.2. Alta Determinista (`#modalCreateRelease`), Escudo de Firma 3 Estados y Autodetección con Rutas Configurables
   - 3.3. Catálogo, Campos Expandibles y Gestión Segura de Variantes ABI en `#modalEditRelease`
   - 3.4. Matriz Inteligente SemVer, Corrección Segura y Reenvío en 1 Clic
   - 3.5. Despacho Asistido de APK por WhatsApp (`#modalWaComposer`) y Portapapeles Windows Endurecido
   - 3.6. Protocolo Dual de Sincronización Offline (`.mlsync` / `MLS1-...`) y Rescate 1-Clic
   - 3.7. Comportamiento en la App Móvil: Snapshot `.bak`, Sincronización `MLC1` y Novedades v9.41.0+85
4. [GUÍA 4: Protocolo de Respuesta ante Incidentes y Seguridad Adversarial](#guía-4-protocolo-de-respuesta-ante-incidentes-y-seguridad-adversarial)
   - 4.1. Incidente: Pantalla de "Reloj Desajustado / Manipulación Temporal"
   - 4.2. Incidente: Pantalla de "Licencia Pendiente de Migración" (Doble Candado Anti-Clonación)
   - 4.3. Incidente: Agotamiento de la Bolsa de Escaneos con IA
   - 4.4. Custodia y Respaldo Frío de la Clave Privada Maestra (`ed25519_master.key`)
   - 4.5. Tabla de Políticas y Tarifario Oficial de Soporte Perú
5. [CAPÍTULO 8: Manual de Persistencia Blindada, Portabilidad Multi-PC (`.mlvault`) y Recuperación Multi-Llave ("A Prueba de Olvidos")](#capítulo-8-manual-de-persistencia-blindada-portabilidad-multi-pc-mlvault-y-recuperación-multi-llave-a-prueba-de-olvidos)
   - 8.1. Dónde Viven Realmente tus Datos y Cero Pérdida por Limpieza de Navegador
   - 8.2. Checklist Inicial de Blindaje en 3 Pasos (Asistente Guiado de 60 segundos)
   - 8.3. Guía Paso a Paso en 5 Segundos para Mudar a Laptop Nueva o Formateada (`.mlvault`)
   - 8.4. Protocolo de Emergencia ante Incidentes de Acceso o Pérdida
   - 8.5. Soberanía Criptográfica y Garantía de Continuidad de Negocio a 10 Años

---

## GUÍA 1: ARRANQUE Y OPERACIÓN DE LA PLATAFORMA ADMIN EN LAPTOP/PC

### 1.1. Arquitectura de Doble Estado (`Modo Pruebas / Sandbox` vs. `Modo Real / Producción`)
La plataforma cuenta con **segregación física estricta en disco duro**:
* **🧪 Modo Pruebas (`sandbox`):**
  - Bases de datos: `data/sandbox_clients_db.json` y `data/sandbox_releases_db.json`.
  - Carpeta de binarios: `releases_apks/sandbox/`.
  - Propósito: Pruebas comerciales, demostraciones y validación de tokens sin alterar la cartera real. Incluye botón **`[↺ Restaurar Pruebas]`** para restablecer datos demo en cualquier momento.
* **🏢 Modo Real (`prod`):**
  - Bases de datos: `data/prod_clients_db.json` y `data/prod_releases_db.json`.
  - Carpeta de binarios: `releases_apks/prod/`.
  - **Pizarra Limpia Certificada:** Arranca con exactamente `0` clientes (`[]`), `0` versiones y `S/ 0.00` de ingresos acumulados para que tu contabilidad oficial permanezca 100% pura y fidedigna desde el primer comerciante real.

El cambio entre ambos estados se realiza al instante desde el interruptor luminoso en la cabecera sin requerir reiniciar el servidor.

---

### 1.2. Métodos de Inicio del Servidor Local

Dispones de dos métodos para encender el servidor administrativo en tu laptop o PC con Windows:

#### Método 1 (Recomendado — Experiencia de Escritorio Nativa en 1 Clic): `Iniciar_MochilaLista_Admin.bat`
Para iniciar la plataforma con un solo clic o desde un acceso directo en tu Escritorio:
1. **Acceso Directo Oficial en el Escritorio (Automatizado y Compatible con OneDrive):**
   - Ejecuta desde PowerShell el script generador oficial:
     ```powershell
     powershell -ExecutionPolicy Bypass -File .\Crear_Acceso_Directo_Escritorio.ps1
     ```
   - Este script resuelve de manera dinámica la ruta real del Escritorio mediante `[Environment]::GetFolderPath('Desktop')` (garantizando compatibilidad total ante carpetas redirigidas por Microsoft OneDrive o rutas locales estándar).
   - Crea en tu Escritorio el acceso directo **`MochilaLista Admin.lnk`** enlazado al lanzador `Iniciar_MochilaLista_Admin.bat`, configurado para ejecutarse minimizado (`WindowStyle = 7`) y portando el ícono corporativo oficial multi-resolución de alta definición (`mochilalista_admin\web\app_icon.ico` / `favicon.ico`).
2. **Doble Clic:** Al ejecutar el acceso directo o el archivo `.bat`, el lanzador inteligente realiza automáticamente:
   - Posicionamiento absoluto seguro en `mochilalista_admin/` (`%~dp0mochilalista_admin`).
   - Validación de la disponibilidad de Dart SDK en el sistema con mensaje claro de ayuda si falta en el PATH.
   - Verificación precisa de socket en puerto 8080 (`netstat -ano | findstr ":8080 " | findstr "LISTENING"`) y sondeo HTTP real sobre `http://localhost:8080/api/vault/health` devolviendo `200 OK`. Si ya estaba corriendo y saludable, reutiliza el servidor de inmediato sin lanzar procesos redundantes.
   - Si no estaba encendido, levanta `server.dart` en una ventana minimizada dedicada con título `MochilaLista Admin Server` y envoltorio interactivo anti-cierre silencioso (`cmd /c "cd /d "%ADMIN_DIR%" && dart run server.dart || pause"`), permitiendo diagnosticar cualquier error en pantalla.
   - **Prioridad 1 — Google Chrome en Modo Ventana Nativa de Escritorio (`--app`):** Mediante bucle de espera con sondeo HTTP (hasta 15 intentos de 1s), aguarda la respuesta `200 OK` del backend y lanza **Google Chrome** en modo aplicación limpia:
     ```cmd
     start chrome.exe --app=http://localhost:8080
     ```
     *(con fallback a `msedge.exe --app=...` o navegador predeterminado solo si Chrome no está instalado)*, desplegando la plataforma en una ventana independiente, sin barra de direcciones ni pestañas genéricas, operando con la fluidez de un software de escritorio nativo.
   - **Botón `Abrir en Chrome` en la Cabecera Web:** En la barra superior de la interfaz dispones de un botón discreto con ícono de Google Chrome que invoca el endpoint `POST /api/system/open-browser`, abriendo la plataforma en una pestaña normal de Chrome si requieres acceder a DevTools, extensiones o navegación multipestaña.

#### Método 2: Inicio Manual por Terminal (PowerShell / CMD)
```powershell
cd C:\Users\vjuli\Documents\mochilalista-app\mochilalista_admin
dart run server.dart
```

Salida esperada en consola:
```
================================================================
🚀 MOCHILALISTA ADMIN — Servidor Local de Licencias y Versiones
👤 Autor y Titular: Julio Angello Vasquez Navarro
🌐 Acceso Local: http://localhost:8080
📁 Entorno Activo: SANDBOX (o PROD)
📁 Base de Datos: C:\Users\vjuli\Documents\mochilalista-app\mochilalista_admin\data
================================================================
```

#### Método 3: Apagado Seguro y Limpio del Servidor desde el Sidebar Footer
En la esquina inferior izquierda del Sidebar (Sidebar Footer), junto al indicador de entorno y perfil, se ubica el botón **`[⏻ Apagar Servidor]`** (`#btnShutdownServer`):
1. Al pulsarlo, el sistema despliega un diálogo de confirmación `showConfirmModal` alertando que la plataforma cerrará el proceso `server.dart` y liberará el socket del puerto 8080.
2. Si la bóveda está protegida por PIN local y la sesión no está autenticada, el endpoint `POST /api/system/shutdown` responde `HTTP 423 Locked`, impidiendo el apagado no autorizado.
3. Al confirmar con sesión válida, el servidor responde confirmación `HTTP 200 OK`, la interfaz muestra una pantalla limpia de desconexión informando que el servicio fue detenido y el backend ejecuta un apagado limpio (`exit(0)`) tras 250ms de gracia para asegurar la entrega de la respuesta HTTP.

---

### 1.3. Navegación por las 8 Pestañas Oficiales (`http://localhost:8080`)
Abre tu navegador web en `http://localhost:8080`. Dispones de **8 módulos de control ejecutivo en el Sidebar**:

1. **📊 Dashboard Financiero (`#tabDashboard`):** KPIs en tiempo real con micro-gráficos SVG interactivos (ingresos del mes, acumulado, clientes activos, por vencer, vencidos, perpetuos y desactualizados) más la tabla de **Acciones Urgentes (≤ 7 días)** con aviso directo a WhatsApp y accesos rápidos de emisión.
2. **👥 Cartera de Clientes CRM (`#tabClients`):** Directorio unificado con **buscador omnicanal reactivo**, filtros por estado, Drawer Lateral "Ficha 360°" con 5 pestañas de detalle profundo, insignias `DeviceID` con micro-botón `[📋]`, enlace directo a WhatsApp, botón de migración inmediata en 1 paso, edición total y eliminación protegida.
3. **🔑 Generador de Licencias Ed25519 (`#tabGenerator`):** Firma criptográfica asimétrica con **Tarjeta de Resumen Ejecutivo en tiempo real**, **Panel de Ajustes Comerciales Personalizados** (días libres, bonos IA, regla acumulativa vs. reinicio y fecha exacta), **Credencial PNG @2x de alta resolución**, descarga/copiado de QR y botón **`[Auditar en Inspector]`**.
4. **🚀 Gestor de Versiones / Release Manager (`#tabReleaseManager`):** Matriz inteligente de distribución de versiones, soporte para APK universal y ligero ARM64, **Mini-Guía Rápida de Compilación Dual** (`#btnToggleDualBuildGuide` con **4 comandos copiables**, incluyendo `--init-notes`, y flujo en 4 pasos), zona Drag & Drop a `releases_apks/`, botones de descarga directa, apertura de carpeta en Windows (`explorer.exe /select,...`) y botón **`[Autorizar Envío de Cortesía]`**.
5. **🔍 Inspector Forense Tri-Protocolo (`#tabInspector`):** Auditoría criptográfica unificada para los **3 protocolos oficiales** (**`ML9-...`** licencias, **`MLS1-...` / `.mlsync`** telemetría móvil y **`MLC1-...`** tarifas/cuentas comerciales), con **Guía Desplegable de Protocolos**, **Lector Óptico QR** (`jsQR` offline con reescalado para QRs densos de `512 px`), comparador de diferencias `diff_vs_current`, verificación de los **4 estados de nonce**, botón **`Copiar Informe Forense`** e historial colapsable de sesión.
6. **Finanzas & Respaldos (`#tabFinancesAndBackups`):**
   - **Submódulo 1:** Libro contable consolidado en hora `America/Lima (GMT-5)` con filtros en vivo (buscador omnicanal sin recortes, rango de fechas Lima, plan, medio de pago), KPIs dinámicos, exportación `.csv` con BOM UTF-8 / escape RFC-4180 y libro Excel Contable `.xlsx` de 5 hojas.
   - **Submódulo 2:** Centro de gestión de respaldos físicos en `backups/` en hora `America/Lima`, paginación `20` en `20`, filtros por entorno, modal de vista previa `#modalBackupPreview` (incluyendo restauración en caliente de `GLOBAL` `owner_config`) y limpieza segura de snapshots `SANDBOX`.
7. **Configuración (`#tabSettings`):**
   - Editor en caliente de identidad corporativa (`data/owner_config.json`) en 4 sub-pestañas (*Tarifario & Bolsas IA*, *Plantillas WhatsApp unificadas con `#modalWaComposer`*, *Medios de Pago & Legal `2x2`*, *Preferencias del Sistema* aplicadas al arranque), *Dirty Guard* anti-pérdida, guardado/reseteo por alcance y **Sincronización Criptográfica `MLC1-...`** hacia la app móvil.
8. **Seguridad y Portabilidad (`#tabSecurityVault`):**
   - Centro neurálgico de persistencia fuera del repositorio: Bóveda Espejo Cifrada con Windows DPAPI en `%APPDATA%\MochilaListaAdminVault\`, auditoría integral `GET /api/vault/audit` (`#modalVaultAuditReport`) con paridad SHA-256 sobre 5 archivos críticos y selector nativo de carpeta nube.
   - Asistente Guiado en 3 Pasos sincronizado con los **4 Factores de Seguridad (`25 % c/u`)**, confirmación protectora para `.mlkey` y Kit PDF de 8 Códigos + QR, portabilidad `.mlvault` y bloqueo PIN local con cookie `HttpOnly` sin auto-bloqueo `423`.

---

### 1.4. Flujo de Alta y Edición Total en Cartera CRM con Buscador Omnicanal

#### A. Registrar Nuevo Cliente (`#modalCreateClient`) — Modelo 100% Coherente Offline-First:
1. En **Cartera de Clientes**, haz clic en **`[➕ Registrar Nuevo Cliente]`**.
2. Rellena los datos comerciales adaptados a los **3 estados iniciales de negocio**:
   * **Nombre Comercial / Librería:** (ej. `Librería & Bazar San Martín`)
   * **Nombre del Propietario:** (ej. `Carlos Mendoza Quispe`)
   * **RUC o DNI:** (ej. `10458796321`)
   * **Teléfono WhatsApp:** (ej. `987654321` — El sistema normaliza automáticamente a formato internacional `+51987654321`).
   * **Hardware ID del Teléfono (ANDROID_ID):**
     - **Para Prospectos:** Puede dejarse completamente vacío; el sistema asigna automáticamente `PENDIENTE` sin bloquear el guardado ni provocar colisiones con otros registros.
     - **Para Trial o Clientes Activos:** Ingresa el identificador de 7 caracteres (ej. `ML-9K4B`).
   * **Plan Inicial (3 Estados Offline-First):**
     - **`PROSPECTO`:** Contacto comercial en prospección sin licencia generada ni expiración ficticia (`license_expires = null`).
     - **`TRIAL GRATUITO (Días Reales)`:** Permite ingresar los días exactos que le restan al comerciante en su teléfono (`trial_days_remaining`, ej. `17 días`). No impone ventana artificial de actualización (`updates_until = null`), respetando la naturaleza Offline-First de la app móvil.
     - **`CON LICENCIA ACTIVA`:** Planes comerciales tarifados (`MENSUAL`, `TRIMESTRAL`, `SEMESTRAL`, `ANUAL`, `PERPETUO`).
   * **Versión de App Instalada:** (por defecto: `9.41.0` — Esquema SQLite `v36`).
   * **Gestión de Créditos IA:**
     - **Saldo IA Reportado en Celular:** Créditos que el cliente indica tener disponibles en su app móvil (ej. `49 IA`).
     - **Bonos IA Pendientes por Emitir:** Escaneos adicionales que se incorporarán en la próxima emisión de token criptográfico Ed25519 (ej. `+20 IA`). Ambos valores se muestran desacoplados de forma transparente, previniendo falsas sumas anticipadas en el CRM.
3. Presiona **"Guardar Cliente"** o **"Guardar y Emitir Licencia"**.

#### B. Compositor Universal de WhatsApp (`#modalWaComposer` — Plan Maestro 22):
Accesible en 1 clic desde Cartera CRM, Ficha 360°, Comprobantes y Matriz de Versiones (con UI libre de emojis crudos y footer responsivo):
- **Toggle Real en 6 Plantillas Rápidas de 1 Clic:** `Saludo y Bienvenida`, `Renovación Preventiva`, `Seguimiento Prospecto`, `Entrega de Licencia`, `Nueva Versión APK` y `Chat Vacío`. El 1.er clic aplica la plantilla conservando chips activos y resguardando el borrador previo; el **2.º clic sobre la misma píldora activa la desactiva** y restaura tu texto previo limpio sin duplicaciones. Si seleccionas `Nueva Versión APK` desde CRM, se despliega allí mismo el panel de versión APK.
- **Chips `Insertar:` Multi-Select Idempotentes:** `+ Datos Yape / Plin`, `+ Hardware ID`, `+ Vencimiento` y `+ Último Token` se combinan de forma acumulativa (1.er clic inserta y marca `.active`; 2.º clic remueve exactamente su bloque y colapsa saltos sobrantes).
- **Guardado/Copia/Despacho:** **`[Guardar Plantilla]`**, **`[Restaurar por defecto]`**, **`[Copiar Solo Texto]`**, **`[Copiar Mensaje]`**, **`[Abrir Chat Vacío]`** y **`[Abrir en WhatsApp]`**.

#### C. Buscador Omnicanal Reactivo:
En la parte superior de la tabla, escribe en la caja de búsqueda cualquier fragmento de negocio, dueño, DNI, teléfono, Hardware ID o versión. La tabla filtrará en tiempo real sin recargar la página.

#### D. Acciones Clave en 1 Sola Fila Horizontal:
Cada fila de la tabla CRM presenta sus 4 herramientas alineadas de manera compacta:
1. **`[👁️]` Ficha 360°:** Despliega el Drawer lateral completo con sus 5 pestañas.
2. **`[🪟]` QR y Credencial:** Abre directamente la pestaña QR de la Ficha 360°.
3. **`[💬]` WhatsApp:** Despliega el Compositor Universal con plantilla contextual.
4. **`[⚡]` Emitir Licencia:** Transfiere al comerciante a la pestaña Generador para firma inmediata.

#### E. Edición Total con Zona de Peligro (`#modalEditClient`):
Toca el botón de edición para modificar libremente los datos del cliente, o accede al botón **`[🗑️ Eliminar Cliente Definitivamente]`** protegido por confirmación estricta de dos pasos.

---

### 1.5. Generador de Licencias Ed25519 con Resumen Ejecutivo y Ajustes Personalizados

1. En la pestaña **Generador de Licencias**, selecciona al comerciante en el menú desplegable.
2. **Columna Derecha Reactiva (Sin Estado Pegado):** Muestra de inmediato la Licencia Activa vigente destacada y el Historial completo de emisiones previas del cliente. Al cambiar de cliente, la credencial previa se limpia automáticamente.
3. Elige el **Plan Oficial** tarifado o selecciona la modalidad:
   - **`Bono / Recarga IA Personalizada (0 días)`:** Emite recargas de escaneos IA sin alterar la fecha de caducidad (`y=0`, claim `c=X`). Cuenta con conmutador para:
     * *Cortesía / Gratuito (S/ 0.00):* Desacopla el cobro y no genera asientos contables ficticios.
     * *Cobrado:* Sugiere el tarifario comercial oficial e integra el medio de pago.
4. **Proyección Reactiva en Vivo (`Antes → Después`):** Previsualiza en tiempo real cómo impactará la licencia en los días remanentes, fecha proyectada y saldo IA, actualizándose instantáneamente al alternar opciones del acordeón de **Ajustes Comerciales Personalizados** (días libres, créditos de regalo, regla acumulativa vs reinicio, o sobreescritura de fecha).
5. Presiona **`[⚡ Firmar Criptográficamente y Emitir Licencia]`**.
6. **Panel de Entrega Multiformato:**
   - **Código `ML9-...`:** Con botón para copiar al portapapeles.
   - **Credencial Oficial PNG en Alta Definición (@2x / 900x520 px):** Renderizada con degradado ejecutivo, sellos legales INDECOPI / D.L. 822 y código QR incrustado. Puedes presionar **`[Descargar PNG]`** o **`[Copiar Credencial]`** (para pegarla directo en WhatsApp Web con `Ctrl + V`).
   - **Botón `[📲 Enviar por WhatsApp]`:** Dispara el mensaje preformateado.
   - **Botón `[🔍 Auditar en el Inspector]`:** Pasa el código al Inspector Forense y lo audita en 1 solo clic.

---

### 1.6. Inspector Forense Tri-Protocolo (`#tabInspector`: Tokens `ML9-...`, Fichas `.mlsync` / `MLS1-...` y Fichas Comerciales `MLC1-...`)

En la pestaña **Inspector Forense (`#tabInspector`)** cuentas con una consola única de verificación criptográfica y diagnóstica para los **3 protocolos oficiales de MochilaLista**:

| Protocolo | Dirección del Flujo | Propósito | Firma Criptográfica | Dónde se Genera | Dónde se Usa | Qué Valida el Inspector (`#tabInspector`) |
|---|---|---|---|---|---|---|
| **`ML9-...`** | Admin ➔ App Móvil | Activar suscripción, licencia perpetua, recarga IA o migración de hardware. | **Ed25519 asimétrica** con llave privada maestra (`ed25519_master.key`). | `#tabLicenseStudio` en MochilaLista Admin. | Pantalla *Licencia y Activación* o *Bloqueo* de la app móvil. | Firma Ed25519, cliente dueño por `d`/`hw`, los claims (`d, p, y, n, v, iat, u, b, c`), fechas en hora Perú y estado real del `nonce`. |
| **`MLS1-...` / `.mlsync`** | App Móvil ➔ Admin | Reportar estado real del teléfono (licencia vigente, días, IA usada, versión APK y salud SQLite). | **HMAC-SHA256 determinista** (prefijo `MLS1-` o JSON `.mlsync`). | Dentro de la app móvil (*Sincronizar con Soporte / Exportar Ficha*). | `#tabInspector` o ficha del cliente para conciliar CRM sin internet. | Integridad HMAC, 21 métricas humanizadas (`Sí`/`No`, `Óptimo`/`Atención`/`Crítico`), comparador *Antes (Admin) ➔ Real (Celular)* y rescate `PENDIENTE_MIGRACION`. |
| **`MLC1-...`** | Admin ➔ App Móvil (auditable de vuelta) | Actualizar precios de los 8 planes/bolsas IA y 5 canales de pago/soporte sin Internet. | **Ed25519 asimétrica con separación de dominio** (`utf8('MLC1-' + payloadB64)`). | `#tabSettings` ➔ *Emitir Ficha Comercial `MLC1-...`*. | App móvil (texto, WhatsApp o QR PNG de `512 px`) y `#tabInspector`. | Firma Ed25519 `MLC1-`, revisión (`CURRENT` / `SUPERSEDED` / `AHEAD_OR_EXTERNAL`), tabla `diff_vs_current` vs config vigente y diagnóstico forense ante manipulación. |

#### Operación Paso a Paso del Inspector Forense (`#tabInspector`):
1. **Guía Visual de Protocolos (`Guía de Protocolos (ML9 / MLS1 / MLC1)`):** Pulsa `#btnToggleInspectorGuide` en la cabecera para desplegar `#inspectorProtocolGuide` con el resumen comparativo, origen, destino y significado de cada código sin salir de la pantalla.
2. **Entrada Multi-Formato y Lector Óptico QR (`jsQR`):**
   - Pega un token puro o un mensaje completo de WhatsApp (el backend extrae automáticamente `ML9-...`, `MLS1-...` o `MLC1-...`, tolerando encabezados, emojis y saltos `\r\n`), carga un `.mlsync` / `.json`, o arrastra una captura **QR PNG** al **Lector Óptico QR**.
   - Para fichas densas `MLC1-...`, el emisor exporta el QR a **`512 px`** con zona de quietud blanca (`32 px`) y el lector aplica **`tryDecodeQrCanvasWithUpscale()`** (reescalado entero `2x`/`3x` sin suavizado ni antialiasing + margen blanco e intento normal/invertido con `jsQR`) garantizando lectura offline confiable.
3. **Auditoría `ML9-...` y Matriz Exacta de 4 Estados de Nonce (`ultimo_nonce` + `next_nonce`):**
   - Muestra todos los claims (`d, p, y, n, v, iat, u, b, c`) con timestamps en **`America/Lima (GMT-5)`**:
     - **`Canjeado en celular (Verificado por .mlsync #N)`** (Verde): Cuando el celular reportó `ultimo_nonce >= tNonce`.
     - **`Emitido — Pendiente de canje en celular (Sin .mlsync reciente)`** (Azul): Último token emitido (`tNonce == next_nonce - 1`) aún sin reporte `.mlsync` posterior.
     - **`Nonce futuro listo para canje`** (Ámbar): Únicamente cuando `tNonce >= next_nonce`.
     - **`Superado / Histórico`** (Púrpura): Tokens anteriores ya rebasados sin confirmación `.mlsync` vigente.
4. **Auditoría `.mlsync` / `MLS1-...`:** Exhibe las 21 métricas humanizadas en hora Perú y la tabla **"Antes (Admin) ➔ Real (Celular)"** (con banner verde `Sin cambios por aplicar` cuando coincide al 100%).
5. **Auditoría Especializada de Fichas Comerciales `MLC1-...` (`#inspectMlc1AuditCard`):**
   - **Estado de Revisión (`revision_status`):** Clasifica la ficha respecto a tu configuración actual en `#tabSettings` como **`CURRENT`** (*Vigente al día*), **`SUPERSEDED`** (*Obsoleta — ya existe una revisión más reciente*) o **`AHEAD_OR_EXTERNAL`** (*Adelantada o emitida desde otro equipo / entorno*).
   - **Comparador de Diferencias (`diff_vs_current`):** Compara valor por valor los **8 productos** (tarifario y bolsas IA) y los **5 canales** (`WhatsApp soporte`, `Yape`, `Plin`, `BCP`, `BBVA`), ofreciendo acceso directo con **`Abrir Configuración (#tabSettings)`**.
   - **Escudo Ante Firma Inválida o Manipulación (`security_alert`):** Si alguien altera aunque sea un carácter o firma con otra clave privada, bloquea la validación (`valid: false`, `payload: null`) y muestra una alerta forense crítica junto a `diagnostic_payload` (inspección de solo lectura del contenido alterado sin aceptarlo como legítimo).
6. **Copiar Informe Forense e Historial de Sesión (`#inspectorSessionHistoryPanel`):**
   - Pulsa **`Copiar Informe Forense`** para obtener un reporte de soporte limpio con fecha `America/Lima (GMT-5)`, validez, contexto (`Cliente CRM` para `ML9`/`MLS1` o `Contexto Admin` para `MLC1`), recomendación y detalle técnico.
   - El panel inferior colapsable guarda las **últimas 10 auditorías de la sesión** con insignia diferenciada (`ML9`, `MLS1`, `MLC1`) para recargarlas en 1 clic.

---

### 1.7. Pestaña Finanzas & Respaldos (`#tabFinancesAndBackups`): Libro Contable y Respaldos en Disco

#### Submódulo 1: Libro Contable de Cobranzas (Hora `America/Lima` GMT-5)
- Consolida todos los pagos registrados en el entorno activo con fechas y horas normalizadas a **`America/Lima (GMT-5)`**.
- **Filtros en Vivo y Buscador Omnicanal (`#inputFinSearch`):** Buscador predictivo en fila dedicada con botón de limpieza SVG (para filtrar sin recortes por `BOL-XXXX`, `FAC-XXXX`, negocio, titular, RUC/DNI, referencia, plan o notas contables), rango de fechas (`Desde` / `Hasta` inclusivo en día local Lima GMT-5), selector de Plan y Medio de Pago (`Yape`, `Plin`, `BCP`, `BBVA`, `Efectivo`).
- **KPIs Dinámicos:** Total Recaudado (S/), Ticket Promedio (S/), N.° de Transacciones y Canal de Pago Principal.
- **Exportación Contable Exacta:** Botón **`Exportar CSV`** (`GET /api/clients/export-finances-csv`) con BOM UTF-8 (`\uFEFF`), escape RFC-4180 completo en todas las columnas y horas en `America/Lima (GMT-5)`; y botón **`Exportar Excel Contable (.xlsx)`** de 5 hojas con desglose completo incluyendo `RECARGA_IA_150`, `EXTENSION_CORTESIA`, `ABONO_PARCIAL`, `SERVICIO_MIGRACION`, métricas reales de `days_added`/`ai_extra_credits` y sub-resumen por medio de pago.

#### Submódulo 2: Centro de Gestión de Respaldos en Disco (`backups/`)
- Muestra la lista física de copias de seguridad generadas en `mochilalista_admin/backups/` con marcas temporales en **`America/Lima (GMT-5)`**, paginación dinámica de **`20` en `20`** (`Cargar 20 respaldos más (Mostrando X de Y)`), buscador rápido y píldoras de filtro (**`Todos`**, **`PROD`**, **`SANDBOX`**, **`GLOBAL`**, **`Manuales`**) con aviso discreto si visualizas respaldos `SANDBOX` operando en **`Modo Real`**.
- **Política de Retención Automática (Últimos 30 Snapshots):** El motor (`DatabaseService` y `ConfigService`) mantiene estrictamente los **30 snapshots automáticos más recientes** (`maxAutoSnapshots = 30`), purgando excedentes antiguos tras cada escritura.
- **Preservación Indefinida de Backups Protegidos:** Cualquier archivo de respaldo que contenga `manual`, `vault`, `pre_restore`, `before_restore`, `pre_import`, `pre_save` o `pre_reset` está blindado y **jamás se elimina automáticamente**.
- **`Crear Snapshot Manual Ahora`:** Guarda una copia atómica instantánea con timestamp en hora Perú.
- **`Abrir Carpeta backups/ en Windows`:** Abre la carpeta en el Explorador de Windows con 1 clic.
- **`Descargar`** y **`Restaurar` con Vista Previa (`#modalBackupPreview`):** Todos los controles usan iconos `<svg>` acotados (cero emojis crudos). Al pulsar `Restaurar`, `GET /api/backups/preview/:filename` muestra la comparativa **Snapshot vs Estado Actual** (clientes, pagos, releases o secciones de configuración), valida estrictamente el nombre contra *path traversal*, crea un respaldo previo `pre_restore_` y, si es un backup **`GLOBAL` (`owner_config_backup_*.json`)**, recarga `ConfigService` e interfaz en caliente (`restored_scope: 'config'`).
- **Limpieza Segura Sandbox (`POST /api/backups/purge-sandbox`):** Permite depurar snapshots automáticos `sandbox_*` conservando intactos al 100 % los respaldos `prod_*`, `owner_config_*`, `manual`, `vault`, `pre_restore`, `before_restore`, `pre_import`, `pre_save` y `pre_reset`.

---

### 1.8. Venta de Bolsas Extra de Escaneos IA (+150 escaneos)
Si un comerciante desea recargar su saldo de escaneos IA o agota su bolsa inicial y no desea configurar su clave BYOK:
1. El cliente te abona **S/ 20.00**.
2. En el Generador, selecciona al cliente y el plan **`BOLSA EXTRA IA (+150 escaneos) — S/ 20.00`**.
3. Presiona emitir y envíale el código o credencial.
4. Al canjearlo, su fecha de caducidad se mantiene intacta y se le suman **+150 escaneos acumulativos sin vencimiento** a su bolsa global.

---

### 1.9. Reasignación Técnica de Dispositivo y Migración Segura (`#modalMigrateDevice`)
Cuando un comerciante cambia de celular, se le extravía o restaura una copia de seguridad en un nuevo terminal:
1. Solicita al comerciante el nuevo Hardware ID (`ANDROID_ID`) que muestra su nuevo teléfono (`Perfil > Licencia`).
2. En Cartera de Clientes, presiona el botón **`[🔄]`** (Migrar Teléfono) o accede desde la pestaña *Hardware* de la Ficha 360°.
3. **Selector de Escenario Técnico:**
   - **`Restauración de Copia de Seguridad (.mlbg / Google Drive):`**
     El cliente ya restauró sus datos en el nuevo celular. La app móvil se encuentra en estado `PENDIENTE_MIGRACION` y ya contiene la fecha de vencimiento legítima en SQLite. El sistema genera un token de reactivación con `y = 0`, evitando que el cliente duplique días de suscripción al reactivarse.
   - **`Instalación Limpia (Sin Backup):`**
     El cliente instaló la app desde cero. El sistema transfiere exactamente los días remanentes calculados (`y = Días restantes`) para que la nueva app herede el período suscrito.
4. **Tarjeta Resumen de Preservación:** Previsualiza en tiempo real el Hardware ID anterior que se archivará, el nuevo Hardware ID que se vinculará, los días a transferir, el saldo IA preservado y el incremento automático de `nonce`.
5. **Modalidades de Tarifa Técnica:**
   - *Estándar (S/ 40.00):* Precio oficial de reasignación con registro automático en finanzas.
   - *Traslado Gratuito / Cortesía (S/ 0.00):* Para garantías comerciales o cambios de equipo sin costo. No genera cobros ficticios en el libro contable.
   - *Personalizada:* Permite ajustar un monto especial acordado.
6. **Emisión en 1 Solo Paso:** Casilla para firmar criptográficamente el token Ed25519 de inmediato e insertarlo en el historial de licencias del cliente con claim `m: 1` para certificar la migración legítima.

---

### 1.10. Ficha 360° del Cliente y Gestión Integral (5 Pestañas Especializadas)
En **Cartera de Clientes**, presiona el botón **`[👁️]`** (Ficha 360°) o **`[🪟]`** (QR Directo) para abrir el Drawer lateral deslizable con gestor inteligente de capas (`z-index: 3000` con auto-retorno exacto a la pestaña activa):

1. **Pestaña 1 — Resumen Ejecutivo:**
   - Métricas clave en tiempo real: Plan Actual con badge `Trial (Xd)` en ámbar si aplica, Vencimiento, Créditos IA Desglosados (`En celular: X IA | Consumidos: Z IA (+delta reciente) | Bono pend: +Y IA`), **Última Sincronización Real en hora `America/Lima` (GMT-5)**, **Respaldo Drive** humanizado (`Vinculado (Óptimo / Requiere atención / Crítico)`), **`Perfiles Activos`** (`pc`) y **`Último Nonce Reportado`** (`ultimo_nonce`).
   - **Botón `[Sincronizar Celular]` (`#modalSyncReported`):** Abre el comparador `.mlsync` / `MLS1` o el ajuste manual de emergencia.

2. **Pestaña 2 — QR & Credencial Oficial:**
   - Visualización garantizada del código QR en alta definición mediante `renderSafeQrCode()`.
   - **Metadatos Sincronizados en Tiempo Real:** Refleja con exactitud `Plan`, `Emisión`, `Vigencia`, `Nonce`, `Créditos IA` y `Dispositivo` de la licencia seleccionada en el histórico.
   - **Acciones Rápidas:**
     * **`[Copiar Código]`:** Copia la cadena `ML9-...`.
     * **`[Descargar Tarjeta (@2x)]`:** Descarga la credencial gráfica PNG en 900x520 px.
     * **`[Copiar Imagen Credencial]`:** Copia el mapa de bits al portapapeles (`Ctrl+V`) para pegado instantáneo en WhatsApp Web.
     * **`[Descargar Solo QR]`:** Descarga el archivo de imagen PNG del código óptico con **margen blanco reglamentario de 32px** (*quiet zone* blanca pura al 100%), garantizando lectura inmediata y sin fallos desde la galería fotográfica de cualquier celular.
     * **`[Auditar en Inspector]`** y **`[WhatsApp]`** contextual.

3. **Pestaña 3 — Pagos y Finanzas (CRUD Dinámico y Boletas):**
   - Tarjetas compactas adaptativas (eliminando scrolls horizontales y dobles botones `++`).
   - Muestra fecha, concepto, monto en soles (`S/`), medio de pago y referencia.
   - Botón **`[🧾 Boleta]`** en cada registro para abrir el Generador de Boletas de Pago.
   - Botón **`[➕ Registrar Pago Manual]` (`#modalManualPayment`):** Permite registrar cobros con presets de tarifas oficiales extraídos en caliente de `owner_config.json`.

4. **Pestaña 4 — Hardware y Dispositivos:**
   - Visualización del Hardware ID actual con píldora interactiva **`[📋 Copiar ID]`** para portapapeles en 1 clic.
   - Historial de cambios de equipo con fecha, hardware anterior, hardware nuevo, tarifa técnica y motivo registrado.
   - **Edición Rápida de Modelo y Motivo:** Permite actualizar el modelo del celular (ej. `Samsung Galaxy A54 5G`) y el motivo de la migración directamente en el historial técnico (`PUT /api/clients/:id/device-history/:index`).
   - Botón directo **`[🔄 Migrar Teléfono]`** conectado a `#modalMigrateDevice`.

5. **Pestaña 5 — Edición Rápida y Zona de Peligro:**
   - Modificación inmediata de titular, negocio, teléfono, documento de identidad y notas comerciales.
   - Campo *Ventana Updates* condicional (solo visible si el cliente posee un plan Perpetuo).
   - **Zona de Peligro:** Botón **`[🗑️ Eliminar Cliente Definitivamente]`** con diseño de advertencia en rojo y diálogo de confirmación estricto de dos pasos con respaldo preventivo automático.

---

### 1.10.1. Generador y Personalizador de Comprobantes de Pago (Boletas `BOL-XXXX` & Facturas `FAC-XXXX`) 100% Offline con Descarga PDF Directa
Accesible desde los botones de comprobante en la Ficha 360°, la tabla de Finanzas o tras registrar un cobro:
- **Soporte Dual para Boletas y Facturas Oficiales:** Permite alternar instantáneamente entre **Boleta de Pago** (`BOL-XXXX`) y **Factura de Pago** (`FAC-XXXX`), administrando series correlativas independientes, atómicas e irreversibles en disco (`DatabaseService.issueOrGetPaymentReceipt`) con total idempotencia contable.
- **Desglose Opcional de IGV (18% Perú):** Al emitir Facturas de Pago, dispones de un interruptor para calcular automáticamente el Subtotal (Base Imponible), el IGV 18% y el Total facturado con precisión a 2 decimales, o emitir como importe total exonerado/incluido.
- **Renderizado Gráfico Fiel en Alta Definición:** Motor `<canvas>` 2D aislado (`ctx.save()` / `ctx.restore()`) con fondo claro corporativo `#f8fafc`, padding tipográfico de 20px, membrete ejecutivo, detalle del cliente y titular, concepto oficial homologado y sello de seguridad.
- **Generador de PDF 1.4 Binario Offline Directo:** Incluye un motor PDF nativo en JavaScript que empaqueta la imagen del comprobante en un stream `/DCTDecode` bajo especificación PDF 1.4, permitiendo descargar el archivo `.pdf` en 1 clic de forma 100% offline sin librerías externas pesadas ni conexión a internet.
- **Acciones Rápidas de Entrega Multiformato:**
  1. **`[Descargar Boleta/Factura PDF]`:** Genera y descarga el documento `.pdf` con nombre sanitizado para Windows (ej. `Boleta_BOL-0001_Luzam.pdf`).
  2. **`[Descargar PNG (@2x)]`:** Exporta imagen rasterizada en alta densidad (1200x940 píxeles).
  3. **`[Copiar Imagen al Portapapeles]`:** Copia el comprobante al búfer del sistema para pegarlo de inmediato con `Ctrl + V` en WhatsApp Desktop o Web.
  4. **`[Enviar por WhatsApp]`:** Conecta con el Compositor de WhatsApp editable (`#modalWaComposer`), permitiendo revisar y personalizar el mensaje antes de disparar el envío.
  5. **`[Imprimir]`:** Abre el diálogo de impresión del sistema operativo para ticket o impresora láser.

---

### 1.11. Centro de Configuración, Exportación Excel y Sincronización Segura `MLC1` (`#tabSettings`)
1. **Motor de Exportación Excel Contable (`.xlsx` multi-hoja) y Comprobantes:**
   - Buscador omnicanal `#inputFinSearch`, píldoras interactivas `BOL-XXXX` / `FAC-XXXX` / `Emitir` en `#tabFinancesAndBackups` y descarga directa `.xlsx` de 5 hojas oficiales sin `Sheet1`: `Resumen Ejecutivo` (con desglose completo de planes y medios de pago en hora Lima GMT-5), `Cartera CRM` (18 columnas A..R), `Libro de Pagos` (14 columnas A..N), `Equipos y Licencias` y `Guia y Glosario`, todas con fórmulas dinámicas seguras (`SUM`, `AVERAGE`, `COUNT`, `SUMIF`, `COUNTIF`).
2. **Las 4 Sub-Pestañas de `#tabSettings` (Configuración Total del Propietario):**
   - **Tab 1 (`Tarifario & Bolsas IA`):** Claves unificadas `updates_window_months` / `updates_months` (`12` meses predeterminados en `PERPETUO_LIBERADO` y `PASE_ACTUALIZACION_ANUAL`), descripciones comerciales editables en los 10 ítems y sincronización bidireccional viva entre el control superior de migración y `HARDWARE_MIGRATION_FEE` (propagándose al Generador, Pagos Manuales, Drawer 360° y Migración). Preserva invariantes `apk_library_dir` y `apk_search_dirs`.
   - **Tab 2 (`Plantillas WhatsApp & Chat en Vivo`):** Registro unificado bidireccional con `#modalWaComposer` (`license_issued` ↔ `license`, `expiring_reminder` ↔ `expiring`, `trial_welcome` ↔ `welcome`, `apk_update_eligible` ↔ `update`, `prospect`, `ai_bonus`, `courtesy_extension`), borrador multi-plantilla en memoria (`settingsDraftTemplates`) sin pérdida al alternar plantilla, tooltips por variable `{...}`, botón **`Copiar Vista Previa`** y guía de formato Markdown.
   - **Tab 3 (`Medios de Pago & Legal Perú`):** Cuadrícula `2x2` equilibrada con soporte oscuro y claro (`[data-theme="light"]`), propagación reactiva de titular, marca, soporte, Yape/Plin, BCP y BBVA hacia Boletas/Facturas, Credenciales PNG (@2x con iconografía Canvas2D vectorial) y compositor WhatsApp, con activos `?v=23`.
   - **Tab 4 (`Preferencias del Sistema`):** Aplicación real de `system.default_mode` al iniciar `server.dart` (`prod` vs `sandbox`), aplicación inicial de tema (`Deep Obsidian` / `Executive Slate`), densidad compacta `.table-compact` en todas las tablas dinámicas y resumen/atajo directo a **Rutas de búsqueda de APKs**.
3. **Guardián de Cambios Sin Guardar (*Dirty Guard*) y Alcance Explícito:**
   - Detecta diferencias reales por sub-pestaña (`pricing`, `templates`, `payment`, `preferences`) mostrando indicador ámbar e interceptando salidas desde el Sidebar o conmutador Sandbox/Prod con `#modalUnsavedSettings` (`Guardar cambios y salir`, `Descartar cambios y salir`, `Seguir editando`).
   - Botones explícitos **`Guardar esta pestaña`** vs **`Guardar todo`** y restablecimiento controlado vía `#modalResetSettingsScope` (**`Solo pestaña actual`** vs **`TODA la configuración`** -> `POST /api/config/reset` con `scope` y snapshot `pre_reset`).
4. **Sincronización Segura `MLC1-...` hacia la App Móvil (`#modalCommercialConfigSync` — Plan Maestro 24):**
   - **Barra horizontal lado a lado:** Alterna cómodamente entre **`Vía 1: Ficha Firmada MLC1 (Offline)`** y **`Vía 2: Archivo Dart Completo (Futuros APKs)`** sin perder visibilidad ni scroll.
   - **Vía 1 (`MLC1-...` Declarativa Offline + QR ISO V1–V40):**
     - `POST /api/config/generate-sync-token` firma un JSON canónico tipado (`v == 1`, <= 8 KB, 8 productos, soporte y cuentas Yape/Plin/BCP/BBVA) con **Ed25519** (`utf8.encode('MLC1-$payloadB64')`), incrementa la revisión monotónica `system.commercial_sync_revision`, autoverifica y emite el token copiable + mensaje WhatsApp.
     - Motor QR **ISO/IEC 18004 completo (Versiones 1 a 40, hasta `2,953 B`)** 100 % offline con selección automática `QRCode.CorrectLevel.L` para payloads densos (`> 900 B`) y módulo entero nítido (`512×512 px` + *quiet zone* blanca de `32 px` = `576×576 px < 1024 px`), certificado round-trip con `jsQR`.
     - Tabla resumen completa visible para los **8 productos** con encabezados claros (**`Producto` | `Precio` | `Vigencia` | `Bolsa IA` | `Updates`**; etiquetas `Recarga`, `Pase anual`, `Único`, `Vitalicia` y **`12 meses`** garantizados en `Perpetuo Liberado` y `Pase Anual de Updates`), guía paso a paso de 3 pasos para el cliente, badge de estado `#mlc1QrMetaBadge` y botón en 1 clic **`Auditar esta ficha en Inspector`** (`#btnAuditMlc1InInspector`).
   - **Vía 2 (`Opción A` — Archivo Dart Completo `owner_commercial_defaults.dart`):**
     - `GET /api/config/dart-defaults-snippet` exporta de principio a fin el archivo declarativo **`app_movil/lib/core/config/owner_commercial_defaults.dart`** (`OwnerCommercialDefaults`, importado limpiamente por `OwnerLegalIdentity` sin alterar `currentAppVersionWithBuild` ni métodos de negocio) sin incrementar `ver`.
     - Presenta instrucciones claras en **2 pasos (`Ctrl+A` → `Ctrl+V`)**, botón **`Copiar Archivo Completo (.dart)`** (`#btnCopyMlc1Dart`) y descarga directa **`Descargar archivo .dart`** (`#btnDownloadMlc1Dart`) en UTF-8 sin BOM.

---

### 1.12. Seguridad y Portabilidad (`#tabSecurityVault`)
En el Sidebar, accede a **Seguridad y Portabilidad (`#tabSecurityVault`)**:
1. **Cabecera Funcional y Auditoría Integral:**
   - Botón **`Auditar Estado`** (`#btnRefreshVaultHealth` -> `GET /api/vault/audit`): abre `#modalVaultAuditReport` inspeccionando salud Windows DPAPI, llavero, paridad SHA-256 real disco vs espejo `%APPDATA%\MochilaListaAdminVault\` sobre los **5 archivos críticos** (`clients_db`, `releases_db`, `owner_config`, `master_key`, `vault_keyring`) con fechas en `America/Lima (GMT-5)`, estado de nube y recomendaciones accionables.
   - Botón **`Sincronizar Espejo`** (`#btnForceSyncMirrorTop`): icono SVG de sincronización que rota únicamente mientras la petición está en curso (`.is-spinning`).
2. **Transparencia Física de Almacenamiento (`6/6` Columnas Reales):**
   - Tabla `#tbodyVaultFiles` alineada exactamente con 6 columnas (`Archivo Físico`, `Propósito Crítico`, `Estado` disco/espejo, `Tamaño` real formateado desde `size_bytes`, `Última Modificación` en Lima GMT-5 y `Huella SHA-256` con botón copiar hash completo).
   - Rutas `#txtMirrorPath` y `#pathCloudDir` con truncado elegante, botón **`Copiar`** de nube deshabilitado cuando no hay carpeta configurada y botón **`Examinar...`** (`POST /api/vault/cloud-path/browse`) en Paso 1 con rechazo de raíces y carpetas internas sensibles.
3. **Coherencia `4 Factores (25 % c/u)` ↔ `Asistente 3 Pasos` y Custodia Segura:**
   - Índice unificado `security_score` (`25%` × DPAPI, `.mlkey`, Kit Rescate y PIN) reflejado en badges reales `#badgeStep1Status..3` y timestamp `#mirrorLastSyncLabel` en hora Lima (nube local como respaldo redundante independiente).
   - Confirmación protectora anti-sobrescritura antes de regenerar `.mlkey` o Kit 8 Códigos + QR (evitando invalidar copias físicas previas), identificador público seguro `MLVAULT-...` en `#kitVaultId` e impresión A4 limpia (`@media print`).
4. **Bloqueo Local con PIN (`HTTP 423 Locked`), Cookie `HttpOnly` y Portabilidad `.mlvault`:**
   - Al activar PIN (`configurePin`), emite `session_token` inmediato sin auto-423 y entrega cookie `Set-Cookie: vault_session_token=...; Path=/; SameSite=Lax; HttpOnly` en `configure`/`verify`/`recover` (limpiada en `lock` / desactivación), permitiendo descargas directas bajo sesión PIN mientras mantiene `HTTP 423` en peticiones y apagado sin autenticar.
   - Desbloquear o recuperar ejecuta `bootstrapAuthenticatedWorkspace()` para poblar vistas en caliente; cancelar desactivación revierte `#chkEnablePin` a activo.
   - **Portabilidad (`.mlvault`):** Inspección precisa de metadatos (`version`, `created_at_lima`, `stats.clients_count`, `stats.releases_count`, `appVersion = '9.41.0+85'`) y auto-recuperación en 1 clic si falta la carpeta `data/`.

---

## GUÍA 2: COMPILACIÓN Y FIRMA OFICIAL RELEASE DE LA APP MÓVIL

### 2.1. Creación del Keystore de Producción (`keytool`)
Para generar tu almacén de claves RSA de 4096 bits:

```cmd
keytool -genkey -v -keystore C:\Users\vjuli\Documents\mochilalista-app\app_movil\android\mochilalista-release-key.jks -keyalg RSA -keysize 4096 -validity 10000 -alias mochilalista-key
```

Datos de titularidad requeridos:
- **Titular:** Julio Angello Vasquez Navarro
- **Unidad:** MochilaLista Core Development
- **Organización:** MochilaLista
- **Ciudad / País:** Lima, PE

---

### 2.2. Configuración Segura de `android/key.properties` y Anti-Fugas en `.gitignore`
En `app_movil/android/key.properties`:
```properties
storePassword=TU_PASSWORD_DEL_KEYSTORE
keyPassword=TU_PASSWORD_DE_LA_CLAVE
keyAlias=mochilalista-key
storeFile=mochilalista-release-key.jks
```

En `.gitignore` se encuentran protegidos `key.properties`, `*.jks`, `*.key`, `private_keys/` y `backups/`, imposibilitando cualquier fuga accidental a repositorios públicos.

---

### 2.3. Compilador Dual Oficial Único y Guiado (`compilar_release_dual.bat` — Recomendado)

Desde el **Plan Maestro 23.5**, la vía oficial principal para compilar y certificar cada lanzamiento móvil es el lanzador único **`compilar_release_dual.bat`** (en la raíz del repositorio) junto con su motor **`scripts/compilar_release_dual.ps1`**.

Genera, audita forensemente y entrega automáticamente en `C:\Users\vjuli\Documents\v-app-offline apks\` **ambos binarios oficiales** de la versión declarada en `app_movil/pubspec.yaml`:
- **APK Universal (`~108 MB`):** `mochilalista_v<tag>_atp.apk` (todas las ABIs `arm64-v8a`, `armeabi-v7a`, `x86_64`; ideal como respaldo maestro o instalación USB).
- **APK ARM64 Ligero (`~39 MB`):** `mochilalista_v<tag>_arm64_atp.apk` (`--split-per-abi`; 99 % de celulares modernos de 64 bits, por debajo del tope de `100 MB` para envío directo por WhatsApp Web).
- *(La etiqueta `<tag>` se calcula dinámicamente desde `pubspec.yaml`: si `patch == 0` usa `vX.Y`, p. ej. `9.41.0+85` ➔ `v9.41`; si `patch > 0` conserva `vX.Y.Z`, p. ej. `9.41.2+87` ➔ `v9.41.2`).*

#### Tabla Completa de Parámetros (Flags):

| Parámetro | Comportamiento | Cuándo Usarlo |
|---|---|---|
| *(sin flags)* | Ejecuta los 6 pasos completos (pre-chequeo, análisis, Universal, ARM64, certificación y resumen). | Al emitir una nueva versión oficial desde `app_movil/pubspec.yaml`. |
| `--help`, `-h`, `/?` | Imprime la guía rápida de variantes, flags, ejemplos y etapas, y termina con código `0` sin compilar ni pausar. | Cuando necesites recordar flags o nombres de salida. |
| `--dry-run` | Ejecuta el `[Paso 1/6]` (SemVer, keystore `.jks`, SDK `build-tools`, ruta destino) y muestra los comandos exactos sin compilar ni escribir en disco. | Para verificar el entorno antes de esperar una compilación completa. |
| `--verify-only` | Omite análisis y compilación (`flutter` no requerido), auditando en segundos con `aapt2` + `apksigner` ambos APKs ya existentes en destino. | Para re-certificar o inspeccionar el SHA-256 y firma de binarios ya compilados. |
| `--skip-analyze` | Salta `[Paso 2/6]` (`flutter analyze --no-pub`) manteniendo compilación Dual + certificación obligatoria. | En re-empaquetados urgentes tras haber ejecutado análisis previo. |
| `--no-pause` | Finaliza inmediatamente sin esperar `ENTER` al concluir o fallar. | Scripts automatizados, CI local o verificación desde terminal/agente. |
| `--init-notes` | Prellena en **UTF-8 sin BOM** los borradores `mochilalista_v<tag>_atp.txt` y `mochilalista_v<tag>_atp_cambios.txt` solo si faltan (combinable con `--verify-only` y `--dry-run`; jamás sobrescribe notas existentes). | Al certificar o preparar un nuevo release (`compilar_release_dual.bat --verify-only --init-notes --no-pause`), también disponible como 4.º comando copiable en `#dualBuildGuidePanel`. |
| `--out-dir "<ruta>"` | Redirige la carpeta de entrega de los APKs en lugar de `C:\Users\vjuli\Documents\v-app-offline apks`. | Respaldos aislados en disco externo o carpeta temporal de pruebas. |

#### Flujo Guiado de 6 Pasos (`[Paso 1/6]` .. `[Paso 6/6]`):
1. **`[Paso 1/6]` Pre-chequeos de entorno:** Lee `version: X.Y.Z+B` en `app_movil/pubspec.yaml`, verifica `app_movil/android/key.properties` leyendo **únicamente** `storeFile=` para confirmar que exista el `.jks` (**jamás** imprime `storePassword` ni `keyPassword`), valida Flutter y localiza la versión numérica más alta de Android SDK `build-tools` (p. ej. `37.0.0`).
2. **`[Paso 2/6]` Análisis estático:** Ejecuta `flutter analyze --no-pub` en `app_movil/` (omitido con `--skip-analyze`, `--verify-only` o `--dry-run`).
3. **`[Paso 3/6]` Compilación APK Universal:** `flutter build apk --release --obfuscate --split-debug-info=build/app_symbols --dart-define=PRODUCTION=true` y entrega a `mochilalista_v<tag>_atp.apk`.
4. **`[Paso 4/6]` Compilación APK ARM64 Ligero:** `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/app_symbols --dart-define=PRODUCTION=true` y entrega a `mochilalista_v<tag>_arm64_atp.apk`.
5. **`[Paso 5/6]` Certificación forense obligatoria sobre AMBOS APKs:**
   - **`aapt2 dump badging`:** Verifica `package: name='com.mochilalista.app'`, paridad exacta de `versionName` y `versionCode` (`B` en Universal; `2000 + B` o `B` en ARM64), ABIs esperadas, `MinSdk`/`TargetSdk` y aborta si aparece `application-debuggable`.
   - **`apksigner verify --verbose --print-certs`:** Soporta tanto **SDK `37+`** (`V2 Signer: certificate SHA-256 digest: ...`, ignorando líneas `SourceStamp`) como **SDK `<= 36.x`** (`Signer #1 certificate SHA-256 digest: ...`), exigiendo coincidencia `1:1` con la huella RSA-4096 oficial **`7c43addc34776f3974eac23fdacc47599efd5393a4dbb28672d06899833ffd20`**.
6. **`[Paso 6/6]` Resumen Ejecutivo, Checklist y Generación Segura de Notas (`--init-notes`):** Muestra tamaño exacto (`MB` y bytes), ahorro `%` del ARM64 frente al Universal, hashes `SHA-256` de archivo, titular del certificado (`CN=Julio Angello Vasquez Navarro`), estado en disco de las notas compañeras `mochilalista_v<tag>_atp.txt` / `_cambios.txt` y los 4 pasos de registro en `#tabReleaseManager`. Si se invoca **`--init-notes`**, genera en **UTF-8 sin BOM** las plantillas que aún no existan (con fecha `America/Lima`, pesos reales, `%` ahorro, ambos SHA-256 y huella RSA-4096), y cuando ya existen en disco imprime **`Ya existe en disco — respetada sin sobrescribir`** manteniendo intacto cada byte previo.

#### Cómo Interpretar el Resumen Final y Resolver Errores Frecuentes (`QUÉ FALLÓ` / `CÓMO SOLUCIONARLO`):

| Situación / Mensaje `QUÉ FALLÓ` | Qué Significa en la Práctica | `CÓMO SOLUCIONARLO` |
|---|---|---|
| `No se encontró el ejecutable 'flutter' en el PATH` | Windows no tiene `flutter\bin` accesible desde CMD/PowerShell. | Instala Flutter SDK o añade `flutter\bin` a las Variables de Entorno y abre nueva consola. |
| `No existe el archivo de configuración de firma android\key.properties` / falta `.jks` | Falta el archivo de configuración local o la ruta de `storeFile=` no apunta al `.jks`. | Verifica `app_movil\android\key.properties` y que el archivo `.jks` oficial esté en `app_movil\android\`. |
| `No se encontraron las herramientas 'aapt2' y 'apksigner'` | No hay `build-tools` en `ANDROID_HOME`, `ANDROID_SDK_ROOT` o `%LOCALAPPDATA%\Android\Sdk`. | Instala *Android SDK Build-Tools* desde Android Studio SDK Manager o define `ANDROID_HOME`. |
| `El APK ... contiene la bandera 'application-debuggable'` | Se intentó certificar o colar un binario de depuración (`debug`). | Recompila en modo `--release` limpio sin flags de depuración y revisa `build.gradle.kts`. |
| `FIRMA NO OFICIAL ... Huella detectada != 7c43addc...` | El binario fue firmado con debug keystore u otro certificado ajeno al propietario. | Verifica que `key.properties` apunte al keystore oficial RSA-4096 de Julio Angello Vasquez Navarro. |
| `No se encontró el archivo APK ...` en `--verify-only` | No existen ambos archivos (`_atp.apk` y `_arm64_atp.apk`) de la versión actual en `--out-dir`. | Comprueba la ruta de salida o ejecuta `compilar_release_dual.bat` sin `--verify-only` para compilarlos. |
| `Parámetro desconocido o no soportado` | Se escribió mal un flag CLI. | Ejecuta `compilar_release_dual.bat --help --no-pause` para copiar la sintaxis válida. |

---

### 2.4. Scripts Individuales de Compatibilidad (`compilar_apk_comercial.bat` y `compilar_apk_arm64.bat`)
Ambos scripts individuales históricos se mantienen **100 % operativos** para compilaciones unitarias aisladas:
- **APK Release Universal (`compilar_apk_comercial.bat`):** Ejecuta análisis estático, compila `app_movil/build/app/outputs/flutter-apk/app-release.apk` (`--release --obfuscate --split-debug-info=build/app_symbols --dart-define=PRODUCTION=true`), calcula el SHA-256 e instala compatibilidad con todas las arquitecturas (`~107.73 MB` en `v9.41.0+85`).
- **APK Release Ligero ARM64 (`compilar_apk_arm64.bat`):** Compila con `--split-per-abi` produciendo `app_movil/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (`~38.66 MB` en `v9.41.0+85`, compatible con el 99 % de teléfonos Android modernos de 64 bits y por debajo del tope de `100 MB` de WhatsApp Web).

---

### 2.5. Compilación del App Bundle para Google Play Store
```bash
cd C:\Users\vjuli\Documents\mochilalista-app\app_movil
flutter build appbundle --release --obfuscate --split-debug-info=build/app_symbols --dart-define=PRODUCTION=true
```
- **Ruta:** `app_movil/build/app/outputs/bundle/release/app-release.aab`

---

### 2.6. Auditoría Forense Manual y Verificación de Firma (`aapt2` + `apksigner`)
Para auditar manualmente cualquier `.apk` desde terminal (equivalente al `[Paso 5/6]` de `compilar_release_dual.bat`):
```cmd
"%LOCALAPPDATA%\Android\Sdk\build-tools\37.0.0\aapt2.exe" dump badging "C:\Users\vjuli\Documents\v-app-offline apks\mochilalista_v9.41_atp.apk"
"%LOCALAPPDATA%\Android\Sdk\build-tools\37.0.0\apksigner.bat" verify --verbose --print-certs "C:\Users\vjuli\Documents\v-app-offline apks\mochilalista_v9.41_atp.apk"
```
Certifica que no exista `application-debuggable`, valida `versionCode` / `ABIs` y comprueba en **`V2 Signer:`** (SDK `37+`) o **`Signer #1`** (SDK `<= 36`) que la firma corresponda exclusivamente al certificado RSA-4096 emitido a nombre de **Julio Angello Vasquez Navarro** (`7c43addc34776f3974eac23fdacc47599efd5393a4dbb28672d06899833ffd20`).

---

## GUÍA 3: PUBLICACIÓN Y NOTIFICACIÓN DE ACTUALIZACIONES (RELEASE MANAGER — PLANES 19, 22, 22.5 Y 23)

### 3.1. Diferenciación Estricta: `HOTFIX` vs. `FEATURE_RELEASE`

| Categoría | Ejemplos | ¿Quién tiene derecho a instalarla? | Vigencia |
| :--- | :--- | :--- | :--- |
| **HOTFIX** (Estabilidad) | `9.23.1`, `9.24.1` | **TODOS los clientes**, tanto con suscripción como con **Licencia Perpetua vitalicia**. | **Vitalicio** (Garantía de software funcional). |
| **FEATURE_RELEASE** (Nuevas Funciones) | `9.41.0`, `10.0.0` | Clientes con **suscripción activa** o Licencia Perpetua con pase vigente (`updates_until`). | Requiere suscripción o Pase Anual de Updates (S/ 150.00). |

---

### 3.2. Alta Determinista (`#modalCreateRelease`), Caché Persistente en Disco e Higiene Git
En la pestaña **Versiones APK (`#tabReleaseManager`)**, el modal **Subir y Registrar Nueva Versión del APK (`#modalCreateRelease`)** y el servidor `server.dart` operan sobre un motor optimizado (Planes 22.5 y 23):
1. **Limpieza Determinista & Tarjeta Unívoca de APK Activo (`#activeCreateApkCard`):**
   * Al abrir, cancelar/cerrar (`X`, `Cancelar`, fondo o `Escape`) o publicar una versión, `resetCreateReleaseModalState()` limpia barra de progreso, dropzone manual, selección de tarjeta, campos ocultos, contadores y rutas abiertas.
   * **Exclusión Mutua Manual vs Autodetección:** Tras subir un binario por `#apkDropZone` (`has-manual-apk`) o seleccionar un build en `#localBuildsGrid` (`.is-selected` animado / `.is-dimmed` en no seleccionados), se renderiza **`#activeCreateApkCard`** identificando inequívocamente el origen con botón **`Cambiar / Quitar APK`** (`clearSelectedCreateApk`).
2. **Singleton `ApkInspectorService` + Caché Persistente (`data/.apk_inspection_cache.json`):**
   * Al arrancar `server.dart`, una instancia singleton de `ApkInspectorService` precarga `data/.apk_inspection_cache.json` (`cache_version: 1`, máx. 200 entradas LRU, escritura atómica `.tmp` + `rename` e ignorada por `.gitignore`).
   * Invalida de inmediato si cambian `size_bytes`, `modified_micros` o se solicita `forceRefresh`, depura rutas ausentes y **lee siempre frescas desde disco** las notas compañeras `*_cambios.txt` y `*_atp.txt`, reduciendo el primer escaneo tras reiniciar el servidor de **~193.7 s a ~272 ms** sobre 86 APKs únicos.
   * **Escudo de Firma 3 Estados (SDK `37.0.0+` y `<= 36.x`):** Distingue `Oficial RSA-4096` (`7c43addc...3ffd20`), `No Oficial / posible debug.apk` (`UNOFFICIAL_SIGNATURE`) y `Sin Verificar` (`UNVERIFIED`).
3. **Autodetección Recursiva y Barras de Rutas Configurables:**
   * `GET /api/releases/detect-local-build` recorre hasta `maxDepth = 3`, ordena por SemVer descendente + `versionCode` + fecha y deduplica por SHA-256 priorizando `Biblioteca Oficial` > carpetas personalizadas > `app_movil/build`.
   * `#localBuildsToolbar` y `#createSearchDirsPanel` gestionan rutas persistidas en `system.apk_search_dirs` con selector nativo Windows PowerShell `-STA` y bloqueo estricto de raíces/secretos.
4. **Higiene Git del Catálogo Local:**
   * `mochilalista_admin/data/prod_releases_db.json` permanece desindexado de Git (`git rm --cached`) e ignorado junto con `data/.apk_inspection_cache.json`, conservando íntegros los registros locales de producción en tu disco sin riesgo de fugas en commits.

---

### 3.3. Catálogo, Verificación Masiva en 1 Clic (`#btnVerifyAllReleases`) y `#modalEditRelease`
En la tabla del catálogo y dentro del modal **Editar Versión Publicada & Changelog (`#modalEditRelease`)**:
* **Auditoría Completa en 1 Clic (`Verificar Todo el Catálogo`):** El botón **`#btnVerifyAllReleases`** ejecuta `POST /api/releases/verify-all` (con soporte `?force=true`), auditando todas las variantes registradas contra disco duro y `apksigner` en un único guardado consolidado en `backups/` y mostrando el banner descartable **`#catalogVerifyAllBanner`** con conteos de `Oficiales RSA-4096`, `No Oficiales`, `Sin Verificar` y `Extraviados en disco`, sincronizando al instante Catálogo, Matriz SemVer y `#modalWaComposer`.
* **Acciones Compactas del Catálogo:** Fila única horizontal SVG con **`Verificar`** (`POST /api/releases/:version/verify`), **`APK`**, **`Copiar`**, **`Carpeta`**, **`Editar`** y **`Eliminar`**, métricas en `MB` y píldora de adopción (`N clientes`).
* **Campos Expandibles y Variantes ABI (`Universal` & `ARM64 Ligero`):** Diferencia explícitamente variantes opcionales **`No adjuntado (Opcional)`**, **`Archivo extraviado en disco`** y **`Verificado en disco`**, con guardia ABI (`UNIVERSAL` <-> `ARM64`) al vincular o subir desde PC.

---

### 3.4. Matriz Inteligente SemVer, Corrección Segura y Reenvío en 1 Clic
La matriz evalúa la versión de cada cliente frente a la última publicada bajo 5 estados (`AL DÍA`, `ACTUALIZACIÓN PENDIENTE`, `VERSIÓN SUPERIOR`, `APK ENVIADO`, `REQUIERE PASE`) junto con `#releasesRolloutProgress`:
* **Reenvío Permanente:** Incluso clientes en **`Al Día`** o **`Versión superior`** mantienen visible el botón **`Reenviar / Elegir APK`** para volver a despachar un instalador o elegir otra versión.
* **Reversión y Corrección Segura sin `window.prompt`:** El botón rápido de marcar actualizado ofrece acción **`Deshacer`** en el toast y las celdas de versión disponen del modal **`Corregir Versión Instalada`** (`#modalFixClientVersion`), respaldado por `POST /api/clients/:id/mark-updated` con soporte `force: true` y retorno de `previous_installed_version`.

---

### 3.5. Despacho Asistido de APK por WhatsApp (`#modalWaComposer`) y Portapapeles Windows Endurecido
Al abrir **`Enviar APK`** / **`Reenviar / Elegir APK`** desde la matriz (o seleccionar la plantilla **`Nueva Versión APK`** desde CRM / Ficha 360°):
1. **Selector Dinámico de Versión (`<select id="waApkVersionSelect">`):** Permite elegir cualquier versión publicada sin cerrar el compositor, actualizando título, variante auto-seleccionada, badge de firma, esquema SQLite y changelog mientras preserva tus chips `Insertar:` activos.
2. **Alerta Preventiva `> 100 MB`:** Cuando el binario Universal (`107.73 MB` en `v9.41`) supera los **100 MB**, el panel advierte del límite de adjuntos de **WhatsApp Web (100 MB)** frente a **WhatsApp Desktop (2 GB)**, sugiriendo elegir **`ARM64 Ligero`** (`38.66 MB`), usar WhatsApp Desktop o compartir enlace externo.
3. **Acciones Flexibles de Despacho:**
   - **`Copiar Archivo .APK y Abrir WhatsApp`:** Invoca `POST /api/releases/:version/copy-file` (`powershell -NoProfile -STA` con `CF_HDROP` + `DROPEFFECT_COPY`), notificando **`Archivo .apk copiado: presiona Ctrl + V en WhatsApp`** y ofreciendo **`Volver a Copiar .APK`**.
   - **`Copiar Solo Texto`**, **`Abrir Carpeta`** y **`Solo Abrir WhatsApp`** con registro automático `APK Enviado`.

---

### 3.6. Protocolo Dual de Sincronización Offline (`.mlsync` / `MLS1-...`) y Rescate 1-Clic
Permite auditar el estado real del celular sin conexión y sin duplicar discrepancias falsas:
1. **Separación Estricta `Plan Comercial` vs `Estado de Vigencia`:** El comparador evalúa por separado el plan contratado (`pl`, ej. `TRIAL`, `MENSUAL`, `PERPETUO_LIBERADO`) y el estado operativo real (`st`, normalizando `EXPIRADA` / `VENCIDA` y manteniendo `ACTIVA` cuando un `TRIAL` está vigente — cero bucle `TRIAL -> ACTIVA`), conservando la autoridad comercial del CRM.
2. **Telemetría Completa, Español Natural y Hora Perú (`America/Lima` GMT-5):**
   - Incorpora `dr` (`Días de Vigencia Restantes`), `aiu` (`Escaneos IA Consumidos (Histórico)` con cálculo de `ai_credits_used_delta` `+N desde última sync`) y `pc` (`Perfiles de Negocio Activos`).
   - Traduce valores técnicos al español y muestra timestamps en `DD/MM/YYYY HH:mm:ss (Lima GMT-5)`. Cuando coincide al 100%, muestra **`La ficha coincide al 100% con el estado actual del CRM — Sin cambios por aplicar`**.
3. **Rescate 1-Clic de `PENDIENTE_MIGRACION`:** Identifica automáticamente al cliente origen mediante `bhw` y ofrece **`Migrar Dispositivo (Restauración — 0 días)`** sin costo extra ni duplicación de vigencia.

---

### 3.7. Comportamiento en la App Móvil: Snapshot `.bak`, Sincronización `MLC1` y Novedades `v9.41.0+85`
1. **Snapshot `.bak` Transparente e Inmutabilidad de Esquema:** La app crea `mochilalista.db_pre_upgrade_vX.bak` antes de migraciones SQLite y conserva intacto el esquema **`v36`** y la bóveda PIN (`lock_screen.dart`).
2. **Recepción Offline Reactiva de Tarifas y Cuentas (`MLC1-...`):**
   * En **Licencia y Activación** y en la **Pantalla de Bloqueo de Licencia**, la app detecta automáticamente tokens declarativos **`MLC1-...`** desde escáner QR, QR de galería, portapapeles o ingreso manual.
   * Valida firma Ed25519 con separación de dominio (`utf8.encode('MLC1-$payloadB64')`) contra la clave pública fija embebida, aplica guardia anti-downgrade monotónica `(ver, iat)`, presenta un cuadro de diálogo confirmatorio mostrando revisión, fecha en hora Perú y desglose completo de tarifas/cuentas antes de aplicar, persiste exclusivamente en **`SharedPreferences`** (`ml_commercial_config_v1`) y ofrece restauración confirmada a defaults compilados (**`Restaurar defaults`**).
3. **Novedades Comerciales Oficiales (`v9.41.0+85` — Plan Maestro 23):**
   * **Actualización segura de tarifas y cuentas sin internet:** Aplica precios oficiales de planes, cuotas IA y cuentas bancarias verificadas en segundos desde Código o QR sin esperar una nueva compilación.
   * **App más liviana y edición ligera ARM64:** Optimización lossless de `assets/logo.png` (`1,178,503 B` -> `73,718 B`, `-93.74 %`) y entrega dual oficial ofuscada y firmada RSA-4096: **Universal (`107.73 MB`, SHA-256 `d8597dd7...4514`)** + **ARM64 Ligero (`38.66 MB`, SHA-256 `fdb64551...0b9e`)**.
4. **Historial Inmediato Anterior (`v9.40.0+84` — Plan Maestro 21):**
   * Inicio más amplio sin parpadeo Perfil -> Home, 35 tours interactivos con sello anti-reactivación y Radar Comercial IA aislado por `profile_id`.
   * Previo (`v9.39.0+83`): Planes Comerciales plegables, Operaciones Financieras cómodas y Radar Comercial IA con noticias del Perú (`https://www.gob.pe/...`).
   * Previo (`v9.38.0+82`): Protocolo `.mlsync` / `MLS1-...` y rescate 1-clic de `PENDIENTE_MIGRACION`.

---

## GUÍA 4: PROTOCOLO DE RESPUESTA ANTE INCIDENTES Y SEGURIDAD ADVERSARIAL

### 4.1. Incidente: Pantalla de "Reloj Desajustado / Manipulación Temporal"
- **Causa:** El usuario retrasó la fecha de su celular o la batería llegó a 0% desconfigurando el reloj de hardware a 1970.
- **Solución:** Indicar al cliente que active **"Usar la hora proporcionada por la red"** y **"Zona horaria automática (GMT-5)"** en los ajustes de su teléfono. Al reabrir la app, se desbloquea de inmediato.

### 4.2. Incidente: Pantalla de "Licencia Pendiente de Migración" (Doble Candado Anti-Clonación & Rescate 1-Clic)
- **Causa:** Un comerciante intentó restaurar un backup o clonar su base de datos en otro teléfono, activando la protección anti-clonación.
- **Protocolo de Rescate 1-Clic (Plan Maestro 19):**
  1. El cliente pulsa en su celular el botón **`[Enviar solicitud de migración por WhatsApp]`** (disponible directamente en la pantalla de bloqueo).
  2. El mensaje llega al WhatsApp de Soporte con el token protegido `Ref. soporte: MLS1-...` que incluye automáticamente el nuevo Hardware ID (`hw`), el Hardware ID anterior (`bhw`) y el estado `PENDIENTE_MIGRACION`.
  3. En **MochilaLista Admin**, abre el modal **`[Sincronizar Estado Real]`** (desde Cartera CRM o la Ficha del Cliente) o la pestaña **Inspector Forense**, y pega el mensaje o token.
  4. El sistema detecta automáticamente al cliente original y despliega el botón **`[Rescatar y Migrar Dispositivo]`**.
  5. Al hacer clic, el sistema reasigna la licencia al nuevo celular conservando intactos sus días de vigencia y saldo IA con **0 días adicionales de costo**.
  6. *Si es piratería:* El teléfono receptor permanece bloqueado y debe adquirir una licencia independiente.

### 4.3. Incidente: Agotamiento de la Bolsa de Escaneos con IA
- **Alternativa A:** Compra de Bolsa Extra (+150 escaneos por S/ 20.00 sin caducidad).
- **Alternativa B:** Modo BYOK Ilimitado (el cliente genera su clave gratuita en [Google AI Studio](https://aistudio.google.com/) y la ingresa en `Perfil > Licencia`).

### 4.4. Custodia y Respaldo Frío de la Clave Privada Maestra (`ed25519_master.key`)
> [!CAUTION]
> `mochilalista_admin/private_keys/ed25519_master.key` es el activo criptográfico más valioso del proyecto. Mantén copias en dos memorias USB desconectadas de internet (almacenamiento frío) y jamás la subas a la nube.

---

### 4.5. Tabla de Políticas y Tarifario Oficial de Soporte Perú

| Producto / Servicio | Modalidad | Precio Oficial | Alcance y Condiciones |
| :--- | :--- | :--- | :--- |
| **Trial Gratuito** | Evaluación | **S/ 0.00** | +30 días de vigencia, **+50 escaneos IA** acumulativos, activación 100% offline. |
| **Plan Mensual** | Suscripción | **S/ 35.00** | +30 días acumulativos, **+50 escaneos IA** acumulativos sin vencimiento, soporte estándar. |
| **Plan Trimestral** | Suscripción | **S/ 90.00** | +90 días acumulativos (Ahorro S/ 15), **+180 escaneos IA** acumulativos sin vencimiento. |
| **Plan Semestral** | Suscripción | **S/ 160.00** | +180 días acumulativos (Ahorro S/ 50), **+450 escaneos IA** acumulativos sin vencimiento. |
| **Plan Anual** | Suscripción | **S/ 280.00** | +365 días acumulativos (Ahorro S/ 140), **+1,200 escaneos IA** acumulativos sin vencimiento. |
| **Licencia Perpetua Liberada** | Pago Único | **S/ 850.00** | Uso vitalicio ilimitado, **+200 escaneos IA** acumulativos, 12 meses de updates incluidos. |
| **Pase Anual de Updates** | Anual (Perpetuos) | **S/ 150.00** | +12 meses de nuevas funciones, **+100 escaneos IA** acumulativos para licencias perpetuas. |
| **Bolsa Extra IA (+150 escaneos)** | Recarga | **S/ 20.00** | **+150 escaneos IA** acumulativos sin vencimiento para usar con la clave oficial integrada. |
| **Reasignación por Cambio de Celular** | Servicio Técnico | **S/ 40.00** | Migración segura de hardware, transferencia de días y créditos acumulados a nuevo DeviceID. |
| **Extensión de Cortesía (Gracia)** | Cortesía | **S/ 0.00** | +7 días de gracia para clientes con cobranza en trámite o emergencias operativas. |

---

## CAPÍTULO 8: MANUAL DE PERSISTENCIA BLINDADA, PORTABILIDAD MULTI-PC (`.mlvault`) Y RECUPERACIÓN MULTI-LLAVE ("A PRUEBA DE OLVIDOS")

### 8.1. Dónde Viven Realmente tus Datos y Cero Pérdida por Limpieza de Navegador
Uno de los principios de diseño fundamentales de **MochilaLista Admin** es la **soberanía y segregación absoluta entre la interfaz web y el motor de datos**:
* **Cero Dependencia de Navegadores:** La interfaz web (`http://localhost:8080`) es un cliente desacoplado. **Ningún dato sensible, cliente, clave o configuración reside en `localStorage`, `IndexedDB` o cookies del navegador.** Si limpias el historial de Chrome/Edge, borras la caché, abres una ventana de incógnito o cambias de navegador, **no pierdes absolutamente nada**.
* **Almacenamiento Activo (En Proyecto):**
  - Directorio: `mochilalista_admin/data/` (`prod_clients_db.json`, `prod_releases_db.json`, `owner_config.json`, `vault_keyring.json`).
  - Clave Asimétrica Maestra: `mochilalista_admin/private_keys/ed25519_master.key`.
  - Respaldos Históricos: `mochilalista_admin/backups/`.
* **Bóveda Espejo Cifrada en Sistema Operativo (`%APPDATA%`):**
  - Ruta en Windows: `%APPDATA%\MochilaListaAdminVault\` (`C:\Users\<Usuario>\AppData\Roaming\MochilaListaAdminVault\`).
  - Archivo Principal: `auto_mirror_latest.mlvault`.
  - **Mecanismo de Protección:** Cifrado con **Windows Data Protection API (DPAPI)** nativo mediante Crypt32.dll y CryptProtectData (`currentUser`). Los datos quedan vinculados a las credenciales de tu cuenta de usuario de Windows y al chip TPM de tu laptop. Si alguien copia físicamente la carpeta o accede al disco duro desde otra máquina, los datos son ilegibles.
* **Espejo en Nube Personal Opcional:**
  - Puedes definir una carpeta local sincronizada por tu proveedor de nube favorito (Google Drive para Escritorio, OneDrive, Dropbox).
  - Cada vez que emites una licencia, registras un cobro o cambias un ajuste, `VaultStorageService` sincroniza automáticamente una réplica cifrada hacia dicha carpeta.

---

### 8.2. Checklist Inicial de Blindaje en 3 Pasos (Asistente Guiado de 60 Segundos)
Al iniciar la plataforma por primera vez en tu laptop o al ingresar a la pestaña **Seguridad y Portabilidad (`#tabSecurityVault`)**, revisa el panel superior (**`4 Factores de Seguridad × 25 % c/u`** + botón **`Auditar Estado`** `GET /api/vault/audit`) y ejecuta el **Asistente Guiado de Blindaje**:

```
[ PASO 1: Sincronizar Espejo Local / Nube ] ──> [ PASO 2: Descargar Llave .mlkey ] ──> [ PASO 3: Imprimir Kit de Emergencia PDF ]
```

1. **Paso 1: Sincronizar Espejo Local y Nube (`#badgeStep1Status`):**
   - Haz clic en **`Sincronizar Espejo`** o **`Sincronizar Bóveda Ahora`** y comprueba que `#mirrorLastSyncLabel` muestre la marca en `America/Lima (GMT-5)`.
   - El sistema empaquetará bases de datos, configuración y clave Ed25519 en `auto_mirror_latest.mlvault`, cifrándolo con Windows DPAPI.
   - Si usas Google Drive, Dropbox u OneDrive, pulsa **`Examinar...`** (`#btnBrowseCloudSyncPath`, con bloqueo automático de raíces y carpetas internas del proyecto) y guarda tu carpeta externa sincronizada.
2. **Paso 2: Descargar y Resguardar tu Archivo Llave (`.mlkey`, `#badgeStep2Status`):**
   - Presiona **`Descargar Llave (.mlkey)`** para obtener `llave_maestra_mochilalista.mlkey` (`MLKEY:...`).
   - Si ya existe una llave activa en el llavero (`slot_2_file`), la plataforma solicitará **confirmación explícita anti-invalidación**, advirtiendo que regenerar la llave invalida copias físicas previas en USB.
   - **Regla de Oro:** Copia este archivo en una **memoria USB física** y guárdala junto a tus documentos personales o gestor cifrado de contraseñas.
3. **Paso 3: Imprimir o Guardar en PDF el Kit de Emergencia (`#badgeStep3Status`):**
   - Presiona **`Generar Kit de Rescate`** (con confirmación protectora si ya existen 8 códigos activos en `slot_3_emergency`).
   - Se abrirá la vista de impresión A4 optimizada (`@media print` con `height: auto` y `overflow: visible`, ID público seguro `MLVAULT-...` y márgenes limpios para Chromium `--app`), incluyendo **8 Códigos de Rescate unívocos (`ML-XXXX-YYYY-ZZZZ`)** y **Código QR vectorial**.
   - **Acción:** Imprime una copia física en papel bajo llave o expórtala como **"Guardar como PDF"** fuera de la PC.

---

### 8.3. Guía Paso a Paso en 5 Segundos para Mudar a Laptop Nueva o Formateada (`.mlvault`)
Cuando renueves tu laptop o formatees tu equipo, no necesitas configurar clientes ni regenerar claves desde cero:

```
[ PC Antigua / Origen ]                                                [ PC Nueva / Destino ]
1. Ir a "Seguridad & Bóveda"                                           1. Instalar Dart / Clonar repo
2. Presionar [Exportar Bóveda (.mlvault)]                             2. Iniciar: dart run server.dart
3. Copiar archivo a USB o enviar por Drive                             3. Abrir: http://localhost:8080
                                                                       4. Arrastrar el archivo .mlvault
                                                                       5. Desbloquear con .mlkey o Código
                                                                       6. Activar: "Re-cifrar con DPAPI"
                                                                       ✨ ¡LISTO EN 5 SEGUNDOS!
```

#### Procedimiento Detallado:
1. **En la PC Antigua:**
   - Abre `http://localhost:8080` > Pestaña **Seguridad & Bóveda**.
   - En la sección **Exportar / Portabilidad**, asegúrate de que esté marcado *"Incluir Clave Privada Maestra Ed25519"*.
   - Presiona **`[📦 Exportar Bóveda (.mlvault)]`**.
   - Se descargará un archivo como `MochilaLista_Vault_Backup_20261119_180000.mlvault`. Cópialo a un pendrive USB.
2. **En la Laptop Nueva:**
   - Copia la carpeta del repositorio `mochilalista-app` en la nueva laptop.
   - Abre una terminal y arranca el servidor:
     ```powershell
     cd C:\Users\vjuli\Documents\mochilalista-app\mochilalista_admin
     dart run server.dart
     ```
   - Abre `http://localhost:8080` en tu navegador.
   - Ve a **Seguridad & Bóveda** > Sección **Mudanza / Importar Bóveda**.
   - Arrastra el archivo `.mlvault` dentro del recuadro punteado.
   - El Inspector Forense te mostrará la tarjeta con la fecha de creación, tamaño y confirmación: `✓ Incluye Clave Maestra Ed25519`.
   - Selecciona tu método de autenticación:
     - **Opción A (Recomendada):** Sube tu archivo `.mlkey` guardado en la USB.
     - **Opción B:** Escribe uno de tus 8 Códigos de Rescate impresos (`ML-XXXX-YYYY-ZZZZ`).
     - **Opción C:** Si habías configurado un PIN en la laptop anterior y lo recuerdas, escríbelo.
   - Marca la casilla **`[✓] Re-cifrar y proteger con DPAPI de esta nueva computadora`**.
   - Presiona **`[🚀 Importar y Desbloquear Bóveda]`**.
3. **Resultado Inmediato:**
   - Todos los clientes (`prod_clients_db.json`), versiones (`prod_releases_db.json`), ajustes (`owner_config.json`) y la clave asimétrica (`ed25519_master.key`) se escriben en disco y **se recargan en caliente en la memoria del servidor** sin reiniciar.
   - El nuevo espejo en `%APPDATA%` de la laptop queda protegido con la DPAPI nativa de esa máquina.
   - Puedes ir al Generador y emitir licencias de inmediato: la app móvil verificará la firma sin problemas.

---

### 8.4. Protocolo de Emergencia ante Incidentes de Acceso o Pérdida

#### CASO 1: Olvido de PIN Local (Bloqueo en Pantalla)
* **Síntoma:** Al abrir `http://localhost:8080`, aparece el modal oscuro *"Bóveda Protegida — Ingresa tu PIN de Acceso"*, pero no recuerdas los dígitos. Todas las acciones devuelven `HTTP 423 Locked`.
* **Solución Rápida:**
  1. En el modal de bloqueo, haz clic en el enlace inferior **`"¿Olvidaste tu PIN? Recuperar acceso"`**.
  2. Se abrirá el modal de emergencia con 3 vías de desbloqueo:
     - **Vía 1 (Automática por DPAPI):** Si estás en tu misma sesión de Windows, presiona **`[🔓 Desbloquear con Windows DPAPI]`**. El sistema validará tu identidad contra el sistema operativo y removerá el PIN de inmediato.
     - **Vía 2 (Archivo `.mlkey`):** Carga tu archivo `.mlkey` de la memoria USB.
     - **Vía 3 (Código de Rescate):** Escribe cualquiera de los 8 códigos de tu Kit impreso (`ML-XXXX-YYYY-ZZZZ`).
  3. Al validar la credencial, el servidor elimina el PIN olvidado, desbloquea la sesión y te permite establecer uno nuevo si lo deseas.

#### CASO 2: Borrado Accidental de la Carpeta o Formateo del Disco C:
* **Síntoma:** Borraste por error la carpeta `mochilalista_admin/data/` o clonaste un repositorio Git limpio donde `.gitignore` excluyó las bases de datos y claves privadas.
* **Solución (Auto-Recuperación en 1 Clic):**
  1. Arranca el servidor local: `dart run server.dart`.
  2. Abre `http://localhost:8080`.
  3. El sistema detectará automáticamente:
     ```
     [⚠️ ALERTA: Base de datos local vacía, pero existe Bóveda Espejo en %APPDATA%]
     ```
  4. Presiona el botón luminoso **`[🛡️ Restaurar Todo desde Espejo en 1 Clic]`**.
  5. Dado que estás en la misma PC con tu usuario de Windows, DPAPI desencripta el espejo de forma transparente y reescribe `data/prod_clients_db.json`, `data/owner_config.json` y `private_keys/ed25519_master.key`.
  6. La plataforma vuelve al estado 100% operativo con todo el historial de clientes y transacciones intacto.

#### CASO 3: Intentos Repetidos de Adivinación de PIN (Anti-Fuerza Bruta)
* Si un tercero intenta adivinar tu PIN probando combinaciones al azar, el servidor activa el **mecanismo de retardo exponencial (Backoff Progresivo)**:
  - Intentos 1 a 3: Respuesta inmediata.
  - Intentos 4 a 5: Retardo forzado de 2 segundos.
  - Intentos 6 a 10: Retardo forzado de 5 a 10 segundos.
  - Más de 10 intentos: Bloqueo temporal de 30 segundos por intento fallido.
* Este mecanismo hace matemáticamente inviable cualquier ataque de fuerza bruta local o por red.

---

### 8.5. Soberanía Criptográfica y Garantía de Continuidad de Negocio a 10 Años
La arquitectura criptográfica implementada en el Plan Maestro 10 cumple con el estándar de **Cifrado de Sobre en 2 Niveles (`Envelope Encryption`)**:
1. **VMK (Vault Master Key):** Llave simétrica de 256 bits generada con `Random.secure()`, persistente durante toda la vida útil de tu instalación.
2. **Key Slots Múltiples:** La VMK se encuentra cifrada de forma independiente en múltiples ranuras (`vault_keyring.json`):
   - Ranura 1: Windows DPAPI (acceso local sin fricción).
   - Ranura 2: Archivo `.mlkey` (resguardo portátil físico).
   - Ranuras 3 a 10: 8 Códigos de Rescate con derivación PBKDF2-HMAC-SHA256 (100,000 iteraciones y salt criptográfico unívoco).
   - Ranura 11: PIN numérico local con PBKDF2 y salt independiente.
3. **DEK Efímera (Data Encryption Key):** En cada exportación `.mlvault`, se genera una llave efímera de 256 bits y un IV de 96 bits para cifrar el payload con **AES-256-GCM**, envolviendo la DEK con la VMK.
4. **Independencia Tecnológica:** El formato `.mlvault` y `.mlkey` es JSON estándar con Base64 y criptografía AES-GCM estándar internacional (NIST SP 800-38D). Incluso dentro de 10 años, cualquier herramienta de software libre (OpenSSL, Python, Rust, Dart) podrá abrir tus respaldos teniendo tu llave o tus códigos de rescate impresos.

---

*Certificado y Aprobado para Operaciones Oficiales.*  
**Julio Angello Vasquez Navarro**  
**Titular y Desarrollador Exclusivo de MochilaLista**  
*Lima, Perú — Noviembre 2026*
