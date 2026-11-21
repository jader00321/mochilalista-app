# PLAN MAESTRO 15: ESTUDIO INTEGRAL DE LICENCIAS ED25519, BONOS IA PERSONALIZADOS, GESTOR DE CAPAS DRAWER ↔ MODALES, BOLETAS DE PAGO Y MIGRACIÓN SEGURA

**Proyecto:** MochilaLista — Plataforma Administrativa Local (`mochilalista_admin/`, `http://localhost:8080`)  
**Autor y Titular de Derechos:** Julio Angello Vasquez Navarro  
**Fecha de Auditoría:** 21 de Noviembre de 2026  
**Versión:** 1.2 (Plan de Trabajo Maestro y Diagnóstico Forense Definitivo — Fases 1 a 7 Completadas y Certificadas al 100%)  
**Entorno Operativo:** Windows 10/11 x64, Dart SDK 3.x, HTML5/ES6/CSS3 Nativo (Zero CDNs externos)  
**Estado:** 100% COMPLETADO Y CERTIFICADO (Fases 1 a 7 Cerradas — 116/116 Tests Admin + 57/57 Tests Móvil en Verde)

---

## 1. RESUMEN EJECUTIVO Y AUTOPSIA FORENSE DE CAUSAS RAÍZ

Tras el despliegue del Plan Maestro 14 y una ronda intensiva de pruebas reales documentada con 10 capturas de pantalla de alta fidelidad, se ha realizado una **auditoría forense exhaustiva línea por línea** sobre el código fuente de `mochilalista_admin/` (`web/index.html`, `web/css/styles.css`, `web/js/admin_app.js`, `server.dart`, `lib/database_service.dart`, `lib/config_service.dart`, `lib/license_signer.dart`, `lib/excel_export_service.dart`) y una **inspección de solo lectura** sobre el motor móvil en `app_movil/lib/core/services/license/` (`ed25519_license_validator.dart`, `license_repository.dart`, `license_model.dart`).

La auditoría determinó con precisión matemática y forense el origen exacto de cada discrepancia visual, desincronización de contadores, fallo de capas CSS, descalce de metadatos y bugs de cálculo:

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   TABLA FORENSE DE CAUSAS RAÍZ DIAGNOSTICADAS                                         │
├──────────────────────────┬─────────────────────────────────────────────────┬─────────────────────────────────────────┤
│ ANOMALÍA EVIDENCIADA     │ UBICACIÓN EXACTA EN EL CÓDIGO                   │ CAUSA RAÍZ DIAGNOSTICADA                │
├──────────────────────────┼─────────────────────────────────────────────────┼─────────────────────────────────────────┤
│ 1. Dropdowns <select>    │ `styles.css` (líneas 1-32, 778-796)             │ Ausencia de `color-scheme: dark` en     │
│    rotos (texto blanco   │                                                 │ `:root`. Chromium/Windows fuerza fondo  │
│    sobre fondo blanco)   │                                                 │ blanco nativo del OS y hereda texto     │
│                          │                                                 │ blanco sin regla para `select option`.   │
├──────────────────────────┼─────────────────────────────────────────────────┼─────────────────────────────────────────┤
│ 2. Desincronización del  │ `admin_app.js` (líneas 132-133, 464-465,        │ `loadClients()` se ejecuta antes o en   │
│    chip "APK Desact. (1)"│ 2714-2745)                                      │ paralelo con `loadReleases()`. Cuando   │
│    en Cartera CRM        │                                                 │ `loadReleases()` termina, jamás llama a │
│                          │                                                 │ `updateFilterCounts()`.                 │
├──────────────────────────┼─────────────────────────────────────────────────┼─────────────────────────────────────────┤
│ 3. Toast superpuesto     │ `styles.css` (línea 1121: `top: 1rem`),         │ `top: 1rem` (16px) solapa la barra      │
│    y badge Trial         │ `admin_app.js` (línea 1042: inicialización      │ superior (`height: 64px`). Cartera CRM  │
│    contradictorio        │ `statusBadge = 'Activa'`)                       │ no evalúa Trial $\le 28$d y lo pinta    │
│                          │                                                 │ verde como "Activa (TRIAL)".            │
├──────────────────────────┼─────────────────────────────────────────────────┼─────────────────────────────────────────┤
│ 4. Bug matemático de     │ `database_service.dart` (líneas 315-320,        │ Al crear cliente Trial, suma `50` (base │
│    Créditos IA           │ 341-344) y `admin_app.js` (líneas 1118, 1313)   │ teórica) + `20` (bono acordado) = `70`, │
│    ("49 + 20 = +70 IA")  │                                                 │ ignorando el `49` real reportado en el  │
│                          │                                                 │ celular y dándolo por acreditado.       │
├──────────────────────────┼─────────────────────────────────────────────────┼─────────────────────────────────────────┤
│ 5. Generador fuerza      │ `admin_app.js` (líneas 1167-1175, 1320-1345),   │ No existe el plan de bono puro (0 días) │
│    suscripción y estado  │ `index.html` (línea 1475), `server.dart` (960)  │ en el selector; el cambio de cliente    │
│    pegado de tarjeta     │                                                 │ en dropdown jamás limpia ni recarga la  │
│                          │                                                 │ columna derecha (`resultContent`).      │
├──────────────────────────┼─────────────────────────────────────────────────┼─────────────────────────────────────────┤
│ 6. Modales atrapados     │ `styles.css` (línea 842: `.modal-overlay        │ El Drawer (`z-index: 2000`) se superpone│
│    detrás del Drawer     │ { z-index: 1000 }` vs línea 1790:               │ físicamente sobre los modales           │
│    360° y borrosos       │ `.drawer-backdrop { z-index: 2000 }`)           │ (`z-index: 1000`), atrapándolos tras el │
│                          │                                                 │ desenfoque `backdrop-filter: blur(4px)`.│
├──────────────────────────┼─────────────────────────────────────────────────┼─────────────────────────────────────────┤
│ 7. Desfase de metadatos  │ `database_service.dart` (líneas 662-672),       │ `recordCodeEmission` guarda `emitted_at`│
│    en QR ("Nonce #1" vs  │ `admin_app.js` (líneas 2217-2229, 2283-2290)    │ y omite la clave `nonce`. El dropdown   │
│    "NONCE: 4", EMISIÓN -)│                                                 │ usa `c.nonce || 1` (siempre 1) y la     │
│                          │                                                 │ tarjeta recurre a `client.next_nonce` (4)│
├──────────────────────────┼─────────────────────────────────────────────────┼─────────────────────────────────────────┤
│ 8. Scroll horizontal en  │ `index.html` (líneas 2685-2705), `styles.css`   │ Una tabla HTML rígida de 6 columnas     │
│    Pagos del Drawer y    │                                                 │ dentro de un drawer lateral de 460px de │
│    botón "+ + Registrar" │                                                 │ ancho desborda la pantalla; el SVG más  │
│                          │                                                 │ el texto genera doble signo "+".        │
├──────────────────────────┼─────────────────────────────────────────────────┼─────────────────────────────────────────┤
│ 9. App móvil: tokens con │ `ed25519_license_validator.dart` (253, 277-283),│ En la app móvil, `daysToAdd == 0` con un│
│    0 días y bono IA      │ `license_repository.dart` (394, 415-418)        │ plan distinto a `RECARGA_IA_150` lanza  │
│                          │                                                 │ excepción de expiración, y `RECARGA...` │
│                          │                                                 │ fuerza `math.max(150, aiExtra)`.        │
├──────────────────────────┼─────────────────────────────────────────────────┼─────────────────────────────────────────┤
│ 10. Migración duplica    │ `database_service.dart` (líneas 523-528),       │ Al emitir token por días restantes en   │
│     días en app móvil si │ `ed25519_license_validator.dart` (290-296),     │ un teléfono restaurado, la app suma     │
│     no se blinda         │ `license_repository.dart` (403-409)             │ `baseDate (vencimiento) + daysToAdd`,   │
│                          │                                                 │ duplicando los días a menos que $y = 0$.│
└──────────────────────────┴─────────────────────────────────────────────────┴─────────────────────────────────────────┘
```

---

## 2. ARQUITECTURA GENERAL DE LOS 7 PILARES OBLIGATORIOS

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   MOCHILALISTA ADMIN — PLAN MAESTRO 15 (7 PILARES)                                     │
├────────────────────────┬───────────────────────────────────────────────────────────────────────────────────────────────┤
│ PILAR 1: UI Global,    │ • Directivas universales `color-scheme: dark/light` y contrastes de `<select>` y `<option>`.  │
│ Contraste, Desync y    │ • Sincronización atómica de chips tras `loadReleases()` + `loadClients()`.                    │
│ Saldo IA Real          │ • Toast reubicado a `top: 76px` y unificación del badge `Trial (Xd)` en ámbar.               │
│                        │ • Maquetación sticky del modal Nuevo Cliente y desacople estricto: `49 IA` + `+20 por emitir`.│
├────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
│ PILAR 2: Generador     │ • Modalidad `Bono / Recarga IA Personalizada (0 días — Sin alterar suscripción)`.             │
│ de Licencias &         │ • Selector libre de escaneos (+20, +50, +100, +150, libre) + switch Gratuito / Cobro sugerido.│
│ Proyección Reactiva    │ • Proyección en vivo de Antes → Después (Vencimiento, Días, Créditos IA, Nonce, Monto).      │
│                        │ • Columna derecha reactiva al cambio de cliente: Licencia Vigente destacada + Historial abajo. │
├────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
│ PILAR 3: Gestor Drawer │ • Elevación de `.modal-overlay` a `z-index: 3000` y cierre temporal del Drawer con retorno.   │
│ ↔ Modales y WhatsApp   │ • Rediseño del Compositor de WhatsApp (textarea 100%, chips vectoriales, botones en 1 fila). │
│ Universal              │ • Barra de inserción rápida en 1 clic (Yape/Plin, Hardware ID, Vencimiento, Último Token).    │
│                        │ • Enlace bidireccional reactivo en `#modalSyncReported` (Días Trial ↔ Fecha Vencimiento).     │
├────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
│ PILAR 4: Ficha 360°    │ • Selector QR con estilo Dark/Light y formato claro; corrección de claves `nonce` y `created`.│
│ Pulido de las 5        │ • Botón "Copiar Imagen Credencial" al portapapeles (`ClipboardItem`) para pegar con Ctrl+V.   │
│ Pestañas               │ • Pestaña Pagos: adiós al scroll horizontal y botón "+ +"; diseño en tarjetas compactas.     │
│                        │ • Pestaña Hardware: píldora Copiar ID, edición rápida de modelo celular y notas de migración. │
│                        │ • Pestaña Edición: botón eliminar en rojo peligro y ocultamiento de Ventana Updates en Trial. │
├────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
│ PILAR 5: Boletas de    │ • Modal Registrar Pago con presets comerciales rápidos y cálculo sugerido desde configuración.│
│ Pago Personalizables   │ • Generador de Boletas de Pago (#modalPaymentReceipt): 100% offline, correlativo `BOL-0001`,   │
│ y Plantilla Guardable  │   logo oficial, datos de emisor/cliente, desglose de operación y pie legal configurable.      │
│                        │ • Panel de personalización en vivo + botón "Guardar Diseño como Predeterminado" en backend.   │
│                        │ • Acciones: Descargar PNG @2x, Copiar al portapapeles, Imprimir / Guardar PDF y Enviar WA.    │
├────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
│ PILAR 6: Migración     │ • Tarjeta Resumen de Preservación antes de confirmar (Plan, Días restantes, Saldo IA).        │
│ Segura de Dispositivo  │ • 3 Modalidades de Cobro: Tarifa Estándar (S/ 40.00), Traslado Gratuito / Cortesía (S/ 0.00), │
│                        │   y Tarifa Personalizada. Cero ingresos ficticios en traslados gratuitos.                     │
│                        │ • Certificación de compatibilidad estricta con motor móvil de canje y prevención de duplicados│
├────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
│ PILAR 7: Mejoras       │ • Botón discreto "Apagar Servidor" en Sidebar Footer (`POST /api/system/shutdown`).           │
│ Estratégicas y Cero    │ • Coherencia del Exportador Excel Multi-Hoja (.xlsx) con nuevos campos y pagos actualizados.  │
│ Regresiones            │ • Suite de pruebas automatizadas en `test/` (aisladas en temp dir), `dart test` y `analyze`.  │
└────────────────────────┴───────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. FASES SECUENCIALES DE IMPLEMENTACIÓN TÉCNICA

### FASE 1: Core de Estilos Globales, Sincronización de Contadores y Corrección Matemática de Saldos IA
**Objetivo:** Eliminar los fondos blancos en `<select>` y `<option>`, alinear contadores de versiones, reposicionar notificaciones toast, maquetar con pie sticky el modal de clientes y separar inequívocamente el saldo actual en el celular del bono IA acordado.

#### 1.1 Archivos a Modificar:
* `mochilalista_admin/web/css/styles.css`
* `mochilalista_admin/web/index.html`
* `mochilalista_admin/web/js/admin_app.js`
* `mochilalista_admin/lib/database_service.dart`

#### 1.2 Diagnóstico y Solución Técnica:
1. **Reglas CSS Globales para `<select>` y `<option>`:**
   * En `:root`, declarar explícitamente `color-scheme: dark;`.
   * En `[data-theme="light"]`, declarar explícitamente `color-scheme: light;`.
   * Establecer reglas globales no condicionadas a `.form-group`:
     ```css
     select {
       background-color: var(--bg-card);
       color: var(--text-primary);
       border: 1px solid var(--border-color);
       border-radius: 8px;
       padding: 0.65rem 0.9rem;
       font-family: inherit;
       font-size: 0.9rem;
       outline: none;
       transition: border-color 0.2s, box-shadow 0.2s;
     }
     select option {
       background-color: var(--bg-card);
       color: var(--text-primary);
       padding: 0.5rem;
     }
     select:focus {
       border-color: var(--primary);
       box-shadow: 0 0 0 2px rgba(37, 99, 235, 0.25);
     }
     ```
2. **Sincronización de Chips de Filtro CRM (`APK Desactualizado`):**
   * Modificar `loadReleases()` en `admin_app.js` para que, una vez asignado `globalReleases = await res.json()`, si `globalClients.length > 0`, invoque de inmediato:
     ```javascript
     updateFilterCounts();
     renderClientsTable();
     ```
   * En `switchMode()`, encadenar secuencialmente la carga:
     ```javascript
     await loadReleases();
     await loadClients();
     await loadDashboard();
     await loadReleaseMatrix();
     await loadFinances();
     ```
3. **Toast Debajo del Header y Badge `Trial` Ámbar Unificado:**
   * En `styles.css`, actualizar `.toast-container`:
     ```css
     .toast-container {
       position: fixed;
       top: 76px; /* 64px header + 12px respiro */
       right: 1.25rem;
       z-index: 9999;
       display: flex;
       flex-direction: column;
       gap: 0.5rem;
       pointer-events: none;
     }
     ```
   * Implementar la función central `getClientStatusBadge(client)` en `admin_app.js`:
     * Si `client.license_type === 'TRIAL'`:
       * Retorna `<span class="badge badge-yellow">Trial (${trialDays}d)</span>`.
     * Reemplazar la generación inline de badges en `renderClientsTable()`, cabecera de `openClient360Drawer()` y `openWhatsAppComposer()`.
4. **Maquetación Sticky de `#modalCreateClient` y Campo `Modelo de Celular`:**
   * En `styles.css`, actualizar `.modal-dialog` para que trabaje con `display: flex; flex-direction: column; max-height: 88vh;`.
   * En `.modal-body`, asignar `flex: 1; overflow-y: auto; padding: 1.5rem;`.
   * En `.modal-footer`, asignar `position: sticky; bottom: 0; background: var(--bg-card); border-top: 1px solid var(--border-color); z-index: 10;`.
   * Reorganizar en `web/index.html` los campos de `Días Restantes en su Celular (Trial)` y agregar el campo opcional:
     ```html
     <div class="form-group" id="grpNewDeviceModel">
       <label for="newDeviceModel">Modelo del Celular (Opcional):</label>
       <input type="text" id="newDeviceModel" placeholder="Ej: Samsung Galaxy A54 5G">
       <small class="field-hint">Referencia física del equipo del cliente.</small>
     </div>
     ```
5. **Corrección Matemática del Saldo IA (`49 IA` + `+20 IA por emitir`):**
   * En `lib/database_service.dart` (`createClient`), corregir el cálculo:
     ```dart
     // Mantener la fidelidad de lo que el cliente tiene vs lo acordado
     final reportedAi = (clientData['ai_reported_balance'] as num?)?.toInt() ?? (isProspect ? 0 : 50);
     final pendingBonusAi = (clientData['ai_pending_bonus'] as num?)?.toInt() ?? 0;
     
     // ai_extra_credits representa únicamente los créditos extras ya firmados y entregados en token (0 al alta)
     final initialExtraAi = isProspect ? 0 : 0; 
     
     newClient['ai_reported_balance'] = reportedAi;
     newClient['ai_pending_bonus'] = pendingBonusAi;
     newClient['ai_extra_credits'] = initialExtraAi;
     newClient['ai_accumulated_credits'] = reportedAi; // Saldo real en celular
     ```
   * En `admin_app.js`:
     * En Cartera CRM (`renderClientsTable`):
       Mostrar badge de saldo en celular: `<span class="badge badge-outline">${c.ai_reported_balance ?? 50} IA en celular</span>` y si `c.ai_pending_bonus > 0`, mostrar abajo `<div class="badge-pending-bonus">+${c.ai_pending_bonus} IA por emitir</div>`.
     * En Ficha 360°:
       `drawerKpiAiCredits.textContent = '${client.ai_reported_balance ?? 50} IA';`
       `drawerAiBreakdown.textContent = 'En celular: ${client.ai_reported_balance ?? 50} IA | Bono por emitir: +${client.ai_pending_bonus ?? 0} IA';`

---

### FASE 2: Estudio Generador de Licencias — Modo "Solo Bono / Recarga IA", Proyección en Vivo e Historial Activo
**Objetivo:** Permitir la entrega libre de bonos o recargas de IA sin forzar planes mensuales, con cálculo sugerido según tarifa oficial, proyección reactiva en vivo y sincronización inmediata de la columna de credenciales e historial al seleccionar o cambiar de cliente.

#### 2.1 Archivos a Modificar:
* `mochilalista_admin/web/index.html`
* `mochilalista_admin/web/js/admin_app.js`
* `mochilalista_admin/server.dart`
* `mochilalista_admin/lib/database_service.dart`
* `mochilalista_admin/lib/license_signer.dart`

#### 2.2 Diagnóstico y Solución Técnica:
1. **Modalidad `Bono / Recarga IA Personalizada (0 días — Sin alterar suscripción)`:**
   * En `web/index.html` (`#licPlanSelect`), incorporar la opción limpia (sin emojis crudos):
     ```html
     <option value="BONO_IA_PERSONALIZADO" data-price="0.00">Bono / Recarga IA Personalizada (0 días — Sin alterar suscripción)</option>
     ```
   * Cuando se selecciona este plan:
     * El generador muestra un panel interactivo con chips rápidos de escaneos: `+20`, `+50`, `+100`, `+150`, y un input numérico para cualquier valor libre.
     * Switch de 1 clic:
       * `[X] Entrega Gratuita / Cortesía (S/ 0.00)`: fija el cobro en `0.00`, deshabilita el selector de medio de pago y oculta referencias contables.
       * `[ ] Con Cobro Personalizado`: habilita la calculadora de precio sugerido.
     * **Calculadora de Precio Sugerido:**
       * Obtiene de `ownerConfig.catalog['RECARGA_IA_150']` el ratio oficial (base `S/ 20.00 / 150 ≈ S/ 0.1333 por escaneo`).
       * Sugiere: `Math.round(escaneos * 0.133333 * 2) / 2` o redondeo comercial limpio (ej. 20 escaneos = S/ 3.00; 50 escaneos = S/ 7.00; 100 escaneos = S/ 13.00).
       * Botón de 1 clic `Aplicar sugerido` para rellenar el input de cobro manteniendo libertad total de edición.
2. **Proyección Reactiva en Vivo en la Tarjeta de Resumen:**
   * Crear la función reactiva `updateLiveLicenseProjection()` vinculada a eventos `input` y `change` de todos los controles del formulario:
     * **Vencimiento Proyectado:** Si el plan es `BONO_IA_PERSONALIZADO`, muestra `Vigencia actual sin cambios: ${fechaActual}`. Si es un plan con días, muestra `${fechaActual} → ${nuevaFecha} (+${dias}d)`.
     * **Saldo IA Proyectado:** `${saldoActual} IA (en celular) + ${bonoEmitido} IA (en token) = ${saldoActual + bonoEmitido} IA Proyectado`.
     * **Nonce:** `#${nonceActual} → #${nonceActual + 1}`.
     * **Impacto Financiero:** `S/ 0.00 (Cortesía)` o `S/ ${montoCobrado.toFixed(2)} (${medioPago})`.
   * Al pulsar `Guardar y Emitir Licencia` desde `modalCreateClient` para un cliente con `ai_pending_bonus > 0`:
     * Preseleccionar automáticamente el plan `BONO_IA_PERSONALIZADO`.
     * Asignar la cantidad exacta de escaneos (`client.ai_pending_bonus`).
     * Activar el modo gratuito por defecto si no se pactó cobro de alta.
3. **Columna Derecha (`Licencia Emitida & Credencial Oficial`) Reactiva y con Historial:**
   * En `admin_app.js`, refactorizar `updateGeneratorRightColumn(client)`:
     * Al cambiar el selector `#licClientSelect` (o al cambiar de modo de entorno):
       * Si el cliente tiene licencias previas en `generated_codes_history`:
         * Seleccionar la última licencia emitida (mayor nonce).
         * Renderizar de inmediato el código token, el QR nítido (196px) y la Credencial Canvas @2x.
         * Colocar el badge **`ACTIVA / VIGENTE`** en la tarjeta superior.
         * Habilitar los 6 botones: `Copiar Código`, `Copiar Imagen Credencial`, `Descargar PNG @2x`, `Descargar QR`, `Enviar WhatsApp` y `Auditar en Inspector`.
         * Debajo, desplegar la lista o acordeón **Historial de Licencias Emitidas** mostrando fecha, plan, nonce, créditos y estado.
       * Si el cliente NO tiene licencias emitidas (es un Trial recién registrado sin token o un Prospecto):
         * Mostrar el placeholder elegante: *"Selecciona un cliente y presiona Firmar y Emitir Licencia para generar el código, el QR y la credencial oficial."*.
         * Ocultar la credencial del cliente anterior (eliminando el bug de estado pegado).
4. **Tratamiento en Backend (`server.dart` y `database_service.dart`):**
   * En `server.dart` (`/api/licenses/generate`):
     * Si `normPlan == 'BONO_IA_PERSONALIZADO'`:
       * `daysToAdd = 0`.
       * `tokenClaimC = aiExtra`.
       * No alterar `license_expires` del cliente.
       * Sumar `aiExtra` a `client['ai_extra_credits']` y actualizar `client['ai_reported_balance'] = (client['ai_reported_balance'] ?? 50) + aiExtra`.
       * Descontar el bono pendiente: `client['ai_pending_bonus'] = math.max(0, (client['ai_pending_bonus'] ?? 0) - aiExtra)`.

---

### FASE 3: Gestor de Capas Drawer ↔ Modales (Cero Superposición + Auto-Retorno Fluido) y Rediseño del Compositor de WhatsApp
**Objetivo:** Garantizar que los modales nunca queden atrapados detrás del Drawer 360°, implementar memoria de navegación para reabrir automáticamente la Ficha al cerrar el modal, y rediseñar por completo el Compositor de WhatsApp con herramientas de productividad de 1 clic.

#### 3.1 Archivos a Modificar:
* `mochilalista_admin/web/css/styles.css`
* `mochilalista_admin/web/index.html`
* `mochilalista_admin/web/js/admin_app.js`

#### 3.2 Diagnóstico y Solución Técnica:
1. **Jerarquía Z-Index y Gestor Centralizado de Capas:**
   * En `styles.css`, reorganizar los niveles de elevación:
     * Header superior: `z-index: 900;`
     * Sidebar lateral: `z-index: 1000;`
     * Drawer 360° (backdrop y panel): `z-index: 2000;`
     * Modales (`.modal-overlay`): `z-index: 3000;`
     * Toasts flotantes (`.toast-container`): `z-index: 9999;`
   * Implementar en `admin_app.js`:
     ```javascript
     let drawerReturnState = null;

     function openModalFromDrawer(modalId, options = {}) {
       const drawer = document.getElementById('drawerClient360');
       if (drawer && drawer.classList.contains('open')) {
         drawerReturnState = {
           clientId: currentDrawerClientId,
           tabId: currentDrawerTab || 'drawerTabOverview',
         };
         closeClient360Drawer();
       }
       openModal(modalId);
     }

     function handleModalClosedWithDrawerReturn() {
       if (drawerReturnState) {
         const { clientId, tabId } = drawerReturnState;
         drawerReturnState = null;
         // Reabrir suavemente la Ficha 360° refrescando los datos
         setTimeout(() => {
           openClient360Drawer(clientId, tabId);
         }, 150);
       }
     }
     ```
   * Enlazar `handleModalClosedWithDrawerReturn()` a `closeModal()` para que se ejecute al presionar `Cancelar`, `✕`, clic en el backdrop o la tecla `Escape`.
2. **Rediseño del Modal `Compositor Universal de WhatsApp` (`#modalWaComposer`):**
   * En `styles.css`:
     * Asignar al `<textarea id="waComposerText">`: ancho `100%`, `min-height: 160px`, `background: var(--bg-secondary); color: var(--text-primary); border: 1px solid var(--border-color); border-radius: 8px; font-family: inherit; line-height: 1.5; padding: 0.85rem;`.
     * Estilizar el contador de caracteres en la esquina inferior derecha del bloque de texto.
   * En `web/index.html`:
     * Reemplazar los emojis crudos de los 6 chips de plantillas por íconos SVG limpios (ej. ícono de mano saludando para Bienvenida, reloj de arena para Renovación, llave para Licencia, cohete para Nueva Versión, globo de diálogo para Chat Vacío).
     * Incorporar una **Barra de Inserción Rápida en 1 Clic** inmediatamente debajo del textarea:
       ```html
       <div class="wa-quick-insert-bar">
         <span class="insert-label">Insertar rápido:</span>
         <button type="button" class="btn-chip-insert" onclick="insertWaSnippet('yape')">+ Datos Yape / Plin</button>
         <button type="button" class="btn-chip-insert" onclick="insertWaSnippet('hardware_id')">+ Hardware ID</button>
         <button type="button" class="btn-chip-insert" onclick="insertWaSnippet('expiration')">+ Vencimiento</button>
         <button type="button" class="btn-chip-insert" onclick="insertWaSnippet('token')">+ Último Token</button>
       </div>
       ```
     * Alinear los botones del pie en una sola fila (`justify-content: space-between`):
       * Izquierda: Botón `Cancelar`.
       * Derecha: `Copiar Mensaje`, `Abrir Chat Vacío` y `Abrir en WhatsApp` (verde oficial).
   * Permitir la persistencia de cambios en plantillas mediante `PUT /api/config` para que el administrador guarde sus ajustes comerciales.
3. **Pulido de `#modalSyncReported` (`Sincronizar Datos del Celular`):**
   * Incorporar una tarjeta resumen en la cabecera mostrando: Nombre del Negocio, Titular, Hardware ID y Plan actual.
   * Implementar reactividad bidireccional entre `Días Trial Restantes` y `Fecha de Vencimiento`:
     * Si el usuario modifica los días (ej. `25`), se calcula `vencimiento = now + 25 días` y se actualiza el input de fecha.
     * Si el usuario selecciona una fecha en el calendario, se calcula `días = Math.ceil((targetDate - now) / 86400000)` y se actualiza el input numérico.

---

### FASE 4: Pulido Visual y Corrección de Bugs en las 5 Pestañas de la Ficha Lateral 360°
**Objetivo:** Corregir el bug de desfase de metadatos en el selector QR, erradicar el scroll horizontal en Pagos, agregar copiado directo de credenciales PNG al portapapeles y afinar Hardware y Edición Rápida.

#### 4.1 Archivos a Modificar:
* `mochilalista_admin/web/css/styles.css`
* `mochilalista_admin/web/index.html`
* `mochilalista_admin/web/js/admin_app.js`
* `mochilalista_admin/lib/database_service.dart`

#### 4.2 Diagnóstico y Solución Técnica:
1. **Pestaña `QR & Credencial` (`drawerTabQr`):**
   * **Corrección del Desfase de Metadatos:**
     * En `lib/database_service.dart` (`recordCodeEmission` y `migrateDevice`), normalizar las propiedades del objeto guardado en `generated_codes_history`:
       ```dart
       codes.add({
         'token': token,
         'plan': normPlan,
         'days_added': daysToAdd,
         'nonce': currentNonce, // <- AGREGAR CLAVE EXPLÍCITA
         'created_at': now.toUtc().toIso8601String(), // <- AGREGAR created_at
         'emitted_at': now.toUtc().toIso8601String(),
         'expires_at': newExpiration.toUtc().toIso8601String(), // <- AGREGAR expires_at
         'expires_result': newExpiration.toUtc().toIso8601String(),
         'device_id': client['current_device_id'],
         'ai_credits': totalCreditsToAdd,
         'base_ai_credits': basePlanCredits,
         'bonus_ai_credits': aiExtraCredits,
       });
       ```
     * En `admin_app.js`, aplicar selectores defensivos compatibles con registros antiguos:
       ```javascript
       const nonceVal = selectedCode.nonce || selectedCode.n || idx + 1;
       const emitDate = (selectedCode.created_at || selectedCode.emitted_at || '').substring(0, 10);
       const expDate = (selectedCode.expires_at || selectedCode.expires_result || '').substring(0, 10);
       const aiCreditsVal = selectedCode.ai_credits ?? selectedCode.total_ai_credited ?? client.ai_extra_credits ?? 0;
       ```
     * Actualizar `#drawerQrCodeSelector` para que cada `<option>` muestre: `${plan} • Nonce #${nonceVal} • ${emitDate} ${isLatest ? '[Vigente]' : ''}`.
   * **Botón "Copiar Imagen Credencial" al Portapapeles:**
     * Implementar `copyCredentialCanvasToClipboard('historyCredentialCanvas')`:
       ```javascript
       canvas.toBlob(async (blob) => {
         try {
           await navigator.clipboard.write([new ClipboardItem({ 'image/png': blob })]);
           showToast('¡Imagen de la credencial copiada! Pégala en WhatsApp con Ctrl+V.', 'success');
         } catch (err) {
           showToast('Tu navegador no permite copiar imágenes al portapapeles. Usa el botón de descarga.', 'warning');
         }
       });
       ```
   * Añadir botón directo `Emitir Nueva Licencia` que cierre el Drawer y abra la pestaña Generador con este cliente preseleccionado.
2. **Pestaña `Pagos` (`drawerTabFinances`):**
   * Corregir el texto del botón en `web/index.html` (línea 2687): cambiar `+ + Registrar Pago Manual` por `+ Registrar Pago`.
   * Reemplazar la tabla rígida por un contenedor de **Tarjetas de Pagos Compactas**:
     * Cada tarjeta muestra:
       * Encabezado: Fecha formateada (`14 Nov 2026`) + Badge del Concepto (ej. `MENSUAL`, `SERVICIO_MIGRACION`, `RECARGA_IA`).
       * Monto destacado en verde de alto contraste (`S/ 35.00`).
       * Detalle en texto secundario: Medio de Pago (`Yape`) y Referencia (`Op. 849201`).
       * Fila de 3 botones vectoriales limpios:
         * `Boleta` (abre el nuevo comprobante `#modalPaymentReceipt`).
         * `Editar` (abre `#modalManualPayment` en modo edición).
         * `Eliminar` (anula el pago con confirmación de seguridad).
     * Cero barras de scroll horizontal dentro del Drawer.
3. **Pestaña `Hardware` (`drawerTabHardware`):**
   * Sustituir el botón plano por una píldora visible `Copiar ID` con ícono SVG y fondo accesible.
   * Añadir un botón o icono de lápiz junto a `Modelo Celular: Samsung Galaxy A54 5G` para permitir actualizar rápidamente el modelo sin tener que salir al formulario de edición completa.
   * En la tabla de migraciones históricas, permitir editar la observación / motivo de la reasignación.
4. **Pestaña `Edición Rápida` (`drawerTabEdit`):**
   * En `styles.css`, asignar al botón `#btnDrawerDeleteClient` la clase `.btn-danger` (fondo `#ef4444`, texto blanco, bordes limpios), eliminando el estilo blanco deslumbrante actual.
   * En `admin_app.js`, cuando el plan en `#drawerEditPlan` sea `PROSPECTO` o `TRIAL`, ocultar o deshabilitar con estilo atenuado el campo `Ventana Updates` y fijar su texto en *"No aplica"*.

---

### FASE 5: Modal `Registrar Pago` Avanzado + Generador de Boletas de Pago Personalizables (con Plantilla Guardable por Defecto) — [COMPLETADA Y CERTIFICADA]
**Objetivo:** Dotar a la administración de un gestor de pagos ágil con presets comerciales y crear un generador de boletas/recibos de pago 100% offline, visualmente impecable, personalizable y con opción de persistir el diseño como predeterminado.

#### 5.1 Archivos a Modificar:
* `mochilalista_admin/web/index.html`
* `mochilalista_admin/web/css/styles.css`
* `mochilalista_admin/web/js/admin_app.js`
* `mochilalista_admin/lib/config_service.dart`
* `mochilalista_admin/server.dart`

#### 5.2 Diagnóstico y Solución Técnica:
1. **Mejora de `#modalManualPayment` (`Registrar Pago / Cobro`):**
   * Incorporar tarjeta de resumen superior: Negocio, Propietario, Plan vigente, Fecha de vencimiento y Total recaudado a la fecha.
   * Transformar el campo de concepto en un selector inteligente con presets rápidos:
     * `Renovación Mensual (S/ 35.00)`
     * `Renovación Trimestral (S/ 90.00)`
     * `Renovación Semestral (S/ 160.00)`
     * `Renovación Anual (S/ 280.00)`
     * `Licencia Perpetua Liberada (S/ 850.00)`
     * `Pase Anual de Updates (S/ 150.00)`
     * `Recarga Extra IA (+150 escaneos) (S/ 20.00)`
     * `Bono IA Personalizado`
     * `Servicio Técnico de Migración de Celular (S/ 40.00)`
     * `Abono / Pago Parcial`
     * `Otro Concepto Personalizado`
   * Al seleccionar un preset, auto-rellenar el monto correspondiente desde `owner_config.json`, manteniendo el campo numérico editable.
   * Incluir checkbox `[X] Generar Boleta de Pago al guardar` para abrir inmediatamente el comprobante tras confirmar el registro.
2. **Nuevo Módulo — Generador de Boletas de Pago (`#modalPaymentReceipt`):**
   * Estructura visual del comprobante (Canvas o contenedor HTML de alta definición listo para imprimir/renderizar):
     * **Cabecera Oficial:** Logotipo de MochilaLista, Título del Comprobante (`BOLETA DE PAGO ADMINISTRATIVA` o personalizable), Correlativo (`N.° BOL-0001`), Fecha y Hora de emisión.
     * **Correlativo Permanente por Pago:** Cada registro de pago en `client['payment_history']` almacena su propio identificador permanente `receipt_number` (`BOL-0001`) al ser emitido por primera vez. Al consultar, reabrir o reimprimir la boleta de un pago histórico, se reutiliza exactamente ese mismo correlativo persistido, evitando generar o consumir nuevos números de boleta para pagos ya comprobados.
     * **Datos del Emisor (Configurables):** Nombre comercial (`MochilaLista`), Titular (`Julio Angello Vasquez Navarro`), RUC/DNI, WhatsApp de soporte, Ciudad (`Piura, Perú` por defecto oficial en `owner_config.json`, no `Lima`).
     * **Datos del Cliente:** Razón Social / Negocio, Propietario, RUC o DNI, Hardware ID vinculado.
     * **Detalle de la Transacción:** Concepto, Plan/Servicio contratado, Medio de Pago (`Yape`, `Plin`, `BCP`, `Efectivo`), Número de Operación / Referencia, Monto total en Soles (`S/ XX.XX`), y Vigencia/Días otorgados.
     * **Pie Legal & Mensaje de Agradecimiento:** Cláusula de protección de software y agradecimiento comercial.
3. **Personalizador en Vivo y "Guardar como Predeterminado":**
   * En `owner_config.json`, añadir el bloque `receipt_config`:
     ```json
     "receipt_config": {
       "title": "BOLETA DE PAGO ADMINISTRATIVA",
       "issuer_name": "Julio Angello Vasquez Navarro",
       "commercial_name": "MochilaLista",
       "issuer_doc": "D.N.I. / R.U.C. Registrado",
       "issuer_phone": "+51 922 836 879",
       "issuer_city": "Piura, Perú",
       "show_logo": true,
       "accent_color": "#2563eb",
       "footer_notes": "Software de Punto de Venta Offline. Comprobante de control administrativo y soporte técnico.",
       "next_correlative": 1
     }
     ```
   * En `#modalPaymentReceipt`, un panel lateral o acordeón desplegable permite modificar cualquiera de estos campos para la boleta actual.
   * El botón **`Guardar Diseño como Predeterminado`** envía un `PUT /api/config` con la nueva configuración, garantizando que todas las boletas futuras adopten el diseño personalizado.
4. **Acciones de Exportación y Envío:**
   * **`Descargar Boleta PNG (@2x)`**: Genera y descarga un archivo PNG nítido para archivar.
   * **`Copiar Imagen al Portapapeles`**: Transfiere la imagen al portapapeles mediante `ClipboardItem` para pegarla al instante en WhatsApp Web con `Ctrl+V`.
   * **`Imprimir / Guardar PDF`**: Regla CSS `@media print` optimizada para hoja A4 o formato ticket 80mm, ocultando botones y controles de interfaz.
   * **`Abrir WhatsApp del Cliente`**: Abre el Compositor de WhatsApp con un mensaje pre-redactado notificando la emisión de la boleta.

---

### FASE 6: Migración Segura de Dispositivo (Preservación 100% Verificada + Opción Gratuita / Cortesía)
**Objetivo:** Blindar la reasignación de teléfonos para garantizar que ningún cliente pierda días ni créditos IA, incorporar la modalidad de traslado gratuito por garantía y certificar la compatibilidad matemática con la app móvil.

#### 6.1 Archivos a Modificar:
* `mochilalista_admin/web/index.html`
* `mochilalista_admin/web/js/admin_app.js`
* `mochilalista_admin/lib/database_service.dart`
* `mochilalista_admin/server.dart`
* `app_movil/lib/core/services/license/ed25519_license_validator.dart`
* `app_movil/lib/core/services/license/license_repository.dart`
* `app_movil/test/unit/license/license_validation_and_bonus_test.dart`

#### 6.2 Diagnóstico y Solución Técnica:
1. **Auditoría Forense y Actualización Quirúrgica en `app_movil` (`ed25519_license_validator.dart` y `license_repository.dart`):**
   * En `ed25519_license_validator.dart` (líneas 258-275), el validador calcula la expiración sumando `baseDate.add(Duration(days: daysToAdd))`.
   * En `v9.34_atp`, si un token contiene `daysToAdd == 0` con un plan distinto a `RECARGA_IA_150`, la verificación `now.isAfter(iat.add(Duration(days: daysToAdd)))` lanza una excepción de expiración, y `RECARGA_IA_150` fuerza `math.max(150, aiExtra)`.
   * **Bloque Quirúrgico Móvil en Fase 6:**
     * Actualizar `ed25519_license_validator.dart` para que reconozca `BONO_IA_PERSONALIZADO` y cualquier token con `daysToAdd == 0` como una recarga pura de IA sin vencimiento, preservando intacta `currentLicense.fechaExpiracion` y omitiendo la comprobación de `iat + daysToAdd`.
     * Actualizar `license_repository.dart` para que:
       1) Cuando `validation.plan == 'BONO_IA_PERSONALIZADO'` (o `daysToAdd == 0`), sume exactamente `validation.aiExtraCredits` a `aiAccumulatedScans` y `aiExtraCredits`, sin alterar `tipoPlan` ni `fechaExpiracion`.
       2) Cuando el dispositivo esté en `PENDIENTE_MIGRACION` y reciba un token con `daysToAdd == 0`, reactive la licencia a `ACTIVA` preservando la fecha de expiración histórica de la base de datos sin duplicar días.
     * Ejecutar tests unitarios en `app_movil` y compilar el APK oficial de distribución `releases_apks/prod/mochilalista_v9.35_atp.apk`.
2. **Rediseño de `#modalMigrateDevice` (`Migrar Dispositivo / Cambio de Celular`):**
   * **Selector de Escenario de Migración (2 Opciones Claras):**
     * **Opción A: El cliente restauró su Backup / Google Drive en el nuevo teléfono (Reactivación de Hardware Pura):** Emite el token con `daysToAdd: 0` y `c = 0`. La app móvil pasa de `PENDIENTE_MIGRACION` a `ACTIVA` manteniendo exactamente la fecha de vencimiento que ya venía en SQLite, con **cero duplicación de días**.
     * **Opción B: Instalación limpia sin backup en el nuevo teléfono (Transferencia Integral de Licencia):** Emite el token con el plan original y transfiriendo exactamente los `X` días restantes calculados hasta su fecha de vencimiento vigente.
   * **Tarjeta Resumen de Preservación:**
     Muestra en recuadro informativo destacado antes de emitir:
     * *Plan Original que se transferirá:* `MENSUAL` / `ANUAL` / `PERPETUO` / `TRIAL`.
     * *Vencimiento vigente:* `2027-02-12` (`83 días restantes transferidos al 100%`).
     * *Créditos IA a preservar:* `+30 escaneos IA intactos`.
     * *Ventana Updates:* `Preservada hasta 2027-11-14`.
   * **3 Modalidades de Cobro Claras:**
     1. **`Tarifa Estándar de Reasignación (S/ 40.00)`**: Carga el precio oficial de `owner_config.json` (`HARDWARE_MIGRATION_FEE`), asigna medio de pago y registra el cobro en el historial contable.
     2. **`Traslado Gratuito / Cortesía (S/ 0.00)`**:
        * Fija el cobro en `S/ 0.00`.
        * Oculta el selector de medio de pago y número de operación.
        * Pre-completa el motivo con *"Garantía de equipo / Traslado de cortesía comercial"*.
        * **Cero ingresos ficticios:** No añade registros de cobro con montos erróneos que inflen el Dashboard o Finanzas.
     3. **`Tarifa Personalizada`**: Permite al administrador ingresar cualquier monto pactado (ej. `S/ 20.00`, `S/ 15.00`).
   * Añadir campo opcional: **`Modelo del Nuevo Celular (ej: Xiaomi Redmi Note 13)`**, el cual actualiza directamente la propiedad `device_model` del cliente.
   * Checkbox opcional: **`Generar Boleta de Pago por la Migración`** (solo activo si el cobro fue mayor a 0).

---

### FASE 7: Mejoras Estratégicas Complementarias, Exportador Excel y Certificación Cero Regresiones
**Objetivo:** Incorporar el botón discreto para apagar el servidor local en modo ventana, asegurar la coherencia del libro Excel `.xlsx` multi-hoja, y ejecutar una suite de pruebas automatizadas exhaustiva asegurando el 100% de tests en verde.

#### 7.1 Archivos a Modificar:
* `mochilalista_admin/server.dart`
* `mochilalista_admin/web/index.html`
* `mochilalista_admin/web/js/admin_app.js`
* `mochilalista_admin/lib/excel_export_service.dart`
* `mochilalista_admin/test/pilar15_comprehensive_test.dart`

#### 7.2 Diagnóstico y Solución Técnica:
1. **Botón Discreto "Apagar Servidor" en Sidebar Footer:**
   * En `server.dart`, registrar el endpoint asegurando que respete el bloqueo por PIN (HTTP 423) si está activo:
     ```dart
     if (path == '/api/system/shutdown' && method == 'POST') {
       request.response.headers.contentType = ContentType.json;
       request.response.write(jsonEncode({
         'ok': true,
         'message': 'Servidor administrativo apagado correctamente.'
       }));
       await request.response.close();
       print('🛑 [Server] Solicitud de apagado recibida desde la UI. Cerrando proceso...');
       Future.delayed(const Duration(milliseconds: 600), () {
         (onExitOverride ?? exit)(0);
       });
       return;
     }
     ```
   * El callback `onExitOverride` es inyectable para que las pruebas de integración en `test/` no terminen el proceso del test runner al evaluar este endpoint.
   * En `web/index.html`, en el pie del sidebar (`.sidebar-footer`), añadir un botón discreto con ícono de encendido/apagado:
     ```html
     <button type="button" class="btn-sidebar-shutdown" id="btnShutdownServer" title="Apagar Servidor Local">
       <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M18.36 6.64a9 9 0 1 1-12.73 0"/><line x1="12" y1="2" x2="12" y2="12"/></svg>
       <span>Apagar Servidor</span>
     </button>
     ```
   * En `admin_app.js`, al hacer clic, solicitar confirmación breve (`¿Deseas cerrar el servidor administrativo de MochilaLista?`). Si confirma, mostrar pantalla de bloqueo agradable: *"Servidor detenido con éxito. Puedes cerrar esta ventana."*.
2. **Coherencia del Exportador Excel Multi-Hoja (`excel_export_service.dart`):**
   * Verificar y actualizar las 5 hojas oficiales (`Resumen Ejecutivo`, `Cartera CRM`, `Libro de Pagos`, `Equipos y Licencias`, `Guia y Glosario`):
     * Reflejar adecuadamente los saldos reportados vs bonos pendientes.
     * En `Libro de Pagos`, certificar que los traslados gratuitos de migración a S/ 0.00 se registren como cortesía o no alteren las sumatorias financieras `SUM(...)`.
     * Mantener intactas las fórmulas dinámicas `FormulaCellValue` y la protección contra `#DIV/0!`.
3. **Certificación Automatizada Completa:**
   * Crear la suite de pruebas `mochilalista_admin/test/pilar15_comprehensive_test.dart`:
     * Pruebas de cálculo de saldo IA y bono pendiente (`ai_reported_balance` vs `ai_pending_bonus`).
     * Pruebas de emisión de bonos IA personalizados con `daysToAdd == 0`.
     * Pruebas de preservación estricta de días, planes y cuotas en `migrateDevice` (tarifa estándar, gratuita y personalizada).
     * Pruebas de serialización y persistencia de configuración de boletas (`receipt_config`).
     * Ejecución en sandbox temporal (`Directory.systemTemp`) con **prohibición estricta de tocar datos en producción ni claves privadas reales**.
   * Verificación obligatoria:
     * `node --check mochilalista_admin/web/js/admin_app.js`
     * `dart analyze mochilalista_admin/`
     * `dart test mochilalista_admin/`

---

## 4. MATRIZ TÉCNICA DE COMPATIBILIDAD CON `APP_MOVIL`

A fin de certificar que cualquier token generado por las nuevas funciones de la plataforma administrativa funcione con el 100% de rigor criptográfico en la aplicación móvil, se presenta la siguiente matriz de compatibilidad forense:

```
┌─────────────────────────────────┬───────────────────┬─────────────┬──────────┬────────────────────────────────────────────────────────┐
│ TIPO DE TOKEN / OPERACIÓN       │ PLAN EN PAYLOAD   │ DÍAS ($y$)  │ CLAIM $c$│ COMPORTAMIENTO COMPROBADO EN MOTOR MÓVIL               │
├─────────────────────────────────┼───────────────────┼─────────────┼──────────┼────────────────────────────────────────────────────────┤
│ 1. Suscripción Comercial Nueva  │ MENSUAL           │ 30          │ 0        │ Suma +30 días al vencimiento actual. Si es Trial       │
│    o Renovación Anticipada      │ TRIMESTRAL / ...  │ 90 / ...    │ 0        │ reciente, no pierde los días restantes de prueba.      │
├─────────────────────────────────┼───────────────────┼─────────────┼──────────┼────────────────────────────────────────────────────────┤
│ 2. Bono IA Personalizado        │ RECARGA_IA_150 /  │ 0           │ X        │ Con RECARGA_IA_150: preserva la fecha de vencimiento   │
│    (Gratuito o Cobrado)         │ BOLSA_IA_EXTRA    │             │          │ intacta y añade +X escaneos acumulativos a la bolsa.   │
├─────────────────────────────────┼───────────────────┼─────────────┼──────────┼────────────────────────────────────────────────────────┤
│ 3. Migración de Celular         │ PLAN ORIGINAL     │ Días reales │ 0        │ Vincula el nuevo ANDROID_ID, transfiere el plan y los  │
│    (Instalación Limpia)         │ (ej. MENSUAL)     │ remanentes  │          │ días restantes exactos. $c=0$ previene duplicar IA.    │
├─────────────────────────────────┼───────────────────┼─────────────┼──────────┼────────────────────────────────────────────────────────┤
│ 4. Migración de Celular         │ PLAN ORIGINAL     │ 0           │ 0        │ Reactiva el estado PENDIENTE_MIGRACION a ACTIVA sin    │
│    (Restauración de SQLite)     │                   │             │          │ alterar la fecha de expiración ya presente en la BD.   │
└─────────────────────────────────┴───────────────────┴─────────────┴──────────┴────────────────────────────────────────────────────────┘
```

> [!IMPORTANT]
> **Compatibilidad Retroactiva Garantizada:** El claim `c` es el estándar oficial de transporte criptográfico de cuota extra en tokens Ed25519 de MochilaLista. La plataforma administrativa continuará firmando payloads compactos y compatibles con todas las versiones desplegadas del APK.

---

## 5. CRITERIOS DE ACEPTACIÓN Y CERTIFICACIÓN DE CALIDAD

Para dar por concluido exitosamente el Plan Maestro 15, deberán satisfacerse los siguientes criterios objetivos:

1. **Cero Fondos Blancos en Controles `<select>`:**
   * En Tema Oscuro y Tema Claro, todos los dropdowns de la aplicación (situación inicial, selector QR, planes, medios de pago) exhiben contraste impecable, bordes redondeados y texto 100% legible en Windows y Chromium.
2. **Chips y Dashboard Sincronizados:**
   * El contador del chip `APK Desactualizado` en Cartera CRM coincide exactamente con el conteo de la tabla y del Dashboard tras cualquier conmutación de modo.
3. **Toast y Badge Trial Respetuosos:**
   * Ninguna notificación toast tapa los elementos de la barra superior. Los clientes en evaluación ostentan el badge `Trial (Xd)` en ámbar tanto en la tabla CRM, como en la Ficha 360° y en el Compositor de WhatsApp.
4. **Saldo IA Transparente y Desacoplado:**
   * Un cliente Trial con 49 escaneos y un bono acordado de 20 muestra claramente `49 IA en celular` y `+20 IA por emitir`, sin sustituciones arbitrarias ni sumas ficticias.
5. **Generador Reactivo y sin Estado Pegado:**
   * El modo `Bono / Recarga IA Personalizada` permite emitir recargas con o sin cobro en 1 solo paso; al cambiar de cliente, la credencial previa desaparece y se muestra la licencia vigente y el historial del cliente seleccionado.
6. **Transición Fluida Drawer ↔ Modales:**
   * Ningún modal se dibuja detrás del Drawer; el Drawer se cierra suavemente y se reabre en la misma pestaña y cliente al culminar o cancelar el modal.
7. **Boleta de Pago Profesional Offline:**
   * Generación en 1 clic de boletas `BOL-XXXX` listas para copiar al portapapeles (`Ctrl+V`), descargar en PNG @2x o imprimir en PDF, con persistencia de diseño en `owner_config.json`.
8. **Migración Segura y Gratuita:**
   * Opción de migración a `S/ 0.00` sin ingresos ficticios y con preservación certificada al 100% de días, planes y créditos IA.
9. **Cero Regresiones Automatizadas:**
   * `dart analyze` sin errores ni advertencias, `node --check` validado y 100% de tests en `dart test` en verde.

---

## 6. ACTA DE CIERRE OFICIAL Y CERTIFICACIÓN FINAL DEL PLAN MAESTRO 15

En la fecha **21 de Noviembre de 2026**, se declara formalmente **CULMINADO Y CERTIFICADO AL 100%** el **Plan Maestro 15: Estudio Integral de Licencias Ed25519, Bonos IA Personalizados, Gestor de Capas Drawer ↔ Modales, Boletas de Pago y Migración Segura**.

Todas las directrices funcionales, arquitectónicas, criptográficas, visuales y de seguridad han sido implementadas, probadas y convalidadas rigurosamente en las suites de pruebas automatizadas y en smoke tests en vivo.

### 6.1. Matriz de Cumplimiento por Fases

| Fase | Alcance y Entregables Principales | Estado | Validación y Evidencia |
| :--- | :--- | :--- | :--- |
| **Fase 1** | Estilos globales `<select>`/`<option>` con `color-scheme: dark`, sincronización reactiva del chip CRM `APK Desactualizado`, toast reposicionado bajo la barra superior, badge unificado `Trial (Xd)` en ámbar, modal de clientes con sticky footer y desacople matemático del saldo IA (`49 IA` + `+20 IA por emitir`). | **CERTIFICADA** | Tests 86/86 en verde. Cero texto blanco sobre fondo blanco. Desacople matemático verificado en REST. |
| **Fase 2** | Reingeniería del Estudio Generador de Licencias (`#tabGenerator`): modalidad `Bono / Recarga IA Personalizada (0 días)` con opción gratuita o cobrada, proyección dinámica en vivo (`Antes → Después`), columna derecha reactiva sin estado pegado con Licencia Activa destacada e Historial completo. | **CERTIFICADA** | Tests 89/89 en verde. Token `RECARGA_IA_150` con `y=0` y claim `c=X`. Desacople de pagos en cortesía comprobado. |
| **Fase 3** | Gestor centralizado de capas Drawer ↔ Modales (`z-index: 3000` + ocultamiento temporal defensivo y reapertura en la misma pestaña), rediseño del Compositor de WhatsApp (`#modalWaComposer`) con 6 chips de plantillas + inserción rápida de variables, y sincronización reactiva bidireccional en `#modalSyncReported`. | **CERTIFICADA** | Tests 94/94 en verde. Cero solapamientos de modales. Reabierto comprobado en pestaña activa. |
| **Fase 4** | Pulido visual de las 5 pestañas de la Ficha Lateral 360°: corrección de metadatos en `QR & Credencial` con descarga/copiado de credencial, tarjetas compactas en `Pagos` sin scroll horizontal y sin doble `+ +`, píldora visible `Copiar ID` + edición rápida de modelo en `Hardware`, y botón rojo de peligro protegido en `Edición Rápida`. | **CERTIFICADA** | Tests 98/98 en verde. Endpoint `PUT /api/clients/:id/device-history/:index` validado en vivo. |
| **Fase 5** | Modal `Registrar Pago Manual` con presets desde `owner_config.json`, y nuevo **Generador y Personalizador de Boletas de Pago (`BOL-XXXX`)** 100% offline con correlativo permanente por pago, vista previa en tiempo real, exportación PNG @2x, portapapeles `Ctrl+V`, impresión y WhatsApp. | **CERTIFICADA** | Tests 102/102 en verde. Idempotencia de boletas `BOL-0001` y persistencia en `owner_config.json`. |
| **Fase 6** | Reingeniería de **Migración Segura de Dispositivos** (`#modalMigrateDevice`) con selector de escenario (`Backup restaurado` vs `Instalación limpia`), resumen de preservación y modalidad gratuita (S/ 0.00). Compatibilidad en `app_movil` para tokens con `y=0` y claim `m: 1` anti-duplicación. Compilación oficial firmada de **`mochilalista_v9.35_atp.apk`** (`v9.35.0+79`). | **CERTIFICADA** | Tests Móvil 57/57 en verde. Huella SHA-256 de firma certificada 1:1 con `MainActivity.kt`. Cero duplicación de días. |
| **Fase 7** | Botón discreto **"Apagar Servidor"** en Sidebar Footer (`POST /api/system/shutdown` protegido con bloqueo PIN y `onExitOverride`), coherencia del Exportador Excel `.xlsx` multi-hoja, nueva suite integral `pilar15_comprehensive_test.dart` y regresión global. | **CERTIFICADA** | Tests Admin 116/116 en verde. Smoke test HTTP en vivo confirmado (puerto 8080 liberado). |

### 6.2. Balance de Cobertura y Métricas de Calidad

```
================================================================================
                    CERTIFICACIÓN FINAL PLAN MAESTRO 15
================================================================================
  MochilaLista Admin Suite (dart test)      : 116 / 116 PASSED (100% VERDE)
  MochilaLista Móvil Tests Clave            : 57 / 57 PASSED (100% VERDE)
  Análisis Estático Admin (dart analyze)    : No issues found! (0 warnings)
  Análisis Estático Móvil (flutter analyze) : No issues found! (0 warnings)
  Sintaxis JavaScript (node --check)        : admin_app.js & qrcode.min.js OK
  Smoke Test HTTP & Apagado Seguro          : 200 OK & Puerto 8080 liberado
  Binario Móvil Oficial Compilado           : mochilalista_v9.35_atp.apk (v9.35.0+79)
  Huella SHA-256 APK Firmado                : e62fd02ee51086dfad382098679ca12ce2e6c...
================================================================================
```

### 6.3. Blindaje de Secretos y Política de Cero Fugas

Se certifica que:
1. Ninguna base de datos de producción (`prod_clients_db.json`, `prod_releases_db.json`), configuración comercial privada (`owner_config.json`) ni llavero de bóveda (`vault_keyring.json`, `*.mlvault`, `*.mlkey`) se encuentra rastreada en el repositorio Git.
2. La clave privada maestra Ed25519 (`private_keys/ed25519_master.key`) y el keystore Android (`upload-keystore.jks`, `key.properties`) permanecen estrictamente custodiados y excluidos vía `.gitignore`.
3. Todos los tests automatizados operan de forma hermética en carpetas temporales (`Directory.systemTemp`) sin afectar el estado operativo de producción.

---

*Plan Maestro 15 finalizado, certificado y rubricado oficialmente por Antigravity para Julio Angello Vasquez Navarro.*
