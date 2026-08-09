# Plan de Implementación: Inteligencia de Negocio y Corrección de Analíticas

He analizado la arquitectura de estadísticas, encontrando la causa de los crasheos y planificando el nuevo módulo de Inteligencia de Negocios predictivo.

## User Review Required
Por favor revisa el plan a continuación. Este detalla cómo solucionaremos el error de la fase 3 ("Procesando Inventario") y cómo implementaremos la nueva sección de Oportunidades.

## 1. Resolución del Fallo en "Analíticas" (Tercer Sistema)

**Problema Raíz:** El error fatal ocurre en el paso de Predicciones e Inventario de `analytics_provider.dart`. Durante una consulta a la base de datos para detectar "productos con stock bajo", el sistema intenta acceder a la columna `stock_alerta`. Los usuarios nuevos la tienen, pero **para usuarios antiguos que actualizaron (como en tu versión 3.2), esta columna nunca se inyectó en las migraciones de SQLite**. Esto causa que SQLite rompa el proceso, mostrando el mensaje "Ocurrió un error al procesar los datos".

**Propuesta de Corrección:**
1. Crear una nueva migración `V8` en `local_db.dart` (`_onUpgrade`) para añadir `stock_alerta INTEGER DEFAULT 5` de manera segura en dispositivos antiguos.
2. Modificar la consulta SQL en `analytics_provider.dart` usando `IFNULL(pp.stock_alerta, 5)` para que sea a prueba de fallos.

## 2. Botón inactivo "Generar Reporte Completo"

Efectivamente, descubrí que ese contenedor azul con el texto "Generar Reporte Completo" y el ícono de rayo (`Icons.bolt`) no tiene ningún evento (no funciona) en `analytics_dashboard_screen.dart`. Es un diseño residual sin funcionalidad.

**Propuesta:** Eliminar este bloque estático y reemplazar el espacio libre para alojar un nuevo componente visual mucho más potente (ver punto 3).

## 3. Nuevo Sistema: "Motor de Insights y Novedades del Negocio"

**Mi opinión sobre incluir noticias:**
Integrar noticias de la web o el mercado global exige conexiones a internet (lo que rompe tu diseño de app Offline) y APIs de terceros lentas.
Lo **más útil y valioso para un comerciante** es conocer las "noticias" generadas a partir de *su propia data*.

**Propuesta de Mejora (Predicción de Crisis y Oportunidades):**
Construiremos una sección dinámica llamada **"Noticias de Mi Negocio"** (un carrusel interactivo) en la parte superior del Dashboard de Estadísticas, alimentado por el historial del cliente.

**Ejemplos de Noticias/Alertas a implementar:**
1. 🚨 **Riesgo de Quiebre de Stock:** El sistema calculará la velocidad de ventas de los últimos 3 meses y alertará: *"Tu [Producto Estrella] se agotará en aprox. 5 días a este ritmo. ¡Considera abastecerte con tu proveedor!"*.
2. 💸 **Alerta de Capital Estancado:** *"Tienes S/ 500 invertidos en mercancía que no rota hace 60 días. Recomendamos una liquidación o combo."*
3. 📈 **Tendencia Favorable:** *"Tus ingresos crecieron un 20% vs. el mes pasado. El día Viernes fue tu mejor día."*

## Proposed Changes

### 1. Database Layer (Migración)
#### [MODIFY] [local_db.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/database/local_db.dart)
- Incrementar versión de `7` a `8`.
- Inyectar en `_onUpgrade` el comando `ALTER TABLE presentaciones_producto ADD COLUMN stock_alerta INTEGER DEFAULT 5`.

### 2. Provider Layer (Motor Analítico)
#### [MODIFY] [analytics_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/providers/analytics_provider.dart)
- Reparar la consulta `lowStockQuery` usando `IFNULL` para evitar bloqueos.
- Fortalecer el cálculo matemático de predicciones para estimar "días restantes de inventario" y enviar esos datos a un nuevo objeto inteligente `BusinessInsight`.

### 3. UI Layer (Dashboard)
#### [MODIFY] [analytics_dashboard_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/screens/analytics_dashboard_screen.dart)
- Remover la tarjeta inactiva "Generar Reporte Completo".
- Añadir un Carousel estilizado y dinámico que mostrará las alertas predictivas, para darle un look ultra premium y valioso al comerciante.

## Verification Plan

### Automated Tests
- Ejecutaré un análisis profundo del código con `flutter analyze` para garantizar que las gráficas y componentes UI queden limpios sin advertencias graves de sintaxis.

### Manual Verification
- Si lo apruebas, realizaré las implementaciones, y te pediré que reconstruyas el APK (v3.2) localmente para probar en tu dispositivo si la fase 3 de analíticas avanza exitosamente y si la nueva interfaz de "Noticias" aporta el valor esperado.
