# Transformación Completa del Dashboard de Inteligencia de Negocio v2

## Contexto
El dashboard actual funciona pero tiene problemas de UX/UI, botones sin funcionalidad, gráficos planos sin interactividad, y un sistema de trazabilidad demasiado pesado. Esta transformación lo convierte en una herramienta de análisis profesional e intuitiva.

---

## Open Questions

> [!IMPORTANT]
> **Sobre el "Asistente de Compras" (FAB):** El usuario no comprende su utilidad porque la app es offline y no hay forma de comprar a proveedores desde ella. Mi propuesta es **renombrarlo a "Alertas de Reabastecimiento"** y que simplemente lleve a la pantalla `SmartRestockScreen` con la lista de productos que están por debajo del punto de reorden. Esto sí aporta valor real: le dice al dueño QUÉ comprar y CUÁNTO, aunque la compra la haga por fuera. ¿Estás de acuerdo?

> [!IMPORTANT]
> **Sobre el sistema de trazabilidad:** Tu intuición es correcta: rastrear cada micro-cambio en cada producto genera mucho ruido y consume recursos innecesariamente. Mi propuesta alternativa es un **sistema de "Snapshots de Rendimiento"**: en lugar de registrar cada cambio individual, el sistema tomará una "foto" del estado del negocio cada vez que el usuario genere un reporte de estadísticas (o mensualmente de forma automática). Esto guarda precio promedio, costo promedio, stock total, ventas del periodo y margen, todo en una sola tabla ligera (`business_snapshots`). Con esta tabla, puedes graficar cómo evolucionó el negocio mes a mes sin el peso de millones de registros individuales. El `product_history` y `stock_ledger` existentes ya cubren los casos puntuales de auditoría cuando se necesiten. ¿Te parece esta alternativa?

---

## Proposed Changes

### Fase 1: Balance Total Interactivo
> El card principal de "Balance Total" ahora será tappeable y abrirá un BottomSheet con desglose financiero completo.

#### [MODIFY] [financial_summary_card.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/dashboard/financial_summary_card.dart)
- Añadir icono `info_outline` tappeable junto al título "Balance Total"
- Al presionar, abrir `_showFinancialBreakdown()` → un `showModalBottomSheet` con:
  - Desglose: Ventas Brutas, Costo de Mercancía (COGS), Ganancia Neta, Margen %
  - Mini gráfico de barras comparativo (Ingresos vs Costos vs Ganancia) usando `fl_chart`
  - Explicación en texto: "Estos datos se calculan de todas tus ventas registradas..."
  - Indicador visual de salud financiera (🟢 Saludable / 🟡 Atención / 🔴 Crítico)

---

### Fase 2: KPIs con Modales Explicativos
> Cada tarjeta KPI será tappeable y abrirá un modal con explicación detallada, mini-gráfico y consejos prácticos.

#### [MODIFY] [kpi_summary_row.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/dashboard/kpi_summary_row.dart)
- Envolver cada `GlassCard` KPI en un `InkWell` con `onTap`
- Crear método `_showKpiDetail(context, {title, value, icon, explanation, chart})`
- Contenido del modal para cada KPI:
  - **Ventas**: "Has realizado X ventas. Tu día más fuerte fue [día]. Comparado con el mes pasado, [subió/bajó] un X%."
  - **Crecimiento**: Mini gráfico sparkline de los últimos 6 meses. Explicación de la tendencia.
  - **Rotación**: "Un índice de X.XX significa que tu inventario se renueva X veces en el periodo. Lo ideal es >1.0"
  - **Valor Stock**: Desglose por categoría del valor del inventario
  - **Inmovilizado**: Lista de los productos muertos con sugerencia de acción

---

### Fase 3: Insights Mejorados con Datos Dinámicos
> Las tarjetas de "Novedades y Oportunidades" tendrán textos más inteligentes con datos reales y mejor animación de expansión.

#### [MODIFY] [analytics_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/providers/analytics_provider.dart)
- Mejorar los textos de `BusinessInsight` para incluir datos concretos:
  - "Riesgo de Quiebre" → Añadir "A tu velocidad de X.X und/día, te quedas sin stock en ~Y días"
  - "Capital Estancado" → Añadir el valor monetario: "S/ X,XXX.XX están inmovilizados..."
  - "Tendencia al Alza" → Añadir "Vendiste S/ X este mes vs S/ Y el mes pasado"
  - "Tu Mejor Día" → Añadir el monto: "Los [día] generan S/ X en promedio"
- Añadir nuevos insights:
  - "🏆 Cliente VIP": "Tu cliente [nombre] ha comprado S/ X. Considera un trato preferencial."
  - "📦 Categoría Estrella": "La categoría [nombre] genera el X% de tus ventas."

#### [MODIFY] [insights_carousel.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/insights_carousel.dart)
- Mejorar la animación de expansión (usar `AnimatedCrossFade` en lugar de solo `AnimatedSize`)
- Al expandirse, mostrar sección adicional "¿Qué puedo hacer?" con acción sugerida
- Añadir indicador de paginación (dots) debajo del carrusel
- Animación de entrada `SlideTransition` para cada card

---

### Fase 4: Sistema de Filtro Temporal Inteligente
> Un selector de periodo que afecta las gráficas que se benefician de filtro temporal, sin limitar los KPIs globales.

#### [MODIFY] [analytics_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/providers/analytics_provider.dart)
- Añadir `enum AnalyticsPeriod { today, week, month, sixMonths, year, allTime }`
- Añadir propiedad `_selectedPeriod` con getter/setter que dispare re-cálculo
- Los datos que **SÍ se filtran** por periodo: `monthlySales`, `salesByDayOfWeek`, `salesByOrigin`, `salesByPaymentMethod`, gráficos de tendencia
- Los datos que **NO se filtran** (siempre globales): `totalSales`, `netProfit`, `inventoryValue`, `deadStockList`, `topProducts`, `topClients`, `topCategories`, `insights`
- Esto se logra filtrando `ventasRows` según la fecha antes de los cálculos de gráficas

#### [MODIFY] [analytics_dashboard_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/screens/analytics_dashboard_screen.dart)
- Añadir un `SegmentedButton` o `ChoiceChip` horizontal debajo de los KPIs:
  `[Hoy] [Semana] [Mes] [6 Meses] [Año] [Todo]`
- Al cambiar, llamar `prov.changePeriod(period)` que re-ejecuta solo la parte de gráficas
- Indicar visualmente qué secciones están filtradas y cuáles son globales

---

### Fase 5: Gráficos Interactivos Avanzados
> Todos los gráficos tendrán tooltips mejorados, mejor diseño visual, y opción de drill-down.

#### [MODIFY] [monthly_sales_chart.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/charts/monthly_sales_chart.dart)
- Añadir doble línea: Ventas (azul) + Ganancia (verde) para dar contexto
- Mejorar grosor de línea (barWidth: 3 → 4), dots más grandes
- Tooltip mejorado: Mostrar "Ventas: S/ X | Ganancia: S/ Y | Margen: Z%"
- Título dinámico que refleje el periodo seleccionado

#### [MODIFY] [sales_by_day_chart.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/charts/sales_by_day_chart.dart)
- Tooltip mejorado: Mostrar "Lunes: S/ X (Y transacciones)"
- Resaltar el día actual con borde especial

#### [MODIFY] [origin_pie_chart.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/charts/origin_pie_chart.dart)
- Añadir valores en S/ en la leyenda lateral
- Tooltip: Al tocar sector, mostrar nombre + monto + % exacto

#### [MODIFY] [payment_method_chart.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/charts/payment_method_chart.dart)
- Añadir conteo de transacciones por método en la leyenda

#### [MODIFY] [top_products_chart.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/charts/top_products_chart.dart)
- Animación de entrada progresiva para las barras de progreso

#### [MODIFY] [top_categories_card.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/dashboard/top_categories_card.dart)
- Añadir monto en S/ junto a las unidades
- Animar las barras de progreso con `TweenAnimationBuilder`

#### [MODIFY] [top_clients_card.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/dashboard/top_clients_card.dart)
- Añadir número de transacciones junto al monto
- Posición (#1, #2...) con medalla dorada/plata/bronce

---

### Fase 6: Correcciones Críticas de Bugs y UX

#### [MODIFY] [dead_stock_card.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/dashboard/dead_stock_card.dart)
- **FIX**: El botón "Ver X más..." no funciona → Convertir a `StatefulWidget`, al presionar expandir la lista completa con `AnimatedList`
- **FIX**: El botón "Crear Promoción de Liquidación" no funciona → Navegar a `OffersTab` de la feature de promociones
- Cambiar el `StatelessWidget` a `StatefulWidget` para manejar estado de expansión

#### [MODIFY] [analytics_dashboard_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/screens/analytics_dashboard_screen.dart)
- **FIX**: Renombrar FAB "Asistente de Compras" → "Alertas de Inventario" con icono `Icons.inventory` 
- Tooltip descriptivo: "Ver productos que necesitan reabastecimiento"

---

### Fase 7: Mejora de Exportaciones PDF y CSV

#### [MODIFY] [analytics_export_service.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/services/analytics_export_service.dart)
**PDF - Añadir secciones:**
- Sección "Análisis de Tendencia": Tabla con ventas mensuales + % de crecimiento mes a mes
- Sección "Composición de Ingresos": Tabla con métodos de pago y su participación %
- Sección "Análisis por Origen": Tabla con canales de venta
- Sección "Ventas por Día": Tabla con rendimiento por día de la semana
- Sección "Top Categorías": Tabla con categorías más vendidas
- Sección "Inventario Muerto": Lista de productos sin movimiento >90 días con valor inmovilizado
- Sección "Indicadores de Eficiencia": Rotación de inventario, Capital Inmovilizado, Margen
- Resumen ejecutivo al inicio: 3-4 frases que resuman el estado del negocio

**CSV - Añadir hojas:**
- Hoja "Métodos de Pago" con nombre, monto y %
- Hoja "Ventas por Origen" con canal, monto y %  
- Hoja "Top Categorías" con categoría y unidades
- Hoja "Inventario Muerto" con producto, stock y valor
- Hoja "Indicadores" con rotación, capital inmovilizado, margen

---

## Resumen de Archivos Afectados

| # | Archivo | Acción | Fase |
|---|---------|--------|------|
| 1 | `financial_summary_card.dart` | MODIFY | 1 |
| 2 | `kpi_summary_row.dart` | MODIFY | 2 |
| 3 | `analytics_provider.dart` | MODIFY | 3, 4 |
| 4 | `insights_carousel.dart` | MODIFY | 3 |
| 5 | `analytics_dashboard_screen.dart` | MODIFY | 4, 6 |
| 6 | `monthly_sales_chart.dart` | MODIFY | 5 |
| 7 | `sales_by_day_chart.dart` | MODIFY | 5 |
| 8 | `origin_pie_chart.dart` | MODIFY | 5 |
| 9 | `payment_method_chart.dart` | MODIFY | 5 |
| 10 | `top_products_chart.dart` | MODIFY | 5 |
| 11 | `top_categories_card.dart` | MODIFY | 5 |
| 12 | `top_clients_card.dart` | MODIFY | 5 |
| 13 | `dead_stock_card.dart` | MODIFY | 6 |
| 14 | `analytics_export_service.dart` | MODIFY | 7 |

---

## Verification Plan

### Compilación
```bash
flutter build apk --release
```

### Manual Verification
- Abrir dashboard → Verificar que el Balance Total sea tappeable y abra el modal
- Tocar cada KPI → Verificar que abra modal con explicación
- Tocar insights → Verificar expansión suave con datos enriquecidos
- Cambiar filtro temporal → Verificar que gráficas cambien, KPIs globales no
- Tocar puntos en gráficas → Verificar tooltips detallados
- Dead Stock → Verificar "Ver más" funciona, botón liquidación navega correctamente
- Exportar PDF → Verificar todas las secciones nuevas
- Exportar CSV → Verificar hojas adicionales
