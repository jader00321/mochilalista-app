# Plan: Mejora Integral del Módulo de Estadísticas, Proyecciones y Motor Inteligente

## Contexto del Problema

Tras un análisis profundo del código fuente y de las capturas proporcionadas, se identificaron los siguientes problemas críticos:

### Hallazgos del Análisis

**1. Pantalla de Estadísticas (Tarjetas KPI)**
- Las 7 tarjetas KPI están distribuidas en 3 filas estáticas (3-2-1+vacío), lo cual se ve desordenado y poco profesional.
- La última fila tiene una tarjeta sola ("Liq. Recuperada") con un `Expanded(child: SizedBox())` vacío al lado, desperdiciando espacio.
- No hay dinamismo ni animación; la pantalla se siente estática.

**2. Pantalla de Proyecciones y Crecimiento**
- **BUG CRÍTICO:** Las interpolaciones de string del Simulador muestran el **código Dart literal** en la UI. En las líneas 286 y 305 de `predictive_analytics_screen.dart`, se usa `\${...}` en lugar de `${...}` (doble escape), lo cual imprime texto como `${_salesSimulationPct > 0 ? '+' : ''}${_salesSimulationPct.toInt()}%` directamente en pantalla.
- **BUG CRÍTICO:** Misma situación en la línea 344 con `\${currencyFmt.format(diffProfit.abs())} vs proy. base`.
- La gráfica "Evolución Patrimonial" solo tiene 2 puntos (inicio y final), lo cual es insuficiente para visualizar progresión.
- Los puntos de la gráfica no muestran datos al presionarlos; el tooltip no incluye la fecha.
- No hay detalle debajo de la gráfica al presionar un punto.

**3. Pantalla "Motor Inteligente de..."**
- El título `"Motor Inteligente de Abastecimiento"` se corta con "..." por falta de espacio responsivo.
- El botón de descarga del AppBar muestra un SnackBar con "En desarrollo..." en lugar de funcionar.
- **BUG:** En la línea 325, `Share.shareXFiles` usa `\\$` (doble escape), lo cual imprime texto literal en vez del valor.
- **BUG:** En la línea 328, mismo problema con `\\$e`.

**4. Pantalla "Historial de Trazabilidad"**
- La pantalla es demasiado simple: solo muestra "Operación: INVENTARIO_INICIAL" y "Cantidad: 2".
- No hay contexto de precios, stock resultante, ni notas.
- No tiene iconos diferenciados claros ni un resumen del producto.
- No hay estadísticas rápidas (total entradas, salidas, etc.).
- La funcionalidad no es clara para el usuario.

**5. Documento PDF de Orden de Compra**
- Le falta: marca del producto, velocidad de venta, ROP, motivo de la sugerencia.
- No tiene resumen ejecutivo ni notas al pie para el usuario.

---

## Fases de Implementación

---

### Fase 1: Carrusel Animado de Tarjetas KPI

**Problema:** Las tarjetas están en filas estáticas con una fila huérfana. Se ven desordenadas y la pantalla se siente muerta.

#### [MODIFY] [kpi_summary_row.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/dashboard/kpi_summary_row.dart)

**Transformación completa del widget a `StatefulWidget` con animación:**

1. **Convertir a `StatefulWidget`** para poder manejar el `Timer` y `PageController`.

2. **Estructura visual - "Carrusel Destacado":**
   - Mostrar todas las 7 tarjetas en una sola vista.
   - La tarjeta **central/destacada** tendrá un tamaño 1.3x mayor con una sombra `glow` azulada y un borde animado.
   - Las tarjetas restantes (no destacadas) se muestran en 2 filas de 3 debajo, con tamaño estándar.
   - Cada **5 segundos**, la tarjeta destacada rota automáticamente al siguiente KPI con una animación `AnimatedSwitcher` (fade + slide).

3. **Datos de cada tarjeta:**
   | KPI | Valor | Ícono | Color |
   |-----|-------|-------|-------|
   | Ventas | `data.totalTransactions` | `receipt_long` | Blue |
   | Crecimiento | `salesGrowthRate%` | `trending_up/down` | Green/Red |
   | Rotación | `inventoryTurnoverRatio` | `autorenew` | Orange |
   | Valor Stock | `inventoryValue` | `inventory_2` | Purple |
   | Inmovilizado | `immobilizedCapital` | `lock_outline` | Red |
   | Liq. Recuperada | `recoveredLiquidity` | `water_drop` | LightBlue |
   | Ticket Promedio | `averageTicket` | `confirmation_number` | Teal |

4. **Animación del destaque:**
   - `Timer.periodic` de 5 segundos que incrementa `_highlightedIndex`.
   - `AnimatedSwitcher` con `SlideTransition` para la tarjeta central.
   - Las tarjetas no destacadas se reorganizan en la cuadrícula inferior con `AnimatedOpacity`.
   - Al tocar cualquier tarjeta no destacada, se vuelve la destacada (resetea el timer).

5. **Dispose:** Cancelar el `Timer` en `dispose()`.

---

### Fase 2: Fix Bugs Críticos del Simulador (Proyecciones)

**Problema:** El texto del simulador muestra código Dart literal en pantalla por doble escape.

#### [MODIFY] [predictive_analytics_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/screens/predictive_analytics_screen.dart)

**Correcciones puntuales:**

1. **Línea 286** - Fix slider de ventas:
   ```dart
   // ANTES (BUG):
   Text("\${_salesSimulationPct > 0 ? '+' : ''}\${_salesSimulationPct.toInt()}%", ...)
   // DESPUÉS:
   Text("${_salesSimulationPct > 0 ? '+' : ''}${_salesSimulationPct.toInt()}%", ...)
   ```

2. **Línea 305** - Fix slider de costos:
   ```dart
   // ANTES (BUG):
   Text("\${_costsSimulationPct > 0 ? '+' : ''}\${_costsSimulationPct.toInt()}%", ...)
   // DESPUÉS:
   Text("${_costsSimulationPct > 0 ? '+' : ''}${_costsSimulationPct.toInt()}%", ...)
   ```

3. **Línea 344** - Fix beneficio neto simulado vs base:
   ```dart
   // ANTES (BUG):
   "\${currencyFmt.format(diffProfit.abs())} vs proy. base"
   // DESPUÉS:
   "${currencyFmt.format(diffProfit.abs())} vs proy. base"
   ```

4. **Línea 79** - Fix error message:
   ```dart
   // ANTES (BUG):
   Text("Ocurrió un error: \$_error", ...)
   // DESPUÉS:
   Text("Ocurrió un error: $_error", ...)
   ```

---

### Fase 3: Mejora de la Gráfica "Evolución Patrimonial"

**Problema:** Solo muestra 2 puntos, no se puede ver la progresión real, y no hay feedback al presionar puntos.

#### [MODIFY] [predictive_analytics_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/screens/predictive_analytics_screen.dart)

**Cambios en `_buildPatrimonyChart`:**

1. **Mostrar TODOS los puntos disponibles** (actualmente ya lo hace si hay datos, pero hay que asegurar que `_data!.historicalPoints` contenga datos diarios reales).

2. **Mostrar puntos visibles en la gráfica** (`FlDotData(show: true)`) con tamaño reducido (radius 3) para que se vea cada día.

3. **Reglas adaptativas según cantidad de datos:**

   | Puntos disponibles | Intervalo de labels en eje X | Tamaño de punto |
   |----|----|----|
   | ≤ 7 (1 semana) | Cada 1 (todos) | 5px |
   | 8–30 (1 mes) | Cada 5 | 3px |
   | 31–90 (3 meses) | Cada 15 | 2px |
   | 91–180 (6 meses) | Cada 30 | 2px, `show: false` excepto min/max |
   | 180+ | Cada 60 | `show: false` excepto min/max |

4. **Resaltar automáticamente el punto MÁS ALTO y MÁS BAJO:**
   - Calcular `minIndex` y `maxIndex`.
   - Usar `FlDotData` con `checkToShowDot` para dibujar esos 2 puntos con un radio mayor (6px) y colores diferenciados (verde para máximo, rojo para mínimo).
   - Mostrar la etiqueta del valor y fecha directamente en la gráfica junto a esos puntos con `ExtraLinesData` o con widgets superpuestos.

5. **Mejora del Tooltip al presionar:**
   - Subir la posición del tooltip con `tooltipMargin: 20` para que no quede debajo del dedo.
   - Incluir la **fecha** además del valor en el tooltip.
   - Formato: `"12/08 — S/ 1,234.56"`.

6. **Panel descriptivo debajo de la gráfica:**
   - Añadir un `_selectedPatrimonyPoint` en el state.
   - Al tocar un punto, actualizar `_selectedPatrimonyPoint` con `setState`.
   - Debajo de la gráfica, mostrar un `AnimatedSwitcher` con un `Container` que diga:
     ```
     📅 12 de Agosto, 2026
     💰 Patrimonio: S/ 4,523.45
     📊 Ventas del día: S/ 150.00
     ```
   - Si no se ha presionado nada, mostrar el resumen del punto más reciente.

---

### Fase 4: Mejora de la Gráfica "Evolución de Ventas" (monthly_sales_chart.dart)

**Problema:** Solo muestra un punto por mes, lo cual es muy pobre en detalle. El usuario quiere granularidad diaria/semanal según el plazo seleccionado.

#### [MODIFY] [analytics_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/providers/analytics_provider.dart)

1. **Nuevo campo en `AnalyticsData`:** Añadir `List<Map<String, dynamic>> dailySalesData` que contenga las ventas agrupadas por día:
   ```dart
   final List<Map<String, dynamic>> dailySalesData; // [{date: '2026-08-01', amount: 150.0}, ...]
   ```

2. **Poblar `dailySalesData`** en `runStaggeredAnalysis()`:
   - Agrupar las ventas filtradas por día (`DateFormat('yyyy-MM-dd')`).
   - Incluir días sin ventas con `amount: 0` para continuidad de la gráfica.

#### [MODIFY] [monthly_sales_chart.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/charts/monthly_sales_chart.dart)

**Transformación completa a `StatefulWidget` con granularidad adaptativa:**

3. **Recibir ambos datasets** (`monthlySales` y `dailySalesData`) y el `selectedPeriod`.

4. **Reglas de agrupación según periodo seleccionado:**

   | Periodo | Agrupación | Formato label |
   |---------|-----------|---------------|
   | Hoy | Por hora (si hay data) | `"10h", "14h"` |
   | 7 Días | Por día | `"Lun", "Mar"` |
   | 30 Días | Por día | `"01", "05", "10"...` |
   | 6 Meses | Por semana | `"S1 Jun", "S2 Jun"` |
   | 1 Año | Por mes | `"Ene", "Feb"` |
   | Todo | Por mes | `"Ene", "Feb"` |

5. **Mostrar puntos visibles** con `FlDotData(show: true)`, radio 4px.

6. **Resaltar punto más alto y más bajo** con colores diferenciados (igual que Fase 3).

7. **Tooltip mejorado:**
   - Subir posición con `tooltipMargin: 20`.
   - Formato: `"Lun 11/08\nS/ 350.00\n+15.2% vs anterior"`.

8. **Panel descriptivo debajo:**
   - `_selectedSalesPoint` en state.
   - Al tocar, mostrar debajo:
     ```
     📅 Lunes, 11 de Agosto 2026
     💰 Ventas: S/ 350.00
     📈 Crecimiento: +15.2% vs día anterior
     ```

---

### Fase 5: Fix del Título del Motor Inteligente + Fix Bugs

**Problema:** El título se corta con "..." y los botones del AppBar no funcionan.

#### [MODIFY] [smart_restock_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/screens/smart_restock_screen.dart)

1. **Título responsivo** (línea 136):
   ```dart
   // ANTES:
   title: const Text('Motor Inteligente de Abastecimiento', style: TextStyle(fontSize: 18)),
   // DESPUÉS:
   title: const FittedBox(
     fit: BoxFit.scaleDown,
     child: Text('Motor Inteligente de Reabastecimiento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
   ),
   ```

2. **Fix botón "Exportar OC"** — conectar al generador real (líneas 140-148):
   ```dart
   // ANTES: muestra SnackBar "En desarrollo..."
   // DESPUÉS: Llamar directamente al PurchaseOrderGenerator
   onPressed: () async {
     final auth = Provider.of<AuthProvider>(context, listen: false);
     // ... lógica idéntica al botón inferior
   },
   ```

3. **Fix doble escape en Share** (línea 325):
   ```dart
   // ANTES (BUG): '\\${auth.businessName}'
   // DESPUÉS: '${auth.businessName}'
   ```

4. **Fix doble escape en SnackBar** (línea 328):
   ```dart
   // ANTES (BUG): '\\$e'
   // DESPUÉS: '$e'
   ```

---

### Fase 6: Mejora del Historial de Trazabilidad

**Problema:** La pantalla es estática, poco informativa y su función no es clara para el usuario.

#### [MODIFY] [audit_trail_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/screens/audit_trail_screen.dart)

**Rediseño completo de la pantalla:**

1. **Encabezado con resumen del producto:**
   - Mostrar un `Card` superior con:
     - Nombre completo del producto.
     - Stock actual (consultado en tiempo real desde la DB).
     - **Mini-estadísticas**: Total de entradas, total de salidas, días desde la última venta.

2. **Mejorar la visualización de cada evento de la timeline:**
   - **VENTA:** Ícono de carrito azul. Mostrar: `"Venta de X unidades"`, precio de venta unitario, y stock resultante (si se puede calcular).
   - **INVENTARIO_INICIAL:** Ícono de bandera verde. Mostrar: `"Carga inicial de X unidades"`, costo unitario.
   - **AJUSTE_STOCK:** Ícono de edición naranja. Mostrar: `"Ajuste manual: +/- X unidades"`.
   - **Cambio de Metadata:** Ícono de tuerca púrpura. Mostrar: `"Se modificó [campo]: de [valor_anterior] a [valor_nuevo]"`.
   - Cada tarjeta del timeline tendrá un fondo sutil coloreado según el tipo.

3. **Título y descripción de la pantalla:**
   - Cambiar título a `"Historial del Producto"`.
   - Añadir subtítulo descriptivo: `"Registro completo de movimientos de stock y cambios del producto."`.

4. **Empty state mejorado:**
   - Si no hay registros: Ícono grande + texto explicativo: `"No se han registrado movimientos para este producto aún. Los movimientos se registrarán automáticamente con cada venta, ajuste de stock o edición."`.

---

### Fase 7: Mejora del PDF de Orden de Compra

**Problema:** El documento es muy básico y no aporta contexto suficiente para que el usuario lo use con su proveedor.

#### [MODIFY] [purchase_order_generator.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/services/purchase_order_generator.dart)

1. **Añadir columnas a la tabla:**

   | Producto | Marca | Stock | Velocidad | ROP | Sugerido | Costo Unit. | Total |
   |----------|-------|-------|-----------|-----|----------|-------------|-------|

2. **Resumen ejecutivo antes de la tabla:**
   ```
   📊 Resumen Ejecutivo
   • Productos en alerta: X
   • Productos críticos (stock = 0): Y
   • Inversión total sugerida: S/ Z,ZZZ.ZZ
   • Este reporte fue generado por el Motor Inteligente de Reabastecimiento
     basado en el análisis de velocidad de ventas y punto de reorden (ROP).
   ```

3. **Notas al pie del documento:**
   ```
   Notas:
   • ROP = Punto de Reorden: nivel de stock en el cual se debe hacer un nuevo pedido.
   • Velocidad: promedio de unidades vendidas por día en los últimos 30 días.
   • Los costos unitarios se basan en el último precio de compra registrado.
   • Este documento es una sugerencia automática. Ajuste las cantidades según
     su criterio y acuerdos con proveedores.
   ```

4. **Fix bug de doble escape** en `grandTotal` (que se acumula incorrectamente dentro de `build` del page, causando duplicación en multi-page).

---

### Fase 8: Fix de bugs en predictive_service.dart

#### [MODIFY] [predictive_service.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/services/predictive_service.dart)

1. **Línea 138** - Fix doble escape:
   ```dart
   // ANTES: debugPrint("Error in generatePrediction: \\$e");
   // DESPUÉS: debugPrint("Error in generatePrediction: $e");
   ```

2. **Enriquecer los `historicalPoints`** para que incluyan `dailySales` además de `patrimony` (ya lo hace, pero verificar que el cálculo no de 0 erróneamente en el primer punto).

---

## Orden de Ejecución

| # | Fase | Prioridad | Archivos |
|---|------|-----------|----------|
| 1 | Carrusel KPI | 🟡 Media | `kpi_summary_row.dart` |
| 2 | Fix Bugs Simulador | 🔴 Crítica | `predictive_analytics_screen.dart` |
| 3 | Gráfica Evolución Patrimonial | 🔴 Alta | `predictive_analytics_screen.dart` |
| 4 | Gráfica Evolución Ventas | 🔴 Alta | `analytics_provider.dart`, `monthly_sales_chart.dart` |
| 5 | Fix Motor Inteligente | 🔴 Crítica | `smart_restock_screen.dart` |
| 6 | Historial de Trazabilidad | 🟡 Media | `audit_trail_screen.dart` |
| 7 | PDF Orden de Compra | 🟢 Normal | `purchase_order_generator.dart` |
| 8 | Fix predictive_service | 🔴 Crítica | `predictive_service.dart` |

---

## Verification Plan

### Pruebas Manuales
1. Abrir "Inteligencia de Negocio" → Las 7 tarjetas KPI deben mostrarse con una destacada que rota cada 5 segundos con animación suave.
2. Abrir "Proyecciones y Crecimiento" → El Simulador debe mostrar los porcentajes correctamente (sin código Dart visible). Los sliders deben actualizar el "Beneficio Neto Simulado" en tiempo real.
3. La gráfica "Evolución Patrimonial" debe mostrar un punto por cada día con los puntos más alto y más bajo resaltados visualmente. Al presionar un punto, se debe ver un panel debajo con los datos detallados.
4. La gráfica "Evolución de Ventas" debe adaptarse al periodo seleccionado (puntos diarios para 7/30 días, semanales para 6 meses, mensuales para 1 año).
5. El título "Motor Inteligente de Reabastecimiento" debe verse completo sin cortarse.
6. El botón de descarga del AppBar y el botón "Exportar OC" inferior deben generar y compartir el PDF correctamente.
7. La pantalla "Historial del Producto" debe mostrar el encabezado con estadísticas y cada evento con formato visual diferenciado.
8. El PDF de Orden de Compra debe contener el resumen ejecutivo, columnas adicionales (marca, velocidad, ROP) y notas explicativas al pie.
