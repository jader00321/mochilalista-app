# Refactorización del Motor de Abastecimiento y Trazabilidad

Transformar el Motor Inteligente de Abastecimiento y las pantallas de Trazabilidad en herramientas de nivel empresarial: claras, educativas y eficientes en consumo de recursos.

## Hallazgos del Análisis

### Arquitectura de Datos Actual

Existen **2 tablas** que alimentan la trazabilidad:

| Tabla | Qué registra | Quién escribe | Tipos de transacción |
|---|---|---|---|
| `stock_ledger` | Movimientos numéricos de stock | `sales_service` → `VENTA`, `scanner_batch_saver` → `COMPRA_LOTE`, `product_repository` → `AJUSTE_INVENTARIO`, `intelligence_service` → `INVENTARIO_INICIAL` | 4 tipos |
| `product_history` | Cambios de metadatos/config | `product_repository` | `nombre`, `marca_id`, `categoria_id`, `precio_venta_final`, `costo_unitario_calculado`, `nombre_especifico`, `codigo_barras`, `estado` |

### Problemas Detectados

1. **`product_history` registra TODO sin filtro.** Campos como `nombre_especifico`, `codigo_barras` y `nombre` generan registros de auditoría por correcciones tipográficas irrelevantes, contaminando la línea de tiempo.
2. **Dos pantallas de trazabilidad duplicadas** con lógica distinta: [audit_trail_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/screens/audit_trail_screen.dart) (accesible desde Motor) y [product_audit_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/screens/product_audit_screen.dart) (accesible desde Catálogo). La segunda tiene mejor mapeo de acciones pero carece del diseño de timeline. Unificaremos la lógica.
3. **Motor sin contexto educativo.** Las métricas "ROP", "Velocidad", "Stock de Seguridad" se muestran crudas sin explicación.
4. **Barra inferior del Motor** tiene el texto "Inversión Total Sugerida" y el botón "Exportar OC" alineados con `spaceBetween` pero sin `crossAxisAlignment: center`, causando desalineación vertical sutil.

---

## Proposed Changes

### Fase 1: Optimización del Modelo de Trazabilidad

> [!IMPORTANT]
> Esta fase modifica la lógica de escritura en la base de datos. Los cambios son retrocompatibles: no se altera la estructura de las tablas, solo se filtra qué se escribe.

#### [MODIFY] [product_repository.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/repositories/product_repository.dart)

**En `_updateProductTxn` (línea 123):**
- Cambiar `fieldsToTrack` de `['nombre', 'marca_id', 'categoria_id']` a solo `['marca_id', 'categoria_id']`.
- **Motivo:** El cambio de nombre del producto es editorial (correcciones de typos) y no tiene valor financiero ni operativo para la trazabilidad. Los cambios de marca/categoría sí importan porque afectan reportes y agrupaciones.

**En `_updatePresentationTxn` (línea 187):**
- Cambiar `fieldsToTrack` de `['precio_venta_final', 'costo_unitario_calculado', 'nombre_especifico', 'codigo_barras', 'estado']` a solo `['precio_venta_final', 'costo_unitario_calculado', 'estado']`.
- **Motivo:** `nombre_especifico` y `codigo_barras` son ediciones de texto que saturan la DB con registros de bajo valor. Los campos financieros (`precio_venta_final`, `costo_unitario_calculado`) y el cambio de `estado` (público/privado) sí son críticos para auditoría.

---

### Fase 2: Rediseño Semántico de la Línea de Tiempo

#### [MODIFY] [audit_trail_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/screens/audit_trail_screen.dart)

Refactorizar completamente `_buildTimelineItem` para usar un mapeo semántico claro:

| `tipo_transaccion` / `campo_modificado` | Nombre actual (confuso) | Nombre nuevo (claro) | Icono | Color |
|---|---|---|---|---|
| `VENTA` | "Venta" | "📦 Venta en Caja" | `shopping_cart_checkout` | 🔴 Rojo (salida de stock) |
| `COMPRA_LOTE` | "Compra lote" | "🚚 Ingreso por Factura" | `local_shipping` | 🟢 Verde (entrada de stock) |
| `AJUSTE_INVENTARIO` (qty > 0) | "Ajuste inventario" | "➕ Ajuste Manual (+)" | `add_circle_outline` | 🟢 Verde |
| `AJUSTE_INVENTARIO` (qty < 0) | "Ajuste inventario" | "➖ Ajuste Manual (-)" | `remove_circle_outline` | 🔴 Rojo |
| `INVENTARIO_INICIAL` | "Inventario Inicial" | "🏁 Punto de Partida" | `flag` | 🔵 Azul |
| `precio_venta_final` | "Estado" (incorrecto) | "💰 Precio de Venta Actualizado" | `price_change` | 🟣 Morado |
| `costo_unitario_calculado` | "Estado" | "📊 Costo Interno Ajustado" | `analytics` | 🟣 Morado |
| `estado` | "Estado" | "🔒 Visibilidad Cambiada" | `visibility` | 🟠 Naranja |
| `marca_id` / `categoria_id` | genérico | "🏷️ Clasificación Modificada" | `label` | Gris |

Además:
- Para operaciones de stock (`STOCK_OP`), mostrar la cantidad con signo claro: `"+30 unidades"` (verde) o `"-5 unidades"` (rojo).
- Para cambios de precio, mostrar un mini-diff visual: `S/ 10.00 → S/ 12.00` con colores (tachado el antiguo, negrita el nuevo).
- Aplicar el mismo mapeo unificado a [product_audit_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/screens/product_audit_screen.dart) para que ambas pantallas de trazabilidad sean visualmente consistentes.

---

### Fase 3: Sistema de Info Tooltips (Educación UX)

#### [MODIFY] [smart_restock_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/screens/smart_restock_screen.dart)

**Agregar iconos `(i)` junto a las métricas en `_buildMetricColumn`:**

Cada métrica tendrá un icono de información que, al presionarse, muestra un diálogo modal elegante con:

| Métrica | Tooltip (lenguaje de negocio) |
|---|---|
| **Stock** | "Unidades disponibles para vender ahora mismo. Si llega a 0, pierdes ventas." |
| **Velocidad** | "Ritmo de ventas promedio: cuántas unidades vendes por día. Se calcula con tus ventas de los últimos 30 días, dando más peso a la semana reciente." |
| **ROP** (Punto de Reorden) | "Nivel mínimo de inventario. Si tu stock cae a este número, es momento de hacer tu pedido al proveedor, considerando que tardará ~7 días en llegar." |
| **Sugerido** | "Cantidad óptima a comprar para cubrir ~30 días de ventas según tu ritmo actual." |
| **Stock de Seguridad** | "Colchón de emergencia para absorber picos inesperados de demanda. Se calcula estadísticamente con tus ventas históricas." |

**Implementación técnica:**
- Crear un helper estático `_showInfoDialog(context, title, explanation, icon, color)` que renderice un `showDialog` con `AlertDialog` estilizado (fondo oscuro, icono grande, texto claro).
- En `_buildMetricColumn`, agregar un `GestureDetector` con un icono `Icons.info_outline` pequeño (12px) al lado del label.

---

### Fase 4: Empoderamiento UX y Corrección Visual

#### [MODIFY] [smart_restock_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/screens/smart_restock_screen.dart)

**Tarjeta de Ayuda Rápida (cabecera):**
- Agregar un `Container` colapsable justo encima de la lista, con un `InkWell` y `AnimatedSize`.
- Título: "📋 ¿Cómo leer esta pantalla?"
- Contenido: Explicación breve del propósito del Motor, qué significa cada color de tarjeta (🔴 Crítico, 🟠 Preventivo), y qué hacer con el botón "Exportar OC".
- Se muestra colapsado por defecto, con un botón de `?` o `💡` para expandirlo.

**Corrección de Barra Inferior (`_buildSummaryBar`):**
- Agregar `crossAxisAlignment: CrossAxisAlignment.center` al `Row` principal.
- Agregar padding vertical al botón "Exportar OC" para alinear visualmente con el bloque de texto.

#### [MODIFY] [audit_trail_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/screens/audit_trail_screen.dart)

**Tarjeta de Ayuda Rápida (cabecera del Summary Card):**
- Agregar un botón `IconButton(Icons.help_outline)` en la esquina de la tarjeta resumen.
- Al presionar, muestra un diálogo que explica: "Esta pantalla muestra el historial completo de movimientos de tu producto: cada venta, compra, ajuste manual y cambio de precio. Los colores te indican si el stock entró (verde) o salió (rojo)."

---

## Verification Plan

### Manual Verification
1. Editar un producto cambiando solo su nombre → verificar que **NO** se registra en `product_history`.
2. Editar un producto cambiando su precio de venta → verificar que **SÍ** se registra.
3. Abrir la trazabilidad de un producto con historial mixto → verificar que cada tipo de evento muestra el nombre, icono y color correcto según la tabla de la Fase 2.
4. En el Motor de Abastecimiento, presionar el icono `(i)` junto a "ROP" → verificar que aparece el diálogo con la explicación en lenguaje de negocio.
5. Verificar que la barra inferior del Motor quede centrada verticalmente.
