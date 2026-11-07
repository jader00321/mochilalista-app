# PLAN MAESTRO: PARTE 2 (BLOQUE 2) — REINGENIERÍA RESPONSIVA DE GESTOR DE MOROSIDAD Y REFINAMIENTO EJECUTIVO EN PDF Y WHATSAPP

**Proyecto:** Sistema de Morosidad, Cronograma de Cuotas y Préstamos Personales  
**Fecha:** 06 de Noviembre de 2026  
**Rama:** `dev/mejoras-v9.0-comercializacion-seguridad`  
**Metodología:** Loop Autónomo + Árbitro Interno Adversarial (Cláusula Estricta Anti-Falsos Positivos)  
**Estado:** PROPUESTA DE PLAN DE TRABAJO (FASE DE INSPECCIÓN Y DISEÑO — CERO MODIFICACIONES DE CÓDIGO)

---

## 1. DIAGNÓSTICO FORENSE Y ANÁLISIS DE EVIDENCIAS

### A. Evidencias Fotográficas Analizadas (Capturas en Vivo)
1. **Imagen 1 (`1:18 AM` - `CuotaMorosidadModal` / `Automático Periódico`):**
   * El modal rebasó el alto de pantalla disponible en el dispositivo. El contenido se corta bruscamente a la mitad del checkbox *"Contar desde la fecha de vencimiento original (acumular periodos ya..."*.
   * **Bloqueo total de scroll:** No es posible deslizar hacia abajo (scroll). La tarjeta de resumen numérico (`Monto Base`, `Incremento por Mora`, `Nuevo Total`) y los botones de acción (`Cancelar`, `Guardar y Aplicar`, `Quitar Mora`) quedan 100% ocultos e inaccesibles para el usuario.
   * **Incoherencia del Switch:** El switch *"Activar Acumulación Periódica"* está apagado (OFF), pero todos los chips de configuración inferior (`Monto Fijo`, `5 S/`, `Semanal (7 días)`) se muestran con color activo, confundiendo al comerciante sobre si la cuota ya está devengando mora periódica o no.
2. **Imagen 2 (`1:14 AM` - `CuotaMorosidadModal` / `Manual / Directo`):**
   * En la sección `FORMA DE CÁLCULO`, las 3 opciones (`Porcentaje (%)`, `Monto Fijo (S/)`, `Total Cuota Directo`) se rompen en 2 filas desalineadas debido al uso de un `Wrap` sin proporciones balanceadas, consumiendo espacio vertical valioso.
   * No existen atajos o presets rápidos de 1 toque (ej. `+5%`, `+10%`, `+S/ 5`, `+S/ 10`), forzando a escribir manualmente en el teclado.
3. **Imagen 3 (`1:13 AM` - `SalePaymentTimeline` / `Plan de Cuotas`):**
   * Visualización del listado de cuotas en `Préstamo #13`. Muestra cómo la Cuota 1 venció hace 13 días, la Cuota 2 venció hace 6 días (ambas a `S/ 300.00` base) y las Cuotas 3 y 4 están aún pendientes en plazo.
4. **Imagen 4 (`1:16 AM` - `PdfPreviewScreen` / `Comprobante PDF`):**
   * En `PLAN DE CUOTAS (4 cuotas)`:
     * La línea de la Cuota 2 dice: `Cuota 2: S/ 305.00 (Orig: S/ 300.00 + Mora: S/ 5.00 = Total: S/ 305.00)`. Repite dos veces `S/ 305.00`, alargando innecesariamente la fila hasta competir con la columna derecha.
     * En la columna derecha, para las cuotas ya vencidas (Cuotas 1 y 2), imprime `Vence: 24/10/2026` y `Vence: 31/10/2026`, cuando gramatical y contablemente debió decir `Venció: 24/10/2026`.
5. **Imagen 5 (`1:16 AM` - `WhatsAppPreviewScreen` / `Editor WhatsApp`):**
   * En el bloque `📅 *CRONOGRAMA DE PAGOS* (4 Cuotas)`:
     * Cuota 1: `🔴 Cuota 1: *S/ 300.00* - Vencida hace 13 d` (se omitió la fecha de vencimiento `24/10/2026`).
     * Cuota 2: `🔴 Cuota 2: *S/ 305.00* (Orig: S/ 300.00 + Mora: S/ 5.00 = Total: S/ 305.00) - Vencida hace 6 d` (repite `S/ 305.00` y omite la fecha `31/10/2026`).
     * Cuotas 3 y 4 en plazo sí muestran `(Vence: 07/11/2026)` y `(Vence: 14/11/2026)`.

---

### B. Diagnóstico Forense en Código Fuente

| Archivo Afectado | Líneas Aprox. | Defecto Identificado en Código |
| :--- | :--- | :--- |
| `app_movil/lib/features/smart_quotation/widgets/history/detail_widgets/cuota_morosidad_modal.dart` | 290–305, 460–490, 740–786 | **Ausencia de Scroll & Layout no dividido:** El modal coloca todo su contenido dentro de un `Column(mainAxisSize: MainAxisSize.min)` directo en `child` sin `SingleChildScrollView`. Los botones de acción están al final de ese `Column`, por lo que si el formulario crece o se activa el teclado, los botones desbordan o quedan fuera de pantalla. Además, `maxHeightFactor` no está limitado a `0.88`. |
| `cuota_morosidad_modal.dart` | 320–340 | **Fecha cruda y estado ambiguo:** Renderiza `widget.cuota['fecha_vencimiento']` crudo (`2026-10-31`) sin formateo en español (`Venció: 31/10/2026 (hace 6 días)`) y carece de un Badge semántico claro sobre si la mora es manual, periódica automática o regla programada en plazo. |
| `cuota_morosidad_modal.dart` | 460–489 | **Segmentación quebrada en 2 filas:** `Wrap` con `ChoiceChip` divide los 3 modos de cálculo manual en dos líneas. Debe ser un `Row` segmentado de 3 botones proporcionales (`Expanded`). |
| `cuota_morosidad_modal.dart` | 550–670 | **Falta de simulación viva y switch no sincronizado:** Cuando el switch `_autoActiva` está apagado, los controles inferiores no se atenúan ni se auto-enciende el switch al configurar valores. No existe tarjeta explicativa que calcule y proyecte los periodos transcurridos ni el monto resultante. |
| `app_movil/lib/features/smart_quotation/utils/pdf_generator.dart` | 920–923, 934, 949 | **Redundancia y tiempo verbal en PDF:** `moraInfo` formatea `(Orig: ... + Mora: ... = Total: ...)`. Siempre concatena `"Vence: $date"` sin evaluar `isVencida ? 'Venció:' : 'Vence:'`. |
| `app_movil/lib/features/smart_quotation/screens/whatsapp_preview_screen.dart` | 613–625 | **Omisión de fecha en vencidas y duplicación:** En `isVencida`, escribe `amountText - Vencida hace X d` sin incluir la fecha `(Venció: DD/MM/YYYY)`, y `amountText` duplica el total. |
| `app_movil/lib/features/smart_quotation/widgets/history/detail_widgets/whatsapp_preview_modal.dart` | 145, 191–197 | **Falta de paridad en el modal de recordatorios:** Mismo formato redundante y omisión de fechas de vencimiento en cuotas vencidas. |
| `app_movil/test/parte1_tarjetas_historial_regla_cuotas_no_vencidas_y_timeline_test.dart` | 27–35 | **Advertencias del compilador Dart:** `_MockSaleProvider` declara `@override` en `isLoadingHistory` e `isSearching`, getters que no existen en `SaleProvider`. |

---

## 2. ARQUITECTURA DE SOLUCIÓN Y FASES DE IMPLEMENTACIÓN (BLOQUE 2)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GESTOR DE MOROSIDAD 2.0                         │
│                    (Arquitectura en 3 Zonas)                          │
├────────────────────────────────────────────────────────────────────────┤
│ 1. CABECERA FIJA (Pinned Header)                                       │
│    • Handle reactivo + Título: "Gestor de Morosidad • Cuota #X"        │
│    • Tarjeta Superior: "Venció: 31/10/2026 (hace 6 días)"              │
│      Badge: [⚡ MORA PERIÓDICA ACTIVA: +S/ 5.00 cada 7 d] [🗑️ Quitar]  │
│    • Selector de Modo: [ Manual / Directo ] [ Automático Periódico ]   │
├────────────────────────────────────────────────────────────────────────┤
│ 2. CUERPO ESCROLLEABLE FLUIDO (Flexible + BouncingScrollPhysics)       │
│    • Pestaña Manual:                                                   │
│      - Selector 3 Segmentos: [% Porcentaje] [S/ Monto] [S/ Total]      │
│      - Campo de Texto reactivo + Sufijo dinámico                       │
│      - Presets 1 Toque: [+5%] [+10%] [+15%] [+20%] / [+S/ 5] [+S/ 10]  │
│    • Pestaña Automática:                                               │
│      - Switch interactivo sincronizado (auto-activación al tocar)      │
│      - Selector Tipo (Porcentaje vs Fijo) y Frecuencias (1d, 7d, etc.) │
│      - Checkbox conteo desde vencimiento                               │
│      - Simulador en vivo con explicación pedagógica y números reales   │
├────────────────────────────────────────────────────────────────────────┤
│ 3. PIE DE PÁGINA FIJO (Pinned Footer vía bottomAction)                 │
│    • Tarjeta Resumen: [Base: S/ 300] [Mora: +S/ 5] [Total: S/ 305.00]  │
│    • Botones: [Cancelar] [Guardar y Aplicar]                           │
│    • Blindaje getEffectiveBottomPadding (Anti-teclado & Ghost Bar)    │
└────────────────────────────────────────────────────────────────────────┘
```

---

### FASE 1: Arquitectura 100% Responsiva y Desbloqueo de Scroll en `CuotaMorosidadModal`
1. **Configuración de la Hoja:**
   * Ajustar `maxHeightFactor: 0.88` en `InteractiveSheetWrapper`.
   * Habilitar `applyEffectiveBottomPadding: true` y `maintainFixedHeightOnKeyboard: false` para que la hoja se ajuste limpiamente si el usuario abre el teclado.
2. **División Estricta de 3 Zonas:**
   * **Zona A (Cabecera Superior Fija):**
     * Se mantiene visible sin moverse. Contiene la tarjeta de estado de la cuota y los segmentos de cambio de modo (`Manual / Directo` | `Automático Periódico`).
   * **Zona B (Cuerpo Central Escrolleable):**
     * Envuelto en `Flexible(fit: FlexFit.loose, child: SingleChildScrollView(physics: const BouncingScrollPhysics(), child: ...))`.
     * Permite recorrer todos los campos, selectores de frecuencia y simulador sin importar la resolución de la pantalla.
   * **Zona C (Pie de Página Pinned en `bottomAction`):**
     * Utiliza la propiedad nativa `bottomAction` de `InteractiveSheetWrapper`.
     * Contiene la tarjeta de preview en vivo con el total resultante y la fila de botones `[Cancelar]` y `[Guardar y Aplicar]`.
     * Esta zona **nunca se oculta al hacer scroll** y queda blindada automáticamente por encima de la barra de navegación del sistema y del teclado numérico.

---

### FASE 2: UX, Dinamismo, Presets Rápidos y Simulador Explicativo en Vivo
1. **Tarjeta de Estado Actual y Condonación en 1 Toque:**
   * Formateo de fecha: `DateFormat('dd/MM/yyyy')` con indicación de días: `Venció: 31/10/2026 (hace 6 días)` o `Vence: 07/11/2026 (en 1 día)`.
   * Badge dinámico:
     * `SIN MORA APLICADA` (Gris `Colors.blueGrey.withValues(alpha: 0.15)`).
     * `MORA MANUAL ACTIVA: +S/ X.XX` (Ámbar/Rojo `Colors.amber.withValues(alpha: 0.2)`).
     * `⚡ MORA PERIÓDICA ACTIVA: +S/ X.XX cada N días` (Naranja brillante `Colors.orange.withValues(alpha: 0.2)`).
     * `🛡️ MORA PROGRAMADA SI VENCE` (Azul/Cian `Colors.blue.withValues(alpha: 0.15)`).
   * Botón visible de condonación: Si `_moraMontoActual > 0.01` o `_autoActiva`, muestra botón `[🗑️ Quitar Mora]` directo en la tarjeta superior con diálogo de confirmación seguro.
2. **Pestaña `Manual / Directo`:**
   * Selector segmentado de 3 opciones en una sola fila:
     ```dart
     Row(
       children: [
         Expanded(child: _buildCalcSegment("Porcentaje", "%", 'porcentaje')),
         const SizedBox(width: 6),
         Expanded(child: _buildCalcSegment("Monto Fijo", "S/", 'fijo')),
         const SizedBox(width: 6),
         Expanded(child: _buildCalcSegment("Nuevo Total", "S/", 'total_directo')),
       ],
     )
     ```
   * Fila de **Presets Rápidos en 1 Toque** debajo del campo de texto:
     * Si `_calcType == 'porcentaje'`: Chips animados `+5%`, `+10%`, `+15%`, `+20%`.
     * Si `_calcType == 'fijo'`: Chips animados `+S/ 5`, `+S/ 10`, `+S/ 20`, `+S/ 50`.
     * Si `_calcType == 'total_directo'`: Chips de adición sobre base `Base + 5`, `Base + 10`, `Base + 20`.
3. **Pestaña `Automático Periódico` y Simulador:**
   * **Auto-activación del Switch:** Si `!_autoActiva` y el usuario selecciona una frecuencia, toca un preset o edita el monto, se dispara `setState(() => _autoActiva = true)` automáticamente.
   * **Atenuación al apagar:** Si el switch está en `false`, el cuerpo de la regla se envuelve en `AnimatedOpacity(opacity: 0.45)` con un mensaje instructivo: *"Interruptor desactivado: no se sumarán nuevos recargos periódicos (la mora actual de +S/ X.XX se conserva intacta)"*.
   * **Tarjeta de Proyección Pedagógica en Tiempo Real:**
     * Algoritmo de cálculo en memoria que evalúa:
       * Días transcurridos desde vencimiento: `daysOverdue`.
       * Periodos cumplidos: `periods = daysOverdue ~/ interval`.
       * Días faltantes para el próximo periodo: `daysToNext = interval - (daysOverdue % interval)`.
       * Monto acumulado proyectado hoy: `periods * valor`.
     * Generación de texto descriptivo según el estado:
       * *Ejemplo 1 (Semanal, 6 días vencido):* `"ℹ️ La cuota venció hace 6 días. Con frecuencia Semanal (cada 7 días), hoy devenga 0 periodos (+S/ 0.00). El 1.er recargo (+S/ 5.00) se aplicará mañana al cumplir 7 días de atraso."`
       * *Ejemplo 2 (Diario, 6 días vencido):* `"⚡ La cuota venció hace 6 días. Al guardar se aplicarán 6 días acumulados (+S/ 30.00 -> Total cuota: S/ 330.00) y sumará +S/ 5.00 cada nuevo día de retraso."`
       * *Ejemplo 3 (Cuota no vencida):* `"🛡️ Cuota en plazo. La regla no generará ningún cobro ahora; se activará automáticamente a partir del vencimiento (DD/MM/AAAA) si la cuota no es pagada a tiempo."`

---

### FASE 3: Refinamiento Ejecutivo en `Comprobante PDF` y `Editor WhatsApp`
1. **Comprobante PDF (`pdf_generator.dart`):**
   * En `cuotasWidget`:
     * Modificar `moraInfo`:
       ```dart
       // ANTES:
       // " (Orig: ${AppCurrency.format(montoOriginal)} + Mora: ${AppCurrency.format(moraMonto)} = Total: ${AppCurrency.format(cuotaMonto)})"
       // AHORA:
       final String moraInfo = tieneMora 
           ? " (Base: ${AppCurrency.format(montoOriginal)} + Mora: ${AppCurrency.format(moraMonto)})" 
           : "";
       ```
     * En la columna derecha de fecha:
       ```dart
       // ANTES:
       // pw.Text("Vence: $date", ...)
       // AHORA:
       pw.Text("${isVencida ? 'Venció:' : 'Vence:'} $date", ...)
       ```
     * Aplicar tanto en el formato **A4** como en el formato **Ticket 80mm**.
2. **Editor WhatsApp (`whatsapp_preview_screen.dart` y `whatsapp_preview_modal.dart`):**
   * Ajustar la construcción del texto de cada cuota:
     * Si `isVencida && !pagado`:
       * Con mora:
         `🔴 Cuota X: *S/ 305.00* (Base: S/ 300.00 + Mora: S/ 5.00) - Venció: 31/10/2026 (hace 6 días)`
       * Sin mora:
         `🔴 Cuota X: *S/ 300.00* (Venció: 24/10/2026) - Vencida hace 13 días`
       * Con pago parcial:
         `🔴 Cuota X: *S/ 300.00* (Venció: 24/10/2026) - Vencida hace 13 días • Pago Parcial (Abonado: S/ 100.00 | Falta: S/ 200.00)`
     * Si en plazo (`!isVencida && !pagado`):
       * `⏳ Cuota X: *S/ 300.00* (Vence: 07/11/2026) - Pendiente` (o `Vence: Hoy` si `daysOverdue == 0`).
     * Si pagada (`pagado`):
       * `✅ Cuota X: *S/ 300.00* (${isVencida ? 'Venció:' : 'Vence:'} $date) - Pagado`
   * Sincronizar exactamente la misma lógica en `whatsapp_preview_modal.dart` (recordatorio de cuota individual y recordatorio de múltiples cuotas desde perfil).

---

### FASE 4: Corrección de Advertencias del Analizador en Tests
1. En `app_movil/test/parte1_tarjetas_historial_regla_cuotas_no_vencidas_y_timeline_test.dart`:
   * Remover las líneas 29–34 (`@override bool get isLoadingHistory => false;` y `@override bool get isSearching => false;`) ya que `SaleProvider` no declara esos getters, eliminando las 2 advertencias `override_on_non_overriding_member`.
2. Verificar con `analyze_files` que no quede ninguna advertencia en el archivo ni en el proyecto.

---

### FASE 5: Árbitro Interno Adversarial y Batería de Pruebas Automatizadas
Se creará la suite integral `app_movil/test/parte2_modal_morosidad_responsivo_pdf_y_whatsapp_test.dart` para auditar rigurosamente los siguientes **8 Criterios de Veto**:

| # | Criterio de Aprobación Adversarial | Condición de Aprobación |
| :---: | :--- | :--- |
| **V1** | **Scroll y Pinned Footer en Modal** | En viewport de 360x640dp con contenido largo de `Automático Periódico`, el modal no genera overflow, el cuerpo central es escrolleable (`SingleChildScrollView`), y los botones de acción (`Cancelar`, `Guardar y Aplicar`) permanecen fijos y visibles en `bottomAction`. |
| **V2** | **Badge de Estado en Cabecera** | Si la cuota tiene mora manual, muestra `MORA MANUAL ACTIVA: +S/ X.XX`; si tiene periódica, muestra `⚡ MORA PERIÓDICA ACTIVA: +S/ X.XX cada N días`; si está en plazo, muestra `🛡️ MORA PROGRAMADA SI VENCE`. |
| **V3** | **Condonación Directa de Mora** | Al pulsar `[🗑️ Quitar Mora]` en la tarjeta superior o en el modal, se invoca `quitarMorosidad` restaurando el monto base original `S/ 300.00` y reseteando `mora_monto = 0.0`. |
| **V4** | **3 Segmentos Manuales y Presets Rápidos** | La fila de cálculo manual contiene exactamente 3 botones (`% Porcentaje`, `S/ Monto Fijo`, `S/ Nuevo Total`) en una sola línea horizontal. Al pulsar el chip rápido `+10%`, el campo de texto se actualiza a `10` y el preview refleja `+S/ 30.00` instantáneamente. |
| **V5** | **Auto-activación del Switch Periódico** | Al seleccionar un chip de frecuencia (ej. `Semanal (7 días)`) o editar el valor de mora mientras el switch está apagado, el switch pasa automáticamente a `true`. |
| **V6** | **Simulador y Proyección Matemática Viva** | Con una cuota vencida hace 6 días y frecuencia `Semanal (7 días)`, el simulador proyecta correctamente 0 periodos acumulados y fecha del próximo devengo. Con frecuencia `Diario (1 día)`, proyecta 6 periodos acumulados (+S/ 30.00). |
| **V7** | **Refinamiento de Plan de Cuotas en PDF** | El PDF generado no contiene el texto redundante `= Total: S/ 305.00` en la cuota 2, sino `(Base: S/ 300.00 + Mora: S/ 5.00)`. En cuotas vencidas, la columna de fecha dice `Venció: DD/MM/YYYY`. |
| **V8** | **Refinamiento en Editor WhatsApp** | El mensaje generado incluye la fecha de vencimiento en cuotas vencidas: `🔴 Cuota 1: *S/ 300.00* (Venció: 24/10/2026) - Vencida hace 13 días`, y en cuotas con mora muestra `(Base: S/ 300.00 + Mora: S/ 5.00) - Venció: 31/10/2026 (hace 6 días)`. |

---

## 3. MATRIZ DE RIESGOS Y MEDIDAS DEFENSIVAS

1. **Riesgo: Desborde en pantallas muy pequeñas (320dp de ancho) con los 3 segmentos manuales.**
   * *Mitigación:* Usar `Expanded` con `FittedBox(fit: BoxFit.scaleDown)` dentro de cada segmento para asegurar que los títulos `"Porcentaje"`, `"Monto Fijo"`, `"Total"` se escalen limpiamente sin overflow.
2. **Riesgo: Teclado numérico tapa el simulador explicativo al escribir el monto.**
   * *Mitigación:* Al estar en un `SingleChildScrollView`, el campo de texto tiene `scrollPadding: const EdgeInsets.only(bottom: 90)` lo que reposiciona el scroll automáticamente por encima del teclado.
3. **Riesgo: Regresión en tests existentes de PDF y WhatsApp.**
   * *Mitigación:* En `motor_morosidad_estados_pdf_y_whatsapp_test.dart` y en `sales_history_and_detail_reengineering_test.dart`, verificar que los matchers esperen la nueva sintaxis limpia `(Base: ... + Mora: ...)` y `Venció:`.

---

## 4. CHECKLIST DE EJECUCIÓN (A EJECUTAR TRAS APROBACIÓN)

- [x] 1. Limpieza de las 2 advertencias en `test/parte1_tarjetas_historial_regla_cuotas_no_vencidas_y_timeline_test.dart`.
- [x] 2. Reingeniería de `cuota_morosidad_modal.dart` (Arquitectura en 3 zonas, scroll fluido, cabecera fija, pinned footer, badges, presets y simulador dinámico).
- [x] 3. Refinamiento en `pdf_generator.dart` (Eliminación de redundancia de total y `Venció:` dinámico).
- [x] 4. Refinamiento en `whatsapp_preview_screen.dart` y `whatsapp_preview_modal.dart` (Inclusión de fecha `Venció:`, texto `Base + Mora` y formato limpio).
- [x] 5. Creación y ejecución de la suite `test/parte2_modal_morosidad_responsivo_pdf_y_whatsapp_test.dart` (8 criterios de veto).
- [x] 6. Ejecución de `analyze_files` (Cero errores y cero advertencias) y corrida completa de la suite de pruebas.

