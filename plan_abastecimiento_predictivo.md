# 🧠 Diagnóstico y Plan de Acción: Motor Predictivo de Abastecimiento

## 1. Diagnóstico de la Métrica de Velocidad (Velocidad = 0)

### 📌 El Problema Identificado
Tras analizar el motor actual (`InventoryIntelligenceService`), he detectado por qué la velocidad siempre arroja `0` (o valores tan cercanos a cero que la interfaz muestra `0.0/d`). 

**La causa matemática:** 
El sistema calcula la velocidad dividiendo el total de ventas entre un bloque fijo de días (`days = 30`), sin importar cuándo se creó el producto o cuándo fue su primera venta. 
Si un producto se registra hoy y vende 10 unidades, el algoritmo hace: `10 / 30 = 0.33`, subestimando brutalmente su rotación real. Además, al truncarse los decimales y multiplicarse por un ROP defectuoso, el valor predictivo colapsa y devuelve `0`. Al ser el ROP `0`, el sistema aplica una regla de rescate (fallback) estática de 2 unidades, ignorando por completo la rotación.

### 🛠️ La Solución Matemática (Velocidad Real Activa)
Corregiremos la fórmula para usar **Días Activos**. 
1. Determinaremos la fecha de la **primera venta** dentro de la ventana de análisis.
2. Calcularemos `dias_activos = MAX(1, dias_desde_primera_venta)`.
3. Nueva fórmula: `Velocidad = total_sold / dias_activos`.
Esto reflejará la verdadera demanda diaria del producto.

---

## 2. Lógica del Algoritmo Predictivo (Prevención de Quiebre Conservadora)

### 📌 El Paradigma Actual vs. El Nuevo Enfoque
Actualmente, esperar al límite base estático (que subiremos de `2` a `5` unidades) es una "Alerta Reactiva". El nuevo algoritmo será **Proactivo**.

### 🛠️ Regla de Negocio y Fórmula Predictiva
Para productos con stock > 5, aplicaremos la siguiente evaluación:

1. **Cálculo de Días para Quiebre de Stock (Stockout Days):**
   `Días para Agotar = Stock Actual / Velocidad Diaria Real`
   
2. **Cálculo Conservador del Punto de Quiebre (Fecha):**
   `Fecha de Quiebre = HOY + Días para Agotar`

3. **Condición de Disparo (Trigger Inteligente):**
   Solo sugeriremos la compra anticipada si los "Días para Agotar" son menores o iguales al **Lead Time (Días que demora el proveedor en entregar) + Safety Stock (Colchón de seguridad estadístico)**.
   Esto previene recomendar compras de productos que aún tienen 3 meses de vida útil (evitando sobrestock), enfocándose solo en aquellos que matemáticamente se acabarán antes de que el proveedor pueda reponerlos.

---

## 3. Plan de Trabajo Detallado (Mapa de Acción)

A continuación, detallo los pasos exactos de implementación técnica. No ejecutaré código hasta que des tu aprobación.

### Paso 1: Corregir Motor Analítico (`inventory_intelligence_service.dart`)
- Refactorizar `calculateSalesVelocity` para calcular `dias_activos` en lugar de usar un divisor estático.
- Actualizar el cálculo del `ROP` (Punto de Reorden) para que absorba correctamente la nueva velocidad.
- Añadir variables de salida al diccionario de retorno: `days_to_stockout` y `stockout_date`.

### Paso 2: Ampliar Límite Base y Actualizar Modelos (`smart_restock_screen.dart`)
- Aumentar el límite estático o "punto crítico base" a 5 unidades en el filtrado principal (`currentStock <= 5`).
- Actualizar el modelo `SmartRestockItem` para incluir `daysToStockout` y `stockoutDate`.
- Actualizar el filtrado para incluir la regla predictiva: `currentStock <= ROP` (esta regla ya existe, pero ahora será funcional).

### Paso 3: Rediseño Predictivo de la UI (Frontend)
- Modificar la tarjeta de cada producto en la lista (`_buildList` en `smart_restock_screen.dart`).
- Añadir una nueva insignia visual (Ej: "⚠️ Se agota en X días" o "📅 Agotamiento: 20/08").
- Separar visualmente las alertas por *Stock Crítico (Base)* de las alertas de *Prevención Predictiva*.
