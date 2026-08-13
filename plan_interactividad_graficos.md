# 📊 Plan de Interactividad y UI: Ecosistema Completo de Estadísticas

## 1. Análisis del Componente Base y Arquitectura Interactiva
El patrón de oro de interactividad lo extraemos del Gráfico de Ventas Mensuales (`MonthlySalesChart`). El objetivo es que **ningún** gráfico o tarjeta quede como un bloque de información estático y sin contexto. Toda la Ventana de Estadísticas será "reaccionaria" al tacto del usuario, proporcionando insights (Explainable BI) y contexto matemático (tablas de origen).

**Patrón de Arquitectura:**
1. **Transición a Stateful:** Conversión de componentes `Stateless` a `Stateful`.
2. **Listenes Táctiles / Gestures:** Uso de `pieTouchData`, `barTouchData` o `InkWell` para capturar la interacción.
3. **Renderizado Condicional de Apoyo:**
   - **Para Gráficos:** Desplegar dinámicamente un contenedor `AnimatedSwitcher` en la parte inferior explicando el segmento tocado.
   - **Para Tarjetas / KPIs:** Expandir la tarjeta o usar modales/bottom sheets para revelar la tabla estadística (Data Table) o el desglose detrás del número.

---

## 2. Mapeo de Componentes a Intervenir (Expansión Total)

A los gráficos previamente identificados, sumamos las métricas clave y de riesgo:

**A. Gráficos Centrales (FlChart)**
1.  📉 **`origin_pie_chart.dart`:** Detalle explicativo de la plataforma de origen al tocar el pastel.
2.  📉 **`payment_method_chart.dart`:** Detalle y monto exacto al tocar el método de pago.
3.  📊 **`sales_by_day_chart.dart`:** Panel inferior que explica el desempeño del día frente al promedio.
4.  📊 **`top_products_chart.dart`:** Detalle de ganancia y rotación del producto al tocar su barra.

**B. Tarjetas de Rentabilidad y Clientes**
5.  🏆 **`top_categories_card.dart`:** Al tocar la categoría, se mostrará un desglose de por qué es la más rentable.
6.  👥 **`top_clients_card.dart`:** Al interactuar, se revelará un miniresumen del hábito de compra del cliente.

**C. Métricas Claves y Riesgo (Nuevos Requerimientos)**
7.  💰 **`financial_summary_card.dart` (Métricas Clave):** Modificación profunda. Al interactuar con el Resumen Financiero, se abrirá o expandirá una **Tabla Estadística** que desglosará de dónde salieron los números (Ingresos vs Egresos vs Costos Operativos).
8.  ⚠️ **`restock_alerts_card.dart` / Quiebre de Stock:** Al tocar las alertas, se explicará matemáticamente la fecha de agotamiento proyectada para los productos críticos.

---

## 3. Plan de Trabajo Detallado (Ejecución Inmediata)

**Fase 1: Refactorización de Gráficos de Proporción (PieCharts)**
- Convertir `OriginPieChart` y `PaymentMethodChart` a `StatefulWidget`. Inyectar eventos táctiles y renderizar el panel informativo explicativo.

**Fase 2: Refactorización de Gráficos de Tendencia (BarCharts)**
- Convertir `SalesByDayChart` y `TopProductsChart` a `StatefulWidget`. Capturar eventos táctiles y desplegar el panel comparativo debajo.

**Fase 3: Estandarización de Tarjetas y KPIs (Deep Dive)**
- Modificar `top_categories_card.dart` y `top_clients_card.dart` con un sistema expansible (ej. `ExpansionTile` o `AnimatedCrossFade`) para mostrar información extendida.
- Refactorizar `FinancialSummaryCard` para incorporar una vista de "Detalle Analítico" mediante un modal inferior que contenga una tabla estructurada.
- Enriquecer la tarjeta de "Quiebre de Stock" explicando el cálculo predictivo.

**Fase 4: Validación y Estabilización**
- Ejecutar `flutter analyze` para asegurar 0 fallos de compilación tras la masiva refactorización estructural.
- Presentar el `walkthrough.md` con los resultados.

*Procediendo a la ejecución de la Fase 1 según instrucción explícita.*
