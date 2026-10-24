# Plan de Trabajo y Reingeniería: Proyecciones, Motor de Abastecimiento y Trazabilidad

> **Fecha:** 23 de Octubre de 2026  
> **Estado:** Propuesta Técnica y Arquitectura de Detalle (Listo para Revisión y Aprobación)  
> **Metodología:** Loop Autónomo + Árbitro Adversarial  
> **Módulos y Archivos Involucrados:**  
> - `app_movil/lib/features/analytics/screens/predictive_analytics_screen.dart`  
> - `app_movil/lib/features/analytics/services/predictive_service.dart`  
> - `app_movil/lib/features/analytics/screens/smart_restock_screen.dart`  
> - `app_movil/lib/features/analytics/services/inventory_intelligence_service.dart`  
> - `app_movil/lib/features/analytics/services/purchase_order_generator.dart`  
> - `app_movil/lib/features/analytics/screens/audit_trail_screen.dart`  
> - `app_movil/lib/features/catalog/repositories/product_repository.dart`  
> - `app_movil/lib/core/widgets/interactive_sheet_wrapper.dart`  
> - `app_movil/lib/core/utils/currency_formatter.dart`  
> - `app_movil/test/projections_restock_and_traceability_reengineering_test.dart` (Nueva suite de arbitraje)

---

## 1. DIAGNÓSTICO EXHAUSTIVO DE LAS 5 CAPTURAS Y ANOMALÍAS EN CÓDIGO

A partir de la inspección exhaustiva del código fuente y del análisis visual milimétrico de las 5 capturas en dispositivo físico, se desglosan las causas exactas de cada deficiencia matemática, lógica y de interfaz:

---

### 1.1. Captura 1 — `Proyecciones y Crecimiento`: Falta de Didáctica, Icono Duplicado y Proyección Opaca
* **Síntomas Observados:**
  1. En la tarjeta principal `"Proyección a 30 Días"`, se exhibe la cifra `21,68 S/` sin ninguna explicación del origen de los números ni su valor práctico; funciona como una "caja negra" incomprensible para el comerciante.
  2. En el consejo inferior de la tarjeta aparece un doble icono repetido: un rayo vectorial más un emoji de foco (`⚡ 💡 Revisa tu Motor de Abastecimiento...`).
  3. No hay forma de explorar escenarios de cierre (*Conservador*, *Esperado*, *Optimista*).
  4. El consejo menciona revisar el Motor de Abastecimiento, pero no es interactivo (no redirige a la pantalla correspondiente).
* **Causa Raíz en Código (`predictive_analytics_screen.dart` y `predictive_service.dart`):**
  * En `predictive_analytics_screen.dart` (líneas 252-258):
    ```dart
    const Icon(Icons.bolt, color: Colors.amberAccent, size: 20),
    const SizedBox(width: 12),
    Expanded(child: Text(_data!.actionText, ...))
    ```
    Y en `predictive_service.dart` (línea 144):
    ```dart
    actionText = "💡 Revisa tu Motor de Abastecimiento para que tus productos estrella no se agoten.";
    ```
    La concatenación del icono vectorial con el emoji en el string produce visualmente `⚡ 💡`.
  * `PredictiveData` solo entrega un escalar único (`predictedNext30DaysSales`) calculado con regresión lineal simple sobre medias móviles, sin exponer el desglose de ventas históricas, promedio diario, pendiente de la recta ni escenarios de dispersión (*Conservador / Esperado / Optimista*).
  * No existe un modal explicativo ni un contenedor `InkWell` con navegación táctil hacia `SmartRestockScreen`.

---

### 1.2. Captura 2 — `Simulador de Escenarios` y `Diagnóstico del Motor`: Bug Lógico al 0% e Iconografía Redundante
* **Síntomas Observados:**
  1. En el simulador, al tener `Variación en Ventas: 0%` y `Variación en Costos: 0%` (lo que da `↑ 0,00 S/ vs proy. base`), el texto afirma erróneamente: **`"¡Excelente! Este escenario aumenta tu ganancia esperada."`**.
  2. Faltan chips de simulación predeterminada para que el comerciante proyecte eventos comunes en un solo toque (campañas, inflación de costos, liquidaciones).
  3. No se indican las cotas en los extremos de los deslizadores (`-50%` a `+100%`) ni se muestran las **Ventas Simuladas** ni los **Costos Simulados** resultantes.
  4. En la tarjeta `"Diagnóstico del Motor"`, se observa un doble robot en el encabezado (un icono azul vectorial `Icons.smart_toy_rounded` junto al emoji `🤖`). El cuerpo es un bloque de puro texto plano monótono.
* **Causa Raíz en Código (`predictive_analytics_screen.dart`):**
  * En las líneas 461-463:
    ```dart
    diffProfit >= 0 
        ? "¡Excelente! Este escenario aumenta tu ganancia esperada." 
        : "Cuidado, este escenario reduce tu rentabilidad."
    ```
    La condición `>= 0` agrupa al `0.00` como "aumento de ganancia", lo cual es una contradicción lógica evidente para el usuario cuando ambos deslizadores están en neutro.
  * En las líneas 288-290:
    ```dart
    const Icon(Icons.smart_toy_rounded, color: Colors.blueAccent, size: 20),
    const SizedBox(width: 8),
    const Text("🤖 Diagnóstico del Motor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    ```
    Se colocó el emoji `🤖` directamente en la cadena del `Text` junto al icono vectorial de Flutter.
  * No hay elementos gráficos (medidor de velocidad, quincenas comparadas, pasos accionables estructurados) que sinteticen visualmente el texto generado.

---

### 1.3. Captura 3 — `Evolución Patrimonial (Desglosada)` y `Estimaciones Teóricas`: Colapso de Escala Gráfica
* **Síntomas Observados:**
  1. En el gráfico de evolución patrimonial, la curva de `Inventario` sube hasta **`S/ 42,642.65`**, mientras que la curva de `Beneficio` es de **`S/ 5.35`**. Debido a la abrumadora disparidad de escala en el mismo eje Y, la curva morada de `Beneficio` queda 100% aplastada contra la base horizontal en `0px` (totalmente plana e invisible).
  2. No hay etiquetas numéricas en el eje Y que permitan inferir los valores de las curvas.
  3. El panel inferior de detalle por fecha (`22/10/2026`) comprime excesivamente las tres columnas (`Beneficio`, `Inventario`, `Ventas`) en una sola línea horizontal apretada.
  4. En la tarjeta `"Estimaciones Teóricas"`, el aviso es un bloque de texto estático sin ningún indicador cuantitativo que señale cuán confiables son las predicciones (dependiendo de la cantidad de snapshots o días registrados).
  5. Los formatos monetarios de la ventana muestran el sufijo `" S/"` o formatos dispares en vez del estándar corporativo `AppCurrency.format(...)` (`S/ #,##0.00`).
* **Causa Raíz en Código (`predictive_analytics_screen.dart`):**
  * En la línea 552, `LineChart` grafica directamente `inventorySpots` y `patrimonySpots` en un solo plano cartesiano sin normalización ni modos de visualización desacoplados:
    ```dart
    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    ```
    No se ofrecen pestañas para alternar entre *Normalizada (0-100%)*, *Valor de Inventario* o *Beneficio y Ventas*, ni se configuran `leftTitles` para mostrar montos monetarios de referencia.
  * El panel de fecha utiliza `Row(mainAxisAlignment: MainAxisAlignment.spaceBetween)` con tres `Column` rígidos que en pantallas medianas o con cifras altas generan tensión de espacio.

---

### 1.4. Captura 4 — `Motor Inteligente de Abastecimiento`: Contradicciones Lógicas de Stock vs ROP y Falta de Control de OC
* **Síntomas Observados:**
  1. **Contradicción Crítica (Stock > ROP marcado como Crítico):** El producto `"Bebida Aloe Vera Uva con Gajos"` posee **`Stock: 5`**, **`ROP: 1`** y **`Agotamiento: 05/03/2027 (en 134 días)`**, pero ostenta el badge rojo **`"Stock Base Crítico"`** y sugiere comprar **`2 und`**. Es decir, tiene stock suficiente para 4 meses y medio, supera el punto de reorden por 5x, ¡y el sistema le exige reabastecer de urgencia!
  2. **Contradicción en Velocidad:** En la métrica se muestra **`Velocidad: 0.0/d`**, pero la tarjeta proyecta que se agotará en 134 días. Si la velocidad fuera 0, nunca se agotaría. El problema es que una venta lenta (ej. `0.037 und/día`) se trunca a `0.0/d` por formateo rígido con 1 solo decimal.
  3. **Productos con Costo `0,00 S/`:** En productos sin costo registrado, el cálculo de inversión muestra `0,00 S/`, lo que distorsiona la `"Inversión Total Sugerida"` inferior sin alertar al comerciante.
  4. **Acceso Oculto a Trazabilidad:** El icono `Icons.history` (`⟲`) está ubicado inmediatamente al lado del costo (`5,00 S/`), sugiriendo falsamente que el monto es un "costo histórico". Nadie intuye que ese icono abre la trazabilidad completa del producto.
  5. **Falta de Control Interactivo:** No hay filtros de urgencia (`Todos`, `🚨 Urgentes`, `⚠️ Preventivos`, `Buscador`). Tampoco es posible desmarcar un producto ni alterar la cantidad sugerida antes de presionar `"Exportar OC"`. El total de inversión inferior es estático y no reacciona a decisiones del usuario.
* **Causa Raíz en Código (`smart_restock_screen.dart` e `inventory_intelligence_service.dart`):**
  * En `smart_restock_screen.dart` (líneas 100 y 290):
    ```dart
    if (currentStock <= rop || currentStock <= 5) { // 💣 FILTRADO FORZADO
    ...
    bool isCritical = item.currentStock <= 5; // 💣 CLASIFICACIÓN FORZADA
    ```
    Se impuso una regla fija `currentStock <= 5` independientemente de si el producto rota una vez cada 6 meses. Por ende, cualquier producto con 5 unidades o menos es considerado "crítico", contradiciendo la propia matemática de Reorder Point (ROP).
  * En la línea 334:
    ```dart
    _buildMetricColumn('Velocidad', '${item.velocityPerDay.toStringAsFixed(1)}/d', ...)
    ```
    Cualquier valor entre `0.001` y `0.049` se renderiza como `0.0/d`.
  * La tarjeta no incluye un `Checkbox` ni controles `-` / `+`, y el botón de trazabilidad es un `IconButton` plano descontextualizado.

---

### 1.5. Captura 5 — `Trazabilidad`: Floats Crudos Infinitos, IDs sin Resolver y Cortes en Scroll
* **Síntomas Observados:**
  1. **Decimales Infinitos en Costos y Precios:**
     * En `"Costo Interno Ajustado"`, se visualiza: `2.4983333333333335 → 2.4983`.
     * En `"Precio de Venta Actualizado"`, se visualiza: `2.998 → 3.0`.
     No se utiliza `AppCurrency` ni redondeo comercial a 2 decimales, exhibiendo floats crudos de SQLite que degradan completamente la apariencia profesional de la app.
  2. **Microcambios Falsos:** Se registran eventos de auditoría por diferencias minúsculas de redondeo binario de coma flotante (`0.00003`).
  3. **IDs Crudos en Clasificación:** En `"Clasificación Modificada"`, solo se lee `→ 4` o `→ 7`. El usuario no tiene cómo saber qué categoría o marca representan esos números de clave primaria.
  4. **Corte Abrupto en el Scroll:** Al scrollear hacia abajo, la primera tarjeta de la línea de tiempo se mete debajo de la tarjeta morada superior y se corta abruptamente por la mitad sin margen de atenuación ni padding adecuado.
  5. **Fechas en Inglés:** Se muestra `"22 Aug 2026 - 09:45"`.
  6. **Iconos Duplicados:** La línea de tiempo contiene un círculo con icono vectorial (ej. `Icons.shopping_cart_checkout`), y al mismo tiempo el título textual lleva un emoji repetido (`📦 Venta en Caja`, `💰 Precio...`, `📊 Costo...`).
* **Causa Raíz en Código (`audit_trail_screen.dart` y `product_repository.dart`):**
  * En `audit_trail_screen.dart` (líneas 345-348):
    ```dart
    Expanded(child: Text("${item['valor_anterior']}", ...)),
    const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
    Expanded(child: Text("${item['valor_nuevo']}", ...)),
    ```
    Se imprime directamente el string crudo guardado en la columna `valor_anterior` y `valor_nuevo` de `product_history`.
  * En `product_repository.dart` (líneas 414-417 y 507-510):
    ```dart
    String oldVal = old[field]?.toString() ?? '';
    String newVal = data[field]?.toString() ?? '';
    if (oldVal != newVal) {
    ```
    Se compara la igualdad de strings en campos flotantes (`2.4983333333333335` != `2.4983`), generando registros espurios en `product_history`.
  * No hay resolución de `marca_id` ni `categoria_id` contra sus respectivas tablas (`marcas` y `categorias`).
  * `DateFormat('dd MMM yyyy')` no especifica el locale en español (`'es'`), retornando abreviaturas inglesas (`Aug`, `Oct`).
  * El `Column` principal divide rígidamente la pantalla con `_buildSummaryCard` fija y `Expanded(ListView.builder)`, provocando que el scroll colisione geométricamente con la base de la tarjeta morada.

---

## 2. ARQUITECTURA DE SOLUCIÓN Y PLAN DE TRABAJO EN 4 FASES

---

### FASE 1: REINGENIERÍA INTEGRAL DE `PROYECCIONES Y CRECIMIENTO`
**Archivos:** `predictive_service.dart`, `predictive_analytics_screen.dart`

#### 1.1. Enriquecimiento del Modelo y Servicio Predictivo (`predictive_service.dart`)
1. Ampliar `PredictiveData` con los metadatos necesarios para la explicabilidad didáctica:
   * `totalSnapshotsUsed`: Cantidad de días de historial considerados.
   * `dailyAverageSales`: Promedio diario de ventas en el periodo de análisis.
   * `trendSlopeM` y `interceptB`: Parámetros matemáticos de la regresión lineal $y = mx + b$.
   * `previous15Sales` y `current15Sales`: Totales vendidos en la quincena previa y la quincena actual.
   * `confidenceScore`: Clasificación del rigor estadístico (`Bajo`, `Medio`, `Alto`) según la cantidad de días con datos reales.
   * `conservativeEstimate`: Escenario pesimista (80% o percentil bajo).
   * `expectedEstimate`: Escenario esperado (100% de la regresión).
   * `optimisticEstimate`: Escenario optimista (120% o tendencia alta).
2. Limpiar `actionText`: Eliminar el emoji `💡` incrustado en el texto de servicio para evitar duplicidad con el icono vectorial de la UI.

#### 1.2. Sistema Universal de Modales Explicativos Didácticos (`InteractiveSheetWrapper`)
Implementar en cada una de las 4 secciones un botón/píldora interactiva con el icono `ⓘ "¿Cómo se calcula?"`:
1. **Modal de la Proyección a 30 Días:**
   * Desglose paso a paso con los **datos reales del comercio**:
     - *Paso 1 (Recopilación):* Número exacto de días históricos analizados.
     - *Paso 2 (Suavizado):* Aplicación de media móvil de 7 días para neutralizar picos atípicos.
     - *Paso 3 (Regresión Lineal):* Ecuación matemática aplicada ($y = mx + b$) mostrando cómo el ritmo diario proyecta los próximos 30 días.
     - *Paso 4 (Resultado):* Cómo se llega a la cifra final (ej. `S/ 21.68`).
   * *Valor Práctico:* Consejos concretos sobre cómo utilizar este monto para programar compras, estimar flujo de caja y no sobreendeudarse con proveedores.
2. **Modal del Simulador de Escenarios:**
   * Explicación de la fórmula de sensibilidad comercial: cómo la variación de ventas incrementa los ingresos brutos, cómo la variación de costos altera el costo de mercancía vendida (COGS), y el resultado neto en el bolsillo del dueño.
3. **Modal del Diagnóstico del Motor:**
   * Explicación del cálculo de velocidad comercial (% de aceleración quincenal) comparando la quincena actual contra la quincena anterior.
4. **Modal de la Evolución Patrimonial:**
   * Distinción clara entre capital inmovilizado en mercadería (stock valorizado a costo) y beneficio líquido generado por ventas.

#### 1.3. Rediseño del Encabezado y Tarjeta Principal de Proyección
1. **Desglose de los 3 Escenarios de Cierre:**
   * Incorporar una fila de 3 tarjetas compactas en la tarjeta principal:
     - 🛡️ *Conservador:* `S/ XX.XX`
     - 🎯 *Esperado:* `S/ 21.68` (destacado)
     - 🚀 *Optimista:* `S/ YY.YY`
2. **Corrección de Iconografía y Navegación:**
   * Sustituir el doble icono `⚡ 💡` por un icono vectorial limpio `Icons.lightbulb_outline`.
   * Envolver la tarjeta de consejo en un `InkWell` con micro-animación táctil para que al tocarla navegue de inmediato a `SmartRestockScreen`.

#### 1.4. Perfeccionamiento del Simulador de Escenarios
1. **Corrección del Bug Lógico al 0%:**
   * Establecer la lógica de evaluación en 3 estados mutuamente excluyentes:
     ```dart
     if (diffProfit.abs() < 0.01) {
       statusText = "Escenario base proyectado. Mueve los controles para simular variaciones.";
       statusColor = Colors.grey;
     } else if (diffProfit > 0) {
       statusText = "¡Excelente! Este escenario aumenta tu ganancia esperada.";
       statusColor = Colors.green;
     } else {
       statusText = "Cuidado, este escenario reduce tu rentabilidad proyectada.";
       statusColor = Colors.redAccent;
     }
     ```
2. **Chips de Simulación Rápida en 1 Toque:**
   * `📈 Campaña (+30% ventas)`: Ajusta ventas a +30%, costos a 0%.
   * `🚛 Subida Proveedor (+10% costos)`: Ajusta ventas a 0%, costos a +10%.
   * `🏷️ Liquidación (+20% ventas, -5% costo/margen)`: Aplica combinación balanceada.
   * `🔄 Restaurar 0%`: Restablece ambos sliders a 0%.
3. **Métricas Desglosadas:**
   * Mostrar debajo del Beneficio Neto Simulado dos mini-indicadores: **Ventas Simuladas (`AppCurrency.format(simSales)`)** y **Costos Simulados (`AppCurrency.format(simCosts)`)**.
4. **Etiquetas de Rango:** Indicar claramente los extremos de cada slider (`-50%` a `+100%`).

#### 1.5. Transformación Visual de Diagnóstico y Estimaciones
1. **Diagnóstico del Motor:**
   * Eliminar el emoji `🤖` repetido en el título.
   * Reemplazar el bloque de texto plano por:
     - Medidor visual de aceleración comercial con barra de progreso y porcentaje coloreado.
     - Dos píldoras comparativas: `Quincena Previa: S/ XX` vs `Quincena Actual: S/ YY`.
     - Fila de recomendaciones accionables con iconos vectoriales temáticos (`Icons.star_rounded`, `Icons.campaign_rounded`).
2. **Estimaciones Teóricas con Indicador de Confianza:**
   * Rediseñar como un banner compacto tipo acordeón con un medidor de **Nivel de Confianza Estadística**:
     - *Bajo (1-6 días de snapshots):* Indicador ámbar/rojo con recomendación de seguir registrando ventas diarias.
     - *Medio (7-29 días):* Indicador azul con fiabilidad moderada.
     - *Alto (30+ días):* Indicador verde con máxima precisión proyectiva.

#### 1.6. Solución Definitiva al Gráfico de Evolución Patrimonial
1. **Selector de Vistas por Pestañas:**
   * Agregar en la cabecera de la tarjeta un selector segmentado con 3 opciones:
     1. `📊 Comparativa Normalizada`: Ambas series se escalan porcentualmente (0% a 100% respecto a su valor máximo en el periodo), permitiendo observar visualmente si el beneficio y el inventario crecen al mismo ritmo sin que una curva aplaste a la otra.
     2. `📦 Valor Inventario`: Muestra la serie de inventario en soles (escala de decenas de miles).
     3. `💰 Beneficio y Ventas`: Muestra únicamente beneficio y ventas diarias en soles (escala de decenas/cientos), logrando que la curva morada sea 100% visible, ondulada y dinámica.
2. **Eje Y con Etiquetas Monetarias:** Habilitar `leftTitles` con formateo abreviado (`S/ 0`, `S/ 5k`, `S/ 10k`, etc.).
3. **Panel de Detalle por Fecha:** Reestructurar el panel inferior para presentar las tres métricas (`Beneficio`, `Inventario`, `Ventas`) en un diseño aireado, con tarjetas individuales y tipografía limpia.
4. **Migración Monetaria Universal:** Estandarizar todos los textos a `AppCurrency.format(...)`.

---

### FASE 2: REINGENIERÍA DEL `MOTOR INTELIGENTE DE ABASTECIMIENTO`
**Archivos:** `smart_restock_screen.dart`, `inventory_intelligence_service.dart`, `purchase_order_generator.dart`

#### 2.1. Auditoría y Corrección Matemática de ROP, Velocidad y Stock
1. **Eliminación del Umbral Forzado `Stock <= 5`:**
   * Eliminar la condición rígida que marcaba a cualquier producto con 5 unidades como crítico.
   * Implementar la jerarquía semántica oficial de reabastecimiento:
     * **`🚨 Agotado`:** `currentStock == 0`.
     * **`🔴 Crítico (Bajo ROP)`:** `currentStock > 0 && currentStock <= rop`. Requiere compra inmediata.
     * **`🟠 Preventivo (Cercano a ROP)`:** `currentStock > rop && currentStock <= rop * 1.5`. Stock suficiente por ahora, pero en zona de seguimiento.
     * **`🟢 Saludable`:** `currentStock > rop * 1.5`. No requiere orden de compra.
2. **Cálculo Coherente de Cantidad Sugerida (`suggestedQty`):**
   * Si el producto está en estado `Saludable` o no requiere compra urgente, su sugerencia base debe ser 0 (o no incluirse por defecto en la selección de compra).
   * Para productos en estado Crítico o Preventivo, la sugerencia debe calcularse para reponer el inventario hasta el stock meta mensual:
     $$\text{Sugerido} = \max\left(1, (\text{ROP} + \text{EOQ}) - \text{StockActual}\right)$$

#### 2.2. Formateo Humano de Velocidad y Fechas de Agotamiento
1. **Velocidad de Ventas Adaptativa:**
   * Si `velocity == 0.0`: Mostrar `"—"` o `"Sin ventas"` y **no calcular fecha ficticia de agotamiento**.
   * Si `0.0 < velocity < 0.1`: Formatear en escala mensual o con dos decimales, por ejemplo:
     - `"${(velocity * 30).toStringAsFixed(1)} / mes"` o `"${velocity.toStringAsFixed(2)} / día"`.
   * Si `velocity >= 0.1`: Formatear como `"${velocity.toStringAsFixed(1)} / día"`.
2. **Fecha de Agotamiento:**
   * Solo mostrar la caja azul de agotamiento si la velocidad es real y el agotamiento ocurrirá en menos de 365 días.
   * Si el agotamiento proyectado es mayor a 1 año, indicar: `"Stock seguro (+1 año)"`.

#### 2.3. Gestión de Productos sin Costo (`0.00 S/`)
1. Detectar si `item.cost <= 0`.
2. Mostrar en la tarjeta un badge de alerta visible: `"⚠️ Sin costo registrado"`.
3. Ofrecer un botón rápido `"Asignar costo"` que permita registrar el costo unitario de compra sin salir del flujo.
4. En el resumen de la barra inferior, incluir una nota si existen productos seleccionados con costo cero: `"⚠️ X items sin costo no suman al total"`.

#### 2.4. Rediseño de la Tarjeta y Acceso Claro a Trazabilidad
1. Separar inequívocamente el costo unitario de la trazabilidad:
   * Costo claramente rotulado: `"Costo est.: S/ 5.00"`.
2. Convertir el botón de trazabilidad en una píldora/botón táctil destacado:
   * **`"🔍 Historial / Trazabilidad"`**, con fondo suave, borde sutil e icono vectorial visible.

#### 2.5. Barra Superior de KPIs y Chips de Filtro
1. **Fila de KPIs de Abastecimiento:**
   * *Por Reabastecer (N)* | *Inversión Sugerida (S/ ...)* | *Agotados (M)*.
2. **Chips de Filtrado Rápido:**
   * `Todos` | `🚨 Urgentes (Stock ≤ ROP)` | `🟠 Preventivos` | `🔍 Buscador interactivo por nombre/marca`.

#### 2.6. Selección Interactiva y Ajuste Dinámico de la Orden de Compra (OC)
1. Incorporar en cada tarjeta de producto:
   * Un `Checkbox` de selección (seleccionados por defecto los productos urgentes con `stock <= rop`).
   * Controles interactivos `-` y `+` para incrementar o decrementar la cantidad a pedir en vivo.
2. Reactividad en la Barra Inferior (`bottomNavigationBar`):
   * La **`Inversión Total Sugerida`** se recalcula a **0ms** considerando exclusivamente los productos marcados con sus cantidades ajustadas.
   * Opción de `"Seleccionar Todos"` y `"Deseleccionar Todos"`.
3. Generación de PDF Adaptativa (`PurchaseOrderGenerator.exportToPdf`):
   * Exporta únicamente los productos seleccionados por el comerciante con las cantidades que él mismo modificó.

---

### FASE 3: REINGENIERÍA TOTAL DE LA VENTANA `TRAZABILIDAD`
**Archivos:** `audit_trail_screen.dart`, `product_repository.dart`, `inventory_intelligence_service.dart`

#### 3.1. Corrección de Floats Crudos y Blindaje de Microcambios
1. **Formateo Monetario con `AppCurrency`:**
   * En eventos de `costo_unitario_calculado` y `precio_venta_final`, parsear los valores anterior y nuevo y formatearlos como moneda peruana:
     - `"S/ 2.50 → S/ 2.50"` (en lugar de `2.4983333333333335 → 2.4983`).
2. **Filtro de Ruido por Coma Flotante en `product_repository.dart`:**
   * Al actualizar presentaciones de producto, si el campo modificado es un valor flotante (`costo_unitario_calculado` o `precio_venta_final`), verificar que la diferencia absoluta sea significativa antes de escribir en `product_history`:
     ```dart
     if ((oldDouble - newDouble).abs() >= 0.005) {
       // Insertar registro de auditoría real
     }
     ```
   * En `audit_trail_screen.dart`, filtrar en la carga cualquier registro histórico antiguo cuya diferencia sea despreciable (< 0.005) para no ensuciar la línea de tiempo.

#### 3.2. Resolución Relacional de IDs de Clasificación
1. En `inventory_intelligence_service.dart` (en `getAuditTrail`):
   * Al consultar los eventos de `product_history` donde `campo_modificado` sea `'categoria_id'` o `'marca_id'`, realizar una consulta auxiliar a las tablas `categorias` y `marcas` para mapear los IDs numéricos a sus nombres reales.
2. En `audit_trail_screen.dart`:
   * Renderizar con total claridad para el usuario:
     - `"Categoría: Bebidas → Abarrotes"` (en lugar de `→ 4`).
     - `"Marca: Genérico → San Carlos"` (en lugar de `→ 7`).

#### 3.3. Solución Geométrica al Scroll y Eliminación de Cortes Abruptos
1. Modificar la estructura de layout:
   * Migrar de `Column(Header, Expanded(ListView))` a un `CustomScrollView` con `SliverToBoxAdapter` para la cabecera morada, o aplicar un margen y `ClipRRect` superior en el listado con padding holgado.
   * De este modo, al desplazarse la lista, las tarjetas pasan suavemente con margen respirable sin rebanarse contra el borde inferior de la cabecera.

#### 3.4. Fechas en Español e Iconografía Limpia
1. **Fechas en Español Oficial:**
   * Utilizar `DateFormat("dd 'de' MMM yyyy • hh:mm a", 'es').format(date)` para producir `"22 de ago. 2026 • 09:45 AM"`.
2. **Eliminación de Iconos Duplicados:**
   * El círculo lateral de la línea de tiempo conserva el icono vectorial representativo.
   * Los títulos de las tarjetas se depuran eliminando los emojis repetidos (`Venta en Caja`, `Precio de Venta Actualizado`, `Costo Interno Ajustado`, `Clasificación Modificada`).

#### 3.5. Cabecera 360 y Filtros por Tipo de Evento
1. **Cabecera Enriquecida del Producto:**
   * Además del nombre y stock actual, mostrar:
     - **Costo Actual:** `AppCurrency.format(...)`
     - **Precio de Venta:** `AppCurrency.format(...)`
     - **Margen Comercial:** `%`
     - **Balance Histórico:** `Total Entradas (+X)` vs `Total Salidas (-Y)`.
2. **Chips de Filtro de Auditoría:**
   * `Todos` | `📦 Movimientos de Stock` | `💰 Precios y Costos` | `🏷️ Ficha del Producto`.
3. **Detalle Enriquecido en Movimientos:**
   * Mostrar el impacto en stock con etiqueta clara: `Cant: -1 und` (en rojo para ventas/mermas, en verde para compras/ingresos), indicando el comprobante asociado si está disponible.

---

### FASE 4: VERIFICACIÓN CON ÁRBITRO ADVERSARIAL Y SUITE DE PRUEBAS
**Archivo:** `app_movil/test/projections_restock_and_traceability_reengineering_test.dart`

Diseño e implementación de una suite exhaustiva de pruebas unitarias y de widgets que actúe como Árbitro Adversarial para verificar:
1. **Arbitraje de Proyecciones (`PredictiveAnalyticsScreen` y `PredictiveService`):**
   * Cálculo correcto de escenarios Conservador, Esperado y Optimista.
   * Comportamiento del Simulador al 0% (comprobando que NO afirme que aumenta la ganancia).
   * Comportamiento al presionar los chips rápidos de simulación.
   * Apertura exitosa de los modales explicativos didácticos con `InteractiveSheetWrapper`.
   * Conmutación de las 3 vistas del gráfico patrimonial y presencia de etiquetas en el eje Y.
2. **Arbitraje de Abastecimiento (`SmartRestockScreen` e `InventoryIntelligenceService`):**
   * Coherencia matemática estricta: un producto con Stock 5 y ROP 1 jamás debe catalogarse como Crítico ni sugerir compras forzadas.
   * Manejo de velocidad de rotación lenta sin truncamiento engañoso a 0.0/d.
   * Detección de productos sin costo registrado.
   * Interactividad de checkboxes y controles `-` / `+`, comprobando el recálculo en vivo de la Inversión Total y la exportación coherente a PDF.
3. **Arbitraje de Trazabilidad (`AuditTrailScreen`):**
   * Formateo de precios y costos con `AppCurrency` (cero decimales infinitos de float).
   * Supresión de microcambios espurios de redondeo (< 0.005).
   * Resolución de IDs de categoría y marca a nombres legibles en texto.
   * Localización de fechas en español y cero desbordamientos o cortes geométricos.

---

## 3. MATRIZ DE TRAZABILIDAD: PROBLEMAS VS SOLUCIONES Y VERIFICACIÓN

| Captura / Requerimiento | Problema Actual en Código | Solución Diseñada | Verificación Adversarial |
| :--- | :--- | :--- | :--- |
| **Captura 1: Proyección a 30 Días** | Caja negra sin explicabilidad; doble icono `⚡ 💡`; consejo estático. | Modal interactivo paso a paso (`InteractiveSheetWrapper`); desglose de 3 escenarios; eliminación del emoji duplicado; tap navega a Abastecimiento. | `testWidgets`: Verifica modal con datos reales, 3 escenarios y navegación al tocar consejo. |
| **Captura 2: Simulador de Escenarios** | 0% afirma "aumenta tu ganancia"; sin chips rápidos ni límites visibles; faltan ventas/costos simulados. | Lógica trifásica (0%, >0, <0); chips rápidos de 1 toque; etiquetas `-50%` a `+100%`; visualización de Ventas y Costos Simulados. | `test`: Verifica strings exactos en 0%, +10% y -10%; verifica valores de simulación. |
| **Captura 2: Diagnóstico del Motor** | Doble robot (`smart_toy` + `🤖`); bloque de texto plano. | Elimina emoji duplicado; tarjeta visual con velocímetro comercial, píldoras quincenales comparativas y pasos vectoriales. | `testWidgets`: Verifica ausencia de emoji duplicado y renderizado del medidor visual. |
| **Captura 3: Gráfico Patrimonial** | Disparidad de escala (42k vs 5.35) aplasta curva morada a 0px; sin eje Y; detalle apretado. | Pestañas de vista (*Normalizada %*, *Inventario*, *Beneficio/Ventas*); etiquetas monetarias en eje Y; panel de fecha aireado. | `testWidgets`: Alterna pestañas del gráfico y valida visibilidad de series y formato `AppCurrency`. |
| **Captura 3: Estimaciones Teóricas** | Bloque estático de puro texto. | Banner/acordeón con indicador de Nivel de Confianza Estadística (Bajo/Medio/Alto). | `testWidgets`: Valida cálculo y badge del nivel de confianza según cantidad de snapshots. |
| **Captura 4: Stock > ROP Crítico** | Regla arbitraria `Stock <= 5` califica erróneamente productos con 134 días de stock como críticos. | Jerarquía semántica estricta basada exclusivamente en ROP y Stock real; sugerencia coherente con déficit objetivo. | `test`: Producto con Stock 5 y ROP 1 se clasifica como Saludable/Preventivo y no sugiere compra crítica. |
| **Captura 4: Velocidad 0.0/d** | Truncamiento a 1 decimal contradice agotamiento en 134 días. | Formato humano adaptativo (`X.X / mes` o `0.XX / día`); si es 0, no inventa fecha de agotamiento. | `test`: Valida formato para velocidades de 0.037 u/d y velocidades de 0 u/d. |
| **Captura 4: Costo 0.00 S/** | Productos sin costo falsean total sugerido. | Alerta `"⚠️ Sin costo registrado"`, opción de asignación rápida y aviso en resumen inferior. | `testWidgets`: Comprueba badge de costo faltante y recálculo seguro. |
| **Captura 4: Control de OC** | Botón de trazabilidad confuso; sin checkboxes ni botones `+`/`-` para ajustar compra. | Botón explícito `"🔍 Historial / Trazabilidad"`; checkboxes individuales/todos; controles `-`/`+` reactivos en vivo. | `testWidgets`: Simula ajuste de cantidades y valida recálculo instantáneo de la inversión total. |
| **Captura 5: Floats Infinitos** | Imprime floats crudos `2.4983333333333335 → 2.4983`. | Formateo estricto con `AppCurrency.format(...)` y filtro de microcambios por redondeo (< 0.005). | `test`: Valida que los cambios exhiban `S/ #,##0.00` y descarten diferencias insignificantes. |
| **Captura 5: IDs Crudos** | Muestra `→ 4` o `→ 7` en clasificación. | Mapeo relacional con tablas `categorias` y `marcas` mostrando nombres reales. | `test`: Valida resolución de ID 4 a "Bebidas" y 7 a "San Carlos". |
| **Captura 5: Scroll y Formato** | Corte de tarjetas bajo cabecera morada; fechas en inglés; iconos duplicados. | Layout respirable sin corte brusco; fechas en español (`es`); eliminación de emojis repetidos en títulos. | `testWidgets`: Verifica ausencia de cortes, fechas con "ago." y títulos limpios sin emojis redundantes. |

---

## 4. CHECKLIST DE BLINDAJE Y PROTOCOLO DE NO-REGRESIÓN

* [ ] Cero dependencias externas adicionales no autorizadas.
* [ ] Cero alteraciones al esquema de base de datos que rompan compatibilidad con versiones previas.
* [ ] Formato monetario peruano oficial unificado en todas las pantallas mediante `AppCurrency.format(num?)` (`S/ #,##0.00`).
* [ ] Todos los modales didácticos encapsulados bajo `InteractiveSheetWrapper` respetando las pautas de accesibilidad y blindaje de barra de navegación Android.
* [ ] Conservación de la generación de PDF para órdenes de compra funcionando con selección dinámica de productos.
* [ ] Ejecución y aprobación del 100% de las pruebas unitarias y de widgets en `app_movil/test/`.
