# Master Plan: Ecosistema Inteligente de Yield Management, Promociones y Bundles 🚀

Este documento detalla la arquitectura, algoritmos y estrategia de implementación para dotar a la aplicación de un ecosistema avanzado de rentabilidad y promociones dinámicas, asegurando la integridad de los datos y el control estricto del inventario.

---

## 1. Diseño del Esquema de Datos (Base de Datos Local)

Para garantizar un **Modelo de Datos Incorruptible**, las nuevas tablas actuarán como "Agrupadores" o reglas financieras aplicadas sobre los IDs originales (`producto_id` y `presentacion_id`).

### Tabla: `campanas_promocionales`
Define la regla global de tiempo, estado y tipo de estrategia.
- `id` (INTEGER PRIMARY KEY)
- `negocio_id` (INTEGER)
- `nombre` (TEXT) - Ej: "Cierra Puertas Escolar"
- `tipo_estrategia` (TEXT) - 'flash_sale', 'bundle', 'volumen', 'al_costo'
- `fecha_inicio` (TEXT)
- `fecha_fin` (TEXT)
- `activo` (INTEGER DEFAULT 1)
- `etiqueta_escasez` (TEXT) - Ej: "¡Solo por hoy!"

### Tabla: `paquetes` (Bundles)
Se comporta como un "Super Producto" virtual.
- `id` (INTEGER PRIMARY KEY)
- `campana_id` (INTEGER NULLABLE)
- `negocio_id` (INTEGER)
- `nombre_paquete` (TEXT) - Ej: "Pack Cuaderno + Lápices"
- `descripcion` (TEXT)
- `imagen_url` (TEXT)
- `precio_venta_total` (REAL) - El precio final que paga el cliente por el paquete.
- `costo_total_calculado` (REAL) - Suma de costos base para el *Heatmap de Rentabilidad*.
- `activo` (INTEGER DEFAULT 1)

### Tabla: `items_paquete`
Relaciona estrictamente el paquete con los productos físicos reales.
- `id` (INTEGER PRIMARY KEY)
- `paquete_id` (INTEGER)
- `producto_id` (INTEGER) - Vínculo duro al catálogo original.
- `presentacion_id` (INTEGER) - Vínculo duro a la variante original.
- `cantidad_requerida` (INTEGER) - Cuántas unidades de esta variante conforman 1 paquete.
- `precio_original_unitario` (REAL) - Snapshot del precio normal en el momento de crear el paquete (referencia).

### Tabla: `reglas_promocion` (Para descuentos individuales o masivos)
- `id` (INTEGER PRIMARY KEY)
- `campana_id` (INTEGER)
- `presentacion_id` (INTEGER)
- `tipo_descuento` (TEXT) - 'porcentaje', 'monto_fijo', 'precio_final', 'al_costo'
- `valor_descuento` (REAL)
- `limite_stock_promocional` (INTEGER NULLABLE) - Stock máximo destinado a la oferta.

---

## 2. Resolución Matemática (Motor de Kitting & Un-Kitting)

El mayor reto de los Bundles es mantener la integridad del stock sin duplicar datos. El stock del `paquete` NO se guarda en la base de datos; **se calcula dinámicamente en memoria**.

**Algoritmo de Cuello de Botella (Disponibilidad Dinámica):**
Para saber cuántos "Pack Cuaderno + Lápices" se pueden vender:
1. Obtenemos los `items_paquete`.
   - Item A (Cuaderno): Requiere 1, Stock Actual = 50. (Posibles: 50/1 = 50)
   - Item B (Lápiz): Requiere 3, Stock Actual = 100. (Posibles: 100/3 = 33)
2. **Stock Máximo del Paquete** = `MIN(Posibles A, Posibles B, ...)` = **33 Paquetes.**

**Motor de Descuento (Al Confirmar Venta):**
Cuando se vende *1 Paquete*:
El sistema intercepta la venta y traduce el `paquete_id` a sus componentes. Se iteran los `items_paquete` y se hace un `UPDATE` restando la `cantidad_requerida` * `cantidad_vendida_del_paquete` al `stock_actual` de cada `presentacion_id`.

**Resolución de Conflictos de Precios:**
Si un producto tiene un descuento en su propia presentación, pero se mete en un paquete: **El Paquete tiene máxima prioridad**. El `precio_venta_total` del paquete anula cualquier otra regla individual de los componentes mientras se venda *como paquete*.

---

## 3. Auditoría de Integración (Impacto en Controladores Actuales)

Para que el ecosistema funcione de forma omnicanal, debemos inyectar la lógica en:

1. **POS / Caja Rápida (`quick_sale_screen.dart`):**
   - **Upsell Alert:** Al agregar un producto al carrito, el controlador debe consultar si ese `presentacion_id` pertenece a un paquete activo. Si es así, se lanza un Snackbar o un Chip flotante: *"Este producto está en el Paquete X. ¡Ofrecer por S/Y extra!"*.
   - **Buscador:** El buscador de Caja Rápida debe indexar también los nombres de la tabla `paquetes`.
2. **Cotización Manual / Catálogo:**
   - Crear un sub-tab o filtro llamado **"Promociones"** que liste los `paquetes` y productos con `reglas_promocion` activas.
   - En la tarjeta del producto, añadir una cinta visual (Badge) que indique si pertenece a un paquete.
3. **Generación de PDF y WhatsApp:**
   - Modificar el renderizado de PDFs (`invoice_pdf_generator.dart` / `quotation_pdf_generator.dart`) para que si un ítem es un paquete, lo imprima con su nombre propio ("Pack X") y opcionalmente liste sus componentes en una línea inferior más pequeña.
   - **Copywriting para WhatsApp:** Añadir un botón en el Dashboard del paquete que compile un String con emojis y gatillos mentales (ej. *"🚨 ¡OFERTA FLASH! Llévate el [Nombre del Paquete] a solo [Precio]..."*).

---

## 4. Roadmap de Ejecución por Fases (Iterativo)

*   **Fase 1: Núcleo de Datos y Modelos (Backend Local)**
    *   Ejecutar script de migración SQL en `local_db.dart` (V10) creando las tablas (`campanas_promocionales`, `paquetes`, `items_paquete`, `reglas_promocion`).
    *   Crear Modelos Dart (`CampaignModel`, `BundleModel`, `BundleItemModel`).
    *   Extender `InventoryProvider` para manejar el CRUD de estas nuevas entidades.

*   **Fase 2: Motor Lógico y Constructor de Bundles**
    *   Implementar el cálculo matemático de "Cuello de Botella" (Stock Dinámico).
    *   Desarrollar la UI del "Constructor de Paquetes": Pantalla con buscador para fusionar productos.
    *   Añadir el **Heatmap de Rentabilidad** (Verde/Amarillo/Rojo) basado en la suma del `costo_unitario_calculado` de los componentes vs el precio total del paquete sugerido.

*   **Fase 3: Dashboard de Inteligencia de Inventario (Insights)**
    *   Crear la pestaña "Insights / Ofertas" en la pantalla de Inventario.
    *   Diseñar el algoritmo sugestivo (productos con stock > X y fecha_actualizacion antigua).
    *   Crear el UI de las tarjetas de sugerencia con los motivos ("Sin ventas por 60 días").

*   **Fase 4: Integración Omnicanal (Caja, Cotizaciones y Alertas)**
    *   Actualizar `CheckoutProgressDialog` y la lógica de cierre de ventas (`pos_provider.dart` o similar) para hacer el "Un-kitting" (descuento correcto de stock al vender un paquete).
    *   Inyectar las Alertas de Upsell en `QuickSaleScreen`.
    *   Habilitar exportación de Copywriting (WhatsApp).

> [!IMPORTANT]
> **Tu Aprobación es Requerida:**
> Revisa detenidamente el diseño de base de datos y la resolución del algoritmo de Cuello de Botella. Si estás satisfecho con esta arquitectura, presiona **Proceed** para que yo comience inmediatamente con la codificación de la **Fase 1** (Migración SQL y Modelos).
