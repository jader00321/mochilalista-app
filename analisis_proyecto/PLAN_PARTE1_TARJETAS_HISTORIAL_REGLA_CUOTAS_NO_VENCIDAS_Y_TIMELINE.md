# PLAN DE ACCIÓN: PARTE 1 (BLOQUE 1)
# REINGENIERÍA DE TARJETAS DE HISTORIAL, REGLA ESTRICTA DE MOROSIDAD EN CUOTAS NO VENCIDAS Y REDISEÑO DE TIMELINE / CRONOGRAMA

**Documento de Especificación Técnica y Plan de Ejecución Quirúrgica**  
**Fecha:** Noviembre 2026  
**Rama:** `dev/mejoras-v9.0-comercializacion-seguridad`  
**Metodología:** Loop Autónomo + Árbitro Interno Adversarial  
**Estado:** PENDIENTE DE REVISIÓN Y APROBACIÓN POR EL USUARIO (FASE DE PLANIFICACIÓN - CERO MODIFICACIONES DE CÓDIGO)

---

## 1. RESUMEN EJECUTIVO Y AUDITORÍA FORENSE DE LAS 5 CAPTURAS REALES

Tras la inspección profunda del código y el cotejo milimétrico de las **5 capturas de pantalla reales adjuntadas por el usuario**, se levantó el siguiente diagnóstico exacto que fundamenta este Bloque 1 de mejoras:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        MAPA DE PANTALLAS Y COMPONENTES ANALIZADOS                     │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ • IMAGEN 1 (1:13 AM): Historial de Ventas (SalesListBuilder / SaleModel)               │
│   Ruta: app_movil/lib/features/smart_quotation/widgets/history/sales_list_builder.dart  │
│   Problema: Tarjeta de Préstamo #13 muestra "Sin motivo especificado" y etiquetas en    │
│   3 filas desordenadas; saldos desfasados con la mora activa (S/ 1,200 vs S/ 1,205).    │
│                                                                                        │
│ • IMAGEN 2 (1:13 AM): Cabecera de Préstamo #13 (SaleHistoryDetailScreen)               │
│   Ruta: app_movil/lib/features/smart_quotation/screens/sale_history_detail_screen.dart│
│   Widgets: DetailHeaderCard y DetailNotesCard                                          │
│   Problema: Monto gigante no refleja la mora acumulada (+S/ 5.00); nota real guardada  │
│   en base de datos es "Préstamo personal" pero se suprimió en el listado general.       │
│                                                                                        │
│ • IMAGEN 3 (1:15 AM): Plan de Cuotas (4) (SalePaymentTimeline)                         │
│   Ruta: .../widgets/history/detail_widgets/sale_payment_timeline.dart                  │
│   Problema: Cuotas no vencidas (Cuota 3, 07/11/2026) muestran "+ Mora" directo violando│
│   regla de negocio; botón "Cobrar" huérfano en 2da línea; texto con doble "+": "⊕ + Mora"│
│                                                                                        │
│ • IMÁGENES 4 y 5 (1:17 y 1:18 AM): Cronograma de Pagos (SaleFinancialDetailScreen)     │
│   Ruta: app_movil/lib/features/smart_quotation/screens/crm/sale_financial_detail_screen│
│   Problema: En cuota desplegada la mora se repite 3 veces; icono de calendario suelto; │
│   falta botón "Cobrar" y no hay acceso directo al comprobante PDF ni a WhatsApp.      │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 1.1 Diagnóstico Forense Específico por Captura

#### A. Evidencia de la Imagen 1 (`Historial de Ventas` — `1:13 AM`):
1. **Contradicción aberrante en el motivo del préstamo:**
   * En la cabecera del cliente `Jj` se lee en cursiva `Sin motivo especificado`.
   * Justo debajo se muestra el badge `[ 🗂️ Préstamo Personal ]`.
   * Al revisar la `Imagen 2`, en la base de datos la tarjeta `MOTIVO DEL PRÉSTAMO` tiene registrado textualmente: `Préstamo personal`.
   * **Causa Raíz en Código:** En `sales_list_builder.dart` (líneas 112-121):
     ```dart
     String cleaned = note.replaceAll(RegExp(r'pr[eé]stamo\s+personal(\s+para|\s*[-:]|\s+de)?\s*', caseSensitive: false), '').trim();
     if (cleaned.isNotEmpty && ...) {
       subtitleText = cleaned[0].toUpperCase() + cleaned.substring(1);
     } else {
       subtitleText = "Sin motivo especificado"; // <-- ¡DESTRUCCIÓN DEL DATO REAL!
     }
     ```
     El regex limpió `"Préstamo personal"` dejándolo como cadena vacía `""`, cayendo en el fallback destructivo `"Sin motivo especificado"`.
2. **Desorden y escalonamiento vertical de etiquetas:**
   * Mientras `Recibo #12` muestra `[ ⚡ Caja Rápida ]  [ EFECTIVO ]` en una sola fila horizontal impecable, `Préstamo #13` tiene sus etiquetas fragmentadas en 3 filas:
     - Fila 1: `[ 🗂️ Préstamo Personal ]`
     - Fila 2: `[ EFECTIVO ]`
     - Fila 3: `[ 📋 PENDIENTE • S/ 1,200.00 ]`
   * **Causa Raíz en Código:** Dentro del `Expanded` izquierdo (ancho restringido en pantallas móviles), `_OriginBadge` mide ~140px, obligando a `[ EFECTIVO ]` a saltar de línea, y abajo el `Wrap` inferior coloca el badge de estado en una tercera fila.
3. **Monto y saldos desincronizados con la mora:**
   * La tarjeta lista `S/ 1,200.00` y `PENDIENTE • S/ 1,200.00` y el KPI superior `Por Cobrar` marca `S/ 1,458.21`.
   * Cuando se le aplica mora al préstamo (elevando el total a `S/ 1,205.00` como muestran las Imágenes 3, 4 y 5), la lista y el KPI no se enteran en tiempo real debido a que `SaleProvider` mantiene la lista en memoria sin refrescar la venta modificada ni sus métricas.

#### B. Evidencia de la Imagen 2 (`Cabecera de Préstamo #13` — `1:13 AM`):
1. **Monto gigante en cabecera sin mora aplicada:**
   * `DetailHeaderCard` dibuja `S/ 1,200.00`. No muestra la píldora `Mora acumulada: + S/ 5.00` ni el importe real con mora `S/ 1,205.00`.
   * En `DetailNotesCard` se comprueba que el motivo real es `Préstamo personal` y es editable con un lápiz. Al editarse, el cambio debe reflejarse al instante en `Historial de Ventas` sin desincronizaciones.

#### C. Evidencia de la Imagen 3 (`SalePaymentTimeline` — `1:15 AM`):
1. **Violación de la Regla de Negocio en Cuotas no Vencidas:**
   * La `Cuota 3` (`Vence: 07/11/2026`, estado `⏳ PENDIENTE`) aún está en plazo, pero muestra el botón `+ Mora` exactamente igual que las cuotas ya vencidas (`Cuota 1` y `Cuota 2`).
   * **Regla de Oro:** La morosidad **solo puede aplicarse y sumar dinero a cuotas vencidas**. En cuotas aún no vencidas (`dueDate >= today`), el monto exigible debe ser estrictamente el original (`S/ 300.00`) y el botón debe decir `🛡️ Programar Mora` (para que la mora empiece a correr recién al día siguiente del vencimiento si no se paga).
2. **Disposición rota de botones:**
   * Signo `+` duplicado: El botón dice `⊕ + Mora` (icono `Icons.add_circle_outline` + texto `"+ Mora"`).
   * Botón `Cobrar` huérfano: Los botones `Mora` y `Recordar` se van a la derecha y `Cobrar` cae en una segunda fila solitaria abajo a la derecha.
   * Encabezado confuso: `Cuota 1` venció hace 13 días, pero su título dice `Vence: 24/10/2026` en lugar de `Venció: 24/10/2026`.

#### D. Evidencia de las Imágenes 4 y 5 (`SaleFinancialDetailScreen` — `1:17 y 1:18 AM`):
1. **Triple redundancia de texto en Cuota Desplegada (`Imagen 5`):**
   * Desglose 1 (Cabecera): `Orig: S/ 300.00 • + Mora: S/ 5.00 (1.7%)`
   * Desglose 2 (Cuerpo interior): `Base: S/ 300.00 • Mora: +S/ 5.00`
   * Desglose 3 (Botón inferior): `Mora: +S/ 5.00`
2. **Icono de calendario flotante:**
   * El botón `IconButton(Icons.edit_calendar)` flota desalineado a la derecha sin etiqueta explicativa.
3. **Ausencia del botón `Cobrar`:**
   * En la cuota desplegada solo hay botones `Mora` y `Recordar`, pero falta la acción fundamental: `Cobrar Cuota`.
4. **Falta de Paridad con PDF y WhatsApp:**
   * En la pantalla solo hay un botón azul genérico para volver a la otra vista. Faltan los accesos directos al comprobante PDF y al WhatsApp general del préstamo.

---

## 2. ARQUITECTURA ADVERSARIAL: CAUSAS RAÍZ Y ESTRATEGIA DE SOLUCIÓN

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        MAPA DE INTERVENCIÓN QUIRÚRGICA (BLOQUE 1)                      │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 1. MODELOS Y BASE DE DATOS:                                                            │
│    • SaleModel: Soporte de 'moraTotal', 'motivoPrestamoReal', 'cuotasVencidasCount'.   │
│    • SQLite (ventas & cuotas): Garantizar cálculo exacto de moras y cuotas vencidas.   │
│                                                                                        │
│ 2. MOTOR DE MOROSIDAD (SalesService & SaleProvider):                                   │
│    • Regla de Bloqueo: aplicarMorosidadManual RECHAZA cuotas con fecha_venc >= hoy.     │
│    • Regla Programada: configurarMorosidadAutomatica en cuotas vigentes NO SUMA mora    │
│      (mora_monto = 0.0, monto = original) hasta que la fecha se cumpla.               │
│    • Sincronización Reactiva: Al guardar o quitar mora, actualizar en memoria          │
│      _masterSales, _salesHistory y los KPIs de deuda sin recargar desde cero.         │
│                                                                                        │
│ 3. WIDGETS DE UI (Historial, Timeline y Cronograma):                                   │
│    • sales_list_builder.dart: Limpiar regex de notas; reorganizar chips en fila única; │
│      añadir badges '⚠️ N vencidas' y '+S/ X mora'.                                    │
│    • detail_header_card.dart: Añadir píldora 'Mora acumulada: +S/ X' y monto real.     │
│    • sale_payment_timeline.dart: Fila única simétrica de 3 botones con FittedBox;      │
│      diferenciar 'Venció:' vs 'Vence:'; eliminar signo '+' duplicado.                  │
│    • sale_financial_detail_screen.dart: Tabla limpia de 4 filas sin redundancia;       │
│      barra de acciones unificada [Fecha] [Mora] [Recordar] [Cobrar]; accesos PDF/WA.  │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. PLAN PASO A PASO POR FASES QUIRÚRGICAS

### FASE 1: Coherencia de Datos, Sincronización de Mora y Diseño de Tarjeta en `Historial de Ventas` y Cabecera de Detalle (`Imágenes 1 y 2`)

#### 1.1 Corrección del Motivo del Préstamo (Eliminación de la Regex Destructiva):
* **Archivo:** `app_movil/lib/features/smart_quotation/widgets/history/sales_list_builder.dart`
* **Diagnóstico en Líneas 108-128:** El código actual detecta la palabra `"préstamo personal"` y la borra por completo, cayendo en `"Sin motivo especificado"`.
* **Solución Quirúrgica:**
  1. Si `sale.isLoan`:
     - Leer `sale.notes?.trim() ?? ""`.
     - Si tiene texto, mostrar el texto exacto tal cual (ej. `"Préstamo personal"`, `"Préstamo para mercadería"`, `"Compra de útiles"`).
     - Si está realmente vacío, mostrar `"Préstamo personal"` como motivo por defecto, o `"Sin motivo especificado"` si el usuario prefiere esa indicación cuando no hay nota.
     - **Regla Estricta:** PROHIBIDO borrar el motivo si dice `"Préstamo personal"`.

#### 1.2 Reorganización Visual de Etiquetas en `SalesListBuilder`:
* **Problema:** Etiquetas apiladas en 3 filas escalonadas (`[Préstamo Personal]`, luego `[EFECTIVO]`, luego `[PENDIENTE • S/ 1,200.00]`).
* **Solución de Layout:**
  - En la columna izquierda del cuerpo central:
    * Fila 1: Nombre del Cliente (`clientTitle`).
    * Fila 2: Motivo real del préstamo en cursiva (`subtitleText`).
    * Fila 3: Fila horizontal compacta (`Wrap` con `spacing: 6` y `runSpacing: 4`):
      - Badge de Origen compacto: `[ 🗂️ Préstamo ]` (o `[ 🗂️ Préstamo Personal ]` si el ancho lo permite).
      - Badge de Método de Pago: `[ EFECTIVO ]`.
  - En la fila inferior de la tarjeta (Línea 303):
    * Badge de Estado Financiero con monto real con mora: `[ 📋 PENDIENTE • S/ 1,205.00 ]` (usando `sale.trueTotalAmount` y `sale.pendingDebt`).
    * **Nuevo Indicador de Cuotas Vencidas:** Si el préstamo tiene cuotas vencidas, mostrar badge rojo/ámbar: `[ ⚠️ 2 cuotas vencidas ]` (o `[ ⚠️ 2 vencidas ]`).
    * **Nuevo Indicador de Mora Activa:** Si `sale.moraTotal > 0.01`, mostrar badge ámbar: `[ ⏱️ +S/ 5.00 mora ]`.
  - **Resultado:** Desaparece el escalonamiento de 3 líneas desordenadas; el diseño queda 100% simétrico con `Recibo #12`.

#### 1.3 Sincronización en Vivo de Saldos y Mora en `SaleProvider` y Cabecera de Detalle:
* **Archivos:**
  - `app_movil/lib/features/smart_quotation/providers/sale_provider.dart`
  - `app_movil/lib/features/smart_quotation/repositories/sale_repository.dart`
  - `app_movil/lib/features/smart_quotation/widgets/history/detail_widgets/detail_header_card.dart`
* **Implementación:**
  1. En `sale_repository.dart` (`getHistoryRaw`), añadir subconsulta SQLite optimizada para traer en cada venta:
     - `(SELECT COUNT(*) FROM cuotas q WHERE q.venta_id = v.id AND q.estado != 'pagado' AND (q.monto - COALESCE(q.monto_pagado, 0)) > 0.01 AND date(q.fecha_vencimiento) < date('now', 'localtime')) AS cuotas_vencidas_count`
  2. En `SaleModel`:
     - Añadir campo `final int cuotasVencidasCount;` y parsearlo en `fromJson`.
  3. En `sale_provider.dart`:
     - Cuando se ejecute `aplicarMorosidadManual`, `configurarMorosidadAutomatica` o `quitarMorosidad`:
       * Actualizar de inmediato en memoria `_masterSales` y `_salesHistory` para el `saleId` afectado con el nuevo `monto_total` y `mora_total`.
       * Re-ejecutar `_applyTabFilterInMemory()` para recalcular de inmediato el KPI `Por Cobrar` (`totalDeuda`) a 0ms.
  4. En `detail_header_card.dart` (`Imagen 2`):
     - Leer `saleData['mora_total']`. Si es `> 0.01`, pintar la píldora idéntica a la `Imagen 4`:
       `[ Mora acumulada: + S/ 5.00 ]` encima del monto gigante.
     - Mostrar el monto total con mora: `S/ 1,205.00`.
     - Si tiene interés aplicado (`porcentaje_interes > 0`), pintar también `[ Interés aplicado: X% ]`.

---

### FASE 2: Regla Estricta de Negocio — La Morosidad Solo Suma Dinero en Cuotas Vencidas (`Imágenes 3 y 4`)

#### 2.1 Blindaje Lógico en Backend Local (`SalesService`):
* **Archivo:** `app_movil/lib/features/smart_quotation/services/sales_service.dart`
* **Regla 1 (Mora Manual):**
  - En `aplicarMorosidadManual(int cuotaId, ...)`:
    * Consultar `fecha_vencimiento` de la cuota.
    * Comparar `DateTime.parse(fecha_vencimiento)` con `DateTime.now()`.
    * Si la cuota **NO ha vencido** (`dueDate >= todayNorm`):
      - **RECHAZAR** la operación con mensaje explicativo: *"No es posible aplicar un recargo de morosidad a una cuota que aún no vence. Utilice la opción de 'Programar Mora' para que se aplique si entra en retraso."*
* **Regla 2 (Mora Automática Programada en Cuota Vigente):**
  - En `configurarMorosidadAutomatica(int cuotaId, ...)`:
    * Si la cuota está en plazo (`dueDate >= todayNorm`):
      - Guardar la configuración en la base de datos: `mora_automatica = 1`, `mora_tipo`, `mora_valor`, `mora_frecuencia`, `mora_intervalo_dias`, `mora_fecha_inicio = fecha_vencimiento`.
      - **REGLA DE ORO:** Mantener estrictamente `mora_monto = 0.0`, `monto = monto_original` y `mora_periodos_acumulados = 0`.
      - **NO SUMAR** ningún sol ni porcentaje al total de la cuota ni al `monto_total` de la venta.
* **Regla 3 (Motor Periódico `evaluarMorosidadPeriodica`):**
  - Al iterar cuotas con `mora_automatica = 1`:
    * Si `todayNorm <= dueDateNorm`: la cuota sigue vigente, `daysOverdue <= 0` -> ignorar y mantener en 0.
    * Recién cuando `todayNorm > dueDateNorm`: computar periodos vencidos desde el día de vencimiento y sumar la mora correspondiente.

#### 2.2 Blindaje en UI (`CuotaMorosidadModal`):
* **Archivo:** `app_movil/lib/features/smart_quotation/widgets/history/detail_widgets/cuota_morosidad_modal.dart`
* **Comportamiento Adaptativo según Vencimiento:**
  - Evaluar si la cuota está vencida: `final bool isVencida = dueDate.isBefore(today);`
  - Si **NO está vencida**:
    * Desactivar o bloquear la pestaña de `Manual (Cobro Inmediato)`.
    * Mostrar banner informativo con diseño elegante:
      `🛡️ Cuota en plazo (Vence: DD/MM/AAAA)`
      `La morosidad no puede cobrarse antes de tiempo. Programa aquí la regla automática para que entre en vigencia si el cliente no paga en la fecha límite.`
    * Botón de acción: `Guardar Regla Programada`.
    * No incrementar el total visual de la cuota mientras no venza.

---

### FASE 3: Rediseño Visual y Organización de Botones en `Plan de Cuotas` (`Imagen 3` — `SalePaymentTimeline`)

#### 3.1 Cabecera de Cuota Dinámica (`Venció:` vs `Vence:`):
* **Archivo:** `app_movil/lib/features/smart_quotation/widgets/history/detail_widgets/sale_payment_timeline.dart`
* **Mejora:**
  - Si está vencida (`isVencido`):
    * Mostrar: **`Cuota 1 • Venció: 24/10/2026`** (en color rojo/blanco contrastado).
  - Si está en plazo (`!isVencido`):
    * Mostrar: **`Cuota 3 • Vence: 07/11/2026`** (en tono neutro/ámbar).

#### 3.2 Fila Única Simétrica y Responsiva de Acciones (Eliminación del Botón Huérfano):
* **Problema:** En la `Imagen 3`, `Mora` y `Recordar` se agrupan dejando un hueco, y `Cobrar` se va solo a una línea inferior. Además el botón dice `⊕ + Mora`.
* **Solución Técnica:**
  - Reemplazar el `Wrap` caótico por una estructura de **Fila Única 100% Responsiva**:
    ```dart
    Row(
      children: [
        // Botón 1: Mora
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _buildMoraButton(...),
          ),
        ),
        const SizedBox(width: 8),
        // Botón 2: Recordar WhatsApp
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _buildReminderButton(...),
          ),
        ),
        const SizedBox(width: 8),
        // Botón 3: Cobrar
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _buildCobrarButton(...),
          ),
        ),
      ],
    )
    ```
  - **Eliminación del signo `+` duplicado:**
    * Si la cuota ya tiene mora: `⚙️ Mora (+S/ 5.00)`
    * Si la cuota está vencida y no tiene mora: `⊕ Mora` (o `+ Mora`, con icono `Icons.timer_outlined` o `Icons.add`, sin duplicar el signo visual).
    * Si la cuota **NO ha vencido** y tiene regla guardada: `🛡️ Mora prog.`
    * Si la cuota **NO ha vencido** y no tiene regla: `🛡️ Prog. Mora`
  - Gracias al `Row` con `Expanded` y `FittedBox`, los 3 botones quedan exactamente con la misma altura, perfectamente alineados en una sola fila en cualquier tamaño de pantalla (sin importar si la pantalla es de 320px o 450px).

---

### FASE 4: Limpieza de Redundancias, Barra de Acciones y Paridad en `Cronograma de Pagos` (`Imágenes 4 y 5` — `SaleFinancialDetailScreen`)

#### 4.1 Limpieza de Redundancias en Cuota Colapsada y Desplegada:
* **Archivo:** `app_movil/lib/features/smart_quotation/screens/crm/sale_financial_detail_screen.dart`
* **En Estado Colapsado (`Imagen 4`):**
  - Mantener subtítulo compacto de una sola línea:
    * Si está vencida con mora: `Venció hace 6 días • +S/ 5.00 mora`
    * Si está vencida sin mora: `Venció hace 13 días`
    * Si está en plazo con mora programada: `Vence: 07/11/2026 • 🛡️ Regla programada`
    * Si está en plazo regular: `Vence: 07/11/2026`
* **En Estado Desplegado (`Imagen 5`):**
  - Eliminar los 3 textos repetitivos (`Orig: S/ 300.00 • + Mora: S/ 5.00`, `Base: S/ 300.00 • Mora: +S/ 5.00` y el botón `Mora: +S/ 5.00`).
  - Sustituir por una **Tabla Financiera Limpia y Jerárquica**:
    ```
    ┌──────────────────────────────────────────────┐
    │ Monto Base:                        S/ 300.00 │
    │ Recargo por Mora (+1.7%):           +S/ 5.00 │
    │ Monto Abonado:                       S/ 0.00 │
    │ ──────────────────────────────────────────── │
    │ Saldo Exigible Cuota:              S/ 305.00 │
    └──────────────────────────────────────────────┘
    ```

#### 4.2 Barra de Acciones Unificada con Botón `Cobrar` y Reubicación de Calendario:
* Reemplazar el `IconButton(Icons.edit_calendar)` flotante suelto por una **barra de acciones inferior integrada**:
  - `[ 📅 Fecha ]`: Abre el selector de fecha de vencimiento con tooltip claro.
  - `[ ⚙️ Mora ]` o `[ 🛡️ Prog. Mora ]`: Abre el modal de morosidad.
  - `[ 💬 Recordar ]`: Abre el estudio de WhatsApp con mensaje parametrizado para esa cuota.
  - `[ 💵 Cobrar ]`: Abre el `PaymentEntryModal` directamente con el saldo de esa cuota pre-cargado.

#### 4.3 Paridad Funcional de Cabecera y Pie (Comprobante PDF y WhatsApp General):
* En `SaleFinancialDetailScreen`:
  - Incorporar en el `AppBar` o en una barra de acciones:
    * Botón de **Vista Previa / Comprobante PDF** (`PdfPreviewScreen`).
    * Botón de **Estudio / Editor WhatsApp General del Préstamo** (`WhatsAppPreviewScreen`).
  - De esta forma, el comerciante dispone de exactamente las mismas herramientas tanto si entra por `Historial de Ventas` como si entra por el `Perfil del Cliente / CRM`.

---

## 4. METODOLOGÍA DEL ÁRBITRO INTERNO ADVERSARIAL: CRITERIOS DE RECHAZO (VETO)

Para garantizar la máxima calidad técnica sin regresiones, el **Árbitro Interno Adversarial** evaluará las modificaciones bajo esta matriz de veto estricto:

| # | Prueba Adversarial | Comportamiento Esperado | Criterio de VETO (Fallo Inmediato) |
|---|-------------------|-------------------------|------------------------------------|
| 1 | **Motivo de Préstamo en Historial** | Si el motivo es `"Préstamo personal"`, la tarjeta de `Historial de Ventas` debe mostrar textualmente `"Préstamo personal"` debajo de `Jj`. | Si dice *"Sin motivo especificado"* o se oculta por el regex, la fase se considera REPROBADA. |
| 2 | **Alineación de Etiquetas en Historial** | En `Préstamo #13`, las etiquetas de tipo y método de pago deben quedar alineadas en una fila y las de estado en la fila inferior. | Si las etiquetas se parten en 3 filas escalonadas como en la `Imagen 1`, se VETA el diseño. |
| 3 | **Mora en Cuota no Vencida** | Al abrir `Cuota 3` (vence en fecha futura), el botón no debe cobrar mora directa. El modal no debe sumar dinero a la cuota ni al préstamo. | Si `mora_monto > 0` o el total pasa a `S/ 305.00` antes de vencer, se VETA de inmediato. |
| 4 | **Fila Única en `Plan de Cuotas`** | En `SalePaymentTimeline`, los 3 botones (`Mora`, `Recordar`, `Cobrar`) deben estar en una sola fila horizontal simétrica. | Si `Cobrar` cae a una segunda línea huérfana en cualquier resolución, se VETA el cambio. |
| 5 | **Eliminación del Doble Signo `+`** | El botón de mora no debe mostrar `⊕ + Mora`. Debe ser `⊕ Mora` o `+ Mora`. | Si aparecen ambos signos sumados, se VETA. |
| 6 | **Limpieza de Redundancia en Cuota Desplegada** | En `SaleFinancialDetailScreen`, la cuota desplegada debe mostrar la tabla financiera sin repetir `Base / Orig / Mora` tres veces. | Si se detecta repetición idéntica del texto, se VETA. |
| 7 | **Botón Cobrar en Cuota Desplegada** | Dentro de la cuota desplegada en `SaleFinancialDetailScreen` debe existir el botón `Cobrar`. | Si falta el botón para amortizar la cuota específica, se VETA. |
| 8 | **Compilación y Análisis Estático** | `flutter analyze` debe pasar con 0 errores. | Cualquier error de tipado o compilación bloquea el merge. |

---

## 5. RESUMEN DE ARCHIVOS QUE SERÁN MODIFICADOS EN LA EJECUCIÓN

1. `app_movil/lib/features/smart_quotation/widgets/history/sales_list_builder.dart` (Layout horizontal de badges, corrección de regex de motivos, badges de cuotas vencidas y mora activa).
2. `app_movil/lib/features/smart_quotation/widgets/history/detail_widgets/detail_header_card.dart` (Píldora de mora acumulada y sincronización del monto total con mora).
3. `app_movil/lib/features/smart_quotation/models/crm_models.dart` (Soporte de `cuotasVencidasCount` en `SaleModel`).
4. `app_movil/lib/features/smart_quotation/repositories/sale_repository.dart` (Subconsulta de cuotas vencidas en `getHistoryRaw`).
5. `app_movil/lib/features/smart_quotation/services/sales_service.dart` (Restricción estricta de mora manual en cuotas no vencidas y salvaguarda en cuotas programadas).
6. `app_movil/lib/features/smart_quotation/providers/sale_provider.dart` (Sincronización reactiva en memoria de `_salesHistory`, `_masterSales` y KPIs tras cambios de mora).
7. `app_movil/lib/features/smart_quotation/widgets/history/detail_widgets/sale_payment_timeline.dart` (Fila simétrica responsiva de 3 botones, corrección `⊕ + Mora`, encabezado `Venció:` vs `Vence:`).
8. `app_movil/lib/features/smart_quotation/widgets/history/detail_widgets/cuota_morosidad_modal.dart` (Modo programado para cuotas vigentes, bloqueo de recargo inmediato si no ha vencido).
9. `app_movil/lib/features/smart_quotation/screens/crm/sale_financial_detail_screen.dart` (Eliminación de triple redundancia, barra de 4 acciones con `Cobrar`, paridad PDF y WhatsApp).

---
**FIN DEL DOCUMENTO DE PLANIFICACIÓN (BLOQUE 1)**  
*Listo para revisión y aprobación por parte del usuario antes de iniciar la Fase de Ejecución.*

