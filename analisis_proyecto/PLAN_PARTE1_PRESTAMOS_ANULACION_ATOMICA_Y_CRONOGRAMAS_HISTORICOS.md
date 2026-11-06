# PLAN MAESTRO: ANULACIÓN ATÓMICA DE PRÉSTAMOS Y VENTAS, REVERSIÓN CONTABLE 360° Y CRONOGRAMAS HISTÓRICOS EN OPERACIONES FINANCIERAS (PARTE 1)

**Documento de Especificación de Reingeniería y Plan de Ejecución**  
**Fecha:** Noviembre 2026  
**Rama:** `dev/mejoras-v9.0-comercializacion-seguridad`  
**Metodología:** Loop Autónomo + Árbitro Interno Adversarial  
**Estado:** PENDIENTE DE REVISIÓN Y APROBACIÓN POR EL USUARIO (FASE DE PLANIFICACIÓN - CERO MODIFICACIONES DE CÓDIGO)

---

## 1. RESUMEN EJECUTIVO Y DIAGNÓSTICO FORENSE CON EVIDENCIAS

A partir de la inspección exhaustiva de los archivos de base de datos SQLite, servicios de ventas y clientes, estado de cuenta contable y el modal de `Operaciones Financieras`, junto con el análisis forense de las 5 capturas proporcionadas (`Imágenes 1, 2, 3, 4 y 5`), se han determinado las causas raíces exactas y los cuellos de botella del sistema.

### 1.1 Diagnóstico de las Imágenes 1 y 5: Crash Fatal al Anular Préstamos / Ventas
* **Evidencia en Captura (`Imagen 1` y `5`):**  
  Al intentar anular el `Préstamo #13` (ID interno de base de datos 14) para el cliente `Jj`, la app estalla con la siguiente excepción no controlada:
  ```text
  Error local al anular venta: DatabaseException(no such column: motivo_anulacion (code 1 SQLITE_ERROR[1]): , while compiling: UPDATE ventas SET is_archived = ?, motivo_anulacion = ? WHERE id = ?) sql 'UPDATE ventas SET is_archived = ?, motivo_anulacion = ? WHERE id = ?' args [1, Cliente arrepentido, 14]
  ```
* **Auditoría Forense en Código:**
  1. En `app_movil/lib/core/database/local_db.dart` (línea 691), la columna `motivo_anulacion TEXT` fue agregada en el método `_createDB` para instalaciones nuevas.
  2. **Sin embargo, en `_onUpgrade` (líneas 44–280), dicha columna NUNCA fue migrada para bases de datos existentes.** Los dispositivos que actualizaron desde versiones anteriores (v19, v20, v25, v27, v28) tienen la tabla `ventas` sin la columna `motivo_anulacion`, y carecen además de la columna canónica de auditoría `fecha_anulacion TEXT`.
  3. En `sales_service.dart` (líneas 663–666), el método `voidSale` asume que ambas columnas existen:
     ```dart
     await txn.update('ventas', {
       'is_archived': 1,
       'motivo_anulacion': motivoAnulacion
     }, where: 'id = ?', whereArgs: [saleId]);
     ```
  4. Como la columna no existe en la base de datos del dispositivo, SQLite aborta la transacción y revierte todos los cambios. **La venta/préstamo nunca se anula, la deuda no se descuenta y el sistema queda bloqueado.**

---

### 1.2 Diagnóstico de la Imagen 2: Inconsistencia Contable, Alertas Huérfanas y Badge de Reputación
* **Evidencia en Captura (`Imagen 2`):**
  * Cliente `Jj` muestra un banner rojo crítico: `2 cuotas vencidas — Deuda más antigua: hace 12 días`.
  * En `Estado de Cuenta`: `Todos 1`, `Cargos 1`, `Abonos 0`, mostrando `Préstamo #13 - S/ 1,200.00 | Saldo Deuda: S/ 1,200.00`.
  * En la cabecera del cliente, su badge de reputación sigue mostrando alegremente: `👍 BUENO` en azul.
* **Auditoría Forense en Código:**
  1. **Falso Estado de Cuotas al Anular:** En `sales_service.dart` (líneas 877–880), cuando una venta/préstamo se intenta anular, el código ejecutaba:
     ```dart
     await txn.update('cuotas', {
       'monto_pagado': 0,
       'estado': 'pendiente' // ❌ ERROR CRÍTICO: Deja las cuotas como 'pendiente' en lugar de 'anulada'
     }, where: 'venta_id = ?', whereArgs: [saleId]);
     ```
     Si las cuotas quedan con `estado = 'pendiente'`, cualquier consulta directa o subconsulta que analice cuotas por vencer o vencidas sigue encontrándolas como deudas activas.
  2. **Desincronización de Pagos Huérfanos:** En `sales_service.dart` (línea 865):
     ```dart
     await txn.rawUpdate(
       "UPDATE pagos SET venta_id = NULL, nota = COALESCE(nota, '') || ' (Desvinculado por Anulación Venta #$saleId)' WHERE venta_id = ?", 
       [saleId]
     );
     ```
     Al desvincular los pagos estableciendo `venta_id = NULL`, en `client_service.dart` (`getClientLedger`, línea 135):
     `WHERE p.cliente_id = ? AND (v.is_archived IS NULL OR v.is_archived = 0)`
     Como `v.is_archived` es `NULL` (porque `venta_id` es null), los pagos desvinculados siguen sumando como movimientos de abono activos, corrompiendo el saldo del cliente en el Libro Contable / Estado de Cuenta.
  3. **Omisión de Recálculo de Reputación en Préstamos:** En `client_service.dart` (`registerLoan`, líneas 1227–1291), al registrar un préstamo se llama a `recalculateClientDebt(clientId)`, pero **NUNCA se llama a `recalculateClientReputation(clientId)`**. Como consecuencia, cuando se crea un préstamo con cuotas que nacen vencidas, la reputación del cliente permanece estática en su valor previo (`bueno` / `PLATA`) sin enterarse de la mora.
  4. **Badge sin Evaluación de Mora Activa en Tiempo Real:** En `client_stats_header.dart` (líneas 382–440), el badge lee estáticamente `client.tier` o `client.nivelConfianza`. Si el cliente tiene cuotas vencidas activas (`overdueCount > 0`), el badge no refleja el estado de `⚠️ EN OBSERVACIÓN` o `CON RETRASO / MOROSO` de inmediato.

---

### 1.3 Diagnóstico de las Imágenes 3 y 4: Limitaciones Críticas y Recortes Visuales en `Operaciones Financieras`
* **Evidencias en Capturas (`Imágenes 3 y 4`):**
  * **Restricción de Fechas Pasadas:**
    * En el modo de **1 sola cuota** (`Imagen 3`), el picker `Fecha de Vencimiento (1 cuota)` tiene configurado `firstDate: DateTime.now()` (`client_finance_actions_modal.dart`, línea 700). Es imposible registrar un préstamo que se otorgó en el pasado y venció hace días, semanas o meses. Además, no existe un selector para la `Fecha de Emisión / Entrega del Préstamo` (se asigna a ciegas `DateTime.now()`).
    * En el modo **Fraccionado en cuotas** (`Imagen 4`), la `Fecha Base / Inicio` tiene `firstDate: DateTime.now().subtract(const Duration(days: 30))` (`client_finance_actions_modal.dart`, línea 720). Si el comerciante quiere registrar un préstamo histórico de hace 3 meses, 6 meses o 2 años, el selector está completamente bloqueado.
  * **Falta de Estados en el Cronograma Generado:**
    * Al registrar un préstamo histórico en múltiples cuotas, las cuotas pasadas que el cliente ya pagó no se pueden marcar como `Ya Pagada` ni `Pago Parcial`.
    * En `client_service.dart` (`registerLoan`, líneas 1265–1275), todas las cuotas se insertan forzosamente con `monto_pagado: 0.0` y `estado: 'pendiente'`. El préstamo nace artificialmente con el 100% de la deuda total, inflando la deuda del cliente con dinero que ya fue pagado hace meses y generando falsas cuotas vencidas.
  * **Recorte Visual de Controles en Pantalla (`Imagen 3`):**
    * Debajo de la barra de pestañas `Retirar | Préstamo`, los botones de método de pago (`Efectivo`, `Yape`, `Plin`) sufren recorte en su borde superior debido a la ausencia de margen y a la colisión del viewport de `Expanded(child: TabBarView(...))` con el `ListView` interior.
    * En `Motivo / Detalle`, los chips de sugerencia (`_motivosSug`) están contenidos en un `SingleChildScrollView` horizontal donde el chip a la derecha de `Fiado mercadería` queda cortado abruptamente en el borde derecho de la pantalla sin envolver (`Wrap`) el contenido.

---

## 2. PROTOCOLO DEL ÁRBITRO INTERNO ADVERSARIAL (STRESS TESTING Y CASOS LÍMITE)

Para garantizar que esta reingeniería no cause regresiones ni fallos contables, el Árbitro Interno Adversarial someterá el diseño a las siguientes 7 pruebas de fuego:

1. **Prueba de Fuego 1: Migración Defensiva de Base de Datos sin Pérdida de Datos Existentes:**
   * Un dispositivo con base de datos en versión 25, 27 o 28 que ejecuta la app debe migrar a versión 29 agregando de forma idempotente las columnas `is_archived`, `motivo_anulacion` y `fecha_anulacion` en `ventas`, y asegurando columnas en `cuotas` y `pagos`. Si las columnas ya existen por algún motivo, la migración no debe arrojar error ni duplicar índices.
2. **Prueba de Fuego 2: Anulación Atómica de Préstamo sin Abonos (Caso de Imagen 1):**
   * Anular un préstamo de S/ 1,200.00 con 0 abonos.
   * La transacción SQLite debe:
     * Actualizar `ventas`: `is_archived = 1`, `motivo_anulacion = 'Cliente arrepentido'`, `fecha_anulacion = DateTime.now().toIso8601String()`, `estado_pago = 'anulado'`.
     * Actualizar `cuotas`: `estado = 'anulada'`, `monto_pagado = 0.0`.
     * No tocar stock físico (los préstamos no tienen `venta_items`).
     * Descontar S/ 1,200.00 de `clientes.deuda_total` dejándola en S/ 0.00 exacto.
     * Al volver al perfil del cliente: el banner rojo desaparece de inmediato, el préstamo desaparece del balance activo en `Estado de Cuenta`, y la analítica reporta 0 préstamos activos.
3. **Prueba de Fuego 3: Anulación de Préstamo con Abonos Parciales Previos:**
   * Préstamo de S/ 1,000.00 con cuota 1 pagada de S/ 250.00 y cuota 2 vencida.
   * Si el usuario anula el préstamo:
     * Las cuotas pasan a `estado = 'anulada'`.
     * Los abonos ya realizados deben gestionarse contablemente de forma limpia: si se anula la operación, los pagos de esa venta no deben seguir figurando como amortizaciones de una venta activa ni descalabrar el saldo deudor. El sistema debe anular/desvincular con contrasiento o trazabilidad explícita sin dejar saldos negativos.
4. **Prueba de Fuego 4: Registro de Préstamo Histórico Ultra-Antiguo (Año 2024 / 2025):**
   * Usuario registra un préstamo entregado el `15/01/2025` de S/ 600.00 en 6 cuotas de S/ 100.00 mensuales.
   * El usuario marca las cuotas 1, 2, 3 y 4 como `Ya Pagada` (S/ 100.00 c/u, total pagado S/ 400.00), la cuota 5 como `Pago Parcial` (pagó S/ 50.00, falta S/ 50.00), y la cuota 6 como `Pendiente / Vencida` (falta S/ 100.00).
   * Al guardar:
     * `ventas`: `monto_total = 600.0`, `monto_pagado = 450.0`, `abono_inicial = 450.0`, `estado_pago = 'parcial'`, `fecha_venta = '2025-01-15T...'`.
     * `cuotas`: 4 cuotas en estado `pagado` (monto_pagado 100), 1 cuota en estado `parcial` (monto_pagado 50), 1 cuota en estado `vencida` o `pendiente` (monto_pagado 0).
     * `pagos`: se generan los registros de abono histórico con sus fechas de pago históricas y vinculados a sus cuotas correspondientes.
     * `clientes.deuda_total`: suma exactamente el saldo restante real (S/ 150.00), **NO los S/ 600.00 originales**.
5. **Prueba de Fuego 5: Sincronización Inmediata del Badge de Reputación:**
   * Si un cliente tiene cuotas vencidas activas, el badge debe alertar en tiempo real (`⚠️ MOROSO` o `⚠️ EN OBSERVACIÓN`).
   * Al anular el préstamo que originó las cuotas vencidas (o al pagarlo completamente), el recálculo atómico de reputación restaura automáticamente el badge a `BUENO` / `PLATA` sin requerir cerrar y reabrir la app.
6. **Prueba de Fuego 6: Inmunidad a Fallos de Redondeo en Soles (Céntimos):**
   * Cuotas con céntimos fraccionados (ej. S/ 100.00 entre 3 cuotas: 33.34, 33.33, 33.33). La suma de cuotas debe cuadrar con precisión milimétrica con el `monto_total` de la venta.
7. **Prueba de Fuego 7: Cero Recortes Visuales en Cualquier Resolución de Pantalla:**
   * El modal de `Operaciones Financieras` debe renderizarse con espaciado superior e inferior limpio, los chips de método de pago y motivos deben adaptarse fluidamente en `Wrap` responsivo sin desbordar ni cortarse con la cabecera.

---

## 3. ESPECIFICACIÓN TÉCNICA Y ARQUITECTURA POR FASES

### FASE 1: Corrección de Esquema SQLite y Transacción Atómica de Anulación

#### 1.1 Migración de Base de Datos (SQLite v28 -> v29)
* **Archivo:** `app_movil/lib/core/database/local_db.dart`
* **Cambios:**
  1. Incrementar versión de la base de datos a `version: 29` en `_initDB`.
  2. En `_createDB`, actualizar la definición canónica de `CREATE TABLE ventas` para incluir:
     ```sql
     is_archived INTEGER DEFAULT 0,
     motivo_anulacion TEXT,
     fecha_anulacion TEXT,
     ```
  3. En `_onUpgrade`, incorporar el bloque de migración para `oldVersion < 29`:
     ```dart
     if (oldVersion < 29) {
       try {
         await ensureColumnExists(db, 'ventas', 'is_archived', 'INTEGER DEFAULT 0');
         await ensureColumnExists(db, 'ventas', 'motivo_anulacion', 'TEXT');
         await ensureColumnExists(db, 'ventas', 'fecha_anulacion', 'TEXT');
         await ensureColumnExists(db, 'cuotas', 'estado', "TEXT DEFAULT 'pendiente'");
         await ensureColumnExists(db, 'cuotas', 'monto_pagado', 'REAL DEFAULT 0.0');
         await ensureColumnExists(db, 'pagos', 'fecha_pago', 'TEXT');
         await db.execute('CREATE INDEX IF NOT EXISTS idx_ventas_archived ON ventas(is_archived, negocio_id)');
         await db.execute('CREATE INDEX IF NOT EXISTS idx_cuotas_estado ON cuotas(estado, venta_id)');
         debugPrint("✅ Migración V29 completada: Columnas de anulación y cuotas blindadas.");
       } catch (e) {
         debugPrint("Error en migración V29: $e");
       }
     }
     ```
  4. **Blindaje Defensivo en Runtime:** En `SalesService.voidSale`, antes de ejecutar el UPDATE, invocar defensivamente `ensureColumnExists` sobre `ventas` para blindar casos donde la base de datos no haya disparado `onUpgrade`.

#### 1.2 Transacción Atómica de Anulación en `SalesService`
* **Archivo:** `app_movil/lib/features/smart_quotation/services/sales_service.dart`
* **Método:** `voidSale(int saleId, int negocioId, String motivoAnulacion)`
* **Lógica Atómica:**
  ```dart
  await db.transaction((txn) async {
    final nowIso = DateTime.now().toIso8601String();

    // 1. Marcar venta o préstamo como anulada
    await txn.update('ventas', {
      'is_archived': 1,
      'motivo_anulacion': motivoAnulacion,
      'fecha_anulacion': nowIso,
      'estado_pago': 'anulado',
    }, where: 'id = ?', whereArgs: [saleId]);

    // 2. Marcar cuotas como anuladas para que queden inactivas
    await txn.update('cuotas', {
      'estado': 'anulada',
    }, where: 'venta_id = ?', whereArgs: [saleId]);

    // 3. Manejo de Stock: Solo si la venta tiene items físicos (NO aplica a préstamos)
    final items = await txn.query('venta_items', where: 'venta_id = ?', whereArgs: [saleId]);
    if (items.isNotEmpty) {
      // Revertir stock según modo INDEPENDIENTE o COMPARTIDO
      ...
    }

    // 4. Cotización asociada: marcar ANNULLED si existe
    if (saleRows.first['cotizacion_id'] != null) {
      await txn.update('smart_quotations', {'status': 'ANNULLED'}, where: 'id = ?', whereArgs: [saleRows.first['cotizacion_id']]);
    }

    // 5. Manejo contable de abonos existentes:
    // Marcar pagos de esta venta como anulados/desvinculados con nota de auditoría
    await txn.rawUpdate(
      "UPDATE pagos SET nota = COALESCE(nota, '') || ' [ANULADO - Venta #$saleId]' WHERE venta_id = ?",
      [saleId]
    );

    // 6. Revertir puntos de fidelización si aplica
    ...
  });

  // 7. Fuera de transacción: Recalcular deuda, saldo a favor y reputación
  if (saleRows.first['cliente_id'] != null) {
    int clientId = saleRows.first['cliente_id'] as int;
    final clientService = ClientService();
    await clientService.recalculateClientDebt(clientId);
    await clientService.recalculateClientSaldoAFavor(clientId);
    await clientService.recalculateClientReputation(clientId);
  }
  ```

---

### FASE 2: Reversión Contable 360°, Estado de Cuenta y Reputación Dinámica

#### 2.1 Reversión Contable en `ClientService`
* **Archivo:** `app_movil/lib/features/smart_quotation/services/client_service.dart`
* **Mejoras en `recalculateClientDebt`:**
  * La consulta de deuda actual filtra estrictamente `WHERE cliente_id = ? AND estado_pago != 'pagado' AND (is_archived IS NULL OR is_archived = 0)`.
  * Las ventas y préstamos anulados quedan con `is_archived = 1`, por lo que su deuda pendiente se excluye al 100%.
  * Si la deuda restante es menor a S/ 0.02, se trunca a `0.00` exacto, evitando micro-saldos negativos.
* **Mejoras en `getClientLedger` (Estado de Cuenta):**
  * Los cargos de ventas o préstamos archivados (`is_archived = 1`) no se suman al balance deudor.
  * Si el usuario selecciona el filtro `Todos`, los movimientos anulados se muestran con su badge de `Anulado` y monto `S/ 0.00` (o se excluyen según preferencia limpia) sin sumar al acumulador de `runningBalance`.
  * Los contadores de chips (`Todos X`, `Cargos Y`, `Abonos Z`) se sincronizan exactamente con las operaciones activas.
* **Mejoras en `getClientDebts`:**
  * Solo retorna operaciones con `is_archived = 0`. Al anular el `Préstamo #13`, `provider.currentClientDebts` queda vacío para ese préstamo, provocando la desaparición inmediata del banner rojo de cuotas vencidas.

#### 2.2 Sincronización en Tiempo Real de la Reputación del Cliente
* **Archivos:**
  * `app_movil/lib/features/smart_quotation/services/client_service.dart`
  * `app_movil/lib/features/smart_quotation/widgets/crm/client_stats_header.dart`
  * `app_movil/lib/features/smart_quotation/screens/crm/client_detail_screen.dart`
* **Lógica:**
  1. En `client_service.dart` (`recalculateClientReputation`):
     * Las cuotas vencidas se consultan uniendo `cuotas` con `ventas` con la condición `(v.is_archived IS NULL OR v.is_archived = 0) AND c.estado != 'anulada'`.
     * Si `cuotasVencidasActivas > 0`, se penaliza el score y se asigna el nivel `OBSERVACION` (legacy: `moroso`).
     * Si no hay cuotas vencidas, el score se basa en su puntualidad y racha.
  2. En `client_stats_header.dart` (`_buildTrustBadge`):
     * Verificar si el cliente tiene mora activa (`provider.currentClientDebts` contiene cuotas con fecha vencida).
     * Si hay mora activa detectada, el badge debe mostrar prioritariamente la alerta de retraso (ej. `⚠️ CON RETRASO` o `⚠️ OBSERVACIÓN` en rojo/ámbar), evitando presentar `👍 BUENO` en azul mientras haya un banner rojo de cuotas vencidas debajo.
  3. En `client_detail_screen.dart` (`_refreshData`):
     * Al entrar al perfil del cliente o tras completar cualquier operación financiera, ejecutar `clientService.recalculateClientReputation(client.id)` para que los datos siempre estén al día.

---

### FASE 3: Reingeniería de `Operaciones Financieras` para Préstamos Históricos

#### 3.1 Modelo de Datos y Soporte de Fechas Históricas
* **Archivo:** `app_movil/lib/features/smart_quotation/widgets/crm/client_finance_actions_modal.dart`
* **Desbloqueo de Fechas:**
  1. Permitir `firstDate: DateTime(2015, 1, 1)` y `lastDate: DateTime.now().add(const Duration(days: 730))` en:
     * `_selectDueDate` (Vencimiento de cuota única).
     * `_selectStartDate` (Fecha base / inicio de cobro para cuotas periódicas).
     * `_selectLoanEmissionDate` (**NUEVO**: Fecha en que se entregó el dinero del préstamo).
     * `_editInstallmentDate` (Edición de fecha individual de una cuota del cronograma).
  2. Agregar campo de UI para **`Fecha de Emisión / Entrega`**:
     * Permite indicar qué día se entregó el dinero (ej. hace 6 meses).
     * Por defecto es `DateTime.now()`, pero con un toque permite elegir cualquier fecha pasada.

#### 3.2 Cronograma Generado Inteligente con Definición de Estados Previos
* **Componente:** `_buildInstallmentRow` en el `Cronograma Generado`.
* **Comportamiento:**
  1. **Determinación Automática Inicial:**
     * Cuando se genera el cronograma con una fecha base en el pasado, para cada cuota:
       * Si `dueDate.isBefore(today)`: nace automáticamente como `vencida` (o `pendiente` si el usuario no la marca como pagada).
       * Si `dueDate.isAfter(today)` o es hoy: nace como `pendiente`.
  2. **Selector Interactivo de Estado por Cuota:**
     * Al tocar la cuota o presionar un chip de estado a la derecha, se despliega un mini-selector rápido con 3 opciones:
       1. **`Pendiente / Vencida`** (`montoPagado = 0.0`): Falta pagar completamente.
       2. **`Ya Pagada`** (`montoPagado = cuota.amount`): El cliente cumplió esta cuota en el pasado. Se marca con check verde y badge `PAGADA`.
       3. **`Pago Parcial`**: Se abre un diálogo numérico para ingresar el monto ya abonado (ej. `S/ 150.00` de una cuota de `S/ 300.00`). La cuota muestra `Abonado: S/ 150.00 | Restante: S/ 150.00`.
  3. **Edición Flexible de Monto y Fecha:**
     * Icono para editar la fecha de vencimiento individual de la cuota.
     * Posibilidad de editar el monto individual de la cuota si el comerciante pactó una cuota desigual (recalculando el total del préstamo automáticamente).
  4. **Resumen de Liquidación Previa:**
     * En la cabecera del cronograma se muestra:
       * `Capital Prestado (+ Interés): S/ 1,200.00`
       * `Ya Amortizado Histórico: S/ 800.00`
       * `Saldo Deudor Inicial Real: S/ 400.00`

#### 3.3 Persistencia Atómica en `ClientService.registerLoan`
* **Archivo:** `app_movil/lib/features/smart_quotation/services/client_service.dart`
* **Firma Actualizada:**
  ```dart
  Future<void> registerLoan(
    int clientId, 
    int negocioId, 
    int usuarioId, {
    required double amount,
    required String motivo,
    DateTime? loanDate, // Fecha de entrega histórica
    double? interestRate,
    String? metodoPago,
    List<InstallmentModel>? installments,
  }) async
  ```
* **Lógica Atómica:**
  1. Calcular el total abonado previamente (`totalHistoricoPagado = sum(cuota.montoPagado)`).
  2. Insertar en `ventas`:
     * `fecha_venta = (loanDate ?? DateTime.now()).toIso8601String()`.
     * `monto_total = finalDebt`.
     * `monto_pagado = totalHistoricoPagado`.
     * `abono_inicial = totalHistoricoPagado`.
     * `estado_pago = totalHistoricoPagado >= finalDebt ? 'pagado' : (totalHistoricoPagado > 0 ? 'parcial' : 'pendiente')`.
  3. Insertar cada registro en `cuotas`:
     * `monto = cuota.amount`.
     * `monto_pagado = cuota.montoPagado`.
     * `estado = cuota.montoPagado >= cuota.amount ? 'pagado' : (cuota.montoPagado > 0 ? 'parcial' : (cuota.isOverdue ? 'vencida' : 'pendiente'))`.
     * `fecha_vencimiento = cuota.dueDate`.
  4. Para cada cuota que tenga `montoPagado > 0`:
     * Insertar el registro correspondiente en la tabla `pagos`:
       * `monto = cuota.montoPagado`.
       * `metodo_pago = metodoPago ?? 'Efectivo'`.
       * `nota = 'Abono histórico registrado al crear préstamo (Cuota #${cuota.installmentNumber})'`.
       * `fecha_pago = cuota.dueDate`.
       * `cuota_id = cuotaInsertedId`.
       * `venta_id = loanId`.
  5. Recalcular contabilidad del cliente:
     * `await recalculateClientDebt(clientId);` (El cliente sólo adeudará el saldo restante real).
     * `await recalculateClientSaldoAFavor(clientId);`
     * `await recalculateClientReputation(clientId);`

#### 3.4 Corrección de Recorte Visual en el Modal (`Imagen 3`)
* **Archivo:** `app_movil/lib/features/smart_quotation/widgets/crm/client_finance_actions_modal.dart`
* **Solución de Layout:**
  1. **Separación de Cabecera y Viewport:**
     * Añadir un padding vertical adecuado (`const SizedBox(height: 12)`) entre el contenedor del `TabBar` y el `TabBarView`.
     * En `_buildLoanTab`, ajustar el padding del `ListView` a `const EdgeInsets.fromLTRB(20, 12, 20, 40)` y agregar un `ClipRRect` para que el desplazamiento del contenido no se corte de forma áspera contra las pestañas.
  2. **Wrap Responsivo en `Motivo / Detalle`:**
     * Reemplazar el `SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(...))` de `_motivosSug` por un `Wrap` con `spacing: 8, runSpacing: 8`.
     * De este modo, los 5 motivos sugeridos ("Préstamo personal", "Fiado mercadería", "Adelanto de trabajo", "Emergencia", "Otros") se acomodan en 2 líneas fluidas dentro del ancho de la pantalla sin cortarse jamás en el margen derecho.
  3. **Espaciado Blindado en Métodos de Entrega:**
     * Optimizar el `Wrap` de métodos de pago (`Efectivo`, `Yape`, `Plin`, `Transferencia`) con altura uniforme y padding interno suficiente para que las letras y los íconos nunca sufran recortes verticales.

---

## 4. MAPA DE ARCHIVOS INVOLUCRADOS Y LÍNEAS EXACTAS

| Archivo | Rol en el Sistema | Líneas Clave | Acción Planeada |
| :--- | :--- | :--- | :--- |
| `app_movil/lib/core/database/local_db.dart` | Esquema SQLite central y migraciones | 33, 44–280, 523, 691 | Migración V29: `is_archived`, `motivo_anulacion`, `fecha_anulacion`, índices y blindaje `ensureColumnExists`. |
| `app_movil/lib/features/smart_quotation/services/sales_service.dart` | Servicio de ventas y anulación (`voidSale`) | 654–740, 835–955 | Reescritura atómica de `voidSale`: marcar `cuotas.estado = 'anulada'`, desvincular pagos correctamente, blindaje defensivo. |
| `app_movil/lib/features/smart_quotation/services/client_service.dart` | Contabilidad del cliente, estado de cuenta y préstamos | 119–218, 245–315, 588–726, 1227–1291 | Descuento exacto de deuda, exclusión de anulados en `getClientLedger`, soporte de abonos históricos en `registerLoan`, recálculo de reputación. |
| `app_movil/lib/features/smart_quotation/widgets/crm/client_finance_actions_modal.dart` | Modal UI de `Operaciones Financieras` | 38–63, 696–760, 887–912, 1150–1215, 1540–1602, 2120–2280 | Desbloqueo de fechas (2015+), fecha de entrega, selector de estado de cuotas (Pagada/Parcial/Pendiente), corrección de recorte visual con `Wrap`. |
| `app_movil/lib/features/smart_quotation/widgets/crm/client_stats_header.dart` | Cabecera y badge de reputación del cliente | 382–440, 442–525 | Sincronización en tiempo real del badge ante cuotas vencidas y desaparición inmediata del banner de mora al anular. |
| `app_movil/lib/features/smart_quotation/screens/crm/client_detail_screen.dart` | Pantalla de perfil de cliente | 66–82, 320–355 | Sincronización de datos frescos y recálculo de reputación al recargar el perfil. |
| `app_movil/lib/features/smart_quotation/screens/sale_history_detail_screen.dart` | Detalle de venta / préstamo y diálogo de anulación | 106–216 | Diálogo amigable específico para préstamos ("¿Anular Préstamo?"), refresco del cliente tras anular. |
| `app_movil/lib/features/smart_quotation/widgets/history/sale_action_bottom_sheet.dart` | Bottom sheet de acciones sobre ventas/préstamos | 160–220 | Paridad en mensajes de anulación y restauración. |

---

## 5. PLAN DE IMPLEMENTACIÓN PASO A PASO (ROADMAP DE EJECUCIÓN)

Una vez que apruebes este plan, la ejecución se llevará a cabo en el siguiente orden secuencial y riguroso:

### Paso 1: Migración SQLite V29 y Esquema Seguro
1. Modificar `local_db.dart` incrementando la versión a 29.
2. Definir en `_onUpgrade` las llamadas `ensureColumnExists` para `ventas`, `cuotas` y `pagos`.
3. Actualizar `_createDB` con la definición canónica completa.
4. Crear pruebas unitarias de migración en SQLite en memoria para verificar que bases de datos simuladas en v25/v27/v28 migran a v29 sin errores.

### Paso 2: Refactorización Atómica de `voidSale` y Reversión Contable
1. Refactorizar `voidSale` en `sales_service.dart` para que ejecute la transacción atómica con las columnas corregidas y marque `cuotas.estado = 'anulada'`.
2. Actualizar `getClientLedger` en `client_service.dart` para no contaminar el historial con abonos de ventas anuladas y excluir cargos archivados del balance deudor.
3. Asegurar que `recalculateClientDebt` y `recalculateClientReputation` se invoquen al finalizar la anulación.
4. Crear pruebas unitarias que simulen la anulación del `Préstamo #13` y verifiquen que la deuda baja a S/ 0.00 y el banner de mora desaparece.

### Paso 3: Reingeniería del Modal `Operaciones Financieras`
1. Desbloquear las fechas pasadas en `client_finance_actions_modal.dart` (`firstDate: DateTime(2015, 1, 1)`).
2. Agregar selector de `Fecha de Emisión / Entrega` tanto en cuota única como en cuotas múltiples.
3. Incorporar en el `Cronograma Generado` el selector de estado por cuota (`Pendiente/Vencida`, `Ya Pagada`, `Pago Parcial`).
4. Corregir los recortes visuales: espaciado superior del `ListView`, `Wrap` en `_motivosSug` y en métodos de entrega.

### Paso 4: Persistencia de Préstamos Históricos con Abonos Previos
1. Actualizar `registerLoan` en `client_service.dart` para soportar la fecha de emisión histórica y el registro automático de `pagos` para cuotas pre-pagadas.
2. Actualizar `TrackingProvider.registerLoan` y la llamada en el modal para enviar el modelo enriquecido.
3. Comprobar que la deuda del cliente nace únicamente con el saldo pendiente real.

### Paso 5: Sincronización del Badge de Reputación en Tiempo Real
1. Ajustar `_buildTrustBadge` en `client_stats_header.dart` para que evalúe activamente la presencia de mora activa.
2. Asegurar que `_refreshData` en `client_detail_screen.dart` sincronice la reputación actualizada.

### Paso 6: Verificación y Batería de Tests Automatizados
1. Ejecutar la suite de tests existente (`flutter test`) asegurando cero regresiones.
2. Escribir una suite especializada `test/prestamos_anulacion_atomica_y_cronogramas_historicos_test.dart` cubriendo los 7 casos del Árbitro Interno Adversarial.
3. Verificar análisis estático (`dart analyze`).

---

## 6. CONCLUSIÓN Y ESTADO DE ESPERA

Este plan aborda de forma quirúrgica, exhaustiva y definitiva los fallos visualizados en las capturas adjuntas, protegiendo la base de datos de los comerciantes y dotando al sistema de préstamos de la flexibilidad histórica que el negocio real demanda.

> [!IMPORTANT]
> **REGLA DE CONFORMIDAD:** En cumplimiento estricto de tus instrucciones, **no se ha modificado ningún archivo de código todavía**. Quedo a la espera de tu revisión y visto bueno sobre este plan maestro para iniciar la fase de ejecución.

