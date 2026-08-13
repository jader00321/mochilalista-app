# 📈 Plan de Rediseño: Proyecciones, Crecimiento y Explainable BI

## 1. Auditoría de UX/UI y Dinamismo de Gráficos

### 📌 El Problema Visual Actual
Los gráficos en la "Ventana de Proyecciones" son planos, carecen de interactividad fluida y muestran una única línea de "Patrimonio" que mezcla ganancias e inventario de forma confusa. El usuario ve una curva subir o bajar, pero no comprende **por qué** (¿compré mucho stock o vendí mucho?). El simulador también ocupa mucho espacio visual sin aportar insights claros.

### 🛠️ Propuesta de Mejora (UX/UI)
1.  **Desglose Visual Inteligente (FlChart Avanzado):** 
    En lugar de una sola línea abstracta, usaré un **Gráfico de Áreas Apiladas (Stacked Area Chart)** o dos curvas de contraste que separen claramente: 
    *   🔵 *Valor del Inventario (Activos)*
    *   🟢 *Beneficios Netos (Liquidez)*
    Esto permitirá al usuario ver de un vistazo si su patrimonio crece porque tiene mercadería inmovilizada o porque realmente está generando caja.
2.  **Animaciones Fluidas:** Implementaré `TweenAnimationBuilder` para que los números proyectados suban con una animación de conteo desde 0, y transiciones animadas en la carga del gráfico de `fl_chart`.
3.  **Tarjetas de Contexto:** El detalle al tocar el gráfico mostrará comparativas directas (Ej: "+5% vs día anterior").

---

## 2. Mejora del Sistema Predictivo (Explainable BI)

### 📌 El Problema de la Predicción Actual
La lógica actual utiliza una Regresión Lineal Simple sobre las ventas *diarias*. Esta técnica es matemáticamente inestable en retail pequeño: si el usuario tuvo un día de ventas enorme (un "outlier" o pico aislado por un evento), la regresión lineal se dispara, arrojando una proyección mensual exagerada y falsa. Además, el usuario solo recibe un número frío sin justificación.

### 🛠️ Nueva Lógica (Suavizado Matemático)
Reemplazaré la regresión cruda por un modelo de **Promedios Móviles Ponderados (WMA)** de 7 días. Esto suaviza los picos irregulares (ej. ventas fuertes de fines de semana) y le da más peso estadístico a los datos recientes, resultando en una predicción muchísimo más realista y confiable.

### 💡 Explainable BI (Explicabilidad)
Incorporaré una tarjeta obligatoria debajo de la proyección llamada: **"🤖 ¿Cómo calculamos esto?"**.
El modelo de datos devolverá variables estructuradas para armar narrativas en lenguaje natural.

*   **Texto de Ejemplo (Origen del Dato):**
    > *"El sistema ha suavizado los picos inusuales de tus ventas y ha analizado tu tendencia. Tu ritmo de ventas creció un **14%** en la última quincena impulsado por los cierres semanales. Basándonos en esta aceleración, proyectamos tu próximo mes de forma conservadora."*
*   **Texto de Ejemplo (Acción Recomendada):**
    > *"**Acción recomendada:** Tienes una proyección alcista. Revisa tu Motor de Abastecimiento hoy mismo para garantizar que tus productos estrella no sufran quiebre de stock en los próximos 15 días."*

---

## 3. Plan de Trabajo Detallado (Mapa de Acción)

A continuación, los pasos exactos de codificación. No se modificará código hasta tu aprobación.

### Paso 1: Reingeniería del Algoritmo Predictivo (`predictive_service.dart`)
- [ ] Implementar un algoritmo de suavizado (Promedio Móvil Ponderado de 7 días) sobre el historial para limpiar "outliers" (picos anormales).
- [ ] Generar la Regresión Lineal sobre los datos *suavizados* para la predicción a 30 días.
- [ ] Ampliar el modelo `PredictiveData` para incluir campos de "Explicabilidad" (`explanation_text`, `action_text`).

### Paso 2: Rediseño Visual de la UI (`predictive_analytics_screen.dart`)
- [ ] Reestructurar la pantalla para destacar el número predictivo con animaciones (`TweenAnimationBuilder`).
- [ ] Reemplazar el gráfico patrimonial simple por un **Gráfico de Áreas Apiladas (Stacked Area)** separando 'Beneficio' e 'Inventario'.
- [ ] Mejorar la interacción táctil (TouchTooltips) del gráfico para mostrar valores desglosados hermosos.

### Paso 3: Integración del Panel "Explainable BI"
- [ ] Construir la nueva tarjeta UI **"🤖 ¿Cómo calculamos esto?"**.
- [ ] Conectar la tarjeta con los nuevos textos generados por el motor predictivo.
- [ ] Ocultar el "Simulador de Escenarios" en un modal deslizable (BottomSheet) u optimizar su espacio para no abrumar la lectura principal de la proyección.

> [!IMPORTANT]
> **Aprobación Requerida:** ¿Estás de acuerdo con el cambio de Regresión Lineal a Promedios Móviles Suavizados para evitar proyecciones falsas por picos de venta? Y ¿Te agrada el enfoque de la Tarjeta de Explicabilidad para el usuario? En cuanto apruebes, procedo a codificar.
