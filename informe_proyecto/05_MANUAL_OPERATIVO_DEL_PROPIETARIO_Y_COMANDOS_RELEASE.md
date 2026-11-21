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
   - 1.6. Inspector Forense de Tokens ML9 con Lector Óptico de Imagen QR y Tabla de Claims
   - 1.7. Pestaña Finanzas & Respaldos: Libro Contable y Centro de Respaldos en Disco (`backups/`)
   - 1.8. Venta de Bolsas Extra de Escaneos IA (+150 escaneos)
   - 1.9. Reasignación Técnica de Dispositivo por Cambio o Pérdida de Celular
   - 1.10. Re-descarga de Credenciales PNG Históricas desde el Modal de Cliente
   - 1.11. Centro de Personalización y Exportación a Libros Excel Multi-Hoja (`#tabSettings`)
   - 1.12. Bóveda de Seguridad, Persistencia y Multi-Llave (`#tabSecurityVault`)
2. [GUÍA 2: Compilación y Firma Oficial Release de la App Móvil](#guía-2-compilación-y-firma-oficial-release-de-la-app-móvil)
   - 2.1. Creación del Keystore de Producción (`keytool`)
   - 2.2. Configuración Segura de `android/key.properties` y Anti-Fugas en `.gitignore`
   - 2.3. Compilación del APK Release Universal (`compilar_apk_comercial.bat`)
   - 2.4. Compilación del APK Release Ligero ARM64 para WhatsApp (`compilar_apk_arm64.bat`)
   - 2.5. Compilación del App Bundle para Google Play Store (`flutter build appbundle`)
   - 2.6. Auditoría Forense y Verificación de Firma con `apksigner`
3. [GUÍA 3: Publicación y Notificación de Actualizaciones (Release Manager)](#guía-3-publicación-y-notificación-de-actualizaciones-release-manager)
   - 3.1. Diferenciación Estricta: `HOTFIX` vs. `FEATURE_RELEASE`
   - 3.2. Carga Directa Drag & Drop de APKs y Autodetección 1-Clic
   - 3.3. Acciones del Catálogo: Descarga Directa y Apertura en Carpeta de Windows
   - 3.4. Matriz Inteligente de Distribución y Botón de Cortesía Excepcional
   - 3.5. Comportamiento en la App Móvil: Snapshot `.bak` y Modal Post-Actualización
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
   - Validación de la disponibilidad de Dart SDK en el sistema.
   - Verificación precisa de socket en puerto 8080 (`netstat -ano | findstr ":8080 " | findstr "LISTENING"`). Si ya estaba corriendo, evita lanzar procesos duplicados.
   - Si no estaba encendido, levanta `server.dart` en una ventana minimizada dedicada con título `MochilaLista Admin Server` (pudiendo restaurarla y cerrarla con `Ctrl+C` en cualquier momento).
   - **Modo Ventana Nativa de Escritorio (`--app`):** Mediante un bucle de espera inteligente con sondeo a `http://localhost:8080`, aguarda a que el servidor esté listo para atender peticiones y lanza Microsoft Edge o Google Chrome en modo aplicación limpia:
     ```cmd
     start msedge.exe --app=http://localhost:8080
     ```
     *(o `chrome.exe --app=http://localhost:8080`)*, desplegando la plataforma en una ventana independiente, sin barra de direcciones ni pestañas de navegación genéricas, operando con la apariencia y fluidez de un software de escritorio empresarial.

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

---

### 1.3. Navegación por las 8 Pestañas Oficiales (`http://localhost:8080`)
Abre tu navegador web en `http://localhost:8080`. Dispones de **8 módulos de control ejecutivo en el Sidebar**:

1. **📊 Dashboard Financiero (`#tabDashboard`):** KPIs en tiempo real con micro-gráficos SVG interactivos (ingresos del mes, acumulado, clientes activos, por vencer, vencidos, perpetuos y desactualizados) más la tabla de **Acciones Urgentes (≤ 7 días)** con aviso directo a WhatsApp y accesos rápidos de emisión.
2. **👥 Cartera de Clientes CRM (`#tabClients`):** Directorio unificado con **buscador omnicanal reactivo**, filtros por estado, Drawer Lateral "Ficha 360°" con 5 pestañas de detalle profundo, insignias `DeviceID` con micro-botón `[📋]`, enlace directo a WhatsApp, botón de migración inmediata en 1 paso, edición total y eliminación protegida.
3. **🔑 Generador de Licencias Ed25519 (`#tabGenerator`):** Firma criptográfica asimétrica con **Tarjeta de Resumen Ejecutivo en tiempo real**, **Panel de Ajustes Comerciales Personalizados** (días libres, bonos IA, regla acumulativa vs. reinicio y fecha exacta), **Credencial PNG @2x de alta resolución**, descarga/copiado de QR y botón **`[Auditar en Inspector]`**.
4. **🚀 Gestor de Versiones / Release Manager (`#tabReleases`):** Matriz inteligente de distribución de versiones, soporte para APK universal y ligero ARM64, zona Drag & Drop a `releases_apks/`, botones de descarga directa, apertura de carpeta en Windows (`explorer.exe /select,...`) y botón **`[Autorizar Envío de Cortesía]`**.
5. **🔍 Inspector Forense de Tokens ML9 (`#tabInspector`):** Auditoría forense Ed25519 con **Lector Óptico de Imagen QR** (drag & drop de capturas de WhatsApp decodificadas offline con `jsQR`), **Tabla Unificada de Claims** (`d, p, y, n, v, iat, u, b, c`) y verificación de correlativo `nonce` contra el CRM.
6. **📈 Finanzas & Respaldos (`#tabFinances`):**
   - **Submódulo 1:** Libro contable consolidado con filtros en vivo (rango de fechas, plan, medio de pago), KPIs dinámicos y exportación a Excel (.CSV) con BOM UTF-8 (`\uFEFF`).
   - **Submódulo 2:** Centro de gestión de respaldos físicos en `backups/` con creación de snapshots manuales en 1 clic, descarga y restauración segura con punto de recuperación previo.
7. **⚙️ Centro de Personalización y Libros Excel Multi-Hoja (`#tabSettings`):**
   - Editor en caliente de identidad corporativa (`data/owner_config.json`): Titularidad INDECOPI, tarifas oficiales, números Yape/Plin, plantillas WhatsApp reactivas y temas visuales (Oscuro/Claro).
   - **Motor Exportador a Microsoft Excel Profesional Multi-Hoja (`.xlsx`):** Generador binario de 5 hojas oficiales con estilos visuales ejecutivos, totales con fórmulas reales seguras (`SUM`, `COUNTA`) y filtros sin macros.
8. **🛡️ Bóveda de Seguridad, Persistencia y Multi-Llave (`#tabSecurityVault`):**
   - Centro neurálgico de persistencia fuera del repositorio: Bóveda Espejo Cifrada con DPAPI de Windows en `%APPDATA%\MochilaListaAdminVault\`.
   - Asistente Guiado de Blindaje en 3 Pasos (Espejo/Nube, Llave `.mlkey` y Kit de Emergencia PDF con 8 Códigos de Rescate y QR).
   - Exportación e Importación Drag & Drop de Bóvedas Portables Cifradas (`.mlvault`) para mudar de PC en 5 segundos.
   - Protección de Acceso mediante PIN local (Middleware `HTTP 423 Locked`), backoff anti-fuerza bruta y recuperación en 1 clic ante borrado accidental o extravío de contraseña.

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
   * **Versión de App Instalada:** (por defecto: `9.34.0` — Esquema SQLite `v36`).
   * **Gestión de Créditos IA:**
     - **Saldo IA Reportado en Celular:** Créditos que el cliente indica tener disponibles en su app móvil.
     - **Bonos IA Pendientes por Emitir:** Escaneos adicionales que se incorporarán en la próxima emisión de token criptográfico Ed25519.
3. Presiona **"Guardar Cliente"** o **"Guardar y Emitir Licencia"**.

#### B. Compositor Universal de WhatsApp (`#modalWaComposer`):
Accesible con 1 clic desde el botón verde de WhatsApp de la Cartera CRM y desde la Ficha 360°:
- **Plantillas Predefinidas Asistidas:**
  1. *Bienvenida y Entrega:* Incluye saludo personalizado, nombre de negocio, titular, Hardware ID y código de licencia Ed25519 con instrucciones claras de pegado en la app móvil.
  2. *Vencimiento Próximo:* Alerta preventiva indicando los días exactos restantes y métodos de pago (Yape/Plin/Transferencia).
  3. *Cotización para Prospecto:* Información comercial del sistema y propuesta de valor.
  4. *Mensaje Personalizado:* Editor libre con previsualización en vivo.
- **Sustitución Automática de Variables:** `{NEGOCIO}`, `{TITULAR}`, `{DIAS}`, `{TOKEN}` se reemplazan en caliente según el cliente seleccionado.
- **Acceso Rápido:** Botón **`[Copiar Mensaje]`**, botón **`[Abrir Chat Vacío]`** (para soporte directo sin plantilla predeterminada) y botón **`[Abrir en WhatsApp]`** enlazado a `https://wa.me/51...`.

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
2. **Tarjeta Ejecutiva de Resumen:** Se desplegará inmediatamente un cuadro con su negocio, titular, Device ID, plan actual, días remanentes, fecha de expiración, créditos IA y versión instalada.
3. Elige el **Plan Oficial** tarifado o abre el acordeón:
   ```
   [⚙️ Habilitar Ajustes Comerciales Personalizados]
   ```
   * **Días a Otorgar Personalizados:** Especifica libremente `15`, `45`, `60` o la cantidad que desees.
   * **Bono de Créditos IA de Regalo:** Añade escaneos extra sin vencimiento (`+X escaneos`).
   * **Modo de Cómputo de Caducidad:** Elige entre *Regla Acumulativa* (suma a su saldo remanente) o *Reiniciar Vigencia* (comienza a contar desde hoy).
   * **Sobrescribir Fecha de Expiración:** Calendario interactivo que ajusta la fecha exacta deseada.
4. Presiona **`[⚡ Firmar Criptográficamente y Emitir Licencia]`**.
5. **Panel de Entrega Multiformato:**
   - **Código `ML9-...`:** Con botón para copiar al portapapeles.
   - **Credencial Oficial PNG en Alta Definición (@2x / 900x520 px):** Renderizada con degradado ejecutivo, sellos legales INDECOPI / D.L. 822 y código QR incrustado. Puedes presionar **`[Descargar PNG]`** o **`[Copiar Credencial]`** (para pegarla directo en WhatsApp Web con `Ctrl + V`).
   - **Botón `[📲 Enviar por WhatsApp]`:** Dispara el mensaje preformateado.
   - **Botón `[🔍 Auditar en el Inspector]`:** Pasa el código al Inspector Forense y lo audita en 1 solo clic.

---

### 1.6. Inspector Forense con Lector Óptico QR y Tabla Unificada de Claims

En la pestaña **Inspector de Tokens ML9**:
1. **Lector Óptico de Imagen QR:** Arrastra cualquier foto de un código QR o captura de pantalla de credencial directamente sobre la zona interactiva. El motor JavaScript integrado **`jsQR`** decodificará la imagen localmente sin enviar datos a internet, rellenará el campo de texto y ejecutará la auditoría al instante.
2. **Tabla Unificada de Claims:** Inspecciona de forma transparente cada clave del payload:
   - **`d`** (`device_id`): Identificador del teléfono.
   - **`p`** (`plan`): Plan comercial.
   - **`y`** (`days_added`): Días sumados.
   - **`n`** (`nonce`): Correlativo anti-reutilización.
   - **`v`** (`min_app_version`): Versión mayor mínima.
   - **`iat` / `e`** (`emitted_at`): Fecha/hora UTC de emisión.
   - **`u`** (`updates_until`): Ventana de updates para perpetuos.
   - **`b`** (`business_tag`): Nombre de la librería.
   - **`c`** (`ai_extra_credits`): Créditos IA otorgados.
3. **Cruce Automático con el CRM:** Muestra si el cliente existe en tu base de datos y si el `nonce` es el vigente (última licencia emitida), uno histórico (ya superado) o uno futuro listo para canjear.

---

### 1.7. Pestaña Finanzas & Respaldos: Libro Contable y Respaldos en Disco

#### Submódulo 1: Libro Contable de Cobranzas
- Consolida todos los pagos registrados en el entorno activo.
- **Filtros en Vivo:** Rango de fechas (`Desde` / `Hasta`), selector de Plan y selector de Medio de Pago (`Yape`, `Plin`, `BCP`, `BBVA`, `Efectivo`).
- **KPIs Dinámicos:** Total Recaudado (S/), Ticket Promedio (S/), N.° de Transacciones y Canal de Pago Principal.
- **Exportación:** Botón **`[📥 Exportar a Excel (.csv)]`** con BOM UTF-8 (`\uFEFF`) para abrir directamente en Microsoft Excel sin caracteres extraños.

#### Submódulo 2: Centro de Gestión de Respaldos en Disco (`backups/`)
- Muestra la lista física de copias de seguridad generadas en `mochilalista_admin/backups/`.
- **Política de Retención Automática (Últimos 30 Snapshots):** El motor (`DatabaseService` y `ConfigService`) aplica una política automática de retención que mantiene estrictamente los **30 snapshots automáticos más recientes** (`maxAutoSnapshots = 30`), purgando los excedentes más antiguos de forma desatendida tras cada modificación para evitar la saturación de disco.
- **Preservación Indefinida de Backups Manuales y Bóveda:** Cualquier archivo de respaldo que contenga `manual`, `vault`, `pre_restore` o `pre_import` está explícitamente blindado y **jamás es eliminado automáticamente**.
- **`[📸 Crear Snapshot Manual Ahora]`:** Guarda una copia atómica instantánea con marca de tiempo.
- **`[📂 Abrir Carpeta backups/ en Windows]`:** Abre la carpeta en el Explorador de Windows con 1 clic.
- **`[⬇️ Descargar]`:** Descarga el archivo JSON para resguardo en memoria USB.
- **`[⏪ Restaurar]`:** Revierte la base de datos a ese punto (generando antes un snapshot de seguridad del estado previo para evitar cualquier pérdida accidental).

---

### 1.8. Venta de Bolsas Extra de Escaneos IA (+150 escaneos)
Si un comerciante desea recargar su saldo de escaneos IA o agota su bolsa inicial y no desea configurar su clave BYOK:
1. El cliente te abona **S/ 20.00**.
2. En el Generador, selecciona al cliente y el plan **`BOLSA EXTRA IA (+150 escaneos) — S/ 20.00`**.
3. Presiona emitir y envíale el código o credencial.
4. Al canjearlo, su fecha de caducidad se mantiene intacta y se le suman **+150 escaneos acumulativos sin vencimiento** a su bolsa global.

---

### 1.9. Reasignación Técnica de Dispositivo por Cambio o Pérdida de Celular
1. Solicita al comerciante el nuevo Device ID que muestra su teléfono (`Perfil > Licencia`).
2. En Cartera de Clientes, presiona el botón **`[🔄]`** (Migrar Teléfono).
3. Ingresa el nuevo Device ID, la tarifa técnica (oficial: **S/ 40.00**; o S/ 0.00 en garantía) y el motivo.
4. Confirma la migración. El sistema archivará el teléfono anterior, actualizará el `current_device_id`, incrementará el `nonce` y te llevará al Generador para emitir la nueva licencia con el 100% de los días y créditos preservados.

---

### 1.10. Ficha 360° del Cliente y Gestión Integral (5 Pestañas Especializadas)
En **Cartera de Clientes**, presiona el botón **`[👁️]`** (Ficha 360°) o **`[🪟]`** (QR Directo) para abrir el Drawer lateral deslizable de alta precisión con sus 5 pestañas de control:

1. **Pestaña 1 — Resumen Ejecutivo:**
   - Métricas clave en tiempo real: Plan Actual, Vencimiento, Créditos IA Acumulados y Versión APK Instalada.
   - Resumen financiero de cobros acumulados y saldo pendiente.
   - **Botón `[📱 Sincronizar Estado Reportado del Celular]`:** Abre `#modalSyncReported` para registrar en caliente Hardware ID, modelo de teléfono, versión real instalada, saldo IA y días restantes reportados por el usuario mediante WhatsApp, sin requerir internet en la app móvil.

2. **Pestaña 2 — QR & Credencial Oficial:**
   - Visualización garantizada del código QR en alta definición mediante `renderSafeQrCode()` (resolviendo cualquier incompatibilidad con librerías QR).
   - **Selector Histórico de Licencias Emitidas:** Menú desplegable dinámico para alternar entre licencias anteriores y la más reciente, actualizando el QR y credencial al instante.
   - *Empty State* asistido para clientes sin licencias emitidas (ofreciendo botón directo de emisión para evitar códigos ficticios).
   - Botones rápidos: **`[Copiar Código]`**, **`[Descargar QR]`** y **`[WhatsApp]`** (conectado al Compositor Universal).

3. **Pestaña 3 — Pagos y Finanzas (CRUD Dinámico Completo):**
   - Historial detallado de pagos manuales y suscripciones del cliente.
   - **Registro de Nuevos Cobros:** Formulario en línea para ingresar monto en soles (`S/`), plan o concepto, medio de pago (Yape/Plin/BCP/Efectivo) y número de operación.
   - **Edición en Caliente:** Permite modificar montos, medios o referencias de cualquier pago previo.
   - **Eliminación Segura:** Borra pagos erróneos con recálculo automático instantáneo de los totales del cliente y del Dashboard.

4. **Pestaña 4 — Hardware y Dispositivos:**
   - Visualización del Hardware ID actual (`ANDROID_ID`) y modelo de celular reportado.
   - Tabla histórica de migraciones y cambios de equipo con fecha, hardware anterior, hardware nuevo, tarifa técnica aplicada y motivo registrado.
   - Botón directo **`[🔄 Migrar Teléfono]`** para reasignaciones técnicas inmediatas.

5. **Pestaña 5 — Edición Rápida y Zona de Peligro:**
   - Modificación directa de titular, negocio, teléfono, documento de identidad y notas comerciales.
   - **Zona de Peligro (`#drawerDangerZone`):** Botón **`[🗑️ Eliminar Cliente Definitivamente]`** con validación estricta de dos pasos para remover registros obsoletos con respaldo previo automático.

---

### 1.11. Centro de Personalización y Exportación a Libros Excel Multi-Hoja (`#tabSettings`)
En el Sidebar, accede a la pestaña **Ajustes / Personalización (`#tabSettings`)**:
1. **Edición en Caliente de `owner_config.json`:**
   - **Identidad Corporativa y Legal:** Nombre del Propietario (`Julio Angello Vasquez Navarro`), RUC/DNI, Sede Oficial y mención legal de INDECOPI / D.L. 822.
   - **Pasarelas de Cobro Perú:** Números y titulares oficiales para **Yape**, **Plin**, Transferencia Bancaria BCP/BBVA.
   - **Tarifario y Parámetros Comerciales:** Ajuste dinámico de precios (Suscripciones, Perpetuo, Migración de Celular, Bolsa Extra IA) y días por plan sin tocar una sola línea de código Dart ni reiniciar el servidor.
   - **Plantillas Reactivas de WhatsApp:** Personalización de los mensajes predeterminados para entrega de licencia, recordatorio de vencimiento y cotización de pase anual.
   - **Preferencia Visual:** Conmutador instantáneo entre Tema Oscuro (Dark Mode) y Tema Claro (Light Mode).
2. **Motor de Exportación a Libros Microsoft Excel Oficiales (`.xlsx`):**
   - Dispones de dos botones ejecutivos: **`[📥 Descargar Libro Excel Maestro (Completo)]`** y **`[📥 Descargar Libro Contable (Finanzas)]`**.
   - Los libros se generan con el formato profesional corporativo (`.xlsx` nativo):
     - **Hoja 1 (`Resumen Ejecutivo`):** Tarjetas de métricas, distribución de cartera e ingresos totales calculados con fórmulas reales de Excel (`SUM`).
     - **Hoja 2 (`Cartera CRM`):** Directorio exhaustivo con filtros automáticos, formato moneda (`S/ #,##0.00`) y fechas ISO legibles.
     - **Hoja 3 (`Libro de Pagos`):** Historial contable de transacciones, referencias de pago y totales computados en tiempo real.
     - **Hoja 4 (`Equipos y Licencias`):** Registro de firmas asimétricas Ed25519, nonces, días agregados y dispositivo destino.
     - **Hoja 5 (`Guia y Glosario`):** Guía de uso contable, glosario técnico de métricas y estados comerciales.

---

### 1.12. Bóveda de Seguridad, Persistencia y Multi-Llave (`#tabSecurityVault`)
En el Sidebar, accede a la pestaña **Seguridad & Bóveda (`#tabSecurityVault`)**:
1. **Tarjeta de Estado de Protección:**
   - Indica el estado de la sincronización espejo (`%APPDATA%\MochilaListaAdminVault\`), última fecha de sincronización, existencia de la clave maestra Ed25519 y estado del PIN de acceso.
2. **Asistente Guiado de Blindaje (3 Pasos):**
   - **Paso 1 (Espejo y Nube):** Fuerza la sincronización inmediata hacia la bóveda en `%APPDATA%` y permite enlazar una carpeta de nube personal (Google Drive, Dropbox, OneDrive).
   - **Paso 2 (Llave Criptográfica `.mlkey`):** Genera y descarga el archivo llave de recuperación de 256 bits para resguardar en una memoria USB o bóveda externa de contraseñas.
   - **Paso 3 (Kit de Emergencia Imprimible/PDF):** Despliega una hoja de alta seguridad lista para imprimir o guardar en PDF con **8 Códigos de Rescate unívocos (`ML-XXXX-YYYY-ZZZZ`)** y un código QR criptográfico vectorial.
3. **Bloqueo Local con PIN (`HTTP 423 Locked`):**
   - Permite establecer un PIN numérico de 4 a 8 dígitos para bloquear la interfaz administrativa cuando te alejes de la laptop.
   - Todas las llamadas al backend quedan bloqueadas con código `HTTP 423` hasta desbloquear con el PIN o el flujo de emergencia `"¿Olvidaste tu PIN?"`.
4. **Portabilidad Multi-PC en 1 Clic (`.mlvault`):**
   - **Exportar:** Empaqueta en un único archivo cifrado (`MochilaLista_Vault_Backup_...mlvault`) todas tus bases de datos, claves privadas y configuraciones con cifrado de sobre (AES-256-GCM).
   - **Importar / Mudar de PC:** Arrastra el archivo `.mlvault` en tu nueva laptop, ingresa tu factor de desbloqueo (llave `.mlkey`, código de rescate o PIN) y marca "Re-cifrar con DPAPI de esta PC". La nueva máquina queda lista para emitir licencias en 5 segundos.
5. **Auto-Recuperación en 1 Clic:**
   - Si por error eliminas la carpeta del proyecto o sufres una corrupción en `data/`, el sistema detecta automáticamente la bóveda espejo y te permite restaurar el 100% de tus datos con un solo clic.

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

### 2.3. Compilación del APK Release Universal (`compilar_apk_comercial.bat`)
Haz doble clic sobre:
```cmd
C:\Users\vjuli\Documents\mochilalista-app\compilar_apk_comercial.bat
```
El script ejecuta el análisis estático, compila con ofuscación completa (`--obfuscate --split-debug-info=build/app_symbols --dart-define=PRODUCTION=true`), calcula la huella criptográfica SHA-256 y genera:
- **Ruta:** `app_movil/build/app/outputs/flutter-apk/app-release.apk`
- **Uso:** Instalador universal compatible con todas las arquitecturas Android.

---

### 2.4. Compilación del APK Release Ligero ARM64 para WhatsApp (`compilar_apk_arm64.bat`)
Para clientes que solicitan un archivo ultraligero y rápido de transferir por WhatsApp (pesa solo **~25 a 35 MB** en comparación con los 114 MB del universal):
Haz doble clic sobre:
```cmd
C:\Users\vjuli\Documents\mochilalista-app\compilar_apk_arm64.bat
```
El script compila con `--split-per-abi`, ofuscación y símbolos debug protegidos, generando:
- **Ruta:** `app_movil/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- **Compatibilidad:** 99% de teléfonos Android modernos de 64 bits (Xiaomi, Samsung, Motorola, Realme, Honor).
- **Ventaja:** Transferencia instantánea sin límites de peso en WhatsApp.

---

### 2.5. Compilación del App Bundle para Google Play Store
```bash
cd C:\Users\vjuli\Documents\mochilalista-app\app_movil
flutter build appbundle --release --obfuscate --split-debug-info=build/app_symbols --dart-define=PRODUCTION=true
```
- **Ruta:** `app_movil/build/app/outputs/bundle/release/app-release.aab`

---

### 2.6. Auditoría Forense y Verificación de Firma con `apksigner`
```bash
apksigner verify --verbose C:\Users\vjuli\Documents\mochilalista-app\app_movil\build\app\outputs\flutter-apk\app-release.apk
```
Certifica que las firmas v1, v2 y v3 corresponden exclusivamente al certificado emitido a nombre de **Julio Angello Vasquez Navarro**.

---

## GUÍA 3: PUBLICACIÓN Y NOTIFICACIÓN DE ACTUALIZACIONES (RELEASE MANAGER)

### 3.1. Diferenciación Estricta: `HOTFIX` vs. `FEATURE_RELEASE`

| Categoría | Ejemplos | ¿Quién tiene derecho a instalarla? | Vigencia |
| :--- | :--- | :--- | :--- |
| **HOTFIX** (Estabilidad) | `9.23.1`, `9.24.1` | **TODOS los clientes**, tanto con suscripción como con **Licencia Perpetua vitalicia**. | **Vitalicio** (Garantía de software funcional). |
| **FEATURE_RELEASE** (Nuevas Funciones) | `9.24.0`, `10.0.0` | Clientes con **suscripción activa** o Licencia Perpetua con pase vigente (`updates_until`). | Requiere suscripción o Pase Anual de Updates (S/ 150.00). |

---

### 3.2. Carga Directa Drag & Drop de APKs y Autodetección 1-Clic
En la pestaña **Gestor de Versiones**, presiona **`[Subir / Registrar Nueva Versión]`**:
1. **Drag & Drop Directo:** Arrastra tu archivo `.apk` directamente a la zona punteada. El servidor calculará en tiempo real el SHA-256 y el tamaño en MB.
2. **Autodetección 1-Clic:** Presiona **`[Autodetectar APK de app_movil]`**. El sistema detectará automáticamente si existen `app-arm64-v8a-release.apk` o `app-release.apk`, mostrándote botones para elegir cuál importar con sus respectivos pesos y hashes.
3. Completa el tipo de lanzamiento (`FEATURE_RELEASE` o `HOTFIX`), el changelog de novedades y presiona **"Publicar Versión"**.

---

### 3.3. Acciones del Catálogo: Descarga Directa y Apertura en Carpeta de Windows
En la tabla de versiones publicadas:
- **`[⬇️ APK]`:** Descarga el binario directo desde el servidor local.
- **`[📂 Carpeta]`:** Invoca `explorer.exe /select,"<ruta_apk>"` en Windows para abrir la carpeta con el archivo resaltado listo para arrastrar a WhatsApp Web.
- **`[✏️]`:** Permite actualizar las notas de changelog o el tipo de lanzamiento.
- **`[🗑️]`:** Elimina el registro y el archivo en disco tras confirmación modal.

---

### 3.4. Matriz Inteligente de Distribución y Botón de Cortesía Excepcional
La matriz compara la versión instalada de cada cliente contra el último lanzamiento:
* **Clientes Elegibles:** Botones **`[📲 Enviar APK]`** (mensaje con enlace) y **`[✓ Marcar Actualizado]`**.
* **Clientes que Requieren Pase:** Botones **`[💳 Cotizar Pase]`** (cotización de S/ 150.00), **`[🔑 Emitir Pase]`** (redirección al Generador con el plan `PASE_ACTUALIZACION_ANUAL`) y el botón discreto:
  ```
  [🎁 Cortesía]
  ```
  Permite autorizar el envío de la nueva versión como excepción comercial gratuita si decides premiar la fidelidad del comerciante.

---

### 3.5. Comportamiento en la App Móvil: Snapshot `.bak` y Modal Post-Actualización
1. **Snapshot `.bak` Transparente:** La app crea una copia `mochilalista.db_pre_upgrade_vX.bak` antes de aplicar migraciones de esquema SQLite. Si ocurre un fallo eléctrico o de hardware durante la migración, la app restaura el `.bak` automáticamente sin perder ningún dato de venta o inventario.
2. **Modal Festivo Post-Actualización:** Tras iniciar la nueva versión, se despliega el modal no intrusivo con las novedades de la versión.

---

## GUÍA 4: PROTOCOLO DE RESPUESTA ANTE INCIDENTES Y SEGURIDAD ADVERSARIAL

### 4.1. Incidente: Pantalla de "Reloj Desajustado / Manipulación Temporal"
- **Causa:** El usuario retrasó la fecha de su celular o la batería llegó a 0% desconfigurando el reloj de hardware a 1970.
- **Solución:** Indicar al cliente que active **"Usar la hora proporcionada por la red"** y **"Zona horaria automática (GMT-5)"** en los ajustes de su teléfono. Al reabrir la app, se desbloquea de inmediato.

### 4.2. Incidente: Pantalla de "Licencia Pendiente de Migración" (Anti-Clonación)
- **Causa:** Un comerciante intentó restaurar un backup o clonar su base de datos en otro teléfono.
- **Solución:**
  * Si es un cliente legítimo que cambió de equipo: solicita su nuevo Device ID, ejecuta la **Reasignación de Dispositivo** (S/ 40.00 o garantía) y emítele su nuevo código.
  * Si es piratería: el teléfono receptor queda inoperable y debe comprar su propia licencia.

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
Al iniciar la plataforma por primera vez en tu laptop o al ingresar a la pestaña **Seguridad & Bóveda (`#tabSecurityVault`)**, ejecuta el **Asistente Guiado de Blindaje**:

```
[ PASO 1: Sincronizar Espejo Local / Nube ] ──> [ PASO 2: Descargar Llave .mlkey ] ──> [ PASO 3: Imprimir Kit de Emergencia PDF ]
```

1. **Paso 1: Sincronizar Espejo Local y Nube:**
   - Haz clic en **`[🔄 Sincronizar Bóveda Espejo Ahora]`**.
   - El sistema empaquetará todas las bases de datos de producción y la clave privada Ed25519 en `auto_mirror_latest.mlvault`, cifrándolo con DPAPI.
   - Si usas Google Drive o OneDrive, pega la ruta absoluta de tu carpeta de respaldo y pulsa Guardar.
2. **Paso 2: Descargar y Resguardar tu Archivo Llave (`.mlkey`):**
   - Presiona **`[⬇️ Descargar Llave Criptográfica (.mlkey)]`**.
   - El sistema descargará un archivo `llave_maestra_mochilalista.mlkey` que contiene el token criptográfico de 256 bits (`MLKEY:...`).
   - **Regla de Oro:** Copia este archivo en una **memoria USB física** y guárdala junto a tus documentos personales, o almacénalo en una bóveda de contraseñas (1Password, Bitwarden, KeePass).
3. **Paso 3: Imprimir o Guardar en PDF el Kit de Emergencia:**
   - Presiona **`[🖨️ Imprimir Kit de Emergencia]`**.
   - Se abrirá la vista de impresión optimizada (`@media print` sin márgenes, con diseño ejecutivo corporativo).
   - El documento contiene:
     - **8 Códigos de Rescate Unívocos:** Formateados en bloques legibles de alta visibilidad (`ML-XXXX-YYYY-ZZZZ`).
     - **Código QR Criptográfico Vectorial:** Permite escanear la llave maestra con la cámara o un lector óptico.
     - **Sellos Legales e Instrucciones Claras:** Protocolo paso a paso en caso de olvido de contraseña.
   - **Acción:** Imprime una copia física en papel y guárdala en un lugar seguro bajo llave, o imprímelo como "Guardar como PDF" y colócalo en un almacenamiento cifrado fuera de la PC.

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
