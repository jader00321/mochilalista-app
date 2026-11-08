# PLAN MAESTRO: CORRECCIÓN DE DESBLOQUEO DE METAS, KARDEX DE PUNTOS Y FLUJO INTEGRAL DE PRÉSTAMOS
**Documento Técnico y Plan de Ejecución bajo Metodología de Loop Autónomo y Árbitro Adversarial**  
**Fecha:** Noviembre 2026 | **Estado:** Pendiente de Aprobación

---

## 1. RESUMEN EJECUTIVO Y DIAGNÓSTICO TÉCNICO RAÍZ

A partir del análisis de las 5 capturas de pantalla reales y de la inspección exhaustiva del código fuente en `loyalty_center_screen.dart`, `meta_reward_editor_modal.dart`, `client_service.dart`, `client_detail_screen.dart`, `client_stats_header.dart`, `client_loyalty_history_modal.dart` y `client_finance_actions_modal.dart`, se han identificado con precisión milimétrica las causas raíz de los 5 problemas reportados:

| # | Problema Detectado | Evidencia Visual | Archivo(s) Responsable(s) | Causa Técnica Raíz Identificada |
|---|-------------------|------------------|---------------------------|----------------------------------|
| **1** | Clientes con puntos suficientes no desbloquean nueva meta creada (Jj con 50 pts no desbloquea `ganador` de 50 pts). Además, clientes con 0 pts aparecen en "Casi en la Meta". | **Capturas 1 y 2** (`9.21.53 PM.jpeg` y `9.21.53 PM (1).jpeg`) | `client_service.dart`<br>`meta_reward_editor_modal.dart`<br>`loyalty_center_screen.dart` | 1. `createRewardGoal` y `updateRewardGoal` guardan la meta pero **no ejecutan una evaluación retroactiva** de los clientes existentes.<br>2. `getClientsAlmostAtGoal` usaba la condición `faltantes <= 50`, lo cual para clientes con 0 pts (`50 - 0 = 50`) resultaba `true`, metiendo a Freddy y Huk (`0 pts`) erróneamente en "Casi en la Meta". Faltaba validar `puntosActuales > 0` y $\ge 50\%$. |
| **2** | Al pulsar `[MOROSO \| 50 pts]` la pantalla se queda gris/blanca translúcida. El botón `+ Prést...` se corta con puntos suspensivos. | **Captura 3** (`9.21.52 PM (1).jpeg`) | `client_loyalty_history_modal.dart`<br>`client_service.dart`<br>`client_stats_header.dart` | 1. **Fatal TypeError en Runtime:** `getNextGoalForClient` en `client_service.dart` retorna claves en español (`puntos_faltantes`, `progreso`), pero `client_loyalty_history_modal.dart` (líneas 911-912) hacía cast forzado a claves en inglés: `_nextGoalData!['missing'] as int` y `_nextGoalData!['progress'] as double`. Al ser nulos, Flutter lanzaba un crash en `build()`, dejando la pantalla gris translúcida de error.<br>2. En `client_stats_header.dart`, la fila de 3 botones usaba `flex: 4, 3, 3` sin `FittedBox` en la etiqueta de `+ Préstamo`, cortándose en pantallas de 360dp. |
| **3** | El teclado no se oculta al pulsar fuera en Operaciones Financieras. La tarjeta "Límite Sugerido" aparece en la pestaña "Retirar Saldo" y no detecta morosidad ni reacciona al monto escrito. | **Capturas 4 y 5** | `client_finance_actions_modal.dart` | 1. Ausencia de `GestureDetector` con `primaryFocus?.unfocus()`, falta de `onTapOutside` en los `TextField` y falta de `ScrollViewKeyboardDismissBehavior.onDrag`.<br>2. La tarjeta de Límite de Crédito estaba renderizada fuera del `TabBarView` (visible en ambas pestañas) y con texto estático, sin consultar cuotas vencidas ni reaccionar en tiempo real a los cambios en el controlador `_amountCtrl`. |
| **4** | En "Estado Cuota #X", el campo `0.00` y el botón `Aplicar` se muestran siempre aunque esté en "Pendiente", y la opción "Pago Parcial / Abono" no se puede seleccionar. | **Captura 4** (`9.21.52 PM (3).jpeg`) | `client_finance_actions_modal.dart` | La opción 3 ("Pago Parcial / Abono") era un `ListTile` sin evento `onTap`, y la caja de texto numérica estaba fija debajo de la lista en lugar de estar condicionada por estado activo. Faltaban chips de porcentaje (`25%`, `50%`, `75%`) y resumen en vivo del saldo restante. |
| **5** | En "Confirmar Préstamo", las fechas chocan contra los montos (`"Lun, 02/11/2026S/ 480.00"`). Falta detalle de estados y desactivar botón `+1d` en cuotas ya pagadas. | **Captura 5** (`9.21.51 PM (1).jpeg`) | `client_finance_actions_modal.dart`<br>`client_service.dart` | El `Row` de cada cuota no tenía `Expanded` en el texto de la izquierda ni espacio entre fecha y monto. El estado de la cuota no mostraba badge si era `Pendiente` o `Vencida`. En la vista previa, el botón `+1d` no se ocultaba cuando `montoPagado >= amount`. |

---

## 2. METODOLOGÍA DE TRABAJO: LOOP AUTÓNOMO + ÁRBITRO ADVERSARIAL

Seguiremos rigurosamente el estándar del proyecto:
1. **Fase de Diseño y Plan Maestro (Este documento):** Análisis de código y arquitectura sin modificar código productivo.
2. **Ciclo TDD con Árbitro Adversarial:** Creación previa o actualización de tests unitarios y de widgets (`test/loyalty_goals_retroactive_and_finance_flow_test.dart`) que reproduzcan con exactitud los 5 fallos identificados.
3. **Ejecución Modular por Fases:** Modificación y corrección quirúrgica en los archivos objetivo.
4. **Verificación Automatizada:** Ejecución de `dart-mcp-server` (`run_tests` y `analyze_files`) asegurando 0 errores estáticos y 100% de tests en verde.
5. **Auditoría Contable y Visual:** Validación de que la suma de cuotas cuadre al céntimo y que en 360dp no exista ningún desborde.

---

## 3. FASE 1: EVALUACIÓN RETROACTIVA DE METAS Y LÓGICA MATEMÁTICA DE "CASI EN LA META"

### 1.1. Motor de Evaluación Retroactiva en `ClientService`
* **Nuevo método `evaluateAllClientsForActiveGoals(int negocioId)`:**
  * Consulta todos los clientes del negocio con `puntos_actuales > 0`.
  * Consulta todas las metas de recompensas activas del negocio ordenadas por `puntos_requeridos ASC`.
  * Ejecuta de forma segura `evaluateAndUnlockRewardGoals` para cada cliente que califique.
  * Si un cliente cumple con una meta (`puntos_actuales >= meta.puntosRequeridos`) y no tiene ya esa meta en `PENDIENTE_REVISION` o `APROBADA_NOTIFICADA`:
    * Reserva los puntos requeridos de `puntos_actuales` (manteniendo intacto `puntos_historicos`).
    * Inserta el registro en `recompensas_cliente` en estado `'PENDIENTE_REVISION'`.
    * Inserta el movimiento contable en `historial_puntos_reputacion` (`tipo_movimiento: 'RESERVA_META'`).
    * Inserta notificación interna para el comerciante.
  * Retorna la lista de todas las recompensas recién desbloqueadas.

### 1.2. Disparadores Automáticos de la Evaluación Retroactiva
1. **Al Crear o Actualizar Metas (`MetaRewardEditorModal._save`):**
   * Tras guardar o actualizar una meta (especialmente si se activa o se reducen los puntos requeridos), invocar inmediatamente:
     ```dart
     final newlyUnlocked = await _clientService.evaluateAllClientsForActiveGoals(widget.negocioId);
     ```
   * Si `newlyUnlocked.isNotEmpty`, notificar al usuario con un banner/snackbar:
     *"¡${newlyUnlocked.length} cliente(s) ya cumplen con esta meta y sus premios están listos para revisar!"*
   * Retornar un indicador de éxito para que la pantalla que lo invocó refresque sus bandejas al instante.
2. **Al Cargar o Refrescar `LoyaltyCenterScreen.loadData()`:**
   * En el paso de inicialización, ejecutar `evaluateAllClientsForActiveGoals(negocioId)` antes de consultar `getPendingReviewRewards(negocioId)`.
   * Esto garantiza que cualquier cliente que ya tuviera puntos suficientes (como Jj con 50 pts) desbloquee de inmediato la recompensa y aparezca en la bandeja superior `Premios Desbloqueados por Revisar`.
3. **Al Abrir y Tras Modificar Puntos en `ClientLoyaltyHistoryModal`:**
   * Evaluar al cliente actual tras bonos manuales para que el desbloqueo sea instantáneo.

### 1.3. Corrección Matemática de "Casi en la Meta" (`getClientsAlmostAtGoal`)
* **Problema actual:** La condición `faltantes <= 50 && faltantes > 0` sin validar puntos acumulados hacía que clientes con `0 puntos` tuvieran `faltantes = 50 - 0 = 50`, catalogándolos como "Casi en la meta".
* **Nueva regla matemática estricta:**
  Un cliente califica como "Casi en la Meta" **ÚNICAMENTE SI**:
  $$\text{puntosActuales} > 0 \quad \text{y} \quad \text{puntosActuales} \ge (\text{meta.puntosRequeridos} \times 0.5) \quad \text{y} \quad \text{puntosActuales} < \text{meta.puntosRequeridos}$$
  * Si `puntosActuales == 0`, **NUNCA** puede entrar a "Casi en la Meta".
  * Se evalúa respecto a la meta activa más cercana que aún no haya sido alcanzada.
* **Tarjeta de Cliente en la Pestaña `Reputación` (`_buildReputationClientCard`):**
  * Si el cliente tiene un premio en estado `'PENDIENTE_REVISION'`:
    * Ocultar el chip de "A X pts de: ... (Impulso)" y mostrar en su lugar una insignia dorada de alta prioridad:
      **`🎁 ¡Premio desbloqueado listo para revisar!`**
    * Incluir botón directo **`Revisar`** que abre `RewardReviewModal(reward, client)` de inmediato.
  * Si el cliente está legítimamente "Casi en la Meta" (puntos $> 0$ y $\ge 50\%$):
    * Mostrar el indicador `"A X pts de: [Meta]"` con el botón verde de WhatsApp `"Impulso"`.

---

## 4. FASE 2: SOLUCIÓN A LA PANTALLA GRIS EN EL KARDEX Y BOTÓN CORTADO `+ PRÉSTAMO`

### 4.1. Diagnóstico y Corrección de la Pantalla Gris en `ClientLoyaltyHistoryModal`
* **Causa Raíz:** En `client_loyalty_history_modal.dart` (líneas 910-913):
  ```dart
  final int missing = _nextGoalData!['missing'] as int;
  final double progress = (_nextGoalData!['progress'] as double).clamp(0.0, 1.0);
  ```
  Mientras que `ClientService.getNextGoalForClient` retornaba:
  ```dart
  return {
    'goal': g,
    'puntos_actuales': currentPoints,
    'puntos_requeridos': g.puntosRequeridos,
    'puntos_faltantes': faltantes,
    'progreso': progress,
  };
  ```
  Al ser `_nextGoalData!['missing']` nulo, la expresión `null as int` lanzaba una excepción no capturada en tiempo de ejecución durante la fase de layout/build de Flutter, provocando el renderizado de la pantalla translúcida gris/blanca de error sobre el perfil del cliente.
* **Solución de Blindaje:**
  1. En `ClientService.getNextGoalForClient`: Retornar ambas variantes de claves (`puntos_faltantes`, `missing`, `progreso`, `progress`) para interoperabilidad universal.
  2. En `ClientLoyaltyHistoryModal`: Parsear defensivamente con operadores nulos y fallback seguro:
     ```dart
     final int missing = (_nextGoalData!['puntos_faltantes'] ?? _nextGoalData!['missing'] as num?)?.toInt() ?? 0;
     final double progress = ((_nextGoalData!['progreso'] ?? _nextGoalData!['progress'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
     ```
  3. Verificar que el modal utilice `InteractiveSheetWrapper` o un `Container` con restricciones verticales claras (`constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90)`), garantizando que el `Column` con `Expanded` interno del listado de movimientos no sufra de *unbounded height*.
  4. Garantizar que al pulsar el badge `[⚠️ MOROSO | ⭐ 50 pts]` en `client_stats_header.dart`, el modal abra fluidamente, cargue el score, la barra de progreso de la meta, los premios por revisar y el Kardex con opción a bono manual.

### 4.2. Corrección del Botón Cortado `+ Prést...` en `ClientStatsHeader`
* **Causa:** En la cabecera del perfil (`client_stats_header.dart`), los 3 botones principales (`Caja Rápida`, `Cotizar`, `+ Préstamo`) están configurados en un `Row` con `flex: 4, 3, 3`. En dispositivos de 360dp de ancho, el padding horizontal del botón más el icono `Icons.account_balance_rounded` (16px) dejaban espacio insuficiente para el texto `"+ Préstamo"`, activando la truncación con puntos suspensivos (`+ Prést...`).
* **Solución:**
  1. Envolver la etiqueta del botón en `FittedBox(fit: BoxFit.scaleDown, child: Text("+ Préstamo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))`.
  2. Ajustar los paddings horizontales de los 3 botones a `horizontal: 6, vertical: 9`.
  3. Asignar proporciones equilibradas en el `Row` (`flex: 7` para Caja Rápida, `flex: 6` para Cotizar y `flex: 7` para + Préstamo).

---

## 5. FASE 3: UX Y REACTIVIDAD EN OPERACIONES FINANCIERAS (TECLADO Y TARJETA DINÁMICA)

### 5.1. Cierre Automático del Teclado al Tocar Fuera
* **Problema:** En `ClientFinanceActionsModal`, al tocar campos numéricos o de texto el teclado se abre, pero tocar fuera no lo cierra ni remueve el foco.
* **Solución Integral:**
  1. Envolver el contenido del modal en un `GestureDetector`:
     ```dart
     GestureDetector(
       behavior: HitTestBehavior.translucent,
       onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
       child: ...
     )
     ```
  2. Agregar en cada `TextField` / `TextFormField` del formulario (`_amountCtrl`, `_interestCtrl`, `_noteCtrl`, `_numCuotasCtrl`):
     ```dart
     onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
     ```
  3. Configurar en los scrolls internos:
     ```dart
     keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
     ```

### 5.2. Tarjeta Dinámica Contextual: "Límite de Crédito Sugerido" vs "Retirar Saldo"
* **Problema:** Actualmente la tarjeta `"Límite de Crédito Sugerido (Bronce): S/ 150.00"` está fija fuera del `TabBarView`, mostrándose erróneamente en la pestaña de `Retirar Saldo` y permaneciendo totalmente estática en `Otorgar Préstamo` sin detectar morosidad ni validar montos.
* **Solución:**
  Crear el widget reactivo `_buildDynamicContextualCard()` cuyo contenido varíe dinámicamente según la pestaña activa (`_tabController.index`):

#### A. En la Pestaña `Retirar Saldo` (Tab 1):
* **Título:** `"Saldo a Favor Disponible para Retiro"`
* **Monto:** `AppCurrency.format(widget.client.saldoAFavor)`
* **Comportamiento:**
  * Si `saldoAFavor > 0`: Tarjeta verde azulada / esmeralda con mensaje: *"Disponible para retiro inmediato en efectivo o transferencia bancaria"*.
  * Si `saldoAFavor <= 0`: Tarjeta ámbar suave informativa: *"Este cliente no posee saldo a favor acumulado para retirar (se genera con abonos excedentes o devoluciones)"*.

#### B. En la Pestaña `Otorgar Préstamo` (Tab 0):
* **Detección de Mora en Tiempo Real:**
  * Consultar a través de `TrackingProvider` si el cliente tiene cuotas vencidas impagas.
  * Si `overdueCount > 0`:
    * Tarjeta de alerta en tono rojo / carmesí:
      * **Icono:** `Icons.warning_amber_rounded`
      * **Texto:** `"⚠️ Riesgo Alto: Registra $overdueCount cuota(s) vencida(s). Límite de crédito congelado sugerido: S/ 0.00"`
  * Si el cliente está al día (`overdueCount == 0`):
    * **Caso B.1 (Sin monto ingresado o Monto $\le$ Límite Sugerido):**
      * Tarjeta verde / azul con icono de escudo:
        * `"🛡️ Cliente ${tier.badgeText} • Racha de ${client.rachaPagosPuntuales} pagos a tiempo • Préstamo seguro hasta ${AppCurrency.format(tier.limiteCreditoSugerido)}"`
    * **Caso B.2 (Monto ingresado > Límite Sugerido - Ej. ingresa S/ 2,000 vs S/ 150):**
      * Tarjeta reactiva en tono ámbar preventivo en vivo (escuchando `_amountCtrl`):
        * `"⚠️ Atención: El monto (${AppCurrency.format(montoIngresado)}) supera en ${AppCurrency.format(montoIngresado - tier.limiteCreditoSugerido)} el límite sugerido para su nivel (${AppCurrency.format(tier.limiteCreditoSugerido)})"`

---

## 6. FASE 4: REINGENIERÍA DEL MODAL "ESTADO CUOTA #X"

### 6.1. Rediseño con 3 Tarjetas de Opción Interactivas y Animadas
En `client_finance_actions_modal.dart`, reemplazar el diálogo estático actual por un selector con 3 tarjetas táctiles con borde y color de selección reactivo:

1. **Opción 1: `Pendiente / Sin Pagar`**
   * Si la fecha de vencimiento ya pasó respecto a hoy: mostrar automáticamente badge/texto **`Vencida / Sin Pagar`** con icono de reloj/alerta ámbar o rojo.
   * Al pulsarla, queda seleccionada y oculta el campo numérico.
2. **Opción 2: `Ya Pagada Totalmente`**
   * Muestra subtítulo: `"Monto abonado: S/ [Total Cuota]"`.
   * Al pulsarla, queda seleccionada y oculta el campo numérico.
3. **Opción 3: `Pago Parcial / Abono`**
   * Permite seleccionarla con un solo toque (corrigiendo el fallo de falta de interacción de la Captura 4).
   * Al seleccionarla, despliega suavemente (`AnimatedSize`) el área de captura de abono.

### 6.2. Visibilidad Condicional Estricta y Chips Porcentuales
* **Ocultamiento Total:** Si se selecciona Opción 1 u Opción 2, el campo de texto numérico y el botón de aplicar abono parcial **desaparecen completamente** de la pantalla, evitando la confusión de la Captura 4.
* **Sección de Abono Parcial (Solo visible en Opción 3):**
  * Campo numérico con formato de moneda y prefijo `S/ `.
  * **Chips de selección rápida por porcentaje en 1 toque:**
    * `[ 25% ]` $\rightarrow$ Calcula automáticamente el 25% de la cuota.
    * `[ 50% ]` $\rightarrow$ Calcula automáticamente la mitad exacta.
    * `[ 75% ]` $\rightarrow$ Calcula automáticamente el 75%.
  * **Resumen en vivo dinámico:**
    * **`Abonado: S/ X.XX  •  Resta por cobrar en esta cuota: S/ Y.YY`**
  * **Validación en caliente:**
    * El abono debe ser $> 0$ y menor al total de la cuota. Si el usuario escribe un monto igual o superior al total de la cuota, sugerir o alternar automáticamente a `"Ya Pagada Totalmente"`.

---

## 7. FASE 5: AUDITORÍA CONTABLE Y MODAL "CONFIRMAR PRÉSTAMO" ANTI-COLISIÓN

### 7.1. Correcciones Visuales en el Modal `"Confirmar Préstamo"` (Captura 5)
* **Separación de Columnas Anti-Colisión:**
  * En la lista de cuotas del modal de confirmación, reestructurar cada fila en un `Row` con dos bloques acotados:
    * **Bloque Izquierdo (`Expanded`):**
      * `Text("Cuota ${c.installmentNumber}", style: bold)`
      * `Text(_formatDateSpanish(d), style: subtitulo)`
    * **Espaciador Central:** `const SizedBox(width: 12)`
    * **Bloque Derecho (`Column(crossAxisAlignment: CrossAxisAlignment.end)`):**
      * `Text(AppCurrency.format(c.amount), style: bold)`
      * **Badge de Estado Completo:**
        * Si `c.status == 'pagado'` o `c.montoPagado >= c.amount`: Badge verde `"Pagada"`.
        * Si `c.montoPagado > 0` y `c.montoPagado < c.amount`: Badge azul/ámbar `"Abonó S/ ${c.montoPagado} (Resta S/ ${c.amount - c.montoPagado})"`.
        * Si `c.montoPagado == 0` y fecha $< \text{hoy}$: Badge rojo `"Vencida"`.
        * Si `c.montoPagado == 0` y fecha $\ge \text{hoy}$: Badge gris `"Pendiente"`.
* **Desactivación del Botón `+1d` en Cuotas Pagadas:**
  * En la lista del cronograma (`_buildCronogramaItem`), si `cuota.status == 'pagado'` o `cuota.montoPagado >= cuota.amount`, **ocultar o desactivar el botón `+1d`**, ya que una cuota amortizada históricamente no debe desplazarse de fecha.

### 7.2. Verificación de Cálculos Contables y Residuos de Centavos
* **División en $N$ Cuotas con Residuo:**
  * Al dividir `finalDebt` entre $N$ cuotas:
    * `basePerQuota = double.parse((finalDebt / numCuotas).toStringAsFixed(2))`
    * Para las cuotas $1$ a $N-1$: monto = `basePerQuota`.
    * Para la cuota $N$: monto = `double.parse((finalDebt - acumuladoAnterior).toStringAsFixed(2))`.
    * Garantiza que la suma de cuotas cuadre exactamente al céntimo ($100.00 / 3 \rightarrow 33.33 + 33.33 + 33.34 = 100.00$).
* **Amortización Histórica y Saldo Deudor Inicial:**
  * `totalAmortizado = suma(cuotas.montoPagado)`
  * `saldoDeudorInicial = finalDebt - totalAmortizado`
* **Persistencia en `ClientService.registerLoan`:**
  * Al guardar en SQLite:
    * En `ventas`: registrar `monto_total = finalDebt`, `monto_pagado = totalAmortizado`, `abono_inicial = totalAmortizado`.
    * En `cuotas`: registrar cada cuota con su estado real (`pagado`, `parcial`, `vencida`, `pendiente`) y su `monto_pagado`.
    * En `pagos`: registrar los abonos iniciales históricos de las cuotas pagadas o parciales.
    * Ejecutar `recalculateClientDebt(clientId)`: calcula `totalDeuda = finalDebt - totalAmortizado = saldoDeudorInicial`.
    * Ejecutar `recalculateClientSaldoAFavor(clientId)` y `recalculateClientReputation(clientId)`.
    * En `ClientDetailScreen`, la llamada a `onFinanceActionCompleted` refrescará la entidad completa, mostrando inmediatamente la deuda neta correcta, el estado de cuenta con sus abonos y las cuotas vencidas sin retrasos ni inconsistencias.

---

## 8. BATERÍA DE PRUEBAS DEL ÁRBITRO ADVERSARIAL

Crearemos el archivo de prueba unitaria y de widgets:
**`test/loyalty_goals_retroactive_and_finance_flow_test.dart`** que someterá a prueba los siguientes escenarios:

1. **Test 1: Evaluación Retroactiva al Crear Nueva Meta:**
   * Crear cliente con 50 puntos.
   * Crear meta de 50 puntos (`ganador`).
   * Verificar que `evaluateAllClientsForActiveGoals` reserve 50 puntos y cree la recompensa en `PENDIENTE_REVISION`.
2. **Test 2: Lógica Matemática Estricta de "Casi en la Meta":**
   * Cliente con 0 puntos **NO** entra en "Casi en la Meta" aunque la meta pida 50 puntos.
   * Cliente con 25 puntos para meta de 50 puntos (50%) **SÍ** entra en "Casi en la Meta".
3. **Test 3: Apertura Resiliente del Kardex (`ClientLoyaltyHistoryModal`):**
   * Simular apertura con cliente con mora y verificar que no lance excepción nula al calcular `missing` / `progress`.
4. **Test 4: Integridad de Cuotas y Cuadre al Céntimo en Creación de Préstamo:**
   * Préstamo de S/ 100 en 3 cuotas con interés 0%: verificar cuotas de 33.33, 33.33 y 33.34 sumando exactamente 100.00.
   * Marcar cuota 1 pagada (33.33): verificar que la deuda total resultante en el cliente sea exactamente S/ 66.67.
5. **Test 5: UI & Anti-Colisión:**
   * Verificar que en pantalla de 360dp el botón `+ Préstamo` no se trunque y que el diálogo de confirmación no solape fecha y monto.

---

## 9. CRITERIOS DE ACEPTACIÓN 100%

- [ ] **Desbloqueo Retroactivo:** Al crear la meta `ganador` (50 pts), el cliente `Jj` (50 pts) desbloquea inmediatamente su premio en `PENDIENTE_REVISION` y aparece en `Premios Desbloqueados por Revisar`.
- [ ] **Filtro "Casi en la Meta":** Freddy (0 pts) y Huk (0 pts) quedan excluidos de "Casi en la Meta". Solo clientes con $> 0$ pts y $\ge 50\%$ de avance aparecen en este filtro.
- [ ] **Apertura de Kardex:** Tocar `[MOROSO | 50 pts]` en el perfil del cliente abre de inmediato y sin error el modal del Kardex.
- [ ] **Botón `+ Préstamo`:** Se lee completo y nítido sin puntos suspensivos en cualquier pantalla móvil (360dp).
- [ ] **Cierre de Teclado:** Tocar cualquier parte exterior a los campos de texto en Operaciones Financieras cierra automáticamente el teclado.
- [ ] **Tarjeta Dinámica:** En "Retirar Saldo" muestra el saldo a favor disponible. En "Otorgar Préstamo" alerta mora en rojo y advierte en ámbar si el monto supera el límite sugerido.
- [ ] **Modal Estado Cuota:** Solo muestra el campo numérico al seleccionar "Pago Parcial / Abono", con chips de 25%, 50%, 75% y resumen en vivo.
- [ ] **Confirmación de Préstamo:** Fechas y montos perfectamente separados, badges de estado detallados y cuadre matemático exacto al céntimo.

