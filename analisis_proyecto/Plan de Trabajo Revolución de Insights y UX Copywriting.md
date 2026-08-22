# Plan de Trabajo: Revolución de Insights y UX Copywriting

## Diagnóstico del Estado Actual

Tras analizar profundamente los **12 archivos** del módulo de Analytics, he identificado los siguientes hallazgos:

### Datos Disponibles en `AnalyticsData` (Provider)
El provider ya calcula y expone **toda** la data necesaria para construir mensajes ricos. El problema no es la falta de datos, sino que **los widgets no los aprovechan**:

| Dato Disponible | Usado en Insights? | Widget que lo ignora |
|---|---|---|
| `totalSales` (monto total) | ❌ Parcial | `sales_by_day_chart` (no muestra el monto del día) |
| `totalTransactions` (# ventas) | ❌ No | `top_clients_card` (no dice cuántas compras hizo el cliente) |
| `averageTicket` | ❌ No | `kpi_summary_row` (solo texto genérico en la explicación) |
| `salesGrowthRate` | ❌ No | `kpi_summary_row` (no lo incorpora al texto de explicación) |
| `monto_vendido` (por producto) | ❌ Parcial | `top_products_chart` (lo muestra en la UI pero no en el insight) |
| `inventoryTurnoverRatio` | ❌ No | `kpi_summary_row` (texto estático sin comparar contra benchmark) |
| `immobilizedCapital` | ❌ No | `kpi_summary_row` (no lo usa en la explicación expandida) |
| `dias_para_agotarse` | ⚠️ Placeholder | `restock_alerts_card` (usa valor hardcodeado `?? 3`) |

### Textos Genéricos Identificados (Copia Textual del Código)

| Archivo | Texto Actual (Estático) | Problema |
|---|---|---|
| [`sales_by_day_chart.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/charts/sales_by_day_chart.dart#L194-L196) | _"Las ventas de este día están un X% por encima/debajo de tu promedio diario (S/ Y)."_ | ❌ **No dice cuánto se vendió ese día** |
| [`origin_pie_chart.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/charts/origin_pie_chart.dart#L190-L192) | _"Este canal representa el X% de tus ventas totales. Analiza sus costos de adquisición para optimizar su rentabilidad."_ | ❌ Consejo genérico sin monto ni acción concreta |
| [`payment_method_chart.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/charts/payment_method_chart.dart#L195-L197) | _"El X% del ingreso se procesó vía Y. Monitoriza este canal para prever posibles comisiones de pasarela."_ | ❌ No diferencia entre Yape/Efectivo/Tarjeta |
| [`top_products_chart.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/charts/top_products_chart.dart#L171-L173) | _"El producto X es un pilar de tu negocio con Y unidades vendidas. Asegúrate de nunca quebrar stock..."_ | ❌ No menciona el ingreso generado (S/) |
| [`top_clients_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/dashboard/top_clients_card.dart#L123-L125) | _"Fidelización: X es uno de tus mayores compradores históricos. Envíale una oferta personalizada..."_ | ❌ No dice cuánto gastó ni sugiere acción con monto |
| [`top_categories_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/dashboard/top_categories_card.dart#L112-L114) | _"La categoría X es un motor clave para tu negocio. Considera ampliar el surtido..."_ | ❌ No dice cuántas unidades vendidas |
| [`restock_alerts_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/dashboard/restock_alerts_card.dart#L134-L137) | _"...Según el algoritmo predictivo, te quedarás sin stock en aproximadamente X días."_ | ⚠️ `dias_para_agotarse` está hardcodeado como `?? 3` |
| [`kpi_summary_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/dashboard/kpi_summary_row.dart#L60-L110) | 7 explicaciones genéricas tipo enciclopedia financiera | ❌ No usan los valores reales del negocio |

---

## Fase 1: Corrección de Datos Faltantes [Ventas por Día]

> [!IMPORTANT]
> **Prioridad CRÍTICA.** El usuario toca una barra y no ve cuánto vendió. Es el error más visible.

### Archivo: [`sales_by_day_chart.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/charts/sales_by_day_chart.dart)

#### Cambio en `_buildDetailPanel` (líneas 160-205)

**ANTES:**
```dart
Text("Día: $name", ...),
Text("Las ventas de este día están un ${diffPct.abs().toStringAsFixed(1)}% ${isAboveAvg ? 'por encima' : 'por debajo'} de tu promedio diario (${widget.formatCurrency(avgVal)}).", ...)
```

**DESPUÉS (propuesta):**
```dart
Text("$name — ${widget.formatCurrency(amount)}", ...),
Text(
  isAboveAvg 
    ? "Vendiste ${widget.formatCurrency(amount)} los días $name. Esto es un ${diffPct.abs().toStringAsFixed(1)}% por encima de tu promedio diario de ${widget.formatCurrency(avgVal)}. ¡Aprovecha este día para lanzar ofertas!"
    : "Los días $name generaste ${widget.formatCurrency(amount)}, un ${diffPct.abs().toStringAsFixed(1)}% por debajo del promedio (${widget.formatCurrency(avgVal)}). Considera promociones flash para impulsar este día.",
  ...
)
```

**Impacto:** El usuario ahora ve el monto exacto como primera información, seguido del contexto comparativo y una sugerencia accionable.

---

## Fase 2: Redacción Dinámica (UX Copywriting) para Gráficos

### 2.1 — [`origin_pie_chart.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/charts/origin_pie_chart.dart)

**Lógica condicional propuesta:**
```
SI porcentaje >= 50%:
  "El canal {name} es tu FUENTE PRINCIPAL con {monto} ({pct}%). 
   Más de la mitad de tus ingresos dependen de él. Diversifica para reducir riesgos."

SI porcentaje >= 20%:
  "{name} generó {monto} ({pct}%). Es un canal relevante. 
   Mantén su rendimiento y busca oportunidades de crecimiento aquí."

SI porcentaje < 20%:
  "{name} aportó {monto} ({pct}%). Es un canal secundario. 
   Evalúa si vale la pena invertir más en este origen o redirigir esfuerzos."
```

### 2.2 — [`payment_method_chart.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/charts/payment_method_chart.dart)

**Lógica condicional por tipo de método de pago:**
```
SI nombre contiene "yape" o "plin" (billetera digital):
  "{name} generó {monto} ({pct}% del total). 
   Recuerda verificar tus límites de recepción diaria y que tu QR esté siempre visible."

SI nombre contiene "efectivo":
  "{name} movió {monto} ({pct}%). 
   Realiza arqueos de caja diarios para evitar faltantes y registra todo en el sistema."

SI nombre contiene "tarjeta" o "visa" o "pos":
  "{name} procesó {monto} ({pct}%). 
   Monitorea las comisiones del POS para asegurar que tu margen no se erosione."

DEFAULT (transferencia, otro):
  "{name} canalizó {monto} ({pct}% del ingreso). 
   Verifica que todos los depósitos hayan sido acreditados correctamente."
```

### 2.3 — [`top_products_chart.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/charts/top_products_chart.dart)

**Propuesta con ingreso real (dato `monto_vendido` ya existe en la query):**
```
SI monto_vendido != null:
  "{name} ha generado S/ {monto_vendido} en {total_vendido} unidades vendidas. 
   Su ticket unitario promedio es S/ {monto/total}. No dejes que se quede sin stock."

SI es el #1 (index == 0):
  "🥇 {name} es tu ESTRELLA ABSOLUTA: {total} unidades y S/ {monto}. 
   Este producto sostiene tu negocio. Negocia mejores precios con tu proveedor por volumen."
```

### 2.4 — [`top_categories_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/dashboard/top_categories_card.dart)

**Propuesta con unidades reales:**
```
SI index == 0 (categoría líder):
  "🏆 {name} lidera con {total} unidades vendidas. 
   Es tu categoría estrella. Amplía el surtido aquí: más variedad = más ventas."

SI total > 50:
  "{name} movió {total} unidades. Tiene alta rotación. 
   Asegura abastecimiento constante de esta línea."

DEFAULT:
  "{name} vendió {total} unidades. Hay espacio para crecer. 
   Considera promociones cruzadas con categorías más fuertes."
```

### 2.5 — [`monthly_sales_chart.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/charts/monthly_sales_chart.dart)

**Propuesta para el panel de detalle (actualmente solo muestra fecha y monto):**
```
Agregar comparación con el punto anterior de la serie:
  "{fecha}: Vendiste {monto}. 
   {SI punto_anterior existe: 'Esto representa un {cambio}% respecto al periodo anterior.'}"
```

---

## Fase 3: Enriquecimiento de Modales y Listas

### 3.1 — [`top_clients_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/dashboard/top_clients_card.dart)

**Propuesta con datos reales del cliente:**
```
SI index == 0 (cliente #1):
  "🏆 {name} es tu cliente VIP con S/ {total_comprado} en compras. 
   ¡Envíale una oferta exclusiva por WhatsApp usando el Cotizador Manual para premiar su lealtad!"

SI index == 1 o 2:
  "{name} ha invertido S/ {total_comprado} en tu negocio. 
   Está a punto de convertirse en tu próximo VIP. Una promoción personalizada podría impulsar su recurrencia."

DEFAULT:
  "{name} acumula S/ {total_comprado}. 
   Cada cliente cuenta. Recuérdale tus ofertas vigentes para fidelizarlo."
```

> [!NOTE]
> La query actual de `topClientsQuery` **no trae** el número de compras (`COUNT`). Para el mensaje ideal ("3 compras, ticket promedio de..."), se necesitaría agregar `COUNT(v.id) as num_compras` a la query SQL en `analytics_provider.dart`. Esto es un cambio mínimo y seguro.

### 3.2 — [`restock_alerts_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/dashboard/restock_alerts_card.dart)

**Problema crítico:** `dias_para_agotarse` está hardcodeado con `?? 3` (placeholder). Hay dos opciones:
- **Opción A (recomendada):** Calcular la velocidad de venta desde la query SQL (promedio de unidades vendidas por semana del producto) y dividir `stock_actual / velocidad_semanal * 7`.
- **Opción B (simple):** Eliminar la mención de "días" y usar solo el dato real disponible (stock actual vs umbral de alerta).

**Propuesta de texto:**
```
SI actual == 0:
  "⛔ {name} se agotó completamente. 
   Cada día sin stock es una venta perdida. Contacta a tu proveedor HOY."

SI actual <= 2:
  "🔴 {name} tiene solo {actual} unidad(es). Nivel CRÍTICO. 
   Al cruzar el umbral de seguridad ({alerta}), el riesgo de quiebre es inminente. Actúa ya."

DEFAULT:
  "⚠️ {name}: {actual} de {alerta} unidades de seguridad. 
   Programa tu reabastecimiento antes de que baje a nivel crítico."
```

### 3.3 — [`kpi_summary_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/dashboard/kpi_summary_row.dart)

**Transformación de "explicaciones de enciclopedia" a "tips de mentor con datos reales":**

| KPI | Texto Actual | Texto Propuesto |
|---|---|---|
| **Ventas** | _"El número total de transacciones..."_ | _"Has completado {totalTransactions} ventas. {SI > 100: '¡Excelente volumen! Tu negocio tiene ritmo constante.' / SI < 10: 'Pocas ventas registradas. Revisa si estás capturando todas las transacciones en el sistema.'}"_ |
| **Crecimiento** | _"Compara el volumen de ventas actual..."_ | _"{SI > 0: 'Creciste un {rate}% respecto al mes pasado. ¡Sigue así!' / SI < 0: 'Tus ventas cayeron un {rate}%. Revisa qué productos estrella podrían estar sin stock o lanza una promoción flash.'}"_ |
| **Rotación** | _"Indica cuántas veces se ha vendido..."_ | _"Tu inventario rota {ratio} veces. {SI >= 2: '¡Excelente! Tu mercancía se mueve rápido.' / SI >= 1: 'Rotación saludable, pero hay espacio para mejorar.' / SI < 1: 'Rotación lenta. Tienes capital estancado. Considera liquidar productos muertos.'}"_ |
| **Valor Stock** | _"Es el dinero total invertido..."_ | _"Tienes {valor} invertidos en inventario. {SI immobilizedCapital > 0: 'De eso, {immobilized} están estancados en productos sin ventas en 90 días.'}"_ |
| **Inmovilizado** | _"Capital estancado en productos..."_ | _"Tienes {valor} atrapados en {deadStockCount} productos sin movimiento. {SI > 0: 'Crea una Promoción de Liquidación para recuperar este dinero y reinvertirlo en productos que sí se venden.'}"_ |
| **Liq. Recuperada** | _"Mide el dinero recuperado..."_ | _"{SI > 0: '¡Has recuperado {valor} vendiendo stock estancado! Sigue usando las promociones de liquidación.' / SI == 0: 'Aún no has recuperado liquidez. Crea tu primera Promoción de Liquidación desde el módulo de Promociones.'}"_ |
| **Ticket Prom.** | _"Es el monto promedio que gasta..."_ | _"Cada cliente gasta en promedio {valor} por compra. {SI >= 50: 'Buen ticket. Ofrece combos para subirlo aún más.' / SI < 20: 'Ticket bajo. Incentiva ventas cruzadas (ej: \"¿Necesitas también X?\").'}"_ |

---

## Cambio Necesario en el Provider (Mínimo)

#### [MODIFY] [`analytics_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/providers/analytics_provider.dart#L272-L280)

Agregar `COUNT(v.id) as num_compras` a la query de `topClientsQuery` para que el widget de clientes pueda mostrar el número de compras y calcular el ticket promedio del cliente:

```sql
SELECT c.nombre_completo, 
       SUM(v.monto_total) as total_comprado,
       COUNT(v.id) as num_compras   -- NUEVO
FROM ventas v
JOIN clientes c ON v.cliente_id = c.id
WHERE v.negocio_id = ? AND v.is_archived = 0
GROUP BY c.id
ORDER BY total_comprado DESC
LIMIT 5
```

---

## Resumen de Archivos a Modificar

| Fase | Archivo | Tipo de Cambio |
|---|---|---|
| 1 | `sales_by_day_chart.dart` | Agregar monto al panel de detalle |
| 2 | `origin_pie_chart.dart` | Reescribir insight con lógica condicional |
| 2 | `payment_method_chart.dart` | Reescribir con detección del tipo de pago |
| 2 | `top_products_chart.dart` | Agregar ingreso real al insight |
| 2 | `top_categories_card.dart` | Agregar unidades y lógica por ranking |
| 2 | `monthly_sales_chart.dart` | Mejorar panel de detalle con comparación |
| 3 | `top_clients_card.dart` | Reescribir con monto y ranking |
| 3 | `restock_alerts_card.dart` | Humanizar alertas con niveles de urgencia |
| 3 | `kpi_summary_row.dart` | Reescribir 7 explicaciones con datos reales |
| 3 | `analytics_provider.dart` | Agregar `COUNT` a query de clientes |

> [!IMPORTANT]
> **Aprobación Requerida:** Revisa este plan fase por fase. Cuando lo apruebes, comenzaré la ejecución con la **Fase 1** (corrección del monto faltante en "Ventas por Día"). Cada fase se implementará y verificará con `flutter analyze` antes de pasar a la siguiente.
