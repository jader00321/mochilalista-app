# 🧠 Plan de Arquitectura: Motor de Trazabilidad Histórica y Business Intelligence Avanzado

He analizado a profundidad tu solicitud, las capturas de pantalla, los planes anteriores (`12_PLAN_ESTADISTICAS_AVANZADAS.md` y `plan_correccion_ventas.md`) y el código actual (`analytics_provider.dart`, `inventory_intelligence_service.dart`, `analytics_dashboard_screen.dart` y `smart_restock_screen.dart`).

Actualmente **ya existe una base fundamental en el código** (tablas `stock_ledger` y `product_history`, y un motor inicial de ROP). Sin embargo, tienes toda la razón: **hay fallas estructurales de origen** (como la omisión de intereses en los registros, lo que corrompe la data financiera) y la interfaz gráfica, aunque útil, es muy plana y difícil de acceder para el usuario, careciendo del impacto visual de una app empresarial premium.

A continuación, presento mi propuesta arquitectónica integral como Experto en BI e Ingeniero de Datos, diseñada específicamente para funcionar rápido y sin congelamientos en SQLite (local).

---

## 🏗️ 1. Arquitectura de Base de Datos (Data Engineering)

### El Problema Actual (Corrupción de Datos)
El `plan_correccion_ventas.md` señala una herida mortal: el sistema de ventas rápidas NO está guardando el recargo por interés en SQLite (`monto_total`), pero en el provider de Analytics se intenta "parchar" esto re-calculando el interés en tiempo real (`if (estadoPago == 'pendiente' && interes > 0)...`). Esto rompe el principio fundamental de BI: **La base de datos debe almacenar la verdad inmutable (Single Source of Truth).**

### Propuesta Arquitectónica
No romperemos la base actual, la **evolucionaremos**:

1.  **Corrección Transaccional (Inmediata):** Arreglaremos `sales_service.dart` y `checkout_action_footer.dart` para que `monto_total` guarde el valor final **real** (incluyendo intereses) y el `stock_ledger` almacene exactamente a cuánto se vendió. Así, Analytics solo hará un `SUM()` directo, volviéndose 100x más rápido.
2.  **Optimización del `stock_ledger` (Audit Trail):**
    *   Actualmente tienes índices en `presentation_id` y `negocio_id`. Añadiremos índices compuestos (`negocio_id, tipo_transaccion, fecha_registro`) para que las consultas de "ventas del mes" respondan en milisegundos incluso con 50,000 registros.
3.  **Manejo de COGS (Costo de Mercancía Vendida):**
    *   En lugar de asumir un 30% fijo si falta el costo, implementaremos un sistema de **Costo Promedio Ponderado**. Cada vez que haya un `abastecimiento` en el `stock_ledger`, recalcularemos un `costo_historico_promedio` y lo estamparemos en la venta. Esto garantiza rentabilidad real sin complicar la base con algoritmos LIFO/FIFO extremos para SQLite.

---

## 📈 2. Lógica del Motor Predictivo y Optimización

Las fórmulas actuales en `inventory_intelligence_service.dart` son demasiado básicas (ej. `eoq = 30 * velocity`). Vamos a incorporar inteligencia real:

1.  **Ajuste por Estacionalidad y Tendencia:**
    *   No basta con ver el promedio de los últimos 30 días. El sistema comparará el ritmo de los últimos 7 días (Tendencia Corta) vs los últimos 30 días (Tendencia Larga). Si la tendencia corta es un 20% mayor, el "Velocity" subirá ponderadamente, previniendo quiebres de stock en picos de ventas.
2.  **Cálculo Avanzado del ROP (Reorder Point):**
    *   Fórmula mejorada: `ROP = (Velocity Diario Ajustado * Lead Time Promedio) + Safety Stock`.
    *   *Safety Stock* se ajustará usando la Desviación Estándar de las ventas diarias, no un cálculo lineal duro. Esto previene comprar de más si las ventas son erráticas.
3.  **Índice de Rotación (Inventory Turnover Ratio):**
    *   KPI Crítico: Calcularemos cuántas veces el negocio vende y reemplaza su inventario entero en un periodo. A mayor índice, el negocio es más líquido y exitoso.

---

## 💡 3. Propuestas de Mejora UI/UX y Accesibilidad (Valor Agregado)

### Problema de Accesibilidad
Actualmente, el sistema está "escondido". El usuario no sabe de dónde abrir el *Dashboard Analítico* ni el *Motor Inteligente de Abastecimiento* (Smart Restock).
*   **Solución:** Crearemos una **Sección Central de Inteligencia (BI Hub)** en el menú principal (Home/Drawer). Además, colocaremos botones de alerta directos (Notificaciones de Quiebre) en la pantalla de inventario que te envíen de un toque al Asistente de Compras.

### Mejoras Visuales (Gráficos)
Analizando tus capturas, los gráficos actuales de `fl_chart` están muy "planos".
*   **Tendencia de Ventas (6 Meses):** La línea actual es simple. La cambiaremos por un gráfico de área suavizada (Spline Area Chart) con un gradiente semitransparente debajo, etiquetas en los nodos al tocar, e indicando el porcentaje de crecimiento respecto al mes anterior directo en el nodo.
*   **Ventas por Día:** En lugar de barras verdes básicas, usaremos barras con bordes redondeados (Radius), variando el color (heatmap) según el volumen de ventas, con tooltips interactivos que muestran el monto exacto en Soles al mantener presionado.
*   **Dashboard de Asistente de Compras:** Incorporaremos badges visuales más fuertes y filtros para ordenar ("Más críticos primero", "Mayor inversión").

---

## 🗺️ 4. Roadmap de Ejecución por Fases

*   **Fase 1: Estabilización de Datos y Corrección de Caja (Data Engineering)**
    *   Corregir el flujo de guardado de ventas (intereses, descuentos) en el POS y el modal de checkout para reflejar totales exactos.
    *   Crear los índices de alto rendimiento en las tablas `stock_ledger` y `ventas`.
*   **Fase 2: Motor de Trazabilidad y Costo Promedio (Audit Trail)**
    *   Ajustar el provider de Analytics para que lea datos limpios usando solo SQL nativo agrupado.
    *   Implementar el cálculo de Costo Promedio en cada movimiento de stock en el Ledger.
*   **Fase 3: Inteligencia Predictiva (BI Engine)**
    *   Reescribir el cálculo de ROP en `InventoryIntelligenceService` con ajuste de tendencia y desviación estándar.
    *   Generar los nuevos KPIs (Turnover Ratio, Costo Estancado Real).
*   **Fase 4: Transformación Visual (Dashboards y Accesibilidad)**
    *   Crear los nuevos gráficos dinámicos con tooltips interactivos.
    *   Integrar botones de acceso rápido y directo desde el Home para que el cliente use el sistema sin perderse.
