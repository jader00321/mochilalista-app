# PLAN MAESTRO 14: REINGENIERÍA UX DEL MODO ADMINISTRADOR, CRM COHERENTE OFFLINE-FIRST, FICHA 360°, GESTIÓN DE HARDWARE Y COMPOSITOR DE WHATSAPP

**Proyecto:** MochilaLista — Plataforma Administrativa Local (`mochilalista_admin/`, `http://localhost:8080`)  
**Autor y Titular de Derechos:** Julio Angello Vasquez Navarro  
**Fecha de Auditoría:** 20 de Noviembre de 2026  
**Versión:** 1.2 (Certificación Final de Cierre)  
**Entorno Operativo:** Windows 10/11 x64, Dart SDK 3.x, HTML5/ES6/CSS3 Nativo (Zero CDNs externos)  
**Estado:** 100% COMPLETADO Y CERTIFICADO (Fases 1 a 7 Cerradas Exitosamente)

---

## 1. RESUMEN EJECUTIVO Y AUTOPSIA FORENSE DE CAUSAS RAÍZ

A partir de la ronda exhaustiva de pruebas reales y las 6 capturas de pantalla suministradas, se procedió a realizar una **auditoría forense estricta línea por línea** sobre el código fuente de `mochilalista_admin/` (`web/index.html`, `web/js/admin_app.js`, `web/css/styles.css`, `server.dart`, `lib/database_service.dart`, `lib/config_service.dart`, e `Iniciar_MochilaLista_Admin.bat`).

Esta auditoría descubrió que múltiples anomalías críticas reportadas derivan de **excepciones no capturadas en JavaScript**, **comparaciones léxicas en lugar de SemVer**, **clases CSS huérfanas en el DOM** y una **desalineación conceptual entre el CRM centralizado y la naturaleza 100% Offline-First de la aplicación móvil**.

### Hallazgos Forenses Críticos:

1. **El 2.º botón de ACCIONES CLAVE roto, el Cuadrado Blanco en QR y la apertura de `localhost:8080` al pulsar WhatsApp:**
   * **Causa Raíz Común:** En `mochilalista_admin/web/js/qrcode.min.js`, el objeto `QRCode.CorrectLevel` **NO EXISTE** (la librería interna usa índices numéricos directos `0, 1, 2, 3` o valores por defecto). 
   * En `admin_app.js` (líneas 1184, 1474 y 1735), se ejecuta:
     ```javascript
     correctLevel: QRCode.CorrectLevel.M
     ```
   * Al ejecutarse esto, JavaScript lanza inmediatamente:
     ```
     TypeError: Cannot read properties of undefined (reading 'M')
     ```
   * **Impacto en el 2.º botón de Cartera CRM (`openQuickQrModal`):** El error ocurre en la línea 1474, impidiendo que el código llegue a la línea 1564 (`openModal('modalQuickQr')`). Por ello, al hacer clic en el botón azul con ícono de cuadrícula/QR, **la consola muere y no ocurre absolutamente nada**.
   * **Impacto en la Ficha 360° (`openClient360Drawer`):** La llamada a `new QRCode` en la línea 1735 está dentro del bloque `try { ... }` que procesa el historial. Justo antes (línea 1728) se ejecutó `qrBox.innerHTML = ''`. Al estallar la excepción en la línea 1735, se aborta el dibujo del QR y la caja queda como un **cuadrado blanco completamente vacío**.
   * **Impacto en el botón de WhatsApp de la Ficha 360°:** Dado que la excepción ocurre en la línea 1735, la línea 1760 (`btnDrawerSendWa.href = waUrl`) **nunca se ejecuta**. En `web/index.html` (línea 2357), el botón tiene `href="#"` y `target="_blank"`. En cualquier navegador moderno, hacer clic en un enlace `<a href="#" target="_blank">` abre una **nueva pestaña navegando a `http://localhost:8080/#`**, recargando la plataforma en lugar de WhatsApp.

2. **Falso token `ML9-PENDIENTE-ML-B0F8` en clientes sin licencia:**
   * En `admin_app.js` (línea 1724): Si el cliente es nuevo o Trial y no tiene licencias Ed25519 emitidas en `generated_codes_history`, el código fabrica artificialmente el string `ML9-PENDIENTE-${client.current_device_id}` e intenta dibujarlo como si fuera un token válido, engañando al usuario y rompiendo el flujo.

3. **Inconsistencia de Migraciones en la Ficha 360° (`Hardware` siempre dice "Sin migraciones"):**
   * En `admin_app.js` (línea 1764), el frontend busca:
     ```javascript
     if (history.hardware && history.hardware.length > 0)
     ```
   * Sin embargo, en `lib/database_service.dart` (línea 890), el backend expone:
     ```dart
     'device_history': devices
     ```
   * `history.hardware` es siempre `undefined`, por lo que la tabla de hardware jamás muestra el historial real de migraciones de equipos.

4. **Bug SemVer de Versiones APK (`v9.31.0` marcado como "Update pend." vs `v9.30.0` como "Al día"):**
   * En `admin_app.js` (líneas 749 y 798) y en `server.dart` (línea 544), la verificación es una simple desigualdad de cadenas:
     ```javascript
     const isOutdated = (c.installed_version || '') !== latestVer;
     ```
   * Si la última versión publicada en el Gestor de Versiones es `9.30.0`:
     * Un cliente con `9.30.0` da `9.30.0 !== 9.30.0` (falso) $\rightarrow$ Badge **"Al día"**.
     * Un cliente con `9.31.0` (versión más nueva) da `9.31.0 !== 9.30.0` (verdadero) $\rightarrow$ Badge **"Update pend."**.
   * No existe un comparador semántico de versiones (SemVer). Cualquier versión no exactamente idéntica se marca erróneamente como desactualizada.

5. **Conmutador de Modo Dual sin contraste visual y con estado residual:**
   * En `web/css/styles.css` (líneas 860 y 867), los estilos activos están condicionados a:
     ```css
     .mode-btn.active.mode-sandbox { ... }
     .mode-btn.active.mode-prod { ... }
     ```
   * Pero en `web/index.html` (líneas 119 y 123) y en `admin_app.js` (líneas 348 y 353), los botones solo tienen la clase `mode-btn` y se les agrega `.active`, **sin agregar jamás las clases `.mode-sandbox` ni `.mode-prod`**.
   * Por tanto, los selectores CSS jamás coinciden. Ambos botones lucen visualmente idénticos e inactivos, con dos puntos de color encendidos simultáneamente sin feedback claro.
   * Además, `switchMode()` no cierra drawers ni modales del modo anterior, ni limpia filtros/selecciones activas, manteniendo datos obsoletos en pantalla.

6. **Sidebar Colapsable roto y desalineado:**
   * En `web/css/styles.css` (líneas 71-85), `.app-sidebar.collapsed` fuerza un ancho de `68px`. Pero `.sidebar-header` tiene `padding: 1.15rem 1rem` (32px de padding horizontal) + `.brand-logo-icon` (36px) + `.btn-toggle-sidebar` (28px) = **96px necesarios**. Los elementos se superponen y se recortan contra el borde izquierdo.
   * No existen reglas CSS para ocultar o estilizar `.sidebar-group-label` al colapsar, dejando textos recortados o espacios vacíos. No hay tooltips flotantes en el menú colapsado.

7. **Desalineación Offline-First en el Registro de Clientes y Créditos IA:**
   * En `database_service.dart` (`createClient`, líneas 220-265) y en `admin_app.js` (`handleCreateClient`, líneas 3044-3074):
     * El `Hardware ID` es estrictamente obligatorio para registrar a cualquier contacto. Esto impide registrar prospectos comerciales que aún no han instalado la app.
     * Al crear un cliente Trial, se le asigna ciegamente `updates_until = now + 365 días`, lo cual carece de sentido comercial para un periodo de prueba.
     * Al ingresar "Créditos IA Extra", se guardan en la base de datos de administración como si el cliente ya los tuviera. En una arquitectura 100% Offline-First, **el teléfono móvil desconoce completamente lo que se escribe en el admin web**. Los créditos y días solo ingresan al celular mediante el canje criptográfico de un token Ed25519 (`ML9-...`).
     * Los números telefónicos se guardan sin normalización internacional (+51), generando URLs rotas para WhatsApp.

---

## 2. ARQUITECTURA DE LOS 7 PILARES OBLIGATORIOS

```
┌───────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                           MOCHILALISTA ADMIN — REINGENIERÍA MAESTRA (FASES 1 - 7)                     │
├───────────────────────────────────────┬───────────────────────────────────────────────────────────────┤
│ PILAR 1: Conmutador Sandbox ↔ Prod    │ • Selector píldora animado con alto contraste (Ámbar vs Verde)│
│                                       │ • Recarga global atómica, cierre de drawers y cabecera reactiva│
├───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ PILAR 2: Sidebar & Dashboard          │ • Header colapsable centrado, divisores y tooltips flotantes  │
│                                       │ • Grilla 4+4 simétrica, dona con todos los planes y S/ .00   │
├───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ PILAR 3: Coherencia CRM Offline-First │ • Estados reales: Prospecto (ID opcional), Trial y Licenciado │
│                                       │ • Saldo IA informativo vs Bono pendiente en token Ed25519     │
│                                       │ • Normalización estricta WhatsApp Perú (+51)                  │
├───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ PILAR 4: Cartera CRM & WhatsApp       │ • Comparador SemVer robusto (v9.31 >= v9.30 -> Al día)       │
│                                       │ • Acciones clave en 1 fila + 2.º botón abre Ficha en tab QR   │
│                                       │ • Modal Compositor Universal con plantillas dinámicas         │
├───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ PILAR 5: Ficha 360° Profunda          │ • QR reparado (sin crash CorrectLevel), Empty State elegante │
│                                       │ • Historial de licencias Ed25519 emitidas con selector        │
│                                       │ • CRUD dinámico de pagos manuales + Hardware con device model │
├───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ PILAR 6: Modo Escritorio en 1 Clic    │ • msedge/chrome --app=http://localhost:8080 (sin barras)      │
│                                       │ • Acceso directo en Escritorio con app_icon.ico oficial       │
├───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ PILAR 7: Certificación Automatizada   │ • Test suite integral en Dart/Node (sin tocar datos reales)  │
│                                       │ • dart analyze, dart test y node --check 100% en verde        │
└───────────────────────────────────────┴───────────────────────────────────────────────────────────────┘
```

---

## 3. PLAN DE TRABAJO EN FASES SECUENCIALES

### FASE 1: Conmutador de Entorno Dual Sandbox ↔ Producción (Sincronización Total Atómica + Rediseño Visual Inequívoco)
* **Archivos Implicados:**
  * `mochilalista_admin/web/index.html` (Header, selector de modo y banner)
  * `mochilalista_admin/web/css/styles.css` (Animaciones, píldora deslizante, colores semánticos, franja superior)
  * `mochilalista_admin/web/js/admin_app.js` (`switchMode`, `updateModeUI`, inyección de cabecera `X-App-Mode`)
  * `mochilalista_admin/server.dart` (Soporte dual seguro `/api/system/mode` y `/api/mode`)
* **Diagnóstico y Solución Detallada:**
  1. **Rediseño Visual del Selector de Modo:**
     * Reestructurar el contenedor `.mode-switcher` para que funcione como un control segmentado con botón deslizante (`sliding active pill`) con `transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1)`.
     * Asignar clases semánticas explícitas: `.mode-sandbox` y `.mode-prod`.
     * Cuando `Modo Pruebas` esté activo: Fondo ámbar suave con borde brillante (`#f59e0b`), texto ámbar brillante y punto ámbar con efecto pulsante (`box-shadow: 0 0 8px #f59e0b`). El botón de Modo Real se muestra apagado/atenuado con opacidad `0.45` y punto apagado.
     * Cuando `Modo Real` esté activo: Fondo esmeralda suave (`#10b981`), texto y punto verde esmeralda brillante (`box-shadow: 0 0 8px #10b981`). El botón de Modo Pruebas se atenúa con opacidad `0.45`.
     * Incorporar una sutil franja de advertencia en el borde superior de la cabecera (`border-top: 3px solid #f59e0b`) cuando se esté en `sandbox`, indicando claramente que los cambios no afectan la producción, y cambiar a un acento esmeralda sutil o neutro limpio en `prod`.
     * Compatibilidad plena con Tema Oscuro y Tema Claro garantizando legibilidad y alto contraste.
  2. **Recarga Global Atómica:**
     * En `switchMode(newMode)`:
       * Guard anti-doble-clic (`_isSwitchingMode`) con bloqueo temporal y cursor de espera.
       * Cerrar de inmediato cualquier drawer lateral abierto (`closeClient360Drawer()`).
       * Cerrar cualquier modal abierto (`modalQuickQr`, `modalEditClient`, `modalManualPayment`, `modalCreateClient`).
       * Resetear variables de cliente activo (`currentDrawerClientId = null`, `currentQuickQrClientId = null`, `currentHistoryClientId = null`).
       * Limpiar el término de búsqueda (`currentSearchQuery = ''`) y restablecer los filtros de clientes a `'all'`.
       * Coordinación estricta con el backend: invocar `POST /api/system/mode` (y alias `POST /api/mode`), esperar la confirmación HTTP 200 con `{ ok: true, mode: targetMode }` antes de disparar peticiones subsiguientes.
       * Enviar la cabecera `X-App-Mode: <mode>` en todas las llamadas fetch del frontend.
       * Invocar de forma coordinada: `await loadDashboard()`, `await loadClients()`, `await loadReleases()`, `await loadFinances()`, `await loadBackups()`.
       * Comportamiento ultra-limpio ante `0` registros en `prod`: los selectores (ej. desplegable del Generador de Licencias) muestran su estado vacío (`-- Elige un cliente --`), las tablas muestran su empty-state sin excepciones en consola y los contadores KPI muestran `0` o `S/ 0.00`.
       * Re-renderizar la vista activa actual y actualizar dinámicamente el subtítulo dedicado en la tarjeta `CLIENTES ACTIVOS` (`kpiActiveClientsSubtitle`: *"En pruebas (Sandbox)"* vs *"En producción (Real)"*).
       * Mostrar un toast claro de notificación de entorno (`Entorno activo: Modo Real (Producción)` o `Modo Pruebas (Sandbox)`).

---

### FASE 2: Rediseño del Panel Lateral (`Sidebar`) Retraído y Perfeccionamiento del Dashboard Ejecutivo
* **Archivos Implicados:**
  * `mochilalista_admin/web/index.html` (Estructura de sidebar, grilla de KPIs 4+4, nuevo KPI de Prospectos)
  * `mochilalista_admin/web/css/styles.css` (Transiciones del sidebar, tooltips flotantes en hover, grilla simétrica)
  * `mochilalista_admin/web/js/admin_app.js` (`renderPlanDistributionChart`, `renderMonthlyRevenueChart`, persistencia visual `localStorage`)
* **Diagnóstico y Solución Detallada:**
  1. **Sidebar Retraído Profesional y Animado:**
     * Corregir el layout de `.sidebar-header` en estado colapsado: ocultar por completo el bloque `.sidebar-brand-text`, reducir padding a `0.5rem`, centrar el isotipo `.brand-logo-icon` y ubicar el botón de expandir de forma equilibrada sin recortar el isotipo.
     * En `.app-sidebar.collapsed .sidebar-group-label`, ocultar el texto y renderizar en su lugar un divisor sutil (`height: 1px; background: var(--border-color); margin: 0.5rem 0.25rem;`).
     * Implementar **tooltips flotantes CSS** en estado colapsado (`[data-tooltip]` o micro-popups flotantes). **Precisión preventiva:** Para evitar cualquier recorte ocasionado por `overflow: hidden` o `overflow-y: auto` en `.app-sidebar` y `.sidebar-body`, los tooltips deben posicionarse de forma absoluta o fixed fuera del contenedor con `z-index: 1000`, fondo oscuro translúcido con borde, flecha indicadora y `pointer-events: none`.
     * Guardar en `localStorage.getItem('ml_admin_sidebar_collapsed')` el estado visual del sidebar para que se mantenga al recargar la página.
  2. **Grilla de KPIs Balanceada (4 + 4):**
     * Reorganizar la grilla de KPIs del Dashboard en dos filas de 4 tarjetas perfectamente simétricas:
       * **Fila 1 (Finanzas y Cartera Comercial):**
         1. `INGRESOS DEL MES (S/)` (Monto con 2 decimales exactos).
         2. `INGRESOS TOTALES (S/)` (Histórico cobrado consolidado).
         3. `CLIENTES ACTIVOS` (Subtítulo dinámico según Sandbox/Producción).
         4. `PROSPECTOS / POR SUSCRIBIR` (Nuevo 8.º KPI con contador de clientes en prospección).
       * **Fila 2 (Operaciones y Salud del Parque):**
         5. `POR VENCER (≤ 7 DÍAS)` (Alerta preventiva de renovación).
         6. `LICENCIAS VENCIDAS` (Bloqueo activo por regularizar).
         7. `LICENCIAS PERPETUAS` (Licencias de por vida liberadas).
         8. `APK DESACTUALIZADO` (Clientes con versión inferior a la última publicada).
     * Convertir las tarjetas KPI en accesos directos clicables: al hacer clic en `APK DESACTUALIZADO`, saltar de inmediato a la pestaña Cartera CRM con el filtro preseleccionado `outdated`; al hacer clic en `POR VENCER`, saltar con filtro `expiring`; al hacer clic en `PROSPECTOS`, saltar con filtro `prospect`.
  3. **Corrección del Gráfico de Dona y Consistencia de Decimales:**
     * En `renderPlanDistributionChart`: Ampliar el catálogo de conteo para incluir de forma nativa:
       * `MENSUAL`, `TRIMESTRAL`, `SEMESTRAL`, `ANUAL`, `PERPETUO`, `TRIAL`, `EXTENSION_CORTESIA` (Cortesía) y `PROSPECTO`.
       * Eliminar la caída por defecto en `TRIAL` para cualquier plan no reconocido. Si es `EXTENSION_CORTESIA`, asignarle su color semántico (ámbar/dorado) y etiqueta *"Cortesía"*.
     * En `renderMonthlyRevenueChart`: Reemplazar `Math.round(m.total)` por `m.total.toFixed(2)` tanto en la etiqueta sobre la barra como en el tooltip SVG, eliminando la discrepancia entre `S/ 35` del gráfico y `S/ 35.10` de la tarjeta KPI.

---

### FASE 3: Coherencia de Modelo de Negocio 100% Offline-First (Registro de Clientes, Prospectos, Trials Reales y Créditos IA)
* **Archivos Implicados:**
  * `mochilalista_admin/lib/database_service.dart` (`createClient`, `updateClient`, esquema JSON)
  * `mochilalista_admin/web/index.html` (Modal `modalCreateClient` rediseñado)
  * `mochilalista_admin/web/js/admin_app.js` (`handleCreateClient`, validaciones de teléfono, normalización)
* **Diagnóstico y Solución Detallada:**
  1. **Tres Estados Iniciales Coherentes con la App Offline:**
     * **`PROSPECTO / POR SUSCRIBIR`:**
       * El `Hardware ID` pasa a ser **opcional** (si no se tiene, se guarda como `PENDIENTE`).
       * Permite ingresar una fecha estimada de seguimiento y notas comerciales.
       * Su estado visual es `Prospecto` (badge gris azulado), y **no** suma al contador de `Clientes Activos`.
     * **`TRIAL EN EVALUACIÓN (App ya instalada)`:**
       * Campo para indicar los **días reales restantes** que el cliente ve en su teléfono (ej. 14 días) o la fecha real en que instaló la app, en lugar de forzar arbitrariamente 30 días desde hoy.
       * No se le asigna `updates_until` de licencia comercial (se almacena como `null` o vacío).
       * Su estado visual es `Trial (Xd rest.)`.
     * **`CON LICENCIA ACTIVA / MIGRACIÓN`:**
       * Requiere `Hardware ID` obligatorio para regularizar a un cliente que ya pagó o para migrarlo con token Ed25519.
  2. **Compatibilidad Total hacia Atrás y Cero Regresiones en Suites:**
     * **Precisión preventiva:** Todos los cambios en `database_service.dart` deben mantener compatibilidad total con registros JSON existentes (donde `ai_extra_credits` o `current_device_id` ya existen) y con las suites automatizadas actuales (`database_service_test.dart`, `excel_export_test.dart`), usando valores por defecto seguros (`?? 0`, `?? 'ML-0000'`, `?? 'PROSPECTO'`).
  3. **Transparencia en Créditos IA Offline:**
     * Separar en el modelo de datos:
       * `ai_reported_balance`: Saldo informativo que el cliente indica tener en su teléfono móvil.
       * `ai_pending_bonus`: Créditos adicionales acordados en administración que **aún no se han entregado en un token Ed25519**.
     * Si en el modal se ingresan créditos extra sin emitir la licencia en el acto, mostrar una advertencia contextual:
       > *"Los créditos ingresados aquí son informativos. El celular del cliente solo recibirá los créditos cuando emitas y canjees un código Ed25519 (ML9-...). Pulsa 'Guardar y Emitir Licencia' si deseas entregárselos ahora."*
     * Si hay un bono pendiente, mostrar un indicador visual en CRM (`+50 IA por entregar en token`).
  4. **Normalización Automática de WhatsApp Perú (`+51`):**
     * Función utilitaria de sanitización telefónica: elimina espacios, guiones y paréntesis.
     * Si el número tiene 9 dígitos e inicia con `9` (ej. `922836879`), se normaliza automáticamente a `+51922836879`.
     * Todas las URLs de WhatsApp en el sistema se construirán a través del formato oficial `https://wa.me/51<numero>` para garantizar compatibilidad universal con WhatsApp Web y WhatsApp Desktop.
  5. **Sincronización Rápida de Datos Reportados:**
     * En la Ficha 360°, agregar una acción rápida *"Sincronizar datos reportados del celular"*, permitiendo al administrador actualizar en 1 clic los días que el cliente dice tener en pantalla, su saldo de créditos IA y la versión APK que tiene instalada.

---

### FASE 4: Cartera CRM, SemVer Comparador, Alineación de Acciones Clave y Compositor Universal de WhatsApp
* **Archivos Implicados:**
  * `mochilalista_admin/web/js/admin_app.js` (`renderClientsTable`, comparador SemVer, compositor de WhatsApp)
  * `mochilalista_admin/web/index.html` (Modal compositor de WhatsApp, estructura de tabla CRM)
  * `mochilalista_admin/web/css/styles.css` (Alineación de 4 botones en 1 sola fila horizontal, anchos de columna)
  * `mochilalista_admin/server.dart` (Endpoint `/api/dashboard`, comparador SemVer en backend)
* **Diagnóstico y Solución Detallada:**
  1. **Comparador SemVer Riguroso (Frontend y Backend):**
     * Implementar la función `compareSemVer(v1, v2)`:
       * Extrae los componentes numéricos `major.minor.patch` (y descarta o compara el build code `+XX`).
       * **Precisión preventiva:** Si en el Gestor de Versiones hay `0` versiones publicadas (`latestRelease == null` o vacío), el comparador **no** marcará falsamente `Update pend.` a ningún cliente; se mantendrá en `Al día` o indicará estado neutral `vX.Y.Z`.
       * Si `vInstalled >= vLatestRelease`, el cliente está **`Al día`** (`badge-green`).
       * Únicamente si `vInstalled < vLatestRelease`, el cliente se marca como **`Update pend.`** (`badge-yellow`).
       * Casos validados: `9.31.0` frente a `9.30.0` dará `Al día`. `9.30.0` frente a `9.30.0` dará `Al día`. `9.24.0` frente a `9.30.0` dará `Update pend.`.
     * Aplicar esta misma lógica en `server.dart` al calcular el contador `outdatedAppCount` del Dashboard.
  2. **Reparación del 2.º Botón de ACCIONES CLAVE:**
     * Modificar la acción del botón de cuadrícula/QR en `renderClientsTable`:
       * En lugar de llamar a `openQuickQrModal` (que sufría la excepción de `QRCode.CorrectLevel`), redirigir directamente a `openClient360Drawer(clientId, 'drawerTabQr')`.
       * Esta función abrirá la Ficha 360° posicionada de inmediato en la pestaña **`QR & Credencial`**, con el QR nítidamente dibujado y todos los controles operativos.
  3. **Alineación de Tabla y Anchos (Cero Envoltura):**
     * En la columna ID: aplicar `white-space: nowrap;` para impedir que `CLI-001` se parta en dos líneas.
     * En `.crm-actions-cell`: establecer `flex-wrap: nowrap; min-width: 165px; gap: 0.4rem;`.
     * Los 4 botones quedan alineados en una sola fila horizontal limpia con tooltips descriptivos:
       1. `Ver Ficha 360°` (Ícono ojo).
       2. `Ver QR & Credencial` (Ícono QR/cuadrícula).
       3. `Enviar WhatsApp` (Ícono WhatsApp con compositor).
       4. `Emitir Licencia` (Ícono rayo).
  4. **Modal Compositor Inteligente de WhatsApp (`modalWaComposer`):**
     * Crear un modal modular y reutilizable, accesible desde Cartera CRM, Dashboard Urgencias y Ficha 360°.
     * **Plantillas preconfiguradas seleccionables en 1 clic:**
       1. *Saludo y Bienvenida* (para nuevos clientes o prospectos).
       2. *Recordatorio de Renovación Preventiva* (para licencias por vencer).
       3. *Seguimiento a Prospecto* (consulta sobre evaluación de la app).
       4. *Entrega Oficial de Licencia / Credencial* (con código `ML9-...`, vigencia y créditos IA).
       5. *Aviso de Actualización de APK* (con enlace directo o aviso de descarga).
       6. *Chat Vacío* (abre conversación sin texto predeterminado).
     * **Sustitución dinámica de variables:** `{negocio}`, `{titular}`, `{plan}`, `{dias_restantes}`, `{vencimiento}`, `{device_id}`, `{version}`, `{codigo_licencia}`.
     * **Área de texto libre editable:** Permite modificar o agregar cualquier detalle antes del envío.
     * **Botonera de salida:** Botón *"Copiar Mensaje"* (al portapapeles) y botón *"Abrir en WhatsApp"* (`https://wa.me/51<telefono>?text=<encodeURIComponent>` con `rel="noopener noreferrer"` y `target="_blank"`).

---

### FASE 5: Reingeniería Profunda de la Ficha Lateral 360° (QR & Credencial, Pagos Dinámicos, Hardware, Resumen y Edición Completa)
* **Archivos Implicados:**
  * `mochilalista_admin/web/index.html` (Drawer lateral con sus 5 pestañas completas)
  * `mochilalista_admin/web/js/admin_app.js` (`openClient360Drawer`, manejo de tabs, llamadas a API)
  * `mochilalista_admin/web/css/styles.css` (Estilos de drawer, cajas QR, botones vectoriales)
  * `mochilalista_admin/server.dart` (Endpoints para CRUD dinámico de pagos manuales)
  * `mochilalista_admin/lib/database_service.dart` (CRUD de pagos, compatibilidad de campos)
* **Diagnóstico y Solución Detallada:**
  1. **Pestaña `QR & Credencial`:**
     * **Eliminación del crash `QRCode.CorrectLevel` en 3 puntos críticos:** Inspeccionar el contrato real de `qrcode.min.js` y reemplazar las 3 ocurrencias (Líneas 1184, 1474 y 1735 de `admin_app.js`) por el entero numérico nativo de la librería (`correctLevel: 1` para nivel M o `correctLevel: 2` para H) o eliminar la clave para usar el fallback interno seguro.
     * **Manejo de Estados:**
       * Si el cliente es un Prospecto o Trial sin licencias Ed25519 emitidas: **NO** mostrar el cuadrado blanco ni inventar `ML9-PENDIENTE-...`. Mostrar un **Empty State elegante**:
         > Icono SVG de credencial: *"Este cliente aún no cuenta con licencias Ed25519 emitidas."*  
         > [ Botón: `Emitir Primera Licencia` ]
       * Si el cliente tiene licencias emitidas: renderizar el QR de la última licencia emitida y ofrecer un selector desplegable para revisar licencias anteriores del histórico.
     * **Botonera Vectorial sin Emojis Crudos:**
       * Fija el estándar estricto de **cero emojis crudos** (eliminar `📦`, `📲`), sustituyéndolos por iconos vectoriales SVG limpios e interactivos para: `Copiar Código`, `Descargar Tarjeta PNG @2x`, `Descargar Solo QR`, `Auditar en Inspector`, y `WhatsApp` (que abrirá el nuevo Compositor con los datos de la licencia precargados).
  2. **Pestaña `Pagos`:**
     * Barra de KPI financiero propio del cliente: Total acumulado cobrado (`S/`), cantidad de pagos, fecha del último cobro y medio preferido.
     * Tabla con historial completo (Fecha, Concepto, Monto `S/`, Método, Referencia).
     * Soporte completo para:
       * **Registrar Pago Manual** (con modal modalManualPayment).
       * **Editar Pago Existente** (permite ajustar monto, método o referencia).
       * **Anular / Eliminar Pago** (con confirmación de seguridad y recálculo automático del total del cliente y del Dashboard).
  3. **Pestaña `Hardware`:**
     * Tarjeta de dispositivo actual: Hardware ID con botón de copia en 1 clic, campo editable para **Modelo de Celular** (ej. *Samsung Galaxy A54 5G*), Versión APK instalada con indicador SemVer, Nonce actual y fecha de vinculación.
     * **Corrección del historial de migraciones:** En `admin_app.js`, leer `history.device_history || history.hardware || []`, permitiendo visualizar correctamente cada cambio de equipo previo con fecha, ID anterior, ID nuevo, tarifa cobrada y motivo.
     * Botón destacado `Migrar / Reasignar Teléfono` completamente operativo.
  4. **Pestaña `Resumen`:**
     * Ocultar la métrica `VENTANA UPDATES` si el cliente es Trial o Prospecto; mostrarla únicamente en planes Perpetuos o Pases de Actualización.
     * Botones de acción rápida: `Enviar WhatsApp`, `Sincronizar Estado Real`, `Emitir Renovación`.
  5. **Pestaña `Edición Rápida` (y Control Total):**
     * Formulario completo para editar datos comerciales, sincronizar estado/plan, fecha real de vencimiento, saldo IA reportado y ventana de updates.
     * **Zona de Peligro:** Botón protegido para eliminar cliente con modal de doble confirmación y creación previa de snapshot de respaldo.

---

### FASE 6: Acceso de Escritorio Profesional en 1 Clic (Modo App Nativa de Ventana + Ícono Oficial)
* **Archivos Implicados:**
  * `Iniciar_MochilaLista_Admin.bat` (Lanzador en la raíz del proyecto)
  * `Crear_Acceso_Directo_Escritorio.ps1` (Nuevo script de creación de acceso directo)
  * `mochilalista_admin/web/favicon.ico` / `app_icon.ico` (Copia del ícono oficial)
* **Diagnóstico y Solución Detallada:**
  1. **Apertura en Modo Aplicación de Escritorio (`--app`):**
     * Actualizar `Iniciar_MochilaLista_Admin.bat` para que, en lugar de abrir una pestaña común de navegador (`start "" http://localhost:8080`), detecte Microsoft Edge o Google Chrome y ejecute:
       ```cmd
       start msedge.exe --app=http://localhost:8080
       ```
       o con fallback a Chrome:
       ```cmd
       start chrome.exe --app=http://localhost:8080
       ```
       o con fallback al navegador predeterminado si ninguno está disponible.
     * Esto proporciona una ventana limpia e independiente, sin barra de direcciones, sin pestañas y con el nombre e ícono de MochilaLista Admin, comportándose exactamente como una aplicación nativa de escritorio.
  2. **Acceso Directo Automatizado en el Escritorio (Compatible con OneDrive):**
     * Desarrollar `Crear_Acceso_Directo_Escritorio.ps1` que genere un acceso directo en el Escritorio del usuario utilizando `[Environment]::GetFolderPath('Desktop')` (garantizando compatibilidad total ante carpetas redirigidas por Microsoft OneDrive).
     * Asignar el ícono oficial desde `app_movil/windows/runner/resources/app_icon.ico`, verificando que corresponda al logotipo oficial de MochilaLista y no al genérico de Flutter.
     * Apuntar el acceso directo al lanzador por lotes con ventana minimizada (`WindowStyle = 7`).

---

### FASE 7: Certificación Automatizada y Cero Regresiones (`mochilalista_admin/`)
* **Archivos Implicados:**
  * `mochilalista_admin/test/ux_crm_mode_offline_whatsapp_test.dart` (Nueva suite de pruebas automatizadas)
  * Suites existentes en `mochilalista_admin/test/`
* **Diagnóstico y Solución Detallada:**
  1. **Suite de Pruebas Automatizadas en Directorio Temporal:**
     * Crear pruebas en `Directory.systemTemp` (garantizando **cero impacto** sobre `data/prod_*` y `private_keys/`).
     * Validar:
       * Conmutación limpia de modo (`sandbox` ↔ `prod`) y persistencia independiente.
       * Comparador SemVer con matriz exhaustiva (`9.31.0` vs `9.30.0` = al día; `9.30.0` vs `9.30.0` = al día; `9.24.0` vs `9.30.0` = pendiente).
       * Creación de prospecto con `Hardware ID` opcional y estado `PROSPECTO`.
       * CRUD completo de pagos manuales (creación, edición, eliminación y recálculo).
       * Conteo en dona para todos los planes (incluyendo `EXTENSION_CORTESIA`).
  2. **Validación Sintáctica y Estática:**
     * Ejecutar `node --check mochilalista_admin/web/js/admin_app.js` para asegurar ausencia de errores de sintaxis en JavaScript.
     * Ejecutar `dart analyze mochilalista_admin/` asegurando 0 advertencias o errores.
     * Ejecutar `dart test` en `mochilalista_admin/` garantizando que los 60 tests existentes y los nuevos pasen 100% en verde.

---

## 4. MATRIZ DE CRITERIOS DE ACEPTACIÓN POR FASE

| Fase | Entregable Clave | Criterio de Aceptación Verificable |
| :--- | :--- | :--- |
| **Fase 1** | Conmutador de Modo | La píldora cambia visualmente con fluidez entre Ámbar (Sandbox) y Verde Esmeralda (Prod). Se cierran drawers y modales al conmutar. KPIs y filtros se actualizan sin datos residuales. |
| **Fase 2** | Sidebar & Dashboard | Al colapsar el sidebar, el logo e ícono quedan perfectamente centrados sin superposición ni textos recortados. Aparecen tooltips al pasar el mouse. Los KPIs se distribuyen en 4+4 simétrico. La dona clasifica `EXTENSION_CORTESIA` como Cortesía y los montos muestran 2 decimales coherentes (`S/ 35.10`). |
| **Fase 3** | Registro Offline-First | Se puede registrar un Prospecto sin obligar a ingresar Hardware ID. Al registrar Trial, se pueden indicar los días reales restantes del celular sin asignar falsamente updates de licencia perpetua. Teléfonos peruanos se normalizan a `+51`. Aviso claro sobre sincronización offline de créditos IA. |
| **Fase 4** | CRM, SemVer & WhatsApp | `CLI-003` (`v9.31.0`) se muestra como `Al día`. Los 4 botones de acciones clave se alinean en una sola fila sin partirse. El 2.º botón abre la Ficha 360° en la pestaña QR. Al pulsar WhatsApp se abre el nuevo Compositor con plantillas predefinidas dinámicas y opción de chat vacío. |
| **Fase 5** | Ficha 360° Reparada | Cero errores `QRCode.CorrectLevel`. El QR se visualiza nítido al abrir la pestaña. Clientes sin licencia muestran un Empty State elegante con botón de emisión. La pestaña Hardware muestra el modelo de celular y el historial real de migraciones. Los pagos se pueden crear, editar y eliminar con recálculo dinámico. |
| **Fase 6** | Modo Escritorio | `Iniciar_MochilaLista_Admin.bat` abre la plataforma en ventana limpia tipo app independiente (`--app`). El script de PowerShell crea el acceso directo en el Escritorio con el ícono `.ico` oficial. |
| **Fase 7** | Certificación Final | `node --check` pasa sin errores. `dart analyze` reporta 0 issues. Todas las suites de `dart test` pasan al 100% en verde sin alterar bases de datos de producción. |

---

## 5. RECOMENDACIÓN DE EJECUCIÓN SECUENCIAL

Para garantizar estabilidad operativa, cero regresiones y validación paso a paso, se recomienda ejecutar las fases en el siguiente orden secuencial estricto:

1. **Paso 1:** Implementar **Fase 1** (Conmutador de Modo Dual y Recarga Atómica). [COMPLETADO]
2. **Paso 2:** Implementar **Fase 2** (Sidebar Colapsable y Dashboard 4+4 con Gráficos Corregidos). [COMPLETADO]
3. **Paso 3:** Implementar **Fase 3** (Modelo de Datos Offline-First, Prospectos y Créditos IA). [COMPLETADO]
4. **Paso 4:** Implementar **Fase 4** (Comparador SemVer, Acciones CRM y Compositor WhatsApp). [COMPLETADO]
5. **Paso 5:** Implementar **Fase 5** (Ficha 360°, Reparación de QR, Pagos y Hardware). [COMPLETADO]
6. **Paso 6:** Implementar **Fase 6** (Lanzador Escritorio Modo App y Acceso Directo con Ícono Oficial). [COMPLETADO]
7. **Paso 7:** Implementar **Fase 7** (Suite de Pruebas Automatizadas y Certificación Final). [COMPLETADO]

---

## 6. ACTA DE CIERRE Y CERTIFICACIÓN FINAL DEL PLAN MAESTRO 14

**Fecha de Cierre Oficial:** 20 de Noviembre de 2026  
**Titular y Autor:** Julio Angello Vasquez Navarro  
**Resultado de Certificación:** **100% COMPLETADO — APROBADO CON CERO REGRESIONES**

### 6.1. Resumen de Entregables por Fase

1. **Fase 1: Conmutador de Entorno Dual (`Modo Pruebas` ↔ `Modo Real`):**
   - Selector visual tipo píldora en header con paleta semántica contrastada: `.mode-sandbox` (ámbar `#f59e0b`) y `.mode-prod` (verde esmeralda `#10b981`).
   - Sincronización atómica frontend-backend via `POST /api/system/mode` y cabecera HTTP `X-Admin-Mode`.
   - Limpieza y recarga automática de vistas, cierre de modales y drawers abiertos al alternar modo para eliminar cualquier estado o filtro residual.

2. **Fase 2: Sidebar Retraído y Dashboard Ejecutivo:**
   - Panel lateral colapsable a 68px con isotipo centrado de forma matemática (`#sidebarLogoIcon`), sin solapamientos ni desbordamientos.
   - Componente de tooltips flotantes en el `body` (`#sidebarFloatingTooltip`) calculados con `getBoundingClientRect()` libres de cualquier recorte por `overflow: hidden`.
   - Grilla simétrica 4+4 de tarjetas KPI con micro-interacciones activas.
   - Gráfico de dona SVG puro con soporte oficial para `EXTENSION_CORTESIA` (Cortesía) y `PROSPECTO` (Prospecto).
   - Formateo de montos en soles con 2 decimales coherentes (`S/ 35.10`).

3. **Fase 3: Modelo de Negocio 100% Offline-First y Registro CRM:**
   - Creación de prospectos comerciales sin obligatoriedad de Hardware ID (`PENDIENTE`), eliminando colisiones en la base de datos.
   - Registro de licencias `TRIAL` con especificación de días reales restantes reportados por el comerciante y `updates_until = null`.
   - Normalizador automático de números peruanos a formato internacional E.164 (`+51`).
   - Segregación estricta entre créditos IA reportados en el celular (`ai_reported_balance`) vs. bonos pendientes en tokens (`ai_pending_bonus`).
   - Endpoint `POST /api/clients/:id/sync-reported` y método `syncClientReportedState` para actualizar datos reportados sin requerir conexión a internet por parte de la app móvil.

4. **Fase 4: Comparador SemVer, Acciones CRM y Compositor de WhatsApp:**
   - Algoritmo de comparación SemVer semántica (`compareSemVer`) en backend y frontend (resuelve bug donde `v9.31.0` se marcaba como desactualizado ante `v9.30.0`).
   - Implementación de la Salvaguarda #3: si hay 0 versiones publicadas, el conteo de desactualizados es estrictamente `0`.
   - Reorganización de `ACCIONES CLAVE` de la Cartera CRM en 1 sola fila horizontal compacta (`.crm-actions-cell`), con ID alfanumérico sin cortes de línea (`white-space: nowrap`).
   - Modal Compositor Universal de WhatsApp (`#modalWaComposer`) con 4 plantillas dinámicas (Bienvenida/Entrega, Vencimiento Próximo, Cotización Prospecto, Personalizado), sustitución de variables `{NEGOCIO}`, `{TITULAR}`, `{DIAS}`, `{TOKEN}` y botón directo para abrir chat vacío.

5. **Fase 5: Ficha 360° Reparada, Hardware y CRUD Dinámico de Pagos:**
   - Corrección integral de la causa raíz de `QRCode.CorrectLevel`: definición formal en `qrcode.min.js` y abstracción en `renderSafeQrCode()` en `admin_app.js`.
   - *Empty State* elegante en pestaña QR para clientes sin licencias emitidas, eliminando tokens artificiales `ML9-PENDIENTE-...`.
   - Selector histórico de licencias Ed25519 emitidas con renderizado dinámico en vivo.
   - Pestaña Hardware conectada a `device_history` (y alias compatible `hardware`), con visualización del modelo de celular y botón de sincronización rápida (`#modalSyncReported`).
   - CRUD completo de Pagos (`POST /api/clients/:id/payments`, `PUT /api/clients/:id/payments/:paymentId`, `DELETE /api/clients/:id/payments/:paymentId`), con recálculo financiero en tiempo real.
   - Pestaña de Edición Total con Zona de Peligro (`#btnDrawerDeleteClient`) para eliminación controlada con modal de doble confirmación.

6. **Fase 6: Experiencia de Escritorio Nativa en 1 Clic:**
   - Generación de suite oficial de íconos multi-resolución (`favicon.ico`, `app_icon.ico` de 90 KB con capas 16x16, 32x32, 48x48 y 256x256, `icon_192.png`, `icon_512.png`, `manifest.json`) a partir del logotipo corporativo oficial `app_movil/assets/logo.png`.
   - Servidor HTTP (`server.dart`) sirviendo `favicon.ico` con MIME `image/x-icon`.
   - Lanzador por lotes `Iniciar_MochilaLista_Admin.bat` con loop de espera inteligente en `http://localhost:8080` e invocación en modo ventana nativa independiente (`--app=http://localhost:8080`) para Edge y Chrome.
   - Script PowerShell `Crear_Acceso_Directo_Escritorio.ps1` con resolución dinámica de carpetas redirigidas por Microsoft OneDrive (`[Environment]::GetFolderPath('Desktop')`), creando el acceso directo oficial `MochilaLista Admin.lnk`.

7. **Fase 7: Suite de Pruebas Automatizadas y Certificación Final:**
   - Creación de `mochilalista_admin/test/ux_crm_mode_offline_whatsapp_test.dart` (21 pruebas en 5 grupos, 100% aislada en `Directory.systemTemp`).
   - Validación sintáctica JavaScript: `node --check` exitoso en `admin_app.js` y `qrcode.min.js`.
   - Análisis estático Dart: `dart analyze` reporta `No issues found!`.
   - Regresión global automatizada: **83/83 pruebas pasando exitosamente en 12 archivos de test** (0 fallas, 0 advertencias).
   - Smoke test en vivo: endpoints `/`, `/api/vault/health` y `/favicon.ico` respondiendo HTTP 200 con liberación limpia del puerto 8080.
   - Blindaje estricto de secretos en Git: bases de datos de producción (`prod_clients_db.json`, `prod_releases_db.json`), llaves maestras (`ed25519_master.key`), bóvedas (`vault_keyring.json`, `*.mlvault`) y configuraciones de propietario (`owner_config.json`) verificadas como ignoradas y no rastreadas.

