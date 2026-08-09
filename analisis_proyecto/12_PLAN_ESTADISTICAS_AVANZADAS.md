# 📊 Plan de Desarrollo: Dashboard Analítico Inteligente

He analizado tu solicitud, que es brillante. Un buen sistema de ventas no solo registra números, sino que te ayuda a tomar decisiones. Crear un panel de analíticas, proyecciones y rentabilidad llevará a MochilaLista al nivel de un software empresarial premium.

A continuación, detallo el plan técnico para ejecutar esta funcionalidad sin comprometer el rendimiento del dispositivo.

## 🛠️ Requisitos Técnicos y Dependencias

Antes de empezar con el código, necesitaremos agregar un par de librerías visuales para los gráficos y para la exportación a Excel:
- **`fl_chart`**: La librería número uno en Flutter para crear gráficos empresariales (barras, tortas, líneas) altamente interactivos y animados.
- **`csv`**: Para generar los archivos compatibles con Excel de manera súper rápida, en crudo.
*(Nota: Para PDF usaremos los paquetes `pdf` y `printing` que ya existen en tu sistema).*

## 🗂️ Fase 1: Motor de Análisis (Backend Local)

Para evitar congelar el celular, todo el cálculo se hará en pequeñas "ondas" (chunks) de forma asíncrona dentro de un nuevo **`AnalyticsProvider`**.

**1. Análisis de Ganancias Netas y Ventas:**
- Consultaremos el historial cruzando las tablas `ventas` y `venta_items`.
- **Lógica de costos:** Si un producto tiene `precio_costo`, calculamos la rentabilidad real (`precio_venta - precio_costo`). Si **no tiene**, aplicaremos una deducción inteligente simulando un margen de ganancia estándar (ej: 30%) para dar una proyección de ganancia aproximada.

**2. Predicciones por Temporada (Machine Learning Básico Local):**
- Agruparemos productos vendidos por `mes`. Así podremos inferir: *"En el mes de Agosto hay un incremento de venta de útiles de oficina"*.

**3. Actividad de Clientes y Top Ventas:**
- Tabla Top de mejores clientes.
- Top 5 de productos más vendidos.
- Alertas predictivas de **Quiebre de Stock**: Recomendaciones de qué necesitas comprar a tus proveedores *ahora* antes de que te quedes sin stock.

## 📱 Fase 2: Experiencia de Usuario (UI Premium)

**1. Ventana de Inicio (Carga Diferida):**
- Al entrar desde el Home, no cargaremos nada pesado. Se mostrará una pantalla limpia con el título **"Analítica de Crecimiento"**, una breve explicación de lo que descubrirás, y un gran botón: **"Generar Reporte Completo"**.

**2. Animación de Análisis en Pasos:**
- Al presionar, usaremos un flujo animado (similar a la carga del scanner de IA), mostrando poco a poco el progreso:
  - *Analizando ingresos brutos... [OK]*
  - *Calculando rentabilidad neta... [OK]*
  - *Prediciendo tendencias de clientes... [OK]*
  - *Generando gráficos...*

**3. Visualización de los Datos:**
- Usaremos tarjetas expansibles con **Gráficos de Barras** (Ventas vs Meses) y **Gráficos de Torta** (Top Productos). Todo con una estética moderna, colores adaptativos (Modo Oscuro) y un diseño impecable.

## 📄 Fase 3: Exportación de Reportes

- Se añadirá un botón flotante con menú desplegable para:
  1. **Descargar como PDF:** Crearemos un documento formal, con el logo del negocio, fecha y hora de creación, cuadros de datos ordenados y conclusiones predictivas.
  2. **Descargar como Excel (CSV):** Ideal para que el contador o el dueño abra el historial completo en Excel con todas las métricas en columnas limpias.
- El nombre del archivo se autogenerará con estampa de tiempo (Ej: `Reporte_Negocio_2026-08-07_14:30.pdf`).

## 🗺️ Fase 4: Integración

- Crearemos una nueva tarjeta (Card) interactiva en el **`SmartActionGrid`** del `home_screen.dart` con ícono de gráficas de tendencia para permitir la entrada a esta nueva ventana.

> [!IMPORTANT]  
> **Aprobación Requerida:**  
> Como es una arquitectura completa nueva, requeriremos instalar `fl_chart` y `csv`. Y tomaré libertades creativas en la paleta de colores de los gráficos (sugiero tonos púrpuras, azules y dorados para temas de dinero y éxito). 
>
> Si te parece perfecto este enfoque organizado y gradual, dale **Proceed** para que yo mismo ejecute los comandos en terminal e inicie a programar.
