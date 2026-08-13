# Tareas: Mejora del Módulo de Estadísticas, Proyecciones y Motor Inteligente

- `[x]` **Fase 1: Carrusel Animado de Tarjetas KPI**
  - `[x]` Convertir `KpiSummaryRow` a `StatefulWidget`
  - `[x]` Implementar lógica de rotación de 5 segundos con `Timer`
  - `[x]` Rediseñar layout: Tarjeta central grande + grid de tarjetas secundarias
  - `[x]` Añadir animaciones `AnimatedSwitcher` y sombras dinámicas

- `[x]` **Fase 2: Fix Bugs Críticos del Simulador**
  - `[x]` Corregir escapes dobles en sliders de `predictive_analytics_screen.dart`
  - `[x]` Corregir escape doble en texto de beneficio neto simulado
  - `[x]` Corregir error message

- `[x]` **Fase 3: Mejora de Gráfica Evolución Patrimonial**
  - `[x]` Mostrar todos los puntos disponibles en gráfica
  - `[x]` Resaltar punto más alto (verde) y más bajo (rojo)
  - `[x]` Mejorar tooltip (posición, mostrar fecha)
  - `[x]` Implementar panel descriptivo dinámico debajo de gráfica al tocar

- `[x]` **Fase 4: Mejora de Gráfica Evolución de Ventas**
  - `[x]` Añadir `dailySalesData` a `AnalyticsData`
  - `[x]` Refactorizar `MonthlySalesChart` a `StatefulWidget`
  - `[x]` Implementar lógica adaptativa (agrupar por horas, días, semanas, meses según periodo)
  - `[x]` Mejorar tooltips y panel descriptivo dinámico al tocar

- `[x]` **Fase 5: Solucionar Title Cut en Motor Inteligente**
  - `[x]` Reemplazar/Ajustar AppBar title en `smart_restock_screen.dart` para ser responsivo
  - `[x]` Usar `FittedBox` o `maxLines: 2` para evitar overflow
  - `[x]` Conectar botón AppBar "Exportar OC" con lógica real
  - `[x]` Corregir escapes dobles en `smart_restock_screen.dart` (SnackBar y Share)

- `[x]` **Fase 6: Mejora del Historial de Trazabilidad**
  - `[x]` Añadir Card de resumen superior (stock actual, mini-estadísticas)
  - `[x]` Mejorar iconos y colores para tipos de eventos (VENTA, INVENTARIO_INICIAL, etc.)
  - `[x]` Cambiar textos y descripciones para mayor claridad

- `[x]` **Fase 7: Mejora del PDF de Orden de Compra**
  - `[x]` Añadir columnas (Marca, Velocidad, ROP)
  - `[x]` Incluir Resumen Ejecutivo y Notas al pie
  - `[x]` Corregir bug de suma de totales duplicada (`grandTotal`)

- `[x]` **Fase 8: Revisión Final y QA**
  - `[x]` Búsqueda global de bugs residuales (ej. `\$`)
  - `[x]` Limpiar código y refactorizar si es necesario
