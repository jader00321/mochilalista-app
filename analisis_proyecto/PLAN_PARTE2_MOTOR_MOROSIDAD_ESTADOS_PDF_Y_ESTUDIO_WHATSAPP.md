# PLAN MAESTRO: MOTOR DE MOROSIDAD (MANUAL Y PERIÓDICO), TAXONOMÍA DE ESTADOS EN AMBAS VISTAS DE DETALLE Y PDF, Y ESTUDIO DE PREVISUALIZACIÓN Y EDICIÓN SEGURA DE WHATSAPP (PARTE 2)

**Documento de Especificación de Reingeniería y Plan de Ejecución**  
**Fecha:** Noviembre 2026  
**Rama:** `dev/mejoras-v9.0-comercializacion-seguridad`  
**Metodología:** Loop Autónomo + Árbitro Interno Adversarial  
**Estado:** PENDIENTE DE REVISIÓN Y APROBACIÓN POR EL USUARIO (FASE DE PLANIFICACIÓN - CERO MODIFICACIONES DE CÓDIGO)

---

## 1. RESUMEN EJECUTIVO Y AUDITORÍA FORENSE CONTRA LAS 5 CAPTURAS REALES

Tras la recepción y análisis exhaustivo de las **5 capturas reales adjuntadas por el usuario**, se realizó un cotejo milimétrico contra la arquitectura del código fuente de la aplicación Flutter/Dart. Este análisis identificó de manera concluyente la existencia de **dos pantallas distintas de detalle** que gestionan cuotas en la app, así como los defectos visuales, contables y de comunicación exactos.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        MAPA DE PANTALLAS IDENTIFICADAS EN CAPTURAS                     │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ • IMAGEN 1: SaleFinancialDetailScreen (Detalle del Préstamo #13 / Detalle de Venta)    │
│   Ruta: app_movil/lib/features/smart_quotation/screens/crm/sale_financial_detail_screen.dart│
│   Acceso: Perfil del Cliente -> Estado de Cuenta -> Tap en Préstamo/Venta a Crédito    │
│                                                                                        │
│ • IMÁGENES 2 y 3: SaleHistoryDetailScreen (Préstamo #13 / Detalle de Venta)           │
│   Ruta: app_movil/lib/features/smart_quotation/screens/sale_history_detail_screen.dart│
│   Widgets: DetailStatusCard y SalePaymentTimeline                                      │
│   Acceso: Historial de Ventas / Búsqueda global de transacciones                      │
│                                                                                        │
│ • IMAGEN 4: PdfPreviewScreen (Vista Previa PDF - COMPROBANTE DE PRÉSTAMO)              │
│   Ruta: app_movil/lib/features/smart_quotation/screens/pdf_preview_screen.dart          │
│   Motor: app_movil/lib/features/smart_quotation/utils/pdf_generator.dart               │
│                                                                                        │
│ • IMAGEN 5: WhatsAppPreviewScreen (Editor WhatsApp)                                    │
│   Ruta: app_movil/lib/features/smart_quotation/screens/whatsapp_preview_screen.dart     │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 1.1 Diagnóstico Forense por Captura

#### A. Evidencia de la Imagen 1 (`SaleFinancialDetailScreen` - `3:51 AM`):
* **Elementos en pantalla:**
  - Cabecera: `Detalle del Préstamo #13`
  - Indicador superior: `Saldo Pendiente de este Préstamo` con chip `Interés aplicado: 20.0%`
  - Cifra destacada: `1.200,00 S/` (formato europeo de moneda en lugar de `S/ 1,200.00`)
  - Subtotales: `Monto Total 1.200,00 S/` | `Abonado 0,00 S/`
  - Sección: `Cronograma de Pagos`
    * Cuota 1: `Cuota 1` (`300,00 S/`), con alerta roja `Venció hace 12 días` y etiqueta `VENCIDA`.
    * Desglose desplegado: `Total Cuota: 300,00 S/`, `Abonado: 0,00 S/`, `Falta Pagar: 300,00 S/`.
    * Icono a la derecha: `IconButton(Icons.edit_calendar)` (solo permite editar la fecha de vencimiento).
    * Cuota 2: Alerta roja `Venció hace 5 días` | `VENCIDA`.
    * Cuota 3: Reloj ámbar `Vence: 07/11/2026` | `PRÓXIMA`.
    * Cuota 4: Calendario gris `Vence: 14/11/2026` | `PENDIENTE`.
* **Carencia Crítica:**
  - En esta pantalla **NO EXISTE ningún control para aplicar morosidad** a las cuotas vencidas (ni manual ni periódica automática), ni botón para recordar por WhatsApp la cuota específica con texto editable. El comerciante solo puede cambiar la fecha con `edit_calendar`.

#### B. Evidencia de las Imágenes 2 y 3 (`SaleHistoryDetailScreen` - `3:48 AM`):
* **Elementos en pantalla (`Imagen 3` - `DetailStatusCard`):**
  - Título de tarjeta: `ESTADO DEL PRÉSTAMO` con estado `PRÉSTAMO DESEMBOLSADO · EN CURSO`.
  - Desglose: `Capital Inicial Prestado: S/ 1,000.00`, `Interés / Financiamiento (20.0%): + S/ 200.00`, `Método de Desembolso: EFECTIVO`, `Estado Financiero: PENDIENTE`, `Total a Devolver: S/ 1,200.00`, `Total Abonado: S/ 0.00`, `Saldo Deudor Exigible: S/ 1,200.00`.
* **Elementos en pantalla (`Imagen 2` - `SalePaymentTimeline`):**
  - Tarjeta desplegable: `Plan de Cuotas (4)`
    * Cuota 1: `Vence: 24/10/2026  S/ 300.00`, badge `! VENCIDO` en rojo. Botones: `Recordar` (verde) y `Cobrar` (teal).
    * Cuota 2: `Vence: 31/10/2026  S/ 300.00`, badge `! VENCIDO` en rojo. Botones: `Recordar` y `Cobrar`.
    * Cuotas 3 y 4: `Vence: 07/11/2026` y `14/11/2026`, badge `⌛ PENDIENTE` en ámbar.
* **Carencia Crítica:**
  - Al igual que en la Vista A, aquí no hay botón ni modal para configurar morosidad. Si la cuota tiene mora, `DetailStatusCard` no tiene fila de `Mora Acumulada`, y el total de la deuda permanece estático sin penalizar el atraso. Además, al presionar `Recordar` se abre un diálogo de solo lectura que no permite editar el texto del mensaje antes de abrir WhatsApp.

#### C. Evidencia de la Imagen 4 (`PdfPreviewScreen` / `COMPROBANTE DE PRÉSTAMO` - `3:48 AM`):
* **Anomalías detectadas:**
  1. **Cuotas vencidas marcadas erróneamente como `PENDIENTE` en amarillo:** En el recuadro `PLAN DE CUOTAS (4 cuotas)`, tanto la Cuota 1 (`24/10/2026`) como la Cuota 2 (`31/10/2026`), que tienen 12 y 5 días de atraso, aparecen en amarillo con el texto `PENDIENTE`, ocultando la mora al deudor y al comerciante.
  2. **Teléfono del cliente como `Tel: 00000000`:** En la cabecera del documento, debajo de `CLIENTE: JJ`, se imprime `Tel: 00000000` (8 ceros), ignorando el teléfono real `922836879` registrado en su perfil.
  3. **Texto de pie de página fuera de contexto:** En el bloque inferior de cuentas, imprime `Condiciones: Válida por 7 días`, el cual es un texto estricto de cotización de venta, totalmente impropio para un comprobante de préstamo o venta al crédito.

#### D. Evidencia de la Imagen 5 (`WhatsAppPreviewScreen` - `Editor WhatsApp` - `3:48 AM`):
* **Anomalías detectadas:**
  - En la sección `📅 *CRONOGRAMA DE PAGOS* (4 Cuotas)`:
    * `▪ Cuota 1: *S/ 300.00* (Vence: 24/10/2026) - ⏳ Pendiente`
    * `▪ Cuota 2: *S/ 300.00* (Vence: 31/10/2026) - ⏳ Pendiente`
    * `▪ Cuota 3: *S/ 300.00* (Vence: 07/11/2026) - ⏳ Pendiente`
    * `▪ Cuota 4: *S/ 300.00* (Vence: 14/11/2026) - ⏳ Pendiente`
  - Todas las cuotas aparecen como `⏳ Pendiente` sin distinguir las cuotas vencidas (`🔴 Vencida hace 12 días`), ni reportar pagos parciales ni incrementos por morosidad.
  - Además, en toda la aplicación, cuando el usuario presiona `Recordar` desde el banner rojo del perfil del cliente, WhatsApp se lanza directamente mediante `ConfirmActionModal` sin permitir editar el mensaje sugerido en un editor previo.

---

## 2. ARQUITECTURA DE LA SOLUCIÓN REINGENIERIL

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              1. BASE DE DATOS SQLITE v30                               │
│  Tabla 'cuotas':                                                                       │
│  - monto_original REAL (Preserva importe base contratado)                              │
│  - mora_monto REAL DEFAULT 0.0 (Recargo acumulado por retraso)                         │
│  - mora_porcentaje REAL DEFAULT 0.0 (Tasa % fijada)                                    │
│  - mora_automatica INTEGER DEFAULT 0 (1 = Recurrencia activa, 0 = Desactivada)         │
│  - mora_frecuencia TEXT ('diario', 'cada_2_dias', 'cada_3_dias', 'semanal', etc.)      │
│  - mora_intervalo_dias INTEGER DEFAULT 1                                               │
│  - mora_tipo TEXT DEFAULT 'fijo' ('fijo' | 'porcentaje')                               │
│  - mora_valor REAL DEFAULT 0.0 (S/ fija o % periódico)                                 │
│  - mora_fecha_inicio TEXT (ISO fecha inicio cómputo mora)                              │
│  - mora_ultima_aplicacion TEXT (ISO fecha último cómputo)                              │
│  - mora_periodos_acumulados INTEGER DEFAULT 0 (Periodos devengados)                    │
└───────────────────────────────────────────┬────────────────────────────────────────────┘
                                            │
                                            ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        2. MOTOR DE MOROSIDAD DUAL (SERVICE)                            │
│                                                                                        │
│  [ MODO MANUAL ]                                                                       │
│  • Input: Monto Fijo (S/) o Porcentaje (%) sobre monto_original                        │
│  • Fórmula: cuotas.monto = cuotas.monto_original + mora_monto                          │
│  • Opción Quitar Mora: cuotas.monto = cuotas.monto_original (mora_monto = 0.0)         │
│                                                                                        │
│  [ MODO AUTOMÁTICO PERIÓDICO ]                                                         │
│  • Intervalos: Diario (1d), 2d, 3d, Semanal (7d), Quincenal (15d), Mensual (30d), N d. │
│  • Acumulación acumulativa por periodos vencidos:                                      │
│    periodos = max(0, diasVencidos ~/ intervaloDias)                                   │
│    mora_monto = periodos * (tipo == 'porcentaje' ? monto_original * % : valor_fijo)     │
│  • REGLA ESTRICTA DE CONSERVACIÓN:                                                     │
│    Al desactivar (toggle OFF), mora_automatica = 0.                                    │
│    PROHIBIDO BORRAR MORA_MONTO: Los recargos devengados se PRESERVAN en la cuota.      │
│                                                                                        │
│  [ REPERCUSIÓN CONTABLE 360° ATÓMICA ]                                                 │
│  • UPDATE ventas SET monto_total = (SELECT SUM(monto) FROM cuotas WHERE venta_id = ?)  │
│  • recalculateClientDebt(clientId)                                                     │
│  • recalculateClientReputation(clientId)                                               │
└───────────────────────────────────────────┬────────────────────────────────────────────┘
                                            │
         ┌──────────────────────────────────┴──────────────────────────────────┐
         ▼                                                                     ▼
┌──────────────────────────────────────────┐          ┌──────────────────────────────────────────┐
│   3. UNIFICACIÓN EN AMBAS VISTAS Y PDF   │          │  4. ESTUDIO DE PREVISUALIZACIÓN WHATSAPP │
│                                          │          │                                          │
│ A. Vista A (SaleFinancialDetailScreen):  │          │ • Unificación de TODOS los botones       │
│    - Botón "+ Mora" / "⚙️ Mora" en cuota │          │   "Recordar" (Banner rojo + Cuotas)      │
│    - Pastilla: Orig + Mora = Total       │          │ • Área de texto multilínea editable      │
│    - Botón "Recordar" con estudio        │          │   (TextFormField) dentro de la app       │
│                                          │          │ • Plantillas dinámicas inteligentes:     │
│ B. Vista B (SaleHistoryDetailScreen):    │          │   - 1 cuota vencida (días + mora)        │
│    - Botón "+ Mora" en timeline cuotas   │          │   - Pago parcial (abonó + falta)         │
│    - Desglose de Mora en StatusCard      │          │   - Múltiples cuotas vencidas (resumen)  │
│                                          │          │ • Validación estricta de celular         │
│ C. Comprobante PDF (pdf_generator.dart): │          │   (no 00000000, prefijo +51)             │
│    - Estados: VENCIDA (rojo), PARCIAL,   │          │ • Botón de confirmación explícito        │
│      CON MOROSIDAD, PAGADA, EN PLAZO     │          │   "Enviar a WhatsApp"                    │
│    - Hidratación teléfono real cliente   │          │ • Actualización en WhatsAppPreviewScreen │
│    - Cláusulas financieras en footer     │          │   (reemplazo de "⏳ Pendiente" genérico) │
└──────────────────────────────────────────┘          └──────────────────────────────────────────┘
```

---

## 3. PLAN DE TRABAJO DETALLADO FASE POR FASE

### FASE 1: Esquema SQLite v30 y Motor de Morosidad Dual (Manual y Automático)

#### Paso 1.1: Migración SQLite v30 Idempotente (`local_db.dart`)
1. Elevar la versión a `30` en `local_db.dart`.
2. Actualizar la definición canónica en `_createDB` de la tabla `cuotas`:
   ```sql
   CREATE TABLE cuotas (
     id $idType,
     venta_id $intType,
     numero_cuota $intType,
     monto $realType,
     monto_pagado $realNullable DEFAULT 0.00,
     fecha_vencimiento $textType,
     estado $textNullable DEFAULT 'pendiente',
     monto_original $realNullable,
     mora_monto $realNullable DEFAULT 0.00,
     mora_porcentaje $realNullable DEFAULT 0.00,
     mora_automatica $intNullable DEFAULT 0,
     mora_frecuencia $textNullable,
     mora_intervalo_dias $intNullable DEFAULT 1,
     mora_tipo $textNullable DEFAULT 'fijo',
     mora_valor $realNullable DEFAULT 0.00,
     mora_fecha_inicio $textNullable,
     mora_ultima_aplicacion $textNullable,
     mora_periodos_acumulados $intNullable DEFAULT 0,
     FOREIGN KEY (venta_id) REFERENCES ventas (id) ON DELETE CASCADE
   );
   ```
3. En `_onUpgrade` para `oldVersion < 30`:
   - Invocar `ensureColumnExists` de manera defensiva para cada una de las 11 nuevas columnas.
   - Ejecutar script de curación e inicialización retroactiva:
     ```sql
     UPDATE cuotas SET monto_original = monto WHERE monto_original IS NULL;
     UPDATE cuotas SET mora_monto = 0.0 WHERE mora_monto IS NULL;
     UPDATE cuotas SET mora_automatica = 0 WHERE mora_automatica IS NULL;
     ```
   - Crear el índice de aceleración:
     ```sql
     CREATE INDEX IF NOT EXISTS idx_cuotas_mora ON cuotas(mora_automatica, estado, fecha_vencimiento);
     ```

#### Paso 1.2: Actualización del Modelo de Cuotas (`crm_models.dart`)
1. Enriquecer `InstallmentModel` con:
   - `final double? montoOriginal;`
   - `final double moraMonto;`
   - `final double moraPorcentaje;`
   - `final bool moraAutomatica;`
   - `final String? moraFrecuencia;`
   - `final int moraIntervaloDias;`
   - `final String moraTipo;`
   - `final double moraValor;`
   - `final String? moraFechaInicio;`
   - `final String? moraUltimaAplicacion;`
   - `final int moraPeriodosAcumulados;`
2. Getters computados de conveniencia:
   - `double get montoBase => montoOriginal ?? amount;`
   - `double get saldoPendiente => (amount - montoPagado) > 0 ? (amount - montoPagado) : 0.0;`
   - `bool get tieneMora => moraMonto > 0.01;`
3. Actualizar `fromJson`, `toSqlite` y `copyWith`.

#### Paso 1.3: Métodos del Motor de Morosidad en `SalesService` y `ClientService`
1. **`aplicarMorosidadManual(int cuotaId, {required String tipo, required double valor})`:**
   - Lee la cuota por ID. Si `monto_original` es null, toma el `monto` actual.
   - Si `tipo == 'fijo'`: `moraMonto = valor`, `moraPorcentaje = (valor / montoOriginal) * 100`.
   - Si `tipo == 'porcentaje'`: `moraPorcentaje = valor`, `moraMonto = (montoOriginal * (valor / 100))`.
   - `nuevoMonto = double.parse((montoOriginal + moraMonto).toStringAsFixed(2))`.
   - Actualiza la cuota en SQLite: `monto`, `mora_monto`, `mora_porcentaje`, `mora_tipo = tipo`, `mora_valor = valor`.
   - **Cascada Contable:**
     - `UPDATE ventas SET monto_total = (SELECT SUM(monto) FROM cuotas WHERE venta_id = vId) WHERE id = vId`.
     - Invoca `clientService.recalculateClientDebt(clientId)`.
     - Invoca `clientService.recalculateClientReputation(clientId)`.
2. **`quitarMorosidad(int cuotaId)`:**
   - Restaura `cuotas.monto = cuotas.monto_original`.
   - Pone `mora_monto = 0.0`, `mora_porcentaje = 0.0`, `mora_automatica = 0`, `mora_periodos_acumulados = 0`.
   - Sincroniza `ventas.monto_total` y recálculos contables del cliente.
3. **`configurarMorosidadAutomatica(int cuotaId, {required bool activa, String? frecuencia, int? intervaloDias, String? tipo, double? valor})`:**
   - Si `activa == true`: Asigna `mora_automatica = 1`, frecuencia, intervalo de días, fecha de inicio y ejecuta la primera corrida de acumulación si la cuota ya está vencida.
   - **REGLA DE CONSERVACIÓN ESTRICTA (Si `activa == false`):**
     - Actualiza únicamente `mora_automatica = 0`.
     - **PROHIBIDO tocar o resetear `mora_monto` ni `monto`.** La mora ya acumulada en los días previos permanece como deuda exigible.
4. **`evaluarMorosidadPeriodica({int? ventaId, int? clienteId})`:**
   - Motor reactivo que se ejecuta al abrir cualquier pantalla de detalle o al consultar deudas del cliente.
   - Para cuotas con `mora_automatica == 1` y no saldadas (`estado != 'pagado'`):
     - Determina días de retraso: `hoy.difference(fechaInicio).inDays`.
     - Determina periodos devengados: `periodos = max(0, diasRetraso ~/ intervaloDias)`.
     - Si `periodos > mora_periodos_acumulados`:
       - Aplica los periodos incrementales sin duplicaciones (idempotencia matemática).
       - Actualiza `cuotas.monto`, `mora_monto`, `mora_periodos_acumulados` y `ventas.monto_total`.

#### Paso 1.4: Modal UI de Configuración de Morosidad (`CuotaMorosidadModal`)
- Modal estilizado (`InteractiveSheetWrapper` responsive para Dark/Light mode):
  - **Selector de Modo:** Chip/Tab entre `Manual Directo` y `Automático Periódico`.
  - **Selector de Unidad:** Chip `Monto Fijo (S/)` vs `Porcentaje (%)`.
  - **Input numérico con Preview en vivo:**
    - Al escribir `5%`, calcula y muestra: `Monto Base: S/ 300.00` + `Mora: S/ 15.00` $\rightarrow$ **`Total Cuota: S/ 315.00`**.
  - **Selector de Frecuencia (si es Automático):**
    - Chips seleccionables: `Diario (1 día)`, `Cada 2 días`, `Cada 3 días`, `Semanal (7 días)`, `Quincenal (15 días)`, `Mensual (30 días)`, `Personalizado (N días)`.
    - Resumen explicativo: *"Se sumará automáticamente S/ 15.00 cada 1 día mientras la cuota permanezca vencida."*
  - **Acciones:**
    - Botón `Quitar Morosidad` (si la cuota ya tenía mora, en contorno rojo/peligro).
    - Botón `Cancelar`.
    - Botón `Guardar y Aplicar` (verde esmeralda).

---

### FASE 2: Taxonomía de Estados en Detalle (Préstamos y Ventas), Tarjetas de Resumen y Comprobante PDF

#### Paso 2.1: Implementación en Vista A (`sale_financial_detail_screen.dart` - `Imagen 1`)
1. **Unificación de formato de moneda:**
   - Corregir el formateo `1.200,00 S/` a `AppCurrency.format` (`S/ 1,200.00`) para consistencia con el resto del sistema.
2. **Inclusión de Botón de Morosidad y WhatsApp en cada Cuota:**
   - En la fila de cada cuota del `Cronograma de Pagos`:
     - Agregar botón interactivo `+ Mora` o `⚙️ Mora` junto al botón de `Icons.edit_calendar`.
     - Si la cuota ya tiene mora (`tieneMora == true`), mostrar pastilla destacada:  
       `Original: S/ 300.00 • + Mora: S/ 15.00 (5%) • Total: S/ 315.00`
     - Agregar botón `Recordar` con icono de WhatsApp que abre el **Estudio de Previsualización y Edición de WhatsApp**.
3. **Tarjeta de Resumen Superior:**
   - Mostrar el desglose de `Mora Acumulada` en las tarjetas de totales cuando existan recargos aplicados.

#### Paso 2.2: Implementación en Vista B (`sale_history_detail_screen.dart` - `Imágenes 2 y 3`)
1. **`DetailStatusCard` (`Imagen 3`):**
   - Incorporar en `ESTADO DEL PRÉSTAMO` y `ESTADO DE LA VENTA` la fila:
     `Mora Acumulada por Retraso: + S/ X.XX` (en color ámbar/rojo) entre el interés y el total.
   - Actualizar `Total a Devolver` y `Saldo Deudor Exigible` para reflejar la suma real de cuotas con moras.
2. **`SalePaymentTimeline` (`Imagen 2`):**
   - En cada cuota del `Plan de Cuotas`:
     - Mostrar badge y desglose de mora: `Base: S/ 300.00 • + Mora: S/ 15.00`.
     - Incorporar botón/chip interactivo `+ Mora` o `⚙️ Mora` para invocar `CuotaMorosidadModal`.
     - Actualizar el botón `Recordar` para abrir el **Estudio de Previsualización y Edición de WhatsApp**.

#### Paso 2.3: Corrección Integral del Comprobante PDF (`pdf_generator.dart` - `Imagen 4`)
1. **Taxonomía Completa en el Cronograma del PDF (A4 y Ticket 80mm):**
   - Erradicar la lógica simplista `pagado ? "PAGADO" : "PENDIENTE"`.
   - Comparar `fecha_vencimiento` contra la fecha del documento/hoy:
     * Si `estado == 'pagado'` o `saldo <= 0.01`: `PAGADA` (en verde `PdfColors.green700`).
     * Si `monto_pagado > 0` y fecha vencida: `VENCIDA • PAGO PARCIAL (Falta: S/ Y)` (en rojo/ámbar).
     * Si `monto_pagado > 0` y en plazo: `PAGO PARCIAL (Abonado: S/ X • Falta: S/ Y)` (en ámbar).
     * Si fecha vencida y sin pagos: `VENCIDA (hace X días)` (en rojo `PdfColors.red700`).
     * Si en plazo y sin pagos: `EN PLAZO / PENDIENTE`.
     * Si la cuota tiene mora: incluir en la línea o subfila `(+ Mora: S/ X.XX)`.
2. **Hidratación y Corrección de Teléfono del Cliente (`Tel: 00000000`):**
   - En `_buildHeader` y bloque de cliente:
     * Resolver teléfono en cascada: `saleData['cliente_telefono']` $\rightarrow$ `saleData['cliente_info']?['telefono']` $\rightarrow$ consulta a tabla `clientes`.
     * **Regla estricta:** Si el teléfono es `"00000000"`, `"000000000"` o nulo, **NO imprimir `Tel: 00000000`**.
     * Si el cliente tiene teléfono registrado (ej. `922836879` de la Imagen 2), imprimir `Tel: 922836879`.
3. **Condiciones Financieras en Pie de Página:**
   - Detectar si el documento es `COMPROBANTE DE PRÉSTAMO` o `COMPROBANTE DE VENTA AL CRÉDITO`.
   - **PROHIBIR estrictamente** el texto de cotizaciones (`"Válida por 7 días"`).
   - Utilizar condiciones financieras legítimas:  
     `"Condiciones: El pago puntual de cada cuota evita la generación de recargos por mora. Comprobante de crédito emitido para control y cobranza."`

---

### FASE 3: Refinamiento de WhatsApp y Estudio de Previsualización y Edición Segura

#### Paso 3.1: Auditoría y Reemplazo de TODOS los Disparadores de WhatsApp
1. **Disparador 1 — Banner rojo de mora en Perfil del Cliente (`client_stats_header.dart`):**
   - Reemplazar el `ConfirmActionModal` ciego por la invocación del nuevo estudio:  
     `WhatsAppPreviewModal.showClientOverdueSummary(...)`.
2. **Disparador 2 — Botón `Recordar` en `SalePaymentTimeline` (`sale_payment_timeline.dart`):**
   - Reemplazar el modal de solo lectura por:  
     `WhatsAppPreviewModal.showCuotaReminder(...)`.
3. **Disparador 3 — Botón `Recordar` en `SaleFinancialDetailScreen` (`sale_financial_detail_screen.dart`):**
   - Conectar cada cuota al nuevo estudio de WhatsApp.
4. **Disparador 4 — Botón de WhatsApp en Footer de Detalle (`sale_action_footer.dart`):**
   - Actualizar el generador de texto de `WhatsAppPreviewScreen`.

#### Paso 3.2: Rediseño del Estudio de WhatsApp (`WhatsAppPreviewModal` / `CuotaReminderModal`)
1. **Área de Edición Multilínea en App:**
   - Reemplazar el widget `Text` de vista previa estática por un `TextFormField` multilínea editable (`minLines: 4`, `maxLines: 10`) con estilo adaptado a tema oscuro/claro.
   - El comerciante puede escribir, borrar o modificar cualquier parte del mensaje dentro de la app sin ningún riesgo de envío accidental.
2. **Plantillas Dinámicas con Desglose de Mora:**
   - Generación automática de plantillas según el caso:
     * **Caso Cuota Vencida con Mora:**
       ```text
       Hola Jj 👋. Le recordamos que su Cuota #1 por S/ 300.00 venció el 24/10/2026 (hace 12 días).
       ⚠️ Recargo por morosidad: + S/ 15.00 (5.0%)
       Total a cancelar: S/ 315.00.
       Puede realizar su abono por Yape, Plin o en tienda física. ¡Muchas gracias!
       ```
     * **Caso Cuota con Pago Parcial:**
       ```text
       Hola Jj 👋. Le recordamos que de su Cuota #1 (S/ 300.00) cuenta con un abono de S/ 100.00.
       Saldo pendiente por pagar: S/ 200.00.
       ```
     * **Caso Resumen de Múltiples Cuotas Vencidas (desde el Perfil del Cliente):**
       ```text
       Hola Jj 👋. Le escribimos de la tienda para informarle que mantiene 2 cuotas vencidas por un total exigible de S/ 615.00:
       ▪ Cuota #1: S/ 315.00 (Venció hace 12 días • incluye S/ 15.00 de mora)
       ▪ Cuota #2: S/ 300.00 (Venció hace 5 días)
       Agradeceremos regularizar su pago a la brevedad. ¡Muchas gracias!
       ```
3. **Herramientas de Utilidad:**
   - Botón `Copiar Texto` con feedback visual (`CustomSnackBar`).
   - Botón `Restaurar Mensaje Original`.
   - Campo de teléfono validado con prefijo internacional (`+51`).
4. **Confirmación Segura:**
   - Botón verde `Enviar por WhatsApp` que valida el número, formatea `wa.me/$phone?text=$encodedMsg` y recién ahí ejecuta `launchUrl`.

#### Paso 3.3: Actualización del Generador en `whatsapp_preview_screen.dart` (`Imagen 5`)
- En el bloque 4 (`CRONOGRAMA DE PAGOS`, líneas 533–546):
  * Reemplazar la lista genérica de `⏳ Pendiente` por los estados reales:
    - `✅ Cuota 1: *S/ 300.00* - Pagada`
    - `🔴 Cuota 1: *S/ 315.00* (Venció: 24/10/2026 - Hace 12 días) - ⚠️ Vencida (+ Mora S/ 15.00)`
    - `🟠 Cuota 2: *S/ 300.00* (Abonado: S/ 100.00 | Falta: S/ 200.00) - ⚠️ Pago Parcial`
    - `⏳ Cuota 3: *S/ 300.00* (Vence: 07/11/2026) - En plazo`

---

## 4. MATRIZ DE RIESGOS Y ESTRATEGIA ADVERSARIAL

| Riesgo Técnico Potencial | Impacto | Causa Raíz Probable | Mitigación Adversarial |
|---|---|---|---|
| **Pérdida de centavos por redondeos sucesivos de mora** | Alto | Operaciones en punto flotante (`double`) | Redondear en cada cómputo con `double.parse(val.toStringAsFixed(2))` y cuadrar contra `ventas.monto_total`. |
| **Acumulación infinita de mora al reabrir la pantalla** | Crítico | Motor ejecuta suma sin cotejar periodos ya cobrados | Almacenar `mora_periodos_acumulados`. Solo devengar la diferencia: `periodosNuevos = periodosTotales - mora_periodos_acumulados`. Si `periodosNuevos <= 0`, no alterar. |
| **Pérdida de mora acumulada al desactivar modo automático** | Crítico | El switch apaga la función y resetea campos | **Regla estricta:** Al desactivar automático, SOLO se actualiza `mora_automatica = 0`. El `mora_monto` se conserva intacto en la cuota y en la deuda. |
| **Discrepancia entre las dos vistas de detalle (A y B)** | Alto | Actualizar una vista y olvidar la otra | Componentes y servicios compartidos (`CuotaMorosidadModal`, `WhatsAppPreviewModal`, `sales_service.dart`). |
| **Teléfono con ceros en PDF (`Tel: 00000000`)** | Medio | Lectura de placeholder sin sanitizar | Sanitizador regex: si `phone.replaceAll('0', '').isEmpty`, tratar como nulo y suprimir la línea. |
| **Envío prematuro de WhatsApp por error de tipeo** | Alto | Lanzar WhatsApp inmediatamente sin editor interno | Todo botón de `Recordar` pasa obligatoriamente por el editor multilínea dentro de la aplicación. |

---

## 5. BATERÍA DE PRUEBAS ADVERSARIALES AUTOMATIZADAS (PASO 4)

Archivo de pruebas a crear:  
[`app_movil/test/motor_morosidad_estados_pdf_y_whatsapp_test.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/test/motor_morosidad_estados_pdf_y_whatsapp_test.dart)

1. **Test 1 (Migración SQLite v30 e Idempotencia):**
   - Validar la existencia de las 11 nuevas columnas en `cuotas`.
   - Comprobar migración fluida desde v29 sin pérdida de datos e inicialización `monto_original = monto`.
2. **Test 2 (Morosidad Manual - Fija y Porcentual):**
   - Cuota de `S/ 300.00` con recargo fijo de `S/ 20.00` $\rightarrow$ Total `S/ 320.00`.
   - Cuota de `S/ 300.00` con `5%` $\rightarrow$ Total `S/ 315.00`.
   - Quitar morosidad $\rightarrow$ Retorno exacto a `S/ 300.00`.
3. **Test 3 (Morosidad Automática Periódica Proyectada e Idempotente):**
   - Simulación de cuota vencida hace 3 días con frecuencia diaria al 5% (`S/ 15.00/día`):
     * Día 1: `S/ 315.00`
     * Día 2: `S/ 330.00`
     * Día 3: `S/ 345.00`
   - Re-ejecutar el motor múltiples veces el mismo día para asegurar que no se duplica la mora.
4. **Test 4 (Regla de Conservación al Desactivar Automático):**
   - Desactivar la morosidad periódica en el Día 3 (`S/ 345.00`).
   - Comprobar que `mora_automatica == 0`, pero `cuotas.monto` permanece en `S/ 345.00` y `mora_monto` en `S/ 45.00`.
5. **Test 5 (Impacto Contable 360° en Deuda del Cliente):**
   - Al generarse mora en una o más cuotas, verificar que `ventas.monto_total` aumenta en la misma proporción y `clientes.deuda_total` se sincroniza exactamente en centavos.
6. **Test 6 (Taxonomía en PDF y Supresión de `Tel: 00000000`):**
   - Verificar que cuotas vencidas se rotulan en rojo con días de atraso en el PDF.
   - Verificar que clientes con teléfono real imprimen su teléfono legítimo y si es `00000000` se suprime.
   - Verificar que el pie de página financiero no incluye `"Válida por 7 días"`.
7. **Test 7 (Estudio de WhatsApp y Edición Segura):**
   - Renderizar `WhatsAppPreviewModal` con cuota vencida y mora.
   - Probar edición libre del texto dentro del `TextFormField` y validación de teléfono antes de abrir la URL.
8. **Test 8 (No Regresión con Bloque 1):**
   - Ejecución completa de [`test/prestamos_anulacion_atomica_y_cronogramas_historicos_test.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/test/prestamos_anulacion_atomica_y_cronogramas_historicos_test.dart) (100% aprobadas).

---

## 6. PROTOCOLO DE PARE Y CONFIRMACIÓN DE EJECUCIÓN

Conforme a las instrucciones del usuario:
> **IMPORTANTE:** En este primer paso **NO modifiques ningún archivo de código todavía**. Inspecciona a fondo todos los archivos... y genera un archivo de Plan de Trabajo muy detallado bajo nuestra metodología de Loop Autónomo + Árbitro Interno Adversarial, explicando cada fase para que yo lo revise antes de darte la orden de ejecución.

**ESTADO ACTUAL:**
- ✅ Cotejo forense completado contra las 5 capturas reales.
- ✅ Identificadas y documentadas las dos pantallas de detalle (`SaleFinancialDetailScreen` e `SaleHistoryDetailScreen`).
- ✅ Plan maestro actualizado y blindado en `analisis_proyecto/PLAN_PARTE2_MOTOR_MOROSIDAD_ESTADOS_PDF_Y_ESTUDIO_WHATSAPP.md`.
- ⏸️ **CERO LÍNEAS DE CÓDIGO MODIFICADAS HASTA RECIBIR LA ORDEN DE EJECUCIÓN DEL USUARIO.**


---

## 🏁 INFORME DE VERIFICACIÓN FINAL Y AUDITORÍA ADVERSARIAL (BLOQUE 2 - CIERRE AL 100%)

### 1. Frecuencias de Tiempo Completadas (Paso 1.4 y Frecuencias Extendidas)
- **Implementación:**
  - `Cada 2 días` (`cada_2_dias`, `intervaloDias = 2`).
  - `Cada 3 días` (`cada_3_dias`, `intervaloDias = 3`).
  - `Personalizado` (`personalizado`, `intervaloDias = N >= 1` con campo numérico y validación contra valores nulos o $\le 0$).
  - Integradas en `CuotaMorosidadModal` y con deducción automática de fallback en `SalesService.configurarMorosidadAutomatica`.
  - Verificado en Test 9 con evaluación de periodos devengados deviniendo en cálculo exacto.

### 2. Evaluación Automática en Perfil de Cliente y Apagado al Pagar
- **Implementación:**
  - `ClientService.getClientDebts` y `ClientService.getClientLedger` ejecutan de forma reactiva `SalesService.evaluarMorosidadPeriodica(clienteId: clientId)` al abrirse el Perfil del Cliente, manteniendo el banner rojo de cuotas vencidas y el estado de cuenta siempre al día.
  - Al completar el pago de una cuota (`estado = 'pagado'`), `ClientService.registerPayment`, `ClientService.recalculateClientDebt` y `SalesService.desanularVenta` apagan de inmediato `mora_automatica = 0`.
  - Evaluaciones posteriores respetan la cuota pagada y no generan mora adicional (Verificado en Test 10).

### 3. Soporte de Morosidad en Ventas al Crédito sin Cuotas Previas (Auto-Heal)
- **Implementación:**
  - En `SalesService.getSaleDetail`, `ClientService.getClientDebts` y `ClientService.registerPayment`: si una venta al crédito o con saldo pendiente no tiene filas en `cuotas`, se autogenera la Cuota #1 con monto igual al saldo pendiente, permitiendo gestionar morosidad y amortizaciones de inmediato sin inconsistencias.
  - Verificado en Test 11 con inserción directa y curación automática instantánea.

### 4. Taxonomía de Estados y Formatos en WhatsApp y PDF
- **Implementación:**
  - En plazo con abono: `🟠 Cuota #X: *S/ 300.00* (Vence: DD/MM/YYYY) - Pago Parcial (Abonado: S/ 100.00 | Falta: S/ 200.00)`.
  - Vencida con abono: `🔴 Cuota #X: *S/ 300.00* - Vencida hace Y d • Pago Parcial (Abonado: S/ 100.00 | Falta: S/ 200.00)`.
  - Con morosidad: `(Orig: S/ 300.00 + Mora: S/ 15.00 = Total: S/ 315.00)`.
  - En PDF: se suprimió el carácter incompatible `•` reemplazándolo por `|` para evitar fallbacks o advertencias de fuente en entornos offline, manteniendo el diseño responsivo en A4 y Ticket 80mm.
  - Verificado en Test 12.

### 5. Cláusula Estricta Anti-Falsos Positivos
- **`analyze_files`:** 0 issues / `No errors` en todo el proyecto.
- **Pruebas unitarias ejecutadas:**
  - `test/motor_morosidad_estados_pdf_y_whatsapp_test.dart`: 12/12 tests PASSING.
  - `test/prestamos_anulacion_atomica_y_cronogramas_historicos_test.dart`: 7/7 tests PASSING.
